.section .data

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