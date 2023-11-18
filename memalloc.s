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
    movq original_brk, %rbx
    movq current_brk, %rcx
    
    _inicio_for:
        cmpq %rbx, %rcx          # %rcx (i) >= %rbx (topo) ==> fim_while
        jge _fim_for
            movq (%rcx), %rdx       # %rdx (bit_ocupado) <-- M[%rcx]
            movq 8(%rcx), %rsi      # %rsi (tamanho) <-- M[%rcx + 8]

            # verifica se o bloco está livre
            cmpq $0, %rdx           # %rdx (bit_ocupado) != 0 ==> fim_if
            jne _fim_if
                # verifica se o tamanho do bloco é suficiente
                cmpq 16(%rbp), %rsi     # %rsi (tamanho) < num_bytes ==> fim_if
                jl _fim_if
                    # marca o bloco como ocupado
                    @ movq $1, %rdx           # %rdx (bit_ocupado) <-- 1
                    @ movq %rdx, (%rcx)       # M[%rcx] <-- %rdx (bit_ocupado)
                    @ movq %rcx, %rax         # %rax <-- %rcx (endereço do bloco)
                    @ addq $16, %rax          # %rax <-- %rax + 16 (endereço do bloco + 16)
                    @ movq %rax, %rcx         # %rcx <-- %rax (endereço do bloco + 16)
                    @ movq 16(%rbp), %rax     # %rax <-- num_bytes
                    @ subq $16, %rax          # %rax <-- %rax - 16 (num_bytes - 16)
                    @ movq %rax, 8(%rcx)      # M[%rcx + 8] <-- %rax (tamanho do bloco)
                    @ movq $1, %rdx           # %rdx (bit_ocupado) <-- 1
                    @ movq %rdx, (%rcx)       # M[%rcx] <-- %rdx (bit_ocupado)
                    @ movq %rcx, %rax         # %rax <-- %rcx (endereço do bloco)
                    @ addq $16, %rax          # %rax <-- %rax + 16 (endereço do bloco + 16)
                    @ movq %rax, current_brk  # current_brk <-- %rax (endereço do bloco + 16)
                    jmp _fim_for

            _fim_if:
        _fim_for:


    popq %rbp
    ret

# marca um bloco ocupado como livre
memory_free:
    pushq %rbp
    movq %rsp, %rbp
    
    popq %rbp
    ret