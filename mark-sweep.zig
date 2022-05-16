const std = @import("std");
const print = @import("std").debug.print;
//const Gpa = std.heap.GeneralPurposeAllocator;

const STACK_MAX = 256;
const INIT_OBJ_NUM_MAX = 8;

const ObjectType = enum {
    OBJ_INT,
    OBJ_PAIR,
};

const Object = struct {
    type: ObjectType,
    marked: bool,
    data: Data,

    // The next object in the linked list of heap allocated objects.
    next: ?*Object,
};

const Data = union { value: i32, pair: struct { head: ?*Object, tail: ?*Object } };

const VM = struct {
    //const Self = @This();

    stack: []*Object, // TODO: Slice ? See ArrayList source code, pub fn init
    stackSize: u32,

    // The first object in the linked list of all objects on the heap. */
    firstObject: ?*Object,

    // The total number of currently allocated objects. */
    numObjects: u32,

    // The number of objects required to trigger a GC. */
    maxObjects: u32,

    allocator: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !VM {
        // From: https://stackoverflow.com/questions/61422445/malloc-to-a-list-of-struct-in-zig
        //const llocator: std.mem.Allocator = std.heap.page_allocator; // this is not the best choice of allocator, see below.
        //const my_slice_of_foo: []*Object = try llocator.alloc(*Object, STACK_MAX);
        //defer llocator.free(my_slice_of_foo);

        const stack: []*Object = try alloc.alloc(*Object, STACK_MAX);

        return VM{
            .stack = stack,
            .stackSize = 0,
            .firstObject = null,
            .numObjects = 0,
            .maxObjects = STACK_MAX,
            .allocator = alloc,
        };
    }

    pub fn deinit(self: *VM) void {
        self.stackSize = 0;
        self.gc();
        self.allocator.free(self.stack);
    }

    fn mark(self: *VM, object: *Object) void {
        // If already marked, we're done. Check this first to avoid recursing
        //   on cycles in the object graph.
        if (object.marked) return;

        object.marked = true;

        if (object.type == ObjectType.OBJ_PAIR) {
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
        while (i < self.stackSize) : (i += 1) {
            self.mark(self.stack[i]);
        }
    }

    fn sweep(self: *VM) void {
        var object = &(self.firstObject);
        while (object.*) |obj| {
            if (!obj.marked) {
                //print("free unmarked object\n", .{});
                // This object wasn't reached, so remove it from the list and free it.
                var unreached = obj;

                if (obj.next) |n| {
                    object.* = n; //unreached.next);
                } else {
                    object.* = null;
                }
                self.allocator.destroy(unreached);

                self.numObjects -= 1;
            } else {
                //print("found marked object\n", .{});
                // This object was reached, so unmark it (for the next GC) and move on to
                // the next.
                obj.marked = false;
                object = &(obj.next);
            }
        }
        print("Done with sweep", .{});

        //var optional_object: ?*Object = self.firstObject;
        //while (optional_object != null) {
        //    const object = optional_object orelse break;
        //    if (object.marked == false) {
        //        print("free unmarked object\n", .{});
        //        // This object wasn't reached, so remove it from the list and free it.
        //        var unreached: *Object = object;

        //        optional_object = unreached.next;
        //        self.allocator.destroy(unreached);

        //        self.numObjects -= 1;
        //    } else {
        //        print("found marked object\n", .{});
        //        // This object was reached, so unmark it (for the next GC) and move on to
        //        // the next.
        //        object.marked = false;
        //        optional_object = object.next;
        //    }
        //}
    }

    //Object** object = &vm->firstObject;
    //while (*object) {
    //  if (!(*object)->marked) {
    //    /* This object wasn't reached, so remove it from the list and free it. */
    //    Object* unreached = *object;

    //    *object = unreached->next;
    //    free(unreached);

    //    vm->numObjects--;
    //  } else {
    //    /* This object was reached, so unmark it (for the next GC) and move on to
    //     the next. */
    //    (*object)->marked = 0;
    //    object = &(*object)->next;
    //  }
    //}

    pub fn gc(self: *VM) void {
        var numObjects = self.numObjects;

        self.markAll();
        self.sweep();

        if (self.numObjects == 0) {
            self.maxObjects = INIT_OBJ_NUM_MAX;
        } else {
            self.maxObjects *= 2;
        }

        print("Collected {} objects, {} remaining.\n", .{ numObjects - self.numObjects, self.numObjects });
    }

    fn newObject(self: *VM, otype: ObjectType) !*Object {
        var obj = try self.allocator.create(Object);
        obj.type = otype;
        obj.marked = false;
        obj.next = self.firstObject;
        self.firstObject = obj;
        self.numObjects += 1;
        return obj;
    }

    pub fn pushInt(self: *VM, value: i32) !void {
        var obj = try self.newObject(ObjectType.OBJ_INT);
        obj.data = Data{ .value = value };
        self.push(obj);
    }

    pub fn pushPair(self: *VM) !*Object {
        var obj = try self.newObject(ObjectType.OBJ_PAIR);
        var t = self.pop();
        var h = self.pop();
        obj.data = Data{ .pair = .{ .head = h, .tail = t } };
        self.push(obj);
        return obj;
    }

    pub fn push(self: *VM, value: *Object) void {
        if (self.stackSize >= STACK_MAX) {
            print("Stack overflow!", .{});
            unreachable;
        }

        self.stack[self.stackSize] = value;
        self.stackSize += 1;
    }

    pub fn pop(self: *VM) *Object {
        if (self.stackSize == 0) {
            print("Stack underflow!", .{});
            unreachable;
        }

        self.stackSize -= 1;
        return self.stack[self.stackSize];
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

    try std.testing.expect(vm.numObjects == 2);
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
    try std.testing.expect(vm.numObjects == 0); // "Should have collected objects."
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
    //  assert(vm->numObjects == 7, "Should have reached objects.");
    try std.testing.expect(vm.numObjects == 7); // "Should have reached objects."
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
    //  a->tail = b;
    //  b->tail = a;
    a.data.pair.tail = b;
    b.data.pair.tail = a;

    vm.gc();
    //  assert(vm->numObjects == 4, "Should have collected objects.");
    try std.testing.expect(vm.numObjects == 4); // "Should have collected objects."
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
    //  for (int i = 0; i < 1000; i++) {
    //    for (int j = 0; j < 20; j++) {
    //      pushInt(vm, i);
    //    }
    //
    //    for (int k = 0; k < 20; k++) {
    //      pop(vm);
    //    }
    //  }
    vm.deinit();
}

pub fn main() !void {
    //const stdout = std.io.getStdOut().writer();
    //try stdout.print("Hello, {s}!\n", .{"world"});
    const allocator = std.testing.allocator;
    print("Test 2: Unreached objects are collected.\n", .{});

    var _vm = try VM.init(allocator);
    var vm = &_vm;

    try vm.pushInt(1);
    try vm.pushInt(2);
    _ = vm.pop();
    _ = vm.pop();

    vm.gc();
    try std.testing.expect(vm.numObjects == 0); // "Should have collected objects."
    vm.deinit();
}

// Older notes / code:

// TODO: pass allocator in
//    pub fn init() !*Object {
//        // https://dev.to/pmalhaire/ziglang-first-contact-with-memory-safety-and-simplicity-83p
//        // based off example from https://ziglearn.org/chapter-2/
//        //var gpa = Gpa(.{}){};
//        //const allocator = &gpa.allocator;
//        //var obj = try allocator.alloc(Object, 1);
//        return obj;
//    }
