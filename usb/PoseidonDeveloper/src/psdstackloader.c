/* PsdStackloader is the configuration file, the executable that loads up
   the stack either in shell or via RomTag.
*/

#include <proto/poseidon.h>
#include <proto/exec.h>

#include <exec/resident.h>

#define	VERSION		2
#define	REVISION	1
#define	DATE	"11.5.02"
#define	VERS	"psdstackloader 2.1"
#define	VSTRING	"psdstackloader 2.1 (11.5.02)"
#define	VERSTAG	"\0$VER: psdstackloader 2.1 (11.5.02) © 2002 by Chris Hodges"


int main(void);

static const char prgname[]     = VERS;
static const char prgidstring[] = VSTRING;
static const char prgverstag[]  = VERSTAG;

static
const struct Resident ROMTag =
{
    RTC_MATCHWORD,
    (struct Resident *) &ROMTag,
    (struct Resident *) (&ROMTag + 1),
#ifdef __MORPHOS__
    RTF_PPC | RTF_COLDSTART,
#else /* __MORPHOS__ */
    RTF_COLDSTART,
#endif /* __MORPHOS__ */
    VERSION,
    NT_UNKNOWN,
    35, /* Behind other known classes */
    (char *) prgname,
    (char *) prgidstring,
    (APTR) &main
};

ULONG formarray[] = { ID_FORM, 4, IFFFORM_PSDCFG };

__saveds int main(void)
{
    struct Library *PsdBase;
    if(PsdBase = OpenLibrary("poseidon.library", 1))
    {
        psdReadCfg(NULL, formarray);
        psdParseCfg();
        CloseLibrary(PsdBase);
    }
    return(0);
}
