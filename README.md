# SpecNext Invaders
Simple [ZX Spectrum Next](https://www.specnext.com/) arcade game for educational purposes.

Programmed in [Z80N](https://wiki.specnext.dev/Extended_Z80_instruction_set) assembly language. Assembled with [sjasmplus](https://github.com/z00m128/sjasmplus). Developed in [Visual Studio Code](https://code.visualstudio.com/) with the [DeZog](https://github.com/maziac/DeZog) plugin. Tested with the [#CSpect](http://www.cspect.org) emulator.

Thanks to [SpecBong](https://github.com/ped7g/SpecBong) and [Lucky Red Fish](https://luckyredfish.com/patricias-spectrum-next-links/) for getting started.

AY audio from [AYFX Editor and player](https://shiru.untergrund.net/software.shtml#old)

A binary of the game is available at https://howprice.itch.io/specnext-invaders

## Recommended reading
- http://z80-heaven.wikidot.com/advanced-math
- "Z80 Assembly Language Subroutines" by Lance A. Leventhal and Winthrop Saville. The first few chapters are excellent for programmers who are familiar with high-level languages (C, C++, Python etc). It explains how to do everyday things such as loops, working with arrays and structures. Very succinctly written and a welcome change from 'beginners' books.
- https://wikiti.brandonw.net/index.php?title=Z80_Optimization is a collection of lots of good standard programming patterns (retrieved 17 Nov 2020)

## Development Environment


Based on information from:
- https://luckyredfish.com/coding-for-the-spectrum-next-emulator-cspect/
- http://www.breakintoprogram.co.uk/computers/zx-spectrum/assembly-language/z80-development-toolchain

Install extensions:
- [ASM Code Lens maziac.asm-code-lens](https://github.com/maziac/asm-code-lens) language server extension for Visual Studio Code for assembler files
- [DeZog maziac.dezog](https://github.com/maziac/DeZog) Visual Studio Code Debugger for Z80/ZX Spectrum.
- [Z80 Instruction Set maziac.z80-instruction-set](https://github.com/maziac/z80-instruction-set) Shows the Z80 opcode when hovering over an instruction.

Open project folder with  File > Open Folder...

### Building

- Main Menu > Terminal > Run Build Task... (Ctrl+Shift+B)

### Debugging

- Launch CSpect with the -remote command line arg
  - Ctrl+P then type 'task CSpect'
- Ctrl+Shift+D to open Debugging Side Bar
- Run > Start Debugging (F5)
- If CSpect fails to start check cspect.log

See https://code.visualstudio.com/docs/editor/debugging#_launch-configurations

Tips:
- Some DeZog features are only available through the Debug Console command line e.g. -sprites and -md (dump memory)

## Z80 Coding Style and Conventions

- Whitespace
  - Labels right aligned
  - Spaces, not tabs
  - Instructions indented 2x4 space tabs = 8 characters
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
