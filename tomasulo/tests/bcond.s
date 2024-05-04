.arch armv8-a
    .text
    .align    2
    .global start
start:

    movz x0, #1
    movz x1, #2
    subs x3, x0, x1
    b.ne .notequal

.goback:
    // Print x0
    eor     x5, x5, x5
    mvn     x5, x5
    //correct value is 26
    //incorrect value is 1
    //stur    x0, [x5]
    ret

.notequal:
    add x0, x0, #13
    add x0, x0, #12
    b .goback

    .size    start, .-start
    .ident    "GCC: (Ubuntu/Linaro 7.5.0-3ubuntu1~18.04) 7.5.0"
    .section    .note.GNU-stack,"",@progbits
