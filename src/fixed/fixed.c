#include "fixed.h"

// op1-> 二進位的加法進位
uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    *n = 0;
    // 程式會需要用到*n來記錄迴圈次數
    while (b) {  // 用while(b)還要注意有沒有2's
                 // complement導致變成負數的問題，先保留
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
// op2用來做二進位的a-b，原本可以用倒轉b
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
    (void) a;
    (void) b;
    return 0;
}
