	.arch armv8-a
	.text
	.align	2
	.p2align 3,,7
    .global start
start:
    add x1, x1, #0xfff
    adds x2, x1, x1
    adds x2, x2, x1
    subs x3, x1, x1
    subs x3, x3, x1
    subs x3, x3, x1
    csinv x7, x3, x1, eq
	.size	start, .-start
	.ident	"GCC: (Ubuntu/Linaro 7.5.0-3ubuntu1~18.04) 7.5.0"
	.section	.note.GNU-stack,"",@progbits