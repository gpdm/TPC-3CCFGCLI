# Design Decisions

## Purpose

This document records intentional design decisions, accepted architectural limitations, and deliberate differences between technically possible hardware states and the behavior exposed by `3CCFGCLI`.

These are not open TODO items.

They describe behavior that is considered intentional unless a future change explicitly revisits the corresponding design decision.

The purpose of this document is to make such decisions visible to maintainers, reviewers, and automated coding agents so that intentional behavior is not repeatedly identified as a defect.

This document complements the detailed architecture documents.

In particular:

`EEPROM.md` describes EEPROM layout, field ownership, preservation rules, and checksum handling.

`TRANSACTIONS.md` describes staged CONFIGURE processing, commit sequencing, and verification.

`CAPABILITIES.md` describes adapter identity, generation classification, and feature capability.

This document explains why some technically possible behaviors are deliberately not implemented or not represented directly by the CLI.

## General Principles

Not every valid hardware state must have a one to one CLI representation.

`3CCFGCLI` exposes a deliberately constrained configuration interface based on supported, defined, and canonical configuration values.

A hardware or EEPROM state may therefore be readable without being directly configurable.

`SAVECONFIG` serializes supported canonical CLI state.

It is not intended to be a bit exact EEPROM backup mechanism.

Likewise, the CONFIGURE transaction model is designed to validate and stage a complete requested configuration before persistent modification begins, but it does not guarantee automatic recovery from every hardware failure after a commit has started.

## EEPROM Transaction Failure And Automatic Rollback

### Decision

`3CCFGCLI` does not automatically roll back EEPROM changes after a persistent write sequence has begun and a later EEPROM operation fails.

This is an intentional architectural limitation.

### Rationale

Before the persistent commit phase begins, CONFIGURE stages and validates the complete requested state.

Once EEPROM modification has started, however, a later failure can leave persistent state partially changed.

Automatic rollback is deliberately not attempted because the cause of an EEPROM failure is unknown.

A failed write may be a transient write error.

It may also indicate a degraded or failing EEPROM.

In the second case, attempting additional writes in order to restore earlier values could make the situation worse.

The program cannot reliably distinguish these cases at the point of failure.

For that reason, automatically issuing further EEPROM writes is not considered inherently safer than stopping after the detected failure.

### Resulting Behavior

When an EEPROM operation fails after persistent modification has started, CONFIGURE reports the failure and stops the transaction.

It does not attempt to reconstruct and rewrite the complete previous EEPROM state.

The adapter may therefore remain partially modified.

This behavior is accepted by design.

Future improvements may make error reporting more explicit, but automatic rollback is not currently considered a required feature.

## MODEM 1200 Microsecond Representation

### Decision

The EEPROM MODEM field value `2Fh` is treated as a technically valid readable state representing 1200 microseconds maximum interrupt disable time.

It is not directly configurable through the current CLI.

`SAVECONFIG` serializes this state canonically as:

```text
/MODEM:NONE
```

### CLI Parsing Rule

The `/MODEM` CLI syntax accepts numeric values without an explicit unit suffix.

The parser therefore cannot distinguish between an intended baud rate value and an intended microsecond value when both use the same number.

Defined modem baud rate values have precedence by design.

Therefore:

```text
/MODEM:1200
```

means the defined 1200 baud preset.

It does not mean 1200 microseconds.

The 1200 baud preset corresponds to a different EEPROM timing value than raw MODEM value `2Fh`.

### Consequence

Raw EEPROM value `2Fh` can be read and interpreted correctly as 1200 microseconds.

It cannot be written back through `/MODEM:1200`, because that command has a different canonical meaning.

No alternative syntax such as `1200us`, `1200bd`, or another unit discriminator is currently defined.

The 1200 microsecond state is therefore readable but not directly representable as a CONFIGURE input value.

### SAVECONFIG Behavior

`SAVECONFIG` follows the same canonical interpretation as the CLI parser.

It must not emit:

```text
/MODEM:1200
```

for raw EEPROM value `2Fh`, because restoring that command would select the 1200 baud preset and would not reproduce the original timing value.

Instead, the unrepresentable timing state is serialized as:

```text
/MODEM:NONE
```

This is intentional canonicalization.

It is not a serialization defect.

`SAVECONFIG` is expected to generate valid supported CLI configuration, not a bit exact representation of every technically possible EEPROM state.


## PIC Enforcement Mode

### Decision

`3CCFGCLI` currently does not enforce the presence of a secondary PIC when configuring an IRQ that requires it.

The existing `pic_gate_enforce` mechanism and `CFG_ERR_INT_REQUIRES_SLAVE_PIC` error path are intentionally retained for possible future use. `pic_gate_enforce` currently remains disabled.

### Rationale

The current behavior reports the PIC condition without rejecting the requested configuration.

The stricter enforcement path is deliberately kept in the code so that this policy can later be changed without reintroducing the complete validation and error handling mechanism.

The currently unreachable enforcement path is therefore intentional reserved functionality and must not be treated as dead code or removed during cleanup.


## Adapter Activation State Preservation

### Decision

3CCFGCLI does not preserve or restore the adapter activation state that existed before discovery or CONFIGURE.

After successful discovery, supported ID discovered adapters are activated at their configured I/O base and remain active.

After CONFIGURE, the selected adapter is likewise left active at its configured I/O base.

This intentionally differs from the original 3Com utility, which preserves the previous activation state and restores an originally inactive adapter to the inactive state.

### Rationale

The current behavior provides a simple and deterministic final state without additional activation state tracking and restoration logic.

Preserving the previous active or inactive state is not required for the configuration model exposed by 3CCFGCLI.

The difference from the original utility is therefore accepted as an intentional behavioral deviation rather than treated as a defect. This follows the purpose of this document to record deliberate differences and prevent them from being repeatedly identified as open issues.

### Resulting Behavior

Successful discovery leaves supported discovered adapters active.

Successful CONFIGURE leaves the configured adapter active.

No cleanup is required solely to restore an adapter to a previously inactive state.


## No CLI Exit Code Support

### Decision

`3CCFGCLI` does not currently implement distinct DOS process exit codes for success or failure conditions.

The program exits with the same process return code regardless of the result of the requested operation.

### Rationale

There is currently no clear practical benefit from introducing a separate exit code model.

`3CCFGCLI` is expected to be used primarily as an interactive, one off configuration utility. Outside the project's own regression tests, it is unlikely to be a significant component of automated DOS batch workflows that depend on `ERRORLEVEL`.

This also follows the behavior of the original 3Com configuration utility, which did not provide a meaningful CLI exit code interface.

For these reasons, implementing distinct exit codes is not currently considered necessary.


## Unsupported IRQ Values In EEPROM

### Decision

`3CCFGCLI` supports only the IRQ values defined as valid configuration choices for the adapter.

If an EEPROM contains some other IRQ value, `3CCFGCLI` is not required to preserve, reproduce, or make that value configurable.

### Rationale

The configuration interface deliberately restricts IRQ selection to the supported values defined for the hardware.

An EEPROM may contain an unsupported value because it was modified by another utility, manually patched, corrupted, or otherwise placed into a state that `3CCFGCLI` itself would never create.

Such a state does not expand the supported configuration surface.

`CONFIGURE /INT` must continue to reject unsupported IRQ values even when such a value can technically be read from EEPROM.

This behavior is intentional.

## SAVECONFIG Is Not An EEPROM Dump

### Decision

`SAVECONFIG` produces canonical, supported `3CCFGCLI` commands.

It is not intended to reproduce every EEPROM bit or every technically possible EEPROM state exactly.

### Rationale

The EEPROM can contain values that are reserved, unsupported by the CLI, produced by other utilities, or otherwise outside the configuration states that `3CCFGCLI` deliberately exposes.

`SAVECONFIG` is therefore defined in terms of the supported CLI configuration model rather than raw EEPROM representation.

Where a valid hardware state has no exact CLI representation, `SAVECONFIG` may serialize the canonical supported equivalent or omit a property where appropriate.

Generated commands must remain subject to the same validation rules as manually entered CONFIGURE commands.

`SAVECONFIG` must not bypass those rules merely in order to reproduce arbitrary EEPROM contents.

## I/O Base Conflict Scope

### Decision

I/O base conflict detection in `3CCFGCLI` is limited to conflicts between supported EtherLink III adapters known to the utility.

`3CCFGCLI` is not a general ISA resource manager.

### Rationale

The purpose of the utility is to configure supported 3C509 and 3C509B family adapters.

It therefore prevents one managed EtherLink III adapter from being assigned an I/O base already used by another managed EtherLink III adapter.

Detecting conflicts with unrelated ISA hardware is outside project scope.

The utility is not required to probe arbitrary I/O ranges, identify unrelated ISA devices, or reproduce the broader resource management infrastructure of the original configuration software.

The operator remains responsible for selecting an I/O base that does not conflict with other hardware in the system.

This reduced conflict model is intentional.

## PnP BIOS Integration And Boot ROM Configuration

### Decision

`3CCFGCLI` detects the system PnP BIOS and uses the final adapter `/PNP`
policy to select the persistent Boot ROM representation. It does not invoke
PnP BIOS services or allocate resources.

### Rationale

The original 3Com configuration utility distinguishes between systems with
and without a PnP BIOS when configuring the Boot ROM.

The resulting persistent Boot ROM representation differs as follows:

| Environment | Boot ROM state | Boot ROM base | Boot ROM Size Valid |
|---|---|---|---:|
| **No PnP BIOS** | enabled | explicit address | **0** |
| **No PnP BIOS** | disabled | 0 | **0** |
| **PnP BIOS, adapter PnP enabled** | enabled | 0 before BIOS assignment | **1** |
| **PnP BIOS, adapter PnP disabled** | enabled | explicit address | **0** |
| **PnP BIOS** | disabled | 0 | **0** |

Without a PnP BIOS, the Boot ROM mapping is stored explicitly in the
adapter configuration and `Boot ROM Size Valid` remains clear.

With a PnP BIOS, an enabled Boot ROM is represented differently. The
persistent Boot ROM base is not used as a fixed ISA mapping, and
`Boot ROM Size Valid` is set while resource assignment is handled through
PnP.

The PnP BIOS signature is inspected without invoking BIOS services. An
absent BIOS preserves conventional ISA configuration on 8086/8088 systems.
Returning from a PnP-managed ROM to conventional ISA requires a caller-
specified ROM address and size: unlike the original graphical UI, this CLI
does not choose a default address.

### Resulting Behavior

For conventional ISA Boot ROM configuration:

```text
Boot ROM enabled
    explicit Boot ROM base
    explicit Boot ROM size
    Boot ROM Size Valid = 0

Boot ROM disabled
    Boot ROM base = 0
    Boot ROM size = 0
    Boot ROM Size Valid = 0
```

For PnP-managed ROMs, the size is retained, the base is zero, and Boot ROM
Size Valid is one. `SAVECONFIG` cannot export that state through the existing
CLI syntax without an address and explicitly refuses to produce a lossy
restore file.

## Link Status Not Reported (Removed Again From `LIST` verb)

### Decision

`3CCFGCLI` does not report a live Ethernet Link Status in `LIST` any longer.

The Window 4 `Valid Link Beat Detected` indication is not treated as a generally valid adapter status value for configuration utility use.

### Rationale

The `Valid Link Beat Detected` bit in the Media Type and Status register applies specifically to the internal 10BASE T transceiver.

A meaningful Link Beat result depends on the media path having first been initialized correctly. In particular, Link Beat is disabled after reset and must be enabled by software when the internal TP transceiver is used.

The situation is additionally ambiguous when the adapter is configured for automatic transceiver selection. `AUTO SELECT` is software configuration information rather than an autonomous hardware media selection mechanism. The network driver is expected to examine the available media, select a connector during initialization, and update the active configuration accordingly.

`3CCFGCLI` cannot assume that such driver initialization has occurred. A DOS configuration utility is expected to be usable without a loaded network driver, particularly because operations such as changing the I/O base address, IRQ, or transceiver configuration would invalidate assumptions made by an already active driver.

Consequently, a cleared Link Beat indication cannot reliably distinguish between conditions such as no physical connection, an uninitialized TP transceiver, Link Beat not having been enabled, a different active transceiver, or unresolved automatic media selection.

Reporting that value as a simple `connected` or `not connected` status would therefore imply information that the utility cannot reliably establish.

### Resulting Behavior

`LIST` does not display `Link Status` any longer. The previous implementation, as tempting as it was, was removed.

`3CCFGCLI` reports configured transceiver state and supported hardware capabilities, but does not attempt to infer live network connectivity from the Window 4 Link Beat indication.

Mock Seeder state and regression tests do not provide separate live link connected or disconnected fixtures solely for `LIST`.

Determining actual network connectivity is considered a runtime driver responsibility rather than a configuration utility function.


## Hardware Capability Does Not Imply CLI Support

### Decision

The existence of a hardware capability, EEPROM field, register bit, or command in historical documentation does not require `3CCFGCLI` to expose that capability through its CLI.

CLI support is deliberate and must be implemented only when it serves the project scope and has sufficiently understood behavior.

### Rationale

`3CCFGCLI` is a focused configuration utility, not an attempt to expose every feature ever present in the EtherLink III hardware or every option mentioned by historical 3Com software.

A technically possible operation may remain unsupported when it is unnecessary for the intended use case, insufficiently understood, redundant with driver policy, absent from the targeted reference utility behavior, or not adequately testable.

Unsupported functionality must not be reintroduced merely because constants, EEPROM fields, mock behavior, or remnants of the original utility show that the hardware can support it.

### `/LINKBEAT`

Historical versions of the 3Com utility advertise `/LINKBEAT`, and earlier versions contain implementation related behavior.

The targeted 3Com utility version does not provide an active `/LINKBEAT` configuration path.

Link Beat policy is also treated primarily as driver policy rather than a configuration requirement for this project.

`CONFIGURE /LINKBEAT` is therefore intentionally not implemented.

Its omission is not a missing feature to be restored automatically.

### `/SYNCREADY`

Historical 3Com utility versions advertise `/SYNCREADY`, but no corresponding active implementation path was identified in the versions investigated for this project.

`3CCFGCLI` therefore does not implement `/SYNCREADY`.

The presence of the option in historical HELP text is not sufficient reason to add it.

Unless project scope is explicitly changed and the required hardware semantics are independently established, `/SYNCREADY` remains intentionally unsupported.

### General Rule

Future reviews must distinguish between:

* hardware capability
* historical utility surface
* currently supported `3CCFGCLI` behavior

These are separate concepts.

A feature must not be treated as missing merely because the hardware could theoretically support it.
