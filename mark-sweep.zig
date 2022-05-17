//! Justin Ethier, 2022
//! https://github.com/justinethier/zig-mark-sweep-gc
//!
//! Implementation of a simple mark-sweep garbage collector. Ported from Bob Nystrom's original code in C.
//!

const std = @import("std");
const print = @import("std").debug.print;

const stack_max = 256;
const init_obj_num_max = 8;

const ObjectType = enum {
    int,
    pair,
};

const Object = struct {
    type: ObjectType,
    marked: bool,
    data: union { value: i32, pair: struct { head: ?*Object, tail: ?*Object } },

    // The next object in the linked list of heap allocated objects.
    next: ?*Object,
};

const VM = struct {
    /// Stack used to store objects between VM function calls.
    /// These objects serve as the roots of the GC.
    stack: []*Object,

    /// Number of objects currently on the stack
    stack_size: u32,

    /// The first object in the linked list of all objects on the heap.
    first_object: ?*Object,

    /// The total number of currently allocated objects.
    num_objects: u32,

    /// The number of objects required to trigger a GC.
    max_objects: u32,

    allocator: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !VM {
        const stack: []*Object = try alloc.alloc(*Object, stack_max);

        return VM{
            .stack = stack,
            .stack_size = 0,
            .first_object = null,
            .num_objects = 0,
            .max_objects = stack_max,
            .allocator = alloc,
        };
    }

    /// Reclaim all memory allocated by the VM
    pub fn deinit(self: *VM) void {
        self.stack_size = 0;
        self.gc();
        self.allocator.free(self.stack);
    }

    fn mark(self: *VM, object: *Object) void {
        // If already marked, we're done. Check this first to avoid recursing
        //   on cycles in the object graph.
        if (object.marked) return;

        object.marked = true;

        if (object.type == ObjectType.pair) {
            if (object.data.pair.head) |head| {
                self.mark(head);
            }
            if (object.data.pair.tail) |tail| {
                self.mark(tail);
            }
        }
    }

    fn markAll(self: *VM) void {
        var i: u32 = 0;
        while (i < self.stack_size) : (i += 1) {
            self.mark(self.stack[i]);
        }
    }

    fn sweep(self: *VM) void {
        var object = &(self.first_object);
        while (object.*) |obj| {
            if (!obj.marked) {
                // This object wasn't reached, so remove it from the list and free it.
                var unreached = obj;

                object.* = obj.next; // Unlink obj, chain points to obj.next instead
                self.allocator.destroy(unreached);

                self.num_objects -= 1;
            } else {
                // This object was reached, so unmark it (for the next GC) and move on to
                // the next.
                obj.marked = false;
                object = &(obj.next);
            }
        }
        //print("Done with sweep", .{});
    }

    pub fn gc(self: *VM) void {
        var num_objects = self.num_objects;

        self.markAll();
        self.sweep();

        if (self.num_objects == 0) {
            self.max_objects = init_obj_num_max;
        } else {
            self.max_objects *= 2;
        }

        print("Collected {} objects, {} remaining.\n", .{ num_objects - self.num_objects, self.num_objects });
    }

    fn newObject(self: *VM, otype: ObjectType) !*Object {
        var obj = try self.allocator.create(Object);
        obj.type = otype;
        obj.marked = false;
        obj.next = self.first_object;
        self.first_object = obj;
        self.num_objects += 1;
        return obj;
    }

    pub fn pushInt(self: *VM, value: i32) !void {
        var obj = try self.newObject(ObjectType.int);
        obj.data = .{ .value = value };
        self.push(obj);
    }

    pub fn pushPair(self: *VM) !*Object {
        var obj = try self.newObject(ObjectType.pair);
        var t = self.pop();
        var h = self.pop();
        obj.data = .{ .pair = .{ .head = h, .tail = t } };
        self.push(obj);
        return obj;
    }

    pub fn push(self: *VM, value: *Object) void {
        if (self.stack_size >= stack_max) {
            print("Stack overflow!", .{});
            unreachable;
        }

        self.stack[self.stack_size] = value;
        self.stack_size += 1;
    }

    pub fn pop(self: *VM) *Object {
        if (self.stack_size == 0) {
            print("Stack underflow!", .{});
            unreachable;
        }

        self.stack_size -= 1;
        return self.stack[self.stack_size];
    }
};

test "test 1" {
    const allocator = std.testing.allocator;
    print("Test 1: Objects on stack are preserved.\n", .{});

    var _vm = try VM.init(allocator);
    var vm = &_vm;
    try vm.pushInt(1);
    try vm.pushInt(2);

    vm.gc();

    try std.testing.expect(vm.num_objects == 2);
    vm.deinit();
}

test "test 2" {
    const allocator = std.testing.allocator;
    print("Test 2: Unreached objects are collected.\n", .{});

    var _vm = try VM.init(allocator);
    var vm = &_vm;

    try vm.pushInt(1);
    try vm.pushInt(2);
    _ = vm.pop();
    _ = vm.pop();

    vm.gc();
    try std.testing.expect(vm.num_objects == 0); // "Should have collected objects."
    vm.deinit();
}

test "test 3" {
    const allocator = std.testing.allocator;
    print("Test 3: Reach nested objects.\n", .{});
    var vm = &(try VM.init(allocator));
    //var vm = &_vm;
    try vm.pushInt(1);
    try vm.pushInt(2);
    _ = try vm.pushPair();
    try vm.pushInt(3);
    try vm.pushInt(4);
    _ = try vm.pushPair();
    _ = try vm.pushPair();

    vm.gc();
    try std.testing.expect(vm.num_objects == 7); // "Should have reached objects."
    vm.deinit();
}

test "test 4" {
    const allocator = std.testing.allocator;
    print("Test 4: Handle cycles.\n", .{});
    var vm = &(try VM.init(allocator));
    try vm.pushInt(1);
    try vm.pushInt(2);
    var a = vm.pushPair() catch unreachable;
    try vm.pushInt(3);
    try vm.pushInt(4);
    var b = vm.pushPair() catch unreachable;

    // Set up a cycle, and also make 2 and 4 unreachable and collectible.
    a.data.pair.tail = b;
    b.data.pair.tail = a;

    vm.gc();
    try std.testing.expect(vm.num_objects == 4); // "Should have collected objects."
    vm.deinit();
}

test "perf test" {
    const allocator = std.testing.allocator;
    print("Performance Test.\n", .{});
    var vm = &(try VM.init(allocator));

    var i: i32 = 0;
    while (i < 1000) : (i += 1) {
        var j: i32 = 0;
        while (j < 20) : (j += 1) {
            try vm.pushInt(i);
        }
        var k: i32 = 0;
        while (k < 20) : (k += 1) {
            _ = vm.pop();
        }
    }
    vm.deinit();
}

// pub fn main() !void {
// }

