mark-sweep: mark-sweep.zig
	zig build-exe mark-sweep.zig

.PHONY: doc test

doc:
	zig test mark-sweep.zig -femit-docs

test:
	zig test mark-sweep.zig
