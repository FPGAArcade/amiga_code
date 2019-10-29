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

; ./vasmm68k_mot -m68020 -Fhunkexe -kick1hunks -nosym -showcrit replayeth.s -o replayeth.device -I $(USERPROFILE)/Dropbox/NDK_3.9/Include/include_i -I sana2_v2/include -L replayeth.txt

; This device driver is split into three parts
;
; 1. General AmigaDOS device handling
; 2. SANA2 device handling
; 3. ENC624 hardware handling
;
;
; == general todo ==
; * check write frame size (raw?)
; * check valid destination address on multicast
; * rewrite packet header if broadcast packet is raw
; * handle TX abort - retransmit
; * copy mcast/bcast bits from the RSV
; * fix formatting and register usage
;
; == opimization todo ==
; use inlined DISABLE/ENABLE instead of exec's _LVODisable/_LVOEnable
; use double-buffered TX
; use on-demand copy of packet RX
; use DMA buffer where possible
; use multicast reception hash filtering
;
; == nice-to-have todo ==
; * split kprintf into ASSERT, ERROR, WARN, INFO, DEBUG, VERBOSE, ...
;
;
; General register allocation (WIP - not adhered to at all ;) :
;
;	"The registers D0, D1, A0, and Al are always scratch"
;	"The values of all other data and address registers must be preserved."
;
;       d0 = parameter / return value
;       d1 = temporary / parameter / scratch
;       d2 = temporary (saved)
;       d3 = 
;       d4 = 
;       d5 = 
;       d6 = loop counter (inner)
;       d7 = loop counter (outer)
;
;       a0 = parameter / HW BASE!
;       a1 = temporary / io req (copy/parameter)
;       a2 = temporary / parameter
;       a3 = io req ptr
;       a4 = context ptr
;	a5 = device ptr (copy)
;	a6 = device ptr	(i.e. GlobalData)
;	a7 = stack 
;
; all functions *should* typically do
; func:	movem.l	d2-d7/a2-a6,-(sp)
;	...
;	movem.l	(sp)+,d2-d7/a2-a6
;	rts
; or a subset thereof


	AUTO	wo ram:replayeth.device\

;ENABLE_KPRINTF

VNAME	MACRO
		dc.b	'replayeth'
	ENDM

VFULL	MACRO
		dc.b	'Replay ETH'
	ENDM

VERSION		EQU	1
REVISION	EQU	0

VSTR	MACRO
		dc.b	'1.0'
	ENDM

VDATE	MACRO
		dc.b	'01.10.2019'
		ENDM

; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	incdir	"SYS:Code/NDK_3.9/Include/include_i/"

	include "exec/ables.i"
	include "exec/execbase.i"
	include "exec/errors.i"
	include "exec/io.i"
	include "exec/memory.i"

	include "dos/dosextens.i"

	include "exec/libraries.i"
	include "exec/devices.i"
	include	"exec/resident.i"
	include	"exec/initializers.i"

	include "hardware/intbits.i"

	include "libraries/expansion.i"
	include "libraries/configvars.i"

	include "utility/utility.i"
	include	"lvo/exec_lib.i"
	include "lvo/expansion_lib.i"
	include	"lvo/utility_lib.i"

	include "devices/timer.i"
	include "utility/tagitem.i"
	include "utility/hooks.i"

	include	"enc624.i"

	incdir	":eth/include/"
	
	include "devices/sana2.i"

	include "kprintf.i"

; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	IFD	ENABLE_KPRINTF

	kprintf	"%cc%c[2J",#$001b001b
	kprintf	"%c[0;32m",#$1b<<16
	kprintf	"%s",#IDString
	kprintf	"%c[0m",#$1b<<16

	kprintf "d0/a0 = %lx/%lx",d0,a0

	move.l	4.w,a1
	move.l	ThisTask(a1),a1
	move.l	pr_CLI(a1),d1
	tst.l	d1
	beq.b	.nocli

	lsl.l	#2,d1
	movea.l	d1,a1
	move.l  cli_CommandName(a1),d1
	lsl.l	#2,d1
	movea.l	d1,a1
	moveq.l	#0,d1
	move.b	(a1)+,d1
	clr.b	(a1,d1.w)

	kprintf "from cli %s %s",a1,a0

.nocli	moveq.l	#0,d0
	rts

	ELSE

	moveq.l	#-1,d0
	rts

	ENDC


; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

MACH_INTREGS	= $00200000
;MACH_ETHREGS	= $00300000

ETH_TX_START	= $1000
ETH_RX_START	= $3000

ETHERPKT_SIZE = 1500
ETHER_ADDR_SIZE = 6

; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	BITDEF	STATE,EXCLUSIVE,0	; set if OpenUnit was exclusive (matches SANA2OPB_MINE)
	BITDEF	STATE,PROMISCUOUS,1	; set if OpenUnit was promiscuous (matches SANA2OPB_PROM)
	BITDEF	STATE,ACQUIRED,2	; set if OpenDevice has acquired the hardware
	BITDEF	STATE,CONFIGURED,3	; set if S2_CONFIGINTERFACE was successful
	BITDEF	STATE,ONLINE,4		; set if S2_ONLINE was successful
	BITDEF	STATE,LINKUP,5		; set if the PHY Ethernet link has been established
	BITDEF	STATE,TXINUSE,7		; transfer in flight - tx buffer in use

	; OPENED -> ACQUIRED -> CONFIGURED -> ONLINE -> OFFLINE -> CLOSED -> RELEASED
	;                           ^---------------------'

	; INITIALIZED = 
	;     * Check System Requirements
	;     * Setup Global State
	;     * Allocate RX/TX buffers
	;
	; OPENED = 
	;     * Open Unit
	;     * Record exlusive/promiscuous request
	;     * Acquire hardware
	;
	; ACQUIRED = 
	;     * Find Board
	;     * Reset Hardware
	;     * Retrieve Hardware (Ethernet) Address
	;
	; CONFIGURED = 
	;     * Set Hardware (Ethernet) Address
	;     * Set Receive Buffer (and TX?)
	;     * Set Receive Filters (based on normal/promiscuous mode)
	;     * Clear RAM
	;
	; ONLINE = 
	;     * Enable MAC/RX
	;     * Enable IRQ
	;
	; OFFLINE =
	;     * Disable MAC/RX
	;     * Disable IRQ
	;
	; RELEASED =
	;     * Clear Hardware (Ethernet) Address
	;     * Reset Hardware
	; 
	; EXPUNGED =
	;     * Free RX/TX buffers
	; 

	; GlobalData - Holds the global data attached to the device driver
	STRUCTURE GlobalData,DD_SIZE
		BYTE	g_State
		ALIGNLONG

	; AmigaDOS device variables
		APTR	g_ExecBase
		APTR	g_SegList

	; SANA2 book-keeping
		; Lists (Minimal List Header, see exec/lists.i)
		STRUCT	g_Contexts,MLH_SIZE	; OpenDevice contexts  
		STRUCT	g_TxReqs,MLH_SIZE	; Pending Write Requests
		STRUCT	g_RxReqsOrphan,MLH_SIZE	; Pending Reads Requests of Orphaned Packets
		STRUCT	g_EventReqs,MLH_SIZE	; Pending Events Requests

		STRUCT	g_MemoryPoolSema,SS_SIZE
		APTR	g_MemoryPool

		STRUCT	g_DeviceQuery,S2DQ_SIZE
		ALIGNLONG

	; ENC624 hardware details
		APTR	g_BoardAddr		; $4000.0000
		APTR	g_MachEnc		; $4030.0000
		APTR	g_TxBuffer		; 32bit aligned
		APTR	g_RxBuffer		; 32bit aligned
		APTR	g_TxBufferRaw		; unaligned
		APTR	g_RxBufferRaw		; unaligned

		STRUCT	g_FactoryEthAddr,ETHER_ADDR_SIZE
		STRUCT	g_CurrentEthAddr,ETHER_ADDR_SIZE

		STRUCT	g_Level2Interrupt,IS_SIZE
		STRUCT	g_TxSoftInterrupt,IS_SIZE
		STRUCT	g_RxSoftInterrupt,IS_SIZE

		WORD	g_NextPacketPointer

		ALIGNLONG
		LABEL	GLOBALDATA_SIZE

	; Context - Holds the context specific to each call to OpenDevice
	STRUCTURE Context,MLN_SIZE
		STRUCT	ctx_RxReqs,MLH_SIZE	; Pending Read Requests (Minimal List Header)

	; best match function pointers 
		APTR	ctx_CopyToBuffQuick
		APTR	ctx_CopyFromBuffQuick

	; buffer operations / tags provided via OpenDevice
		APTR	ctx_CopyToBuff		; S2_Dummy+1
		APTR	ctx_CopyFromBuff	; S2_Dummy+2
		APTR	ctx_PacketFilter	; S2_Dummy+3
		APTR	ctx_CopyToBuff16	; S2_Dummy+4
		APTR	ctx_CopyFromBuff16	; S2_Dummy+5
		APTR	ctx_CopyToBuff32	; S2_Dummy+6
		APTR	ctx_CopyFromBuff32	; S2_Dummy+7
		APTR	ctx_DmaCopyToBuff32	; S2_Dummy+8
		APTR	ctx_DmaCopyFromBuff32	; S2_Dummy+9

		LABEL	CONTEXT_SIZE


; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

VSTRING	MACRO
		VNAME
		dc.b	' '
		VSTR
		dc.b	' ('
		VDATE
		dc.b	') '
		VFULL
		dc.b	13,10,0
		even
	ENDM

VERSTAG	MACRO
		dc.b	0,'$VER: '
		VSTRING
		dc.b	0
		even
	ENDM

DEVNAME	MACRO
		VNAME
		dc.b	'.device',0
		even
	ENDM

; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
; %% AmigaDOS Device Driver
; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

		VERSTAG			; $VER: ...

RomTag:		dc.w	RTC_MATCHWORD	; RT_MATCHWORD
		dc.l	RomTag		; RT_MATCHTAG
		dc.l	end		; RT_ENDSKIP
		dc.b	RTF_AUTOINIT	; RT_FLAGS
		dc.b	VERSION		; RT_VERSION
		dc.b	NT_DEVICE	; RT_TYPE
		dc.b	0		; RT_PRI
		dc.l	DeviceName	; RT_NAME
		dc.l	IDString	; RT_IDSTRING
		dc.l	Init		; RT_INIT

DeviceName:	DEVNAME
IDString:	VSTRING

Init:		dc.l	GLOBALDATA_SIZE		; data space size
		dc.l	.funcTable		; pointer to function initializers
		dc.l	.dataTable		; pointer to data initializers
		dc.l	.initRoutine		; routine to run at startup

.funcTable:
		dc.w	-1
		dc.w	OpenDevice-.funcTable
		dc.w	CloseDevice-.funcTable
		dc.w	ExpungeDevice-.funcTable
		dc.w	Null-.funcTable
		dc.w	BeginIO-.funcTable
		dc.w	AbortIO-.funcTable
		dc.w	-1

.dataTable:
		INITBYTE	LN_TYPE,NT_DEVICE
		INITLONG	LN_NAME,DeviceName
		INITBYTE	LIB_FLAGS,LIBF_SUMUSED|LIBF_CHANGED
		INITWORD	LIB_VERSION,VERSION
		INITWORD	LIB_REVISION,REVISION
		INITLONG	LIB_IDSTRING,IDString
		dc.w	0

.initRoutine:	; ( device:d0, seglist:a0, execbase:a6 )
		kprintf "CODE STARTS AT %lx - ENDS AT %lx - SIZE EQUALS %lx",#RomTag,#end,#(end-RomTag)

		movem.l	d1-a6,-(sp)

		kprintf	"%cc%c[2J",#$001b001b
		kprintf_green
		kprintf	"initRoutine( device = %lx, seglist = %lx, execbase = %lx )",d0,a0,a6
		kprintf_reset_color

		; 020+ only
		btst	#AFB_68020,AttnFlags+1(a6)
		beq.b	.cpufail

		; OS3.0+ only
		cmp.w	#39,LIB_VERSION(a6)
		blt	.osfail

		; Store constants
		move.l	a6,a1			; execbase in a1
		move.l	d0,a6			; device ptr in a6
		move.l	a1,g_ExecBase(a6)	; save execbase ptr
		move.l  a0,g_SegList(a6)	; save seglist ptr for Expunge

		; everything but d0/d1/a0/a1 must be preserved
		; device ptr = a6

		bsr	SetupGlobalSANAII
		beq	.sanafailed
		bsr	SetupGlobalENC624
		beq	.hwfailed

		move.l	a6,d0			; restore device ptr == return value
		kprintf	"   device driver initialized (d0 = %lx)",d0
.out		movem.l	(sp)+,d1-a6
		rts

.cpufail
		kprintf	"   requires 68020+"
		bra	.error

.osfail
		kprintf	"   requires V39+"
		bra.b	.error

.sanafailed
		kprintf	"   SANA-II failed"
		bra.b	.error

.hwfailed	bsr	FreeSANAResources
		kprintf	"   hardware setup failed"

.error		bsr	FreeDevice
		moveq.l	#0,d0			; return NULL
		bra	.out

OpenDevice:	; ( unitnum:d0, flags:d1, iob:a1, device:a6 )
		kprintf_green
		kprintf	"OpenDevice( unit = %lx, flags = %lx, iob = %lx, device = %lx )",d0,d1,a1,a6
		kprintf_reset_color

		addq.w	#1,LIB_OPENCNT(a6)	; take a temp reference

	bsr	OpenUnit
	move.l	d0,IO_UNIT(a1)
	beq.b	.failed

	bsr	AcquireHardware
	beq.b	.failed

		clr.b	IO_ERROR(a1)
		move.b	#NT_REPLYMSG,LN_TYPE(a1)

		addq.w  #1,LIB_OPENCNT(a6)
		bclr    #LIBB_DELEXP,LIB_FLAGS(a6)
		moveq   #0,d0

.done		subq.w	#1,LIB_OPENCNT(a6)	; decrease temp reference cnt
		kprintf	"    OpenDevice returns %lx",d0
		rts

.failed		moveq.l	#IOERR_OPENFAIL,d0
		move.b	d0,IO_ERROR(a1)
		move.l	d0,IO_DEVICE(a1)
		kprintf	"    OpenDevice failed!"
		bra	.done

CloseDevice:	; ( iob:a1, device:a6 ) - returns seglist if unloading
	kprintf_green
	kprintf	"CloseDevice( iob = %lx, device = %lx )",a1,a6
	kprintf_reset_color

		moveq.l	#0,d0
		move.w	LIB_OPENCNT(a6),d0
		kprintf	"    LIB_OPENCNT = %lx",d0

		tst.w	LIB_OPENCNT(a6)		; can this happen?
		beq.b	.done

		moveq.l	#-1,d1
		move.l	d1,IO_UNIT(a1)
		move.l	d1,IO_DEVICE(a1)

		bsr	CloseUnit

		subq.w  #1,LIB_OPENCNT(a6)
		bne.b   .keep

;		bsr	ReleaseHardware		; let go of the board

		btst	#LIBB_DELEXP,LIB_FLAGS(a6)
		beq.b	.keep

		bsr.b	ExpungeDevice		; returns seglist:d0

.done		kprintf	"    CloseDevice returns %lx",d0
		rts

.keep		kprintf	"    Device still in use"
		moveq.l	#0,d0
		bra.b	.done

ExpungeDevice:	; ( device: a6 ) - return seglist if refcount = 0
	kprintf_green
	kprintf	"ExpungeDevice( device = %lx )",a6
	kprintf_reset_color

	tst.w	LIB_OPENCNT(a6)
	bne.w	.delayed

		bsr	ReleaseHardware		; let go of the board
	bsr	FreeSANAResources	; free pools etc
	bsr	FreeENC624Resources

	kprintf	"    Ejecting Device!"

	move.l	g_SegList(a6),-(sp)	; save seglist pointer

	move.l	a6,a1
	kprintf	"    removing device %lx",a1
	REMOVE (a1)

	move.l	a6,d0
	bsr.w	FreeDevice

	kprintf	"    %s expunged!",#DeviceName

	movem.l (sp)+,d0
	bra.b	.done

.delayed
	kprintf	"    open count not 0; delaying expunge"

	bset	#LIBB_DELEXP,LIB_FLAGS(a6)
	moveq.l	#0,d0
.done
 	kprintf	"    ExpungeDevice returns %lx",d0
 	rts


FreeDevice:	; ( device: d0 )
	kprintf	"    freeing device %lx",d0
	move.l  d0,a1
	moveq.l	#0,d0
	move.w	LIB_NEGSIZE(a6),d0
	sub.l	d0,a1                        ; calculate base of functions
	add.w	LIB_POSSIZE(a6),d0           ; calculate size of functions + data area
	movea.l	4.w,a6

	kprintf	"    free device memory %ld bytes",d0
	CALLLIB	_LVOFreeMem (a1,d0)

	rts
Null:
	kprintf_green
	kprintf	"Null()"
	kprintf_reset_color
	moveq.l	#0,d0
	rts

COMMAND	MACRO
	dc.w	(\1)-(.jmptbl)
	ENDM

BeginIO:	; ( iob: a1, device:a6 )
	move.l	#*,a0
	kprintf_green
	kprintf	"BeginIO( %lx, %lx ) @ %lx ( %lx )",a1,a6,a0,*
	kprintf_reset_color

	moveq.l	#0,d1
	moveq.l	#0,d0
	move.b	IO_FLAGS(a1),d1
	move.w	IO_COMMAND(a1),d0

	kprintf	"    IO_DEVICE = %lx, IO_UNIT = %lx, IO_FLAGS = %lx, IO_COMMAND = %lx",IO_DEVICE(a1),IO_UNIT(a1),d1,d0

	move.b	#NT_MESSAGE,LN_TYPE(a1)
	clr.b	IO_ERROR(a1)

;	kprintf	"-->> break @ %lx <<--",#*

	cmpi.w	#(.endtbl-.jmptbl)/2,d0
	bhs.b	.nsdcmd

;	kprintf	"   -> about to jump to command handler %lx ...",d0

	add.w	d0,d0
	move.w	.jmptbl(pc,d0.w),d0
	beq.b	.nocmd

	jmp	.jmptbl(pc,d0.w)	

.nsdcmd

	; $TODO New Style Device

	kprintf	"NewStyleDevice"	

	bra.b	.nocmd


	rts

	cnop	0,4


; A
; B
; 19
; A
; 9
; 2
; 2
; 2
; 2

.jmptbl	
	COMMAND	.nocmd			; 00 = CMD_INVALID		(invalid command)
	COMMAND	.nocmd			; 01 = CMD_RESET		(reset as if just inited)
	COMMAND	CmdRead			; 02 = CMD_READ			(standard read)
	COMMAND	CmdWrite		; 03 = CMD_WRITE		(standard write)
	COMMAND	.nocmd			; 04 = CMD_UPDATE		(write out all buffers)
	COMMAND	.nocmd			; 05 = CMD_CLEAR		(clear all buffers)
	COMMAND	.nocmd			; 06 = CMD_STOP			(hold current and queued)
	COMMAND	.nocmd			; 07 = CMD_START		(restart after stop)
	COMMAND	CmdFlush		; 08 = CMD_FLUSH		(abort entire queue)
	COMMAND	CmdDeviceQuery		; 09 = S2_DEVICEQUERY		(return parameters for this network interface.)
	COMMAND	CmdGetStationAddress	; 0a = S2_GETSTATIONADDRESS	(get default and interface address.)
	COMMAND	CmdConfigInterface	; 0b = S2_CONFIGINTERFACE	(get accumulated type specific statistics.)
	COMMAND	.nocmd			; 0c
	COMMAND	.nocmd			; 0d
	COMMAND	CmdAddMulticastAddress	; 0e = S2_ADDMULTICASTADDRESS	(enable an interface multicast address.)
	COMMAND	CmdDelMulticastAddress	; 0f = S2_DELMULTICASTADDRESS	(disable an interface multicast address.)
	COMMAND	CmdMulticast		; 10 = S2_MULTICAST		(multicast a packet on network.)
	COMMAND	CmdBroadcast		; 11 = S2_BROADCAST		(broadcast a packet on network.)
	COMMAND	CmdTrackType		; 12 = S2_TRACKTYPE		(accumulate statistics about a packet type.)
	COMMAND	CmdUntrackType		; 13 = S2_UNTRACKTYPE		(end statistics about a packet type.)
	COMMAND	CmdGetTypeStats		; 14 = S2_GETTYPESTATS		(get accumulated type specific statistics.)
	COMMAND	CmdGetSpecialStats	; 15 = S2_GETSPECIALSTATS	(get network type specific statistics.)
	COMMAND	CmdGetGlobalStats	; 16 = S2_GETGLOBALSTATS	(get interface accumulated statistics.)
	COMMAND	CmdOnEvent		; 17 = S2_ONEVENT		(return when specified event occures.)
	COMMAND	CmdReadOrphan		; 18 = S2_READORPHAN		(get a packet for which there is no reader.)
	COMMAND	CmdOnline		; 19 = S2_ONLINE		(put a network interface back in service.)
	COMMAND	CmdOffline		; 1a = S2_OFFLINE		(remove interface from service.)
.endtbl

.nocmd
	kprintf	"IO_ERROR = IOERR_NOCMD"

	move.b	#IOERR_NOCMD,IO_ERROR(a1)
	bra.w	TermIO


AbortIO:	; ( iob: a1, device:a6 )
	kprintf_green
	kprintf	"AbortIO( %lx, %lx)",a1,a6
	kprintf_reset_color

		movem.l	d2/a2-a3,-(sp)
		LINKLIB	_LVODisable,g_ExecBase(a6)

		kprintf	"    Disable / Lock Sema"
		moveq.l	#0,d0
		move.b	LN_TYPE(a1),d0
		kprintf	"    LN_TYPE = %lx",d0

		cmp.b	#NT_MESSAGE,LN_TYPE(a1)
		bne	.gone

		move.w	IO_COMMAND(a1),d0
		kprintf	"    IO_COMMAND = %lx",d0

		kprintf	"    Check IO_COMMAND == CMD_WRITE"
		lea	g_TxReqs(a6),a0
		cmp.w	#CMD_WRITE,IO_COMMAND(a1)
		beq	.remove

		kprintf	"    Check IO_COMMAND == S2_READORPHAN"
		lea	g_RxReqsOrphan(a6),a0
		cmp.w	#S2_READORPHAN,IO_COMMAND(a1)
		beq	.remove

		kprintf	"    Check IO_COMMAND == S2_ONEVENT"
		lea	g_EventReqs(a6),a0
		cmp.w	#S2_ONEVENT,IO_COMMAND(a1)
		beq	.remove

		kprintf	"    Check IO_COMMAND == CMD_READ"
		cmp.w	#CMD_READ,IO_COMMAND(a1)
		beq.b	.read

		kprintf	"    IO Request not known!"
		moveq.l	#IOERR_NOCMD,d0
		bra.b	.gone

.remove		bsr	.find

.gone		move.l	d0,-(sp)
		LINKLIB	_LVOEnable,g_ExecBase(a6)
		move.l	(sp)+,d0

		movem.l	(sp)+,d2/a2-a3
		rts

.read		lea		g_Contexts(a6),a2
		kprintf	"    Context list = %lx",a2
		move.l		MLH_HEAD(a2),d2
.next
		NEXTNODE.s	d2,a2,.notfound

		kprintf	"    Context = %lx",a2

		lea		ctx_RxReqs(a2),a0
		bsr.b		.find
		bne.b		.next

;		kprintf	"    IO Request aborted"

		bra		.gone

.notfound	kprintf	"    IO Request not found"
		moveq.l		#IOERR_NOCMD,d0
		rts

.find		; a0:list , a1:ioreq, a6:device (arbitration required!)
;		kprintf	"    Request list = %lx",a0
		move.l		MLH_HEAD(a0),d0
.loop
		NEXTNODE.s	d0,a3,.notfound

		kprintf	"    Request = %lx",a3

		cmp.l		a1,a3
		bne.b		.loop

		kprintf	"    Remove a1 = %lx",a1

		REMOVE		(a1)

		move.l		a3,a1
		move.b  	#IOERR_ABORTED,IO_ERROR(a1)
		bsr.b		TermIO

		moveq.l		#0,d0
		rts


; Abort single IO
; 


; TODO Add TermReq which checks DISABLE/Sema!

;AbortIO:	; a1 : io request
;		kprintf	"AbortIO"
;		move.b  #IOERR_ABORTED,IO_ERROR(a1)

		; fall through!

TermIO:		; a1 : io request
	kprintf	"TermIO %lx",a1

;	kprintf	"   -> about to reply to message ..."

;	move.b	#NT_REPLYMSG,LN_TYPE(a1)	; wait - is this kosher?
	btst	#IOB_QUICK,IO_FLAGS(a1)
	bne.b	.quick

	kprintf	"   -> replying to message ..."

	; ReplyMsg(message:a1)
		LINKLIB	_LVOReplyMsg,$4.w

.quick
	kprintf	"   -> done!"
	rts


AbortAllPending:	; d0:error d1:wireerror a6:device
		kprintf	"AbortAllPending %lx/%lx %lx",d0,d1,a6
		movem.l	d2-d4/a1-a3,-(sp)
		move.l	d0,d2
		move.l	d1,d3

		LINKLIB	_LVODisable,g_ExecBase(a6)

	; Write requests
		lea	g_TxReqs(a6),a2
		kprintf	"    TX Reqs list at %lx",a2
		bsr	.abortlist

	; ReadOrphan requests
		lea	g_RxReqsOrphan(a6),a2
		kprintf	"    RX Orphan Reqs list at %lx",a2
		bsr	.abortlist

	; EventReqs requests
		lea	g_EventReqs(a6),a2
		kprintf	"    Event Reqs list at %lx",a2
		bsr	.abortlist

	; Read requests
		lea	g_Contexts(a6),a3
		kprintf	"    Context list = %lx",a3
		move.l	MLH_HEAD(a3),d4
.next		NEXTNODE.s d4,a3,.done
		kprintf	"    Context = %lx",a3
		lea	ctx_RxReqs(a3),a2
		kprintf	"    RX Reqs list at %lx",a2
		bsr.b	.abortlist
		bra.b	.next

.done
		LINKLIB	_LVOEnable,g_ExecBase(a6)
		movem.l	(sp)+,d2-d4/a1-a3
		rts


.abortlist	; d2:error d3:wireerror a2:list , a6:device
		kprintf	"    List = %lx",a2
.loop		IFEMPTY	a2,.empty
		REMHEADQ a2,a1,a0
		kprintf	"    Removed %lx from %lx",a1,a2
		move.b	d2,IO_ERROR(a1)
		move.l	d3,IOS2_WIREERROR(a1)
		bsr	TermIO
		bra.b	.loop
.empty		rts

; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
; %% SANA-II Network Device Driver
; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

; All these entrypoints assume this register layout:
;
;  a1 = ioRequest (where applicable)
;  a6 = device ptr (GlobalData)

SetupGlobalSANAII:	; ( device:a6 )
		kprintf	"SetupGlobalSANAII"
		movem.l	d2-d7/a2-a6,-(sp)

	; Initialize device query struct
		lea	g_DeviceQuery(a6),a0			; -4 to skip the S2DQ_SIZEAVAILABLE
		move.l	#S2DQ_SIZE,S2DQ_SIZEAVAILABLE(a0)
		move.l	S2DQ_SIZEAVAILABLE(a0),S2DQ_SIZESUPPLIED(a0)
		clr.l	S2DQ_FORMAT(a0)
		clr.l	S2DQ_DEVICELEVEL(a0)
		move.w	#ETHER_ADDR_SIZE*8,S2DQ_ADDRFIELDSIZE(a0)
		move.l	#ETHERPKT_SIZE,S2DQ_MTU(a0)
		move.l	#100*(1000*1000),S2DQ_BPS(a0)
		move.l	#S2WIRETYPE_ETHERNET,S2DQ_HARDWARETYPE(a0)

	; InitSemaphore(signalSemaphore:a0)
		lea	g_MemoryPoolSema(a6),a0
		kprintf	"    _LVOInitSemaphore(g_MemoryPoolSema = %lx)",a0
		LINKLIB	_LVOInitSemaphore,g_ExecBase(a6) (a0)

	; CreatePool(memFlags:d0,puddleSize:d1,threshSize:d2) V39
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d0
		move.l	#4096,d1
		move.l	#2048,d2
		kprintf	"    _LVOCreatePool()"
		LINKLIB	_LVOCreatePool,g_ExecBase(a6) (d0,d1,d2)
		kprintf	"        => %lx",d0
		move.l	d0,g_MemoryPool(a6)
		beq	.memfailed

	; Create lists
		kprintf	"    NEWLIST()"
		lea	g_Contexts(a6),a0
		bsr	.newlist
		lea	g_TxReqs(a6),a0
		bsr	.newlist
		lea	g_RxReqsOrphan(a6),a0
		bsr.b	.newlist
		lea	g_EventReqs(a6),a0
		bsr.b	.newlist

		kprintf	"   done"
		moveq.l	#-1,d0
.out		movem.l	(sp)+,d2-d7/a2-a6
		rts


.memfailed
		kprintf	"   CreatePool failed"
		moveq.l	#0,d0
		bra.b	.out

.newlist	kprintf	"    NEWLIST $%lx",a0
		NEWLIST	a0
		rts



FreeSANAResources:
		kprintf	"FreeSANAResources"

	; DeletePool(poolHeader:a0)

		move.l	g_MemoryPool(a6),d0
		beq.b	.nopool
		movea.l	d0,a0
		kprintf	"   _LVODeletePool(%lx)",a0
		LINKLIB	_LVODeletePool,g_ExecBase(a6) (a0)

.nopool
		kprintf	"   done"
		rts

AllocVecPooled:
		kprintf "AllocVecPooled(d0 = %ld)",d0

		addq.l	#4,d0
		move.l	d0,-(sp)	; memory block size, including space for size

	; ObtainSemaphore(signalSemaphore:a0)
		lea	g_MemoryPoolSema(a6),a0
		kprintf	"    _LVOObtainSemaphore(g_MemoryPoolSema = %lx)",a0
		LINKLIB	_LVOObtainSemaphore,g_ExecBase(a6) (a0)

	; memory:d0=AllocPooled(poolHeader:a0,memSize:d0)
		move.l	(sp),d0
		move.l	g_MemoryPool(a6),a0
		kprintf	"    _LVOAllocPooled($%lx, %ld)",a0,d0
		LINKLIB	_LVOAllocPooled,g_ExecBase(a6) (a0,d0)
		move.l	d0,-(sp)

	; ReleaseSemaphore(signalSemaphore:a0)
		lea	g_MemoryPoolSema(a6),a0
		kprintf	"    _LVOReleaseSemaphore(g_MemoryPoolSema = %lx)",a0
		LINKLIB	_LVOReleaseSemaphore,g_ExecBase(a6) (a0)

		movem.l	(sp)+,d0/d1
		kprintf	"    _LVOAllocPooled(%ld bytes) returned %lx",d1,d0
		tst.l	d0
		beq.b	.failed

		move.l	d0,a0
		move.l	d1,(a0)+
		move.l	a0,d0

.out		kprintf	"    returns %lx",d0
		rts
.failed		kprintf	"    allocation failed"
		bra.b	.out

FreeVecPooled:
		kprintf "FreeVecPooled(a1 = %lx)",a1

		move.l	-(a1),d0
		movem.l	d0/a1,-(sp)

	; ObtainSemaphore(signalSemaphore:a0)
		lea	g_MemoryPoolSema(a6),a0
		kprintf	"    _LVOObtainSemaphore(g_MemoryPoolSema = %lx)",a0
		LINKLIB	_LVOObtainSemaphore,g_ExecBase(a6) (a0)

	; FreePooled(poolHeader:a0,memory:a1,memSize:d0)
		move.l	g_MemoryPool(a6),a0
		movem.l	(sp)+,d0/a1
		kprintf	"    _LVOFreePooled($%lx, $%lx, %ld)",a0,a1,d0
		LINKLIB	_LVOFreePooled,g_ExecBase(a6) (a0,a1,d0)

	; ReleaseSemaphore(signalSemaphore:a0)
		lea	g_MemoryPoolSema(a6),a0
		kprintf	"    _LVOReleaseSemaphore(g_MemoryPoolSema = %lx)",a0
		LINKLIB	_LVOReleaseSemaphore,g_ExecBase(a6) (a0)
		rts

;S2_COPYTOBUFF   EQU     S2_Dummy+1
;S2_COPYFROMBUFF EQU     S2_Dummy+2
;S2_PACKETFILTER EQU     S2_Dummy+3

; "SANA-IIR3" / S2R3 additional tags

S2_COPYTOBUFF16		EQU	S2_Dummy+4
S2_COPYFROMBUFF16	EQU	S2_Dummy+5
S2_COPYTOBUFF32		EQU	S2_Dummy+6
S2_COPYFROMBUFF32	EQU	S2_Dummy+7
S2_DMACOPYTOBUFF32	EQU	S2_Dummy+8
S2_DMACOPYFROMBUFF32	EQU	S2_Dummy+9

_intena = $dff09a

OpenUnit	; ( unitnum:d0, flags:d1, iob:a1, device:a6 ) - returns non-zero unit, or null
	kprintf	"OpenUnit"

	tst.l	d0
	beq.b	.unitok

	kprintf	"    illegal unit number"
	bra	.error

.unitok	cmp.w	#IOS2_SIZE,MN_LENGTH(a1)
	bhs.b	.sizeok

	moveq.l	#0,d0
	move.w	MN_LENGTH(a1),d0
	moveq.l	#IOS2_SIZE,d1
	kprintf	"    illegal message length (%lx < %lx)",d0,d1

	bra.b	.error

.sizeok		btst	#STATEB_EXCLUSIVE,g_State(a6)
		bne.b	.exclusive

		btst	#SANA2OPB_MINE,d1
		beq.b	.cooperative

		cmp.w	#1,LIB_OPENCNT(a6)
		bne	.nonexclusive

		and.b	#SANA2OPF_PROM+SANA2OPF_MINE,d1
		or.b	d1,g_State(a6)

.cooperative	move.l  IOS2_BUFFERMANAGEMENT(a1),d0
		bne	.gettags
		moveq.l	#1,d0
.done		kprintf	"    OpenUnit returns %lx",d0
		rts

.error		moveq.l	#0,d0
		bra.b	.done
.exclusive	kprintf	"    Unit already opened in exclusive mode"
		bra.b	.error
.nonexclusive	kprintf	"    Unit already opened in non-exclusive mode"
		bra	.error

.gettags ; d0 = taglist
	
	movem.l	a1/a3/a4/a5/a6,-(sp)

		kprintf	"    Create context and retrieve tags"

		movea.l	d0,a4		; a4 = taglist
		movea.l	a1,a5		; a5 = iob

		moveq.l	#CONTEXT_SIZE,d0
		bsr	AllocVecPooled
		move.l	d0,IOS2_BUFFERMANAGEMENT(a5)
		bne.b	.memok

		kprintf	"    failed to alloc context"
		moveq.l	#0,d0
		bra.w	.tagsdone

.memok		move.l	d0,a3		; a3 = context
		move.l	a6,a5		; a5 = device global

	; library:d0 = OpenLibrary(libName:a1, version:d0)
		move.l	g_ExecBase(a5),a6
		lea	.utilityname(pc),a1
		moveq.l	#36,d0
		CALLLIB	_LVOOpenLibrary	(a1,d0)
		tst.l	d0
		bne.b	.utilok

		kprintf	"    Failed to open library '%s'",#.utilityname
		moveq.l	#0,d0
		bra.w	.tagsdone
.utilok
		kprintf	"    Opened library '%s'",#.utilityname
	
		move.l	d0,a6			; a6 = utility library

	; retrieve all known tags

		lea	ctx_CopyToBuff(a3),a2
		move.l	#S2_COPYTOBUFF,d3
		moveq.l	#S2_DMACOPYFROMBUFF32-S2_COPYTOBUFF,d7

.nexttag	move.l	d3,d0
		moveq.l	#0,d1
		movea.l	a4,a0
		jsr	_LVOGetTagData(a6)
		move.l	d0,(a2)+

		kprintf	"    Tag %lx => %lx",d3,d0

		addq.l	#1,d3
		dbf	d7,.nexttag

	; done with utility

		kprintf	"    Closing library '%s'",#.utilityname

		move.l	a6,a1
		move.l	g_ExecBase(a5),a6
		jsr	_LVOCloseLibrary(a6)

	; init rxlist

		lea	ctx_RxReqs(a3),a0
		kprintf	"    Creating RX list at %lx",a0
		NEWLIST a0

	; find the best buffer copy hooks

		kprintf	"    Finding best buffer copy hooks"

		kprintf	"    ctx_CopyToBuff32      = %lx",ctx_CopyToBuff32(a3)
		move.l	ctx_CopyToBuff32(a3),d0
		bne	.copyto
		kprintf	"    ctx_CopyToBuff16      = %lx",ctx_CopyToBuff16(a3)
		move.l	ctx_CopyToBuff16(a3),d0
		bne.b	.copyto
		kprintf	"    ctx_CopyToBuff        = %lx",ctx_CopyToBuff(a3)
		move.l	ctx_CopyToBuff(a3),d0
.copyto		move.l	d0,ctx_CopyToBuffQuick(a3)
		kprintf	"    ctx_CopyToBuffQuick   = %lx",ctx_CopyToBuff(a3)

		kprintf	"    ctx_CopyFromBuff32    = %lx",ctx_CopyFromBuff32(a3)
		move.l	ctx_CopyFromBuff32(a3),d0
		bne	.copyfrom
		kprintf	"    ctx_CopyFromBuff16    = %lx",ctx_CopyFromBuff16(a3)
		move.l	ctx_CopyFromBuff16(a3),d0
		bne.b	.copyfrom
		kprintf	"    ctx_CopyFromBuff      = %lx",ctx_CopyFromBuff(a3)
		move.l	ctx_CopyFromBuff(a3),d0
.copyfrom	move.l	d0,ctx_CopyFromBuffQuick(a3)
		kprintf	"    ctx_CopyFromBuffQuick = %lx",ctx_CopyFromBuffQuick(a3)

	; add context to global list of contexts
		lea	g_Contexts(a5),a0
		movea.l	a3,a1

		kprintf	"    Adding context %lx to list %lx",a1,a0

		CALLLIB	_LVODisable
		ADDHEAD	(a0,a1)
		CALLLIB	_LVOEnable

		kprintf	"    Done"

		moveq.l	#1,d0		; success
.tagsdone
		movem.l	(sp)+,a1/a3/a4/a5/a6
		bra.w	.done

.utilityname
		UTILITYNAME

CloseUnit
		kprintf	"CloseUnit"
		move.l	d2,-(sp)

		and.b	#~(STATEF_EXCLUSIVE+STATEF_PROMISCUOUS),g_State(a6)

		kprintf	"    Context = %lx",IOS2_BUFFERMANAGEMENT(a1)

		move.l	IOS2_BUFFERMANAGEMENT(a1),d2
		beq	.noctx
		clr.l	IOS2_BUFFERMANAGEMENT(a1)

		movea.l	d2,a1

		kprintf	"    Removing context %lx",a1

		LINKLIB	_LVODisable,g_ExecBase(a6)
		REMOVE	(a1)
		LINKLIB	_LVOEnable,g_ExecBase(a6)

		movea.l	d2,a1
		kprintf	"    Freeing context %lx",a1
		bsr	FreeVecPooled
.noctx
		move.l	(sp)+,d2
		rts



KPRINTF_SANA2REQ:
	kprintf "---"
	kprintf	"    IOS2_WIREERROR = %lx",IOS2_WIREERROR(a1)
	kprintf	"    IOS2_PACKETTYPE = %lx",IOS2_PACKETTYPE(a1)
	kprintf	"    IOS2_SRCADDR = %08lx,%08lx",IOS2_SRCADDR+0(a1),IOS2_SRCADDR+4(a1)
	kprintf	"    IOS2_DSTADDR = %08lx,%08lx",IOS2_DSTADDR+0(a1),IOS2_DSTADDR+4(a1)
	kprintf	"    IOS2_DATALENGTH = %lx",IOS2_DATALENGTH(a1)
	kprintf	"    IOS2_DATA = %lx",IOS2_DATA(a1)
	kprintf	"    IOS2_STATDATA = %lx",IOS2_STATDATA(a1)
	kprintf	"    IOS2_BUFFERMANAGEMENT = %lx",IOS2_BUFFERMANAGEMENT(a1)
	kprintf "---"
	rts


CmdRead
	kprintf_yellow
	kprintf	"CMD_READ"
	kprintf_reset_color
;	bsr	KPRINTF_SANA2REQ

		btst	#STATEB_CONFIGURED,g_State(a6)
		beq	.noconfig
		btst	#STATEB_ONLINE,g_State(a6)
		beq	.notonline

		move.l	IOS2_BUFFERMANAGEMENT(a1),d0
		beq	.noctx
		move.l	d0,a0
		tst.l	ctx_CopyToBuffQuick(a0)
		beq	.nocopy

		lea	ctx_RxReqs(a0),a0
		bra	EnqueueRequest

.noconfig	
		kprintf	"    device not configured"
		move.b	#S2ERR_BAD_ARGUMENT,IO_ERROR(a1)
		moveq.l	#S2WERR_NOT_CONFIGURED,d0
		bra	.terminate

.notonline	
		kprintf	"    device not online"
		move.b	#S2ERR_OUTOFSERVICE,IO_ERROR(a1)
		moveq.l	#S2WERR_UNIT_OFFLINE,d0
		bra	.terminate

.nocopy
		kprintf	"    context does not provide a CopyToBuff func ptr!"
		bra.b	.err

.noctx
		kprintf	"    iob does not provide a context!"

.err		move.b	#S2ERR_BAD_ARGUMENT,IO_ERROR(a1)
		moveq.l	#S2WERR_GENERIC_ERROR,d0
.terminate	move.l	d0,IOS2_WIREERROR(a1)

		bra	TermIO

CmdReadOrphan
	kprintf_yellow
	kprintf	"S2_READORPHAN"
	kprintf_reset_color

		btst	#STATEB_CONFIGURED,g_State(a6)
		beq	.noconfig
		btst	#STATEB_ONLINE,g_State(a6)
		beq	.notonline

		move.l	IOS2_BUFFERMANAGEMENT(a1),d0
		beq	.noctx
		move.l	d0,a0
		tst.l	ctx_CopyToBuffQuick(a0)
		beq	.nocopy

		lea	g_RxReqsOrphan(a6),a0
		bra	EnqueueRequest

		kprintf	"    Done"
		rts

.noconfig	
		kprintf	"    device not configured"
		move.b	#S2ERR_BAD_ARGUMENT,IO_ERROR(a1)
		moveq.l	#S2WERR_NOT_CONFIGURED,d0
		bra	.terminate

.notonline	
		kprintf	"    device not online"
		move.b	#S2ERR_OUTOFSERVICE,IO_ERROR(a1)
		moveq.l	#S2WERR_UNIT_OFFLINE,d0
		bra	.terminate

.nocopy
		kprintf	"    context does not provide a CopyToBuff func ptr!"
		bra.b	.err

.noctx
		kprintf	"    iob does not provide a context!"

.err		move.b	#S2ERR_BAD_ARGUMENT,IO_ERROR(a1)
		moveq.l	#S2WERR_GENERIC_ERROR,d0
.terminate	move.l	d0,IOS2_WIREERROR(a1)

		bra	TermIO


CmdWrite
	kprintf_yellow
	kprintf	"CMD_WRITE"
	kprintf_reset_color

		btst	#STATEB_CONFIGURED,g_State(a6)
		beq	.noconfig
		btst	#STATEB_ONLINE,g_State(a6)
		beq	.notonline

		move.l	IOS2_BUFFERMANAGEMENT(a1),d0
		beq	.noctx
		move.l	d0,a0
		tst.l	ctx_CopyFromBuffQuick(a0)
		beq	.nocopy

	; $TODO check frame size (raw?)

		lea	g_TxReqs(a6),a0
		bsr	EnqueueRequest

	; _LVOCause(interrupt:a1)
		lea	g_TxSoftInterrupt(a6),a1
		LINKLIB	_LVOCause,g_ExecBase(a6) (a1)
		rts
.noconfig	
		kprintf	"    device not configured"
		move.b	#S2ERR_BAD_ARGUMENT,IO_ERROR(a1)
		moveq.l	#S2WERR_NOT_CONFIGURED,d0
		bra	.terminate

.notonline	
		kprintf	"    device not online"
		move.b	#S2ERR_OUTOFSERVICE,IO_ERROR(a1)
		moveq.l	#S2WERR_UNIT_OFFLINE,d0
		bra	.terminate

.nocopy
		kprintf	"    context does not provide a CopyFromBuff func ptr!"
		bra.b	.err

.noctx
		kprintf	"    iob does not provide a context!"

.err		move.b	#S2ERR_BAD_ARGUMENT,IO_ERROR(a1)
		moveq.l	#S2WERR_GENERIC_ERROR,d0
.terminate	move.l	d0,IOS2_WIREERROR(a1)

		bra	TermIO
CmdFlush
	kprintf_yellow
	kprintf	"CMD_FLUSH"
	kprintf_reset_color


	 	moveq.l	#IOERR_ABORTED,d0
	 	moveq.l	#0,d1
		bsr	AbortAllPending

	bra	TermIO

CmdDeviceQuery
	kprintf_yellow
	kprintf	"S2_DEVICEQUERY"
	kprintf_reset_color
	bsr	KPRINTF_SANA2REQ

		move.l	IOS2_STATDATA(a1),a0
		exg	d1,a1			; save iob ptr

		lea	g_DeviceQuery(a6),a1
		move.l	(a1)+,d0		; == S2DQ_SIZEAVAILABLE

		kprintf	"    S2DQ_SIZEAVAILABLE = %lx",S2DQ_SIZEAVAILABLE(a0)
		kprintf	"    S2DQ_SIZESUPPLIED = %lx",d0

		cmp.l	(a0)+,d0		; S2DQ_SIZESUPPLIED vs S2DQ_SIZEAVAILABLE
		blo.b	.nospace

		subq.l	#4+1,d0			; skip S2DQ_SIZEAVAILABLE
.copy		move.b	(a1)+,(a0)+
		dbf	d0,.copy

		exg	d1,a1			; restore iob ptr
		bra.b	.done

.nospace
		exg	d1,a1			; restore iob ptr
		clr.l	(a0)			; clear S2DQ_SIZESUPPLIED
		move.b	#S2ERR_BAD_ARGUMENT,IO_ERROR(a1)
		moveq.l	#S2WERR_BAD_STATDATA,d0
		move.l	d0,IOS2_WIREERROR(a1)

.done		bra.w	TermIO

CmdGetStationAddress
	kprintf_yellow
	kprintf	"S2_GETSTATIONADDRESS"
	kprintf_reset_color

	move.l	g_CurrentEthAddr+0(a6),IOS2_SRCADDR+0(a1)
	move.w	g_CurrentEthAddr+4(a6),IOS2_SRCADDR+4(a1)
	move.l	g_FactoryEthAddr+0(a6),IOS2_DSTADDR+0(a1)
	move.w	g_FactoryEthAddr+4(a6),IOS2_DSTADDR+4(a1)

	bsr	KPRINTF_SANA2REQ

	bra.w	TermIO


CmdConfigInterface
	kprintf_yellow
	kprintf	"S2_CONFIGINTERFACE"
	kprintf_reset_color
	bsr	KPRINTF_SANA2REQ

		btst	#STATEB_CONFIGURED,g_State(a6)
		bne.b	.configured

		btst	#0,IOS2_SRCADDR(a1)	; multicast
		bne	.nomac

		move.l	IOS2_SRCADDR+0(a1),g_CurrentEthAddr+0(a6)
		move.w	IOS2_SRCADDR+4(a1),g_CurrentEthAddr+4(a6)

		bsr	HW_SetMAC
		bsr	HW_SetReceiveBuffer
		bsr	HW_SetReceiveFilters
		bsr	HW_ClearSRAM

		bset	#STATEB_CONFIGURED,g_State(a6)

	; Genesis WTF?
	; Genesis/NetConnect3/AmiTCP will put the interface ONLINE first
	; and then CONFIGURE, assuming the ONLINE state is sticky..
		bclr	#STATEB_ONLINE,g_State(a6)
		bne	CmdOnline

.done
		bra.w	TermIO

.configured	kprintf	"    Hardware already configured"
		move.b	#S2ERR_BAD_STATE,IO_ERROR(a1)
		moveq.l	#S2WERR_IS_CONFIGURED,d0
		move.l	d0,IOS2_WIREERROR(a1)
		bra.b	.done

.nomac		kprintf	"    Bad MAC (SRC) address"
		move.b	#S2ERR_BAD_ADDRESS,IO_ERROR(a1)
		moveq.l	#S2WERR_SRC_ADDRESS,d0
		move.l	d0,IOS2_WIREERROR(a1)
		bclr	#STATEB_CONFIGURED,g_State(a6)
		bra	.done
	

CmdAddMulticastAddress
	kprintf_yellow
	kprintf	"S2_ADDMULTICASTADDRESS"
	kprintf_reset_color

		move.b	#S2ERR_NOT_SUPPORTED,IO_ERROR(a1)
		moveq.l	#S2WERR_GENERIC_ERROR,d0
		move.l	d0,IOS2_WIREERROR(a1)
		bra	TermIO

CmdDelMulticastAddress
	kprintf_yellow
	kprintf	"S2_DELMULTICASTADDRESS"
	kprintf_reset_color
		move.b	#S2ERR_NOT_SUPPORTED,IO_ERROR(a1)
		moveq.l	#S2WERR_GENERIC_ERROR,d0
		move.l	d0,IOS2_WIREERROR(a1)
		bra	TermIO

CmdMulticast
	kprintf_yellow
	kprintf	"S2_MULTICAST"
	kprintf_reset_color

;	The address supplied in ios2_DstAddr will be sanity checked (if
;	possible) by the driver. If the supplied address fails this sanity
;	check, the multicast request will fail immediately with ios2_Error
;	set to S2WERR_BAD_MULTICAST.

	; $TODO check valid dst addr

		bra	CmdWrite

CmdBroadcast
	kprintf_yellow
	kprintf	"S2_BROADCAST"
	kprintf_reset_color

	; $TODO check raw packet

;	The DstAddr field may be trashed by the driver because this function
;	may be implemented by filling DstAddr with a broadcast address and
;	internally calling CMD_WRITE.

	; broadcast address = ff:ff:ff:ff:ff:ff

		move.b	#$ff,IOS2_DSTADDR+0(a1)
		move.b	#$ff,IOS2_DSTADDR+1(a1)
		move.b	#$ff,IOS2_DSTADDR+2(a1)
		move.b	#$ff,IOS2_DSTADDR+3(a1)
		move.b	#$ff,IOS2_DSTADDR+4(a1)
		move.b	#$ff,IOS2_DSTADDR+5(a1)
		bra	CmdWrite

CmdTrackType
	kprintf_yellow
	kprintf	"S2_TRACKTYPE"
	kprintf_reset_color
		move.b	#S2ERR_NOT_SUPPORTED,IO_ERROR(a1)
		moveq.l	#S2WERR_GENERIC_ERROR,d0
		move.l	d0,IOS2_WIREERROR(a1)
		bra	TermIO
CmdUntrackType
	kprintf_yellow
	kprintf	"S2_UNTRACKTYPE"
	kprintf_reset_color
		move.b	#S2ERR_NOT_SUPPORTED,IO_ERROR(a1)
		moveq.l	#S2WERR_GENERIC_ERROR,d0
		move.l	d0,IOS2_WIREERROR(a1)
		bra	TermIO
CmdGetTypeStats
	kprintf_yellow
	kprintf	"S2_GETTYPESTATS"
	kprintf_reset_color
		move.b	#S2ERR_NOT_SUPPORTED,IO_ERROR(a1)
		moveq.l	#S2WERR_GENERIC_ERROR,d0
		move.l	d0,IOS2_WIREERROR(a1)
		bra	TermIO

CmdGetSpecialStats
	kprintf_yellow
	kprintf	"S2_GETSPECIALSTATS"
	kprintf_reset_color
		move.b	#S2ERR_NOT_SUPPORTED,IO_ERROR(a1)
		moveq.l	#S2WERR_GENERIC_ERROR,d0
		move.l	d0,IOS2_WIREERROR(a1)
		bra	TermIO

CmdGetGlobalStats
	kprintf_yellow
	kprintf	"S2_GETGLOBALSTATS"
	kprintf_reset_color
		move.b	#S2ERR_NOT_SUPPORTED,IO_ERROR(a1)
		moveq.l	#S2WERR_GENERIC_ERROR,d0
		move.l	d0,IOS2_WIREERROR(a1)
		bra	TermIO

CmdOnline
	kprintf_yellow
	kprintf	"S2_ONLINE"
	kprintf_reset_color

	; Genesis WTF? - see note in CmdConfigInterface
		bset	#STATEB_ONLINE,g_State(a6)
		bne.b	.terminate

		btst	#STATEB_CONFIGURED,g_State(a6)
		beq.b	.noconfig

		bsr	HW_EnableNIC

		moveq.l	#S2EVENT_ONLINE,d0
		bsr	ReplyEvent

.terminate	bra.w	TermIO

.noconfig	kprintf	"   Device not configured!"
		move.b	#S2ERR_BAD_STATE,IO_ERROR(a1)
		moveq.l	#S2WERR_NOT_CONFIGURED,d0
		move.l	d0,IOS2_WIREERROR(a1)
		bra.b	.terminate

CmdOffline
	kprintf_yellow
	kprintf	"S2_OFFLINE"
	kprintf_reset_color

		bclr	#STATEB_ONLINE,g_State(a6)
		beq.b	.offline

		moveq.l	#S2ERR_OUTOFSERVICE,d0
		moveq.l	#S2WERR_UNIT_OFFLINE,d1
		bsr	AbortAllPending

		bsr	HW_DisableNIC

		moveq.l	#S2EVENT_OFFLINE,d0
		bsr	ReplyEvent

.offline	bra.w	TermIO

CmdOnEvent
	kprintf_yellow
	kprintf	"S2_ONEVENT"
	kprintf_reset_color

	; If this device driver does not understand the specified event
	; condition(s) then the command returns immediately with
	; ios2_Req.io_Error set to S2_ERR_NOT_SUPPORTED and ios2_WireError
	; S2WERR_BAD_EVENT.  
		move.l	IOS2_WIREERROR(a1),d0
		and.l	#~(S2EVENT_ONLINE+S2EVENT_OFFLINE),d0
		bne.b	.unknown

	; Types ONLINE and OFFLINE return immediately if the device is
	; already in the state to be waited for.

		moveq.l	#S2EVENT_ONLINE,d0
		btst	#STATEB_ONLINE,g_State(a6)
		beq.b	.offline
.check		and.l	IOS2_WIREERROR(a1),d0
		beq.b	.enqueue

		clr.b	IO_ERROR(a1)
		move.l	d0,IOS2_WIREERROR(a1)

		bra	TermIO

.offline	moveq.l	#S2EVENT_OFFLINE,d0
		bra.b	.check

	; All other event requests are enqueued

.enqueue	lea	g_EventReqs(a6),a0
		bra	EnqueueRequest

.unknown
		kprintf	"    Unknown event type %lx",d0
		move.b	#S2ERR_NOT_SUPPORTED,IO_ERROR(a1)
		moveq.l	#S2WERR_BAD_EVENT,d0
		move.l	d0,IOS2_WIREERROR(a1)
		bra	TermIO

;
;
;

EnqueueRequest	; A0-list(destroyed) A1-node D0-(destroyed)
		kprintf	"EnqueueRequest( %lx, %lx )",a0,a1
		move.l	a6,-(sp)
		move.l	g_ExecBase(a6),a6
		bclr	#IOB_QUICK,IO_FLAGS(a1)

		CALLLIB	_LVODisable
		ADDTAIL	(a0,a1)
		CALLLIB	_LVOEnable

		move.l	(sp)+,a6
		rts


ReplyEvent	; d0:event mask a6:device
		kprintf	"ReplyEvent( %lx, %lx )",d0,a6
		movem.l	d2-d3/a1-a3/a5/a6,-(sp)

		move.l	d0,d2			; event mask

		lea	g_EventReqs(a6),a3
		move.l	g_ExecBase(a6),a5
		exg.l	a5,a6

		CALLLIB	_LVODisable

		kprintf	"    Event list = %lx",a3
		move.l	MLH_HEAD(a3),d3
.next		NEXTNODE.s d3,a3,.done

		kprintf	"    Event = %lx",a3

	; ios2_WireError	- Mask of event(s) to wait for
		move.l	IOS2_WIREERROR(a3),d0
;		kprintf	"    request mask = %lx",d0
;		kprintf	"      event mask = %lx",d2
		and.l	d2,d0
		beq.b	.next

	; A successful return will have ios2_Error set to
	; zero ios2_WireError set to the event number.

;		kprintf	"     result mask = %lx",d0

		clr.b	IO_ERROR(a3)
		move.l	d0,IOS2_WIREERROR(a3)

;		kprintf	"    Removing and replying = %lx",a3

		movea.l	a3,a1
		REMOVE

		movea.l	a3,a1
		CALLLIB	_LVOReplyMsg (a1)

	; All pending requests for a particular event will be returned when
	; that event occurs.

		bra	.next

.done
		CALLLIB	_LVOEnable

		movem.l	(sp)+,d2-d3/a1-a3/a5/a6
		rts


PacketProcess	; a0 = hw, a1 = globals, a2 = rx buffer
		movem.l	d0-a6,-(sp)

		moveq.l	#0,d7			; number of successful reads processed / -1 for orphan

		move.l	g_Contexts(a1),a3
.ctx		move.l	(a3),d3
		beq	.noctx

;		kprintf	"   Processing context $%lx",a3

		move.l	ctx_RxReqs(a3),a3
.req		move.l	(a3),d4
		beq.b	.noreqs

;		kprintf	"   Processing request $%lx",a3

		moveq.l	#0,d0
		move.w	12(a2),d0
		cmp.l	IOS2_PACKETTYPE(a3),d0
		beq.b	.process

;		kprintf	"   Packet type mismatch %lx != %lx",IOS2_PACKETTYPE(a3),d0

		move.l	d4,a3
		bra.b	.req

.process
		bsr	.copytobuff

.noreqs		move.l	d3,a3
		bra	.ctx

.noctx
		tst.l	d7
		bne.b	.done

		moveq.l	#-1,d7

	; Read Orphan requests
		move.l	g_RxReqsOrphan(a1),a3
		tst.l	(a3)
		beq.b	.done

		kprintf	"   Processing orphan request $%lx",a3

		bsr	.copytobuff
.done

		movem.l	(sp)+,d0-a6

		rts

.copytobuff
		move.l  IOS2_BUFFERMANAGEMENT(a3),a4
		kprintf	"   Request %lx : CopyToBuff with context $%lx",a3,a4

		move.l	(a2),IOS2_DSTADDR(a3)
		move.w	4(a2),IOS2_DSTADDR+4(a3)
		move.l	6(a2),IOS2_SRCADDR(a3)
		move.w	10(a2),IOS2_SRCADDR+4(a3)
		move.l	d0,IOS2_PACKETTYPE(a3)

		kprintf	"    DST = %08lx-%08lx",IOS2_DSTADDR(a3),IOS2_DSTADDR+4(a3)
		kprintf	"    SRC = %08lx-%08lx",IOS2_SRCADDR(a3),IOS2_SRCADDR+4(a3)
		kprintf	"    TYP = %08lx",IOS2_PACKETTYPE(a3)

		btst	#SANA2IOB_RAW,IO_FLAGS+1(a3)
		bne.b	.raw

;		kprintf	"   Cooked request"

		lea	ETHER_ADDR_SIZE+ETHER_ADDR_SIZE+2(a2),a2
		sub.l	#ETHER_ADDR_SIZE+ETHER_ADDR_SIZE+2+4,d2

.raw		move.l	d2,IOS2_DATALENGTH(a3)

;		kprintf	"   Data = %lx, length = %ld",a2,d2

		cmp.l	#-1,d7		; number of packets == $ffff.ffff?
		beq.b	.keep		; magic - orphaned read -> skip filtering

		move.l	ctx_PacketFilter(a4),d0
		beq.b	.keep

	;keep:d0 = PacketFilter(hook:a0, ios2:a2, data:a1)
		move.l	d0,a0		; a0 = hook
		exg.l	a2,a3		; a2 = iob
		exg.l	a3,a1		; a1 = buffer
		move.l	h_Entry(a0),a5	; assembler entry point

;		kprintf	"   PacketFilter(%lx,%lx,%lx) = %lx",a0,a1,a2,a5

		jsr	(a5)
		exg.l	a3,a1
		exg.l	a2,a3
		tst.l	d0
		bne.b	.keep

		kprintf	"   Filter discarded packet"
		rts

.keep
	; $TODO use the RSV for this
	; Bit 25 = Byte 3 Bit 1 = Receive Broadcast Packet = SANA2IOB_BCAST,bit 6
	; Bit 24 = Byte 3 Bit 0 = Receive Multicast Packet = SANA2IOB_MCAST,bit 5
	;

		btst	#0,IOS2_DSTADDR(a3)
		beq	.flagsdone		; EVEN address = not BCAST/MCAST
		cmp.l	#-1,IOS2_DSTADDR(a3)
		bne.b	.multicast
		cmp.w	#-1,IOS2_DSTADDR+4(a3)
		bne.b	.multicast
		kprintf	"    BROADCAST!"
		bset	#SANA2IOB_BCAST,IO_FLAGS(a3)
		bra.b	.flagsdone
.multicast	kprintf	"    MULTICAST!"
		bset	#SANA2IOB_MCAST,IO_FLAGS(a3)
.flagsdone

	;success:d0 = CopyToBuff(to:a0, from:a1, n:d0)

		move.l	IOS2_DATA(a3),a0	; to
		move.l	a2,a1			; from
		move.l	d2,d0			; length
		move.l	a2,d1
		and.w	#$f,d1
		bne.b	.unaligned
		move.l	ctx_CopyToBuffQuick(a4),a5
		bra.b	.aligned
.unaligned	move.l	ctx_CopyToBuff(a4),a5
.aligned
		kprintf	"   CopyToBuff(%lx,%lx,%ld) = %lx",a0,a1,d0,a5

		jsr	(a5)
		tst.l	d0
		beq.b	.error

		addq.l	#1,d7

.packetdone	move.l	a3,a1
		kprintf	"    removing request %lx",a1
		REMOVE (a1)

		move.l	a3,a1
		bra	TermIO


.error		kprintf	"    CopyToBuff failed!"

		move.b	#S2ERR_NO_RESOURCES,IO_ERROR(a1)
		moveq.l	#S2WERR_BUFF_ERROR,d0
		move.l	d0,IOS2_WIREERROR(a1)
		bra	.packetdone


;; --------------------------

AcquireHardware	; ( unitnum:d0, flags:d1, iob:a1, device:a6 )
		kprintf	"AcquireHardware"
		movem.l	d0/a1-a2,-(sp)

		btst	#STATEB_ACQUIRED,g_State(a6)
		bne	.acquired

		bsr	GetBoardAddr
		kprintf	"Replay USB/ETH BoardAddr = %lx",d0
		move.l	d0,g_BoardAddr(a6)
		beq.w	.no_hardware

		movea.l	d0,a0
		adda.l	#$00300000,a0	; MACH_ETHREGS
		move.l	a0,g_MachEnc(a6)

		bsr	HW_ResetEth
		beq	.reset_failed

		bsr	HW_PrintEthStatus

		lea	g_FactoryEthAddr(a6),a1
		move.b	(MAADR1L,a0),(a1)+
		move.b	(MAADR1H,a0),(a1)+
		move.b	(MAADR2L,a0),(a1)+
		move.b	(MAADR2H,a0),(a1)+
		move.b	(MAADR3L,a0),(a1)+
		move.b	(MAADR3H,a0),(a1)+
		lea	-ETHER_ADDR_SIZE(a1),a1
		lea	g_CurrentEthAddr(a6),a2
		move.l	(a1)+,(a2)+
		move.w	(a1)+,(a2)+

		moveq.l	#0,d0
		move.w	g_FactoryEthAddr+4(a6),d0

		bset	#STATEB_ACQUIRED,g_State(a6)

.ok		moveq.l	#-1,d0
.done		movem.l	(sp)+,d0/a1-a2
		rts			; return with Z cleared to indicated success

.acquired	kprintf	"    Hardware already acquired"
		bra.b	.ok
.no_hardware	kprintf	"    Hardware not found"
		bra.b	.done
.reset_failed	kprintf	"    Reset failed"
		bra	.done

ReleaseHardware	; ( device:a6 )
		kprintf	"ReleaseHardware"

		bclr	#STATEB_ONLINE,g_State(a6)
		beq.b	.offline

		kprintf	"   NIC online - going offline"

		bsr	HW_DisableNIC

.offline	bclr	#STATEB_CONFIGURED,g_State(a6)
		beq.b	.configured

		kprintf	"   NIC configured - releasing config"

.configured	bclr	#STATEB_ACQUIRED,g_State(a6)
		beq	.released

		kprintf	"   Hardware acquired - resetting"

		bsr	HW_ResetEth
		beq	.resetfailed

.zeromac	kprintf	"    nulling MAC"
		clr.l	g_FactoryEthAddr(a6)
		clr.w	g_FactoryEthAddr+4(a6)
		clr.l	g_CurrentEthAddr(a6)
		clr.w	g_CurrentEthAddr+4(a6)

.ok		moveq.l	#-1,d0
		rts

.released	kprintf	"    Hardware already released"
		bra.b	.ok

.resetfailed	kprintf	"    Hardware reset failed"
.failed		moveq.l	#0,d0
		rts




; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
; %% Microchip ENC624J600 Hardware Device Driver
; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

; All these entrypoints assume this register layout:
;
;  a1 = ioRequest (where applicable)
;  a6 = device ptr (GlobalData)

TXBUFFER_SIZE	= 24*1024	; matches hw sram size
RXBUFFER_SIZE	= 24*1024	; matches hw sram size
BUFFER_ALIGN	= 16		; byte alignment

SetupGlobalENC624:
		kprintf	"SetupGlobalENC624"

	; memoryBlock:d0 = AllocVec(byteSize:d0, attributes:d1)
		move.l	#TXBUFFER_SIZE+BUFFER_ALIGN,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		LINKLIB	_LVOAllocVec,g_ExecBase(a6) (d0,d1)
		move.l	d0,g_TxBufferRaw(a6)
		beq	.memerror

		kprintf	"    TxBufferRaw = %lx",d0
		add.l	#BUFFER_ALIGN-1,d0
		and.l	#~(BUFFER_ALIGN-1),d0
		move.l	d0,g_TxBuffer(a6)
		kprintf	"    TxBuffer    = %lx",d0

		move.l	#RXBUFFER_SIZE+BUFFER_ALIGN+16,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		LINKLIB	_LVOAllocVec,g_ExecBase(a6) (d0,d1)
		move.l	d0,g_RxBufferRaw(a6)
		beq	.memerror

		kprintf	"    RxBufferRaw = %lx",d0
		add.l	#BUFFER_ALIGN-1,d0
		and.l	#~(BUFFER_ALIGN-1),d0
		add.l	#16-(ETHER_ADDR_SIZE+ETHER_ADDR_SIZE+2),d0	; 6+6+2 = eth header. makes a non-raw packet aligned
		move.l	d0,g_RxBuffer(a6)
		kprintf	"    RxBuffer    = %lx",d0


	; Setup ISR structs
		lea	HardInterrupt(pc),a0
		lea	g_Level2Interrupt(a6),a1
		lea	.Lvl2InterruptName(pc),a2
		bsr.b	.setinterrupt

		lea	TransmitHandler(pc),a0
		lea	g_TxSoftInterrupt(a6),a1
		lea	.TxInterruptName(pc),a2
		bsr.b	.setinterrupt

		lea	ReceiveHandler(pc),a0
		lea	g_RxSoftInterrupt(a6),a1
		lea	.RxInterruptName(pc),a2
		bsr.b	.setinterrupt

		kprintf	"    done"
		moveq.l	#-1,d0
		rts


.setinterrupt	; ( a0 = ISR, a1 = Interrupt Structure, a2 = name, a6 = device)
	
		kprintf	"    IS @ %lx (%s) points to %lx/%lx",a1,a2,a0,a6

		move.b	#NT_INTERRUPT,LN_TYPE(a1)
		move.b	#0,LN_PRI(a1)
		move.l	a2,LN_NAME(a1)
		move.l	a6,IS_DATA(a1)
		move.l	a0,IS_CODE(a1)
		rts

.memerror
		kprintf	"    allocation failed"
		bsr.b	FreeENC624Resources
		moveq.l	#0,d0
		rts

.Lvl2InterruptName	dc.b	'ETH Level2 Hard Interrupt',0
		even
.TxInterruptName	dc.b	'ETH Tx SoftInt',0
		even
.RxInterruptName	dc.b	'ETH Rx SoftInt',0
		even


FreeENC624Resources:
		kprintf	"FreeENC624Resources"

	; FreeVec(memoryBlock:a1)

		move.l	g_TxBufferRaw(a6),d0
		beq.b	.notx

		movea.l	d0,a1
		LINKLIB	_LVOFreeVec,g_ExecBase(a6) (a1)
		clr.l	g_TxBuffer(a6)
		clr.l	g_TxBufferRaw(a6)

.notx		move.l	g_RxBufferRaw(a6),d0
		beq.b	.norx

		movea.l	d0,a1
		LINKLIB	_LVOFreeVec,g_ExecBase(a6) (a1)
		clr.l	g_RxBuffer(a6)
		clr.l	g_RxBufferRaw(a6)
.norx
		kprintf	"    done"
		rts

;-----------------------------------------------------------

	cnop	0,32

HardInterrupt:

;	Servers are called with the following register conventions:
;
;	    D0 - scratch
;	    D1 - scratch
;
;	    A0 - scratch
;	    A1 - server is_Data pointer (scratch)
;
;	    A5 - jump vector register (scratch)
;	    A6 - scratch
;
;	    all other registers must be preserved

	; $TODO Check online and enabled?
		move.l	a1,a5
		move.l	g_MachEnc(a5),a0	; $4030.0000

	; determine if we actually caused this interrupt

		btst	#EIEB_INTIE,(EIE,a0)		; is enabled?
		beq	.noteth
		btst	#ESTATB_INT,(ESTAT,a0)		; is signalled?
		beq	.noteth

	; Determine what caused this interrupt
		move.l	g_ExecBase(a5),a6

.checkirq	move.w	(EIE,a0),d0
		and.w	(EIR,a0),d0
		beq	.done

		kprintf	"   IRQ mask = %lx",d0

	; PKTIF?

		btst	#EIRB_PKTIF,d0			; Packet Pending?
		beq.b	.notPKTIF

		kprintf	"EIRB_PKTIF"

		move.w	#EIEF_PKTIE,(EIECLR,a0)

	; _LVOCause(interrupt:a1)
		lea	g_RxSoftInterrupt(a5),a1
		CALLLIB	_LVOCause (a1)
		bra	.continue

.notPKTIF
	; TXIF?
		btst	#EIRB_TXIF,d0			; Transmit Done?
		beq	.notTXIF

		kprintf	"EIRB_TXIF"

		bclr	#STATEB_TXINUSE,g_State(a5)
		bne	.txwasinuse

		kprintf	"$ ERROR $ ERROR $ ERROR $ ERROR $ ERROR"
		kprintf " TX buffer was not allocated!?"
		clr.b	$0	; enforce hit!
		clr.b	$2	; enforce hit!
		clr.b	$1	; enforce hit!
		clr.b	$3	; enforce hit!
		illegal

.txwasinuse	move.w	#EIRF_TXIF,(EIRCLR,a0)

	; _LVOCause(interrupt:a1)
.causeTX	lea	g_TxSoftInterrupt(a5),a1
		CALLLIB	_LVOCause (a1)
		bra	.continue

.notTXIF
	; LINKIF?
		btst	#EIRB_LINKIF,d0			; Link Status Change?
		beq	.notLINKIF

		kprintf	"EIRB_LINKIF"

		move.w	#EIRF_LINKIF,(EIRCLR,a0)

		moveq.l	#0,d1
		move.w	(ESTAT,a0),d1
		and.w	#ESTATF_PHYLNK,d1
		beq.b	.nolink

		kprintf	"  PHYLNK UP!"
		bset	#STATEB_LINKUP,g_State(a5)
		bra	.causeTX
.nolink
		kprintf	"  PHYLNK DOWN!"
		bclr	#STATEB_LINKUP,g_State(a5)
		bra	.continue

.notLINKIF
	; We got interrupted without an handler attached?!
	; Clear the left over flags, and disable further interrupts of this kind

		kprintf	"Spurious IRQ?! Silence it! %lx",d0

		move.w	d0,(EIRCLR,a0)
		move.w	d0,(EIECLR,a0)

.continue	move.l	g_MachEnc(a5),a0	; restore HW base
		bra	.checkirq

.done		moveq.l	#1,d0	; clr Z = processed
		rts

.noteth		moveq.l	#0,d0	; set Z = not taken
		rts

;-----------------------------------------------------------

	cnop	0,32

TransmitHandler
		kprintf	"TransmitHandler"
		movem.l	d0-a6,-(sp)
		move.l	a1,a6

		; Check transmit buffer available
		btst	#STATEB_TXINUSE,g_State(a6)
		bne	.packetdone

		kprintf "   TX Buffer available!"

		btst	#STATEB_LINKUP,g_State(a6)
		beq	.packetdone

		kprintf "   PHY link available!"

		lea	g_TxReqs(a6),a0

	;	REMHEAD	(a0)

			MOVE.L  (A0),A1
			MOVE.L  (A1),D0
			BEQ.S   .REMHEAD
			MOVE.L  D0,(A0)
			EXG.L   D0,A1
			MOVE.L  A0,LN_PRED(A1)
.REMHEAD
	;	REMHEAD ^^^

		beq	.packetdone

		move.l	d0,a4
		kprintf "   TX Request available! %lx",a4

		move.l  IOS2_BUFFERMANAGEMENT(a4),a5

		kprintf	"   CopyFromBuff with context $%lx",a5

		move.l	g_TxBuffer(a6),a0
		move.l	IOS2_DATA(a4),a1
		move.l	IOS2_DATALENGTH(a4),d6
		move.l	d6,d0

		btst	#SANA2IOB_RAW,IO_FLAGS+1(a4)
		bne	.raw

		kprintf	"    Cooked"

		kprintf	"    DST = %08lx-%08lx",IOS2_DSTADDR(a4),IOS2_DSTADDR+4(a4)
		kprintf	"    SRC = %08lx-%08lx",g_CurrentEthAddr(a6),g_CurrentEthAddr+4(a6)

		move.l	IOS2_DSTADDR(a4),(a0)+
		move.w	IOS2_DSTADDR+4(a4),(a0)+
		move.w	IOS2_PACKETTYPE+2(a4),(a0)+

		add.w	#ETHER_ADDR_SIZE+2,d6

		; TXMAC = 1
		; PADCFG = 101
		; TXCRCEN = 1
		bra.b	.copyfrombuf
.raw
		kprintf	"    Raw"

		; TXMAC = 0
		; PADCFG = 101
		; TXCRCEN = 1

.copyfrombuf	move.l	ctx_CopyFromBuff(a5),a2

		kprintf	"   CopyFromBuff(%lx,%lx,%ld) = %lx",a0,a1,d0,a2

		jsr	(a2)
		tst.l	d0
		beq	.error

	; done with the ioreq
		move.l	a4,a1
		bsr	TermIO

	; copy bytes to SRAM

		move.l	g_MachEnc(a6),a0	; $4030.0000

		move.w	#ETH_TX_START,(ETXST,a0)
		move.w	d6,(ETXLEN,a0)
		cmp.w	IOS2_DATALENGTH(a4),d6	; hack af.. 
		beq.b	.stillraw

		kprintf	"    Cooked"

		; TXMAC = 1
		bset	#ECON2B_TXMAC,(ECON2SET,a0)

		bra.b	.transfer
.stillraw
		kprintf	"    Raw"

		; TXMAC = 0
		bset	#ECON2B_TXMAC,(ECON2CLR,a0)


.transfer	move.l	g_TxBuffer(a6),a3

		lea	(2*ETH_TX_START,a0),a2
		addq.w	#1,d6
		lsr.w	d6
		subq.w	#1,d6

.copy		move.w	(a3)+,d1
		ror.w	#8,d1
		move.w	d1,(a2)+
		addq.w	#2,a2

		dbf	d6,.copy

		bset	#STATEB_TXINUSE,g_State(a6)
		move.w	#ECON1F_TXRTS,(ECON1SET,a0)

.packetdone	movem.l	(sp)+,d0-a6
		rts

.error		kprintf	"    CopyFromBuff failed!"

		move.b	#S2ERR_NO_RESOURCES,IO_ERROR(a1)
		moveq.l	#S2WERR_BUFF_ERROR,d0
		move.l	d0,IOS2_WIREERROR(a1)
		bra.b	.packetdone

;-----------------------------------------------------------

	cnop	0,32

ReceiveHandler
		kprintf	"ReceiveHandler"
		movem.l	d0-a6,-(sp)
		move.l	g_MachEnc(a1),a0	; $4030.0000

		moveq.l	#0,d7
		move.b	(ESTATL,a0),d7		; packets available
		beq	.nopackets
;		kprintf	"packets to process : %lx",d7

		subq.l	#1,d7

		moveq.l	#0,d0
		move.w	g_NextPacketPointer(a1),d0
		
.process	move.l	g_RxBuffer(a1),a3
;		kprintf	"ThisPacketPointer : %lx",d0

		lea	(a0,d0.l*2),a2		; packet

		move.w	d0,(ERXRDPT,a0)
		move.w	(a2),d0

;		kprintf	"NextPacketPointer : %lx",d0

		lea	(ERXDATA+1,a0),a2
		move.b	(a2),d1
		move.b	(a2),d1

		moveq.l	#0,d1
		moveq.l	#0,d2
		moveq.l	#0,d3
		moveq.l	#0,d4
		moveq.l	#0,d5
		moveq.l	#0,d6

		move.b	(a2),d6
		move.b	(a2),d5
		move.b	(a2),d4
		move.b	(a2),d3
		move.b	(a2),d2
		move.b	(a2),d1

;		kprintf	"RSV (48 bits) = %02lx-%02lx-%02lx-%02lx-%02lx-%02lx",d1,d2,d3,d4,d5,d6

	; $TODO if multicast - check against list of valid addresses, and discard if possible

		lsl.w	#8,d5
		or.w	d5,d6

;		sub.w	#4,d6	; remove trailing CRC
;		kprintf	"Ether packet length w/o CRC = %ld bytes",d6

		move.w	d6,d5
		lsr.w	#4,d6
;		kprintf	"loop cnt = %ld bytes",d6

		and.w	#16-1,d5
;		kprintf	"left over = %ld copys",d5
		lsl.w	d5
;		kprintf	"jump offset = %ld copys",d5
		neg.w	d5

;		kprintf "RecvBuffer = %lx",a3
		jmp	.start(pc,d5.w)

.copy
	rept 16
		move.b	(a2),(a3)+
	endr
.start		dbf	d6,.copy

		move.w	#ECON1F_PKTDEC,(ECON1SET,a0)
;		move.w	d0,(ERXTAIL,a0)

		move.l	g_RxBuffer(a1),d2
		move.l	d2,a2
		sub.l	a3,d2
		neg.l	d2

;		kprintf	"PacketProcess $%lx %ld bytes",a2,d2
;;		bsr.b	.dump
		bsr	PacketProcess

		dbf	d7,.process

		move.w	d0,g_NextPacketPointer(a1)
		cmp.w	#ETH_RX_START,d0
		bne.b	.tailok
		move.w	#$5FFE+2,d0
.tailok		sub.w	#2,d0
		move.w	d0,(ERXTAIL,a0)

	; Enable RX interrupts

		move.w	#EIEF_PKTIE,(EIESET,a0)

.nopackets	movem.l	(sp)+,d0-a6
		rts

;-----------------------------------------------------------

.dump		movem.l	d0-a6,-(sp)
		bra.b	.dumpstart
.dumpend	movem.l	(sp)+,d0-a6
		rts
.dumpstart		
		tst.w	d2
		ble.b	.dumpend

		cmp.w	#12,d2
		ble.b	.min12
		bra.b	.print16

.min12		cmp.w	#8,d2
		ble.b	.min8
		bra.b	.print12

.min8		cmp.w	#4,d2
		ble.b	.min4
		bra	.print8

.min4		bra	.print4

.print16	kprintf	"    %08lx %08lx %08lx %08lx",0(a2),4(a2),8(a2),12(a2)
		add.w	#16,a2
		sub.w	#16,d2
		bra	.dump

.print12	kprintf	"    %08lx %08lx %08lx",0(a2),4(a2),8(a2)
		add.w	#12,a2
		sub.w	#12,d2
		bra	.dump

.print8		kprintf	"    %08lx %08lx",0(a2),4(a2)
		add.w	#8,a2
		sub.w	#8,d2
		bra	.dump

.print4		kprintf	"    %08lx",0(a2)
		add.w	#4,a2
		sub.w	#4,d2
		bra	.dump

		rts

;-----------------------------------------------------------

GetBoardAddr:	; ( device:a6 )
.VENDOR		= 5060	; Replay
.PRODUCT	= 16	; usb/eth
		movem.l	d1/a0/a1/a6,-(sp)
		moveq.l	#0,d0
		movea.l	g_ExecBase(a6),a6
		lea	.expansionName(pc),a1
		jsr	_LVOOpenLibrary(a6)
		tst.l	d0
		beq.b	.exit

		move.l	a6,-(sp)
		movea.l	d0,a6
		suba.l	a0,a0

.findNext	move.l	#.VENDOR,d0
		move.l	#.PRODUCT,d1
		jsr	_LVOFindConfigDev(a6)
		tst.l	d0
		beq.b	.noBoard
		move.l	d0,a0
		bclr	#CDB_CONFIGME,cd_Flags(a0)
		move.l	cd_BoardAddr(a0),d0

.noBoard	movea.l	a6,a1
		movea.l	(sp),a6
		move.l	d0,(sp)
		jsr	_LVOCloseLibrary(a6)
		move.l	(sp)+,d0

.exit		movem.l	(sp)+,d1/a0/a1/a6
		rts

.expansionName	EXPANSIONNAME

;-----------------------------------------------------------

HW_SetMAC
		kprintf	"Set MAC"
		movem.l	d0-a6,-(sp)

		move.l	g_MachEnc(a6),a0
		move.b	g_CurrentEthAddr+0(a6),(MAADR1L,a0)	; 020+ addressing
		move.b	g_CurrentEthAddr+1(a6),(MAADR1H,a0)
		move.b	g_CurrentEthAddr+2(a6),(MAADR2L,a0)
		move.b	g_CurrentEthAddr+3(a6),(MAADR2H,a0)
		move.b	g_CurrentEthAddr+4(a6),(MAADR3L,a0)
		move.b	g_CurrentEthAddr+5(a6),(MAADR3H,a0)

		bsr	HW_PrintEthStatus

		movem.l	(sp)+,d0-a6
 	 	rts


HW_EnableNIC:
		kprintf	"Enable NIC"
		movem.l	d0-a6,-(sp)

	; AddIntServer(intNum:d0, interrupt:a1)
		moveq.l	#INTB_PORTS,d0
		lea	g_Level2Interrupt(a6),a1
		LINKLIB	_LVOAddIntServer,g_ExecBase(a6) (d0,a1)

		bsr	HW_EnableMAC
		bsr	HW_EnableInterrupt

		movem.l	(sp)+,d0-a6
		rts

HW_DisableNIC:
		kprintf	"Disable NIC"
		movem.l	d0-a6,-(sp)

		bsr	HW_DisableMAC
		bsr	HW_DisableInterrupt

	; RemIntServer(intNum:d0, interrupt:a1)
		moveq.l	#INTB_PORTS,d0
		lea	g_Level2Interrupt(a6),a1
		LINKLIB	_LVORemIntServer,g_ExecBase(a6) (d0,a1)

		movem.l	(sp)+,d0-a6
		rts


HW_ResetEth:
		kprintf	"Reset ETH"
		move.l	g_MachEnc(a6),a0

		kprintf	" > Wait EUDAST stable.."

; 1. Write 1234h to EUDAST.
; 2. Read EUDAST to see if it now equals 1234h. If
; it does not, the SPI/PSP interface may not be
; ready yet, so return to step 1 and try again.

		moveq.l	#100,d1
		move.w	#$1234,d0
.notrdy		move.w	d0,(EUDAST,a0)
		cmp.w	(EUDAST,a0),d0
		beq.b	.psprdy
		bsr	Wait25us
		dbf	d1,.notrdy
		bra	.error

.psprdy
		kprintf	" > Wait CLKRDY .."

; 3. Poll CLKRDY (ESTAT<12>) and wait for it to
; become set.

		moveq.l	#100,d1
.noclk		btst	#ESTATB_CLKRDY,(ESTATH,a0)
		bne.b	.clkrdy
		bsr	Wait25us
		dbf	d1,.noclk
		bra	.error

.clkrdy
		kprintf	" > Issue a System Reset .."

; 4. Issue a System Reset command by setting
; ETHRST (ECON2<4>).
; 5. In software, wait at least 25 s for the Reset to
; take place and the SPI/PSP interface to begin
; operating again.

		moveq.l	#100,d1
		move.w	#ECON2F_ETHRST,(ECON2SET,a0)
.waitrst	bsr	Wait25us
		btst	#ECON2B_ETHRST,(ECON2L,a0)
		beq.b	.resetok
		dbf	d1,.waitrst
		bra	.error

.resetok
		kprintf	" > Check EUDAST .."

; 6. Read EUDAST to confirm that the System Reset
; took place. EUDAST should have reverted back
; to its Reset default of 0000h.

		tst.w	(EUDAST,a0)
		bne	.error

		kprintf	" > Wait PHY .."

; 7. Wait at least 256 s for the PHY registers and
; PHY status bits to become available

		bsr	Wait250us

	; read PHY regs

		moveq.l	#PHCON1,d0
		bsr	HW_ReadPhy
		kprintf	" > PHCON1  = $%lx",d0

		moveq.l	#PHSTAT1,d0
		bsr	HW_ReadPhy
		kprintf	" > PHSTAT1 = $%lx",d0

		moveq.l	#PHANA,d0
		bsr	HW_ReadPhy
		kprintf	" > PHANA   = $%lx",d0

		moveq.l	#PHANLPA,d0
		bsr	HW_ReadPhy
		kprintf	" > PHANLPA = $%lx",d0

		moveq.l	#PHANE,d0
		bsr	HW_ReadPhy
		kprintf	" > PHANE   = $%lx",d0

		moveq.l	#PHCON2,d0
		bsr	HW_ReadPhy
		kprintf	" > PHCON2  = $%lx",d0

		moveq.l	#PHSTAT2,d0
		bsr	HW_ReadPhy
		kprintf	" > PHSTAT2 = $%lx",d0

		moveq.l	#PHSTAT3,d0
		bsr	HW_ReadPhy
		kprintf	" > PHSTAT3 = $%lx",d0

	; DONE

		kprintf	" > Reset done."
		moveq.l	#-1,d0
		rts

.error:		kprintf " > Reset failed."
		moveq.l	#0,d0
		rts

Wait25us:	move.l	d0,-(sp)
		moveq.l	#25,d0
.wait		tst.b	$bfe001		; approx 1us
		dbf	d0,.wait
		move.l	(sp)+,d0
		rts

Wait250us:	move.w	d0,-(sp)
		move.w	#250,d0
.wait		tst.b	$bfe001		; approx 1us
		dbf	d0,.wait
		move.w	(sp)+,d0
		rts

HW_PrintEthStatus:
		kprintf	"PrintEthStatus"

		movem.l	d0-a6,-(sp)
		move.l	g_MachEnc(a6),a0
		moveq.l	#0,d0
		moveq.l	#0,d1
		moveq.l	#0,d2
		moveq.l	#0,d3
		moveq.l	#0,d4
		moveq.l	#0,d5
		move.b	(MAADR1L,a0),d0	; 020+ addressing
		move.b	(MAADR1H,a0),d1
		move.b	(MAADR2L,a0),d2
		move.b	(MAADR2H,a0),d3
		move.b	(MAADR3L,a0),d4
		move.b	(MAADR3H,a0),d5
		kprintf	"    MAC = %02lx:%02lx:%02lx:%02lx:%02lx:%02lx",d0,d1,d2,d3,d4,d5
		move.w	(EIDLED,a0),d0
		move.w	d0,d1
		and.w	#%11100000,d0	; bit 7-5 = DEVID<2:0>
		and.w	#%00011111,d1	; bit 4-0 = REVID<4:0>
		lsr.w	#5,d0
		kprintf	"    DEVID/REVID	= %lx/%lx",d0,d1
		movem.l	(sp)+,d0-a6
 	 	rts


HW_SetReceiveBuffer
		kprintf	"Set Receive Buffer"

		move.l	g_MachEnc(a6),a0

		moveq.l	#0,d0
		move.w	#ETH_RX_START,(ERXST,a0)
		move.w	(ERXST,a0),d0
		kprintf	" > ERXST = %lx",d0

		move.w	d0,g_NextPacketPointer(a6)

		move.w	(ERXTAIL,a0),d0
		kprintf	" > ERXTAIL = %lx",d0

		rts


HW_SetReceiveFilters
		kprintf	"Set Receive Filters"

		move.l	g_MachEnc(a6),a0

;At power-up, the CRC Error Rejection, Runt Error
;Rejection, Unicast Collection and Broadcast Collection
;filters are enabled
		moveq.l	#0,d0
		move.w	(ERXFCON,a0),d0
		kprintf	"> ERXFCON old = %lx",d0

DEFAULT		= ERXFCONF_CRCEN+ERXFCONF_RUNTEN+ERXFCONF_UCEN+ERXFCONF_BCEN
PROMISCUOUS	= ERXFCONF_CRCEN+ERXFCONF_RUNTEN+ERXFCONF_UCEN+ERXFCONF_NOTMEEN+ERXFCONF_MCEN

		btst	#STATEB_PROMISCUOUS,g_State(a6)
		bne.b	.promiscuous

		kprintf	"    DEFAULT mode"
		move.w	#DEFAULT,(ERXFCON,a0)
		bra.b	.done

.promiscuous	kprintf	"    PROMISCUOUS mode"
		move.w	#PROMISCUOUS,(ERXFCON,a0)

.done		moveq.l	#0,d0
		move.w	(ERXFCON,a0),d0
		kprintf	"> ERXFCON = %lx",d0

		rts

HW_EnableMAC
		kprintf	"Enable MAC"

		move.l	g_MachEnc(a6),a0
		moveq.l	#0,d0

		moveq.l	#PHANA,d0
		bsr	HW_ReadPhy
		kprintf	" > PHANA old = $%lx",d0
		and.w	#~(PHANAF_ADPAUS1+PHANAF_ADPAUS0),d0
		bset	#PHANAB_ADPAUS0,d0
		move.l	d0,d1
		moveq.l	#PHANA,d0
		bsr	HW_WritePhy
		kprintf	" > PHANA = $%lx",d0


;  Verify that the TXCRCEN (MACON2<4>) and
; PADCFG<2:0> (MACON2<7:5>) bits are set
; correctly. Most applications will not need to modify
; these settings from their power-on defaults.

		move.w	(MACON2,a0),d0
		kprintf	" > MACON2 = $%lx",d0

		move.w	(MAMXFL,a0),d0
		kprintf	" > MAMXFL = %ld",d0

		move.w	#ECON1F_RXEN,(ECON1SET,a0)
		move.w	(ECON1,a0),d0
		kprintf	" > ECON1  = $%lx",d0

		rts

HW_DisableMAC
		kprintf	"Disable MAC"
		move.l	g_MachEnc(a6),a0
		moveq.l	#0,d0

		move.w	#ECON1F_RXEN,(ECON1CLR,a0)
		move.w	(ECON1,a0),d0
		kprintf	" > ECON1  = $%lx",d0

		rts
HW_ClearSRAM:
		move.l	g_MachEnc(a6),a0

		move.l	#$6000/2-1,d0
.clear		move.w	#0,(a0)+
		adda.w	#2,a0
		dbf	d0,.clear

		rts

HW_EnableInterrupt:
		move.l	g_BoardAddr(a6),a0
		lea	MACH_INTREGS(a0),a0
		move.l	#$00010000,(a0)		; enable INT2

		move.l	g_MachEnc(a6),a0
		move.w	#EIEF_INTIE+EIEF_LINKIE+EIEF_PKTIE+EIEF_TXIE,(EIE,a0) ; 
		rts

HW_DisableInterrupt:
		move.l	g_BoardAddr(a6),a0
		lea	MACH_INTREGS(a0),a0
		move.l	#$00000000,(a0)		; disable INT2/6

		move.l	g_MachEnc(a6),a0
		move.w	#EIEF_INTIE,(EIECLR,a0)
		rts

HW_ReadPhy:	
; To read from a PHY register:
; 1. Write the address of the PHY register to read
; from into the MIREGADR register
; (Register 3-1). Make sure to also set reserved
; bit 8 of this register.
; 2. Set the MIIRD bit (MICMD<0>, Register 3-2).
; The read operation begins and the BUSY bit
; (MISTAT<0>, Register 3-3) is automatically set
; by hardware.
; 3. Wait 25.6 s. Poll the BUSY (MISTAT<0>) bit to
; be certain that the operation is complete. While
; busy, the host controller should not start any
; MIISCAN operations or write to the MIWR
; register. When the MAC has obtained the register
; contents, the BUSY bit will clear itself.
; 4. Clear the MIIRD (MICMD<0>) bit.
; 5. Read the desired data from the MIRD register.
; For 8-bit interfaces, the order that these bytes
; are read is unimportant.

		move.l	g_MachEnc(a6),a0

		and.l	#%11111,d0
;		kprintf "Read PHY reg $%lx",d0

		or.w	#$100,d0	; reserved bit 8, set high

		moveq.l	#10,d1
.busy		move.w	d0,(MIREGADR,a0)
		bset	#MICMDB_MIIRD,(MICMDL,a0)

		bsr	Wait25us

		btst	#MISTATB_BUSY,(MISTATL,a0)
		beq.b	.done

		dbf	d1,.busy
		bra.b	.error

.done		bclr	#MICMDB_MIIRD,(MICMDL,a0)
		move.w	(MIRD,a0),d0
;		kprintf " > $%lx",d0
		rts

.error:		kprintf " > PHY read %lx failed.",d0
		moveq.l	#-1,d0
		rts

HW_WritePhy:
; To write to a PHY register:
; 1. Write the address of the PHY register to write to
; into the MIREGADR register. Make sure to also
; set reserved bit 8 of this register.
; 2. Write the 16 bits of data into the MIWR register.
; The low byte must be written first, followed by
; the high byte.
; 3. Writing to the high byte of MIWR begins the
; MIIM transaction and the BUSY (MISTAT<0>)
; bit is automatically set by hardware.

		move.l	g_MachEnc(a6),a0

		and.l	#%11111,d0
;		kprintf "Write PHY reg $%lx data %lx",d0,d1

		or.w	#$100,d0	; reserved bit 8, set high

		move.w	d0,(MIREGADR,a0)
		move.w	d1,(MIWR,a0)

		moveq.l	#10,d1
.busy		bsr	Wait25us
		btst	#MISTATB_BUSY,(MISTATL,a0)
		beq.b	.done
		dbf	d1,.busy
		bra.b	.error

.done		bsr	HW_ReadPhy		; not needed
		rts

.error:		kprintf " > PHY write %lx failed.",d0
		moveq.l	#-1,d0
		rts

	; DON'T PUT ANYTHING PAST THIS END MARKER!
end
