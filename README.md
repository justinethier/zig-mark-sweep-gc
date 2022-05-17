# Mark-Sweep GC in Zig

The project is the port of a modern classic program - Bob Nystrom's simple mark-sweep GC - from C to Zig.  

(can't do the original write-up justice, see it at (blog link))
The original implemtation is included here as `main.c` and is available at: https://github.com/munificent/mark-sweep

areas to highlight:

- zig installation, no dependencies

The installation process is very simple. Just download the latest version from the [Releases page](https://ziglang.org/download/), extract to a folder, and add to your path.

Here is this code being used for the project's continuous integration: 

          wget https://ziglang.org/download/0.9.1/zig-linux-x86_64-0.9.1.tar.xz
          tar xf zig-linux*.tar.xz
          echo "`pwd`/zig-linux-x86_64-0.9.1" >> $GITHUB_PATH

For a real installation we would install this somewhere more appropriate but this works well for our CI.

`zig` comes as a large statically-linked executable. No dependencies required :thumbsup:.

- vim plugin

https://github.com/ziglang/zig.vim "Vim configuration for Zig"

Originally I only installed this to get syntax highlighting but then I discovered this:

> This plugin enables automatic code formatting on save by default using `zig fmt`.

Its super handy to be able to just *not worry* about formatting. This was a great feature of Go and its welcome here as well. 

A nice bonus here is the command can also catch basic syntax errors and such. I tend to save frequently when coding so this provides constant feedback on the state of the code.

- printing, and struct vs varargs

    const print = @import("std").debug.print;
    print("Collected {} objects, {} remaining.\n", .{ numObjects - self.numObjects, self.numObjects });

- while loops, if's, optionals, error unions
- sweep code
- debugging with gdb
- test sections

what else?
- web assembly compilation (TBD, probably requires a main and possibly a more detailed implementation)
