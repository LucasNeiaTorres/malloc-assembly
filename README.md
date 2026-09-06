# malloc-assembly

> **In English, briefly.** A memory allocator written in x86-64 assembly (GNU as,
> AT&T syntax), with no libc underneath: memory is taken straight from the Linux
> kernel through the `brk` system call (syscall 12). Every block carries a 16-byte
> header — an in-use flag and a size — and the allocator walks that implicit list
> to serve each request, splitting a free block when the leftover is worth
> splitting. The repository holds two versions of the same allocator that differ in
> a single decision: which free block to pick. `Original/` is first-fit,
> `Modificado/` is worst-fit. Both pass the C test program that comes with them.

Um `malloc` escrito à mão, em assembly x86-64, que pede memória ao kernel pela
syscall `brk` e administra a heap sozinho — sem `malloc`, sem `mmap`, sem
biblioteca nenhuma embaixo.

---

## Contexto: por que isto existe

Este é um trabalho de disciplina de graduação, feito em dupla no fim de 2023.
O enunciado é o exercício clássico de sistemas: implementar, em assembly, as
quatro rotinas que um programa em C chama no lugar de `malloc` e `free` —
e depois **trocar a política de escolha do bloco** e mostrar que a diferença
aparece no comportamento.

O interesse dele não está no tamanho (são ~150 linhas de assembly), está em
não haver nada embaixo. Não existe estrutura de dados pronta, não existe
ponteiro tipado, não existe alocação para guardar os metadados da alocação —
os metadados têm de morar dentro da própria memória administrada. É esse
problema, o do ovo e da galinha da alocação, que o trabalho força a resolver.

A interface é fixada pelo `memalloc.h`, que o programa de teste em C inclui:

| Função | O que faz |
|---|---|
| `void setup_brk()` | Captura o topo inicial da heap e guarda em `original_brk` |
| `void *memory_alloc(unsigned long int bytes)` | Devolve o endereço de uma área de `bytes` bytes |
| `int memory_free(void *pointer)` | Marca o bloco como livre; devolve 1 em sucesso, 0 se rejeitar |
| `void dismiss_brk()` | Devolve a heap inteira ao sistema, restaurando o topo inicial |

(`memory_print()` também está declarada no cabeçalho, mas **não** está
implementada em lugar nenhum do repositório.)

## Arquitetura, sintaxe e convenção de chamada

- **x86-64 (AMD64), Linux.** O código usa registradores de 64 bits (`%rax`,
  `%rdi`, `%r8`–`%r13`), `movq`/`cmpq` e a instrução `syscall`.
- **Sintaxe AT&T, montado pelo GNU as** (`as`), não NASM: as diretivas são
  `.section .data` / `.section .text`, `.global`, `.quad`, e o comentário é `#`.
- **Convenção System V AMD64**, a mesma do C do Linux: o argumento chega em
  `%rdi` e o valor de retorno sai em `%rax`. É por isso que o `main.c` consegue
  chamar `memory_alloc` como se fosse uma função C qualquer — só precisa declarar
  o protótipo e linkar o `.o`.
- **A ligação exige `-no-pie`.** O código endereça as variáveis globais de forma
  absoluta (`movq original_brk, %rax`), o que gera uma relocação `R_X86_64_32S`.
  Linkar como executável independente de posição falha com
  `relocation R_X86_64_32S against symbol 'original_brk' can not be used when
  making a PIE object`. Daí o `-no-pie` nos makefiles: não é enfeite, é requisito.

## Como a memória é obtida do sistema

Pela syscall **`brk`, número 12** — o mecanismo mais antigo e mais simples do
Linux para crescer a heap: um único ponteiro, o "topo do programa", que se
empurra para cima.

```asm
setup_brk:
    movq $12, %rax      # syscall brk
    movq $0, %rdi       # brk(0) devolve o topo atual, sem mexer nele
    syscall
    movq %rax, original_brk
    movq %rax, current_brk
```

Chamar `brk(0)` é o truque de sempre: o kernel não tem como crescer para o
endereço 0, então devolve o topo corrente. Esse valor é o **endereço-base da
heap** — o começo do primeiro bloco — e fica guardado em `original_brk`, que é
`.global` justamente para o teste em C poder conferir onde a primeira alocação
caiu.

Crescer é a mesma syscall com o novo topo:

```asm
arruma_ponteiro_heap:
    movq current_brk, %rdi
    addq %r8, %rdi              # + tamanho pedido
    addq $16, %rdi              # + cabeçalho
    movq $12, %rax
    syscall
```

Ou seja: **a heap cresce exatamente o que a alocação precisa**, sem folga, sem
arredondar para página, sem pool. Cada alocação que não encontra bloco livre é
uma syscall. Um `malloc` de verdade faz o oposto — pede grandes pedaços de uma
vez, com `mmap`, e serve muitas alocações de cada pedaço.

`dismiss_brk` desfaz tudo de uma vez, chamando `brk(original_brk)`: a heap
inteira volta ao sistema. É o único caminho pelo qual este alocador devolve
memória — `memory_free` nunca encolhe a heap.

## A estrutura do heap: cabeçalho de 16 bytes e lista implícita

Não há lista encadeada de blocos livres, nem árvore, nem bitmap separado. A
estrutura é a mais econômica possível: **cada bloco carrega, imediatamente antes
da área devolvida, um cabeçalho de 16 bytes** com dois inteiros de 64 bits.

```
   início do bloco
   |
   v
   +-----------------+-----------------+------------------------------+
   | ocupado (8 B)   | tamanho (8 B)   | área devolvida ao chamador   |
   +-----------------+-----------------+------------------------------+
                                       ^
                                       ponteiro devolvido = início + 16
```

- `ocupado` (deslocamento 0): `1` se o bloco está em uso, `0` se está livre.
- `tamanho` (deslocamento 8): quantos bytes tem a área útil, sem o cabeçalho.

Com isso, a lista de blocos é **implícita**: não existe campo "próximo". O
próximo bloco começa em `endereço_atual + 16 + tamanho`, e é assim que a varredura
anda:

```asm
bloco_ocupado:
    movq 8(%rax), %r11      # r11 = tamanho do bloco
    addq %r11, %rax
    addq $16, %rax          # rax = próximo cabeçalho
    jmp busca_livre
```

A varredura termina quando o ponteiro alcança `current_brk` — o topo. Essa
comparação é o que impede a leitura de memória não mapeada; o comentário no
código diz isso com todas as letras ("se a posição da qual deseja ver o valor
passar de `current_brk` dá segfault").

Consequência mensurável: pedir 100 bytes e depois 130 coloca o segundo cabeçalho
**116 bytes** depois do primeiro (100 de área + 16 de cabeçalho). O programa de
teste confere exatamente esse número.

### Alinhamento — o que o código faz e o que não faz

**O tamanho pedido não é arredondado.** O bloco seguinte começa onde o anterior
termina, byte a byte. O primeiro ponteiro saiu alinhado a 16 bytes em todas as
execuções observadas — o topo inicial da heap já vem assim do kernel —, mas do
segundo em diante o alinhamento passa a depender do que foi pedido: com um
primeiro pedido de 100 bytes, o segundo ponteiro sai em `...084`, **desalinhado
a 8 bytes**. Um alocador de produção arredondaria toda requisição para um
múltiplo de 16 antes de qualquer outra coisa; este não arredonda, e é uma das lacunas conscientes da lista de
limitações lá embaixo.

## A decisão difícil: qual bloco livre escolher

É aqui que o trabalho fica interessante, e é a razão de existirem dois
diretórios. As duas versões têm o mesmo cabeçalho, a mesma varredura, a mesma
divisão de blocos e o mesmo `memory_free`. **A única diferença é a política de
escolha** — e ela muda para onde os ponteiros apontam.

### `Original/` — first-fit

A varredura pára no **primeiro** bloco livre que couber. Achou livre, pula
direto para o código que aloca:

```asm
    cmpq $0, (%rax)     # ocupado == 0 ?
    je bloco_livre      # first-fit: usa este e acabou
```

Simples e barato: no melhor caso não percorre a heap inteira. Em compensação
espalha as sobras pequenas pelo começo da heap.

### `Modificado/` — worst-fit

A varredura **não pára**: percorre a heap inteira guardando o maior bloco livre
encontrado (`%r13` = maior tamanho visto, `%rdx` = endereço dele) e só decide no
fim.

```asm
    verifica_endereco:
        movq 8(%rax), %r10      # tamanho deste bloco livre
        cmpq %r13, %r10
        jle bloco_ocupado       # não é maior que o campeão: segue andando
        movq %r10, %r13         # novo campeão
        movq %rax, %rdx
        jmp bloco_ocupado

    worst_fit:                  # chegou ao topo da heap
        movq original_brk, %rbx
        cmpq %rbx, current_brk
        je arruma_ponteiro_heap # heap vazia: cresce
        cmpq $0, %r13
        je arruma_ponteiro_heap # nenhum bloco livre: cresce
        movq %rdx, %rax         # usa o MAIOR bloco livre
        jmp bloco_livre
```

A ideia do worst-fit é que a sobra de um bloco grande ainda é utilizável, ao
contrário da sobra de um bloco justo. O custo é o oposto do first-fit: **toda**
alocação percorre a heap inteira.

A diferença é visível no teste. Depois de alocar 100 e 130 bytes e liberar os
dois, um pedido de 24 bytes:

- em **first-fit** cairia no bloco de 100 (o primeiro);
- em **worst-fit** cai no bloco de 130 (o maior) — e é isso que o
  `Modificado/main.c` verifica, comparando o ponteiro novo com o antigo `pnt_2`.

## Quando o bloco é dividido, e quando não é

Achado o bloco, o alocador decide entre dividir e não dividir por um limiar:

```asm
    subq %r8, %r12          # sobra = tamanho_do_bloco - tamanho_pedido
    cmpq $0, %r12
    jl bloco_ocupado        # não cabe: continua procurando
    cmpq $24, %r12
    jl formata_bloco_completo   # sobra < 24: entrega o bloco inteiro
```

O limiar de **24 bytes** é o mínimo aritmético que faz sentido: 16 bytes de
cabeçalho mais pelo menos 8 de área útil. Abaixo disso, dividir criaria um bloco
que ninguém consegue usar e ainda gastaria cabeçalho.

- **Sobra ≥ 24** → divide. Escreve um cabeçalho novo logo depois da área alocada,
  com `ocupado = 0` e `tamanho = sobra - 16`, e o bloco pedido fica com o tamanho
  exato da requisição.
- **Sobra < 24** → não divide. O bloco é entregue inteiro e seu campo `tamanho`
  continua sendo o original — o pedido de 90 bytes num bloco de 100 devolve um
  bloco que continua dizendo "100". É fragmentação interna, assumida.

## `memory_free`

É a rotina mais curta do arquivo, e a assimetria é proposital: liberar é só
apagar um bit.

```asm
memory_free:
    movq %rdi, %r10
    cmpq current_brk, %r10
    jg invalido             # ponteiro acima do topo da heap: recusa
    subq $16, %r10          # volta ao cabeçalho
    movq $0, (%r10)         # ocupado = 0
    movq $1, %rax           # sucesso
```

Duas coisas que valem ser ditas em voz alta:

1. **Não há coalescência.** Dois blocos livres vizinhos continuam sendo dois
   blocos livres. A heap só se desfragmenta quando o `dismiss_brk` derruba tudo.
2. **A única validação é o limite superior.** Um ponteiro acima de `current_brk`
   é recusado (é assim que a bateria de testes original consegue "liberar a
   pilha" e receber 0 de volta, já que a pilha fica em endereços muito mais
   altos). Não existe validação do limite inferior — ver as limitações.

## Como compilar e rodar

Precisa de `gcc`, `as` (binutils) e `make`, em Linux x86-64. Não há dependência
nenhuma além disso.

```bash
# a versão first-fit
cd Original && make clean && make && ./main

# a versão worst-fit
cd Modificado && make clean && make && ./main
```

O `make clean` no começo não é frescura: os `.o` e os executáveis estão
versionados junto com o fonte, e sem limpar o `make` pode achar que já está tudo
pronto e apenas relinkar os objetos antigos.

A saída é a bateria de testes que acompanha cada versão — uma linha `CORRETO!`
ou `INCORRETO!` por propriedade verificada: onde o ponteiro caiu, o indicador de
uso, o tamanho gravado no cabeçalho e a distância entre alocações consecutivas.
Verificado em setembro de 2026 com gcc 15.2 e binutils 2.46: **as duas versões
montam sem aviso e passam em todas as verificações dos seus testes.**

```
============================== ROTINAS DE TESTE ==============================
==>> ALOCANDO UM ESPAÇO DE 100 BYTES:
	LOCAL: CORRETO!
	IND. DE USO: CORRETO!
	TAMANHO: CORRETO!
...
```

Cada versão tem o seu próprio `main.c`, com expectativas diferentes — e é essa
divergência que demonstra a troca de política. Montar o teste do first-fit contra
o alocador worst-fit passa nas primeiras verificações e diverge exatamente onde
deveria: no pedido de 60 bytes, que o first-fit coloca no fragmento de 64 e o
worst-fit coloca no bloco de 120 (`LOCAL: INCORRETO!`). Logo depois, o pedido de
150 bytes trava — é o laço infinito descrito nas limitações.

## Limitações conhecidas

Um alocador didático tem muitas, e listá-las é parte de entender o problema.
Todas as abaixo foram verificadas lendo ou executando o código deste
repositório.

- **Não é thread-safe.** `original_brk` e `current_brk` são duas variáveis
  globais em `.data`, manipuladas sem nenhum tipo de trava. Duas threads
  alocando ao mesmo tempo corrompem a heap.
- **Não convive com o `malloc` da libc.** A libc também administra a sua heap
  principal empurrando o `brk`. Um programa que use `printf` e este alocador ao
  mesmo tempo tem dois donos para o mesmo ponteiro de topo. Os testes funcionam,
  mas isso é conveniência do caso pequeno, não garantia.
- **`memory_free` não valida o limite inferior.** Só ponteiros *acima* de
  `current_brk` são recusados. Um endereço abaixo da heap — uma variável global,
  por exemplo — passa pela validação, tem `1` devolvido como se fosse sucesso, e
  faz o alocador escrever zero 16 bytes antes dele. Confirmado
  experimentalmente: liberar o endereço de um vetor global devolve 1 e zera a
  memória vizinha.
- **Sem coalescência de blocos livres adjacentes.** Liberar dois blocos vizinhos
  de 100 bytes não produz um bloco de 216; produz dois de 100, e um pedido de
  150 não é atendido por nenhum deles.
- **A memória nunca volta ao sistema, exceto tudo de uma vez.** `memory_free` só
  apaga o bit de uso. Só `dismiss_brk` chama `brk` para baixo.
- **Sem alinhamento garantido** a partir da segunda alocação, porque o tamanho
  pedido não é arredondado (detalhado acima).
- **A falha da syscall não é tratada.** O retorno do `brk` em `%rax` é ignorado —
  o código grava em `current_brk` o valor que *pediu*, não o que o kernel
  *devolveu*. `memory_alloc` nunca devolve `NULL`: se a heap não puder crescer, o
  ponteiro entregue aponta para memória que não existe.
- **A versão worst-fit entra em laço infinito** quando existe pelo menos um
  bloco livre e nenhum deles é grande o bastante. O `worst_fit` escolhe o maior
  bloco livre sem verificar se o pedido cabe nele; o `bloco_livre` percebe que
  não cabe e volta a varrer; a varredura chega de novo ao fim, `%r13` continua
  apontando para o mesmo campeão, e o ciclo se fecha — em vez de crescer a heap,
  que é o que deveria acontecer. Confirmado por execução (o programa trava). A
  versão first-fit **não** tem esse problema: ela nunca revisita um bloco.
- **Não existem `realloc` nem `calloc`**, e `memory_print`, apesar de declarada
  no `memalloc.h`, não está implementada. A interface é deliberadamente a mínima
  do enunciado.
- **Convenção de chamada respeitada só pela metade.** `memory_alloc` escreve em
  `%rbx`, `%r12` e `%r13` sem salvá-los, e a System V AMD64 exige que esses três
  sejam preservados pela função chamada. Nos testes não dá problema porque o
  chamador não tinha nada vivo neles, mas é uma violação do ABI: com outro
  compilador, outro nível de otimização ou outro chamador, dá.
- **`memalloc.s` na raiz do repositório não monta.** É o rascunho inicial,
  congelado em 18/11/2023, com um trecho comentado usando `@` — que não é
  caractere de comentário na sintaxe AT&T. `make` na raiz falha com
  `junk at end of line, first unrecognized character is '@'`. O código que
  funciona é o dos diretórios `Original/` e `Modificado/`. (Esse rascunho guarda
  um detalhe divertido do processo: ele ainda lia o argumento da pilha, em
  `16(%rbp)`, antes de a dupla passar para o `%rdi` da convenção correta.)
- **Dívidas menores:** o alvo `purge` dos makefiles não funciona (`clean` está
  escrito como comando de shell, não como dependência), o rótulo `aux`, que
  chama `exit`, é código morto nas duas versões, e os binários compilados
  (`main`, `*.o`) estão versionados junto com o fonte.

## Estrutura do repositório

O repositório guarda as duas versões lado a lado, que é o formato em que o
trabalho foi entregue.

```
.
├── Original/            versão FIRST-FIT (a entrega base)
│   ├── memalloc.s       o alocador — 150 linhas de assembly
│   ├── memalloc.h       a interface consumida pelo C
│   ├── main.c           bateria de testes com expectativas de first-fit
│   └── makefile
├── Modificado/          versão WORST-FIT (a modificação pedida)
│   ├── memalloc.s       176 linhas: mesma base + a varredura completa
│   ├── memalloc.h
│   ├── main.c           bateria de testes com expectativas de worst-fit
│   └── makefile
├── alocacaoFeita/       diretório de trabalho da dupla; o conteúdo final é
│                        byte a byte igual ao de Original/
├── memalloc.s           rascunho inicial — NÃO monta (ver limitações)
├── teste.c              bateria de testes mais antiga, com um caso a mais:
│                        liberar um endereço da pilha e exigir recusa
└── makefile             o makefile do rascunho
```

Feito em dupla, em novembro de 2023, com
[@LeonardooBecker](https://github.com/LeonardooBecker).
