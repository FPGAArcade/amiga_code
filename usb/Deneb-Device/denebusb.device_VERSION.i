VERSION		EQU	1
REVISION	EQU	24
DATE	MACRO
		dc.b	'25.4.11'
	ENDM
VERS	MACRO
		dc.b	'denebusb 1.24'
	ENDM
VSTRING	MACRO
		dc.b	'denebusb 1.24 (25.4.11) © 2007-2010 by Chris Hodges',13,10,0
	ENDM
VERSTAG	MACRO
		dc.b	0,'$VER: denebusb 1.24 (25.4.11) © 2007-2010 by Chris Hodges',0
	ENDM
