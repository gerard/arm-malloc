	.include	"syscalls.asi"
	.macro SET_U header
		orr	\header, #0x80000000
	.endm
	.macro SET_F header
		and	\header, #0x7FFFFFFF
	.endm
	.macro USED header
		tst	\header, #0x80000000
	.endm
	.macro LEN len, header
		and	\len, \header, #0x7FFFFFFF
	.endm

	.global	malloc_init
	.global	malloc
	.global	free
	.text

@ Simple memory allocation.  All allocated memory (ie, every malloc call) is
@ prepended with a word whose format is as follows:
@ byte  31    => Used flag (1 for used, 0 for free)
@ bytes 30..0 => Length of the allocated region with header
@   Note that => next = cur + (*cur & 0x7FFFFFFF)

@ Allocation is in charge to fix the contiguous blocks of allocated memory
@ into a simple free area.

@ Error management is for pussies
panic:
	exit	#1

@ No brk/sbrk should be done manually after malloc_init
malloc_init:
	brk	#0
	ldr	r1, .Lbrk_memstart
	str	r0, [r1]
	ldr	r1, .Lbrk_memend
	str	r0, [r1]
	bx	lr

malloc:
	@ Altough the user wants r0, we need r0 + size(header)
	add	r0, #4

	ldr	r5, .Lbrk_memstart
	ldr	r6, .Lbrk_memend
	ldr	r3, [r5]
	ldr	r4, [r6]

.Lmalloc_restart:
	cmp	r3, r4
	beq	.Lmalloc_needs_more
	bpl	panic

	ldr	r1, [r3]
	USED	r1
	LEN	r1, r1

	@ NOT free: Get to the next area
	addne	r3, r1
	bne	.Lmalloc_restart

.Lmalloc_check_fit:
	@ FREE: Is it big enough?
	cmp	r1, r0
	beq	.Lmalloc_perfect_match
	bpl	.Lmalloc_big_enough

	@ FREE: but not enough, is the next free?
	add	r4, r3, r1
	ldr	r2, [r4]
	USED	r2
	LEN	r2, r2

	@ unfit: Start looking again
	addne	r3, r1
	bne	.Lmalloc_restart

	@ FREE: Merge next free location
	add	r1, r2
	b	.Lmalloc_check_fit

.Lmalloc_needs_more:
	mov	r1, r0
	add	r4, r0
	str	r4, [r6]
	brk	r0
	mov	r0, r1
	b	.Lmalloc_perfect_match

@ In this case we need to add a header after the allocated area
.Lmalloc_big_enough:
	sub	r2, r1, r0
	add	r4, r3, r0
	str	r2, [r4]

.Lmalloc_perfect_match:
	SET_U	r0
	str	r0, [r3], #4
	mov	r0, r3
	bx	lr

free:
	sub	r0, #4
	ldr	r1, [r0]
	SET_F	r1
	str	r1, [r0]
	bx	lr

.Lbrk_memstart:
	.local	memstart
	.word	memstart
	.comm	memstart, 4, 4

.Lbrk_memend:
	.local	memend
	.word	memend
	.comm	memend, 4, 4
