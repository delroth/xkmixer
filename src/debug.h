// SPDX-License-Identifier: MIT
//
// Useful common types definitions used throughout the project.

#ifndef __XKMIXER_DEBUG_H_
#define __XKMIXER_DEBUG_H_

#ifdef NDEBUG
#define dprintf(...)
#else
#include <stdio.h>

#define dprintf printf
#endif

#endif
