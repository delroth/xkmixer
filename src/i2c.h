// SPDX-License-Identifier: MIT
//
// I2C library to access PLL/ADC/DAC control interfaces.

#ifndef __XKMIXER_I2C_H_
#define __XKMIXER_I2C_H_

#include "types.h"

void i2c_init(void);

int i2c_read_reg(u8 dev, u8 reg, byte data[], u16 size);
int i2c_write_reg(u8 dev, u8 reg, const byte data[], u16 size);

#endif
