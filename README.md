# 3CCFG CLI

```text
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  EXPERIMENTAL RELEASE, LIMITED HARDWARE TESTING                                   |
|                                                                                   |
|  This release has only undergone limited testing on physical hardware.            |
|  Bugs and unexpected behaviors may be present.                                    |
|  GENERALLY CONSIDERED UNSAFE ARE /BADDR AND /BSIZE OPERATIONS, REST SHOULD WORK   |
|  USE ENTIRELY AT YOUR OWN RISK.                                                   |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

## Overview

This project is a compact CLI only reimplementation of the 3Com EtherLink III
configuration utility for early DOS systems, especially 8 bit ISA machines
with 8086 and 8088 class CPUs.

It was created to fill a remaining gap in the effort to make the 3Com
EtherLink III 3C509B useful in original IBM PC, XT, and compatible systems.

The work documented in [3C509B nestor](https://github.com/hackerb9/3C509B-nestor)
demonstrated that the 3C509B itself can operate in an 8 bit ISA slot and
provided an 8086 compatible packet driver. The original 3Com configuration
software was also adapted so that it could run on 8086 and 8088 processors.

That solved the CPU compatibility problem, but not the memory requirement.

The original 3Com EtherLink III Configuration Utility was designed around a
large text mode user interface. Even when invoked from the command line, the
entire program loads into memory, making it impractical on systems with
256 KB of RAM or less.

The usual workaround is to install the card in a newer computer, configure it
there using the original `3C5X9CFG.EXE` or adapted `3CCFG.EXE` utility, and
then move the configured adapter back into the target system.

`3CCFGCLI` was created to remove that limitation.

Rather than attempting to strip down the original program, it is a purpose
built reimplementation based on analysis of the original 3Com
`3C5X9CFG.EXE` v3.2. It retains the configuration functionality needed for
ISA EtherLink III adapters while deliberately omitting the text mode interface
and other unnecessary functionality.

The implementation history, reverse engineering approach, design decisions,
and validation methodology behind `3CCFGCLI` are documented separately in
[DEVELOPMENT.md](DEVELOPMENT.md).

## Implementation status

Current task notes and open follow ups are tracked in [TODO.md](TODO.md).

The implementation currently provides:

* `HELP`
* `LIST`
* `CONFIGURE`
* `SAVECONFIG`, exports a restore batch file for all installed adapters

Supported `CONFIGURE` subverbs include:

* `/ADAPTERNUM`
* `/INT`
* `/IOBASE`
* `/PNP`
* `/FULLDUPLEX`
* `/TR`
* `/XCVR`
* `/MODEM`
* `/OPTIMIZE`
* `/BADDRESS`
* `/BSIZE`

Supported global CLI options, valid with any command verb:

* `/VERBOSE`, new enhancement

## Where 3CCFGCLI differs

`3CCFGCLI` intentionally differs from the reference implementation in several
areas, including deliberately omitted functionality and a small number of
extensions.

### Not Implemented Features

The following functionality of the original `3C5X9CFG.EXE` was deliberately
omitted:

* MEWEL based text mode UI
* EISA and MCA support, including the `/SLOT` configuration subverb
* `/LANGUAGE` CLI verb
* `/ECHOSERVER` CLI verb
* `/RUN` CLI verb

### /LINKBEAT configuration verb

`CONFIGURE /LINKBEAT` was investigated across the available reference utility
versions.

Versions 3.2 and 3.0 advertise `/LINKBEAT` in their HELP text, but neither
branches into an actual implementation. Version 2.1 still contains an active
`/LINKBEAT` parser path.

The associated EEPROM behavior is documented in
[3C509DEF.INC](3C509DEF.INC), including how the setting could be implemented.
LINKBEAT is effectively treated as driver policy rather than an adapter
configuration requirement.

Because `3CCFGCLI` targets compatibility with the latest available
`3C5X9CFG.EXE` v3.2 behavior, `/LINKBEAT` is intentionally not implemented.

### /SYNCREADY configuration verb

Versions 3.x and 2.1 of `3C5X9CFG.EXE` also advertise a `/SYNCREADY`
configuration verb in their HELP text, but no corresponding implementation
path was found.

For compatibility with the targeted `3C5X9CFG.EXE` v3.2 behavior,
`/SYNCREADY` is not implemented.

### /CONFIGPORT configuration verb

`/CONFIGPORT` is an ISA specific workaround parameter in the original utility.

According to its HELP text, it is intended for systems where the program has
trouble operating through the default adapter ID port. It accepts an I/O
address in the `100h` through `1E0h` range, in increments of `10h`, and
relocates the ID port used during EEPROM and ISA probing.

It does not configure a persistent adapter setting.

`CONFIGURE /CONFIGPORT` is not currently implemented in `3CCFGCLI`.

### /VERBOSE global CLI option

`/VERBOSE` is a new global option handled by the common command parser before
dispatch to the selected command verb. It may therefore be supplied with any
supported command.

Examples:

```text
LIST /VERBOSE
CONFIGURE /VERBOSE /INT:5
SAVECONFIG /VERBOSE
SAVECONFIG /OUTPUTFILE:BACKUP.BAT /VERBOSE
```

It takes no value and may be supplied only once. Duplicate `/VERBOSE`
arguments are rejected.

`/VERBOSE` is intended as a diagnostic aid. For `CONFIGURE`, it prints
additional EEPROM and live register read and write details so transactions can
be traced while investigating hardware behavior, mock state, or parser and
transaction sequencing.

`LIST` and `SAVECONFIG` accept the global option but do not currently produce
additional diagnostic output.

### SAVECONFIG command verb

`SAVECONFIG [/OUTPUTFILE:file] [/EXECFILE:program]` reads the persistent
configuration of every installed adapter with an active IOBASE and writes a
batch file containing restore commands.

One or more `program CONFIGURE /ADAPTERNUM:N ...` lines are generated for each
adapter as required.

Both options are optional and may appear in either order. Each may be supplied
only once. Duplicate and unknown options are rejected.

The old positional filename form:

```text
SAVECONFIG FILE.BAT
```

is not accepted.

`file` defaults to `RESTORE.BAT`. `/OUTPUTFILE:` requires a nonempty value.
The default is used only when the option is omitted entirely.

Examples:

```text
SAVECONFIG
SAVECONFIG /OUTPUTFILE:BACKUP.BAT
SAVECONFIG /EXECFILE:3CCFGCLI.EXE
SAVECONFIG /OUTPUTFILE:BACKUP.BAT /EXECFILE:3CCFGCLI.EXE
SAVECONFIG /EXECFILE:3CCFGCLI.EXE /OUTPUTFILE:BACKUP.BAT
```

`program` defaults to `3CCFGCLI.EXE`.

`/EXECFILE:%1` is the only supported batch placeholder form and is emitted
literally. Other `/EXECFILE` values are interpreted as literal executable
paths. General percent expansion is not supported, and the referenced file
must exist before the restore batch is created.

Restore commands are split dynamically before exceeding the practical
128 byte DOS batch command line limit. The available line budget consists of
the reserved executable length, one separating space, and the generated
`CONFIGURE ...` argument text.

The default executable reserves its actual length. `%1` reserves 64 bytes
because the caller supplies the executable path at runtime. Literal executable
paths reserve their actual supplied length.

`SAVECONFIG` exports only persistent settings supported by the current
implementation and does not modify any adapter.

It can be used to preserve a known configuration and is also used internally
by the standalone hardware conformance tests.

### Enhanced LIST verb

The `LIST` verb extends the original command line output with additional
configuration and status information that would otherwise have been available
through the original text mode interface.

This includes the current Link Status, also known as Link Beat.

Example:

```text
3Com EtherLink III CLI Configuration Program v0.7.1
by The Phintage Collector (Gianpaolo Del Matto)
https://github.com/gpdm/TPC-3CCFGCLI
reimplementation of the original 3Com EtherLink III Configuration Utility v3.2

NIC                            NIC
Number                       Description
--------------------------------------------------------------------------
  1    3Com 3C509B-TP: Ethernet Address = 02608C654321
       EtherLink III 16-bit ISA NIC
       ASIC Revision = 4
       Software Compatibility = failure level 0, warning level 0
       Connectors = TP
       Full Duplex Capability = yes
       Plug and Play Capability = yes
       Link Status = connected
       ---
       IOBASE = 0300, IRQ = 10
       Transceiver = on-board TP
       Plug and Play = enabled
       Boot ROM = disabled
       Optimization = DOS
       MODEM Interrupt Disable Time = 1600 us (NONE)
       Full Duplex = disabled
```

## How it works

The implementation is split into several assembly modules.

CLI behavior is kept separate from hardware access. Real hardware access and
the equivalent mock interface are exposed through common interfaces, allowing
the same main program logic to operate against either backend.

A mock state seeder is supplied to create deterministic EEPROM and live
register state for automated testing.

| File                         | Explanation                                                                                   |
| ---------------------------- | --------------------------------------------------------------------------------------------- |
| [3CCFGCLI.ASM](3CCFGCLI.ASM) | Reduced scope CLI reimplementation.                                                           |
| [3CHWIF.ASM](3CHWIF.ASM)     | Real hardware interface.                                                                      |
| [3CMOCKIF.ASM](3CMOCKIF.ASM) | Persistent mock backend for development and tests.                                            |
| [3CSEED.ASM](3CSEED.ASM)     | Mock state seeder used to create deterministic test fixtures.                                 |
| [TEST.MK](TEST.MK)           | Smoke test suite orchestration.                                                               |
| [TESTHWL.MK](TESTHWL.MK)     | Test run on an emulated IBM PC compatible constrained system with 64, 128, and 256 KB of RAM. |
| [TESTHWC.MK](TESTHWC.MK)     | Limited EEPROM read and write Hardware Compliance Test.                                       |

## Build

Builds are driven through DOSBox X so the original Borland TASM toolchain can
run in a DOS environment.

This utility was developed on macOS, so that is the currently expected host
environment.

If your host setup differs, set `DOSBOX_BIN` to your DOSBox X executable path
when running [build.sh](build.sh), [test.sh](test.sh), or
[interactive.sh](interactive.sh).

Example:

```sh
DOSBOX_BIN=/custom/path/dosbox-x ./test.sh
```

### Prerequisites

* DOSBox-X installed.

* Wrapper scripts default to
  `/Applications/DOSBox-X.app/Contents/MacOS/dosbox-x` and can be overridden
  by setting `DOSBOX_BIN`.

* The repository contains a local `./TASM` placeholder directory.

* TASM, TLINK, and MAKE are not bundled with this repository. Install them
  separately. The project was built around TASM 5.0, that's what I recommened.

* DOSBox X maps the current working directory as `C:`, so `./TASM` on the host
  corresponds to `\TASM` inside DOSBox X.

* For interactive installation, run [interactive.sh](interactive.sh), which
  starts DOSBox X with `C:` mapped to the current working directory. This
  allows the Borland TASM installer to be run directly from floppy disk
  images and install to `C:\TASM`.

* Alternatively, copy `TASM.EXE`, `TLINK.EXE`, `MAKE.EXE`, `32RTM.EXE`, and
  `DPMI32VM.OVL` into `./TASM/BIN`.

* The repository contains a local `./PKLITE` placeholder directory.

* PKLITE is not bundled with this repository. Install it separately.

* Simply drop PKLITE binaries into `./PKLITE` (`C:\PKLITE` inside DOSBox-X)

* BUILD's MAKEFILE will automatically check for `C:\PKLITE\PKLITE.EXE` and
  create compress the main `3CCFGCLI.EXE` binary.
 

### Build flow

1. Run `./build.sh`.

2. [build.sh](build.sh) starts DOSBox X with
   [autoexec-build](autoexec-build).

3. [autoexec-build](autoexec-build) mounts `C:` from the current working
   directory, then runs `BUILD.BAT`.

4. [BUILD.BAT](BUILD.BAT) deletes the old `BUILD.LOG`, runs:

```text
\TASM\BIN\MAKE ALL >> BUILD.LOG
```

then exits DOSBox X.

5. [MAKEFILE](MAKEFILE) builds:

   * `BIN\3CCFGCLI.EXE`, using `/dREALHW`
   * `BIN\3CHWMOCK.EXE`, using `/dMOCKHW`
   * `BIN\3CSEED.EXE`


6. If PKLITE is available, `BIN\3CCFGCLI.EXE` will automatically be compressed to `BIN\PKLITE\3CCFGCLI.EXE`

7. `build.sh` prints `BUILD.LOG` and a build summary after DOSBox X exits.

### Interactive DOSBox X session

For manual or incremental build and test work, run:

```sh
./interactive.sh
```

This starts DOSBox X with
[autoexec-interactive](autoexec-interactive), mounts the repository root as
`C:`, and leaves you at a DOS prompt instead of running an automatic build or
test command.

From there you can invoke the Borland and TASM tools directly, for example:

```text
\TASM\BIN\MAKE -f MAKEFILE all
\TASM\BIN\MAKE -f TEST.MK smoke
\TASM\BIN\MAKE -f TEST.MK IRQ_CHANGE
```

Or use the included batch files, which are also used for build and test
automation:

```text
\BUILD.BAT
\TEST.BAT
\TEST.BAT IRQ_CHANGE
```

This is useful when iterating on one area and avoiding a complete host side
`./build.sh` or `./test.sh` cycle.

## Test

Tests use the same DOSBox X environment.

The normal test run consists of:

* the regular smoke suite in [TEST.MK](TEST.MK)
* `SAVECONFIG` line length validation
* memory constrained execution with 64, 128, and 256 KB of RAM

### Seeder usage in tests

[3CSEED.ASM](3CSEED.ASM) exists mainly to support deterministic testing. It
prepares mock NIC state in `3C509B.MCK` so tests can begin from known card
profiles, capability overrides, configuration values, and cleanup states.

| Verb           | Description                                                                                 |
| -------------- | ------------------------------------------------------------------------------------------- |
| `INIT`         | Deterministic 3C509B TP profile, IRQ 10, base 0x0300. Default for most tests.               |
| `CLEAR`        | Deletes `3C509B.MCK`.                                                                       |
| `3C509B-TP`    | Product 9050h, media TP.                                                                    |
| `3C509B-COMBO` | Product 9150h, media AUI.                                                                   |
| `3C509B-C`     | Product 9450h, media TP.                                                                    |
| `3C509B-TPO`   | Product 9550h, media TP.                                                                    |
| `3C509B-TPC`   | Product 9850h, media coax.                                                                  |
| `NOPNP`        | INIT plus EEPROM Capability PNP bit clear, preserving the other capability bits.            |
| `PNPREV0`      | INIT plus `EEPROM_REVISION_INFO=0`, retaining EEPROM PNP capability for independence tests. |
| `NOFD`         | INIT plus live TP connector capability clear, while retaining a valid B class revision.     |
| `TPAUI`        | TP product ID plus live TP and AUI connector capabilities, for Product ID mismatch tests.   |
| `TRI`          | TP product ID plus live TP, AUI, and BNC connector capabilities.                            |
| `MODEMFIELDS`  | INIT plus non MODEM Software Information fields set for preservation tests.                 |
| `M1200US`      | INIT plus MODEM raw value `2Fh`, 1200 microseconds, for serialization tests.                |
| `NOLINKBEAT`   | INIT plus `EEPROM_SOFTWARE_INFO` bit 14 set for MODEM preservation tests.                   |

### Test flow

1. Run `./test.sh`.

2. [test.sh](test.sh) starts DOSBox X with
   [autoexec-test](autoexec-test).

3. [autoexec-test](autoexec-test) mounts `C:` from the current working
   directory, then runs `TEST`.

4. [TEST.BAT](TEST.BAT) invokes:

```text
\TASM\BIN\MAKE -f TEST.MK smoke
```

5. [TEST.MK](TEST.MK) runs the smoke groups, writing:

   * summary log, `TEST.LOG`
   * individual test logs, `ARTIFACT/T0xx.LOG`

6. [test.sh](test.sh) validates the generated `RESTORE.BAT` files and ensures
   that individual batch commands do not exceed the practical 128 byte DOS
   command line limit.

7. [test.sh](test.sh) then performs hardware limit checks using
   [autoexec-testhwl](autoexec-testhwl), generating:

   * `ARTIFACT/HWL64.LOG`
   * `ARTIFACT/HWL128.LOG`
   * `ARTIFACT/HWL256.LOG`

   Progress and result information is also appended to `TEST.LOG`.

The smoke suite exercises `BIN\3CHWMOCK.EXE` by default because there is
currently no suitable emulation of a 3Com EtherLink III in DOSBox X, 86Box,
or PCem.


### Running selected test targets

[TEST.BAT](TEST.BAT) defaults to the `smoke` target:

```text
TEST
```

It also accepts one optional argument and forwards it as the
[TEST.MK](TEST.MK) target:

```text
TEST IRQ_CHANGE
TEST SAVECONFIG_TEST
TEST t0203
```

This allows direct execution of any target defined in [TEST.MK](TEST.MK),
including symbolic test groups such as `LISTING`, `IRQ_CHANGE`,
`SAVECONFIG_TEST`, or individual test cases such as `t0101`.

Some tests depend on previously seeded mock state. The complete `smoke` target
begins with `prep` and executes the groups in their intended order.

Individual targets are therefore primarily intended for manual debugging and
development work.

### Running tests against real hardware

The same smoke suite can be executed against the real hardware binary from
vanilla DOS using:

```text
\TASM\BIN\MAKE -f TEST.MK real
```

The target system must provide:

* `MAKE.EXE` at `\TASM\BIN\MAKE`
* `TEST.MK` in the current working directory
* `3CCFGCLI.EXE` at `\BIN\3CCFGCLI.EXE`

If the executable is stored elsewhere, the default `real` target cannot be
used directly.

Supply `BINAPP` explicitly instead:

```text
\TASM\BIN\MAKE -f TEST.MK BINAPP=\CLI\3CCFGCLI.EXE smoke
```

## AI Development Transparency

This project was developed with assistance from large language models.

AI tools were used for code review, reasoning about 8086 and 8088 assembly,
comparison with the original 3Com utility, identification of possible defects
and cleanup opportunities, preparation of implementation plans, and review of
proposed changes.

Development remains human directed. Design decisions, compatibility goals,
feature scope, implementation choices, and acceptance of changes remain under
the control of the maintainer. AI generated suggestions are treated as
engineering and review aids, not as substitutes for verification.

More details about the development and validation process are available in
[DEVELOPMENT.md](DEVELOPMENT.md).

## References

* [3C509B nestor, project context and upstream ideas](https://github.com/hackerb9/3C509B-nestor)
* Wikipedia, [3Com EtherLink III](https://en.wikipedia.org/wiki/3Com_3c509)
* [3Com EtherLink III User's Guide](https://archive.org/details/09-1310-000)
* [3Com EtherLink III technical reference](https://www.janwagemakers.be/PIC18F452_3COM_3C509B_Ethernet/3c5x9b.pdf)
* [Original 3Com 3C509 configuration utilities](3C5X9CFG)