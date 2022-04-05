; Picasso96Develop/PrivateInclude/boardinfo.i
;
; This file is from CardDevelop.lha
;
; See http://wiki.icomp.de/wiki/P96
;

        IFND    boardinfo_I
boardinfo_I SET 1

        IFND    EXEC_TYPES_I
        include exec/types.i
        ENDC

        IFND    EXEC_LIBRARIES_I
        include exec/libraries.i
        ENDC

        IFND    EXEC_INTERRUPTS_I
        include exec/interrupts.i
        ENDC

        IFND    EXEC_SEMAPHORES_I
        include exec/semaphores.i
        ENDC

        IFND    GRAPHICS_GFX_I
        include graphics/gfx.i
        ENDC
        
        IFND    DEVICES_TIMER_I
        include devices/timer.i
        ENDC
        
        IFND    UTILITY_TAGITEM_I
        include utility/tagitem.i
        ENDC

;        IFND    LIBRARIES_PICASSO96_I
;        include libraries/Picasso96.i
;        ENDC

        IFND    SETTINGS_I
        include settings.i
        ENDC

************************************************************************
* read "boardinfo.h" for more information
************************************************************************

MAXSPRITEWIDTH  equ     32
MAXSPRITEHEIGHT equ     48

************************************************************************
* Types for BoardType Identification
        ENUM    0
        EITEM   BT_NoBoard
        EITEM   BT_oMniBus
        EITEM   BT_Graffity
        EITEM   BT_CyberVision
        EITEM   BT_Domino
        EITEM   BT_Merlin
        EITEM   BT_PicassoII
        EITEM   BT_Piccolo
        EITEM   BT_RetinaBLT
        EITEM   BT_Spectrum
        EITEM   BT_PicassoIV
        EITEM   BT_PiccoloSD64
        EITEM   BT_A2410
        EITEM   BT_Pixel64
        EITEM   BT_uaegfx
        EITEM   BT_CVision3D
        EITEM   BT_Altais
        EITEM   BT_Prometheus
        EITEM   BT_Mediator
        EITEM   BT_powerfb
        EITEM   BT_powerpci
        EITEM   BT_CVisionPPC
        EITEM   BT_GREX
        EITEM   BT_Prototype7
        EITEM   BT_Reserved                     ;added, thor
        EITEM   BT_Reserved2                    ;added, thor
	EITEM	BT_MNT_VA2000
	EITEM	BT_MNT_ZZ9000
        EITEM   BT_MaxBoardTypes

        ENUM    0
        EITEM   PCT_Unknown
        EITEM   PCT_S11483
        EITEM   PCT_S15025
        EITEM   PCT_CirrusGD542x
        EITEM   PCT_Domino
        EITEM   PCT_BT482
        EITEM   PCT_Music
        EITEM   PCT_ICS5300
        EITEM   PCT_CirrusGD5446
        EITEM   PCT_CirrusGD5434
        EITEM   PCT_S3Trio64
        EITEM   PCT_A2410_xxx
        EITEM   PCT_S3ViRGE
        EITEM   PCT_3dfxVoodoo
        EITEM   PCT_TIPermedia2
        EITEM   PCT_ATIRV100
	EITEM   PCT_reserved
	EITEM   PCT_reserved2
	EITEM   PCT_MNT_VA2000
	EITEM   PCT_MNT_ZZ9000
	EITEM   PCT_MaxPaletteChipTypes

        ENUM    0
        EITEM   GCT_Unknown
        EITEM   GCT_ET4000
        EITEM   GCT_ETW32
        EITEM   GCT_CirrusGD542x
        EITEM   GCT_NCR77C32BLT
        EITEM   GCT_CirrusGD5446
        EITEM   GCT_CirrusGD5434
        EITEM   GCT_S3Trio64
        EITEM   GCT_TI34010
        EITEM   GCT_S3ViRGE
        EITEM   GCT_3dfxVoodoo
        EITEM   GCT_TIPermedia2
        EITEM   GCT_ATIRV100
        EITEM   GCT_reserved
        EITEM   GCT_reserved2
	EITEM   GCT_MNT_VA2000
	EITEM   GCT_MNT_ZZ9000
	EITEM   GCT_MaxGraphicsControllerTypes

************************************************************************

RGBFF_PLANAR    equ     RGBFF_NONE
RGBFF_CHUNKY    equ     RGBFF_CLUT

RGBFB_PLANAR    equ     RGBFB_NONE
RGBFB_CHUNKY    equ     RGBFB_CLUT

************************************************************************

        ENUM    0
        EITEM   DPMS_ON         ; Full operation
        EITEM   DPMS_STANDBY    ; Optional state of minimal power reduction
        EITEM   DPMS_SUSPEND    ; Significant reduction of power consumption
        EITEM   DPMS_OFF        ; Lowest level of power consumption

************************************************************************

 STRUCTURE ColorIndexMapping,0
        ULONG   cim_ColorMask
        STRUCT  cim_Colors,4*256
        LABEL   cim_SIZEOF

************************************************************************

 STRUCTURE Template,0
        APTR    tmp_Memory
        WORD    tmp_BytesPerRow
        UBYTE   tmp_XOffset
        UBYTE   tmp_DrawMode
        ULONG   tmp_FgPen
        ULONG   tmp_BgPen
        LABEL   tmp_SIZEOF

************************************************************************

 STRUCTURE Pattern,0
        APTR    pat_Memory
        LABEL   pat_Offset
        UWORD   pat_XOffset
        UWORD   pat_YOffset
        ULONG   pat_FgPen
        ULONG   pat_BgPen
        UBYTE   pat_Size        ; Width: 16, Height: (1<<pat_Size)
        UBYTE   pat_DrawMode
        LABEL   pat_SIZEOF

************************************************************************

 STRUCTURE Line,0
        WORD    lin_X
        WORD    lin_Y
        UWORD   lin_Length
        WORD    lin_dX
        WORD    lin_dY
        WORD    lin_sDelta
        WORD    lin_lDelta
        WORD    lin_twoSDminusLD
        UWORD   lin_LinePtrn
        UWORD   lin_PatternShift
        ULONG   lin_FgPen
        ULONG   lin_BgPen
        BOOL    lin_Horizontal
        UBYTE   lin_DrawMode
        BYTE    lin_pad
        UWORD   lin_Xorigin
        UWORD   lin_Yorigin
        LABEL   lin_SIZEOF

************************************************************************

 STRUCTURE BitMapExtra,0
        STRUCT  bme_BoardNode,MLN_SIZE
        APTR    bme_HashChain
        APTR    bme_Match
        APTR    bme_BitMap
        APTR    bme_BoardInfo
        APTR    bme_MemChunk
        STRUCT  bme_RenderInfo,gri_SIZEOF
        UWORD   bme_Width
        UWORD   bme_Height
        UWORD   bme_Flags
        LABEL   bme_SIZEOF

        BITDEF  BME,ONBOARD,0
        BITDEF  BME,SPECIAL,1
        BITDEF  BME,VISIBLE,11
        BITDEF  BME,DISPLAYABLE,12
        BITDEF  BME,SPRITESAVED,13
        BITDEF  BME,CHECKSPRITE,14
        BITDEF  BME,INUSE,15

BME_ColorMaskArray      MACRO
        dc.l    $ffffffff
        dc.l    $ffffffff
        dc.l    $ffffffff
        dc.l    $ffffffff
        dc.l    $ffffffff
        dc.l    $ff7fff7f
        dc.l    $00ffffff
        dc.l    $00ffffff
        dc.l    $ffffff00
        dc.l    $ffffff00
        dc.l    $ffffffff
        dc.l    $7fff7fff
        dc.l    $ffffffff
        dc.l    $ff7fff7f
        ENDM

************************************************************************

 STRUCTURE SpecialFeature,MLN_SIZE
        APTR    sf_BoardInfo
        APTR    sf_BitMap
        ULONG   sf_Type
        APTR    sf_FeatureData

        ENUM    0
        EITEM   SFT_INVALID
        EITEM   SFT_FLICKERFIXER
        EITEM   SFT_VIDEOCAPTURE
        EITEM   SFT_VIDEOWINDOW
        EITEM   SFT_MEMORYWINDOW

        ENUM    TAG_USER
        EITEM   FA_Restore
        EITEM   FA_Onboard
        EITEM   FA_Active
        EITEM   FA_Left
        EITEM   FA_Top
        EITEM   FA_Width
        EITEM   FA_Height
        EITEM   FA_Format
        EITEM   FA_Color
        EITEM   FA_Occlusion
        EITEM   FA_SourceWidth
        EITEM   FA_SourceHeight
        EITEM   FA_MinWidth
        EITEM   FA_MinHeight
        EITEM   FA_MaxWidth
        EITEM   FA_MaxHeight
        EITEM   FA_Interlace
        EITEM   FA_PAL
        EITEM   FA_BitMap
        EITEM   FA_Brightness
        EITEM   FA_ModeInfo
        EITEM   FA_ModeFormat
        EITEM   FA_Colors
        EITEM   FA_Colors32
        EITEM   FA_NoMemory
        EITEM   FA_RenderFunc
        EITEM   FA_SaveFunc
        EITEM   FA_UserData
        EITEM   FA_Alignment
        EITEM   FA_ConstantBytesPerRow
        EITEM   FA_DoubleBuffer
        EITEM   FA_Pen
        EITEM   FA_ModeMemorySize
        EITEM   FA_ClipLeft
        EITEM   FA_ClipTop
        EITEM   FA_ClipWidth
        EITEM   FA_ClipHeight
        EITEM   FA_ConstantByteSwapping

************************************************************************

* Tags for bi->AllocBitMap()

        ENUM    TAG_USER
        EITEM   ABMA_Friend
        EITEM   ABMA_Depth
        EITEM   ABMA_RGBFormat
        EITEM   ABMA_Clear
        EITEM   ABMA_Displayable
        EITEM   ABMA_Visible
        EITEM   ABMA_NoMemory
        EITEM   ABMA_NoSprite
        EITEM   ABMA_Colors
        EITEM   ABMA_Colors32
        EITEM   ABMA_ModeWidth
        EITEM   ABMA_ModeHeight
        EITEM   ABMA_RenderFunc
        EITEM   ABMA_SaveFunc
        EITEM   ABMA_UserData
        EITEM   ABMA_Alignment
        EITEM   ABMA_ConstantBytesPerRow
        EITEM   ABMA_UserPrivate
        EITEM   ABMA_ConstantByteSwapping
* the following are reserved for Os 4 but not in current use
        EITEM   ABMA_Memory
        EITEM   ABMA_NotifyHook
        EITEM   ABMA_Locked
* the following are new
        EITEM   ABMA_System
************************************************************************

* Tags for bi->GetBitMapAttr()

        ENUM    TAG_USER
        EITEM   GBMA_MEMORY
        EITEM   GBMA_BASEMEMORY
        EITEM   GBMA_BYTESPERROW
        EITEM   GBMA_BYTESPERPIXEL
        EITEM   GBMA_BITSPERPIXEL
        EITEM   GBMA_RGBFORMAT
        EITEM   GBMA_WIDTH
        EITEM   GBMA_HEIGHT
        EITEM   GBMA_DEPTH

************************************************************************

 STRUCTURE  BoardInfo,0
        APTR    gbi_RegisterBase
        APTR    gbi_MemoryBase
        APTR    gbi_MemoryIOBase
        ULONG   gbi_MemorySize
        APTR    gbi_BoardName
        STRUCT  gbi_VBIName,32
        APTR    gbi_CardBase
        APTR    gbi_ChipBase
        APTR    gbi_ExecBase
        APTR    gbi_UtilBase
        STRUCT  gbi_HardInterrupt,IS_SIZE
        STRUCT  gbi_SoftInterrupt,IS_SIZE
        STRUCT  gbi_BoardLock,SS_SIZE
        STRUCT  gbi_ResolutionsList,MLH_SIZE

        ULONG   gbi_BoardType
        ULONG   gbi_PaletteChipType
        ULONG   gbi_GraphicsControllerType
        UWORD   gbi_MoniSwitch
        UWORD   gbi_BitsPerCannon
        ULONG   gbi_Flags
        UWORD   gbi_SoftSpriteFlags
        UWORD   gbi_ChipFlags
        ULONG   gbi_CardFlags

        UWORD   gbi_BoardNum
        UWORD   gbi_RGBFormats

        STRUCT  gbi_MaxHorValue,MAXMODES*2
        STRUCT  gbi_MaxVerValue,MAXMODES*2
        STRUCT  gbi_MaxHorResolution,MAXMODES*2
        STRUCT  gbi_MaxVerResolution,MAXMODES*2
        ULONG   gbi_MaxMemorySize
        ULONG   gbi_MaxChunkSize

        ULONG   gbi_MemoryClock

        STRUCT  gbi_PixelClockCount,MAXMODES*4

        APTR    gbi_AllocCardMem
        APTR    gbi_FreeCardMem
        
        APTR    gbi_SetSwitch

        APTR    gbi_SetColorArray

        APTR    gbi_SetDAC
        APTR    gbi_SetGC
        APTR    gbi_SetPanning
        APTR    gbi_CalculateBytesPerRow
        APTR    gbi_CalculateMemory
        APTR    gbi_GetCompatibleFormats
        APTR    gbi_SetDisplay

        APTR    gbi_ResolvePixelClock
        APTR    gbi_GetPixelClock
        APTR    gbi_SetClock

        APTR    gbi_SetMemoryMode
        APTR    gbi_SetWriteMask
        APTR    gbi_SetClearMask
        APTR    gbi_SetReadPlane

        APTR    gbi_WaitVerticalSync
        APTR    gbi_SetInterrupt

        APTR    gbi_WaitBlitter

        APTR    gbi_ScrollPlanar
        APTR    gbi_ScrollPlanarDefault
        APTR    gbi_UpdatePlanar
        APTR    gbi_UpdatePlanarDefault
        APTR    gbi_BlitPlanar2Chunky
        APTR    gbi_BlitPlanar2ChunkyDefault
        APTR    gbi_FillRect
        APTR    gbi_FillRectDefault
        APTR    gbi_InvertRect
        APTR    gbi_InvertRectDefault
        APTR    gbi_BlitRect
        APTR    gbi_BlitRectDefault
        APTR    gbi_BlitTemplate
        APTR    gbi_BlitTemplateDefault
        APTR    gbi_BlitPattern
        APTR    gbi_BlitPatternDefault
        APTR    gbi_DrawLine
        APTR    gbi_DrawLineDefault
        APTR    gbi_BlitRectNoMaskComplete
        APTR    gbi_BlitRectNoMaskCompleteDefault
        APTR    gbi_BlitPlanar2Direct
        APTR    gbi_BlitPlanar2DirectDefault

        APTR    gbi_EnableSoftSprite
        APTR    gbi_EnableSoftSpriteDefault
        APTR    gbi_AllocCardMemAbs
        APTR    gbi_SetSplitPosition
        APTR    gbi_ReInitMemory
        APTR    gbi_Reserved2Default
	APTR    gbi_Reserved3
        APTR    gbi_Reserved3Default
        APTR    gbi_WriteYUVRect
        APTR    gbi_WriteYUVRectDefault

        APTR    gbi_GetVSyncState
        APTR    gbi_GetVBeamPos
        APTR    gbi_SetDPMSLevel
        APTR    gbi_ResetChip

        APTR    gbi_GetFeatureAttrs

        APTR    gbi_AllocBitMap
        APTR    gbi_FreeBitMap
        APTR    gbi_GetBitMapAttr

        APTR    gbi_SetSprite
        APTR    gbi_SetSpritePosition
        APTR    gbi_SetSpriteImage
        APTR    gbi_SetSpriteColor

        APTR    gbi_CreateFeature
        APTR    gbi_SetFeatureAttrs
        APTR    gbi_DeleteFeature
        STRUCT  gbi_SpecialFeatures,MLH_SIZE

        APTR    gbi_ModeInfo
        ULONG   gbi_RGBFormat
        WORD    gbi_XOffset
        WORD    gbi_YOffset
        UBYTE   gbi_Depth
        UBYTE   gbi_ClearMask
        BOOL    gbi_Border
        ULONG   gbi_Mask
        STRUCT  gbi_CLUT,256*3

        APTR    gbi_ViewPort
        APTR    gbi_VisibleBitMap
        APTR    gbi_BitMapExtra
        STRUCT  gbi_BitMapList,MLH_SIZE
        STRUCT  gbi_MemList,MLH_SIZE

        WORD    gbi_MouseX
        WORD    gbi_MouseY
        UBYTE   gbi_MouseWidth
        UBYTE   gbi_MouseHeight
        UBYTE   gbi_MouseXOffset
        UBYTE   gbi_MouseYOffset
        APTR    gbi_MouseImage
        STRUCT  gbi_MousePens,4*1
        LABEL   gbi_MouseRect
        WORD    gbi_MouseMinX
        WORD    gbi_MouseMinY
        WORD    gbi_MouseMaxX
        WORD    gbi_MouseMaxY
        APTR    gbi_MouseChunky
        APTR    gbi_MouseRendered
        APTR    gbi_MouseSaveBuffer

        STRUCT  gbi_ChipData,16*4
        STRUCT  gbi_CardData,16*4
        
        APTR    gbi_MemorySpaceBase
        ULONG   gbi_MemorySpaceSize

        APTR    gbi_DoubleBufferList
        
        STRUCT  gbi_SyncTime,TV_SIZE
        ULONG   gbi_SyncPeriod
        STRUCT  gbi_SoftVBlankPort,MP_SIZE
        
        STRUCT  gbi_WaitQ,MLH_SIZE
        
        LONG    gbi_EssentialFormats
        
        APTR    gbi_MouseImageBuffer
				    ; Additional viewport stuff
        APTR    gbi_backViewPort
	APTR    gbi_backgroundBitMap
        APTR    gbi_backExtra
        WORD    gbi_YSplit				    
        ULONG   gbi_MaxPlanarMemory ; Size of a bitplane if planar. If left blank, MemorySize>>2 
        ULONG   gbi_MaxBMWidth      ; Maximum width of a bitmap
        ULONG   gbi_MaxWMHeight     ; Maximum height of a bitmap

        LABEL   gbi_SIZEOF

        BITDEF  BI,HARDWARESPRITE,0
        BITDEF  BI,NOMEMORYMODEMIX,1
        BITDEF  BI,NEEDSALIGNMENT,2
        BITDEF  BI,CACHEMODECHANGE,3
        BITDEF  BI,VBLANKINTERRUPT,4
        BITDEF  BI,HASSPRITEBUFFER,5
	BITDEF  BI,VGASCREENSPLIT,6
	BITDEF  BI,DBLCLOCKHALFSPRITEX,7
        BITDEF  BI,DBLSCANDBLSPRITEY,8
        BITDEF  BI,ILACEHALFSPRITEY,9
        BITDEF  BI,ILACEDBLROWOFFSET,10
        BITDEF  BI,INTERNALMODESONLY,11
        BITDEF  BI,FLICKERFIXER,12
        BITDEF  BI,VIDEOCAPTURE,13
        BITDEF  BI,VIDEOWINDOW,14
        BITDEF  BI,BLITTER,15
        BITDEF  BI,HIRESSPRITE,16
        BITDEF  BI,BIGSPRITE,17
        BITDEF  BI,BORDEROVERRIDE,18
        BITDEF  BI,BORDERBLANK,19
        BITDEF  BI,INDISPLAYCHAIN,20
        BITDEF  BI,QUIET,21
        BITDEF  BI,IGNOREMASK,22
        BITDEF  BI,NOP2CBLITS,23
        BITDEF  BI,NOBLITTER,24
        BITDEF  BI,SYSTEM2SCREENBLITS,25
        BITDEF  BI,GRANTDIRECTACCESS,26
        BITDEF  BI,OVERCLOCK,31

        BITDEF  BI,NOC2PBLITS,23

**********************************
 STRUCTURE CardBase,LIB_SIZE
        UBYTE   card_Flags
        UBYTE   card_pad
        ;We are now longword aligned
        ULONG   card_ExecBase
        ULONG   card_ExpansionBase
        ULONG   card_SegmentList
        APTR    card_Name
        LABEL   card_SIZEOF

**********************************
 STRUCTURE ChipBase,LIB_SIZE
        UBYTE   chip_Flags
        UBYTE   chip_pad
        ;We are now longword aligned
        ULONG   chip_ExecBase
        ULONG   chip_SegmentList
        LABEL   chip_SIZEOF

_LVOInitChip    EQU     -30

        ENDC
