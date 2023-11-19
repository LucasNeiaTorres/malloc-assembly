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
    movq %rdi, %rsi                 # rsi = tamanho_alocacao
    addq $2, %rsi                   # rsi = tamanho_alocacao + 2

    # Essas 3 funções estão formando um while

    busca_livre:
        cmpq %rax, current_brk      # current_brk > %rax ==> Verificação de ponteiros, se a posicao do qual deseja ver o valor passar de current_brk da segfault
        jle altera_brk              # if ( current_brk <= rax ) ==> ja sei que preciso atualizar ponteiro do brk
        
        cmpq $0, (%rax)             # if(endereco==0) ==> bloco_livre
        je verifica_tamanho

        movq +8(%rax), %r13         # r13 = tamanho_bloco ==> Acessando a posição que guarda o tamanho
        addq $2, %r13               # r13 += 2 distancia para o proximo ponteiro
                                    # rax = endereço do segmento
        
        movq %rax, %r11             # r11 = rax
        addq $116, %rax

        popq %rbx
        ret
        movq $8, %rax
        mul %r13                    # rax = r13 * 8
        addq %rax, %r11             # r11 = r11 + rax
        movq %r11, %rax             # rax = r11
        
        #popq %rbp
        #ret

        jmp busca_livre

        verifica_tamanho:
            movq +8(%rax), %r13         # r13 = tamanho_bloco ==> Acessando a posição que guarda o tamanho
            cmpq %rsi, %r13             # r13 >= rsi ==> if( tamanho_bloco >= tamanho_alocacao )
            jge mantem_brk              # marcha
            addq (%r13), %rax           # vai ter q voltar a buscar
            movq %rax, %r11             # r11 = rax
            movq $8, %rax
            mul %r13                     # rax = r13 * 8
            addq %rax, %r11
            movq %r11, %rax
            jmp busca_livre


    encerra:
        movq %rax, %rdi
        movq $60, %rax
        syscall

    mantem_brk:
                                    # r13 = tamanho do bloco
        movq %rax, %r8              # r8 = posicao_inicial do bloco
        movq %r10, %r9              # r9 = tamanho_alocacao que eu quero agora
        subq %r9, %r13              # r13 = r13 - r9
        cmpq $3, %r13               # if ( r13 >= 3 )
        jge fragmenta


        resolve_inicial:
            movq $1, (%r8)              # primeiro endereço = 1 ( ocupado )
            movq %r9, 8(%r8)            # segundo endereco = tamanho_alocacao
            addq $16, %r8               # r8 = posicao_inicial + 16 ==> ponteiro para o primeiro endereço de dados da alocação
            movq %r8, %rax              # retorno pelo rax

            popq %rbp
            ret


    # se o tamanho do bloco for mt grande tem chance da multiplicao quebrar o programa
    fragmenta:
        # r13 ==> tem o espaço de bits que a alocao inicial n vai utilizar
        # r8 ==> posicao inicial do bloco primário
        # r9 ==> tamanho_alocacao que eu quero agora

        movq %r8, %r14      # r14 = r8
        movq $8, %rax
        mul %r9            # rax = r9 * rax ==>  rax = r9*8  ==> soma que preciso fazer para chegar no endereço inicial do bloco seguinte
        addq %rax, %r14     # r14 = r14 + rax ==> endereco do proximo bloco

        movq $0, (%r14)     # primeiro endereço = 0 ( livre )
        subq $16, %r13      # r13 -= 16     ==> como r13 tem o espaço de bits do fragmeto, o tamanho do fragmento vai ser o espaço - "header"
        movq %r13, 8(%r14)
        jmp resolve_inicial


    altera_brk:

        movq %rax, %r14             # r14 = rax ==> inicio_bloco         
        movq %rax, %rbx             # rbx = rax ==> inicio_bloco
        addq %r10, %rbx             # rbx = tamanho_alocacao
        addq $16, %rbx              # rbx = tamanho_alocacao + 16
        movq %rbx, %rdi             # rdi = rbx
        movq $12, %rax              # rax = 12 ==> para chamada de syscall heap
        syscall
        
        movq %rbx, current_brk      # current_brk = tamanho_alocacao + 16
        movq %r14, %r8              # r8 = inicio_bloco
        movq $1, (%r8)              # primeiro endereço = 1 ( ocupado )
        movq %r10, %r9              # r9 = tamanho_alocacao
        movq %r9, 8(%r8)            # segundo endereco = tamanho_alocacao
        addq $16, %r8               # r8 = inicio_bloco + 16 ==> ponteiro para o primeiro endereço de dados da alocação
        movq %r8, %rax              # retorno pelo rax


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
    