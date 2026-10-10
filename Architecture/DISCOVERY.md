# Adapter Discovery Architecture

## Purpose

Adapter discovery is responsible for turning an initially unknown ISA
environment into the `nic_table` used by the rest of `3CCFGCLI`.

Discovery has to handle more than simply asking whether a card responds at a
particular I/O address.

A 3C509/3C509B may:

* be inactive and only discoverable through the proprietary 3Com ID port
* already be active at its configured ISA I/O base
* become active only after ID-port discovery and activation
* share its configured I/O base with another discovered adapter
* expose a configured I/O selector that this ISA-only utility deliberately
  does not support

Because of that, discovery is a coordinated multi-stage process.

The result is a set of normalized 16-byte records in `nic_table`.

Later code should consume those records rather than performing its own
independent adapter enumeration.

## Discovery at a glance

The complete discovery flow is coordinated by `Scan_All_3Com_Cards`.

```text
                       Scan_All_3Com_Cards
                                |
                                v
                    clear previous nic_table
                    reset discovery state
                                |
                                v
                  Discover_Id_Port_Cards
                                |
             +------------------+------------------+
             |                  |                  |
        contention          identify           build
        through ID port     supported NICs     provisional records
             |                  |                  |
             +------------------+------------------+
                                |
                                v
                   Nic_Activate_Tagged_Cards
                                |
                        activate discovered
                        tagged adapters
                                |
                                v
                   Validate_Active_Id_Records
                                |
                                v
                  refresh or verify existing
                   ID-discovered records
                                |
                                v
                    Enrich_All_3Com_Cards
                  isolated temporary access
                   for capability collection
                                |
                                v
                            nic_table
```

The order matters.

ID-port discovery identifies adapters that may not currently decode an ISA
I/O address.

Tagged activation then attempts to make those adapters accessible at their
configured bases.

Active-record validation probes only uniquely owned, nonzero configured bases
from the ID-discovered table. It does not enumerate every valid ISA base or
create additional records. Capability enrichment then uses isolated temporary
access to collect live facts for each tagged record.

## The NIC record

Each discovered adapter is represented by one 16-byte record.

The current layout is:

| Offset | Field            | Meaning                                              |
| ------ | ---------------- | ---------------------------------------------------- |
| `0`    | `NIC_IO_BASE`    | Configured ISA I/O base                              |
| `2`    | `NIC_PRODUCT_ID` | 3Com product ID                                      |
| `4`    | `NIC_ASIC_REV`   | ASIC revision, `FFh` when not yet readable           |
| `5`    | `NIC_MAC_ADDR`   | Six-byte MAC address                                 |
| `11`   | `NIC_IRQ_VAL`    | Normalized IRQ                                       |
| `12`   | `NIC_PORT_TYPE`  | Transceiver selection from Address Configuration     |
| `13`   | `NIC_TAG`        | ISA ID tag assigned during ID-port discovery         |
| `14`   | `NIC_ID_MODE`    | ID sequence mode used for later tag re-entry         |
| `15`   | `NIC_FLAGS`      | Record state flags                                   |

The current flags are:

| Flag               | Meaning                                                                            |
| ------------------ | ---------------------------------------------------------------------------------- |
| `NIC_FLAG_ACTIVE`  | The adapter has been verified as currently accessible at its ISA I/O base          |
| `NIC_FLAG_FROM_ID` | The record originated from 3Com ID-port discovery                                  |
| `NIC_FLAG_OEM_MAC` | `NIC_MAC_ADDR` contains the OEM node address from EEPROM words `0Ah` through `0Ch` |

The flags describe distinct record properties. A record may have
`NIC_FLAG_FROM_ID` set without `NIC_FLAG_ACTIVE`.

That means the adapter was identified through the ID port, but is not
currently known to be accessible at its configured base.

## `Scan_All_3Com_Cards`

`Scan_All_3Com_Cards` is the common discovery coordinator.

It first resets the previous discovery state:

* `card_count` becomes zero
* `current_card` becomes zero
* `id_short_mode` starts enabled
* `id_next_tag` starts at tag 1
* the complete `nic_table` is cleared

It then performs discovery, activation, validation, and enrichment in this order:

```text
Discover_Id_Port_Cards
        |
        v
Nic_Activate_Tagged_Cards
        |
        v
Validate_Active_Id_Records
        |
        v
Enrich_All_3Com_Cards
```

This procedure is the normal entry point when the application needs a current
adapter list.

`LIST`, `CONFIGURE`, and other higher-level operations should consume this
common discovery result rather than introducing their own enumeration logic.

# Phase 1: ID-port discovery

## Why the ID port is needed

An inactive 3C509 does not necessarily respond at its configured ISA I/O base.

The proprietary 3Com ID port allows such adapters to be discovered and
identified before normal ISA decode is active.

The project uses ID port `0110h`.

The common discovery algorithm lives in `3CCFGCLI.ASM`, while the actual
ID-port operations are supplied by the selected backend.

The backend boundary for those operations is documented in
[`BACKEND.md`](BACKEND.md).

## Initializing the ID port

`Discover_Id_Port_Cards` begins with:

```text
Nic_Init_Id_Port
```

This establishes the ID-port state expected by the following contention
sequence.

The detailed electrical and port-level behavior belongs to the backend and is
not duplicated in the discovery coordinator.

## Short sequence first, full sequence as fallback

Discovery initially attempts the short ID sequence.

`id_short_mode` begins as `1`.

While this remains set, the discovery loop uses:

```text
Nic_IdPort_Send_Short_Sequence
```

If the expected manufacturer or supported product cannot be identified, the
scan changes `id_short_mode` to `0` and retries using:

```text
Nic_IdPort_Send_Full_Sequence
```

Once discovery has switched to full mode, it remains there for the rest of
that scan.

The selected mode is later stored in each ID-discovered record as
`NIC_ID_MODE`.

This matters because tagged activation needs to re-enter the appropriate
ID-port state before selecting the adapter by tag.

## Manufacturer identification

The first presence check reads EEPROM word `07h`,
`EEPROM_MFG_ID`.

The required manufacturer value is:

```text
6D50h
```

This is the documented 3Com Manufacturer ID value used by the current
implementation.

The manufacturer check is intentionally not based on EEPROM node word `00h`.

## Product-family validation

After manufacturer identification, EEPROM word `03h`,
`EEPROM_PRODUCT_ID`, is read.

The product value is accepted only when:

```text
product_id AND F0FFh == 9050h
```

This is the supported 3C509 product family.

The original 3Com code also knows about other EtherLink III families, but
`3CCFGCLI` deliberately does not.

This project is restricted to the ISA 3C509/3C509B family.

An unsupported EtherLink III product must therefore not become a normal
`nic_table` record merely because it is recognizable as a 3Com adapter.

## Contender data and contention

Once the manufacturer and product family are accepted,
`Read_Id_Contender_Data` reads the fields required to construct the local
record.

The routine reads:

* node address words `00h` through `02h`
* Address Configuration word `08h`
* Resource Configuration word `09h`
* OEM node address words `0Ah` through `0Ch`
* Software Information word `0Dh`

Reading the node address is also part of the standard ID-port contention
process.

The standard station address words `00h` through `02h` are therefore read even
though the record ultimately stores the OEM node address from words `0Ah`
through `0Ch`.

The configuration and OEM values are collected while the current contender
still owns the ID-port transaction.

## EISA selector rejection

Address Configuration word `08h` uses bits `4:0` as the ISA I/O base
selector.

Selectors `00h` through `1Eh` represent the normal selectable ISA bases:

```text
0200h + selector * 10h
```

Selector `1Fh` has different semantics.

It requests EISA slot-specific addressing.

EISA support is intentionally outside the scope of this project.

A contender using selector `1Fh` is therefore rejected before normal record
construction.

The implementation does not simply abandon the whole discovery process.

Instead it assigns the reserved nonzero tag:

```text
ID_TAG_SKIP_EISA = 7
```

This retires that contender from further ID-port contention while allowing
remaining untagged adapters to continue participating.

For this skipped adapter:

* no `nic_table` record is created
* `card_count` is not incremented
* the adapter is not included in the later supported tagged activation set

Supported records use tags `1` through `MAX_CARDS`, where `MAX_CARDS` is
currently 6, so the reserved tag cannot collide with a supported record.

This behavior must be preserved.

Selector `1Fh` must never be decoded as if it were another ordinary ISA I/O
base.

## Duplicate ID-port identities

Before creating a new record, discovery calls
`Find_Duplicate_Id_Record`.

The comparison uses the OEM node address from EEPROM words `0Ah` through
`0Ch`.

If the contender matches an existing record, no second record is created.

Instead, the contender is assigned the existing record's tag and discovery
continues.

This prevents the same physical identity from producing duplicate table
entries through repeated ID-port visibility.

This duplicate mechanism is identity-based.

It should not be confused with the later active-record ownership check,
which detects shared I/O bases without merging or deleting records.

## Creating a provisional ID record

A new supported contender is converted into a record by
`Build_Record_From_Id`.

The record receives:

* the newly assigned ID tag
* the current short/full ID mode
* `NIC_FLAG_FROM_ID`
* the product ID
* decoded ISA I/O base
* normalized IRQ
* decoded transceiver selection
* the OEM MAC address

The ASIC revision is initialized to:

```text
FFh
```

because it has not yet been read from active hardware.

Most importantly:

```text
NIC_FLAG_ACTIVE
```

is **not** set at this stage.

The ID port has identified the card and exposed its persistent configuration,
but this does not yet prove that the adapter is currently reachable at its ISA
base.

## IRQ normalization

Resource Configuration word `09h` stores the IRQ in bits `15:12`.

The accepted IRQ values are:

```text
3, 5, 7, 9, 10, 11, 12, 15
```

If the stored nibble contains another value, the discovery record normalizes
it to IRQ 10.

This behavior mirrors the compatibility behavior already chosen by the
project and should not be casually replaced with generic validation during
record construction.

## Assigning tags

New supported adapters receive sequential tags beginning with 1.

After the record has been constructed, the selected contender is assigned
that tag through the ID port.

`card_count` and `id_next_tag` are then incremented and contention continues.

Tagging removes the already discovered contender from subsequent selection so
that the next untagged adapter can win contention.

The project currently supports up to:

```text
MAX_CARDS = 6
```

normal records.

# Phase 2: Tagged-card activation

## Purpose

After ID-port discovery completes, the provisional records may still describe
adapters that are not active on the ISA bus.

`Nic_Activate_Tagged_Cards` performs the activation step for the adapters just
discovered through the ID port. Its algorithm is shared in `3CSHIF.ASM`;
the selected backend supplies the ID-port primitives.

The application-level purpose, however, is the same:

```text
take tagged ID-discovered records
        |
        v
make their configured ISA decode active where possible
```

## Real hardware activation

The shared routine processes each record with a nonzero configured I/O base.

It:

1. re-enters short or full ID mode according to `NIC_ID_MODE`
2. selects the record's `NIC_TAG`
3. derives the 3Com activation selector from the configured I/O base
4. sends the ID-port activation command

On REALHW, the backend emits these commands to the physical ID port.
The activation routine neither probes the resulting base nor sets
`NIC_FLAG_ACTIVE`. Issuing activation does not itself prove runtime
reachability; that is checked separately by `Validate_Active_Id_Records`.

## Mock activation

MOCKHW runs the same shared `Nic_Activate_Tagged_Cards` command sequence.
Its ID-port backend models tag selection and activation:
`Mock_Id_Select_Tag` leaves matching-tag adapters in ID command state, and
`Mock_Id_Activate_Eligible` applies activation to adapters in that state.
It updates the live base and modeled decode state and persists the state.
This modeled activation state is distinct from `NIC_FLAG_ACTIVE` in the
application's `nic_table`.

This is an example of the distinction described in
[`BACKEND.md`](BACKEND.md):

Equivalent application semantics do not require identical internal backend
implementations.

The full mock ID-port tagging and activation model is documented in
[`MOCK.md`](MOCK.md).

## Activation failure

Failure to activate a tagged adapter does not automatically remove the
provisional record created through ID discovery.

The record can remain:

```text
NIC_FLAG_FROM_ID set
NIC_FLAG_ACTIVE clear
```

That state has meaning.

The program knows that an adapter identity and persistent configuration were
found through ID contention, but it does not claim that the hardware is
currently accessible through its ISA base.

Later code must preserve that distinction.

# Phase 3: Validation of active ID records

## Which bases are probed?

`Validate_Active_Id_Records` walks the `card_count` existing records in
`nic_table`, not `io_scan_table`.

For each record it:

1. skips a zero (unassigned) `NIC_IO_BASE`
2. calls `Find_Record_By_Base` for the configured base
3. proceeds only when the returned pointer is the current record
4. calls `Nic_Check_3Com_Signature` at that base

`Find_Record_By_Base` returns zero for no matching record, `FFFFh` for
multiple matches, or the sole matching record's pointer. Shared bases are
therefore skipped before any signature probe; their logical records remain
separate and do not receive active status from an ambiguous response.

Normal ID discovery rejects EISA selector `1Fh` before record construction,
so supported records normally have nonzero ISA bases. The zero-base check
also protects validation if an unassigned record is present.

## Signature results and active status

`Nic_Check_3Com_Signature`, shared in `3CSHIF.ASM`, checks command/status
access, the Window 0 manufacturer ID and supported product family, and reads
the ASIC revision from Window 4. It restores the original register window.

A failed probe advances to the next record without setting
`NIC_FLAG_ACTIVE`. A successful probe refreshes the sole owner's
`NIC_PRODUCT_ID` and `NIC_ASIC_REV` and sets `NIC_FLAG_ACTIVE`.

This configured-base check does not compare the OEM node address; the stronger
identity comparison belongs to temporary working-base validation below.

There is no record-construction path here and no increment of `card_count`.
A base absent from the ID-discovered table is not probed by this phase, so
even a responding adapter there cannot create a new record.

## The separate role of `io_scan_table`

`io_scan_table` still contains all 31 valid selectable ISA bases, emitted by
`ISA_IOBASE_TABLE` in `3C509DEF.INC` and followed by a zero terminator.
They cover `0200h` through `03E0h` in `10h` increments, with the `0300h`
range first and the `0200h` range afterward. `03F0h` is excluded because
selector `1Fh` requests EISA slot-specific addressing.

The table is consumed by `Nic_Find_Temporary_Base`, not by active-record
validation. That routine selects a working address for an already known,
ID-tagged adapter:

1. skips the selected adapter's configured base
2. skips any base configured by a record in `nic_table`, regardless of its
   active flag
3. samples each of the candidate range's 16 ports 16 times through
   `Nic_Probe_IO_Byte`, rejecting the candidate if the final sample for a port
   is not `FFh`
4. activates the selected tag at the candidate base
5. calls `Nic_Validate_Temporary_Base` to compare the signature, product ID,
   known ASIC revision, and OEM EEPROM node address against the logical record

If identity validation fails, it issues activation at the configured base
before trying another candidate. Success returns the temporary base; exhausting
the table returns carry set. This is working-address selection, not adapter
enumeration, and does not create records or set `NIC_FLAG_ACTIVE`.

# Phase 4: Capability enrichment

`Enrich_All_3Com_Cards` uses `Nic_Begin_Temporary_Access` for each record,
collects capabilities through `Nic_Read_Capabilities`, and calls
`Nic_End_Temporary_Access` to restore the configured base. Capability results
are published only after restoration succeeds.

Temporary validation can learn an unknown ASIC revision even for a record whose
configured base was not uniquely accessible. It does not turn temporary
reachability into configured-base active status.

# How records converge

The stages preserve ID-discovered identity while adding verified live facts.

The most common ID-discovered case looks like this:

```text
                  ID-port contention
                         |
                         v
                +------------------+
                | provisional      |
                | FROM_ID          |
                | ACTIVE clear     |
                | tag assigned     |
                +------------------+
                         |
                  tagged activation
                         |
                         |
                ACTIVE still clear
                         |
             Validate_Active_Id_Records
                         |
             +-----------+-----------+
             |                       |
       zero/shared base       unique responding base
       or failed probe               |
             |                       v
             v                FROM_ID | ACTIVE
     remains FROM_ID          refresh product/revision
             |                       |
             +-----------+-----------+
                         |
               temporary capability
                    enrichment
```

# Identity, configuration and activity are different things

Discovery deliberately keeps several concepts separate.

They must not be collapsed into one test.

## Identity

The ID-port path can establish that a supported 3C509-family adapter exists
and recover its persistent identity.

This is represented by `NIC_FLAG_FROM_ID` and the stored ID tag.

## Configured I/O base

`NIC_IO_BASE` describes the ISA base derived from the adapter's configuration.

A nonzero value does not by itself prove that the adapter is currently
responding there.

## Active accessibility

`NIC_FLAG_ACTIVE` means that the adapter has been established as accessible
through an active ISA base.

Later code must not assume that a record containing an I/O base is live.
Configured-base access and validated temporary working access are distinct:
temporary access can reach a tagged record whose configured base is ambiguous
and whose `NIC_FLAG_ACTIVE` remains clear.

This distinction matters to `CONFIGURE`, capability reads, extended
information, verification, and other hardware-facing operations.

# Discovery versus working-base validation

Initial discovery and later selected-adapter working-base validation are related
but are not the same operation.

Discovery builds the candidate table.

Once `CONFIGURE` selects a particular record, the transaction obtains a unique
working base for that selected adapter before it reads or writes hardware state.

The purpose of working-base validation is to ensure that the adapter selected
from the discovery result is still the adapter the transaction is about to
operate on.

It should not be replaced by another complete enumeration pass inside an
individual configuration property handler.

The transaction and selected-adapter working-base validation flow is documented
in [`TRANSACTIONS.md`](TRANSACTIONS.md).

# Discovery and the backend boundary

Most of the discovery algorithm lives in common code.

Examples include:

* scan coordination
* manufacturer validation
* product-family validation
* contender EEPROM interpretation
* duplicate identity handling
* provisional record construction
* configured-base ownership checks and active-record validation
* temporary working-base selection and capability enrichment

The backend supplies the actual hardware operations required by those
algorithms.

Shared hardware algorithms in `3CSHIF.ASM`, including
`Nic_Activate_Tagged_Cards` and `Nic_Check_3Com_Signature`, use those backend
primitives rather than separate real and mock discovery policies.

Do not move higher-level discovery policy into MOCKHW merely because doing so
would simplify a test.

Likewise, do not duplicate the complete discovery algorithm inside REALHW.

The common discovery path is one of the mechanisms that keeps mock testing
relevant to the real application.

# Discovery invariants

The following rules should remain true when modifying adapter discovery:

* `Scan_All_3Com_Cards` remains the common coordinator for normal adapter
  enumeration.
* Discovery begins from a cleared `nic_table` and reset discovery state.
* ID-port discovery happens before tagged-card activation.
* Tagged-card activation happens before active-record validation.
* ID-port discovery is the only source of supported `nic_table` records.
* Active-record validation probes only uniquely owned, nonzero configured bases
  and only verifies or refreshes existing records.
* Temporary-base selection uses `io_scan_table` for working access, not discovery.
* Only the supported `9050h` 3C509 product family becomes a normal supported
  record.
* EEPROM manufacturer identification uses documented `6D50h`.
* EISA selector `1Fh` must not be decoded as an ISA I/O base.
* An EISA-addressed contender must be retired from contention without becoming
  a normal `nic_table` entry.
* A provisional ID-port record is not active merely because it contains a
  configured I/O base.
* `NIC_FLAG_ACTIVE` is the record-level indication that normal active hardware
  access is available.
* `NIC_FLAG_FROM_ID` records how the adapter was discovered and is independent
  of active state.
* ID-port duplicate suppression uses OEM node identity.
* configured-base ambiguity checks use I/O base and preserve separate records.
* ID-discovered records retain their tag and ID sequence mode.
* ASIC revision remains `FFh` in a provisional ID record until active hardware
  has provided a real value.
* successful active-base signature results should be reused rather than
  immediately reprobed without need.
* property handlers must not create their own independent adapter scanners.
* discovery policy remains common code unless there is a real hardware reason
  for a backend-specific operation.

The important question when consuming a `nic_table` record is therefore not
just:

```text
Did we find a card?
```

It is also:

```text
How did we find it?

Do we know its ID-port identity?

What base is configured?

And has the adapter actually been verified as active there?
```

Those distinctions are deliberate and form the basis for the later
configuration and verification architecture.
