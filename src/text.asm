;
; Prints a single character out to a screen address
; A = Character to print
; D = Character Y position
; E = Character X position
; Modifies: AF, BC, DE, HL
;
PrintChar:             
        ld hl, 0x3C00           ; Character set bitmap data in ROM
        ld b,0                  ; BC = character code
        ld c,a
        ; Multiply BC by 8 by shifting left 3 bits
        sla c                   ; lsb = 0, carry flag = msb
        rl b                    ; lsb = carry flag from preceding SLA
        sla c
        rl b
        sla c
        rl b
    
        add hl,bc               ; And add to HL to get first byte of character
        call GetCharAddress     ; Get screen position in DE
        ld b,8                  ; Loop counter - 8 bytes per character
.loop:  ld a,(hl)               ; Get the byte from the ROM into A
        ld (de),a               ; write to screen RAM
        inc hl                  ; Goto next byte of character
        inc d                   ; Goto next line on screen
        djnz .loop              ; Loop around whilst it is Not Zero (NZ)
        ret

;
; Calculates the screen address of a character (X,Y) coordinate
; D = Y character position [0,23] (5 bits)
; E = X character position [0,31] (5 bits) 
; DE <- screen address 
; Modifies: af
;
; The screen address of a pixel, where Y in pixels and X in *bytes* is encoded as:
;              MSB             |         LSB
;  Bit  7  6  5  4  3  2  1  0 |  7  6  5  4  3  2  1  0 
;  Val  0  1  0 Y7 Y6 Y2 Y1 Y0 | Y5 Y4 Y3 X4 X3 X2 X1 X0  where X in chars and Y in pixels
;
; Characters are 8x8, so positioning on 8x8 grid Y2 Y1 Y0 will all be zero
;              MSB             |         LSB
;  Bit  7  6  5  4  3  2  1  0 |  7  6  5  4  3  2  1  0 
;  Val  0  1  0 Y7 Y6  0  0  0 | Y5 Y4 Y3 X4 X3 X2 X1 X0  where X in chars and Y in pixels
;
; Y pixel coord = Y char coord >> 3
;              MSB             |         LSB
;  Bit  7  6  5  4  3  2  1  0 |  7  6  5  4  3  2  1  0 
;  Val  0  1  0 Y4 Y3  0  0  0 | Y2 Y1 Y0 X4 X3 X2 X1 X0  where both X and Y in char coords
;
; http://www.breakintoprogram.co.uk/computers/zx-spectrum/screen-memory-layout
;
GetCharAddress:   
        ; LSB    
        ld a,d         ; A = Y in char coords
        and %00000111  ; A = Y2 Y1 Y0 char coords, resets CF
        ; shift left 5 bits by shifting right 4 bits with carry (save one instruction!)
        rra  ; RRA rotates with carry in and out
        rra
        rra
        rra            ; A = Y2 Y1 Y0 0 0 0 0 0
        or e           ; A = Y2 Y1 Y0 X4 X3 X2 X1 X0
        ld e,a         ; E = Y2 Y1 Y0 X4 X3 X2 X1 X0
        ; MSB
        ld a,d         ; A = Y char coords
        and %00011000  ; A = 0 0 0 Y4 Y3 0 0 0 (char coords)
        or %01000000   ; A = 0 1 0 Y4 Y3 0 0 0 (char coords)
        ld d,a         ; D = 0 1 0 Y4 Y3 0 0 0 (char coords)
        ret
;
; Prints a null terminated string to a screen address (char coords)
; HL = Address of string
; D = Character Y position
; E = Character X position
; Modifies: AF, BC, DE, HL
;
PrintString:
        ld a, (hl)              ; Get character
        cp 0                    ; null terminator?
        ret z                   ; yes - return
        cp 32                   ; CP A with 32 (space character)
        jr c, PrintString       ; If < 32, then don't ouput
        push de                 ; Save screen coordinates
        push hl                 ; And pointer to text string
        call PrintChar
        pop hl                  ; Pop pointer to text string
        pop de                  ; Pop screen coordinates
        inc hl                  ; Skip to next character in string
        inc e                   ; Inc to the next character position on screen
        jr PrintString          ; next char

;
; Clears a horizontal strip of characters
; E = char coord x
; D = char coord y
; B = char count (string length)
;
ClearText:

        call GetCharAddress             ; DE <- ULA pixel coordinate
        ld h,d                          ; H <- screen address MSB
        xor a                           ; A <- 0
.charLoop                               ; B = char loop counter
        ld c,b                          ; C <- char loop counter
        ld b,8                          ; loopY counter = character height = 8 pixels
.loopY  ld (de),a                       ; clear row of 8 pixels
        inc d                           ; next line on screen
        djnz .loopY
        
        ld d,h                          ; D <- initial MSB
        inc e                           ; next character to the right
        ld b,c                          ; B <- char loop counter
        djnz .charLoop

        ret

;
; A = decimal value to print [0,9]
; D = character Y position
; E = character X position
; Modifies: AF, BC, DE, HL
;
PrintDecimalNibble:
        add a,'0'  ; convert numeric value to character code
        call PrintChar
        ret

;
; Prints the two nibbles in a byte as BCD digits to the screen.
; If the nibble values are > 9 then garbage is printed.
;
; a = value
; d = character Y position
; e = character X position
; Modifies: af, bc, de, hl
;
PrintDecimalByte:

        ; print upper nibble
        push af
        rrca      ; a >>= 4
        rrca
        rrca
        rrca
        and $0f   ; mask out lower nibble
        push de
        call PrintDecimalNibble
        pop de

        ; print lower nibble
        pop af   ; restore original BCD byte
        and $0f  ; mask out lower nibble
        inc e    ; advance character position
        call PrintDecimalNibble
        ret

;
; Prints two bytes (4 nibbles) as BCD digits to the screen
; a = MSB
; b = LSB
; d = character Y position
; e = character X position
; Modifies: af, bc, de, hl
;
PrintDecimalWord:

        push de
        push bc
        call PrintDecimalByte
        pop bc
        pop de

        ld a,e      ; advance char x pos
        add a,$2  
        ld e,a
        ld a,b      ; A = LSB
        call PrintDecimalByte

        ret
