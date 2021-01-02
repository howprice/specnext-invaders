
LoadHighScoreFile:

        ; Open file for read
        ld a,'$'        ; use system drive (overridden by filespec anyway)    
        ld ix,filename  ; IX = filespec
        ld b,ESX_MODE_READ|ESX_MODE_OPEN_EXIST ; read from existing file
        CALL_ESXDOS F_OPEN
        ret c           ; return if failed to open file
        ld (filehandle),a       ; store returned file handle

        ; Read 2 bytes from file into buffer
        ASSERT HIGH_SCORE_SIZE_BYTES == 2 ; logic assumes this
        ld a,(filehandle)
        ld ix,highScoreBCD16
        ld bc,HIGH_SCORE_SIZE_BYTES
        CALL_ESXDOS F_READ

        ; Close file
        ld a,(filehandle)
        CALL_ESXDOS F_CLOSE

        ld hl,filehandle
        ld (hl),$00

        ret

SaveHighScoreFile:

        ; Open file for write
        ld a,'$'        ; use system drive (overridden by filespec anyway)    
        ld ix,filename  ; IX = filespec
        ld b,ESX_MODE_WRITE|ESX_MODE_OPEN_CREAT ; write to existing or new file
        CALL_ESXDOS F_OPEN
        ret c                   ; return if failed to open file n.b. CSpect always sets Carry Flag!
        ld (filehandle),a       ; store returned file handle

        ; Write buffer to file
        ld a,(filehandle)
        ld ix,highScoreBCD16    ; IX = address
        ld bc,HIGH_SCORE_SIZE_BYTES
        CALL_ESXDOS F_WRITE

        ; Close file
        ld a,(filehandle)
        CALL_ESXDOS F_CLOSE

        ld hl,filehandle
        ld (hl),$00

        ret
        
; n.b. Don't use full path to store in CWD (same directory as .nex)
; If used e.g. "C:/games/Next/SpecNextInvaders/invaders.sav" this would be too restrictive for the user.
filename   DB "invaders.sav",0  

filehandle DB $00
