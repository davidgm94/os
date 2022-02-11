const kernel = @import("../kernel.zig");

const EsMemoryCopy = kernel.EsMemoryCopy;
const EsMemoryZero = kernel.EsMemoryZero;
const EsMemorySumBytes = kernel.EsMemorySumBytes;
const FatalError = kernel.FatalError;
const CrashReason = kernel.CrashReason;
const zeroes = kernel.zeroes;
const SimpleList = kernel.SimpleList;
const Volatile = kernel.Volatile;
const TODO = kernel.TODO;

const ACPI = kernel.drivers.ACPI;
const memory = kernel.memory;

const Thread = kernel.scheduling.Thread;

const Event = kernel.sync.Event;
const Mutex = kernel.sync.Mutex;
const Spinlock = kernel.sync.Spinlock;

const syscall = kernel.syscall;

const std = @import("std");
const assert = std.debug.assert;

pub const page_bit_count = 12;
pub const page_size = 0x1000;

pub const entry_per_page_table_count = 512;
pub const entry_per_page_table_bit_count = 9;

pub const core_memory_region_start = 0xFFFF8001F0000000;
pub const core_memory_region_count = (0xFFFF800200000000 - 0xFFFF8001F0000000) / @sizeOf(memory.Region);

pub const kernel_address_space_start = 0xFFFF900000000000;
pub const kernel_address_space_size = 0xFFFFF00000000000 - 0xFFFF900000000000;

pub const modules_start = 0xFFFFFFFF90000000;
pub const modules_size = 0xFFFFFFFFC0000000 - 0xFFFFFFFF90000000;

pub const core_address_space_start = 0xFFFF800100000000;
pub const core_address_space_size = 0xFFFF8001F0000000 - 0xFFFF800100000000;

pub const user_space_start = 0x100000000000;
pub const user_space_size = 0xF00000000000 - 0x100000000000;

pub const low_memory_map_start = 0xFFFFFE0000000000;
pub const low_memory_limit = 0x100000000; // The first 4GB is mapped here.

export var _stack: [0x4000]u8 align(0x1000) linksection(".bss") = undefined;
export var _idt_data: [idt_entry_count]IDTEntry align(0x1000) linksection(".bss") = undefined;
/// Array of pointers to the CPU local states
export var _cpu_local_storage: [0x2000]u8 align(0x1000) linksection(".bss") = undefined;

export var timeStampCounterSynchronizationValue = Volatile(u64) { .value = 0 };

export var idt_descriptor: CPUDescriptorTable linksection(".data") = undefined;
export var processorGDTR: u128 align(0x10) linksection(".data")  = undefined;
pub export var installation_ID: u128 linksection(".data") = 0;
pub export var bootloader_ID: u64 linksection(".data") = 0;
pub export var bootloader_information_offset: u64 linksection(".data") = 0;
export var _cpu_local_storage_index: u64 linksection(".data") = 0;
export var kernel_size: u32 linksection(".data") = 0;

export var pagingNXESupport: u32 linksection(".data") = 1;
export var pagingPCIDSupport: u32 linksection(".data") = 1;
export var pagingSMEPSupport: u32 linksection(".data") = 1;
export var pagingTCESupport: u32 linksection(".data") = 1;
export var simdSSE3Support: u32 linksection(".data") = 1;
export var simdSSSE3Support: u32 linksection(".data") = 1;

export var global_descriptor_table: GDT align(0x10) linksection(".data") = GDT
{
    .null_entry = GDT.Entry.new(0, 0, 0, 0),
    .code_entry = GDT.Entry.new(0xffff, 0, 0xcf9a, 0),
    .data_entry = GDT.Entry.new(0xffff, 0, 0xcf92, 0),
    .code_entry16 = GDT.Entry.new(0xffff, 0, 0x0f9a, 0),
    .data_entry16 = GDT.Entry.new(0xffff, 0, 0x0f92, 0),
    .user_code = GDT.Entry.new(0xffff, 0, 0xcffa, 0),
    .user_data = GDT.Entry.new(0xffff, 0, 0xcff2, 0),
    .tss = TSS { .foo1 = 0x68, .foo2 = 0, .foo3 = 0xe9, .foo4 = 0, .foo5 = 0 },
    .code_entry64 = GDT.Entry.new(0xffff, 0, 0xaf9a, 0),
    .data_entry64 = GDT.Entry.new(0xffff, 0, 0xaf92, 0),
    .user_code64 = GDT.Entry.new(0xffff, 0, 0xaffa, 0),
    .user_data64 = GDT.Entry.new(0xffff, 0, 0xaff2, 0),
    .user_code64c = GDT.Entry.new(0xffff, 0, 0xaffa, 0),
};
export var gdt_descriptor2 = GDT.Descriptor
{
    .limit = @sizeOf(GDT) - 1,
    .base = 0x11000,
};

pub extern fn halt() callconv(.C) noreturn;
pub extern fn are_interrupts_enabled() callconv(.C) bool;
pub extern fn enable_interrupts() callconv(.C) void;
pub extern fn disable_interrupts() callconv(.C) void;
pub extern fn fake_timer_interrupt() callconv(.C) void;
pub extern fn invalidate_page(page: u64) callconv(.C) void;
pub extern fn ProcessorInvalidateAllPages() callconv(.C) void;
pub extern fn in8(port: u16) callconv(.C) u8;
pub extern fn in16(port: u16) callconv(.C) u16;
pub extern fn in32(port: u16) callconv(.C) u32;
pub extern fn out8(port: u16, value: u8) callconv(.C) void;
pub extern fn out16(port: u16, value: u16) callconv(.C) void;
pub extern fn out32(port: u16, value: u32) callconv(.C) void;
pub extern fn ProcessorReadTimeStamp() callconv(.C) u64;
pub extern fn ProcessorReadCR3() callconv(.C) u64;
pub extern fn debug_output_byte(byte: u8) callconv(.C) void;
pub extern fn ProcessorSetThreadStorage(tls_address: u64) callconv(.C) void;
pub extern fn set_local_storage(local_storage: *LocalStorage) callconv(.C) void;
pub extern fn ProcessorInstallTSS(gdt: u64, tss: u64) callconv(.C) void;
pub extern fn get_local_storage() callconv(.C) ?*LocalStorage;
pub extern fn get_current_thread() callconv(.C) ?*Thread;

pub export fn initialize_thread(kernel_stack: u64, kernel_stack_size: u64, thread: *Thread, start_address: u64, argument1: u64, argument2: u64, userland: bool, user_stack: u64, user_stack_size: u64) callconv(.C) *InterruptContext
{
    const base = kernel_stack + kernel_stack_size - 8;
    const context = @intToPtr(*InterruptContext, base - @sizeOf(InterruptContext));
    thread.kernel_stack = base;
    var ptr = @intToPtr(*u64, base);
    // @TODO: workaround since Zig gives us 0 address sometimes for function pointers...
    const fn_ptr = Get_KThreadTerminateAddress();
    ptr.* = fn_ptr;

    context.fx_save[32] = 0x80;
    context.fx_save[33] = 0x1f;

    if (userland)
    {
        context.cs = 0x5b;
        context.ds = 0x63;
        context.ss = 0x63;
    }
    else
    {
        context.cs = 0x48;
        context.ds = 0x50;
        context.ss = 0x50;
    }

    context._check = 0x123456789ABCDEF;
    context.flags = 1 << 9;
    context.rip = start_address;
    if (context.rip == 0) kernel.panic("RIP is 0");
    context.rsp = user_stack + user_stack_size - 8;
    context.rdi = argument1;
    context.rsi = argument2;

    return context;
}
export fn MMArchInvalidatePages(virtual_address_start: u64, page_count: u64) callconv(.C) void
{
    ipiLock.acquire();
    tlbShootdownVirtualAddress.access_volatile().* = virtual_address_start;
    tlbShootdownPageCount.access_volatile().* = page_count;

    ArchCallFunctionOnAllProcessors(TLBShootdownCallback, true);
    ipiLock.release();
}
export fn InterruptHandler(context: *InterruptContext) callconv(.C) void
{
    if (kernel.scheduler.panic.read_volatile() and context.interrupt_number != 2) return;
    if (are_interrupts_enabled()) kernel.panic("interrupts were enabled at the start of the interrupt handler");

    const interrupt = context.interrupt_number;
    var maybe_local = get_local_storage();
    if (maybe_local) |local|
    {
        if (local.current_thread) |current_thread| current_thread.last_interrupt_timestamp = ProcessorReadTimeStamp();
        if (local.spinlock_count != 0 and context.cr8 != 0xe) kernel.panic("Spinlock count is not zero but interrupts were enabled");
    }

    if (interrupt < 0x20)
    {
        if (interrupt == 2)
        {
            maybe_local.?.panic_context = context;
            halt();
        }

        const supervisor = context.cs & 3 == 0;

        if (!supervisor)
        {
            if (context.cs != 0x5b and context.cs != 0x6b) kernel.panic("Unexpected value of CS");
            const current_thread = get_current_thread().?;
            if (current_thread.is_kernel_thread) kernel.panic("Kernel thread executing user code");
            const previous_terminatable_state = current_thread.terminatable_state.read_volatile();
            current_thread.terminatable_state.write_volatile(.in_syscall);

            if (maybe_local) |local| if (local.spinlock_count != 0) kernel.panic("user exception occurred with spinlock acquired");

            enable_interrupts();
            maybe_local = null;

            if ((interrupt == 14 and !handle_page_fault(context.cr2, if (context.error_code & 2 != 0) memory.HandlePageFaultFlags.from_flag(.write) else memory.HandlePageFaultFlags.empty())) or interrupt != 14)
            {
                {
                    var rbp = context.rbp;
                    var trace_depth: u32 = 0;

                    while (rbp != 0 and trace_depth < 32)
                    {
                        if (!MMArchIsBufferInUserRange(rbp, 16)) break;
                        var value: u64 = 0;
                        if (!MMArchSafeCopy(@ptrToInt(&value), rbp + 8, @sizeOf(u64))) break;
                        if (value == 0) break;
                        if (!MMArchSafeCopy(@ptrToInt(&rbp), rbp, @sizeOf(u64))) break;
                    }
                }

                var crash_reason = zeroes(CrashReason);
                crash_reason.error_code = FatalError.processor_exception;
                crash_reason.during_system_call = -1;
                current_thread.process.?.crash(&crash_reason);
            }

            if (current_thread.terminatable_state.read_volatile() != .in_syscall) kernel.panic("thread changed terminatable state during interrupt");

            current_thread.terminatable_state.write_volatile(previous_terminatable_state);
            if (current_thread.terminating.read_volatile() or current_thread.paused.read_volatile()) fake_timer_interrupt();

            disable_interrupts();
        }
        else
        {
            if (context.cs != 0x48) kernel.panic("unexpected value of CS");

            if (interrupt == 14)
            {
                if (context.error_code & (1 << 3) != 0) kernel.panic("unresolvable page fault");

                if (maybe_local) |local| if (local.spinlock_count != 0 and (context.cr2 >= 0xFFFF900000000000 and context.cr2 < 0xFFFFF00000000000)) kernel.panic("page fault occurred with spinlocks active");

                if (context.flags & 0x200 != 0 and context.cr8 != 0xe)
                {
                    enable_interrupts();
                    maybe_local = null;
                }

                const result = handle_page_fault(context.cr2, (if (context.error_code & 2 != 0) memory.HandlePageFaultFlags.from_flag(.write) else memory.HandlePageFaultFlags.empty()).or_flag(.for_supervisor));
                var safe_copy = false;
                if (!result)
                {
                    if (get_current_thread().?.in_safe_copy and context.cr2 < 0x8000000000000000)
                    {
                        safe_copy = true;
                        context.rip = context.r8;
                    }
                }

                if (result or safe_copy)
                {
                    disable_interrupts();
                }
                else
                {
                    kernel.panic("unhandled page fault");
                }
            }
            else
            {
                kernel.panic("Unresolvable exception");
            }
        }
    }
    else if (interrupt == 0xff)
    {
    }
    else if (interrupt >= 0x20 and interrupt < 0x30)
    {
    }
    else if (interrupt >= 0xf0 and interrupt < 0xfe)
    {
        TODO(@src());
    }
    else if (maybe_local) |local|
    {
        if ((interrupt >= interrupt_vector_msi_start and interrupt < interrupt_vector_msi_start + interrupt_vector_msi_count) and maybe_local != null)
        {
            irqHandlersLock.acquire();
            const msi_i = interrupt - interrupt_vector_msi_start;
            const handler = msiHandlers[msi_i];
            irqHandlersLock.release();
            local.IRQ_switch_thread = false;

            if (handler.callback) |callback|
            {
                _ = callback(msi_i, handler.context);

                if (local.IRQ_switch_thread and kernel.scheduler.started.read_volatile() and local.scheduler_ready)
                {
                    //TODO();
                    kernel.scheduler.yield(context);
                    kernel.panic("returned from scheduler yield");
                }
                else
                {
                    LAPIC.end_of_interrupt();
                }
            }
            else
            {
                kernel.panic("MSI handler didn't have a callback assigned");
            }
        }
        else
        {
            local.IRQ_switch_thread = false;

            if (interrupt == timer_interrupt)
            {
                local.IRQ_switch_thread = true;
            }
            else if (interrupt == IPI.yield)
            {
                local.IRQ_switch_thread = true;
                get_current_thread().?.received_yield_IPI.write_volatile(true);
            }
            else if (interrupt >= irq_base and interrupt < irq_base + 0x20)
            {
                TODO(@src());
            }

            if (local.IRQ_switch_thread and kernel.scheduler.started.read_volatile() and local.scheduler_ready)
            {
                kernel.scheduler.yield(context);
                kernel.panic("returned from scheduler yield");
            }
            else
            {
                LAPIC.end_of_interrupt();
            }
        }
    }

    ContextSanityCheck(context);

    if (are_interrupts_enabled()) kernel.panic("interrupts were enabled while returning from an interrupt handler");
}

const CPUDescriptorTable = packed struct 
{
    limit: u16,
    base: u64,
};

const IDTEntry = packed struct
{
    foo1: u16,
    foo2: u16,
    foo3: u16,
    foo4: u16,
    masked_handler: u64,
};

const GDT = packed struct
{
    null_entry: Entry,
    code_entry: Entry,
    data_entry: Entry,
    code_entry16: Entry,
    data_entry16: Entry,
    user_code: Entry,
    user_data: Entry,
    tss: TSS,
    code_entry64: Entry,
    data_entry64: Entry,
    user_code64: Entry,
    user_data64: Entry,
    user_code64c: Entry,

    const Entry = packed struct
    {
        foo1: u32,
        foo2: u8,
        foo3: u16,
        foo4: u8,

        fn new(foo1: u32, foo2: u8, foo3: u16, foo4: u8) @This()
        {
            return @This()
            {
                .foo1 = foo1,
                .foo2 = foo2,
                .foo3 = foo3,
                .foo4 = foo4,
            };
        }
    };

    const Descriptor = packed struct
    {
        limit: u16,
        base: u64,
    };

    const WithDescriptor = packed struct
    {
        gdt: GDT,
        descriptor: Descriptor,
    };

    comptime
    {
        assert(@sizeOf(Entry) == 8);
        assert(@sizeOf(TSS) == 16);
        assert(@sizeOf(GDT) == @sizeOf(u64) * 14);
        assert(@sizeOf(Descriptor) == 10);
        assert(@offsetOf(GDT.WithDescriptor, "descriptor") == @sizeOf(GDT));
        // This is false
        //assert(@sizeOf(Complete) == @sizeOf(GDT) + @sizeOf(Descriptor));
    }
};

const TSS = packed struct
{
    foo1: u32,
    foo2: u8,
    foo3: u16,
    foo4: u8,
    foo5: u64,
};

const idt_entry_count = 0x1000 / @sizeOf(IDTEntry);

comptime { assert(@sizeOf(IDTEntry) == 0x10); }

export fn _start() callconv(.Naked) noreturn
{
    @setRuntimeSafety(false);
    asm volatile(
        \\.intel_syntax noprefix
        \\.extern kernel_size
        \\mov rax, OFFSET kernel_size
        \\mov [rax], edx
        \\xor rdx, rdx

        \\mov rax, 0x63
        \\mov fs, ax
        \\mov gs, ax

        \\// save bootloader id
        \\mov rax, OFFSET bootloader_ID
        \\mov [rax], rsi

        \\cmp rdi, 0
        \\jne .standard_acpi
        \\mov rax, 0x7fe8
        \\mov [rax], rdi
        \\.standard_acpi:

        \\mov rax, OFFSET bootloader_information_offset
        \\mov [rax], rdi

        // Stack size: 0x4000 
        \\mov rsp, OFFSET _stack + 0x4000
        \\
        \\mov rbx, OFFSET installation_ID
        \\mov rax, [rdi + 0x7ff0]
        \\mov [rbx], rax
        \\mov rax, [rdi + 0x7ff8]
        \\mov [rbx + 8], rax

        \\// unmap the identity paging the bootloader used
        \\mov rax, 0xFFFFFF7FBFDFE000
        \\mov qword ptr [rax], 0
        \\mov rax, cr3
        \\mov cr3, rax

        \\call PCSetupCOM1
        \\call PCDisablePIC
        \\call PCProcessMemoryMap
        \\call install_interrupt_handlers
        \\
        \\mov rcx, OFFSET processorGDTR
        \\sgdt [rcx]
        \\
        \\call CPU_setup_1
        \\
        \\and rsp, ~0xf
        \\call KernelInitialise

        \\jmp ProcessorReady
    );
    unreachable;
}

export fn install_interrupt_handlers() callconv(.C) void
{
    comptime var interrupt_number: u64 = 0;
    inline while (interrupt_number < 256) : (interrupt_number += 1)
    {
        const has_error_code_pushed = comptime switch (interrupt_number)
        {
            8, 10, 11, 12, 13, 14, 17 => true,
            else => false,
        };
        var handler_address = @ptrToInt(InterruptHandlerMaker(interrupt_number, has_error_code_pushed).routine);

        _idt_data[interrupt_number].foo1 = @truncate(u16, handler_address);
        _idt_data[interrupt_number].foo2 = 0x48;
        _idt_data[interrupt_number].foo3 = 0x8e00;
        handler_address >>= 16;
        _idt_data[interrupt_number].foo4 = @truncate(u16, handler_address);
        handler_address >>= 16;
        _idt_data[interrupt_number].masked_handler = handler_address;
    }
}

fn InterruptHandlerMaker(comptime number: u64, comptime has_error_code: bool) type
{
    return extern struct
    {
        fn routine() callconv(.Naked) noreturn
        {
            @setRuntimeSafety(false);

            if (comptime !has_error_code)
            {
                asm volatile(
                \\.intel_syntax noprefix
                \\push 0
                );
            }

            asm volatile(
                ".intel_syntax noprefix\npush " ++ std.fmt.comptimePrint("{}", .{number})
                );

            asm volatile(
                \\.intel_syntax noprefix
                
                \\cld
               
                \\push rax
                \\push rbx
                \\push rcx
                \\push rdx
                \\push rsi
                \\push rdi
                \\push rbp
                \\push r8
                \\push r9
                \\push r10
                \\push r11
                \\push r12
                \\push r13
                \\push r14
                \\push r15
                
                \\mov rax, cr8
                \\push rax
               
                \\mov rax, 0x123456789ABCDEF
                \\push rax
                
                \\mov rbx, rsp
                \\and rsp, ~0xf
                \\fxsave [rsp - 512]
                \\mov rsp, rbx
                \\sub rsp, 512 + 16

                \\xor rax, rax
                \\mov ax, ds
                \\push rax
                \\mov ax, 0x10
                \\mov ds, ax
                \\mov es, ax
                \\mov rax, cr2
                \\push rax

                \\mov rdi, rsp
                \\mov rbx, rsp
                \\and rsp, ~0xf
                \\call InterruptHandler
                \\mov rsp, rbx
                \\xor rax, rax

                \\jmp ReturnFromInterruptHandler
            );

            unreachable;
        }
    };
}


comptime
{
    asm(
            \\.intel_syntax noprefix
        \\.global CPU_setup_1
        \\CPU_setup_1:
        // Enable no-execute support, if available
        \\mov eax, 0x80000001
        \\cpuid
        \\and edx,1 << 20
        \\shr edx,20
        \\mov rax, OFFSET pagingNXESupport
        \\and [rax],edx
        \\cmp edx,0
        \\je .no_paging_nxe_support
        \\mov ecx,0xC0000080
        \\rdmsr
        \\or eax,1 << 11
        \\wrmsr
        \\.no_paging_nxe_support:
        
        // x87 FPU
        \\fninit
        \\mov rax, OFFSET .cw
        \\fldcw [rax]
        \\jmp .cwa
        \\.cw: .short 0x037a
        \\.cwa:
        
        // Enable SMEP support, if available
        // This prevents the kernel from executing userland pages
        // TODO Test this: neither Bochs or Qemu seem to support it?
        \\xor eax,eax
        \\cpuid
        \\cmp eax,7
        \\jb .no_smep_support
        \\mov eax,7
        \\xor ecx,ecx
        \\cpuid
        \\and ebx,1 << 7
        \\shr ebx,7
        \\mov rax, OFFSET pagingSMEPSupport
        \\and [rax],ebx
        \\cmp ebx,0
        \\je .no_smep_support
        \\mov word ptr [rax],2
        \\mov rax,cr4
        \\or rax,1 << 20
        \\mov cr4,rax
        \\.no_smep_support:
        
        // Enable PCID support, if available
        \\mov eax,1
        \\xor ecx,ecx
        \\cpuid
        \\and ecx,1 << 17
        \\shr ecx,17
        \\mov rax, OFFSET pagingPCIDSupport
        \\and [rax],ecx
        \\cmp ecx,0
        \\je .no_pcid_support
        \\mov rax,cr4
        \\or rax,1 << 17
        \\mov cr4,rax
        \\.no_pcid_support:
        
        // Enable global pages
        \\mov rax,cr4
        \\or rax,1 << 7
        \\mov cr4,rax
        
        // Enable TCE support, if available
        \\mov eax,0x80000001
        \\xor ecx,ecx
        \\cpuid
        \\and ecx,1 << 17
        \\shr ecx,17
        \\mov rax, OFFSET pagingTCESupport
        \\and [rax],ecx
        \\cmp ecx,0
        \\je .no_tce_support
        \\mov ecx,0xC0000080
        \\rdmsr
        \\or eax,1 << 15
        \\wrmsr
        \\.no_tce_support:
        
        // Enable write protect, so copy-on-write works in the kernel, and MMArchSafeCopy will page fault in read-only regions.
        \\mov rax,cr0
        \\or rax,1 << 16
        \\mov cr0,rax
        
        // Enable MMX, SSE and SSE2
        // These features are all guaranteed to be present on a x86_64 CPU
        \\mov rax,cr0
        \\mov rbx,cr4
        \\and rax,~4
        \\or rax,2
        \\or rbx,512 + 1024
        \\mov cr0,rax
        \\mov cr4,rbx
        
        // Detect SSE3 and SSSE3, if available.
        \\mov eax,1
        \\cpuid
        \\test ecx,1 << 0
        \\jnz .has_sse3
        \\mov rax, OFFSET simdSSE3Support
        \\and byte ptr [rax],0
        \\.has_sse3:
        \\test ecx,1 << 9
        \\jnz .has_ssse3
        \\mov rax, OFFSET simdSSSE3Support
        \\and byte ptr [rax],0
        \\.has_ssse3:
        
        // Enable system-call extensions (SYSCALL and SYSRET).
        \\mov ecx,0xC0000080
        \\rdmsr
        \\or eax,1
        \\wrmsr
        \\add ecx,1
        \\rdmsr
        \\mov edx,0x005B0048
        \\wrmsr
        \\add ecx,1
        \\mov rdx, OFFSET SyscallEntry
        \\mov rax,rdx
        \\shr rdx,32
        \\wrmsr
        \\add ecx,2
        \\rdmsr
        // Clear direction and interrupt flag when we enter ring 0.
        \\mov eax,(1 << 10) | (1 << 9) 
        \\wrmsr
        
        // Assign PAT2 to WC.
        \\mov ecx,0x277
        \\xor rax,rax
        \\xor rdx,rdx
        \\rdmsr
        \\and eax,0xFFF8FFFF
        \\or eax,0x00010000
        \\wrmsr
        
        \\.setup_cpu_local_storage:
        \\mov ecx,0xC0000101
        \\mov rax, OFFSET _cpu_local_storage
        \\mov rdx, OFFSET _cpu_local_storage
        \\shr rdx,32
        \\mov rdi, OFFSET _cpu_local_storage_index
        \\add rax,[rdi]
        // Space for 4 8-byte values at gs:0 - gs:31
        \\add qword ptr [rdi],32 
        \\wrmsr
        
        \\.load_idtr:
        // Load the IDTR
        \\mov rax, OFFSET idt_descriptor
        \\mov word ptr [rax], 0x1000
        \\mov qword ptr [rax + 2], OFFSET _idt_data
        \\lidt [rax]
        \\sti
        
        \\.enable_apic:
        // Enable the APIC!
        // Since we're on AMD64, we know that the APIC will be present.
        \\mov ecx,0x1B
        \\rdmsr
        \\or eax,0x800
        \\wrmsr
        \\and eax,~0xFFF
        \\mov edi,eax
        
        // Set the spurious interrupt vector to 0xFF
        // LOW_MEMORY_MAP_START + 0xF0
        \\mov rax,0xFFFFFE00000000F0 
        \\add rax,rdi
        \\mov ebx,[rax]
        \\or ebx,0x1FF
        \\mov [rax],ebx
        
        // Use the flat processor addressing model
        // LOW_MEMORY_MAP_START + 0xE0
        \\mov rax,0xFFFFFE00000000E0 
        \\add rax,rdi
        \\mov dword ptr [rax],0xFFFFFFFF
        
        // Make sure that no external interrupts are masked
        \\xor rax,rax
        \\mov cr8,rax
        
        \\ret
        
        \\.global get_current_thread
        \\get_current_thread:
        \\mov rax, qword ptr gs:16
        \\ret
        
        \\.global ProcessorGetRSP
        \\ProcessorGetRSP:
        \\mov rax, rsp
        \\ret
        
        \\.global ProcessorGetRBP
        \\ProcessorGetRBP:
        \\mov rax, rbp
        \\ret
        
        \\.global halt
        \\halt:
        \\cli
        \\hlt
        \\jmp halt

        \\.global are_interrupts_enabled
        \\are_interrupts_enabled:
        \\pushf
        \\pop rax
        \\and rax, 0x200
        \\shr rax, 9
        \\
        \\mov rdx, cr8
        \\cmp rdx, 0
        \\je .done
        \\mov rax, 0
        \\.done:
        \\ret
        
        \\.global enable_interrupts
        \\enable_interrupts:
        \\mov rax, 0
        \\mov cr8, rax
        \\sti
        \\ret

        \\.global disable_interrupts
        \\disable_interrupts:
        \\mov rax, 14
        \\mov cr8, rax
        \\sti
        \\ret

        \\.global get_local_storage
        \\get_local_storage:
        \\mov rax, qword ptr gs:0
        \\ret

        \\.global fake_timer_interrupt
        \\fake_timer_interrupt:
        \\int 0x40
        \\ret

        \\.extern KThreadTerminate
        \\.global _KThreadTerminate
        \\_KThreadTerminate:
        \\sub rsp, 8
        \\jmp KThreadTerminate
        \\
        
        \\.global Get_KThreadTerminateAddress
        \\Get_KThreadTerminateAddress:
        \\mov rax, OFFSET _KThreadTerminate
        \\ret

        \\.global ProcessorReadCR3
        \\ProcessorReadCR3:
        \\mov rax, cr3
        \\ret

        \\.global invalidate_page
        \\invalidate_page:
        \\invlpg [rdi]
        \\ret

        \\.global set_address_space
        \\set_address_space:
        \\mov rdi, [rdi]
        \\mov rax, cr3
        \\cmp rax, rdi
        \\je .continuation
        \\mov cr3, rdi
        \\.continuation:
        \\ret

        \\.global ProcessorInvalidateAllPages
        \\ProcessorInvalidateAllPages:
        \\mov rax, cr4
        \\and rax, ~(1 << 7)
        \\mov cr4, rax
        \\or rax, 1 << 7
        \\mov cr4, rax
        \\ret

        \\.global out8
        \\out8:
        \\mov rdx, rdi
        \\mov rax, rsi
        \\out dx, al
        \\ret

        \\.global in8
        \\in8:
        \\mov rdx, rdi
        \\xor rax, rax
        \\in al, dx
        \\ret

        \\.global out16
        \\out16:
        \\mov rdx,rdi
        \\mov rax,rsi
        \\out dx,ax
        \\ret
     
        \\.global in16
        \\in16:
        \\mov rdx,rdi
        \\xor rax,rax
        \\in ax,dx
        \\ret
      
        \\.global out32
        \\out32:
        \\mov rdx,rdi
        \\mov rax,rsi
        \\out dx,eax
        \\ret
        
        \\.global in32
        \\in32:
        \\mov rdx,rdi
        \\xor rax,rax
        \\in eax,dx
        \\ret

        \\.global ProcessorReadTimeStamp
        \\ProcessorReadTimeStamp:
        \\rdtsc
        \\shl rdx, 32
        \\or rax, rdx
        \\ret

        \\.global set_local_storage
        \\set_local_storage:
        \\mov qword ptr gs:0, rdi
        \\ret

        \\.global ProcessorInstallTSS
        \\ProcessorInstallTSS:
        \\push rbx

        \\mov rax,rdi
        \\mov rbx,rsi
        \\mov [rax + 56 + 2],bx
        \\shr rbx,16
        \\mov [rax + 56 + 4],bl
        \\shr rbx,8
        \\mov [rax + 56 + 7],bl
        \\shr rbx,8
        \\mov [rax + 56 + 8],rbx
        
        \\mov rax, OFFSET gdt_descriptor2
        \\add rax, 2
        \\mov rdx,[rax]
        \\mov [rax],rdi
        \\mov rdi, rax
        \\sub rdi, 2
        \\lgdt [rdi]
        \\mov [rax],rdx
        
        \\mov ax,0x38
        \\ltr ax
        
        \\pop rbx
        \\ret
 
        \\.global switch_context
        \\switch_context:
        \\cli
        \\mov qword ptr gs:16, rcx
        \\mov qword ptr gs:8, rdx
        \\mov rsi, [rsi]
        \\mov rax, cr3
        \\cmp rax, rsi
        \\je .cont
        \\mov cr3, rsi
        \\.cont:
        \\mov rsp, rdi
        \\mov rsi, r8
        \\call PostContextSwitch
        \\jmp ReturnFromInterruptHandler

        \\.global ProcessorSetThreadStorage
        \\ProcessorSetThreadStorage:
        \\push rdx
        \\push rcx
        \\mov rcx, 0xc0000100
        \\mov rdx, rdi
        \\mov rax, rdi
        \\shr rdx, 32
        \\wrmsr
        \\pop rcx
        \\pop rdx
        \\ret

        \\.global MMArchSafeCopy
        \\MMArchSafeCopy:
        \\call get_current_thread
        \\mov byte ptr [rax + 0], 1
        \\mov rcx, rdx
        \\mov r8, .error
        \\rep movsb
        \\mov byte ptr [rax + 0], 0
        \\mov al, 1
        \\ret

        \\.error:
        \\mov byte ptr [rax + 0], 0
        \\mov al, 0
        \\ret

        \\.global debug_output_byte
        \\debug_output_byte:
        \\mov dx, 0x3f8 + 5
        \\.wait_read:
        \\in al, dx
        \\and al, 0x20
        \\cmp al, 0
        \\je .wait_read
        \\mov dx, 0x3f8 + 0
        \\mov rax, rdi
        \\out dx, al
        \\ret

        \\.global ProcessorReadMXCSR
        \\ProcessorReadMXCSR:
        \\mov rax, .buffer
        \\stmxcsr [rax]
        \\mov rax, .buffer
        \\mov rax, [rax]
        \\ret
        \\.buffer: .quad 0

        \\ProcessorReady:
        \\mov rdi, 1
        \\call next_timer
        \\jmp ProcessorIdle

        \\.global ReturnFromInterruptHandler
        \\ReturnFromInterruptHandler:
        \\add rsp, 8
        \\pop rbx
        \\mov ds, bx
        \\mov es, bx
        \\add rsp, 512 + 16
        \\mov rbx, rsp
        \\and rbx, ~0xf
        \\fxrstor [rbx - 512]
        \\
        \\cmp al, 0
        \\je .old_thread
        \\fninit
        \\.old_thread:
        \\
        \\pop rax
        \\mov rbx, 0x123456789ABCDEF
        \\cmp rax, rbx
        \\.loop:
        \\jne .loop
        \\
        \\cli
        \\pop rax
        \\mov cr8, rax
        \\pop r15
        \\pop r14
        \\pop r13
        \\pop r12
        \\pop r11
        \\pop r10
        \\pop r9
        \\pop r8
        \\pop rbp
        \\pop rdi
        \\pop rsi
        \\pop rdx
        \\pop rcx
        \\pop rbx
        \\pop rax
        \\
        \\add rsp, 16
        \\iretq

        \\.global ProcessorIdle
        \\ProcessorIdle:
        \\sti
        \\hlt
        \\jmp ProcessorIdle

        \\.global SyscallEntry
        \\SyscallEntry:
        \\mov rsp, qword ptr gs:8
        \\sti
        \\mov ax,0x50
        \\mov ds,ax
        \\mov es,ax
        \\push rcx
        \\push r11
        \\push r12
        \\mov rax,rsp
        \\push rbx
        \\push rax
        \\mov rbx,rsp
        \\and rsp,~0xF
        \\call Syscall
        \\mov rsp,rbx
        \\cli
        \\add rsp,8
        \\push rax
        \\mov ax,0x63
        \\mov ds,ax
        \\mov es,ax
        \\pop rax
        \\pop rbx
        \\pop r12
        \\pop r11
        \\pop rcx 
        \\.byte 0x48 
        \\sysret
    );
}

pub extern fn switch_context(context: *InterruptContext, arch_address_space: *AddressSpace, thread_kernel_stack: u64, new_thread: *Thread, old_address_space: *memory.AddressSpace) callconv(.C) void;

pub const LocalStorage = extern struct
{
    current_thread: ?*Thread,
    idle_thread: ?*Thread,
    async_task_thread: ?*Thread,
    panic_context: ?*InterruptContext,
    IRQ_switch_thread: bool,
    scheduler_ready: bool,
    in_IRQ: bool,
    in_async_task: bool,
    processor_ID: u32,
    spinlock_count: u64,
    cpu: ?*CPU,
    async_task_list: SimpleList,
    //
    //pub fn get() callconv(.Inline) ?*@This()
    //{
        //return asm volatile(
                //\\mov %%gs:0x0, %[out]
                //: [out] "=r" (-> ?*@This())
        //);
    //}

    //fn set(storage: *@This()) callconv(.Inline) void
    //{
        //asm volatile(
            //\\mov %[in], %%gs:0x0
            //:
            //: [in] "r" (storage)
        //);
    //}
    //extern fn set(storage: *LocalStorage) callconv(.C) void;
};

pub const InterruptContext = extern struct
{
    cr2: u64,
    ds: u64,
    fx_save: [512 + 16]u8,
    _check: u64,
    cr8: u64,
    r15: u64,
    r14: u64,
    r13: u64,
    r12: u64,
    r11: u64,
    r10: u64,
    r9: u64,
    r8: u64,
    rbp: u64,
    rdi: u64,
    rsi: u64,
    rdx: u64,
    rcx: u64,
    rbx: u64,
    rax: u64,
    interrupt_number: u64,
    error_code: u64,
    rip: u64,
    cs: u64,
    flags: u64,
    rsp: u64,
    ss: u64,

    fn sanity_check(self: *@This()) void
    {
        if (self.cs > 0x100 or
            self.ds > 0x100 or
            self.ss > 0x100 or
            (self.rip >= 0x1000000000000 and self.rip < 0xFFFF000000000000) or
            (self.rip < 0xFFFF800000000000 and self.cs == 0x48))
        {
            kernel.panic("context sanity check failed\n");
        }
    }

};

pub const AddressSpace = extern struct
{
    cr3: u64,
    commit: extern struct
    {
        L1: [*]u8,
        commit_L1: [L1_commit_commit_size]u8,
        L2: [L2_commit_size]u8,
        L3: [L3_commit_size]u8,
    },
    commited_page_table_count: u64,
    active_page_table_count: u64,
    mutex: Mutex,

    const L1_commit_size = 1 << 23;
    const L1_commit_commit_size = 1 << 8;
    const L2_commit_size = 1 << 14;
    const L3_commit_size = 1 << 5;
};

export var core_L1_commit: [(0xFFFF800200000000 - 0xFFFF800100000000) >> (entry_per_page_table_bit_count + page_bit_count + 3)]u8 = undefined;

pub const CPU = extern struct
{
    processor_ID: u8,
    kernel_processor_ID: u8,
    APIC_ID: u8,
    boot_processor: bool,
    kernel_stack: *align(1) u64,
    local_storage: ?*LocalStorage,
};

pub extern fn set_address_space(address_space: *AddressSpace) callconv(.C) void;
pub export fn finalize_address_space(space: *memory.AddressSpace) callconv(.C) void
{
    _ = space;
    TODO(@src());
}
pub export fn FindRootSystemDescriptorPointer() callconv(.C) u64
{
    const UEFI_RSDP = @intToPtr(*u64, low_memory_map_start + bootloader_information_offset + 0x7fe8).*;
    if (UEFI_RSDP != 0) return UEFI_RSDP;

    var search_regions: [2]memory.Physical.MemoryRegion = undefined;
    search_regions[0].base_address = @as(u64, @intToPtr(*u16, low_memory_map_start + 0x40e * @sizeOf(u16)).* << 4) + low_memory_map_start;
    search_regions[0].page_count = 0x400;
    search_regions[1].base_address = 0xe0000 + low_memory_map_start;
    search_regions[1].page_count = 0x20000;

    for (search_regions) |search_region|
    {
        var address = search_region.base_address;
        while (address < search_region.base_address + search_region.page_count) : (address += 16)
        {
            const rsdp = @intToPtr(*ACPI.RootSystemDescriptorPointer, address);

            if (rsdp.signature != ACPI.RootSystemDescriptorPointer.signature)
            {
                continue;
            }

            if (rsdp.revision == 0)
            {
                if (EsMemorySumBytes(@ptrCast([*]u8, rsdp), 20) != 0) continue;

                return @ptrToInt(rsdp) - low_memory_map_start;
            }
            else if (rsdp.revision == 2)
            {
                if (EsMemorySumBytes(@ptrCast([*]u8, rsdp), @sizeOf(ACPI.RootSystemDescriptorPointer)) != 0) continue;
                return @ptrToInt(rsdp) - low_memory_map_start;
            }
        }
    }

    return 0;
}

export var pciConfigSpinlock: Spinlock = undefined;
export var ipiLock: Spinlock = undefined;

pub const IPI = struct
{
    pub const yield = 0x41;
    pub const call_function_on_all_processors = 0xf0;
    pub const tlb_shootdown = 0xf1;
    pub const kernel_panic = 0;

    pub fn send(interrupt: u64, nmi: bool, processor_ID: i32) callconv(.C) u64
    {
        if (interrupt != IPI.kernel_panic) ipiLock.assert_locked();

        var ignored: u64 = 0;

        for (ACPI.driver.processors[0..ACPI.driver.processor_count]) |*processor|
        {
            if (processor_ID != -1)
            {
                if (processor_ID != processor.kernel_processor_ID)
                {
                    ignored += 1;
                    continue;
                }
            }
            else
            {
                if (processor == get_local_storage().?.cpu or processor.local_storage == null or !processor.local_storage.?.scheduler_ready)
                {
                    ignored += 1;
                    continue;
                }
            }

            const destination = @intCast(u32, processor.APIC_ID) << 24;
            const command = @intCast(u32, interrupt | (1 << 14) | if (nmi) @as(u32, 0x400) else @as(u32, 0));
            LAPIC.write(0x310 >> 2, destination);
            LAPIC.write(0x300 >> 2, command);

            while (LAPIC.read(0x300 >> 2) & (1 << 12) != 0) { }
        }

        return ignored;
    }
    pub fn send_yield(thread: *Thread) callconv(.C) void
    {
        thread.received_yield_IPI.write_volatile(false);
        ipiLock.acquire();
        _ = IPI.send(IPI.yield, false, -1);
        ipiLock.release();
        while (!thread.received_yield_IPI.read_volatile()) {}
    }
};

const LAPIC = struct
{
    fn write(register: u32, value: u32) void
    {
        ACPI.driver.LAPIC_address[register] = value;
    }

    fn read(register: u32) u32
    {
        return ACPI.driver.LAPIC_address[register];
    }

    fn next_timer(ms: u64) void
    {
        LAPIC.write(0x320 >> 2, timer_interrupt | (1 << 17));
        LAPIC.write(0x380 >> 2, @intCast(u32, ACPI.driver.LAPIC_ticks_per_ms * ms));
    }

    fn end_of_interrupt() void
    {
        LAPIC.write(0xb0 >> 2, 0);
    }
};

export var tlbShootdownVirtualAddress: Volatile(u64) = undefined;
export var tlbShootdownPageCount: Volatile(u64) = undefined;

const CallFunctionOnAllProcessorsCallback = fn() void;
export var callFunctionOnAllProcessorsCallback: CallFunctionOnAllProcessorsCallback = undefined;
export var callFunctionOnAllProcessorsRemaining: Volatile(u64) = undefined;

const timer_interrupt = 0x40;
const irq_base = 0x50;

const interrupt_vector_msi_start = 0x70;
const interrupt_vector_msi_count = 0x40;

fn ArchCallFunctionOnAllProcessors(callback: CallFunctionOnAllProcessorsCallback, including_this_processor: bool) void
{
    ipiLock.assert_locked();
    //if (callback == 0) kernel.panic("Callback is null");

    const cpu_count = ACPI.driver.processor_count;
    if (cpu_count > 1)
    {
        @ptrCast(*volatile CallFunctionOnAllProcessorsCallback, &callFunctionOnAllProcessorsCallback).* = callback;
        callFunctionOnAllProcessorsRemaining.write_volatile(cpu_count);
        const ignored = IPI.send(IPI.call_function_on_all_processors, false, -1);
        _ = callFunctionOnAllProcessorsRemaining.atomic_fetch_sub(ignored);
        while (callFunctionOnAllProcessorsRemaining.read_volatile() != 0) { }
        // @TODO: do some stats here but static variables inside functions don't translate well to Zig. Figure out the way to port it properly
    }
    
    if (including_this_processor) callback();
}

const invalidate_all_pages_threshold = 1024;

fn TLBShootdownCallback() void
{
    const page_count = tlbShootdownPageCount.read_volatile();
    if (page_count > invalidate_all_pages_threshold)
    {
        ProcessorInvalidateAllPages();
    }
    else
    {
        var i: u64 = 0;
        var page = tlbShootdownVirtualAddress.read_volatile();

        while (i < page_count) : ({i += 1; page += page_size; })
        {
            invalidate_page(page);
        }
    }
}

pub const KIRQHandler = fn(interrupt_index: u64, context: u64) callconv(.C) bool;
pub const MSIHandler = extern struct
{
    callback: ?KIRQHandler,
    context: u64,
};

pub const IRQHandler = extern struct
{
    callback: KIRQHandler,
    context: u64,
    line: i64,
    pci_device: u64, // @ABICompatibility
    owner_name: u64, // @ABICompatibility
};

pub export var pciIRQLines: [0x100][4]u8 = undefined;
pub export var msiHandlers: [interrupt_vector_msi_count]MSIHandler = undefined;
pub export var irqHandlers: [0x40]IRQHandler = undefined;
pub export var irqHandlersLock: Spinlock = undefined;

pub export var physicalMemoryRegions: [*]memory.Physical.MemoryRegion = undefined;
pub export var physicalMemoryRegionsCount: u64 = undefined;
pub export var physicalMemoryRegionsPagesCount: u64 = undefined;
pub export var physicalMemoryOriginalPagesCount: u64 = undefined;
pub export var physicalMemoryRegionsIndex: u64 = undefined;
pub export var physicalMemoryHighest: u64 = undefined;

const PageTables = extern struct
{
    fn access(comptime level: Level, indices: Indices) *volatile u64
    {
        return access_at_index(level, indices[@enumToInt(level)]);
    }

    fn access_at_index(comptime level: Level, index: u64) *volatile u64
    {
        return switch (level)
        {
            .level1 => @intToPtr(*volatile u64, 0xFFFFFF0000000000 + index * @sizeOf(u64)),
            .level2 => @intToPtr(*volatile u64, 0xFFFFFF7F80000000 + index * @sizeOf(u64)),
            .level3 => @intToPtr(*volatile u64, 0xFFFFFF7FBFC00000 + index * @sizeOf(u64)),
            .level4 => @intToPtr(*volatile u64, 0xFFFFFF7FBFDFE000 + index * @sizeOf(u64)),
        };
    }

    //fn write(level: Level, indices: Indices, value: u64) void
    //{
        //write_at_index(level, indices[@enumToInt(level)], value);
    //}

    //fn write_at_index(comptime level: Level, index: u64, value: u64) void
    //{
        //const levels = [4][*]volatile u64
        //{
            //@intToPtr([*]volatile u64, 0xFFFFFF0000000000),
            //@intToPtr([*]volatile u64, 0xFFFFFF7F80000000),
            //@intToPtr([*]volatile u64, 0xFFFFFF7FBFC00000),
            //@intToPtr([*]volatile u64, 0xFFFFFF7FBFDFE000),
        //};
        //levels[@enumToInt(level)][index] = value;
    //}

    //fn take_address_of_element(comptime level: Level, index: u64) u64
    //{
        //const levels = [4][*]volatile u64
        //{
            //@intToPtr([*]volatile u64, 0xFFFFFF0000000000),
            //@intToPtr([*]volatile u64, 0xFFFFFF7F80000000),
            //@intToPtr([*]volatile u64, 0xFFFFFF7FBFC00000),
            //@intToPtr([*]volatile u64, 0xFFFFFF7FBFDFE000),
        //};
        //return @ptrToInt(&levels[@enumToInt(level)][index]);
    //}

    const Indices = [PageTables.Level.count]u64;
    fn compute_indices(virtual_address: u64) callconv(.Inline) Indices
    {
        var indices: Indices = undefined;
        inline for (comptime std.enums.values(PageTables.Level)) |value|
        {
            indices[@enumToInt(value)] = virtual_address >> (page_bit_count + entry_per_page_table_bit_count * @enumToInt(value));
        }

        return indices;
    }
    const Level = enum(u8)
    {
        level1 = 0,
        level2 = 1,
        level3 = 2,
        level4 = 3,

        const count = std.enums.values(PageTables.Level).len;
    };
};

pub fn free_address_space(space: *memory.AddressSpace) callconv(.C) void
{
    var i: u64 = 0;
    while (i < 256) : (i += 1)
    {
        if (PageTables.access_at_index(.level4, i).* == 0) continue;

        var j = i * entry_per_page_table_count;
        while (j < (i + 1) * entry_per_page_table_count) : (j += 1)
        {
            if (PageTables.access_at_index(.level3, j).* == 0) continue;

            var k = j * entry_per_page_table_count;
            while (k < (j + 1) * entry_per_page_table_count) : (k += 1)
            {
                if (PageTables.access_at_index(.level2, k).* == 0) continue;

                memory.physical_free(PageTables.access_at_index(.level2, k).* & ~@as(u64, page_size - 1), false, 1);
                space.arch.active_page_table_count -= 1;
            }

            memory.physical_free(PageTables.access_at_index(.level3, j).* & ~@as(u64, page_size - 1), false, 1);
            space.arch.active_page_table_count -= 1;
        }

        memory.physical_free(PageTables.access_at_index(.level4, i).* & ~@as(u64, page_size - 1), false, 1);
        space.arch.active_page_table_count -= 1;
    }

    if (space.arch.active_page_table_count != 0)
    {
        kernel.panic("space has still active page tables");
    }

    _ = kernel.core_address_space.reserve_mutex.acquire();
    const l1_commit_region = kernel.core_address_space.find_region(@ptrToInt(space.arch.commit.L1)).?;
    unmap_pages(&kernel.core_address_space, l1_commit_region.descriptor.base_address, l1_commit_region.descriptor.page_count, memory.UnmapPagesFlags.from_flag(.free), 0, null);
    kernel.core_address_space.unreserve(l1_commit_region, false, false);
    kernel.core_address_space.reserve_mutex.release();
    memory.decommit(space.arch.commited_page_table_count * page_size, true);
}

const IO_PIC_1_COMMAND = (0x0020);
const IO_PIC_1_DATA = (0x0021);
const IO_PIT_DATA = (0x0040);
const IO_PIT_COMMAND = (0x0043);
const IO_PS2_DATA = (0x0060);
const IO_PC_SPEAKER = (0x0061);
const IO_PS2_STATUS = (0x0064);
const IO_PS2_COMMAND = (0x0064);
const IO_RTC_INDEX  = (0x0070);
const IO_RTC_DATA  = (0x0071);
const IO_UNUSED_DELAY = (0x0080);
const IO_PIC_2_COMMAND = (0x00A0);
const IO_PIC_2_DATA = (0x00A1);
const IO_BGA_INDEX = (0x01CE);
const IO_BGA_DATA = (0x01CF);
const IO_ATA_1 = (0x0170); // To 0x0177.;
const IO_ATA_2 = (0x01F0); // To 0x01F7.;
const IO_COM_4 = (0x02E8); // To 0x02EF.;
const IO_COM_2 = (0x02F8); // To 0x02FF.;
const IO_ATA_3 = (0x0376);
const IO_VGA_AC_INDEX  = (0x03C0);
const IO_VGA_AC_WRITE  = (0x03C0);
const IO_VGA_AC_READ   = (0x03C1);
const IO_VGA_MISC_WRITE  = (0x03C2);
const IO_VGA_MISC_READ   = (0x03CC);
const IO_VGA_SEQ_INDEX  = (0x03C4);
const IO_VGA_SEQ_DATA   = (0x03C5);
const IO_VGA_DAC_READ_INDEX   = (0x03C7);
const IO_VGA_DAC_WRITE_INDEX  = (0x03C8);
const IO_VGA_DAC_DATA         = (0x03C9);
const IO_VGA_GC_INDEX  = (0x03CE);
const IO_VGA_GC_DATA   = (0x03CF);
const IO_VGA_CRTC_INDEX  = (0x03D4);
const IO_VGA_CRTC_DATA   = (0x03D5);
const IO_VGA_INSTAT_READ  = (0x03DA);
const IO_COM_3 = (0x03E8); // To 0x03EF.;
const IO_ATA_4 = (0x03F6);
const IO_COM_1 = (0x03F8); // To 0x03FF.;
const IO_PCI_CONFIG  = (0x0CF8);
const IO_PCI_DATA    = (0x0CFC);

pub export fn EarlyDelay1Ms() callconv(.C) void
{
    out8(IO_PIT_COMMAND, 0x30);
    out8(IO_PIT_DATA, 0xa9);
    out8(IO_PIT_DATA, 0x04);

    while (true)
    {
        out8(IO_PIT_COMMAND, 0xe2);

        if (in8(IO_PIT_DATA) & (1 << 7) != 0) break;
    }
}

pub export var timeStampTicksPerMs: u64 = undefined;

const NewProcessorStorage = extern struct
{
    local: *LocalStorage,
    gdt: u64,

    fn allocate(cpu: *CPU) @This()
    {
        var storage: @This() = undefined;
        storage.local = @intToPtr(*LocalStorage, kernel.heapFixed.allocate(@sizeOf(LocalStorage), true));
        const gdt_physical_address = memory.physical_allocate_with_flags(memory.Physical.Flags.from_flag(.commit_now));
        storage.gdt = kernel.address_space.map_physical(gdt_physical_address, page_size, memory.Region.Flags.empty());
        storage.local.cpu = cpu;
        cpu.local_storage = storage.local;
        storage.local.async_task_thread = Thread.spawn(GetAsyncTaskThreadAddress(), 0, Thread.Flags.from_flag(.async_task), null, 0);
        storage.local.idle_thread = Thread.spawn(0, 0, Thread.Flags.from_flag(.idle), null, 0);
        storage.local.current_thread = storage.local.idle_thread;
        storage.local.processor_ID = @intCast(u32, @atomicRmw(@TypeOf(kernel.scheduler.next_processor_id), &kernel.scheduler.next_processor_id, .Add, 1, .SeqCst));
        if (storage.local.processor_ID >= kernel.max_processors) kernel.panic("cpu max count exceeded");
        cpu.kernel_processor_ID = @intCast(u8, storage.local.processor_ID);
        return storage;
    }
};

pub fn init() callconv(.C) void
{
    ACPI.driver.parse_tables();

    const bootstrap_LAPIC_ID = @intCast(u8, LAPIC.read(0x20 >> 2) >> 24);

    const current_cpu = blk:
    {
        for (ACPI.driver.processors[0..ACPI.driver.processor_count]) |*processor|
        {
            if (processor.APIC_ID == bootstrap_LAPIC_ID)
            {
                processor.boot_processor = true;
                break :blk processor;
            }
        }

        kernel.panic("could not find the bootstrap processor");
    };

    disable_interrupts();
    const start = ProcessorReadTimeStamp();
    LAPIC.write(0x380 >> 2, std.math.maxInt(u32));
    var i: u64 = 0;
    while (i < 8) : (i += 1)
    {
        EarlyDelay1Ms();
    }

    ACPI.driver.LAPIC_ticks_per_ms = (std.math.maxInt(u32) - LAPIC.read(0x390 >> 2)) >> 4;
    kernel.rng.add_entropy(LAPIC.read(0x390 >> 2));

    const end = ProcessorReadTimeStamp();
    timeStampTicksPerMs = (end - start) >> 3;
    enable_interrupts();

    var storage = NewProcessorStorage.allocate(current_cpu);
    SetupProcessor2(&storage);
}

var get_time_from_PIT_ms_started = false;
var get_time_from_PIT_ms_cumulative: u64 = 0;
var get_time_from_PIT_ms_last: u64 = 0;

export fn ArchGetTimeFromPITMs() callconv(.C) u64
{
    if (!get_time_from_PIT_ms_started)
    {
        out8(IO_PIT_COMMAND, 0x30);
        out8(IO_PIT_DATA, 0xff);
        out8(IO_PIT_DATA, 0xff);
        get_time_from_PIT_ms_started = true;
        get_time_from_PIT_ms_last = 0xffff;
        return 0;
    }
    else
    {
        out8(IO_PIT_COMMAND, 0);
        var x: u16 = in8(IO_PIT_DATA);
        x |= @as(u16, in8(IO_PIT_DATA)) << 8;
        get_time_from_PIT_ms_cumulative += get_time_from_PIT_ms_last - x;
        if (x > get_time_from_PIT_ms_last) get_time_from_PIT_ms_cumulative += 0x10000;
        get_time_from_PIT_ms_last = x;
        return get_time_from_PIT_ms_cumulative * 1000 / 1193182;
    }
}

pub export fn get_time_ms() callconv(.C) u64
{
    timeStampCounterSynchronizationValue.write_volatile(((timeStampCounterSynchronizationValue.read_volatile() & 0x8000000000000000) ^ 0x8000000000000000) | ProcessorReadTimeStamp());
    if (ACPI.driver.HPET_base_address != null and ACPI.driver.HPET_period != 0)
    {
        const fs_to_ms = 1000000000000;
        const reading: u128 = ACPI.driver.HPET_base_address.?[30];
        return @intCast(u64, reading * ACPI.driver.HPET_period / fs_to_ms);
    }

    return ArchGetTimeFromPITMs();
}

pub export fn populate_pageframe_database() callconv(.C) u64
{
    var commit_limit: u64 = 0;

    for (physicalMemoryRegions[0..physicalMemoryRegionsCount]) |*region|
    {
        const base = region.base_address >> page_bit_count;
        const count = region.page_count;
        commit_limit += count;

        var i: u64 = 0;
        while (i < count) : (i += 1)
        {
            memory.physical_insert_free_pages_next(base + i);
        }
    }

    physicalMemoryRegionsPagesCount = 0;
    return commit_limit;
}

export fn MMArchGetPhysicalMemoryHighest() callconv(.C) u64
{
    return physicalMemoryHighest;
}

pub fn memory_init() callconv(.C) void
{
    const cr3 = ProcessorReadCR3();
    kernel.address_space.arch.cr3 = cr3;
    kernel.core_address_space.arch.cr3 = cr3;

    kernel.mmCoreRegions[0].descriptor.base_address = core_address_space_start;
    kernel.mmCoreRegions[0].descriptor.page_count = core_address_space_size / page_size;

    var i: u64 = 0x100;
    while (i < 0x200) : (i += 1)
    {
        if (PageTables.access_at_index(.level4, i).* == 0)
        {
            PageTables.access_at_index(.level4, i).* = memory.physical_allocate_with_flags(memory.Physical.Flags.empty()) | 0b11;
            EsMemoryZero(@ptrToInt(PageTables.access_at_index(.level3, i * 0x200)), page_size);
        }
    }

    kernel.core_address_space.arch.commit.L1 = &core_L1_commit;
    _ = kernel.core_address_space.reserve_mutex.acquire();
    kernel.address_space.arch.commit.L1 = @intToPtr([*]u8, kernel.core_address_space.reserve(AddressSpace.L1_commit_size, memory.Region.Flags.from_flags(.{ .normal, .no_commit_tracking, .fixed }), 0).?.descriptor.base_address);
    kernel.core_address_space.reserve_mutex.release();
}
pub export fn EarlyAllocatePage() callconv(.C) u64
{
    const index = blk:
    {

        for (physicalMemoryRegions[0..physicalMemoryRegionsCount]) |*region, region_i|
        {
            if (region.page_count != 0)
            {
                break :blk physicalMemoryRegionsIndex + region_i;
            }
        }

        kernel.panic("Unable to early allocate a page\n");
    };

    const region = &physicalMemoryRegions[index];
    const page = region.base_address;

    region.base_address += page_size;
    region.page_count -= 1;
    physicalMemoryRegionsPagesCount -= 1;
    physicalMemoryRegionsIndex = index;

    return page;
}

export fn PCProcessMemoryMap() callconv(.C) void
{
    physicalMemoryRegions = @intToPtr([*]memory.Physical.MemoryRegion, low_memory_map_start + 0x60000 + bootloader_information_offset);

    var region_i: u64 = 0;
    while (physicalMemoryRegions[region_i].base_address != 0) : (region_i += 1)
    {
        const region = &physicalMemoryRegions[region_i];
        const end = region.base_address + (region.page_count << page_bit_count);
        physicalMemoryRegionsPagesCount += region.page_count;
        if (end > physicalMemoryHighest) physicalMemoryHighest = end;
        physicalMemoryRegionsCount += 1;
    }

    physicalMemoryRegionsPagesCount = physicalMemoryRegions[physicalMemoryRegionsCount].page_count;
}

export fn ProcessorOut8Delayed(port: u16, value: u8) callconv(.C) void
{
    out8(port, value);
    _ = in8(IO_UNUSED_DELAY);
}

export fn MMArchIsBufferInUserRange(base_address: u64, byte_count: u64) callconv(.C) bool
{
    if (base_address & 0xFFFF800000000000 != 0) return false;
    if (byte_count & 0xFFFF800000000000 != 0) return false;
    if ((base_address + byte_count) & 0xFFFF800000000000 != 0) return false;
    return true;
}

export fn PCSetupCOM1() callconv(.C) void
{
    ProcessorOut8Delayed(IO_COM_1 + 1, 0x00);
    ProcessorOut8Delayed(IO_COM_1 + 3, 0x80);
    ProcessorOut8Delayed(IO_COM_1 + 0, 0x03);
    ProcessorOut8Delayed(IO_COM_1 + 1, 0x00);
    ProcessorOut8Delayed(IO_COM_1 + 3, 0x03);
    ProcessorOut8Delayed(IO_COM_1 + 2, 0xC7);
    ProcessorOut8Delayed(IO_COM_1 + 4, 0x0B);

    // Print a divider line.
    var i: u64 = 0;
    while (i < 10) : (i += 1)
    {
        debug_output_byte('-');
    }
    debug_output_byte('\r');
    debug_output_byte('\n');
}

pub export fn PCDisablePIC() callconv(.C) void
{
    // Remap the ISRs sent by the PIC to 0x20 - 0x2F.
    // Even though we'll mask the PIC to use the APIC, 
    // we have to do this so that the spurious interrupts are sent to a reasonable vector range.
    ProcessorOut8Delayed(IO_PIC_1_COMMAND, 0x11);
    ProcessorOut8Delayed(IO_PIC_2_COMMAND, 0x11);
    ProcessorOut8Delayed(IO_PIC_1_DATA, 0x20);
    ProcessorOut8Delayed(IO_PIC_2_DATA, 0x28);
    ProcessorOut8Delayed(IO_PIC_1_DATA, 0x04);
    ProcessorOut8Delayed(IO_PIC_2_DATA, 0x02);
    ProcessorOut8Delayed(IO_PIC_1_DATA, 0x01);
    ProcessorOut8Delayed(IO_PIC_2_DATA, 0x01);

    // Mask all interrupts.
    ProcessorOut8Delayed(IO_PIC_1_DATA, 0xFF);
    ProcessorOut8Delayed(IO_PIC_2_DATA, 0xFF);
}

pub export fn next_timer(ms: u64) callconv(.C) void
{
    while (!kernel.scheduler.started.read_volatile()) { }
    get_local_storage().?.scheduler_ready = true;
    LAPIC.next_timer(ms);
}

pub export fn commit_page_tables(space: *memory.AddressSpace, region: *memory.Region) callconv(.C) bool
{
    _ = space.reserve_mutex.assert_locked();

    const base = (region.descriptor.base_address - @as(u64, if (space == &kernel.core_address_space) core_address_space_start else 0)) & 0x7FFFFFFFF000;
    const end = base + (region.descriptor.page_count << page_bit_count);
    var needed: u64 = 0;

    var i = base;
    while (i < end)
    {
        const shifter: u64 = page_bit_count + entry_per_page_table_bit_count * 3;
        const index = i >> shifter;
        const increment = space.arch.commit.L3[index >> 3] & (@as(u8, 1) << @truncate(u3, index & 0b111)) == 0;
        needed += @boolToInt(increment);
        i = (index << shifter) + (1 << shifter);
    }

    i = base;
    while (i < end)
    {
        const shifter: u64 = page_bit_count + entry_per_page_table_bit_count * 2;
        const index = i >> shifter;
        const increment = space.arch.commit.L2[index >> 3] & (@as(u8, 1) << @truncate(u3, index & 0b111)) == 0;
        needed += @boolToInt(increment);
        i = (index << shifter) + (1 << shifter);
    }

    var previous_index_l2i: u64 = std.math.maxInt(u64);
    i = base;
    while (i < end)
    {
        const shifter: u64 = page_bit_count + entry_per_page_table_bit_count;
        const index = i >> shifter;
        const index_l2i = index >> 15;

        if (space.arch.commit.commit_L1[index_l2i >> 3] & (@as(u8, 1) << @truncate(u3, index_l2i & 0b111)) == 0)
        {
            if (previous_index_l2i != index_l2i)
            {
                needed += 2;
            }
            else
            {
                needed += 1;
            }
        }
        else
        {
            const increment = space.arch.commit.L1[index >> 3] & (@as(u8, 1) << @truncate(u3, index & 0b111)) == 0;
            needed += @boolToInt(increment);
        }

        previous_index_l2i = index_l2i;
        i = index << shifter;
        i += 1 << shifter;
    }

    if (needed != 0)
    {
        if (!memory.commit(needed * page_size, true))
        {
            return false;
        }
        space.arch.commited_page_table_count += needed;
    }

    i = base;
    while (i < end)
    {
        const shifter: u64 = page_bit_count + entry_per_page_table_bit_count * 3;
        const index = i >> shifter;
        space.arch.commit.L3[index >> 3] |= @as(u8, 1) << @truncate(u3, index & 0b111);
        i = index << shifter;
        i += 1 << shifter;
    }

    i = base;
    while (i < end)
    {
        const shifter: u64 = page_bit_count + entry_per_page_table_bit_count * 2;
        const index = i >> shifter;
        space.arch.commit.L2[index >> 3] |= @as(u8, 1) << @truncate(u3, index & 0b111);
        i = index << shifter;
        i += 1 << shifter;
    }

    i = base;
    while (i < end)
    {
        const shifter: u64 = page_bit_count + entry_per_page_table_bit_count;
        const index = i >> shifter;
        const index_L2i = index >> 15;
        space.arch.commit.commit_L1[index_L2i >> 3] |= @as(u8, 1) << @truncate(u3, index_L2i & 0b111);
        space.arch.commit.L1[index >> 3] |= @as(u8, 1) << @truncate(u3, index & 0b111);
        i = index << shifter;
        i += 1 << shifter;
    }

    return true;
}

fn handle_missing_page_table(space: *memory.AddressSpace, comptime level: PageTables.Level, indices: PageTables.Indices, flags: memory.MapPageFlags) callconv(.Inline) void
{
    assert(level != .level1);

    if (PageTables.access(level, indices).* & 1 == 0)
    {
        if (flags.contains(.no_new_tables)) kernel.panic("no new tables flag set but a table was missing\n");

        const physical_allocation_flags = memory.Physical.Flags.from_flag(.lock_acquired);
        const physical_allocation = memory.physical_allocate_with_flags(physical_allocation_flags) | 0b111;
        PageTables.access(level, indices).* = physical_allocation;
        const previous_level = comptime @intToEnum(PageTables.Level, @enumToInt(level) - 1);

        const page = @ptrToInt(PageTables.access_at_index(previous_level, indices[@enumToInt(previous_level)]));
        invalidate_page(page);
        const page_slice = @intToPtr([*]u8, page & ~@as(u64, page_size - 1))[0..page_size];
        std.mem.set(u8, page_slice, 0);
        space.arch.active_page_table_count += 1;
    }
}

pub export fn map_page(space: *memory.AddressSpace, asked_physical_address: u64, asked_virtual_address: u64, flags: memory.MapPageFlags) callconv(.C) bool
{
    if ((asked_virtual_address | asked_physical_address) & (page_size - 1) != 0)
    {
        kernel.panic("Mapping pages that are not aligned\n");
    }

    if (kernel.pmm.pageframeDatabaseCount != 0 and (asked_physical_address >> page_bit_count) < kernel.pmm.pageframeDatabaseCount)
    {
        const frame_state = kernel.pmm.pageframes[asked_physical_address >> page_bit_count].state.read_volatile();
        if (frame_state != .active and frame_state != .unusable)
        {
            kernel.panic("Physical pageframe not marked as active or unusable\n");
        }
    }

    if (asked_physical_address == 0) kernel.panic("Attempt to map physical page 0\n");
    if (asked_virtual_address == 0) kernel.panic("Attempt to map virtual page 0\n");

    if (asked_virtual_address < 0xFFFF800000000000 and ProcessorReadCR3() != space.arch.cr3)
    {
        kernel.panic("Attempt to map page into another address space\n");
    }

    const acquire_framelock = !flags.contains(.no_new_tables) and !flags.contains(.frame_lock_acquired);
    if (acquire_framelock) _ = kernel.pmm.pageframe_mutex.acquire();
    defer if (acquire_framelock) kernel.pmm.pageframe_mutex.release();

    const acquire_spacelock = !flags.contains(.no_new_tables);
    if (acquire_spacelock) _ = space.arch.mutex.acquire();
    defer if (acquire_spacelock) space.arch.mutex.release();

    const physical_address = asked_physical_address & 0xFFFFFFFFFFFFF000;
    const virtual_address = asked_virtual_address & 0x0000FFFFFFFFF000;

    const indices = PageTables.compute_indices(virtual_address);

    if (space != &kernel.core_address_space and space != &kernel.address_space)
    {
        const index_L4 = indices[@enumToInt(PageTables.Level.level4)];
        if (space.arch.commit.L3[index_L4 >> 3] & (@as(u8, 1) << @truncate(u3, index_L4 & 0b111)) == 0) kernel.panic("attempt to map using uncommited L3 page table\n");

        const index_L3 = indices[@enumToInt(PageTables.Level.level3)];
        if (space.arch.commit.L2[index_L3 >> 3] & (@as(u8, 1) << @truncate(u3, index_L3 & 0b111)) == 0) kernel.panic("attempt to map using uncommited L3 page table\n");

        const index_L2 = indices[@enumToInt(PageTables.Level.level2)];
        if (space.arch.commit.L1[index_L2 >> 3] & (@as(u8, 1) << @truncate(u3, index_L2 & 0b111)) == 0) kernel.panic("attempt to map using uncommited L3 page table\n");
    }

    handle_missing_page_table(space, .level4, indices, flags);
    handle_missing_page_table(space, .level3, indices, flags);
    handle_missing_page_table(space, .level2, indices, flags);

    const old_value = PageTables.access(.level1, indices).*;
    var value = physical_address | 0b11;

    if (flags.contains(.write_combining)) value |= 16;
    if (flags.contains(.not_cacheable)) value |= 24;
    if (flags.contains(.user)) value |= 7 else value |= 1 << 8;
    if (flags.contains(.read_only)) value &= ~@as(u64, 2);
    if (flags.contains(.copied)) value |= 1 << 9;

    value |= (1 << 5);
    value |= (1 << 6);

    if (old_value & 1 != 0 and !flags.contains(.overwrite))
    {
        if (flags.contains(.ignore_if_mapped))
        {
            return false;
        }

        if (old_value & ~@as(u64, page_size - 1) != physical_address)
        {
            kernel.panic("attempt to map page tha has already been mapped\n");
        }

        if (old_value == value)
        {
            kernel.panic("attempt to rewrite page translation\n");
        }
        else
        {
            const page_become_writable = old_value & 2 == 0 and value & 2 != 0;
            if (!page_become_writable)
            {
                kernel.panic("attempt to change flags mapping address\n");
            }
        }
    }

    PageTables.access(.level1, indices).* = value;

    invalidate_page(asked_virtual_address);

    return true;
}

pub export fn translate_address(virtual_address: u64, write_access: bool) callconv(.C) u64
{
    const address = virtual_address & 0x0000FFFFFFFFF000;
    const indices = PageTables.compute_indices(address);
    if (PageTables.access(.level4, indices).* & 1 == 0) return 0;
    if (PageTables.access(.level3, indices).* & 1 == 0) return 0;
    if (PageTables.access(.level2, indices).* & 1 == 0) return 0;

    const physical_address = PageTables.access(.level1, indices).*;

    if (write_access and physical_address & 2 == 0) return 0;
    if (physical_address & 1 == 0) return 0;
    return physical_address & 0x0000FFFFFFFFF000;
}

pub export fn handle_page_fault(fault_address: u64, flags: memory.HandlePageFaultFlags) bool
{
    const virtual_address = fault_address & ~@as(u64, page_size - 1);
    const for_supervisor = flags.contains(.for_supervisor);

    if (!are_interrupts_enabled())
    {
        kernel.panic("Page fault with interrupts disabled\n");
    }

    const fault_in_very_low_memory = virtual_address < page_size;
    if (!fault_in_very_low_memory)
    {
        if (virtual_address >= low_memory_map_start and virtual_address < low_memory_map_start + low_memory_limit and for_supervisor)
        {
            const physical_address = virtual_address - low_memory_map_start;
            const map_page_flags = memory.MapPageFlags.from_flag(.commit_tables_now);
          _ = map_page(&kernel.address_space, physical_address, virtual_address, map_page_flags);
            return true;
        }
        else if (virtual_address >= core_memory_region_start and virtual_address < core_memory_region_start + core_memory_region_count * @sizeOf(memory.Region) and for_supervisor)
        {
            const physical_allocation_flags = memory.Physical.Flags.from_flag(.zeroed);
            const physical_address = memory.physical_allocate_with_flags(physical_allocation_flags);
            const map_page_flags = memory.MapPageFlags.from_flag(.commit_tables_now);
            _ = map_page(&kernel.address_space, physical_address, virtual_address, map_page_flags);
            return true;
        }
        else if (virtual_address >= core_address_space_start and virtual_address < core_address_space_start + core_address_space_size and for_supervisor)
        {
            return kernel.core_address_space.handle_page_fault(virtual_address, flags);
        }
        else if (virtual_address >= kernel_address_space_start and virtual_address < kernel_address_space_start + kernel_address_space_size and for_supervisor)
        {
            return kernel.address_space.handle_page_fault(virtual_address, flags);
        }
        else if (virtual_address >= modules_start and virtual_address < modules_start + modules_size and for_supervisor)
        {
            return kernel.address_space.handle_page_fault(virtual_address, flags);
        }
        else
        {
            // @Unsafe
            if (get_current_thread()) |current_thread|
            {
                const space = if (current_thread.temporary_address_space) |temporary_address_space| @ptrCast(*memory.AddressSpace, temporary_address_space)
                else current_thread.process.?.address_space;
                return space.handle_page_fault(virtual_address, flags);
            }
            else
            {
                kernel.panic("unreachable path\n");
            }
        }
    }

    return false;
}

export fn ContextSanityCheck(context: *InterruptContext) callconv(.C) void
{
    if (context.cs > 0x100 or
        context.ds > 0x100 or
        context.ss > 0x100 or
        (context.rip >= 0x1000000000000 and context.rip < 0xFFFF000000000000) or
        (context.rip < 0xFFFF800000000000 and context.cs == 0x48))
    {
        kernel.panic("Context sanity check failed");
    }
}

export fn PostContextSwitch(context: *InterruptContext, old_address_space: *memory.AddressSpace) callconv(.C) bool
{
    if (kernel.scheduler.dispatch_spinlock.interrupts_enabled.read_volatile()) kernel.panic ("Interrupts were enabled");

    kernel.scheduler.dispatch_spinlock.release_ex(true);

    const current_thread = get_current_thread().?;
    const local = get_local_storage().?;
    local.cpu.?.kernel_stack.* = current_thread.kernel_stack;

    const new_thread = current_thread.cpu_time_slices.read_volatile() == 1;
    LAPIC.end_of_interrupt();
    ContextSanityCheck(context);
    ProcessorSetThreadStorage(current_thread.tls_address);
    old_address_space.close_reference();
    current_thread.last_known_execution_address = context.rip;

    if (are_interrupts_enabled()) kernel.panic("interrupts were enabled");

    if (local.spinlock_count != 0) kernel.panic("spinlock_count is not zero");

    current_thread.timer_adjust_ticks += ProcessorReadTimeStamp() - local.current_thread.?.last_interrupt_timestamp;

    if (current_thread.timer_adjust_address != 0 and MMArchIsBufferInUserRange(current_thread.timer_adjust_address, @sizeOf(u64)))
    {
        _ = MMArchSafeCopy(current_thread.timer_adjust_address, @ptrToInt(&local.current_thread.?.timer_adjust_ticks), @sizeOf(u64));
    }

    return new_thread;
}

extern fn MMArchSafeCopy(destination_address: u64, source_address: u64, byte_count: u64) callconv(.C) bool;

extern fn GetAsyncTaskThreadAddress() callconv(.C) u64;
comptime
{
    asm(
        \\.intel_syntax noprefix
        \\.global GetAsyncTaskThreadAddress
        \\.extern AsyncTaskThread
        \\GetAsyncTaskThreadAddress:
        \\mov rax, OFFSET AsyncTaskThread
        \\ret
    );
}
export fn SetupProcessor2(storage: *NewProcessorStorage) callconv(.C) void
{
    for (ACPI.driver.LAPIC_NMIs[0..ACPI.driver.LAPIC_NMI_count]) |*nmi|
    {
        if (nmi.processor == 0xff or nmi.processor == storage.local.cpu.?.processor_ID)
        {
            const register_index = (0x350 + (@intCast(u32, nmi.lint_index) << 4)) >> 2;
            var value: u32 = 2 | (1 << 10);
            if (nmi.active_low) value |= 1 << 13;
            if (nmi.level_triggered) value |= 1 << 15;
            LAPIC.write(register_index, value);
        }
    }

    LAPIC.write(0x350 >> 2, LAPIC.read(0x350 >> 2) & ~@as(u32, 1 << 16));
    LAPIC.write(0x360 >> 2, LAPIC.read(0x360 >> 2) & ~@as(u32, 1 << 16));
    LAPIC.write(0x080 >> 2, 0);
    if (LAPIC.read(0x30 >> 2) & 0x80000000 != 0) LAPIC.write(0x410 >> 2, 0);
    LAPIC.end_of_interrupt();

    LAPIC.write(0x3e0 >> 2, 2);
    set_local_storage(storage.local);

    const gdt = storage.gdt;
    const bootstrap_GDT = @intToPtr(*align(1) u64, (@ptrToInt(&processorGDTR) + @sizeOf(u16))).*;
    EsMemoryCopy(gdt, bootstrap_GDT, 2048);
    const tss = gdt + 2048;
    storage.local.cpu.?.kernel_stack = @intToPtr(*align(1) u64, tss + @sizeOf(u32));
    ProcessorInstallTSS(gdt, tss);
}

pub export fn unmap_pages(space: *memory.AddressSpace, virtual_address_start: u64, page_count: u64, flags: memory.UnmapPagesFlags, unmap_maximum: u64, resume_position: ?*u64) callconv(.C) void
{
    _ = kernel.pmm.pageframe_mutex.acquire();
    defer kernel.pmm.pageframe_mutex.release();

    _ = space.arch.mutex.acquire();
    space.arch.mutex.release();

    const table_base = virtual_address_start & 0x0000FFFFFFFFF000;
    const start: u64 = if (resume_position) |rp| rp.* else 0;

    var page = start;
    while (page < page_count) : (page += 1)
    {
        const virtual_address = (page << page_bit_count) + table_base;
        const indices = PageTables.compute_indices(virtual_address);

        comptime var level: PageTables.Level = .level4;
        if (PageTables.access(level, indices).* & 1 == 0)
        {
            page -= (virtual_address >> page_bit_count) % (1 << (entry_per_page_table_bit_count * @enumToInt(level)));
            page += 1 << (entry_per_page_table_bit_count * @enumToInt(level));
            continue;
        }

        level = .level3;
        if (PageTables.access(level, indices).* & 1 == 0)
        {
            page -= (virtual_address >> page_bit_count) % (1 << (entry_per_page_table_bit_count * @enumToInt(level)));
            page += 1 << (entry_per_page_table_bit_count * @enumToInt(level));
            continue;
        }

        level = .level2;
        if (PageTables.access(level, indices).* & 1 == 0)
        {
            page -= (virtual_address >> page_bit_count) % (1 << (entry_per_page_table_bit_count * @enumToInt(level)));
            page += 1 << (entry_per_page_table_bit_count * @enumToInt(level));
            continue;
        }

        const translation = PageTables.access(.level1, indices).*;

        if (translation & 1 == 0) continue; // the page wasnt mapped

        const copy = (translation & (1 << 9)) != 0;

        if (copy and flags.contains(.balance_file) and !flags.contains(.free_copied)) continue; // Ignore copied pages when balancing file mappings

        if ((~translation & (1 << 5) != 0) or (~translation & (1 << 6) != 0))
        {
            kernel.panic("page found without accessed or dirty bit set");
        }

        PageTables.access(.level1, indices).* = 0;
        const physical_address = translation & 0x0000FFFFFFFFF000;

        if (flags.contains(.free) or (flags.contains(.free_copied) and copy))
        {
            memory.physical_free(physical_address, true, 1);
        }
        else if (flags.contains(.balance_file))
        {
            _ = unmap_maximum;
            TODO(@src());
        }
    }

    MMArchInvalidatePages(virtual_address_start, page_count);
}

const syscall_functions = [syscall.Type.count + 1]syscall.Function
{
    kernel.syscall.process_exit,
    undefined,
    undefined,
};
export fn DoSyscall(index: syscall.Type, argument0: u64, argument1: u64, argument2: u64, argument3: u64, batched: bool, fatal: ?*bool, user_stack_pointer: ?*u64) callconv(.C) u64
{
    enable_interrupts();

    const current_thread = get_current_thread().?;
    const current_process = current_thread.process.?;
    const current_address_space = current_process.address_space;

    if (!batched)
    {
        if (current_thread.terminating.read_volatile())
        {
            fake_timer_interrupt();
        }

        if (current_thread.terminatable_state.read_volatile() != .terminatable) kernel.panic("Current thread was not terminatable");

        current_thread.terminatable_state.write_volatile(.in_syscall);
    }

    var return_value: u64 = @enumToInt(FatalError.unknown_syscall);
    var fatal_error = true;

    const function = syscall_functions[@enumToInt(index)];
    if (batched and index == .batch)
    {

    }
    else
    {
        return_value = function(argument0, argument1, argument2, argument3, current_thread, current_process, current_address_space, user_stack_pointer, @ptrCast(*u8, &fatal_error));
    }

    if (fatal) |fatal_u| fatal_u.* = false;

    if (fatal_error)
    {
        if (fatal) |fatal_u| fatal_u.* = true
        else
        {
            var reason = zeroes(CrashReason);
            reason.error_code = @intToEnum(FatalError, return_value);
            reason.during_system_call = @bitCast(i32, @enumToInt(index));
            current_process.crash(&reason);
        }
    }

    if (!batched)
    {
        current_thread.terminatable_state.write_volatile(.terminatable);
        if (current_thread.terminating.read_volatile() or current_thread.paused.read_volatile())
        {
            fake_timer_interrupt();
        }
    }

    return return_value;
}

export fn Syscall(argument0: u64, argument1: u64, argument2: u64, return_address: u64, argument3: u64, argument4: u64, user_stack_pointer: ?*u64) callconv(.C) u64
{
    _ = return_address;
    return DoSyscall(@intToEnum(syscall.Type, argument0), argument1, argument2, argument3, argument4, false, null, user_stack_pointer);
}

pub extern fn GetKernelMainAddress() callconv(.C) u64;
comptime 
{
    asm(
        \\.intel_syntax noprefix
        \\.extern KernelMain
        \\.global GetKernelMainAddress
        \\GetKernelMainAddress:
        \\mov rax, OFFSET KernelMain
        \\ret
    );
}

pub fn pci_read_config32(bus: u8, device: u8, function: u8, offset: u8) u32
{
    return pci_read_config(bus, device, function, offset, 32);
}

pub fn pci_read_config(bus: u8, device: u8, function: u8, offset: u8, size: u32) u32
{
    pciConfigSpinlock.acquire();
    defer pciConfigSpinlock.release();

    if (offset & 3 != 0) kernel.panic("offset is not 4-byte aligned");
    out32(IO_PCI_CONFIG, 0x80000000 | (@intCast(u32, bus) << 16) | (@intCast(u32, device) << 11) | (@intCast(u32, function) << 8) | @intCast(u32, offset));
    if (size == 8) return in8(IO_PCI_DATA);
    if (size == 16) return in16(IO_PCI_DATA);
    if (size == 32) return in32(IO_PCI_DATA);
    kernel.panic("invalid size");
}

pub fn pci_write_config(bus: u8, device: u8, function: u8, offset: u8, value: u32, size: u32) void
{
    pciConfigSpinlock.acquire();
    defer pciConfigSpinlock.release();

    if (offset & 3 != 0) kernel.panic("offset is not 4-byte aligned");
    out32(IO_PCI_CONFIG, 0x80000000 | (@intCast(u32, bus) << 16) | (@intCast(u32, device) << 11) | (@intCast(u32, function) << 8) | @intCast(u32, offset));
    if (size == 8) out8(IO_PCI_DATA, @intCast(u8, value))
    else if (size == 16) out16(IO_PCI_DATA, @intCast(u16, value))
    else if (size == 32) out32(IO_PCI_DATA, value)
    else kernel.panic("Invalid size\n");
}
pub var module_ptr: u64 = modules_start;

pub const MSI = extern struct
{
    address: u64,
    data: u64,
    tag: u64,

    pub fn register(handler: KIRQHandler, context: u64, owner_name: []const u8) @This()
    {
        _ = owner_name;
        irqHandlersLock.acquire();
        defer irqHandlersLock.release();

        for (msiHandlers) |*msi_handler, i|
        {
            if (msi_handler.callback != null) continue;

            msi_handler.* = MSIHandler { .callback = handler, .context = context };

            return .
            {
                .address = 0xfee00000,
                .data = interrupt_vector_msi_start + i,
                .tag = i,
            };
        }

        return zeroes(MSI);
    }

    pub fn unregister(tag: u64) void
    {
        irqHandlersLock.acquire();
        defer irqHandlersLock.release();
        msiHandlers[tag].callback = null;
    }
};
pub export fn initialize_user_space(space: *memory.AddressSpace, region: *memory.Region) callconv(.C) bool
{
    region.descriptor.base_address = user_space_start;
    region.descriptor.page_count = user_space_size / page_size;

    if (!memory.commit(page_size, true)) return false;

    space.arch.cr3 = memory.physical_allocate_with_flags(memory.Physical.Flags.empty());

    {
        _ = kernel.core_address_space.reserve_mutex.acquire();
        defer kernel.core_address_space.reserve_mutex.release();

        const L1_region = kernel.core_address_space.reserve(AddressSpace.L1_commit_size, memory.Region.Flags.from_flags(.{ .normal, .no_commit_tracking, .fixed }), 0) orelse return false;
        space.arch.commit.L1 = @intToPtr([*]u8, L1_region.descriptor.base_address);
    }

    const page_table_address = @intToPtr(?[*]u64, kernel.address_space.map_physical(space.arch.cr3, page_size, memory.Region.Flags.empty())) orelse kernel.panic("Expected page table allocation to be good");
    EsMemoryZero(@ptrToInt(page_table_address), page_size / 2);
    EsMemoryCopy(@ptrToInt(page_table_address) + (0x100 * @sizeOf(u64)), @ptrToInt(PageTables.access_at_index(.level4, 0x100)), page_size / 2);
    page_table_address[512 - 2] = space.arch.cr3 | 0b11;
    _ = kernel.address_space.free(@ptrToInt(page_table_address), 0, false);

    return true;
}

pub export fn CallFunctionOnAllProcessorCallbackWrapper() callconv(.C) void
{
    @ptrCast(*volatile CallFunctionOnAllProcessorsCallback, &callFunctionOnAllProcessorsCallback).*();
}
pub extern fn Get_KThreadTerminateAddress() callconv(.C) u64;
pub extern fn GetProcesssLoadDesktopExecutableAddress() callconv(.C) u64;
comptime
{
    asm(
        \\.intel_syntax noprefix
        \\.extern ProcessLoadDesktopExecutable
        \\.global GetProcesssLoadDesktopExecutableAddress
        \\GetProcesssLoadDesktopExecutableAddress:
        \\mov rax, OFFSET ProcessLoadDesktopExecutable
        \\ret
    );
}
pub extern fn GetMMZeroPageThreadAddress() callconv(.C) u64;
pub extern fn GetMMBalanceThreadAddress() callconv(.C) u64;
comptime
{
    asm(
        \\.intel_syntax noprefix
        \\.global GetMMZeroPageThreadAddress
        \\.extern MMZeroPageThread
        \\GetMMZeroPageThreadAddress:
        \\mov rax, OFFSET MMZeroPageThread
        \\ret
        
        \\.global GetMMBalanceThreadAddress
        \\.extern MMBalanceThread
        \\GetMMBalanceThreadAddress:
        \\mov rax, OFFSET MMBalanceThread
        \\ret
    );
}
