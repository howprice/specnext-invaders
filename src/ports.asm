;-------------------------------------------------------------------------------------------------------
; Mapped Spectrum Ports
;
; Most up-to-date list can be found in FPGA core GitLab:
; https://gitlab.com/SpectrumNext/ZX_Spectrum_Next_FPGA/-/blob/master/cores/zxnext/ports.txt
;
; See https://wiki.specnext.dev/Board_feature_control (second half "Next/TBBlue Feature Control Registers")

PORT_SPECTRUM_ULA EQU $FE ; Only LSB is read $xxFE https://wiki.specnext.dev/ULA_Control_Port
                         ; Bits 0-2 border colour

PORT_KEMPSTON_JOY1 EQU $1F
PORT_KEMPSTON_JOY2 EQU $37

PORT_SPRITE_SLOT_SELECT EQU $303B ; https://wiki.specnext.dev/Sprite_Status/Slot_Select

PORT_SPRITE_ATTRIBUTE_UPLOAD EQU $57 ; https://wiki.specnext.dev/Sprite_Attribute_Upload
SPRITE_ATTRIBUTE3_BIT_VISIBLE EQU 7    ; bit 7 enables visibility (1 = displayed) https://wiki.specnext.dev/Sprite_Attribute_Upload
SPRITE_ATTRIBUTE3_FLAG_VISIBLE EQU $80 ; "
SPRITE_ATTRIBUTE3_FLAG_EXTENDED EQU $40 ; bit 6 Sprite Attribute 4 is active if set

PORT_SPRITE_PATTERN_UPLOAD EQU $5B ; $xx5B (MSB ignored) https://wiki.specnext.dev/Sprite_Pattern_Upload

PORT_NEXTREG_REGISTER_SELECT EQU $243B
    ; -- port $243B = 9275  Read+Write (detection bitmask: %0010_0100_0011_1011)
    ;   -- selects NextREG mapped at port TBBLUE_REGISTER_ACCESS_P_253B

PORT_NEXTREG_DATA EQU $253B
    ; -- port $253B = 9531  Read?+Write? (detection bitmask: %0010_0101_0011_1011)
    ;   -- read/write data for selected NextREG (read/write depends on the register selected)

; 0xFFFD AY control and AY register select
; (R) Returns the value stored in the selected register on the active AY chip
; (W) If bits 7:5 = 0, selects an AY register in the currently active AY chip
; Otherwise if multiple AY chips is enabled (nextreg 0x08 bit 1 = 1):
;   bit 7 = 1
;   bit 6 = left channel enable
;   bit 5 = right channel enable
;   bit 4 = 1
;   bit 3 = 1
;   bit 2 = 1
;   bits 1:0 = active AY chip
;     11 = AY 0 made active (default)
;     10 = AY 1 made active
;     01 = AY 2 made active
;     00 = reserved
PORT_TURBO_SOUND_NEXT_CONTROL EQU $FFFD ; https://wiki.specnext.dev/Turbo_Sound_Next_Control

; 0xBFFD AY data
; Writes data to the selected register on the active AY chip
PORT_SOUND_CHIP_REGISTER_WRITE EQU $BFFD ; https://wiki.specnext.dev/Sound_Chip_Register_Write
