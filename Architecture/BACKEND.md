# Hardware Backend Architecture

## Purpose

`3CCFGCLI` separates the application logic from direct access to the
3C509/3C509B hardware.

The same command parser, discovery orchestration, `LIST` logic, configuration
transaction engine, verification code, and reporting paths are used regardless
of whether the program is running against a real EtherLink III adapter or the
software mock.

The hardware-facing part is selected at compile time.

There are currently two backend implementations:

* `3CHWIF.ASM` for real 3C509/3C509B ISA hardware
* `3CMOCKIF.ASM` for the software hardware model

The intent is simple:

Application logic should deal with what it wants the adapter to do.

The backend deals with how that operation reaches either the real hardware or
the model.

## Architecture at a glance

```text
                          3C509DEF.INC
                     shared hardware definitions
                               |
                 +-------------+-------------+
                 |                           |
                 v                           v
          3CCFGCLI.ASM                  3CSEED.ASM
   CLI, discovery, LIST, CONFIGURE,          |
   transactions, verification, SAVECONFIG    |
                 |                           |
                 |                     creates/modifies
                 |                           |
                 |                           v
                 |                      3C509B.MCK
                 |                           ^
                 |                           |
       compile-time backend selection        |
                 |                           |
        +--------+--------+                  |
        |                 |                  |
        v                 v                  |
   REALHW build       MOCKHW build            |
        |                 |                  |
        |                 +------------------+
        |                 |
        v                 v
   3CHWIF.ASM        3CMOCKIF.ASM
        |                 |
        |                 |
   ISA port I/O       modeled adapter state
   EEPROM             ID-port state
   register windows   EEPROM/live registers
   ID port            reset/command state
   Option ROM         synthetic Option ROM
        |
        v
   physical
   3C509/3C509B
```

`3CSEED` is not another backend and it does not participate in the runtime
hardware interface.

Its job is to create deterministic `3C509B.MCK` state that
`3CMOCKIF.ASM` later loads and operates on.

## Compile-time composition

The backend is not a separately linked library.

`3CCFGCLI.ASM` includes the selected backend source directly into its own
assembly unit.

The current selection logic is:

```text
REALHW defined        -> include 3CHWIF.ASM
MOCKHW defined        -> include 3CMOCKIF.ASM
neither defined       -> default to REALHW and include 3CHWIF.ASM
```

The normal build therefore defaults to real hardware.

`REALHW` and `MOCKHW` are intended to be mutually exclusive. Defining both is
not a supported build configuration, since both files provide the same
`Nic_*` procedure names.

Because the backend files are included directly, they share the surrounding
segments, definitions, and application data.

This is important when reading the source.

The backend boundary is an architectural seam, but it is not a strict binary
ABI between independently assembled modules.

Some backend procedures can therefore access common application state such as
`nic_table` and `card_count`.

`Nic_Activate_Tagged_Cards` is one example.

Do not treat `3CHWIF.ASM` or `3CMOCKIF.ASM` as standalone reusable libraries
without first removing those source-level dependencies.

## Responsibility of `3CCFGCLI.ASM`

`3CCFGCLI.ASM` contains the backend-independent application logic.

This includes:

* command parsing
* adapter selection
* discovery orchestration
* adapter record management
* capability decisions
* `LIST`
* `CONFIGURE`
* prospective transaction state
* EEPROM field composition
* checksum calculations
* live-state synchronization policy
* transaction verification
* `SAVECONFIG`
* user-visible reporting

There are currently no raw adapter-facing `IN` or `OUT` instructions in
`3CCFGCLI.ASM` itself.

Hardware-facing port access goes through the selected backend.

Application code may interpret register or EEPROM values returned by the
backend, but it should not create separate REALHW and MOCKHW versions of the
same application algorithm.

If a new feature genuinely requires a new hardware operation, the normal
approach is to add an appropriate shared backend operation and implement its
hardware semantics in both backends.

## Responsibility of `3CHWIF.ASM`

`3CHWIF.ASM` implements the real hardware side of the backend contract.

It owns direct interaction with the EtherLink III hardware, including:

* ISA word I/O
* register-window selection and access
* command-status polling
* EEPROM access used by general read paths
* 3Com ID-port access
* ID-port timing
* tagged-card activation
* active-card signature checking
* Option ROM memory access
* Option ROM page selection

Hardware timing and physical I/O sequencing belong here when they are part of
the hardware operation being abstracted.

For example, the real implementation of `Nic_IdPort_Eeprom_Delay` performs
the required delay using repeated port reads.

The mock implementation does not need to simulate elapsed CPU time and
therefore implements the same operation as a no-op.

The relevant contract is the hardware-visible result, not cycle-accurate
timing.

## Responsibility of `3CMOCKIF.ASM`

`3CMOCKIF.ASM` implements the same backend-facing surface against the software
hardware model.

The mock is deliberately more than a table of expected values.

It maintains concepts that exist on the real adapter, including:

* persistent EEPROM contents
* live register state
* active ISA decode state
* current register window
* adapter tags
* ID-port state
* ID-port contention state
* command-in-progress state
* reset behavior
* EEPROM command state
* Option ROM presence
* Option ROM paging

The mock state is stored persistently in `3C509B.MCK`.

This allows separate invocations of the DOS utility to observe the state left
behind by earlier operations, just as separate invocations against a real card
would observe its persistent and current hardware state.

The mock should model the adapter state required by the application.

It should not contain a second implementation of `CONFIGURE` policy merely to
produce whatever result a test expects.

More detail about the internal hardware model belongs in
[`MOCK.md`](MOCK.md).

## Responsibility of `3C509DEF.INC`

Shared hardware definitions belong in `3C509DEF.INC`.

This includes things such as:

* EEPROM word addresses
* EEPROM field masks
* register offsets
* command values
* status bits
* product IDs
* capability bits
* NIC record definitions
* mock file and record definitions
* other shared 3C509/3C509B constants

`3CCFGCLI`, the real backend, the mock backend, and `3CSEED` should use the
same definitions.

A hardware field must not acquire a different definition merely because it is
being used by the mock.

Duplicating hardware constants locally should therefore be avoided unless
there is a specific reason for doing so.

## The current backend surface

The shared backend procedures use the `Nic_*` namespace.

The source remains authoritative for exact register inputs, preserved
registers, and FLAGS behavior, but the current backend surface can be grouped
as follows.

### ID-port operations

| Procedure                        | Purpose                                                                                        |
| -------------------------------- | ---------------------------------------------------------------------------------------------- |
| `Nic_IdPort_Write_Command`       | Send one command or data byte through the 3Com ID-port interface.                              |
| `Nic_IdPort_Send_Full_Sequence`  | Perform the full 255-byte ID-port LFSR sequence.                                               |
| `Nic_IdPort_Send_Short_Sequence` | Perform the short ID-port re-entry sequence used by the current discovery flow.                |
| `Nic_IdPort_Eeprom_Delay`        | Provide the required real-hardware EEPROM delay; no timing simulation is required in the mock. |
| `Nic_Init_Id_Port`               | Initialize the ID-port environment used before discovery.                                      |
| `Nic_IdPort_Read_Bit`            | Read one serialized ID-port data bit.                                                          |

The higher-level EEPROM word transfer itself is not duplicated in the
backends.

`Nic_IdPort_Read_Word` lives in `3CCFGCLI.ASM` and assembles the 16 serialized
bits using `Nic_IdPort_Read_Bit`.

This is a useful example of the intended split:

```text
common algorithm                backend primitive
-----------------------------   -------------------------
Nic_IdPort_Read_Word       ->   Nic_IdPort_Read_Bit
```

The serialization algorithm is identical in both builds, so only the actual
bit source is backend-specific.

### NIC register and command access

| Procedure                | Purpose                                                                    |
| ------------------------ | -------------------------------------------------------------------------- |
| `Nic_IO_Read_Word`       | Read a WORD from an actual or modeled NIC I/O address.                     |
| `Nic_IO_Write_Word`      | Write a WORD to an actual or modeled NIC I/O address.                      |
| `Nic_Read_Status`        | Read the adapter status register.                                          |
| `Nic_Select_Window`      | Select one of the 3C509 register windows.                                  |
| `Nic_Get_Current_Window` | Read the currently selected register window.                               |
| `Nic_Wait_Command_Ready` | Wait for Command-In-Progress to clear and return timeout state through CF. |
| `Nic_Reg_Read_Word`      | Read a WORD register at an offset from the adapter base.                   |
| `Nic_Reg_Write_Word`     | Write a WORD register at an offset from the adapter base.                  |

The generic NIC register interface is intentionally WORD only.

Older byte-oriented register primitives and the corresponding byte-pair mock
state were removed once it was established that current `3CCFGCLI` code does
not require byte-level NIC register access.

Do not reintroduce generic byte I/O merely because the physical adapter can
perform it.

If future application code genuinely requires byte access, that should first
be established from the hardware requirement and then implemented consistently
in both backends.

This WORD-only rule applies to NIC register I/O.

It does not mean every hardware object is word-sized. Option ROM data, for
example, is naturally accessed byte by byte.

### General EEPROM read access

| Procedure         | Purpose                                                                    |
| ----------------- | -------------------------------------------------------------------------- |
| `Nic_EEPROM_Read` | Read one EEPROM word from an active adapter and report timeout through CF. |

`Nic_EEPROM_Read` is used by general read paths such as adapter record
construction, capability discovery, extended `LIST` information, and
`SAVECONFIG`.

Its contract is:

```text
Input:
    DX = adapter I/O base
    AL = EEPROM word number

Success:
    CF clear
    AX = EEPROM data word

Failure:
    CF set
    AX must not be used
```

A valid EEPROM word may contain `FFFFh`.

Therefore `FFFFh` must never be interpreted as an EEPROM read failure
sentinel.

The FLAGS contract is what distinguishes data from failure.

## CONFIGURE EEPROM access is intentionally common code

One detail deserves special attention because it is easy to misunderstand from
the backend split.

There is currently no `Nic_EEPROM_Write` backend procedure.

The central `CONFIGURE` transaction uses the common routines:

* `Cfg_Eeprom_Read`
* `Cfg_Eeprom_Write`
* `Cfg_Eeprom_Wait_Ready`

These live in `3CCFGCLI.ASM`.

They reproduce the required EEPROM command protocol using the common
`Nic_Select_Window`, `Nic_Reg_Read_Word`, and `Nic_Reg_Write_Word`
operations.

Conceptually:

```text
                     CONFIGURE transaction
                             |
                 +-----------+-----------+
                 |                       |
          Cfg_Eeprom_Read         Cfg_Eeprom_Write
                 |                       |
                 +-----------+-----------+
                             |
                 Nic_Reg_Read/Write_Word
                             |
                   backend implementation
                     /               \
                    /                 \
             3CHWIF.ASM          3CMOCKIF.ASM
             real registers      modeled registers
```

This is intentional and useful.

The EEPROM write sequence itself is part of the common configuration behavior.

The real backend therefore sees the actual register commands.

The mock backend sees those same commands through its modeled Window 0 EEPROM
command and data registers.

This prevents the mock from bypassing the protocol with a special
"just change this EEPROM word" shortcut.

It also means that changes to CONFIGURE EEPROM sequencing should normally be
made in the shared transaction code, not by inventing separate real and mock
write algorithms.

`Nic_EEPROM_Read` and `Cfg_Eeprom_Read` therefore serve different purposes and
should not be casually consolidated merely because both ultimately read
EEPROM contents.

## Card-level backend operations

Two current backend procedures operate at a somewhat higher level than simple
register primitives.

| Procedure                   | Purpose                                                                                                  |
| --------------------------- | -------------------------------------------------------------------------------------------------------- |
| `Nic_Check_3Com_Signature`  | Validate an active adapter and recover its product ID and ASIC revision.                                 |
| `Nic_Activate_Tagged_Cards` | Perform the backend-specific activation step for records discovered and tagged through the ID-port flow. |

These procedures are part of the backend seam because their implementation is
closely tied to active hardware state.

They also demonstrate why the backend is not a pure low-level I/O abstraction.

`Nic_Activate_Tagged_Cards`, for example, operates on the shared `nic_table`
and `card_count` state.

The real implementation performs the actual ID-port activation sequence and
then verifies the resulting active card.

The mock implementation updates the corresponding modeled adapter activation
state.

Callers should therefore depend on the documented application-level purpose of
this procedure, not on private internal steps of either backend.

The overall discovery orchestration remains common code and is documented in
[`DISCOVERY.md`](DISCOVERY.md).

## Option ROM access

Boot ROM probing also uses the backend abstraction.

The current common primitives are:

| Procedure           | Purpose                                                                               |
| ------------------- | ------------------------------------------------------------------------------------- |
| `Nic_Rom_Read_Byte` | Read one byte from the currently visible Option ROM aperture.                         |
| `Nic_Rom_Set_Page`  | Select the 32 KB Option ROM page while preserving the caller's register-window state. |

The real backend reads the byte from the mapped physical ROM address and
programs the adapter's ROM page register.

The mock backend resolves the selected adapter, checks its modeled live ROM
aperture, and returns a byte from its deterministic synthetic Option ROM.

This allows the common `Cfg_Probe_Boot_ROM` routine to perform the actual ROM
validation.

The probe does not need separate REALHW and MOCKHW implementations.

It can use the same logic to validate:

* the Option ROM signature
* the declared ROM size
* the complete ROM checksum
* 32 KB page traversal
* aperture wrapping behavior

This is the preferred shape for new hardware-facing functionality.

Abstract the hardware operation.

Keep the interpretation and validation algorithm common.

## Not every `Nic_*` procedure is a backend procedure

The `Nic_*` prefix predates parts of the backend split and does not by itself
prove that a routine lives inside `3CHWIF.ASM` or `3CMOCKIF.ASM`.

Current examples of common `Nic_*` routines in `3CCFGCLI.ASM` include:

* `Nic_IdPort_Read_Word`
* `Nic_Read_Capabilities`

Before moving, replacing, or duplicating a `Nic_*` routine, check where it
actually lives and what layer owns its algorithm.

Do not infer backend ownership solely from the procedure name.

## Equivalent contract does not mean identical implementation

`3CHWIF.ASM` and `3CMOCKIF.ASM` obviously cannot be internally identical.

One talks to a physical ISA adapter.

The other maintains a software representation of one.

The goal is equivalent behavior for the hardware operations required by
supported application paths.

That does not require cycle-accurate simulation.

For example:

* the real command-ready routine waits on a physical status bit
* the mock uses a deterministic busy-then-clear model
* the real ID-port EEPROM delay consumes real I/O time
* the mock delay is a no-op
* the real Option ROM read accesses physical memory
* the mock generates the corresponding synthetic ROM byte
* the real backend activates a physical ISA decode
* the mock updates modeled activation state

These implementations are different, but the application should observe the
same relevant hardware semantics.

The mock does not claim perfect equivalence for every physically possible ISA
bus situation.

Known modeling limits belong in [`MOCK.md`](MOCK.md).

The important rule is that a supported application path must not pass merely
because MOCKHW contains a shortcut that reproduces the result expected by the
CLI.

## Persistent state and live state

The backend boundary does not make EEPROM and live registers interchangeable.

They are not.

EEPROM contains persistent configuration.

The ASIC exposes current live hardware state.

Some adapter operations transfer persistent configuration into live state.

Other operations affect only one side.

The mock preserves these distinctions where they are relevant to the modeled
hardware.

For example, Window 3 Internal Configuration state is not continuously mirrored
from its corresponding EEPROM words. It is loaded at the appropriate modeled
configuration/reset point.

The application must therefore not assume that writing an EEPROM word
automatically changes every related live register.

This distinction is fundamental to both the real and mock implementations and
is documented in detail in [`STATE_MODEL.md`](STATE_MODEL.md).

## `3CSEED` and the backend boundary

`3CSEED` is test infrastructure.

It creates deterministic mock adapter records in `3C509B.MCK`.

It may deliberately construct states that are awkward to reach through the
normal CLI, for example:

* particular connector capability combinations
* stale Full Duplex live state
* specific MODEM fields
* Link Beat policy preservation cases
* adapters with or without synthetic Boot ROMs
* Boot ROM metadata states
* multiple adapters

That is appropriate for a fixture generator.

What `3CSEED` must not do is become part of the implementation path that
`3CCFGCLI` itself depends upon.

Once the fixture exists, `3CCFGCLI` interacts with it through
`3CMOCKIF.ASM`, exactly as the real build interacts with a physical adapter
through `3CHWIF.ASM`.

`3CSEED` and the mock backend both use the shared hardware and mock-record
definitions from `3C509DEF.INC`.

## Error and FLAGS behavior

Several backend procedures return success or failure through processor FLAGS.

Those contracts are part of the interface.

They must not be changed casually.

In particular:

* `Nic_EEPROM_Read` uses CF for read failure
* `Nic_Wait_Command_Ready` uses CF for command timeout
* `Nic_Check_3Com_Signature` uses CF for signature validation failure
* data values must not be repurposed as error sentinels when all values are
  valid hardware data
* caller-visible FLAGS contracts must survive internal cleanup
* critical hardware sequences must preserve the caller's interrupt state where
  required

The real hardware code now uses `PUSHF`, `CLI`, and `POPF` in critical regions
that must restore the incoming interrupt state rather than unconditionally
enabling interrupts afterward.

Detailed procedure and FLAGS conventions belong in
[`LOW_LEVEL_CONVENTIONS.md`](LOW_LEVEL_CONVENTIONS.md).

## Adding a new hardware-facing operation

Before adding a new backend procedure, first determine whether the operation
actually belongs at the backend boundary.

A good backend operation represents something the adapter does, or something
required to access its hardware state.

Examples include:

* reading or writing a NIC register
* selecting a register window
* waiting for a hardware command
* accessing the ID port
* reading an Option ROM byte
* changing an Option ROM page

Things such as these do not belong in the backend:

* CLI syntax
* CONFIGURE property parsing
* capability policy
* cross-property validation
* prospective configuration construction
* EEPROM field ownership
* checksum policy
* deciding whether a requested combination is valid
* user-visible messages

When new backend functionality is required:

1. Determine the smallest hardware operation that needs abstraction.
2. Check whether an existing `Nic_*` primitive already provides it.
3. Keep the higher-level algorithm common where possible.
4. Implement the real hardware semantics in `3CHWIF.ASM`.
5. Implement equivalent modeled semantics in `3CMOCKIF.ASM`.
6. Use shared definitions from `3C509DEF.INC`.
7. Do not add a mock-only application shortcut just to make a test pass.
8. Add regression coverage once the operation is reachable by supported
   application behavior.
9. Verify the real path on physical hardware where practical.

A new backend procedure is not automatically the right answer.

The existing CONFIGURE EEPROM write path is a good example: the hardware
primitive is register access, while the EEPROM write protocol remains common
code.

## Backend invariants

The following rules should remain true when modifying this part of the
project:

* REALHW and MOCKHW use the same higher-level `3CCFGCLI` application logic.
* Exactly one backend is intended to be selected for a build.
* The default build uses REALHW.
* Adapter-facing raw ISA I/O remains inside the real hardware backend.
* Shared hardware operations expose equivalent relevant semantics in both
  backends.
* The mock models hardware state rather than expected CLI results.
* Generic NIC register I/O remains WORD only unless a demonstrated requirement
  justifies extending the contract.
* Option ROM byte access is kept behind its dedicated ROM interface rather than
  reintroducing generic byte NIC I/O.
* `FFFFh` remains valid EEPROM data and must not be used as a read-failure
  sentinel.
* CONFIGURE EEPROM write sequencing remains common code unless there is a
  deliberate architectural reason to change that model.
* Persistent EEPROM state and live register state remain distinct.
* Shared hardware constants come from `3C509DEF.INC`.
* `3CSEED` prepares test fixtures but is not part of the runtime application
  path.
* Hardware policy remains outside the backend.
* A new hardware-facing feature should normally abstract the hardware
  operation, not duplicate the complete higher-level algorithm for REALHW and
  MOCKHW.
* The location of a routine must be checked before assuming that every
  `Nic_*` name belongs to the backend.

The shorter project-wide list of non-negotiable architectural rules is
maintained in [`INVARIANTS.md`](INVARIANTS.md).

