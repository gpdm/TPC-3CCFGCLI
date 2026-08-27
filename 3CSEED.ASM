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
             DB '  CLEAR        Delete 3C509B.MCK.', 0Dh, 0Ah
             DB '  3C509B-TP    Seed as 3C509B-TP  (product 9050h, twisted-pair).', 0Dh, 0Ah
             DB '  3C509B-COMBO Seed as 3C509B      (product 9150h, combo/AUI).', 0Dh, 0Ah
             DB '  3C509B-C     Seed as 3C509B-C    (product 9450h, twisted-pair).', 0Dh, 0Ah
             DB '  3C509B-TPO   Seed as 3C509B-TPO  (product 9550h, twisted-pair).', 0Dh, 0Ah
             DB '  3C509B-TPC   Seed as 3C509B-TPC  (product 9850h, coax).', 0Dh, 0Ah
             DB '  NOPNP        Seed as non-PNP-capable card (gate test).', 0Dh, 0Ah
             DB '  NOFD         Seed as non-FULLDUPLEX-capable card (gate test).', 0Dh, 0Ah
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
msg_ok_nofd  DB 'Seed file created (NOFD).', 0Dh, 0Ah, '$'
msg_ok_linkup   DB 'Seed file created (LINKUP).', 0Dh, 0Ah, '$'
msg_ok_linkdown DB 'Seed file created (LINKDOWN).', 0Dh, 0Ah, '$'
msg_fail_io  DB 'File I/O error.', 0Dh, 0Ah, '$'
msg_bad_arg  DB 'Invalid command argument.', 0Dh, 0Ah, '$'

kw_init      DB 'INIT', 0
kw_random    DB 'RANDOM', 0
kw_clear     DB 'CLEAR', 0
kw_tp        DB '3C509B-TP', 0
kw_combo     DB '3C509B-COMBO', 0
kw_c         DB '3C509B-C', 0
kw_tpo       DB '3C509B-TPO', 0
kw_tpc       DB '3C509B-TPC', 0
kw_nopnp     DB 'NOPNP', 0
kw_nofd      DB 'NOFD', 0
kw_linkup    DB 'LINKUP', 0
kw_linkdown  DB 'LINKDOWN', 0

cmd_buffer   DB 128 DUP (0)
state_blob   DB MCK_FILE_SIZE DUP (0)

seed_product DW PRODUCT_3C509_TP
seed_base    DW 0300h
seed_irq     DB 10
seed_asic    DB 4
seed_media   DB 0

factory_mac  DB 6 DUP (0)
oem_mac      DB 6 DUP (0)

chk_high     DB 0
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
    mov     dx, OFFSET kw_nofd
    call    Match_Token
    jnc     @@DoNoFD
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

@@DoNoFD:
    call    Seed_NoFD
    jc      @@IoFail
    mov     dx, OFFSET msg_ok_nofd
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
    call    Seed_Init
    ret
ENDP Seed_Model_TP

PROC Seed_Model_Combo NEAR
    ; 3C509B (Combo): product 9150h, AUI/external (media 1).
    mov     [seed_product], PRODUCT_3C509
    mov     [seed_media], 1
    call    Seed_Init
    ret
ENDP Seed_Model_Combo

PROC Seed_Model_C NEAR
    ; 3C509B-C: product 9450h, twisted-pair (media 0).
    mov     [seed_product], PRODUCT_3C509_COMBO
    mov     [seed_media], 0
    call    Seed_Init
    ret
ENDP Seed_Model_C

PROC Seed_Model_TPO NEAR
    ; 3C509B-TPO: product 9550h, twisted-pair (media 0).
    mov     [seed_product], PRODUCT_3C509_TPO
    mov     [seed_media], 0
    call    Seed_Init
    ret
ENDP Seed_Model_TPO

PROC Seed_Model_TPC NEAR
    ; 3C509B-TPC: product 9850h, coax/BNC (media 3).
    mov     [seed_product], PRODUCT_3C509_TPC
    mov     [seed_media], 3
    call    Seed_Init
    ret
ENDP Seed_Model_TPC

PROC Seed_NoPNP NEAR
    ; INIT profile, then patch EEPROM_REVISION_INFO to 0000h so the PNP
    ; capability gate (low byte >= 1) fails.
    call    Seed_Init
    jc      @@Fail
    mov     si, EEPROM_REVISION_INFO
    mov     ax, 0000h
    call    EEPROM_Write_SI
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_PNP], 0
    call    Build_Checksum
    call    Write_State_File
    ret
@@Fail:
    stc
    ret
ENDP Seed_NoPNP

PROC Seed_NoFD NEAR
    ; INIT profile, then clear EEPROM_CAPABILITY bit 0.
    ; The EEPROM capability gate is sufficient to block FULLDUPLEX.
    ; Product ID is left as a valid SKU so the card is enumerated normally.
    call    Seed_Init
    jc      @@Fail
    mov     si, EEPROM_CAPABILITY
    mov     ax, 0000h
    call    EEPROM_Write_SI
    call    Build_Checksum
    call    Write_State_File
    ret
@@Fail:
    stc
    ret
ENDP Seed_NoFD

PROC Seed_LinkUp NEAR
    ; INIT profile with the live link status explicitly forced to
    ; connected (Media Type and Status register, Window 4/Port 0Ah,
    ; bit 11 set).  This is already the INIT/RANDOM default; the explicit
    ; seed exists for test clarity and as the counterpart to LINKDOWN.
    call    Seed_Init
    jc      @@Fail
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_LIVE_W4_MEDIA_STATUS], 0800h
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
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_LIVE_W4_MEDIA_STATUS], 0000h
    call    Write_State_File
    ret
@@Fail:
    stc
    ret
ENDP Seed_LinkDown

PROC Build_State NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    mov     di, OFFSET state_blob
    mov     cx, MCK_FILE_SIZE
    xor     al, al
    rep     stosb

    mov     [BYTE state_blob + MCK_OFF_MAGIC0], MCK_MAGIC_0
    mov     [BYTE state_blob + MCK_OFF_MAGIC1], MCK_MAGIC_1
    mov     [BYTE state_blob + MCK_OFF_MAGIC2], MCK_MAGIC_2
    mov     [BYTE state_blob + MCK_OFF_MAGIC3], MCK_MAGIC_3
    mov     [WORD state_blob + MCK_OFF_VERSION], MCK_VERSION
    mov     [BYTE state_blob + MCK_OFF_RECORD_COUNT], 1

    mov     [BYTE state_blob + MCK_HEADER_SIZE + MCKR_PRESENT], 1
    mov     [BYTE state_blob + MCK_HEADER_SIZE + MCKR_ACTIVE], 1
    mov     [BYTE state_blob + MCK_HEADER_SIZE + MCKR_TAG], 1
    mov     [BYTE state_blob + MCK_HEADER_SIZE + MCKR_ID_MODE], 1
    mov     [BYTE state_blob + MCK_HEADER_SIZE + MCKR_CURRENT_WINDOW], 0
    mov     al, [seed_asic]
    mov     [BYTE state_blob + MCK_HEADER_SIZE + MCKR_ASIC_REV], al
    mov     al, [seed_irq]
    mov     [BYTE state_blob + MCK_HEADER_SIZE + MCKR_IRQ], al
    mov     ax, [seed_base]
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_ACTIVE_BASE], ax
    mov     ax, [seed_product]
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_PRODUCT_ID], ax

    mov     ax, MCK_CFGF_ALL
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_FLAGS], ax

    xor     ah, ah
    mov     al, [seed_irq]
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_INT], ax
    mov     ax, [seed_base]
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_IOBASE], ax
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_PORT], ax
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_BADDRESS], 0
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_BSIZE], 0

    xor     ah, ah
    mov     al, [seed_media]
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_TR], ax
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_XCVR], ax
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_MODEM], 0
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_OPTIMIZE], 0
    ; MCKR_CFG_LINKBEAT is an inert placeholder (see 3C509DEF.INC); it is
    ; never derived from anything configurable, so it is left at zero.
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_LINKBEAT], 0
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_PNP], 1
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_FULLDUPLEX], 0

    ; Live link status default: a freshly seeded card is assumed to be
    ; connected (Media Type and Status register bit 11 set), consistent
    ; with the "nominal by default" convention used elsewhere (e.g. PNP,
    ; FULLDUPLEX capability).  Use SEED LINKDOWN for the negative case.
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_LIVE_W4_MEDIA_STATUS], 0800h

    mov     si, EEPROM_MFG_ID
    mov     ax, 06D50h
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
    mov     cl, 4
    shr     ax, cl
    and     al, 01Fh
    xor     ah, ah
    mov     bx, ax
    xor     ax, ax
    mov     al, [seed_media]
    and     ax, 0003h
    mov     cl, 14
    shl     ax, cl
    or      ax, bx
    mov     si, EEPROM_ADDR_CFG
    call    EEPROM_Write_SI

    xor     ah, ah
    mov     al, [seed_irq]
    mov     cl, 12
    shl     ax, cl
    mov     si, EEPROM_RESOURCE_CFG
    call    EEPROM_Write_SI

    mov     si, EEPROM_SOFTWARE_INFO
    mov     ax, 0000h
    call    EEPROM_Write_SI
    mov     si, EEPROM_COMPATIBILITY
    mov     ax, 0000h
    call    EEPROM_Write_SI
    mov     si, EEPROM_CAPABILITY
    mov     ax, 0001h
    call    EEPROM_Write_SI
    mov     si, EEPROM_CONFIG_CONTROL
    mov     ax, 0000h
    call    EEPROM_Write_SI
    mov     si, EEPROM_REVISION_INFO
    mov     ax, 0001h
    call    EEPROM_Write_SI

    ; Preserve the documented default optimization mode (DOS) in the high byte
    ; of EEPROM word 0Fh before the checksum pass fills in the low byte.
    mov     ah, [BYTE state_blob + MCK_HEADER_SIZE + MCKR_CFG_OPTIMIZE]
    xor     al, al
    mov     si, EEPROM_CHECKSUM
    call    EEPROM_Write_SI

    call    Build_Checksum

    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_LIVE_W0_MFG], 06D50h
    mov     ax, [seed_product]
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_LIVE_W0_PRODUCT], ax
    mov     si, EEPROM_ADDR_CFG
    call    EEPROM_Read_SI
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_LIVE_W0_ADDR_CFG], ax
    mov     si, EEPROM_RESOURCE_CFG
    call    EEPROM_Read_SI
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_LIVE_W0_RES_CFG], ax

    xor     ah, ah
    mov     al, [seed_asic]
    shl     ax, 1
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_LIVE_W4_NETDIAG], ax

    lea     si, [factory_mac]
    mov     di, OFFSET state_blob + MCK_HEADER_SIZE + MCKR_FACTORY_MAC
    mov     cx, 6
    rep     movsb

    lea     si, [oem_mac]
    mov     di, OFFSET state_blob + MCK_HEADER_SIZE + MCKR_OEM_MAC
    mov     cx, 6
    rep     movsb

    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Build_State

PROC Build_Checksum NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si

    xor     bx, bx
    xor     si, si
@@HighLoop:
    cmp     si, 8
    je      @@HighNext
    cmp     si, 9
    je      @@HighNext
    cmp     si, 0Dh
    je      @@HighNext
    call    EEPROM_Read_SI
    xor     bl, al
    xor     bl, ah
@@HighNext:
    inc     si
    cmp     si, 0Eh
    jbe     @@HighLoop
    mov     [chk_high], bl

    xor     bx, bx
    mov     si, 8
@@LowLoop:
    cmp     si, 0Ah
    jb      @@LowRead
    cmp     si, 0Ch
    jbe     @@LowNext
@@LowRead:
    call    EEPROM_Read_SI
    xor     bl, al
    xor     bl, ah
@@LowNext:
    inc     si
    cmp     si, 0Dh
    jbe     @@LowLoop

    mov     si, EEPROM_CHECKSUM
    call    EEPROM_Read_SI
    mov     al, bl
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
    mov     bx, si
    and     bx, 003Fh
    shl     bx, 1
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_EEPROM + bx], ax
    pop     bx
    ret
ENDP EEPROM_Write_SI

PROC EEPROM_Read NEAR
    ; Input AL = EEPROM word index, output AX = value.
    push    bx
    xor     bh, bh
    mov     bl, al
    and     bl, 03Fh
    shl     bx, 1
    mov     ax, [WORD state_blob + MCK_HEADER_SIZE + MCKR_EEPROM + bx]
    pop     bx
    ret
ENDP EEPROM_Read

PROC EEPROM_Read_SI NEAR
    ; Input SI = EEPROM word index, output AX = value.
    push    bx
    mov     bx, si
    and     bx, 003Fh
    shl     bx, 1
    mov     ax, [WORD state_blob + MCK_HEADER_SIZE + MCKR_EEPROM + bx]
    pop     bx
    ret
ENDP EEPROM_Read_SI

PROC Write_State_File NEAR
    push    ax
    push    bx
    push    cx
    push    dx

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
