# Architecture

This document is the entry point for the internal architecture of 3CCFGCLI.

For implementation details, backend contracts, state handling, transaction
semantics, and testing architecture, see the documents below.

| Document | Description |
|---|---|
| [Backend](BACKEND.md) | REALHW and MOCKHW backend contract and `Nic_*` interface |
| [Discovery](DISCOVERY.md) | ID port discovery, tagging, activation, active base scanning and adapter records |
| [State Model](STATE_MODEL.md) | Persistent EEPROM state versus live ASIC/register state |
| [Transactions](TRANSACTIONS.md) | CONFIGURE parsing, staging, prospective state, commit and verification |
| [EEPROM](EEPROM.md) | Shared EEPROM words, bit ownership, preservation rules and checksums |
| [Capabilities](CAPABILITIES.md) | Product, EEPROM, connector, revision and derived capability handling |
| [Mock](MOCK.md) | 3CMOCKIF hardware model and 3CSEED fixtures |
| [Low Level Conventions](LOW_LEVEL_CONVENTIONS.md) | CF, FLAGS, interrupt state and low level procedure contracts |
| [Testing](TESTING.md) | TEST.MK, TESTHWC.MK and TESTHWL.MK |
| [Architectural Invariants](INVARIANTS.md) | Rules that must remain true when modifying the implementation |
| [Design Decisions](DESIGN_DECISIONS.md) | Design Decisions that influence the implementation scope |
