pub use kernel::*;

pub const page_bit_count: u16 = 12;
pub const page_size: u16 = 1 << page_bit_count;
//pub const K_PAGE_BITS (12)
//pub const K_PAGE_SIZE (0x1000)
//pub const
//pub const MM_CORE_REGIONS_START (0xFFFF8001F0000000)
//pub const MM_CORE_REGIONS_COUNT ((0xFFFF800200000000 - 0xFFFF8001F0000000) / sizeof(MMRegion))
//pub const MM_KERNEL_SPACE_START (0xFFFF900000000000)
//pub const MM_KERNEL_SPACE_SIZE  (0xFFFFF00000000000 - 0xFFFF900000000000)
//pub const MM_MODULES_START      (0xFFFFFFFF90000000)
//pub const MM_MODULES_SIZE	      (0xFFFFFFFFC0000000 - 0xFFFFFFFF90000000)
//pub const
//pub const MM_CORE_SPACE_START   (0xFFFF800100000000)
//pub const MM_CORE_SPACE_SIZE    (0xFFFF8001F0000000 - 0xFFFF800100000000)
//pub const MM_USER_SPACE_START   (0x100000000000)
//pub const MM_USER_SPACE_SIZE    (0xF00000000000 - 0x100000000000)

pub const low_memory_map_start: u64 = 0xFFFFFE0000000000;
pub const low_memory_limit: u64 = 0x100000000; // The first 4GB is mapped here.

pub struct Specific<'a>
{
    pub gdt_descriptor: GDT::Descriptor,
    pub idt_descriptor: IDT::Descriptor,
    pub physical_memory: PhysicalMemory<'a>,
    pub installation_id: u128,
    pub bootloader_id: u64,
    pub bootloader_information_offset: u64,
    pub kernel_size: u32,
}

impl<'a> const Default for Specific<'a>
{
    fn default() -> Self
    {
        Self
        {
            gdt_descriptor: GDT::Descriptor { limit: 0, base: 0 },
            idt_descriptor: IDT::Descriptor { limit: 0, base: 0 },
            physical_memory: PhysicalMemory
            {
                regions: &mut [],
                page_count: 0,
                original_page_count: 0,
                region_index: 0,
                highest: 0,
            },
            installation_id: 0,
            bootloader_id: 0,
            bootloader_information_offset: 0,
            kernel_size: 0
        }
    }
}

pub struct PhysicalMemory<'a>
{
    regions: &'a mut[arch::PhysicalMemoryRegion],
    page_count: u64,
    original_page_count: u64,
    region_index: u64,
    highest: u64,
}

impl<'a> PhysicalMemory<'a>
{
    fn setup(&mut self)
    {
        let physical_memory_region_ptr = unsafe { (low_memory_map_start + 0x60000 + kernel.arch.bootloader_information_offset) as *mut arch::PhysicalMemoryRegion };
        let physical_memory_region_count =
        {
            let mut it = physical_memory_region_ptr;

            loop
            {
                let region = unsafe { it.as_mut().unwrap() };
                if region.base_address == 0 { break }

                let end = region.base_address + (region.page_count << page_bit_count);
                if end > 0x100000000
                {
                    region.page_count = 0;
                    continue;
                }

                self.page_count += region.page_count;
                
                if end > self.highest { self.highest = end }
                it = unsafe { it.add(1) };
            }


            unsafe { it.offset_from(physical_memory_region_ptr) }
        };

        self.original_page_count = unsafe { physical_memory_region_ptr.offset(physical_memory_region_count).read().page_count };
        self.regions = unsafe { &mut *core::ptr::slice_from_raw_parts_mut(physical_memory_region_ptr, physical_memory_region_count as usize) };
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

#[repr(C, align(0x10))]
pub struct Stack
{
    memory: [u8; 0x4000],
}

#[no_mangle]
#[link_section = ".bss"]
pub static mut stack: Stack = Stack { memory: [0; 0x4000] };

#[naked]
#[no_mangle]
pub extern "C" fn _start()
{
    unsafe
    {
        asm!(
            "mov rax, 0x63",
            "mov fs, ax",
            "mov gs, ax",

            "mov {0:e}, edx",
            "mov {1}, rsi",
            "mov {2}, rdi",
            out(reg) kernel.arch.kernel_size,
            out(reg) kernel.arch.bootloader_id,
            out(reg) kernel.arch.bootloader_information_offset,
        );

        if kernel.arch.bootloader_information_offset == 0
        {
            *(0x7fe8 as *mut u64) = kernel.arch.bootloader_information_offset;
        }

        asm!(
            "mov rsp, OFFSET {} + {}",
            sym stack,
            const size_of::<Stack>()
        );

        kernel.arch.installation_id = *((kernel.arch.bootloader_information_offset + 0x7ff0) as *mut u128);

        *(0xFFFFFF7FBFDFE000 as *mut u64) = 0;
        CR3::flush();
        IO::PIC::disable();
        kernel.arch.physical_memory.setup();
        IDT::setup();
    }
}

pub mod IO
{
    use kernel::*;
    pub struct Port
    {
        port: u16,
    }

    pub const PIC1_command: Port = Port::new(0x0020);
    pub const PIC1_data: Port = Port::new(0x0021);
    pub const PIT_command: Port = Port::new(0x0040);
    pub const PIT_data: Port = Port::new(0x0043);
    pub const PS2_data: Port = Port::new(0x0060);
    pub const PC_speaker: Port = Port::new(0x0061);
    pub const PS2_status: Port = Port::new(0x0064);
    pub const PS2_command: Port = Port::new(0x0064);
    pub const RTC_index: Port = Port::new(0x0070);
    pub const RTC_data: Port = Port::new(0x0071);
    pub const unused_delay: Port = Port::new(0x0080);
    pub const PIC2_command: Port = Port::new(0x00a0);
    pub const PIC2_data: Port = Port::new(0x00a1);

    impl Port
    {
        #[inline(always)]
        fn write_u8(self, value: u8)
        {
            unsafe
            {
                asm!("out dx, al", in("dx") self.port, in("al") value, options(nomem, nostack, preserves_flags));
            }
        }

        #[inline(always)]
        fn read_u8(self) -> u8
        {
            unsafe
            {
                let value: u8;
                asm!("in al, dx", out("al") value, in("dx") self.port, options(nomem, nostack, preserves_flags));
                value
            }
        }

        #[inline(always)]
        fn write_u8_delayed(self, value: u8)
        {
            self.write_u8(value);
            unused_delay.read_u8();
        }

        const fn new(port: u16) -> Self
        {
            Self { port }
        }
    }

    pub struct PIC;

    impl PIC
    {
        pub fn disable()
        {
            // Remap the ISRs sent by the PIC to 0x20 - 0x2F.
            // Even though we'll mask the PIC to use the APIC, 
            // we have to do this so that the spurious interrupts are sent to a reasonable vector range.
            PIC1_command.write_u8_delayed(0x11);
            PIC2_command.write_u8_delayed(0x11);
            PIC1_data.write_u8_delayed(0x20);
            PIC2_data.write_u8_delayed(0x28);
            PIC1_data.write_u8_delayed(0x04);
            PIC2_data.write_u8_delayed(0x02);
            PIC1_data.write_u8_delayed(0x01);
            PIC2_data.write_u8_delayed(0x01);

            // Mask all interrupts.
            PIC1_data.write_u8_delayed(0xff);
            PIC2_data.write_u8_delayed(0xff);
        }
    }
}

#[no_mangle]
#[naked]
pub extern "C" fn asm_interrupt_handler()
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
            "call {}",
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
            "je .old_thread",
            "fninit", // New thread - initialise FPU.",
            ".old_thread:",

            "pop rax",
            "mov rbx,0x123456789ABCDEF",
            "cmp rax,rbx",
            ".infinite_loop:",
            "jne .infinite_loop",

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
            sym interrupt_handler
        );
    }
    unreachable!();
}

pub struct InterruptContext
{
}

pub extern "C" fn interrupt_handler(_: &InterruptContext)
{
    unimplemented!();
}

#[naked]
pub extern "C" fn interrupt_handler_prologue<const interrupt_number: u64>()
{
    unsafe
    {
        asm!(
            "push 0",
            "push {}",
            "jmp {}",
            const interrupt_number,
            sym asm_interrupt_handler,
        );
    }
    unreachable!();
}

pub extern "C" fn interrupt_handler_prologue_error_code<const interrupt_number: u64>()
{
    unsafe
    {
        asm!(
            "push {}",
            "jmp {}",
            const interrupt_number,
            sym asm_interrupt_handler,
        );
    }
    unreachable!();
}

mod IDT
{
    use kernel::*;
    use super::{interrupt_handler_prologue, interrupt_handler_prologue_error_code};

    #[repr(C, packed)]
    pub struct Descriptor
    {
        pub limit: u16,
        pub base: u64,
    }

    pub const size: usize = 0x1000;
    pub const entry_count: usize = size as usize / size_of::<Entry>();

    #[repr(C, align(0x10))]
    pub struct Data
    {
        entries: [Entry; entry_count],
    }

    pub static mut data: Data = Data { entries: [Entry { foo1: 0, foo2: 0, foo3: 0, foo4: 0, handler: 0 }; entry_count] };


    impl Data
    {
        fn new_interrupt_handler<const interrupt_number: u64, const error_code: bool>(&mut self)
        {
            let handler: InterruptHandlerFn = match error_code
            {
                true => interrupt_handler_prologue_error_code::<interrupt_number>,
                false => interrupt_handler_prologue::<interrupt_number>,
            };

            let handler_raw_address = unsafe { transmute::<InterruptHandlerFn, u64>(handler) };
            let foo4 = handler_raw_address >> 16;
            let handler_address = foo4 >> 16;

            self.entries[interrupt_number as usize] = Entry
            {
                foo1: handler_raw_address as u16,
                foo2: 0x48,
                foo3: 0x8e00,
                foo4: foo4 as u16,
                handler: handler_address,
            };
        }
    }

    type InterruptHandlerFn = extern "C" fn();


    #[derive(Copy, Clone)]
    #[repr(C, packed)]
    pub struct Entry
    {
        pub foo1: u16,
        pub foo2: u16,
        pub foo3: u16,
        pub foo4: u16,
        pub handler: u64,
    }

    pub fn setup()
    {
        unsafe
        {
            kernel.arch.idt_descriptor.limit = size as u16 - 1;
            kernel.arch.idt_descriptor.base = (&mut data as *mut Data) as u64;

            data.new_interrupt_handler::<0,  false>();
            data.new_interrupt_handler::<1,  false>();
            data.new_interrupt_handler::<2,  false>();
            data.new_interrupt_handler::<3,  false>();
            data.new_interrupt_handler::<4,  false>();
            data.new_interrupt_handler::<5,  false>();
            data.new_interrupt_handler::<6,  false>();
            data.new_interrupt_handler::<7,  false>();
            data.new_interrupt_handler::<8,  true>();
            data.new_interrupt_handler::<9,  false>();
            data.new_interrupt_handler::<10, true>();
            data.new_interrupt_handler::<11, true>();
            data.new_interrupt_handler::<12, true>();
            data.new_interrupt_handler::<13, true>();
            data.new_interrupt_handler::<14, true>();
            data.new_interrupt_handler::<15, false>();
            data.new_interrupt_handler::<16, false>();
            data.new_interrupt_handler::<17, true>();
            data.new_interrupt_handler::<18, false>();
            data.new_interrupt_handler::<19, false>();
            data.new_interrupt_handler::<20, false>();
            data.new_interrupt_handler::<21, false>();
            data.new_interrupt_handler::<22, false>();
            data.new_interrupt_handler::<23, false>();
            data.new_interrupt_handler::<24, false>();
            data.new_interrupt_handler::<25, false>();
            data.new_interrupt_handler::<26, false>();
            data.new_interrupt_handler::<27, false>();
            data.new_interrupt_handler::<28, false>();
            data.new_interrupt_handler::<29, false>();
            data.new_interrupt_handler::<30, false>();
            data.new_interrupt_handler::<31, false>();
            data.new_interrupt_handler::<32, false>();
            data.new_interrupt_handler::<33, false>();
            data.new_interrupt_handler::<34, false>();
            data.new_interrupt_handler::<35, false>();
            data.new_interrupt_handler::<36, false>();
            data.new_interrupt_handler::<37, false>();
            data.new_interrupt_handler::<38, false>();
            data.new_interrupt_handler::<39, false>();
            data.new_interrupt_handler::<40, false>();
            data.new_interrupt_handler::<41, false>();
            data.new_interrupt_handler::<42, false>();
            data.new_interrupt_handler::<43, false>();
            data.new_interrupt_handler::<44, false>();
            data.new_interrupt_handler::<45, false>();
            data.new_interrupt_handler::<46, false>();
            data.new_interrupt_handler::<47, false>();
            data.new_interrupt_handler::<48, false>();
            data.new_interrupt_handler::<49, false>();
            data.new_interrupt_handler::<50, false>();
            data.new_interrupt_handler::<51, false>();
            data.new_interrupt_handler::<52, false>();
            data.new_interrupt_handler::<53, false>();
            data.new_interrupt_handler::<54, false>();
            data.new_interrupt_handler::<55, false>();
            data.new_interrupt_handler::<56, false>();
            data.new_interrupt_handler::<57, false>();
            data.new_interrupt_handler::<58, false>();
            data.new_interrupt_handler::<59, false>();
            data.new_interrupt_handler::<60, false>();
            data.new_interrupt_handler::<61, false>();
            data.new_interrupt_handler::<62, false>();
            data.new_interrupt_handler::<63, false>();
            data.new_interrupt_handler::<64, false>();
            data.new_interrupt_handler::<65, false>();
            data.new_interrupt_handler::<66, false>();
            data.new_interrupt_handler::<67, false>();
            data.new_interrupt_handler::<68, false>();
            data.new_interrupt_handler::<69, false>();
            data.new_interrupt_handler::<70, false>();
            data.new_interrupt_handler::<71, false>();
            data.new_interrupt_handler::<72, false>();
            data.new_interrupt_handler::<73, false>();
            data.new_interrupt_handler::<74, false>();
            data.new_interrupt_handler::<75, false>();
            data.new_interrupt_handler::<76, false>();
            data.new_interrupt_handler::<77, false>();
            data.new_interrupt_handler::<78, false>();
            data.new_interrupt_handler::<79, false>();
            data.new_interrupt_handler::<80, false>();
            data.new_interrupt_handler::<81, false>();
            data.new_interrupt_handler::<82, false>();
            data.new_interrupt_handler::<83, false>();
            data.new_interrupt_handler::<84, false>();
            data.new_interrupt_handler::<85, false>();
            data.new_interrupt_handler::<86, false>();
            data.new_interrupt_handler::<87, false>();
            data.new_interrupt_handler::<88, false>();
            data.new_interrupt_handler::<89, false>();
            data.new_interrupt_handler::<90, false>();
            data.new_interrupt_handler::<91, false>();
            data.new_interrupt_handler::<92, false>();
            data.new_interrupt_handler::<93, false>();
            data.new_interrupt_handler::<94, false>();
            data.new_interrupt_handler::<95, false>();
            data.new_interrupt_handler::<96, false>();
            data.new_interrupt_handler::<97, false>();
            data.new_interrupt_handler::<98, false>();
            data.new_interrupt_handler::<99, false>();

            data.new_interrupt_handler::<100, false>();
            data.new_interrupt_handler::<101, false>();
            data.new_interrupt_handler::<102, false>();
            data.new_interrupt_handler::<103, false>();
            data.new_interrupt_handler::<104, false>();
            data.new_interrupt_handler::<105, false>();
            data.new_interrupt_handler::<106, false>();
            data.new_interrupt_handler::<107, false>();
            data.new_interrupt_handler::<108, false>();
            data.new_interrupt_handler::<109, false>();
            data.new_interrupt_handler::<110, false>();
            data.new_interrupt_handler::<111, false>();
            data.new_interrupt_handler::<112, false>();
            data.new_interrupt_handler::<113, false>();
            data.new_interrupt_handler::<114, false>();
            data.new_interrupt_handler::<115, false>();
            data.new_interrupt_handler::<116, false>();
            data.new_interrupt_handler::<117, false>();
            data.new_interrupt_handler::<118, false>();
            data.new_interrupt_handler::<119, false>();
            data.new_interrupt_handler::<120, false>();
            data.new_interrupt_handler::<121, false>();
            data.new_interrupt_handler::<122, false>();
            data.new_interrupt_handler::<123, false>();
            data.new_interrupt_handler::<124, false>();
            data.new_interrupt_handler::<125, false>();
            data.new_interrupt_handler::<126, false>();
            data.new_interrupt_handler::<127, false>();
            data.new_interrupt_handler::<128, false>();
            data.new_interrupt_handler::<129, false>();
            data.new_interrupt_handler::<130, false>();
            data.new_interrupt_handler::<131, false>();
            data.new_interrupt_handler::<132, false>();
            data.new_interrupt_handler::<133, false>();
            data.new_interrupt_handler::<134, false>();
            data.new_interrupt_handler::<135, false>();
            data.new_interrupt_handler::<136, false>();
            data.new_interrupt_handler::<137, false>();
            data.new_interrupt_handler::<138, false>();
            data.new_interrupt_handler::<139, false>();
            data.new_interrupt_handler::<140, false>();
            data.new_interrupt_handler::<141, false>();
            data.new_interrupt_handler::<142, false>();
            data.new_interrupt_handler::<143, false>();
            data.new_interrupt_handler::<144, false>();
            data.new_interrupt_handler::<145, false>();
            data.new_interrupt_handler::<146, false>();
            data.new_interrupt_handler::<147, false>();
            data.new_interrupt_handler::<148, false>();
            data.new_interrupt_handler::<149, false>();
            data.new_interrupt_handler::<150, false>();
            data.new_interrupt_handler::<151, false>();
            data.new_interrupt_handler::<152, false>();
            data.new_interrupt_handler::<153, false>();
            data.new_interrupt_handler::<154, false>();
            data.new_interrupt_handler::<155, false>();
            data.new_interrupt_handler::<156, false>();
            data.new_interrupt_handler::<157, false>();
            data.new_interrupt_handler::<158, false>();
            data.new_interrupt_handler::<159, false>();
            data.new_interrupt_handler::<160, false>();
            data.new_interrupt_handler::<161, false>();
            data.new_interrupt_handler::<162, false>();
            data.new_interrupt_handler::<163, false>();
            data.new_interrupt_handler::<164, false>();
            data.new_interrupt_handler::<165, false>();
            data.new_interrupt_handler::<166, false>();
            data.new_interrupt_handler::<167, false>();
            data.new_interrupt_handler::<168, false>();
            data.new_interrupt_handler::<169, false>();
            data.new_interrupt_handler::<170, false>();
            data.new_interrupt_handler::<171, false>();
            data.new_interrupt_handler::<172, false>();
            data.new_interrupt_handler::<173, false>();
            data.new_interrupt_handler::<174, false>();
            data.new_interrupt_handler::<175, false>();
            data.new_interrupt_handler::<176, false>();
            data.new_interrupt_handler::<177, false>();
            data.new_interrupt_handler::<178, false>();
            data.new_interrupt_handler::<179, false>();
            data.new_interrupt_handler::<180, false>();
            data.new_interrupt_handler::<181, false>();
            data.new_interrupt_handler::<182, false>();
            data.new_interrupt_handler::<183, false>();
            data.new_interrupt_handler::<184, false>();
            data.new_interrupt_handler::<185, false>();
            data.new_interrupt_handler::<186, false>();
            data.new_interrupt_handler::<187, false>();
            data.new_interrupt_handler::<188, false>();
            data.new_interrupt_handler::<189, false>();
            data.new_interrupt_handler::<190, false>();
            data.new_interrupt_handler::<191, false>();
            data.new_interrupt_handler::<192, false>();
            data.new_interrupt_handler::<193, false>();
            data.new_interrupt_handler::<194, false>();
            data.new_interrupt_handler::<195, false>();
            data.new_interrupt_handler::<196, false>();
            data.new_interrupt_handler::<197, false>();
            data.new_interrupt_handler::<198, false>();
            data.new_interrupt_handler::<199, false>();

            data.new_interrupt_handler::<200, false>();
            data.new_interrupt_handler::<201, false>();
            data.new_interrupt_handler::<202, false>();
            data.new_interrupt_handler::<203, false>();
            data.new_interrupt_handler::<204, false>();
            data.new_interrupt_handler::<205, false>();
            data.new_interrupt_handler::<206, false>();
            data.new_interrupt_handler::<207, false>();
            data.new_interrupt_handler::<208, false>();
            data.new_interrupt_handler::<209, false>();
            data.new_interrupt_handler::<210, false>();
            data.new_interrupt_handler::<211, false>();
            data.new_interrupt_handler::<212, false>();
            data.new_interrupt_handler::<213, false>();
            data.new_interrupt_handler::<214, false>();
            data.new_interrupt_handler::<215, false>();
            data.new_interrupt_handler::<216, false>();
            data.new_interrupt_handler::<217, false>();
            data.new_interrupt_handler::<218, false>();
            data.new_interrupt_handler::<219, false>();
            data.new_interrupt_handler::<220, false>();
            data.new_interrupt_handler::<221, false>();
            data.new_interrupt_handler::<222, false>();
            data.new_interrupt_handler::<223, false>();
            data.new_interrupt_handler::<224, false>();
            data.new_interrupt_handler::<225, false>();
            data.new_interrupt_handler::<226, false>();
            data.new_interrupt_handler::<227, false>();
            data.new_interrupt_handler::<228, false>();
            data.new_interrupt_handler::<229, false>();
            data.new_interrupt_handler::<230, false>();
            data.new_interrupt_handler::<231, false>();
            data.new_interrupt_handler::<232, false>();
            data.new_interrupt_handler::<233, false>();
            data.new_interrupt_handler::<234, false>();
            data.new_interrupt_handler::<235, false>();
            data.new_interrupt_handler::<236, false>();
            data.new_interrupt_handler::<237, false>();
            data.new_interrupt_handler::<238, false>();
            data.new_interrupt_handler::<239, false>();
            data.new_interrupt_handler::<240, false>();
            data.new_interrupt_handler::<241, false>();
            data.new_interrupt_handler::<242, false>();
            data.new_interrupt_handler::<243, false>();
            data.new_interrupt_handler::<244, false>();
            data.new_interrupt_handler::<245, false>();
            data.new_interrupt_handler::<246, false>();
            data.new_interrupt_handler::<247, false>();
            data.new_interrupt_handler::<248, false>();
            data.new_interrupt_handler::<249, false>();
            data.new_interrupt_handler::<250, false>();
            data.new_interrupt_handler::<251, false>();
            data.new_interrupt_handler::<252, false>();
            data.new_interrupt_handler::<253, false>();
            data.new_interrupt_handler::<254, false>();
            data.new_interrupt_handler::<255, false>();
        }
    }
}

mod GDT
{
    #[repr(C, packed)]
    pub struct Descriptor
    {
        pub limit: u16,
        pub base: u64,
    }
}
