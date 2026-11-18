# RV32I port of the Assignment 1 IDA* search.
# a0 = state string, a1 = output buffer, a2 = capacity; a0 = result.
# The 320-byte frame contains input bytes, an 11-move path, twelve
# 20-byte search frames, and the twelve saved callee-saved registers.
# Search frame: permutation row pointer, orientation row pointer,
# continuation address, child budget, forbidden face's first move (byte).

    .text
    .globl rubik_solve_asm
    .type rubik_solve_asm, @function
    .align 2
rubik_solve_asm:
    addi sp, sp, -320
    sw s0, 272(sp)
    sw s1, 276(sp)
    sw s2, 280(sp)
    sw s3, 284(sp)
    sw s4, 288(sp)
    sw s5, 292(sp)
    sw s6, 296(sp)
    sw s7, 300(sp)
    sw s8, 304(sp)
    sw s9, 308(sp)
    sw s10, 312(sp)
    sw s11, 316(sp)
    mv s0, a1
    mv s1, a2

    # Parse the permutation, rejecting short input and repeated cubies.
    li t0, 0
    li t1, 0
    mv t2, sp
.Lrubik_parse_p:
    lbu t3, 0(a0)
    addi t3, t3, -49
    li t4, 7
    bgeu t3, t4, .Lrubik_invalid
    li t4, 1
    sll t4, t4, t3
    and t5, t1, t4
    bne t5, zero, .Lrubik_invalid
    or t1, t1, t4
    sb t3, 0(t2)
    addi a0, a0, 1
    addi t2, t2, 1
    addi t0, t0, 1
    li t4, 7
    bltu t0, t4, .Lrubik_parse_p

    # Parse all seven twists; rank only the first six.
    li t0, 0
    li t1, 0
    li s3, 0
.Lrubik_parse_o:
    lbu t3, 0(a0)
    addi t3, t3, -49
    li t4, 3
    bgeu t3, t4, .Lrubik_invalid
    add t1, t1, t3
    li t4, 6
    beq t0, t4, .Lrubik_last_twist
    slli t4, s3, 1
    add s3, s3, t4
    add s3, s3, t3
.Lrubik_last_twist:
    addi a0, a0, 1
    addi t0, t0, 1
    li t4, 7
    bltu t0, t4, .Lrubik_parse_o
    lbu t0, 0(a0)
    bne t0, zero, .Lrubik_invalid
    li t4, 3
.Lrubik_twist_sum:
    bltu t1, t4, .Lrubik_twist_checked
    addi t1, t1, -3
    j .Lrubik_twist_sum
.Lrubik_twist_checked:
    bne t1, zero, .Lrubik_invalid

    # Lehmer rank: accumulate the six nontrivial digits in mixed radix.
    li s2, 0
    li t0, 0
.Lrubik_rank_outer:
    add t1, sp, t0
    lbu t2, 0(t1)
    addi t3, t0, 1
    li t4, 0
.Lrubik_rank_inner:
    add t5, sp, t3
    lbu t5, 0(t5)
    sltu t5, t5, t2
    add t4, t4, t5
    addi t3, t3, 1
    li t5, 7
    bltu t3, t5, .Lrubik_rank_inner
    # Process each radix using shifts and adds, without a helper call.
    slli t1, t0, 2
    la t2, .Lrubik_radix_jumps
    add t2, t2, t1
    lw t2, 0(t2)
    jr t2
.Lrubik_radix7:
    slli t1, s2, 3
    sub s2, t1, s2
    j .Lrubik_rank_digit
.Lrubik_radix6:
    slli t1, s2, 2
    slli t2, s2, 1
    add s2, t1, t2
    j .Lrubik_rank_digit
.Lrubik_radix5:
    slli t1, s2, 2
    add s2, t1, s2
    j .Lrubik_rank_digit
.Lrubik_radix4:
    slli s2, s2, 2
    j .Lrubik_rank_digit
.Lrubik_radix3:
    slli t1, s2, 1
    add s2, t1, s2
    j .Lrubik_rank_digit
.Lrubik_radix2:
    slli s2, s2, 1
.Lrubik_rank_digit:
    add s2, s2, t4
    addi t0, t0, 1
    li t1, 6
    bltu t0, t1, .Lrubik_rank_outer

    la s8, .Lrubik_permutation_next
    la s9, .Lrubik_orientation_next
    la s10, .Lrubik_permutation_distance
    la s11, .Lrubik_orientation_distance
    addi s7, sp, 16
    or t0, s2, s3
    beq t0, zero, .Lrubik_solved
    add t0, s10, s2
    lbu s4, 0(t0)
    add t0, s11, s3
    lbu t0, 0(t0)
    bgeu s4, t0, .Lrubik_depth11_check
    mv s4, t0

.Lrubik_depth11_check:
    # Recognize the complete distance-11 layer, then still search its path.
    slli t0, s2, 9
    slli t1, s2, 7
    add t0, t0, t1
    slli t1, s2, 6
    add t0, t0, t1
    slli t1, s2, 4
    add t0, t0, t1
    slli t1, s2, 3
    add t0, t0, t1
    add t0, t0, s2
    add t0, t0, s3
    la t1, .Lrubik_distance11
    li t2, 0
    li t3, 2644
.Lrubik_depth11_binary:
    bgeu t2, t3, .Lrubik_start_bound
    add t4, t2, t3
    srli t4, t4, 1
    slli t5, t4, 2
    add t5, t5, t1
    lw t5, 0(t5)
    beq t5, t0, .Lrubik_depth11_found
    bltu t5, t0, .Lrubik_depth11_higher
    mv t3, t4
    j .Lrubik_depth11_binary
.Lrubik_depth11_higher:
    addi t2, t4, 1
    j .Lrubik_depth11_binary
.Lrubik_depth11_found:
    li s4, 11

.Lrubik_start_bound:
    li s5, 0
    addi s6, sp, 32
    slli t0, s2, 4
    slli t1, s2, 1
    add t0, t0, t1
    add t0, t0, s8
    mv a0, t0
    slli t0, s3, 4
    slli t1, s3, 1
    add t0, t0, t1
    add t0, t0, s9
    mv a1, t0
    li a2, 0
    li a5, 9
    addi a6, s4, -1

.Lrubik_search:
.Lrubik_try_0:
    beq a5, zero, .Lrubik_try_3
    lhu a3, 0(a0)
    add t2, s10, a3
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_1
    lhu a4, 0(a1)
    add t2, s11, a4
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_1
    li t0, 0
    la a2, .Lrubik_try_1
    j .Lrubik_accept

.Lrubik_try_1:
    lhu a3, 2(a0)
    add t2, s10, a3
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_2
    lhu a4, 2(a1)
    add t2, s11, a4
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_2
    li t0, 1
    la a2, .Lrubik_try_2
    j .Lrubik_accept

.Lrubik_try_2:
    lhu a3, 4(a0)
    add t2, s10, a3
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_3
    lhu a4, 4(a1)
    add t2, s11, a4
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_3
    li t0, 2
    la a2, .Lrubik_try_3
    j .Lrubik_accept

.Lrubik_try_3:
    li t1, 3
    beq a5, t1, .Lrubik_try_6
    lhu a3, 6(a0)
    add t2, s10, a3
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_4
    lhu a4, 6(a1)
    add t2, s11, a4
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_4
    li t0, 3
    la a2, .Lrubik_try_4
    j .Lrubik_accept

.Lrubik_try_4:
    lhu a3, 8(a0)
    add t2, s10, a3
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_5
    lhu a4, 8(a1)
    add t2, s11, a4
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_5
    li t0, 4
    la a2, .Lrubik_try_5
    j .Lrubik_accept

.Lrubik_try_5:
    lhu a3, 10(a0)
    add t2, s10, a3
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_6
    lhu a4, 10(a1)
    add t2, s11, a4
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_6
    li t0, 5
    la a2, .Lrubik_try_6
    j .Lrubik_accept

.Lrubik_try_6:
    li t1, 6
    beq a5, t1, .Lrubik_backtrack
    lhu a3, 12(a0)
    add t2, s10, a3
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_7
    lhu a4, 12(a1)
    add t2, s11, a4
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_7
    li t0, 6
    la a2, .Lrubik_try_7
    j .Lrubik_accept

.Lrubik_try_7:
    lhu a3, 14(a0)
    add t2, s10, a3
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_8
    lhu a4, 14(a1)
    add t2, s11, a4
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_try_8
    li t0, 7
    la a2, .Lrubik_try_8
    j .Lrubik_accept

.Lrubik_try_8:
    lhu a3, 16(a0)
    add t2, s10, a3
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_backtrack
    lhu a4, 16(a1)
    add t2, s11, a4
    lbu t2, 0(t2)
    bltu a6, t2, .Lrubik_backtrack
    li t0, 8
    la a2, .Lrubik_backtrack
    j .Lrubik_accept

.Lrubik_accept:
    add t1, s7, s5
    sb t0, 0(t1)
    or t1, a3, a4
    beq t1, zero, .Lrubik_found
    # A non-goal with zero remaining moves cannot pass the distance tests.
    li t2, 0
    li t1, 3
    bltu t0, t1, .Lrubik_face_ready
    li t2, 3
    li t1, 6
    bltu t0, t1, .Lrubik_face_ready
    li t2, 6
.Lrubik_face_ready:
    # Keep the active frame in registers; spill only when descending.
    sw a0, 0(s6)
    sw a1, 4(s6)
    sw a2, 8(s6)
    sb a5, 16(s6)
    sw a6, 12(s6)
    addi s6, s6, 20
    slli t0, a3, 4
    slli t1, a3, 1
    add t0, t0, t1
    add t0, t0, s8
    mv a0, t0
    slli t0, a4, 4
    slli t1, a4, 1
    add t0, t0, t1
    add t0, t0, s9
    mv a1, t0
    li a2, 0
    mv a5, t2
    addi a6, a6, -1
    addi s5, s5, 1
    j .Lrubik_search

.Lrubik_backtrack:
    beq s5, zero, .Lrubik_raise_bound
    addi s5, s5, -1
    addi s6, s6, -20
    lw a0, 0(s6)
    lw a1, 4(s6)
    lw a2, 8(s6)
    lbu a5, 16(s6)
    lw a6, 12(s6)
    jr a2
.Lrubik_raise_bound:
    addi s4, s4, 1
    li t0, 12
    bltu s4, t0, .Lrubik_start_bound
    j .Lrubik_invalid

.Lrubik_found:
    addi s5, s5, 1
    j .Lrubik_size_output
.Lrubik_solved:
    li s5, 0
.Lrubik_size_output:
    # Each name takes 1 or 2 bytes; spaces plus NUL add exactly length.
    li t0, 0
    li t1, 1
    beq s5, zero, .Lrubik_check_capacity
    mv t1, s5
    la t2, .Lrubik_names
.Lrubik_size_loop:
    add t3, s7, t0
    lbu t3, 0(t3)
    slli t3, t3, 1
    add t3, t3, t2
    lbu t3, 1(t3)
    snez t3, t3
    addi t1, t1, 1
    add t1, t1, t3
    addi t0, t0, 1
    bltu t0, s5, .Lrubik_size_loop
.Lrubik_check_capacity:
    bltu s1, t1, .Lrubik_small_buffer
    li t0, 0
    mv t1, s0
    beq s5, zero, .Lrubik_output_done
    la t2, .Lrubik_names
.Lrubik_output_loop:
    beq t0, zero, .Lrubik_output_name
    li t3, 32
    sb t3, 0(t1)
    addi t1, t1, 1
.Lrubik_output_name:
    add t3, s7, t0
    lbu t3, 0(t3)
    slli t3, t3, 1
    add t3, t3, t2
    lbu t4, 0(t3)
    sb t4, 0(t1)
    addi t1, t1, 1
    lbu t4, 1(t3)
    beq t4, zero, .Lrubik_next_name
    sb t4, 0(t1)
    addi t1, t1, 1
.Lrubik_next_name:
    addi t0, t0, 1
    bltu t0, s5, .Lrubik_output_loop
.Lrubik_output_done:
    sb zero, 0(t1)
    mv a0, s5
    j .Lrubik_return
.Lrubik_small_buffer:
    beq s1, zero, .Lrubik_small_return
    sb zero, 0(s0)
.Lrubik_small_return:
    li a0, -2
    j .Lrubik_return
.Lrubik_invalid:
    li a0, -1
.Lrubik_return:
    lw s0, 272(sp)
    lw s1, 276(sp)
    lw s2, 280(sp)
    lw s3, 284(sp)
    lw s4, 288(sp)
    lw s5, 292(sp)
    lw s6, 296(sp)
    lw s7, 300(sp)
    lw s8, 304(sp)
    lw s9, 308(sp)
    lw s10, 312(sp)
    lw s11, 316(sp)
    addi sp, sp, 320
    ret
    .size rubik_solve_asm, .-rubik_solve_asm

    .section .rodata
    .balign 4
.Lrubik_radix_jumps:
    .word .Lrubik_radix7, .Lrubik_radix6, .Lrubik_radix5
    .word .Lrubik_radix4, .Lrubik_radix3, .Lrubik_radix2
.Lrubik_names:
    .byte 82, 0, 82, 50, 82, 39, 66, 0, 66, 50, 66, 39, 68, 0, 68, 50, 68, 39

    .include "src/rubik/rubik_tables.inc"
