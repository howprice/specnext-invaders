;
; NextZXOS provides an API but an esxDOS-compatible API is also available.
; The esxDOS-compatible API provides file-based calls for SD card access and is easier to use.
; More information can be found in:
; https://gitlab.com/thesmog358/tbblue/-/blob/master/docs/nextzxos/NextZXOS_and_esxDOS_APIs.pdf
; 
; To make a call, you only need to set up the entry parameters as indicated and
; perform a RST $08; DEFB hook_code. On return, registers AF,BC,DE,HL will all be
; changed. IX,IY and the alternate registers are never changed (except for
; M_P3DOS).

        MACRO CALL_ESXDOS hook_code
                rst $08
                DB hook_code
	ENDM

; (Note that the standard 48K BASIC ROM must be paged in to the bottom of memory,
; but this is the usual situation after starting a machine code program with a USR
; function call).
;
; Notice that error codes are different from those returned by +3DOS calls, and
; also the carry flag is SET for an error condition when returning from an esxDOS
; call (instead of RESET, as is the case for +3DOS).
;
; If desired, you can use the M_GETERR hook to generate a BASIC error report for
; any error returned, or even use it to generate your own custom BASIC error
; report.
;
; All of the calls where a filename is specified will accept long filenames (LFNs)
; and most will accept wildcards (for an operation such as F_OPEN where a single
; file is always used, the first matching filename will be used).
;
; IMPORTANT NOTE:
; When calling either the +3DOS-compatible or esxDOS-compatible API, make sure you
; have not left layer 2 writes enabled (ie bit 0 of port $123b should be zero when
; making any API call).
; This is important because if layer 2 writes are left enabled, they can interfere
; with the operation of the system calls, which page in DivMMC RAM to the same
; region of memory ($0000-$3fff).
; It is perfectly okay to leave layer 2 turned on and displayed (with bit 1 of
; port $123b) during API calls; only the writes need to be disabled.
;


; ***************************************************************************
; * F_OPEN ($9a) *
; ***************************************************************************
; Open a file.
; Entry:
;       A=drive specifier (overridden if filespec includes a drive)
;          '*' = use the default drive. 
;          '$' = use the system drive (C:, where the NEXTZXOS and BIN dirs are)
;          n.b. Drive letter in filename overrides this e.g. "D:/myfile.txt\0"
;       IX [HL from dot command]=filespec, null-terminated
;       B=access modes, a combination of:
;         any/all of:
;           esx_mode_read $01 request read access
;           esx_mode_write $02 request write access
;           esx_mode_use_header $40 read/write +3DOS header
;         plus one of:
;           esx_mode_open_exist $00 only open existing file
;           esx_mode_open_creat $08 open existing or create file
;           esx_mode_creat_noexist $04 create new file, error if exists
;           esx_mode_creat_trunc $0c create new file, delete existing
;      
;       DE=8-byte buffer with/for +3DOS header data (if specified in mode)
;       (NB: filetype will be set to $ff if headerless file was opened)
; Exit (success):
;       Fc=0
;       A=file handle
; Exit (failure):
;       Fc=1
;       A=error code
F_OPEN          EQU $9A

ESX_MODE_READ           EQU $01 ; request read access
ESX_MODE_WRITE          EQU $02 ; request write access
ESX_MODE_OPEN_EXIST     EQU $00 ; only open existing file
ESX_MODE_OPEN_CREAT     EQU $08 ; open existing or create file

; ***************************************************************************
; * F_CLOSE ($9b) *
; ***************************************************************************
; Close a file or directory.
; Entry:
;       A=file handle or directory handle
; Exit (success):
;       Fc=0
;       A=0
; Exit (failure):
;       Fc=1
;       A=error code
F_CLOSE         EQU $9B

F_SYNC          EQU $9C

; ***************************************************************************
; * F_READ ($9d) *
; ***************************************************************************
; Read bytes from file.
; Entry:
;       A=file handle
;       IX [HL from dot command]=address
;       BC=bytes to read
; Exit (success):
;       Fc=0
;       BC=bytes actually read (also in DE)
;       HL=address following bytes read
; Exit (failure):
;       Fc=1
;       BC=bytes actually read
;       A=error code
;
; NOTES:
; EOF is not an error, check BC to determine if all bytes requested were read.
F_READ          EQU $9D

; ***************************************************************************
; * F_WRITE ($9e) *
; ***************************************************************************
; Write bytes to file.
; Entry:
;       A=file handle
;       IX [HL from dot command]=address
;       BC=bytes to write
; Exit (success):
;       Fc=0
;       BC=bytes actually written
; Exit (failure):
;       Fc=1
;       BC=bytes actually written
F_WRITE         EQU $9E

;------------------------------------------------------------------------------------
