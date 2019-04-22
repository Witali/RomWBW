;
;==================================================================================================
; SIO DRIVER (SERIAL PORT)
;==================================================================================================
;
;  SETUP PARAMETER WORD:
;  +-------+---+-------------------+ +---+---+-----------+---+-------+
;  |       |RTS| ENCODED BAUD RATE | |DTR|XON|  PARITY   |STP| 8/7/6 |
;  +-------+---+---+---------------+ ----+---+-----------+---+-------+
;    F   E   D   C   B   A   9   8     7   6   5   4   3   2   1   0
;       -- MSB (D REGISTER) --           -- LSB (E REGISTER) --
;
; FOR THE ECB-ZILOG-PERIPHERALS BOARD, INFORMATION ON JUMPER SETTINGS 
; AND BAUD RATES CAN BE FOUND HERE:
; https://www.retrobrewcomputers.org/doku.php?id=boards:ecb:zilog-peripherals:clock-divider
; 
; SIO PORT A (COM1:) and SIO PORT B (COM2:) ARE MAPPED TO DEVICE UC1: AND UL1: IN CP/M.
;             
SIO_NONE	.EQU	0
SIO_SIO		.EQU	1
;               
#IF (SIOMODE == SIOMODE_RC)
SIOA_CMD	.EQU	SIOBASE + $00	
SIOA_DAT	.EQU	SIOBASE + $01
SIOB_CMD	.EQU	SIOBASE + $02
SIOB_DAT	.EQU	SIOBASE + $03
#ENDIF	
;	
#IF (SIOMODE == SIOMODE_SMB)	
SIOA_CMD	.EQU	SIOBASE + $02
SIOA_DAT	.EQU	SIOBASE + $00
SIOB_CMD	.EQU	SIOBASE + $03
SIOB_DAT	.EQU	SIOBASE + $01
#ENDIF
;
#IF (SIOMODE == SIOMODE_ZP)		
SIOA_CMD	.EQU	SIOBASE + $06
SIOA_DAT	.EQU	SIOBASE + $04 
SIOB_CMD	.EQU	SIOBASE + $07
SIOB_DAT	.EQU	SIOBASE + $05
#ENDIF
;
#IF (SIOMODE == SIOMODE_EZZ80)
SIOA_CMD	.EQU	SIOBASE + $01	
SIOA_DAT	.EQU	SIOBASE + $00
SIOB_CMD	.EQU	SIOBASE + $03
SIOB_DAT	.EQU	SIOBASE + $02
#ENDIF	
;	
; CONDITIONALS THAT DETERMINE THE ENCODED VALUE OF THE BAUD RATE
;
#INCLUDE "siobaud.inc"	
;
SIO_PREINIT:
;
; SETUP THE DISPATCH TABLE ENTRIES
; NOTE: INTS WILL BE DISABLED WHEN PREINIT IS CALLED AND THEY MUST REMIAIN
; DISABLED.
;
	LD	B,SIO_CNT		; LOOP CONTROL
	LD	C,0			; PHYSICAL UNIT INDEX
	XOR	A			; ZERO TO ACCUM
	LD	(SIO_DEV),A		; CURRENT DEVICE NUMBER
SIO_PREINIT0:	
	PUSH	BC			; SAVE LOOP CONTROL
	LD	A,C			; PHYSICAL UNIT TO A
	RLCA				; MULTIPLY BY CFG TABLE ENTRY SIZE (8 BYTES)
	RLCA				; ...
	RLCA				; ... TO GET OFFSET INTO CFG TABLE
	LD	HL,SIO_CFG		; POINT TO START OF CFG TABLE
	CALL	ADDHLA			; HL := ENTRY ADDRESS
	PUSH	HL			; SAVE IT
	PUSH	HL			; COPY CFG DATA PTR
	POP	IY			; ... TO IY
	CALL	SIO_INITUNIT		; HAND OFF TO GENERIC INIT CODE
	POP	DE			; GET ENTRY ADDRESS BACK, BUT PUT IN DE
	POP	BC			; RESTORE LOOP CONTROL
;
	LD	A,(IY+1)		; GET THE SIO TYPE DETECTED
	OR	A			; SET FLAGS
	JR	Z,SIO_PREINIT2		; SKIP IT IF NOTHING FOUND
;	
	PUSH	BC			; SAVE LOOP CONTROL
	LD	BC,SIO_FNTBL		; BC := FUNCTION TABLE ADDRESS
	CALL	NZ,CIO_ADDENT		; ADD ENTRY IF SIO FOUND, BC:DE
	POP	BC			; RESTORE LOOP CONTROL
;
SIO_PREINIT2:	
	INC	C			; NEXT PHYSICAL UNIT
	DJNZ	SIO_PREINIT0		; LOOP UNTIL DONE
;
#IF (INTMODE == 1)
	; ADD IM1 INT CALL LIST ENTRY IF APPROPRIATE
	LD	A,(SIO_DEV)		; GET NEXT DEVICE NUM
	OR	A			; SET FLAGS
	JR	Z,SIO_PREINIT3		; IF ZERO, NO SIO DEVICES
	LD	HL,SIO_INT		; GET INT VECTOR
	CALL	HB_ADDIM1		; ADD TO IM1 CALL LIST
#ENDIF
;
#IF (INTMODE == 2)
	; SETUP SIO INTERRUPT VECTOR IN IVT
	LD	HL,INT_SIO
	LD	(HBX_IVT + IVT_SER0),HL
#ENDIF
;
SIO_PREINIT3:
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
; SIO INITIALIZATION ROUTINE
;
SIO_INITUNIT:
	CALL	SIO_DETECT		; DETERMINE SIO TYPE
	LD	(IY+1),A		; SAVE IN CONFIG TABLE
	OR	A			; SET FLAGS
	RET	Z			; ABORT IF NOTHING THERE

	; UPDATE WORKING SIO DEVICE NUM
	LD	HL,SIO_DEV		; POINT TO CURRENT UART DEVICE NUM
	LD	A,(HL)			; PUT IN ACCUM
	INC	(HL)			; INCREMENT IT (FOR NEXT LOOP)
	LD	(IY),A			; UPDATE UNIT NUM
	
	; SET DEFAULT CONFIG
	LD	DE,-1			; LEAVE CONFIG ALONE
	; CALL INITDEVX TO IMPLEMENT CONFIG, BUT NOTE THAT WE CALL
	; THE INITDEVX ENTRY POINT THAT DOES NOT ENABLE/DISABLE INTS!
	JP	SIO_INITDEVX		; IMPLEMENT IT AND RETURN
;
;
;
SIO_INIT:
	LD	B,SIO_CNT		; COUNT OF POSSIBLE SIO UNITS
	LD	C,0			; INDEX INTO SIO CONFIG TABLE
SIO_INIT1:
	PUSH	BC			; SAVE LOOP CONTROL
	
	LD	A,C			; PHYSICAL UNIT TO A
	RLCA				; MULTIPLY BY CFG TABLE ENTRY SIZE (8 BYTES)
	RLCA				; ...
	RLCA				; ... TO GET OFFSET INTO CFG TABLE
	LD	HL,SIO_CFG		; POINT TO START OF CFG TABLE
	CALL	ADDHLA			; HL := ENTRY ADDRESS
	PUSH	HL			; COPY CFG DATA PTR
	POP	IY			; ... TO IY
	
	LD	A,(IY+1)		; GET SIO TYPE
	OR	A			; SET FLAGS
	CALL	NZ,SIO_PRTCFG		; PRINT IF NOT ZERO
	
	POP	BC			; RESTORE LOOP CONTROL
	INC	C			; NEXT UNIT
	DJNZ	SIO_INIT1		; LOOP TILL DONE
;
	XOR	A			; SIGNAL SUCCESS
	RET				; DONE
;
; RECEIVE INTERRUPT HANDLER
;
#IF (INTMODE > 0)
;
SIO_INT:
SIOA_INT:
	; CHECK FOR RECEIVE PENDING ON CHANNEL A
	XOR	A			; A := 0
	OUT	(SIOA_CMD),A		; ADDRESS RD0
	IN	A,(SIOA_CMD)		; GET RD0
	AND	$01			; ISOLATE RECEIVE READY BIT
	JR	Z,SIOB_INT		; CHECK CHANNEL B
;
SIOA_INT00:
	; HANDLE CHANNEL A
	IN	A,(SIOA_DAT)		; READ PORT
	LD	E,A			; SAVE BYTE READ
	LD	A,(SIOA_CNT)		; GET CURRENT BUFFER USED COUNT
	CP	SIOA_BUFSZ		; COMPARE TO BUFFER SIZE
	;RET	Z			; BAIL OUT IF BUFFER FULL, RCV BYTE DISCARDED
	JR	Z,SIOA_INT2		; BAIL OUT IF BUFFER FULL, RCV BYTE DISCARDED
	INC	A			; INCREMENT THE COUNT
	LD	(SIOA_CNT),A		; AND SAVE IT
	CP	SIOA_BUFSZ / 2		; BUFFER GETTING FULL?
	JR	NZ,SIOA_INT0		; IF NOT, BYPASS CLEARING RTS
	LD	A,5			; RTS IS IN WR5
	OUT	(SIOA_CMD),A		; ADDRESS WR5
	LD	A,$E8			; VALUE TO CLEAR RTS
	OUT	(SIOA_CMD),A		; DO IT
SIOA_INT0:
	LD	HL,(SIOA_HD)		; GET HEAD POINTER
	LD	A,L			; GET LOW BYTE
	CP	SIOA_BUFEND & $FF	; PAST END?
	JR	NZ,SIOA_INT1		; IF NOT, BYPASS POINTER RESET
	LD	HL,SIOA_BUF		; ... OTHERWISE, RESET TO START OF BUFFER
SIOA_INT1:
	LD	A,E			; RECOVER BYTE READ
	LD	(HL),A			; SAVE RECEIVED BYTE TO HEAD POSITION
	INC	HL			; INCREMENT HEAD POINTER
	LD	(SIOA_HD),HL		; SAVE IT
;
SIOA_INT2:
	; CHECK FOR MORE PENDING...
	XOR	A			; A := 0
	OUT	(SIOA_CMD),A		; ADDRESS RD0
	IN	A,(SIOA_CMD)		; GET RD0
	RRA				; READY BIT TO CF
	JR	C,SIOA_INT00		; IF SET, DO SOME MORE
	OR	$FF			; NZ SET TO INDICATE INT HANDLED
	RET				; AND RETURN
;
SIOB_INT:
	; CHECK FOR RECEIVE PENDING ON CHANNEL B
	XOR	A			; A := 0
	OUT	(SIOB_CMD),A		; ADDRESS RD0
	IN	A,(SIOB_CMD)		; GET RD0
	AND	$01			; ISOLATE RECEIVE READY BIT
	RET	Z			; IF NOT, RETURN WITH Z SET
;
SIOB_INT00:
	; HANDLE CHANNEL B
	IN	A,(SIOB_DAT)		; READ PORT
	LD	E,A			; SAVE BYTE READ
	LD	A,(SIOB_CNT)		; GET CURRENT BUFFER USED COUNT
	CP	SIOB_BUFSZ		; COMPARE TO BUFFER SIZE
	;RET	Z			; BAIL OUT IF BUFFER FULL, RCV BYTE DISCARDED
	JR	Z,SIOB_INT2		; BAIL OUT IF BUFFER FULL, RCV BYTE DISCARDED
	INC	A			; INCREMENT THE COUNT
	LD	(SIOB_CNT),A		; AND SAVE IT
	CP	SIOB_BUFSZ / 2		; BUFFER GETTING FULL?
	JR	NZ,SIOB_INT0		; IF NOT, BYPASS CLEARING RTS
	LD	A,5			; RTS IS IN WR5
	OUT	(SIOB_CMD),A		; ADDRESS WR5
	LD	A,$E8			; VALUE TO CLEAR RTS
	OUT	(SIOB_CMD),A		; DO IT
SIOB_INT0:
	LD	HL,(SIOB_HD)		; GET HEAD POINTER
	LD	A,L			; GET LOW BYTE
	CP	SIOB_BUFEND & $FF	; PAST END?
	JR	NZ,SIOB_INT1		; IF NOT, BYPASS POINTER RESET
	LD	HL,SIOB_BUF		; ... OTHERWISE, RESET TO START OF BUFFER
SIOB_INT1:
	LD	A,E			; RECOVER BYTE READ
	LD	(HL),A			; SAVE RECEIVED BYTE TO HEAD POSITION
	INC	HL			; INCREMENT HEAD POINTER
	LD	(SIOB_HD),HL		; SAVE IT
;
SIOB_INT2:
	; CHECK FOR MORE PENDING...
	XOR	A			; A := 0
	OUT	(SIOB_CMD),A		; ADDRESS RD0
	IN	A,(SIOB_CMD)		; GET RD0
	RRA				; READY BIT TO CF
	JR	C,SIOB_INT00		; IF SET, DO SOME MORE
	OR	$FF			; NZ SET TO INDICATE INT HANDLED
	RET				; AND RETURN
;
#ENDIF
;
; DRIVER FUNCTION TABLE
;
SIO_FNTBL:
	.DW	SIO_IN
	.DW	SIO_OUT
	.DW	SIO_IST
	.DW	SIO_OST
	.DW	SIO_INITDEV
	.DW	SIO_QUERY
	.DW	SIO_DEVICE
#IF (($ - SIO_FNTBL) != (CIO_FNCNT * 2))
	.ECHO	"*** INVALID SIO FUNCTION TABLE ***\n"
#ENDIF
;
;
;
#IF (INTMODE == 0)
;
SIO_IN:
	CALL	SIO_IST			; CHAR WAITING?
	JR	Z,SIO_IN		; LOOP IF NOT
	LD	C,(IY+3)		; C := SIO CMD PORT
#IF (SIOMODE == SIOMODE_RC)
	INC	C			; BUMP TO DATA PORT
#ENDIF
#IF ((SIOMODE == SIOMODE_SMB) | (SIOMODE == SIOMODE_ZP))
	DEC	C			; DECREMENT CMD PORT TWICE TO GET DATA PORT
	DEC	C
#ENDIF
#IF (SIOMODE == SIOMODE_EZZ80)
	DEC	C			; DECREMENT CMD PORT TO GET DATA PORT
#ENDIF
	IN	E,(C)			; GET CHAR
	XOR	A			; SIGNAL SUCCESS
	RET
;
#ELSE
;
SIO_IN:
	LD	A,(IY+2)		; GET CHANNEL
	OR	A			; SET FLAGS
	JR	Z,SIOA_IN		; HANDLE CHANNEL A
	DEC	A			; TEST FOR NEXT DEVICE
	JR	Z,SIOB_IN		; HANDLE CHANNEL B
	CALL 	PANIC			; ELSE FATAL ERROR
	RET				; ... AND RETURN
;
SIOA_IN:
	CALL	SIOA_IST		; RECEIVED CHAR READY?
	JR	Z,SIOA_IN		; LOOP TILL WE HAVE SOMETHING IN BUFFER
	HB_DI				; AVOID COLLISION WITH INT HANDLER
	LD	A,(SIOA_CNT)		; GET COUNT
	DEC	A			; DECREMENT COUNT
	LD	(SIOA_CNT),A		; SAVE SAVE IT
	CP	5			; BUFFER LOW THRESHOLD
	JR	NZ,SIOA_IN0		; IF NOT, BYPASS SETTING RTS
	LD	A,5			; RTS IS IN WR5
	OUT	(SIOA_CMD),A		; ADDRESS WR5
	LD	A,$EA			; VALUE TO SET RTS
	OUT	(SIOA_CMD),A		; DO IT
SIOA_IN0:
	LD	HL,(SIOA_TL)		; GET BUFFER TAIL POINTER
	LD	E,(HL)			; GET BYTE
	INC	HL			; BUMP TAIL POINTER
	LD	A,L			; GET LOW BYTE
	CP	SIOA_BUFEND & $FF	; PAST END?
	JR	NZ,SIOA_IN1		; IF NOT, BYPASS POINTER RESET
	LD	HL,SIOA_BUF		; ... OTHERWISE, RESET TO START OF BUFFER
SIOA_IN1:
	LD	(SIOA_TL),HL		; SAVE UPDATED TAIL POINTER
	HB_EI				; INTERRUPTS OK AGAIN
	XOR	A			; SIGNAL SUCCESS
	RET				; AND DONE
;
SIOB_IN:
	CALL	SIOB_IST		; RECEIVED CHAR READY?
	JR	Z,SIOB_IN		; LOOP TILL WE HAVE SOMETHING IN BUFFER
	HB_DI				; AVOID COLLISION WITH INT HANDLER
	LD	A,(SIOB_CNT)		; GET COUNT
	DEC	A			; DECREMENT COUNT
	LD	(SIOB_CNT),A		; SAVE SAVE IT
	CP	5			; BUFFER LOW THRESHOLD
	JR	NZ,SIOB_IN0		; IF NOT, BYPASS SETTING RTS
	LD	A,5			; RTS IS IN WR5
	OUT	(SIOB_CMD),A		; ADDRESS WR5
	LD	A,$EA			; VALUE TO SET RTS
	OUT	(SIOB_CMD),A		; DO IT
SIOB_IN0:
	LD	HL,(SIOB_TL)		; GET BUFFER TAIL POINTER
	LD	E,(HL)			; GET BYTE
	INC	HL			; BUMP TAIL POINTER
	LD	A,L			; GET LOW BYTE
	CP	SIOB_BUFEND & $FF	; PAST END?
	JR	NZ,SIOB_IN1		; IF NOT, BYPASS POINTER RESET
	LD	HL,SIOB_BUF		; ... OTHERWISE, RESET TO START OF BUFFER
SIOB_IN1:
	LD	(SIOB_TL),HL		; SAVE UPDATED TAIL POINTER
	HB_EI				; INTERRUPTS OK AGAIN
	XOR	A			; SIGNAL SUCCESS
	RET				; AND DONE
;
#ENDIF
;
;
;
SIO_OUT:
	CALL	SIO_OST			; READY FOR CHAR?
	JR	Z,SIO_OUT		; LOOP IF NOT
	LD	C,(IY+3)		; C := SIO CMD PORT
#IF (SIOMODE == SIOMODE_RC)
	INC	C			; BUMP TO DATA PORT
#ENDIF
#IF ((SIOMODE == SIOMODE_SMB) | (SIOMODE == SIOMODE_ZP))
	DEC	C			; DECREMENT CMD PORT TWICE TO GET DATA PORT
	DEC	C
#ENDIF
#IF (SIOMODE == SIOMODE_EZZ80)
	DEC	C			; DECREMENT CMD PORT TO GET DATA PORT
#ENDIF
	OUT	(C),E			; SEND CHAR FROM E
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
#IF (INTMODE == 0)
;
SIO_IST:
	LD	C,(IY+3)		; CMD PORT
	XOR	A			; WR0
	OUT	(C),A			; DO IT
	IN	A,(C)			; GET STATUS
	AND	$01			; ISOLATE BIT 0 (RX READY)
	JP	Z,CIO_IDLE		; NOT READY, RETURN VIA IDLE PROCESSING
	XOR	A			; ZERO ACCUM
	INC	A			; ASCCUM := 1 TO SIGNAL 1 CHAR WAITING
	RET				; DONE
;
#ELSE
;
SIO_IST:
	LD	A,(IY+2)		; GET CHANNEL
	OR	A			; SET FLAGS
	JR	Z,SIOA_IST		; HANDLE CHANNEL A
	DEC	A			; TEST FOR NEXT DEVICE
	JR	Z,SIOB_IST		; HANDLE CHANNEL B
	CALL 	PANIC			; ELSE FATAL ERROR
	RET				; ... AND RETURN
;
SIOA_IST:
	LD	A,(SIOA_CNT)		; GET BUFFER UTILIZATION COUNT
	OR	A			; SET FLAGS
	JP	Z,CIO_IDLE		; NOT READY, RETURN VIA IDLE PROCESSING
	RET				; AND DONE
;
SIOB_IST:
	LD	A,(SIOB_CNT)		; GET BUFFER UTILIZATION COUNT
	OR	A			; SET FLAGS
	JP	Z,CIO_IDLE		; NOT READY, RETURN VIA IDLE PROCESSING
	RET				; DONE
;
#ENDIF
;
;
;
SIO_OST:
	LD	C,(IY+3)		; CMD PORT
	XOR	A			; WR0
	OUT	(C),A			; DO IT
	IN	A,(C)			; GET STATUS
	AND	$04			; ISOLATE BIT 2 (TX EMPTY)
	JP	Z,CIO_IDLE		; NOT READY, RETURN VIA IDLE PROCESSING
	XOR	A			; ZERO ACCUM
	INC	A			; ACCUM := 1 TO SIGNAL 1 BUFFER POSITION
	RET				; DONE
;
; AT INITIALIZATION THE SETUP PARAMETER WORD IS TRANSLATED TO THE FORMAT 
; REQUIRED BY THE SIO AND STORED IN A PORT/REGISTER INITIALIZATION TABLE, 
; WHICH IS THEN LOADED INTO THE SIO.
;
; RTS, DTR AND XON SETTING IS NOT CURRENTLY SUPPORTED.
; MARK & SPACE PARITY AND 1.5 STOP BITS IS NOT SUPPORTED BY THE SIO.
; INITIALIZATION WILL NOT BE COMPLETED IF AN INVALID SETTING IS DETECTED.
;
; NOTE THAT THERE ARE TWO ENTRY POINTS.  INITDEV WILL DISABLE/ENABLE INTS
; AND INITDEVX WILL NOT.  THIS IS DONE SO THAT THE PREINIT ROUTINE ABOVE
; CAN AVOID ENABLING/DISABLING INTS.
;
SIO_INITDEV:
	HB_DI				; DISABLE INTS
	CALL	SIO_INITDEVX		; DO THE WORK
	HB_EI				; INTS BACK ON
	RET				; DONE
;
SIO_INITDEVX:
;
; THIS ENTRY POINT BYPASSES DISABLING/ENABLING INTS WHICH IS REQUIRED BY
; PREINIT ABOVE.  PREINIT IS NOT ALLOWED TO ENABLE INTS!
;
	; TEST FOR -1 WHICH MEANS USE CURRENT CONFIG (JUST REINIT)
	LD	A,D			; TEST DE FOR
	AND	E			; ... VALUE OF -1
	INC	A			; ... SO Z SET IF -1
	JR	NZ,SIO_INITDEV1	; IF DE == -1, REINIT CURRENT CONFIG
;
	; LOAD EXISTING CONFIG TO REINIT
	LD	E,(IY+4)		; LOW BYTE
	LD	D,(IY+5)		; HIGH BYTE	
;
SIO_INITDEV1:
	PUSH	DE			; SAVE CONFIG

	LD	A,D			; GET CONFIG MSB
	AND	$1F			; ISOLATE ENCODED BAUD RATE

#IF (SIODEBUG)
	PUSH	AF
	PRTS(" ENCODE[$")
	CALL	PRTHEXBYTE
	PRTC(']')
	POP	AF
#ENDIF
;
; ONLY FOUR BAUD RATES ARE POSSIBLE WITH A FIXED CLOCK.
; THESE ARE PREDETERMINED BY HARDWARE SETTINGS AND MATCHING
; CONFIGURATION SETTINGS. WE PRECALCULATED THE FOUR 
; POSSIBLE ENCODED VALUES.
;
	CP	SIOBAUD1		; We set the divider and the lower bit (d2) of the stop bits
	LD	D,$04			; /1 N,8,1
	JR	Z,BROK	
	CP	SIOBAUD2	
	LD	D,$44			; /16 N,8,1
	JR	Z,BROK	
	CP	SIOBAUD3	
	LD	D,$84			; /32 N,8,1
	JR	Z,BROK	
	CP	SIOBAUD4	
	LD	D,$C4			; /64 N,8,1
	JR	Z,BROK			
	
#IF (SIODEBUG)
	PUSH	AF
	PRTS(" BR FAIL[$")	
	CALL PRTHEXBYTE
	PRTC(']')
	POP	AF
#ENDIF
;
EXITINIT:
	POP	DE
	RET				; NZ status here indicating fail / invalid baud rate.
	
BROK:
	LD	A,E
	AND	$E0
	JR	NZ,EXITINIT		; NZ status here indicates dtr, xon, parity mark or space so return

	LD	A,E			;  set stop bit (d3) and add divider
	AND	$04
	RLA
	OR	D			; carry gets reset here
	LD	D,A
	
	LD	A,E			; get the parity bits
	SRL	A			; move them to bottom two bits
	SRL	A			; we know top bits are zero from previous test
	SRL	A			; add stop bits
	OR	D 			; carry = 0
;	
; SET DIVIDER, STOP AND PARITY WR4
;	
	LD	BC,SIO_INITVALS+3
	LD	(BC),A
	
#IF (SIODEBUG)
	PUSH	AF
	PRTS(" WR4[$")
	CALL	PRTHEXBYTE
	PRTC(']')
	POP	AF
#ENDIF

	LD	A,E			; 112233445566d1d0 CC
	RRA				; CC112233445566d1 d0
	RRA				; d0CC112233445566 d1
	RRA 				; d1d0CC1122334455 66
	LD	D,A	
	RRA				; 66d1d0CC11223344 55
	AND	$60			; 0011110000000000 00
	OR	$8a
;	
; SET TRANSMIT DATA BITS WR5	
;
	LD	BC,SIO_INITVALS+11
	LD	(BC),A	

#IF (SIODEBUG)
	PUSH	AF
	PRTS(" WR5[$")
	CALL	PRTHEXBYTE
	PRTC(']')
	POP	AF
#ENDIF	
;
; SET RECEIVE DATA BITS WR3 
;	
	LD	A,D
	AND	$C0
	OR	$01
	
	LD	BC,SIO_INITVALS+9
	LD	(BC),A	

#IF (SIODEBUG)
	PUSH	AF
	PRTS(" WR3[$")
	CALL	PRTHEXBYTE
	PRTC(']')
	POP	AF
#ENDIF	
	
	POP	DE			; RESTORE CONFIG

	LD	(IY+4),E		; SAVE LOW WORD
	LD	(IY+5),D		; SAVE HI WORD
;
	; PROGRAM THE SIO CHIP CHANNEL
	LD	C,(IY+3)		; COMMAND PORT
	LD	HL,SIO_INITVALS		; POINT TO INIT VALUES
	LD	B,SIO_INITLEN		; COUNT OF BYTES TO WRITE
	OTIR				; WRITE ALL VALUES
;
#IF (INTMODE > 0)
;
	; RESET THE RECEIVE BUFFER
	LD	E,(IY+6)
	LD	D,(IY+7)		; DE := _CNT
	XOR	A			; A := 0
	LD	(DE),A			; _CNT = 0
	INC	DE			; DE := ADR OF _HD
	PUSH	DE			; SAVE IT
	INC	DE
	INC	DE
	INC	DE
	INC	DE			; DE := ADR OF _BUF
	POP	HL			; HL := ADR OF _HD
	LD	(HL),E
	INC	HL
	LD	(HL),D			; _HD := _BUF
	INC	HL
	LD	(HL),E
	INC	HL
	LD	(HL),D			; _TL := _BUF
;
#ENDIF
;
	XOR	A			; SIGNAL SUCCESS
	RET				; RETURN
;
;
SIO_INITVALS:
	.DB	$00, $18		; WR0: CHANNEL RESET
	.DB	$04, $00		; WR4: CLK BAUD PARITY STOP BIT
#IF (INTMODE == 0)
	.DB	$01, $00		; WR1: NO INTERRUPTS
#ELSE
	.DB	$01, $18		; WR1: INTERRUPT ON ALL RECEIVE CHARACTERS
#ENDIF
	.DB	$02, IVT_SER0		; WR2: INTERRUPT VECTOR OFFSET
	.DB	$03, $C1		; WR3: 8 BIT RCV, RX ENABLE
	.DB	$05, $EA		; WR5: DTR, 8 BITS SEND,  TX ENABLE, RTS 1 11 0 1 0 1 0 (1=DTR,11=8bits,0=sendbreak,1=TxEnable,0=sdlc,1=RTS,0=txcrc)
SIO_INITLEN	.EQU	$ - SIO_INITVALS
;
;
;
SIO_QUERY:
	LD	E,(IY+4)		; FIRST CONFIG BYTE TO E
	LD	D,(IY+5)		; SECOND CONFIG BYTE TO D
	XOR	A			; SIGNAL SUCCESS
	RET				; DONE
;
;
;
SIO_DEVICE:
	LD	D,CIODEV_SIO		; D := DEVICE TYPE
	LD	E,(IY)			; E := PHYSICAL UNIT
	LD	C,$00			; C := DEVICE TYPE, 0x00 IS RS-232
	XOR	A			; SIGNAL SUCCESS
	RET
;
; SIO DETECTION ROUTINE
;
SIO_DETECT:
	LD	C,(IY+3)		; COMMAND PORT
	XOR	A	
	OUT	(C),A			; ACCESS RD0
	IN	A,(C)			; GET RD0 VALUE
	LD	B,A			; SAVE IT
	LD	A,1	
	OUT	(C),A			; ACCESS RD1
	IN	A,(C)			; GET RD1 VALUE
	CP	B			; COMPARE
	LD	A,SIO_NONE		; ASSUME NOTHING THERE
	RET	Z			; RD0=RD1 MEANS NOTHING THERE
	LD	A,SIO_SIO		; GUESS WE HAVE A VALID SIO HERE
	RET				; DONE
;
;
;
SIO_PRTCFG:
	; ANNOUNCE PORT
	CALL	NEWLINE			; FORMATTING
	PRTS("SIO$")			; FORMATTING
	LD	A,(IY)			; DEVICE NUM
	CALL	PRTDECB			; PRINT DEVICE NUM
	PRTS(": IO=0x$")		; FORMATTING
	LD	A,(IY+3)		; GET BASE PORT
	CALL	PRTHEXBYTE		; PRINT BASE PORT

	; PRINT THE SIO TYPE
	CALL	PC_SPACE		; FORMATTING
	LD	A,(IY+1)		; GET SIO TYPE BYTE
	RLCA				; MAKE IT A WORD OFFSET
	LD	HL,SIO_TYPE_MAP		; POINT HL TO TYPE MAP TABLE
	CALL	ADDHLA			; HL := ENTRY
	LD	E,(HL)			; DEREFERENCE
	INC	HL			; ...
	LD	D,(HL)			; ... TO GET STRING POINTER
	CALL	WRITESTR		; PRINT IT
;
	; ALL DONE IF NO SIO WAS DETECTED
	LD	A,(IY+1)		; GET SIO TYPE BYTE
	OR	A			; SET FLAGS
	RET	Z			; IF ZERO, NOT PRESENT
;
	PRTS(" MODE=$")			; FORMATTING
	LD	E,(IY+4)		; LOAD CONFIG
	LD	D,(IY+5)		; ... WORD TO DE
	CALL	PS_PRTSC0		; PRINT CONFIG
;
	XOR	A
	RET
;
;
;
SIO_TYPE_MAP:
		.DW	SIO_STR_NONE
		.DW	SIO_STR_SIO

SIO_STR_NONE	.DB	"<NOT PRESENT>$"
SIO_STR_SIO	.DB	"SIO$"
;
; WORKING VARIABLES
;
SIO_DEV		.DB	0		; DEVICE NUM USED DURING INIT
;
#IF (INTMODE == 0)
;
SIOA_RCVBUF	.EQU	0
SIOB_RCVBUF	.EQU	0
;
#ELSE
;
; CHANNEL A RECEIVE BUFFER
SIOA_RCVBUF:
SIOA_CNT	.DB	0		; CHARACTERS IN RING BUFFER
SIOA_HD		.DW	SIOA_BUF	; BUFFER HEAD POINTER
SIOA_TL		.DW	SIOA_BUF	; BUFFER TAIL POINTER
SIOA_BUF	.FILL	32,0		; RECEIVE RING BUFFER
SIOA_BUFEND	.EQU	$		; END OF BUFFER
SIOA_BUFSZ	.EQU	$ - SIOA_BUF	; SIZE OF RING BUFFER
;
; CHANNEL B RECEIVE BUFFER
SIOB_RCVBUF:
SIOB_CNT	.DB	0		; CHARACTERS IN RING BUFFER
SIOB_HD		.DW	SIOB_BUF	; BUFFER HEAD POINTER
SIOB_TL		.DW	SIOB_BUF	; BUFFER TAIL POINTER
SIOB_BUF	.FILL	32,0		; RECEIVE RING BUFFER
SIOB_BUFEND	.EQU	$		; END OF BUFFER
SIOB_BUFSZ	.EQU	$ - SIOB_BUF	; SIZE OF RING BUFFER
;
#ENDIF
;
; SIO PORT TABLE
;
SIO_CFG:
	; SIO CHANNEL A
	.DB	0			; DEVICE NUMBER (SET DURING INIT)
	.DB	0			; SIO TYPE (SET DURING INIT)
	.DB	0			; SIO CHANNEL (A)
	.DB	SIOA_CMD		; BASE PORT (CMD PORT)
	.DW	DEFSIOACFG		; LINE CONFIGURATION
	.DW	SIOA_RCVBUF		; POINTER TO RCV BUFFER STRUCT
;
	; SIO CHANNEL B
	.DB	0			; DEVICE NUMBER (SET DURING INIT)
	.DB	0			; SIO TYPE (SET DURING INIT)
	.DB	1			; SIO CHANNEL (B)
	.DB	SIOB_CMD		; BASE PORT (CMD PORT)
	.DW	DEFSIOBCFG		; LINE CONFIGURATION
	.DW	SIOB_RCVBUF		; POINTER TO RCV BUFFER STRUCT
;
SIO_CNT	.EQU	($ - SIO_CFG) / 8
