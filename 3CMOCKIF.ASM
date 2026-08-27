; ---------------------------------------------------------------------------
; 3CMOCKIF.ASM
; Mock backend for the 3C509/3C509B ISA interface used during CLI testing.
; ---------------------------------------------------------------------------
; This module implements the same low-level contract as the real backend, but it
; emulates the card state in memory and persists it to a binary state file.
;
; The mock is intentionally behaviorally close to the real hardware interface:
;  - it exposes the same primitive names as the hardware backend
;  - it preserves register and window semantics
;  - it persists card state between runs so multi-step tests remain possible
; ---------------------------------------------------------------------------

MOCKHW_BACKEND EQU 1
MOCK_STATE_SIZE EQU 256

DATASEG

MOCK_STATE_FILE DB '3C509B.MCK', 0
mock_file_state DB MCK_FILE_SIZE DUP (0)

; ---------------------------------------------------------------------------
; Mock device runtime image.
; On-disk persistence uses 3C509B.MCK v1 layout from 3C509DEF.INC.
; Runtime keeps:
;   - EL3 window 0 register words in mock_state + 00h..
;   - EEPROM words in mock_state + 40h..
;   - window 4 net-diag register in mock_w4_netdiag
; ---------------------------------------------------------------------------
mock_state DB MOCK_STATE_SIZE DUP (0)
mock_state_dirty DB 0
mock_status_word DW 0000h
mock_current_window DB 0
mock_active_base DW 0200h
mock_irq DB 10
mock_tag DB 1
mock_active DB 0
mock_w4_netdiag DW 0000h
; Live Media Type and Status register (Window 4/Port 0Ah).  Bit 11 is the
; read-only link-beat-detected indicator surfaced via LIST; see
; EL3_W4_MEDIA_STATUS / MCKR_LIVE_W4_MEDIA_STATUS in 3C509DEF.INC.
mock_w4_media_status DW 0000h
mock_selected_tag DB 0
mock_selected_valid DB 0
mock_contender_visible DB 0

CODESEG

; ---------------------------------------------------------------------------
; Primitive: Init_State
; Purpose: initialize the default in-memory 3C509/3C509B mock device.
; Input: none.
; Output: none.
; Side effects: clears the working image and resets all runtime fields.
; Mock behavior: no seed file means no card is present.
; ---------------------------------------------------------------------------
PROC Init_State NEAR
    push    ax
    push    cx
    push    di

    mov     cx, MOCK_STATE_SIZE
    mov     di, OFFSET mock_state
@@Clear:
    xor     al, al
    mov     [di], al
    inc     di
    loop    @@Clear

    mov     [word mock_w4_netdiag], 0
    mov     [byte mock_current_window], 0
    mov     [word mock_active_base], 0200h
    mov     [byte mock_irq], 10
    mov     [byte mock_tag], 1
    mov     [byte mock_active], 0
    mov     [byte mock_selected_tag], 0
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_contender_visible], 0

    pop     di
    pop     cx
    pop     ax
    ret
ENDP Init_State

; ---------------------------------------------------------------------------
; Primitive: Load_State
; Purpose: read the persisted mock state blob from disk.
; Input: none.
; Output: none.
; Side effects: opens or creates the mock state file and loads it into memory.
; Mock behavior: file-backed state persistence across runs.
; ---------------------------------------------------------------------------
PROC Load_State NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    call    Init_State
    mov     dx, OFFSET MOCK_STATE_FILE
    xor     al, al
    mov     ah, 3Dh
    int     21h
    jc      @@NoFile
    mov     bx, ax
    mov     cx, MCK_FILE_SIZE
    mov     dx, OFFSET mock_file_state
    mov     ah, 3Fh
    int     21h
    mov     ah, 3Eh
    int     21h

    cmp     [BYTE mock_file_state + MCK_OFF_MAGIC0], MCK_MAGIC_0
    jne     @@NoFile
    cmp     [BYTE mock_file_state + MCK_OFF_MAGIC1], MCK_MAGIC_1
    jne     @@NoFile
    cmp     [BYTE mock_file_state + MCK_OFF_MAGIC2], MCK_MAGIC_2
    jne     @@NoFile
    cmp     [BYTE mock_file_state + MCK_OFF_MAGIC3], MCK_MAGIC_3
    jne     @@NoFile
    cmp     [WORD mock_file_state + MCK_OFF_VERSION], MCK_VERSION
    jne     @@NoFile
    cmp     [BYTE mock_file_state + MCK_OFF_RECORD_COUNT], 1
    jb      @@NoFile
    cmp     [BYTE mock_file_state + MCK_HEADER_SIZE + MCKR_PRESENT], 0
    je      @@NoFile

    mov     al, [BYTE mock_file_state + MCK_HEADER_SIZE + MCKR_CURRENT_WINDOW]
    mov     [byte mock_current_window], al
    mov     al, [BYTE mock_file_state + MCK_HEADER_SIZE + MCKR_TAG]
    mov     [byte mock_tag], al
    mov     al, [BYTE mock_file_state + MCK_HEADER_SIZE + MCKR_IRQ]
    mov     [byte mock_irq], al
    mov     ax, [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_ACTIVE_BASE]
    mov     [word mock_active_base], ax
    mov     al, [BYTE mock_file_state + MCK_HEADER_SIZE + MCKR_ACTIVE]
    mov     [byte mock_active], al

    mov     ax, [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_LIVE_W0_MFG]
    mov     [word mock_state + EL3_W0_MFG_ID], ax
    mov     ax, [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_LIVE_W0_PRODUCT]
    mov     [word mock_state + EL3_W0_PRODUCT_ID], ax
    mov     ax, [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_LIVE_W0_ADDR_CFG]
    mov     [word mock_state + EL3_W0_ADDRESS_CFG], ax
    mov     ax, [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_LIVE_W0_RES_CFG]
    mov     [word mock_state + EL3_W0_RESOURCE_CFG], ax
    mov     ax, [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_LIVE_W4_NETDIAG]
    mov     [word mock_w4_netdiag], ax
    mov     ax, [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_LIVE_W4_MEDIA_STATUS]
    mov     [word mock_w4_media_status], ax

    mov     si, OFFSET mock_file_state + MCK_HEADER_SIZE + MCKR_EEPROM
    mov     di, OFFSET mock_state + 40h
    mov     cx, 64
@@CopyEeprom:
    mov     ax, [WORD si]
    mov     [WORD di], ax
    add     si, 2
    add     di, 2
    loop    @@CopyEeprom
    jmp     @@Done

@@NoFile:
    mov     [byte mock_active], 0

@@Done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Load_State

; ---------------------------------------------------------------------------
; Primitive: Save_State
; Purpose: persist the current mock image to disk.
; Input: none.
; Output: none.
; Side effects: writes the in-memory state to the state file.
; Mock behavior: file-backed persistence for multi-step testing.
; ---------------------------------------------------------------------------
PROC Save_State NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    mov     di, OFFSET mock_file_state
    mov     cx, MCK_FILE_SIZE
    xor     al, al
    rep     stosb

    mov     [BYTE mock_file_state + MCK_OFF_MAGIC0], MCK_MAGIC_0
    mov     [BYTE mock_file_state + MCK_OFF_MAGIC1], MCK_MAGIC_1
    mov     [BYTE mock_file_state + MCK_OFF_MAGIC2], MCK_MAGIC_2
    mov     [BYTE mock_file_state + MCK_OFF_MAGIC3], MCK_MAGIC_3
    mov     [WORD mock_file_state + MCK_OFF_VERSION], MCK_VERSION
    mov     [BYTE mock_file_state + MCK_OFF_RECORD_COUNT], 1

    mov     al, [byte mock_active]
    mov     [BYTE mock_file_state + MCK_HEADER_SIZE + MCKR_ACTIVE], al
    mov     ax, [word mock_state + EL3_W0_MFG_ID]
    cmp     ax, 06D50h
    jne     @@NoPresent
    mov     al, 1
    jmp     @@StorePresent
@@NoPresent:
    xor     al, al
@@StorePresent:
    mov     [BYTE mock_file_state + MCK_HEADER_SIZE + MCKR_PRESENT], al
    mov     al, [byte mock_tag]
    mov     [BYTE mock_file_state + MCK_HEADER_SIZE + MCKR_TAG], al
    mov     [BYTE mock_file_state + MCK_HEADER_SIZE + MCKR_ID_MODE], 1
    mov     al, [byte mock_current_window]
    mov     [BYTE mock_file_state + MCK_HEADER_SIZE + MCKR_CURRENT_WINDOW], al
    mov     al, [byte mock_irq]
    mov     [BYTE mock_file_state + MCK_HEADER_SIZE + MCKR_IRQ], al
    mov     ax, [word mock_active_base]
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_ACTIVE_BASE], ax

    mov     ax, [word mock_state + EL3_W0_PRODUCT_ID]
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_PRODUCT_ID], ax
    mov     ax, [word mock_state + EL3_W0_MFG_ID]
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_LIVE_W0_MFG], ax
    mov     ax, [word mock_state + EL3_W0_PRODUCT_ID]
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_LIVE_W0_PRODUCT], ax
    mov     ax, [word mock_state + EL3_W0_ADDRESS_CFG]
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_LIVE_W0_ADDR_CFG], ax
    mov     ax, [word mock_state + EL3_W0_RESOURCE_CFG]
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_LIVE_W0_RES_CFG], ax
    mov     ax, [word mock_w4_netdiag]
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_LIVE_W4_NETDIAG], ax
    mov     ax, [word mock_w4_media_status]
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_LIVE_W4_MEDIA_STATUS], ax

    mov     ax, MCK_CFGF_INT + MCK_CFGF_IOBASE + MCK_CFGF_PORT + MCK_CFGF_PNP + MCK_CFGF_MODEM
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_CFG_FLAGS], ax
    xor     ah, ah
    mov     al, [byte mock_irq]
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_CFG_INT], ax
    mov     ax, [word mock_active_base]
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_CFG_IOBASE], ax
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_CFG_PORT], ax
    mov     ax, [word mock_state + 40h + (EEPROM_CONFIG_CONTROL * 2)]
    and     ax, 000Ch
    cmp     ax, 0004h
    je      @@StorePnpDisabled
    mov     ax, 1
    jmp     @@StorePnp
@@StorePnpDisabled:
    xor     ax, ax
@@StorePnp:
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_CFG_PNP], ax
    mov     ax, [word mock_state + 40h + (EEPROM_SOFTWARE_INFO * 2)]
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_CFG_MODEM], ax
    ; Extract FULLDUPLEX from bit 15 of EEPROM word 0Dh.
    mov     ax, [word mock_state + 40h + (EEPROM_SOFTWARE_INFO * 2)]
    mov     cl, 15
    shr     ax, cl
    and     ax, 0001h
    mov     [WORD mock_file_state + MCK_HEADER_SIZE + MCKR_CFG_FULLDUPLEX], ax

    mov     si, OFFSET mock_state + 40h
    mov     di, OFFSET mock_file_state + MCK_HEADER_SIZE + MCKR_EEPROM
    mov     cx, 64
@@CopyEeprom:
    mov     ax, [WORD si]
    mov     [WORD di], ax
    add     si, 2
    add     di, 2
    loop    @@CopyEeprom

    mov     ah, 3Ch
    xor     cx, cx
    mov     dx, OFFSET MOCK_STATE_FILE
    int     21h
    jc      @@Done
    mov     bx, ax

@@Write:
    mov     cx, MCK_FILE_SIZE
    mov     dx, OFFSET mock_file_state
    mov     ah, 40h
    int     21h
    mov     ah, 3Eh
    int     21h

@@Done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Save_State

; ---------------------------------------------------------------------------
; Primitive: Nic_Read_Status
; Purpose: emulate the live NIC status word at base + EL3_STATUS.
; Input: DX = candidate base.
; Output: AX = status word, or FFFFh when absent.
; Side effects: none beyond reading the mock register image.
; Mock behavior: absent device returns FFFFh; active device returns a valid status.
; ---------------------------------------------------------------------------
PROC Nic_Read_Status NEAR
    push    dx
    mov     al, [byte mock_active]
    cmp     al, 0
    je      @@Absent
    cmp     dx, [word mock_active_base]
    jne     @@Absent
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

; ---------------------------------------------------------------------------
; Primitive: Nic_Select_Window
; Purpose: emulate the window selection command.
; Input: DX = base, AL = desired window 0..7.
; Output: none.
; Side effects: updates the mock current window state.
; Mock behavior: the selected register bank is now the active window.
; ---------------------------------------------------------------------------
PROC Nic_Select_Window NEAR
    push    ax
    and     al, 07h
    mov     [byte mock_current_window], al
    pop     ax
    ret
ENDP Nic_Select_Window

; ---------------------------------------------------------------------------
; Primitive: Nic_Get_Current_Window
; Purpose: return the selected register window number.
; Input: DX = base.
; Output: AX = current window number.
; Side effects: none.
; Mock behavior: returns the current mock window.
; ---------------------------------------------------------------------------
PROC Nic_Get_Current_Window NEAR
    xor     ax, ax
    mov     al, [byte mock_current_window]
    ret
ENDP Nic_Get_Current_Window

; ---------------------------------------------------------------------------
; Primitive: Nic_Wait_Command_Ready
; Purpose: emulate the command-busy polling cycle.
; Input: DX = base.
; Output: CF clear.
; Side effects: no actual delay needed in the mock path.
; Mock behavior: command engine is assumed ready when the mock is active.
; ---------------------------------------------------------------------------
PROC Nic_Wait_Command_Ready NEAR
    clc
    ret
ENDP Nic_Wait_Command_Ready

; ---------------------------------------------------------------------------
; Primitive: Nic_Reg_Read_Word
; Purpose: read a simulated register word from the current mock register image.
; Input: DX = base, BX = register offset.
; Output: AX = simulated register value.
; Side effects: none.
; Mock behavior: the word is read from the in-memory register image.
; ---------------------------------------------------------------------------
PROC Cfg_Reg_Read_Word NEAR
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

; ---------------------------------------------------------------------------
; Primitive: Nic_Reg_Write_Word
; Purpose: write a simulated register word.
; Input: DX = base, BX = register offset, AX = value.
; Output: none.
; Side effects: updates the in-memory register image.
; Mock behavior: writes directly to the mock image.
; ---------------------------------------------------------------------------
PROC Cfg_Reg_Write_Word NEAR
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    mov     cl, [byte mock_current_window]
    cmp     cl, 4
    jne     @@Window0
    cmp     bx, EL3_W4_NET_DIAG
    jne     @@Done
    mov     [word mock_w4_netdiag], ax
    call    Save_State
    jmp     @@Done
@@Window0:
    cmp     cl, 0
    jne     @@Done
    cmp     bx, EL3_W0_EEPROM_COMMAND
    jne     @@StoreDirect
    mov     [word mock_state + EL3_W0_EEPROM_COMMAND], ax
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
    call    Save_State
    jmp     @@Done
@@StoreDirect:
    mov     [word mock_state + bx], ax
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

; ---------------------------------------------------------------------------
; Primitive: Nic_Reg_Write_Byte
; Purpose: write a byte to a simulated register byte.
; Input: DX = base, BX = register offset, AL = value.
; Output: none.
; Side effects: updates the mock image byte.
; Mock behavior: direct mock byte write.
; ---------------------------------------------------------------------------
PROC Cfg_Reg_Write_Byte NEAR
    push    bx
    mov     [byte mock_state + bx], al
    pop     bx
    ret
ENDP Cfg_Reg_Write_Byte

PROC Nic_Reg_Write_Byte NEAR
    call    Cfg_Reg_Write_Byte
    ret
ENDP Nic_Reg_Write_Byte

; ---------------------------------------------------------------------------
; Primitive: Nic_EEPROM_Read
; Purpose: read one EEPROM word from the mock image.
; Input: DX = base, AL = EEPROM word index.
; Output: AX = EEPROM word.
; Side effects: none.
; Mock behavior: reads from a file-backed EEPROM template.
; ---------------------------------------------------------------------------
PROC Nic_EEPROM_Read NEAR
    push    bx
    xor     ah, ah
    mov     bl, al
    xor     bh, bh
    shl     bx, 1
    mov     ax, [word mock_state + 40h + bx]
    pop     bx
    ret
ENDP Nic_EEPROM_Read

; ---------------------------------------------------------------------------
; Primitive: Nic_EEPROM_Wait_Ready
; Purpose: emulate the EEPROM busy bit.
; Input: DX = base.
; Output: CF clear.
; Side effects: none.
; Mock behavior: the EEPROM model is assumed always ready after the command.
; ---------------------------------------------------------------------------
PROC Nic_EEPROM_Wait_Ready NEAR
    clc
    ret
ENDP Nic_EEPROM_Wait_Ready

; ---------------------------------------------------------------------------
; Primitive: Nic_Activate_Tagged_Cards
; Purpose: emulate the tag activation pass performed by the CLI.
; Input: none.
; Output: none.
; Side effects: marks the mock card active and persists the state.
; Mock behavior: card becomes active at its configured base and tag selection.
; ---------------------------------------------------------------------------
PROC Nic_Activate_Tagged_Cards NEAR
    cmp     [card_count], 0
    jz      @@Done
    mov     al, [BYTE nic_table + NIC_TAG]
    mov     [byte mock_tag], al
    mov     ax, [WORD nic_table + NIC_IO_BASE]
    or      ax, ax
    jz      @@KeepBase
    mov     [word mock_active_base], ax
@@KeepBase:
    mov     al, 1
    mov     [byte mock_active], al
    call    Save_State
@@Done:
    ret
ENDP Nic_Activate_Tagged_Cards

; ---------------------------------------------------------------------------
; Primitive: Nic_Scan_Active_Base_Ports
; Purpose: emulate the active-base scan pass.
; Input: none.
; Output: none.
; Side effects: updates the active base state.
; Mock behavior: the mock reports the fixed active ISA base 0200h.
; ---------------------------------------------------------------------------
PROC Nic_Scan_Active_Base_Ports NEAR
    cmp     [byte mock_active], 0
    je      @@Done
    cmp     [word mock_active_base], 0
    jne     @@Done
    mov     [word mock_active_base], 0300h
@@Done:
    ret
ENDP Nic_Scan_Active_Base_Ports

; ---------------------------------------------------------------------------
; Primitive: Nic_Check_3Com_Signature
; Purpose: verify that the mocked card presents a valid 3C509 registration image.
; Input: DX = candidate base.
; Output: CF clear on success, AX = normalized product ID, BL = ASIC revision.
; Side effects: reads status, window state and live register values.
; Mock behavior: this reproduces the same contract as the real routine.
; ---------------------------------------------------------------------------
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

; ---------------------------------------------------------------------------
; Primitive: Nic_IdPort_Write_Command
; ---------------------------------------------------------------------------
PROC Nic_IdPort_Write_Command NEAR
    push    bx
    mov     bl, al
    and     bl, 0F8h
    cmp     bl, ID_CMD_SET_TAG
    jne     @@CheckSelect
    and     al, 07h
    mov     [byte mock_tag], al
    mov     [byte mock_contender_visible], 0
    jmp     @@Done
@@CheckSelect:
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
    mov     ah, [byte mock_selected_tag]
    cmp     ah, [byte mock_tag]
    jne     @@Done
    and     al, 1Fh
    xor     ah, ah
    shl     ax, 1
    shl     ax, 1
    shl     ax, 1
    shl     ax, 1
    add     ax, 0200h
    mov     [word mock_active_base], ax
    mov     al, 1
    mov     [byte mock_active], al
    call    Save_State
    jmp     @@Done
@@CheckDeactivate:
    cmp     al, 0C0h
    jne     @@Done
    mov     [byte mock_active], 0
    call    Save_State
@@Done:
    pop     bx
    ret
ENDP Nic_IdPort_Write_Command

; ---------------------------------------------------------------------------
; Primitive: Nic_IdPort_Send_Full_Sequence
; ---------------------------------------------------------------------------
PROC Nic_IdPort_Send_Full_Sequence NEAR
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    cmp     [word mock_state + EL3_W0_MFG_ID], 06D50h
    jne     @@NoCard
    cmp     [byte mock_tag], 0
    jne     @@NoCard
    mov     [byte mock_contender_visible], 1
    ret
@@NoCard:
    mov     [byte mock_contender_visible], 0
    ret
ENDP Nic_IdPort_Send_Full_Sequence

; ---------------------------------------------------------------------------
; Primitive: Nic_IdPort_Send_Short_Sequence
; ---------------------------------------------------------------------------
PROC Nic_IdPort_Send_Short_Sequence NEAR
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    cmp     [word mock_state + EL3_W0_MFG_ID], 06D50h
    jne     @@NoCard
    cmp     [byte mock_tag], 0
    jne     @@NoCard
    mov     [byte mock_contender_visible], 1
    ret
@@NoCard:
    mov     [byte mock_contender_visible], 0
    ret
ENDP Nic_IdPort_Send_Short_Sequence

; ---------------------------------------------------------------------------
; Primitive: Nic_IdPort_Eeprom_Delay
; ---------------------------------------------------------------------------
PROC Nic_IdPort_Eeprom_Delay NEAR
    ret
ENDP Nic_IdPort_Eeprom_Delay

; ---------------------------------------------------------------------------
; Primitive: Nic_Init_Id_Port
; Purpose: emulate the initialization of both ID-port sequence modes.
; Input: none.
; Output: none.
; Side effects: marks the mock device initialized and ready for scanning.
; Mock behavior: software-only initialization, no real ISA port access.
; ---------------------------------------------------------------------------
PROC Nic_Init_Id_Port NEAR
    call    Load_State
    mov     [byte mock_selected_valid], 0
    mov     [byte mock_selected_tag], 0
    mov     [byte mock_tag], 0
    cmp     [word mock_state + EL3_W0_MFG_ID], 06D50h
    jne     @@NoCard
    mov     [byte mock_contender_visible], 1
    ret
@@NoCard:
    mov     [byte mock_contender_visible], 0
    ret
ENDP Nic_Init_Id_Port

; ---------------------------------------------------------------------------
; Primitive: Nic_IdPort_Read_Word
; Purpose: emulate the proprietary ID-port EEPROM read path.
; Input: AL = EEPROM word index.
; Output: AX = logical 16-bit EEPROM word.
; Side effects: reads from the mock EEPROM image.
; Mock behavior: direct software replacement for ID-port EEPROM access.
; ---------------------------------------------------------------------------
PROC Nic_IdPort_Read_Word NEAR
    push    bx
    cmp     [byte mock_contender_visible], 0
    jne     @@ReadWord
    cmp     [byte mock_selected_valid], 0
    je      @@Absent
    mov     ah, [byte mock_selected_tag]
    cmp     ah, [byte mock_tag]
    jne     @@Absent
@@ReadWord:
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
ENDP Nic_IdPort_Read_Word

; ---------------------------------------------------------------------------
; Primitive: Nic_Read_Id_Contender_Data
; Purpose: read the prospect identity block from the mock file-backed image.
; Input: none.
; Output: none.
; Side effects: sets the temporary contender variables used by the scanner.
; Mock behavior: deterministic block content for the mock-device path.
; ---------------------------------------------------------------------------
PROC Nic_Read_Id_Contender_Data NEAR
    ; The full scanner logic remains in 3CCFGCLI.ASM.  The mock backend only
    ; provides the low-level device semantics the scanner expects.
    ret
ENDP Nic_Read_Id_Contender_Data

PROC Nic_Find_Duplicate_Id_Record NEAR
    call    Find_Duplicate_Id_Record
    ret
ENDP Nic_Find_Duplicate_Id_Record

; ---------------------------------------------------------------------------
; Compatibility wrapper names retained for the older helper names.
; ---------------------------------------------------------------------------
PROC Nic_Read_EepromWord NEAR
    call    Nic_EEPROM_Read
    ret
ENDP Nic_Read_EepromWord

PROC Nic_Write_EepromWord NEAR
    call    Nic_Reg_Write_Word
    ret
ENDP Nic_Write_EepromWord
