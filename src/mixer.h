// SPDX-License-Identifier: MIT
//
// Handles audio mixing from/to the various sources/sinks on the device.

#ifndef __XKMIXER_MIXER_H_
#define __XKMIXER_MIXER_H_

void mixer_init(void);

void mixer_mix(chanend analog_in, chanend analog_out);

#endif
