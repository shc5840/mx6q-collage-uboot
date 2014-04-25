#define  SCR_NS_BIT     0x1
#define  SCR_FIQ_BIT    0x4
#define  SCR_IRQ_BIT    0x2

#define  Mode_USR       0x10
#define  Mode_FIQ       0x11
#define  Mode_IRQ       0x12
#define  Mode_SVC       0x13
#define  Mode_MON       0x16
#define  Mode_ABT       0x17
#define  Mode_UNDEF     0x1B
#define  Mode_SYS       0x1F

#define  I_BIT          0x80
#define  F_BIT          0x40

.equ	Len_MON_Stack,	1024
.equ	Len_FIQ_Stack,	1024
.equ	Len_IRQ_Stack,	1024
.equ	Len_ABT_Stack,	1024
.equ	Len_UND_Stack,	1024
.equ	Len_SVC_Stack,	1024
.equ	Len_SYS_Stack,	1024

.equ 	Offset_MON_Stack,	0
.equ 	Offset_FIQ_Stack,	Offset_MON_Stack + Len_MON_Stack
.equ 	Offset_IRQ_Stack,	Offset_FIQ_Stack + Len_FIQ_Stack
.equ 	Offset_ABT_Stack,	Offset_IRQ_Stack + Len_IRQ_Stack
.equ 	Offset_UND_Stack,	Offset_ABT_Stack + Len_ABT_Stack
.equ 	Offset_SVC_Stack,	Offset_UND_Stack + Len_UND_Stack
.equ 	Offset_SYS_Stack,	Offset_SVC_Stack + Len_SVC_Stack

.macro CP15_SCR_WRITE treg  
	mcr p15, 0, \treg, c1, c1, 0
.endm

.macro CP15_MVBAR_WRITE treg
	mcr p15, 0, \treg, c12, c0, 1
.endm

.macro CP15_NSACR_WRITE treg  
	mcr p15, 0, \treg, c1, c1, 2
.endm

.macro scr_nsbit_set rt
	mrc     p15, 0, \rt, c1, c1, 0  @ Read Secure Configuration Register
	orr	\rt, \rt, #SCR_NS_BIT
	mcr     p15, 0, \rt, c1, c1, 0  @ Write Secure Configuration Register
.endm

.macro scr_nsbit_clear rt
	mrc     p15, 0, \rt, c1, c1, 0  @ Read Secure Configuration Register
	bic	\rt, \rt, #SCR_NS_BIT
	mcr     p15, 0, \rt, c1, c1, 0  @ Write Secure Configuration Register
.endm	

   	
.text
.arm
.align 5
.global _sctest
_sctest:
	mov ip, lr
	
	b _start_1
	
	mov	lr, ip
	mov pc, lr
	
@ ------------------------------------------------------------
@ vector table
@ ------------------------------------------------------------
.align 5
.global normal_vectors
normal_vectors:
	B      _sec_reset_handler
    B      _sec_undefined_handler
    B      _sec_swi_handler
    B      _sec_prefetch_handler
    B      _sec_abort_handler
    B      _sec_reserved_vector
    B      _sec_irq_handler
    B      _sec_fiq_handler
	
_sec_reset_handler:
    B       _sec_reset_handler
	
_sec_undefined_handler:
    B       _sec_undefined_handler	
	
_sec_swi_handler:
    B       _sec_swi_handler

_sec_prefetch_handler:
    B       _sec_prefetch_handler	

_sec_abort_handler:
    B      _sec_abort_handler	

_sec_reserved_vector:
    B       _sec_reserved_vector
	
_sec_irq_handler:
    B 		_sec_irq_handler

_sec_fiq_handler:
    B       _sec_fiq_handler


@ ------------------------------------------------------------
@ Monitor mode vector table
@ ------------------------------------------------------------
.align 5
.global monitor
monitor:
	@ Monitor
	NOP     @ Reset      - not used by Monitor
	NOP     @ Undef      - not used by Monitor
	B       smp_smc_handler
	NOP     @ Prefetch   - can by used by Monitor
	NOP     @ Data abort - can by used by Monitor
	NOP     @ RESERVED
	NOP     @ IRQ        - can by used by Monitor
	NOP     @ FIQ        - can by used by Monitor

@ ------------------------------------------------------------
@ SMC Handler
@
@ - Detect which world executed SMC
@ - Saves state to appropriate stack
@ - Restores other worlds state
@ - Switches world
@ - Performs exception return
@ ------------------------------------------------------------
.align	5
.global SMC_Handler
SMC_Handler:
	PUSH   {r0-r3}                       @ R0-r3 contain args to be passed between worlds
	                                     @ Temporarily stack, so can be used as scratch regs
	
	@ Which world have we come from
	@ ------------------------------
	MRC     p15, 0, r0, c1, c1, 0        @ Read Secure Configuration Register data
	TST     r0, #SCR_NS_BIT              @ Is the NS bit set?
	EOR     r0, r0, #SCR_NS_BIT          @ Toggle NS bit
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

@ ------------------------------------------------------------
@ smc handler form openvirtualization source code
@ ------------------------------------------------------------	
.align	5
.global smp_smc_handler	
smp_smc_handler:
	ldr r0, =0x020b4004		@ LED0 LED1 off
	ldr r1, =0x3
	str r1, [r0]
	
	mrc     p15, 0, r1, c1, c1, 2        @ Read Non-Secure Access Control Register
    ldr r2, =0x60C00
    orr     r1, r1, r2
    mcr     p15, 0, r1, c1, c1, 2
	
	@ change it to non-secure
    scr_nsbit_set r3
	
	@ Set the SPSR to be in SVC mode
    msr     spsr_cxsf, #Mode_SVC         @ Set SPSR to be SVC m
	
	bx lr

@ ------------------------------------------------------------
@ entrance for additional part
@ ------------------------------------------------------------	
.global _start_1	
_start_1:
    /* setup monitor mode */   
    mrs     r0, cpsr
    bic     r0, r0, #0x1f
    orr     r0, r0, #0xd6
    msr     cpsr,r0
	
	ldr r0, =normal_vectors		@ get address for VBAR
	mcr p15, 0, r0, c12, c0, 0  @ Write Current world VBA
	
	ldr r0, =monitor			@ get address for MVBAR
	mcr p15, 0, r1, c12, c0, 1	@ set MVBAR


@ Initialize stacks for all modes
	ldr r0, =0x00938000		@ free iram address 0x00907000 - 0x00938000
	
@ set FIQ stack 
	msr CPSR_c,#(Mode_FIQ | I_BIT | F_BIT)
	sub	sp, r0, #Offset_IRQ_Stack
	
@ set ABT stack
	msr CPSR_c,#(Mode_ABT | I_BIT | F_BIT)
	sub	sp, r0, #Offset_ABT_Stack
	
@ set UND stack
	msr CPSR_c,#(Mode_UNDEF | I_BIT | F_BIT)
	sub	sp, r0, #Offset_UND_Stack
	
@ set user/system stack
	msr CPSR_c,#(Mode_SYS | I_BIT | F_BIT)
	sub	sp, r0, #Offset_SYS_Stack
	
@ set monitor stack
	msr CPSR_c,#(Mode_MON | I_BIT )
	sub	sp, r0, #Offset_MON_Stack
/*
@ set SVC stack 
    msr	CPSR_c,#(Mode_SVC | I_BIT | F_BIT)	
	sub	sp, r0, #Offset_SVC_Stack
*/
	msr	CPSR_c,#(Mode_SVC | I_BIT | F_BIT)	

@ disable mmu & cache	
	mrc     p15, 0, r0, c1, c0, 0    /* read CP15 register 1 into r0 */
    bic     r0, r0, #(0x1  <<13)     /* clear bit 13 */
    bic     r0, r0, #(0x1  <<12)     /* disable I Cache */
    bic     r0, r0, #(0x1  <<2)      /* disable D Cache */
    bic     r0, r0, #(0x1  <<0)      /* disable MMU */
    mcr     p15, 0, r0, c1, c0, 0    /* write CP15 register 1 */
	
@ Invalidate Instruction cache 
    mov R1,#0
    mcr p15, 0, r1, c7, c5, 0

@ Invalidate Branch predictor arrays 
    mov r1,#0
    mcr p15, 0, r1, c7, c5,  6

@ Invalidate TLBs 
    mov r1, #0x0
    mcr p15, 0, r1, c8, c3, 0

    mrc     p15, 0, r1, c1, c0, 0        @ Read SCTLR
    bic     r1, r1, #0x10000000
    bic     r1, r1, #0x00002000
    mcr     p15, 0, r1, c1, c0, 0

	@ @ NSACR configuration
    mrc     p15, 0, r1, c1, c1, 2        @ Read Non-Secure Access Control Register
    ldr     r2, =0x60C00
    orr     r1, r1, r2
    mcr     p15, 0, r1, c1, c1, 2

    @ @ Set the FIQ bit so as to route FIQs to monitor mode
    mrc     p15, 0, r1, c1, c1, 0        @ Read Secure Configuration Register data
    ldr     r2, =0x4             
    orr     r1, r1, r2	
    mcr     p15, 0, r1, c1, c1, 0        @ Write Secure Configuration Register data
	
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
	
	bx lr
	

.align	5
.global LED_OFF_TEST
LED_OFF_TEST:
	ldr r0, =0x020b4004		@ LED0 LED1 off
	ldr r1, =0x3
	str r1, [r0]
	bx lr
	
.align	5	
.global	LED_ON_TEST
LED_ON_TEST:
	ldr r0, =0x020b4004		@ LED0 LED1 on
	ldr r1, =0x0
	str r1, [r0]
	bx lr
