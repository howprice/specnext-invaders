
INVADER_MOVEMENT_ENABLED EQU 1  ; allow invader movement to be disabled for debugging

INVADER_TYPE_COUNT      EQU 3

INVADER_ROW_COUNT       EQU 5
INVADER_COLUMN_COUNT    EQU 11
INVADER_COUNT           EQU INVADER_ROW_COUNT * INVADER_COLUMN_COUNT
INVALID_INVADER_INDEX   EQU $FF
        ASSERT INVADER_COUNT < INVALID_INVADER_INDEX

; Invader movement range
; Sprite pattern data is 16x16 but widest invader data is inset is inset horizontally by 2 pixels
INVADER_X_MIN           EQU 32 + 16 + 2             ; border + 16 - 2 
INVADER_X_MAX           EQU 32 + 256 - 16 - 32 - 2  ; border + ULA width - sprite width - 32 + 2 

; $40 is about right for the first stage
; $60 is about as low as looks sensible. Maybe $70 at a push.
INVADER_START_Y EQU $40

INVADER_BULLET_COUNT    EQU 3 ; squiggly, plunger, rolling

; invader pack flags
INVADER_BIT_MOVING_LEFT EQU     0       ; reset = right, set = left
INVADER_BIT_CHANGE_DIR  EQU     1       ; if set then invaders should change direction after the entire pack has completed the step
INVADER_BIT_FRAME       EQU     2       ; invaders have two frames of animation  
INVADER_BIT_MOVE_DOWN   EQU     3       ; if set moves invader down by 8 pixels when it next moves

; TODO: Add column and row index?
        STRUCT Invader
active                  BYTE
type                    BYTE
pSpriteAttributes       WORD    ; address of sprite attributes (position, pattern, visibility)
hitboxScreenSpace       Hitbox
        ENDS

; See invader pattern data
; Constant data, but no way to make it constant in assembly language.
; TODO: Could derive these from the pattern data
                                ;        x0  x1  y0  y1
invaderHitboxesPatternSpace     Hitbox $2, $d, $0, $7  ; invader A (type 0)
                                Hitbox $3, $d, $0, $7  ; invader B (type 1)
                                Hitbox $4, $b, $0, $7  ; invader C (type 2)
        ASSERT $-invaderHitboxesPatternSpace == (INVADER_TYPE_COUNT * Hitbox)

; array of invaders per player
player1Invaders DS INVADER_COUNT * Invader
player2Invaders DS INVADER_COUNT * Invader
pActiveInvaders DW $0000                        ; pointer to active invaders (address of player1Invaders or player2Invaders)

; maps row index to invader type index LUT, where row 0 is bottom row and row INVADER_ROW_COUNT-1 is the top row
rowIndexToInvaderType DB $00, $01, $01, $02, $02 
        ASSERT ($ - rowIndexToInvaderType) == INVADER_ROW_COUNT

invaderTypeToScoreBCD DB $10, $20, $30
        ASSERT ($ - invaderTypeToScoreBCD) == INVADER_TYPE_COUNT
        
;-------------------------------------------------------------------------------------------------------------------

;
; Call once on boot
; 
InitInvaders:

        ; init player 1's invaders
        ld hl,player1Invaders
        call setInvaderTypes

        ld hl,player1Invaders
        ld de,player1invaderSprites
        call setInvaderSpriteAttributePointers
       
        ; init player 2's invaders
        ld hl,player2Invaders
        call setInvaderTypes

        ld hl,player2Invaders
        ld de,player2invaderSprites
        call setInvaderSpriteAttributePointers
       
        ret
;
; Set the active state for all invaders
; HL = address of invaders
; Modifies: AF, HL, B
;
SetAllInvadersActive:
        add hl,Invader.active                   ; HL += offsetof(Invader.active)
        ld b,INVADER_COUNT
        ld a,1                                  ; 1 == active
.loop   ld (hl),a
        add hl,Invader                          ; HL += sizeof(Invader) i.e next invader
        djnz .loop
        ret

;
; Sets the type index for each invader
; HL = address of invaders
; Modifies: AF, BC, DE, HL
; n.b. invaders are indexed 0 bottom-left scanning right then up to top-right
;
setInvaderTypes:
        ; set type for each invader
        add hl,Invader.type                     ; HL = &invaders[0].type
        ld de,rowIndexToInvaderType             ; DE = &rowIndexToInvaderType[0]
        ld b,0                                  ; B = rowIndex
.y      ; look up invader type for this row
        push hl                                 ; push &invaders[i].type
        ld h,d                                  ; fake instruction: ld hl,de
        ld l,e                                  ; ...
        ld c,(hl)                               ; C <- invaderTypeIndex
        pop hl                                  ; HL = &invaders[i].type

        push bc                                 ; push rowIndex
        ld b,INVADER_COLUMN_COUNT
.x      ld (hl),c                               ; invaders[i].type = invaderTypeIndex
        add hl,Invader                          ; HL += sizeof(Invader) i.e next invader
        djnz .x

        ; next row
        inc de                                  ; DE <- address of next rowIndexToInvaderType element 
        pop bc                                  ; B <- rowIndex
        inc b                                   ; rowIndex++
        ld a,b                                  ; A <- rowIndex
        cp INVADER_ROW_COUNT                    ; Set Z flag from rowIndex - INVADER_ROW_COUNT
        jr nz,.y

        ret

;
; HL = address of invaders
; DE = address of invader sprites
;
setInvaderSpriteAttributePointers:
        add hl,Invader.pSpriteAttributes        ; HL = &invaders[0].pSpriteAttributes
        ld b,INVADER_COUNT
.loop   ld (hl),e                               ; store LSB
        inc hl
        ld (hl),d                               ; store MSB
        add hl,Invader-1                        ; HL += sizeof(Invader) - 1 i.e HL = &invaders[i+1].pSpriteAttributes
        ex de,hl                                ; HL =  &invaderSprites[i]  DE = &invaders[i+1].pSpriteAttributes
        add hl,SpriteAttributes                 ; HL += sizeof(SpriteAttributes)  HL = &invaderSprites[i+1]
        ex de,hl                                ; HL = &invaders[i+1].pSpriteAttributes  DE = &invaderSprites[i+1]
        djnz .loop
        ret

;
; HL = address of Invader
; Modifies AF, B, DE, HL
;
calculateInvaderScreenSpaceHitbox:

        ; DE = address of pattern-space hitbox
        ASSERT Invader.type == 1                ; next line assumes this
        inc hl                                  ; HL = &invader.type
        ld e,(hl)                               ; E = invader type index [0,2]
        push hl                                 ; push &invader.type
        ld hl,invaderHitboxesPatternSpace       ; HL = &invaderHitboxesPatternSpace[0]
        ld d,Hitbox                             ; D = sizeof(Hitbox)
        mul d,e                                 ; DE = sizeof(Hitbox) * type
        add hl,de                               ; HL = &invaderHitboxesPatternSpace[type]
        ex de,hl                                ; DE = &invaderHitboxesPatternSpace[type]
        pop hl                                  ; HL = &invader.type

        ; IX = address of sprite attributes struct
        ; n.b ld ixl,(hl) : ld ixh,(hl) are illegal instructions, so load into DE as intermediate
        push de                                 ; push &invaderHitboxPatternSpace
        
        ASSERT Invader.pSpriteAttributes == 2   ; next lines assumes this
        inc hl                                  ; HL = &invader.pSpriteAttributes
        ld e,(hl)                               ; E = LSB of address 
        inc hl                                  ; &invader.pSpriteAttributes + 1
        ld d,(hl)                               ; D = MSB of address -> DE = &spriteAttributes
        ld ixh,d                                ; fake instruction: ld ix,de
        ld ixl,e                                ; ... IX <- invader.pSpriteAttributes

        pop de                                  ; DE = &invaderHitboxPatternSpace

        ; HL = address of screen-space hitbox
        ASSERT Invader.hitboxScreenSpace == 4   ; next lines assumes this
        inc hl
        call CalculateSpriteScreenSpaceHitbox

        ret

;
; HL = address of invaders
; Modifies: F, B, HL
;
calculateAllInvaderScreenSpaceHitboxes:

        ld b,INVADER_COUNT
.loop   push bc
        push hl
        call calculateInvaderScreenSpaceHitbox
        pop hl
        pop bc
        add hl,Invader                          ; HL += sizeof(Invader)
        djnz .loop
        ret

;
; Gets the animated pattern index for an invader of a given type
; A = invader type index [0,2]
; A <- pattern index
; Modifies: A, C
;
getInvaderPatternIndex:
        ld c,INVADER_A_FRAME0_PATTERN_INDEX     ; C = invader type 0 pattern index
        cp 0
        jr z,.frameOffset

        ld c,INVADER_B_FRAME0_PATTERN_INDEX 
        cp 1
        jr z,.frameOffset

        ld c,INVADER_C_FRAME0_PATTERN_INDEX

.frameOffset
        ld a,(invaderPackFlags)
        bit INVADER_BIT_FRAME,a
        ld a,c                          ; A <- pattern index (frame 0)
        ret z
        inc a                           ; A <- pattern index (frame 1)
        ret

;
; Sets initial invader sprite attributes: position, patterns and visibility
; n.b. invaders are indexed 0 bottom-left scanning right then up to top-right
; HL = address of invaders
; Modifies: AF, BC, DE, HL, IX
;
SetInitialInvaderPackState:        

        push hl
        call SetAllInvadersActive
        pop hl

        push hl
        call spawnAllInvaders_setSpriteAttributes
        pop hl

        call calculateAllInvaderScreenSpaceHitboxes
        
        ; initialise working invader state
        ld a,INVADER_COUNT                      ; A <- 55 (5 rows of 11 invaders)
        ld (liveInvaderCount),a                 ; liveInvaderCount <- INVADER_COUNT
        xor a                                   ; A <- 0
        ld (invaderToMoveIndex),a               ; Move invader 0 first (bottom left)
        ld (invaderPackFlags),a                 ; clear invader flags (move right, don't change dir)
        ret

;
; SpawnAllInvaders helper to set all sprite attributes: position, pattern and visibility 
; HL = address of invaders
; Modifies: AF, BC, DE, HL, IX
;
spawnAllInvaders_setSpriteAttributes:

        ; Start invaders 8 pixels lower per level, wrapping at level 8
        ld ix,(pActivePlayer)                   ; IX <- &player[activePlayerIndex]
        ld a,(ix+Player.levelIndex)             ; A <- activePlayer.levelIndex
        and $7                                  ; wrap at level 8 
        sla a                                   ; A = 2 * levelIndex 
        sla a                                   ; A = 4 * levelIndex
        sla a                                   ; A = 8 * levelIndex
        
        add a,INVADER_START_Y+16*(INVADER_ROW_COUNT-1) ; A = y position of first row (bottom row)
        ld e,a       

        ld b,INVADER_ROW_COUNT                  ; B = row loop count
.y      ld d,32 + 16                            ; D = x position of left-most invader = border + 16
        push bc                                 ; push row loop count
        ld b,INVADER_COLUMN_COUNT               ; B = column loop count
.x      push hl                                 ; push &invaders[i]
        add hl,Invader.type
        ld c,(hl)                               ; C <- invaderTypeIndex
        ASSERT Invader.type + 1 == Invader.pSpriteAttributes ; next instruction depends on this
        inc hl                                  ; HL = &invaders[i].pSpriteAttributes
        ; HL contains the address of a word containing the address of SpriteAttributes
        ; Dereference pointer to set HL to address of SpriteAttributes
        ld a,(hl)                               ; A <- LSB
        inc hl
        ld h,(hl)                               ; H <- MSB
        ld l,a                                  ; HL = &spriteAttributes

        ; Set Sprite Attributes
        ld (hl),d                               ; Sprite Attribute 0 - lower 8 bits of x position
        inc hl
        ld (hl),e                               ; Sprite Attribute 1 lower 8 bits of y position
        inc hl                                  ; 
        ld (hl),0                               ; Sprite Attribute 2 - no rotation or mirroring
        inc hl

        ; Sprite Attribute 3: visible, no 5th attribute byte, sprite pattern for this row
        ld a,c                                  ; A = invader type index [0,2]
        call getInvaderPatternIndex             ; A <- pattern index
        or SPRITE_ATTRIBUTE3_FLAG_VISIBLE
        ld (hl),a 

        ; next invader
        pop hl                                  ; HL <- &invaders[i]
        add hl,Invader                          ; HL += sizeof(Invader) i.e. HL <= &invaders[i+1].pSpriteAttributes

        ; calculate x position of next invader to the right
        ld a,d
        add a,16                                ; x += horizontal spacing
        ld d,a

        djnz .x                                 ; next column

        ; calculate y position of next row up
        ld a,e                                  ; A <- y position of current row
        sub a,16                                ; y -= dy
        ld e,a                                  ; E = y position of next row down

        pop bc                                  ; B = row loop count
        djnz .y                                 ; next row
        ret

;
; Only one invader moves every frame
;
MoveInvader:

        IF INVADER_MOVEMENT_ENABLED == 0
        ret
        ENDIF

        ; HL <- selected invader sprite address
        ld a,(invaderToMoveIndex)       ; A = element index (can't load from memory directly into D)
.start  ld hl,(pActiveInvaders)         ; HL = &invaders[0]
        ld d,a                          ; D = element index
        ld e,Invader                    ; E = sizeof(Invader)
        mul d,e                         ; DE <- D * E = offset of invader[i] (Z80N opcode)
        add hl,de                       ; HL = &invaders[i]

        ; The selected invader may have been destroyed since it was selected
        ; Keep iterating through invaders until a live one is found
        ASSERT Invader.active == 0 ; assume HL pointing at this member
        inc (hl)                                ; set Zero flag if value at address in HL is zero...
        dec (hl)                                ; ... in two steps (but 22 T-states!)
        jp nz,.updateInvader                    ; live invader - update it
        inc a                                   ; next invader
        cp INVADER_COUNT                        ; passed end of array?
        jp nz,.start                            ; no - try again with this invader
        xor a                                   ; A <- 0 wrap around to start of array

        ; when all invaders have been moved change direction if required
        push af                                 ; push index
        call postInvaderPackUpdate
        pop af                                  ; pop index

        jp .start                               ; try again with first invader

.updateInvader
        ld (invaderToMoveIndex),a               ; store index of invader being moved
        push hl                                 ; push &invader

        ; set IX to point to invader's Sprite Attributes
        ASSERT Invader.active + 2 == Invader.pSpriteAttributes ; next two instructions assume this
        inc hl
        inc hl
        ; HL contains the address of a word containing the address of SpriteAttributes
        ; Dereference pointer to set HL to address of SpriteAttributes
        ld a,(hl)                               ; A <- LSB
        inc hl
        ld h,(hl)                               ; H <- MSB
        ld l,a                                  ; HL = &spriteAttributes

        push hl                                 ; fake instruction: ld ix,hl
        pop ix                                  ; ...

        ld l,(ix+SpriteAttributes.x)            ; L = lower 8 bits of x position
        ld h,(ix+SpriteAttributes.mrx8)         ; H = MSb of x position
 
        ; change direction if:
        ; - moving right and at rightmost extent 
        ; - moving left and at leftmost extent 
        ld a,(invaderPackFlags)                 ; A = move dir  0 = right, 1 = left
        bit INVADER_BIT_MOVING_LEFT,a           ; set Z flag if A is zero (moving right)
        jp nz,.movingLeft
.movingRight
        push hl                                 ; push x pos
        ld de,INVADER_X_MAX
        and a                   ; clear carry flag for following 16-bit SBC instruction (there is no 16-bit SUB HL,DE)
        sbc hl,de               ; HL -= (DE+CF) sets carry flag, whereas DEC HL does not. n.b. there is no SUB HL,DE instruction!
        pop hl                  ; pop x pos
        jp z,.changeDir
        jp .move
.movingLeft
        push hl                 ; push x pos
        ld de,INVADER_X_MIN
        and a                   ; clear carry flag for following 16-bit SBC instruction (there is no 16-bit SUB HL,DE)
        sbc hl,de               ; HL -= (DE+CF) sets carry flag, whereas DEC HL does not. n.b. there is no SUB HL,DE instruction!
        pop hl                  ; pop x pos
        jp nz,.move
.changeDir
        ld a,(invaderPackFlags)
        set INVADER_BIT_CHANGE_DIR,a
        ld (invaderPackFlags),a
.move   bit INVADER_BIT_MOVING_LEFT,a
        jp nz,.moveLeft
.moveRight
        ; move invaders 2 pixels each step
        inc hl  ; x++
        inc hl  ; x++
        jp .setX
.moveLeft
        ; move invaders 2 pixels each step
        dec hl  ; x--
        dec hl  ; x--
.setX   ; set x LSB
        ld (ix+SpriteAttributes.x),l    ; set 8 least significant bits of x

        ; set x MSb
        ld a,h  ; A = 4th sprite attribute byte
        and $1  ; A = MSb of x pos
        ld (ix+SpriteAttributes.mrx8),a 

.maybeMoveDown
        ld a,(invaderPackFlags)
        bit INVADER_BIT_MOVE_DOWN,a
        jp z,.updateHitbox

        ; move down
        ld a,(ix+SpriteAttributes.y)
        add $8                                 ; n.b. no need to clamp to max Y because if invader reach ship-level the it's game over
        ld (ix+SpriteAttributes.y),a

        ; check if have been "invaded"
        cp SHIP_Y                               ; invaderY - shipY   sets carry flag if invaderY < shipY (not invaded); no carry if invaderY >= shipY (invaded
        jp c,.updateHitbox                      ; jump ahead if not invaded
        ld (invaded),a                          ; set invaded to non-zero value

.updateHitbox
        pop hl                                  ; HL = &invader
        push hl                                 ; push &invader (modified by call)
        call calculateInvaderScreenSpaceHitbox
        pop hl                                  ; HL = &invader

        push hl
        call CollideInvaderWithShields
        pop hl

        ; update pattern
        ; Set Sprite Attribute 3: visible, no 5th attribute byte, sprite pattern for this row
        ASSERT Invader.type == 1                ; next instruction assumes this
        inc hl                                  ; HL = &invader.type
        ld a,(hl)                               ; A = invader type index [0,2]
        call getInvaderPatternIndex             ; A <- pattern index
        or SPRITE_ATTRIBUTE3_FLAG_VISIBLE       ; OR sprite visibility bit into A
        ld (ix+SpriteAttributes.vpat),a 

        ; select next invader index, wrapping back to start
        ; it doesn't matter at this point if the invader is dead or alive
        ld a,(invaderToMoveIndex)
        inc a                                   ; next invader
        cp INVADER_COUNT                        ; passed end of array?
        jp nz,.end

        xor a                                   ; A <- 0 wrap around to start of array
        ; when all invaders have been moved change direction if required
        push af                                 ; push index
        call postInvaderPackUpdate
        pop af                                  ; pop index
.end    ld (invaderToMoveIndex),a
        ret

;
; Called when all of the invaders in the pack have moved
; modifies af, b
; 
postInvaderPackUpdate

        ld a,(invaderPackFlags)                 ; A <- invaderFlags
        res INVADER_BIT_MOVE_DOWN,a             ; if the pack moving down last update then don't this time round

        ; if INVADER_BIT_CHANGE_DIR is set then:
        ;   1. Change horizontal direction
        ;   2. Set flag to move invaders down for duration of next pack update
        bit INVADER_BIT_CHANGE_DIR,a            ; want to change dir?
        jr z,.nextFrame                         ; no? branch
        ; change direction in x
        res INVADER_BIT_CHANGE_DIR,a            ; clear change dir bit
        xor 1<<INVADER_BIT_MOVING_LEFT          ; invert direction bit in A
        set INVADER_BIT_MOVE_DOWN,a             ; move down for next pack update

        ; animate pattern
.nextFrame
        xor 1<<INVADER_BIT_FRAME                ; next frame

        ld (invaderPackFlags),a                 ; store

        ret

;
; Selects an invader to drop a given bullet
;
; IX = address of InvaderBullet struct
; A <- invader index, or INVALID_INVADER_INDEX if no suitable invader was found
; Modifies: af, bc, de, hl
;
getInvaderToDropBullet:
        
        ; is it a targetted bullet?
        ld a,(ix+InvaderBullet.sequenceIndex)
        cp $ff
        jp z,.columnNearestShip

        ; get next column in the sequence
        ld d,0                                          ; extend 8-bit sequence index in A to 16-bit value in DE
        ld e,a                                          ; ...
        ld l,(ix+InvaderBullet.pColumnSequence)       ; fake instruction: ld hl,(ix+S_INVADER_BULLET.columnSequence)
        ld h,(ix+InvaderBullet.pColumnSequence+1)     ; MSB
        add hl,de                                       ; HL <- &sequence[sequenceIndex]
        ld h,(hl)                                       ; H <- columnIndex
        inc a                                           ; sequenceIndex++
        ld b,(ix+InvaderBullet.sequenceLength)
        cp b                                            ; end of array?
        jr nz,.storeSequenceIndex
        ld a,0                                          ; loop back to start sequenceIndex <- 0
.storeSequenceIndex 
        ld (ix+InvaderBullet.sequenceIndex),a        ; store sequenceIndex

        ld a,h                                          ; A <- columnIndex for call to findLowestLiveInvaderInColumn
        call findLowestLiveInvaderInColumn              ; A <- invader index
        ret

.columnNearestShip
        push ix
        call findClosestInvaderColumnToShip             ; A <- column index
        call findLowestLiveInvaderInColumn              ; A <- invader index
        pop ix
        ret


;
; A = column index (in)
; A <- invader index, or INVALID_INVADER_INDEX if no invader found
; Modifies: af, bc, hl
;
findLowestLiveInvaderInColumn:
        ; Invaders are ordered bottom-left to top-right, so just need to find the first live invader in the column.
        ld c,a                          ; C <- desired column index
        ld hl,(pActiveInvaderSprites)   ; HL = &invaderSprites[activePlayerIndex][0]
        add hl,SpriteAttributes.vpat    ; HL = &invaderSprites[activePlayerIndex][0].vpat (4th attribute byde)
        ld a,0                          ; A = current column index
        ld b,INVADER_COUNT
.loop   bit SPRITE_ATTRIBUTE3_BIT_VISIBLE,(hl)
        jr z,.next              ; jump if invader not visible
        ; invader is alive
        cp c                    ; correct column?
        jr nz,.next             ; no? next
        ; column is correct, this is the invader we want
        ld a,INVADER_COUNT      ; a = N - b
        sub b                   ; 
        ret

.next   inc a
        cp INVADER_COLUMN_COUNT
        jr nz,.a
        xor a                   ; A <- 0
.a      add hl,SpriteAttributes ; next sprite's 4th attribute 
        djnz .loop

        ; failed to find a live invader in the desired column
        ld a,INVALID_INVADER_INDEX
        ret

;
; A <- column index
; Modifies: AF, BC, DE, HL, IX
;
findClosestInvaderColumnToShip:

        ; loop over all live invaders
        ld a,(liveInvaderCount)
        ld b,a
.start
        ld hl,shipSprite+SpriteAttributes.x     ; HL = address of ship x pos
        ld ix,(pActiveInvaderSprites)           ; IX <- address of first invader sprite attribute
        ld c,$0                                 ; column index
        
        ld a,INVADER_COLUMN_COUNT-1
        ld (closestColumnIndex),a
        ld a,$ff
        ld (closestColumnDistance),a

.loop   bit SPRITE_ATTRIBUTE3_BIT_VISIBLE,(ix+SpriteAttributes.vpat)
        jr z,.nextInvader                       ; jump if invader is dead

        dec b                           ; decrement loop count because this invader is alive
        ; invader is alive; is this one closer?
        ld a,(closestColumnDistance)
        ld e,a                          ; E <- closestColumnDistance
        ld a,(ix+SpriteAttributes.x)    ; A <- invaderX
        cp (hl)                         ; invaderX - shipX
        jr c,.invaderToLeftOfShip       ; jump if shipX > invaderX
        ; invaderX >= shipX
        sub (hl)                        ; A <- invaderX - shipX = abs(deltaX)
        jr .compare
.invaderToLeftOfShip
        ; invaderX < shipX
        ld a,(hl)                       ; A <- shipX
        ld d,(ix+SpriteAttributes.x)    ; D <- invaderX
        sub d                           ; A <- shipX - invaderX
.compare ; A = abs(shipX - invaderX)
        ; TODO: Add deltaY

        cp e                            ; set flags from deltaX - closestDeltaX
        jr nc,.nextInvader              ; if deltaX >= closestDeltaX then skip to next invader
        ; deltaX < closestDeltaX i.e. this invader is closer
        ld (closestColumnDistance),a    ; store closest distance
        ; store closest column index
        ld a,c                          ; A <- closestColumnIndex
        ld (closestColumnIndex),a      

.nextInvader
        inc c                                   ; columnIndex++
        ld a,c                                  ; A <- columnIndex
        cp INVADER_COLUMN_COUNT                 ; passed last column?
        jr nz,.nextSprite                       ; jump if not
        ld c,0                                  ; columnIndex <- 0
.nextSprite
        ld de,SpriteAttributes                  ; next invader sprite
        add ix,de                               ; ...
        ld a,b                                  ; A <- loop counter
        and a                                   ; set zero flag if zero
        jr nz,.loop

        ; finished looping over all invaders
        ; return column index in A
        ld a,(closestColumnIndex)
        ret

; 
; HL = address of Invader
; Modifies: BC, DE, HL
; 
DestroyInvader:

        ; clear active flag
        ASSERT Invader.active == 0 ; following instruction depends on this
        ld (hl),0

        ; hide invader sprite
        ASSERT Invader.pSpriteAttributes == 2 ; following instructions depends on this
        inc hl
        inc hl                                          ; HL <- &invader.pSpriteAttributes
        ld e,(hl)                                       ; E = LSB of pSpriteAttributes 
        inc hl
        ld d,(hl)                                       ; D = MSB of pSpriteAttributes
        ex de,hl                                        ; HL = address of sprite attributes

        ; copy the first 3 Sprite Attribute bytes from the Invader to the Explosion
        ; this leaves HL pointing to the invaders 4th attribute byte
        ld bc,3
        ld de,explosionSprite
        ldir

        ; hide invader sprite
        res SPRITE_ATTRIBUTE3_BIT_VISIBLE,(hl)          ; hide sprite

        ; show explosion sprite and set pattern
        ex de,hl        ; HL <- &explosion.spriteAttribute[3]
        ld (hl),SPRITE_ATTRIBUTE3_FLAG_VISIBLE|INVADER_EXPLODING_PATTERN_INDEX

        ; Set explosion countdown to 16 frames
        ld a,EXPLOSION_DISPLAY_TIME_FRAMES
        ld (explosionCountdown),a
        ret

closestColumnIndex     DB INVADER_COLUMN_COUNT-1   ; default to last column
closestColumnDistance  DB $ff ; absolute distance to closest invader

;
; Set deltaScore value to be added to player's score later in the frame   
; HL = address of invader
; Modifies: AF, DE, HL
;
SetDeltaScoreForInvader:

        ASSERT Invader.type == 1        ; next instruction depends on this
        inc hl                          ; HL = &invader.type
        ld a,(hl)                       ; A = invaderType (array element index)
        ld hl,invaderTypeToScoreBCD     ; HL = &scoreArray[0]
        add hl,a                        ; HL = &scoreArray[type]
        ld e,(hl)                       ; E = score LSB
        ld d,0                          ; D = score MSB, DE = delta score in BCD
        ld (deltaScoreBCD16),de         ; set deltaScore value

        ret

