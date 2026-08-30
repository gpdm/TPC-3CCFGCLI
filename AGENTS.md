# 3CCFG Project — Agent Instructions

## Build & Test

```
./build.sh    # assembles all targets via DOSBox-X; output in BUILD.LOG
./test.sh     # runs smoke suite + HW-limit checks via DOSBox-X; output in TEST.LOG and ./ARTIFACT/ logs.
```

- **Never** pipe, grep, or tail the build.sh or test.sh scripts. Just run them bare.
- **Never** precede build.sh or test.sh with extra shell commands (e.g. `rm`,
  `find`, cache-busting) "just in case." `prep` in TEST.MK already clears
  `ARTIFACT\*.LOG` and TEST.LOG before every run. If you suspect stale state,
  investigate and confirm it first; don't add speculative cleanup commands.
- Scripts default to `/Applications/DOSBox-X.app/Contents/MacOS/dosbox-x`;
  override with `DOSBOX_BIN=/path/to/dosbox-x` when needed.
- Build artifacts: `BIN/3CCFGCLI.EXE` (real HW), `BIN/3CHWMOCK.EXE` (mock HW), `BIN/3CSEED.EXE` (seeder).
- Test artifacts: `ARTIFACT/T0xx.LOG` (smoke suite) and
  `ARTIFACT/HWL*.LOG` (hardware-limit checks) — written inside DOSBox,
  readable on the host after the run.
- **All filenames and directory names follow 8.3 convention** — this is intentional; the toolchain runs inside DOSBox-X under DOS.
- A clean build shows `Error messages: None` for every TASM pass.
- A test target exits successfully only when the test suite runs through to completion without a failing assertion or non-zero test exit.
- If a single testcase fails, the suite exits prematurely; that early exit is a fail verdict.
- The authoritative pass/fail result comes from the test assertions in TEST.LOG and the per-test artifact logs under `ARTIFACT/`.


## Toolchain

- Turbo Assembler 4.1 (TASM), Turbo Linker 7.1, Borland MAKE — all run inside DOSBox-X.
- Target: DOS, 8086/8088 real-mode, IDEAL mode TASM syntax.
- Two build variants controlled by a TASM define: `/dREALHW` → `3CCFGCLI.EXE`, `/dMOCKHW` → `3CHWMOCK.EXE`. Default build target always builds both by default.

## Project Layout

```
3CCFGCLI.ASM         Main CLI — parser, transaction engine, all verb handlers.
3CHWIF.ASM           Real hardware backend (ISA I/O primitives).
3CMOCKIF.ASM         Mock hardware backend (reads/writes 3C509B.MCK state file).
3CSEED.ASM           Seeder utility — creates mock state files for testing.
3C509DEF.INC         Shared constants (EEPROM layout, product IDs, MCK record offsets).

MAKEFILE             Production build rules (run via build.sh).
TEST.MK              Test orchestration (Borland MAKE, run via test.sh).
BUILD.BAT            DOSBox entry point invoked by build.sh.
TEST.BAT             DOSBox entry point invoked by test.sh.
TESTHWL.BAT          DOSBox entry point for hardware-limit checks (used by test.sh).

build.sh             Host script: launches DOSBox-X for a full build; output → BUILD.LOG.
test.sh              Host script: launches DOSBox-X for smoke + HW-limit checks; output → TEST.LOG.
interactive.sh       Host script: opens an interactive DOSBox-X session for manual testing.

autoexec-build       DOSBox-X config used by build.sh.
autoexec-test        DOSBox-X config used by test.sh.
autoexec-testhwl     DOSBox-X config used by test.sh for hardware-limit checks.
autoexec-interactive DOSBox-X config used by interactive.sh.

OBJ/                 Intermediate TASM object files (3CCFGCLI.OBJ, 3CHWMOCK.OBJ, 3CSEED.OBJ).
BIN/                 Final DOS executables (3CCFGCLI.EXE, 3CHWMOCK.EXE, 3CSEED.EXE).
ARTIFACT/            Per-test log files produced by the test suite.
TASM/                Placeholder DOS toolchain location (user-supplied TASM/TLINK/MAKE).
```

## Scope & Status Authority

- [README.md](README.md) is authoritative for current implementation scope,
  supported CLI verbs/subverbs, and project status.

## Changelog Convention

Changelog lives in `CHANGES`.

## Test Convention

- Tests are numbered `t001`–`tNNN` in `TEST.MK`, grouped by feature.
- Each test echoes `[tNNN] description` to `TEST.LOG`, runs the binary, and uses DOS `FIND` to assert expected output strings.
- Hardware-limit checks write `ARTIFACT/HWL*.LOG` (e.g. `HWL64.LOG`, `HWL128.LOG`, `HWL256.LOG`) and are part of test-run validation.
- Tests abort prematurely on error (non-zero exit code, behaviour by design)
- Subsequent tests will not run, but assertion ends on first critical failure
- Failure to reach completion of all defined tests in `TEST.MK` has to be considered critical
- Negative tests (invalid input, out-of-range, capability gates) are included in every feature group.
- State is managed by explicit `3CSEED` calls; always restore to `INIT` or `CLEAR` after a capability-override seed.
- Seeder verb reference is documented in [README.md](README.md).
