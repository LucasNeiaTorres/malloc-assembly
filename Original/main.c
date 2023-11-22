#include <stdio.h>
#include <stdlib.h>

#include "memalloc.h" 							

extern void *original_brk;	/* Você precisa ter a variável global que armazena o valor de brk como um extern aqui.
							No código de teste estou chamandando de original_brk, mas se utilizarem outro nome,
							substituir as ocorrências por ele aqui. */

int main() { 

	printf("============================== ROTINAS DE TESTE ==============================\n");
	
	setup_brk();
	void *initial_brk = original_brk;
	void *pnt_1, *pnt_2, *pnt_3, *pnt_4, *pnt_5, *pnt_6, *pnt_7;

	pnt_1 = memory_alloc(100);
	printf("==>> ALOCANDO UM ESPAÇO DE 100 BYTES:\n");
	printf("\tLOCAL: %s\n", pnt_1-16 == initial_brk ? "CORRETO!" : "INCORRETO!");
	printf("\tIND. DE USO: %s\n", *((long long*) (pnt_1-16)) == 1 ? "CORRETO!" : "INCORRETO!");
	printf("\tTAMANHO: %s\n", *((long long*) (pnt_1-8)) == 100 ? "CORRETO!" : "INCORRETO!");

	pnt_2 = memory_alloc(130);
	printf("==>> ALOCANDO UM ESPAÇO DE 130 BYTES:\n");
	printf("\tLOCAL: %s\n", pnt_2-16 == initial_brk + 116 ? "CORRETO!" : "INCORRETO!");
	printf("\tIND. DE USO: %s\n", *((long long*) (pnt_2-16)) == 1 ? "CORRETO!" : "INCORRETO!");
	printf("\tTAMANHO: %s\n", *((long long*) (pnt_2-8)) == 130 ? "CORRETO!" : "INCORRETO!");
	printf("\tREL. PRIMEIRA ALOCAÇÃO: %s\n", (long long) (pnt_2-pnt_1) == 116 ? "CORRETO!" : "INCORRETO!");

	pnt_3 = memory_alloc(110);
	printf("==>> ALOCANDO UM ESPAÇO DE 110 BYTES:\n");
	printf("\tLOCAL: %s\n", pnt_3-16 == initial_brk + 262 ? "CORRETO!" : "INCORRETO!");
	printf("\tIND. DE USO: %s\n", *((long long*) (pnt_3-16)) == 1 ? "CORRETO!" : "INCORRETO!");
	printf("\tTAMANHO: %s\n", *((long long*) (pnt_3-8)) == 110 ? "CORRETO!" : "INCORRETO!");
	printf("\tREL. SEGUNDA ALOCAÇÃO: %s\n", (long long) (pnt_3-pnt_2) == 146 ? "CORRETO!" : "INCORRETO!");

	pnt_4 = memory_alloc(120);
	printf("==>> ALOCANDO UM ESPAÇO DE 120 BYTES:\n");
	printf("\tLOCAL: %s\n", pnt_4-16 == initial_brk + 388 ? "CORRETO!" : "INCORRETO!");
	printf("\tIND. DE USO: %s\n", *((long long*) (pnt_4-16)) == 1 ? "CORRETO!" : "INCORRETO!");
	printf("\tTAMANHO: %s\n", *((long long*) (pnt_4-8)) == 120 ? "CORRETO!" : "INCORRETO!");
	printf("\tREL. TERCEIRA ALOCAÇÃO: %s\n", (long long) (pnt_4-pnt_3) == 126 ? "CORRETO!" : "INCORRETO!");

	printf("==>> DESALOCANDO UM ESPAÇO DE 130 BYTES:\n");
	memory_free(pnt_2);
	printf("\tIND. DE USO: %s\n", *((long long*) (pnt_2-16)) == 0 ? "CORRETO!" : "INCORRETO!");
	printf("\tTAMANHO: %s\n", *((long long*) (pnt_2-8)) == 130 ? "CORRETO!" : "INCORRETO!");

	printf("==>> DESALOCANDO UM ESPAÇO DE 120 BYTES:\n");
	memory_free(pnt_4);
	printf("\tIND. DE USO: %s\n", *((long long*) (pnt_4-16)) == 0 ? "CORRETO!" : "INCORRETO!");
	printf("\tTAMANHO: %s\n", *((long long*) (pnt_4-8)) == 120 ? "CORRETO!" : "INCORRETO!");

	pnt_5 = memory_alloc(50);
	printf("==>> ALOCANDO UM ESPAÇO DE 50 BYTES:\n");
	printf("\tLOCAL: %s\n", pnt_5 == pnt_2 ? "CORRETO!" : "INCORRETO!");
	printf("\tIND. DE USO: %s\n", *((long long*) (pnt_5-16)) == 1 ? "CORRETO!" : "INCORRETO!");
	printf("\tTAMANHO: %s\n", *((long long*) (pnt_5-8)) == 50 ? "CORRETO!" : "INCORRETO!");
	
	pnt_6 = memory_alloc(60);
	printf("==>> ALOCANDO UM ESPAÇO DE 60 BYTES:\n");
	printf("\tLOCAL: %s\n", pnt_6 == pnt_5+66 ? "CORRETO!" : "INCORRETO!");
	printf("\tIND. DE USO: %s\n", *((long long*) (pnt_6-16)) == 1 ? "CORRETO!" : "INCORRETO!");
	printf("\tTAMANHO: %s\n", *((long long*) (pnt_6-8)) == 64 ? "CORRETO!" : "INCORRETO!");

	pnt_7 = memory_alloc(150);
	printf("==>> ALOCANDO UM ESPAÇO DE 150 BYTES:\n");
	printf("\tLOCAL: %s\n", pnt_7 == pnt_4+136 ? "CORRETO!" : "INCORRETO!");
	printf("\tIND. DE USO: %s\n", *((long long*) (pnt_7-16)) == 1 ? "CORRETO!" : "INCORRETO!");
	printf("\tTAMANHO: %s\n", *((long long*) (pnt_7-8)) == 150 ? "CORRETO!" : "INCORRETO!");

	printf("==>> DESALOCANDO TUDO:\n");
	memory_free(pnt_1);
	memory_free(pnt_3);
	memory_free(pnt_5);
	memory_free(pnt_6);
	memory_free(pnt_7);
	printf("\tIND. DE USO: %s\n", *((long long*) (pnt_1-16)) == 0 ? "CORRETO!" : "INCORRETO!");
	printf("\tTAMANHO: %s\n", *((long long*) (pnt_1-8)) == 100 ? "CORRETO!" : "INCORRETO!");
	printf("\tIND. DE USO: %s\n", *((long long*) (pnt_3-16)) == 0 ? "CORRETO!" : "INCORRETO!");
	printf("\tTAMANHO: %s\n", *((long long*) (pnt_3-8)) == 110 ? "CORRETO!" : "INCORRETO!");
	printf("\tIND. DE USO: %s\n", *((long long*) (pnt_5-16)) == 0 ? "CORRETO!" : "INCORRETO!");
	printf("\tTAMANHO: %s\n", *((long long*) (pnt_5-8)) == 50 ? "CORRETO!" : "INCORRETO!");
	printf("\tIND. DE USO: %s\n", *((long long*) (pnt_6-16)) == 0 ? "CORRETO!" : "INCORRETO!");
	printf("\tTAMANHO: %s\n", *((long long*) (pnt_6-8)) == 64 ? "CORRETO!" : "INCORRETO!");
	printf("\tIND. DE USO: %s\n", *((long long*) (pnt_7-16)) == 0 ? "CORRETO!" : "INCORRETO!");
	printf("\tTAMANHO: %s\n", *((long long*) (pnt_7-8)) == 150 ? "CORRETO!" : "INCORRETO!");

	return 0;
}
