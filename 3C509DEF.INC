; ---------------------------------------------------------------------------
; 3C509DEF.INC
; Shared constants for 3CCFGCLI and 3CSEED.
; ---------------------------------------------------------------------------

ID_PORT                 EQU 0110h

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
EEPROM_COMPATIBILITY    EQU 0Eh
EEPROM_CHECKSUM         EQU 0Fh
EEPROM_CAPABILITY       EQU 10h
EEPROM_CONFIG_CONTROL   EQU 13h
EEPROM_REVISION_INFO    EQU 14h

ID_CMD_SET_TAG          EQU 0D0h
ID_CMD_SELECT_TAG       EQU 0D8h
ID_CMD_ACTIVATE         EQU 0E0h

EL3_COMMAND             EQU 0Eh
EL3_STATUS              EQU 0Eh
EL3_W0_MFG_ID           EQU 00h
EL3_W0_PRODUCT_ID       EQU 02h
EL3_W0_ADDRESS_CFG      EQU 06h
EL3_W0_RESOURCE_CFG     EQU 08h
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

VALID_IOBASE_MIN        EQU 0200h
VALID_IOBASE_MAX        EQU 03E0h
VALID_IOBASE_STEP       EQU 0010h

; ---------------------------------------------------------------------------
; 3C509B.MCK file layout (v1)
; ---------------------------------------------------------------------------
MCK_MAGIC_0             EQU '3'
MCK_MAGIC_1             EQU 'C'
MCK_MAGIC_2             EQU '5'
MCK_MAGIC_3             EQU 'M'
MCK_VERSION             EQU 0001h

MCK_OFF_MAGIC0          EQU 0
MCK_OFF_MAGIC1          EQU 1
MCK_OFF_MAGIC2          EQU 2
MCK_OFF_MAGIC3          EQU 3
MCK_OFF_VERSION         EQU 4       ; DW
MCK_OFF_RECORD_COUNT    EQU 6       ; DB
MCK_HEADER_SIZE         EQU 16

MCKR_PRESENT            EQU 0       ; DB
MCKR_ACTIVE             EQU 1       ; DB
MCKR_TAG                EQU 2       ; DB
MCKR_ID_MODE            EQU 3       ; DB
MCKR_CURRENT_WINDOW     EQU 4       ; DB
MCKR_ASIC_REV           EQU 5       ; DB
MCKR_IRQ                EQU 6       ; DB
MCKR_RSVD0              EQU 7       ; DB

MCKR_ACTIVE_BASE        EQU 8       ; DW
MCKR_PRODUCT_ID         EQU 10      ; DW

MCKR_CFG_FLAGS          EQU 12      ; DW
MCKR_CFG_INT            EQU 14      ; DW
MCKR_CFG_IOBASE         EQU 16      ; DW
MCKR_CFG_PORT           EQU 18      ; DW
MCKR_CFG_BADDRESS       EQU 20      ; DW
MCKR_CFG_BSIZE          EQU 22      ; DW
MCKR_CFG_TR             EQU 24      ; DW
MCKR_CFG_XCVR           EQU 26      ; DW
MCKR_CFG_MODEM          EQU 28      ; DW
MCKR_CFG_OPTIMIZE       EQU 30      ; DW
MCKR_CFG_LINKBEAT       EQU 32      ; DW
MCKR_CFG_CONFIGPORT     EQU 34      ; DW
MCKR_CFG_PNP            EQU 36      ; DW
MCKR_CFG_SYNCREADY      EQU 38      ; DW
MCKR_CFG_FULLDUPLEX     EQU 40      ; DW

MCKR_LIVE_W0_MFG        EQU 42      ; DW
MCKR_LIVE_W0_PRODUCT    EQU 44      ; DW
MCKR_LIVE_W0_ADDR_CFG   EQU 46      ; DW
MCKR_LIVE_W0_RES_CFG    EQU 48      ; DW
MCKR_LIVE_W4_NETDIAG    EQU 50      ; DW

MCKR_EEPROM             EQU 64      ; 64 words = 128 bytes
MCKR_FACTORY_MAC        EQU 192     ; 6 bytes
MCKR_OEM_MAC            EQU 198     ; 6 bytes

MCK_RECORD_SIZE         EQU 256
MCK_FILE_SIZE           EQU MCK_HEADER_SIZE + MCK_RECORD_SIZE

MCK_CFGF_INT            EQU 0001h
MCK_CFGF_IOBASE         EQU 0002h
MCK_CFGF_PORT           EQU 0004h
MCK_CFGF_BADDRESS       EQU 0008h
MCK_CFGF_BSIZE          EQU 0010h
MCK_CFGF_TR             EQU 0020h
MCK_CFGF_XCVR           EQU 0040h
MCK_CFGF_MODEM          EQU 0080h
MCK_CFGF_OPTIMIZE       EQU 0100h
MCK_CFGF_LINKBEAT       EQU 0200h
MCK_CFGF_CONFIGPORT     EQU 0400h
MCK_CFGF_PNP            EQU 0800h
MCK_CFGF_SYNCREADY      EQU 1000h
MCK_CFGF_FULLDUPLEX     EQU 2000h
MCK_CFGF_ALL            EQU 3FFFh
