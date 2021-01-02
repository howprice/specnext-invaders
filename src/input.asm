
; bits encoding inputs as Kempston/MD: https://wiki.specnext.dev/Kempston_Joystick
INPUT_BIT_RIGHT           EQU     0
INPUT_BIT_LEFT            EQU     1
INPUT_BIT_DOWN            EQU     2
INPUT_BIT_UP              EQU     3
INPUT_BIT_FIRE            EQU     4
INPUT_BIT_PLAYER_1_START  EQU     5
INPUT_BIT_PLAYER_2_START  EQU     6

inputBits:                DB 0  ; combined keyboard and joystick input bits
inputBitsPreviousFrame    DB 0
inputPressed:             DB 0  ; pressed means "pressed this frame" i.e. up last frame and down this frame

;-------------------------------------------------------------------------------------------------------------------

InitInput:

        ; NEXTREG_PERIPHERAL_1 sets joystick modes as well as video frequency and scandoubler
        ; we want to preserve the video frequency and scandoubler bits

        ; read NextReg
        ld bc,PORT_NEXTREG_REGISTER_SELECT
        ld a,NEXTREG_PERIPHERAL_1
        out (c),a       ; select NextReg
        inc b           ; BC = TBBLUE_REGISTER_ACCESS_P_253B
        in a,(c)        ; A <- NextReg
        and %101        ; preserve video frequency and scandoubler bits
        ld d,a

        ; Joystick 1 mode %001 Kempston 1 (port 0x1F) bits 3,7,6
        ; Joystick 2 mode %100 Kempston 2 (port 0x37) bits 1,5,4
        ld a,%01000010
        or d                            ; merge in video and scandoubler bits
        nextreg NEXTREG_PERIPHERAL_1,a

        ret
;
; Keyboard Input
;
; Row  Port     Bit 0,1,2,3,4
; -----------------------------------
; 0    $fefe    SHIFT, Z, X, C, V
; 1    $fdfe    A, S, D, F, G     
; 2    $fbfe    Q, W, E, R, T     
; 3    $f7fe    1, 2, 3, 4, 5
; 4    $effe    0, 9, 8, 7, 6
; 5    $dffe    P, O, I, U, Y
; 6    $bffe    ENTER, L, K, J, H
; 7    $7ffe    SPACE, SYM SHFT, M, N, B
;
; n.b. Bits are set to 0 for any key that is pressed and 1 for any key that is not pressed.
;
; See http://www.breakintoprogram.co.uk/computers/zx-spectrum/keyboard/

;
; Reads joystick and keyboard input and combines into inputBits
; Space Invaders doesn't need up and down inputs, but they are in the Kempston
; bits so might as well read from keyboard too.
; Modifies: A, DE
; 
ReadInputDevices:
        ; read Kempston joystick ports first (active high)
        in a,(PORT_KEMPSTON_JOY1)    ; A <- Kempston joystick 1 input bits (---FUDLR)
        ld e,a                          ; E = joystick 1 bits
        
        ; set INPUT_BIT_PLAYER_1_START if joystick 1 fire pressed
        ASSERT INPUT_BIT_PLAYER_1_START == (INPUT_BIT_FIRE + 1) ; logic assumes this
        and 1<<INPUT_BIT_FIRE           ; mask off everything put the fire bit
        add a,a                         ; shift accumulator left, so fire bit becomes P1 start bit
        or e                            ; combine INPUT_BIT_PLAYER_1_START with joystick 1 bits
        ld e,a                          ; store in E

        in a,(PORT_KEMPSTON_JOY2)    ; A <- Kempston joystick 2 input bits (---FUDLR)
        ld d,a                          ; D = joystick 2 bits

        ; set INPUT_BIT_PLAYER_1_START if joystick 1 fire pressed
        ASSERT INPUT_BIT_PLAYER_2_START == (INPUT_BIT_FIRE + 2) ; logic assumes this
        and 1<<INPUT_BIT_FIRE           ; mask off everything put the fire bit
        add a,a                         ; shift accumulator left ...
        add a,a                         ; ... twice so fire bit becomes P2 start bit
        or d                            ; combine INPUT_BIT_PLAYER_2_START with joystick 2 bits

        or e                            ; A <- combined joystick 1, joystick 2 and P1/P2 start bits
        ld e,a
        
        ; read keyboard QAOP and <space>
        ld d,$FF                        ; keyboard reading bits are 1=released, 0=pressed -> $FF = no key

        // read space bar (Fire)
        ld a,~(1<<7)                    ; keyboard row 7
        in a,(PORT_SPECTRUM_ULA)         ; A = ~%---<space><symbol shift>MNB
        rrca                            ; CF = ~<space>
        rl d                            ; rotate D left and carry into bit 0. D = ~%0000000F

        // read Q key (Up)
        ld a,~(1<<2)                    ; keyboard row 2
        in a,(PORT_SPECTRUM_ULA)         ; A = ~%---TREWQ
        rrca                            ; CF = ~Q
        rl d                            ; rotate D left and carry into bit 0. D = ~%000000FU 

        ; read A key (Down)
        ld a,~(1<<1)                    ; keyboard row 1
        in a,(PORT_SPECTRUM_ULA)         ; A = ~%---GFDSA
        rrca                            ; CF = ~A
        rl d                            ; rotate D left and carry into bit 0. D = ~%00000FUD 

        ; read O and P keys (left and right)
        ld a,~(1<<5)                    ; keyboard row 5
        in a,(PORT_SPECTRUM_ULA)         ; A = ~%---YUIOP
        rra                             ; A = ~%----YUIO  CF = ~P
        rra                             ; A = ~%P----YUI  CF = ~O
        rl d                            ; rotate D left and carry into bit 0. D = ~%0000FUDL
        rla                             ; A = ~%----YUIO  CF = ~P
        ld a,d                          ; A = ~%0000FUDL  CF = ~P
        rla                             ; A = ~%000FUDLR
        cpl                             ; A = %000FUDLR

        or e                            ; A = combined QAOP<space> and joystick bits
        ld e,a                          ; E = combined QAOP<space> and joystick bits (---FUDLR)

        ; cursor keys FUDLR map to keys 0,7,6,5,8
        ld d,$FF                        ; keyboard reading bits are 1=released, 0=pressed -> $FF = no key

        ; read keys 6,7,8,0 (Down, Up, Right, Fire)
        ld a,~(1<<4)                    ; keyboard row 4 
        in a,(PORT_SPECTRUM_ULA)         ; A = ~%---67890 == ~%---DUR-F
        rra                             ; A = ~%----DUR-  CF = ~F
        rl d                            ; rotate D left and carry into bit 0. D = ~%0000000F  CF = ~0
        rra                             ; A = ~%-----DUR  CF = ~0
        rra                             ; A = ~%------DU  CF = ~R
        rra                             ; A = ~%R------D  CF = ~U
        rl d                            ; rotate D left and carry into bit 0. D = ~%000000FU  CF = ~0
        rra                             ; A = ~%0R------  CF = ~D
        rl d                            ; rotate D left and carry into bit 0. D = ~%00000FUD  CF = ~0
        rla                             ; A = ~%R-------  CF = ~0
        rla                             ; CF = ~R

        ; read key 5 (Left)
        ld a,~(1<<3)                    ; keyboard row 3
        in a,(PORT_SPECTRUM_ULA)         ; A = ~%---54321 == ~%---L----  CF = ~R
        rla                             ; A = ~%--L----R
        rla                             ; A = ~%-L----R-
        rla                             ; A = ~%L----R--
        rla                             ; A = ~%----R---  CF = ~L
        rl d                            ; rotate D left and carry into bit 0. D = ~%0000FUDL  CF = ~0
        rra                             ; A = ~%-----R--
        rra                             ; A = ~%------R-
        rra                             ; A = ~%-------R
        rra                             ; CF = ~R
        rl d                            ; rotate D left and carry into bit 0. D = ~%000FUDLR

        ld a,d                          ; A = ~%000FUDLR
        cpl                             ; A = %000FUDLR
        or e                            ; A = combined QAOP<space>, cursor keys and joystick bits
        ld e,a                          ; E = combined QAOP<space>, cursor keys and joystick bits

        ; read player 1 and player 2 start buttons (keys 1 and 2)
        ; Player 2 start is inputBits bit 6
        ; Player 1 start is inputBits bit 5
        ld a,~(1<<3)                    ; keyboard row 3
        in a,(PORT_SPECTRUM_ULA)         ; A = ~%---54321 == ~%------21
        rla                             ; A = ~%-----21-
        rla                             ; A = ~%----21--
        rla                             ; A = ~%---21---
        rla                             ; A = ~%--21----
        rla                             ; A = ~%-21-----
        cpl                             ; A = %-21-----
        and %01100000                   ; A = %02100000
        or e                            ; A = combined QAOP<space>, cursor keys, joystick and start button bits

        ld (inputBits),a                ; store

        ; pressed = 0 last frame and 1 this frame
        ld b,a
        ld a,(inputBitsPreviousFrame)
        cpl
        and b
        ld (inputPressed),a

        ld a,b
        ld (inputBitsPreviousFrame),a

        ret
