# 3CCFG Project Agent Instructions

## 1. Purpose

This file defines repository rules for automated coding agents.

It is intentionally limited to instructions that affect how an agent modifies, builds, tests, and validates this project.

Do not duplicate general project documentation here.

For project behavior, supported commands, implementation scope, usage, and technical background, consult `README.md`.

For current work items and known follow ups, consult `TODO.md`.

The changelog is maintained in `CHANGES`.

If this file and `README.md` appear to disagree about implemented project scope, `README.md` is authoritative.

Do not infer desired functionality from the original 3Com utility alone. Features intentionally omitted by this project must remain omitted unless the task explicitly asks for them.

## 2. Mandatory Build and Test Workflow

Build and test validation is required only when the agent has modified code, tests, build files, or other files that affect the produced binaries or automated tests.

If the agent has not made such a modification, it MUST NOT run `build.sh` or `test.sh` unless the user explicitly requests a build or test run.

Tasks that do not require build or test execution include source review or analysis without modifications, reading or explaining existing code, producing implementation recommendations or prompts, reviewing already supplied changes without modifying the repository, and documentation only changes unless the user explicitly requests validation.

When the agent has made a change that requires validation, the mandatory sequence is:

```text
./build.sh
./test.sh
```

The order is mandatory.

After a change that requires validation:

1. Run `./build.sh`.

2. Wait for `build.sh` to finish completely.

3. Inspect `BUILD.LOG` after the script has completed.

4. Confirm that the build completed successfully.

5. Confirm that every TASM pass reports:

```text
Error messages: None
```

6. Only after that successful build, run `./test.sh`.

7. Wait for `test.sh` to finish completely.

8. Review the `TEST.LOG` output emitted by `test.sh`.

9. Inspect any relevant logs under `ARTIFACT/` separately after `test.sh` has completed.

10. Confirm that the complete test suite reached its normal successful completion, including the hardware limit checks.

A previous build does not satisfy this requirement after files affecting the binaries or tests have changed.

If such a file is changed after `build.sh` was run, run `build.sh` again before running `test.sh`.

If `build.sh` fails, do not run `test.sh`. Fix or report the build failure first.

Running tests against binaries produced before the current relevant source changes is invalid validation.

Pure documentation changes do not require a build or test run unless validation is explicitly requested by the user.

### Command invocation rules

`build.sh` and `test.sh` MUST always be executed as bare standalone commands.

The complete shell command used to invoke them MUST be exactly one of:

```text
./build.sh
```

or:

```text
./test.sh
```

Nothing may be appended, prepended, chained, wrapped, redirected, or combined with either command.

Do not append another command with a shell separator.

Do not chain another command conditionally.

Do not pipe script output into another command.

Do not redirect script output.

Do not capture the script exit status into a shell variable.

Do not append `echo`, `cat`, `find`, `grep`, `tail`, or similar commands.

Do not wrap either script in `sh`, `bash`, a subshell, or another helper command.

Do not perform cleanup, status reporting, or log collection in the same shell invocation.

Commands such as these are forbidden:

```text
./test.sh; echo $?
```

```text
./test.sh && cat TEST.LOG
```

```text
./test.sh | tee output.log
```

```text
./test.sh; ret=$?; cat TEST.LOG; exit $ret
```

```text
./build.sh; cat BUILD.LOG
```

Run the script by itself and wait for it to finish.

Log inspection MUST occur only after the corresponding script has completed, using separate tool calls or separate shell commands.

Do not prepend speculative cleanup commands such as `rm`, `find`, or cache removal.

The test infrastructure performs its own required cleanup.

If stale state is suspected, investigate it first rather than modifying the normal validation command.

Script exit status is no sufficient validation.

Both `build.sh` and `test.sh` automatically emit their main log, `BUILD.LOG` and `TEST.LOG` respectively, as part of their normal output.

Do not print, dump, or `cat` either `BUILD.LOG` or `TEST.LOG` again after script run merely to duplicate output that was already emitted.

For regression tests, inspect additional logs under `ARTIFACT/` separately when they are required to determine the final validation result.

### Long running test process

A complete `test.sh` run may take more than 120 seconds and can exceed the default timeout of an execution tool.

This does not justify wrapping `test.sh` in additional shell logic.

Always invoke it exactly as:

```text
./test.sh
```

A tool timeout does not mean that the test suite passed, failed, or completed.

The agent MUST NOT issue a final assessment, claim successful validation, or report the change as complete until the original test process has actually finished and the required logs have been inspected.

Use an execution timeout long enough for the complete test run whenever possible.

If the execution tool returns before the test process has finished, continue observing the existing process when the environment permits it.

Do not start another `test.sh` merely because the first invocation exceeded a tool timeout.

Do not replace the bare invocation with shell logic intended to capture status, collect logs, or work around the timeout.

Once the original process has finished, review the output emitted by `test.sh` and inspect relevant `ARTIFACT/` logs separately before determining the validation result.

## 3. Validation Semantics

The test suite uses fail fast behavior by design.

A test run that terminates before all expected tests and hardware limit checks have completed is a failed validation, even if earlier tests passed.

Do not describe a partial test run as successful.

The authoritative test result comes from the assertions recorded in `TEST.LOG` together with the corresponding relevant logs under `ARTIFACT/`.

Tests use explicit `3CSEED` state so that results remain deterministic.

When adding or changing tests, establish the required mock state explicitly.

After temporary capability or configuration overrides, restore the state with the appropriate `INIT` or `CLEAR` operation.

The complete seeder command reference is found in `README.md`.

## 4. Target and Toolchain Constraints

The production target is 16 bit DOS on 8086 and 8088 class processors.

Assembly source uses TASM IDEAL mode syntax.

Instructions that require an 80186 or later processor are forbidden.

Do not introduce newer processor instructions accidentally during optimization or cleanup.

The normal build produces both hardware implementations:

```text
/dREALHW
/dMOCKHW
```

The corresponding executables are:

```text
BIN/3CCFGCLI.EXE
BIN/3CHWMOCK.EXE
```

The test seeder is:

```text
BIN/3CSEED.EXE
```

File and directory names must remain compatible with the repository's DOS 8.3 naming convention.

## 5. Source Architecture

The important source responsibilities are:

```text
3CCFGCLI.ASM
    Main CLI implementation.
    Parsing, adapter discovery orchestration, transaction logic,
    configuration handlers, output, and high level policy.

3CHWIF.ASM
    Real hardware backend.
    ISA hardware access and hardware specific primitives.

3CMOCKIF.ASM
    Mock hardware backend.
    Implements the corresponding hardware interface using mock state.

3CSEED.ASM
    Deterministic test fixture utility.
    Creates and modifies mock hardware state used by the test suite.

3C509DEF.INC
    Shared constants and data definitions.
    Includes EEPROM definitions, product definitions, and shared mock layout values.
```

Keep hardware access behind the existing backend boundary.

When changing a generic hardware interface contract, inspect both `3CHWIF.ASM` and `3CMOCKIF.ASM`.

The mock backend should reproduce the externally relevant behavior of the real backend where practical.

Backend specific implementation details may differ, but their shared caller contract must remain consistent.

Do not add production behavior merely to make a mock test easier to implement.

Do not add nondeterministic behavior to `3CSEED` or the automated tests.

## 6. Scope Discipline

Keep changes focused on the requested task.

Do not perform unrelated refactoring merely because nearby code could also be changed.

Do not silently change established CLI semantics while performing cleanup or optimization.

When removing apparently dead code, first verify references across the main program and both hardware backends where applicable.

When changing shared constants, EEPROM handling, hardware interface behavior, transaction behavior, or mock record layout, inspect all consumers before making the change.

For behavior intended to reproduce the original utility, preserve the project's chosen compatibility semantics rather than introducing generic best practice behavior that changes compatibility.

`README.md` remains the authority for which commands and features this project intentionally implements.

## 7. Line Ending Requirements

Files consumed directly by DOS tooling require CRLF line endings in the working tree:

```text
*.BAT
*.MK
MAKEFILE
```

This is enforced by `.gitattributes`.

Do not manually normalize these files to LF.

The remaining source and documentation files use LF.

If a new DOS consumed file type requires CRLF, update `.gitattributes` accordingly.

## 8. Test Changes

Tests in `TEST.MK` are grouped by feature and use numbered test identifiers.

New behavior should normally include appropriate positive and negative coverage.

Tests should explicitly establish their prerequisite state rather than depending accidentally on state left behind by an unrelated test.

A test that changes persistent mock state must leave subsequent tests with a defined state.

Do not weaken an existing assertion merely to make a changed implementation pass unless the expected behavior itself is intentionally being changed.

## 9. Completion Criteria

These validation steps apply only when the agent has modified code, tests, build files, or other files that affect the produced binaries or automated tests.

If no such modification was made, do not run `build.sh` or `test.sh` merely as a completion ritual.

When validation is required, before reporting the modification as complete:

1. Review the final changes for unrelated or accidental edits.

2. Run exactly:

```text
./build.sh
```

3. Wait for the build process to finish.

4.  Review the `BUILDTEST.LOG` output already emitted by `build.sh` after the build has completed.

5. Verify that the current source tree builds successfully.

6. Only after that successful build, run exactly:

```text
./test.sh
```

7. Wait for the complete test process to finish, even if this takes more than 120 seconds.

8. Review the `TEST.LOG` output already emitted by `test.sh`.

9. Inspect relevant `ARTIFACT/` logs separately.

10. Verify that the full test sequence completed successfully.

11. Report any validation that could not be performed.

Never claim that a change was fully validated when the build failed, the tests terminated early, only an isolated test was run, the test process had not yet finished, the required logs were not inspected, or the tests used binaries from an earlier relevant source state.

Never combine build execution, test execution, status capture, cleanup, or log inspection into a compound shell command.