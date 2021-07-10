;
;==================================================================================================
;   ROMWBW 2.X CONFIGURATION DEFAULTS FOR EASY Z80
;==================================================================================================
;
; THIS FILE CONTAINS THE FULL SET OF DEFAULT CONFIGURATION SETTINGS FOR THE PLATFORM
; INDICATED ABOVE. THIS FILE SHOULD *NOT* NORMALLY BE CHANGED.	INSTEAD, YOU SHOULD
; OVERRIDE ANY SETTINGS YOU WANT USING A CONFIGURATION FILE IN THE CONFIG DIRECTORY
; UNDER THIS DIRECTORY.
;
; THIS FILE CAN BE CONSIDERED A REFERENCE THAT LISTS ALL POSSIBLE CONFIGURATION SETTINGS
; FOR THE PLATFORM.
;
#DEFINE PLATFORM_NAME "EASYZ80"
;
PLATFORM	.EQU	PLT_EZZ80	; PLT_[SBC|ZETA|ZETA2|N8|MK4|UNA|RCZ80|RCZ180|EZZ80|SCZ180|DYNO|RCZ280|MBC]
CPUFAM		.EQU	CPU_Z80		; CPU FAMILY: CPU_[Z80|Z180|Z280]
BIOS		.EQU	BIOS_WBW	; HARDWARE BIOS: BIOS_[WBW|UNA]
BATCOND		.EQU	FALSE		; ENABLE LOW BATTERY WARNING MESSAGE
HBIOS_MUTEX	.EQU	FALSE		; ENABLE REENTRANT CALLS TO HBIOS (ADDS OVERHEAD)
USELZSA2	.EQU	TRUE		; ENABLE FONT COMPRESSION
TICKFREQ	.EQU	50		; DESIRED PERIODIC TIMER INTERRUPT FREQUENCY (HZ)
;
BOOT_TIMEOUT	.EQU	-1		; AUTO BOOT TIMEOUT IN SECONDS, -1 TO DISABLE, 0 FOR IMMEDIATE
;
CPUOSC		.EQU	10000000	; CPU OSC FREQ IN MHZ
INTMODE		.EQU	2		; INTERRUPTS: 0=NONE, 1=MODE 1, 2=MODE 2, 3=MODE 3 (Z280)
DEFSERCFG	.EQU	SER_115200_8N1	; DEFAULT SERIAL LINE CONFIG (SEE STD.ASM)
;
RAMSIZE		.EQU	512		; SIZE OF RAM IN KB (MUST MATCH YOUR HARDWARE!!!)
RAM_RESERVE	.EQU	0		; RESERVE FIRST N KB OF RAM (USUALLY 0)
ROM_RESERVE	.EQU	0		; RESERVE FIRST N KB OR ROM (USUALLY 0)
MEMMGR		.EQU	MM_Z2		; MEMORY MANAGER: MM_[SBC|Z2|N8|Z180|Z280|MBC]
MPGSEL_0	.EQU	$78		; Z2 MEM MGR BANK 0 PAGE SELECT REG (WRITE ONLY)
MPGSEL_1	.EQU	$79		; Z2 MEM MGR BANK 1 PAGE SELECT REG (WRITE ONLY)
MPGSEL_2	.EQU	$7A		; Z2 MEM MGR BANK 2 PAGE SELECT REG (WRITE ONLY)
MPGSEL_3	.EQU	$7B		; Z2 MEM MGR BANK 3 PAGE SELECT REG (WRITE ONLY)
MPGENA		.EQU	$7C		; Z2 MEM MGR PAGING ENABLE REGISTER (BIT 0, WRITE ONLY)
;
RTCIO		.EQU	$C0		; RTC LATCH REGISTER ADR
;
KIOENABLE	.EQU	FALSE		; ENABLE ZILOG KIO SUPPORT
KIOBASE		.EQU	$80		; KIO BASE I/O ADDRESS
;
CTCENABLE	.EQU	TRUE		; ENABLE ZILOG CTC SUPPORT
CTCDEBUG	.EQU	FALSE		; ENABLE CTC DRIVER DEBUG OUTPUT
CTCBASE		.EQU	$88		; CTC BASE I/O ADDRESS
CTCTIMER	.EQU	TRUE		; ENABLE CTC PERIODIC TIMER
CTCMODE		.EQU	CTCMODE_CTR	; CTC MODE: CTCMODE_[NONE|CTR|TIM16|TIM256]
CTCPRE		.EQU	256		; PRESCALE CONSTANT (1-256)
CTCPRECH	.EQU	2		; PRESCALE CHANNEL (0-3)
CTCTIMCH	.EQU	3		; TIMER CHANNEL (0-3)
CTCOSC		.EQU	921600		; CTC CLOCK FREQUENCY
;
EIPCENABLE	.EQU	FALSE		; EIPC: ENABLE Z80 EIPC (Z84C15) INITIALIZATION
;
SKZENABLE	.EQU	FALSE		; ENABLE SERGEY'S Z80-512K FEATURES
;
WDOGMODE	.EQU	WDOG_EZZ80	; WATCHDOG MODE: WDOG_[NONE|EZZ80|SKZ]
WDOGIO		.EQU	$6F		; WATCHDOG REGISTER ADR
;
DIAGENABLE	.EQU	FALSE		; ENABLES OUTPUT TO 8 BIT LED DIAGNOSTIC PORT
DIAGPORT	.EQU	$00		; DIAGNOSTIC PORT ADDRESS
DIAGDISKIO	.EQU	TRUE		; ENABLES DISK I/O ACTIVITY ON DIAGNOSTIC LEDS
;
LEDENABLE	.EQU	FALSE		; ENABLES STATUS LED (SINGLE LED)
LEDMODE		.EQU	LEDMODE_STD	; LEDMODE_[STD|RTC]
LEDPORT		.EQU	$0E		; STATUS LED PORT ADDRESS
LEDDISKIO	.EQU	TRUE		; ENABLES DISK I/O ACTIVITY ON STATUS LED
;
DSKYENABLE	.EQU	FALSE		; ENABLES DSKY (DO NOT COMBINE WITH PPIDE)
;
BOOTCON		.EQU	0		; BOOT CONSOLE DEVICE
CRTACT		.EQU	FALSE		; ACTIVATE CRT (VDU,CVDU,PROPIO,ETC) AT STARTUP
VDAEMU		.EQU	EMUTYP_ANSI	; VDA EMULATION: EMUTYP_[TTY|ANSI]
ANSITRACE	.EQU	1		; ANSI DRIVER TRACE LEVEL (0=NO,1=ERRORS,2=ALL)
MKYENABLE	.EQU	FALSE		; MSX 5255 PPI KEYBOARD COMPATIBLE DRIVER (REQUIRES TMS VDA DRIVER)
MKYKBLOUT	.EQU	KBD_US		; KBD KEYBOARD LANGUAGE: KBD_[US|DE]
;
DSRTCENABLE	.EQU	TRUE		; DSRTC: ENABLE DS-1302 CLOCK DRIVER (DSRTC.ASM)
DSRTCMODE	.EQU	DSRTCMODE_STD	; DSRTC: OPERATING MODE: DSRTC_[STD|MFPIC]
DSRTCCHG	.EQU	FALSE		; DSRTC: FORCE BATTERY CHARGE ON (USE WITH CAUTION!!!)
;
BQRTCENABLE	.EQU	FALSE		; BQRTC: ENABLE BQ4845 CLOCK DRIVER (BQRTC.ASM)
BQRTC_BASE	.EQU	$50		; BQRTC: I/O BASE ADDRESS
;
INTRTCENABLE	.EQU	FALSE		; ENABLE PERIODIC INTERRUPT CLOCK DRIVER (INTRTC.ASM)
;
RP5RTCENABLE	.EQU	FALSE		; RP5C01 RTC BASED CLOCK (RP5RTC.ASM)
;
HTIMENABLE	.EQU	FALSE		; ENABLE SIMH TIMER SUPPORT
SIMRTCENABLE	.EQU	FALSE		; ENABLE SIMH CLOCK DRIVER (SIMRTC.ASM)
;
DS7RTCENABLE	.EQU	FALSE		; DS7RTC: ENABLE DS-1307 I2C CLOCK DRIVER (DS7RTC.ASM)
DS7RTCMODE	.EQU	DS7RTCMODE_PCF	; DS7RTC: OPERATING MODE: DS7RTC_[PCF]
;
DUARTENABLE	.EQU	FALSE		; DUART: ENABLE 2681/2692 SERIAL DRIVER (DUART.ASM)
DUARTCNT	.EQU	2		; DUART: NUMBER OF CHIPS TO DETECT (1-2)
DUART0BASE	.EQU	$A0		; DUART 0: BASE ADDRESS OF CHIP
DUART0ACFG	.EQU	DEFSERCFG	; DUART 0A: SERIAL LINE CONFIG
DUART0BCFG	.EQU	DEFSERCFG	; DUART 0B: SERIAL LINE CONFIG
DUART1BASE	.EQU	$40		; DUART 1: BASE ADDRESS OF CHIP
DUART1ACFG	.EQU	DEFSERCFG	; DUART 1A: SERIAL LINE CONFIG
DUART1BCFG	.EQU	DEFSERCFG	; DUART 1B: SERIAL LINE CONFIG
;
UARTENABLE	.EQU	TRUE		; UART: ENABLE 8250/16550-LIKE SERIAL DRIVER (UART.ASM)
UARTOSC		.EQU	1843200		; UART: OSC FREQUENCY IN MHZ
UARTCFG		.EQU	DEFSERCFG | SER_RTS	; UART: LINE CONFIG FOR UART PORTS
UARTSBC		.EQU	FALSE		; UART: AUTO-DETECT SBC/ZETA ONBOARD UART
UARTCAS		.EQU	FALSE		; UART: AUTO-DETECT ECB CASSETTE UART
UARTMFP		.EQU	FALSE		; UART: AUTO-DETECT MF/PIC UART
UART4		.EQU	FALSE		; UART: AUTO-DETECT 4UART UART
UARTRC		.EQU	TRUE		; UART: AUTO-DETECT RC UART
;
ASCIENABLE	.EQU	FALSE		; ASCI: ENABLE Z180 ASCI SERIAL DRIVER (ASCI.ASM)
;
Z2UENABLE	.EQU	FALSE		; Z2U: ENABLE Z280 UART SERIAL DRIVER (Z2U.ASM)
;
ACIAENABLE	.EQU	FALSE		; ACIA: ENABLE MOTOROLA 6850 ACIA DRIVER (ACIA.ASM)
;
SIOENABLE	.EQU	TRUE		; SIO: ENABLE ZILOG SIO SERIAL DRIVER (SIO.ASM)
SIODEBUG	.EQU	FALSE		; SIO: ENABLE DEBUG OUTPUT
SIOBOOT		.EQU	0		; SIO: REBOOT ON RCV CHAR (0=DISABLED)
SIOCNT		.EQU	2		; SIO: NUMBER OF CHIPS TO DETECT (1-2), 2 CHANNELS PER CHIP
SIO0MODE	.EQU	SIOMODE_STD	; SIO 0: CHIP TYPE: SIOMODE_[STD|RC|SMB|ZP]
SIO0BASE	.EQU	$80		; SIO 0: REGISTERS BASE ADR
SIO0ACLK	.EQU	1843200		; SIO 0A: OSC FREQ IN HZ, ZP=2457600/4915200, RC/SMB=7372800
SIO0ACFG	.EQU	DEFSERCFG	; SIO 0A: SERIAL LINE CONFIG
SIO0ACTCC	.EQU	-1		; SIO 0A: CTC CHANNEL 0=A, 1=B, 2=C, 3=D, -1 FOR NONE
SIO0BCLK	.EQU	1843200		; SIO 0B: OSC FREQ IN HZ, ZP=2457600/4915200, RC/SMB=7372800
SIO0BCFG	.EQU	DEFSERCFG	; SIO 0B: SERIAL LINE CONFIG
SIO0BCTCC	.EQU	-1		; SIO 0B: CTC CHANNEL 0=A, 1=B, 2=C, 3=D, -1 FOR NONE
SIO1MODE	.EQU	SIOMODE_RC	; SIO 1: CHIP TYPE: SIOMODE_[STD|RC|SMB|ZP]
SIO1BASE	.EQU	$84		; SIO 1: REGISTERS BASE ADR
SIO1ACLK	.EQU	7372800		; SIO 1A: OSC FREQ IN HZ, ZP=2457600/4915200, RC/SMB=7372800
SIO1ACFG	.EQU	DEFSERCFG	; SIO 1A: SERIAL LINE CONFIG
SIO1ACTCC	.EQU	-1		; SIO 1A: CTC CHANNEL 0=A, 1=B, 2=C, 3=D, -1 FOR NONE
SIO1BCLK	.EQU	7372800		; SIO 1B: OSC FREQ IN HZ, ZP=2457600/4915200, RC/SMB=7372800
SIO1BCFG	.EQU	DEFSERCFG	; SIO 1B: SERIAL LINE CONFIG
SIO1BCTCC	.EQU	-1		; SIO 1B: CTC CHANNEL 0=A, 1=B, 2=C, 3=D, -1 FOR NONE
;
XIOCFG		.EQU	DEFSERCFG	; XIO: SERIAL LINE CONFIG
;
VDUENABLE	.EQU	FALSE		; VDU: ENABLE VDU VIDEO/KBD DRIVER (VDU.ASM)
CVDUENABLE	.EQU	FALSE		; CVDU: ENABLE CVDU VIDEO/KBD DRIVER (CVDU.ASM)
NECENABLE	.EQU	FALSE		; NEC: ENABLE NEC UPD7220 VIDEO/KBD DRIVER (NEC.ASM)
TMSENABLE	.EQU	FALSE		; TMS: ENABLE TMS9918 VIDEO/KBD DRIVER (TMS.ASM)
TMSTIMENABLE	.EQU	FALSE		; TMS: ENABLE TIMER INTERRUPTS (REQUIRES IM1)
VGAENABLE	.EQU	FALSE		; VGA: ENABLE VGA VIDEO/KBD DRIVER (VGA.ASM)
;
MDENABLE	.EQU	TRUE		; MD: ENABLE MEMORY (ROM/RAM) DISK DRIVER (MD.ASM)
MDROM		.EQU	TRUE		; MD: ENABLE ROM DISK
MDRAM		.EQU	TRUE		; MD: ENABLE RAM DISK
MDTRACE		.EQU	1		; MD: TRACE LEVEL (0=NO,1=ERRORS,2=ALL)
MDFFENABLE	.EQU	FALSE		; MD: ENABLE FLASH FILE SYSTEM 
;
FDENABLE	.EQU	FALSE		; FD: ENABLE FLOPPY DISK DRIVER (FD.ASM)
FDMODE		.EQU	FDMODE_RCWDC	; FD: DRIVER MODE: FDMODE_[DIO|ZETA|ZETA2|DIDE|N8|DIO3|RCSMC|RCWDC|DYNO|EPWDC]
FDCNT		.EQU	2		; FD: NUMBER OF FLOPPY DRIVES ON THE INTERFACE (1-2)
FDTRACE		.EQU	1		; FD: TRACE LEVEL (0=NO,1=FATAL,2=ERRORS,3=ALL)
FDMEDIA		.EQU	FDM144		; FD: DEFAULT MEDIA FORMAT FDM[720|144|360|120|111]
FDMEDIAALT	.EQU	FDM720		; FD: ALTERNATE MEDIA FORMAT FDM[720|144|360|120|111]
FDMAUTO		.EQU	TRUE		; FD: AUTO SELECT DEFAULT/ALTERNATE MEDIA FORMATS
;
RFENABLE	.EQU	FALSE		; RF: ENABLE RAM FLOPPY DRIVER
;
IDEENABLE	.EQU	FALSE		; IDE: ENABLE IDE DISK DRIVER (IDE.ASM)
IDETRACE	.EQU	1		; IDE: TRACE LEVEL (0=NO,1=ERRORS,2=ALL)
IDECNT		.EQU	1		; IDE: NUMBER OF IDE INTERFACES TO DETECT (1-3), 2 DRIVES EACH
IDE0MODE	.EQU	IDEMODE_RC	; IDE 0: DRIVER MODE: IDEMODE_[DIO|DIDE|MK4|RC]
IDE0BASE	.EQU	$10		; IDE 0: IO BASE ADDRESS
IDE0DATLO	.EQU	$00		; IDE 0: DATA LO PORT FOR 16-BIT I/O
IDE0DATHI	.EQU	$00		; IDE 0: DATA HI PORT FOR 16-BIT I/O
IDE0A8BIT	.EQU	TRUE		; IDE 0A (MASTER): 8 BIT XFER
IDE0B8BIT	.EQU	TRUE		; IDE 0B (MASTER): 8 BIT XFER
IDE1MODE	.EQU	IDEMODE_NONE	; IDE 1: DRIVER MODE: IDEMODE_[DIO|DIDE|MK4|RC]
IDE1BASE	.EQU	$00		; IDE 1: IO BASE ADDRESS
IDE1DATLO	.EQU	$00		; IDE 1: DATA LO PORT FOR 16-BIT I/O
IDE1DATHI	.EQU	$00		; IDE 1: DATA HI PORT FOR 16-BIT I/O
IDE1A8BIT	.EQU	TRUE		; IDE 1A (MASTER): 8 BIT XFER
IDE1B8BIT	.EQU	TRUE		; IDE 1B (MASTER): 8 BIT XFER
IDE2MODE	.EQU	IDEMODE_NONE	; IDE 2: DRIVER MODE: IDEMODE_[DIO|DIDE|MK4|RC]
IDE2BASE	.EQU	$00		; IDE 2: IO BASE ADDRESS
IDE2DATLO	.EQU	$00		; IDE 2: DATA LO PORT FOR 16-BIT I/O
IDE2DATHI	.EQU	$00		; IDE 2: DATA HI PORT FOR 16-BIT I/O
IDE2A8BIT	.EQU	TRUE		; IDE 2A (MASTER): 8 BIT XFER
IDE2B8BIT	.EQU	TRUE		; IDE 2B (MASTER): 8 BIT XFER
;
PPIDEENABLE	.EQU	FALSE		; PPIDE: ENABLE PARALLEL PORT IDE DISK DRIVER (PPIDE.ASM)
PPIDETRACE	.EQU	1		; PPIDE: TRACE LEVEL (0=NO,1=ERRORS,2=ALL)
PPIDECNT	.EQU	1		; PPIDE: NUMBER OF PPI CHIPS TO DETECT (1-3), 2 DRIVES PER CHIP
PPIDE0BASE	.EQU	$20		; PPIDE 0: PPI REGISTERS BASE ADR
PPIDE0A8BIT	.EQU	FALSE		; PPIDE 0A (MASTER): 8 BIT XFER
PPIDE0B8BIT	.EQU	FALSE		; PPIDE 0B (SLAVE): 8 BIT XFER
;
SDENABLE	.EQU	FALSE		; SD: ENABLE SD CARD DISK DRIVER (SD.ASM)
SDMODE		.EQU	SDMODE_PPI	; SD: DRIVER MODE: SDMODE_[JUHA|N8|CSIO|PPI|UART|DSD|MK4|SC|MT]
SDPPIBASE	.EQU	$60		; SD: BASE I/O ADDRESS OF PPI FOR PPI MODDE
SDCNT		.EQU	1		; SD: NUMBER OF SD CARD DEVICES (1-2), FOR DSD & SC ONLY
SDTRACE		.EQU	1		; SD: TRACE LEVEL (0=NO,1=ERRORS,2=ALL)
SDCSIOFAST	.EQU	FALSE		; SD: ENABLE TABLE-DRIVEN BIT INVERTER IN CSIO MODE
SDMTSWAP	.EQU	FALSE		; SD: SWAP THE LOGICAL ORDER OF THE SPI PORTS OF THE MT011
;
PRPENABLE	.EQU	FALSE		; PRP: ENABLE ECB PROPELLER IO BOARD DRIVER (PRP.ASM)
PRPSDENABLE	.EQU	TRUE		; PRP: ENABLE PROPIO DRIVER SD CARD SUPPORT
PRPSDTRACE	.EQU	1		; PRP: SD CARD TRACE LEVEL (0=NO,1=ERRORS,2=ALL)
PRPCONENABLE	.EQU	TRUE		; PRP: ENABLE PROPIO DRIVER VIDEO/KBD SUPPORT
;
PPPENABLE	.EQU	FALSE		; PPP: ENABLE ZETA PARALLEL PORT PROPELLER BOARD DRIVER (PPP.ASM)
;
HDSKENABLE	.EQU	FALSE		; HDSK: ENABLE SIMH HDSK DISK DRIVER (HDSK.ASM)
;
PIO_4P		.EQU	FALSE		; PIO: ENABLE PARALLEL PORT DRIVER FOR ECB 4P BOARD
PIO_ZP		.EQU	FALSE		; PIO: ENABLE PARALLEL PORT DRIVER FOR ECB ZILOG PERIPHERALS BOARD (PIO.ASM)
PIO_SBC		.EQU	FALSE		; PIO: ENABLE PARALLEL PORT DRIVER FOR 8255 CHIP
;
UFENABLE	.EQU	FALSE		; UF: ENABLE ECB USB FIFO DRIVER (UF.ASM)
;
SN76489ENABLE	.EQU	FALSE		; SN76489 SOUND DRIVER
AUDIOTRACE	.EQU	FALSE		; ENABLE TRACING TO CONSOLE OF SOUND DRIVER
SN7CLK		.EQU	CPUOSC / 4	; DEFAULT TO CPUOSC / 4
;
AY38910ENABLE	.EQU	FALSE		; AY: AY-3-8910 / YM2149 SOUND DRIVER
AY_CLK		.EQU	CPUOSC / 4	; DEFAULT TO CPUOSC / 4
AYMODE		.EQU	AYMODE_NONE	; AY: DRIVER MODE: AYMODE_[SCG/N8/RCZ80/RCZ180]
;
SPKENABLE	.EQU	FALSE		; SPK: ENABLE RTC LATCH IOBIT SOUND DRIVER (SPK.ASM)
;
DMAENABLE	.EQU	FALSE		; DMA: ENABLE DMA DRIVER (DMA.ASM)
DMABASE		.EQU	$E0		; DMA: DMA BASE ADDRESS
DMAMODE		.EQU	DMAMODE_NONE	; DMA: DMA MODE (NONE|ECB|Z180|Z280|RC)
