// SPDX-License-Identifier: MIT
//
// I2C, bitbanged over the lower 2 bits of an XS2 4 bit I/O port. Supports
// clock stretching, but no multi-master / arbitration.

#include "i2c.h"

#include "debug.h"
#include "timeutils.h"

#include <platform.h>

// Board configuration.
#define I2C_PORT XS1_PORT_4A
#define I2C_PORT_SDA_BIT 1
#define I2C_PORT_SCL_BIT 0
#define I2C_CLK_HZ 100000u
#define I2C_TIMEOUT_US 1000u

// We internally use 4 "cycles" within one bus clock cycle. This is because we
// must guarantee that SDA does not change while SCL is high. We only update
// SDA halfway into SCL being low, which is half of half the bus cycle.
#define DELAY_TICKS ((INTERNAL_TICK_HZ / I2C_CLK_HZ) / 4u)

#define SDA_SCL(sda, scl) ((((int)!!(sda)) << (I2C_PORT_SDA_BIT)) | \
                           (((int)!!(scl)) << (I2C_PORT_SCL_BIT)))

#define EXTRACT_SDA(v) (((v) >> (I2C_PORT_SDA_BIT)) & 1)
#define EXTRACT_SCL(v) (((v) >> (I2C_PORT_SCL_BIT)) & 1)

static port s_i2c_port = XS1_PORT_4A;

void i2c_init(void)
{
    s_i2c_port :> void; // Hi-Z.
    // 0 = pull down, 1 = Hi-Z. I2C uses external pull-ups.
    set_port_drive_low(s_i2c_port);
}

static void i2c_delay(void)
{
    timer t;
    u32 time;

    t :> time;
    t when timerafter(time + DELAY_TICKS) :> void;
}

static int i2c_wait_for_stretching(void)
{
    // Waits up to I2C_TIMEOUT_US for the target to stop stretching SCL.
    // Note: SCL must be held hi-z before this function is called.
    timer t;
    u32 time, deadline;

    t :> time;
    deadline = time + I2C_TIMEOUT_US * 100;
    while (EXTRACT_SCL(peek(s_i2c_port)) == 0)
    {
        t when timerafter(time + 100) :> time;
        if (time >= deadline)
            return -1;
    }
    return 0;
}

static void i2c_start(void)
{
    // Start sequence: initially SDA=SCL=1 (hi-z). Pull SDA low, wait,
    // pull SCL low.
    s_i2c_port <: SDA_SCL(0, 1);
    i2c_delay(); i2c_delay();
    s_i2c_port <: SDA_SCL(0, 0);
    i2c_delay(); i2c_delay();
}

static int i2c_stop(void)
{
    // Stop sequence: ensure SDA=SCL=0. Go Hi-Z on SCL then SDA.
    s_i2c_port <: SDA_SCL(0, 0);
    i2c_delay(); i2c_delay();
    s_i2c_port <: SDA_SCL(0, 1);
    i2c_delay(); i2c_delay();
    if (i2c_wait_for_stretching() < 0)
    {
        dprintf("i2c timeout while stopping TXN\n");
        return -1;
    }
    s_i2c_port :> void;
    i2c_delay(); i2c_delay();
    return 0;
}

static int i2c_read_bit(u8& val)
{
    // SDA Hi-Z the whole time, then do a full clock cycle with SCL.
    s_i2c_port <: SDA_SCL(1, 0);
    i2c_delay();
    s_i2c_port <: SDA_SCL(1, 1);
    if (i2c_wait_for_stretching() < 0)
    {
        dprintf("i2c timeout while reading bit\n");
        return -1;
    }
    i2c_delay();
    val = EXTRACT_SDA(peek(s_i2c_port));
    i2c_delay();
    s_i2c_port <: SDA_SCL(1, 0);
    i2c_delay();
    return 0;
}

static int i2c_write_bit(u8 val)
{
    // We start halfway into SCL=0, so we're safe to set SDA. Then hold, and
    // set back to Hi-Z when releasing.
    s_i2c_port <: SDA_SCL(val, 0);
    i2c_delay();
    s_i2c_port <: SDA_SCL(val, 1);
    i2c_delay();
    if (i2c_wait_for_stretching() < 0)
    {
        dprintf("i2c timeout while writing bit\n");
        return -1;
    }
    i2c_delay();
    s_i2c_port <: SDA_SCL(1, 0);
    return 0;
}

static int i2c_read_byte(u8& val, u8 ack)
{
    val = 0;
    u8 bit;

    for (u8 i = 0; i < 8; ++i)
    {
        if (i2c_read_bit(bit) < 0)
            return -1;
        val |= bit << (7 - i);
    }

    if (i2c_write_bit(ack) < 0)
        return -1;

    return 0;
}

static int i2c_write_byte(u8 val)
{
    for (u8 i = 0; i < 8; ++i)
    {
        u8 bit = !!(val & (1 << (7 - i)));
        if (i2c_write_bit(bit) < 0)
            return -1;
    }

    u8 ack;
    if (i2c_read_bit(ack) < 0)
        return -1;

    return ack;  // ACK=0, NAK=1
}

int i2c_read_reg(u8 dev, u8 reg, byte data[], u16 size)
{
    int err;

    i2c_start();

    if ((err = i2c_write_byte(dev << 1)) != 0)
    {
        dprintf("i2c_read_reg(%08x, %08x): wdev write failed (err=%d)\n",
                dev, reg, err);
        return -1;
    }
    if ((err = i2c_write_byte(reg)) != 0)
    {
        dprintf("i2c_read_reg(%08x, %08x): reg write failed (err=%d)\n",
                dev, reg, err);
        return -1;
    }

    if (i2c_stop() < 0)
    {
        dprintf("i2c_read_reg(%08x, %08x): middle stop failed\n", dev, reg);
        return -1;
    }
    i2c_start();

    if ((err = i2c_write_byte((dev << 1) | 1)) != 0)
    {
        dprintf("i2c_read_reg(%08x, %08x): rdev write failed (err=%d)\n",
                dev, reg, err);
        return -1;
    }

    for (u16 i = 0; i < size; ++i)
    {
        if (i2c_read_byte(data[i], i == (size - 1)) < 0)
        {
            dprintf("i2c_read_reg(%08x, %08x): byte %d read failed\n",
                    dev, reg, i);
            return -1;
        }
    }

    if (i2c_stop() < 0)
    {
        dprintf("i2c_read_reg(%08x, %08x): final stop failed\n", dev, reg);
        return -1;
    }

    return 0;
}

int i2c_write_reg(u8 dev, u8 reg, const byte data[], u16 size)
{
    int err;

    i2c_start();
    if ((err = i2c_write_byte(dev << 1)) != 0)
    {
        dprintf("i2c_write_reg(%08x, %08x): dev write failed (err=%d)\n",
                dev, reg, err);
        return -1;
    }
    if ((err = i2c_write_byte(reg)) != 0)
    {
        dprintf("i2c_write_reg(%08x, %08x): reg write failed (err=%d)\n",
                dev, reg, err);
        return -1;
    }

    for (u16 i = 0; i < size; ++i)
    {
        if ((err = i2c_write_byte(data[i])) != 0)
        {
            dprintf("i2c_write_reg(%08x, %08x): byte %d write failed (err=%d)\n",
                    dev, reg, i, err);
            return -1;
        }
    }

    if (i2c_stop() < 0)
    {
        dprintf("i2c_write_reg(%08x, %08x): stop failed\n", dev, reg);
        return -1;
    }

    return 0;
}
