EXPLOSION_DISPLAY_TIME_FRAMES EQU 8

explosionCountdown DB $00

;
; Call every frame to update explosion sprite
;
UpdateExplosion:

    ld a,(explosionCountdown)
    and a                       ; set Zero flag if zero
    ret z                       ; return if not active

    dec a
    ld (explosionCountdown),a                    
    ret nz                      ; return if not finished

    ; finished - hide explosion
;   xor a                       ; A <- 0  Instrucion redundant - A already known to be zero
    ld (explosionSprite+SpriteAttributes.vpat),a 

    ret

ResetExplosion:
    xor a                                           ; A <- 0
    ld (explosionCountdown),a                    
    ld (explosionSprite+SpriteAttributes.vpat),a 
    ret
