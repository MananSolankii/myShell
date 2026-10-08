# myshell

A small command-line shell written in C. I built this while learning operating systems to understand what happens between typing a command and seeing its output.

The project focuses on the basics: reading a command, splitting its arguments, starting a child process, and waiting for it to finish.

## What it can do

- Run external programs such as `ls`, `pwd`, and `echo`.
- Pass arguments to those programs, for example `ls -l /tmp`.
- Find programs through `PATH`, using `execvp()`.
- Wait for the current command before showing the next prompt.
- Handle empty input and report errors when a program cannot be started.
- Close with `exit` or end-of-input (Ctrl+D on an empty line).

## Build and run

Use Linux or a Linux distribution inside WSL. You will need GCC. On Ubuntu, you can install it with:

```bash
sudo apt update
sudo apt install build-essential
```

From the project folder:

```bash
gcc -Wall -Wextra -g myshell.c -o myshell
./myshell
```

If your source file is named `myShell.c`, use that exact name in the compilation command. Linux filenames are case-sensitive.

An example session:

```text
myshell> echo hello
hello
myshell> /bin/echo learning processes in C
learning processes in C
myshell> exit
```

Commands such as `ls` and `echo` are existing programs on the system. This shell launches them; it does not implement them itself. `exit` is handled inside the shell.

## How it works

The main loop reads a line with `fgets()`. It removes the trailing newline and uses `strtok()` to split the input at spaces and tabs. The resulting argument array ends with a `NULL` pointer, as required by `execvp()`.

For an external command, `fork()` creates a child process. The child calls `execvp()` to replace itself with the requested program. The parent waits with `waitpid()` and then returns to the prompt. If execution fails, the child prints an error and exits.

One detail that helped me understand this: `fork()` creates a process, while `execvp()` changes the program running inside that process.

## Run the tests

Run these commands in your normal WSL terminal, outside `myshell`:

```bash
bash tests/test_shell.sh
```

The script finds `myshell.c` or `myShell.c`, compiles a temporary executable, and checks basic command execution, arguments, whitespace, empty input, invalid commands, and exiting. It removes its temporary files when it finishes. The script needs Bash, GCC, and the `timeout` command supplied by GNU coreutils on Ubuntu.

To test a source file with a different name or location:

```bash
bash tests/test_shell.sh src/main.c
```

These are basic regression tests. They do not prove correct signal handling, job control, or safety for every input.

## Current limitations

This version uses a simple whitespace-based parser. Quoted strings and escaped spaces are not supported, and quotes are not removed from arguments.

It also does not yet support:

- Changing directories with `cd`.
- Pipes (`|`) or input/output redirection (`<`, `>`, `>>`).
- Background commands (`&`) or job control.
- Shell variables, wildcard expansion, or command history.
- Proper interactive signal handling for Ctrl+C and Ctrl+Z.

The input buffer is 1024 bytes, so one `fgets()` call reads at most 1023 bytes plus the terminating null character. Longer lines are not handled properly yet. The argument array holds at most 63 tokens, including the command name; additional tokens are currently ignored. Handling these limits explicitly is a planned improvement.

## What I want to add next

First, better input validation and a `cd` built-in. After that, I want to add redirection and pipes, then work on signals and background jobs.

## Learning reference

[Operating Systems: Three Easy Pieces](https://pages.cs.wisc.edu/~remzi/OSTEP/), particularly the Process API chapter, helped connect the code to the underlying OS concepts.
