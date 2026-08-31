; ============================================================================
; 3CCFGCLI.ASM
; 3Com EtherLink III 3C509 and 3C509B ISA LIST and CONFIGURE framework
; Target: MS DOS, Turbo Assembler, 8086 and 8088 only
; ============================================================================
; - Supported CONFIGURE verbs in this build:
;    /ADAPTERNUM, /BADDRESS, /BSIZE, /FULLDUPLEX, /INT, /IOBASE, /MODEM,
;    /OPTIMIZE, /PNP, /TR (/XCVR alias), /VERBOSE.
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

CFG_PARSE_ADAPTER       EQU 01h
CFG_PARSE_INT           EQU 02h
CFG_PARSE_VERBOSE       EQU 04h
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
CFG_SEEN_VERBOSE        EQU 08h
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
CFG_TXN_CHG_WORD0F       EQU 0200h
; Widened to also require the hardware transaction pipeline for /BADDRESS,
; /BSIZE, and /TR (bits 0100h/0200h/0400h), which share EEPROM word 08h
; with /IOBASE.
CFG_PARSE_HW_MASK        EQU 07FAh
CFG_TXN_IO_DETECT_MASK   EQU 15h
CFG_TXN_WORD09_INT_MASK  EQU 42h
CFG_TXN_EEPROM_MASK      EQU 0383h
CFG_TXN_LIVE06_MASK      EQU 14h
; WORD08 (bit 0) is included directly so a /BADDRESS or /BSIZE change (which
; has no IOBASE_CHANGED-style composite signal of its own) still triggers
; the write/verify/success pipeline.  This mirrors how WORD0D/WORD13/WORD0F
; are already included directly for MODEM/FULLDUPLEX/PNP/OPTIMIZE.
CFG_TXN_COMMIT_MASK      EQU 03F1h
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
                DB  "  SAVECONFIG file [/EXECFILE:program]", 0Dh, 0Ah
                DB  "    Export all adapter configurations to a restore batch file.", 0Dh, 0Ah
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
                DB  "    /VERBOSE                       Show verbose transaction details.", 0Dh, 0Ah, '$'

msg_no_cards    DB  "No EtherLink III NICs are installed in this computer.", 0Dh, 0Ah, '$'
msg_save_missing DB "SAVECONFIG requires an output filename.", 0Dh, 0Ah, '$'
msg_save_bad_name DB "Invalid SAVECONFIG output filename.", 0Dh, 0Ah, '$'
msg_save_bad_option DB "Invalid SAVECONFIG option.", 0Dh, 0Ah, '$'
msg_save_bad_execfile DB "Invalid SAVECONFIG /EXECFILE value.", 0Dh, 0Ah, '$'
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
msg_cfg_bad_int DB "Invalid /INT parameter. Value must be 3, 5, 7, 9, 10, 11, 12, or 15.", 0Dh, 0Ah, '$'
msg_cfg_bad_pnp DB "Invalid /PNP parameter. Use ENABLED or DISABLED.", 0Dh, 0Ah, '$'
msg_cfg_bad_modem DB "Invalid /MODEM parameter. Use NONE, 1200, 2400, 9600, 19200, 38400, or 25-1600 in 25 increments.", 0Dh, 0Ah, '$'
msg_cfg_bad_optimize DB "Invalid /OPTIMIZE parameter. Use DOS, WINDOWS, OS/2, or SERVER.", 0Dh, 0Ah, '$'
msg_cfg_int_ok DB "INT parameter accepted. Requested IRQ: ", '$'
msg_cfg_pnp_ok DB "PNP parameter accepted. Requested Plug and Play mode: ", '$'
msg_cfg_modem_ok DB "MODEM parameter accepted. Requested setting: ", '$'
msg_cfg_crlf DB 0Dh, 0Ah, '$'
msg_cfg_adapter_prefix DB "Adapter ", '$'
msg_cfg_adapter_suffix DB " selected.", 0Dh, 0Ah, '$'
msg_cfg_current_irq DB "Current IRQ: ", '$'
msg_cfg_current_word09 DB "Current EEPROM word 09h: ", '$'
msg_cfg_current_word0d DB "Current EEPROM word 0Dh: ", '$'
msg_cfg_current_word0f DB "Current EEPROM word 0Fh: ", '$'
msg_cfg_new_word09 DB "New EEPROM word 09h: ", '$'
msg_cfg_new_word0d DB "New EEPROM word 0Dh: ", '$'
msg_cfg_new_word0f DB "New EEPROM word 0Fh: ", '$'
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
msg_cfg_write_iobase DB 0Dh, 0Ah, "Writing I/O configuration to EEPROM...", 0Dh, 0Ah, '$'
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
msg_cfg_fd_verify_fail DB "Full duplex configuration verification failed.", 0Dh, 0Ah, '$'
msg_cfg_fd_completed DB 0Dh, 0Ah, "Full duplex configuration completed successfully.", 0Dh, 0Ah, '$'
msg_cfg_fd_not_capable DB "This adapter does not support full duplex configuration.", 0Dh, 0Ah, '$'

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
msg_boot_label  DB  "Boot ROM = ", '$'
msg_compat_label DB "Software Compatibility = failure level ", '$'
msg_optimize_label DB "Optimization = ", '$'
msg_modem_label DB "Modem Speed = ", '$'
msg_fullduplex_label DB "Full Duplex = ", '$'
msg_link_status_label DB "Link Status = ", '$'
msg_optimize_reserved DB "Reserved", '$'
msg_optimize_dos DB "DOS", '$'
msg_optimize_windows DB "Windows", '$'
msg_optimize_os2 DB "OS/2", '$'
msg_optimize_windows_or_os2 DB "Windows or OS/2", '$'
msg_optimize_server DB "Server", '$'
msg_warn_label  DB  ", warning level ", '$'

msg_enabled     DB  "enabled", '$'
msg_disabled    DB  "disabled", '$'
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
ext_revision_info DW 0FFFFh
ext_optimize      DW 0FFFFh
; Live link status (Window 4/Port 0Ah bit 11); 0 = not connected,
; 1 = connected, 0FFFFh = unavailable (adapter not active).
ext_link_status   DW 0FFFFh
; Raw EEPROM_SOFTWARE_INFO (word 0Dh); bits 13:0 are the MODEM field, masked
; with EEPROM_SOFTWARE_INFO_MODEM_MASK by Print_Modem_Value before display.
ext_software_info DW 0FFFFh
; Full duplex capability verdict; 0 = not supported, 1 = supported,
; 0FFh = unavailable (adapter not active or EEPROM read timed out).
ext_fd_capable    DB 0FFh

; CONFIGURE state.  nic_table itself is deliberately not extended.
cfg_adapter_ordinal   DB 0
cfg_parse_flags       DW 0
cfg_seen_flags        DW 0
cfg_property_count    DB 0
cfg_last_error        DB CFG_ERR_NONE
cfg_timeout_latched   DB 0
cfg_selected_ptr      DW 0
cfg_options_ptr       DW 0

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
; modified only by Cfg_Prepare_INT, Cfg_Prepare_IOBASE and Cfg_Prepare_PNP.
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
save_execname   DB  64 DUP(0)
save_execname_default DB '3CCFGCLI.EXE', 0
save_execfile_kw DB 'EXECFILE:', 0
save_buffer     DB  1024 DUP(0)
save_length     DW  0
save_handle     DW  0
save_adapter_num DW 0
save_word08     DW  0
save_word09     DW  0
save_word0d     DW  0
save_word13     DW  0
save_configure_suffix DB ' CONFIGURE', 0
save_adapternum DB  ' /ADAPTERNUM:', 0
save_int        DB  ' /INT:', 0
save_iobase     DB  ' /IOBASE:', 0
save_pnp        DB  ' /PNP:', 0
save_fd         DB  ' /FULLDUPLEX:', 0
save_modem      DB  ' /MODEM:', 0
save_optimize   DB  ' /OPTIMIZE:', 0
save_baddress   DB  ' /BADDRESS:', 0
save_bsize      DB  ' /BSIZE:', 0
save_tr         DB  ' /TR:', 0
save_none       DB  'NONE', 0
save_enabled    DB  'ENABLED', 0
save_disabled   DB  'DISABLED', 0
save_dos        DB  'DOS', 0
save_windows    DB  'WINDOWS', 0
save_os2        DB  'OS/2', 0
save_server     DB  'SERVER', 0
save_tp         DB  'TP', 0
save_aui        DB  'AUI', 0
save_coax       DB  'COAX', 0
save_auto       DB  'AUTO', 0

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
    jne     @@TrySaveConfig
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

@@TrySaveConfig:
    cmp     [BYTE si], 'S'
    jne     @@TryConfig
    cmp     [BYTE si+1], 'A'
    jne     @@TryConfig
    cmp     [BYTE si+2], 'V'
    jne     @@TryConfig
    cmp     [BYTE si+3], 'E'
    jne     @@TryConfig
    cmp     [BYTE si+4], 'C'
    jne     @@TryConfig
    cmp     [BYTE si+5], 'O'
    jne     @@TryConfig
    cmp     [BYTE si+6], 'N'
    jne     @@TryConfig
    cmp     [BYTE si+7], 'F'
    jne     @@TryConfig
    cmp     [BYTE si+8], 'I'
    jne     @@TryConfig
    cmp     [BYTE si+9], 'G'
    jne     @@TryConfig
    mov     al, [si+10]
    cmp     al, ' '
    je      @@SaveConfig
    cmp     al, 09h
    jne     @@TryConfig
@@SaveConfig:
    add     si, 10
    call    Cmd_SaveConfig
    ret

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

@@SkipWhite:
    mov     al, [si]
    cmp     al, ' '
    je      @@Advance
    cmp     al, 09h
    jne     @@Name
@@Advance:
    inc     si
    jmp     @@SkipWhite
@@Name:
    or      al, al
    jz      @@Missing
    mov     di, OFFSET save_filename
    mov     cx, 127
@@Copy:
    mov     al, [si]
    or      al, al
    jz      @@Copied
    cmp     al, ' '
    je      @@Copied
    cmp     al, 09h
    je      @@Copied
    mov     [BYTE di], al
    inc     di
    inc     si
    loop    @@Copy
    jmp     @@BadName
@@Copied:
    xor     al, al
    mov     [BYTE di], al

    ; Default program name embedded in each restore line is this build,
    ; unless /EXECFILE overrides it.
    push    si
    mov     di, OFFSET save_execname
    mov     si, OFFSET save_execname_default
@@CopyDefaultExec:
    lodsb
    mov     [BYTE di], al
    inc     di
    or      al, al
    jnz     @@CopyDefaultExec
    pop     si

@@SkipWhite2:
    mov     al, [si]
    cmp     al, ' '
    je      @@Advance2
    cmp     al, 09h
    jne     @@CheckOption
@@Advance2:
    inc     si
    jmp     @@SkipWhite2

@@CheckOption:
    or      al, al
    jz      @@ScanCards
    cmp     al, '/'
    je      @@ExecSlash
    cmp     al, '-'
    jne     @@BadOption
@@ExecSlash:
    inc     si
    mov     di, OFFSET save_execfile_kw
@@MatchExec:
    mov     al, [BYTE di]
    or      al, al
    jz      @@ExecMatched
    cmp     al, [BYTE si]
    jne     @@BadOption
    inc     di
    inc     si
    jmp     @@MatchExec
@@ExecMatched:
    mov     di, OFFSET save_execname
    mov     cx, 63
@@CopyExec:
    mov     al, [si]
    or      al, al
    jz      @@ExecCopied
    cmp     al, ' '
    je      @@ExecCopied
    cmp     al, 09h
    je      @@ExecCopied
    mov     [BYTE di], al
    inc     di
    inc     si
    loop    @@CopyExec
    jmp     @@BadExecFile
@@ExecCopied:
    xor     al, al
    mov     [BYTE di], al

@@ScanCards:
    call    Scan_All_3Com_Cards
    cmp     [card_count], 0
    je      @@NoCards

    mov     [save_length], 0
    mov     [current_card], 0
    mov     si, OFFSET nic_table
@@ExportLoop:
    mov     dx, [WORD si + NIC_IO_BASE]
    or      dx, dx
    jz      @@SkipAdapter

    mov     al, EEPROM_ADDR_CFG
    call    EEPROM_Read
    mov     [save_word08], ax
    mov     al, EEPROM_RESOURCE_CFG
    call    EEPROM_Read
    mov     [save_word09], ax
    mov     al, EEPROM_SOFTWARE_INFO
    call    EEPROM_Read
    mov     [save_word0d], ax
    mov     al, EEPROM_CONFIG_CONTROL
    call    EEPROM_Read
    mov     [save_word13], ax

    mov     ax, [current_card]
    inc     ax
    mov     [save_adapter_num], ax
    call    Save_Build_Command
    jc      @@ReadFail

@@SkipAdapter:
    add     si, NIC_RECORD_SIZE
    inc     [current_card]
    mov     ax, [current_card]
    cmp     ax, [card_count]
    jb      @@ExportLoop

    cmp     [save_length], 0
    je      @@NoActive

    mov     ah, 3Ch
    xor     cx, cx
    mov     dx, OFFSET save_filename
    int     21h
    jc      @@WriteFail
    mov     [save_handle], ax
    mov     bx, ax
    mov     ah, 40h
    mov     cx, [save_length]
    mov     dx, OFFSET save_buffer
    int     21h
    jc      @@CloseFail
    cmp     ax, [save_length]
    jne     @@CloseFail
    mov     bx, [save_handle]
    mov     ah, 3Eh
    int     21h
    mov     dx, OFFSET msg_save_ok
    mov     ah, 09h
    int     21h
    mov     si, OFFSET save_filename
    call    Save_Print_Filename
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h
    jmp     @@Done
@@CloseFail:
    mov     bx, [save_handle]
    mov     ah, 3Eh
    int     21h
@@WriteFail:
    mov     dx, OFFSET msg_save_write_fail
    jmp     @@Print
@@ReadFail:
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
@@BadExecFile:
    mov     dx, OFFSET msg_save_bad_execfile
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

PROC Save_Append_Char NEAR
    push    di
    mov     di, OFFSET save_buffer
    add     di, [save_length]
    stosb
    inc     [save_length]
    pop     di
    ret
ENDP Save_Append_Char

PROC Save_Append_String NEAR
    push    ax
@@Loop:
    lodsb
    or      al, al
    jz      @@Done
    call    Save_Append_Char
    jmp     @@Loop
@@Done:
    pop     ax
    ret
ENDP Save_Append_String

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
    pop     ax
    push    ax
    mov     al, ah
    call    Save_Append_Hex_Nibble
    pop     ax
    push    ax
    mov     al, al
    shr     al, 1
    shr     al, 1
    shr     al, 1
    shr     al, 1
    call    Save_Append_Hex_Nibble
    pop     ax
    call    Save_Append_Hex_Nibble
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
    loop    @@Output
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
ENDP Save_Append_Dec_Word

PROC Save_Build_Command NEAR
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    mov     si, OFFSET save_execname
    call    Save_Append_String
    mov     si, OFFSET save_configure_suffix
    call    Save_Append_String
    mov     si, OFFSET save_adapternum
    call    Save_Append_String
    mov     ax, [save_adapter_num]
    call    Save_Append_Dec_Word
    mov     si, OFFSET save_int
    call    Save_Append_String
    mov     ax, [save_word09]
    mov     cl, 12
    shr     ax, cl
    call    Save_Append_Dec_Word
    mov     si, OFFSET save_iobase
    call    Save_Append_String
    mov     ax, [save_word08]
    and     ax, 001Fh
    mov     cl, 4
    shl     ax, cl
    add     ax, 0200h
    call    Save_Append_Hex_Word
    mov     si, OFFSET save_pnp
    call    Save_Append_String
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
    mov     si, OFFSET save_fd
    call    Save_Append_String
    mov     ax, [save_word0d]
    test    ax, EEPROM_SOFTWARE_INFO_FULLDUPLEX
    jz      @@FdOff
    mov     si, OFFSET save_enabled
    jmp     @@FdDone
@@FdOff:
    mov     si, OFFSET save_disabled
@@FdDone:
    call    Save_Append_String
    mov     si, OFFSET save_modem
    call    Save_Append_String
    mov     ax, [save_word0d]
    and     ax, EEPROM_SOFTWARE_INFO_MODEM_MASK
    call    Decode_Modem_Value
    jc      @@ModemNone
    cmp     ax, 0FFFFh
    je      @@ModemNone         ; Unrecognised encoding: fall back to NONE,
                                 ; a value our own parser is guaranteed to accept.
    call    Save_Append_Dec_Word
    jmp     @@Optimize
@@ModemNone:
    mov     si, OFFSET save_none
    call    Save_Append_String
@@Optimize:
    mov     si, OFFSET save_optimize
    call    Save_Append_String
    mov     ax, [save_word0d]
    mov     cl, 4
    shr     ax, cl
    and     ax, 0003h
    cmp     al, 1
    je      @@OptDos
    cmp     al, 2
    je      @@OptOs2
    cmp     al, 3
    je      @@OptServer
    ; 00b is reserved; use a parser-valid, conservative restore fallback.
    mov     si, OFFSET save_dos
    jmp     @@OptDone
@@OptDos:
    mov     si, OFFSET save_dos
    jmp     @@OptDone
@@OptOs2:
    ; Value 10b is Windows client, but the original UI combines it with OS/2.
    ; Retain the established OS/2 restore keyword rather than add an alias.
    mov     si, OFFSET save_os2
    jmp     @@OptDone
@@OptServer:
    mov     si, OFFSET save_server
@@OptDone:
    call    Save_Append_String
    mov     ax, [save_word08]
    and     ax, 3F00h              ; Base (bits 11:8) and size (bits 13:12).
    jz      @@NoRom
    mov     si, OFFSET save_baddress
    call    Save_Append_String
    mov     ax, [save_word08]
    and     ax, 0F00h
    mov     cl, 8
    shr     ax, cl
    mov     cl, 13
    shl     ax, cl
    mov     dl, 0Ch
    mov     al, dl
    call    Save_Append_Hex_Nibble
    mov     ax, [save_word08]
    and     ax, 0F00h
    mov     cl, 5
    shl     ax, cl
    call    Save_Append_Hex_Word
    mov     si, OFFSET save_bsize
    call    Save_Append_String
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
    jmp     @@Tr
@@NoRom:
    ; The original utility does not accept /BADDRESS:NONE; disabling the
    ; Boot ROM is expressed with /BSIZE:DISABLED alone.
    mov     si, OFFSET save_bsize
    call    Save_Append_String
    mov     si, OFFSET save_disabled
    call    Save_Append_String
@@Tr:
    mov     si, OFFSET save_tr
    call    Save_Append_String
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
    mov     al, 0Dh
    call    Save_Append_Char
    mov     al, 0Ah
    call    Save_Append_Char
    clc
    jmp     @@Done
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
    mov     ax, CFG_SEEN_VERBOSE
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
; performs hardware access directly.  Remaining property handlers are stubs.
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

    ; NONE disables the setting; the original utility encodes this as
    ; EEPROM_MODEM_NONE, not zero (see 3C509DEF.INC).
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
    ; AX = step count (1-64); raw = ((count-1) << 8) | 20h.
    dec     ax
    mov     cl, 8
    shl     ax, cl
    or      ax, 0020h
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
    jne     @@E31
    mov     dx, OFFSET msg_cfg_iobase_activate_fail
    jmp     @@Print
@@E31:
    cmp     al, CFG_ERR_BAD_PNP
    jne     @@E32
    mov     dx, OFFSET msg_cfg_bad_pnp
    jmp     @@Print
@@E32:
    cmp     al, CFG_ERR_PNP_INACTIVE
    jne     @@E33
    mov     dx, OFFSET msg_cfg_pnp_inactive
    jmp     @@Print
@@E33:
    cmp     al, CFG_ERR_PNP_EEPROM_READ
    jne     @@E34
    mov     dx, OFFSET msg_cfg_pnp_eeprom_read_fail
    jmp     @@Print
@@E34:
    cmp     al, CFG_ERR_PNP_EEPROM_WRITE
    jne     @@E35
    mov     dx, OFFSET msg_cfg_pnp_eeprom_write_fail
    jmp     @@Print
@@E35:
    cmp     al, CFG_ERR_PNP_VERIFY
    jne     @@E36
    mov     dx, OFFSET msg_cfg_pnp_verify_fail
    jmp     @@Print
@@E36:
    cmp     al, CFG_ERR_BAD_MODEM
    jne     @@E37
    mov     dx, OFFSET msg_cfg_bad_modem
    jmp     @@Print
@@E37:
    cmp     al, CFG_ERR_MODEM_INACTIVE
    jne     @@E38
    mov     dx, OFFSET msg_cfg_modem_inactive
    jmp     @@Print
@@E38:
    cmp     al, CFG_ERR_MODEM_EEPROM_READ
    jne     @@E39
    mov     dx, OFFSET msg_cfg_modem_eeprom_read_fail
    jmp     @@Print
@@E39:
    cmp     al, CFG_ERR_MODEM_EEPROM_WRITE
    jne     @@E40
    mov     dx, OFFSET msg_cfg_modem_eeprom_write_fail
    jmp     @@Print
@@E40:
    cmp     al, CFG_ERR_MODEM_VERIFY
    jne     @@E41
    mov     dx, OFFSET msg_cfg_modem_verify_fail
    jmp     @@Print
@@E41:
    cmp     al, CFG_ERR_BAD_OPTIMIZE
    jne     @@E42
    mov     dx, OFFSET msg_cfg_bad_optimize
    jmp     @@Print
@@E42:
    cmp     al, CFG_ERR_OPTIMIZE_INACTIVE
    jne     @@E43
    mov     dx, OFFSET msg_cfg_optimize_inactive
    jmp     @@Print
@@E43:
    cmp     al, CFG_ERR_OPTIMIZE_EEPROM_READ
    jne     @@E44
    mov     dx, OFFSET msg_cfg_optimize_eeprom_read_fail
    jmp     @@Print
@@E44:
    cmp     al, CFG_ERR_OPTIMIZE_EEPROM_WRITE
    jne     @@E45
    mov     dx, OFFSET msg_cfg_optimize_eeprom_write_fail
    jmp     @@Print
@@E45:
    cmp     al, CFG_ERR_OPTIMIZE_VERIFY
    jne     @@E46
    mov     dx, OFFSET msg_cfg_optimize_verify_fail
    jmp     @@Print
@@E46:
    cmp     al, CFG_ERR_PNP_NOT_CAPABLE
    jne     @@E47
    mov     dx, OFFSET msg_cfg_pnp_not_capable
    jmp     @@Print
@@E47:
    cmp     al, CFG_ERR_BAD_FULLDUPLEX
    jne     @@E48
    mov     dx, OFFSET msg_cfg_bad_fullduplex
    jmp     @@Print
@@E48:
    cmp     al, CFG_ERR_FD_INACTIVE
    jne     @@E49
    mov     dx, OFFSET msg_cfg_fd_inactive
    jmp     @@Print
@@E49:
    cmp     al, CFG_ERR_FD_EEPROM_READ
    jne     @@E50
    mov     dx, OFFSET msg_cfg_fd_eeprom_read_fail
    jmp     @@Print
@@E50:
    cmp     al, CFG_ERR_FD_EEPROM_WRITE
    jne     @@E51
    mov     dx, OFFSET msg_cfg_fd_eeprom_write_fail
    jmp     @@Print
@@E51:
    cmp     al, CFG_ERR_FD_VERIFY
    jne     @@E52
    mov     dx, OFFSET msg_cfg_fd_verify_fail
    jmp     @@Print
@@E52:
    cmp     al, CFG_ERR_FD_NOT_CAPABLE
    jne     @@E53
    mov     dx, OFFSET msg_cfg_fd_not_capable
    jmp     @@Print
@@E53:
    cmp     al, CFG_ERR_BAD_BADDRESS
    jne     @@E54
    mov     dx, OFFSET msg_cfg_bad_baddress
    jmp     @@Print
@@E54:
    cmp     al, CFG_ERR_BADDRESS_INACTIVE
    jne     @@E55
    mov     dx, OFFSET msg_cfg_baddress_inactive
    jmp     @@Print
@@E55:
    cmp     al, CFG_ERR_BADDRESS_EEPROM_READ
    jne     @@E56
    mov     dx, OFFSET msg_cfg_baddress_eeprom_read_fail
    jmp     @@Print
@@E56:
    cmp     al, CFG_ERR_BADDRESS_EEPROM_WRITE
    jne     @@E57
    mov     dx, OFFSET msg_cfg_baddress_eeprom_write_fail
    jmp     @@Print
@@E57:
    cmp     al, CFG_ERR_BADDRESS_VERIFY
    jne     @@E58
    mov     dx, OFFSET msg_cfg_baddress_verify_fail
    jmp     @@Print
@@E58:
    cmp     al, CFG_ERR_BADDRESS_NOT_CAPABLE
    jne     @@E59
    mov     dx, OFFSET msg_cfg_baddress_not_capable
    jmp     @@Print
@@E59:
    cmp     al, CFG_ERR_BAD_BSIZE
    jne     @@E60
    mov     dx, OFFSET msg_cfg_bad_bsize
    jmp     @@Print
@@E60:
    cmp     al, CFG_ERR_BSIZE_INACTIVE
    jne     @@E61
    mov     dx, OFFSET msg_cfg_bsize_inactive
    jmp     @@Print
@@E61:
    cmp     al, CFG_ERR_BSIZE_EEPROM_READ
    jne     @@E62
    mov     dx, OFFSET msg_cfg_bsize_eeprom_read_fail
    jmp     @@Print
@@E62:
    cmp     al, CFG_ERR_BSIZE_EEPROM_WRITE
    jne     @@E63
    mov     dx, OFFSET msg_cfg_bsize_eeprom_write_fail
    jmp     @@Print
@@E63:
    cmp     al, CFG_ERR_BSIZE_VERIFY
    jne     @@E64
    mov     dx, OFFSET msg_cfg_bsize_verify_fail
    jmp     @@Print
@@E64:
    cmp     al, CFG_ERR_BSIZE_NOT_CAPABLE
    jne     @@E65
    mov     dx, OFFSET msg_cfg_bsize_not_capable
    jmp     @@Print
@@E65:
    cmp     al, CFG_ERR_BOOTROM_INCOMPLETE
    jne     @@E66
    mov     dx, OFFSET msg_cfg_bootrom_incomplete
    jmp     @@Print
@@E66:
    cmp     al, CFG_ERR_BAD_TR
    jne     @@E67
    mov     dx, OFFSET msg_cfg_bad_tr
    jmp     @@Print
@@E67:
    cmp     al, CFG_ERR_TR_INACTIVE
    jne     @@E68
    mov     dx, OFFSET msg_cfg_tr_inactive
    jmp     @@Print
@@E68:
    cmp     al, CFG_ERR_TR_EEPROM_READ
    jne     @@E69
    mov     dx, OFFSET msg_cfg_tr_eeprom_read_fail
    jmp     @@Print
@@E69:
    cmp     al, CFG_ERR_TR_EEPROM_WRITE
    jne     @@E70
    mov     dx, OFFSET msg_cfg_tr_eeprom_write_fail
    jmp     @@Print
@@E70:
    cmp     al, CFG_ERR_TR_VERIFY
    jne     @@E71
    mov     dx, OFFSET msg_cfg_tr_verify_fail
    jmp     @@Print
@@E71:
    cmp     al, CFG_ERR_TR_NOT_CAPABLE
    jne     @@Done
    mov     dx, OFFSET msg_cfg_tr_not_capable
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
    mov     dx, OFFSET msg_iobase
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
    call    Nic_IdPort_Send_Full_Sequence
    ret
ENDP IdPort_Send_Full_Sequence

; Send the first 8 bytes of the same LFSR stream.
; This matches original sub_329.
PROC IdPort_Send_Short_Sequence NEAR
    call    Nic_IdPort_Send_Short_Sequence
    ret
ENDP IdPort_Send_Short_Sequence

; Conservative delay after an ID port EEPROM read command.
; The hardware minimum is about 162 microseconds.  The original utility uses
; a calibrated delay routine.  This reduced build uses repeated ISA I O reads
; so it remains valid on an 8086 and is intentionally longer than the minimum.
PROC IdPort_Eeprom_Delay NEAR
    call    Nic_IdPort_Eeprom_Delay
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
    call    Nic_IdPort_Read_Word
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
    call    Nic_Init_Id_Port
    ret
ENDP IdPort_Initialize

; Read the fields needed to construct one record while the current contender
; still owns the ID port.
PROC Read_Id_Contender_Data NEAR
    push    ax

    mov     al, EEPROM_NODE_0
    call    IdPort_Read_Word

    mov     al, EEPROM_NODE_1
    call    IdPort_Read_Word

    mov     al, EEPROM_NODE_2
    call    IdPort_Read_Word

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
    ; ISA ID-port discovery for 3C509/3C509B.
    ; Classic 3Com contention sequence on ID_PORT (0110h): send the 255-byte
    ; or short LFSR stream, probe the EEPROM manufacturer/product words, then
    ; tag and activate the adapter at its runtime IOBASE.
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
    call    Nic_IdPort_Write_Command
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
    call    Nic_IdPort_Write_Command

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
    call    Nic_Activate_Tagged_Cards
    ret
ENDP Activate_Tagged_Cards

; ============================================================================
; Active register access and signature verification
; ============================================================================

; Input DX = base, AL = window 0 through 7.
PROC Select_Window NEAR
    call    Nic_Select_Window
    ret
ENDP Select_Window

; Input DX = base.  Output AX = current window number.
PROC Get_Current_Window NEAR
    call    Nic_Get_Current_Window
    ret
ENDP Get_Current_Window

; Verify a live 3C509 register image.
; Input DX = candidate base.
; Output CF clear on success, AX = normalized product ID, BL = ASIC revision.
; The normal x86 word order is 6D50h.  A byte swapped 506Dh read is accepted
; defensively and the product ID is normalized in the same way.
PROC Check_3Com_Signature NEAR
    call    Nic_Check_3Com_Signature
    ret
ENDP Check_3Com_Signature

; ============================================================================
; Active EEPROM access
; ============================================================================
; Input DX = base, AL = EEPROM word index.
; Output AX = EEPROM word, FFFFh on timeout.
PROC EEPROM_Read NEAR
    call    Nic_EEPROM_Read
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
    call    Nic_IdPort_Write_Command
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

    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_CHECKSUM
    call    Cfg_Eeprom_Read
    jc      @@ReadOptimizeFail
    mov     [cfg_txn_old_word0f], ax
@@Word0FDone:

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

    mov     ax, [cfg_txn_new_word0d]
    and     ax, 0C0FFh              ; preserve bits 15:14 and 7:0
    or      ax, [cfg_modem_value]   ; modem value is constrained to bits 13:8
    mov     [cfg_txn_new_word0d], ax

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
    call    Nic_Read_Status
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
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
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
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
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
    jz      @@Checksum
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     bx, [cfg_txn_new_word13]
    mov     al, EEPROM_CONFIG_CONTROL
    call    Cfg_Eeprom_Write
    jc      @@Write13Fail
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@Checksum
    mov     dx, OFFSET msg_cfg_pnp_word_written
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

    mov     ax, [cfg_txn_new_word0f]
    and     ax, 0FF00h
    xor     bx, bx
    mov     bl, [cfg_txn_checksum]
    or      ax, bx
    mov     [cfg_txn_new_word0f], ax
    mov     bx, ax
    mov     al, 0Fh
    call    Cfg_Eeprom_Write
    jc      @@ChecksumWriteFail

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
    test    [cfg_parse_flags], CFG_PARSE_OPTIMIZE
    jz      @@ChecksumFail
    test    [cfg_txn_change_flags], CFG_TXN_CHG_WORD0D
    jz      @@ChecksumFail
    mov     [cfg_last_error], CFG_ERR_OPTIMIZE_EEPROM_WRITE
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
    jz      @@PNPPersistent
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
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@Success
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
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
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
    ; Verify only bit 15 since MODEM may have set the same flag already.
    and     ax, 8000h
    mov     bx, [cfg_txn_new_word0d]
    and     bx, 8000h
    cmp     ax, bx
    jne     @@FDVerifyFail
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
    jz      @@Success
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
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
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
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
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
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
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

; Verbose snapshot and prospective image reporting.  Normal mode remains concise.
PROC Cfg_Txn_Report_Current NEAR
    push    ax
    push    cx
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
    test    [cfg_parse_flags], CFG_PARSE_MODEM
    jz      @@Optimize
    mov     dx, OFFSET msg_cfg_current_word0d
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_old_word0d]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
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
    call    Print_Optimize_Read_Code
    mov     dx, OFFSET msg_cfg_crlf
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
    test    [cfg_parse_flags], CFG_PARSE_MODEM
    jz      @@Optimize
    mov     dx, OFFSET msg_cfg_new_word0d
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_txn_new_word0d]
    call    Print_HexWord
    mov     dx, OFFSET msg_cfg_crlf
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
    call    Print_Optimize_Read_Code
    mov     dx, OFFSET msg_cfg_crlf
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
    test    [cfg_parse_flags], CFG_PARSE_VERBOSE
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
; CONFIGURE verbs (/PNP, /FULLDUPLEX, /BADDRESS, /BSIZE) run here, before any
; "parameter accepted" echo.  An adapter that cannot support a requested verb
; is rejected immediately, without ever being told its input was accepted.
; Moved out of the Prepare phase in 0.5.6; the Prepare phase below now only
; stages values, since every gate has already passed by the time it runs.
; ----------------------------------------------------------------------------
@@GatePNP:
    test    [cfg_parse_flags], CFG_PARSE_PNP
    jz      @@GateFULLDUPLEX
    ; Guard: EEPROM word 14h (EEPROM_REVISION_INFO) low byte must be >= 1.
    ; This is how the original utility determines whether the adapter supports
    ; Plug and Play configuration at all.
    mov     si, [cfg_selected_ptr]
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_REVISION_INFO
    call    Cfg_Eeprom_Read
    jc      @@PNPCapReadFail
    and     ax, 00FFh
    cmp     ax, 1
    jb      @@PNPNotCapable
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
    ; Guard 1: product ID must be one of the five known ISA SKUs.
    mov     si, [cfg_selected_ptr]
    mov     ax, [WORD si + NIC_PRODUCT_ID]
    cmp     ax, PRODUCT_3C509_TP
    je      @@FDProductOk
    cmp     ax, PRODUCT_3C509
    je      @@FDProductOk
    cmp     ax, PRODUCT_3C509_COMBO
    je      @@FDProductOk
    cmp     ax, PRODUCT_3C509_TPO
    je      @@FDProductOk
    cmp     ax, PRODUCT_3C509_TPC
    je      @@FDProductOk
    mov     [cfg_last_error], CFG_ERR_FD_NOT_CAPABLE
    jmp     @@Done
@@FDProductOk:
    ; Guard 2: EEPROM_CAPABILITY (word 10h) bit 0 must be set.
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_CAPABILITY
    call    Cfg_Eeprom_Read
    jc      @@FDCapReadFail
    test    ax, 0001h
    jz      @@FDNotCapable
    jmp     @@GateBootRom
@@FDCapReadFail:
    mov     [cfg_last_error], CFG_ERR_FD_EEPROM_READ
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

; Gate: /TR transceiver type must be valid for this specific product.
; TP-only cards (3C509B-TP) reject AUI/COAX/AUTO.
; Coax card (3C509B-TPC) rejects AUI and AUTO.
; TPO (3C509B-TPO) rejects COAX and AUTO (no auto-select path on TPO).
; Combo and C variants accept all four values.
; Any unrecognised product ID is rejected.
@@Requested:
@@GateTR:
    test    [cfg_parse_flags], CFG_PARSE_TR
    jz      @@GateTR_Pass
    mov     si, [cfg_selected_ptr]
    mov     ax, [WORD si + NIC_PRODUCT_ID]
    cmp     ax, PRODUCT_3C509_TP
    je      @@GateTR_TP
    cmp     ax, PRODUCT_3C509_TPC
    je      @@GateTR_TPC
    cmp     ax, PRODUCT_3C509_TPO
    je      @@GateTR_TPO
    cmp     ax, PRODUCT_3C509
    je      @@GateTR_All
    cmp     ax, PRODUCT_3C509_COMBO
    je      @@GateTR_All
    ; Unrecognised product.
    mov     [cfg_last_error], CFG_ERR_TR_NOT_CAPABLE
    jmp     @@Done

@@GateTR_TP:
    ; 3C509B-TP: only TP (0) is valid.
    cmp     [cfg_tr_value], 0
    je      @@GateTR_Pass
    mov     [cfg_last_error], CFG_ERR_TR_NOT_CAPABLE
    jmp     @@Done

@@GateTR_TPC:
    ; 3C509B-TPC: TP (0) and COAX (3) only; no AUI (1) or AUTO (0FFh).
    cmp     [cfg_tr_value], 0
    je      @@GateTR_Pass
    cmp     [cfg_tr_value], 3
    je      @@GateTR_Pass
    mov     [cfg_last_error], CFG_ERR_TR_NOT_CAPABLE
    jmp     @@Done

@@GateTR_TPO:
    ; 3C509B-TPO: TP (0) and AUI (1) only; no COAX (3) or AUTO (0FFh).
    cmp     [cfg_tr_value], 0
    je      @@GateTR_Pass
    cmp     [cfg_tr_value], 1
    je      @@GateTR_Pass
    mov     [cfg_last_error], CFG_ERR_TR_NOT_CAPABLE
    jmp     @@Done

@@GateTR_All:
    ; 3C509B-Combo / 3C509B-C: TP, AUI, COAX, AUTO all valid.
    ; Reject COAX (3) for non-TPC cards that reach this path.
    cmp     [cfg_tr_value], 3
    je      @@GateTR_NoCoax
    jmp     @@GateTR_Pass
@@GateTR_NoCoax:
    mov     [cfg_last_error], CFG_ERR_TR_NOT_CAPABLE
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
    mov     dx, OFFSET msg_cfg_crlf
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
    mov     dx, OFFSET msg_cfg_crlf
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
    mov     dx, OFFSET msg_cfg_crlf
    mov     ah, 09h
    int     21h

@@RequestedMODEM:
    test    [cfg_parse_flags], CFG_PARSE_MODEM
    jz      @@RequestedFULLDUPLEX
    mov     dx, OFFSET msg_cfg_modem_ok
    mov     ah, 09h
    int     21h
    mov     ax, [cfg_modem_value]
    call    Decode_Modem_Value
    jc      @@PrintModemNone
    cmp     ax, 0FFFFh
    je      @@PrintModemUnknown
    call    Print_DecWord
    jmp     @@AfterRequestedModem
@@PrintModemNone:
    mov     dx, OFFSET msg_none
    mov     ah, 09h
    int     21h
    jmp     @@AfterRequestedModem
@@PrintModemUnknown:
    mov     dx, OFFSET msg_unknown_value
    mov     ah, 09h
    int     21h
@@AfterRequestedModem:
    mov     dx, OFFSET msg_cfg_crlf
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
    mov     dx, OFFSET msg_cfg_crlf
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
    mov     dx, OFFSET msg_cfg_crlf
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
    mov     dx, OFFSET msg_cfg_crlf
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
    call    Nic_IdPort_Write_Command

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
    call    Nic_IdPort_Write_Command
    mov     al, 0C0h
    call    Nic_IdPort_Write_Command
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
    call    Nic_IdPort_Write_Command

    mov     ax, [WORD si + NIC_IO_BASE]
    sub     ax, 0200h
    mov     bx, 0010h
    xor     dx, dx
    div     bx
    or      al, ID_CMD_ACTIVATE
    mov     dx, ID_PORT
    call    Nic_IdPort_Write_Command
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
    mov     [ext_fd_capable], 0FFh

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
    mov     al, EEPROM_SOFTWARE_INFO
    call    EEPROM_Read
    mov     [ext_software_info], ax
    mov     [ext_optimize], ax

    ; Full duplex capability, mirroring the CONFIGURE /FULLDUPLEX gate: a
    ; known ISA product ID plus EEPROM_CAPABILITY (word 10h) bit 0.  Read
    ; here unconditionally because that gate does not depend on the later
    ; card revision layout guarding the ext_capability read further below.
    mov     ax, [WORD si + NIC_PRODUCT_ID]
    cmp     ax, PRODUCT_3C509_TP
    je      @@FdProductOk
    cmp     ax, PRODUCT_3C509
    je      @@FdProductOk
    cmp     ax, PRODUCT_3C509_COMBO
    je      @@FdProductOk
    cmp     ax, PRODUCT_3C509_TPO
    je      @@FdProductOk
    cmp     ax, PRODUCT_3C509_TPC
    je      @@FdProductOk
    mov     [ext_fd_capable], 0
    jmp     @@FdCapDone
@@FdProductOk:
    mov     dx, [WORD si + NIC_IO_BASE]
    mov     al, EEPROM_CAPABILITY
    call    EEPROM_Read
    cmp     ax, 0FFFFh
    je      @@FdCapDone
    mov     [ext_fd_capable], 0
    test    ax, 0001h
    jz      @@FdCapDone
    mov     [ext_fd_capable], 1
@@FdCapDone:

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

PROC Print_Optimize_Code NEAR
    push    ax
    push    dx

    cmp     al, 0
    je      @@Dos
    cmp     al, 1
    je      @@Windows
    cmp     al, 2
    je      @@Os2
    cmp     al, 4
    je      @@Server
    mov     dx, OFFSET msg_unknown_value
    jmp     @@Print
@@Dos:
    mov     dx, OFFSET msg_optimize_dos
    jmp     @@Print
@@Windows:
    mov     dx, OFFSET msg_optimize_windows
    jmp     @@Print
@@Os2:
    mov     dx, OFFSET msg_optimize_os2
    jmp     @@Print
@@Server:
    mov     dx, OFFSET msg_optimize_server
@@Print:
    mov     ah, 09h
    int     21h
    pop     dx
    pop     ax
    ret
ENDP Print_Optimize_Code

; Input AL = documented EEPROM_SOFTWARE_INFO Software Optimization value.
PROC Print_Optimize_Read_Code NEAR
    push    ax
    push    dx

    cmp     al, 0
    je      @@Reserved
    cmp     al, 1
    je      @@Dos
    cmp     al, 2
    je      @@Windows
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
@@Windows:
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
ENDP Print_Optimize_Read_Code

PROC Print_Optimize_Value NEAR
    push    ax
    push    cx

    mov     ax, [ext_optimize]
    cmp     ax, 0FFFFh
    je      @@Unavailable
    mov     cl, 4
    shr     ax, cl
    and     al, 03h
    call    Print_Optimize_Read_Code
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

; Decodes a raw EEPROM_SOFTWARE_INFO MODEM field (bits 13:0, already masked
; with EEPROM_SOFTWARE_INFO_MODEM_MASK).  Returns CF=1 for "no custom modem
; tuning" (zero, or the measured EEPROM_MODEM_NONE constant); otherwise CF=0
; and AX = the friendly value to display: a named baud rate, the equivalent
; custom step value (25-1600), or 0FFFFh if the encoding is unrecognised.
PROC Decode_Modem_Value NEAR
    push    dx
    push    cx

    and     ax, EEPROM_SOFTWARE_INFO_INT_DISABLE_MASK
    or      ax, ax
    jz      @@None
    cmp     ax, EEPROM_MODEM_NONE
    je      @@None
    cmp     ax, EEPROM_MODEM_1200
    je      @@Named1200
    cmp     ax, EEPROM_MODEM_2400
    je      @@Named2400
    cmp     ax, EEPROM_MODEM_9600
    je      @@Named9600
    cmp     ax, EEPROM_MODEM_19200
    je      @@Named19200
    cmp     ax, EEPROM_MODEM_38400
    je      @@Named38400

    mov     cl, 8
    shr     ax, cl
    inc     ax
    mov     cx, 25
    mul     cx
    clc
    jmp     @@Done

@@Named1200:
    mov     ax, 1200
    jmp     @@ValueDone
@@Named2400:
    mov     ax, 2400
    jmp     @@ValueDone
@@Named9600:
    mov     ax, 9600
    jmp     @@ValueDone
@@Named19200:
    mov     ax, 19200
    jmp     @@ValueDone
@@Named38400:
    mov     ax, 38400
@@ValueDone:
    clc
    jmp     @@Done

@@Unknown:
    mov     ax, 0FFFFh
    clc
    jmp     @@Done

@@None:
    stc

@@Done:
    pop     cx
    pop     dx
    ret
ENDP Decode_Modem_Value

; Prints the persistent MODEM (Interrupt Disable Time) setting via
; Decode_Modem_Value: "none", a friendly baud/step value, or "unknown" for an
; unrecognised raw encoding.
PROC Print_Modem_Value NEAR
    push    ax

    mov     ax, [ext_software_info]
    cmp     ax, 0FFFFh
    je      @@Unavailable
    and     ax, EEPROM_SOFTWARE_INFO_MODEM_MASK
    call    Decode_Modem_Value
    jc      @@None
    cmp     ax, 0FFFFh
    je      @@UnknownEnc
    call    Print_DecWord
    jmp     @@Done
@@None:
    mov     dx, OFFSET msg_none
    mov     ah, 09h
    int     21h
    jmp     @@Done
@@UnknownEnc:
    mov     dx, OFFSET msg_unknown_value
    mov     ah, 09h
    int     21h
    jmp     @@Done
@@Unavailable:
    mov     dx, OFFSET msg_unavailable
    mov     ah, 09h
    int     21h
@@Done:
    pop     ax
    ret
ENDP Print_Modem_Value

; Prints the persistent full duplex setting from EEPROM_SOFTWARE_INFO
; (word 0Dh) bit 15, gated by the capability verdict computed in
; Read_Extended_Nic_Info.
PROC Print_Full_Duplex_Value NEAR
    push    ax
    push    dx

    mov     al, [ext_fd_capable]
    cmp     al, 0FFh
    je      @@Unavailable
    or      al, al
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

mov     dx, OFFSET msg_indent
mov     ah, 09h
int     21h
mov     dx, OFFSET msg_optimize_label
mov     ah, 09h
int     21h
call    Print_Optimize_Value
mov     dx, OFFSET msg_crlf
mov     ah, 09h
int     21h

    mov     dx, OFFSET msg_indent
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET msg_modem_label
    mov     ah, 09h
    int     21h
    call    Print_Modem_Value
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_indent
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET msg_fullduplex_label
    mov     ah, 09h
    int     21h
    call    Print_Full_Duplex_Value
    mov     dx, OFFSET msg_crlf
    mov     ah, 09h
    int     21h

    mov     dx, OFFSET msg_indent
    mov     ah, 09h
    int     21h
    mov     dx, OFFSET msg_link_status_label
    mov     ah, 09h
    int     21h
    call    Print_Link_Status_Value
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
