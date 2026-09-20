# CONFIGURE Canonical Semantics (Phase 1)

This report documents the current `CONFIGURE` behavior as implemented in the checked-out source tree. It is a source-of-truth analysis only; no production code or tests were changed.

Primary sources used:
- [3CCFGCLI.ASM](./3CCFGCLI.ASM)
- [3C509DEF.INC](./3C509DEF.INC)
- [3CHWIF.ASM](./3CHWIF.ASM)
- [3CMOCKIF.ASM](./3CMOCKIF.ASM)
- [3CSHIF.ASM](./3CSHIF.ASM)
- [Architecture/CAPABILITIES.md](./Architecture/CAPABILITIES.md)

## A. Executive Summary

The current canonical `CONFIGURE` model is not a single global truth table. It is a staged transaction pipeline that separates:

1. parse/acceptance of user syntax,
2. adapter discovery and temporary access,
3. capability discovery with independent validity flags,
4. property-specific validation and cross-property rules,
5. transaction preparation of a prospective persistent/live image,
6. write and verification against EEPROM and live registers,
7. user-facing success or failure reporting.

The decisive semantics are encoded in the transaction path in [3CCFGCLI.ASM](./3CCFGCLI.ASM), especially `Cfg_Parse_Options`, `Cfg_Dispatch_Property`, `Cfg_Txn_Execute`, `Cfg_Read_Capabilities`, `Cfg_Prepare_*`, `Cfg_Validate_FD_Transceiver`, and `Cfg_Txn_Verify`.

The main canonical rules are:

- `NIC_ASIC_REV` is the generation classifier. `FFh` means unknown/unreadable; revision `1` is original 3C509; revision `2+` is 3C509B behavior. Unknown generation is resolved during temporary access validation, not by treating EEPROM word `14h` as the generation source.
- Capability decisions are separated from raw data. A capability bit and its validity bit are distinct. `unknown` and `unsupported` are not the same state.
- `/PNP` is only accepted for adapters that are already known to be 3C509B generation and whose EEPROM capability bit actually reports PnP support. A textual `ENABLED` or `DISABLED` value is syntactically valid, but the property itself is rejected if the adapter cannot support it or the evidence cannot be established.
- `/FULLDUPLEX` is only valid for adapters that are known 3C509B generation and whose `NIC_CAP_FULLDUPLEX` capability is valid and true. It also requires an effective TP transceiver. If a requested transceiver change moves from TP to non-TP, persistent Full Duplex can be implicitly cleared.
- `/TR` is encoded as raw transceiver bits in word 08h (`TP=00`, `AUI=01`, `COAX=11`, `AUTO` is bit 7 plus no XCVR bits). Capability gates consult live connector presence from Window 0 Configuration Control, and `AUTO` requires a known 3C509B generation.
- `/INT` accepts exactly `3, 5, 7, 9, 10, 11, 12, 15` as user input. The discovery-time `Normalize_IRQ` helper is not the same thing as CONFIGURE input validation.
- `/IOBASE` accepts only normal ISA bases in the range `0200h` through `03E0h`, aligned to 16 bytes, and explicitly rejects selector `1Fh`/EISA slot addressing. The selector conversion helpers in [3CSHIF.ASM](./3CSHIF.ASM) represent the persistent selector form, but the user-facing CONFIGURE value is still a normal ISA base.

## B. CONFIGURE Control Flow

The execution order in the current implementation is:

1. `main` resolves the adapter selection after discovery and dispatches the verb.
2. `Cfg_Parse_Options` parses all CLI arguments; it:
   - matches recognized property names,
   - rejects duplicate supported properties,
   - records request slots in `cfg_property_requests`,
   - rejects missing or invalid option syntax.
3. `Cfg_Dispatch_Parsed_Properties` stages per-property value parsing but does not touch the hardware yet.
4. `Cfg_Handle_INT`, `Cfg_Handle_IOBASE`, `Cfg_Handle_PNP`, `Cfg_Handle_FULLDUPLEX`, `Cfg_Handle_TR`, etc. accept or reject the textual value and fill staged state only.
5. `Cfg_Txn_Execute` begins the hardware-backed transaction:
   - `Cfg_Txn_Begin_Access` establishes a unique temporary working I/O base and validates the selected record there.
   - `Cfg_Read_Capabilities` snapshots the capability state needed for gated instructions.
   - gate checks reject `/PNP`, `/FULLDUPLEX`, `/TR`, and Boot ROM requests before any property is echoed as accepted.
   - `Cfg_Txn_Read_Current` reads the current EEPROM/live state into the prospective transaction image.
   - `Cfg_Txn_Init_Prospective` copies the current persistent image to a new prospective image.
   - property-specific `Cfg_Prepare_*` routines merge staged values into the prospective persistent/live image.
   - `Cfg_Validate_FD_Transceiver` checks the Full Duplex/transceiver consistency.
   - `Cfg_Txn_Probe_Boot_ROM` probes Boot ROM state when relevant.
   - `Cfg_Txn_Detect_Changes` decides which persistent and live fields changed.
   - `Cfg_Txn_Preflight` handles activation and migration constraints.
   - `Cfg_Txn_Activate_If_Needed` performs actual activation only for required migration and live restoration.
   - `Cfg_Txn_Write_EEPROM` and `Cfg_Txn_Write_Live` commit the prospective state.
   - `Cfg_Txn_Verify` re-reads the relevant EEPROM and live registers and fails if the write did not produce the expected state.
   - `Cfg_Txn_Sync_Live_FullDuplex`, `Cfg_Txn_Finalize_IOBASE`, and `Cfg_Txn_End_Access` finish the transaction and restore the selected logical base.
   - `Cfg_Txn_Report_Prospective` and `Cfg_Txn_Report_Implicit_FD_Notice` produce the user-visible results.

The analysis in [3CCFGCLI.ASM](./3CCFGCLI.ASM) makes a key distinction: input validation and capability gating are not the same as transaction state update. The property handlers validate syntax, the capability gates validate support, and the transaction layer handles actual EEPROM/live mutation and verification.

## C. Canonical Raw Facts Used by CONFIGURE

The table below distinguishes semantic fact from access mechanism.

| Fact | Where it originates | Persistent/runtime | Preferred source | Fallback | Failure representation |
|---|---|---|---|---|---|
| `NIC_ASIC_REV` | active adapter signature path / temporary base validation | runtime identity | runtime signature (`Nic_Check_3Com_Signature` + `Cfg_Validate_Temporary_Base`) | ID snapshot may carry evidence, but generation is resolved by live validation | `0FFh` means unknown/unreadable |
| product ID | ID EEPROM snapshot or live signature | persistent identity | ID snapshot when available | live read at working base | product ID mismatch or missing hardware is treated as not reachable |
| EEPROM word 08h (Address Configuration) | persistent EEPROM word | persistent | ID snapshot if valid | live `Cfg_Eeprom_Read` at access base | read failure / busy latching / `CFG_ERR_EEPROM_BUSY` |
| EEPROM word 09h (Resource Configuration) | persistent EEPROM word | persistent | ID snapshot if valid | live `Cfg_Eeprom_Read` | read failure |
| EEPROM word 0Dh (Software Information) | persistent EEPROM word | persistent | ID snapshot if valid | live `Cfg_Eeprom_Read` | read failure |
| EEPROM word 10h (Capabilities) | EEPROM capability word | persistent | ID snapshot if valid | live `Cfg_Eeprom_Read` | capability validity bit remains clear on read failure |
| EEPROM word 13h (Configuration Control / Internal Configuration) | persistent secondary config | persistent | ID snapshot if valid | live `Cfg_Eeprom_Read` | read failure / capability gate failure |
| EEPROM word 14h (Revision Info) | persistent EEPROM word | persistent | ID snapshot if valid | live `Cfg_Eeprom_Read` | read failure |
| Window 0 Configuration Control | live register | runtime | live read of `EL3_W0_CONFIG_CONTROL` | none; if register is unavailable the capability is unknown | `FFFFh` / read failure treated as no valid connector evidence |
| current transceiver selection | live Address Configuration bits `15:14` + `AUTO_SELECT` bit 7 | runtime | live register read | persistent word 08h if the request is being evaluated without a live write yet | no special failure beyond capability validity |
| current Full Duplex bit | persistent EEPROM word 0Dh bit 15 | persistent | persistent word 0Dh snapshot | live re-read if needed | verification failure if expected bit did not land |
| current PNP bit | persistent word 13h bits 3:2 | persistent | persistent snapshot | live re-read if needed | verification failure if expected field did not land |
| current IRQ | live resource config bits 15:12 | runtime / persistent image | live register read | persistent EEPROM word 09h when the current live state is not the relevant source | mismatch triggers live update failure |
| current IOBASE | live Address Configuration bits 4:0 / persistent selector | runtime / persistent | live register and logical base selection | selector conversion via [3CSHIF.ASM](./3CSHIF.ASM) | considered invalid when selector 1Fh / EISA-specific form is encountered |

The important distinction is semantic fact vs. access mechanism. A snapshot and a live read are both treated as the same EEPROM word when they describe the same persistent field; they are not considered different canonical semantics.

## D. ASIC Revision and Generation Semantics

`NIC_ASIC_REV` is the project’s generation classifier.

- Revision `1` means original 3C509-class hardware.
- Revision `2+` means 3C509B-class hardware.
- Revision `FFh` means the ASIC revision was not readable or not yet resolved.

The normal CONFIGURE path resolves unknown ASIC revision during temporary access validation. The key routine is `Cfg_Validate_Temporary_Base` in [3CCFGCLI.ASM](./3CCFGCLI.ASM):

- it probes the selected adapter at the temporary working base,
- verifies the 3Com signature,
- reads the MAC address and product ID,
- compares the product/ASIC identity to the selected record,
- if the record had `NIC_ASIC_REV == 0FFh`, it stores the newly decoded revision from `bl` into the selected record.

This is the point where an unknown revision becomes a canonical known revision. This is not a generic hardware rule; it is a CONFIGURE temporary-access validation step.

The criteria appear in the transaction gating code in `Cfg_Txn_Execute`:

- `/PNP` is rejected if `NIC_ASIC_REV < 2` and the adapter is not a known 3C509B-class card.
- `/FULLDUPLEX` is rejected if `NIC_ASIC_REV < 2`.
- Boot ROM and `/TR:AUTO` also require a known revision `2+` before their capability or compatibility checks are allowed.

`Cfg_Read_Capabilities` also respects this rule:

- it reads connector presence from live Window 0 Configuration Control regardless of generation,
- it only interprets EEPROM word 10h (PnP capability) and EEPROM word 14h (revision-based Full Duplex evidence) when the cached ASIC revision is already known and `>= 2`.
- when the ASIC revision is `FFh`, it does not use those bits as authoritative capability evidence.

This means the project’s canonical model treats unknown generation as “not yet proven 3C509B,” not as “3C509B with no capability.”

## E. Canonical Capability Model

`Cfg_Read_Capabilities` establishes the normalized capability contract:

- `NIC_CAP_PNP` = `01h`
- `NIC_CAP_TP` = `02h`
- `NIC_CAP_AUI` = `04h`
- `NIC_CAP_BNC` = `08h`
- `NIC_CAP_FULLDUPLEX` = `10h`
- validity bits are `NIC_CAP_VALID_PNP`, `NIC_CAP_VALID_CONNECTORS`, `NIC_CAP_VALID_FULLDUPLEX`

The canonical interpretation is:

- `NIC_CAP_VALID_*` set + capability bit set => known and supported
- `NIC_CAP_VALID_*` set + capability bit clear => known and unsupported
- `NIC_CAP_VALID_*` clear => unknown because the required evidence could not be established

The important rules are:

1. Connector capabilities come from live Window 0 Configuration Control. The code tests `W0_CONFIG_CONTROL_TP_PRESENT`, `W0_CONFIG_CONTROL_AUI_PRESENT`, and `W0_CONFIG_CONTROL_BNC_PRESENT`; it normalizes them to `NIC_CAP_TP`, `NIC_CAP_AUI`, and `NIC_CAP_BNC`.
2. PnP capability is from EEPROM word 10h bit 0 (`EEPROM_CAPABILITY_PNP` = `0001h`). It is only interpreted when the adapter is already known as 3C509B generation (`NIC_ASIC_REV >= 2`).
3. Full Duplex capability is established only when:
   - connector evidence says TP is present,
   - the capability validity bit for connectors is set,
   - the adapter is known 3C509B generation,
   - EEPROM word 14h low byte (`EEPROM_REVISION_INFO`) is at least `EEPROM_REVISION_3C509B` (value `0001h`),
   - and the adapter is not the original 3C509 product family variant that legitimately excludes the bit.

The file [Architecture/CAPABILITIES.md](./Architecture/CAPABILITIES.md) reinforces this distinction and explicitly warns not to collapse capability validity into capability support.

## F. PNP Canonical Rule

`/PNP` uses the common `ENABLED`/`DISABLED` parser in `Cfg_Parse_EnableDisable`.

Accepted textual values:
- `/PNP:ENABLED`
- `/PNP:DISABLED`

Canonical staging:
- `Cfg_Handle_PNP` stores `cfg_pnp_value` as `1` for enabled and `0` for disabled.
- `Cfg_Prepare_PNP` writes the field into EEPROM word 13h.
- Disabled encoding is `word13 bits 3:2 = 01b`, which is the 0004h mask set in `Cfg_Prepare_PNP`.
- Enabled encoding is a clear `00b` in bits 3:2 (the field is reset to zero to retain classic ISA contention and PnP simultaneously).

The property is rejected even when the text is valid if it fails the capability or generation checks:

- `Cfg_Txn_Execute` checks `NIC_ASIC_REV` and requires `>= 2` for the property to even be eligible.
- if the adapter is not a known 3C509B card, it rejects with the unsupported-card error.
- if the adapter is 3C509B but `NIC_CAP_VALID_PNP` is not set or `NIC_CAP_PNP` is absent, it rejects with the capability-read or not-capable error.
- If the hardware cannot establish the capability evidence, the property fails as unknown, not as “set to disabled”.

This is the rule that should become the canonical reference for later LIST/SAVECONFIG work.

## G. FULLDUPLEX Canonical Rule

`/FULLDUPLEX` uses the same `ENABLED`/`DISABLED` parser.

Important semantics:

- `Cfg_Prepare_FULLDUPLEX` writes bit 15 of EEPROM word 0Dh (`EEPROM_SOFTWARE_INFO_FULLDUPLEX = 8000h`).
- The property is only valid on adapters that support Full Duplex as a capability.
- `Cfg_Validate_FD_Transceiver` enforces connectivity consistency: if the future state attempts to leave `FULLDUPLEX` enabled while the effective transceiver is `AUTO` or a non-TP selection, the request fails with `CFG_ERR_FD_TRANSCEIVER`.
- This is a separate concept from “adapter supports Full Duplex” and “persistent Full Duplex bit is currently enabled”.

The engine also preserves the established semantics that changing from TP to non-TP can implicitly clear persistent Full Duplex:

- `Cfg_Prepare_TR` checks a genuine transition from old effective TP to a requested non-TP target (AUI/COAX/AUTO).
- if the old EEPROM word 0Dh had Full Duplex enabled and the request did not include an explicit `/FULLDUPLEX`, it clears the Full Duplex bit in the prospective word 0Dh.
- the implicit clear is explicitly detected by `Cfg_Txn_Detect_Changes` and verified later by `Cfg_Txn_Verify`.

So the current canonical rule is:

- adapter supports Full Duplex capability: separate from current per-device bit
- current persistent bit enabled: separate from request outcome
- request result disabled due to implicit TR change: separate from “unsupported”

This distinction matters because the code verifies bit transitions independently of the historical property gate.

## H. TR Canonical Rule

The parser for `/TR` accepts four values:

- `TP` -> staged as `0`
- `AUI` -> staged as `1`
- `COAX` -> staged as `3`
- `AUTO` -> staged as `0FFh` sentinel

The relevant handler is `Cfg_Handle_TR` in [3CCFGCLI.ASM](./3CCFGCLI.ASM):

- `TP` matches two characters (`T`, `P`)
- `AUI` matches three characters (`A`, `U`, `I`)
- `COAX` matches four characters (`C`, `O`, `A`, `X`)
- `AUTO` matches four characters (`A`, `U`, `T`, `O`)

The property is encoded in word 08h:

- `TP` -> bits 15:14 = `00b`
- `AUI` -> bits 15:14 = `01b`
- `COAX` -> bits 15:14 = `11b`
- `AUTO` -> clear bits 15:14 and set bit 7 (`W0_ADDRESS_CFG_AUTO_SELECT`)

The capability gating in `Cfg_Txn_Execute` requires connector evidence from the live W0 Configuration Control register and checks the matching connector capability bit:

- `TP` requires `NIC_CAP_TP`
- `AUI` requires `NIC_CAP_AUI`
- `COAX` requires `NIC_CAP_BNC`
- `AUTO` requires at least one of `TP`, `AUI`, or `BNC` to be available, and also requires known 3C509B generation.

`/TR` is also cross-checked with `/FULLDUPLEX` by `Cfg_Validate_FD_Transceiver`, which rejects `FULLDUPLEX` when the effective transceiver is not TP.

The effective transceiver selection is a runtime property even when the persistent EEPROM field is being prepared. The current code explicitly calls out the distinction between “supported transceiver” and “effective current transceiver bit” before writing and verifying the transaction.

## I. INT Canonical Rule

`/INT` accepts only the configured 3C509/3C509B supported IRQ values:

- 3
- 5
- 7
- 9
- 10
- 11
- 12
- 15

This exact set is enforced in `Cfg_Handle_INT` in [3CCFGCLI.ASM](./3CCFGCLI.ASM). Any other input is rejected with `CFG_ERR_BAD_INT`.

After the user value is accepted, `Cfg_Prepare_INT` applies it into `cfg_txn_new_word09` and `cfg_txn_new_live08` by shifting the IRQ into the `W0_RESOURCE_CFG_IRQ_MASK` field using `W0_RESOURCE_CFG_IRQ_SHIFT = 12`.

The project also includes `Normalize_IRQ` in [3CCFGCLI.ASM](./3CCFGCLI.ASM), but that helper is not the same as CONFIGURE input validation. It is used during discovery and ID-port record construction to normalize a raw resource configuration IRQ nibble encountered in hardware data; invalid hardware values are mapped to 10. CONFIGURE itself rejects invalid textual inputs earlier and does not depend on that helper for user input acceptance.

## J. IOBASE Canonical Rule

`/IOBASE` validates the user input as a normal ISA base, not a selector encoded for EEPROM.

Accepted range:
- `0200h` through `03E0h`
- aligned to 16-byte boundaries only
- the selector must not be `1Fh` (EISA slot-specific addressing)

The parsing routine is `Cfg_Parse_IOBASE_Hex` in [3CCFGCLI.ASM](./3CCFGCLI.ASM). It accepts hexadecimal input with optional `0x` prefix and rejects values outside the dedicated ISA range or values that do not land on a 16-byte boundary.

The conversion helper in [3CSHIF.ASM](./3CSHIF.ASM):
- `Nic_IOBASE_Selector_To_Base` converts a 5-bit EEPROM selector to an ISA base;
- `Nic_IOBASE_Base_To_Selector` converts a valid ISA base back to a selector;
- selector `1Fh` is treated as unassigned/EISA-specific and returns zero (no normal ISA base) for the 3CCFGCLI ISA-only model.

Important distinction:

- persistent selector representation lives in the EEPROM Address Configuration field bits 4:0;
- normal ISA base representation is the user-visible value (`0200h` to `03E0h`);
- `1Fh` is a special EISA/unassigned selector that is not considered a normal CONFIGURE IOBASE value;
- a normal CONFIGURE request must therefore use `0200h`-`03E0h` and never an EISA selector.

Temporary access handling is explicitly part of the CONFIGURE transaction flow: `Cfg_Txn_Begin_Access` and `Cfg_Validate_Temporary_Base` establish a temporary working base, and the code ensures the selected record remains reachable before writing the new IOBASE.

## K. Other CONFIGURE Properties

The remaining properties are straightforward compared to PNP/FULLDUPLEX/TR/INT/IOBASE, but they still preserve their own canonical rules:

- `BADDRESS`: parsed as a Boot ROM base address; validated against the 8K/16K/32K Boot ROM rules and gated to known 3C509B generation only.
- `BSIZE`: paired with `BADDRESS`; disabled mode is only legal by itself; otherwise both `BADDRESS` and `BSIZE` must be present.
- `MODEM`: parsed as a documented maximum interrupt disable time field in word 0Dh bits 13:8, with named values such as `NONE`, `1200`, etc.
- `OPTIMIZE`: only accepts the named optimization values supported by the project.

These properties follow the same set of stages: parse -> stage -> capability gate -> prospective image -> verification. They are not the main focus of the current refactoring case, but they are also canonical and should remain separate from the transaction state machine.

## L. Separate Capability Rules from Transaction Policy

The code clearly distinguishes the categories below:

- Raw data acquisition: `Nic_EEPROM_Read`, `Nic_Reg_Read_Word`, `Get_Id_Eeprom_Snapshot`, `Cfg_Txn_Read_Current`
- Canonical interpretation: `Cfg_Read_Capabilities`, `Cfg_Prepare_PNP`, `Cfg_Prepare_FULLDUPLEX`, `Cfg_Prepare_TR`, `Cfg_Validate_FD_Transceiver`
- Property value validation: `Cfg_Handle_INT`, `Cfg_Parse_IOBASE_Hex`, `Cfg_Parse_EnableDisable`, `Cfg_Handle_TR`
- Hardware capability validation: `Cfg_Txn_Execute` gates, especially the `/PNP`, `/FULLDUPLEX`, `/TR`, and Boot ROM checks
- Cross-property validation: `Cfg_Prepare_TR`, `Cfg_Validate_FD_Transceiver`, implicit Full Duplex disable rules
- Transaction policy: `Cfg_Txn_Preflight`, `Cfg_Txn_Activate_If_Needed`, `Cfg_Txn_Write_EEPROM`, `Cfg_Txn_Write_Live`, `Cfg_Txn_End_Access`
- Write execution: `Cfg_Eeprom_Write`, `Cfg_Txn_Write_EEPROM`, `Cfg_Txn_Write_Live`
- Verification: `Cfg_Txn_Verify`
- User-facing error reporting: `Cfg_Report_Error`, `Cfg_Txn_Report_Current`, `Cfg_Txn_Report_Prospective`, `Cfg_Txn_Report_Implicit_FD_Notice`

The key design point is that capability rules and transaction policy are intentionally separate. Capability interpretation is a candidate for later neutral extraction, while the transaction state machine should remain CONFIGURE-specific.

## M. Current CONFIGURE-Specific Dependencies

`Cfg_Read_Capabilities` and related canonical routines still depend on CONFIGURE transaction state. Examples:

- `cfg_txn_access_base` is required to read EEPROM at the working base.
- `cfg_selected_ptr` is required to know which adapter record is being evaluated.
- `cfg_txn_capabilities` and `cfg_txn_capability_valid` are CONFIGURE-local caches for the snapshot taken before gates.
- `cfg_parse_flags` determines which properties are in play and therefore which field data must be read and which writes are relevant.
- `cfg_last_error` decides the user-facing failure result.
- `cfg_txn_change_flags` is used to decide what the transaction actually changed and what must be verified.

The dependency split is:

- essential to semantic rule: ASIC generation comparisons, capability bit validity, `cfg_selected_ptr`, selected adapter access base, proper `EEPROM`/live register source selection
- necessary only to obtain raw data: working-base selection, temporary revalidation, access activation, selection of the correct current window
- CONFIGURE-specific orchestration: `cfg_txn_*` caches, `cfg_parse_flags`, user-visible error reporting, activation migration logic, post-write verification flow

This should be treated as a boundary to preserve for later refactoring. The semantic rule may be extracted, but the transaction orchestration must not be silently reinterpreted as universal hardware semantics.

## N. Regression-Sensitive Behavior

The code indicates several areas that are especially sensitive to regressions and must be preserved exactly:

- temporary-base validation and unknown ASIC resolution (`FFh` to known revision)
- duplicate IOBASE conflicts and logical ownership checks
- PnP validity and generation gating
- Full Duplex capability and the TP requirement
- implicit Full Duplex disable during TP-to-non-TP `/TR` changes
- `AUTO` transceiver semantics and generation gating
- EEPROM busy/wait behavior and the `CFG_ERR_EEPROM_BUSY` path
- live synchronization after `Cfg_Txn_Activate_If_Needed`
- verification masks that only check the relevant field rather than the entire word
- original 3C509 versus 3C509B restrictions, especially on word 13h/word 14h and capability interpretation

These are exactly the places where a later refactor could accidentally change semantics even if the source code initially appears valid.

## O. Existing Test Coverage

The current repository contains a substantial smoke/test harness, but the analysis phase is intentionally not adding tests. The main gaps and coverage facts are:

Covered by the current test set and code comments:
- valid and invalid `/INT` values
- valid and invalid `/IOBASE` values
- PnP not-capable rejection path
- original 3C509 PnP rejection path
- original 3C509 Full Duplex rejection path
- Full Duplex requirement without capability
- TR connector rejection and /TR capability checks
- Full Duplex plus transceiver contradictions
- implicit Full Duplex disable on TP-to-non-TP transitions
- unknown / resolved ASIC revision path
- duplicate IOBASE handling and temporary access revalidation

Coverage is likely strongest for the transaction-level combination cases already encoded in the command and smoke test suite. The analysis does not show a need to add tests during this phase, but the above items are the canonical rule map that later C20/C27 refactoring must preserve.

## P. Potential Defects and Notes

No explicit bug was found in the current canonical implementation that required changing behavior during this analysis phase. The main caution is not an actual code defect but a conceptual trap:

- the discovery helper `Normalize_IRQ` is not equivalent to the `CONFIGURE` user parser, and the project must keep those semantics separate.
- `FFh` is a valid “unknown” state, not a supported card state; it must not be collapsed into an unsupported capability.
- The code splits “known unsupported” from “unknown because evidence could not be established”, and that distinction is deliberate and central to the canonical model.

This is therefore a canonical-model analysis rather than a behavior-change patch.
