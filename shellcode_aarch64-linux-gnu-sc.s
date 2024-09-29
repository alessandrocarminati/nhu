.section .text
.global inject

inject:
	// Step 1: Close FD 1 and create /tmp/stdio_red
	mov x0, 1
	mov x8, 57                             // syscall number for close (57)
	svc 0

	// Create /tmp/stdio_red
	ldr x0, =filename_stdout
	mov x1, 0x41                           // x1 = O_CREAT | O_WRONLY (0x41)
	mov x2, 0x1A4                          // x2 = 0666 (octal)
	mov x8, 56                             // syscall number for openat (56)
	svc 0

	cmp x0, 1
	b.ne exit

	// Step 2: Close FD 2 and create /tmp/sterr_red
	mov x0, 2                              // x0 = 2 (file descriptor stderr)
	mov x8, 57                             // syscall number for close (57)
	svc 0

	// Create /tmp/sterr_red
	ldr x0, =filename_stderr
	mov x1, 0x41                           // x1 = O_CREAT | O_WRONLY (0x41)
	mov x2, 0x1A4                          // x2 = 0666 (octal)
	mov x8, 56                             // syscall number for openat (56)
	svc 0

	cmp x0, 2
	b.ne exit

	// Step 3: Close FD 0 and open /dev/null
	mov x0, 0
	mov x8, 57
	svc 0

	// Open /dev/null
	ldr x0, =filename_null
	mov x1, 0                              // x1 = O_RDONLY (0)
	mov x8, 56                             // syscall number for openat (56)
	svc 0

	cmp x0, 0
	b.ne exit

	// Step 4: Redirect SIGHUP to no action
	mov x0, 1                              // x0 = SIGHUP (signal number)
	mov x1, 0                              // x1 = NULL (no handler)
	mov x2, 0                              // x2 = NULL (no old action)
	mov x8, 134                            // syscall number for rt_sigaction (134)
	svc 0

	brk #0

.section .data
filename_stdout:   .asciz "/tmp/stdio_red"     // Filename for stdout redirection
filename_stderr:   .asciz "/tmp/sterr_red"     // Filename for stderr redirection
filename_null:     .asciz "/dev/null"          // Filename for /dev/null

exit:
	# Exit with status code 1
	mov x0, 1                              // x0 = exit code 1
	mov x8, 93                             // syscall number for exit (93)
	svc 0                                  // exit(1)
