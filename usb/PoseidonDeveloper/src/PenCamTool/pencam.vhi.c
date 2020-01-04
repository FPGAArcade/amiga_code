/*
 *----------------------------------------------------------------------------
 *                         Poseidon pencam.vhi driver for VHI Studio
 *----------------------------------------------------------------------------
 *                   By Chris Hodges <hodges@in.tum.de>
 *
 * History
 *
 *  28-09-2002  - Initial
 */

#include "debug.h"
#include "pencam.vhi_VERSION.h"

#ifndef __MORPHOS__
#include <pragmas/exec_sysbase_pragmas.h>
#else
#define USE_INLINE_STDARG
#define __NOLIBBASE__
#endif
#include <proto/exec.h>
#include <proto/poseidon.h>

#if defined(__SASC) || defined(__MORPHOS__)
#include <clib/alib_protos.h>
#endif

#include "pencam.vhi.h"

#ifdef __MORPHOS__
#include <ppcinline/poseidon.h>
#endif

#undef	SysBase
#undef  PsdBase

#define LIBNAME             "pencam.vhi"

#define LE2BE_W(x) (((x<<8) & 0xffff) | (x>>8))

/* /// "Lib Stuff" */
struct initstruct
{
    const ULONG libsize;
    const void  *functable;
    const void  *datatable;
    void  (*initfunc)(void);
};

/* MorphOS m68k->ppc gate functions
*/

DECLGATE(static const, releasehook, LIBNR)

/* local protos
*/

#ifdef __MORPHOS__

struct NepPencamBase * libInit(struct NepPencamBase *np,
                         BPTR seglist,
                         struct ExecBase *SysBase);
#else /* __MORPHOS__ */

struct NepPencamBase * NATDECLFUNC_3(libInit,
                               d0, struct NepPencamBase *, np,
                               a0, BPTR, seglist,
                               a6, struct ExecBase *, SysBase);
#endif /* __MORPHOS__ */

struct NepPencamBase * NATDECLFUNC_2(libOpen,
                               d0, ULONG, version,
                               a6, struct NepPencamBase *, np);

BPTR NATDECLFUNC_1(libClose,
                   a6, struct NepPencamBase *, np);

BPTR NATDECLFUNC_1(libExpunge,
                   a6, struct NepPencamBase *, np);

BPTR i_libExpunge(struct NepPencamBase *np);

ULONG libReserved(void);

/* Function prototypes */

ULONG NATDECLFUNC_6(vhi_api,
                    a6, struct NepPencamBase *, np,
                    d2, ULONG, method,
                    d3, ULONG, submethod,
                    d4, APTR, attr,
                    d5, ULONG *, errcode,
                    d6, APTR, vhi_handle);

/* This is a library, not executable
*/
static
int fakemain(void)
{
    return -1;
}

void callfake(void)
{
    fakemain();
}

/* Important! Magic cookie for MorphOS
*/
#ifdef __MORPHOS__
const ULONG __amigappc__ = 1;
#endif /* __MORPHOS__ */


const char libname[];
const char libidstring[];
static
const struct initstruct libraryinitstruct;


static
const struct Resident ROMTag =
{
    RTC_MATCHWORD,
    (struct Resident *) &ROMTag,
    (struct Resident *) (&ROMTag + 1),
#ifdef __MORPHOS__
    RTF_PPC | RTF_AUTOINIT | RTF_COLDSTART,
#else /* __MORPHOS__ */
    RTF_AUTOINIT | RTF_COLDSTART,
#endif /* __MORPHOS__ */
    VERSION,
    NT_LIBRARY,
    47, /* Behind timer.device */
    (char *) libname,
    (char *) libidstring,
    (APTR) &libraryinitstruct
};


/* Static data
*/

/*static
const ULONG FuncTable[]; */

static
const ULONG FuncTable[] =
{
#ifdef __MORPHOS__
    FUNCARRAY_32BIT_NATIVE,
#endif /* __MORPHOS__ */
    (ULONG) libOpen,
    (ULONG) libClose,
    (ULONG) libExpunge,
    (ULONG) libReserved,
    (ULONG) vhi_api,
    0xFFFFFFFF
};

const char libname[]     = LIBNAME;
const char libidstring[] = VSTRING;
const char libverstag[]  = VERSTAG;

static
const struct initstruct libraryinitstruct =
{
    sizeof(struct NepPencamBase),
    FuncTable,
    NULL,
    (void (*)(void)) libInit
};

/*
 *===========================================================
 * libInit(np, seglist, SysBase)
 *===========================================================
 *
 * This is the the LIB_INIT function.
 *
 */

#ifdef __MORPHOS__

struct NepPencamBase * libInit(struct NepPencamBase *np,
                        BPTR seglist,
                        struct ExecBase *SysBase)
{

#else /* __MORPHOS__ */

struct NepPencamBase * NATDECLFUNC_3(libInit,
                              d0, struct NepPencamBase *, np,
                              a0, BPTR, seglist,
                              a6, struct ExecBase *, SysBase)
{
    DECLARG_3(d0, struct NepPencamBase *, np,
              a0, BPTR, seglist,
              a6, struct ExecBase *, SysBase)

#endif /* __MORPHOS__ */

    KPRINTF(10, ("libInit np: 0x%08lx seglist: 0x%08lx SysBase: 0x%08lx\n",
                 np, seglist, SysBase));

    /* Store sysnp & segment */
    np->np_SysBase = SysBase;
#define	SysBase	np->np_SysBase
    np->np_SegList = seglist;
    /* Initialize device node & library struct
    */
    np->np_Library.lib_Node.ln_Type = NT_LIBRARY;
    np->np_Library.lib_Node.ln_Name = (char *) libname;
    np->np_Library.lib_Flags        = LIBF_SUMUSED | LIBF_CHANGED;
    np->np_Library.lib_Version      = VERSION;
    np->np_Library.lib_Revision     = REVISION;
    np->np_Library.lib_IdString     = (char *) libidstring;

    KPRINTF(10, ("libInit: Ok\n"));
    return(np);
}

/*
 *===========================================================
 * libOpen(version, np)
 *===========================================================
 *
 * This is the the LIB_OPEN function.
 *
 */

struct NepPencamBase * NATDECLFUNC_2(libOpen,
                              d0, ULONG, version,
                              a6, struct NepPencamBase *, np)
{
    DECLARG_2(d0, ULONG, version,
              a6, struct NepPencamBase *, np)

    KPRINTF(10, ("libOpen np: 0x%08lx\n", np));
    ++np->np_Library.lib_OpenCnt;
    np->np_Library.lib_Flags &= ~LIBF_DELEXP;
    if(!np->np_PsdBase)
    {
        np->np_PsdBase = OpenLibrary("poseidon.library", 0);
    }

    if(np->np_PsdBase)
    {
        KPRINTF(10, ("libOpen: openCnt = %ld\n", np->np_Library.lib_OpenCnt));
        return(np);
    }
    np->np_Library.lib_OpenCnt--;
    return(NULL);
}


/*
 *===========================================================
 * libClose(np)
 *===========================================================
 *
 * This is the the LIB_EXPUNGE function.
 *
 */

BPTR NATDECLFUNC_1(libClose,
                   a6, struct NepPencamBase *, np)
{
    DECLARG_1(a6, struct NepPencamBase *, np)

    BPTR ret = NULL;

    KPRINTF(10, ("libClose np: 0x%08lx\n", np));

    if(--np->np_Library.lib_OpenCnt == 0)
    {
        if(np->np_PsdBase)
        {
            CloseLibrary(np->np_PsdBase);
            np->np_PsdBase = NULL;
        }
        if(np->np_Library.lib_Flags & LIBF_DELEXP)
        {
            KPRINTF(5, ("libClose: calling expunge...\n"));
            ret = i_libExpunge(np);
        }
    }
    KPRINTF(5, ("libClose: lib_OpenCnt = %ld\n", np->np_Library.lib_OpenCnt));
    return(ret);
}


BPTR i_libExpunge(struct NepPencamBase *np)
{
    BPTR ret = NULL;

    KPRINTF(10, ("libExpunge np: 0x%08lx\n", np));

    if(np->np_Library.lib_OpenCnt == 0)
    {
        ret = np->np_SegList;
        KPRINTF(5, ("libExpunge: removing library node 0x%08lx\n",
                    &np->np_Library.lib_Node));
        Remove(&np->np_Library.lib_Node);

        KPRINTF(5, ("libExpunge: FreeMem()...\n"));
        FreeMem((char *) np - np->np_Library.lib_NegSize,
                (ULONG) (np->np_Library.lib_NegSize + np->np_Library.lib_PosSize));

        KPRINTF(5, ("libExpunge: Unloading done! pencam.vhi expunged!\n\n"));
    } else {
        KPRINTF(5, ("libExpunge: Could not expunge, LIBF_DELEXP set!\n"));
        np->np_Library.lib_Flags |= LIBF_DELEXP;
    }

    return(ret);
}


/*
 *===========================================================
 * libExpunge(np)
 *===========================================================
 *
 * This is the the LIB_EXPUNGE function.
 *
 */

BPTR NATDECLFUNC_1(libExpunge,
                   a6, struct NepPencamBase *, np)
{
    DECLARG_1(a6, struct NepPencamBase *, np)
    return i_libExpunge(np);
}


/*
 *===========================================================
 * libReserved(void)
 *===========================================================
 *
 * This is the the reserved function. It must return 0.
 *
 */

ULONG libReserved(void)
{
    return 0;
}
/* \\\ */

/*
 * ***********************************************************************
 * * Library functions                                                   *
 * ***********************************************************************
 */

#define PsdBase np->np_PsdBase

/* /// "str_null()" */
UBYTE *str_null(struct NepPencamBase *np, UBYTE *str)
{
    UBYTE *str_n;

    if((str_n = AllocVec((ULONG) (strlen(str) + 1), MEMF_ANY|MEMF_CLEAR)))
    {
        strcpy(str_n, str);
    }

    return(str_n);
}
/* \\\ */

/* /// "vhi_api()" */
ULONG NATDECLFUNC_6(vhi_api,
                    a6, struct NepPencamBase *, np,
                    d2, ULONG, method,
                    d3, ULONG, submethod,
                    d4, APTR, attr,
                    d5, ULONG *, errcode,
                    d6, struct NepClassPencam *, vhi_handle)
{
    DECLARG_6(a6, struct NepPencamBase *, np,
              d2, ULONG, method,
              d3, ULONG, submethod,
              d4, APTR, attr,
              d5, ULONG *, errcode,
              d6, struct NepClassPencam *, vhi_handle)

    ULONG result=0;
    ULONG errc;
    struct NepClassPencam *nch = vhi_handle;

    if(!errcode)
    {
        // Avoid crashes, if NULL is supplied as "error-pointer".
        errcode = &errc;
    }

    KPRINTF(1, ("vhi_method %ld, sub %ld, attr %ld\n", method, submethod, attr));
    switch(method)
    {
        case VHI_METHOD_OPEN:
            // The value returned is stored and passed in vhi_handle at every call
            if((nch = SetupPencam(np, errcode)))
            {
            }
            result = (ULONG) nch;
            break;

        case VHI_METHOD_GET:
            result = vhi_method_get(submethod, attr, errcode, vhi_handle);
            break;

        case VHI_METHOD_SET:
            result = vhi_method_set(submethod, attr, errcode, vhi_handle);
            break;

        case VHI_METHOD_PERFORM:
            result = vhi_method_perform(submethod, attr, errcode, vhi_handle);
            break;

        case VHI_METHOD_CLOSE:
            // Free all ressources allocated at VHI_METHOD_OPEN
            if(nch)
            {
                FreePencam(nch);
            }
            break;

        default:
            *errcode = VHI_ERR_UNKNOWN_METHOD;
            break;
    }

    return(result);
}
/* \\\ */

/* /// "vhi_method_get()" */
ULONG vhi_method_get(ULONG method, APTR attr, ULONG *errorcode, struct NepClassPencam *nch)
{
    ULONG result = 0;
    struct vhi_size *dim;
    struct vhi_dimensions *ds;
    struct vhi_dc_number_of_pics *num_of_pics;
    struct vhi_dc_freestore      *free_store;
    struct vhi_dc_status         *dc_status;

    struct NepPencamBase *np = nch->nch_PencamBase;
    struct PCImageInfo pcii;
    LONG ioerr;

    switch(method)
    {
        case VHI_CARD_NAME:
            result = (ULONG) str_null(np, "PenCam STV680");
            break;

        case VHI_CARD_MANUFACTURER:
            result = (ULONG) str_null(np, "STMicroelectronics");
            break;

        case VHI_CARD_VERSION:
            result = (ULONG) nch->nch_FWVers;
            break;

        case VHI_CARD_REVISION:
            result = (ULONG) nch->nch_FWRev;
            break;

        case VHI_CARD_DRIVERAUTHOR:
            result = (ULONG) str_null(np, "Chris Hodges");
            break;

        case VHI_CARD_DRIVERVERSION:
            result = (ULONG) VERSION;
            break;

        case VHI_CARD_DRIVERREVISION:
            result = (ULONG) REVISION;
            break;

        case VHI_SUPPORTED_MODES:
            result = (ULONG) VHI_MODE_COLOR;
            break;

        case VHI_NUMBER_OF_INPUTS:
            result = (ULONG) 1;
            break;

        case VHI_NAME_OF_INPUT:
            result = (ULONG) str_null(np, "CMOS Camera");
            break;

        case VHI_SUPPORTED_OPTIONS:
            result = (ULONG) 0;
            break;

        case VHI_SUPPORTED_VIDEOFORMATS:
            result = (ULONG) VHI_FORMAT_PAL;
            break;

        case VHI_COLOR_MODE:
            result = (ULONG) 1;
            break;

        case VHI_DIGITAL_CAMERA:
            result = (ULONG) VHI_DC_TYPE_USB;
            break;

        case VHI_DC_NUMBER_OF_PICS:
            if((num_of_pics = attr))
            {
                psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE,
                             CMDID_GET_IMAGE_INFO, 0, 0);
                ioerr = psdDoPipe(nch->nch_EP0Pipe, &pcii, 16);
                if(!ioerr)
                {
                    num_of_pics->num = pcii.pcii_ImgIndex;
                    num_of_pics->thumbsavail = FALSE; //nch->nch_HWCaps & HWCF_THUMBS;
                } else {
                    *errorcode = VHI_ERR_INTERNAL_ERROR;
                    psdAddErrorMsg(RETURN_WARN, (STRPTR) libname,
                                   "CMDID_GET_IMAGE_INFO failed: %s (%ld)!",
                                   (APTR) psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
                }
            }
            break;

        case VHI_DC_FREESTORE:
            if((free_store = attr))
            {
                psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE,
                             CMDID_GET_IMAGE_INFO, 0, 0);
                ioerr = psdDoPipe(nch->nch_EP0Pipe, &pcii, 16);
                if(!ioerr)
                {
                    free_store->bytes_free  = pcii.pcii_ImgIndex;
                    free_store->bytes_total = pcii.pcii_MaxIndex;
                    free_store->avail       = TRUE;
                } else {
                    free_store->avail       = FALSE;
                    *errorcode = VHI_ERR_INTERNAL_ERROR;
                    psdAddErrorMsg(RETURN_WARN, (STRPTR) libname,
                                   "CMDID_GET_IMAGE_INFO failed: %s (%ld)!",
                                   (APTR) psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
                }
            }
            break;

        case VHI_DC_DCTIME:
            *errorcode = VHI_ERR_DC_NOTIMEAVAIL;
            break;

        case VHI_MAXIMUM_SIZE:
            if((dim = attr))
            {
                psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE,
                             CMDID_GET_IMAGE_INFO, 0, 0);
                ioerr = psdDoPipe(nch->nch_EP0Pipe, &pcii, 16);
                if(!ioerr)
                {
                    dim->max_width  = pcii.pcii_ImgWidth;
                    dim->max_height = pcii.pcii_ImgHeight;
                    dim->fixed      = TRUE;
                    dim->scalable   = FALSE;
                } else {
                    *errorcode = VHI_ERR_INTERNAL_ERROR;
                    psdAddErrorMsg(RETURN_WARN, (STRPTR) libname,
                                   "CMDID_GET_IMAGE_INFO failed: %s (%ld)!",
                                   (APTR) psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
                }
            }
            break;

        case VHI_TRUSTME_MODE:
            result = (ULONG) nch->nch_TrustMe;
            break;

        case VHI_TRUSTME_SIZE:
            if((ds = attr))
            {
                ds->x1 = nch->nch_Dims.x1;
                ds->y1 = nch->nch_Dims.y1;
                ds->x2 = nch->nch_Dims.x2;
                ds->y2 = nch->nch_Dims.y2;
                ds->dst_width  = nch->nch_Dims.dst_width;
                ds->dst_height = nch->nch_Dims.dst_height;
            }
            break;

        default:
            *errorcode = VHI_ERR_UNKNOWN_METHOD;
            break;
    }

    return(result);
}
/* \\\ */

/* /// "vhi_method_set()" */
ULONG vhi_method_set(ULONG method, APTR attr, ULONG *errorcode, struct NepClassPencam *nch)
{
    struct NepPencamBase *np = nch->nch_PencamBase;
    ULONG result = 0;
    struct vhi_dimensions *ds;

    switch(method)
    {
        case VHI_TRUSTME_MODE:
            nch->nch_TrustMe = (BOOL) attr;
            break;

        case VHI_TRUSTME_SIZE:
            if((ds = attr))
            {
                nch->nch_Dims.x1 = ds->x1;
                nch->nch_Dims.y1 = ds->y1;
                nch->nch_Dims.x2 = ds->x2;
                nch->nch_Dims.y2 = ds->y2;
                nch->nch_Dims.dst_width = ds->dst_width;
                nch->nch_Dims.dst_height = ds->dst_height;
            }
            break;

        case VHI_DC_DCTIME:
            break;

        default:
            *errorcode = VHI_ERR_UNKNOWN_METHOD;
            break;
    }
    return(result);
}
/* \\\ */

/* /// "vhi_method_perform()" */
ULONG vhi_method_perform(ULONG method, APTR attr, ULONG *errorcode, struct NepClassPencam *nch)
{
    struct NepPencamBase *np = nch->nch_PencamBase;
    ULONG result = 0;
    struct vhi_dimensions *dim;
    struct PCImageInfo pcii;
    LONG ioerr;

    switch(method)
    {
        case VHI_CHECK_DIGITIZE_SIZE:
            // Correct dimensions to digitize
            if((dim = attr))
            {
                psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE,
                             CMDID_GET_IMAGE_INFO, 0, 0);
                ioerr = psdDoPipe(nch->nch_EP0Pipe, &pcii, 16);
                if(!ioerr)
                {
                    if(dim->x1 < 0)
                    {
                        dim->x1 = 0;
                    }
                    if(dim->y1 < 0)
                    {
                        dim->y1 = 0;
                    }
                    if(dim->x2  > pcii.pcii_ImgWidth)
                    {
                        dim->x2 = pcii.pcii_ImgWidth;
                    }
                    if(dim->y2  > pcii.pcii_ImgHeight)
                    {
                        dim->y2 = pcii.pcii_ImgHeight;
                    }
                } else {
                    *errorcode = VHI_ERR_INTERNAL_ERROR;
                    psdAddErrorMsg(RETURN_WARN, (STRPTR) libname,
                                   "CMDID_GET_IMAGE_INFO failed: %s (%ld)!",
                                   (APTR) psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
                }
            }
            break;
        case VHI_DIGITIZE_PICTURE:
            result = (ULONG) vhi_grab(attr, nch, errorcode);
            break;

        case VHI_DC_GET_THUMBNAIL:
            *errorcode = VHI_ERR_DC_NO_THUMBNAIL;
            break;

        case VHI_DC_GET_FULL_PICTURE:
            result = (ULONG) vhi_getimage (attr, nch, errorcode);
            break;

        default:
            *errorcode = VHI_ERR_UNKNOWN_METHOD;
            break;
    }
    return(result);
}
/* \\\ */

/* /// "vhi_grab()" */
struct vhi_image *vhi_grab (struct vhi_digitize *digi, struct NepClassPencam *nch, ULONG *errorcode)
{
    struct NepPencamBase *np = nch->nch_PencamBase;
#ifndef __MORPHOS__
    APTR (*CstAllocVec) (ULONG size, ULONG flags);
    void (*CstFreeVec)  (APTR mem);
#else
    APTR CstAllocVec = NULL;
    APTR CstFreeVec = NULL;
#endif
    struct vhi_image *img;
    LONG ioerr;
    ULONG err;
    struct PCImageHeader pcih;

    KPRINTF(10, ("Grabbing...\n"));
    /* Mem Handling */
#ifndef __MORPHOS__
    CstAllocVec = stubAllocVec;
    CstFreeVec  = stubFreeVec;
#endif

    if(digi->custom_memhandling)
    {
        KPRINTF(10, ("Custom mem handler!\n"));
        CstAllocVec = digi->CstAllocVec;
        CstFreeVec  = digi->CstFreeVec;
    }

    /* Correct the size */
    if(nch->nch_TrustMe)
    {
        digi->dim.x1         = nch->nch_Dims.x1;
        digi->dim.x1         = nch->nch_Dims.y1;
        digi->dim.x2         = nch->nch_Dims.x2;
        digi->dim.y2         = nch->nch_Dims.y2;
        digi->dim.dst_width  = nch->nch_Dims.dst_width;
        digi->dim.dst_height = nch->nch_Dims.dst_height;
    } else {
        vhi_method_perform(VHI_CHECK_DIGITIZE_SIZE, &digi->dim, &err, nch);
    }

    psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE,
                 CMDID_GRAB_UPLOAD, 0x6000L, 0);
    ioerr = psdDoPipe(nch->nch_EP0Pipe, &pcih, 8);
    if(ioerr)
    {
        *errorcode = VHI_ERR_ERR_WHILE_DIG;
        psdAddErrorMsg(RETURN_ERROR, (STRPTR) libname,
                       "CMDID_GRAB_UPLOAD failed: %s (%ld)!",
                       (APTR) psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
        return(NULL);
    }
    if((!nch->nch_RawBuf) || (pcih.pcih_ImgSize > nch->nch_RawBufSize))
    {
        KPRINTF(10, ("Allocating %ld bytes\n", pcih.pcih_ImgSize));
        psdFreeVec(nch->nch_RawBuf);
        nch->nch_RawBufSize = 0;
        if(!(nch->nch_RawBuf = psdAllocVec(pcih.pcih_ImgSize)))
        {
            KPRINTF(10, ("Out of memory!\n"));
            *errorcode = VHI_ERR_OUT_OF_MEMORY;
            return(NULL);
        }
        nch->nch_RawBufSize = pcih.pcih_ImgSize;
    }
    /* Workaround for a firmware bug */
    ioerr = psdDoPipe(nch->nch_BulkPipe, nch->nch_RawBuf, 64);
    if(!ioerr)
    {
        if(((ULONG *) nch->nch_RawBuf)[0] == 0xed15ed15)
        {
            /* Junk packet at the beginning! */
            ioerr = psdDoPipe(nch->nch_BulkPipe, nch->nch_RawBuf, pcih.pcih_ImgSize);
        } else {
            ioerr = psdDoPipe(nch->nch_BulkPipe, &nch->nch_RawBuf[64], pcih.pcih_ImgSize-64);
        }
    }
    if(ioerr)
    {
        *errorcode = VHI_ERR_ERR_WHILE_DIG;
        psdAddErrorMsg(RETURN_ERROR, (STRPTR) libname,
                       "Bulk image transfer failed: %s (%ld)!",
                       (APTR) psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
        return(NULL);
    }
#ifndef __MORPHOS__
    if((img = (*CstAllocVec)(sizeof(struct vhi_image), MEMF_ANY|MEMF_CLEAR)))
#else
    //if(digi->custom_memhandling)
    if(0)
    {
        ULONG *p = (ULONG *) REG_A7 - 2;
        UWORD *funcptr = (UWORD *) CstAllocVec;
        p[0] = sizeof(struct vhi_image);
        p[1] = MEMF_ANY|MEMF_CLEAR;
        REG_A7 = (ULONG) p;
        if(*funcptr >= (UWORD) 0xFF00)
        {
            REG_A7 -= 4;
        }
        img = (*MyEmulHandle->EmulCallDirect68k)(funcptr);
        if(*funcptr >= (UWORD) 0xFF00)
        {
            REG_A7 += 4;
        }
        REG_A7 += (2*4);
    } else {
        img = AllocVec(sizeof(struct vhi_image), MEMF_ANY|MEMF_CLEAR);
    }
    if(img)
#endif
    {
        img->width  = (digi->dim.x2 - digi->dim.x1);
        img->height = (digi->dim.y2 - digi->dim.y1);
        img->scaled = FALSE;
        img->type   = VHI_RGB_24;
        img->v = img->u = img->y = NULL;

#ifndef __MORPHOS__
        if((img->chunky = (*CstAllocVec)((img->width * img->height * 3) + 256, MEMF_ANY|MEMF_CLEAR)))
#else
        if(0)
//        if(digi->custom_memhandling)
        {
            ULONG *p = (ULONG *) REG_A7 - 2;
            UWORD *funcptr = (UWORD *) CstAllocVec;
            p[0] = (img->width * img->height * 3) + 256;
            p[1] = MEMF_ANY|MEMF_CLEAR;
            REG_A7 = (ULONG) p;
            if(*funcptr >= (UWORD) 0xFF00)
            {
                REG_A7 -= 4;
            }
            img->chunky = (*MyEmulHandle->EmulCallDirect68k)(funcptr);
            if(*funcptr >= (UWORD) 0xFF00)
            {
                REG_A7 += 4;
            }
            REG_A7 += (2*4);
        } else {
            img->chunky = AllocVec((img->width * img->height * 3) + 256, MEMF_ANY|MEMF_CLEAR);
        }
        if(img->chunky)
#endif
        {
            bayer_unshuffle(&pcih, digi, img, nch->nch_RawBuf);
            bayer_demosaic(digi, img);
            return(img);
        } else {
            KPRINTF(10, ("Out of memory: image!\n"));
            *errorcode = VHI_ERR_OUT_OF_MEMORY;
        }
#ifndef __MORPHOS__
        (*CstFreeVec)(img);
#else
        if(0)
        //if(digi->custom_memhandling)
        {
            ULONG *p = (ULONG *) REG_A7 - 1;
            UWORD *funcptr = (UWORD *) CstFreeVec;
            p[0] = img;
            REG_A7 = (ULONG) p;
            if(*funcptr >= (UWORD) 0xFF00)
            {
                REG_A7 -= 4;
            }
            (*MyEmulHandle->EmulCallDirect68k)(funcptr);
            if(*funcptr >= (UWORD) 0xFF00)
            {
                REG_A7 += 4;
            }
            REG_A7 += (1*4);
        } else {
            FreeVec(img);
        }
#endif
    } else {
        KPRINTF(10, ("Out of memory: struct!\n"));
        *errorcode = VHI_ERR_OUT_OF_MEMORY;
    }
    return(NULL);
}
/* \\\ */

/* /// "vhi_getimage()" */
struct vhi_dc_image *vhi_getimage (struct vhi_dc_getimage *digi, struct NepClassPencam *nch, ULONG *errorcode)
{
    struct NepPencamBase *np = nch->nch_PencamBase;
#ifndef __MORPHOS__
    APTR (*CstAllocVec) (ULONG size, ULONG flags);
    void (*CstFreeVec)  (APTR mem);
#else
    APTR CstAllocVec = NULL;
    APTR CstFreeVec = NULL;
#endif
    void (* set_progress)   (UBYTE *txt, ULONG perc);
    BOOL (* check_cancel) (void);

    struct vhi_dc_image *img = NULL;
    struct vhi_digitize digicnv;

    LONG ioerr;
    struct PCImageHeader pcih;
    ULONG picnum = digi->pic-1;

    KPRINTF(10, ("Downloading image...\n"));
    /* Mem Handling */
#ifndef __MORPHOS__
    CstAllocVec = stubAllocVec;
    CstFreeVec  = stubFreeVec;
#endif
    if(digi->custom_memhandling)
    {
        KPRINTF(10, ("Custom mem handler!\n"));
        CstAllocVec = digi->CstAllocVec;
        CstFreeVec  = digi->CstFreeVec;
    }
    set_progress = digi->set_progress;
    check_cancel = digi->check_cancel;

    psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE,
                 CMDID_GET_IMAGE_HEADER, picnum, 0);
    ioerr = psdDoPipe(nch->nch_EP0Pipe, &pcih, sizeof(struct PCImageHeader));
    if(ioerr)
    {
        *errorcode = VHI_ERR_ERR_WHILE_DIG;
        psdAddErrorMsg(RETURN_ERROR, (STRPTR) libname,
                       "CMDID_GET_IMAGE_HEADER failed: %s (%ld)!",
                       (APTR) psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
        return(NULL);
    }
    psdPipeSetup(nch->nch_EP0Pipe, URTF_OUT|URTF_VENDOR|URTF_DEVICE,
                 CMDID_UPLOAD_IMAGE, picnum, 0);
    ioerr = psdDoPipe(nch->nch_EP0Pipe, &pcih, sizeof(struct PCImageHeader));
    if(ioerr)
    {
        *errorcode = VHI_ERR_ERR_WHILE_DIG;
        psdAddErrorMsg(RETURN_ERROR, (STRPTR) libname,
                       "CMDID_UPLOAD_IMAGE failed: %s (%ld)!",
                       (APTR) psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
        return(NULL);
    }
    if((!nch->nch_RawBuf) || (pcih.pcih_ImgSize > nch->nch_RawBufSize))
    {
        KPRINTF(10, ("Allocating %ld bytes\n", pcih.pcih_ImgSize));
        psdFreeVec(nch->nch_RawBuf);
        nch->nch_RawBufSize = 0;
        if(!(nch->nch_RawBuf = psdAllocVec(pcih.pcih_ImgSize)))
        {
            KPRINTF(10, ("Out of memory!\n"));
            *errorcode = VHI_ERR_OUT_OF_MEMORY;
            return(NULL);
        }
        nch->nch_RawBufSize = pcih.pcih_ImgSize;
    }
    /* Workaround for a firmware bug */
    ioerr = psdDoPipe(nch->nch_BulkPipe, nch->nch_RawBuf, 64);
    if(!ioerr)
    {
        if(((ULONG *) nch->nch_RawBuf)[0] == 0xed15ed15)
        {
            /* Junk packet at the beginning! */
            ioerr = psdDoPipe(nch->nch_BulkPipe, nch->nch_RawBuf, pcih.pcih_ImgSize);
        } else {
            ioerr = psdDoPipe(nch->nch_BulkPipe, &nch->nch_RawBuf[64], pcih.pcih_ImgSize-64);
        }
    }
    if(ioerr)
    {
        *errorcode = VHI_ERR_ERR_WHILE_DIG;
        psdAddErrorMsg(RETURN_ERROR, (STRPTR) libname,
                       "Bulk image transfer failed: %s (%ld)!",
                       (APTR) psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
        return(NULL);
    }
#ifndef __MORPHOS__
    if((img = (*CstAllocVec)(sizeof(struct vhi_dc_image), MEMF_ANY|MEMF_CLEAR)))
#else
    //if(digi->custom_memhandling)
    if(0)
    {
        ULONG *p = (ULONG *) REG_A7 - 2;
        UWORD *funcptr = (UWORD *) CstAllocVec;
        p[0] = sizeof(struct vhi_dc_image);
        p[1] = MEMF_ANY|MEMF_CLEAR;
        REG_A7 = (ULONG) p;
        if(*funcptr >= (UWORD) 0xFF00)
        {
            REG_A7 -= 4;
        }
        img = (*MyEmulHandle->EmulCallDirect68k)(funcptr);
        if(*funcptr >= (UWORD) 0xFF00)
        {
            REG_A7 += 4;
        }
        REG_A7 += (2*4);
    } else {
        img = AllocVec(sizeof(struct vhi_dc_image), MEMF_ANY|MEMF_CLEAR);
    }
    if(img)
#endif
    {
        img->struct_size = sizeof(struct vhi_dc_image);
        img->image.width  = pcih.pcih_ImgWidth;
        img->image.height = pcih.pcih_ImgHeight;
        img->image.scaled = FALSE;
        img->image.type   = VHI_RGB_24;
        img->image.v = img->image.u = img->image.y = NULL;
        img->file_size = 0;
        img->time.sec = img->time.min = img->time.hour = img->time.year = img->time.month = img->time.day = VHI_TIME_UNKNOWN;
        img->degree = VHI_ROT_UNKNOWN;
        img->flash = VHI_FLASH_UNKNOWN;
        img->zoom_setting = VHI_ZOOM_UNKNOWN;
        img->exposure = VHI_EXPOSURE_UNKNOWN; //pcih.pcih_FineExp + pcih.pcih_CoarseExp;
        img->aperture = VHI_APERTURE_UNKNOWN;
        img->is_thumbnail = FALSE;
        img->fullsize_width = 0;
        img->fullsize_height = 0;
#ifndef __MORPHOS__
        if((img->image.chunky = (*CstAllocVec)((img->image.width * img->image.height * 3) + 256, MEMF_ANY|MEMF_CLEAR)))
#else
        //if(digi->custom_memhandling)
        if(0)
        {
            ULONG *p = (ULONG *) REG_A7 - 2;
            UWORD *funcptr = (UWORD *) CstAllocVec;
            p[0] = (img->image.width * img->image.height * 3) + 256;
            p[1] = MEMF_ANY|MEMF_CLEAR;
            REG_A7 = (ULONG) p;
            if(*funcptr >= (UWORD) 0xFF00)
            {
                REG_A7 -= 4;
            }
            img->image.chunky = (*MyEmulHandle->EmulCallDirect68k)(funcptr);
            if(*funcptr >= (UWORD) 0xFF00)
            {
                REG_A7 += 4;
            }
            REG_A7 += (2*4);
        } else {
            img->image.chunky = AllocVec((img->image.width * img->image.height * 3) + 256, MEMF_ANY|MEMF_CLEAR);
        }
        if(img->image.chunky)
#endif
        {
            digicnv.dim.x1 = 0;
            digicnv.dim.y1 = 0;
            digicnv.dim.x2 = img->image.width;
            digicnv.dim.y2 = img->image.height;
            bayer_unshuffle(&pcih, &digicnv, &img->image, nch->nch_RawBuf);
            bayer_demosaic(&digicnv, &img->image);
            return(img);
        } else {
            KPRINTF(10, ("Out of memory: image!\n"));
            *errorcode = VHI_ERR_OUT_OF_MEMORY;
        }
#ifndef __MORPHOS__
        (*CstFreeVec)(img);
#else
        //if(digi->custom_memhandling)
        if(0)
        {
            ULONG *p = (ULONG *) REG_A7 - 1;
            UWORD *funcptr = (UWORD *) CstFreeVec;
            p[0] = img;
            REG_A7 = (ULONG) p;
            if(*funcptr >= (UWORD) 0xFF00)
            {
                REG_A7 -= 4;
            }
            (*MyEmulHandle->EmulCallDirect68k)(funcptr);
            if(*funcptr >= (UWORD) 0xFF00)
            {
                REG_A7 += 4;
            }
            REG_A7 += (1*4);
        } else {
            FreeVec(img);
        }
#endif
    } else {
        KPRINTF(10, ("Out of memory: struct!\n"));
        *errorcode = VHI_ERR_OUT_OF_MEMORY;
    }
    return(NULL);
}
/* \\\ */

/* /// "releasehook()" */
void DECLFUNC_3(releasehook, a0, struct Hook *, hook,
                             a2, APTR, pab,
                             a1, struct NepClassPencam *, nch)
{
     DECLARG_3(a0, struct Hook *, hook,
               a2, APTR, pab,
               a1, struct NepClassPencam *, nch)
     /*psdAddErrorMsg(RETURN_WARN, (STRPTR) prgname,
                    "Pencam killed!");*/
     //Signal(nch->nch_Task, SIGBREAKF_CTRL_C);
}
/* \\\ */

/* /// "bayer_unshuffle()" */
void bayer_unshuffle(struct PCImageHeader *pcih, struct vhi_digitize *digi, struct vhi_image *img, UBYTE *raw)
{
    ULONG x, y;
    ULONG w = pcih->pcih_ImgWidth>>1;
    ULONG vw = pcih->pcih_ImgWidth;
    ULONG vw3 = img->width+img->width+img->width;
    //ULONG vh = pcih->pcih_ImgHeight;
    UBYTE *raweven;
    UBYTE *rawodd;

    UBYTE *oline = img->chunky;
    UBYTE *output;

    /*  raw bayer data: 1st row, 1st half are the odd pixels (same color),
        2nd half (w/2) are the even pixels (same color) for that row
        top left corner of sub array is always green */

    for(y = digi->dim.y1; y < digi->dim.y2; ++y)
    {
        rawodd = &raw[y*vw+digi->dim.x1];
        raweven = &rawodd[w];
        output = oline;
        if(y & 1) // blue-green line
        {
            output++;
        }
        for(x = digi->dim.x1; x < digi->dim.x2; ++x)
        {
            if(x & 1)
            {
                *output = *rawodd++;
                output += 3;
            } else {
                ++output;
                *output = *raweven++;
                output += 2;
            }
        } /* for x */
        oline += vw3;
    } /* for y */
}
/* \\\ */

/* /// "bayer_demosaic()" */
void bayer_demosaic(struct vhi_digitize *digi, struct vhi_image *img)
{
    LONG x, y;
    LONG vw = img->width;
    LONG vw3 = vw+vw+vw;
    LONG vh = img->height;
    UBYTE *op;
    UBYTE *output = img->chunky;
    LONG yo;

    for(y = 1; y < vh-1; y++)
    {
        op = &output[(y*vw+1)*3];
        yo = (((digi->dim.y1+y) & 1));
        yo += yo;
        yo += 1-(digi->dim.x1 & 1);
        for(x = 1; x < vw-1; x++) /* work out pixel type */
        {
            switch(yo)
            {
                case 0:        /* green. red lr, blue tb */
                    *op = (((UWORD) op[-3]) + ((UWORD) op[3])) >> 1; /* Set red */
                    op[2] = (((UWORD) op[2-vw3]) + ((UWORD) op[2+vw3]) + 1) >> 1; /* Set blue */
                    break;
                case 1:        /* red. green lrtb, blue diagonals */
                    op[1] = (((UWORD) op[-2]) + ((UWORD) op[4]) +
                             ((UWORD) op[1-vw3]) + ((UWORD) op[1+vw3]) + 2) >> 2; /* Set green */
                    op[2] = (((UWORD) op[-1-vw3]) + ((UWORD) op[5-vw3]) +
                             ((UWORD) op[-1+vw3]) + ((UWORD) op[5+vw3]) + 2) >> 2; /* Set blue */
                    break;
                case 2:        /* blue. green lrtb, red diagonals */
                    op[1] = (((UWORD) op[-2]) + ((UWORD) op[4]) +
                             ((UWORD) op[1-vw3]) + ((UWORD) op[1+vw3]) + 2) >> 2; /* Set green */
                    *op = (((UWORD) op[-3-vw3]) + ((UWORD) op[3-vw3]) +
                           ((UWORD) op[-3+vw3]) + ((UWORD) op[3+vw3]) + 2) >> 2; /* Set red */
                    break;
                case 3:        /* green. blue lr, red tb */
                    op[2] = (((UWORD) op[-1]) + ((UWORD) op[5]) + 1) >> 1; /* Set blue */
                    *op = (((UWORD) op[-vw3]) + ((UWORD) op[vw3]) + 1) >> 1; /* Set red */
                    break;
            }  /* switch */
            yo ^= 1;
            op += 3;
        }   /* for x */
    }  /* for y */
#if 0
    y = 0;
    op = &output;
    yo = (((digi->dim.y1+y) & 1));
    yo += yo;
    yo += digi->dim.x1 & 1;
    for(x = 0; x < vw; x++)
    {
        switch(yo)
        {
            case 0: /* green. red lr, blue tb */
                if(x == 0) /* Set red */
                {
                    *op = op[3];
                }
                else if(x == vw-1)
                {
                    *op = op[-3];
                } else {
                    *op = (((UWORD) op[-3]) + ((UWORD) op[3])) >> 1; 
                }
                if(y == 0) /* Set blue */
                {
                    op[2] = op[2+vw3];
                }
                else if(y == vh-1)
                    op[2] = op[2-vw3];
                } else {
                    op[2] = (((UWORD) op[2-vw3]) + ((UWORD) op[2+vw3]) + 1) >> 1;
                }
                break;

            case 1:        /* red. green lrtb, blue diagonals */
                if(x == 0) /* Set green */
                {
                    if(y == 0)
                    {
                        op[1] = (((UWORD) op[4]) + ((UWORD) op[1+vw3]) + 1) >> 1;
                    }
                    else if(y == vh-1)
                    {
                        op[1] = (((UWORD) op[4]) + ((UWORD) op[1-vw3]) + 1) >> 1;
                    } else {
                        op[1] = (((UWORD) op[4]) + ((UWORD) op[4]) + ((UWORD) op[1-vw3]) + ((UWORD) op[1+vw3]) + 2) >> 2;
                    }
                }
                else if(x == vw-1)
                {
                    if(y == 0)
                    {
                        op[1] = (((UWORD) op[-2]) + ((UWORD) op[1+vw3]) + 1) >> 1;
                    }
                    else if(y == vh-1)
                    {
                        op[1] = (((UWORD) op[-2]) + ((UWORD) op[1-vw3]) + 1) >> 1;
                    } else {
                        op[1] = (((UWORD) op[-2]) + ((UWORD) op[-2]) +
                                ((UWORD) op[1-vw3]) + ((UWORD) op[1+vw3]) + 2) >> 2;
                    }
                } else {
                    op[1] = (((UWORD) op[-2]) + ((UWORD) op[4]) +
                             ((UWORD) op[1-vw3]) + ((UWORD) op[1+vw3]) + 2) >> 2;
                }

                    op[2] = (((UWORD) op[-1-vw3]) + ((UWORD) op[5-vw3]) +
                             ((UWORD) op[-1+vw3]) + ((UWORD) op[5+vw3]) + 2) >> 2; /* Set blue */
                    break;
                case 2:        /* blue. green lrtb, red diagonals */
                    op[1] = (((UWORD) op[-2]) + ((UWORD) op[4]) +
                             ((UWORD) op[1-vw3]) + ((UWORD) op[1+vw3]) + 2) >> 2; /* Set green */
                    *op = (((UWORD) op[-3-vw3]) + ((UWORD) op[3-vw3]) +
                           ((UWORD) op[-3+vw3]) + ((UWORD) op[3+vw3]) + 2) >> 2; /* Set red */
                    break;
                case 3:        /* green. blue lr, red tb */
                    op[2] = (((UWORD) op[-1]) + ((UWORD) op[5]) + 1) >> 1; /* Set blue */
                    *op = (((UWORD) op[-vw3]) + ((UWORD) op[vw3]) + 1) >> 1; /* Set red */
                    break;
            }  /* switch */
        yo ^= 1;
        op += 3;
    }
#endif
}
/* \\\ */

/* /// "SetupPencam()" */
struct NepClassPencam * SetupPencam(struct NepPencamBase *np, ULONG *errcode)
{
    struct NepClassPencam *nch;
    struct PsdDevice *pd = NULL;
    struct PsdAppBinding *pab;

    pd = psdFindDevice(pd,
                       DA_VendorID, 0x0553,
                       DA_ProductID, 0x0202,
                       DA_Binding, NULL,
                       TAG_END);
    if(!pd)
    {
        KPRINTF(10, ("No pencam found!\n"));
        *errcode = VHI_ERR_NO_HARDWARE;
        return(NULL);
    }
    if((nch = psdAllocVec(sizeof(struct NepClassPencam))))
    {
        nch->nch_PencamBase = np;
        nch->nch_Device = pd;
#ifndef __MORPHOS__
        nch->nch_ReleaseHook.h_Entry = (ULONG (*)()) releasehook;
#else
        nch->nch_ReleaseHook.h_Entry = (ULONG (*)()) &releasehook;
#endif
        pab = psdClaimAppBinding(ABA_Device, pd,
                                 ABA_ReleaseHook, &nch->nch_ReleaseHook,
                                 ABA_UserData, nch,
                                 TAG_END);
        if(pab)
        {
            if(AllocPencam(nch, errcode))
            {
                KPRINTF(10, ("Pencam allocated!\n"));
                return(nch);
            }
            psdReleaseAppBinding(pab);
        } else {
            *errcode = VHI_ERR_INTERNAL_ERROR;
        }
        psdFreeVec(nch);
    }
    KPRINTF(10, ("Pencam allocation failed!\n"));
    return(NULL);
}
/* \\\ */

/* /// "AllocPencam()" */
struct NepClassPencam * AllocPencam(struct NepClassPencam *nch, ULONG *errcode)
{
    struct NepPencamBase *np = nch->nch_PencamBase;
    struct List *cfglist;
    struct List *iflist;
    struct List *altiflist;
    ULONG ifnum;
    ULONG altnum;
    struct List *eplist;
    LONG ioerr;
    UBYTE caminfo[16];

    psdGetAttrs(PGA_DEVICE, nch->nch_Device,
                DA_ConfigList, &cfglist,
                TAG_END);

    if(!cfglist->lh_Head->ln_Succ)
    {
        *errcode = VHI_ERR_COULD_NOT_INIT;
        return(NULL);
    }

    nch->nch_Config = (struct PsdConfig *) cfglist->lh_Head;

    psdGetAttrs(PGA_CONFIG, nch->nch_Config,
                CA_InterfaceList, &iflist,
                TAG_END);

    if(!iflist->lh_Head->ln_Succ)
    {
        *errcode = VHI_ERR_COULD_NOT_INIT;
        return(NULL);
    }

    nch->nch_Interface = (struct PsdInterface *) iflist->lh_Head;
    psdGetAttrs(PGA_INTERFACE, nch->nch_Interface,
                IFA_InterfaceNum, &ifnum,
                IFA_AlternateNum, &altnum,
                IFA_AlternateIfList, &altiflist,
                IFA_EndpointList, &eplist,
                TAG_END);

    if((nch->nch_TaskMsgPort = CreateMsgPort()))
    {
        if((nch->nch_EP0Pipe = psdAllocPipe(nch->nch_Device, nch->nch_TaskMsgPort, NULL)))
        {
            if((ifnum == 0) && (altnum == 0))
            {
                psdSetAltInterface(nch->nch_EP0Pipe, altiflist->lh_Head);
            }
            psdGetAttrs(PGA_CONFIG, nch->nch_Config,
                        CA_InterfaceList, &iflist,
                        TAG_END);
            nch->nch_Interface = (struct PsdInterface *) iflist->lh_Head;
            psdGetAttrs(PGA_INTERFACE, nch->nch_Interface,
                        IFA_InterfaceNum, &ifnum,
                        IFA_AlternateNum, &altnum,
                        IFA_EndpointList, &eplist,
                        TAG_END);
            if(eplist->lh_Head->ln_Succ)
            {
                nch->nch_BulkEP = (struct PsdEndpoint *) eplist->lh_Head;
                psdGetAttrs(PGA_ENDPOINT, nch->nch_BulkEP,
                            EA_MaxPktSize, &nch->nch_BulkPktSize,
                            TAG_END);
                if((nch->nch_BulkPipe = psdAllocPipe(nch->nch_Device, nch->nch_TaskMsgPort, nch->nch_BulkEP)))
                {
                    psdSetAttrs(PGA_PIPE, nch->nch_BulkPipe,
                                PPA_AllowRuntPackets, TRUE,
                                PPA_NakTimeout, TRUE,
                                PPA_NakTimeoutTime, 5000,
                                TAG_END);
                    psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE,
                                 CMDID_GET_CAMERA_INFO, 0, 0);
                    ioerr = psdDoPipe(nch->nch_EP0Pipe, caminfo, 16);
                    if(!ioerr)
                    {
                        KPRINTF(10, ("CamInfo FW V%ld.%ld, ASIC V%ld.%ld, Sensor ID %02lx%02lx, HWCaps %02lx, ImgCaps %02lx\n",
                                caminfo[0], caminfo[1], caminfo[2], caminfo[3], caminfo[4], caminfo[5], caminfo[6], caminfo[7]));
                        nch->nch_FWVers = caminfo[0];
                        nch->nch_FWRev = caminfo[1];
                        nch->nch_ASICVers = caminfo[2];
                        nch->nch_ASICRev = caminfo[3];
                        nch->nch_HWCaps = caminfo[6];
                        nch->nch_ImgCaps = caminfo[7];
                    } else {
                        psdAddErrorMsg(RETURN_WARN, (STRPTR) libname,
                                       "CMDID_GET_CAMERA_INFO failed: %s (%ld)!",
                                       (APTR) psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
                    }
                    return(nch);
                } else {
                    *errcode = VHI_ERR_COULD_NOT_INIT;
                }
            } else {
                *errcode = VHI_ERR_COULD_NOT_INIT;
            }
            psdFreePipe(nch->nch_EP0Pipe);
        } else {
            *errcode = VHI_ERR_COULD_NOT_INIT;
        }
        DeleteMsgPort(nch->nch_TaskMsgPort);
    } else {
        *errcode = VHI_ERR_COULD_NOT_INIT;
    }
    return(NULL);
}
/* \\\ */

/* /// "FreePencam()" */
void FreePencam(struct NepClassPencam *nch)
{
    struct NepPencamBase *np = nch->nch_PencamBase;
    APTR pab;

    KPRINTF(10, ("Free Pencam!\n"));
    if(nch->nch_RawBuf)
    {
        psdFreeVec(nch->nch_RawBuf);
        nch->nch_RawBuf = NULL;
        nch->nch_RawBufSize = 0;
    }
    psdGetAttrs(PGA_DEVICE, nch->nch_Device,
                DA_Binding, &pab,
                TAG_END);
    psdReleaseAppBinding(pab);
    psdFreePipe(nch->nch_BulkPipe);
    psdFreePipe(nch->nch_EP0Pipe);
    DeleteMsgPort(nch->nch_TaskMsgPort);
    psdFreeVec(nch);
}
/* \\\ */

#undef SysBase
#define	SysBase	(*(struct Library **) (4L))

/* /// "stubAllocVec()" */
#ifndef __MORPHOS__
APTR stubAllocVec(ULONG size, ULONG flags)
{
    return(AllocVec(size, flags));
}
#endif
/* \\\ */

/* /// "stubFreeVec()" */
#ifndef __MORPHOS__
void stubFreeVec(APTR mem)
{
    FreeVec(mem);
}
#endif
/* \\\ */

