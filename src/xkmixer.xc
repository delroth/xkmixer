// SPDX-License-Identifier: MIT
//
// Main entry point for the firmware.

#include <stdio.h>

#include "analog.h"

#ifdef NDEBUG
#define BUILD_TYPE "Release"
#else
#define BUILD_TYPE "Debug"
#endif

int main()
{
    puts("Hi from xkmixer! Build type: " BUILD_TYPE);

    analog_init(SAMPLE_RATE_48000);

    return 0;
}
