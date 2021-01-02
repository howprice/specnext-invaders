
        STRUCT Hitbox
x0      BYTE 0  ; min X
x1      BYTE 0  ; max X (inclusive)
y0      BYTE 0  ; min Y
y1      BYTE 0  ; max Y (inclusive)
        ENDS

;
; Transform a sprite's hitbox from pattern space to screenspace
; IX = address of sprite attributes struct
; DE = address of pattern-space hitbox
; HL = address of screen-space hitbox
; Modifies: AF, B, DE, HL
;
CalculateSpriteScreenSpaceHitbox:

        ; x0 (min x)
        ld a,(ix+SpriteAttributes.x)    ; A = spriteX 
        ld b,a                          ; B = spriteX (for subsequent x1 calculation)
        ex de,hl                        ; DE = &hitboxScreenSpace.x0; HL = &hitboxPatternSpace.x0
        add (hl)                        ; A = spriteX + hitboxPatternSpace.x0 = hitboxScreenSpace.x0 (transform to screen space)
        ex de,hl                        ; DE = &hitboxPatternSpace.x0; HL = &hitboxScreenSpace.x0
        ld (hl),a                       ; hitboxScreenSpace.x0 <- A

        ; x1 (max x)
        ld a,b                          ; A = spriteX
        inc de                          ; DE = &hitboxPatternSpace.x1
        inc hl                          ; HL = &hitboxScreenSpace.x1
        ex de,hl                        ; DE = &hitboxScreenSpace.x1; HL = &hitboxPatternSpace.x1
        add (hl)                        ; A = spriteX + hitboxPatternSpace.x1 = hitboxScreenSpace.x1 (transform to screen space)
        ex de,hl                        ; DE = &hitboxPatternSpace.x1; HL = &hitboxScreenSpace.x1
        ld (hl),a                       ; hitboxScreenSpace.x1 <- A

        ; y0 (min y)
        ld a,(ix+SpriteAttributes.y)    ; A = spriteY
        ld b,a                          ; B = spriteY (for subsequent y1 calcultion)
        inc de                          ; DE = &hitboxPatternSpace.y0
        inc hl                          ; HL = &hitboxScreenSpace.y0
        ex de,hl                        ; DE = &hitboxScreenSpace.y0; HL = &hitboxPatternSpace.y0
        add (hl)                        ; A = A + hitboxPatternSpace.y0 = hitboxScreenSpace.y0 (transform to screen space)
        ex de,hl                        ; DE = &hitboxPatternSpace.y0; HL = &hitboxScreenSpace.y0
        ld (hl),a                       ; hitboxScreenSpace.y0 <- A

        ; y1 (max y)
        ld a,b                          ; A = spriteY
        inc de                          ; DE = &hitboxPatternSpace.y1
        inc hl                          ; HL = &hitboxScreenSpace.y1
        ex de,hl                        ; DE = &hitboxScreenSpace.y1; HL = &hitboxPatternSpace.y1
        add (hl)                        ; A = A + hitboxPatternSpace.y0 = hitboxScreenSpace.y1 (transform to screen space)
        ex de,hl                        ; DE = &hitboxPatternSpace.y1; HL = &hitboxScreenSpace.y1
        ld (hl),a                       ; hitboxScreenSpace.y1 <- A

        ret

;
; Collides two hitboxes (bounding boxes)
; DE = address of hitbox A
; HL = address of hitbox B
; CF <- 0 if boxes are overlapping
; Modifies: AF, BC, DE, HL
;
CollideHitboxes:

        ; x-axis
        ; n.b. Max x pos < 256 so we get away with 8-bit arithmetic here
        ld a,(de)                       ; A = ax0 
        ld b,a                          ; B = ax0 (for subsequent test)
        inc de                          ; DE = &a.x1
        ld a,(de)                       ; A = ax1
        cp (hl)                         ; ax1 - bx0  
        ret c                           ; if CF set then bx0 > ax1 i.e. left of B is to the right of the right of A so not overlapping

        inc hl                          ; HL = &b.x1
        ld a,(hl)                       ; A = bx1
        cp b                            ; bx1 - ax0
        ret c                           ; if CF set then ax0 > bx1 i.e. left of A is to the right of the right of B so not overlapping

        ; y-axis
        inc de                          ; DE = &a.y0
        inc hl                          ; HL = &b.y0
        ld a,(de)                       ; A = ay0 
        ld b,a                          ; B = ay0 (for subsequent test)
        inc de                          ; DE = &a.y1
        ld a,(de)                       ; A = ay1
        cp (hl)                         ; ay1 - by0  
        ret c                           ; if CF set then by0 > ay1 i.e. top of B is below of bottom of A so not overlapping

        inc hl                          ; HL = &b.y1
        ld a,(hl)                       ; A = by1
        cp b                            ; by1 - ay0
        ret                             ; return with CF set if ay0 > by1 i.e. top of A below the bottom of B so not overlapping
