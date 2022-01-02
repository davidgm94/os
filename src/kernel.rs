pub mod arch;
pub mod memory;
pub mod scheduler;
pub mod sync;

use self::scheduler::{Scheduler, Process, Thread};
use self::sync::{Mutex, Spinlock, WriterLock, Event};

extern crate bitflags;
pub use self::bitflags::bitflags;

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
        let _scope_call = ::ScopeCall {
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
    fn read(&self) -> T
    {
        unsafe { core::ptr::read_volatile(&self.value) }
    }

    fn write(&mut self, value: T)
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
    fn read(self) -> T
    {
        unsafe { core::ptr::read_volatile(self.ptr) }
    }

    fn write(self, value: T)
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
        address_space: memory::AddressSpace
        {
            arch: arch::Memory::AddressSpace
            {
                cr3: 0,
            },
            reference_count: 0,
        },
        permissions: scheduler::ProcessPermissions::empty(),
        kind: scheduler::ProcessKind::kernel,
    },
    physical_allocator: memory::Physical::Allocator
    {
        pageframes: &mut[],
        commit_mutex: Mutex::default(),
        pageframe_mutex: Mutex::default(),
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
