#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void injected_function() {
	volatile int a = 0;

	if (a) {
str:
		__asm__ volatile (
		    ".byte 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x66, 0x72, 0x6f, 0x6d, 0x20,"
		    "0x69, 0x6e, 0x6a, 0x65, 0x63, 0x74, 0x65, 0x64, 0x20, 0x66, 0x75, 0x6e,"
		    "0x63, 0x21, 0x0a, 0x00, 0x00"
		);
	}
str_end:
	write(1, (void *) &&str, (&&str_end - &&str) );
}


int main(){
	int i;
	for (i=0; i<5; i++) injected_function();
}