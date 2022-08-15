// SPDX-License-Identifier: MIT
//
// Main entry point for the firmware.

#include <stdio.h>

int main()
{
    printf("Hello, xkmixer world! Build type: %s\n",
#ifdef NDEBUG
            "Release"
#else
            "Debug"
#endif
            );
    return 0;
}
