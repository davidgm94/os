const kernel = @import("kernel.zig");

const clamp = kernel.clamp;
const Volatile = kernel.Volatile;
const TODO = kernel.TODO;

const LinkedList = kernel.LinkedList;

const Mutex = kernel.sync.Mutex;
const Event = kernel.sync.Event;

const memory = kernel.memory;

const Thread = kernel.Scheduler.Thread;

const page_size = kernel.Arch.page_size;

pub const Space = struct
{
};

pub const ActiveSession = struct
{
    load_complete_event: Event,
    write_complete_event: Event,
    list_item: LinkedList(ActiveSession).Item,

    offset: u64,
    cache: ?*Space,

    accessor_count: u64,
    loading: Volatile(bool),
    writing: Volatile(bool),
    modified: Volatile(bool),
    flush: Volatile(bool),

    referenced_page_count: u16,
    referenced_pages: [max_page_array_count]u8,
    modified_pages: [max_page_array_count]u8,

    pub const size = 262144;
    pub const max_page_array_count = ActiveSession.size / page_size / 8;

    pub fn get_bytes() u64
    {
        return clamp(u64, 0, 1024 * 1024 * 1024, kernel.physical_allocator.commit_fixed_limit * page_size / 4);
    }

    pub const Manager = struct
    {
        sections: []ActiveSession,
        base_address: u64,
        mutex: Mutex,
        LRU_list: LinkedList(ActiveSession),
        modified_list: LinkedList(ActiveSession),
        modified_non_empty_event: Event,
        modified_non_full_event: Event,
        modified_getting_full_event: Event,
        write_back_thread: ?*Thread,

        pub fn init(self: *@This()) void
        {
            self.sections.len = ActiveSession.get_bytes() / ActiveSession.size;
            self.sections.ptr = @intToPtr([*]ActiveSession, kernel.core.fixed_heap.allocate(self.sections.len * @sizeOf(ActiveSession), true));

            _ = kernel.process.address_space.reserve_mutex.acquire();
            self.base_address = kernel.process.address_space.reserve(self.sections.len * ActiveSession.size, memory.Region.Flags.new_from_flag(.cache)).?.descriptor.base_address;
            kernel.process.address_space.reserve_mutex.release();

            for (self.sections) |*section|
            {
                section.list_item.value = section;
                self.LRU_list.insert_at_end(&section.list_item);
            }

            _ = self.modified_non_full_event.set(false);
            self.write_back_thread = kernel.process.spawn_thread(@ptrToInt(write_behind_thread), 0, Thread.Flags.empty());
            self.write_back_thread.?.is_page_generator = true;
        }
    };
};

pub fn write_behind_thread() callconv(.C) void
{
    TODO();
}
