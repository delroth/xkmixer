// SPDX-License-Identifier: MIT
//
// Interface to the analog parts of the XK-AUDIO-216-MC-AB board. This module
// handles configuration as well as input/output from the 8ch ADC/DAC.

#ifndef __XKMIXER_ANALOG_H_
#define __XKMIXER_ANALOG_H_

typedef enum
{
    SAMPLE_RATE_48000,
} sample_rate_t;

void analog_init(sample_rate_t sample_rate);

void analog_io(chanend in_chan, chanend out_chan);

#endif
