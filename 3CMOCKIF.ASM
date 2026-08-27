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

MOCK_STATE_FILE DB '3C509B.MCK', 0

; ---------------------------------------------------------------------------
; Mock device state image.
; Layout (minimal but usable for the CLI):
;   +00h: live register image (32 words, enough for the common NIC windows)
;   +40h: EEPROM image (64 words)
;   +80h: current window, active base, IRQ, tag, layout flags
; ---------------------------------------------------------------------------
mock_state DB MOCK_STATE_SIZE DUP (0)
mock_state_dirty DB 0
mock_status_word DW 0000h
mock_current_window DB 0
mock_active_base DW 0200h
mock_irq DB 10
mock_tag DB 1
mock_active DB 0

; ---------------------------------------------------------------------------
; Primitive: Init_State
; Purpose: initialize the default in-memory 3C509/3C509B mock device.
; Input: none.
; Output: none.
; Side effects: clears the working image and seeds a valid 3C509 signature.
; Mock behavior: populates a deterministic, file-backed software model.
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

    mov     ax, 06D50h
    mov     [word mock_state+00h], ax
    mov     ax, 09050h
    mov     [word mock_state+02h], ax
    mov     ax, 0004h
    mov     [word mock_state+06h], ax
    mov     ax, 0000h
    mov     [word mock_state+08h], ax
    mov     [word mock_state+0Ah], ax
    mov     [word mock_state+0Ch], ax
    mov     [word mock_state+10h], ax
    mov     [word mock_state+12h], ax
    mov     [word mock_state+14h], ax
    mov     [word mock_state+16h], ax
    mov     [word mock_state+18h], ax

    mov     al, 0
    mov     [byte mock_current_window], al
    mov     ax, 0200h
    mov     [word mock_active_base], ax
    mov     al, 10
    mov     [byte mock_irq], al
    mov     al, 1
    mov     [byte mock_tag], al
    mov     al, 1
    mov     [byte mock_active], al

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

    mov     dx, OFFSET MOCK_STATE_FILE
    xor     al, al
    mov     ah, 3Dh
    int     21h
    jc      @@InitNew
    mov     bx, ax
    mov     cx, MOCK_STATE_SIZE
    mov     dx, OFFSET mock_state
    mov     ah, 3Fh
    int     21h
    mov     ah, 3Eh
    int     21h
    jmp     @@Done

@@InitNew:
    call    Init_State
    call    Save_State

@@Done:
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

    mov     ah, 3Ch
    xor     cx, cx
    mov     dx, OFFSET MOCK_STATE_FILE
    int     21h
    jc      @@OpenExisting
    mov     bx, ax
    jmp     @@Write

@@OpenExisting:
    mov     ah, 3Dh
    mov     al, 2
    mov     dx, OFFSET MOCK_STATE_FILE
    int     21h
    jc      @@Done
    mov     bx, ax

@@Write:
    mov     cx, MOCK_STATE_SIZE
    mov     dx, OFFSET mock_state
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
PROC Nic_Reg_Read_Word NEAR
    push    bx
    mov     ax, [word mock_state + bx]
    pop     bx
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
PROC Nic_Reg_Write_Word NEAR
    push    bx
    mov     [word mock_state + bx], ax
    pop     bx
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
PROC Nic_Reg_Write_Byte NEAR
    push    bx
    mov     [byte mock_state + bx], al
    pop     bx
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
    mov     al, 1
    mov     [byte mock_active], al
    call    Save_State
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
    mov     ax, 0200h
    mov     [word mock_active_base], ax
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
    mov     bx, EL3_W0_PRODUCT_ID
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
; Primitive: Nic_Init_Id_Port
; Purpose: emulate the initialization of both ID-port sequence modes.
; Input: none.
; Output: none.
; Side effects: marks the mock device initialized and ready for scanning.
; Mock behavior: software-only initialization, no real ISA port access.
; ---------------------------------------------------------------------------
PROC Nic_Init_Id_Port NEAR
    call    Load_State
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
    xor     ah, ah
    mov     bl, al
    xor     bh, bh
    shl     bx, 1
    mov     ax, [word mock_state + 40h + bx]
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
