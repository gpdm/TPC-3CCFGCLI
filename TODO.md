# 3CCFG TODO

This file documents pending items, in no particular order or priority.


## Bugs

- [Pending Clarification/Compatibility] t1505 duplicate active IOBASE conflict:

  The hardware-faithful mock currently rejects a targeted IOBASE migration
  when two active adapters decode the same IOBASE. The physical port response
  is ambiguous, so selecting and safely reconfiguring adapter 2 is not
  supported by the model.
  
  Retest this with real EtherLink III cards intentionally configured to the
  same IOBASE and the original 3C5X9CFG utility. Determine whether the
  original utility handles this conflict gracefully or simply fails. Until
  confirmed, retain the conservative failure expectation in t1505.
  
## Enhancements

### 3C509 (non-B) Boot ROM Support

As noted in [README.md](README.md), Boot ROM support for 3C509 (non-B) is currently not implemented
in this utility. I have no ROMs curently to even test the Boot ROM support for the 3c509B,
but even more worse, I don't have a plain 3c509 on hand.

I won't spend time on this feature for now until I have test gear on hand.


### [Enhancement] Would be interesting to write a detection capability for 8-bit/16-bit bus.

Could be use to dynamically narrow-down the allowed IRQs for 8-bit bus systems.
Not strictly needed, but nice to have.


### [Enhancement] PnP-BIOS Detection

At the time, since this utility is primarily intended for 8-bit bus systems,
this is not necessary.

But it would just generally be interesting in doing it.


### [Enhancement] Implement CLI Exit Codes

The original utility does not emit return codes on the CLI either.

But it could be useful anyway to emit return codes for success states, but also
non-zero codes after command, hardware, and verification failures.

Not a priority thing right now.

