
GAME_STATE_MAIN_MENU            EQU     0
GAME_STATE_READY_PLAYER         EQU     1
GAME_STATE_SPAWNING_SHIP        EQU     2
GAME_STATE_PLAYING              EQU     3
GAME_STATE_LEVEL_COMPLETE       EQU     4
GAME_STATE_DESTROYED            EQU     5
GAME_STATE_GAME_OVER_PLAYER     EQU     6
GAME_STATE_GAME_OVER            EQU     7
GAME_STATE_COUNT                EQU     8       ; This must always be last

gameState DB $00  ; GAME_STATE_...

frameCount8 DB $00      ; incremented by 1 each frame, for simple flashing text etc

; 16-bit frames-in-state counter
; max value = 2^16 = 65536 frames = 1092 seconds (at 60Hz) = 18 minutes
; TODO: Extend to 32-bits iff required e.g. if used during play, and player is setting a world record!
framesInState16         DW      $0000   

activePlayerIndex       DB $00      ; 0 = player 1, 1 = player 2
pActivePlayer           DW $0000    ; Address of active Player struct
twoPlayerGame           DB $00      ; 0 = 1 player game, 1 = 2 player game
invaded                 DB $00      ; non zero means the invaders have "invaded" earth by reaching the bottom. Game Over!
destroyed               DB $00      ; non-zero means destroyed (hit by invader bullet)

highScoreBCD16          DW $0000    ; BCD format (9999 max)  TODO: 4 byte value?
HIGH_SCORE_SIZE_BYTES EQU $-highScoreBCD16

;-------------------------------------------------------------------------------------------------------------------

InitGame:

        call InitSprites
        SHOW_SPRITES
       
        call DrawScoreHeader    ; only needs to be called once - never gets cleared

        call InitInvaders

        ld a,GAME_STATE_MAIN_MENU
        jp EnterGameState

;
; Table of addresses (16-bit) for each game state update routine
; n.b. Entries in this table *can* be null
;
enterGameStateJumpTable:
        DW EnterMainMenu                ; GAME_STATE_MAIN_MENU
        DW EnterReadyPlayer             ; GAME_STATE_READY_PLAYER
        DW EnterSpawningShip            ; GAME_STATE_SPAWNING_SHIP
        DW EnterPlaying                 ; GAME_STATE_PLAYING
        DW EnterLevelComplete           ; GAME_STATE_LEVEL_COMPLETE
        DW EnterDestroyed               ; GAME_STATE_DESTROYED
        DW EnterGameOverPlayer          ; GAME_STATE_GAME_OVER_PLAYER
        DW EnterGameOver                ; GAME_STATE_GAME_OVER
        ASSERT ($ - enterGameStateJumpTable) == (2 * GAME_STATE_COUNT); incorrect number of entries in jump table

;
; Table of addresses (16-bit) for each game state update routine
; n.b. Entries in this table can *not* be null
;
updateGameStateJumpTable:
        DW UpdateMainMenu               ; GAME_STATE_MAIN_MENU
        DW UpdateReadyPlayer            ; GAME_STATE_READY_PLAYER
        DW UpdateSpawningShip           ; GAME_STATE_SPAWNING_SHIP
        DW UpdatePlaying                ; GAME_STATE_PLAYING
        DW UpdateLevelComplete          ; GAME_STATE_LEVEL_COMPLETE
        DW UpdateDestroyed              ; GAME_STATE_DESTROYED
        DW UpdateGameOverPlayer         ; GAME_STATE_GAME_OVER_PLAYER
        DW UpdateGameOver               ; GAME_STATE_GAME_OVER
        ASSERT ($ - updateGameStateJumpTable) == (2 * GAME_STATE_COUNT); incorrect number of entries in jump table

;
; Sets gameState value and calls associated routine from enterGameStateJumpTable
; A = game state e.g. GAME_STATE_GAME_OVER
;
EnterGameState:

;       ASSERT a < GAME_STATE_COUNT
        ld (gameState),a

        ; clear frames in state counter
        ld hl,$0000
        ld (framesInState16),hl

        ; jump to address in enterGameStateJumpTable
        ; n.b. NULL pointers in the LUT are allowed
        ld hl,enterGameStateJumpTable
        add a,a         ; double index for 2-byte entries
        ld e,a          ; copy 8-bit index into 16-bit DE register pair
        ld d,0
        add hl,de       ; calculate address of element
        ld e,(hl)       ; fetch address from the element
        inc hl
        ld d,(hl)

        ; if DE is zero then function pointer is null so return
        ld a,d
        or e            ; set Z flag if DE is zero
        ret z

        ex de,hl
        jp (hl)
;       ret             ; this RET instruction is redundant; the calling code will return

UpdateGameState:

        ; jump to address in updateGameStateJumpTable
        ; n.b. NULL pointers in the LUT are NOT allowed
        ld a,(gameState)
        ld hl,updateGameStateJumpTable
        add a,a         ; double index for 2-byte entries
        ld e,a          ; copy 8-bit index into 16-bit DE register pair
        ld d,0
        add hl,de       ; calculate address of element
        ld a,(hl)       ; fetch address from the element
        inc hl
        ld h,(hl)
        ld l,a
;       ASSERT hl != $0000
        jp (hl)
        ret             ; this RET instruction is redundant; the calling code will return

;---------------------------------------------------------------------------------------------------

EnterMainMenu:
        call HideAllSprites     ; hide sprites from last game
        call DrawMainMenu
        ret

UpdateMainMenu:

        ; Start 1 or 2 player game
        ld a,(inputPressed)
        bit INPUT_BIT_PLAYER_1_START,a
        jr nz,.startOnePlayer
        bit INPUT_BIT_PLAYER_2_START,a
        jr nz,.startTwoPlayer
        
        ; soft reset if Q pressed
        ; n.b. Not implemented on CSpect https://wiki.specnext.dev/CSpect:known_bugs
        bit INPUT_BIT_UP,a      ; mapped to Q for Quit too
        ret z
        nextreg NEXTREG_RESET,1 ; soft reset

        ret

.startOnePlayer

        call ClearULAPlayAreaPixels     ; remove the main menu text

        ld hl,player1                   ; HL = &players[0]
        call InitPlayerForNewGame

        call ActivatePlayer1
        ld hl,player1Invaders
        call SetInitialInvaderPackState

        call RestoreFullShields

        call ClearULAScoreAreaPixels
        call DrawPlayer1Score
        call DrawPlayer1Lives
        call DrawHighScore

        xor a                           ; A <- 0 (one player game)
        jr .nextState

.startTwoPlayer

        call ClearULAPlayAreaPixels     ; remove the main menu text

        ld hl,player1                   ; HL = &players1
        call InitPlayerForNewGame
        ld hl,player2                   ; HL = &players2
        call InitPlayerForNewGame

        call ActivatePlayer2            ; set global pointers before spawning invaders
        ld hl,player2Invaders
        call SetInitialInvaderPackState
        call RestoreFullShields                 ; draw shields to ULA so can then store the initial state for player 2
        call StoreWorkingDataForActivePlayer    ; store player 2's invader and shield state for their turn later

        ; now set player 1 active so they can start
        call ActivatePlayer1
        ld hl,player1Invaders
        call SetInitialInvaderPackState
        call RestoreFullShields

        call ClearULAScoreAreaPixels
        call DrawPlayer1Score
        call DrawPlayer1Lives
        call DrawHighScore
        call DrawPlayer2Score
        call DrawPlayer2Lives

        ld a,1                          ; A <- 1 (two player game)
        jr .nextState

.nextState
        ld (twoPlayerGame),a            ; set twoPlayerGame value

        ld a,GAME_STATE_READY_PLAYER
        jp EnterGameState

EnterReadyPlayer:
        HIDE_SPRITES                    ; hide sprites so READY PLAYER text is clearly visible
        call StartActivePlayerTextFlash
        call ResetUfoForPlayer
        jp DrawReadyPlayerText

UpdateReadyPlayer:

        ; Exit state after a couple of seconds
        ld a,(framesInState16)  ; A <- framesInState16 LSB
        cp 2*60                 ; 2 seconds at 60Hz
        ret nz

        call ClearReadyPlayerText

        SHOW_SPRITES

        ; next state
        ld a,GAME_STATE_SPAWNING_SHIP
        call EnterGameState

        ret

EnterSpawningShip:
        jp StartMusic

UpdateSpawningShip:

        call MoveInvader
        call UpdateUfo
        call UpdateExplosion

        ; Wait a couple of seconds before spawning ship
        ld a,(framesInState16)  ; A <- framesInState16 LSB
        cp 2*60                 ; 2 seconds at 60Hz
        ret nz

        call SpawnShip

        ; decrement lives
        ld hl,(pActivePlayer)           ; HL = &player[activePlayerIndex]
        add hl,Player.lives             ; HL = &player[activePlayerIndex].lives
        dec (hl)                        ; lives--
        call DrawActivePlayerLives

        ld a,GAME_STATE_PLAYING
        jp EnterGameState

EnterPlaying:
        jp StartMusic

UpdatePlaying:

        call UpdateShip
        call UpdateShipBullet
        call MoveInvader
        call UpdateInvaderBullets
        call UpdateUfo
        call UpdateExplosion

        PERF_BORDER_COLOUR BLUE
        call UpdateCollisions
        PERF_BORDER_COLOUR GREEN

        call UpdateScore

        ; check if player ship destroyed before checking for level complete that so it takes priority
        ld a,(destroyed)
        and a                           ; set Z flag if A is zero
        jp z,.checkLevelComplete        ; jump if not destroyed
        ld a,GAME_STATE_DESTROYED
        jp EnterGameState               ; set new state and return

.checkLevelComplete

        ld a,(liveInvaderCount)         ; A <- liveInvaderCount
        and a                           ; set Z flag if liveInvaderCount == 0
        jp nz,.checkInvaded             ; jump if there are still invaders left
        ld a,GAME_STATE_LEVEL_COMPLETE
        jp EnterGameState               ; set new state and return

.checkInvaded
        ; have the invaders reached the bottom?
        ld a,(invaded)
        and a                           ; set Zero flag if not invaded
        ret z                           ; zero means not invaded

        xor a                           ; A <- 0
        ld (invaded),a                  ; clear invaded flag

        ; set lives to zero
        ld hl,(pActivePlayer)           ; HL = &player[activePlayerIndex]
        add hl,Player.lives             ; HL = &player[activePlayerIndex].lives
        ld (hl),0                       ; lives <- 0
        call DrawActivePlayerLives

        call ResetShipBullet            ; n.b. Ensure call this before change active player so updates correct player's state
        call ResetInvaderBullets
        call ResetExplosion

        ld a,(twoPlayerGame)
        and a                           ; set zero flag if one player game
        ld a,GAME_STATE_GAME_OVER       ; assume one player, n.b. LD does not affect flags
        jp z,.set

        ; two player game
        ld a,GAME_STATE_GAME_OVER_PLAYER

        ; set active player to be dead, so play doesn't switch back to them again
        ld hl,(pActivePlayer)           ; HL = &player[activePlayerIndex]
        add hl,Player.alive             ; HL = &player.alive
        ld (hl),0                       ; player is no longer active

.set    jp EnterGameState               ; set new state and return

EnterLevelComplete:

        ; don't allow player to die after completing the level
        call ResetInvaderBullets

        call StopMusic

        ret

UpdateLevelComplete:

        call UpdateScore
        call UpdateExplosion

        ; Exit state after a couple of seconds
        ld a,(framesInState16)  ; A <- framesInState16 LSB
        cp 2*60                 ; 2 seconds at 60Hz
        ret nz

        ld ix,(pActivePlayer)
        inc (ix+Player.levelIndex)

        ld hl,(pActiveInvaders)
        call SetInitialInvaderPackState

        call RestoreFullShields

        ; next state
        ld a,GAME_STATE_PLAYING
        call EnterGameState
        ret

EnterDestroyed:
        ld a,SHIP_STATE_DESTROYED
        ld (shipState),a

        call StopMusic
        
        ; play sound effect
        ld a,SOUND_EFFECT_INDEX_SHIP_DESTROYED
        ld b,SOUND_EFFECT_CHANNEL_SHIP
        call AyfxPlayEffect

        ret

UpdateDestroyed:

        call UpdateShip         ; need to update destroyed animation
        call UpdateScore

        ; Wait a second or two for death animation to finish
        ld a,(framesInState16)  ; A <- framesInState16 LSB
        cp 2*60                 ; 2 seconds at 60Hz
        ret nz

        call HideShipSprite
        call ResetShipBullet            ; n.b. Ensure call this before change active player so updates correct player's state
        call ResetInvaderBullets
        call ResetExplosion
        
        ; clear destroyed flag now that it has been handled
        xor a                           ; A <- 0
        ld (destroyed),a                ; destroyed <- 0

        ; Was the player using their last life?
        ld hl,(pActivePlayer)           ; HL = &player[activePlayerIndex]
        add hl,Player.lives             ; HL = &player[activePlayerIndex].lives
        ld a,(hl)                       ; A <- num lives
        and a                           ; set Zero Flags if no lives left
        jr z,.noLivesLeft               ; jump if no lives left
        
        call ChangeActivePlayerIfOtherPlayerIsAlive ; Zero Flag <- reset if changed player
        jr nz,.changedPlayer
        ; did not change player, so just spawn ship straight away
        ld a,GAME_STATE_SPAWNING_SHIP
        call EnterGameState
        ret

.changedPlayer
        ld a,GAME_STATE_READY_PLAYER
        call EnterGameState
        ret

.noLivesLeft
        ld hl,(pActivePlayer)           ; HL = &player[activePlayerIndex]
        add hl,Player.alive             ; HL = &player.alive
        ld (hl),0                       ; player is no longer active

        ; if 2 player game then change to GameOverPlayer state else change to GameOver state
        ld a,(twoPlayerGame)
        and a                           ; set zero flag if one player game
        jr nz,.gameOverPlayer
        ld a,GAME_STATE_GAME_OVER
        jr .changeState
.gameOverPlayer
        ld a,GAME_STATE_GAME_OVER_PLAYER
.changeState
        call EnterGameState
        ret

EnterGameOverPlayer:
        call DrawGameOverPlayerText
        call StopActivePlayerTextFlash  ; stop flashing while GAME OVER PLAYER X is shown
        ret

UpdateGameOverPlayer:

        ; Exit state after a couple of seconds
        ld a,(framesInState16)  ; A <- framesInState16 LSB
        cp 2*60                 ; 2 seconds at 60Hz
        ret nz

        call ClearGameOverPlayerText
        call SilenceUfo

        call ChangeActivePlayerIfOtherPlayerIsAlive ; Zero Flag <- reset if changed player
        jr nz,.otherPlayerAlive
        ; other player is not alive so it's game over
        ld a,GAME_STATE_GAME_OVER
        jr .changeState
.otherPlayerAlive
        ld a,GAME_STATE_READY_PLAYER
.changeState
        call EnterGameState
        ret

EnterGameOver:
        call DrawGameOverText
        call StopActivePlayerTextFlash
        call SilenceUfo
        ret

UpdateGameOver:

        ; Exit state after a couple of seconds
        ld a,(framesInState16)  ; A <- framesInState16 LSB
        cp 2*60                 ; 2 seconds at 60Hz
        ret nz

        call EraseAllShieldBitmaps
        call ClearGameOverText
        call UpdateHighScore
        call SaveHighScoreFile

        ld a,GAME_STATE_MAIN_MENU
        call EnterGameState
        ret
