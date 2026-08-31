; ---------------------------------------------------------------------------
; 3CMOCKIF.ASM
; Mock backend for the 3C509/3C509B ISA interface used during CLI testing.
; ---------------------------------------------------------------------------
; The mock preserves the hardware-facing contract used by 3CCFGCLI:
;   - ID-port discovery enumerates untagged contenders one by one
;   - tag/select/activate semantics are modelled per mock NIC record
;   - active-base register and EEPROM access route to the addressed record
;
; Mock fidelity / limitations:
;   - Distinct-base multi-NIC scenarios are intended to be hardware-credible.
;   - Shared-IRQ scenarios are acceptable for CLI testing because the utility
;     does not depend on interrupt-driven communication with the adapter.
;   - Multiple simultaneously active records with the same IOBASE are
;     conflict simulations only.  The original 3CCFG discovery logic treated
;     duplicate active resources as an ambiguity/error condition rather than a
;     clean steady state, and no strong evidence was found that it could
;     reliably mutate one specific card while two cards actively decoded the
;     same base.  This mock therefore resolves same-base active access to the
;     first matching record only and does not claim strong hardware
;     equivalence for that case.
; ---------------------------------------------------------------------------

MOCK_STATE_SIZE EQU 256

DATASEG

MOCK_STATE_FILE DB '3C509B.MCK', 0
mock_file_state DB MCK_FILE_SIZE DUP (0)

; Scratch image for the currently loaded mock record.
mock_state DB MOCK_STATE_SIZE DUP (0)
mock_state_dirty DB 0
mock_current_window DB 0
mock_active_base DW 0000h
mock_irq DB 0
mock_tag DB 0
mock_active DB 0
mock_w4_netdiag DW 0000h
mock_w4_media_status DW 0000h
mock_eeprom_busy DB 0
mock_eeprom_flags DB 0
mock_eeprom_pending DB 0
mock_id_shift DW 0
mock_id_bits_left DB 0
mock_id_state DB MCK_ID_WAIT
mock_id_sequence_expected DB 0
mock_id_sequence_count DW 0
mock_id_zero_count DB 0
mock_id_command_ready DB 0
mock_id_contention_active DB 0

; Global mock discovery state.
mock_selected_tag DB 0
mock_selected_valid DB 0
mock_contender_visible DB 0
mock_record_count DB 0
mock_loaded_index DB 0FFh
mock_contender_index DB 0FFh

CODESEG

PROC Mock_Clear_Scratch NEAR
    push    ax
    push    cx
    push    di

    mov     cx, MOCK_STATE_SIZE
    mov     di, OFFSET mock_state
    xor     ax, ax
@@ClearScratch:
    mov     [di], al
    inc     di
    loop    @@ClearScratch

    mov     [byte mock_state_dirty], 0
    mov     [byte mock_current_window], 0
    mov     [word mock_active_base], 0000h
    mov     [byte mock_irq], 0
    mov     [byte mock_tag], 0
    mov     [byte mock_active], 0
    mov     [word mock_w4_netdiag], 0
    mov     [word mock_w4_media_status], 0
    mov     [byte mock_eeprom_busy], 0
    mov     [byte mock_eeprom_flags], 0
    mov     [byte mock_eeprom_pending], 0
    mov     [word mock_id_shift], 0
    mov     [byte mock_id_bits_left], 0
    mov     [byte mock_id_state], MCK_ID_WAIT
    mov     [byte mock_id_sequence_expected], 0
    mov     [word mock_id_sequence_count], 0
    mov     [byte mock_id_zero_count], 0
    mov     [byte mock_id_command_ready], 0
    mov     [byte mock_id_contention_active], 0

    pop     di
    pop     cx
    pop     ax
    ret
ENDP Mock_Clear_Scratch

PROC Init_State NEAR
    call    Mock_Clear_Scratch
    mov     [byte mock_selected_tag], 0
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_contender_visible], 0
    mov     [byte mock_record_count], 0
    mov     [byte mock_loaded_index], 0FFh
    mov     [byte mock_contender_index], 0FFh
    ret
ENDP Init_State

PROC Mock_Init_Empty_File NEAR
    push    ax
    push    cx
    push    di

    mov     di, OFFSET mock_file_state
    mov     cx, MCK_FILE_SIZE
    xor     ax, ax
@@ClearFile:
    mov     [di], al
    inc     di
    loop    @@ClearFile

    mov     [BYTE mock_file_state + MCK_OFF_MAGIC0], MCK_MAGIC_0
    mov     [BYTE mock_file_state + MCK_OFF_MAGIC1], MCK_MAGIC_1
    mov     [BYTE mock_file_state + MCK_OFF_MAGIC2], MCK_MAGIC_2
    mov     [BYTE mock_file_state + MCK_OFF_MAGIC3], MCK_MAGIC_3
    mov     [WORD mock_file_state + MCK_OFF_VERSION], MCK_VERSION
    mov     [BYTE mock_file_state + MCK_OFF_RECORD_COUNT], 0
    mov     [byte mock_record_count], 0
    mov     [byte mock_loaded_index], 0FFh
    mov     [byte mock_contender_index], 0FFh
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    mov     [byte mock_contender_visible], 0
    mov     [byte mock_state_dirty], 0

    pop     di
    pop     cx
    pop     ax
    ret
ENDP Mock_Init_Empty_File

PROC Mock_Get_Record_Ptr NEAR
    push    bx

    xor     bx, bx
    mov     bl, al
    mov     bh, bl
    xor     bl, bl
    mov     di, OFFSET mock_file_state + MCK_HEADER_SIZE
    add     di, bx

    pop     bx
    ret
ENDP Mock_Get_Record_Ptr

PROC Mock_Commit_Loaded_Record NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    cmp     [byte mock_loaded_index], 0FFh
    je      @@Done
    cmp     [byte mock_state_dirty], 0
    je      @@Done

    mov     al, [byte mock_loaded_index]
    call    Mock_Get_Record_Ptr

    mov     ax, [word mock_state + EL3_W0_MFG_ID]
    cmp     ax, 06D50h
    jne     @@NoPresent
    mov     [BYTE di + MCK3R_PRESENT], 1
    jmp     @@StoreHeader
@@NoPresent:
    mov     [BYTE di + MCK3R_PRESENT], 0
@@StoreHeader:
    mov     al, [byte mock_id_state]
    mov     [BYTE di + MCK3R_ID_STATE], al
    mov     al, [byte mock_active]
    or      al, al
    jz      @@Inactive
    mov     [BYTE di + MCK3R_FLAGS], MCKRF_ACTIVE
    jmp     @@StateDone
@@Inactive:
    mov     [BYTE di + MCK3R_FLAGS], 0
@@StateDone:
    mov     al, [byte mock_tag]
    mov     [BYTE di + MCK3R_TAG], al
    mov     al, [byte mock_current_window]
    mov     [BYTE di + MCK3R_CURRENT_WINDOW], al
    mov     ax, [word mock_active_base]
    mov     [WORD di + MCK3R_ACTIVE_BASE], ax

    mov     ax, [word mock_state + EL3_W0_PRODUCT_ID]
    mov     [WORD di + MCK3R_W0_PRODUCT], ax
    mov     ax, [word mock_state + EL3_W0_CONFIG_CONTROL]
    mov     [WORD di + MCK3R_W0_CONFIG_CONTROL], ax
    mov     ax, [word mock_state + EL3_W0_ADDRESS_CFG]
    mov     [WORD di + MCK3R_W0_ADDRESS_CFG], ax
    mov     ax, [word mock_state + EL3_W0_RESOURCE_CFG]
    mov     [WORD di + MCK3R_W0_RESOURCE_CFG], ax
    mov     ax, [word mock_state + EL3_W0_EEPROM_COMMAND]
    mov     [WORD di + MCK3R_EEPROM_COMMAND], ax
    mov     ax, [word mock_state + EL3_W0_EEPROM_DATA]
    mov     [WORD di + MCK3R_EEPROM_DATA], ax
    mov     al, [byte mock_eeprom_busy]
    mov     [BYTE di + MCK3R_EEPROM_BUSY], al
    mov     al, [byte mock_eeprom_flags]
    mov     [BYTE di + MCK3R_EEPROM_FLAGS], al
    mov     al, [byte mock_eeprom_pending]
    mov     [BYTE di + MCK3R_EEPROM_PENDING], al
    mov     ax, [word mock_w4_netdiag]
    mov     [WORD di + MCK3R_W4_NET_DIAG_WRITE], ax
    mov     ax, [word mock_state + 30h]
    mov     [WORD di + MCK3R_W4_MEDIA_WRITE], ax
    mov     ax, [word mock_w4_media_status]
    mov     [WORD di + MCK3R_W4_MEDIA_INPUT], ax

    lea     si, [mock_state + 40h]
    lea     di, [di + MCK3R_EEPROM]
    mov     cx, 64
@@CopyEeprom:
    mov     ax, [WORD si]
    mov     [WORD di], ax
    add     si, 2
    add     di, 2
    loop    @@CopyEeprom

    mov     [byte mock_state_dirty], 0
@@Done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Mock_Commit_Loaded_Record

PROC Mock_Load_Record_By_Index NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    cmp     al, [byte mock_record_count]
    jae     @@Fail
 
    mov     dl, al
    call    Mock_Commit_Loaded_Record
    call    Mock_Clear_Scratch
    mov     al, dl
    mov     [byte mock_loaded_index], al
    call    Mock_Get_Record_Ptr

    mov     al, [BYTE di + MCK3R_CURRENT_WINDOW]
    mov     [byte mock_current_window], al
    mov     al, [BYTE di + MCK3R_TAG]
    mov     [byte mock_tag], al
    mov     al, [BYTE di + MCK3R_ID_STATE]
    mov     [byte mock_id_state], al
    mov     ax, [WORD di + MCK3R_ACTIVE_BASE]
    mov     [word mock_active_base], ax
    mov     al, [BYTE di + MCK3R_FLAGS]
    and     al, MCKRF_ACTIVE
    mov     [byte mock_active], al

    mov     [word mock_state + EL3_W0_MFG_ID], 06D50h
    mov     ax, [WORD di + MCK3R_W0_PRODUCT]
    mov     [word mock_state + EL3_W0_PRODUCT_ID], ax
    mov     ax, [WORD di + MCK3R_W0_CONFIG_CONTROL]
    mov     [word mock_state + EL3_W0_CONFIG_CONTROL], ax
    mov     ax, [WORD di + MCK3R_W0_ADDRESS_CFG]
    mov     [word mock_state + EL3_W0_ADDRESS_CFG], ax
    mov     ax, [WORD di + MCK3R_W0_RESOURCE_CFG]
    mov     [word mock_state + EL3_W0_RESOURCE_CFG], ax
    mov     ax, [WORD di + MCK3R_EEPROM_COMMAND]
    mov     [word mock_state + EL3_W0_EEPROM_COMMAND], ax
    mov     ax, [WORD di + MCK3R_EEPROM_DATA]
    mov     [word mock_state + EL3_W0_EEPROM_DATA], ax
    mov     al, [BYTE di + MCK3R_EEPROM_BUSY]
    mov     [byte mock_eeprom_busy], al
    mov     al, [BYTE di + MCK3R_EEPROM_FLAGS]
    mov     [byte mock_eeprom_flags], al
    mov     al, [BYTE di + MCK3R_EEPROM_PENDING]
    mov     [byte mock_eeprom_pending], al
    mov     ax, [WORD di + MCK3R_W4_NET_DIAG_WRITE]
    mov     [word mock_w4_netdiag], ax
    mov     ax, [WORD di + MCK3R_W4_MEDIA_WRITE]
    mov     [word mock_state + 30h], ax
    mov     ax, [WORD di + MCK3R_W4_MEDIA_INPUT]
    mov     [word mock_w4_media_status], ax

    lea     si, [di + MCK3R_EEPROM]
    lea     di, [mock_state + 40h]
    mov     cx, 64
@@CopyIn:
    mov     ax, [WORD si]
    mov     [WORD di], ax
    add     si, 2
    add     di, 2
    loop    @@CopyIn

    mov     [byte mock_state_dirty], 0
    clc
    jmp     @@Done
@@Fail:
    stc
@@Done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Mock_Load_Record_By_Index

PROC Mock_Find_Record_By_Base NEAR
    push    bx
    push    cx
    push    di

    xor     ax, ax
    mov     cl, [byte mock_record_count]
    xor     ch, ch
@@Loop:
    or      cx, cx
    jz      @@NotFound
    push    ax
    call    Mock_Get_Record_Ptr
    pop     ax
    cmp     [BYTE di + MCK3R_PRESENT], 0
    je      @@Next
    test    [BYTE di + MCK3R_FLAGS], MCKRF_ACTIVE
    je      @@Next
    cmp     [WORD di + MCK3R_ACTIVE_BASE], dx
    je      @@Found
@@Next:
    inc     al
    dec     cx
    jmp     @@Loop
@@Found:
    pop     di
    pop     cx
    pop     bx
    clc
    ret
@@NotFound:
    pop     di
    pop     cx
    pop     bx
    stc
    ret
ENDP Mock_Find_Record_By_Base

PROC Mock_Find_Record_By_Tag NEAR
    push    bx
    push    cx
    push    dx
    push    di

    mov     dl, al
    xor     ax, ax
    mov     cl, [byte mock_record_count]
    xor     ch, ch
@@Loop:
    or      cx, cx
    jz      @@NotFound
    push    ax
    call    Mock_Get_Record_Ptr
    pop     ax
    cmp     [BYTE di + MCK3R_PRESENT], 0
    je      @@Next
    cmp     [BYTE di + MCK3R_TAG], dl
    je      @@Found
@@Next:
    inc     al
    dec     cx
    jmp     @@Loop
@@Found:
    pop     di
    pop     dx
    pop     cx
    pop     bx
    clc
    ret
@@NotFound:
    pop     di
    pop     dx
    pop     cx
    pop     bx
    stc
    ret
ENDP Mock_Find_Record_By_Tag

PROC Mock_Find_First_Untagged_Record NEAR
    push    bx
    push    cx
    push    di

    xor     ax, ax
    mov     cl, [byte mock_record_count]
    xor     ch, ch
@@Loop:
    or      cx, cx
    jz      @@NotFound
    push    ax
    call    Mock_Get_Record_Ptr
    pop     ax
    cmp     [BYTE di + MCK3R_PRESENT], 0
    je      @@Next
    cmp     [BYTE di + MCK3R_TAG], 0
    je      @@Found
@@Next:
    inc     al
    dec     cx
    jmp     @@Loop
@@Found:
    pop     di
    pop     cx
    pop     bx
    clc
    ret
@@NotFound:
    pop     di
    pop     cx
    pop     bx
    stc
    ret
ENDP Mock_Find_First_Untagged_Record

; Return the first untagged adapter currently participating in an ID command.
PROC Mock_Find_First_Command_Contender NEAR
    push    bx
    push    cx
    push    di

    xor     ax, ax
    mov     cl, [byte mock_record_count]
    xor     ch, ch
@@Loop:
    or      cx, cx
    jz      @@NotFound
    push    ax
    call    Mock_Get_Record_Ptr
    pop     ax
    cmp     [BYTE di + MCK3R_PRESENT], 0
    je      @@Next
    cmp     [BYTE di + MCK3R_TAG], 0
    jne     @@Next
    cmp     [BYTE di + MCK3R_ID_STATE], MCK_ID_CMD
    je      @@Found
@@Next:
    inc     al
    dec     cx
    jmp     @@Loop
@@Found:
    pop     di
    pop     cx
    pop     bx
    clc
    ret
@@NotFound:
    pop     di
    pop     cx
    pop     bx
    stc
    ret
ENDP Mock_Find_First_Command_Contender

PROC Mock_Ensure_Record_By_Base NEAR
    push    ax

    cmp     [byte mock_loaded_index], 0FFh
    je      @@Load
    cmp     dx, [word mock_active_base]
    jne     @@Load
    pop     ax
    clc
    ret
@@Load:
    call    Mock_Find_Record_By_Base
    jc      @@Fail
    call    Mock_Load_Record_By_Index
    jc      @@Fail
    pop     ax
    clc
    ret
@@Fail:
    pop     ax
    stc
    ret
ENDP Mock_Ensure_Record_By_Base

; Input DX = physical ISA port.  Output AL = matching active record index.
; A card decodes exactly its configured 16-byte I/O region.
PROC Mock_Find_Record_By_Port NEAR
    push    bx
    push    cx
    push    si
    push    di

    xor     ax, ax
    mov     cl, [byte mock_record_count]
    xor     ch, ch
@@Loop:
    or      cx, cx
    jz      @@NotFound
    push    ax
    call    Mock_Get_Record_Ptr
    pop     ax
    cmp     [BYTE di + MCK3R_PRESENT], 0
    je      @@Next
    test    [BYTE di + MCK3R_FLAGS], MCKRF_ACTIVE
    jz      @@Next
    mov     bx, [WORD di + MCK3R_ACTIVE_BASE]
    cmp     dx, bx
    jb      @@Next
    add     bx, 000Fh
    cmp     dx, bx
    jbe     @@Found
@@Next:
    inc     al
    dec     cx
    jmp     @@Loop
@@Found:
    pop     di
    pop     si
    pop     cx
    pop     bx
    clc
    ret
@@NotFound:
    pop     di
    pop     si
    pop     cx
    pop     bx
    stc
    ret
ENDP Mock_Find_Record_By_Port

PROC Mock_Ensure_Record_By_Tag NEAR
    push    ax

    cmp     [byte mock_loaded_index], 0FFh
    je      @@Load
    cmp     al, [byte mock_tag]
    jne     @@Load
    pop     ax
    clc
    ret
@@Load:
    call    Mock_Find_Record_By_Tag
    jc      @@Fail
    call    Mock_Load_Record_By_Index
    jc      @@Fail
    pop     ax
    clc
    ret
@@Fail:
    pop     ax
    stc
    ret
ENDP Mock_Ensure_Record_By_Tag

PROC Load_State NEAR
    push    ax
    push    bx
    push    cx
    push    dx

    call    Init_State
    call    Mock_Init_Empty_File

    mov     dx, OFFSET MOCK_STATE_FILE
    xor     al, al
    mov     ah, 3Dh
    int     21h
    jc      @@Done
    mov     bx, ax
    mov     cx, MCK_FILE_SIZE
    mov     dx, OFFSET mock_file_state
    mov     ah, 3Fh
    int     21h
    mov     ah, 3Eh
    int     21h

    cmp     [BYTE mock_file_state + MCK_OFF_MAGIC0], MCK_MAGIC_0
    jne     @@Invalid
    cmp     [BYTE mock_file_state + MCK_OFF_MAGIC1], MCK_MAGIC_1
    jne     @@Invalid
    cmp     [BYTE mock_file_state + MCK_OFF_MAGIC2], MCK_MAGIC_2
    jne     @@Invalid
    cmp     [BYTE mock_file_state + MCK_OFF_MAGIC3], MCK_MAGIC_3
    jne     @@Invalid

    mov     ax, [WORD mock_file_state + MCK_OFF_VERSION]
    cmp     ax, MCK_VERSION
    je      @@VersionOk
    cmp     ax, MCK_VERSION_V1
    jne     @@Invalid
@@VersionOk:
    mov     al, [BYTE mock_file_state + MCK_OFF_RECORD_COUNT]
    cmp     [WORD mock_file_state + MCK_OFF_VERSION], MCK_VERSION_V1
    jne     @@Clamp
    or      al, al
    jne     @@Clamp
    mov     al, 1
@@Clamp:
    cmp     al, MCK_MAX_RECORDS
    jbe     @@CountOk
    mov     al, MCK_MAX_RECORDS
@@CountOk:
    mov     [byte mock_record_count], al
    jmp     @@Done

@@Invalid:
    call    Init_State
    call    Mock_Init_Empty_File
@@Done:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Load_State

PROC Save_State NEAR
    push    ax
    push    bx
    push    cx
    push    dx

    call    Mock_Commit_Loaded_Record

    mov     [BYTE mock_file_state + MCK_OFF_MAGIC0], MCK_MAGIC_0
    mov     [BYTE mock_file_state + MCK_OFF_MAGIC1], MCK_MAGIC_1
    mov     [BYTE mock_file_state + MCK_OFF_MAGIC2], MCK_MAGIC_2
    mov     [BYTE mock_file_state + MCK_OFF_MAGIC3], MCK_MAGIC_3
    mov     [WORD mock_file_state + MCK_OFF_VERSION], MCK_VERSION
    mov     al, [byte mock_record_count]
    mov     [BYTE mock_file_state + MCK_OFF_RECORD_COUNT], al

    mov     ah, 3Ch
    xor     cx, cx
    mov     dx, OFFSET MOCK_STATE_FILE
    int     21h
    jc      @@Done
    mov     bx, ax

    mov     cx, MCK_FILE_SIZE
    mov     dx, OFFSET mock_file_state
    mov     ah, 40h
    int     21h
    mov     ah, 3Eh
    int     21h
@@Done:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Save_State

PROC Nic_Read_Status NEAR
    push    dx
    add     dx, EL3_STATUS
    call    Nic_IO_Read_Word
    pop     dx
    ret
ENDP Nic_Read_Status

PROC Nic_Select_Window NEAR
    push    ax
    push    dx
    xor     ah, ah
    and     ax, 0007h
    or      ax, CMD_SELECT_WINDOW
    add     dx, EL3_COMMAND
    call    Nic_IO_Write_Word
    pop     dx
    pop     ax
    ret
ENDP Nic_Select_Window

PROC Nic_Get_Current_Window NEAR
    call    Mock_Ensure_Record_By_Base
    jc      @@None
    xor     ax, ax
    mov     al, [byte mock_current_window]
    ret
@@None:
    xor     ax, ax
    ret
ENDP Nic_Get_Current_Window

PROC Nic_Wait_Command_Ready NEAR
    clc
    ret
ENDP Nic_Wait_Command_Ready

; Advance a completed EEPROM operation only when software observes EBY clear.
PROC Mock_Eeprom_Read_Command NEAR
    push    bx

    mov     al, [byte mock_eeprom_busy]
    or      al, al
    jz      @@Ready
    dec     [byte mock_eeprom_busy]
    mov     [byte mock_state_dirty], 1
    call    Save_State
    mov     ax, EEPROM_BUSY
    jmp     @@Done
@@Ready:
    test    [byte mock_eeprom_flags], MCKEF_DATA_VALID
    jz      @@Return
    mov     bx, [word mock_state + EL3_W0_EEPROM_COMMAND]
    and     bx, 003Fh
    shl     bx, 1
    mov     ax, [word mock_state + 40h + bx]
    mov     [word mock_state + EL3_W0_EEPROM_DATA], ax
    and     [byte mock_eeprom_flags], NOT MCKEF_DATA_VALID
    mov     [byte mock_state_dirty], 1
    call    Save_State
@@Return:
    mov     ax, [word mock_state + EL3_W0_EEPROM_COMMAND]
    and     ax, 7FFFh
@@Done:
    pop     bx
    ret
ENDP Mock_Eeprom_Read_Command

; Window 0 EEPROM command decoder.  Program operations require explicit
; enable, erase writes ones, and write operations can only clear bits.
PROC Mock_Eeprom_Write_Command NEAR
    push    bx
    push    cx
    push    dx

    cmp     [byte mock_eeprom_busy], 0
    jne     @@Done
    mov     [word mock_state + EL3_W0_EEPROM_COMMAND], ax
    mov     dx, ax
    and     dx, 00C0h
    cmp     dx, 0000h
    jne     @@Operation
    and     ax, 0030h
    cmp     ax, EEPROM_CMD_WRITE_ENABLE
    jne     @@Disable
    or      [byte mock_eeprom_flags], MCKEF_WRITE_ENABLED
    jmp     @@Done
@@Disable:
    and     [byte mock_eeprom_flags], NOT MCKEF_WRITE_ENABLED
    jmp     @@Done
@@Operation:
    mov     cx, ax
    and     cx, 003Fh
    cmp     dx, EEPROM_CMD_READ
    jne     @@WriteOrErase
    mov     [byte mock_eeprom_pending], cl
    or      [byte mock_eeprom_flags], MCKEF_DATA_VALID
    mov     [byte mock_eeprom_busy], 1
    jmp     @@Done
@@WriteOrErase:
    test    [byte mock_eeprom_flags], MCKEF_WRITE_ENABLED
    jz      @@Done
    mov     bx, cx
    shl     bx, 1
    cmp     dx, EEPROM_CMD_ERASE
    jne     @@Write
    mov     [word mock_state + 40h + bx], 0FFFFh
    jmp     @@ProgramDone
@@Write:
    mov     ax, [word mock_state + EL3_W0_EEPROM_DATA]
    and     [word mock_state + 40h + bx], ax
@@ProgramDone:
    and     [byte mock_eeprom_flags], NOT MCKEF_WRITE_ENABLED
    mov     [byte mock_eeprom_busy], 1
    mov     [byte mock_state_dirty], 1
@@Done:
    pop     dx
    pop     cx
    pop     bx
    ret
ENDP Mock_Eeprom_Write_Command

; Internal register dispatch after physical port resolution.  Input BX is the
; offset within the active adapter's 16-byte region.
PROC Mock_Reg_Read_Word NEAR
    push    bx
    push    cx

    mov     cl, [byte mock_current_window]
    cmp     cl, 4
    jne     @@Window0
    cmp     bx, EL3_W4_NET_DIAG
    je      @@NetDiag
    cmp     bx, EL3_W4_MEDIA_STATUS
    jne     @@Default
    mov     ax, [word mock_w4_media_status]
    and     ax, NOT W4_MEDIA_STATUS_WRITABLE
    mov     dx, [word mock_state + 30h]
    and     dx, W4_MEDIA_STATUS_WRITABLE
    or      ax, dx
    jmp     @@Done
@@NetDiag:
    mov     ax, [word mock_w4_netdiag]
    and     ax, 0F000h
    or      ax, W4_NET_DIAG_ASIC_REV
    jmp     @@Done
@@Window0:
    cmp     cl, 0
    jne     @@Default
    cmp     bx, EL3_W0_EEPROM_COMMAND
    jne     @@ReadRaw
    call    Mock_Eeprom_Read_Command
    jmp     @@Done
@@ReadRaw:
    mov     ax, [word mock_state + bx]
    jmp     @@Done
@@Default:
    xor     ax, ax
@@Done:
    pop     cx
    pop     bx
    ret
ENDP Mock_Reg_Read_Word

PROC Nic_IO_Read_Word NEAR
    push    bx
    push    dx

    call    Mock_Find_Record_By_Port
    jc      @@Absent
    cmp     al, [byte mock_loaded_index]
    je      @@Loaded
    call    Mock_Load_Record_By_Index
    jc      @@Absent
@@Loaded:
    pop     dx
    push    dx
    mov     bx, dx
    sub     bx, [word mock_active_base]
    cmp     bx, EL3_STATUS
    jne     @@Register
    xor     ax, ax
    mov     al, [byte mock_current_window]
    shl     ax, 13
    and     ax, STATUS_WINDOW_MASK
    jmp     @@Done
@@Register:
    call    Mock_Reg_Read_Word
    jmp     @@Done
@@Absent:
    mov     ax, 0FFFFh
@@Done:
    pop     dx
    pop     bx
    ret
ENDP Nic_IO_Read_Word

PROC Cfg_Reg_Read_Word NEAR
    push    dx
    add     dx, bx
    call    Nic_IO_Read_Word
    pop     dx
    ret
ENDP Cfg_Reg_Read_Word

PROC Nic_Reg_Read_Word NEAR
    call    Cfg_Reg_Read_Word
    ret
ENDP Nic_Reg_Read_Word

; Internal register dispatch after physical port resolution.  Input BX is the
; offset within the active adapter's 16-byte region.
PROC Mock_Reg_Write_Word NEAR
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    mov     cl, [byte mock_current_window]
    cmp     cl, 4
    jne     @@Window0
    cmp     bx, EL3_W4_NET_DIAG
    jne     @@MediaStatus
    and     ax, W4_NET_DIAG_WRITABLE
    mov     [word mock_w4_netdiag], ax
    mov     [byte mock_state_dirty], 1
    call    Save_State
    jmp     @@Done
@@MediaStatus:
    cmp     bx, EL3_W4_MEDIA_STATUS
    jne     @@Done
    and     ax, W4_MEDIA_STATUS_WRITABLE
    mov     [word mock_state + 30h], ax
    mov     [byte mock_state_dirty], 1
    call    Save_State
    jmp     @@Done
@@Window0:
    cmp     cl, 0
    jne     @@Done
    cmp     bx, EL3_W0_EEPROM_COMMAND
    jne     @@StoreDirect
    call    Mock_Eeprom_Write_Command
    mov     [byte mock_state_dirty], 1
    call    Save_State
    jmp     @@Done
@@StoreDirect:
    cmp     bx, EL3_W0_MFG_ID
    je      @@Done
    cmp     bx, EL3_W0_PRODUCT_ID
    je      @@Done
    cmp     bx, EL3_W0_CONFIG_CONTROL
    jne     @@StoreRaw
    mov     dx, [word mock_state + EL3_W0_CONFIG_CONTROL]
    and     dx, NOT W0_CONFIG_CONTROL_WRITABLE
    and     ax, W0_CONFIG_CONTROL_WRITABLE
    or      ax, dx
    mov     [word mock_state + EL3_W0_CONFIG_CONTROL], ax
    test    ax, W0_CONFIG_CONTROL_RST
    jz      @@PersistLive
    call    Mock_Automatic_Configuration
    call    Save_State
    jmp     @@Done
@@StoreRaw:
    mov     [word mock_state + bx], ax
    mov     [byte mock_state_dirty], 1
    cmp     bx, EL3_W0_ADDRESS_CFG
    je      @@PersistLive
    cmp     bx, EL3_W0_RESOURCE_CFG
    jne     @@Done
@@PersistLive:
    call    Save_State
    jmp     @@Done
@@Done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    ret
ENDP Mock_Reg_Write_Word

PROC Nic_IO_Write_Word NEAR
    push    bx
    push    dx
    push    ax
    call    Mock_Find_Record_By_Port
    jc      @@Absent
    cmp     al, [byte mock_loaded_index]
    je      @@Loaded
    call    Mock_Load_Record_By_Index
    jc      @@Absent
@@Loaded:
    pop     ax
    mov     bx, dx
    sub     bx, [word mock_active_base]
    cmp     bx, EL3_COMMAND
    jne     @@Register
    mov     bx, ax
    and     bx, 0F800h
    cmp     bx, CMD_SELECT_WINDOW
    jne     @@Done
    and     ax, 0007h
    mov     [byte mock_current_window], al
    mov     [byte mock_state_dirty], 1
    call    Save_State
    jmp     @@Done
@@Register:
    call    Mock_Reg_Write_Word
    jmp     @@Done
@@Absent:
    pop     ax
@@Done:
    pop     dx
    pop     bx
    ret
ENDP Nic_IO_Write_Word

PROC Cfg_Reg_Write_Word NEAR
    push    dx
    add     dx, bx
    call    Nic_IO_Write_Word
    pop     dx
    ret
ENDP Cfg_Reg_Write_Word

PROC Nic_Reg_Write_Word NEAR
    call    Cfg_Reg_Write_Word
    ret
ENDP Nic_Reg_Write_Word


PROC Nic_EEPROM_Read NEAR
    push    bx
    push    cx
    push    dx
    push    si

    xor     ah, ah
    mov     si, ax
    xor     al, al
    call    Nic_Select_Window
    mov     ax, si
    and     ax, 003Fh
    or      ax, EEPROM_CMD_READ
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Cfg_Reg_Write_Word
    mov     cx, 4000h
@@Busy:
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Cfg_Reg_Read_Word
    test    ax, EEPROM_BUSY
    jnz     @@Wait
    mov     bx, EL3_W0_EEPROM_DATA
    call    Cfg_Reg_Read_Word
    jmp     @@Done
@@Wait:
    loop    @@Busy
    mov     ax, 0FFFFh
@@Done:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    ret
ENDP Nic_EEPROM_Read

; Automatic configuration is the documented synchronization point between
; persistent EEPROM and live registers.  It does not program Window 2.
PROC Mock_Automatic_Configuration NEAR
    push    ax
    push    bx

    mov     bx, EEPROM_PRODUCT_ID * 2
    mov     ax, [word mock_state + 40h + bx]
    mov     [word mock_state + EL3_W0_PRODUCT_ID], ax
    mov     bx, EEPROM_ADDR_CFG * 2
    mov     ax, [word mock_state + 40h + bx]
    mov     [word mock_state + EL3_W0_ADDRESS_CFG], ax
    mov     bx, EEPROM_RESOURCE_CFG * 2
    mov     ax, [word mock_state + 40h + bx]
    mov     [word mock_state + EL3_W0_RESOURCE_CFG], ax
    mov     [byte mock_current_window], 0
    mov     [word mock_w4_netdiag], 0
    and     [word mock_w4_media_status], NOT W4_MEDIA_STATUS_WRITABLE
    or      [word mock_w4_media_status], W4_MEDIA_STATUS_RESERVED_ONE
    mov     [byte mock_eeprom_busy], 0
    and     [byte mock_eeprom_flags], NOT MCKEF_WRITE_ENABLED
    mov     [byte mock_state_dirty], 1

    pop     bx
    pop     ax
    ret
ENDP Mock_Automatic_Configuration


PROC Nic_Activate_Tagged_Cards NEAR
    push    ax
    push    cx
    push    si

    mov     cx, [card_count]
    or      cx, cx
    jz      @@Done
    mov     si, OFFSET nic_table
@@Loop:
    mov     al, [BYTE si + NIC_TAG]
    or      al, al
    jz      @@Next
    call    Mock_Ensure_Record_By_Tag
    jc      @@Next
    mov     ax, [WORD si + NIC_IO_BASE]
    or      ax, ax
    jz      @@KeepBase
    mov     [word mock_active_base], ax
@@KeepBase:
    mov     [byte mock_active], 1
    mov     [byte mock_state_dirty], 1
    call    Mock_Commit_Loaded_Record
@@Next:
    add     si, NIC_RECORD_SIZE
    loop    @@Loop
    call    Save_State
@@Done:
    pop     si
    pop     cx
    pop     ax
    ret
ENDP Nic_Activate_Tagged_Cards


PROC Nic_Check_3Com_Signature NEAR
    push    cx
    push    dx
    push    si
    push    di

    mov     si, dx
    mov     ch, 0FFh
    xor     bh, bh

    mov     dx, si
    call    Nic_Read_Status
    cmp     ax, 0FFFFh
    je      @@Fail

    mov     dx, si
    call    Nic_Wait_Command_Ready
    jc      @@Fail

    mov     dx, si
    call    Nic_Get_Current_Window
    mov     ch, al

    mov     dx, si
    xor     al, al
    call    Nic_Select_Window

    mov     dx, si
    mov     bx, EL3_W0_MFG_ID
    call    Nic_Reg_Read_Word
    cmp     ax, 06D50h
    je      @@MfgGood
    cmp     ax, 0506Dh
    jne     @@RestoreFail
    mov     bh, 1

@@MfgGood:
    mov     dx, si
    mov     bx, EL3_W0_PRODUCT_ID
    call    Nic_Reg_Read_Word
    cmp     bh, 0
    je      @@ProductOrderGood
    xchg    al, ah
@@ProductOrderGood:
    mov     di, ax
    and     ax, 0F0FFh
    cmp     ax, 09050h
    jne     @@RestoreFail

    mov     dx, si
    mov     al, 4
    call    Nic_Select_Window

    mov     dx, si
    mov     bx, EL3_W4_NET_DIAG
    call    Nic_Reg_Read_Word
    cmp     bh, 0
    je      @@NetDiagOrderGood
    xchg    al, ah
@@NetDiagOrderGood:
    and     ax, 003Eh
    shr     ax, 1
    mov     bl, al

    mov     dx, si
    mov     al, ch
    call    Nic_Select_Window

    mov     ax, di
    pop     di
    pop     si
    pop     dx
    pop     cx
    clc
    ret

@@RestoreFail:
    cmp     ch, 0FFh
    je      @@Fail
    mov     dx, si
    mov     al, ch
    call    Nic_Select_Window
@@Fail:
    pop     di
    pop     si
    pop     dx
    pop     cx
    stc
    ret
ENDP Nic_Check_3Com_Signature

; The documented sequence begins with two zero bytes, then the complete
; 255-byte LFSR stream starting at FFh.  A wrong byte abandons recognition.
PROC Mock_Id_Reset_Sequence NEAR
    mov     [byte mock_id_sequence_expected], 0FFh
    mov     [word mock_id_sequence_count], 0
    mov     [byte mock_id_zero_count], 0
    mov     [byte mock_id_command_ready], 0
    mov     [byte mock_contender_visible], 0
    mov     [byte mock_contender_index], 0FFh
    mov     [byte mock_id_contention_active], 0
    ret
ENDP Mock_Id_Reset_Sequence

; Move every untagged adapter into ID_CMD after a successful ID sequence.
PROC Mock_Id_Enter_Untagged_Command NEAR
    push    ax
    push    cx
    push    di

    xor     ax, ax
    mov     cl, [byte mock_record_count]
    xor     ch, ch
@@Loop:
    or      cx, cx
    jz      @@Done
    push    ax
    call    Mock_Get_Record_Ptr
    pop     ax
    cmp     [BYTE di + MCK3R_PRESENT], 0
    je      @@Next
    cmp     [BYTE di + MCK3R_TAG], 0
    jne     @@Next
    mov     [BYTE di + MCK3R_ID_STATE], MCK_ID_CMD
@@Next:
    inc     al
    dec     cx
    jmp     @@Loop
@@Done:
    pop     di
    pop     cx
    pop     ax
    ret
ENDP Mock_Id_Enter_Untagged_Command

; Input AL = EEPROM word.  Each untagged ID_CMD adapter receives its own
; serial register; subsequent reads implement wired-AND contention.
PROC Mock_Id_Start_Contention_Read NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    di

    and     al, 3Fh
    xor     ah, ah
    shl     ax, 1
    mov     bx, ax
    xor     ax, ax
    mov     cl, [byte mock_record_count]
    xor     ch, ch
@@Loop:
    or      cx, cx
    jz      @@Choose
    push    ax
    call    Mock_Get_Record_Ptr
    pop     ax
    cmp     [BYTE di + MCK3R_PRESENT], 0
    je      @@Next
    cmp     [BYTE di + MCK3R_TAG], 0
    jne     @@Next
    cmp     [BYTE di + MCK3R_ID_STATE], MCK_ID_CMD
    jne     @@Next
    mov     dx, [WORD di + MCK3R_EEPROM + bx]
    mov     [WORD di + MCK3R_ID_SHIFT], dx
    mov     [BYTE di + MCK3R_ID_BITS_LEFT], 16
@@Next:
    inc     al
    dec     cx
    jmp     @@Loop
@@Choose:
    call    Mock_Find_First_Command_Contender
    jc      @@None
    mov     [byte mock_contender_index], al
    mov     [byte mock_contender_visible], 1
    mov     [byte mock_id_contention_active], 1
    jmp     @@Done
@@None:
    mov     [byte mock_contender_visible], 0
    mov     [byte mock_contender_index], 0FFh
    mov     [byte mock_id_contention_active], 0
@@Done:
    pop     di
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Mock_Id_Start_Contention_Read

; Return one open-drain ID bit.  A contender that drives one while another
; drives zero loses and returns to ID_WAIT for the remainder of this round.
PROC Mock_Id_Read_Contention_Bit NEAR
    push    bx
    push    cx
    push    dx
    push    di

    mov     bl, 1
    xor     ax, ax
    mov     cl, [byte mock_record_count]
    xor     ch, ch
@@Observe:
    or      cx, cx
    jz      @@Apply
    push    ax
    call    Mock_Get_Record_Ptr
    pop     ax
    cmp     [BYTE di + MCK3R_ID_STATE], MCK_ID_CMD
    jne     @@ObserveNext
    cmp     [BYTE di + MCK3R_TAG], 0
    jne     @@ObserveNext
    cmp     [BYTE di + MCK3R_ID_BITS_LEFT], 0
    je      @@ObserveNext
    test    [WORD di + MCK3R_ID_SHIFT], 8000h
    jnz     @@ObserveNext
    xor     bl, bl
@@ObserveNext:
    inc     al
    dec     cx
    jmp     @@Observe
@@Apply:
    xor     ax, ax
    mov     cl, [byte mock_record_count]
    xor     ch, ch
@@Shift:
    or      cx, cx
    jz      @@Finish
    push    ax
    call    Mock_Get_Record_Ptr
    pop     ax
    cmp     [BYTE di + MCK3R_ID_STATE], MCK_ID_CMD
    jne     @@ShiftNext
    cmp     [BYTE di + MCK3R_TAG], 0
    jne     @@ShiftNext
    cmp     [BYTE di + MCK3R_ID_BITS_LEFT], 0
    je      @@ShiftNext
    test    [WORD di + MCK3R_ID_SHIFT], 8000h
    jz      @@Advance
    cmp     bl, 0
    jne     @@Advance
    mov     [BYTE di + MCK3R_ID_STATE], MCK_ID_WAIT
@@Advance:
    shl     [WORD di + MCK3R_ID_SHIFT], 1
    dec     [BYTE di + MCK3R_ID_BITS_LEFT]
@@ShiftNext:
    inc     al
    dec     cx
    jmp     @@Shift
@@Finish:
    mov     al, bl
    call    Mock_Find_First_Command_Contender
    jc      @@NoContender
    mov     [byte mock_contender_index], al
    mov     [byte mock_contender_visible], 1
    jmp     @@Done
@@NoContender:
    mov     [byte mock_contender_visible], 0
    mov     [byte mock_id_contention_active], 0
@@Done:
    mov     al, bl
    pop     di
    pop     dx
    pop     cx
    pop     bx
    ret
ENDP Mock_Id_Read_Contention_Bit

; Input AL = one ID-port byte belonging to sequence recognition.
PROC Mock_Id_Process_Sequence_Byte NEAR
    push    ax
    push    bx

    or      al, al
    jnz     @@SequenceByte
    cmp     [byte mock_id_zero_count], 2
    jae     @@Done
    inc     [byte mock_id_zero_count]
    mov     [word mock_id_sequence_count], 0
    mov     [byte mock_id_sequence_expected], 0FFh
    mov     [byte mock_id_command_ready], 0
    jmp     @@Done

@@SequenceByte:
    cmp     [byte mock_id_zero_count], 2
    jne     @@Bad
    cmp     al, [byte mock_id_sequence_expected]
    jne     @@Bad
    inc     [word mock_id_sequence_count]
    mov     bl, al
    test    bl, 80h
    jz      @@ShiftOnly
    shl     bl, 1
    xor     bl, 0CFh
    jmp     @@NextExpected
@@ShiftOnly:
    shl     bl, 1
@@NextExpected:
    mov     [byte mock_id_sequence_expected], bl
    cmp     [word mock_id_sequence_count], 255
    jb      @@Done
    mov     [byte mock_id_command_ready], 1
    call    Mock_Id_Enter_Untagged_Command
    call    Mock_Find_First_Command_Contender
    jc      @@Done
    mov     [byte mock_contender_index], al
    mov     [byte mock_contender_visible], 1
    jmp     @@Done

@@Bad:
    call    Mock_Id_Reset_Sequence
@@Done:
    pop     bx
    pop     ax
    ret
ENDP Mock_Id_Process_Sequence_Byte

PROC Nic_IdPort_Write_Command NEAR
    push    ax
    push    bx
    push    dx
 
    mov     bh, al
    cmp     al, 80h
    jb      @@CheckSetTag
    cmp     al, 0C0h
    jae     @@CheckSetTag
    cmp     [byte mock_contender_visible], 0
    jne     @@ReadContender
    cmp     [byte mock_selected_valid], 0
    je      @@Done
    mov     al, [byte mock_selected_tag]
    call    Mock_Ensure_Record_By_Tag
    jc      @@Done
    cmp     [byte mock_id_state], MCK_ID_CMD
    jne     @@Done
    jmp     @@LoadIdWord
@@ReadContender:
    mov     al, bh
    call    Mock_Id_Start_Contention_Read
    jmp     @@Done
@@LoadIdWord:
    mov     bl, bh
    and     bl, 3Fh
    xor     bh, bh
    shl     bx, 1
    mov     ax, [word mock_state + 40h + bx]
    mov     [word mock_id_shift], ax
    mov     [byte mock_id_bits_left], 16
    jmp     @@Done
@@CheckSetTag:
    mov     bl, al
    and     bl, 0F8h
    cmp     bl, ID_CMD_SET_TAG
    jne     @@CheckSelect
    cmp     [byte mock_contender_visible], 0
    je      @@Done
    mov     al, [byte mock_contender_index]
    call    Mock_Load_Record_By_Index
    jc      @@ClearContender
    cmp     [byte mock_id_state], MCK_ID_CMD
    jne     @@ClearContender
    mov     al, bh
    and     al, 07h
    mov     [byte mock_tag], al
    mov     [byte mock_id_state], MCK_ID_WAIT
    mov     [byte mock_state_dirty], 1
    call    Mock_Commit_Loaded_Record
@@ClearContender:
    mov     [byte mock_contender_visible], 0
    mov     [byte mock_contender_index], 0FFh
    mov     [byte mock_id_contention_active], 0
    jmp     @@Done

@@CheckSelect:
    mov     bl, al
    and     bl, 0F8h
    cmp     bl, ID_CMD_SELECT_TAG
    jne     @@CheckActivate
    and     al, 07h
    mov     dl, al
    cmp     [byte mock_id_command_ready], 0
    je      @@ClearSelected
    call    Mock_Ensure_Record_By_Tag
    jc      @@ClearSelected
    mov     [byte mock_id_state], MCK_ID_CMD
    mov     [byte mock_state_dirty], 1
    call    Mock_Commit_Loaded_Record
    mov     [byte mock_selected_tag], dl
    mov     [byte mock_selected_valid], 1
    mov     [byte mock_id_contention_active], 0
    jmp     @@Done
@@ClearSelected:
    mov     [byte mock_selected_tag], 0
    mov     [byte mock_selected_valid], 0
    jmp     @@Done

@@CheckActivate:
    mov     bl, al
    and     bl, 0E0h
    cmp     bl, ID_CMD_ACTIVATE
    jne     @@CheckDeactivate
    cmp     [byte mock_selected_valid], 0
    je      @@Done
    mov     al, [byte mock_selected_tag]
    call    Mock_Ensure_Record_By_Tag
    jc      @@Done
    cmp     [byte mock_id_state], MCK_ID_CMD
    jne     @@Done
    mov     al, bh
    and     al, 1Fh
    xor     ah, ah
    shl     ax, 1
    shl     ax, 1
    shl     ax, 1
    shl     ax, 1
    add     ax, 0200h
    mov     [word mock_active_base], ax
    mov     [byte mock_active], 1
    mov     [byte mock_id_state], MCK_ID_WAIT
    mov     [byte mock_state_dirty], 1
    call    Save_State
    jmp     @@Done

@@CheckDeactivate:
    cmp     al, ID_CMD_GLOBAL_RESET
    jne     @@Done
    cmp     [byte mock_selected_valid], 0
    je      @@Done
    mov     al, [byte mock_selected_tag]
    call    Mock_Ensure_Record_By_Tag
    jc      @@Done
    cmp     [byte mock_id_state], MCK_ID_CMD
    jne     @@Done
    mov     [byte mock_active], 0
    mov     [word mock_active_base], 0
    mov     [byte mock_tag], 0
    mov     [byte mock_id_state], MCK_ID_WAIT
    call    Mock_Automatic_Configuration
    call    Save_State
@@Done:
    pop     dx
    pop     bx
    pop     ax
    ret
ENDP Nic_IdPort_Write_Command

PROC Nic_IdPort_Send_Full_Sequence NEAR
    push    ax
    push    cx

    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    call    Mock_Id_Reset_Sequence
    xor     al, al
    call    Mock_Id_Process_Sequence_Byte
    call    Mock_Id_Process_Sequence_Byte
    mov     al, 0FFh
    mov     cx, 255
@@Loop:
    call    Mock_Id_Process_Sequence_Byte
    test    al, 80h
    jz      @@ShiftOnly
    shl     al, 1
    xor     al, 0CFh
    jmp     @@Next
@@ShiftOnly:
    shl     al, 1
@@Next:
    loop    @@Loop

    pop     cx
    pop     ax
    ret
ENDP Nic_IdPort_Send_Full_Sequence

PROC Nic_IdPort_Send_Short_Sequence NEAR
    ; Existing CLI flows use the measured short reentry sequence.  Preserve
    ; that compatibility until its exact device-state semantics are verified.
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    mov     [byte mock_id_command_ready], 1
    call    Mock_Find_First_Untagged_Record
    jc      @@NoCard
    mov     [byte mock_contender_index], al
    mov     [byte mock_contender_visible], 1
    call    Mock_Load_Record_By_Index
    jc      @@NoCard
    mov     [byte mock_id_state], MCK_ID_CMD
    mov     [byte mock_state_dirty], 1
    call    Mock_Commit_Loaded_Record
    ret
@@NoCard:
    mov     [byte mock_contender_visible], 0
    mov     [byte mock_contender_index], 0FFh
    ret
ENDP Nic_IdPort_Send_Short_Sequence

PROC Nic_IdPort_Eeprom_Delay NEAR
    ret
ENDP Nic_IdPort_Eeprom_Delay

PROC Nic_Init_Id_Port NEAR
    push    ax
    push    cx
    push    di

    call    Load_State
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    mov     [byte mock_contender_visible], 0
    mov     [byte mock_contender_index], 0FFh
    mov     [byte mock_loaded_index], 0FFh
    mov     [byte mock_state_dirty], 0

    xor     ax, ax
    mov     cl, [byte mock_record_count]
    xor     ch, ch
@@ResetTags:
    or      cx, cx
    jz      @@FindAny
    push    ax
    call    Mock_Get_Record_Ptr
    pop     ax
    cmp     [BYTE di + MCK3R_PRESENT], 0
    je      @@Next
    mov     [BYTE di + MCK3R_TAG], 0
@@Next:
    inc     al
    dec     cx
    jmp     @@ResetTags

@@FindAny:
    call    Mock_Find_First_Untagged_Record
    jc      @@NoCard
    mov     [byte mock_contender_index], al
    mov     [byte mock_contender_visible], 1
    jmp     @@Done
@@NoCard:
    mov     [byte mock_contender_visible], 0
    mov     [byte mock_contender_index], 0FFh
@@Done:
    pop     di
    pop     cx
    pop     ax
    ret
ENDP Nic_Init_Id_Port

PROC Nic_IdPort_Read_Bit NEAR
    cmp     [byte mock_id_contention_active], 0
    je      @@Selected
    call    Mock_Id_Read_Contention_Bit
    ret
@@Selected:
    xor     ax, ax
    cmp     [byte mock_id_bits_left], 0
    je      @@Done
    test    [word mock_id_shift], 8000h
    jz      @@Shift
    mov     al, 1
@@Shift:
    shl     [word mock_id_shift], 1
    dec     [byte mock_id_bits_left]
@@Done:
    ret
ENDP Nic_IdPort_Read_Bit

