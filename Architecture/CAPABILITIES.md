# Capability Model

## 1. Purpose

3CCFGCLI distinguishes between adapter identity, hardware capability, configured state, live state, and the validity of the information used to describe those properties.

These concepts must not be collapsed into a single model.

A product identifier can identify an adapter family or model without proving that a particular connector is present. A configuration bit can describe what the adapter is configured to do without proving that the hardware supports that configuration. A live register can describe the current ASIC state without being the persistent source of configuration.

The capability model exists to keep these distinctions explicit and to provide common capability decisions for both `LIST` and `CONFIGURE`.

Related architecture documents are:

* [BACKEND.md](BACKEND.md), common hardware backend interface
* [DISCOVERY.md](DISCOVERY.md), adapter discovery and record construction
* [STATE_MODEL.md](STATE_MODEL.md), persistent and live state
* [TRANSACTIONS.md](TRANSACTIONS.md), capability gates during `CONFIGURE`
* [EEPROM.md](EEPROM.md), EEPROM field ownership and update rules

## 2. Capability Classes

The program currently deals with several different kinds of hardware information.

### 2.1 Product identity

Product identity describes which member of the supported 3C509 family has been discovered.

The product identifier is stored in `NIC_PRODUCT_ID` inside the enumeration record.

Product identity is used for purposes such as:

* determining whether a discovered adapter belongs to the supported 3C509 family
* selecting the user visible model description
* preserving adapter identity during revalidation
* applying model specific restrictions where required

Product identity is not a general substitute for hardware capability discovery.

In particular, the presence of TP, AUI, or BNC connectors is not inferred solely from `NIC_PRODUCT_ID`.

The mock fixtures deliberately allow product identity and connector presence to differ so that this rule remains testable.

### 2.2 ASIC revision

The active adapter record also contains `NIC_ASIC_REV`.

This value comes from active adapter identification and represents the ASIC revision returned by the hardware signature path.

The ASIC revision is the sole adapter generation classifier:

```text
ASIC rev 1   = original 3C509 generation
ASIC rev 2+  = 3C509B generation
ASIC rev FFh = unknown/unavailable
```

`FFh` means that the ASIC revision was not available.

ASIC revision is part of adapter identity, generation classification, and revalidation. It is separate from EEPROM word `14h`, which contains Adapter Revision Level and other secondary information.

These two revision concepts must not be treated as interchangeable.

### 2.3 EEPROM capability information

EEPROM word `10h`, `EEPROM_CAPABILITY`, contains documented capability information.

For the capability model, the relevant field is:

```text
EEPROM_CAPABILITY_PNP = 0001h
```

Bit 0 is the authoritative source for Plug and Play capability.

It is interpreted only on an adapter already classified as a known 3C509B-generation device by its ASIC revision; other EEPROM words carry different, non-capability meanings on the original generation.

EEPROM word `14h` must not be used as a replacement for this capability bit.

Adapter Revision Level and Plug and Play capability are deliberately independent properties.

### 2.4 Connector capabilities

Physical connector capability is obtained from the live Window 0 Configuration Control register.

The relevant source bits are:

```text
W0_CONFIG_CONTROL_TP_PRESENT  = 0200h
W0_CONFIG_CONTROL_BNC_PRESENT = 1000h
W0_CONFIG_CONTROL_AUI_PRESENT = 2000h
```

These bits describe the connectors exposed by the active hardware model.

They are normalized into the shared software capability bits:

```text
NIC_CAP_TP  = 02h
NIC_CAP_AUI = 04h
NIC_CAP_BNC = 08h
```

Connector capability must therefore come from the active hardware state rather than from assumptions based on the product identifier.

This distinction is important for combo adapters and is also intentionally exercised by the mock fixtures.

### 2.5 Adapter Revision Level

EEPROM word `14h`, `EEPROM_REVISION_INFO`, contains secondary adapter information.

The documented Adapter Revision Level identifies the hardware revision class.

The defined baseline values are:

```text
0 = original 3C509 class hardware
1 = 3C509B class hardware
```

The same EEPROM word also contains other information, including the Boot ROM Size Valid flag.

The revision information must therefore not be treated as though the complete EEPROM word were a single capability value.

Adapter generation is classified exclusively from the ASIC revision (`NIC_ASIC_REV`); EEPROM word `14h` is not used as the generation source. Within a known 3C509B generation, `Nic_Read_Capabilities` uses the low byte of word `14h` only as full duplex revision evidence.

Whatever representation is used internally, the architectural meaning remains revision classification. It must not be substituted for the independent Plug and Play capability bit from EEPROM word `10h`.

## 3. Normalized Capability Contract

Application logic does not directly pass EEPROM and register bit positions between capability consumers.

Instead, `3CCFGCLI` defines a normalized capability contract:

```text
NIC_CAP_PNP        = 01h
NIC_CAP_TP         = 02h
NIC_CAP_AUI        = 04h
NIC_CAP_BNC        = 08h
NIC_CAP_FULLDUPLEX = 10h
```

These values are software level capability bits.

They are not aliases for the physical bit positions used by EEPROM or ASIC registers.

This allows application logic to ask whether an adapter supports a feature without knowing where the underlying evidence came from.

The translation from hardware representation into the normalized representation belongs in shared capability discovery.

## 4. `Nic_Read_Capabilities`

`Nic_Read_Capabilities` is the common capability reader used by both display and configuration logic.

Its input is:

```text
DX = active adapter I/O base
```

Its output is:

```text
AX = normalized NIC_CAP_* values
BX = NIC_CAP_VALID_* validity flags
CF = clear
```

The routine preserves the currently selected register window.

Capability source failures are not returned through CF.

Instead, each capability group has its own validity flag.

This is intentional because the hardware sources are independent. Failure to obtain one capability group must not automatically erase information successfully obtained from another group.

## 5. Capability Validity

The normalized capability bits are accompanied by independent validity bits:

```text
NIC_CAP_VALID_PNP        = 01h
NIC_CAP_VALID_CONNECTORS = 02h
NIC_CAP_VALID_FULLDUPLEX = 04h
```

A capability bit and its validity bit answer different questions.

For example:

```text
NIC_CAP_VALID_PNP set
NIC_CAP_PNP clear
```

means that Plug and Play capability was successfully determined and the adapter does not support it.

By contrast:

```text
NIC_CAP_VALID_PNP clear
```

means that Plug and Play capability could not be determined.

The absence of a capability and the inability to determine that capability are not equivalent states.

Consumers must therefore test the relevant validity bit before interpreting the corresponding capability bit.

### 5.1 Plug and Play validity

`Nic_Read_Capabilities` reads EEPROM word `10h` using `Nic_EEPROM_Read`.

If the EEPROM read succeeds, `NIC_CAP_VALID_PNP` is set.

The value of `EEPROM_CAPABILITY_PNP` then determines whether `NIC_CAP_PNP` is set.

EEPROM errors are determined by the EEPROM read status contract, not by treating the EEPROM data value itself as an error sentinel.

### 5.2 Connector validity

Connector capability is read from the Window 0 Configuration Control register.

If that register is available, `NIC_CAP_VALID_CONNECTORS` is set and the TP, AUI, and BNC presence bits are normalized.

If the register value is unavailable according to the current register access contract, connector validity remains clear.

This register handling must not be confused with EEPROM read semantics, where `FFFFh` may be valid EEPROM data and CF reports read success or failure.

### 5.3 Full duplex validity

Full duplex capability is derived rather than read from one dedicated hardware bit.

To determine it, the capability reader requires:

* valid connector information
* a successful EEPROM word `14h` read

Once both sources are available, `NIC_CAP_VALID_FULLDUPLEX` is set.

The actual `NIC_CAP_FULLDUPLEX` bit is then set only if:

* TP capability is present
* the word `14h` revision classification meets or exceeds `EEPROM_REVISION_3C509B`

This means a valid full duplex capability result can legitimately be false.

For example, a 3C509B-generation adapter without TP capability has a known full duplex capability result of no. It does not have an unknown capability result.

## 6. Derived Capabilities

Some capabilities are derived from more than one hardware property.

### 6.1 Full duplex

Full duplex is the main normalized derived capability.

It is not inferred from product identity alone.

It depends on both connector capability and revision information.

Conceptually:

```text
full duplex capability =
    connector information valid
    AND revision information valid
    AND TP present
    AND adapter revision supports full duplex
```

Plug and Play capability does not participate in this decision.

This independence is intentional.

A card without Plug and Play capability can still support full duplex.

Likewise, a card with Plug and Play capability can fail the full duplex capability test because its revision or connector information does not satisfy the full duplex requirements.

### 6.2 Automatic transceiver selection

Automatic transceiver selection is not represented by a separate `NIC_CAP_*` bit.

When determining whether AUTO is meaningful, the program examines the normalized TP, AUI, and BNC capability bits.

AUTO requires more than one available connector.

A card with only one connector therefore has a valid connector capability set but does not have a meaningful automatic selection choice.

### 6.3 Boot ROM configuration support

Boot ROM configuration is not currently represented by a normalized `NIC_CAP_*` bit.

The current implementation has a separate generation and product gate: the adapter must be classified as a known 3C509B-generation device by its ASIC revision (`NIC_ASIC_REV` 2 or later, excluding `FFh`), and `PRODUCT_3C509_TPO` is additionally excluded.

The same model specific rule is used by both `LIST` and `CONFIGURE`.

This is an explicit special case and must not be generalized into assumptions about other products.

If Boot ROM capability handling is normalized in the future, both consumers must be moved to the same shared result rather than creating independent interpretations.

## 7. Capability Versus Configured State

Capability describes what the hardware can support.

Configured state describes what the adapter is currently configured to use.

These values must remain separate.

### 7.1 Plug and Play

Plug and Play capability comes from:

```text
EEPROM word 10h
EEPROM_CAPABILITY_PNP
```

Plug and Play configured state comes from the ISA activation selection field stored in EEPROM word `13h`.

Therefore:

```text
Plug and Play capable = yes
Plug and Play configured = disabled
```

is a valid state.

Disabling Plug and Play configuration must not cause `LIST` to report that the adapter has lost Plug and Play capability.

### 7.2 Full duplex

Full duplex capability is derived from connector and revision information.

The persistent full duplex setting comes from:

```text
EEPROM_SOFTWARE_INFO
EEPROM_SOFTWARE_INFO_FULLDUPLEX
```

The live full duplex ASIC state is a separate runtime property discussed in [STATE_MODEL.md](STATE_MODEL.md).

Therefore these concepts are distinct:

```text
Full Duplex Capability
Full Duplex persistent setting
Full Duplex live ASIC state
```

A persistent enabled setting does not itself prove capability.

A capability result does not itself prove that full duplex is currently enabled.

### 7.3 Transceiver

Connector capabilities describe which connectors physically exist.

The configured transceiver describes which one is selected.

The configured transceiver is obtained from Address Configuration state.

When automatic transceiver selection is configured, the connector capability set is additionally required to determine whether AUTO represents an actual choice between multiple connectors.

## 8. Capability Versus Live State

Live hardware state is not automatically a capability.

For example, link status is read from the Window 4 Media Type and Status register.

The link status reports whether valid link beat is currently detected.

It does not indicate whether the adapter supports TP in the architectural capability sense.

Likewise, the current live full duplex state is not the source of full duplex capability.

Capabilities describe available hardware functionality.

Live state describes what the hardware is doing now.

The distinction defined in [STATE_MODEL.md](STATE_MODEL.md) applies here as well.

## 9. `LIST` Consumption

The enumeration record deliberately remains compact.

Additional information required by `LIST` is collected only after enumeration through `Read_Extended_Nic_Info`.

This avoids changing discovery behavior or the fixed NIC record layout merely to support additional display fields.

For each active adapter, `Read_Extended_Nic_Info` initializes its extended state to unavailable values and then calls `Nic_Read_Capabilities`.

The returned values are stored in:

```text
ext_nic_capabilities
ext_nic_capability_valid
```

Additional persistent and live properties are then read separately.

The capability display routines always consult the corresponding validity bit before interpreting the capability value.

This applies to:

* Plug and Play capability
* connector capability
* full duplex capability

The full duplex configured value first checks whether full duplex capability is known and supported. Only then is the persistent setting interpreted.

This allows `LIST` to distinguish between:

```text
yes
no
not supported
unavailable
```

where appropriate.

These meanings must not be collapsed.

## 10. `CONFIGURE` Consumption

Capability checks occur during the capability gate phase of the `CONFIGURE` transaction.

This phase runs before accepted parameter reporting and before any hardware modification.

A requested property that the selected adapter cannot support is therefore rejected before staging or commit.

### 10.1 `/PNP`

The PNP gate calls `Nic_Read_Capabilities`.

It first requires `NIC_CAP_VALID_PNP`.

If validity is absent, configuration fails as a capability read error.

If validity is present but `NIC_CAP_PNP` is clear, configuration fails because the adapter does not support Plug and Play configuration.

Revision information is not used as a substitute.

### 10.2 `/FULLDUPLEX`

The full duplex gate requires `NIC_CAP_VALID_FULLDUPLEX`.

If validity is absent, configuration fails as a capability read error.

If validity is present but `NIC_CAP_FULLDUPLEX` is clear, the adapter is rejected as not supporting full duplex configuration.

This gate is separate from the later prospective state validation that ensures full duplex is only enabled with an effective TP transceiver selection.

Capability answers whether the hardware can support full duplex.

Prospective validation answers whether the requested configuration is internally valid.

Both checks are required.

### 10.3 `/TR`

The transceiver gate requires `NIC_CAP_VALID_CONNECTORS`.

Each explicit transceiver request is checked against the corresponding normalized connector capability:

```text
TP   requires NIC_CAP_TP
AUI  requires NIC_CAP_AUI
COAX requires NIC_CAP_BNC
```

AUTO requires multiple available connector capabilities.

Product identity alone must not be used to approve these selections.

### 10.4 Boot ROM verbs

The Boot ROM verbs currently use their separate product and revision gate rather than `Nic_Read_Capabilities`.

This exception must remain consistent between `LIST` and `CONFIGURE`.

## 11. Shared Use by `LIST` and `CONFIGURE`

The architecture requires capability interpretation to be shared.

`LIST` and `CONFIGURE` may consume capability information differently, but they must not independently invent different definitions of the same capability.

The intended flow is:

```text
hardware sources
        |
        v
Nic_Read_Capabilities
        |
        v
normalized capability values
plus validity flags
        |
        +====> LIST display
        |
        +====> CONFIGURE gates
```

This provides one interpretation of:

* Plug and Play capability
* physical connector presence
* full duplex capability

A change to any of these definitions must therefore be made in the shared capability discovery path and validated against both consumers.

Product specific capability exceptions that remain outside this normalized path must likewise be implemented consistently in both consumers.

## 12. Backend Requirements

Capability policy belongs to application logic, not to `REALHW` or `MOCKHW`.

`Nic_Read_Capabilities` obtains its evidence through the common `Nic_*` hardware interface.

The hardware backends are responsible for providing equivalent observable hardware behavior for:

* register window selection
* Configuration Control reads
* EEPROM reads
* active adapter access

The backends must not independently decide whether a card is Plug and Play capable, full duplex capable, or connector capable.

Those decisions belong to the shared normalized capability logic.

This is part of the backend equivalence rule defined in [BACKEND.md](BACKEND.md).

## 13. Mock Capability Fixtures

`3CSEED` contains deterministic profiles that deliberately separate capability sources.

These are architectural tests, not merely convenient sample cards.

Important examples include:

* `NOPNP`, clears the authoritative Plug and Play capability bit on a known 3C509B-generation adapter while retaining the other normal adapter properties, proving that the generation alone does not imply Plug and Play capability
* `NOFD`, retains the normal product identity and revision information while removing live TP capability
* `TPAUI`, retains the TP product identity while reporting TP and AUI connector capabilities
* `TRI`, retains the TP product identity while reporting TP, AUI, and BNC connector capabilities

These profiles prevent capability logic from degenerating into product identifier assumptions.

They also verify that the individual capability sources remain independent.

## 14. Required Architectural Invariants

The following rules are mandatory for future changes.

1. Product identity must not replace hardware capability discovery.

2. EEPROM word `10h` bit 0 is the authoritative Plug and Play capability source.

3. EEPROM word `14h` revision information must not be used as a substitute for Plug and Play capability.

4. Connector capability must come from the hardware connector presence information exposed through Configuration Control.

5. Full duplex capability must remain derived from the required connector and revision information, not from Plug and Play capability or product identity alone.

6. Capability values and capability validity must remain separate.

7. A valid capability result of no must not be treated as an unavailable capability result.

8. Consumers must check the relevant `NIC_CAP_VALID_*` flag before using a normalized capability group.

9. Configured state must not be interpreted as proof of capability.

10. Live ASIC state must not be interpreted as proof of capability.

11. `LIST` and `CONFIGURE` must share the same capability interpretation.

12. Backend implementations must expose hardware state through the common `Nic_*` interface and must not contain independent application capability policy.

13. Product specific capability exceptions outside `Nic_Read_Capabilities` must remain consistent between all consumers.

14. New capability sources should be normalized before being consumed by multiple application paths.

15. Tests must preserve fixtures in which product identity, revision information, Plug and Play capability, and connector capability remain independent evidence rather than interchangeable substitutes.

## 15. Summary

The capability model is a normalization layer between raw hardware information and application behavior.

It combines several independent sources:

```text
Product ID
ASIC revision
EEPROM capability information
EEPROM revision information
live connector presence
other live ASIC state
```

but does not treat them as interchangeable.

The normalized `NIC_CAP_*` values describe supported functionality.

The `NIC_CAP_VALID_*` values describe whether that functionality could be determined.

Configured state and live state remain separate from both.

This separation allows `LIST` to report hardware accurately and allows `CONFIGURE` to reject unsupported requests before any transaction is committed.

