# SpecNext Invaders
Simple [ZX Spectrum Next](https://www.specnext.com/) arcade game in Z80N assembly language for educational purposes.

A binary of the game is available at https://howprice.itch.io/specnext-invaders

Features:
- Classic arcade action
- Keyboard and joystick input
- Hardware sprites
- ULA text and destructible shield graphics
- Mode 2 Line Interrupt handler
- Hitbox collision detection
- High-level game state machine
- AY-3 sound effects and 'music'
- 2 player logic
- High score file saving/loading using esxDOS
- Visual Studio Code project files to build, launch in emulators and copy to SD image file
- Well commented code

## Building

The [Z80N](https://wiki.specnext.dev/Extended_Z80_instruction_set) assembly language source code uses syntax compatible with the [SjASMPlus Z80 Cross-Assembler](https://github.com/z00m128/sjasmplus) (tested with v1.18.0).

Build from project root with with command line:

```
sjasmplus --fullpath --sld=bin/invaders.sld --lst=bin/invaders.lst --lstlab --sym=bin/invaders.labels --msg=war src/main.asm
```

[build.bat](./build.bat) is included for the convenience of Windows users.

Build from Visual Studio code Main Menu > Terminal > Run Build Task... (Ctrl+Shift+B)

## Running

Copy the bin/invaders.nex to the SD card used with your ZX Spectrum Next or open with an emulator such as [#CSpect](http://www.cspect.org) (tested with version V2.13.00).

## Development Environment

Developed in [Visual Studio Code](https://code.visualstudio.com/) with extensions:
- [ASM Code Lens maziac.asm-code-lens](https://github.com/maziac/asm-code-lens) language server extension for Visual Studio Code for assembler files
- [DeZog maziac.dezog](https://github.com/maziac/DeZog) Visual Studio Code Debugger for Z80/ZX Spectrum.
- [Z80 Instruction Set maziac.z80-instruction-set](https://github.com/maziac/z80-instruction-set) Shows the Z80 opcode when hovering over an instruction.

Open project folder with  File > Open Folder...

With thanks for information from:
- https://luckyredfish.com/coding-for-the-spectrum-next-emulator-cspect/
- http://www.breakintoprogram.co.uk/computers/zx-spectrum/assembly-language/z80-development-toolchain

### Debugging

Debug in Visual Studio Code with [DeZog](https://github.com/maziac/DeZog). Ensuring that the [DeZog Plugin](https://github.com/maziac/DeZogPlugin) DLL is next to the CSpect.exe (see [./CSpect/_readme.txt](./CSpect/_readme.txt)). 

[launch.json](./.vscode/launch.json) is currently configured for DeZog version 2.0.3.

- Launch CSpect with the -remote command line arg
  - Ctrl+P then type `task CSpect`
  - Select `CSpect (no sound)` to run at a nice smooth 60Hz frame rate, but with no sound
  - Select `CSpect (sound)` to run with sound, but compromising frame rate (this is an OpenAL issue which is on the CSpect roadmap)
  - Select `CSpect (MMC)` to run with an SD image card. See [./sd/readme.txt](./sd/readme.txt) for more information
- Ctrl+Shift+D to open Debugging Side Bar
- Run > Start Debugging (F5)
- If CSpect fails to start check cspect.log

See https://code.visualstudio.com/docs/editor/debugging#_launch-configurations

Tips:
- Some DeZog features are only available through the Debug Console command line e.g. -sprites and -md (dump memory)

## Thanks and attribution

[SpecBong](https://github.com/ped7g/SpecBong) and [Lucky Red Fish](https://luckyredfish.com/patricias-spectrum-next-links/) were extremely helpful getting started with ZX Spectrum Next development.

[hdfmonkey](https://github.com/gasman/hdfmonkey)

Thanks to Shiru for the [AYFX Editor and player](https://shiru.untergrund.net/software.shtml#old). Modified to support looping samples.

## Recommended reading
- http://z80-heaven.wikidot.com/advanced-math
- "Z80 Assembly Language Subroutines" by Lance A. Leventhal and Winthrop Saville. The first few chapters are excellent for programmers who are familiar with high-level languages (C, C++, Python etc). It explains how to do everyday things such as loops, working with arrays and structures. Very succinctly written and a welcome change from 'beginners' books.
- https://wikiti.brandonw.net/index.php?title=Z80_Optimization is a collection of lots of good standard programming patterns (retrieved 17 Nov 2020)

## Z80 Coding Style and Conventions

- Whitespace
  - Spaces, not tabs
  - Instructions indented 8 spaces
  - No space between oprands e.g. ld a,b
- Naming conventions
  - Upper case assembler directives e.g. EQU, ORG, IF, ENDIF
  - Upper case constants e.g. MAGENTA EQU %011
  - Lower case operators (opcode mnemonics) and registers e.g. push hl
  - Function names UpperCamelCase and end with colon e.g. DrawScore:
    - Local helper functions can be lowerCamelCase to make it clear they are not part of the "public" API
  - Local labels start with .
  - Data labels (variable names) lowerCamelCase e.g. playerScore: DW 0
    - Addresses that contain addresses (i.e. pointers) should start with a 'p' e.g. pActivePlayer DW $0000
  - Struct names UpperCamelCase e.g. STRUCT InvaderBullet
- Comments
  - Only use semi-colon
  - Capital register names in comments
  - No vertical space between comment above function and the function. Use single ; on last line if required (for VS Code intellisense)
  - Function comments should mark all input with =, output with <- and modified registers
    ;
    ; DE = address of addhend
    ; B <- sum
    ; Modifies: AF, BC, DE, HL
    ;
    sum:
        ...
- Other
  - Use $ for hex literals e.g. ld hl,$4000
