;
; WWW.FPGAArcade.COM
;
; REPLAY Retro Gaming Platform
; No Emulation No Compromise
;
; battclock.resource - Replacement RTC device driver for the REPLAY 68060 daughterboard
; Copyright (C) FPGAArcade community
;
; Contributors : Erik Hemming
;
; This software is licensed under LPGLv2.1 ; see LICENSE file
;
;

kprintf	MACRO
	IFD	ENABLE_KPRINTF
	cmp.l	#$baadc0de,0.l		; kludge to dynamically enable/disable printf's
	bne.b	.skip\@

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
	ENDC
	ENDM

	IFD	ENABLE_KPRINTF
	bra.b	_kprintf_end
_kprintf:	movem.l	d0-d1/a0-a3/a6,-(sp)	
		move.l	$4.w,a6
		move.l	28(sp),a0
		lea	32(sp),a1
		lea	.putch(pc),a2
		move.l	a6,a3
		jsr	-522(a6)		; _LVORawDoFmt

		move.l	28(sp),a0
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
_kprintf_end:
	ENDC

