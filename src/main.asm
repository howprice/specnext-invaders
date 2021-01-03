; Build from project root with with command line:
; sjasmplus --fullpath --sld=bin/invaders.sld --lst=bin/invaders.lst --lstlab --sym=bin/invaders.labels --msg=war src/main.asm

        OPT --syntax=abfw  ; sjasmplus recommended settings
        OPT --zxnext
        OPT --zxnext=cspect ;DEBUG enable break/exit fake instructions of CSpect (remove for real board)
 
        DEVICE ZXSPECTRUMNEXT
        SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION

        DEFINE DISPLAY_PERFORMANCE_DEBUG_BORDER 1    ; enable the color stripes in border

        ; If set then sprite attributes are uploaded as soon as screen finishes drawing
        ; to avoid tearing.
        ; If reset then game state updates first before uploading the sprite attributes
        ; which can reduce latency to zero if whole game runs before raster gets back to first
        ; line containing sprites.
        DEFINE UPLOAD_SPRITE_ATTRIBUTES_FIRST 0   

        ORG $8000               ; $8000..BFFF is Bank 2 (pages 4 and 5)

PROGRAM_START
CODE_START
        INCLUDE "ula.asm"
        INCLUDE "ports.asm"
        INCLUDE "nextreg.asm"
        INCLUDE "esxdos.asm"
        INCLUDE "macros.asm"
        INCLUDE "math.asm"
        INCLUDE "rand.asm"
        INCLUDE "input.asm"
        INCLUDE "text.asm"
        INCLUDE "ui.asm"
        INCLUDE "sprite.asm"
        INCLUDE "hitbox.asm"
        INCLUDE "ship.asm"
        INCLUDE "ship_bullet.asm"
        INCLUDE "invaders.asm"
        INCLUDE "invader_bullets.asm"
        INCLUDE "ufo.asm"
        INCLUDE "shields.asm"
        INCLUDE "explosion.asm"
        INCLUDE "collision.asm"
        INCLUDE "game_state.asm"
        INCLUDE "player.asm"
        INCLUDE "ay3.asm"
        INCLUDE "music.asm"
        INCLUDE "ayfxplay.asm"
        INCLUDE "sound_effects.asm"
        INCLUDE "audio.asm"
        INCLUDE "file.asm"

Start:
        di                 ; disable interrupts

        ; Game runs best at 14MHz at which speed the whole game updates between bottom of ULA screen
        ; and top of screen, which allows the game to update and render with minimal latency.
        ; When a NEX is loaded it should default to 14MHz, but better to set explicitly. This is actually
        ; the case when launching from DeZog - the speed seems to revert to 3.5MHz, so need to set for dev purposes.
        nextreg NEXTREG_CPU_SPEED,NEXTREG_CPU_SPEED_FLAGS_14MHZ

        call InitInput
        call LoadHighScoreFile
        
        ; initialise audio before enabling interrupt to ensure TickAudio not called before InitAudio is complete
        call InitAudio

        call InitInterrupt

        ld a,BLACK
        SET_BORDER_COLOUR

        call ClearULAScreen
        call InitGame

MainLoop:

        ; Wait for scanline 192, so visible elements can be updated in the vertical blank to avoid tearing.
        ; This will also force the main loop to tick at "per frame" speed 50 or 60 FPS
        call WaitForScanlineUnderUla

        IF UPLOAD_SPRITE_ATTRIBUTES_FIRST
        PERF_BORDER_COLOUR RED ; Set the border to red at the start of the frame (immediately after ULA paper area)

        ; The raster position is now just past the bottom of the drawable screen so
        ; upload the sprite attributes ASAP to avoid tearing
        call UploadSpriteAttributes
        ENDIF
 
        ; Set border to green when the drawing is complete
        ; We don't want the red band to reach the upper part of the drawn region of the screen
        ; to avoid possible tearing
        PERF_BORDER_COLOUR GREEN

        ; Now that the sprites have been updated we can safely update the CPU side sprite state.
        call ReadInputDevices
        call UpdateGameState

        IF !UPLOAD_SPRITE_ATTRIBUTES_FIRST
        PERF_BORDER_COLOUR RED ; Set the border to red at the start of the frame (immediately after ULA paper area)

        ; Let's hope that the sprite attributes are uploaded before the raster starts to draw them
        ; else tearing!
        call UploadSpriteAttributes
        ENDIF

        call UpdateUI

        ; increment 8-bit frame count
        ld hl,frameCount8       ; HL = &frameCount
        inc (hl)

        ; increment 16-bit frames-in-state count
        ; TODO: Might not want to increment this if changed state this frame
        ld hl,(framesInState16)
        inc hl
        ld (framesInState16),hl

        ; Set border to black border when game update is complete
        PERF_BORDER_COLOUR BLACK

        jr MainLoop             ; infinite loop

;------------------------------------------------------------------------------------------------

InitInterrupt:
        ld a,im2VectorTable>>8  ; S <- interrupt vector table address MSB
        ld i,a                  ; I <- interrupt vector table address MSB
        im 2                    ; Interrupt Mode 2

        ; Disable ULA Interrupt and enable Line Interrupt
        ; Set bit 2 to disable original ULA interrupt
        ; Set Bit 1 to enable Line Interrupt
        ; Bit 0 is the MSb of Line Interrupt line value (default 0)
        nextreg NEXTREG_LINE_INTERRUPT_CONTROL,%110

        ; Set 8 eight LSbs of the line on which the line interrupt should occur.
        ; 0 = top of ULA area
        ; 192 = 1 pixel below bottom of ULA area
        ; n.b. MSb is RASTER_INTERRUPT_CONTROL_REGISTER bit 0 
        ;
        ; We set the line interrupt to occur near the bottom of the ULA screen because at that point
        ; the graphics update starts (to avoid tearing). Even at 3.5MHz, this gives the graphics and game update 
        ; plenty of time to update and the interrupt should fire when the CPU is busy waiting for the ULA
        ; to finish drawing.
        ; If the amount of work in the interrupt increases and starts to crash the bottom of the ULA
        ; then may need to reduce this. 
        nextreg NEXTREG_LINE_INTERRUPT_VALUE_LSB,160

        ei                      ; Enable Interrupts

        ret

;------------------------------------------------------------------------------------------------
; 
; Busy waits for the raster line (scanline) to reach just under ULA paper area, i.e. scanline 192
;
WaitForScanlineUnderUla:
        ; read NextReg $1F - LSB of current raster line
        ld      bc,PORT_NEXTREG_REGISTER_SELECT
        ld      a,NEXTREG_ACTIVE_VIDEO_LINE_LSB
        out     (c),a       ; select NextReg $1F
        inc     b           ; BC = TBBLUE_REGISTER_ACCESS_P_253B
        ; if already at scanline 192, then wait extra whole frame (for super-fast game loops)
.cantStartAt192:
        in      a,(c)       ; read the raster line LSB
        cp      192
        jr      z,.cantStartAt192
        ; if not yet at scanline 192, wait for it ... wait for it ...
.waitLoop:
        in      a,(c)       ; read the raster line LSB
        cp      192
        jr      nz,.waitLoop
        ; and because the max scanline number is between 260..319 (depends on video mode),
        ; we don't need to read MSB. 256+192 = 448 -> such scanline is not part of any mode.
        ret

CODE_END

;-----------------------------------------------------------------------------------------------------------------------    
; Stack [$B800,$BFFF]

STACK_BOTTOM     EQU $B800
STACK_SIZE_BYTES EQU $0800

        ASSERT CODE_END < STACK_BOTTOM ; Code has crashed the stack. Relocate stack

        ORG STACK_BOTTOM
        DS  STACK_SIZE_BYTES-2, $00
initialStackTop:
        DW  $0000

;-----------------------------------------------------------------------------------------------------------------------    
; Pattern data immediately after code. 
; TODO: This only needs to be paged in during initialisation, so could be moved
; to another page/bank and paged out to free up memory if required.
PATTERN_DATA_START
        INCLUDE  "sprite_data.asm"  ;  include sprite pattern and palette data
PATTERN_DATA_END

AYFX_DATA_START
pAyfxSoundEffectsBank INCBIN "../data/invaders.afb"    ; effects bank address
AYFX_DATA_END

;-----------------------------------------------------------------------------------------------------------------------    
; Interrupt handler routine
; Called once per frame at raster position configured by Line Interrupt
; See interrupt samples for more information

        ORG $FCFC
        ASSERT ($ >> 8) == ($ & $ff) ; IM2 interrupt handler address high byte and low byte must be equal
InterruptHandler:
        ; push all registers from the stack
        ; n.b. In practice only need to preserve registers that are modified by this routine
        push af

        PERF_BORDER_COLOUR MAGENTA ; n.b. modifies A so must call after PUSH AF

        push bc
        push de
        push hl
        push ix
        push iy
        ex af,af'
        exx             ; swaps BC, DE and HL with their shadow registers
        push af
        push bc
        push de
        push hl

        call TickMusic
        call AyfxFrameUpdate

        ; restore all registers from the stack
        pop hl
        pop de
        pop bc
        pop af
        exx
        ex af,af'
        pop iy
        pop ix
        pop hl
        pop de
        pop bc

        PERF_BORDER_COLOUR BLACK ; n.b. modifies A so must call before POP AF

        pop af

        ei      ; enable interrupts for next time

        reti    ; technically must use reti, but ret is fine on Spectrum hardware

;-----------------------------------------------------------------------------------------------------------------------    
; Interrupt Mode 2 Vector Table
; See interrupt samples for more information
        ORG $FE00
        ASSERT ($ >= $8000) ; IM2 table must be not be in contended RAM
        ASSERT ($ & $00ff) == 0  ; IM2 table must be 256-byte aligned
        ASSERT ($10000 - $) >= 257 ; Not enough room for IM2 table (257 bytes required)
im2VectorTable:
        ASSERT (InterruptHandler >> 8) == (InterruptHandler & $ff) ; IM2 interrupt handler address high byte and low byte must be equal
        DS 257,InterruptHandler>>8      ; 257 bytes containing MSB of interrupt handler routine

;-----------------------------------------------------------------------------------------------------------------------    

PROGRAM_END

;-----------------------------------------------------------------------------------------------------------------------    

        DISPLAY "Code start:           ",/H,CODE_START
        DISPLAY "Code end:             ",/H,CODE_END
        DISPLAY "Code size:            ",/H,CODE_END-CODE_START
        DISPLAY "Code free bytes:      ",/H,STACK_BOTTOM-CODE_END-1
        DISPLAY "Stack bottom:         ",/H,STACK_BOTTOM
        DISPLAY "Stack size (bytes):   ",/H,STACK_SIZE_BYTES
        DISPLAY "Pattern data start:   ",/H,PATTERN_DATA_START
        DISPLAY "Pattern data end:     ",/H,PATTERN_DATA_END
        DISPLAY "Pattern data size:    ",/H,PATTERN_DATA_END-PATTERN_DATA_START
        DISPLAY "AYFX bank start:      ",/H,AYFX_DATA_START
        DISPLAY "AYFX bank end:        ",/H,AYFX_DATA_END
        DISPLAY "AYFX bank size:       ",/H,AYFX_DATA_END-AYFX_DATA_START
        DISPLAY "Data free bytes:      ",/H,InterruptHandler-AYFX_DATA_END-1
        DISPLAY "Program size:         ",/H,PROGRAM_END-PROGRAM_START

;-----------------------------------------------------------------------------------------------------------------------    
; --- Create the main .nex file ---
        SAVENEX OPEN "bin/invaders.nex", Start, initialStackTop
        SAVENEX CORE 3, 0, 0
        SAVENEX AUTO
        SAVENEX CLOSE

; -- Create a map file for CSpect debugging ---
        CSPECTMAP "bin/invaders.map"
