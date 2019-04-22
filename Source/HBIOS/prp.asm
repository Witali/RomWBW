;
;==================================================================================================
; PROPIO DRIVER
;==================================================================================================
;
; TODO:
;   1) ADD SUPPORT FOR DSKY
;
PRP_IOBASE	.EQU	$A8
;
; GLOBAL PROPIO INITIALIZATION
;
PRP_INIT:
;
	CALL	NEWLINE			; FORMATTING
	PRTS("PRP: IO=0x$")
	LD	A,PRP_IOBASE
	CALL	PRTHEXBYTE
;
	CALL	PRP_DETECT
	;CALL	PC_SPACE		; *DEBUG*
	;CALL	PRTHEXWORD		; *DEBUG*
	LD	DE,PRP_STR_NOHW
	JP	NZ,WRITESTR
;
	; RESET INTERFACE, RETURN WITH NZ ON FAILURE
#IF (PRPSDTRACE >= 3)
	CALL	PRPSD_PRTPREFIX
	PRTS(" RESET$")
#ENDIF
;
	; REQUEST INTERFACE RESET, RESULT IN A, Z/NZ SET
	LD	A,PRPSD_CMDRESET	; CLEAR ANY ERRORS ON PROPIO
	CALL	PRPSD_SNDCMD
	RET	NZ			; NZ SET, A HAS RESULT CODE
;
	CALL	PRPSD_GETVER
	RET	NZ
;
	; PRINT FIRMWARE VERSION
	PRTS(" F/W=$")
	LD	HL,PRP_FWVER
	CALL	LD32
	LD	A,D
	CALL	PRTDECB
	CALL	PC_PERIOD
	LD	A,E
	CALL	PRTDECB
	CALL	PC_PERIOD
	CALL	PRTDEC
;
	; CHECK F/W VERSION & NOTIFY USER IF UPGRADE REQUIRED
	LD	HL,PRP_FWVER
	CALL	LD32
	XOR	A
	CP	D
	JR	NZ,PRP_INIT1
	CP	E
	JR	NZ,PRP_INIT1
	LD	DE,PRP_STR_UPGRADE
	CALL	WRITESTR
;
PRP_INIT1:
	CALL	PRPCON_INIT		; CONSOLE INITIALIZATION
	CALL	PRPSD_INIT		; SD CARD INITIALIZATION
;
	RET
;
;
;
PRP_DETECT:
	LD	BC,2048			; TRY FOR ABOUT 4 SECONDS
PRP_DETECT1:
	CALL	PRP_DETECT2
	RET	Z
	DEC	BC
	LD	A,B
	OR	C
	JR	NZ,PRP_DETECT1
	OR	$FF
	RET
;
PRP_DETECT2:
	LD	A,PRPSD_CMDRESET
	OUT	(PRPSD_DSKCMD),A
	LD	DE,64			; 1MS
	CALL	VDELAY
	LD	A,$A5
	OUT	(PRPSD_DSKIO),A
	LD	A,$5A
	OUT	(PRPSD_DSKIO),A
	LD	A,PRPSD_CMDNOP
	OUT	(PRPSD_DSKCMD),A
	LD	DE,64			; 1MS
	CALL	VDELAY
	IN	A,(PRPSD_DSKIO)
	CP	$A5
	RET	NZ
	IN	A,(PRPSD_DSKIO)
	CP	$5A
	RET
;
;
;
PRP_STR_NOHW		.TEXT	" NOT PRESENT$"
PRP_STR_UPGRADE		.TEXT	" !!!UPGRADE REQUIRED!!!$"
;
;==================================================================================================
; PROPIO CONSOLE DRIVER
;==================================================================================================
;
PRPCON_CMD	.EQU	PRP_IOBASE + 0	; PROPIO CONSOLE COMMAND PORT (WHEN WRITTEN)
PRPCON_STATUS	.EQU	PRP_IOBASE + 0	; PROPIO CONSOLE STATUS PORT (WHEN READ)
PRPCON_DATA	.EQU	PRP_IOBASE + 1	; PROPIO CONSOLE DATA PORT (READ=KBD, WRITE=DISPLAY)
;
PRPCON_BUSY	.EQU	$80		; BIT SET WHEN PROPIO CONSOLE INTERFACE IS BUSY
PRPCON_ERR	.EQU	$40		; BIT SET WHEN PROPIO CONSOLE ERROR HAS OCCURRED
PRPCON_KBDRDY	.EQU	$20		; BIT SET WHEN KEYBOARD BUF HAS A BYTE READY (BUF FULL)
PRPCON_DSPRDY	.EQU	$10		; BIT SET WHEN DISPLAY BUF IS READY FOR A BYTE (BUF EMPTY)
;
PRPCON_ROWS	.EQU	37		; PROPELLER VGA DISPLAY ROWS (40 - 3 STATUS LINES)
PRPCON_COLS	.EQU	80		; PROPELLER VGA DISPLAY COLS
;
;
;
PRPCON_INIT:
;
	CALL	NEWLINE
	PRTS("PRPCON: $")
;
	; DISPLAY CONSOLE DIMENSIONS
	CALL	PC_SPACE
	LD	A,PRPCON_COLS
	CALL	PRTDECB
	LD	A,'X'
	CALL	COUT
	LD	A,PRPCON_ROWS
	CALL	PRTDECB
	CALL	PRTSTRD
	.TEXT	" TEXT (ANSI)$"
;
; ADD OURSELVES TO CIO DISPATCH TABLE
;
	LD	D,0			; PHYSICAL UNIT IS ZERO
	LD	E,CIODEV_PRPCON		; DEVICE TYPE
	LD	BC,PRPCON_FNTBL		; BC := FUNCTION TABLE ADDRESS
	CALL	CIO_ADDENT		; ADD ENTRY, A := UNIT ASSIGNED
	LD	(HCB + HCB_CRTDEV),A	; SET OURSELVES AS THE CRT DEVICE
;
	XOR	A			; SIGNAL SUCCESS
	RET
;
; DRIVER FUNCTION TABLE
;
PRPCON_FNTBL:
	.DW	PRPCON_IN
	.DW	PRPCON_OUT
	.DW	PRPCON_IST
	.DW	PRPCON_OST
	.DW	PRPCON_INITDEV
	.DW	PRPCON_QUERY
	.DW	PRPCON_DEVICE
#IF (($ - PRPCON_FNTBL) != (CIO_FNCNT * 2))
	.ECHO	"*** INVALID PRPCON FUNCTION TABLE ***\n"
#ENDIF
;
;
;
PRPCON_IN:
	CALL	PRPCON_IST		; CHECK FOR CHAR PENDING
	JR	Z,PRPCON_IN		; WAIT FOR IT IF NECESSARY
	IN	A,(PRPCON_DATA)		; READ THE CHAR FROM PROPIO
	LD	E,A
	RET
;
;
;
PRPCON_IST:
	IN	A,(PRPCON_STATUS)	; READ LINE STATUS REGISTER
	AND	PRPCON_KBDRDY | PRPCON_BUSY	; ISOLATE KBDRDY AND BUSY
	SUB	PRPCON_KBDRDY		; KBD RDY BUT NOT BUSY?
	JR	Z,PRPCON_IST1		; YES, GO TO READY LOGIC
	XOR	A			; SIGNAL NO CHARS WAITING
	JP	CIO_IDLE		; RETURN VIA IDLE PROCESSING
PRPCON_IST1:
	DEC	A			; SET A=$FF TO SIGNAL READY
	RET				; RETURN
;
;
;
PRPCON_OUT:
	CALL	PRPCON_OST		; CHECK FOR OUTPUT READY
	JR	Z,PRPCON_OUT		; WAIT IF NECESSARY
	LD	A,E			; RECOVER THE CHAR TO WRITE
	OUT	(PRPCON_DATA),A		; WRITE THE CHAR TO PROPIO
	RET
;
;
;
PRPCON_OST:
	IN	A,(PRPCON_STATUS)	; READ LINE STATUS REGISTER
	AND	PRPCON_DSPRDY | PRPCON_BUSY	; ISOLATE DSPRDY AND BUSY
	SUB	PRPCON_DSPRDY		; DSP RDY BUT NOT BUSY?
	JR	Z,PRPCON_OST1		; YES, GO TO READY LOGIC
	XOR	A			; SIGNAL NO CHARS WAITING
	JP	CIO_IDLE		; RETURN VIA IDLE PROCESSING
PRPCON_OST1:
	DEC	A			; SET A=$FF TO SIGNAL READY
	RET				; RETURN
;
;
;
PRPCON_INITDEV:
	CALL	PANIC
;
;
;
PRPCON_QUERY:
	LD	DE,0
	LD	HL,0
	XOR	A
	RET
;
;
;
PRPCON_DEVICE:
	LD	D,CIODEV_PRPCON		; D := DEVICE TYPE
	LD	E,0			; E := DEVICE NUM, ALWAYS 0
	LD	C,$80			; C := DEVICE TYPE, 0x80 IS TERMINAL
	XOR	A			; SIGNAL SUCCESS
	RET
;
;==================================================================================================
;   PROPIO SD CARD DRIVER
;==================================================================================================
;
; IO PORT ADDRESSES
;
PRPSD_DSKCMD	.EQU	PRP_IOBASE + 2
PRPSD_DSKST	.EQU	PRP_IOBASE + 2
PRPSD_DSKIO	.EQU	PRP_IOBASE + 3
;
PRPSD_CMDNOP	.EQU	$00
PRPSD_CMDSTAT	.EQU	$01
PRPSD_CMDTYPE	.EQU	$02
PRPSD_CMDCAP	.EQU	$03
PRPSD_CMDCSD	.EQU	$04
PRPSD_CMDRESET	.EQU	$10
PRPSD_CMDINIT	.EQU	$20
PRPSD_CMDREAD	.EQU	$30
PRPSD_CMDPREP	.EQU	$40
PRPSD_CMDWRITE	.EQU	$50
;
PRPSD_CMDVER	.EQU	$F0
;
PRPSD_DSKSTBSY	.EQU	$80
PRPSD_DSKSTERR	.EQU	$40
PRPSD_DSKSTOVR	.EQU	$20
PRPSD_DSKSTTO	.EQU	$10
;
; SD CARD TYPE
;
PRPSD_TYPEUNK	.EQU	0		; CARD TYPE UNKNOWN/UNDETERMINED
PRPSD_TYPEMMC	.EQU	1		; MULTIMEDIA CARD (MMC STANDARD)
PRPSD_TYPESDSC	.EQU	2		; SDSC CARD (V1)
PRPSD_TYPESDHC	.EQU	3		; SDHC CARD (V2)
PRPSD_TYPESDXC	.EQU	4		; SDXC CARD (V3)
;
; SD CARD STATUS (PRPSD_STAT)
;
PRPSD_STOK	.EQU	0		; OK
PRPSD_STINVUNIT	.EQU	-1		; INVALID UNIT
PRPSD_STRDYTO	.EQU	-2		; TIMEOUT WAITING FOR CARD TO BE READY
PRPSD_STINITTO	.EQU	-3		; INITIALIZATOIN TIMEOUT
PRPSD_STCMDTO	.EQU	-4		; TIMEOUT WAITING FOR COMMAND RESPONSE
PRPSD_STCMDERR	.EQU	-5		; COMMAND ERROR OCCURRED (REF PRPSD_RC)
PRPSD_STDATAERR	.EQU	-6		; DATA ERROR OCCURRED (REF PRPSD_TOK)
PRPSD_STDATATO	.EQU	-7		; DATA TRANSFER TIMEOUT
PRPSD_STCRCERR	.EQU	-8		; CRC ERROR ON RECEIVED DATA PACKET
PRPSD_STNOMEDIA	.EQU	-9		; NO MEDIA IN CONNECTOR
PRPSD_STWRTPROT	.EQU	-10		; ATTEMPT TO WRITE TO WRITE PROTECTED MEDIA
;
; PRPSD DEVICE CONFIGURATION
;
PRPSD_DEVCNT	.EQU	1		; ONE DEVICE SUPPORTED
PRPSD_CFGSIZ	.EQU	12		; SIZE OF CFG TBL ENTRIES
;
; PER DEVICE DATA OFFSETS
;
PRPSD_DEV	.EQU	0		; OFFSET OF DEVICE NUMBER (BYTE)
PRPSD_STAT	.EQU	1		; LAST STATUS (BYTE)
PRPSD_TYPE	.EQU	2		; DEVICE TYPE (BYTE)
PRPSD_FLAGS	.EQU	3		; FLAG BITS BIT 0=CF, 1=LBA (BYTE)
PRPSD_MEDCAP	.EQU	4		; MEDIA CAPACITY (DWORD)
PRPSD_LBA	.EQU	8		; OFFSET OF LBA (DWORD)
;
PRPSD_CFGTBL:
	; DEVICE 0
	.DB	0			; DRIVER DEVICE NUMBER
	.DB	0			; DEVICE STATUS
	.DB	0			; DEVICE TYPE
	.DB	0			; FLAGS BYTE
	.DW	0,0			; DEVICE CAPACITY
	.DW	0,0			; CURRENT LBA
;
#IF ($ - PRPSD_CFGTBL) != (PRPSD_DEVCNT * PRPSD_CFGSIZ)
	.ECHO	"*** INVALID PRPSD CONFIG TABLE ***\n"
#ENDIF
;
	.DB	$FF			; END MARKER
;
; SD CARD INITIALIZATION
;
PRPSD_INIT:
;
; SETUP THE DISPATCH TABLE ENTRIES
;
	LD	B,PRPSD_DEVCNT		; LOOP CONTROL
	LD	IY,PRPSD_CFGTBL		; START OF CFG TABLE
PRPSD_INIT0:
	PUSH	BC			; SAVE LOOP CONTROL
	LD	BC,PRPSD_FNTBL		; BC := FUNC TABLE ADR
	PUSH	IY			; CFG ENTRY POINTER
	POP	DE			; COPY TO DE
	CALL	DIO_ADDENT		; ADD ENTRY, BC IS NOT DESTROYED
	LD	BC,PRPSD_CFGSIZ		; SIZE OF CFG ENTRY
	ADD	IY,BC			; BUMP IY TO NEXT ENTRY
	POP	BC			; RESTORE BC
	DJNZ	PRPSD_INIT0		; LOOP AS NEEDED
;
	; INITIALIZE INDIVIDUAL UNIT(S) AND DISPLAY DEVICE INVENTORY
	LD	B,PRPSD_DEVCNT		; INIT LOOP COUNTER TO DEVICE COUNT
	LD	IY,PRPSD_CFGTBL		; START OF CFG TABLE
PRPSD_INIT1:
	PUSH	BC			; SAVE LOOP COUNTER/INDEX
	CALL	PRPSD_INITUNIT		; INITIALIZE IT
#IF (PRPSDTRACE < 2)
	CALL	NZ,PRPSD_PRTSTAT	; IF ERROR, SHOW IT
#ENDIF
	LD	BC,PRPSD_CFGSIZ		; SIZE OF CFG ENTRY
	ADD	IY,BC			; BUMP IY TO NEXT ENTRY
	POP	BC			; RESTORE LOOP CONTROL
	DJNZ	PRPSD_INIT1		; DECREMENT LOOP COUNTER AND LOOP AS NEEDED
;
	RET				; DONE
;
;
;
PRPSD_INITUNIT:
	; REINITIALIZE THE CARD HERE
	CALL	PRPSD_INITCARD
	RET	NZ
;
	CALL	PRPSD_PRTPREFIX
;
	; PRINT CARD TYPE
	PRTS(" TYPE=$")
	CALL	PRPSD_PRTTYPE
;
	; PRINT STORAGE CAPACITY (BLOCK COUNT)
	PRTS(" BLOCKS=0x$")		; PRINT FIELD LABEL
	LD	A,PRPSD_MEDCAP		; OFFSET TO CAPACITY FIELD
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	CALL	LD32			; GET THE CAPACITY VALUE
	CALL	PRTHEX32		; PRINT HEX VALUE
;
	; PRINT STORAGE SIZE IN MB
	PRTS(" SIZE=$")			; PRINT FIELD LABEL
	LD	B,11			; 11 BIT SHIFT TO CONVERT BLOCKS --> MB
	CALL	SRL32			; RIGHT SHIFT
	CALL	PRTDEC			; PRINT LOW WORD IN DECIMAL (HIGH WORD DISCARDED)
	PRTS("MB$")			; PRINT SUFFIX
;
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
PRPSD_FNTBL:
	.DW	PRPSD_STATUS
	.DW	PRPSD_RESET
	.DW	PRPSD_SEEK
	.DW	PRPSD_READ
	.DW	PRPSD_WRITE
	.DW	PRPSD_VERIFY
	.DW	PRPSD_FORMAT
	.DW	PRPSD_DEVICE
	.DW	PRPSD_MEDIA
	.DW	PRPSD_DEFMED
	.DW	PRPSD_CAP
	.DW	PRPSD_GEOM
#IF (($ - PRPSD_FNTBL) != (DIO_FNCNT * 2))
	.ECHO	"*** INVALID PRPSD FUNCTION TABLE ***\n"
#ENDIF
;
PRPSD_VERIFY:
PRPSD_FORMAT:
PRPSD_DEFMED:
	CALL	PANIC			; INVALID SUB-FUNCTION
;
;
;
PRPSD_READ:
	LD	BC,PRPSD_RDSEC		; GET ADR OF SECTOR READ FUNC
	LD	(PRPSD_IOFNADR),BC	; SAVE IT AS PENDING IO FUNC
	JR	PRPSD_IO		; CONTINUE TO GENERIC IO ROUTINE
;
;
;
PRPSD_WRITE:
	LD	BC,PRPSD_WRSEC		; GET ADR OF SECTOR READ FUNC
	LD	(PRPSD_IOFNADR),BC	; SAVE IT AS PENDING IO FUNC
	JR	PRPSD_IO		; CONTINUE TO GENERIC IO ROUTINE
;
;
;
PRPSD_IO:
	LD	(PRPSD_DSKBUF),HL	; SAVE DISK BUFFER ADDRESS
	LD	A,E			; BLOCK COUNT TO A
	OR	A			; SET FLAGS
	RET	Z			; ZERO SECTOR I/O, RETURN W/ E=0 & A=0
	LD	B,A			; INIT SECTOR DOWNCOUNTER
	LD	C,0			; INIT SECTOR R/W COUNTER

#IF (PRPSDTRACE == 1)
	LD	HL,PRPSD_PRTERR		; SET UP PRPSD_PRTERR
	PUSH	HL			; ... TO FILTER ALL EXITS
#ENDIF

	PUSH	BC			; SAVE COUNTERS
	CALL	PRPSD_CHKCARD		; CHECK / REINIT CARD AS NEEDED
	POP	BC			; RESTORE COUNTERS
	JR	NZ,PRPSD_IO3		; BAIL OUT ON ERROR

PRPSD_IO1:
	PUSH	BC			; SAVE COUNTERS

#IF (PRPSDTRACE >= 3)
	CALL	PRPSD_PRTPREFIX
#ENDIF

	LD	HL,(PRPSD_IOFNADR)	; GET PENDING IO FUNCTION ADDRESS
	CALL	JPHL			; ... AND CALL IT
	JR	NZ,PRPSD_IO2		; BAIL OUT ON ERROR
	; INCREMENT LBA
	LD	A,PRPSD_LBA		; LBA OFFSET
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	CALL	INC32HL			; INCREMENT THE VALUE
	; INCREMENT DMA
	LD	HL,PRPSD_DSKBUF+1	; POINT TO MSB OF BUFFER ADR
	INC	(HL)			; BUMP DMA BY
	INC	(HL)			; ... 512 BYTES
	XOR	A			; SIGNAL SUCCESS

PRPSD_IO2:
	POP	BC			; RECOVER COUNTERS
	JR	NZ,PRPSD_IO3		; IF ERROR PENDING, BAIL OUT
	INC	C			; BUMP COUNT OF SECTORS READ
	DJNZ	PRPSD_IO1		; LOOP AS NEEDED

PRPSD_IO3:
	LD	E,C			; SECTOR READ COUNT TO E
	LD	HL,(PRPSD_DSKBUF)	; CURRENT BUF ADR TO HL
	OR	A			; SET FLAGS
	RET				; RETURN WITH A = STATUS
;
;
;
PRPSD_RDSEC:
;
	CALL	PRPSD_SETBLK		; SEND BLOCK ADDRESS

#IF (PRPSDTRACE >= 3)
	PRTS(" READ$")
#ENDIF

	LD	A,PRPSD_CMDREAD		; READ COMMAND
	CALL	PRPSD_SNDCMD		; ... AND SEND COMMAND
	RET	NZ			; BAIL OUT ON ERROR

	LD	C,PRPSD_DSKIO		; SET PORT
	LD	B,0			; SET LOOP COUNTER FOR 256 ITER
	LD	HL,(PRPSD_DSKBUF)	; SET BUF ADR
	INIR				; READ 256 BYTES
	INIR				; ... AND AGAIN FOR 512 TOTAL

	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
PRPSD_WRSEC:
;
	CALL	PRPSD_SETBLK

#IF (PRPSDTRACE >= 3)
	PRTS(" PREP$")
#ENDIF

	LD	A,PRPSD_CMDPREP		; PREPARE COMMAND
	CALL	PRPSD_SNDCMD		; SEND IT
	RET	NZ			; BAIL OUT ON ERROR

	LD	C,PRPSD_DSKIO		; SET PORT
	LD	B,0			; SET LOOP COUNTER FOR 256 ITER
	LD	HL,(PRPSD_DSKBUF)	; SET BUF ADR
	OTIR				; WRITE 256 BYTES
	OTIR				; ... AND AGAIN FOR 512 TOTAL

#IF (PRPSDTRACE >= 3)
	PRTS(" WRITE$")
#ENDIF

	LD	A,PRPSD_CMDWRITE	; WRITE COMMAND
	CALL	PRPSD_SNDCMD		; SEND IT
	RET	NZ			; BAIL OUT ON ERROR

	XOR	A			; SIGNAL SUCCESS
	RET				; RETURN
;
;
;
PRPSD_STATUS:
	LD	A,(IY+PRPSD_STAT)	; GET STATUS OF SELECTED DEVICE
	OR	A
	RET
;
;
;
PRPSD_RESET:
	XOR	A			; ALWAYS OK
	RET
;
;
;
PRPSD_DEVICE:
	LD	D,DIODEV_PRPSD		; D := DEVICE TYPE
	LD	E,(IY+PRPSD_DEV)	; E := PHYSICAL DEVICE NUMBER
	LD	C,%01010000		; C := ATTRIBUTES, REMOVABLE, SD CARD
	XOR	A			; SIGNAL SUCCESS
	RET
;
; PRPSD_SENSE
;
PRPSD_MEDIA:
	; REINITIALIZE THE CARD HERE
	CALL	PRPSD_INITCARD
#IF (PRPSDTRACE == 1)
	CALL	PRPSD_PRTERR		; PRINT ANY ERRORS
#ENDIF
	LD	E,MID_HD		; ASSUME WE ARE OK
	RET	Z			; RETURN IF GOOD INIT
	LD	E,MID_NONE		; SIGNAL NO MEDA
	RET				; AND RETURN
;
;
;
PRPSD_SEEK:
	BIT	7,D			; CHECK FOR LBA FLAG
	CALL	Z,HB_CHS2LBA		; CLEAR MEANS CHS, CONVERT TO LBA
	RES	7,D			; CLEAR FLAG REGARDLESS (DOES NO HARM IF ALREADY LBA)
	LD	(IY+PRPSD_LBA+0),L	; SAVE NEW LBA
	LD	(IY+PRPSD_LBA+1),H	; ...
	LD	(IY+PRPSD_LBA+2),E	; ...
	LD	(IY+PRPSD_LBA+3),D	; ...
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
;
;
PRPSD_CAP:
	LD	A,PRPSD_MEDCAP		; OFFSET TO CAPACITY FIELD
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	CALL	LD32			; GET THE CURRENT CAPACITY INTO DE:HL
	LD	BC,512			; 512 BYTES PER BLOCK
	LD	A,(IY+PRPSD_STAT)	; GET STATUS
	OR	A			; SET FLAGS
	RET
;
;
;
PRPSD_GEOM:
	; FOR LBA, WE SIMULATE CHS ACCESS USING 16 HEADS AND 16 SECTORS
	; RETURN HS:CC -> DE:HL, SET HIGH BIT OF D TO INDICATE LBA CAPABLE
	CALL	PRPSD_CAP		; GET TOTAL BLOCKS IN DE:HL, BLOCK SIZE TO BC
	LD	L,H			; DIVIDE BY 256 FOR # TRACKS
	LD	H,E			; ... HIGH BYTE DISCARDED, RESULT IN HL
	LD	D,16 | $80		; HEADS / CYL = 16, SET LBA CAPABILITY BIT
	LD	E,16			; SECTORS / TRACK = 16
	RET				; DONE, A STILL HAS PRPSD_CAP STATUS
;
;
;
PRPSD_INITCARD:
	;; CLEAR ALL STATUS DATA
	;LD	HL,PRPSD_UNITDATA
	;LD	BC,PRPSD_UNITDATALEN
	;XOR	A
	;CALL	FILL
;
	; RESET INTERFACE, RETURN WITH NZ ON FAILURE
#IF (PRPSDTRACE >= 3)
	CALL	PRPSD_PRTPREFIX
	PRTS(" RESET$")
#ENDIF

	; REQUEST INTERFACE RESET, RESULT IN A, Z/NZ SET
	LD	A,PRPSD_CMDRESET	; CLEAR ANY ERRORS ON PROPIO
	CALL	PRPSD_SNDCMD
	RET	NZ			; NZ SET, A HAS RESULT CODE
;
	; (RE)INITIALIZE THE CARD, RETURN WITH NZ ON FAILURE
#IF (PRPSDTRACE >= 3)
	CALL	PRPSD_PRTPREFIX
	PRTS(" INIT$")
#ENDIF

	; REQUEST HARDWARE INIT, RESULT IN A, Z/NZ SET
	LD	A,PRPSD_CMDINIT
	CALL	PRPSD_SNDCMD
	;RET	NZ			; NZ SET, A HAS RESULT CODE
	JP	NZ,PRPSD_NOMEDIA	; RETURN W/ NO MEDIA ERROR

#IF (PRPSDTRACE >= 3)
	; GET CSD IF DEBUGGING
	CALL	PRPSD_GETCSD
	RET	NZ
#ENDIF

	; GET CARD TYPE
	CALL	PRPSD_GETTYPE
	RET	NZ

	; GET CAPACITY
	CALL	PRPSD_GETCAP
	RET	NZ

	RET				; N/NZ SET, A HAS RESULT CODE
;
; CHECK THE SD CARD, ATTEMPT TO REINITIALIZE IF NEEDED
;
PRPSD_CHKCARD:
	LD	A,(IY+PRPSD_STAT)	; GET CURRENT STATUS
	OR	A			; SET FLAGS
	RET	Z			; IF ALL GOOD, DONE
	JP	PRPSD_INITCARD		; OTHERWISE, REINIT
;
;
;
PRPSD_GETVER:
#IF (PRPSDTRACE >= 3)
	CALL	PRPSD_PRTPREFIX
#ENDIF
;
#IF (PRPSDTRACE >= 3)
	PRTS(" PREP$")
#ENDIF
;
	; ZEROES BUFFER IN CASE F/W DOES NOT KNOW VER COMMAND
	LD	A,PRPSD_CMDPREP
	CALL	PRPSD_SNDCMD
	RET	NZ			; RETURN ON FAILURE, A = STATUS
;
#IF (PRPSDTRACE >= 3)
	PRTS(" VER$")
#ENDIF
	LD	A,PRPSD_CMDVER
	CALL	PRPSD_SNDCMD
	RET	NZ

	LD	C,PRPSD_DSKIO		; FROM PROPIO DISK PORT
	LD	B,4			; 4 BYTES
	LD	HL,PRP_FWVER		; TO PRP_FWVER
	INIR

#IF (PRPSDTRACE >= 3)
	CALL	PC_SPACE
	LD	HL,PRP_FWVER
	CALL	LD32
	CALL	PRTHEX32
#ENDIF
	XOR	A
	RET
;
;
;
PRPSD_GETTYPE:
#IF (PRPSDTRACE >= 3)
	CALL	PRPSD_PRTPREFIX
	PRTS(" TYPE$")
#ENDIF
	LD	A,PRPSD_CMDTYPE
	CALL	PRPSD_SNDCMD
	RET	NZ

	IN	A,(PRPSD_DSKIO)
	LD	(IY+PRPSD_TYPE),A

#IF (PRPSDTRACE >= 3)
	CALL	PC_SPACE
	CALL	PRTHEXBYTE
#ENDIF

	XOR	A
	RET
;
;
;
PRPSD_GETCAP:
#IF (PRPSDTRACE >= 3)
	CALL	PRPSD_PRTPREFIX
	PRTS(" CAP$")
#ENDIF
	LD	A,PRPSD_CMDCAP
	CALL	PRPSD_SNDCMD
	RET	NZ

	LD	C,PRPSD_DSKIO		; FROM PROPIO DISK PORT
	LD	B,4			; 4 BYTES
	LD	A,PRPSD_MEDCAP		; ... OF CAPACITY
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	INIR

#IF (PRPSDTRACE >= 3)
	CALL	PC_SPACE
	LD	A,PRPSD_MEDCAP		; ... OF CAPACITY
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	CALL	LD32
	CALL	PRTHEX32
#ENDIF

	XOR	A
	RET
;
;
;
PRPSD_GETCSD:
#IF (PRPSDTRACE >= 3)
	CALL	PRPSD_PRTPREFIX
	PRTS(" CSD$")
#ENDIF
	LD	A,PRPSD_CMDCSD
	CALL	PRPSD_SNDCMD
	RET	NZ

	LD	C,PRPSD_DSKIO
	LD	B,16
	LD	HL,PRPSD_CSDBUF
	INIR

#IF (PRPSDTRACE >= 3)
	CALL	PC_SPACE
	LD	DE,PRPSD_CSDBUF
	LD	A,16
	CALL	PRTHEXBUF
#ENDIF

	XOR	A
	RET
;
;
;
PRPSD_SNDCMD:
	LD	(PRPSD_CMD),A		; SAVE INCOMING COMMAND
	CALL	PRPSD_WAITBSY		; WAIT FOR BUSY TO BE CLEAR
	LD	(PRPSD_DSKSTAT),A	; SAVE STATUS
#IF (PRPSDTRACE >= 3)
	CALL	PC_SPACE
	CALL	PRTHEXBYTE
#ENDIF
	BIT	7,A			; STILL BUSY
	JP	NZ,PRPSD_ERRRDYTO	; HANDLE TIMEOUT
	;CALL	PC_PERIOD
	LD	A,(PRPSD_CMD)		; RECOVER INCOMING COMMAND
	OUT	(PRPSD_DSKCMD),A	; SEND THE COMMAND
	CALL	PRPSD_WAITBSY		; WAIT FOR BUSY TO CLEAR (CMD COMPLETE)
	LD	(PRPSD_DSKSTAT),A	; SAVE STATUS
#IF (PRPSDTRACE >= 3)
	CALL	PC_SPACE
	CALL	PRTHEXBYTE
#ENDIF
	OR	A			; SET FLAGS
	RET	Z			; RETURN W/ NO ERRORS
;
	BIT	7,A			; STILL BUSY
	JP	NZ,PRPSD_ERRRDYTO	; HANDLE TIMEOUT
;
	; ASSUMES A COMMAND ERROR AT THIS POINT
	; GET DETAIL ERROR CODE
	LD	C,PRPSD_DSKIO		; FROM PROPIO DISK PORT
	LD	B,4			; 4 BYTES
	LD	HL,PRPSD_ERRCODE	; TO PRPSD_ERRCODE
	INIR
#IF (PRPSDTRACE >= 3)
	CALL	PC_SPACE
	LD	HL,PRPSD_ERRCODE
	CALL	LD32
	CALL	PRTHEX32
#ENDIF
	JP	PRPSD_ERRCMD		; RETURN VIA ERROR HANDLER
;
;
;
PRPSD_WAITBSY:
	LD	BC,(PRPSD_TIMEOUT)
PRPSD_WAITBSY1:
	IN	A,(PRPSD_DSKST)		; GET STATUS
	LD	E,A			; SAVE IT IN E
	BIT	7,A			; ISLOATE BUSY BIT
	JR	Z,PRPSD_WAITBSY2	; DONE, JUMP TO HAPPY EXIT
	CALL	DELAY
	CALL	DELAY
	DEC	BC
	LD	A,B
	OR	C
	JR	NZ,PRPSD_WAITBSY1
	; TIMEOUT RETURN
	LD	A,E			; RECOVER LAST STATUS
	OR	A			; SET FLAGS
	RET
;
PRPSD_WAITBSY2:
#IF (PRPSDTRACE >= 3)
	; DUMP LOOP COUNT
	PUSH	AF
	CALL	PC_SPACE
	CALL	PC_LBKT
	OR	A			; CLEAR CARRY
	LD	HL,(PRPSD_TIMEOUT)
	SBC	HL,BC
	LD	B,H
	LD	C,L
	CALL	PRTHEXWORD
	CALL	PC_RBKT
	POP	AF
#ENDIF
	OR	A			; SET FLAGS
	RET				; AND RETURN WITH STATUS IN A
;
; SEND INDEX OF BLOCK TO READ/WRITE FROM SD CARD
; 32 BIT VALUE (4 BYTES)
;
PRPSD_SETBLK:
#IF (PRPSDTRACE >= 3)
	PRTS(" BLK$")
#ENDIF

	; A NOP COMMAND IS A QUICK WAY TO ENSURE THE DISK BUFFER
	; POINTER ON THE PROPIO IS RESET TO ZERO
	LD	A,PRPSD_CMDNOP
	OUT	(PRPSD_DSKCMD),A	; SEND THE COMMAND (NO WAIT)

#IF (PRPSDTRACE >= 3)
	CALL	PC_SPACE
	LD	A,PRPSD_LBA		; OFFSET OF LBA
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	CALL	LD32
	CALL	PRTHEX32
#ENDIF
	LD	C,PRPSD_DSKIO		; SEND TO DISK I/O PORT
	LD	B,4			; 4 BYTES
	LD	A,PRPSD_LBA		; OFFSET OF LBA
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	OTIR
	RET
;
;=============================================================================
; ERROR HANDLING AND DIAGNOSTICS
;=============================================================================
;
; ERROR HANDLERS
;
PRPSD_INVUNIT:
	LD	A,PRPSD_STINVUNIT
	JR	PRPSD_ERR2		; SPECIAL CASE FOR INVALID UNIT
;
PRPSD_ERRRDYTO:
	LD	A,PRPSD_STRDYTO
	JR	PRPSD_ERR
;
PRPSD_ERRINITTO:
	LD	A,PRPSD_STINITTO
	JR	PRPSD_ERR
;
PRPSD_ERRCMDTO:
	LD	A,PRPSD_STCMDTO
	JR	PRPSD_ERR
;
PRPSD_ERRCMD:
	LD	A,PRPSD_STCMDERR
	JR	PRPSD_ERR
;
PRPSD_ERRDATA:
	LD	A,PRPSD_STDATAERR
	JR	PRPSD_ERR
;
PRPSD_ERRDATATO:
	LD	A,PRPSD_STDATATO
	JR	PRPSD_ERR
;
PRPSD_ERRCRC:
	LD	A,PRPSD_STCRCERR
	JR	PRPSD_ERR
;
PRPSD_NOMEDIA:
	LD	A,PRPSD_STNOMEDIA
	JR	PRPSD_ERR
;
PRPSD_WRTPROT:
	LD	A,PRPSD_STWRTPROT
	JR	PRPSD_ERR2		; DO NOT UPDATE UNIT STATUS!
;
PRPSD_ERR:
	LD	(IY+PRPSD_STAT),A	; UPDATE STATUS
;
PRPSD_ERR2:
#IF (PRPSDTRACE >= 2)
	CALL	PRPSD_PRTSTAT
#ENDIF
	OR	A			; SET FLAGS
	RET
;
;
;
PRPSD_PRTERR:
	RET	Z			; DONE IF NO ERRORS
	; FALL THRU TO PRPSD_PRTSTAT
;
; PRINT STATUS STRING
;
PRPSD_PRTSTAT:
	PUSH	AF
	PUSH	DE
	PUSH	HL
	OR	A
	LD	DE,PRPSD_STR_STOK
	JR	Z,PRPSD_PRTSTAT1
	INC	A
	LD	DE,PRPSD_STR_STINVUNIT
	JR	Z,PRPSD_PRTSTAT1	; INVALID UNIT IS SPECIAL CASE
	INC	A
	LD	DE,PRPSD_STR_STRDYTO
	JR	Z,PRPSD_PRTSTAT1
	INC	A
	LD	DE,PRPSD_STR_STINITTO
	JR	Z,PRPSD_PRTSTAT1
	INC	A
	LD	DE,PRPSD_STR_STCMDTO
	JR	Z,PRPSD_PRTSTAT1
	INC	A
	LD	DE,PRPSD_STR_STCMDERR
	JR	Z,PRPSD_PRTSTAT1
	INC	A
	LD	DE,PRPSD_STR_STDATAERR
	JR	Z,PRPSD_PRTSTAT1
	INC	A
	LD	DE,PRPSD_STR_STDATATO
	JR	Z,PRPSD_PRTSTAT1
	INC	A
	LD	DE,PRPSD_STR_STCRCERR
	JR	Z,PRPSD_PRTSTAT1
	INC	A
	LD	DE,PRPSD_STR_STNOMEDIA
	JR	Z,PRPSD_PRTSTAT1
	INC	A
	LD	DE,PRPSD_STR_STWRTPROT
	JR	Z,PRPSD_PRTSTAT1
	LD	DE,PRPSD_STR_STUNK
PRPSD_PRTSTAT1:
	CALL	PRPSD_PRTPREFIX		; PRINT UNIT PREFIX
	CALL	PC_SPACE		; FORMATTING
	CALL	WRITESTR
	LD	A,(IY+PRPSD_STAT)
	CP	PRPSD_STCMDERR
	CALL	Z,PRPSD_PRTSTAT2
	POP	HL
	POP	DE
	POP	AF
	RET
PRPSD_PRTSTAT2:
	CALL	PC_SPACE
	LD	A,(PRPSD_DSKSTAT)
	CALL	PRTHEXBYTE
	CALL	PC_SPACE
	JP	PRPSD_PRTERRCODE
	RET

;
;
;
PRPSD_PRTERRCODE:
	PUSH	HL
	PUSH	DE
	LD	HL,PRPSD_ERRCODE
	CALL	LD32
	CALL	PRTHEX32
	POP	DE
	POP	HL
	RET
;
; PRINT DIAGNONSTIC PREFIX
;
PRPSD_PRTPREFIX:
	PUSH	AF
	CALL	NEWLINE
	PRTS("PRPSD$")
	LD	A,(IY+PRPSD_DEV)	; GET CURRENT DEVICE NUM
	ADD	A,'0'
	CALL	COUT
	CALL	PC_COLON
	POP	AF
	RET
;
; PRINT THE CARD TYPE
;
PRPSD_PRTTYPE:
	LD	A,(IY+PRPSD_TYPE)
	LD	DE,PRPSD_STR_TYPEMMC
	CP	PRPSD_TYPEMMC
	JR	Z,PRPSD_PRTTYPE1
	LD	DE,PRPSD_STR_TYPESDSC
	CP	PRPSD_TYPESDSC
	JR	Z,PRPSD_PRTTYPE1
	LD	DE,PRPSD_STR_TYPESDHC
	CP	PRPSD_TYPESDHC
	JR	Z,PRPSD_PRTTYPE1
	LD	DE,PRPSD_STR_TYPESDXC
	CP	PRPSD_TYPESDXC
	JR	Z,PRPSD_PRTTYPE1
	LD	DE,PRPSD_STR_TYPEUNK
PRPSD_PRTTYPE1:
	JP	WRITESTR
;
;=============================================================================
; STRING DATA
;=============================================================================
;
PRPSD_STR_ARROW		.TEXT	" -->$"
PRPSD_STR_RC		.TEXT	" RC=$"
PRPSD_STR_TOK		.TEXT	" TOK=$"
PRPSD_STR_CSD		.TEXT	" CSD =$"
PRPSD_STR_CID		.TEXT	" CID =$"
PRPSD_STR_SCR		.TEXT	" SCR =$"
PRPSD_STR_SDTYPE	.TEXT	" SD CARD TYPE ID=$"
;
PRPSD_STR_STOK		.TEXT	"OK$"
PRPSD_STR_STINVUNIT	.TEXT	"INVALID UNIT$"
PRPSD_STR_STRDYTO	.TEXT	"READY TIMEOUT$"
PRPSD_STR_STINITTO	.TEXT	"INITIALIZATION TIMEOUT$"
PRPSD_STR_STCMDTO	.TEXT	"COMMAND TIMEOUT$"
PRPSD_STR_STCMDERR	.TEXT	"COMMAND ERROR$"
PRPSD_STR_STDATAERR	.TEXT	"DATA ERROR$"
PRPSD_STR_STDATATO	.TEXT	"DATA TIMEOUT$"
PRPSD_STR_STCRCERR	.TEXT	"CRC ERROR$"
PRPSD_STR_STNOMEDIA	.TEXT	"NO MEDIA$"
PRPSD_STR_STWRTPROT	.TEXT	"WRITE PROTECTED$"
PRPSD_STR_STUNK		.TEXT	"UNKNOWN$"
;
PRPSD_STR_TYPEUNK	.TEXT	"UNK$"
PRPSD_STR_TYPEMMC	.TEXT	"MMC$"
PRPSD_STR_TYPESDSC	.TEXT	"SDSC$"
PRPSD_STR_TYPESDHC	.TEXT	"SDHC$"
PRPSD_STR_TYPESDXC	.TEXT	"SDXC$"
;
;=============================================================================
; DATA STORAGE
;=============================================================================
;
PRP_FWVER		.DW	0,0	; MMNNBBB (M=MAJOR, N=MINOR, B=BUILD)
;
PRPSD_IOFNADR		.DW	0	; PENDING IO FUNCTION ADDRESS
;
PRPSD_DSKBUF		.DW	0
;
PRPSD_DSKSTAT		.DB	0
PRPSD_ERRCODE		.DW	0,0
PRPSD_CSDBUF		.FILL	16,0
;
PRPSD_CMD		.DB	0
;
PRPSD_TIMEOUT		.DW	$0000	; FIX: MAKE THIS CPU SPEED RELATIVE
