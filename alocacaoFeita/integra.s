.section .data

.section .text
    .global memory_alloc

memory_alloc:
    pushq %rbp
    movq %rsp, %rbp

    movq %rdi, %rax     #n sei pq o 16rbp n ta funcionando xd
    

    popq %rbp
    ret
    