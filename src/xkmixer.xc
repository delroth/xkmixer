// SPDX-License-Identifier: MIT
//
// Main entry point for the firmware.

#include <stdio.h>

#include "analog.h"
#include "mixer.h"

#ifdef NDEBUG
#define BUILD_TYPE "Release"
#else
#define BUILD_TYPE "Debug"
#endif

int main()
{
    puts("Hi from xkmixer! Build type: " BUILD_TYPE);

    analog_init(SAMPLE_RATE_48000);
    mixer_init();

    chan analog_in, analog_out;
    par {
        analog_io(analog_in, analog_out);
        mixer_mix(analog_in, analog_out);
    }

    return 0;
}
