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
    movq $12, %rax              # código da syscall para o brk
    movq $0, %rdi      # brk restaura valor inicial da heap
    syscall

    movq %rax, original_brk
    movq %rax, current_brk

    ret

# restaura o endereco de brk
dismiss_brk:
    movq $12, %rax              # código da syscall para o brk
    movq original_brk, %rdi      # brk restaura valor inicial da heap
    syscall

    ret

# 1. Procura bloco livre com tamanho igual ou maior que a requisição
# 2. Se encontrar, marca ocupação, utiliza os bytes necessários do bloco, retornando o endereço correspondente
# 3. Se não encontrar, abre espaço para um novo bloco
memory_alloc:
    pushq %rbp
    movq %rsp, %rbp

    movq 16(%rbp), %r10             # Pegando o tamanho de alocação pelo rdi e quardando no r10

    movq original_brk, %rax         # rax = endereço_heap
    movq %rdi, %r8                  # r8 = tamanho_alocacao


    # Primeira comparação verifica se o ponteiro que percorre a lista de alocações ja chegou ao ponto final_heap
    # Segunda comparação para verificar se cada segmento esta livre
    busca_livre:
        cmpq %rax, current_brk      # current_brk > %rax ==> Verificação de ponteiros, se a posicao do qual deseja ver o valor passar de current_brk da segfault
        jle arruma_ponteiro_heap       # if ( current_brk <= rax ) ==> ja sei que preciso atualizar ponteiro do brk
        
        cmpq $0, (%rax)             # if(endereco==0) ==> bloco_livre
        je bloco_livre

        jmp bloco_ocupado           # caso contrário o bloco esta ocupado
    

    # Quando bloco livre primeiro procura o tamanho dele para ver se o bloco a ser inserido cabe
    # Depois é necessário verificar se fragmenta ou não: Caso tenha 3 bytes livre nao framgenta, apenas arruma os ponteiros iniciais
    # Caso fragmentação, ao fim do bloco alocado, corrige os ponteiro gerando então esse novo bloco
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
        addq %r8, %rax              # rax = tamanho_alocacao <-- aponta para o inicio do bloco fragmentado
        addq $16, %rax              # rax = tamanho_alocacao + header
        movq $0, (%rax)             # bloco_fragmentado.ocupado = 0 ==> não esta ocupado
        movq %r12, 8(%rax)         # bloco_fragmentado.tamanho = tamanho_bloco - tamanho_para_alocar - header
        jmp formata_header

    bloco_ocupado:
        movq 8(%rax), %r11          # r11 = tamanho do bloco
        addq %r11, %rax             # adiciona o tamanho do bloco no endereço de rax
        addq $16, %rax              # rax += 16
        jmp busca_livre

    arruma_ponteiro_heap:
        movq current_brk, %rdi      # rdi = final_heap
        addq %r8, %rdi              # rdi = final_heap + tamanho_segmento
        addq $16, %rdi              # rdi = final_heap + tamanho_segmento + header
        movq $12, %rax              # chamada syscall
        syscall
        movq current_brk, %rbx      # rdx servindo de backup do ponteiro currente_brk antes de ser alterado
        movq %rdi, current_brk      # atualiza current_brk
        jmp formata_header    

    formata_header:                 
        movq $1, (%rbx)             # Bloco ocupado
        movq %r8, 8(%rbx)          # Tamanho do bloco em segmento.tamanho
        addq $16, %rbx              # Endereço do inicio da araa alocada = ponteiro de ocupado + 16
        movq %rbx, %rax             # Endereço de retorno
        jmp finaliza


    finaliza:
        popq %rbp
        ret



# marca um bloco ocupado como livre
memory_free:
    pushq %rbp
    movq %rsp, %rbp
    
    movq %rdi, %r10
    cmpq current_brk, %r10          
    jg invalido                     # if ( r10 > current_brk )
    subq $16, %r10                  # Busca o endereço de ocupação
    movq $0, (%r10)                 # Define ocupado como 0
    movq $1, %rax                   # Operação bem sucedida
    popq %rbp
    ret

    invalido:
    movq $0, %rax                   # Operação mal sucedida
    popq %rbp
    ret
    