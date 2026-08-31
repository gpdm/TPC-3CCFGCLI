; ---------------------------------------------------------------------------
; 3C509DEF.INC
; Shared 3C509B hardware, EEPROM, ISA ID-port and mock-device definitions.
; ---------------------------------------------------------------------------
;
; Hardware target
; ---------------------------------------------------------------------------
;
; The hardware model in this project targets the ISA 3Com EtherLink III
; 3C509B family.
;
; Unless explicitly marked otherwise, the hardware definitions and bit
; meanings in this file follow:
;
;     3Com EtherLink III Parallel Tasking
;     ISA, EISA, Micro Channel, and PCMCIA
;     Adapter Drivers Technical Reference
;     Manual 09-0398-002B, August 1994
;
; The mock backend is intended to reproduce the configuration-facing hardware
; behaviour described by that reference.  It is not intended to emulate packet
; transmission, receive/transmit FIFOs, statistics, or the complete Ethernet
; controller.
;
; Behaviour reconstructed from the original 3Com configuration utility must
; not override documented 3C509B hardware semantics.  Any utility-specific
; behaviour that is not defined by the hardware reference should be identified
; separately as an application-level compatibility behaviour.
;
;
; ---------------------------------------------------------------------------
; 3C509B ISA product variants
; ---------------------------------------------------------------------------
;
; EEPROM word 03h contains the 3C5X9 Product ID.
;
; Product IDs documented by the 3Com reference for the ISA 3C509/3C509B
; family are:
;
;     9150h    3C509 / 3C509B
;     9050h    3C509-TP / 3C509B-TP
;     9450h    3C509-COMBO / 3C509B-COMBO
;     9550h    3C509-TPO / 3C509B-TPO
;
; The reference does not document 9850h as a 3C509B Product ID.
;
; The documented ISA connector configurations are:
;
;     3C509B-TPO
;         one connector:
;             10BASE-T
;
;     3C509B-TP
;         two connectors:
;             10BASE-T
;             AUI
;
;     3C509B-Coax
;         two connectors:
;             AUI
;             BNC / 10BASE2
;
;     3C509B-COMBO
;         three connectors:
;             10BASE-T
;             AUI
;             BNC / 10BASE2
;
; Connector availability is exposed by the live Window 0 Configuration
; Control register and should be treated as hardware capability information.
;
;
; ---------------------------------------------------------------------------
; Persistent EEPROM state versus live register state
; ---------------------------------------------------------------------------
;
; EEPROM configuration and live ASIC registers are distinct hardware state.
;
; In particular:
;
;     EEPROM 08h  -> persistent Address Configuration
;     EEPROM 09h  -> persistent Resource Configuration
;     EEPROM 12h  -> persistent Internal Configuration word 0
;     EEPROM 13h  -> persistent Internal Configuration word 1
;
; These values must not be treated as continuously mirrored live registers.
;
; For ISA 3C509B, automatic configuration after:
;
;     power-on reset
;     Configuration Control RST
;     Command-register Global Reset
;     ID-port Global Reset
;
; performs the following documented reload:
;
;     EEPROM 03h -> Window 0 Product ID
;     EEPROM 08h -> Window 0 Address Configuration
;     EEPROM 09h -> Window 0 Resource Configuration
;     EEPROM 12h/13h -> Window 3 Internal Configuration
;
; The station address is NOT automatically copied into Window 2.
; Driver software must read the station address from EEPROM words 00h-02h and
; explicitly program the Window 2 station-address registers.
;
;
; ---------------------------------------------------------------------------
; Window 0 Configuration Control register, offset 04h
; ---------------------------------------------------------------------------
;
; Relevant 3C509B read-only POR capability bits:
;
;     bit 14      1 = ISA interface
;
;     bit 13      AUI connector available
;                 0 = no AUI
;                 1 = AUI present
;
;     bit 12      on-board 10BASE2 transceiver available
;                 0 = no BNC transceiver
;                 1 = BNC / 10BASE2 present
;
;     bits 11:10  operating mode
;                 11b = normal operation
;                 other values reserved
;
;     bit 9       on-board 10BASE-T transceiver available
;                 0 = no TP transceiver
;                 1 = 10BASE-T present
;
;     bit 8       VCO selection on 3C509B
;                 0 = external VCO
;                 1 = internal on-chip VCO
;
; Relevant writable control bits:
;
;     bit 2       RST
;                 1 = reset adapter to power-on-reset state
;
;     bit 0       ENA
;                 0 = adapter disabled
;                 1 = adapter enabled
;
; The connector capability bits are hardware state.  Software should use
; these bits rather than infer connector availability solely from Product ID.
;
;
; ---------------------------------------------------------------------------
; Window 0 Address Configuration register / EEPROM word 08h
; ---------------------------------------------------------------------------
;
;     bits 15:14  XCVR
;
;                 00b = twisted pair / 10BASE-T
;                 01b = AUI
;                 10b = reserved / undefined
;                 11b = BNC / 10BASE2
;
;     bits 13:12  Boot ROM Size
;
;                 00b = 8 K
;                 01b = 16 K
;                 10b = 32 K
;                 11b = 64 K
;
;     bits 11:8   Boot ROM Base
;
;     bit 7       AUTO SELECT
;
;                 0 = use XCVR selection
;                 1 = driver must ignore XCVR and auto-select among the
;                     connectors reported by Configuration Control
;
;                 AUTO SELECT is software configuration information.  It does
;                 not itself switch the physical transceiver.
;
;     bit 6       must be zero
;
;     bit 5       reserved
;
;     bits 4:0    ISA I/O Base selector
;
;                 00h through 1Eh select:
;
;                     base = 0200h + selector * 10h
;
;                 therefore valid ISA bases are 0200h through 03E0h.
;
;                 1Fh selects EISA slot-specific addressing and is outside
;                 the ISA-only scope of 3CCFGCLI.
;
; For 10BASE-T, driver software must also configure Link Beat and Jabber in
; Window 4 Media Type and Status.
;
; For BNC / 10BASE2, driver software must issue Start Coaxial Transceiver
; through the Command register.
;
;
; ---------------------------------------------------------------------------
; Window 0 Resource Configuration register / EEPROM word 09h
; ---------------------------------------------------------------------------
;
;     bits 15:12  IRQ
;
; Valid enabled IRQ values:
;
;     3, 5, 7, 9, 10, 11, 12, 15
;
; Other encoded values disable the IRQ line drivers.
;
; For 3C509B:
;
;     bit 6       Synchronous Ready
;
;                 0 = normal I/O operation
;                 1 = assert I/OCHRDY for every I/O access
;
;
; ---------------------------------------------------------------------------
; EEPROM word 0Dh, Software Information
; ---------------------------------------------------------------------------
;
; The documented 3C509B Software Information layout is:
;
;     bit 15      must be zero
;
;     bit 14      Link Beat Disable
;
;                 0 = driver should enable Link Beat
;                 1 = driver should disable Link Beat
;
;                 This EEPROM bit is driver policy.  It does not directly
;                 modify Window 4 Media Type and Status.
;
;     bits 13:8   Maximum Interrupt Disable Time
;
;                 The encoded value plus one is the maximum number of
;                 25 microsecond intervals for which the driver may disable
;                 interrupts.
;
;                 Example:
;
;                     encoded 19 decimal
;                     -> (19 + 1) * 25 us
;                     -> 500 us
;
;                 The 3Com reference explicitly gives a 9600 baud modem as
;                 the example producing encoded value 19.
;
;     bits 7:6    must be zero
;
;     bits 5:4    Software Optimization
;
;                 00b = Reserved
;                 01b = DOS client
;                 10b = Windows client
;                 11b = Server
;
;     bits 3:0    Select Boot Protocol
;
;                 Selects a protocol present in the Boot ROM for remote
;                 program loading.
;
; IMPORTANT:
;
; There is no documented FULLDUPLEX bit in EEPROM word 0Dh.
; Bit 15 is documented as zero.
;
; A MODEM configuration property must modify only bits 13:8 if it is intended
; to represent the documented Maximum Interrupt Disable Time.
;
; MODEM must preserve:
;
;     bit 14
;     bits 7:6
;     bits 5:4
;     bits 3:0
;
; In particular, values such as 1320h must not be interpreted as a single
; "modem value":
;
;     13h in bits 13:8 = Maximum Interrupt Disable Time
;     2 in bits 5:4    = Windows client optimization
;
; These are independent fields in the same EEPROM word.
;
;
; ---------------------------------------------------------------------------
; EEPROM word 0Eh, Compatibility Word
; ---------------------------------------------------------------------------
;
;     bits 15:8   Fail Level
;     bits 7:0    Warning Level
;
; For 3C509B both documented values are zero.
;
;
; ---------------------------------------------------------------------------
; EEPROM word 0Fh, Primary Checksum
; ---------------------------------------------------------------------------
;
; BOTH bytes of EEPROM word 0Fh are checksums.
;
; High byte:
;
;     byte XOR of both bytes of EEPROM words 00h through 0Eh,
;     excluding:
;
;         08h
;         09h
;         0Dh
;
; Low byte:
;
;     byte XOR of both bytes of:
;
;         08h
;         09h
;         0Dh
;
; The high byte normally remains unchanged during user configuration.
; The low byte changes when configurable values in words 08h, 09h, or 0Dh
; are changed.
;
; EEPROM word 0Fh MUST NOT be used to store Software Optimization.
;
;
; ---------------------------------------------------------------------------
; EEPROM word 10h, Capabilities Word, 3C509B
; ---------------------------------------------------------------------------
;
; Documented ISA 3C509B value:
;
;     2083h
;
; Bit definitions:
;
;     bit 0       Plug and Play supported
;                 set on ISA 3C509B
;
;     bit 1       always one
;
;     bits 2:6    always zero
;
;     bit 7       CRC pass-through supported
;                 always set on 3C509B
;
;     bits 8:9    always zero
;
;     bits 10:12  reserved, read zero
;
;     bit 13      Power Management supported
;                 always set on 3C509B
;
;     bits 14:15  reserved, read zero
;
; Plug and Play CAPABILITY is therefore represented by EEPROM word 10h,
; bit 0.
;
; EEPROM word 14h Adapter Revision Level must not be used as a replacement
; for this capability bit.
;
;
; ---------------------------------------------------------------------------
; Window 3 Internal Configuration / EEPROM words 12h and 13h
; ---------------------------------------------------------------------------
;
; The Internal Configuration register is 32 bits wide and is loaded from
; EEPROM words 12h and 13h at startup/reset.
;
; Both halves may be accessed as 16-bit values.
;
; Relevant 3C509B field:
;
;     bits 19:18  ISA ACTIVATION SELECT
;
;                 00b = both ISA activation mechanisms enabled
;                       default
;
;                 01b = classic ISA contention only
;
;                 10b = ISA Plug and Play only
;
;                 11b = both ISA activation mechanisms enabled
;
; Since bits 19:18 are bits 3:2 of EEPROM word 13h:
;
;     word13 bits 3:2 = 00b or 11b
;         classic contention and PnP enabled
;
;     word13 bits 3:2 = 01b
;         PnP disabled, classic contention enabled
;
;     word13 bits 3:2 = 10b
;         classic contention disabled, PnP enabled
;
; A CONFIGURE /PNP operation that means "enable or disable Plug and Play while
; retaining classic ISA contention" should therefore change this field
; according to the documented activation-select encoding.
;
;
; ---------------------------------------------------------------------------
; EEPROM word 14h, Secondary Software Information
; ---------------------------------------------------------------------------
;
; Relevant documented fields:
;
;     bit 14      Auto Power
;
;                 0 = Auto Power Enable
;                 1 = Auto Power Disable
;
;     bit 4       Boot ROM Size Valid
;
;                 Indicates that a Boot ROM is installed and the ROM Size
;                 field is valid even if Boot ROM Base is zero.
;
;     bits 3:0    Adapter Revision Level
;
;                 0 = original 3C509-class hardware
;                 1 = 3C509B-class hardware
;
; Adapter Revision Level identifies the hardware revision class.
; It is NOT the documented Plug and Play capability bit.
;
;
; ---------------------------------------------------------------------------
; EEPROM word 17h, Secondary Checksums
; ---------------------------------------------------------------------------
;
; High byte:
;
;     Vital Data Checksum
;
;     byte XOR over:
;
;         words 10h through 12h
;         words 20h through 3Fh
;
; Low byte:
;
;     Configurable Data Checksum
;
;     byte XOR over:
;
;         words 13h through 16h
;
; Therefore changing EEPROM word 13h requires recalculation of the LOW byte
; of EEPROM word 17h.
;
;
; ---------------------------------------------------------------------------
; EEPROM words 18h through 3Fh
; ---------------------------------------------------------------------------
;
; ISA Plug and Play Resource Data.
;
; These locations contain data structured according to the ISA Plug and Play
; Resource Data specification.
;
; They are persistent raw EEPROM data and must not be regenerated or modified
; by the mock unless an explicitly implemented operation requires it.
;
;
; ---------------------------------------------------------------------------
; ISA ID port and activation
; ---------------------------------------------------------------------------
;
; After automatic configuration the ID Sequence State Machine is in ID_WAIT.
;
; The ID port is one of:
;
;     01x0h
;
; where x is any hexadecimal digit.
;
; Writing zero selects/resets ID-port sequence recognition.
;
; The normal ID sequence contains 255 bytes:
;
;     initial value = FFh
;
;     for each byte:
;         output current value
;         shift left
;         if the old high bit was one:
;             XOR with CFh
;
; The normal sequence begins with FFh and ends with 98h.
;
; After the complete sequence the adapter enters ID_CMD.
;
; Relevant ID_CMD command ranges:
;
;     00h-7Fh
;         return to ID_WAIT
;
;     80h-BFh
;         read EEPROM word n
;         n = low six bits
;
;     C0h-CFh
;         ID Global Reset
;         reset adapter to power-on-reset state
;
;     D0h-D7h
;         Set Tag n
;
;     D8h-DFh
;         Test adapter tag n
;         mismatching adapters return to ID_WAIT
;
;     E0h-FEh
;         Activate adapter
;
;         low five command bits are copied into Address Configuration
;         bits 4:0 and therefore select the active ISA I/O base.
;
;         adapter returns to ID_WAIT.
;
;     FFh
;         Activate adapter at the PRECONFIGURED I/O base address.
;
;         This is a distinct command and must not be interpreted as selector
;         1Fh.
;
;         adapter returns to ID_WAIT.
;
; ID-port EEPROM data is returned serially.
;
; During each contention read:
;
;     EEPROM Data bit 15 is driven onto host data bit 0
;     EEPROM Data shifts left one position after the read
;
; Multiple adapters use open-drain contention.
;
; If an adapter drives one while another adapter drives zero, the bus reads
; zero.  The adapter that attempted to drive one detects the mismatch, loses
; contention, and returns to ID_WAIT.
;
; The ID state machine continues to operate after an adapter has been
; activated.
;
;
; ---------------------------------------------------------------------------
; Mock-model rule
; ---------------------------------------------------------------------------
;
; The mock represents hardware state, not CONFIGURE command intent.
;
; It must not automatically:
;
;     repair EEPROM checksums
;     copy EEPROM values into live registers outside documented reset loading
;     move active I/O decoding merely because EEPROM 08h changed
;     change live IRQ state merely because EEPROM 09h changed
;     apply Link Beat policy merely because EEPROM 0Dh changed
;     infer connector capabilities from a CLI product name when the live
;         Configuration Control register provides the hardware capability
;     reinterpret reserved hardware values as supported values
;
; Software must perform the same hardware operations required by a physical
; 3C509B.
;
; ---------------------------------------------------------------------------


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
EEPROM_SOFTWARE_INFO_FULLDUPLEX        EQU 8000h
; Persistent driver policy. When set, the driver clears bit 7 of the live
; Window 4 Media Type and Status register during adapter initialization.
; CONFIGURE /LINKBEAT is intentionally unimplemented.
EEPROM_SOFTWARE_INFO_LINKBEAT_DISABLE  EQU 4000h
EEPROM_SOFTWARE_INFO_MODEM_MASK         EQU 3FFFh
; Empirically measured raw MODEM encodings (see comment above); the CLI's
; encode (Cfg_Handle_MODEM) and decode (Decode_Modem_Value) logic use these.
EEPROM_MODEM_NONE       EQU 3F20h
EEPROM_MODEM_1200       EQU 3320h
EEPROM_MODEM_2400       EQU 2720h
EEPROM_MODEM_9600       EQU 1320h
EEPROM_MODEM_19200      EQU 0920h
EEPROM_MODEM_38400      EQU 0420h
EEPROM_COMPATIBILITY    EQU 0Eh
EEPROM_CHECKSUM         EQU 0Fh
EEPROM_CAPABILITY       EQU 10h
EEPROM_CONFIG_CONTROL   EQU 13h
EEPROM_REVISION_INFO    EQU 14h
EEPROM_SECONDARY_CHECKSUM EQU 17h

EEPROM_CMD_READ         EQU 0080h
EEPROM_CMD_WRITE        EQU 0040h
EEPROM_CMD_ERASE        EQU 00C0h
EEPROM_CMD_WRITE_ENABLE EQU 0030h
EEPROM_CMD_WRITE_DISABLE EQU 0000h

ID_CMD_SET_TAG          EQU 0D0h
ID_CMD_SELECT_TAG       EQU 0D8h
ID_CMD_ACTIVATE         EQU 0E0h
ID_CMD_GLOBAL_RESET     EQU 0C0h
ID_CMD_ACTIVATE_CONFIGURED EQU 0FFh

EL3_COMMAND             EQU 0Eh
EL3_STATUS              EQU 0Eh
EL3_W0_MFG_ID           EQU 00h
EL3_W0_PRODUCT_ID       EQU 02h
EL3_W0_CONFIG_CONTROL   EQU 04h
EL3_W0_ADDRESS_CFG      EQU 06h
EL3_W0_RESOURCE_CFG     EQU 08h
EL3_W0_EEPROM_COMMAND   EQU 0Ah
EL3_W0_EEPROM_DATA      EQU 0Ch
EL3_W2_STATION_0        EQU 00h
EL3_W2_STATION_1        EQU 02h
EL3_W2_STATION_2        EQU 04h
EL3_W3_INTERNAL_CONFIG_0 EQU 00h
EL3_W3_INTERNAL_CONFIG_1 EQU 02h
EL3_W4_NET_DIAG         EQU 06h
; Media Type and Status register.  Bit 11 = "Valid link beat detected"
; (TP, read only).  Bit 7 = "Link beat enabled" (writable, not used by
; this build).  See 3c5x9b.pdf Figure 6-12.
EL3_W4_MEDIA_STATUS     EQU 0Ah

CMD_SELECT_WINDOW       EQU 0800h
STATUS_CMD_BUSY         EQU 1000h
EEPROM_BUSY             EQU 8000h
STATUS_WINDOW_MASK      EQU 0E000h

W0_CONFIG_CONTROL_WRITABLE EQU 0C05h
W0_CONFIG_CONTROL_RST       EQU 0004h
W0_CONFIG_CONTROL_ENA       EQU 0001h
W0_ADDRESS_CFG_WRITABLE     EQU 0FFFFh
W0_RESOURCE_CFG_WRITABLE    EQU 0FFFFh
W4_NET_DIAG_WRITABLE        EQU 0F001h
W4_NET_DIAG_ASIC_REV        EQU 0004h
W4_MEDIA_STATUS_WRITABLE    EQU 00CCh
W4_MEDIA_STATUS_RESERVED_ONE EQU 2000h

MCK_ID_AUTOINIT        EQU 0
MCK_ID_WAIT            EQU 1
MCK_ID_CMD             EQU 2
MCK_ID_ACTIVE          EQU 3
MCKRF_ACTIVE           EQU 01h
MCKRF_COAX_STARTED     EQU 02h
MCKEF_WRITE_ENABLED    EQU 01h
MCKEF_DATA_VALID       EQU 02h

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
MCK_VERSION_V2          EQU 0002h
MCK_VERSION             EQU 0003h
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
MCKR_CFG_PNP            EQU 34      ; DW
MCKR_CFG_FULLDUPLEX     EQU 38      ; DW

MCKR_LIVE_W0_MFG        EQU 40      ; DW
MCKR_LIVE_W0_PRODUCT    EQU 42      ; DW
MCKR_LIVE_W0_ADDR_CFG   EQU 44      ; DW
MCKR_LIVE_W0_RES_CFG    EQU 46      ; DW
MCKR_LIVE_W4_NETDIAG    EQU 48      ; DW
; Live Media Type and Status register (Window 4/Port 0Ah) bit 11, "Valid
; link beat detected" (read only) per 3c5x9b.pdf Figure 6-12.  This is
; the dynamic cable-link indicator surfaced by LIST as "Link Status".
MCKR_LIVE_W4_MEDIA_STATUS EQU 50    ; DW

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
MCK_CFGF_PNP            EQU 0800h
MCK_CFGF_FULLDUPLEX     EQU 2000h
MCK_CFGF_ALL            EQU 29FFh

; ---------------------------------------------------------------------------
; 3C509B.MCK v3 device image.  The image represents powered hardware: live
; state survives separate DOS processes and changes only through emulated I/O
; or an explicit reset.  EEPROM is persistent storage, not a register mirror.
; ---------------------------------------------------------------------------
MCK3R_PRESENT            EQU 00h    ; DB
MCK3R_ID_STATE           EQU 01h    ; DB
MCK3R_TAG                EQU 02h    ; DB
MCK3R_FLAGS              EQU 03h    ; DB
MCK3R_ACTIVE_BASE        EQU 04h    ; DW
MCK3R_CURRENT_WINDOW     EQU 06h    ; DB
MCK3R_COMMAND_BUSY       EQU 07h    ; DB
MCK3R_EEPROM_BUSY        EQU 08h    ; DB
MCK3R_EEPROM_FLAGS       EQU 09h    ; DB
MCK3R_ID_SEQUENCE_POS    EQU 0Ah    ; DW
MCK3R_ID_SHIFT           EQU 0Ch    ; DW
MCK3R_ID_BITS_LEFT       EQU 0Eh    ; DB
MCK3R_EEPROM_PENDING     EQU 0Fh    ; DB
MCK3R_W0_PRODUCT         EQU 10h    ; DW
MCK3R_W0_CONFIG_CONTROL  EQU 12h    ; DW
MCK3R_W0_ADDRESS_CFG     EQU 14h    ; DW
MCK3R_W0_RESOURCE_CFG    EQU 16h    ; DW
MCK3R_EEPROM_COMMAND     EQU 18h    ; DW
MCK3R_EEPROM_DATA        EQU 1Ah    ; DW
MCK3R_W2_STATION         EQU 1Ch    ; 6 bytes
MCK3R_W3_INTERNAL_CONFIG EQU 22h    ; 4 bytes
MCK3R_W4_NET_DIAG_WRITE  EQU 26h    ; DW
MCK3R_W4_MEDIA_WRITE     EQU 28h    ; DW
MCK3R_W4_MEDIA_INPUT     EQU 2Ah    ; DW
MCK3R_EEPROM             EQU 2Ch    ; 64 words, 128 bytes
