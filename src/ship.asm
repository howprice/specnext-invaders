
SHIP_STATE_ALIVE        EQU 0
SHIP_STATE_DESTROYED    EQU 1
SHIP_STATE_COUNT        EQU 2

SHIP_MOVE_SPEED         EQU 2 
SHIP_X_MIN              EQU 32 + 16             ; border + 16
SHIP_X_MAX              EQU 32 + 256 - 16 - 32  ; border + ULA width - sprite width - 32 
SHIP_START_X            EQU SHIP_X_MIN
SHIP_Y                  EQU 32 + 192 - 8  ; border + ULA height - sprite height (ship sprite is 8 pixels tall)

shipState DB SHIP_STATE_ALIVE

; See shipPattern
shipHitboxPatternSpace  Hitbox { $02, $0e, $00, $07 } ; x0, x1, y0, y1
shipHitboxScreenSpace   Hitbox

;-------------------------------------------------------------------------------------------------------------------

SpawnShip:
        ; Set ship position and make visible
        ld ix,shipSprite
        ld (ix+SpriteAttributes.x),SHIP_START_X
        ld (ix+SpriteAttributes.y),SHIP_Y
        ld (ix+SpriteAttributes.vpat),SPRITE_ATTRIBUTE3_FLAG_VISIBLE|SHIP_PATTERN_INDEX // visible, no 5th attribute byte, sprite pattern 

        ; set ship bullet to be invisible
        ld ix,shipBulletSprite
        ld (ix+SpriteAttributes.vpat),SHIP_BULLET_PATTERN_INDEX // not visible, no 5th attribute byte, sprite pattern

        ld a,SHIP_STATE_ALIVE
        ld (shipState),a

        ret

HideShipSprite:
        ld hl,shipSprite+SpriteAttributes.vpat
        ld (hl),SHIP_PATTERN_INDEX
        ret

UpdateShip:

        ASSERT SHIP_STATE_COUNT == 2 ; need a switch statement or jump table
        ld a,(shipState)
        cp SHIP_STATE_ALIVE
        jr z,updateShip_Alive 
        jr updateShip_Destroyed

updateShip_Alive:

        call updateShipPos

        ld ix,shipSprite
        ld de,shipHitboxPatternSpace
        ld hl,shipHitboxScreenSpace
        call CalculateSpriteScreenSpaceHitbox

        ret

updateShip_Destroyed:

        ; flip animation frame every 4 frames
        ld a,(framesInState16)                  ; A = LSB of frames in state
        and $4                                  ; keep only bit 2
        srl a                                   ; A >>= 1
        srl a                                   ; A >>= 1
        add SHIP_DESTROYED_FRAME0_INDEX
        or SPRITE_ATTRIBUTE3_FLAG_VISIBLE
        ld (shipSprite+SpriteAttributes.vpat),a

        ret

;
; Uses inputBits to move ship sprite
; 
updateShipPos:

        ld ix,shipSprite

        ; HL = current X coordinate (9 bit)
        ld l,(ix+SpriteAttributes.x)
        ld a,(ix+SpriteAttributes.mrx8)     ; H = most significant bit of X
        and 1       ; keep only bit 1
        ld h,a      ; HL = 9-bit x coordinate

        ld a,(inputBits)
        
.right  bit INPUT_BIT_RIGHT,a
        jr z,.left
        ld de,SHIP_MOVE_SPEED    ; move speed
        add hl,de               ; HL += DE

        ; x = min(x,SHIP_X_MAX)
        push hl
        ld de,SHIP_X_MAX
        and a                   ; clear carry flag for following 16-bit SBC instruction (there is no 16-bit SUB HL,DE)
        sbc hl,de               ; HL -= (DL+CF) sets carry flag, whereas DEC HL does not. n.b. there is no sub hl,de !
        pop hl
        jr c,.left
        ld hl,SHIP_X_MAX        ; clamp

.left   bit INPUT_BIT_LEFT,a
        jr z,.setSpritePos
        ld de,SHIP_MOVE_SPEED   ; move speed
        and a                   ; clear carry flag for following 16-bit SBC instruction (there is no 16-bit SUB HL,DE)
        sbc hl,de               ; HL -= (DL+CF) sets carry flag, whereas DEC HL does not. n.b. there is no sub hl,de !

        ; x = max(x,SHIP_X_MIN)
        push hl
        ld de,SHIP_X_MIN
        sbc hl,de
        pop hl
        jr nc,.setSpritePos
        ld hl,SHIP_X_MIN        ; clamp

.setSpritePos
        ld (ix+SpriteAttributes.x),l
        ld (ix+SpriteAttributes.mrx8),h
        ret

