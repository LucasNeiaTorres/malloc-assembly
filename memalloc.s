.section .data
    current_brk: .quad 0
.global original_brk
    original_brk:   # A variável que armazena o valor original de brk
   .quad 0      # Inicialmente, pode ser 0 ou o valor atual de brk

.section .text
.global _start
.global setup_brk
.global dismiss_brk
.global memory_alloc
.global memory_free

# obtem o endereco de brk
setup_brk:
    pushq %rbp
    movq %rsp, %rbp

    movq $12, %rax              # código da syscall para o brk
    movq $0, %rdi      # brk restaura valor inicial da heap
    syscall

    movq %rax, original_brk
    movq %rax, current_brk

    popq %rbp
    ret

# restaura o endereco de brk
dismiss_brk:
    pushq %rbp
    movq %rsp, %rbp
    
    movq $12, %rax              # código da syscall para o brk
    movq original_brk, %rdi      # brk restaura valor inicial da heap
    syscall

    popq %rbp
    ret

# 1. Procura bloco livre com tamanho igual ou maior que a requisição
# 2. Se encontrar, marca ocupação, utiliza os bytes necessários do bloco, retornando o endereço correspondente
# 3. Se não encontrar, abre espaço para um novo bloco
memory_alloc:
    pushq %rbp
    movq %rsp, %rbp
    
    popq %rbp
    ret

# marca um bloco ocupado como livre
memory_free:
    pushq %rbp
    movq %rsp, %rbp
    
    popq %rbp
    ret