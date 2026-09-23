# Mock Hardware Architecture

## Purpose

`3CMOCKIF.ASM` is the MOCKHW backend implementation described architecturally
in [BACKEND.md](BACKEND.md).

This document describes the mock hardware model itself: what state it keeps,
how it represents ID-port contention, tagging, and activation, how it stores
persistent EEPROM and live register state, what it deliberately simplifies,
and which parts of it exist purely to support regression testing rather than
to model a real adapter.

`3CSEED.EXE` is the companion fixture generator. It writes the same on-disk
mock state file that `3CMOCKIF.ASM` loads and operates on. `3CSEED` creates
starting states; it is not part of the runtime hardware interface and does not
reproduce any application behavior. See [BACKEND.md](BACKEND.md) for the
boundary between fixture creation and the runtime mock backend.

Related architecture documents are:

* [BACKEND.md](BACKEND.md), the backend contract shared with `3CHWIF.ASM`
* [DISCOVERY.md](DISCOVERY.md), the common discovery algorithm the mock supports
* [STATE_MODEL.md](STATE_MODEL.md), the persistent-versus-live distinction the mock must preserve
* [TRANSACTIONS.md](TRANSACTIONS.md), the CONFIGURE transaction the mock backs
* [EEPROM.md](EEPROM.md), the EEPROM field layout the mock stores per adapter
* [TESTING.md](TESTING.md), how `TEST.MK` uses the mock and `3CSEED` together
* [INVARIANTS.md](INVARIANTS.md), section 10, the mandatory mock rules

## 1. What The Mock Is For

The mock exists so that `3CCFGCLI` application logic (discovery, `LIST`,
`CONFIGURE` transactions, `SAVECONFIG`) can run unmodified against a
software-modeled adapter instead of a physical 3C509/3C509B.

The mock is deliberately more than a table of expected answers. A header
comment in `3CMOCKIF.ASM` states the goal directly: the mock preserves the
hardware-facing contract used by `3CCFGCLI`, including ID-port discovery that
enumerates untagged contenders one by one, tag/select/activate semantics
modeled per mock NIC record, and active-base register and EEPROM access that
routes to the addressed record.

`INV-MOCK-01` states this as a standing rule: `3CMOCKIF` must model hardware
behavior rather than return expected answers for individual tests.

## 2. Relationship Between REALHW And MOCKHW

`3CCFGCLI.ASM` selects the backend at assembly time with `IFDEF REALHW` /
`IFDEF MOCKHW`. There is no runtime dispatch between the two; a build
includes either `3CHWIF.ASM` or `3CMOCKIF.ASM`, never both. `3CSHIF.ASM`, the
backend-independent layer, is always included afterward. See
[BACKEND.md](BACKEND.md) for the complete compile-time composition.

Both backends implement the same `Nic_*` procedure names, including
`Nic_IdPort_Write_Command`, `Nic_IdPort_Send_Full_Sequence`,
`Nic_IdPort_Send_Short_Sequence`, `Nic_IdPort_Eeprom_Delay`,
`Nic_Init_Id_Port`, `Nic_IdPort_Read_Bit`, `Nic_IO_Read_Word`,
`Nic_IO_Write_Word`, `Nic_Wait_Command_Ready`, `Nic_EEPROM_Read`,
`Nic_Rom_Read_Byte`, `Nic_Rom_Set_Page`, `Nic_Check_3Com_Signature`, and
`Nic_Activate_Tagged_Cards`.

Equivalent contract does not mean identical implementation. For example,
`Nic_IdPort_Eeprom_Delay` performs a real timing loop in `3CHWIF.ASM` and is a
no-op `ret` in `3CMOCKIF.ASM`, because the application only depends on the
hardware-visible result, not on elapsed CPU time.

## 3. The Mock State File

Persistent mock state lives in `3C509B.MCK`, defined by the
`MOCK_STATE_FILE` constant in both `3CMOCKIF.ASM` and `3CSEED.ASM`.

The file format is versioned:

```text
MCK_VERSION      = 0004h   ; v4: MCK3R_ASIC_REV is now mandatory
MCK_HEADER_SIZE  = 16 bytes
MCK_MAX_RECORDS  = 6
MCK_RECORD_SIZE  = 256 bytes
MCK_FILE_SIZE    = MCK_HEADER_SIZE + (MCK_MAX_RECORDS * MCK_RECORD_SIZE)
```

`MCK_MAX_RECORDS` matches the application-level `MAX_CARDS` limit used by
discovery; the mock cannot represent more adapters than the application
itself supports.

Storing the file persistently between separate DOS invocations is
deliberate. Loading `3CHWMOCK.EXE` for another process is not equivalent to
power-cycling a physical adapter, and `Nic_Init_Id_Port` does not reset tags
or ID state merely because the backend was opened (`INV-STATE-08`). If the
mock recreated every live register from EEPROM on every process start, many
real-hardware persistence bugs would become impossible to reproduce.

Statefile persistence is internal mock infrastructure, not a NIC operation.
When a modeled ID-port transition occurs inside an interrupt-masked common
sequence, `3CMOCKIF.ASM` commits its model, temporarily enables interrupts
only for DOS file I/O, and restores the caller's original FLAGS. `3CCFGCLI`
does not participate in this housekeeping.

## 4. Per-Adapter Mock Record

Each of the up to `MCK_MAX_RECORDS` slots in the file is a 256-byte
`MCK3R_*` record. The fields fall into the same categories described in
[STATE_MODEL.md](STATE_MODEL.md):

| Category                     | Representative fields                                                                                   |
| ----------------------------- | --------------------------------------------------------------------------------------------------------- |
| Presence / identity            | `MCK3R_PRESENT`, `MCK3R_ASIC_REV`                                                                         |
| ID-port / activation state     | `MCK3R_ID_STATE`, `MCK3R_TAG`, `MCK3R_FLAGS`, `MCK3R_ACTIVE_BASE`, `MCK3R_ID_SHIFT`, `MCK3R_ID_BITS_LEFT` |
| Live register state            | `MCK3R_CURRENT_WINDOW`, `MCK3R_W0_PRODUCT`, `MCK3R_W0_CONFIG_CONTROL`, `MCK3R_W0_ADDRESS_CFG`, `MCK3R_W0_RESOURCE_CFG`, `MCK3R_W2_STATION`, `MCK3R_W3_INTERNAL_CONFIG`, `MCK3R_W4_NET_DIAG_WRITE`, `MCK3R_W4_MEDIA_WRITE`, `MCK3R_W4_MEDIA_INPUT` |
| Command / EEPROM state         | `MCK3R_COMMAND_BUSY`, `MCK3R_EEPROM_BUSY`, `MCK3R_EEPROM_FLAGS`, `MCK3R_EEPROM_PENDING`, `MCK3R_EEPROM_COMMAND`, `MCK3R_EEPROM_DATA` |
| Persistent EEPROM               | `MCK3R_EEPROM` (64 words)                                                                                 |
| Physical Option ROM             | `MCK3R_ROM_SIZE`, `MCK3R_ROM_PAGE`                                                                        |

`Mock_Commit_Loaded_Record` copies the currently loaded scratch state
(`mock_state`) back into a record's `MCK3R_EEPROM` area in the file image;
`Mock_Load_Record_By_Index` performs the reverse. Only one record is loaded
into the `mock_state` scratch image at a time.

`INV-MOCK-03` requires that adapter-owned hardware state stay associated with
its corresponding mock record rather than becoming untracked global state.

## 5. Shared ID-Bus State Versus Per-Adapter State

The mock source deliberately classifies its state variables into three
groups, documented directly in the `3CMOCKIF.ASM` header comment. This
classification matters because collapsing it would violate `INV-MOCK-04`.

**Per-adapter hardware state** (lives in the `MCK3R_*` record, not in global
scratch): `MCK3R_ID_STATE`, `MCK3R_TAG`, `MCK3R_ID_SHIFT`, `MCK3R_ID_BITS_LEFT`
(per-record contention shift registers, because contention genuinely spans
multiple simultaneous adapters), `MCK3R_FLAGS` (active / coax-started),
`MCK3R_ACTIVE_BASE`.

**Shared ID-bus state** (global by nature, because there is exactly one ID
port): `mock_id_shift` / `mock_id_bits_left` (the serial shift register used
for a single explicitly tagged/selected adapter's direct EEPROM word reads,
distinct from the per-record contention shift registers above),
`mock_contender_index` / `mock_contender_visible` / `mock_id_contention_active`
(which record, if any, is still contending), `mock_selected_tag` /
`mock_selected_valid` (which tag was isolated by the last `SELECT_TAG`, used
to route direct EEPROM reads).

**Temporary host-side scratch** (sequence-recognition bookkeeping with no
per-adapter meaning, because every untagged adapter tracks the same 255-byte
LFSR stream identically): `mock_id_sequence_expected`, `mock_id_sequence_count`,
`mock_id_zero_count`, `mock_id_command_ready`.

## 6. ID-Port Contention And Tagging

The mock implements the same 3Com ID-port state machine described in
[DISCOVERY.md](DISCOVERY.md): a shared open-drain-style contention read,
tag assignment, tag selection, and activation.

`Mock_Id_Process_Sequence_Byte` enforces the ID sequence recognition rules
(255-byte LFSR stream, or the short re-entry sequence for an already tagged
adapter) and, once enough bytes are recognized, calls either
`Mock_Id_Enter_Command` or `Mock_Id_Enter_Short_Command`.

`Mock_Id_Start_Contention_Read` and `Mock_Id_Read_Contention_Bit` model
wired-AND contention across every untagged, currently visible record.
`Nic_IdPort_Read_Bit` dispatches into contention mode whenever
`mock_id_contention_active` is set, satisfying `INV-MOCK-05`.

`Mock_Id_Select_Tag` moves the matching tagged adapter into `MCK_ID_CMD` for
subsequent direct EEPROM reads and returns every other contending adapter to
`MCK_ID_WAIT`. The resulting `mock_selected_tag` / `mock_selected_valid` state
is documented as being used only to route subsequent direct EEPROM serial
reads; it is not activation authority by itself.

`Mock_Id_Activate_Eligible` broadcasts activation to every adapter currently
in `MCK_ID_CMD`. It updates the modeled live `MCK3R_W0_ADDRESS_CFG` selector,
computes the resulting `MCK3R_ACTIVE_BASE`, and sets or clears `MCKRF_ACTIVE`
in `MCK3R_FLAGS`. Only the live I/O selector changes this way; the persistent
EEPROM Address Configuration selector is untouched unless a separate EEPROM
write occurs. Every adapter is then returned to `MCK_ID_WAIT`.

`Mock_Id_Clear_All_Tags` clears `MCK3R_TAG` on every present adapter and
returns them to `MCK_ID_WAIT`. `Mock_Id_Global_Reset_All` models the broadcast
`C0h`-`CFh` ID-port global reset command and returns every adapter currently
in `MCK_ID_CMD` to the documented power-on-reset state.

`INV-MOCK-06` requires that tags and activation state change only because of
these modeled ID-port operations, never because application code directly
requests a particular outcome.

## 7. Tagged Versus Active State In The Mock

The mock preserves the same distinction described in
[DISCOVERY.md](DISCOVERY.md) between an ID-discovered ("tagged") record and
one verified as active at its ISA base. A record's `MCK3R_TAG` and
`MCK3R_ID_STATE` describe ID-port bus visibility; `MCKRF_ACTIVE` in
`MCK3R_FLAGS` describes whether the record currently decodes its active base.
`Nic_Activate_Tagged_Cards` (the shared backend entry point described in
[BACKEND.md](BACKEND.md)) locates the modeled adapter by tag, applies the
configured active base, sets the modeled activation state, commits the
resulting record, and persists it — but deliberately does not itself prove
runtime reachability; that is established separately by the active-base scan
and signature check, exactly as it is for REALHW.

## 8. Live Registers And Windows

`Mock_Reg_Read_Word` and `Mock_Reg_Write_Word` dispatch on `mock_current_window`
and model windows 0, 2, 3, and 4 explicitly. The mock does not short-circuit
generic register access into an application-level shortcut.

* **Window 0**: `EL3_W0_CONFIG_CONTROL` is writable subject to
  `W0_CONFIG_CONTROL_WRITABLE`; `EL3_W0_EEPROM_COMMAND` routes into EEPROM
  command handling; `EL3_W0_MFG_ID` and `EL3_W0_PRODUCT_ID` are read-only.
* **Window 2**: live station-address bytes map to `mock_w2_station`. This is
  independent of the EEPROM node-address words and is never auto-loaded on
  reset, matching [STATE_MODEL.md](STATE_MODEL.md).
* **Window 3**: the live 32-bit Internal Configuration register maps to
  `mock_w3_config_lo` / `mock_w3_config_hi`. It is loaded only by
  `Mock_Automatic_Configuration` from EEPROM words `12h`/`13h`, and is not
  continuously mirrored from EEPROM afterward.
* **Window 4**: Network Diagnostic and Media Status state are modeled
  separately through `mock_w4_netdiag` and `mock_w4_media_status`. The
  Network Diagnostic register also exposes the record's decoded
  `MCK3R_ASIC_REV` in bits `5:1`, the same path real hardware uses.

Unsupported windows or offsets return zero rather than fabricated data.

`Mock_Resolve_And_Read_Word` models Status Register bit 12
(Command-In-Progress) as a deterministic "busy once, then clear" sequence: a
command that logically requires completion polling sets `mock_command_busy`
to a small nonzero count, and each status read reports the bit while nonzero
and decrements it.

## 9. Automatic Configuration And Reset

`Mock_Automatic_Configuration` is the explicit synchronization point where
selected persistent EEPROM fields are loaded into live state:

```text
EEPROM word 03h -> Window 0 Product ID
EEPROM word 08h -> Window 0 Address Configuration
EEPROM word 09h -> Window 0 Resource Configuration
EEPROM word 12h -> Window 3 Internal Configuration low word
EEPROM word 13h -> Window 3 Internal Configuration high word
```

It also resets configuration-facing state: register window 0, cleared
command-busy state, cleared EEPROM operation state, reset Window 4 writable
control state, reset Option ROM page, and cleared modeled coax-start state.
Window 2 station-address registers are not loaded here.

`Mock_Reset_Loaded_Record` represents power-on-reset. It clears active ISA
decode, active base, tag, and current ID shift state, then calls
`Mock_Automatic_Configuration`. Both the addressed command-register Global
Reset and the ID-port Global Reset use this same reset machinery, although
the caller decides which adapters are actually reset (`INV-MOCK-08`).

Per `INV-STATE-08`, starting a new host process against `3C509B.MCK` is not
itself treated as a hardware reset; automatic configuration only happens at
these documented modeled hardware transitions.

## 10. Mock EEPROM Access

Persistent EEPROM data lives in the 64-word `MCK3R_EEPROM` area of the loaded
adapter's record. `Nic_EEPROM_Read` in the mock issues the same
command/data register protocol the application uses for REALHW, then polls
`EEPROM_BUSY` via register reads rather than short-circuiting the data
directly out of the record. `mock_eeprom_busy`, `mock_eeprom_flags`, and
`mock_eeprom_pending` are persisted per record so a busy or pending EEPROM
operation observed by one process can still be observed correctly by a
later one.

Per `INV-MOCK-07`, EEPROM writes are not continuously mirrored into live
registers. A later read of a live register that happens to share bits with a
just-written EEPROM word does not automatically reflect the new value; only
an explicit synchronization point such as `Mock_Automatic_Configuration`
performs that transfer.

## 11. Temporary Access In The Mock

CONFIGURE's temporary working-base mechanism, described in
[TRANSACTIONS.md](TRANSACTIONS.md), is backed by the same explicit
tag/select/activate sequence described in section 6 above:
`Nic_Begin_Temporary_Access` uses selected-tag explicit activation to move an
adapter to a temporary working base before transaction-time normal I/O
access begins, and `Nic_End_Temporary_Access` restores it to its configured
base afterward. The mock does not need a separate temporary-access code path;
it reuses the same modeled ID-port activation primitives REALHW uses.

## 12. Physical Option ROM Modeling

The mock stores a synthetic installed Option ROM size (`MCK3R_ROM_SIZE`) and
page (`MCK3R_ROM_PAGE`) per record, independent of the persistent Boot ROM
EEPROM configuration. `Nic_Rom_Read_Byte` checks the modeled ROM size and the
live `MCK3R_W0_ADDRESS_CFG` Boot ROM base/size fields, computes the requested
offset within the modeled aperture, and returns `FFh` for an out-of-range
access. It also produces size-specific header/checksum bytes so ROM
signature/size probing exercises real decode logic rather than a canned
answer.

This physical/configured separation is required by `INV-MOCK-13`: physical
mock Option ROM presence and size must remain independent from configured
Boot ROM state. It is what allows the regression suite to exercise absent
ROM, undersized ROM, and correctly sized ROM as distinct fixture states, as
described in [TESTING.md](TESTING.md).

## 13. Same-IOBASE Conflicts

Multiple simultaneously active mock records sharing one active I/O base are
modeled as a genuine conflict, not resolved by silently picking the first
match. `Mock_Find_Record_By_Port` fails as unavailable/ambiguous when zero or
more than one active record decodes the requested port, because ordinary
register I/O cannot by itself identify which tagged adapter is intended. ID
port identity (discovery, contention, tags, `SELECT_TAG`, EEPROM-via-ID-port
reads, and activation) remains valid throughout and continues to distinguish
adapters by tag even in this state.

This satisfies `INV-MOCK-14`: same-I/O-base multi-adapter conflicts are a
deliberate conflict simulation, not a claim that this exact ambiguity is the
only possible physical outcome.

## 14. What The Mock Does Not Model

Some behavior is deliberately not modeled, or modeled only as
configuration-visible state:

* `mock_coax_started` mirrors `MCKRF_COAX_STARTED`, set by a currently
  unreachable Start Coaxial Transceiver command. It is configuration-visible
  state only; there is no analog coax signal model.
* Shared-IRQ scenarios across mock adapters are acceptable because
  `3CCFGCLI` does not depend on interrupt-driven communication with the
  adapter. The mock does not model actual IRQ line contention.
* The mock does not simulate constrained system memory (64 KB / 128 KB /
  256 KB). That is a property of the DOSBox X test environment, not of
  `3CMOCKIF.ASM`; see the hardware limit testing section of
  [TESTING.md](TESTING.md) and `TESTHWL.BAT`.
* `Nic_IdPort_Eeprom_Delay` is a no-op in the mock. Real elapsed EEPROM
  timing is a `3CHWIF.ASM`-only concern; see [BACKEND.md](BACKEND.md).

Per `INV-MOCK-15`, unsupported or unmodeled hardware behavior should be
represented conservatively (for example, returning zero or failing the
operation) rather than inventing a plausible-looking answer merely to satisfy
an application code path that happens to ask for it.

## 15. `3CSEED` And The Mock

`3CSEED.EXE` creates or appends deterministic records directly into
`3C509B.MCK` using the same `MCK_*` / `MCK3R_*` layout `3CMOCKIF.ASM` reads,
without going through any runtime hardware protocol. Its top-level verbs are
`INIT` (recreate the file with one default or named card), `ADD` (append a
card to an existing file), and `CLEAR` (delete the file); a bare model name
is shorthand for `INIT model`. Supported models cover both ASIC-revision
generations (`3C509B-TP`, `3C509B-COAX`, `3C509B-COMBO`, `3C509B-TPO`,
`3C509B-TPC`, and their `3C509-*` revision-1 counterparts), and optional
`/IOBASE:`, `/INT:`, `/MODEMPRESERVE`, `/M1200US`, `/ROM8K`, `/ROM16K`, and
`/ROM32K` attributes further shape the created record. The exact verb and
option reference lives in [README.md](../README.md).

Per `INV-MOCK-09` and `INV-MOCK-10`, `3CSEED` only creates initial fixtures
and must remain deterministic; it must not replace runtime hardware behavior
that belongs in `3CMOCKIF.ASM`, and randomized fixtures must not be
introduced into regression behavior. Per `INV-MOCK-12`, a fixture may
deliberately construct disagreement between hardware information sources
(for example, a stale live Full Duplex bit versus a different persistent
policy) precisely because that disagreement is the condition a test needs to
exercise; that is a legitimate fixture, not a modeling defect.

## 16. Mock Architecture Invariants

The following rules should remain true when modifying the mock backend. They
restate section 10 of [INVARIANTS.md](INVARIANTS.md) in the context of this
document:

* `3CMOCKIF.ASM` models hardware behavior; it must not special-case a
  particular test's expected result.
* Persistent EEPROM and live register state remain distinct, and EEPROM
  writes are not continuously mirrored into live registers.
* Adapter-owned state stays in the corresponding `MCK3R_*` record; shared
  ID-bus state stays global; sequence-recognition scratch has no per-adapter
  meaning.
* ID-port contention, tagging, selection, and activation change tags and
  activation state only through modeled ID-port operations.
* `Mock_Automatic_Configuration` remains the explicit EEPROM-to-live
  synchronization point; it is not a continuous mirror.
* `3CSEED` creates deterministic fixtures only; it is not a substitute for
  runtime mock behavior and must not become nondeterministic.
* Physical Option ROM presence/size stays independent of configured Boot ROM
  state.
* Same-I/O-base multi-adapter conflicts remain a deliberate conflict
  simulation.
* Unmodeled or unsupported hardware behavior is represented conservatively,
  not invented to satisfy an application path.

Testing procedures that exercise this model are documented in
[TESTING.md](TESTING.md) and, for physical hardware, [HWCTEST.md](../HWCTEST.md).
This document describes the model itself, not the test inventory built on
top of it.
