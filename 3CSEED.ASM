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
             DB '  INIT         Create deterministic one-card seed (3C509B-TP profile).', 0Dh, 0Ah
             DB '  RANDOM       Create randomized one-card seed state.', 0Dh, 0Ah
             DB '  ADD model [io] [irq]  Append one card; defaults pick next free I/O.', 0Dh, 0Ah
             DB '  CLEAR        Delete 3C509B.MCK.', 0Dh, 0Ah
             DB '  3C509B-TP    Seed as 3C509B-TP  (product 9050h, twisted-pair).', 0Dh, 0Ah
             DB '  3C509B-COMBO Seed as 3C509B      (product 9150h, combo/AUI).', 0Dh, 0Ah
             DB '  3C509B-C     Seed as 3C509B-C    (product 9450h, twisted-pair).', 0Dh, 0Ah
             DB '  3C509B-TPO   Seed as 3C509B-TPO  (product 9550h, twisted-pair).', 0Dh, 0Ah
             DB '  3C509B-TPC   Seed as 3C509B-TPC  (product 9850h, coax).', 0Dh, 0Ah
             DB '  NOPNP        Seed as non-PNP-capable card (gate test).', 0Dh, 0Ah
             DB '  PNPREV0      Seed as PNP-capable card with revision level 0.', 0Dh, 0Ah
             DB '  NOFD         Seed as B-class card without TP capability.', 0Dh, 0Ah
             DB '  TPAUI        Seed TP product with live TP+AUI capabilities.', 0Dh, 0Ah
             DB '  TRI          Seed TP product with live TP+AUI+BNC capabilities.', 0Dh, 0Ah
             DB '  MODEMFIELDS  Seed non-MODEM word 0Dh fields for preservation tests.', 0Dh, 0Ah
             DB '  NOLINKBEAT   INIT profile with EEPROM Link Beat Disable set.', 0Dh, 0Ah
             DB '  LINKUP       INIT profile with live Link Status forced connected.', 0Dh, 0Ah
             DB '  LINKDOWN     INIT profile with live Link Status forced not connected.', 0Dh, 0Ah
             DB '$'
msg_ok_init  DB 'Seed file created (INIT).', 0Dh, 0Ah, '$'
msg_ok_rand  DB 'Seed file created (RANDOM).', 0Dh, 0Ah, '$'
msg_ok_clear DB 'Seed file deleted (or already absent).', 0Dh, 0Ah, '$'
msg_ok_tp    DB 'Seed file created (3C509B-TP).', 0Dh, 0Ah, '$'
msg_ok_combo DB 'Seed file created (3C509B-COMBO).', 0Dh, 0Ah, '$'
msg_ok_c     DB 'Seed file created (3C509B-C).', 0Dh, 0Ah, '$'
msg_ok_tpo   DB 'Seed file created (3C509B-TPO).', 0Dh, 0Ah, '$'
msg_ok_tpc   DB 'Seed file created (3C509B-TPC).', 0Dh, 0Ah, '$'
msg_ok_nopnp DB 'Seed file created (NOPNP).', 0Dh, 0Ah, '$'
msg_ok_pnprev0 DB 'Seed file created (PNPREV0).', 0Dh, 0Ah, '$'
msg_ok_nofd  DB 'Seed file created (NOFD).', 0Dh, 0Ah, '$'
msg_ok_tpaui DB 'Seed file created (TPAUI).', 0Dh, 0Ah, '$'
msg_ok_tri   DB 'Seed file created (TRI).', 0Dh, 0Ah, '$'
msg_ok_modemfields DB 'Seed file created (MODEMFIELDS).', 0Dh, 0Ah, '$'
msg_ok_nolinkbeat DB 'Seed file created (NOLINKBEAT).', 0Dh, 0Ah, '$'
msg_ok_linkup   DB 'Seed file created (LINKUP).', 0Dh, 0Ah, '$'
msg_ok_linkdown DB 'Seed file created (LINKDOWN).', 0Dh, 0Ah, '$'
msg_ok_add   DB 'Seed file updated (ADD).', 0Dh, 0Ah, '$'
msg_fail_io  DB 'File I/O error.', 0Dh, 0Ah, '$'
msg_bad_arg  DB 'Invalid command argument.', 0Dh, 0Ah, '$'
msg_add_too_many DB 'Too many mock NIC records.', 0Dh, 0Ah, '$'
msg_no_free_iobase DB 'No free default IOBASE remains.', 0Dh, 0Ah, '$'
msg_bad_iobase DB 'Invalid IOBASE argument.', 0Dh, 0Ah, '$'
msg_bad_irq  DB 'Invalid IRQ argument.', 0Dh, 0Ah, '$'

kw_init      DB 'INIT', 0
kw_random    DB 'RANDOM', 0
kw_add       DB 'ADD', 0
kw_clear     DB 'CLEAR', 0
kw_tp        DB '3C509B-TP', 0
kw_combo     DB '3C509B-COMBO', 0
kw_c         DB '3C509B-C', 0
kw_tpo       DB '3C509B-TPO', 0
kw_tpc       DB '3C509B-TPC', 0
kw_nopnp     DB 'NOPNP', 0
kw_pnprev0   DB 'PNPREV0', 0
kw_nofd      DB 'NOFD', 0
kw_tpaui     DB 'TPAUI', 0
kw_tri       DB 'TRI', 0
kw_modemfields DB 'MODEMFIELDS', 0
kw_nolinkbeat DB 'NOLINKBEAT', 0
kw_linkup    DB 'LINKUP', 0
kw_linkdown  DB 'LINKDOWN', 0

cmd_buffer   DB 128 DUP (0)
state_blob   DB MCK_FILE_SIZE DUP (0)
state_record_offset DW MCK_HEADER_SIZE
state_record_count DB 0

seed_product DW PRODUCT_3C509_TP
seed_base    DW 0300h
seed_irq     DB 10
seed_asic    DB 4
seed_media   DB 0
seed_config_control DW W0_CONFIG_CONTROL_3C509B_DEFAULT

factory_mac  DB 6 DUP (0)
oem_mac      DB 6 DUP (0)

rand_seed    DW 0A5A5h

product_table DW PRODUCT_3C509
             DW PRODUCT_3C509_TP
             DW PRODUCT_3C509_COMBO
             DW PRODUCT_3C509_TPO
             DW PRODUCT_3C509_TPC

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
    mov     dx, OFFSET kw_random
    call    Match_Token
    jnc     @@DoRandom
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
    mov     dx, OFFSET kw_c
    call    Match_Token
    jnc     @@DoC
    mov     dx, OFFSET kw_tpo
    call    Match_Token
    jnc     @@DoTPO
    mov     dx, OFFSET kw_tpc
    call    Match_Token
    jnc     @@DoTPC
    mov     dx, OFFSET kw_nopnp
    call    Match_Token
    jnc     @@DoNoPNP
    mov     dx, OFFSET kw_pnprev0
    call    Match_Token
    jnc     @@DoPNPRev0
    mov     dx, OFFSET kw_nofd
    call    Match_Token
    jnc     @@DoNoFD
    mov     dx, OFFSET kw_tpaui
    call    Match_Token
    jnc     @@DoTpAui
    mov     dx, OFFSET kw_tri
    call    Match_Token
    jnc     @@DoTri
    mov     dx, OFFSET kw_modemfields
    call    Match_Token
    jnc     @@DoModemFields
    mov     dx, OFFSET kw_nolinkbeat
    call    Match_Token
    jnc     @@DoNoLinkBeat
    mov     dx, OFFSET kw_linkup
    call    Match_Token
    jnc     @@DoLinkUp
    mov     dx, OFFSET kw_linkdown
    call    Match_Token
    jnc     @@DoLinkDown

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
    call    Seed_Init
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_init
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoRandom:
    call    Seed_Random
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_rand
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
    call    Seed_Model_TP
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_tp
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoCombo:
    call    Seed_Model_Combo
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_combo
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoC:
    call    Seed_Model_C
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_c
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoTPO:
    call    Seed_Model_TPO
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_tpo
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoTPC:
    call    Seed_Model_TPC
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_tpc
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoNoPNP:
    call    Seed_NoPNP
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_nopnp
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoPNPRev0:
    call    Seed_PNPRev0
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_pnprev0
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoNoFD:
    call    Seed_NoFD
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_nofd
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoTpAui:
    call    Seed_TpAui
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_tpaui
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoTri:
    call    Seed_Tri
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_tri
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoModemFields:
    call    Seed_ModemFields
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_modemfields
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoNoLinkBeat:
    call    Seed_NoLinkBeat
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_nolinkbeat
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoLinkUp:
    call    Seed_LinkUp
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_linkup
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@DoLinkDown:
    call    Seed_LinkDown
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_linkdown
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

PROC Parse_Model_Token NEAR
    push    dx

    mov     dx, OFFSET kw_tp
    call    Match_Token
    jnc     @@TP
    mov     dx, OFFSET kw_combo
    call    Match_Token
    jnc     @@Combo
    mov     dx, OFFSET kw_c
    call    Match_Token
    jnc     @@C
    mov     dx, OFFSET kw_tpo
    call    Match_Token
    jnc     @@TPO
    mov     dx, OFFSET kw_tpc
    call    Match_Token
    jnc     @@TPC
    pop     dx
    stc
    ret

@@TP:
    mov     [seed_product], PRODUCT_3C509_TP
    mov     [seed_media], 0
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT
    call    Consume_Token
    pop     dx
    clc
    ret
@@Combo:
    mov     [seed_product], PRODUCT_3C509
    mov     [seed_media], 1
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT OR W0_CONFIG_CONTROL_AUI_PRESENT
    call    Consume_Token
    pop     dx
    clc
    ret
@@C:
    mov     [seed_product], PRODUCT_3C509_COMBO
    mov     [seed_media], 0
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT
    call    Consume_Token
    pop     dx
    clc
    ret
@@TPO:
    mov     [seed_product], PRODUCT_3C509_TPO
    mov     [seed_media], 0
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT
    call    Consume_Token
    pop     dx
    clc
    ret
@@TPC:
    mov     [seed_product], PRODUCT_3C509_TPC
    mov     [seed_media], 3
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT OR W0_CONFIG_CONTROL_BNC_PRESENT
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
    je      @@VersionOk
    cmp     ax, MCK_VERSION_V1
    jne     @@Reset
@@VersionOk:
    mov     al, [BYTE state_blob + MCK_OFF_RECORD_COUNT]
    cmp     [WORD state_blob + MCK_OFF_VERSION], MCK_VERSION_V1
    jne     @@Clamp
    or      al, al
    jne     @@Clamp
    mov     al, 1
@@Clamp:
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

; Deterministic baseline seed.  seed_product/seed_media are intentionally NOT
; set here: the DATASEG defaults (PRODUCT_3C509_TP / media 0) apply for a bare
; INIT call, while Seed_Model_TP/Combo/C/TPO/TPC set seed_product/seed_media
; to their SKU-specific values BEFORE calling this proc and rely on them being
; preserved.  NOPNP/NOFD also call this directly and expect the TP defaults.
PROC Seed_Init NEAR
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
ENDP Seed_Init

PROC Seed_Random NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si

    call    Seed_From_Time

    mov     cx, 5
    call    Rand_Mod
    shl     ax, 1
    mov     si, ax
    mov     ax, [WORD product_table + si]
    mov     [seed_product], ax

    mov     cx, 31
    call    Rand_Mod
    shl     ax, 1
    mov     si, ax
    mov     ax, [WORD iobase_table + si]
    mov     [seed_base], ax

    mov     cx, 8
    call    Rand_Mod
    mov     si, ax
    mov     al, [BYTE irq_table + si]
    mov     [seed_irq], al

    mov     cx, 5
    call    Rand_Mod
    add     al, 2
    mov     [seed_asic], al

    mov     cx, 3
    call    Rand_Mod
    cmp     al, 0
    je      @@MediaDone
    cmp     al, 1
    je      @@MediaExternal
    mov     al, 3
    jmp     @@MediaDone
@@MediaExternal:
    mov     al, 1
@@MediaDone:
    mov     [seed_media], al

    mov     cx, 6
    mov     si, OFFSET factory_mac
@@Mac0:
    call    Rand16
    mov     [BYTE si], al
    inc     si
    loop    @@Mac0

    mov     cx, 6
    mov     si, OFFSET oem_mac
@@Mac1:
    call    Rand16
    mov     [BYTE si], al
    inc     si
    loop    @@Mac1

    mov     al, [BYTE factory_mac+0]
    and     al, 0FEh
    or      al, 02h
    mov     [BYTE factory_mac+0], al

    mov     al, [BYTE oem_mac+0]
    and     al, 0FEh
    or      al, 02h
    mov     [BYTE oem_mac+0], al

    call    Build_State
    call    Write_State_File

    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Seed_Random

PROC Seed_Add NEAR
    push    ax
    push    dx
    push    si

    mov     [seed_asic], 4
    mov     [seed_irq], 10

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
    call    Parse_IOBase_Token
    jnc     @@MaybeIRQ
    mov     dx, OFFSET msg_bad_iobase
    mov     ah, 09h
    int     21h
    stc
    jmp     @@Done

@@PickDefaultBase:
    call    Choose_Default_Base
    jnc     @@MaybeIRQ
    mov     dx, OFFSET msg_no_free_iobase
    mov     ah, 09h
    int     21h
    stc
    jmp     @@Done

@@MaybeIRQ:
    call    Skip_Spaces
    mov     al, [BYTE si]
    or      al, al
    jz      @@Append
    call    Parse_IRQ_Token
    jnc     @@CheckEnd
    mov     dx, OFFSET msg_bad_irq
    mov     ah, 09h
    int     21h
    stc
    jmp     @@Done

@@CheckEnd:
    call    Skip_Spaces
    cmp     [BYTE si], 0
    je      @@Append
    mov     dx, OFFSET msg_bad_arg
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
; Model-specific seed helpers.
; Each sets seed_product and seed_media to the correct defaults for that SKU,
; then delegates to Seed_Init which sets the shared fixed MAC/IRQ/base and
; calls Build_State + Write_State_File.
; ---------------------------------------------------------------------------

PROC Seed_Model_TP NEAR
    ; 3C509B-TP: product 9050h, twisted-pair (media 0).
    mov     [seed_product], PRODUCT_3C509_TP
    mov     [seed_media], 0
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT
    call    Seed_Init
    ret
ENDP Seed_Model_TP

PROC Seed_Model_Combo NEAR
    ; 3C509B (Combo): product 9150h, AUI/external (media 1).
    mov     [seed_product], PRODUCT_3C509
    mov     [seed_media], 1
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT OR W0_CONFIG_CONTROL_AUI_PRESENT
    call    Seed_Init
    ret
ENDP Seed_Model_Combo

PROC Seed_Model_C NEAR
    ; 3C509B-C: product 9450h, twisted-pair (media 0).
    mov     [seed_product], PRODUCT_3C509_COMBO
    mov     [seed_media], 0
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT
    call    Seed_Init
    ret
ENDP Seed_Model_C

PROC Seed_Model_TPO NEAR
    ; 3C509B-TPO: product 9550h, twisted-pair (media 0).
    mov     [seed_product], PRODUCT_3C509_TPO
    mov     [seed_media], 0
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT
    call    Seed_Init
    ret
ENDP Seed_Model_TPO

PROC Seed_Model_TPC NEAR
    ; 3C509B-TPC: product 9850h, coax/BNC (media 3).
    mov     [seed_product], PRODUCT_3C509_TPC
    mov     [seed_media], 3
    mov     [seed_config_control], W0_CONFIG_CONTROL_3C509B_DEFAULT OR W0_CONFIG_CONTROL_BNC_PRESENT
    call    Seed_Init
    ret
ENDP Seed_Model_TPC

PROC Seed_NoPNP NEAR
    ; INIT profile with the authoritative EEPROM_CAPABILITY PNP bit clear.
    call    Seed_Init
    jc      @@Fail
    mov     si, EEPROM_CAPABILITY
    mov     ax, EEPROM_CAPABILITY_3C509B
    and     ax, NOT EEPROM_CAPABILITY_PNP
    call    EEPROM_Write_SI
    call    Build_Checksum
    call    Write_State_File
    ret
@@Fail:
    stc
    ret
ENDP Seed_NoPNP

; PNP capability is independent of the revision-level classification.
PROC Seed_PNPRev0 NEAR
    call    Seed_Init
    jc      @@Fail
    mov     si, EEPROM_REVISION_INFO
    xor     ax, ax
    call    EEPROM_Write_SI
    call    Build_Checksum
    call    Write_State_File
    ret
@@Fail:
    stc
    ret
ENDP Seed_PNPRev0

PROC Seed_NoFD NEAR
    ; Keep PNP and B-class revision valid, but remove the live TP capability.
    call    Seed_Init
    jc      @@Fail
    mov     ax, W0_CONFIG_CONTROL_3C509B_DEFAULT
    and     ax, NOT W0_CONFIG_CONTROL_TP_PRESENT
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCK3R_W0_CONFIG_CONTROL], ax
    call    Write_State_File
    ret
@@Fail:
    stc
    ret
ENDP Seed_NoFD

; Product ID remains 3C509B-TP while live connector bits report TP+AUI.
PROC Seed_TpAui NEAR
    call    Seed_Init
    jc      @@Fail
    mov     ax, W0_CONFIG_CONTROL_3C509B_DEFAULT OR W0_CONFIG_CONTROL_AUI_PRESENT
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCK3R_W0_CONFIG_CONTROL], ax
    call    Write_State_File
    ret
@@Fail:
    stc
    ret
ENDP Seed_TpAui

; Product ID remains 3C509B-TP while live connector bits report all three.
PROC Seed_Tri NEAR
    call    Seed_Init
    jc      @@Fail
    mov     ax, W0_CONFIG_CONTROL_3C509B_DEFAULT OR W0_CONFIG_CONTROL_AUI_PRESENT OR W0_CONFIG_CONTROL_BNC_PRESENT
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCK3R_W0_CONFIG_CONTROL], ax
    call    Write_State_File
    ret
@@Fail:
    stc
    ret
ENDP Seed_Tri

; Set every non-MODEM word 0Dh field while retaining a named MODEM encoding.
PROC Seed_ModemFields NEAR
    call    Seed_Init
    jc      @@Fail
    mov     si, EEPROM_SOFTWARE_INFO
    mov     ax, EEPROM_MODEM_1200
    or      ax, EEPROM_SOFTWARE_INFO_LINKBEAT_DISABLE
    or      ax, EEPROM_SOFTWARE_INFO_RESERVED_MASK
    or      ax, EEPROM_SOFTWARE_INFO_OPTIMIZE_MASK
    or      ax, EEPROM_SOFTWARE_INFO_BOOT_PROTOCOL_MASK
    call    EEPROM_Write_SI
    call    Build_Checksum
    call    Write_State_File
    ret
@@Fail:
    stc
    ret
ENDP Seed_ModemFields

PROC Seed_NoLinkBeat NEAR
    ; INIT profile, then set the persistent Link Beat Disable policy in
    ; EEPROM_SOFTWARE_INFO word 0Dh bit 14.
    call    Seed_Init
    jc      @@Fail
    mov     si, EEPROM_SOFTWARE_INFO
    mov     ax, EEPROM_SOFTWARE_INFO_LINKBEAT_DISABLE OR EEPROM_SOFTWARE_INFO_OPTIMIZE_DOS
    call    EEPROM_Write_SI
    call    Build_Checksum
    call    Write_State_File
    ret
@@Fail:
    stc
    ret
ENDP Seed_NoLinkBeat

PROC Seed_LinkUp NEAR
    ; INIT profile with the live link status explicitly forced to
    ; connected (Media Type and Status register, Window 4/Port 0Ah,
    ; bit 11 set).  This is already the INIT/RANDOM default; the explicit
    ; seed exists for test clarity and as the counterpart to LINKDOWN.
    call    Seed_Init
    jc      @@Fail
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCK3R_W4_MEDIA_INPUT], W4_MEDIA_STATUS_LINK_UP
    call    Write_State_File
    ret
@@Fail:
    stc
    ret
ENDP Seed_LinkUp

PROC Seed_LinkDown NEAR
    ; INIT profile with bit 11 of the live Media Type and Status register
    ; mirror cleared, so LIST reports "not connected".
    call    Seed_Init
    jc      @@Fail
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCK3R_W4_MEDIA_INPUT], W4_MEDIA_STATUS_RESERVED_ONE
    call    Write_State_File
    ret
@@Fail:
    stc
    ret
ENDP Seed_LinkDown

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
    mov     ax, [seed_base]
    mov     [WORD state_blob + di + MCK3R_ACTIVE_BASE], ax
 
    ; The deterministic diagnostic input supplies the read-only reserved-one
    ; and valid-link-beat bits.  Driver-controlled media bits start clear.
    mov     [WORD state_blob + di + MCK3R_W4_MEDIA_INPUT], W4_MEDIA_STATUS_LINK_UP
 
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
    mov     ax, EEPROM_SOFTWARE_INFO_OPTIMIZE_DOS
    call    EEPROM_Write_SI
    mov     si, EEPROM_COMPATIBILITY
    mov     ax, 0000h
    call    EEPROM_Write_SI
    mov     si, EEPROM_CAPABILITY
    mov     ax, EEPROM_CAPABILITY_3C509B
    call    EEPROM_Write_SI
    mov     si, EEPROM_CONFIG_CONTROL
    mov     ax, 0000h
    call    EEPROM_Write_SI
    mov     si, EEPROM_REVISION_INFO
    mov     ax, EEPROM_REVISION_3C509B
    call    EEPROM_Write_SI

    ; Legacy fixture initialization retained until the deferred OPTIMIZE and
    ; checksum alignment pass.  Word 0Fh is not the documented optimization
    ; field; the checksum pass below owns its bytes.
    xor     ax, ax
    mov     si, EEPROM_CHECKSUM
    call    EEPROM_Write_SI
 
    call    Build_Checksum
 
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

    ; Legacy fixture checksum behavior is retained pending the deferred
    ; checksum-alignment pass.  EEPROM word 0Fh is not an optimization field.
    xor     bx, bx
    xor     si, si
@@PrimaryHigh:
    cmp     si, EEPROM_CHECKSUM
    jae     @@PrimaryLowStart
    cmp     si, EEPROM_ADDR_CFG
    je      @@PrimaryHighNext
    cmp     si, EEPROM_RESOURCE_CFG
    je      @@PrimaryHighNext
    cmp     si, EEPROM_SOFTWARE_INFO
    je      @@PrimaryHighNext
    call    EEPROM_Read_SI
    xor     bl, al
    xor     bl, ah
@@PrimaryHighNext:
    inc     si
    jmp     @@PrimaryHigh

@@PrimaryLowStart:
    xor     bh, bh
    mov     si, EEPROM_ADDR_CFG
@@PrimaryLow:
    call    EEPROM_Read_SI
    xor     bh, al
    xor     bh, ah
    inc     si
    cmp     si, EEPROM_SOFTWARE_INFO
    jbe     @@PrimaryLow
    mov     si, EEPROM_CHECKSUM
    call    EEPROM_Read_SI
    mov     al, bh
    call    EEPROM_Write_SI

    ; Secondary high checksum: words 10h-12h and 20h-3Fh.
    xor     bx, bx
    mov     si, EEPROM_CAPABILITY
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

PROC Seed_From_Time NEAR
    push    ax
    push    cx
    push    dx

    mov     ah, 2Ch
    int     21h
    mov     al, dl
    xor     ah, ah
    add     ax, dx
    add     ax, cx
    add     ax, [rand_seed]
    mov     [rand_seed], ax

    pop     dx
    pop     cx
    pop     ax
    ret
ENDP Seed_From_Time

PROC Rand16 NEAR
    push    bx
    mov     ax, [rand_seed]
    mov     bx, 25173
    mul     bx
    add     ax, 13849
    mov     [rand_seed], ax
    pop     bx
    ret
ENDP Rand16

PROC Rand_Mod NEAR
    ; Input CX = modulus. Output AX = random 0..CX-1.
    push    dx
    call    Rand16
    xor     dx, dx
    div     cx
    mov     ax, dx
    pop     dx
    ret
ENDP Rand_Mod

END Start
