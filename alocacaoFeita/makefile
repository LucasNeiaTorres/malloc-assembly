flags = -g -Wall -no-pie
PROG = malloc

all: $(PROG)

$(PROG): teste.o memalloc.o
	gcc $(flags) -o $(PROG) teste.o memalloc.o

teste.o: teste.c
	gcc $(flags) -c teste.c -o teste.o

memalloc.o: memalloc.h memalloc.s
	as $(flags) memalloc.s -o memalloc.o

clean:
	rm -rf *.o $(PROG)