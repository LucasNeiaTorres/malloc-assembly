#ifndef _MEMALLOC_H
#define _MEMALLOC_H

extern void *original_brk;

void setup_brk();

void dismiss_brk(); 

void* memory_alloc(unsigned long int bytes);

int memory_free(void *pointer);

void memory_print();

#endif