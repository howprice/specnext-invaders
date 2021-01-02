INVADER_BULLETS_ENABLED EQU 1
SQUIGGLY_BULLET_ENABLED EQU 1
PLUNGER_BULLET_ENABLED  EQU 1
ROLLING_BULLET_ENABLED  EQU 1

INVADER_BULLET_SPEED    EQU 1  ; n.b. changing this will require changes to collision code

        STRUCT InvaderBullet
active                  BYTE
pSpriteAttributes       WORD    ; address of sprite attributes
pColumnSequence         WORD    ; address of column sequence array, or zero if targetted bullet
sequenceLength          BYTE    ; length of the sequence, or zero if targetted bullet
sequenceIndex           BYTE    ; current sequence index, of $ff if targetted bullet
frame0PatternIndex      BYTE    ; first frame of animation
pHitboxPatternSpace     WORD    ; address of pattern-space hitbox
hitboxScreenSpace       Hitbox  ; screen-space hitbox
        ENDS

invaderBullets
squigglyBullet InvaderBullet {
        $00,                                            ; not active
        invaderBulletSprites + 0 * SpriteAttributes,    ; invader bullet sprite 0
        squigglyBulletColumnSequence,                   ; address of sequence array
        SQUIGGLY_BULLET_COLUMN_SEQUENCE_LENGTH,         ; array length
        $00,                                            ; array index
        SQUIGGLY_BULLET_FRAME_0_PATTERN_INDEX,          ; first frame pattern index
        invaderBulletHitboxesPatternSpace               ; &invaderBulletHitboxesPatternSpace[0]
        { 0, 0, 0, 0 }                                  ; screen-space hitbox        
}

plungerBullet InvaderBullet {
        $00,                                            ; not active
        invaderBulletSprites + 1 * SpriteAttributes,    ; second invader bullet sprite
        plungerBulletColumnSequence,                    ; address of sequence array
        PLUNGER_BULLET_COLUMN_SEQUENCE_LENGTH,          ; array length
        $00,                                            ; array index
        PLUNGER_BULLET_FRAME_0_PATTERN_INDEX,           ; first frame pattern index
        invaderBulletHitboxesPatternSpace               ; &invaderBulletHitboxesPatternSpace[0]
        { 0, 0, 0, 0 }                                  ; screen-space hitbox 
}

; Rolling invader bullet is dropped from invader closest to player's ship
rollingBullet InvaderBullet {
        $00,                                            ; not active
        invaderBulletSprites + 2 * SpriteAttributes,    ; second invader bullet sprite
        $0000,                                          ; address of sequence array
        0,                                              ; array length
        $ff,                                            ; invalid array index means targetted
        ROLLING_BULLET_FRAME_0_PATTERN_INDEX,           ; first frame pattern index
        invaderBulletHitboxesPatternSpace + Hitbox      ; &invaderBulletHitboxesPatternSpace[1]
        { 0, 0, 0, 0 }                                  ; screen-space hitbox 
}
        ; CollideInvaderBulletsWithShip depends on array of invader bullet structs
        ASSERT $ - invaderBullets == INVADER_BULLET_COUNT * InvaderBullet

; Array of column indices from which to drop the squiggly bullet in round-robin
squigglyBulletColumnSequence DB $0A, $00, $05, $02, $00, $00, $0A, $08, $01, $07, $01, $0A, $03, $06, $09
SQUIGGLY_BULLET_COLUMN_SEQUENCE_LENGTH EQU $-squigglyBulletColumnSequence ; TODO: Remove this - terminate sequence with FF instead

; Array of column indices from which to drop the plunger bullet in round-robin
plungerBulletColumnSequence DB $00, $06, $00, $00, $00, $03, $0a, $00, $05, $02, $00, $00, $0a, $08, $01, $07
PLUNGER_BULLET_COLUMN_SEQUENCE_LENGTH EQU $-plungerBulletColumnSequence

; One per type                                  ;   x0   x1   y0   y1
invaderBulletHitboxesPatternSpace       Hitbox { $00, $02, $00, $05 } ; squiggly and plunger
                                        Hitbox { $00, $02, $00, $06 } ; rolling

;-------------------------------------------------------------------------------------------------------------------

UpdateInvaderBullets:

        IF INVADER_BULLETS_ENABLED == 0
        ret
        ENDIF

        IF SQUIGGLY_BULLET_ENABLED
        ld ix,squigglyBullet
        call updateInvaderBullet
        ENDIF

        IF PLUNGER_BULLET_ENABLED
        ld ix,plungerBullet
        call updateInvaderBullet
        ENDIF

        IF ROLLING_BULLET_ENABLED
        ld ix,rollingBullet
        call updateInvaderBullet
        ENDIF

        ret

ResetInvaderBullets:
        ld hl,squigglyBullet
        call ResetInvaderBullet

        ld hl,plungerBullet
        call ResetInvaderBullet
        
        ld hl,rollingBullet
        call ResetInvaderBullet

        ret

;
; HL = &invaderBullet
; Modifies: DE, HL
;
ResetInvaderBullet:
        ASSERT InvaderBullet.active == 0 ; succeeding instruction assumes offset of zero
        ld (hl),$00

        ASSERT InvaderBullet.pSpriteAttributes == 1 ; following instructions depends on this
        inc hl                                          ; HL = &InvaderBullet.pSpriteAttributes
        ; dereference pointer to pointer
        ld e,(hl)                                       ; E = LSB of address 
        inc hl                                          ; HL = &InvaderBullet.pSpriteAttributes + 1
        ld d,(hl)                                       ; D = MSB of address
        ex de,hl                                        ; HL = &spriteAttributes
        add hl,SpriteAttributes.vpat                    ; HL = address of sprite attribute 3
        res SPRITE_ATTRIBUTE3_BIT_VISIBLE,(hl)          ; hide sprite

        ret

;
; Updates an invader bullet, either squiggly or plunger
; IX = address of InvaderBullet struct
; Modifies: lots 
updateInvaderBullet:

        call updateInvaderBulletPos

        ; Always update the hitbox, even if the bullet is not active (worst case performanceshipHitboxPatternSpace)
        ; DE = address of pattern-space hitbox
        ld e,(ix+InvaderBullet.pHitboxPatternSpace)     ; fake instruction: ld de,(ix+nn)   
        ld d,(ix+InvaderBullet.pHitboxPatternSpace+1)   ; ...
        ; HL = address of screen-space hitbox
        push ix                                         ; fake instruction: ld hl,ix  
        pop hl                                          ; ...
        add hl,InvaderBullet.hitboxScreenSpace
        ; IX = address of sprite attributes struct
        push hl                                         ; stash HL
        ld l,(ix+InvaderBullet.pSpriteAttributes)       ; fake instruction ld hl,(ix+nn)
        ld h,(ix+InvaderBullet.pSpriteAttributes+1)     ; ...
        push hl                                         ; fake instruction: ld ix,hl
        pop ix                                          ; ...
        pop hl                                          ; restore HL
        call CalculateSpriteScreenSpaceHitbox

        ret

;
; Updates an invader bullet of any type
; IX = address of InvaderBullet struct
; Preserves: IX
; Modifies: AF, C, DE, HL
;
updateInvaderBulletPos:

        ld c,(ix+InvaderBullet.frame0PatternIndex)   ; for later call to AnimateBullet

        ld a,(ix+InvaderBullet.active)
        and a                           ; set flags
        jr nz,.updateActiveBullet

.updateInactiveBullet
        ; if bullet is not already active then spawn bullet
        ; TODO: Only spawn when timer counts down

        push bc
        call getInvaderToDropBullet ; A <- invader index
        pop bc

        ; if there are no live invaders in the selected column then return
        cp INVALID_INVADER_INDEX
        ret z

        ld (ix+InvaderBullet.active),$1 ; make bullet active

        ; IY <- &invaderSprites[A] 
        ld iy,(pActiveInvaderSprites)   ; IY <- address of invader 0 sprite attributes
        ld d,a                          ; D = element index
        ld e,SpriteAttributes           ; E = sizeof sprite attribute struct
        mul d,e                         ; DE <- D * E = offset of invaderSprites[i] (Z80N opcode)
        add iy,de                       ; IY <- &invaderSprites[i]

        ; Position bullet sprite underneath invader

        ; Set ix to sprite attribute address in S_INVADER_BULLET.spriteAttributes
        push ix                                         ; stash sprite address
        ld l,(ix+InvaderBullet.pSpriteAttributes)        ; fake instruction ld hl,(ix+nn)
        ld h,(ix+InvaderBullet.pSpriteAttributes+1)      ; ...
        push hl                                         ; fake instruction: ld ix,hl
        pop ix                                          ; ...

        ; x pos
        ld l,(iy+SpriteAttributes.x)
        ld a,(iy+SpriteAttributes.mrx8)         ; A = most significant bit of X
        and 1                                   ; keep only bit 1
        ld h,a                                  ; HL = 9-bit x coordinate
        add hl,$8                               ; centre horizontally
        ld (ix+SpriteAttributes.x),l
        ld (ix+SpriteAttributes.mrx8),h
        
        ; y pos
        ld a,(iy+SpriteAttributes.y)            ; A  = invader y 
        add a,8                                 ; invader sprite patterns are 8 pixels in height
        ld (ix+SpriteAttributes.y),a

        ; make sprite visible
        call animateInvaderBullet
        pop ix                                  ; restore sprite address
        ret

.updateActiveBullet

        ; Set ix to sprite attribute address in S_INVADER_BULLET.spriteAttributes
        push ix                                         ; store InvaderBullet struct for later
        ld l,(ix+InvaderBullet.pSpriteAttributes)        ; fake instruction ld hl,(ix+nn)
        ld h,(ix+InvaderBullet.pSpriteAttributes+1)      ; ...
        push hl                                         ; fake instruction: ld ix,hl
        pop ix                                          ; ...

        ld a,(ix+SpriteAttributes.y)                    ; A  = bullet y 
        add a,INVADER_BULLET_SPEED                      ; y += speed
        cp 32+192                                       ; A -= ULA screen max Y
        jr nc,.reset                                    ; y < 0 ?
        ld (ix+SpriteAttributes.y),a                    ; store new y pos

        call animateInvaderBullet
        pop ix                                          ; restore stack state
        ret

.reset  ld (ix+SpriteAttributes.vpat),0                 ; make sprite invisible
        pop ix                                          ; IX <- bullet struct
        ld (ix+InvaderBullet.active),$0                 ; make bullet inactive
        ret

;
; Sets the bullet's sprite pattern based on its y position and sets 4th sprite attribute visibility bit
; IX = Sprite Attribute address
; A = y
; C = frame 0 pattern index e.g. SQUIGGLY_BULLET_FRAME_0_PATTERN_INDEX
; Modifies: AF
animateInvaderBullet:
        ASSERT SQUIGGLY_BULLET_FRAME_COUNT == 4         ; next instruction relies on 4 frames of animation
        ASSERT PLUNGER_BULLET_FRAME_COUNT == 4          ; next instruction relies on 4 frames of animation
        ASSERT ROLLING_BULLET_FRAME_COUNT == 4          ; next instruction relies on 4 frames of animation
        sra a                                           ; A = A >> 1 so only animates every 2nd frame
        and $3                                          ; keep lowest 4 bits of y. A = [0,3] (invader bullet has 4 frames)
        add c                                           ; A = [FRAME_0_PATTERN_INDEX, FRAME_3_PATTERN_INDEX]
        or SPRITE_ATTRIBUTE3_FLAG_VISIBLE
        ld (ix+SpriteAttributes.vpat),a // visible, no 5th attribute byte, sprite pattern
        ret
