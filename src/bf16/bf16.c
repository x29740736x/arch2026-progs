#include "bf16.h"

uint16_t bf16_from_f32(uint32_t f32bits)
{
    uint32_t exponent = (f32bits >> 23) & 0xFFu;  // 找exponent part
    if (exponent == 0xFFu)                        // case if exponent == 0xFFu
        return (uint16_t) (f32bits >> 16);        // INF跟跟Nan直接return
    uint32_t bits16 = (f32bits >> 16) & 1u;       // 如果剛好一半就往下取
    uint32_t rounded = f32bits + 0x7FFFu + bits16;
    return (uint16_t) (rounded >> 16);
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    uint32_t exponent_a =
        (a >> 7) & 0xFFu;             // check exponent and exclude the sign bit
    uint32_t fraction_a = a & 0x7Fu;  // 7bits of fraction
    uint16_t sign = (a ^ b) & 0x8000u;  // decide sign bits 最高位

    if (exponent_a == 0xFFu && fraction_a != 0u)
        return a;               // 已經是Nan，不用check sign 也不用改
    if (exponent_a == 0xFFu) {  // 處理+-Inf
        if ((b & 0x7FFFu) == 0u)
            return 0x7FC0u;  // 規定的Inf *+-0=0
        return (uint16_t) (sign | 0x7F80u);
    }
    uint32_t exponent_b =
        (b >> 7) &
        0xFFu;  // 如果a是無限b是0上面就回傳，exclude the situation when b=0
    uint32_t fraction_b = b & 0x7Fu;
    if (exponent_b == 0xFFu && fraction_b != 0u)
        return b;
    if (exponent_b == 0xFFu) {
        if ((a & 0x7FFFu) == 0u)  // a  +-0
            return 0x7FC0u;
        return (uint16_t) (sign | 0x7F80u);
    }
    if ((a & 0x7FFFu) == 0u || (b & 0x7FFFu) == 0u)
        return sign;  // finite value * 0

    uint32_t significand_a = fraction_a;
    int32_t exp_a = (int32_t) exponent_a;  // 有offset的a

    if (exp_a != 0) {
        significand_a |= 0x80u;
    } else {
        exp_a = 1;
        while (significand_a < 0x80u) {
            significand_a <<= 1;
            exp_a--;
        }
    }
    uint32_t significand_b = fraction_b;
    int32_t exp_b = (int32_t) exponent_b;

    if (exp_b != 0) {
        significand_b |= 0x80u;
    } else {
        exp_b = 1;
        while (significand_b < 0x80u) {
            significand_b <<= 1;
            exp_b--;
        }
    }

    uint32_t product = 0;
    uint32_t multiplicand = significand_a;
    uint32_t multiplier = significand_b;

    while (multiplier) {
        if (multiplier & 1u)
            product += multiplicand;
        multiplicand <<= 1;
        multiplier >>= 1;
    }

    int32_t exp_product = exp_a + exp_b - 127;  // 扣掉兩個都有的offset
    uint32_t significand_product;

    if (product & 0x8000u) {  // 如果<0
        significand_product = product >> 8;
        exp_product++;
    } else {
        significand_product = product >> 7;
    }
    if (exp_product >= 255)
        return (uint16_t) (sign | 0x7F80u);

    if (exp_product < -6)
        return sign;

    if (exp_product <= 0) {
        uint32_t fraction = (significand_product & 0x7Fu) >> (1 - exp_product);
        return (uint16_t) (sign | fraction);
    }

    return (uint16_t) (sign | ((uint32_t) exp_product << 7) |
                       (significand_product & 0x7Fu));
}
uint16_t bf16_sqrt(uint16_t a)
{
    uint32_t exponent = (a >> 7) & 0xFFu;
    uint32_t fraction = a & 0x7Fu;

    if (exponent == 0xFFu && fraction != 0u)
        return a;
    if ((a & 0x7FFFu) == 0u)
        return 0u;
    if (a & 0x8000u)
        return 0x7FC0u;
    if (exponent == 0xFFu)
        return a;
    if (exponent == 0u)
        return 0u;

    uint32_t significand = 0x80u | fraction;
    uint32_t result_exp = (exponent + 127u) >> 1;

    if ((exponent & 1u) == 0u)
        significand <<= 1;

    uint32_t remainder = ((significand + 1u) << 7) - 1u;
    uint32_t root = 0;

    for (uint32_t bit = 1u << 14; bit != 0u; bit >>= 2) {
        uint32_t trial = root + bit;
        root >>= 1;
        if (remainder >= trial) {
            remainder -= trial;
            root += bit;
        }
    }
    return (uint16_t) ((result_exp << 7) | (root & 0x7Fu));
}
