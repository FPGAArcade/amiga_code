//
//
// tf-rom - resident CLI command test for 'cpufreq'
// Copyright (c) Erik Hemming
//
// This software is licensed under MIT ; see LICENSE file
//
//

#include <stdint.h>

#include <proto/dos.h>
#include <proto/exec.h>
#include <exec/nodes.h>
#include <exec/resident.h>

#include "kprintf.h"

void* Init(__reg("d0") APTR libraryBase , __reg("a0") BPTR segList, __reg("a6") struct ExecBase* SysBase);
int Run(__reg("d0") ULONG argc, __reg("a0") APTR argp, __reg("a3") BPTR segList);
int Launch(__reg("d0") ULONG argc, __reg("a0") APTR argp, __reg("a1") APTR entry, __reg("a3") BPTR seglist);

extern struct Resident romtag;
extern uint8_t cpufreq;
extern int end;

static __section(CODE) struct SegListTrampoline
{
    ULONG next;
    UWORD jmp;
    APTR address;
} trampoline = 
{
    .next = 0,
    .jmp = 0x4ef9,
    .address = (APTR)Run
};

void* Init( __reg("d0") APTR libraryBase,
            __reg("a0") BPTR segList, 
            __reg("a6") struct ExecBase* SysBase )
{
    kprintf("Init() => %s", romtag.rt_IdString);

    struct DosLibrary* DOSBase = (struct DosLibrary*)OpenLibrary(DOSNAME, 36);

    if (DOSBase) {
        kprintf("AddSegment(segList=%08lx => jumpto=%08lx)\n", MKBADDR(&trampoline), trampoline.address);    
        int ret = AddSegment("cpufreq", MKBADDR(&trampoline), CMD_INTERNAL);
        kprintf("  => success = %08lx\n", ret);    

        CloseLibrary((struct Library*)DOSBase);
    }
    else
    {
        kprintf("Failed to open dos.library\n");    
    }

    return 0;
}

static uint32_t Copy( __reg("d1") void* readhandle,  // Autodocs says D1,A0,D0
                      __reg("d2") void* buffer,      // but is incorrect!
                      __reg("d3") uint32_t length,   // It matches Read() ...
                      __reg("a6") struct DosLibrary* DOSBase )
{
    struct ExecBase * SysBase = *(struct ExecBase **)4;
    uint8_t** p = readhandle;

    uint32_t available = (ULONG)&end - (ULONG)*p;
    if (available < length)
        length = available;

    CopyMem(*p, buffer, length);
    *p += length;

    return length;
}

static void* Alloc( __reg("d0") uint32_t size, 
                    __reg("d1") uint32_t flags, 
                    __reg("a6") struct ExecBase* SysBase )
{
    return AllocMem(size, flags);
}
static void Free( __reg("a1") void* memory,
                  __reg("d0") uint32_t size,
                  __reg("a6") struct ExecBase* SysBase )
{
    FreeMem(memory, size);
}

int Run(__reg("d0") ULONG argc, __reg("a0") APTR argp, __reg("a3") BPTR segList)
{
    struct ExecBase* SysBase = *((struct ExecBase **) (4L));
    struct DosLibrary* DOSBase = (struct DosLibrary*)OpenLibrary(DOSNAME, 36);

    if (!DOSBase) {
        kprintf("DOS failed\n");
        return 1337;
    }

    {
        uint8_t* fh = &cpufreq;
        LONG funcs[] = { (LONG)Copy, (LONG)Alloc, (LONG)Free };
        LONG stackSize = 0;
        kprintf("InternalLoadSeg(%08lx)...\n", fh);
        segList = InternalLoadSeg((BPTR)&fh, 0, funcs, &stackSize);
        kprintf("  => segList = %08lx (%08lx)\n", segList, BADDR(segList));
    }

    if (!segList) {
        kprintf("segList is NULL\n");
        return 1337;
    }

    {
        kprintf("segTable =\n");
        int hunkNr = 0;
        for (BPTR *hunk = BADDR(segList), next; hunk; next = *hunk, hunk = BADDR(next))
        {
            kprintf("  [%ld] => %08lx\n", hunkNr++, hunk);
        }
    }

    kprintf("Launch(argc = %08ld, argp = %08lx, entry=%08lx, segList=%08lx)\n",
            argc, argp, BADDR(segList+1), segList);
    int ret = Launch(argc, argp, BADDR(segList+1), segList);
    kprintf("  => error = %08ld\n", ret);

    {
        kprintf("InternalUnLoadSeg(%08lx)\n", segList);
        InternalUnLoadSeg(segList, Free);
    }

    CloseLibrary((struct Library*)DOSBase);
    return ret;
}
