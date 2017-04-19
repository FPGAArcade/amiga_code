;APS00000000000000000000000000000000000000000000000000000000000000000000000000000000
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

*** AUDM
Mode1:
	dc.l	ID_AUDM
	dc.l	.e-.s
.s
	dc.l	AHIDB_AudioID,		$00440001
	dc.l	AHIDB_Bits,		16

	dc.l	AHIDB_Volume,		TRUE
	dc.l	AHIDB_Panning,		FALSE
	dc.l	AHIDB_Stereo,		FALSE
	dc.l	AHIDB_HiFi,		FALSE
	dc.l	AHIDB_MultTable,	FALSE

	dc.l	AHIDB_Name,		.name-.s
	dc.l	TAG_DONE
	CNOP	0,8
.name	dc.b	"Replay:16 bit Mono",0
.e
	CNOP	0,2

Mode2:
	dc.l	ID_AUDM
	dc.l	.e-.s
.s
	dc.l	AHIDB_AudioID,		$00440002
	dc.l	AHIDB_Bits,		16

	dc.l	AHIDB_Volume,		TRUE
	dc.l	AHIDB_Panning,		TRUE
	dc.l	AHIDB_Stereo,		TRUE
	dc.l	AHIDB_HiFi,		FALSE
	dc.l	AHIDB_MultTable,	FALSE

	dc.l	AHIDB_Name,		.name-.s
	dc.l	TAG_DONE
	CNOP	0,8
.name	dc.b	"Replay:16 bit Stereo",0
.e
	CNOP	0,2

E:
	CNOP	0,2
END:
