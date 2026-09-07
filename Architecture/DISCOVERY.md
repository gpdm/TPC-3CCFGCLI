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
* be encountered more than once during the complete discovery process
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
                    Scan_Active_Base_Ports
                                |
              +-----------------+-----------------+
              |                                   |
       refresh records                     find adapters that
       already known                       were already active
       from ID discovery                   at an ISA base
              |                                   |
              +-----------------+-----------------+
                                |
                                v
                            nic_table
```

The order matters.

ID-port discovery identifies adapters that may not currently decode an ISA
I/O address.

Tagged activation then attempts to make those adapters accessible at their
configured bases.

The final active-base scan verifies the resulting live adapters and also finds
cards that were already active before the ID-port sequence began.

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
| `13`   | `NIC_TAG`        | ISA ID tag, zero when not known through ID discovery |
| `14`   | `NIC_ID_MODE`    | ID sequence mode used for later tag re-entry         |
| `15`   | `NIC_FLAGS`      | Record state flags                                   |

The current flags are:

| Flag               | Meaning                                                                            |
| ------------------ | ---------------------------------------------------------------------------------- |
| `NIC_FLAG_ACTIVE`  | The adapter has been verified as currently accessible at its ISA I/O base          |
| `NIC_FLAG_FROM_ID` | The record originated from 3Com ID-port discovery                                  |
| `NIC_FLAG_OEM_MAC` | `NIC_MAC_ADDR` contains the OEM node address from EEPROM words `0Ah` through `0Ch` |

These flags are deliberately independent.

For example, a record may have `NIC_FLAG_FROM_ID` set without
`NIC_FLAG_ACTIVE`.

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

It then performs the three discovery phases in this order:

```text
Discover_Id_Port_Cards
        |
        v
Nic_Activate_Tagged_Cards
        |
        v
Scan_Active_Base_Ports
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

It should not be confused with the later active-base duplicate handling,
which operates on I/O base addresses.

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

`Nic_Activate_Tagged_Cards` performs the backend-specific activation step for
the adapters just discovered through the ID port.

This procedure belongs to the backend because the real and mock
implementations reach activation differently.

The application-level purpose, however, is the same:

```text
take tagged ID-discovered records
        |
        v
make their configured ISA decode active where possible
```

## Real hardware activation

On REALHW, each record with a nonzero configured I/O base is processed.

The backend:

1. re-enters short or full ID mode according to `NIC_ID_MODE`
2. selects the record's `NIC_TAG`
3. derives the 3Com activation selector from the configured I/O base
4. sends the ID-port activation command
5. probes the resulting active base using `Nic_Check_3Com_Signature`

Only after the signature check succeeds does the record receive:

```text
NIC_FLAG_ACTIVE
```

The live product ID and ASIC revision are also refreshed from the active
adapter.

## Mock activation

MOCKHW exposes the same application-level operation through
`Nic_Activate_Tagged_Cards`, but does not need to reproduce the literal ISA
bus sequence instruction by instruction.

It locates the modeled adapter by tag, applies the configured active base, sets
the modeled activation state, commits the resulting mock record, and persists
the state.

This is an example of the distinction described in
[`BACKEND.md`](BACKEND.md):

Equivalent application semantics do not require identical internal backend
implementations.

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

# Phase 3: Active-base scanning

## Why scan again after activation?

Even after ID-port discovery and activation, the program performs a complete
scan of valid active ISA bases.

This is not redundant.

The final scan serves two purposes:

1. verify and refresh adapters that are now active
2. detect adapters that were already active before ID-port discovery

This means the discovery system can recover useful records through either
mechanism without maintaining two separate final adapter lists.

## Valid base addresses

`io_scan_table` contains all 31 valid selectable ISA bases.

They cover:

```text
0200h through 03E0h
```

in `10h` increments.

The table is ordered with the `0300h` range first and the `0200h` range
afterward, but all 31 valid selector values are represented.

`03F0h` is not included.

EEPROM selector `1Fh` does not represent another normal ISA base.

## Signature probing

For every base in `io_scan_table`,
`Scan_Active_Base_Ports` calls:

```text
Nic_Check_3Com_Signature
```

A failed signature probe simply advances to the next base.

A successful probe returns the product ID and ASIC revision needed for the
record.

The successful probe result is retained and reused by the remainder of the
current scan iteration.

The active scan should not add unnecessary duplicate signature probes after a
base has already been validated.

## Matching an existing record

After a successful signature probe, the scanner calls:

```text
Find_Record_By_Base
```

This comparison is based on `NIC_IO_BASE`.

If a record already exists for that base, the scanner does not create another
one.

Instead it refreshes:

* `NIC_PRODUCT_ID`
* `NIC_ASIC_REV`

and sets:

```text
NIC_FLAG_ACTIVE
```

This is the normal path for an adapter that was discovered through the ID port
and then successfully activated.

## Creating an active-only record

If no existing record uses the responding I/O base, the scanner creates a new
record with:

```text
Build_Record_From_Active
```

This handles an adapter that is already active even though it did not become a
normal record through the preceding ID-port discovery phase.

The record begins with:

* known active I/O base
* product ID from the live signature probe
* ASIC revision from the live signature probe
* tag `0`
* ID mode `0`
* `NIC_FLAG_ACTIVE`

It then reads the persistent values required to complete the record:

* Address Configuration word `08h`
* Resource Configuration word `09h`
* OEM node address words `0Ah` through `0Ch`

From those values it derives:

* normalized IRQ
* transceiver selection
* OEM MAC address

## Mandatory EEPROM read failures

Record construction from an active adapter requires the configuration and OEM
EEPROM reads above to succeed.

If one of those reads fails, `Build_Record_From_Active` returns failure.

The incomplete record is not counted.

This is intentional.

A hardware read error must not be converted into apparently valid
configuration data by substituting a value such as `FFFFh`.

`FFFFh` is also a valid EEPROM data word and cannot be used as an error
sentinel.

The EEPROM error contract is documented further in
[`BACKEND.md`](BACKEND.md) and
[`LOW_LEVEL_CONVENTIONS.md`](LOW_LEVEL_CONVENTIONS.md).

# How records converge

The three stages are designed to converge on one final table.

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
             +-----------+-----------+
             |                       |
          failure                   success
             |                       |
             v                       v
     remains FROM_ID          FROM_ID | ACTIVE
                                     |
                              active-base scan
                                     |
                                     v
                          refresh live identity
```

An adapter found only through the final active scan looks different:

```text
                 active-base scan
                        |
                 signature valid
                        |
              no record at this base
                        |
                        v
                +------------------+
                | active-only      |
                | ACTIVE           |
                | FROM_ID clear    |
                | tag = 0          |
                +------------------+
```

Both are valid `nic_table` entries.

They simply tell the rest of the application different things about how much
is known about the adapter.

# Identity, configuration and activity are different things

Discovery deliberately keeps several concepts separate.

They must not be collapsed into one test.

## Identity

The ID-port path can establish that a supported 3C509-family adapter exists
and recover its persistent identity.

This is represented by `NIC_FLAG_FROM_ID` and the stored ID tag.

## Configured I/O base

`NIC_IO_BASE` describes the ISA base derived from the adapter's configuration
or the base at which the active adapter was found.

A nonzero value does not by itself prove that the adapter is currently
responding there.

## Active accessibility

`NIC_FLAG_ACTIVE` means that the adapter has been established as accessible
through an active ISA base.

Later code that requires normal register access must use the active state, not
merely assume that a record containing an I/O base is live.

This distinction matters to `CONFIGURE`, capability reads, extended
information, verification, and other hardware-facing operations.

# Discovery versus revalidation

Initial discovery and later selected-adapter revalidation are related but are
not the same operation.

Discovery builds the candidate table.

Once `CONFIGURE` selects a particular record, later code may revalidate that
specific adapter before modifying it.

The purpose of revalidation is to make sure that the adapter selected from the
discovery result is still the adapter the transaction is about to operate on.

It should not be replaced by another complete enumeration pass inside an
individual configuration property handler.

The transaction and selected-adapter revalidation flow is documented in
[`TRANSACTIONS.md`](TRANSACTIONS.md).

# Discovery and the backend boundary

Most of the discovery algorithm lives in common code.

Examples include:

* scan coordination
* manufacturer validation
* product-family validation
* contender EEPROM interpretation
* duplicate identity handling
* provisional record construction
* active-base table scanning
* record merging

The backend supplies the actual hardware operations required by those
algorithms.

Some operations, notably `Nic_Activate_Tagged_Cards`, sit at a somewhat higher
level because the physical and mock activation mechanisms differ enough to
justify a common backend entry point.

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
* Tagged-card activation happens before the final active-base scan.
* ID-port discovery and active-base scanning are complementary, not competing
  discovery implementations.
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
* active-base duplicate suppression uses I/O base.
* ID-discovered records retain their tag and ID sequence mode.
* active-only records use tag zero unless later architecture deliberately
  establishes an ID-port identity for them.
* ASIC revision remains `FFh` in a provisional ID record until active hardware
  has provided a real value.
* successful active-base signature results should be reused rather than
  immediately reprobed without need.
* mandatory EEPROM read failure must abort active record construction.
* EEPROM data values, including `FFFFh`, must not be confused with read
  failure.
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

