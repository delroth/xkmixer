// SPDX-License-Identifier: MIT

#include "timeutils.h"

#include <xs1.h>

void usleep(u32 usec)
{
    timer t;
    u32 time;

    t :> time;
    t when timerafter(time + 100 * usec) :> void;
}
