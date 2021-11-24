#![no_std]
#![no_main]

#![feature(const_maybe_uninit_assume_init)]
#![feature(const_slice_from_raw_parts)]
#![feature(const_default_impls)]
#![feature(const_trait_impl)]
#![feature(const_ptr_offset)]
#![feature(const_option)]
#![feature(const_mut_refs)]
#![feature(maybe_uninit_slice)]
#![feature(untagged_unions)]
#![feature(variant_count)]
#![feature(link_llvm_intrinsics)]
#![feature(integer_atomics)]
// @TODO: conditional compilation for debug stuff

extern crate bitflags;

use core::panic::PanicInfo;
use core::ptr::null_mut;
use core::sync::atomic::Ordering;

mod arch;
mod drivers;
mod memory;
mod scheduler;
mod synchronization;

use drivers::pci;
use scheduler::{Scheduler, Process, ProcessKind};
use synchronization::{Mutex, Spinlock};

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

extern
{
    #[link_name = "llvm.return_address"]
    pub fn return_address() -> u64;
}

#[panic_handler]
pub extern "C" fn rust_kernel_panic(_info: &PanicInfo) -> ! {
    loop{}
}

pub extern "C" fn drivers_init()
{
    pci::Controller::setup();
}


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
        unsafe { core::ptr::write_volatile(&mut self.value, value) };
    }

    const fn new(value: T) -> Self
    {
        Self
        {
            value
        }
    }
}

struct VolatilePointer<T>
{
    ptr: *mut T,
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
}

struct LinkedItem<T>
{
    previous: *mut Self,
    next: *mut Self,
    this: *mut T,
    list: *mut LinkedList<T>
}

struct LinkedList<T>
{
    first: *mut LinkedItem<T>,
    last: *mut LinkedItem<T>,
    count: u64,
    modcheck: bool,
}

impl<T> LinkedItem<T>
{
    fn remove_from_list(&mut self)
    {
        unsafe { self.list.as_mut() }.expect("Item is not in the list").remove(self);
    }
}

impl<T> LinkedList<T>
{
    fn insert_at_start(&mut self, item: &mut LinkedItem<T>)
    {
        if cfg!(debug_assertions)
        {
            if self.modcheck { panic() }
            self.modcheck = true;
        }

        if item.list as *const _ == self as *const _ { panic() }
        if !item.list.is_null() { panic() }

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
        self.validate();
        if cfg!(debug_assertions) { self.modcheck = false }
    }

    fn insert_at_end(&mut self, item: &mut LinkedItem<T>)
    {
        if cfg!(debug_assertions)
        {
            if self.modcheck { panic() }
            self.modcheck = true;
        }

        if item.list as *const _ == self as *const _ { panic() }
        if !item.list.is_null() { panic() }

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
        self.validate();
        if cfg!(debug_assertions) { self.modcheck = false }
    }

    fn insert_before(&mut self, item: &mut LinkedItem<T>, before: &mut LinkedItem<T>)
    {
        if cfg!(debug_assertions)
        {
            if self.modcheck { panic() }
            self.modcheck = true;
        }

        if item.list as *const _ == self as *const _ { panic() }
        if !item.list.is_null() { panic() }

        if before as *mut _ != self.last
        {
            item.previous = before.previous;
            unsafe { item.previous.as_mut().unwrap_unchecked().next = item }
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
        self.validate();
        if cfg!(debug_assertions) { self.modcheck = false }
    }

    fn remove(&mut self, item: &mut LinkedItem<T>)
    {
        if cfg!(debug_assertions)
        {
            if self.modcheck { panic() }
            self.modcheck = true;
            
        }


        if unsafe { item.list.as_mut() }.expect("Item already removed") as *const _ != self as *const _ { panic() }

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

        item.next = null_mut();
        item.previous = null_mut();
        self.count -= 1;

        self.validate();
        if cfg!(debug_assertions) { self.modcheck = false }
    }

    fn validate(&self)
    {
        if cfg!(debug_assertions)
        {
            match self.count
            {
                0 => if !self.first.is_null() || !self.last.is_null() { panic() }
                1 =>
                {
                    let last_neq_first = self.first != self.last;
                    if last_neq_first { panic() }

                    let first = unsafe {self.first.as_ref() }.expect("Expected first item");
                    if !first.previous.is_null() || !first.next.is_null() || first.list as *const _ != self as *const _ || first.this.is_null()
                    {
                        panic()
                    }
                }
                _ =>
                {
                    if self.first == self.last { panic() }
                    if !(unsafe { self.first.as_ref().unwrap_unchecked()}.previous.is_null()) { panic() }
                    if !(unsafe { self.last.as_ref().unwrap_unchecked()}.next.is_null()) { panic() }

                    {
                        let mut it = unsafe {self.first.as_ref().unwrap_unchecked()} ;
                        let mut index = self.count;

                        loop
                        {
                            index -= 1;
                            if index == 0 { break }

                            if it.next as *const _ == it as *const _ { panic() }
                            if it.list as *const _ != self as *const _ { panic() }
                            if it.this.is_null() { panic() }

                            it = unsafe { it.next.as_ref().unwrap_unchecked()};
                        }

                        if it as *const _ != self.last { panic() }
                    }

                    {
                        let mut it = unsafe {self.last.as_ref().unwrap_unchecked()} ;
                        let mut index = self.count;

                        loop
                        {
                            index -= 1;
                            if index == 0 { break }

                            if it.previous as *const _ == it as *const _ { panic() }

                            it = unsafe { it.previous.as_ref().unwrap_unchecked()};
                        }

                        if it as *const _ != self.first { panic() }
                    }
                }
            }
        }
    }
}

enum ObjectKind
{
    could_not_resolve_handle,
    none,
    process,
    thread,
    window,
    shared_memory,
    node,
    event,
    constant_buffer,
    pipe,
    embedded_window,
    connection,
    device,
}

impl Default for ObjectKind
{
    fn default() -> Self
    {
        return ObjectKind::none;
    }
}

#[derive(Default)]
pub struct Handle
{
    object: u64,
    flags: u32,
    kind: ObjectKind,
}

type HandleTableL2 = [Handle; 256];

pub struct HandleTableL1
{
    t: [u64;256],
    u: [u16;256],
}

impl Default for HandleTableL1
{
    fn default() -> Self {
        Self { t: [0;256], u: [0;256] }
    }
}

//#[derive(Default)]
pub struct HandleTable
{
    l1: HandleTableL1,
    lock: Mutex,
    process: u64,
    destroyed: bool,
    handle_count: u32,
}

impl HandleTable
{
    const fn init() -> Self
    {
        return HandleTable
        {
            l1: HandleTableL1
            {
                t: [0;256],
                u: [0;256],
            },
            lock: Mutex::zeroed(),
            process: 0,
            destroyed: false,
            handle_count: 1,
        };
    }
}

pub static mut kernel: Kernel = Kernel
{
    scheduler: Scheduler
    {
        dispatch_spinlock: Spinlock::zeroed(),
        shutdown: false,
        panic: false,
        started: false,
    },
    process: Process
    {
        address_space: memory::AddressSpace::default(),
        handle_table: HandleTable::init(),
        // threads
        // threads mutex
        //
        // executable node
        // executable name
        // data
        permissions: core::u64::MAX,
        // creationflags
        kind: ProcessKind::kernel,

        id: 0,
        all_id: 0,
        handles: Volatile::<u64> { value: 1 },

        // crash mutex
        // crash reason
        crashed: false,

        all_threads_terminated: false,
        block_shutdown: false,
        prevent_new_threads: false,
        exit_status: 0,
        // killed event
        //

        executable_state: 0,
        executable_start_request: false,
        // executable load attempt complete
        // executable main thread

        cpu_time_slices: 0,
        idle_time_slices: 0,
    },
    physical_allocator: memory::PhysicalAllocator
    {
        page_frames: &mut[],
        page_frame_mutex: Mutex::zeroed(),
        page_frame_database_initialized: false
    },
    // @INFO: this should be inmutable but Rust doesn't let us initialize the slice to the values we
    core_regions:  &mut [],
    core_address_space: memory::AddressSpace
    {
        arch: arch::AddressSpace::zeroed(),
        reference_count: Volatile::<u32> { value: 0 }
    },
};

pub fn panic() -> !
{
    loop{}
}

pub struct Kernel<'a>
{
    scheduler: Scheduler,
    process: Process,
    physical_allocator: memory::PhysicalAllocator<'a>,
    core_regions: &'a mut[memory::Region],
    core_address_space: memory::AddressSpace,
}

impl<'a> Kernel<'a>
{
    fn setup(&mut self)
    {
        // The kernel process is statically initialized, so we just need to increment the process id
        // count
        let _ = scheduler::NEXT_PROCESS_ID.fetch_add(1, Ordering::SeqCst);
        self.core_regions = unsafe { core::slice::from_raw_parts_mut(0xFFFF8001F0000000 as *mut memory::Region, 1) };
        if unsafe { self.core_regions[0].cnc.core.used } { panic() }
        arch::Memory::init(self);
        unimplemented!();
    }
}

#[no_mangle]
pub extern "C" fn KernelInitialise()
{
    unsafe { kernel.setup() }
}
