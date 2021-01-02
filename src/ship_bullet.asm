SHIP_BULLET_WIDTH       EQU     1
SHIP_BULLET_HEIGHT      EQU     4
SHIP_BULLET_SPEED       EQU     4
SHIP_BULLET_Y_MIN       EQU     32 + PLAY_AREA_START_Y  ; 32 pixel sprite screen border + UI size in ULA

shipBulletActive                DB $00
shipBulletHitboxPatternSpace    Hitbox { $00, $00, $00, $03 } ; x0, x1, y0, y1 (see shipBulletPattern)
shipBulletHitboxScreenSpace     Hitbox

;-------------------------------------------------------------------------------------------------------------------

;
; Call every frame
; 
UpdateShipBullet:
        ld a,(shipBulletActive)
        and a                                   ; set Zero flag if shipBulletActive is zero
        jr nz,.updateActiveBullet

.updateInactiveBullet
        ; if fire pressed this frame then fire bullet
        ld a,(inputPressed)
        bit INPUT_BIT_FIRE,a
        ret z               ; return if fire not pressed
        
        ; set bullet active
        ld a,1
        ld (shipBulletActive),a

        ; Position bullet at ship nuzzle

        ; x pos
        ld a,(shipSprite+SpriteAttributes.x)
        ld l,a
        ld a,(shipSprite+SpriteAttributes.mrx8)         ; H = most significant bit of X
        and 1                                           ; keep only bit 1
        ld h,a                                          ; HL = 9-bit x coordinate
        add hl,$8                                       ; Add x nuzzle offset of 8
        ld a,l
        ld (shipBulletSprite+SpriteAttributes.x),a
        ld a,h
        ld (shipBulletSprite+SpriteAttributes.mrx8),a
        
        ; y pos
        ld a,(shipSprite+SpriteAttributes.y)            ; A  = ship y 
        sub a,4                                         ; bullet sprite image is 4 pixels in height
        ld (shipBulletSprite+SpriteAttributes.y),a

        ; make sprite visible
        ld a,SPRITE_ATTRIBUTE3_FLAG_VISIBLE|SHIP_BULLET_PATTERN_INDEX ; visible, no 5th attribute byte, sprite pattern
        ld (shipBulletSprite+SpriteAttributes.vpat),a 
        
        call calculateShipBulletScreenSpaceHitbox

        ; play sound effect
        ld a,SOUND_EFFECT_INDEX_SHIP_SHOT
        ld b,SOUND_EFFECT_CHANNEL_SHIP
        call AyfxPlayEffect

        ret

.updateActiveBullet
        ld a,(shipBulletSprite+SpriteAttributes.y)      ; A = bullet y 
        sub a,SHIP_BULLET_SPEED                         ; A <- y - speed
        cp SHIP_BULLET_Y_MIN                            ; set carry flag when y < SHIP_BULLET_Y_MIN
        jr c,ResetShipBullet                            ; jump if y < 0 ?
        ld (shipBulletSprite+SpriteAttributes.y),a      ; store new y pos
        call calculateShipBulletScreenSpaceHitbox
        ret

calculateShipBulletScreenSpaceHitbox:
        ld ix,shipBulletSprite
        ld de,shipBulletHitboxPatternSpace
        ld hl,shipBulletHitboxScreenSpace
        call CalculateSpriteScreenSpaceHitbox
        ret

;
; Modifies AF, HL
; 
ResetShipBullet:
        ld hl,shipBulletActive
        ld a,(hl)
        and a                    ; set zero flag if not active
        ret z

        ld (hl),0                         ; shipBulletActive <- 0

        ; hide sprite
        ld hl,shipBulletSprite+SpriteAttributes.vpat
        res SPRITE_ATTRIBUTE3_BIT_VISIBLE,(hl)

        ; increment the active player's bulletsRemoved count (used for UFO spawning and scoring)
        ld hl,(pActivePlayer)           ; HL <- &player
        add hl,Player.bulletsRemoved    ; HL <- &player.bulletsRemoved
        inc (hl)                        ; player.bulletsRemoved++

        call AdvanceUfoScoreSequenceAndSpawnPos

        ret

;
; Control ship bullet with input for debugging collision
;
DebugMoveShipBullet:

        ld ix,shipBulletSprite
        ld b,(ix+SpriteAttributes.x)
        ld c,(ix+SpriteAttributes.y)
        ld a,(inputPressed)
        
.right  bit INPUT_BIT_RIGHT,a
        jr z,.left
        inc b
.left   bit INPUT_BIT_LEFT,a
        jr z,.down
        dec b
.down   bit INPUT_BIT_DOWN,a
        jr z,.up
        inc c
.up     bit INPUT_BIT_UP,a
        jr z,.setSpritePos
        dec c        

.setSpritePos
        ld (ix+SpriteAttributes.x),b
        ld (ix+SpriteAttributes.y),c
        ret
