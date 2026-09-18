; ---------------------------------------------------------------------------
; 3CHWIF.ASM
; Real hardware backend primitives for 3CCFGCLI.
; ---------------------------------------------------------------------------

PROC Nic_Sync_State NEAR
    ret
ENDP Nic_Sync_State

PROC Nic_IdPort_Write_Command NEAR
    push    dx
    mov     dx, ID_PORT
    out     dx, al
    pop     dx
    ret
ENDP Nic_IdPort_Write_Command

PROC Nic_IdPort_Send_Full_Sequence NEAR
    push    ax
    push    cx

    xor     al, al
    call    Nic_IdPort_Write_Command
    call    Nic_IdPort_Write_Command

    mov     al, 0FFh
    mov     cx, 255
@@Loop:
    call    Nic_IdPort_Write_Command
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
    push    ax
    push    cx

    xor     al, al
    call    Nic_IdPort_Write_Command
    call    Nic_IdPort_Write_Command

    mov     al, 0FFh
    mov     cx, 8
@@Loop:
    call    Nic_IdPort_Write_Command
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
ENDP Nic_IdPort_Send_Short_Sequence

PROC Nic_IdPort_Eeprom_Delay NEAR
    push    ax
    push    cx
    mov     cx, 2000
@@Delay:
    in      al, 0EDh
    loop    @@Delay
    pop     cx
    pop     ax
    ret
ENDP Nic_IdPort_Eeprom_Delay

PROC Nic_Init_Id_Port NEAR
    push    ax
    pushf
    cli
    call    Nic_IdPort_Send_Full_Sequence
    mov     al, ID_CMD_SET_TAG
    call    Nic_IdPort_Write_Command
    call    Nic_IdPort_Send_Short_Sequence
    mov     al, ID_CMD_SET_TAG
    call    Nic_IdPort_Write_Command
    popf
    pop     ax
    ret
ENDP Nic_Init_Id_Port

PROC Nic_IdPort_Read_Bit NEAR
    push    dx
    mov     dx, ID_PORT
    in      al, dx
    and     al, 01h
    pop     dx
    ret
ENDP Nic_IdPort_Read_Bit

; Backend physical I/O primitives.  Shared hardware algorithms pass actual
; ISA port addresses here; this backend performs the corresponding IN/OUT.
PROC Nic_IO_Read_Word NEAR
    in      ax, dx
    ret
ENDP Nic_IO_Read_Word

; Read one raw ISA byte for temporary I/O-range occupancy probing.
PROC Nic_Probe_IO_Byte NEAR
    in      al, dx
    ret
ENDP Nic_Probe_IO_Byte

PROC Nic_IO_Write_Word NEAR
    out     dx, ax
    ret
ENDP Nic_IO_Write_Word




PROC Nic_Wait_Command_Ready NEAR
    push    ax
    push    cx
    push    dx
    add     dx, EL3_STATUS
    mov     cx, 2000h
@@Wait:
    in      ax, dx
    test    ax, STATUS_CMD_BUSY
    jz      @@Ready
    in      al, 0EDh
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
    or      ax, 0080h
    add     dx, EL3_W0_EEPROM_COMMAND
    out     dx, ax

    mov     cx, 4000h
@@Busy:
    in      ax, dx
    test    ax, EEPROM_BUSY
    jz      @@ReadData
    in      al, 0EDh
    loop    @@Busy
    mov     ax, 0FFFFh
    stc
    jmp     @@Done
@@ReadData:
    add     dx, 2
    in      ax, dx
    clc
@@Done:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    ret
ENDP Nic_EEPROM_Read



; Input:  DX = adapter I/O base (unused on real HW; read is physical memory)
;         ES:BX = mapped Boot ROM memory address
; Output: AL = byte read
; Preserves: BX, CX, DX, SI, DI, BP, DS, ES
; AH: undefined
; Flags: undefined
PROC Nic_Rom_Read_Byte NEAR
    mov     al, [BYTE es:bx]
    ret
ENDP Nic_Rom_Read_Byte

; Input:  DX = adapter base, AL = Boot ROM page number.
; Output: None.
; Preserves all caller registers. Live register window preserved. Flags undefined.
PROC Nic_Rom_Set_Page NEAR
    push    ax
    push    bx
    push    cx
    push    dx

    mov     bl, al
    call    Nic_Get_Current_Window
    mov     ch, al

    mov     al, 3
    call    Nic_Select_Window

    mov     al, bl
    add     dx, EL3_W3_ROM_PAGE
    out     dx, al
    sub     dx, EL3_W3_ROM_PAGE

    mov     al, ch
    call    Nic_Select_Window

    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Nic_Rom_Set_Page
