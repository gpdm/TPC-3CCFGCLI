; ============================================================================
; 3CCFGCLI.ASM
; 3Com EtherLink III 3C509 and 3C509B ISA LIST and CONFIGURE framework
; Target: MS DOS, Turbo Assembler, 8086 and 8088 only
; ============================================================================
; - Supported CONFIGURE verbs in this build:
;    /ADAPTERNUM, /BADDRESS, /BSIZE, /FULLDUPLEX, /INT, /IOBASE, /MODEM,
;    /OPTIMIZE, /PNP, /TR (/XCVR alias).
;
; - Supported global CLI options, owned by the common command parser and
;   valid with any command verb:
;    /VERBOSE.
;
; - See CHANGES for the complete release history.
; ============================================================================

IDEAL
P8086
JUMPS

MODEL SMALL
STACK 400h

; ----------------------------------------------------------------------------
; Constants
; ----------------------------------------------------------------------------
MAX_CARDS               EQU 6

; Reserved nonzero ID tag used solely to retire an ID port contender whose
; Address Configuration selector 1Fh requests EISA slot specific addressing.
; Supported records only ever use tags 1 through MAX_CARDS, so this tag can
; never collide with a supported record and the contender is never selected.
ID_TAG_SKIP_EISA        EQU 7

include '3C509DEF.INC'

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
CFG_OPT_PNP             EQU 10
CFG_OPT_FULLDUPLEX      EQU 12

CFG_MAX_PROPERTY_REQUESTS EQU 9
CFG_PROPERTY_REQUEST_SIZE EQU 5    ; ID DB, value pointer DW, value length DW

; Global CLI options.  These belong to the common command parser and are not
; owned by any individual command verb.
CLI_FLAG_VERBOSE        EQU 01h

; Maximum number of verb specific argument tokens the common parser records.
CLI_MAX_ARGS            EQU 16

CFG_PARSE_ADAPTER       EQU 01h
CFG_PARSE_INT           EQU 02h
CFG_PARSE_IOBASE        EQU 08h
CFG_PARSE_PNP           EQU 10h
CFG_PARSE_MODEM         EQU 20h
CFG_PARSE_FULLDUPLEX    EQU 40h
CFG_PARSE_OPTIMIZE      EQU 80h
CFG_PARSE_BADDRESS      EQU 0100h
CFG_PARSE_BSIZE         EQU 0200h
CFG_PARSE_TR            EQU 0400h

; Strict CONFIGURE single occurrence tracking, independent of staged state.
CFG_SEEN_ADAPTER        EQU 01h
CFG_SEEN_INT            EQU 02h
CFG_SEEN_IOBASE         EQU 04h
CFG_SEEN_PNP            EQU 10h
CFG_SEEN_MODEM          EQU 20h
CFG_SEEN_FULLDUPLEX     EQU 40h
CFG_SEEN_OPTIMIZE       EQU 80h
CFG_SEEN_BADDRESS       EQU 0100h
CFG_SEEN_BSIZE          EQU 0200h
CFG_SEEN_TR             EQU 0400h

; Central CONFIGURE transaction change flags.
CFG_TXN_CHG_WORD08       EQU 01h
CFG_TXN_CHG_WORD09       EQU 02h
CFG_TXN_CHG_LIVE06       EQU 04h
CFG_TXN_CHG_LIVE08       EQU 08h
CFG_TXN_MIGRATE_IO       EQU 10h
CFG_TXN_IOBASE_CHANGED   EQU 20h
CFG_TXN_INT_CHANGED      EQU 40h
CFG_TXN_CHG_WORD13       EQU 80h
CFG_TXN_CHG_WORD0D       EQU 0100h
; Widened to also require the hardware transaction pipeline for /BADDRESS,
; /BSIZE, and /TR (bits 0100h/0200h/0400h), which share EEPROM word 08h
; with /IOBASE.
CFG_PARSE_HW_MASK        EQU 07FAh
CFG_TXN_IO_DETECT_MASK   EQU 15h
CFG_TXN_WORD09_INT_MASK  EQU 42h
; Persistent property changes only; derived checksum writes have no flags.
CFG_TXN_EEPROM_MASK      EQU 0183h
CFG_TXN_LIVE06_MASK      EQU 14h
CFG_TXN_PRIMARY_CHECKSUM_MASK EQU 0103h ; WORD08, WORD09, WORD0D
CFG_TXN_SECONDARY_CHECKSUM_MASK EQU 0080h ; WORD13
; WORD08 (bit 0) is included directly so a /BADDRESS or /BSIZE change (which
; has no IOBASE_CHANGED-style composite signal of its own) still triggers
; the write/verify/success pipeline. This mirrors how WORD0D and WORD13 are
; included directly for MODEM/FULLDUPLEX/PNP/OPTIMIZE.
CFG_TXN_COMMIT_MASK      EQU 01F1h
CFG_TXN_INT_MIGRATE_MASK EQU 50h

; Normalized physical NIC capabilities.  These bits are a shared software
; contract, not aliases for EEPROM or register bit positions.
NIC_CAP_PNP              EQU 01h
NIC_CAP_TP               EQU 02h
NIC_CAP_AUI              EQU 04h
NIC_CAP_BNC              EQU 08h
NIC_CAP_FULLDUPLEX       EQU 10h
NIC_CAP_VALID_PNP        EQU 01h
NIC_CAP_VALID_CONNECTORS EQU 02h
NIC_CAP_VALID_FULLDUPLEX EQU 04h

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
CFG_ERR_BAD_PNP             EQU 31
CFG_ERR_PNP_INACTIVE        EQU 32
CFG_ERR_PNP_EEPROM_READ     EQU 33
CFG_ERR_PNP_EEPROM_WRITE    EQU 34
CFG_ERR_PNP_VERIFY          EQU 35
CFG_ERR_BAD_MODEM           EQU 36
CFG_ERR_MODEM_INACTIVE      EQU 37
CFG_ERR_MODEM_EEPROM_READ   EQU 38
CFG_ERR_MODEM_EEPROM_WRITE  EQU 39
CFG_ERR_MODEM_VERIFY        EQU 40
CFG_ERR_PNP_NOT_CAPABLE     EQU 41
CFG_ERR_BAD_FULLDUPLEX      EQU 42
CFG_ERR_FD_INACTIVE         EQU 43
CFG_ERR_FD_EEPROM_READ      EQU 44
CFG_ERR_FD_EEPROM_WRITE     EQU 45
CFG_ERR_FD_VERIFY           EQU 46
CFG_ERR_FD_NOT_CAPABLE      EQU 47
CFG_ERR_BAD_OPTIMIZE        EQU 48
CFG_ERR_OPTIMIZE_INACTIVE   EQU 49
CFG_ERR_OPTIMIZE_EEPROM_READ EQU 50
CFG_ERR_OPTIMIZE_EEPROM_WRITE EQU 51
CFG_ERR_OPTIMIZE_VERIFY     EQU 52
CFG_ERR_BAD_BADDRESS        EQU 53
CFG_ERR_BADDRESS_INACTIVE   EQU 54
CFG_ERR_BADDRESS_EEPROM_READ  EQU 55
CFG_ERR_BADDRESS_EEPROM_WRITE EQU 56
CFG_ERR_BADDRESS_VERIFY     EQU 57
CFG_ERR_BADDRESS_NOT_CAPABLE EQU 58
CFG_ERR_BAD_BSIZE           EQU 59
CFG_ERR_BSIZE_INACTIVE      EQU 60
CFG_ERR_BSIZE_EEPROM_READ   EQU 61
CFG_ERR_BSIZE_EEPROM_WRITE  EQU 62
CFG_ERR_BSIZE_VERIFY        EQU 63
CFG_ERR_BSIZE_NOT_CAPABLE   EQU 64
CFG_ERR_BOOTROM_INCOMPLETE  EQU 65
CFG_ERR_BAD_TR              EQU 66
CFG_ERR_TR_INACTIVE         EQU 67
CFG_ERR_TR_EEPROM_READ      EQU 68
CFG_ERR_TR_EEPROM_WRITE     EQU 69
CFG_ERR_TR_VERIFY           EQU 70
CFG_ERR_TR_NOT_CAPABLE      EQU 71
CFG_ERR_TR_CAPABILITY_READ  EQU 72
CFG_ERR_FD_CAPABILITY_READ  EQU 73
CFG_ERR_FD_TRANSCEIVER      EQU 74
CFG_ERR_FD_LIVE_UPDATE      EQU 75
CFG_ERR_FD_LIVE_VERIFY      EQU 76

DATASEG

include 'VERSION.INC'

msg_banner_prefix DB  "3Com EtherLink III CLI Configuration Program v", '$'
msg_banner_suffix DB  0Dh, 0Ah
                  DB  "by The Phintage Collector (Gianpaolo Del Matto)", 0Dh, 0Ah
                  DB  "https://github.com/gpdm/TPC-3CCFGCLI", 0Dh, 0Ah
                  DB  "reimplementation of the original 3Com EtherLink III Configuration Utility v3.2", 0Dh, 0Ah, 0Dh, 0Ah, '$'

msg_help        DB  "Usage: 3CCFGCLI [COMMAND]", 0Dh, 0Ah, 0Dh, 0Ah
                DB  "Commands:", 0Dh, 0Ah
                DB  "  /? or /H", 0Dh, 0Ah
                DB  "    Display this help screen.", 0Dh, 0Ah, 0Dh, 0Ah
                DB  "  LIST", 0Dh, 0Ah
                DB  "    Detect and display 3C509 and 3C509B adapters.", 0Dh, 0Ah, 0Dh, 0Ah
                DB  "  SAVECONFIG [/OUTPUTFILE:file] [/EXECFILE:program]", 0Dh, 0Ah
                DB  "    Export all adapter configurations to a restore batch file.", 0Dh, 0Ah
                DB  "    /OUTPUTFILE overrides the output batch file (default: RESTORE.BAT).", 0Dh, 0Ah
                DB  "    /EXECFILE overrides the embedded program name (default: self).", 0Dh, 0Ah, 0Dh, 0Ah
                DB  "  CONFIGURE [options]", 0Dh, 0Ah
                DB  "    Configure ISA adapter properties. Options:", 0Dh, 0Ah, 0Dh, 0Ah
                DB  "    /ADAPTERNUM:N                  Select adapter N (from LIST).", 0Dh, 0Ah
                DB  "    /INT:N                         Set IRQ (3,5,7,9,10,11,12,15).", 0Dh, 0Ah
                DB  "    /IOBASE:NNN                    Set ISA IOBASE address (hex).", 0Dh, 0Ah
                DB  "    /PNP:ENABLED|DISABLED          Plug and Play mode.", 0Dh, 0Ah
                DB  "    /FULLDUPLEX:ENABLED|DISABLED   Full duplex mode.", 0Dh, 0Ah
                DB  "    /TR:TP|AUI|COAX|AUTO           Transceiver type.", 0Dh, 0Ah
                DB  "    /XCVR:...                      Alias for /TR.", 0Dh, 0Ah
                DB  "    /MODEM:N|NONE                  Modem speed/interrupt-disable tuning.", 0Dh, 0Ah
                DB  "    /OPTIMIZE:DOS|WINDOWS|OS/2|SERVER", 0Dh, 0Ah
                DB  "                                   Network workload optimization.", 0Dh, 0Ah
                DB  "    /BADDRESS:NNNNN                Boot ROM base (hex, C0000-DE000,", 0Dh, 0Ah
                DB  "                                   2000h steps); requires /BSIZE.", 0Dh, 0Ah
                DB  "    /BSIZE:8|16|32|DISABLED       Boot ROM size in KB, or DISABLED;", 0Dh, 0Ah
                DB  "                                   a size requires /BADDRESS.", 0Dh, 0Ah
                DB  0Dh, 0Ah
                DB  "Global options (valid with any command):", 0Dh, 0Ah
                DB  "  /VERBOSE                       Show verbose transaction details.", 0Dh, 0Ah, '$'

msg_cli_dup_verbose DB "Duplicate /VERBOSE option.", 0Dh, 0Ah, '$'
msg_cli_too_many_args DB "Too many command line arguments.", 0Dh, 0Ah, '$'

msg_no_cards    DB  "No EtherLink III NICs are installed in this computer.", 0Dh, 0Ah, '$'
msg_id_eisa_unsupported DB "Adapter uses EISA addressing, which is not supported by this utility. Adapter skipped.", 0Dh, 0Ah, '$'
msg_save_missing DB "SAVECONFIG /OUTPUTFILE requires a value.", 0Dh, 0Ah, '$'
msg_save_bad_name DB "Invalid SAVECONFIG output filename.", 0Dh, 0Ah, '$'
msg_save_bad_option DB "Invalid SAVECONFIG option.", 0Dh, 0Ah, '$'
msg_save_dup_option DB "Duplicate SAVECONFIG option.", 0Dh, 0Ah, '$'
msg_save_bad_execfile DB "Invalid SAVECONFIG /EXECFILE value.", 0Dh, 0Ah, '$'
msg_save_execfile_not_found DB "SAVECONFIG /EXECFILE file not found.", 0Dh, 0Ah, '$'
msg_save_line_too_long DB "SAVECONFIG restore command line would exceed DOS batch line limit.", 0Dh, 0Ah, '$'
msg_save_no_active DB "SAVECONFIG found no adapters with an active IOBASE.", 0Dh, 0Ah, '$'
msg_save_read_fail DB "Unable to read adapter EEPROM for SAVECONFIG.", 0Dh, 0Ah, '$'
msg_save_write_fail DB "Unable to write SAVECONFIG output file.", 0Dh, 0Ah, '$'
msg_save_ok DB "Configuration restore batch file created: ", '$'

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
msg_cfg_bad_int DB "Invalid /INT parameter. Value must be either of", 0Dh, 0Ah
                DB "Systems with 8-bit Bus: 3, 5, 7", 0Dh, 0Ah
                DB "Systems with 16-bit Bus: 3, 5, 7, 9, 10, 11, 12, or 15.", 0Dh, 0Ah, '$'
msg_cfg_bad_pnp DB "Invalid /PNP parameter. Use ENABLED or DISABLED.", 0Dh, 0Ah, '$'
msg_cfg_bad_modem DB "Invalid /MODEM parameter. Use NONE, 1200, 2400, 9600, 19200, 38400, or 25-1600 in 25 increments.", 0Dh, 0Ah, '$'
msg_cfg_bad_optimize DB "Invalid /OPTIMIZE parameter. Use DOS, WINDOWS, OS/2, or SERVER.", 0Dh, 0Ah, '$'
msg_cfg_int_ok DB "INT parameter accepted. Requested IRQ: ", '$'
msg_cfg_pnp_ok DB "PNP parameter accepted. Requested Plug and Play mode: ", '$'
msg_cfg_modem_ok DB "MODEM parameter accepted. Requested setting: ", '$'
msg_cfg_adapter_prefix DB "Adapter ", '$'
msg_cfg_adapter_suffix DB " selected.", 0Dh, 0Ah, '$'
msg_cfg_current_irq DB "Current IRQ: ", '$'
msg_cfg_current_word09 DB "Current EEPROM word 09h: ", '$'
msg_cfg_current_word0d DB "Current EEPROM word 0Dh: ", '$'
msg_cfg_new_word09 DB "New EEPROM word 09h: ", '$'
msg_cfg_new_word0d DB "New EEPROM word 0Dh: ", '$'
msg_cfg_prepare_active DB 0Dh, 0Ah, "Preparing adapter using original ISA activation sequence...", 0Dh, 0Ah, '$'
msg_cfg_irq_unchanged DB 0Dh, 0Ah, "IRQ is already configured to the requested value.", 0Dh, 0Ah
                      DB "No hardware changes required.", 0Dh, 0Ah, '$'
msg_cfg_irq_word_written DB "IRQ configuration word written.", 0Dh, 0Ah, '$'
msg_cfg_update_checksum DB 0Dh, 0Ah, "Updating EEPROM checksum...", 0Dh, 0Ah, '$'
msg_cfg_checksum_updated DB "EEPROM checksum updated.", 0Dh, 0Ah, '$'
msg_cfg_eeprom_verified DB "EEPROM IRQ verified: ", '$'
msg_cfg_live_verified DB "Live IRQ verified: ", '$'
msg_cfg_completed DB 0Dh, 0Ah, "IRQ configuration completed successfully.", 0Dh, 0Ah, '$'
msg_cfg_eeprom_read_fail DB "EEPROM read timed out while reading IRQ configuration.", 0Dh, 0Ah, '$'
msg_cfg_eeprom_write_fail DB "EEPROM write timed out while writing IRQ configuration.", 0Dh, 0Ah, '$'
msg_cfg_checksum_fail DB "EEPROM checksum update failed.", 0Dh, 0Ah, '$'
msg_cfg_live_fail DB "Live IRQ configuration update failed.", 0Dh, 0Ah, '$'
msg_cfg_verify_fail DB "IRQ configuration verification failed.", 0Dh, 0Ah, '$'
msg_cfg_int_inactive DB "Selected adapter has no active IOBASE for /INT configuration.", 0Dh, 0Ah, '$'
msg_cfg_pnp_inactive DB "Selected adapter has no active IOBASE for /PNP configuration.", 0Dh, 0Ah, '$'
msg_cfg_modem_inactive DB "Selected adapter has no active IOBASE for /MODEM configuration.", 0Dh, 0Ah, '$'
msg_cfg_optimize_inactive DB "Selected adapter has no active IOBASE for /OPTIMIZE configuration.", 0Dh, 0Ah, '$'
msg_cfg_fd_inactive DB "Selected adapter has no active IOBASE for /FULLDUPLEX configuration.", 0Dh, 0Ah, '$'

; /IOBASE diagnostics.
msg_cfg_bad_iobase DB "Invalid /IOBASE parameter. Use hexadecimal 0200 through 03E0 in 10h increments.", 0Dh, 0Ah, '$'
msg_cfg_iobase_inactive DB "Selected adapter has no active IOBASE for /IOBASE configuration.", 0Dh, 0Ah, '$'
msg_cfg_iobase_conflict DB "Requested IOBASE is already used by another discovered adapter.", 0Dh, 0Ah, '$'
msg_cfg_iobase_deactivate_fail DB "Selected adapter deactivation failed before IOBASE migration.", 0Dh, 0Ah, '$'
msg_cfg_iobase_reactivate_fail DB "Adapter reactivation at the requested IOBASE failed.", 0Dh, 0Ah, '$'
msg_cfg_iobase_eeprom_read_fail DB "EEPROM read timed out while reading I/O configuration.", 0Dh, 0Ah, '$'
msg_cfg_iobase_eeprom_write_fail DB "EEPROM write timed out while writing I/O configuration.", 0Dh, 0Ah, '$'
msg_cfg_iobase_live_fail DB "Live I/O configuration access or update failed.", 0Dh, 0Ah, '$'
msg_cfg_iobase_verify_fail DB "IOBASE configuration verification failed.", 0Dh, 0Ah, '$'
msg_cfg_iobase_activate_fail DB "Adapter did not become reachable at the requested IOBASE.", 0Dh, 0Ah, '$'
msg_cfg_iobase_ok DB "IOBASE parameter accepted. Requested IOBASE: ", '$'
msg_cfg_current_iobase DB "Current persistent IOBASE: ", '$'
msg_cfg_current_live_iobase DB "Current live IOBASE: ", '$'
msg_cfg_current_word08 DB "Current EEPROM word 08h: ", '$'
msg_cfg_current_live06 DB "Current live Address Configuration: ", '$'
msg_cfg_current_live08 DB "Current live Resource Configuration: ", '$'
msg_cfg_new_word08 DB "New EEPROM word 08h: ", '$'
msg_cfg_new_live06 DB "New live Address Configuration: ", '$'
msg_cfg_new_live08 DB "New live Resource Configuration: ", '$'
msg_cfg_iobase_unchanged DB 0Dh, 0Ah, "IOBASE is already configured to the requested value.", 0Dh, 0Ah
                         DB "No IOBASE hardware changes required.", 0Dh, 0Ah, '$'
msg_cfg_deactivate_iobase DB 0Dh, 0Ah, "Deactivating selected adapter at old IOBASE...", 0Dh, 0Ah, '$'
msg_cfg_reactivate_iobase DB "Reactivating adapter at requested IOBASE...", 0Dh, 0Ah, '$'
msg_cfg_iobase_word_written DB "I/O configuration word written.", 0Dh, 0Ah, '$'
msg_cfg_eeprom_iobase_verified DB "EEPROM IOBASE verified: ", '$'
msg_cfg_live_iobase_verified DB "Live IOBASE verified: ", '$'
msg_cfg_iobase_completed DB 0Dh, 0Ah, "IOBASE configuration completed successfully.", 0Dh, 0Ah, '$'
msg_cfg_combined_completed DB 0Dh, 0Ah, "IOBASE and IRQ configuration completed successfully.", 0Dh, 0Ah, '$'
msg_cfg_pnp_unchanged DB 0Dh, 0Ah, "Plug and Play mode is already configured to the requested value.", 0Dh, 0Ah
                      DB "No hardware changes required.", 0Dh, 0Ah, '$'
msg_cfg_pnp_word_written DB "Plug and Play configuration word written.", 0Dh, 0Ah, '$'
msg_cfg_pnp_eeprom_read_fail DB "EEPROM read timed out while reading Plug and Play configuration.", 0Dh, 0Ah, '$'
msg_cfg_pnp_eeprom_write_fail DB "EEPROM write timed out while writing Plug and Play configuration.", 0Dh, 0Ah, '$'
msg_cfg_pnp_verified DB "EEPROM Plug and Play mode verified.", 0Dh, 0Ah, '$'
msg_cfg_pnp_verify_fail DB "Plug and Play configuration verification failed.", 0Dh, 0Ah, '$'
msg_cfg_pnp_completed DB 0Dh, 0Ah, "Plug and Play configuration completed successfully.", 0Dh, 0Ah, '$'
msg_cfg_modem_unchanged DB 0Dh, 0Ah, "Modem speed setting is already configured to the requested value.", 0Dh, 0Ah
                        DB "No hardware changes required.", 0Dh, 0Ah, '$'
msg_cfg_modem_word_written DB "Modem speed configuration word written.", 0Dh, 0Ah, '$'
msg_cfg_modem_eeprom_read_fail DB "EEPROM read timed out while reading modem speed configuration.", 0Dh, 0Ah, '$'
msg_cfg_modem_eeprom_write_fail DB "EEPROM write timed out while writing modem speed configuration.", 0Dh, 0Ah, '$'
msg_cfg_modem_verified DB "EEPROM modem speed setting verified.", 0Dh, 0Ah, '$'
msg_cfg_modem_verify_fail DB "Modem speed configuration verification failed.", 0Dh, 0Ah, '$'
msg_cfg_modem_completed DB 0Dh, 0Ah, "Modem speed configuration completed successfully.", 0Dh, 0Ah, '$'
msg_cfg_optimize_unchanged DB 0Dh, 0Ah, "Optimize mode is already configured to the requested value.", 0Dh, 0Ah
                      DB "No hardware changes required.", 0Dh, 0Ah, '$'
msg_cfg_optimize_eeprom_read_fail DB "EEPROM read timed out while reading optimize configuration.", 0Dh, 0Ah, '$'
msg_cfg_optimize_eeprom_write_fail DB "EEPROM write timed out while writing optimize configuration.", 0Dh, 0Ah, '$'
msg_cfg_optimize_verified DB "EEPROM optimize mode verified.", 0Dh, 0Ah, '$'
msg_cfg_optimize_verify_fail DB "Optimize mode configuration verification failed.", 0Dh, 0Ah, '$'
msg_cfg_pnp_not_capable DB "This adapter does not support Plug and Play configuration.", 0Dh, 0Ah, '$'
msg_cfg_bad_fullduplex DB "Invalid /FULLDUPLEX parameter. Use ENABLED or DISABLED.", 0Dh, 0Ah, '$'
msg_cfg_fullduplex_ok DB "FULLDUPLEX parameter accepted. Requested mode: ", '$'
msg_cfg_fd_unchanged DB 0Dh, 0Ah, "Full duplex mode is already configured to the requested value.", 0Dh, 0Ah
                     DB "No hardware changes required.", 0Dh, 0Ah, '$'
msg_cfg_fd_word_written DB "Full duplex configuration word written.", 0Dh, 0Ah, '$'
msg_cfg_fd_eeprom_read_fail DB "EEPROM read timed out while reading full duplex configuration.", 0Dh, 0Ah, '$'
msg_cfg_fd_eeprom_write_fail DB "EEPROM write timed out while writing full duplex configuration.", 0Dh, 0Ah, '$'
msg_cfg_fd_verified DB "EEPROM full duplex mode verified.", 0Dh, 0Ah, '$'
msg_cfg_fd_live_verified DB "Live Network Diagnostic full duplex mode verified.", 0Dh, 0Ah, '$'
msg_cfg_fd_verify_fail DB "Full duplex configuration verification failed.", 0Dh, 0Ah, '$'
msg_cfg_fd_completed DB 0Dh, 0Ah, "Full duplex configuration completed successfully.", 0Dh, 0Ah, '$'
msg_cfg_fd_not_capable DB "This adapter does not support full duplex configuration.", 0Dh, 0Ah, '$'
msg_cfg_fd_capability_read_fail DB "Hardware capability data is unavailable for full duplex configuration.", 0Dh, 0Ah, '$'
msg_cfg_fd_transceiver DB "Full duplex can only be enabled with the TP transceiver.", 0Dh, 0Ah, '$'
msg_cfg_fd_live_update_fail DB "Live full duplex hardware update failed.", 0Dh, 0Ah, '$'
msg_cfg_fd_live_verify_fail DB "Live full duplex hardware verification failed.", 0Dh, 0Ah, '$'

; /BADDRESS and /BSIZE diagnostics.  Both share EEPROM word 08h (bits 11:8
; and 13:12) with /IOBASE (bits 4:0); see Cfg_Prepare_BADDRESS/BSIZE.
msg_cfg_bad_baddress DB "Invalid /BADDRESS parameter. Use a hex address C0000-DE000 in 2000h steps.", 0Dh, 0Ah, '$'
msg_cfg_bad_bsize DB "Invalid /BSIZE parameter. Use 8, 16, 32, or DISABLED.", 0Dh, 0Ah, '$'
msg_cfg_bootrom_incomplete DB "/BADDRESS and /BSIZE must be specified together (or use /BSIZE:DISABLED alone to disable).", 0Dh, 0Ah, '$'
msg_cfg_baddress_ok DB "BADDRESS parameter accepted. Requested base address: ", '$'
msg_cfg_bsize_ok DB "BSIZE parameter accepted. Requested size: ", '$'
msg_cfg_baddress_inactive DB "Selected adapter has no active IOBASE for /BADDRESS configuration.", 0Dh, 0Ah, '$'
msg_cfg_bsize_inactive DB "Selected adapter has no active IOBASE for /BSIZE configuration.", 0Dh, 0Ah, '$'
msg_cfg_baddress_unchanged DB 0Dh, 0Ah, "Boot ROM base address is already configured to the requested value.", 0Dh, 0Ah
                           DB "No hardware changes required.", 0Dh, 0Ah, '$'
msg_cfg_bsize_unchanged DB 0Dh, 0Ah, "Boot ROM size is already configured to the requested value.", 0Dh, 0Ah
                        DB "No hardware changes required.", 0Dh, 0Ah, '$'
msg_cfg_bootrom_word_written DB "Boot ROM configuration word written.", 0Dh, 0Ah, '$'
msg_cfg_baddress_eeprom_read_fail DB "EEPROM read timed out while reading Boot ROM base address configuration.", 0Dh, 0Ah, '$'
msg_cfg_baddress_eeprom_write_fail DB "EEPROM write timed out while writing Boot ROM base address configuration.", 0Dh, 0Ah, '$'
msg_cfg_baddress_verified DB "EEPROM Boot ROM base address verified.", 0Dh, 0Ah, '$'
msg_cfg_baddress_verify_fail DB "Boot ROM base address configuration verification failed.", 0Dh, 0Ah, '$'
msg_cfg_baddress_not_capable DB "This adapter does not support Boot ROM configuration.", 0Dh, 0Ah, '$'
msg_cfg_bsize_eeprom_read_fail DB "EEPROM read timed out while reading Boot ROM size configuration.", 0Dh, 0Ah, '$'
msg_cfg_bsize_eeprom_write_fail DB "EEPROM write timed out while writing Boot ROM size configuration.", 0Dh, 0Ah, '$'
msg_cfg_bsize_verified DB "EEPROM Boot ROM size verified.", 0Dh, 0Ah, '$'
msg_cfg_bsize_verify_fail DB "Boot ROM size configuration verification failed.", 0Dh, 0Ah, '$'
msg_cfg_bsize_not_capable DB "This adapter does not support Boot ROM configuration.", 0Dh, 0Ah, '$'

; /TR (/XCVR) diagnostics.  Transceiver selection shares EEPROM word 08h
; bits 15:14 (and bit 7 for AUTO) with /IOBASE, /BADDRESS, and /BSIZE.
msg_cfg_bad_tr DB "Invalid /TR parameter. Use TP, AUI, COAX, or AUTO.", 0Dh, 0Ah, '$'
msg_cfg_tr_inactive DB "Selected adapter has no active IOBASE for /TR configuration.", 0Dh, 0Ah, '$'
msg_cfg_tr_not_capable DB "This adapter does not support the requested transceiver type.", 0Dh, 0Ah, '$'
msg_cfg_tr_capability_read_fail DB "Hardware connector capability data is unavailable for transceiver configuration.", 0Dh, 0Ah, '$'
msg_cfg_tr_ok DB "TR parameter accepted. Requested transceiver: ", '$'
msg_cfg_tr_unchanged DB 0Dh, 0Ah, "Transceiver type is already configured to the requested value.", 0Dh, 0Ah
               DB "No hardware changes required.", 0Dh, 0Ah, '$'
msg_cfg_tr_eeprom_read_fail DB "EEPROM read timed out while reading transceiver configuration.", 0Dh, 0Ah, '$'
msg_cfg_tr_eeprom_write_fail DB "EEPROM write timed out while writing transceiver configuration.", 0Dh, 0Ah, '$'
msg_cfg_tr_verify_fail DB "Transceiver configuration verification failed.", 0Dh, 0Ah, '$'

; Symbolic transceiver names used for /TR echo output.
msg_tr_tp   DB "TP", '$'
msg_tr_aui  DB "AUI", '$'
msg_tr_coax DB "COAX", '$'
msg_tr_auto DB "AUTO", '$'
msg_cfg_txn_completed DB 0Dh, 0Ah, "Configuration completed successfully.", 0Dh, 0Ah, '$'
msg_cfg_txn_read DB 0Dh, 0Ah, "Reading current configuration...", 0Dh, 0Ah, '$'
msg_cfg_txn_prepare DB 0Dh, 0Ah, "Preparing requested configuration...", 0Dh, 0Ah, '$'
msg_cfg_txn_no_changes DB "No hardware changes required.", 0Dh, 0Ah, '$'
msg_cfg_txn_write DB 0Dh, 0Ah, "Writing changed EEPROM configuration...", 0Dh, 0Ah, '$'
msg_cfg_txn_live DB 0Dh, 0Ah, "Synchronizing live configuration...", 0Dh, 0Ah, '$'
msg_cfg_txn_verify DB 0Dh, 0Ah, "Verifying requested configuration...", 0Dh, 0Ah, '$'
msg_cfg_txn_current_active_base DB "Current active IOBASE: ", '$'
msg_cfg_txn_current_live_irq DB "Current live IRQ: ", '$'
msg_cfg_txn_new_base DB "Prospective active IOBASE: ", '$'
msg_cfg_txn_reachable DB "Adapter reachable at active IOBASE: ", '$'

msg_list_hdr    DB  "NIC                            NIC", 0Dh, 0Ah
                DB  "Number                       Description", 0Dh, 0Ah
                DB  "--------------------------------------------------------------------------", 0Dh, 0Ah, '$'

; Original generic NIC description resources.
; Only the ISA 3C509 family selector is reachable in this reduced build.
msg_a02c        DB  "EtherLink III 16-bit ISA NIC", '$'

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
msg_iobase      DB  "IOBASE = ", '$'
msg_irq         DB  ", IRQ = ", '$'
msg_no_io       DB  "unassigned", '$'

msg_asic_label  DB  "ASIC Revision = ", '$'
msg_xcvr_label  DB  "Transceiver = ", '$'
msg_pnp_label   DB  "Plug and Play Capability = ", '$'
msg_pnp_state_label DB "Plug and Play = ", '$'
msg_connectors_label DB "Connectors = ", '$'
msg_fd_capability_label DB "Full Duplex Capability = ", '$'
msg_boot_label  DB  "Boot ROM = ", '$'
msg_compat_label DB "Software Compatibility = failure level ", '$'
msg_optimize_label DB "Optimization = ", '$'
msg_modem_label DB "MODEM Interrupt Disable Time = ", '$'
msg_modem_us DB " us", '$'
msg_modem_38400 DB " (38400 bd)", '$'
msg_modem_19200 DB " (19200 bd)", '$'
msg_modem_9600 DB " (9600 bd)", '$'
msg_modem_2400 DB " (2400 bd)", '$'
msg_modem_1200 DB " (1200 bd)", '$'
msg_modem_none DB " (NONE)", '$'
msg_modem_not_representable DB " (not representable by CLI)", '$'
msg_fullduplex_label DB "Full Duplex = ", '$'
msg_link_status_label DB "Link Status = ", '$'
msg_optimize_reserved DB "Reserved", '$'
msg_optimize_dos DB "DOS", '$'
msg_optimize_windows_or_os2 DB "Windows or OS/2", '$'
msg_optimize_server DB "Server", '$'
msg_warn_label  DB  ", warning level ", '$'

msg_enabled     DB  "enabled", '$'
msg_disabled    DB  "disabled", '$'
msg_yes         DB  "yes", '$'
msg_no          DB  "no", '$'
msg_none        DB  "none", '$'
msg_not_supported DB "not supported", '$'
msg_unavailable DB  "unavailable", '$'
msg_link_connected     DB "connected", '$'
msg_link_not_connected DB "not connected", '$'
msg_invalid_cfg DB  "invalid configuration", '$'
msg_onboard_tp  DB  "on-board TP", '$'
msg_external    DB  "external", '$'
msg_onboard_coax DB "on-board coax", '$'
msg_auto_select DB  "auto select", '$'
msg_unknown_value DB "unknown", '$'
msg_at          DB  "K at ", '$'
msg_hex_suffix  DB  "H", '$'
msg_kilobytes_suffix DB "K", '$'
msg_crlf        DB  0Dh, 0Ah, '$'
msg_separator   DB  "       ---", 0Dh, 0Ah, '$'
msg_connector_separator DB ", ", '$'

card_count      DW  0
current_card    DW  0
nic_table       DB  (MAX_CARDS * NIC_RECORD_SIZE) DUP(0)

; Discovery state.
id_short_mode   DB  1
id_next_tag     DB  1
id_product      DW  0
id_oem0         DW  0
id_oem1         DW  0
id_oem2         DW  0
id_addr_cfg     DW  0
id_resource_cfg DW  0

; Temporary live EEPROM values used only by the LIST output.
; These are deliberately separate from nic_table so the known good 16 byte
; enumeration record layout remains unchanged.
ext_addr_cfg      DW 0FFFFh
ext_compatibility DW 0FFFFh
ext_capability    DW 0FFFFh
ext_config_ctrl   DW 0FFFFh
ext_nic_capabilities DW 0FFFFh
ext_nic_capability_valid DW 0
ext_revision_info DW 0FFFFh
ext_optimize      DW 0FFFFh
; Live link status (Window 4/Port 0Ah bit 11); 0 = not connected,
; 1 = connected, 0FFFFh = unavailable (adapter not active).
ext_link_status   DW 0FFFFh
; Raw EEPROM_SOFTWARE_INFO (word 0Dh).  /MODEM uses only its Maximum Interrupt
; Disable Time field, bits 13:8.
ext_software_info DW 0FFFFh
; Global CLI parser state.  cli_arg_ptrs holds pointers into cmd_buffer for
; the verb specific argument tokens that remain after global options have
; been consumed.  Argument text is never copied; each token is delimited in
; place by whitespace or the terminating NUL.
cli_flags             DW 0
cli_arg_ptrs          DW CLI_MAX_ARGS DUP(0)
cli_arg_count         DW 0
cli_arg_index         DW 0

; CONFIGURE state.  nic_table itself is deliberately not extended.
cfg_adapter_ordinal   DB 0
cfg_parse_flags       DW 0
cfg_seen_flags        DW 0
cfg_property_count    DB 0
cfg_last_error        DB CFG_ERR_NONE
cfg_timeout_latched   DB 0
cfg_selected_ptr      DW 0
cfg_queue_property_id DB 0
; Ordered CONFIGURE hardware-property requests.  Value spans point into the
; original command tail, which remains unchanged until command completion.
cfg_property_requests DB CFG_MAX_PROPERTY_REQUESTS * CFG_PROPERTY_REQUEST_SIZE DUP (0)

; Staged property requests.  Handlers write only these values and parse flags.
cfg_int_value         DB 0
cfg_iobase_value      DW 0
cfg_pnp_value         DB 0
cfg_modem_value       DW 0
cfg_fullduplex_value  DB 0
cfg_optimize_value    DB 0
; cfg_baddress_value: raw 0-15 Boot ROM base index
; (address = 0C0000h + index*2000h).
; cfg_bsize_value: 0/1/2 = 8/16/32K, meaningful only when cfg_bsize_disabled=0.
; cfg_bsize_disabled is the /BSIZE:DISABLED sentinel, since value zero is a
; valid size (8K) as well as a valid base index.
cfg_baddress_value    DB 0
cfg_bsize_value       DB 0
cfg_bsize_disabled    DB 0
; cfg_tr_value: 0=TP, 1=AUI, 3=COAX, 0FFh=AUTO sentinel.
cfg_tr_value          DB 0

; Central CONFIGURE transaction state.  Current state is snapshotted before any
; hardware modification.  Prospective state starts as an exact copy and is then
; modified only by Cfg_Prepare_*** routines.
cfg_txn_old_base          DW 0
cfg_txn_new_base          DW 0
cfg_txn_old_word08        DW 0
cfg_txn_new_word08        DW 0
cfg_txn_old_word09        DW 0
cfg_txn_new_word09        DW 0
cfg_txn_old_word0d        DW 0
cfg_txn_new_word0d        DW 0
cfg_txn_old_word13        DW 0
cfg_txn_new_word13        DW 0
cfg_txn_old_live06        DW 0
cfg_txn_new_live06        DW 0
cfg_txn_old_live08        DW 0
cfg_txn_new_live08        DW 0
cfg_txn_old_word0f        DW 0
cfg_txn_new_word0f        DW 0
cfg_txn_checksum_word     DW 0
cfg_txn_io_selector       DB 0
cfg_txn_old_io_selector   DB 0
cfg_txn_live_io_selector  DB 0
cfg_txn_old_irq           DB 0
cfg_txn_live_irq          DB 0
cfg_txn_change_flags      DW 0
cfg_txn_checksum          DB 0
cfg_txn_activation_needed DB 0

cfg_wait_start_lo     DW 0
cfg_wait_start_hi     DW 0

; Original CONFIGURE property order is retained for prefix resolution.
cfg_name_adapternum DB 'ADAPTERNUM', 0
cfg_name_int        DB 'INT', 0
cfg_name_iobase     DB 'IOBASE', 0
cfg_name_baddress   DB 'BADDRESS', 0
cfg_name_bsize      DB 'BSIZE', 0
cfg_name_tr         DB 'TR', 0
cfg_name_xcvr       DB 'XCVR', 0
cfg_name_modem      DB 'MODEM', 0
cfg_name_optimize   DB 'OPTIMIZE', 0
cfg_name_pnp        DB 'PNP', 0
cfg_name_fullduplex DB 'FULLDUPLEX', 0

cfg_property_names DW OFFSET cfg_name_int
                   DW OFFSET cfg_name_iobase
                   DW OFFSET cfg_name_baddress
                   DW OFFSET cfg_name_bsize
                   DW OFFSET cfg_name_tr
                   DW OFFSET cfg_name_xcvr
                   DW OFFSET cfg_name_modem
                   DW OFFSET cfg_name_optimize
                   DW OFFSET cfg_name_pnp
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
                 DB CFG_OPT_PNP
                 DB CFG_OPT_FULLDUPLEX

SAVE_MAX_BATCH_LINE EQU 128
SAVE_BUFFER_SIZE EQU SAVE_MAX_BATCH_LINE + 2 ; generated command text + CR + LF
SAVE_EXECFILE_RUNTIME_RESERVE EQU 64
SAVE_ERR_NONE EQU 0
SAVE_ERR_WRITE EQU 1
SAVE_ERR_LINE_TOO_LONG EQU 2
SAVE_ERR_BAD_EXECFILE EQU 3

; All 31 valid selectable 3C509 ISA I O bases.
; EEPROM Address Configuration bits 4 to 0 encode indexes 0 through 30.
; Index 31 means no assigned base, therefore 03F0h is not a valid selection.
io_scan_table   DW  0300h, 0310h, 0320h, 0330h, 0340h, 0350h, 0360h, 0370h
                DW  0380h, 0390h, 03A0h, 03B0h, 03C0h, 03D0h, 03E0h
                DW  0200h, 0210h, 0220h, 0230h, 0240h, 0250h, 0260h, 0270h
                DW  0280h, 0290h, 02A0h, 02B0h, 02C0h, 02D0h, 02E0h, 02F0h
                DW  0000h

cmd_buffer      DB  128 DUP(0)
save_filename   DB  128 DUP(0)
save_execname   DB  65 DUP(0)
save_execname_default DB '3CCFGCLI.EXE', 0
save_filename_default DB 'RESTORE.BAT', 0
save_outputfile_kw DB 'OUTPUTFILE:', 0
cli_kw_help     DB 'HELP', 0
cli_kw_list     DB 'LIST', 0
cli_kw_saveconfig DB 'SAVECONFIG', 0
cli_kw_configure DB 'CONFIGURE', 0
cli_kw_verbose  DB 'VERBOSE', 0
save_execfile_kw DB 'EXECFILE:', 0
save_buffer     DB  SAVE_BUFFER_SIZE DUP(0)
save_length     DW  0
save_argument_length DW 0
save_max_argument_length DW 0
save_execname_length DW 0
save_execfile_supplied DB 0
save_outputfile_supplied DB 0
save_execfile_placeholder DB 0
save_error      DB  0
save_handle     DW  0
save_file_open  DB  0
save_adapter_num DW 0
save_word08     DW  0
save_word09     DW  0
save_word0d     DW  0
save_word13     DW  0
save_configure_suffix DB ' CONFIGURE', 0
save_adapternum DB  ' /ADAPTERNUM:', 0
save_int        DB  ' /INT:', 0
SAVE_LEN_INT EQU 6
save_iobase     DB  ' /IOBASE:', 0
SAVE_LEN_IOBASE EQU 9
save_pnp        DB  ' /PNP:', 0
SAVE_LEN_PNP EQU 6
save_fd         DB  ' /FULLDUPLEX:', 0
SAVE_LEN_FD EQU 13
save_modem      DB  ' /MODEM:', 0
SAVE_LEN_MODEM EQU 8
save_optimize   DB  ' /OPTIMIZE:', 0
SAVE_LEN_OPTIMIZE EQU 11
save_baddress   DB  ' /BADDRESS:', 0
SAVE_LEN_BADDRESS EQU 11
save_bsize      DB  ' /BSIZE:', 0
SAVE_LEN_BSIZE EQU 8
save_tr         DB  ' /TR:', 0
SAVE_LEN_TR EQU 5
save_none       DB  'NONE', 0
SAVE_LEN_NONE EQU 4
save_enabled    DB  'ENABLED', 0
SAVE_LEN_ENABLED EQU 7
save_disabled   DB  'DISABLED', 0
SAVE_LEN_DISABLED EQU 8
save_dos        DB  'DOS', 0
SAVE_LEN_DOS EQU 3
save_windows_os2        DB  'Windows or OS/2', 0
SAVE_LEN_WINDOWS_OS2 EQU 15
save_server     DB  'SERVER', 0
SAVE_LEN_SERVER EQU 6
save_tp         DB  'TP', 0
SAVE_LEN_TP EQU 2
save_aui        DB  'AUI', 0
SAVE_LEN_AUI EQU 3
save_coax       DB  'COAX', 0
SAVE_LEN_COAX EQU 4
save_auto       DB  'AUTO', 0
SAVE_LEN_AUTO EQU 4

; ---------------------------------------------------------------------------
; CONFIGURE error message dispatch table.
;
; CFG_ERR_* values are stable indices into cfg_error_messages.
; Do not renumber existing values.
; Retired values keep a zero table entry.
; A zero entry means "no message"; Cfg_Report_Error prints nothing for it.
;
; Example: if CFG_ERR_FOO EQU 50 is retired, table entry 50 becomes
;              DW 0
;          and entries 51 and above stay at their original indices.
;          Never delete a slot, as that would shift every later entry and
;          silently remap all following error codes to the wrong message.
;
; The valid index range is derived from the table itself via CFG_ERR_COUNT,
; so appending or removing the last entry needs no other edit.
; ---------------------------------------------------------------------------

LABEL cfg_error_messages WORD
    DW      0                                             ; 0 CFG_ERR_NONE
    DW      OFFSET msg_no_cards                          ; 1 CFG_ERR_NO_NIC
    DW      OFFSET msg_cfg_bad_adapter                   ; 2 CFG_ERR_BAD_ADAPTER
    DW      OFFSET msg_cfg_revalidate                    ; 3 CFG_ERR_REVALIDATE
    DW      OFFSET msg_cfg_unsupported_product           ; 4 CFG_ERR_UNSUPPORTED_PRODUCT
    DW      OFFSET msg_cfg_unsupported_asic              ; 5 CFG_ERR_UNSUPPORTED_ASIC
    DW      OFFSET msg_cfg_eeprom_timeout                ; 6 CFG_ERR_EEPROM_TIMEOUT
    DW      OFFSET msg_cfg_command_timeout               ; 7 CFG_ERR_COMMAND_TIMEOUT
    DW      OFFSET msg_cfg_bad_option                    ; 8 CFG_ERR_BAD_OPTION
    DW      OFFSET msg_cfg_missing_value                 ; 9 CFG_ERR_MISSING_VALUE
    DW      OFFSET msg_cfg_not_implemented               ; 10 CFG_ERR_NOT_IMPLEMENTED
    DW      OFFSET msg_cfg_need_adapter                  ; 11 CFG_ERR_ADAPTER_REQUIRED
    DW      OFFSET msg_cfg_dup_property                  ; 12 CFG_ERR_DUP_PROPERTY
    DW      OFFSET msg_cfg_no_property                   ; 13 CFG_ERR_NO_PROPERTY
    DW      OFFSET msg_cfg_bad_int                       ; 14 CFG_ERR_BAD_INT
    DW      OFFSET msg_cfg_eeprom_read_fail              ; 15 CFG_ERR_EEPROM_READ
    DW      OFFSET msg_cfg_eeprom_write_fail             ; 16 CFG_ERR_EEPROM_WRITE
    DW      OFFSET msg_cfg_checksum_fail                 ; 17 CFG_ERR_CHECKSUM_UPDATE
    DW      OFFSET msg_cfg_live_fail                     ; 18 CFG_ERR_LIVE_UPDATE
    DW      OFFSET msg_cfg_verify_fail                   ; 19 CFG_ERR_VERIFY
    DW      OFFSET msg_cfg_int_inactive                  ; 20 CFG_ERR_INT_INACTIVE
    DW      OFFSET msg_cfg_bad_iobase                    ; 21 CFG_ERR_BAD_IOBASE
    DW      OFFSET msg_cfg_iobase_inactive               ; 22 CFG_ERR_IOBASE_INACTIVE
    DW      OFFSET msg_cfg_iobase_conflict               ; 23 CFG_ERR_IOBASE_CONFLICT
    DW      OFFSET msg_cfg_iobase_deactivate_fail        ; 24 CFG_ERR_IOBASE_DEACTIVATE
    DW      OFFSET msg_cfg_iobase_reactivate_fail        ; 25 CFG_ERR_IOBASE_REACTIVATE
    DW      OFFSET msg_cfg_iobase_eeprom_read_fail       ; 26 CFG_ERR_IOBASE_EEPROM_READ
    DW      OFFSET msg_cfg_iobase_eeprom_write_fail      ; 27 CFG_ERR_IOBASE_EEPROM_WRITE
    DW      OFFSET msg_cfg_iobase_live_fail              ; 28 CFG_ERR_IOBASE_LIVE
    DW      OFFSET msg_cfg_iobase_verify_fail            ; 29 CFG_ERR_IOBASE_VERIFY
    DW      OFFSET msg_cfg_iobase_activate_fail          ; 30 CFG_ERR_IOBASE_ACTIVATE
    DW      OFFSET msg_cfg_bad_pnp                       ; 31 CFG_ERR_BAD_PNP
    DW      OFFSET msg_cfg_pnp_inactive                  ; 32 CFG_ERR_PNP_INACTIVE
    DW      OFFSET msg_cfg_pnp_eeprom_read_fail          ; 33 CFG_ERR_PNP_EEPROM_READ
    DW      OFFSET msg_cfg_pnp_eeprom_write_fail         ; 34 CFG_ERR_PNP_EEPROM_WRITE
    DW      OFFSET msg_cfg_pnp_verify_fail               ; 35 CFG_ERR_PNP_VERIFY
    DW      OFFSET msg_cfg_bad_modem                     ; 36 CFG_ERR_BAD_MODEM
    DW      OFFSET msg_cfg_modem_inactive                ; 37 CFG_ERR_MODEM_INACTIVE
    DW      OFFSET msg_cfg_modem_eeprom_read_fail        ; 38 CFG_ERR_MODEM_EEPROM_READ
    DW      OFFSET msg_cfg_modem_eeprom_write_fail       ; 39 CFG_ERR_MODEM_EEPROM_WRITE
    DW      OFFSET msg_cfg_modem_verify_fail             ; 40 CFG_ERR_MODEM_VERIFY
    DW      OFFSET msg_cfg_pnp_not_capable               ; 41 CFG_ERR_PNP_NOT_CAPABLE
    DW      OFFSET msg_cfg_bad_fullduplex                ; 42 CFG_ERR_BAD_FULLDUPLEX
    DW      OFFSET msg_cfg_fd_inactive                   ; 43 CFG_ERR_FD_INACTIVE
    DW      OFFSET msg_cfg_fd_eeprom_read_fail           ; 44 CFG_ERR_FD_EEPROM_READ
    DW      OFFSET msg_cfg_fd_eeprom_write_fail          ; 45 CFG_ERR_FD_EEPROM_WRITE
    DW      OFFSET msg_cfg_fd_verify_fail                ; 46 CFG_ERR_FD_VERIFY
    DW      OFFSET msg_cfg_fd_not_capable                ; 47 CFG_ERR_FD_NOT_CAPABLE
    DW      OFFSET msg_cfg_bad_optimize                  ; 48 CFG_ERR_BAD_OPTIMIZE
    DW      OFFSET msg_cfg_optimize_inactive             ; 49 CFG_ERR_OPTIMIZE_INACTIVE
    DW      OFFSET msg_cfg_optimize_eeprom_read_fail     ; 50 CFG_ERR_OPTIMIZE_EEPROM_READ
    DW      OFFSET msg_cfg_optimize_eeprom_write_fail    ; 51 CFG_ERR_OPTIMIZE_EEPROM_WRITE
    DW      OFFSET msg_cfg_optimize_verify_fail          ; 52 CFG_ERR_OPTIMIZE_VERIFY
    DW      OFFSET msg_cfg_bad_baddress                  ; 53 CFG_ERR_BAD_BADDRESS
    DW      OFFSET msg_cfg_baddress_inactive             ; 54 CFG_ERR_BADDRESS_INACTIVE
    DW      OFFSET msg_cfg_baddress_eeprom_read_fail     ; 55 CFG_ERR_BADDRESS_EEPROM_READ
    DW      OFFSET msg_cfg_baddress_eeprom_write_fail    ; 56 CFG_ERR_BADDRESS_EEPROM_WRITE
    DW      OFFSET msg_cfg_baddress_verify_fail          ; 57 CFG_ERR_BADDRESS_VERIFY
    DW      OFFSET msg_cfg_baddress_not_capable          ; 58 CFG_ERR_BADDRESS_NOT_CAPABLE
    DW      OFFSET msg_cfg_bad_bsize                     ; 59 CFG_ERR_BAD_BSIZE
    DW      OFFSET msg_cfg_bsize_inactive                ; 60 CFG_ERR_BSIZE_INACTIVE
    DW      OFFSET msg_cfg_bsize_eeprom_read_fail        ; 61 CFG_ERR_BSIZE_EEPROM_READ
    DW      OFFSET msg_cfg_bsize_eeprom_write_fail       ; 62 CFG_ERR_BSIZE_EEPROM_WRITE
    DW      OFFSET msg_cfg_bsize_verify_fail             ; 63 CFG_ERR_BSIZE_VERIFY
    DW      OFFSET msg_cfg_bsize_not_capable             ; 64 CFG_ERR_BSIZE_NOT_CAPABLE
    DW      OFFSET msg_cfg_bootrom_incomplete            ; 65 CFG_ERR_BOOTROM_INCOMPLETE
    DW      OFFSET msg_cfg_bad_tr                        ; 66 CFG_ERR_BAD_TR
    DW      OFFSET msg_cfg_tr_inactive                   ; 67 CFG_ERR_TR_INACTIVE
    DW      OFFSET msg_cfg_tr_eeprom_read_fail           ; 68 CFG_ERR_TR_EEPROM_READ
    DW      OFFSET msg_cfg_tr_eeprom_write_fail          ; 69 CFG_ERR_TR_EEPROM_WRITE
    DW      OFFSET msg_cfg_tr_verify_fail                ; 70 CFG_ERR_TR_VERIFY
    DW      OFFSET msg_cfg_tr_not_capable                ; 71 CFG_ERR_TR_NOT_CAPABLE
    DW      OFFSET msg_cfg_tr_capability_read_fail       ; 72 CFG_ERR_TR_CAPABILITY_READ
    DW      OFFSET msg_cfg_fd_capability_read_fail       ; 73 CFG_ERR_FD_CAPABILITY_READ
    DW      OFFSET msg_cfg_fd_transceiver                ; 74 CFG_ERR_FD_TRANSCEIVER
    DW      OFFSET msg_cfg_fd_live_update_fail           ; 75 CFG_ERR_FD_LIVE_UPDATE
    DW      OFFSET msg_cfg_fd_live_verify_fail           ; 76 CFG_ERR_FD_LIVE_VERIFY
LABEL cfg_error_messages_end WORD

CFG_ERR_COUNT   = (cfg_error_messages_end - cfg_error_messages) / 2

CODESEG

; ---------------------------------------------------------------------------
; Backend selection.  The real hardware interface is the default build, but a
; mock backend can be selected at compile time by defining /dMOCKHW.
; ---------------------------------------------------------------------------
IFDEF REALHW
    include '3CHWIF.ASM'
ENDIF

IFDEF MOCKHW
    include '3CMOCKIF.ASM'
ENDIF

IFNDEF REALHW
IFNDEF MOCKHW
    REALHW EQU 1
    include '3CHWIF.ASM'
ENDIF
ENDIF

; Hardware-independent ID-port EEPROM transfer.  The backend only supplies
; one contention bit for each input cycle; assembly remains identical on a
; physical adapter and the device model.
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

    mov     bx, OFFSET cli_kw_help
    call    Cli_Match_Token
    jnc     @@Help

    mov     bx, OFFSET cli_kw_list
    call    Cli_Match_Token
    jnc     @@List

    mov     bx, OFFSET cli_kw_saveconfig
    call    Cli_Match_Token
    jc      @@CheckConfig
    add     si, 10
    call    Cli_Collect_Args
    jc      @@Done
    call    Cmd_SaveConfig
    ret

@@CheckConfig:
    mov     bx, OFFSET cli_kw_configure
    call    Cli_Match_Token
    jc      @@Help

    add     si, 9
    call    Cli_Collect_Args
    jc      @@Done
    call    Cmd_Configure
    ret

@@List:
    add     si, 4
    call    Cli_Collect_Args
    jc      @@Done
    ; LIST owns no arguments of its own, so any residual token is invalid.
    cmp     [cli_arg_count], 0
    jne     @@Help
    call    Cmd_List
    ret

@@Help:
    mov     dx, OFFSET msg_help
    mov     ah, 09h
    int     21h
@@Done:
    ret
ENDP Parse_And_Execute

; ---------------------------------------------------------------------------
; Global CLI option layer.
;
; Cli_Collect_Args tokenizes the command tail that follows the command verb.
; Genuinely global options are consumed here and never reach a verb specific
; parser; currently the only global option is /VERBOSE.  Everything else is
; recorded as a pointer into cmd_buffer so the selected verb parser can
; validate it inside its own namespace.  No argument text is copied.
;
; Input   SI points immediately after the recognized command verb.
; Output  CF clear on success, CF set after printing a diagnostic.
; ---------------------------------------------------------------------------
PROC Cli_Collect_Args NEAR
    push    ax
    push    bx
    push    dx

    mov     [cli_arg_count], 0
    mov     [cli_arg_index], 0

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
    je      @@Introducer
    cmp     al, '-'
    jne     @@RecordArg
@@Introducer:
    ; Global options are matched on the switch body only.  A non-global
    ; switch is left intact for the verb specific parser.
    inc     si
    mov     bx, OFFSET cli_kw_verbose
    call    Cli_Match_Token
    dec     si
    jc      @@RecordArg

    test    [cli_flags], CLI_FLAG_VERBOSE
    jnz     @@DupVerbose
    or      [cli_flags], CLI_FLAG_VERBOSE
    add     si, 8                   ; Skip the introducer and VERBOSE.
    jmp     @@NextToken

@@RecordArg:
    mov     bx, [cli_arg_count]
    cmp     bx, CLI_MAX_ARGS
    jae     @@TooMany
    shl     bx, 1
    add     bx, OFFSET cli_arg_ptrs
    mov     [bx], si
    inc     [cli_arg_count]

@@SkipToken:
    mov     al, [si]
    or      al, al
    jz      @@Success
    cmp     al, ' '
    je      @@NextToken
    cmp     al, 09h
    je      @@NextToken
    inc     si
    jmp     @@SkipToken

@@Success:
    clc
    jmp     @@Done
@@DupVerbose:
    mov     dx, OFFSET msg_cli_dup_verbose
    jmp     @@Fail
@@TooMany:
    mov     dx, OFFSET msg_cli_too_many_args
@@Fail:
    mov     ah, 09h
    int     21h
    stc
@@Done:
    pop     dx
    pop     bx
    pop     ax
    ret
ENDP Cli_Collect_Args

; Matches the NUL terminated keyword at DS:BX against the token at DS:SI.
; A match requires a whitespace or NUL delimiter directly after the keyword.
; SI is preserved.  CF clear on match.
PROC Cli_Match_Token NEAR
    push    ax
    push    bx
    push    si
@@Loop:
    mov     al, [BYTE bx]
    or      al, al
    jz      @@AtDelimiter
    cmp     al, [BYTE si]
    jne     @@NoMatch
    inc     bx
    inc     si
    jmp     @@Loop
@@AtDelimiter:
    mov     al, [BYTE si]
    or      al, al
    jz      @@Match
    cmp     al, ' '
    je      @@Match
    cmp     al, 09h
    jne     @@NoMatch
@@Match:
    pop     si
    pop     bx
    pop     ax
    clc
    ret
@@NoMatch:
    pop     si
    pop     bx
    pop     ax
    stc
    ret
ENDP Cli_Match_Token

; Returns the next verb specific argument token in SI, or CF set when the
; filtered argument view is exhausted.
PROC Cli_Next_Arg NEAR
    push    bx
    mov     bx, [cli_arg_index]
    cmp     bx, [cli_arg_count]
    jae     @@None
    inc     [cli_arg_index]
    shl     bx, 1
    add     bx, OFFSET cli_arg_ptrs
    mov     si, [bx]
    pop     bx
    clc
    ret
@@None:
    pop     bx
    stc
    ret
ENDP Cli_Next_Arg

; ==========================================================================
; SAVECONFIG command. Exports the recognized persistent configuration of one
; adapter as a DOS batch file. The command never writes NIC registers/EEPROM.
; ==========================================================================
PROC Cmd_SaveConfig NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    ; Establish the SAVECONFIG defaults before any option text is examined.
    ; The output batch file defaults to RESTORE.BAT and the program name
    ; embedded in each restore line defaults to this build, unless the
    ; matching option overrides it.
    mov     di, OFFSET save_filename
    mov     si, OFFSET save_filename_default
    call    Save_Copy_Default
    mov     di, OFFSET save_execname
    mov     si, OFFSET save_execname_default
    call    Save_Copy_Default
    mov     [save_outputfile_supplied], 0
    mov     [save_execfile_supplied], 0
    mov     [save_execfile_placeholder], 0
    mov     [save_error], SAVE_ERR_NONE

    ; Single pass over the SAVECONFIG argument view established by the common
    ; parser.  Only SAVECONFIG owned options are accepted here; global options
    ; were already consumed and CONFIGURE properties are not in scope.
@@NextOption:
    call    Cli_Next_Arg
    jc      @@ScanCards

    mov     al, [si]
    cmp     al, '/'
    je      @@HaveIntroducer
    cmp     al, '-'
    jne     @@BadOption
@@HaveIntroducer:
    inc     si

    mov     di, OFFSET save_outputfile_kw
    call    Save_Match_Keyword
    jc      @@TryExecFile
    cmp     [save_outputfile_supplied], 0
    jne     @@DupOption
    mov     di, OFFSET save_filename
    mov     cx, 127
    call    Save_Copy_Value
    jc      @@BadName
    or      ax, ax
    jz      @@Missing
    mov     [save_outputfile_supplied], 1
    jmp     @@NextOption

@@TryExecFile:
    mov     di, OFFSET save_execfile_kw
    call    Save_Match_Keyword
    jc      @@BadOption
    cmp     [save_execfile_supplied], 0
    jne     @@DupOption
    mov     di, OFFSET save_execname
    mov     cx, 64
    call    Save_Copy_Value
    jc      @@BadExecFile
    or      ax, ax
    jz      @@BadExecFile
    mov     [save_execfile_supplied], 1
    jmp     @@NextOption

@@ScanCards:
    call    Save_Prepare_Execfile
    jc      @@PrepareFail
    call    Scan_All_3Com_Cards
    cmp     [card_count], 0
    je      @@NoCards

    mov     [save_length], 0
    mov     [save_argument_length], 0
    mov     [save_file_open], 0
    mov     [current_card], 0
    mov     si, OFFSET nic_table
@@ExportLoop:
    mov     dx, [WORD si + NIC_IO_BASE]
    or      dx, dx
    jz      @@SkipAdapter

    mov     al, EEPROM_ADDR_CFG
    call    Nic_EEPROM_Read
    jc      @@ReadFail
    mov     [save_word08], ax
    mov     al, EEPROM_RESOURCE_CFG
    call    Nic_EEPROM_Read
    jc      @@ReadFail
    mov     [save_word09], ax
    mov     al, EEPROM_SOFTWARE_INFO
    call    Nic_EEPROM_Read
    jc      @@ReadFail
    mov     [save_word0d], ax
    mov     al, EEPROM_CONFIG_CONTROL
    call    Nic_EEPROM_Read
    jc      @@ReadFail
    mov     [save_word13], ax

    mov     ax, [current_card]
    inc     ax
    mov     [save_adapter_num], ax
    call    Save_Build_Command
    jc      @@SaveFail

@@SkipAdapter:
    add     si, NIC_RECORD_SIZE
    inc     [current_card]
    mov     ax, [current_card]
    cmp     ax, [card_count]
    jb      @@ExportLoop

    cmp     [save_file_open], 0
    je      @@NoActive

    mov     bx, [save_handle]
    mov     ah, 3Eh
    int     21h
    jc      @@WriteFail
    mov     [save_file_open], 0
    mov     dx, OFFSET msg_save_ok
    mov     ah, 09h
    int     21h
    mov     si, OFFSET save_filename
    call    Save_Print_Filename
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h
    jmp     @@Done
@@PrepareFail:
    cmp     al, SAVE_ERR_WRITE
    je      @@ExecNotFound
    cmp     al, SAVE_ERR_LINE_TOO_LONG
    je      @@LineTooLong
    jmp     @@BadExecFile
@@SaveFail:
    cmp     [save_error], SAVE_ERR_LINE_TOO_LONG
    je      @@LineTooLong
    jmp     @@WriteFail
@@WriteFail:
    call    Save_Cleanup_Partial_File
    mov     dx, OFFSET msg_save_write_fail
    jmp     @@Print
@@ReadFail:
    call    Save_Cleanup_Partial_File
    mov     dx, OFFSET msg_save_read_fail
    jmp     @@Print
@@NoActive:
    mov     dx, OFFSET msg_save_no_active
    jmp     @@Print
@@NoCards:
    mov     dx, OFFSET msg_no_cards
    jmp     @@Print
@@Missing:
    mov     dx, OFFSET msg_save_missing
    jmp     @@Print
@@BadOption:
    mov     dx, OFFSET msg_save_bad_option
    jmp     @@Print
@@DupOption:
    mov     dx, OFFSET msg_save_dup_option
    jmp     @@Print
@@BadExecFile:
    mov     dx, OFFSET msg_save_bad_execfile
    jmp     @@Print
@@ExecNotFound:
    mov     dx, OFFSET msg_save_execfile_not_found
    jmp     @@Print
@@LineTooLong:
    call    Save_Cleanup_Partial_File
    mov     dx, OFFSET msg_save_line_too_long
    jmp     @@Print
@@BadName:
    mov     dx, OFFSET msg_save_bad_name
@@Print:
    mov     ah, 09h
    int     21h
@@Done:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Cmd_SaveConfig

; Copies the NUL terminated default string at DS:SI into DS:DI.
PROC Save_Copy_Default NEAR
    push    ax
@@Loop:
    lodsb
    mov     [BYTE di], al
    inc     di
    or      al, al
    jnz     @@Loop
    pop     ax
    ret
ENDP Save_Copy_Default

; Compares the NUL terminated keyword at DS:DI against the option text at
; DS:SI.  On a match SI advances past the keyword and CF is clear; otherwise
; SI is unchanged and CF is set.
PROC Save_Match_Keyword NEAR
    push    ax
    push    di
    push    si
@@Loop:
    mov     al, [BYTE di]
    or      al, al
    jz      @@Matched
    cmp     al, [BYTE si]
    jne     @@NoMatch
    inc     di
    inc     si
    jmp     @@Loop
@@Matched:
    pop     ax                      ; discard saved SI, keep advanced SI
    pop     di
    pop     ax
    clc
    ret
@@NoMatch:
    pop     si
    pop     di
    pop     ax
    stc
    ret
ENDP Save_Match_Keyword

; Copies the whitespace delimited option value at DS:SI into the CX byte
; bounded buffer at DS:DI and NUL terminates it.  Returns the copied length
; in AX with CF clear, or CF set when the value exceeds the buffer.
PROC Save_Copy_Value NEAR
    push    cx
    push    di
    xor     ax, ax
@@Loop:
    jcxz    @@Overflow
    push    ax
    mov     al, [BYTE si]
    or      al, al
    jz      @@EndValue
    cmp     al, ' '
    je      @@EndValue
    cmp     al, 09h
    je      @@EndValue
    mov     [BYTE di], al
    pop     ax
    inc     di
    inc     si
    inc     ax
    dec     cx
    jmp     @@Loop
@@EndValue:
    pop     ax
    xor     cl, cl
    mov     [BYTE di], cl
    pop     di
    pop     cx
    clc
    ret
@@Overflow:
    pop     di
    pop     cx
    stc
    ret
ENDP Save_Copy_Value

PROC Save_Print_Filename NEAR
    push    ax
    push    dx
@@Loop:
    mov     dl, [BYTE si]
    or      dl, dl
    jz      @@Done
    mov     ah, 02h
    int     21h
    inc     si
    jmp     @@Loop
@@Done:
    pop     dx
    pop     ax
    ret
ENDP Save_Print_Filename

; Appends AL to save_buffer, guarding against overrun of SAVE_BUFFER_SIZE.
; All upstream length accounting (Save_Ensure_Option_Length) is expected to
; keep writes within bounds; this is a hard backstop against any programming
; error letting save_length reach the buffer limit.
PROC Save_Append_Char NEAR
    push    di
    cmp     [save_length], SAVE_BUFFER_SIZE
    jae     @@Overflow
    mov     di, OFFSET save_buffer
    add     di, [save_length]
    stosb
    inc     [save_length]
    pop     di
    ret
@@Overflow:
    pop     di
    mov     [save_error], SAVE_ERR_LINE_TOO_LONG
    stc
    ret
ENDP Save_Append_Char

PROC Save_Append_String NEAR
    push    ax
@@Loop:
    lodsb
    or      al, al
    jz      @@Done
    call    Save_Append_Char
    jc      @@Fail
    jmp     @@Loop
@@Fail:
    pop     ax
    stc
    ret
@@Done:
    pop     ax
    clc
    ret
ENDP Save_Append_String

PROC Save_String_Length NEAR
    push    ax
    push    si
    xor     cx, cx
@@Loop:
    lodsb
    or      al, al
    jz      @@Done
    inc     cx
    jmp     @@Loop
@@Done:
    pop     si
    pop     ax
    ret
ENDP Save_String_Length

PROC Save_Dec_Word_Length NEAR
    push    ax
    push    bx
    push    dx
    xor     cx, cx
    mov     bx, 10
@@Loop:
    xor     dx, dx
    div     bx
    inc     cx
    or      ax, ax
    jnz     @@Loop
    pop     dx
    pop     bx
    pop     ax
    ret
ENDP Save_Dec_Word_Length

PROC Save_Prepare_Execfile NEAR
    push    bx
    push    cx
    push    dx
    push    si

    cmp     [save_execfile_supplied], 0
    je      @@Lengths
    mov     si, OFFSET save_execname
    cmp     [BYTE si], 0
    je      @@BadValue
    cmp     [BYTE si], '%'
    jne     @@LiteralScan
    cmp     [BYTE si+1], '1'
    jne     @@BadValue
    cmp     [BYTE si+2], 0
    jne     @@BadValue
    mov     [save_execfile_placeholder], 1
    jmp     @@Lengths

@@LiteralScan:
    mov     [save_execfile_placeholder], 0
@@PercentLoop:
    mov     al, [BYTE si]
    or      al, al
    jz      @@CheckExists
    cmp     al, '%'
    je      @@BadValue
    inc     si
    jmp     @@PercentLoop

@@CheckExists:
    mov     dx, OFFSET save_execname
    mov     ax, 3D00h
    int     21h
    jc      @@NotFound
    mov     bx, ax
    mov     ah, 3Eh
    int     21h
    jc      @@NotFound

@@Lengths:
    mov     si, OFFSET save_execname
    call    Save_String_Length
    mov     [save_execname_length], cx
    cmp     [save_execfile_placeholder], 0
    je      @@UseActual
    mov     cx, SAVE_EXECFILE_RUNTIME_RESERVE
@@UseActual:
    mov     ax, SAVE_MAX_BATCH_LINE
    sub     ax, cx
    jc      @@TooLong
    dec     ax
    mov     [save_max_argument_length], ax
    mov     al, SAVE_ERR_NONE
    clc
    jmp     @@Done
@@BadValue:
    mov     al, SAVE_ERR_BAD_EXECFILE
    stc
    jmp     @@Done
@@NotFound:
    mov     al, SAVE_ERR_WRITE
    stc
    jmp     @@Done
@@TooLong:
    mov     al, SAVE_ERR_LINE_TOO_LONG
    stc
@@Done:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    ret
ENDP Save_Prepare_Execfile

PROC Save_Ensure_Option_Length NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    mov     ax, [save_argument_length]
    add     ax, cx
    jc      @@NeedNewLine
    cmp     ax, [save_max_argument_length]
    jbe     @@Ok
@@NeedNewLine:
    call    Save_Flush_Command
    jc      @@WriteFail
    call    Save_Begin_Command
    jc      @@Fail
    mov     ax, [save_argument_length]
    add     ax, cx
    jc      @@LineTooLong
    cmp     ax, [save_max_argument_length]
    jbe     @@Ok
@@LineTooLong:
    mov     [save_error], SAVE_ERR_LINE_TOO_LONG
    jmp     @@Fail
@@WriteFail:
    mov     [save_error], SAVE_ERR_WRITE
@@Fail:
    stc
    jmp     @@Done
@@Ok:
    clc
@@Done:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Save_Ensure_Option_Length

PROC Save_Commit_Option_Length NEAR
    add     [save_argument_length], cx
    ret
ENDP Save_Commit_Option_Length

PROC Save_Append_Hex_Nibble NEAR
    and     al, 0Fh
    add     al, '0'
    cmp     al, '9'
    jbe     @@Out
    add     al, 7
@@Out:
    call    Save_Append_Char
    ret
ENDP Save_Append_Hex_Nibble

PROC Save_Append_Hex_Word NEAR
    push    ax
    mov     al, ah
    shr     al, 1
    shr     al, 1
    shr     al, 1
    shr     al, 1
    call    Save_Append_Hex_Nibble
    jc      @@Fail
    pop     ax
    push    ax
    mov     al, ah
    call    Save_Append_Hex_Nibble
    jc      @@Fail
    pop     ax
    push    ax
    shr     al, 1
    shr     al, 1
    shr     al, 1
    shr     al, 1
    call    Save_Append_Hex_Nibble
    jc      @@Fail
    pop     ax
    call    Save_Append_Hex_Nibble
    jc      @@FailNoPop
    ret
@@Fail:
    pop     ax
@@FailNoPop:
    stc
    ret
ENDP Save_Append_Hex_Word

PROC Save_Append_Dec_Word NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    xor     cx, cx
    mov     bx, 10
@@Divide:
    xor     dx, dx
    div     bx
    push    dx
    inc     cx
    or      ax, ax
    jnz     @@Divide
@@Output:
    pop     dx
    mov     al, dl
    add     al, '0'
    call    Save_Append_Char
    jc      @@Fail
    loop    @@Output
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    clc
    ret
@@Fail:
    ; Unwind any digits still pushed for the pending output loop so the
    ; stack stays balanced before returning failure to the caller.
    dec     cx
    jz      @@FailRestore
@@FailUnwind:
    pop     dx
    loop    @@FailUnwind
@@FailRestore:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    stc
    ret
ENDP Save_Append_Dec_Word

; Start one independently executable CONFIGURE command line.  Although DOS
; stores only the argument tail in the child PSP, batch execution first has to
; pass the complete text line.  SAVECONFIG therefore limits:
;   emitted executable reservation + one separator + CONFIGURE arguments <= 128.
PROC Save_Begin_Command NEAR
    call    Save_Open_File
    jc      @@Fail
    mov     [save_length], 0
    mov     si, OFFSET save_execname
    call    Save_Append_String
    jc      @@Fail
    mov     si, OFFSET save_configure_suffix
    call    Save_Append_String
    jc      @@Fail
    mov     si, OFFSET save_adapternum
    call    Save_Append_String
    jc      @@Fail
    mov     ax, [save_adapter_num]
    call    Save_Append_Dec_Word
    jc      @@Fail
    mov     ax, [save_length]
    sub     ax, [save_execname_length]
    dec     ax
    mov     [save_argument_length], ax
    cmp     ax, [save_max_argument_length]
    jbe     @@Ready
    mov     [save_error], SAVE_ERR_LINE_TOO_LONG
    jmp     @@Fail
@@Ready:
    clc
    ret
@@Fail:
    stc
    ret
ENDP Save_Begin_Command

; Append CR/LF and persist the current command line.
PROC Save_Flush_Command NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    mov     al, 0Dh
    call    Save_Append_Char
    jc      @@Fail
    mov     al, 0Ah
    call    Save_Append_Char
    jc      @@Fail
    mov     bx, [save_handle]
    mov     ah, 40h
    mov     cx, [save_length]
    mov     dx, OFFSET save_buffer
    int     21h
    jc      @@Fail
    cmp     ax, [save_length]
    jne     @@Fail
    mov     [save_length], 0
    clc
    jmp     @@Done
@@Fail:
    stc
@@Done:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Save_Flush_Command

; Lazily create the output so a no-active-adapter error leaves no empty file.
PROC Save_Open_File NEAR
    cmp     [save_file_open], 0
    jne     @@Done
    mov     ah, 3Ch
    xor     cx, cx
    mov     dx, OFFSET save_filename
    int     21h
    jc      @@Fail
    mov     [save_handle], ax
    mov     [save_file_open], 1
@@Done:
    clc
    ret
@@Fail:
    stc
    ret
ENDP Save_Open_File

; Discards an incomplete SAVECONFIG output file after a fatal error.  A no-op
; if no file is currently open.  Closes save_handle and deletes save_filename
; so a partial restore batch can never be mistaken for a complete one.  Any
; close/delete failure here is ignored; the caller's original error condition
; is what gets reported.
PROC Save_Cleanup_Partial_File NEAR
    push    ax
    push    bx
    push    dx
    cmp     [save_file_open], 0
    je      @@Done
    mov     bx, [save_handle]
    mov     ah, 3Eh
    int     21h
    mov     [save_file_open], 0
    mov     ah, 41h
    mov     dx, OFFSET save_filename
    int     21h
@@Done:
    pop     dx
    pop     bx
    pop     ax
    ret
ENDP Save_Cleanup_Partial_File

PROC Save_Build_Command NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    call    Save_Begin_Command
    jc      @@Fail

    mov     ax, [save_word09]
    mov     cl, 12
    shr     ax, cl
    call    Save_Dec_Word_Length
    add     cx, SAVE_LEN_INT
    call    Save_Ensure_Option_Length
    jc      @@Fail
    call    Save_Commit_Option_Length
    mov     si, OFFSET save_int
    call    Save_Append_String
    jc      @@Fail
    mov     ax, [save_word09]
    mov     cl, 12
    shr     ax, cl
    call    Save_Append_Dec_Word
    jc      @@Fail

    mov     cx, SAVE_LEN_IOBASE + 4
    call    Save_Ensure_Option_Length
    jc      @@Fail
    call    Save_Commit_Option_Length
    mov     si, OFFSET save_iobase
    call    Save_Append_String
    jc      @@Fail
    mov     ax, [save_word08]
    and     ax, 001Fh
    mov     cl, 4
    shl     ax, cl
    add     ax, 0200h
    call    Save_Append_Hex_Word
    jc      @@Fail

    mov     ax, [save_word13]
    and     ax, 000Ch
    cmp     ax, 0004h
    jne     @@PnpOnLength
    mov     cx, SAVE_LEN_PNP + SAVE_LEN_DISABLED
    jmp     @@PnpLengthDone
@@PnpOnLength:
    mov     cx, SAVE_LEN_PNP + SAVE_LEN_ENABLED
@@PnpLengthDone:
    call    Save_Ensure_Option_Length
    jc      @@Fail
    call    Save_Commit_Option_Length
    mov     si, OFFSET save_pnp
    call    Save_Append_String
    jc      @@Fail
    mov     ax, [save_word13]
    and     ax, 000Ch
    cmp     ax, 0004h
    jne     @@PnpOn
    mov     si, OFFSET save_disabled
    jmp     @@PnpDone
@@PnpOn:
    mov     si, OFFSET save_enabled
@@PnpDone:
    call    Save_Append_String
    jc      @@Fail

    mov     ax, [save_word0d]
    test    ax, EEPROM_SOFTWARE_INFO_FULLDUPLEX
    jz      @@FdOffLength
    mov     cx, SAVE_LEN_FD + SAVE_LEN_ENABLED
    jmp     @@FdLengthDone
@@FdOffLength:
    mov     cx, SAVE_LEN_FD + SAVE_LEN_DISABLED
@@FdLengthDone:
    call    Save_Ensure_Option_Length
    jc      @@Fail
    call    Save_Commit_Option_Length
    mov     si, OFFSET save_fd
    call    Save_Append_String
    jc      @@Fail
    mov     ax, [save_word0d]
    test    ax, EEPROM_SOFTWARE_INFO_FULLDUPLEX
    jz      @@FdOff
    mov     si, OFFSET save_enabled
    jmp     @@FdDone
@@FdOff:
    mov     si, OFFSET save_disabled
@@FdDone:
    call    Save_Append_String
    jc      @@Fail

    mov     ax, [save_word0d]
    and     ax, EEPROM_SOFTWARE_INFO_INT_DISABLE_MASK
    cmp     ax, EEPROM_MODEM_NONE
    je      @@ModemNone
    ; Raw 2Fh is valid 1200 us hardware data, but /MODEM:1200 is the named
    ; baud setting.  Normalize this CLI-unrepresentable value to NONE.
    cmp     ax, 2F00h
    je      @@ModemNone
    call    Decode_Modem_Baud_Alias
    jnc     @@ModemValue
    mov     ax, [save_word0d]
    call    Decode_Modem_Value
@@ModemValue:
    call    Save_Dec_Word_Length
    add     cx, SAVE_LEN_MODEM
    call    Save_Ensure_Option_Length
    jc      @@Fail
    call    Save_Commit_Option_Length
    mov     si, OFFSET save_modem
    call    Save_Append_String
    jc      @@Fail
    call    Save_Append_Dec_Word
    jc      @@Fail
    jmp     @@Optimize
@@ModemNone:
    mov     cx, SAVE_LEN_MODEM + SAVE_LEN_NONE
    call    Save_Ensure_Option_Length
    jc      @@Fail
    call    Save_Commit_Option_Length
    mov     si, OFFSET save_modem
    call    Save_Append_String
    jc      @@Fail
    mov     si, OFFSET save_none
    call    Save_Append_String
    jc      @@Fail
@@Optimize:
    mov     ax, [save_word0d]
    mov     cl, 4
    shr     ax, cl
    and     ax, 0003h
    cmp     al, 1
    je      @@OptDosLength
    cmp     al, 2
    je      @@OptWindowsOs2Length
    cmp     al, 3
    je      @@OptServerLength
    ; 00b is reserved; use a parser-valid, conservative restore fallback.
    mov     cx, SAVE_LEN_OPTIMIZE + SAVE_LEN_DOS
    jmp     @@OptLengthDone
@@OptDosLength:
    mov     cx, SAVE_LEN_OPTIMIZE + SAVE_LEN_DOS
    jmp     @@OptLengthDone
@@OptWindowsOs2Length:
    mov     cx, SAVE_LEN_OPTIMIZE + SAVE_LEN_WINDOWS_OS2
    jmp     @@OptLengthDone
@@OptServerLength:
    mov     cx, SAVE_LEN_OPTIMIZE + SAVE_LEN_SERVER
    jmp     @@OptLengthDone
@@OptLengthDone:
    call    Save_Ensure_Option_Length
    jc      @@Fail
    call    Save_Commit_Option_Length
    mov     si, OFFSET save_optimize
    call    Save_Append_String
    jc      @@Fail
    mov     ax, [save_word0d]
    mov     cl, 4
    shr     ax, cl
    and     ax, 0003h
    cmp     al, 1
    je      @@OptDos
    cmp     al, 2
    je      @@OptWindowsOS2
    cmp     al, 3
    je      @@OptServer
    mov     si, OFFSET save_dos
    jmp     @@OptDone
@@OptDos:
    mov     si, OFFSET save_dos
    jmp     @@OptDone
@@OptWindowsOS2:
    ; Value 10b is Windows and OS/2 client, as in the original UI,
    ; which also combines both display values.
    mov     si, OFFSET save_windows_os2
    jmp     @@OptDone
@@OptServer:
    mov     si, OFFSET save_server
    jmp     @@OptDone
@@OptDone:
    call    Save_Append_String
    jc      @@Fail
    mov     ax, [save_word08]
    and     ax, 3F00h              ; Base (bits 11:8) and size (bits 13:12).
    jz      @@NoRom
    mov     ax, [save_word08]
    and     ax, 3000h
    mov     cl, 12
    shr     ax, cl
    or      ax, ax
    jz      @@Size8Length
    cmp     ax, 1
    je      @@Size16Length
    mov     ax, 32
    jmp     @@SizeLengthDone
@@Size8Length:
    mov     ax, 8
    jmp     @@SizeLengthDone
@@Size16Length:
    mov     ax, 16
@@SizeLengthDone:
    call    Save_Dec_Word_Length
    add     cx, SAVE_LEN_BADDRESS + 5 + SAVE_LEN_BSIZE
    call    Save_Ensure_Option_Length
    jc      @@Fail
    call    Save_Commit_Option_Length
    mov     si, OFFSET save_baddress
    call    Save_Append_String
    jc      @@Fail
    mov     ax, [save_word08]
    and     ax, 0F00h
    mov     cl, 8
    shr     ax, cl
    mov     cl, 13
    shl     ax, cl
    mov     dl, 0Ch
    mov     al, dl
    call    Save_Append_Hex_Nibble
    jc      @@Fail
    mov     ax, [save_word08]
    and     ax, 0F00h
    mov     cl, 5
    shl     ax, cl
    call    Save_Append_Hex_Word
    jc      @@Fail
    mov     si, OFFSET save_bsize
    call    Save_Append_String
    jc      @@Fail
    mov     ax, [save_word08]
    and     ax, 3000h
    mov     cl, 12
    shr     ax, cl
    or      ax, ax
    jz      @@Size8
    cmp     ax, 1
    je      @@Size16
    mov     ax, 32
    jmp     @@SizeDone
@@Size8:
    mov     ax, 8
    jmp     @@SizeDone
@@Size16:
    mov     ax, 16
@@SizeDone:
    call    Save_Append_Dec_Word
    jc      @@Fail
    jmp     @@Tr
@@NoRom:
    ; The original utility does not accept /BADDRESS:NONE; disabling the
    ; Boot ROM is expressed with /BSIZE:DISABLED alone.
    mov     cx, SAVE_LEN_BSIZE + SAVE_LEN_DISABLED
    call    Save_Ensure_Option_Length
    jc      @@Fail
    call    Save_Commit_Option_Length
    mov     si, OFFSET save_bsize
    call    Save_Append_String
    jc      @@Fail
    mov     si, OFFSET save_disabled
    call    Save_Append_String
    jc      @@Fail
@@Tr:
    mov     ax, [save_word08]
    test    ax, 0080h
    jnz     @@TrAutoLength
    mov     cl, 14
    shr     ax, cl
    cmp     al, 1
    je      @@TrAuiLength
    cmp     al, 3
    je      @@TrCoaxLength
    mov     cx, SAVE_LEN_TR + SAVE_LEN_TP
    jmp     @@TrLengthDone
@@TrAutoLength:
    mov     cx, SAVE_LEN_TR + SAVE_LEN_AUTO
    jmp     @@TrLengthDone
@@TrAuiLength:
    mov     cx, SAVE_LEN_TR + SAVE_LEN_AUI
    jmp     @@TrLengthDone
@@TrCoaxLength:
    mov     cx, SAVE_LEN_TR + SAVE_LEN_COAX
@@TrLengthDone:
    call    Save_Ensure_Option_Length
    jc      @@Fail
    call    Save_Commit_Option_Length
    mov     si, OFFSET save_tr
    call    Save_Append_String
    jc      @@Fail
    mov     ax, [save_word08]
    test    ax, 0080h
    jnz     @@TrAuto
    mov     cl, 14
    shr     ax, cl
    cmp     al, 1
    je      @@TrAui
    cmp     al, 3
    je      @@TrCoax
    mov     si, OFFSET save_tp
    jmp     @@TrDone
@@TrAuto:
    mov     si, OFFSET save_auto
    jmp     @@TrDone
@@TrAui:
    mov     si, OFFSET save_aui
    jmp     @@TrDone
@@TrCoax:
    mov     si, OFFSET save_coax
@@TrDone:
    call    Save_Append_String
    jc      @@Fail
    call    Save_Flush_Command
    jc      @@Fail
    jmp     @@Done
@@Fail:
    stc
@@Done:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Save_Build_Command

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
; case insensitive.
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
    mov     [cfg_selected_ptr], 0

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
; Input is the filtered CONFIGURE argument view established by the common
; parser; global options such as /VERBOSE never appear here.
; Output CF clear on syntactically valid options, CF set with cfg_last_error.
PROC Cfg_Parse_Options NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di

@@NextToken:
    call    Cli_Next_Arg
    jc      @@Success

    mov     al, [si]
    cmp     al, '/'
    je      @@HaveIntroducer
    cmp     al, '-'
    jne     @@BadOption

@@HaveIntroducer:
    inc     si

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
    mov     [cfg_queue_property_id], al

    ; Strict duplicate tracking applies to supported hardware properties.
    cmp     al, CFG_OPT_INT
    jne     @@CheckSeenIOBase
    mov     ax, CFG_SEEN_INT
    call    Cfg_Mark_Seen
    jc      @@DuplicateProperty
    jmp     @@CountProperty
@@CheckSeenIOBase:
    cmp     al, CFG_OPT_IOBASE
    jne     @@CheckSeenBAddress
    mov     ax, CFG_SEEN_IOBASE
    call    Cfg_Mark_Seen
    jc      @@DuplicateProperty
    jmp     @@CountProperty
@@CheckSeenBAddress:
    cmp     al, CFG_OPT_BADDRESS
    jne     @@CheckSeenBSize
    mov     ax, CFG_SEEN_BADDRESS
    call    Cfg_Mark_Seen
    jc      @@DuplicateProperty
    jmp     @@CountProperty
@@CheckSeenBSize:
    cmp     al, CFG_OPT_BSIZE
    jne     @@CheckSeenPNP
    mov     ax, CFG_SEEN_BSIZE
    call    Cfg_Mark_Seen
    jc      @@DuplicateProperty
    jmp     @@CountProperty
@@CheckSeenPNP:
    cmp     al, CFG_OPT_PNP
    jne     @@CheckSeenModem
    mov     ax, CFG_SEEN_PNP
    call    Cfg_Mark_Seen
    jc      @@DuplicateProperty
    jmp     @@CountProperty
@@CheckSeenModem:
    cmp     al, CFG_OPT_MODEM
    jne     @@CheckSeenFullDuplex
    mov     ax, CFG_SEEN_MODEM
    call    Cfg_Mark_Seen
    jc      @@DuplicateProperty
    jmp     @@CountProperty
@@CheckSeenFullDuplex:
    cmp     al, CFG_OPT_FULLDUPLEX
    jne     @@CheckSeenOptimize
    mov     ax, CFG_SEEN_FULLDUPLEX
    call    Cfg_Mark_Seen
    jc      @@DuplicateProperty
    jmp     @@CountProperty
@@CheckSeenOptimize:
    cmp     al, CFG_OPT_OPTIMIZE
    jne     @@CheckSeenTR
    mov     ax, CFG_SEEN_OPTIMIZE
    call    Cfg_Mark_Seen
    jc      @@DuplicateProperty
    jmp     @@CountProperty
@@CheckSeenTR:
    cmp     al, CFG_OPT_TR
    jne     @@CountProperty
    mov     ax, CFG_SEEN_TR
    call    Cfg_Mark_Seen
    jc      @@DuplicateProperty
@@CountProperty:
    xor     bx, bx
    mov     bl, [cfg_property_count]
    mov     ax, bx
    shl     bx, 1
    shl     bx, 1
    add     bx, ax                 ; BX = request index times five.
    add     bx, OFFSET cfg_property_requests
    mov     al, [cfg_queue_property_id]
    mov     [bx], al
    mov     [bx+1], dx
    mov     [bx+3], di
    inc     [cfg_property_count]
    jmp     @@NextToken

@@AdapterNumber:
    mov     ax, CFG_SEEN_ADAPTER
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
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    stc
    ret
@@Success:
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    clc
    ret
ENDP Cfg_Parse_Options

; Mark one supported CONFIGURE verb as seen during the first parse pass.
; Input AX = one CFG_SEEN bit.  Carry set means that verb was already seen.
; This state is intentionally separate from cfg_parse_flags so staged state
; continues to mean successfully parsed and accepted property values.
PROC Cfg_Mark_Seen NEAR
    push    bx

    mov     bx, [cfg_seen_flags]
    test    bx, ax
    jnz     @@Duplicate
    or      bx, ax
    mov     [cfg_seen_flags], bx
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
; explicit selector.
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

; Dispatch ordered CONFIGURE hardware-property requests collected by
; Cfg_Parse_Options after adapter selection and revalidation.  A handler error
; stops later handlers, matching the original sub_377 loop.
PROC Cfg_Dispatch_Parsed_Properties NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    di
    push    si

    mov     bx, OFFSET cfg_property_requests
    xor     di, di                 ; Number of requests dispatched.
@@NextRequest:
    mov     al, [cfg_property_count]
    xor     ah, ah
    cmp     di, ax
    jae     @@Done

    mov     al, [bx]
    mov     si, [bx+1]
    mov     cx, [bx+3]
    push    bx
    push    di
    call    Cfg_Dispatch_Property
    pop     di
    pop     bx
    cmp     [cfg_last_error], CFG_ERR_NONE
    jne     @@Done
    add     bx, CFG_PROPERTY_REQUEST_SIZE
    inc     di
    jmp     @@NextRequest

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
    jne     @@PnP
    call    Cfg_Handle_OPTIMIZE
    ret
@@PnP:
    cmp     al, CFG_OPT_PNP
    jne     @@FullDuplex
    call    Cfg_Handle_PNP
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
; accepted value.  /IOBASE and /PNP likewise parse and stage only.  No handler
; performs hardware access directly.
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

; Parses a hexadecimal Boot ROM base address string (optional 0X prefix,
; digits 0-9/A-F) in [SI], length CX, into a 4-bit base index (0-15) in AL.
; The address must fall on an 8K boundary between 0C0000h and 0DE000h
; inclusive (address = 0C0000h + index*2000h).  Carry set means invalid.
PROC Cfg_Parse_BAddress_Hex NEAR
    push    bx
    push    cx
    push    dx
    push    si
    push    di

    xor     ax, ax
    xor     dx, dx
    xor     di, di                 ; DI = number of converted hex digits.
    or      cx, cx
    jz      @@Bad

    cmp     [BYTE si], '+'
    jne     @@CheckMinus
    inc     si
    dec     cx
    jz      @@Bad
@@CheckMinus:
    cmp     [BYTE si], '-'
    je      @@Bad

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
    jb      @@Bad
    cmp     bl, '9'
    jbe     @@DecimalDigit
    cmp     bl, 'A'
    jb      @@Bad
    cmp     bl, 'F'
    ja      @@Bad
    sub     bl, 37h
    jmp     @@HaveDigit
@@DecimalDigit:
    sub     bl, '0'
@@HaveDigit:
    ; Reject any token wider than 20 bits before shifting further.
    test    dx, 0FFF0h
    jnz     @@Bad
    shl     ax, 1
    rcl     dx, 1
    shl     ax, 1
    rcl     dx, 1
    shl     ax, 1
    rcl     dx, 1
    shl     ax, 1
    rcl     dx, 1
    or      al, bl
    inc     di
    inc     si
    dec     cx
    jmp     @@Digits

@@Converted:
    or      di, di
    jz      @@Bad

    ; Validate the 0C0000h-0DE000h range and 2000h (8K) alignment, then
    ; derive the 4-bit index directly from DX (high nibble) and AX (low
    ; word): index = (DX-0Ch)*8 + (AX>>13), only valid when AX's low 13
    ; bits are zero.
    cmp     dx, 0Ch
    jb      @@Bad
    cmp     dx, 0Dh
    ja      @@Bad
    mov     bx, ax
    and     bx, 1FFFh
    jnz     @@Bad
    mov     cl, 13
    mov     bx, ax
    shr     bx, cl
    cmp     dx, 0Ch
    je      @@BaseOk
    add     bx, 8
@@BaseOk:
    mov     al, bl

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
ENDP Cfg_Parse_BAddress_Hex

PROC Cfg_Handle_BADDRESS NEAR
    push    bx
    push    dx
    push    si

    call    Cfg_Parse_BAddress_Hex
    jc      @@Invalid
    mov     [cfg_baddress_value], al
    or      [cfg_parse_flags], CFG_PARSE_BADDRESS
    mov     [cfg_last_error], CFG_ERR_NONE
    jmp     @@Done

@@Invalid:
    mov     [cfg_last_error], CFG_ERR_BAD_BADDRESS

@@Done:
    pop     si
    pop     dx
    pop     bx
    ret
ENDP Cfg_Handle_BADDRESS

PROC Cfg_Handle_BSIZE NEAR
    push    bx
    push    dx
    push    si

    mov     [cfg_bsize_disabled], 0

    ; DISABLED turns off the Boot ROM; /BADDRESS may accompany it but is
    ; then ignored.
    cmp     cx, 8
    jne     @@ParseSize
    cmp     [BYTE si], 'D'
    jne     @@ParseSize
    cmp     [BYTE si+1], 'I'
    jne     @@ParseSize
    cmp     [BYTE si+2], 'S'
    jne     @@ParseSize
    cmp     [BYTE si+3], 'A'
    jne     @@ParseSize
    cmp     [BYTE si+4], 'B'
    jne     @@ParseSize
    cmp     [BYTE si+5], 'L'
    jne     @@ParseSize
    cmp     [BYTE si+6], 'E'
    jne     @@ParseSize
    cmp     [BYTE si+7], 'D'
    jne     @@ParseSize
    mov     [cfg_bsize_value], 0
    mov     [cfg_bsize_disabled], 1
    or      [cfg_parse_flags], CFG_PARSE_BSIZE
    mov     [cfg_last_error], CFG_ERR_NONE
    jmp     @@Done

@@ParseSize:
    ; Strict decimal parser: no sign, no suffix, no spaces, 2 digits max.
    or      cx, cx
    jz      @@Invalid
    cmp     cx, 2
    ja      @@Invalid
    xor     ax, ax
@@DigitLoop:
    mov     dl, [si]
    cmp     dl, '0'
    jb      @@Invalid
    cmp     dl, '9'
    ja      @@Invalid
    mov     bx, ax
    shl     ax, 1
    shl     bx, 1
    shl     bx, 1
    shl     bx, 1
    add     ax, bx
    sub     dl, '0'
    xor     dh, dh
    add     ax, dx
    inc     si
    dec     cx
    jnz     @@DigitLoop

    cmp     ax, 8
    jne     @@Check16
    mov     [cfg_bsize_value], 0
    jmp     @@Accept
@@Check16:
    cmp     ax, 16
    jne     @@Check32
    mov     [cfg_bsize_value], 1
    jmp     @@Accept
@@Check32:
    cmp     ax, 32
    jne     @@Invalid
    mov     [cfg_bsize_value], 2

@@Accept:
    or      [cfg_parse_flags], CFG_PARSE_BSIZE
    mov     [cfg_last_error], CFG_ERR_NONE
    jmp     @@Done

@@Invalid:
    mov     [cfg_last_error], CFG_ERR_BAD_BSIZE

@@Done:
    pop     si
    pop     dx
    pop     bx
    ret
ENDP Cfg_Handle_BSIZE

PROC Cfg_Handle_TR NEAR
    push    si
    push    cx

    ; Match TP (2), AUI (3), COAX (4), AUTO (4) by length then character.
    cmp     cx, 2
    jne     @@NotTP
    cmp     [BYTE si], 'T'
    jne     @@NotTP
    cmp     [BYTE si+1], 'P'
    jne     @@NotTP
    mov     [cfg_tr_value], 0       ; TP  -> bits 15:14 = 00
    jmp     @@Accept
@@NotTP:
    cmp     cx, 3
    jne     @@NotAUI
    cmp     [BYTE si], 'A'
    jne     @@NotAUI
    cmp     [BYTE si+1], 'U'
    jne     @@NotAUI
    cmp     [BYTE si+2], 'I'
    jne     @@NotAUI
    mov     [cfg_tr_value], 1       ; AUI -> bits 15:14 = 01
    jmp     @@Accept
@@NotAUI:
    cmp     cx, 4
    jne     @@Invalid
    cmp     [BYTE si], 'C'
    jne     @@NotCOAX
    cmp     [BYTE si+1], 'O'
    jne     @@NotCOAX
    cmp     [BYTE si+2], 'A'
    jne     @@NotCOAX
    cmp     [BYTE si+3], 'X'
    jne     @@NotCOAX
    mov     [cfg_tr_value], 3       ; COAX -> bits 15:14 = 11
    jmp     @@Accept
@@NotCOAX:
    cmp     [BYTE si], 'A'
    jne     @@Invalid
    cmp     [BYTE si+1], 'U'
    jne     @@Invalid
    cmp     [BYTE si+2], 'T'
    jne     @@Invalid
    cmp     [BYTE si+3], 'O'
    jne     @@Invalid
    mov     [cfg_tr_value], 0FFh    ; AUTO sentinel -> bit 7 of word 08h
    jmp     @@Accept
@@Invalid:
    mov     [cfg_last_error], CFG_ERR_BAD_TR
    jmp     @@Done
@@Accept:
    or      [cfg_parse_flags], CFG_PARSE_TR
    mov     [cfg_last_error], CFG_ERR_NONE
@@Done:
    pop     cx
    pop     si
    ret
ENDP Cfg_Handle_TR

PROC Cfg_Handle_MODEM NEAR
    push    ax
    push    bx
    push    dx
    push    si
    push    cx

    ; NONE means no modem timing constraint and uses the maximum 1600 us
    ; EEPROM_MODEM_NONE encoding, not zero (see 3C509DEF.INC).
    cmp     cx, 4
    jne     @@ParseNumber
    cmp     [BYTE si], 'N'
    jne     @@ParseNumber
    cmp     [BYTE si+1], 'O'
    jne     @@ParseNumber
    cmp     [BYTE si+2], 'N'
    jne     @@ParseNumber
    cmp     [BYTE si+3], 'E'
    jne     @@ParseNumber
    mov     [cfg_modem_value], EEPROM_MODEM_NONE
    or      [cfg_parse_flags], CFG_PARSE_MODEM
    mov     [cfg_last_error], CFG_ERR_NONE
    jmp     @@Done

@@ParseNumber:
    ; Strict decimal parser: no sign, no suffix, no spaces.
    or      cx, cx
    jz      @@Invalid
    cmp     cx, 5
    ja      @@Invalid
    xor     ax, ax
@@DigitLoop:
    mov     dl, [si]
    cmp     dl, '0'
    jb      @@Invalid
    cmp     dl, '9'
    ja      @@Invalid
    cmp     ax, 6553
    ja      @@Invalid
    mov     bx, ax
    shl     ax, 1
    shl     bx, 1
    shl     bx, 1
    shl     bx, 1
    add     ax, bx
    sub     dl, '0'
    xor     dh, dh
    add     ax, dx
    inc     si
    dec     cx
    jnz     @@DigitLoop

    ; The five named speeds are hardware-tuned constants measured against
    ; real hardware, not a formula derived from the baud number.
    cmp     ax, 1200
    je      @@Named1200
    cmp     ax, 2400
    je      @@Named2400
    cmp     ax, 9600
    je      @@Named9600
    cmp     ax, 19200
    je      @@Named19200
    cmp     ax, 38400
    je      @@Named38400

    cmp     ax, 25
    jb      @@Invalid
    cmp     ax, 1600
    ja      @@Invalid
    xor     dx, dx
    mov     bx, 25
    div     bx
    or      dx, dx
    jnz     @@Invalid
    ; AX = step count (1-64); raw Maximum Interrupt Disable Time = (count-1) << 8.
    dec     ax
    mov     cl, 8
    shl     ax, cl
    jmp     @@Accept

@@Named1200:
    mov     ax, EEPROM_MODEM_1200
    jmp     @@Accept
@@Named2400:
    mov     ax, EEPROM_MODEM_2400
    jmp     @@Accept
@@Named9600:
    mov     ax, EEPROM_MODEM_9600
    jmp     @@Accept
@@Named19200:
    mov     ax, EEPROM_MODEM_19200
    jmp     @@Accept
@@Named38400:
    mov     ax, EEPROM_MODEM_38400

@@Accept:
    mov     [cfg_modem_value], ax
    or      [cfg_parse_flags], CFG_PARSE_MODEM
    mov     [cfg_last_error], CFG_ERR_NONE
    jmp     @@Done

@@Invalid:
    mov     [cfg_last_error], CFG_ERR_BAD_MODEM

@@Done:
    pop     cx
    pop     si
    pop     dx
    pop     bx
    pop     ax
    ret
ENDP Cfg_Handle_MODEM

PROC Cfg_Handle_OPTIMIZE NEAR
    push    ax
    push    bx
    push    cx

    cmp     cx, 3
    je      @@Dos
    cmp     cx, 4
    je      @@Os2
    cmp     cx, 6
    je      @@Server
    cmp     cx, 7
    je      @@Windows
    jmp     @@Invalid

@@Dos:
    cmp     [BYTE si], 'D'
    jne     @@Invalid
    cmp     [BYTE si+1], 'O'
    jne     @@Invalid
    cmp     [BYTE si+2], 'S'
    jne     @@Invalid
    mov     al, 1
    jmp     @@Accept
@@Windows:
    cmp     [BYTE si], 'W'
    jne     @@Invalid
    cmp     [BYTE si+1], 'I'
    jne     @@Invalid
    cmp     [BYTE si+2], 'N'
    jne     @@Invalid
    cmp     [BYTE si+3], 'D'
    jne     @@Invalid
    cmp     [BYTE si+4], 'O'
    jne     @@Invalid
    cmp     [BYTE si+5], 'W'
    jne     @@Invalid
    cmp     [BYTE si+6], 'S'
    jne     @@Invalid
    mov     al, 2
    jmp     @@Accept
@@Os2:
    cmp     [BYTE si], 'O'
    jne     @@Invalid
    cmp     [BYTE si+1], 'S'
    jne     @@Invalid
    cmp     [BYTE si+2], '/'
    jne     @@Invalid
    cmp     [BYTE si+3], '2'
    jne     @@Invalid
    mov     al, 2
    jmp     @@Accept
@@Server:
    cmp     [BYTE si], 'S'
    jne     @@Invalid
    cmp     [BYTE si+1], 'E'
    jne     @@Invalid
    cmp     [BYTE si+2], 'R'
    jne     @@Invalid
    cmp     [BYTE si+3], 'V'
    jne     @@Invalid
    cmp     [BYTE si+4], 'E'
    jne     @@Invalid
    cmp     [BYTE si+5], 'R'
    jne     @@Invalid
    mov     al, 3
@@Accept:
    mov     [cfg_optimize_value], al
    or      [cfg_parse_flags], CFG_PARSE_OPTIMIZE
    mov     [cfg_last_error], CFG_ERR_NONE
    jmp     @@Done
@@Invalid:
    mov     [cfg_last_error], CFG_ERR_BAD_OPTIMIZE
@@Done:
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Cfg_Handle_OPTIMIZE

PROC Cfg_Handle_PNP NEAR
    cmp     cx, 7
    je      @@CheckEnabled
    cmp     cx, 8
    je      @@CheckDisabled
    jmp     @@Invalid

@@CheckEnabled:
    cmp     [BYTE si], 'E'
    jne     @@Invalid
    cmp     [BYTE si+1], 'N'
    jne     @@Invalid
    cmp     [BYTE si+2], 'A'
    jne     @@Invalid
    cmp     [BYTE si+3], 'B'
    jne     @@Invalid
    cmp     [BYTE si+4], 'L'
    jne     @@Invalid
    cmp     [BYTE si+5], 'E'
    jne     @@Invalid
    cmp     [BYTE si+6], 'D'
    jne     @@Invalid
    mov     [cfg_pnp_value], 1
    jmp     @@Accept

@@CheckDisabled:
    cmp     [BYTE si], 'D'
    jne     @@Invalid
    cmp     [BYTE si+1], 'I'
    jne     @@Invalid
    cmp     [BYTE si+2], 'S'
    jne     @@Invalid
    cmp     [BYTE si+3], 'A'
    jne     @@Invalid
    cmp     [BYTE si+4], 'B'
    jne     @@Invalid
    cmp     [BYTE si+5], 'L'
    jne     @@Invalid
    cmp     [BYTE si+6], 'E'
    jne     @@Invalid
    cmp     [BYTE si+7], 'D'
    jne     @@Invalid
    mov     [cfg_pnp_value], 0

@@Accept:
    or      [cfg_parse_flags], CFG_PARSE_PNP
    mov     [cfg_last_error], CFG_ERR_NONE
    jmp     @@Done
@@Invalid:
    mov     [cfg_last_error], CFG_ERR_BAD_PNP
@@Done:
    ret
ENDP Cfg_Handle_PNP

PROC Cfg_Handle_FULLDUPLEX NEAR
    cmp     cx, 7
    je      @@CheckEnabled
    cmp     cx, 8
    je      @@CheckDisabled
    jmp     @@Invalid

@@CheckEnabled:
    cmp     [BYTE si], 'E'
    jne     @@Invalid
    cmp     [BYTE si+1], 'N'
    jne     @@Invalid
    cmp     [BYTE si+2], 'A'
    jne     @@Invalid
    cmp     [BYTE si+3], 'B'
    jne     @@Invalid
    cmp     [BYTE si+4], 'L'
    jne     @@Invalid
    cmp     [BYTE si+5], 'E'
    jne     @@Invalid
    cmp     [BYTE si+6], 'D'
    jne     @@Invalid
    mov     [cfg_fullduplex_value], 1
    jmp     @@Accept

@@CheckDisabled:
    cmp     [BYTE si], 'D'
    jne     @@Invalid
    cmp     [BYTE si+1], 'I'
    jne     @@Invalid
    cmp     [BYTE si+2], 'S'
    jne     @@Invalid
    cmp     [BYTE si+3], 'A'
    jne     @@Invalid
    cmp     [BYTE si+4], 'B'
    jne     @@Invalid
    cmp     [BYTE si+5], 'L'
    jne     @@Invalid
    cmp     [BYTE si+6], 'E'
    jne     @@Invalid
    cmp     [BYTE si+7], 'D'
    jne     @@Invalid
    mov     [cfg_fullduplex_value], 0

@@Accept:
    or      [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    mov     [cfg_last_error], CFG_ERR_NONE
    jmp     @@Done
@@Invalid:
    mov     [cfg_last_error], CFG_ERR_BAD_FULLDUPLEX
@@Done:
    ret
ENDP Cfg_Handle_FULLDUPLEX

PROC Cfg_Report_Error NEAR
; Entry: AL = CFG_ERR_* code. Preserves all registers.
    push    ax
    push    bx
    push    dx

    xor     ah, ah
    cmp     ax, CFG_ERR_COUNT
    jae     @@Done
    mov     bx, ax
    shl     bx, 1
    mov     dx, [cfg_error_messages+bx]
    or      dx, dx
    jz      @@Done
    mov     ah, 09h
    int     21h

@@Done:
    pop     dx
    pop     bx
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
    call    Nic_Activate_Tagged_Cards

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

; Read the fields needed to construct one record while the current contender
; still owns the ID port.
PROC Read_Id_Contender_Data NEAR
    push    ax

    mov     al, EEPROM_NODE_0
    call    Nic_IdPort_Read_Word

    mov     al, EEPROM_NODE_1
    call    Nic_IdPort_Read_Word

    mov     al, EEPROM_NODE_2
    call    Nic_IdPort_Read_Word

    mov     al, EEPROM_ADDR_CFG
    call    Nic_IdPort_Read_Word
    mov     [id_addr_cfg], ax

    mov     al, EEPROM_RESOURCE_CFG
    call    Nic_IdPort_Read_Word
    mov     [id_resource_cfg], ax

    ; Original sub_339 stores the OEM node address at words 0Ah through 0Ch.
    mov     al, EEPROM_OEM_NODE_0
    call    Nic_IdPort_Read_Word
    mov     [id_oem0], ax

    mov     al, EEPROM_OEM_NODE_1
    call    Nic_IdPort_Read_Word
    mov     [id_oem1], ax

    mov     al, EEPROM_OEM_NODE_2
    call    Nic_IdPort_Read_Word
    mov     [id_oem2], ax

    mov     al, EEPROM_SOFTWARE_INFO
    call    Nic_IdPort_Read_Word

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
    ; Selector 1Fh selects EISA slot specific addressing and is rejected by
    ; Discover_Id_Port_Cards before normal ISA record construction, so the
    ; selector decoded here is always in the range 00h through 1Eh.
    mov     ax, [id_addr_cfg]
    and     ax, 001Fh
    mov     cl, 4
    shl     ax, cl
    add     ax, 0200h
    mov     [WORD di + NIC_IO_BASE], ax

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
    ; ISA ID-port discovery for 3C509/3C509B.
    ; Classic 3Com contention sequence on ID_PORT (0110h): send the 255-byte
    ; or short LFSR stream, probe the EEPROM manufacturer/product words, then
    ; tag and activate the adapter at its runtime IOBASE.
    push    ax
    push    bx
    push    dx
    push    di

    call    Nic_Init_Id_Port

@@ProbeAgain:
    mov     al, [id_next_tag]
    cmp     al, MAX_CARDS
    ja      @@Done

    pushf
    cli
    cmp     [id_short_mode], 0
    je      @@UseFull
    call    Nic_IdPort_Send_Short_Sequence
    jmp     @@SequenceReady
@@UseFull:
    call    Nic_IdPort_Send_Full_Sequence
@@SequenceReady:

    ; The original presence test is manufacturer word 7, not node word 0.
    mov     al, EEPROM_MFG_ID
    call    Nic_IdPort_Read_Word
    cmp     ax, 06D50h
    je      @@ManufacturerGood

    popf
    cmp     [id_short_mode], 0
    je      @@Done
    mov     [id_short_mode], 0
    jmp     @@ProbeAgain

@@ManufacturerGood:
    mov     al, EEPROM_PRODUCT_ID
    call    Nic_IdPort_Read_Word
    mov     [id_product], ax
    call    Is_3C509_Family
    jnc     @@ProductGood

    ; Original sub_332 also has an 8050h family branch for other EtherLink III
    ; members.  This reduced executable is intentionally restricted to 3C509.
    popf
    cmp     [id_short_mode], 0
    je      @@Done
    mov     [id_short_mode], 0
    jmp     @@ProbeAgain

@@ProductGood:
    ; Reading the node address also performs the standard contention process.
    call    Read_Id_Contender_Data

    ; Address Configuration selector 1Fh selects EISA slot specific addressing,
    ; which this ISA only utility does not support.  Reject the contender
    ; before normal record construction.
    mov     ax, [id_addr_cfg]
    and     ax, 001Fh
    cmp     ax, 001Fh
    je      @@SkipEisaContender

    ; Suppress a duplicate identity and reapply its existing tag.  This mirrors
    ; the original duplicate path used when the same board is visible by more
    ; than one enumeration mechanism.
    call    Find_Duplicate_Id_Record
    jc      @@NewRecord
    and     al, 07h
    or      al, ID_CMD_SET_TAG
    call    Nic_IdPort_Write_Command
    popf
    jmp     @@ProbeAgain

@@SkipEisaContender:
    ; Retire the unsupported contender from further ID port contention with
    ; the reserved nonzero skip tag.  No nic_table record is created,
    ; card_count is not incremented, and the adapter is never activated.
    ; The scan then continues with the remaining untagged adapters.
    mov     al, ID_CMD_SET_TAG
    or      al, ID_TAG_SKIP_EISA
    call    Nic_IdPort_Write_Command
    popf
    mov     dx, OFFSET msg_id_eisa_unsupported
    call    Print_String
    jmp     @@ProbeAgain

@@NewRecord:
    mov     ax, [card_count]
    cmp     ax, MAX_CARDS
    jae     @@TableFull

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
    call    Nic_IdPort_Write_Command

    inc     [card_count]
    inc     [id_next_tag]
    popf
    jmp     @@ProbeAgain

@@TableFull:
    popf
@@Done:
    pop     di
    pop     dx
    pop     bx
    pop     ax
    ret
ENDP Discover_Id_Port_Cards

; ============================================================================
; Active register access and signature verification
; ============================================================================

; ============================================================================
; Active EEPROM access
; ============================================================================

; Read hardware capability sources independently.
; Input DX = active I/O base.  Output AX = NIC_CAP_* values, BX =
; NIC_CAP_VALID_* source-validity flags, CF always clear.  The current window
; is restored.  A clear validity bit means that capability group is unavailable.
PROC Nic_Read_Capabilities NEAR
    push    cx
    push    dx
    push    si
    push    di

    mov     si, dx
    call    Nic_Get_Current_Window
    mov     di, ax
    xor     bx, bx                  ; validity result
    xor     cx, cx                  ; normalized capability result

    mov     dx, si
    xor     al, al
    call    Nic_Select_Window
    mov     bx, EL3_W0_CONFIG_CONTROL
    call    Nic_Reg_Read_Word
    xor     bx, bx                  ; discard register offset; rebuild validity
    cmp     ax, 0FFFFh
    je      @@ReadPnp
    or      bx, NIC_CAP_VALID_CONNECTORS
    test    ax, W0_CONFIG_CONTROL_TP_PRESENT
    jz      @@NoTp
    or      cx, NIC_CAP_TP
@@NoTp:
    test    ax, W0_CONFIG_CONTROL_AUI_PRESENT
    jz      @@NoAui
    or      cx, NIC_CAP_AUI
@@NoAui:
    test    ax, W0_CONFIG_CONTROL_BNC_PRESENT
    jz      @@ReadPnp
    or      cx, NIC_CAP_BNC

@@ReadPnp:
    mov     dx, si
    mov     al, EEPROM_CAPABILITY
    call    Nic_EEPROM_Read
    jc      @@ReadRevision
    or      bx, NIC_CAP_VALID_PNP
    test    ax, EEPROM_CAPABILITY_PNP
    jz      @@ReadRevision
    or      cx, NIC_CAP_PNP

@@ReadRevision:
    test    bx, NIC_CAP_VALID_CONNECTORS
    jz      @@Restore
    mov     dx, si
    mov     al, EEPROM_REVISION_INFO
    call    Nic_EEPROM_Read
    jc      @@Restore
    or      bx, NIC_CAP_VALID_FULLDUPLEX
    test    cx, NIC_CAP_TP
    jz      @@Restore
    and     ax, 00FFh
    cmp     ax, EEPROM_REVISION_3C509B
    jb      @@Restore
    or      cx, NIC_CAP_FULLDUPLEX

@@Restore:
    mov     ax, di
    mov     dx, si
    call    Nic_Select_Window
    mov     ax, cx
    clc
@@Exit:
    pop     di
    pop     si
    pop     dx
    pop     cx
    ret
ENDP Nic_Read_Capabilities

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
    call    Nic_EEPROM_Read
    jc      @@Fail
    mov     [id_addr_cfg], ax

    mov     dx, si
    mov     al, EEPROM_RESOURCE_CFG
    call    Nic_EEPROM_Read
    jc      @@Fail
    mov     [id_resource_cfg], ax

    mov     dx, si
    mov     al, EEPROM_OEM_NODE_0
    call    Nic_EEPROM_Read
    jc      @@Fail
    mov     [id_oem0], ax
    mov     dx, si
    mov     al, EEPROM_OEM_NODE_1
    call    Nic_EEPROM_Read
    jc      @@Fail
    mov     [id_oem1], ax
    mov     dx, si
    mov     al, EEPROM_OEM_NODE_2
    call    Nic_EEPROM_Read
    jc      @@Fail
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

    clc
    jmp     @@Done

@@Fail:
    stc

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

    call    Nic_Check_3Com_Signature
    jc      @@PortLoop

    push    ax
    call    Find_Record_By_Base
    pop     ax
    jnc     @@UpdateExisting

    mov     cx, [card_count]
    cmp     cx, MAX_CARDS
    jae     @@Done

    ; The record offset computation clobbers AX, BX and DX, so keep the
    ; signature results from the probe above.
    push    ax
    push    bx
    mov     ax, cx
    mov     bx, NIC_RECORD_SIZE
    mul     bx
    mov     di, OFFSET nic_table
    add     di, ax
    pop     bx
    pop     ax

    mov     dx, [si-2]
    call    Build_Record_From_Active
    jc      @@PortLoop
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

; EEPROM busy wait shared by original sub_314 and sub_315.
; Input DX = adapter base.  Carry set on timeout.
PROC Cfg_Eeprom_Wait_Ready NEAR
    push    ax
    push    bx

    call    Cfg_Start_Wait_Timer
@@Loop:
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Nic_Reg_Read_Word
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
    call    Nic_Select_Window

    mov     ax, si
    or      ax, 0080h
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Nic_Reg_Write_Word
    call    Cfg_Eeprom_Wait_Ready

    mov     bx, EL3_W0_EEPROM_DATA
    call    Nic_Reg_Read_Word
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
    call    Nic_Select_Window

    mov     ax, 0030h
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Nic_Reg_Write_Word
    call    Cfg_Eeprom_Wait_Ready

    mov     ax, 00C0h
    or      ax, si
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Nic_Reg_Write_Word
    call    Cfg_Eeprom_Wait_Ready

    mov     ax, di
    mov     bx, EL3_W0_EEPROM_DATA
    call    Nic_Reg_Write_Word

    mov     ax, 0030h
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Nic_Reg_Write_Word
    call    Cfg_Eeprom_Wait_Ready

    mov     ax, 0040h
    or      ax, si
    mov     bx, EL3_W0_EEPROM_COMMAND
    call    Nic_Reg_Write_Word
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

; Destination EEPROM word 17h low byte. Domain: words 13h through 16h.
PROC Cfg_Checksum_17_Low NEAR
    push    bx
    push    dx
    push    si

    xor     bx, bx
    mov     si, EEPROM_SECONDARY_CONFIG_START
@@Loop:
    mov     ax, si
    call    Cfg_Eeprom_Read
    jc      @@Fail
    call    Cfg_Checksum_Xor_Word
    inc     si
    cmp     si, EEPROM_SECONDARY_CONFIG_END
    jb      @@Loop
    mov     al, bl
    pop     si
    pop     dx
    pop     bx
    clc
    ret
@@Fail:
    pop     si
    pop     dx
    pop     bx
    stc
    ret
ENDP Cfg_Checksum_17_Low

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

    call    Nic_IdPort_Eeprom_Delay
    call    Nic_IdPort_Eeprom_Delay
    call    Nic_IdPort_Eeprom_Delay
    call    Nic_IdPort_Eeprom_Delay
    call    Nic_IdPort_Eeprom_Delay
    call    Nic_IdPort_Eeprom_Delay
    call    Nic_IdPort_Eeprom_Delay
    call    Nic_IdPort_Eeprom_Delay

    mov     si, [cfg_selected_ptr]
    pushf
    cli
    cmp     [BYTE si + NIC_ID_MODE], 0
    je      @@Full
    call    Nic_IdPort_Send_Short_Sequence
    jmp     @@WriteTag
@@Full:
    call    Nic_IdPort_Send_Full_Sequence
@@WriteTag:
    mov     dx, ID_PORT
    mov     al, ID_CMD_SET_TAG
    or      al, [BYTE si + NIC_TAG]
    call    Nic_IdPort_Write_Command
    popf

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
    test    [cfg_parse_flags], CFG_PARSE_PNP
    jz      @@InactiveModem
    mov     [cfg_last_error], CFG_ERR_PNP_INACTIVE
    jmp     @@Fail
@@InactiveModem:
    test    [cfg_parse_flags], CFG_PARSE_MODEM
    jz      @@InactiveFD
    mov     [cfg_last_error], CFG_ERR_MODEM_INACTIVE
    jmp     @@Fail
@@InactiveFD:
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jz      @@InactiveOptimize
    mov     [cfg_last_error], CFG_ERR_FD_INACTIVE
    jmp     @@Fail
@@InactiveOptimize:
    test    [cfg_parse_flags], CFG_PARSE_OPTIMIZE
    jz      @@InactiveBAddress
    mov     [cfg_last_error], CFG_ERR_OPTIMIZE_INACTIVE
    jmp     @@Fail
@@InactiveBAddress:
    test    [cfg_parse_flags], CFG_PARSE_BADDRESS
    jz      @@InactiveBSize
    mov     [cfg_last_error], CFG_ERR_BADDRESS_INACTIVE
    jmp     @@Fail
@@InactiveBSize:
    test    [cfg_parse_flags], CFG_PARSE_BSIZE
    jz      @@InactiveIRQ
    mov     [cfg_last_error], CFG_ERR_BSIZE_INACTIVE
    jmp     @@Fail
@@InactiveIRQ:
    mov     [cfg_last_error], CFG_ERR_INT_INACTIVE
    jmp     @@Fail

@@HaveBase:
    mov     [cfg_txn_old_base], dx
    mov     [cfg_txn_new_base], dx

    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jnz     @@ReadWord08
    test    [cfg_parse_flags], CFG_PARSE_BADDRESS
    jnz     @@ReadWord08
    test    [cfg_parse_flags], CFG_PARSE_BSIZE
    jnz     @@ReadWord08
    test    [cfg_parse_flags], CFG_PARSE_TR
    jnz     @@ReadWord08
    ; FULLDUPLEX validation decodes the currently persistent transceiver when
    ; no prospective /TR was supplied.
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jz      @@NoWord08
@@ReadWord08:
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

    test    [cfg_parse_flags], CFG_PARSE_PNP
    jz      @@NoWord13
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_CONFIG_CONTROL
    call    Cfg_Eeprom_Read
    jc      @@ReadPNPFail
    mov     [cfg_txn_old_word13], ax
    jmp     @@Word13Done
@@NoWord13:
    mov     [cfg_txn_old_word13], 0
@@Word13Done:

    test    [cfg_parse_flags], CFG_PARSE_MODEM
    jnz     @@ReadWord0D
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jnz     @@ReadWord0D
    test    [cfg_parse_flags], CFG_PARSE_OPTIMIZE
    jz      @@NoWord0D
@@ReadWord0D:
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_SOFTWARE_INFO
    call    Cfg_Eeprom_Read
    jc      @@ReadMODEMFail
    mov     [cfg_txn_old_word0d], ax
    jmp     @@Word0DDone
@@NoWord0D:
    mov     [cfg_txn_old_word0d], 0
@@Word0DDone:

    ; PNP-only transactions use the secondary checksum and do not depend on
    ; EEPROM word 0Fh being readable.
    test    [cfg_parse_flags], CFG_PARSE_INT + CFG_PARSE_IOBASE + CFG_PARSE_MODEM + CFG_PARSE_FULLDUPLEX + CFG_PARSE_OPTIMIZE + CFG_PARSE_BADDRESS + CFG_PARSE_BSIZE + CFG_PARSE_TR
    jz      @@NoWord0F
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_CHECKSUM
    call    Cfg_Eeprom_Read
    jc      @@ReadOptimizeFail
    mov     [cfg_txn_old_word0f], ax
    jmp     @@Word0FDone
@@NoWord0F:
    mov     [cfg_txn_old_word0f], 0
@@Word0FDone:

    ; Both live words are required because original ISA reactivation restores
    ; Address Configuration and Resource Configuration together.
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    xor     al, al
    call    Nic_Select_Window
    mov     bx, EL3_W0_ADDRESS_CFG
    call    Nic_Reg_Read_Word
    mov     [cfg_txn_old_live06], ax
    mov     bx, EL3_W0_RESOURCE_CFG
    call    Nic_Reg_Read_Word
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
    jmp     @@Fail
@@ReadPNPFail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_PNP_EEPROM_READ
    jmp     @@Fail
@@ReadMODEMFail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_MODEM_EEPROM_READ
    jmp     @@Fail
@@ReadOptimizeFail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_OPTIMIZE_EEPROM_READ
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
    mov     ax, [cfg_txn_old_word0d]
    mov     [cfg_txn_new_word0d], ax
    mov     ax, [cfg_txn_old_word13]
    mov     [cfg_txn_new_word13], ax
    mov     ax, [cfg_txn_old_word0f]
    mov     [cfg_txn_new_word0f], ax
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

; Merge only the staged PNP field into the prospective persistent image.
; /PNP:0 encodes disabled state as config-control bits 3:2 equal 01b (0004h).
PROC Cfg_Prepare_PNP NEAR
    push    ax

    mov     ax, [cfg_txn_new_word13]
    and     ax, 0FFF3h
    cmp     [cfg_pnp_value], 0
    jne     @@Store
    or      ax, 0004h
@@Store:
    mov     [cfg_txn_new_word13], ax

    pop     ax
    ret
ENDP Cfg_Prepare_PNP

; Merge only the Maximum Interrupt Disable Time field (bits 13:8) into the
; prospective Software Information word.  Always use RMW.
PROC Cfg_Prepare_MODEM NEAR
    push    ax
    push    dx

    mov     ax, [cfg_txn_new_word0d]
    and     ax, NOT EEPROM_SOFTWARE_INFO_INT_DISABLE_MASK
    mov     dx, [cfg_modem_value]
    and     dx, EEPROM_SOFTWARE_INFO_INT_DISABLE_MASK
    or      ax, dx
    mov     [cfg_txn_new_word0d], ax

    pop     dx
    pop     ax
    ret
ENDP Cfg_Prepare_MODEM

; Merge only the FULLDUPLEX bit into the prospective persistent image.
; Only bit 15 of EEPROM word 0Dh is owned by FULLDUPLEX.  Always RMW.
PROC Cfg_Prepare_FULLDUPLEX NEAR
    push    ax

    mov     ax, [cfg_txn_new_word0d]
    and     ax, 7FFFh               ; clear bit 15
    cmp     [cfg_fullduplex_value], 0
    je      @@Store
    or      ax, 8000h               ; set bit 15 if requested
@@Store:
    mov     [cfg_txn_new_word0d], ax

    pop     ax
    ret
ENDP Cfg_Prepare_FULLDUPLEX

; Merge only the documented Software Optimization field into EEPROM word 0Dh.
PROC Cfg_Prepare_OPTIMIZE NEAR
    push    ax
    push    cx

    mov     ax, [cfg_txn_new_word0d]
    and     ax, 0FFCFh
    xor     cx, cx
    mov     cl, [cfg_optimize_value]
    shl     cx, 1
    shl     cx, 1
    shl     cx, 1
    shl     cx, 1
    or      ax, cx
    mov     [cfg_txn_new_word0d], ax

    pop     cx
    pop     ax
    ret
ENDP Cfg_Prepare_OPTIMIZE

; Merge only the staged Boot ROM base address field into the prospective
; EEPROM word 08h image.  Bits 11:8 are owned by BADDRESS; bits 4:0
; (IOBASE), 13:12 (BSIZE) and 15:14 (media, reserved for /XCVR) are
; preserved.  The raw requested index is written as-is; any alignment
; "rounding" for a given size is a read-side hardware/display concern
; already handled faithfully by Print_Boot_Rom_Value, not enforced here.
; Merge only the staged Boot ROM base field into the prospective EEPROM
; word 08h image.  Bits 11:8 are owned by BADDRESS; all other bits preserved.
; If /BSIZE:DISABLED is also staged, Cfg_Prepare_BSIZE runs afterwards and
; clears this field again, so an /BADDRESS given alongside DISABLED is
; effectively ignored.
PROC Cfg_Prepare_BADDRESS NEAR
    push    ax
    push    bx
    push    cx

    mov     ax, [cfg_txn_new_word08]
    and     ax, 0F0FFh
    xor     bx, bx
    mov     bl, [cfg_baddress_value]
    mov     cl, 8
    shl     bx, cl
    or      ax, bx
    mov     [cfg_txn_new_word08], ax

    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Cfg_Prepare_BADDRESS

; Merge the staged Boot ROM size field into the prospective EEPROM word 08h
; image.  Bits 13:12 are owned by BSIZE; all other bits preserved.  When
; /BSIZE:DISABLED was staged, both the size and base fields are cleared
; instead, overriding any /BADDRESS staged earlier in the same transaction.
PROC Cfg_Prepare_BSIZE NEAR
    push    ax
    push    bx
    push    cx

    mov     ax, [cfg_txn_new_word08]
    cmp     [cfg_bsize_disabled], 1
    je      @@Disable

    and     ax, 0CFFFh
    xor     bx, bx
    mov     bl, [cfg_bsize_value]
    mov     cl, 12
    shl     bx, cl
    or      ax, bx
    mov     [cfg_txn_new_word08], ax
    jmp     @@Done

@@Disable:
    and     ax, 0C0FFh
    mov     [cfg_txn_new_word08], ax

@@Done:
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Cfg_Prepare_BSIZE

; Merge only the transceiver selection into the prospective EEPROM word 08h
; image.  AUTO (sentinel 0FFh) clears bits 15:14 and sets bit 7.  TP/AUI/COAX
; clear bit 7 and write the raw value into bits 15:14.  All other bits preserved.
PROC Cfg_Prepare_TR NEAR
    push    ax
    push    bx
    push    cx

    mov     ax, [cfg_txn_new_word08]
    and     ax, 3F7Fh               ; clear bits 15:14 and bit 7
    mov     bl, [cfg_tr_value]
    cmp     bl, 0FFh
    jne     @@NotAuto
    or      ax, 0080h               ; AUTO: set bit 7 only
    jmp     @@Done
@@NotAuto:
    xor     bh, bh
    mov     cl, 14
    shl     bx, cl                  ; shift raw value into bits 15:14
    or      ax, bx
@@Done:
    mov     [cfg_txn_new_word08], ax

    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Cfg_Prepare_TR

; FULLDUPLEX:ENABLED requires effective TP selection.  A staged /TR takes
; precedence; otherwise decode the transaction's current Address Configuration.
PROC Cfg_Validate_FD_Transceiver NEAR
    push    ax
    push    bx
    push    cx

    cmp     [cfg_fullduplex_value], 0
    je      @@Success
    test    [cfg_parse_flags], CFG_PARSE_TR
    jz      @@Current
    cmp     [cfg_tr_value], 0
    je      @@Success
    jmp     @@Conflict
@@Current:
    mov     ax, [cfg_txn_old_word08]
    test    ax, W0_ADDRESS_CFG_AUTO_SELECT
    jnz     @@Conflict
    and     ax, W0_ADDRESS_CFG_XCVR_MASK
    mov     cl, W0_ADDRESS_CFG_XCVR_SHIFT
    shr     ax, cl
    or      ax, ax
    jz      @@Success
@@Conflict:
    mov     [cfg_last_error], CFG_ERR_FD_TRANSCEIVER
    stc
    jmp     @@Done
@@Success:
    clc
@@Done:
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Cfg_Validate_FD_Transceiver

; Compare current and prospective states once after all properties are prepared.
; INT keeps release 0.3.3 unchanged semantics: its persistent EEPROM field is
; authoritative.  A matching persistent IRQ alone remains a no write success
; unless an IOBASE migration is already required and must restore live state.
PROC Cfg_Txn_Detect_Changes NEAR
    push    ax

    mov     [cfg_txn_change_flags], 0

    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jnz     @@CheckWord08
    test    [cfg_parse_flags], CFG_PARSE_BADDRESS
    jnz     @@CheckWord08
    test    [cfg_parse_flags], CFG_PARSE_BSIZE
    jnz     @@CheckWord08
    test    [cfg_parse_flags], CFG_PARSE_TR
    jz      @@INT

@@CheckWord08:
    mov     ax, [cfg_txn_old_word08]
    cmp     ax, [cfg_txn_new_word08]
    je      @@NoW08
    or      [cfg_txn_change_flags], CFG_TXN_CHG_WORD08
@@NoW08:
    ; Live register sync and I/O migration only apply to /IOBASE; Boot ROM
    ; fields (/BADDRESS, /BSIZE) have no live-register or migration component.
    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jz      @@INT
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
    jz      @@PNP
    mov     ax, [cfg_txn_old_word09]
    cmp     ax, [cfg_txn_new_word09]
    je      @@INTPersistentSame
    or      [cfg_txn_change_flags], CFG_TXN_WORD09_INT_MASK
    mov     ax, [cfg_txn_old_live08]
    cmp     ax, [cfg_txn_new_live08]
    je      @@PNP
    or      [cfg_txn_change_flags], CFG_TXN_CHG_LIVE08
    jmp     @@PNP

@@INTPersistentSame:
    ; During a real IOBASE migration the activation restore uses the requested
    ; staged IRQ, even when EEPROM already contains it.  Outside migration, the
    ; tested 0.3.3 unchanged INT path performs no live correction.
    test    [cfg_txn_change_flags], CFG_TXN_MIGRATE_IO
    jz      @@PNP
    mov     ax, [cfg_txn_old_live08]
    cmp     ax, [cfg_txn_new_live08]
    je      @@PNP
    or      [cfg_txn_change_flags], CFG_TXN_CHG_LIVE08

@@PNP:
    test    [cfg_parse_flags], CFG_PARSE_PNP
    jz      @@MODEM
    mov     ax, [cfg_txn_old_word13]
    cmp     ax, [cfg_txn_new_word13]
    je      @@MODEM
    or      [cfg_txn_change_flags], CFG_TXN_CHG_WORD13

@@MODEM:
    test    [cfg_parse_flags], CFG_PARSE_MODEM
    jz      @@FULLDUPLEX
    mov     ax, [cfg_txn_old_word0d]
    cmp     ax, [cfg_txn_new_word0d]
    je      @@FULLDUPLEX
    or      [cfg_txn_change_flags], CFG_TXN_CHG_WORD0D

@@FULLDUPLEX:
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jz      @@Optimize
    mov     ax, [cfg_txn_old_word0d]
    cmp     ax, [cfg_txn_new_word0d]
    je      @@Optimize
    or      [cfg_txn_change_flags], CFG_TXN_CHG_WORD0D

@@Optimize:
    test    [cfg_parse_flags], CFG_PARSE_OPTIMIZE
    jz      @@Done
    mov     ax, [cfg_txn_old_word0d]
    cmp     ax, [cfg_txn_new_word0d]
    je      @@Done
    or      [cfg_txn_change_flags], CFG_TXN_CHG_WORD0D

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
    test    [cli_flags], CLI_FLAG_VERBOSE
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
    call    Nic_Read_Status
    cmp     ax, 0FFFFh
    je      @@Retag
    mov     dx, bx
    call    Nic_Check_3Com_Signature
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

    test    [cli_flags], CLI_FLAG_VERBOSE
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
    call    Nic_Select_Window
    mov     ax, [cfg_txn_new_live06]
    mov     bx, EL3_W0_ADDRESS_CFG
    call    Nic_Reg_Write_Word
    mov     ax, [cfg_txn_new_live08]
    mov     bx, EL3_W0_RESOURCE_CFG
    call    Nic_Reg_Write_Word

    ; Confirm that an EtherLink III register image is reachable.  At this stage
    ; keep the proven strict product and ASIC comparison before any EEPROM write.
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Nic_Check_3Com_Signature
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
    call    Nic_Select_Window

    test    [cfg_txn_change_flags], CFG_TXN_MIGRATE_IO
    jz      @@CheckIRQ
    mov     bx, EL3_W0_ADDRESS_CFG
    call    Nic_Reg_Read_Word
    and     al, 01Fh
    cmp     al, [cfg_txn_io_selector]
    jne     @@ActivationLiveFail

@@CheckIRQ:
    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@PreserveIRQ
    test    [cfg_txn_change_flags], CFG_TXN_INT_MIGRATE_MASK
    jz      @@Success
    mov     bx, EL3_W0_RESOURCE_CFG
    call    Nic_Reg_Read_Word
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
    call    Nic_Reg_Read_Word
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

; Write persistent property words in original sub_342 order, then update only
; the checksum domains whose data words changed.
PROC Cfg_Txn_Write_EEPROM NEAR
    push    ax
    push    bx
    push    dx
    push    si

    test    [cfg_txn_change_flags], CFG_TXN_EEPROM_MASK
    jnz     @@Start
    jmp     @@Success

@@Start:
    test    [cli_flags], CLI_FLAG_VERBOSE
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
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@Word09
    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jz      @@Word08NoIOBaseNote
    mov     dx, OFFSET msg_cfg_iobase_word_written
    mov     ah, 09h
    int     21h
@@Word08NoIOBaseNote:
    test    [cfg_parse_flags], CFG_PARSE_BADDRESS
    jnz     @@Word08BootRomNote
    test    [cfg_parse_flags], CFG_PARSE_BSIZE
    jz      @@Word09
@@Word08BootRomNote:
    mov     dx, OFFSET msg_cfg_bootrom_word_written
    mov     ah, 09h
    int     21h

@@Word09:
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD09
    jz      @@Word0D
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     bx, [cfg_txn_new_word09]
    mov     al, EEPROM_RESOURCE_CFG
    call    Cfg_Eeprom_Write
    jc      @@Write09Fail
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@Word0D
    mov     dx, OFFSET msg_cfg_irq_word_written
    mov     ah, 09h
    int     21h

@@Word0D:
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD0D
    jz      @@Word13
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     bx, [cfg_txn_new_word0d]
    mov     al, EEPROM_SOFTWARE_INFO
    call    Cfg_Eeprom_Write
    jc      @@Write0DFail
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@Word13
    test    [cfg_parse_flags], CFG_PARSE_OPTIMIZE
    jnz     @@Word0DPrint
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jnz     @@Word0DWrittenFD
    mov     dx, OFFSET msg_cfg_modem_word_written
    jmp     @@Word0DPrint
@@Word0DWrittenFD:
    mov     dx, OFFSET msg_cfg_fd_word_written
@@Word0DPrint:
    mov     ah, 09h
    int     21h

@@Word13:
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD13
    jz      @@Checksums
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     bx, [cfg_txn_new_word13]
    mov     al, EEPROM_CONFIG_CONTROL
    call    Cfg_Eeprom_Write
    jc      @@Write13Fail
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@Checksums
    mov     dx, OFFSET msg_cfg_pnp_word_written
    mov     ah, 09h
    int     21h

@@Checksums:
    test    [cfg_txn_change_flags], CFG_TXN_PRIMARY_CHECKSUM_MASK
    jnz     @@ChecksumAnnounce
    test    [cfg_txn_change_flags], CFG_TXN_SECONDARY_CHECKSUM_MASK
    jz      @@ChecksumUpdated
@@ChecksumAnnounce:
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@PrimaryChecksum
    mov     dx, OFFSET msg_cfg_update_checksum
    mov     ah, 09h
    int     21h
@@PrimaryChecksum:
    test    [cfg_txn_change_flags], CFG_TXN_PRIMARY_CHECKSUM_MASK
    jz      @@SecondaryChecksum
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Cfg_Checksum_0F_Low
    jc      @@ChecksumFail
    mov     [cfg_txn_checksum], al

    mov     ax, [cfg_txn_new_word0f]
    and     ax, 0FF00h
    xor     bx, bx
    mov     bl, [cfg_txn_checksum]
    or      ax, bx
    mov     [cfg_txn_new_word0f], ax
    mov     bx, ax
    mov     al, EEPROM_CHECKSUM
    call    Cfg_Eeprom_Write
    jc      @@ChecksumWriteFail

    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_CHECKSUM
    call    Cfg_Eeprom_Read
    jc      @@ChecksumFail
    cmp     ax, [cfg_txn_new_word0f]
    jne     @@ChecksumFail

@@SecondaryChecksum:
    test    [cfg_txn_change_flags], CFG_TXN_SECONDARY_CHECKSUM_MASK
    jz      @@ChecksumUpdated
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_SECONDARY_CHECKSUM
    call    Cfg_Eeprom_Read
    jc      @@ChecksumFail
    mov     [cfg_txn_checksum_word], ax
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Cfg_Checksum_17_Low
    jc      @@ChecksumFail
    and     [cfg_txn_checksum_word], 0FF00h
    xor     bx, bx
    mov     bl, al
    or      [cfg_txn_checksum_word], bx
    mov     bx, [cfg_txn_checksum_word]
    mov     al, EEPROM_SECONDARY_CHECKSUM
    call    Cfg_Eeprom_Write
    jc      @@ChecksumWriteFail
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_SECONDARY_CHECKSUM
    call    Cfg_Eeprom_Read
    jc      @@ChecksumFail
    cmp     ax, [cfg_txn_checksum_word]
    jne     @@ChecksumFail
@@ChecksumUpdated:
    test    [cli_flags], CLI_FLAG_VERBOSE
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
    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jnz     @@Write08FailIOBase
    test    [cfg_parse_flags], CFG_PARSE_BADDRESS
    jnz     @@Write08FailBAddress
    mov     [cfg_last_error], CFG_ERR_BSIZE_EEPROM_WRITE
    jmp     @@Fail
@@Write08FailBAddress:
    mov     [cfg_last_error], CFG_ERR_BADDRESS_EEPROM_WRITE
    jmp     @@Fail
@@Write08FailIOBase:
    mov     [cfg_last_error], CFG_ERR_IOBASE_EEPROM_WRITE
    jmp     @@Fail
@@Write09Fail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_EEPROM_WRITE
    jmp     @@Fail
@@Write0DFail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    test    [cfg_parse_flags], CFG_PARSE_OPTIMIZE
    jnz     @@OptimizeWriteFail
    mov     [cfg_last_error], CFG_ERR_MODEM_EEPROM_WRITE
    jmp     @@Fail
@@OptimizeWriteFail:
    mov     [cfg_last_error], CFG_ERR_OPTIMIZE_EEPROM_WRITE
    jmp     @@Fail
@@Write13Fail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_PNP_EEPROM_WRITE
    jmp     @@Fail
@@ChecksumWriteFail:
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
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@Select
    mov     dx, OFFSET msg_cfg_txn_live
    mov     ah, 09h
    int     21h

@@Select:
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    xor     al, al
    call    Nic_Select_Window

    test    [cfg_txn_change_flags], CFG_TXN_LIVE06_MASK
    jz      @@INT
    mov     ax, [cfg_txn_new_live06]
    mov     bx, EL3_W0_ADDRESS_CFG
    call    Nic_Reg_Write_Word
    mov     bx, EL3_W0_ADDRESS_CFG
    call    Nic_Reg_Read_Word
    and     al, 01Fh
    cmp     al, [cfg_txn_io_selector]
    jne     @@IOFail

@@INT:
    test    [cfg_txn_change_flags], CFG_TXN_INT_CHANGED
    jz      @@Success
    mov     ax, [cfg_txn_new_live08]
    mov     bx, EL3_W0_RESOURCE_CFG
    call    Nic_Reg_Write_Word
    mov     bx, EL3_W0_RESOURCE_CFG
    call    Nic_Reg_Read_Word
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
    test    [cli_flags], CLI_FLAG_VERBOSE
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
    call    Nic_Check_3Com_Signature
    jc      @@ReachFail
    cmp     ax, [WORD si + NIC_PRODUCT_ID]
    jne     @@ReachFail

    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@IOPersistent
    mov     dx, OFFSET msg_cfg_txn_reachable
    mov     ah, 09h
    int     21h
    mov     ax, [WORD si + NIC_IO_BASE]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
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

    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@IOLive
    mov     dx, OFFSET msg_cfg_eeprom_iobase_verified
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_iobase_value]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@IOLive:
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    xor     al, al
    call    Nic_Select_Window
    mov     bx, EL3_W0_ADDRESS_CFG
    call    Nic_Reg_Read_Word
    and     al, 01Fh
    cmp     al, [cfg_txn_io_selector]
    jne     @@IOVerifyFail

    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@INTPersistent
    mov     dx, OFFSET msg_cfg_live_iobase_verified
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_iobase_value]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@INTPersistent:
    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@PNPPersistent
    ; Preserve the standalone 0.3.3 unchanged path.  Verify INT only when its
    ; persistent field changed, or when an IO migration forced live restoration.
    ; An unchanged INT skips its own readback only; later requested properties
    ; are still verified.
    test    [cfg_txn_change_flags], CFG_TXN_INT_MIGRATE_MASK
    jz      @@PNPPersistent

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

    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@INTLive
    mov     dx, OFFSET msg_cfg_eeprom_verified
    mov     ah, 09h
    int     21h
    mov     al, bl
    call    Print_DecByte
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@INTLive:
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    xor     al, al
    call    Nic_Select_Window
    mov     bx, EL3_W0_RESOURCE_CFG
    call    Nic_Reg_Read_Word
    mov     bx, ax
    mov     cl, 12
    shr     bx, cl
    and     bl, 0Fh
    cmp     bl, [cfg_int_value]
    jne     @@INTVerifyFail

    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@PNPPersistent
    mov     dx, OFFSET msg_cfg_live_verified
    mov     ah, 09h
    int     21h
    mov     al, bl
    call    Print_DecByte
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@PNPPersistent:
    test    [cfg_parse_flags], CFG_PARSE_PNP
    jz      @@MODEMPersistent
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD13
    jz      @@MODEMPersistent
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_CONFIG_CONTROL
    call    Cfg_Eeprom_Read
    jc      @@PNPVerifyFail
    cmp     ax, [cfg_txn_new_word13]
    jne     @@PNPVerifyFail
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@MODEMPersistent
    mov     dx, OFFSET msg_cfg_pnp_verified
    mov     ah, 09h
    int     21h

@@MODEMPersistent:
    test    [cfg_parse_flags], CFG_PARSE_MODEM
    jz      @@FDPersistent
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD0D
    jz      @@FDPersistent
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_SOFTWARE_INFO
    call    Cfg_Eeprom_Read
    jc      @@MODEMVerifyFail
    cmp     ax, [cfg_txn_new_word0d]
    jne     @@MODEMVerifyFail
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@FDPersistent
    mov     dx, OFFSET msg_cfg_modem_verified
    mov     ah, 09h
    int     21h

@@FDPersistent:
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jz      @@OptimizePersistent
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD0D
    jz      @@OptimizePersistent
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_SOFTWARE_INFO
    call    Cfg_Eeprom_Read
    jc      @@FDVerifyFail
    ; Verify the undocumented persistent Full Duplex policy bit only.
    and     ax, 8000h
    mov     bx, [cfg_txn_new_word0d]
    and     bx, 8000h
    cmp     ax, bx
    jne     @@FDVerifyFail
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@OptimizePersistent
    mov     dx, OFFSET msg_cfg_fd_verified
    mov     ah, 09h
    int     21h

@@OptimizePersistent:
    test    [cfg_parse_flags], CFG_PARSE_OPTIMIZE
    jz      @@BootRomPersistent
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD0D
    jz      @@BootRomPersistent
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_SOFTWARE_INFO
    call    Cfg_Eeprom_Read
    jc      @@OptimizeVerifyFail
    cmp     ax, [cfg_txn_new_word0d]
    jne     @@OptimizeVerifyFail
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@BootRomPersistent
    mov     dx, OFFSET msg_cfg_optimize_verified
    mov     ah, 09h
    int     21h

@@BootRomPersistent:
    test    [cfg_parse_flags], CFG_PARSE_BADDRESS
    jnz     @@BootRomNeedsRead
    test    [cfg_parse_flags], CFG_PARSE_BSIZE
    jz      @@Success
@@BootRomNeedsRead:
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD08
    jz      @@Success
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_ADDR_CFG
    call    Cfg_Eeprom_Read
    jc      @@BootRomVerifyFail
    mov     bx, ax                  ; BX = word08 as read back

    test    [cfg_parse_flags], CFG_PARSE_BADDRESS
    jz      @@BSizeVerify
    cmp     [cfg_bsize_disabled], 1
    je      @@BSizeVerify        ; BADDRESS is ignored/cleared by BSIZE:DISABLED.
    mov     ax, bx
    and     ax, 0F00h
    mov     cl, 8
    shr     ax, cl
    cmp     al, [cfg_baddress_value]
    jne     @@BootRomVerifyFail
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@BSizeVerify
    mov     dx, OFFSET msg_cfg_baddress_verified
    mov     ah, 09h
    int     21h

@@BSizeVerify:
    test    [cfg_parse_flags], CFG_PARSE_BSIZE
    jz      @@Success
    mov     ax, bx
    and     ax, 3000h
    mov     cl, 12
    shr     ax, cl
    cmp     al, [cfg_bsize_value]
    jne     @@BootRomVerifyFail
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@Success
    mov     dx, OFFSET msg_cfg_bsize_verified
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

@@BootRomVerifyFail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    test    [cfg_parse_flags], CFG_PARSE_BADDRESS
    jz      @@BootRomVerifyFailBSize
    cmp     [cfg_bsize_disabled], 1
    je      @@BootRomVerifyFailBSize
    mov     [cfg_last_error], CFG_ERR_BADDRESS_VERIFY
    jmp     @@Fail
@@BootRomVerifyFailBSize:
    mov     [cfg_last_error], CFG_ERR_BSIZE_VERIFY
    jmp     @@Fail
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
    jmp     @@Fail
@@PNPVerifyFail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_PNP_VERIFY
    jmp     @@Fail
@@MODEMVerifyFail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_MODEM_VERIFY
    jmp     @@Fail
@@FDVerifyFail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_FD_VERIFY
    jmp     @@Fail
@@OptimizeVerifyFail:
    cmp     [cfg_last_error], CFG_ERR_EEPROM_TIMEOUT
    je      @@Fail
    mov     [cfg_last_error], CFG_ERR_OPTIMIZE_VERIFY
@@Fail:
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    stc
    ret
ENDP Cfg_Txn_Verify

; Enforce the requested persistent Full Duplex policy in the live Network
; Diagnostic register only after Cfg_Txn_Verify has confirmed the EEPROM
; transaction.  This also repairs a stale live state when the policy was
; already correct and therefore needed no EEPROM write.
PROC Cfg_Txn_Sync_Live_FullDuplex NEAR
    push    ax
    push    bx
    push    dx
    push    si
    push    di

    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jz      @@Success

    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Nic_Get_Current_Window
    mov     di, ax
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, 4
    call    Nic_Select_Window
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     bx, EL3_W4_NETWORK_DIAGNOSTIC
    call    Nic_Reg_Read_Word
    cmp     ax, 0FFFFh
    je      @@UpdateFail

    test    ax, W4_NET_DIAG_FD_ENABLE
    jz      @@LiveDisabled
    test    [cfg_txn_new_word0d], EEPROM_SOFTWARE_INFO_FULLDUPLEX
    jnz     @@Verified
    and     ax, NOT W4_NET_DIAG_FD_ENABLE
    jmp     @@Write
@@LiveDisabled:
    test    [cfg_txn_new_word0d], EEPROM_SOFTWARE_INFO_FULLDUPLEX
    jz      @@Verified
    or      ax, W4_NET_DIAG_FD_ENABLE
@@Write:
    mov     bx, EL3_W4_NETWORK_DIAGNOSTIC
    call    Nic_Reg_Write_Word
    mov     bx, EL3_W4_NETWORK_DIAGNOSTIC
    call    Nic_Reg_Read_Word
    cmp     ax, 0FFFFh
    je      @@VerifyFail
    test    ax, W4_NET_DIAG_FD_ENABLE
    jz      @@VerifyDisabled
    test    [cfg_txn_new_word0d], EEPROM_SOFTWARE_INFO_FULLDUPLEX
    jz      @@VerifyFail
    jmp     @@Verified
@@VerifyDisabled:
    test    [cfg_txn_new_word0d], EEPROM_SOFTWARE_INFO_FULLDUPLEX
    jnz     @@VerifyFail
@@Verified:
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@RestoreSuccess
    mov     dx, OFFSET msg_cfg_fd_live_verified
    mov     ah, 09h
    int     21h
    jmp     @@RestoreSuccess

@@UpdateFail:
    mov     [cfg_last_error], CFG_ERR_FD_LIVE_UPDATE
    jmp     @@RestoreFail
@@VerifyFail:
    mov     [cfg_last_error], CFG_ERR_FD_LIVE_VERIFY
@@RestoreFail:
    mov     ax, di
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Nic_Select_Window
    stc
    jmp     @@Done
@@RestoreSuccess:
    mov     ax, di
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Nic_Select_Window
@@Success:
    clc
@@Done:
    pop     di
    pop     si
    pop     dx
    pop     bx
    pop     ax
    ret
ENDP Cfg_Txn_Sync_Live_FullDuplex

; Verbose snapshot and prospective image reporting.  Normal mode remains concise.
PROC Cfg_Txn_Report_Current NEAR
    push    ax
    push    cx
    push    dx

    test    [cli_flags], CLI_FLAG_VERBOSE
    jnz     @@Start
    jmp     @@Done
@@Start:
    mov     dx, OFFSET msg_cfg_txn_current_active_base
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_old_base]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
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
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_cfg_current_word08
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_old_word08]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_cfg_current_live_iobase
    mov     ah, 09h
    int     21h
    mov     al, [cfg_txn_live_io_selector]
    call    Cfg_IOBASE_Selector_To_Base
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@Live06:
    mov     dx, OFFSET msg_cfg_current_live06
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_old_live06]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@Live08
    mov     dx, OFFSET msg_cfg_current_irq
    mov     ah, 09h
    int     21h
    mov     al, [cfg_txn_old_irq]
    call    Print_DecByte
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_cfg_txn_current_live_irq
    mov     ah, 09h
    int     21h
    mov     al, [cfg_txn_live_irq]
    call    Print_DecByte
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_cfg_current_word09
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_old_word09]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@Live08:
    mov     dx, OFFSET msg_cfg_current_live08
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_old_live08]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h
    test    [cfg_parse_flags], CFG_PARSE_MODEM
    jz      @@Optimize
    mov     dx, OFFSET msg_cfg_current_word0d
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_old_word0d]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h
@@Optimize:
    test    [cfg_parse_flags], CFG_PARSE_OPTIMIZE
    jz      @@Done
    mov     dx, OFFSET msg_cfg_current_word0d
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_old_word0d]
    mov     cl, 4
    shr     ax, cl
    and     al, 03h
    call    Decode_Optimize_Value
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h
@@Done:
    pop     dx
    pop     cx
    pop     ax
    ret
ENDP Cfg_Txn_Report_Current

PROC Cfg_Txn_Report_Prospective NEAR
    push    ax
    push    cx
    push    dx

    test    [cli_flags], CLI_FLAG_VERBOSE
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
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jz      @@Live06
    mov     dx, OFFSET msg_cfg_new_word08
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_new_word08]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@Live06:
    mov     dx, OFFSET msg_cfg_new_live06
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_new_live06]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@Live08
    mov     dx, OFFSET msg_cfg_new_word09
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_new_word09]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@Live08:
    mov     dx, OFFSET msg_cfg_new_live08
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_new_live08]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h
    test    [cfg_parse_flags], CFG_PARSE_MODEM
    jz      @@Optimize
    mov     dx, OFFSET msg_cfg_new_word0d
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_new_word0d]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h
@@Optimize:
    test    [cfg_parse_flags], CFG_PARSE_OPTIMIZE
    jz      @@Done
    mov     dx, OFFSET msg_cfg_new_word0d
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_new_word0d]
    mov     cl, 4
    shr     ax, cl
    and     al, 03h
    call    Decode_Optimize_Value
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h
@@Done:
    pop     dx
    pop     cx
    pop     ax
    ret
ENDP Cfg_Txn_Report_Prospective

; Print final success message once after centralized verification.
PROC Cfg_Txn_Report_Success NEAR
    push    dx

    test    [cfg_parse_flags], CFG_PARSE_OPTIMIZE
    jnz     @@Generic
    test    [cfg_parse_flags], CFG_PARSE_BADDRESS
    jnz     @@Generic
    test    [cfg_parse_flags], CFG_PARSE_BSIZE
    jnz     @@Generic
    test    [cfg_parse_flags], CFG_PARSE_TR
    jnz     @@Generic
    test    [cfg_parse_flags], CFG_PARSE_PNP
    jz      @@NoPNP
    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jnz     @@Generic
    test    [cfg_parse_flags], CFG_PARSE_INT
    jnz     @@Generic
    test    [cfg_parse_flags], CFG_PARSE_MODEM
    jnz     @@Generic
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jnz     @@Generic
    mov     dx, OFFSET msg_cfg_pnp_completed
    jmp     @@Print
@@Generic:
    mov     dx, OFFSET msg_cfg_txn_completed
    jmp     @@Print
@@NoPNP:
    test    [cfg_parse_flags], CFG_PARSE_MODEM
    jz      @@NoMODEM
    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jnz     @@Generic
    test    [cfg_parse_flags], CFG_PARSE_INT
    jnz     @@Generic
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jnz     @@Generic
    mov     dx, OFFSET msg_cfg_modem_completed
    jmp     @@Print
@@NoMODEM:
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jz      @@NoFD
    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jnz     @@Generic
    test    [cfg_parse_flags], CFG_PARSE_INT
    jnz     @@Generic
    mov     dx, OFFSET msg_cfg_fd_completed
    jmp     @@Print
@@NoFD:
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
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@GatePNP
    mov     dx, OFFSET msg_cfg_adapter_prefix
    mov     ah, 09h
    int     21h
    mov     al, [cfg_adapter_ordinal]
    call    Print_DecByte
    mov     dx, OFFSET msg_cfg_adapter_suffix
    mov     ah, 09h
    int     21h

; ----------------------------------------------------------------------------
; Capability gate phase.  All hardware/product capability checks for gated
; CONFIGURE verbs (/PNP, /FULLDUPLEX, /BADDRESS, /BSIZE, /TR) run here, before any
; "parameter accepted" echo.  An adapter that cannot support a requested verb
; is rejected immediately, without ever being told its input was accepted.
; Moved out of the Prepare phase in 0.5.6; the Prepare phase below now only
; stages values, since every gate has already passed by the time it runs.
; ----------------------------------------------------------------------------
@@GatePNP:
    test    [cfg_parse_flags], CFG_PARSE_PNP
    jz      @@GateFULLDUPLEX
    ; EEPROM_CAPABILITY bit 0 is the authoritative PNP capability source.
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Nic_Read_Capabilities
    test    bx, NIC_CAP_VALID_PNP
    jz      @@PNPCapReadFail
    test    ax, NIC_CAP_PNP
    jz      @@PNPNotCapable
    jmp     @@GateFULLDUPLEX
@@PNPCapReadFail:
    mov     [cfg_last_error], CFG_ERR_PNP_EEPROM_READ
    jmp     @@Done
@@PNPNotCapable:
    mov     [cfg_last_error], CFG_ERR_PNP_NOT_CAPABLE
    jmp     @@Done

@@GateFULLDUPLEX:
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jz      @@GateBootRom
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Nic_Read_Capabilities
    test    bx, NIC_CAP_VALID_FULLDUPLEX
    jz      @@FDCapReadFail
    test    ax, NIC_CAP_FULLDUPLEX
    jz      @@FDNotCapable
    jmp     @@GateBootRom
@@FDCapReadFail:
    mov     [cfg_last_error], CFG_ERR_FD_CAPABILITY_READ
    jmp     @@Done
@@FDNotCapable:
    mov     [cfg_last_error], CFG_ERR_FD_NOT_CAPABLE
    jmp     @@Done

@@GateBootRom:
    test    [cfg_parse_flags], CFG_PARSE_BADDRESS
    jnz     @@BootRomRequested
    test    [cfg_parse_flags], CFG_PARSE_BSIZE
    jz      @@Requested

@@BootRomRequested:
    ; Pairing rule: /BSIZE:DISABLED may be given alone (any /BADDRESS given
    ; alongside is then ignored) to disable the Boot ROM.  Otherwise
    ; /BADDRESS and /BSIZE:8|16|32 must both be specified.
    test    [cfg_parse_flags], CFG_PARSE_BSIZE
    jz      @@BootRomIncomplete
    cmp     [cfg_bsize_disabled], 1
    je      @@BootRomCapabilityGate
    test    [cfg_parse_flags], CFG_PARSE_BADDRESS
    jz      @@BootRomIncomplete
    jmp     @@BootRomCapabilityGate
@@BootRomIncomplete:
    mov     [cfg_last_error], CFG_ERR_BOOTROM_INCOMPLETE
    jmp     @@Done

@@BootRomCapabilityGate:
    ; Guard: 3C509B-TPO adapters do not support Boot ROM configuration when
    ; the card is also "later" (PnP-capable per EEPROM word 14h).  Mirrors
    ; the same gate already used by Print_Boot_Rom_Value/Extended_Is_Later_Card
    ; for LIST display.
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_REVISION_INFO
    call    Cfg_Eeprom_Read
    jc      @@BootRomCapReadFail
    and     ax, 00FFh
    cmp     ax, 1
    jb      @@Requested
    mov     si, [cfg_selected_ptr]
    mov     ax, [WORD si + NIC_PRODUCT_ID]
    cmp     ax, PRODUCT_3C509_TPO
    jne     @@Requested
    mov     [cfg_last_error], CFG_ERR_BADDRESS_NOT_CAPABLE
    jmp     @@Done
@@BootRomCapReadFail:
    mov     [cfg_last_error], CFG_ERR_BADDRESS_EEPROM_READ
    jmp     @@Done

@@Requested:
@@GateTR:
    test    [cfg_parse_flags], CFG_PARSE_TR
    jz      @@GateTR_Pass
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Nic_Read_Capabilities
    test    bx, NIC_CAP_VALID_CONNECTORS
    jz      @@TRCapabilityReadFail
    cmp     [cfg_tr_value], 0
    jne     @@GateTR_Aui
    test    ax, NIC_CAP_TP
    jnz     @@GateTR_Pass
    jmp     @@TRNotCapable
@@GateTR_Aui:
    cmp     [cfg_tr_value], 1
    jne     @@GateTR_Coax
    test    ax, NIC_CAP_AUI
    jnz     @@GateTR_Pass
    jmp     @@TRNotCapable
@@GateTR_Coax:
    cmp     [cfg_tr_value], 3
    jne     @@GateTR_Auto
    test    ax, NIC_CAP_BNC
    jnz     @@GateTR_Pass
    jmp     @@TRNotCapable
@@GateTR_Auto:
    and     ax, NIC_CAP_TP + NIC_CAP_AUI + NIC_CAP_BNC
    mov     bx, ax
    dec     ax
    and     ax, bx
    jnz     @@GateTR_Pass
@@TRNotCapable:
    mov     [cfg_last_error], CFG_ERR_TR_NOT_CAPABLE
    jmp     @@Done
@@TRCapabilityReadFail:
    mov     [cfg_last_error], CFG_ERR_TR_CAPABILITY_READ
    jmp     @@Done

@@GateTR_Pass:
@@RequestedIOBASE:
    ; Preserve normal requested parameter output from the existing releases.
    test    [cfg_parse_flags], CFG_PARSE_IOBASE
    jz      @@RequestedINT
    mov     dx, OFFSET msg_cfg_iobase_ok
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_iobase_value]
    call    Print_HexWord
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h
@@RequestedINT:
    test    [cfg_parse_flags], CFG_PARSE_INT
    jz      @@RequestedPNP
    mov     dx, OFFSET msg_cfg_int_ok
    mov     ah, 09h
    int     21h
    mov     al, [cfg_int_value]
    call    Print_DecByte
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@RequestedPNP:
    test    [cfg_parse_flags], CFG_PARSE_PNP
    jz      @@RequestedMODEM
    mov     dx, OFFSET msg_cfg_pnp_ok
    mov     ah, 09h
    int     21h
    cmp     [cfg_pnp_value], 0
    je      @@PnpDisabled
    mov     dx, OFFSET msg_enabled
    jmp     @@PnpPrint
@@PnpDisabled:
    mov     dx, OFFSET msg_disabled
@@PnpPrint:
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@RequestedMODEM:
    test    [cfg_parse_flags], CFG_PARSE_MODEM
    jz      @@RequestedFULLDUPLEX
    mov     dx, OFFSET msg_cfg_modem_ok
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_modem_value]
    call    Decode_Modem_Baud_Alias
    jnc     @@PrintModem
    mov     ax, [cfg_modem_value]
    call    Decode_Modem_Value
    jc      @@PrintModemNone
@@PrintModem:
    call    Print_DecWord
    jmp     @@AfterRequestedModem
@@PrintModemNone:
    mov     dx, OFFSET msg_none
    mov     ah, 09h
    int     21h
    jmp     @@AfterRequestedModem
@@AfterRequestedModem:
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@RequestedFULLDUPLEX:
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jz      @@RequestedBAddress
    mov     dx, OFFSET msg_cfg_fullduplex_ok
    mov     ah, 09h
    int     21h
    cmp     [cfg_fullduplex_value], 0
    je      @@FDDisabled
    mov     dx, OFFSET msg_enabled
    jmp     @@FDPrint
@@FDDisabled:
    mov     dx, OFFSET msg_disabled
@@FDPrint:
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@RequestedBAddress:
    test    [cfg_parse_flags], CFG_PARSE_BADDRESS
    jz      @@RequestedBSize
    mov     dx, OFFSET msg_cfg_baddress_ok
    mov     ah, 09h
    int     21h
    xor     ax, ax
    mov     al, [cfg_baddress_value]
    mov     cx, 2000h
    mul     cx
    add     dx, 000Ch
    call    Print_HexAddress20
    mov     dx, OFFSET msg_hex_suffix
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@RequestedBSize:
    test    [cfg_parse_flags], CFG_PARSE_BSIZE
    jz      @@RequestedTR
    mov     dx, OFFSET msg_cfg_bsize_ok
    mov     ah, 09h
    int     21h
    cmp     [cfg_bsize_disabled], 1
    je      @@PrintBSizeDisabled
    mov     al, [cfg_bsize_value]
    xor     ah, ah
    cmp     al, 0
    jne     @@Check16K
    mov     ax, 8
    jmp     @@PrintBSizeValue
@@Check16K:
    cmp     al, 1
    jne     @@Is32K
    mov     ax, 16
    jmp     @@PrintBSizeValue
@@Is32K:
    mov     ax, 32
@@PrintBSizeValue:
    call    Print_DecWord
    mov     dx, OFFSET msg_kilobytes_suffix
    mov     ah, 09h
    int     21h
    jmp     @@AfterBSizeValue
@@PrintBSizeDisabled:
    mov     dx, OFFSET msg_disabled
    mov     ah, 09h
    int     21h
@@AfterBSizeValue:
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@RequestedTR:
    test    [cfg_parse_flags], CFG_PARSE_TR
    jz      @@Read
    mov     dx, OFFSET msg_cfg_tr_ok
    mov     ah, 09h
    int     21h
    cmp     [cfg_tr_value], 0FFh
    jne     @@TRNotAuto
    mov     dx, OFFSET msg_tr_auto
    jmp     @@PrintTR
@@TRNotAuto:
    cmp     [cfg_tr_value], 0
    jne     @@TRNotTP
    mov     dx, OFFSET msg_tr_tp
    jmp     @@PrintTR
@@TRNotTP:
    cmp     [cfg_tr_value], 1
    jne     @@TRIsCoax
    mov     dx, OFFSET msg_tr_aui
    jmp     @@PrintTR
@@TRIsCoax:
    mov     dx, OFFSET msg_tr_coax
@@PrintTR:
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

@@Read:
    test    [cli_flags], CLI_FLAG_VERBOSE
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
    jz      @@PreparePNP
    call    Cfg_Prepare_INT
@@PreparePNP:
    ; Capability gate already passed in the gate phase above; stage only.
    test    [cfg_parse_flags], CFG_PARSE_PNP
    jz      @@PrepareMODEM
    call    Cfg_Prepare_PNP
@@PrepareMODEM:
    test    [cfg_parse_flags], CFG_PARSE_MODEM
    jz      @@PrepareFULLDUPLEX
    call    Cfg_Prepare_MODEM
@@PrepareFULLDUPLEX:
    ; Capability gate already passed in the gate phase above; stage only.
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jz      @@PrepareOPTIMIZE
    call    Cfg_Prepare_FULLDUPLEX
@@PrepareOPTIMIZE:
    test    [cfg_parse_flags], CFG_PARSE_OPTIMIZE
    jz      @@PrepareBootRom
    call    Cfg_Prepare_OPTIMIZE
@@PrepareBootRom:
    ; Pairing rule and capability gate already passed in the gate phase
    ; above; stage only.
    test    [cfg_parse_flags], CFG_PARSE_BADDRESS
    jz      @@PrepareBSizeOnly
    call    Cfg_Prepare_BADDRESS
@@PrepareBSizeOnly:
    test    [cfg_parse_flags], CFG_PARSE_BSIZE
    jz      @@PrepareTR
    call    Cfg_Prepare_BSIZE
@@PrepareTR:
    ; Capability gate already passed in the gate phase above; stage only.
    test    [cfg_parse_flags], CFG_PARSE_TR
    jz      @@Detect
    call    Cfg_Prepare_TR
@@Detect:
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jz      @@DetectChanges
    call    Cfg_Validate_FD_Transceiver
    jc      @@Done
@@DetectChanges:
    call    Cfg_Txn_Detect_Changes
    call    Cfg_Txn_Report_Prospective

    test    [cli_flags], CLI_FLAG_VERBOSE
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
    jz      @@CheckPNPUnchanged
    test    [cfg_txn_change_flags], CFG_TXN_INT_CHANGED
    jnz     @@CheckPNPUnchanged
    mov     dx, OFFSET msg_cfg_irq_unchanged
    mov     ah, 09h
    int     21h
@@CheckPNPUnchanged:
    test    [cfg_parse_flags], CFG_PARSE_PNP
    jz      @@CheckMODEMUnchanged
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD13
    jnz     @@CheckMODEMUnchanged
    mov     dx, OFFSET msg_cfg_pnp_unchanged
    mov     ah, 09h
    int     21h
@@CheckMODEMUnchanged:
    test    [cfg_parse_flags], CFG_PARSE_MODEM
    jz      @@CheckOPTIMIZEUnchanged
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD0D
    jnz     @@CheckOPTIMIZEUnchanged
    mov     dx, OFFSET msg_cfg_modem_unchanged
    mov     ah, 09h
    int     21h
@@CheckOPTIMIZEUnchanged:
    test    [cfg_parse_flags], CFG_PARSE_OPTIMIZE
    jz      @@CheckFDUnchanged
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD0D
    jnz     @@CheckFDUnchanged
    mov     dx, OFFSET msg_cfg_optimize_unchanged
    mov     ah, 09h
    int     21h
@@CheckFDUnchanged:
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jz      @@CheckBAddressUnchanged
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD0D
    jnz     @@CheckBAddressUnchanged
    mov     dx, OFFSET msg_cfg_fd_unchanged
    mov     ah, 09h
    int     21h

@@CheckBAddressUnchanged:
    test    [cfg_parse_flags], CFG_PARSE_BADDRESS
    jz      @@CheckBSizeUnchanged
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD08
    jnz     @@CheckBSizeUnchanged
    mov     dx, OFFSET msg_cfg_baddress_unchanged
    mov     ah, 09h
    int     21h

@@CheckBSizeUnchanged:
    test    [cfg_parse_flags], CFG_PARSE_BSIZE
    jz      @@CheckTRUnchanged
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD08
    jnz     @@CheckTRUnchanged
    mov     dx, OFFSET msg_cfg_bsize_unchanged
    mov     ah, 09h
    int     21h

@@CheckTRUnchanged:
    test    [cfg_parse_flags], CFG_PARSE_TR
    jz      @@CheckAnyChange
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD08
    jnz     @@CheckAnyChange
    mov     dx, OFFSET msg_cfg_tr_unchanged
    mov     ah, 09h
    int     21h

@@CheckAnyChange:
    ; No requested hardware change.  INT intentionally follows release 0.3.3
    ; persistent authoritative unchanged behavior.
    mov     ax, [cfg_txn_change_flags]
    and     ax, CFG_TXN_COMMIT_MASK
    jnz     @@Preflight
    test    [cfg_parse_flags], CFG_PARSE_FULLDUPLEX
    jnz     @@SyncUnchangedFD
    test    [cli_flags], CLI_FLAG_VERBOSE
    jz      @@Success
    mov     dx, OFFSET msg_cfg_txn_no_changes
    mov     ah, 09h
    int     21h
    jmp     @@Success
@@SyncUnchangedFD:
    call    Cfg_Txn_Sync_Live_FullDuplex
    jc      @@Done
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
    call    Cfg_Txn_Sync_Live_FullDuplex
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

    call    Nic_Check_3Com_Signature
    jc      @@Mismatch
    cmp     ax, [WORD si + NIC_PRODUCT_ID]
    jne     @@Mismatch
    cmp     [BYTE si + NIC_ASIC_REV], 0FFh
    je      @@Mac
    cmp     bl, [BYTE si + NIC_ASIC_REV]
    jne     @@Mismatch

@@Mac:
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Nic_Get_Current_Window
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
    call    Nic_Select_Window
    jmp     @@Good

@@RestoreReadError:
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, ch
    call    Nic_Select_Window
    jmp     @@Fail
@@RestoreMismatch:
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, ch
    call    Nic_Select_Window
    jmp     @@Mismatch

@@ByTag:
    test    [BYTE si + NIC_FLAGS], NIC_FLAG_FROM_ID
    jz      @@Mismatch
    mov     al, [BYTE si + NIC_TAG]
    or      al, al
    jz      @@Mismatch
    cmp     al, 7
    ja      @@Mismatch

    pushf
    cli
    cmp     [BYTE si + NIC_ID_MODE], 0
    je      @@FullSequence
    call    Nic_IdPort_Send_Short_Sequence
    jmp     @@SelectTag
@@FullSequence:
    call    Nic_IdPort_Send_Full_Sequence
@@SelectTag:
    mov     dx, ID_PORT
    mov     al, ID_CMD_SELECT_TAG
    or      al, [BYTE si + NIC_TAG]
    call    Nic_IdPort_Write_Command

    mov     al, EEPROM_MFG_ID
    call    Nic_IdPort_Read_Word
    cmp     ax, 06D50h
    jne     @@TagMismatch
    mov     al, EEPROM_PRODUCT_ID
    call    Nic_IdPort_Read_Word
    cmp     ax, [WORD si + NIC_PRODUCT_ID]
    jne     @@TagMismatch
    call    Is_3C509_Family
    jc      @@TagUnsupported

    mov     al, EEPROM_OEM_NODE_0
    call    Nic_IdPort_Read_Word
    cmp     ah, [BYTE si + NIC_MAC_ADDR]
    jne     @@TagMismatch
    cmp     al, [BYTE si + NIC_MAC_ADDR + 1]
    jne     @@TagMismatch
    mov     al, EEPROM_OEM_NODE_1
    call    Nic_IdPort_Read_Word
    cmp     ah, [BYTE si + NIC_MAC_ADDR + 2]
    jne     @@TagMismatch
    cmp     al, [BYTE si + NIC_MAC_ADDR + 3]
    jne     @@TagMismatch
    mov     al, EEPROM_OEM_NODE_2
    call    Nic_IdPort_Read_Word
    cmp     ah, [BYTE si + NIC_MAC_ADDR + 4]
    jne     @@TagMismatch
    cmp     al, [BYTE si + NIC_MAC_ADDR + 5]
    jne     @@TagMismatch
    popf
    jmp     @@Good

@@TagUnsupported:
    popf
    mov     [cfg_last_error], CFG_ERR_UNSUPPORTED_PRODUCT
    jmp     @@Fail
@@TagMismatch:
    popf
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

    pushf
    cli
    cmp     [BYTE si + NIC_ID_MODE], 0
    je      @@Full
    call    Nic_IdPort_Send_Short_Sequence
    jmp     @@Selected
@@Full:
    call    Nic_IdPort_Send_Full_Sequence
@@Selected:
    mov     dx, ID_PORT
    mov     al, ID_CMD_SELECT_TAG
    or      al, [BYTE si + NIC_TAG]
    call    Nic_IdPort_Write_Command
    mov     al, 0C0h
    call    Nic_IdPort_Write_Command
    popf

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

    pushf
    cli
    cmp     [BYTE si + NIC_ID_MODE], 0
    je      @@Full
    call    Nic_IdPort_Send_Short_Sequence
    jmp     @@Select
@@Full:
    call    Nic_IdPort_Send_Full_Sequence
@@Select:
    mov     dx, ID_PORT
    mov     al, ID_CMD_SELECT_TAG
    or      al, [BYTE si + NIC_TAG]
    call    Nic_IdPort_Write_Command

    mov     ax, [WORD si + NIC_IO_BASE]
    sub     ax, 0200h
    mov     bx, 0010h
    xor     dx, dx
    div     bx
    or      al, ID_CMD_ACTIVATE
    mov     dx, ID_PORT
    call    Nic_IdPort_Write_Command
    popf

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
; The current executable accepts only the 9050h family; EISA, MCA and 3C508
; resources have been removed, since none of them have a reachable selection
; branch (see CHANGES for details).
PROC Select_Nic_Description NEAR
    mov     dx, OFFSET msg_a02c
    ret
ENDP Select_Nic_Description

; Read all additional LIST values from the activated adapter.
; Input SI = NIC record.
; The existing enumeration record is not modified.
PROC Read_Extended_Nic_Info NEAR
    push    ax
    push    bx
    push    cx
    push    dx

    mov     [ext_addr_cfg], 0FFFFh
    mov     [ext_compatibility], 0FFFFh
    mov     [ext_capability], 0FFFFh
    mov     [ext_config_ctrl], 0FFFFh
    mov     [ext_revision_info], 0FFFFh
    mov     [ext_optimize], 0FFFFh
    mov     [ext_link_status], 0FFFFh
    mov     [ext_software_info], 0FFFFh
    mov     [ext_nic_capabilities], 0FFFFh
    mov     [ext_nic_capability_valid], 0

    mov     dx, [WORD si + NIC_IO_BASE]
    or      dx, dx
    jz      @@Done
    test    [BYTE si + NIC_FLAGS], NIC_FLAG_ACTIVE
    jz      @@Done

    call    Nic_Read_Capabilities
    mov     [ext_nic_capabilities], ax
    mov     [ext_nic_capability_valid], bx

    mov     al, EEPROM_ADDR_CFG
    call    Nic_EEPROM_Read
    jc      @@SkipAddrCfg
    mov     [ext_addr_cfg], ax
@@SkipAddrCfg:

    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_COMPATIBILITY
    call    Nic_EEPROM_Read
    jc      @@SkipCompatibility
    mov     [ext_compatibility], ax
@@SkipCompatibility:

    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_SOFTWARE_INFO
    call    Nic_EEPROM_Read
    jc      @@SkipSoftwareInfo
    mov     [ext_software_info], ax
    mov     [ext_optimize], ax
@@SkipSoftwareInfo:

    ; Read the live Media Type and Status register (Window 4/Port 0Ah) to
    ; surface the dynamic "Valid link beat detected" bit (bit 11) in LIST.
    ; This is a live register, not an EEPROM field; the current window is
    ; saved (on the stack) and restored around the switch to window 4.
    mov     dx, [WORD si + NIC_IO_BASE]
    call    Nic_Get_Current_Window
    push    ax
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, 4
    call    Nic_Select_Window
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     bx, EL3_W4_MEDIA_STATUS
    call    Nic_Reg_Read_Word
    mov     cl, 11
    shr     ax, cl
    and     ax, 0001h
    mov     [ext_link_status], ax
    mov     dx, [WORD si + NIC_IO_BASE]
    pop     ax
    call    Nic_Select_Window

    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_CONFIG_CONTROL
    call    Nic_EEPROM_Read
    jc      @@SkipConfigCtrl
    mov     [ext_config_ctrl], ax
@@SkipConfigCtrl:

    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_REVISION_INFO
    call    Nic_EEPROM_Read
    jc      @@Done
    mov     [ext_revision_info], ax

    mov     ax, [ext_revision_info]
    cmp     ax, 0FFFFh
    je      @@Done
    and     ax, 00FFh
    cmp     ax, 1
    jb      @@Done

    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_CAPABILITY
    call    Nic_EEPROM_Read
    jc      @@Done
    mov     [ext_capability], ax

@@Done:
    pop     dx
    pop     cx
    pop     bx
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

    mov     ax, [ext_addr_cfg]
    test    ax, 0080h
    jz      @@ConfiguredMedia
    test    [ext_nic_capability_valid], NIC_CAP_VALID_CONNECTORS
    jz      @@Unavailable
    mov     ax, [ext_nic_capabilities]
    and     ax, NIC_CAP_TP + NIC_CAP_AUI + NIC_CAP_BNC
    mov     cx, ax
    dec     ax
    and     ax, cx
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

    mov     ax, [ext_nic_capabilities]
    cmp     ax, 0FFFFh
    je      @@Unavailable
    test    [ext_nic_capability_valid], NIC_CAP_VALID_PNP
    jz      @@Unavailable
    test    ax, NIC_CAP_PNP
    jz      @@No
    mov     dx, OFFSET msg_yes
    jmp     @@Print
@@No:
    mov     dx, OFFSET msg_no
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

PROC Print_Pnp_State_Value NEAR
    push    ax
    push    dx

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
@@Unavailable:
    mov     dx, OFFSET msg_unavailable
@@Print:
    mov     ah, 09h
    int     21h
    pop     dx
    pop     ax
    ret
ENDP Print_Pnp_State_Value

PROC Print_Connector_Capabilities NEAR
    push    ax
    push    dx

    test    [ext_nic_capability_valid], NIC_CAP_VALID_CONNECTORS
    jz      @@Unavailable
    mov     ax, [ext_nic_capabilities]
    and     ax, NIC_CAP_TP + NIC_CAP_AUI + NIC_CAP_BNC
    jz      @@None
    test    ax, NIC_CAP_TP
    jz      @@Aui
    mov     dx, OFFSET msg_tr_tp
    call    Print_String
@@Aui:
    test    ax, NIC_CAP_AUI
    jz      @@Bnc
    test    ax, NIC_CAP_TP
    jz      @@PrintAui
    mov     dx, OFFSET msg_connector_separator
    call    Print_String
@@PrintAui:
    mov     dx, OFFSET msg_tr_aui
    call    Print_String
@@Bnc:
    test    ax, NIC_CAP_BNC
    jz      @@Done
    mov     dx, OFFSET msg_connector_separator
    test    ax, NIC_CAP_TP + NIC_CAP_AUI
    jnz     @@PrintBncSeparator
    jmp     @@PrintBnc
@@PrintBncSeparator:
    call    Print_String
@@PrintBnc:
    mov     dx, OFFSET msg_tr_coax
    call    Print_String
    jmp     @@Done
@@None:
    mov     dx, OFFSET msg_none
    jmp     @@Print
@@Unavailable:
    mov     dx, OFFSET msg_unavailable
@@Print:
    call    Print_String
@@Done:
    pop     dx
    pop     ax
    ret
ENDP Print_Connector_Capabilities

PROC Print_Full_Duplex_Capability NEAR
    push    ax
    push    dx

    test    [ext_nic_capability_valid], NIC_CAP_VALID_FULLDUPLEX
    jz      @@Unavailable
    mov     ax, [ext_nic_capabilities]
    test    ax, NIC_CAP_FULLDUPLEX
    jz      @@No
    mov     dx, OFFSET msg_yes
    jmp     @@Print
@@No:
    mov     dx, OFFSET msg_no
    jmp     @@Print
@@Unavailable:
    mov     dx, OFFSET msg_unavailable
@@Print:
    call    Print_String
    pop     dx
    pop     ax
    ret
ENDP Print_Full_Duplex_Capability


; Input AL = documented EEPROM_SOFTWARE_INFO Software Optimization value.
PROC Decode_Optimize_Value NEAR
    push    ax
    push    dx

    cmp     al, 0
    je      @@Reserved
    cmp     al, 1
    je      @@Dos
    cmp     al, 2
    je      @@Windows_OS2
    cmp     al, 3
    je      @@Server
    mov     dx, OFFSET msg_unknown_value
    jmp     @@Print
@@Reserved:
    mov     dx, OFFSET msg_optimize_reserved
    jmp     @@Print
@@Dos:
    mov     dx, OFFSET msg_optimize_dos
    jmp     @@Print
@@Windows_OS2:
    mov     dx, OFFSET msg_optimize_windows_or_os2
    jmp     @@Print
@@Server:
    mov     dx, OFFSET msg_optimize_server
@@Print:
    mov     ah, 09h
    int     21h
    pop     dx
    pop     ax
    ret
ENDP Decode_Optimize_Value

PROC Print_Optimize_Value NEAR
    push    ax
    push    cx

    mov     ax, [ext_optimize]
    cmp     ax, 0FFFFh
    je      @@Unavailable
    mov     cl, 4
    shr     ax, cl
    and     al, 03h
    call    Decode_Optimize_Value
    jmp     @@Done
@@Unavailable:
    mov     dx, OFFSET msg_unavailable
    mov     ah, 09h
    int     21h
@@Done:
    pop     cx
    pop     ax
    ret
ENDP Print_Optimize_Value

; EEPROM word 0Dh bits 13:8 store Maximum Interrupt Disable Time: raw 00h-3Fh
; is 25-1600 us in 25 us steps. CLI baud values 1200/2400/9600/19200/38400 take
; precedence over numeric timings, so /MODEM:1200 is 1300 us. Raw 2Fh is valid
; 1200 us data but cannot be represented by the CLI: INFO reports this, while
; SAVECONFIG intentionally normalizes it to /MODEM:NONE.
; Input AX = EEPROM word.  Output AX = timing in microseconds; CF=1 for NONE.
PROC Decode_Modem_Value NEAR
    push    dx
    push    cx

    and     ax, EEPROM_SOFTWARE_INFO_INT_DISABLE_MASK
    cmp     ax, EEPROM_MODEM_NONE
    je      @@None
    mov     cl, 8
    shr     ax, cl
    inc     ax
    mov     cx, 25
    mul     cx
    clc
    jmp     @@Done

@@None:
    mov     ax, 1600
    stc

@@Done:
    pop     cx
    pop     dx
    ret
ENDP Decode_Modem_Value

; Input AX = EEPROM word. Output CF=0 and AX = named baud alias, or CF=1.
PROC Decode_Modem_Baud_Alias NEAR
    and     ax, EEPROM_SOFTWARE_INFO_INT_DISABLE_MASK
    cmp     ax, EEPROM_MODEM_1200
    je      @@1200
    cmp     ax, EEPROM_MODEM_2400
    je      @@2400
    cmp     ax, EEPROM_MODEM_9600
    je      @@9600
    cmp     ax, EEPROM_MODEM_19200
    je      @@19200
    cmp     ax, EEPROM_MODEM_38400
    je      @@38400
    stc
    ret
@@1200:
    mov     ax, 1200
    jmp     @@Done
@@2400:
    mov     ax, 2400
    jmp     @@Done
@@9600:
    mov     ax, 9600
    jmp     @@Done
@@19200:
    mov     ax, 19200
    jmp     @@Done
@@38400:
    mov     ax, 38400
@@Done:
    clc
    ret
ENDP Decode_Modem_Baud_Alias

; Prints the persistent MODEM interrupt-disable time and any CLI baud alias.
PROC Print_Modem_Value NEAR
    push    ax
    push    bx
    push    dx

    mov     bx, [ext_software_info]
    cmp     bx, 0FFFFh
    je      @@Unavailable
    mov     ax, bx
    call    Decode_Modem_Value
    call    Print_DecWord
    mov     dx, OFFSET msg_modem_us
    call    Print_String
    and     bx, EEPROM_SOFTWARE_INFO_INT_DISABLE_MASK
    cmp     bx, EEPROM_MODEM_NONE
    je      @@None
    cmp     bx, 2F00h
    je      @@NotRepresentable
    mov     ax, bx
    call    Decode_Modem_Baud_Alias
    jc      @@Done
    cmp     ax, 1200
    je      @@Baud1200
    cmp     ax, 2400
    je      @@Baud2400
    cmp     ax, 9600
    je      @@Baud9600
    cmp     ax, 19200
    je      @@Baud19200
    ; The helper only returns 38400 for the remaining successful alias.
    mov     dx, OFFSET msg_modem_38400
    jmp     @@PrintAlias
@@Baud1200:
    mov     dx, OFFSET msg_modem_1200
    jmp     @@PrintAlias
@@Baud2400:
    mov     dx, OFFSET msg_modem_2400
    jmp     @@PrintAlias
@@Baud9600:
    mov     dx, OFFSET msg_modem_9600
    jmp     @@PrintAlias
@@Baud19200:
    mov     dx, OFFSET msg_modem_19200
    jmp     @@PrintAlias
@@None:
    mov     dx, OFFSET msg_modem_none
    jmp     @@PrintAlias
@@NotRepresentable:
    mov     dx, OFFSET msg_modem_not_representable
@@PrintAlias:
    call    Print_String
    jmp     @@Done
@@Unavailable:
    mov     dx, OFFSET msg_unavailable
    call    Print_String
@@Done:
    pop     dx
    pop     bx
    pop     ax
    ret
ENDP Print_Modem_Value

; Prints the persistent full duplex setting from EEPROM_SOFTWARE_INFO
; (word 0Dh) bit 15 when shared hardware capability discovery supports it.
PROC Print_Full_Duplex_Value NEAR
    push    ax
    push    dx

    test    [ext_nic_capability_valid], NIC_CAP_VALID_FULLDUPLEX
    je      @@Unavailable
    mov     ax, [ext_nic_capabilities]
    test    ax, NIC_CAP_FULLDUPLEX
    jz      @@NotSupported

    mov     ax, [ext_software_info]
    cmp     ax, 0FFFFh
    je      @@Unavailable
    test    ax, EEPROM_SOFTWARE_INFO_FULLDUPLEX
    jz      @@Disabled

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
ENDP Print_Full_Duplex_Value

; Prints the live link status ("connected"/"not connected") read from the
; Media Type and Status register (Window 4/Port 0Ah bit 11), or
; "unavailable" if the adapter is not active.  See Read_Extended_Nic_Info.
PROC Print_Link_Status_Value NEAR
    push    ax
    push    dx

    mov     ax, [ext_link_status]
    cmp     ax, 0FFFFh
    je      @@Unavailable
    or      ax, ax
    jz      @@NotConnected

    mov     dx, OFFSET msg_link_connected
    jmp     @@Print
@@NotConnected:
    mov     dx, OFFSET msg_link_not_connected
    jmp     @@Print
@@Unavailable:
    mov     dx, OFFSET msg_unavailable
@@Print:
    mov     ah, 09h
    int     21h
    pop     dx
    pop     ax
    ret
ENDP Print_Link_Status_Value

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
    mov     ax, [ext_addr_cfg]
    and     ax, 3000h
    mov     cl, 12
    shr     ax, cl
    or      bx, bx
    jz      @@CheckDisabled
    cmp     ax, 3
    je      @@Invalid
    jmp     @@HaveSize

@@CheckDisabled:
    or      ax, ax
    jz      @@Disabled
    cmp     ax, 3
    je      @@Invalid

@@HaveSize:

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

   mov     dx, OFFSET msg_indent
   call    Print_String
   mov     dx, OFFSET msg_connectors_label
   call    Print_String
   call    Print_Connector_Capabilities
   mov     dx, OFFSET msg_crlf
   call    Print_String

   mov     dx, OFFSET msg_indent
   call    Print_String
   mov     dx, OFFSET msg_fd_capability_label
   call    Print_String
   call    Print_Full_Duplex_Capability
   mov     dx, OFFSET msg_crlf
   call    Print_String

   mov     dx, OFFSET msg_indent
   call    Print_String
   mov     dx, OFFSET msg_pnp_label
   call    Print_String
   call    Print_Pnp_Capability_Value
   mov     dx, OFFSET msg_crlf
   call    Print_String

   mov     dx, OFFSET msg_indent
   call    Print_String
   mov     dx, OFFSET msg_link_status_label
   call    Print_String
   call    Print_Link_Status_Value
    mov     dx, OFFSET msg_crlf
   call    Print_String

   mov     dx, OFFSET msg_separator
   call    Print_String

   mov     dx, OFFSET msg_indent
   call    Print_String
   mov     dx, OFFSET msg_iobase
   call    Print_String
   mov     ax, [WORD si + NIC_IO_BASE]
   or      ax, ax
   jz      @@PrintNoIo
   call    Print_HexWord
   jmp     @@PrintIrq
@@PrintNoIo:
   mov     dx, OFFSET msg_no_io
   call    Print_String
@@PrintIrq:
   mov     dx, OFFSET msg_irq
   call    Print_String
   xor     ax, ax
   mov     al, [BYTE si + NIC_IRQ_VAL]
   call    Print_DecByte
   mov     dx, OFFSET msg_crlf
   call    Print_String

   mov     dx, OFFSET msg_indent
   call    Print_String
   mov     dx, OFFSET msg_xcvr_label
   call    Print_String
   call    Print_Transceiver_Value
   mov     dx, OFFSET msg_crlf
   call    Print_String

   mov     dx, OFFSET msg_indent
   call    Print_String
   mov     dx, OFFSET msg_pnp_state_label
   call    Print_String
   call    Print_Pnp_State_Value
   mov     dx, OFFSET msg_crlf
   call    Print_String

   mov     dx, OFFSET msg_indent
   call    Print_String
   mov     dx, OFFSET msg_boot_label
   call    Print_String
   call    Print_Boot_Rom_Value
   mov     dx, OFFSET msg_crlf
   call    Print_String

   mov     dx, OFFSET msg_indent
   call    Print_String
   mov     dx, OFFSET msg_optimize_label
   call    Print_String
   call    Print_Optimize_Value
   mov     dx, OFFSET msg_crlf
   call    Print_String

   mov     dx, OFFSET msg_indent
   call    Print_String
   mov     dx, OFFSET msg_modem_label
   call    Print_String
   call    Print_Modem_Value
   mov     dx, OFFSET msg_crlf
   call    Print_String

   mov     dx, OFFSET msg_indent
   call    Print_String
   mov     dx, OFFSET msg_fullduplex_label
   call    Print_String
   call    Print_Full_Duplex_Value
   mov     dx, OFFSET msg_crlf
   call    Print_String

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

; Input DX = '$'-terminated string.
PROC Print_String NEAR
    push    ax
    mov     ah, 09h
    int     21h
    pop     ax
    ret
ENDP Print_String

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

PROC Print_DecWord NEAR
    push    ax
    push    bx
    push    cx
    push    dx

    cmp     ax, 0
    jne     @@Convert
    mov     dl, '0'
    mov     ah, 02h
    int     21h
    jmp     @@Done

@@Convert:
    xor     cx, cx
@@DivLoop:
    xor     dx, dx
    mov     bx, 10
    div     bx
    push    dx
    inc     cx
    or      ax, ax
    jnz     @@DivLoop

@@PrintLoop:
    pop     dx
    add     dl, '0'
    mov     ah, 02h
    int     21h
    loop    @@PrintLoop

@@Done:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Print_DecWord

END Start
