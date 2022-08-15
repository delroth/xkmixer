#include "analog.h"

#include "i2c.h"
#include "platform.h"
#include "timeutils.h"

#include <stdio.h>

#define CONVERTERS_GPIO_PORT XS1_PORT_8C
#define GPIO_DAC_RESET (1 << 1)
#define GPIO_ADC_RESET (1 << 6)

out port s_converters_gpio_port = CONVERTERS_GPIO_PORT;

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

void analog_init(sample_rate_t sample_rate)
{
    i2c_init();

    analog_reset_converters();

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
