gcc -c teste.c -o teste.o
gcc -no-pie -fno-pie memalloc.o teste.o -o teste -Wall -g

