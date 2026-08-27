; ---------------------------------------------------------------------------
; 3CHWIF.ASM
; Real hardware backend for the 3C509/3C509B ISA interface.
; ---------------------------------------------------------------------------
; This module contains the real device-side primitive contract used by the main
; LIST/CONFIGURE logic in 3CCFGCLI.ASM.
;
; The core design is intentionally simple: a backend API exposes low-level
; hardware access primitives, while the CLI logic remains algorithmic and
; backend-agnostic.
; ---------------------------------------------------------------------------

REALHW_BACKEND EQU 1

; ---------------------------------------------------------------------------
; Primitive: Nic_Init_Id_Port
; Purpose: initialize the proprietary 3Com ID-port discovery path.
; Input: none.
; Output: none.
; Side effects: issues the short/full ID-port initialization sequences.
; Real backend behavior: direct ISA I/O using the original 3CCFG routines.
; ---------------------------------------------------------------------------
PROC Nic_Init_Id_Port NEAR
    call    IdPort_Initialize
    ret
ENDP Nic_Init_Id_Port

; ---------------------------------------------------------------------------
; Primitive: Nic_IdPort_Read_Word
; Purpose: read one 16-bit EEPROM word through the ISA ID port.
; Input: AL = EEPROM word index, without the 80h read opcode.
; Output: AX = assembled 16-bit EEPROM word.
; Side effects: writes sequence bytes to ID_PORT and reads back the serial bitstream.
; Real backend behavior: direct ID_PORT access via IdPort_Read_Word.
; ---------------------------------------------------------------------------
PROC Nic_IdPort_Read_Word NEAR
    call    IdPort_Read_Word
    ret
ENDP Nic_IdPort_Read_Word

; ---------------------------------------------------------------------------
; Primitive: Nic_Read_Status
; Purpose: read the live 3C509 status register.
; Input: DX = candidate base port.
; Output: AX = status word from base + EL3_STATUS.
; Side effects: one ISA IN read.
; Real backend behavior: direct hardware read.
; ---------------------------------------------------------------------------
PROC Nic_Read_Status NEAR
    push    dx
    add     dx, EL3_STATUS
    in      ax, dx
    pop     dx
    ret
ENDP Nic_Read_Status

; ---------------------------------------------------------------------------
; Primitive: Nic_Select_Window
; Purpose: switch the live register window.
; Input: DX = base, AL = window number 0..7.
; Output: none.
; Side effects: writes a command word to base + EL3_COMMAND.
; Real backend behavior: direct OUT instruction to the selected NIC register.
; ---------------------------------------------------------------------------
PROC Nic_Select_Window NEAR
    push    ax
    push    dx
    xor     ah, ah
    and     ax, 0007h
    or      ax, CMD_SELECT_WINDOW
    add     dx, EL3_COMMAND
    out     dx, ax
    pop     dx
    pop     ax
    ret
ENDP Nic_Select_Window

; ---------------------------------------------------------------------------
; Primitive: Nic_Get_Current_Window
; Purpose: decode the currently selected register window.
; Input: DX = base.
; Output: AX = current window number 0..7.
; Side effects: reads base + EL3_STATUS.
; Real backend behavior: direct hardware read and bit extraction.
; ---------------------------------------------------------------------------
PROC Nic_Get_Current_Window NEAR
    call    Get_Current_Window
    ret
ENDP Nic_Get_Current_Window

; ---------------------------------------------------------------------------
; Primitive: Nic_Wait_Command_Ready
; Purpose: poll the command-busy flag until it clears.
; Input: DX = base.
; Output: CF clear on ready, set on timeout.
; Side effects: repeated IN reads from the status register.
; Real backend behavior: direct hardware polling with the original timeout logic.
; ---------------------------------------------------------------------------
PROC Nic_Wait_Command_Ready NEAR
    call    Wait_Command_Ready
    ret
ENDP Nic_Wait_Command_Ready

; ---------------------------------------------------------------------------
; Primitive: Nic_Reg_Read_Word
; Purpose: read one 16-bit register word from the selected NIC window.
; Input: DX = base, BX = register offset within the selected window.
; Output: AX = 16-bit register value.
; Side effects: one IN read from base + BX.
; Real backend behavior: direct NIC register access.
; ---------------------------------------------------------------------------
PROC Nic_Reg_Read_Word NEAR
    push    dx
    add     dx, bx
    in      ax, dx
    pop     dx
    ret
ENDP Nic_Reg_Read_Word

; ---------------------------------------------------------------------------
; Primitive: Nic_Reg_Write_Word
; Purpose: write one 16-bit register word to the selected NIC window.
; Input: DX = base, BX = register offset, AX = value.
; Output: none.
; Side effects: one OUT write to the selected register word.
; Real backend behavior: direct NIC register write.
; ---------------------------------------------------------------------------
PROC Nic_Reg_Write_Word NEAR
    push    dx
    add     dx, bx
    out     dx, ax
    pop     dx
    ret
ENDP Nic_Reg_Write_Word

; ---------------------------------------------------------------------------
; Primitive: Nic_Reg_Write_Byte
; Purpose: write one 8-bit register byte.
; Input: DX = base, BX = register offset, AL = value.
; Output: none.
; Side effects: one OUT write to the selected byte register.
; Real backend behavior: direct NIC register write.
; ---------------------------------------------------------------------------
PROC Nic_Reg_Write_Byte NEAR
    push    dx
    add     dx, bx
    out     dx, al
    pop     dx
    ret
ENDP Nic_Reg_Write_Byte

; ---------------------------------------------------------------------------
; Primitive: Nic_EEPROM_Read
; Purpose: read one EEPROM word from the selected adapter.
; Input: DX = base, AL = EEPROM word index.
; Output: AX = EEPROM word, or FFFFh on timeout.
; Side effects: writes EEPROM command, polls busy flag, reads data register.
; Real backend behavior: direct EEPROM access via the original implementation.
; ---------------------------------------------------------------------------
PROC Nic_EEPROM_Read NEAR
    call    EEPROM_Read
    ret
ENDP Nic_EEPROM_Read

; ---------------------------------------------------------------------------
; Primitive: Nic_EEPROM_Wait_Ready
; Purpose: poll the EEPROM busy bit until the command finishes.
; Input: DX = base.
; Output: CF clear when ready, CF set on timeout.
; Side effects: repeated status reads and a timer-based wait loop.
; Real backend behavior: direct polling of the hardware EEPROM command register.
; ---------------------------------------------------------------------------
PROC Nic_EEPROM_Wait_Ready NEAR
    call    Cfg_Eeprom_Wait_Ready
    ret
ENDP Nic_EEPROM_Wait_Ready

; ---------------------------------------------------------------------------
; Primitive: Nic_Activate_Tagged_Cards
; Purpose: tag-select and activate all discovered adapters.
; Input: none; uses the in-memory NIC table and ID-port state.
; Output: none.
; Side effects: ID-port selection, activation commands, and a signature validation pass.
; Real backend behavior: direct action against the physical device list.
; ---------------------------------------------------------------------------
PROC Nic_Activate_Tagged_Cards NEAR
    call    Activate_Tagged_Cards
    ret
ENDP Nic_Activate_Tagged_Cards

; ---------------------------------------------------------------------------
; Primitive: Nic_Scan_Active_Base_Ports
; Purpose: scan the valid active ISA bases for a live 3Com board.
; Input: none.
; Output: none.
; Side effects: populates the card table using the active-base scan loop.
; Real backend behavior: direct active-base probing over the hardware I/O map.
; ---------------------------------------------------------------------------
PROC Nic_Scan_Active_Base_Ports NEAR
    call    Scan_Active_Base_Ports
    ret
ENDP Nic_Scan_Active_Base_Ports

; ---------------------------------------------------------------------------
; Primitive: Nic_Check_3Com_Signature
; Purpose: verify that a candidate base is a live 3C509/3C509B register image.
; Input: DX = candidate base.
; Output: CF clear on success, AX = normalized product ID, BL = ASIC revision.
; Side effects: selects windows, reads status and product words, restores window state.
; Real backend behavior: direct hardware register verification as implemented in
; the original CLI logic.
; ---------------------------------------------------------------------------
PROC Nic_Check_3Com_Signature NEAR
    call    Check_3Com_Signature
    ret
ENDP Nic_Check_3Com_Signature

; ---------------------------------------------------------------------------
; Compatibility wrappers retained for older call sites and direct references.
; ---------------------------------------------------------------------------
PROC Nic_Read_EepromWord NEAR
    call    EEPROM_Read
    ret
ENDP Nic_Read_EepromWord

PROC Nic_Write_EepromWord NEAR
    call    Cfg_Eeprom_Write
    ret
ENDP Nic_Write_EepromWord

PROC Nic_Read_Id_Contender_Data NEAR
    call    Read_Id_Contender_Data
    ret
ENDP Nic_Read_Id_Contender_Data

PROC Nic_Find_Duplicate_Id_Record NEAR
    call    Find_Duplicate_Id_Record
    ret
ENDP Nic_Find_Duplicate_Id_Record
