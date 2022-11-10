;
; WWW.FPGAArcade.COM
;
; REPLAY Retro Gaming Platform
; No Emulation No Compromise
;
; usb_eth.autoconfig - ZorroIII config for the REPLAY 68060 daughterboard
; Copyright (C) Erik Hemming
;
; This software is licensed under LPGLv2.1 ; see LICENSE file
;
;

;./vasmm68k_mot  -Fhunkexe addconfig.s -o usb_eth.autoconfig -I ~/Documents/amiga-root/SYS/Code/NDK_3.9/Include/include_i

;ENABLE_KPRINTF

	incdir	include:
	incdir	sys:code/ndk_3.9/include/include_i/

	include	exec/resident.i

	include	libraries/expansion.i
	include	libraries/configvars.i

	include	lvo/exec_lib.i
	include	lvo/expansion_lib.i

	include kprintf.i

	moveq.l	#-1,d0
	rts

VERSION	= 1
REVISION= 0

VERSTRING	dc.b	'usb_eth.autoconfig 1.2 (7.11.2022) ZorroIII config for Replay USB/Ethernet Card',13,10,0
	even
	
romtag:	dc.w	RTC_MATCHWORD
	dc.l	romtag
	dc.l	end
	dc.b	RTF_COLDSTART
	dc.b	VERSION
	dc.b	NT_UNKNOWN
	dc.b	100
	dc.l	name
	dc.l	VERSTRING
	dc.l	S

name:	dc.b	'usb_eth.autoconfig',0
	even
	
S:
	kprintf	"INIT: %s",#VERSTRING
	     	                    	; $4000.0000 (USB/ETH base) + $0010.0000 (MACH_USBREGS) + $0304 (ISP_CHIPID)
	cmp.l	#$00011761,$40100304	; $0001.1761 == Valid Chip ID
	bne.b	.exit
	bsr.b	AddBoardConfig
.exit	moveq.l	#0,d0
	rts

AddBoardConfig:
.VENDOR		= 5060	; Replay
.PRODUCT	= 16	; usb
.SERIAL		= $12345678
.BOARDSIZE	= $0	; %000 = 8MB
		movem.l	d1/a0/a1,-(sp)
		moveq	#0,d0
		movea.l	4.w,a6
		lea	.expansionName,a1
		jsr	_LVOOpenLibrary(a6)
		tst.l	d0
		beq.w	.exit

		move.l	a6,-(sp)
		movea.l	d0,a6

		sub.l	a0,a0

.findNext
		move.l	#.VENDOR,d0
		move.l	#.PRODUCT,d1
		jsr	_LVOFindConfigDev(a6)
		tst.l	d0
		beq.b	.noBoard
		move.l	d0,a0
		lea	cd_Rom(a0),a1
		bclr	#CDB_CONFIGME,cd_Flags(a0)
;		beq.b	.findNext

		bra.b	.boardFound

.noBoard
		jsr	_LVOAllocConfigDev(a6)

		tst.l	d0
		beq.b	.noMem

		movea.l	d0,a0
		move.l	#$40000000,cd_BoardAddr(a0)
		move.l	#$00800000,cd_BoardSize(a0)
		lea	cd_Rom(a0),a1
		move.b	#ERT_ZORROIII+.BOARDSIZE,er_Type(a1)
		move.b	#.PRODUCT,er_Product(a1)
		move.b	#ERFF_ZORRO_III+ERFF_NOSHUTUP,er_Flags(a1)
		move.w	#.VENDOR,er_Manufacturer(a1)
		move.l	#.SERIAL,er_SerialNumber(a1)

		move.l	a0,a5
		
		jsr	_LVOAddConfigDev(a6)

;		move.l	a5,a0
;
;		jsr	_LVORemConfigDev(a6)
;
;		move.l	a5,a0
;		
;		jsr	_LVOFreeConfigDev(a6)
		
		bra.b	.findNext
.boardFound	
		move.l	cd_BoardAddr(a0),d0
.noMem
		move.l	a6,a1
		move.l	(sp),a6
		move.l	d0,(sp)
		jsr	_LVOCloseLibrary(a6)
		move.l	(sp)+,d0
.exit
		movem.l	(sp)+,d1/a0/a1
		rts

.expansionName:	EXPANSIONNAME

end		
		cnop	0,4

