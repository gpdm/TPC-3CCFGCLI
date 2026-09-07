# Testing Architecture

## 1. Purpose

The 3CCFG test framework validates the project through several deliberately different test layers.

No single test suite is intended to prove every aspect of the program.

The current framework consists primarily of:

* `TEST.MK`
* `TEST.BAT`
* `test.sh`
* `autoexec-test`
* `3CSEED.EXE`
* `3CHWMOCK.EXE`
* `TESTHWC.MK`
* `TESTHWL.BAT`
* `autoexec-testhwl.template`

These layers provide different kinds of evidence:

```text
mock regression testing
    verifies application behavior against deterministic modeled hardware

host assertions
    verify conditions that are inconvenient to inspect inside DOS

real hardware conformance
    compares 3CCFGCLI observations with configuration written by the original utility

hardware limit testing
    verifies that the executable can start under constrained 8086 memory configurations
```

These forms of testing complement each other.

They are not interchangeable.

Related architecture documents are:

[BACKEND.md](BACKEND.md)

[DISCOVERY.md](DISCOVERY.md)

[STATE_MODEL.md](STATE_MODEL.md)

[TRANSACTIONS.md](TRANSACTIONS.md)

[EEPROM.md](EEPROM.md)

[CAPABILITIES.md](CAPABILITIES.md)

[MOCK.md](MOCK.md)

[LOW_LEVEL_CONVENTIONS.md](LOW_LEVEL_CONVENTIONS.md)

## 2. Test Layers

The normal automated test path is:

```text
test.sh
    |
    +--> DOSBox X
    |       |
    |       +--> autoexec-test
    |               |
    |               +--> TEST.BAT
    |                       |
    |                       +--> TEST.MK smoke
    |                               |
    |                               +--> 3CSEED
    |                               +--> 3CHWMOCK
    |                               +--> FIND assertions
    |                               +--> NFIND assertions
    |
    +--> SAVECONFIG line length assertion
    |
    +--> 8086 memory limit runs
            |
            +--> generated DOSBox X configurations
                    |
                    +--> TESTHWL.BAT
                            |
                            +--> 3CCFGCLI HELP
```

Real hardware conformance is separate:

```text
TESTHWC.MK
    |
    +--> original 3Com utility writes configuration
    |
    +--> 3CCFGCLI LIST observes resulting state
```

The real hardware suite is deliberately not invoked by the normal automated test path.

## 3. Default Regression Backend

`TEST.MK` defaults to:

```text
BINAPP = BIN\3CHWMOCK.EXE
SEEDAPP = BIN\3CSEED.EXE
```

Therefore the normal `smoke` target exercises the application against MOCKHW.

`3CSEED` creates the deterministic starting hardware states described in [MOCK.md](MOCK.md).

`3CHWMOCK` then behaves as the hardware backend while the application performs normal discovery, reads, configuration transactions, live state changes, and verification.

Application code is not given a test specific shortcut.

The same application logic must operate through the `Nic_*` hardware interface.

## 4. `TEST.BAT`

`TEST.BAT` is a small DOS entry point for Borland MAKE.

With no argument it runs:

```text
smoke
```

A supplied argument replaces the target.

Conceptually:

```text
TEST
    -> MAKE -f TEST.MK smoke

TEST some-target
    -> MAKE -f TEST.MK some-target
```

The batch file contains no test semantics itself.

Those belong to `TEST.MK`.

## 5. `autoexec-test`

The normal DOSBox X regression configuration:

* mounts the repository as drive C
* enters drive C
* calls `TEST`
* exits DOSBox X when the test run ends

The functional regression configuration currently specifies a cycle limit but does not explicitly select an 8086 CPU type.

Therefore the complete regression suite must not be described as a full functional execution suite under explicit 8086 emulation.

The separate hardware limit configuration performs that narrower role.

## 6. `TEST.MK`

`TEST.MK` is the main DOS regression definition.

The default aliases are:

```text
all
    -> smoke

test
    -> smoke
```

The `smoke` target performs preparation, runs all symbolic regression groups, performs cleanup, and writes:

```text
Smoke test: run completed
```

only after the complete dependency chain succeeds.

This completion marker is consumed by the host wrapper.

## 7. Regression Groups

The current `smoke-core` dependency chain consists of the following symbolic targets.

| Symbolic target             | Purpose                                                                                                            |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `LISTING`                   | General adapter listing behavior and the no adapter case                                                           |
| `IRQ_CHANGE`                | IRQ parsing, rejection, configuration, and resulting state                                                         |
| `DEFAULT_NIC_SELECTION`     | Implicit adapter selection when only one adapter exists                                                            |
| `IOBASE_CHANGE`             | I/O base validation, migration, activation, conflicts, and verification                                            |
| `PNP_CHANGE`                | Plug and Play configuration behavior                                                                               |
| `MODEM_CHANGE`              | Modem interrupt disable timing and shared EEPROM field preservation                                                |
| `FD_CHANGE`                 | Full Duplex capability, persistent policy, live synchronization, and transceiver interaction                       |
| `CAPABILITY_GATES`          | Independent hardware capability sources and capability rejection behavior                                          |
| `OPTIMIZE_CHANGE`           | Optimization mode configuration and shared EEPROM state                                                            |
| `LINK_STATUS`               | Live link beat reporting                                                                                           |
| `BOOTROM_CHANGE`            | Boot ROM parsing, capability, Boot ROM Size Valid, physical presence, size, paging, commit, and verification       |
| `XCVR_CHANGE`               | Transceiver selection, capability validation, alias behavior, and cross property rules                             |
| `CLI_PARSER`                | Command parsing, global options, prefixes, invalid syntax, and option namespaces                                   |
| `COMBINED_TRANSACTIONS`     | Multiple requested properties processed through one prospective transaction                                        |
| `MULTI_NIC`                 | Multiple adapters, adapter selection, discovery, and resource conflict handling                                    |
| `SAVECONFIG_TEST`           | Restore command generation, parser compatibility, command splitting, option serialization, and output behavior     |
| `VERIFICATION_CONTROL_FLOW` | Verification sequencing, unchanged properties, verbose paths, and continuation through multi property verification |

The individual numbered tests remain the authoritative detail beneath these symbolic groups.

## 8. Numbered Test Identity

Every numbered test uses an identifier of the form:

```text
tNNNN
```

and writes a corresponding marker:

```text
[tNNNN]
```

to `TEST.LOG` when the test starts.

Examples include:

```text
t0203
t0801
t1127
t1404
t1622
t1714
```

These identifiers provide:

* stable test references
* readable failure location
* automatic execution counting
* grouping by feature area

A new numbered case must be connected to the appropriate symbolic group and therefore to `smoke-core`.

Simply defining a new `tNNNN` target without adding it to the smoke dependency tree causes the host defined versus executed count check to fail.

## 9. Ordered State Is Part Of The Suite

The regression suite is deterministic, but not every numbered target is completely standalone.

Some cases explicitly seed their required state.

Other cases intentionally continue from state established by an earlier case in the same ordered smoke run.

For example, a sequence may:

```text
seed a baseline
reject invalid changes
verify that state remained unchanged
perform a valid change
use the changed state as the starting point for the next case
```

Therefore:

* the `smoke-core` group order is significant
* individual targets are not automatically guaranteed to have all prerequisites
* tests that require independent execution should seed their own starting state
* existing targets must not be freely reordered merely because their identifiers look independent

Determinism belongs to the defined execution chain, not necessarily to each isolated MAKE target.

## 10. Positive Assertions

Most DOS side assertions use the DOS `FIND` command.

Typical structure:

```text
run command
capture output into ARTIFACT\TNNNN.LOG
FIND expected text
```

A missing expected string causes the MAKE command to fail.

This provides simple and deterministic output assertions without requiring a separate DOS test framework.

## 11. Negative Assertions

Some cases must verify that text is absent.

Those cases use the assertion helper under:

```text
ASSERTRS
```

with calls to:

```text
NFIND.BAT
```

Typical use cases include checking that:

* a success message was not printed
* an unchanged message was not printed
* a rejected operation did not continue into a commit path

Positive and negative output checks together allow the suite to validate control flow as well as final state.

## 12. State Verification Through `LIST`

A successful `CONFIGURE` message is not normally treated as sufficient proof of a correct hardware transition.

Many regression cases subsequently run:

```text
LIST
```

and assert the resulting hardware state.

A typical test therefore follows:

```text
seed state

CONFIGURE requested change

assert expected CONFIGURE output

LIST

assert resulting state
```

This is important because the second command runs as a separate DOS process.

With MOCKHW, the result therefore also exercises persistence of the modeled powered device state described in [MOCK.md](MOCK.md).

## 13. Verification Output Tests

Verbose mode exposes additional transaction verification information.

The `VERIFICATION_CONTROL_FLOW` group specifically exercises paths such as:

* EEPROM verification
* live IRQ verification
* Plug and Play verification
* modem verification
* Full Duplex persistent verification
* live Full Duplex verification
* optimization verification
* Boot ROM persistent verification
* Boot ROM live verification
* transceiver verification

These tests do not replace final state checks.

They verify that the expected verification stages themselves are reached.

## 14. Combined Transaction Testing

`COMBINED_TRANSACTIONS` is especially important for the architecture described in [TRANSACTIONS.md](TRANSACTIONS.md).

The group verifies combinations such as:

```text
IOBASE plus INT

MODEM plus FULLDUPLEX

IOBASE plus TR

IOBASE plus Boot ROM configuration

cross property combinations with shared EEPROM words
```

The purpose is to ensure that properties are not implemented as unrelated sequential mini transactions.

Tests must continue to validate the prospective combined state and final commit behavior.

## 15. Capability Fixture Testing

`CAPABILITY_GATES` uses deliberately unusual `3CSEED` fixtures.

These tests verify that application decisions are based on the correct capability source.

Examples include:

```text
Plug and Play absent while Full Duplex remains supported

TP product identity without live TP capability

Plug and Play capability present with older revision classification
```

These are architectural tests.

Their purpose is to prevent future code from replacing the normalized capability model with simpler but incorrect product assumptions.

## 16. Boot ROM Testing

Boot ROM behavior receives a comparatively large regression group because it combines several independent concerns.

The mock suite can exercise:

* parser validation
* base alignment rules
* supported size rules
* paired `/BADDRESS` and `/BSIZE` behavior
* adapter capability gates
* physical ROM absent state
* 8 KB ROM
* 16 KB ROM
* 32 KB paged ROM
* ROM presence probing
* requested size mismatch
* Boot ROM Size Valid preservation
* Boot ROM Size Valid clearing
* secondary checksum handling
* combined transactions
* persistent verification
* live verification

This is possible because MOCKHW models physical Option ROM presence separately from configured Boot ROM state.

The mock tests therefore provide substantially more Boot ROM coverage than the current physical hardware suite.

## 17. Multi Adapter Testing

The `MULTI_NIC` group uses `3CSEED ADD` to construct deterministic multi adapter hardware images.

These tests can exercise:

* adapter enumeration
* logical adapter numbering
* explicit adapter selection
* required adapter selection when several adapters exist
* distinct active I/O bases
* resource conflicts

This capability is specific to the mock test environment.

A physical machine with only one adapter cannot provide equivalent coverage.

## 18. `SAVECONFIG` Regression Testing

`SAVECONFIG_TEST` verifies more than the existence of a generated batch file.

The current suite exercises behavior including:

* default output file generation
* explicit output file
* explicit executable name
* `%1` executable indirection
* invalid executable forms
* missing executable paths
* multiple adapters
* restore command splitting
* command line length management
* modem value serialization
* atomic Boot ROM property pairing
* option ordering
* duplicate option rejection
* global `/VERBOSE`
* separation of CONFIGURE and SAVECONFIG option namespaces

Some cases execute generated restore commands again through the program.

This validates that serialization output remains acceptable to the CLI parser.

## 19. Host Side `SAVECONFIG` Line Length Check

One assertion is intentionally performed outside DOS.

After the smoke suite, `test.sh` examines:

```text
ARTIFACT/RESTORE.BAT
```

with AWK.

The maximum permitted generated line length is currently:

```text
128 characters
```

This assertion exists on the host because checking arbitrary line lengths is unnecessarily awkward in plain DOS batch processing.

The host test fails if any generated restore line exceeds that limit.

This is part of the normal test result.

## 20. Fail Fast DOS Execution

Borland MAKE acts as the DOS side test executor.

A failed assertion causes the MAKE dependency chain to stop.

As a result, later numbered targets are not executed after an earlier failing assertion.

This behavior is intentional.

The suite therefore does not attempt to collect every possible failure in one run.

It prioritizes preserving the first failing state and test artifact.

## 21. Host Completion Guard

`test.sh` does not assume that the DOSBox X process exiting means that the regression suite succeeded.

It explicitly requires:

```text
Smoke test: run completed
```

in `TEST.LOG`.

That marker is written only after the complete `smoke` dependency chain reaches its final target.

If MAKE stopped early, the marker is absent.

The host regression stage therefore fails.

## 22. Defined Versus Executed Guard

The host wrapper performs an additional completeness check.

It counts:

```text
defined tests
    TEST.MK targets matching tNNNN:

executed tests
    TEST.LOG entries matching [tNNNN]
```

The two counts must be equal for a complete successful smoke run.

This catches cases such as:

* an early MAKE abort
* a newly defined test that was not connected to `smoke-core`
* a missing numbered execution marker
* incomplete execution of the dependency chain

The smoke completion marker and test count check are separate guards.

Both are required.

## 23. Overall Host Test Sequence

The standard host sequence is:

```text
1. regression smoke suite

2. SAVECONFIG line length assertion

3. hardware memory limit tests
```

The shell uses success chaining between these stages.

If an earlier stage fails, later stages are not treated as completed.

The summary starts each major stage in a failed state and clears that state only when its corresponding completion condition is observed.

The final result is PASS only when:

```text
smoke completed

defined test count equals executed test count

SAVECONFIG host assertion completed

all hardware limit cases completed
```

## 24. Test Logs And Artifacts

`TEST.LOG` is the overall regression progress and result log.

Individual numbered tests normally write their command output to:

```text
ARTIFACT\TNNNN.LOG
```

Additional generated artifacts include restore batch files and memory limit logs.

This separation is intentional.

`TEST.LOG` answers:

```text
which test ran and did the suite complete?
```

Per test artifacts answer:

```text
what did the application actually print?
```

A failure should therefore be investigated using both.

## 25. Standard Testing Does Not Build

The normal `test.sh` path does not rebuild the binaries before running the smoke suite.

It assumes the binaries to be tested already exist.

`TEST.MK` does contain a separate:

```text
test-build
```

target that performs a build before `smoke-core`.

The project also has separate host build orchestration.

Build validation and regression validation should therefore not be described as one inseparable operation.

When correctness depends on testing freshly modified source, the normal development workflow must ensure the build has succeeded before running the tests.

## 26. Real Hardware Conformance

`TESTHWC.MK` is deliberately separate from `TEST.BAT` and `test.sh`.

It is intended to run manually on a DOS system containing one or more physical EtherLink III adapters.

Only the first logical adapter is used by the current test sequence.

The default roles are:

```text
writer
    original 3Com 3C5X9CFG utility

observer
    3CCFGCLI
```

The original utility writes each requested configuration.

`3CCFGCLI LIST` then reads the resulting adapter state.

This tests whether 3CCFGCLI interprets real EEPROM and live hardware state consistently with configuration written by the original utility.

## 27. What Real Hardware Conformance Proves

The default real hardware suite provides evidence for:

* physical adapter discovery
* active register access
* EEPROM interpretation
* live state interpretation
* decoding of configuration written by the original utility
* LIST compatibility with original utility configuration semantics
* SAVECONFIG reading of the physical adapter

It does not directly prove the correctness of the normal `3CCFGCLI CONFIGURE` write path.

The original utility is the writer during the individual conformance cases.

This distinction is important.

A successful HWC run must not be described as complete proof that every 3CCFGCLI EEPROM write sequence is correct on physical hardware.

## 28. Current Real Hardware Cases

The current enabled real hardware suite contains these cases:

| Case     | Original utility operation | 3CCFGCLI observation                     |
| -------- | -------------------------- | ---------------------------------------- |
| `hwc001` | `/INT`                     | IRQ                                      |
| `hwc002` | `/IOBASE`                  | I/O base                                 |
| `hwc003` | `/PNP`                     | Plug and Play output                     |
| `hwc004` | `/MODEM`                   | Modem interrupt disable timing           |
| `hwc005` | `/FULLDUPLEX`              | Full Duplex state                        |
| `hwc006` | `/OPTIMIZE`                | Optimization state                       |
| `hwc007` | `/TR`                      | Transceiver state                        |
| `hwc008` | `/XCVR`                    | Original transceiver alias compatibility |

Physical Boot ROM conformance is currently disabled because a suitable physical ROM is not available for the test.

## 29. Real Hardware Preservation And Restoration

The actual `hwc` dependency chain currently runs:

```text
clean
prep
save-config
set-default
HWC_CONFIGURATION
restore-config
complete
```

Therefore the adapter configuration is saved before the deterministic test baseline is written.

`save-config` uses:

```text
3CCFGCLI SAVECONFIG
```

to produce the restore batch.

The test then writes a known configuration using the original utility.

After the conformance cases, the generated restore batch is executed.

By default, restoration is performed through the original 3Com utility.

This reduces dependence on the project's own write path while real hardware write confidence is still being established.

## 30. Self Restoration Mode

`TESTHWC.MK` provides:

```text
hwc-restore-self
```

which changes the restore executable from the original utility to `3CCFGCLI`.

This causes the generated restore commands to be replayed through the project's own CONFIGURE implementation.

This mode provides additional physical write exercise.

It is still not equivalent to a complete property by property hardware write conformance suite because the individual HWC cases continue to use the original utility as their writer.

## 31. Physical Hardware Test Values

Real hardware tests use configurable default and test values.

Values such as:

```text
IRQ
I/O base
Plug and Play state
transceiver
```

must be appropriate and conflict free on the physical machine.

Unlike the mock suite, the hardware test environment cannot assume that arbitrary ISA resources are safe.

The operator remains responsible for choosing suitable test resources.

## 32. `TEST.MK real` Is Not The Hardware Conformance Suite

`TEST.MK` contains a `real` target that substitutes:

```text
BINAPP = BIN\3CCFGCLI.EXE
```

for the mock executable.

However, the smoke suite itself contains extensive `3CSEED` fixture assumptions, including synthetic adapters, capability variants, Option ROM models, and multi adapter states.

Changing only `BINAPP` does not reproduce those fixtures on physical hardware.

The same smoke suite also contains write tests that would modify the physical adapter.

Therefore the `TEST.MK real` target must not be treated as equivalent to `TESTHWC.MK` or as authoritative real hardware conformance evidence.

The dedicated real hardware architecture is `TESTHWC.MK`.

## 33. Current HWC Ordering Comment Issue

A comment in the current `TESTHWC.MK` states that the sane default configuration is written before the baseline SAVECONFIG capture.

The actual dependency chain does the opposite:

```text
save-config
set-default
```

The executed order is authoritative.

This is desirable for preservation because it captures the adapter's preexisting configuration before test defaults are written.

The comment should not be used to infer the runtime behavior.

## 34. Hardware Limit Testing

The hardware limit phase is separate from the functional regression suite.

`test.sh` currently runs three configurations:

```text
64 KB
128 KB
256 KB
```

For each size it generates a temporary DOSBox X configuration from:

```text
autoexec-testhwl.template
```

The configuration explicitly selects:

```text
cputype = 8086
core = normal
```

and sets the requested conventional memory size.

## 35. `TESTHWL.BAT`

The memory test performs:

```text
MEM

3CCFGCLI HELP
```

`MEM` is allowed to fail under the smallest memory configuration.

The actual assertion is whether:

```text
3CCFGCLI HELP
```

can execute without returning an error condition.

A successful run prints:

```text
HWLIMIT PASS memsizekb=N
```

The host wrapper searches for this exact marker.

## 36. What The Hardware Limit Test Proves

The hardware limit suite proves only that the executable can be loaded and execute the HELP path under the tested DOSBox X 8086 memory configurations.

It does not prove:

* LIST operation under those memory limits
* discovery under those memory limits
* CONFIGURE under those memory limits
* SAVECONFIG under those memory limits
* multi adapter operation under those memory limits
* maximum stack usage under every program path
* minimum possible memory requirement below 64 KB
* functional correctness of the complete application on an 8086

It is a resource startup test.

It must not be described as a complete 8086 functional regression suite.

## 37. 8086 Validation Boundary

The project targets 8086 and 8088 compatible code.

The current test framework contributes two different kinds of evidence:

```text
normal regression suite
    broad functional coverage
    CPU type not explicitly forced to 8086 in autoexec-test

hardware limit suite
    explicitly uses DOSBox X 8086 mode
    only exercises the HELP startup path
```

Therefore architectural 8086 compatibility still depends on source and build discipline in addition to runtime tests.

The test framework alone does not execute all functional paths under explicit 8086 emulation.

## 38. Mock Tests Versus Original Utility Compatibility

The mock regression suite validates the behavior defined by this project.

It must not automatically treat every behavior of the original 3Com utility as desired behavior.

The project deliberately omits unsupported original features.

Regression tests should therefore encode:

* current project scope
* chosen original compatibility semantics where intentionally retained
* architecture contracts documented by this project

The original utility is a reference for compatibility behavior, not an automatic source of new requirements.

## 39. Mock Tests Versus Real Hardware

Mock testing provides advantages that physical testing cannot easily provide.

It can deterministically construct:

* multiple adapters
* inactive adapters
* resource conflicts
* unusual capability combinations
* stale persistent and live state
* absent Option ROM
* multiple Option ROM sizes
* Boot ROM Size Valid edge cases

Real hardware provides a different advantage.

It validates assumptions against the actual ASIC, EEPROM, ISA bus, and physical adapter.

Neither environment replaces the other.

The preferred evidence model is:

```text
mock regression
    broad deterministic behavior coverage

original utility comparison
    compatibility evidence

real hardware
    physical implementation evidence
```

## 40. Adding A Regression Test

A new normal regression should normally:

1. Be assigned a stable `tNNNN` identifier.

2. Be added to the appropriate symbolic group.

3. Ensure that group remains reachable from `smoke-core`.

4. Establish any starting hardware state it requires, either explicitly or through a clearly intentional ordered dependency.

5. Execute the public CLI behavior being tested.

6. Capture relevant output in an artifact log.

7. Assert expected output.

8. Assert forbidden output when control flow matters.

9. Verify resulting hardware state through `LIST` or another appropriate public observation path.

10. Avoid directly modifying mock internals merely to manufacture the expected result after the command under test.

11. Keep deterministic fixture creation in `3CSEED`; do not use the Seeder as a postcondition checker or test oracle.

12. Leave the test count and execution marker mechanism intact.

## 41. Adding A Real Hardware Test

A new `TESTHWC.MK` case must be treated more conservatively.

It should:

1. Operate on the selected physical adapter only.

2. Use resource values known to be safe on the target system.

3. Preserve the original configuration before modification.

4. Use the original utility as the writer when the purpose is observer conformance.

5. Use `3CCFGCLI LIST` as the observation path.

6. Assert the exact property that was changed.

7. Restore the original configuration after the suite.

8. Clearly identify tests that require optional physical hardware such as an Option ROM.

9. Avoid implying that observer conformance proves the project's own write implementation.

## 42. Required Architectural Invariants

The following rules are mandatory for future test framework changes.

1. The normal automated regression suite must default to MOCKHW.

2. `3CSEED` must remain deterministic.

3. Mock test fixtures must model starting hardware state rather than replacing runtime backend behavior.

4. Numbered regression targets must use stable `tNNNN` identifiers.

5. Every numbered test must produce its corresponding execution marker.

6. Every numbered test intended for the normal suite must be reachable from `smoke-core`.

7. The defined versus executed count guard must remain intact.

8. The smoke completion marker must only be written after the complete smoke dependency chain succeeds.

9. A DOSBox X process exit alone must not be treated as successful regression completion.

10. Expected output assertions must fail the MAKE chain when absent.

11. Tests that require forbidden output checks must use an explicit negative assertion.

12. Final hardware state should be observed after configuration where practical rather than trusting success text alone.

13. Combined property behavior must have combined transaction coverage.

14. Capability logic must retain fixtures whose product identity and capability sources deliberately disagree.

15. Persistent and live state divergence fixtures must remain available for synchronization tests.

16. Multi adapter behavior must continue to be tested with deterministic mock records.

17. Physical Option ROM absence and supported ROM sizes must remain independently testable in MOCKHW.

18. Host side assertions are acceptable when DOS provides no practical equivalent.

19. The hardware limit suite must not be represented as full functional coverage.

20. The full smoke suite must not be represented as explicitly running under 8086 emulation unless its DOSBox X configuration is changed to do so.

21. `TESTHWC.MK` must remain separate from normal unattended mock regression execution.

22. Default HWC observer tests must distinguish original utility writes from 3CCFGCLI writes.

23. Real hardware state must be preserved and restored around destructive conformance testing.

24. Real hardware test values must be chosen with target machine resource conflicts in mind.

25. The `TEST.MK real` substitution target must not be treated as equivalent to the dedicated HWC methodology.

26. Test coverage must follow project architecture and scope rather than blindly reproducing every feature of the original utility.

27. Current known harness defects must not be converted into architectural expectations merely because a test file contains them.

## 43. Summary

The current test architecture is layered:

```text
TEST.MK plus MOCKHW
    broad deterministic functional regression

test.sh
    orchestration, completeness checks, host assertions, final status

TESTHWC.MK
    manual original utility versus real hardware observation conformance

TESTHWL.BAT
    constrained 8086 startup and memory sanity
```

The strongest confidence comes from combining these layers.

The mock suite provides breadth and deterministic edge cases.

The original utility provides compatibility reference behavior.

Physical adapters validate real ASIC and EEPROM assumptions.

The memory limit suite confirms that the executable can at least start in deliberately constrained 8086 environments.

Each layer must remain clear about what it proves and what it does not.

