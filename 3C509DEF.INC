; ---------------------------------------------------------------------------
; 3C509DEF.INC
; Shared constants for 3CCFGCLI and 3CSEED.
; ---------------------------------------------------------------------------
;
; Supported ISA product IDs and per-feature capability matrix.
;
; The original 3CCFG utility gates certain configuration verbs on two
; independent mechanisms:
;
;   (A) EEPROM-driven: a capability field read at run time decides support.
;   (B) Product-ID-driven: the utility dispatches on the product ID word and
;       takes a "not capable" path for any unrecognised ID.
;
; For the five known ISA SKUs both mechanisms agree; no known ISA 3C509 SKU
; has product-ID support without the matching EEPROM capability bit, or vice
; versa.  The two columns are separated below to make the dual gate explicit.
;
;  Product             | EEPROM              | Product ID |     |            |       |
;  Constant            | word 03h bits 15:8  | (hex)      | PNP | FULLDUPLEX | MODEM | /TR (transceiver types accepted)
; ---------------------+---------------------+------------+-----+------------+-------+----------------------------------
;  PRODUCT_3C509_TP    | 90h  (3C509B-TP)    |  9050h     |  1  |     1      |   1   | TP only
;  PRODUCT_3C509       | 91h  (3C509B-Combo) |  9150h     |  1  |     1      |   1   | TP, AUI, AUTO
;  PRODUCT_3C509_COMBO | 94h  (3C509B-C)     |  9450h     |  1  |     1      |   1   | TP, AUI, AUTO
;  PRODUCT_3C509_TPO   | 95h  (3C509B-TPO)   |  9550h     |  1  |     1      |   1   | TP, AUI  (no AUTO; TPO excluded from auto-select path)
;  PRODUCT_3C509_TPC   | 98h  (3C509B-TPC)   |  9850h     |  1  |     1      |   1   | TP, COAX
;  (unknown/other)     | any other value     |  ????h     |  *  |     0      |   1   | (not recognised; /TR gate TBD)
; ---------------------+---------------------+------------+-----+------------+-------+----------------------------------
;
; Notes:
;   PNP:        Gated on EEPROM_REVISION_INFO (word 14h) low byte >= 1.
;               This is a pure EEPROM flag; the value is set by the
;               manufacturer or configuration tool, not derived from the
;               product ID.  A card whose word 14h low byte is zero will
;               refuse /PNP configuration regardless of its product ID.
;               Marked (*) above because it is EEPROM-content-dependent,
;               not product-ID-dependent.
;
;   FULLDUPLEX: Gated on BOTH product ID recognition (the five IDs above
;               dispatch to the capable path; any other ID falls to the
;               not-capable path) AND on EEPROM_CAPABILITY (word 10h) bit 0
;               being set.  Both conditions must hold.  In practice all five
;               known SKUs ship with word 10h bit 0 = 1.
;
;   MODEM:      No capability gate in the original utility.  The modem speed
;               field (EEPROM_SOFTWARE_INFO word 0Dh bits 14:0) is written
;               unconditionally for any recognised adapter.  Word 0Dh bit 15
;               is FULLDUPLEX and is always preserved during modem writes.
;
;   TR (/XCVR): Writes EEPROM_ADDR_CFG (word 08h) bits 15:14 (media selection).
;               AUTO is only available on "later" cards (3C509B) that are not
;               TPO; it is signalled by bit 7 of word 08h rather than bits
;               15:14.  The 3C509B-TP has a single on-board TP connector and
;               no external port, so AUI/COAX/AUTO are not meaningful for it.
;               The 3C509B-TPC (coax) has no AUI port.
;               Capability gate details are TBD pending /TR implementation.
;
;  EEPROM word 08h bits 15:14 | Bit 7 | Raw value | Symbolic name | LIST display
;  ---------------------------+-------+-----------+---------------+---------------
;  00                         |   0   |   0h      | TP            | on-board TP
;  01                         |   0   |   1h      | AUI           | external
;  10                         |   0   |   2h      | (normalised   | external
;                             |       |           |  to AUI)      |
;  11                         |   0   |   3h      | COAX          | on-board coax
;  (any)                      |   1   |   -       | AUTO          | auto select
;  ---------------------------+-------+-----------+---------------+---------------
;  Note: bit 7 = AUTO overrides bits 15:14 in the display path.  Values 0 and 2
;  both map to "external" on read-back (normalisation: raw 2 -> display as 1).
;  AUTO is suppressed for 3C509B-TPO even on later-card hardware.
;
;   OPTIMIZE:   No separate product-ID gate was found.  The original utility
;               accepts the property for recognised adapters and stores the
;               high byte of EEPROM_CHECKSUM (word 0Fh bits 15:8).
;               The documented CLI keywords are DOS, WINDOWS, OS/2, and SERVER.
;               The additional raw values below appear to be undocumented and
;               are not implemented as symbolic names in the CLI.
;
;  EEPROM word 0Fh bits 15:8 | Raw value | Symbolic name | Comments
;  --------------------------+-----------+---------------+-------------------------
;  15:8                      | 00h       | DOS           | implemented
;  15:8                      | 01h       | WINDOWS       | implemented
;  15:8                      | 02h       | OS/2          | implemented; literal slash
;  15:8                      | 04h       | SERVER        | implemented
;  15:8                      | 06h       | UNKNOWN       | not implemented
;  15:8                      | 08h       | UNKNOWN       | not implemented
;  15:8                      | 0Dh       | UNKNOWN       | not implemented
;  15:8                      | 0Eh       | UNKNOWN       | not implemented
;  15:8                      | 0Fh       | UNKNOWN       | not implemented
;

ID_PORT                 EQU 0110h    ; sometimes referenced as CONFIG_PORT

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
; Media Type and Status register.  Bit 11 = "Valid link beat detected"
; (TP, read only).  Bit 7 = "Link beat enabled" (writable, not used by
; this build).  See 3c5x9b.pdf Figure 6-12.
EL3_W4_MEDIA_STATUS     EQU 0Ah

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
; 3C509B.MCK file layout (v2, multi-record)
; ---------------------------------------------------------------------------
MCK_MAGIC_0             EQU '3'
MCK_MAGIC_1             EQU 'C'
MCK_MAGIC_2             EQU '5'
MCK_MAGIC_3             EQU 'M'
MCK_VERSION_V1          EQU 0001h
MCK_VERSION             EQU 0002h
; Multi-record mock state is designed to preserve the CLI-visible contract for
; normal distinct-base adapter discovery/configuration.  Same-active-IOBASE
; records remain a deliberate conflict-simulation case; see 3CMOCKIF.ASM.

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
; MCKR_CFG_LINKBEAT is an inert placeholder.  The original 3CCFG utility's
; property-name table includes a 'LINKBEAT' string, so the verb name was
; likely recognised, but no disassembly evidence pins down which EEPROM
; word or bit it wrote, if any.  Per 3Com's EtherLink III Technical
; Reference (3c5x9b.pdf, Figure 6-12, Media Type and Status Register,
; Window 4 / Port 0Ah), "Link beat enabled" is bit 7 of a live ASIC
; register, not a documented EEPROM field, defaulting to 0 and meant to
; be set by driver software at initialization.  This field remains
; defined for layout completeness but is deliberately NOT wired to any
; CONFIGURE verb.  See EL3_W4_MEDIA_STATUS below for the live, read-only
; link status bit that IS surfaced (in LIST) instead.
MCKR_CFG_LINKBEAT       EQU 32      ; DW - reserved/unwired placeholder
MCKR_CFG_PNP            EQU 36      ; DW
MCKR_CFG_FULLDUPLEX     EQU 40      ; DW

MCKR_LIVE_W0_MFG        EQU 42      ; DW
MCKR_LIVE_W0_PRODUCT    EQU 44      ; DW
MCKR_LIVE_W0_ADDR_CFG   EQU 46      ; DW
MCKR_LIVE_W0_RES_CFG    EQU 48      ; DW
MCKR_LIVE_W4_NETDIAG    EQU 50      ; DW
; Live Media Type and Status register (Window 4/Port 0Ah) bit 11, "Valid
; link beat detected" (read only) per 3c5x9b.pdf Figure 6-12.  This is
; the dynamic cable-link indicator surfaced by LIST as "Link Status".
MCKR_LIVE_W4_MEDIA_STATUS EQU 52    ; DW

MCKR_EEPROM             EQU 64      ; 64 words = 128 bytes
MCKR_FACTORY_MAC        EQU 192     ; 6 bytes
MCKR_OEM_MAC            EQU 198     ; 6 bytes
 
MCK_MAX_RECORDS         EQU 6
MCK_RECORD_SIZE         EQU 256
MCK_FILE_SIZE           EQU MCK_HEADER_SIZE + (MCK_MAX_RECORDS * MCK_RECORD_SIZE)

MCK_CFGF_INT            EQU 0001h
MCK_CFGF_IOBASE         EQU 0002h
MCK_CFGF_PORT           EQU 0004h
MCK_CFGF_BADDRESS       EQU 0008h
MCK_CFGF_BSIZE          EQU 0010h
MCK_CFGF_TR             EQU 0020h
MCK_CFGF_XCVR           EQU 0040h
MCK_CFGF_MODEM          EQU 0080h
MCK_CFGF_OPTIMIZE       EQU 0100h
MCK_CFGF_LINKBEAT       EQU 0200h   ; reserved/unwired placeholder, see MCKR_CFG_LINKBEAT
MCK_CFGF_PNP            EQU 0800h
MCK_CFGF_FULLDUPLEX     EQU 2000h
MCK_CFGF_ALL            EQU 2BFFh
