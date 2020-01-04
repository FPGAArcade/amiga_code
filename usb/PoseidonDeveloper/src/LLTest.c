#include <proto/exec.h>
#include <proto/lowlevel.h>
#include <proto/dos.h>
#include <dos/dos.h>

#include <libraries/lowlevel_ext.h>

ULONG main(void)
{
    struct Library *LowLevelBase;
    ULONG cnt;
    ULONG val;

    if(LowLevelBase = OpenLibrary("lowlevel.library", 1))
    {
        SetJoyPortAttrs(1, SJA_Reinitialize, TRUE, TAG_END);
        val = SetJoyPortAttrs(1, SJA_Type, SJA_TYPE_ANALOGUE, TAG_END);
        Printf("SetJoyPortAttrs() returned %ld\n", val);
        Delay(50);
        do
        {
            if(SetSignal(0,0) & SIGBREAKF_CTRL_C)
            {
                break;
            }
            for(cnt = 0x0000; cnt < 0x0004; cnt++)
            {
                val = ReadJoyPort(cnt);
                if((cnt == 1) && (val & JPF_BUTTON_RED))
                {
                    SetJoyPortAttrs(1, SJA_RumbleSetSlowMotor, val & 0xff,
                                       SJA_RumbleSetFastMotor, (val>>8) & 0xff,
                                       TAG_END);
                }
                Printf("Port %ld: %08lx   ", cnt, val);
            }
            PutStr("\n");
            Delay(2);
        } while(TRUE);
        SetJoyPortAttrs(1, SJA_Reinitialize, TRUE, TAG_END);

        CloseLibrary(LowLevelBase);
    }
    return(0);
}
