#define SCR_NS  0b110001
#define SCR_S   0b110000
#define NSACR_SETTING 0b1110011111111111111
#define NS_BIT	0x1

.macro CP15_SCR_WRITE treg  
	mcr p15, 0, \treg, c1, c1, 0
.endm

.macro CP15_MVBAR_WRITE treg
	mcr p15, 0, \treg, c12, c0, 1
.endm

.macro CP15_NSACR_WRITE treg  
	mcr p15, 0, \treg, c1, c1, 2
.endm

	.ltorg	

	.section .init, "ax"
   	.code 32
   	.align 5

@ ------------------------------------------------------------
@ Monitor mode vector table
@ ------------------------------------------------------------

	.global monitor
monitor:

	@ Monitor
	NOP     @ Reset      - not used by Monitor
	NOP     @ Undef      - not used by Monitor
	B       SMC_Handler
	NOP     @ Prefetch   - can by used by Monitor
	NOP     @ Data abort - can by used by Monitor
	NOP     @ RESERVED
	NOP     @ IRQ        - can by used by Monitor
	NOP     @ FIQ        - can by used by Monitor

@ ------------------------------------------------------------
@ SMC Handler
@
@ - Detect which world executed SMC
@ - Saves state to appropiate stack
@ - Restores other worlds state
@ - Switches world
@ - Performs exception return
@ ------------------------------------------------------------

	.global SMC_Handler
SMC_Handler:
	PUSH   {r0-r3}                       @ R0-r3 contain args to be passed between worlds
	                                     @ Temporarily stack, so can be used as scratch regs
	
	@ Which world have we come from
	@ ------------------------------
	MRC     p15, 0, r0, c1, c1, 0        @ Read Secure Configuration Register data
	TST     r0, #NS_BIT                  @ Is the NS bit set?
	EOR     r0, r0, #NS_BIT              @ Toggle NS bit
	MCR     p15, 0, r0, c1, c1, 0        @ Write Secure Configuration Register data

	ldr r0, =0x020b4004		@ LED0 LED1 off
	ldr r1, =0x3
	str r1, [r0]

	@ Now restore args (r0-r3)
	@ -------------------------
	POP     {r0-r3}

	@ Perform exception return
	@ -------------------------
	MOVS    pc, lr

	.text
	.arm
	.global _sctest  
_sctest:
	/* setup monitor mode */	
	mrs	r0, cpsr
	bic	r0, r0, #0x1f
	orr	r0, r0, #0xd6
	msr	cpsr,r0

	mov r0, #SCR_S
	CP15_SCR_WRITE r0 	@ set SCR secure state

	ldr r0, =monitor	@ get address for MVBAR
	CP15_MVBAR_WRITE r0 @ set MVBAR

	ldr r0, =NSACR_SETTING
	CP15_NSACR_WRITE r0	@ NSACR setting


	ldr r0, =0x021c0000	@ CSU_CSL begin address
	ldr r1, =0x021c009c @ CSU_CSL end address
	ldr r2, =0x00ff00ff @ Secure\Non-Secure can access write CSU policy
	
CSU_CSL_SET:
	str r2, [r0]
	cmp r0, r1
	add r0, r0, #4
	bne	CSU_CSL_SET

	ldr r0, =0x021c0218	@ CSU_SA address
	ldr r2, =0x15554554 @ 
	str r2, [r0]
	
	@ Switch to Normal world  
	@ -----------------------  
	MRC     p15, 0, r4, c1, c1, 0   @ Read Secure Configuration Register data  
	ORR     r4, #NS_BIT				@ Set NS bit  
	MCR     p15, 0, r4, c1, c1, 0   @ Write Secure Configuration Register data
	
	mov pc, lr
	
	.text
	.arm
	
.global _test1
_test1:
	mov ip, lr
	bl LED_OFF_TEST
	mov	lr, ip
	mov pc, lr

.global _test2
_test2:
	mov ip, lr
	bl LED_ON_TEST
	mov	lr, ip
	mov pc, lr	
	
@ End Reset operation-----------------------------------------
LED_OFF_TEST:
	ldr r0, =0x020b4004		@ LED0 LED1 off
	ldr r1, =0x3
	str r1, [r0]
	bx lr
	
LED_ON_TEST:
	ldr r0, =0x020b4004		@ LED0 LED1 on
	ldr r1, =0x0
	str r1, [r0]
	bx lr
