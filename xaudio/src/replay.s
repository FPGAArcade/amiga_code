	AUTO	wb Devs:AudioModes/replay\BEG\END\

	incdir	sys:code/ndk_3.9/include/include_i/
	include	devices/ahi.i
	include	libraries/ahi_sub.i

TRUE		EQU	1
FALSE		EQU	0

BEG:

*** FORM AHIM
	dc.l	ID_FORM
	dc.l	E-S
S:
	dc.l	ID_AHIM


*** AUDN
DrvName:
	dc.l	ID_AUDN
	dc.l	.e-.s
.s
	dc.b	"replay",0
.e
	CNOP	0,2

;AHIDB_AudioID		EQU AHI_TagBase+100
;AHIDB_Bits		EQU AHI_TagBase+110	; Output bits
;AHIDB_Volume		EQU AHI_TagBase+103	; Boolean
;AHIDB_Panning		EQU AHI_TagBase+104	; Boolean
;AHIDB_Stereo		EQU AHI_TagBase+105	; Boolean
;AHIDB_HiFi		EQU AHI_TagBase+106	; Boolean
;AHIDB_MultTable	EQU AHI_TagBase+108	; Private!


*** AUDM
ModeA:
	dc.l	ID_AUDM
	dc.l	.e-.s
.s
	dc.l	AHIDB_AudioID,		$00440001
	dc.l	AHIDB_Bits,		16

	dc.l	AHIDB_Volume,		TRUE
	dc.l	AHIDB_Panning,		TRUE
	dc.l	AHIDB_Stereo,		TRUE
	dc.l	AHIDB_HiFi,		FALSE ; no 24bit yet..
	dc.l	AHIDB_MultTable,	FALSE

	dc.l	AHIDB_Name,		.name-.s
	dc.l	TAG_DONE
	CNOP	0,8
.name	dc.b	"Replay :16 bit Stereo-only",0
.e
	CNOP	0,2

E:
	CNOP	0,2
END:
	dcb.b	1024,$ff
;	ds.l	1024
