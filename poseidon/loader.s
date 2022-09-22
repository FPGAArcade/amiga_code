;
; WWW.FPGAArcade.COM
;
; REPLAY Retro Gaming Platform
; No Emulation No Compromise
;
; PoseidonLoader - pre-boot loader for a Poseidon USB ROM, located at $03f8.0000 (512KB)
; Copyright (C) Erik Hemming
;
; This software is licensed under LPGLv2.1 ; see LICENSE file
;
;

EXT_ROM_START	= $03f80000
EXT_ROM_END	= $04000000
MAX_ROM_TAGS	= 32

;ENABLE_KPRINTF

	include	exec/exec.i
	include	exec/nodes.i
	include	exec/resident.i
	include	exec/libraries.i
	include lvo/exec_lib.i
	include kprintf.i


	jmp	S
	moveq.l	#-1,d0
	rts

VERSION	= 2
REVISION= 0

	dc.b	0,'$VER: Poseidon ROM Loader 2.0 (19.9.2022) Replay USB',0
	even
VERSTRING	dc.b	'Poseidon ROM Loader 2.0 (19.9.2022) Replay USB',13,10,0
	even

	cnop	0,4
romtag:	dc.w	RTC_MATCHWORD
	dc.l	romtag
	dc.l	end
	dc.b	RTF_SINGLETASK
	dc.b	VERSION
	dc.b	NT_UNKNOWN
	dc.b	106
	dc.l	tagname
	dc.l	VERSTRING
	dc.l	S

tagname:	dc.b	'USB.ROM.init',0
	even
	cnop	0,4
tagname_end:

S:
	kprintf	"INIT: %s",#VERSTRING

	movem.l	d0-a6,-(sp)

	move.l	$4.w,a6

	lea	$40100304,a0		; $4000.0000 (USB/ETH base) + $0010.0000 (MACH_USBREGS) + $0304 (ISP_CHIPID)

	kprintf	<"    Check USB ChipID ... (addr $%08lx, value $%08lx)",10>,a0,(a0)

	cmp.l	#$00011761,(a0)		; $0001.1761 == Valid Chip ID
	bne	.exit

	lea	EXT_ROM_START,a4	; 1MB ROM max
	lea	EXT_ROM_END,a5		; End of DDR

	kprintf	<"    Check ROM @ %08lx ... (%08lx)",10>,a4,(a4)

	cmp.l	#$11144ef9,(a4)
	bne	.exit			; ROM header not found.

	kprintf	"    Validate ROM checksum (%08lx) -> ",(EXT_ROM_END-$18)

	movea.l	a4,a0
	moveq	#0,d4
	moveq	#0,d5
	moveq.l	#(((EXT_ROM_END-EXT_ROM_START)/4)-1)>>16,d6
	moveq.l	#-1,d7

.checksum:
	add.l	(a0)+,d5
	addx.l	d4,d5
	dbf	d7,.checksum
	dbf	d6,.checksum

	kprintf	<"%08lx (should be FFFFFFFF)",10>,d5

	not.l	d5
	bne	.exit			; checksum failed

	kprintf	<"    Current KickMem/KickTag/KickSum = [ %08lx, %08lx, %08x ]",10>,KickMemPtr(a6),KickTagPtr(a6),KickCheckSum(a6)

	CALLLIB	_LVOSumKickData
	cmp.l	KickCheckSum(a6),d0
	bne	.invalid

	kprintf	<"    Search KickMemPtr for %08lx ...",10>,a4

	move.l	KickMemPtr(a6),d2

.next_memlist
	tst.l	d2
	beq	.notfound
	movea.l	d2,a2

	kprintf	<"    Found memlist %08lx (%s)",10>,a2,LN_NAME(a2)

	move.l	LN_SUCC(a2),d2
	lea	ML_NUMENTRIES(a2),a2
	move.w	(a2)+,d7
	bra.b	.findmem_start
.findmem
	kprintf	<"        Entry : addr %08lx, size %08lx",10>,ME_ADDR(a2),ME_LENGTH(a2)
	cmp.l	(a2)+,a4
	beq	.exit
	add.w	#4,a2
.findmem_start
	dbf	d7,.findmem
	bra	.next_memlist


.invalid
	kprintf	<"    KickCheckSum is invalid - clear it",10>

	clr.l	KickMemPtr(a6)
	clr.l	KickTagPtr(a6)

.notfound	

	move.l	#ML_SIZE+ME_SIZE+MAX_ROM_TAGS*4,d0
	kprintf	"    Create KickMemPtr (%ld bytes) ",d0
	suba.l	d0,a5

	lea	(a5),a1				; MemList

	kprintf	<" @ %08lx",10>,a1

	kprintf	<"    Old KickMemPtr(a6) = %08lx",10>,KickMemPtr(a6)

	move.l	KickMemPtr(a6),d0
	move.l	a1,KickMemPtr(a6)

	kprintf	<"    New KickMemPtr(a6) = %08lx",10>,KickMemPtr(a6)

	lea	tagname(pc),a0
	move.l	d0,(a1)+				; LN_SUCC
	clr.l	(a1)+					; LN_PRED
	clr.w	(a1)+					; LN_TYPE + LN_PRI
	move.l	a0,(a1)+				; LN_NAME
	move.w	#1,(a1)+				; ML_NUMENTRIES
	move.l	a4,(a1)+				; ME_ADDR
	move.l	#EXT_ROM_END-EXT_ROM_START,(a1)+	; ME_LENGTH
	move.l	a1,a2

.scan	
	cmp.w	#RTC_MATCHWORD,(a4)+
	bne.b	.cont
	lea	-2(a4),a0
	move.l	(a4)+,d2
	cmp.l	d2,a0
	bne.b	.cont

	move.l	a0,a4

	move.l	a4,(a1)+
	kprintf	"    ROMTAG @ %08lx (end : %08lx) : %s / %s",a4,RT_ENDSKIP(a4),RT_NAME(a4),RT_IDSTRING(a4)

	move.l	RT_ENDSKIP(a4),a4

.cont	cmp.l	a5,a4
	blt.b	.scan

	move.l	KickTagPtr(a6),d0
	beq.b	.notags
	bset	#31,d0
.notags	move.l	d0,(a1)+

	move.l	a2,KickTagPtr(a6)
	kprintf	<"    New KickTagPtr = %08lx",10>,KickTagPtr(a6)

	kprintf	<"    Calculate KickCheckSum ...",10>

	CALLLIB	_LVOSumKickData
	move.l	d0,KickCheckSum(a6)
	kprintf	<"    New KickCheckSum = %08lx",10>,KickCheckSum(a6)

	CALLLIB	_LVOCacheClearU	

	kprintf	<"    CacheFlushed",10>

.exit	kprintf <"DONE!",10>
	movem.l	(sp)+,d0-a6
	rts

end:
