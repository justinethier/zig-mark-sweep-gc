mark-sweep: mark-sweep.zig
	zig build-exe mark-sweep.zig

.PHONY: test

test:
	zig test mark-sweep.zig
