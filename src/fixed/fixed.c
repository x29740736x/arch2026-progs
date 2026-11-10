#include "fixed.h"

// op1-> 二進位的加法進位
uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    *n = 0;
    // 程式會需要用到*n來記錄迴圈次數
    while (b) {
        uint32_t c = ((a & b) << 1);
        // C保存a and b 的結果再往左邊移動
        a = (a ^ b);
        // 不含進位的和 XOR
        b = c;
        // 把c assign 給b，下一輪還要處理再加上去
        (*n)++;
    }
    return a;
}
// op2用來做二進位的a-b，原本可以用倒轉b再+1
// 的bits的方式，但是為了達要求bugets要重寫
uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}
// op3用來計算平均整數部分，原本相加再/2可能會造成overflow，所以先同時/2再相加
uint32_t op3(uint32_t a, uint32_t b)
{
    uint32_t c = a & b & 1;
    a = a >> 1;
    b = b >> 1;
    return a + b + c;
}

int32_t q_mul(int32_t a, int32_t b)
{
    int negative = (a < 0) ^ (b < 0);  // xor logic -> check one neg one pos
    uint32_t magnitude_a = (uint32_t) a;
    uint32_t magnitude_b = (uint32_t) b;
    if (a < 0)
        magnitude_a = 0u - magnitude_a;
    if (b < 0)
        magnitude_b = 0u - magnitude_b;

    uint32_t multiplicand_lo = magnitude_a;  // 存到low bits
    uint32_t multiplicand_hi = 0;            // zero out
    uint32_t multiplier = magnitude_b;       // 乘數

    uint32_t product_lo = 0;  // risc-v 32bits而已
    uint32_t product_hi = 0;
    while (multiplier) {
        if (multiplier & 1) {
            uint32_t old_lo = product_lo;
            product_lo = product_lo + multiplicand_lo;
            uint32_t carry = (product_lo < old_lo);  // 如果有進位要去hi_part

            product_hi = product_hi + multiplicand_hi + carry;
        }
        multiplicand_hi = (multiplicand_hi << 1) | (multiplicand_lo >> 31);
        multiplicand_lo = multiplicand_lo << 1;
        multiplier = multiplier >> 1;
    }
    uint64_t product = ((uint64_t) product_hi << 32) | product_lo;
    if (negative)
        product = 0ULL - product;
    product = product + (1ULL << 19);
    uint32_t result_bits = (uint32_t) (product >> 20);
    int64_t result = (int64_t) result_bits;
    if (result_bits & (1u << 31))
        result = result - (1LL << 32);
    return (int32_t) result;
}
