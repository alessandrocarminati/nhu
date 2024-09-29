#include <stdio.h>
#include <stdlib.h>
#include <sys/ptrace.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/user.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/uio.h>
#include <fcntl.h>
#include "shellcode.h"


void printregs(struct user_regs_struct *r){
	printf("r15 = %08llx\n", r->r15);
	printf("r14 = %08llx\n", r->r14);
	printf("r13 = %08llx\n", r->r13);
	printf("r12 = %08llx\n", r->r12);
	printf("bp = %08llx\n", r->rbp);
	printf("bx = %08llx\n", r->rbx);
	printf("r11 = %08llx\n", r->r11);
	printf("r10 = %08llx\n", r->r10);
	printf("r9 = %08llx\n", r->r9);
	printf("r8 = %08llx\n", r->r8);
	printf("ax = %08llx\n", r->rax);
	printf("cx = %08llx\n", r->rcx);
	printf("dx = %08llx\n", r->rdx);
	printf("si = %08llx\n", r->rsi);
	printf("di = %08llx\n", r->rdi);
	printf("orig_ax = %08llx\n", r->orig_rax);
	printf("ip = %08llx\n", r->rip);
	printf("cs = %08llx\n", r->cs);
	printf("flags = %08llx\n", r->eflags);
	printf("sp = %08llx\n", r->rsp);
	printf("ss = %08llx\n", r->ss);
	printf("fs_base = %08llx\n", r->fs_base);
	printf("gs_base = %08llx\n", r->gs_base);
	printf("ds = %08llx\n", r->ds);
	printf("es = %08llx\n", r->es);
	printf("fs = %08llx\n", r->fs);
	printf("gs = %08llx\n", r->gs);
	printf("-----------------------\n");
}

int inject_function(pid_t target_pid, void *function, size_t func_size) {
	struct user_regs_struct old_regs, new_regs;
	long *saved_data;
	long data;

	printf("attaching %d\n", target_pid);
	if (ptrace(PTRACE_ATTACH, target_pid, NULL, NULL) == -1) {
		perror("ptrace attach failed");
		return -1;
	}
	printf("attached to %d, waiting to get control\n", target_pid);
	waitpid(target_pid, NULL, 0);

	printf("Fetching state....\n");
	if (ptrace(PTRACE_GETREGS, target_pid, NULL, &old_regs) == -1) {
		perror("ptrace getregs failed");
		ptrace(PTRACE_DETACH, target_pid, NULL, NULL);
		return -1;
	}
	printregs(&old_regs);

	printf("allocate data for backup....\n");
	saved_data = malloc(func_size);
	if (!saved_data) {
		perror("no mem for saved data\n");
		ptrace(PTRACE_DETACH, target_pid, NULL, NULL);
		return -1;
	}

	printf("Backingup and rewriting text (0x%08llx)-> ", old_regs.rip);
	for (size_t i = 0; i < func_size; i += sizeof(long)) {
		errno = 0;
		data = ptrace(PTRACE_PEEKTEXT, target_pid, old_regs.rip + i, NULL);
		if (data == -1 && errno != 0) {
			perror("ptrace peektext failed");
			ptrace(PTRACE_DETACH, target_pid, NULL, NULL);
			return -1;
		}
		*(saved_data + i) = data;
		printf("0x%08lx =>", data);
		data = *(long *)((char *)function + i);
		if (ptrace(PTRACE_POKETEXT, target_pid, old_regs.rip + i, data) == -1) {
			perror("ptrace poketext failed");
			ptrace(PTRACE_DETACH, target_pid, NULL, NULL);
			return -1;
		}
		printf(" 0x%08lx, ", data);
	}
	printf("\n");

	printf("saved date....\n");
	for (size_t i = 0; i < func_size; i += sizeof(long)) {
		printf("0x%08lx, ", *(saved_data + i));
	}
	printf("\n");

	printf("executing the redirection....\n");
	if (ptrace(PTRACE_CONT, target_pid, NULL, NULL) == -1) {
		perror("ptrace continue failed");
		ptrace(PTRACE_DETACH, target_pid, NULL, NULL);
		return -1;
	}
	printf("Waiting to regaign control....\n");
	waitpid(target_pid, NULL, 0);

	printf("restore old text....\n");
	for (size_t i = 0; i < func_size; i += sizeof(long)) {
		data = *(saved_data + i);
		if (ptrace(PTRACE_POKETEXT, target_pid, old_regs.rip + i, data) == -1) {
			perror("ptrace poketext failed");
			ptrace(PTRACE_DETACH, target_pid, NULL, NULL);
			return -1;
		}
	}

	printregs(&old_regs);

	printf("restore regs....\n");
	if (ptrace(PTRACE_SETREGS, target_pid, NULL, &old_regs) == -1) {
		perror("ptrace restore registers failed");
		ptrace(PTRACE_DETACH, target_pid, NULL, NULL);
		return -1;
	}

	printf("Fetching state....\n");
	if (ptrace(PTRACE_GETREGS, target_pid, NULL, &old_regs) == -1) {
		perror("ptrace getregs failed");
		ptrace(PTRACE_DETACH, target_pid, NULL, NULL);
		return -1;
	}
	printregs(&old_regs);

	printf("checking text at execution (0x%08llx)-> ", old_regs.rip);
	for (size_t i = 0; i < func_size; i += sizeof(long)) {
		errno = 0;
		data = ptrace(PTRACE_PEEKTEXT, target_pid, old_regs.rip + i, NULL);
		if (data == -1 && errno != 0) {
			perror("ptrace peektext failed");
			ptrace(PTRACE_DETACH, target_pid, NULL, NULL);
			return -1;
		}
		*(saved_data + i) = data;
		printf("0x%08lx, ", data);
	}
	printf("\n");

	printf("Continue....\n");
	if (ptrace(PTRACE_DETACH, target_pid, NULL, NULL) == -1) {
		perror("ptrace detach failed");
		return -1;
	}

	return 0;
}

int main(int argc, char *argv[]) {
	if (argc != 2) {
		fprintf(stderr, "Usage: %s <pid>\n", argv[0]);
		return 1;
	}

	pid_t target_pid = atoi(argv[1]);

	if (inject_function(target_pid, (void *)injected_code, INJECTED_CODE_SZ) != 0) {
		fprintf(stderr, "Failed to inject function\n");
		return 1;
	}

	return 0;
}
