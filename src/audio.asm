InitAudio:

        ; Set AY mono mode to avoid sound effects and music being randomly ABC panned (This doesn't currently work on CSpect)
        ; n.b. Read current nextreg value,to preserve the user's bits 2:0 (silence HDMI audio and scanline weight)
        ld bc,PORT_NEXTREG_REGISTER_SELECT
        ld a,NEXTREG_PERIPHERAL_4
        out (c),a       ; select NextReg
        
        inc b            ; BC = TBBLUE_REGISTER_ACCESS_P_253B
        in a,(c)         ; A <- NextReg value
        or  %111'00'00'0 ; mask on bits 7:5 to enable mono mode for AY chips 2:0
        and %111'00'11'1 ; mask off bit 4 "Sprite id lockstep" n.b. read bit 3 always returns 0 so doesn't matter
        nextreg NEXTREG_PERIPHERAL_4,a  ; NextReg <- A

        call InitMusic

        ld hl,pAyfxSoundEffectsBank
        call AyfxInit

        ret
