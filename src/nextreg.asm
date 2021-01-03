;-------------------------------------------------------------------------------------------------------
; Next Registers
;
; Most up-to-date list can be found in FPGA core GitLab:
; https://gitlab.com/SpectrumNext/ZX_Spectrum_Next_FPGA/-/blob/master/cores/zxnext/nextreg.txt
;
; See https://wiki.specnext.dev/Board_feature_control (second half "Next/TBBlue Feature Control Registers")

NEXTREG_RESET EQU $02   ; https://wiki.specnext.dev/Next_Reset_Register
; bit 1 = Generate a hard reset (reboot)
; bit 0 = Generate a soft reset

NEXTREG_PERIPHERAL_1 EQU $05 ; https://wiki.specnext.dev/Peripheral_1_Register
; Sets joystick mode, video frequency and Scandoubler.
;(R/W)
;  bits 7:6 = Joystick 1 mode (LSB)
;  bits 5:4 = Joystick 2 mode (LSB)
;  bit 3 = Joystick 1 mode (MSB)
;  bit 2 = 50/60 Hz mode (0 = 50Hz, 1 = 60Hz, Pentagon is always 50Hz)
;  bit 1 = Joystick 2 mode (MSB)
;  bit 0 = Enable scandoubler (1 = enabled)
;Joystick modes:
;  000 = Sinclair 2 (12345)
;  001 = Kempston 1 (port 0x1F)
;  010 = Cursor (56780)
;  011 = Sinclair 1 (67890)
;  100 = Kempston 2 (port 0x37)
;  101 = MD 1 (3 or 6 button joystick port 0x1F)
;  110 = MD 2 (3 or 6 button joystick port 0x37)
;  111 = I/O Mode

NEXTREG_CPU_SPEED EQU $07
; 0x07 (07) => CPU Speed
; (R)
;   bits 7:6 = Reserved
;   bits 5:4 = Current actual cpu speed
;   bits 3:2 = Reserved
;   bits 1:0 = Programmed cpu speed
; (W)
;   bits 7:2 = Reserved, must be 0
;   bits 1:0 = Set cpu speed (soft reset = 00)
;     00 = 3.5 MHz
;     01 = 7 MHz
;     10 = 14 MHz
;     11 = 28 MHz
NEXTREG_CPU_SPEED_FLAGS_3_5MHZ EQU %00
NEXTREG_CPU_SPEED_FLAGS_7MHZ   EQU %01
NEXTREG_CPU_SPEED_FLAGS_14MHZ  EQU %10
NEXTREG_CPU_SPEED_FLAGS_28MHZ  EQU %11

NEXTREG_PERIPHERAL_4 EQU $09  ; https://wiki.specnext.dev/Peripheral_4_Register
; 0x09 (09) => Peripheral 4 Setting
; (R/W)
; bit 7 = Place AY 2 in mono mode (hard reset = 0)
; bit 6 = Place AY 1 in mono mode (hard reset = 0)
; bit 5 = Place AY 0 in mono mode (hard reset = 0)
; bit 4 = Sprite id lockstep (nextreg 0x34 and port 0x303B are in lockstep) (soft reset = 0)
; bit 3 = Reset divmmc mapram bit (port 0xe3 bit 6) (read returns 0)
; bit 2 = 1 to silence hdmi audio (hard reset = 0)
; bits 1:0 = Scanline weight
;   00 = scanlines off
;   01 = scanlines 50%
;   10 = scanlines 25%
;   11 = scanlines 12.5%
;
; In "mono" mode A+B+C is sent to both R and L channels, makes it a bit louder than stereo mode.
; n.b. This doesn't currently work on CSpect

NEXTREG_SPRITES_AND_LAYERS_SYSTEM EQU $15 ; https://wiki.specnext.dev/Sprite_and_Layers_System_Register
NEXTREG_SPRITES_AND_LAYERS_SYSTEM_FLAG_SHOW_SPRITES EQU $1
NEXTREG_SPRITES_AND_LAYERS_SYSTEM_FLAG_SPRITES_OVER_BORDER EQU $2

NEXTREG_ACTIVE_VIDEO_LINE_MSB EQU $1E ; https://wiki.specnext.dev/Active_Video_Line_MSB_Register
NEXTREG_ACTIVE_VIDEO_LINE_LSB EQU $1F ; https://wiki.specnext.dev/Active_Video_Line_LSB_Register

NEXTREG_LINE_INTERRUPT_CONTROL   EQU $22  
; Controls the timing of raster interrupts and the ULA frame interrupt.
; Bit 2  If 1 disables original ULA interrupt (Reset to 0 after a reset)
; Bit 1  If 1 enables Line Interrupt (Reset to 0 after a reset)
; Bit 0  MSB of Line Interrupt line value (Reset to 0 after a reset)
; https://wiki.specnext.dev/Raster_Interrupt_Control_Register

NEXTREG_LINE_INTERRUPT_VALUE_LSB EQU $23
; https://wiki.specnext.dev/Video_Line_Interrupt_Value_Register

NEXTREG_PALETTE_INDEX EQU $40 ; https://wiki.specnext.dev/Palette_Index_Register
; (R/W)
;  bits 7:0 = Select the palette index to change the associated colour. (soft reset = 0)

NEXTREG_PALETTE_VALUE_8_BIT_COLOUR EQU $41 ; https://wiki.specnext.dev/Palette_Value_Register
; Palette Value (8 bit colour)
; (R/W)
;   bits 7:0 = Colour for the palette index selected by nextreg 0x40. 
;     The format is RRRGGGBB -  the lower blue bit of the 9-bit colour will be the logical
;     OR of blue bits 1 and 0 of this 8-bit value.
;     After the write, the palette index is auto-incremented to the next index if the
;     auto-increment is enabled in nextreg 0x43.  Reads do not auto-increment.
;     Any other bits associated with the index will be zeroed.

NEXTREG_PALETTE_CONTROL EQU $43 ; https://wiki.specnext.dev/Enhanced_ULA_Control_Register
; bit 7 = set to 1 to disable palette write auto-increment.
; bits 6-4 = Select palette for reading or writing:
;            000 = ULA first palette
;            100 = ULA second palette
;            001 = Layer 2 first palette
;            101 = Layer 2 second palette
;            010 = Sprites first palette
;            110 = Sprites second palette
;            011 = Tilemap first palette
;            111 = Tilemap second palette
; bit 3 = Select Sprites palette (0 = first palette, 1 = second palette)
; bit 2 = Select Layer 2 palette (0 = first palette, 1 = second palette)
; bit 1 = Select ULA palette (0 = first palette, 1 = second palette)
; bit 0 = Enabe ULANext mode if 1. (0 after a reset)
NEXTREG_PALETTE_CONTROL_FLAGS_SPRITES_FIRST_PALETTE_RW EQU %010 << 4

NEXTREG_PALETTE_VALUE_9_BIT_COLOUR EQU $44  ; https://wiki.specnext.dev/Enhanced_ULA_Palette_Extension
; 0x44 (68) => Palette Value (9 bit colour)
; (R/W)
;   Two consecutive writes are needed to write the 9 bit colour
;   1st write:
;     bits 7:0 = RRRGGGBB
;   2nd write:
;     bits 7:1 = Reserved, must be 0
;     bit 0 = lsb B
;     If writing to an L2 palette
;     bit 7 = 1 for L2 priority colour, 0 for normal.
;       An L2 priority colour moves L2 above all layers.  If you need the same
;       colour in both priority and normal modes, you will need to have two
;       different entries with the same colour one with and one without priority.
;   After two consecutive writes the palette index is auto-incremented if
;   auto-increment is enabled in nextreg 0x43.
;   Reads only return the 2nd byte and do not auto-increment.
;   Writes to nextreg 0x40, 0x41, 0x43 reset to the 1st write.

NEXTREG_SPRITE_TRANSPARENCY_INDEX EQU $4B  ; https://wiki.specnext.dev/Sprites_Transparency_Index_Register
; 0x4B (75) => Sprite Transparency Index
; (R/W)
;   bits 7:0 = Sprite colour index treated as transparent (soft reset = 0xe3) <- n.b!
;   For 4-bit sprites only the bottom 4-bits are used
;-------------------------------------------------------------------------------------------------------
