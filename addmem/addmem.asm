;
; WWW.FPGAArcade.COM
;
; REPLAY Retro Gaming Platform
; No Emulation No Compromise
;
; AddReplayMem - Memory configuration tool for the REPLAY Amiga core
; Copyright (C) FPGAArcade community
;
; Contributors : Mike Johnson, Jim Drew, Erik Hemming
;
; This software is licensed under LPGLv2.1 ; see LICENSE file
;
;

; vasmm68k_mot -Fhunkexe -kick1hunks addmem.asm -L addmem.list -nosym -m68000 -o AddReplayMem -I ~/Documents/amiga-root/SYS/Code/NDK_3.9/Include/include_i

	include	exec/nodes.i
	include	exec/resident.i

_LVOAllocMem    equ	-198
_LVOFreeMem     equ	-210
_LVOTypeOfMem   equ	-534
_LVOAddMemList  equ	-618
_LVOOpenLibrary equ	-552
_LVOCloseLibrary equ	-414
_LVOPutStr      equ	-948
MEMF_PUBLIC     equ    (1<<0)
MEMF_CHIP       equ    (1<<1)
MEMF_FAST       equ    (1<<2)
MEMF_REPLAY     equ    (1<<14)

	jmp	S
	moveq.l	#-1,d0
	rts

VERSION	= 1
REVISION= 5

	dc.b	0,'$VER: AddReplayMem 1.5 (20.9.2018) Replay XRAM',0
VERSTRING	dc.b	'AddReplayMem 1.5 (20.9.2018) Replay XRAM',13,10,0
	even
	
romtag:	dc.w	RTC_MATCHWORD
	dc.l	romtag
	dc.l	end
	dc.b	RTF_COLDSTART
	dc.b	VERSION
	dc.b	NT_UNKNOWN
	dc.b	0
	dc.l	tagname
	dc.l	VERSTRING
	dc.l	S

tagname:	dc.b	'AddReplayMem',0
	even
	
S:
	movem.l	d2-d6/a2-a6,-(sp)

; 1.5 - Make ROMable
; 1.4 - Add console logging; Fix building with vasm.
; 1.3 - Label the memory region as REPLAY memory (unused bit 14)
; 1.2 - Probe the memory region to see if it's already been added (using exec.library/TypeOfMem())
; 1.1 - Detect 24 bit (000/010/EC020) memory space (by detecting mirroring of CHIP above the 16M barrier)
; 1.0 - Probe memory to make sure it's actually present

	; Check if already registered
	movea.l	$4.w,a6
	lea	$01001000,a1
	jsr	_LVOTypeOfMem(a6)
	tst.l	d0
	bne.w	.quit_present
	
	; determine 24/32 bit address bus
	; check mirroring of CHIP above 16M...

	moveq.l	#16,d0
	moveq.l	#MEMF_CHIP,d1
	jsr	_LVOAllocMem(a6)
	tst.l	d0
	beq.w	.quit_alloc

	move.l	d0,a0

	move.l	#$DEADCE11,d0
	move.l	#$ABADC0DE,d1
	move.l	#$BEEFBABE,d2
	move.l	#$B007FEE7,d3

	moveq.l	#$0,d4
	
	moveq.l	#2-1,d5
.again	movem.l	d0-d3,(a0)
	move.l	a0,a1
	add.l	#$01000000,a1
	moveq.l	#$10-1,d6
.next	add.l	#$00100000,a1
	move.l	a0,a2
	move.l	a1,a3
	moveq.l	#4-1,d7
.cmp	cmpm.l	(a2)+,(a3)+
	dbne	d7,.cmp

	tst.w	d7
	spl	d7
	add.b	d7,d4

	dbf	d6,.next
	
	eor.w	d0,d1
	eor.w	d1,d0
	eor.w	d0,d1
	
	eor.w	d2,d3
	eor.w	d3,d2
	eor.w	d2,d3

	dbf	d5,.again

	move.l	a0,a1
	moveq.l	#16,d0
	jsr	_LVOFreeMem(a6)	

	neg.b	d4
	cmp.b	#32,d4
	bne.b	.quit_24bit

	; Probe the memory to see if it's there
	lea	$01000000,a0
	moveq.l	#$30-1,d7
.probe	movem.l	d0-d3,(a0)
	lea	$4000(a0),a1
	movem.l	$4.w,a2-a5
	movem.l	a2-a5,(a1)
	move.l	a0,a1
	cmp.l	(a1)+,d0
	bne.b	.quit_probing
	cmp.l	(a1)+,d1
	bne.b	.quit_probing
	cmp.l	(a1)+,d2
	bne.b	.quit_probing
	cmp.l	(a1)+,d3
	bne.b	.quit_probing
	add.l	#$00100000,a0
	dbf	d7,.probe

	moveq.l	#name_end-name,d0
	moveq.l	#0,d1
	jsr	_LVOAllocMem(a6)  ; allocated memory to hold the name for the memlist
	tst.l	d0
	beq.b	.quit_alloc

	movea.l	d0,a1
	lea	name(pc),a0
	moveq.l	#name_end-name,d1
.copy	move.b	(a0)+,(a1)+
	dbf	d1,.copy

	movea.l	d0,a1            ; this is the pointer to the name
	move.l	#$03000000,d0    ; this is the size of memory to add
	move.l	#(MEMF_PUBLIC|MEMF_FAST|MEMF_REPLAY),d1
	move.l	#20,d2           ; this is the memory priority
	movea.l	#$01000000,a0    ; this is the start of memory we are adding
	jsr	_LVOAddMemList(a6)

	lea	memory_added(pc),a5
	bra.b	.quit

.quit_present	lea	already_there(pc),a5
		bra.b	.quit
.quit_24bit	lea	cpu_is_24bit(pc),a5
		bra.b	.quit
.quit_probing	lea	probing_failed(pc),a5
		bra.b	.quit
.quit_alloc	lea	alloc_failed(pc),a5

.quit	lea	dos(pc),a1
	moveq.l	#36,d0		; putstr is kick 2.x+
	movea.l	$4.w,a6
	jsr	_LVOOpenLibrary(a6)
	tst.l	d0
	beq.w	.nodos

	move.l	d0,a6
	move.l	a5,d1
	jsr	_LVOPutStr(a6)

	movea.l	a6,a1
	movea.l	$4.w,a6
	jsr	_LVOCloseLibrary(a6)

.nodos
	movem.l	(sp)+,d2-d6/a2-a6
	moveq.l	#0,d0
	rts

name		dc.b 'replay xram memory',0
name_end
dos		dc.b 'dos.library',0
already_there	dc.b 'memory is already available',10,0
cpu_is_24bit	dc.b 'cpu uses a 24bit address bus (68000/010/EC020)',10,0
probing_failed	dc.b 'memory probing failed',10,0
alloc_failed	dc.b 'memory allocation failed',10,0
memory_added	dc.b 'memory region added',10,0

end

