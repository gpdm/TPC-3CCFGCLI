; ============================================================================
; 3CCFGCLI.ASM
; 3Com EtherLink III 3C509 and 3C509B ISA LIST and CONFIGURE framework
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
; Scope note: this reduced utility supports ISA EtherLink III adapters only.
; EISA bus support and Micro Channel bus support from the original utility were
; explicitly removed and are not part of this build.  The EISA and MCA generic
; description strings are retained only as reference resources.
;
; Compatibility note: the original 3CCFG also accepted /PORT as an alias for
; /IOBASE.  This reduced 3CCFGCLI deliberately omits that alias.  Use /IOBASE
; instead.  /PORT is intentionally unsupported, not an unfinished feature.
;
; The executable detector remains limited to the 3C509 and 3C509B 9050h family.
; The 3C508 ISA description resource is retained for completeness, but 8050h
; family detection is not present in this reduced source.
;
; The original 3CCFG also contains resource manager and ISA PnP discovery before
; the classic 3Com ID sequence.  This reduced utility catches PnP cards that are
; already activated at an ISA base, and cards for which the classic 3Com ID
; mechanism is enabled.  It does not implement standalone ISA PnP serial
; isolation for an inactive adapter configured for PnP only mode.
;
; Extended LIST information is read only after enumeration from the activated
; adapter.  The proven ID port contention, tagging, activation, record layout,
; MAC address, I O base and IRQ discovery path is intentionally left unchanged.
;
; CONFIGURE uses one centralized staged transaction facility.  /INT and /IOBASE
; handlers only parse and stage requested values.  Property preparation routines
; merge those requests into one prospective configuration image, then the shared
; Cfg_Txn facility owns activation, I O migration, EEPROM writes, checksum update,
; live register synchronization and verification.  /INT behavior remains based
; on the hardware tested release 0.3.3 implementation.  All other hardware
; property handlers remain explicit stubs.
;
; Release 0.3.5 adds strict single occurrence validation for every supported
; CONFIGURE verb.  /ADAPTERNUM, /INT, /IOBASE and /VERBOSE may each appear
; at most once.  Duplicate detection is completed before discovery, property
; dispatch or the centralized hardware transaction can begin.
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
EEPROM_COMPATIBILITY      EQU 0Eh
EEPROM_CAPABILITY         EQU 10h
EEPROM_CONFIG_CONTROL     EQU 13h
EEPROM_REVISION_INFO      EQU 14h

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

; CONFIGURE property identifiers.  XCVR maps to TR.  /PORT is deliberately absent.
CFG_OPT_INT             EQU 1
CFG_OPT_IOBASE          EQU 2
CFG_OPT_BADDRESS        EQU 3
CFG_OPT_BSIZE           EQU 4
CFG_OPT_TR              EQU 5
CFG_OPT_MODEM           EQU 6
CFG_OPT_OPTIMIZE        EQU 7
CFG_OPT_LINKBEAT        EQU 8
CFG_OPT_CONFIGPORT      EQU 9
CFG_OPT_PNP             EQU 10
CFG_OPT_SYNCREADY       EQU 11
CFG_OPT_FULLDUPLEX      EQU 12

CFG_PARSE_ADAPTER       EQU 01h
CFG_PARSE_INT           EQU 02h
CFG_PARSE_VERBOSE       EQU 04h
CFG_PARSE_IOBASE        EQU 08h

; Strict CONFIGURE single occurrence tracking, independent of staged state.
CFG_SEEN_ADAPTER        EQU 01h
CFG_SEEN_INT            EQU 02h
CFG_SEEN_IOBASE         EQU 04h
CFG_SEEN_VERBOSE        EQU 08h

; Central CONFIGURE transaction change flags.
CFG_TXN_CHG_WORD08       EQU 01h
CFG_TXN_CHG_WORD09       EQU 02h
CFG_TXN_CHG_LIVE06       EQU 04h
CFG_TXN_CHG_LIVE08       EQU 08h
CFG_TXN_MIGRATE_IO       EQU 10h
CFG_TXN_IOBASE_CHANGED   EQU 20h
CFG_TXN_INT_CHANGED      EQU 40h
CFG_PARSE_HW_MASK        EQU 0Ah
CFG_TXN_IO_DETECT_MASK   EQU 15h
CFG_TXN_WORD09_INT_MASK  EQU 42h
CFG_TXN_EEPROM_MASK      EQU 03h
CFG_TXN_LIVE06_MASK      EQU 14h
CFG_TXN_COMMIT_MASK      EQU 70h
CFG_TXN_INT_MIGRATE_MASK EQU 50h

; Common CONFIGURE result codes.
CFG_ERR_NONE                EQU 0
CFG_ERR_NO_NIC              EQU 1
CFG_ERR_BAD_ADAPTER         EQU 2
CFG_ERR_REVALIDATE          EQU 3
CFG_ERR_UNSUPPORTED_PRODUCT EQU 4
CFG_ERR_UNSUPPORTED_ASIC    EQU 5
CFG_ERR_EEPROM_TIMEOUT      EQU 6
CFG_ERR_COMMAND_TIMEOUT     EQU 7
CFG_ERR_BAD_OPTION          EQU 8
CFG_ERR_MISSING_VALUE       EQU 9
CFG_ERR_NOT_IMPLEMENTED     EQU 10
CFG_ERR_ADAPTER_REQUIRED    EQU 11
CFG_ERR_DUP_PROPERTY        EQU 12
CFG_ERR_NO_PROPERTY         EQU 13
CFG_ERR_BAD_INT             EQU 14
CFG_ERR_EEPROM_READ         EQU 15
CFG_ERR_EEPROM_WRITE        EQU 16
CFG_ERR_CHECKSUM_UPDATE     EQU 17
CFG_ERR_LIVE_UPDATE         EQU 18
CFG_ERR_VERIFY              EQU 19
CFG_ERR_INT_INACTIVE        EQU 20
CFG_ERR_BAD_IOBASE          EQU 21
CFG_ERR_IOBASE_INACTIVE     EQU 22
CFG_ERR_IOBASE_CONFLICT     EQU 23
CFG_ERR_IOBASE_DEACTIVATE   EQU 24
CFG_ERR_IOBASE_REACTIVATE   EQU 25
CFG_ERR_IOBASE_EEPROM_READ  EQU 26
CFG_ERR_IOBASE_EEPROM_WRITE EQU 27
CFG_ERR_IOBASE_LIVE         EQU 28
CFG_ERR_IOBASE_VERIFY       EQU 29
CFG_ERR_IOBASE_ACTIVATE     EQU 30

DATASEG

VERSION_STRING	DB '0.3.5', '$'

msg_banner_prefix DB  "3Com EtherLink III CLI Configuration Program v", '$'
msg_banner_suffix DB  0Dh, 0Ah
                  DB  "derived from the original 3Com EtherLink III Configuration Utility v3.2", 0Dh, 0Ah, 0Dh, 0Ah, '$'

msg_help        DB  "Usage: 3CCFGCLI [COMMAND]", 0Dh, 0Ah, 0Dh, 0Ah
                DB  "Commands:", 0Dh, 0Ah
                DB  "  /? or /H          Display this help screen.", 0Dh, 0Ah
                DB  "  LIST              Detect and display 3C509 and 3C509B adapters.", 0Dh, 0Ah
                DB  "  CONFIGURE         Configure supported ISA properties, /INT and /IOBASE.", 0Dh, 0Ah
                DB  "                    /ADAPTERNUM:N selects the NIC number shown by LIST.", 0Dh, 0Ah
                DB  "                    /INT:N sets the IRQ.", 0Dh, 0Ah
                DB  "                    /IOBASE:NNN sets the ISA I/O base address.", 0Dh, 0Ah
                DB  "  /VERBOSE          Show detailed CONFIGURE transaction diagnostics.", 0Dh, 0Ah, '$'

msg_no_cards    DB  "No EtherLink III NICs are installed in this computer.", 0Dh, 0Ah, '$'

; CONFIGURE framework diagnostics.
msg_cfg_bad_adapter DB "Invalid ADAPTERNUM value.", 0Dh, 0Ah, '$'
msg_cfg_need_adapter DB "ADAPTERNUM is required when more than one adapter is installed.", 0Dh, 0Ah, '$'
msg_cfg_dup_property DB "Duplicate CONFIGURE property.", 0Dh, 0Ah, '$'
msg_cfg_revalidate DB "Selected adapter no longer matches the discovered NIC.", 0Dh, 0Ah, '$'
msg_cfg_unsupported_product DB "Unsupported EtherLink III product.", 0Dh, 0Ah, '$'
msg_cfg_unsupported_asic DB "Unsupported ASIC revision.", 0Dh, 0Ah, '$'
msg_cfg_eeprom_timeout DB "EEPROM access timed out.", 0Dh, 0Ah, '$'
msg_cfg_command_timeout DB "Adapter command timed out.", 0Dh, 0Ah, '$'
msg_cfg_bad_option DB "Invalid CONFIGURE option.", 0Dh, 0Ah, '$'
msg_cfg_missing_value DB "Missing CONFIGURE option value.", 0Dh, 0Ah, '$'
msg_cfg_no_property DB "No CONFIGURE property was specified.", 0Dh, 0Ah, '$'
msg_cfg_not_implemented DB "CONFIGURE option not implemented in this release.", 0Dh, 0Ah, '$'
msg_cfg_bad_int DB "Invalid /INT parameter. Value must be 3, 5, 7, 9, 10, 11, 12, or 15.", 0Dh, 0Ah, '$'
msg_cfg_int_ok DB "INT parameter accepted. Requested IRQ: ", '$'
msg_cfg_crlf DB 0Dh, 0Ah, '$'
msg_cfg_adapter_prefix DB "Adapter ", '$'
msg_cfg_adapter_suffix DB " selected.", 0Dh, 0Ah, '$'
msg_cfg_read_irq DB 0Dh, 0Ah, "Reading current IRQ configuration...", 0Dh, 0Ah, '$'
msg_cfg_current_irq DB "Current IRQ: ", '$'
msg_cfg_current_word09 DB "Current EEPROM word 09h: ", '$'
msg_cfg_prepare_irq DB 0Dh, 0Ah, "Preparing IRQ change...", 0Dh, 0Ah, '$'
msg_cfg_new_word09 DB "New EEPROM word 09h: ", '$'
msg_cfg_prepare_active DB 0Dh, 0Ah, "Preparing adapter using original ISA activation sequence...", 0Dh, 0Ah, '$'
msg_cfg_active_prepared DB "Adapter reactivated and live IRQ staged.", 0Dh, 0Ah, '$'
msg_cfg_irq_unchanged DB 0Dh, 0Ah, "IRQ is already configured to the requested value.", 0Dh, 0Ah
                      DB "No hardware changes required.", 0Dh, 0Ah, '$'
msg_cfg_write_irq DB 0Dh, 0Ah, "Writing IRQ configuration to EEPROM...", 0Dh, 0Ah, '$'
msg_cfg_irq_word_written DB "IRQ configuration word written.", 0Dh, 0Ah, '$'
msg_cfg_update_checksum DB 0Dh, 0Ah, "Updating EEPROM checksum...", 0Dh, 0Ah, '$'
msg_cfg_checksum_updated DB "EEPROM checksum updated.", 0Dh, 0Ah, '$'
msg_cfg_update_live DB 0Dh, 0Ah, "Updating live IRQ configuration...", 0Dh, 0Ah, '$'
msg_cfg_live_updated DB "Live IRQ configuration updated.", 0Dh, 0Ah, '$'
msg_cfg_verifying DB 0Dh, 0Ah, "Verifying configuration...", 0Dh, 0Ah, '$'
msg_cfg_eeprom_verified DB "EEPROM IRQ verified: ", '$'
msg_cfg_live_verified DB "Live IRQ verified: ", '$'
msg_cfg_completed DB 0Dh, 0Ah, "IRQ configuration completed successfully.", 0Dh, 0Ah, '$'
msg_cfg_eeprom_read_fail DB "EEPROM read timed out while reading IRQ configuration.", 0Dh, 0Ah, '$'
msg_cfg_eeprom_write_fail DB "EEPROM write timed out while writing IRQ configuration.", 0Dh, 0Ah, '$'
msg_cfg_checksum_fail DB "EEPROM checksum update failed.", 0Dh, 0Ah, '$'
msg_cfg_live_fail DB "Live IRQ configuration update failed.", 0Dh, 0Ah, '$'
msg_cfg_verify_fail DB "IRQ configuration verification failed.", 0Dh, 0Ah, '$'
msg_cfg_int_inactive DB "Selected adapter has no active I/O base for /INT configuration.", 0Dh, 0Ah, '$'

; /IOBASE diagnostics.
msg_cfg_bad_iobase DB "Invalid /IOBASE parameter. Use hexadecimal 0200 through 03E0 in 10h increments.", 0Dh, 0Ah, '$'
msg_cfg_iobase_inactive DB "Selected adapter has no active I/O base for /IOBASE configuration.", 0Dh, 0Ah, '$'
msg_cfg_iobase_conflict DB "Requested I/O base is already used by another discovered adapter.", 0Dh, 0Ah, '$'
msg_cfg_iobase_deactivate_fail DB "Selected adapter deactivation failed before I/O base migration.", 0Dh, 0Ah, '$'
msg_cfg_iobase_reactivate_fail DB "Adapter reactivation at the requested I/O base failed.", 0Dh, 0Ah, '$'
msg_cfg_iobase_eeprom_read_fail DB "EEPROM read timed out while reading I/O configuration.", 0Dh, 0Ah, '$'
msg_cfg_iobase_eeprom_write_fail DB "EEPROM write timed out while writing I/O configuration.", 0Dh, 0Ah, '$'
msg_cfg_iobase_live_fail DB "Live I/O configuration access or update failed.", 0Dh, 0Ah, '$'
msg_cfg_iobase_verify_fail DB "I/O base configuration verification failed.", 0Dh, 0Ah, '$'
msg_cfg_iobase_activate_fail DB "Adapter did not become reachable at the requested I/O base.", 0Dh, 0Ah, '$'
msg_cfg_iobase_ok DB "IOBASE parameter accepted. Requested I/O base: ", '$'
msg_cfg_read_iobase DB 0Dh, 0Ah, "Reading current I/O configuration...", 0Dh, 0Ah, '$'
msg_cfg_current_iobase DB "Current persistent I/O base: ", '$'
msg_cfg_current_live_iobase DB "Current live I/O base: ", '$'
msg_cfg_current_word08 DB "Current EEPROM word 08h: ", '$'
msg_cfg_current_live06 DB "Current live Address Configuration: ", '$'
msg_cfg_current_live08 DB "Current live Resource Configuration: ", '$'
msg_cfg_prepare_iobase DB 0Dh, 0Ah, "Preparing I/O base change...", 0Dh, 0Ah, '$'
msg_cfg_new_word08 DB "New EEPROM word 08h: ", '$'
msg_cfg_new_live06 DB "New live Address Configuration: ", '$'
msg_cfg_new_live08 DB "New live Resource Configuration: ", '$'
msg_cfg_iobase_unchanged DB 0Dh, 0Ah, "I/O base is already configured to the requested value.", 0Dh, 0Ah
                         DB "No I/O base hardware changes required.", 0Dh, 0Ah, '$'
msg_cfg_deactivate_iobase DB 0Dh, 0Ah, "Deactivating selected adapter at old I/O base...", 0Dh, 0Ah, '$'
msg_cfg_reactivate_iobase DB "Reactivating adapter at requested I/O base...", 0Dh, 0Ah, '$'
msg_cfg_iobase_reactivated DB "Adapter reactivated and live I/O configuration staged.", 0Dh, 0Ah, '$'
msg_cfg_write_iobase DB 0Dh, 0Ah, "Writing I/O configuration to EEPROM...", 0Dh, 0Ah, '$'
msg_cfg_iobase_word_written DB "I/O configuration word written.", 0Dh, 0Ah, '$'
msg_cfg_combined_irq_word_written DB "IRQ configuration word written in combined transaction.", 0Dh, 0Ah, '$'
msg_cfg_update_live_iobase DB 0Dh, 0Ah, "Updating live I/O configuration...", 0Dh, 0Ah, '$'
msg_cfg_live_iobase_updated DB "Live I/O configuration updated.", 0Dh, 0Ah, '$'
msg_cfg_verifying_iobase DB 0Dh, 0Ah, "Verifying I/O configuration...", 0Dh, 0Ah, '$'
msg_cfg_eeprom_iobase_verified DB "EEPROM I/O base verified: ", '$'
msg_cfg_live_iobase_verified DB "Live I/O base verified: ", '$'
msg_cfg_iobase_completed DB 0Dh, 0Ah, "I/O base configuration completed successfully.", 0Dh, 0Ah, '$'
msg_cfg_combined_completed DB 0Dh, 0Ah, "I/O base and IRQ configuration completed successfully.", 0Dh, 0Ah, '$'
msg_cfg_txn_read DB 0Dh, 0Ah, "Reading current configuration...", 0Dh, 0Ah, '$'
msg_cfg_txn_prepare DB 0Dh, 0Ah, "Preparing requested configuration...", 0Dh, 0Ah, '$'
msg_cfg_txn_no_changes DB "No hardware changes required.", 0Dh, 0Ah, '$'
msg_cfg_txn_write DB 0Dh, 0Ah, "Writing changed EEPROM configuration...", 0Dh, 0Ah, '$'
msg_cfg_txn_live DB 0Dh, 0Ah, "Synchronizing live configuration...", 0Dh, 0Ah, '$'
msg_cfg_txn_verify DB 0Dh, 0Ah, "Verifying requested configuration...", 0Dh, 0Ah, '$'
msg_cfg_txn_current_active_base DB "Current active I/O base: ", '$'
msg_cfg_txn_current_live_irq DB "Current live IRQ: ", '$'
msg_cfg_txn_new_base DB "Prospective active I/O base: ", '$'
msg_cfg_txn_reachable DB "Adapter reachable at active I/O base: ", '$'

msg_list_hdr    DB  "NIC                            NIC", 0Dh, 0Ah
                DB  "Number                       Description", 0Dh, 0Ah
                DB  "--------------------------------------------------------------------------", 0Dh, 0Ah, '$'

; Original generic NIC description resources.
; Only the ISA 3C509 family selector is reachable in this reduced build.
msg_a02c        DB  "EtherLink III 16-bit ISA NIC", '$'
msg_a02d        DB  "EtherLink III 32-bit EISA NIC", '$'
msg_a02e        DB  "EtherLink III 32-bit MCA NIC", '$'
msg_a0ac        DB  "3Com 3C508 16-bit ISA NIC", '$'

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
msg_indent      DB  "       ", '$'
msg_io          DB  "I/O = ", '$'
msg_irq         DB  ", IRQ = ", '$'
msg_no_io       DB  "unassigned", '$'

msg_asic_label  DB  "ASIC Revision = ", '$'
msg_xcvr_label  DB  "Transceiver = ", '$'
msg_pnp_label   DB  "Plug and Play Capability = ", '$'
msg_boot_label  DB  "Boot ROM = ", '$'
msg_compat_label DB "Software Compatibility = failure level ", '$'
msg_warn_label  DB  ", warning level ", '$'

msg_enabled     DB  "enabled", '$'
msg_disabled    DB  "disabled", '$'
msg_not_supported DB "not supported", '$'
msg_unavailable DB  "unavailable", '$'
msg_invalid_cfg DB  "invalid configuration", '$'
msg_onboard_tp  DB  "on-board TP", '$'
msg_external    DB  "external", '$'
msg_onboard_coax DB "on-board coax", '$'
msg_auto_select DB  "auto select", '$'
msg_unknown_value DB "unknown", '$'
msg_at          DB  "K at ", '$'
msg_hex_suffix  DB  "H", '$'
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

; Temporary live EEPROM values used only by the LIST output.
; These are deliberately separate from nic_table so the known good 16 byte
; enumeration record layout remains unchanged.
ext_addr_cfg      DW 0FFFFh
ext_compatibility DW 0FFFFh
ext_capability    DW 0FFFFh
ext_config_ctrl   DW 0FFFFh
ext_revision_info DW 0FFFFh

; CONFIGURE state.  nic_table itself is deliberately not extended.
cfg_adapter_ordinal   DB 0
cfg_parse_flags       DB 0
cfg_seen_flags        DB 0
cfg_property_count    DB 0
cfg_last_error        DB CFG_ERR_NONE
cfg_timeout_latched   DB 0
cfg_selected_index    DW 0FFFFh
cfg_selected_ptr      DW 0
cfg_options_ptr       DW 0

; Staged property requests.  Handlers write only these values and parse flags.
cfg_int_value         DB 0
cfg_iobase_value      DW 0

; Central CONFIGURE transaction state.  Current state is snapshotted before any
; hardware modification.  Prospective state starts as an exact copy and is then
; modified only by Cfg_Prepare_INT and Cfg_Prepare_IOBASE.
cfg_txn_old_base          DW 0
cfg_txn_new_base          DW 0
cfg_txn_old_word08        DW 0
cfg_txn_new_word08        DW 0
cfg_txn_old_word09        DW 0
cfg_txn_new_word09        DW 0
cfg_txn_old_live06        DW 0
cfg_txn_new_live06        DW 0
cfg_txn_old_live08        DW 0
cfg_txn_new_live08        DW 0
cfg_txn_new_word0f        DW 0
cfg_txn_io_selector       DB 0
cfg_txn_old_io_selector   DB 0
cfg_txn_live_io_selector  DB 0
cfg_txn_old_irq           DB 0
cfg_txn_live_irq          DB 0
cfg_txn_change_flags      DB 0
cfg_txn_checksum          DB 0
cfg_txn_activation_needed DB 0

cfg_wait_start_lo     DW 0
cfg_wait_start_hi     DW 0

; Original CONFIGURE property order is retained for prefix resolution.
; CONFIGPORT is required by the reduced roadmap, but is not an entry in the
; original primary CONFIGURE property table.  It is therefore appended at the
; requested logical position and remains an unreachable hardware stub.
cfg_name_adapternum DB 'ADAPTERNUM', 0
cfg_name_int        DB 'INT', 0
cfg_name_iobase     DB 'IOBASE', 0
cfg_name_baddress   DB 'BADDRESS', 0
cfg_name_bsize      DB 'BSIZE', 0
cfg_name_tr         DB 'TR', 0
cfg_name_xcvr       DB 'XCVR', 0
cfg_name_modem      DB 'MODEM', 0
cfg_name_optimize   DB 'OPTIMIZE', 0
cfg_name_linkbeat   DB 'LINKBEAT', 0
cfg_name_configport DB 'CONFIGPORT', 0
cfg_name_pnp        DB 'PNP', 0
cfg_name_syncready  DB 'SYNCREADY', 0
cfg_name_fullduplex DB 'FULLDUPLEX', 0

cfg_property_names DW OFFSET cfg_name_int
                   DW OFFSET cfg_name_iobase
                   DW OFFSET cfg_name_baddress
                   DW OFFSET cfg_name_bsize
                   DW OFFSET cfg_name_tr
                   DW OFFSET cfg_name_xcvr
                   DW OFFSET cfg_name_modem
                   DW OFFSET cfg_name_optimize
                   DW OFFSET cfg_name_linkbeat
                   DW OFFSET cfg_name_configport
                   DW OFFSET cfg_name_pnp
                   DW OFFSET cfg_name_syncready
                   DW OFFSET cfg_name_fullduplex
                   DW 0

; Canonical dispatch identifiers parallel the table above.
cfg_property_ids DB CFG_OPT_INT
                 DB CFG_OPT_IOBASE
                 DB CFG_OPT_BADDRESS
                 DB CFG_OPT_BSIZE
                 DB CFG_OPT_TR
                 DB CFG_OPT_TR
                 DB CFG_OPT_MODEM
                 DB CFG_OPT_OPTIMIZE
                 DB CFG_OPT_LINKBEAT
                 DB CFG_OPT_CONFIGPORT
                 DB CFG_OPT_PNP
                 DB CFG_OPT_SYNCREADY
                 DB CFG_OPT_FULLDUPLEX

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

    mov     dx, OFFSET msg_banner_prefix
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET VERSION_STRING
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_banner_suffix
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
    cmp     [BYTE si+6], 'U'
    jne     @@Help
    cmp     [BYTE si+7], 'R'
    jne     @@Help
    cmp     [BYTE si+8], 'E'
    jne     @@Help
    mov     al, [si+9]
    or      al, al
    jz      @@Configure
    cmp     al, ' '
    je      @@Configure
    cmp     al, 09h
    jne     @@Help

@@Configure:
    add     si, 9
    call    Cmd_Configure
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
; CONFIGURE command framework
; ============================================================================
; Original references:
;   sub_377, common CONFIGURE property loop
;   sub_548, slash or minus switch parser with required values
;   sub_531, colon or equals value separator
;   sub_530 and sub_271, first matching case insensitive keyword prefix
;   sub_554, ADAPTERNUM validation, confirmed directly in the original EXE
;   sub_535, logical adapter selection
;
; This reduced parser keeps those semantics without importing the original
; argv framework.  Start already uppercases ASCII input, so matching remains
; case insensitive.  /INT is staged during property dispatch and applied once
; after the complete dispatch succeeds.  Every other property remains a stub.
PROC Cmd_Configure NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    mov     [cfg_adapter_ordinal], 0
    mov     [cfg_parse_flags], 0
    mov     [cfg_seen_flags], 0
    mov     [cfg_property_count], 0
    mov     [cfg_last_error], CFG_ERR_NONE
    mov     [cfg_timeout_latched], 0
    mov     [cfg_selected_index], 0FFFFh
    mov     [cfg_selected_ptr], 0
    mov     [cfg_options_ptr], si

    call    Cfg_Parse_Options
    jc      @@Report

    ; Reuse the exact discovery path used by LIST.  No second scanner exists.
    call    Scan_All_3Com_Cards
    cmp     [card_count], 0
    jne     @@HaveNic
    mov     [cfg_last_error], CFG_ERR_NO_NIC
    jmp     @@Report

@@HaveNic:
    call    Cfg_Resolve_Adapter
    jc      @@Report

    mov     si, [cfg_selected_ptr]
    call    Cfg_Revalidate_Selected
    jc      @@Report

    cmp     [cfg_property_count], 0
    jne     @@Dispatch
    mov     [cfg_last_error], CFG_ERR_NO_PROPERTY
    jmp     @@Report

@@Dispatch:
    mov     si, [cfg_options_ptr]
    call    Cfg_Dispatch_Parsed_Properties
    cmp     [cfg_last_error], CFG_ERR_NONE
    jne     @@Report

    ; All supported properties are now committed by one centralized staged
    ; transaction.  Handlers above have only parsed and staged values.
    test    [cfg_parse_flags], CFG_PARSE_HW_MASK
    jz      @@Report
    call    Cfg_Txn_Execute

@@Report:
    mov     al, [cfg_last_error]
    call    Cfg_Report_Error

    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Cmd_Configure

; Parse all tokens so a later invalid switch is not hidden by an earlier stub.
; Input SI points immediately after CONFIGURE.
; Output CF clear on syntactically valid options, CF set with cfg_last_error.
PROC Cfg_Parse_Options NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    di

@@NextToken:
    mov     al, [si]
    cmp     al, ' '
    je      @@SkipWhite
    cmp     al, 09h
    jne     @@TokenStart
@@SkipWhite:
    inc     si
    jmp     @@NextToken

@@TokenStart:
    or      al, al
    jz      @@Success
    cmp     al, '/'
    je      @@HaveIntroducer
    cmp     al, '-'
    jne     @@BadOption

@@HaveIntroducer:
    inc     si

    ; /VERBOSE is a global CONFIGURE diagnostic switch and takes no value.
    ; It affects output only and never changes hardware transaction behavior.
    cmp     [BYTE si], 'V'
    jne     @@RegularOption
    cmp     [BYTE si+1], 'E'
    jne     @@RegularOption
    cmp     [BYTE si+2], 'R'
    jne     @@RegularOption
    cmp     [BYTE si+3], 'B'
    jne     @@RegularOption
    cmp     [BYTE si+4], 'O'
    jne     @@RegularOption
    cmp     [BYTE si+5], 'S'
    jne     @@RegularOption
    cmp     [BYTE si+6], 'E'
    jne     @@RegularOption
    mov     al, [si+7]
    or      al, al
    jz      @@SetVerbose
    cmp     al, ' '
    je      @@SetVerbose
    cmp     al, 09h
    jne     @@RegularOption
@@SetVerbose:
    mov     al, CFG_SEEN_VERBOSE
    call    Cfg_Mark_Seen
    jc      @@DuplicateProperty
    or      [cfg_parse_flags], CFG_PARSE_VERBOSE
    add     si, 7
    jmp     @@NextToken

@@RegularOption:
    mov     bx, si                  ; BX = option name start.
    xor     cx, cx                  ; CX = option name length.

@@FindSeparator:
    mov     al, [si]
    cmp     al, ':'
    je      @@HaveSeparator
    cmp     al, '='
    je      @@HaveSeparator
    or      al, al
    jz      @@MissingValue
    cmp     al, ' '
    je      @@MissingValue
    cmp     al, 09h
    je      @@MissingValue
    inc     si
    inc     cx
    jmp     @@FindSeparator

@@HaveSeparator:
    or      cx, cx
    jz      @@BadOption
    inc     si                     ; SI = value start.
    mov     dx, si                 ; DX = value start.
    xor     di, di                 ; DI = value length.

@@FindValueEnd:
    mov     al, [si]
    or      al, al
    jz      @@ValueReady
    cmp     al, ' '
    je      @@ValueReady
    cmp     al, 09h
    je      @@ValueReady
    inc     si
    inc     di
    jmp     @@FindValueEnd

@@ValueReady:
    or      di, di
    jz      @@MissingValue

    ; ADAPTERNUM is a selector, not a hardware property.
    push    si
    push    cx
    push    di
    mov     si, bx
    mov     di, OFFSET cfg_name_adapternum
    call    Cfg_Match_Name_Prefix
    pop     di
    pop     cx
    pop     si
    jnc     @@AdapterNumber

    ; Match the retained original property order.  XCVR remains the only alias.
    push    si
    push    dx
    push    cx
    mov     si, bx
    call    Cfg_Match_Property
    pop     cx
    pop     dx
    pop     si
    jc      @@BadOption

    ; Strict duplicate tracking applies to supported hardware properties.
    cmp     al, CFG_OPT_INT
    jne     @@CheckSeenIOBase
    mov     al, CFG_SEEN_INT
    call    Cfg_Mark_Seen
    jc      @@DuplicateProperty
    jmp     @@CountProperty
@@CheckSeenIOBase:
    cmp     al, CFG_OPT_IOBASE
    jne     @@CountProperty
    mov     al, CFG_SEEN_IOBASE
    call    Cfg_Mark_Seen
    jc      @@DuplicateProperty
@@CountProperty:
    inc     [cfg_property_count]
    jmp     @@NextToken

@@AdapterNumber:
    mov     al, CFG_SEEN_ADAPTER
    call    Cfg_Mark_Seen
    jc      @@DuplicateProperty
    or      [cfg_parse_flags], CFG_PARSE_ADAPTER

    push    si
    mov     si, dx
    mov     cx, di
    call    Cfg_Parse_Adapter_Number
    pop     si
    jc      @@BadAdapter
    mov     [cfg_adapter_ordinal], al
    jmp     @@NextToken

@@BadOption:
    mov     [cfg_last_error], CFG_ERR_BAD_OPTION
    jmp     @@Fail
@@MissingValue:
    mov     [cfg_last_error], CFG_ERR_MISSING_VALUE
    jmp     @@Fail
@@DuplicateProperty:
    mov     [cfg_last_error], CFG_ERR_DUP_PROPERTY
    jmp     @@Fail
@@BadAdapter:
    mov     [cfg_last_error], CFG_ERR_BAD_ADAPTER
@@Fail:
    pop     di
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    stc
    ret
@@Success:
    pop     di
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    clc
    ret
ENDP Cfg_Parse_Options

; Mark one supported CONFIGURE verb as seen during the first parse pass.
; Input AL = one CFG_SEEN bit.  Carry set means that verb was already seen.
; This state is intentionally separate from cfg_parse_flags so staged state
; continues to mean successfully parsed and accepted property values.
PROC Cfg_Mark_Seen NEAR
    push    bx

    mov     bl, [cfg_seen_flags]
    test    bl, al
    jnz     @@Duplicate
    or      bl, al
    mov     [cfg_seen_flags], bl
    pop     bx
    clc
    ret

@@Duplicate:
    pop     bx
    stc
    ret
ENDP Cfg_Mark_Seen

; Input SI = typed name, CX = typed length, DI = full keyword.
; Carry clear means the typed name is a prefix of the keyword.
PROC Cfg_Match_Name_Prefix NEAR
    push    ax
    push    cx
    push    si
    push    di

    or      cx, cx
    jz      @@No
@@Loop:
    mov     al, [di]
    or      al, al
    jz      @@No
    cmp     al, [si]
    jne     @@No
    inc     si
    inc     di
    loop    @@Loop

    pop     di
    pop     si
    pop     cx
    pop     ax
    clc
    ret
@@No:
    pop     di
    pop     si
    pop     cx
    pop     ax
    stc
    ret
ENDP Cfg_Match_Name_Prefix

; Input SI = typed property name, CX = length.
; Output AL = canonical property ID, carry clear when matched.
PROC Cfg_Match_Property NEAR
    push    bx
    push    cx
    push    dx
    push    di
    push    si

    mov     di, OFFSET cfg_property_names
    xor     bx, bx
@@Next:
    mov     dx, [di]
    or      dx, dx
    jz      @@NoMatch

    push    si
    push    cx
    push    di
    mov     di, dx
    call    Cfg_Match_Name_Prefix
    pop     di
    pop     cx
    pop     si
    jnc     @@Found

    add     di, 2
    inc     bx
    jmp     @@Next

@@Found:
    mov     al, [BYTE bx + cfg_property_ids]
    pop     si
    pop     di
    pop     dx
    pop     cx
    pop     bx
    clc
    ret
@@NoMatch:
    pop     si
    pop     di
    pop     dx
    pop     cx
    pop     bx
    stc
    ret
ENDP Cfg_Match_Property

; Original sub_554 accepts exactly one or two decimal digits, values greater
; than zero, then validates against the detected adapter count.  This helper
; performs only the syntax and zero test.  Range is checked after discovery.
; Input SI = value, CX = value length.  Output AL = ordinal.
PROC Cfg_Parse_Adapter_Number NEAR
    push    bx
    push    cx
    push    si

    cmp     cx, 1
    jb      @@Bad
    cmp     cx, 2
    ja      @@Bad

    xor     ax, ax
    mov     bl, [si]
    cmp     bl, '0'
    jb      @@Bad
    cmp     bl, '9'
    ja      @@Bad
    sub     bl, '0'
    mov     al, bl

    cmp     cx, 1
    je      @@CheckZero
    mov     bl, [si+1]
    cmp     bl, '0'
    jb      @@Bad
    cmp     bl, '9'
    ja      @@Bad
    sub     bl, '0'
    shl     al, 1
    mov     bl, al
    shl     al, 1
    shl     al, 1
    add     al, bl                 ; AL = original digit times 10.
    add     al, [si+1]
    sub     al, '0'

@@CheckZero:
    or      al, al
    jz      @@Bad
    pop     si
    pop     cx
    pop     bx
    clc
    ret
@@Bad:
    pop     si
    pop     cx
    pop     bx
    stc
    ret
ENDP Cfg_Parse_Adapter_Number

; Resolve the selector against the exact nic_table order produced by LIST.
; Original behavior: one NIC defaults to adapter 1, multiple NICs require an
; explicit selector.  cfg_selected_index is zero based, matching sub_535.
PROC Cfg_Resolve_Adapter NEAR
    push    ax
    push    bx
    push    dx

    test    [cfg_parse_flags], CFG_PARSE_ADAPTER
    jnz     @@Explicit
    cmp     [card_count], 1
    jbe     @@DefaultOne
    mov     [cfg_last_error], CFG_ERR_ADAPTER_REQUIRED
    jmp     @@Fail

@@DefaultOne:
    mov     [cfg_adapter_ordinal], 1
@@Explicit:
    xor     ax, ax
    mov     al, [cfg_adapter_ordinal]
    or      ax, ax
    jz      @@Bad
    cmp     ax, [card_count]
    ja      @@Bad

    dec     ax
    mov     [cfg_selected_index], ax
    mov     bx, NIC_RECORD_SIZE
    mul     bx
    add     ax, OFFSET nic_table
    mov     [cfg_selected_ptr], ax

    pop     dx
    pop     bx
    pop     ax
    clc
    ret
@@Bad:
    mov     [cfg_last_error], CFG_ERR_BAD_ADAPTER
@@Fail:
    pop     dx
    pop     bx
    pop     ax
    stc
    ret
ENDP Cfg_Resolve_Adapter

; Rewalk the already validated option text after adapter selection and
; revalidation.  This preserves original style sequential property dispatch
; without storing a second request array.  A handler error stops later handlers,
; matching the original sub_377 loop.  ADAPTERNUM is skipped because it has
; already selected the logical adapter.
PROC Cfg_Dispatch_Parsed_Properties NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    di
    push    si

@@NextToken:
    mov     al, [si]
    cmp     al, ' '
    je      @@SkipWhite
    cmp     al, 09h
    jne     @@TokenStart
@@SkipWhite:
    inc     si
    jmp     @@NextToken

@@TokenStart:
    or      al, al
    jz      @@Done
    inc     si                     ; Syntax was already validated in pass one.

    ; /VERBOSE is global diagnostic state, not a hardware property.
    cmp     [BYTE si], 'V'
    jne     @@RegularProperty
    cmp     [BYTE si+1], 'E'
    jne     @@RegularProperty
    cmp     [BYTE si+2], 'R'
    jne     @@RegularProperty
    cmp     [BYTE si+3], 'B'
    jne     @@RegularProperty
    cmp     [BYTE si+4], 'O'
    jne     @@RegularProperty
    cmp     [BYTE si+5], 'S'
    jne     @@RegularProperty
    cmp     [BYTE si+6], 'E'
    jne     @@RegularProperty
    mov     al, [si+7]
    or      al, al
    jz      @@SkipVerbose
    cmp     al, ' '
    je      @@SkipVerbose
    cmp     al, 09h
    jne     @@RegularProperty
@@SkipVerbose:
    add     si, 7
    jmp     @@NextToken

@@RegularProperty:
    mov     bx, si
    xor     cx, cx
@@FindSeparator:
    mov     al, [si]
    cmp     al, ':'
    je      @@HaveSeparator
    cmp     al, '='
    je      @@HaveSeparator
    inc     si
    inc     cx
    jmp     @@FindSeparator

@@HaveSeparator:
    inc     si
    mov     dx, si
    xor     di, di
@@FindValueEnd:
    mov     al, [si]
    or      al, al
    jz      @@ValueReady
    cmp     al, ' '
    je      @@ValueReady
    cmp     al, 09h
    je      @@ValueReady
    inc     si
    inc     di
    jmp     @@FindValueEnd

@@ValueReady:
    push    si
    push    cx
    push    di
    mov     si, bx
    mov     di, OFFSET cfg_name_adapternum
    call    Cfg_Match_Name_Prefix
    pop     di
    pop     cx
    pop     si
    jnc     @@NextToken

    push    si
    push    dx
    push    cx
    mov     si, bx
    call    Cfg_Match_Property
    pop     cx
    pop     dx
    pop     si
    jc      @@InternalBadOption

    push    si
    mov     si, dx                 ; Handler value pointer.
    mov     cx, di                 ; Handler value length.
    call    Cfg_Dispatch_Property
    pop     si
    cmp     [cfg_last_error], CFG_ERR_NONE
    jne     @@Done
    jmp     @@NextToken

@@InternalBadOption:
    mov     [cfg_last_error], CFG_ERR_BAD_OPTION
@@Done:
    pop     si
    pop     di
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Cfg_Dispatch_Parsed_Properties

; Canonical property dispatcher.  Input AL = property ID, SI = value pointer,
; CX = value length.  XCVR maps to TR before this point.  /PORT is not present
; in the parser.  /INT and /IOBASE stage validated values only.
PROC Cfg_Dispatch_Property NEAR
    cmp     al, CFG_OPT_INT
    jne     @@IOBase
    call    Cfg_Handle_INT
    ret
@@IOBase:
    cmp     al, CFG_OPT_IOBASE
    jne     @@BAddress
    call    Cfg_Handle_IOBASE
    ret
@@BAddress:
    cmp     al, CFG_OPT_BADDRESS
    jne     @@BSize
    call    Cfg_Handle_BADDRESS
    ret
@@BSize:
    cmp     al, CFG_OPT_BSIZE
    jne     @@TR
    call    Cfg_Handle_BSIZE
    ret
@@TR:
    cmp     al, CFG_OPT_TR
    jne     @@Modem
    call    Cfg_Handle_TR
    ret
@@Modem:
    cmp     al, CFG_OPT_MODEM
    jne     @@Optimize
    call    Cfg_Handle_MODEM
    ret
@@Optimize:
    cmp     al, CFG_OPT_OPTIMIZE
    jne     @@LinkBeat
    call    Cfg_Handle_OPTIMIZE
    ret
@@LinkBeat:
    cmp     al, CFG_OPT_LINKBEAT
    jne     @@ConfigPort
    call    Cfg_Handle_LINKBEAT
    ret
@@ConfigPort:
    cmp     al, CFG_OPT_CONFIGPORT
    jne     @@PnP
    call    Cfg_Handle_CONFIGPORT
    ret
@@PnP:
    cmp     al, CFG_OPT_PNP
    jne     @@SyncReady
    call    Cfg_Handle_PNP
    ret
@@SyncReady:
    cmp     al, CFG_OPT_SYNCREADY
    jne     @@FullDuplex
    call    Cfg_Handle_SYNCREADY
    ret
@@FullDuplex:
    cmp     al, CFG_OPT_FULLDUPLEX
    jne     @@Bad
    call    Cfg_Handle_FULLDUPLEX
    ret
@@Bad:
    mov     [cfg_last_error], CFG_ERR_BAD_OPTION
    ret
ENDP Cfg_Dispatch_Property

; Property handler entry points receive SI = value pointer and CX = value length.
; /INT preserves the hardware tested validation body and only stages its final
; accepted value.  /IOBASE likewise parses and stages only.  Neither handler
; performs hardware access.  Remaining property handlers are stubs.
; Input SI = /INT value pointer, CX = value length.
; Accepted canonical decimal forms are exactly:
;   3, 5, 7, 9, 10, 11, 12, 15
PROC Cfg_Handle_INT NEAR
    push    ax
    push    bx
    push    dx

    cmp     cx, 1
    je      @@OneDigit
    cmp     cx, 2
    je      @@TwoDigits
    jmp     @@Invalid

@@OneDigit:
    mov     al, [si]
    cmp     al, '3'
    je      @@StoreOne
    cmp     al, '5'
    je      @@StoreOne
    cmp     al, '7'
    je      @@StoreOne
    cmp     al, '9'
    je      @@StoreOne
    jmp     @@Invalid

@@StoreOne:
    sub     al, '0'
    jmp     @@Accepted

@@TwoDigits:
    mov     al, [si]
    cmp     al, '1'
    jne     @@Invalid
    mov     al, [si+1]
    cmp     al, '0'
    je      @@TenToTwelve
    cmp     al, '1'
    je      @@TenToTwelve
    cmp     al, '2'
    je      @@TenToTwelve
    cmp     al, '5'
    jne     @@Invalid
    mov     al, 15
    jmp     @@Accepted

@@TenToTwelve:
    sub     al, '0'
    add     al, 10

@@Accepted:
    mov     [cfg_int_value], al
    or      [cfg_parse_flags], CFG_PARSE_INT
    mov     [cfg_last_error], CFG_ERR_NONE
    jmp     @@Done

@@Invalid:
    mov     [cfg_last_error], CFG_ERR_BAD_INT

@@Done:
    pop     dx
    pop     bx
    pop     ax
    ret
ENDP Cfg_Handle_INT

; Parse the original command line IOBASE numeric form.  Original loc_2598 uses
; the runtime %X conversion, followed by a 0200h through 03E0h range test and a
; division by 10h requiring zero remainder.  Start uppercases the command line,
; so hexadecimal digits and the optional 0X prefix are case insensitive here.
; As with scanf %X, conversion stops after a valid hexadecimal prefix, therefore
; a trailing non hexadecimal suffix is ignored after at least one digit.
; Input SI = value pointer, CX = token length.  Output AX = parsed value.
PROC Cfg_Parse_IOBASE_Hex NEAR
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    xor     ax, ax
    xor     di, di                 ; DI = number of converted hex digits.
    or      cx, cx
    jz      @@Bad

    ; scanf integer conversions accept an optional plus sign.  A minus sign can
    ; never produce a valid selectable 0200h through 03E0h value, so reject it.
    cmp     [BYTE si], '+'
    jne     @@CheckMinus
    inc     si
    dec     cx
    jz      @@Bad
@@CheckMinus:
    cmp     [BYTE si], '-'
    je      @@Bad

    ; Optional C style hexadecimal prefix accepted by %X.
    cmp     cx, 2
    jb      @@Digits
    cmp     [BYTE si], '0'
    jne     @@Digits
    cmp     [BYTE si+1], 'X'
    jne     @@Digits
    add     si, 2
    sub     cx, 2
    jz      @@Bad

@@Digits:
    or      cx, cx
    jz      @@Converted
    mov     bl, [si]
    xor     bh, bh
    cmp     bl, '0'
    jb      @@Converted
    cmp     bl, '9'
    jbe     @@DecimalDigit
    cmp     bl, 'A'
    jb      @@Converted
    cmp     bl, 'F'
    ja      @@Converted
    sub     bl, 37h
    jmp     @@HaveDigit
@@DecimalDigit:
    sub     bl, '0'
@@HaveDigit:
    ; Prevent a long hexadecimal token from wrapping into the valid ISA range.
    cmp     ax, 0FFFh
    ja      @@Bad
    shl     ax, 1
    shl     ax, 1
    shl     ax, 1
    shl     ax, 1
    add     ax, bx
    inc     di
    inc     si
    dec     cx
    jmp     @@Digits

@@Converted:
    or      di, di
    jz      @@Bad
    cmp     ax, 0200h
    jb      @@Bad
    cmp     ax, 03E0h
    ja      @@Bad
    mov     bx, ax
    and     bx, 000Fh
    jnz     @@Bad

    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    clc
    ret
@@Bad:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    stc
    ret
ENDP Cfg_Parse_IOBASE_Hex

PROC Cfg_Handle_IOBASE NEAR
    push    ax

    call    Cfg_Parse_IOBASE_Hex
    jc      @@Invalid
    mov     [cfg_iobase_value], ax
    or      [cfg_parse_flags], CFG_PARSE_IOBASE
    mov     [cfg_last_error], CFG_ERR_NONE
    jmp     @@Done
@@Invalid:
    mov     [cfg_last_error], CFG_ERR_BAD_IOBASE
@@Done:
    pop     ax
    ret
ENDP Cfg_Handle_IOBASE

PROC Cfg_Handle_BADDRESS NEAR
    mov     [cfg_last_error], CFG_ERR_NOT_IMPLEMENTED
    ret
ENDP Cfg_Handle_BADDRESS

PROC Cfg_Handle_BSIZE NEAR
    mov     [cfg_last_error], CFG_ERR_NOT_IMPLEMENTED
    ret
ENDP Cfg_Handle_BSIZE

PROC Cfg_Handle_TR NEAR
    mov     [cfg_last_error], CFG_ERR_NOT_IMPLEMENTED
    ret
ENDP Cfg_Handle_TR

PROC Cfg_Handle_MODEM NEAR
    mov     [cfg_last_error], CFG_ERR_NOT_IMPLEMENTED
    ret
ENDP Cfg_Handle_MODEM

PROC Cfg_Handle_OPTIMIZE NEAR
    mov     [cfg_last_error], CFG_ERR_NOT_IMPLEMENTED
    ret
ENDP Cfg_Handle_OPTIMIZE

PROC Cfg_Handle_LINKBEAT NEAR
    mov     [cfg_last_error], CFG_ERR_NOT_IMPLEMENTED
    ret
ENDP Cfg_Handle_LINKBEAT

PROC Cfg_Handle_CONFIGPORT NEAR
    mov     [cfg_last_error], CFG_ERR_NOT_IMPLEMENTED
    ret
ENDP Cfg_Handle_CONFIGPORT

PROC Cfg_Handle_PNP NEAR
    mov     [cfg_last_error], CFG_ERR_NOT_IMPLEMENTED
    ret
ENDP Cfg_Handle_PNP

PROC Cfg_Handle_SYNCREADY NEAR
    mov     [cfg_last_error], CFG_ERR_NOT_IMPLEMENTED
    ret
ENDP Cfg_Handle_SYNCREADY

PROC Cfg_Handle_FULLDUPLEX NEAR
    mov     [cfg_last_error], CFG_ERR_NOT_IMPLEMENTED
    ret
ENDP Cfg_Handle_FULLDUPLEX

PROC Cfg_Report_Error NEAR
    push    ax
    push    dx

    or      al, al
    jz      @@Done
    cmp     al, CFG_ERR_NO_NIC
    jne     @@E2
    mov     dx, OFFSET msg_no_cards
    jmp     @@Print
@@E2:
    cmp     al, CFG_ERR_BAD_ADAPTER
    jne     @@E3
    mov     dx, OFFSET msg_cfg_bad_adapter
    jmp     @@Print
@@E3:
    cmp     al, CFG_ERR_REVALIDATE
    jne     @@E4
    mov     dx, OFFSET msg_cfg_revalidate
    jmp     @@Print
@@E4:
    cmp     al, CFG_ERR_UNSUPPORTED_PRODUCT
    jne     @@E5
    mov     dx, OFFSET msg_cfg_unsupported_product
    jmp     @@Print
@@E5:
    cmp     al, CFG_ERR_UNSUPPORTED_ASIC
    jne     @@E6
    mov     dx, OFFSET msg_cfg_unsupported_asic
    jmp     @@Print
@@E6:
    cmp     al, CFG_ERR_EEPROM_TIMEOUT
    jne     @@E7
    mov     dx, OFFSET msg_cfg_eeprom_timeout
    jmp     @@Print
@@E7:
    cmp     al, CFG_ERR_COMMAND_TIMEOUT
    jne     @@E8
    mov     dx, OFFSET msg_cfg_command_timeout
    jmp     @@Print
@@E8:
    cmp     al, CFG_ERR_BAD_OPTION
    jne     @@E9
    mov     dx, OFFSET msg_cfg_bad_option
    jmp     @@Print
@@E9:
    cmp     al, CFG_ERR_MISSING_VALUE
    jne     @@E10
    mov     dx, OFFSET msg_cfg_missing_value
    jmp     @@Print
@@E10:
    cmp     al, CFG_ERR_NOT_IMPLEMENTED
    jne     @@E11
    mov     dx, OFFSET msg_cfg_not_implemented
    jmp     @@Print
@@E11:
    cmp     al, CFG_ERR_ADAPTER_REQUIRED
    jne     @@E12
    mov     dx, OFFSET msg_cfg_need_adapter
    jmp     @@Print
@@E12:
    cmp     al, CFG_ERR_DUP_PROPERTY
    jne     @@E13
    mov     dx, OFFSET msg_cfg_dup_property
    jmp     @@Print
@@E13:
    cmp     al, CFG_ERR_NO_PROPERTY
    jne     @@E14
    mov     dx, OFFSET msg_cfg_no_property
    jmp     @@Print
@@E14:
    cmp     al, CFG_ERR_BAD_INT
    jne     @@E15
    mov     dx, OFFSET msg_cfg_bad_int
    jmp     @@Print
@@E15:
    cmp     al, CFG_ERR_EEPROM_READ
    jne     @@E16
    mov     dx, OFFSET msg_cfg_eeprom_read_fail
    jmp     @@Print
@@E16:
    cmp     al, CFG_ERR_EEPROM_WRITE
    jne     @@E17
    mov     dx, OFFSET msg_cfg_eeprom_write_fail
    jmp     @@Print
@@E17:
    cmp     al, CFG_ERR_CHECKSUM_UPDATE
    jne     @@E18
    mov     dx, OFFSET msg_cfg_checksum_fail
    jmp     @@Print
@@E18:
    cmp     al, CFG_ERR_LIVE_UPDATE
    jne     @@E19
    mov     dx, OFFSET msg_cfg_live_fail
    jmp     @@Print
@@E19:
    cmp     al, CFG_ERR_VERIFY
    jne     @@E20
    mov     dx, OFFSET msg_cfg_verify_fail
    jmp     @@Print
@@E20:
    cmp     al, CFG_ERR_INT_INACTIVE
    jne     @@E21
    mov     dx, OFFSET msg_cfg_int_inactive
    jmp     @@Print
@@E21:
    cmp     al, CFG_ERR_BAD_IOBASE
    jne     @@E22
    mov     dx, OFFSET msg_cfg_bad_iobase
    jmp     @@Print
@@E22:
    cmp     al, CFG_ERR_IOBASE_INACTIVE
    jne     @@E23
    mov     dx, OFFSET msg_cfg_iobase_inactive
    jmp     @@Print
@@E23:
    cmp     al, CFG_ERR_IOBASE_CONFLICT
    jne     @@E24
    mov     dx, OFFSET msg_cfg_iobase_conflict
    jmp     @@Print
@@E24:
    cmp     al, CFG_ERR_IOBASE_DEACTIVATE
    jne     @@E25
    mov     dx, OFFSET msg_cfg_iobase_deactivate_fail
    jmp     @@Print
@@E25:
    cmp     al, CFG_ERR_IOBASE_REACTIVATE
    jne     @@E26
    mov     dx, OFFSET msg_cfg_iobase_reactivate_fail
    jmp     @@Print
@@E26:
    cmp     al, CFG_ERR_IOBASE_EEPROM_READ
    jne     @@E27
    mov     dx, OFFSET msg_cfg_iobase_eeprom_read_fail
    jmp     @@Print
@@E27:
    cmp     al, CFG_ERR_IOBASE_EEPROM_WRITE
    jne     @@E28
    mov     dx, OFFSET msg_cfg_iobase_eeprom_write_fail
    jmp     @@Print
@@E28:
    cmp     al, CFG_ERR_IOBASE_LIVE
    jne     @@E29
    mov     dx, OFFSET msg_cfg_iobase_live_fail
    jmp     @@Print
@@E29:
    cmp     al, CFG_ERR_IOBASE_VERIFY
    jne     @@E30
    mov     dx, OFFSET msg_cfg_iobase_verify_fail
    jmp     @@Print
@@E30:
    cmp     al, CFG_ERR_IOBASE_ACTIVATE
    jne     @@Done
    mov     dx, OFFSET msg_cfg_iobase_activate_fail
@@Print:
    mov     ah, 09h
    int     21h
@@Done:
    pop     dx
    pop     ax
    ret
ENDP Cfg_Report_Error

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
    ; Keep the first line on the same proven path as the hardware tested build.
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

    ; The original 9850h description is always 3C509B TPCoax.
    mov     ax, [WORD si + NIC_PRODUCT_ID]
    cmp     ax, PRODUCT_3C509_TPC
    je      @@ModelB

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

    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    ; Original generic NIC description line.
    mov     dx, OFFSET msg_indent
    mov     ah, 09h
    int     21h
    mov     ax, [WORD si + NIC_PRODUCT_ID]
    call    Select_Nic_Description
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    ; I/O and IRQ line.
    mov     dx, OFFSET msg_indent
    mov     ah, 09h
    int     21h
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

    ; Read and print the additional metrics only after enumeration is complete.
    ; This cannot alter the ID port contention or the 16 byte NIC record layout.
    call    Read_Extended_Nic_Info
    call    Print_Extended_Nic_Info

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
; Common CONFIGURE hardware infrastructure.  Release 0.4 exposes only the
; original resources required by the deferred /INT transaction.
; ============================================================================

; Word register read, original sub_306.
; Input DX = adapter base, BX = register offset.  Output AX = word.
PROC Cfg_Reg_Read_Word NEAR
    push    dx
    add     dx, bx
    in      ax, dx
    pop     dx
    ret
ENDP Cfg_Reg_Read_Word

; Word register write, original sub_308.
; Input DX = adapter base, BX = register offset, AX = value.
PROC Cfg_Reg_Write_Word NEAR
    push    dx
    add     dx, bx
    out     dx, ax
    pop     dx
    ret
ENDP Cfg_Reg_Write_Word

; Byte register write, original sub_309.
; Input DX = adapter base, BX = register offset, AL = value.
PROC Cfg_Reg_Write_Byte NEAR
    push    dx
    add     dx, bx
    out     dx, al
    pop     dx
    ret
ENDP Cfg_Reg_Write_Byte

; Reduced replacement for the original sub_139 timing dependency.  The original
; result is an absolute count in seconds.  Busy waits only compare a delta of
; at most two seconds, so seconds since midnight plus wrap correction preserves
; the relevant behavior without importing calendar conversion routines.
; Output DX:AX = seconds since midnight.
PROC Cfg_Get_Time_Seconds NEAR
    push    bx
    push    cx
    push    si
    push    di

    mov     ah, 2Ch
    int     21h
    push    dx                     ; BH after pop below will contain seconds.

    xor     ax, ax
    mov     al, ch
    mov     bx, 3600
    mul     bx
    mov     si, ax
    mov     di, dx

    xor     ax, ax
    mov     al, cl
    mov     bx, 60
    mul     bx
    add     si, ax
    adc     di, dx

    pop     bx
    xor     ax, ax
    mov     al, bh
    add     si, ax
    adc     di, 0

    mov     ax, si
    mov     dx, di

    pop     di
    pop     si
    pop     cx
    pop     bx
    ret
ENDP Cfg_Get_Time_Seconds

; Save the current second counter for the original greater than one second
; timeout test shared by command and EEPROM polling.
PROC Cfg_Start_Wait_Timer NEAR
    push    ax
    push    dx
    call    Cfg_Get_Time_Seconds
    mov     [cfg_wait_start_lo], ax
    mov     [cfg_wait_start_hi], dx
    pop     dx
    pop     ax
    ret
ENDP Cfg_Start_Wait_Timer

; Return carry set when more than one elapsed second has passed.
PROC Cfg_Wait_Expired NEAR
    push    ax
    push    dx

    call    Cfg_Get_Time_Seconds
    sub     ax, [cfg_wait_start_lo]
    sbb     dx, [cfg_wait_start_hi]
    jnc     @@Compare

    ; Midnight wrap.  86400 decimal = 0001:5180h.
    add     ax, 05180h
    adc     dx, 1

@@Compare:
    cmp     dx, 0
    ja      @@Expired
    cmp     ax, 1
    ja      @@Expired

    pop     dx
    pop     ax
    clc
    ret
@@Expired:
    pop     dx
    pop     ax
    stc
    ret
ENDP Cfg_Wait_Expired

; Original sub_310 waits for command IDs 5, 8 and 0Bh by polling status bit
; 1000h until clear or until elapsed time is greater than one second.
; Input DX = adapter base.  Output carry set on timeout.
PROC Cfg_Wait_Command_Ready NEAR
    push    ax
    push    bx

    call    Cfg_Start_Wait_Timer
@@Loop:
    mov     bx, EL3_STATUS
    call    Cfg_Reg_Read_Word
    test    ax, STATUS_CMD_BUSY
    jz      @@Ready
    call    Cfg_Wait_Expired
    jnc     @@Loop

    mov     [cfg_timeout_latched], 1
    mov     [cfg_last_error], CFG_ERR_COMMAND_TIMEOUT
    pop     bx
    pop     ax
    stc
    ret
@@Ready:
    pop     bx
    pop     ax
    clc
    ret
ENDP Cfg_Wait_Command_Ready

; Test the exact product family used by the original ISA CONFIGURE helpers.
; Input AX = product ID.  Carry clear means F0FFh masked value is 9050h.
PROC Cfg_Is_Supported_Product NEAR
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
ENDP Cfg_Is_Supported_Product

; Original sub_313 hardware test.  Input AX = exact product ID, BL = ASIC
; revision.  Carry clear means original early 3C509 behavior, revision below 2
; and product family 9050h.  No 3C508 classification is present.
PROC Cfg_Is_Original_3C509 NEAR
    push    ax
    call    Cfg_Is_Supported_Product
    jc      @@No
    cmp     bl, 2
    jae     @@No
    pop     ax
    clc
    ret
@@No:
    pop     ax
    stc
    ret
ENDP Cfg_Is_Original_3C509

; Later 3C509B class for future restrictions.  Input AX product, BL revision.
PROC Cfg_Is_Later_3C509B NEAR
    push    ax
    call    Cfg_Is_Supported_Product
    jc      @@No
    cmp     bl, 2
    jb      @@No
    pop     ax
    clc
    ret
@@No:
    pop     ax
    stc
    ret
ENDP Cfg_Is_Later_3C509B

; Read live product and ASIC revision while restoring the caller's window.
; This maps the useful part of original sub_313 to the existing verified
; Check_3Com_Signature routine.  Input DX = adapter base.
; Output AX = product ID, BL = ASIC revision, carry clear on success.
PROC Cfg_Read_Product_Revision NEAR
    call    Check_3Com_Signature
    ret
ENDP Cfg_Read_Product_Revision

; Original sub_310 command issue helper.  Input DX = base, AX = command ID,
; BX = argument.  Command zero uses the original early 3C509 byte write to
; offset 0Fh.  Other commands encode command ID in bits 15 to 11.
PROC Cfg_Issue_Command NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    mov     si, ax                 ; SI = command ID.
    mov     di, bx                 ; DI = argument.
    or      si, si
    jnz     @@Normal

    ; The original sub_310 operates on the already selected global base.
    ; Here DX is that explicit base, so no record lookup is required.
    or      dx, dx
    jz      @@Normal
    call    Cfg_Read_Product_Revision
    jc      @@Normal
    call    Cfg_Is_Original_3C509
    jc      @@Normal

    xor     al, al
    mov     bx, 0Fh
    call    Cfg_Reg_Write_Byte
    jmp     @@MaybeWait

@@Normal:
    mov     ax, si
    mov     cl, 11
    shl     ax, cl
    or      ax, di
    mov     bx, EL3_COMMAND
    call    Cfg_Reg_Write_Word

@@MaybeWait:
    cmp     si, 5
    je      @@Wait
    cmp     si, 8
    je      @@Wait
    cmp     si, 0Bh
    jne     @@Done
@@Wait:
    call    Cfg_Wait_Command_Ready
    jc      @@Timeout
@@Done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    clc
    ret
@@Timeout:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    stc
    ret
ENDP Cfg_Issue_Command

; EEPROM busy wait shared by original sub_314 and sub_315.
; Input DX = adapter base.  Carry set on timeout.
PROC Cfg_Eeprom_Wait_Ready NEAR
    push    ax
    push    bx

    call    Cfg_Start_Wait_Timer
@@Loop:
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Cfg_Reg_Read_Word
    test    ax, EEPROM_BUSY
    jz      @@Ready
    call    Cfg_Wait_Expired
    jnc     @@Loop

    mov     [cfg_timeout_latched], 1
    mov     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    pop     bx
    pop     ax
    stc
    ret
@@Ready:
    pop     bx
    pop     ax
    clc
    ret
ENDP Cfg_Eeprom_Wait_Ready

; EEPROM word read, original sub_314.  Input DX = base, AL = word number.
; The routine selects window 0 and intentionally does not restore the previous
; window, matching the original.  AX contains the data word.  Carry exposes the
; original latched timeout state to reduced callers.
PROC Cfg_Eeprom_Read NEAR
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    cmp     [cfg_timeout_latched], 0
    je      @@Start
    xor     ax, ax
    mov     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    jmp     @@Fail

@@Start:
    xor     ah, ah
    mov     si, ax
    xor     al, al
    call    Select_Window

    mov     ax, si
    or      ax, 0080h
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Cfg_Reg_Write_Word
    call    Cfg_Eeprom_Wait_Ready

    mov     bx, EL3_W0_EEPROM_DATA
    call    Cfg_Reg_Read_Word
    cmp     [cfg_timeout_latched], 0
    jne     @@Fail

    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    clc
    ret
@@Fail:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    stc
    ret
ENDP Cfg_Eeprom_Read

; EEPROM word write, original sub_315, confirmed independently in 3CCFG.EXE.
; Input DX = base, AL = word number, BX = data word.
; Exact command sequence:
;   window 0, 0030h, wait, 00C0h OR word, wait, write data,
;   0030h, wait, 0040h OR word, wait.
; The original continues through the sequence after a timeout, so this helper
; does the same and returns the shared timeout latch in carry at the end.
; Release 0.3.4 reaches this procedure from the centralized CONFIGURE transaction.
PROC Cfg_Eeprom_Write NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    xor     ah, ah
    mov     si, ax                 ; SI = EEPROM word number.
    mov     di, bx                 ; DI = data word.

    xor     al, al
    call    Select_Window

    mov     ax, 0030h
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Cfg_Reg_Write_Word
    call    Cfg_Eeprom_Wait_Ready

    mov     ax, 00C0h
    or      ax, si
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Cfg_Reg_Write_Word
    call    Cfg_Eeprom_Wait_Ready

    mov     ax, di
    mov     bx, EL3_W0_EEPROM_DATA
    call    Cfg_Reg_Write_Word

    mov     ax, 0030h
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Cfg_Reg_Write_Word
    call    Cfg_Eeprom_Wait_Ready

    mov     ax, 0040h
    or      ax, si
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Cfg_Reg_Write_Word
    call    Cfg_Eeprom_Wait_Ready

    cmp     [cfg_timeout_latched], 0
    jne     @@Fail
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    clc
    ret
@@Fail:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    stc
    ret
ENDP Cfg_Eeprom_Write

; XOR one EEPROM word into BL, both low byte and high byte.
; Input AX = EEPROM word, BL = current checksum.  Output BL updated.
PROC Cfg_Checksum_Xor_Word NEAR
    xor     bl, al
    xor     bl, ah
    ret
ENDP Cfg_Checksum_Xor_Word

; Original sub_316, destination EEPROM word 0Fh high byte.
; Domain: words 00h through 0Eh, excluding 08h, 09h and 0Dh.
; Input DX = base.  Output AL = checksum, carry set on EEPROM timeout.
PROC Cfg_Checksum_0F_High NEAR
    push    bx
    push    cx
    push    dx
    push    si

    xor     bx, bx
    xor     si, si
@@Loop:
    cmp     si, 8
    je      @@Next
    cmp     si, 9
    je      @@Next
    cmp     si, 0Dh
    je      @@Next
    mov     ax, si
    call    Cfg_Eeprom_Read
    jc      @@Fail
    call    Cfg_Checksum_Xor_Word
@@Next:
    inc     si
    cmp     si, 0Eh
    jbe     @@Loop
    mov     al, bl
    pop     si
    pop     dx
    pop     cx
    pop     bx
    clc
    ret
@@Fail:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    stc
    ret
ENDP Cfg_Checksum_0F_High

; Original sub_317, destination EEPROM word 0Fh low byte.
; Domain: words 08h through 0Dh, excluding 0Ah through 0Ch.
PROC Cfg_Checksum_0F_Low NEAR
    push    bx
    push    cx
    push    dx
    push    si

    xor     bx, bx
    mov     si, 8
@@Loop:
    cmp     si, 0Ah
    jb      @@Read
    cmp     si, 0Ch
    jbe     @@Next
@@Read:
    mov     ax, si
    call    Cfg_Eeprom_Read
    jc      @@Fail
    call    Cfg_Checksum_Xor_Word
@@Next:
    inc     si
    cmp     si, 0Dh
    jbe     @@Loop
    mov     al, bl
    pop     si
    pop     dx
    pop     cx
    pop     bx
    clc
    ret
@@Fail:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    stc
    ret
ENDP Cfg_Checksum_0F_Low

; ============================================================================
; /IOBASE hardware transaction, release 0.3.4
; ============================================================================
; Original authorities:
;   loc_2590 through loc_2605, command line IOBASE parser and staging
;   sub_335, selected ISA adapter deactivation and retag preparation
;   sub_334, D8h plus tag and E0h plus selector activation at the new base
;   sub_342, EEPROM word 08h, optional word 09h, sub_317 checksum, then live
;            window 0 Address Configuration 06h and Resource Configuration 08h
;
; The critical original ordering is intentionally retained: a tagged ISA card
; is deactivated and reactivated at the requested base before sub_342 performs
; the persistent EEPROM writes.  The record I O base is therefore changed only
; immediately before Cfg_Id_Activate_Selected emits the E0h activation command.
; No rollback sequence is invented after that point.
;
; Pure selector decoder.  Input AL = selector.  Output AX = base, zero for 1Fh.
PROC Cfg_IOBASE_Selector_To_Base NEAR
    push    cx
    xor     ah, ah
    and     ax, 001Fh
    cmp     ax, 001Fh
    je      @@Unassigned
    mov     cl, 4
    shl     ax, cl
    add     ax, 0200h
    pop     cx
    ret
@@Unassigned:
    xor     ax, ax
    pop     cx
    ret
ENDP Cfg_IOBASE_Selector_To_Base

; Read only conflict guard.  The original full utility has resource manager
; conflict processing which is not retained here.  This reduced build never
; changes another NIC merely to free an address.  Carry set means another LIST
; record already occupies cfg_iobase_value.
PROC Cfg_IOBASE_Check_Conflict NEAR
    push    ax
    push    cx
    push    dx
    push    si
    push    di

    mov     dx, [cfg_iobase_value]
    mov     di, [cfg_selected_ptr]
    mov     cx, [card_count]
    mov     si, OFFSET nic_table
@@Loop:
    or      cx, cx
    jz      @@Clear
    cmp     si, di
    je      @@Next
    cmp     [WORD si + NIC_IO_BASE], dx
    je      @@Conflict
@@Next:
    add     si, NIC_RECORD_SIZE
    dec     cx
    jmp     @@Loop
@@Clear:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     ax
    clc
    ret
@@Conflict:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     ax
    stc
    ret
ENDP Cfg_IOBASE_Check_Conflict

; ============================================================================
; Central staged CONFIGURE transaction facility, release 0.3.4
; ============================================================================
;
; Property handlers only parse and stage values.  The routines below snapshot
; current hardware state, initialize a prospective image, merge requested
; properties into that image, detect changes, perform any required activation or
; I O migration, write changed EEPROM words, update the checksum once, synchronize
; live registers and verify every property that was actually committed.
;
; No property owns another property's transaction logic.

; Carry clear when the selected record has a safe proprietary ISA ID tag.
PROC Cfg_Txn_Has_Valid_Tag NEAR
    push    ax
    push    si

    mov     si, [cfg_selected_ptr]
    test    [BYTE si + NIC_FLAGS], NIC_FLAG_FROM_ID
    jz      @@Bad
    mov     al, [BYTE si + NIC_TAG]
    or      al, al
    jz      @@Bad
    cmp     al, 7
    ja      @@Bad

    pop     si
    pop     ax
    clc
    ret
@@Bad:
    pop     si
    pop     ax
    stc
    ret
ENDP Cfg_Txn_Has_Valid_Tag

; Original sub_335 continuation used by both the tested INT path and IOBASE
; migration.  Reenter ID state and restore the selected tag after deactivation.
PROC Cfg_Txn_Retag_Selected NEAR
    push    ax
    push    dx
    push    si

    call    IdPort_Eeprom_Delay
    call    IdPort_Eeprom_Delay
    call    IdPort_Eeprom_Delay
    call    IdPort_Eeprom_Delay
    call    IdPort_Eeprom_Delay
    call    IdPort_Eeprom_Delay
    call    IdPort_Eeprom_Delay
    call    IdPort_Eeprom_Delay

    mov     si, [cfg_selected_ptr]
    cli
    cmp     [BYTE si + NIC_ID_MODE], 0
    je      @@Full
    call    IdPort_Send_Short_Sequence
    jmp     @@WriteTag
@@Full:
    call    IdPort_Send_Full_Sequence
@@WriteTag:
    mov     dx, ID_PORT
    mov     al, ID_CMD_SET_TAG
    or      al, [BYTE si + NIC_TAG]
    out     dx, al
    sti

    pop     si
    pop     dx
    pop     ax
    ret
ENDP Cfg_Txn_Retag_Selected

; Snapshot current state required by all presently implemented properties.
; No hardware modification occurs here.
PROC Cfg_Txn_Read_Current NEAR
    push    ax
    push    bx
    push    dx
    push    si

    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    or      dx, dx
    jnz     @@HaveBase
    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jz      @@InactiveINT
    mov     [cfg_last_error], CFG_ERR_IOBASE_INACTIVE
    jmp     @@Fail
@@InactiveINT:
    mov     [cfg_last_error], CFG_ERR_INT_INACTIVE
    jmp     @@Fail

@@HaveBase:
    mov     [cfg_txn_old_base], dx
    mov     [cfg_txn_new_base], dx

    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jz      @@NoWord08
    mov     al, EEPROM_ADDR_CFG
    call    Cfg_Eeprom_Read
    jc      @@ReadIOFail
    mov     [cfg_txn_old_word08], ax
    jmp     @@Word08Done
@@NoWord08:
    mov     [cfg_txn_old_word08], 0
@@Word08Done:

    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@NoWord09
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_RESOURCE_CFG
    call    Cfg_Eeprom_Read
    jc      @@ReadINTFail
    mov     [cfg_txn_old_word09], ax
    jmp     @@Word09Done
@@NoWord09:
    mov     [cfg_txn_old_word09], 0
@@Word09Done:

    ; Both live words are required because original ISA reactivation restores
    ; Address Configuration and Resource Configuration together.
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    xor     al, al
    call    Select_Window
    mov     bx, EL3_W0_ADDRESS_CFG
    call    Cfg_Reg_Read_Word
    mov     [cfg_txn_old_live06], ax
    mov     bx, EL3_W0_RESOURCE_CFG
    call    Cfg_Reg_Read_Word
    mov     [cfg_txn_old_live08], ax

    mov     ax, [cfg_txn_old_word08]
    and     al, 01Fh
    mov     [cfg_txn_old_io_selector], al
    mov     ax, [cfg_txn_old_live06]
    and     al, 01Fh
    mov     [cfg_txn_live_io_selector], al

    mov     ax, [cfg_txn_old_word09]
    mov     bx, ax
    mov     cl, 12
    shr     bx, cl
    and     bl, 0Fh
    mov     [cfg_txn_old_irq], bl

    mov     ax, [cfg_txn_old_live08]
    mov     bx, ax
    mov     cl, 12
    shr     bx, cl
    and     bl, 0Fh
    mov     [cfg_txn_live_irq], bl

    pop     si
    pop     dx
    pop     bx
    pop     ax
    clc
    ret

@@ReadIOFail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_IOBASE_EEPROM_READ
    jmp     @@Fail
@@ReadINTFail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_EEPROM_READ
@@Fail:
    pop     si
    pop     dx
    pop     bx
    pop     ax
    stc
    ret
ENDP Cfg_Txn_Read_Current

; Prospective state always begins as an exact copy of the snapshot.
PROC Cfg_Txn_Init_Prospective NEAR
    push    ax

    mov     ax, [cfg_txn_old_word08]
    mov     [cfg_txn_new_word08], ax
    mov     ax, [cfg_txn_old_word09]
    mov     [cfg_txn_new_word09], ax
    mov     ax, [cfg_txn_old_live06]
    mov     [cfg_txn_new_live06], ax
    mov     ax, [cfg_txn_old_live08]
    mov     [cfg_txn_new_live08], ax
    mov     ax, [cfg_txn_old_base]
    mov     [cfg_txn_new_base], ax
    mov     [cfg_txn_change_flags], 0
    mov     [cfg_txn_activation_needed], 0

    pop     ax
    ret
ENDP Cfg_Txn_Init_Prospective

; Merge only the staged IOBASE field into the prospective state.
; No hardware access is permitted here.
PROC Cfg_Prepare_IOBASE NEAR
    push    ax
    push    bx
    push    cx

    mov     ax, [cfg_iobase_value]
    mov     [cfg_txn_new_base], ax
    sub     ax, 0200h
    mov     cl, 4
    shr     ax, cl
    and     al, 01Fh
    mov     [cfg_txn_io_selector], al

    mov     ax, [cfg_txn_new_word08]
    and     ax, 0FFE0h
    xor     bx, bx
    mov     bl, [cfg_txn_io_selector]
    or      ax, bx
    mov     [cfg_txn_new_word08], ax

    mov     ax, [cfg_txn_new_live06]
    and     ax, 0FFE0h
    or      ax, bx
    mov     [cfg_txn_new_live06], ax

    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Cfg_Prepare_IOBASE

; Merge only the staged IRQ field into the prospective state.
; Encoding is the hardware tested release 0.3.3 behavior.
PROC Cfg_Prepare_INT NEAR
    push    ax
    push    bx
    push    cx

    xor     bx, bx
    mov     bl, [cfg_int_value]
    mov     cl, 12
    shl     bx, cl

    mov     ax, [cfg_txn_new_word09]
    and     ax, 0FFFh
    or      ax, bx
    mov     [cfg_txn_new_word09], ax

    mov     ax, [cfg_txn_new_live08]
    and     ax, 0FFFh
    or      ax, bx
    mov     [cfg_txn_new_live08], ax

    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Cfg_Prepare_INT

; Compare current and prospective states once after all properties are prepared.
; INT keeps release 0.3.3 unchanged semantics: its persistent EEPROM field is
; authoritative.  A matching persistent IRQ alone remains a no write success
; unless an IOBASE migration is already required and must restore live state.
PROC Cfg_Txn_Detect_Changes NEAR
    push    ax

    mov     [cfg_txn_change_flags], 0

    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jz      @@INT

    mov     ax, [cfg_txn_old_word08]
    cmp     ax, [cfg_txn_new_word08]
    je      @@NoW08
    or      [cfg_txn_change_flags], CFG_TXN_CHG_WORD08
@@NoW08:
    mov     ax, [cfg_txn_old_live06]
    cmp     ax, [cfg_txn_new_live06]
    je      @@NoL06
    or      [cfg_txn_change_flags], CFG_TXN_CHG_LIVE06
@@NoL06:
    mov     ax, [cfg_txn_old_base]
    cmp     ax, [cfg_txn_new_base]
    je      @@NoMigrate
    or      [cfg_txn_change_flags], CFG_TXN_MIGRATE_IO
@@NoMigrate:
    test    [cfg_txn_change_flags], CFG_TXN_IO_DETECT_MASK
    jz      @@INT
    or      [cfg_txn_change_flags], CFG_TXN_IOBASE_CHANGED

@@INT:
    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@Done
    mov     ax, [cfg_txn_old_word09]
    cmp     ax, [cfg_txn_new_word09]
    je      @@INTPersistentSame
    or      [cfg_txn_change_flags], CFG_TXN_WORD09_INT_MASK
    mov     ax, [cfg_txn_old_live08]
    cmp     ax, [cfg_txn_new_live08]
    je      @@Done
    or      [cfg_txn_change_flags], CFG_TXN_CHG_LIVE08
    jmp     @@Done

@@INTPersistentSame:
    ; During a real IOBASE migration the activation restore uses the requested
    ; staged IRQ, even when EEPROM already contains it.  Outside migration, the
    ; tested 0.3.3 unchanged INT path performs no live correction.
    test    [cfg_txn_change_flags], CFG_TXN_MIGRATE_IO
    jz      @@Done
    mov     ax, [cfg_txn_old_live08]
    cmp     ax, [cfg_txn_new_live08]
    je      @@Done
    or      [cfg_txn_change_flags], CFG_TXN_CHG_LIVE08

@@Done:
    pop     ax
    ret
ENDP Cfg_Txn_Detect_Changes

; Read only conflict and activation preflight.  Nothing has been modified yet.
PROC Cfg_Txn_Preflight NEAR
    test    [cfg_txn_change_flags], CFG_TXN_MIGRATE_IO
    jz      @@ActivationChoice
    call    Cfg_IOBASE_Check_Conflict
    jnc     @@NeedMigrationTag
    mov     [cfg_last_error], CFG_ERR_IOBASE_CONFLICT
    stc
    ret
@@NeedMigrationTag:
    call    Cfg_Txn_Has_Valid_Tag
    jnc     @@MarkActivation
    mov     [cfg_last_error], CFG_ERR_IOBASE_REACTIVATE
    stc
    ret

@@ActivationChoice:
    ; Preserve release 0.3.3 INT behavior: when an ID tagged adapter is
    ; available, a real IRQ change uses the original deactivate/reactivate path.
    test    [cfg_txn_change_flags], CFG_TXN_INT_CHANGED
    jz      @@Good
    call    Cfg_Txn_Has_Valid_Tag
    jc      @@Good
@@MarkActivation:
    mov     [cfg_txn_activation_needed], 1
@@Good:
    clc
    ret
ENDP Cfg_Txn_Preflight

; Central owner of the old base to new base transition and original ISA
; deactivate/reactivate preparation.  The selected record changes base exactly
; once, immediately before Cfg_Id_Activate_Selected consumes it.
PROC Cfg_Txn_Activate_If_Needed NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si

    cmp     [cfg_txn_activation_needed], 0
    jne     @@Start
    jmp     @@Success

@@Start:
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@Deactivate
    test    [cfg_txn_change_flags], CFG_TXN_MIGRATE_IO
    jz      @@VerboseINT
    mov     dx, OFFSET msg_cfg_deactivate_iobase
    mov     ah, 09h
    int     21h
    jmp     @@Deactivate
@@VerboseINT:
    mov     dx, OFFSET msg_cfg_prepare_active
    mov     ah, 09h
    int     21h

@@Deactivate:
    mov     si, [cfg_selected_ptr]
    call    Cfg_Id_Deactivate_Selected

    ; The experimental IOBASE path proved useful on hardware, so retain its
    ; read only old base absence check for an actual migration.
    test    [cfg_txn_change_flags], CFG_TXN_MIGRATE_IO
    jz      @@Retag
    mov     dx, [cfg_txn_old_base]
    mov     bx, dx
    add     dx, EL3_STATUS
    in      ax, dx
    cmp     ax, 0FFFFh
    je      @@Retag
    mov     dx, bx
    call    Check_3Com_Signature
    jc      @@Retag
    mov     si, [cfg_selected_ptr]
    cmp     ax, [WORD si + NIC_PRODUCT_ID]
    jne     @@Retag
    cmp     [BYTE si + NIC_ASIC_REV], 0FFh
    je      @@DeactivateFail
    cmp     bl, [BYTE si + NIC_ASIC_REV]
    jne     @@Retag
@@DeactivateFail:
    mov     [cfg_last_error], CFG_ERR_IOBASE_DEACTIVATE
    jmp     @@Fail

@@Retag:
    call    Cfg_Txn_Retag_Selected

    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@MigrateRecord
    test    [cfg_txn_change_flags], CFG_TXN_MIGRATE_IO
    jz      @@MigrateRecord
    mov     dx, OFFSET msg_cfg_reactivate_iobase
    mov     ah, 09h
    int     21h

@@MigrateRecord:
    test    [cfg_txn_change_flags], CFG_TXN_MIGRATE_IO
    jz      @@Activate
    mov     si, [cfg_selected_ptr]
    mov     ax, [cfg_txn_new_base]
    mov     [WORD si + NIC_IO_BASE], ax

@@Activate:
    mov     si, [cfg_selected_ptr]
    call    Cfg_Id_Activate_Selected

    ; Original sub_334 restores both live window 0 words before sub_342 commits
    ; persistent state.  Restore the complete prospective live image here.
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    xor     al, al
    call    Select_Window
    mov     ax, [cfg_txn_new_live06]
    mov     bx, EL3_W0_ADDRESS_CFG
    call    Cfg_Reg_Write_Word
    mov     ax, [cfg_txn_new_live08]
    mov     bx, EL3_W0_RESOURCE_CFG
    call    Cfg_Reg_Write_Word

    ; Confirm that an EtherLink III register image is reachable.  At this stage
    ; keep the proven strict product and ASIC comparison before any EEPROM write.
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Check_3Com_Signature
    jc      @@ActivationFail
    cmp     ax, [WORD si + NIC_PRODUCT_ID]
    jne     @@ActivationFail
    cmp     [BYTE si + NIC_ASIC_REV], 0FFh
    je      @@SignatureGood
    cmp     bl, [BYTE si + NIC_ASIC_REV]
    jne     @@ActivationFail
@@SignatureGood:

    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    xor     al, al
    call    Select_Window

    test    [cfg_txn_change_flags], CFG_TXN_MIGRATE_IO
    jz      @@CheckIRQ
    mov     bx, EL3_W0_ADDRESS_CFG
    call    Cfg_Reg_Read_Word
    and     al, 01Fh
    cmp     al, [cfg_txn_io_selector]
    jne     @@ActivationLiveFail

@@CheckIRQ:
    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@PreserveIRQ
    test    [cfg_txn_change_flags], CFG_TXN_INT_MIGRATE_MASK
    jz      @@Success
    mov     bx, EL3_W0_RESOURCE_CFG
    call    Cfg_Reg_Read_Word
    mov     bx, ax
    mov     cl, 12
    shr     bx, cl
    and     bl, 0Fh
    cmp     bl, [cfg_int_value]
    jne     @@ActivationLiveFail
    jmp     @@Success

@@PreserveIRQ:
    ; IOBASE only migration must preserve the live IRQ nibble exactly.
    test    [cfg_txn_change_flags], CFG_TXN_MIGRATE_IO
    jz      @@Success
    mov     bx, EL3_W0_RESOURCE_CFG
    call    Cfg_Reg_Read_Word
    mov     bx, ax
    mov     cl, 12
    shr     bx, cl
    and     bl, 0Fh
    mov     ax, [cfg_txn_old_live08]
    mov     cl, 12
    shr     ax, cl
    and     al, 0Fh
    cmp     bl, al
    jne     @@ActivationLiveFail

@@Success:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    clc
    ret

@@ActivationFail:
    test    [cfg_txn_change_flags], CFG_TXN_MIGRATE_IO
    jz      @@INTActivationFail
    mov     [cfg_last_error], CFG_ERR_IOBASE_ACTIVATE
    jmp     @@Fail
@@INTActivationFail:
    mov     [cfg_last_error], CFG_ERR_LIVE_UPDATE
    jmp     @@Fail
@@ActivationLiveFail:
    test    [cfg_txn_change_flags], CFG_TXN_MIGRATE_IO
    jz      @@INTLiveFail
    mov     [cfg_last_error], CFG_ERR_IOBASE_LIVE
    jmp     @@Fail
@@INTLiveFail:
    mov     [cfg_last_error], CFG_ERR_LIVE_UPDATE
@@Fail:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    stc
    ret
ENDP Cfg_Txn_Activate_If_Needed

; Write all changed persistent property words in original sub_342 order, then
; update the shared low checksum byte once.  Each EEPROM word remains a separate
; physical Cfg_Eeprom_Write operation inside one logical CONFIGURE transaction.
PROC Cfg_Txn_Write_EEPROM NEAR
    push    ax
    push    bx
    push    dx
    push    si

    test    [cfg_txn_change_flags], CFG_TXN_EEPROM_MASK
    jnz     @@Start
    jmp     @@Success

@@Start:
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@Word08
    mov     dx, OFFSET msg_cfg_txn_write
    mov     ah, 09h
    int     21h

@@Word08:
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD08
    jz      @@Word09
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     bx, [cfg_txn_new_word08]
    mov     al, EEPROM_ADDR_CFG
    call    Cfg_Eeprom_Write
    jc      @@Write08Fail
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@Word09
    mov     dx, OFFSET msg_cfg_iobase_word_written
    mov     ah, 09h
    int     21h

@@Word09:
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD09
    jz      @@Checksum
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     bx, [cfg_txn_new_word09]
    mov     al, EEPROM_RESOURCE_CFG
    call    Cfg_Eeprom_Write
    jc      @@Write09Fail
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@Checksum
    mov     dx, OFFSET msg_cfg_irq_word_written
    mov     ah, 09h
    int     21h

@@Checksum:
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@ChecksumCalc
    mov     dx, OFFSET msg_cfg_update_checksum
    mov     ah, 09h
    int     21h
@@ChecksumCalc:
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Cfg_Checksum_0F_Low
    jc      @@ChecksumFail
    mov     [cfg_txn_checksum], al

    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, 0Fh
    call    Cfg_Eeprom_Read
    jc      @@ChecksumFail
    and     ax, 0FF00h
    xor     bx, bx
    mov     bl, [cfg_txn_checksum]
    or      ax, bx
    mov     [cfg_txn_new_word0f], ax
    mov     bx, ax
    mov     al, 0Fh
    call    Cfg_Eeprom_Write
    jc      @@ChecksumFail

    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, 0Fh
    call    Cfg_Eeprom_Read
    jc      @@ChecksumFail
    cmp     ax, [cfg_txn_new_word0f]
    jne     @@ChecksumFail

    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@Success
    mov     dx, OFFSET msg_cfg_checksum_updated
    mov     ah, 09h
    int     21h

@@Success:
    pop     si
    pop     dx
    pop     bx
    pop     ax
    clc
    ret

@@Write08Fail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_IOBASE_EEPROM_WRITE
    jmp     @@Fail
@@Write09Fail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_EEPROM_WRITE
    jmp     @@Fail
@@ChecksumFail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_CHECKSUM_UPDATE
@@Fail:
    pop     si
    pop     dx
    pop     bx
    pop     ax
    stc
    ret
ENDP Cfg_Txn_Write_EEPROM

; Synchronize changed live fields after the persistent commit.  A migration
; repeats the Address Configuration write here because original sub_334 restores
; it during activation and sub_342 writes it again after EEPROM configuration.
PROC Cfg_Txn_Write_Live NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si

    xor     al, al
    test    [cfg_txn_change_flags], CFG_TXN_LIVE06_MASK
    jnz     @@Need
    test    [cfg_txn_change_flags], CFG_TXN_INT_CHANGED
    jz      @@Success
@@Need:
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@Select
    mov     dx, OFFSET msg_cfg_txn_live
    mov     ah, 09h
    int     21h

@@Select:
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    xor     al, al
    call    Select_Window

    test    [cfg_txn_change_flags], CFG_TXN_LIVE06_MASK
    jz      @@INT
    mov     ax, [cfg_txn_new_live06]
    mov     bx, EL3_W0_ADDRESS_CFG
    call    Cfg_Reg_Write_Word
    mov     bx, EL3_W0_ADDRESS_CFG
    call    Cfg_Reg_Read_Word
    and     al, 01Fh
    cmp     al, [cfg_txn_io_selector]
    jne     @@IOFail

@@INT:
    test    [cfg_txn_change_flags], CFG_TXN_INT_CHANGED
    jz      @@Success
    mov     ax, [cfg_txn_new_live08]
    mov     bx, EL3_W0_RESOURCE_CFG
    call    Cfg_Reg_Write_Word
    mov     bx, EL3_W0_RESOURCE_CFG
    call    Cfg_Reg_Read_Word
    mov     bx, ax
    mov     cl, 12
    shr     bx, cl
    and     bl, 0Fh
    cmp     bl, [cfg_int_value]
    jne     @@INTFail

@@Success:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    clc
    ret
@@IOFail:
    mov     [cfg_last_error], CFG_ERR_IOBASE_LIVE
    jmp     @@Fail
@@INTFail:
    mov     [cfg_last_error], CFG_ERR_LIVE_UPDATE
@@Fail:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    stc
    ret
ENDP Cfg_Txn_Write_Live

; Central verification.  Final reachability deliberately verifies the live 3Com
; signature and product identity but does not repeat the ASIC revision equality
; test.  ASIC revision was already checked by Cfg_Revalidate_Selected and, when
; activation occurred, by Cfg_Txn_Activate_If_Needed.  It is not a configured
; property and should not turn successful EEPROM and live field readback into a
; false IOBASE verification failure.
PROC Cfg_Txn_Verify NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si

    test    [cfg_txn_change_flags], CFG_TXN_COMMIT_MASK
    jnz     @@Start
    jmp     @@Success

@@Start:
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@Reachable
    mov     dx, OFFSET msg_cfg_txn_verify
    mov     ah, 09h
    int     21h

@@Reachable:
    ; Release 0.3.3 INT verification did not add a final signature probe.  Keep
    ; reachability as an IOBASE transaction check only, where the active address
    ; itself may have changed.
    test    [cfg_txn_change_flags], CFG_TXN_IOBASE_CHANGED
    jz      @@INTPersistent

    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Check_3Com_Signature
    jc      @@ReachFail
    cmp     ax, [WORD si + NIC_PRODUCT_ID]
    jne     @@ReachFail

    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@IOPersistent
    mov     dx, OFFSET msg_cfg_txn_reachable
    mov     ah, 09h
    int     21h
    mov     ax, [WORD si + NIC_IO_BASE]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

@@IOPersistent:
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_ADDR_CFG
    call    Cfg_Eeprom_Read
    jc      @@IOVerifyFail
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD08
    jz      @@IOField
    cmp     ax, [cfg_txn_new_word08]
    jne     @@IOVerifyFail
@@IOField:
    and     al, 01Fh
    cmp     al, [cfg_txn_io_selector]
    jne     @@IOVerifyFail

    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@IOLive
    mov     dx, OFFSET msg_cfg_eeprom_iobase_verified
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_iobase_value]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

@@IOLive:
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    xor     al, al
    call    Select_Window
    mov     bx, EL3_W0_ADDRESS_CFG
    call    Cfg_Reg_Read_Word
    and     al, 01Fh
    cmp     al, [cfg_txn_io_selector]
    jne     @@IOVerifyFail

    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@INTPersistent
    mov     dx, OFFSET msg_cfg_live_iobase_verified
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_iobase_value]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

@@INTPersistent:
    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@Success
    ; Preserve the standalone 0.3.3 unchanged path.  Verify INT only when its
    ; persistent field changed, or when an IO migration forced live restoration.
    test    [cfg_txn_change_flags], CFG_TXN_INT_MIGRATE_MASK
    jz      @@Success

    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_RESOURCE_CFG
    call    Cfg_Eeprom_Read
    jc      @@INTVerifyFail
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD09
    jz      @@INTField
    cmp     ax, [cfg_txn_new_word09]
    jne     @@INTVerifyFail
@@INTField:
    mov     bx, ax
    mov     cl, 12
    shr     bx, cl
    and     bl, 0Fh
    cmp     bl, [cfg_int_value]
    jne     @@INTVerifyFail

    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@INTLive
    mov     dx, OFFSET msg_cfg_eeprom_verified
    mov     ah, 09h
    int     21h
    mov     al, bl
    call    Print_DecByte
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

@@INTLive:
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    xor     al, al
    call    Select_Window
    mov     bx, EL3_W0_RESOURCE_CFG
    call    Cfg_Reg_Read_Word
    mov     bx, ax
    mov     cl, 12
    shr     bx, cl
    and     bl, 0Fh
    cmp     bl, [cfg_int_value]
    jne     @@INTVerifyFail

    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@Success
    mov     dx, OFFSET msg_cfg_live_verified
    mov     ah, 09h
    int     21h
    mov     al, bl
    call    Print_DecByte
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

@@Success:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    clc
    ret

@@ReachFail:
    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jz      @@INTVerifyFail
    mov     [cfg_last_error], CFG_ERR_IOBASE_VERIFY
    jmp     @@Fail
@@IOVerifyFail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_IOBASE_VERIFY
    jmp     @@Fail
@@INTVerifyFail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_VERIFY
@@Fail:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    stc
    ret
ENDP Cfg_Txn_Verify

; Verbose snapshot and prospective image reporting.  Normal mode remains concise.
PROC Cfg_Txn_Report_Current NEAR
    push    ax
    push    dx

    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jnz     @@Start
    jmp     @@Done
@@Start:
    mov     dx, OFFSET msg_cfg_txn_current_active_base
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_old_base]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jz      @@Live06
    mov     dx, OFFSET msg_cfg_current_iobase
    mov     ah, 09h
    int     21h
    mov     al, [cfg_txn_old_io_selector]
    call    Cfg_IOBASE_Selector_To_Base
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_cfg_current_word08
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_old_word08]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_cfg_current_live_iobase
    mov     ah, 09h
    int     21h
    mov     al, [cfg_txn_live_io_selector]
    call    Cfg_IOBASE_Selector_To_Base
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

@@Live06:
    mov     dx, OFFSET msg_cfg_current_live06
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_old_live06]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@Live08
    mov     dx, OFFSET msg_cfg_current_irq
    mov     ah, 09h
    int     21h
    mov     al, [cfg_txn_old_irq]
    call    Print_DecByte
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_cfg_txn_current_live_irq
    mov     ah, 09h
    int     21h
    mov     al, [cfg_txn_live_irq]
    call    Print_DecByte
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_cfg_current_word09
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_old_word09]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

@@Live08:
    mov     dx, OFFSET msg_cfg_current_live08
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_old_live08]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h
@@Done:
    pop     dx
    pop     ax
    ret
ENDP Cfg_Txn_Report_Current

PROC Cfg_Txn_Report_Prospective NEAR
    push    ax
    push    dx

    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jnz     @@Start
    jmp     @@Done
@@Start:
    mov     dx, OFFSET msg_cfg_txn_prepare
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_cfg_txn_new_base
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_new_base]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jz      @@Live06
    mov     dx, OFFSET msg_cfg_new_word08
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_new_word08]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

@@Live06:
    mov     dx, OFFSET msg_cfg_new_live06
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_new_live06]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@Live08
    mov     dx, OFFSET msg_cfg_new_word09
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_new_word09]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

@@Live08:
    mov     dx, OFFSET msg_cfg_new_live08
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_new_live08]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h
@@Done:
    pop     dx
    pop     ax
    ret
ENDP Cfg_Txn_Report_Prospective

; Print final success message once after centralized verification.
PROC Cfg_Txn_Report_Success NEAR
    push    dx

    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jz      @@INTOnly
    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@IOOnly
    mov     dx, OFFSET msg_cfg_combined_completed
    jmp     @@Print
@@IOOnly:
    mov     dx, OFFSET msg_cfg_iobase_completed
    jmp     @@Print
@@INTOnly:
    mov     dx, OFFSET msg_cfg_completed
@@Print:
    mov     ah, 09h
    int     21h
    pop     dx
    ret
ENDP Cfg_Txn_Report_Success

; Single centralized CONFIGURE transaction entry point.
PROC Cfg_Txn_Execute NEAR
    push    ax
    push    dx
    push    si

    mov     [cfg_last_error], CFG_ERR_NONE
    mov     [cfg_timeout_latched], 0

    ; Adapter selection detail is global transaction output, not property output.
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@Requested
    mov     dx, OFFSET msg_cfg_adapter_prefix
    mov     ah, 09h
    int     21h
    mov     al, [cfg_adapter_ordinal]
    call    Print_DecByte
    mov     dx, OFFSET msg_cfg_adapter_suffix
    mov     ah, 09h
    int     21h

@@Requested:
    ; Preserve normal requested parameter output from the existing releases.
    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jz      @@RequestedINT
    mov     dx, OFFSET msg_cfg_iobase_ok
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_iobase_value]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h
@@RequestedINT:
    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@Read
    mov     dx, OFFSET msg_cfg_int_ok
    mov     ah, 09h
    int     21h
    mov     al, [cfg_int_value]
    call    Print_DecByte
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

@@Read:
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@ReadNow
    mov     dx, OFFSET msg_cfg_txn_read
    mov     ah, 09h
    int     21h
@@ReadNow:
    call    Cfg_Txn_Read_Current
    jc      @@Done
    call    Cfg_Txn_Report_Current

    call    Cfg_Txn_Init_Prospective
    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jz      @@PrepareINT
    call    Cfg_Prepare_IOBASE
@@PrepareINT:
    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@Detect
    call    Cfg_Prepare_INT
@@Detect:
    call    Cfg_Txn_Detect_Changes
    call    Cfg_Txn_Report_Prospective

    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@CheckAnyChange
    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jz      @@CheckINTUnchanged
    test    [cfg_txn_change_flags], CFG_TXN_IOBASE_CHANGED
    jnz     @@CheckINTUnchanged
    mov     dx, OFFSET msg_cfg_iobase_unchanged
    mov     ah, 09h
    int     21h
@@CheckINTUnchanged:
    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@CheckAnyChange
    test    [cfg_txn_change_flags], CFG_TXN_INT_CHANGED
    jnz     @@CheckAnyChange
    mov     dx, OFFSET msg_cfg_irq_unchanged
    mov     ah, 09h
    int     21h

@@CheckAnyChange:
    ; No requested hardware change.  INT intentionally follows release 0.3.3
    ; persistent authoritative unchanged behavior.
    mov     al, [cfg_txn_change_flags]
    and     al, CFG_TXN_COMMIT_MASK
    jnz     @@Preflight
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@Success
    mov     dx, OFFSET msg_cfg_txn_no_changes
    mov     ah, 09h
    int     21h
    jmp     @@Success

@@Preflight:
    call    Cfg_Txn_Preflight
    jc      @@Done
    call    Cfg_Txn_Activate_If_Needed
    jc      @@Done
    call    Cfg_Txn_Write_EEPROM
    jc      @@Done
    call    Cfg_Txn_Write_Live
    jc      @@Done
    call    Cfg_Txn_Verify
    jc      @@Done

@@Success:
    ; Keep the in memory record synchronized only after successful verification.
    mov     si, [cfg_selected_ptr]
    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@ReportSuccess
    mov     al, [cfg_int_value]
    mov     [BYTE si + NIC_IRQ_VAL], al
@@ReportSuccess:
    call    Cfg_Txn_Report_Success
    mov     [cfg_last_error], CFG_ERR_NONE

@@Done:
    pop     si
    pop     dx
    pop     ax
    ret
ENDP Cfg_Txn_Execute

; Original sub_318, destination EEPROM word 17h high byte.
; Domains: words 10h through 12h and words 18h through 3Fh.
PROC Cfg_Checksum_17_High NEAR
    push    bx
    push    cx
    push    dx
    push    si

    xor     bx, bx
    mov     si, 10h
@@First:
    mov     ax, si
    call    Cfg_Eeprom_Read
    jc      @@Fail
    call    Cfg_Checksum_Xor_Word
    inc     si
    cmp     si, 12h
    jbe     @@First

    mov     si, 18h
@@Second:
    mov     ax, si
    call    Cfg_Eeprom_Read
    jc      @@Fail
    call    Cfg_Checksum_Xor_Word
    inc     si
    cmp     si, 3Fh
    jbe     @@Second

    mov     al, bl
    pop     si
    pop     dx
    pop     cx
    pop     bx
    clc
    ret
@@Fail:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    stc
    ret
ENDP Cfg_Checksum_17_High

; Original sub_319, destination EEPROM word 17h low byte.
; Domain: words 13h through 16h.
PROC Cfg_Checksum_17_Low NEAR
    push    bx
    push    cx
    push    dx
    push    si

    xor     bx, bx
    mov     si, 13h
@@Loop:
    mov     ax, si
    call    Cfg_Eeprom_Read
    jc      @@Fail
    call    Cfg_Checksum_Xor_Word
    inc     si
    cmp     si, 16h
    jbe     @@Loop
    mov     al, bl
    pop     si
    pop     dx
    pop     cx
    pop     bx
    clc
    ret
@@Fail:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    stc
    ret
ENDP Cfg_Checksum_17_Low

; Revalidate the logical record selected from nic_table against live hardware.
; Active records use the existing proven register signature path and then the
; OEM station address from EEPROM.  An unassigned ID port record can be checked
; read only by selecting its existing tag and re-reading the same identity words.
; Input SI = selected record.  Carry set with cfg_last_error on failure.
PROC Cfg_Revalidate_Selected NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    di
    push    si

    mov     dx, [WORD si + NIC_IO_BASE]
    or      dx, dx
    jz      @@ByTag

    call    Check_3Com_Signature
    jc      @@Mismatch
    cmp     ax, [WORD si + NIC_PRODUCT_ID]
    jne     @@Mismatch
    cmp     [BYTE si + NIC_ASIC_REV], 0FFh
    je      @@Mac
    cmp     bl, [BYTE si + NIC_ASIC_REV]
    jne     @@Mismatch

@@Mac:
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Get_Current_Window
    mov     ch, al

    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_OEM_NODE_0
    call    Cfg_Eeprom_Read
    jc      @@RestoreReadError
    cmp     ah, [BYTE si + NIC_MAC_ADDR]
    jne     @@RestoreMismatch
    cmp     al, [BYTE si + NIC_MAC_ADDR + 1]
    jne     @@RestoreMismatch

    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_OEM_NODE_1
    call    Cfg_Eeprom_Read
    jc      @@RestoreReadError
    cmp     ah, [BYTE si + NIC_MAC_ADDR + 2]
    jne     @@RestoreMismatch
    cmp     al, [BYTE si + NIC_MAC_ADDR + 3]
    jne     @@RestoreMismatch

    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_OEM_NODE_2
    call    Cfg_Eeprom_Read
    jc      @@RestoreReadError
    cmp     ah, [BYTE si + NIC_MAC_ADDR + 4]
    jne     @@RestoreMismatch
    cmp     al, [BYTE si + NIC_MAC_ADDR + 5]
    jne     @@RestoreMismatch

    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, ch
    call    Select_Window
    jmp     @@Good

@@RestoreReadError:
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, ch
    call    Select_Window
    jmp     @@Fail
@@RestoreMismatch:
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, ch
    call    Select_Window
    jmp     @@Mismatch

@@ByTag:
    test    [BYTE si + NIC_FLAGS], NIC_FLAG_FROM_ID
    jz      @@Mismatch
    mov     al, [BYTE si + NIC_TAG]
    or      al, al
    jz      @@Mismatch
    cmp     al, 7
    ja      @@Mismatch

    cli
    cmp     [BYTE si + NIC_ID_MODE], 0
    je      @@FullSequence
    call    IdPort_Send_Short_Sequence
    jmp     @@SelectTag
@@FullSequence:
    call    IdPort_Send_Full_Sequence
@@SelectTag:
    mov     dx, ID_PORT
    mov     al, ID_CMD_SELECT_TAG
    or      al, [BYTE si + NIC_TAG]
    out     dx, al

    mov     al, EEPROM_MFG_ID
    call    IdPort_Read_Word
    cmp     ax, 06D50h
    jne     @@TagMismatch
    mov     al, EEPROM_PRODUCT_ID
    call    IdPort_Read_Word
    cmp     ax, [WORD si + NIC_PRODUCT_ID]
    jne     @@TagMismatch
    call    Cfg_Is_Supported_Product
    jc      @@TagUnsupported

    mov     al, EEPROM_OEM_NODE_0
    call    IdPort_Read_Word
    cmp     ah, [BYTE si + NIC_MAC_ADDR]
    jne     @@TagMismatch
    cmp     al, [BYTE si + NIC_MAC_ADDR + 1]
    jne     @@TagMismatch
    mov     al, EEPROM_OEM_NODE_1
    call    IdPort_Read_Word
    cmp     ah, [BYTE si + NIC_MAC_ADDR + 2]
    jne     @@TagMismatch
    cmp     al, [BYTE si + NIC_MAC_ADDR + 3]
    jne     @@TagMismatch
    mov     al, EEPROM_OEM_NODE_2
    call    IdPort_Read_Word
    cmp     ah, [BYTE si + NIC_MAC_ADDR + 4]
    jne     @@TagMismatch
    cmp     al, [BYTE si + NIC_MAC_ADDR + 5]
    jne     @@TagMismatch
    sti
    jmp     @@Good

@@TagUnsupported:
    sti
    mov     [cfg_last_error], CFG_ERR_UNSUPPORTED_PRODUCT
    jmp     @@Fail
@@TagMismatch:
    sti
@@Mismatch:
    mov     [cfg_last_error], CFG_ERR_REVALIDATE
@@Fail:
    pop     si
    pop     di
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    stc
    ret
@@Good:
    pop     si
    pop     di
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    clc
    ret
ENDP Cfg_Revalidate_Selected

; ISA deactivation core recovered from original sub_335.
; Input SI = selected ID record.  D8h plus tag selects it, C0h deactivates it.
; Release 0.3.4 CONFIGURE calls this only for a selected ID tagged record.
PROC Cfg_Id_Deactivate_Selected NEAR
    push    ax
    push    dx

    cli
    cmp     [BYTE si + NIC_ID_MODE], 0
    je      @@Full
    call    IdPort_Send_Short_Sequence
    jmp     @@Selected
@@Full:
    call    IdPort_Send_Full_Sequence
@@Selected:
    mov     dx, ID_PORT
    mov     al, ID_CMD_SELECT_TAG
    or      al, [BYTE si + NIC_TAG]
    out     dx, al
    mov     al, 0C0h
    out     dx, al
    sti

    pop     dx
    pop     ax
    ret
ENDP Cfg_Id_Deactivate_Selected

; ISA activation core recovered from original sub_334 and sub_335 reactivation.
; Input SI = selected record.  Uses its existing tag and active I O base.
; Release 0.3.4 CONFIGURE calls this only for a selected ID tagged record.
PROC Cfg_Id_Activate_Selected NEAR
    push    ax
    push    bx
    push    dx

    cli
    cmp     [BYTE si + NIC_ID_MODE], 0
    je      @@Full
    call    IdPort_Send_Short_Sequence
    jmp     @@Select
@@Full:
    call    IdPort_Send_Full_Sequence
@@Select:
    mov     dx, ID_PORT
    mov     al, ID_CMD_SELECT_TAG
    or      al, [BYTE si + NIC_TAG]
    out     dx, al

    mov     ax, [WORD si + NIC_IO_BASE]
    sub     ax, 0200h
    mov     bx, 0010h
    xor     dx, dx
    div     bx
    or      al, ID_CMD_ACTIVATE
    mov     dx, ID_PORT
    out     dx, al
    sti

    pop     dx
    pop     bx
    pop     ax
    ret
ENDP Cfg_Id_Activate_Selected

; ============================================================================
; Extended LIST information
; ============================================================================

; Select the original generic NIC description resource by product family.
; Input AX = product ID.  Output DX = DOS string address.
; The current executable accepts only the 9050h family.  The 8050h branch is
; retained so the original ISA resource mapping is explicit, but it is not
; reachable without adding a real 3C508 detector.  EISA and MCA strings have
; no executable selection branch.
PROC Select_Nic_Description NEAR
    push    ax
    and     ax, 0F0FFh
    cmp     ax, 08050h
    je      @@Isa508
    cmp     ax, 09050h
    je      @@Isa509
    mov     dx, OFFSET msg_a02c
    jmp     @@Done
@@Isa508:
    mov     dx, OFFSET msg_a0ac
    jmp     @@Done
@@Isa509:
    mov     dx, OFFSET msg_a02c
@@Done:
    pop     ax
    ret
ENDP Select_Nic_Description

; Read all additional LIST values from the activated adapter.
; Input SI = NIC record.
; The existing enumeration record is not modified.
PROC Read_Extended_Nic_Info NEAR
    push    ax
    push    dx

    mov     [ext_addr_cfg], 0FFFFh
    mov     [ext_compatibility], 0FFFFh
    mov     [ext_capability], 0FFFFh
    mov     [ext_config_ctrl], 0FFFFh
    mov     [ext_revision_info], 0FFFFh

    mov     dx, [WORD si + NIC_IO_BASE]
    or      dx, dx
    jz      @@Done
    test    [BYTE si + NIC_FLAGS], NIC_FLAG_ACTIVE
    jz      @@Done

    mov     al, EEPROM_ADDR_CFG
    call    EEPROM_Read
    mov     [ext_addr_cfg], ax

    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_COMPATIBILITY
    call    EEPROM_Read
    mov     [ext_compatibility], ax

    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_REVISION_INFO
    call    EEPROM_Read
    mov     [ext_revision_info], ax

    mov     ax, [ext_revision_info]
    cmp     ax, 0FFFFh
    je      @@Done
    and     ax, 00FFh
    cmp     ax, 1
    jb      @@Done

    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_CAPABILITY
    call    EEPROM_Read
    mov     [ext_capability], ax

    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_CONFIG_CONTROL
    call    EEPROM_Read
    mov     [ext_config_ctrl], ax

@@Done:
    pop     dx
    pop     ax
    ret
ENDP Read_Extended_Nic_Info

; Return AL = 1 if EEPROM word 14h identifies the later capability layout.
PROC Extended_Is_Later_Card NEAR
    mov     ax, [ext_revision_info]
    cmp     ax, 0FFFFh
    je      @@No
    and     ax, 00FFh
    cmp     ax, 1
    jb      @@No
    mov     al, 1
    ret
@@No:
    xor     al, al
    ret
ENDP Extended_Is_Later_Card

PROC Print_Transceiver_Value NEAR
    push    ax
    push    cx
    push    dx

    mov     ax, [ext_addr_cfg]
    cmp     ax, 0FFFFh
    je      @@Unavailable

    call    Extended_Is_Later_Card
    or      al, al
    jz      @@ConfiguredMedia

    mov     ax, [WORD si + NIC_PRODUCT_ID]
    cmp     ax, PRODUCT_3C509_TPO
    je      @@ConfiguredMedia

    mov     ax, [ext_addr_cfg]
    test    ax, 0080h
    jz      @@ConfiguredMedia
    mov     dx, OFFSET msg_auto_select
    jmp     @@Print

@@ConfiguredMedia:
    mov     ax, [ext_addr_cfg]
    mov     cl, 14
    shr     ax, cl
    and     al, 03h
    cmp     al, 2
    jne     @@MediaNormalized
    mov     al, 1
@@MediaNormalized:
    cmp     al, 0
    je      @@Tp
    cmp     al, 1
    je      @@External
    cmp     al, 3
    je      @@Coax
    mov     dx, OFFSET msg_unknown_value
    jmp     @@Print
@@Tp:
    mov     dx, OFFSET msg_onboard_tp
    jmp     @@Print
@@External:
    mov     dx, OFFSET msg_external
    jmp     @@Print
@@Coax:
    mov     dx, OFFSET msg_onboard_coax
    jmp     @@Print
@@Unavailable:
    mov     dx, OFFSET msg_unavailable
@@Print:
    mov     ah, 09h
    int     21h
    pop     dx
    pop     cx
    pop     ax
    ret
ENDP Print_Transceiver_Value

PROC Print_Pnp_Capability_Value NEAR
    push    ax
    push    dx

    call    Extended_Is_Later_Card
    or      al, al
    jz      @@NotSupported

    mov     ax, [ext_capability]
    cmp     ax, 0FFFFh
    je      @@Unavailable
    test    ax, 0001h
    jz      @@Disabled

    mov     ax, [ext_config_ctrl]
    cmp     ax, 0FFFFh
    je      @@Unavailable
    and     ax, 000Ch
    cmp     ax, 0004h
    je      @@Disabled

    mov     dx, OFFSET msg_enabled
    jmp     @@Print
@@Disabled:
    mov     dx, OFFSET msg_disabled
    jmp     @@Print
@@NotSupported:
    mov     dx, OFFSET msg_not_supported
    jmp     @@Print
@@Unavailable:
    mov     dx, OFFSET msg_unavailable
@@Print:
    mov     ah, 09h
    int     21h
    pop     dx
    pop     ax
    ret
ENDP Print_Pnp_Capability_Value

PROC Print_Boot_Rom_Value NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    di

    mov     ax, [ext_addr_cfg]
    cmp     ax, 0FFFFh
    je      @@Unavailable

    call    Extended_Is_Later_Card
    or      al, al
    jz      @@CheckBase
    mov     ax, [WORD si + NIC_PRODUCT_ID]
    cmp     ax, PRODUCT_3C509_TPO
    je      @@NotSupported

@@CheckBase:
    mov     bx, [ext_addr_cfg]
    and     bx, 0F00h
    mov     cl, 8
    shr     bx, cl
    or      bx, bx
    jz      @@Disabled

    mov     ax, [ext_addr_cfg]
    and     ax, 3000h
    mov     cl, 12
    shr     ax, cl
    cmp     ax, 3
    je      @@Invalid

    mov     di, 8
    or      ax, ax
    jz      @@HaveSizeK
    mov     di, 16
    cmp     ax, 1
    je      @@HaveSizeK
    mov     di, 32
@@HaveSizeK:

    cmp     di, 8
    je      @@CheckOld32K
    and     bx, 000Eh
@@CheckOld32K:
    call    Extended_Is_Later_Card
    or      al, al
    jnz     @@BuildAddress
    cmp     di, 32
    jne     @@BuildAddress
    and     bx, 000Ch

@@BuildAddress:
    mov     ax, bx
    mov     cx, 2000h
    mul     cx
    add     dx, 000Ch

    push    dx
    push    ax
    mov     ax, di
    call    Print_DecByte
    mov     dx, OFFSET msg_at
    mov     ah, 09h
    int     21h
    pop     ax
    pop     dx
    call    Print_HexAddress20
    mov     dx, OFFSET msg_hex_suffix
    mov     ah, 09h
    int     21h
    jmp     @@Done

@@Disabled:
    mov     dx, OFFSET msg_disabled
    jmp     @@PrintString
@@NotSupported:
    mov     dx, OFFSET msg_not_supported
    jmp     @@PrintString
@@Invalid:
    mov     dx, OFFSET msg_invalid_cfg
    jmp     @@PrintString
@@Unavailable:
    mov     dx, OFFSET msg_unavailable
@@PrintString:
    mov     ah, 09h
    int     21h
@@Done:
    pop     di
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Print_Boot_Rom_Value

PROC Print_HexAddress20 NEAR
    push    ax
    push    dx
    mov     al, dl
    call    Print_HexNibble
    pop     dx
    pop     ax
    call    Print_HexWord
    ret
ENDP Print_HexAddress20

PROC Print_Extended_Nic_Info NEAR
    push    ax
    push    dx

    mov     dx, OFFSET msg_indent
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET msg_asic_label
    mov     ah, 09h
    int     21h
    mov     al, [BYTE si + NIC_ASIC_REV]
    cmp     al, 0FFh
    je      @@AsicUnavailable
    xor     ah, ah
    call    Print_DecByte
    jmp     @@AsicDone
@@AsicUnavailable:
    mov     dx, OFFSET msg_unavailable
    mov     ah, 09h
    int     21h
@@AsicDone:
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_indent
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET msg_xcvr_label
    mov     ah, 09h
    int     21h
    call    Print_Transceiver_Value
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_indent
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET msg_pnp_label
    mov     ah, 09h
    int     21h
    call    Print_Pnp_Capability_Value
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_indent
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET msg_boot_label
    mov     ah, 09h
    int     21h
    call    Print_Boot_Rom_Value
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_indent
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET msg_compat_label
    mov     ah, 09h
    int     21h
    mov     ax, [ext_compatibility]
    cmp     ax, 0FFFFh
    je      @@CompatUnavailable
    mov     al, ah
    xor     ah, ah
    call    Print_DecByte
    mov     dx, OFFSET msg_warn_label
    mov     ah, 09h
    int     21h
    mov     ax, [ext_compatibility]
    and     ax, 00FFh
    call    Print_DecByte
    jmp     @@CompatDone
@@CompatUnavailable:
    mov     dx, OFFSET msg_unavailable
    mov     ah, 09h
    int     21h
@@CompatDone:
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    pop     dx
    pop     ax
    ret
ENDP Print_Extended_Nic_Info

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
