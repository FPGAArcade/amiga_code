; Picasso96Develop/PrivateInclude/settings.i
;
; This file is from CardDevelop.lha
;
; See http://wiki.icomp.de/wiki/P96
;

	IFND	settings_I
settings_I	SET	1

	IFND	EXEC_TYPES_I
	include exec/types.i
	ENDC

************************************************************************

	ENUM	0
	EITEM	PLANAR
	EITEM	CHUNKY
	EITEM	HICOLOR
	EITEM	TRUECOLOR
	EITEM	TRUEALPHA
	EITEM	MAXMODES

************************************************************************

SETTINGSNAMEMAXCHARS	equ	30
BOARDNAMEMAXCHARS	equ	30
MAXRESOLUTIONNAMELENGTH	equ	22

 STRUCTURE LibResolution,LN_SIZE
	STRUCT	glr_P96ID,6
	STRUCT	glr_Name,MAXRESOLUTIONNAMELENGTH
	ULONG	glr_DisplayID;
	UWORD	glr_Width;
	UWORD	glr_Height;
	UWORD	glr_Flags;
	STRUCT	glr_Modes,4*MAXMODES
	APTR	glr_BoardInfo
	APTR	glr_HashChain
	LABEL	glr_SIZEOF

 STRUCTURE ModeInfo,LN_SIZE
 	WORD	gmi_OpenCount
	UWORD	gmi_Active
	UWORD	gmi_Width
	UWORD	gmi_Height
	UBYTE	gmi_Depth
	UBYTE	gmi_Flags

	UWORD	gmi_HorTotal
	UWORD	gmi_HorBlankSize
	UWORD	gmi_HorSyncStart
	UWORD	gmi_HorSyncSize

	UBYTE	gmi_HorSyncSkew
	UBYTE	gmi_HorEnableSkew

	UWORD	gmi_VerTotal
	UWORD	gmi_VerBlankSize
	UWORD	gmi_VerSyncStart
	UWORD	gmi_VerSyncSize

	LABEL	gmi_Clock
	UBYTE	gmi_Numerator
	LABEL	gmi_ClockDivide
	UBYTE	gmi_Denominator
	ULONG	gmi_PixelClock

	LABEL	gmi_SIZEOF

***********************************
* Flags:

	BITDEF	GM,DOUBLECLOCK,0
	BITDEF	GM,INTERLACE,1
	BITDEF	GM,DOUBLESCAN,2
	BITDEF	GM,HPOLARITY,3
	BITDEF	GM,VPOLARITY,4
	BITDEF	GM,COMPATVIDEO,5
	BITDEF	GM,DOUBLEVERTICAL,6
	BITDEF	GM,ALWAYSBORDER,7

***********************************

	ENDC
