/*
 * derived from
 * STV0680 Vision Camera Chipset Driver
 * Copyright (C) 2000 Adam Harrison <adam@antispin.org> 
 *
 * Rewritten by Chris Hodges.
 * 
 */

#include <stdio.h>
#include <string.h>

#include <stdlib.h>

#include "pencam.h"

void bayer_unshuffle(struct PCImageHeader *pcih, UBYTE *raw, UBYTE *output)
{
    ULONG x, y;
    ULONG w = pcih->pcih_ImgWidth>>1;
    ULONG vw = pcih->pcih_ImgWidth;
    ULONG vh = pcih->pcih_ImgHeight;
    UBYTE *raweven;
    UBYTE *rawodd;
    UBYTE *oline;
        
    //memset(output, 0, (size_t) (3*vw*vh));  /* clear output matrix */

    /*  raw bayer data: 1st row, 1st half are the odd pixels (same color),
        2nd half (w/2) are the even pixels (same color) for that row
        top left corner of sub array is always green */

    for(y = 0; y < vh; y++)
    {
        rawodd = &raw[y*vw];
        raweven = &rawodd[w];
        oline = output;
        if(y & 1)
        {
            ++oline;
        }
        ++oline;
        x = w;
        do
        {
            *oline = *raweven++;
            oline += 2;
            *oline = *rawodd++;
            oline += 4;
        } while(--x);
        output += vw;
        output += vw;
        output += vw;
    }

}  /* bayer_unshuffle */


void bayer_demosaic(struct PCImageHeader *pcih, UBYTE *output)
{
    LONG x, y;
    LONG vw = pcih->pcih_ImgWidth;
    LONG vw3 = vw+vw+vw;
    LONG vh = pcih->pcih_ImgHeight;
    UBYTE *op;
    for(y = 1; y < vh-1; y++)
    {
        op = &output[(y*vw + 1)*3];
        for(x = 1; x < vw-1; x++) /* work out pixel type */
        {
            switch(((y + y) & 2) + (x & 1))
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
            op += 3;
        }   /* for x */
    }  /* for y */
}  /* bayer_demosaic */

void gammacorrection(struct PCImageHeader *pcih, UBYTE *output)
{
    ULONG cnt = pcih->pcih_ImgWidth*pcih->pcih_ImgHeight;
    while(cnt--)
    {
        *output = gammaredtab[*output];
        output++;
        *output = gammagreentab[*output];
        output++;
        *output = gammabluetab[*output];
        output++;
    }
}

#if 0
static const WORD sh5x5[5][5] =
{
   { -1, -1, -1, -1, -1 },
   { -1, -3, -3, -3, -1 },
   { -1, -3, 56, -3, -1 },
   { -1, -3, -3, -3, -1 },
   { -1, -1, -1, -1, -1 }
};

static const WORD sh3x3[3][3] =
{
   { -1, -1, -1 },
   { -1,  9, -1 },
   { -1, -1, -1 }
};
#endif


void sharpen5x5(struct PCImageHeader *pcih, UBYTE *input, UBYTE *output)
{
    LONG x, y;
    LONG vw = pcih->pcih_ImgWidth;
    LONG vw3 = vw+vw+vw;
    LONG vw6 = vw*6;
    LONG vh = pcih->pcih_ImgHeight;
    LONG linem2[3];
    LONG linem1[3];
    LONG linep1[3];
    LONG linep2[3];
    LONG val[3];

    UBYTE *op;
    UBYTE *oop;
    for(y = 2; y < vh-2; y++)
    {
        op = &input[((y-2)*vw)*3];
        linem2[0] = *op++;  // -2
        linem2[1] = *op++;
        linem2[2] = *op++;
        linem2[0] += *op++; // -1
        linem2[1] += *op++;
        linem2[2] += *op++;
        linem2[0] += *op++; // 0
        linem2[1] += *op++;
        linem2[2] += *op++;
        linem2[0] += *op++; // 1
        linem2[1] += *op++;
        linem2[2] += *op++;
        linem2[0] += *op++; // 2
        linem2[1] += *op++;
        linem2[2] += *op;

        op = &input[((y-1)*vw+1)*3];
        linem1[0] = *op++;  // -1
        linem1[1] = *op++;
        linem1[2] = *op++;
        linem1[0] += *op++; // 0
        linem1[1] += *op++;
        linem1[2] += *op++;
        linem1[0] += *op++; // 1
        linem1[1] += *op++;
        linem1[2] += *op++;
        linem1[0] += linem1[0]+linem1[0];
        linem1[1] += linem1[1]+linem1[1];
        linem1[2] += linem1[2]+linem1[2];
        linem1[0] += *op++; // 2
        linem1[1] += *op++;
        linem1[2] += *op++;
        linem1[0] += op[-15]; // -2
        linem1[1] += op[-14];
        linem1[2] += op[-13];

        op = &input[((y+1)*vw+1)*3];
        linep1[0] = *op++;  // -1
        linep1[1] = *op++;
        linep1[2] = *op++;
        linep1[0] += *op++; // 0
        linep1[1] += *op++;
        linep1[2] += *op++;
        linep1[0] += *op++; // 1
        linep1[1] += *op++;
        linep1[2] += *op++;
        linep1[0] += linep1[0]+linep1[0];
        linep1[1] += linep1[1]+linep1[1];
        linep1[2] += linep1[2]+linep1[2];
        linep1[0] += *op++; // 2
        linep1[1] += *op++;
        linep1[2] += *op++;
        linep1[0] += op[-15]; // -2
        linep1[1] += op[-14];
        linep1[2] += op[-13];

        op = &input[((y+2)*vw)*3];
        linep2[0] = *op++;  // -2
        linep2[1] = *op++;
        linep2[2] = *op++;
        linep2[0] += *op++; // -1
        linep2[1] += *op++;
        linep2[2] += *op++;
        linep2[0] += *op++; // 0
        linep2[1] += *op++;
        linep2[2] += *op++;
        linep2[0] += *op++; // 1
        linep2[1] += *op++;
        linep2[2] += *op++;
        linep2[0] += *op++; // 2
        linep2[1] += *op++;
        linep2[2] += *op;

        op = &input[(y*vw + 2)*3];
        oop = &output[(y*vw + 2)*3];
        for(x = 2; x < vw-2; x++) /* work out pixel type */
        {
#if 1
            /* Central line */
            val[0] = op[-3] + op[3];
            val[1] = op[-2] + op[4];
            val[2] = op[-1] + op[5];
            val[0] += val[0] + val[0] + op[-6] + op[6] + linem2[0] + linem1[0] + linep1[0] + linep2[0];
            val[1] += val[1] + val[1] + op[-5] + op[7] + linem2[1] + linem1[1] + linep1[1] + linep2[1];
            val[2] += val[2] + val[2] + op[-4] + op[8] + linem2[2] + linem1[2] + linep1[2] + linep2[2];
            val[0] -= op[0] * 56;
            val[1] -= op[1] * 56;
            val[2] -= op[2] * 56;
#define MAXVAL 4080

            *oop++ = (val[0] > 0) ? 0 : ((val[0] < -MAXVAL) ? 255 : (-val[0]+8)>>4);
            *oop++ = (val[1] > 0) ? 0 : ((val[1] < -MAXVAL) ? 255 : (-val[1]+8)>>4);
            *oop++ = (val[2] > 0) ? 0 : ((val[2] < -MAXVAL) ? 255 : (-val[2]+8)>>4);

            /* Update line y-2 */
            linem2[0] -= op[-vw6-6];
            linem2[0] += op[-vw6+9];
            linem2[1] -= op[-vw6-5];
            linem2[1] += op[-vw6+10];
            linem2[2] -= op[-vw6-4];
            linem2[2] += op[-vw6+11];

            /* Update line y-1 */
            linem1[0] -= op[-vw3-6];
            linem1[0] -= op[-vw3-3]<<1;
            linem1[0] += op[-vw3+6]<<1;
            linem1[0] += op[-vw3+9];
            linem1[1] -= op[-vw3-5];
            linem1[1] -= op[-vw3-2]<<1;
            linem1[1] += op[-vw3+7]<<1;
            linem1[1] += op[-vw3+10];
            linem1[2] -= op[-vw3-4];
            linem1[2] -= op[-vw3-1]<<1;
            linem1[2] += op[-vw3+8]<<1;
            linem1[2] += op[-vw3+11];

            /* Update line y+1 */
            linep1[0] -= op[vw3-6];
            linep1[0] -= op[vw3-3]<<1;
            linep1[0] += op[vw3+6]<<1;
            linep1[0] += op[vw3+9];
            linep1[1] -= op[vw3-5];
            linep1[1] -= op[vw3-2]<<1;
            linep1[1] += op[vw3+7]<<1;
            linep1[1] += op[vw3+10];
            linep1[2] -= op[vw3-4];
            linep1[2] -= op[vw3-1]<<1;
            linep1[2] += op[vw3+8]<<1;
            linep1[2] += op[vw3+11];

            /* Update line y-2 */
            linep2[0] -= op[vw6-6];
            linep2[0] += op[vw6+9];
            linep2[1] -= op[vw6-5];
            linep2[1] += op[vw6+10];
            linep2[2] -= op[vw6-4];
            linep2[2] += op[vw6+11];
#else
            UWORD xx,yy;
            val[0] = val[1] = val[2] = 0;
            for(yy = 0; yy < 5; yy++)
            {
                for(xx = 0; xx < 5; xx++)
                {
                    val[0] += op[((yy-2)*vw+(xx-2))*3+0]*sh5x5[xx][yy];
                    val[1] += op[((yy-2)*vw+(xx-2))*3+1]*sh5x5[xx][yy];
                    val[2] += op[((yy-2)*vw+(xx-2))*3+2]*sh5x5[xx][yy];
                }
            }
            val[0] /= 32;
            val[1] /= 32;
            val[2] /= 32;
            val[0] = (val[0] < 0) ? 0 : ((val[0] > 255) ? 255 : val[0]);
            val[1] = (val[1] < 0) ? 0 : ((val[1] > 255) ? 255 : val[1]);
            val[2] = (val[2] < 0) ? 0 : ((val[2] > 255) ? 255 : val[2]);
            *oop++ = val[0];
            *oop++ = val[1];
            *oop++ = val[2];
#endif
            op += 3;
        }
    }
}

