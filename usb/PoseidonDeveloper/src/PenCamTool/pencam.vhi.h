#ifndef PENCAM_VHI_H
#define PENCAM_VHI_H

/*
 *----------------------------------------------------------------------------
 *                         Includes for pencam vhi driver
 *----------------------------------------------------------------------------
 *                   By Chris Hodges <hodges@in.tum.de>
 *
 * History
 *
 *  28-09-2002  - Initial
 *
 */

#include <exec/types.h>
#include <exec/lists.h>
#include <exec/alerts.h>
#include <exec/memory.h>
#include <exec/libraries.h>
#include <exec/interrupts.h>
#include <exec/semaphores.h>
#include <exec/execbase.h>
#include <exec/devices.h>
#include <exec/io.h>
#include <exec/ports.h>
#include <exec/errors.h>
#include <exec/resident.h>
#include <exec/initializers.h>

#include <devices/timer.h>
#include <utility/utility.h>
#include <dos/dos.h>
#include <intuition/intuition.h>

#include <devices/usb.h>
#include <devices/usbhardware.h>
#include <libraries/usbclass.h>

#include <string.h>
#include <stddef.h>
#include <stdio.h>

#if defined(__GNUC__) && !defined(__aligned)
#define __aligned __attribute__((__aligned__(4)))
#endif
#define inline __inline

#include "pencam.h"

#include "declgate.h"


/* Protos
*/

void DECLFUNC_3(releasehook, a0, struct Hook *, hook,
                             a2, APTR, pab,
                             a1, struct NepClassPencam *, nch);

APTR stubAllocVec(ULONG size, ULONG flags);

void stubFreeVec(APTR mem);

struct NepClassPencam * SetupPencam(struct NepPencamBase *np, ULONG *errcode);
struct NepClassPencam * AllocPencam(struct NepClassPencam *nch, ULONG *errcode);
void FreePencam(struct NepClassPencam *nch);

void bayer_unshuffle(struct PCImageHeader *pcih, struct vhi_digitize *digi, struct vhi_image *img, UBYTE *raw);
void bayer_demosaic( struct vhi_digitize *digi, struct vhi_image *img);

ULONG vhi_method_get(ULONG method, APTR attr, ULONG *errorcode, struct NepClassPencam *nch);
ULONG vhi_method_set(ULONG method, APTR attr, ULONG *errorcode, struct NepClassPencam *nch);
ULONG vhi_method_perform(ULONG method, APTR attr, ULONG *errorcode, struct NepClassPencam *nch);
struct vhi_image *vhi_grab (struct vhi_digitize *digi, struct NepClassPencam *nch, ULONG *errorcode);
struct vhi_dc_image *vhi_getimage (struct vhi_dc_getimage *digi, struct NepClassPencam *nch, ULONG *errorcode);


/* Library base macros
*/

#endif /* PENCAM_VHI_H */
