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

    movq %rdi, %r10                 #Pegando o tamanho de alocação pelo rdi e quardando no r10

    movq original_brk, %rax         # rax = endereço_heap
    movq %rdi, %r8                 # r8 = tamanho_alocacao



    busca_livre:
        cmpq %rax, current_brk      # current_brk > %rax ==> Verificação de ponteiros, se a posicao do qual deseja ver o valor passar de current_brk da segfault
        jle insere_final_heap              # if ( current_brk <= rax ) ==> ja sei que preciso atualizar ponteiro do brk
        
        cmpq $0, (%rax)             # if(endereco==0) ==> bloco_livre
        je bloco_livre

        jmp bloco_ocupado
    

    bloco_livre:
        movq 8(%rax), %r11          # r11 = tamanho do bloco
        movq %r11, %r12             # r12 = r11
        subq %r8, %r12              # tamanho_bloco - tamanho_para_alocar 
        movq %rax, %rbx
        cmpq $0, %r12               # if( r12 < 0 )
        jl bloco_ocupado

        cmpq $3, %r12               # if( r12 < 3 )
        jl formata_header



        subq $16, %r12              # tamanho_bloco - tamanho_para_alocar - header
        addq %r8, %rbx
        addq $16, %rbx
        movq $0, (%rbx)
        movq %r12, +8(%rbx)
        movq %rax, %rbx
        jmp formata_header

    bloco_ocupado:
        movq 8(%rax), %r11          # r11 = tamanho do bloco
        movq %rax, %rbx
        addq %r11, %rbx
        movq %rbx, %rax
        addq $16, %rax
        jmp busca_livre




    arruma_ponteiro_heap:
        movq current_brk, %rdi      # rdi = final_heap
        addq %r8, %rdi             # rdi = final_heap + tamanho_segmento
        addq $16, %rdi              # rdi = final_heap + tamanho_segmento + header
        movq $12, %rax              # chamada syscall
        syscall
        movq current_brk, %rbx      # rdx servindo de backup do ponteiro currente_brk antes de ser alterado
        movq %rdi, current_brk  
        jmp formata_header    

    insere_final_heap:
        jmp arruma_ponteiro_heap
        formata_header:
            movq $1, (%rbx)
            movq %r8, +8(%rbx)
            addq $16, %rbx
            movq %rbx, %rax
            jmp finaliza


    finaliza:
        popq %rbp
        ret






# marca um bloco ocupado como livre
memory_free:
    pushq %rbp
    movq %rsp, %rbp
    
    movq original_brk, %rdx
    movq %rdi, %r10
    subq $16, %r10
    movq $0, (%r10)

    popq %rbp
    ret
    