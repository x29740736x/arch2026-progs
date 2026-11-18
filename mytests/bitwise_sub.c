#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>

/* Subtraction modulo 2^32 using XOR and repeated borrow propagation. */
uint32_t sub(uint32_t a, uint32_t b)
{
    while (b) {
        uint32_t c = (b & ~a) << 1;
        a = a ^ b;
        b = c;
    }
    return a;
}

int main(void)
{
    uint32_t a = 4;
    uint32_t b = 1;
    uint32_t c = sub(a, b);

    printf("%" PRIu32 " - %" PRIu32 " = %" PRIu32 "\n", a, b, c);
    return c != 3;
}
