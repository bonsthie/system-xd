const consts = @import("../consts.zig");
const log = @import("std").log;

pub fn coerceProjectAuthors() []const u8 {
    const authors = comptime &consts.Project.authors;
    comptime var result: []const u8 = undefined;
    const sep = ", ";
    const final_sep = ", and ";
    const two_final_sep = " and ";
    comptime var i: usize = 0;
    inline for (authors) |author| {
        if (i == 0) {
            result = author;
        } else if (i == authors.len - 1) {
            if (i == 1) {
                result = result ++ two_final_sep ++ author;
            } else {
                result = result ++ final_sep ++ author;
            }
        } else {
            result = result ++ sep ++ author;
        }
        i += 1;
    }
    return result;
}

pub fn printHeader() void {
    const p = log.scoped(.main);
    const project = consts.Project;
    p.info("Launching {s} v{s}", .{ project.name, project.version });
    p.info("This dumbfuckery is brought to you by {s}", .{coerceProjectAuthors()});
}
