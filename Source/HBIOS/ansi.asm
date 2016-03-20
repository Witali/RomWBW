;
;==================================================================================================
;   ANSI EMULATION MODULE
;==================================================================================================
;
; TODO:
;   1) INSERT/DELETE CHARACTERS CTL SEQUENCES
;   2) OTHER CTL SEQUENCES?
;
;==================================================================================================
;   ANSI EMULATION MODULE CONSTANTS
;==================================================================================================
;
ANSI_DEFATTR	.EQU	0	; ALL ATTRIBUTES OFF
ANSI_DEFCOLOR	.EQU	7	; WHITE ON BLACK
;
;==================================================================================================
;   ANSI EMULATION MODULE
;==================================================================================================
;
ANSI_INIT:
	; SAVE INCOMING VDA DISPATCH ADDRESS
	CALL	TSTPT		; *DEBUG*
	LD	(EMU_VDADISPADR),DE	; RECORD NEW VDA DISPATCH ADDRESS
;
	; QUERY THE VIDEO DRIVER FOR SCREEN DIMENSIONS
	LD	B,BF_VDAQRY	; FUNCTION IS QUERY
	LD	HL,0		; WE DO NOT WANT A COPY OF THE CHARACTER BITMAP DATA
	CALL	TSTPT		; *DEBUG*
	CALL	EMU_VDADISP	; PERFORM THE QUERY FUNCTION
	CALL	TSTPT		; *DEBUG*
	LD	(ANSI_DIM),DE	; SAVE THE SCREEN DIMENSIONS RETURNED
;
	; INITIALIZE ALL WORKING VARIABLES
	LD	DE,0		; DE := 0, CURSOR TO HOME POSITION 0,0
	LD	(ANSI_POS),DE	; SAVE CURSOR POSITION
	LD	HL,ANSI_STBASE	; SET STATE TO BASE
	LD	(ANSI_STATE),HL	; DO IT
	LD	A,ANSI_DEFATTR	; DEFAULT ATTRIBUTE
	LD	(ANSI_ATTR),A	; CLEAR ATTRIBUTES
	LD	A,ANSI_DEFCOLOR	; DEFAULT COLOR
	LD	(ANSI_COLOR),A	; RESET COLOR
	XOR	A		; ZERO ACCUM
	LD	(ANSI_WRAP),A	; CLEAR WRAP FLAG
	LD	(ANSI_LNM),A	; SET LINE FEED NEW LINE MODE
	LD	(ANSI_CKM),A	; CLEAR DEC CURSOR KEY MODE
	LD	(ANSI_COLM),A	; CLEAR 132 COLUMN MODE
	LD	(ANSI_QLEN),A	; ZERO THE QUEUE LENGTH
	LD	A,$FF		; SET ALL BITS OF ACCUM
	LD	(ANSI_AWM),A	; SET DEC AUTOWRAP MODE
;
	; RESET TAB STOPS TO DEFAULT (EVERY 8 CHARACTERS)
	LD	A,%10000000	; STOP AT FIRST OF EVERY 8 CHARACTERS
	LD	HL,ANSI_TABS	; POINT TO TAB STOP BITMAP
	LD	B,32		; INIT 32 BYTES
;
ANSI_INIT2:	; LOOP TO RESET TAB STOPS
	LD	(HL),A		; SET A BYTE
	INC	HL		; POINT TO NEXT BYTE
	DJNZ	ANSI_INIT2	; LOOP TILL ALL BYTES DONE
;
	LD	DE,ANSI_DISPATCH	; RETURN OUR DISPATCH ADDRESS
	CALL	TSTPT		; *DEBUG*
	XOR	A
	RET
;
;
;
ANSI_DISPATCH:
	LD	(ANSI_CIODEV),A	; *DEBUG*
	LD	A,B		; GET REQUESTED FUNCTION
	AND	$0F		; ISOLATE SUB-FUNCTION
	JR	Z,ANSI_IN	; $30
	DEC	A
	JR	Z,ANSI_OUT	; $31
	DEC	A
	JR	Z,ANSI_IST	; $32
	DEC	A
	JR	Z,ANSI_OST	; $33
	DEC	A
	JR	Z,ANSI_INITDEV	; $34
	DEC	A
	JP	Z,ANSI_QUERY	; $35
	DEC	A	
	JP	Z,ANSI_DEVICE	; $36
	CALL	PANIC
;
;==================================================================================================
;   ANSI EMULATION MODULE BIOS FUNCTION ENTRY POINTS
;==================================================================================================
;
; READ A CHARACTER
;
ANSI_IN:	; HANDLE INPUT REQUEST
;
	; RETURN QUEUED DATA IF WE HAVE ANY
	LD	A,(ANSI_QLEN)	; GET THE CURRENT QUEUE LENGTH
	OR	A		; SET FLAGS
	JR	Z,ANSI_IN1	; NOTHING THERE, GO TO KEYBOARD READ
	DEC	A		; DECREMENT THE QUEUE LENGTH
	LD	(ANSI_QLEN),A	; AND SAVE IT
	LD	HL,(ANSI_QPTR)	; GET THE QUEUE POINTER
	LD	A,(HL)		; GET THE NEXT QUEUE BYTE
	INC	HL		; INCREMENT THE POINTER
	LD	(ANSI_QPTR),HL	; AND SAVE IT
	LD	E,A		; RETURN VALUE IN E
	XOR	A		; SIGNAL SUCCESS
	RET			; DONE
;
ANSI_IN1:	; PERFORM ACTUAL KEYBOARD INPUT
	LD	B,BF_VDAKRD	; SET FUNCTION TO KEYBOARD READ
	CALL	EMU_VDADISP	; CALL VDA DISPATCHER
	LD	A,E		; CHARACTER READ INTO A
	BIT	7,A		; TEST HIGH BIT
	JR	NZ,ANSI_IN2	; HANDLE $80 OR HIGHER AS SPECIAL CHAR
	XOR	A		; OTHERWISE, SIGNAL SUCCESS
	RET			; AND RETURN THE KEY 
;
ANSI_IN2:	; HANDLE SPECIAL KEY
	CALL	ANSI_KDISP	; IF $80 OR HIGHER, DISPATCH
	JR	ANSI_IN		; AND LOOP
;
; WRITE A CHARACTER W/ EMULATION
;
ANSI_OUT:
	LD	HL,ANSI_OUT2	; RETURN ADDRESS
	PUSH	HL		; PUT IT ON STACK
	LD	A,E		; GET THE INCOMING CHARACTER
	CP	$20		; $00-$1F IS C0
	JP	C,ANSI_C0DISP	; IF C0, DO C0 DISPATCH
	CP	$80		; $20-$7F
	JR	C,ANSI_OUT1	; HANDLE VIA STATE MACHINE
	CP	$A0		; $80-$9F IS C1
	JP	C,ANSI_C1DISP	; IF C1, DO C1 DISPATCH
;
ANSI_OUT1:	; PROCESS OTHER CHARS VIA STATE MACHINE
	LD	HL,(ANSI_STATE)	; LOAD THE CURRENT STATE
	JP	(HL)		; DO IT
;	CALL	JPHL		; DO IT
;
ANSI_OUT2:	; SET RESULT AND RETURN
	XOR	A		; SIGNAL SUCCESS
	RET
;
; CHECK INPUT STATUS
;
ANSI_IST:	; CHECK QUEUE FIRST
	LD	A,(ANSI_QLEN)	; GET CURRENT QUEUE LENGTH
	OR	A		; SET FLAGS
	RET	NZ		; RETURN IF CHAR(S) WAITING
;
	; QUEUE WAS EMPTY, CHECK HARDWARE STATUS
	LD	B,BF_VDAKST	; SET FUNCTION TO KEYBOARD STATUS
	CALL	EMU_VDADISP	; CHECK STATUS
	OR	A		; SET FLAGS
	RET	Z		; NO KEYS WAITING, RETURN NO JOY
;
	; KEY WAITING, GET IT AND HANDLE IT
	LD	B,BF_VDAKRD	; SET FUNCTION TO KEYBOARD READ
	CALL	EMU_VDADISP	; DO IT
	LD	A,E		; CHARACTER READ TO A
	BIT	7,A		; TEST HIGH BIT
	JR	NZ,ANSI_IST1	; HANDLE $80 OR HIGHER AS SPECIAL CHAR
;
	; REGULAR CHARACTER RECEIVED, QUEUE IT AND RETURN CHARS WAITING STATUS
	LD	HL,ANSI_QUEUE	; SET HL TO START OF QUEUE
	LD	(ANSI_QPTR),HL	; RESET QUEUE POINTER
	LD	A,E		; RESTORE CHARACTER RECEIVED
	LD	(HL),A		; SAVE IT AT THE HEAD OF THE QUEUE
	XOR	A		; ZERO ACCUM
	INC	A		; ASSUM := 1 (NUM CHARS IN QUEUE)
	LD	(ANSI_QLEN),A	; SAVE NEW QUEUE LEN
	JR	ANSI_IST	; REPEAT
;
ANSI_IST1:	; HANDLE SPECIAL KEY
	CALL	ANSI_KDISP	; DO SPECIAL KEY HANDLING
	JR	ANSI_IST	; REPEAT
;
; CHECK OUTPUT STATUS
;
ANSI_OST:	; VIDEO OUTPUT IS *ALWAYS* READY
	XOR	A		; ZERO ACCUM
	INC	A		; A := $FF TO SIGNAL OUTPUT BUFFER READY
	RET
;
; INITIALIZE
;
ANSI_INITDEV:
	XOR	A		; SIGNAL SUCCESS
	RET			; AND RETURN
;
; QUERY STATUS
;
ANSI_QUERY:
	CALL	PANIC		; NOT IMPLEMENTED
	RET
;
; REPORT DEVICE
;
ANSI_DEVICE:
	;LD	D,CIODEV_VDA	; D := DEVICE TYPE
	LD	A,(ANSI_CIODEV)	; GET THE CURRENT CIO DEVICE *DEBUG*
	LD	D,A		; AND PASS BACK IN D *DEBUG*
	LD	E,C		; E := PHYSICAL UNIT
	XOR	A		; SIGNAL SUCCESS
	RET
;
;==================================================================================================
;   ANSI STATE MACHINE ENTRY POINTS
;==================================================================================================
;
ANSI_STBASE:	; STATE == BASE
	JP	ANSI_RENDER	; RENDER THE GLYPH
;
;
;
ANSI_STESC:	; STATE == ESCAPE SEQUENCE
	RES	7,A		; CLEAR HIGH BIT
	CP	$30		; $20 - $2F ARE INTERMEDIATE CHARS
	JP	C,ANSI_COLLINT	; COLLECT INTERMEDIATE CHARACTERS
	CP	$7F		; $30 - $7E
	RET	NC		; IGNORE $7F
	LD	HL,ANSI_STBASE	; BASE STATE
	LD	(ANSI_STATE),HL	; SET IT
	JP	ANSI_ESCDISP	; DISPATCH FOR ESCAPE SEQUENCE
;
;
;
ANSI_STCTL:	; STATE == CONTROL SEQUENCE
	RES	7,A		; CLEAR HIGH BIT
	CP	$30
	JP	C,ANSI_COLLINT	; COLLECT INTERMEDIATE CHARACTERS
	CP	$3C
	JP	C,ANSI_COLLPAR	; COLLECT PARAMETERS
	CP	$40
	JP	C,ANSI_COLLPRI	; COLLECT PRIVATE CHARACTERS
	CP	$7F		; $30 - $7E
	RET	NC		; IGNORE $7F
	LD	HL,ANSI_STBASE	; BASE STATE
	LD	(ANSI_STATE),HL	; SET IT
	JP	ANSI_CTLDISP	; DISPATCH FOR CONTROL SEQUENCE
;
;
;
ANSI_STSTR:	; STATE == STRING DATA
	RET
;
;==================================================================================================
;   ANSI C0 DISPATCHING
;==================================================================================================
;
ANSI_C0DISP:
	CP	$08		; BS: BACKSPACE
	JP	Z,ANSI_BS
	CP	$09		; HT: TAB
	JP	Z,ANSI_HT
	CP	$0A		; LF: LINEFEED
	JP	Z,ANSI_LF
	CP	$0B		; VT: VERTICAL TAB
	JP	Z,ANSI_LF	; TREAD AS LINEFEED
	CP	$0C		; FF: FORMFEED
	JP	Z,ANSI_LF	; TREAT AS LINEFEED
	CP	$0D		; CR: CARRIAGE RETURN
	JP	Z,ANSI_CR
	CP	$18		; CAN: CANCEL
	JP	Z,ANSI_CAN
	CP	$1A		; SUB: ???
	JP	Z,ANSI_SUB
	CP	$1B		; ESC: ESCAPE
	JP	Z,ANSI_ESC
	RET
;
;==================================================================================================
;   ANSI C1 DISPATCHING
;==================================================================================================
;
ANSI_C1DISP:
	CP	$84			; IND: INDEX
	JP	Z,ANSI_LF		; DO IT
	CP	$85			; NEL: NEXT LINE
	JP	Z,ANSI_NEL		; DO IT
	CP	$88			; HTS: HORIZONTAL TAB SET
	JP	Z,ANSI_HTS		; DO IT
	CP	$8D			; RI: REVERSE INDEX
	JP	Z,ANSI_RI		; DO IT
	CP	$9B			; CSI: CONTROL SEQ INTRODUCER
	JP	Z,ANSI_CSI		; HANDLE IT
;
	; IGNORE OTHERS
	RET
;
;==================================================================================================
;   ANSI ESCAPE SEQUENCE DISPATCHING
;==================================================================================================
;
ANSI_ESCDISP:
#IF (ANSITRACE >= 2)
	PRTS("<ESC>($")
	PUSH	AF
	LD	A,(ANSI_INT)
	OR	A
	CALL	NZ,COUT
	CALL	PC_COMMA
	POP	AF
	CALL	COUT
	CALL	PC_RPAREN
#ENDIF
	LD	(ANSI_FINAL),A		; RECORD THE FINAL CHARACTER
	LD	A,(ANSI_INT)		; LOAD THE INTERMEDIATE CHARACTER
	OR	A			; SET FLAGS
	JR	Z,ANSI_ESCDISP1		; NO INT CHARACTER, DO NORMAL DISPATCH
	CP	'#'			; INTERMEDIATE CHAR == '#'?
	JR	Z,ANSI_ESCDISP2		; YES, DO # DISPATCHING
	JP	ANSI_UNK		; UNKNOWN, ABORT
;
ANSI_ESCDISP1:	; NORMAL ESCAPE DISPATCHING, NO INT CHARACTER
	LD	A,(ANSI_FINAL)		; GET FINAL CHARACTER
	CP	$40			; $30-$3F
	JR	C,ANSI_ESCDISP1A	; YES, CONTINUE NORMALLY
	CP	$60			; $40-$5F
	JR	NC,ANSI_ESCDISP1A	; NOPE, $60 AND ABOVE CONTINUE NORMALLY
;
	; $40-$5F MAPS TO $80-$9F IN C1 RANGE
	CALL	ANSI_CLEAR		; CLEAR STATE RELATED VARIABLES
	LD	HL,ANSI_STBASE		; BASE STATE
	LD	(ANSI_STATE),HL		; SET IT
	ADD	A,$40			; MAP $40-$5F -> $80-$9F
	JP	ANSI_C1DISP		; PROCESS AS C1 CHARACTER
;
ANSI_ESCDISP1A:	; CONTINUE NORMAL ESCAPE SEQ DISPATCHING
	CP	'c'			; RIS: RESET TO INITIAL STATE
	JP	Z,ANSI_INITDEV		; DO A FULL RESET
	JP	ANSI_UNK		; UNKNOWN, ABORT
;
ANSI_ESCDISP2:	; ESC DISPATCHING FOR '#' INT CHAR
	LD	A,(ANSI_FINAL)		; GET FINAL CHARACTER
	CP	'8'			; DECALN: DEC SCREEN ALIGNMENT TEST
	JP	Z,ANSI_DECALN		; HANDLE IT
	JP	ANSI_UNK		; UNKNOWN, ABORT
;
;==================================================================================================
;   ANSI CONTROL SEQUENCE DISPATCHING
;==================================================================================================
;
ANSI_CTLDISP:
	LD	(ANSI_FINAL),A		; RECORD THE FINAL CHARACTER
#IF (ANSITRACE >= 2)
	PUSH	AF
	PRTS("<CTL>($")
	LD	A,(ANSI_PRI)
	OR	A
	CALL	NZ,COUT
	CALL	PC_COMMA
	LD	DE,ANSI_PARLST
	LD	A,(ANSI_PARIDX)
	INC	A
	CALL	PRTHEXBUF
	CALL	PC_COMMA
	LD	A,(ANSI_INT)
	OR	A
	CALL	NZ,COUT
	CALL	PC_COMMA
	POP	AF
	CALL	COUT
	CALL	PC_RPAREN
#ENDIF
	; BRANCH BASED ON PRIVATE CHARACTER OF SEQUENCE
	LD	A,(ANSI_PRI)		; GET THE PRIVATE CHARACTER
	OR	A			; SET FLAGS
	JR	Z,ANSI_STD		; IF ZERO, NO PRIVATE CHAR, DO STANDARD
	CP	'?'			; '?' = DEC PRIVATE
	JR	Z,ANSI_DEC		; HANDLE DEC PRIVATE SEQUENCES
	JR	ANSI_UNK		; UNKNOWN, ABORT
;
ANSI_STD:	; DISPATCH ON INTERMEDIATE CHAR W/ NO PRIVATE CHAR (STD)
	LD	A,(ANSI_INT)		; GET THE INTERMEDIATE CHARCACTER
	OR	A			; SET FLAGS
	JR	Z,ANSI_STD1		; NO INTERMEDIATE CHARACTER, HANDLE IT
	; CHECK FOR ANY OTHER STD INTERMEDIATE CHARACTERS HERE...
	JR	ANSI_UNK		; UNKNOWN, ABORT
;
ANSI_STD1:	; DISPATCH FOR FINAL CHAR W/ NO INTERMEDIATE CHAR AND NO PRIVATE CHAR (STD)
	LD	A,(ANSI_FINAL)		; GET FINAL CHARACTER
	CP	'A'			; CUU: CURSOR UP
	JP	Z,ANSI_CUU
	CP	'B'			; CUD: CURSOR DOWN
	JP	Z,ANSI_CUD
	CP	'C'			; CUF: CURSOR FORWARD
	JP	Z,ANSI_CUF
	CP	'D'			; CUB: CURSOR BACKWARD
	JP	Z,ANSI_CUB
	CP	'H'			; CUP: CURSOR POSITION
	JP	Z,ANSI_CUP
	CP	'J'			; ED: ERASE IN DISPLAY
	JP	Z,ANSI_ED
	CP	'K'			; EL: ERASE IN LINE
	JP	Z,ANSI_EL
	CP	'L'			; IL: INSERT LINE
	JP	Z,ANSI_IL
	CP	'M'			; DL: DELETE LINE
	JP	Z,ANSI_DL
	CP	'f'			; HVP: HORIZONTAL/VERTICAL POSITION
	JP	Z,ANSI_HVP
	CP	'g'			; TBC: TAB CLEAR
	JP	Z,ANSI_TBC
	CP	'h'			; SM: SET MODE
	JP	Z,ANSI_SM
	CP	'l'			; RM: RESET MODE
	JP	Z,ANSI_RM
	CP	'm'			; SGR: SELECT GRAPHIC RENDITION
	JP	Z,ANSI_SGR
	; CHECK FOR ANY OTHERS HERE
	JR	ANSI_UNK		; UNKNOWN, ABORT
;
ANSI_DEC:	; DISPATCH ON INTERMEDIATE CHAR W/ PRIVATE CHAR = '?' (DEC)
	LD	A,(ANSI_INT)		; GET THE INTERMEDIATE CHARCACTER
	OR	A			; SET FLAGS
	JR	Z,ANSI_DEC1		; NO INTERMEDIATE CHARACTER, HANDLE IT
	; CHECK FOR ANY OTHER DEC INTERMEDIATE CHARACTERS HERE...
	JR	ANSI_UNK		; UNKNOWN, ABORT
;
ANSI_DEC1:	; DISPATCH FOR FINAL CHAR W/ NO INTERMEDIATE CHAR AND PRIVATE CHAR = '?' (DEC)
	LD	A,(ANSI_FINAL)		; GET FINAL CHARACTER
	CP	'h'			; SM: SET DEC MODE
	JP	Z,ANSI_DECSM
	CP	'l'			; RM: RESET DEC MODE
	JP	Z,ANSI_DECRM
	JR	ANSI_UNK		; UNKNOWN, ABORT
;
ANSI_UNK:	; DIAGNOSE UNKNOWN SEQUENCE
#IF (ANSITRACE >= 2)
	PRTS("***UNK***$")
#ENDIF
	RET
;
;==================================================================================================
;   ANSI PROTOCOL SUPPORT FUNCTIONS
;==================================================================================================
;
; CLEAR THE WORKING VARIABLES AT START OF NEW ESC/CTL SEQUENCE
;
ANSI_CLEAR:
	PUSH	AF			; PRESERVE AF
	LD	HL,ANSI_VARS		; POINT TO VARS
	LD	B,ANSI_VARLEN		; B := NUMBER OF BYTES TO CLEAR
	XOR	A			; A := 0
;
ANSI_CLEAR1:	; LOOP
	LD	(HL),A			; CLEAR THE BYTE
	INC	HL			; BUMP POINTER
	DJNZ	ANSI_CLEAR1		; LOOP AS NEEDED
;
	POP	AF			; RECOVER AF
	RET				; DONE
;
; COLLECT INTERMEDIATE CHARACTERS
; WE DO NOT SUPPORT MORE THAN 1 WHICH IS ALL THAT IS EVER
; USED BY THE STANDARD.  IF MORE THAN ONE RECEIVED, IT IS OVERLAID
;
ANSI_COLLINT:
	LD	(ANSI_INT),A		; RECORD INTERMEDIATE CHAR
	RET				; DONE
;
; COLLECT PARAMETERS
; ';' SEPARATES PARAMETERS
; '0'-'9' ARE DIGITS OF CURRENT PARAMETER
;
ANSI_COLLPAR:
	; HANDLE SEPARATOR
	CP	$3B			; ';' SEPARATOR?
	JR	NZ,ANSI_COLLPAR1	; NOPE, CONTINUE
	LD	A,(ANSI_PARIDX)		; GET CURRENT PARM POS INDEX
	INC	A			; INCREMENT
	AND	$0F			; 16 PARMS MAX!!!
	LD	(ANSI_PARIDX),A		; SAVE IT
	RET				; DONE
;
ANSI_COLLPAR1:	; HANDLE '0'-'9'
	CP	'9' + 1			; > '9'?
	RET	NC			; YUP, IGNORE CHAR
	SUB	'0'			; CONVERT TO BINARY VALUE
	LD	B,A			; SAVE VALUE IN B
	LD	A,(ANSI_PARIDX)		; A := CURRENT PARM INDEX
	LD	HL,ANSI_PARLST		; POINT TO START OF PARM LIST
	LD	DE,0			; SETUP DE := 0
	LD	E,A			; NOW DE := PARM OFFSET
	ADD	HL,DE			; NOW HL := PARM BYTE TO UPDATE
	LD	A,(HL)			; GET CURRENT VALUE
	LD	C,A			; COPY TO C
	RLCA				; MULTIPLY BY 10
	RLCA				; "
	ADD	A,C			; "
	RLCA				; "
	ADD	A,B			; ADD NEW DIGIT
	LD	(HL),A			; SAVE UPDATED VALUE
	RET				; DONE
;
; COLLECT PRIVATE CHARACTERS
; WE DO NOT SUPPORT MORE THAN 1 WHICH IS ALL THAT IS EVER
; USED BY THE STANDARD.  IF MORE THAN ONE RECEIVED, IT IS OVERLAID
;
ANSI_COLLPRI:
	LD	(ANSI_PRI),A		; RECORD THE PRIVATE CHARACTER
	RET				; DONE
;
; CANCEL AN ESC/CTL SEQUENCE IN PROGRESS
; SOME VT TERMINALS WILL SHOW AN ERROR SYMBOL IN THIS CASE
;
ANSI_SUB:
	; DISPLAY AN ERR SYMBOL???
;
; CANCEL AN ESC/CTL SEQUENCE IN PROGRESS
;
ANSI_CAN:
	LD	HL,ANSI_STBASE	; SET STATE TO BASE
	LD	(ANSI_STATE),HL	; SAVE IT
	RET
;
; START AN ESC SEQ, CANCEL ANY ESC/CTL SEQUENCE IN PROGRESS
;
ANSI_ESC:
	CALL	ANSI_CLEAR	; CLEAR STATE RELEATED VARIABLES
	LD	HL,ANSI_STESC	; SET STATE TO ESCAPE SEQUENCE
	LD	(ANSI_STATE),HL	; SAVE IT
	RET
;
; START A CTL SEQ
;
ANSI_CSI:
	CALL	ANSI_CLEAR	; CLEAR STATE RELEATED VARIABLES
	LD	HL,ANSI_STCTL	; SET STATE TO CONTROL SEQUENCE
	LD	(ANSI_STATE),HL	; SAVE IT
	RET
;
;==================================================================================================
;   ANSI FUNCTION EXECUTION
;==================================================================================================
;
ANSI_RENDER:
#IF (ANSITRACE >= 2)
	LD	A,E
	CALL	COUT
#ENDIF
	PUSH	DE

	; IF WRAP PENDING, DO IT NOW
	LD	A,(ANSI_WRAP)	; GET THE WRAP FLAG
	OR	A		; SET FLAGS
	JR	Z,ANSI_RENDER1	; IF Z, NO WRAP, CONTINUE
	LD	A,(ANSI_AWM)	; GET AUTOWRAP MODE SETTING
	OR	A		; SET FLAGS
	CALL	NZ,ANSI_NEL	; IF SET, PERFORM A LINEWRAP (CLEARS WRAP FLAG)
;
ANSI_RENDER1:	; WRITE THE CHARACTER
	POP	DE		; RECOVER THE CHAR TO RENDER
	LD	B,BF_VDAWRC	; FUNC := WRITE CHARACTER
	CALL	EMU_VDADISP	; SPIT OUT THE RAW CHARACTER
;	
	; END OF LINE HANDLING (CHECK FOR RIGHT MARGIN EXCEEDED)
	LD	A,(ANSI_COLS)	; GET SCREEN COLUMNS
	LD	B,A		; PUT IT IN B
	LD	A,(ANSI_COL)	; GET COLUMN
	INC	A		; BUMP IT TO REFLECT NEW CURSOR POSITION
	LD	(ANSI_COL),A	; SAVE IT
	CP	B		; PAST MAX?
	RET	C		; IF NOT, ALL DONE, JUST RETURN
;
	; CURSOR MOVED PAST RIGHT MARGIN, FIX IT AND SET WRAP FLAG
	DEC	A		; BACK TO RIGHT MARGIN
	LD	(ANSI_COL),A	; SAVE IT
	CALL	ANSI_XY		; UPDATE CURSOR POSITION ON SCREEN
	LD	A,$FF		; LOAD $FF TO SET FLAG
	LD	(ANSI_WRAP),A	; SAVE FLAG
	RET			; AND RETURN
;
ANSI_FF:
	LD	DE,0		; PREPARE TO HOME CURSOR
	LD	(ANSI_POS),DE	; SAVE NEW CURSOR POSITION
	CALL	ANSI_XY		; EXECUTE
	LD	DE,(ANSI_DIM)	; GET SCREEN DIMENSIONS
	LD	H,D		; SET UP TO MULTIPLY ROWS BY COLS
	CALL	MULT8		; HL := H * E TO GET TOTAL SCREEN POSITIONS
	LD	E,' '		; FILL SCREEN WITH BLANKS
	LD	B,BF_VDAFIL	; SET FUNCTION TO FILL
	CALL	EMU_VDADISP	; PERFORM FILL
	JP	ANSI_XY		; HOME CURSOR AND RETURN
;
ANSI_BS:
	LD	A,(ANSI_COL)	; GET CURRENT COLUMN
	DEC	A		; BACK IT UP BY ONE
	RET	C		; IF CARRY, MARGIN EXCEEDED, ABORT
	LD	(ANSI_COL),A	; SAVE NEW COLUMN
	JP	ANSI_XY		; UDPATE CUSROR AND RETURN
;
ANSI_CR:
	XOR	A		; ZERO ACCUM
	LD	(ANSI_COL),A	; COL := 0
	JP	ANSI_XY		; REPOSITION CURSOR AND RETURN
;
ANSI_LF:	; LINEFEED (FORWARD INDEX)
	LD	A,(ANSI_ROW)	; GET CURRENT ROW
	LD	DE,(ANSI_DIM)	; GET SCREEN DIMENSIONS
	DEC	D		; D := MAX ROW NUM
	CP 	D		; >= LAST ROW?
	JR	NC,ANSI_LF1	; NEED TO SCROLL
	INC	A		; BUMP TO NEXT ROW
	LD	(ANSI_ROW),A	; SAVE IT
	JP	ANSI_XY		; UPDATE CURSOR AND RETURN
;
ANSI_LF1:	; SCROLL
	LD	E,1		; SCROLL FORWARD 1 LINE
	LD	B,BF_VDASCR	; SET FUNCTION TO SCROLL
	JP	EMU_VDADISP	; DO THE SCROLLING AND RETURN
;
ANSI_RI:	; REVERSE INDEX (REVERSE LINEFEED)
	LD	A,(ANSI_ROW)	; GET CURRENT ROW
	OR	A		; SET FLAGS
	JR	Z,ANSI_RI1	; IF AT TOP (ROW 0), NEED TO SCROLL
	DEC	A		; BUMP TO PRIOR ROW
	LD	(ANSI_ROW),A	; SAVE IT
	JP	ANSI_XY		; RESPOSITION CURSOR AND RETURN
;
ANSI_HT:	; HORIZONTAL TAB
;
	; CHECK FOR RIGHT MARGIN, IF AT MARGIN, IGNORE
	LD	A,(ANSI_COLS)	; GET SCREEN COLUMN COUNT
	DEC	A		; MAKE IT MAX COL NUM
	LD	E,A		; SAVE IN E
	LD	A,(ANSI_COL)	; GET CURRENT COLUMN
	CP	E		; COMPARE TO MAX
	RET	NC		; IF COL >= MAX, IGNORE
;
	; INCREMENT COL TILL A TAB STOP IS HIT OR RIGHT MARGIN
ANSI_HT1:
	INC	A		; NEXT COLUMN
	LD	D,A		; SAVE COLUMN
;	PUSH	AF		; SAVE COLUMN
;	PUSH	BC		; SAVE MAX COLUMN
	LD	HL,ANSI_TABS	; POINT TO TABSTOP BITMAP
	CALL	BITTST		; TEST BIT FOR CURRENT COLUMN
;	POP	BC		; RECOVER MAX COLUMN
;	POP	AF		; RECOVER CUR COLUMN
	LD	A,D		; RECOVER COLUMN
	JR	NZ,ANSI_HT2	; IF TABSTOP HIT, COMMIT NEW COLUMN
	CP	E		; TEST FOR RIGHT MARGIN
	JR	NC,ANSI_HT2	; IF AT RIGHT MARGIN, COMMIT NEW COLUMN
	JR	ANSI_HT1	; LOOP UNTIL DONE
;
ANSI_HT2:	; COMMIT THE NEW COLUMN VALUE
	LD	(ANSI_COL),A	; SAVE THE NEW COLUMN
	JP	ANSI_XY		; UPDATE CURSOR AND RETURN
;
ANSI_RI1:	; REVERSE SCROLL
	LD	E,-1		; SCROLL -1 LINES (REVERSE SCROLL 1 LINE)
	LD	B,BF_VDASCR	; SET FUNCTION TO SCROLL
	JP	EMU_VDADISP	; DO THE SCROLLING AND RETURN
;
;
;
ANSI_HTS:	; HORIZONTAL TAB SET
	LD	HL,ANSI_TABS	; POINT TO TAB STOP BITMAP
	LD	A,(ANSI_COL)	; SET TAB STOP AT CURRENT COL
	CALL	BITSET		; SET THE APPROPRIATE BIT
	RET
;
;
;
ANSI_TBC:	; TAB CLEAR
	LD	A,(ANSI_PARLST)	; GET FIRST PARM
	OR	A		; SET FLAGS
	JR	Z,ANSI_TBC1	; 0 = CLEAR TAB AT CURRENT COL
	CP	3		; TEST FOR 3
	JR	Z,ANSI_TBC2	; 3 = CLEAR ALL TABS
	RET			; ANYTHING ELSE IS IGNORED
;
ANSI_TBC1:	; CLEAR TAB AT CURRENT COL
	LD	HL,ANSI_TABS	; POINT TO TAB STOP BITMAP
	LD	A,(ANSI_COL)	; SET TAB STOP AT CURRENT COL
	CALL	BITCLR		; CLEAR THE APPROPRIATE BIT
	RET			; DONE
;
ANSI_TBC2:	; CLEAR ALL TABS
	LD	HL,ANSI_TABS	; POINT TO TABSTOP BITMAP
	LD	B,32		; CLEAR 32 BYTES
	XOR	A		; CLEAR WITH  VALUE OF ZERO
;
ANSI_TBC3:	; CLEAR ALL TABS LOOP
	LD	(HL),A		; SET THE CURRENT BYTE
	INC	HL		; POINT TO NEXT BYTE
	DJNZ	ANSI_TBC3	; LOOP UNTIL DONE
	RET			; DONE
;
;
;
ANSI_SM:	; SET MODE
ANSI_DECSM:	; SET DEC MODE
	LD	C,$FF		; FLAG VALUE (SET VALUE)
	JR	ANSI_MODE	; GO TO SET/RESET MODE
;
ANSI_RM:	; RESET MODE
ANSI_DECRM:	; RESET DEC MODE
	LD	C,$00		; FLAG VALUE (RESET VALUE)
	JR	ANSI_MODE	; GO TO SET/RESET MODE
;
ANSI_MODE:	; (RE)SET MODES, FLAG VALUE IN C
	LD	A,(ANSI_PARIDX)	; GET CURRENT PARM INDEX
	INC	A		; INCREMENT TO MAKE IT THE PARM COUNT
	LD	B,A		; MOVE COUNT TO B FOR LOOPING
	LD	HL,ANSI_PARLST	; USE HL AS PARM POINTER
	
ANSI_MODE1:	; (RE)SET MODE LOOP
	PUSH	BC		; SAVE LOOP COUNTER
	PUSH	HL		; SAVE PARM INDEX
	CALL	ANSI_MODE2	; DO THE WORK
	POP	HL		; RESTORE PARM INDEX
	POP	BC		; RESTORE LOOP COUNTER
	INC	HL		; BUMP THE PARM INDEX
	DJNZ	ANSI_MODE1	; LOOP THRU ALL PARMS

ANSI_MODE2:	; (RE)SET MODE LOOP
	LD	A,(ANSI_PRI)	; GET PRIVATE CHAR
	OR	A		; SET FLAGS
	JR	Z,ANSI_MODE3	; IF ZERO, HANDLE SANDARD MODES
	CP	'?'		; IF '?', DEC PRIVATE
	JR	Z,ANSI_MODE4	; HANDLE DEC PRIVATE MODES
	RET			; OTHERWISE IGNORE
;
ANSI_MODE3:	; STANDARD MODES
	LD	A,(HL)		; GET PARM
	INC	HL		; INCREMENT POINTER FOR NEXT LOOP
	CP	20		; LNM: LINE FEED NEW LINE MODE?
	JR	Z,ANSI_MDLNM	; DO IT
	RET			; OTHERWISE IGNORE
;
ANSI_MODE4:	; DEC PRIVATE MODES
	LD	A,(HL)		; GET PARM
	CP	1		; DECCKM: DEC CURSOR KEY MODE
	JR	Z,ANSI_MDDECCKM	; DO IT
	CP	3		; DECCOLM: DEC COLUMN MODE
	JR	Z,ANSI_MDDECCOLM	; DO IT
	CP	7		; DECAWM: DEC AUTOWRAP MODE
	JR	Z,ANSI_MDDECAWM	; DO IT
	RET			; OTHERWISE IGNORE
;
ANSI_MDLNM:	; (RE)SET LINE FEED NEW LINE MODE
	LD	A,C		; GET THE VALUE
	LD	(ANSI_LNM),A	; SAVE IT
	RET
;
ANSI_MDDECCKM:	; (RE)SET DEC CURSOR KEY MODE FLAG
	LD	A,C		; GET THE VALUE
	LD	(ANSI_CKM),A	; SAVE IT
	RET			; DONE
;
ANSI_MDDECCOLM:	; (RE)SET DEC COLUMN MODE
	LD	A,C		; GET THE VALUE
	LD	(ANSI_COLM),A	; SAVE IT
	JP	ANSI_FF		; CLEAR SCREEN
;
ANSI_MDDECAWM:	; (RE)SET DEC AUTOWRAP MODE
	LD	A,C		; GET THE VALUE
	LD	(ANSI_AWM),A	; SAVE IT
	RET			; DONE
;
;
;
ANSI_NEL:	; NEXT LINE
	CALL	ANSI_CR
	JP	ANSI_LF
;
;
;
ANSI_CUU:	; CURSOR UP
	LD	A,(ANSI_PARLST)		; GET PARM
	OR	A			; SET FLAGS
	JR	NZ,ANSI_CUU1		; WE HAVE A PARM, CONTINUE
	INC	A			; DEFAULT TO 1
;
ANSI_CUU1:
	LD	B,A			; PARM IN B
	LD	A,(ANSI_ROW)		; GET CURRENT ROW
	SUB	B			; DECREMENT BY PARM VALUE
	JR	NC,ANSI_CUU2		; NO CARRY, WE ARE GOOD
	XOR	A			; LESS THAN 0, FIX IT
;
ANSI_CUU2:
	LD	(ANSI_ROW),A		; SAVE IT
	JP	ANSI_XY			; MOVE CURSOR AND RETURN
;
;
;
ANSI_CUD:	; CURSOR DOWN
	LD	A,(ANSI_PARLST)		; GET PARM
	OR	A			; SET FLAGS
	JR	NZ,ANSI_CUD1		; WE HAVE A PARM, CONTINUE
	INC	A			; DEFAULT TO 1
ANSI_CUD1:
	LD	B,A			; PARM IN B
	LD	A,(ANSI_ROWS)		; GET ROW COUNT
	DEC	A			; DEC FOR MAX ROW NUM
	LD	C,A			; MAX ROW NUM IN C
	LD	A,(ANSI_ROW)		; GET CURRENT ROW
	ADD	A,B			; ADD PARM VALUE, A HAS NEW ROW
	CP	C			; COMPARE NEW ROW TO MAX ROW
	JR	C,ANSI_CUD2		; IF CARRY, WE ARE WITHIN MARGIN
	LD	A,C			; OTHERWISE, SET TO MARGIN
;
ANSI_CUD2:
	LD	(ANSI_ROW),A		; SAVE IT
	JP	ANSI_XY			; MOVE CURSOR AND RETURN
;
;
;
ANSI_CUF:	; CURSOR FORWARD
	LD	A,(ANSI_PARLST)		; GET PARM
	OR	A			; SET FLAGS
	JR	NZ,ANSI_CUF1		; WE HAVE A PARM, CONTINUE
	INC	A			; DEFAULT TO 1
;
ANSI_CUF1:
	LD	B,A			; PARM IN B
	LD	A,(ANSI_COLS)		; GET COL COUNT
	DEC	A			; DEC FOR MAX COL NUM
	LD	C,A			; MAX COL NUM IN C
	LD	A,(ANSI_COL)		; GET CURRENT COL
	ADD	A,B			; ADD PARM VALUE, A HAS NEW COL
	CP	C			; COMPARE NEW COL TO MAX COL
	JR	C,ANSI_CUF2		; IF CARRY, WE ARE WITHIN MARGINS
	LD	A,C			; OTHERWISE, SET TO MARGIN
;
ANSI_CUF2:	
	LD	(ANSI_COL),A		; SAVE IT
	JP	ANSI_XY			; MOVE CURSOR AND RETURN
;
;
;
ANSI_CUB:	; CURSOR BACKWARD
	LD	A,(ANSI_PARLST)		; GET PARM
	OR	A			; SET FLAGS
	JR	NZ,ANSI_CUB1		; WE HAVE A PARM, CONTINUE
	INC	A			; DEFAULT TO 1
;
ANSI_CUB1:
	LD	B,A			; PARM IN B
	LD	A,(ANSI_COL)		; GET CURRENT COL
	SUB	B			; DECREMENT BY PARM VALUE
	JR	NC,ANSI_CUB2		; NO CARRY, WE ARE GOOD
	XOR	A			; LESS THAN 0, FIX IT
;
ANSI_CUB2:
	LD	(ANSI_COL),A		; SAVE IT
	JP	ANSI_XY			; MOVE CURSOR AND RETURN
;
;
;
ANSI_CUP:	; CURSOR UPDATE
ANSI_HVP:	; HORIZONTAL/VERTICAL POSITION
;
	; HANDLE ROW NUMBER
	LD	A,(ANSI_PARLST + 0)	; ROW PARM
	DEC	A			; ADJUST FOR ZERO OFFSET
	JP	P,ANSI_CUP1		; 0 OR MORE, OK, CONTINUE
	XOR	A			; NEGATIVE, FIX IT
ANSI_CUP1:
	LD	HL,ANSI_ROWS		; HL POINTS TO ROW COUNT
	CP	(HL)			; COMPARE TO ROW COUNT
	JR	C,ANSI_CUP2		; IN BOUNDS, CONTINUE
	LD	A,(HL)			; FIX IT, LOAD ROW COUNT
	DEC	A			; SET TO LAST ROW NUM
ANSI_CUP2:
	LD	D,A			; COMMIT ROW NUMBER TO D
;
	; HANDLE COL NUMBER
	LD	A,(ANSI_PARLST + 1)	; COL PARM
	DEC	A			; ADJUST FOR ZERO OFFSET
	JP	P,ANSI_CUP3		; 0 OR MORE, OK, CONTINUE
	XOR	A			; NEGATIVE, FIX IT
ANSI_CUP3:
	LD	HL,ANSI_COLS		; HL POINTS TO COL COUNT
	CP	(HL)			; COMPARE TO COL COUNT
	JR	C,ANSI_CUP4		; IN BOUNDS, CONTINUE
	LD	A,(HL)			; FIX IT, LOAD COL COUNT
	DEC	A			; SET TO LAST COL NUM
ANSI_CUP4:
	LD	E,A			; COMMIT COL NUMBER TO E
;
	; COMMIT THE NEW CURSOR POSITION AND RETURN
	LD	(ANSI_POS),DE		; SAVE IT
	JP	ANSI_XY			; UPDATE CURSOR AND RETURN
;
;
;
ANSI_ED:	; ERASE IN DISPLAY
	LD	A,(ANSI_PARLST + 0)	; GET FIRST PARM
	CP	0			; ERASE CURSOR TO EOS
	JR	Z,ANSI_ED1
	CP	1			; ERASE START THRU CURSOR
	JR	Z,ANSI_ED2
	CP	2			; ERASE FULL DISPLAY?
	JR	Z,ANSI_ED3
	RET				; INVALID?
;
ANSI_ED1:	; ERASE CURSOR THRU EOS
	LD	DE,(ANSI_POS)		; GET CURSOR POSITION
	CALL	ANSI_XY2IDX		; HL NOW HAS CURSOR INDEX
	PUSH	HL			; SAVE IT
	LD	DE,(ANSI_DIM)		; GET SCREEN DIMENSIONS
	LD	E,0			; COL POSITION := 0
	CALL	ANSI_XY2IDX		; HL NOW HAS EOS INDEX
	POP	DE			; RECOVER CURSOR POS INDEX
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; SUBTRACT CURSOR INDEX FROM EOS INDEX
	JR	ANSI_ED4		; COMPLETE THE FILL
;
ANSI_ED2:	; ERASE START THRU CURSOR
	LD	DE,0			; CURSOR TO 0,0 FOR NOW
	LD	B,BF_VDASCP		; SET FUNCTION TO SET CURSOR POSITION
	CALL	EMU_VDADISP		; DO IT
	LD	DE,(ANSI_POS)		; GET ORIGINAL CURSOR POSITION
	CALL	ANSI_XY2IDX		; HL NOW HAS INDEX
	INC	HL			; ADD 1 POSITION TO ERASE THRU CURSOR POSITION
	JR	ANSI_ED4		; COMPLETE THE FILL
;
ANSI_ED3:	; ERASE FULL DISPLAY
	LD	DE,0			; CURSOR POS 0,0
	LD	B,BF_VDASCP		; FUNCTION = SET CURSOR POS
	CALL	EMU_VDADISP		; DO IT
	LD	DE,(ANSI_DIM)		; DE := SCREEN ROWS/COLS
	CALL	ANSI_XY2IDX		; HL := CHARS ON SCREEN
;
ANSI_ED4:	; COMMON FILL PROCESS COMPLETION
	LD	E,' '			; FILL WITH BLANK
	LD	B,BF_VDAFIL		; FUNCTION = FILL
	CALL	EMU_VDADISP		; DO IT
	JP	ANSI_XY			; RESTORE CURSOR POS AND RETURN
;
;
;
ANSI_EL:	; ERASE IN LINE
	LD	A,(ANSI_PARLST + 0)	; GET FIRST PARM
	CP	0			; ERASE CURSOR TO EOL
	JR	Z,ANSI_EL1
	CP	1			; ERASE START THRU CURSOR
	JR	Z,ANSI_EL2
	CP	2			; ERASE FULL LINE?
	JR	Z,ANSI_EL3
	RET				; INVALID?
;
ANSI_EL1:	; ERASE CURSOR THRU EOL
	LD	DE,(ANSI_POS)		; GET CURSOR POSITION
	CALL	ANSI_XY2IDX		; HL NOW HAS CURSOR INDEX
	PUSH	HL			; SAVE IT
	LD	DE,(ANSI_POS)		; GET CURSOR POSITION
	LD	E,0			; COL POSITION := 0
	INC	D			; ROW := ROW + 1
	CALL	ANSI_XY2IDX		; HL NOW HAS EOL INDEX
	POP	DE			; RECOVER CURSOR POS INDEX
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; SUBTRACT CURSOR INDEX FROM EOL INDEX
	JR	ANSI_EL4		; COMPLETE THE FILL
;
ANSI_EL2:	; ERASE START THRU CURSOR
	LD	DE,(ANSI_POS)		; GET CURSOR POS
	LD	E,0			; COL := 0, START OF ROW
	LD	B,BF_VDASCP		; SET FUNCTION TO SET CURSOR POSITION
	CALL	EMU_VDADISP		; DO IT
	LD	HL,(ANSI_POS)		; GET ORIGINAL CURSOR POSITION
	LD	H,0			; ONLY ERASE COLUMNS
	INC	HL			; ADD 1 POSITION TO ERASE THRU CURSOR POSITION
	JR	ANSI_EL4		; COMPLETE THE FILL
;
ANSI_EL3:	; ERASE FULL LINE
	LD	DE,(ANSI_POS)		; GET CURSOR POSITION
	LD	E,0			; COL := 0 (START OF ROW)
	LD	B,BF_VDASCP		; FUNC = SET CURSOR POS
	CALL	EMU_VDADISP		; DO IT
	LD	HL,(ANSI_DIM)		; GET SCREEN DIM IN HL
	LD	H,0			; H := 0, HL IS NOW CHARS IN A LINE
	JR	ANSI_EL4		; COMPLETE THE FILL
;
ANSI_EL4	.EQU	ANSI_ED4	; REUSE CODE ABOVE
;
;
;
ANSI_IL:	; INSERT LINE
	LD	A,(ANSI_PARLST)		; GET PARM
	OR	A			; SET FLAGS
	JR	NZ,ANSI_IL1		; GOT IT CONTINUE
	INC	A			; NO PARM, DEFAULT TO 1
;
ANSI_IL1:
	LD	B,A			; SET LOOP COUNTER
	LD	DE,(ANSI_DIM)		; GET SCREEN DIMENSIONS
	DEC	D			; POINT TO LAST ROW
	LD	E,0			; FIRST CHAR OF ROW
;
ANSI_IL2:
	PUSH	BC			; PRESERVE LOOP COUNTER
	PUSH	DE			; PRESERVE STARTING POSTION
	CALL	ANSI_IL3		; DO AN ITERATION
	POP	DE			; RECOVER STARTING POSITION
	POP	BC			; RECOVER LOOP COUNTER
	DJNZ	ANSI_IL2		; LOOP AS NEEDED
;
	; RESTORE CURSOR POSTION AND RETURN
	JP	ANSI_XY
;
ANSI_IL3:
	; SET CURSOR POSITION TO DEST
	PUSH	DE			; PRESERVE DE
	LD	B,BF_VDASCP		; FUNC = SET CURSOR POS
	CALL	EMU_VDADISP		; DO IT
	POP	DE			; RECOVER DE
	; SET HL TO LENGTH
	LD	HL,(ANSI_DIM)		; GET DIMENSIONS
	LD	H,0			; ZERO MSB, SO COPY LEN IS COL COUNT
	; CHECK ROW, GET OUT IF WORKING ROW IS CURRENT ROW
	LD	A,(ANSI_ROW)		; GET CURRENT ROW
	CP	D			; COMPARE TO WORKING ROW NUM
	JR	Z,ANSI_IL4		; IF EQUAL WE ARE DONE
	; SET DE TO SOURCE POS
	DEC	D			; DE NOW POINTS TO PRIOR ROW
	; DO THE COPY
	PUSH	DE			; PRESERVE DE
	LD	B,BF_VDACPY		; FUNCTION = COPY
	CALL	EMU_VDADISP		; COPY THE LINE
	POP	DE			; RECOVER DE
	JR	ANSI_IL3		; LOOP
;
ANSI_IL4:	;CLEAR INSERTED LINE
	LD	E,' '			; FILL WITH BLANK
	LD	B,BF_VDAFIL		; FUNCTION = FILL
	JP	EMU_VDADISP		; DO IT
;
;
;
ANSI_DL:	; DELETE LINE
	LD	A,(ANSI_PARLST)		; GET PARM
	OR	A			; SET FLAGS
	JR	NZ,ANSI_DL1		; GOT IT CONTINUE
	INC	A			; NO PARM, DEFAULT TO 1
;
ANSI_DL1:
	LD	B,A			; SET LOOP COUNTER
	LD	DE,(ANSI_POS)		; GET CURSOR POS
	LD	E,0			; COL := 0, START OF ROW
;
ANSI_DL2:
	PUSH	BC			; PRESERVE LOOP COUNTER
	PUSH	DE			; PRESERVE STARTING POSTION
	CALL	ANSI_DL3		; DO AN ITERATION
	POP	DE			; RECOVER STARTING POSITION
	POP	BC			; RECOVER LOOP COUNTER
	DJNZ	ANSI_DL2		; LOOP AS NEEDED
;
	; RESTORE CURSOR POSTION AND RETURN
	JP	ANSI_XY
;
ANSI_DL3:
	; SET CURSOR TO START OF DEST ROW
	PUSH	DE			; PRESERVE DE
	LD	B,BF_VDASCP		; FUNC = SET CURSOR POS
	CALL	EMU_VDADISP		; DO IT
	POP	DE			; RECOVER DE
	; SET DE TO SOURCE POS
	INC	D			; NEXT ROW, DE NOW HAS SOURCE
	; SET HL TO LENGTH
	LD	HL,(ANSI_DIM)		; GET DIMENSIONS
	LD	H,0			; ZERO MSB, SO COPY LEN IS COL COUNT
	; CHECK ROW, GET OUT IF WORKING ROW NUM PAST END
	LD	A,(ANSI_ROWS)		; GET ROW COUNT
	CP	D			; COMPARE TO WORKING ROW NUM
	JR	Z,ANSI_DL4		; IF EQUAL WE ARE DONE
	; DO THE COPY
	PUSH	DE			; PRESERVE DE
	LD	B,BF_VDACPY		; FUNCTION = COPY
	CALL	EMU_VDADISP		; COPY THE LINE
	POP	DE			; RECOVER DE
	JR	ANSI_DL3		; LOOP
;
ANSI_DL4:	;CLEAR BOTTOM LINE
	LD	E,' '			; FILL WITH BLANK
	LD	B,BF_VDAFIL		; FUNCTION = FILL
	JP	EMU_VDADISP		; DO IT
;
;
;
ANSI_SGR:	; SET GRAPHIC RENDITION
	LD	A,(ANSI_PARIDX)		; GET CURRENT PARM INDEX
	INC	A			; INC TO MAKE IT THE COUNT
	LD	B,A			; B IS NOW LOOP COUNTER
	LD	HL,ANSI_PARLST		; HL POINTS TO START OF PARM LIST
;
ANSI_SGR1:	; PROCESSING LOOP
	PUSH	BC			; PRESERVE BC
	PUSH	HL			; PRESERVE HL
	LD	A,(HL)
	CALL	ANSI_SGR2		; HANDLE PARM
	POP	HL			; RESTORE HL
	POP	BC			; RESTORE BC
	INC	HL			; POINT TO NEXT PARM
	DJNZ	ANSI_SGR1		; LOOP TILL DONE
;
	; NOW IMPLEMENT ALL CHANGES
	LD	A,(ANSI_ATTR)		; GET THE ATTRIBUTE VALUE
	LD	E,A			; MOVE TO E
	LD	B,BF_VDASAT		; SET ATTRIBUTE FUNCTION
	CALL	EMU_VDADISP		; CALL THE FUNCTION
	LD	A,(ANSI_COLOR)		; GET THE COLOR VALUE
	LD	E,A			; MOVE TO E
	LD	B,BF_VDASCO		; SET ATTRIBUTE FUNCTION
	CALL	EMU_VDADISP		; CALL THE FUNCTION
	RET				; RETURN
;
ANSI_SGR2:	; HANDLE THE REQUEST CODE
	CP	0			; ALL OFF
	JR	Z,ANSI_SGR_OFF		; DO IT
	CP	1			; BOLD
	JR	Z,ANSI_SGR_BOLD		; DO IT
	CP	4			; UNDERLINE
	JR	Z,ANSI_SGR_UL		; DO IT
	CP	5			; BLINK
	JR	Z,ANSI_SGR_BLINK	; DO IT
	CP	7			; REVERSE
	JR	Z,ANSI_SGR_REV		; DO IT
	CP	30			; START OF FOREGROUND
	RET	C			; OUT OF RANGE
	CP	38			; END OF RANGE
	JR	C,ANSI_SGR_FG		; SET FOREGROUND
	CP	40			; START OF BACKGROUND
	RET	C			; OUT OF RANGE
	CP	48			; END OF RANGE
	JR	C,ANSI_SGR_BG		; SET BACKGROUND
	RET				; OTHERWISE OUT OF RANGE
;
ANSI_SGR_OFF:
	LD	A,ANSI_DEFATTR	; DEFAULT ATTRIBUTE
	LD	(ANSI_ATTR),A	; CLEAR ATTRIBUTES
	LD	A,ANSI_DEFCOLOR	; DEFAULT COLOR
	LD	(ANSI_COLOR),A	; RESET COLOR
	RET
;
ANSI_SGR_BOLD:
	LD	A,(ANSI_COLOR)		; LOAD CURRENT COLOR
	OR	%00001000		; SET BOLD BIT
	LD	(ANSI_COLOR),A		; SAVE IT
	RET
;
ANSI_SGR_UL:
	LD	A,(ANSI_ATTR)		; LOAD CURRENT ATTRIBUTE
	OR	%00000010		; SET UNDERLINE BIT
	LD	(ANSI_ATTR),A		; SAVE IT
	RET
;
ANSI_SGR_BLINK:
	LD	A,(ANSI_ATTR)		; LOAD CURRENT ATTRIBUTE
	OR	%00000001		; SET BLINK BIT
	LD	(ANSI_ATTR),A		; SAVE IT
	RET
;
ANSI_SGR_REV:
	LD	A,(ANSI_ATTR)		; LOAD CURRENT ATTRIBUTE
	OR	%00000100		; SET REVERSE BIT
	LD	(ANSI_ATTR),A		; SAVE IT
	RET
;
ANSI_SGR_FG:
	SUB	30
	LD	E,A
	LD	A,(ANSI_COLOR)
	AND	%11111000
	OR	E
	LD	(ANSI_COLOR),A
	RET
;
ANSI_SGR_BG:
	SUB	40
	RLCA
	RLCA
	RLCA
	RLCA
	LD	E,A
	LD	A,(ANSI_COLOR)
	AND	%10001111
	OR	E
	LD	(ANSI_COLOR),A
	RET
;
;
;
ANSI_DECALN:	; DEC SCREEN ALIGNMENT TEST
	LD	DE,0		; PREPARE TO HOME CURSOR
	LD	(ANSI_POS),DE	; SAVE NEW CURSOR POSITION
	CALL	ANSI_XY		; EXECUTE
	LD	DE,(ANSI_DIM)	; GET SCREEN DIMENSIONS
	LD	H,D		; SET UP TO MULTIPLY ROWS BY COLS
	CALL	MULT8		; HL := H * E TO GET TOTAL SCREEN POSITIONS
	LD	E,'E'		; FILL SCREEN WITH BLANKS
	LD	B,BF_VDAFIL	; SET FUNCTION TO FILL
	CALL	EMU_VDADISP	; PERFORM FILL
	JP	ANSI_XY		; HOME CURSOR AND RETURN
;
;==================================================================================================
;   ANSI PROTOCOL KEYBOARD DISPATCHING
;==================================================================================================
;
; HANDLE SPECIAL KEYBOARD CHARACTERS BY FILLING QUEUE WITH DATA
;
ANSI_KDISP:
	; RESET THE QUEUE POINTER
	LD	HL,ANSI_QUEUE
	LD	(ANSI_QPTR),HL
;
	; HANDLE FUNCTION KEYS
	LD	B,'P'
	CP	$E0		; F1
	JR	Z,ANSI_KDISP_FN
	LD	B,'Q'
	CP	$E1		; F2
	JR	Z,ANSI_KDISP_FN
	LD	B,'R'
	CP	$E2		; F3
	JR	Z,ANSI_KDISP_FN
	LD	B,'S'
	CP	$E3		; F4
	JR	Z,ANSI_KDISP_FN
;
	; HANDLE EDIT KEYS
	LD	B,'2'
	CP	$F0		; INSERT
	JR	Z,ANSI_KDISP_ED
	LD	B,'3'
	CP	$F1		; DELETE
	JR	Z,ANSI_KDISP_ED
	LD	B,'1'
	CP	$F2		; HOME
	JR	Z,ANSI_KDISP_ED
	LD	B,'4'
	CP	$F3		; END
	JR	Z,ANSI_KDISP_ED
	LD	B,'5'
	CP	$F4		; PAGEUP
	JR	Z,ANSI_KDISP_ED
	LD	B,'6'
	CP	$F5		; PAGEDOWN
	JR	Z,ANSI_KDISP_ED
;
	; HANDLE DIRECTION KEYS
	LD	B,'A'
	CP	$F6		; UP
	JR	Z,ANSI_KDISP_DIR
	LD	B,'B'
	CP	$F7		; DOWN
	JR	Z,ANSI_KDISP_DIR
	LD	B,'D'
	CP	$F8		; LEFT
	JR	Z,ANSI_KDISP_DIR
	LD	B,'C'
	CP	$F9		; RIGHT
	JR	Z,ANSI_KDISP_DIR
;
	RET			; NO MATCH, DONE
;
ANSI_KDISP_FN:	; ADD FUNCTION KEY SEQUENCE TO QUEUE
	LD	A,$1B
	LD	(HL),A
	INC	HL
	LD	A,'O'
	LD	(HL),A
	INC	HL
	LD	A,B
	LD	(HL),A
	LD	A,3
	LD	(ANSI_QLEN),A
	RET
;
ANSI_KDISP_ED:	; ADD EDIT KEY SEQUENCE TO QUEUE
	LD	A,$1B
	LD	(HL),A
	INC	HL
	LD	A,'['
	LD	(HL),A
	INC	HL
	LD	A,B
	LD	(HL),A
	INC	HL
	LD	A,'~'
	LD	(HL),A
	LD	A,4
	LD	(ANSI_QLEN),A
	RET
;
ANSI_KDISP_DIR:	; ADD DIRECTION KEY SEQUENCE TO QUEUE
;
	; SPECIAL CASE FOR CURSOR KEY MODE
	LD	A,(ANSI_CKM)
	OR	A
	JR	NZ,ANSI_KDISP_FN	; HANDLE LIKE FUNCTION KEY
;
	LD	A,$1B
	LD	(HL),A
	INC	HL
	LD	A,'['
	LD	(HL),A
	INC	HL
	LD	A,B
	LD	(HL),A
	LD	A,3
	LD	(ANSI_QLEN),A
	RET
;
;==================================================================================================
;   SUPPORT FUNCTIONS
;==================================================================================================
;
ANSI_XY:
	XOR	A		; ZERO ACCUM	
	LD	(ANSI_WRAP),A	; CLEAR THE WRAP FLAG
	LD	DE,(ANSI_POS)	; GET THE DESIRED CURSOR POSITION
	LD	B,BF_VDASCP	; SET FUNCTION TO SET CURSOR POSITION
	JP	EMU_VDADISP	; REPOSITION CURSOR
;
; CONVERT XY COORDINATES IN DE INTO LINEAR INDEX IN HL
; D=ROW, E=COL
;
ANSI_XY2IDX:
	PUSH	DE
	LD	HL,(ANSI_DIM)	; GET DIMENSIONS
	LD	H,L		; COLS -> H
	LD	E,D		; ROW NUM -> E
	CALL	MULT8		; HL := H * E (ROW OFFSET)
	POP	DE		; RECOVER ORIGINAL ROW/COL
	LD	D,0		; GET RID OF ROW COUNT
	ADD	HL,DE		; ADD COLUMN OFFSET
	RET			; RETURN, HL HAS INDEX
;
;==================================================================================================
;   WORKING DATA STORAGE
;==================================================================================================
;
ANSI_POS:
ANSI_COL	.DB	0	; CURRENT COLUMN - 0 BASED
ANSI_ROW	.DB	0	; CURRENT ROW - 0 BASED
;
ANSI_DIM:
ANSI_COLS	.DB	80	; NUMBER OF COLUMNS ON SCREEN
ANSI_ROWS	.DB	24	; NUMBER OF ROWS ON SCREEN
;
ANSI_STATE	.DW	PANIC		; CURRENT FUNCTION FOR STATE MACHINE
ANSI_ATTR	.DB	ANSI_DEFATTR	; CURRENT CHARACTER ATTRIBUTE
ANSI_COLOR	.DB	ANSI_DEFCOLOR	; CURRENT CHARACTER COLOR;
ANSI_WRAP	.DB	0		; WRAP PENDING FLAG
ANSI_TABS	.FILL	32,0		; TAB STOP BIT MAP (256 BITS)
ANSI_LNM	.DB	0		; LINE FEED NEW LINE MODE FLAG
ANSI_CKM	.DB	0		; DEC CURSOR KEY MODE FLAG
ANSI_COLM	.DB	0		; DEC 132 COLUMN MODE FLAG
ANSI_AWM	.DB	0		; DEC AUTOWRAP MODE FLAG
ANSI_QLEN	.DB	0		; INPUT QUEUE LENGTH
ANSI_QPTR	.DW	0		; CURRENT QUEUE POINTER
ANSI_QUEUE	.FILL	16,0		; 16 BYTE QUEUE BUFFER
;
ANSI_VARS:
ANSI_PRI	.DB	0	; PRIVATE CHARACTER RECORDED HERE
ANSI_INT	.DB	0	; INTERMEDIATE CHARACTER RECORDED HERE
ANSI_FINAL	.DB	0	; FINAL CHARACTER RECORDED HERE
ANSI_PARIDX	.DB	0	; NUMBER OF PARAMETERS RECORDED
ANSI_PARLST	.FILL	16,0	; PARAMETER VALUE LIST (UP TO 16 BYTE VALUES)
ANSI_VARLEN	.EQU	$ - ANSI_VARS
;
ANSI_CIODEV	.DB	0	; *DEBUG*
