#![allow(non_snake_case)]
#![allow(non_camel_case_types)]
#![allow(non_upper_case_globals)]

#![no_std]
#![no_main]

#![feature(asm)]
#![feature(asm_const)]
#![feature(global_asm)]
#![feature(const_maybe_uninit_assume_init)]
#![feature(const_slice_from_raw_parts)]
#![feature(const_default_impls)]
#![feature(const_trait_impl)]
#![feature(const_fn_trait_bound)]
#![feature(const_ptr_offset)]
#![feature(const_option)]
#![feature(const_mut_refs)]
#![feature(maybe_uninit_slice)]
#![feature(untagged_unions)]
#![feature(naked_functions)]
#![feature(variant_count)]
#![feature(link_llvm_intrinsics)]
#![feature(integer_atomics)]
// @TODO: conditional compilation for debug stuff

use core::panic::PanicInfo;
use core::u64::MAX;
use core::ptr::null_mut;
use core::sync::atomic::Ordering;

extern crate bitflags;
use bitflags::bitflags;

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

    pub const fn new(value: T) -> Self
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

    const fn new(ptr: *mut T) -> Self
    {
        Self
        {
            ptr
        }
    }
}

impl<T> const Default for VolatilePointer<T>
{
    fn default() -> Self {
        Self { ptr: null_mut() }
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> !
{
    loop{}
}

enum KernelObjectType
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
    POSIX_file_descriptor,
    pipe,
    embedded_window,
    connection,
    device,
}

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
    len: u64,
    modcheck: bool,
}

impl<T> const Default for LinkedItem<T>
{
    fn default() -> Self {
        Self
        {
            previous: null_mut(),
            next: null_mut(),
            list: null_mut(),
            item: null_mut()
        }
    }
}

impl<T> const Default for LinkedList<T>
{
    fn default() -> Self
    {
        Self
        {
            first: null_mut(),
            last: null_mut(),
            len: 0,
            modcheck: false
        }
    }
}

bitflags!
{
    struct Permissions: u64
    {
        const networking = 1 << 0;
        const process_create = 1 << 1;
        const process_open = 1 << 2;
        const screen_modify = 1 << 3;
        const shutdown = 1 << 4;
        const take_system_snapshot = 1 << 5;
        const get_volume_information = 1 << 6;
        const window_manager = 1 << 7;
        const POSIX_subsystem = 1 << 8;
        const inherit = 1 << 63;
    }
}

pub struct Thread
{
}

use Sync::Mutex;

#[repr(C)]
pub struct CPULocalStorage
{
}

pub mod Sync
{
    use {Volatile, VolatilePointer, Thread, LinkedList, kernel, Arch};

    pub struct Spinlock
    {
        state: Volatile<u8>,
        owner_cpu: Volatile<u8>,
        interrupts_enabled: Volatile<bool>,
    }

    pub struct Mutex
    {
        owner: VolatilePointer<Thread>,
        blocked_threads: LinkedList<Thread>,
    }

    impl Spinlock
    {
        pub fn acquire(&mut self)
        {
            if unsafe { kernel.scheduler.panic.read() }  { return }

            let interrupts_enabled = unsafe { Arch::interrupts_are_enabled() };
            unsafe { Arch::interrupts_disable() };
        }
    }

    impl Mutex
    {
    }

    impl const Default for Mutex
    {
        fn default() -> Self
        {
            Self
            {
                owner: VolatilePointer::<Thread>::default(),
                blocked_threads: LinkedList::<Thread>::default(),
            }
        }
    }

}

pub mod Memory
{
    use {Volatile, bitflags::bitflags, Sync::Mutex, null_mut};

    pub union HeapRegionUse
    {
        allocation_size: u64,
        region_list_next: *mut HeapRegion,
    }

    pub struct HeapRegion
    {
        next_or_size: u16,

        previous: u16,
        offset: u16,

        used: u16,
        use_u: HeapRegionUse,
    }

    pub struct Heap
    {
        mutex: Mutex,
        regions: [*mut HeapRegion; 12],
        allocation_count: Volatile<u64>,
        size: Volatile<u64>,
        block_count: Volatile<u64>,
        blocks: [u64; 16],
        cannot_validate: bool,

    }

    impl Heap
    {
        pub const fn zeroed() -> Self
        {
            Self
            {
                mutex: Mutex::default(),
                regions: [null_mut(); 12],
                allocation_count: Volatile::<u64>::new(0),
                size: Volatile::<u64>::new(0),
                block_count: Volatile::<u64>::new(0),
                blocks: [0;16],
                cannot_validate: false
            }
        }
    }

    impl const Default for Heap
    {
        fn default() -> Self
        {
            Self
            {
                mutex: Mutex::default(),
                regions: [null_mut(); 12],
                allocation_count: Volatile::<u64>::new(0),
                size: Volatile::<u64>::new(0),
                block_count: Volatile::<u64>::new(0),
                blocks: [0;16],
                cannot_validate: false
            }
        }
    }

    pub struct Space
    {
    }

    impl const Default for Space
    {
        fn default() -> Self
        {
            Self
            {
            }
        }
    }

    bitflags!
    {
        pub struct OpenFlags : u64
        {
            const fail_if_found = 0x1000;
            const fail_if_not_found = 0x2000;
        }
    }
}

pub const stack_size: usize = 0x4000;
#[repr(align(0x10))]
pub struct Stack
{
    memory: [u8; stack_size],
}
#[no_mangle]
#[link_section = ".bss"]
pub static mut stack: Stack = Stack { memory: [0; stack_size] };

pub const idt_size: u16 = 0x1000;
#[repr(align(0x10))]
pub struct IDT
{
    memory: [u8; idt_size as usize],
}
#[no_mangle]
#[link_section = ".bss"]
pub static mut idt_data: IDT = IDT { memory: [0; idt_size as usize] };

pub const cpu_local_storage_size: usize = 0x2000;
#[repr(align(0x10))]
pub struct CPULocalStorageMemory
{
    memory: [u8; cpu_local_storage_size],
}
#[no_mangle]
#[link_section = ".bss"]
pub static mut cpu_local_storage: CPULocalStorageMemory = CPULocalStorageMemory { memory: [0; cpu_local_storage_size] };

global_asm!(
    ".extern idt_data", 
    ".section .data",
    ".global idt",
    "idt:",
    "idt_base: .short {idt_base}",
    "idt_limit: .quad idt_data",
    idt_base = const idt_size - 1,
);

#[no_mangle]
#[link_section = ".data"]
pub static mut cpu_local_storage_index: u64 = 0;

#[no_mangle]
#[link_section = ".data"]
pub static mut paging_NXE_support: u32 = 0;

#[no_mangle]
#[link_section = ".data"]
pub static mut paging_PCID_support: u32 = 0;

#[no_mangle]
#[link_section = ".data"]
pub static mut paging_SMEP_support: u32 = 0;

#[no_mangle]
#[link_section = ".data"]
pub static mut paging_TCE_support: u32 = 0;

#[no_mangle]
#[link_section = ".data"]
pub static mut simd_SSE3_support: u32 = 0;

#[no_mangle]
#[link_section = ".data"]
pub static mut simd_SSSE3_support: u32 = 0;

#[repr(C, align(0x10))]
pub struct GDTR(u64, u64);

#[no_mangle]
#[link_section = ".data"]
pub static mut gdtr: GDTR = GDTR { 0: 0, 1: 0 };

#[no_mangle]
#[link_section = ".data"]
pub static mut kernel_size: u32 = 0;

#[no_mangle]
#[link_section = ".data"]
pub static mut bootloader_ID: u32 = 0;

pub mod Arch
{
    global_asm!(
        ".extern kernel_size",

        ".section .text",
        ".global _start",

        "_start:",
        "mov [kernel_size], edx",
        "xor rdx, rdx",

        "mov rax, 0x63",
        "mov fs, ax",
        "mov gs, ax",

        // Save bootloader ID
        "mov rax, bootloader_ID",
        "mov [rax], rsi",
    );

    extern "C" { pub fn interrupts_are_enabled() -> bool; }
    extern "C" { pub fn interrupts_disable(); }
    extern "C" { pub fn interrupts_enable(); }

    global_asm!(
        ".global interrupts_are_enabled",
        ".global interrupts_disable",
        ".global interrupts_enable",

        "interrupts_are_enabled:",
        "pushf",
        "pop rax",
        "and rax, 0x200",
        "shr rax, 9",
        
        "mov rdx, cr8",
        "cmp rdx, 0",
        "je .done",
        "mov rax, 0",
        ".done:",
        "ret",

        "interrupts_disable:",
        "mov rax, 14",
        "mov cr8, rax",
        "sti",
        "ret",

        "interrupts_enable:",
        "mov rax, 0",
        "mov cr8, rax",
        "sti",
        "ret",
    );
}

pub struct Scheduler
{
    started: Volatile<bool>,
    panic: Volatile<bool>,
    shutdown: Volatile<bool>
}

impl const Default for Scheduler
{
    fn default() -> Self
    {
        Self
        {
            started: Volatile::<bool>::new(false),
            panic: Volatile::<bool>::new(false),
            shutdown: Volatile::<bool>::new(false),
        }
    }
}

pub mod Cache
{
    use bitflags::bitflags;

    bitflags!
    {
        pub struct Access: u32
        {
            const map = 1 << 0;
            const read = 1 << 1;
            const write = 1 << 2;
            const write_back = 1 << 3;
        }
    }
}

pub struct Kernel
{
    scheduler: Scheduler,
    core_heap: Memory::Heap,
    fixed_heap: Memory::Heap,
    address_space: Memory::Space,
    core_address_space: Memory::Space,
}

pub static mut kernel: Kernel = Kernel
{
    scheduler: Scheduler::default(),
    core_heap: Memory::Heap::default(),
    fixed_heap: Memory::Heap::default(),
    address_space: Memory::Space::default(),
    core_address_space: Memory::Space::default(),
};
