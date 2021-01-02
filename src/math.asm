
;
; Adds two 16-bit BCD numbers. (DE) = (DE) + (HL)
; Ref: http://z80-heaven.wikidot.com/advanced-math#toc6
;
; DE = pointer to little endian source and sum
; HL = pointer to little endian source
; Modifies: AF, DE, HL
;
AddBCD16:
        ; LSB
        ld a,(de)
        add a,(hl)  ; n.b. no need to include carry for LSB
        daa         ; convert to BCD
        ld (de),a
        inc hl
        inc de

        ; MSB
        ld a,(de)
        adc a,(hl)  ; include carry from LSB
        daa         ; convert to BCD
        ld (de),a   
        ret
