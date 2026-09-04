; ---------------------------------------------------------------------------
; 3CHWIF.ASM
; Real hardware backend primitives for 3CCFGCLI.
; ---------------------------------------------------------------------------

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
PROC Nic_IO_Read_Byte NEAR
    in      al, dx
    ret
ENDP Nic_IO_Read_Byte

PROC Nic_IO_Read_Word NEAR
    in      ax, dx
    ret
ENDP Nic_IO_Read_Word

PROC Nic_IO_Write_Byte NEAR
    out     dx, al
    ret
ENDP Nic_IO_Write_Byte

PROC Nic_IO_Write_Word NEAR
    out     dx, ax
    ret
ENDP Nic_IO_Write_Word

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
    push    dx
    add     dx, EL3_STATUS
    call    Nic_IO_Read_Word
    mov     cl, 13
    shr     ax, cl
    and     ax, 0007h
    pop     dx
    pop     cx
    ret
ENDP Nic_Get_Current_Window

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

PROC Nic_Reg_Read_Word NEAR
    push    dx
    add     dx, bx
    call    Nic_IO_Read_Word
    pop     dx
    ret
ENDP Nic_Reg_Read_Word

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

PROC Nic_Check_3Com_Signature NEAR
    push    cx
    push    dx
    push    si
    push    di

    mov     si, dx
    mov     ch, 0FFh

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
    ; Documented Window 0 Manufacturer ID register value.
    cmp     ax, 06D50h
    jne     @@RestoreFail

    mov     dx, si
    mov     bx, EL3_W0_PRODUCT_ID
    call    Nic_Reg_Read_Word
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

PROC Nic_Activate_Tagged_Cards NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si

    mov     cx, [card_count]
    or      cx, cx
    jz      @@Done
    mov     si, OFFSET nic_table
@@Loop:
    mov     dx, [WORD si + NIC_IO_BASE]
    or      dx, dx
    jz      @@Next

    pushf
    cli
    cmp     [BYTE si + NIC_ID_MODE], 0
    je      @@Full
    call    Nic_IdPort_Send_Short_Sequence
    jmp     @@SelectTag
@@Full:
    call    Nic_IdPort_Send_Full_Sequence
@@SelectTag:
    mov     al, [BYTE si + NIC_TAG]
    and     al, 07h
    or      al, ID_CMD_SELECT_TAG
    call    Nic_IdPort_Write_Command

    mov     ax, [WORD si + NIC_IO_BASE]
    sub     ax, 0200h
    shr     ax, 1
    shr     ax, 1
    shr     ax, 1
    shr     ax, 1
    and     al, 1Fh
    or      al, ID_CMD_ACTIVATE
    call    Nic_IdPort_Write_Command
    popf

    mov     dx, [WORD si + NIC_IO_BASE]
    call    Nic_Check_3Com_Signature
    jc      @@Next
    mov     [WORD si + NIC_PRODUCT_ID], ax
    mov     [BYTE si + NIC_ASIC_REV], bl
    or      [BYTE si + NIC_FLAGS], NIC_FLAG_ACTIVE
@@Next:
    add     si, NIC_RECORD_SIZE
    loop    @@Loop
@@Done:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Nic_Activate_Tagged_Cards
