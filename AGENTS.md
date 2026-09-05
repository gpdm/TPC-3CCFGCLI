# 3CCFG Project Agent Instructions

## 1. Purpose and Sources of Truth

This file defines repository rules for automated coding agents.

It contains only instructions that affect how an agent modifies, builds, tests, and validates this project.

For project behavior, supported commands, implementation scope, usage, and technical background, consult `README.md`.

For current work items and known follow ups, consult `TODO.md`.

The changelog is maintained in `CHANGES`.

If this file and `README.md` appear to disagree about implemented project scope, `README.md` is authoritative.

Do not infer desired functionality from the original 3Com utility alone.

Features intentionally omitted by this project must remain omitted unless the task explicitly requests them.

## 2. Scope Discipline

Keep changes focused on the requested task.

Do not perform unrelated refactoring merely because nearby code could also be changed.

Do not silently change established CLI semantics during cleanup, optimization, or maintenance work.

For behavior intended to reproduce the original utility, preserve the compatibility semantics chosen by this project rather than introducing generic best practice behavior that changes compatibility.

Before removing apparently dead code, verify its references across all relevant source files.

Before changing shared constants, EEPROM handling, hardware interface behavior, transaction behavior, or mock record layout, inspect all consumers.

`README.md` is authoritative for which commands, features, and original utility behaviors this project intentionally supports.

## 3. Target and Toolchain Constraints

The production target is 16 bit DOS on 8086 and 8088 class processors.

Assembly source uses TASM IDEAL mode syntax.

Instructions requiring an 80186 or later processor are forbidden.

Do not accidentally introduce newer processor instructions during implementation, cleanup, or optimization.

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

File and directory names must remain compatible with the repository DOS 8.3 naming convention.

## 4. Source Architecture

The principal source responsibilities are:

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

Their implementations may differ internally, but their shared caller contract must remain consistent.

The mock backend should reproduce externally relevant real hardware behavior where practical.

Do not add production behavior merely to make a mock test easier to implement.

Do not introduce nondeterministic behavior into `3CSEED` or the automated tests.

## 5. Build and Validation

### 5.1 When validation is required

Build and test validation is required when the agent modifies code, tests, build files, or any other file that affects produced binaries or automated tests.

Validation is not required when no such files were modified.

Examples include:

1. Source review or analysis without repository modifications.

2. Explanation of existing code.

3. Producing implementation recommendations or prompts.

4. Reviewing changes already supplied by the user without modifying the repository.

5. Documentation only changes.

Do not run `build.sh` or `test.sh` for such tasks unless the user explicitly requests validation.

A previous validation run becomes invalid after any relevant source, test, or build file has changed.

### 5.2 Mandatory validation sequence

When validation is required, perform the following sequence exactly.

1. Review the final changes for accidental or unrelated edits.

2. Run exactly:

```text
./build.sh
```

3. Wait until the command has completely finished.

4. Check the process exit status and the `Build summary` emitted by the script.

5. Only if the build is successful, run exactly:

```text
./test.sh
```

6. Wait until the original test process has completely finished.

7. Check the process exit status and the `Test summary` emitted by the script.

8. Inspect additional logs under `ARTIFACT/` separately when they are relevant to the changed behavior or needed to establish the final result.

9. Report the modification as fully validated only when both build and test validation succeeded.

If `build.sh` fails, do not run `test.sh`.

If a relevant file is changed after the build, run `build.sh` again before running `test.sh`.

Tests run against binaries produced before the latest relevant source change are invalid validation.

### 5.3 Build success criteria

`build.sh` provides both a process exit status and an explicit summary.

A zero exit status indicates that the script reports success.

A nonzero exit status indicates failure.

A normal successful build ends with a summary equivalent to:

```text
Build summary
=============
TASM calls : 3
TLINK calls: 3
Warnings   : 0
Errors     : 0

Overall result: PASS
```

For the normal repository build, successful validation requires:

```text
build.sh exit status = 0
TASM calls           = 3
TLINK calls          = 3
Warnings             = 0
Errors               = 0
Overall result        = PASS
```

The exact whitespace used to align summary fields is not significant.

A nonzero exit status is always a failed build.

A summary reporting warnings, errors, or an overall result other than `PASS` is also a failed build.

If the exit status and summary disagree, or the expected summary is missing or incomplete, do not assume success.

Inspect the emitted build output and report the inconsistency.

Do not run `test.sh` until the current build has been established as successful.

### 5.4 Test success criteria

`test.sh` provides both a process exit status and an explicit summary.

A zero exit status indicates that the script reports success.

A nonzero exit status indicates failure.

A successful current test run has a summary equivalent to:

```text
Test summary
============
Smoke Test            : SUCCESS
    Defined Tests     : 144
    Executed Tests    : 144
    Failed Tests      : NONE
SAVECONFIG Test       : SUCCESS
Hardware Limit Test   : SUCCESS

Overall result        : PASS
```

The exact whitespace used to align summary fields is not significant.

The number of defined tests may legitimately change when tests are intentionally added or removed.

Successful validation requires all of the following:

```text
test.sh exit status         = 0
Smoke Test                  = SUCCESS
Defined Tests               = Executed Tests
Failed Tests                = NONE
SAVECONFIG Test             = SUCCESS
Hardware Limit Test         = SUCCESS
Overall result              = PASS
```

The hardware limit phase must complete normally, including successful checks for 64 KB, 128 KB, and 256 KB memory limits.

A nonzero exit status is always failed validation.

Any failed test, incomplete test count, failed test phase, failed hardware limit check, or overall result other than `PASS` is failed validation.

If the exit status and summary disagree, or the expected summary is missing or incomplete, do not assume success.

Inspect the emitted test output and relevant logs to determine what happened, then report the inconsistency.

### 5.5 Script invocation rules

`build.sh` and `test.sh` must always be executed as bare standalone commands.

The complete shell command used to invoke them must be exactly:

```text
./build.sh
```

or:

```text
./test.sh
```

Nothing may be appended, prepended, chained, wrapped, redirected, piped, or combined with either command.

In particular, do not:

1. Append another command using a shell separator.

2. Add conditional command execution.

3. Pipe script output into another program.

4. Redirect script output.

5. Capture the script exit status into a shell variable.

6. Wrap the script using `sh`, `bash`, a subshell, or another helper.

7. Combine script execution with cleanup, log inspection, or status reporting.

Forbidden examples include:

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

Run each script by itself and wait for it to finish.

Any later inspection must use a separate command or tool call.

Do not prepend speculative cleanup commands such as `rm`, `find`, or cache removal.

The test infrastructure performs its own required cleanup.

If stale state is suspected, investigate the cause rather than changing the normal validation invocation.

### 5.6 Log handling

`build.sh` emits the contents of `BUILD.LOG` as part of its normal output.

`test.sh` emits the contents of `TEST.LOG` as part of its normal output.

Do not dump or `cat` either main log again merely to duplicate output already emitted by the corresponding script.

Use the emitted summaries as the primary concise validation result.

Inspect the preceding emitted log content when the summary indicates a failure, when the summary is incomplete or inconsistent, or when details are needed to diagnose a problem.

Additional regression logs under `ARTIFACT/` must be inspected separately when they are relevant to the changed functionality or necessary to establish the validation result.

Do not treat the process exit status alone as proof of complete validation.

Successful validation requires a successful exit status and a complete successful summary without contradictory evidence in the corresponding output or relevant artifacts.

### 5.7 Long running tests

A complete `test.sh` run may take more than 120 seconds and may exceed the default timeout of an execution tool.

Use an execution timeout long enough for the complete test suite whenever possible.

A tool timeout does not mean that the test suite passed, failed, or completed.

If the execution tool returns while the original test process is still running, continue observing that existing process when the environment permits it.

Do not start another `test.sh` merely because the original invocation exceeded a tool timeout.

Do not replace the required bare invocation with additional shell logic intended to work around a timeout.

The test suite uses fail fast behavior.

A run that terminates before all expected phases and hardware limit checks have completed is failed validation, even if every test executed before termination passed.

Never describe a partial test run as successful.

### 5.8 Reporting validation

Never report a modification as fully validated when any of the following is true:

1. The current build failed.

2. Tests were run without a successful build of the current relevant source state.

3. The test process terminated before normal completion.

4. Only an isolated subset of the required suite was run.

5. The test process was still running.

6. The build or test summary was missing, incomplete, contradictory, or reported failure.

7. Required relevant artifact logs were not inspected.

8. Tests used binaries from an earlier relevant source state.

If required validation cannot be completed, state exactly what was performed, what succeeded, what failed, and what remains unvalidated.

## 6. Test Design Rules

Tests in `TEST.MK` are grouped by feature and use numbered test identifiers.

New or changed behavior should normally include appropriate positive and negative coverage.

Tests must explicitly establish prerequisite mock state rather than depend accidentally on state left by an unrelated test.

Tests use explicit `3CSEED` state to remain deterministic.

A test that changes persistent mock state must leave subsequent tests with a defined state.

After temporary capability or configuration overrides, restore the required state using the appropriate `INIT` or `CLEAR` operation.

The complete `3CSEED` command reference is documented in `README.md`.

Do not weaken an existing assertion merely to make a changed implementation pass unless the expected behavior itself is intentionally being changed.

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

If another DOS consumed file type is introduced and requires CRLF, update `.gitattributes` accordingly.