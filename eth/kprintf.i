;
; WWW.FPGAArcade.COM
;
; REPLAY Retro Gaming Platform
; No Emulation No Compromise
;
; repleyeth.device - SANAII device driver for the REPLAY 68060 daughterboard
; Copyright (C) Erik Hemming
;
; This software is licensed under LPGLv2.1 ; see LICENSE file
;
;

kprintf	MACRO
	IFD	ENABLE_KPRINTF
;	cmp.l	#$baadc0de,0.l		; kludge to dynamically enable/disable printf's
;	bne.b	.skip\@

	ifnc	"","\9"
		move.l  \9,-(sp)
	endc
	ifnc	"","\8"
		move.l  \8,-(sp)
	endc
	ifnc	"","\7"
		move.l  \7,-(sp)
	endc
	ifnc	"","\6"
		move.l  \6,-(sp)
	endc
	ifnc	"","\5"
		move.l  \5,-(sp)
	endc
	ifnc	"","\4"
		move.l  \4,-(sp)
	endc
	ifnc	"","\3"
		move.l  \3,-(sp)
	endc
	ifnc	"","\2"
		move.l  \2,-(sp)
	endc

	jsr	_kprintf

	dc.b	\1,$d,$a,0
	even

	adda.w	#(NARG-1)*4,sp

.skip\@
	ELSE
	nop
	ENDC
	ENDM

	IFD	ENABLE_KPRINTF
	bra.w	_kprintf_end
_kprintf:	movem.l	d0-d2/a0-a3/a6,-(sp)	
		movea.l	$4.w,a6


		lea	.dos(pc),a1
		moveq.l	#36,d0          ; fputc is kick 2.x+
		jsr	-552(a6)	; _LVOOpenLibrary
		movea.l	d0,a3

		jsr	-120(a6)	; _LVODisable

		move.l	28+4(sp),a0
		lea	32+4(sp),a1
		lea	.putch(pc),a2
;		move.l	a6,a3
		jsr	-522(a6)		; _LVORawDoFmt

		move.l	28+4(sp),a0
.end:		move.b	(a0)+,d0
		bne.b	.end
		move.l	a0,d0
		addq.l	#1,d0
		andi.l	#$fffffffe,d0
		move.l	d0,28+4(sp)

		move.l	a3,a1
		movea.l $4.w,a6

		jsr	-126(a6)	; _LVOEnable

		jsr	-414(a6)	; _LVOCloseLibrary

		movem.l	(sp)+,d0-d2/a0-a3/a6
		rts

.putch:
		move.l	d0,-(sp)
		move.l	a3,d0
		beq.b	.skipdos
		bra.b	.skipdos

		move.l	a3,a6
		jsr	-60(a6)			; _LVOOutput
		move.l	d0,d1
		beq.b	.skipdos

		move.l	(sp),d2
		move.l	d1,-(sp)
		jsr	-312(a6)		; _LVOFPutC

		move.l	(sp)+,d1
		jsr	-360(a6)		; _LVOFlush

.skipdos	move.l	(sp)+,d0

		movea.l	$4.w,a6
		jmp	-516(a6)		; _LVORawPutChar (execPrivate9)

.dos:		dc.b	'dos.library',0
		even

_kprintf_end:
	ENDC

kprintf_reset_color	MACRO
	kprintf	"%c[0m",#$1b<<16
	ENDM
kprintf_red MACRO
	kprintf	"%c[0;31m",#$1b<<16
	ENDM
kprintf_green MACRO
	kprintf	"%c[0;32m",#$1b<<16
	ENDM
kprintf_yellow MACRO
	kprintf	"%c[0;33m",#$1b<<16
	ENDM
