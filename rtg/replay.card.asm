;
; WWW.FPGAArcade.COM
;
; REPLAY Retro Gaming Platform
; No Emulation No Compromise
;
; Replay.card - P96 RTG driver for the REPLAY Amiga core
; Copyright (C) FPGAArcade community
;
; Contributors : Jakub Bednarski, Mike Johnson, Jim Drew, Erik Hemming, Nicolas Hamel
;
; This software is licensed under LPGLv2.1 ; see LICENSE file
;
;

; 1.24   - Fix fast mem alloc with 060db (eriQue)
;           Request MMU cache mode change (040/060)
; 1.0.23 - Made compatible with ASM-One/AsmPro and PhxAss and vasm (eriQue)
;           Replaced custom bugprintf with _LVORawDoFmt / _LVORawPutChar
;           Changed SetInterrupt() to use VDE_InterruptEnable and added check in the ISR
;           Added debug trace output for all VDE register writes
;           Removed all LED bchg operations
; 1.0.22 - Changed clock timing (MikeJ)
; 1.0.21 - Re-wrote SetInt() and VBL handler (Jim Drew)
; 1.0.20 - Fix race condition on the set interrupt (Gouky)
; 1.0.19 - removed includes, replaced with System.gs, added blitter debugging (Jim Drew)
; 1.0.18 - hardware sprite support
; 1.0.17 - HDSTOP now is equal actual width
; 1.0.16 - VBLINT changed to INT2
; 1.0.15 - optimized BlitRect()
; 1.0.14 - implemented BlitRect() with hardware support

; ASM-One / AsmPro : r replay.card.asm\a\
; PhxAss:PhxAss replay.card.asm SET "AUTO,PHXASS"
; Devpac:GenAm replay.card.asm -E AUTO -E DEVPAC
; vasmm68k_mot -quiet -nowarn=1012 -cnop=0x0000 -m68020 -Fhunkexe -kick1hunks -nosym -no-opt replay.card.asm -o Replay.card -L replay.txt -I ~/Dropbox/NDK_3.9/Include/include_i

	incdir  drivers:rtg/
	include P96BoardInfo.i
	include P96ModeInfo.i
	include P96CardStruct.i
	include vde.i

	IFND	AUTO
SYSTEM_INCLUDES
		AUTO	wo LIBS:Picasso96/Replay.card\
	ELSE
		output	LIBS:Picasso96/Replay.card
		IFD		DEVPAC
			include system.gs
			opt	P=68020
		ENDC
		IFD		PHXASS
SYSTEM_INCLUDES
			opt	0
			machine 68020
		ENDC
	ENDC

;	output ram:Replay.card

	IFD SYSTEM_INCLUDES
	incdir  asm_include:
	include lvo/exec_lib.i
	include lvo/expansion_lib.i
	include exec/exec.i
	include libraries/expansionbase.i
	include hardware/intbits.i
	ENDC

;debug

HasBlitter
;blitterhistory
HasSprite

BUG MACRO
	IFD	debug
	ifnc	"","\9"
	move.l	\9,-(sp)
	endc
	ifnc	"","\8"
	move.l	\8,-(sp)
	endc
	ifnc	"","\7"
	move.l	\7,-(sp)
	endc
	ifnc	"","\6"
	move.l	\6,-(sp)
	endc
	ifnc	"","\5"
	move.l	\5,-(sp)
	endc
	ifnc	"","\4"
	move.l	\4,-(sp)
	endc
	ifnc	"","\3"
	move.l	\3,-(sp)
	endc
	ifnc	"","\2"
	move.l	\2,-(sp)
	endc

	jsr	bugprintf

	dc.b	\1,$d,$a,0
	even

	adda.w	#(NARG-1)*4,sp

	ENDC
	ENDM

****************************************************************************
;	section ReplayRTG,code
****************************************************************************

MEMORY_SIZE EQU $400000
MEMF_REPLAY EQU (1<<14)


;------------------------------------------------------------------------------
	ProgStart:
;------------------------------------------------------------------------------

	moveq	#-1,d0
	rts

	IFD	debug
	bra.b	_bugprintf_end
bugprintf:	
		movem.l	d0-d1/a0-a3/a6,-(sp)
		move.l	$4.w,a6
		move.l	28(sp),a0
		lea	32(sp),a1
		lea	.putch(pc),a2
		move.l	a6,a3
		jsr	-522(a6)		; _LVORawDoFmt

.skip		move.l	28(sp),a0
.end:		move.b	(a0)+,d0
		bne.b	.end
		move.l	a0,d0
		addq.l	#1,d0
		and.l	#$fffffffe,d0
		move.l	d0,28(sp)
		movem.l	(sp)+,d0-d1/a0-a3/a6
		rts

.putch:		move.l	a3,a6
		jmp	-516(a6)		; _LVORawPutChar (execPrivate9)
_bugprintf_end:
	rts
	ENDC

;------------------------------------------------------------------------------
	RomTag:
;------------------------------------------------------------------------------

	dc.w	RTC_MATCHWORD
	dc.l	RomTag
	dc.l	ProgEnd
	dc.b	RTF_AUTOINIT	;RT_FLAGS
	dc.b	1		;RT_VERSION
	dc.b	NT_LIBRARY	;RT_TYPE
	dc.b	0		;RT_PRI
	dc.l	ReplayCard
	dc.l	IDString
	dc.l	InitTable
CardName:
	dc.b	'REPLAY',0
ReplayCard:
	dc.b	'Replay.card',0,0
	dc.b	'$VER: '
IDString:
	dc.b	'Replay.card 1.24 (30.01.2018)',0
	dc.b	0
expansionLibName:
	dc.b	'expansion.library',0

	cnop	0,4

InitTable:
	dc.l	CARD_SIZEOF	;DataSize
	dc.l	FuncTable	;FunctionTable
	dc.l	DataTable	;DataTable
	dc.l	InitRoutine
FuncTable:
	dc.l	Open
	dc.l	Close
	dc.l	Expunge
	dc.l	ExtFunc
	dc.l	FindCard
	dc.l	InitCard
	dc.l	-1
DataTable:
	INITBYTE	LN_TYPE,NT_LIBRARY
	INITBYTE	LN_PRI,206
	INITLONG	LN_NAME,ReplayCard
	INITBYTE	LIB_FLAGS,LIBF_SUMUSED|LIBF_CHANGED
	INITWORD	LIB_VERSION,1
	INITWORD	LIB_REVISION,0
	INITLONG	LIB_IDSTRING,IDString
	INITLONG	CARD_NAME,CardName
	dc.w		0,0

;------------------------------------------------------------------------------
	InitRoutine:
;------------------------------------------------------------------------------

;	BUG "Replay.card InitRoutine()"

	movem.l	a5,-(sp)
	movea.l	d0,a5
	move.l	a6,CARD_EXECBASE(a5)
	move.l	a0,CARD_SEGMENTLIST(a5)
	lea	expansionLibName(pc),a1
	moveq	#0,d0
	jsr	_LVOOpenLibrary(a6)

	move.l	d0,CARD_EXPANSIONBASE(a5)
	bne.b	.exit

	movem.l	d7/a5/a6,-(sp)
	move.l	#(AT_Recovery|AG_OpenLib|AO_ExpansionLib),d7
	movea.l	$4.w,a6
	jsr	_LVOAlert(a6)

	movem.l	(sp)+,d7/a5/a6
.exit:
	move.l	a5,d0
	movem.l	(sp)+,a5
	rts

;------------------------------------------------------------------------------
	Open:
;------------------------------------------------------------------------------

	addq.w	#1,LIB_OPENCNT(a6)
	bclr	#3,CARD_FLAGS(a6)

	IFD blitterhistory
	move.l	a0,-(sp)
	lea	$80000,a0
	moveq.l	#16,d0
.fill:
	clr.l	(a0)+
	dbra	d0,.fill

	move.l	(sp)+,a0
	ENDC

	move.l	a6,d0
	rts

;------------------------------------------------------------------------------
	Close:
;------------------------------------------------------------------------------

	moveq	#0,d0
	subq.w	#1,LIB_OPENCNT(a6)
	bne.b	.exit

	btst	#3,CARD_FLAGS(a6)
	beq.b	.exit

	bsr.b	Expunge

.exit:
	rts

;------------------------------------------------------------------------------
	Expunge:
;------------------------------------------------------------------------------

	movem.l	d2/a5/a6,-(sp)
	movea.l	a6,a5
	movea.l	CARD_EXECBASE(a5),a6
	tst.w	LIB_OPENCNT(a5)
	beq.b	.remove

	bset	#3,CARD_FLAGS(a5)
	moveq	#0,d0
	bra.b	.exit

.remove:
	move.l	CARD_SEGMENTLIST(a5),d2
	movea.l	a5,a1
	jsr	_LVORemove(a6)

	movea.l	CARD_EXPANSIONBASE(a5),a1
	jsr	_LVOCloseLibrary(a6)

	moveq	#0,d0
	movea.l	a5,a1
	move.w	LIB_NEGSIZE(a5),d0
	suba.l	d0,a1
	add.w	LIB_POSSIZE(a5),d0
	jsr	_LVOFreeMem(a6)

	move.l	d2,d0
.exit:
	movem.l	(sp)+,d2/a5/a6
	rts

;------------------------------------------------------------------------------
	ExtFunc:
;------------------------------------------------------------------------------

	moveq	#0,d0
	rts

;------------------------------------------------------------------------------
	FindCard:
;------------------------------------------------------------------------------
;  BOOL FindCard(struct BoardInfo *bi)
;
;  FindCard is called in the first stage of the board initialisation and
;  configuration and is used to look if there is a free and unconfigured
;  board of the type the driver is capable of managing. If it finds one,
;  it immediately reserves it for use by Picasso96, usually by clearing
;  the CDB_CONFIGME bit in the flags field of the ConfigDev struct of
;  this expansion card. But this is only a common example, a driver can
;  do whatever it wants to mark this card as used by the driver. This
;  mechanism is intended to ensure that a board is only configured and
;  used by one driver. FindBoard also usually fills some fields of the
;  BoardInfo struct supplied by the caller, the rtg.library, for example
;  the MemoryBase, MemorySize and RegisterBase fields.

	movem.l	a2/a3/a6,-(sp)
	movea.l	a0,a2


	movea.l	CARD_EXPANSIONBASE(a6),a6

	suba.l	a0,a0
.next:
	move.l	#5060,d0			;Manufacturer ID
	moveq	#20,d1				;Product ID
	jsr	_LVOFindConfigDev(a6)

	tst.l	d0
	beq.b	.exit

	movea.l	d0,a0
	bclr	#CDB_CONFIGME,cd_Flags(a0)
	beq.b	.next

	move.l	cd_BoardAddr(a0),(PSSO_BoardInfo_RegisterBase,a2)

	move.l	$4.w,a6
	move.l	#MEMORY_SIZE,d0
	addi.l	#$0000FFFF,d0		; add 64K-1
	move.l	#MEMF_PUBLIC|MEMF_FAST|MEMF_REPLAY,d1
	jsr	_LVOAllocMem(a6)

	tst.l	d0
	bne.b	.ok			; found REPLAY tagged mem

	move.l	#MEMORY_SIZE,d0
	addi.l	#$0000FFFF,d0		; add 64K-1
	move.l	#MEMF_PUBLIC|MEMF_FAST|MEMF_24BITDMA,d1
	jsr	_LVOAllocMem(a6)

	tst.l	d0
	beq.b	.exit

.ok
	addi.l	#$0000FFFF,d0		; add 64K-1
	andi.l	#$FFFF0000,d0		; and with 64K to even align memory
	move.l	d0,PSSO_BoardInfo_MemoryBase(a2)
	move.l	#MEMORY_SIZE,PSSO_BoardInfo_MemorySize(a2)

;	bchg.b	#1,$bfe001

	moveq	#-1,d0
.exit:
	movem.l	(sp)+,a2/a3/a6
	rts

;------------------------------------------------------------------------------
	InitCard:
;------------------------------------------------------------------------------
;  a0:  struct BoardInfo

	movem.l	a2/a5/a6,-(sp)
	movea.l	a0,a2

	lea	CardName(pc),a1
	move.l	a1,PSSO_BoardInfo_BoardName(a2)
	move.l	#10,PSSO_BoardInfo_BoardType(a2)
	move.l	#0,PSSO_BoardInfo_GraphicsControllerType(a0)
	move.l	#0,PSSO_BoardInfo_PaletteChipType(a2)

;	ori.w	#$3FF2,PSSO_BoardInfo_RGBFormats(a2)
	ori.w	#$3FFE,PSSO_BoardInfo_RGBFormats(a2)

	move.w	#8,PSSO_BoardInfo_BitsPerCannon(a2)
	move.l	#MEMORY_SIZE-$40000,PSSO_BoardInfo_MemorySpaceSize(a2)
	move.l	PSSO_BoardInfo_MemoryBase(a2),d0
	move.l	d0,PSSO_BoardInfo_MemorySpaceBase(a2)
	addi.l	#MEMORY_SIZE-$4000,d0
	move.l	d0,PSSO_BoardInfo_MouseSaveBuffer(a2)

	ori.l	#(1<<20),PSSO_BoardInfo_Flags(a2)	; BIF_INDISPLAYCHAIN
;	ori.l	#(1<<1),PSSO_BoardInfo_Flags(a2)	; BIF_NOMEMORYMODEMIX

	lea	SetSwitch(pc),a1
	move.l	a1,PSSO_BoardInfo_SetSwitch(a2)
	lea	SetDAC(pc),a1
	move.l	a1,PSSO_BoardInfo_SetDAC(a2)
	lea	SetGC(pc),a1
	move.l	a1,PSSO_BoardInfo_SetGC(a2)
	lea	SetPanning(pc),a1
	move.l	a1,PSSO_BoardInfo_SetPanning(a2)
	lea	CalculateBytesPerRow(pc),a1
	move.l	a1,PSSO_BoardInfo_CalculateBytesPerRow(a2)
	lea	CalculateMemory(pc),a1
	move.l	a1,PSSO_BoardInfo_CalculateMemory(a2)
	lea	GetCompatibleFormats(pc),a1
	move.l	a1,PSSO_BoardInfo_GetCompatibleFormats(a2)
	lea	SetColorArray(pc),a1
	move.l	a1,PSSO_BoardInfo_SetColorArray(a2)
	lea	SetDPMSLevel(pc),a1
	move.l	a1,PSSO_BoardInfo_SetDPMSLevel(a2)
	lea	SetDisplay(pc),a1
	move.l	a1,PSSO_BoardInfo_SetDisplay(a2)
	lea	SetMemoryMode(pc),a1
	move.l	a1,PSSO_BoardInfo_SetMemoryMode(a2)
	lea	SetWriteMask(pc),a1
	move.l	a1,PSSO_BoardInfo_SetWriteMask(a2)
	lea	SetReadPlane(pc),a1
	move.l	a1,PSSO_BoardInfo_SetReadPlane(a2)
	lea	SetClearMask(pc),a1
	move.l	a1,PSSO_BoardInfo_SetClearMask(a2)
	lea	WaitVerticalSync(pc),a1
	move.l	a1,PSSO_BoardInfo_WaitVerticalSync(a2)
	lea	(Reserved5,pc),a1
	move.l	a1,(PSSO_BoardInfo_Reserved5,a2)
	lea	SetClock(pc),a1
	move.l	a1,PSSO_BoardInfo_SetClock(a2)
	lea	ResolvePixelClock(pc),a1
	move.l	a1,PSSO_BoardInfo_ResolvePixelClock(a2)
	lea	GetPixelClock(pc),a1
	move.l	a1,PSSO_BoardInfo_GetPixelClock(a2)

	move.l	#113440000,PSSO_BoardInfo_MemoryClock(a2)

	move.l	#16,(PSSO_BoardInfo_PixelClockCount+0,a2)
	move.l	#16,(PSSO_BoardInfo_PixelClockCount+4,a2)
	move.l	#12,(PSSO_BoardInfo_PixelClockCount+8,a2)
	move.l	#8,(PSSO_BoardInfo_PixelClockCount+12,a2)
	move.l	#7,(PSSO_BoardInfo_PixelClockCount+16,a2)
;- Planar
;- Chunky
;- HiColor
;- Truecolor
;- Truecolor + Alpha

	move.w	#4095,(PSSO_BoardInfo_MaxHorValue+0,a2)
	move.w	#4095,(PSSO_BoardInfo_MaxVerValue+0,a2)
	move.w	#4095,(PSSO_BoardInfo_MaxHorValue+2,a2)
	move.w	#4095,(PSSO_BoardInfo_MaxVerValue+2,a2)
	move.w	#4095,(PSSO_BoardInfo_MaxHorValue+4,a2)
	move.w	#4095,(PSSO_BoardInfo_MaxVerValue+4,a2)
	move.w	#4095,(PSSO_BoardInfo_MaxHorValue+6,a2)
	move.w	#4095,(PSSO_BoardInfo_MaxVerValue+6,a2)
	move.w	#4095,(PSSO_BoardInfo_MaxHorValue+8,a2)
	move.w	#4095,(PSSO_BoardInfo_MaxVerValue+8,a2)

	move.w	#2048,(PSSO_BoardInfo_MaxHorResolution+0,a2)
	move.w	#2048,(PSSO_BoardInfo_MaxVerResolution+0,a2)
	move.w	#2048,(PSSO_BoardInfo_MaxHorResolution+2,a2)
	move.w	#2048,(PSSO_BoardInfo_MaxVerResolution+2,a2)
	move.w	#2048,(PSSO_BoardInfo_MaxHorResolution+4,a2)
	move.w	#2048,(PSSO_BoardInfo_MaxVerResolution+4,a2)
	move.w	#2048,(PSSO_BoardInfo_MaxHorResolution+6,a2)
	move.w	#2048,(PSSO_BoardInfo_MaxVerResolution+6,a2)
	move.w	#2048,(PSSO_BoardInfo_MaxHorResolution+8,a2)
	move.w	#2048,(PSSO_BoardInfo_MaxVerResolution+8,a2)

	lea	PSSO_BoardInfo_HardInterrupt(a2),a1
	lea	VBL_ISR(pc),a0
	move.l	a0,IS_CODE(a1)
	moveq	#INTB_PORTS,d0
	move.l	$4,a6
	jsr	_LVOAddIntServer(a6)

	ori.l	#(1<<4),PSSO_BoardInfo_Flags(a2)	; BIF_VBLANKINTERRUPT
	lea	SetInterrupt(pc),a1
	move.l	a1,PSSO_BoardInfo_SetInterrupt(a2)

	ifd	HasBlitter
	ori.l	#(1<<15),PSSO_BoardInfo_Flags(a2)	; BIF_BLITTER
	lea	BlitRectNoMaskComplete(pc),a1
	move.l	a1,PSSO_BoardInfo_BlitRectNoMaskComplete(a2)
	lea	BlitRect(pc),a1
	move.l	a1,PSSO_BoardInfo_BlitRect(a2)
	lea	WaitBlitter(pc),a1
	move.l	a1,PSSO_BoardInfo_WaitBlitter(a2)
	ENDC

	ifd	HasSprite
	ori.l	#(1<<0),PSSO_BoardInfo_Flags(a2)	; BIF_HARDWARESPRITE
	lea	SetSprite(pc),a1
	move.l	a1,PSSO_BoardInfo_SetSprite(a2)
	lea	SetSpritePosition(pc),a1
	move.l	a1,PSSO_BoardInfo_SetSpritePosition(a2)
	lea	SetSpriteImage(pc),a1
	move.l	a1,PSSO_BoardInfo_SetSpriteImage(a2)
	lea	SetSpriteColor(pc),a1
	move.l	a1,PSSO_BoardInfo_SetSpriteColor(a2)
	ENDC

	ori.l	#(1<<3),PSSO_BoardInfo_Flags(a2)	; BIF_CACHEMODECHANGE
	move.l	PSSO_BoardInfo_MemoryBase(a2),(PSSO_BoardInfo_MemorySpaceBase,a2)
	move.l	PSSO_BoardInfo_MemorySize(a2),(PSSO_BoardInfo_MemorySpaceSize,a2)

	move.l	#$FFFFFFFF,PSSO_BoardInfo_ChipData(a2)

	movea.l	PSSO_BoardInfo_RegisterBase(a2),a0

	moveq	#-1,d0
.exit:
	movem.l	(sp)+,a2/a5/a6
	rts

;------------------------------------------------------------------------------
	SetSwitch:
;------------------------------------------------------------------------------
;  a0:  struct BoardInfo
;  d0.w:		BOOL state
;  this function should set a board switch to let the Amiga signal pass
;  through when supplied with a 0 in d0 and to show the board signal if
;  a 1 is passed in d0. You should remember the current state of the
;  switch to avoid unneeded switching. If your board has no switch, then
;  simply supply a function that does nothing except a RTS.
;
;  NOTE: Return the opposite of the switch-state. BDK

	move.w	PSSO_BoardInfo_MoniSwitch(a0),d1
	andi.w	#$FFFE,d1
	tst.b	d0
	beq.b	.off

	ori.w	#$0001,d1
.off:
	move.w	PSSO_BoardInfo_MoniSwitch(a0),d0
	cmp.w	d0,d1
	beq.b	.done

	move.w	d1,PSSO_BoardInfo_MoniSwitch(a0)

	andi.l	#$1,d1
	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0
	move.w	d1,VDE_DisplaySwitch(a0)
	BUG	"VDE_DisplaySwitch = %lx",d1
.done:
;	bsr.w	SetInterrupt
	andi.w	#$0001,d0
	rts

;------------------------------------------------------------------------------
	SetDAC:
;------------------------------------------------------------------------------
;  a0: struct BoardInfo
;  d7: RGBFTYPE RGBFormat
;  This function is called whenever the RGB format of the display changes,
;  e.g. from chunky to TrueColor. Usually, all you have to do is to set
;  the RAMDAC of your board accordingly.

	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0
	move.w	d7,VDE_DisplayFormat(a0)
	BUG	"VDE_DisplayFormat = %lx",d7
	rts

;------------------------------------------------------------------------------
	SetGC:
;------------------------------------------------------------------------------
;  a0: struct BoardInfo
;  a1: struct ModeInfo
;  d0: BOOL Border
;  This function is called whenever another ModeInfo has to be set. This
;  function simply sets up the CRTC and TS registers to generate the
;  timing used for that screen mode. You should not set the DAC, clocks
;  or linear start adress. They will be set when appropriate by their
;  own functions.

;	bchg.b	#1,$bfe001

	movem.l	d2-d6,-(sp)

	move.l	a1,PSSO_BoardInfo_ModeInfo(a0)
	move.w	d0,PSSO_BoardInfo_Border(a0)
	move.w	d0,d4 ; Border
	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0

	move.w	PSSO_ModeInfo_Width(a1),d0
	moveq	#0,d1
	move.b	PSSO_ModeInfo_Depth(a1),d1
	addq.w	#7,d1
	lsr.w	#3,d1
	mulu.w	d1,d0
	move.w	d0,VDE_BytesPerLine(a0)
	BUG	"VDE_BytesPerLine = %lx",d0

	move.w	PSSO_ModeInfo_HorTotal(a1),d0
	subq.w	#1,d0
	move.w	d0,VDE_HorTotal(a0)
	BUG	"VDE_HorTotal = %lx",d0
	move.w	PSSO_ModeInfo_Width(a1),d0
;	subq.w	#1,d0
	move.w	d0,VDE_HorDisplayEnd(a0)
	BUG	"VDE_HorDisplayEnd = %lx",d0
	add.w	PSSO_ModeInfo_HorSyncStart(a1),d0
	move.w	d0,VDE_HorSyncStart(a0)
	BUG	"VDE_HorSyncStart = %lx",d0
	add.w	PSSO_ModeInfo_HorSyncSize(a1),d0
	move.w	d0,VDE_HorSyncEnd(a0)
	BUG	"VDE_HorSyncEnd = %lx",d0
	move.w	PSSO_ModeInfo_VerTotal(a1),d0
	subq.w	#1,d0
	move.w	d0,VDE_VerTotal(a0)
	BUG	"VDE_VerTotal = %lx",d0
	move.w	PSSO_ModeInfo_Height(a1),d0
	subq.w	#1,d0
	move.w	d0,VDE_VerDisplayEnd(a0)
	BUG	"VDE_VerDisplayEnd = %lx",d0
	add.w	PSSO_ModeInfo_VerSyncStart(a1),d0
	move.w	d0,VDE_VerSyncStart(a0)
	BUG	"VDE_VerSyncStart = %lx",d0
	add.w	PSSO_ModeInfo_VerSyncSize(a1),d0
	move.w	d0,VDE_VerSyncEnd(a0)
	BUG	"VDE_VerSyncEnd = %lx",d0
	moveq	#0,d0
	move.b	PSSO_ModeInfo_Flags(a1),d0
	move.w	d0,VDE_DisplayFlags(a0)
	BUG	"VDE_DisplayFlags = %lx",d0
	movem.l	(sp)+,d2-d6
	rts

;------------------------------------------------------------------------------
	SetPanning:
;------------------------------------------------------------------------------
;  a0: struct BoardInfo
;  a1: UBYTE* Memory
;  d0: WORD Width
;  d1: WORD XOffset
;  d2: WORD YOffset
;  d7: RGBFTYPE RGBFormat
;  This function sets the view origin of a display which might also be
;  overscanned. In register a1 you get the start address of the screen
;  bitmap on the Amiga side. You will have to subtract the starting
;  address of the board memory from that value to get the memory start
;  offset within the board. Then you get the offset in pixels of the
;  left upper edge of the visible part of an overscanned display. From
;  these values you will have to calculate the LinearStartingAddress
;  fields of the CRTC registers.

;	bchg.b	#1,$bfe001

	movem.l	d2-d5,-(sp)
	move.w	d1,PSSO_BoardInfo_XOffset(a0)
	move.w	d2,PSSO_BoardInfo_YOffset(a0)
	move.w	d0,d3
	moveq	#0,d5
	move.l	a1,d4
	move.b	.BytesPerPixel(pc,d7.l),d5

	move.l	PSSO_BoardInfo_ModeInfo(a0),a1

	sub.w	PSSO_ModeInfo_Width(a1),d0
	mulu.w	d5,d0
	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0
	move.w	d0,VDE_Modulo(a0)
	BUG	"VDE_Modulo = %lx",d0
	mulu.w	d2,d3
	ext.l	d1	; XOffset
	add.l	d1,d3
	mulu.l	d5,d3
	add.l	d4,d3
	move.l	d3,VDE_DisplayBase(a0)
	BUG	"VDE_DisplayBase = %lx",d3

	movem.l	(sp)+,d2-d5
	rts

.BytesPerPixel:

	dc.b	1	; RGBFB_NONE
	dc.b	1	; RGBFB_CLUT,
	dc.b	3	; RGBFB_R8G8B8
	dc.b	3	; RGBFB_B8G8R8
	dc.b	2	; RGBFB_R5G6B5PC
	dc.b	2	; RGBFB_R5G5B5PC
	dc.b	4	; RGBFB_A8R8G8B8
	dc.b	4	; RGBFB_A8B8G8R8
	dc.b	4	; RGBFB_R8G8B8A8
	dc.b	4	; RGBFB_B8G8R8A8
	dc.b	2	; RGBFB_R5G6B5
	dc.b	2	; RGBFB_R5G5B5
	dc.b	2	; RGBFB_B5G6R5PC
	dc.b	2	; RGBFB_B5G5R5PC
	dc.b	2	; RGBFB_Y4U2V2
	dc.b	1	; RGBFB_Y4U1V1


;------------------------------------------------------------------------------
	CalculateBytesPerRow:
;------------------------------------------------------------------------------
;  a0:  struct BoardInfo
;  d0:  uae_u16 Width
;  d7:  RGBFTYPE RGBFormat
;  This function calculates the amount of bytes needed for a line of
;  "Width" pixels in the given RGBFormat.

	cmpi.l	#16,d7
	bcc.b	.exit

	move.w	.base(pc,d7.l*2),d1
	jmp	.base(pc,d1.w)

.base:
	dc.w	.pp_1Bit-.base
	dc.w	.pp_1Byte-.base
	dc.w	.pp_3Bytes-.base
	dc.w	.pp_3Bytes-.base
	dc.w	.pp_2Bytes-.base
	dc.w	.pp_2Bytes-.base
	dc.w	.pp_4Bytes-.base
	dc.w	.pp_4Bytes-.base
	dc.w	.pp_4Bytes-.base
	dc.w	.pp_4Bytes-.base
	dc.w	.pp_2Bytes-.base
	dc.w	.pp_2Bytes-.base
	dc.w	.pp_2Bytes-.base
	dc.w	.pp_2Bytes-.base
	dc.w	.pp_2Bytes-.base
	dc.w	.pp_1Byte-.base

.pp_4Bytes:
	add.w	d0,d0
.pp_2Bytes:
	add.w	d0,d0
	bra.b	.exit

.pp_3Bytes:
	move.w	d0,d1
	add.w	d0,d1
	add.w	d1,d0
	bra.b	.exit

.pp_1Bit:
	lsr.w	#3,d0

.pp_1Byte:

.exit:
	rts

;------------------------------------------------------------------------------
	CalculateMemory:
;------------------------------------------------------------------------------

	move.l	a1,d0
	rts

;------------------------------------------------------------------------------
	SetColorArray:
;------------------------------------------------------------------------------
;  a0: struct BoardInfo
;  d0.w: startindex
;  d1.w: count
;  when this function is called, your driver has to fetch "count" color
;  values starting at "startindex" from the CLUT field of the BoardInfo
;  structure and write them to the hardware. The color values are always
;  between 0 and 255 for each component regardless of the number of bits
;  per cannon your board has. So you might have to shift the colors
;  before writing them to the hardware.

;	BUG	"SetColorArray( %lx / %lx )",d0,d1

	lea	PSSO_BoardInfo_CLUT(a0),a1
	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0
	lea	VDE_ColourPalette(a0),a0

;	adda.w	d0,a1
;	adda.w	d0,a1
;	adda.w	d0,a1

;	adda.w	d0,a0
;	adda.w	d0,a0
;	adda.w	d0,a0
;	adda.w	d0,a0

	lea	(a1,d0.w),a1
	lea	(a1,d0.w*2),a1
	lea	(a0,d0.w*4),a0

	bra.b	.sla_loop_end

.sla_loop:
	moveq	#0,d0
	move.b	(a1)+,d0
	lsl.w	#8,d0
	move.b	(a1)+,d0
	lsl.l	#8,d0
	move.b	(a1)+,d0

	move.l	d0,(a0)+
.sla_loop_end
	dbra	d1,.sla_loop

	rts

;------------------------------------------------------------------------------
	SetDPMSLevel:
;------------------------------------------------------------------------------

	rts

;------------------------------------------------------------------------------
	SetDisplay:
;------------------------------------------------------------------------------
;  a0:  struct BoardInfo
;  d0:  BOOL state
;  This function enables and disables the video display.
;
;  NOTE: return the opposite of the state

	not.b	d0
	andi.w	#1,d0
	rts

;------------------------------------------------------------------------------
	SetMemoryMode:
;------------------------------------------------------------------------------

	rts

;------------------------------------------------------------------------------
	SetWriteMask:
;------------------------------------------------------------------------------

	rts

;------------------------------------------------------------------------------
	SetReadPlane:
;------------------------------------------------------------------------------

	rts

;------------------------------------------------------------------------------
	SetClearMask:
;------------------------------------------------------------------------------

	move.b	d0,PSSO_BoardInfo_ClearMask(a0)
	rts

;------------------------------------------------------------------------------
	WaitVerticalSync:
;------------------------------------------------------------------------------
;  a0:  struct BoardInfo
;  This function waits for the next horizontal retrace.
	BUG	"WaitVerticalSync"

	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0
	; bit 15 is  VDE active low
	lea	VDE_DisplayStatus(a0),a0
	tst.b	d0
	beq.b	.wait_vde

	move.l	#1000000,d1
.wait_loop1:
	move.b	(a0),d0
	andi.b	#$80,d0		 ; Vertical retrace
	beq.b	.wait_vde

	subq.l	#1,d1
	bne.b	.wait_loop1

	rts

.wait_vde:
	move.l	#1000000,d1
.wait_loop2:
	move.b	(a0),d0
	andi.b	#$80,d0		 ; Vertical retrace
	bne.b	.wait_done

	subq.l	#1,d1
	bne.b	.wait_loop2

.wait_done:
	rts

;------------------------------------------------------------------------------
	Reserved5:
;------------------------------------------------------------------------------
;	BUG	"Reserved5"

	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0
	btst.b	#7,VDE_DisplayStatus(a0)	;Vertical retrace
	sne	d0
	extb.l	d0
	rts

;------------------------------------------------------------------------------
	SetClock:
;------------------------------------------------------------------------------

	movea.l	PSSO_BoardInfo_ModeInfo(a0),a1
	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0
	move.b	PSSO_ModeInfo_second_union(a1),d0
	lsl.w	#8,d0
	move.b	PSSO_ModeInfo_first_union(a1),d0
	move.w	d0,VDE_ClockDivider(a0)
	BUG	"VDE_ClockDivider = %lx",d0
	rts

;------------------------------------------------------------------------------
	ResolvePixelClock:
;------------------------------------------------------------------------------
; ARGS:
;	d0 - requested pixel clock frequency
; RESULT:
;	d0 - pixel clock index

	movem.l	d2/d3,-(sp)
	move.l	d0,d1						; requested clock frequency
	moveq	#0,d3
	move.b	.rpc_BytesPerPixel(pc,d7.l),d3

	move.l	(PSSO_BoardInfo_PixelClockCount.l,a0,d3.l*4),d2	; should be qualified with d3
	lea	 PixelClockTable(pc),a0
	moveq	#0,d0						; frequency index
.loop:
	cmp.l	(a0)+,d1
	beq.b	.done

	blt.b	.freq_lt_current

	addq.l	#1,d0	; go to next frequency
	cmp.l	d2,d0	; check if the last one
	blt.b	.loop

	subq.l	#1,d0	; return to the last one
	bra.b	.get_current

.freq_lt_current:
	tst.l	d0
	beq.b	.get_current

	move.l	(-4,a0),d2	; current clock frequency
	add.l	(-8,a0),d2	; previous clock frequency
	sub.l	d1,d2
	sub.l	d1,d2
	bmi.b	.get_current	; requested clock frequency is closer to the current one

.get_previous:
	move.l	(-8,a0),d1
	subq.l	#1,d0
	bra.b	.done

.get_current:
	move.l	(-4,a0),d1
.done:
	move.l	d1,PSSO_ModeInfo_PixelClock(a1)
	move.b	FirstUnionTable(pc,d0.l),PSSO_ModeInfo_first_union(a1)
	move.b	SecondUnionTable(pc,d0.l),PSSO_ModeInfo_second_union(a1)
	movem.l	(sp)+,d2/d3
	rts

.rpc_BytesPerPixel:

	dc.b	1	; RGBFB_NONE
	dc.b	1	; RGBFB_CLUT
	dc.b	3	; RGBFB_R8G8B8
	dc.b	3	; RGBFB_B8G8R8
	dc.b	2	; RGBFB_R5G6B5PC
	dc.b	2	; RGBFB_R5G5B5PC
	dc.b	4	; RGBFB_A8R8G8B8
	dc.b	4	; RGBFB_A8B8G8R8
	dc.b	4	; RGBFB_R8G8B8A8
	dc.b	4	; RGBFB_B8G8R8A8
	dc.b	2	; RGBFB_R5G6B5
	dc.b	2	; RGBFB_R5G5B5
	dc.b	2	; RGBFB_B5G6R5PC
	dc.b	2	; RGBFB_B5G5R5PC
	dc.b	2	; RGBFB_Y4U2V2
	dc.b	1	; RGBFB_Y4U1V1

;------------------------------------------------------------------------------
	GetPixelClock:
;------------------------------------------------------------------------------

	lea	PixelClockTable(pc),a0
	move.l	(a0,d0.l*4),d0
	moveq	#0,d1
	move.b	.gpc_BytesPerPixel(pc,d7.l),d1
	rts

.gpc_BytesPerPixel:

	dc.b	1	; RGBFB_NONE
	dc.b	1	; RGBFB_CLUT
	dc.b	3	; RGBFB_R8G8B8
	dc.b	3	; RGBFB_B8G8R8
	dc.b	2	; RGBFB_R5G6B5PC
	dc.b	2	; RGBFB_R5G5B5PC
	dc.b	4	; RGBFB_A8R8G8B8
	dc.b	4	; RGBFB_A8B8G8R8
	dc.b	4	; RGBFB_R8G8B8A8
	dc.b	4	; RGBFB_B8G8R8A8
	dc.b	2	; RGBFB_R5G6B5
	dc.b	2	; RGBFB_R5G5B5
	dc.b	2	; RGBFB_B5G6R5PC
	dc.b	2	; RGBFB_B5G5R5PC
	dc.b	2	; RGBFB_Y4U2V2
	dc.b	1	; RGBFB_Y4U1V1
; base clocks

; 28.625 MHz 0
; 40.000 MHz 1
; 50.000 MHz 2
; 74.250 MHz 3
; 82.000 MHz 4
;108.000 MHz 5
;114.500 MHz 6

FirstUnionTable: ; divider (-1)

	dc.b	3
	dc.b	3
	dc.b	3
	dc.b	1
	dc.b	1
	dc.b	3
	dc.b	0
	dc.b	2
	dc.b	0
	dc.b	0
	dc.b	1
	dc.b	1
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	0


SecondUnionTable:	; clock generator select

	dc.b	0
	dc.b	1
	dc.b	2
	dc.b	1
	dc.b	2
	dc.b	5
	dc.b	0
	dc.b	5
	dc.b	1
	dc.b	2
	dc.b	5
	dc.b	6
	dc.b	3
	dc.b	4
	dc.b	5
	dc.b	6

PixelClockTable:

	dc.l	7156250		;28.625	div	4
	dc.l	10000000	;40	div	4
	dc.l	12500000	;50	div	4
	dc.l	20000000	;40	div	2
	dc.l	25000000	;50	div	2
	dc.l	27000000	;108	div	4
	dc.l	28625000	;28.625	div	1
	dc.l	36000000	;108	div	3
	dc.l	40000000	;40	div	1
	dc.l	50000000	;50	div	1
	dc.l	54000000	;108	div	2
	dc.l	57250000	;114.5	div	2
	dc.l	74250000	;74.25	div	1
	dc.l	82000000	;82	div	1
	dc.l	108000000	;108	div	1
	dc.l	114500000	;114.5	div	1


;------------------------------------------------------------------------------
	SetInterrupt:
;------------------------------------------------------------------------------

;	bchg.b	#1,$bfe001

	movea.l	PSSO_BoardInfo_RegisterBase(a0),a1
	tst.b	d0
	beq.b	.disable

	move.w	VDE_InterruptEnable(a1),d0
	bne.b	.done

	move.w	#$0001,VDE_InterruptEnable(a1)
	BUG	"VDE_InterruptEnable = $0001"

.done:	rts

.disable:
	move.w	VDE_InterruptEnable(a1),d0
	beq.b	.done

	move.w	#$0000,VDE_InterruptEnable(a1)
	BUG	"VDE_InterruptEnable = $0000"
	bra.b	.done

;------------------------------------------------------------------------------
	VBL_ISR:
;------------------------------------------------------------------------------

	movem.l	a1/a6,-(sp)
	movea.l	PSSO_BoardInfo_RegisterBase(a1),a6

	move.w	VDE_InterruptEnable(a6),d0
	tst.b	d0
	beq.b	.no_soft_int

	move.w	VDE_InterruptRequest(a6),d0
	andi.w	#$0001,d0
	beq.b	.no_soft_int

	movea.l	PSSO_BoardInfo_ExecBase(a1),a6
	lea	PSSO_BoardInfo_SoftInterrupt(a1),a1
	jsr	_LVOCause(a6)

;	bchg.b	#1,$bfe001

	movem.l	(sp)+,a1/a6
	moveq	#1,d0
	rts

.no_soft_int:

	movem.l	(sp)+,a1/a6
	moveq	#0,d0
	rts

;------------------------------------------------------------------------------
	SetSprite:
;------------------------------------------------------------------------------
; a0: struct BoardInfo *bi
; d0: BOOL activate
; d7: RGBFTYPE RGBFormat
;
; This function activates or deactivates the hardware sprite.

;	BUG "SetSprite()"

;	BUG "a0 = %lx",a0
;	BUG "d0 = %ld",d0
;	BUG "d7 = %ld",d7

	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0
	andi.w	#1,d0
	move.w	d0,VDE_SpriteControl(a0)
	BUG	"VDE_SpriteControl = %lx",d0
	rts


;------------------------------------------------------------------------------
	SetSpritePosition:
;------------------------------------------------------------------------------
; a0: struct BoardInfo *bi
; d7: RGBFTYPE RGBFormat

;	BUG "SetSpritePosition()"

;	BUG "a0 = %lx",a0
;	BUG "d7 = %ld",d7

	move.w	PSSO_BoardInfo_MouseX(a0),d0
	move.w	PSSO_BoardInfo_MouseY(a0),d1
	sub.w	PSSO_BoardInfo_XOffset(a0),d0
	sub.w	PSSO_BoardInfo_YOffset(a0),d1
	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0

;	BUG "X = %d",d0

	move.w	d0,VDE_SpriteXPos(a0)

;	BUG "Y = %d",d1

	move.w	d1,VDE_SpriteYPos(a0)

	BUG	"VDE_SpriteX/YPos = %ld, %ld",d0,d1
;	moveq	#1,d0
	rts


;------------------------------------------------------------------------------
	SetSpriteImage:
;------------------------------------------------------------------------------
; a0: struct BoardInfo *bi
; d7: RGBFTYPE RGBFormat
;
; This function gets new sprite image data from the MouseImage field of the BoardInfo structure and writes
; it to the board.
;
; There are three possible cases:
;
; BIB_HIRESSPRITE is set:
; skip the first two long words and the following sprite data is arranged as an array of two longwords. Those form the
; two bit planes for one image line respectively.
;
; BIB_HIRESSPRITE and BIB_BIGSPRITE are not set:
; skip the first two words and the following sprite data is arranged as an array of two words. Those form the two
; bit planes for one image line respectively.
;
; BIB_HIRESSPRITE is not set and BIB_BIGSPRITE is set:
; skip the first two words and the following sprite data is arranged as an array of two words. Those form the two bit
; planes for one image line respectively. You have to double each pixel horizontally and vertically. All coordinates
; used in this case already assume a zoomed sprite, only the sprite data is not zoomed yet. You will have to
; compensate for this when accounting for hotspot offsets and sprite dimensions.


;	BUG "SetSpriteImage()"

;	BUG "a0 = %lx",a0
;	BUG "d7 = %ld",d7


	moveq	#0,d1
	movea.l	PSSO_BoardInfo_MouseImage(a0),a1
	move.b	PSSO_BoardInfo_MouseHeight(a0),d1
	move.l	PSSO_BoardInfo_Flags(a0),d0
	andi.l	#$00010000,d0 ; BIF_HIRESSPRITE
	bne	SetMouseImage_Hires

	move.l	PSSO_BoardInfo_Flags(a0),d0
	andi.l	#$00020000,d0 ; BIF_BIGSPRITE
	bne	SetMouseImage_Big

SetMouseImage_Normal:

	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0
	lea	(4,a1),a1
	lea	VDE_SpriteImage(a0),a0
	cmpi.w	#64,d1
	ble	.ok

	moveq	#64,d1
.ok:
	BUG	"SetSpriteImage() = $%lx, %ld longwords",a1,d1
	move.w	d1,d0
	bra	 .end

.loop:
	move.l	(a1)+,(a0)+
	clr.l	(a0)+
.end:
	dbra	d1,.loop

SetMouseImage_ClearBuffer:

	neg.w	d0
	addi.w	#64,d0
	asl.w	#1,d0
	bra	.end
.loop:
	clr.l	(a0)+
.end:
	dbra	d0,.loop


	rts

SetMouseImage_Hires:

	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0
	lea	(8,a1),a1
	lea	VDE_SpriteImage(a0),a0
	cmpi.w	#64,d1
	ble	 .ok

	moveq	#64,d1
.ok:
	BUG	"SetSpriteImage() = $%lx, %ld quadwords",a1,d1
	move.w	d1,d0
	bra	 .end

.loop:
	move.w	(a1),(a0)+
	move.w	(4,a1),(a0)+
	move.w	(2,a1),(a0)+
	move.w	(6,a1),(a0)+
	lea	(8,a1),a1
.end:
	dbra	d1,.loop

	bra	SetMouseImage_ClearBuffer

;	rts

SetMouseImage_Big:

	movem.l	d2/d3,-(sp)
	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0
	lea	(4,a1),a1
	lea	VDE_SpriteImage(a0),a0
	asr.w	#1,d1
	cmpi.w	#64,d1
	ble	.ok

	moveq	#64,d1
.ok:
	BUG	"SetSpriteImage() = $%lx, %ld octawords",a1,d1
	move.w	d1,-(sp)
	asr.w	#1,d1
	bra	.end

.loop:

	move.l	(a1),d0
	rol.l	#8,d0
	bsr	Scale2X
	move.w	d2,(8,a0)
	move.w	d2,(a0)

	swap	d0
	bsr	Scale2X
	move.w	d2,(10,a0)
	move.w	d2,(2,a0)

	ror.l	#8,d0
	bsr	Scale2X
	move.w	d2,(12,a0)
	move.w	d2,(4,a0)

	swap	d0
	bsr	Scale2X
	move.w	d2,(14,a0)
	move.w	d2,(6,a0)

	lea	(4,a1),a1
	lea	(16,a0),a0

.end:
	dbra	d1,.loop

	move.w	(sp)+,d0
	movem.l	(sp)+,d2/d3
	bra	SetMouseImage_ClearBuffer
;	rts


Scale2X:

	moveq	#7,d3
.loop:
	roxr.b	#1,d0
	roxr.w	#1,d2
	asr.w	#1,d2
	dbra	d3,.loop
	rts

;------------------------------------------------------------------------------
	SetSpriteColor:
;------------------------------------------------------------------------------
; a0: struct BoardInfo *bi
; d0.b: index
; d1.b: red
; d2.b: green
; d3.b: blue
; d7: RGBFTYPE RGBFormat
;
; This function changes one of the possible three colors of the hardware sprite.

;	BUG "SetSpriteColor()"

;	BUG "a0 = %lx",a0
;	BUG "d0 = %ld",d0
;	BUG "d1 = %ld",d1
;	BUG "d2 = %ld",d2
;	BUG "d3 = %ld",d3
;	BUG "d7 = %ld",d7

	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0
	lsl.w	#8,d1
	move.b	d2,d1
	lsl.l	#8,d1
	move.b	d3,d1
	lea	VDE_SpriteColours(a0),a0
	addq.b	#1,d0
	andi.w	#3,d0
	move.l	d1,(a0,d0.w*4)

;	moveq	#1,d0
	rts

;------------------------------------------------------------------------------
	GetCompatibleFormats:
;------------------------------------------------------------------------------

	moveq	#-1,d0
	rts

;------------------------------------------------------------------------------
	BlitRectNoMaskComplete:
;------------------------------------------------------------------------------
; a0:   struct BoardInfo
; a1:   struct RenderInfo (src)
; a2:   struct RenderInfo (dst)
; d0:   WORD SrcX
; d1:   WORD SrcY
; d2:   WORD DstX
; d3:   WORD DstY
; d4:   WORD Width
; d5:   WORD Height
; d6:   UBYTE OpCode
; d7:   ULONG RGBFormat
; MUST return 0 in D0 if we're not handling this operation
; because the RGBFormat or opcode aren't supported.
; OTHERWISE return 1

; OpCodes:
;  0 = FALSE:		dst = 0
;  1 = NOR:		dst = ~(src | dst)
;  2 = ONLYDST:		dst = dst & ~src
;  3 = NOTSRC:		dst = ~src
;  4 = ONLYSRC:		dst = src & ~dst
;  5 = NOTDST:		dst = ~dst
;  6 = EOR:		dst = src^dst
;  7 = NAND:		dst = ~(src & dst)
;  8 = AND:		dst = (src & dst)
;  9 = NEOR:		dst = ~(src ^ dst)
; 10 = DST:		dst = dst
; 11 = NOTONLYSRC:	dst = ~src | dst
; 12 = SRC:		dst = src
; 13 = NOTONLYDST:	dst = ~dst | src
; 14 = OR:		dst = src | dst
; 15 = TRUE:		dst = 0xFF

; IF 0
;	BUG "BlitRectNoMaskComplete()

;	BUG "a0 = %lx",a0
;	BUG "a1 = %lx",a1
;	BUG "a2 = %lx",a2
;	BUG "d0 = %ld",d0
;	BUG "d1 = %ld",d1
;	BUG "d2 = %ld",d2
;	BUG "d3 = %ld",d3
;	BUG "d4 = %ld",d4
;	BUG "d5 = %ld",d5
;	BUG "d6 = %lx",d6
;	BUG "d7 = %ld",d7
; ENDIF
	movem.l	d0-d7/a0-a3,-(sp)
;	bchg.b	#1,$bfe001	 ; blink when blitter function called!

	IFD blitterhistory
	movem.l	d0-d7/a0-a3,-(sp)
	lea	$80000,a0
	andi.l	#$000000FF,d6
	move.l	(a0,d6.w*4),d0
	addq.l	#1,d0
	move.l	d0,(a0,d6.w*4)
	movem.l	(sp)+,d0-d7/a0-a3
	ENDC

	cmpi.b	#12,d6		; only mode 12 is currently supported!
	bne	.not_supported

	cmpi.l	#15,d7
	bhi	.exit

	bsr	GetBytesPerPixel

	mulu.w	d7,d4	; W * BPP

	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0

	moveq	#0,d6
	move.w	(4,a1),d6	; RenderInfo.BytesPerRow
	move.l	(a1),a1		; Memory

;	BUG "sri->Memory = %lx",a1
;	BUG "sri->BytesPerRow = %ld",d6

	; SRCPTR = MEM + SrcX * BPP + SrcY * BPR
	mulu.w	d7,d0	; BPP * SrcX
	adda.l	d0,a1
	mulu.w	d6,d1	; BPR * SrcY
	adda.l	d1,a1

	move.w	d5,d1	; H
	subq.w	#1,d1	; H - 1
	mulu.w	d6,d1	; (H-1) * SRCBPR

	; calculate source modulo SRCMOD = BPR - W * BPP
	sub.l	d4,d6	; BPR - (W * BPP)
	move.l	d6,VBE_SRCMOD(a0)
;	BUG "VBE_SRCMOD = %ld",d6

	; destination area
	moveq	#0,d6
	move.w	(4,a2),d6	; RenderInfo.BytesPerRow
	move.l	(a2),a2		; Memory

;	BUG "dri->Memory = %lx",a2
;	BUG "dri->BytesPerRow = %ld",d6

	; DSTPTR = MEM + DstX * BPP + DstY * BPR
	mulu.w	d7,d2	; BPP * SrcX
	adda.l	d2,a2
	mulu.w	d6,d3	; BPR * SrcY
	adda.l	d3,a2

	move.w	d5,d3	; H
	subq.w	#1,d3	; H - 1
	mulu.w	d6,d3	; (H-1) * DSTBPR

	; calculate modulo
	sub.l	d4,d6	; DSTBPR - W*BPP
	move.l	d6,VBE_DSTMOD(a0)
;	BUG "VBE_DSTMOD = %ld",d6

	move.w	#0,VBE_CONTROL(a0)

	cmpa.l	a1,a2
	blo	.forward

	adda.l	d1,a1
	adda.l	d4,a1
	subq.l	#1,a1

	adda.l	d3,a2
	adda.l	d4,a2
	subq.l	#1,a2

	move.w	#1,VBE_CONTROL(a0)

.forward

	move.l	a1,VBE_SRCPTR(a0)
;	BUG "VBE_SRCPTR = %lx",a1
	move.l	a2,VBE_DSTPTR(a0)
;	BUG "VBE_DSTPTR = %lx",a2

	move.w	d4,VBE_SIZEX(a0)
	move.w	d5,VBE_SIZEY(a0)
;	BUG "VBE_SIZEX = %ld",d4
;	BUG "VBE_SIZEY = %ld",d5

.wait:
	move.w	VBE_STATUS(a0),d0
	bmi	.wait

.exit
	movem.l	(sp)+,d0-d7/a0-a3
	rts

.not_supported:

;	BUG "*
	movem.l	(sp)+,d0-d7/a0-a3
	move.l	PSSO_BoardInfo_BlitRectNoMaskCompleteDefault(a0),-(a7)
	rts


;------------------------------------------------------------------------------
	BlitRect:
;------------------------------------------------------------------------------
; a0:   struct BoardInfo
; a1:   struct RenderInfo
; d0:   WORD SrcX
; d1:   WORD SrcY
; d2:   WORD DstX
; d3:   WORD DstY
; d4:   WORD Width
; d5:   WORD Height
; d6:   UBYTE Mask
; d7:   ULONG RGBFormat

; IF 0
;	BUG "BlitRect(),d7

;	BUG "a0 = %lx",a0
;	BUG "a1 = %lx",a1
;	BUG "d0 = %ld",d0
;	BUG "d1 = %ld",d1
;	BUG "d2 = %ld",d2
;	BUG "d3 = %ld",d3
;	BUG "d4 = %ld",d4
;	BUG "d5 = %ld",d5
;	BUG "d6 = %lx",d6
;	BUG "d7 = %ld",d7
; ENDIF
	movem.l	d2-d7/a2/a3,-(sp)
;	bchg.b	#1,$bfe001	; blink when blitter function called!

	cmpi.l	#15,d7
	bhi	.exit
	bsr	GetBytesPerPixel

	moveq	#0,d6
	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0
	move.w	(4,a1),d6	; RenderInfo.BytesPerRow
;	BUG "RenderInfo.BytesPerRow = %d",d6
	move.l	(a1),a1		; Memory
;	BUG "RenderInfo.Memory = %lx",a1

	cmp.w	d1,d3
	blo	.forward
	bhi	.reverse

	cmp.w	d0,d2
	blo	.forward
	beq	.exit

.reverse

	; SRCPTR = MEM + (SrcX + W) * BPP + (SrcY + H - 1) * BPR - 1
	movea.l	a1,a2	; MEM
	add.w	d4,d0	; SrcX + W
	mulu.w	d7,d0	; (SrcX + W) * BPP
	adda.l	d0,a2	;
	add.w	d5,d1	; SrcY + H
	subq.w	#1,d1	; SrcY + H - 1
	mulu.w	d6,d1	; BPR * SrcY
	adda.l	d1,a2
	suba.l	#1,a2

	; DSTPTR = MEM + (DstX + W) * BPP + (DstY + H - 1) * BPR - 1
	movea.l	a1,a3	; MEM
	add.w	d4,d2	; DstX + W
	mulu.w	d7,d2	; (DstX + W) * BPP
	adda.l	d2,a3
	add.w	d5,d3	; DstY + H
	subq.w	#1,d3	; DstY + H - 1
	mulu.w	d6,d3	; BPR * DstY
	adda.l	d3,a3
	suba.l	#1,a3

	; calculate modulo MOD = BPR - W*BPP
	mulu.w	d4,d7	; W * BPP
	sub.l	d7,d6	; BPR - (W * BPP)

	move.w	#1,VBE_CONTROL(a0)

	bra	.blit

.forward

	; SRCPTR = MEM + SrcX * BPP + SrcY * BPR
	movea.l	a1,a2
	mulu.w	d7,d0	; BPP * SrcX
	adda.l	d0,a2
	mulu.w	d6,d1	; BPR * SrcY
	adda.l	d1,a2

	; DSTPTR = MEM + DstX * BPP + DstY * BPR
	movea.l	a1,a3
	mulu.w	d7,d2	; BPP * DstX
	adda.l	d2,a3
	mulu.w	d6,d3	; BPR * DstY
	adda.l	d3,a3

	;calculate modulo MOD = BPR - W * BPP
	mulu.w	d4,d7
	sub.l	d7,d6

	move.w	#0,VBE_CONTROL(a0)

.blit
	move.l	a2,VBE_SRCPTR(a0)
	move.l	a3,VBE_DSTPTR(a0)
	move.l	d6,VBE_SRCMOD(a0)
	move.l	d6,VBE_DSTMOD(a0)
	move.w	d7,VBE_SIZEX(a0)
	move.w	d5,VBE_SIZEY(a0)

.wait:
	move.w	VBE_STATUS(a0),d0
	bmi	.wait

.exit
	movem.l	(sp)+,d2-d7/a2/a3
	rts

;------------------------------------------------------------------------------
	GetBytesPerPixel:
;------------------------------------------------------------------------------

	move.b	.BytesPerPixel(pc,d7.l),d7
	rts

.BytesPerPixel:

	dc.b	1	; RGBFB_NONE
	dc.b	1	; RGBFB_CLUT,
	dc.b	3	; RGBFB_R8G8B8
	dc.b	3	; RGBFB_B8G8R8
	dc.b	2	; RGBFB_R5G6B5PC
	dc.b	2	; RGBFB_R5G5B5PC
	dc.b	4	; RGBFB_A8R8G8B8
	dc.b	4	; RGBFB_A8B8G8R8
	dc.b	4	; RGBFB_R8G8B8A8
	dc.b	4	; RGBFB_B8G8R8A8
	dc.b	2	; RGBFB_R5G6B5
	dc.b	2	; RGBFB_R5G5B5
	dc.b	2	; RGBFB_B5G6R5PC
	dc.b	2	; RGBFB_B5G5R5PC
	dc.b	2	; RGBFB_Y4U2V2
	dc.b	1	; RGBFB_Y4U1V1

;------------------------------------------------------------------------------
	WaitBlitter:
;------------------------------------------------------------------------------

;	BUG "WaitBlitter()"

	movea.l	PSSO_BoardInfo_RegisterBase(a0),a0
.wait:
	move.w	VBE_STATUS(a0),d0
	bmi	.wait

	rts

;==============================================================================

ProgEnd:
	end
