# CONFIGURE Transaction Architecture

## Purpose

All supported hardware-changing `CONFIGURE` properties are committed through
one centralized staged transaction facility.

Individual property handlers do not own their own EEPROM write sequences,
activation logic, checksum handling, live-register updates, or verification.

Instead, the transaction follows one common model:

```text id="zjhe4h"
parse requested properties
        |
        v
discover and select adapter
        |
        v
revalidate selected adapter
        |
        v
parse and stage property values
        |
        v
capability gates
        |
        v
read current hardware state
        |
        v
build prospective state
        |
        v
validate combined prospective state
        |
        v
detect actual changes
        |
        v
preflight
        |
        v
activate / migrate if required
        |
        v
write persistent EEPROM
        |
        v
synchronize live state
        |
        v
verify
        |
        v
post-commit live Full Duplex synchronization
        |
        v
report success
```

This architecture exists because several `CONFIGURE` properties share the
same EEPROM words and some changes affect both persistent and live hardware
state.

The transaction must therefore reason about the requested configuration as a
whole.

No property owns another property's transaction logic.

# What "transaction" means here

The word transaction in `Cfg_Txn_*` means:

**stage the complete requested state before committing it through one
centralized path.**

It does **not** mean an ACID transaction with automatic rollback.

Before the commit phase, the transaction is deliberately read-only except for
temporary Boot ROM mapping used by the ROM probe, which is restored before
continuing.

Once activation or persistent writes begin, however, there is no general
rollback mechanism.

For example:

```text id="eld7r6"
deactivate adapter
        |
        v
reactivate at new base
        |
        v
write EEPROM word 08h
        |
        v
write EEPROM word 0Dh
        |
        v
checksum update fails
```

At that point some hardware state may already have changed.

The transaction reports the failure, but it does not attempt to reconstruct
and restore every previously written state.

This distinction is important for maintainers and coding agents.

Do not assume that because a function is called `Cfg_Txn_Execute`, every
failure leaves the adapter exactly as it was before the command.

# Why configuration is centralized

The centralized transaction solves several problems that would otherwise
appear in individual property handlers.

## Shared EEPROM words

Several properties share one persistent word.

For example:

```text id="bf0leu"
                       EEPROM word 08h
                             |
            +----------------+----------------+
            |                |                |
          IOBASE          Boot ROM            TR
```

and:

```text id="fjkeu4"
                       EEPROM word 0Dh
                             |
            +----------------+----------------+
            |                |                |
          MODEM         FULLDUPLEX        OPTIMIZE
```

If every property wrote its own complete word independently, combined commands
could overwrite bits staged by another property.

Instead, the transaction reads each required word once into the current
snapshot, copies it to the prospective image, and lets each property modify
only its own bits.

## Combined validation

Some properties cannot be validated correctly in isolation.

For example:

```text id="n2k66d"
FULLDUPLEX:ENABLED
```

is valid only when the **effective final transceiver state** is TP.

That effective state may come from:

* the current persistent configuration
* a simultaneous `/TR:TP`
* a simultaneous `/TR:AUI`
* a simultaneous `/TR:COAX`
* a simultaneous `/TR:AUTO`

Validation must therefore happen after all requested properties have been
merged into one prospective image.

## Shared activation and migration

Changing the I/O base requires more than an EEPROM write.

The selected adapter may have to be:

* deactivated
* retagged
* assigned a new application-visible base
* reactivated
* have live Window 0 state restored
* checked at the new address
* then have persistent state committed

That sequence belongs to the transaction, not the `/IOBASE` parser.

# CONFIGURE before the transaction

`Cfg_Txn_Execute` is not the first thing `Cmd_Configure` does.

Several important steps happen before the transaction itself starts.

## Initial CONFIGURE state

At command entry, `Cmd_Configure` clears the previous command state, including:

```text id="vdk3k5"
cfg_adapter_ordinal
cfg_parse_flags
cfg_seen_flags
cfg_property_count
cfg_last_error
cfg_timeout_latched
cfg_selected_ptr
```

Each `CONFIGURE` invocation therefore begins with a fresh parser and
transaction context.

# First parse pass

## Parse the complete command before discovery

`Cfg_Parse_Options` first parses the complete CONFIGURE argument list.

This happens before adapter discovery.

The parser validates the structural form of every option:

```text id="1xtge5"
/PROPERTY:VALUE

or

-PROPERTY=VALUE
```

and rejects:

* unknown properties
* missing values
* malformed `ADAPTERNUM`
* duplicate properties

This ensures that a bad property later on the command line is not hidden by an
earlier valid one.

## `ADAPTERNUM` is not a hardware property

`ADAPTERNUM` is parsed immediately because it only selects a logical record.

It is not added to the hardware property request queue.

The hardware properties are stored in:

```text id="18jogp"
cfg_property_requests
```

which retains the original command-line order.

The current maximum number of hardware property requests is nine, matching the
supported property set.

## Duplicate tracking is separate from accepted staged state

The parser uses:

```text id="g1iz3j"
cfg_seen_flags
```

for strict single-occurrence validation.

This state is intentionally separate from:

```text id="g42arb"
cfg_parse_flags
```

The distinction is:

```text id="ns79bz"
cfg_seen_flags
    property appeared syntactically on the command line

cfg_parse_flags
    property value was successfully parsed and staged
```

This prevents duplicate detection from depending on whether a property
handler later accepts its value.

`/TR` and its `/XCVR` alias resolve to the same canonical property before
duplicate tracking, so they cannot both be specified as if they were different
properties.

# Discovery, selection and revalidation

After the first parse pass succeeds, `Cmd_Configure` performs the same complete
adapter discovery used by `LIST`:

```text id="ly20el"
Scan_All_3Com_Cards
```

There is no separate CONFIGURE-only scanner.

Discovery architecture is documented in
[`DISCOVERY.md`](DISCOVERY.md).

## Adapter selection

`Cfg_Resolve_Adapter` resolves the requested logical adapter against the exact
`nic_table` order produced by discovery.

Current behavior is:

```text id="2f05ah"
one adapter
    ADAPTERNUM may be omitted
    defaults to adapter 1

multiple adapters
    ADAPTERNUM is required
```

The resulting record pointer is stored in:

```text id="qoou4f"
cfg_selected_ptr
```

## Revalidation

Before property values are dispatched, the selected record is revalidated by:

```text id="wfj716"
Cfg_Revalidate_Selected
```

An active record is checked through:

* active 3Com signature
* product ID
* ASIC revision where known
* OEM node address read from EEPROM

An inactive ID-port record can instead be revalidated read-only through its
existing ID tag and ID-port identity.

This protects CONFIGURE from blindly trusting a record created during an
earlier discovery step.

Revalidation is not itself permission to configure an inactive adapter.

The later current-state read phase still rejects hardware-changing
transactions when the selected record is not active.

# Second parse stage: property handlers

Once the adapter has been selected and revalidated,
`Cfg_Dispatch_Parsed_Properties` dispatches the queued property requests in
their original command-line order.

The current handlers are:

```text id="9i7kk6"
Cfg_Handle_INT
Cfg_Handle_IOBASE
Cfg_Handle_BADDRESS
Cfg_Handle_BSIZE
Cfg_Handle_TR
Cfg_Handle_MODEM
Cfg_Handle_OPTIMIZE
Cfg_Handle_PNP
Cfg_Handle_FULLDUPLEX
```

The handlers validate and normalize the property values.

They store results in variables such as:

```text id="b6l93j"
cfg_int_value
cfg_iobase_value
cfg_pnp_value
cfg_modem_value
cfg_fullduplex_value
cfg_optimize_value
cfg_baddress_value
cfg_bsize_value
cfg_bsize_disabled
cfg_tr_value
```

and set the corresponding `CFG_PARSE_*` bit.

They do not perform hardware configuration.

## Property handlers must remain hardware-free

The architectural contract for property handlers is:

```text id="3x7xmb"
text input
    |
    v
validate syntax / value
    |
    v
normalize representation
    |
    v
store staged property value
```

Not:

```text id="bi57wy"
text input
    |
    v
write EEPROM
```

A handler error stops later handlers, matching the retained original property
dispatch behavior.

Once all handlers succeed, `Cmd_Configure` enters the centralized transaction
through:

```text id="h0r972"
Cfg_Txn_Execute
```

# Transaction overview

The current execution path can be summarized as:

```text id="bl9r2f"
Cfg_Txn_Execute
       |
       +--> capability gates
       |
       +--> requested-value reporting
       |
       +--> Cfg_Txn_Read_Current
       |
       +--> Cfg_Txn_Init_Prospective
       |
       +--> Cfg_Prepare_*
       |
       +--> Cfg_Validate_FD_Transceiver
       |
       +--> Cfg_Txn_Probe_Boot_ROM
       |
       +--> Cfg_Txn_Detect_Changes
       |
       +--> no change?
       |       |
       |       +--> possibly synchronize live Full Duplex
       |       +--> success
       |
       +--> Cfg_Txn_Preflight
       |
       +--> Cfg_Txn_Activate_If_Needed
       |
       +--> Cfg_Txn_Write_EEPROM
       |
       +--> Cfg_Txn_Write_Live
       |
       +--> Cfg_Txn_Verify
       |
       +--> Cfg_Txn_Sync_Live_FullDuplex
       |
       +--> update cached record state
       |
       +--> report success
```

# Validation happens in layers

There is intentionally no single "validate everything" procedure.

Different validation belongs at different points.

The current layers are:

| Stage                     | What is validated                                                                    |
| ------------------------- | ------------------------------------------------------------------------------------ |
| First parse pass          | option syntax, separators, missing values, duplicate properties, `ADAPTERNUM` syntax |
| Property handlers         | property-specific value syntax and normalization                                     |
| Capability gate           | whether the selected physical adapter supports the requested operation               |
| Current-state read        | whether required persistent/live state can be read and whether the adapter is active |
| Prepare phase             | encoding constraints that depend on the adapter generation or staged values          |
| Combined-state validation | relationships between multiple prospective properties                                |
| Boot ROM probe            | whether an enabled requested mapping exposes a valid physical Option ROM             |
| Change detection          | whether anything actually differs                                                    |
| Preflight                 | resource conflicts and required activation capability                                |
| Verification              | whether committed persistent/live state matches the prospective state                |

Putting a check in the wrong phase can change command semantics.

For example, a cross-property FULLDUPLEX/TR test cannot be correctly performed
inside either individual parser because the final effective state is not known
yet.

# Capability gate phase

`Cfg_Txn_Execute` begins with capability checks for properties whose validity
depends on the selected hardware.

The current gated properties are:

* `/PNP`
* `/FULLDUPLEX`
* `/BADDRESS`
* `/BSIZE`
* `/TR`

These checks happen before any:

```text id="cb68ie"
"... parameter accepted ..."
```

message is printed.

A request that is not supported by the selected adapter therefore fails
without first telling the user that it was accepted.

## PNP gate

`/PNP` uses the normalized capability result from:

```text id="p8cjb4"
Nic_Read_Capabilities
```

Both the validity of the PNP capability source and the capability bit itself
must be present.

## Full Duplex gate

`/FULLDUPLEX` similarly requires a valid Full Duplex capability result and the
normalized Full Duplex capability bit.

## Boot ROM gate

Boot ROM requests have several checks before staging.

The pairing rule is:

```text id="em6j89"
enable Boot ROM:
    /BADDRESS + /BSIZE:8|16|32

disable Boot ROM:
    /BSIZE:DISABLED alone
```

`/BADDRESS` without an enabled size is incomplete.

`/BSIZE:8|16|32` without `/BADDRESS` is incomplete.

`/BADDRESS` combined with `/BSIZE:DISABLED` is also invalid.

The gate also reads EEPROM Revision Information word `14h`.

That read is reused later as:

```text id="c1hi3o"
cfg_txn_old_word14
```

rather than reading the same word a second time during
`Cfg_Txn_Read_Current`.

The low revision byte is also used to derive:

```text id="9rnhdo"
cfg_txn_later_card
```

for Boot ROM encoding rules.

The current TPO/later-card restriction is applied here.

## Transceiver gate

`/TR` is validated against the normalized connector capability set.

TP requires TP capability.

AUI requires AUI capability.

COAX requires BNC capability.

AUTO requires more than one available connector.

The details of capability derivation belong in
[`CAPABILITIES.md`](CAPABILITIES.md).

# Requested-value reporting

Only after the capability gates succeed does `Cfg_Txn_Execute` print the
normal accepted parameter messages.

This reporting means:

```text id="ukb7dw"
the requested value was syntactically accepted
and its immediate hardware capability gate passed
```

It does **not** mean:

```text id="1shlfr"
the change has already been written
```

Later current-state reads, combined validation, resource preflight, writes, or
verification can still fail.

# Reading the current state

`Cfg_Txn_Read_Current` snapshots the hardware state required by the requested
transaction.

No hardware modification should occur in this phase.

## Active adapter requirement

The transaction currently requires an active record for every supported
hardware-changing property.

If the selected record is not marked active, a property-specific inactive
error is returned.

This is separate from revalidation.

An inactive ID-port record may be proven to still represent the same card, but
the current CONFIGURE implementation still requires normal active hardware
access before proceeding.

## Persistent state is read on demand

Not every transaction reads every EEPROM word.

The current logic reads only what is required by the requested properties or
their cross-property validation.

| EEPROM state | Read when needed by                                        |
| ------------ | ---------------------------------------------------------- |
| word `08h`   | IOBASE, Boot ROM, TR, or FULLDUPLEX transceiver validation |
| word `09h`   | INT                                                        |
| word `0Dh`   | MODEM, FULLDUPLEX, OPTIMIZE, or TR/FULLDUPLEX interaction  |
| word `13h`   | PNP                                                        |
| word `14h`   | Boot ROM, already cached by the capability gate            |
| word `0Fh`   | transactions that may require the primary checksum domain  |

A PNP-only transaction does not require EEPROM word `0Fh`, because PNP belongs
to the secondary checksum domain.

## Live Window 0 state is always captured

For a hardware transaction, both live Window 0 configuration words are read:

```text id="81x38u"
EL3_W0_ADDRESS_CFG
EL3_W0_RESOURCE_CFG
```

and stored as:

```text id="pzg8t1"
cfg_txn_old_live06
cfg_txn_old_live08
```

This is intentional even when the requested property does not directly modify
both registers.

The original ISA deactivate/reactivate sequence restores Address Configuration
and Resource Configuration together.

The transaction therefore needs a complete live image available in case an
activation path is later required.

## Derived current values

The snapshot also derives convenient current fields such as:

```text id="m7dwn7"
cfg_txn_old_io_selector
cfg_txn_live_io_selector
cfg_txn_old_irq
cfg_txn_live_irq
```

These are diagnostic and comparison values derived from the raw snapshot.

The raw words remain the authoritative transaction images.

# Prospective state initialization

After the current snapshot succeeds:

```text id="2f6xno"
Cfg_Txn_Init_Prospective
```

copies every current transaction field into its corresponding prospective
field.

For example:

```text id="hdedp3"
cfg_txn_old_word08  -> cfg_txn_new_word08
cfg_txn_old_word09  -> cfg_txn_new_word09
cfg_txn_old_word0d  -> cfg_txn_new_word0d
cfg_txn_old_word13  -> cfg_txn_new_word13
cfg_txn_old_word14  -> cfg_txn_new_word14

cfg_txn_old_live06  -> cfg_txn_new_live06
cfg_txn_old_live08  -> cfg_txn_new_live08

cfg_txn_old_base    -> cfg_txn_new_base
```

Change flags and activation state are reset.

This exact-copy rule is fundamental.

A prospective field is not initialized from a constant, default, or decoded
property value.

It begins as the observed current state so that unrelated fields survive.

# Property preparation

The `Cfg_Prepare_*` routines merge staged property values into the prospective
image.

They do not access hardware.

## Prepare order

The current transaction prepares properties in this fixed order:

```text id="4phvik"
IOBASE
INT
PNP
MODEM
FULLDUPLEX
OPTIMIZE
Boot ROM
TR
```

This is separate from the original command-line order used during property
handler dispatch.

By the time preparation begins, all individual values have already been parsed
and staged.

## Ownership

The current prospective ownership is:

| Property   | Persistent image                               | Live image / other transaction state  |
| ---------- | ---------------------------------------------- | ------------------------------------- |
| IOBASE     | word `08h` bits `4:0`                          | live06 bits `4:0`, `cfg_txn_new_base` |
| INT        | word `09h` bits `15:12`                        | live08 bits `15:12`                   |
| PNP        | word `13h` bits `3:2`                          | none                                  |
| MODEM      | word `0Dh` bits `13:8`                         | none                                  |
| FULLDUPLEX | word `0Dh` bit `15`                            | live synchronization deferred         |
| OPTIMIZE   | word `0Dh` bits `5:4`                          | none                                  |
| Boot ROM   | word `08h` bits `13:8`, Boot ROM Size Valid in word `14h` | live06 bits `13:8`                    |
| TR         | word `08h` bits `15:14` and bit `7`            | none                                  |

Each prepare routine performs read-modify-write against the **prospective**
word.

It must not replace unrelated bits.

# IOBASE preparation

`Cfg_Prepare_IOBASE` converts the requested base into the 5-bit ISA selector:

```text id="15krw7"
selector = (IOBASE - 0200h) / 10h
```

It merges that selector into:

* prospective EEPROM word `08h`
* prospective live Window 0 Address Configuration
* prospective active base

No migration is performed at this point.

# INT preparation

`Cfg_Prepare_INT` places the requested IRQ into bits `15:12` of:

* prospective EEPROM word `09h`
* prospective live Window 0 Resource Configuration

Again, this is only staging.

# PNP preparation

`Cfg_Prepare_PNP` modifies only the PNP field in EEPROM word `13h`.

The current compatibility encoding uses:

```text id="xdzek1"
disabled -> bits 3:2 = 01b
enabled  -> bits 3:2 cleared
```

# MODEM, FULLDUPLEX and OPTIMIZE preparation

These three properties share EEPROM Software Information word `0Dh`.

Each prepare routine owns only its field:

```text id="12ds0h"
MODEM
    bits 13:8

FULLDUPLEX
    bit 15

OPTIMIZE
    bits 5:4
```

All other bits remain whatever was already present in the prospective image.

# Boot ROM preparation

`Cfg_Prepare_Boot_ROM` does more than simple bit insertion because valid ROM
selectors depend on the requested size and adapter generation.

The enabled address must be representable by the requested:

* 8 KB
* 16 KB
* 32 KB

mapping.

The routine canonicalizes the stored selector where required and rejects
invalid alignment combinations.

It merges Boot ROM address and size into bits `13:8` of:

* prospective EEPROM word `08h`
* prospective live Window 0 Address Configuration

It also clears the Boot ROM Size Valid bit in prospective EEPROM word `14h`.

For the conventional ISA configuration path supported by `3CCFGCLI`,
Boot ROM Size Valid therefore remains clear. The original 3Com utility uses
a different Boot ROM representation when a system PnP BIOS participates in
resource assignment. System PnP BIOS integration is intentionally outside
the scope of `3CCFGCLI`; see
[`DESIGN_DECISIONS.md`](../DESIGN_DECISIONS.md).

A disabled request clears the Boot ROM mapping fields.

# Transceiver preparation

`Cfg_Prepare_TR` modifies only:

* transceiver selector bits `15:14`
* AUTO select bit `7`

of prospective EEPROM word `08h`.

AUTO clears the explicit selector and sets bit `7`.

TP, AUI, and COAX clear AUTO and set their encoded selector.

The current transaction does not directly synchronize a live transceiver
register for `/TR`.

# Combined FULLDUPLEX / transceiver validation

After all prepare routines have run, the transaction performs:

```text id="2wejcw"
Cfg_Validate_FD_Transceiver
```

whenever FULLDUPLEX or TR participates.

This routine examines the **fully prepared prospective state**.

The rule is:

```text id="3aa04d"
if prospective FULLDUPLEX is ENABLED
    prospective transceiver must be explicit TP
```

Therefore:

```text id="2i5mt8"
/FULLDUPLEX:ENABLED /TR:TP
    valid

/FULLDUPLEX:ENABLED /TR:AUI
    rejected

/FULLDUPLEX:ENABLED /TR:COAX
    rejected

/FULLDUPLEX:ENABLED /TR:AUTO
    rejected
```

Likewise, changing away from TP while Full Duplex would remain enabled is
rejected.

But a combined request that also disables Full Duplex is valid.

This is exactly why cross-property validation belongs after prospective state
construction rather than inside an individual property handler.

# Pre-commit Boot ROM probe

An enabled Boot ROM request has one unusual validation step.

After prospective state construction and combined validation, but before
change detection and commit:

```text id="x00s2s"
Cfg_Txn_Probe_Boot_ROM
```

temporarily maps the requested Boot ROM aperture into live Window 0 Address
Configuration.

Only Boot ROM bits `13:8` are taken from the prospective image.

The currently active I/O selector and unrelated live bits are preserved.

The common ROM probe then validates the actual Option ROM.

## The temporary mapping is restored

After probing, the previous live Address Configuration is restored and read
back.

The probe therefore does not become the permanent live commit.

## Missing or invalid ROM is a rejected subrequest

A failed ROM-content probe is unusual because it does not automatically fail
the entire combined transaction.

Instead, the transaction:

* restores the previous Boot ROM bits in prospective EEPROM word `08h`
* restores the previous Boot ROM bits in prospective live06
* restores the previous Boot ROM Size Valid state in word `14h`
* sets `cfg_bootrom_rejected`
* reports that no valid Boot ROM was detected
* continues with any other requested properties

Conceptually:

```text id="pry87s"
combined request
    |
    +--> INT change -------- keep
    |
    +--> MODEM change ------ keep
    |
    +--> Boot ROM enable
            |
            +--> ROM invalid
                    |
                    +--> roll back only prospective Boot ROM portion
                    +--> continue transaction
```

This is a deliberate **pre-commit selective rejection**, not general
transaction rollback.

If restoring the temporary live mapping itself fails, the transaction does
fail because the hardware may have been left in an unknown live state.

# Change detection

After all requested properties have been prepared and any Boot ROM probe has
completed:

```text id="m0o2sp"
Cfg_Txn_Detect_Changes
```

compares the current and prospective images.

Change detection happens once, after all properties have been merged.

## Change flags

The transaction currently tracks:

| Flag                     | Meaning                                                                |
| ------------------------ | ---------------------------------------------------------------------- |
| `CFG_TXN_CHG_WORD08`     | persistent EEPROM word `08h` differs                                   |
| `CFG_TXN_CHG_WORD09`     | persistent EEPROM word `09h` differs                                   |
| `CFG_TXN_CHG_LIVE06`     | relevant prospective live Address Configuration differs                |
| `CFG_TXN_CHG_LIVE08`     | relevant prospective live Resource Configuration differs               |
| `CFG_TXN_MIGRATE_IO`     | active base itself changes                                             |
| `CFG_TXN_IOBASE_CHANGED` | requested IOBASE requires some form of persistent/live/base correction |
| `CFG_TXN_INT_CHANGED`    | persistent IRQ field differs                                           |
| `CFG_TXN_CHG_WORD13`     | persistent EEPROM word `13h` differs                                   |
| `CFG_TXN_CHG_WORD0D`     | persistent EEPROM word `0Dh` differs                                   |
| `CFG_TXN_CHG_WORD14`     | persistent EEPROM word `14h` differs                                   |

Some flags are raw image differences.

Others are composite transaction decisions.

# IOBASE change semantics

For an `/IOBASE` request the transaction compares:

* persistent word `08h`
* live Address Configuration
* active application base

If any relevant I/O state differs, the transaction marks:

```text id="zx1ckr"
CFG_TXN_IOBASE_CHANGED
```

This means an explicit IOBASE request can repair stale live I/O state even
when the persistent EEPROM selector is already correct.

## Migration is separate

An actual old-base to new-base move sets:

```text id="173pdf"
CFG_TXN_MIGRATE_IO
```

A transaction may therefore have:

```text id="5twhe3"
IOBASE_CHANGED = yes
MIGRATE_IO      = no
```

if the requested persistent base is already correct but related live I/O state
needs correction.

# INT unchanged compatibility behavior

INT deliberately retains an older compatibility rule from the hardware-tested
0.3.3 implementation.

For a standalone `/INT` request:

```text id="6ujl6m"
persistent EEPROM IRQ already matches
live IRQ differs
```

the transaction does **not** repair the live IRQ merely because it differs.

The persistent EEPROM field is authoritative for the unchanged decision.

This behavior is intentional.

Do not replace it with generic "repair every stale live field" logic.

## INT during IOBASE migration

There is one important exception.

If an actual I/O migration is already required, the activation sequence must
restore complete live Resource Configuration.

In that case a staged IRQ participates in the migration even when the
persistent IRQ word already contains the requested value.

This prevents migration from losing the requested live IRQ state.

# Shared-word change flags

MODEM, FULLDUPLEX, and OPTIMIZE do not each get an independent persistent
change flag.

They share:

```text id="o808qs"
CFG_TXN_CHG_WORD0D
```

because all three fields live in the same persistent word.

Likewise, TR and Boot ROM changes can contribute to:

```text id="3nb0mv"
CFG_TXN_CHG_WORD08
```

alongside IOBASE.

Verification later determines which requested property-specific bits need to
be checked.

# No-change path

After change detection, the transaction applies:

```text id="wrrxyx"
CFG_TXN_COMMIT_MASK
```

to decide whether a normal commit is required.

If there is no persistent, migration, or relevant live transaction work, the
normal hardware commit path is skipped.

## FULLDUPLEX is special

An explicit FULLDUPLEX request still calls:

```text id="id4m75"
Cfg_Txn_Sync_Live_FullDuplex
```

even if the persistent EEPROM policy was already correct.

This allows an explicitly requested Full Duplex policy to repair stale live
Window 4 state.

## INT is deliberately different

The same stale-live repair is not applied to an unchanged standalone INT
request.

That difference is intentional compatibility behavior, not an accidental
inconsistency.

# Preflight

If actual commit work remains:

```text id="38ji74"
Cfg_Txn_Preflight
```

performs the remaining read-only checks before destructive work begins.

Nothing should have been persistently committed yet.

# IOBASE conflict check

An actual I/O migration checks the requested base against the other records in
`nic_table`.

The selected adapter itself is excluded.

If another discovered adapter already uses that base, the transaction fails
with an I/O conflict.

This is deliberately a reduced conflict model.

The original full utility had broader resource-manager logic.

`3CCFGCLI` does not attempt to reconfigure another NIC to free an address.

# Valid ID tag requirement

Actual I/O migration requires the selected record to have a valid proprietary
ISA ID tag.

Without that tag, the transaction cannot safely perform the required
deactivate/retag/reactivate migration.

The migration therefore fails before making changes.

# INT activation choice

A real persistent IRQ change also prefers the original
deactivate/reactivate path when the selected adapter has a valid ID tag.

If no usable tag exists, the INT transaction is still allowed to continue
through the direct persistent/live update path.

This preserves the behavior established by the earlier hardware-tested INT
implementation.

# Activation and I/O migration

If preflight marks activation as required:

```text id="q0jpqm"
Cfg_Txn_Activate_If_Needed
```

owns the transition.

## Deactivation

The selected tagged adapter is first deactivated through the ID port.

For a true I/O migration, the old base is then checked read-only to confirm
that the selected adapter no longer appears there.

This old-base disappearance check is specific to migration.

## Retagging

After deactivation:

```text id="qwl3mi"
Cfg_Txn_Retag_Selected
```

re-enters the appropriate ID sequence and restores the selected adapter's tag.

## Moving the selected record

During a real migration, the selected `nic_table` record changes
`NIC_IO_BASE` exactly once:

```text id="yyv8wt"
old base
    |
    v
deactivate
    |
    v
retag
    |
    v
NIC_IO_BASE = prospective new base
    |
    v
activate selected adapter
```

The record must contain the new address before
`Cfg_Id_Activate_Selected` consumes it.

This is one of the few pieces of application state that necessarily changes
before the whole transaction has been verified.

## Reactivation

The tagged adapter is activated at the prospective base.

The transaction then restores the complete prospective live:

* Window 0 Address Configuration
* Window 0 Resource Configuration

before persistent EEPROM is committed.

## Why live state is restored before EEPROM commit

Deactivation/reset may reload live configuration from the still-old persistent
EEPROM.

Therefore the transaction explicitly reapplies its prospective live Window 0
state after activation.

The sequence is:

```text id="kg43jp"
old persistent EEPROM
        |
        v
deactivate / reset-facing behavior
        |
        v
live state may reflect old persistent values
        |
        v
reactivate
        |
        v
restore prospective live06 / live08
        |
        v
verify active hardware
        |
        v
write new persistent EEPROM
```

This relationship is described in more detail in
[`STATE_MODEL.md`](STATE_MODEL.md).

# Activation verification

Before any EEPROM write proceeds after activation, the transaction checks that
the expected EtherLink III is reachable.

The activation-stage identity check is strict:

* 3Com signature
* product ID
* ASIC revision when previously known

For I/O migration, the new live I/O selector is also checked.

If INT participates in the activation path, the live IRQ is checked as
appropriate.

For an IOBASE-only migration, the old live IRQ nibble must survive unchanged.

# Persistent commit

After activation succeeds, the transaction commits persistent EEPROM through:

```text id="m73tse"
Cfg_Txn_Write_EEPROM
```

Only changed persistent property words are written.

## Property-word write order

The current order is:

```text id="su2tv9"
word 08h
word 09h
word 0Dh
word 13h
word 14h
```

Unchanged words are skipped.

# Checksum updates are derived work

Checksums are updated after the property words they cover have been written.

The current transaction has two checksum domains:

```text id="wvmu23"
primary checksum
    data changes in 08h / 09h / 0Dh
    -> update word 0Fh low byte

secondary checksum
    data changes in 13h / 14h
    -> update word 17h low byte
```

The high byte of the destination checksum word is preserved.

Both checksum writes are immediately read back and compared.

Detailed checksum ownership belongs in
[`EEPROM.md`](EEPROM.md).

## Checksums do not have independent transaction change flags

Checksum writes are consequences of changing covered data.

They are not user-requested properties.

The transaction therefore derives checksum work from the property-word change
flags rather than creating separate "checksum changed" transaction state.

# Live commit

After the persistent write phase:

```text id="fhfmxw"
Cfg_Txn_Write_Live
```

synchronizes the live Window 0 state required by the transaction.

## IOBASE live synchronization

When IOBASE live state participates, the complete prospective live Address
Configuration word is written.

The I/O selector is immediately read back and checked.

For an actual migration this write deliberately repeats the prospective
Address Configuration that was already restored during activation.

This mirrors the original sequencing and ensures that the committed live state
matches the final transaction image.

## INT live synchronization

A real persistent INT change writes prospective live Resource Configuration.

The IRQ nibble is immediately read back and checked.

## Boot ROM live synchronization

An accepted Boot ROM change also writes prospective live Address
Configuration so the new ROM mapping becomes effective without requiring a
reset.

The final Boot ROM-specific live readback is performed by the verification
phase.

## Properties without direct live Window 0 writes

The current transaction does not directly synchronize live state for:

* PNP
* MODEM
* OPTIMIZE
* TR

Full Duplex uses a separate Window 4 synchronization phase after persistent
verification.

Do not add live writes for these properties merely for architectural
symmetry.

Their behavior should change only when supported by the compatibility target
or hardware evidence.

# Central verification

After persistent and immediate live writes complete:

```text id="wwdpl2"
Cfg_Txn_Verify
```

performs property-aware readback.

Verification is based on the prospective state.

It does not simply check that a write routine returned success.

# IOBASE verification

If `CFG_TXN_IOBASE_CHANGED` is set, verification checks final reachability at
the selected base.

The final reachability test compares:

* 3Com signature
* product identity

It deliberately does **not** repeat the ASIC revision comparison at this final
stage.

ASIC revision was already checked during selected-adapter revalidation and,
when activation occurred, during activation verification.

ASIC revision is not itself a configured property.

## Persistent IOBASE verification

EEPROM word `08h` is read again.

If the complete word changed, it must match the complete prospective word.

The I/O selector is then checked explicitly.

## Live IOBASE verification

Live Window 0 Address Configuration is read again and the I/O selector must
match the prospective selector.

# INT verification

INT readback happens when either:

* its persistent field changed
* an I/O migration forced live restoration

The persistent Resource Configuration word is read again.

If the complete word was changed, it must match the prospective word.

The IRQ nibble is then checked explicitly.

Live Window 0 Resource Configuration is also read and its IRQ nibble verified.

A standalone unchanged INT request skips this readback, preserving the
established 0.3.3 semantics.

# PNP verification

When persistent word `13h` changed for a requested PNP operation, the complete
word is read back and compared with the prospective image.

# MODEM verification

When MODEM was requested and shared EEPROM word `0Dh` changed, the complete
word is read back and compared with the prospective image.

This is important for combined word `0Dh` transactions because it verifies
that the complete merged Software Information image survived the commit.

# FULLDUPLEX persistent verification

When FULLDUPLEX was requested and word `0Dh` changed, verification compares
only the persistent Full Duplex policy bit:

```text id="u77myx"
bit 15
```

The live Full Duplex bit is handled separately after central persistent
verification succeeds.

# OPTIMIZE verification

When OPTIMIZE was requested and word `0Dh` changed, the complete Software
Information word is read back and compared with the prospective image.

# Boot ROM verification

Boot ROM verification distinguishes persistent configuration from actual ROM
contents.

The ROM contents are **not** re-probed after commit.

Physical ROM validity was already established by the pre-commit probe.

## Persistent Boot ROM Size Valid

If EEPROM word `14h` changed, the complete word is read back and compared.

## Persistent Boot ROM fields

If EEPROM word `08h` changed, only Boot ROM-owned bits `13:8` are compared for
the Boot ROM-specific verification step.

Other fields in the shared word belong to other properties.

## Live Boot ROM mapping

For an accepted Boot ROM request during a committed transaction, live Window 0
Address Configuration is read and only Boot ROM bits `13:8` are compared with
the prospective live image.

A Boot ROM request rejected by the pre-commit ROM probe is not verified again.

# TR verification

If TR was requested and EEPROM word `08h` changed, the transaction rereads
word `08h`.

Only the transceiver-owned fields are compared:

* explicit transceiver selector
* AUTO select bit

This prevents unrelated IOBASE or Boot ROM fields in the same word from being
mistaken for TR verification state.

# Shared-word verification behavior

Because several properties can share one word, a requested property may be
verified even when another property caused the actual word-level change.

For example:

```text id="ab89dj"
/MODEM already correct
/FULLDUPLEX changes word 0Dh
```

The resulting word `0Dh` is still the one combined prospective image.

If MODEM was explicitly requested, its verification path may therefore also
check that final merged word.

That is correct.

The transaction verifies the final requested configuration, not an artificial
sequence of isolated property writes.

# Checksum verification occurs during the write phase

The central verification routine does not independently re-verify checksum
words.

Both checksum destinations are already read back immediately after their
writes inside `Cfg_Txn_Write_EEPROM`.

Checksum verification therefore belongs to the persistent commit phase.

# Post-commit Full Duplex live synchronization

Full Duplex has one additional phase:

```text id="rwwtzl"
Cfg_Txn_Sync_Live_FullDuplex
```

This happens only after central persistent verification has succeeded.

## Window 4 state

The routine preserves the current register window, selects Window 4, and reads:

```text id="bxwk43"
EL3_W4_NETWORK_DIAGNOSTIC
```

It compares the current Full Duplex live bit against the prospective
persistent policy.

## Update only when necessary

If live state already matches persistent policy, no write occurs.

Otherwise only the live Full Duplex enable bit is changed.

The register is then read back and verified.

## Unchanged persistent FULLDUPLEX still reaches this phase

This routine is also used for an explicit FULLDUPLEX request where no EEPROM
change was necessary.

That is how the utility repairs stale live Full Duplex state while preserving
the existing persistent policy.

# Updating the in-memory record

After all required verification succeeds, the selected `nic_table` record is
updated where necessary.

The current transaction updates the cached IRQ only after successful
verification.

IOBASE is different.

As described earlier, `NIC_IO_BASE` must be changed before reactivation so the
activation routine knows the new address.

This asymmetry is intentional.

# Success reporting

`Cfg_Txn_Report_Success` runs only after the required transaction work has
succeeded.

Some single-property commands retain their historical dedicated completion
messages.

Combined or newer property transactions use the generic transaction completion
message.

Verbose mode adds current-state, prospective-state, unchanged-property,
activation, write, checksum, live synchronization, and verification details.

Verbose reporting must not change transaction behavior.

# Error propagation

Lower-level transaction stages generally return failure through CF and set an
appropriate:

```text id="xij6w6"
cfg_last_error
```

`Cfg_Txn_Execute` uses that state to stop later phases.

`Cmd_Configure` ultimately reports `cfg_last_error` through the common error
reporting path.

EEPROM timeouts use the shared timeout latch so a timeout is not silently
converted into another property-specific read or write error.

Detailed FLAGS and error conventions belong in
[`LOW_LEVEL_CONVENTIONS.md`](LOW_LEVEL_CONVENTIONS.md).

# Failure after commit has started

This deserves repeating because it is easy to misunderstand.

The transaction is strongly staged before modification:

```text id="i4su15"
parse
validate
snapshot
prepare
combined validation
probe
change detection
preflight
```

All of those phases are designed to reject invalid work before persistent
changes begin.

But once:

```text id="rqtp6n"
Cfg_Txn_Activate_If_Needed
```

starts destructive activation work, or:

```text id="qu1qcb"
Cfg_Txn_Write_EEPROM
```

starts writing persistent words, failure does not imply automatic rollback.

## Examples

A failure can theoretically occur after:

* the selected adapter has already migrated to a new I/O base
* one EEPROM property word was written but a later word failed
* property words were written but checksum update failed
* EEPROM committed successfully but a live register write failed
* persistent and Window 0 state succeeded but live Full Duplex synchronization
  failed

In those cases the program reports the failure.

It does not claim that the original state was restored.

## Why preflight matters

Because general rollback is not implemented, destructive work should be pushed
as late as reasonably possible.

Checks that can be performed read-only belong before activation and EEPROM
writes.

That is one of the main architectural reasons for maintaining explicit:

* capability gates
* prospective validation
* physical Boot ROM probing
* conflict checks
* valid-tag checks

before commit begins.

# Adding another CONFIGURE property

A new hardware-changing property should normally fit into the existing staged
transaction.

The preferred sequence is:

## 1. Parse the property

Add the property to the canonical parser and duplicate tracking.

The handler should validate and normalize its value into dedicated staged
state.

Do not write hardware here.

## 2. Add capability gating if required

If the operation is only valid on certain physical adapters, place that check
in the capability gate phase before accepted-value reporting.

Do not hide hardware capability checks inside the prepare routine unless the
check genuinely depends on prospective combined state.

## 3. Read required current state

Extend `Cfg_Txn_Read_Current` only with the persistent/live state actually
needed by the new property.

Reuse already captured words when fields share storage.

## 4. Initialize prospective state

Every newly introduced transaction image must be copied from current state
before property modification.

## 5. Add a Prepare routine

The prepare routine should modify only the fields owned by the property.

It must not perform hardware access.

## 6. Add combined validation where necessary

If the property interacts with another configured field, validate the
effective prospective state after both have been prepared.

## 7. Extend change detection

Determine which raw and composite change flags represent actual required work.

Do not force a hardware write merely because a property appeared on the
command line.

## 8. Extend preflight if destructive prerequisites exist

Resource conflicts, required tags, or other read-only prerequisites should be
checked before commit.

## 9. Add persistent and live commit behavior

Place hardware writes in the centralized commit phases.

Do not create a second independent EEPROM transaction inside the property
handler.

## 10. Update checksum domains correctly

If the new persistent field belongs to a checksum domain, extend checksum work
according to the actual EEPROM ownership documented in
[`EEPROM.md`](EEPROM.md).

## 11. Add verification

A successful write is not sufficient.

Read back the persistent and/or live fields that define success for the
property.

## 12. Test combined transactions

A property sharing a word or hardware state with existing properties must be
tested in combination with them.

Testing only the standalone verb is insufficient.

# Transaction invariants

The following rules should remain true when modifying CONFIGURE:

* All supported hardware properties use the centralized transaction path.
* Property handlers parse and stage values only.
* Property handlers do not write hardware.
* Duplicate-property detection remains separate from accepted staged state.
* Adapter discovery occurs through the same common path used by `LIST`.
* The selected adapter is revalidated before transaction execution.
* Capability gates happen before accepted-value reporting.
* Current hardware state is snapshotted before prospective state construction.
* Prospective state starts as an exact copy of current state.
* Prepare routines modify only the fields owned by their property.
* Prepare routines perform no hardware access.
* Shared EEPROM words use prospective read-modify-write semantics.
* Cross-property rules are validated against the fully prepared prospective
  state.
* FULLDUPLEX compatibility is evaluated against effective prospective
  transceiver state, not parser order.
* Boot ROM physical probing happens before change detection and persistent
  commit.
* A failed Boot ROM content probe rolls back only its prospective Boot ROM
  portion and may allow unrelated requested changes to proceed.
* Temporary Boot ROM mapping must be restored before normal commit.
* Change detection happens only after all property preparation is complete.
* A property appearing on the command line does not by itself require a write.
* IOBASE persistent state, live state, and actual active-base migration remain
  separately detectable.
* Standalone unchanged INT behavior remains persistently authoritative unless
  compatibility requirements deliberately change it.
* An actual I/O migration requires a valid ID-port tag.
* I/O migration conflict checks happen before destructive activation work.
* The selected record changes IOBASE only at the controlled activation point.
* Persistent property words are written through the shared transaction path.
* Checksums are derived from changed covered words, not treated as independent
  user properties.
* Live Window 0 synchronization happens only where current property semantics
  require it.
* Full Duplex live synchronization remains separate from persistent EEPROM
  verification.
* Every committed property has appropriate persistent and/or live readback
  verification.
* Verbose mode may report transaction state but must not alter transaction
  decisions.
* `Cfg_Txn` must not be described or relied upon as an automatic rollback
  transaction.
* Once destructive commit begins, a later failure may leave partially changed
  hardware state.
* Read-only validation and preflight should therefore happen before activation
  or EEPROM writes whenever practical.

The central design principle is:

```text id="vzifoe"
Parse each property separately.

Prepare one final configuration together.

Commit it through one shared path.

Verify what actually matters.

And do as much checking as possible before touching the hardware.
```

The persistent EEPROM layout and checksum domains used by this transaction are
documented in [`EEPROM.md`](EEPROM.md).

