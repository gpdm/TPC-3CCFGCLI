; ============================================================================
; 3CCFGCLI.ASM
; 3Com EtherLink III 3C509 and 3C509B ISA detection and LIST utility
;
; Target: MS DOS, Turbo Assembler, 8086 and 8088 only
;
; The ISA discovery path intentionally follows the behavior recovered from
; the original 3CCFG 3.2 utility:
;
;   1. Use ID port 0110h.
;   2. Initialize both the full 255 byte ID sequence and the short 8 byte
;      sequence, clearing tags with command D0h after each sequence.
;   3. Probe with the short sequence first, retry with the full sequence when
;      manufacturer or product validation fails.
;   4. Validate EEPROM word 7 = 6D50h and product word 3 with mask F0FFh.
;   5. Read the identity and configuration words while the contender is live.
;   6. Assign tag D0h plus tag before moving to the next contender.
;   7. Reactivate each tagged adapter using D8h plus tag, followed by
;      E0h plus the encoded I O base index.
;   8. Verify the active register image in window 0 and read ASIC revision
;      from window 4 offset 6.
;   9. Scan all 31 valid ISA base addresses from 0200h through 03E0h in
;      10h increments to catch adapters that were already active.
;
; Scope note: the original 3CCFG also contains resource manager and ISA PnP
; discovery before the classic 3Com ID sequence.  This reduced utility catches
; PnP cards that are already activated at an ISA base, and cards for which the
; classic 3Com ID mechanism is enabled.  It does not implement standalone ISA
; PnP serial isolation for an inactive adapter configured for PnP only mode.
;
; This file deliberately does not write the EEPROM.  CONFIGURE is rejected.
; The prior reimplementation used incorrect EEPROM fields in its write path,
; so retaining that code would risk changing the wrong configuration bits.
; ============================================================================

IDEAL
P8086
JUMPS

MODEL SMALL
STACK 400h

; ----------------------------------------------------------------------------
; Constants
; ----------------------------------------------------------------------------
ID_PORT                 EQU 0110h
MAX_CARDS               EQU 6

EEPROM_NODE_0           EQU 00h
EEPROM_NODE_1           EQU 01h
EEPROM_NODE_2           EQU 02h
EEPROM_PRODUCT_ID       EQU 03h
EEPROM_MFG_ID           EQU 07h
EEPROM_ADDR_CFG         EQU 08h
EEPROM_RESOURCE_CFG     EQU 09h
EEPROM_OEM_NODE_0       EQU 0Ah
EEPROM_OEM_NODE_1       EQU 0Bh
EEPROM_OEM_NODE_2       EQU 0Ch
EEPROM_SOFTWARE_INFO    EQU 0Dh

ID_CMD_SET_TAG          EQU 0D0h
ID_CMD_SELECT_TAG       EQU 0D8h
ID_CMD_ACTIVATE         EQU 0E0h

EL3_COMMAND             EQU 0Eh
EL3_STATUS              EQU 0Eh
EL3_W0_MFG_ID           EQU 00h
EL3_W0_PRODUCT_ID       EQU 02h
EL3_W0_EEPROM_COMMAND   EQU 0Ah
EL3_W0_EEPROM_DATA      EQU 0Ch
EL3_W4_NET_DIAG         EQU 06h

CMD_SELECT_WINDOW       EQU 0800h
STATUS_CMD_BUSY         EQU 1000h
EEPROM_BUSY             EQU 8000h

PRODUCT_3C509           EQU 09150h
PRODUCT_3C509_TP        EQU 09050h
PRODUCT_3C509_COMBO     EQU 09450h
PRODUCT_3C509_TPO       EQU 09550h
PRODUCT_3C509_TPC       EQU 09850h

; Record layout used only by this reduced utility.
NIC_IO_BASE             EQU 0       ; DW
NIC_PRODUCT_ID          EQU 2       ; DW
NIC_ASIC_REV            EQU 4       ; DB, FFh means not readable
NIC_MAC_ADDR            EQU 5       ; 6 bytes
NIC_IRQ_VAL             EQU 11      ; DB
NIC_PORT_TYPE           EQU 12      ; DB, Address Configuration bits 15 to 14
NIC_TAG                 EQU 13      ; DB, ISA ID tag 1 through 7, 0 if unknown
NIC_ID_MODE             EQU 14      ; DB, 1 short sequence, 0 full sequence
NIC_FLAGS               EQU 15      ; DB
NIC_RECORD_SIZE         EQU 16

NIC_FLAG_ACTIVE         EQU 01h
NIC_FLAG_FROM_ID        EQU 02h
NIC_FLAG_OEM_MAC        EQU 04h

DATASEG

msg_banner      DB  "3Com Etherlink III CLI Configuration Program Version 1.0", 0Dh, 0Ah
                DB  "derived from the original 3Com Etherlink III Configuration Utility v3.4", 0Dh, 0Ah, 0Dh, 0Ah, '$'

msg_help        DB  "Usage: 3CCFGCLI [COMMAND]", 0Dh, 0Ah, 0Dh, 0Ah
                DB  "Commands:", 0Dh, 0Ah
                DB  "  /? or /H          Display this help screen.", 0Dh, 0Ah
                DB  "  LIST              Detect and display 3C509 and 3C509B adapters.", 0Dh, 0Ah
                DB  "  CONFIGURE         Disabled in this hardware enumeration build.", 0Dh, 0Ah, '$'

msg_no_cards    DB  "No EtherLink III 3C509 or 3C509B adapters were found.", 0Dh, 0Ah, '$'
msg_cfg_blocked DB  "CONFIGURE is disabled in this hardware enumeration build.", 0Dh, 0Ah, '$'

msg_list_hdr    DB  "NIC            NIC", 0Dh, 0Ah
                DB  "Number         Description", 0Dh, 0Ah
                DB  "------------------------------------------------------------------------", 0Dh, 0Ah, '$'

msg_3com_prefix DB  "3Com ", '$'
msg_3c509       DB  "3C509", '$'
msg_3c509b      DB  "3C509B", '$'
msg_plain       DB  "", '$'
msg_tp          DB  "-TP", '$'
msg_combo       DB  "-Combo", '$'
msg_tpo         DB  "-TPO", '$'
msg_tpcoax      DB  "-TPCoax", '$'
msg_unknown     DB  "-EtherLinkIII", '$'
msg_eth_addr    DB  ": Ethernet Address = ", '$'
msg_io          DB  ", I/O = ", '$'
msg_irq         DB  ", IRQ = ", '$'
msg_no_io       DB  "unassigned", '$'
msg_crlf        DB  0Dh, 0Ah, '$'

card_count      DW  0
current_card    DW  0
nic_table       DB  (MAX_CARDS * NIC_RECORD_SIZE) DUP(0)

; Discovery state.
id_short_mode   DB  1
id_next_tag     DB  1
id_mfr          DW  0
id_product      DW  0
id_factory0     DW  0
id_factory1     DW  0
id_factory2     DW  0
id_oem0         DW  0
id_oem1         DW  0
id_oem2         DW  0
id_addr_cfg     DW  0
id_resource_cfg DW  0
id_sw_info      DW  0

; All 31 valid selectable 3C509 ISA I O bases.
; EEPROM Address Configuration bits 4 to 0 encode indexes 0 through 30.
; Index 31 means no assigned base, therefore 03F0h is not a valid selection.
io_scan_table   DW  0300h, 0310h, 0320h, 0330h, 0340h, 0350h, 0360h, 0370h
                DW  0380h, 0390h, 03A0h, 03B0h, 03C0h, 03D0h, 03E0h
                DW  0200h, 0210h, 0220h, 0230h, 0240h, 0250h, 0260h, 0270h
                DW  0280h, 0290h, 02A0h, 02B0h, 02C0h, 02D0h, 02E0h, 02F0h
                DW  0000h

cmd_buffer      DB  128 DUP(0)

CODESEG

; ----------------------------------------------------------------------------
; Program entry
; ----------------------------------------------------------------------------
Start:
    mov     ax, @data
    mov     es, ax

    ; DS still points at the PSP here.  Copy the DOS command line first.
    mov     si, 81h
    mov     cl, [BYTE ds:80h]
    xor     ch, ch
    mov     di, OFFSET cmd_buffer
    jcxz    @@CopyDone

@@CopyLoop:
    lodsb
    cmp     al, 0Dh
    je      @@CopyDone
    cmp     al, 'a'
    jb      @@StoreChar
    cmp     al, 'z'
    ja      @@StoreChar
    sub     al, 20h
@@StoreChar:
    stosb
    loop    @@CopyLoop

@@CopyDone:
    xor     al, al
    stosb

    mov     ax, @data
    mov     ds, ax

    mov     dx, OFFSET msg_banner
    mov     ah, 09h
    int     21h

    call    Parse_And_Execute

    mov     ax, 4C00h
    int     21h

; ----------------------------------------------------------------------------
; Command parser
; ----------------------------------------------------------------------------
PROC Parse_And_Execute NEAR
    mov     si, OFFSET cmd_buffer

@@SkipWhite:
    mov     al, [si]
    cmp     al, ' '
    je      @@AdvanceWhite
    cmp     al, 09h
    jne     @@HaveToken
@@AdvanceWhite:
    inc     si
    jmp     @@SkipWhite

@@HaveToken:
    or      al, al
    jz      @@Help

    cmp     al, '?'
    je      @@Help
    cmp     al, '/'
    je      @@Slash
    cmp     al, '-'
    je      @@Slash

    ; HELP
    cmp     [BYTE si], 'H'
    jne     @@TryList
    cmp     [BYTE si+1], 'E'
    jne     @@TryList
    cmp     [BYTE si+2], 'L'
    jne     @@TryList
    cmp     [BYTE si+3], 'P'
    je      @@Help

@@TryList:
    cmp     [BYTE si], 'L'
    jne     @@TryConfig
    cmp     [BYTE si+1], 'I'
    jne     @@TryConfig
    cmp     [BYTE si+2], 'S'
    jne     @@TryConfig
    cmp     [BYTE si+3], 'T'
    jne     @@TryConfig
    mov     al, [si+4]
    or      al, al
    jz      @@List
    cmp     al, ' '
    je      @@List
    cmp     al, 09h
    je      @@List
    jmp     @@Help

@@TryConfig:
    cmp     [BYTE si], 'C'
    jne     @@Help
    cmp     [BYTE si+1], 'O'
    jne     @@Help
    cmp     [BYTE si+2], 'N'
    jne     @@Help
    cmp     [BYTE si+3], 'F'
    jne     @@Help
    cmp     [BYTE si+4], 'I'
    jne     @@Help
    cmp     [BYTE si+5], 'G'
    jne     @@Help
    mov     dx, OFFSET msg_cfg_blocked
    mov     ah, 09h
    int     21h
    ret

@@Slash:
    inc     si
    cmp     [BYTE si], '?'
    je      @@Help
    cmp     [BYTE si], 'H'
    je      @@Help
    jmp     @@Help

@@List:
    call    Cmd_List
    ret

@@Help:
    mov     dx, OFFSET msg_help
    mov     ah, 09h
    int     21h
    ret
ENDP Parse_And_Execute

; ============================================================================
; LIST command
; ============================================================================
PROC Cmd_List NEAR
    call    Scan_All_3Com_Cards

    cmp     [card_count], 0
    jne     @@HaveCards

    mov     dx, OFFSET msg_no_cards
    mov     ah, 09h
    int     21h
    ret

@@HaveCards:
    mov     dx, OFFSET msg_list_hdr
    mov     ah, 09h
    int     21h

    mov     [current_card], 0
    mov     si, OFFSET nic_table

@@PrintLoop:
    mov     dl, ' '
    mov     ah, 02h
    int     21h
    mov     dl, ' '
    int     21h

    mov     ax, [current_card]
    inc     ax
    call    Print_DecByte

    mov     dl, ' '
    mov     ah, 02h
    int     21h
    int     21h
    int     21h
    int     21h

    mov     dx, OFFSET msg_3com_prefix
    mov     ah, 09h
    int     21h

    mov     al, [BYTE si + NIC_ASIC_REV]
    cmp     al, 0FFh
    je      @@ModelUnknownRevision
    cmp     al, 2
    jae     @@ModelB
@@ModelUnknownRevision:
    mov     dx, OFFSET msg_3c509
    jmp     @@PrintModel
@@ModelB:
    mov     dx, OFFSET msg_3c509b
@@PrintModel:
    mov     ah, 09h
    int     21h

    mov     ax, [WORD si + NIC_PRODUCT_ID]
    cmp     ax, PRODUCT_3C509
    je      @@SuffixPlain
    cmp     ax, PRODUCT_3C509_TP
    je      @@SuffixTP
    cmp     ax, PRODUCT_3C509_COMBO
    je      @@SuffixCombo
    cmp     ax, PRODUCT_3C509_TPO
    je      @@SuffixTPO
    cmp     ax, PRODUCT_3C509_TPC
    je      @@SuffixTPC
    mov     dx, OFFSET msg_unknown
    jmp     @@PrintSuffix
@@SuffixPlain:
    mov     dx, OFFSET msg_plain
    jmp     @@PrintSuffix
@@SuffixTP:
    mov     dx, OFFSET msg_tp
    jmp     @@PrintSuffix
@@SuffixCombo:
    mov     dx, OFFSET msg_combo
    jmp     @@PrintSuffix
@@SuffixTPO:
    mov     dx, OFFSET msg_tpo
    jmp     @@PrintSuffix
@@SuffixTPC:
    mov     dx, OFFSET msg_tpcoax
@@PrintSuffix:
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_eth_addr
    mov     ah, 09h
    int     21h

    push    si
    add     si, NIC_MAC_ADDR
    mov     cx, 6
@@PrintMac:
    lodsb
    call    Print_HexByte
    loop    @@PrintMac
    pop     si

    mov     dx, OFFSET msg_io
    mov     ah, 09h
    int     21h
    mov     ax, [WORD si + NIC_IO_BASE]
    or      ax, ax
    jz      @@PrintNoIo
    call    Print_HexWord
    jmp     @@PrintIrq
@@PrintNoIo:
    mov     dx, OFFSET msg_no_io
    mov     ah, 09h
    int     21h

@@PrintIrq:
    mov     dx, OFFSET msg_irq
    mov     ah, 09h
    int     21h
    xor     ax, ax
    mov     al, [BYTE si + NIC_IRQ_VAL]
    call    Print_DecByte

    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    add     si, NIC_RECORD_SIZE
    inc     [current_card]
    mov     ax, [current_card]
    cmp     ax, [card_count]
    jb      @@PrintLoop
    ret
ENDP Cmd_List

; ============================================================================
; Complete scan coordinator
; ============================================================================
PROC Scan_All_3Com_Cards NEAR
    push    ax
    push    cx
    push    di

    mov     [card_count], 0
    mov     [current_card], 0
    mov     [id_short_mode], 1
    mov     [id_next_tag], 1

    ; Clear the complete record table.
    mov     di, OFFSET nic_table
    mov     cx, MAX_CARDS * NIC_RECORD_SIZE
    xor     ax, ax
@@ClearTable:
    mov     [di], al
    inc     di
    loop    @@ClearTable

    ; First perform the proprietary 3Com ISA ID port discovery.
    call    Discover_Id_Port_Cards

    ; The original program tags the contenders first and activates them later.
    call    Activate_Tagged_Cards

    ; Finally examine all valid active I O bases.  This also catches a board
    ; that was already active before the proprietary ID sequence was entered.
    call    Scan_Active_Base_Ports

    pop     di
    pop     cx
    pop     ax
    ret
ENDP Scan_All_3Com_Cards

; ============================================================================
; ISA ID port discovery
; ============================================================================

; Send the complete 255 byte LFSR sequence.
; This matches original sub_328.
PROC IdPort_Send_Full_Sequence NEAR
    push    ax
    push    cx
    push    dx

    mov     dx, ID_PORT
    xor     al, al
    out     dx, al
    out     dx, al

    mov     al, 0FFh
    mov     cx, 255
@@Loop:
    out     dx, al
    test    al, 80h
    jz      @@ShiftOnly
    shl     al, 1
    xor     al, 0CFh
    jmp     @@Next
@@ShiftOnly:
    shl     al, 1
@@Next:
    loop    @@Loop

    pop     dx
    pop     cx
    pop     ax
    ret
ENDP IdPort_Send_Full_Sequence

; Send the first 8 bytes of the same LFSR stream.
; This matches original sub_329.
PROC IdPort_Send_Short_Sequence NEAR
    push    ax
    push    cx
    push    dx

    mov     dx, ID_PORT
    xor     al, al
    out     dx, al
    out     dx, al

    mov     al, 0FFh
    mov     cx, 8
@@Loop:
    out     dx, al
    test    al, 80h
    jz      @@ShiftOnly
    shl     al, 1
    xor     al, 0CFh
    jmp     @@Next
@@ShiftOnly:
    shl     al, 1
@@Next:
    loop    @@Loop

    pop     dx
    pop     cx
    pop     ax
    ret
ENDP IdPort_Send_Short_Sequence

; Conservative delay after an ID port EEPROM read command.
; The hardware minimum is about 162 microseconds.  The original utility uses
; a calibrated delay routine.  This reduced build uses repeated ISA I O reads
; so it remains valid on an 8086 and is intentionally longer than the minimum.
PROC IdPort_Eeprom_Delay NEAR
    push    ax
    push    cx
    mov     cx, 2000
@@Delay:
    in      al, 0EDh
    loop    @@Delay
    pop     cx
    pop     ax
    ret
ENDP IdPort_Eeprom_Delay

; Read one 16 bit EEPROM word through the ISA ID port.
; Input: AL = EEPROM word index, without the 80h read opcode.
; Output: AX = word, assembled MSB first.
;
; A separate SI accumulator is essential.  The failed reimplementation used
; AL both as the port input byte and as the low byte of AX, destroying the
; partially assembled word at every bit.
PROC IdPort_Read_Word NEAR
    push    bx
    push    cx
    push    dx
    push    si

    mov     dx, ID_PORT
    and     al, 3Fh
    or      al, 80h
    out     dx, al
    call    IdPort_Eeprom_Delay

    xor     si, si
    mov     cx, 16
@@BitLoop:
    shl     si, 1
    in      al, dx
    and     al, 01h
    xor     ah, ah
    or      si, ax
    loop    @@BitLoop

    mov     ax, si

    pop     si
    pop     dx
    pop     cx
    pop     bx
    ret
ENDP IdPort_Read_Word

; Return carry clear for a product in the 3C509 family.
; The original enumeration applies F0FFh and accepts 9050h family products.
PROC Is_3C509_Family NEAR
    push    ax
    and     ax, 0F0FFh
    cmp     ax, 09050h
    jne     @@No
    pop     ax
    clc
    ret
@@No:
    pop     ax
    stc
    ret
ENDP Is_3C509_Family

; Initialize both ID sequence modes exactly in the order used by sub_332.
PROC IdPort_Initialize NEAR
    push    ax
    push    dx

    cli
    call    IdPort_Send_Full_Sequence
    mov     dx, ID_PORT
    mov     al, ID_CMD_SET_TAG
    out     dx, al

    call    IdPort_Send_Short_Sequence
    mov     dx, ID_PORT
    mov     al, ID_CMD_SET_TAG
    out     dx, al
    sti

    pop     dx
    pop     ax
    ret
ENDP IdPort_Initialize

; Read the fields needed to construct one record while the current contender
; still owns the ID port.
PROC Read_Id_Contender_Data NEAR
    push    ax

    mov     al, EEPROM_NODE_0
    call    IdPort_Read_Word
    mov     [id_factory0], ax

    mov     al, EEPROM_NODE_1
    call    IdPort_Read_Word
    mov     [id_factory1], ax

    mov     al, EEPROM_NODE_2
    call    IdPort_Read_Word
    mov     [id_factory2], ax

    mov     al, EEPROM_ADDR_CFG
    call    IdPort_Read_Word
    mov     [id_addr_cfg], ax

    mov     al, EEPROM_RESOURCE_CFG
    call    IdPort_Read_Word
    mov     [id_resource_cfg], ax

    ; Original sub_339 stores the OEM node address at words 0Ah through 0Ch.
    mov     al, EEPROM_OEM_NODE_0
    call    IdPort_Read_Word
    mov     [id_oem0], ax

    mov     al, EEPROM_OEM_NODE_1
    call    IdPort_Read_Word
    mov     [id_oem1], ax

    mov     al, EEPROM_OEM_NODE_2
    call    IdPort_Read_Word
    mov     [id_oem2], ax

    mov     al, EEPROM_SOFTWARE_INFO
    call    IdPort_Read_Word
    mov     [id_sw_info], ax

    pop     ax
    ret
ENDP Read_Id_Contender_Data

; Normalize an EEPROM Resource Configuration IRQ nibble.
; Original sub_339 accepts IRQ 3, 5, 7, 9, 10, 11, 12 and 15.
; Invalid encodings are replaced with IRQ 10 in the record.
PROC Normalize_IRQ NEAR
    cmp     al, 3
    je      @@Good
    cmp     al, 5
    je      @@Good
    cmp     al, 7
    je      @@Good
    cmp     al, 9
    je      @@Good
    cmp     al, 10
    je      @@Good
    cmp     al, 11
    je      @@Good
    cmp     al, 12
    je      @@Good
    cmp     al, 15
    je      @@Good
    mov     al, 10
@@Good:
    ret
ENDP Normalize_IRQ

; Store one word as two network order MAC bytes at DS:DI.
; Input AX = EEPROM word, DI = byte destination.
PROC Store_Mac_Word NEAR
    mov     [BYTE di], ah
    mov     [BYTE di+1], al
    add     di, 2
    ret
ENDP Store_Mac_Word

; Create one local record from the ID port temporary variables.
; Input DI = destination record, AL = assigned tag.
PROC Build_Record_From_Id NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    di

    mov     [BYTE di + NIC_TAG], al
    mov     al, [id_short_mode]
    mov     [BYTE di + NIC_ID_MODE], al
    mov     [BYTE di + NIC_FLAGS], NIC_FLAG_FROM_ID
    mov     [BYTE di + NIC_ASIC_REV], 0FFh

    mov     ax, [id_product]
    mov     [WORD di + NIC_PRODUCT_ID], ax

    ; Address Configuration bits 4 to 0 select 0200h plus index times 10h.
    ; Value 1Fh means no assigned I O base.
    mov     ax, [id_addr_cfg]
    and     ax, 001Fh
    cmp     ax, 001Fh
    je      @@NoBase
    mov     cl, 4
    shl     ax, cl
    add     ax, 0200h
    mov     [WORD di + NIC_IO_BASE], ax
    jmp     @@HaveBase
@@NoBase:
    mov     [WORD di + NIC_IO_BASE], 0
@@HaveBase:

    ; Resource Configuration bits 15 to 12 contain the actual IRQ number.
    mov     ax, [id_resource_cfg]
    mov     cl, 12
    shr     ax, cl
    call    Normalize_IRQ
    mov     [BYTE di + NIC_IRQ_VAL], al

    ; Address Configuration bits 15 to 14 contain the media selection.
    mov     ax, [id_addr_cfg]
    mov     cl, 14
    shr     ax, cl
    and     al, 03h
    cmp     al, 2
    jne     @@MediaGood
    mov     al, 1
@@MediaGood:
    mov     [BYTE di + NIC_PORT_TYPE], al

    ; Original sub_339 stores EEPROM words 0Ah through 0Ch in the record.
    ; Words 0 through 2 were still read above because they are the standard
    ; station address words used by the ISA contention protocol.
    or      [BYTE di + NIC_FLAGS], NIC_FLAG_OEM_MAC
    add     di, NIC_MAC_ADDR
    mov     ax, [id_oem0]
    call    Store_Mac_Word
    mov     ax, [id_oem1]
    call    Store_Mac_Word
    mov     ax, [id_oem2]
    call    Store_Mac_Word

@@Done:
    pop     di
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Build_Record_From_Id

; Compare temporary contender identity with an existing record table entry.
; Output carry clear and AL = existing tag when found, carry set otherwise.
PROC Find_Duplicate_Id_Record NEAR
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    mov     cx, [card_count]
    or      cx, cx
    jz      @@NotFound
    mov     si, OFFSET nic_table

@@RecordLoop:
    ; Compare the OEM address words exactly as original sub_332 does.
    mov     ax, [id_oem0]
    mov     bx, [id_oem1]
    mov     dx, [id_oem2]
    cmp     [BYTE si + NIC_MAC_ADDR + 0], ah
    jne     @@Next
    cmp     [BYTE si + NIC_MAC_ADDR + 1], al
    jne     @@Next
    cmp     [BYTE si + NIC_MAC_ADDR + 2], bh
    jne     @@Next
    cmp     [BYTE si + NIC_MAC_ADDR + 3], bl
    jne     @@Next
    mov     di, dx
    cmp     [BYTE si + NIC_MAC_ADDR + 4], dh
    jne     @@Next
    cmp     [BYTE si + NIC_MAC_ADDR + 5], dl
    jne     @@Next

    mov     al, [BYTE si + NIC_TAG]
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    clc
    ret

@@Next:
    add     si, NIC_RECORD_SIZE
    loop    @@RecordLoop

@@NotFound:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    stc
    ret
ENDP Find_Duplicate_Id_Record

PROC Discover_Id_Port_Cards NEAR
    push    ax
    push    bx
    push    dx
    push    di

    call    IdPort_Initialize

@@ProbeAgain:
    mov     al, [id_next_tag]
    cmp     al, MAX_CARDS
    ja      @@Done

    cli
    cmp     [id_short_mode], 0
    je      @@UseFull
    call    IdPort_Send_Short_Sequence
    jmp     @@SequenceReady
@@UseFull:
    call    IdPort_Send_Full_Sequence
@@SequenceReady:

    ; The original presence test is manufacturer word 7, not node word 0.
    mov     al, EEPROM_MFG_ID
    call    IdPort_Read_Word
    mov     [id_mfr], ax
    cmp     ax, 06D50h
    je      @@ManufacturerGood

    sti
    cmp     [id_short_mode], 0
    je      @@Done
    mov     [id_short_mode], 0
    jmp     @@ProbeAgain

@@ManufacturerGood:
    mov     al, EEPROM_PRODUCT_ID
    call    IdPort_Read_Word
    mov     [id_product], ax
    call    Is_3C509_Family
    jnc     @@ProductGood

    ; Original sub_332 also has an 8050h family branch for other EtherLink III
    ; members.  This reduced executable is intentionally restricted to 3C509.
    sti
    cmp     [id_short_mode], 0
    je      @@Done
    mov     [id_short_mode], 0
    jmp     @@ProbeAgain

@@ProductGood:
    ; Reading the node address also performs the standard contention process.
    call    Read_Id_Contender_Data

    ; Suppress a duplicate identity and reapply its existing tag.  This mirrors
    ; the original duplicate path used when the same board is visible by more
    ; than one enumeration mechanism.
    call    Find_Duplicate_Id_Record
    jc      @@NewRecord
    and     al, 07h
    or      al, ID_CMD_SET_TAG
    mov     dx, ID_PORT
    out     dx, al
    sti
    jmp     @@ProbeAgain

@@NewRecord:
    mov     ax, [card_count]
    cmp     ax, MAX_CARDS
    jae     @@StopWithInterrupts

    mov     bx, NIC_RECORD_SIZE
    mul     bx
    mov     di, OFFSET nic_table
    add     di, ax

    mov     al, [id_next_tag]
    call    Build_Record_From_Id

    ; Tag the selected contender before another ID sequence is sent.
    mov     al, [id_next_tag]
    and     al, 07h
    or      al, ID_CMD_SET_TAG
    mov     dx, ID_PORT
    out     dx, al

    inc     [card_count]
    inc     [id_next_tag]
    sti
    jmp     @@ProbeAgain

@@StopWithInterrupts:
    sti
@@Done:
    pop     di
    pop     dx
    pop     bx
    pop     ax
    ret
ENDP Discover_Id_Port_Cards

; ============================================================================
; Activation of tagged ISA adapters
; ============================================================================
PROC Activate_Tagged_Cards NEAR
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

    cli
    cmp     [BYTE si + NIC_ID_MODE], 0
    je      @@Full
    call    IdPort_Send_Short_Sequence
    jmp     @@SelectTag
@@Full:
    call    IdPort_Send_Full_Sequence

@@SelectTag:
    mov     dx, ID_PORT
    mov     al, [BYTE si + NIC_TAG]
    and     al, 07h
    or      al, ID_CMD_SELECT_TAG
    out     dx, al

    ; Activation is E0h plus the encoded base index, not C0h.
    mov     ax, [WORD si + NIC_IO_BASE]
    sub     ax, 0200h
    shr     ax, 1
    shr     ax, 1
    shr     ax, 1
    shr     ax, 1
    and     al, 1Fh
    or      al, ID_CMD_ACTIVATE
    mov     dx, ID_PORT
    out     dx, al
    sti

    ; Verify register window signature and obtain ASIC revision.
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Check_3Com_Signature
    jc      @@NextAfterVerify
    mov     [WORD si + NIC_PRODUCT_ID], ax
    mov     [BYTE si + NIC_ASIC_REV], bl
    or      [BYTE si + NIC_FLAGS], NIC_FLAG_ACTIVE

@@NextAfterVerify:
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
ENDP Activate_Tagged_Cards

; ============================================================================
; Active register access and signature verification
; ============================================================================

; Input DX = base, AL = window 0 through 7.
PROC Select_Window NEAR
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
ENDP Select_Window

; Input DX = base.  Output AX = current window number.
PROC Get_Current_Window NEAR
    push    cx
    push    dx
    add     dx, EL3_STATUS
    in      ax, dx
    mov     cl, 13
    shr     ax, cl
    and     ax, 0007h
    pop     dx
    pop     cx
    ret
ENDP Get_Current_Window

; Input DX = base.  Carry clear when command busy has cleared.
PROC Wait_Command_Ready NEAR
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
ENDP Wait_Command_Ready

; Verify a live 3C509 register image.
; Input DX = candidate base.
; Output CF clear on success, AX = normalized product ID, BL = ASIC revision.
; The normal x86 word order is 6D50h.  A byte swapped 506Dh read is accepted
; defensively and the product ID is normalized in the same way.
PROC Check_3Com_Signature NEAR
    push    cx
    push    dx
    push    si
    push    di

    mov     si, dx
    mov     ch, 0FFh               ; Saved window, FFh means not saved yet.
    xor     bh, bh                 ; BH = 1 when register words are swapped.

    add     dx, EL3_STATUS
    in      ax, dx
    cmp     ax, 0FFFFh
    je      @@Fail

    mov     dx, si
    call    Wait_Command_Ready
    jc      @@Fail

    mov     dx, si
    call    Get_Current_Window
    mov     ch, al

    mov     dx, si
    xor     al, al
    call    Select_Window

    mov     dx, si
    in      ax, dx
    cmp     ax, 06D50h
    je      @@MfgGood
    cmp     ax, 0506Dh
    jne     @@RestoreFail
    mov     bh, 1

@@MfgGood:
    mov     dx, si
    add     dx, EL3_W0_PRODUCT_ID
    in      ax, dx
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
    call    Select_Window

    mov     dx, si
    add     dx, EL3_W4_NET_DIAG
    in      ax, dx
    cmp     bh, 0
    je      @@NetDiagOrderGood
    xchg    al, ah
@@NetDiagOrderGood:
    and     ax, 003Eh
    shr     ax, 1
    mov     bl, al

    mov     dx, si
    mov     al, ch
    call    Select_Window

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
    call    Select_Window
@@Fail:
    pop     di
    pop     si
    pop     dx
    pop     cx
    stc
    ret
ENDP Check_3Com_Signature

; ============================================================================
; Active EEPROM access
; ============================================================================
; Input DX = base, AL = EEPROM word index.
; Output AX = EEPROM word, FFFFh on timeout.
PROC EEPROM_Read NEAR
    push    bx
    push    cx
    push    dx
    push    si

    xor     ah, ah
    mov     si, ax

    xor     al, al
    call    Select_Window

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
    jmp     @@Done

@@ReadData:
    add     dx, 2
    in      ax, dx

@@Done:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    ret
ENDP EEPROM_Read

; Build a record from an adapter that is already active at DX.
; Input DX = base, DI = destination record, AX = product ID, BL = ASIC rev.
PROC Build_Record_From_Active NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    mov     [WORD di + NIC_IO_BASE], dx
    mov     [WORD di + NIC_PRODUCT_ID], ax
    mov     [BYTE di + NIC_ASIC_REV], bl
    mov     [BYTE di + NIC_TAG], 0
    mov     [BYTE di + NIC_ID_MODE], 0
    mov     [BYTE di + NIC_FLAGS], NIC_FLAG_ACTIVE

    mov     si, dx

    mov     al, EEPROM_ADDR_CFG
    call    EEPROM_Read
    mov     [id_addr_cfg], ax

    mov     dx, si
    mov     al, EEPROM_RESOURCE_CFG
    call    EEPROM_Read
    mov     [id_resource_cfg], ax

    mov     dx, si
    mov     al, EEPROM_NODE_0
    call    EEPROM_Read
    mov     [id_factory0], ax
    mov     dx, si
    mov     al, EEPROM_NODE_1
    call    EEPROM_Read
    mov     [id_factory1], ax
    mov     dx, si
    mov     al, EEPROM_NODE_2
    call    EEPROM_Read
    mov     [id_factory2], ax

    mov     dx, si
    mov     al, EEPROM_OEM_NODE_0
    call    EEPROM_Read
    mov     [id_oem0], ax
    mov     dx, si
    mov     al, EEPROM_OEM_NODE_1
    call    EEPROM_Read
    mov     [id_oem1], ax
    mov     dx, si
    mov     al, EEPROM_OEM_NODE_2
    call    EEPROM_Read
    mov     [id_oem2], ax

    mov     ax, [id_resource_cfg]
    mov     cl, 12
    shr     ax, cl
    call    Normalize_IRQ
    mov     [BYTE di + NIC_IRQ_VAL], al

    mov     ax, [id_addr_cfg]
    mov     cl, 14
    shr     ax, cl
    and     al, 03h
    cmp     al, 2
    jne     @@MediaGood
    mov     al, 1
@@MediaGood:
    mov     [BYTE di + NIC_PORT_TYPE], al

    ; Mirror the original record layout by displaying the OEM node address.
    or      [BYTE di + NIC_FLAGS], NIC_FLAG_OEM_MAC
    add     di, NIC_MAC_ADDR
    mov     ax, [id_oem0]
    call    Store_Mac_Word
    mov     ax, [id_oem1]
    call    Store_Mac_Word
    mov     ax, [id_oem2]
    call    Store_Mac_Word

@@Done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Build_Record_From_Active

; Return carry clear if a record with base DX already exists.
PROC Find_Record_By_Base NEAR
    push    ax
    push    cx
    push    si

    mov     cx, [card_count]
    or      cx, cx
    jz      @@NotFound
    mov     si, OFFSET nic_table
@@Loop:
    mov     ax, [WORD si + NIC_IO_BASE]
    cmp     ax, dx
    je      @@Found
    add     si, NIC_RECORD_SIZE
    loop    @@Loop
@@NotFound:
    pop     si
    pop     cx
    pop     ax
    stc
    ret
@@Found:
    pop     si
    pop     cx
    pop     ax
    clc
    ret
ENDP Find_Record_By_Base

; Scan every valid base address.  There are exactly 31 selectable bases.
PROC Scan_Active_Base_Ports NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    mov     si, OFFSET io_scan_table
@@PortLoop:
    lodsw
    or      ax, ax
    jz      @@Done
    mov     dx, ax

    call    Check_3Com_Signature
    jc      @@PortLoop

    push    ax
    call    Find_Record_By_Base
    pop     ax
    jnc     @@UpdateExisting

    mov     cx, [card_count]
    cmp     cx, MAX_CARDS
    jae     @@Done

    mov     ax, cx
    mov     bx, NIC_RECORD_SIZE
    mul     bx
    mov     di, OFFSET nic_table
    add     di, ax

    mov     dx, [si-2]
    call    Check_3Com_Signature
    jc      @@PortLoop
    call    Build_Record_From_Active
    inc     [card_count]
    jmp     @@PortLoop

@@UpdateExisting:
    ; Find_Record_By_Base preserves SI, so locate the matching entry again and
    ; refresh product and revision from the live hardware.
    mov     dx, [si-2]
    mov     cx, [card_count]
    mov     di, OFFSET nic_table
@@FindExisting:
    cmp     [WORD di + NIC_IO_BASE], dx
    je      @@Refresh
    add     di, NIC_RECORD_SIZE
    loop    @@FindExisting
    jmp     @@PortLoop
@@Refresh:
    call    Check_3Com_Signature
    jc      @@PortLoop
    mov     [WORD di + NIC_PRODUCT_ID], ax
    mov     [BYTE di + NIC_ASIC_REV], bl
    or      [BYTE di + NIC_FLAGS], NIC_FLAG_ACTIVE
    jmp     @@PortLoop

@@Done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Scan_Active_Base_Ports

; ============================================================================
; Printing helpers
; ============================================================================
PROC Print_HexNibble NEAR
    and     al, 0Fh
    add     al, '0'
    cmp     al, '9'
    jbe     @@Out
    add     al, 7
@@Out:
    mov     dl, al
    mov     ah, 02h
    int     21h
    ret
ENDP Print_HexNibble

PROC Print_HexByte NEAR
    push    ax
    push    bx
    mov     bl, al
    shr     al, 1
    shr     al, 1
    shr     al, 1
    shr     al, 1
    call    Print_HexNibble
    mov     al, bl
    call    Print_HexNibble
    pop     bx
    pop     ax
    ret
ENDP Print_HexByte

PROC Print_HexWord NEAR
    push    ax
    mov     al, ah
    call    Print_HexByte
    pop     ax
    call    Print_HexByte
    ret
ENDP Print_HexWord

PROC Print_DecByte NEAR
    push    ax
    push    bx
    push    cx
    push    dx

    xor     ah, ah
    mov     bx, 100
    xor     dx, dx
    div     bx
    mov     ch, al
    mov     ax, dx

    mov     bx, 10
    xor     dx, dx
    div     bx
    mov     cl, al
    mov     bl, dl

    cmp     ch, 0
    je      @@NoHundreds
    mov     dl, ch
    add     dl, '0'
    mov     ah, 02h
    int     21h
    mov     dl, cl
    add     dl, '0'
    int     21h
    jmp     @@Ones

@@NoHundreds:
    cmp     cl, 0
    je      @@Ones
    mov     dl, cl
    add     dl, '0'
    mov     ah, 02h
    int     21h

@@Ones:
    mov     dl, bl
    add     dl, '0'
    mov     ah, 02h
    int     21h

    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Print_DecByte

END Start
