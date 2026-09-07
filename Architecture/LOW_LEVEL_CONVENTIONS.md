# Low Level Conventions

## 1. Purpose

This document defines the low level conventions used by `3CCFGCLI`, `3CHWIF`, and `3CMOCKIF`.

These conventions cover:

* carry flag success and failure contracts
* validity of returned register values
* EEPROM error handling
* valid `FFFFh` EEPROM data
* timeout propagation
* `cfg_last_error`
* FLAGS preservation
* interrupt state handling
* register preservation
* register window preservation
* backend equivalence

These rules are especially important because the code base does not use one universal procedure ABI for every internal routine.

The contract of each procedure depends on its documented inputs, outputs, preserved state, and flags.

Related architecture documents are:

[BACKEND.md](BACKEND.md)

[DISCOVERY.md](DISCOVERY.md)

[STATE_MODEL.md](STATE_MODEL.md)

[TRANSACTIONS.md](TRANSACTIONS.md)

[EEPROM.md](EEPROM.md)

[CAPABILITIES.md](CAPABILITIES.md)

[MOCK.md](MOCK.md)

## 2. Procedure Contracts Are Explicit

There is no repository wide rule that every procedure returns success or failure in CF.

Some procedures use CF as a result.

Some procedures return data only.

Some deliberately always return with CF clear.

Some leave FLAGS undefined.

Some have no flag contract at all.

The contract documented for the individual procedure therefore takes precedence.

A caller must not infer a CF contract merely because another nearby routine uses CF.

For example:

```text
Nic_EEPROM_Read
    CF clear means success
    CF set means timeout

Nic_Check_3Com_Signature
    CF clear means a supported adapter signature was found
    CF set means the signature check failed

Cfg_Probe_Boot_ROM
    CF clear means a valid ROM was found
    CF set means invalid or inaccessible ROM

Nic_Read_Capabilities
    CF is always clear
    individual source failures are represented by validity bits

Nic_IdPort_Read_Word
    returns a 16 bit serial value
    has no CF error result
```

Code that consumes one of these procedures must follow that procedure's actual contract.

## 3. Carry Flag Convention

Where a procedure defines a CF success and failure result, the normal convention is:

```text
CF clear
    requested operation succeeded

CF set
    requested operation failed
```

The returned data is valid only according to that procedure's success contract.

The important rule is not merely that CF exists.

The important rule is that callers must test CF before consuming outputs that are documented as invalid on failure.

A typical pattern is:

```asm
call    Nic_EEPROM_Read
jc      @@Fail
mov     [destination], ax
```

The caller must not use `AX` first and inspect CF later.

## 4. EEPROM Read Contract

The common backend EEPROM read interface is:

```text
Input
    DX = active adapter I/O base
    AL = EEPROM word address

Success
    CF clear
    AX = EEPROM word

Timeout
    CF set
    AX is unspecified and must not be used
```

This contract is implemented by both `3CHWIF` and `3CMOCKIF`.

Application code must therefore use CF as the authoritative indication of EEPROM read success.

The value returned in `AX` is data, not an error code.

## 5. `FFFFh` Is Valid EEPROM Data

`FFFFh` must not be used as a generic EEPROM read failure sentinel.

The EEPROM model explicitly supports the erased state.

An erase operation writes:

```text
FFFFh
```

to the selected EEPROM word.

A subsequent successful read of that word can therefore legitimately produce:

```text
AX = FFFFh
CF clear
```

That is a successful EEPROM read whose data happens to contain all ones.

The only portable interpretation is:

```text
CF clear
    AX is EEPROM data, including FFFFh

CF set
    EEPROM read failed, AX must be ignored
```

Any new EEPROM code that performs:

```asm
cmp     ax, 0FFFFh
je      @@ReadFailed
```

without first having a separate procedure specific reason to interpret the value that way is incorrect.

## 6. Timeout Values Must Not Become Configuration Data

A failed EEPROM read must not be converted into a configuration value.

For example, record construction for an active adapter performs each required EEPROM read and immediately checks CF.

If any required read fails, record construction fails.

The failed value is not stored into the adapter record.

The same rule applies during configuration snapshot, checksum calculation, commit verification, and other correctness critical paths.

Failure and data must remain separate.

## 7. Raw Register `FFFFh` Is A Different Contract

The EEPROM rule does not mean that `FFFFh` can never be used as a hardware sentinel.

Raw ISA register access has a different contract.

For example, the mock backend returns `FFFFh` for an I/O read when no active adapter decodes the requested port.

The signature probe also treats a Status Register value of `FFFFh` as evidence that no usable adapter is responding at that base.

Some live register consumers likewise treat `FFFFh` as unavailable hardware.

These are register or bus level conventions.

They must not be copied into EEPROM handling.

The distinction is:

```text
EEPROM word read
    CF determines success
    FFFFh can be data

specific raw register or I/O probe
    FFFFh may be defined by that path as absent hardware
```

The meaning belongs to the interface being used.

## 8. Software Sentinels Are Not Hardware Error Codes

Higher level application state sometimes initializes cached display values to `FFFFh`.

Examples include extended `LIST` information such as:

```text
ext_addr_cfg
ext_compatibility
ext_config_ctrl
ext_revision_info
ext_link_status
ext_software_info
ext_nic_capabilities
```

In those variables, `FFFFh` is an application level unavailable marker.

That convention does not redefine the low level EEPROM interface.

The normal flow is still:

```text
perform hardware read
check its real success contract
store the result when available
otherwise retain the application sentinel
```

A software sentinel must never be used to replace CF at the hardware access boundary.

## 9. Generic EEPROM Access And CONFIGURE EEPROM Access

There are two distinct EEPROM access layers in the current architecture.

### 9.1 `Nic_EEPROM_Read`

`Nic_EEPROM_Read` is part of the common backend interface.

It performs an EEPROM read through the active adapter interface and returns its immediate result through CF.

It is used by code such as:

* active adapter record construction
* capability discovery
* extended `LIST` information
* `SAVECONFIG`

Its contract must remain equivalent between REALHW and MOCKHW.

### 9.2 `Cfg_Eeprom_Read`

`Cfg_Eeprom_Read` is the configuration compatibility layer derived from the original utility's EEPROM access sequence.

It has additional transaction specific behavior.

It:

* selects Window 0
* intentionally does not restore the previous window
* uses the shared CONFIGURE timeout latch
* exposes the latched timeout result through CF
* records timeout state through `cfg_last_error`

It must not be replaced mechanically with `Nic_EEPROM_Read` merely because both routines read EEPROM words.

Their architectural roles are different.

## 10. CONFIGURE Timeout Latch

CONFIGURE maintains:

```text
cfg_timeout_latched
```

for its original compatible EEPROM transaction behavior.

The latch is cleared when a new configuration transaction begins.

If `Cfg_Eeprom_Wait_Ready` times out, it:

```text
sets cfg_timeout_latched
sets cfg_last_error to CFG_ERR_EEPROM_TIMEOUT
returns with CF set
```

Once the timeout has been latched, subsequent CONFIGURE EEPROM operations in that transaction must preserve the failure state.

`Cfg_Eeprom_Read` checks the latch before beginning a new read.

It also checks the latch before reporting success.

This prevents a later apparently successful access from erasing the fact that an earlier EEPROM operation already failed.

## 11. CONFIGURE EEPROM Write Compatibility

`Cfg_Eeprom_Write` deliberately follows the original utility's command sequence.

The sequence includes:

```text
select Window 0
write enable
wait
erase selected word
wait
write data
write enable
wait
program selected word
wait
```

The routine deliberately continues through the command sequence after a timeout because that behavior is part of the retained original compatibility path.

It does not report intermediate calls as independent transaction successes.

At completion, the shared timeout latch determines the returned CF state.

Therefore callers must test the final CF result from `Cfg_Eeprom_Write`.

They must not assume that reaching a later part of the command sequence means an earlier operation succeeded.

## 12. Error Propagation Has Two Layers

CONFIGURE uses two related but distinct error mechanisms.

### 12.1 CF

CF is used for immediate control flow between procedures.

For example:

```asm
call    Cfg_Txn_Read_Current
jc      @@Done

call    Cfg_Txn_Preflight
jc      @@Done

call    Cfg_Txn_Write_EEPROM
jc      @@Done

call    Cfg_Txn_Write_Live
jc      @@Done

call    Cfg_Txn_Verify
jc      @@Done
```

CF answers:

```text
did this stage succeed?
```

### 12.2 `cfg_last_error`

`cfg_last_error` records the reason that will eventually be reported to the user.

It answers:

```text
why did this stage fail?
```

The top level CONFIGURE path ultimately reports `cfg_last_error`.

This allows low level procedures to remain compact while preserving a meaningful diagnostic classification.

## 13. More Specific Errors Must Be Preserved

Higher layers must not overwrite a more specific error already established by a lower layer.

The main example is EEPROM timeout handling.

When a lower level access has already set:

```text
CFG_ERR_EEPROM_TIMEOUT
```

transaction stages check for that error before translating the failure into a property specific error such as:

```text
CFG_ERR_IOBASE_EEPROM_READ
CFG_ERR_PNP_EEPROM_READ
CFG_ERR_MODEM_EEPROM_READ
CFG_ERR_OPTIMIZE_EEPROM_READ
CFG_ERR_BADDRESS_EEPROM_WRITE
CFG_ERR_VERIFY
```

The timeout classification takes priority because it explains the actual hardware failure.

The general rule is:

```text
preserve an existing more specific lower level error

only assign a higher level contextual error when no stronger error has already been established
```

## 14. CF And `cfg_last_error` Must Stay Consistent

For CONFIGURE routines that advertise both a CF result and `cfg_last_error`, failure requires both pieces of state to remain meaningful.

For example, `Cfg_Revalidate_Selected` documents:

```text
CF set
    validation failed
    cfg_last_error contains the reason
```

A caller checks CF to decide whether execution can continue.

The eventual reporting path reads `cfg_last_error`.

A future change must not create a state where:

```text
CF clear
cfg_last_error reports failure
```

for a routine whose documented contract says CF represents success, nor:

```text
CF set
cfg_last_error was accidentally cleared
```

when a reportable failure is required.

## 15. Not Every Source Failure Becomes CF Failure

Some procedures intentionally aggregate several optional hardware sources.

`Nic_Read_Capabilities` is the important example.

Its contract is:

```text
AX = normalized capability bits
BX = validity bits
CF always clear
```

An EEPROM capability read can fail while connector information remains valid.

A revision read can fail while Plug and Play capability remains valid.

Those source failures are represented by clear validity bits rather than by returning CF set from the whole capability operation.

This is intentional.

A caller must not convert an unavailable optional source into total procedure failure when the procedure's contract explicitly provides per source validity.

## 16. Required Reads And Optional Reads Differ

Failure handling depends on why the information is being read.

During active adapter record construction, required EEPROM reads are necessary to construct a trustworthy adapter record.

A failed read therefore aborts record construction.

During extended `LIST` collection, individual optional display values can fail independently.

The corresponding display field remains unavailable while other information can still be shown.

The low level read contract is the same in both cases.

The consumer decides whether that read is mandatory for the operation being performed.

## 17. FLAGS Are Not Globally Preserved

There is no general rule that a procedure preserves FLAGS.

Arithmetic, comparisons, hardware access helpers, and ordinary procedure calls may alter FLAGS.

A caller must therefore assume FLAGS are clobbered unless a procedure explicitly documents otherwise or the caller deliberately preserves them.

This is especially important for CF.

Code must not:

```text
produce a CF result
call an unrelated helper
then assume CF still contains the earlier result
```

unless the helper explicitly preserves FLAGS.

## 18. Preserving A CF Result Across Cleanup

`Cfg_Probe_Boot_ROM` demonstrates the required pattern.

The procedure determines its final result in CF.

Before returning, it must restore Option ROM page zero.

`Nic_Rom_Set_Page` explicitly leaves FLAGS undefined.

The probe therefore does:

```asm
pushf
xor     al, al
call    Nic_Rom_Set_Page
popf
```

The cleanup operation is performed while the already determined CF result is preserved.

This pattern should be used whenever:

* a procedure has already established its flag result
* cleanup is still required
* the cleanup operation does not promise to preserve FLAGS

Do not rely on the cleanup routine accidentally leaving CF unchanged.

## 19. `POPF` And Return Flags

`POPF` restores the saved FLAGS value, including CF and IF.

This has two important consequences.

First, a result produced inside a `PUSHF` and `POPF` region is discarded by the final `POPF` unless it is deliberately preserved.

Second, a procedure that promises a CF result must establish that result after its final `POPF`, or explicitly save and restore the intended result as `Cfg_Probe_Boot_ROM` does.

`Cfg_Revalidate_Selected` follows this discipline.

Its ID port critical section restores FLAGS first.

Its final success or failure path then explicitly executes `CLC` or `STC`.

## 20. Interrupt State Must Be Restored, Not Assumed

Physical ID port sequences require short critical sections with interrupts disabled.

The current convention is:

```asm
pushf
cli

    hardware critical section

popf
```

The purpose of `PUSHF` and `POPF` is not merely to enable interrupts again afterward.

It restores the caller's original interrupt state.

If the caller entered with interrupts enabled, they become enabled again.

If the caller entered with interrupts already disabled, they remain disabled.

An unconditional `STI` would violate this contract.

Therefore code must not replace:

```asm
pushf
cli
...
popf
```

with:

```text
CLI
...
enable interrupts unconditionally
```

The previous IF state belongs to the caller and must be preserved.

## 21. ID Port Critical Sections

Interrupt exclusion is used around the ID port sequences that must execute as one hardware interaction.

Current examples include:

* initial real hardware ID port initialization
* ID port discovery
* selected adapter revalidation through its tag
* retagging after deactivation
* selected adapter deactivation
* selected adapter activation
* tagged card activation in the real hardware backend

The protected region contains the hardware sequence that must not be disrupted.

The interrupt state is restored before normal application processing continues.

Interrupt disabling must not be expanded across unrelated parsing, display, EEPROM checksum calculation, or other long running work.

## 22. The Mock Does Not Need A Second Interrupt Model

`3CMOCKIF` models the observable NIC behavior of ID port operations.

It does not contain its own `CLI` and `STI` implementation.

The application code still executes its normal critical section structure when built with MOCKHW.

The mock backend is responsible for modeling device behavior, not for inventing a separate CPU interrupt state.

REALHW and MOCKHW therefore do not need identical internal instructions.

They need equivalent hardware facing procedure contracts.

## 23. Register Preservation Is Procedure Specific

The code base does not define one universal rule such as:

```text
all AX, BX, CX, DX registers are caller saved
```

or:

```text
all registers except AX are always preserved
```

Instead, procedures explicitly preserve the registers that must survive according to their local contract.

Typical internal helpers use `PUSH` and `POP` around scratch registers.

Output registers are naturally not restored when they carry return values.

Callers must therefore use the documented interface rather than assuming a generic compiler calling convention.

## 24. Backend Procedure Contracts Must Match

Procedures exposed by REALHW and MOCKHW must have equivalent externally observable contracts.

This includes:

* input registers
* output registers
* CF meaning
* registers documented as preserved
* whether FLAGS are defined or undefined
* register window preservation
* behavior when hardware is absent
* behavior on timeout

The two implementations do not need identical instruction sequences.

For example, REALHW performs physical `IN` and `OUT` instructions while MOCKHW resolves an adapter record.

The caller must nevertheless be able to use either implementation without changing its assumptions.

## 25. `Nic_Rom_Read_Byte`

The Option ROM byte reader has an explicit cross backend contract.

Input:

```text
DX = adapter base
ES:BX = mapped ROM address
```

Output:

```text
AL = ROM byte
AH undefined
FLAGS undefined
```

Preserved:

```text
BX
CX
DX
SI
DI
BP
DS
ES
```

REALHW reads physical memory.

MOCKHW synthesizes the corresponding ROM byte.

The register and flag contract must remain the same.

## 26. `Nic_Rom_Set_Page`

The Option ROM page selector also has an explicit contract.

Input:

```text
DX = adapter base
AL = ROM page
```

It preserves:

```text
all caller registers
the previously selected live register window
```

FLAGS are undefined.

This undefined flag contract is why callers such as `Cfg_Probe_Boot_ROM` must explicitly preserve CF when necessary.

## 27. Register Window Preservation Is Not Universal

Register window state is hardware state.

Procedures therefore need an explicit policy about whether they restore the previous window.

Some shared operations preserve it.

Examples include:

```text
Nic_Check_3Com_Signature
Nic_Read_Capabilities
Nic_Rom_Set_Page
```

Other routines intentionally do not.

`Cfg_Eeprom_Read`, for example, selects Window 0 and deliberately leaves it selected to match the original configuration routine.

A caller must not assume that every helper restores the previous window.

A new procedure that temporarily changes windows should either:

* restore the caller's window, when that is part of its abstraction
* clearly document that it intentionally leaves another window selected

Silent accidental window changes are not acceptable.

## 28. Restoring Hardware State On Failure

A routine that temporarily changes hardware state should restore that state on both success and failure when its contract promises restoration.

`Nic_Check_3Com_Signature` saves the existing register window before probing Window 0 and Window 4.

If a later signature test fails after the original window has been captured, the failure path restores that window before returning.

The restoration is part of the procedure's hardware state contract, not merely cosmetic cleanup.

The same principle applies to temporary Option ROM page selection and similar stateful hardware interfaces.

## 29. Raw I/O Helpers Are Minimal

The backend raw I/O primitives intentionally have very small contracts.

For REALHW:

```text
Nic_IO_Read_Word
    DX = physical ISA port
    AX = word read

Nic_IO_Write_Word
    DX = physical ISA port
    AX = word written
```

MOCKHW interprets those same physical port accesses against the active mock adapter records.

Higher level code should not add application policy to these primitives.

They are hardware access mechanisms.

Validation and configuration policy belongs above them.

## 30. ID Port EEPROM Reads Have A Different Interface

`Nic_IdPort_Read_Word` is hardware independent shared code used during ISA contention and tagged adapter access.

It sends the EEPROM word request and collects 16 serial bits through `Nic_IdPort_Read_Bit`.

It returns the resulting word in `AX`.

It does not provide the active adapter EEPROM timeout contract used by `Nic_EEPROM_Read`.

These two read mechanisms must not be conflated.

The ID port serial discovery path and the active adapter EEPROM register path are distinct hardware interfaces.

## 31. Stack Balance Is Part Of The Contract

Any procedure that pushes registers, FLAGS, or temporary values must unwind every exit path correctly.

This is particularly important in assembly procedures with several failure branches.

A failure path must not skip a required:

```text
POP
POPF
```

or return with temporary data still on the stack.

Likewise, success and failure branches must restore the same preserved registers unless an output contract says otherwise.

This requirement applies even when the program terminates soon afterward, because these procedures are shared and can be called from multiple paths.

## 32. Do Not Preserve A Register By Destroying The Result

Register restoration must be designed around outputs.

For example, a routine returning data in `AX` cannot blindly restore an entry value of AX before return.

Likewise, a routine returning ASIC revision in `BL` cannot restore the caller's original `BX` after producing that result unless the output is moved elsewhere first.

The procedure's documented outputs define which entry values may be replaced.

Preservation is not an end in itself.

Correct output state is part of the ABI.

## 33. Failure Outputs Must Be Treated As Undefined When Documented

When a procedure says an output is unspecified after failure, callers must treat it as unusable even if the current implementation happens to place a recognizable value there.

`Nic_EEPROM_Read` currently places `FFFFh` in AX on its backend timeout paths.

Its documented contract still says AX is unspecified on timeout.

Therefore code must not depend on:

```text
timeout produces AX = FFFFh
```

That implementation detail may change without changing the interface.

The stable contract is:

```text
CF set
AX unusable
```

## 34. Cleanup Must Not Hide Failure

A cleanup or restoration action performed after an error must not accidentally turn the procedure into apparent success.

Examples include:

* restoring a register window
* returning Option ROM page selection to zero
* restoring FLAGS after an interrupt critical section
* restoring temporary registers

The original failure result must survive the cleanup according to the procedure contract.

If CF is the result channel, cleanup that changes FLAGS requires explicit CF preservation.

If `cfg_last_error` is the diagnostic channel, cleanup must not clear it.

## 35. Application State Must Update Only After Verified Success

Low level success propagation ultimately protects higher level state.

For example, the CONFIGURE transaction updates the in memory NIC record only after its hardware commit and verification stages have succeeded.

A low level error must therefore propagate far enough to prevent application state from claiming a configuration that was not successfully established.

This rule connects the CF conventions in this document to the transaction rules in [TRANSACTIONS.md](TRANSACTIONS.md).

## 36. Required Architectural Invariants

The following rules are mandatory for future changes.

1. CF must be interpreted only according to the called procedure's documented contract.

2. A procedure with no CF contract must not accidentally become a source of success or failure state for its caller.

3. `Nic_EEPROM_Read` success is determined by CF, not by the value in AX.

4. `FFFFh` must remain valid EEPROM data when CF is clear.

5. AX must not be consumed after a failed `Nic_EEPROM_Read`.

6. A timeout value must never be converted into adapter configuration data.

7. Raw register uses of `FFFFh` must remain separate from EEPROM error handling.

8. Application level `FFFFh` unavailable sentinels must not replace hardware access status.

9. The CONFIGURE timeout latch must preserve an EEPROM timeout across the complete compatible EEPROM operation.

10. A more specific lower level error must not be overwritten by a less specific higher level error.

11. CF and `cfg_last_error` must remain consistent where a procedure documents both.

12. Per source validity flags must be used where a procedure deliberately aggregates independent optional sources.

13. FLAGS must be considered undefined unless a procedure explicitly defines or preserves them.

14. A CF result that must survive a cleanup call with undefined FLAGS must be preserved explicitly.

15. A final `POPF` must not accidentally overwrite a procedure's intended CF result.

16. Interrupt critical sections must restore the caller's original FLAGS with `POPF`.

17. Interrupt state must not be unconditionally enabled after a critical section.

18. Interrupt disabling must remain limited to the hardware sequence that requires it.

19. Register preservation must follow each procedure's actual input and output contract.

20. REALHW and MOCKHW implementations of a common `Nic_*` procedure must expose equivalent register, flag, and hardware state behavior.

21. Register window preservation must be explicit and procedure specific.

22. A procedure that promises hardware state restoration must restore it on both success and applicable failure paths.

23. Failure outputs documented as unspecified must never become dependencies of higher level code.

24. Every exit path must leave the stack balanced.

25. Cleanup and restoration must not hide an earlier failure.

26. Higher level software state must not be updated as though hardware modification succeeded until the required verification path has completed.

## 37. Summary

The low level architecture relies on explicit procedure contracts rather than implicit conventions.

The central rules are:

```text
CF is meaningful only when the procedure defines it

EEPROM success is CF clear

FFFFh can be valid EEPROM data

failed EEPROM output must be ignored

raw register FFFFh semantics are separate

cfg_last_error explains CONFIGURE failure

CF propagates immediate control flow

specific lower level errors must survive higher layers

FLAGS are not preserved by default

interrupt state is restored with PUSHF and POPF

register preservation is procedure specific

register window preservation is procedure specific

REALHW and MOCKHW must expose the same external contracts
```

These rules prevent hardware errors, valid data, CPU state, and temporary implementation details from becoming accidentally interchangeable.

