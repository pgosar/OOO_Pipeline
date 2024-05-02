.arch armv8-a
    .text
    .align    2
    .global start
start:
    adds x0, x0, x0
    b.eq .equal

.goback:
    // Print x0
    mov x0, #0xBAD
    ret
    //correct value is 26
    //incorrect value is 1

.equal:
    mov x0, #0xAAA
    nop
    ret

    .size    start, .-start
    .ident    "GCC: (Ubuntu/Linaro 7.5.0-3ubuntu1~18.04) 7.5.0"
    .section    .note.GNU-stack,"",@progbits
