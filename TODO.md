# 3CCFG TODO

This file documents pending items, in no particular order or priority.


## Bugs

- [Bug] /TR not chaing /FULLDUPLEX

  When selecting trascever type other than TP, FULLDUPLEX should be automatically disabled.
  The original utility does prevents combining FULLDUPLEX=enabled + COAX/AUI/AUTO combination.

- [Bug] Boot ROM Activation:

  Boot ROM (/BADDRESS & /BSIZE) seem to probe if a ROM is actually socketed.
  The original utility prevents configuration via the CLI if it doesn't find
  a Boot ROM installed.
  The MEWEL Text-UI on the other hand offers to option to configure anyway.

  Though I suspect this would lead to a reboot / POST init loop of some sorts,
  and I shouldn't enforce activation of the Boot ROM if none is equipped.

  In general, this should be tested as well with real hardware and ROMs
  equipped, to fully validate the proper functionality.

  Secondly, a gate must be implemented, which prevents enabling it if
  the probing fails.

  Thirdly: Figure out, how the probing fails.
  To my current understanding, the original utility probes the ROM window,
  if it finds a valid signature.

  So apparently, also the MOCKIF would need to be extended to mimic the
  signature in an identical way how the actual hardware does it.



- [Bug] Hardware Compliance Tests  

  - [Pending Clarification/Compatibility] t1505 duplicate active IOBASE conflict:

    The hardware-faithful mock currently rejects a targeted IOBASE migration
    when two active adapters decode the same IOBASE. The physical port response
    is ambiguous, so selecting and safely reconfiguring adapter 2 is not
    supported by the model.

    Retest this with real EtherLink III cards intentionally configured to the
    same IOBASE and the original 3C5X9CFG utility. Determine whether the
    original utility handles this conflict gracefully or simply fails. Until
    confirmed, retain the conservative failure expectation in t1505.

  - [Pending Clarification/Compatibility] config restore fails

    TESTHWC.MK includes config restoration via `RESTORE.BAT` as generated
    by `3CCFGCLI.EXE` during the compliance test.

    This somewhat broken right now:

    When invoking `RESTORE.BAT 3C5X9CFG.EXE` from `make`, the test system locks up.

    When invoking the same command from the DOS prompt, it runs through.
    This may hint at an actual out-of-memory issue, possible related to MAKE.

    Tested only on MS-DOS 4 so far. Needs further investigation.
    Might be related to the fact that I'm not using MAKE 4.0, but the older MAKE 3.0,
    as only this one runs on MS-DOS 4.



## Enhancements

- [Enhancement] Handle /VERBOSE flag for `SAVECONFIG` and `LIST` command

  While these verbs accept the `/VERBOSE` flag, they don't produce extra diagnostics output.

  Right now, I don't have a need for that, but maybe it's worthwile implementing it.


- [Enhancement] Would be interesting to write a detection capability for 8-bit/16-bit bus.

  Could be use to dynamically narrow-down the allowed IRQs for 8-bit bus systems.
  Not strictly needed, but nice to have.


- [Enhancement] Implement CLI Exit Codes

  Not strictly a bug, since the original utility does not emit return codes on the CLI either.

  But it could be useful anyway to emit return codes for success states, but also
  non-zero codes after command, hardware, and verification failures.

  Not a priority thing right now.