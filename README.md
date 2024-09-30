# nhu - Nohup for Running Processes

## Introduction
Sometimes you run a long-lasting process on a remote machine...
For example, to compress a large file...
When suddenly you have an emergency: your wife is itching to shop.

At that point, you typically have a couple of options:
* Stop the job and restart it at a more convenient time.
* Keep your computer connected and go out shopping.

Surely, if you had known beforehand, you could have started
the job in a `screen` or `tmux` session, but usually things
didn’t go that way, and now you have to decide what to do.

If you have enough time, you can use your trusty `gdb` to sort
this problem out.
You can attach to the program, close `stderr` and `stdout`, and
then create new files to replace them.
You can use `sigaction` to disable `SIGHUP`, but that isn’t something
you can manage when shopping is calling...
You simply don’t have the time.

To address this, I developed a simple tool to automate the `gdb` 
process, and this is the result of that effort.



## How Does It Work?
This app mimics the steps you would take using `gdb`: 
it attaches to the process, executes a few commands within the 
process context, and then resumes its execution.

This breaks down into a few subproblems:
1. Attaching to the running process.
2. Executing commands in the process context.
3. Resuming execution.

The original intent was to write everything in C to ensure 
portability, but I encountered a few challenges:

* The injected code must not depend on libraries. The reason 
  is that the running code has already been dynamically linked 
  at the time of injection, and I can't guarantee that the 
  necessary function entry exists in the PLT. 
  And if it doesn’t exist, there’s little I can do.
* The injected code needs to be position-independent. C 
  compilers can generate this kind of code, but it doesn’t 
  provide full control over it.
* If the injected code requires data, the data must be embedded 
  within the code itself, meaning it needs to reside in the same 
  memory space. I managed to achieve this in C, but it comes with 
  limitations. `x.c` in this repository is an attempt to have 
  data embedded in the code.
* If I end up reimplementing code to make direct system calls 
  without using libraries, I have to account for hardware-specific 
  details, which defeats the purpose of using C over assembly.

For these reasons, after experimenting with embedding data in the 
code space via a PoC, I ultimately decided to implement the injected 
code directly in assembly.


  the code has been already dynamic linked at the injected code 
  execution time, and I can't be sure there's an entry in the PLT
  for the function I need, and btw, if none there's nothing I can do.
* The injected code needs to be position indipendent, c compilers can 
  produce this lind of code, but there's no full control on it.
* If data is needed, it needs to be injected with the code, so it 
  must lay on the code space. I've found a way to achieve this in C
  but it has some limitations.
* If I endup in reimplement code to call the syscalls directly
  wo use library, I need to deal with hardware specificies, nullifiying
  the advantage of using c in place of assambly.


### Attaching to the Running Process
This part is straightforward... 
Linux provides the `ptrace` syscall for this purpose.

### Executing Commands in the Process Context
Initially, I considered using `mmap` within the process context to 
allocate the necessary memory for the code. 
However, I couldn’t find a reliable way to do this other than executing 
code that calls `mmap` itself. Since executing code was necessary anyway, 
I chose a quick-and-dirty approach: 
I stop the running program, overwrite the instructions at the PC, and 
assume there is enough space to insert the `nohup` code.

The `nohup` code must end with a breakpoint instruction so that, once 
executed, control returns to the attaching application. 
Afterward, the original code is restored, and execution resumes from 
where it left off.

### Resuming Execution
Resuming the process is handled by the operating system.


## Code Structure
The `nhu.c` file handles all the core tasks: 
* attaching to the process, 
* overwriting instructions, 
* executing the injected code, 
* restoring the original state, 
* resuming execution, 
* and detaching. 
Additionally, there are architecture-specific assembly 
files that define the shellcode (injected code).

## Current State
This project is considered a PoC. 
At the time of writing, only the x86_64 implementation has 
been tested and verified to work with at least one target program. 
Future work will focus on adapting it for the aarch64 architecture.

## Sample Execution
Here’s a sample execution demonstrating what you can expect when 
running this app against a target PID. 
It’s particularly cool because it prints a lot of numbers.

```
$ sudo ./bin/nhu 1383018
attaching 1383018
attached to 1383018, waiting to get control
Fetching state....
r15 = 00000000
r14 = 00000000
r13 = 7fff339d9b10
r12 = 7fff339d9b10
bp = 00000000
bx = ffffffffffffff01
r11 = 00000246
r10 = 7fff339d9b10
r9 = 00000003
r8 = 00000000
ax = fffffffffffffdfc
cx = 7fdc6804b1b4
dx = 7fff339d9b10
si = 00000000
di = 00000000
orig_ax = 000000e6
ip = 7fdc6804b1b4
cs = 00000033
flags = 00000246
sp = 7fff339d9a90
ss = 0000002b
fs_base = 7fdc68161540
gs_base = 00000000
ds = 00000000
es = 00000000
fs = 00000000
gs = 00000000
-----------------------
allocate data for backup....
Backingup and rewriting text (0x7fdc6804b1b4)-> 
	0x840475eaf883c289 => 0x4800000001c0c748, 
	0x81d8f7d0894175db => 0x8d4800000001c7c7, 
	0xbafffff000fa => 0xc2c7480000011135, 
	0x5c8b48c2460f0000 => 0xc748050f0000000e, 
	0x28251c3348643824 => 0xc7c74800000003c0, 
	0x155850f000000 => 0xc748050f00000001, 
	0x415d5b48c4834800 => 0xc009480000000ec3, 
	0xfabfdb31c35d415c => 0xc74800000142880f, 
	0x801f0fa0ebffffff => 0x3d8d4800000002c0, 
	0x247c814900000000 => 0x42c6c748000000ea, 
	0x490d773b9ac9ff08 => 0x1b6c2c748000000, 
	0xf664e7900243c83 => 0xfc3c748050f0000, 
	0x16b80000441f => 0xf01f88348000000, 
	0x8247c8990b2eb00 => 0xc7c7480000011385, 
	0x247c8bfffb73b7e8 => 0x3c0c74800000002, 
	0x41e2894cea894d08 => 0xc3c748050f000000, 
	0xe6b8ee89c089 => 0xfc0094800000010, 
	0x8948c78944050f00 => 0xc0c748000000f388, 
	0xfffb73f4e8082444 => 0xab3d8d4800000002, 
	0xff5ee90824448b48 => 0x42c6c748000000, 
	0x841f0f2e66ffff => 0x1b6c2c7480000, 
	0x1c5f64000000000 => 0x11c3c748050f00, 
	0x1825048b642b75 => 0x850f02f883480000, 
	0x8f850fc0850000 => 0x48ff3148000000c4, 
	0xe2894cea894d0000 => 0x50f00000003c0c7, 
	0xb800000001bfee89 => 0x4800000012c3c748, 
	0xc289050f000000e6 => 0xa8880fc009, 
	0xf41f3ffffff2ee9 => 0x4800000002c0c748, 
	0x748d48ff3124046f => 0x3148000000703d8d, 
	0xe8202444290f1024 => 0x13c3c748050ff6, 
	0x850fc085fffffde8 => 0x850f00f883480000, 
	0x24448b48ffffff68 => 0xdc0c74800000084, 
	0x8b481824442b4828 => 0x1c7c748000000, 
	0x1024542b48202454 => 0x4f358d480000, 
	0xc085482824448948 => 0x8c2c749d2314800, 
	0x6420245489487178 => 0xc38948050f000000, 
	0x4c0000001825048b => 0x6552cc5b78c00948, 
	0x85fee5832024648d => 0x6e69746365726964, 
	0x894cea894d7175c0 => 0x742f000a2e2e2e67, 
	0x1bfee89e2 => 0x756f6474732f706d, 
	0x48050f000000e6b8 => 0x742f006465725f74, 
	0xfffebae9da89c389 => 0x72656474732f706d, 
	0x894dfffb72d6e8ff => 0x642f006465725f72, 
	0x8941ee89e2894cea => 0x6c6c756e2f7665, 
	0xe6b800000001bfc0 => 0x00000001, 
	0xc78944050f000000 => 0x04000000, 
	0x7312e80824448948 => 0xdeadbeef, 
	0x890824448b48fffb => 0x00000000, 
	0x51e8fffffe85e9c2 => 0x480000003cc0c748, 
	0x4801ea8348000529 => 0x050fdf89, 
saved data....
0x840475eaf883c289, 0x81d8f7d0894175db, 0xbafffff000fa, 0x5c8b48c2460f0000, 0x28251c3348643824, 0x155850f000000, 0x415d5b48c4834800, 
0xfabfdb31c35d415c, 0x801f0fa0ebffffff, 0x247c814900000000, 0x490d773b9ac9ff08, 0xf664e7900243c83, 0x16b80000441f, 0x8247c8990b2eb00, 
0x247c8bfffb73b7e8, 0x41e2894cea894d08, 0xe6b8ee89c089, 0x8948c78944050f00, 0xfffb73f4e8082444, 0xff5ee90824448b48, 0x841f0f2e66ffff, 
0x1c5f64000000000, 0x1825048b642b75, 0x8f850fc0850000, 0xe2894cea894d0000, 0xb800000001bfee89, 0xc289050f000000e6, 0xf41f3ffffff2ee9, 
0x748d48ff3124046f, 0xe8202444290f1024, 0x850fc085fffffde8, 0x24448b48ffffff68, 0x8b481824442b4828, 0x1024542b48202454, 
0xc085482824448948, 0x6420245489487178, 0x4c0000001825048b, 0x85fee5832024648d, 0x894cea894d7175c0, 0x1bfee89e2, 0x48050f000000e6b8, 
0xfffebae9da89c389, 0x894dfffb72d6e8ff, 0x8941ee89e2894cea, 0xe6b800000001bfc0, 0xc78944050f000000, 0x7312e80824448948, 0x890824448b48fffb, 
0x51e8fffffe85e9c2, 0x4801ea8348000529, 
executing the redirection....
Waiting to regaign control....
restore old text....
r15 = 00000000
r14 = 00000000
r13 = 7fff339d9b10
r12 = 7fff339d9b10
bp = 00000000
bx = ffffffffffffff01
r11 = 00000246
r10 = 7fff339d9b10
r9 = 00000003
r8 = 00000000
ax = fffffffffffffdfc
cx = 7fdc6804b1b4
dx = 7fff339d9b10
si = 00000000
di = 00000000
orig_ax = 000000e6
ip = 7fdc6804b1b4
cs = 00000033
flags = 00000246
sp = 7fff339d9a90
ss = 0000002b
fs_base = 7fdc68161540
gs_base = 00000000
ds = 00000000
es = 00000000
fs = 00000000
gs = 00000000
-----------------------
restore regs....
Fetching state....
r15 = 00000000
r14 = 00000000
r13 = 7fff339d9b10
r12 = 7fff339d9b10
bp = 00000000
bx = ffffffffffffff01
r11 = 00000246
r10 = 7fff339d9b10
r9 = 00000003
r8 = 00000000
ax = fffffffffffffdfc
cx = 7fdc6804b1b4
dx = 7fff339d9b10
si = 00000000
di = 00000000
orig_ax = 000000e6
ip = 7fdc6804b1b4
cs = 00000033
flags = 00000246
sp = 7fff339d9a90
ss = 0000002b
fs_base = 7fdc68161540
gs_base = 00000000
ds = 00000000
es = 00000000
fs = 00000000
gs = 00000000
-----------------------
checking text at execution (0x7fdc6804b1b4)-> 
0x840475eaf883c289, 0x81d8f7d0894175db, 0xbafffff000fa, 0x5c8b48c2460f0000, 0x28251c3348643824, 0x155850f000000, 
0x415d5b48c4834800, 0xfabfdb31c35d415c, 0x801f0fa0ebffffff, 0x247c814900000000, 0x490d773b9ac9ff08, 0xf664e7900243c83, 
0x16b80000441f, 0x8247c8990b2eb00, 0x247c8bfffb73b7e8, 0x41e2894cea894d08, 0xe6b8ee89c089, 0x8948c78944050f00, 
0xfffb73f4e8082444, 0xff5ee90824448b48, 0x841f0f2e66ffff, 0x1c5f64000000000, 0x1825048b642b75, 0x8f850fc0850000, 
0xe2894cea894d0000, 0xb800000001bfee89, 0xc289050f000000e6, 0xf41f3ffffff2ee9, 0x748d48ff3124046f, 0xe8202444290f1024, 
0x850fc085fffffde8, 0x24448b48ffffff68, 0x8b481824442b4828, 0x1024542b48202454, 0xc085482824448948, 0x6420245489487178, 
0x4c0000001825048b, 0x85fee5832024648d, 0x894cea894d7175c0, 0x1bfee89e2, 0x48050f000000e6b8, 0xfffebae9da89c389, 
0x894dfffb72d6e8ff, 0x8941ee89e2894cea, 0xe6b800000001bfc0, 0xc78944050f000000, 0x7312e80824448948, 0x890824448b48fffb, 
0x51e8fffffe85e9c2, 0x4801ea8348000529, 
Continue....
```
