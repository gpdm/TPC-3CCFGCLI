; ============================================================================
; 3CSEED.ASM
; 3C509B mock state seeder utility for 3CCFGCLI mock backend.
; Target: MS-DOS, TASM, 8086/8088.
; ============================================================================

IDEAL
P8086
JUMPS

MODEL SMALL
STACK 200h

include '3C509DEF.INC'

DATASEG

include 'VERSION.INC'

MOCK_STATE_FILE DB '3C509B.MCK', 0

msg_banner_prefix DB '3CSEED - 3C509B mock state seeder v', '$'
msg_banner_suffix DB 0Dh, 0Ah, '$'
msg_help     DB 'Usage: 3CSEED [verb]', 0Dh, 0Ah
             DB '  INIT [options]       Create a 3C509B-TP seed.', 0Dh, 0Ah
             DB '  model [options]      Create one card using the selected model.', 0Dh, 0Ah
             DB '  ADD model [options]  Append one card; defaults pick next free I/O.', 0Dh, 0Ah
             DB '  CLEAR        Delete 3C509B.MCK.', 0Dh, 0Ah
             DB '  3C509B-TP    Seed as 3C509B-TP  (product 9050h, TP + AUI).', 0Dh, 0Ah
             DB '  3C509B-COAX  Seed as 3C509B-COAX (product 9150h, AUI + BNC).', 0Dh, 0Ah
             DB '  3C509B-COMBO Seed as 3C509B-COMBO (product 9450h, TP + AUI + BNC).', 0Dh, 0Ah
             DB '  3C509B-TPO   Seed as 3C509B-TPO  (product 9550h, TP only).', 0Dh, 0Ah
             DB '  3C509B-TPC   Seed as 3C509B-TPC  (product 9850h, coax).', 0Dh, 0Ah
             DB '  3C509-TP     Seed as 3C509-TP (ASIC revision 1, TP + AUI).', 0Dh, 0Ah
             DB '  /IOBASE:value /INT:value  Resource attributes.', 0Dh, 0Ah
             DB '  /MODEMPRESERVE /M1200US /NOLINKBEAT', 0Dh, 0Ah
             DB '  /LINKUP /LINKDOWN /ROM8K /ROM16K /ROM32K /ROMNONE', 0Dh, 0Ah
             DB '$'
msg_ok_init  DB 'Seed file created (INIT).', 0Dh, 0Ah, '$'
msg_ok_clear DB 'Seed file deleted (or already absent).', 0Dh, 0Ah, '$'
msg_ok_tp    DB 'Seed file created (3C509B-TP).', 0Dh, 0Ah, '$'
msg_ok_combo DB 'Seed file created (3C509B-COMBO).', 0Dh, 0Ah, '$'
msg_ok_coax  DB 'Seed file created (3C509B-COAX).', 0Dh, 0Ah, '$'
msg_ok_tpo   DB 'Seed file created (3C509B-TPO).', 0Dh, 0Ah, '$'
msg_ok_tpc   DB 'Seed file created (3C509B-TPC).', 0Dh, 0Ah, '$'
msg_ok_509tp DB 'Seed file created (3C509-TP).', 0Dh, 0Ah, '$'
msg_ok_add   DB 'Seed file updated (ADD).', 0Dh, 0Ah, '$'
msg_fail_io  DB 'File I/O error.', 0Dh, 0Ah, '$'
msg_bad_arg  DB 'Invalid command argument.', 0Dh, 0Ah, '$'
msg_add_too_many DB 'Too many mock NIC records.', 0Dh, 0Ah, '$'
msg_no_free_iobase DB 'No free default IOBASE remains.', 0Dh, 0Ah, '$'
msg_bad_iobase DB 'Invalid IOBASE argument.', 0Dh, 0Ah, '$'
msg_bad_irq  DB 'Invalid IRQ argument.', 0Dh, 0Ah, '$'

kw_init      DB 'INIT', 0
kw_add       DB 'ADD', 0
kw_clear     DB 'CLEAR', 0
kw_tp        DB '3C509B-TP', 0
kw_combo     DB '3C509B-COMBO', 0
kw_coax      DB '3C509B-COAX', 0
kw_tpo       DB '3C509B-TPO', 0
kw_tpc       DB '3C509B-TPC', 0
kw_509tp     DB '3C509-TP', 0
kw_opt_iobase DB '/IOBASE:', 0
kw_opt_int DB '/INT:', 0
kw_opt_modempreserve DB '/MODEMPRESERVE', 0
kw_opt_m1200us DB '/M1200US', 0
kw_opt_nolinkbeat DB '/NOLINKBEAT', 0
kw_opt_linkup DB '/LINKUP', 0
kw_opt_linkdown DB '/LINKDOWN', 0
kw_opt_rom8k DB '/ROM8K', 0
kw_opt_rom16k DB '/ROM16K', 0
kw_opt_rom32k DB '/ROM32K', 0
kw_opt_romnone DB '/ROMNONE', 0

cmd_buffer   DB 128 DUP (0)
state_blob   DB MCK_FILE_SIZE DUP (0)
state_record_offset DW MCK_HEADER_SIZE
state_record_count DB 0

seed_product DW PRODUCT_3C509_TP
seed_base    DW 0300h
seed_irq     DB 10
seed_media   DB 0
seed_config_control DW W0_CONFIG_CONTROL_3C509B_DEFAULT OR W0_CONFIG_CONTROL_AUI_PRESENT
seed_asic_rev DB 2
seed_rom_size DB MCK_ROM_NONE
seed_rom_selected DB 0
seed_link_state DB 1
seed_software_info DW EEPROM_SOFTWARE_INFO_OPTIMIZE_DOS
seed_sw_selected DB 0
seed_base_explicit DB 0

factory_mac  DB 6 DUP (0)
oem_mac      DB 6 DUP (0)

irq_table    DB 3, 5, 7, 9, 10, 11, 12, 15

iobase_table DW 0300h, 0310h, 0320h, 0330h, 0340h, 0350h, 0360h, 0370h
            DW 0380h, 0390h, 03A0h, 03B0h, 03C0h, 03D0h, 03E0h
            DW 0200h, 0210h, 0220h, 0230h, 0240h, 0250h, 0260h, 0270h
            DW 0280h, 0290h, 02A0h, 02B0h, 02C0h, 02D0h, 02E0h, 02F0h

CODESEG

Start:
    mov     ax, @data
    mov     es, ax

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

    mov     dx, OFFSET msg_banner_prefix
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET VERSION_STRING
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET msg_banner_suffix
    mov     ah, 09h
    int     21h

    call    Parse_And_Run

    mov     ax, 4C00h
    int     21h

PROC Parse_And_Run NEAR
    push    ax
    push    dx
    push    si

    mov     si, OFFSET cmd_buffer
@@Skip:
    mov     al, [BYTE si]
    cmp     al, ' '
    je      @@Adv
    cmp     al, 09h
    je      @@Adv
    jmp     @@Token
@@Adv:
    inc     si
    jmp     @@Skip

@@Token:
    or      al, al
    jz      @@Help

    cmp     al, '/'
    je      @@Slash
    cmp     al, '-'
    je      @@Slash

    mov     dx, OFFSET kw_init
    call    Match_Token
    jnc     @@DoInit
    mov     dx, OFFSET kw_add
    call    Match_Token
    jnc     @@DoAdd
    mov     dx, OFFSET kw_clear
    call    Match_Token
    jnc     @@DoClear
    mov     dx, OFFSET kw_tp
    call    Match_Token
    jnc     @@DoTP
    mov     dx, OFFSET kw_combo
    call    Match_Token
    jnc     @@DoCombo
    mov     dx, OFFSET kw_coax
    call    Match_Token
    jnc     @@DoCoax
    mov     dx, OFFSET kw_tpo
    call    Match_Token
    jnc     @@DoTPO
    mov     dx, OFFSET kw_tpc
    call    Match_Token
    jnc     @@DoTPC
    mov     dx, OFFSET kw_509tp
    call    Match_Token
    jnc     @@Do509TP
    mov     dx, OFFSET msg_bad_arg
    mov     ah, 09h
    int     21h
    jmp     @@Help

@@Slash:
    inc     si
    mov     al, [BYTE si]
    cmp     al, '?'
    je      @@Help
    cmp     al, 'H'
    je      @@Help
    mov     dx, OFFSET msg_bad_arg
    mov     ah, 09h
    int     21h
    jmp     @@Help

@@DoInit:
    call    Set_Model_509B_TP
    call    Consume_Token
    call    Seed_Direct
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_init
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoAdd:
    call    Consume_Token
    call    Seed_Add
    jc      @@Done
    mov     dx, OFFSET msg_ok_add
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoClear:
    call    Seed_Clear
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_clear
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoTP:
    call    Set_Model_509B_TP
    call    Consume_Token
    call    Seed_Direct
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_tp
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoCombo:
    call    Set_Model_509B_Combo
    call    Consume_Token
    call    Seed_Direct
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_combo
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoCoax:
    call    Set_Model_509B_Coax
    call    Consume_Token
    call    Seed_Direct
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_coax
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoTPO:
    call    Set_Model_509B_TPO
    call    Consume_Token
    call    Seed_Direct
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_tpo
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoTPC:
    call    Set_Model_509B_TPC
    call    Consume_Token
    call    Seed_Direct
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_tpc
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@Do509TP:
    call    Set_Model_509_TP
    call    Consume_Token
    call    Seed_Direct
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_509tp
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@IoFail:
    mov     dx, OFFSET msg_fail_io
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@Help:
    mov     dx, OFFSET msg_help
    mov     ah, 09h
    int     21h

@@Done:
    pop     si
    pop     dx
    pop     ax
    ret
ENDP Parse_And_Run

PROC Match_Token NEAR
    push    ax
    push    si
    push    di

    mov     di, dx
@@Loop:
    mov     al, [BYTE di]
    or      al, al
    jz      @@EndKeyword
    cmp     al, [BYTE si]
    jne     @@No
    inc     di
    inc     si
    jmp     @@Loop

@@EndKeyword:
    mov     al, [BYTE si]
    or      al, al
    jz      @@Yes
    cmp     al, ' '
    je      @@Yes
    cmp     al, 09h
    je      @@Yes

@@No:
    pop     di
    pop     si
    pop     ax
    stc
    ret
@@Yes:
    pop     di
    pop     si
    pop     ax
    clc
    ret
ENDP Match_Token

PROC Skip_Spaces NEAR
@@Loop:
    mov     al, [BYTE si]
    cmp     al, ' '
    je      @@Advance
    cmp     al, 09h
    je      @@Advance
    ret
@@Advance:
    inc     si
    jmp     @@Loop
ENDP Skip_Spaces

PROC Consume_Token NEAR
@@Loop:
    mov     al, [BYTE si]
    or      al, al
    jz      @@Done
    cmp     al, ' '
    je      @@Done
    cmp     al, 09h
    je      @@Done
    inc     si
    jmp     @@Loop
@@Done:
    ret
ENDP Consume_Token

; Match an option prefix and leave SI after it.  On failure SI is unchanged.
PROC Match_Option_Prefix NEAR
    push    ax
    push    bx
    push    di
    mov     bx, si
    mov     di, dx
@@Loop:
    mov     al, [BYTE di]
    or      al, al
    jz      @@Yes
    cmp     al, [BYTE si]
    jne     @@No
    inc     di
    inc     si
    jmp     @@Loop
@@No:
    mov     si, bx
    pop     di
    pop     bx
    pop     ax
    stc
    ret
@@Yes:
    pop     di
    pop     bx
    pop     ax
    clc
    ret
ENDP Match_Option_Prefix

PROC Reset_Seed_Attributes NEAR
    mov     [seed_base], 0300h
    mov     [seed_irq], 10
    mov     [BYTE seed_base_explicit], 0
    mov     [BYTE seed_rom_size], MCK_ROM_NONE
    mov     [BYTE seed_rom_selected], 0
    mov     [BYTE seed_link_state], 0
    mov     [BYTE seed_sw_selected], 0
    mov     [WORD seed_software_info], EEPROM_SOFTWARE_INFO_OPTIMIZE_DOS
    ret
ENDP Reset_Seed_Attributes

; Parse all slash attributes for the current model.  SI points at the first
; optional attribute and is left at the terminating NUL.
PROC Parse_Seed_Options NEAR
@@Next:
    call    Skip_Spaces
    mov     al, [BYTE si]
    or      al, al
    jz      @@Ok
    cmp     al, '/'
    jne     @@Bad

    mov     dx, OFFSET kw_opt_iobase
    call    Match_Option_Prefix
    jnc     @@IOBase
    mov     dx, OFFSET kw_opt_int
    call    Match_Option_Prefix
    jnc     @@IRQ

    mov     dx, OFFSET kw_opt_modempreserve
    call    Match_Token
    jnc     @@ModemPreserve
    mov     dx, OFFSET kw_opt_m1200us
    call    Match_Token
    jnc     @@M1200
    mov     dx, OFFSET kw_opt_nolinkbeat
    call    Match_Token
    jnc     @@NoLinkBeat
    mov     dx, OFFSET kw_opt_linkup
    call    Match_Token
    jnc     @@LinkUp
    mov     dx, OFFSET kw_opt_linkdown
    call    Match_Token
    jnc     @@LinkDown
    mov     dx, OFFSET kw_opt_rom8k
    call    Match_Token
    jnc     @@Rom8K
    mov     dx, OFFSET kw_opt_rom16k
    call    Match_Token
    jnc     @@Rom16K
    mov     dx, OFFSET kw_opt_rom32k
    call    Match_Token
    jnc     @@Rom32K
    mov     dx, OFFSET kw_opt_romnone
    call    Match_Token
    jnc     @@RomNone
    jmp     @@Bad

@@IOBase:
    call    Parse_IOBase_Token
    jc      @@Bad
    mov     [BYTE seed_base_explicit], 1
    jmp     @@Next
@@IRQ:
    call    Parse_IRQ_Token
    jc      @@Bad
    jmp     @@Next
@@ModemPreserve:
    cmp     [BYTE seed_sw_selected], 0
    jne     @@Bad
    mov     [BYTE seed_sw_selected], 1
    mov     ax, EEPROM_MODEM_1200
    or      ax, EEPROM_SOFTWARE_INFO_LINKBEAT_DISABLE
    or      ax, EEPROM_SOFTWARE_INFO_RESERVED_MASK
    or      ax, EEPROM_SOFTWARE_INFO_OPTIMIZE_MASK
    or      ax, EEPROM_SOFTWARE_INFO_BOOT_PROTOCOL_MASK
    mov     [seed_software_info], ax
    call    Consume_Token
    jmp     @@Next
@@M1200:
    cmp     [BYTE seed_sw_selected], 0
    jne     @@Bad
    mov     [BYTE seed_sw_selected], 1
    mov     [WORD seed_software_info], 2F00h OR EEPROM_SOFTWARE_INFO_OPTIMIZE_DOS
    call    Consume_Token
    jmp     @@Next
@@NoLinkBeat:
    cmp     [BYTE seed_sw_selected], 0
    jne     @@Bad
    mov     [BYTE seed_sw_selected], 1
    mov     [WORD seed_software_info], EEPROM_SOFTWARE_INFO_LINKBEAT_DISABLE OR EEPROM_SOFTWARE_INFO_OPTIMIZE_DOS
    call    Consume_Token
    jmp     @@Next
@@LinkUp:
    cmp     [BYTE seed_link_state], 2
    je      @@Bad
    mov     [BYTE seed_link_state], 1
    call    Consume_Token
    jmp     @@Next
@@LinkDown:
    cmp     [BYTE seed_link_state], 1
    je      @@Bad
    mov     [BYTE seed_link_state], 2
    call    Consume_Token
    jmp     @@Next
@@Rom8K:
    cmp     [BYTE seed_rom_selected], 0
    jne     @@Bad
    mov     [BYTE seed_rom_selected], 1
    mov     [BYTE seed_rom_size], MCK_ROM_8K
    call    Consume_Token
    jmp     @@Next
@@Rom16K:
    cmp     [BYTE seed_rom_selected], 0
    jne     @@Bad
    mov     [BYTE seed_rom_selected], 1
    mov     [BYTE seed_rom_size], MCK_ROM_16K
    call    Consume_Token
    jmp     @@Next
@@Rom32K:
    cmp     [BYTE seed_rom_selected], 0
    jne     @@Bad
    mov     [BYTE seed_rom_selected], 1
    mov     [BYTE seed_rom_size], MCK_ROM_32K
    call    Consume_Token
    jmp     @@Next
@@RomNone:
    cmp     [BYTE seed_rom_selected], 0
    jne     @@Bad
    mov     [BYTE seed_rom_selected], 1
    mov     [BYTE seed_rom_size], MCK_ROM_NONE
    call    Consume_Token
    jmp     @@Next
@@Bad:
    stc
    ret
@@Ok:
    clc
    ret
ENDP Parse_Seed_Options

; Recognize an ADD model token and apply the shared canonical model profile.
PROC Parse_Model_Token NEAR
    push    dx

    mov     dx, OFFSET kw_tp
    call    Match_Token
    jnc     @@TP
    mov     dx, OFFSET kw_combo
    call    Match_Token
    jnc     @@Combo
    mov     dx, OFFSET kw_coax
    call    Match_Token
    jnc     @@Coax
    mov     dx, OFFSET kw_tpo
    call    Match_Token
    jnc     @@TPO
    mov     dx, OFFSET kw_tpc
    call    Match_Token
    jnc     @@TPC
    mov     dx, OFFSET kw_509tp
    call    Match_Token
    jnc     @@P509TP
    pop     dx
    stc
    ret

@@TP:
    call    Set_Model_509B_TP
    call    Consume_Token
    pop     dx
    clc
    ret
@@Coax:
    call    Set_Model_509B_Coax
    call    Consume_Token
    pop     dx
    clc
    ret
@@Combo:
    call    Set_Model_509B_Combo
    call    Consume_Token
    pop     dx
    clc
    ret
@@TPO:
    call    Set_Model_509B_TPO
    call    Consume_Token
    pop     dx
    clc
    ret
@@TPC:
    call    Set_Model_509B_TPC
    call    Consume_Token
    pop     dx
    clc
    ret
@@P509TP:
    call    Set_Model_509_TP
    call    Consume_Token
    pop     dx
    clc
    ret
ENDP Parse_Model_Token

PROC Parse_IOBase_Token NEAR
    push    bx
    push    cx
    push    dx

    xor     dx, dx
    xor     cx, cx
@@Loop:
    mov     al, [BYTE si]
    or      al, al
    jz      @@DoneDigits
    cmp     al, ' '
    je      @@DoneDigits
    cmp     al, 09h
    je      @@DoneDigits
    cmp     al, '0'
    jb      @@Bad
    cmp     al, '9'
    jbe     @@Digit
    cmp     al, 'A'
    jb      @@Bad
    cmp     al, 'F'
    ja      @@Bad
    sub     al, 'A' - 10
    jmp     @@Accumulate
@@Digit:
    sub     al, '0'
@@Accumulate:
    cmp     cx, 4
    jae     @@Bad
    mov     bl, al
    mov     ax, dx
    shl     ax, 1
    jc      @@Bad
    shl     ax, 1
    jc      @@Bad
    shl     ax, 1
    jc      @@Bad
    shl     ax, 1
    jc      @@Bad
    xor     bh, bh
    add     ax, bx
    jc      @@Bad
    mov     dx, ax
    inc     si
    inc     cx
    jmp     @@Loop
@@DoneDigits:
    or      cx, cx
    jz      @@Bad
    mov     ax, dx
    cmp     ax, VALID_IOBASE_MIN
    jb      @@Bad
    cmp     ax, VALID_IOBASE_MAX
    ja      @@Bad
    sub     ax, VALID_IOBASE_MIN
    test    ax, VALID_IOBASE_STEP - 1
    jnz     @@Bad
    add     ax, VALID_IOBASE_MIN
    mov     [seed_base], ax
    pop     dx
    pop     cx
    pop     bx
    clc
    ret
@@Bad:
    pop     dx
    pop     cx
    pop     bx
    stc
    ret
ENDP Parse_IOBase_Token

PROC Parse_IRQ_Token NEAR
    push    bx
    push    cx
    push    dx
    push    di
 
    mov     di, si
    xor     dx, dx
    mov     al, [BYTE di]
    or      al, al
    jz      @@Bad
    cmp     al, ' '
    je      @@Bad
    cmp     al, 09h
    je      @@Bad
    cmp     al, '0'
    jb      @@Bad
    cmp     al, '9'
    ja      @@Bad
    sub     al, '0'
    mov     dl, al
    inc     di
 
    mov     al, [BYTE di]
    or      al, al
    jz      @@CheckValue
    cmp     al, ' '
    je      @@CheckValue
    cmp     al, 09h
    je      @@CheckValue
    cmp     al, '0'
    jb      @@Bad
    cmp     al, '9'
    ja      @@Bad
    sub     al, '0'
    mov     bl, dl
    shl     bl, 1
    mov     cl, bl
    shl     bl, 1
    shl     bl, 1
    add     bl, cl
    add     bl, al
    mov     dl, bl
    inc     di
@@CheckValue:
    mov     si, di
    mov     bx, OFFSET irq_table
    mov     cx, 8
@@Check:
    cmp     dl, [BYTE bx]
    je      @@Good
    inc     bx
    loop    @@Check
    jmp     @@Bad
@@Good:
    mov     [seed_irq], dl
    pop     di
    pop     dx
    pop     cx
    pop     bx
    clc
    ret
@@Bad:
    pop     di
    pop     dx
    pop     cx
    pop     bx
    stc
    ret
ENDP Parse_IRQ_Token

PROC Set_Record_Offset_By_Index NEAR
    push    bx

    xor     bx, bx
    mov     bl, al
    mov     bh, bl
    xor     bl, bl
    add     bx, MCK_HEADER_SIZE
    mov     [state_record_offset], bx

    pop     bx
    ret
ENDP Set_Record_Offset_By_Index

PROC Init_State_Blob NEAR
    push    ax
    push    cx
    push    di

    mov     di, OFFSET state_blob
    mov     cx, MCK_FILE_SIZE
    xor     ax, ax
    rep     stosb

    mov     [BYTE state_blob + MCK_OFF_MAGIC0], MCK_MAGIC_0
    mov     [BYTE state_blob + MCK_OFF_MAGIC1], MCK_MAGIC_1
    mov     [BYTE state_blob + MCK_OFF_MAGIC2], MCK_MAGIC_2
    mov     [BYTE state_blob + MCK_OFF_MAGIC3], MCK_MAGIC_3
    mov     [WORD state_blob + MCK_OFF_VERSION], MCK_VERSION
    mov     [BYTE state_blob + MCK_OFF_RECORD_COUNT], 0
    mov     [byte state_record_count], 0
    mov     [word state_record_offset], MCK_HEADER_SIZE

    pop     di
    pop     cx
    pop     ax
    ret
ENDP Init_State_Blob

PROC Load_State_File NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    call    Init_State_Blob

    mov     dx, OFFSET MOCK_STATE_FILE
    xor     al, al
    mov     ah, 3Dh
    int     21h
    jc      @@Done
    mov     bx, ax
    mov     cx, MCK_FILE_SIZE
    mov     dx, OFFSET state_blob
    mov     ah, 3Fh
    int     21h
    mov     ah, 3Eh
    int     21h

    cmp     [BYTE state_blob + MCK_OFF_MAGIC0], MCK_MAGIC_0
    jne     @@Reset
    cmp     [BYTE state_blob + MCK_OFF_MAGIC1], MCK_MAGIC_1
    jne     @@Reset
    cmp     [BYTE state_blob + MCK_OFF_MAGIC2], MCK_MAGIC_2
    jne     @@Reset
    cmp     [BYTE state_blob + MCK_OFF_MAGIC3], MCK_MAGIC_3
    jne     @@Reset

    mov     ax, [WORD state_blob + MCK_OFF_VERSION]
    cmp     ax, MCK_VERSION
    jne     @@Reset
    mov     al, [BYTE state_blob + MCK_OFF_RECORD_COUNT]
    cmp     al, MCK_MAX_RECORDS
    jbe     @@CountOk
    mov     al, MCK_MAX_RECORDS
@@CountOk:
    mov     [byte state_record_count], al
    mov     [BYTE state_blob + MCK_OFF_RECORD_COUNT], al
    jmp     @@Done

@@Reset:
    call    Init_State_Blob
@@Done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Load_State_File

PROC Is_Base_In_Use NEAR
    push    ax
    push    bx
    push    cx
    push    di

    mov     bx, dx
    xor     ax, ax
    mov     cl, [byte state_record_count]
    xor     ch, ch
@@Loop:
    or      cx, cx
    jz      @@Free
    push    ax
    call    Set_Record_Offset_By_Index
    pop     ax
    mov     di, [state_record_offset]
    cmp     [BYTE state_blob + di + MCK3R_PRESENT], 0
    je      @@Next
    cmp     [WORD state_blob + di + MCK3R_ACTIVE_BASE], bx
    je      @@Used
@@Next:
    inc     al
    dec     cx
    jmp     @@Loop
@@Free:
    pop     di
    pop     cx
    pop     bx
    pop     ax
    clc
    ret
@@Used:
    pop     di
    pop     cx
    pop     bx
    pop     ax
    stc
    ret
ENDP Is_Base_In_Use

PROC Choose_Default_Base NEAR
    push    ax
    push    cx
    push    dx
    push    si

    mov     cx, 31
    mov     si, OFFSET iobase_table
@@Loop:
    mov     dx, [WORD si]
    call    Is_Base_In_Use
    jnc     @@Found
    add     si, 2
    loop    @@Loop
    stc
    jmp     @@Done
@@Found:
    mov     [seed_base], dx
    clc
@@Done:
    pop     si
    pop     dx
    pop     cx
    pop     ax
    ret
ENDP Choose_Default_Base

PROC Set_Default_Macs_For_Index NEAR
    add     al, 1

    mov     [BYTE factory_mac+0], 02h
    mov     [BYTE factory_mac+1], 60h
    mov     [BYTE factory_mac+2], 8Ch
    mov     [BYTE factory_mac+3], 12h
    mov     [BYTE factory_mac+4], 34h
    mov     [BYTE factory_mac+5], al

    mov     [BYTE oem_mac+0], 02h
    mov     [BYTE oem_mac+1], 60h
    mov     [BYTE oem_mac+2], 8Ch
    mov     [BYTE oem_mac+3], 65h
    mov     [BYTE oem_mac+4], 43h
    mov     [BYTE oem_mac+5], al
    ret
ENDP Set_Default_Macs_For_Index

; The selected model setter establishes the SKU profile before this proc.
; Seed_Direct resets seed attributes, parses slash options, then builds and
; persists the complete state.
PROC Seed_Direct NEAR
    call    Reset_Seed_Attributes
    call    Parse_Seed_Options
    jc      @@Bad
    mov     [BYTE factory_mac+0], 02h
    mov     [BYTE factory_mac+1], 60h
    mov     [BYTE factory_mac+2], 8Ch
    mov     [BYTE factory_mac+3], 12h
    mov     [BYTE factory_mac+4], 34h
    mov     [BYTE factory_mac+5], 56h
    mov     [BYTE oem_mac+0], 02h
    mov     [BYTE oem_mac+1], 60h
    mov     [BYTE oem_mac+2], 8Ch
    mov     [BYTE oem_mac+3], 65h
    mov     [BYTE oem_mac+4], 43h
    mov     [BYTE oem_mac+5], 21h
    call    Build_State
    call    Write_State_File
    ret
@@Bad:
    stc
    ret
ENDP Seed_Direct

PROC Seed_Add NEAR
    push    ax
    push    dx
    push    si

    call    Reset_Seed_Attributes

    call    Skip_Spaces
    call    Parse_Model_Token
    jnc     @@ModelOk
    mov     dx, OFFSET msg_bad_arg
    mov     ah, 09h
    int     21h
    stc
    jmp     @@Done

@@ModelOk:
    call    Load_State_File
    mov     al, [byte state_record_count]
    cmp     al, MCK_MAX_RECORDS
    jb      @@RoomOk
    mov     dx, OFFSET msg_add_too_many
    mov     ah, 09h
    int     21h
    stc
    jmp     @@Done

@@RoomOk:
    call    Skip_Spaces
    mov     al, [BYTE si]
    or      al, al
    jz      @@PickDefaultBase
    cmp     al, '/'
    je      @@SlashOptions
    jmp     @@BadAddOptions

@@SlashOptions:
    call    Parse_Seed_Options
    jc      @@BadAddOptions
    call    Skip_Spaces
    cmp     [BYTE si], 0
    jne     @@BadAddOptions
    cmp     [BYTE seed_base_explicit], 0
    jne     @@Append
    jmp     @@PickDefaultBase

@@BadAddOptions:
    mov     dx, OFFSET msg_bad_arg
    mov     ah, 09h
    int     21h
    stc
    jmp     @@Done

@@PickDefaultBase:
    call    Choose_Default_Base
    jnc     @@Append
    mov     dx, OFFSET msg_no_free_iobase
    mov     ah, 09h
    int     21h
    stc
    jmp     @@Done

@@Append:
    mov     al, [byte state_record_count]
    call    Set_Default_Macs_For_Index
    mov     al, [byte state_record_count]
    call    Set_Record_Offset_By_Index
    call    Build_Record_Current
    inc     [byte state_record_count]
    mov     al, [byte state_record_count]
    mov     [BYTE state_blob + MCK_OFF_RECORD_COUNT], al
    call    Write_State_File
    jnc     @@Success
    mov     dx, OFFSET msg_fail_io
    mov     ah, 09h
    int     21h
    stc
    jmp     @@Done

@@Success:
    clc
@@Done:
    pop     si
    pop     dx
    pop     ax
    ret
ENDP Seed_Add

PROC Seed_Clear NEAR
    push    ax
    push    dx

    mov     dx, OFFSET MOCK_STATE_FILE
    mov     ah, 41h
    int     21h
    jnc     @@Ok
    cmp     ax, 2
    jne     @@Fail
@@Ok:
    pop     dx
    pop     ax
    clc
    ret
@@Fail:
    pop     dx
    pop     ax
    stc
    ret
ENDP Seed_Clear

; ---------------------------------------------------------------------------
; Canonical model profile setters shared by direct model commands and ADD.
; ---------------------------------------------------------------------------

PROC Set_Model_509B_TP NEAR
    ; 3C509B-TP: product 9050h, TP + AUI connectors.
    mov     [seed_product], PRODUCT_3C509_TP
    mov     [seed_media], 0
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT OR W0_CONFIG_CONTROL_AUI_PRESENT
    mov     [byte seed_asic_rev], 2
    ret
ENDP Set_Model_509B_TP

PROC Set_Model_509B_Coax NEAR
    ; 3C509B-COAX: product 9150h, AUI + BNC connectors.
    mov     [seed_product], PRODUCT_3C509
    mov     [seed_media], 3
    mov     ax, W0_CONFIG_CONTROL_3C509B_DEFAULT
    and     ax, NOT W0_CONFIG_CONTROL_TP_PRESENT
    or      ax, W0_CONFIG_CONTROL_AUI_PRESENT OR W0_CONFIG_CONTROL_BNC_PRESENT
    mov     [seed_config_control], ax
    mov     [byte seed_asic_rev], 2
    ret
ENDP Set_Model_509B_Coax

PROC Set_Model_509B_Combo NEAR
    ; 3C509B-COMBO: product 9450h, TP + AUI + BNC connectors.
    mov     [seed_product], PRODUCT_3C509_COMBO
    mov     [seed_media], 0
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT OR W0_CONFIG_CONTROL_AUI_PRESENT OR W0_CONFIG_CONTROL_BNC_PRESENT
    mov     [byte seed_asic_rev], 2
    ret
ENDP Set_Model_509B_Combo

PROC Set_Model_509B_TPO NEAR
    ; 3C509B-TPO: product 9550h, twisted-pair (media 0).
    mov     [seed_product], PRODUCT_3C509_TPO
    mov     [seed_media], 0
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT
    mov     [byte seed_asic_rev], 2
    ret
ENDP Set_Model_509B_TPO

PROC Set_Model_509B_TPC NEAR
    ; 3C509B-TPC: product 9850h, coax/BNC (media 3).
    mov     [seed_product], PRODUCT_3C509_TPC
    mov     [seed_media], 3
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT OR W0_CONFIG_CONTROL_BNC_PRESENT
    mov     [byte seed_asic_rev], 2
    ret
ENDP Set_Model_509B_TPC

; 3C509-TP: 3C509-TP, ASIC revision 1, TP + AUI connectors.  Product ID
; is the same 9050h family value as 3C509B-TP; the ASIC revision (obtained
; through the normal Window 4 Network Diagnostic register path, not by any
; mock-only shortcut) is what distinguishes the 3C509 generation.  EEPROM
; words 10h/13h/14h/17h receive deterministic non-B-semantics sentinel values
; (see the poison-value comments below) instead of 3C509B capability/Internal
; Configuration/secondary-checksum content.
PROC Set_Model_509_TP NEAR
    mov     [seed_product], PRODUCT_3C509_TP
    mov     [seed_media], 0
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT OR W0_CONFIG_CONTROL_AUI_PRESENT
    mov     [byte seed_asic_rev], 1
    ret
ENDP Set_Model_509_TP

PROC Build_Record_Current NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di
 
    mov     di, [state_record_offset]

    mov     [BYTE state_blob + di + MCK3R_PRESENT], 1
    mov     [BYTE state_blob + di + MCK3R_ID_STATE], MCK_ID_WAIT
    mov     [BYTE state_blob + di + MCK3R_TAG], 0
    mov     [BYTE state_blob + di + MCK3R_FLAGS], MCKRF_ACTIVE
    mov     [BYTE state_blob + di + MCK3R_CURRENT_WINDOW], 0
    mov     al, [seed_rom_size]
    mov     [BYTE state_blob + di + MCK3R_ROM_SIZE], al
    mov     [BYTE state_blob + di + MCK3R_ROM_PAGE], 0
    mov     ax, [seed_base]
    mov     [WORD state_blob + di + MCK3R_ACTIVE_BASE], ax
 
    ; The deterministic diagnostic input supplies the read-only reserved-one
    ; and valid-link-beat bits.  Driver-controlled media bits start clear.
    cmp     [BYTE seed_link_state], 2
    jne     @@LinkUp
    mov     [WORD state_blob + di + MCK3R_W4_MEDIA_INPUT], W4_MEDIA_STATUS_RESERVED_ONE
    jmp     @@LinkDone
@@LinkUp:
    mov     [WORD state_blob + di + MCK3R_W4_MEDIA_INPUT], W4_MEDIA_STATUS_LINK_UP
@@LinkDone:
 
    mov     si, EEPROM_MFG_ID
    mov     ax, EEPROM_MFG_ID_3COM
    call    EEPROM_Write_SI

    mov     si, EEPROM_PRODUCT_ID
    mov     ax, [seed_product]
    call    EEPROM_Write_SI

    mov     si, EEPROM_NODE_0
    mov     ah, [BYTE factory_mac+0]
    mov     al, [BYTE factory_mac+1]
    call    EEPROM_Write_SI

    mov     si, EEPROM_NODE_1
    mov     ah, [BYTE factory_mac+2]
    mov     al, [BYTE factory_mac+3]
    call    EEPROM_Write_SI

    mov     si, EEPROM_NODE_2
    mov     ah, [BYTE factory_mac+4]
    mov     al, [BYTE factory_mac+5]
    call    EEPROM_Write_SI

    mov     si, EEPROM_OEM_NODE_0
    mov     ah, [BYTE oem_mac+0]
    mov     al, [BYTE oem_mac+1]
    call    EEPROM_Write_SI

    mov     si, EEPROM_OEM_NODE_1
    mov     ah, [BYTE oem_mac+2]
    mov     al, [BYTE oem_mac+3]
    call    EEPROM_Write_SI

    mov     si, EEPROM_OEM_NODE_2
    mov     ah, [BYTE oem_mac+4]
    mov     al, [BYTE oem_mac+5]
    call    EEPROM_Write_SI

    mov     ax, [seed_base]
    sub     ax, VALID_IOBASE_MIN
    mov     cl, W0_ADDRESS_CFG_IOBASE_SHIFT
    shr     ax, cl
    and     al, W0_ADDRESS_CFG_IOBASE_MASK
    xor     ah, ah
    mov     bx, ax
    xor     ax, ax
    mov     al, [seed_media]
    and     ax, W0_ADDRESS_CFG_XCVR_VALUE_MASK
    mov     cl, W0_ADDRESS_CFG_XCVR_SHIFT
    shl     ax, cl
    or      ax, bx
    cmp     [byte seed_asic_rev], 1
    jne     @@AddrCfgNoAuto
    ; 3C509 (ASIC rev 1) regression fixture: set Address
    ; Configuration bit 7 while keeping the explicit TP transceiver
    ; selector above, so LIST/CONFIGURE/SAVECONFIG can prove bit 7 is
    ; ignored as a B-only Auto Select field on revision 1.
    or      ax, W0_ADDRESS_CFG_AUTO_SELECT
@@AddrCfgNoAuto:
    mov     si, EEPROM_ADDR_CFG
    call    EEPROM_Write_SI

    xor     ah, ah
    mov     al, [seed_irq]
    mov     cl, W0_RESOURCE_CFG_IRQ_SHIFT
    shl     ax, cl
    and     ax, W0_RESOURCE_CFG_IRQ_MASK
    mov     si, EEPROM_RESOURCE_CFG
    call    EEPROM_Write_SI

    mov     si, EEPROM_SOFTWARE_INFO
    mov     ax, [seed_software_info]
    call    EEPROM_Write_SI
    mov     si, EEPROM_COMPATIBILITY
    mov     ax, 0000h
    call    EEPROM_Write_SI

    cmp     [byte seed_asic_rev], 1
    je      @@Seed509NMD

    ; ASIC revision 2+ (3C509B): normal capability/Internal Configuration/
    ; revision-info EEPROM content, unchanged from the pre-Phase-9 layout.
    mov     si, EEPROM_CAPABILITY
    mov     ax, EEPROM_CAPABILITY_3C509B
    call    EEPROM_Write_SI
    mov     si, EEPROM_CONFIG_CONTROL
    mov     ax, 0000h
    call    EEPROM_Write_SI
    mov     si, EEPROM_REVISION_INFO
    mov     ax, EEPROM_REVISION_3C509B
    call    EEPROM_Write_SI
    jmp     @@ChecksumWord0F

@@Seed509NMD:
    ; ASIC revision 1 (3C509): words 10h/13h/14h are ordinary
    ; Network Management Data, not 3C509B capability/Internal Configuration/
    ; revision-info content.  Deterministic nonzero poison values are seeded so a
    ; regression that mistakenly applies 3C509B semantics to these words is
    ; observable: word 10h bit 0 set would falsely read as PNP capability,
    ; word 13h looks like a plausible PNP/Internal-Configuration state, and
    ; word 14h (00B1h) matches a pattern with a set Boot ROM Size Valid bit.
    mov     si, EEPROM_CAPABILITY
    mov     ax, 0001h
    call    EEPROM_Write_SI
    mov     si, EEPROM_CONFIG_CONTROL
    mov     ax, 8001h
    call    EEPROM_Write_SI
    mov     si, EEPROM_REVISION_INFO
    mov     ax, 00B1h
    call    EEPROM_Write_SI

@@ChecksumWord0F:
    ; Clear EEPROM word 0Fh so its high byte is 00h before Build_Checksum
    ; populates the primary low checksum in the low byte.
    xor     ax, ax
    mov     si, EEPROM_CHECKSUM
    call    EEPROM_Write_SI

    call    Build_Checksum

    cmp     [byte seed_asic_rev], 1
    jne     @@ChecksumDone
    ; 3C509: word 17h is ordinary Network Management Data.  Seed a
    ; recognizable non-checksum sentinel instead of a B secondary checksum,
    ; and do not let Build_Checksum (called above) compute one; see
    ; Build_Checksum's own ASIC-revision gate.
    mov     si, EEPROM_SECONDARY_CHECKSUM
    mov     ax, 0BADh
    call    EEPROM_Write_SI
@@ChecksumDone:
    mov     di, [state_record_offset]
    mov     ax, [seed_product]
    mov     [WORD state_blob + di + MCK3R_W0_PRODUCT], ax
    mov     ax, [seed_config_control]
    mov     [WORD state_blob + di + MCK3R_W0_CONFIG_CONTROL], ax
    mov     si, EEPROM_ADDR_CFG
    call    EEPROM_Read_SI
    mov     [WORD state_blob + di + MCK3R_W0_ADDRESS_CFG], ax
    mov     si, EEPROM_RESOURCE_CFG
    call    EEPROM_Read_SI
    mov     [WORD state_blob + di + MCK3R_W0_RESOURCE_CFG], ax
    mov     al, [byte seed_asic_rev]
    mov     [BYTE state_blob + di + MCK3R_ASIC_REV], al

    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Build_Record_Current

PROC Build_State NEAR
    call    Init_State_Blob
    mov     [byte state_record_count], 1
    mov     [BYTE state_blob + MCK_OFF_RECORD_COUNT], 1
    xor     al, al
    call    Set_Record_Offset_By_Index
    call    Build_Record_Current
    ret
ENDP Build_State

PROC Build_Checksum NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si

    ; Primary low checksum covers only configurable words 08h, 09h, and 0Dh.
    xor     bh, bh
    mov     si, EEPROM_ADDR_CFG
@@PrimaryLow:
    call    EEPROM_Read_SI
    xor     bh, al
    xor     bh, ah
    cmp     si, EEPROM_SOFTWARE_INFO
    je      @@PrimaryLowDone
    cmp     si, EEPROM_ADDR_CFG
    jne     @@PrimaryLowSoftware
    inc     si
    jmp     @@PrimaryLow
@@PrimaryLowSoftware:
    mov     si, EEPROM_SOFTWARE_INFO
@@PrimaryLowDone:
    mov     si, EEPROM_CHECKSUM
    call    EEPROM_Read_SI
    mov     al, bh
    call    EEPROM_Write_SI

    ; Secondary high/low checksum: conceptually ASIC rev 1 builds only the
    ; primary checksum above and preserves word 17h as Network Management
    ; Data (poisoned by Build_Record_Current); only known B-generation
    ; fixtures (ASIC rev 2+) get the existing secondary checksum below.
    cmp     [byte seed_asic_rev], 1
    je      @@SecondarySkip

    ; Secondary high checksum: words 10h-12h and 20h-3Fh.
    xor     bx, bx
    mov     si, EEPROM_SECONDARY_VITAL_START
@@SecondaryHighA:
    call    EEPROM_Read_SI
    xor     bl, al
    xor     bl, ah
    inc     si
    cmp     si, EEPROM_SECONDARY_VITAL_END
    jb      @@SecondaryHighA
    mov     si, EEPROM_SECONDARY_VITAL_PNP_START
@@SecondaryHighB:
    call    EEPROM_Read_SI
    xor     bl, al
    xor     bl, ah
    inc     si
    cmp     si, EEPROM_SECONDARY_VITAL_PNP_END
    jb      @@SecondaryHighB

    xor     bh, bh
    mov     si, EEPROM_SECONDARY_CONFIG_START
@@SecondaryLow:
    call    EEPROM_Read_SI
    xor     bh, al
    xor     bh, ah
    inc     si
    cmp     si, EEPROM_SECONDARY_CONFIG_END
    jb      @@SecondaryLow
    mov     si, EEPROM_SECONDARY_CHECKSUM
    mov     ax, bx
    xchg    al, ah
    call    EEPROM_Write_SI

@@SecondarySkip:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Build_Checksum

PROC EEPROM_Write_SI NEAR
    ; Input SI = EEPROM word index, AX = value to write.
    push    bx
    push    di
    mov     di, [state_record_offset]
    mov     bx, si
    and     bx, 003Fh
    shl     bx, 1
    mov     [WORD state_blob + di + MCK3R_EEPROM + bx], ax
    pop     di
    pop     bx
    ret
ENDP EEPROM_Write_SI

PROC EEPROM_Read_SI NEAR
    ; Input SI = EEPROM word index, output AX = value.
    push    bx
    push    di
    mov     di, [state_record_offset]
    mov     bx, si
    and     bx, 003Fh
    shl     bx, 1
    mov     ax, [WORD state_blob + di + MCK3R_EEPROM + bx]
    pop     di
    pop     bx
    ret
ENDP EEPROM_Read_SI

PROC Write_State_File NEAR
    push    ax
    push    bx
    push    cx
    push    dx
 
    mov     [BYTE state_blob + MCK_OFF_MAGIC0], MCK_MAGIC_0
    mov     [BYTE state_blob + MCK_OFF_MAGIC1], MCK_MAGIC_1
    mov     [BYTE state_blob + MCK_OFF_MAGIC2], MCK_MAGIC_2
    mov     [BYTE state_blob + MCK_OFF_MAGIC3], MCK_MAGIC_3
    mov     [WORD state_blob + MCK_OFF_VERSION], MCK_VERSION
    mov     al, [byte state_record_count]
    mov     [BYTE state_blob + MCK_OFF_RECORD_COUNT], al

    mov     ah, 3Ch
    xor     cx, cx
    mov     dx, OFFSET MOCK_STATE_FILE
    int     21h
    jc      @@Fail
    mov     bx, ax

    mov     ah, 40h
    mov     cx, MCK_FILE_SIZE
    mov     dx, OFFSET state_blob
    int     21h
    jc      @@CloseFail
    cmp     ax, MCK_FILE_SIZE
    jne     @@CloseFail

    mov     ah, 3Eh
    int     21h

    pop     dx
    pop     cx
    pop     bx
    pop     ax
    clc
    ret

@@CloseFail:
    mov     ah, 3Eh
    int     21h
@@Fail:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    stc
    ret
ENDP Write_State_File

END Start
