# gcd_u32_asm: binary GCD, hand-written RV32I.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tgcd.c.

    .text

    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2
gcd_u32_asm:
    li t3,0
    
check:
    beq a0, a1, return_result #if(a==b) return a or b
    beq a0, x0, return_b
    beq a1, x0, return_a
    andi t0, a0, 1 #odd or even ,t0存a跟1 and之後的value t0=a0是奇數 t1 =a1是奇數
    andi t1, a1, 1 #t1存b跟1 and之後的value
    or t2,t0,t1  #用t2來存取如果其中一個是奇數
    beq t2,zero,both_even
    beq t0, zero, a_even
    beq t1, zero, b_even
    bltu a1,a0,a_larger
    j b_larger
    
    
    
return_a:
    j return_result
    
return_b:
    add a0, a1, x0 #result in a0
    j return_result
both_even:
    srli a0,a0,1
    srli a1,a1,1
    addi t3,t3,1
    j  check
    
a_even:
    srli a0, a0, 1
    j check
    
b_even:
    srli a1, a1, 1
    j check
    
a_larger:
    sub a0, a0, a1
    srli a0, a0, 1
    j check
    
b_larger:
    sub a1, a1, a0
    srli a1, a1, 1
    j check
    
return_result:
    sll a0, a0,t3
    ret
.size   gcd_u32_asm, .-gcd_u32_asm
