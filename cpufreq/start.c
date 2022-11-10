//
// WWW.FPGAArcade.COM
//
// REPLAY Retro Gaming Platform
// No Emulation No Compromise
//
// cpufreq - CLI tool for updating the 68060 CPU clock frequency
// Copyright (C) Erik Hemming
//
// This software is licensed under LPGLv2.1 ; see LICENSE file
//
//

#include <proto/dos.h>
#include <proto/exec.h>

#include <exec/nodes.h>
#include <exec/resident.h>

void* Init();
int Run();
extern int end;

int Start()
{
    return Run();
}

__section(CODE) struct Resident romtag =
{
    .rt_MatchWord   = RTC_MATCHWORD,
    .rt_MatchTag    = &romtag,
    .rt_EndSkip     = &end,
    .rt_Flags       = RTF_AFTERDOS,
    .rt_Version     = 1,
    .rt_Type        = NT_UNKNOWN,
    .rt_Pri         = 0,
    .rt_Name        = "cpufreq",
    .rt_IdString    = "cpufreq 1.0 (8.11.2022)\n\r",
    .rt_Init        = (APTR)Init
};
