; REPLAY XAUDIO AHI DRIVER - RELEASE 0.2ß
;------------

; General register allocation :

;	"The registers D0, D1, A0, and Al are always scratch"
;	"The values of all other data and address registers must be preserved."
;	d0 - a1 = scratch and/or context dependent
;	a2 = struct AHIAudioCtrlDrv *
;	a3 = replay (private) / ahiac_DriverData
;	a4 = xaudio base address ptr
;	a5 = replay base address ptr
;	a6 = exec base ptr
;	a7 = stack 

; all functions typically do
; func:	movem.l	d2-d7/a2-a6,-(sp)
;	...
;	movem.l	(sp)+,d2-d7/a2-a6
;	rts
; or a subset thereof

; TODO:
;	* create helper functions for alloc/free, softint start/stop, ...

; -----------
; ASM-One / AsmPro : r replay_audio.s\a\
; PhxAss:PhxAss replay_audio.s SET "AUTO,PHXASS"
; Devpac:GenAm replay_audio.s -E AUTO -E DEVPAC

;STANDALONE_TESTCODE


	IFND	AUTO
		AUTO	wo Devs:AHI/replay.audio\
	ELSE
		output	Devs:AHI/replay.audio
		IFD		DEVPAC
			opt	P=68020
		ENDC
		IFD		PHXASS
			opt	0
			machine 68020
		ENDC
	ENDC

VERSION		EQU 4
REVISION	EQU 0
DATE	MACRO
		dc.b	"19.04.17"
	ENDM
VERS	MACRO
		dc.b	"replay.audio 0.2ß"
	ENDM

VSTRING	MACRO
		VERS
		dc.b	" ("
		DATE
		dc.b	")",13,10,0
	ENDM
VERSTAG	MACRO
		dc.b	0,"$VER: "
		VERS
		dc.b	" ("
		DATE
		dc.b	")",0
	ENDM

	IFND	DEVPAC	; not supported with devpac due to 'broken' string pp

;ENABLE_KPRINTF

	ENDC

	incdir	sys:xaudio/src/
	include kprintf.i

*************************************************************************

	incdir	include:
	incdir	sys:code/ndk_3.9/include/include_i/

	include	devices/timer.i
	include	exec/exec.i
	include	utility/hooks.i

	include	libraries/ahi_sub.i
	include	libraries/expansion.i
	include	libraries/configvars.i

	include	lvo/ahi_sub_lib.i
	include	lvo/exec_lib.i
	include	lvo/expansion_lib.i
	include	lvo/timer_lib.i

*************************************************************************

XAUD_FREQ	= 28367516	; 28.367516 MHz
XAUD_SRCPTRH	= $0000
XAUD_SRCPTRL	= $0002
XAUD_STARTH	= $0004
XAUD_STARTL	= $0006
XAUD_ENDH	= $0008
XAUD_ENDL	= $000a
XAUD_VOLLEFT	= $000c
XAUD_VOLRIGHT	= $000e
XAUD_PERIODH	= $0010
XAUD_PERIODL	= $0012
XAUD_FORMATH	= $0014
XAUD_FORMATL	= $0016
XAUD_CTRLH	= $001c
XAUD_CTRLL	= $001e

*************************************************************************

TRUE	EQU	1
FALSE	EQU	0

*************************************************************************

 * replayBase (private)
	STRUCTURE replayBase,LIB_SIZE
	UBYTE	rb_Flags
	UBYTE	rb_InUse
	UWORD	rb_Pad2
	APTR	rb_SysLib
	ULONG	rb_SegList
	APTR	rb_BoardAddr
	APTR	rb_ExpLib
	APTR	rb_TimerLib
	LABEL	replayBase_SIZEOF

 * replay (private) ahiac_DriverData points to this structure.
	STRUCTURE replay,0
	UWORD	r_Disabled
	UBYTE	r_DisableInt
	UBYTE	r_Pad0
	APTR	r_ReplayBase			; Pointer to library base
	APTR	r_AudioCtrl			; Pointer to AudioCtrl struct.
	APTR	r_PlayerHook
	APTR	r_MixerHook
	APTR	r_MixBuffer
	APTR	r_MixBufferSize
	APTR	r_MixReadPtr			; Current read position in the mix buffer
	APTR	r_OutputBuffer
	APTR	r_OutputBufferAligned
	ULONG	r_OutputBufferSize
	APTR	r_OutputGetPtr			; XAUDIO hardware read ptr
	APTR	r_OutputPutPtr			; XAUDIO buffer write ptr
	ULONG	r_OutputPeriod			; XAUDIO period value
	ULONG	r_OutputVolume			; Hardware volume

	STRUCT	r_TimerPort,MP_SIZE
	STRUCT	r_TimerInt,IS_SIZE
	APTR	r_TimerReq			; Drives TimerInt_ / PlayerFunc()
	ULONG	r_TimerInterval			; Interrupt wake-up interval in us
	ULONG	r_TimerIntervalMax		; Max wake-up interval in us
	UBYTE	r_TimerDevResult		; -- " --
	UBYTE	r_TimerPad
	UWORD	r_TimerCommFlag			; TimerInt_ quit flags

	STRUCT	r_TimerVal,EV_SIZE		; Used by ec timer funcs
	ULONG	r_TimerFreq			; -- " --
	ULONG	r_TimerCalibrate		; -- " --

	LABEL	replay_SIZEOF

Start:
	IFD	STANDALONE_TESTCODE
		move.l	4.w,a6

		lea	.replayBase(pc),a0
		move.w	#.baseEnd-.replayBase,LIB_POSSIZE(a0)
		move.w	#.replayBase-.baseStart,LIB_NEGSIZE(a0)
		move.l	a0,d0

		lea	RomTag,a1
		kprintf	"Starting '%s'...",RT_NAME(a1)
		kprintf	"%s",RT_IDSTRING(a1)
		move.l	RT_INIT(a1),a1
		move.l	12(a1),a1

		suba.l	a0,a0			; seglist
		jsr	(a1)

		tst.l	d0
		beq.w	.error

		movea.l	d0,a6
		lea	.audioCtrl(pc),a2

		move.l	#AHIACF_VOL|AHIACF_PAN,ahiac_Flags(a2)
		move.l	#.soundHook,ahiac_SoundFunc(a2)
		move.l	#.playerHook,ahiac_PlayerFunc(a2)
		move.l	#50<<16,ahiac_PlayerFreq(a2)
		move.l	#3<<16,ahiac_MinPlayerFreq(a2)
		move.l	#240<<16,ahiac_MaxPlayerFreq(a2)
		move.l	#44100,ahiac_MixFreq(a2)
		move.w	#1,ahiac_Channels(a2)
		move.w	#1,ahiac_Sounds(a2)
		move.l	#.mixerHook,ahiac_MixerFunc(a2)
		move.l	#.samplerHook,ahiac_SamplerFunc(a2)
		move.l	#1024,ahiac_BuffSamples(a2)
		move.l	#64,ahiac_MinBuffSamples(a2)
		move.l	#1024*100,ahiac_MaxBuffSamples(a2)
		move.l	#1024*2*2,ahiac_BuffSize(a2)
		move.l	#AHIST_S16S,ahiac_BuffType(a2)
		move.l	#.preTimer,ahiac_PreTimer(a2)
		move.l	#.postTimer,ahiac_PostTimer(a2)

		suba.l	a1,a1			; no tags
		moveq.l	#0,d1
		lea	.emptyString(pc),a0
		move.l	a0,d2			; default arg (empty string)
		move.l	#AHIDB_Author,d0
		CALLLIB	_LVOAHIsub_GetAttr
		kprintf	"author : %s",d0
		move.l	#AHIDB_Copyright,d0
		CALLLIB	_LVOAHIsub_GetAttr
		kprintf	"copyright : %s",d0
		move.l	#AHIDB_Version,d0
		CALLLIB	_LVOAHIsub_GetAttr
		kprintf	"version : %s",d0
		move.l	#AHIDB_Annotation,d0
		CALLLIB	_LVOAHIsub_GetAttr
		kprintf	"annotaion : %s",d0

		CALLLIB	_LVOAHIsub_AllocAudio
		cmp.l	#AHISF_ERROR,d0
		beq.b	.error
		move.l	#AHIC_Output,d0
		moveq.l	#0,d1			; 0 = line
		CALLLIB	_LVOAHIsub_HardwareControl

		lea	audio(pc),a0
		bsr.b	.playsample
		bsr.b	.playsample

		CALLLIB	_LVOAHIsub_FreeAudio

		
.error		moveq	#-1,d0
;		moveq	#0,d0
		rts


.playsample
		movem.l	d0-a6,-(sp)
		lea	.containers(pc),a1
.tryagain	move.l	(a1),a4
		cmp.l	#-1,a4
		beq.w	.error
		jsr	(a4)
		beq.b	.skip
		move.l	4(a1),a4
		jsr	(a4)
		move.l	d0,ahiac_BuffType(a2)
		and.l	#%10,d0			; isolate 'stereo' bit
		lsl.w	#AHIACB_STEREO-1,d0	; or AHIACF_STEREO
		or.l	d0,ahiac_Flags(a2)
		move.l	8(a1),a4
		jsr	(a4)
		move.l	d0,ahiac_MixFreq(a2)
		divu.w	#50,d0
		move.l	d0,ahiac_BuffSamples(a2)
		move.l	12(a1),a4
		move.l	a4,.copyHandler
		move.l	a0,.sourceData

		bra.b	.startplaying
.skip		add.w	#16,a1
		bra.b	.tryagain

.startplaying
		move.l	#AHISF_PLAY,d0		
		CALLLIB	_LVOAHIsub_Start

.waitlmb	btst	#6,$bfe001
		bne	.waitlmb

		move.l	#AHISF_PLAY,d0
		CALLLIB	_LVOAHIsub_Stop
		movem.l	(sp)+,d0-a6
		rts
		

.emptyString	dc.b	"",0
		cnop	0,2
.baseStart	jmp	AHIsub_HardwareControl
		jmp	AHIsub_GetAttr
		jmp	AHIsub_UnloadSound
		jmp	AHIsub_LoadSound
		jmp	AHIsub_SetEffect
		jmp	AHIsub_SetSound
		jmp	AHIsub_SetFreq
		jmp	AHIsub_SetVol
		jmp	AHIsub_Stop
		jmp	AHIsub_Update
		jmp	AHIsub_Start
		jmp	AHIsub_Enable
		jmp	AHIsub_Disable
		jmp	AHIsub_FreeAudio
		jmp	AHIsub_AllocAudio
		jmp	LIB_ExtFunc
		jmp	LIB_Expunge
		jmp	LIB_Close
		jmp	LIB_Open
.replayBase	ds.b	replayBase_SIZEOF
.baseEnd

.audioCtrl	ds.b	AHIAudioCtrlDrv_SIZEOF
.soundHook	dc.l	0,0		; MLN_SUCC,MLN_PRED
		dc.l	.hookEntry	; h_Entry
		dc.l	0,0		; h_SubEntry,h_Data
.playerHook	dc.l	0,0		; MLN_SUCC,MLN_PRED
		dc.l	.playerEntry	; h_Entry
		dc.l	0,0		; h_SubEntry,h_Data
.mixerHook	dc.l	0,0		; MLN_SUCC,MLN_PRED
		dc.l	.mixerEntry	; h_Entry
		dc.l	0,0		; h_SubEntry,h_Data
.samplerHook	dc.l	0,0		; MLN_SUCC,MLN_PRED
		dc.l	.samplerEntry	; h_Entry
		dc.l	0,0		; h_SubEntry,h_Data

.hookEntry	kprintf	".hookEntry - nop"
		rts
.playerEntry	;kprintf	".playerEntry - nop"
		rts
.mixerEntry	;kprintf	".mixerEntry - nop"
		movem.l	d0-a6,-(sp)
		move.l	.copyHandler(pc),d0
		beq.b	.noHandler
		lea	.audioCtrl(pc),a2
		move.l	ahiac_BuffSamples(a2),d1
		move.l	d0,a2
		move.l	.sourceData(pc),a0
		move.l	.sampleOffset(pc),d0
		jsr	(a2)
		move.l	d0,.sampleOffset
.noHandler	movem.l	(sp)+,d0-a6
		rts
.samplerEntry	kprintf	".samplerEntry - nop"
		rts
.preTimer	;kprintf	".preTimer - nop"
		moveq.l	#0,d0
		btst	#10,$dff016		; skip with RMB
		seq	d0			; return TRUE to skip mixing
		tst.b	d0
		rts
.postTimer	;kprintf	".postTimer - nop"
		moveq.l	#0,d0
		rts

.containers	dc.l	.isWAVvalid,.getWAVsampletype,.getWAVrate,.copyWAVsamples
		dc.l	.isAIFvalid,.getAIFsampletype,.getAIFrate,.copyAIFsamples
		dc.l	-1
.copyHandler	dc.l	0
.sourceData	dc.l	0
.sampleOffset	dc.l	0

.isWAVvalid	cmp.l	#'RIFF',(a0)	; check "RIFF"
		bne.b	.notWAV
		cmp.l	#'WAVE',8(a0)	; check "WAVE"
		bne.b	.notWAV
		cmp.l	#'fmt ',12(a0)	; check "fmt "
		bne.b	.notWAV
		cmp.b	#16,16(a0)	; check Subchunk1Size (16 for PCM)
		bne.b	.notWAV
		cmp.b	#1,20(a0)	; check AudioFormat (1 for PCM)
		bne.b	.notWAV
		cmp.b	#1,22(a0)	; check NumChannels (MONO)
		beq.b	.okWAVchannel
		cmp.b	#2,22(a0)	; check NumChannels (STEREO)
		bne.b	.notWAV
.okWAVchannel	cmp.b	#8,34(a0)	; check BitsPerSample (8 bits)
		beq.b	.okWAVsample
		cmp.b	#16,34(a0)	; check BitsPerSample (16 bits)
		bne.b	.notWAV
.okWAVsample	moveq.l	#1,d0
		rts
.notWAV		moveq.l	#0,d0
		rts

.getWAVsampletype
		moveq.l	#AHIST_M8S,d0
		cmp.b	#1,22(a0)	; channels (1 = mono, 2 = stereo)
		beq.b	.WAVmono
		addq.w	#AHIST_S8S,d0
.WAVmono	cmp.b	#8,34(a0)
		beq.b	.WAVbyte
		addq.w	#AHIST_M16S,d0
.WAVbyte	rts

.getWAVrate	moveq.l	#0,d0
		move.b	24(a0),d0
		ror.l	#8,d0
		move.b	25(a0),d0
		ror.l	#8,d0
		move.b	26(a0),d0
		ror.l	#8,d0
		move.b	27(a0),d0
		ror.l	#8,d0
		rts

		; a0 = src data
		; a1 = dst data
		; d0 = offset
		; d1 = num samples
.copyWAVsamples	
		move.l	d0,d3
		bsr.b	.getWAVsampletype

		moveq.l	#0,d2
		move.b	40(a0),d2	; data size
		ror.l	#8,d2
		move.b	41(a0),d2
		ror.l	#8,d2
		move.b	42(a0),d2
		ror.l	#8,d2
		move.b	43(a0),d2
		ror.l	#8,d2

;		kprintf	"copy WAV samples"
;		kprintf "src ptr : %lx",a0
;		kprintf "dst ptr : %lx",a1
;		kprintf "type    : %ld",d0
;		kprintf "offset  : %ld",d3
;		kprintf "samples : %ld",d1
;		kprintf "length  : %ld",d2

		lea	44(a0),a0
		move.w	.copyWAVtable(pc,d0.w*2),d0
		jsr	.copyWAVtable(pc,d0.w)


		rts

.copyWAVtable
		dc.w	.copyWAVm8-.copyWAVtable
		dc.w	.copyWAVm16-.copyWAVtable
		dc.w	.copyWAVs8-.copyWAVtable
		dc.w	.copyWAVs16-.copyWAVtable

.copyWAVm8	;kprintf	"copyWAVmono8"
		move.w	#0,d0						; shift value
		lea	.copyWAVm8_i(pc),a3				; inner loop
		bra.w	.copySampleGeneric
.copyWAVm8_i	subq.w	#1,d7						; inner loop
.copyWAVm8_l	move.b	(a2)+,(a1)+					; inner loop
		dbf	d7,.copyWAVm8_l					; inner loop
		rts

.copyWAVm16	;kprintf	"copyWAVmono16"
		move.w	#1,d0						; shift value
		lsr.l	d0,d2						; shift value
		lea	.copyWAVm16_i(pc),a3				; inner loop
		bra.b	.copySampleGeneric
.copyWAVm16_i	subq.w	#1,d7						; inner loop
.copyWAVm16_l	move.b	(a2)+,d5					; inner loop
		move.b	(a2)+,(a1)+					; inner loop
		move.b	d5,(a1)+					; inner loop
		dbf	d7,.copyWAVm16_l				; inner loop
		rts

.copyWAVs8	;kprintf	"copyWAVstereo8"
		move.w	#1,d0						; shift value
		lsr.l	d0,d2						; shift value
		lea	.copyWAVs8_i(pc),a3				; inner loop
		bra.b	.copySampleGeneric
.copyWAVs8_i	subq.w	#1,d7						; inner loop
.copyWAVs8_l	move.w	(a2)+,(a1)+					; inner loop
		dbf	d7,.copyWAVs8_l					; inner loop
		rts

.copyWAVs16	;kprintf	"copyWAVstereo16"
		move.w	#2,d0						; shift value
		lsr.l	d0,d2						; shift value
		lea	.copyWAVs16_i(pc),a3				; inner loop
		bra.b	.copySampleGeneric
.copyWAVs16_i	subq.w	#1,d7						; inner loop
.copyWAVs16_l	move.b	(a2)+,d5					; inner loop
		move.b	(a2)+,(a1)+					; inner loop
		move.b	d5,(a1)+						; inner loop
		move.b	(a2)+,d5					; inner loop
		move.b	(a2)+,(a1)+					; inner loop
		move.b	d5,(a1)+					; inner loop
		dbf	d7,.copyWAVs16_l				; inner loop
		rts


; Generic "mixer out"
;
;	d0	sample size shift value (0 = byte, 1 = word, 2 = longword)
;	d1	num samples to mix/copy
;	d2	num samples available from source
;	d3	current sample offset in source
;	a3	copy inner loop (d7 = num samples, a2 = source, a1 = dest)
;
;RETURNS
;	d0	new offset in source
;
;DESTROYS
;	d4	temp offset/calc
;	d5/d6	sample data conversion
;	d7	loop counter
;	a1/a2	input/output
;
;

.copySampleGeneric:
		move.l	d3,d4
		lsl.l	d0,d4
		lea	(a0,d4.l),a2					; shift value
		
		; length - offset = left
		move.l	d2,d4
		sub.l	d3,d4
;		kprintf	"%ld samples left...",d4

		; left > samples
		cmp.l	d1,d4
		ble.b	.copySampleStart
		move.l	d1,d4
.copySampleStart

;		kprintf	"copy %ld samples...",d4

		move.l	d4,d7

		jsr	(a3)

		moveq.l	#0,d3
		sub.l	d4,d1
		tst.l	d1
		bne.b	.copySampleGeneric
		sub.l	a0,a2
		move.l	a2,d1
		lsr.l	d0,d1
		move.l	d1,d0						; shift value
;		kprintf	"new offset = %ld",d0

		rts



.isAIFvalid	kprintf	"isAIFvalid"
		cmp.l	#'FORM',(a0)	; check "FORM"
		bne.b	.notAIF
		cmp.l	#'AIFF',8(a0)	; check "AIFF"
		bne.b	.notAIF

		movem.l	d1/a0/a1,-(sp)

		move.l	4(a0),d0
		lea	12(a0),a0

		move.l	#'SSND',d1
		bsr.b	.getAIFchunk
		tst.l	a1
		beq.b	.notAIF		

		move.l	#'COMM',d1
		bsr.b	.getAIFchunk
		tst.l	a1
		beq.b	.notAIF		

		cmp.w	#1,8(a1)	; check NumChannels (MONO)
		beq.b	.okAIFchannel
		cmp.w	#2,8(a1)	; check NumChannels (STEREO)
		bne.b	.notAIF
.okAIFchannel
		cmp.w	#8,14(a1)	; check BitsPerSample (8 bits)
		beq.b	.okAIFsample
		cmp.w	#16,14(a1)	; check BitsPerSample (16 bits)
		bne.b	.notAIF
.okAIFsample	moveq.l	#1,d0
		movem.l	(sp)+,d1/a0/a1
		rts
.notAIF		moveq.l	#0,d0
		movem.l	(sp)+,d1/a0/a1
		rts

.getAIFchunk
		movem.l	d0/d2,-(sp)
		move.l	a0,a1
.trynextchunk	move.l	(a1)+,d2
;		kprintf	"comparing %lx with %lx",d1,d2
		cmp.l	d1,d2
		beq.b	.foundAIFchunk
		sub.l	(a1)+,d0
		beq.b	.noAIFchunk
		add.l	-4(a1),a1
		bra.b	.trynextchunk

.foundAIFchunk	sub.w	#4,a1
		movem.l	(sp)+,d0/d2
		rts
.noAIFchunk	move.l	#4,a1
		bra.b	.foundAIFchunk

.getAIFsampletype
;		kprintf	"getAIFsampletype"
		movem.l	d1/a0/a1,-(sp)
		move.l	4(a0),d0
		lea	12(a0),a0
		move.l	#'COMM',d1
		bsr.b	.getAIFchunk
		moveq.l	#AHIST_M8S,d0
		cmp.w	#1,8(a0)	; channels (1 = mono, 2 = stereo)
		beq.b	.AIFmono
		addq.w	#AHIST_S8S,d0
.AIFmono	cmp.w	#8,14(a0)
		beq.b	.AIFbyte
		addq.w	#AHIST_M16S,d0
.AIFbyte	movem.l	(sp)+,d1/a0/a1
		rts

.getAIFrate
		kprintf	"getAIFrate"
		movem.l	d1/a0/a1,-(sp)
		move.l	4(a0),d0
		lea	12(a0),a0
		pea	.returnAIFrate(pc)

		move.l	#'COMM',d1
		bsr.w	.getAIFchunk

		cmp.l	#$400DAC44,16(a1)
		beq.b	.AIF22050
		cmp.l	#$400EAC44,16(a1)
		beq.b	.AIF44100

		move.l	#44100,d0	; default
.returnAIFrate	movem.l	(sp)+,d1/a0/a1
		rts

.AIF22050	move.l	#22050,d0
		rts
.AIF44100	move.l	#44100,d0
		rts


.copyAIFsamples
;		kprintf	"copyAIFsamples"

		move.l	d0,d3
		bsr.w	.getWAVsampletype

		movem.l	d0/d1/a1,-(sp)
		move.l	4(a0),d0
		lea	12(a0),a0

		move.l	#'COMM',d1
		bsr.w	.getAIFchunk
		move.l	10(a1),d2

		move.l	#'SSND',d1
		bsr.w	.getAIFchunk
		move.l	a1,a0
		movem.l	(sp)+,d0/d1/a1

;		kprintf	"copy AIF samples"
;		kprintf "src ptr : %lx",a0
;		kprintf "dst ptr : %lx",a1
;		kprintf "type    : %ld",d0
;		kprintf "offset  : %ld",d3
;		kprintf "samples : %ld",d1
;		kprintf "length  : %ld",d2

		move.w	.copyAIFtable(pc,d0.w*2),d0
		jsr	.copyAIFtable(pc,d0.w)

		rts

.copyAIFtable
		dc.w	.copyAIFm8-.copyAIFtable
		dc.w	.copyAIFm16-.copyAIFtable
		dc.w	.copyAIFs8-.copyAIFtable
		dc.w	.copyAIFs16-.copyAIFtable

.copyAIFm8	;kprintf	"copyAIFmono8"
		move.w	#0,d0						; shift value
		lea	.copyAIFm8_i(pc),a3				; inner loop
		bra.w	.copySampleGeneric
.copyAIFm8_i	subq.w	#1,d7						; inner loop
.copyAIFm8_l	move.b	(a2)+,(a1)+					; inner loop
		dbf	d7,.copyAIFm8_l					; inner loop
		rts

.copyAIFm16	;kprintf	"copyAIFmono16"
		move.w	#1,d0						; shift value
		lea	.copyAIFm16_i(pc),a3				; inner loop
		bra.w	.copySampleGeneric
.copyAIFm16_i	subq.w	#1,d7						; inner loop
.copyAIFm16_l	move.w	(a2)+,(a1)+					; inner loop
		dbf	d7,.copyAIFm16_l				; inner loop
		rts

.copyAIFs8	;kprintf	"copyAIFstereo8"
		move.w	#1,d0						; shift value
		lea	.copyAIFs8_i(pc),a3				; inner loop
		bra.w	.copySampleGeneric
.copyAIFs8_i	subq.w	#1,d7						; inner loop
.copyAIFs8_l	move.w	(a2)+,(a1)+					; inner loop
		dbf	d7,.copyAIFs8_l					; inner loop
		rts

.copyAIFs16	;kprintf	"copyAIFstereo16"
		move.w	#2,d0						; shift value
		lea	.copyAIFs16_i(pc),a3				; inner loop
		bra.w	.copySampleGeneric
.copyAIFs16_i	subq.w	#1,d7						; inner loop
.copyAIFs16_l	move.w	(a2)+,(a1)+					; inner loop
		move.w	(a2)+,(a1)+					; inner loop
		dbf	d7,.copyAIFs16_l				; inner loop
		rts


audio:
		incbin	"111_classicbrk-39.aif"
;		incbin	"084_classicbrk-24.aif"
;		incbin	"Casio-MT-45-16-Beat.wav"
	ELSE
		moveq	#-1,d0
		rts
	ENDC	; STANDALONE_TESTCODE

*************************************************************************

RomTag:
	dc.w	RTC_MATCHWORD
	dc.l	RomTag
	dc.l	EndCode
	dc.b	RTF_AUTOINIT
	dc.b	VERSION
	dc.b	NT_LIBRARY
	dc.b	0						;pri
	dc.l	LibName
	dc.l	IDString
	dc.l	.InitTable

.InitTable:
	dc.l	replayBase_SIZEOF
	dc.l	.funcTable
	dc.l	.dataTable
	dc.l	.initRoutine

.funcTable:
	dc.l	LIB_Open
	dc.l	LIB_Close
	dc.l	LIB_Expunge
	dc.l	LIB_ExtFunc
*
	dc.l	AHIsub_AllocAudio
	dc.l	AHIsub_FreeAudio
	dc.l	AHIsub_Disable
	dc.l	AHIsub_Enable
	dc.l	AHIsub_Start
	dc.l	AHIsub_Update
	dc.l	AHIsub_Stop
	dc.l	AHIsub_SetVol
	dc.l	AHIsub_SetFreq
	dc.l	AHIsub_SetSound
	dc.l	AHIsub_SetEffect
	dc.l	AHIsub_LoadSound
	dc.l	AHIsub_UnloadSound
	dc.l	AHIsub_GetAttr
	dc.l	AHIsub_HardwareControl
	dc.l	-1

.dataTable:
	INITBYTE	LN_TYPE,NT_LIBRARY
	INITLONG	LN_NAME,LibName
	INITBYTE	LIB_FLAGS,LIBF_SUMUSED|LIBF_CHANGED
	INITWORD	LIB_VERSION,VERSION
	INITWORD	LIB_REVISION,REVISION
	INITLONG	LIB_IDSTRING,IDString
	dc.l		0

; This routine gets called after the library has been allocated.  The library pointer is
; in D0.  The segment list is in A0.  If it returns non-zero then the library will be
; linked into the library list.
.initRoutine:	; ( libptr:d0 seglist:a0 )
		movem.l	d1/a0/a1/a5/a6,-(sp)

		move.l	d0,a5
		moveq.l	#0,d0
		move.l	a6,rb_SysLib(a5)
		move.l	a0,rb_SegList(a5)

		bsr.w	GetBoardAddr
		kprintf	"Replay xaudio BoardAddr = %lx",d0
		move.l	d0,rb_BoardAddr(a5)
		moveq.l	#0,d0
		move.w	LIB_NEGSIZE(a5),d0
		kprintf	"Replay xaudio libsize (neg) = %lx",d0
		move.w	LIB_POSSIZE(a5),d0
		kprintf	"Replay xaudio libsize (pos) = %lx",d0	; replayBase_SIZEOF

		move.l	a5,d0
.exit
		movem.l	(sp)+,d1/a0/a1/a5/a6
		rts

.initFail
		moveq	#0,d0
		move.l	a5,a1
		move.w	LIB_NEGSIZE(a5),d0
		sub.l	d0,a1
		add.w	LIB_POSSIZE(a5),d0
		CALLLIB	_LVOFreeMem

		moveq	#0,d0
		bra.b	.exit

LibName:	dc.b	"replay.audio",0
timerName:	TIMERNAME
IDString:	VSTRING
		dc.b	0

	cnop	0,2

GetBoardAddr:	; ( exec:a6 )
.VENDOR		= 5060	; Replay
.PRODUCT	= 10	; xaudio
		movem.l	d1/a0/a1,-(sp)
		moveq	#0,d0
		lea	.expansionName,a1
		jsr	_LVOOpenLibrary(a6)
		tst.l	d0
		beq.b	.exit

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
		bclr	#CDB_CONFIGME,cd_Flags(a0)
;		beq.b	.findNext

		move.l	cd_BoardAddr(a0),d0

.noBoard
		move.l	a6,a1
		move.l	(sp),a6
		move.l	d0,(sp)
		jsr	_LVOCloseLibrary(a6)
		move.l	(sp)+,d0
.exit
		movem.l	(sp)+,d1/a0/a1
		rts

.expansionName:	EXPANSIONNAME

; Open returns the library pointer in d0 if the open was successful.  If the open failed
; then null is returned.  It might fail if we allocated memory on each open, or if only
; open application could have the library open at a time...
LIB_Open:	; ( libptr:a6, version:d0 ; returns libptr:d0, if successful)
		addq.w	#1,LIB_OPENCNT(a6)
		bclr.b	#LIBB_DELEXP,rb_Flags(a6)
		move.l	a6,d0
		rts

; There are two different things that might be returned from the Close routine.  If the
; library is no longer open and there is a delayed expunge then Close should return the
; segment list (as given to Init).  Otherwise close should return NULL.

LIB_Close:	; ( libptr:a6 ; returns 0:d0 or seglist:d0 )
		moveq	#0,d0
		subq.w	#1,LIB_OPENCNT(a6)
		bne.b	.exit
		btst.b	#LIBB_DELEXP,rb_Flags(a6)
		beq.b	.exit
		bsr.b	LIB_Expunge
.exit
		rts

; There are two different things that might be returned from the Expunge routine.  If
; the library is no longer open then Expunge should return the segment list (as given
; to Init).  Otherwise Expunge should set the delayed expunge flag and return NULL.
;
; One other important note: because Expunge is called from the memory allocator, it may
; NEVER Wait() or otherwise take long time to complete.

LIB_Expunge:	; ( libptr: a6 ; returns 0:d0 or seglist:d0 )
		movem.l	d1/d2/a0/a1/a5/a6,-(sp)
		move.l	a6,a5
		move.l	rb_SysLib(a5),a6
		tst.w	LIB_OPENCNT(a5)
		beq.b	.notopen
		bset.b	#LIBB_DELEXP,rb_Flags(a5)
		moveq	#0,d0
		bra.b	.end
.notopen
		move.l	a5,a1
		CALLLIB	_LVORemove

		move.l	rb_SegList(a5),d2

		moveq	#0,d0
		move.l	a5,a1
		move.w	LIB_NEGSIZE(a5),d0
		sub.l	d0,a1
		add.w	LIB_POSSIZE(a5),d0
		CALLLIB	_LVOFreeMem

		move.l	d2,d0
.end
		movem.l	(sp)+,d1/d2/a0/a1/a5/a6
		rts

LIB_ExtFunc:
		moveq	#0,d0
		rts

*************************************************************************

PrintAudioCtrl:
	IFD	ENABLE_KPRINTF
	movem.l	d0/a0,-(sp)
	lea	.table(pc),a0
	move.l	ahiac_BuffType(a2),d0
	move.l	(a0,d0.w*4),a0
	kprintf "- AHIAudioCtrlDrv.ahiac_Flags            = %lx", ahiac_Flags(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_SoundFunc        = %lx", ahiac_SoundFunc(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_PlayerFunc       = %lx", ahiac_PlayerFunc(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_PlayerFreq       = %lx", ahiac_PlayerFreq(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_MinPlayerFreq    = %lx", ahiac_MinPlayerFreq(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_MaxPlayerFreq    = %lx", ahiac_MaxPlayerFreq(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_MixFreq          = %lx", ahiac_MixFreq(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_Channels         = %x" , ahiac_Channels(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_Sounds           = %x" , ahiac_Sounds(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_DriverData       = %lx", ahiac_DriverData(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_MixerFunc        = %lx", ahiac_MixerFunc(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_SamplerFunc      = %lx", ahiac_SamplerFunc(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_Obsolete         = %lx", ahiac_Obsolete(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_BuffSamples      = %lx", ahiac_BuffSamples(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_MinBuffSamples   = %lx", ahiac_MinBuffSamples(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_MaxBuffSamples   = %lx", ahiac_MaxBuffSamples(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_BuffSize         = %lx", ahiac_BuffSize(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_BuffType         = %lx (%s)", ahiac_BuffType(a2), a0
	kprintf "- AHIAudioCtrlDrv.ahiac_PreTimer         = %lx", ahiac_PreTimer(a2)
	kprintf "- AHIAudioCtrlDrv.ahiac_PostTimer        = %lx", ahiac_PostTimer(a2)
	movem.l	(sp)+,d0/a0
	rts

.table		dc.l	.AHIST_M8S		; 0
		dc.l	.AHIST_M16S		; 1
		dc.l	.AHIST_S8S		; 2
		dc.l	.AHIST_S16S		; 3
		dc.l	.AHIST_UNK,.AHIST_UNK,.AHIST_UNK,.AHIST_UNK
		dc.l	.AHIST_M32S		; 8
		dc.l	.AHIST_UNK
		dc.l	.AHIST_S32S		; 10

.AHIST_M8S	dc.b  "AHIST_M8S  = Mono, 8 bit signed (BYTE)",0
.AHIST_M16S	dc.b  "AHIST_M16S = Mono, 16 bit signed (WORD)",0
.AHIST_S8S	dc.b  "AHIST_S8S  = Stereo, 8 bit signed (2×BYTE)",0
.AHIST_S16S	dc.b  "AHIST_S16S = Stereo, 16 bit signed (2×WORD)",0
.AHIST_M32S	dc.b  "AHIST_M32S = Mono, 32 bit signed (LONG)",0
.AHIST_S32S	dc.b  "AHIST_S32S = Stereo, 32 bit signed (2×LONG)",0
.AHIST_UNK	dc.b  "Unknown",0
	even
	ELSE
	rts
	ENDC


****** [driver].audio/--background-- ****************************************
*
*   OVERVIEW
*
*       GENERAL PROGRAMMING GUIDLINES
*
*       The driver must be able to be OpenLibrary()'ed even if the
*       hardware is not present. If a library the driver uses fails
*       to open, it is ok to fail at the library init routine, but please
*       avoid it if possible.
*
*       Please note that this document could be much better, but since not
*       many will ever need to read it, it will probably stay this way.
*       Don't hesitate to contact Martin Blom when you're writing a driver!
*
*       DRIVER VERSIONS
*
*       The lowest supported driver version is 2. If you use any feature
*       introduced in later versions of AHI, you should set the driver
*       version to the same version as the features were introduced with.
*       Example: You use PreTimer() and PostTimer(), and since these
*       calls were added in V4 of ahi.device, your driver's version should
*       be 4, too.
*
*       Note that AHI version 4 will not open V6 drivers, for obvious
*       reasons.
*
*       AUDIO ID NUMBERS
*
*       Just some notes about selecting ID numbers for different modes:
*       It is up to the driver programmer to chose which modes should be
*       available to the user. Take care when selecting.
*
*       The upper word is the hardware ID, and can only be allocated by
*       Martin Blom <lcs@lysator.liu.se>. The lower word is free, but in
*       order to allow enhancements, please only use bit 0 to 4 for modes!
*       If your driver supports multiple sound cards, use bit 12-15 to
*       select card (first one is 0). If your sound card has multiple
*       AD/DA converters, you can use bit 8-11 to select them (the first
*       should be 0).
*
*       Set the remaining bits to zero.
*
*       Use AHI:Developer/Support/ScanAudioModes to have a look at the modes
*       currently available. Use AHI:Developer/Support/sift to make sure your
*       mode descriptor file is a legal IFF file.
*
*       I do reserve the right to change the rules if I find them incorrect!
*
*****************************************************************************
*
*


****** [driver].audio/AHIsub_AllocAudio *************************************
*
*   NAME
*       AHIsub_AllocAudio -- Allocates and initializes the audio hardware.
*
*   SYNOPSIS
*       result = AHIsub_AllocAudio( tags, audioctrl);
*       D0                          A1    A2
*
*       ULONG AHIsub_AllocAudio( struct TagItem *, struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       Allocate and initialize the audio hardware. Decide if and how you
*       wish to use the mixing routines provided by 'ahi.device', by looking
*       in the AHIAudioCtrlDrv structure and parsing the tag list for tags
*       you support.
*
*       1) Use mixing routines with timing:
*           You will need to be able to play any number of samples from
*           about 80 up to 65535 with low overhead.
*           · Update AudioCtrl->ahiac_MixFreq to nearest value that your
*             hardware supports.
*           · Return AHISF_MIXING|AHISF_TIMING.
*
*       2) Use mixing routines without timing:
*           If the hardware can't play samples with any length, use this
*           alternative and provide timing yourself. The buffer must
*           take less than about 20 ms to play, preferable less than 10!
*           · Update AudioCtrl->ahiac_MixFreq to nearest value that your
*             hardware supports.
*           · Store the number of samples to mix each pass in
*             AudioCtrl->ahiac_BuffSamples.
*           · Return AHISF_MIXING
*           Alternatively, you can use the first method and call the
*           mixing hook several times in a row to fill up a buffer.
*           In that case, AHIsub_GetAttr(AHIDB_MaxPlaySamples) should
*           return the size of the buffer plus AudioCtrl->ahiac_MaxBuffSamples.
*           If the buffer is so large that it takes more than (approx.) 10 ms to
*           play it for high sample frequencies, AHIsub_GetAttr(AHIDB_Realtime)
*           should return FALSE.
*
*       3) Don't use mixing routines:
*           If your hardware can handle everything without using the CPU to
*           mix the channels, you tell 'ahi.device' this by not setting
*           either the AHISB_MIXING or the AHISB_TIMING bit.
*
*       If you can handle stereo output from the mixing routines, also set
*       bit AHISB_KNOWSTEREO.
*
*       If you can handle hifi (32 bit) output from the mixing routines,
*       set bit AHISB_KNOWHIFI.
*
*       If this driver can be used to record samples, set bit AHISB_CANRECORD,
*       too (regardless if you use the mixing routines in AHI or not).
*
*       If the sound card has hardware to do DSP effects, you can set the
*       AHISB_CANPOSTPROCESS bit. The output from the mixing routines will 
*       then be two separate buffers, one wet and one dry. You should then
*       apply the Fx on the wet buffer, and post-mix the two buffers before
*       you send the samples to the DAC. (V4)
*
*   INPUTS
*       tags - pointer to a taglist.
*       audioctrl - pointer to an AHIAudioCtrlDrv structure.
*
*   TAGS
*       The tags are from the audio database (AHIDB_#? in <devices/ahi.h>),
*       NOT the tag list the user called ahi.device/AHI_AllocAudio() with.
*
*   RESULT
*       Flags, defined in <libraries/ahi_sub.h>.
*
*   EXAMPLE
*
*   NOTES
*       You don't have to clean up on failure, AHIsub_FreeAudio() will
*       always be called.
*
*   BUGS
*
*   SEE ALSO
*       AHIsub_FreeAudio(), AHIsub_Start()
*
*****************************************************************************
*
*

AHIsub_AllocAudio:
	kprintf	"AHIsub_AllocAudio(%lx, %lx)",a1,a2

;	bsr.w   PrintAudioCtrl

	movem.l	d2-d7/a2-a6,-(sp)

	kprintf	"Replay base = %lx",a6
	moveq.l	#0,d0
	move.b	rb_InUse(a6),d0
	kprintf	"Replay InUse = %lx",d0
	tas.b	rb_InUse(a6)
	bne.w	.error_noreplay

	move.l	rb_BoardAddr(a6),d2
	kprintf	"xaudio board address = %lx",d2
	tst.l	d2
;	beq	.error_noreplay

	move.l	a6,a5

	move.l	a1,d3

* Allocate the 'replay' structure (our variables)
	move.l	rb_SysLib(a5),a6
	move.l	#replay_SIZEOF,d0
	move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
	CALLLIB	_LVOAllocVec
	move.l	d0,ahiac_DriverData(a2)
	beq.b	.error_noreplay
	move.l	d0,a3

	kprintf	"r_ReplayBase = %lx",a5
	kprintf	"ahiac_DriverData = %lx",a3
* Initialize some fields...

	st	r_TimerDevResult(a3)
	move.l	a5,r_ReplayBase(a3)
	move.l	a2,r_AudioCtrl(a3)
; ...

;#define AHISF_ERROR		(1<<0)
;#define AHISF_MIXING		(1<<1)
;#define AHISF_TIMING		(1<<2)
;#define AHISF_KNOWSTEREO	(1<<3)
;#define AHISF_KNOWHIFI		(1<<4)
;#define AHISF_CANRECORD 	(1<<5)
;#define AHISF_CANPOSTPROCESS	(1<<6)
;#define AHISF_KNOWMULTICHANNEL	(1<<7)

	move.l	#XAUD_FREQ,d0
	move.l	ahiac_MixFreq(a2),d1
	move.l	d0,d2
	divu.l	d1,d0
	divu.l	d0,d2
	move.l	d2,ahiac_MixFreq(a2)		
	

.mixing
	moveq	#AHISF_KNOWSTEREO|AHISF_MIXING|AHISF_TIMING,d0
;	moveq	#AHISF_KNOWSTEREO|AHISF_MIXING,d0

.exit
	movem.l	(sp)+,d2-d7/a2-a6
	rts

.error_noreplay
	kprintf	"Unable to find/alloc replay XAUDIO"
	moveq	#AHISF_ERROR,d0
	bra.b	.exit


;in:
* d0  Frequency
;out:
* d0  Closest frequency
* d1  Index
FindFreq:
	lea	Replay_FreqList(pc),a0
	cmp.l	(a0),d0
	bls.b	.2
.findfreq
	cmp.l	(a0)+,d0
	bhi.b	.findfreq
	move.l	-4(a0),d1
	sub.l	d0,d1
	sub.l	-8(a0),d0
	cmp.l	d1,d0
	bhs.b	.1
	subq.l	#4,a0
.1	subq.l	#4,a0
.2	move.l	(a0),d0
	move.l	a0,d1
	sub.l	#Replay_FreqList,d1
	lsr.l	#2,d1
	rts

Replay_FreqList:
	dc.l	10000
	dc.l	11025
	dc.l	12000
	dc.l	13000
	dc.l	14000
	dc.l	17640
	dc.l	18900
	dc.l	19200
	dc.l	22050
	dc.l	27348
	dc.l	32000
	dc.l	33075
	dc.l	37800
	dc.l	44100
	dc.l	48000
	dc.l	63000
	dc.l	88200
	dc.l	96000
NUM_FREQUENCIES   EQU ((*-Replay_FreqList)>>2)
	dc.l	-1

****** [driver].audio/AHIsub_FreeAudio **************************************
*
*   NAME
*       AHIsub_FreeAudio -- Deallocates the audio hardware.
*
*   SYNOPSIS
*       AHIsub_FreeAudio( audioctrl );
*                         A2
*
*       void AHIsub_FreeAudio( struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       Deallocate the audio hardware and other resources allocated in
*       AHIsub_AllocAudio(). AHIsub_Stop() will always be called by
*       'ahi.device' before this call is made.
*
*   INPUTS
*       audioctrl - pointer to an AHIAudioCtrlDrv structure.
*
*   NOTES
*       It must be safe to call this routine even if AHIsub_AllocAudio()
*       was never called, failed or called more than once.
*
*   SEE ALSO
*       AHIsub_AllocAudio()
*
*****************************************************************************
*
*

AHIsub_FreeAudio:
	kprintf	"AHIsub_FreeAudio()"
	movem.l	d2-d7/a2-a6,-(sp)

	move.l	a6,a5
	move.l	rb_SysLib(a5),a6

	move.l	ahiac_DriverData(a2),d0
	beq.b	.noreplay
	move.l	d0,a3

	move.l	rb_SysLib(a5),a6
	move.l	a3,a1
	clr.l	ahiac_DriverData(a2)
	CALLLIB	_LVOFreeVec

	clr.b	rb_InUse(a5)

.noreplay
	;moveq	#0,d0			; void function, no returncode needed
	movem.l	(sp)+,d2-d7/a2-a6
	rts


****** [driver].audio/AHIsub_Disable ****************************************
*
*   NAME
*       AHIsub_Disable -- Temporary turn off audio interrupt/task
*
*   SYNOPSIS
*       AHIsub_Disable( audioctrl );
*                       A2
*
*       void AHIsub_Disable( struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       If you are lazy, then call exec.library/Disable().
*       If you are smart, only disable your own interrupt or task.
*
*   INPUTS
*       audioctrl - pointer to an AHIAudioCtrlDrv structure.
*
*   NOTES
*       This call should be guaranteed to preserve all registers.
*       V6 drivers do NOT have to preserve all registers.
*       This call nests.
*
*   SEE ALSO
*       AHIsub_Enable(), exec.library/Disable()
*
*****************************************************************************
*
*
*

AHIsub_Disable:
;	kprintf	"AHIsub_Disable()"
	movem.l	a3/a6,-(sp)
	move.l	ahiac_DriverData(a2),a3
	move.l	r_ReplayBase(a3),a6
	move.l	rb_SysLib(a6),a6
;	call	Disable
	st	r_DisableInt(a3)
	movem.l	(sp)+,a3/a6
	rts


****** [driver].audio/AHIsub_Enable *****************************************
*
*   NAME
*       AHIsub_Enable -- Turn on audio interrupt/task
*
*   SYNOPSIS
*       AHIsub_Enable( audioctrl );
*                      A2
*
*       void AHIsub_Enable( struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       If you are lazy, then call exec.library/Enable().
*       If you are smart, only enable your own interrupt or task.
*
*   INPUTS
*       audioctrl - pointer to an AHIAudioCtrlDrv structure.
*
*   NOTES
*       This call should be guaranteed to preserve all registers.
*       V6 drivers do NOT have to preserve all registers.
*       This call nests.
*
*   SEE ALSO
*       AHIsub_Disable(), exec.library/Enable()
*
*****************************************************************************
*
*
*

AHIsub_Enable:
;	kprintf	"AHIsub_Enable()"
	movem.l	a3/a6,-(sp)
	move.l	ahiac_DriverData(a2),a3
	move.l	r_ReplayBase(a3),a6
	move.l	rb_SysLib(a6),a6
;	call	Enable
	clr.b	r_DisableInt(a3)
	movem.l	(sp)+,a3/a6
	rts


****** [driver].audio/AHIsub_Start ******************************************
*
*   NAME
*       AHIsub_Start -- Starts playback or recording
*
*   SYNOPSIS
*       error = AHIsub_Start( flags, audioctrl );
*       D0                    D0     A2
*
*       ULONG AHIsub_Start(ULONG, struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       What to do depends what you returned in AHIsub_AllocAudio().
*
*     * First, assume bit AHISB_PLAY in flags is set. This means that you
*       should begin playback.
*
*     - AHIsub_AllocAudio() returned AHISF_MIXING|AHISF_TIMING:
*
*       A) Allocate a mixing buffer of ahiac_BuffSize bytes. The buffer must
*          be long aligned!
*       B) Create/start an interrupt or task that will do 1-6 over and over
*          again until AHIsub_Stop() is called. Note that it is not a good
*          idea to do the actual mixing and conversion in a real hardware
*          interrupt. Signal a task or create a Software Interrupt to do
*          the number crunching.
*
*       1) Call the user Hook ahiac_PlayerFunc with the following parameters:
*                  A0 - (struct Hook *)
*                  A2 - (struct AHIAudioCtrlDrv *)
*                  A1 - Set to NULL.
*
*       2) [Call the ahiac_PreTimer function. If it returns TRUE (Z will be
*          cleared so you don't have to test d0), skip step 3 and 4. This
*          is used to avoid overloading the CPU. This step is optional.
*          A2 is assumed to point to struct AHIAudioCtrlDrv. All registers
*          except d0 are preserved. (V4)
*
*          Starting with V6, you can also call the pre-timer Hook
*          (ahiac_PreTimerFunc) with the following parameters:
*                  A0 - (struct Hook *)           - The Hook itself
*                  A2 - (struct AHIAudioCtrlDrv *)
*                  A1 - Set to NULL.
*          The Hook is not guaranteed to preserve all registers and
*          you must check the return value and not rely on the Z flag. (V6)
*
*          This step, 2, is optional.]
*
*       3) Call the mixing Hook (ahiac_MixerFunc) with the following
*          parameters:
*                  A0 - (struct Hook *)           - The Hook itself
*                  A2 - (struct AHIAudioCtrlDrv *)
*                  A1 - (WORD *[])                - The mixing buffer.
*          Note that ahiac_MixerFunc preserves ALL registers.
*          The user Hook ahiac_SoundFunc will be called by the mixing
*          routine when a sample have been processed, so you don't have to
*          worry about that.
*          How the buffer will be filled is indicated by ahiac_Flags.
*          It is always filled with signed 16-bit (32 bit if AHIACB_HIFI in
*          in ahiac_Flags is set) words, even if playback is 8 bit. If
*          AHIDBB_STEREO is set (in ahiac_Flags), data for left and right
*          channel are interleaved:
*           1st sample left channel,
*           1st sample right channel,
*           2nd sample left channel,
*           ...,
*           ahiac_BuffSamples:th sample left channel,
*           ahiac_BuffSamples:th sample right channel.
*          If AHIDBB_STEREO is cleared, the mono data is stored:
*           1st sample,
*           2nd sample,
*           ...,
*           ahiac_BuffSamples:th sample.
*          Note that neither AHIACB_STEREO nor AHIACB_HIFI will be set if
*          you didn't report that you understand these flags when
*          AHI_AllocAudio() was called.
*
*          For AHI V2, the type of buffer is also available in ahiac_BuffType.
*          It is suggested that you use this value instead. ahiac_BuffType
*          can be one of AHIST_M16S, AHIST_S16S, AHIST_M32S and AHIST_S32S.
*
*       4) Convert the buffer if needed and feed it to the audio hardware.
*          Note that you may have to clear CPU caches if you are using DMA
*          to play the buffer, and the buffer is not allocated in non-
*          cachable RAM (which is not a good idea anyway, for performace
*          reasons).
*
*       5) [Call the ahiac_PostTimer function. A2 is assumed to point to
*          struct AHIAudioCtrlDrv. All registers are preserved. (V4)
*
*          Starting with V6, you can also call the post-timer Hook
*          (ahiac_PostTimerFunc) with the following parameters:
*                  A0 - (struct Hook *)           - The Hook itself
*                  A2 - (struct AHIAudioCtrlDrv *)
*                  A1 - Set to NULL.
*          The Hook is not guaranteed to preserve all registers. (V6)
*
*          This step, 5, is optional.]
*
*       6) Wait until the whole buffer has been played, then repeat.
*
*       Use double buffering if possible!
*
*       You may DECREASE ahiac_BuffSamples slightly, for example to force an
*       even number of samples to be mixed. By doing this you will make
*       ahiac_PlayerFunc to be called at wrong frequency so be careful!
*       Even if ahiac_BuffSamples is defined ULONG, it will never be greater
*       than 65535.
*
*       ahiac_BuffSize is the largest size of the mixing buffer that will be
*       needed until AHIsub_Stop() is called.
*
*       ahiac_MaxBuffSamples is the maximum number of samples that will be
*       mixed (until AHIsub_Stop() is called). You can use this value if you
*       need to allocate DMA buffers.
*
*       ahiac_MinBuffSamples is the minimum number of samples that will be
*       mixed. Most drivers will ignore it.
*
*       If AHIsub_AllocAudio() returned with the AHISB_CANPOSTPROCESS bit set,
*       ahiac_BuffSize is large enough to hold two buffers. The mixing buffer
*       will be filled with the wet buffer first, immediately followed by the
*       dry buffer. I.e., ahiac_BuffSamples sample frames wet data, then
*       ahiac_BuffSamples sample frames dry data. The DSP fx should only be
*       applied to the wet buffer, and the two buffers should then be added
*       together. (V4)
*
*     - If AHIsub_AllocAudio() returned AHISF_MIXING, do as described above,
*       except calling ahiac_PlayerFunc. ahiac_PlayerFunc should be called
*       ahiac_PlayerFreq times per second, clocked by timers on your sound
*       card or by using 'timer.device' or 'realtime.library'. No other Amiga
*       resources may be used for timing (like direct CIA timers).
*       ahiac_MinBuffSamples and ahiac_MaxBuffSamples are undefined if
*       AHIsub_AllocAudio() returned AHISF_MIXING (AHISB_TIMING bit not set).
*
*     - If AHIsub_AllocAudio() returned with neither the AHISB_MIXING nor
*       the AHISB_TIMING bit set, then just start playback. Don't forget to
*       call ahiac_PlayerFunc ahiac_PlayerFreq times per second. Only your
*       own timing hardware, 'timer.device'  or 'realtime.library' may be
*       used. Note that ahiac_MixerFunc, ahiac_BuffSamples,
*       ahiac_MinBuffSamples, ahiac_MaxBuffSamples and ahiac_BuffSize are
*       undefined. ahiac_MixFreq is the frequency the user wants to use for
*       recording, if you support that.
*
*     * Second, assume bit AHISB_RECORD in flags is set. This means that you
*       should start to sample. Create a interrupt or task that does the
*       following:
*
*       Allocate a buffer (you chose size, but try to keep it reasonable
*       small to avoid delays - it is suggested that RecordFunc is called
*       at least 4 times/second for the lowers sampling rate, and more often
*       for higher rates), and fill it with the sampled data. The buffer must
*       be long aligned, and it's size must be evenly divisible by four.
*       The format should always be AHIST_S16S (even with 8 bit mono samplers),
*       which means:
*           1st sample left channel,
*           1st sample right channel (same as prev. if mono),
*           2nd sample left channel,
*           ... etc.
*       Each sample is a signed word (WORD). The sample rate should be equal
*       to the mixing rate.
*
*       Call the ahiac_SamplerFunc Hook with the following parameters:
*           A0 - (struct Hook *)           - The Hook itself
*           A2 - (struct AHIAudioCtrlDrv *)
*           A1 - (struct AHIRecordMessage *)
*       The message should be filled as follows:
*           ahirm_Type - Set to AHIST_S16S.
*           ahirm_Buffer - A pointer to the filled buffer.
*           ahirm_Samples - How many sample frames stored.
*       You must not destroy the buffer until next time the Hook is called.
*
*       Repeat until AHIsub_Stop() is called.
*
*     * Note that both bits may be set when this function is called.
*
*   INPUTS
*       flags - See <libraries/ahi_sub.h>.
*       audioctrl - pointer to an AHIAudioCtrlDrv structure.
*
*   RESULT
*       Returns AHIE_OK if successful, else an error code as defined
*       in <devices/ahi.h>. AHIsub_Stop() will always be called, even
*       if this call failed.
*
*   NOTES
*       The driver must be able to handle multiple calls to this routine
*       without preceding calls to AHIsub_Stop().
*
*   SEE ALSO
*       AHIsub_Update(), AHIsub_Stop()
*
*****************************************************************************
*
*
*

AHIsub_Start:
	kprintf	"AHIsub_Start()"

	bsr.w   PrintAudioCtrl

	movem.l	d2-d7/a2-a6,-(sp)

	move.l	d0,d7
	move.l	ahiac_DriverData(a2),a3

	btst	#AHISB_PLAY,d7
	beq.w	.dont_play

**
*** AHISB_PLAY
**
	moveq	#AHISF_PLAY,d0
	CALLLIB	_LVOAHIsub_Stop			;Stop current playback if any.
	CALLLIB	_LVOAHIsub_Update			;fill variables

	move.l	r_TimerInterval(a3),r_TimerIntervalMax(a3)

	move.l	a6,a5
	move.l	rb_SysLib(a5),a6

	move.l	ahiac_BuffSize(a2),d0

	; Don't trust BuffSize - compare against the max samples copied
	move.l	ahiac_MaxBuffSamples(a2),d1
	move.l	ahiac_Flags(a2),d2
	and.l	#AHIACF_STEREO,d2
	lsr.w	#AHIACB_STEREO,d2
	add.w	#1,d2
	lsl.l	d2,d1

	cmp.l	d1,d0
	bge.b	.bufsizeok
	move.l	d1,d0
	kprintf	"ahiac_BuffSize is too small! Calculated size = %ld",d0

.bufsizeok
	kprintf	"Mixing buffer is %lx bytes",d0
	move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
	CALLLIB	_LVOAllocVec


	kprintf	"Mixing buffer at %lx",d0

	move.l	d0,r_MixBuffer(a3)
	beq	.error_nomem


	clr.l	r_MixBufferSize(a3)
	move.l	d0,r_MixReadPtr(a3)


	move.l	ahiac_MixFreq(a2),d0
	move.l	ahiac_PlayerFreq(a2),d1
	cmp.l	#$10000,d1				; freq can be both 16.16 fixed point or not ?!
	blo.b	.valok
	clr.w	d1
	swap	d1
.valok	divu.l	d1,d0
	add.l	d0,d0					; buffer 2x sample speed

	; d0 = BuffSamples * 2 - should be enough(?)
	
;	move.l	ahiac_MaxBuffSamples(a2),d0
;	add.l	d0,d0					; buffer 2x sample speed
	lsl.l	#2,d0					; multiply by 4 because output is always 16 bit stereo
	add.l	#15,d0					; need 16byte alignment size
	and.l	#~15,d0
	move.l	d0,r_OutputBufferSize(a3)
	add.l	#15,d0					; need 16byte alignment ptr
	move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
	CALLLIB	_LVOAllocVec
	move.l	d0,r_OutputBuffer(a3)
	beq	.error_nomem

	add.l	#15,d0
	and.l	#~15,d0
	move.l	d0,r_OutputBufferAligned(a3)


	kprintf	"Output (DMA) buffer at $%lx",r_OutputBufferAligned(a3)
	kprintf	"Output (DMA) buffer is $%lx bytes",r_OutputBufferSize(a3)

	move.l	r_OutputBufferAligned(a3),r_OutputGetPtr(a3)
	move.l	r_OutputBufferAligned(a3),r_OutputPutPtr(a3)

	move.l	#XAUD_FREQ,d0
	move.l	ahiac_MixFreq(a2),d1
	divu.l	d1,d0
;	ext.l	d0
	kprintf	"Output (DMA) Period is %ld",d0
	move.l	d0,r_OutputPeriod(a3)

;	bsr.w   PrintAudioCtrl

	; pre-mix XAUDIO buffer content - this minimizes startup latency
	move.l	r_OutputBufferAligned(a3),d0
	add.l	r_OutputBufferSize(a3),d0
	move.l	d0,r_OutputGetPtr(a3)
	bsr	FillOutputBuffer_entry
	move.l	r_OutputBufferAligned(a3),r_OutputGetPtr(a3)

; poke xaudio hw
	move.l	rb_BoardAddr(a5),d4
	beq.b	.nohw
	move.l	d4,a4
	move.l	r_OutputBufferAligned(a3),a1
	move.l	a1,a2
	add.l	r_OutputBufferSize(a3),a2
	suba.w	#4,a2

	move.l	a1,XAUD_SRCPTRH(a4)
	move.l	a1,XAUD_STARTH(a4)
	move.l	a2,XAUD_ENDH(a4)

	move.l	#$80008000,XAUD_VOLLEFT(a4)

	move.l	r_OutputPeriod(a3),XAUD_PERIODH(a4)
;	move.l	#643,XAUD_PERIODH(a4)	; 28.367516 MHz / 44100 Hz

	move.l	#1,XAUD_CTRLH(a4)

.nohw	bsr	TimerInt_Start
	bra	.exit

; ...

.dont_play
	btst	#AHISB_RECORD,d7
	beq.b	.dont_record
**
*** AHISB_RECORD
**

	moveq	#AHISF_RECORD,d0
	CALLLIB	_LVOAHIsub_Stop			;Stop current recording if any.

	move.l	a6,a5
	move.l	rb_SysLib(a5),a6

; ...

.dont_record
.return
	moveq	#AHIE_OK,d0
.exit
	movem.l	(sp)+,d2-d7/a2-a6
	rts
.error_nomem
	kprintf	"ERROR : unable to allocate buffers"
	moveq	#AHIE_NOMEM,d0
	bra.b	.exit
.error_unknown
	kprintf	"ERROR : unknown error"
	moveq	#AHIE_UNKNOWN,d0
	bra.b	.exit



****** [driver].audio/AHIsub_Update *****************************************
*
*   NAME
*       AHIsub_Update -- Update some variables
*
*   SYNOPSIS
*       AHIsub_Update( flags, audioctrl );
*                      D0     A2
*
*       void AHIsub_Update(ULONG, struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       All you have to do is to reread some variables:
*
*     * Mixing & timing: ahiac_PlayerFunc, ahiac_MixerFunc, ahiac_SamplerFunc,
*       ahiac_BuffSamples (and perhaps ahiac_PlayerFreq if you use it).
*
*     * Mixing only: ahiac_PlayerFunc, ahiac_MixerFunc, ahiac_SamplerFunc and
*           ahiac_PlayerFreq.
*
*     * Nothing: ahiac_PlayerFunc, ahiac_SamplerFunc and ahiac_PlayerFreq.
*
*   INPUTS
*       flags - Currently no flags defined.
*       audioctrl - pointer to an AHIAudioCtrlDrv structure.
*
*   RESULT
*
*   NOTES
*       This call must be safe from interrupts.
*
*   SEE ALSO
*       AHIsub_Start()
*
*****************************************************************************
*
*
*

AHIsub_Update:
	kprintf	"AHIsub_Update()"
	movem.l	d2-d7/a2-a6,-(sp)

	CALLLIB	_LVOAHIsub_Disable		;make sure we don't get an interrupt
								;while updating our local variables
	move.l	ahiac_DriverData(a2),a3

	move.l	ahiac_PlayerFunc(a2),r_PlayerHook(a3)

	move.l	ahiac_PlayerFreq(a2),d0
	cmp.l	#$10000,d0
	bge.b	.valok
	swap	d0
.valok	lsr.l	#8,d0
	move.l	#256*1000*1000,d1
	divu.l	d0,d1
	tst.l	r_TimerInterval(a3)
	beq.b	.set
	cmp.l	r_TimerIntervalMax(a3),d1
	bhi.b	.tooslow
.set	kprintf	"mix interval = %ld us",d1
	move.l	d1,r_TimerInterval(a3)
.tooslow
	kprintf	 "ahiac_PlayerFreq is $%lx", ahiac_PlayerFreq(a2)
	kprintf	 "ahiac_BuffSamples is %ld", ahiac_BuffSamples(a2)

	move.l	ahiac_MixerFunc(a2),r_MixerHook(a3)

.exit
	CALLLIB	_LVOAHIsub_Enable
	;moveq	#0,d0			; void function, no returncode needed
	movem.l	(sp)+,d2-d7/a2-a6
	rts


****** [driver].audio/AHIsub_Stop *******************************************
*
*   NAME
*       AHIsub_Stop -- Stops playback.
*
*   SYNOPSIS
*       AHIsub_Stop( flags, audioctrl );
*                    D0     A2
*
*       void AHIsub_Stop( ULONG, struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       Stop playback and/or recording, remove all resources allocated by
*       AHIsub_Start().
*
*   INPUTS
*       flags - See <libraries/ahi_sub.h>.
*       audioctrl - pointer to an AHIAudioCtrlDrv structure.
*
*   NOTES
*       It must be safe to call this routine even if AHIsub_Start() was never
*       called, failed or called more than once.
*
*   SEE ALSO
*       AHIsub_Start()
*
*****************************************************************************
*
*

AHIsub_Stop:
	kprintf	"AHIsub_Stop()"
	movem.l	d2-d7/a2-a6,-(sp)

	move.l	a6,a5
	move.l	rb_SysLib(a5),a6
	move.l	ahiac_DriverData(a2),a3

	move.l	d0,-(sp)
	btst	#AHISB_PLAY,d0
	beq.b	.dontplay

**
*** AHISB_PLAY
**
	; Check enabled tags here..
	nop

	move.l	rb_BoardAddr(a5),d4
	beq.b	.nohw
	move.l	d4,a4
	move.l	#0,XAUD_CTRLH(a4)

.nohw	bsr	TimerInt_Stop

	clr.l	r_TimerInterval(a3)

	move.l	r_MixBuffer(a3),d0
	beq.b	.nomixbuffer
	move.l	d0,a1
	CALLLIB	_LVOFreeVec
	clr.l	r_MixBuffer(a3)

.nomixbuffer	
	move.l	r_OutputBuffer(a3),d0
	beq.b	.nooutputbuffer
	move.l	d0,a1
	CALLLIB	_LVOFreeVec
	clr.l	r_OutputBuffer(a3)
.nooutputbuffer
;	bra	.playchecked

;-----

.playchecked

.dontplay
	move.l	(sp)+,d0
	btst	#AHISB_RECORD,d0
	beq.w	.dontrecord

**
*** AHISB_RECORD
**

.dontrecord
.exit
	;moveq	#0,d0			; void function, no returncode needed
	movem.l	(sp)+,d2-d7/a2-a6
	rts


****** [driver].audio/AHIsub_GetAttr ****************************************
*
*   NAME
*       AHIsub_GetAttr -- Returns information about audio modes or driver
*
*   SYNOPSIS
*       AHIsub_GetAttr( attribute, argument, default, taglist, audioctrl );
*       D0              D0         D1        D2       A1       A2
*
*       LONG AHIsub_GetAttr( ULONG, LONG, LONG, struct TagItem *,
*                            struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       Return the attribute based on a tag list and an AHIAudioCtrlDrv
*       structure, which are the same that will be passed to
*       AHIsub_AllocAudio() by 'ahi.device'. If the attribute is
*       unknown to you, return the default.
*
*   INPUTS
*       attribute - Is really a Tag and can be one of the following:
*
*           AHIDB_Bits - Return how many output bits the tag list will
*               result in.
*
*           AHIDB_MaxChannels - Return the maximum number of channels.
*
*           AHIDB_Frequencies - Return how many mixing/sampling frequencies
*               you support
*
*           AHIDB_Frequency - Return the argument:th frequency
*               Example: You support 3 frequencies; 32, 44.1 and 48 kHz.
*                   If argument is 1, return 44100.
*
*           AHIDB_Index - Return the index which gives the frequency closest
*               to argument.
*               Example: You support 3 frequencies; 32, 44.1 and 48 kHz.
*                   If argument is 40000, return 1 (=> 44100).
*
*           AHIDB_Author - Return pointer to name of driver author:
*               "Martin 'Leviticus' Blom"
*
*           AHIDB_Copyright - Return pointer to copyright notice, including
*               the '©' character: "© 1996 Martin Blom" or "Public Domain"
*
*           AHIDB_Version - Return pointer version string, normal Amiga
*               format: "paula 1.5 (18.2.96)\r\n"
*
*           AHIDB_Annotation - Return pointer to an annotation string, which
*               can be several lines.
*
*           AHIDB_Record - Are you a sampler, too? Return TRUE or FALSE.
*
*           AHIDB_FullDuplex - Return TRUE or FALSE.
*
*           AHIDB_Realtime - Return TRUE or FALSE.
*
*           AHIDB_MaxPlaySamples - Normally, return the default. See
*               AHIsub_AllocAudio(), section 2.
*
*           AHIDB_MaxRecordSamples - Return the size of the buffer you fill
*               when recording.
*
*           The following are associated with AHIsub_HardwareControl() and are
*           new for V2.
*
*           AHIDB_MinMonitorVolume
*           AHIDB_MaxMonitorVolume - Return the lower/upper limit for
*               AHIC_MonitorVolume. If unsupported but always 1.0, return
*               1.0 for both.
*
*           AHIDB_MinInputGain
*           AHIDB_MaxInputGain - Return the lower/upper limit for
*               AHIC_InputGain. If unsupported but always 1.0, return 1.0 for
*               both.
*
*           AHIDB_MinOutputVolume
*           AHIDB_MaxOutputVolume - Return the lower/upper limit for
*               AHIC_OutputVolume.
*
*           AHIDB_Inputs - Return how many inputs you have.
*           AHIDB_Input - Return a short string describing the argument:th
*               input. Number 0 should be the default one. Example strings
*               can be "Line 1", "Mic", "Optical" or whatever.
*
*           AHIDB_Outputs - Return how many outputs you have.
*           AHIDB_Output - Return a short string describing the argument:th
*               output. Number 0 should be the default one. Example strings
*               can be "Line 1", "Headphone", "Optical" or whatever.
*
*       argument - extra info for some attributes.
*       default - What you should return for unknown attributes.
*       taglist - Pointer to a tag list that eventually will be fed to
*           AHIsub_AllocAudio(), or NULL.
*       audioctrl - Pointer to an AHIAudioCtrlDrv structure that eventually
*           will be fed to AHIsub_AllocAudio(), or NULL.
*
*   NOTES
*
*   SEE ALSO
*       AHIsub_AllocAudio(), AHIsub_HardwareControl(),
*       ahi.device/AHI_GetAudioAttrsA()
*
*****************************************************************************
*
*

AHIsub_GetAttr:
	move.l  d3,-(sp)
	move.l	d0,d3
	sub.l	#$80000064,d3
	kprintf	"AHIsub_GetAttr(%lx = %ld) arg = %lx; defalt = %lx]",d0,d3,d1,d2
	move.l 	(sp)+,d3
	movem.l	d2-d7/a2-a6,-(sp)
	move.l	a1,a3
	move.l	a6,a5

	moveq	#FALSE,d3		; HIFI
	moveq	#FALSE,d4		; MONO

	movem.l	d0-d1,-(sp)

	move.l	a3,a0
	move.l	a3,d0
	beq.w	.notaglist

	; GetTagData here.. 

.notaglist

	movem.l	(sp)+,d0-d1

	and.l	#~(AHI_TagBaseR),d0
	cmp.l	#AHIDB_Data&~(AHI_TagBaseR),d0
	bhi.b	.default
	sub.w	#100,d0
	lsl.w	#1,d0
	move.w	.jt(pc,d0.w),d0
	beq.b	.default
	jsr		.jt(pc,d0.w)

.exit
	kprintf	"                    return = %lx",d0
	movem.l	(sp)+,d2-d7/a2-a6
	rts

.default
	move.l	d2,d0
	bra.b	.exit

.jt
	dc.w	0				; AHIDB_AudioID
	dc.w	0				; AHIDB_Driver
	dc.w	0				; AHIDB_Flags
	dc.w	ga_Volume-.jt			; AHIDB_Volume
	dc.w	ga_Panning-.jt			; AHIDB_Panning
	dc.w	ga_Stereo-.jt			; AHIDB_Stereo
	dc.w	ga_HiFi-.jt			; AHIDB_HiFi
	dc.w	ga_PingPong-.jt			; AHIDB_PingPong
	dc.w	0				; AHIDB_MultTable
	dc.w	0				; AHIDB_Name
	dc.w	ga_Bits-.jt			; AHIDB_Bits
	dc.w	ga_MaxChannels-.jt		; AHIDB_MaxChannels
	dc.w	0				; AHIDB_MinMixFreq
	dc.w	0				; AHIDB_MaxMixFreq
	dc.w	ga_Record-.jt			; AHIDB_Record
	dc.w	ga_Frequencies-.jt		; AHIDB_Frequencies
	dc.w	0				; AHIDB_FrequencyArg
	dc.w	ga_Frequency-.jt		; AHIDB_Frequency
	dc.w	ga_Author-.jt			; AHIDB_Author
	dc.w	ga_Copyright-.jt		; AHIDB_Copyright
	dc.w	ga_Version-.jt			; AHIDB_Version
	dc.w	ga_Annotation-.jt		; AHIDB_Annotation
	dc.w	0				; AHIDB_BufferLen
	dc.w	0				; AHIDB_IndexArg
	dc.w	ga_Index-.jt			; AHIDB_Index
	dc.w	ga_Realtime-.jt			; AHIDB_Realtime
	dc.w	0;ga_MaxPlaySamples-.jt		; AHIDB_MaxPlaySamples
	dc.w	ga_MaxRecordSamples-.jt		; AHIDB_MaxRecordSample
	dc.w	0				; 
	dc.w	ga_FullDuplex-.jt		; AHIDB_FullDuplex
	dc.w	ga_MinMonitorVolume-.jt		; AHIDB_MinMonitorVolum
	dc.w	ga_MaxMonitorVolume-.jt		; AHIDB_MaxMonitorVolum
	dc.w	ga_MinInputGain-.jt		; AHIDB_MinInputGain
	dc.w	ga_MaxInputGain-.jt		; AHIDB_MaxInputGain
	dc.w	ga_MinOutputVolume-.jt		; AHIDB_MinOutputVolume
	dc.w	ga_MaxOutputVolume-.jt		; AHIDB_MaxOutputVolume
	dc.w	ga_Inputs-.jt			; AHIDB_Inputs
	dc.w	0				; AHIDB_InputArg
	dc.w	ga_Input-.jt			; AHIDB_Input
	dc.w	ga_Outputs-.jt			; AHIDB_Outputs
	dc.w	0				; AHIDB_OutputArg
	dc.w	ga_Output-.jt			; AHIDB_Output
	dc.w	0				; AHIDB_Data


*** The tags AHIDB_Volume, AHIDB_Panning, AHIDB_Stereo and AHIDB_HiFi are
*** parameters to the mixing routine when mixing, but attributes in DMA mode.

ga_Volume:
	move.l	d2,d0
	tst.l	d4
	beq.b	.exit
	moveq	#TRUE,d0
.exit
	rts

ga_Panning:
	moveq	#TRUE,d0
	rts

ga_Stereo:
	moveq	#TRUE,d0
	rts

ga_HiFi:
	moveq	#FALSE,d0
	rts

ga_PingPong:
	moveq	#FALSE,d0
	rts

ga_Bits:
	moveq	#16,d0
	rts

ga_MaxChannels:
	moveq	#1,d0
	rts

ga_Record:
	moveq	#FALSE,d0
	rts

ga_Frequencies:
	moveq.l	#NUM_FREQUENCIES,d0
	rts

ga_Frequency:
	lea		Replay_FreqList(pc),a0
	move.l	(a0,d1.w*4),d0
	rts

ga_Author:
	lea		.author(pc),a0
	move.l	a0,d0
	rts
.author		dc.b	"Erik 'eriQue' Hemming",0
	even

ga_Copyright:
	lea		.copyright(pc),a0
	move.l	a0,d0
	rts
.copyright	dc.b	"© 2017 All rights reserved",0
	even

ga_Version:
	lea		IDString(pc),a0
	move.l	a0,d0
	rts

ga_Annotation:
	lea		.anno(pc),a0
	move.l	a0,d0
	rts
.anno		dc.b	"WWW.FPGAArcade.COM - No Emulation No Compromise",$d,$a,0
	even

ga_Index:
	move.l	d1,d0
	bsr		FindFreq
	move.l	d1,d0
	rts

ga_Realtime:
	moveq	#TRUE,d0
	rts

ga_MaxPlaySamples:
	move.l	#$372,d0
	rts

ga_MaxRecordSamples:
	moveq.l	#0,d0
	rts

ga_FullDuplex:
	moveq	#FALSE,d0
	rts


ga_MinMonitorVolume:
	move.l	d2,d0
	rts

ga_MaxMonitorVolume:
	move.l	d2,d0
	rts

ga_MinInputGain:
	move.l	d2,d0
	rts

ga_MaxInputGain:
	move.l	d2,d0
	rts

ga_MinOutputVolume:
	moveq.l	#0,d0
	rts

ga_MaxOutputVolume:
	move.l	#$10000,d0
	rts

ga_Inputs:
	moveq	#0,d0
	rts

ga_Input:
	moveq	#0,d0
	rts

ga_Outputs:
	moveq	#1,d0
	rts

ga_Output:
	lea.l	.output(pc),a0
	move.l	a0,d0
	rts
.output		dc.b	"Line",0
	even


****** [driver].audio/AHIsub_HardwareControl ********************************
*
*   NAME
*       AHIsub_HardwareControl -- Modify sound card settings
*
*   SYNOPSIS
*       AHIsub_HardwareControl( attribute,  argument, audioctrl );
*       D0                      D0          D1        A2
*
*       LONG AHIsub_HardwareControl( ULONG, LONG, struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       Set or return the state of a particular hardware component. AHI uses
*       AHIsub_GetAttr() to supply the user with limits and what tags are
*       available.
*
*   INPUTS
*       attribute - Is really a Tag and can be one of the following:
*
*           AHIC_MonitorVolume - Set the input monitor volume to argument.
*           AHIC_MonitorVolume_Query - Return the current input monitor
*               volume (argument is ignored).
*
*           AHIC_InputGain - Set the input gain to argument. (V2)
*           AHIC_InputGain_Query (V2)
*
*           AHIC_OutputVolume - Set the output volume to argument. (V2)
*           AHIC_OutputVolume_Query (V2)
*
*           AHIC_Input - Use the argument:th input source (default is 0). (V2)
*           AHIC_Input_Query (V2)
*
*           AHIC_Output - Use the argument:th output destination (default
*               is 0). (V2)
*           AHIC_Output_Query (V2)
*
*       argument - What value attribute should be set to.
*       audioctrl - Pointer to an AHIAudioCtrlDrv structure.
*
*   RESULT
*       Return the state of selected attribute. If you were asked to set
*       something, return TRUE. If attribute is unknown to you or unsupported,
*       return FALSE.
*
*   NOTES
*       This call must be safe from interrupts.
*
*   SEE ALSO
*       ahi.device/AHI_ControlAudioA(), AHIsub_GetAttr()
*
*****************************************************************************
*
*

AHIsub_HardwareControl:
	kprintf	"AHIsub_HardwareControl() [%lx, %lx] / [%lx]",d0,d1,a0
	cmp.l	#AHIC_OutputVolume,d0
	bne.b	.dontsetoutvol
	move.l	ahiac_DriverData(a2),a1
	move.l	d1,r_OutputVolume(a1)
	bra.b	.exit
.dontsetoutvol
	cmp.l	#AHIC_OutputVolume_Query,d0
	bne.b	.dontgetoutvol
	move.l	ahiac_DriverData(a2),a1
	move.l	r_OutputVolume(a1),d0
	bra.b	.quit
.dontgetoutvol
	moveq	#FALSE,d0
.quit
	rts
.exit
	moveq	#TRUE,d0
	rts







****** [driver].audio/AHIsub_#? *********************************************
*
*   NAME
*       AHIsub_SetEffect -- Set effect.
*       AHIsub_SetFreq -- Set frequency.
*       AHIsub_SetSound -- Set sound.
*       AHIsub_SetVol -- Set volume and stereo panning.
*       AHIsub_LoadSound -- Prepare a sound for playback.
*       AHIsub_UnloadSound -- Discard a sound.
*
*   SYNOPSIS
*       See functions in 'ahi.device'.
*
*   IMPLEMENTATION
*       If AHIsub_AllocAudio() did not return with bit AHISB_MIXING set,
*       all user calls to these function will be routed to the driver.
*
*       If AHIsub_AllocAudio() did return with bit AHISB_MIXING set, the
*       calls will first be routed to the driver, and only handled by
*       'ahi.device' if the driver returned AHIS_UNKNOWN. This way it is
*       possible to add effects that the sound card handles on its own, like
*       filter and echo effects.
*
*       For what each function does, see the autodocs for 'ahi.device'.
*
*   INPUTS
*       See functions in 'ahi.device'.
*
*   NOTES
*       See functions in 'ahi.device'.
*
*   SEE ALSO
*       ahi.device/AHI_SetEffect(), ahi.device/AHI_SetFreq(),
*       ahi.device/AHI_SetSound(), ahi.device/AHI_SetVol(),
*       ahi.device/AHI_LoadSound(), ahi.device/AHI_UnloadSound()
*       
*
*****************************************************************************
*
*

AHIsub_SetVol:
;	kprintf		"AHIsub_SetVol() [%lx, %lx, %lx] / [%lx, %lx, %lx]",d0,d1,d2,a0,a1,a2
	bra.w	AHIsub_Unknown
AHIsub_SetFreq:
;	kprintf		"AHIsub_SetFreq() [%lx, %lx, %lx] / [%lx, %lx, %lx]",d0,d1,d2,a0,a1,a2
	bra.w	AHIsub_Unknown
AHIsub_SetSound:
;	kprintf		"AHIsub_SetSound() [%lx, %lx, %lx] / [%lx, %lx, %lx]",d0,d1,d2,a0,a1,a2
	bra.w	AHIsub_Unknown
AHIsub_SetEffect:
;	kprintf		"AHIsub_SetEffect() [%lx, %lx, %lx] / [%lx, %lx, %lx]",d0,d1,d2,a0,a1,a2
	bra.w	AHIsub_Unknown
AHIsub_LoadSound:
;	kprintf		"AHIsub_LoadSound() [%lx, %lx, %lx] / [%lx, %lx, %lx]",d0,d1,d2,a0,a1,a2
	bra.b	AHIsub_Unknown
AHIsub_UnloadSound:
;	kprintf		"AHIsub_UnloadSound() [%lx, %lx, %lx] / [%lx, %lx, %lx]",d0,d1,d2,a0,a1,a2
	bra.w	AHIsub_Unknown
AHIsub_Unknown:
	moveq.l	#AHIS_UNKNOWN,d0
	rts

* BeginIO(ioRequest)(a1) (From amiga.lib)
BeginIO:
	;move.l	a1,a0		;probably not necessary
	move.l	a6,-(sp)
	move.l	IO_DEVICE(a1),a6
	jsr	-30(a6)
	move.l	(sp)+,a6
	rts

TimerInt_Start:
	kprintf	"TimerInt_Start"

		movea.l d0,a0
		lea     r_TimerPort(a3),a0
		lea     MP_MSGLIST(a0),a0
		NEWLIST a0

		lea     r_TimerInt(a3),a2
		lea     PlayerFunc(pc),a0
		move.l  a0,IS_CODE(a2)
		move.l  a3,IS_DATA(a2)
;		clr.b   LN_PRI(a2)
		move.b	#32,LN_PRI(a2)

		lea     r_TimerPort(a3),a0
		move.b  #NT_MSGPORT,LN_TYPE(a0)
		move.b  #PA_SOFTINT,MP_FLAGS(a0)
		move.l  a2,MP_SIGTASK(a0)

		movea.l a0,a0                   ; ioReplyPort
		moveq.l #IOTV_SIZE,d0
		jsr     _LVOCreateIORequest(a6)
		move.l  d0,r_TimerReq(a3)
		beq.w   .CreateIORequest_failed

		lea     timerName(pc),a0
		moveq.l #UNIT_MICROHZ,d0
		movea.l r_TimerReq(a3),a1
		moveq.l  #0,d1
		jsr     _LVOOpenDevice(a6)

		move.b	d0,r_TimerDevResult(a3)
		bne.w   .OpenDevice_failed

		move.l	r_TimerReq(a3),a0
		move.l	IO_DEVICE(a0),rb_TimerLib(a5)

		bsr.w	ec_init
		kprintf	"ec freq = %ld",r_TimerFreq(a3)

		clr.w	r_TimerCommFlag(a3)

		move.l  r_TimerReq(a3),a1
		move.w  #TR_ADDREQUEST,IO_COMMAND(a1)
		move.l  r_TimerInterval(a3),IOTV_TIME+TV_MICRO(a1)
		move.l  a6,-(sp)
		movea.l IO_DEVICE(a1),a6
		jsr     DEV_BEGINIO(a6)
		movea.l (sp)+,a6

.ok
		moveq	#AHIE_OK,d0
.exit
		rts
.OpenDevice_failed
.CreateIORequest_failed
		moveq	#AHIE_UNKNOWN,d0
		bra	.exit



TimerInt_Stop:
	kprintf	"TimerInt_Stop"

		tst.b	r_TimerDevResult(a3)
		bne	.notimer
		st	r_TimerDevResult(a3)

		kprintf	"Waiting for timer to exit.."

* Ask timer softint to stop

		addq.w	#1,r_TimerCommFlag(a3)
.waittimer
		tst.w	r_TimerCommFlag(a3)
		beq	.closetimer
;		move.l	pb_DosLib(a5),a6
;		moveq	#1,d1
;		call	Delay
		bra	.waittimer
.closetimer

		kprintf	"timer done"

		clr.l	rb_TimerLib(a5)

	kprintf	"close device"

		move.l	rb_SysLib(a5),a6
		move.l	r_TimerReq(a3),a1
		CALLLIB	_LVOCloseDevice
.notimer
	kprintf	"delete io req"
		move.l	r_TimerReq(a3),a0
		clr.l	r_TimerReq(a3)
		CALLLIB	_LVODeleteIORequest

.ok
		rts


*************************************************************************
ec_init:
		movem.l	d0/d7/a0/a6,-(sp)
		lea	r_TimerVal(a3),a0
		move.l	rb_TimerLib(a5),a6
		jsr	_LVOReadEClock(a6)

		lea	ec_tmp(pc),a0
		moveq.l	#(1<<5)-1,d7
.calibrate	jsr	_LVOReadEClock(a6)
		dbf	d7,.calibrate

		move.l	d0,r_TimerFreq(a3)

		move.l	EV_LO(a0),d0
		sub.l	EV_LO+r_TimerVal(a3),d0
		add.l	#1<<4,d0
		lsr.l	#5,d0
		move.l	d0,r_TimerCalibrate(a3)

		movem.l	(sp)+,d0/d7/a0/a6
		bra.b	ec_reset

ec_readconv:	; ( returns miliseconds d0:d1  )
		bsr	ec_read
		bsr	ec_conv2ms
		rts
ec_readconv_us:	; ( returns microseconds d0:d1  )
		bsr	ec_read
		bsr	ec_conv2us
		rts

*d0:d1	eclocks since init/last reset
*d2	eclock frequency
ec_read:
		movem.l	a0/a6,-(sp)
		lea	ec_tmp(pc),a0
		move.l	rb_TimerLib(a5),a6
		jsr	_LVOReadEClock(a6)
		move.l	(a0)+,d0
		move.l	(a0),d1
		move.l	r_TimerVal(a3),d2
		sub.l	EV_LO+r_TimerVal(a3),d1
		subx.l	d2,d0

		moveq.l	#0,d2
		sub.l	r_TimerCalibrate(a3),d1
		subx.l	d2,d0
		bgt.b	.done

		moveq.l	#0,d0
		moveq.l	#1,d1

.done		move.l	r_TimerFreq(a3),d2
		movem.l	(sp)+,a0/a6
		bra.b	ec_reset
		
ec_conv2ms:
		divu.l	#1000,d2
		divu.l	d2,d0:d1
		rts
ec_conv2us:
		divu.l	#1000,d2
		mulu.l	#1000,d0:d1
		divu.l	d2,d0:d1
		rts

ec_reset
		movem.l	d0-d2/a0/a6,-(sp)
		lea	r_TimerVal(a3),a0
		move.l	rb_TimerLib(a5),a6
		jsr	_LVOReadEClock(a6)
		movem.l	(sp)+,d0-d2/a0/a6
		rts

ec_tmp		ds.l	2

*************************************************************************

PlayerFunc:
;	kprintf	"PlayerFunc"
;	bra.b	.exitxx
		movem.l	d2-d7/a2-a6,-(sp)

		move.l	a1,a3
		move.l	r_AudioCtrl(a3),a2

		move.l	r_ReplayBase(a3),a6
		move.l	rb_SysLib(a6),a6
		lea	r_TimerPort(a3),a0
		CALLLIB	_LVOGetMsg				; Remove message

		tst.w	r_TimerCommFlag(a3)
		beq	.running

		clr.w	r_TimerCommFlag(a3)
		bra	.exit
;
.running
		move.l  r_TimerReq(a3),a1
		move.w  #TR_ADDREQUEST,IO_COMMAND(a1)
		move.l  r_TimerInterval(a3),IOTV_TIME+TV_MICRO(a1)
		LINKLIB	DEV_BEGINIO,IO_DEVICE(a1)

		tst.b	r_DisableInt(a3)
		bne	.notyet

		move.l	r_ReplayBase(a3),a5
		bsr.b	ec_reset

		move.l	rb_BoardAddr(a5),a0
		tst.l	a0
		beq.b	.noreplay

		move.l	XAUD_SRCPTRH(a0),r_OutputGetPtr(a3)
		bra.b	.gotptr

	; faking hw-mix progress..
.noreplay
		move.l	r_OutputGetPtr(a3),a0
		add.l	#176,a0					
		move.l	r_OutputBufferAligned(a3),a1
		add.l	r_OutputBufferSize(a3),a1
;	kprintf	"GET vs END = %lx vs %lx",a0,a1
.again		cmp.l	a1,a0
		blo.b	.ok
		sub.l	r_OutputBufferSize(a3),a0
		bra.b	.again
.ok		move.l	a0,r_OutputGetPtr(a3)

.gotptr

		bsr.b	FillOutputBuffer_entry

		bsr.w	ec_readconv_us
		add.l	d1,.processTimeSum
		add.l	#1,.processTimeCnt
		cmp.l	#50,.processTimeCnt
		bne.b	.notyet
		move.l	.processTimeSum(pc),d0
		divu.l	#50,d0
	kprintf	"Average process time = %ld us",d0
		clr.l	.processTimeSum
		clr.l	.processTimeCnt
.notyet

.exit
		moveq	#0,d0
		movem.l	(sp)+,d2-d7/a2-a6
.exitxx		rts


.processTimeSum	dc.l	0
.processTimeCnt	dc.l	0


FillOutputBuffer_entry:
		movem.l	d0-a6,-(sp)
		move.l	r_OutputBufferSize(a3),d0
		move.l	r_OutputBufferAligned(a3),a0
		move.l	r_OutputPutPtr(a3),a1
		move.l	r_OutputGetPtr(a3),d2
		move.l	r_MixBuffer(a3),a4
		move.l	a4,a5
		add.l	r_MixBufferSize(a3),a4
		move.l	r_MixReadPtr(a3),a3
		move.l	a2,a6
		move.l	d2,a2

;	kprintf	"SIZE = %lx",d0
;	kprintf	"BUFFER = %lx",a0
;	kprintf	"PUT = %lx",a1
;	kprintf	"GET = %lx",a2
;	kprintf	"START = %lx",a5
;	kprintf	"READ = %lx",a3
;	kprintf	"END = %lx",a4


		bsr.w	FillOutputBuffer

;	a1	PUT
;	a3	READ PTR
;	a4	READ BUFFER END

		move.l	a6,a2
		move.l	a4,a5
		move.l	ahiac_DriverData(a2),a4
		move.l	a1,r_OutputPutPtr(a4)
		move.l	a3,r_MixReadPtr(a4)
		move.l	r_MixBuffer(a4),a3
		sub.l	a3,a5
		move.l	a5,r_MixBufferSize(a4)

		movem.l	(sp)+,d0-a6
		rts
		
FillOutputBuffer:
;	d0	OUTPUT BUFFER SIZE
;	a0	OUTPUT BUFFER START
;	a1	PUT
;	a2	GET
;	a3	READ PTR
;	a4	READ BUFFER END
;	a6	AHIAudioCtrlDrv PTR
;RETURNS (updated)
;	a1	PUT
;	a3	READ PTR
;	a4	READ BUFFER END
;DESTROYS (scratch)
;	d2	BYTES TO COPY
;	d3	<temp>
;	d4	<temp>
;	d5	<temp>
;	d6	<temp>
;	d7	<temp>
;	a5	MIX BUFFER temp
;
; alt
;
; 
; 
; a2-a6 = audioctrl, replay, xaudio, replaybase, execbase
;
; d0 - r_OutputBufferSize(a3)
; a0 - r_OutputBufferAligned(a3)
; a1 - r_OutputPutPtr(a3) (or r_OutputPutOffset(a3))
; a2 - r_OutputGetPtr(a3) (or r_OutputGetOffset(a3))
; a3 - r_MixReadPtr(a3)
; a4 - r_MixBuffer(a3) + r_MixBufferSize(a3)
;
; returns miliseconds(d0:d1) used
;

	; either
	;
	; a0 |----------%%%%%%%%%-------------| a0+d0	
	;           a1-^         ^-a2
	; or wrapped
	;
	; a0 |%%%%%-----------------------%%%%| a0+d0	
	;       a2-^                     ^-a1

	; diff = a2 - a1
	; if (diff > 0)	bytes_to_copy = diff
	;    else       bytes_to_copy = (a0+d0-a1) + (a2-a0)

		move.l	a1,d1
		move.l	a2,d2
		sub.l	d1,d2
		bmi.b	.wrapped

		bsr.w	CopySamples

		bra.b	.done

.wrapped
		move.l	a0,d2
		add.l	d0,d2
		sub.l	d1,d2
		bsr.b	CopySamples

		move.l	a2,d2
		sub.l	a0,d2
		bsr.b	CopySamples

.done
		rts

;	d0	OUTPUT BUFFER SIZE
;	d2	BYTES TO COPY
;	a0	OUTPUT BUFFER START
;	a1	PUT
;	a3	INPUT BUFFER
;	a4	READ BUFFER END
;RETURNS
;	a1	PUT
;	a3	READ PTR
;	a4	READ BUFFER END

CopySamples
;	kprintf	"Copy %lx bytes to %lx",d2,a1
		; Compare number of samples to copy with number of samples available

		lsr.l	#2,d2		; output is always 16 bit stereo

.copymore	move.l	a4,d3
		sub.l	a3,d3

	; convert num bytes to num samples (depending on stereo/hifi)
		move.l	ahiac_Flags(a6),d4
		and.l	#AHIACF_STEREO,d4
		lsr.w	#AHIACB_STEREO,d4
		move.w	.copyLoops(pc,d4.w*2),d5
		lea	.copyLoops(pc,d5.w),a5
		add.w	#1,d4
		lsr.l	d4,d3		; input is 16 bit stereo

	; d2 = num out samples
	; d3 = num available samples
;		kprintf	"num samples to copy in total = %ld",d2
;		kprintf "num available samples = %ld",d3

		cmp.l	d2,d3
		ble.b	.copySampleStart
		move.l	d2,d3		; cap copy to actual wanted 
.copySampleStart

	; d2 = num samples to copy in total
	; d3 = num samples to copy in one go
		move.l	d3,d7
		beq.b	.nosamples

		jsr	(a5)		; jump to innerloop

.nosamples
		sub.l	d3,d2
		tst.l	d2
		beq.b	.done
		bsr.w	RefillBuffer
		bra.b	.copymore
.done


		move.l	a1,d2
		sub.l	a0,d2
		cmp.l	d0,d2
		blo.b	.notwrap
		move.l	a0,a1		; reset PUT to start of buffer
.notwrap

		rts

.copyLoops	dc.w	.copyM16-.copyLoops
		dc.w	.copyS16-.copyLoops

		; copy d7 samples from a3 to a1
.copyM16	;kprintf	"Innerloop Copy %ld samples",d7


		move.l	d7,d6
		and.l	#$f,d6
		add.l	#$f,d7		
		lsr.l	#4,d7

		neg	d6
		and.w	#$f,d6
		jmp	.copyLoopM16(pc,d6.w*4)

.copyLoopM16
		rept	16
		move.w	(a3),(a1)+	; left
		move.w	(a3)+,(a1)+	; right
		endr

		subq.l	#1,d7
		bne	.copyLoopM16
		rts

.copyS16	;kprintf	"Innerloop Copy %ld samples",d7

		move.l	d7,d6
		and.l	#$f,d6
		add.l	#$f,d7		
		lsr.l	#4,d7

		neg	d6
		and.w	#$f,d6
		jmp	.copyLoopS16(pc,d6.w*2)

.copyLoopS16
		rept	16
		move.l	(a3)+,(a1)+	; left & right
		endr
		subq.l	#1,d7
		bne	.copyLoopS16
		rts


RefillBuffer:
;	A6	= AHIAudioCtrlDrv ptr
;	kprintf "RefillBuffer"
		movem.l	d0-a6,-(sp)

		move.l	a6,a2
		move.l	ahiac_DriverData(a2),a3

		move.l	ahiac_PreTimer(a2),d0
		move.l	d0,a4
		beq.b	.nopretimerfunc
		jsr	(a4)
		move.l	d0,d7

.nopretimerfunc
		move.l	ahiac_PlayerFunc(a2),d0
		move.l	d0,a0
		beq	.noplayerfunc
		sub.l	a1,a1				; IMPORTANT!
		move.l	h_Entry(a0),a4
;	kprintf "calling player a4 = %lx",a0
		jsr	(a4)
.noplayerfunc

		move.l	ahiac_MixerFunc(a2),d0
		move.l	d0,a0
		beq.b	.nomixerfunc
		tst.l	d7
		bne.b	.nomixerfunc
		move.l	r_MixBuffer(a3),a1
		move.l	h_Entry(a0),a4
;	kprintf "calling mixer a4 = %lx with buffer = %lx",a0,a1
		jsr	(a4)
.nomixerfunc

		move.l	ahiac_PostTimer(a2),d0
		move.l	d0,a4
		beq.w	.noposttimerfunc
		jsr	(a4)

.noposttimerfunc
	
		movem.l	(sp)+,d0-a6

	; reset READ PTR and READ BUFFER END (a3 and a4)

		move.l	ahiac_DriverData(a6),a3
		move.l	r_MixBuffer(a3),a3
		move.l	a3,a4

		move.l	ahiac_BuffSamples(a6),d4
		move.l	ahiac_Flags(a6),d5
		and.l	#AHIACF_STEREO,d5
		lsr.w	#AHIACB_STEREO,d5
		add.w	#1,d5
		lsl.l	d5,d4
		add.l	d4,a4

	
		rts

EndCode:
