const std = @import("std");
const io = std.io;
const log = std.log.scoped(.readline);
const File = std.fs.File;

const rlReadSize = 1024;

var buffer: [*:0]u8 = null;

const rlNode = struct { buffer: ?[*:0]u8 = null, next: ?*rlNode };

const rlLine = struct {
    line: []u8,
    pub fn free(self: rlLine, allocator: std.mem.Allocator) void {
        allocator.free(self.rlLine);
    }
};

// 1. Check the buffer for a newline character ('\n').
//    - If found, trim the buffer to the correct size and return the rlLine.
//
// 2. If no newline is found, initialize the first node (`rlNode`) with the current buffer contents.
//
// 3. Continuously read from the input stream in chunks of 1024 bytes:
//    - If `readUntilDelimiterOrEof()` returns `error.StreamTooLong`, allocate a new node.
//    - Store the remaining portion of the data in the new buffer.
//
// 4. Once the full rlLine is read, concatenate all `rlNode` chunks.
//
// 5. Return the assembled rlLine inside a temporary struct that does not require further allocations.

pub fn readline(_: std.mem.Allocator, fd: File) !rlLine {
    var buf_reader = io.bufferedReader(fd.reader());
    var in_stream = buf_reader.reader();
    var buf: [1024]u8 = undefined;
    while (in_stream.readUntilDelimiterOrEof(&buf, '\n')) |newLine| {
        if (newLine) |line| {
            std.debug.print("line [{s}]\n", .{line});
        } else {
            std.debug.print("line [{}]\n", .{newLine});
        }
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const fd = std.fs.cwd().openFile("test", .{}) catch |err| {
        std.log.debug("{s} open fail : {}", .{ "test", err });
        return error.newTTYOpenFail;
    };
    try readline(allocator, fd);
}
