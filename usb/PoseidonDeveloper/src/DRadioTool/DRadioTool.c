/*
 *----------------------------------------------------------------------------
 *                         DRadio Tool for Poseidon
 *----------------------------------------------------------------------------
 *                   By Chris Hodges <hodges@in.tum.de>
 *
 * History
 *
 *  18-05-2003  - Initial
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

#include "dradio.h"
#include <string.h>

/* MorphOS m68k->ppc gate functions
*/

void DECLFUNC_3(releasehook, a0, struct Hook *, hook,
                             a2, APTR, pab,
                             a1, struct NepClassDRadio *, nch);

DECLGATE(static const, releasehook, LIB)


/* Static data
*/

#define ARGS_ON       0
#define ARGS_OFF      1
#define ARGS_FREQ     2
#define ARGS_SCAN     3
#define ARGS_AUTO     4
#define ARGS_SIGNAL   5
#define ARGS_UNIT     6
#define ARGS_SIZEOF   7

static char *prgname = "DRadioTool";
static char *template = "ON/S,OFF/S,FREQ/K/N,SCAN/S,AUTO/S,SIGNAL/S,UNIT/N/K";
static char *version = "$VER: DRadioTool 1.1 (20.05.03) by Chris Hodges <hodges@in.tum.de>";
static LONG ArgsArray[ARGS_SIZEOF];
static struct RDArgs *ArgsHook = NULL;

struct Library *PsdBase;
#ifdef __MORPHOS__
struct ExecBase *SysBase;
#endif

struct NepClassDRadio * SetupDRadio(void);
struct NepClassDRadio * AllocDRadio(struct NepClassDRadio *nch);
void FreeDRadio(struct NepClassDRadio *nch);

void DECLFUNC_3(releasehook, a0, struct Hook *, hook,
                             a2, APTR, pab,
                             a1, struct NepClassDRadio *, nch)
{
     DECLARG_3(a0, struct Hook *, hook,
               a2, APTR, pab,
               a1, struct NepClassDRadio *, nch)
     /*psdAddErrorMsg(RETURN_WARN, (STRPTR) prgname,
                    "DRadio killed!");*/
     Signal(nch->nch_Task, SIGBREAKF_CTRL_C);
}

struct NepClassDRadio * SetupDRadio(void)
{
    struct NepClassDRadio *nch;
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
                               DA_VendorID, 0x04b4,
                               DA_ProductID, 0x1002,
                               TAG_END);
        } while(pd && (unit--));

        if(!pd)
        {
            PutStr("No D-Link/GemTek Radio found!\n");
            return(NULL);
        }
        if((nch = psdAllocVec(sizeof(struct NepClassDRadio))))
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
                if(AllocDRadio(nch))
                {
                    return(nch);
                } else {
                    PutStr("Couldn't allocate DRadio...\n");
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

struct NepClassDRadio * AllocDRadio(struct NepClassDRadio *nch)
{
    nch->nch_Task = FindTask(NULL);

    if((nch->nch_TaskMsgPort = CreateMsgPort()))
    {
        if((nch->nch_EP0Pipe = psdAllocPipe(nch->nch_Device, nch->nch_TaskMsgPort, NULL)))
        {
            return(nch);
        } else {
            PutStr("Couldn't allocate default pipe\n");
        }
        DeleteMsgPort(nch->nch_TaskMsgPort);
    }
    return(NULL);
}


void FreeDRadio(struct NepClassDRadio *nch)
{
    APTR pab;

    psdGetAttrs(PGA_DEVICE, nch->nch_Device,
                DA_Binding, &pab,
                TAG_END);
    psdReleaseAppBinding(pab);
    psdFreePipe(nch->nch_EP0Pipe);
    DeleteMsgPort(nch->nch_TaskMsgPort);
    psdFreeVec(nch);
}

void SetFreq(struct NepClassDRadio *nch, ULONG pll_div)
{
    LONG ioerr;
    psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE, CMDID_SETFREQ, (pll_div>>8) & 0xff, pll_div & 0xff);
    ioerr = psdDoPipe(nch->nch_EP0Pipe, nch->nch_Buf, 1);
    if(ioerr)
    {
        Printf("Error sending set freq request: %s (%ld)\n",
               psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
    }
    /*psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE, CMDID_CTRL, 0x9c, 0xb7);
    ioerr = psdDoPipe(nch->nch_EP0Pipe, nch->nch_Buf, 1);
    if(ioerr)
    {
        Printf("Error sending set freq request: %s (%ld)\n",
               psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
    }*/
}

/**************************************************************************/

int main(int argc, char *argv[])
{
    struct NepClassDRadio *nch;
    ULONG sigs;
    LONG ioerr;
    ULONG pll_div = (MIN_FREQ*1000 + PLLFREQ) / PLLSTEP;
    ULONG ret = RETURN_OK;

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
    if(!(nch = SetupDRadio()))
    {
        FreeArgs(ArgsHook);
        CloseLibrary(PsdBase);
        return(RETURN_ERROR);
    }
    if(ArgsArray[ARGS_ON])
    {
        /*psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE, CMDID_GETSTEREO, 0x00, 0xC7);
        ioerr = psdDoPipe(nch->nch_EP0Pipe, nch->nch_Buf, 1);
        if(ioerr)
        {
            Printf("Error sending on request: %s (%ld)\n",
                   psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
        }*/
        psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE, CMDID_POWER, 0x01, 0x00);
        ioerr = psdDoPipe(nch->nch_EP0Pipe, nch->nch_Buf, 1);
        if(ioerr)
        {
            Printf("Error sending power on request: %s (%ld)\n",
                   psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
        }
    }
    if(ArgsArray[ARGS_OFF])
    {
        /*psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE, CMDID_GETSTEREO, 0x16, 0x1C);
        ioerr = psdDoPipe(nch->nch_EP0Pipe, nch->nch_Buf, 1);
        if(ioerr)
        {
            Printf("Error sending off request: %s (%ld)\n",
                   psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
        }*/
        psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE, CMDID_POWER, 0x00, 0x00);
        ioerr = psdDoPipe(nch->nch_EP0Pipe, nch->nch_Buf, 1);
        if(ioerr)
        {
            Printf("Error sending mute request: %s (%ld)\n",
                   psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
        }
    }
    if(ArgsArray[ARGS_FREQ])
    {
        ULONG freq;
        freq = *((ULONG *) ArgsArray[ARGS_FREQ]);
        if((freq < MIN_FREQ) || (freq > MAX_FREQ))
        {
            Printf("Value out of range. Must be between %ldKHz and %ldKHz.\n", MIN_FREQ, MAX_FREQ);
        } else {
            pll_div = (freq*1000 + PLLFREQ) / PLLSTEP;
            SetFreq(nch, pll_div);
        }
    }
    if(ArgsArray[ARGS_SCAN])
    {
        ULONG freq;
        ULONG last_pll = 0;
        for(; pll_div < (MAX_FREQ*1000 + PLLFREQ) / PLLSTEP; pll_div += 16)
        {
            freq = ((pll_div * PLLSTEP) - PLLFREQ) / 1000;
            SetFreq(nch, pll_div);
            //Printf("Pll_Div: %ld\r", pll_div);
            Delay(13);
            psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE, CMDID_GETSTEREO, 0x00, 0x00);
            ioerr = psdDoPipe(nch->nch_EP0Pipe, nch->nch_Buf, 1);
            if(ioerr)
            {
                Printf("Error sending status request: %s (%ld)\n",
                       psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
                break;
            }
            if(!(nch->nch_Buf[0] & 0x01))
            {
                last_pll = pll_div;
                if(ArgsArray[ARGS_AUTO])
                {
                    Printf("Found station at %ld.%ld MHz. Press Ctrl-C to keep.\n", freq/1000, freq % 1000);
                    Delay(150);
                } else {
                    Printf("%ld\n", freq);
                }
            }
            if(SetSignal(0,0) & SIGBREAKF_CTRL_C)
            {
                break;
            }
        }
        if(last_pll)
        {
            SetFreq(nch, last_pll);
        }
    }
    if(ArgsArray[ARGS_SIGNAL])
    {
        psdPipeSetup(nch->nch_EP0Pipe, URTF_IN|URTF_VENDOR|URTF_DEVICE, CMDID_GETSTEREO, 0x00, 0x00);
        ioerr = psdDoPipe(nch->nch_EP0Pipe, nch->nch_Buf, 1);
        if(ioerr)
        {
            Printf("Error sending status request: %s (%ld)\n",
                   psdNumToStr(NTS_IOERR, ioerr, "unknown"), ioerr);
        }
        if(nch->nch_Buf[0] & 0x01)
        {
            ret = RETURN_WARN;
        }
    }
    FreeDRadio(nch);
    FreeArgs(ArgsHook);
    CloseLibrary(PsdBase);
    return(ret);
}
