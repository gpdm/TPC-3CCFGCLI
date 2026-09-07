# EEPROM Architecture

## Purpose

The 3C509/3C509B EEPROM contains persistent adapter configuration, identity,
capability information, revision information, checksums, and ISA Plug and Play
resource data.

`3CCFGCLI` deliberately modifies only a small subset of that EEPROM.

Several supported `CONFIGURE` properties share the same EEPROM word.

Because of that, the EEPROM write model is based on:

```text
read current word
        |
        v
copy complete word into prospective state
        |
        v
modify only bits owned by requested properties
        |
        v
write complete merged word
        |
        v
update affected checksum domain
        |
        v
read back and verify
```

The central rule is:

**A configuration property owns fields, not complete EEPROM words.**

Unrelated fields, including reserved or currently unsupported fields, must
survive a configuration transaction unchanged.

# EEPROM map relevant to 3CCFGCLI

The complete EEPROM contains more data than the current utility modifies.

The locations most relevant to the architecture are:

| Word       | Name                                                  | Current use                            |
| ---------- | ----------------------------------------------------- | -------------------------------------- |
| `00h`      | Node Address 0                                        | Identity / contention data             |
| `01h`      | Node Address 1                                        | Identity / contention data             |
| `02h`      | Node Address 2                                        | Identity / contention data             |
| `03h`      | Product ID                                            | Adapter identity                       |
| `07h`      | Manufacturer ID                                       | 3Com identification                    |
| `08h`      | Address Configuration                                 | IOBASE, transceiver, Boot ROM          |
| `09h`      | Resource Configuration                                | IRQ                                    |
| `0Ah..0Ch` | OEM Node Address                                      | MAC identity used by this project      |
| `0Dh`      | Software Information                                  | MODEM, FULLDUPLEX policy, OPTIMIZE     |
| `0Eh`      | Compatibility                                         | Read-only compatibility levels         |
| `0Fh`      | Primary Checksums                                     | Two independent checksum bytes         |
| `10h`      | Capabilities                                          | Hardware capability information        |
| `12h`      | Internal Configuration low                            | Persistent source for Window 3         |
| `13h`      | Configuration Control / Internal Configuration high   | PNP activation policy                  |
| `14h`      | Secondary Software Information / Revision Information | Boot ROM Size Valid and adapter revision |
| `17h`      | Secondary Checksums                                   | Vital and configurable data checksums  |
| `18h..3Fh` | ISA Plug and Play Resource Data                       | Persistent PnP resource data           |

Only the fields explicitly implemented by the current CONFIGURE architecture
are writable through the utility.

Do not interpret the presence of an EEPROM definition as permission to modify
it.

# Writable EEPROM surface

At present, `CONFIGURE` can modify persistent fields in:

```text
08h
09h
0Dh
13h
14h
```

Checksum maintenance may additionally write:

```text
0Fh
17h
```

Everything else is outside the normal CONFIGURE write surface.

## Overview

```text
EEPROM
  |
  +-- 08h Address Configuration
  |      |
  |      +-- bits 15:14  TR / XCVR
  |      +-- bits 13:12  Boot ROM size
  |      +-- bits 11:8   Boot ROM base
  |      +-- bit  7      TR AUTO select
  |      +-- bits 4:0    IOBASE
  |
  +-- 09h Resource Configuration
  |      |
  |      +-- bits 15:12  INT / IRQ
  |
  +-- 0Dh Software Information
  |      |
  |      +-- bit  15     FULLDUPLEX policy
  |      +-- bit  14     Link Beat policy, preserved
  |      +-- bits 13:8   MODEM
  |      +-- bits 7:6    reserved, preserved
  |      +-- bits 5:4    OPTIMIZE
  |      +-- bits 3:0    Boot Protocol, preserved
  |
  +-- 13h Configuration Control
  |      |
  |      +-- bits 3:2    PNP activation policy
  |
  +-- 14h Revision Information
         |
         +-- bit 4       Boot ROM Size Valid
         +-- other bits  preserved
```

# EEPROM word `08h`: Address Configuration

Word `08h` is the most heavily shared configuration word in the current
implementation.

Its relevant layout is:

```text
15          14 13          12 11               8 7 6 5 4             0
+--------------+--------------+------------------+-+-+-+---------------+
|     XCVR     | Boot ROM Size|  Boot ROM Base   |A|0|R|  I/O selector |
+--------------+--------------+------------------+-+-+-+---------------+
                                                   ^
                                                   AUTO SELECT
```

Where:

| Bits    | Meaning                         | Current owner  |
| ------- | ------------------------------- | -------------- |
| `15:14` | Transceiver selection           | `/TR`, `/XCVR` |
| `13:12` | Boot ROM Size                   | `/BSIZE`       |
| `11:8`  | Boot ROM Base selector          | `/BADDRESS`    |
| `7`     | Automatic transceiver selection | `/TR`, `/XCVR` |
| `6`     | documented zero                 | preserved      |
| `5`     | reserved                        | preserved      |
| `4:0`   | ISA I/O base selector           | `/IOBASE`      |

## IOBASE

The ISA base is encoded as:

```text
base = 0200h + selector * 10h
```

with selector values:

```text
00h through 1Eh
```

representing:

```text
0200h through 03E0h
```

Selector `1Fh` represents EISA slot-specific addressing and is outside the
scope of this ISA-only project.

`Cfg_Prepare_IOBASE` therefore modifies only bits `4:0`.

The rest of word `08h` is preserved.

## Transceiver selection

The explicit transceiver field uses bits `15:14`.

The current values are:

```text
00b = TP
01b = AUI
11b = BNC / COAX
```

The value:

```text
10b
```

is reserved or undefined and is not introduced by the CONFIGURE parser.

AUTO selection is represented separately by bit `7`.

For an explicit transceiver request:

```text
bit 7     = 0
bits15:14 = requested transceiver
```

For AUTO:

```text
bit 7     = 1
bits15:14 = 00b
```

`Cfg_Prepare_TR` therefore clears only bits `15:14` and bit `7`, then inserts
the requested transceiver representation.

Boot ROM and IOBASE fields remain untouched.

## Boot ROM fields

Boot ROM configuration occupies bits `13:8`.

The persistent fields consist of:

```text
bits 13:12  Boot ROM size
bits 11:8   Boot ROM base selector
```

The current utility supports:

```text
8 KB
16 KB
32 KB
```

even though the underlying two-bit field can also encode 64 KB.

`Cfg_Prepare_Boot_ROM` merges only bits `13:8`.

It preserves:

* transceiver bits `15:14`
* AUTO bit `7`
* bits `6:5`
* IOBASE bits `4:0`

The same Boot ROM field layout also exists in live Window 0 Address
Configuration, but persistent EEPROM and live state remain separate.

See [`STATE_MODEL.md`](STATE_MODEL.md).

## One word, multiple simultaneous changes

A combined transaction such as:

```text
/IOBASE:300 /TR:TP /BADDRESS:C8000 /BSIZE:16
```

does not perform three independent writes to EEPROM word `08h`.

Instead:

```text
current word08
      |
      v
prospective word08
      |
      +--> merge IOBASE
      |
      +--> merge Boot ROM
      |
      +--> merge TR
      |
      v
one final word08 image
```

If that final image differs from the current word, the complete merged word is
written once.

# EEPROM word `09h`: Resource Configuration

The field modified by the current utility is:

```text
bits 15:12  IRQ
```

Valid enabled IRQ values accepted by the CLI are:

```text
3
5
7
9
10
11
12
15
```

Other values have hardware meanings outside the normal enabled IRQ set.

Word `09h` contains fields other than IRQ.

For example, 3C509B bit `6` is the Synchronous Ready configuration bit.

`/INT` does not own those fields.

`Cfg_Prepare_INT` therefore:

```text
clears bits 15:12
inserts requested IRQ
preserves bits 11:0
```

The complete prospective word is then written if the persistent IRQ actually
changes.

# EEPROM word `0Dh`: Software Information

Word `0Dh` is another shared configuration word.

Its documented layout, plus the compatibility behavior used by this project,
is:

```text
15 14 13                    8 7     6 5     4 3                    0
+--+--+----------------------+-------+-------+----------------------+
|FD|LB| Max Interrupt Disable| resvd | OPT   |    Boot Protocol     |
+--+--+----------------------+-------+-------+----------------------+
```

Current ownership is:

| Bits   | Meaning                        | Current owner                          |
| ------ | ------------------------------ | -------------------------------------- |
| `15`   | Persistent Full Duplex policy  | `/FULLDUPLEX`                          |
| `14`   | Link Beat Disable policy       | preserved, `/LINKBEAT` not implemented |
| `13:8` | Maximum Interrupt Disable Time | `/MODEM`                               |
| `7:6`  | reserved                       | preserved                              |
| `5:4`  | Software Optimization          | `/OPTIMIZE`                            |
| `3:0`  | Boot Protocol                  | preserved                              |

## MODEM

`/MODEM` modifies only:

```text
bits 13:8
```

using:

```text
EEPROM_SOFTWARE_INFO_INT_DISABLE_MASK = 3F00h
```

The field represents Maximum Interrupt Disable Time.

The raw value is not the whole Software Information word.

For example, a value such as:

```text
1320h
```

contains two independent fields:

```text
13h in bits 13:8
    Maximum Interrupt Disable Time

2 in bits 5:4
    Software Optimization
```

A MODEM implementation must therefore never treat `1320h` as one indivisible
modem setting.

## FULLDUPLEX

Bit `15` is documented as zero in the hardware reference.

However, the original 3Com utility and historical driver behavior use it as an
undocumented persistent Full Duplex policy.

`3CCFGCLI` deliberately retains that compatibility behavior.

`/FULLDUPLEX` therefore owns only:

```text
bit 15
```

Its live hardware counterpart is a separate Window 4 Network Diagnostic bit.

Changing the EEPROM bit must not be confused with changing the live hardware
bit.

That relationship is documented in
[`STATE_MODEL.md`](STATE_MODEL.md) and
[`TRANSACTIONS.md`](TRANSACTIONS.md).

## OPTIMIZE

`/OPTIMIZE` owns only:

```text
bits 5:4
```

The current encoded field represents software workload optimization.

The remaining Software Information fields must survive unchanged.

## LINKBEAT

Bit `14` is persistent Link Beat driver policy.

The current utility does not implement `/LINKBEAT`.

Therefore this bit must be preserved during all MODEM, FULLDUPLEX, and
OPTIMIZE writes.

## Reserved and Boot Protocol fields

Bits `7:6` are not owned by any current CONFIGURE property.

Bits `3:0` select Boot Protocol.

Neither field is rewritten or normalized by the current utility.

Even if a value looks unexpected, a property modifying another field in word
`0Dh` must leave it alone.

# EEPROM word `13h`: Configuration Control

EEPROM word `13h` is also the high 16 bits of the 32-bit Internal
Configuration value loaded into Window 3 during automatic configuration.

The relevant current CONFIGURE field is:

```text
bits 3:2  ISA Activation Select
```

Those bits correspond to Internal Configuration bits `19:18`.

## Activation Select encoding

The hardware encoding is:

```text
00b = classic contention and PnP enabled
01b = classic contention enabled, PnP disabled
10b = classic contention disabled, PnP enabled
11b = classic contention and PnP enabled
```

The project uses `/PNP` to enable or disable Plug and Play while retaining
classic ISA contention.

Therefore:

```text
/PNP:ENABLED
    bits 3:2 = 00b

/PNP:DISABLED
    bits 3:2 = 01b
```

`Cfg_Prepare_PNP` clears only bits `3:2` and inserts the required encoding.

Every other bit in word `13h` must survive unchanged.

## Why preserving the rest matters

Word `13h` is not merely a two-bit PNP variable.

It is part of the persistent 32-bit Internal Configuration image.

Other fields in the same word may influence hardware behavior after reset.

A PNP implementation that constructs a fresh word from the desired PNP value
would therefore destroy unrelated persistent Internal Configuration state.

# EEPROM word `14h`: Revision Information

Word `14h` contains Secondary Software Information and Revision Information.

Relevant documented fields include:

```text
bit 14      Auto Power
bit 4       Boot ROM Size Valid
bits 3:0    Adapter Revision Level
```

The current CONFIGURE transaction modifies only:

```text
bit 4
```

and only as part of Boot ROM configuration.

## Boot ROM Size Valid

`Cfg_Prepare_Boot_ROM` clears:

```text
EEPROM_REVISION_INFO_BOOT_ROM_SIZE_VALID = 0010h
```

from the prospective word `14h`.

All other bits are preserved.

For the conventional ISA configuration path supported by `3CCFGCLI`,
`Boot ROM Size Valid` therefore remains clear.

The original 3Com utility also has a PnP BIOS path in which Boot ROM
configuration is represented differently. System PnP BIOS integration is
intentionally outside the scope of `3CCFGCLI`; see
[`DESIGN_DECISIONS.md`](../DESIGN_DECISIONS.md).

This is important because the same word contains adapter revision
information used elsewhere in the program.

## Adapter Revision Level is not writable policy

Bits `3:0` identify the adapter revision class.

For example, the current project uses revision information to distinguish
original 3C509-class behavior from later 3C509B-class behavior where required.

CONFIGURE must not overwrite those bits simply because Boot ROM Size Valid
shares the same word.

# Read-modify-write is mandatory

The common rule for all writable property words is:

```text
current complete word
        |
        v
prospective complete word
        |
        v
clear only property-owned mask
        |
        v
insert requested field
        |
        v
preserve everything else
```

Current Prepare routines follow this model.

Examples:

```text
IOBASE
    word08 AND FFE0h
    insert bits 4:0

TR
    word08 AND 3F7Fh
    insert bits 15:14 and/or bit 7

Boot ROM
    word08 AND C0FFh
    insert bits 13:8

INT
    word09 AND 0FFFh
    insert bits 15:12

MODEM
    clear only 3F00h
    insert bits 13:8

FULLDUPLEX
    clear only 8000h
    insert bit 15

OPTIMIZE
    clear only 0030h
    insert bits 5:4

PNP
    clear only 000Ch
    insert bits 3:2

Boot ROM Size Valid
    clear only word14 bit 4
```

A property must not create a complete replacement word from constants.

# Unknown and reserved bits are data too

Reserved does not mean disposable.

If the current adapter contains a bit pattern that the utility does not
understand, modifying an unrelated field is not permission to normalize that
pattern.

The safe rule is:

```text
if this CONFIGURE property does not own the field
    preserve it exactly
```

This applies to:

* documented but unsupported fields
* reserved fields
* undocumented fields
* policy fields belonging to omitted verbs
* adapter-generation-specific fields

This conservative rule is especially important when reproducing the behavior
of old hardware whose EEPROM may have been written by several generations of
3Com software.

# Primary checksum word `0Fh`

EEPROM word `0Fh` contains two independent checksum bytes.

It is not an ordinary configuration word.

```text
15                       8 7                        0
+-------------------------+-------------------------+
|  Primary High Checksum  |   Primary Low Checksum |
+-------------------------+-------------------------+
```

## Primary low checksum

The low byte is the configurable-data checksum.

Its domain is exactly:

```text
word 08h
word 09h
word 0Dh
```

The checksum is calculated by XORing both bytes of each word:

```text
checksum = 0

checksum ^= low_byte(word08)
checksum ^= high_byte(word08)

checksum ^= low_byte(word09)
checksum ^= high_byte(word09)

checksum ^= low_byte(word0D)
checksum ^= high_byte(word0D)
```

Equivalent source iteration is:

```text
08h through 0Dh
excluding 0Ah through 0Ch
```

which produces the same three-word domain.

## Primary high checksum

The high byte covers the complementary primary EEPROM domain:

```text
words 00h through 0Eh
```

excluding:

```text
08h
09h
0Dh
```

In other words, the configurable words covered by the low checksum are
deliberately excluded from the high checksum.

## Why CONFIGURE updates only the low byte

The current CONFIGURE implementation modifies only these words within the
primary area:

```text
08h
09h
0Dh
```

Those are all members of the **low-byte** checksum domain.

It does not modify any word in the primary high-byte domain.

Therefore the high byte of EEPROM word `0Fh` must remain unchanged.

## Updating word `0Fh`

When any of:

```text
word08 changed
word09 changed
word0D changed
```

the transaction:

1. recalculates the low checksum from current EEPROM contents
2. takes the existing prospective word `0Fh`
3. preserves its high byte
4. replaces only the low byte
5. writes the complete word `0Fh`
6. reads it back
7. compares the complete result

Conceptually:

```text
old word0F
     |
     +--> preserve high byte
     |
recalculate low byte from 08h, 09h, 0Dh
     |
     v
new word0F
```

## PNP-only transactions do not depend on word `0Fh`

A transaction changing only PNP does not touch the primary checksum domain.

`Cfg_Txn_Read_Current` therefore does not require word `0Fh` to be readable
for a PNP-only transaction.

This is deliberate.

The secondary checksum domain is sufficient for that operation.

## Software Optimization does not live in `0Fh`

EEPROM word `0Fh` must never be used as storage for `/OPTIMIZE`.

Software Optimization is in:

```text
EEPROM word 0Dh bits 5:4
```

Word `0Fh` is checksum storage.

# Secondary checksum word `17h`

EEPROM word `17h` also contains two independent checksum bytes.

```text
15                         8 7                          0
+---------------------------+---------------------------+
| Vital Data Checksum       | Configurable Data Check.  |
+---------------------------+---------------------------+
| high byte                 | low byte                  |
+---------------------------+---------------------------+
```

# Secondary low checksum

The low byte covers:

```text
words 13h through 16h
```

Both bytes of every word participate in the XOR.

Conceptually:

```text
checksum = 0

for word = 13h through 16h:
    checksum ^= low_byte(word)
    checksum ^= high_byte(word)
```

## Current CONFIGURE users of this domain

The current utility can modify:

```text
word13
    /PNP

word14
    Boot ROM Size Valid
```

Both are inside the secondary low checksum domain.

Therefore either changed word requires recalculation of word `17h` low.

# Secondary high checksum

The high byte is the Vital Data Checksum.

Its domain consists of:

```text
words 10h through 12h

plus

words 20h through 3Fh
```

Both bytes of each word participate.

## Why CONFIGURE preserves the high byte

Current CONFIGURE operations do not modify any word in this domain.

Therefore current CONFIGURE checksum maintenance must preserve the high byte of
word `17h`.

It must not recalculate or normalize it merely because the low checksum
changes.

## Why `3CSEED` calculates it

`3CSEED` constructs complete synthetic EEPROM images.

Unlike CONFIGURE, it is responsible for producing internally consistent mock
fixtures from scratch.

Its `Build_Checksum` therefore calculates both:

```text
secondary high
    words 10h..12h + 20h..3Fh

secondary low
    words 13h..16h
```

and stores them together in word `17h`.

That does not mean CONFIGURE should do the same on every modification.

The two programs have different responsibilities.

# Checksum domains at a glance

```text
PRIMARY CHECKSUM, word 0Fh

          high byte                             low byte
              |                                     |
              v                                     v
   words 00h..0Eh                         words 08h,09h,0Dh
   except 08h,09h,0Dh
              |                                     |
              |                                     |
 current CONFIGURE does                    current CONFIGURE
 not modify this domain                    modifies this domain
              |                                     |
              v                                     v
          preserve                             recalculate


SECONDARY CHECKSUM, word 17h

          high byte                             low byte
              |                                     |
              v                                     v
   words 10h..12h                         words 13h..16h
   words 20h..3Fh
              |                                     |
              |                                     |
 current CONFIGURE does              current CONFIGURE modifies
 not modify this domain              13h and potentially 14h
              |                                     |
              v                                     v
          preserve                             recalculate
```

# Checksum update matrix

The checksum work is derived from the EEPROM words that actually changed.

It is not derived merely from which property appeared on the command line.

| Property              | Persistent word(s)    | Primary low `0Fh` | Secondary low `17h` |
| --------------------- | --------------------- | ----------------: | ------------------: |
| `/IOBASE`             | `08h`                 |               Yes |                  No |
| `/INT`                | `09h`                 |               Yes |                  No |
| `/MODEM`              | `0Dh`                 |               Yes |                  No |
| `/FULLDUPLEX`         | `0Dh`                 |               Yes |                  No |
| `/OPTIMIZE`           | `0Dh`                 |               Yes |                  No |
| `/TR`, `/XCVR`        | `08h`                 |               Yes |                  No |
| `/PNP`                | `13h`                 |                No |                 Yes |
| `/BADDRESS`, `/BSIZE` | `08h`, possibly `14h` |  If `08h` changed |    If `14h` changed |

The important wording is:

```text
if the covered EEPROM word changed
```

not:

```text
if the property was requested
```

An already-correct property does not require a checksum rewrite.

# Combined checksum updates

A combined transaction may affect both checksum domains.

For example:

```text
/IOBASE:300 /PNP:DISABLED
```

can change:

```text
word08
word13
```

Therefore the transaction must update:

```text
word0F low
word17 low
```

in the same commit.

Likewise, Boot ROM configuration may change both:

```text
word08
word14
```

and therefore require both checksum domains.

# Persistent write order

The current transaction writes changed property words in this order:

```text
08h
09h
0Dh
13h
14h
```

After those property writes complete, it updates the required checksums.

Conceptually:

```text
write changed persistent data words
              |
              v
      primary checksum needed?
              |
          yes | no
              v
      update word0F low
              |
              v
     secondary checksum needed?
              |
          yes | no
              v
      update word17 low
```

This ordering is deliberate.

The checksum must be calculated from the final persistent data image, not from
an intermediate state before all covered property words have been written.

# EEPROM write protocol

CONFIGURE EEPROM writes are implemented in common code through:

```text
Cfg_Eeprom_Write
```

rather than through a backend-specific "write this EEPROM word directly"
operation.

The routine drives the normal Window 0 EEPROM command and data registers using
the common `Nic_Reg_*` interface.

The current write sequence is:

```text
select Window 0

0030h
    write enable
    wait ready

00C0h | word
    erase selected word
    wait ready

write new data to EEPROM Data register

0030h
    write enable
    wait ready

0040h | word
    write selected word
    wait ready
```

This sequence intentionally follows the original utility.

The common transaction therefore exercises the mock through the same modeled
register protocol rather than bypassing it with a mock-only direct EEPROM
shortcut.

See [`BACKEND.md`](BACKEND.md).

# EEPROM read behavior

CONFIGURE's transaction-local EEPROM reader similarly uses Window 0 EEPROM
commands and the common NIC register interface.

EEPROM reads may return any 16-bit value.

That includes:

```text
FFFFh
```

Therefore EEPROM errors are represented by the defined FLAGS/error contract,
not by reserving a data value.

See [`LOW_LEVEL_CONVENTIONS.md`](LOW_LEVEL_CONVENTIONS.md).

# Checksum readback verification

Checksum writes are verified immediately during
`Cfg_Txn_Write_EEPROM`.

For the primary checksum:

```text
calculate new low byte
preserve old high byte
write word0F
read word0F
compare complete word
```

For the secondary checksum:

```text
read current word17
calculate new low byte
preserve current high byte
write word17
read word17
compare complete word
```

A checksum mismatch is a transaction failure.

Checksum verification is therefore part of the EEPROM commit phase rather
than a later property-specific verification pass.

# Why word `17h` is read immediately before update

Unlike word `0Fh`, the current transaction does not maintain a normal
old/new snapshot of word `17h`.

When the secondary checksum needs updating, `Cfg_Txn_Write_EEPROM` reads the
current word `17h` immediately before calculating and writing the new low byte.

It then preserves the high byte from that current value.

This is sufficient because CONFIGURE owns only the low-byte checksum update
for its current writable secondary domain.

# `3CSEED` checksum responsibility

`3CSEED` does not perform a normal CONFIGURE transaction.

It constructs deterministic mock EEPROM images.

Its checksum builder therefore has a slightly different responsibility from
`Cfg_Txn_Write_EEPROM`.

For the current mock image:

* primary low is calculated from `08h`, `09h`, and `0Dh`
* secondary high is calculated from `10h..12h` and `20h..3Fh`
* secondary low is calculated from `13h..16h`

The resulting mock EEPROM must be internally self-consistent before
`3CHWMOCK.EXE` operates on it.

Direct fixture construction in `3CSEED` must not be confused with the
read-modify-write rules used by the actual CONFIGURE command.

# Persistent PnP resource data

EEPROM words:

```text
18h through 3Fh
```

contain ISA Plug and Play Resource Data.

These are persistent raw EEPROM contents.

The current `/PNP` implementation does **not** regenerate this resource data.

It changes only the ISA Activation Select field in word `13h`.

The existing raw PnP resource data remains untouched.

That distinction matters because the PNP capability, PNP activation policy,
and PNP resource data are three different things:

```text
word10 bit0
    hardware says PNP is supported

word13 bits3:2
    persistent activation policy

words18h..3Fh
    persistent ISA PnP Resource Data
```

# Capability data is not configuration policy

EEPROM word `10h` contains hardware capability information.

For ISA 3C509B, bit `0` indicates Plug and Play capability.

`/PNP` must not modify that capability word.

Changing whether Plug and Play is enabled is a policy change in word `13h`.

It does not change whether the hardware is capable of Plug and Play.

The capability architecture is documented separately in
[`CAPABILITIES.md`](CAPABILITIES.md).

# EEPROM and live state are separate

Several EEPROM words have related live register representations.

Examples include:

```text
EEPROM 08h
    <-> Window 0 Address Configuration

EEPROM 09h
    <-> Window 0 Resource Configuration

EEPROM 12h/13h
    -> Window 3 Internal Configuration at automatic configuration
```

The existence of related fields does not imply continuous mirroring.

A successful EEPROM write is not proof that the corresponding live register
changed.

Likewise, changing live state does not write EEPROM.

The transaction architecture explicitly handles both state domains where
required.

See [`STATE_MODEL.md`](STATE_MODEL.md).

# Adding another EEPROM-backed property

Before adding another CONFIGURE property that writes EEPROM, determine all of
the following.

## 1. Exact field ownership

Identify:

* EEPROM word
* field mask
* field encoding
* whether the field is shared with existing properties
* which bits must be preserved

## 2. Current-state requirement

The transaction must read the complete word before constructing the
prospective state.

Do not initialize the word from a default constant.

## 3. Read-modify-write behavior

The Prepare routine should:

```text
take prospective complete word
clear only owned bits
insert requested field
store prospective complete word
```

It must not access hardware directly.

## 4. Checksum domain

Determine whether the modified word belongs to:

* primary high
* primary low
* secondary high
* secondary low
* no currently modeled checksum domain

Do not infer checksum membership from physical proximity in EEPROM.

## 5. Live-state relationship

Determine whether the persistent field also has a live representation that
requires immediate synchronization.

Do not assume that writing EEPROM is enough.

## 6. Verification

After commit, verify the persistent field or complete prospective word as
appropriate.

Shared-word verification must not accidentally attribute another property's
bits to the new property.

## 7. Mock and seeder consistency

If the field affects mock initialization or reset behavior, update the modeled
hardware semantics rather than adding a CLI-specific shortcut.

If `3CSEED` constructs the field directly, make sure its generated checksums
remain correct.

# EEPROM invariants

The following rules should remain true when modifying persistent
configuration:

* CONFIGURE writes only EEPROM fields intentionally supported by the project.
* An EEPROM definition does not imply a writable CLI feature.
* Properties own bit fields, not whole EEPROM words.
* Every shared word uses read-modify-write semantics.
* Prospective EEPROM words begin as exact copies of current EEPROM contents.
* Prepare routines clear only fields owned by the requested property.
* Unsupported, reserved, and undocumented unrelated bits are preserved.
* `/IOBASE` owns only word `08h` bits `4:0`.
* `/TR` owns only word `08h` bits `15:14` and bit `7`.
* Boot ROM configuration owns word `08h` bits `13:8` plus the explicitly
  handled word `14h` Boot ROM Size Valid bit.
* `/INT` owns only word `09h` bits `15:12`.
* `/MODEM` owns only word `0Dh` bits `13:8`.
* `/FULLDUPLEX` owns only word `0Dh` bit `15`.
* `/OPTIMIZE` owns only word `0Dh` bits `5:4`.
* `/PNP` owns only word `13h` bits `3:2`.
* Word `0Dh` bit `14` remains preserved because LINKBEAT is not implemented as
  a CONFIGURE property.
* Word `0Dh` bits `3:0` remain preserved because Boot Protocol is not a
  supported CONFIGURE property.
* EEPROM word `0Fh` is checksum storage and must not be used for OPTIMIZE or
  another configuration property.
* Primary low checksum covers only words `08h`, `09h`, and `0Dh`.
* Primary high checksum excludes words `08h`, `09h`, and `0Dh`.
* Current CONFIGURE preserves primary checksum high.
* Secondary low checksum covers words `13h` through `16h`.
* Secondary high checksum covers words `10h` through `12h` and `20h` through
  `3Fh`.
* Current CONFIGURE preserves secondary checksum high.
* Checksum work is triggered by changed covered words, not merely by requested
  property names.
* PNP-only transactions do not require primary checksum word `0Fh`.
* Checksum destination high bytes must survive low-byte updates.
* Checksum writes are read back and verified immediately.
* PnP capability, PnP activation policy, and PnP Resource Data remain separate
  concepts.
* PnP Resource Data is not regenerated by `/PNP`.
* EEPROM and corresponding live registers must not be treated as continuously
  mirrored.
* A valid EEPROM value such as `FFFFh` must never double as an error sentinel.
* Do not expand the writable EEPROM surface based on guesswork.

The central rule is:

```text
Read the complete persistent state.

Change only what the requested property actually owns.

Preserve everything else.

Then repair exactly the checksum domain that the change disturbed.
```

The transaction machinery that stages and commits these EEPROM images is
documented in [`TRANSACTIONS.md`](TRANSACTIONS.md).

