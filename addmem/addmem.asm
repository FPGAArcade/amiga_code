
MC_SIZE         equ    $00000008
LN_NAME         equ    $0000000A
_LVOAddMemList  equ    -$0000026A
tv_UserIntVects equ    $00000100
MEMHF_RECYCLE   equ    $00000001
MEMF_PUBLIC     equ    $00000001
MEMB_NO_EXPUNGE equ    $0000001F
ME_SIZE         equ    $00000008
MEM_TRY_AGAIN   equ    $00000001
MEMF_FAST       equ    $00000004
memh_Flags      equ    $00000008
MEM_BLOCKSIZE   equ    $00000008
_LVOAllocMem    equ    -$000000C6
MEMF_LOCAL      equ    $00000100
_LVOTypeOfMem   equ    -$00000216
MEMF_REPLAY     equ    (1<<14)

	jmp	ProgStart

	section	data,data_p

	AUTO	wo C:AddReplayMem\

; 1.3 - Label the memory region as REPLAY memory (unused bit 14)
; 1.2 - Probe the memory region to see if it's already been added (using exec.library/TypeOfMem())
; 1.1 - Detect 24 bit (000/010/EC020) memory space (by detecting mirroring of CHIP above the 16M barrier)
; 1.0 - Probe memory to make sure it's actually present

	dc.b	0,'$VER: AddReplayMem 1.3 (30.01.2018)',0

****************************************************************************
	section	code,code_p

ProgStart

	; Check if already registered
	movea.l	$4.w,a6
	lea	$01001000,a1
	jsr	_LVOTypeOfMem(a6)
	tst.l	d0
	bne.w	.quit
	

	; determine 24/32 bit address bus
	; check mirroring of CHIP above 16M...
	lea	chip,a0

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
	dbne.b	d7,.cmp

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

	neg.b	d4
	cmp.b	#32,d4
	bne.b	.quit

	; Probe the memory to see if it's there
	lea	$01000000,a0
	moveq.l	#$30-1,d7
.probe	movem.l	d0-d3,(a0)
	lea	$4000(a0),a1
	movem.l	$4.w,a2-a5
	movem.l	a2-a5,(a1)
	move.l	a0,a1
	cmp.l	(a1)+,d0
	bne.b	.quit
	cmp.l	(a1)+,d1
	bne.b	.quit
	cmp.l	(a1)+,d2
	bne.b	.quit
	cmp.l	(a1)+,d3
	bne.b	.quit
	add.l	#$00100000,a0
	dbf	d7,.probe

	moveq.l	#name_end-name,d0
	moveq.l	#0,d1
	jsr	_LVOAllocMem(a6)  ; allocated memory to hold the name for the memlist
	tst.l	d0
	beq.b	.quit

	movea.l	d0,a1
	lea	name(pc),a0
	moveq.l	#name_end-name,d1
.copy	move.b	(a0)+,(a1)+
	dbra.b	d1,.copy

	movea.l	d0,a1            ; this is the pointer to the name
	move.l	#$03000000,d0    ; this is the size of memory to add
	move.l	#(MEMF_PUBLIC|MEMF_FAST|MEMF_REPLAY),d1
	move.l	#20,d2           ; this is the memory priority
	movea.l	#$01000000,a0    ; this is the start of memory we are adding
	jsr	_LVOAddMemList(a6)

.quit       
	moveq.l	#0,d0
	rts

name		dc.b 'replay xram memory',0
name_end

	section	chip,bss_c
chip		ds.b	16

    end

