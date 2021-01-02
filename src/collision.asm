
UpdateCollisions:       
        call collideShipBulletWithInvaders
        call collideShipBulletWithUfo
        call collideShipBulletWithShields
        call collideInvaderBulletsWithShip
        jp collideInvaderBulletsWithShields   ; jp instead of call xxxx : ret saves 1 byte and 17 T-states
               
;
; Collide ship bullet hitbox with each (live) invader hitbox
; This is an expensive routine!
;
collideShipBulletWithInvaders:

        ; return if ship bullet is not active
        ld a,(shipBulletActive)
        and a                                           ; set Z flag if bullet is inactive
        ret z                                           ; return if not active

        ld b,INVADER_COUNT                              ; loop over all invaders
        ld hl,(pActiveInvaders)                         ; HL = &invaders[activePlayerIndex][0]
.loop   ASSERT Invader.active == 0
        ld a,(hl)                                       ; A <- invader.active
        and a                                           ; Set Zero flag
        jp z,.nextInvader                               ; jump if invader not active 

        ; call CollideHitboxes
        push bc                                         ; push loop count
        push hl                                         ; push &invader

        ; DE <- &invader.hitboxScreenSpace
        add hl,Invader.hitboxScreenSpace                ; HL = &invader.hitboxScreenSpace
        ld d,h                                          ; fake instruction : ld de,hl
        ld e,l                                          ; ... DE <- &invader.hitboxScreenSpace

        ld hl,shipBulletHitboxScreenSpace               ; HL = &shipBulletHitboxScreenSpace
        call CollideHitboxes                            ; CF <- 0 if overlapping
        pop hl                                          ; HL = &invader (does not affect flags)
        pop bc                                          ; pop loop count (does not affect flags)
        jp c,.nextInvader                               ; jump of not overlapping

        ; bullet hit invader

        push hl                                         ; push &invader
        call SetDeltaScoreForInvader
        pop hl                                          ; HL = &invader

        call DestroyInvader
        call ResetShipBullet

        ld hl,liveInvaderCount
        dec (hl)                                        ; liveInvaderCount--

        ; play sound effect
        ld a,SOUND_EFFECT_INDEX_INVADER_DESTROYED
        ld b,SOUND_EFFECT_CHANNEL_INVADER
        call AyfxPlayEffect

        ret

.nextInvader
        add hl,Invader                                  ; HL += sizeof(Invader); HL <- &invaders[i+1].type
        djnz .loop
        ret


collideShipBulletWithUfo:

        ; early out if ship bullet not active
        ld a,(shipBulletActive)
        and a                                           ; set Z flag if not active
        ret z

        ; early out if UFO not active
        ld a,(ufoState)
        cp UFO_STATE_ACTIVE                             ; set Z flag if ufoState == UFO_STATE_ACTIVE
        ret nz                                           ; return if one or both are inactive

        ld de,shipBulletHitboxScreenSpace
        ld hl,ufoHitboxScreenSpace
        call CollideHitboxes                            ; CF <- 0 if overlapping
        ret c                                           ; return if carry set, meaning not overlapping

        ; bullet hit UFO
        call DestroyUfo

        ; call SetDeltaScoreForUfo before ResetShipBullet because when a bullet is destroyed
        ; it increments counters
        call SetDeltaScoreForUfo

        call ResetShipBullet

        ret


collideShipBulletWithShields:

        ; return if ship bullet is not active
        ld a,(shipBulletActive)
        and a                                           ; set Z flag if bullet is inactive
        ret z                                           ; return if not active

        ld a,(shipBulletHitboxScreenSpace+Hitbox.x0)
        sub a,32        ; transform from sprite space to ULA space (32 pixel border around ULA)
        ld e,a          ; E <- bullet pos ULA space
        setae           ; A <- pixel mask
        ld c,a          ; C <- pixel mask       

        ; The ship bullet is 4 pixels tall travels at 4 pixels per frame upwards (-y direction)
        ASSERT SHIP_BULLET_SPEED <= SHIP_BULLET_HEIGHT ; handle bullet-through-paper!
       
        ; Collide from bullet hitbox y1 (bottom) to y0 (top) so simulates colliding with lower
        ; parts of the shield first. 

        ; Collide each row of pixel data from bottom up
        ld b,SHIP_BULLET_HEIGHT                         ; loop counter
        ld a,(shipBulletHitboxScreenSpace+Hitbox.y1)
        sub a,32        ; transform to ULA space
        ld d,a          ; D <- bullet ULA y pos
.loopY  pixelad         ; HL <- ULA pixel byte address
        ld a,(hl)       ; A <- 8 pixel bits
        and c           ; test against pixel mask, set Z flag if no pixels overlap
        jp z,.nextY

        ; bullet hit pixels
        call BlowHoleInShields
        call ResetShipBullet
        ret

.nextY  dec d           ; next row up
        djnz .loopY

        ret


collideInvaderBulletsWithShip:

        ld hl,invaderBullets
        ld b,INVADER_BULLET_COUNT
.loop   ASSERT InvaderBullet.active == 0 ; this routine relies on zero offset for member 'active'
        ; set Zero flag if invader bullet not active
        ld a,(hl)                                       ; A <- active
        and a                                           ; Set Zero flag
        jr z,.next                                      ; jump if not active

        push bc                                         ; push loop count
        push hl                                         ; push InvaderBullet address
        add hl,InvaderBullet.hitboxScreenSpace          ; HL <- address of S_INVADER_BULLET.hitboxScreenSpace
        ld d,h                                          ; fake instruction : ld de,hl
        ld e,l                                          ; ...

        ld hl,shipHitboxScreenSpace
        call CollideHitboxes    ; CF <- 0 if overlapping
        jr c,.nohit   ; return if not overlapping

        ; bullet hit ship
        pop hl                                          ; pop InvaderBullet address
        pop bc                                          ; pop loop count

        ; flag ship as destroyed
        ld a,1
        ld (destroyed),a                                ; destroyed <- 1

        call ResetInvaderBullet

        ret                                             ; no point testing other bullets

.nohit  pop hl                                          ; pop InvaderBullet address
        pop bc                                          ; pop loop count
        ; TODO: Might want to early out here if CF is reset meaning the ship was hit
.next   add hl,InvaderBullet                            ; HL += sizeof(STRUCT S_INVADER_BULLET)
        djnz .loop
        ret

;
; Collide all active invader bullets with shields
;
collideInvaderBulletsWithShields:

        ld hl,invaderBullets
        ld b,INVADER_BULLET_COUNT
.loop   ASSERT InvaderBullet.active == 0 ; this routine relies on zero offset for member 'active'
        ; set Zero flag if invader bullet not active
        ld a,(hl)                                       ; A <- active
        and a                                           ; Set Zero flag
        jp z,.next                                      ; jump if not active

        push hl                                         ; push InvaderBullet address
        push bc
        call collideInvaderBulletWithShields
        pop bc
        pop hl

.next   add hl,InvaderBullet                            ; HL += sizeof(STRUCT S_INVADER_BULLET)
        djnz .loop
        ret

;
; Collides a single invader bullet with the shields
; HL = address of InvaderBullet
; Modifies: AF, BC, DE, HL, IXH
; 
collideInvaderBulletWithShields:

        push hl                         ; push InvaderBullet address
        add hl,InvaderBullet.hitboxScreenSpace.x0

        ld a,(hl)       ; A <- hitbox x0 (screen/sprite space)
        sub a,32        ; transform from sprite space to ULA space (32 pixel border around ULA)
        ld e,a          ; E <- bullet pos ULA space
        
        ; Collide invader bullet bottom (y1) with shield
        ASSERT INVADER_BULLET_SPEED == 1 ; algorithm need to be updated to test range of Y
        ASSERT Hitbox.x0 + 3 == Hitbox.y1
        add hl,3        ; HL = &hitbox.y1
        ld a,(hl)       ; A <- hitbox.y1
        sub a,32        ; transform to ULA space
        ld d,a          ; D <- bullet ULA y pos

        ; don't try to colide past bottom of ULA pixel screen
        cp 192          ; y-192, resets CF when y >= 192
        jp nc,.done

        ld b,3          ; Invader bullets are 3 wide, so loop over 3 pixels horizontally
.loopX  setae           ; A <- pixel mask
        ld c,a          ; C <- pixel mask       
        pixelad         ; HL <- ULA pixel byte address
        ld a,(hl)       ; A <- 8 pixel bits
        and c           ; test against pixel mask, set Z flag if no pixels overlap
        jp nz,.hit

        inc e           ; x++
        djnz .loopX

.done   pop hl          ; restore stack
        ret

.hit    call BlowHoleInShields
        pop hl          ; HL <- &InvaderBullet
        call ResetInvaderBullet
        ret

;
; Collides an invader hitbox with the shields and removes any shields that it overlaps
; Call when an invader has been moved and its hitbox has been updated.
; HL = address of Invader
; Modifies: AF, B, DE, HL
;
CollideInvaderWithShields:

        add hl,Invader.hitboxScreenSpace        ; HL <- &invader.hitboxScreenSpace

        ; All shields are at the same height so we can earl out
        ; if Invader.hitboxScreenSpace.y1 < SHIELD_Y_SCREEN_SPACE
        add hl,Hitbox.y1                ; HL <- &invader.hitboxScreenSpace.y1
        ld a,(hl)                       ; A <- invader.hitbox.y1
        cp SHIELD_Y_SCREEN_SPACE        ; invader.hitbox.y1 - SHIELD_Y_SCREEN_SPACE
        ret c                           ; return if invader.hitbox.y1 < SHIELD_Y_SCREEN_SPACE
        add hl,-Hitbox.y1               ; HL <- &invader.hitboxScreenSpace

        ld de,shieldHitboxes
        ld b,SHIELD_COUNT                       ; .shieldLoop counter
        ld c,1                                  ; %0001 mask for shield 0
.shieldLoop
        ; Check that shield is not already destroyed before performing collision detection
        ld a,(shieldState)      ; bits 0-3 set if shield 0-3 is still active (not already destroyed)
        and c                   ; set z flag if shield is already destroyed
        jp z,.next              ; jump if shield already destroyed

        push bc
        push de
        push hl                 ; push &invader.hitboxScreenSpace
        call CollideHitboxes    ; CF <- 0 if overlapping
        pop hl                  ; HL <- &invader.hitboxScreenSpace (POP does not affect flags)
        pop de
        pop bc
        jp c,.next              ; jump if not overlapping

        ld a,c
        call DestroyShield
        ret                     ; return - assumes an invader cannot overlap mutiple shields simultaneously

.next   add de,Hitbox           ; DE <- address of next shield hitbox
        sla c                   ; A << 1, shift shield mask to next bit
        djnz .shieldLoop

        ret
