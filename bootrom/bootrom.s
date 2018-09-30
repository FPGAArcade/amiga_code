; ./vasmm68k_mot -Fbin -m68060 bootrom/bootrom.s -o bootrom/bootrom.bin

ROM_MODE = 1

	IFEQ	ROM_MODE
Startup
		lea	Startup(pc),a0
		lea	$dff000,a4
		move.w	#$8000,d0
		move.w	$02(a4),.dmacon-Startup(a0)
		move.w	$1c(a4),.intena-Startup(a0)
		move.w	$1e(a4),.intreq-Startup(a0)
		or.w	d0,.intena-Startup(a0)
		or.w	d0,.intreq-Startup(a0)
		or.w	d0,.dmacon-Startup(a0)

		lea	KICK(pc),a5
		move.l	$4.w,a6
		move.l	$9c(a6),a6
		suba.l	a1,a1
		jsr	-222(a6)
		jsr	-270(a6)	
		jsr	-270(a6)
		move.l	$4.w,a6
		jsr	-30(a6)

		lea	$dff000,a4
		move.w	.dmacon(pc),$96(a4)
		move.w	.intena(pc),$9a(a4)
		move.w	.intreq(pc),$9c(a4)

		move.l	$4.w,a6
		move.l	$9c(a6),a6
		move.l	$26(a6),$80(a4)
		move.w	#0,$88(a4)

		rts

.intena		dc.w	0
.intreq		dc.w	0
.dmacon		dc.w	0

KICK		lea	.stack(pc),a1
		move.l	a7,(a1)
		lea	.E(pc),a5
		lea	ROM_START(pc),a1
		jmp	2(a1)
.E		move.l	.stack(pc),a7
		rte
.stack		dc.l	0
	ELSE

;		rts
;		AUTO	wb fat0:amiga_68060/bootrom.bin\ROM_START\ROM_END\

	ENDC

FADE	MACRO	; op,value,mask
	move.w	d0,d2
	move.w	(a1),d1
	and.w	#\2,d2
	and.w	#\2,d1
	cmp.w	d1,d2
	beq.b	.done\@
	bgt.b	.add\@
	sub.w	#\1,d1
	bra.b	.done\@
.add\@	add.w	#\1,d1
.done\@
	and.w	#~\2,(a1)
	or.w	d1,(a1)
	ENDM


ROM_START
		dc.w $1111	; Magic ROM tag
; ---------------------------------------------------------------------------
		bra.b	S
; ---------------------------------------------------------------------------
		;	 0123456789abcdef
		dc.b	  0, '$VER: replay.rom 1.0 (16.9.2018) '
		dc.b	      'FPGAArcade' 
		dc.b	'  Replay 68060  '
		dc.b	' Bootstrap ROM ',0
		cnop	0,4
; ---------------------------------------------------------------------------
S:
	; Enable CHIP
		lea	$bfe001,a4
		clr.b	(a4)
		move.b	#3,$200(a4)

	; Shut off INT/DMA
		lea	$dff000,a4
		move.w	#$7fff,d0
		move.w	d0,$9a(a4)
		move.w	d0,$9c(a4)
		move.w	d0,$96(a4)

	; Delay...
		move.w	#5000,d1
.delay		dbf	d1,.delay

	; Overwrite 'Illegal Instruction' vector
		movec	VBR,d7
		move.l	d7,a0
		move.l	$10(a0),a6
		lea	IllegalTrap(pc),a1
		move.l	a1,$10(a0)

	; Setup stack (in case we're not running on an 060)
		move.l	#$10000,sp

	; Disable 060 FPU
	IFNE	ROM_MODE
		moveq.l	#2,d0
		movec	d0,pcr
	ENDC

; ---------------------------------------------------------------------------

	; COLOR00 'rainbow'
Rainbow:	move.w	#0,d0
		move.w	#$200,$100(a4)
		move.w	d0,$110(a4)

.loop1:		move.w	d0,$180(a4)
		move.w	#$A,d1
.loop2:		dbf	d1,.loop2
		addi.w	#1,d0
		bcc.b	.loop1

; ---------------------------------------------------------------------------
Display:

	; First restore exception vector
	
		move.l	d7,a0
		move.l	a6,$10(a0)

	; Copy copper and logo to CHIP

		lea	CHIP_START(pc),a0
		movea.l	sp,a1
		movea.l	a1,a3
		move.w	#(CHIP_END-CHIP_START)/16-1,d7
.copy		rept 4
		move.l	(a0)+,(a1)+
		endr
		dbf	d7,.copy


	; Setup bitplane pointers
		move.l	a3,a0
		move.l	a3,d0
		add.l	#(Logo-Copper),d0
		moveq.l	#4-1,d7
.setbpl		move.w	d0,6(a0)
		swap	d0
		move.w	d0,2(a0)
		swap	d0
		add.w	#2002,d0
		add.w	#8,a0
		dbf	d7,.setbpl

	; Enable Copper and Bitplanes
		move.l	a3,$80(a4)
		move.w	#$8380,$96(a4)

NUM_FRAMES = 64
		moveq.l	#0,d7		; d7 = FRAME counter

	; Wait for Top-Of-Frame / first scanline
.waitTOF	move.l	$4(a4),d1
		and.l	#$7ff00,d1
		bne.b	.waitTOF
.waitNext	move.l	$4(a4),d1
		and.l	#$7ff00,d1
		beq.b	.waitNext

	; Fade palette (oldschool n00b non-linear fade!)
		move.l	a3,a1
		adda.w	#(CopCols-Copper)+2,a1
		moveq.l	#16-1,d3
		lea	Colors(pc),a0
		cmp.w	#NUM_FRAMES-16,d7
		ble.b	.setcol
		adda.w	#16*2,a0	; Fade to black
.setcol		move.w	(a0)+,d0	; RGB

		FADE	$001,$00f
		FADE	$010,$0f0
		FADE	$100,$f00

		adda.w	#4,a1
		dbf	d3,.setcol

	; Jump back to the Kickstart (a5) ?
		addq.l	#1,d7
		cmp.w	#NUM_FRAMES,d7
		bne	.waitTOF
		jmp	(a5)
; ---------------------------------------------------------------------------

IllegalTrap:
	; Overwrite PC and return
		lea	Display(pc),a0
		move.l	a0,2(sp)
		rte

; ---------------------------------------------------------------------------

Colors	dc.w	$0000,$0e51,$0fff,$0310
	dc.w	$0b31,$0720,$0d41,$0200
	dc.w	$0888,$0931,$0510,$0bbb
	dc.w	$0555,$0333,$0ddd,$0999
	dc.w	$0000,$0000,$0000,$0000
	dc.w	$0000,$0000,$0000,$0000
	dc.w	$0000,$0000,$0000,$0000
	dc.w	$0000,$0000,$0000,$0000

CHIP_START
Copper:
	dc.w	$00e0,$0000,$00e2,$0000,$00e4,$0000,$00e6,$0000
	dc.w	$00e8,$0000,$00ea,$0000,$00ec,$0000,$00ee,$0000

	dc.w	$008e,$68a0
	dc.w	$0090,$b5a0
	dc.w	$0092,$0050
	dc.w	$0094,$00b0

	dc.w	$0100,$4000
	dc.w	$0102,$00cc
	dc.w	$0108,$0000
	dc.w	$010a,$0000

CopCols:
	dc.w	$0180,$0000,$0182,$0000,$0184,$0000,$0186,$0000
	dc.w	$0188,$0000,$018a,$0000,$018c,$0000,$018e,$0000
	dc.w	$0190,$0000,$0192,$0000,$0194,$0000,$0196,$0000
	dc.w	$0198,$0000,$019a,$0000,$019c,$0000,$019e,$0000	

	dc.w	$01fc,$0000
	dc.w	$ffff,$fffe

Logo:	incbin	replay_200x77.bin
	dcb.b	$2000-(*-CHIP_START),$00
CHIP_END

;	dcb.b	($4000-(*-ROM_START)),$00

ROM_END

