
SCORE_HEADER_START_Y EQU 0
SCORE_VALUES_START_Y EQU 8
PLAY_AREA_START_Y    EQU 16

scoreText:              BYTE "1UP      HI-SCORE      2UP", 0        ; null terminated string
mainMenuText1           BYTE "SPECNEXT INVADERS", 0                 ; null terminated string
mainMenuText2           BYTE "PRESS FIRE OR 1 OR 2", 0              ; null terminated string
mainMenuText3           BYTE "PRESS Q TO QUIT", 0                   ; null terminated string

readyPlayer1Text        BYTE "READY PLAYER 1", 0                    ; null terminated string
readyPlayer2Text        BYTE "READY PLAYER 2", 0                    ; null terminated string
READY_PLAYER_TEXT_LENGTH EQU $-readyPlayer2Text-1
READY_PLAYER_TEXT_X  EQU 8
READY_PLAYER_TEXT_Y  EQU 10

gameOverText            BYTE "GAME OVER", 0                         ; null terminated string
GAME_OVER_TEXT_LENGTH EQU $-gameOverText-1
GAME_OVER_TEXT_X EQU 10
GAME_OVER_TEXT_Y EQU 3

gameOverPlayer1Text     BYTE "GAME OVER PLAYER 1", 0                ; null terminated string
gameOverPlayer2Text     BYTE "GAME OVER PLAYER 2", 0                ; null terminated string
GAME_OVER_PLAYER_TEXT_LENGTH EQU $-gameOverPlayer2Text-1
GAME_OVER_PLAYER_TEXT_X EQU 6
GAME_OVER_PLAYER_TEXT_Y EQU 22

versionString:          BYTE "V0.8.2", 0                          ; null terminated string
VERSION_STRING_LENGTH   EQU $-versionString-1                     ; -1 to account for null terminator

flashActivePlayerText DB $00

;-------------------------------------------------------------------------------------------------------------------

;
; Clears the ULA screen pixel and attribute region of memory
; https://zxsnippets.fandom.com/wiki/Clearing_screen
;
; Modifies: AF, BC, DE, HL
;
ClearULAScreen:
        ; 256x192 pixels at 1 bit per pixel = $1800 bytes
        ; 32x24 8x8 attribute cells 1 byte per cell $300 bytes
        ; https://wiki.specnext.dev/Video_Modes#Spectrum_Video_Mode

        ; clear pixels
        ; Deliberately zero 1 too many (first attribute byte) to set up hl and bc for attributes
        ld hl,ULA_BITMAP_ADDRESS
        ld de,ULA_BITMAP_ADDRESS+1
        ld bc,ULA_BITMAP_SIZE_BYTES     ; byte count
        ld (hl),l                       ; zero first byte (l = 0 at this point)
        ldir                            ; clear pixel area

        ; clear attribute cells
        ld a,ATTR_PAPER_BLACK|ATTR_INK_WHITE|ATTR_BRIGHT
        ld (hl),a                            ; set first attribute
        ld bc,ULA_ATTRIBUTES_SIZE_BYTES-1    ; number of attributes to loop over
        ldir                                 ; set the rest
        ret

;
; Clears a vertical region of ULA pixels
; D = row start index (in pixels)
; B = row count
; Modifies: DE, HL
;
ClearULAPixelRows:
        ld e,0                          ; x coord
.loop   pixelad                         ; HL <- address of first pixel to clear
        push bc                         ; push row loop count
        push de                         ; push pixel coord
        push hl                         ; push address of first pixel in row
        ex de,hl                        ; DE <- address of first pixel in row
        add de,$1                       ; DE <- address of second pixel in row
        pop hl                          ; DE <- address of first pixel in row
        ld (hl),$00                     ; clear first pixel in the row
        ld bc,31                        ; BC <- loop count = 32 bytes per row, but first has already been cleared
        ldir                            ; clear row

        pop de                          ; DE <- pixel coord
        add de,$100                     ; y++
        pop bc                          ; pop row loop count
        djnz .loop                      ; next row

        ret

;
; Clears the region of the ULA between the score header and player area
; 
; Modifies: BC, DE, HL
;
ClearULAScoreAreaPixels:
        ld d,SCORE_VALUES_START_Y          ; y coord
        ld b,8                             ; row loop count
        jr ClearULAPixelRows

;
; Clears the region of the ULA below the two score header and score lines
; i.e. (0,32) to (255,191)
;
; Modifies: BC, DE, HL
;
ClearULAPlayAreaPixels:
        ld d,PLAY_AREA_START_Y          ; y coord
        ld b,192-PLAY_AREA_START_Y      ; row loop count
        jr ClearULAPixelRows

;
; Draws the (unchanging) text at the top of the screen
; Modifies: af, bc, de, hl
;
DrawScoreHeader:
        ; print string
        ld hl,scoreText
        ld d,0                ; Y position
        ld e,2                ; X position
        call PrintString
        ret

;
; Modify ULA attribute to oscillate ink colour to highlight active player 1UP or 2UP text
; B = ULA attribute value
; Modifies: AF, HL
; 
SetActivePlayerTextAttributes
        ld a,(activePlayerIndex)
        and a                   ; set zero flag if player 1 active
        jr nz,.player2
        ld hl,ULA_ATTRIBUTES_ADDRESS+2  ; + offset of "1UP"
        jr .setAttributes
.player2
        ld hl,ULA_ATTRIBUTES_ADDRESS+25 ; + offset of "2UP"
.setAttributes
        ld (hl),b               ; set first attribute '1' or '2'
        inc hl
        ld (hl),b               ; set second attribute 'U'
        inc hl
        ld (hl),b               ; set third attribute 'P'
        ret

DrawActivePlayerScore:
        ld a,(activePlayerIndex)
        and a                           ; set Zero flag if player 1 active
        jr z,DrawPlayer1Score
        jp DrawPlayer2Score

;
; Draws player 1's 4 digit score value to the ULA screen  
;
DrawPlayer1Score:
        ld a,(player1+Player.scoreBCD16)        ; A = player 1 score LSB
        ld b,a                                  ; B = score LSB
        ld a,(player1+Player.scoreBCD16+1)      ; A = player 2 score MSB
        ld d,1                                  ; Y position
        ld e,2                                  ; X position
        call PrintDecimalWord

        ret

;
; Draws player 2's 4 digit score value to the ULA screen  
;
DrawPlayer2Score:
        ld a,(player2+Player.scoreBCD16)        ; A = player 1 score LSB
        ld b,a                                  ; B = score LSB
        ld a,(player2+Player.scoreBCD16+1)      ; A = player 2 score MSB
        ld d,1                                  ; Y position
        ld e,24                                 ; X position
        call PrintDecimalWord

        ret        

; Draws the 4 digit score value 
DrawHighScore:
        ld a,(highScoreBCD16)       ; A = high score LSB
        ld b,a                      ; B = high score LSB
        ld a,(highScoreBCD16+1)     ; A = high score MSB
        ld d,1                      ; Y position
        ld e,13                     ; X position
        call PrintDecimalWord

        ret


DrawMainMenu:

        ; set all ULA attributes
        ld a,ATTR_PAPER_BLACK|ATTR_INK_WHITE|ATTR_BRIGHT
        ld hl,ULA_ATTRIBUTES_ADDRESS
        ld de,ULA_ATTRIBUTES_ADDRESS+1
        ld (hl),a                               ; set first attribute
        ld bc,ULA_ATTRIBUTES_SIZE_BYTES-1       ; number of attributes to loop over
        ldir                                    ; loop over and set the rest

        call DrawPlayer1Score
        call DrawPlayer2Score
        call DrawHighScore

        ld hl,mainMenuText1
        ld d,7                ; Y position
        ld e,6                ; X position
        call PrintString

        ld hl,mainMenuText2
        ld d,14                ; Y position
        ld e,5                 ; X position
        call PrintString

        ld hl,mainMenuText3
        ld d,20                ; Y position
        ld e,7                 ; X position
        call PrintString

        ld hl,versionString
        ld d,ULA_ATTRIBUTES_HEIGHT_BYTES-1                ; Y position
        ld e,ULA_ATTRIBUTES_WIDTH_BYTES-VERSION_STRING_LENGTH-1                 ; X position
        call PrintString

        ret

;
; Draws READY PLAYER 1 or READY PLAYER 2 depending on active player
;
DrawReadyPlayerText:
        call DrawActivePlayerScore      ; TODO: This should flash

        ld a,(activePlayerIndex)
        and a                           ; set Zero Flag if player 1 is active
        jr nz,.p2                       ; jump if player 2 is active
        ld hl,readyPlayer1Text
        jr .draw
.p2     ld hl,readyPlayer2Text
.draw   ld e,READY_PLAYER_TEXT_X
        ld d,READY_PLAYER_TEXT_Y
        call PrintString

        ret

ClearReadyPlayerText:
        
        ld e,READY_PLAYER_TEXT_X
        ld d,READY_PLAYER_TEXT_Y
        ld b,READY_PLAYER_TEXT_LENGTH
        jp ClearText

;
; Modifes: AF, BC, DE, HL 
;
DrawPlayer1Lives:
        ld a,(player1+Player.lives)     ; A = player[0].lives
        ld d,1                          ; Y
        ld e,7                          ; X
        call PrintDecimalNibble
        ret

;
; Modifes: AF, BC, DE, HL 
;
DrawPlayer2Lives:
        ld a,(player2+Player.lives)     ; A = player[1].lives
        ld d,1                          ; Y
        ld e,22                         ; X
        call PrintDecimalNibble
        ret

DrawActivePlayerLives:
        ld a,(activePlayerIndex)
        and a                           ; set Zero flag if player 1 active
        jr z,DrawPlayer1Lives
        jp DrawPlayer2Lives      

DrawGameOverText:
        ld hl,gameOverText
        ld e,GAME_OVER_TEXT_X
        ld d,GAME_OVER_TEXT_Y
        call PrintString
        ret        

ClearGameOverText:      
        ld e,GAME_OVER_TEXT_X
        ld d,GAME_OVER_TEXT_Y
        ld b,GAME_OVER_TEXT_LENGTH
        jp ClearText

;
; Draws "GAME OVER PLAYER X"
;
DrawGameOverPlayerText:

        ld a,(activePlayerIndex)
        and a                           ; set Zero flag if player 1 active
        jr nz,.player2                  ; not zero means player 2 is active
        ld hl,gameOverPlayer1Text
        jr .draw
.player2
        ld hl,gameOverPlayer2Text
.draw
        ld e,GAME_OVER_PLAYER_TEXT_X
        ld d,GAME_OVER_PLAYER_TEXT_Y
        call PrintString
        ret        

ClearGameOverPlayerText:      
        ld e,GAME_OVER_PLAYER_TEXT_X
        ld d,GAME_OVER_PLAYER_TEXT_Y
        ld b,GAME_OVER_PLAYER_TEXT_LENGTH
        jp ClearText

UpdateUI:
        ld a,(flashActivePlayerText)
        and a                           ; set zero flag if don't want to flash
        ret z
        call updateActivePlayerTextFlash
        ret

StartActivePlayerTextFlash:
        ld a,1
        ld (flashActivePlayerText),a
        ret

;
; Stop flashing 1UP or 2UP
;
StopActivePlayerTextFlash:
        xor a                                   ; A <- 0
        ld (flashActivePlayerText),a            ; flashActivePlayerText <- 0
        ; make the text visible in case was called while hidden
        ld b,ATTR_PAPER_BLACK|ATTR_INK_WHITE|ATTR_BRIGHT
        call SetActivePlayerTextAttributes
        ret

updateActivePlayerTextFlash:

        ld a,(frameCount8)
        and 1<<4                ;  change bit to change frequency
        jr nz,.off
        ld b,ATTR_PAPER_BLACK|ATTR_INK_WHITE|ATTR_BRIGHT
        jr .set
.off    ld b,ATTR_PAPER_BLACK|ATTR_INK_BLACK
.set    call SetActivePlayerTextAttributes
        ret
