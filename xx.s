.intel_syntax noprefix

.section .data
    # Define the sigaction structure for ignoring SIGHUP
    act_sigaction:
        .quad 1             # sa_handler = SIG_IGN (1)
        .long 0x04000000    # sa_flags = 0x04000000
        .long 0x00000000    # pad
        .quad 0xdeadbeef  # sa_restorer = 0 (not used)
        .quad 0             # sa_mask = 0 (empty signal mask)

.section .text
    .global _start

restore_stub:
    mov rax, 15             # syscall number for rt_sigreturn
    syscall                 # invoke the system call

_start:
    # Set up parameters for the sigaction syscall
    # syscall number for sigaction = 13
    # rdi = SIGHUP (1)
    # rsi = pointer to the sigaction structure
    # rdx = NULL (we don't need to capture the old action)
    
    mov rax, 13            # syscall number for sigaction
    mov edi, 1             # SIGHUP signal number (1)
    lea rsi, [act_sigaction + rip] # pointer to the sigaction struct
    xor rdx, rdx           # NULL for the old action (rdx = 0)
    mov r10, 8
    syscall                # invoke the syscall

    mov rdi, rax
    #Exit the program with syscall exit(0)
    mov eax, 60            # syscall number for exit
    syscall                # invoke the syscall
