	.arch armv8-a
	.text
	.align	2
	.p2align 3,,7
    .global start
start:
    mov x8, #4096
    mov x9, #42
    stur x9, [x8]
    ldur x10, [x8]
	.size	start, .-start
	.ident	"GCC: (Ubuntu/Linaro 7.5.0-3ubuntu1~18.04) 7.5.0"
	.section	.note.GNU-stack,"",@progbits
