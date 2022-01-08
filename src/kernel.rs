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
pub use core::mem::{size_of, transmute, transmute_copy};
pub use core::intrinsics::unreachable;
pub use core::ptr::{null, null_mut, addr_of, addr_of_mut};

pub const lock_exclusive: bool = true;
pub const lock_shared: bool = false;

pub fn take_slice<'a, T>(ptr: *mut T, count: usize) -> &'a mut[T]
{
    unsafe { &mut *core::ptr::slice_from_raw_parts_mut(ptr, count) } 
}

pub fn take_byte_slice<'a, T>(ptr: *mut T, count: usize) -> &'a mut[u8]
{
    take_slice(ptr as *mut u8, count)
}

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

impl Volatile<u64>
{
    pub fn increment_volatile(&mut self)
    {
        self.write_volatile(self.read_volatile() + 1);
    }
}
impl Volatile<i64>
{
    pub fn increment_volatile(&mut self)
    {
        self.write_volatile(self.read_volatile() + 1);
    }

    pub fn decrement_volatile(&mut self)
    {
        self.write_volatile(self.read_volatile() - 1);
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
    /// This method is named diferently in order to differentiate it from the Volatile struct,
    /// which does not involve pointers
    fn deref_volatile(self) -> T
    {
        unsafe { core::ptr::read_volatile(self.ptr) }
    }

    /// This method is named diferently in order to differentiate it from the Volatile struct,
    /// which does not involve pointers
    fn write_volatile_at_address(self, value: T)
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

#[derive(Copy, Clone)]
pub struct LinkedList<T>
{
    first: *mut LinkedItem<T>,
    last: *mut LinkedItem<T>,
    count: u64,
}

impl<T> const Default for LinkedList<T>
{
    fn default() -> Self {
        Self { first: null_mut(), last: null_mut(), count: 0 }
    }
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

impl<'a> const Default for Bitset<'a> {
    fn default() -> Self {
        Self { single_usage: &mut[], group_usage: &mut[] }
    }
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

pub mod AVL
{
    use kernel::*;

    pub enum TreeSearchMode
    {
        exact,
        smallest_above_or_equal,
        largest_below_or_equal,
    }

    type Key = u64;

    #[derive(Copy)]
    pub struct Item<T>
    {
        this: *mut T,
        children: [*mut Self; 2],
        parent: *mut Self,
        tree: *mut Tree<T>,
        key: Key,
        height: i32,
    }

    pub enum DuplicateKeyPolicy
    {
        panic,
        allow,
        fail,
    }

    #[derive(Copy, Clone)]
    pub struct Tree<T>
    {
        root: *mut Item<T>,
        modcheck: bool,
    }

    impl<T> Clone for Item<T>
    {
        fn clone(&self) -> Self {
            Self { this: self.this.clone(), children: self.children.clone(), parent: self.parent.clone(), tree: self.tree.clone(), key: self.key.clone(), height: self.height.clone() }
        }
    }
    impl<T> Item<T>
    {
        fn relink(&mut self, new_location: &mut Self)
        {
            let parent = unsafe { self.parent.as_mut().unwrap() };
            parent.children[(parent.children[1] == self as *mut _) as usize] = new_location;
            if let Some(left) = unsafe { self.children[0].as_mut() }
            {
                left.parent = new_location;
            }
            if let Some(right) = unsafe { self.children[1].as_mut() }
            {
                right.parent = new_location;
            }
        }

        pub fn swap(&mut self, other: &mut Self)
        {
            unsafe
            {
                (*self.parent).children[((*self.parent).children[1] == self as *mut _) as usize] = other;
                (*other.parent).children[((*other.parent).children[1] == other as *mut _) as usize] = self;
            }

            let tmp_self = self.clone();
            let tmp_other = other.clone();

            self.parent = tmp_other.parent;
            other.parent = tmp_self.parent;

            self.height = tmp_other.height;
            other.height = self.height;

            self.children[0] = tmp_other.children[0];
            self.children[1] = tmp_other.children[1];
            other.children[0] = tmp_self.children[0];
            other.children[1] = tmp_self.children[1];

            if let Some(self_left_child) = unsafe { self.children[0].as_mut() } { self_left_child.parent = self }
            if let Some(self_right_child) = unsafe { self.children[1].as_mut() } { self_right_child.parent = self }
            if let Some(other_left_child) = unsafe { other.children[0].as_mut() } { other_left_child.parent = other }
            if let Some(other_right_child) = unsafe { other.children[1].as_mut() } { other_right_child.parent = other }
        }

        pub fn compare(&self, other: &Self) -> i32
        {
            if self.key < other.key { return -1 }
            if self.key > other.key { return 1; }
            return 0
        }

        pub fn rotate_left(&mut self) -> *mut Self
        {
            let x = self;
            let y = x.children[1];
            let t = unsafe { (*y).children[0] };
            unsafe { (*y).children[0] = x; };
            x.children[1] = t;

            x.parent = y;
            if let Some(t_unwrapped) = unsafe { t.as_mut() } { t_unwrapped.parent = x }

            x.height = x.compute_height();
            unsafe { y.as_mut().unwrap().height =  y.as_ref().unwrap().compute_height() }

            y
        }

        pub fn rotate_right(&mut self) -> *mut Self
        {
            let y = self;
            let x = unsafe { y.children[0].as_mut().unwrap() };
            let t = x.children[1];
            x.children[1] = y;
            y.children[0] = t;

            y.parent = x;
            if let Some(t_unwrapped) = unsafe { t.as_mut() } { t_unwrapped.parent = y }

            y.height = y.compute_height();
            x.height = x.compute_height();

            return x;
        }

        fn compute_height(&self) -> i32
        {
            let left_height =
            {
                if let Some(left) = unsafe { self.children[0].as_mut() } { left.height }
                else { 0 }
            };
            let right_height =
            {
                if let Some(right) = unsafe { self.children[1].as_mut() } { right.height }
                else { 0 }
            };
            let balance = left_height - right_height;
            let height =
            {
                if balance > 0 { left_height }
                else { right_height }
            } + 1;

            height
        }

        fn validate(&self, tree: &Tree<T>, parent: *mut Self)
        {
            unimplemented!()
        }
    }

    impl<T> Tree<T>
    {
        pub fn insert(&mut self, item: &mut Item<T>, this: &mut T, key: Key, duplicate_key_policy: DuplicateKeyPolicy) -> bool
        {
            if self.modcheck { panic("concurrent modification\n") }
            self.modcheck = true;

            let mut success = true;

            unsafe { self.root.as_mut().unwrap().validate(self, null_mut()) };

            if !item.tree.is_null() { panic("item already in a tree\n") }
            item.tree = self;

            item.key = key;
            item.children[0] = null_mut();
            item.children[1] = null_mut();
            item.this = this;
            item.height = 1;

            let mut link = addr_of_mut!(self.root);
            let mut parent: *mut Item<T> = null_mut();

            while let Some(node) = unsafe { (*link).as_mut() }
            {
                if item.compare(node) == 0
                {
                    match duplicate_key_policy
                    {
                        DuplicateKeyPolicy::panic => { panic("duplicate keys\n") }
                        DuplicateKeyPolicy::fail => { success = false; break; }
                        DuplicateKeyPolicy::allow => { }
                    }
                }

                let child_index = (item.compare(node) > 0) as usize;
                link = addr_of_mut!(node.children[child_index]);
                parent = node;
            }

            if success
            {
                unsafe
                {
                    *link = item;
                    item.parent = parent;
                }

                let mut fake_root = unsafe { core::mem::zeroed::<Item<T>>() };
                unsafe { self.root.as_mut().unwrap().parent = addr_of_mut!(fake_root) };
                fake_root.tree = self;
                fake_root.key = 0;
                fake_root.children[0] = self.root;

                let it = item.parent;

                while it != addr_of_mut!(fake_root)
                {
                    unimplemented!()
                }
                unimplemented!()
            }
            else
            {
                return false;
            }
        }
    }
}

#[derive(Copy, Clone)]
pub struct Array<T>
{
    ptr: *mut T,
    len: u64,
    cap: u64,
    heap: *mut memory::Heap,
}

impl<T> Array<T>
{
    pub fn insert(&mut self, item: T, i: u64) -> *mut T
    {
        todo!()
    }

    pub fn delete_many(&mut self, position: u64, count: u64)
    {
        todo!()
    }

    pub fn get_slice<'a>(&self) -> &'a mut [T]
    {
        take_slice::<T>(self.ptr, self.len as usize)
    }
}

#[derive(Copy, Clone)]
pub struct Range
{
    from: u64,
    to: u64,
}

#[derive(Copy, Clone)]
pub struct RangeSet
{
    ranges: Array<Range>,
    contiguous: u64,
}

impl RangeSet
{
    pub fn set(&mut self, from: u64, to: u64, maybe_delta: *mut i64, modify: bool) -> bool
    {
        if to <= from { panic("invalid range\n") }

        if self.ranges.len == 0
        {
            if let Some(delta) = unsafe { maybe_delta.as_mut() }
            {
                if from >= self.contiguous
                {
                    *delta = (to - from) as i64;
                }
                else if to >= self.contiguous
                {
                    *delta = (to - self.contiguous) as i64;
                }
                else
                {
                    *delta = 0;
                }
            }

            if !modify { return true }

            if from <= self.contiguous
            {
                if to > self.contiguous { self.contiguous = to; }

                return true
            }

            if !self.normalize() { return false }
        }


        let new_range =
        {
            let mut range: Range = unsafe { core::mem::zeroed() };
            range.from = (if let Some(left) = unsafe { self.find(from, true).as_ref() } { left.from } else { from } as *const Range) as u64;
            range.to = (if let Some(right) = unsafe { self.find(to, true).as_ref() } { right.to } else { to } as *const Range) as u64;

            range
        };

        let mut i = 0;

        while i <= self.ranges.len
        {
            if i == self.ranges.len || unsafe { self.ranges.ptr.add(i as usize).read().to } > new_range.from
            {
                if modify
                {
                    if self.ranges.insert(new_range, i).is_null() { return false }

                    i += 1;
                }

                break;
            }

            i += 1;
        }

        let delete_start = i;
        let mut delete_count = 0;
        let mut delete_total = 0;

        for range in self.ranges.get_slice().iter_mut()
        {
            let overlap = (range.from >= new_range.from && range.from <= new_range.to) ||
                (range.to >= new_range.from && range.to <= new_range.to);

            if overlap
            {
                delete_count += 1;
                delete_total = range.to - range.from;
            }
            else { break }
        }

        if modify
        {
            self.ranges.delete_many(delete_start, delete_count);
        }

        self.validate();

        if let Some(delta) = unsafe { maybe_delta.as_mut() }
        {
            *delta = new_range.to as i64 - new_range.from as i64 - delete_total as i64;
        }

        true
    }

    pub fn validate(&self)
    {
        todo!()
    }

    pub fn normalize(&mut self) -> bool
    {
        todo!()
    }

    pub fn find(&self, offset: u64, touching: bool) -> *mut Range
    {
        todo!()
    }
}

pub struct Kernel<'a>
{
    core: Core<'a>,
    scheduler: Scheduler,
    process: Process<'a>,
    physical_allocator: memory::Physical::Allocator<'a>,
    arch: arch::Specific<'a>,
}

pub struct Core<'a>
{
    regions: &'a mut[memory::Region],
    region_commit_count: u64,
    address_space: memory::AddressSpace<'a>,
    heap: memory::Heap,
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
        heap: memory::Heap::default(),
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

        free_or_zeroed_page_bitset: Bitset::default(),
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
        available_critical_event: Event::default(),
        available_low_event: Event::default(),
        available_not_critical_event: Event::default(),
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
