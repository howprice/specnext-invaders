
UFO_ENABLED EQU 1

UFO_SPAWN_PERIOD_FRAMES EQU $600    ; $600 frames = 25 seconds at 60Hz

UFO_X_MIN EQU $30
UFO_X_MAX  EQU 32 + 256 - 16 - 32  ; border + ULA width - sprite width - 32 
UFO_Y EQU $34

UFO_SPEED_FRAMES_PER_PIXEL EQU 2  ; moves less than 1 pixel per frame so use inverse speed 

UFO_EXPLOSION_DISPLAY_FRAME_COUNT EQU 10
UFO_SCORE_DISPLAY_FRAME_COUNT EQU 40

UFO_MIN_INVADERS_TO_SPAWN EQU 8 ; don't spawn if less than 8 invaders left alive

ufoHitboxPatternSpace  Hitbox { $00, $0f, $01, $07 } ; x0, x1, y0, y1
ufoHitboxScreenSpace   Hitbox

UFO_STATE_INACTIVE   EQU 0
UFO_STATE_ACTIVE     EQU 1
UFO_STATE_EXPLODING  EQU 2
UFO_STATE_SHOW_SCORE EQU 3
UFO_STATE_COUNT      EQU 4

ufoState            DB $00      ; UFO_STATE_*

ufoSpawnCountdown   DW $0000    ; UFO spawns when reaches zero
ufoMoveCountdown    DB $00      ; moves < 1 pixel per frame so countdown to move

; Table of score for shooting the UFO
; Values are BCD/10, so for example element 0 with value $10 is worth 100 points (decimal)
; Each time a player bullet is removed from play the current score is incremented
; When it reaches the last element it wraps
; "bug" in original code wraps at 15th instead of 16th element. I guess this is so
; the 300 point UFO spawn pos alternates between left and right
ufoScoreTable DB $10, $05, $05, $10, $15, $10, $10, $05, $30, $10, $10, $10, $05, $15, $10 ; $05 last element deliberately removed
ufoScoreTableEnd EQU $
UFO_SCORE_SEQUENCE_COUNT EQU ufoScoreTableEnd-ufoScoreTable

ufoScoreSequenceIndex DB $00

; The patterns in tehis table must match the values in the score table
ufoScoreSpritePatternTable
        DB UFO_100_POINTS_PATTERN_INDEX
        DB UFO_50_POINTS_PATTERN_INDEX
        DB UFO_50_POINTS_PATTERN_INDEX
        DB UFO_100_POINTS_PATTERN_INDEX
        DB UFO_150_POINTS_PATTERN_INDEX
        DB UFO_100_POINTS_PATTERN_INDEX
        DB UFO_100_POINTS_PATTERN_INDEX
        DB UFO_50_POINTS_PATTERN_INDEX
        DB UFO_300_POINTS_PATTERN_INDEX
        DB UFO_100_POINTS_PATTERN_INDEX
        DB UFO_100_POINTS_PATTERN_INDEX
        DB UFO_100_POINTS_PATTERN_INDEX
        DB UFO_50_POINTS_PATTERN_INDEX
        DB UFO_150_POINTS_PATTERN_INDEX
        DB UFO_100_POINTS_PATTERN_INDEX
        ASSERT $-ufoScoreSpritePatternTable == UFO_SCORE_SEQUENCE_COUNT

ufoScoreSpritePatternIndex DB $00

; 0 = spawn on left and move right
; 1 = spawn on right and move left 
; Inverted each time a player bullet is removed from play
ufoSpawnSide DB $00

ufoDirection DB $00 ; direction UFO is travelling. 0 = left-to-right (+x), 1 = right-to-left (-x)

ResetUfo:
        ld hl,UFO_SPAWN_PERIOD_FRAMES   ; HL <- UFO_SPAWN_PERIOD_FRAMES
        ld (ufoSpawnCountdown),hl

        ASSERT UFO_STATE_INACTIVE == 0
        xor a                   ; A <- 0
        ld (ufoState),a         ; ufoState <- UFO_STATE_INACTIVE

        ; hide sprite
        ld hl,ufoSprite+SpriteAttributes.vpat
        res SPRITE_ATTRIBUTE3_BIT_VISIBLE,(hl)

        jp SilenceUfo
;       ret

ResetUfoForPlayer:
        call ResetUfo

        xor a                   ; A <- 0
        ld (ufoSpawnSide),a     ; ufoSpawnSide <- 0, spawn on left and move right

        ; reset UFO score table
        ; TODO: Perhaps this should be persistent per-player state?
        xor a                   ; A <- 0
        ld (ufoScoreSequenceIndex),a

        ret

;
; silence UFO sound effects channel
; 
SilenceUfo:
        ld a,SOUND_EFFECT_CHANNEL_UFO
        jp AyfxStopChannel
;       ret

;
; Call every frame during play
;
UpdateUfo:

        ld a,(ufoState)
        cp UFO_STATE_INACTIVE
        jp z,updateInactiveUfo
        cp UFO_STATE_ACTIVE
        jp z,updateActiveUfo
        cp UFO_STATE_EXPLODING
        jp z,updateExplodingUfo
        cp UFO_STATE_SHOW_SCORE
        jp z,updateShowScore
        ASSERT UFO_STATE_COUNT == 4 ; missing case statement

;
; Call when UFO is destroyed during play
; Modifies: AF, BC, DE, HL
;
DestroyUfo:

        ld a,UFO_STATE_EXPLODING
        ld (ufoState),a

        ld a,SPRITE_ATTRIBUTE3_FLAG_VISIBLE|UFO_EXPLODING_PATTERN_INDEX ; visible, no 5th attribute byte, sprite pattern
        ld (ufoSprite+SpriteAttributes.vpat),a

        ; Store correct sprite pattern index for current UFO score
        ; n.b. Need to store it because sucessive bullets may progress the sequence
        ; before the sprite is displayed.
        ld hl,ufoScoreSpritePatternTable
        ld a,(ufoScoreSequenceIndex)
        add hl,a                                        ; HL = &patternIndexTable[index]
        ld a,(hl)                                       ; A <- patternIndex
        ld (ufoScoreSpritePatternIndex),a

        ; hijack ufoMoveCountdown for time to stay in this state
        ld a,UFO_EXPLOSION_DISPLAY_FRAME_COUNT
        ld (ufoMoveCountdown),a

        ; play sound effect
        ld a,SOUND_EFFECT_INDEX_UFO_DESTROYED
        ld b,SOUND_EFFECT_CHANNEL_UFO
        jp AyfxPlayEffect          ; jp instead of call xxxx : ret saves 1 byte and 17 T-states

updateInactiveUfo:

        IF UFO_ENABLED == 0
        ret
        ENDIF

        ; don't spawn if less than 8 invaders left alive
        ld a,(liveInvaderCount)
        cp UFO_MIN_INVADERS_TO_SPAWN    ; set flags from A-8
        ret c

        ; is it time to spawn?
        ld hl,(ufoSpawnCountdown)   ; HL = ufoCountdown (16-bit value)
        ld a,l
        or h                        ; set zero flag if HL == 0
        jp z,.spawn

        ; not time to spawn
        dec hl
        ld (ufoSpawnCountdown),hl
        ret

.spawn
        ; set ufo active
        ld a,UFO_STATE_ACTIVE
        ld (ufoState),a

        ; Position at either left or right of screen depending on ufoSpawnSide
        ld hl,ufoSprite         ; HL = &ufoSpriteAttributes.x
        ld a,(ufoSpawnSide)
        ld (ufoDirection),a     ; store direction of travel
        and a                   ; set Z flag if spawn on left hand side 
        ld a,UFO_X_MIN          ; assume spawn on left until find otherwise n.b. LD does not affect Z flag
        jp z,.setX              ; jump if should spawn on left
        ld a,UFO_X_MAX          ; spawn at right hand side
.setX   ld (hl),a
        
.y      inc hl                  ; HL = &ufoSpriteAttributes.y
        ld (hl),UFO_Y

        inc hl                  ; HL = &ufoSpriteAttributes.mrx8
        ld (hl),0

        ; set initial "speed" n.b. this is unsigned speed not signed velocity
        ld a,UFO_SPEED_FRAMES_PER_PIXEL
        ld (ufoMoveCountdown),a

        ; make sprite visible
        inc hl                  ; HL = &ufoSpriteAttributes.vpat
        ld (hl),SPRITE_ATTRIBUTE3_FLAG_VISIBLE|UFO_PATTERN_INDEX ; visible, no 5th attribute byte, sprite pattern
        
        call calculateUfoScreenSpaceHitbox        

        ; play sound effect
        ld a,SOUND_EFFECT_INDEX_UFO_SIREN
        ld b,SOUND_EFFECT_CHANNEL_UFO
        jp AyfxPlayEffectLooping          ; jp instead of call xxxx : ret saves 1 byte and 17 T-states

updateActiveUfo:

        ld a,(ufoMoveCountdown)
        dec a
        jp z,.move
        ; don't move
        ld (ufoMoveCountdown),a
        ret

.move   ld a,(ufoSprite+SpriteAttributes.x)      ; A = ufo x 
        ld hl,ufoDirection
        inc (hl)                ; set Z flag if ufoDirection == 0 in two steps ...
        dec (hl)                ; ... without modifying A
        jp nz,.movingLeft

.movingRight
        inc a
        ; Reached right hand side of screen?
        ASSERT UFO_X_MAX <= $ff ; need 16-bit arithmetic
        cp UFO_X_MAX                             ; A - UFO_X_MAX. Set Zero flag if A == UFO_X_MAX
        jr nz,.notFinished
        jp ResetUfo                              ; reached far right - reset

.movingLeft
        dec a
        cp UFO_X_MIN                            ; A - UFO_X_MIN. Set Zero flag if A == UFO_X_MIN
        jr nz,.notFinished
        jp ResetUfo                             ; reached far left - reset

.notFinished
        ld (ufoSprite+SpriteAttributes.x),a     ; store new sprite x pos

        ; restart move countdown
        ld a,UFO_SPEED_FRAMES_PER_PIXEL
        ld (ufoMoveCountdown),a

        jp calculateUfoScreenSpaceHitbox        ; jp instead of call xxxx : ret saves 1 byte and 17 T-states

calculateUfoScreenSpaceHitbox:
        ld ix,ufoSprite
        ld de,ufoHitboxPatternSpace
        ld hl,ufoHitboxScreenSpace
        jp CalculateSpriteScreenSpaceHitbox     ; jp instead of call xxxx : ret saves 1 byte and 17 T-states

updateExplodingUfo:

        ld a,(ufoMoveCountdown) ; this var is hijacked for time in this state
        dec a
        jp z,.showScore
        ; stay in this state for now
        ld (ufoMoveCountdown),a
        ret

.showScore
        ld a,UFO_STATE_SHOW_SCORE
        ld (ufoState),a

        ; hijack ufoMoveCountdown for time to stay in this state
        ld a,UFO_SCORE_DISPLAY_FRAME_COUNT
        ld (ufoMoveCountdown),a
        
        ; Show correct sprite for UFO value
        ld a,(ufoScoreSpritePatternIndex)
        or SPRITE_ATTRIBUTE3_FLAG_VISIBLE
        ld (ufoSprite+SpriteAttributes.vpat),a

        ret

updateShowScore:

        ld a,(ufoMoveCountdown) ; this var is hijacked for time in this state
        dec a
        jp z,ResetUfo
;       ; stay in this state for now
        ld (ufoMoveCountdown),a
        ret
;
; Set deltaScore value to be added to player's score later in the frame   
; Modifies: AF, DE, HL
;
SetDeltaScoreForUfo:

        ld hl,ufoScoreTable
        ld a,(ufoScoreSequenceIndex)
        add hl,a
        ld a,(hl)                       ; dereference pointer, A = scoreBCD/10 e.g. $12 meaning 120 decimal
        swapnib                         ; swap nibbles in accumulator e.g. $21
        ld b,a                          ; store full byte for later
        and $f0                         ; keep only upper nibble e.g. $20
        ld (deltaScoreBCD16),a          ; store deltaScore value LSB
        ld a,b                          ; A <- nibble-swapped value
        and $0f                         ; keep only lower nibble e.g. $01
        ld (deltaScoreBCD16+1),a        ; store deltaScore value MSB
        ret

AdvanceUfoScoreSequenceAndSpawnPos:

        ld hl,ufoSpawnSide
        ld a,(hl)
        xor 1                           ; invert (0 -> 1, 1 -> 0)
        ld (hl),a

        ; advance score sequence
        ld a,(ufoScoreSequenceIndex)
        inc a                          ; point DE at next element in table

        ; if passed end of table then wrap to start
        cp UFO_SCORE_SEQUENCE_COUNT
        jp nz,.end                      ; jump if haven't reached end of table
        xor a
.end    ld (ufoScoreSequenceIndex),a    ; store 
        ret
