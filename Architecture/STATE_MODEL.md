# Hardware State Model

## Purpose

A 3C509/3C509B does not have one single configuration state.

Several related forms of state exist at the same time:

* persistent configuration stored in EEPROM
* live ASIC/register state
* ISA activation and ID-port state
* physical state such as whether an Option ROM is actually installed
* `3CCFGCLI`'s own in-memory snapshot and prospective transaction state
* cached discovery information in `nic_table`

These states are related, but they are not interchangeable.

In particular:

**EEPROM must not be treated as a continuously mirrored copy of the live
registers.**

Writing persistent configuration does not automatically mean that the
corresponding live hardware state changed at the same moment.

Likewise, changing a live register does not automatically update EEPROM.

A significant part of the `CONFIGURE` architecture exists specifically to
keep these states synchronized where the original utility requires it.

## State model at a glance

```text id="i8tr2f"
                    persistent configuration
                         EEPROM words
                              |
                              |
                  reset / automatic configuration
                  loads selected persistent fields
                              |
                              v
                  +-------------------------+
                  |      live ASIC state    |
                  |                         |
                  | Window 0 configuration  |
                  | Window 3 configuration  |
                  | Window 4 control state  |
                  | current register window |
                  +-------------------------+
                       ^              |
                       |              |
          direct register writes      |
                       |              |
                       |              v
                  +-------------------------+
                  | ISA / ID-port state     |
                  |                         |
                  | active or inactive      |
                  | active I/O base         |
                  | tag / ID state          |
                  +-------------------------+


              3CCFGCLI CONFIGURE transaction
                         |
                         v
              +-------------------------+
              | current snapshot        |
              |                         |
              | old EEPROM words        |
              | old live registers      |
              | old active I/O base     |
              +-------------------------+
                         |
                         | exact copy
                         v
              +-------------------------+
              | prospective state       |
              |                         |
              | new EEPROM words        |
              | new live registers      |
              | new active I/O base     |
              +-------------------------+
                         |
                 merge requested fields
                         |
                         v
              validate -> commit -> verify
```

The transaction does not modify hardware while building the prospective
image.

It first establishes what the final state should look like.

Only after validation and change detection does the commit path begin.

# Persistent EEPROM state

## What persistent means

EEPROM contains configuration that survives normal program termination and
machine power cycles.

It is the persistent configuration source for settings such as:

* ISA I/O base
* IRQ
* transceiver selection
* Boot ROM mapping
* Plug and Play policy
* MODEM interrupt-disable timing
* software optimization
* Full Duplex policy
* Boot ROM Size Valid and revision information
* EEPROM checksums

The exact ownership of individual EEPROM words and fields is documented in
[`EEPROM.md`](EEPROM.md).

The important state-model rule is that EEPROM describes persistent
configuration.

It does not necessarily describe what every live ASIC register contains at
this exact instant.

## EEPROM is authoritative only where the architecture says it is

Different configuration properties have different relationships with live
state.

Some have both persistent and immediate live representations.

Some are currently treated as persistent-only settings.

Some persistent values are loaded into live state during reset or automatic
configuration.

Some live settings require an explicit register write after the EEPROM commit.

Do not invent a general rule such as:

```text id="vw4ohf"
write EEPROM
    ->
hardware automatically changes immediately
```

That rule is wrong.

# Live ASIC and register state

Live state is the configuration currently exposed by the adapter ASIC.

The parts relevant to the current implementation include, among others:

* Window 0 Address Configuration
* Window 0 Resource Configuration
* Window 0 Product ID
* the selected register window
* Window 3 Internal Configuration
* Window 4 Network Diagnostic state
* Window 4 Media Status state

The mock also models Window 2 station-address registers for architectural
completeness.

Live registers may reflect values originally loaded from EEPROM, but after
that load point they are independent hardware state.

## Window 0 Address Configuration

Window 0 Address Configuration is particularly important because it contains
live fields related to several persistent settings.

Current `CONFIGURE` code uses it for:

* the active I/O selector
* Boot ROM address and size mapping

The transaction keeps separate copies:

```text id="a8n7wh"
cfg_txn_old_word08      persistent EEPROM word 08h
cfg_txn_new_word08      prospective persistent word 08h

cfg_txn_old_live06      current live Window 0 Address Configuration
cfg_txn_new_live06      prospective live Window 0 Address Configuration
```

Even though the persistent EEPROM word and live register contain related
fields, the transaction deliberately keeps them as separate values.

That is not redundant state.

They may legitimately differ.

## Window 0 Resource Configuration

The same distinction exists for IRQ configuration.

The transaction keeps:

```text id="g5a9mf"
cfg_txn_old_word09      persistent EEPROM Resource Configuration
cfg_txn_new_word09      prospective persistent Resource Configuration

cfg_txn_old_live08      current live Window 0 Resource Configuration
cfg_txn_new_live08      prospective live Resource Configuration
```

Again, persistent IRQ and current live IRQ are separate state.

The current implementation even preserves one historical compatibility
behavior where an unchanged persistent IRQ does not automatically repair a
different live IRQ during a normal standalone `/INT` transaction.

That behavior is deliberate because the tested 0.3.3 `/INT` implementation
used the persistent EEPROM field as authoritative for the unchanged case.

During a real I/O migration, however, the live Resource Configuration must be
restored and therefore the staged IRQ is included.

## Window 3 Internal Configuration

The mock models Window 3 Internal Configuration as a live 32-bit register.

It is loaded from EEPROM words `12h` and `13h` during automatic
configuration.

It is **not continuously mirrored** from those EEPROM words.

A later EEPROM write therefore does not silently change the modeled live
Window 3 value.

This distinction was one of the reasons the original lightweight mock became
insufficient.

If the mock simply returned EEPROM contents whenever code asked for a related
live register, an implementation could accidentally depend on synchronization
that real hardware never performed.

## Window 2 station address

The mock also keeps Window 2 station-address registers separate from EEPROM
node-address words.

Automatic configuration does not load Window 2 from EEPROM in the current
model.

These registers are not currently needed by a normal `3CCFGCLI` path, but the
distinction is retained because they are live registers, not aliases into the
EEPROM array.

Do not collapse them merely because they currently contain little
application-visible behavior.

# Activation state is another state domain

An adapter can have a perfectly valid persistent configuration and still not
currently decode its configured ISA I/O address.

Activation therefore has its own state.

Relevant concepts include:

* whether the adapter is currently active
* which I/O base currently decodes the adapter
* its ID-port tag
* its current ID-port state
* whether it is participating in ID command processing

In the mock these concepts are represented separately from EEPROM and live
register contents.

Examples include:

```text id="2wuazm"
MCKRF_ACTIVE
MCK3R_ACTIVE_BASE
MCK3R_TAG
MCK3R_ID_STATE
```

The discovery-side `NIC_FLAG_ACTIVE` is the application's record of whether
the adapter was verified as currently accessible.

It is not itself the hardware state.

## Configured base versus active base

This distinction is especially important for `/IOBASE`.

There may be several different values involved during a migration:

```text id="ywrmz1"
persistent EEPROM selector
        |
        | may describe intended configuration
        v

live Window 0 Address Configuration selector
        |
        | current ASIC configuration
        v

active ISA decode base
        |
        | address currently responding on the bus
        v

NIC_IO_BASE in nic_table
        |
        | application record used for subsequent access
        v
```

Normally these converge.

During a transaction they do not necessarily change at the same instant.

The I/O migration code therefore manages the transition explicitly.

# Reset and automatic configuration

## Automatic configuration is a synchronization point

The mock has an explicit:

```text id="sn3y4t"
Mock_Automatic_Configuration
```

This represents the documented point where selected persistent EEPROM fields
are loaded into live configuration.

The current model loads:

```text id="u5ipyi"
EEPROM word 03h -> Window 0 Product ID
EEPROM word 08h -> Window 0 Address Configuration
EEPROM word 09h -> Window 0 Resource Configuration
EEPROM word 12h -> Window 3 Internal Configuration low word
EEPROM word 13h -> Window 3 Internal Configuration high word
```

It also restores configuration-facing reset state such as:

* register window 0
* cleared command-busy state
* cleared EEPROM operation state
* reset Window 4 writable control state
* reset Option ROM page
* cleared modeled coax-start state

It does not load Window 2 station-address registers from EEPROM.

The purpose of this routine is not convenience.

It establishes a specific synchronization event between persistent and live
state.

## Reset is not continuous synchronization

The existence of automatic configuration must not be misunderstood as:

```text id="xu1jci"
EEPROM changes
     |
     v
Mock_Automatic_Configuration automatically runs
```

It does not.

EEPROM can change while the related live state remains unchanged.

Automatic configuration happens only when the modeled hardware transition
calls for it.

## Reset also affects activation state

`Mock_Reset_Loaded_Record` represents the configuration-facing
power-on-reset state of an adapter.

It clears:

* active ISA decode
* active base
* tag
* current ID shift state

and then performs automatic configuration.

Command-register Global Reset and ID-port Global Reset both use this reset
machinery in the mock, although the callers decide which adapters receive the
reset.

The two reset mechanisms must still be kept conceptually distinct because one
is an addressed command-register operation and the other is an ID-port bus
command.

## Process startup is not a hardware reset

Loading `3CHWMOCK.EXE` for another DOS invocation must not silently reset every
mock adapter.

The mock file stores persistent modeled hardware state between program runs.

A new host process loading the file is not equivalent to power cycling the
adapter.

This matters because otherwise tests would be unable to reproduce stale live
state, activation state, or other conditions that can persist across separate
utility invocations.

# Why CONFIGURE snapshots both persistent and live state

`Cfg_Txn_Read_Current` does not read only the EEPROM fields being changed.

For transactions involving hardware changes, it also snapshots live Window 0
Address Configuration and Resource Configuration.

This is required because the deactivate/reactivate path can disturb live
state.

The transaction therefore needs enough information to restore fields that were
not requested to change.

## Current transaction snapshot

The current state is stored in variables such as:

```text id="i1sv5h"
cfg_txn_old_word08
cfg_txn_old_word09
cfg_txn_old_word0d
cfg_txn_old_word13
cfg_txn_old_word14
cfg_txn_old_word0f

cfg_txn_old_live06
cfg_txn_old_live08

cfg_txn_old_base
```

Not every transaction needs every EEPROM word.

Only the persistent values required by the requested properties and their
validation/checksum requirements are read.

The live Window 0 Address and Resource Configuration words are both captured
for hardware transactions because ISA reactivation may require the complete
live image to be restored.

# Prospective transaction state

After the snapshot is complete:

```text id="93j1fw"
Cfg_Txn_Init_Prospective
```

copies the current values into the prospective image.

Conceptually:

```text id="zl4566"
old persistent state ------+
                           |
                           +---- exact copy ----> new persistent state

old live state ------------+
                           |
                           +---- exact copy ----> new live state

old active base -----------+
                           |
                           +---- exact copy ----> new active base
```

Only then are requested property fields merged into the `new` values.

## Preparation must not touch hardware

Procedures such as:

```text id="d5nxu6"
Cfg_Prepare_IOBASE
Cfg_Prepare_INT
Cfg_Prepare_PNP
Cfg_Prepare_MODEM
Cfg_Prepare_FULLDUPLEX
Cfg_Prepare_OPTIMIZE
Cfg_Prepare_Boot_ROM
Cfg_Prepare_TR
```

operate on the prospective image.

They do not commit hardware changes.

This is important because multiple properties may share one EEPROM word or
live register.

For example:

```text id="xqt9gt"
                   EEPROM word 08h
                         |
        +----------------+----------------+
        |                |                |
      IOBASE          Boot ROM            TR
```

The transaction can merge all requested changes into one prospective word
before anything is written.

The same principle applies to EEPROM word `0Dh`.

# CONFIGURE state transition

The high-level state transition looks like this:

```text id="dylj6w"
            read persistent + live current state
                         |
                         v
                 current snapshot
                         |
                         v
                exact prospective copy
                         |
                         v
              merge requested properties
                         |
                         v
             validate combined final state
                         |
                         v
       temporarily probe Boot ROM if requested
              |                     |
           valid                  invalid
              |                     |
              |              restore live mapping
              |              reject ROM portion
              +----------+----------+
                         |
                         v
                   detect changes
                         |
                         v
                       preflight
                         |
                         v
              optional deactivate /
                 retag / activate
                         |
                         v
                  write EEPROM
                         |
                         v
              synchronize live state
                         |
                         v
                 verify committed state
                         |
                         v
              synchronize Full Duplex
                  live policy bit
```

The exact transaction mechanics are documented in
[`TRANSACTIONS.md`](TRANSACTIONS.md).

The state model matters here because each phase owns a different type of
change.

# Deactivate and reactivate behavior

Some configuration operations require the selected adapter to be deactivated
and reactivated through the 3Com ID port.

The current flow is particularly relevant for `/IOBASE`.

`Cfg_Txn_Activate_If_Needed`:

1. deactivates the selected tagged adapter
2. verifies disappearance from the old base when performing an actual
   migration
3. retags the selected adapter
4. changes the selected `nic_table` record to the prospective new base exactly
   once, immediately before activation
5. activates the adapter at that base
6. restores the complete prospective live Window 0 Address Configuration
7. restores the complete prospective live Window 0 Resource Configuration
8. verifies that the adapter is reachable and that the required live fields
   survived

This happens **before** the persistent EEPROM write phase.

That order can look surprising if only the EEPROM values are considered.

It makes sense once reset and live state are treated separately.

## Why live Window 0 must be restored

The ID-port deactivation sequence resets configuration-facing hardware state.

At that point the hardware may have reloaded live configuration from the
currently persistent EEPROM values.

But the transaction has not yet written the new persistent values.

Therefore the activation path explicitly restores the prospective live
Address Configuration and Resource Configuration before continuing.

Conceptually:

```text id="75imgd"
old EEPROM
    |
    | reset during deactivate
    v
live state reloaded from old persistent configuration
    |
    | reactivate
    v
explicitly restore prospective live06/live08
    |
    v
adapter reachable with intended live state
    |
    v
commit new persistent EEPROM configuration
```

Without this distinction, an I/O migration could easily lose the new live
base or accidentally change an unrelated live IRQ.

# Property-specific state behavior

Not every configuration property uses the same synchronization rules.

The current model is approximately:

| Property              | Persistent state                                        | Immediate live state                                                  |
| --------------------- | ------------------------------------------------------- | --------------------------------------------------------------------- |
| `/IOBASE`             | EEPROM word `08h`                                       | Window 0 Address Configuration plus active ISA decode migration       |
| `/INT`                | EEPROM word `09h`                                       | Window 0 Resource Configuration                                       |
| `/PNP`                | EEPROM word `13h`                                       | No direct live synchronization in the current transaction             |
| `/MODEM`              | EEPROM word `0Dh`                                       | No direct live synchronization in the current transaction             |
| `/OPTIMIZE`           | EEPROM word `0Dh`                                       | No direct live synchronization in the current transaction             |
| `/FULLDUPLEX`         | EEPROM word `0Dh` bit 15                                | Window 4 Network Diagnostic Full Duplex bit                           |
| `/BADDRESS`, `/BSIZE` | EEPROM word `08h`, plus Boot ROM Size Valid in word `14h` | Window 0 Address Configuration Boot ROM mapping                       |
| `/TR`                 | EEPROM word `08h`                                       | No direct live transceiver synchronization in the current transaction |

This table describes the current implementation.

It must not be generalized into a rule that every persistent property should
gain a live write.

If compatibility work later establishes different original hardware behavior,
the transaction model should be changed deliberately and tested accordingly.

# Full Duplex is explicitly dual-state

Full Duplex is a particularly clear example of why persistent and live state
must be separated.

Persistent policy is stored in EEPROM Software Information word `0Dh`,
bit 15.

The currently effective hardware control is represented by the Full Duplex bit
in Window 4 Network Diagnostic.

After persistent transaction verification,
`Cfg_Txn_Sync_Live_FullDuplex` compares the requested persistent policy with
the live Window 4 bit.

If necessary, it updates the live register and reads it back.

Importantly, this synchronization can also happen when the EEPROM setting was
already correct and therefore no persistent write was needed.

This allows:

```text id="724l2c"
persistent EEPROM: ENABLED
live hardware:      DISABLED
```

to be repaired by an explicit:

```text id="4fwcvr"
/FULLDUPLEX:ENABLED
```

request.

This is intentionally different from the preserved standalone `/INT`
unchanged behavior.

Do not assume all properties share one generic "unchanged means do nothing"
rule.

# Boot ROM state has an additional physical layer

Boot ROM support introduces another useful distinction.

There are at least three separate concepts:

```text id="serxi1"
persistent EEPROM Boot ROM configuration
                  |
                  v
live Window 0 ROM mapping
                  |
                  v
actual ROM contents physically available
```

A configured ROM address does not prove that a valid Option ROM is installed.

Likewise, an installed ROM cannot be read through the adapter unless the live
ROM aperture is currently mapped appropriately.

## Mock physical ROM state

The mock therefore stores a separate synthetic installed-ROM size.

This represents whether a physical ROM exists in the modeled adapter.

It is not derived from EEPROM Boot ROM configuration.

The synthetic ROM contents can then be accessed only through the modeled live
ROM aperture and page state.

## Temporary pre-commit ROM mapping

For an enabled Boot ROM request,
`Cfg_Txn_Probe_Boot_ROM` temporarily changes only the Boot ROM fields of the
live Window 0 Address Configuration.

It preserves the current I/O selector and other unrelated live fields.

The requested mapping is then used to probe the actual ROM contents.

After the probe, the previous live Address Configuration is restored before
the transaction continues.

Conceptually:

```text id="vamhww"
old live mapping
       |
       v
temporary prospective ROM mapping
       |
       v
probe ROM signature / size / checksum / paging
       |
       v
restore old live mapping
```

If the ROM probe fails, the Boot ROM portion of the prospective persistent and
live state is restored to the previous values and that part of the request is
marked rejected.

The live mapping must not remain modified merely because probing required
temporarily enabling it.

## Committed Boot ROM mapping

If the request is accepted and persistent state changes,
`Cfg_Txn_Write_Live` later writes the prospective live Address Configuration
so the Boot ROM mapping takes effect without requiring a machine reset.

Verification compares only the Boot ROM-owned live bits against the
prospective image.

It does not treat the whole shared Address Configuration register as belonging
to the Boot ROM request.

# The in-memory NIC record is not hardware state

`nic_table` is a discovery and selection structure.

It contains useful cached information such as:

* product ID
* ASIC revision
* MAC address
* IRQ
* configured/current I/O base used by the application
* ID tag
* discovery state flags

It must not be treated as an authoritative copy of every EEPROM or live
register.

For configuration transactions, relevant hardware state is read again.

This is particularly important because hardware may have changed since the
initial discovery pass.

## Record updates during CONFIGURE

Some record fields have to change as part of successful configuration.

The I/O base is special because activation at the new address requires the
selected record to contain the new base before
`Cfg_Id_Activate_Selected` is called.

The migration code therefore changes `NIC_IO_BASE` at one controlled point in
the activation sequence.

IRQ record state is updated only after the transaction has completed
successfully.

These record changes exist so subsequent application code addresses the
correct adapter.

They are not a replacement for persistent and live verification.

# The mock state file

`3C509B.MCK` contains more than EEPROM contents.

It persists enough modeled state to allow separate utility invocations to
continue operating on the same virtual adapters.

A mock record includes state such as:

* persistent EEPROM
* current live Window 0 configuration
* current live Window 3 configuration
* selected register window
* active base
* activation flags
* tag and ID state
* EEPROM command state
* Window 4 state
* Option ROM size and page

This is deliberate.

If the file stored only EEPROM and recreated every live register from it
whenever `3CHWMOCK.EXE` started, many important real-hardware state bugs would
again become impossible to reproduce.

# State ownership

A useful rule when modifying the program is to ask:

```text id="4452a3"
Who owns this value?
```

Possible answers include:

```text id="8zauuh"
EEPROM
    persistent adapter configuration

live ASIC register
    current hardware behavior

ID-port / activation state
    current bus visibility and adapter selection

physical device state
    installed Option ROM, actual hardware capability

transaction snapshot
    immutable view of what CONFIGURE observed before modification

transaction prospective image
    desired final state if the transaction commits

nic_table
    application discovery and selection metadata

mock file
    persistence container for the modeled adapter
```

A value should not silently migrate from one category into another merely
because doing so simplifies an implementation.

# State-model invariants

The following rules should remain true when modifying this part of the
project:

* EEPROM and live ASIC registers are separate state domains.
* An EEPROM write must not be assumed to update a corresponding live register
  immediately.
* A live register write must not be assumed to update EEPROM.
* Automatic configuration is an explicit synchronization point, not a
  continuous mirror.
* Starting a new mock process is not itself a hardware reset.
* Reset and activation state are distinct from persistent EEPROM state.
* Configured I/O base, live Address Configuration, active ISA decode, and
  `NIC_IO_BASE` are related but not identical concepts.
* `NIC_FLAG_ACTIVE` describes verified application-visible accessibility; it is
  not itself the physical activation state.
* `nic_table` is cached application metadata, not the authoritative hardware
  configuration image.
* CONFIGURE reads the required current hardware state again before committing.
* Prospective state begins as an exact copy of the current snapshot.
* Prepare routines modify only their owned fields in prospective state.
* Prepare routines must not perform hardware writes.
* Shared EEPROM words and live registers must use read-modify-write semantics
  so unrelated fields survive.
* Reset/deactivate/reactivate paths must preserve or explicitly restore live
  state that is not supposed to change.
* Persistent and live verification must be performed according to the
  semantics of the individual property, not through one generic assumption.
* Full Duplex remains explicitly represented by both persistent policy and live
  hardware state.
* The preserved standalone `/INT` unchanged behavior must not accidentally be
  replaced by Full Duplex-style stale-live repair.
* Boot ROM EEPROM configuration, live ROM mapping, and actual ROM presence are
  separate things.
* Temporary Boot ROM probing must restore the previous live mapping before
  proceeding.
* The mock must persist live state where real hardware can retain live state
  across separate utility invocations.
* Do not make the mock continuously derive live registers from EEPROM just
  because both values happen to match after reset.

The central rule is therefore simple:

```text id="v3w16i"
Persistent configuration tells us what the adapter is configured to use.

Live state tells us what the adapter is doing now.

Those are often the same.

But the architecture must never depend on them always being the same.
```

The transaction machinery that coordinates changes between these states is
documented in [`TRANSACTIONS.md`](TRANSACTIONS.md).

