#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/signal.h>
#include <fcntl.h>
#include <sys/prctl.h>
#include <string.h>
#include <errno.h>

// Function to redirect stdout, stderr and stdin
void redirect_io(const char *stdout_file, const char *stderr_file) {
    // Open the files for redirection
    int out_fd = open(stdout_file, O_WRONLY | O_CREAT | O_APPEND, 0644);
    int err_fd = open(stderr_file, O_WRONLY | O_CREAT | O_APPEND, 0644);
    
    if (out_fd == -1 || err_fd == -1) {
        perror("Failed to open files for redirection");
        exit(EXIT_FAILURE);
    }

    // Redirect stdout
    if (dup2(out_fd, STDOUT_FILENO) == -1) {
        perror("Failed to redirect stdout");
        exit(EXIT_FAILURE);
    }
    
    // Redirect stderr
    if (dup2(err_fd, STDERR_FILENO) == -1) {
        perror("Failed to redirect stderr");
        exit(EXIT_FAILURE);
    }

    // Redirect stdin to /dev/null
    int null_fd = open("/dev/null", O_RDONLY);
    if (dup2(null_fd, STDIN_FILENO) == -1) {
        perror("Failed to redirect stdin to /dev/null");
        exit(EXIT_FAILURE);
    }

    close(out_fd);
    close(err_fd);
    close(null_fd);
}

// Function to prevent SIGHUP (detach from the terminal)
void prevent_sighup() {
    if (prctl(PR_SET_PDEATHSIG, 0) == -1) {
        perror("Failed to set PR_SET_PDEATHSIG");
        exit(EXIT_FAILURE);
    }
    
    // Create a new session and detach from terminal
    if (setsid() == -1) {
        perror("Failed to create new session (detach from terminal)");
        exit(EXIT_FAILURE);
    }
}

// Use ptrace to attach to the target process and its children
void attach_and_redirect(pid_t pid, const char *stdout_file, const char *stderr_file) {
    // Attach to the target process
    if (ptrace(PTRACE_ATTACH, pid, NULL, NULL) == -1) {
        perror("Failed to ptrace attach");
        exit(EXIT_FAILURE);
    }

    // Wait for the target process to stop
    int status;
    waitpid(pid, &status, 0);

    // Redirect I/O for the process
    redirect_io(stdout_file, stderr_file);

    // Detach the process once done
    if (ptrace(PTRACE_DETACH, pid, NULL, NULL) == -1) {
        perror("Failed to ptrace detach");
        exit(EXIT_FAILURE);
    }

    printf("Successfully redirected stdout, stderr, and prevented SIGHUP for PID: %d\n", pid);
}

int main(int argc, char *argv[]) {
    if (argc < 4) {
        fprintf(stderr, "Usage: %s <pid> <stdout_file> <stderr_file>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    pid_t pid = atoi(argv[1]);
    const char *stdout_file = argv[2];
    const char *stderr_file = argv[3];

    // Detach from terminal to prevent SIGHUP
    prevent_sighup();

    // Attach to the process and redirect IO
    attach_and_redirect(pid, stdout_file, stderr_file);

    return 0;
}
