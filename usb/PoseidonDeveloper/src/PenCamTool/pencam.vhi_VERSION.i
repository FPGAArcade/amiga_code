VERSION		EQU	1
REVISION	EQU	2
DATE	MACRO
		dc.b	'28.8.02'
	ENDM
VERS	MACRO
		dc.b	'pencam 1.2'
	ENDM
VSTRING	MACRO
		dc.b	'pencam 1.2 (28.8.02) © 2002 by Chris Hodges',13,10,0
	ENDM
VERSTAG	MACRO
		dc.b	0,'$VER: pencam 1.2 (28.8.02) © 2002 by Chris Hodges',0
	ENDM
