;./vasmm68k_mot -Fhunkexe -align -nosym battclock.s -o battclock.resource -I ~/Documents/amiga-root/SYS/Code/NDK_3.9/Include/include_i

	section	BattClock,code_p

;ENABLE_KPRINTF

	include	"exec/types.i"
	include	"exec/libraries.i"
	include	"exec/semaphores.i"

	include	"exec/ables.i"
	include	"exec/resident.i"
	include	"exec/initializers.i"
	include	"utility/date.i"

	include	"lvo/exec_lib.i"
	include	"lvo/utility_lib.i"

BATTCLOCKNAME	MACRO
		dc.b	'battclock.resource',0
		even
		ENDM

VERSION		EQU	99
REVISION	EQU	1
DATE	MACRO
		dc.b	'9.12.2018'
	ENDM
VERS	MACRO
		dc.b	'battclock 99.1'
	ENDM
VSTRING	MACRO
		dc.b	'battclock 99.1 (9.12.2018) Replay RTC/NVM',13,10,0
	ENDM
VERSTAG	MACRO
		dc.b	0,'$VER: battclock 99.1 (9.12.2018) Replay RTC/NVM',0
	ENDM

_intena      EQU   $dff09a

*--------------------------------------------------------------------

 STRUCTURE BattClockResource,LIB_SIZE
	APTR	BTC_Exec
	APTR	BTC_UtilLib

	STRUCT	BTC_Semaphore,SS_SIZE

	LABEL	BTC_SIZE

*--------------------------------------------------------------------

	INCLUDE 'kprintf.i'

 ; test code
 IFD ENABLE_KPRINTF
	include "lvo/battclock_lib.i"
	include "lvo/battmem_lib.i"
TEST

	kprintf "battclock loaded"

	move.l	$4.w,a6
	bsr	InitResource

	tst.l	d0
	beq.w	OUT

	movea.l	d0,a2

	move.l	BTC_UtilLib(a2),a1
	move.l	BTC_Exec(a2),a6
	jsr	_LVOCloseLibrary(a6)


	move.l	4.w,a6
	lea	BattClockName(pc),a1
	jsr	_LVOOpenResource(a6)
	tst.l	d0
	beq.b	.error

	move.l	d0,a6

	jsr	_LVOReadBattClock(a6)

;	move.l	#$12345678,d0
;
;	jsr	_LVOWriteBattClock(a6)
;
;	jsr	_LVOResetBattClock(a6)


	lea	BattMemName(pc),a4
	moveq.l	#0,d4

.copymem
	move.l	d4,d1
	asl.w	#3,d1
	moveq.l	#8,d2

	move.b	(a4)+,d0
	jsr	_LVOWriteBattClock-12(a6)

	addq.l	#1,d4
	cmp.w	#55,d4
	bne.b	.copymem



	move.l	4.w,a6
	lea	BattMemName(pc),a1
	jsr	_LVOOpenResource(a6)
	tst.l	d0
	beq.b	.error

	move.l	d0,a6

	jsr	_LVOObtainBattSemaphore(a6)

	lea	membuffer(pc),a0
	moveq.l	#0,d0
	move.l	#8*55,d1
	jsr	_LVOReadBattMem(a6)

;	lea	buffer(pc),a0
;	moveq.l	#0,d0
;	move.l	#8*55,d1
;	jsr	_LVOWriteBattMem(a6)

	jsr	_LVOReleaseBattSemaphore(a6)

.error
	bra.b	OUT

membuffer:	dc.b	56
BattMemName	dc.b	'battmem.resource',0

	even
 ; end test code

OUT
 ENDC

S:	moveq.l	#-1,d0
	rts

	VERSTAG
	even

RomTag:		     		;STRUCTURE RT,0
	dc.w	RTC_MATCHWORD	; UWORD RT_MATCHWORD
	dc.l	RomTag		; APTR  RT_MATCHTAG
	dc.l	BattClockEnd	; APTR  RT_ENDSKIP
	dc.b	RTF_COLDSTART	; UBYTE RT_FLAGS
	dc.b	VERSION		; UBYTE RT_VERSION
	dc.b	NT_RESOURCE	; UBYTE RT_TYPE
	dc.b	70		; BYTE  RT_PRI
	dc.l	BattClockName	; APTR  RT_NAME
	dc.l	VERSTRING	; APTR  RT_IDSTRING
	dc.l	InitResource	; APTR  RT_INIT
				; LABEL RT_SIZE

BattClockName:
		BATTCLOCKNAME

UtilityLibrary:	dc.b	'utility.library',0

VERSTRING:	VSTRING

	even

SSPBDAT	equ	$dd0058
I2C_RTC	equ	$d0

	BITDEF	I2C,READ,0
	BITDEF	I2C,ACK,8
	BITDEF	I2C,STOP,9
	BITDEF	I2C,START,10
	BITDEF	I2C,BUSY,15

; d0 = bytes processed
; d1 = loop counter
; d2 = temp
; d6 = result
; d7 = loop
; a1 = sspbdat

; a0.l = buffer
; d0.w = offset
; d1.w = length
; 
; d0.w = bytes read (negative if error)

i2c_read:
	DISABLE	a1
	movem.l	d2/d6/d7,-(sp)

	tst.w	d1
	beq.b	.zero

	lea	SSPBDAT,a1

	move.w	#I2CF_START|I2C_RTC,(a1)
	bsr.b	i2c_wait
	beq.b	.error
	btst	#I2CB_ACK,d6
	beq.b	.error

	and.w	#$ff,d0
	move.w	d0,(a1)
	bsr.b	i2c_wait
	beq.b	.error
	btst	#I2CB_ACK,d6
	beq.b	.error

	move.w	#I2CF_START|I2C_RTC|I2CF_READ,(a1)
	bsr.b	i2c_wait
	beq.b	.error
	btst	#I2CB_ACK,d6
	beq.b	.error

	move.w	#I2CF_ACK|$ff,d2
.zero	moveq.l	#0,d0

	bra.b	.cont

.loop	move.w	d2,(a1)

	bsr.b	i2c_wait
	beq.b	.error
;	btst	#I2CB_ACK,d6
;	bne.b	.error

	move.b	d6,(a0)+
	addq.l	#1,d0

.cont	subq.w	#1,d1
	bmi.b	.done
	bne.b	.loop
	move.w	#I2CF_STOP|$ff,d2
	bra.b	.loop

.error	moveq.l	#-1,d0

.done	ENABLE	a1
	tst.l	d0
	movem.l	(sp)+,d2/d6/d7
	rts


i2c_wait:
	move.w	#1024,d7
.busy	btst	#1,$bfe001
	move.w	(a1),d6
	btst	#I2CB_BUSY,d6
	dbeq	d7,.busy
	cmp.w	#$ffff,d7
	rts


; a0.l = buffer
; d0.w = offset
; d1.w = length
; 
; d0 = bytes written (negative if error)

i2c_write:
	DISABLE	a1
	movem.l	d2/d6/d7,-(sp)

	tst.w	d1
	beq.b	.zero

	lea	SSPBDAT,a1

	move.w	#I2CF_START|I2C_RTC,(a1)

	bsr.b	i2c_wait
	beq.b	.error
	btst	#I2CB_ACK,d6
	beq.b	.error

	and.w	#$ff,d0
	move.w	d0,(a1)

	bsr.b	i2c_wait
	beq.b	.error
	btst	#I2CB_ACK,d6
	beq.b	.error

	moveq.l	#0,d2
.zero	moveq.l	#0,d0

	bra.b	.cont

.loop	move.b	(a0)+,d2
	move.w	d2,(a1)

	bsr.b	i2c_wait
	beq.b	.error
	btst	#I2CB_ACK,d6
	beq.b	.error

	addq.l	#1,d0

.cont	subq.w	#1,d1
	bmi.b	.done
	bne.b	.loop
	move.w	#I2CF_STOP,d2
	bra.b	.loop

.error	moveq.l	#-1,d0

.done	ENABLE	a1
	tst.l	d0
	movem.l	(sp)+,d2/d6/d7
	rts

RtcSize = 8	; 8 registers

NvBuffSize	equ	128	; must be even
NvMemSize	equ	56
NvBitSize	equ	((NvMemSize-1)*8)	; 55*8

RtcRead:
	kprintf	"ReadBattClockRtc"


	movem.l	d2/a2,-(sp)
	lea	-RtcSize-CD_SIZE(sp),sp	; need temp

	moveq.l	#0,d0
	moveq.l	#RtcSize,d1	
	move.l	sp,a0
	bsr.w	i2c_read

	move.l	sp,a1		; Rtc data
	lea	RtcSize(a1),a2	; ClockData struct

	exg.l	a1,a2

	moveq.l	#10,d1

	bsr	.Bcd2Bin
	move.w	d0,sec(a1)

	bsr	.Bcd2Bin
	move.w	d0,min(a1)

	bsr	.Bcd2Bin
	move.w	d0,hour(a1)

	moveq.l	#0,d0
	move.b	(a2)+,d0
	subq.w	#1,d0
	move.w	d0,wday(a1)

	bsr	.Bcd2Bin
	move.w	d0,mday(a1)

	bsr	.Bcd2Bin
	move.w	d0,month(a1)

	bsr	.Bcd2Bin
	add.w	#1900,d0
	cmp.w	#1978,d0
	bcc.s	.pre2k
	add.w	#100,d0

.pre2k
	move.w	d0,year(a1)


	lea	RtcSize(sp),sp
	move.l	a1,a0
	LINKLIB	_LVOCheckDate,BTC_UtilLib(a6)
	tst.l	d0
	bne	.ok

	bsr	RtcReset
	moveq.l	#0,d0
.ok	lea	CD_SIZE(sp),sp
	movem.l	(sp)+,d2/a2
	rts


.Bcd2Bin:
	moveq.l	#0,d0
	move.b	(a2)+,d0
	ror.l	#4,d0
	move.l	d0,d2
	swap	d2
	rol.w	#4,d2
	mulu.w	d1,d0
	add.w	d2,d0
	rts

RtcReset:
	kprintf	"ResetBattClockRtc"

	moveq.l	#0,d0

	; fall through

RtcWrite:
	kprintf	"WriteBattClockRtc %lx",d0

	movem.l	a2/a6,-(sp)
	lea	-RtcSize-CD_SIZE(sp),sp
	move.l	sp,a2
	move.l	a0,-(sp)
	lea	RtcSize(a2),a0
	move.l	BTC_UtilLib(a6),a6
	jsr	_LVOAmiga2Date(a6)

	lea	RtcSize(a2),a1
	move.l	(sp)+,a0	; not needed?


	moveq.l	#10,d1

	moveq.l	#0,d0
	move.w	sec(a1),d0
	bsr	.Bin2Bcd

	moveq.l	#0,d0
	move.w	min(a1),d0
	bsr	.Bin2Bcd

	moveq.l	#0,d0
	move.w	hour(a1),d0
	bsr	.Bin2Bcd

	moveq.l	#0,d0
	move.w	wday(a1),d0
	addq.w	#1,d0			; day 1-7 / wday 0-6
	move.b	d0,(a2)+

	moveq.l	#0,d0
	move.w	mday(a1),d0
	bsr	.Bin2Bcd

	moveq.l	#0,d0
	move.w	month(a1),d0
	bsr	.Bin2Bcd

	moveq.l	#0,d0
	move.w	year(a1),d0
	sub.w	#1900,d0
	cmp.w	#100,d0
	ble.b	.yok
	sub.w	#100,d0
.yok	bsr	.Bin2Bcd
	

	move.b	#$9F,(a2)+

	moveq.l	#0,d0
	moveq.l	#RtcSize,d1	
	move.l	sp,a0
	bsr.w	i2c_write

	bpl.b	.write_ok

	nop
	kprintf	"error writing time"

.write_ok

	lea	CD_SIZE+RtcSize(sp),sp
	movem.l	(sp)+,a2/a6
	rts


.Bin2Bcd:
	divu.w	d1,d0
	swap	d0
	ror.w	#4,d0
	swap	d0
	rol.l	#4,d0
	move.b	d0,(a2)+
	rts

NvRead
	kprintf	"ReadNonVolatile"

	move.l	a1,-(sp)
	bsr.w	.NvGetMem
	move.l	(sp)+,a1
	movem.l	a0/a1,-(sp)
	move.l	a1,a0
	moveq.l	#-1,d0
	moveq.l	#NvMemSize-1,d1
	bsr	CalcCRC8
	movem.l	(sp)+,a0/a1
	kprintf	"NonVolatile CRC8 = %lx",d0
	cmp.b	NvMemSize-1(a1),d0
	beq.s	.CRCok

	kprintf	"CRC8 failed - was %lx",(NvMemSize-1)(a1)

	moveq.l	#NvMemSize-1,d0
	move.l	a1,d1
.clear	clr.b	(a1)+
	dbf	d0,.clear
	move.l	d1,a1
	bsr.s	NvWrite
.CRCok
	rts


.NvGetMem:

	moveq.l	#RtcSize,d0
	moveq.l	#NvMemSize,d1	
	move.l	a1,a0
	bsr.w	i2c_read

	rts

NvWrite
	kprintf	"WriteNonVolatile"

	movem.l	a0/a1,-(sp)
	moveq.l	#-1,d0
	move.l	a1,a0
	moveq.l	#NvMemSize-1,d1
	bsr.s	CalcCRC8
	kprintf	"NonVolatile CRC8 = %lx",d0
	movem.l	(sp)+,a0/a1
	move.b	d0,NvMemSize-1(a1)
	move.l	a1,-(sp)
	bsr.s	.NvPutMem
	move.l	(sp)+,a1
	rts

.NvPutMem:

	moveq.l	#RtcSize,d0
	moveq.l	#NvMemSize,d1	
	move.l	a1,a0
	bsr.w	i2c_write

	rts


;; Based on Kickstart 3.1 : battclock.resource 39.3

CalcCRC8:
	move.l	d2,-(sp)
	lea	.CRCTable,a1
	move.l	d1,d2
	bra.s	.CC8le
.CC8ls
	move.b	(a0),d1
	bsr.s	.DivNibble
	move.b	(a0)+,d1
	asl.b	#4,d1
	bsr.s	.DivNibble
.CC8le	dbf	d2,.CC8ls

	move.l	(sp)+,d2
	rts


.DivNibble:
	and.b	#$f0,d1
	eor.b	d0,d1
	ror.b	#4,d1
	move.b	d1,d0
	and.b	#$f0,d0
	and.w	#$f,d1
	move.b	0(a1,d1.w),d1
	eor.b	d1,d0
	rts

.CRCTable:
	dc.b	$00,$57,$ae,$f9
	dc.b	$0b,$5c,$a5,$f2
	dc.b	$16,$41,$b8,$7f
	dc.b	$1d,$4a,$b3,$e4


*------ Functions Offsets -------------------------------------

V_DEF	MACRO
	dc.w	(\1-initFunc)
	ENDM

initFunc:
	dc.w	-1
	V_DEF	ResetBattClock
	V_DEF	ReadBattClock
	V_DEF	WriteBattClock
	V_DEF	ReadBattMem
	V_DEF	WriteBattMem
	V_DEF	NoOp
	dc.w	-1

*------ Initializaton Table -----------------------------------

initStruct:
	INITBYTE	LN_TYPE,NT_RESOURCE
	INITLONG	LN_NAME,BattClockName
	INITBYTE	LIB_FLAGS,LIBF_SUMUSED!LIBF_CHANGED
	INITWORD	LIB_VERSION,VERSION
	INITWORD	LIB_REVISION,REVISION
	INITLONG	LIB_IDSTRING,VERSTRING

	DC.L		0

InitResource:
	movem.l	a2/a3/a6,-(sp)
	move.l	#0,a2		; for no resource case

	moveq.l	#36,d0
	lea	UtilityLibrary(pc),a1
	jsr	_LVOOpenLibrary(a6)
	tst.l	d0
	beq.w	.InitEnd
	move.l	d0,a3		; utilityLib base

	kprintf	"UtilityLib base = $%lx",a3

	lea	BattClockName(pc),a1
	jsr	_LVOOpenResource(a6)
	tst.l	d0
	beq.b	.NoOldRes
	movea.l	d0,a1
	kprintf	"Old battclock.resource at $%lx removed",a1
	jsr	_LVORemResource(a6)
.NoOldRes	


	lea	initFunc(pc),a0
	lea	initStruct,a1
	suba.l	a2,a2
	move.l	#BTC_SIZE,d0
	jsr	_LVOMakeLibrary(a6)
	move.l	d0,a2
	tst.l	d0
	beq.w	.MakeLibFailed

	move.l	a6,BTC_Exec(a2)
	move.l	a3,BTC_UtilLib(a2)

	lea	BTC_Semaphore(a2),a0
	jsr	_LVOInitSemaphore(a6)
	move.l	a2,a1
	jsr	_LVOAddResource(a6)
	move.l	a2,a6
	bra.b	.ResourceMade

.MakeLibFailed:
	move.l	a3,a1
	jsr	_LVOCloseLibrary(a6)
	move.l	(sp)+,d0
	bra	.InitEnd


.ResourceMade
	bsr	RtcRead

.InitEnd:
	move.l	a2,d0		; battclockbase or NULL
	movem.l	(sp)+,a2/a3/a6
	rts


NoOp:
	kprintf	"RtcNop"
	moveq.l	#0,d0
	rts


ResetBattClock:
	lea	BTC_Semaphore(a6),a0
	LINKLIB	_LVOObtainSemaphore,BTC_Exec(A6)

	bsr	RtcReset

	lea	BTC_Semaphore(a6),a0
	LINKLIB	_LVOReleaseSemaphore,BTC_Exec(A6)
	rts


ReadBattClock:
	lea	BTC_Semaphore(a6),a0
	LINKLIB	_LVOObtainSemaphore,BTC_Exec(A6)

	bsr	RtcRead

	move.l	d0,-(sp)
	lea	BTC_Semaphore(a6),a0
	LINKLIB	_LVOReleaseSemaphore,BTC_Exec(A6)
	move.l	(sp)+,d0

	rts


WriteBattClock:
	move.l	d0,-(sp)
	lea	BTC_Semaphore(a6),a0
	LINKLIB	_LVOObtainSemaphore,BTC_Exec(A6)
	move.l	(sp)+,d0

	bsr	RtcWrite

	lea	BTC_Semaphore(a6),a0
	LINKLIB	_LVOReleaseSemaphore,BTC_Exec(A6)
	rts


ReadBattMem:
	movem.l	d1-d4,-(sp)
	move.l	d1,d4

	lea	BTC_Semaphore(a6),a0
	LINKLIB	_LVOObtainSemaphore,BTC_Exec(A6)

	moveq.l	#0,d0
	move.l	d0,-(sp)
	lea	-NvBuffSize(sp),sp
	move.l	sp,a1
	bsr	NvRead
	move.l	d4,d1
	moveq.l	#0,d0
	move.b	d0,NvMemSize-1(a1)
	move.b	d0,NvMemSize+0(a1)
	move.b	d0,NvMemSize+1(a1)
	move.b	d0,NvMemSize+2(a1)

	tst.l	d2
	beq.s	.exit
	cmp.l	#32,d2
	bls.s	.LenOk1
	moveq.l	#32,d2
.LenOk1
	moveq.l	#0,d0
	move.l	#NvBitSize,d3
	sub.l	d1,d3
	bls.s	.exit

	moveq.l	#-1,d3
	lsr.l	d2,d3
	not.l	d3

	move.l	d1,d4
	asr.l	#3,d1
	add.l	d1,a1
	and.l	#7,d4
	beq.s	.NoRot1
	ror.l	d4,d3
.NoRot1

	moveq.l	#3,d1
.ReadLoop
	rol.l	#8,d0
	move.b	(a1)+,d0
	dbf	d1,.ReadLoop

	and.l	d3,d0
	tst.l	d4
	beq.s	.NoRot2
	rol.l	d4,d0
.NoRot2

	rol.l	d2,d0

.exit	move.l	d0,d3
	lea	NvBuffSize(sp),sp

	move.l	(sp)+,d0
	lea	BTC_Semaphore(a6),a0
	LINKLIB	_LVOReleaseSemaphore,BTC_Exec(A6)
	move.l	d3,d0

	movem.l	(sp)+,d1-d4

	kprintf	"ReadBattMemRtc %lx = %lx / %lx",d0,d1,d2
	rts


WriteBattMem:
	kprintf	"WriteBattMemRtc %lx = %lx / %lx",d0,d1,d2
	movem.l	d2-d4,-(sp)
	move.l	d0,d3
	move.l	d1,d4

	lea	BTC_Semaphore(a6),a0
	LINKLIB	_LVOObtainSemaphore,BTC_Exec(A6)

	move.l	d0,-(sp)
	lea	-NvBuffSize(sp),sp
	move.l	sp,a1
	bsr.w	NvRead
	move.l	d3,d0
	move.l	d4,d1

	move.l	a1,-(sp)

	cmp.l	#32,d2
	bls.s	.LenOk1
	moveq.l	#32,d2
.LenOk1
	move.l	#NvBitSize,d3
	sub.l	d1,d3
	bls.s	.exit
	move.l	d2,d4
	sub.l	d3,d4
	bls.s	.LenOk2
	move.l	d3,d2
	asr.l	d4,d0
.LenOk2
	tst.l	d2
	beq.s	.exit

	moveq.l	#-1,d3
	asl.l	d2,d3
	not.l	d3
	and.l	d3,d0
	not.l	d3

	ror.l	d2,d0
	ror.l	d2,d3

	move.l	d1,d4
	asr.l	#3,d1
	add.l	d1,a1
	move.l	d4,d1
	and.l	#7,d1
	beq.s	.NoRot
	ror.l	d1,d0
	ror.l	d1,d3
.NoRot

	moveq.l	#3,d1
.WriteLoop
	rol.l	#8,d0
	rol.l	#8,d3
	and.b	d3,(a1)
	or.b	d0,(a1)+
	dbf	d1,.WriteLoop

	move.l	(sp)+,a1
	bsr	NvWrite

.exit	lea	NvBuffSize(sp),sp

	move.l	(sp)+,d0
	lea	BTC_Semaphore(a6),a0
	LINKLIB	_LVOReleaseSemaphore,BTC_Exec(A6)

	movem.l	(sp)+,d2-d4
	rts


BattClockEnd:
	end
