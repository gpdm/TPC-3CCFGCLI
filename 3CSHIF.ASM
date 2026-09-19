; ---------------------------------------------------------------------------
; 3CSHIF.ASM
; Backend-independent NIC algorithms for 3CCFGCLI.
; ---------------------------------------------------------------------------

; Convert a five bit Address Configuration selector to its ISA I/O base.
; Input AL = selector.  Output AX = base, zero for unassigned/EISA selector 1Fh.
PROC Nic_IOBASE_Selector_To_Base NEAR
    push    cx
    xor     ah, ah
    and     ax, W0_ADDRESS_CFG_IOBASE_MASK
    cmp     ax, W0_ADDRESS_CFG_IOBASE_MASK
    je      @@Unassigned
    mov     cl, W0_ADDRESS_CFG_IOBASE_SHIFT
    shl     ax, cl
    add     ax, VALID_IOBASE_MIN
    pop     cx
    ret
@@Unassigned:
    ; Selector 1Fh denotes EISA slot specific addressing, not ISA IOBASE 03F0h.
    ; This ISA only implementation does not model a slot derived address, so
    ; returning zero intentionally means that no normal ISA IOBASE is available.
    xor     ax, ax
    pop     cx
    ret
ENDP Nic_IOBASE_Selector_To_Base

; Convert a valid ISA I/O base to its five bit Address Configuration selector.
; Input AX = base.  Output AL = selector.
PROC Nic_IOBASE_Base_To_Selector NEAR
    push    cx
    sub     ax, VALID_IOBASE_MIN
    mov     cl, W0_ADDRESS_CFG_IOBASE_SHIFT
    shr     ax, cl
    and     al, W0_ADDRESS_CFG_IOBASE_MASK
    pop     cx
    ret
ENDP Nic_IOBASE_Base_To_Selector

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
    call    Nic_IOBASE_Base_To_Selector
    or      al, ID_CMD_ACTIVATE
    call    Nic_IdPort_Write_Command
    popf

    ; The ID tag selected the adapter and issued the E0h activation command,
    ; but that alone does not prove the adapter is reachable through normal
    ; runtime I/O (a second adapter can decode E0h yet fail to answer at its
    ; IOBASE afterward).  Do not set NIC_FLAG_ACTIVE here; runtime
    ; reachability is proven separately once normal-IOBASE access is
    ; verified.
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

PROC Nic_IdPort_Read_Word NEAR
    push    cx
    push    si

    and     al, 3Fh
    or      al, 80h
    call    Nic_IdPort_Write_Command
    call    Nic_IdPort_Eeprom_Delay
    xor     si, si
    mov     cx, 16
@@BitLoop:
    shl     si, 1
    call    Nic_IdPort_Read_Bit
    xor     ah, ah
    or      si, ax
    loop    @@BitLoop
    mov     ax, si

    pop     si
    pop     cx
    ret
ENDP Nic_IdPort_Read_Word
