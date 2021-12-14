#![allow(non_snake_case)]
#![allow(non_camel_case_types)]
#![allow(non_upper_case_globals)]
#![allow(unsupported_naked_functions)]

#![no_std]
#![no_main]

#![feature(asm)]
#![feature(core_intrinsics)]
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
use core::u64;
use core::ptr::null_mut;
use core::sync::atomic::Ordering;
use core::mem::size_of;

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
pub static mut cpu_local_storage_index: Volatile<u64> = Volatile::new(0);

#[no_mangle]
#[link_section = ".data"]
pub static mut paging_NXE_support: Volatile<u32> = Volatile::new(0);

#[no_mangle]
#[link_section = ".data"]
pub static mut paging_PCID_support: Volatile<u32> = Volatile::new(0);

#[no_mangle]
#[link_section = ".data"]
pub static mut paging_SMEP_support: Volatile<u32> = Volatile::new(0);

#[no_mangle]
#[link_section = ".data"]
pub static mut paging_TCE_support: Volatile<u32> = Volatile::new(0);

#[no_mangle]
#[link_section = ".data"]
pub static mut simd_SSE3_support: Volatile<u32> = Volatile::new(0);

#[no_mangle]
#[link_section = ".data"]
pub static mut simd_SSSE3_support: Volatile<u32> = Volatile::new(0);

#[repr(C, align(0x10))]
pub struct GDTR(u64, u64);

#[no_mangle]
#[link_section = ".data"]
pub static mut gdtr: Volatile<GDTR> = Volatile::new(GDTR { 0: 0, 1: 0 });

#[no_mangle]
#[link_section = ".data"]
pub static mut kernel_size: Volatile<u32> = Volatile::new(0);

#[no_mangle]
#[link_section = ".data"]
pub static mut bootloader_ID: Volatile<u32> = Volatile::new(0);

#[no_mangle]
#[link_section = ".data"]
pub static mut installation_ID: Volatile<u128> = Volatile::new(0);

pub struct PhysicalMemory<'a>
{
    pub regions: &'a mut[Memory::PhysicalRegion],
    pub page_count: u64,
    pub original_page_count: u64,
    pub region_index: u64,
    pub highest: u64,
}

#[no_mangle]
#[link_section = ".data"]
pub static mut physical_memory: PhysicalMemory = PhysicalMemory
{
    regions: &mut[],
    page_count: 0,
    original_page_count: 0,
    region_index: 0,
    highest: 0,
};

global_asm!(
    ".section .text",
    ".global install_interrupt_handler",
    "install_interrupt_handler:",

    "mov word ptr [rbx + 0],dx",
    "mov word ptr [rbx + 2],0x48",
    "mov word ptr [rbx + 4],0x8E00",
    "shr rdx,16",
    "mov word ptr [rbx + 6],dx",
    "shr rdx,16",
    "mov qword ptr [rbx + 8],rdx",
    "ret",

    ".macro INTERRUPT_HANDLER i",
    ".global interrupt_handler\\i",
    "interrupt_handler\\i:",
    "push 0", // Fake error code
    "push \\i", // interrupt number
    "jmp interrupt_handler_common",
    ".endm",

    ".macro INTERRUPT_HANDLER_ERROR_CODE i",
    ".global interrupt_handler\\i",
    "interrupt_handler\\i:",
    // The CPU already pushed an error code
    "push \\i",
    "jmp interrupt_handler_common",
    ".endm",

    "INTERRUPT_HANDLER 0",
    "INTERRUPT_HANDLER 1",
    "INTERRUPT_HANDLER 2",
    "INTERRUPT_HANDLER 3",
    "INTERRUPT_HANDLER 4",
    "INTERRUPT_HANDLER 5",
    "INTERRUPT_HANDLER 6",
    "INTERRUPT_HANDLER 7",
    "INTERRUPT_HANDLER_ERROR_CODE 8",
    "INTERRUPT_HANDLER 9",
    "INTERRUPT_HANDLER_ERROR_CODE 10",
    "INTERRUPT_HANDLER_ERROR_CODE 11",
    "INTERRUPT_HANDLER_ERROR_CODE 12",
    "INTERRUPT_HANDLER_ERROR_CODE 13",
    "INTERRUPT_HANDLER_ERROR_CODE 14",
    "INTERRUPT_HANDLER 15",
    "INTERRUPT_HANDLER 16",
    "INTERRUPT_HANDLER_ERROR_CODE 17",
    "INTERRUPT_HANDLER 18",
    "INTERRUPT_HANDLER 19",
    "INTERRUPT_HANDLER 20",
    "INTERRUPT_HANDLER 21",
    "INTERRUPT_HANDLER 22",
    "INTERRUPT_HANDLER 23",
    "INTERRUPT_HANDLER 24",
    "INTERRUPT_HANDLER 25",
    "INTERRUPT_HANDLER 26",
    "INTERRUPT_HANDLER 27",
    "INTERRUPT_HANDLER 28",
    "INTERRUPT_HANDLER 29",
    "INTERRUPT_HANDLER 30",
    "INTERRUPT_HANDLER 31",

    ".altmacro",
    ".set i, 32",
    ".rept 224",
    "INTERRUPT_HANDLER %i",
    ".set i, i + 1",
    ".endr",

    ".global interrupt_handler_common",
    "interrupt_handler_common:",
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
    ".foo:",
    "jne .foo",

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
        #[link_section = ".text"]
        #[no_mangle]
        pub extern "C" fn PIC_disable()
        {
            // Remap the ISRs sent by the PIC to 0x20 - 0x2F.
            // Even though we'll mask the PIC to use the APIC, 
            // we have to do this so that the spurious interrupts are sent to a reasonable vector range.
            Arch::IO::out8_delayed(Arch::IO::PIC1_command, 0x11);
            Arch::IO::out8_delayed(Arch::IO::PIC2_command, 0x11);
            Arch::IO::out8_delayed(Arch::IO::PIC1_data, 0x20);
            Arch::IO::out8_delayed(Arch::IO::PIC2_data, 0x28);
            Arch::IO::out8_delayed(Arch::IO::PIC1_data, 0x04);
            Arch::IO::out8_delayed(Arch::IO::PIC2_data, 0x02);
            Arch::IO::out8_delayed(Arch::IO::PIC1_data, 0x01);
            Arch::IO::out8_delayed(Arch::IO::PIC2_data, 0x01);

            // Mask all iArch::IO::nterrupts
            Arch::IO::out8_delayed(Arch::IO::PIC1_data, 0xff);
            Arch::IO::out8_delayed(Arch::IO::PIC2_data, 0xff);
        }

pub mod Arch
{
    use {size_of, physical_memory, stack_size};
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

    pub const page_bit_count: u8 = 12;

    global_asm!(
        ".extern kernel_size",
        ".extern bootloader_ID",
        ".extern stack",
        ".extern installation_ID",
        ".extern gdtr",
        ".extern bootloader_information_offset",

        ".extern PIC_disable",
        ".extern memory_region_setup",

        ".section .text",
        ".global _start",

        "_start:",
        "mov [kernel_size], edx",
        "xor rdx, rdx",

        "mov rax, 0x63",
        "mov fs, ax",
        "mov gs, ax",

        // Save bootloader ID
        "mov rax, OFFSET bootloader_ID",
        "mov [rax], rsi",

        // The MBR bootloader doesn't know the address of the RSDP
        "cmp rdi, 0",
        "jne .standard_acpi",
        "mov [0x7fe8], rdi",
        ".standard_acpi:",

        // Save the bootloader information offset
        "mov rax, OFFSET bootloader_information_offset",
        "mov [rax], rdi",

        // Install a stack
        "mov rsp, OFFSET stack + {stack_size}",

        // Load the installation ID
        "mov rbx, OFFSET installation_ID",
        "mov rax, [rdi + 0x7ff0]",
        "mov [rbx], rax",
        "mov rax, [rdi + 0x7ff8]",
        "mov [rbx + 8], rax",

        // Unmap the identity paging the bootloader used
        "mov rax, 0xFFFFFF7FBFDFE000",
        "mov qword ptr [rax], 0",
        "mov rax, cr3",
        "mov cr3, rax",

        // @TODO: serial
        "call PIC_disable",
        "call memory_region_setup",

        // Install interrupt handlers
        ".macro INSTALL_INTERRUPT_HANDLER i",
        "mov rbx, (\\i * 16) + OFFSET idt_data",
        "mov rdx, OFFSET interrupt_handler\\i",
        "call install_interrupt_handler",
        ".endm",

        ".altmacro",
        ".set i, 0",
        ".rept 256",
        "INSTALL_INTERRUPT_HANDLER %i",
        ".set i, i + 1",
        ".endr",

        // Save the location of the bootstrap GDT
        "mov rcx, OFFSET gdtr",
        "sgdt [rcx]",

        // First stage of CPU initialization
        "call CPU_setup1",

        "and rsp, ~0xf",
        "call kernel_initialize",

        "CPU_ready:",
        "mov rdi, 1",
        "call next_timer",
        "jmp CPU_idle",

        "CPU_setup1:",

        ".enable_cpu_features:",
        // Enable no-execute support, if available"
        "mov	eax,0x80000001",
        "cpuid",
        "and	edx,1 << 20",
        "shr	edx,20",
        "mov	rax, OFFSET paging_NXE_support",
        "and	[rax],edx",
        "cmp	edx,0",
        "je	.no_paging_nxe_support",
        "mov	ecx,0xC0000080",
        "rdmsr",
        "or	eax,1 << 11",
        "wrmsr",
        ".no_paging_nxe_support:",

        // x87 FPU
        "fninit",
        "mov	rax,.cw",
        "fldcw	[rax]",
        "jmp	.cwa",
        ".cw:", ".short 0x037A",
        ".cwa:",
        // Enable SMEP support, if available"
        // This prevents the kernel from executing userland pages",
        // TODO Test this: neither Bochs or Qemu seem to support it?",
        "xor	eax,eax",
        "cpuid",
        "cmp	eax,7",
        "jb	.no_smep_support",
        "mov	eax,7",
        "xor	ecx,ecx",
        "cpuid",
        "and ebx,1 << 7",
        "shr	ebx,7",
        "mov	rax, OFFSET paging_SMEP_support",
        "and	[rax],ebx",
        "cmp	ebx,0",
        "je	.no_smep_support",
        "mov	word ptr [rax],2",
        "mov	rax,cr4",
        "or	rax,1 << 20",
        "mov	cr4,rax",
        ".no_smep_support:",

        // Enable PCID support, if available
        "mov	eax,1",
        "xor	ecx,ecx",
        "cpuid",
        "and	ecx,1 << 17",
        "shr	ecx,17",
        "mov	rax, OFFSET paging_PCID_support",
        "and	[rax],ecx",
        "cmp	ecx,0",
        "je	.no_pcid_support",
        "mov	rax,cr4",
        "or	rax,1 << 17",
        "mov	cr4,rax",
        ".no_pcid_support:",

        // Enable global pages
        "mov	rax,cr4",
        "or	rax,1 << 7",
        "mov	cr4,rax",

        // Enable TCE support, if available
        "mov	eax,0x80000001",
        "xor	ecx,ecx",
        "cpuid",
        "and	ecx,1 << 17",
        "shr	ecx,17",
        "mov	rax, OFFSET paging_TCE_support",
        "and	[rax],ecx",
        "cmp	ecx,0",
        "je	.no_tce_support",
        "mov	ecx, 0xC0000080",
        "rdmsr",
        "or	eax,1 << 15",
        "wrmsr",
        ".no_tce_support:",

        // Enable write protect, so copy-on-write works in the kernel, and MMArchSafeCopy will page fault in read-only regions.
        "mov	rax,cr0",
        "or	rax,1 << 16",
        "mov	cr0,rax",

        // Enable MMX, SSE and SSE2",
        // These features are all guaranteed to be present on a x86_64 CPU",
        "mov	rax,cr0",
        "mov	rbx,cr4",
        "and	rax,~4",
        "or	rax,2",
        "or	rbx,512 + 1024",
        "mov	cr0,rax",
        "mov	cr4,rbx",

        // Detect SSE3 and SSSE3, if available.",
        "mov	eax,1",
        "cpuid",
        "test	ecx,1 << 0",
        "jnz	.has_sse3",
        "mov	rax, OFFSET simd_SSE3_support",
        "and	byte ptr [rax],0",
        ".has_sse3:",
        "test	ecx,1 << 9",
        "jnz	.has_ssse3",
        "mov	rax, OFFSET simd_SSSE3_support",
        "and	byte ptr [rax],0",
        ".has_ssse3:",

        // Enable system-call extensions (SYSCALL and SYSRET).",
        "mov	ecx,0xC0000080",
        "rdmsr",
        "or	eax,1",
        "wrmsr",
        "add	ecx,1",
        "rdmsr",
        "mov	edx,0x005B0048",
        "wrmsr",
        "add	ecx,1",
        "mov	rdx, OFFSET syscall_entry",
        "mov	rax,rdx",
        "shr	rdx,32",
        "wrmsr",
        "add	ecx,2",
        "rdmsr",
        "mov	eax,(1 << 10) | (1 << 9)", // Clear direction and interrupt flag when we enter ring 0.",
        "wrmsr",

        // Assign PAT2 to WC.",
        "mov	ecx,0x277",
        "xor	rax,rax",
        "xor	rdx,rdx",
        "rdmsr",
        "and	eax,0xFFF8FFFF",
        "or	eax,0x00010000",
        "wrmsr",

        ".setup_cpu_local_storage:",
        "mov	ecx,0xC0000101",
        "mov	rax, OFFSET cpu_local_storage",
        "mov	rdx, OFFSET cpu_local_storage",
        "shr	rdx,32",
        "mov	rdi, OFFSET cpu_local_storage_index",
        "add	rax,[rdi]",
        "add	qword ptr [rdi],32", // Space for 4 8-byte values at gs:0 - gs:31",
        "wrmsr",

        ".load_idtr:",
        // Load the IDTR",
        "mov	rax,idt",
        "lidt	[rax]",
        "sti",

        ".enable_apic:",
        // Enable the APIC!",
        // Since we're on AMD64, we know that the APIC will be present.",
        "mov	ecx,0x1B",
        "rdmsr",
        "or	eax,0x800",
        "wrmsr",
        "and	eax,~0xFFF",
        "mov	edi,eax",

        // Set the spurious interrupt vector to 0xFF",
        "mov	rax,0xFFFFFE00000000F0", // LOW_MEMORY_MAP_START + 0xF0",
        "add	rax,rdi",
        "mov	ebx,[rax]",
        "or	ebx,0x1FF",
        "mov	[rax],ebx",

        // Use the flat processor addressing model",
        "mov	rax,0xFFFFFE00000000E0", // LOW_MEMORY_MAP_START + 0xE0",
        "add	rax,rdi",
        "mov	dword ptr [rax],0xFFFFFFFF",

        // Make sure that no external interrupts are masked",
        "xor	rax,rax",
        "mov	cr8,rax",

        "ret",

        stack_size = const stack_size
    );

    extern "C"
    {
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

        "CPU_idle:",
        "sti",
        "hlt",
        "jmp CPU_idle",


        "syscall_entry:",
        "mov	rsp, qword ptr gs:8",
        "sti",

        "mov	ax,0x50",
        "mov	ds,ax",
        "mov	es,ax",

        // Preserve RCX, R11, R12 and RBX.",
        "push	rcx",
        "push	r11",
        "push	r12",
        "mov	rax,rsp",
        "push	rbx",
        "push	rax",

        // Arguments in RDI, RSI, RDX, R8, R9. (RCX contains return address).",
        // Return value in RAX.",
        "mov	rbx,rsp",
        "and	rsp,~0xF",
        "call	syscall",
        "mov	rsp,rbx",

        // Disable maskable interrupts.",
        "cli",

        // Return to long mode. (Address in RCX).",
        "add	rsp,8",
        "push	rax",
        "mov	ax,0x63",
        "mov	ds,ax",
        "mov	es,ax",
        "pop	rax",
        "pop	rbx",
        "pop	r12", // User RSP",
        "pop	r11",
        "pop	rcx", // Return address",
        "sysretq",

        ".global bootloader_information_offset_get",
        "bootloader_information_offset_get:",
        "mov rax, [bootloader_information_offset]",
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

    #[no_mangle]
    pub extern "C" fn memory_region_setup()
    {
        let physical_memory_region_ptr = unsafe { (low_memory_map_start + 0x600000 + bootloader_information_offset_get()) as *mut Memory::PhysicalRegion };
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

                unsafe { physical_memory.page_count  += region.page_count };
                if end > unsafe { physical_memory.highest }
                {
                    unsafe { physical_memory.highest = end };
                }

                region_count += 1;
                unsafe { region_it = region_it.add(1) };
            }

            region_count
        };

        unsafe { physical_memory.regions = core::slice::from_raw_parts_mut(physical_memory_region_ptr, physical_memory_region_count) }
        unsafe { physical_memory.original_page_count = physical_memory.regions[physical_memory.regions.len()].page_count }
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

    #[no_mangle]
    // arg = ms
    pub extern "C" fn next_timer(_: u64)
    {
        unimplemented!();
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

impl Kernel
{
    fn init(&mut self)
    {
        unimplemented!();
    }
}

#[no_mangle]
pub extern "C" fn kernel_initialize()
{
    unsafe { kernel.init() }
}
