.intel_syntax noprefix

	.section .text
	.global inject

inject:
	# Step 0: debug message.
	mov rax, 1                              # syscall number for sys_write (1)
	mov rdi, 1                              # stdout (1)
	lea rsi, [debug_str  + rip]             # debug str
	mov rdx, 0x0e                           # len(debug_str)
	syscall

	# Step 1: Close FD 1 and create /tmp/stdio_red
	mov rax, 3                              # syscall number for sys_closw (3)
	mov rdi, 1                              # rdi = 1 (close stdout)
	syscall                                 # close(1)
	mov rbx, 0xe
	or rax, rax
	js exit

	mov rax, 2                              # syscall number for sys_open (2)
	lea rdi, [filename_stdout  + rip]       # filename of /tmp/stdio_red
	mov rsi, 66                             # O_CREAT | O_WRONLY (0x42)
	mov rdx, 0666                           # Mode 666
	syscall                                 # open("/tmp/stdio_red", O_CREAT|O_WRONLY, 0666)

	mov rbx,0x0f                            # errorcode stdout err
	cmp rax, 1                              # Check if file descriptor is 1
	jne exit                                # Exit if FD is not 1

	# Step 2: Close FD 2 and create /tmp/sterr_red
	mov rdi, 2                              # rdi = 2 (close stderr)
	mov rax, 3                              # syscall number for close (3)
	syscall                                 # close(2)
	mov rbx, 0x10
	or rax, rax
	js exit

	# Create /tmp/sterr_red
	mov rax, 2                              # syscall number for sys_open (2)
	lea rdi, [filename_stderr + rip]        # filename of /tmp/sterr_red
	mov rsi, 66                             # O_CREAT | O_WRONLY (0x42)
	mov rdx, 0666                           # Mode 666
	syscall                                 # open("/tmp/sterr_red", O_CREAT|O_WRONLY, 0666)

	mov rbx,0x11                            # errorcode stderr err
	cmp rax, 2                              # Check if file descriptor is 2
	jne exit                                # Exit if FD is not 2

	# Step 3: Close FD 0 and open /dev/null
	xor rdi, rdi                            # rdi = 0 (close stdin)
	mov rax, 3                              # syscall number for close (3)
	syscall                                 # close(0)
	mov rbx, 0x12
	or rax, rax
	js exit

	# Open /dev/null
	mov rax, 2                              # syscall number for sys_open (2)
	lea rdi, [filename_null + rip]          # filename of /dev/null
	xor rsi, rsi                            # O_RDONLY (0)
	syscall                                 # open("/dev/null", O_RDONLY)

	mov rbx,0x13                            # errorcode stin err
	cmp rax, 0                              # Check if file descriptor is 0
	jne exit                                # Exit if FD is not 0

	# Step 4: Redirect signals to no action
	mov rax, 13				# syscall number for sigaction (13)
	mov rdi, 1				# SIGHUP signal number (1)
	lea rsi, [act_sigaction + rip]		# sa_handler
	xor rdx, rdx				# old_action = NULL
	mov r10, 8
	syscall					# rt_sigaction(SIGHUP, act_sigaction, NULL)
	mov rbx, rax
	or rax, rax
	js exit

	int3					# x86_64 breakpoint
debug_str:
	.string "Redirecting...\n"
filename_stdout:
	.string "/tmp/stdout_red"
filename_stderr:
	.string "/tmp/stderr_red"
filename_null:
	.string "/dev/null"
act_sigaction:
        .quad 1             # sa_handler = SIG_IGN (1)
        .long 0x04000000    # sa_flags = 0x04000000
        .long 0x00000000    # pad
        .quad 0xdeadbeef    # sa_restorer = 0 (poisoned)
        .quad 0             # sa_mask = 0 (empty signal mask)
exit:
	# Exit with status code 1
	mov rax, 60                             # syscall number for exit (60)
	mov rdi, rbx                            # exitcode
	syscall
