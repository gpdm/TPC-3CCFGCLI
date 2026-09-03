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
; ID-port scratch state classification (see PRIMARY NEXT GOAL item 10):
;
;   Per-adapter hardware state (already lives in the MCK v3 record, not in
;   global scratch): MCK3R_ID_STATE, MCK3R_TAG, MCK3R_ID_SHIFT,
;   MCK3R_ID_BITS_LEFT (per-record contention shift registers used by
;   Mock_Id_Start_Contention_Read / Mock_Id_Read_Contention_Bit so that
;   wired-AND contention across multiple untagged adapters is genuinely
;   per-adapter), MCK3R_FLAGS (active/coax-started), MCK3R_ACTIVE_BASE.
;
;   Shared ID-bus state (global by nature -- there is exactly one ID port
;   and at most one adapter can be "the currently addressed target" of a
;   non-contention operation at a time, mirroring how mock_state/
;   mock_current_window already represent "whichever record is loaded"):
;   mock_id_shift/mock_id_bits_left (serial shift register for a single
;   explicitly-tagged/selected adapter's direct EEPROM word reads --
;   distinct from the per-record contention shift registers above, which
;   already correctly live in the file-backed record because contention
;   genuinely spans multiple simultaneous adapters), mock_contender_index/
;   mock_contender_visible/mock_id_contention_active (which record, if any,
;   is still contending), mock_selected_tag/mock_selected_valid (which tag
;   was isolated by the last SELECT_TAG, used to route direct EEPROM reads
;   -- see @@ReadContender in Nic_IdPort_Write_Command), mock_byte_pair_*
;   (host-side byte-pair assembly state; see its own declaration comment
;   below).
;
;   Temporary host-side scratch (sequence recognition bookkeeping that has
;   no per-adapter meaning at all, since every untagged adapter tracks the
;   SAME 255-byte LFSR stream identically): mock_id_sequence_expected,
;   mock_id_sequence_count, mock_id_zero_count, mock_id_command_ready.
;
;   This split already matches the current implementation; no fields were
;   moved as part of this pass.  Do not mechanically relocate the "shared
;   ID-bus state" items into the per-record structure: they describe the
;   bus/host session, not an individual chip's storage.
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
; Window 2 live station-address bytes (EL3_W2_STATION_0/1/2).  Independent
; of the EEPROM node-address words; never auto-loaded on reset.
mock_w2_station DB 6 DUP (0)
; Window 3 live 32-bit Internal Configuration register, loaded ONLY from
; EEPROM words 12h/13h during Mock_Automatic_Configuration (documented
; reset/auto-config load point).  Not continuously mirrored from EEPROM.
mock_w3_config_lo DW 0000h
mock_w3_config_hi DW 0000h
; Command-In-Progress model (Status Register bit 12).  A command that
; "logically requires completion polling" sets this to a small nonzero
; count; each Status read reports the bit while nonzero and decrements it,
; giving a deterministic "busy once, then clear" observation.
mock_command_busy DB 0
; Mirrors MCK3R_FLAGS bit MCKRF_COAX_STARTED, the same way mock_active
; mirrors MCKRF_ACTIVE.  Set by a (currently unreachable) Start Coaxial
; Transceiver command; configuration-visible state only, no analog model.
mock_coax_started DB 0
; Generic byte-pair state for every configuration-facing 16-bit register.
; A pair is valid only when the high byte immediately follows the low byte
; of the same register, adapter, window, and access direction.  The low
; write is held until completion; the low read latches one coherent word.
mock_byte_pair_pending DB 0
mock_byte_pair_index DB 0FFh
mock_byte_pair_offset DW 0000h
mock_byte_pair_window DB 0
mock_byte_pair_write DB 0
mock_byte_pair_low DB 0
mock_byte_pair_word DW 0000h

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
    mov     [word mock_w3_config_lo], 0
    mov     [word mock_w3_config_hi], 0
    mov     [byte mock_command_busy], 0
    mov     [byte mock_coax_started], 0
    mov     [word mock_w2_station + 0], 0
    mov     [word mock_w2_station + 2], 0
    mov     [word mock_w2_station + 4], 0

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
    mov     [byte mock_byte_pair_pending], 0
    mov     [byte mock_byte_pair_index], 0FFh
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
    mov     ah, 0
    cmp     [byte mock_active], 0
    je      @@FlagsCoax
    or      ah, MCKRF_ACTIVE
@@FlagsCoax:
    cmp     [byte mock_coax_started], 0
    je      @@FlagsDone
    or      ah, MCKRF_COAX_STARTED
@@FlagsDone:
    mov     [BYTE di + MCK3R_FLAGS], ah
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
    mov     al, [byte mock_command_busy]
    mov     [BYTE di + MCK3R_COMMAND_BUSY], al
    mov     ax, [word mock_w2_station + 0]
    mov     [WORD di + MCK3R_W2_STATION + 0], ax
    mov     ax, [word mock_w2_station + 2]
    mov     [WORD di + MCK3R_W2_STATION + 2], ax
    mov     ax, [word mock_w2_station + 4]
    mov     [WORD di + MCK3R_W2_STATION + 4], ax
    mov     ax, [word mock_w3_config_lo]
    mov     [WORD di + MCK3R_W3_INTERNAL_CONFIG + 0], ax
    mov     ax, [word mock_w3_config_hi]
    mov     [WORD di + MCK3R_W3_INTERNAL_CONFIG + 2], ax

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
    mov     al, [BYTE di + MCK3R_FLAGS]
    and     al, MCKRF_COAX_STARTED
    mov     [byte mock_coax_started], al

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
    mov     al, [BYTE di + MCK3R_COMMAND_BUSY]
    mov     [byte mock_command_busy], al
    mov     ax, [WORD di + MCK3R_W2_STATION + 0]
    mov     [word mock_w2_station + 0], ax
    mov     ax, [WORD di + MCK3R_W2_STATION + 2]
    mov     [word mock_w2_station + 2], ax
    mov     ax, [WORD di + MCK3R_W2_STATION + 4]
    mov     [word mock_w2_station + 4], ax
    mov     ax, [WORD di + MCK3R_W3_INTERNAL_CONFIG + 0]
    mov     [word mock_w3_config_lo], ax
    mov     ax, [WORD di + MCK3R_W3_INTERNAL_CONFIG + 2]
    mov     [word mock_w3_config_hi], ax

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
    push    cx
    call    Nic_Read_Status
    mov     cl, 13
    shr     ax, cl
    and     ax, 0007h
    pop     cx
    ret
ENDP Nic_Get_Current_Window

; Polls the modeled Status Register (bit 12, Command In Progress) instead of
; being an unconditional success stub.  The mock's busy model is a small,
; deterministic decrement (see Mock_Resolve_And_Read_Word), so a small bound
; is sufficient; this is not a timing simulation.
PROC Nic_Wait_Command_Ready NEAR
    push    ax
    push    cx
    push    dx
    mov     cx, 0010h
@@Wait:
    call    Nic_Read_Status
    test    ax, STATUS_CMD_BUSY
    jz      @@Ready
    loop    @@Wait
    pop     dx
    pop     cx
    pop     ax
    stc
    ret
@@Ready:
    pop     dx
    pop     cx
    pop     ax
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
;
; Reachable-code audit (see PRIMARY NEXT GOAL item 11): 3CCFGCLI, 3CSEED,
; and Nic_EEPROM_Read only ever exercise READ (EEPROM_CMD_READ), Write
; Enable/Disable (EEPROM_CMD_WRITE_ENABLE / bits 5:4 clear), ERASE WORD
; (EEPROM_CMD_ERASE), and WRITE WORD (EEPROM_CMD_WRITE).  ERASE ALL, WRITE
; ALL, and an explicit EWDS-distinct-from-plain-disable variant are not
; used by any reachable path, so they are deliberately not implemented;
; this keeps Stage 1 scoped to what is actually exercised.
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
    je      @@Window4
    cmp     cl, 0
    je      @@Window0
    cmp     cl, 2
    je      @@Window2
    cmp     cl, 3
    je      @@Window3
    jmp     @@Default
@@Window4:
    cmp     bx, EL3_W4_NETWORK_DIAGNOSTIC
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
    cmp     bx, EL3_W0_EEPROM_COMMAND
    jne     @@ReadRaw
    call    Mock_Eeprom_Read_Command
    jmp     @@Done
@@ReadRaw:
    mov     ax, [word mock_state + bx]
    jmp     @@Done
@@Window2:
    ; Live station address; independent of EEPROM, never auto-loaded.
    cmp     bx, EL3_W2_STATION_0
    je      @@ReadW2_0
    cmp     bx, EL3_W2_STATION_1
    je      @@ReadW2_1
    cmp     bx, EL3_W2_STATION_2
    jne     @@Default
    mov     ax, [word mock_w2_station + 4]
    jmp     @@Done
@@ReadW2_0:
    mov     ax, [word mock_w2_station + 0]
    jmp     @@Done
@@ReadW2_1:
    mov     ax, [word mock_w2_station + 2]
    jmp     @@Done
@@Window3:
    ; Live Internal Configuration; loaded only by Mock_Automatic_Configuration.
    cmp     bx, EL3_W3_INTERNAL_CONFIG_0
    je      @@ReadW3Lo
    cmp     bx, EL3_W3_INTERNAL_CONFIG_1
    jne     @@Default
    mov     ax, [word mock_w3_config_hi]
    jmp     @@Done
@@ReadW3Lo:
    mov     ax, [word mock_w3_config_lo]
    jmp     @@Done
@@Default:
    ; Unsupported/reserved windows and offsets remain conservative (0).
    xor     ax, ax
@@Done:
    pop     cx
    pop     bx
    ret
ENDP Mock_Reg_Read_Word

; Shared word-level register resolution used by both Nic_IO_Read_Word and
; Nic_IO_Read_Byte, once the physical port has already been resolved to a
; loaded record.  Input BX = even offset within the 16-byte adapter region.
PROC Mock_Resolve_And_Read_Word NEAR
    cmp     bx, EL3_STATUS
    jne     @@RegisterPath
    xor     ax, ax
    mov     al, [byte mock_current_window]
    shl     ax, 13
    and     ax, STATUS_WINDOW_MASK
    cmp     [byte mock_command_busy], 0
    je      @@ResolveDone
    or      ax, STATUS_CMD_BUSY
    dec     [byte mock_command_busy]
    mov     [byte mock_state_dirty], 1
    call    Save_State
    jmp     @@ResolveDone
@@RegisterPath:
    call    Mock_Reg_Read_Word
@@ResolveDone:
    ret
ENDP Mock_Resolve_And_Read_Word

; A word access is an intervening access for any outstanding byte pair on
; this adapter.  Accesses to other adapters do not invalidate the pair.
PROC Mock_Byte_Pair_Invalidate_Current NEAR
    push    ax
    cmp     [byte mock_byte_pair_pending], 0
    je      @@Done
    mov     al, [byte mock_loaded_index]
    cmp     al, [byte mock_byte_pair_index]
    jne     @@Done
    mov     [byte mock_byte_pair_pending], 0
@@Done:
    pop     ax
    ret
ENDP Mock_Byte_Pair_Invalidate_Current

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
    call    Mock_Byte_Pair_Invalidate_Current
    pop     dx
    push    dx
    mov     bx, dx
    sub     bx, [word mock_active_base]
    call    Mock_Resolve_And_Read_Word
    jmp     @@Done
@@Absent:
    mov     ax, 0FFFFh
@@Done:
    pop     dx
    pop     bx
    ret
ENDP Nic_IO_Read_Word

; Byte-wide equivalent of Nic_IO_Read_Word.  Reads use the same physical
; dispatch as word access, but a low-byte read snapshots one coherent word
; and only the immediate matching high-byte read consumes that snapshot.
PROC Nic_IO_Read_Byte NEAR
    push    bx
    push    cx
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
    mov     cl, bl
    and     cl, 01h
    and     bx, 0FFFEh
    or      cl, cl
    jz      @@Low
    cmp     [byte mock_byte_pair_pending], 0
    je      @@InvalidHigh
    mov     al, [byte mock_loaded_index]
    cmp     al, [byte mock_byte_pair_index]
    jne     @@InvalidHigh
    cmp     [word mock_byte_pair_offset], bx
    jne     @@InvalidHigh
    mov     al, [byte mock_current_window]
    cmp     al, [byte mock_byte_pair_window]
    jne     @@InvalidHigh
    cmp     [byte mock_byte_pair_write], 0
    jne     @@InvalidHigh
    mov     ax, [word mock_byte_pair_word]
    mov     [byte mock_byte_pair_pending], 0
    mov     al, ah
    xor     ah, ah
    jmp     @@Done
@@InvalidHigh:
    call    Mock_Byte_Pair_Invalidate_Current
    call    Mock_Resolve_And_Read_Word
    mov     al, ah
    xor     ah, ah
    jmp     @@Done
@@Low:
    call    Mock_Byte_Pair_Invalidate_Current
    call    Mock_Resolve_And_Read_Word
    mov     [word mock_byte_pair_word], ax
    mov     al, [byte mock_loaded_index]
    mov     [byte mock_byte_pair_index], al
    mov     [word mock_byte_pair_offset], bx
    mov     al, [byte mock_current_window]
    mov     [byte mock_byte_pair_window], al
    mov     [byte mock_byte_pair_write], 0
    mov     [byte mock_byte_pair_pending], 1
    xor     ah, ah
    jmp     @@Done
@@Absent:
    mov     ax, 00FFh
@@Done:
    pop     dx
    pop     cx
    pop     bx
    ret
ENDP Nic_IO_Read_Byte

PROC Nic_Reg_Read_Word NEAR
    push    dx
    add     dx, bx
    call    Nic_IO_Read_Word
    pop     dx
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
    je      @@Window4
    cmp     cl, 0
    je      @@Window0
    cmp     cl, 2
    je      @@Window2
    cmp     cl, 3
    je      @@Window3
    jmp     @@Done
@@Window4:
    cmp     bx, EL3_W4_NETWORK_DIAGNOSTIC
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
@@Window2:
    ; Live station address; independent of EEPROM, plain read/write storage.
    cmp     bx, EL3_W2_STATION_0
    jne     @@W2Chk1
    mov     [word mock_w2_station + 0], ax
    jmp     @@W2Store
@@W2Chk1:
    cmp     bx, EL3_W2_STATION_1
    jne     @@W2Chk2
    mov     [word mock_w2_station + 2], ax
    jmp     @@W2Store
@@W2Chk2:
    cmp     bx, EL3_W2_STATION_2
    jne     @@Done
    mov     [word mock_w2_station + 4], ax
@@W2Store:
    mov     [byte mock_state_dirty], 1
    call    Save_State
    jmp     @@Done
@@Window3:
    ; Live Internal Configuration; each 16-bit half is plain read/write
    ; storage.  Reset/automatic configuration (not this write path) is the
    ; only place EEPROM words 12h/13h feed this register; see
    ; Mock_Automatic_Configuration.
    cmp     bx, EL3_W3_INTERNAL_CONFIG_0
    jne     @@W3Chk1
    mov     [word mock_w3_config_lo], ax
    jmp     @@W3Store
@@W3Chk1:
    cmp     bx, EL3_W3_INTERNAL_CONFIG_1
    jne     @@Done
    mov     [word mock_w3_config_hi], ax
@@W3Store:
    mov     [byte mock_state_dirty], 1
    call    Save_State
@@Done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    ret
ENDP Mock_Reg_Write_Word

; Central Command Register (EL3_COMMAND, offset 0Eh) decoder.  Input AX =
; the full 16-bit command word; the addressed adapter's record must
; already be the loaded scratch record.  Both the word write path
; (Nic_IO_Write_Word) and the bytewise assembly path (Nic_IO_Write_Byte,
; once the high byte completes a pending pair) dispatch through here, so
; there is exactly one command decoder regardless of access width.
;
; Select Window is the only opcode reachable from current 3CCFGCLI code.
; Global Reset and Start Coaxial Transceiver are modeled for architectural
; completeness (see 3C509DEF.INC CMD_GLOBAL_RESET/CMD_START_COAX) but are
; not presently issued by any 3CCFGCLI code path.  Unrecognized opcodes are
; conservatively ignored, matching "do not implement unrelated commands".
PROC Mock_Command_Register_Write NEAR
    push    bx

    mov     bx, ax
    and     bx, CMD_OPCODE_MASK
    cmp     bx, CMD_SELECT_WINDOW
    jne     @@CheckGlobalReset
    and     ax, 0007h
    mov     [byte mock_current_window], al
    mov     [byte mock_state_dirty], 1
    call    Save_State
    jmp     @@CmdDone
@@CheckGlobalReset:
    cmp     bx, CMD_GLOBAL_RESET
    jne     @@CheckStartCoax
    ; Command-register Global Reset is a power-on-reset-equivalent reset:
    ; it removes the active ISA decode as well as reloading live state.
    ; The access that issued this command is intentionally its final access
    ; at the old base until a subsequent normal ID-port activation.
    call    Mock_Reset_Loaded_Record
    call    Save_State
    jmp     @@CmdDone
@@CheckStartCoax:
    cmp     bx, CMD_START_COAX
    jne     @@CmdDone
    mov     [byte mock_coax_started], 1
    mov     [byte mock_state_dirty], 1
    call    Save_State
@@CmdDone:
    pop     bx
    ret
ENDP Mock_Command_Register_Write

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
    call    Mock_Byte_Pair_Invalidate_Current
    pop     ax
    mov     bx, dx
    sub     bx, [word mock_active_base]
    cmp     bx, EL3_COMMAND
    jne     @@Register
    call    Mock_Command_Register_Write
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

; Byte-wide equivalent of Nic_IO_Write_Word.  A low byte starts a pending
; 16-bit write; no register effect occurs until the immediate matching high
; byte completes it.  This applies equally to Command and normal registers.
PROC Nic_IO_Write_Byte NEAR
    push    bx
    push    cx
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
    mov     cl, bl
    and     cl, 01h
    and     bx, 0FFFEh
    or      cl, cl
    jz      @@Low
    cmp     [byte mock_byte_pair_pending], 0
    je      @@InvalidHigh
    mov     cl, [byte mock_loaded_index]
    cmp     cl, [byte mock_byte_pair_index]
    jne     @@InvalidHigh
    cmp     [word mock_byte_pair_offset], bx
    jne     @@InvalidHigh
    mov     cl, [byte mock_current_window]
    cmp     cl, [byte mock_byte_pair_window]
    jne     @@InvalidHigh
    cmp     [byte mock_byte_pair_write], 1
    jne     @@InvalidHigh
    mov     ah, al
    mov     al, [byte mock_byte_pair_low]
    mov     [byte mock_byte_pair_pending], 0
    cmp     bx, EL3_COMMAND
    jne     @@RegisterComplete
    call    Mock_Command_Register_Write
    jmp     @@Done
@@RegisterComplete:
    call    Mock_Reg_Write_Word
    jmp     @@Done
@@InvalidHigh:
    ; A high byte without an immediate matching low byte is discarded.
    ; It cannot complete a read-direction pair or one for another register.
    call    Mock_Byte_Pair_Invalidate_Current
    jmp     @@Done
@@Low:
    call    Mock_Byte_Pair_Invalidate_Current
    mov     [byte mock_byte_pair_low], al
    mov     al, [byte mock_loaded_index]
    mov     [byte mock_byte_pair_index], al
    mov     [word mock_byte_pair_offset], bx
    mov     al, [byte mock_current_window]
    mov     [byte mock_byte_pair_window], al
    mov     [byte mock_byte_pair_write], 1
    mov     [byte mock_byte_pair_pending], 1
    jmp     @@Done
@@Absent:
    pop     ax
@@Done:
    pop     dx
    pop     cx
    pop     bx
    ret
ENDP Nic_IO_Write_Byte

PROC Nic_Reg_Write_Word NEAR
    push    dx
    add     dx, bx
    call    Nic_IO_Write_Word
    pop     dx
    ret
ENDP Nic_Reg_Write_Word


; Input:  DX = adapter base, AL = EEPROM word address.
; Output: Success -> CF clear, AX = EEPROM word.
;         Timeout -> CF set, AX is unspecified and must not be used.
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
    call    Nic_Reg_Write_Word
    mov     cx, 4000h
@@Busy:
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Nic_Reg_Read_Word
    test    ax, EEPROM_BUSY
    jnz     @@Wait
    mov     bx, EL3_W0_EEPROM_DATA
    call    Nic_Reg_Read_Word
    clc
    jmp     @@Done
@@Wait:
    loop    @@Busy
    mov     ax, 0FFFFh
    stc
@@Done:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    ret
ENDP Nic_EEPROM_Read

; Automatic configuration is the documented synchronization point between
; persistent EEPROM and live registers.  It does not program Window 2.
; Window 3 Internal Configuration IS loaded here (EEPROM words 12h/13h),
; per 3C509DEF.INC; it is not continuously mirrored from EEPROM otherwise.
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
    mov     bx, EEPROM_INTERNAL_CONFIG_LO * 2
    mov     ax, [word mock_state + 40h + bx]
    mov     [word mock_w3_config_lo], ax
    mov     bx, EEPROM_CONFIG_CONTROL * 2
    mov     ax, [word mock_state + 40h + bx]
    mov     [word mock_w3_config_hi], ax
    mov     [byte mock_current_window], 0
    mov     [word mock_w4_netdiag], 0
    and     [word mock_w4_media_status], NOT W4_MEDIA_STATUS_WRITABLE
    or      [word mock_w4_media_status], W4_MEDIA_STATUS_RESERVED_ONE
    mov     [byte mock_eeprom_busy], 0
    and     [byte mock_eeprom_flags], NOT MCKEF_WRITE_ENABLED
    mov     [byte mock_eeprom_pending], 0
    mov     [byte mock_command_busy], 0
    mov     [byte mock_coax_started], 0
    mov     [byte mock_state_dirty], 1

    pop     bx
    pop     ax
    ret
ENDP Mock_Automatic_Configuration

; Reset the currently loaded adapter to the configuration-facing
; power-on-reset state.  This is intentionally shared by Command Register
; Global Reset and ID-port Global Reset; callers retain responsibility for
; deciding which adapter(s) receive that reset.
PROC Mock_Reset_Loaded_Record NEAR
    mov     [byte mock_active], 0
    mov     [word mock_active_base], 0
    mov     [byte mock_tag], 0
    mov     [byte mock_id_state], MCK_ID_WAIT
    mov     [word mock_id_shift], 0
    mov     [byte mock_id_bits_left], 0
    call    Mock_Automatic_Configuration
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    mov     [byte mock_byte_pair_pending], 0
    ret
ENDP Mock_Reset_Loaded_Record


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
    mov     bx, EL3_W4_NETWORK_DIAGNOSTIC
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

; A successful supported ID re-entry sequence returns every present adapter
; to ID_CMD.
; Tagged adapters still do not participate in untagged EEPROM contention;
; Mock_Id_Start_Contention_Read filters them by tag, while D8h-DFh can
; subsequently narrow the ID_CMD population to one tag.
PROC Mock_Id_Enter_Command NEAR
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
ENDP Mock_Id_Enter_Command

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
    call    Mock_Id_Enter_Command
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

; Broadcast ID-port Global Reset (C0h-CFh): every record currently in
; MCK_ID_CMD is reset to its documented power-on-reset state (live
; registers reloaded from EEPROM via Mock_Automatic_Configuration, tag and
; active-decode state cleared, ID state machine returned to ID_WAIT).
; Records not currently in MCK_ID_CMD are untouched.
PROC Mock_Id_Global_Reset_All NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    di

    call    Mock_Commit_Loaded_Record

    mov     bl, [byte mock_record_count]
    xor     dl, dl
@@ScanLoop:
    cmp     dl, bl
    jae     @@ScanDone
    mov     al, dl
    call    Mock_Get_Record_Ptr
    cmp     [BYTE di + MCK3R_PRESENT], 0
    je      @@ScanNext
    cmp     [BYTE di + MCK3R_ID_STATE], MCK_ID_CMD
    jne     @@ScanNext
    mov     al, dl
    call    Mock_Load_Record_By_Index
    jc      @@ScanNext
    call    Mock_Reset_Loaded_Record
    call    Mock_Commit_Loaded_Record
@@ScanNext:
    inc     dl
    jmp     @@ScanLoop
@@ScanDone:
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    mov     [byte mock_loaded_index], 0FFh
    call    Save_State
    pop     di
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Mock_Id_Global_Reset_All

; ID_CMD D8h-DFh is a bus command.  Every adapter presently in ID_CMD
; observes it; only the matching tag remains in that state.  selected_* is
; retained only to route subsequent direct EEPROM serial reads, never as the
; authority for later activation.
; Input AL = selected tag.
PROC Mock_Id_Select_Tag NEAR
    push    ax
    push    bx
    push    dx
    push    di

    mov     dh, al
    call    Mock_Commit_Loaded_Record
    mov     bl, [byte mock_record_count]
    xor     dl, dl
    mov     [byte mock_selected_valid], 0
@@Loop:
    cmp     dl, bl
    jae     @@Done
    mov     al, dl
    call    Mock_Get_Record_Ptr
    cmp     [BYTE di + MCK3R_PRESENT], 0
    je      @@Next
    cmp     [BYTE di + MCK3R_ID_STATE], MCK_ID_CMD
    jne     @@Next
    cmp     [BYTE di + MCK3R_TAG], dh
    je      @@Match
    mov     [BYTE di + MCK3R_ID_STATE], MCK_ID_WAIT
    jmp     @@Next
@@Match:
    mov     [byte mock_selected_tag], dh
    mov     [byte mock_selected_valid], 1
@@Next:
    inc     dl
    jmp     @@Loop
@@Done:
    mov     [byte mock_loaded_index], 0FFh
    call    Save_State
    pop     di
    pop     dx
    pop     bx
    pop     ax
    ret
ENDP Mock_Id_Select_Tag

; Broadcast an ID-port Activate command to every adapter presently in
; ID_CMD.  Input AL = explicit E0h-FEh selector; AH nonzero requests FFh
; configured-base activation.  The adapter's own live Address Configuration
; supplies the FFh selector, so selected_* does not authorize activation.
PROC Mock_Id_Activate_Eligible NEAR
    push    ax
    push    bx
    push    dx
    push    di

    mov     dh, al
    mov     dl, ah
    call    Mock_Commit_Loaded_Record
    mov     bl, [byte mock_record_count]
    xor     bh, bh
@@Loop:
    cmp     bh, bl
    jae     @@Done
    mov     al, bh
    call    Mock_Get_Record_Ptr
    cmp     [BYTE di + MCK3R_PRESENT], 0
    je      @@Next
    cmp     [BYTE di + MCK3R_ID_STATE], MCK_ID_CMD
    jne     @@Next
    or      dl, dl
    jz      @@Explicit
    mov     ax, [WORD di + MCK3R_W0_ADDRESS_CFG]
    and     ax, 001Fh
    jmp     @@MakeBase
@@Explicit:
    xor     ax, ax
    mov     al, dh
    and     ax, 001Fh
@@MakeBase:
    shl     ax, 1
    shl     ax, 1
    shl     ax, 1
    shl     ax, 1
    add     ax, 0200h
    mov     [WORD di + MCK3R_ACTIVE_BASE], ax
    or      [BYTE di + MCK3R_FLAGS], MCKRF_ACTIVE
    mov     [BYTE di + MCK3R_ID_STATE], MCK_ID_WAIT
@@Next:
    inc     bh
    jmp     @@Loop
@@Done:
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    mov     [byte mock_loaded_index], 0FFh
    call    Save_State
    pop     di
    pop     dx
    pop     bx
    pop     ax
    ret
ENDP Mock_Id_Activate_Eligible

; The documented initialization sequence uses D0h (Set Tag 0) after each
; re-entry sequence to return adapters to the untagged ID_WAIT population.
; This changes powered state through the modeled ID command, never merely
; because the backend was loaded for a new DOS process.
PROC Mock_Id_Clear_All_Tags NEAR
    push    ax
    push    bx
    push    dx
    push    di

    call    Mock_Commit_Loaded_Record
    mov     bl, [byte mock_record_count]
    xor     dl, dl
@@Loop:
    cmp     dl, bl
    jae     @@Done
    mov     al, dl
    call    Mock_Get_Record_Ptr
    cmp     [BYTE di + MCK3R_PRESENT], 0
    je      @@Next
    mov     [BYTE di + MCK3R_TAG], 0
    mov     [BYTE di + MCK3R_ID_STATE], MCK_ID_WAIT
@@Next:
    inc     dl
    jmp     @@Loop
@@Done:
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    mov     [byte mock_loaded_index], 0FFh
    call    Save_State
    pop     di
    pop     dx
    pop     bx
    pop     ax
    ret
ENDP Mock_Id_Clear_All_Tags

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
    cmp     al, ID_CMD_SET_TAG
    je      @@ClearAllTags
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
@@ClearAllTags:
    call    Mock_Id_Clear_All_Tags
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
    cmp     [byte mock_id_command_ready], 0
    je      @@ClearSelected
    call    Mock_Id_Select_Tag
    cmp     [byte mock_selected_valid], 0
    je      @@ClearSelected
    mov     [byte mock_id_contention_active], 0
    jmp     @@Done
@@ClearSelected:
    mov     [byte mock_selected_tag], 0
    mov     [byte mock_selected_valid], 0
    jmp     @@Done

@@CheckActivate:
    ; FFh is a distinct command (Activate at the preconfigured I/O base) and
    ; must be checked before the E0h-FEh masked comparison below, since FFh
    ; numerically falls inside that mask's match set.
    cmp     al, ID_CMD_ACTIVATE_CONFIGURED
    jne     @@CheckActivateRange
    xor     ax, ax
    inc     ah
    call    Mock_Id_Activate_Eligible
    jmp     @@Done
@@CheckActivateRange:
    mov     bl, al
    and     bl, ID_CMD_ACTIVATE_MASK
    cmp     bl, ID_CMD_ACTIVATE
    jne     @@CheckDeactivate
    mov     al, bh
    and     al, 1Fh
    xor     ah, ah
    call    Mock_Id_Activate_Eligible
    jmp     @@Done

@@CheckDeactivate:
    ; ID-port Global Reset (C0h-CFh, a range -- not just the literal C0h)
    ; is a broadcast: it resets every record CURRENTLY in MCK_ID_CMD, not
    ; merely a single previously-selected tagged adapter.
    ; mock_selected_tag/valid track a *different* concept (the target of
    ; direct EEPROM-word reads once a tag has been isolated; see
    ; @@ReadContender above) and must not gate this broadcast.  This is
    ; also distinct from Command-Register Global Reset (which resets one
    ; adapter to its complete POR state) and from
    ; Cfg_Id_Deactivate_Selected's utility-level sequence in 3CCFGCLI.ASM,
    ; which narrows ID_CMD membership down to one adapter via SELECT_TAG
    ; before issuing this command -- that narrowing is what makes today's
    ; single-adapter deactivate/reconfigure flows behave the same as
    ; before, while this now also does the documented right thing for any
    ; other adapter that happens to still be in MCK_ID_CMD.
    mov     bl, al
    and     bl, ID_CMD_GLOBAL_RESET_MASK
    cmp     bl, ID_CMD_GLOBAL_RESET
    jne     @@Done
    call    Mock_Id_Global_Reset_All
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
    ; It re-enters the ID command population; untagged-only filtering occurs
    ; later at contention-read time, while D8h-DFh narrows tagged targets.
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    mov     [byte mock_id_command_ready], 1
    call    Mock_Id_Enter_Command
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

    call    Load_State
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    mov     [byte mock_contender_visible], 0
    mov     [byte mock_contender_index], 0FFh
    mov     [byte mock_loaded_index], 0FFh
    mov     [byte mock_state_dirty], 0

    ; Loading the MCK v3 powered-device image is side-effect free.  In
    ; particular, it does not clear tags or alter ID state merely because a
    ; DOS process opened the backend.  Any such transition must instead be
    ; caused by the modeled ID-port sequence/commands.
    call    Nic_IdPort_Send_Full_Sequence
    mov     al, ID_CMD_SET_TAG
    call    Nic_IdPort_Write_Command
    call    Nic_IdPort_Send_Short_Sequence
    mov     al, ID_CMD_SET_TAG
    call    Nic_IdPort_Write_Command
    call    Mock_Find_First_Untagged_Record
    jc      @@NoCard
    mov     [byte mock_contender_index], al
    mov     [byte mock_contender_visible], 1
    jmp     @@Done
@@NoCard:
    mov     [byte mock_contender_visible], 0
    mov     [byte mock_contender_index], 0FFh
@@Done:
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
