#[macro_use]

pub mod arch;
pub mod memory;
pub mod scheduler;
pub mod sync;

pub use self::scheduler::{Scheduler, Process, Thread};
pub use self::sync::{Mutex, Spinlock, WriterLock, Event};
pub use self::arch::{page_size, page_bit_count};

extern crate bitflags;
pub use self::bitflags::bitflags;

extern crate scopeguard;

pub use core::sync::atomic::*;
pub use core::arch::asm;
pub use core::mem::{size_of, transmute};
pub use core::intrinsics::unreachable;
pub use core::ptr::{null, null_mut};

pub struct ScopeCall<F: FnOnce()> {
    c: Option<F>
}
impl<F: FnOnce()> Drop for ScopeCall<F> {
    fn drop(&mut self) {
        self.c.take().unwrap()()
    }
}

#[macro_export]
macro_rules! expr { ($e: expr) => { $e } } // tt hack

#[macro_export]
macro_rules! defer
{
    ($($data: tt)*) => (
        let _scope_call = ScopeCall {
            c: Some(|| -> () { ::expr!({ $($data)* }) })
        };
    )
}

#[derive(Copy, Clone)]
#[repr(transparent)]
pub struct Volatile<T>
{
    value: T,
}

impl<T> Volatile<T>
{
    fn read_volatile(&self) -> T
    {
        unsafe { core::ptr::read_volatile(&self.value) }
    }

    fn write_volatile(&mut self, value: T)
    {
        unsafe { core::ptr::write_volatile(&mut self.value, value) }
    }

    pub const fn new(value: T) -> Self
    {
        Self
        {
            value
        }
    }
}

#[derive(Copy, Clone)]
#[repr(transparent)]
pub struct VolatilePointer<T>
{
    pub ptr: *mut T,
}

impl<T> VolatilePointer<T>
{
    fn deref_volatile(self) -> T
    {
        unsafe { core::ptr::read_volatile(self.ptr) }
    }

    fn write_volatile(self, value: T)
    {
        unsafe { core::ptr::write_volatile(self.ptr, value) }
    }

    const fn new(ptr: *mut T) -> Self
    {
        Self
        {
            ptr
        }
    }
}

impl<T> PartialEq for VolatilePointer<T>
{
    fn eq(&self, other: &Self) -> bool {
        self.ptr == other.ptr
    }
}

impl<T> const Default for VolatilePointer<T>
{
    fn default() -> Self {
        Self { ptr: null_mut() }
    }
}

#[derive(Copy, Clone)]
pub struct LinkedItem<T>
{
    previous: *mut Self,
    next: *mut Self,

    list: *mut LinkedList<T>,
    item: *mut T,
}

pub struct LinkedList<T>
{
    first: *mut LinkedItem<T>,
    last: *mut LinkedItem<T>,
    count: u64,
}

impl<T> LinkedItem<T>
{
    pub fn remove_from_list(&mut self)
    {
        unsafe { self.list.as_mut() .unwrap().remove(self) };
    }
}

impl<T> LinkedList<T>
{
    pub fn insert_at_start(&mut self, item: &mut LinkedItem<T>)
    {
        if !item.list.is_null()
        {
            panic("inserting an item that's already in a list\n");
        }

        if let Some(first) = unsafe { self.first.as_mut() }
        {
            item.next = first;
            item.previous = null_mut();
            first.previous = item;
            self.first = item;
        }
        else
        {
            self.first = item;
            self.last = item;
            item.previous = null_mut();
            item.next = null_mut();
        }

        self.count += 1;
        item.list = self;
    }

    pub fn insert_at_end(&mut self, item: &mut LinkedItem<T>)
    {
        if !item.list.is_null()
        {
            panic("inserting an item that's already in the list\n");
        }

        if let Some(last) = unsafe { self.last.as_mut() }
        {
            item.previous = last;
            item.next = null_mut();
            last.next = item;
            self.last = item;
        }
        else
        {
            self.first = item;
            self.last = item;
            item.previous = null_mut();
            item.next = null_mut();
        }

        self.count += 1;
        item.list = self;
    }

    pub fn insert_before(&mut self, item: &mut LinkedItem<T>, before: &mut LinkedItem<T>)
    {
        if before as *mut _ != item as *mut _
        {
            item.previous = before.previous;
            unsafe { item.previous.as_mut() }.unwrap().next = item;
        }
        else
        {
            self.first = item;
            item.previous = null_mut();
        }

        item.next = before;
        before.previous = item;

        self.count += 1;
        item.list = self;
    }

    pub fn remove(&mut self, item: &mut LinkedItem<T>)
    {
        if let Some(list) = unsafe { item.list.as_mut() }
        {
            if list as *mut _ != self as *mut _
            {
                panic("removing an item that is from a different list\n");
            }
        }
        else
        {
            panic("item already removed\n");
        }

        if let Some(previous) = unsafe { item.previous.as_mut() }
        {
            previous.next = item.next;
        }
        else
        {
            self.first = item.next;
        }

        if let Some(next) = unsafe { item.next.as_mut() }
        {
            next.previous = item.previous;
        }
        else
        {
            self.last = item.previous;
        }

        item.previous = null_mut();
        item.next = null_mut();
        item.list = null_mut();
        self.count -= 1;
    }
}

const bitset_group_size: u64 = 0x1000;
pub struct Bitset<'a>
{
    single_usage: &'a mut [u32],
    group_usage: &'a mut [u16],
}

impl<'a> Bitset<'a>
{
    pub fn init(&mut self, count: u64, map_all: bool)
    {
        let single_count = (count + 31) & !31;
        let group_count = single_count / bitset_group_size + 1;

        let byte_count = (single_count >> 3) + (group_count * 2);
        let flags =
        {
            if map_all { memory::RegionFlags::fixed }
            else { memory::RegionFlags::empty() }
        };
        let single_usage = unsafe { kernel.process.address_space.standard_allocate(byte_count, flags) };
        let group_usage = single_usage + ((single_count >> 4) * size_of::<u16>() as u64);

        self.single_usage = unsafe { &mut *core::ptr::slice_from_raw_parts_mut(single_usage as *mut u32, single_count as usize) };
        self.group_usage = unsafe { &mut *core::ptr::slice_from_raw_parts_mut(group_usage as *mut u16, group_count as usize) };
    }

    pub fn put_all(&mut self)
    {
        let single_count = self.single_usage.len();
        let mut i: usize = 0;

        while i < single_count
        {
            self.group_usage[i / bitset_group_size as usize] += 32;
            self.single_usage[i / 32] |= 0xffffffff;
            i += 32;
        }
    }

    pub fn get(&mut self, maybe_count: u64, maybe_alignment: u64, maybe_below: u64) -> u64
    {
        let result = u64::MAX;

        let below = 
        {
            if maybe_below != 0
            {
                if maybe_below < maybe_count { return result }
                maybe_below - maybe_count
            }
            else
            {
                maybe_below
            }
        };

        unimplemented!()
    }

    pub fn read(&mut self, index: u64) -> bool
    {
        (self.single_usage[index as usize >> 5] & (1 << (index as usize & 31))) != 0
    }

    pub fn take(&mut self, index: u64)
    {
        let group = (index / bitset_group_size) as usize;
        self.group_usage[group] -= 1;
        self.single_usage[index as usize >> 5] &= !(1 << (index & 31));
    }

    pub fn put(&mut self, index: u64)
    {
        self.single_usage[index as usize >> 5] |= 1 << (index & 31);
        self.group_usage[(index / bitset_group_size) as usize] += 1;
    }
}

pub struct Kernel<'a>
{
    core: Core<'a>,
    scheduler: Scheduler,
    process: Process,
    physical_allocator: memory::Physical::Allocator<'a>,
    arch: arch::Specific<'a>,
}

pub struct Core<'a>
{
    regions: &'a mut[memory::Region],
    region_commit_count: u64,
    address_space: memory::AddressSpace,
}

impl<'a> Kernel<'a>
{
    #[inline(never)]
    pub fn init(&mut self)
    {
        self.process.register(scheduler::ProcessKind::kernel);
        self.memory_init();
    }
}

pub static mut kernel: Kernel = Kernel
{
    core: Core
    {
        regions: &mut[],
        region_commit_count: 0,
        address_space: memory::AddressSpace::default(),
    },
    scheduler: Scheduler
    {
        dispatch_spinlock: Spinlock::default(),
        next_process_id: AtomicU64::new(0),
        started: false,
        panic: false,
        shutdown: false,
    },
    process: Process
    {
        id: 0,
        handle_count: 0,
        address_space: memory::AddressSpace::default(),
        permissions: scheduler::ProcessPermissions::empty(),
        kind: scheduler::ProcessKind::kernel,
    },
    physical_allocator: memory::Physical::Allocator
    {
        pageframes: &mut[],
        commit_mutex: Mutex::default(),
        pageframe_mutex: Mutex::default(),

        first_free_page: 0,
        first_zeroed_page: 0,
        first_standby_page: 0,
        last_standby_page: 0,

        zeroed_page_count: 0,
        free_page_count: 0,
        standby_page_count: 0,
        active_page_count: 0,

        commit_fixed: 0,
        commit_pageable: 0,
        commit_fixed_limit: 0,
        commit_limit: 0,

        approximate_total_object_cache_byte_count: 0,
    },
    arch: arch::Specific::default(),
};

// @INFO: this hack is just to get the value of msg string which is passed to panic
fn _panic(msg: &str) -> !
{
    let _ = msg;
    loop{}
}

#[cold]
pub fn panic(msg: &str) -> !
{
    _panic(msg);
}
