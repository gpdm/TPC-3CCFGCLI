# 3CCFG CLI

```
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  EXPERIMENTAL RELEASE — LIMITED HARDWARE TESTING                                  |
|                                                                                   |
|  This release has only undergone limited testing on physical hardware.            |
|  It has been developed and primarily verified using the software mock backend.    |
|                                                                                   |
|  Bugs and unexpected behaviors may be present.                                    |
|  USE ENTIRELY AT YOUR OWN RISK.                                                   |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

## Overview

This project is a compact CLI-only reimplementation of the 3Com EtherLink III
configuration utility for early DOS systems, especially 8-bit ISA machines
with 8086/8088-class CPUs.

The goal is not a literal code port. Instead, a new codebase was built from
analysis of the original 3Com EtherLink III Configuration Utility v3.2.

On many authentic retro systems, the original utility was still too heavy:
even though it was eventually adapted to run also on 8086/8088 CPUs,
the bundled text-mode UI and its memory footprint pushed the RAM
requirement beyond 256 KB RAM.

This becomes a problem for retro collectors and enthusiasts who prefer to
not expand their original systems to the limit.

The practical workaround is to preconfigure the network card on a different system
using the stock `3C5x9CFG.EXE` utility, then move the adapter into the target machine.


## Rationale

- Keep the reimplemented utility small enough to run in 256 KB or less of RAM
- Focus on CLI behavior only; No text-mode UI
- Preserve the configuration-related CLI verbs
- Support development and verification through a mock backend.


## Implementation status

This reimplementation is intentionally CLI-only. It does not aim to reproduce the
original text UI, nor all CLI verbs supported by the original `3C5x9CFG.EXE` utility.
Therefore it does not include other functions like the `echo server` by intention.

Current task notes and open follow-ups are tracked in [TODO.TXT](TODO.TXT).

The new implementation currently covers:

- `HELP`
- `LIST`
- `CONFIGURE`
- `SAVECONFIG file` (exports a restore batch file for all installed adapters)

Supported `CONFIGURE` subverbs include:

- `/ADAPTERNUM`
- `/INT`
- `/IOBASE`
- `/PNP`
- `/FULLDUPLEX`
- `/TR`
- `/XCVR`
- `/MODEM`
- `/OPTIMIZE`
- `/BADDRESS`
- `/BSIZE`
- `/VERBOSE` (new enhancement)

## Where 3CCFGCLI differs

`3CCFGCLI` saw some changes and extensions compared to the reference implementation,
or skipped reimplementation of some features altogether.


### Not Implemented Features

The orignal `3C5C9CFG.EXE` implemented many more features that those found in the
current reimplementations.
The following list of features and functionalities were deliberately skipped in the implementation.

- MEWEL-based Text-mode UI
- EISA and MCA support (including /SLOT configuration subverb)
- `/LANGUAGE` CLI verb
- `/ECHOSERVER` CLI verb
- `/RUN` CLI verb

### /LINKBEAT configuration verb

`CONFIGURE /LINKBEAT` was investigated across the available reference utility
versions. Version 3.2 still lists both `/LINKBEAT` and `/SYNCREADY` in its HELP
text, but neither command branches to an implementation. Version 3.0 has the
same behavior. Version 2.1 contains an active `/LINKBEAT` parser branch.

The 3C509B technical reference identifies Link Beat Disable as bit 14 of the
EEPROM Software Information word (offset 0Dh). This persistent setting directs
the network driver to set or clear bit 7 of the Media Type and Status register
(Window 4, port 0Ah) when it initializes the adapter. The register value is
live; the EEPROM policy that directs the driver is retained across power cycles.

`CONFIGURE /LINKBEAT` is not yet implemented in `3CCFGCLI`. The `LIST` command
retains its `Link Status` ("Link Beat") display, as described below.

### /SYNCREADY configuration verb

Version 3.x and 2.1 of `3C5X9CFG.EXE` advertise also a `/SYNCREADY` configuration verb
in its HELP text, although it doesn't branch into actual code.

This is still under analysis, see also [TODO.TXT](TODO.TXT).

### /CONFIGPORT configuration verb

`/CONFIGPORT` is an ISA-only workaround parameter in the original utility. Per
its HELP text, it is used only if the program has trouble running on the
target machine, and accepts an I/O address in the 100h-1E0h range (in
increments of 10h) to relocate the adapter's ID port used during EEPROM/ISA
probing. It does not configure a persistent adapter setting.

`CONFIGURE /CONFIGPORT` is not implemented in `3CCFGCLI` at this time.


### /VERBOSE configuration verb

`/VERBOSE` is a diagnostic aid. It prints additional EEPROM and live-register
read/write detail so transactions can be traced while debugging hardware
behavior, mock-state issues, or parser/transaction sequencing.

### SAVECONFIG command verb

`SAVECONFIG [filename.bat] [/EXECFILE:program]` reads the persistent configuration
of every installed adapter with an active IOBASE and writes a batch file with
one `program CONFIGURE /ADAPTERNUM:N ...` restore line per adapter.

`program` defaults to this executable; `/EXECFILE` overrides it with any literal text,
including a DOS batch parameter placeholder like `%1`, so a restore batch can
instead replay through the original 3Com utility.
It exports the implemented persistent settings only and does not modify any
adapter. This is handy for storing your last configuration, but is mainly used
internally for the standalone hardware conformance tests.


### Enhanded LIST verb

The `LIST` verb was also extended beyond the original implementation.
Because the text-mode UI is intentionally absent, the `LIST` display now
includes additional configuration and status details, including current `Link Status`
("Link Beat").

Here's an example:

```text
3Com EtherLink III CLI Configuration Program v0.6.8
by The Phintage Collector (Gianpaolo Del Matto)
https://github.com/gpdm/TPC-3CCFGCLI
reimplementation of the original 3Com EtherLink III Configuration Utility v3.2

NIC                            NIC
Number                       Description
--------------------------------------------------------------------------
  1    3Com 3C509B-TP: Ethernet Address = 02608C654321
       EtherLink III 16-bit ISA NIC
       IOBASE = 0300, IRQ = 10
       ASIC Revision = 4
       Transceiver = on-board TP
       Plug and Play Capability = enabled
       Boot ROM = disabled
       Software Compatibility = failure level 0, warning level 0
       Optimization = DOS
       Modem Speed = none
       Full Duplex = disabled
       Link Status = connected
```

## How it works

The code is split into several assembly modules. The CLI logic stays in one place, hardware access and an equivalent mock interface are isolated behind generic interfaces.
A mock-state seeder utility is supplied to mimic the hardware EEPROM and live registers
for smoke testing.

| File | Explanation |
| --- | --- |
| [3CCFGCLI.ASM](3CCFGCLI.ASM) | Reduced-scope CLI reimplementation. |
| [3CHWIF.ASM](3CHWIF.ASM) | Real hardware interface. |
| [3CMOCKIF.ASM](3CMOCKIF.ASM) | Persistent mock backend for development and tests. |
| [3CSEED.ASM](3CSEED.ASM) | Mock-state seeder used to create test fixtures. |
| [TEST.MK](TEST.MK) | Smoke-test suite orchestration. |

## Build

Builds are driven through DOSBox-X so the original Borland/TASM toolchain can
run in a DOS environment.

This utility was developed on macOS, so that's what's currently expected.
If your host setup differs, set `DOSBOX_BIN` to your DOSBox-X executable path
when running [build.sh](build.sh), [test.sh](test.sh), or
[interactive.sh](interactive.sh).

Example:

`DOSBOX_BIN=/custom/path/dosbox-x ./test.sh`


### Prerequisites

- DOSBox-X installed.
- Wrapper scripts default to
  `/Applications/DOSBox-X.app/Contents/MacOS/dosbox-x` and can be overridden
  by setting `DOSBOX_BIN`.
- The repository contains a local `./TASM` placeholder directory.
- TASM/TLINK/MAKE are **not** bundled with this repository; install them yourself.
- DOSBox-X maps the current working directory as `C:`, so `./TASM` on the host
  corresponds to `\TASM` in DOSBox-X.
- Ensure `MAKE.EXE` is available at `\TASM\BIN\MAKE` (plus `TASM.EXE` and
  `TLINK.EXE` in the same toolchain tree).
- For interactive installation, run [interactive.sh](interactive.sh), which
  starts DOSBox-X with `C:` mapped to the current working directory.
  This allows running the Borland TASM installer directly from floppy disk images.
- Alternatively, just copy `TASM.EXE`, `TLINK.EXE`, `MAKE.EXE`, `32RTM.EXE` and
  `DPMI32VM.OVL` into `./TASM/BIN`.


### Build flow

1. Run `./build.sh`.
2. [build.sh](build.sh) starts DOSBox-X with [autoexec-build](autoexec-build).
3. [autoexec-build](autoexec-build) mounts `C:` from the current working directory
   then runs `BUILD.BAT`.
4. [BUILD.BAT](BUILD.BAT) deletes old `BUILD.LOG`, runs
   `\TASM\BIN\MAKE ALL >> BUILD.LOG`, then exits DOSBox-X.
5. [MAKEFILE](MAKEFILE) builds:
   - `BIN\3CCFGCLI.EXE` (`/dREALHW`)
   - `BIN\3CHWMOCK.EXE` (`/dMOCKHW`)
   - `BIN\3CSEED.EXE`
6. `build.sh` prints `BUILD.LOG` after DOSBox-X exits.


## Test

Tests use the same DOSBox-X pattern and run:

- the regular smoke suite in [TEST.MK](TEST.MK)
- a hardware-limit follow-up pass (64 KB, 128 KB, 256 KB)

### Seeder usage in tests

[3CSEED.ASM](3CSEED.ASM) exists mainly to support deterministic testing. It
prepares mock NIC state (`3C509B.MCK`) so smoke tests can start from known card
profiles, capability overrides, and cleanup states.

| Verb | Description |
|------|-------------|
| `INIT` | Deterministic 3C509B-TP profile (IRQ 10, base 0x0300). Default for most tests. |
| `RANDOM` | Random real-model card. Always PNP+FD capable. |
| `CLEAR` | Deletes `3C509B.MCK`. |
| `3C509B-TP` | Product 9050h, media=TP. |
| `3C509B-COMBO` | Product 9150h, media=AUI. |
| `3C509B-C` | Product 9450h, media=TP. |
| `3C509B-TPO` | Product 9550h, media=TP. |
| `3C509B-TPC` | Product 9850h, media=coax. |
| `NOPNP` | INIT + EEPROM Capability PNP bit clear; preserves the other capability bits. |
| `PNPREV0` | INIT + `EEPROM_REVISION_INFO=0`; retains EEPROM PNP capability for independence tests. |
| `NOFD` | INIT + live TP connector capability clear; the B-class revision remains valid. |
| `TPAUI` | TP product ID + live TP/AUI connector capabilities, for Product-ID mismatch tests. |
| `TRI` | TP product ID + live TP/AUI/BNC connector capabilities. |
| `NOLINKBEAT` | INIT + `EEPROM_SOFTWARE_INFO` bit 14 set for MODEM preservation tests. |


### Test flow

1. Run `./test.sh`.
2. [test.sh](test.sh) starts DOSBox-X with [autoexec-test](autoexec-test).
3. [autoexec-test](autoexec-test) mounts `C:` from the current working directory,
   then runs `TEST`.
4. [TEST.BAT](TEST.BAT) invokes `\TASM\BIN\MAKE -f TEST.MK smoke`.
5. [TEST.MK](TEST.MK) runs the smoke groups, writing:
   - summary log: `TEST.LOG`
   - per-test logs: `ARTIFACT/T0xx.LOG`
6. [test.sh](test.sh) then runs hardware-limit checks using
   [autoexec-testhwl](autoexec-testhwl), generating:
   - `ARTIFACT/HWL64.LOG`
   - `ARTIFACT/HWL128.LOG`
   - `ARTIFACT/HWL256.LOG`
   and appending progress lines to `TEST.LOG`.


Notes:

The smoke target exercises `BIN\3CHWMOCK.EXE` by default.
There's currently no emulation of a 3Com EtherLink III in DOSBox-X, neither in 86Box or pcem.
The hardware-limit phase is fail-fast: it stops immediately on the first memory
step that does not report a PASS marker.

To run the test suite against real hardware, see next section.


### Running tests against real hardware

You can run the same smoke suite against the real-hardware binary by invoking
the specific `real` target from vanilla DOS instead:

`\TASM\BIN\MAKE -f TEST.MK real`

For this to work on the target system you must have:

- `MAKE.EXE` available at `\TASM\BIN\MAKE`.
- `TEST.MK` present in the current working directory.
- `3CCFGCLI.EXE` available at `\BIN\3CCFGCLI.EXE`.

If your executable is not in the default path expected by
[TEST.MK](TEST.MK), you can't run `make real`.
In this case, use an explicit override as shown below:

`\TASM\BIN\MAKE -f TEST.MK BINAPP=\CLI\3CCFGCLI.EXE smoke`


## References

- [Project context and upstream ideas](https://github.com/hackerb9/3C509B-nestor)
- [3Com EtherLink III User's Guide](https://archive.org/details/09-1310-000)
- [3Com EtherLink III technical reference](https://www.janwagemakers.be/PIC18F452_3COM_3C509B_Ethernet/3c5x9b.pdf)
- Original [3Com 3C509 configuration utilities](3C5X9CFG)
