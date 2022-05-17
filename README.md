# Mark-Sweep GC in Zig

The project is the port of a modern classic program - Bob Nystrom's simple mark-sweep GC - from C to Zig.  

(can't do the original write-up justice, see it at (blog link))
The original implemtation is included here as `main.c` and is available at: https://github.com/munificent/mark-sweep

areas to highlight:

- zig installation, no dependencies
- vim plugin
- sweep code
- while loops, if's, optionals, error unions
- printing, and struct vs varargs
- debugging with gdb
- test sections

what else?
- web assembly compilation (TBD, probably requires a main and possibly a more detailed implementation)
