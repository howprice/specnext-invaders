;-Minimal ayFX player v0.15 06.05.06---------------------------;
;                                                              ;
; From: https://shiru.untergrund.net/software.shtml#old        ;
; Fixed up for sjasmplus and translated into English           ;
;                                                              ;
; "All of my projects here are free to use and distrubute."    ;
; - https://shiru.untergrund.net/donate.shtml                  ;
;                                                              ;
; The simplest effects player. Plays effects on one AY,        ; 
; without background music.                                    ;
;                                                              ;
; Initialization:                                              ;
;   ld hl, effects bank address                                ;
;   call AFXINIT                                               ;
;                                                              ;
; Launching an effect:                                         ;
;   ld a, effect index [0,255]                                 ;
;   ld b, channel index  [0,2]                                 ;
;   call AFXPLAY                                               ;
;                                                              ;
; In the interrupt handler:                                    ; 
;   call AFXFRAME                                              ;
;                                                              ;
;--------------------------------------------------------------;
; AFB file format
; 
; An AFB file is a bank of AFX samples (see below)
;
; Header:
; +0 (1 byte) Total number of effects in the bank, up to 256 (0 means 256);
; +1 (2 bytes per effect) Table of offsets to data of every effect. Offset 
; value is given relative to the second byte of the offset itself
; 
; Data:
; The effects data, format is the same as in the single effect file. After every 
; effect there could be a null terminated text string with name of the effect. 
; It may absent, if the bank was saved into a file using corresponding item of the File
; menu, in this case null terminator bytes are absent as well.
;
;--------------------------------------------------------------
; AFX file format
;
; An AFX file is a single effect. An effect is composed of a list of frames.
;
; Every frame is encoded with a flag byte followed by optional data bytes
; 
; Bit 7     Disable Noise
; Bit 6     Change Noise Period
; Bit 5     Change Tone Period
; Bit 4     Disable Tone
; Bits 3-0  Volume
; 
; - If bit 5 is set, two bytes with tone period will follow (little endian)
; - If bit 6 set, a single byte with noise period will follow
; - when both bits are set, first two bytes of tone period, then single byte with noise period will follow. 
; - When none of the bits are set, next flags byte will follow.
; 
; Note that disable noise and tone bits 7 and 4 are spaced apart by 3 bits and active low
; just like AY "mixer" register 7
;
; End of the effect is marked with byte sequence $D0 $20 (disable noise, change noise period, disable tone, 
; noise period = $20 (invalid value: max 5 bit value + 1)
; Player should detect it before outputting it to the AY registers, by checking noise period value to 
; be equal $20. The editor considers last non-zero volume value as the last frame of an effect, other 
; parameters aren't matter.


; channel descriptors, 4 bytes per channel:                       
        STRUCT AyfxChannelState
pCurrentEffectFrame DW $0000  ; Pointer to current frame of effect data. Channel is free if high byte = $00
pFirstEffectFrame   DW $0000  ; Pointer to first frame of effect data (for looping effects)
loop                DB $00    ; effect loops if non zero
        ENDS 
        
AYFX_CHANNEL_COUNT EQU 3    ; single AY-3 chip   

ayfxChannelState DS AYFX_CHANNEL_COUNT * AyfxChannelState  

;
; Initialises the sound effects player.
; Call once during application initialisation, and before enabling interrupts
; Initialises Ayfx internal state and zeros AY-3 registers [0,14]
; HL = Effects Bank Address (pointer to .afb file)
; Modifies: AF, BC, DE, HL
;
AyfxInit:

        inc hl                  ; HL <- address of offset of offset table
        ld (pAfbOffsetTable),hl ; store effects bank (AFB binary) offset table address
        
        xor a                   ; A <- 0
        ld (pAyfxNoisePeriod),a  ; afxNoisePeriod <- 0

        ; mark all channels as empty
        ld hl,ayfxChannelState  ; HL <- channelState.pEffect LSB
        ld de,$00ff             ; D,E <- channel desc initial values
        ld bc,(AYFX_CHANNEL_COUNT<<8)|$fd        ; B <- channel loop count; C <- AY port address LSB (for subsequent loop)
.channelStateLoop
        ASSERT (AyfxChannelState == 5) ; logic assumes this
        ld (hl),d               ; channelState.pCurrentEffectFrame LSB <- $00
        inc hl                  ; HL <- &channelState.pCurrentEffectFrame MSB
        ld (hl),d               ; channelState.pCurrentEffectFrame MSB <- $00
        inc hl                  ; HL <- &channelState.pFirstEffectFrame LSB
        ld (hl),d               ; channelState.pFirstEffectFrame LSB <- $00
        inc hl                  ; HL <- &channelState.pFirstEffectFrame MSB
        ld (hl),d               ; channelState.pFirstEffectFrame MSB <- $00
        inc hl                  ; HL <- &channelState.loop
        ld (hl),0               ; not looping
        inc hl                  ; HL <- next channelState.address LSB (or one past last one)
        djnz .channelStateLoop

        ; Select AY1 (second AY chip) left and right audio
        ld bc,PORT_TURBO_SOUND_NEXT_CONTROL
        ld a,%11111110
        out (c),a
        
        ; Zero AY registers [0,13]
        ; n.b. In the original code this was trying to write to registers [0,$14] hex, which seems like a bug
        ld hl,$ffbf             ; load H and L with MSB of port so can quickly toggle between $FFFD and $BFFD 
        ld e,14                 ; E <- AY register index 14 (one above the first one to be cleared)
.regLoop
        dec e                   ; regIndex--, and set Zero flag if last one (LD and OUT do not affect flags)
        ld b,h                  ; BC <- $FFFD (TURBO_SOUND_NEXT_CONTROL_PORT)
        out (c),e               ; select register
        ld b,l                  ; BC <- $BFFD (SOUND_CHIP_REGISTER_WRITE_PORT)
        out (c),d               ; write value of zero to register
        jr nz,.regLoop          ; next register

        ; Special case here to initialise "mixer" register 7
        ; because the 6 bits need to be set to 1 to disable sound.
        ld b,h                  ; BC <- $FFFD (TURBO_SOUND_NEXT_CONTROL_PORT)
        ld e,AY3_MIXER          ; E <- register index
        out (c),e               ; select register
        ld b,l                  ; BC <- $BFFD (SOUND_CHIP_REGISTER_WRITE_PORT)
        ld a,%00111111          ; disable noise and tone for channels A, B and C
        out (c),a               ; write value of zero to register
        ld (pAyfxMixerFlags),a   ; store current value 

        ret

;
; Play the current frame. Call from raster interrupt handler
; Modifies: AF, BC, DE, HL, IX
;
AyfxFrameUpdate

        ; Select AY1 (second AY chip) left and right audio
        ld bc,PORT_TURBO_SOUND_NEXT_CONTROL
        ld a,%11111110
        out (c),a

        ld bc,(AYFX_CHANNEL_COUNT<<8)|$fd  ; B <- channel loop counter, C <- LSB of port address $FFFD and $BFFD
        ld ix,ayfxChannelState  ; IX = &channelState[0]

.channelLoop
        push bc                 ; push channel loop counter
        
        ld a,(ix+AyfxChannelState.pCurrentEffectFrame+1)  ; A <- effect frame address MSB
        and a                   ; set Z flag if effect frame address MSB == 0
        jr z,.nextChannel       ; jump to next channel if effect frame MSB address is zero (does not modify A)

        ld h,a                  ; H <- effect frame address MSB
        ld l,(ix+AyfxChannelState.pCurrentEffectFrame) ; L <- effect frame address LSB, HL <- effect frame address
        ld e,(hl)               ; E <- effect frame info byte
        inc hl                  ; HL <- frame data byte or next frame info byte

        ld a,11                 ; calculate the amplitude register index for this channel:
        sub b                   ; A <- channel amplitude register index (11-3=8, 11-2=9, 11-1=10)
        ld d,b                  ; D <- channel amplitude register index (for subseqent Tone register calculation)
        ld b,$ff                ; BC <- $FFFD
        out (c),a               ; select AY amplitude register

        ld b,$bf                ; BC <- $BFFD
        ld a,e                  ; A <- effect frame info byte
        and $0f                 ; Keep only 4-bit volume from lower nibble
        out (c),a               ; write channel amplitude AY register value
        
        bit 5,e                 ; Tone Period change?
        jr z,.noise             ; jump if no change
        
        ld a,3                  ; select the tone registers:
        sub d                   ; A <- channel fine Tone Period reg index: 3-3=0, 3-2=1, 3-1=2
        add a,a                 ; 0*2=0, 1*2=2, 2*2=4
        ld b,$ff                ; BC <- $FFFD
        out (c),a               ; select channel fine tone period register

        ld b,$bf                ; BC <- $BFFD SOUND_CHIP_REGISTER_WRITE_PORT
        ld d,(hl)               ; D <- fine tone period data byte
        inc hl                  ; HL <- address of coarse tone period data byte
        out (c),d               ; write channel fine tone period register value

        ld b,$ff                ; BC <- $FFFD
        inc a                   ; registerIndex++, A <- channel coarse tone period register index
        out (c),a               ; select channel coarse tone period register

        ld b,$bf                ; BC <- $BFFD SOUND_CHIP_REGISTER_WRITE_PORT
        ld d,(hl)               ; D <- coarse tone period data byte
        inc hl                  ; HL <- address of noise period data byte or next frame info byte
        out (c),d               ; write channel coarse tone period register value
        
.noise  bit 6,e                 ; Noise Period change?
        jr z,.mixer             ; jump if no change
        
        ld a,(hl)               ; A <- noise period data value
        cp $20                  ; set Z flag if Noise Period value equals special value $20 meaning end of effect (see file format)
        jr nz,.afxFrame2        ; jump if not end of effect

        ; end of effect unless looping
        ld a,(ix+AyfxChannelState.loop)
        and a                           ; set Z flag if not looping
        jr z,.noLoop                    ; jump if not a looping effect
        
        ; looping effect - start again at first frame
        ld l,(ix+AyfxChannelState.pFirstEffectFrame)
        ld h,(ix+AyfxChannelState.pFirstEffectFrame+1)
        ld (ix+AyfxChannelState.pCurrentEffectFrame),l    ; store channelState.pEffect frame pointer LSB
        ld (ix+AyfxChannelState.pCurrentEffectFrame+1),h  ; ...                                      MSB
        pop bc                  ; B <- channel loop index
        jr .channelLoop         ; process this channel again (to avoid blank frame)

.noLoop ; effect has finished
        ld hl,$0000             ; null pCurrentEffectFrame
        jr .storeChannelState
        
.afxFrame2
        inc hl                  ; HL <- address of next frame info byte
        ld (pAyfxNoisePeriod),a  ; save the noise period
        
.mixer
        pop bc                  ; B <- channel loop counter
        push bc

        ; Channel Mask for disable noise and tone flags.
        ; This allows us to toggle the noise and tone for a single channel at a time, while leaving others unchanged.
        ; Note that the frame info byte disable noise and tone bits 7 and 4 are spaced apart by 3 bits and 
        ; active low just like AY "mixer" register 7, so the mask will be shifted right to map to the noise and tone 
        ; flags for this channel in the AY mixer register.
        ; 0 bits will be taken from the new frame byte value (currently in E)
        ; 1 bits will be preserved
        ld a,%01101111	        

        ; Calculate right shift count for this channel to go from info bits to AY register 7 bits
        inc b                   ; B <- right shift count {0,1,2} = {4,3,2}
        
        ; n.b. at this point E = frame info byte
.mixerShiftLoop
        rrc e                   ; right shift frame flags
        rrca                    ; right shift mask
        djnz .mixerShiftLoop
        ld d,a                  ; D <- shifted inverted mask
        
        ; update mixer flags using the XOR-AND-XOR process:
        ;   newValue = (((currentValue XOR xorMask) AND andMask) XOR xorMask)
        ; This inserts the bits of the XOR Mask (frame byte) into the bit locations where the AND Mask (D) is 0.
        ; The other bits remain unchanged.
        ; mixer <- ((mixer XOR frameMask) AND channelMask) XOR frameMask
        ; Theory:
        ;   (A XOR E) XOR E = A  (1)
        ;   E XOR 0 = E          (2)
        ; So for the sequence xor e : and d : xor e
        ; - Bits that are 1 in D will be set to the value in A i.e. unchanged by the process
        ; - Bits that are 0 in D will have the value from E
        ; 
        ; Thanks to Ped7g https://discord.com/channels/556228195767156758/692885353161293895/787703316234240021
        ;
        ld bc,pAyfxMixerFlags    ; BC <- address of mixer flags
        ld a,(bc)               ; A <- current mixer register value
        xor e                   ; apply XOR mask
        and d                   ; apply AND mask
        xor e                   ; apply XOR mask
        ld (bc),a               ; store new mixer register value
        
.storeChannelState
        ld (ix+AyfxChannelState.pCurrentEffectFrame),l    ; store channelState.pEffect frame pointer LSB
        ld (ix+AyfxChannelState.pCurrentEffectFrame+1),h  ; ...                                      MSB
        
.nextChannel
        ld bc,AyfxChannelState  ; BC <- sizeof(ChannelState)
        add ix,bc               ; IX <- next channel state
        pop bc                  ; B <- channel loop index
        dec b                   ; DJNZ cannot be used here because target out of ragne
        jp nz,.channelLoop

        ; write to the AY3 Noise Period and Mixer registers
        ld hl,$ffbf             ; MSBs of the two ports $FFFD and $BFFD (LSB is common)

        ; Self modifying code. 3 byte instruction, last two bytes are written into n.b. little-endian
        ld de,$0000             ; D <- Mixer Flags, E <- Noise Period      
pAyfxNoisePeriod EQU $-2        ; Noise Period address
pAyfxMixerFlags  EQU $-1        ; Mixer Flags address

        ld a,AY3_NOISE_PERIOD   ; AY-3 register 6, AY3_NOISE_PERIOD
        ld b,h                  ; BC <- $FFFD TURBO_SOUND_NEXT_CONTROL_PORT (register select port)
        out (c),a               ; select register

        ld b,l                  ; BC <- $BFFD SOUND_CHIP_REGISTER_WRITE_PORT
        out (c),e               ; write noise period value to AY3_NOISE_PERIOD register
        
        inc a                   ; A <- 7, AY3_MIXER register
        ld b,h                  ; BC <- $FFFD TURBO_SOUND_NEXT_CONTROL_PORT (register select port)
        out (c),a               ; select register

        ld b,l                  ; BC <- $BFFD SOUND_CHIP_REGISTER_WRITE_PORT
        out (c),d               ; write mixer register value
        
        ret

;
; Triggers a sound effect on a specified channel.
; System only uses a single AY chip, so only 3 channels are available
; A = effect index  [0,255]
; B = channel index [0,2]
; Modifies: AF, BC, DE, HL
;
AyfxPlayEffect:

        ; calculate address of ChannelState struct
        ld c,a                  ; C <- effect index (for later)
        ld a,b                  ; A <- channel index [0,2]
        ASSERT (AyfxChannelState == 5) ; logic assumes this
        add a                   ; A = channelIndex * 2
        add a                   ; A = channelIndex * 4
        add b                   ; A = channelIndex * 5
        ld hl,ayfxChannelState  ; HL <- &ayfxChannelState[0]
        add hl,a                ; HL <- &ayfxChannelState[channelIndex]
        push hl

        ; calculate the address of the AFX effect in the AFB bank
        ld h,$00                ; H <- 0
        ld l,c                  ; L <- effectIndex [0,$ff]
        add hl,hl               ; HL <- 2 * effectIndex (word offset)
        ld bc,$0000             ; BC <- effect offset table address (self modifying code)
pAfbOffsetTable EQU $-2 ; address for self-modifying code
        add hl,bc               ; HL <- &effectOffsetTable[effectIndex]
        ld c,(hl)               ; C <- &effectOffset LSB
        inc hl                  ; n.b. Effect offset is relative to this second byte! (see AFB format above)
        ld b,(hl)               ; B <- &effectOffset MSB, BC <- &effectOffset
        add hl,bc               ; HL <- &effect (AFX format)
        
        ; store the effect address in the ChannelState struct
        ld d,h                  ; DE <- effect address
        ld e,l                  ; ...
        pop hl                  ; HL <- &channelState[channelIndex]

        ASSERT (AyfxChannelState == 5) && AyfxChannelState.pCurrentEffectFrame == 0 ; logic assumes this
        ld (hl),e               ; store pCurrentEffectFrame LSB
        inc hl                  ; 
        ld (hl),d               ; store pCurrentEffectFrame LSB
        inc hl
        ld (hl),e               ; store pFirstEffectFrame LSB
        inc hl                  ; 
        ld (hl),d               ; store pFirstEffectFrame LSB
        inc hl
        ld (hl),0               ; not looping
        ret

AyfxPlayEffectLooping
        call AyfxPlayEffect     ; HL <- channelState[n].loop
        ld (hl),1
        ret

;
; Stops a channel from playing. Useful for looping effects.
; A = Channel index [0,2]
; Modifies: ???
;
AyfxStopChannel:

        ; Zero the ChannelState.pCurrentEffectFrame which means the channel is empty
        ld b,a                  ; B <- channel index
        ASSERT (AyfxChannelState == 5) ; logic assumes this
        add a                   ; A = channelIndex * 2
        add a                   ; A = channelIndex * 4
        add b                   ; A = channelIndex * 5
        ld hl,ayfxChannelState  ; HL <- &ayfxChannelState[0]
        add hl,a                ; HL <- &ayfxChannelState[channelIndex]
        add hl,AyfxChannelState.pCurrentEffectFrame
        ld (hl),$00             ; LSB <- $00
        inc hl
        ld (hl),$00             ; LSB <- $00

        ; turn off the AY3 mixer flags for this channel (active low)
        ld e,%001001            ; bits to disable Noise and Tone for AY channel A
        bsla de,b               ; DE <<= B (we don't care about D)
        ld a,(pAyfxMixerFlags)
        or e
        ld (pAyfxMixerFlags),a   ; store current value 

        ret
