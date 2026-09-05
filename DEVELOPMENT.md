## How this started

This project started out of sheer curiosity.

While reading through the 3C509B nestor project, I saw a request asking if someone could strip the MEWEL text UI out of the original 3Com config utility. Didn't think it was doable, but I started looking anyway.

Disassembled the original binary using DOS Sourcer 8, spent time in Ghidra, generated ridiculous call graphs, and tried to untangle the config logic from the UI.

At some point it became pretty obvious that this would take ages.

The original utility isn't just a small config tool with a text UI bolted on. It's a mess of interconnected code linked against old runtime libraries. Even if I dissected the whole thing, I'd still be stuck figuring out what could safely be thrown away and how to link it back into a working program.

Unreasonable. What I actually needed was a clean reimplementation.

Only problem: I wasn't motivated to write a DOS program from scratch in C. And definitely not in assembly.

I'd done x86 assembly before, but that was about 35 years ago. I was rusty. I could read it, but the details were gone.

There was, however, another motivation.

I am lazy.

I really do not enjoy moving retro network cards from one machine to another just to change an IRQ. Shoving the card into a newer system, running the 3Com utility, and moving it back to the XT works, but it's an annoying workaround.

Around the same time, work discussions about AI coding kept popping up. Someone always had a reason why LLMs were supposedly useless for real development.

That got me thinking. What if I could make a point here?

I still knew enough assembly to understand what code was doing, question it, and test it. I was just rusty. So what if I used an LLM to help me get back into it, analyze the original binary, reason about the hardware, and fill in the blanks?

And if I was going to try that, why not make it interesting? Writing another modern web app wouldn't prove anything. Writing a DOS config utility in 8086/8088 assembly—talking directly to ISA hardware and EEPROMs while cramming into machines with almost no memory—seemed like a much better test.

If LLM-assisted development could get that working reliably, that would prove a lot.

So that's how `3CCFGCLI` started.

### Implementing a basic reader

Once I gave up on cutting up the original utility, the first goal was small: find the cards correctly, identify them, read their config, and don't write *anything* yet.

The resulting 0.1 alpha was a single 1,500-line assembly file. `LIST` worked. `CONFIGURE` deliberately didn't. That gave me a read-only baseline against real hardware before touching a single EEPROM byte.

Once basic discovery was solid, I expanded `LIST`. The first version found adapters and showed basics (model, MAC, IOBASE, IRQ), but without the text UI, a lot of useful info disappeared. So I decoded more EEPROM and live state: ASIC revisions, transceiver configs, PnP data, Boot ROM info, and compatibility levels.

I was cautious not to touch the core discovery code once it worked. Additional EEPROM reads happened *after* enumeration finished, keeping them outside the main NIC record layout. That became a rule: once a piece worked against real hardware, don't casually disturb it.

By then the program was closing in on 2,000 lines, but it was still just a read-only inspection tool. The dangerous part—changing configs—hadn't even started.

### Building CONFIGURE without configuring anything

For 0.3 alpha I finally started on `CONFIGURE`. But I still didn't let it write anything.

First came the framework: how the original utility parsed options, selected adapters, matched abbreviated names, handled aliases, and dealt with multiple cards. `CONFIGURE` understood the properties, selected the right adapter using `LIST`'s engine, and revalidated it against the hardware before proceeding.

The individual handlers were stubs returning "not implemented."

Underneath them, though, I built the engine: low-level register helpers, command/EEPROM timeout handling, EEPROM read/write routines, checksum calculators for different regions, and ISA deactivation/reactivation sequences.

None of the write code was reachable from the CLI yet. That was intentional. I'd already made mistakes understanding EEPROM fields earlier; I didn't want my first working config command to also be my first time blasting all that untested code at a real card.

### Real hardware vs. a mock

The first actual writes in the 0.3 series were tested on real hardware. Important, because no emulator—DOSBox, PCem, 86Box—emulates a 3Com EtherLink III closely enough for this. I had to put the card in a machine and see if it survived.

It did. `/INT` was the first property I enabled, and the write path worked. That's also when `/VERBOSE` became essential. When code starts mutating EEPROM and live registers, a simple "success" or "failure" message tells you nothing.

The catch: I was developing on a Mac. Every hardware test meant building the binary, transferring it to the DOS box, running it, looking at the result, and going back to the Mac. That gets old fast.

So I split the hardware interface from the CLI logic and built a software mock: `3CHWIF.ASM`, `3CMOCKIF.ASM`, `3CSEED`, and two binaries (`3CCFGCLI.EXE` and `3CHWMOCK.EXE`). The main program shouldn't care if it's talking to a real 3C509B or a simulated one. `3CSEED` created known states, and I could test repeatedly without swapping cards.

### When the architecture paid off

The backend split accelerated the 0.5 series. I could add config verbs without reinventing the write path. The parser validated the request, the property handler staged the value, and the shared transaction code read the state, merged changes, updated EEPROM words, recalculated checksums, synced live registers, and verified the result.

Good call, because some values share EEPROM words. MODEM and Full Duplex share Software Information word 0Dh. IOBASE, transceivers, and Boot ROM all touch Address Configuration word 08h. A centralized transaction meant multiple requests could be combined into one prospective image before touching the hardware, preventing one command from wiping out bits belonging to another.

PNP, MODEM, FULLDUPLEX, OPTIMIZE, Boot ROM, and transceiver selection followed quickly. No card swapping. No moving binaries around.

### Realizing the simple mock wasn't good enough

Hardware compliance testing exposed a fundamental flaw: the first mock was too simple.

I built it around the behavior I expected from `3CCFGCLI`. If the program needed an EEPROM word, I gave it that word. If it needed register bits, I gave it those bits.

Bah, how wrong I was.

I wasn't testing hardware behavior; I was testing the behavior I had *implemented*. If both the CLI and the mock shared the same wrong assumption, the test passed brilliantly. Until I tried it on a real card.

I had to refactor the mock to represent persistent EEPROM state and live register state separately. Reset behavior mattered. Window selection mattered. Command busy states had to exist.

The funny part? The LLM had suggested building a hardware model based on the technical manual much earlier. My reaction: *Nah, that's unnecessary complexity for a few bytes.*

My decision. My mistake.

### Checksums, because one wasn't enough

Early on, I underestimated EEPROM checksum handling. I implemented what I thought was a second checksum scheme, decided it was wrong, and stripped it out. Later investigation proved there *was* an additional checksum domain, just not how I initially assumed. Back it came.

Reverse engineering isn't a straight line. An interpretation looks correct, survives testing, and is later contradicted by the original utility, the docs, or the hardware. Code goes in. Code comes out. Code goes back in for a different reason.

That's why I got conservative about writes. If something couldn't be verified, I left it out. `LINKBEAT` is a good example: the name exists in the original binary, but the reference utility doesn't actually use it. Rather than invent an implementation, I skipped it. Compatibility with what 3Com actually did matters more than chasing every stray string in the binary.

### Boot ROM support and final audits

By the 0.7 series, most features were done. Shifted focus from adding features to auditing what was already there: stale procedures, unreachable branches, redundant reads, failure handling, parser inconsistencies.

Replacing a linear error dispatch routine with a pointer table knocked several hundred bytes off the binary—crucial for 8086/8088 memory limits. I ran hardware limit tests with 64KB, 128KB, and 256KB caps to make sure it actually ran where it needed to.

Boot ROM config was the last messy corner. Writing a ROM base address to EEPROM is easy; knowing if a valid ROM is actually installed is harder. Added a ROM access abstraction to both backends, validating signatures, sizes, checksums, and paging behavior. `/BADDRESS` and `/BSIZE` are still the trickiest parts, mostly because I don't have physical ROM modules for every test case.

### What the LLM actually did

The workflow evolved. Early on, it was syntax and disassembly help. Later, an implementation assistant—taking source and docs, drafting pieces, and reviewing them. Eventually, it became an adversarial reviewer: *Find what's wrong with this. Assume my conclusion is wrong and rederive it.*

It found real issues: an EEPROM read path treating `FFFFh` as an error even though it's a valid value, bad interrupt restoration using `STI`, missing readback verification on transceivers, and broken cross-property validation.

To be absolutely clear: Had I written all of this completely by myself, it would have taken months. And I wasn't willing to invest that much time.

Two weeks later, the utility went from a read-only experiment to an almost finished tool. There are still corners I don't entirely trust, and bugs are surely hiding somewhere.

But it works. On real hardware. On an 8086.

And that's a lot further than I expected this experiment to go.