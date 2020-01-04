/*
 *----------------------------------------------------------------------------
 *                         pencam class for poseidon
 *----------------------------------------------------------------------------
 *                   By Chris Hodges <hodges@in.tum.de>
 *
 * History
 *
 *  11-03-2002  - Initial
 */

#include "debug.h"

#ifdef __MORPHOS__
#define USE_INLINE_STDARG
#endif

#include <proto/dos.h>
#include <proto/exec.h>
#include <proto/poseidon.h>
#include <proto/intuition.h>
#include <proto/graphics.h>
#include <proto/diskfont.h>

#if defined(__SASC) || defined(__MORPHOS__)
#include <clib/alib_protos.h>
#endif

#include "declgate.h"

#ifdef __MORPHOS__
#define USE_INLINE_STDARG
#include <ppcinline/poseidon.h>
#endif

#include "pencam.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

/* MorphOS m68k->ppc gate functions
*/

void DECLFUNC_3(releasehook, a0, struct Hook *, hook,
                             a2, APTR, pab,
                             a1, struct NepClassPencam *, nch);

DECLGATE(static const, releasehook, LIB)


/* Static data
*/

#define ARGS_TO       0
#define ARGS_PICNUM   1
#define ARGS_INTERVAL 2
#define ARGS_UPTO     3
#define ARGS_NOBEEP   4
#define ARGS_GAMMA    5
#define ARGS_SHARPEN  6
#define ARGS_TEXT     7
#define ARGS_FONT     8
#define ARGS_FONTSIZE 9
#define ARGS_UNIT     10
#define ARGS_SIZEOF   11

static char *prgname = "PencamTool";
static char *template = "TO/A,PICNUM/N,INTERVAL/N,UPTO/N/K,NOBEEP/S,GAMMA/K,SHARPEN/S,TEXT/K,FONT/K,FONTSIZE/N/K,UNIT/N/K";
static char *version = "$VER: PencamTool 1.6 (02.09.02) by Chris Hodges <hodges@in.tum.de>";
static LONG ArgsArray[ARGS_SIZEOF];
static struct RDArgs *ArgsHook = NULL;

static UWORD gammaredtab[256];
static UWORD gammagreentab[256];
static UWORD gammabluetab[256];

struct RastPort fontrp;
struct RastPort picrp;
struct TextAttr avenirta;
struct TextFont *avenirfont = NULL;
struct BitMap *fontbm = NULL;
ULONG tlength, theight;

struct Library *PsdBase;
#ifdef __MORPHOS__
struct ExecBase *SysBase;
#endif

struct NepClassPencam * SetupPencam(void);
struct NepClassPencam * AllocPencam(struct NepClassPencam *nch);
void FreePencam(struct NepClassPencam *nch);

#define GAMMA 0.450
#define ZERO 17.0

void CreateGammaTab(void)
{
    UWORD i;
    UWORD red, green, blue;
    double x,y;
    double gamma;
    if(!ArgsArray[ARGS_GAMMA])
    {
        return;
    }
    gamma = atof((char *) ArgsArray[ARGS_GAMMA]);
    gammaredtab[0] = gammagreentab[0] = gammabluetab[0] = 0;
    for(i=1; i<256; ++i)
    {
        x = i;
        x -= ZERO;
        if(x < 1.0)
        {
            x = 1.0;
        }
        y = pow((x/256.0), gamma)*255.0;
        red = (UWORD) (y*1.08);
        green = (UWORD) y;
        blue = (UWORD) (y*0.95);
        gammaredtab[i] = red < 256 ? red : 255;
        gammagreentab[i] = green;
        gammabluetab[i] = blue;
    }
}

void DECLFUNC_3(releasehook, a0, struct Hook *, hook,
                             a2, APTR, pab,
                             a1, struct NepClassPencam *, nch)
{
     DECLARG_3(a0, struct Hook *, hook,
               a2, APTR, pab,
               a1, struct NepClassPencam *, nch)
     /*psdAddErrorMsg(RETURN_WARN, (STRPTR) prgname,
                    "Pencam killed!");*/
     Signal(nch->nch_Task, SIGBREAKF_CTRL_C);
}

struct NepClassPencam * SetupPencam(void)
{
    struct NepClassPencam *nch;
    struct PsdDevice *pd = NULL;
    struct PsdAppBinding *pab;
    ULONG unit;

    if(ArgsArray[ARGS_UNIT])
    {
        unit = *((ULONG *) ArgsArray[ARGS_UNIT]);
    } else {
        unit = 0;
    }
    do
    {
        do
        {
            pd = psdFindDevice(pd,
                               DA_VendorID, 0x0553,
                               DA_ProductID, 0x0202,
                               TAG_END);
        } while(pd && (unit--));

        if(!pd)
        {
            PutStr("No Pencam found!\n");
            return(NULL);
        }
        if((nch = psdAllocVec(sizeof(struct NepClassPencam))))
        {
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
                if(AllocPencam(nch))
                {
                    return(nch);
                } else {
                    PutStr("Couldn't allocate Pencam...\n");
                }
                psdReleaseAppBinding(pab);
            } else {
                PutStr("Couldn't claim binding!\n");
            }
            psdFreeVec(nch);
        }
        PutStr("Hohum...\n");
    } while(TRUE);
    return(NULL);
}

struct RastPort * SetupText(void)
{
    STRPTR text = (STRPTR) ArgsArray[ARGS_TEXT];
    InitRastPort(&fontrp);
    if(ArgsArray[ARGS_FONT])
    {
        avenirta.ta_Name = (STRPTR) ArgsArray[ARGS_FONT];
        if(ArgsArray[ARGS_FONTSIZE])
        {
            avenirta.ta_YSize = *((ULONG *) ArgsArray[ARGS_FONTSIZE]);
        } else {
            avenirta.ta_YSize = 8;
        }
        avenirta.ta_Style = 0L;
        avenirta.ta_Flags = 0L;
        if(!(avenirfont = OpenDiskFont(&avenirta)))
        {
            Printf("Couldn't open font!\n");
        } else {
            SetFont(&fontrp, avenirfont);
        }
    }
    tlength = TextLength(&fontrp, text, (ULONG) strlen(text));
    theight = fontrp.Font->tf_YSize;
    if(!(fontbm = AllocBitMap(tlength, theight, 1L, BMF_CLEAR, NULL)))
    {
        Printf("Couldn't allocate font bitmap memory (%ldx%ld)", tlength, theight);
        return(NULL);
    }
    fontrp.BitMap = fontbm;
    //printf("String: %s\nLength: %d\n",(char *)argsarray[ARGS_TEXT], tlength);
    Move(&fontrp, 0, (LONG) fontrp.Font->tf_Baseline);
    Text(&fontrp, text, (ULONG) strlen(text));
    return(&fontrp);
}

void FreeText(void)
{
    if(fontbm)
    {
        FreeBitMap(fontbm);
        fontbm = NULL;
    }
    if(avenirfont)
    {
        CloseFont(avenirfont);
        avenirfont = NULL;
    }
}

void PasteText(struct PCImageHeader *pcih, UBYTE *output)
{
    LONG x, y;
    LONG tarx, tary;
    LONG vw = pcih->pcih_ImgWidth;
    LONG vw3 = vw+vw+vw;
    UBYTE *op;
    WORD pix;
    if(tlength < vw-2)
    {
        tarx = (vw-tlength) >> 1;
    } else {
        tarx = 1;
    }
    tary = (pcih->pcih_ImgHeight-theight-theight);
    for(y = 0; y < theight; y++)
    {
        for(x = 0; (x < tlength) && (x+tarx+2 < vw); x++)
        {
            pix = ReadPixel(&fontrp, x, y);
            if(pix)
            {
                op = &output[((tary+y)*vw+tarx+x)*3];
                op[-vw3] >>= 1;
                op[-vw3+1] >>= 1;
                op[-vw3+2] >>= 1;
                op[-3] >>= 1;
                op[-2] >>= 1;
                op[-1] >>= 1;
                op[3] >>= 1;
                op[4] >>= 1;
                op[5] >>= 1;
                op[vw3] >>= 1;
                op[vw3+1] >>= 1;
                op[vw3+2] >>= 1;
            }
        }
    }
    for(y = 0; y < theight; y++)
    {
        for(x = 0; (x < tlength) && (x+tarx+2 < vw); x++)
        {
            pix = ReadPixel(&fontrp, x, y);
            if(pix)
            {
                op = &output[((tary+y)*vw+tarx+x)*3];
                *op++ = 255;
                *op++ = 255;
                *op = 255;
            }
        }
    }
}

struct NepClassPencam * AllocPencam(struct NepClassPencam *nch)
{
    struct List *cfglist;
    struct List *iflist;
    struct List *altiflist;
    ULONG ifnum;
    ULONG altnum;
    struct List *eplist;

    nch->nch_Task = FindTask(NULL);

    psdGetAttrs(PGA_DEVICE, nch->nch_Device,
                DA_ConfigList, &cfglist,
                TAG_END);

    if(!cfglist->lh_Head->ln_Succ)
    {
        PutStr("No configs?\n");
        return(NULL);
    }

    nch->nch_Config = (struct PsdConfig *) cfglist->lh_Head;

    psdGetAttrs(PGA_CONFIG, nch->nch_Config,
                CA_InterfaceList, &iflist,
                TAG_END);

    if(!iflist->lh_Head->ln_Succ)
    {
        PutStr("No interfaces?\n");
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
                    return(nch);
                } else {
                    PutStr("Couldn't allocate bulk pipe.\n");
                }
            } else {
                PutStr("No bulk endpoint?\n");
            }
            psdFreePipe(nch->nch_EP0Pipe);
        } else {
             PutStr("Couldn't allocate default pipe\n");
        }
        DeleteMsgPort(nch->nch_TaskMsgPort);
    }
    return(NULL);
}


void FreePencam(struct NepClassPencam *nch)
{
    APTR pab;

    psdGetAttrs(PGA_DEVICE, nch->nch_Device,
                DA_Binding, &pab,
                TAG_END);
    psdReleaseAppBinding(pab);
    psdFreePipe(nch->nch_BulkPipe);
    psdFreePipe(nch->nch_EP0Pipe);
    DeleteMsgPort(nch->nch_TaskMsgPort);
    psdFreeVec(nch);
}

/**************************************************************************/

#include "bayer.c"

APTR TransferImage(struct NepClassPencam *nch, struct PCImageHeader *pcih)
{
    LONG ioerr;
    UBYTE *rawbuf;
    UBYTE *imgbuf;
    UBYTE *newimgbuf;

    rawbuf = psdAllocVec(pcih->pcih_ImgSize);
    if(!rawbuf)
    {
        Printf("Couldn't allocate %ld bytes of memory.\n", pcih->pcih_ImgSize);
        return(NULL);
    }
    /* Workaround fpr a firmware bug */
    ioerr = psdDoPipe(nch->nch_BulkPipe, rawbuf, 64);
    if(!ioerr)
    {
        if(((ULONG *) rawbuf)[0] == 0xed15ed15)
        {
            /* Junk packet at the beginning! */
            ioerr = psdDoPipe(nch->nch_BulkPipe, rawbuf, pcih->pcih_ImgSize);
            /*Printf("Narf!\n");*/
        } else {
            ioerr = psdDoPipe(nch->nch_BulkPipe, &rawbuf[64], pcih->pcih_ImgSize-64);
        }
    }
    if(!ioerr)
    {
        imgbuf = psdAllocVec((ULONG) pcih->pcih_ImgWidth * (ULONG) pcih->pcih_ImgHeight * 3);
        if(imgbuf)
        {
            bayer_unshuffle(pcih, rawbuf, imgbuf);
            psdFreeVec(rawbuf);
            bayer_demosaic(pcih, imgbuf);
            if(ArgsArray[ARGS_SHARPEN])
            {
                newimgbuf = psdAllocVec((ULONG) pcih->pcih_ImgWidth * (ULONG) pcih->pcih_ImgHeight * 3);
                if(newimgbuf)
                {
                    sharpen5x5(pcih, imgbuf, newimgbuf);
                    psdFreeVec(imgbuf);
                    imgbuf = newimgbuf;
                }
            }
            if(ArgsArray[ARGS_GAMMA])
            {
                gammacorrection(pcih, imgbuf);
            }
            if(ArgsArray[ARGS_TEXT])
            {
                PasteText(pcih, imgbuf);
            }
            return(imgbuf);
        } else {
            Printf("Couldn't allocate %ld bytes of memory.\n", pcih->pcih_ImgSize);
        }
    } else {
        Printf("Bulk transfer failed: %s (%ld)\n",
               psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
    }
    psdFreeVec(rawbuf);
    return(NULL);
}

APTR GetPicture(struct NepClassPencam *nch, ULONG picnum, struct PCImageHeader *pcih)
{
    struct PsdPipe *pp;
    LONG ioerr;

    pp = nch->nch_EP0Pipe;
    psdPipeSetup(pp, URTF_IN|URTF_VENDOR|URTF_DEVICE,
                 CMDID_GET_IMAGE_HEADER, picnum, 0);
    ioerr = psdDoPipe(pp, pcih, sizeof(struct PCImageHeader));
    if(ioerr)
    {
        Printf("GET_IMAGE_HEADER failed: %s (%ld)\n",
               psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
        return(NULL);
    }

    psdPipeSetup(pp, URTF_OUT|URTF_VENDOR|URTF_DEVICE,
                 CMDID_UPLOAD_IMAGE, picnum, 0);
    ioerr = psdDoPipe(pp, pcih, sizeof(struct PCImageHeader));
    if(!ioerr)
    {
        return(TransferImage(nch, pcih));
    } else {
        Printf("UPLOAD_IMAGE failed: %s (%ld)\n",
               psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
    }
    return(NULL);
}

APTR GetVideoSnap(struct NepClassPencam *nch, struct PCImageHeader *pcih)
{
    struct PsdPipe *pp;
    LONG ioerr;

    pp = nch->nch_EP0Pipe;
    /*psdPipeSetup(pp, URTF_STANDARD|URTF_ENDPOINT,
                 USR_CLEAR_FEATURE, UFS_ENDPOINT_HALT, URTF_IN|2);
    ioerr = psdDoPipe(pp, NULL, 0);*/

    psdPipeSetup(pp, URTF_IN|URTF_VENDOR|URTF_DEVICE,
                 CMDID_GRAB_UPLOAD, ArgsArray[ARGS_NOBEEP] ? 0x6000L : 0x2000L, 0);
    ioerr = psdDoPipe(pp, pcih, 8);
    if(ioerr)
    {
        Printf("GRAB_UPLOAD failed: %s (%ld)\n",
               psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
        return(NULL);
    }
    return(TransferImage(nch, pcih));
}

int main(int argc, char *argv[])
{
    struct NepClassPencam *nch;
    struct PCImageHeader pcih;
    BPTR outfile;
    UBYTE *imgbuf;
    ULONG sigs;
    char buf[256];
    ULONG imgcount;
    ULONG picnum;

    if(!(ArgsHook = ReadArgs(template, ArgsArray, NULL)))
    {
        PutStr("Wrong arguments!\n");
        return(RETURN_FAIL);
    }
    PsdBase = OpenLibrary("poseidon.library", 1);
    if(!PsdBase)
    {
        FreeArgs(ArgsHook);
        return(RETURN_FAIL);
    }
    if(ArgsArray[ARGS_TEXT])
    {
        if(!(SetupText()))
        {
            FreeArgs(ArgsHook);
            CloseLibrary(PsdBase);
            return(RETURN_ERROR);
        }
    }
    if(!(nch = SetupPencam()))
    {
        FreeText();
        FreeArgs(ArgsHook);
        CloseLibrary(PsdBase);
        return(RETURN_ERROR);
    }
    CreateGammaTab();
    imgcount = 0;
    if(ArgsArray[ARGS_PICNUM])
    {
        picnum = *((ULONG *) ArgsArray[ARGS_PICNUM]);
    } else {
        picnum = 0;
    }
    do
    {
         /*PutStr("Waiting for CTRL-C before downloading.\n"
                "This is your chance to remove the cam to check if the machine crashes.\n");
         Wait(SIGBREAKF_CTRL_C); */
         imgbuf = NULL;
         if(ArgsArray[ARGS_PICNUM])
         {
             imgbuf = GetPicture(nch, picnum, &pcih);
         } else {
             imgbuf = GetVideoSnap(nch, &pcih);
         }
         if(imgbuf)
         {
#if 1
             psdSafeRawDoFmt(buf, 256, (STRPTR) ArgsArray[ARGS_TO], imgcount);
             outfile = Open(buf, MODE_NEWFILE);
             if(outfile)
             {
                 UWORD y;
                 ULONG h = pcih.pcih_ImgHeight;
                 ULONG vh = h-4;
                 ULONG w = pcih.pcih_ImgWidth*3;
                 ULONG vw = w-4*3;
                 for(y = 0; y < vh; y++)
                 {
                     memcpy(imgbuf+y*vw, imgbuf+(y+2)*w+6, (size_t) vw);
                 }
                 FPrintf(outfile, "P6\n%ld %ld\n255\n", vw/3, vh);
                 Flush(outfile);
                 Write(outfile, imgbuf, vw*vh);
                 Close(outfile);
                 Printf("Wrote image into '%s'.\n", buf);
                 imgcount++;
             } else {
                 Printf("Could not open file '%s' for writing!\n", buf);
             }
#endif
             psdFreeVec(imgbuf);
         } else {
             break;
         }
         /*PutStr("Finished. Waiting for another CTRL-C.\n");*/
         sigs = SetSignal(0, 0);
         if(sigs & SIGBREAKF_CTRL_C)
         {
             break;
         }
         if(ArgsArray[ARGS_INTERVAL])
         {
             if((!ArgsArray[ARGS_PICNUM]) && ArgsArray[ARGS_UPTO])
             {
                 if(imgcount > *((ULONG *) ArgsArray[ARGS_UPTO]))
                 {
                     break;
                 }
             }
             Delay(*((ULONG *) ArgsArray[ARGS_INTERVAL]));
         } else {
             if(ArgsArray[ARGS_UPTO])
             {
                 if(picnum < *((ULONG *) ArgsArray[ARGS_UPTO]))
                 {
                     picnum++;
                 } else {
                     break;
                 }
             } else {
                 break;
             }
         }
         sigs = SetSignal(0, 0);
         if(sigs & SIGBREAKF_CTRL_C)
         {
             break;
         }
    } while(TRUE);
    FreeText();
    FreePencam(nch);
    FreeArgs(ArgsHook);
    CloseLibrary(PsdBase);
    return(RETURN_OK);
}
