# Architecture Invariants

## 1. Purpose

This document is the compact list of non negotiable architectural rules for 3CCFGCLI.

It is intended for:

* maintainers
* code review
* automated coding agents
* regression analysis
* future refactoring

It does not replace the detailed architecture documents.

Those documents explain why these rules exist.

This file states what must remain true.

The terms **must** and **must not** are intentional.

If a future change genuinely requires one of these invariants to change, the corresponding architecture document must be reconsidered deliberately. The implementation must not silently violate an invariant simply because a local change is easier that way.

Related documents are:

[BACKEND.md](BACKEND.md)

[DISCOVERY.md](DISCOVERY.md)

[STATE_MODEL.md](STATE_MODEL.md)

[TRANSACTIONS.md](TRANSACTIONS.md)

[EEPROM.md](EEPROM.md)

[CAPABILITIES.md](CAPABILITIES.md)

[MOCK.md](MOCK.md)

[LOW_LEVEL_CONVENTIONS.md](LOW_LEVEL_CONVENTIONS.md)

[TESTING.md](TESTING.md)

## 2. Project Scope

| ID             | Invariant                                                                                                                                                 |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INV-SCOPE-01` | The supported hardware scope is ISA 3C509 and 3C509B family adapters. EISA and MCA support must not be reintroduced implicitly.                           |
| `INV-SCOPE-02` | Features intentionally removed from the reduced utility must remain removed unless a task explicitly changes project scope.                               |
| `INV-SCOPE-03` | The program must remain compatible with 8086 and 8088 class processors. Instructions requiring an 80186 or later CPU must not be introduced.              |
| `INV-SCOPE-04` | The target remains 16 bit DOS using the existing TASM based build environment.                                                                            |
| `INV-SCOPE-05` | The original 3Com utility is a compatibility reference. It is not by itself authority to reintroduce functionality that this project intentionally omits. |
| `INV-SCOPE-06` | System PnP BIOS detection and integration are outside project scope. `/PNP` configures adapter policy only and must not be interpreted as requiring PnP BIOS cooperation or the original utility's PnP-BIOS-specific Boot ROM path. |

## 3. Backend Boundary

| ID               | Invariant                                                                                                                                                   |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INV-BACKEND-01` | Application logic must access NIC hardware through the common `Nic_*` interface.                                                                            |
| `INV-BACKEND-02` | Application logic must not contain separate REALHW and MOCKHW hardware behavior.                                                                            |
| `INV-BACKEND-03` | REALHW and MOCKHW implementations of a common `Nic_*` operation must expose equivalent externally visible contracts.                                        |
| `INV-BACKEND-04` | Equivalent backend contracts include inputs, outputs, CF semantics, documented register preservation, hardware state effects, and failure behavior.         |
| `INV-BACKEND-05` | Backend code must provide hardware mechanisms, not application policy.                                                                                      |
| `INV-BACKEND-06` | Capability policy, transaction policy, validation, and user visible decisions belong in shared application logic rather than independently in each backend. |
| `INV-BACKEND-07` | Hardware independent algorithms must remain shared when they can operate through backend primitives.                                                        |

See [BACKEND.md](BACKEND.md).

## 4. Discovery And Adapter Identity

| ID            | Invariant                                                                                                                                                 |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INV-DISC-01` | ISA ID port discovery and active I/O base scanning are both valid discovery sources.                                                                      |
| `INV-DISC-02` | Active and inactive adapters must remain distinguishable. Discovery must not imply that every known adapter currently decodes an I/O base.                |
| `INV-DISC-03` | ID port tagging, tag selection, and ISA activation are separate hardware operations and must not be treated as interchangeable.                           |
| `INV-DISC-04` | An ID tag identifies an adapter within the ID port mechanism. It is not equivalent to active ISA decode state.                                            |
| `INV-DISC-05` | Active register access must target an adapter actually decoding the requested I/O base.                                                                   |
| `INV-DISC-06` | Unsupported contenders must not be turned into supported `nic_table` records merely because they are visible through the ID port.                         |
| `INV-DISC-07` | Duplicate discovery paths must not create duplicate logical records for the same adapter.                                                                 |
| `INV-DISC-08` | Required EEPROM failure while constructing an active adapter record must abort that record construction. Failed read values must not become adapter data. |
| `INV-DISC-09` | A logical adapter selected from the discovery table must be revalidated against hardware before CONFIGURE modifies it.                                    |

See [DISCOVERY.md](DISCOVERY.md).

## 5. Persistent And Live State

| ID             | Invariant                                                                                                                                                     |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INV-STATE-01` | EEPROM state and live ASIC or register state are different state domains.                                                                                     |
| `INV-STATE-02` | EEPROM and live registers must not be treated as continuously mirrored.                                                                                       |
| `INV-STATE-03` | Synchronization between persistent and live state must occur only at defined hardware transitions or explicit application synchronization points.             |
| `INV-STATE-04` | Reset may reload reset backed live state from EEPROM, but it must not erase or recreate persistent EEPROM configuration.                                      |
| `INV-STATE-05` | ISA activation state and configured I/O base state are separate. Changing stored configuration alone must not be assumed to move active decode.               |
| `INV-STATE-06` | The live Window 2 station address must remain distinct from the EEPROM node address unless verified hardware behavior deliberately changes this architecture. |
| `INV-STATE-07` | Live state may legitimately disagree with persistent state until a documented synchronization operation occurs.                                               |
| `INV-STATE-08` | Starting another DOS process must not itself be treated as a hardware reset in MOCKHW.                                                                        |

See [STATE_MODEL.md](STATE_MODEL.md).

## 6. CONFIGURE Transactions

| ID           | Invariant                                                                                                                                                   |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INV-TXN-01` | Parsing and property handlers must stage requested values before hardware mutation.                                                                         |
| `INV-TXN-02` | Property parsing must not perform independent EEPROM or live register commits.                                                                              |
| `INV-TXN-03` | The selected adapter must be revalidated before the transaction can modify hardware.                                                                        |
| `INV-TXN-04` | Hardware and product capability gates must run before a gated parameter is reported as accepted and before any write occurs.                                |
| `INV-TXN-05` | The transaction must read the current hardware state required by all requested properties before constructing the proposed result.                          |
| `INV-TXN-06` | Prospective state must begin as an exact copy of the current snapshot.                                                                                      |
| `INV-TXN-07` | Requested changes must be applied to the prospective image, not directly to hardware while validation is still in progress.                                 |
| `INV-TXN-08` | Cross property validation must use the effective final prospective state of the complete combined transaction.                                              |
| `INV-TXN-09` | A property that would be invalid alone may be valid in a combined transaction when another requested property makes the effective final state valid.        |
| `INV-TXN-10` | Shared EEPROM words must be constructed as one merged prospective image. One property must not overwrite another property's staged bits.                    |
| `INV-TXN-11` | Change detection must compare actual current state with effective prospective state. Merely requesting a verb does not prove that a hardware change exists. |
| `INV-TXN-12` | No persistent or live hardware write may occur until validation and required preflight work have succeeded.                                                 |
| `INV-TXN-13` | A transaction must update every checksum domain affected by the persistent words it changes.                                                                |
| `INV-TXN-14` | Relevant persistent state and live state must be verified after commit.                                                                                     |
| `INV-TXN-15` | In memory adapter state must not be updated to the new configuration until required hardware verification has succeeded.                                    |
| `INV-TXN-16` | A persistent property that is already correct may still require live synchronization when persistent and live state disagree.                               |
| `INV-TXN-17` | A failed transaction stage must not fall through into success reporting.                                                                                    |
| `INV-TXN-18` | One CONFIGURE property must not own or silently perform another property's independent transaction semantics.                                               |

See [TRANSACTIONS.md](TRANSACTIONS.md).

## 7. EEPROM Integrity

| ID              | Invariant                                                                                                 |
| --------------- | --------------------------------------------------------------------------------------------------------- |
| `INV-EEPROM-01` | EEPROM words containing several logical fields must be modified using read modify write semantics.        |
| `INV-EEPROM-02` | Bits unrelated to the requested property must be preserved.                                               |
| `INV-EEPROM-03` | EEPROM read success must be determined from the documented CF contract, not from the returned data value. |
| `INV-EEPROM-04` | `FFFFh` is valid EEPROM data when the read succeeds.                                                      |
| `INV-EEPROM-05` | Data returned from a failed EEPROM read must not be consumed.                                             |
| `INV-EEPROM-06` | A timeout or read failure must not be converted into configuration data.                                  |
| `INV-EEPROM-07` | The primary checksum low byte in EEPROM word `0Fh` covers configuration words `08h`, `09h`, and `0Dh`.    |
| `INV-EEPROM-08` | The secondary checksum low byte in EEPROM word `17h` covers words `13h` through `16h`.                    |
| `INV-EEPROM-09` | Updating a checksum low byte must preserve the unrelated high byte of its EEPROM word.                    |
| `INV-EEPROM-10` | A checksum domain must be updated when, and only when, a changed persistent field belongs to that domain. |
| `INV-EEPROM-11` | Persistent writes must be read back and verified when the transaction architecture requires verification. |

See [EEPROM.md](EEPROM.md).

## 8. Capability Model

| ID           | Invariant                                                                                                                                          |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INV-CAP-01` | Product identity must not be used as a general substitute for hardware capability information.                                                     |
| `INV-CAP-02` | EEPROM word `10h` bit 0 is the authoritative Plug and Play capability source.                                                                      |
| `INV-CAP-03` | EEPROM word `14h` represents revision related information and must not replace the Plug and Play capability source.                                |
| `INV-CAP-04` | Physical TP, AUI, and BNC connector capability must come from live Configuration Control information rather than Product ID assumptions.           |
| `INV-CAP-05` | Full Duplex capability must be derived from the required valid connector and revision information.                                                 |
| `INV-CAP-06` | Capability value and capability source validity must remain separate concepts.                                                                     |
| `INV-CAP-07` | A valid capability result of false is different from an unavailable capability result.                                                             |
| `INV-CAP-08` | Consumers must check the corresponding `NIC_CAP_VALID_*` state before relying on a normalized capability group.                                    |
| `INV-CAP-09` | Configured state must not be confused with capability.                                                                                             |
| `INV-CAP-10` | Live operating state must not be confused with capability.                                                                                         |
| `INV-CAP-11` | `LIST` and `CONFIGURE` must use the same normalized capability interpretation.                                                                     |
| `INV-CAP-12` | Product specific capability exceptions must remain consistent between display and configuration paths.                                             |
| `INV-CAP-13` | Physical Option ROM presence must remain distinct from configured Boot ROM mapping.                                                                |
| `INV-CAP-14` | New hardware capability sources used by more than one consumer should be normalized once rather than independently reinterpreted by each consumer. |

See [CAPABILITIES.md](CAPABILITIES.md).

## 9. Low Level Procedure Contracts

| ID           | Invariant                                                                                                                                               |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INV-LOW-01` | CF is meaningful only when the called procedure defines a CF contract.                                                                                  |
| `INV-LOW-02` | A caller must test CF before consuming outputs documented as invalid on failure.                                                                        |
| `INV-LOW-03` | Failure outputs documented as unspecified must remain unusable even if the current implementation happens to return a recognizable value.               |
| `INV-LOW-04` | FLAGS must be considered clobbered unless a procedure explicitly defines or preserves them.                                                             |
| `INV-LOW-05` | A CF result that must survive cleanup through a routine with undefined FLAGS must be preserved explicitly.                                              |
| `INV-LOW-06` | Hardware critical sections that disable interrupts must restore the caller's original FLAGS with `PUSHF` and `POPF`.                                    |
| `INV-LOW-07` | An unconditional interrupt enable must not replace restoration of the caller's previous interrupt state.                                                |
| `INV-LOW-08` | Interrupt exclusion must remain limited to hardware sequences that actually require it.                                                                 |
| `INV-LOW-09` | Register preservation is procedure specific and must follow the documented input and output contract.                                                   |
| `INV-LOW-10` | Register window preservation is procedure specific. A routine that changes the window must either restore it or document that it deliberately does not. |
| `INV-LOW-11` | A procedure that promises hardware state restoration must restore that state on success and applicable failure paths.                                   |
| `INV-LOW-12` | Every procedure exit path must leave the stack balanced.                                                                                                |
| `INV-LOW-13` | Cleanup must not destroy or hide an already established failure result.                                                                                 |

See [LOW_LEVEL_CONVENTIONS.md](LOW_LEVEL_CONVENTIONS.md).

## 10. Mock Hardware

| ID            | Invariant                                                                                                                                             |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INV-MOCK-01` | `3CMOCKIF` must model hardware behavior rather than return expected answers for individual tests.                                                     |
| `INV-MOCK-02` | The mock device image must preserve the distinction between persistent EEPROM and live hardware state.                                                |
| `INV-MOCK-03` | Adapter owned hardware state must remain associated with the corresponding mock adapter record.                                                       |
| `INV-MOCK-04` | State belonging to the single shared ID bus must remain shared rather than being duplicated as independent per adapter hardware state.                |
| `INV-MOCK-05` | ID port contention must operate across eligible contenders using modeled hardware semantics.                                                          |
| `INV-MOCK-06` | Tags and activation state must change because of modeled ID port operations, not application intent.                                                  |
| `INV-MOCK-07` | EEPROM writes must not continuously mirror into live registers.                                                                                       |
| `INV-MOCK-08` | Reset and automatic configuration must remain explicit EEPROM to live synchronization points.                                                         |
| `INV-MOCK-09` | `3CSEED` must create initial fixtures. It must not replace runtime hardware behavior that belongs in `3CMOCKIF`.                                      |
| `INV-MOCK-10` | `3CSEED` fixtures must remain deterministic.                                                                                                          |
| `INV-MOCK-11` | Randomized fixtures must not be introduced into regression behavior unless a separate explicitly nondeterministic test mode is deliberately designed. |
| `INV-MOCK-12` | Fixtures may deliberately create disagreement between hardware information sources when that disagreement is the condition being tested.              |
| `INV-MOCK-13` | Physical mock Option ROM presence and size must remain independent from configured Boot ROM state.                                                    |
| `INV-MOCK-14` | Same I/O base multi adapter conflicts must remain classified as conflict simulations rather than strong claims of physical hardware equivalence.      |
| `INV-MOCK-15` | Unsupported hardware behavior should be modeled conservatively rather than invented merely to satisfy an application path.                            |

See [MOCK.md](MOCK.md).

## 11. Testing

| ID            | Invariant                                                                                                                                                                       |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INV-TEST-01` | The normal automated regression suite must default to MOCKHW.                                                                                                                   |
| `INV-TEST-02` | Numbered regression tests must retain stable `tNNNN` identities.                                                                                                                |
| `INV-TEST-03` | Every numbered regression intended for the smoke suite must remain reachable through its symbolic group from `smoke-core`.                                                      |
| `INV-TEST-04` | Every executed numbered regression must emit its corresponding `[tNNNN]` marker.                                                                                                |
| `INV-TEST-05` | The smoke completion marker must only be emitted after the complete smoke dependency chain succeeds.                                                                            |
| `INV-TEST-06` | Host orchestration must not treat DOSBox termination alone as proof of successful regression completion.                                                                        |
| `INV-TEST-07` | The defined versus executed numbered test guard must remain intact.                                                                                                             |
| `INV-TEST-08` | Configuration tests should verify resulting hardware state where practical rather than relying only on a success message.                                                       |
| `INV-TEST-09` | Combined transaction behavior must retain explicit combined transaction coverage.                                                                                               |
| `INV-TEST-10` | Capability tests must retain deterministic fixtures whose identity and capability sources deliberately disagree.                                                                |
| `INV-TEST-11` | Synchronization tests must retain fixtures in which persistent and live state deliberately disagree.                                                                            |
| `INV-TEST-12` | Multi adapter behavior must remain covered through deterministic mock records.                                                                                                  |
| `INV-TEST-13` | Real hardware conformance must remain separate from normal unattended mock regression execution.                                                                                |
| `INV-TEST-14` | Default `TESTHWC.MK` conformance uses the original utility as writer and `3CCFGCLI` as observer. That evidence must not be represented as proof of every `3CCFGCLI` write path. |
| `INV-TEST-15` | The hardware limit test must remain described according to what it actually proves: executable startup and HELP execution under the tested constrained 8086 environments.       |
| `INV-TEST-16` | The normal functional smoke suite must not be described as running fully under explicit 8086 emulation unless its DOSBox configuration is changed accordingly.                  |
| `INV-TEST-17` | Regression behavior must reflect the intended scope and architecture of this project rather than blindly reproducing every behavior of the original utility.                    |

See [TESTING.md](TESTING.md).

## 12. Change Discipline

The invariants above describe boundaries that should survive ordinary feature work, bug fixing, cleanup, and optimization.

A normal implementation change should therefore satisfy all of the following:

1. It remains within project scope.

2. It preserves the common backend boundary.

3. It does not collapse persistent and live state.

4. It respects the centralized transaction model.

5. It preserves unrelated EEPROM fields and checksum domains.

6. It uses authoritative capability sources and validity information.

7. It follows the low level procedure contracts.

8. It does not add mock shortcuts that physical hardware does not provide.

9. It adds or updates deterministic regression coverage where behavior changes.

10. It does not weaken an existing invariant merely because the current change would otherwise require more work.

If a requested change genuinely conflicts with an invariant, the conflict should be identified explicitly before the architecture is changed.

## 13. Review Checklist

Before accepting a significant hardware facing change, check:

```text id="rygmxg"
Scope
    Is this functionality actually part of the reduced project?

Backend
    Does application code still use the shared Nic_* interface?

Discovery
    Are adapter identity, tag state, and active state still distinct?

State
    Are EEPROM and live state still treated separately?

Transaction
    Was the complete prospective state validated before mutation?

EEPROM
    Were unrelated bits and the correct checksum domains preserved?

Capabilities
    Was the authoritative capability source used, including validity?

Low level
    Were CF, FLAGS, registers, windows, interrupts, and the stack handled according to contract?

Mock
    Does MOCKHW model a hardware transition rather than an application shortcut?

Testing
    Does deterministic coverage exercise both the requested behavior and relevant failure paths?
```

A change that cannot answer these questions cleanly should be reviewed against the detailed architecture documents before it is merged.

## 14. Summary

The central architecture can be reduced to the following rules:

```text id="xmmhhm"
Keep hardware behind Nic_*.

Keep REALHW and MOCKHW externally equivalent.

Keep identity, capability, configured state, live state, and validity distinct.

Keep EEPROM separate from live ASIC state.

Keep discovery, tagging, selection, and activation distinct.

Build one prospective CONFIGURE transaction before writing anything.

Validate the effective final state of combined requests.

Preserve unrelated EEPROM bits.

Update the correct checksum domains.

Use CF according to the actual procedure contract.

Treat FFFFh as valid EEPROM data after a successful read.

Restore FLAGS and interrupt state correctly.

Make MOCKHW behave like hardware, not like the test expectation.

Keep fixtures deterministic.

Verify committed hardware state.

Do not claim that a test proves more than it actually exercises.
```

These invariants are the architectural guard rails for future development.

