_start:

.org 0x0
	b restart_handler 			@ Pula para o código que trata o Reset

.org 0x4
	b undef_handler				@ Pula para o código que trata o instruçÕes inválidas

.org 0x8
	b svc_handler				@ Pula para o código que trata syscalls

.org 0xc
	b abort_handler1			@ Pula para o código que trata erros dos barramento ("Prefetch Abort")

.org 0x10
	b abort_handler2			@ Pula para o código que trata erros dos barramento ("Data Abort")

.org 0x18
	b irq_handler				@ Pula para o código que trata interrupções de hardware (IRQ)

.org 0x1c
	b fiq_handler				@ Pula para o código que trata interrupções de hardware (FIQ - modo rápido)

.org 0x100

.align 4

PRC_CTRL:		.word 0x0		@ Armazena as informções sobre quais processos estão vivos.
						@ Se o bit correspondente ao PID do processo é 1, o processo está vivo.
CRNT_PRC:		.word 0x0		@ Armazena o Processo atual

GPT_CR: 		.word 0x53FA0000	@ Endereço do Registrador de Controle do GPT
GPT_Prescaler:		.word 0x53FA0004	@ Endereço do Registrador Prescaler do GPT 
GPT_SR:			.word 0x53FA0008	@ Endereço do Registrador de Status do GPT
GPT_IR:			.word 0x53FA000C	@ Endereço do Registrador de Interrupt do GPT
GPT_OCR1:		.word 0x53FA0010	@ Endereço do Registrador Ouptut Compare 1 do GPT

CLOCK_COUNT:		.word 50		@ Valor até o qual o GPT deve contar antes de gerar uma interrupção

UART1_URXD:		.word 0x53FBC000	@ Endereço do Registrador 1 do UART
UART4_URXD:		.word 0x53FBC000	@ Endereço do Registrador 2 do UART
UART2_URXD:		.word 0x53FC0000	@ Endereço do Registrador 3 do UART
UART3_URXD:		.word 0x53FC4000	@ Endereço do Registrador 4 do UART
UART1_USR1:		.word 0x53FBC094	@ Endereço do Registrador de Status do UART
UART1_UTXD:		.word 0x53FBC040	@ Endereço do Registrador de Transmissão

usuario:

	bl 0x8000

.align 4

infinito:

	b infinito				@ Loop infinito do Sistema Operacional

restart_handler:

	@ Configurar os valores da Pilha das Pilhas

	.set USR_STACK, 0x11000
	.set SVC_STACK, 0x10800
	.set UND_STACK, 0x07c00
	.set ABT_STACK, 0x07800
	.set FIQ_STACK, 0x07400
	.set IRQ_STACK, 0x07000

	@ First configure stacks for all modes
	mov sp, #SVC_STACK 
	msr CPSR_c, #0xDF	@ Enter system mode, FIQ/IRQ disabled
	mov sp, #USR_STACK
	msr CPSR_c, #0xD1	@ Enter FIQ mode, FIQ/IRQ disabled
	mov sp, #FIQ_STACK
	msr CPSR_c, #0xD2	@ Enter IRQ mode, FIQ/IRQ disabled
	mov sp, #IRQ_STACK
	msr CPSR_c, #0xD7	@ Enter abort mode, FIQ/IRQ disabled
	mov sp, #ABT_STACK
	msr CPSR_c, #0xDB	@ Enter undefined mode, FIQ/IRQ disabled
	mov sp, #UND_STACK
	msr CPSR_c, #0x1F	@ Enter system mode, IRQ/FIQ enabled
	
	@ Habilitar Interrupções

	msr CPSR_c, #0x13 			@ Muda para o modo supervisor e habilita interrupções FIQ e IRQ

	@ Configurar o UART

	ldr r2, = UART1_URXD 			@ Carrega o Endereço da UART atual (UARTx)
	
	mov r1, #0x80
	ldr r0, [r0]
	add r0, r2, r1				@ Calcula o Endereço de UARTx-UCR1
	mov r1, #0x0001 				
	str r1, [r0]				@ Habilita o UART

	mov r1, #0x84
	ldr r0, [r0]
	add r0, r2, r1				@ Calcula o Endereço de UARTx-UCR2
	ldr r1, =0x2127
	str r1, [r0]				@ Define o controle de fluxo de Hardware, o formato de dados e habilita o transmissor e o receptor.

	mov r1, #0x88
	ldr r0, [r0]
	add r0, r2, r1				@ Calcula o Endereço de UARTx-UCR3
	ldr r1, =0x0704
	str r1, [r0]				@ Define UCR3[RXDMUXSEL] = 1

	mov r1, #0x8C
	ldr r0, [r0]
	add r0, r2, r1				@ Calcula o Endereço de UARTx-UCR4
	ldr r1, =0x7C00
	str r1, [r0]				@ Define CTS Trigger Level como 31
	
	mov r1, #0x90
	ldr r0, [r0]
	add r0, r2, r1				@ Calcula o Endereço de UARTx-UFCR
	ldr r1, =0x089E
	str r1, [r0]				@ Define o divisor de clock interno como 5 (clock de referênica = 100MHz/5). Define TXTl = 2 e RXTL = 30

	mov r1, #0xA4
	ldr r0, [r0]
	add r0, r2, r1				@ Calcula o Endereço de UARTx-UBIR
	ldr r1, =0x08FF
	str r1, [r0]

	mov r1, #0xA8
	ldr r0, [r0]
	add r0, r2, r1				@ Calcula o Endereço de UARTx-UBMR				
	ldr r1, =0x0C34
	str r1, [r0]				@ Define a taxa de transmissão como 921.6Kbps (baseado no clock de referência de 20MHz)
	
	@ UCR1 = #0x2201 - Não habilitaremos interrupções TRDY e RRDY 

	@ Configurar o GPT (General Purpouse Timer) 

	ldr	r0, =GPT_CR			@ Carrega o endereço de GPT_CR
	ldr	r0, [r0]			
	mov	r1, #0x00000041			@ Valor que habilita e configura o clock_src
	str	r1, [r0]			@ O Contador irá contar a cada ciclo do relógio dos periféricos do sistema

	ldr	r0, =GPT_Prescaler		@ Carrefa o endereço do GPT_Prescaler
	ldr	r0, [r0]		
	mov	r1, #0
	str	r1, [r0]			@ Mantemos o Prescaler zerado
	
	ldr	r0, =GPT_OCR1			@ Carrega o endereço do GPT_OCR1
	ldr	r0, [r0]			
	ldr	r1, =CLOCK_COUNT		@ Valor até o qual desejamos contar antes de gerar uma interrupção tipo "Output Compare Channel 1"
	ldr	r1, [r1]			
	str	r1, [r0]

	ldr	r0, =GPT_IR			@ Carrega o endereço de GPT_IR
	ldr	r0, [r0]			
	mov	r1, #1				@ Valor que habilita a interrupção "Output Compare Channel 1"
	str	r1, [r0]

	@ Configurar o TZIC (TrustZone Interrup Controller)

			   @ Constantes para os endereços do TZIC
			   @ (não são instruções, são diretivas do montador!)
			   .set TZIC_BASE, 0x0FFFC000
			   .set TZIC_INTCTRL, 0x0
			   .set TZIC_INTSEC1, 0x84 
			   .set TZIC_ENSET1, 0x104
			   .set TZIC_PRIOMASK, 0xC
			   .set TZIC_PRIORITY9, 0x424

			@ Liga o controlador de interrupções
			@ R1 <= TZIC_BASE
			ldr	r1, =TZIC_BASE
			@ Configura interrupção 39 do GPT como não segura
			mov	r0, #(1 << 7)
			str	r0, [r1, #TZIC_INTSEC1]
			@ Habilita interrupção 39 (GPT)
			@ reg1 bit 7 (gpt)
			mov	r0, #(1 << 7)
			str	r0, [r1, #TZIC_ENSET1]
			@ Configure interrupt39 priority as 1
			@ reg9, byte 3
			ldr r0, [r1, #TZIC_PRIORITY9]
			bic r0, r0, #0xFF000000
			mov r2, #1
			orr r0, r0, r2, lsl #24
			str r0, [r1, #TZIC_PRIORITY9]
			@ Configure PRIOMASK as 0
			eor r0, r0, r0
			str r0, [r1, #TZIC_PRIOMASK]
			@ Habilita o controlador de interrupções
			mov	r0, #1
			str	r0, [r1, #TZIC_INTCTRL]
			   
	mov	r0, #0B00000001
	bl set_proc				@ Atualiza PRC_CTRL com a ligação do primeiro processo

	b usuario				@ Loop infinito do Sistema Operacional

set_proc:					@ Função auxiliar que atualzia PRC_CTRL e CRNT_PRC. Liga o bit recebido em r0
						@ (processo vivo) de PRC_CTRL e guarda r0 em CRNT_PRC

	ldr	r1, =PRC_CTRL			@ Carrefa o endereço do PRC_CTRL
	ldr	r2, [r1]
	orr	r2, r0, r2			@ Liga o bit recebido em r0	
	str	r2, [r1]
	
	ldr 	r1, =CRNT_PRC
	str 	r0, [r1]			@ Guarda o bit recebido em CRNT_PRC

	mov pc, lr

kill_proc:					@ função auxiliar que atualiza PRC_CTRL, desligando o bit r0 (processo morto).

	mvn	r1, #0x0				@ r1 -> 1111111111111
	eor	r2, r1, r0			@ r2 -> 1111101111111
	ldr	r1, =PRC_CTRL			@ Carrefa o endereço do PRC_CTRL
	ldr	r2, [r1]
	orr	r2, r0, r2			@ Desliga o bit recebido em r0	
	str	r2, [r1]
	
	mov pc, lr

undef_handler:

	sub lr, lr, #4				@ Corrige o valor de LR de PC+8 para PC+4, endereço da próxima instrução
	movs pc, lr

svc_handler:

	@ Verifica o conteudo de r7 para realizar um switch e identificar a syscall
	mov r0, #0x4
	cmp r0, r7
	beq svc_handler_write
	mov r0, #0x0
	cmp r0, r7
	beq svc_handler_exit

svc_handler_write:				@ Trata a syscall write

		@ Escreve os R2 bytes do buffer no dispositivo UART. Retorna o número de bytes escritos (0 se nada for escrito, -1 se ocorrer algum erro). Essa implementação ignora arquivos e descritores de arquivos.

	mrs 	r0, CPSR				@ Desliga as interrupções enquanto ocorre a escrita na UART
	push 	{r0}
	orr 	r0, r0, #0xC0
	msr 	CPSR, r0

	push {r4, r5, r6}

	mov	r3, #0x0			@ Inicializa o contador de bytes escritos

write_end_test:
	cmp 	r1, r3				@ Testa fim da escrita
	beq	write_end

write_waiting:
	ldr	r4, =UART1_USR1			@ Carrega o endereço do UART1_USR1
	ldr	r4, [r4]			
	ldr	r5, =0x1000			@ Mascara para o bit 13 (0x1000 -> 0b 0001 0000 0000 0000)
	and	r6, r5, r4
	cmp	r5, r6				@ Testa se o bit TRDY (13) está definido como 1
	beq	write_add_letter		@ Se o bit estiver setado, escreve o próximo caracter
	b 	write_waiting			@ Se não, tenta de novo

write_add_letter:				@ Adiciona um caracter à fila de impressão TX_FIFO
	ldr	r4, =UART1_UTXD
	ldr	r4, [r4]
	ldr	r5, [r2, #1]!			@ Calcula Próximo caracter e atualzia endereço
	str	r5, [r4]
	add	r3, r3, #1			@ Aumenta contador
	b write_end_test	

write_end:
	pop {r4, r5, r6}
	pop {r0}
	msr 	CPSR, r0

	sub lr, lr, #4				@ Corrige o valor de LR de PC+8 para PC+4, endereço da próxima instrução
	movs pc, lr

svc_handler_exit:				@ Trata a syscall exit

		@ Encerra a execução do processo que a chamou, e libera seu PID para que possa ser usado por outro processo.

	sub lr, lr, #4				@ Corrige o valor de LR de PC+8 para PC+4, endereço da próxima instrução
	movs pc, lr

svc_handler_fork:				@ Trata a syscall fork

	sub lr, lr, #4				@ Corrige o valor de LR de PC+8 para PC+4, endereço da próxima instrução
	movs pc, lr

svc_handler_getpid:				@ Trata a syscall getpid

	sub lr, lr, #4				@ Corrige o valor de LR de PC+8 para PC+4, endereço da próxima instrução
	movs pc, lr

		@ Retorna o Process ID do processo que a chamou

abort_handler1:

	sub lr, lr, #4				@ Corrige o valor de LR de PC+8 para PC+4, endereço da próxima instrução
	movs pc, lr

abort_handler2:

	sub lr, lr, #4				@ Corrige o valor de LR de PC+8 para PC+4, endereço da próxima instrução
	movs pc, lr

irq_handler:

	push {r0, r1}

	ldr	r0, =GPT_SR			@ Carrefa o endereço do GPT_SR
	ldr	r0, [r0]			
	mov	r1, #1				@ Valor que informa ao GPT que o processador está ciente de que ocorreu a interrupção
	str	r1, [r0]			@ GPT limpa a flag OF1

	ldr 	r1, [r0]
	add	r1, r1, #1
	str	r1, [r0]

	pop {r0, r1}
	
	sub lr, lr, #4				@ Corrige o valor de LR de PC+8 para PC+4, endereço da próxima instrução
	movs pc, lr				@ Retorna para LR_irq e grava SPSR em CPSR

fiq_handler:

	@ Trata interrupções de Hardware (FIQ - Modo Rápido)

	sub lr, lr, #4				@ Corrige o valor de LR de PC+8 para PC+4, endereço da próxima instrução
	movs pc, lr
