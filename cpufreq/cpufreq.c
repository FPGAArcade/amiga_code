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

#include <stdio.h>
#include <stdint.h>

#include <proto/exec.h>
#include <proto/dos.h>
#include <dos/rdargs.h>
#include <libraries/configvars.h>
#include <libraries/configregs.h>
#include <libraries/expansion.h>
#include <proto/expansion.h>

#define PRODUCTID    (32)
#define MANUFACTURER (5060)

#define TEMPLATE "FREQ/N/A"
#define OPT_FREQ 0
#define OPT_COUNT 1

#define CPU_CLKDIV (0x100)

int main (void)
{
    uint32_t* result[OPT_COUNT] = { 0 };
    struct RDArgs* args = ReadArgs(TEMPLATE, (LONG *)result, NULL);

    printf(">> FPGAArcade Replay 68060db CPU Frequency Control <<\n\n");

    struct Library* ExpansionBase = OpenLibrary(EXPANSIONNAME, 0);
    if (!ExpansionBase)
    {
        printf("ERROR: Unable to open '%s'\n", EXPANSIONNAME);
        return 1337;
    }

    struct ConfigDev* cd = (struct ConfigDev*)FindConfigDev(NULL, MANUFACTURER, PRODUCTID);
    if (cd)
    {
        printf("68060db config device found (%04d/%02d).\n", MANUFACTURER, PRODUCTID);
#ifdef DEBUG
        printf("    cd_BoardAddr    = %p\n", cd->cd_BoardAddr);
        printf("    cd_BoardSize    = %lu bytes\n", cd->cd_BoardSize);
        printf("    er_Type         = $%02x\n", cd->cd_Rom.er_Type);
        printf("    er_Flags        = $%02x\n", cd->cd_Rom.er_Flags);
        printf("    er_SerialNumber = $%08lx\n", cd->cd_Rom.er_SerialNumber);
        printf("    er_InitDiagVec  = $%04x\n", cd->cd_Rom.er_InitDiagVec);

        struct DiagArea* da = *(struct DiagArea**)&cd->cd_Rom.er_Reserved0c;
        printf("    er_DiagArea     = %p\n", (APTR)da);
        if (da)
        {
            APTR da_DiagPoint   = da->da_DiagPoint ? (APTR)((intptr_t)da + (int16_t)da->da_DiagPoint) : 0;
            APTR da_BootPoint   = da->da_BootPoint ? (APTR)((intptr_t)da + (int16_t)da->da_BootPoint) : 0;
            const char* da_Name = da->da_Name      ? (char*)((intptr_t)da + (int16_t)da->da_Name) : 0;

            printf("    da_Config       = $%02x\n", da->da_Config);
            printf("    da_Flags        = $%02x\n", da->da_Flags);
            printf("    da_Size         = $%04x\n", da->da_Size);
            printf("    da_DiagPoint    = %p\n", da_DiagPoint);
            printf("    da_BootPoint    = %p\n", da_BootPoint);
            printf("    da_Name         = %p (%s)\n", (APTR)da_Name, da_Name ? da_Name : "<null>");

        }
        printf("\n");
#endif
        uint32_t freq_opt = 0;

        if (args != NULL)
        {
            freq_opt = *result[OPT_FREQ];

            printf("Setting CPU CLK to %lu MHz\n", freq_opt);

            FreeArgs(args);
        }
        else
        {
            printf("usage: cpufreq <cpu freq in megahertz>\n");
        }

        if (freq_opt > 0)
        {
            uint16_t* cpu_clk = (uint16_t*)((intptr_t)cd->cd_BoardAddr + CPU_CLKDIV);

            uint16_t data = 0x8000 | (freq_opt & 0xff);
#ifdef DEBUG
            printf("Writing 0x%x of cpu_clk ( %p )\n", data, (APTR)cpu_clk);
#endif
            Disable();
            *cpu_clk = data;
            CacheClearU();
            Enable();
#ifdef DEBUG
            printf("\nDONE!\n");
#endif
        }
    }
    else
    {
        printf("68060db config device NOT FOUND (%04d/%02d).\n", MANUFACTURER, PRODUCTID);
    }

    CloseLibrary(ExpansionBase);    

    return 0;
}
