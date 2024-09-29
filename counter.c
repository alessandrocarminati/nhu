#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>  // For sleep()

int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Usage: %s <number>\n", argv[0]);
        return 1;
    }

    int limit = atoi(argv[1]);  // Convert the command line argument to an integer

    if (limit <= 0) {
        printf("Please provide a positive integer.\n");
        return 1;
    }

    for (int i = 1; i <= limit; i++) {
        printf("%d\n", i);  // Print the current counter
        sleep(1);           // Sleep for 1 second
    }

    return 0;
}
