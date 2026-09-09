# Hardware Compliance Tests

## Overview

The hardware compliance suite validates `3CCFGCLI` against real 3Com EtherLink III hardware.

It is deliberately separate from the normal mock based regression suite. The goal is to test the program against the physical adapter, real EEPROM contents, live hardware state, and, where possible, the original 3Com Configuration and Diagnostic Program version 3.2.

The suite has two complementary directions.

* `READ`, the original 3Com utility establishes known hardware states, `3CCFGCLI` reads them back.
* `CONFIG`, `3CCFGCLI` performs the hardware writes, then the resulting state is checked first through a fresh `3CCFGCLI LIST` process and finally through a configuration dump created by the original 3Com utility.

Boot ROM testing is separated into the optional `READROM` and `ROMCONFIG` modes because it requires suitable physical Boot ROM hardware.

```text
                         +=======================+
                         |      HWCTEST.BAT      |
                         |  common entry point   |
                         +===========+===========+
                                     |
                                     v
                         +=======================+
                         |   3CCFGCLI.EXE LIST   |
                         | detect adapter model  |
                         +===========+===========+
                                     |
                  +==================+==================+
                  |                                     |
                  v                                     v
          +===============+                     +===============+
          |   READ path   |                     |  CONFIG path  |
          +=======+=======+                     +=======+=======+
                  |                                     |
                  v                                     v
          +===============+                     +===============+
          |  HWCREAD.MK   |                     |  HWCWRITE.MK  |
          +=======+=======+                     +=======+=======+
                  |                                     |
                  |                                     |
      original 3Com utility                     original 3Com utility
      establishes known state                   establishes baseline
                  |                                     |
                  v                                     v
          3CCFGCLI LIST and                     3CCFGCLI CONFIGURE
          SAVECONFIG readback                           |
                  |                                     v
                  |                              fresh 3CCFGCLI LIST
                  |                                     |
                  |                                     v
                  |                              final known test state
                  |                                     |
                  |                                     v
                  |                              STUFFIT drives the
                  |                              original 3Com utility
                  |                                     |
                  |                                     v
                  |                              vendor configuration
                  |                              dump saved as .SET
                  |                                     |
                  |                                     v
                  |                              HWCWRITE.MK verifier
                  |                              checks vendor dump
                  |                                     |
                  +==================+==================+
                                     |
                                     v
                         +=======================+
                         |   logs and artifacts  |
                         |   under ARTIFACT\     |
                         +=======================+
```

The test scripts intentionally use conservative DOS batch and MAKE syntax. They are written to remain usable on early DOS installations, including MS DOS 3.x and 4.x, and with Borland MAKE 3.0.

No memory manager such as `HIMEM.SYS` is required. This is intentional. The hardware compliance environment should contain as little unrelated software as practical, so memory managers and other resident software do not become additional variables in the test.

The suite is fail fast. Each assertion uses the DOS command result returned to MAKE. If a required value is not found, MAKE stops at that point and `HWCTEST.BAT` returns a nonzero DOS `ERRORLEVEL`.

### Entry points

```text
HWCTEST.BAT READ
HWCTEST.BAT READROM
HWCTEST.BAT CONFIG
HWCTEST.BAT ROMCONFIG
```

`READ` tests the `3CCFGCLI` hardware read path.

`READROM` performs only the physical Boot ROM read compliance test.

`CONFIG` tests the `3CCFGCLI CONFIGURE` hardware write path and performs a final independent cross check using a configuration dump from the original 3Com utility.

`ROMCONFIG` performs the corresponding Boot ROM write test and vendor dump verification.

The current scripts operate on adapter number 1.

## HWCTEST.BAT

`HWCTEST.BAT` is the common entry point and orchestration layer.

It first creates the `ARTIFACT` directory when necessary, removes the previous top level test log and old `.SET` vendor dumps, then runs:

```text
3CCFGCLI.EXE LIST
```

The resulting output is stored in:

```text
ARTIFACT\HWCTEST.LOG
```

The batch file identifies the installed adapter model from this output and selects the corresponding card specific MAKE target.

The currently recognized models are:

* `3C509B TP`
* `3C509B COAX`
* `3C509B Combo`
* `3C509B TPO`
* `3C509B TPCoax`
* `3C509 TP`
* `3C509 COAX`
* `3C509 Combo`
* `3C509 TPO`
* `3C509 TPCoax`

Depending on the command line mode, `HWCTEST.BAT` dispatches either `HWCREAD.MK` or `HWCWRITE.MK`.

Conceptually:

```text
READ       => HWCREAD.MK   => hwcr
READROM    => HWCREAD.MK   => hwcr-rom
CONFIG     => HWCWRITE.MK  => hwcw
ROMCONFIG  => HWCWRITE.MK  => hwcw-rom
```

The detected model is appended to the selected target name. For example, a normal write compliance run on a 3C509B TPCoax invokes:

```text
MAKE -fHWCWRITE.MK hwcw-btpc
```

### Post configuration vendor dump

After a successful `CONFIG` or `ROMCONFIG` run, `HWCTEST.BAT` performs an additional independent cross check.

The original `3C5X9CFG` utility does not offer a command line readback mode, but its interactive user interface can save the current adapter configuration to a text based `.SET` file.

`HWCTEST.BAT` uses `STUFFIT` to queue the required keyboard input, then launches:

```text
3C5X9CFG
```

The automated UI sequence saves one of these files:

```text
ARTIFACT\hwcw.SET
ARTIFACT\hwcw-rom.SET
```

The batch file then invokes `HWCWRITE.MK` a second time with the matching verification target, for example:

```text
MAKE -fHWCWRITE.MK hwcw-btpc-vrfy
```

This final stage is important because it provides a vendor tool cross check of the configuration written by `3CCFGCLI`.

The individual write tests use `3CCFGCLI LIST` for immediate readback. The final `.SET` verification additionally confirms that the original 3Com utility decodes the resulting physical adapter configuration as expected.

## HWCREAD.MK

`HWCREAD.MK` tests the read side of `3CCFGCLI`.

In this suite, `3CCFGCLI` does not establish the test configuration. Known states are written by the original 3Com `3C5X9CFG.EXE` version 3.2 utility, then read through `3CCFGCLI`.

Before modifying the adapter, the original configuration is saved through:

```text
3CCFGCLI SAVECONFIG
```

This creates:

```text
ARTIFACT\HWCRREST.BAT
```

The suite then establishes a deterministic model specific baseline using the original 3Com utility.

The normal read suite covers:

* adapter identity and capabilities
* interrupt request level
* I/O base address
* Plug and Play state, where supported
* MODEM interrupt disable timing
* Full Duplex state, where supported
* optimization mode
* transceiver selection
* combined state serialization through `SAVECONFIG`

The common test values are:

```text
IRQ          3
I/O base     0280
MODEM        1200 baud, 1300 microseconds
OPTIMIZE     SERVER
PNP          DISABLED, where supported
FULLDUPLEX   DISABLED, where supported
```

Transceiver tests are model specific. The suite selects a valid alternate connector for the detected adapter.

The final normal read test uses `SAVECONFIG` and verifies that the accumulated physical hardware state is serialized with the expected values.

### Optional Boot ROM read test

`READROM` performs a separate physical Boot ROM test.

The current test configuration is:

```text
Boot ROM address   C8000
Boot ROM size      16K
```

The original 3Com utility writes the Boot ROM configuration. `3CCFGCLI LIST` and `SAVECONFIG` then verify the resulting state.

The current Boot ROM targets are defined for:

* `3C509B TP`
* `3C509B COAX`
* `3C509B Combo`
* `3C509B TPCoax`

## HWCWRITE.MK

`HWCWRITE.MK` tests the physical `3CCFGCLI CONFIGURE` write path.

The original 3Com utility is used only to establish deterministic starting states. The configuration under test is then written by `3CCFGCLI`.

Each individual write is followed by a new `3CCFGCLI LIST` process. This verifies that the resulting persistent hardware state can be rediscovered after the `CONFIGURE` process has exited.

The normal write suite covers:

* `/INT`
* `/IOBASE`
* `/PNP`, where supported
* `/MODEM`
* `/FULLDUPLEX`, where supported
* `/OPTIMIZE`
* `/TR`, using a model specific valid connector
* one combined multi property `CONFIGURE` transaction

The combined transaction first reestablishes the common defaults with the original utility, then writes the common test values in one `3CCFGCLI CONFIGURE` invocation:

```text
/INT:3
/IOBASE:0280
/MODEM:1200
/OPTIMIZE:SERVER
```

This intentionally leaves the adapter in a clear final test state for the subsequent vendor configuration dump.

### Vendor configuration dump verification

After the normal MAKE run returns successfully, `HWCTEST.BAT` creates:

```text
ARTIFACT\hwcw.SET
```

using the original 3Com utility.

The second MAKE invocation checks the vendor dump against the expected final state.

Common checks include:

```text
I/O base address              280
Interrupt request level       3
Network driver optimization   server
Maximum interrupt disable     1300 microseconds
```

Additional assertions are selected according to the detected adapter.

These include, where applicable:

```text
Plug and Play Capability      disabled
Full Duplex                   disabled
Transceiver type              on-board TP
Transceiver type              on-board coax
Transceiver type              external
```

This is the strongest cross check in the write suite because the final configuration is decoded by the original 3Com utility rather than only by `3CCFGCLI` itself.

### Optional Boot ROM write test

`ROMCONFIG` tests the physical Boot ROM configuration write path.

The current test configuration is:

```text
Boot ROM address   C8000
Boot ROM size      16K
```

`3CCFGCLI` writes the configuration and a fresh `3CCFGCLI LIST` verifies the immediate state.

After that, `HWCTEST.BAT` creates:

```text
ARTIFACT\hwcw-rom.SET
```

through the original 3Com utility and invokes the corresponding ROM verification target.

The ROM dump verifier expects the deterministic non ROM baseline plus the configured Boot ROM address and size.

The exact Boot PROM text matching in the current verifier is provisional. It is extrapolated from the configuration file naming used by the original utility and should be confirmed against a real `ROMCONFIG` dump once suitable hardware is available.

## Configuration preservation

Both MAKE files save the adapter configuration before destructive testing begins.

The restore batch files are:

```text
ARTIFACT\HWCRREST.BAT
ARTIFACT\HWCWREST.BAT
```

The generated restore commands use a replaceable executable argument so the saved configuration can be replayed with the original 3Com utility.

Automatic restoration is intentionally not performed from MAKE because command invocation through MAKE is unreliable on some earlier DOS versions.

At the end of a run the suite prints the command that should be executed manually to restore the original adapter configuration.

This also means that a failed run may leave the adapter in an intermediate test state. The saved restore batch should be retained until the original configuration has been restored.

## Logs and artifacts

The suite keeps orchestration, per test evidence, generated restore files, and vendor dumps separate.

Important files include:

```text
ARTIFACT\HWCTEST.LOG

HWCREAD.LOG
ARTIFACT\HWCR001.LOG
ARTIFACT\HWCR002.LOG
...
ARTIFACT\HWCR010.LOG
ARTIFACT\HWCRREST.BAT

HWCWRITE.LOG
ARTIFACT\HWCW001.LOG
ARTIFACT\HWCW002.LOG
...
ARTIFACT\HWCW009.LOG
ARTIFACT\HWCWREST.BAT

ARTIFACT\hwcw.SET
ARTIFACT\hwcw-rom.SET
```

`HWCTEST.LOG` records initial adapter detection and dispatch information.

`HWCREAD.LOG` and `HWCWRITE.LOG` record suite progress and completion.

The numbered `HWCR` and `HWCW` logs contain the command output associated with individual compliance checks.

The `.SET` files are configuration dumps generated by the original 3Com utility and are consumed by the final write verification targets.

## Dependencies

The hardware compliance suite requires:

* a physical supported 3Com EtherLink III adapter
* `3CCFGCLI.EXE`
* the original 3Com Configuration and Diagnostic Program, `3C5X9CFG.EXE`, version 3.2
* Borland MAKE 3.0
* `STUFFIT`, version 3.10, from `stuff310.zip`
* DOS with the standard commands used by the scripts, including `FIND`
* a suitable physical Boot ROM for `READROM` and `ROMCONFIG`

The scripts are intentionally kept compatible with early DOS environments, including MS DOS 3.x and 4.x.

They do not require `HIMEM.SYS`, an XMS manager, an EMS manager, or another memory manager. Avoiding such dependencies is deliberate, the hardware test should run with as little unrelated resident software as possible.

The original `3C5X9CFG.EXE` version 3.2 utility is required for both directions of compliance testing.

For READ testing it establishes the reference hardware state.

For CONFIG testing it establishes deterministic baselines and provides the final independent configuration dump used to cross check the state written by `3CCFGCLI`.

## Links


### STUFFIT 3.10

Download from Simtel MS DOS keyboard utilities archive:
http://ftp.oldskool.org/pub/simtelnet/msdos/keyboard/stuff310.zip