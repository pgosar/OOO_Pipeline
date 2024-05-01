	.arch armv8-a
	.text
	.align	2
	.p2align 3,,7
    .global start
start:
    mov x0, #4096
    mov x1, #42
    stur x1, [x0]
    ldur x10, [x0]
    nop
	.size	start, .-start
	.ident	"GCC: (Ubuntu/Linaro 7.5.0-3ubuntu1~18.04) 7.5.0"
	.section	.note.GNU-stack,"",@progbits
