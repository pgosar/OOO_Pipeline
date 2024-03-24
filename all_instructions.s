    .arch armv8-a
    .text
    // Code for all functions go here.

    .align  2
    .p2align 3,,7
    .global all_instr
    .type   all_instr, %function
    all_instr:
        
        ldur    x0, [x0, #4]
        ldp     x0, x30, [sp], 32
        stur    x0, [x0, #8]
        stp     x0, x30, [sp, -32]!
        movz    x0, #0x123, lsl #16
        movk    x0, #0x456, lsl #32
        adr     x0, label
        adrp    x0, label
        cneg    x0, x0, ne
        csel    x0, x0, x0, eq
        cset    x0, lt
        csetm   x0, lt
        csinc   x0, x0, x0, mi
        csinv   x0, x0, x0, lt
        cneg    x0, x0, ne
        add     x0, x0, x0
        adds    x0, x0, x0
        sub     x0, x0, x0
        subs    x0, x0, x0
        cmp     x0, x0
        mvn     x0, x0
        orr     x0, x0, x0
        eor     x0, x0, x0
        and     x0, x0, x0
        and     x0, x0, x0
        tst     x0, x0
        lsl     x0, x0, #3
        lsr     x0, x0, #2
        sbfm    x0, x0, #8, #16
        ubfm    x0, x0, #4, #12
        asr     x0, x0, #5
        b       branch_target
        beq     branch_target
        b.ne    branch_target
        bl      branch_with_link
        blr     x0
        cbz     x0, branch_target
        ret
        hlt     #1

    branch_target:
        nop

    branch_with_link:
        nop

    label:
    nop
