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
;   - Multiple simultaneously active records with the same I/O base are
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
    mov     [BYTE di + MCKR_PRESENT], 1
    jmp     @@StoreHeader
@@NoPresent:
    mov     [BYTE di + MCKR_PRESENT], 0
@@StoreHeader:
    mov     al, [byte mock_active]
    mov     [BYTE di + MCKR_ACTIVE], al
    mov     al, [byte mock_tag]
    mov     [BYTE di + MCKR_TAG], al
    mov     [BYTE di + MCKR_ID_MODE], 1
    mov     al, [byte mock_current_window]
    mov     [BYTE di + MCKR_CURRENT_WINDOW], al
    mov     ax, [word mock_active_base]
    mov     [WORD di + MCKR_ACTIVE_BASE], ax
    mov     al, [byte mock_irq]
    mov     [BYTE di + MCKR_IRQ], al

    mov     ax, [word mock_state + EL3_W0_PRODUCT_ID]
    mov     [WORD di + MCKR_PRODUCT_ID], ax
    mov     ax, [word mock_state + EL3_W0_MFG_ID]
    mov     [WORD di + MCKR_LIVE_W0_MFG], ax
    mov     ax, [word mock_state + EL3_W0_PRODUCT_ID]
    mov     [WORD di + MCKR_LIVE_W0_PRODUCT], ax
    mov     ax, [word mock_state + EL3_W0_ADDRESS_CFG]
    mov     [WORD di + MCKR_LIVE_W0_ADDR_CFG], ax
    mov     ax, [word mock_state + EL3_W0_RESOURCE_CFG]
    mov     [WORD di + MCKR_LIVE_W0_RES_CFG], ax
    mov     ax, [word mock_w4_netdiag]
    mov     [WORD di + MCKR_LIVE_W4_NETDIAG], ax
    mov     ax, [word mock_w4_media_status]
    mov     [WORD di + MCKR_LIVE_W4_MEDIA_STATUS], ax

    mov     ax, MCK_CFGF_INT + MCK_CFGF_IOBASE + MCK_CFGF_PORT + MCK_CFGF_PNP + MCK_CFGF_MODEM
    mov     [WORD di + MCKR_CFG_FLAGS], ax
    xor     ah, ah
    mov     al, [byte mock_irq]
    mov     [WORD di + MCKR_CFG_INT], ax
    mov     ax, [word mock_active_base]
    mov     [WORD di + MCKR_CFG_IOBASE], ax
    mov     [WORD di + MCKR_CFG_PORT], ax
    mov     ax, [word mock_state + 40h + (EEPROM_CONFIG_CONTROL * 2)]
    and     ax, 000Ch
    cmp     ax, 0004h
    je      @@StorePnpDisabled
    mov     ax, 1
    jmp     @@StorePnp
@@StorePnpDisabled:
    xor     ax, ax
@@StorePnp:
    mov     [WORD di + MCKR_CFG_PNP], ax
    mov     ax, [word mock_state + 40h + (EEPROM_SOFTWARE_INFO * 2)]
    mov     [WORD di + MCKR_CFG_MODEM], ax
    mov     ax, [word mock_state + 40h + (EEPROM_SOFTWARE_INFO * 2)]
    mov     cl, 15
    shr     ax, cl
    and     ax, 0001h
    mov     [WORD di + MCKR_CFG_FULLDUPLEX], ax

    lea     si, [mock_state + 40h]
    lea     di, [di + MCKR_EEPROM]
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

    mov     al, [BYTE di + MCKR_CURRENT_WINDOW]
    mov     [byte mock_current_window], al
    mov     al, [BYTE di + MCKR_TAG]
    mov     [byte mock_tag], al
    mov     al, [BYTE di + MCKR_IRQ]
    mov     [byte mock_irq], al
    mov     ax, [WORD di + MCKR_ACTIVE_BASE]
    mov     [word mock_active_base], ax
    mov     al, [BYTE di + MCKR_ACTIVE]
    mov     [byte mock_active], al

    mov     ax, [WORD di + MCKR_LIVE_W0_MFG]
    mov     [word mock_state + EL3_W0_MFG_ID], ax
    mov     ax, [WORD di + MCKR_LIVE_W0_PRODUCT]
    mov     [word mock_state + EL3_W0_PRODUCT_ID], ax
    mov     ax, [WORD di + MCKR_LIVE_W0_ADDR_CFG]
    mov     [word mock_state + EL3_W0_ADDRESS_CFG], ax
    mov     ax, [WORD di + MCKR_LIVE_W0_RES_CFG]
    mov     [word mock_state + EL3_W0_RESOURCE_CFG], ax
    mov     ax, [WORD di + MCKR_LIVE_W4_NETDIAG]
    mov     [word mock_w4_netdiag], ax
    mov     ax, [WORD di + MCKR_LIVE_W4_MEDIA_STATUS]
    mov     [word mock_w4_media_status], ax

    lea     si, [di + MCKR_EEPROM]
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
    cmp     [BYTE di + MCKR_PRESENT], 0
    je      @@Next
    cmp     [BYTE di + MCKR_ACTIVE], 0
    je      @@Next
    cmp     [WORD di + MCKR_ACTIVE_BASE], dx
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
    cmp     [BYTE di + MCKR_PRESENT], 0
    je      @@Next
    cmp     [BYTE di + MCKR_TAG], dl
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
    cmp     [BYTE di + MCKR_PRESENT], 0
    je      @@Next
    cmp     [BYTE di + MCKR_TAG], 0
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
    call    Mock_Ensure_Record_By_Base
    jc      @@Absent
    mov     al, [byte mock_active]
    cmp     al, 0
    je      @@Absent
    xor     ax, ax
    mov     al, [byte mock_current_window]
    shl     ax, 13
    and     ax, 0E000h
    jmp     @@Done
@@Absent:
    mov     ax, 0FFFFh
@@Done:
    pop     dx
    ret
ENDP Nic_Read_Status

PROC Nic_Select_Window NEAR
    call    Mock_Ensure_Record_By_Base
    jc      @@Done
    and     al, 07h
    mov     [byte mock_current_window], al
    mov     [byte mock_state_dirty], 1
@@Done:
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

PROC Cfg_Reg_Read_Word NEAR
    push    bx
    push    cx

    call    Mock_Ensure_Record_By_Base
    jc      @@Default
    mov     cl, [byte mock_current_window]
    cmp     cl, 4
    jne     @@Window0
    cmp     bx, EL3_W4_NET_DIAG
    je      @@NetDiag
    cmp     bx, EL3_W4_MEDIA_STATUS
    jne     @@Default
    mov     ax, [word mock_w4_media_status]
    jmp     @@Done
@@NetDiag:
    mov     ax, [word mock_w4_netdiag]
    jmp     @@Done
@@Window0:
    cmp     cl, 0
    jne     @@Default
    cmp     bx, EL3_W0_EEPROM_COMMAND
    jne     @@ReadRaw
    mov     ax, [word mock_state + EL3_W0_EEPROM_COMMAND]
    and     ax, 7FFFh
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
ENDP Cfg_Reg_Read_Word

PROC Nic_Reg_Read_Word NEAR
    call    Cfg_Reg_Read_Word
    ret
ENDP Nic_Reg_Read_Word

PROC Cfg_Reg_Write_Word NEAR
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    call    Mock_Ensure_Record_By_Base
    jc      @@Done
    mov     cl, [byte mock_current_window]
    cmp     cl, 4
    jne     @@Window0
    cmp     bx, EL3_W4_NET_DIAG
    jne     @@Done
    mov     [word mock_w4_netdiag], ax
    mov     [byte mock_state_dirty], 1
    call    Save_State
    jmp     @@Done
@@Window0:
    cmp     cl, 0
    jne     @@Done
    cmp     bx, EL3_W0_EEPROM_COMMAND
    jne     @@StoreDirect
    mov     [word mock_state + EL3_W0_EEPROM_COMMAND], ax
    mov     [byte mock_state_dirty], 1
    mov     dx, ax
    and     dx, 00C0h
    cmp     dx, 0080h
    jne     @@CheckEepromWrite
    mov     dx, ax
    and     dx, 003Fh
    mov     si, OFFSET mock_state + 40h
    mov     di, dx
    shl     di, 1
    add     si, di
    mov     dx, [word si]
    mov     [word mock_state + EL3_W0_EEPROM_DATA], dx
    jmp     @@Done
@@CheckEepromWrite:
    cmp     dx, 0040h
    jne     @@Done
    mov     dx, ax
    and     dx, 003Fh
    mov     cx, dx
    mov     si, OFFSET mock_state + 40h
    mov     di, dx
    shl     di, 1
    add     si, di
    mov     dx, [word mock_state + EL3_W0_EEPROM_DATA]
    mov     [word si], dx
    cmp     cx, EEPROM_ADDR_CFG
    jne     @@MaybeResCfg
    mov     [word mock_state + EL3_W0_ADDRESS_CFG], dx
    jmp     @@Persist
@@MaybeResCfg:
    cmp     cx, EEPROM_RESOURCE_CFG
    jne     @@Persist
    mov     [word mock_state + EL3_W0_RESOURCE_CFG], dx
@@Persist:
    mov     [byte mock_state_dirty], 1
    call    Save_State
    jmp     @@Done
@@StoreDirect:
    mov     [word mock_state + bx], ax
    mov     [byte mock_state_dirty], 1
    cmp     bx, EL3_W0_ADDRESS_CFG
    je      @@PersistLive
    cmp     bx, EL3_W0_RESOURCE_CFG
    jne     @@Done
@@PersistLive:
    call    Save_State
@@Done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    ret
ENDP Cfg_Reg_Write_Word

PROC Nic_Reg_Write_Word NEAR
    call    Cfg_Reg_Write_Word
    ret
ENDP Nic_Reg_Write_Word


PROC Nic_EEPROM_Read NEAR
    push    bx

    call    Mock_Ensure_Record_By_Base
    jc      @@Absent
    xor     ah, ah
    mov     bl, al
    xor     bh, bh
    shl     bx, 1
    mov     ax, [word mock_state + 40h + bx]
    pop     bx
    ret
@@Absent:
    mov     ax, 0FFFFh
    pop     bx
    ret
ENDP Nic_EEPROM_Read


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

PROC Nic_IdPort_Write_Command NEAR
    push    ax
    push    bx
 
    mov     bh, al
    mov     bl, al
    and     bl, 0F8h
    cmp     bl, ID_CMD_SET_TAG
    jne     @@CheckSelect
    cmp     [byte mock_contender_visible], 0
    je      @@Done
    mov     al, [byte mock_contender_index]
    call    Mock_Load_Record_By_Index
    jc      @@ClearContender
    mov     al, bh
    and     al, 07h
    mov     [byte mock_tag], al
    mov     [byte mock_state_dirty], 1
    call    Mock_Commit_Loaded_Record
@@ClearContender:
    mov     [byte mock_contender_visible], 0
    mov     [byte mock_contender_index], 0FFh
    jmp     @@Done

@@CheckSelect:
    mov     bl, al
    and     bl, 0F8h
    cmp     bl, ID_CMD_SELECT_TAG
    jne     @@CheckActivate
    and     al, 07h
    mov     [byte mock_selected_tag], al
    mov     [byte mock_selected_valid], 1
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
    mov     [byte mock_state_dirty], 1
    call    Save_State
    jmp     @@Done

@@CheckDeactivate:
    cmp     al, 0C0h
    jne     @@Done
    cmp     [byte mock_selected_valid], 0
    je      @@Done
    mov     al, [byte mock_selected_tag]
    call    Mock_Ensure_Record_By_Tag
    jc      @@Done
    mov     [byte mock_active], 0
    mov     [byte mock_state_dirty], 1
    call    Save_State
@@Done:
    pop     bx
    pop     ax
    ret
ENDP Nic_IdPort_Write_Command

PROC Nic_IdPort_Send_Full_Sequence NEAR
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    call    Mock_Find_First_Untagged_Record
    jc      @@NoCard
    mov     [byte mock_contender_index], al
    mov     [byte mock_contender_visible], 1
    ret
@@NoCard:
    mov     [byte mock_contender_visible], 0
    mov     [byte mock_contender_index], 0FFh
    ret
ENDP Nic_IdPort_Send_Full_Sequence

PROC Nic_IdPort_Send_Short_Sequence NEAR
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    call    Mock_Find_First_Untagged_Record
    jc      @@NoCard
    mov     [byte mock_contender_index], al
    mov     [byte mock_contender_visible], 1
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
    cmp     [BYTE di + MCKR_PRESENT], 0
    je      @@Next
    mov     [BYTE di + MCKR_TAG], 0
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

PROC Nic_IdPort_Read_Word NEAR
    push    bx

    cmp     [byte mock_contender_visible], 0
    jne     @@UseContender
    cmp     [byte mock_selected_valid], 0
    je      @@Absent
    mov     ah, al
    mov     al, [byte mock_selected_tag]
    call    Mock_Ensure_Record_By_Tag
    jc      @@RestoreAbsent
    mov     al, ah
    jmp     @@ReadWord
@@UseContender:
    mov     ah, al
    mov     al, [byte mock_contender_index]
    call    Mock_Load_Record_By_Index
    jc      @@RestoreAbsent
    mov     al, ah
@@ReadWord:
    xor     ah, ah
    mov     bl, al
    xor     bh, bh
    shl     bx, 1
    mov     ax, [word mock_state + 40h + bx]
    pop     bx
    ret
@@RestoreAbsent:
    mov     ax, 0FFFFh
    pop     bx
    ret
@@Absent:
    mov     ax, 0FFFFh
    pop     bx
    ret
ENDP Nic_IdPort_Read_Word

