// SPDX-License-Identifier: MIT

#include "mixer.h"

#include "types.h"

void mixer_init(void)
{
}

void mixer_mix(chanend analog_in, chanend analog_out)
{
    while (1)
    {
        s16 tot_l = 0, tot_r = 0;
        int i;

        for (i = 0; i < 4; ++i)
        {
            s16 l, r;
            analog_in :> l;
            analog_in :> r;
            tot_l += l;
            tot_r += r;
        }
        for (i = 0; i < 4; ++i)
        {
            analog_out <: tot_l;
            analog_out <: tot_r;
        }
    }
}
