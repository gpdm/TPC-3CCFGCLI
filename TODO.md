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

### [Enhancement] Would be interesting to write a detection capability for 8-bit/16-bit bus.

Could be use to dynamically narrow-down the allowed IRQs for 8-bit bus systems.
Not strictly needed, but nice to have.

### [Enhancement] Implement CLI Exit Codes

The original utility does not emit return codes on the CLI either.

But it could be useful anyway to emit return codes for success states, but also
non-zero codes after command, hardware, and verification failures.

Not a priority thing right now.

