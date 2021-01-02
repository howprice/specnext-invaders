
;
; Ion pseudo random number generator
; 123 T-states
; A <- random number in range [0,255]
; Modifies: AF
;
; See https://wikiti.brandonw.net/index.php?title=Z80_Routines:Math:Random#Ion_Random
;
; TODO: Optimise this by pre-calulating a 256 array of random numbers and just iterating through
CalcRandomByte:            ; call 17 T-states         
        push hl                 ; 11
        push de                 ; 11
        ld hl,(randomSeed)      ; 16
        ld a,r                  ; 9
        ld d,a                  ; 4
        ld e,(hl)               ; 7
        add hl,de               ; 11
        add a,l                 ; 4
        xor h                   ; 4
        ld (randomSeed),hl      ; 16
        pop de                  ; 10
        pop hl                  ; 10
        ret                     ; 10
                        ;  Total: 123 T-states

randomSeed DB $9f
