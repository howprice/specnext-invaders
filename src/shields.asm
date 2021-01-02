
SHIELD_IMAGE_WIDTH_PIXELS  EQU 22
SHIELD_IMAGE_WIDTH_BYTES   EQU 3
 ASSERT (SHIELD_IMAGE_WIDTH_PIXELS + 7) / 8 == SHIELD_IMAGE_WIDTH_BYTES ; pixes should round up to bytes
SHIELD_IMAGE_HEIGHT_PIXELS EQU 16
SHIELD_IMAGE_SIZE_BYTES    EQU SHIELD_IMAGE_WIDTH_BYTES*SHIELD_IMAGE_HEIGHT_PIXELS

; 22 pixels wide x 16 pixels high
; n.b. image is not symmetrical!
shieldImage
        DB %01111111, %11111111, %11111000
        DB %11111111, %11111111, %11111100
        DB %11101010, %10101010, %01011100
        DB %11011111, %11111111, %11101100
        DB %11011111, %11111111, %11101100
        DB %11011111, %11111111, %11101100
        DB %11011111, %11111111, %11101100
        DB %11011111, %11111111, %11101100
        DB %11011111, %11111111, %11101100
        DB %11011111, %11111111, %11101100
        DB %11010111, %11111111, %11101100
        DB %11010111, %11111111, %10101100
        DB %11010111, %11111111, %10101100
        DB %11010111, %11111111, %10101100
        DB %11010111, %11111111, %10101100
        DB %01111111, %11111111, %11111000
        ASSERT $-shieldImage == SHIELD_IMAGE_SIZE_BYTES

SHIELD_COUNT EQU 4

SHIELD0_X_ULA_SPACE EQU 32  ; ULA x coord of left most shield
SHIELD_SPACING_X    EQU 52  ; from left hand side to left hand side
SHIELD1_X_ULA_SPACE EQU SHIELD0_X_ULA_SPACE + SHIELD_SPACING_X
SHIELD2_X_ULA_SPACE EQU SHIELD1_X_ULA_SPACE + SHIELD_SPACING_X
SHIELD3_X_ULA_SPACE EQU SHIELD2_X_ULA_SPACE + SHIELD_SPACING_X

SHIELD0_X_SCREEN_SPACE EQU 32 + SHIELD0_X_ULA_SPACE   ; screen-space x coord of left-most shield
SHIELD1_X_SCREEN_SPACE EQU 32 + SHIELD1_X_ULA_SPACE
SHIELD2_X_SCREEN_SPACE EQU 32 + SHIELD2_X_ULA_SPACE
SHIELD3_X_SCREEN_SPACE EQU 32 + SHIELD3_X_ULA_SPACE   ; screen-space x coord of right-most shield

SHIELD_Y_ULA_SPACE    EQU 160                        ; all shields are at the same height
SHIELD_Y_SCREEN_SPACE EQU 32 + SHIELD_Y_ULA_SPACE

; Shield hitboxes in sprite screen space (ULA space with extra 32 pixel border around it)
shieldHitboxes Hitbox { SHIELD0_X_SCREEN_SPACE, SHIELD0_X_SCREEN_SPACE + SHIELD_IMAGE_WIDTH_PIXELS - 1, ; x0, x1 (left shield)
                        SHIELD_Y_SCREEN_SPACE, SHIELD_Y_SCREEN_SPACE + SHIELD_IMAGE_HEIGHT_PIXELS - 1 } ; y0, y1                              ; y0, y1
               Hitbox { SHIELD1_X_SCREEN_SPACE, SHIELD1_X_SCREEN_SPACE + SHIELD_IMAGE_WIDTH_PIXELS - 1, 
                        SHIELD_Y_SCREEN_SPACE, SHIELD_Y_SCREEN_SPACE + SHIELD_IMAGE_HEIGHT_PIXELS - 1 }
               Hitbox { SHIELD2_X_SCREEN_SPACE, SHIELD2_X_SCREEN_SPACE + SHIELD_IMAGE_WIDTH_PIXELS - 1, 
                        SHIELD_Y_SCREEN_SPACE, SHIELD_Y_SCREEN_SPACE + SHIELD_IMAGE_HEIGHT_PIXELS - 1 }
               Hitbox { SHIELD3_X_SCREEN_SPACE, SHIELD3_X_SCREEN_SPACE + SHIELD_IMAGE_WIDTH_PIXELS - 1, ; right shield
                        SHIELD_Y_SCREEN_SPACE, SHIELD_Y_SCREEN_SPACE + SHIELD_IMAGE_HEIGHT_PIXELS - 1 }
               ASSERT $-shieldHitboxes == (SHIELD_COUNT * Hitbox)

; colour vertical strip of the ULA screen
SHIELD_Y0_ULA_ATTRIBUTE_SPACE EQU SHIELD_Y_ULA_SPACE / 8 ; 8 pixels per byte
SHIELD_Y1_ULA_ATTRIBUTE_SPACE EQU (SHIELD_Y_ULA_SPACE + SHIELD_IMAGE_HEIGHT_PIXELS - 1) / 8 ; 8 pixels per byte
SHIELD_HEIGHT_ATTRIBUTE_SPACE EQU SHIELD_Y1_ULA_ATTRIBUTE_SPACE - SHIELD_Y0_ULA_ATTRIBUTE_SPACE + 1
SHIELD_ATTRIBUTES_START_ADDRESS EQU ULA_ATTRIBUTES_ADDRESS + (SHIELD_Y0_ULA_ATTRIBUTE_SPACE * ULA_ATTRIBUTES_WIDTH_BYTES)
SHIELD_ATTRIBUTES_SIZE_BYTES EQU ULA_ATTRIBUTES_WIDTH_BYTES * SHIELD_HEIGHT_ATTRIBUTE_SPACE

; In a one player game the shield pixel state is stored directly on screen in the ULA
; bitmap data. In a two player game the shield pixel state needs to be stored per-player.
; While a player is playing the state is in the ULA. When the game switches player the ULA
; data is copied into the outgoing player's off screen buffer, and the incoming player's 
; off-screen buffer is copied back into the ULA memory
player1ShieldBitmaps DS SHIELD_IMAGE_SIZE_BYTES * SHIELD_COUNT
player2ShieldBitmaps DS SHIELD_IMAGE_SIZE_BYTES * SHIELD_COUNT

;----------------------------------------------------------------------------------------
;
; Draws all four shields to the ULA screen
; Modifies: AF, BC, DE, HL, IX, IY
;
RestoreFullShields:

        ; TODO: Could put this in a loop to save few bytes
        ld hl,shieldImage
        ld a,SHIELD0_X_ULA_SPACE
        call drawShieldBitmap

        ld hl,shieldImage
        ld a,SHIELD1_X_ULA_SPACE
        call drawShieldBitmap

        ld hl,shieldImage
        ld a,SHIELD2_X_ULA_SPACE
        call drawShieldBitmap
        
        ld hl,shieldImage
        ld a,SHIELD3_X_ULA_SPACE
        call drawShieldBitmap

        ; set attribute cell values for the vertical strip of the screen containing the shields
        ld a,ATTR_PAPER_BLACK|ATTR_INK_WHITE ; n.b. not bright
        ld hl,SHIELD_ATTRIBUTES_START_ADDRESS
        ld de,SHIELD_ATTRIBUTES_START_ADDRESS+1
        ld (hl),a                               ; set first attribute
        ld bc,SHIELD_ATTRIBUTES_SIZE_BYTES-1    ; number of attributes to loop over
        ldir                                    ; set the rest

        ld a,$0f        ; set bits 0-3 to indicate that shields 0-3 are intact
        ld (shieldState),a
        ret

;
; HL = address of off-screen buffer (array)
; Modifies: AF, BC, DE, HL, IX, IY
;
StoreShields:

        push hl
        ld a,SHIELD0_X_ULA_SPACE
        call copyShieldULAToBuffer

        pop hl
        add hl,SHIELD_IMAGE_SIZE_BYTES
        push hl
        ld a,SHIELD1_X_ULA_SPACE
        call copyShieldULAToBuffer

        pop hl
        add hl,SHIELD_IMAGE_SIZE_BYTES
        push hl
        ld a,SHIELD2_X_ULA_SPACE
        call copyShieldULAToBuffer

        pop hl
        add hl,SHIELD_IMAGE_SIZE_BYTES
        ld a,SHIELD3_X_ULA_SPACE
        call copyShieldULAToBuffer

        ret

DrawPlayer1Shields:
        ld hl,player1ShieldBitmaps
        jp drawBufferedShields

DrawPlayer2Shields:
        ld hl,player2ShieldBitmaps
        jp drawBufferedShields


;
; HL = address of off-screen buffer (array)
; Modifies: AF, BC, DE, HL, IX, IY
;
drawBufferedShields:

        push hl
        ld a,SHIELD0_X_ULA_SPACE
        call drawShieldBitmap

        pop hl
        add hl,SHIELD_IMAGE_SIZE_BYTES
        push hl
        ld a,SHIELD1_X_ULA_SPACE
        call drawShieldBitmap

        pop hl
        add hl,SHIELD_IMAGE_SIZE_BYTES
        push hl
        ld a,SHIELD2_X_ULA_SPACE
        call drawShieldBitmap

        pop hl
        add hl,SHIELD_IMAGE_SIZE_BYTES
        ld a,SHIELD3_X_ULA_SPACE
        call drawShieldBitmap

        ret

;
; Draws a shield to the ULA bitmap at a specified pixel coordinate
;
; n.b. The shield image is 3 bytes wide, but when not 8 pixel aligned in x it requires 
; four bytes to be written to screen
; 
; HL = shield bitmap image data, which could be either hardcoded or per-player data
; A = ULA x coord
; Modifies: AF, BC, DE, HL, IX, IY
;
drawShieldBitmap:
        push hl                         ; push image address

        ld e,a                          ; E <- ULA x coord
        ld d,SHIELD_Y_ULA_SPACE         ; D <- ULA y coord
        pixelad                         ; HL <- ULA pixel address

        ; calculate and store the right bit shift value [0,7]
        and 7                           ; keep lower 3 bits
        ld ixl,a                        ; IXL <- shift value

        pop de                          ; DE <- address of image
        ld b,SHIELD_IMAGE_HEIGHT_PIXELS ; row loop counter
.rowLoop
        ; 22 horizontal pixels requires three bytes storage but when shifted right it can require up
        ; to four bytes to be written to the screen.
        ; Use C, D, E and A for the four bytes.
        ld a,(de)                       ; A <- first byte
        ld c,a                          ; C <- first byte
        inc de                          ; advance DE to second byte 

        ld a,(de)                       ; A <- second byte
        ld iyh,a                        ; IYH <- second byte
        inc de                          ; advance DE to third byte 

        ld a,(de)                       ; A <- third byte
        ld iyl,a                        ; IYL <- third byte
        inc de                          ; advance DE to next row of image data 

        push de
        ld d,iyh                        ; D <- second byte
        ld e,iyl                        ; E <- third byte

        ; do we need to shift right?
        ld a,ixl                        ; A <- right bit shift value
        and a                           ; set Z flag if shift is 0
        jp z,.noshift                   ; jump if no shift required n.b. A (right byte) will be zero

        ; shift
        ld ixh,b                        ; IXH <- row loop count
        ld b,a                          ; B <- right shift count (loop count)
        xor a                           ; A <- 0, CF <- 0
.shiftLoop
        rr c                            ; rotate zero into bit 7 of C and bit 0 of C into CF
        rr d                            ; rotate CY into bit 7 of D and bit 0 of D into CF
        rr e                            ; rotate CY into bit 7 of E and bit 0 of E into CF
        rra                             ; rotate CY into bit 7 of A and 0 into CF (A initialised to zero)
        djnz .shiftLoop
        ld b,ixh                        ; B <- row loop count
.noshift
        ; write the four bytes to screen          
        ld (hl),c                       ; write first byte to screen
        inc hl                          ; step right
        ld (hl),d                       ; write second byte to screen
        inc hl                          ; step right
        ld (hl),e                       ; write third byte to screen
        inc hl                          ; step right
        ld (hl),a                       ; write fourth byte to screen
        add hl,-3                       ; step back to first byte
        pixeldn                         ; step down
        
        pop de                          ; DE <- address of next row of sprite data
        djnz .rowLoop
        ret

;
; Erases a shield from the ULA bitmap screen
; A = ULA x coord
; Modifies: AF, B, DE, HL
;
eraseShieldBitmap:

        ; Shield x pos means it straddles wither 3 or 4 bytes horizontally
        ; There's nothing inbeteen right now, so let's just clear 4 bytes per row
        ld e,a                  ; A <- ULA x coord
        ld d,SHIELD_Y_ULA_SPACE
        pixelad                 ; HL <- address of top-left byte
        xor a                   ; A <- 0
        ld b,SHIELD_IMAGE_HEIGHT_PIXELS ; row loop counter
.loop   ld e,l                  ; E <- low byte of ULA address (no need to store high byte because doesn't change in a row)
        ld (hl),a               ; clear first byte of row
        inc hl
        ld (hl),a               ; clear second byte of row
        inc hl
        ld (hl),a               ; clear third byte of row
        inc hl
        ld (hl),a               ; clear fourth byte of row
        ld l,e                  ; L <- low byte of first byte
        pixeldn                 ; HL <- address of first byte on next row
        djnz .loop
        ret

;
; A = shield x coord (ULA space)
; HL = address of off-screen buffer of size SHIELD_IMAGE_SIZE_BYTES
; Modifies: AF, BC, DE, HL, IX, IY
;
copyShieldULAToBuffer:

        push hl                         ; IX <- address of buffer ..
        pop ix                          ; .. (using Index Registers is slow, but this isn't performance-critical)

        ld e,a                          ; E <- ULA x coord
        ld d,SHIELD_Y_ULA_SPACE         ; D <- ULA y coord
        pixelad                         ; HL <- ULA pixel address

        ; calculate offset into ULA bitmap byte
        and 7                           ; A <- x & 7
        ld iyh,a                        ; IYH <- x & 7

        ; SHIELD_IMAGE_WIDTH_BYTES == 3 so if (x & 7) > 0 then need to read 4 ULA bytes
        ; We read a pair from left to right three times, shifting left by the shield's x&7 offset
        ; and storing a byte into the off-screen buffer 
        ; n.b. This does not clip so may fail if shield against right screen edge
        ASSERT SHIELD_IMAGE_WIDTH_BYTES == 3 ; code assumes this

        ld b,SHIELD_IMAGE_HEIGHT_PIXELS
.loopY  push hl                         ; push ULA bitmap byte address

        ; load first ULA bytes into DE
        ld d,(hl)
        inc l           ; next horizontal byte

        push bc         ; push loopY counter
        ld b,3          ; B <- loopX counter - read 3 pairs of bytes per row
.loopX  ld c,b          ; C <- loopX counter

        ; load next byte to the right
        ld e,(hl)
        inc l           ; ulaBitmapAddress++

        ; barrel shift left (Z80N instruction)
        ld iyl,e                        ; preserve second byte for next iteration
        ld b,iyh                        ; B <- shift
        bsla de,b                       ; DE <- DE << b

        ; store in off-screen buffer
        ld (ix+0),d                     ; store byte in buffer
        inc ix                          ; pBuffer++

        ld d,iyl                        ; D <- next byte over for next iteration (rotate)

        ; next byte in row
        ld b,c                          ; B <- loopX counter
        djnz .loopX

        ; next row
        pop bc                          ; BC <- loopY counter
        pop hl                          ; HL <- ULA coord
        pixeldn                         ; HL <- next row down
        djnz .loopY                     ; next row

        ret


; 2D Gaussian kernel to use a destruction pattern
; Generated at http://dev.theomader.com/gaussian-kernel-calculator/ with sigma=2.0
; Designed to do maximum damage at hitpoint and less with increasing distance
; Almost certainly overkill
gaussianKernel7x7:
        DB 28,52, 75, 85, 75, 52, 28
        DB 52,96, 139,157,139,96, 52
        DB 75,139,200,227,200,139,75
        DB 85,157,227,255,227,157,85
        DB 75,139,200,227,200,139,75
        DB 52,96, 139,157,139,96, 52
        DB 28,52, 75, 85, 75, 52, 28
        ASSERT $ - gaussianKernel7x7 == 7*7

;
; E = point of impact ULA x coord
; D = point of impact ULA y coord
; Modifies: AF, BC, DE, HL, IXH
; 
BlowHoleInShields:

        ; Affect pixels in a 7x7 square centred around around the point of impact
        ; Remove the pixels pseudo-randomly using a 2D Gaussian kernel for more damage near centre.
        dec d                   ; y -=3
        dec d                   ; ..
        dec d                   ; ..
        dec e                   ; x -= 3
        dec e                   ; ..
        dec e                   ; ..
        ld hl,gaussianKernel7x7
        ld ixl,e                ; store x0 for looping
        ld ixh,7                ; y loop counter
.loopY  ld e,ixl                ; E <- x0
        ld b,7                  ; x loop counter
.loopX  call CalcRandomByte     ; A <- random byte
        ld c,a                  ; C <- random
        ld a,(hl)               ; A <- Gaussian 7x7 filter kernel element value
        inc hl                  ; next kernel element
        cp c                    ; kernel - random, set CF if random > kernel
        jp c,.nextX             ; jumpf and leave pixel intact if random > kernel

        ; clear the pixel
        push hl         ; push kernel address
        pixelad         ; HL <- ULA pixel address
        ld c,(hl)       ; C <- shield pixels
        setae           ; HL <- pixel mask e.g. 00010000
        cpl             ; A <= ~A          e.g. 11101111
        and c           ; C <- shield pixels with pixel removed
        ld (hl),a       ; write ULA byte
        pop hl          ; HL <- kernel address

.nextX  inc e           ; x++
        djnz .loopX

        dec ixh
        ld b,ixh
        inc d           ; y++
        djnz .loopY

        ret

;
; Erases a shield image from the ULA bitmap and resets its "intact" bit
; A = value with bit set for shield index to erase e.g. $1 = shield 0, $2 = shield 1, $4 = shield 2, $8 = shield 3
; Modifies: AF, B, DE, HL
;
DestroyShield:

        ; reset the active bit for this shield
        ld b,a                  ; store original value
        cpl                     ; invert bits
        ld hl,shieldState
        and (hl)                ; shieldState &= ~shieldBit
        ld (hl),a
        ld a,b

        cp 1
        jp z,eraseShield0Bitmap
        cp 2
        jp z,eraseShield1Bitmap
        cp 4
        jp z,eraseShield2Bitmap
        cp 8
        jp z,eraseShield3Bitmap
        ret

eraseShield0Bitmap:
        ld a,SHIELD0_X_ULA_SPACE
        call eraseShieldBitmap
        ret

eraseShield1Bitmap:
        ld a,SHIELD1_X_ULA_SPACE
        call eraseShieldBitmap
        ret

eraseShield2Bitmap:
        ld a,SHIELD2_X_ULA_SPACE
        call eraseShieldBitmap
        ret

eraseShield3Bitmap:
        ld a,SHIELD3_X_ULA_SPACE
        call eraseShieldBitmap
        ret

;
; Erases the bitmap image data from the ULA screen for all shields
; Modifies: AF, B, DE, HL
;
EraseAllShieldBitmaps:

        ld a,SHIELD0_X_ULA_SPACE
        call eraseShieldBitmap

        ld a,SHIELD1_X_ULA_SPACE
        call eraseShieldBitmap

        ld a,SHIELD2_X_ULA_SPACE
        call eraseShieldBitmap

        ld a,SHIELD3_X_ULA_SPACE
        call eraseShieldBitmap

        ret
