
MAX_PLAYERS EQU 2
PLAYER_START_LIVES EQU 3

; Per player state that must persist between turns in a 2 player game
        STRUCT Player
scoreBCD16              DW $0000    ; BCD format (9999 max)  TODO: 4 byte value?
lives                   DB $00
levelIndex              DB $00      ; Zero-indexed i.e. 0 = first level
extraLifeAvailable      DB $00      ; non-zero = available. Only get one extra life per game
alive                   DB $00      ; set to zero when dead (lost last life). n.b. Can't just use lives, because player has 0 lives on last life
bulletsRemoved          DB $00      ; incremented when bullet removed from play. Used for UFO direction
invaderPackFlags        DB $00      ; INVADER_BIT_*
invaderToMoveIndex      DB $00      ; the index of the invader to move
liveInvaderCount        DB $00
shieldState             DB $00      ; bits 0-3 is shield active state i.e. set if not hit by invader
        ENDS

; data for 2 players
players
player1 DS Player
player2 DS Player

; Working per-player data
; Having a global copy of these variables simplifies complex routines when all registers are in use
invaderPackFlags        DB $00  ; INVADER_BIT_*.
invaderToMoveIndex      DB $00  ; the index of the invader to move 
liveInvaderCount        DB $00  ; the number of invaders alive
shieldState             DB $00  ; bits 0-3 set if shield 0-3 still intact (not hit by invader)


; Global state. NOT persistent per-player state
deltaScoreBCD16:    DW $0000    ; BCD format (9999 max)

;----------------------------------------------------------------------------------------

;
; HL = address of Player struct
; Modifies: AF, DE, HL
;
InitPlayerForNewGame:
        ASSERT Player.scoreBCD16 == 0 ; following code assumes this
        xor a                   ; A <- 0
        ld (hl),a               ; zero score LSB
        inc hl                  ; HL = address of score MSB
        ld (hl),a               ; zero score MSB

        ASSERT Player.lives == 2 ; following code assumes this
        inc hl                  ; HL = address of lives byte
        ld (hl),PLAYER_START_LIVES

        ASSERT Player.levelIndex == Player.lives + 1 ; following code assumes this
        inc hl                  ; HL = address of levelIndex byte
        ld (hl),0

        ASSERT Player.extraLifeAvailable == Player.levelIndex + 1 ; following code assumes this
        inc hl                  ; HL = address of extraLifeAvailable byte
        ld (hl),1               ; extra life is available
        
        ASSERT Player.alive == Player.extraLifeAvailable + 1 ; following code assumes this
        inc hl                  ; HL = address of alive byte
        ld (hl),1               ; alive = 1 

        ASSERT Player.bulletsRemoved == Player.alive + 1 ; following code assumes this
        inc hl                  ; HL = &player.bulletsRemoved
        ld (hl),0               ; player.bulletsRemoved <- 0

        ret
;
; Sets activePlayerIndex <- 0
; Sets pActivePlayer, pActiveInvaders and pActiveInvaderSprites pointers
; Copies player 1 data to working data
; Modifies A, HL
;
ActivatePlayer1:
        
        ld a,0                          ; A <- 0 (player 1 index) n.b. don't use xor a or sub a to maintain Z flag
        ld (activePlayerIndex),a        ; activePlayerIndex <- 0

        ld hl,player1                   ; HL = &player1
        ld (pActivePlayer),hl           ; pActivePlayer = &player1 

        ld hl,player1Invaders
        ld (pActiveInvaders),hl

        ld hl,player1invaderSprites
        ld (pActiveInvaderSprites),hl
        
        call copyActivePlayerDataToWorkingData

        ret

;
; Sets activePlayerIndex <- 1
; Sets pActivePlayer, pActiveInvaders and pActiveInvaderSprites pointers
; Copies player 2 data to working data
; Modifies A, HL
;
ActivatePlayer2:

        ld a,1                          ; A <- 1 (player 2 index)
        ld (activePlayerIndex),a        ; activePlayerIndex <- 1

        ld hl,player2                   ; HL <- &player1
        ld (pActivePlayer),hl           ; pActivePlayer = &player2

        ld hl,player2Invaders
        ld (pActiveInvaders),hl

        ld hl,player2invaderSprites
        ld (pActiveInvaderSprites),hl

        call copyActivePlayerDataToWorkingData

        ret

;
; Copies some per-player state to global working data to simplify code
; Modifies: AF, HL
;
copyActivePlayerDataToWorkingData:

        ld hl,(pActivePlayer)                   ; HL = pActivePlayer
        add hl,Player.invaderPackFlags          ; HL <- &activePlayer.invaderPackFlags
        ld a,(hl)
        ld (invaderPackFlags),a

        ASSERT Player.invaderPackFlags + 1 == Player.invaderToMoveIndex ; next instruction depends on this
        inc hl
        ld a,(hl)
        ld (invaderToMoveIndex),a

        ASSERT Player.invaderToMoveIndex + 1 == Player.liveInvaderCount ; next instruction depends on this
        inc hl
        ld a,(hl)
        ld (liveInvaderCount),a

        ASSERT Player.liveInvaderCount + 1 == Player.shieldState ; next instruction depends on this
        inc hl
        ld a,(hl)
        ld (shieldState),a

        ret

;
; Stores working data for the active player
; Call this in a 2 player game when a player dies to preserve their state for the next life.
; Modifies: AF, BC, DE, HL, IX, IY
;
StoreWorkingDataForActivePlayer:

        ld hl,(pActivePlayer)                   ; HL = pActivePlayer
        add hl,Player.invaderPackFlags          ; HL <- &activePlayer.invaderPackFlags
        ld a,(invaderPackFlags)
        ld (hl),a

        ASSERT Player.invaderPackFlags + 1 == Player.invaderToMoveIndex ; next instruction depends on this
        inc hl
        ld a,(invaderToMoveIndex)
        ld (hl),a

        ASSERT Player.invaderToMoveIndex + 1 == Player.liveInvaderCount ; next instruction depends on this
        inc hl
        ld a,(liveInvaderCount)
        ld (hl),a

        ASSERT Player.liveInvaderCount + 1 == Player.shieldState ; next instruction depends on this
        inc hl
        ld a,(shieldState)
        ld (hl),a

        ; store the active player's shield bitmap for next turn
        ld hl,player1ShieldBitmaps            ; assume player 1 until determine otherwise
        ld a,(activePlayerIndex)
        and a                           ; set zero flag if player 1 is active
        jp z,StoreShields
        ; player 2 is active
        ld hl,player2ShieldBitmaps
        jp StoreShields

;       ret


;
; If other player is alive then switch player
; Modifies: AF, HL
; Zero Flag <- reset if changed player, set if did not change player
;
ChangeActivePlayerIfOtherPlayerIsAlive:
        ; n.b. no need to check if it is a two player game because in 1 player game player 2 will not be active
        ld a,(activePlayerIndex)
        and a                           ; set zero flag if player 1 is active
        jr nz,.player2Active

        ; player 1 is active - we can switch to player 2 if they are alive
        ld a,(player2+Player.alive)     ; A = player2.alive
        and a                           ; set zero flag if player 2 is dead
        ret z                           ; player 2 is not active so can't switch
        call StoreWorkingDataForActivePlayer          ; store working data in player 1 struct for their next life
        call StopActivePlayerTextFlash
        call ActivatePlayer2            ; player 2 is still alive so change to player 2
        call DrawPlayer2Shields
        or 1                            ; reset zero flag as return value means changed player
        ret

.player2Active     
        ; player 2 is active - we can switch to player 1 if they are alive
        ld a,(player1+Player.alive)             ; A = player1.alive
        and a                                   ; set zero flag if player 1 is still alive
        ret z                                   ; player 1 is not active so can't switch
        call StoreWorkingDataForActivePlayer    ; store working data for player 2 for their next life
        call StopActivePlayerTextFlash
        call ActivatePlayer1                    ; player 1 is still alive so change to player 1
        call DrawPlayer1Shields
        or 1                                    ; reset zero flag as return value means changed player
        ret

;
; Adds deltaScoreBCD16 to active player score and resets deltaScoreBCD16  
; Modifies: AF, BC, DE, HL
;
UpdateScore:

        ld hl,deltaScoreBCD16
        ld a,(hl)                       ; A = deltaScore LSB
        ld d,a                          ; D = deltaScore LSB
        ld a,(deltaScoreBCD16+1)        ; A = deltaScore MSB
        or d                            ; set zero flag if both LSB and MSB are zero 
        ret z                           ; return if no score to add

        ld de,(pActivePlayer)           ; DE = &player[activePlayerIndex]
        add de,Player.scoreBCD16        ; DE = &player[activePlayerIndex].scoreBCD16
        call AddBCD16

        ; clear deltaScore (does not affect Carry Flag)
        ld hl,$0000
        ld (deltaScoreBCD16),hl

        jr nc,.extra             ; skip clamp if carry out of MSB from AddBCD16

        ; clamp to 9999
        ld a,$99
        ld hl,(pActivePlayer)            ; HL = &player[activePlayerIndex]
        add hl,Player.scoreBCD16        ; HL = &player[activePlayerIndex].scoreBCD16 (address of 16-bit score LSB)
        ld (hl),a
        inc hl
        ld (hl),a

.extra  ; extra life at 1500
        ld hl,(pActivePlayer)                    ; HL = &player[activePlayerIndex]
        add hl,Player.extraLifeAvailable        ; HL = &player[activePlayerIndex].extraLifeAvailable
        ld a,(hl)                               ; A <- extraLifeAvailable
        and a                                   ; set zero flag if not available
        jr z,.draw                              ; jump if extra life already awarded
        ; extra life not yet awarded
        ld hl,(pActivePlayer)                    ; HL = &player[activePlayerIndex]
        add hl,Player.scoreBCD16+1              ; HL = &player[activePlayerIndex].scoreBCD16 + 1 (MSB)
        ld a,(hl)                               ; A <- score BCD MSB e.g. $15 if score is $1500
        cp $15                                  ; score MSB - 15
        jr c,.draw                              ; jump if A < 15

        ; increment life count
        ld hl,(pActivePlayer)                   ; HL = &player[activePlayerIndex]
        add hl,Player.lives                     ; HL = &player[activePlayerIndex].lives
        inc (hl)
        call DrawActivePlayerLives              ; update graphics

        ; set extraLifeAvailable to zero
        ld hl,(pActivePlayer)                    ; HL = &player[activePlayerIndex]
        add hl,Player.extraLifeAvailable        ; HL = &player[activePlayerIndex].extraLifeAvailable
        xor a                                   ; A <- 0
        ld (hl),a                               ; player[activePlayerIndex].extraLifeAvailable <- 0

        ; play sound effect
        ld a,SOUND_EFFECT_INDEX_EXTRA_LIFE
        ld b,SOUND_EFFECT_CHANNEL_EXTRA_LIFE
        call AyfxPlayEffect

        ; update score ULA graphics as required rather than every frame
.draw   call DrawActivePlayerScore
        ret

;
; This is called once when all players are dead.
; Updates the high score if either player score exceeds it.
;
UpdateHighScore:

        ; highScore = max(highScore, player1.score)
        ld de,(player1+Player.scoreBCD16)       ; DE = player 1 score
        call updateHighScore

        ; return if one player game
        ld a,(twoPlayerGame)
        and a                                   ; set Zero Flag if one player game
        ret z                                   ; return if 1 player game

        ; highScore = max(highScore, player2.score)
        ld de,(player2+Player.scoreBCD16)       ; DE = player 2 score
        call updateHighScore  

        ret

;
; DE = address of Player.scoreBCD16
; Modifies: AF, HL
;
updateHighScore:
        ld hl,(highScoreBCD16)                  ; HL = highScore
        and a                                   ; clear carry for SBC: HL = HL-DE-CY
        sbc hl,de                               ; HL = highscore - score, sets CY if score > highScore
        ret nc                                  ; return if score <= highScore
        ld a,e                                  ; A = score LSB
        ld (highScoreBCD16),a                   ; store new high score LSB
        ld a,d                                  ; A = score MSB
        ld (highScoreBCD16+1),a                 ; store new high score MSB
        ret
