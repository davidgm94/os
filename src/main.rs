#![allow(non_snake_case)]
#![allow(non_camel_case_types)]
#![allow(non_upper_case_globals)]
#![allow(unsupported_naked_functions)]

#![no_std]
#![no_main]

#![feature(untagged_unions)]
#![feature(naked_functions)]
#![feature(variant_count)]
#![feature(link_llvm_intrinsics)]
#![feature(integer_atomics)]
#![feature(core_intrinsics)]

#![feature(asm_const)]
#![feature(asm_sym)]

#![feature(const_maybe_uninit_assume_init)]
#![feature(const_slice_from_raw_parts)]
#![feature(const_default_impls)]
#![feature(const_trait_impl)]
#![feature(const_fn_trait_bound)]
#![feature(const_fn_fn_ptr_basics)]
#![feature(const_ptr_offset)]
#![feature(const_ptr_offset_from)]
#![feature(const_option)]
#![feature(const_mut_refs)]
#![feature(maybe_uninit_slice)]
// @TODO: conditional compilation for debug stuff

use core::panic::PanicInfo;
use core::u64;
use core::ptr::null_mut;
use core::arch::{asm, global_asm};
use core::mem::{size_of, transmute};

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

#[inline(never)]
#[panic_handler]
fn panic(info: &PanicInfo) -> !
{
    _foo_panic(info);
    loop{}
}

#[inline(never)]
fn _foo_panic(_: &PanicInfo)
{
}

#[allow(non_camel_case_types)]
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
            unimplemented!();
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

#[repr(C)]
    pub struct RegionDescriptor
    {
        pub base_address: u64,
        pub page_count: u64,
    }

    pub type PhysicalRegion = RegionDescriptor;

    pub struct Region
    {
        base_address: u64,
        page_count: u64,
    }

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




pub mod Arch
{
    use kernel;
    use transmute;
    use {asm, global_asm};
    use size_of;
    use Memory;

    pub const core_memory_regions_start: u64 = 0xFFFF8001F0000000;
    pub const core_memory_region_count: u64 = (0xFFFF800200000000 - 0xFFFF8001F0000000) / size_of::<Memory::Region>() as u64;
    pub const kernel_address_space_start: u64 = 0xFFFF900000000000;
    pub const kernel_address_space_size: u64 = 0xFFFFF00000000000 - 0xFFFF900000000000;
    pub const module_memory_start: u64 = 0xFFFFFFFF90000000;
    pub const module_memory_size: u64 = 0xFFFFFFFFC0000000 - 0xFFFFFFFF90000000;
    pub const core_address_space_start: u64 = 0xFFFF800100000000;
    pub const core_address_space_size: u64 = 0xFFFF8001F0000000 - 0xFFFF800100000000;
    pub const user_address_space_start: u64 = 0x100000000000;
    pub const user_address_space_size: u64 = 0xF00000000000 - 0x100000000000;
    pub const low_memory_map_start: u64 = 0xFFFFFE0000000000;
    pub const low_memory_limit: u64 = 0x100000000; // The first 4GB is mapped here.

    pub const page_size: u16 = 0x1000;
    pub const page_bit_count: u8 = 12;

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
    pub const idt_entry_count: usize = 0x1000 / size_of::<IDTEntry>();

    #[derive(Clone, Copy)]
    #[repr(C, align(0x10))]
    pub struct IDTEntry
    {
        foo1: u16,
        foo2: u16,
        foo3: u16,
        foo4: u16,
        handler: u64,
    }

    impl const Default for IDTEntry
    {
        fn default() -> Self
        {
            Self
            {
                foo1: 0,
                foo2: 0,
                foo3: 0,
                foo4: 0,
                handler: 0,
            }
        }
    }

    impl IDTEntry
    {
        const fn new(handler: InterruptHandlerFn) -> Self
        {
            let handler_raw_address = unsafe { transmute::<InterruptHandlerFn, u64>(handler) };
            let foo4 = handler_raw_address >> 16;
            let handler_address = foo4 >> 16;

            Self
            {
                foo1: handler_raw_address as u16,
                foo2: 0x48,
                foo3: 0x8e00,
                foo4: foo4 as u16,
                handler: handler_address,
            }
        }
    }

    #[repr(align(0x10))]
    pub struct IDT
    {
        entries: [IDTEntry; idt_entry_count],
    }

    impl IDT
    {
        #[inline(always)]
        const fn register_new<const interrupt_number: u64, const error_code: bool>(&mut self)
        {
            let handler: InterruptHandlerFn =
                if error_code { InterruptHandler::<interrupt_number>::interrupt_handler_prologue_error_code }
                else { InterruptHandler::<interrupt_number>::interrupt_handler_prologue };
            self.entries[interrupt_number as usize] = IDTEntry::new(handler);
        }
    }

    #[no_mangle]
    #[link_section = ".bss"]
    pub static mut idt_data: IDT = IDT { entries: [IDTEntry::default(); idt_entry_count] };

    #[repr(align(0x10))]
    pub struct CPULocalStorageMemory
    {
        memory: [u8; cpu_local_storage_size],
    }

    pub const cpu_local_storage_size: usize = 0x2000;
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

    #[repr(C, packed)]
    pub struct GDTR
    {
        limit: u16,
        base: u64,
    }

    impl GDTR
    {
        #[inline(always)]
        pub fn save(&mut self)
        {
            unsafe { asm!("sgdt [{}]", in(reg) self, options(nostack, preserves_flags)) };
        }
    }

    #[repr(C, packed)]
    pub  struct IDTR
    {
        limit: u16,
        base: u64,
    }

    impl IDTR
    {
        #[inline(always)]
        pub fn load(&self)
        {
            unsafe { asm!("lidt [{}]", in(reg) self, options(readonly, nostack, preserves_flags)) }
        }
    }

    #[allow(non_snake_case)]
    pub struct PagingSupport
    {
        NXE: u32,
        PCID: u32,
        SMEP: u32,
        TCE: u32,
    }

    impl const Default for PagingSupport
    {
        fn default() -> Self
        {
            Self
            {
                NXE: 1,
                PCID: 1,
                SMEP: 1,
                TCE: 1,
            }
        }
    }

    #[allow(non_snake_case)]
    pub struct SIMDSupport
    {
        SSE3: u32,
        SSSE3: u32,
    }

    impl const Default for SIMDSupport
    {
        fn default() -> Self
        {
            Self
            {
                SSE3: 1,
                SSSE3: 1,
            }
        }
    }

    #[allow(non_snake_case)]
    pub struct CPUFeatures
    {
        paging: PagingSupport,
        SIMD: SIMDSupport,
    }

    impl const Default for CPUFeatures
    {
        fn default() -> Self
        {
            Self
            {
                paging: Default::default(),
                SIMD: Default::default(),
            }
        }
    }

    pub struct Specific<'a>
    {
        physical_memory: PhysicalMemory<'a>,
        bootloader: Bootloader,
        cpu_features: CPUFeatures,
        installation_id: [u64;2],
        cpu_local_storage_index: u64,
        size: u32,
        gdtr: GDTR,
        idtr: IDTR,
    }

    impl<'a> const Default for Specific<'a>
    {
        fn default() -> Self
        {
            Self
            {
                physical_memory: Default::default(),
                bootloader: Default::default(),
                cpu_features: Default::default(),
                installation_id: [0; 2],
                cpu_local_storage_index: 0,
                size: 0,
                gdtr: GDTR { limit: 0, base: 0 },
                idtr: IDTR { limit: 0, base: 0 },
            }
        }
    }

    fn install_interrupt_handlers()
    {
        unsafe
        {
            idt_data.register_new::<0,   false>();
            idt_data.register_new::<1,   false>();
            idt_data.register_new::<2,   false>();
            idt_data.register_new::<3,   false>();
            idt_data.register_new::<4,   false>();
            idt_data.register_new::<5,   false>();
            idt_data.register_new::<6,   false>();
            idt_data.register_new::<7,   false>();
            idt_data.register_new::<8,   true>();
            idt_data.register_new::<9,   false>();
            idt_data.register_new::<10,  true>();
            idt_data.register_new::<11,  true>();
            idt_data.register_new::<12,  true>();
            idt_data.register_new::<13,  true>();
            idt_data.register_new::<14,  true>();
            idt_data.register_new::<15,  false>();
            idt_data.register_new::<16,  false>();
            idt_data.register_new::<17,  true>();
            idt_data.register_new::<18,  false>();
            idt_data.register_new::<19,  false>();
            idt_data.register_new::<20,  false>();
            idt_data.register_new::<21,  false>();
            idt_data.register_new::<22,  false>();
            idt_data.register_new::<23,  false>();
            idt_data.register_new::<24,  false>();
            idt_data.register_new::<25,  false>();
            idt_data.register_new::<26,  false>();
            idt_data.register_new::<27,  false>();
            idt_data.register_new::<28,  false>();
            idt_data.register_new::<29,  false>();
            idt_data.register_new::<30,  false>();
            idt_data.register_new::<31,  false>();
            idt_data.register_new::<32,  false>();
            idt_data.register_new::<33,  false>();
            idt_data.register_new::<34,  false>();
            idt_data.register_new::<35,  false>();
            idt_data.register_new::<36,  false>();
            idt_data.register_new::<37,  false>();
            idt_data.register_new::<38,  false>();
            idt_data.register_new::<39,  false>();
            idt_data.register_new::<40,  false>();
            idt_data.register_new::<41,  false>();
            idt_data.register_new::<42,  false>();
            idt_data.register_new::<43,  false>();
            idt_data.register_new::<44,  false>();
            idt_data.register_new::<45,  false>();
            idt_data.register_new::<46,  false>();
            idt_data.register_new::<47,  false>();
            idt_data.register_new::<48,  false>();
            idt_data.register_new::<49,  false>();
            idt_data.register_new::<50,  false>();
            idt_data.register_new::<51,  false>();
            idt_data.register_new::<52,  false>();
            idt_data.register_new::<53,  false>();
            idt_data.register_new::<54,  false>();
            idt_data.register_new::<55,  false>();
            idt_data.register_new::<56,  false>();
            idt_data.register_new::<57,  false>();
            idt_data.register_new::<58,  false>();
            idt_data.register_new::<59,  false>();
            idt_data.register_new::<60,  false>();
            idt_data.register_new::<61,  false>();
            idt_data.register_new::<62,  false>();
            idt_data.register_new::<63,  false>();
            idt_data.register_new::<64,  false>();
            idt_data.register_new::<65,  false>();
            idt_data.register_new::<66,  false>();
            idt_data.register_new::<67,  false>();
            idt_data.register_new::<68,  false>();
            idt_data.register_new::<69,  false>();
            idt_data.register_new::<70,  false>();
            idt_data.register_new::<71,  false>();
            idt_data.register_new::<72,  false>();
            idt_data.register_new::<73,  false>();
            idt_data.register_new::<74,  false>();
            idt_data.register_new::<75,  false>();
            idt_data.register_new::<76,  false>();
            idt_data.register_new::<77,  false>();
            idt_data.register_new::<78,  false>();
            idt_data.register_new::<79,  false>();
            idt_data.register_new::<80,  false>();
            idt_data.register_new::<81,  false>();
            idt_data.register_new::<82,  false>();
            idt_data.register_new::<83,  false>();
            idt_data.register_new::<84,  false>();
            idt_data.register_new::<85,  false>();
            idt_data.register_new::<86,  false>();
            idt_data.register_new::<87,  false>();
            idt_data.register_new::<88,  false>();
            idt_data.register_new::<89,  false>();
            idt_data.register_new::<90,  false>();
            idt_data.register_new::<91,  false>();
            idt_data.register_new::<92,  false>();
            idt_data.register_new::<93,  false>();
            idt_data.register_new::<94,  false>();
            idt_data.register_new::<95,  false>();
            idt_data.register_new::<96,  false>();
            idt_data.register_new::<97,  false>();
            idt_data.register_new::<98,  false>();
            idt_data.register_new::<99,  false>();
            idt_data.register_new::<100, false>();
            idt_data.register_new::<101, false>();
            idt_data.register_new::<102, false>();
            idt_data.register_new::<103, false>();
            idt_data.register_new::<104, false>();
            idt_data.register_new::<105, false>();
            idt_data.register_new::<106, false>();
            idt_data.register_new::<107, false>();
            idt_data.register_new::<108, false>();
            idt_data.register_new::<109, false>();
            idt_data.register_new::<110, false>();
            idt_data.register_new::<111, false>();
            idt_data.register_new::<112, false>();
            idt_data.register_new::<113, false>();
            idt_data.register_new::<114, false>();
            idt_data.register_new::<115, false>();
            idt_data.register_new::<116, false>();
            idt_data.register_new::<117, false>();
            idt_data.register_new::<118, false>();
            idt_data.register_new::<119, false>();
            idt_data.register_new::<120, false>();
            idt_data.register_new::<121, false>();
            idt_data.register_new::<122, false>();
            idt_data.register_new::<123, false>();
            idt_data.register_new::<124, false>();
            idt_data.register_new::<125, false>();
            idt_data.register_new::<126, false>();
            idt_data.register_new::<127, false>();
            idt_data.register_new::<128, false>();
            idt_data.register_new::<129, false>();
            idt_data.register_new::<130, false>();
            idt_data.register_new::<131, false>();
            idt_data.register_new::<132, false>();
            idt_data.register_new::<133, false>();
            idt_data.register_new::<134, false>();
            idt_data.register_new::<135, false>();
            idt_data.register_new::<136, false>();
            idt_data.register_new::<137, false>();
            idt_data.register_new::<138, false>();
            idt_data.register_new::<139, false>();
            idt_data.register_new::<140, false>();
            idt_data.register_new::<141, false>();
            idt_data.register_new::<142, false>();
            idt_data.register_new::<143, false>();
            idt_data.register_new::<144, false>();
            idt_data.register_new::<145, false>();
            idt_data.register_new::<146, false>();
            idt_data.register_new::<147, false>();
            idt_data.register_new::<148, false>();
            idt_data.register_new::<149, false>();
            idt_data.register_new::<150, false>();
            idt_data.register_new::<151, false>();
            idt_data.register_new::<152, false>();
            idt_data.register_new::<153, false>();
            idt_data.register_new::<154, false>();
            idt_data.register_new::<155, false>();
            idt_data.register_new::<156, false>();
            idt_data.register_new::<157, false>();
            idt_data.register_new::<158, false>();
            idt_data.register_new::<159, false>();
            idt_data.register_new::<160, false>();
            idt_data.register_new::<161, false>();
            idt_data.register_new::<162, false>();
            idt_data.register_new::<163, false>();
            idt_data.register_new::<164, false>();
            idt_data.register_new::<165, false>();
            idt_data.register_new::<166, false>();
            idt_data.register_new::<167, false>();
            idt_data.register_new::<168, false>();
            idt_data.register_new::<169, false>();
            idt_data.register_new::<170, false>();
            idt_data.register_new::<171, false>();
            idt_data.register_new::<172, false>();
            idt_data.register_new::<173, false>();
            idt_data.register_new::<174, false>();
            idt_data.register_new::<175, false>();
            idt_data.register_new::<176, false>();
            idt_data.register_new::<177, false>();
            idt_data.register_new::<178, false>();
            idt_data.register_new::<179, false>();
            idt_data.register_new::<180, false>();
            idt_data.register_new::<181, false>();
            idt_data.register_new::<182, false>();
            idt_data.register_new::<183, false>();
            idt_data.register_new::<184, false>();
            idt_data.register_new::<185, false>();
            idt_data.register_new::<186, false>();
            idt_data.register_new::<187, false>();
            idt_data.register_new::<188, false>();
            idt_data.register_new::<189, false>();
            idt_data.register_new::<190, false>();
            idt_data.register_new::<191, false>();
            idt_data.register_new::<192, false>();
            idt_data.register_new::<193, false>();
            idt_data.register_new::<194, false>();
            idt_data.register_new::<195, false>();
            idt_data.register_new::<196, false>();
            idt_data.register_new::<197, false>();
            idt_data.register_new::<198, false>();
            idt_data.register_new::<199, false>();
            idt_data.register_new::<200, false>();
            idt_data.register_new::<201, false>();
            idt_data.register_new::<202, false>();
            idt_data.register_new::<203, false>();
            idt_data.register_new::<204, false>();
            idt_data.register_new::<205, false>();
            idt_data.register_new::<206, false>();
            idt_data.register_new::<207, false>();
            idt_data.register_new::<208, false>();
            idt_data.register_new::<209, false>();
            idt_data.register_new::<210, false>();
            idt_data.register_new::<211, false>();
            idt_data.register_new::<212, false>();
            idt_data.register_new::<213, false>();
            idt_data.register_new::<214, false>();
            idt_data.register_new::<215, false>();
            idt_data.register_new::<216, false>();
            idt_data.register_new::<217, false>();
            idt_data.register_new::<218, false>();
            idt_data.register_new::<219, false>();
            idt_data.register_new::<220, false>();
            idt_data.register_new::<221, false>();
            idt_data.register_new::<222, false>();
            idt_data.register_new::<223, false>();
            idt_data.register_new::<224, false>();
            idt_data.register_new::<225, false>();
            idt_data.register_new::<226, false>();
            idt_data.register_new::<227, false>();
            idt_data.register_new::<228, false>();
            idt_data.register_new::<229, false>();
            idt_data.register_new::<230, false>();
            idt_data.register_new::<231, false>();
            idt_data.register_new::<232, false>();
            idt_data.register_new::<233, false>();
            idt_data.register_new::<234, false>();
            idt_data.register_new::<235, false>();
            idt_data.register_new::<236, false>();
            idt_data.register_new::<237, false>();
            idt_data.register_new::<238, false>();
            idt_data.register_new::<239, false>();
            idt_data.register_new::<240, false>();
            idt_data.register_new::<241, false>();
            idt_data.register_new::<242, false>();
            idt_data.register_new::<243, false>();
            idt_data.register_new::<244, false>();
            idt_data.register_new::<245, false>();
            idt_data.register_new::<246, false>();
            idt_data.register_new::<247, false>();
            idt_data.register_new::<248, false>();
            idt_data.register_new::<249, false>();
            idt_data.register_new::<250, false>();
            idt_data.register_new::<251, false>();
            idt_data.register_new::<252, false>();
            idt_data.register_new::<253, false>();
            idt_data.register_new::<254, false>();
            idt_data.register_new::<255, false>();
        }
    }

    #[no_mangle]
    #[naked]
    extern "C" fn CPU_ready()
    {
        unsafe
        {
            asm!(
                "mov rdi, 1",
                "call {0}",
                "jmp {1}",
                sym next_timer,
                sym CPU_idle,
            );
        }
        unreachable!();
    }

    extern "C" fn CPU_idle()
    {
        unimplemented!();
    }

    pub fn next_timer(_: u64)
    {
        unimplemented!();
    }

    pub struct MSR(u32);

    impl MSR
    {
        #[inline(always)]
        pub const fn new(register: u32) -> Self
        {
            Self(register)
        }

        #[inline(always)]
        pub fn read(self) -> (u32, u32)
        {
            let (high, low): (u32, u32);
            unsafe
            {
                asm!(
                    "rdmsr",
                    in("ecx") self.0,
                    out("eax") low, out("edx") high,
                    options(nomem, nostack, preserves_flags),
                );
            }

            (low, high)
        }

        #[inline(always)]
        pub fn write(self, low: u32, high: u32)
        {
            unsafe
            {
                asm!(
                    "wrmsr",
                    in("ecx") self.0,
                    in("eax") low, in("edx") high,
                    options(nostack, preserves_flags)
                );
            }
        }
    }

    // Extended Feature Enable Register
    pub const EFER: MSR = MSR::new(0xc0000080);
    pub const STAR: MSR = MSR::new(0xc0000081);
    pub const LSTAR: MSR = MSR::new(0xc0000082);
    pub const SFMASK: MSR = MSR::new(0xc0000084);
    pub const FS_BASE: MSR = MSR::new(0xc0000100);
    pub const GS_BASE: MSR = MSR::new(0xc0000101);

    use core::arch::x86_64::__cpuid;

    impl<'a> Specific<'a>
    {
        pub fn early_setup(&mut self, early_kernel_info: EarlyKernelInfo)
        {
            self.size = early_kernel_info.size;
            self.bootloader.id = early_kernel_info.bootloader.id;

            let standard_acpi = early_kernel_info.bootloader.offset != 0;
            if !standard_acpi
            {
                unsafe { (0x7fe8 as *mut u64).write(early_kernel_info.bootloader.offset) };
            }

            self.bootloader.offset = early_kernel_info.bootloader.offset;

            unsafe
            {
                let installation_id_offset = early_kernel_info.bootloader.offset + 0x7ff0;
                self.installation_id[0] = *(installation_id_offset as *mut u64);
                self.installation_id[1] = *((installation_id_offset as usize + size_of::<u64>()) as *mut u64);

                *(0xFFFFFF7FBFDFE000 as *mut u64) = 0;
            }
            CR3::flush();

            // @TODO: setup serial
            PIC::disable();
            self.physical_memory.setup(self.bootloader.offset);
            install_interrupt_handlers();
            self.gdtr.save();
            self.cpu_setup_1();
        }

        pub fn cpu_setup_1(&mut self)
        {
            // Enable no-execute support, if available
            {
                let cpuid_result = unsafe { __cpuid(0x80000001) };
                let mask = (cpuid_result.edx & (1 << 20)) >> 20;
                self.cpu_features.paging.NXE &= mask;
                if mask != 0
                {
                    let mut efer = EFER.read();
                    efer.0 |= 1 << 11;
                    EFER.write(efer.0, efer.1);
                }
            }

            // x87 FPU
            {
                #[allow(named_asm_labels)]
                unsafe
                {
                    asm!(
                        "fninit",
                        "mov rax, .cw",
                        "fldcw [rax]",
                        "jmp .cwa",
                        ".cw:",
                        ".long 0x037a",
                        ".cwa:",
                    );
                }
            }

            // Enable SMEP support, if available
            // This prevents the kernel from executing userland pages
            // TODO: test this: neither Bochs or Qemu seem to support it
            {
                let mut cpuid_result = unsafe { __cpuid(0) };
                if cpuid_result.eax >= 7
                {
                    cpuid_result = unsafe { __cpuid(7) } ;
                    let smep = (cpuid_result.ebx & (1 << 7)) >> 7;
                    self.cpu_features.paging.SMEP &= smep;

                    if smep != 0
                    {
                        self.cpu_features.paging.SMEP = (self.cpu_features.paging.SMEP & 0xffff0000) | 2;
                        CR4::write(CR4::read() | (1 << 20));
                    }
                }
            }

            // Enable PCID support, if available
            {
                let cpuid_result = unsafe { __cpuid(1) };
                let pcid = (cpuid_result.ecx & (1 << 17)) >> 17;
                self.cpu_features.paging.PCID &= pcid;

                if pcid != 0
                {
                    CR4::write(CR4::read() | (1 << 17));
                }
            }

            // Enable global pages
            {
                CR4::write(CR4::read() | (1 << 7));
            }

            // Enable TCE support, if available
            {
                let cpuid_result = unsafe { __cpuid(0x80000001) };
                let tce = (cpuid_result.ecx & (1 << 17)) >> 17;
                self.cpu_features.paging.TCE &= tce;

                if tce != 0
                {
                    let mut efer = EFER.read();
                    efer.0 |= 1 << 15;
                    EFER.write(efer.0, efer.1);
                }
            }

            // Enable write-protect, so copy-on-write works in the kernel, and MMArchSafeCopy will
            // page fault in read-only regions
            {
                CR0::write(CR0::read() | (1 << 16));
            }

            // Enable MMX, SSE and SSE2, which are guaranteed to be present in x86_64
            {
                let mut cr0 = CR0::read();
                let mut cr4 = CR4::read();
                cr0 &= !4;
                cr0 |= 2;
                cr4 |= 512 + 1024;
                CR0::write(cr0);
                CR4::write(cr4);
            }

            // Detect SSE3 and SSSE3, if available
            {
                let cpuid_result = unsafe { __cpuid(1) };
                if cpuid_result.ecx & 1 == 0
                {
                    self.cpu_features.SIMD.SSE3 = self.cpu_features.SIMD.SSE3 & (0xffffff00) | 0;
                }

                if ((cpuid_result.ecx & (1 << 9)) >> 9) == 0
                {
                    self.cpu_features.SIMD.SSSE3 = self.cpu_features.SIMD.SSSE3 & (0xffffff00) | 0;
                }
            }

            // Enable system-call extensions (syscall and sysret)
            {
                let mut efer = EFER.read();
                efer.0 |= 1;
                EFER.write(efer.0, efer.1);

                let mut star = STAR.read();
                star.1 = 0x005b0048;
                STAR.write(star.0, star.1);

                let lstar_0 = (syscall_entry as u64) as u32;
                let lstar_1 = (syscall_entry as u64 >> 32) as u32;
                LSTAR.write(lstar_0, lstar_1);

                let mut sfmask = SFMASK.read();
                sfmask.0 = (1 << 10) | (1 << 9);
                SFMASK.write(sfmask.0, sfmask.1);
            }

            // Assign PAT2 to WC
            {
                const unknown_msr: MSR = MSR::new(0x277);
                let mut read_result = unknown_msr.read();
                read_result.0 &= 0xfff8ffff;
                read_result.0 |= 0x00010000;
                unknown_msr.write(read_result.0, read_result.1);
            }

            // Setup CPU local storage
            {
                let cpu_local_storage_address = unsafe { (&mut cpu_local_storage as *mut CPULocalStorageMemory) as u64 };
                let cpu_local_storage_low = (cpu_local_storage_address + self.cpu_local_storage_index) as u32;
                let cpu_local_storage_high = (cpu_local_storage_address >> 32) as u32;
                // Space for 4 8-byte values at gs:0 - gs:31
                self.cpu_local_storage_index += 32;
                GS_BASE.write(cpu_local_storage_low, cpu_local_storage_high);
            }

            // Load IDT
            {
                self.idtr.limit = idt_size - 1;
                self.idtr.base = unsafe { (&mut idt_data as *mut IDT) as u64 };
                self.idtr.load();
                unsafe { asm!("sti", options(nomem, nostack)) };
            }

            // Enable the APIC, which in x86_64 is always present
            {
                const unknown_msr: MSR = MSR::new(0x1b);
                let mut read_result = unknown_msr.read();
                read_result.0 |= 0x800;
                unknown_msr.write(read_result.0, read_result.1);
                let mask = read_result.0 & !0xfff;

                // Set the spurious interrupt vector to 0xff
                let ptr = (low_memory_map_start + 0xf0 + mask as u64) as *mut u32;
                unsafe { ptr.write_volatile(ptr.read_volatile() | 0x1ff) };

                // Use the flat processor addressing model
                let ptr = (low_memory_map_start + 0xe0 + mask as u64) as *mut u32;
                unsafe { ptr.write_volatile(0xffffffff) };

                // Make sure no external interrupts are masked
                CR8::write(0);
            }
        }
    }

    #[no_mangle]
    pub extern "C" fn syscall_entry()
    {
        unimplemented!();
    }


    global_asm!(
        ".section .text",
        ".global _start",
        ".extern start",
        ".extern stack",
        "_start:",
            "mov rax, 0x63",
            "mov fs, ax",
            "mov gs, ax",
            "mov rsp, OFFSET stack + {stack_size}",
            "jmp start",
            stack_size = const stack_size,
        );

    pub struct EarlyKernelInfo
    {
        bootloader: Bootloader,
        size: u32,
    }

    #[no_mangle]
    pub extern "C" fn start(bootloader_information_offset: u64, bootloader_ID: u64, kernel_size: u32)
    {
        let early_kernel_info = EarlyKernelInfo
        {
            bootloader: Bootloader
            {
                offset: bootloader_information_offset,
                id: bootloader_ID,
            },
            size: kernel_size,
        };

        unsafe { kernel.init(early_kernel_info) };
    }

    pub struct PIC;

    impl PIC
    {
        pub fn disable()
        {
            // Remap the ISRs sent by the PIC to 0x20 - 0x2F.
            // Even though we'll mask the PIC to use the APIC, 
            // we have to do this so that the spurious interrupts are sent to a reasonable vector range.
            IO::out8_delayed(IO::PIC1_command, 0x11);
            IO::out8_delayed(IO::PIC2_command, 0x11);
            IO::out8_delayed(IO::PIC1_data, 0x20);
            IO::out8_delayed(IO::PIC2_data, 0x28);
            IO::out8_delayed(IO::PIC1_data, 0x04);
            IO::out8_delayed(IO::PIC2_data, 0x02);
            IO::out8_delayed(IO::PIC1_data, 0x01);
            IO::out8_delayed(IO::PIC2_data, 0x01);

            // Mask all iArch::IO::nterrupts
            IO::out8_delayed(IO::PIC1_data, 0xff);
            IO::out8_delayed(IO::PIC2_data, 0xff);
        }
    }

    type InterruptHandlerFn = extern "C" fn();

    pub struct InterruptHandler<const interrupt_number: u64>;

    impl<const interrupt_number: u64> InterruptHandler<interrupt_number>
    {
        #[naked]
        pub extern "C" fn interrupt_handler_prologue()
        {
            unsafe
            {
                asm!(
                    "push 0",
                    "push {0}",
                    "jmp {1}",
                    const interrupt_number,
                    sym asm_interrupt_handler,
                );
            }
            unreachable!();
        }

        #[naked]
        pub extern "C" fn interrupt_handler_prologue_error_code()
        {
            unsafe
            {
                asm!(
                    // The CPU already pushed an error code
                    "push {0}",
                    "jmp {1}",
                    const interrupt_number,
                    sym asm_interrupt_handler,
                );
            }
            unreachable!();
        }
    }

    #[no_mangle]
    #[naked]
    extern "C" fn asm_interrupt_handler()
    {
        unsafe
        {
            #![allow(named_asm_labels)]
            asm!(
                "cld",

                "push rax",
                "push rbx",
                "push rcx",
                "push rdx",
                "push rsi",
                "push rdi",
                "push rbp",
                "push r8",
                "push r9",
                "push r10",
                "push r11",
                "push r12",
                "push r13",
                "push r14",
                "push r15",

                "mov rax,cr8",
                "push rax",

                "mov rax,0x123456789ABCDEF",
                "push rax",

                "mov rbx,rsp",
                "and rsp,~0xF",
                "fxsave [rsp - 512]",
                "mov rsp,rbx",
                "sub rsp,512 + 16",

                "xor rax,rax",
                "mov ax,ds",
                "push rax",
                "mov ax,0x10",
                "mov ds,ax",
                "mov es,ax",
                "mov rax,cr2",
                "push rax",

                "mov rdi,rsp",
                "mov rbx,rsp",
                "and rsp,~0xF",
                "call interrupt_handler",
                "mov rsp,rbx",
                "xor rax,rax",

                ".global return_from_interrupt_handler",
                "return_from_interrupt_handler:",

                "add rsp,8",
                "pop rbx",
                "mov ds,bx",
                "mov es,bx",

                "add rsp,512 + 16",
                "mov rbx,rsp",
                "and rbx,~0xF",
                "fxrstor [rbx - 512]",

                "cmp al,0",
                "je .oldThread",
                "fninit", // New thread - initialise FPU
                ".oldThread:",

                "pop rax",
                "mov rbx,0x123456789ABCDEF",
                "cmp rax,rbx",
                ".loop:",
                "jne .loop",

                "cli",
                "pop rax",
                "mov cr8,rax",

                "pop r15",
                "pop r14",
                "pop r13",
                "pop r12",
                "pop r11",
                "pop r10",
                "pop r9",
                "pop r8",
                "pop rbp",
                "pop rdi",
                "pop rsi",
                "pop rdx",
                "pop rcx",
                "pop rbx",
                "pop rax",

                "add rsp,16",
                "iretq",
                );
        }
        unreachable!();
    }

    extern "C"
    {
        pub fn return_from_interrupt_handler();
        pub fn interrupts_are_enabled() -> bool;
        pub fn interrupts_disable();
        pub fn interrupts_enable();
        pub fn bootloader_information_offset_get() -> u64;
    }

    global_asm!(
        ".section .data",
        "bootloader_information_offset: .quad 0",

        ".section .text",

        ".global interrupts_are_enabled",
        ".global interrupts_disable",
        ".global interrupts_enable",
        ".global out8",
        ".global in8",
        ".global CPU_idle",
        ".global bootloader_information_offset_get",

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

        "out8:",
        "mov rdx, rdi",
        "mov rax, rsi",
        "out dx, al",
        "ret",

        "in8:",
        "mov rdx, rdi",
        "xor rax, rax",
        "in al, dx",
        "ret",
    );

    pub mod IO
    {
        type Port = u16;

        pub const PIC1_command: Port = 0x0020;
        pub const PIC1_data: Port = 0x0021;
        pub const PIT_data: Port = 0x0040;
        pub const PIT_command: Port = 0x0043;
        pub const PS2_data: Port = 0x0060;
        pub const PC_speaker: Port = 0x0061;
        pub const PS2_status: Port = 0x0064;
        pub const PS2_command: Port = 0x0064;
        pub const RTC_index: Port = 0x0070;
        pub const RTC_data: Port = 0x0071;
        pub const unused_delay: Port = 0x0080;
        pub const PIC2_command: Port = 0x00A0;
        pub const PIC2_data: Port = 0x00A1;
        pub const BGA_index: Port = 0x01CE;
        pub const BGA_data: Port = 0x01CF;
        pub const ATA1: Port = 0x0170; // To 0x0177.
        pub const ATA2: Port = 0x01F0; // To 0x01F7.
        pub const COM4: Port = 0x02E8; // To 0x02EF.
        pub const COM2: Port = 0x02F8; // To 0x02FF.
        pub const ATA3: Port = 0x0376;
        pub const VGA_AC_index: Port = 0x03C0;
        pub const VGA_AC_write: Port = 0x03C0;
        pub const VGA_AC_read: Port = 0x03C1;
        pub const VGA_misc_write: Port = 0x03C2;
        pub const VGA_misc_read: Port = 0x03CC;
        pub const VGA_seq_index: Port = 0x03C4;
        pub const VGA_seq_data: Port = 0x03C5;
        pub const VGA_DAC_read_index: Port = 0x03C7;
        pub const VGA_DAC_write_indeX: Port = 0x03C8;
        pub const VGA_DAC_data: Port = 0x03C9;
        pub const VGA_GC_index: Port = 0x03CE;
        pub const VGA_GC_data: Port = 0x03CF;
        pub const VGA_CRTC_index: Port = 0x03D4;
        pub const VGA_CRTC_data: Port = 0x03D5;
        pub const VGA_INSTAT_read: Port = 0x03DA;
        pub const COM3: Port = 0x03E8; // To 0x03EF.
        pub const ATA4: Port = 0x03F6;
        pub const COM1: Port = 0x03F8; // To 0x03FF.
        pub const PCI_config: Port = 0x0CF8;
        pub const PCI_data: Port = 0x0CFC;

        extern "C"
        {
            pub fn out8(port: Port, value: u8);
            pub fn in8(port: Port);
        }
        pub extern "C" fn out8_delayed(port: Port, value: u8)
        {
            unsafe
            {
                out8(port, value);
                in8(unused_delay);
            }
        }

    }

    pub struct InterruptContext
    {
    }

    #[no_mangle]
    pub extern "C" fn interrupt_handler(_: &InterruptContext)
    {
        unimplemented!();
    }

    #[no_mangle]
    pub extern "C" fn syscall(argument0: u64, argument1: u64, argument2: u64, return_address: u64, argument3: u64, argument4: u64, user_stack_pointer: *const u64) -> u64
    {
        unimplemented!();
    }

    pub struct CR0;

    impl CR0
    {
        #[inline(always)]
        fn read() -> u64
        {
            let value: u64;

            unsafe
            {
                asm!("mov {}, cr0", out(reg) value, options(nomem, nostack, preserves_flags));
            }
            value
        }

        fn write(value: u64)
        {
            unsafe
            {
                asm!("mov cr0, {}", in(reg) value, options(nostack, preserves_flags));
            }
        }
    }

    pub struct CR3;

    impl CR3
    {
        #[inline(always)]
        fn flush()
        {
            unsafe
            {
                asm!( "mov rax, cr3", "mov cr3, rax")
            }
        }
    }

    pub struct CR4;
    impl CR4
    {
        #[inline(always)]
        fn read() -> u64
        {
            let value: u64;

            unsafe
            {
                asm!("mov {}, cr4", out(reg) value, options(nomem, nostack, preserves_flags));
            }
            value
        }

        #[inline(always)]
        fn write(value: u64)
        {
            unsafe { asm!("mov cr4, {}", in(reg) value, options(nostack, preserves_flags)) };
        }
    }

    pub struct CR8;
    impl CR8
    {
        #[inline(always)]
        fn read() -> u64
        {
            let value: u64;

            unsafe
            {
                asm!("mov {}, cr8", out(reg) value, options(nomem, nostack, preserves_flags));
            }
            value
        }

        #[inline(always)]
        fn write(value: u64)
        {
            unsafe { asm!("mov cr8, {}", in(reg) value, options(nostack, preserves_flags)) };
        }
    }

pub struct PhysicalMemory<'a>
{
    pub regions: &'a mut[Memory::PhysicalRegion],
    pub page_count: u64,
    pub original_page_count: u64,
    pub region_index: u64,
    pub highest: u64,
}

impl<'a> const Default for PhysicalMemory<'a>
{
    fn default() -> Self
    {
        Self
        {
            regions: &mut[],
            page_count: 0,
            original_page_count: 0,
            region_index: 0,
            highest: 0,
        }
    }
}

    impl<'a> PhysicalMemory<'a>
    {
        fn setup(&mut self, bootloader_information_offset: u64)
        {
            let physical_memory_region_ptr = (low_memory_map_start + 0x600000 + bootloader_information_offset) as *mut Memory::PhysicalRegion;
            let physical_memory_region_count =
            {
                let mut region_count: usize = 0;
                let mut region_it = physical_memory_region_ptr;

                loop
                {
                    let region = unsafe { region_it.as_mut() }.unwrap();
                    if region.base_address == 0 { break }
                    let end = region.base_address + (region.page_count << page_bit_count);
                    if end > 0x100000000
                    {
                        region.page_count = 0;
                        continue;
                    }

                    self.page_count  += region.page_count;
                    if end > self.highest
                    {
                        self.highest = end;
                    }

                    region_count += 1;
                    unsafe { region_it = region_it.add(1) };
                }

                region_count
            };

            self.regions = unsafe { core::slice::from_raw_parts_mut(physical_memory_region_ptr, physical_memory_region_count) };
            #[allow(unused_unsafe)]
            unsafe { self.original_page_count = self.regions[self.regions.len()].page_count };
        }
    }

    pub struct Bootloader
    {
        offset: u64,
        id: u64,
    }

    impl const Default for Bootloader
    {
        fn default() -> Self
        {
            Self
            {
                offset: 0,
                id: 0,
            }
        }
    }
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

pub struct Kernel<'a>
{
    arch: Arch::Specific<'a>,
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
    arch: Arch::Specific::default(),
};

impl Kernel<'static>
{
    fn init(&mut self, early_kernel_info: Arch::EarlyKernelInfo)
    {
        self.arch.early_setup(early_kernel_info);
        unimplemented!();
    }
}
