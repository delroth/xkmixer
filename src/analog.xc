#include "analog.h"

#include "i2c.h"
#include "platform.h"
#include "timeutils.h"

#include <stdio.h>
#include <xclib.h>

#define CONVERTERS_GPIO_PORT XS1_PORT_8C
#define GPIO_DSD_MODE  (1 << 0)
#define GPIO_DAC_RESET (1 << 1)
#define GPIO_ADC_RESET (1 << 6)
#define GPIO_MCLK_FSEL (1 << 7)

// Cirrus Logic CS5368
#define ADC_I2C_ADDR 0x4C

#define ADC_I2C_GCTL_REG 0x01
#define ADC_GCTL_CPEN (1 << 7)
#define ADC_GCTL_MDIV_DIV2 (1 << 4)
#define ADC_GCTL_FMT_I2S (1 << 2)
#define ADC_GCTL_MODE_SLAVE (3 << 0)

// Cirrus Logic CS4384
#define DAC_I2C_ADDR 0x18

#define DAC_I2C_MODE_CTRL_REG 0x02
#define DAC_MODE_CTRL_CPEN (1 << 7)

#define DAC_I2C_PCM_CTRL_REG 0x03
#define DAC_PCM_CTRL_MODE_AUTO (3 << 0)
#define DAC_PCM_CTRL_FMT_I2S (1 << 4)

out port s_converters_gpio_port = CONVERTERS_GPIO_PORT;

in port s_mclk_port = XS1_PORT_1F;
out buffered port:32 s_sclk_port = XS1_PORT_1H;
out buffered port:32 s_lrclk_port = XS1_PORT_1G;
out buffered port:32 s_dac_ports[4] = {
        XS1_PORT_1M, XS1_PORT_1N, XS1_PORT_1O, XS1_PORT_1P
};
in buffered port:32 s_adc_ports[4] = {
        XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K, XS1_PORT_1L
};
clock s_sclk_clk = XS1_CLKBLK_1;

static void analog_reset_converters(void)
{
    u8 gpio = peek(s_converters_gpio_port);
    gpio &= ~(GPIO_DAC_RESET | GPIO_ADC_RESET);
    s_converters_gpio_port <: gpio;
    usleep(10);

    gpio |= (GPIO_DAC_RESET | GPIO_ADC_RESET);
    s_converters_gpio_port <: gpio;
    usleep(100);
}

static void analog_disable_dsd_mode(void)
{
    // In DSD mode the ADC input is not connected to the DSP, in favor of
    // 8 direct DAC connections (vs. 4 DAC, 4 ADC). We don't need DSD.
    s_converters_gpio_port <: peek(s_converters_gpio_port) & ~GPIO_DSD_MODE;
    // This only controls a MUXSEL, doesn't need a long delay to settle.
    usleep(1);
}

static void analog_pick_mclk(int use_48k)
{
    if (use_48k)
        s_converters_gpio_port <: peek(s_converters_gpio_port) | GPIO_MCLK_FSEL;
    else
        s_converters_gpio_port <: peek(s_converters_gpio_port) & ~GPIO_MCLK_FSEL;
}

static void adc_init()
{
    u8 gctl = ADC_GCTL_CPEN | ADC_GCTL_MDIV_DIV2 | ADC_GCTL_FMT_I2S | ADC_GCTL_MODE_SLAVE;
    i2c_write_reg(ADC_I2C_ADDR, ADC_I2C_GCTL_REG, &gctl, 1);
}

static void dac_init()
{
    u8 mode_ctrl = DAC_MODE_CTRL_CPEN;
    u8 pcm_ctrl = DAC_PCM_CTRL_MODE_AUTO | DAC_PCM_CTRL_FMT_I2S;

    i2c_write_reg(DAC_I2C_ADDR, DAC_I2C_MODE_CTRL_REG, &mode_ctrl, 1);
    i2c_write_reg(DAC_I2C_ADDR, DAC_I2C_PCM_CTRL_REG, &pcm_ctrl, 1);
}

void analog_init(sample_rate_t sample_rate)
{
    i2c_init();

    analog_reset_converters();
    analog_disable_dsd_mode();
    analog_pick_mclk(sample_rate == SAMPLE_RATE_48000);

    adc_init();
    dac_init();

    u8 revi1, revi2;

    if (i2c_read_reg(0x4C, 0x00, &revi1, 1) < 0)
    {
        printf("Could not read REVI from CS5368\n");
        return;
    }
    if (i2c_read_reg(0x18, 0x01, &revi2, 1) < 0)
    {
        printf("Could not read REVI from CS4384\n");
        return;
    }

    printf("CS5368 REVI: %d\n", revi1);
    printf("CS4384 REVI: %d\n", revi2);
}

void analog_io(chanend in_chan, chanend out_chan)
{
    u32 lrclk = 0xFFFF0000;

    set_clock_on(s_sclk_clk);
    configure_clock_src_divide(s_sclk_clk, s_mclk_port, 8);
    configure_port_clock_output(s_sclk_port, s_sclk_clk);
    configure_out_port(s_lrclk_port, s_sclk_clk, 0);
    clearbuf(s_lrclk_port);
    for (int i = 0; i < 4; ++i)
    {
        configure_out_port(s_dac_ports[i], s_sclk_clk, 0);
        clearbuf(s_dac_ports[i]);
        configure_in_port(s_adc_ports[i], s_sclk_clk);
        clearbuf(s_adc_ports[i]);
    }

    // Align the cycles for all the outputs. LRCLK is offset from the data.
    s_lrclk_port @ 1 <: lrclk;
    for (int i = 0; i < 4; ++i)
    {
        s_dac_ports[i] @ 0 <: 0;
    }

    start_clock(s_sclk_clk);

    while (1)
    {
        s_lrclk_port <: lrclk;

        s16 tl = 0, tr = 0;
        for (int i = 0; i < 4; ++i)
        {
            u32 s;
            s16 l, r;
            s_adc_ports[i] :> s;
            s = bitrev(s);
            l = (s16)(s >> 16);
            r = (s16)s;

            in_chan <: l;
            in_chan <: r;
        }
        for (int i = 0; i < 4; ++i)
        {
            s16 l, r;
            out_chan :> l;
            out_chan :> r;
            s_dac_ports[i] <: bitrev(((u32)l << 16) | ((u32)r & 0xFFFF));;
        }
    }
}
