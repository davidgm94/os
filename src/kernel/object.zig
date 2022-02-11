const kernel = @import("kernel.zig");

const TODO = kernel.TODO;
const ES_CURRENT_THREAD = kernel.ES_CURRENT_THREAD;
const ES_CURRENT_PROCESS = kernel.ES_CURRENT_PROCESS;
const ES_INVALID_HANDLE = kernel.ES_INVALID_HANDLE;

const arch = kernel.arch;

const SharedRegion = kernel.memory.SharedRegion;

const Process = kernel.scheduling.Process;
const Thread = kernel.scheduling.Thread;

const Mutex = kernel.sync.Mutex;

pub const Type = enum(u32)
{
    could_not_resolve = 0,
    none = 0x80000000,
    process = 0x1,
    thread = 0x2,
    window = 0x4,
    shared_memory = 0x8,
    node = 0x10,
    event = 0x20,
    constant_buffer = 0x40,
    posix_fd = 0x100,
    pipe = 0x200,
    embedded_window = 0x400,
    connection = 0x4000,
    device = 0x8000,
};

const ResolveHandleStatus = enum(u8)
{
    failed = 0,
    no_close = 1,
    normal = 2,
};


pub const Handle = extern struct
{
    object: ?*anyopaque,
    flags: u32,
    type: Type,

    const TableL2 = extern struct
    {
        t: [256]Handle,

        const entry_count = 256;
    };

    const TableL1 = extern struct
    {
        t: [256]?*TableL2,
        u: [256]u16,

        const entry_count = 256;
    };

    pub const Table = extern struct
    {
        l1r: TableL1,
        lock: Mutex,
        process: ?*Process,
        destroyed: bool,
        handleCount: u32,

        pub fn resolve_handle(self: *@This(), out_handle: *Handle, in_handle: u64, type_mask: u32) ResolveHandleStatus
        {
            if (in_handle == ES_CURRENT_THREAD and type_mask & @enumToInt(Type.thread) != 0)
            {
                out_handle.type = .thread;
                out_handle.object = arch.get_current_thread();
                out_handle.flags = 0;

                return .no_close;
            }
            else if (in_handle == ES_CURRENT_PROCESS and type_mask & @enumToInt(Type.process) != 0)
            {
                out_handle.type = .process;
                out_handle.object = arch.get_current_thread().?.process;
                out_handle.flags = 0;

                return .no_close;
            }
            else if (in_handle == ES_INVALID_HANDLE and type_mask & @enumToInt(Type.none) != 0)
            {
                out_handle.type = .none;
                out_handle.object = null;
                out_handle.flags = 0;

                return .no_close;
            }

            _ = self;
            TODO(@src());
        }

        pub fn destroy(self: *@This()) void
        {
            _ = self.lock.acquire();
            defer self.lock.release();

            if (self.destroyed) return;

            self.destroyed = true;

            const l1 = &self.l1r;

            var i: u64 = 0;
            while (i < TableL1.entry_count) : (i += 1)
            {
                if (l1.u[i] == 0) continue;

                var k: u64 = 0;
                while (k < TableL1.entry_count) : (k += 1)
                {
                    const handle = &l1.t[i].?.t[k];
                    if (handle.object != null) close_handle(handle.object, handle.flags);
                }

                kernel.heapFixed.free(@ptrToInt(l1.t[i]), 0);
            }
        }
    };
};

pub fn open_handle(object: anytype, flags: u32) bool
{
    _ = flags;
    var had_no_handles = false;
    var failed = false;

    const object_type = @TypeOf(object);
    switch (object_type)
    {
        *Process =>
        {
            had_no_handles = @ptrCast(*Process, object).handle_count.atomic_fetch_add(1) == 0;
        },
        *Thread =>
        {
            had_no_handles = @ptrCast(*Thread, object).handle_count.atomic_fetch_add(1) == 0;
        },
        *SharedRegion =>
        {
            const region = @ptrCast(*SharedRegion, object);
            _ = region.mutex.acquire();
            had_no_handles = (region.handle_count.read_volatile() == 0);
            if (!had_no_handles) region.handle_count.increment();
            region.mutex.release();
        },
        else => TODO(@src()),
    }

    if (had_no_handles) kernel.panic("object had no handles");

    return !failed;
}

pub fn close_handle(object: anytype, flags: u32) void
{
    _ = flags;
    const object_type = @TypeOf(object);
    switch (object_type)
    {
        *Process =>
        {
            const _process = @ptrCast(*Process, object);
            const previous = _process.handle_count.atomic_fetch_sub(1);
            // @Log
            if (previous == 0) kernel.panic("All handles to process have been closed")
            else if (previous == 1) TODO(@src());
        },
        *Thread =>
        {
            const thread = @ptrCast(*Thread, object);
            const previous = thread.handle_count.atomic_fetch_sub(1);

            if (previous == 0) kernel.panic("All handles to thread have been closed")
            else if (previous == 1) thread.remove();
        },
        else => TODO(@src()),
    }
}

