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
