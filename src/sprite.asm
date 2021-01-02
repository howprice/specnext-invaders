
SPECNEXT_MAX_SPRITES EQU 128  ; Spectrum Next supports 128 sprites

;-------------------------------------------------------------------------------------------------------

; ------------------------------------------------------------------------------------------------
; 4 byte sprites attributes structure

    STRUCT SpriteAttributes

; Sprite Attribute 0: lower 8 bits of x position (MSB in attribute 2 bit 0)
x BYTE 0

; Sprite Attribute 1: lower 8 bits of y position (MSB in attribute 4 bit 0)
y BYTE 0

; Sprite Attribute 2
; bits 7-4 = Palette offset added to top 4 bits of sprite colour index
; bit 3 = X mirror
; bit 2 = Y mirror
; bit 1 = Rotate
; bit 0 = MSB of X coordinate  
mrx8 BYTE 0

; Sprite Attribute 3  
; bit 7 = sprite visible
; bit 6 = enable 5th sprite attribute byte
; bits 5-0 = Pattern used by sprite [0,63]  
vpat BYTE 0

    ENDS

; ------------------------------------------------------------------------------------------------
TOTAL_INVADER_SPRITE_COUNT EQU MAX_PLAYERS * INVADER_COUNT  ; store invader sprites for each player so persist between lives in 2 player games
SHIP_SPRITE_COUNT          EQU 1                            ; players can share the same ship
SHIP_BULLET_SPRITE_COUNT   EQU 1                            ; players can share the same bullets
EXPLOSION_SPRITE_COUNT     EQU 1                            ; when invader dies
UFO_SPRITE_COUNT           EQU 1

TOTAL_SPRITE_COUNT  EQU TOTAL_INVADER_SPRITE_COUNT + INVADER_BULLET_COUNT + SHIP_SPRITE_COUNT + SHIP_BULLET_SPRITE_COUNT + EXPLOSION_SPRITE_COUNT + UFO_SPRITE_COUNT

sprites       
player1invaderSprites   DS SpriteAttributes * INVADER_COUNT
player2invaderSprites   DS SpriteAttributes * INVADER_COUNT
shipSprite              DS SpriteAttributes * SHIP_SPRITE_COUNT
shipBulletSprite        DS SpriteAttributes * SHIP_BULLET_SPRITE_COUNT
invaderBulletSprites    DS SpriteAttributes * INVADER_BULLET_COUNT
explosionSprite         DS SpriteAttributes * EXPLOSION_SPRITE_COUNT
ufoSprite               DS SpriteAttributes * UFO_SPRITE_COUNT
 ASSERT ($ - sprites) == (SpriteAttributes * TOTAL_SPRITE_COUNT)

; only one set of invaders will ever be visible at any one time
ACTIVE_SPRITE_COUNT EQU INVADER_COUNT + INVADER_BULLET_COUNT + SHIP_SPRITE_COUNT + SHIP_BULLET_SPRITE_COUNT + EXPLOSION_SPRITE_COUNT + UFO_SPRITE_COUNT
 ASSERT ACTIVE_SPRITE_COUNT <= SPECNEXT_MAX_SPRITES   ; hardware sprite count exceeded

pActiveInvaderSprites DW player1invaderSprites

; ------------------------------------------------------------------------------------------------

;
; Call once on boot
;
InitSprites:
        call initSpritePalette
        call uploadSpritePatternData
        call clearSpriteAttributes
        ret

initSpritePalette:

        ; Select sprites first palette for write
        nextreg NEXTREG_PALETTE_CONTROL, NEXTREG_PALETTE_CONTROL_FLAGS_SPRITES_FIRST_PALETTE_RW
        nextreg NEXTREG_PALETTE_INDEX,0   ; start with element 0
        ld de,spritePalette    ; DE = address of first element in 8-bit palette data RRRGGGBB
        ld b,SPRITE_PALETTE_COUNT  ; number of colours to loop over

.loop   ld a,(de)       ; RRRGGGBB
        nextreg NEXTREG_PALETTE_VALUE_9_BIT_COLOUR,a ; n.b. writing to Palette Value Register increments Palette Index Register
        inc de          ; DE <- address of byte containing blue LSB (in bit 0) 
        
        ld a,(de)       ; blue LSB
        nextreg NEXTREG_PALETTE_VALUE_9_BIT_COLOUR,a
        inc de          ; DE <- address of next element

        djnz .loop

        ; Set colour index 0 to be transparent
        nextreg NEXTREG_SPRITE_TRANSPARENCY_INDEX, 0

        ret

;
; Sprite data is not stored in RAM, it is stored in internal memory on the FPGA.
; So the CPU needs to upload the data to the FPGA.
;
; Modifies: af, bc, hl
;
uploadSpritePatternData:

        ; Select sprite 0 by writing zero to SPRITE_SLOT_SELECT_PORT
        ; Writing to this port sets the sprite index for both SPRITE_ATTRIBUTE_UPLOAD_PORT $xx57 and SPRITE_PATTERN_UPLOAD_PORT $XX5B
        ld bc, PORT_SPRITE_SLOT_SELECT
        ld a,0 ; sprite 0
        out (c),a ; n.b. port number is given in BC even though the instruction refers only to C

        ld hl,spritePatternData ; HL = pattern data
        ld c,PORT_SPRITE_PATTERN_UPLOAD
        ld b,0 ; repeat 256 times (write 256 bytes) 
        ld a,SPRITE_PATTERN_COUNT
.loop   ; upload 256 bytes of data. B will end up at 0 again
        otir ; n.b. repeats outi(bc) but MSB of SPRITE_PATTERN_UPLOAD_PORT $xx5B is ignored
        dec a
        jr nz,.loop
        ret

; Sets up sprites. See https://wiki.specnext.dev/Sprites#Programming_Sprites
clearSpriteAttributes:

        ld hl,sprites
        ld b,TOTAL_SPRITE_COUNT                       ; loop index
.loop   ASSERT SpriteAttributes.x == 0
        ld (hl),0
        inc hl
        ASSERT SpriteAttributes.y == 1
        ld (hl),0
        inc hl
        ASSERT SpriteAttributes.mrx8 == 2
        ld (hl),0 ; no rotation and mirroring , no palette offset
        inc hl
        ASSERT SpriteAttributes.vpat == 3
        ld (hl),0 ; not visible, no 5th attribute byte, sprite pattern zero
        inc hl
        djnz .loop
        ret

HideAllSprites:
        ld hl,sprites+SpriteAttributes.vpat
        ld b,TOTAL_SPRITE_COUNT
.loop   res SPRITE_ATTRIBUTE3_BIT_VISIBLE,(hl)
        add hl,SpriteAttributes
        djnz .loop
        ret

;   
; Sprite data is not stored in RAM, it is stored in internal memory on the FPGA.
; So the CPU needs to upload the data to the FPGA.
;
UploadSpriteAttributes:

        ; Select sprite 0 by writing zero to SPRITE_SLOT_SELECT_PORT
        ; Writing to this port sets the sprite index for SPRITE_ATTRIBUTE_UPLOAD_PORT $xx57
        ; n.b. The attribute pointer increments internally after each attribute is written so just write attributes consecutively
        ; https://wiki.specnext.dev/Sprite_Attribute_Upload

        ; select sprite 0
        ld bc,PORT_SPRITE_SLOT_SELECT
        ld a,0 ; sprite 0
        out (c),a ; n.b. port number is given in BC even though the instruction refers only to C

        ; To upload the max 128 sprites at once, 128 * 4 bytes = 512 bytes would require 2 x 256 byte loops
        ; Hint: Only LSB (C) of port is used so could use B as loop index for otir. (Set B to 0 before calling OTIR to loop 256 times)
        ld bc, PORT_SPRITE_ATTRIBUTE_UPLOAD  

        ; upload invader sprites for active player
        ld hl,(pActiveInvaderSprites)                     ; assume player 1 active
.notPlayer2
INVADER_SPRITES_BYTE_COUNT EQU INVADER_COUNT * SpriteAttributes
        ASSERT INVADER_SPRITES_BYTE_COUNT <= 256       ; if this assert fires then may need a bigger loop
        ld b,INVADER_SPRITES_BYTE_COUNT                ; loop index for otir
        otir                                            ; do {B--; out(BC,HL); HL++} while (B>0)

        ; upload remaining sprites (ship, bullets etc)
        ASSERT shipSprite == player2invaderSprites + INVADER_COUNT * SpriteAttributes ; assumes ship sprites immediately follows
        ld hl,shipSprite
        ld b,(ACTIVE_SPRITE_COUNT - INVADER_COUNT) * SpriteAttributes     ; size of remaining sprites in bytes 
        otir                                            ; do {B--; out(BC,HL); HL++} while (B>0)

        ret 
