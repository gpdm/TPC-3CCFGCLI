# Hardware Compliance Tests

## Overview

The hardware compliance suite validates `3CCFGCLI` against real 3Com EtherLink III hardware.

It is deliberately separate from the normal mock based regression suite. Its purpose is to exercise the program against a physical adapter, real EEPROM contents, live adapter state, and the original 3Com Configuration and Diagnostic Program.

The suite has two complementary directions.

* `READ`, the original 3Com utility establishes known hardware states, then `3CCFGCLI` reads them through `LIST` and `SAVECONFIG`.
* `WRITE`, `3CCFGCLI` performs the hardware writes, then a fresh `3CCFGCLI LIST` process reads the resulting persistent state back.

`READROM` and `WRITEROM` run the corresponding full suite with the `ROM_TEST` make definition enabled. Boot ROM test recipes exist in both MAKE files, but the current card mappings do not yet select those recipes. Current ROM runs therefore report `NOT IMPLEMENTED` for the supported models, and `NOT SUPPORTED` for the 3C509B TPO.

After every successful READ or WRITE make run, `HWCTEST.BAT` also starts the original 3Com utility through `STUFFIT` and saves a post configuration `.SET` dump. The current implementation checks that this dump was created, but it does not parse or verify its contents.

```text
                         +=======================+
                         |      HWCTEST.BAT      |
                         |  common entry point   |
                         +===========+===========+
                                     |
                                     v
                         +=======================+
                         |   3CCFGCLI.EXE LIST   |
                         |    HWCINIT.LOG        |
                         +===========+===========+
                                     |
                                     v
                         +=======================+
                         | detect adapter model  |
                         | select card macro     |
                         +===========+===========+
                                     |
                  +==================+==================+
                  |                                     |
                  v                                     v
          +===============+                     +===============+
          |   READ path   |                     |  WRITE path   |
          +=======+=======+                     +=======+=======+
                  |                                     |
                  v                                     v
          +===============+                     +===============+
          |  HWCREAD.MK   |                     |  HWCWRITE.MK  |
          | target hwcr   |                     | target hwcw   |
          +=======+=======+                     +=======+=======+
                  |                                     |
      3C5X9CFG establishes                    3C5X9CFG establishes
      known hardware states                   deterministic baseline
                  |                                     |
                  v                                     v
      3CCFGCLI LIST and                       3CCFGCLI CONFIGURE
      SAVECONFIG readback                              |
                  |                                     v
                  |                            fresh 3CCFGCLI LIST
                  |                                     |
                  +==================+==================+
                                     |
                                     v
                         +=======================+
                         | successful MAKE run   |
                         +===========+===========+
                                     |
                                     v
                         +=======================+
                         | STUFFIT + 3C5X9CFG    |
                         | save post state .SET  |
                         +===========+===========+
                                     |
                                     v
                         +=======================+
                         | card specific logs    |
                         | and ARTIFACT folder   |
                         +=======================+
```

The scripts intentionally use conservative DOS batch and MAKE syntax. They are intended to remain usable on early DOS installations and with Borland MAKE 3.0.

No memory manager such as `HIMEM.SYS` is required. Keeping the hardware compliance environment small is intentional, so unrelated resident software does not become another variable in the test.

The MAKE based checks are fail fast. Assertions use the DOS command result returned by commands such as `FIND`. A failed assertion stops MAKE, `HWCTEST.BAT` detects the nonzero result, and the batch file deliberately leaves a nonzero DOS `ERRORLEVEL`.

The current scripts operate on adapter number 1.

## Entry points

The supported batch entry points are:

```text
HWCTEST.BAT READ
HWCTEST.BAT READROM
HWCTEST.BAT WRITE
HWCTEST.BAT WRITEROM
```

`READ` runs the normal hardware read compliance suite.

`READROM` runs the same complete READ suite with `ROM_TEST` defined. It is not a ROM only run.

`WRITE` runs the normal hardware write compliance suite.

`WRITEROM` runs the same complete WRITE suite with `ROM_TEST` defined. It is not a ROM only run.

The current help text in `HWCTEST.BAT` prints `WRITEPROM` in its usage list. The actual dispatch label and working command are `WRITEROM`.

Conceptually, the dispatch is:

```text
READ       => HWCREAD.MK    + CARD_<model>             => hwcr
READROM    => HWCREAD.MK    + CARD_<model> + ROM_TEST  => hwcr
WRITE      => HWCWRITE.MK   + CARD_<model>             => hwcw
WRITEROM   => HWCWRITE.MK   + CARD_<model> + ROM_TEST  => hwcw
```

For example, a normal WRITE run on a detected 3C509B TPCoax invokes the equivalent of:

```text
MAKE -fHWCWRITE.MK -DCARD_BTPC hwcw
```

The corresponding ROM mode adds:

```text
-DROM_TEST
```

## HWCTEST.BAT

`HWCTEST.BAT` is the common entry point and orchestration layer.

### Initial hardware scan

At startup the batch file initializes:

```text
LOGFILE=HWCINIT.LOG
DETECTED_NIC=UNKNOWN
```

Any previous `HWCINIT.LOG` is removed, then the batch file runs:

```text
3CCFGCLI.EXE LIST > HWCINIT.LOG
```

This initial LIST output is used only for adapter detection and as the beginning of the final suite log.

### Recognized adapter models

The current batch file recognizes these six models:

| Detection text from `3CCFGCLI LIST` | Batch card code | MAKE definition | MAKE card type | Model name used by MAKE |
| ----------------------------------- | --------------- | --------------- | -------------- | ----------------------- |
| `3Com 3C509B-TP:`                   | `BTP`           | `CARD_BTP`      | `btp`          | `3C509B-TP`             |
| `3Com 3C509B:`                      | `BCOAX`         | `CARD_BCOAX`    | `bcoax`        | `3C509B-COAX`           |
| `3Com 3C509B-Combo:`                | `BCOMBO`        | `CARD_BCOMBO`   | `bcombo`       | `3C509B-Combo`          |
| `3Com 3C509B-TPO:`                  | `BTPO`          | `CARD_BTPO`     | `btpo`         | `3C509B-TPO`            |
| `3Com 3C509B-TPCoax:`               | `BTPC`          | `CARD_BTPC`     | `btpc`         | `3C509B-TPCoax`         |
| `3Com 3C509-TP:`                    | `TP`            | `CARD_TP`       | `tp`           | `3C509-TP`              |

Other EtherLink III model strings are currently rejected as unsupported.

The detection order checks the more specific 3C509B model strings before the generic `3Com 3C509B:` string.

### Card specific output paths

After detection, the batch file switches from the temporary `HWCINIT.LOG` to a card specific output directory.

For example, a detected `BTP` card uses:

```text
BTP\HWCREAD.LOG
BTP\HWCWRITE.LOG
BTP\ARTIFACT\
```

The batch file creates the card directory and its `ARTIFACT` subdirectory when necessary.

The initial `HWCINIT.LOG` is copied to the selected main log and then deleted. The MAKE files derive their own paths from the lower case card type, for example `btp\HWCREAD.LOG`. DOS path matching is case insensitive, so these refer to the same location.

### MAKE dispatch

The batch file invokes one generic MAKE target and supplies the detected card as a make definition.

Examples:

```text
MAKE -fHWCREAD.MK -DCARD_BTP hwcr
MAKE -fHWCWRITE.MK -DCARD_BTPC hwcw
```

ROM mode keeps the same target and adds `ROM_TEST`:

```text
MAKE -fHWCREAD.MK -DCARD_BTP -DROM_TEST hwcr
MAKE -fHWCWRITE.MK -DCARD_BTPC -DROM_TEST hwcw
```

Model specific differences are resolved while the MAKE file is parsed. An unknown or missing card definition triggers `!error No valid card model selected` before hardware testing starts.

### Post configuration vendor dump

After a successful MAKE run, `HWCTEST.BAT` always creates a configuration dump with the original 3Com utility. This happens after READ, READROM, WRITE, and WRITEROM.

The batch file first clears queued keyboard input:

```text
stuffit 0
```

It then loads a keyboard macro, starts:

```text
3c5x9cfg
```

and saves the current adapter state to:

```text
<card>\ARTIFACT\hwcr.SET
```

for READ and READROM, or:

```text
<card>\ARTIFACT\hwcw.SET
```

for WRITE and WRITEROM.

ROM mode does not use a separate `.SET` filename because the MAKE target remains `hwcr` or `hwcw`.

The current batch file only checks whether the expected `.SET` file exists. There is no second MAKE invocation and no current `.SET` content verifier.

The `.SET` file should therefore be treated as captured vendor evidence of the final hardware state, not as an asserted test result.

### Batch result handling

If MAKE returns a nonzero result, or if the post configuration `.SET` file was not created, the batch file enters its failure path.

The failure path appends a failure message to the selected main log and runs a deliberately unsuccessful `FIND` for `HWC-FAILURE-SENTINEL` so DOS retains a nonzero `ERRORLEVEL`.

On success, the batch file appends the pass message and runs:

```text
FIND "3Com " <main log> > NUL
```

against text known to exist in the initial successful LIST output, resetting `ERRORLEVEL` to zero.

## Common configuration values

`HWCREAD.MK` and `HWCWRITE.MK` currently use the same baseline values and the same primary test values.

### Baseline values

The common deterministic baseline is:

```text
IRQ          10
I/O base     0300
MODEM        NONE
OPTIMIZE     DOS
Transceiver  TP
```

The 3C509B COAX overrides the default transceiver to:

```text
Transceiver  AUI
```

Model specific baseline settings are:

| Card            | PNP baseline  | Full Duplex baseline   | Boot ROM baseline                |
| --------------- | ------------- | ---------------------- | -------------------------------- |
| `3C509B-TP`     | `ENABLED`     | `DISABLED`             | `BSIZE:DISABLED`                 |
| `3C509B-COAX`   | `ENABLED`     | not issued             | `BSIZE:DISABLED`                 |
| `3C509B-Combo`  | `ENABLED`     | `DISABLED`             | `BSIZE:DISABLED`                 |
| `3C509B-TPO`    | `ENABLED`     | not issued by baseline | not issued, Boot ROM unsupported |
| `3C509B-TPCoax` | `ENABLED`     | `DISABLED`             | `BSIZE:DISABLED`                 |
| `3C509-TP`      | not supported | not supported          | `BSIZE:DISABLED`                 |

All baseline writes are performed through the original `3C5X9CFG.EXE` utility.

### Test values

The primary test values are:

```text
IRQ          3
I/O base     0280
PNP          DISABLED
MODEM        1200
OPTIMIZE     SERVER
FULLDUPLEX   ENABLED
```

For MODEM, the token `1200` is expected to read back as:

```text
MODEM Interrupt Disable Time = 1300 us (1200 bd)
```

The currently defined Boot ROM recipe values are:

```text
Boot ROM address   C8000
Boot ROM size      16K
```

## Adapter identity and capability checks

Test `001` in both MAKE files validates the detected adapter identity and capabilities through a fresh `3CCFGCLI LIST`.

The current expectations are:

| Card            | ASIC revision | Connectors      | Plug and Play capability | Full Duplex capability |
| --------------- | ------------- | --------------- | ------------------------ | ---------------------- |
| `3C509B-TP`     | 2             | `TP, AUI`       | yes                      | yes                    |
| `3C509B-COAX`   | 2             | `AUI, COAX`     | yes                      | no                     |
| `3C509B-Combo`  | 2             | `TP, AUI, COAX` | yes                      | yes                    |
| `3C509B-TPO`    | 2             | `TP`            | yes                      | yes                    |
| `3C509B-TPCoax` | 2             | `TP, COAX`      | yes                      | yes                    |
| `3C509-TP`      | 1             | `TP, AUI`       | not supported            | not supported          |

For the 3C509B COAX, the LIST identity string matched by the tests is the unsuffixed:

```text
3Com 3C509B:
```

## HWCREAD.MK

`HWCREAD.MK` tests the hardware read side of `3CCFGCLI`.

`3CCFGCLI` does not establish the test properties in this suite. Known hardware states are written by the original `3C5X9CFG.EXE`, then read through fresh `3CCFGCLI LIST` processes and through `SAVECONFIG`.

The primary target is:

```text
hwcr
```

Its current sequence is:

```text
clean
prep
HWCR00xx
save-config
set-default-<card>
hwcr001-<card>
hwcr002
hwcr003
optional hwcr004
hwcr005
optional hwcr006
hwcr007
optional hwcr008-<card>
hwcr009-<card>
ROM status target
complete
```

### READ test matrix

| Test      | Purpose                                                                     | Models                                         |
| --------- | --------------------------------------------------------------------------- | ---------------------------------------------- |
| `HWCR001` | Identity, ASIC revision, connectors, PNP capability, Full Duplex capability | all recognized models                          |
| `HWCR002` | `3C5X9CFG /INT:3`, then `3CCFGCLI LIST`                                     | all recognized models                          |
| `HWCR003` | `3C5X9CFG /IOBASE:0280`, then `3CCFGCLI LIST`                               | all recognized models                          |
| `HWCR004` | `3C5X9CFG /PNP:DISABLED`, then `3CCFGCLI LIST`                              | all recognized 3C509B models                   |
| `HWCR005` | `3C5X9CFG /MODEM:1200`, then `3CCFGCLI LIST`                                | all recognized models                          |
| `HWCR006` | `3C5X9CFG /FULLDUPLEX:ENABLED`, then `3CCFGCLI LIST`                        | BTP, BCOMBO, BTPO, BTPC                        |
| `HWCR007` | `3C5X9CFG /OPTIMIZE:SERVER`, then `3CCFGCLI LIST`                           | all recognized models                          |
| `HWCR008` | model specific transceiver write through `3C5X9CFG`, then `3CCFGCLI LIST`   | BTP, BCOAX, BCOMBO, BTPC, TP                   |
| `HWCR009` | `3CCFGCLI SAVECONFIG` of the accumulated state                              | all recognized models                          |
| `HWCR051` | Boot ROM recipe or ROM status                                               | currently not selected by normal card mappings |

The 3C509B TPO skips `HWCR008` because its only connector is TP.

The original 3C509 TP skips `HWCR004` and `HWCR006` because PNP and Full Duplex are not supported.

The 3C509B COAX skips `HWCR006` because Full Duplex is not supported.

### Model specific transceiver checks

`HWCR008` uses these settings:

| Card            | Vendor utility write | Expected `3CCFGCLI LIST` result |
| --------------- | -------------------- | ------------------------------- |
| `3C509B-TP`     | `/TR:AUI`            | `Transceiver = external`        |
| `3C509B-COAX`   | `/TR:COAX`           | `Transceiver = on-board coax`   |
| `3C509B-Combo`  | `/TR:COAX`           | `Transceiver = on-board coax`   |
| `3C509B-TPCoax` | `/TR:COAX`           | `Transceiver = on-board coax`   |
| `3C509-TP`      | `/TR:AUI`            | `Transceiver = external`        |

### SAVECONFIG aggregate check

`HWCR009` serializes the accumulated physical state to:

```text
<card>\ARTIFACT\HWCR009.BAT
```

All card variants assert these common tokens:

```text
INT:3
IOBASE:0280
MODEM:1200
OPTIMIZE:SERVER
```

Additional current assertions are:

| Card            | Additional `HWCR009.BAT` assertions                                |
| --------------- | ------------------------------------------------------------------ |
| `3C509B-TP`     | `PNP:DISABLED`, `FULLDUPLEX:DISABLED`, `BSIZE:DISABLED`, `TR:AUI`  |
| `3C509B-COAX`   | `PNP:DISABLED`, `BSIZE:DISABLED`, `TR:COAX`                        |
| `3C509B-Combo`  | `PNP:DISABLED`, `FULLDUPLEX:DISABLED`, `BSIZE:DISABLED`, `TR:COAX` |
| `3C509B-TPO`    | `PNP:DISABLED`, `FULLDUPLEX:DISABLED`, `TR:TP`                     |
| `3C509B-TPCoax` | `PNP:DISABLED`, `FULLDUPLEX:DISABLED`, `BSIZE:DISABLED`, `TR:COAX` |
| `3C509-TP`      | `TR:AUI`                                                           |

The current `006` recipes validate `FULLDUPLEX:ENABLED` through immediate LIST readback on capable cards. The later `009` recipes explicitly look for `FULLDUPLEX:DISABLED` on BTP, BCOMBO, BTPO, and BTPC. This documentation records the implemented assertions exactly.

## HWCWRITE.MK

`HWCWRITE.MK` tests the physical `3CCFGCLI CONFIGURE` write path.

The original 3Com utility establishes deterministic starting states. The properties under test are then written by `3CCFGCLI`.

Each individual write test starts a new `3CCFGCLI LIST` process afterward. This verifies that the resulting physical state is still discoverable after the CONFIGURE process has exited.

The primary target is:

```text
hwcw
```

Its current sequence is:

```text
clean
prep
HWCW00xx
save-config
set-default-<card>
hwcw001-<card>
hwcw002
hwcw003
optional hwcw004
hwcw005
optional hwcw006
hwcw007
optional hwcw008-<card>
hwcw009-<card>
hwcw010
ROM status target
complete
```

### WRITE test matrix

| Test      | Purpose                                                      | Models                                         |
| --------- | ------------------------------------------------------------ | ---------------------------------------------- |
| `HWCW001` | Identity and capability sanity check through `3CCFGCLI LIST` | all recognized models                          |
| `HWCW002` | `3CCFGCLI CONFIGURE /INT:3`, then fresh LIST                 | all recognized models                          |
| `HWCW003` | `3CCFGCLI CONFIGURE /IOBASE:0280`, then fresh LIST           | all recognized models                          |
| `HWCW004` | `3CCFGCLI CONFIGURE /PNP:DISABLED`, then fresh LIST          | all recognized 3C509B models                   |
| `HWCW005` | `3CCFGCLI CONFIGURE /MODEM:1200`, then fresh LIST            | all recognized models                          |
| `HWCW006` | `3CCFGCLI CONFIGURE /FULLDUPLEX:ENABLED`, then fresh LIST    | BTP, BCOMBO, BTPO, BTPC                        |
| `HWCW007` | `3CCFGCLI CONFIGURE /OPTIMIZE:SERVER`, then fresh LIST       | all recognized models                          |
| `HWCW008` | model specific `3CCFGCLI /TR` write, then fresh LIST         | BTP, BCOAX, BCOMBO, BTPC, TP                   |
| `HWCW009` | `3CCFGCLI SAVECONFIG` of the accumulated state               | all recognized models                          |
| `HWCW010` | combined four property physical CONFIGURE transaction        | all recognized models                          |
| `HWCW051` | Boot ROM recipe or ROM status                                | currently not selected by normal card mappings |

Capability based omissions are the same as in the READ suite.

### Model specific transceiver writes

`HWCW008` uses the same alternate connector choices as `HWCR008`:

| Card            | `3CCFGCLI` write | Expected fresh LIST result    |
| --------------- | ---------------- | ----------------------------- |
| `3C509B-TP`     | `/TR:AUI`        | `Transceiver = external`      |
| `3C509B-COAX`   | `/TR:COAX`       | `Transceiver = on-board coax` |
| `3C509B-Combo`  | `/TR:COAX`       | `Transceiver = on-board coax` |
| `3C509B-TPCoax` | `/TR:COAX`       | `Transceiver = on-board coax` |
| `3C509-TP`      | `/TR:AUI`        | `Transceiver = external`      |

### SAVECONFIG aggregate check

`HWCW009` writes:

```text
<card>\ARTIFACT\HWCW009.BAT
```

and checks the same common and model specific serialized values as `HWCR009`.

The common assertions are:

```text
INT:3
IOBASE:0280
MODEM:1200
OPTIMIZE:SERVER
```

The card specific assertions are:

| Card            | Additional `HWCW009.BAT` assertions                                |
| --------------- | ------------------------------------------------------------------ |
| `3C509B-TP`     | `PNP:DISABLED`, `FULLDUPLEX:DISABLED`, `BSIZE:DISABLED`, `TR:AUI`  |
| `3C509B-COAX`   | `PNP:DISABLED`, `BSIZE:DISABLED`, `TR:COAX`                        |
| `3C509B-Combo`  | `PNP:DISABLED`, `FULLDUPLEX:DISABLED`, `BSIZE:DISABLED`, `TR:COAX` |
| `3C509B-TPO`    | `PNP:DISABLED`, `FULLDUPLEX:DISABLED`, `TR:TP`                     |
| `3C509B-TPCoax` | `PNP:DISABLED`, `FULLDUPLEX:DISABLED`, `BSIZE:DISABLED`, `TR:COAX` |
| `3C509-TP`      | `TR:AUI`                                                           |

As in the READ suite, the immediate `006` check expects Full Duplex enabled on capable models, while the current `009` serialization checks listed above expect disabled for BTP, BCOMBO, BTPO, and BTPC.

### Combined physical transaction

`HWCW010` exercises a multi property write in one `3CCFGCLI CONFIGURE` invocation.

First the original utility reestablishes the four common defaults:

```text
/INT:10
/IOBASE:0300
/MODEM:NONE
/OPTIMIZE:DOS
```

Then `3CCFGCLI` writes all four test values in one process:

```text
/INT:3
/IOBASE:0280
/MODEM:1200
/OPTIMIZE:SERVER
```

A fresh LIST process then verifies:

```text
IOBASE = 0280, IRQ = 3
MODEM Interrupt Disable Time = 1300 us (1200 bd)
Optimization = Server
```

`HWCW010` resets only these four common properties before the combined write. Other properties retain the state established earlier in the suite.

This is the last active configuration test before the optional ROM status target and the post configuration `.SET` dump created by `HWCTEST.BAT`.

## Boot ROM test status

Both MAKE files contain concrete `051` Boot ROM recipes, with these values:

```text
BADDRESS = C8000
BSIZE    = 16
```

However, the current card selection logic does not route a normal READROM or WRITEROM run to those recipes.

Without `ROM_TEST`, every model selects the corresponding `rom-disabled` status target.

With `ROM_TEST`:

| Card            | READROM status    | WRITEROM status   |
| --------------- | ----------------- | ----------------- |
| `3C509B-TP`     | `NOT IMPLEMENTED` | `NOT IMPLEMENTED` |
| `3C509B-COAX`   | `NOT IMPLEMENTED` | `NOT IMPLEMENTED` |
| `3C509B-Combo`  | `NOT IMPLEMENTED` | `NOT IMPLEMENTED` |
| `3C509B-TPO`    | `NOT SUPPORTED`   | `NOT SUPPORTED`   |
| `3C509B-TPCoax` | `NOT IMPLEMENTED` | `NOT IMPLEMENTED` |
| `3C509-TP`      | `NOT IMPLEMENTED` | `NOT IMPLEMENTED` |

The dormant `hwcr051` recipe would use `3C5X9CFG` to write C8000 and 16K, then verify the state through `3CCFGCLI LIST` and `SAVECONFIG`.

The dormant `hwcw051` recipe would use `3CCFGCLI CONFIGURE` to write C8000 and 16K, then verify the state through a fresh `LIST` and `SAVECONFIG`.

These recipes are present in the source, but they are not currently reached by the normal card mappings.

## Test ID structure

Both MAKE files retain generic test targets for structural consistency and test reporting.

Examples include:

```text
hwcr001
hwcr008
hwcr009
hwcw001
hwcw008
hwcw009
```

For tests with card specific behavior, these generic targets act as canonical stubs while the normal run invokes a card specific target such as:

```text
hwcr001-btp
hwcr008-btpc
hwcr009-tp
hwcw001-bcombo
hwcw008-bcoax
hwcw009-btpo
```

The source comments identify these stubs as structural entries for `testreport.py`.

The MAKE files also expose the aggregate dependency declarations:

```text
HWCR_READ
HWCW_WRITE
```

The normal hardware compliance entry points remain `HWCTEST.BAT` with the `hwcr` or `hwcw` target selected internally.

## Configuration preservation

Both MAKE files save the original adapter configuration before the deterministic baseline is written.

The saved restore batches are card specific:

```text
<card>\ARTIFACT\HWCRREST.BAT
<card>\ARTIFACT\HWCWREST.BAT
```

They are created with `3CCFGCLI SAVECONFIG` and use a replaceable executable argument so the saved configuration can be replayed through the original 3Com utility.

Automatic restoration is intentionally not performed from MAKE. The MAKE files document that command invocation through MAKE is unreliable on some earlier DOS versions.

The `restore` and `restore-config` targets therefore print the command that should be run manually instead of invoking the restore batch themselves.

For example, conceptually:

```text
<card>\ARTIFACT\HWCRREST.BAT 3C5X9CFG.EXE
<card>\ARTIFACT\HWCWREST.BAT 3C5X9CFG.EXE
```

A failed test can leave the adapter in an intermediate test state. Keep the generated restore batch until the original configuration has been restored successfully.

## Cleanup behavior

The MAKE `clean` target removes files inside the selected card's `ARTIFACT` directory:

```text
<card>\ARTIFACT\*.*
```

It does not delete the main card log itself.

At the beginning of a new batch run, `HWCTEST.BAT` removes the temporary `HWCINIT.LOG`, creates a fresh initial LIST output, then copies that output over the selected `HWCREAD.LOG` or `HWCWRITE.LOG` before MAKE appends the detailed suite progress.

Artifacts belonging to other card directories are not touched.

## Logs and artifacts

All persistent output is grouped by detected card.

A typical BTP READ run uses:

```text
BTP\HWCREAD.LOG
BTP\ARTIFACT\HWCRSET.LOG
BTP\ARTIFACT\HWCR001.LOG
BTP\ARTIFACT\HWCR002.LOG
BTP\ARTIFACT\HWCR003.LOG
BTP\ARTIFACT\HWCR004.LOG
BTP\ARTIFACT\HWCR005.LOG
BTP\ARTIFACT\HWCR006.LOG
BTP\ARTIFACT\HWCR007.LOG
BTP\ARTIFACT\HWCR008.LOG
BTP\ARTIFACT\HWCR009.LOG
BTP\ARTIFACT\HWCR009.BAT
BTP\ARTIFACT\HWCRREST.BAT
BTP\ARTIFACT\hwcr.SET
```

A typical BTP WRITE run uses:

```text
BTP\HWCWRITE.LOG
BTP\ARTIFACT\HWCWSET.LOG
BTP\ARTIFACT\HWCW001.LOG
BTP\ARTIFACT\HWCW002.LOG
BTP\ARTIFACT\HWCW003.LOG
BTP\ARTIFACT\HWCW004.LOG
BTP\ARTIFACT\HWCW005.LOG
BTP\ARTIFACT\HWCW006.LOG
BTP\ARTIFACT\HWCW007.LOG
BTP\ARTIFACT\HWCW008.LOG
BTP\ARTIFACT\HWCW009.LOG
BTP\ARTIFACT\HWCW009.BAT
BTP\ARTIFACT\HWCW010.LOG
BTP\ARTIFACT\HWCWREST.BAT
BTP\ARTIFACT\hwcw.SET
```

Model specific skipped tests simply do not produce the corresponding numbered log.

The main `HWCREAD.LOG` or `HWCWRITE.LOG` contains the initial adapter LIST, dispatch information, suite progress, PASS markers, ROM status, and the final batch result.

The numbered `HWCR` and `HWCW` logs contain the command output associated with individual compliance checks.

`HWCR009.BAT` and `HWCW009.BAT` are test artifacts generated by `SAVECONFIG` and inspected by the `009` assertions.

`HWCRREST.BAT` and `HWCWREST.BAT` preserve the original configuration for manual restoration.

`hwcr.SET` and `hwcw.SET` are post run configuration dumps produced by the original 3Com utility. In the current implementation they are retained as evidence and are not parsed by the suite.

The dormant READ Boot ROM recipe currently uses `HWCR010.LOG` and `HWCR010.BAT` as its artifact names even though its test identifier is `HWCR051`. The dormant WRITE Boot ROM recipe uses `HWCW051.LOG` and `HWCW051.BAT`.

## Dependencies

The hardware compliance suite currently requires:

* a physical supported 3Com EtherLink III adapter
* `3CCFGCLI.EXE`
* the original 3Com Configuration and Diagnostic Program, `3C5X9CFG.EXE`, version 3.2
* Borland MAKE 3.0
* `STUFFIT`, version 3.10, from `stuff310.zip`
* DOS with the standard commands used by the scripts, including `FIND`, `COPY`, `DEL`, and `MD`

`STUFFIT` is required for every successful mode because `HWCTEST.BAT` creates a post configuration vendor dump after both READ and WRITE runs.

The scripts are intentionally kept compatible with early DOS environments, including DOS 3.x and 4.x.

They do not require `HIMEM.SYS`, an XMS manager, an EMS manager, or another memory manager.

Suitable physical Boot ROM hardware will be required when the `051` recipes are enabled in the normal READROM and WRITEROM card mappings. At present those entry points report ROM test status without executing the physical Boot ROM recipe.

The original `3C5X9CFG.EXE` utility is required in both directions.

For READ testing it establishes the deterministic baseline and every hardware state that `3CCFGCLI` is asked to read.

For WRITE testing it establishes the deterministic baseline and the common defaults used before the combined `HWCW010` transaction.

After either direction it is also used interactively, through `STUFFIT`, to save the final `.SET` evidence file.

## Links

### STUFFIT 3.10

Download from the Simtel DOS keyboard utilities archive:

http://ftp.oldskool.org/pub/simtelnet/msdos/keyboard/stuff310.zip