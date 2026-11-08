#include "gcd.h"
/*5 condition for gcd*/

uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    if (a == b)
        return a;  // condition 1
    if (a == 0)
        return b;  // condition 2
    if (b == 0)
        return a;                             // condition 2
    if (!(a & 1) && !(b & 1))                 // a&1 奇數判斷
        return gcd_u32(a >> 1, b >> 1) << 1;  // condition 3
    if (!(a & 1))
        return gcd_u32(a >> 1, b);  // condition 4
    if (!(b & 1))
        return gcd_u32(a, b >> 1);  // condition 4
    if (a > b)
        return gcd_u32((a - b) >> 1, b);  // condition 5
    else
        return gcd_u32((b - a) >> 1, a);  // condition 5
}
