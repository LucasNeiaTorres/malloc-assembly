# as memalloc.s -o memalloc.o
# ld memalloc.o -o memalloc
# ./memalloc
# echo $?

gcc -Wall teste.c -o teste memalloc.s -no-pie
./teste
echo $?