# as malloc.s -o malloc.o -g; ld malloc.o -o malloc -g

.section .data

.section .text
.global _start

# obtem o endereco de brk
setup_brk:
    pushq %rbp
    movq %rsp, %rbp

    popq %rbp
    ret

# restaura o endereco de brk
dismiss_brk:
    pushq %rbp
    movq %rsp, %rbp
    
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

_start:
    pushq %rbp
    movq %rsp, %rbp


    addq $16, %rsp # depende das variaveis locais
    popq %rbp
    movq $0, %rdi
    movq $60, %rax
    syscall