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

MOCK_STATE_FILE DB '3C509B.MCK', 0

msg_banner   DB '3CSEED - 3C509B mock state seeder', 0Dh, 0Ah, '$'
msg_help     DB 'Usage: 3CSEED [INIT|RANDOM|CLEAR|/H|/?]', 0Dh, 0Ah
             DB '  INIT   Create deterministic one-card seed state.', 0Dh, 0Ah
             DB '  RANDOM Create randomized one-card seed state.', 0Dh, 0Ah
             DB '  CLEAR  Delete 3C509B.MCK.', 0Dh, 0Ah, '$'
msg_ok_init  DB 'Seed file created (INIT).', 0Dh, 0Ah, '$'
msg_ok_rand  DB 'Seed file created (RANDOM).', 0Dh, 0Ah, '$'
msg_ok_clear DB 'Seed file deleted (or already absent).', 0Dh, 0Ah, '$'
msg_fail_io  DB 'File I/O error.', 0Dh, 0Ah, '$'
msg_bad_arg  DB 'Invalid command argument.', 0Dh, 0Ah, '$'

kw_init      DB 'INIT', 0
kw_random    DB 'RANDOM', 0
kw_clear     DB 'CLEAR', 0

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

    mov     dx, OFFSET msg_banner
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

PROC Seed_Init NEAR
    mov     [seed_product], PRODUCT_3C509_TP
    mov     [seed_base], 0300h
    mov     [seed_irq], 10
    mov     [seed_asic], 4
    mov     [seed_media], 0

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
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_LINKBEAT], 1
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_CONFIGPORT], 0
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_PNP], 1
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_SYNCREADY], 0
    mov     [WORD state_blob + MCK_HEADER_SIZE + MCKR_CFG_FULLDUPLEX], 0

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

    mov     ah, [chk_high]
    mov     al, bl
    mov     si, EEPROM_CHECKSUM
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
