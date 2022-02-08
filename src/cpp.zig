const std = @import("std");
const assert = std.debug.assert;

const atomic_order: std.builtin.AtomicOrder = .SeqCst;

const Error = i64;

fn zeroes(comptime T: type) T
{
    @setEvalBranchQuota(100000);
    var zero_value: T = undefined;
    std.mem.set(u8, std.mem.asBytes(&zero_value), 0);
    return zero_value;
}

pub const max_wait_count = 8;
pub const max_processors = 256;
pub const wait_no_timeout = std.math.maxInt(u64);
pub const page_bit_count = 12;
pub const page_size = 0x1000;

pub const entry_per_page_table_count = 512;
pub const entry_per_page_table_bit_count = 9;

pub const core_memory_region_start = 0xFFFF8001F0000000;
pub const core_memory_region_count = (0xFFFF800200000000 - 0xFFFF8001F0000000) / @sizeOf(Region);

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

const ES_SUCCESS = -1;


export var _stack: [0x4000]u8 align(0x1000) linksection(".bss") = undefined;
export var _idt_data: [idt_entry_count]IDTEntry align(0x1000) linksection(".bss") = undefined;
export var _cpu_local_storage: [0x2000]u8 align(0x1000) linksection(".bss") = undefined;

export var timeStampCounterSynchronizationValue = Volatile(u64) { .value = 0 };

export var idt_descriptor: CPUDescriptorTable linksection(".data") = undefined;
export var processorGDTR: u128 align(0x10) linksection(".data")  = undefined;
export var installation_ID: u128 linksection(".data") = 0;
export var bootloader_ID: u64 linksection(".data") = 0;
export var bootloader_information_offset: u64 linksection(".data") = 0;
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

export var scheduler: Scheduler = undefined;
export var _kernelProcess: Process = undefined;
export var kernelProcess: *Process = undefined;
export var desktopProcess: *Process = undefined;

extern fn ProcessorHalt() callconv(.C) noreturn;
extern fn ProcessorAreInterruptsEnabled() callconv(.C) bool;
extern fn ProcessorEnableInterrupts() callconv(.C) void;
extern fn ProcessorDisableInterrupts() callconv(.C) void;
extern fn ProcessorFakeTimerInterrupt() callconv(.C) void;
extern fn ProcessorInvalidatePage(page: u64) callconv(.C) void;
extern fn ProcessorInvalidateAllPages() callconv(.C) void;
extern fn ProcessorIn8(port: u16) callconv(.C) u8;
extern fn ProcessorIn16(port: u16) callconv(.C) u16;
extern fn ProcessorIn32(port: u16) callconv(.C) u32;
extern fn ProcessorOut8(port: u16, value: u8) callconv(.C) void;
extern fn ProcessorOut16(port: u16, value: u16) callconv(.C) void;
extern fn ProcessorOut32(port: u16, value: u32) callconv(.C) void;
extern fn ProcessorReadTimeStamp() callconv(.C) u64;
extern fn ProcessorReadCR3() callconv(.C) u64;
extern fn ProcessorDebugOutputByte(byte: u8) callconv(.C) void;
extern fn ProcessorSetThreadStorage(tls_address: u64) callconv(.C) void;
extern fn ProcessorSetLocalStorage(local_storage: *LocalStorage) callconv(.C) void;
extern fn ProcessorInstallTSS(gdt: u64, tss: u64) callconv(.C) void;
extern fn GetLocalStorage() callconv(.C) ?*LocalStorage;
extern fn GetCurrentThread() callconv(.C) ?*Thread;

fn zero(comptime T: type, ptr: *T) void
{
    std.mem.set(u8, @ptrCast([*]u8, ptr), 0);
}

fn zero_many(comptime T: type, ptr: [*]T) void
{
    std.mem.set(u8, @ptrCast([*]u8, ptr), 0);
}

pub fn Volatile(comptime T: type) type
{
    return extern struct
    {
        value: T,

        pub fn read_volatile(self: *volatile const @This()) callconv(.Inline) T
        {
            return self.value;
        }

        pub fn write_volatile(self: *volatile @This(), value: T) callconv(.Inline) void
        {
            self.value = value;
        }

        pub fn access_volatile(self: *volatile @This()) callconv(.Inline) *volatile T
        {
            return &self.value;
        }

        pub fn increment(self: *@This()) callconv(.Inline) void
        {
            self.write_volatile(self.read_volatile() + 1);
        }

        pub fn decrement(self: *@This()) callconv(.Inline) void
        {
            self.write_volatile(self.read_volatile() - 1);
        }
        
        /// Only supported for integer types
        pub fn atomic_fetch_add(self: *@This(), value: T) callconv(.Inline) T
        {
            return @atomicRmw(T, &self.value, .Add, value, .SeqCst);
        }
        pub fn atomic_fetch_sub(self: *@This(), value: T) callconv(.Inline) T
        {
            return @atomicRmw(T, &self.value, .Sub, value, .SeqCst);
        }

        pub fn atomic_compare_and_swap(self: *@This(), expected_value: T, new_value: T) callconv(.Inline) ?T
        {
            return @cmpxchgStrong(@TypeOf(self.value), &self.value, expected_value, new_value, .SeqCst, .SeqCst);
        }
    };
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

export fn TODO() noreturn
{
    KernelPanic("unimplemented");
}

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
        
        \\.global GetCurrentThread
        \\GetCurrentThread:
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
        
        \\.global ProcessorHalt
        \\ProcessorHalt:
        \\cli
        \\hlt
        \\jmp ProcessorHalt

        \\.global ProcessorAreInterruptsEnabled
        \\ProcessorAreInterruptsEnabled:
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
        
        \\.global ProcessorEnableInterrupts
        \\ProcessorEnableInterrupts:
        \\mov rax, 0
        \\mov cr8, rax
        \\sti
        \\ret

        \\.global ProcessorDisableInterrupts
        \\ProcessorDisableInterrupts:
        \\mov rax, 14
        \\mov cr8, rax
        \\sti
        \\ret

        \\.global GetLocalStorage
        \\GetLocalStorage:
        \\mov rax, qword ptr gs:0
        \\ret

        \\.global ProcessorFakeTimerInterrupt
        \\ProcessorFakeTimerInterrupt:
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

        \\.global ProcessorInvalidatePage
        \\ProcessorInvalidatePage:
        \\invlpg [rdi]
        \\ret

        \\.global ProcessorSetAddressSpace
        \\ProcessorSetAddressSpace:
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

        \\.global ProcessorOut8
        \\ProcessorOut8:
        \\mov rdx, rdi
        \\mov rax, rsi
        \\out dx, al
        \\ret

        \\.global ProcessorIn8
        \\ProcessorIn8:
        \\mov rdx, rdi
        \\xor rax, rax
        \\in al, dx
        \\ret

        \\.global ProcessorOut16
        \\ProcessorOut16:
        \\mov rdx,rdi
        \\mov rax,rsi
        \\out dx,ax
        \\ret
     
        \\.global ProcessorIn16
        \\ProcessorIn16:
        \\mov rdx,rdi
        \\xor rax,rax
        \\in ax,dx
        \\ret
      
        \\.global ProcessorOut32
        \\ProcessorOut32:
        \\mov rdx,rdi
        \\mov rax,rsi
        \\out dx,eax
        \\ret
        
        \\.global ProcessorIn32
        \\ProcessorIn32:
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

        \\.global ProcessorSetLocalStorage
        \\ProcessorSetLocalStorage:
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
 
        \\.global ArchSwitchContext
        \\ArchSwitchContext:
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
        \\call GetCurrentThread
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

        \\.global ProcessorDebugOutputByte
        \\ProcessorDebugOutputByte:
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
        \\call ArchNextTimer
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

var panic_buffer: [0x4000]u8 = undefined;
extern fn KernelPanic(format: [*:0]const u8, ...) callconv(.C) noreturn;
pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn
{
    _ = stack_trace;
    KernelPanic(@ptrCast([*:0]const u8, message.ptr));
}

pub const Spinlock = extern struct
{
    state: Volatile(u8),
    owner_cpu: Volatile(u8),
    interrupts_enabled: Volatile(bool),

    pub fn acquire(self: *@This()) void
    {
        if (scheduler.panic.read_volatile()) return;

        const interrupts_enabled = ProcessorAreInterruptsEnabled();
        ProcessorDisableInterrupts();

        const maybe_local_storage = GetLocalStorage();
        if (maybe_local_storage) |local_storage|
        {
            local_storage.spinlock_count += 1;
        }

        _ = self.state.atomic_compare_and_swap(0, 1);
        @fence(.SeqCst);
        self.interrupts_enabled.write_volatile(interrupts_enabled);

        if (maybe_local_storage) |local_storage|
        {
            // @Unsafe
            self.owner_cpu.write_volatile(@intCast(u8, local_storage.processor_ID));
        }
    }

    pub fn release(self: *@This()) void
    {
        self.release_ex(false);
    }

    pub fn release_ex(self: *@This(), comptime force: bool) void
    {
        if (scheduler.panic.read_volatile()) return;

        const maybe_local_storage = GetLocalStorage();
        if (maybe_local_storage) |local_storage|
        {
            local_storage.spinlock_count -= 1;
        }

        if (force)
        {
            self.assert_locked();
        }

        const were_interrupts_enabled = self.interrupts_enabled.read_volatile();
        @fence(.SeqCst);
        self.state.write_volatile(0);
        
        if (were_interrupts_enabled) ProcessorEnableInterrupts();
    }

    pub fn assert_locked(self: *@This()) void
    {
        if (scheduler.panic.read_volatile()) return;

        if (self.state.read_volatile() == 0 or ProcessorAreInterruptsEnabled())
        {
            KernelPanic("Spinlock not correctly acquired\n");
        }
    }
};

export fn KSpinlockAcquire(spinlock: *Spinlock) callconv(.C) void
{
    spinlock.acquire();
}
export fn KSpinlockRelease(spinlock: *Spinlock) callconv(.C) void
{
    spinlock.release_ex(false);
}
export fn KSpinlockReleaseForced(spinlock: *Spinlock) callconv(.C) void
{
    spinlock.release_ex(true);
}
export fn KSpinlockAssertLocked(spinlock: *Spinlock) callconv(.C) void
{
    spinlock.assert_locked();
}

const Scheduler = extern struct
{
    dispatch_spinlock: Spinlock,
    active_timers_spinlock: Spinlock,
    active_threads: [Thread.priority_count]LinkedList(Thread),
    paused_threads: LinkedList(Thread),
    active_timers: LinkedList(Timer),

    all_threads_mutex: Mutex,
    all_processes_mutex: Mutex,
    async_task_spinlock: Spinlock,
    all_threads: LinkedList(Thread),
    all_processes: LinkedList(Process),

    thread_pool: Pool,
    process_pool: Pool,
    address_space_pool: Pool,

    next_thread_id: u64,
    next_process_id: u64,
    next_processor_id: u64,

    all_processes_terminated_event: Event,
    block_shutdown_process_count: Volatile(u64),
    active_process_count: Volatile(u64),
    started: Volatile(bool),
    panic: Volatile(bool),
    shutdown: Volatile(bool),
    time_ms: u64,

    fn yield(self: *@This(), context: *InterruptContext) void
    {
        if (!self.started.read_volatile()) return;
        if (GetLocalStorage()) |local|
        {
            if (!local.scheduler_ready) return;

            if (local.processor_ID == 0)
            {
                self.time_ms = ArchGetTimeMs();
                globalData.scheduler_time_ms.write_volatile(self.time_ms);

                self.active_timers_spinlock.acquire();

                var maybe_timer_item = self.active_timers.first;

                while (maybe_timer_item) |timer_item|
                {
                    const timer = timer_item.value.?;
                    const next = timer_item.next;

                    if (timer.trigger_time_ms <= self.time_ms)
                    {
                        self.active_timers.remove(timer_item);
                        _ = timer.event.set(false);

                        if (@intToPtr(?AsyncTask.Callback, timer.callback)) |callback|
                        {
                            timer.async_task.register(callback);
                        }
                    }
                    else
                    {
                        break;
                    }
                    maybe_timer_item = next;
                }

                self.active_timers_spinlock.release();
            }

            if (local.spinlock_count != 0) KernelPanic("Spinlocks acquired while attempting to yield");

            ProcessorDisableInterrupts();
            self.dispatch_spinlock.acquire();

            if (self.dispatch_spinlock.interrupts_enabled.read_volatile())
            {
                KernelPanic("interrupts were enabled when scheduler lock was acquired");
            }

            if (!local.current_thread.?.executing.read_volatile()) KernelPanic("current thread marked as not executing");

            const old_address_space = if (local.current_thread.?.temporary_address_space) |tas| @ptrCast(*AddressSpace, tas) else local.current_thread.?.process.?.address_space;

            local.current_thread.?.interrupt_context = context;
            local.current_thread.?.executing.write_volatile(false);

            const kill_thread = local.current_thread.?.terminatable_state.read_volatile() == .terminatable and local.current_thread.?.terminating.read_volatile();
            const keep_thread_alive = local.current_thread.?.terminatable_state.read_volatile() == .user_block_request and local.current_thread.?.terminating.read_volatile();

            if (kill_thread)
            {
                local.current_thread.?.state.write_volatile(.terminated);
                local.current_thread.?.kill_async_task.register(ThreadKill);
            }
            else if (local.current_thread.?.state.read_volatile() == .waiting_mutex)
            {
                const mutex = @ptrCast(*Mutex, local.current_thread.?.blocking.mutex.?);
                if (!keep_thread_alive and mutex.owner != null)
                {
                    mutex.owner.?.blocked_thread_priorities[@intCast(u64, local.current_thread.?.priority)] += 1;
                    SchedulerMaybeUpdateActiveList(@ptrCast(*Thread, @alignCast(@alignOf(Thread), mutex.owner.?)));
                    mutex.blocked_threads.insert_at_end(&local.current_thread.?.item);
                }
                else
                {
                    local.current_thread.?.state.write_volatile(.active);
                }
            }
            else if (local.current_thread.?.state.read_volatile() == .waiting_event)
            {
                if (keep_thread_alive)
                {
                    local.current_thread.?.state.write_volatile(.active);
                }
                else
                {
                    var unblocked = false;

                    for (local.current_thread.?.blocking.event.array[0..local.current_thread.?.blocking.event.count]) |event|
                    {
                        if (event.?.state.read_volatile() != 0)
                        {
                            local.current_thread.?.state.write_volatile(.active);
                            unblocked = true;
                            break;
                        }
                    }

                    if (!unblocked)
                    {
                        for (local.current_thread.?.blocking.event.array[0..local.current_thread.?.blocking.event.count]) |_event, i|
                        {
                            const event = @ptrCast(*Event, _event.?);
                            const item = @ptrCast(*LinkedList(Thread).Item, &local.current_thread.?.blocking.event.items.?[i]);
                            event.blocked_threads.insert_at_end(item);
                        }
                    }
                }
            }
            else if (local.current_thread.?.state.read_volatile() == .waiting_writer_lock)
            {
                const lock = @ptrCast(*WriterLock, local.current_thread.?.blocking.writer.lock.?);
                if ((local.current_thread.?.blocking.writer.type == WriterLock.shared and lock.state.read_volatile() >= 0) or
                    (local.current_thread.?.blocking.writer.type == WriterLock.exclusive and lock.state.read_volatile() == 0))
                {
                    local.current_thread.?.state.write_volatile(.active);
                }
                else
                {
                    lock.blocked_threads.insert_at_end(&local.current_thread.?.item);
                }
            }

            if (!kill_thread and local.current_thread.?.state.read_volatile() == .active)
            {
                if (local.current_thread.?.type == .normal)
                {
                    SchedulerAddActiveThread(local.current_thread.?, false);
                }
                else if (local.current_thread.?.type == .idle or local.current_thread.?.type == .async_task)
                {
                }
                else
                {
                    KernelPanic("unrecognized thread type");
                }
            }

            const new_thread = SchedulerPickThread(local) orelse KernelPanic("Could not find a thread to execute");
            local.current_thread = new_thread;
            if (new_thread.executing.read_volatile()) KernelPanic("thread in active queue already executing");

            new_thread.executing.write_volatile(true);
            new_thread.executing_processor_ID = local.processor_ID;
            new_thread.cpu_time_slices.increment();
            if (new_thread.type == .idle) new_thread.process.?.idle_time_slices += 1
            else new_thread.process.?.cpu_time_slices += 1;

            ArchNextTimer(1);
            const new_context = new_thread.interrupt_context;
            const address_space = if (new_thread.temporary_address_space) |tas| @ptrCast(*AddressSpace, tas) else new_thread.process.?.address_space;
            MMSpaceOpenReference(address_space);
            ArchSwitchContext(new_context, &address_space.arch, new_thread.kernel_stack, new_thread, old_address_space);
            KernelPanic("do context switch unexpectedly returned");
        }
    }

    fn add_active_thread(self: *@This(), thread: *Thread, start: bool) void
    {
        if (thread.type == .async_task) return;
        if (thread.state.read_volatile() != .active) KernelPanic("thread not active")
        else if (thread.executing.read_volatile()) KernelPanic("thread executing")
        else if (thread.type != .normal) KernelPanic("thread not normal")
        else if (thread.item.list != null) KernelPanic("thread already in queue");

        if (thread.paused.read_volatile() and thread.terminatable_state.read_volatile() == .terminatable)
        {
            self.paused_threads.insert_at_start(&thread.item);
        }
        else
        {
            const effective_priority = @intCast(u64, SchedulerGetThreadEffectivePriority(thread));
            if (start) self.active_threads[effective_priority].insert_at_start(&thread.item)
            else self.active_threads[effective_priority].insert_at_end(&thread.item);
        }
    }

    fn get_thread_effective_priority(self: *@This(), thread: *Thread) i8
    {
        self.dispatch_spinlock.assert_locked();

        for (thread.blocked_thread_priorities[0..@intCast(u64, thread.priority)]) |priority, i|
        {
            if (priority != 0) return @intCast(i8, i);
        }

        return thread.priority;
    }

    fn pick_thread(self: *@This(), local: *LocalStorage) ?*Thread
    {
        self.dispatch_spinlock.assert_locked();

        if ((local.async_task_list.next_or_first != null or local.in_async_task)
            and local.async_task_thread.?.state.read_volatile() == .active)
        {
            return local.async_task_thread;
        }

        for (self.active_threads) |*thread_item|
        {
            if (thread_item.first) |first|
            {
                first.remove_from_list();
                return first.value;
            }
        }

        return local.idle_thread;
    }

    fn maybe_update_list(self: *@This(), thread: *Thread) void
    {
        if (thread.type == .async_task) return;
        if (thread.type != .normal) KernelPanic("trying to update the active list of a non-normal thread");

        self.dispatch_spinlock.assert_locked();

        if (thread.state.read_volatile() != .active or thread.executing.read_volatile()) return;
        if (thread.item.list == null) KernelPanic("Despite thread being active and not executing, it is not in an active thread list");

        const effective_priority = @intCast(u64, SchedulerGetThreadEffectivePriority(thread));
        if (&self.active_threads[effective_priority] == thread.item.list) return;
        thread.item.remove_from_list();
        self.active_threads[effective_priority].insert_at_start(&thread.item);
    }

    fn unblock_thread(self: *@This(), unblocked_thread: *Thread, previous_mutex_owner: ?*Thread) void
    {
        _ = previous_mutex_owner;
        self.dispatch_spinlock.assert_locked();
        switch (unblocked_thread.state.read_volatile())
        {
            .waiting_mutex => TODO(),
            .waiting_event => TODO(),
            .waiting_writer_lock => TODO(),
            else => KernelPanic("unexpected thread state"),
        }

        unblocked_thread.state.write_volatile(.active);
        if (!unblocked_thread.executing.read_volatile()) SchedulerAddActiveThread(unblocked_thread, true);
    }
};

extern fn ArchSwitchContext(context: *InterruptContext, arch_address_space: *ArchAddressSpace, thread_kernel_stack: u64, new_thread: *Thread, old_address_space: *AddressSpace) callconv(.C) void;

export fn SchedulerNotifyObject(blocked_threads: *LinkedList(Thread), unblock_all: bool, previous_mutex_owner: ?*Thread) callconv(.C) void
{
    scheduler.dispatch_spinlock.assert_locked();

    var unblocked_item = blocked_threads.first;
    if (unblocked_item == null) return;
    while (true)
    {
        if (@ptrToInt(unblocked_item) < 0xf000000000000000)
        {
            KernelPanic("here");
        }
        const next_unblocked_item = unblocked_item.?.next;
        const unblocked_thread = unblocked_item.?.value.?;
        SchedulerUnblockThread(unblocked_thread, previous_mutex_owner);
        unblocked_item = next_unblocked_item;
        if (!(unblock_all and unblocked_item != null)) break;
    }
}
export fn SchedulerAddActiveThread(thread: *Thread, start: bool) callconv(.C) void
{
    scheduler.add_active_thread(thread, start);
}
export fn SchedulerGetThreadEffectivePriority(thread: *Thread) callconv(.C) i8
{
    return scheduler.get_thread_effective_priority(thread);
}
export fn SchedulerPickThread(local: *LocalStorage) callconv(.C) ?*Thread
{
    return scheduler.pick_thread(local);
}
export fn SchedulerMaybeUpdateActiveList(thread: *Thread) callconv(.C) void
{
    scheduler.maybe_update_list(thread);
}

export fn SchedulerUnblockThread(unblocked_thread: *Thread, previous_mutex_owner: ?*Thread) callconv(.C) void
{
    _ = unblocked_thread;
    _ = previous_mutex_owner;
    TODO();
    //scheduler.unblock_thread(unblocked_thread, previous_mutex_owner);
}
//extern fn SchedulerYield(context: *InterruptContext) callconv(.C) void;
export fn SchedulerYield(context: *InterruptContext) callconv(.C) void
{
    scheduler.yield(context);
}
extern fn SchedulerCreateProcessorThreads(local: *LocalStorage) callconv(.C) void;

const GlobalData = extern struct
{
    click_chain_timeout_ms: Volatile(i32),
    ui_scale: Volatile(f32),
    swap_left_and_right_buttons: Volatile(bool),
    show_cursor_shadow: Volatile(bool),
    use_smart_quotes: Volatile(bool),
    enable_hover_state: Volatile(bool),
    animation_time_multiplier: Volatile(f32),
    scheduler_time_ms: Volatile(u64),
    scheduler_time_offset: Volatile(u64),
    keyboard_layout: Volatile(u16),
};

export var mmGlobalDataRegion: *SharedRegion = undefined;
export var globalData: *GlobalData = undefined;


const LocalStorage = extern struct
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
    //comptime asm
};

// @TODO: do right
const FSFile = extern struct
{
    foo: u64,
};

pub const Thread = extern struct
{
    in_safe_copy: bool,
    item: LinkedList(Thread).Item,
    all_item: LinkedList(Thread).Item,
    process_item: LinkedList(Thread).Item,

    process: ?*Process,
    id: u64,
    cpu_time_slices: Volatile(u64),
    handle_count: Volatile(u64),
    executing_processor_ID: u32,

    user_stack_base: u64,
    kernel_stack_base: u64,
    kernel_stack: u64,
    user_stack_reserve: u64,
    user_stack_commit: Volatile(u64),

    tls_address: u64,
    timer_adjust_address: u64,
    timer_adjust_ticks: u64,
    last_interrupt_timestamp: u64,

    type: Thread.Type,
    is_kernel_thread: bool,
    is_page_generator: bool,
    priority: i8,
    blocked_thread_priorities: [Thread.priority_count]i32,

    state: Volatile(Thread.State),
    terminatable_state: Volatile(Thread.TerminatableState),
    executing: Volatile(bool),
    terminating: Volatile(bool),
    paused: Volatile(bool),
    received_yield_IPI: Volatile(bool),

    blocking: extern union
    {
        mutex: ?*volatile Mutex,
        writer: extern struct
        {
            lock: ?*volatile WriterLock,
            type: bool,
        },
        event: extern struct
        {
            items: ?[*]volatile LinkedList(Thread).Item,
            array: [max_wait_count]?*volatile Event,
            count: u64,
        },
    },

    killed_event: Event,
    kill_async_task: AsyncTask,

    temporary_address_space: ?*volatile AddressSpace,
    interrupt_context: *InterruptContext,
    last_known_execution_address: u64, // @TODO: for debugging

    pub const Priority = enum(i8)
    {
        normal = 0,
        low = 1,
    };
    pub const priority_count = std.enums.values(Priority).len;

    pub const State = enum(i8)
    {
        active = 0,
        waiting_mutex = 1,
        waiting_event = 2,
        waiting_writer_lock = 3,
        terminated = 4,
    };

    pub const Type = enum(i8)
    {
        normal = 0,
        idle = 1,
        async_task = 2,
    };

    pub const TerminatableState = enum(i8)
    {
        invalid_TS = 0,
        terminatable = 1,
        in_syscall = 2,
        user_block_request = 3,
    };

    pub const Flags = Bitflag(enum(u32)
        {
            userland = 0,
            low_priority = 1,
            paused = 2,
            async_task = 3,
            idle = 4,
        });
};

pub fn LinkedList(comptime T: type) type
{
    return extern struct
    {
        first: ?*Item,
        last: ?*Item,
        count: u64,

        pub const Item = extern struct
        {
            previous: ?*@This(),
            next: ?*@This(),
            list: ?*LinkedList(T),
            value: ?*T,

            pub fn remove_from_list(self: *@This()) void
            {
                if (self.list) |list|
                {
                    list.remove(self);
                }
                else
                {
                    KernelPanic("list null when trying to remove item");
                }
            }
        };

        pub fn insert_at_start(self: *@This(), item: *Item) void
        {
            if (item.list != null) KernelPanic("inserting an item that is already in a list");

            if (self.first) |first|
            {
                item.next = first;
                item.previous = null;
                first.previous = item;
                self.first = item;
            }
            else
            {
                self.first = item;
                self.last = item;
                item.previous = null;
                item.next = null;
            }

            self.count += 1;
            item.list = self;
            self.validate();
        }

        pub fn insert_at_end(self: *@This(), item: *Item) void
        {
            if (item.list != null) KernelPanic("inserting an item that is already in a list");

            if (self.last) |last|
            {
                item.previous = last;
                item.next= null;
                last.next = item;
                self.last = item;
            }
            else
            {
                self.first = item;
                self.last = item;
                item.previous = null;
                item.next = null;
            }

            self.count += 1;
            item.list = self;
            self.validate();
        }

        pub fn insert_before(self: *@This(), item: *Item, before: *Item) void
        {
            if (item.list != null) KernelPanic("inserting an item that is already in a list");

            if (before != self.first)
            {
                item.previous = before.previous;
                item.previous.?.next = item;
            }
            else
            {
                self.first = item;
                item.previous = null;
            }

            item.next = before;
            before.previous = item;

            self.count += 1;
            item.list = self;
            self.validate();
        }

        pub fn remove(self: *@This(), item: *Item) void
        {
            if (item.list) |list|
            {
                if (list != self) KernelPanic("item is in another list");
            }
            else
            {
                KernelPanic("item is not in any list");
            }

            if (item.previous) |previous| previous.next = item.next
            else self.first = item.next;

            if (item.next) |next| next.previous = item.previous
            else self.last = item.previous;

            item.previous = null;
            item.next = null;
            item.list = null;

            self.count -= 1;
            self.validate();
        }

        fn validate(self: *@This()) void
        {
            if (self.count == 0)
            {
                if (self.first != null or self.last != null) KernelPanic("invalid list");
            }
            else if (self.count == 1)
            {
                if (self.first != self.last or
                    self.first.?.previous != null or
                    self.first.?.next != null or
                    self.first.?.list != self or
                    self.first.?.value == null)
                {
                    KernelPanic("invalid list");
                }
            }
            else
            {
                if (self.first == self.last or
                    self.first.?.previous != null or
                    self.last.?.next != null)
                {
                    KernelPanic("invalid list");
                }

                {
                    var item = self.first;
                    var index = self.count;

                    while (true)
                    {
                        index -= 1;
                        if (index == 0) break;

                        if (item.?.next == item or item.?.list != self or item.?.value == null)
                        {
                            KernelPanic("invalid list");
                        }

                        item = item.?.next;
                    }

                    if (item != self.last) KernelPanic("invalid list");
                }

                {
                    var item = self.last;
                    var index = self.count;

                    while (true)
                    {
                        index -= 1;
                        if (index == 0) break;

                        if (item.?.previous == item)
                        {
                            KernelPanic("invalid list");
                        }

                        item = item.?.previous;
                    }

                    if (item != self.first) KernelPanic("invalid list");
                }
            }
        }
    };
}

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
            KernelPanic("context sanity check failed\n");
        }
    }

};

pub const Timer = extern struct
{
    event: Event,
    async_task: AsyncTask,
    item: LinkedList(Timer).Item,
    trigger_time_ms: u64,
    callback: u64, //?AsyncTask.Callback,
    argument: u64,

    pub fn set_extended(self: *@This(), trigger_in_ms: u64, maybe_callback: ?AsyncTask.Callback, maybe_argument: u64) void
    {
        scheduler.active_timers_spinlock.acquire();

        if (self.item.list != null) scheduler.active_timers.remove(&self.item);

        self.event.reset();

        self.trigger_time_ms = trigger_in_ms + scheduler.time_ms;
        self.callback = @ptrToInt(maybe_callback);
        self.argument = maybe_argument;
        self.item.value = self;

        var maybe_timer = scheduler.active_timers.first;
        while (maybe_timer != null)
        {
            const timer = maybe_timer.?.value.?;
            const next = maybe_timer.?.next;
            if (timer.trigger_time_ms > self.trigger_time_ms) break;

            maybe_timer = next;
        }

        if (maybe_timer) |timer|
        {
            scheduler.active_timers.insert_before(&self.item, timer);
        }
        else
        {
            scheduler.active_timers.insert_at_end(&self.item);
        }

        scheduler.active_timers_spinlock.release();
    }

    pub fn set(self: *@This(), trigger_in_ms: u64) void
    {
        self.set_extended(trigger_in_ms, null, 0);
    }

    pub fn remove(self: *@This()) void
    {
        scheduler.active_timers_spinlock.acquire();

        if (self.callback != 0) KernelPanic("timer with callback cannot be removed");

        if (self.item.list != null) scheduler.active_timers.remove(&self.item);

        scheduler.active_timers_spinlock.release();
    }
};

//extern fn TimeoutTimerHit(task: *AsyncTask) callconv(.C) void;

export fn KTimerRemove(timer: *Timer) callconv(.C) void
{
    timer.remove();
}

pub const Mutex = extern struct
{
    owner: ?* align(1) volatile Thread,
    blocked_threads: LinkedList(Thread),

    pub fn acquire(self: *@This()) bool
    {
        if (scheduler.panic.read_volatile()) return false;

        var current_thread = blk:
        {
            const thread_address = addr_block:
            {
                if (GetCurrentThread()) |current_thread|
                {
                    if (current_thread.terminatable_state.read_volatile() == .terminatable)
                    {
                        KernelPanic("thread is terminatable\n");
                    }

                    if (self.owner != null and self.owner == current_thread)
                    {
                        KernelPanic("Attempt to acquire a mutex owned by current thread already acquired\n");
                    }

                    break :addr_block @ptrToInt(current_thread);
                }
                else
                {
                    break :addr_block 1;
                }
            };

            break :blk @intToPtr(*volatile align(1) Thread, thread_address);
        };

        if (!ProcessorAreInterruptsEnabled())
        {
            KernelPanic("trying to acquire a mutex with interrupts disabled");
        }

        while (true)
        {
            scheduler.dispatch_spinlock.acquire();
            const old = self.owner;
            if (old == null) self.owner = current_thread;
            scheduler.dispatch_spinlock.release();
            if (old == null) break;

            @fence(.SeqCst);

            if (GetLocalStorage()) |local_storage|
            {
                if (local_storage.scheduler_ready)
                {
                    if (current_thread.state.read_volatile() != .active)
                    {
                        KernelPanic("Attempting to wait on a mutex in a non-active thread\n");
                    }

                    current_thread.blocking.mutex = self;
                    @fence(.SeqCst);

                    current_thread.state.write_volatile(.waiting_mutex);

                    scheduler.dispatch_spinlock.acquire();
                    const spin = 
                        if (self.owner) |owner| owner.executing.read_volatile()
                        else false;

                    scheduler.dispatch_spinlock.release();

                    if (!spin and current_thread.blocking.mutex.?.owner != null)
                    {
                        ProcessorFakeTimerInterrupt();
                    }

                    while ((!current_thread.terminating.read_volatile() or current_thread.terminatable_state.read_volatile() != .user_block_request) and self.owner != null)
                    {
                        current_thread.state.write_volatile(.waiting_mutex);
                    }

                    current_thread.state.write_volatile(.active);

                    if (current_thread.terminating.read_volatile() and current_thread.terminatable_state.read_volatile() == .user_block_request)
                    {
                        // mutex was not acquired because the thread is terminating
                        return false;
                    }
                }
            }
        }

        @fence(.SeqCst);

        if (self.owner != current_thread)
        {
            KernelPanic("Invalid owner thread\n");
        }

        return true;
    }

    pub fn release(self: *@This()) void
    {
        if (scheduler.panic.read_volatile()) return;

        self.assert_locked();
        const maybe_current_thread = GetCurrentThread();
        scheduler.dispatch_spinlock.acquire();

        if (maybe_current_thread) |current_thread|
        {
            if (@cmpxchgStrong(?*align(1) volatile Thread, &self.owner, current_thread, null, .SeqCst, .SeqCst) != null)
            {
                KernelPanic("Invalid owner thread\n");
            }
        }
        else self.owner = null;

        const preempt = self.blocked_threads.count != 0;
        if (scheduler.started.read_volatile())
        {
            SchedulerNotifyObject(&self.blocked_threads, true, maybe_current_thread);
        }

        scheduler.dispatch_spinlock.release();
        @fence(.SeqCst);

        if (preempt) ProcessorFakeTimerInterrupt();
    }

    pub fn assert_locked(self: *@This()) void
    {
        const current_thread = blk:
        {
            if (GetCurrentThread()) |thread|
            {
                break :blk @ptrCast(*align(1) Thread, thread);
            }
            else
            {
                break :blk @intToPtr(*align(1) Thread, 1);
            }
        };

        if (self.owner != current_thread)
        {
            KernelPanic("Mutex not correctly acquired\n");
        }
    }
};

export fn KMutexAcquire(mutex: *Mutex) callconv(.C) bool
{
    return mutex.acquire();
}
export fn KMutexRelease(mutex: *Mutex) callconv(.C) void
{
    mutex.release();
}
export fn KMutexAssertLocked(mutex: *Mutex) callconv(.C) void
{
    mutex.assert_locked();
}

const ObjectCacheItem = SimpleList;
pub const Node = extern struct
{
    driver_node: u64,
    handle_count: Volatile(u64),
    directory_entry: u64,
    filesystem: u64,
    id: u64,
    writer_lock: WriterLock,
    node_error: i64,
    flags: Volatile(u32),
    cache_item: ObjectCacheItem,
};

pub const ProcessCreateData = extern struct
{
    system_data: u64,
    subsystem_data: u64,
    user_data: u64,
    subsystem_ID: u8,
};

pub const FatalError = enum(u32)
{
    abort,
    incorrect_file_acces,
    incorrect_node_type,
    insufficient_permissions,
    invalid_buffer,
    invalid_handle,
    invalid_memory_region,
    out_of_range,
    processor_exception,
    recursive_batch,
    unknown_syscall,
};

pub const CrashReason = extern struct
{
    error_code: FatalError,
    during_system_call: i32,
};

const ExecutableState = enum(u8)
{
    not_loaded = 0,
    failed_to_load = 1,
    loaded = 2,
};

pub const Process = extern struct
{
    // @TODO: maybe turn into a pointer
    address_space: *AddressSpace,
    message_queue: MessageQueue,
    handle_table: HandleTable,

    threads: LinkedList(Thread),
    threads_mutex: Mutex,

    executable_node: ?*Node,
    executable_name: [32]u8,
    data: ProcessCreateData,
    permissions: Process.Permission,
    creation_flags: Process.CreationFlags,
    type: Process.Type,

    id: u64,
    handle_count: Volatile(u64),
    all_item: LinkedList(Process).Item,

    crash_mutex: Mutex,
    crash_reason: CrashReason,
    crashed: bool,

    all_threads_terminated: bool,
    block_shutdown: bool,
    prevent_new_threads: bool,
    exit_status: i32,
    killed_event: Event,

    executable_state: ExecutableState,
    executable_start_request: bool,
    executable_load_attempt_complete: Event,
    executable_main_thread: ?*Thread,

    cpu_time_slices: u64,
    idle_time_slices: u64,
    
    pub const Type = enum(u32)
    {
        normal,
        kernel,
        desktop,
    };

    pub const Permission = Bitflag(enum(u64)
        {
            networking = 0,
            process_create = 1,
            process_open = 2,
            screen_modify = 3,
            shutdown = 4,
            take_system_snapshot = 5,
            get_volume_information = 6,
            window_manager = 7,
            posix_subsystem = 8,
        });

    pub const CreationFlags = Bitflag(enum(u32)
        {
            paused = 0,
        });

    //pub fn register(self: *@This(), process_type: Process.Type) void
    //{
        //self.id = @atomicRmw(@TypeOf(scheduler.next_processor_id), &scheduler.next_process_id, .Add, 1, .SeqCst);
        //self.address_space.reference_count.write_volatile(1);
        ////// list, table
        //self.handle_count.write_volatile(1);
        //self.permissions = Process.Permission.all();
        //self.type = process_type;
    //}

    //pub fn spawn_thread_extended(self: *@This(), start_address: u64, argument1: u64, flags: Thread.Flags, argument2: u64) ?*Thread
    //{
        //const userland = flags.contains(.userland);

        //const parent_thread = GetCurrentThread();
        //_ = parent_thread;

        //if (userland and self == kernelProcess)
        //{
            //KernelPanic("cannot add userland thread to kernel process");
        //}

        //_ = self.threads_mutex.acquire();
        //defer self.threads_mutex.release();

        //if (self.prevent_new_threads) return null;

        //if (scheduler.thread_pool.add()) |thread|
        //{
            //const kernel_stack_size: u64 = 0x5000;
            //const user_stack_reserve: u64 = if (userland) 0x400000 else kernel_stack_size;
            //const user_stack_commit: u64 = if (userland) 0x10000 else 0;
            //var user_stack: u64 = 0;
            //var kernel_stack: u64 = 0;

            //var failed = false;
            //if (!flags.contains(.idle))
            //{
                //kernel_stack = kernel.process.address_space.standard_allocate(kernel_stack_size, Region.Flags.from_flag(.fixed));
                //if (kernel_stack != 0)
                //{
                    //if (userland)
                    //{
                        //user_stack = self.address_space.standard_allocate_extended(user_stack_reserve, Region.Flags.empty(), 0, false);

                        //const region = self.address_space.find_and_pin_region(user_stack, user_stack_reserve).?;
                        //_ = self.address_space.reserve_mutex.acquire();
                        //const success = self.address_space.commit_range(region, (user_stack_reserve - user_stack_commit) / page_size, user_stack_commit / page_size);
                        //self.address_space.reserve_mutex.release();
                        //self.address_space.unpin_region(region);
                        //failed = !success or user_stack == 0;
                    //}
                    //else
                    //{
                        //user_stack = kernel_stack;
                    //}
                //}
                //else
                //{
                    //failed = true;
                //}
            //}

            //if (!failed)
            //{
                //thread.paused.write_volatile((parent_thread != null and parent_thread.?.process != null and parent_thread.?.paused.read_volatile()) or flags.contains(.paused));
                //thread.handle_count.write_volatile(2);
                //thread.is_kernel_thread = !userland;
                //thread.priority = @enumToInt(if (flags.contains(.low_priority)) Thread.Priority.low else Thread.Priority.normal);
                //thread.kernel_stack_base = kernel_stack;
                //thread.user_stack_base = if (userland) user_stack else 0;
                //thread.user_stack_reserve = user_stack_reserve;
                //thread.user_stack_commit.write_volatile(user_stack_commit);
                //thread.terminatable_state.write_volatile(if (userland) .terminatable else .in_syscall);
                //thread.type = if (flags.contains(.async_task)) Thread.Type.async_task else (if (flags.contains(.idle)) Thread.Type.idle else Thread.Type.normal);
                //thread.id = @atomicRmw(u64, &scheduler.next_thread_id, .Add, 1, .SeqCst);
                //thread.process = self;
                //thread.item.value = thread;
                //thread.all_item.value = thread;
                //thread.process_item.value = thread;

                //if (thread.type != .idle)
                //{
                    //thread.interrupt_context = kernel.Arch.initialize_thread(kernel_stack, kernel_stack_size, thread, start_address, argument1, argument2, userland, user_stack, user_stack_reserve);
                //}
                //else
                //{
                    //thread.state.write_volatile(.active);
                    //thread.executing.write_volatile(true);
                //}

                //self.threads.insert_at_end(&thread.process_item);

                //_ = scheduler.all_threads_mutex.acquire();
                //scheduler.all_threads.insert_at_start(&thread.all_item);
                //scheduler.all_threads_mutex.release();

                //_ = open_handle(Process, self, 0);
                //// log

                //if (thread.type == .normal)
                //{
                    //// add to the start of the active thread list
                    //scheduler.dispatch_spinlock.acquire();
                    //scheduler.add_active_thread(thread, true);
                    //scheduler.dispatch_spinlock.release();
                //}
                //else {} // idle and asynchronous threads dont need to be added to a scheduling list

                //// The thread may now be terminated at any moment
                //return thread;
            //}
            //else
            //{
                //if (user_stack != 0) _ = self.address_space.free(user_stack);
                //if (kernel_stack != 0) _ = self.address_space.free(kernel_stack);
                //scheduler.thread_pool.remove(thread);
                //return null;
            //}
        //}
        //else
        //{
            //return null;
        //}

    //}

    //pub fn spawn_thread(self: *@This(), start_address: u64, argument1: u64, flags: Thread.Flags) ?*Thread
    //{
        //return self.spawn_thread_extended(start_address, argument1, flags, 0);
    //}

    //pub fn spawn_thread_no_flags(self: *@This(), start_address: u64, argument1: u64) ?*Thread
    //{
        //return self.spawn_thread(start_address, argument1, Thread.Flags.empty());
    //}
};

pub const Heap = extern struct
{
    mutex: Mutex,
    regions: [12]?*HeapRegion,
    allocation_count: Volatile(u64),
    size: Volatile(u64),
    block_count: Volatile(u64),
    blocks: [16]?*HeapRegion,
    cannot_validate: bool,

    pub fn allocate(self: *@This(), asked_size: u64, zero_memory: bool) u64
    {
        if (@bitCast(i64, asked_size) < 0) KernelPanic("heap panic");

        const size = (asked_size + HeapRegion.used_header_size + 0x1f) & ~@as(u64, 0x1f);

        if (size >= large_allocation_threshold)
        {
            if (@intToPtr(?*HeapRegion, self.allocate_call(size))) |region|
            {
                region.used = HeapRegion.used_magic;
                region.u1.size = 0;
                region.u2.allocation_size = asked_size;
                _ = self.size.atomic_fetch_add(asked_size);
                return region.get_data();
            }
            else
            {
                return 0;
            }
        }

        _ = self.mutex.acquire();

        self.validate();

        const region = blk:
        {
            var heap_index = HeapCalculateIndex(size);
            if (heap_index < self.regions.len)
            {
                for (self.regions[heap_index..]) |maybe_heap_region|
                {
                    if (maybe_heap_region) |heap_region|
                    {
                        if (heap_region.u1.size >= size)
                        {
                            const result = heap_region;
                            result.remove_free();
                            break :blk result;
                        }
                    }
                }
            }

            const allocation = @intToPtr(?*HeapRegion, self.allocate_call(65536));
            if (self.block_count.read_volatile() < 16)
            {
                self.blocks[self.block_count.read_volatile()] = allocation;
            }
            else
            {
                self.cannot_validate = true;
            }
            self.block_count.increment();

            if (allocation) |result|
            {
                result.u1.size = 65536 - 32;
                const end_region = result.get_next().?;
                end_region.used = HeapRegion.used_magic;
                end_region.offset = 65536 - 32;
                end_region.u1.next = 32;
                @intToPtr(?*?*Heap, end_region.get_data()).?.* = self;

                break :blk result;
            }
            else
            {
                // it failed
                self.mutex.release();
                return 0;
            }
        };

        if (region.used != 0 or region.u1.size < size) KernelPanic("heap panic\n");

        self.allocation_count.increment();
        _ = self.size.atomic_fetch_add(size);

        if (region.u1.size != size)
        {
            const old_size = region.u1.size;
            assert(size <= std.math.maxInt(u16));
            const truncated_size = @intCast(u16, size);
            region.u1.size = truncated_size;
            region.used = HeapRegion.used_magic;

            const free_region = region.get_next().?;
            free_region.u1.size = old_size - truncated_size;
            free_region.previous = truncated_size;
            free_region.offset = region.offset + truncated_size;
            free_region.used = 0;
            self.add_free_region(free_region);

            const next_region = free_region.get_next().?;
            next_region.previous = free_region.u1.size;

            self.validate();
        }

        region.used = HeapRegion.used_magic;
        region.u2.allocation_size = asked_size;
        self.mutex.release();

        const address = region.get_data();
        const memory = @intToPtr([*]u8, address)[0..asked_size];
        if (zero_memory)
        {
            std.mem.set(u8, memory, 0);
        }
        else
        {
            std.mem.set(u8, memory, 0xa1);
        }

        return address;
    }

    //fn allocateT(self: *@This(), comptime T: type, zero_memory: bool) callconv(.Inline) ?*T
    //{
        //return @intToPtr(?*T, self.allocate(@sizeOf(T), zero_memory));
    //}

    fn add_free_region(self: *@This(), region: *HeapRegion) void
    {
        if (region.used != 0 or region.u1.size < 32)
        {
            KernelPanic("heap panic\n");
        }

        const index = HeapCalculateIndex(region.u1.size);
        assert(index < std.math.maxInt(u32));
        region.u2.region_list_next = self.regions[index];
        if (region.u2.region_list_next) |region_list_next|
        {
            region_list_next.region_list_reference = &region.u2.region_list_next;
        }
        self.regions[index] = region;
        region.region_list_reference = &self.regions[index];
    }

    fn allocate_call(self: *@This(), size: u64) u64
    {
        if (self == &heapCore)
        {
            //return kernel.core.address_space.standard_allocate(size, Region.Flags.from_flag(.fixed));
            return MMStandardAllocate(&_coreMMSpace, size, Region.Flags.from_flag(.fixed), 0, true);
        }
        else
        {
            return MMStandardAllocate(&_kernelMMSpace, size, Region.Flags.from_flag(.fixed), 0, true);
        }
    }

    fn free_call(self: *@This(), region: *HeapRegion) void
    {
        if (self == &heapCore)
        {
            _ = MMFree(&_coreMMSpace, @ptrToInt(region), 0, false);
        }
        else
        {
            _ = MMFree(&_kernelMMSpace, @ptrToInt(region), 0, false);
        }
    }

    pub fn free(self: *@This(), address: u64, expected_size: u64) void
    {
        if (address == 0 and expected_size != 0) KernelPanic("heap panic");
        if (address == 0) return;

        var region = @intToPtr(*HeapRegion, address).get_header().?;
        if (region.used != HeapRegion.used_magic) KernelPanic("heap panic");
        if (expected_size != 0 and region.u2.allocation_size != expected_size) KernelPanic("heap panic");

        if (region.u1.size == 0)
        {
            _ = self.size.atomic_fetch_sub(region.u2.allocation_size);
            self.free_call(region);
            return;
        }

        {
            const first_region = @intToPtr(*HeapRegion, @ptrToInt(region) - region.offset + 65536 - 32);
            if (@intToPtr(**Heap, first_region.get_data()).* != self) KernelPanic("heap panic");
        }

        _ = self.mutex.acquire();

        self.validate();

        region.used = 0;

        if (region.offset < region.previous) KernelPanic("heap panic");

        self.allocation_count.decrement();
        _ = self.size.atomic_fetch_sub(region.u1.size);

        if (region.get_next()) |next_region|
        {
            if (next_region.used == 0)
            {
                next_region.remove_free();
                region.u1.size += next_region.u1.size;
                next_region.get_next().?.previous = region.u1.size;
            }
        }

        if (region.get_previous()) |previous_region|
        {
            if (previous_region.used == 0)
            {
                previous_region.remove_free();

                previous_region.u1.size += region.u1.size;
                region.get_next().?.previous = previous_region.u1.size;
                region = previous_region;
            }
        }

        if (region.u1.size == 65536 - 32)
        {
            if (region.offset != 0) KernelPanic("heap panic");

            self.block_count.decrement();

            if (!self.cannot_validate)
            {
                var found = false;
                for (self.blocks[0..self.block_count.read_volatile() + 1]) |*heap_region|
                {
                    if (heap_region.* == region)
                    {
                        heap_region.* = self.blocks[self.block_count.read_volatile()];
                        found = true;
                        break;
                    }
                }

                assert(found);
            }

            self.free_call(region);
            self.mutex.release();
            return;
        }

        self.add_free_region(region);
        self.validate();
        self.mutex.release();
    }

    fn validate(self: *@This()) void
    {
        if (self.cannot_validate) return;

        for (self.blocks[0..self.block_count.read_volatile()]) |maybe_start, i|
        {
            if (maybe_start) |start|
            {
                const end = @intToPtr(*HeapRegion, @ptrToInt(self.blocks[i]) + 65536);
                var maybe_previous: ?* HeapRegion = null;
                var region = start;

                while (@ptrToInt(region) < @ptrToInt(end))
                {
                    if (maybe_previous) |previous|
                    {
                        if (@ptrToInt(previous) != @ptrToInt(region.get_previous()))
                        {
                            KernelPanic("heap panic\n");
                        }
                    }
                    else
                    {
                        if (region.previous != 0) KernelPanic("heap panic\n");
                    }

                    if (region.u1.size & 31 != 0) KernelPanic("heap panic");

                    if (@ptrToInt(region) - @ptrToInt(start) != region.offset)
                    {
                        KernelPanic("heap panic\n");
                    }

                    if (region.used != HeapRegion.used_magic and region.used != 0)
                    {
                        KernelPanic("heap panic");
                    }

                    if (region.used == 0 and region.region_list_reference == null)
                    {
                        KernelPanic("heap panic\n");
                    }

                    if (region.used == 0 and region.u2.region_list_next != null and region.u2.region_list_next.?.region_list_reference != &region.u2.region_list_next)
                    {
                        KernelPanic("heap panic");
                    }

                    maybe_previous = region;
                    region = region.get_next().?;
                }

                if (region != end)
                {
                    KernelPanic("heap panic");
                }
            }
        }
    }

    //// @TODO: this may be relying on C undefined behavior and might be causing different results than expected
    //// @TODO: make this a zig function
    //extern fn heap_calculate_index(size: u64) callconv(.C) u64;
    //comptime
    //{
        //asm(
        //\\.intel_syntax noprefix
        //\\.global heap_calculate_index
        //\\heap_calculate_index:
        //\\bsr eax, edi
        //\\xor eax, -32
        //\\add eax, 33
        //\\add rax, -5
        //\\ret
        //);
    //}

    const large_allocation_threshold = 32768;
};

export var heapCore: Heap = undefined;
export var heapFixed: Heap = undefined;

// @TODO: initialize
export var mmCoreRegions: [*]Region = undefined;
export var mmCoreRegionCount: u64 = 0;
export var mmCoreRegionArrayCommit: u64 = 0;

pub const HeapRegion = extern struct
{
    u1: extern union
    {
        next: u16,
        size: u16,
    },

    previous: u16,
    offset: u16,
    used: u16,

    u2: extern union
    {
        allocation_size: u64,
        region_list_next: ?*HeapRegion,
    },

    region_list_reference: ?*?*@This(),

    const used_header_size = @sizeOf(HeapRegion) - @sizeOf(?*?*HeapRegion);
    const free_header_size = @sizeOf(HeapRegion);
    const used_magic = 0xabcd;

    fn remove_free(self: *@This()) void
    {
        if (self.region_list_reference == null or self.used != 0) KernelPanic("heap panic\n");

        self.region_list_reference.?.* = self.u2.region_list_next;

        if (self.u2.region_list_next) |region_list_next|
        {
            region_list_next.region_list_reference = self.region_list_reference;
        }
        self.region_list_reference = null;
    }

    fn get_header(self: *@This()) ?*HeapRegion
    {
        return @intToPtr(?*HeapRegion, @ptrToInt(self) - used_header_size);
    }

    fn get_data(self: *@This()) u64
    {
        return @ptrToInt(self) + used_header_size;
    }

    fn get_next(self: *@This()) ?*HeapRegion
    {
        return @intToPtr(?*HeapRegion, @ptrToInt(self) + self.u1.next);
    }

    fn get_previous(self: *@This()) ?*HeapRegion
    {
        if (self.previous != 0)
        {
            return @intToPtr(?*HeapRegion, @ptrToInt(self) - self.previous);
        }
        else
        {
            return null;
        }
    }
};

pub const Pool = extern struct
{
    element_size: u64, // @ABICompatibility @Delete
    cache_entries: [cache_count]u64,
    cache_entry_count: u64,
    mutex: Mutex,

    const cache_count = 16;

    pub fn add(self: *@This(), element_size: u64) u64
    {
        _ = self.mutex.acquire();
        defer self.mutex.release();

        if (self.element_size != 0 and element_size != self.element_size) KernelPanic("pool size mismatch");
        self.element_size = element_size;

        if (self.cache_entry_count != 0)
        {
            self.cache_entry_count -= 1;
            const address = self.cache_entries[self.cache_entry_count];
            std.mem.set(u8, @intToPtr([*]u8, address)[0..self.element_size], 0);
            return address;
        }
        else
        {
            return EsHeapAllocate(self.element_size, true, &heapFixed);
            //return @intToPtr(?*T, kernel.core.fixed_heap.allocate(@sizeOf(T), true));
        }
    }

    pub fn remove(self: *@This(), pointer: u64) void
    {
        _ = self.mutex.acquire();
        defer self.mutex.release();

        if (pointer == 0) return;

        if (self.cache_entry_count == cache_count)
        {
            EsHeapFree(pointer, self.element_size, &heapFixed);
        }
        else
        {
            self.cache_entries[self.cache_entry_count] = pointer;
            self.cache_entry_count += 1;
        }
    }
};

export fn PoolAdd(pool: *Pool, element_size: u64) callconv(.C) u64
{
    return pool.add(element_size);
}

export fn PoolRemove(pool: *Pool, pointer: u64) callconv(.C) void
{
    pool.remove(pointer);
}

pub const ArchAddressSpace = extern struct
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

pub const AddressSpace = extern struct
{
    arch: ArchAddressSpace,

    free_region_base: AVLTree(Region),
    free_region_size: AVLTree(Region),
    used_regions: AVLTree(Region),
    used_regions_non_guard: LinkedList(Region),

    reserve_mutex: Mutex,

    reference_count: Volatile(i32),
    user: bool,
    commit_count: u64,
    reserve_count: u64,
    remove_async_task: AsyncTask,
    //pub fn handle_page_fault(self: *@This(), fault_address: u64, flags: HandlePageFaultFlags) bool
    //{
        //const address = fault_address & ~@as(u64, page_size - 1);

        //const lock_acquired = flags.contains(.lock_acquired);
        //if (!lock_acquired and kernel.physical_allocator.get_available_page_count() < Physical.Allocator.critical_available_page_threshold and GetCurrentThread() != null and !GetCurrentThread().?.is_page_generator)
        //{
            //TODO();
        //}

        //var region: *Region = undefined;
        //{
            //if (!lock_acquired) _ = self.reserve_mutex.acquire()
            //else self.reserve_mutex.assert_locked();
            //defer if (!lock_acquired) self.reserve_mutex.release();

            //if (self.find_region(address)) |result|
            //{
                //if (!result.data.pin.take_extended(WriterLock.shared, true)) return false;
                //region = result;
            //}
            //else
            //{
                //return false;
            //}
        //}

        //defer region.data.pin.return_lock(WriterLock.shared);
        //_ = region.data.map_mutex.acquire();
        //defer region.data.map_mutex.release();

        //// Spurious page fault
        //if (kernel.arch.translate_address(address, flags.contains(.write)) != 0)
        //{
            //return true;
        //}

        //var copy_on_write = false;
        //var mark_modified = false;

        //if (flags.contains(.write))
        //{
            //if (region.flags.contains(.copy_on_write)) copy_on_write = true
            //else if (region.flags.contains(.read_only)) return false
            //else mark_modified = true;
        //}

        //const offset_into_region = address - region.descriptor.base_address;
        //_ = offset_into_region;
        //var physical_allocation_flags = Physical.Flags.empty();
        //var zero_page = true;
        //var map_page_flags: MapPageFlags = MapPageFlags.empty();

        //if (self.user)
        //{
            //physical_allocation_flags = physical_allocation_flags.or_flag(.zeroed);
            //zero_page = false;
            //map_page_flags = map_page_flags.or_flag(.user);
        //}

        //if (region.flags.contains(.not_cacheable)) map_page_flags = map_page_flags.or_flag(.not_cacheable);
        //if (region.flags.contains(.write_combining)) map_page_flags = map_page_flags.or_flag(.write_combining);
        //if (!mark_modified and !region.flags.contains(.fixed) and region.flags.contains(.file)) map_page_flags = map_page_flags.or_flag(.read_only);

        //if (region.flags.contains(.physical))
        //{
            //_ = kernel.arch.map_page(self, region.data.u.physical.offset + address - region.descriptor.base_address, address, map_page_flags);
            //return true;
        //}
        //else if (region.flags.contains(.shared))
        //{
            //const shared_region = region.data.u.shared.region.?;

            //if (shared_region.handle_count.read_volatile() == 0) KernelPanic("shared region has no handles");

            //_ = shared_region.mutex.acquire();
            //defer shared_region.mutex.release();

            //const offset = address - region.descriptor.base_address + region.data.u.shared.offset;

            //if (offset >= shared_region.size)
            //{
                //return false;
            //}

            //const entry = @intToPtr(*u64, shared_region.address + (offset / page_size * @sizeOf(u64)));
            //if (entry.* & shared_entry_present != 0) zero_page = false
            //else entry.* = kernel.physical_allocator.allocate_with_flags(physical_allocation_flags) | shared_entry_present;

            //_ = kernel.arch.map_page(self, entry.* & ~@as(u64, page_size - 1), address, map_page_flags);
            //if (zero_page) std.mem.set(u8, @intToPtr([*]u8, address)[0..page_size], 0);
            //return true;
        //}
        //else if (region.flags.contains(.file))
        //{
            //TODO();
        //}
        //else if (region.flags.contains(.normal))
        //{
            //if (!region.flags.contains(.no_commit_tracking) and !region.data.u.normal.commit.contains(offset_into_region >> page_bit_count))
            //{
                //return false;
            //}

            //const physical_address = kernel.physical_allocator.allocate_with_flags(physical_allocation_flags);
            //_ = kernel.arch.map_page(self, physical_address, address, map_page_flags);
            //if (zero_page) std.mem.set(u8, @intToPtr([*]u8, address)[0..page_size], 0);
            //return true;
        //}
        //else if (region.flags.contains(.guard))
        //{
            //TODO();
        //}
        //else
        //{
            //TODO();
        //}
    //}

    //pub fn find_region(self: *@This(), address: u64) ?*Region
    //{
        //self.reserve_mutex.assert_locked();

        //if (self == &kernel.core.address_space)
        //{
            //const regions = kernel.core.regions;
            //for (regions) |*region|
            //{
                //if (region.u.core.used and
                    //region.descriptor.base_address <= address and
                    //region.descriptor.base_address + (region.descriptor.page_count * page_size) > address)
                //{
                    //return region;
                //}
            //}
        //}
        //else
        //{
            //if (self.used_regions.find(address, .largest_below_or_equal)) |item|
            //{
                //const region = item.value.?;
                //if (region.descriptor.base_address > address) KernelPanic("broken used_regions use\n");
                //if (region.descriptor.base_address + region.descriptor.page_count * page_size > address)
                //{
                    //return region;
                //}
            //}
        //}

        //return null;
    //}

    //pub fn reserve(self: *@This(), byte_count: u64, flags: Region.Flags) ?*Region
    //{
        //return self.reserve_extended(byte_count, flags, 0);
    //}

    //pub fn reserve_extended(self: *@This(), byte_count: u64, flags: Region.Flags, forced_address: u64) ?*Region
    //{
        //const needed_page_count = ((byte_count + page_size - 1) & ~@as(u64, page_size - 1)) / page_size;

        //if (needed_page_count == 0) return null;

        //self.reserve_mutex.assert_locked();

        //const region = blk:
        //{
            //if (self == &kernel.core.address_space)
            //{
                //if (kernel.core.regions.len == kernel.Arch.core_memory_region_count) return null;

                //if (forced_address != 0) KernelPanic("Using a forced address in core address space\n");

                //{
                    //const new_region_count = kernel.core.regions.len + 1;
                    //const needed_commit_page_count = new_region_count * @sizeOf(Region) / page_size;

                    //while (kernel.core.region_commit_count < needed_commit_page_count) : (kernel.core.region_commit_count += 1)
                    //{
                        //if (!kernel.physical_allocator.commit(page_size, true)) return null;
                    //}
                //}

                //for (kernel.core.regions) |*region|
                //{
                    //if (!region.u.core.used and region.descriptor.page_count >= needed_page_count)
                    //{
                        //if (region.descriptor.page_count > needed_page_count)
                        //{
                            //const last = kernel.core.regions.len;
                            //kernel.core.regions.len += 1;
                            //var split = &kernel.core.regions[last];
                            //split.* = region.*;
                            //split.descriptor.base_address += needed_page_count * page_size;
                            //split.descriptor.page_count -= needed_page_count;
                        //}

                        //region.u.core.used = true;
                        //region.descriptor.page_count = needed_page_count;
                        //region.flags = flags;
                        //// @WARNING: this is not working and may cause problem with the kernel
                        //// region.data = std.mem.zeroes(@TypeOf(region.data));
                        //region.zero_data_field();
                        //assert(region.data.u.normal.commit.ranges.items.len == 0);

                        //break :blk region;
                    //}
                //}

                //return null;
            //}
            //else if (forced_address != 0)
            //{
                //TODO();
            //}
            //else
            //{
                //// @TODO: implement guard pages?
                
                //if (self.free_region_size.find(needed_page_count, .smallest_above_or_equal)) |item|
                //{
                    //const region = item.value.?;
                    //self.free_region_base.remove(&region.u.item.base);
                    //self.free_region_size.remove(&region.u.item.u.size);

                    //if (region.descriptor.page_count > needed_page_count)
                    //{
                        //const split = kernel.core.heap.allocateT(Region, true).?;
                        //split.* = region.*;

                        //split.descriptor.base_address += needed_page_count * page_size;
                        //split.descriptor.page_count -= needed_page_count;

                        //_ = self.free_region_base.insert(&split.u.item.base, split, split.descriptor.base_address, .panic);
                        //_ = self.free_region_size.insert(&split.u.item.u.size, split, split.descriptor.page_count, .allow);
                    //}

                    //region.zero_data_field();
                    //region.descriptor.page_count = needed_page_count;
                    //region.flags = flags;
                    
                    //// @TODO: if guard pages needed
                    //_ = self.used_regions.insert(&region.u.item.base, region, region.descriptor.base_address, .panic);
                    //break :blk region;
                //}
                //else
                //{
                    //return null;
                //}
            //}
        //};

        //if (!kernel.arch.commit_page_tables(self, region))
        //{
            //self.unreserve(region, false);
            //return null;
        //}

        //if (self != &kernel.core.address_space)
        //{
            //region.u.item.u.non_guard = std.mem.zeroes(@TypeOf(region.u.item.u.non_guard));
            //region.u.item.u.non_guard.value = region;
            //self.used_regions_non_guard.insert_at_end(&region.u.item.u.non_guard);
        //}

        //self.reserve_count += needed_page_count;

        //return region;
    //}

    //pub fn unreserve(self: *@This(), region_to_remove: *Region, unmap_pages: bool) void
    //{
        //self.unreserve_extended(region_to_remove, unmap_pages, false);
    //}

    //pub fn unreserve_extended(self: *@This(), region_to_remove: *Region, unmap_pages: bool, guard_region: bool) void
    //{
        //self.reserve_mutex.assert_locked();

        //if (kernel.physical_allocator.next_region_to_balance == region_to_remove)
        //{
            //// if the balance thread paused while balancing this region, switch to the next region
            //kernel.physical_allocator.next_region_to_balance = if (region_to_remove.u.item.u.non_guard.next) |next_item| next_item.value else null;
            //kernel.physical_allocator.balance_resume_position = 0;
        //}

        //if (region_to_remove.flags.contains(.normal))
        //{
            //if (region_to_remove.data.u.normal.guard_before) |guard_before| self.unreserve_extended(guard_before, false, true);
            //if (region_to_remove.data.u.normal.guard_after) |guard_after| self.unreserve_extended(guard_after, false, true);
        //}
        //else if (region_to_remove.flags.contains(.guard) and !guard_region)
        //{
            //// you can't free a guard region
            //// @TODO: error
            //return;
        //}

        //if (region_to_remove.u.item.u.non_guard.list != null and !guard_region)
        //{
            //region_to_remove.u.item.u.non_guard.remove_from_list();
        //}

        //if (unmap_pages) kernel.arch.unmap_pages(self, region_to_remove.descriptor.base_address, region_to_remove.descriptor.page_count, UnmapPagesFlags.empty());

        //self.reserve_count += region_to_remove.descriptor.page_count;

        //if (self == &kernel.core.address_space)
        //{
            //TODO();
        //}
        //else
        //{
            //self.used_regions.remove(&region_to_remove.u.item.base);
            //const address = region_to_remove.descriptor.base_address;

            //{
                //if (self.free_region_base.find(address, .largest_below_or_equal)) |before|
                //{
                    //if (before.value.?.descriptor.base_address + before.value.?.descriptor.page_count * page_size == region_to_remove.descriptor.base_address)
                    //{
                        //region_to_remove.descriptor.base_address = before.value.?.descriptor.base_address;
                        //region_to_remove.descriptor.page_count += before.value.?.descriptor.page_count;
                        //self.free_region_base.remove(before);
                        //self.free_region_size.remove(&before.value.?.u.item.u.size);
                        //kernel.core.heap.free(@ptrToInt(before.value), @sizeOf(Region));
                    //}
                //}
            //}

            //{
                //if (self.free_region_base.find(address, .smallest_above_or_equal)) |after|
                //{
                    //if (region_to_remove.descriptor.base_address + region_to_remove.descriptor.page_count * page_size == after.value.?.descriptor.base_address)
                    //{
                        //region_to_remove.descriptor.page_count += after.value.?.descriptor.page_count;
                        //self.free_region_base.remove(after);
                        //self.free_region_size.remove(&after.value.?.u.item.u.size);
                        //kernel.core.heap.free(@ptrToInt(after.value), @sizeOf(Region));
                    //}
                //}
            //}
            
            //_ = self.free_region_base.insert(&region_to_remove.u.item.base, region_to_remove, region_to_remove.descriptor.base_address, .panic);
            //_ = self.free_region_size.insert(&region_to_remove.u.item.u.size, region_to_remove, region_to_remove.descriptor.page_count, .allow);
        //}
    //}

    //pub fn standard_allocate(self: *@This(), byte_count: u64, flags: Region.Flags) u64
    //{
        //return self.standard_allocate_extended(byte_count, flags, 0, true);
    //}

    //pub fn standard_allocate_extended(self: *@This(), byte_count: u64, flags: Region.Flags, base_address: u64, commit_all: bool) u64
    //{
        //_ = self.reserve_mutex.acquire();
        //defer self.reserve_mutex.release();

        //if (self.reserve_extended(byte_count, flags.or_flag(.normal), base_address)) |region|
        //{
            //if (commit_all and !self.commit_range(region, 0, region.descriptor.page_count))
            //{
                //self.unreserve(region, false);
                //return 0;
            //}

            //return region.descriptor.base_address;
        //}
        //else
        //{
            //return 0;
        //}
    //}

    //pub fn commit_range(self: *@This(), region: *Region, page_offset: u64, page_count: u64) bool
    //{
        //self.reserve_mutex.assert_locked();
        
        //if (region.flags.contains(.no_commit_tracking))
        //{
            //KernelPanic("region does not support commit tracking");
        //}

        //if (page_offset >= region.descriptor.page_count or page_count > region.descriptor.page_count - page_offset)
        //{
            //KernelPanic("invalid region offset and page count");
        //}

        //if (!region.flags.contains(.normal))
        //{
            //KernelPanic("cannot commit into non-normal region");
        //}

        //var delta_s: i64 = 0;

        //_ = region.data.u.normal.commit.set(page_offset, page_offset + page_count, &delta_s, false);

        //if (delta_s < 0)
        //{
            //KernelPanic("commit range invalid delta calculation");
        //}
        
        //const delta = @intCast(u64, delta_s);

        //if (delta == 0) return true;

        //{
            //const commit_byte_count = delta * page_size;
            //if (!kernel.physical_allocator.commit(commit_byte_count, region.flags.contains(.fixed))) return false;

            //region.data.u.normal.commit_page_count += delta;
            //self.commit_count += delta;

            //if (region.data.u.normal.commit_page_count > region.descriptor.page_count)
            //{
                //KernelPanic("invalid delta calculation increases region commit past page count");
            //}
        //}

        //if (!region.data.u.normal.commit.set(page_offset, page_offset + page_count, null, true))
        //{
            //TODO();
        //}

        //if (region.flags.contains(.fixed))
        //{
            //var i: u64 = page_offset;
            //while (i < page_offset + page_count) : (i += 1)
            //{
                //if (!self.handle_page_fault(region.descriptor.base_address + i * page_size, HandlePageFaultFlags.from_flag(.lock_acquired)))
                //{
                    //KernelPanic("unable to fix pages\n");
                //}
            //}
        //}

        //return true;
    //}

    //pub fn find_and_pin_region(self: *@This(), address: u64, size: u64) ?*Region
    //{
        //// @TODO: this is overflow, we should handle it in a different way
        //if (address + size < address) return null;

        //_ = self.reserve_mutex.acquire();
        //defer self.reserve_mutex.release();

        //if (self.find_region(address)) |region|
        //{
            //if (region.descriptor.base_address > address) return null;
            //if (region.descriptor.base_address  + region.descriptor.page_count * page_size < address + size) return null;
            //if (!region.data.pin.take_extended(WriterLock.shared, true)) return null;

            //return region;
        //}
        //else
        //{
            //return null;
        //}
    //}

    //pub fn unpin_region(self: *@This(), region: *Region) void
    //{
        //_ = self.reserve_mutex.acquire();
        //region.data.pin.return_lock(WriterLock.shared);
        //self.reserve_mutex.release();
    //}

    //pub fn free(self: *@This(), address: u64) bool
    //{
        //return self.free_extended(address, 0, false);
    //}

    //pub fn free_extended(self: *@This(), address: u64, expected_size: u64, user_only: bool) bool
    //{
        //{
            //_ = self.reserve_mutex.acquire();
            //defer self.reserve_mutex.release();

            //if (self.find_region(address)) |region|
            //{
                //if (user_only and !region.flags.contains(.user)) return false;
                //if (!region.data.pin.take_extended(WriterLock.exclusive, true)) return false;
                //if (region.descriptor.base_address != address and !region.flags.contains(.physical)) return false;
                //if (expected_size != 0 and (expected_size + page_size - 1) / page_size != region.descriptor.page_count) return false;

                //var unmap_pages = true;

                //if (region.flags.contains(.normal))
                //{
                    //TODO();
                //}
                //else if (region.flags.contains(.shared))
                //{
                    //TODO();
                //}
                //else if (region.flags.contains(.file))
                //{
                    //TODO();
                //}
                //else if (region.flags.contains(.physical))
                //{
                    //// do nothing
                //}
                //else if (region.flags.contains(.guard))
                //{
                    //return false;
                //}
                //else
                //{
                    //KernelPanic("unsupported region type\n");
                //}

                //self.unreserve(region, unmap_pages);
            //}
            //else
            //{
                //return false;
            //}
        //}

        //// @TODO: handle this in their if block
        ////if (sharedRegionToFree) CloseHandleToObject(sharedRegionToFree, KERNEL_OBJECT_SHMEM);
        ////if (nodeToFree && fileHandleFlags) CloseHandleToObject(nodeToFree, KERNEL_OBJECT_NODE, fileHandleFlags);
        //return true;
    //}

    //pub fn map_shared(self: *@This(), shared_region: *SharedRegion, offset: u64, byte_count: u64) u64
    //{
        //return self.map_shared(shared_region, offset, byte_count);
    //}

    //pub fn map_shared_extended(self: *@This(), shared_region: *SharedRegion, offset: u64, bytes: u64, additional_flags: Region.Flags, base_address: u64) u64
    //{
        //_ = open_handle(SharedRegion, shared_region, 0);

        //_ = self.reserve_mutex.acquire();
        //defer self.reserve_mutex.release();
        //var byte_count = bytes;
        //if (offset & (page_size - 1) != 0) byte_count += offset & (page_size - 1);
        //if (shared_region.size > offset and shared_region.size >= offset + byte_count)
        //{
            //if (self.reserve_extended(byte_count, additional_flags.or_flag(.shared), base_address)) |region|
            //{
                //if (!region.flags.contains(.shared)) KernelPanic("cannot commit into non-shared region");
                //if (region.data.u.shared.region != null) KernelPanic("a shared region has already been bound");

                //region.data.u.shared.region = shared_region;
                //region.data.u.shared.offset = offset & ~@as(u64, page_size - 1);
                //return region.descriptor.base_address + (offset & (page_size - 1));
            //}
        //}

        //// fail
        //TODO();
    //}

    //pub fn map_physical(self: *@This(), asked_offset: u64, asked_byte_count: u64, flags: Region.Flags) u64
    //{
        //const offset2 = asked_offset & (page_size - 1);
        //const offset = asked_offset - offset2;
        //const byte_count= asked_byte_count + @as(u64, if (offset2 != 0) page_size else 0);

        //const region = blk:
        //{
            //_ = self.reserve_mutex.acquire();
            //defer self.reserve_mutex.release();

            //if (self.reserve(byte_count, flags.or_flag(.physical).or_flag(.fixed))) |result|
            //{
                //result.data.u.physical.offset = offset;
                //break :blk result;
            //}
            //else
            //{
                //return 0;
            //}
        //};

        //var page: u64 = 0;
        //while (page < region.descriptor.page_count) : (page += 1)
        //{
            //_ = self.handle_page_fault(region.descriptor.base_address + page * page_size, HandlePageFaultFlags.empty());
        //}

        //return region.descriptor.base_address + offset2;
    //}

    //pub fn open_reference(self: *@This()) void
    //{
        //if (self == &kernel.process.address_space) return;
        //if (self.reference_count.read_volatile() < 1) KernelPanic("space has invalid reference count");

        //// @TODO: max processors macro 
        //if (self.reference_count.read_volatile() >= 256 + 1) KernelPanic("space has too many references");

        //_ = self.reference_count.atomic_fetch_add(1);
    //}

    //pub fn close_reference(self: *@This()) void
    //{
        //if (self == &kernel.process.address_space) return;
        //if (self.reference_count.read_volatile() < 1) KernelPanic("space has invalid reference count");

        //if (self.reference_count.atomic_fetch_sub(1) > 1) return;

        //self.remove_async_task.register(remove_async);
    //}

    //fn remove_async(task: *AsyncTask) void
    //{
        //_ = task;
        //TODO();
    //}
};

export var _kernelMMSpace: AddressSpace = undefined;
export var _coreMMSpace: AddressSpace = undefined;

pub const Event = extern struct
{
    auto_reset: Volatile(bool),
    state: Volatile(u64),
    blocked_threads: LinkedList(Thread),
    handle_count: Volatile(u64),

    /// already_set default = false
    pub fn set(self: *@This(), already_set: bool) bool
    {
        if (self.state.read_volatile() != 0 and !already_set)
        {
            // log error
        }

        scheduler.dispatch_spinlock.acquire();

        var unblocked_threads = Volatile(bool) { .value = false };

        if (self.state.read_volatile() == 0)
        {
            self.state.write_volatile(@boolToInt(true));

            if (scheduler.started.read_volatile())
            {
                if (self.blocked_threads.count != 0) unblocked_threads.write_volatile(true);
                SchedulerNotifyObject(&self.blocked_threads, !self.auto_reset.read_volatile(), null);
            }
        }

        scheduler.dispatch_spinlock.release();
        return unblocked_threads.read_volatile();
    }

    pub fn reset(self: *@This()) void
    {
        if (self.blocked_threads.first != null and self.state.read_volatile() != 0)
        {
            // log error
        }

        self.state.write_volatile(@boolToInt(false));
    }

    pub fn poll(self: *@This()) bool
    {
        if (self.auto_reset.read_volatile())
        {
            if (self.state.atomic_compare_and_swap(@boolToInt(true), @boolToInt(false))) |value|
            {
                return value != 0;
            }
            else
            {
                return true;
            }
        }
        else
        {
            return self.state.read_volatile() != 0;
        }
    }

    pub fn wait(self: *@This()) bool
    {
        return self.wait_extended(wait_no_timeout);
    }
    
    pub fn wait_extended(self: *@This(), timeout_ms: u64) bool
    {
        var events: [2]*Event = undefined;
        events[0] = self;

        if (timeout_ms == wait_no_timeout)
        {
            const index = wait_multiple(&events, 1);
            return index == 0;
        }
        else
        {
            var timer: Timer = undefined;
            std.mem.set(u8, @ptrCast([*]u8, &timer)[0..@sizeOf(Timer)], 0);
            timer.set(timeout_ms);
            events[1] = &timer.event;
            const index = wait_multiple(&events, 2);
            timer.remove();
            return index == 0;
        }
    }

    fn wait_multiple(event_ptr: [*]*Event, event_len: u64) u64
    {
        var events = event_ptr[0..event_len];
        if (events.len > max_wait_count) KernelPanic("count too high")
        else if (events.len == 0) KernelPanic("count 0")
        else if (!ProcessorAreInterruptsEnabled()) KernelPanic("timer with interrupts disabled");

        const thread = GetCurrentThread().?;
        thread.blocking.event.count = events.len;

        var event_items: [512]LinkedList(Thread).Item = undefined;
        std.mem.set(u8, @ptrCast([*]u8, &event_items)[0..@sizeOf(@TypeOf(event_items))], 0);
        thread.blocking.event.items = &event_items;
        defer thread.blocking.event.items = null;

        for (thread.blocking.event.items.?[0..thread.blocking.event.count]) |*event_item, i|
        {
            event_item.value = thread;
            thread.blocking.event.array[i] = events[i];
        }

        while (!thread.terminating.read_volatile() or thread.terminatable_state.read_volatile() != .user_block_request)
        {
            for (events) |event, i|
            {
                if (event.auto_reset.read_volatile())
                {
                    if (event.state.read_volatile() != 0)
                    {
                        thread.state.write_volatile(.active);
                        const result = event.state.atomic_compare_and_swap(0, 1);
                        if (result) |resultu|
                        {
                            if (resultu != 0) return i;
                        }
                        else
                        {
                            return i;
                        }

                        thread.state.write_volatile(.waiting_event);
                    }
                }
                else
                {
                    if (event.state.read_volatile() != 0)
                    {
                        thread.state.write_volatile(.active);
                        return i;
                    }
                }
            }

            ProcessorFakeTimerInterrupt();
        }
        
        return std.math.maxInt(u64);
    }
};

export fn KEventSet(event: *Event, maybe_already_set: bool) callconv(.C) bool
{
    return event.set(maybe_already_set);
}

export fn KEventReset(event: *Event) callconv(.C) void
{
    event.reset();
}

export fn KEventPoll(event: *Event) callconv(.C) bool
{
    return event.poll();
}

export fn KEventWait(event: *Event, timeout_ms: u64) callconv(.C) bool
{
    return event.wait_extended(timeout_ms);
}

export fn KEventWaitMultiple(events: [*]*Event, count: u64) callconv(.C) u64
{
    return Event.wait_multiple(events, count);
}

pub const CPU = extern struct
{
    processor_ID: u8,
    kernel_processor_ID: u8,
    APIC_ID: u8,
    boot_processor: bool,
    kernel_stack: *align(1) u64,
    local_storage: ?*LocalStorage,
};

pub const SimpleList = extern struct
{
    previous_or_last: ?*@This(),
    next_or_first: ?*@This(),

    pub fn insert(self: *@This(), item: *SimpleList, start: bool) void
    {
        if (item.previous_or_last != null or item.next_or_first != null)
        {
            KernelPanic("bad links");
        }

        if (self.next_or_first == null and self.previous_or_last == null)
        {
            item.previous_or_last = self;
            item.next_or_first = self;
            self.next_or_first = item;
            self.previous_or_last = item;
        }
        else if (start)
        {
            item.previous_or_last = self;
            item.next_or_first = self.next_or_first;
            self.next_or_first.?.previous_or_last = item;
            self.next_or_first = item;
        }
        else
        {
            item.previous_or_last = self.previous_or_last;
            item.next_or_first = self;
            self.previous_or_last.?.next_or_first = item;
            self.previous_or_last = item;
        }
    }

    pub fn remove(self: *@This()) void
    {
        if (self.previous_or_last.?.next_or_first != self or self.next_or_first.?.previous_or_last != self) KernelPanic("bad links");

        if (self.previous_or_last == self.next_or_first)
        {
            self.next_or_first.?.next_or_first = null;
            self.next_or_first.?.previous_or_last = null;
        }
        else
        {
            self.previous_or_last.?.next_or_first = self.next_or_first;
            self.next_or_first.?.previous_or_last = self.previous_or_last;
        }

        self.previous_or_last = null;
        self.next_or_first = null;
    }
};


pub const WriterLock = extern struct
{
    blocked_threads: LinkedList(Thread),
    state: Volatile(i64),

    pub fn take(self: *@This(), write: bool) bool
    {
        return self.take_extended(write, false);
    }

    pub fn take_extended(self: *@This(), write: bool, poll: bool) bool
    {
        var done = false;
        const maybe_current_thread = GetCurrentThread();
        if (maybe_current_thread) |thread|
        {
            thread.blocking.writer.lock = self;
            thread.blocking.writer.type = write;
            @fence(.SeqCst);
        }

        while (true)
        {
            scheduler.dispatch_spinlock.acquire();

            if (write)
            {
                if (self.state.read_volatile() == 0)
                {
                    self.state.write_volatile(-1);
                    done = true;
                }
            }
            else
            {
                if (self.state.read_volatile() >= 0)
                {
                    self.state.increment();
                    done = true;
                }
            }

            scheduler.dispatch_spinlock.release();

            if (poll or done) break
            else
            {
                if (maybe_current_thread) |thread|
                {
                    thread.state.write_volatile(.waiting_writer_lock);
                    ProcessorFakeTimerInterrupt();
                    thread.state.write_volatile(.active);
                }
                else
                {
                    KernelPanic("scheduler not ready yet\n");
                }
            }
        }

        return done;
    }

    pub fn return_lock(self: *@This(), write: bool) void
    {
        scheduler.dispatch_spinlock.acquire();

        const lock_state = self.state.read_volatile();
        if (lock_state == -1)
        {
            if (!write) KernelPanic("attempt to return shared access to an exclusively owned lock");

            self.state.write_volatile(0);
        }
        else if (lock_state == 0)
        {
            KernelPanic("attempt to return access to an unowned lock");
        }
        else
        {
            if (write) KernelPanic("attempting to return exclusive access to a shared lock");

            self.state.decrement();
        }

        if (self.state.read_volatile() == 0)
        {
            SchedulerNotifyObject(&self.blocked_threads, true, null);
        }

        scheduler.dispatch_spinlock.release();
    }

    pub fn assert_exclusive(self: *@This()) void
    {
        const lock_state = self.state.read_volatile();
        if (lock_state == 0) KernelPanic("unlocked")
        else if (lock_state > 0) KernelPanic("shared mode");
    }

    pub fn assert_shared(self: *@This()) void
    {
        const lock_state = self.state.read_volatile();
        if (lock_state == 0) KernelPanic("unlocked")
        else if (lock_state < 0) KernelPanic("exclusive mode");
    }

    pub fn assert_locked(self: *@This()) void
    {
        if (self.state.read_volatile() == 0) KernelPanic("unlocked");
    }

    pub fn convert_exclusive_to_shared(self: *@This()) void
    {
        scheduler.dispatch_spinlock.acquire();
        self.assert_exclusive();
        self.state.write_volatile(1);
        SchedulerNotifyObject(&self.blocked_threads, true, null);
        scheduler.dispatch_spinlock.release();
    }

    pub const shared = false;
    pub const exclusive = true;
};

export fn KWriterLockTake(lock: *WriterLock, write: bool, poll: bool) callconv(.C) bool
{
    return lock.take_extended(write, poll);
}
export fn KWriterLockReturn(lock: *WriterLock, write: bool) callconv(.C) void
{
    lock.return_lock(write);
}
export fn KWriterLockConvertExclusiveToShared(lock: *WriterLock) callconv(.C) void
{
    lock.convert_exclusive_to_shared();
}
export fn KWriterLockAssertExclusive(lock: *WriterLock) callconv(.C) void
{
    lock.assert_exclusive();
}
export fn KWriterLockAssertShared(lock: *WriterLock) callconv(.C) void
{
    lock.assert_shared();
}
export fn KWriterLockAssertLocked(lock: *WriterLock) callconv(.C) void
{
    lock.assert_locked();
}

pub const AsyncTask = extern struct
{
    item: SimpleList,
    callback: u64, // ?Callback

    comptime
    {
        assert(@sizeOf(AsyncTask) == @sizeOf(SimpleList) + 8);
    }

    pub const Callback = fn (*@This()) void;

    pub fn register(self: *@This(), callback: Callback) void
    {
        assert(@ptrToInt(callback) != 0);
        scheduler.async_task_spinlock.acquire();
        if (self.callback == 0)
        {
            self.callback = @ptrToInt(callback);
            GetLocalStorage().?.async_task_list.insert(&self.item, false);
        }
        scheduler.async_task_spinlock.release();
    }
};
pub fn Bitflag(comptime EnumT: type) type
{
    return extern struct
    {
        const IntType = std.meta.Int(.unsigned, @bitSizeOf(EnumT));
        const Enum = EnumT;

        bits: IntType,

        pub fn from_flags(flags: anytype) callconv(.Inline) @This()
        {
            const flags_type = @TypeOf(flags);
            const result = comptime blk:
            {
                const fields = std.meta.fields(flags_type);
                if (fields.len > @bitSizeOf(EnumT)) @compileError("More flags than bits\n");

                var bits: IntType = 0;

                var field_i: u64 = 0;
                inline while (field_i < fields.len) : (field_i += 1)
                {
                    const field = fields[field_i];
                    const enum_value: EnumT = field.default_value.?;
                    bits |= 1 << @enumToInt(enum_value);
                }
                break :blk bits;
            };
            return @This() { .bits = result };
        }

        pub fn from_bits(bits: IntType) @This()
        {
            return @This() { .bits = bits };
        }

        pub fn from_flag(comptime flag: EnumT) callconv(.Inline) @This()
        {
            const bits = 1 << @enumToInt(flag);
            return @This() { .bits = bits };
        }

        pub fn empty() callconv(.Inline) @This()
        {
            return @This()
            {
                .bits = 0,
            };
        }

        pub fn all() callconv(.Inline) @This()
        {
            var result = comptime blk:
            {
                var bits: IntType = 0;
                inline for (@typeInfo(EnumT).Enum.fields) |field|
                {
                    bits |= 1 << field.value;
                }
                break :blk @This()
                {
                    .bits = bits,
                };
            };
            return result;
        }

        pub fn is_empty(self: @This()) callconv(.Inline) bool
        {
            return self.bits == 0;
        }

        /// This assumes invalid values in the flags can't be set.
        pub fn is_all(self: @This()) callconv(.Inline) bool
        {
            return all().bits == self.bits;
        }

        pub fn contains(self: @This(), comptime flag: EnumT) callconv(.Inline) bool
        {
            return ((self.bits & (1 << @enumToInt(flag))) >> @enumToInt(flag)) != 0;
        }

        // TODO: create a mutable version of this
        pub fn or_flag(self: @This(), comptime flag: EnumT) callconv(.Inline) @This()
        {
            const bits = self.bits | 1 << @enumToInt(flag);
            return @This() { .bits = bits };
        }
    };
}

const HeapType = enum
{
    core,
    fixed,
};

// @TODO -> this is just to maintain abi compatibility with the C++ implementation
pub fn Array(comptime T: type, comptime heap_type: HeapType) type
{
    _ = heap_type;
    return extern struct
    {
        ptr: ?[*]T,

        fn length(self: @This()) u64
        {
            return ArrayHeaderGetLength(@ptrCast(?*u64, self.ptr));
        }

        fn get_slice(self: @This()) []T
        {
            if (self.ptr) |ptr|
            {
                return ptr[0..self.length()];
            }
            else
            {
                KernelPanic("Array ptr is null");
            }
        }

        fn free(self: *@This()) void
        {
            _ArrayFree(@ptrCast(*?*u64, &self.ptr), @sizeOf(T), get_heap());
        }

        fn get_heap() *Heap
        {
            return switch (heap_type)
            {
                .core => &heapCore,
                .fixed => &heapFixed,
            };
        }

        fn insert(self: *@This(), item: T, position: u64) ?*T
        {
            return @intToPtr(?*T, _ArrayInsert(@ptrCast(*?*u64, &self.ptr), @ptrToInt(&item), @sizeOf(T), @bitCast(i64, position), 0, get_heap()));
        }

        fn delete_many(self: *@This(), position: u64, count: u64) void
        {
            _ArrayDelete(@ptrCast(?*u64, self.ptr), position, @sizeOf(T), count);
        }

        fn first(self: *@This()) *T
        {
            return &self.ptr.?[0];
        }

        fn last(self: *@This()) *T
        {
            const len = self.length();
            assert(len != 0);
            return &self.ptr.?[len - 1];
        }
    };
}

pub const MessageObject = extern struct
{
    array: [5]u64,
};

pub const MessageQueue = extern struct
{
    messages: Array(MessageObject, .core),
    mouseMovedMessage: u64,
    windowResizedMessage: u64,
    eyedropResultMessage: u64,
    keyRepeatMessage: u64,
    pinged: bool,
    mutex: Mutex,
    notEmpty: Event,
};

pub const Handle = extern struct
{
    object: u64,
    flags: u32,
    type: KernelObjectType,
};

const HandleTableL2 = extern struct
{
    t: [256]Handle,

    const entry_count = 256;
};

const HandleTableL1 = extern struct
{
    t: [256]?*HandleTableL2,
    u: [256]u16,

    const entry_count = 256;
};

const ES_INVALID_HANDLE: u64 = 0x0;
const ES_CURRENT_THREAD: u64 = 0x10;
const ES_CURRENT_PROCESS: u64 = 0x11;

const HandleTable = extern struct
{
    l1r: HandleTableL1,
    lock: Mutex,
    process: ?*Process,
    destroyed: bool,
    handleCount: u32,

    fn resolve_handle(self: *@This(), out_handle: *Handle, in_handle: u64, type_mask: u32) ResolveHandleStatus
    {
        if (in_handle == ES_CURRENT_THREAD and type_mask & @enumToInt(KernelObjectType.thread) != 0)
        {
            out_handle.type = .thread;
            out_handle.object = @ptrToInt(GetCurrentThread());
            out_handle.flags = 0;

            return .no_close;
        }
        else if (in_handle == ES_CURRENT_PROCESS and type_mask & @enumToInt(KernelObjectType.process) != 0)
        {
            out_handle.type = .process;
            out_handle.object = @ptrToInt(GetCurrentThread().?.process);
            out_handle.flags = 0;

            return .no_close;
        }
        else if (in_handle == ES_INVALID_HANDLE and type_mask & @enumToInt(KernelObjectType.none) != 0)
        {
            out_handle.type = .none;
            out_handle.object = 0;
            out_handle.flags = 0;

            return .no_close;
        }

        _ = self;
        TODO();
    }

    fn destroy(self: *@This()) void
    {
        _ = self.lock.acquire();
        defer self.lock.release();

        if (self.destroyed) return;

        self.destroyed = true;

        const l1 = &self.l1r;

        var i: u64 = 0;
        while (i < HandleTableL1.entry_count) : (i += 1)
        {
            if (l1.u[i] == 0) continue;

            var k: u64 = 0;
            while (k < HandleTableL2.entry_count) : (k += 1)
            {
                const handle = &l1.t[i].?.t[k];
                if (handle.object != 0) CloseHandleToObject(handle.object, handle.type, handle.flags);
            }

            EsHeapFree(@ptrToInt(l1.t[i]), 0, &heapFixed);
        }
    }
};

pub fn AVLTree(comptime T: type) type
{
    return extern struct
    {
        root: ?*Item,
        modcheck: bool,
        long_keys: bool, // @ABICompatibility @Delete

        const Tree = @This();
        const KeyDefaultType = u64;
        const Key = extern union
        {
            short_key: u64,
            long: extern struct
            {
                key: u64,
                key_byte_count: u64,
            },
        };

        pub const SearchMode = enum
        {
            exact,
            smallest_above_or_equal,
            largest_below_or_equal,
        };

        pub const DuplicateKeyPolicy = enum
        {
            panic,
            allow,
            fail,
        };

        pub fn insert(self: *@This(), item: *Item, item_value: ?*T, key: KeyDefaultType, duplicate_key_policy: DuplicateKeyPolicy) bool
        {
            self.validate();
            
            if (item.tree != null)
            {
                KernelPanic("item already in a tree\n");
            }

            item.tree = self;

            item.key = zeroes(Key);
            item.key.short_key = key;
            item.children[0] = null;
            item.children[1] = null;
            item.value = item_value;
            item.height = 1;

            var link = &self.root;
            var parent: ?*Item = null;
            
            while (true)
            {
                if (link.*) |node|
                {
                    if (item.compare(node) == 0)
                    {
                        if (duplicate_key_policy == .panic) KernelPanic("avl duplicate panic")
                        else if (duplicate_key_policy == .fail) return false;
                    }

                    const child_index = @boolToInt(item.compare(node) > 0);
                    link = &node.children[child_index];
                    parent = node;
                }
                else
                {
                    link.* = item;
                    item.parent = parent;
                    break;
                }
            }

            var fake_root = zeroes(Item);
            self.root.?.parent = &fake_root;
            fake_root.tree = self;
            fake_root.children[0] = self.root;

            var item_it = item.parent.?;

            while (item_it != &fake_root)
            {
                const left_height = if (item_it.children[0]) |left| left.height else 0;
                const right_height = if (item_it.children[1]) |right| right.height else 0;
                const balance = left_height - right_height;
                item_it.height = 1 + if (balance > 0) left_height else right_height;
                var new_root: ?*Item = null;
                var old_parent = item_it.parent.?;

                if (balance > 1 and Item.compare_keys(key, item_it.children[0].?.key.short_key) <= 0)
                {
                    const right_rotation = item_it.rotate_right();
                    new_root = right_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                    old_parent.children[old_parent_child_index] = right_rotation;
                }
                else if (balance > 1 and Item.compare_keys(key, item_it.children[0].?.key.short_key) > 0 and item_it.children[0].?.children[1] != null)
                {
                    item_it.children[0] = item_it.children[0].?.rotate_left();
                    item_it.children[0].?.parent = item_it;
                    const right_rotation = item_it.rotate_right();
                    new_root = right_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                    old_parent.children[old_parent_child_index] = right_rotation;
                }
                else if (balance < -1 and Item.compare_keys(key, item_it.children[1].?.key.short_key) > 0)
                {
                    const left_rotation = item_it.rotate_left();
                    new_root = left_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                    old_parent.children[old_parent_child_index] = left_rotation;
                }
                else if (balance < -1 and Item.compare_keys(key, item_it.children[1].?.key.short_key) <= 0 and item_it.children[1].?.children[0] != null)
                {
                    item_it.children[1] = item_it.children[1].?.rotate_right();
                    item_it.children[1].?.parent = item_it;
                    const left_rotation = item_it.rotate_left();
                    new_root = left_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                    old_parent.children[old_parent_child_index] = left_rotation;
                }

                if (new_root) |new_root_unwrapped| new_root_unwrapped.parent = old_parent;
                item_it = old_parent;
            }

            self.root = fake_root.children[0];
            self.root.?.parent = null;

            self.validate();
            return true;
        }

        pub fn find(self: *@This(), key: KeyDefaultType, search_mode: SearchMode) ?*Item
        {
            if (self.modcheck) KernelPanic("concurrent access\n");
            self.validate();
            return self.find_recursive(self.root, key, search_mode);
        }

        pub fn find_recursive(self: *@This(), maybe_root: ?*Item, key: KeyDefaultType, search_mode: SearchMode) ?*Item
        {
            if (maybe_root) |root|
            {
                if (Item.compare_keys(root.key.short_key, key) == 0) return root;

                switch (search_mode)
                {
                    .exact => return self.find_recursive(root.children[0], key, search_mode),
                    .smallest_above_or_equal =>
                    {
                        if (Item.compare_keys(root.key.short_key, key) > 0)
                        {
                            if (self.find_recursive(root.children[0], key, search_mode)) |item| return item
                            else return root;
                        }
                        else return self.find_recursive(root.children[1], key, search_mode);
                    },
                    .largest_below_or_equal =>
                    {
                        if (Item.compare_keys(root.key.short_key, key) < 0)
                        {
                            if (self.find_recursive(root.children[1], key, search_mode)) |item| return item
                            else return root;
                        }
                        else return self.find_recursive(root.children[0], key, search_mode);
                    },
                }
            }
            else
            {
                return null;
            }
        }

        pub fn remove(self: *@This(), item: *Item) void
        {
            if (self.modcheck) KernelPanic("concurrent modification");
            self.modcheck = true;
            defer self.modcheck = false;

            self.validate();
            if (item.tree != self) KernelPanic("item not in tree");

            var fake_root = zeroes(Item);
            self.root.?.parent = &fake_root;
            fake_root.tree = self;
            fake_root.children[0] = self.root;

            if (item.children[0] != null and item.children[1] != null)
            {
                const smallest = 0;
                const a = self.find_recursive(item.children[1], smallest, .smallest_above_or_equal).?;
                const b = item;
                a.swap(b);
            }

            var link = &item.parent.?.children[@boolToInt(item.parent.?.children[1] == item)];
            link.* = if (item.children[0]) |left| left else item.children[1];

            item.tree = null;
            var item_it = blk:
            {
                if (link.*) |link_u|
                {
                    link_u.parent = item.parent;
                    break :blk link.*.?;
                }
                else break :blk item.parent.?;
            };

            while (item_it != &fake_root)
            {
                const left_height = if (item_it.children[0]) |left| left.height else 0;
                const right_height = if (item_it.children[1]) |right| right.height else 0;
                const balance = left_height - right_height;
                item_it.height = 1 + if (balance > 0) left_height else right_height;

                var new_root: ?*Item = null;
                var old_parent = item_it.parent.?;

                if (balance > 1)
                {
                    const left_balance = if (item_it.children[0]) |left| left.get_balance() else 0;
                    if (left_balance >= 0)
                    {
                        const right_rotation = item_it.rotate_right();
                        new_root = right_rotation;
                        const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                        old_parent.children[old_parent_child_index] = right_rotation;
                    }
                    else
                    {
                        item_it.children[0] = item_it.children[0].?.rotate_left();
                        item_it.children[0].?.parent = item_it;
                        const right_rotation = item_it.rotate_right();
                        new_root = right_rotation;
                        const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                        old_parent.children[old_parent_child_index] = right_rotation;
                    }
                }
                else if (balance < -1)
                {
                    const right_balance = if (item_it.children[1]) |left| left.get_balance() else 0;
                    if (right_balance <= 0)
                    {
                        const left_rotation = item_it.rotate_left();
                        new_root = left_rotation;
                        const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                        old_parent.children[old_parent_child_index] = left_rotation;
                    }
                    else
                    {
                        item_it.children[1] = item_it.children[1].?.rotate_right();
                        item_it.children[1].?.parent = item_it;
                        const left_rotation = item_it.rotate_left();
                        new_root = left_rotation;
                        const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                        old_parent.children[old_parent_child_index] = left_rotation;
                    }
                }

                if (new_root) |new_root_unwrapped| new_root_unwrapped.parent = old_parent;
                item_it = old_parent;
            }

            self.root = fake_root.children[0];
            if (self.root) |root|
            {
                if (root.parent != &fake_root) KernelPanic("incorrect root parent");
                root.parent = null;
            }

            self.validate();
        }

        fn validate(self: *@This()) void
        {
            if (self.root) |root|
            {
                _ = root.validate(self, null);
            }
            else
            {
                return;
            }
        }

        pub const Item = extern struct
        {
            value: ?*T,
            children: [2]?*Item,
            parent: ?*Item,
            tree: ?*Tree,
            key: Key,
            height: i32,

            fn rotate_left(self: *@This()) *Item
            {
                const x = self;
                const y = x.children[1].?;
                const maybe_t = y.children[0];
                y.children[0] = x;
                x.children[1] = maybe_t;
                x.parent = y;
                if (maybe_t) |t| t.parent = x;

                {
                    const left_height = if (x.children[0]) |left| left.height else 0;
                    const right_height = if (x.children[1]) |right| right.height else 0;
                    const balance = left_height - right_height;
                    x.height = 1 + if (balance > 0) left_height else right_height;
                }

                {
                    const left_height = if (y.children[0]) |left| left.height else 0;
                    const right_height = if (y.children[1]) |right| right.height else 0;
                    const balance = left_height - right_height;
                    y.height = 1 + if (balance > 0) left_height else right_height;
                }

                return y;
            }

            fn rotate_right(self: *@This()) *Item
            {
                const y = self;
                const x = y.children[0].?;
                const maybe_t = x.children[1];
                x.children[1] = y;
                y.children[0] = maybe_t;
                y.parent = x;
                if (maybe_t) |t| t.parent = y;

                {
                    const left_height = if (y.children[0]) |left| left.height else 0;
                    const right_height = if (y.children[1]) |right| right.height else 0;
                    const balance = left_height - right_height;
                    y.height = 1 + if (balance > 0) left_height else right_height;
                }

                {
                    const left_height = if (x.children[0]) |left| left.height else 0;
                    const right_height = if (x.children[1]) |right| right.height else 0;
                    const balance = left_height - right_height;
                    x.height = 1 + if (balance > 0) left_height else right_height;
                }

                return x;
            }

            fn swap(self: *@This(), other: *@This()) void
            {
                self.parent.?.children[@boolToInt(self.parent.?.children[1] == self)] = other;
                other.parent.?.children[@boolToInt(other.parent.?.children[1] == other)] = self;

                var temporal_self = self.*;
                var temporal_other = other.*;
                self.parent = temporal_other.parent;
                other.parent = temporal_self.parent;
                self.height = temporal_other.height;
                other.height = temporal_self.height;
                self.children[0] = temporal_other.children[0];
                self.children[1] = temporal_other.children[1];
                other.children[0] = temporal_self.children[0];
                other.children[1] = temporal_self.children[1];

                if (self.children[0]) |a_left| a_left.parent = self;
                if (self.children[1]) |a_right| a_right.parent = self;
                if (other.children[0]) |b_left| b_left.parent = other;
                if (other.children[1]) |b_right| b_right.parent = other;
            }

            fn get_balance(self: *@This()) i32
            {
                const left_height = if (self.children[0]) |left| left.height else 0;
                const right_height = if (self.children[1]) |right| right.height else 0;
                return left_height - right_height;
            }

            fn validate(self: *@This(), tree: *Tree, parent: ?*@This()) i32
            {
                if (self.parent != parent) KernelPanic("tree panic");
                if (self.tree != tree) KernelPanic("tree panic");

                const left_height = blk:
                {
                    if (self.children[0]) |left|
                    {
                        if (left.compare(self) > 0) KernelPanic("invalid tree");
                        break :blk left.validate(tree, self);
                    }
                    else
                    {
                        break :blk @as(i32, 0);
                    }
                };

                const right_height = blk:
                {
                    if (self.children[1]) |right|
                    {
                        if (right.compare(self) < 0) KernelPanic("invalid tree");
                        break :blk right.validate(tree, self);
                    }
                    else
                    {
                        break :blk @as(i32, 0);
                    }
                };

                const height = 1 + if (left_height > right_height) left_height else right_height;
                if (height != self.height) KernelPanic("invalid tree");

                return height;
            }

            fn compare(self: *@This(), other: *@This()) i32
            {
                return compare_keys(self.key.short_key, other.key.short_key);
            }

            fn compare_keys(key1: u64, key2: u64) i32
            {
                if (key1 < key2) return -1;
                if (key1 > key2) return 1;
                return 0;
            }
        };
    };
}

pub const SharedRegion = extern struct
{
    size: u64,
    handle_count: Volatile(u64),
    mutex: Mutex,
    address: u64,
};

pub const Region = extern struct
{
    descriptor: Region.Descriptor,
    flags: Region.Flags,
    data: extern struct
    {
        u: extern union
        {
            physical: extern struct
            {
                offset: u64,
            },
            shared: extern struct
            {
                region: ?*SharedRegion,
                offset: u64,
            },
            file: extern struct
            {
                node: ?*FSFile,
                offset: u64,
                zeroed_bytes: u64,
                file_handle_flags: u64,
            },
            normal: extern struct
            {
                commit: Range.Set,
                commit_page_count: u64,
                guard_before: ?*Region,
                guard_after: ?*Region,
            },
        },
        pin: WriterLock,
        map_mutex: Mutex,
    },
    u: extern union
    {
        item: extern struct
        {
            base: AVLTree(Region).Item,
            u: extern union
            {
                size: AVLTree(Region).Item,
                non_guard: LinkedList(Region).Item,
            },
        },
        core: extern struct
        {
            used: bool,
        },
    },

    pub const Descriptor = extern struct
    {
        base_address: u64,
        page_count: u64,
    };

    pub const Flags = Bitflag(enum(u32)
        {
            fixed = 0,
            not_cacheable = 1,
            no_commit_tracking = 2,
            read_only = 3,
            copy_on_write = 4,
            write_combining = 5,
            executable = 6,
            user = 7,
            physical = 8,
            normal = 9,
            shared = 10,
            guard = 11,
            cache = 12,
            file = 13,
        });

    pub fn zero_data_field(self: *@This()) void
    {
        std.mem.set(u8, @ptrCast([*]u8, &self.data)[0..@sizeOf(@TypeOf(self.data))], 0);
    }
};

pub const Range = extern struct
{
    from: u64,
    to: u64,

    pub const Set = extern struct
    {
        ranges: Array(Range, .core),
        contiguous: u64,

        pub fn find(self: *@This(), offset: u64, touching: bool) ?*Range
        {
            const length = self.ranges.length();
            if (length == 0) return null;

            var low: i64 = 0;
            var high = @intCast(i64, length) - 1;

            while (low <= high)
            {
                const i = @divTrunc(low + (high - low), 2);
                assert(i >= 0);
                const range = &self.ranges.ptr.?[@intCast(u64, i)];

                if (range.from <= offset and (offset < range.to or (touching and offset <= range.to))) return range
                else if (range.from <= offset) low = i + 1
                else high = i - 1;
            }

            return null;
        }

        fn contains(self: *@This(), offset: u64) bool
        {
            if (self.ranges.length() != 0) return self.find(offset, false) != null
            else return offset < self.contiguous;
        }

        fn validate(self: *@This()) void
        {
            var previous_to: u64 = 0;
            if (self.ranges.length() == 0) return;

            for (self.ranges.get_slice()) |range|
            {
                if (previous_to != 0 and range.from <= previous_to) KernelPanic("range in set is not placed after the prior range\n");
                if (range.from >= range.to) KernelPanic("range in set is invalid\n");

                previous_to = range.to;
            }
        }

        pub fn normalize(self: *@This()) bool
        {
            if (self.contiguous != 0)
            {
                const old_contiguous = self.contiguous;
                self.contiguous = 0;

                if (!RangeSetSet(self, 0, old_contiguous, null, true)) return false;
            }

            return true;
        }

        pub fn clear(self: *@This(), from: u64, to: u64, maybe_delta: ?*i64, modify: bool) bool
        {
            if (to <= from) KernelPanic("invalid range");

            if (self.ranges.length() == 0)
            {
                if (from < self.contiguous and self.contiguous != 0)
                {
                    if (to < self.contiguous)
                    {
                        if (modify)
                        {
                            if (!RangeSetNormalize(self)) return false;
                        }
                        else
                        {
                            if (maybe_delta) |delta| delta.* = @intCast(i64, from) - @intCast(i64, to);
                            return true;
                        }
                    }
                    else
                    {
                        if (maybe_delta) |delta| delta.* = @intCast(i64, from) - @intCast(i64, self.contiguous);
                        if (modify) self.contiguous = from;
                        return true;
                    }
                }
                else
                {
                    if (maybe_delta) |delta| delta.* = 0;
                    return true;
                }
            }

            if (self.ranges.length() == 0)
            {
                self.ranges.free();
                if (maybe_delta) |delta| delta.* = 0;
                return true;
            }

            if (to <= self.ranges.first().from or from >= self.ranges.last().to)
            {
                if (maybe_delta) |delta| delta.* = 0;
                return true;
            }

            if (from <= self.ranges.first().from and to >= self.ranges.last().to)
            {
                if (maybe_delta) |delta|
                {
                    var total: i64 = 0;

                    for (self.ranges.get_slice()) |range|
                    {
                        total += @intCast(i64, range.to) - @intCast(i64, range.from);
                    }

                    delta.* = -total;
                }

                if (modify) self.ranges.free();

                return true;
            }

            var overlap_start = self.ranges.length();
            var overlap_count: u64 = 0;

            for (self.ranges.get_slice()) |*range, i|
            {
                if (range.to > from and range.from < to)
                {
                    overlap_start = i;
                    overlap_count = 1;
                    break;
                }
            }

            for (self.ranges.get_slice()[overlap_start + 1..]) |*range|
            {
                if (range.to >= from and range.from < to) overlap_count += 1
                else break;
            }

            var _delta: i64 = 0;

            if (overlap_count == 1)
            {
                TODO();
            }
            else if (overlap_count > 1)
            {
                TODO();
            }

            if (maybe_delta) |delta| delta.* = _delta;

            self.validate();
            return true;
        }

        pub fn set(self: *@This(), from: u64, to: u64, maybe_delta: ?*i64, modify: bool) bool
        {
            if (to <= from) KernelPanic("invalid range");

            const initial_length = self.ranges.length();
            if (initial_length == 0)
            {
                if (maybe_delta) |delta|
                {
                    if (from >= self.contiguous) delta.* = @intCast(i64, to) - @intCast(i64, from)
                    else if (to >= self.contiguous) delta.* = @intCast(i64, to) - @intCast(i64, self.contiguous)
                    else delta.* = 0;
                }

                if (!modify) return true;

                if (from <= self.contiguous)
                {
                    if (to > self.contiguous) self.contiguous = to;
                    return true;
                }

                if (!self.normalize()) return false;
            }

            const new_range = Range
            {
                .from = if (self.find(from, true)) |left| left.from else from,
                .to = if (self.find(to, true)) |right| right.to else to,
            };

            var i: u64 = 0;
            while (i <= self.ranges.length()) : (i += 1)
            {
                if (i == self.ranges.length() or self.ranges.ptr.?[i].to > new_range.from)
                {
                    if (modify)
                    {
                        if (self.ranges.insert(new_range, i) == null) return false;
                        i += 1;
                    }

                    break;
                }
            }

            var delete_start = i;
            var delete_count: u64 = 0;
            var delete_total: u64 = 0;

            for (self.ranges.get_slice()[i..]) |*range|
            {
                const overlap = (range.from >= new_range.from and range.from <= new_range.to) or (range.to >= new_range.from and range.to <= new_range.to);

                if (overlap)
                {
                    delete_count += 1;
                    delete_total += range.to - range.from;
                }
                else break;
            }

            if (modify) self.ranges.delete_many(delete_start, delete_count);

            self.validate();

            if (maybe_delta) |delta| delta.* = @intCast(i64, new_range.to) - @intCast(i64, new_range.from) - @intCast(i64, delete_total);

            return true;
        }
    };
};

export fn RangeSetFind(range_set: *Range.Set, offset: u64, touching: bool) callconv(.C) ?*Range
{
    return range_set.find(offset, touching);
}

export fn RangeSetContains(range_set: *Range.Set, offset: u64) callconv(.C) bool
{
    return range_set.contains(offset);
}

export fn RangeSetNormalize(range_set: *Range.Set) callconv(.C) bool
{
    return range_set.normalize();
}

export fn RangeSetClear(range_set: *Range.Set, from: u64, to: u64, delta: ?*i64, modify: bool) callconv(.C) bool
{
    return range_set.clear(from, to, delta, modify);
}
//extern fn RangeSetSet(range_set: *Range.Set, from: u64, to: u64, delta: ?*i64, modify: bool) callconv(.C) bool;
export fn RangeSetSet(range_set: *Range.Set, from: u64, to: u64, delta: ?*i64, modify: bool) callconv(.C) bool
{
    return range_set.set(from, to, delta, modify);
}

export fn EsMemoryFill(from: u64, to: u64, byte: u8) callconv(.C) void
{
    assert(from != 0);
    assert(to != 0);

    var a = @intToPtr(*u8, from);
    var b = @intToPtr(*u8, to);
    while (a != b)
    {
        a.* = byte;
        a = @intToPtr(*u8, @ptrToInt(a) + 1);
    }
}

export fn EsMemorySumBytes(source: [*]u8, byte_count: u64) callconv(.C) u8
{
    if (byte_count == 0) return 0;

    var slice = source[0..byte_count];
    var total: u64 = 0;
    for (slice) |byte|
    {
        total += byte;
    }

    return @truncate(u8, total);
}

export fn EsMemoryCompare(a: u64, b: u64, byte_count: u64) callconv(.C) i32
{
    if (byte_count == 0) return 0;

    assert(a != 0);
    assert(b != 0);

    const a_slice = @intToPtr([*]u8, a)[0..byte_count];
    const b_slice = @intToPtr([*]u8, b)[0..byte_count];

    for (a_slice) |a_byte, i|
    {
        const b_byte = b_slice[i];

        if (a_byte < b_byte) return -1
        else if (a_byte > b_byte) return 1;
    }

    return 0;
}

export fn EsMemoryZero(dst: u64, byte_count: u64) callconv(.C) void
{
    if (byte_count == 0) return;

    var slice = @intToPtr([*]u8, dst)[0..byte_count];
    std.mem.set(u8, slice, 0);
}

export fn EsMemoryCopy(dst: u64, src: u64, byte_count: u64) callconv(.C) void
{
    if (byte_count == 0) return;

    const dst_slice = @intToPtr([*]u8, dst)[0..byte_count];
    const src_slice = @intToPtr([*]const u8, src)[0..byte_count];
    std.mem.copy(u8, dst_slice, src_slice);
}

export fn EsCRTmemcpy(dst: u64, src: u64, byte_count: u64) callconv(.C) u64
{
    EsMemoryCopy(dst, src, byte_count);
    return dst;
}

export fn EsCRTstrlen(str: [*:0]const u8) callconv(.C) u64
{
    var i: u64 = 0;
    while (str[i] != 0)
    {
        i += 1;
    }

    return i;
}

export fn EsCRTstrcpy(dst: [*:0]u8, src: [*:0]const u8) callconv(.C) [*:0]u8
{
    const string_length = EsCRTstrlen(src);
    return @intToPtr([*:0]u8, EsCRTmemcpy(@ptrToInt(dst), @ptrToInt(src), string_length + 1));
}

export fn EsMemoryCopyReverse(destination: u64, source: u64, byte_count: u64) callconv(.C) void
{
    if (byte_count == 0) return;

    assert(destination != 0);
    assert(source != 0);

    var dst = &(@intToPtr([*]u8, destination)[0..byte_count][byte_count - 1]);
    var src = &(@intToPtr([*]u8, source)[0..byte_count][byte_count - 1]);

    var bytes: u64 = byte_count;
    while (bytes >= 1)
    {
        dst.* = src.*;
        src = @intToPtr(*u8, @ptrToInt(src) - 1);
        dst = @intToPtr(*u8, @ptrToInt(dst) - 1);
        bytes -= 1;
    }
}

const EsGeneric = u64;

export fn EsMemoryMove(start_address: u64, end_address: u64, amount: i64, zero_empty_space: bool) callconv(.C) void
{
    if (end_address < start_address) return;

    if (amount > 0)
    {
        const amount_u = @intCast(u64, amount);
        EsMemoryCopyReverse(start_address + amount_u, start_address, end_address - start_address);

        if (zero_empty_space) EsMemoryZero(start_address, amount_u);
    }
    else if (amount < 0)
    {
        const amount_u = @intCast(u64, std.math.absInt(amount) catch unreachable);
        EsMemoryCopy(start_address - amount_u, start_address, end_address - start_address);
        if (zero_empty_space) EsMemoryZero(end_address - amount_u, amount_u);
    }
}

export fn EsAssertionFailure(file: [*:0]const u8, line: i32) callconv(.C) void
{
    _ = file; _ = line;
    KernelPanic("Assertion failure called");
}

const ArrayHeader = extern struct
{
    length: u64,
    allocated: u64,

};

export fn ArrayHeaderGet(array: ?*u64) callconv(.C) *ArrayHeader
{
    return @intToPtr(*ArrayHeader, @ptrToInt(array) - @sizeOf(ArrayHeader));
}

export fn ArrayHeaderGetLength(array: ?*u64) callconv(.C) u64
{
    if (array) |arr| return ArrayHeaderGet(arr).length
    else return 0;
}

export fn _ArrayMaybeInitialise(array: *?*u64, item_size: u64, heap: *Heap) callconv(.C) bool
{
    const new_length = 4;
    if (@intToPtr(?*ArrayHeader, EsHeapAllocate(@sizeOf(ArrayHeader) + item_size * new_length, true, heap))) |header|
    {
        header.length = 0;
        header.allocated = new_length;
        array.* = @intToPtr(?*u64, @ptrToInt(header) + @sizeOf(ArrayHeader));
        return true;
    }
    else
    {
        return false;
    }
}

export fn _ArrayEnsureAllocated(array: *?*u64, minimum_allocated: u64, item_size: u64, additional_header_bytes: u8, heap: *Heap) callconv(.C) bool
{
    if (!_ArrayMaybeInitialise(array, item_size, heap)) return false;

    const old_header = ArrayHeaderGet(array.*);

    if (old_header.allocated >= minimum_allocated) return true;

    _ = additional_header_bytes;

    TODO();

    //if (@intToPtr(?*ArrayHeader, EsHeapReallocate(@ptrToInt(old_header) - additional_header_bytes, @sizeOf(ArrayHeader) + additional_header_bytes + item_size * minimum_allocated, false, heap))) |new_header|
    //{
        //new_header.allocated = minimum_allocated;
        //array.* = @intToPtr(?*u64, @ptrToInt(new_header) + @sizeOf(ArrayHeader) + additional_header_bytes);
        //return true;
    //}
    //else
    //{
        //return false;
    //}
}

export fn _ArraySetLength(array: *?*u64, new_length: u64, item_size: u64, additional_header_bytes: u8, heap: *Heap) callconv(.C) bool
{
    if (!_ArrayMaybeInitialise(array, item_size, heap)) return false;

    var header = ArrayHeaderGet(array.*);

    if (header.allocated >= new_length)
    {
        header.length = new_length;
        return true;
    }

    if (!_ArrayEnsureAllocated(array, if (header.allocated * 2 > new_length) header.allocated * 2 else new_length + 16, item_size, additional_header_bytes, heap)) return false;

    header = ArrayHeaderGet(array.*);
    header.length = new_length;
    return true;
}

fn memory_move_backwards(comptime T: type, addr: T) std.meta.Int(.signed, @bitSizeOf(T))
{
    return - @intCast(std.meta.Int(.signed, @bitSizeOf(T)), addr);
}

export fn _ArrayDelete(array: ?*u64, position: u64, item_size: u64, count: u64) callconv(.C) void
{
    if (count == 0) return;

    const old_array_length = ArrayHeaderGetLength(array);
    if (position >= old_array_length) KernelPanic("position out of bounds");
    if (count > old_array_length - position) KernelPanic("count out of bounds");
    ArrayHeaderGet(array).length = old_array_length - count;
    const array_address = @ptrToInt(array);
    // @TODO @WARNING @Dangerous @ERROR @PANIC
    EsMemoryMove(array_address + item_size * (position + count), array_address + item_size * old_array_length, memory_move_backwards(u64, item_size) * @intCast(i64, count), false);
}

export fn _ArrayDeleteSwap(array: ?*u64, position: u64, item_size: u64) callconv(.C) void
{
    const old_array_length = ArrayHeaderGetLength(array);
    if (position >= old_array_length) KernelPanic("position out of bounds");
    ArrayHeaderGet(array).length = old_array_length - 1;
    const array_address = @ptrToInt(array);
    EsMemoryCopy(array_address + item_size * position, array_address * ArrayHeaderGetLength(array), item_size);
}

export fn _ArrayInsert(array: *?*u64, item: u64, item_size: u64, maybe_position: i64, additional_header_bytes: u8, heap: *Heap) callconv(.C) u64
{
    const old_array_length = ArrayHeaderGetLength(array.*);
    const position: u64 = if (maybe_position == -1) old_array_length else @intCast(u64, maybe_position);
    if (maybe_position < 0 or position > old_array_length) KernelPanic("position out of bounds");
    if (!_ArraySetLength(array, old_array_length + 1, item_size, additional_header_bytes, heap)) return 0;
    const array_address = @ptrToInt(array.*);
    EsMemoryMove(array_address + item_size * position, array_address + item_size * old_array_length, @intCast(i64, item_size), false);
    if (item != 0) EsMemoryCopy(array_address + item_size * position, item, item_size)
    else EsMemoryZero(array_address + item_size * position, item_size);
    return array_address + item_size * position;
}

export fn _ArrayInsertMany(array: *?*u64, item_size: u64, maybe_position: i64, insert_count: u64, heap: *Heap) callconv(.C) u64
{
    const old_array_length = ArrayHeaderGetLength(array.*);
    const position: u64 = if (maybe_position == -1) old_array_length else @intCast(u64, maybe_position);
    if (maybe_position < 0 or position > old_array_length) KernelPanic("position out of bounds");
    if (!_ArraySetLength(array, old_array_length + insert_count, item_size, 0, heap)) return 0;
    const array_address = @ptrToInt(array.*);
    EsMemoryMove(array_address + item_size * position, array_address + item_size * old_array_length, @intCast(i64, item_size * insert_count), false);
    return array_address + item_size * position;
}

export fn _ArrayFree(array: *?*u64, item_size: u64, heap: *Heap) callconv(.C) void
{
    if (array.* == null) return;

    EsHeapFree(@ptrToInt(ArrayHeaderGet(array.*)), @sizeOf(ArrayHeader) + item_size * ArrayHeaderGet(array.*).allocated, heap);
    array.* = null;
}

export fn EsCStringLength(maybe_string: ?[*:0]const u8) callconv(.C) u64
{
    if (maybe_string) |string|
    {
        var size: u64 = 0;

        while (string[size] != 0)
        {
            size += 1;
        }

        return size;
    }
    else return 0;
}

export fn EsStringCompareRaw(s1: [*:0]const u8, length1: i64, s2: [*:0]const u8, length2: i64) callconv(.C) i32
{
    var len1: u64 = if (length1 == -1) EsCStringLength(s1) else @intCast(u64, length1);
    var len2: u64 = if (length2 == -1) EsCStringLength(s2) else @intCast(u64, length2);

    var i: u64 = 0;
    while (len1 != 0 or len2 != 0) : (i += 1)
    {
        if (len1 == 0) return -1;
        if (len2 == 0) return 1;

        const c1 = s1[i];
        const c2 = s2[i];

        if (c1 != c2) return @intCast(i32, c1) - @intCast(i32, c2);
        len1 -= 1;
        len2 -= 1;
    }

    return 0;
}

export fn MMUnpinRegion(space: *AddressSpace, region: *Region) callconv(.C) void
{
    _ = space.reserve_mutex.acquire();
    region.data.pin.return_lock(WriterLock.shared);
    space.reserve_mutex.release();
}

//extern fn drivers_init() callconv(.C) void;

export var shutdownEvent: Event = undefined;

export fn MMInitialise() callconv(.C) void
{
    {
        mmCoreRegions = @intToPtr([*]Region, core_memory_region_start);
        mmCoreRegions[0].u.core.used = false;
        mmCoreRegionCount = 1;
        MMArchInitialise();

        const region = @intToPtr(?*Region, EsHeapAllocate(@sizeOf(Region), true, &heapCore)) orelse unreachable;
        region.descriptor.base_address = kernel_address_space_start;
        region.descriptor.page_count = kernel_address_space_size / page_size;
        _ = _kernelMMSpace.free_region_base.insert(&region.u.item.base, region, region.descriptor.base_address, .panic);
        _ = _kernelMMSpace.free_region_size.insert(&region.u.item.u.size, region, region.descriptor.page_count, .allow);
    }

    {
        _ = _kernelMMSpace.reserve_mutex.acquire();
        pmm.manipulation_region = @intToPtr(?*Region, (MMReserve(&_kernelMMSpace, Physical.memory_manipulation_region_page_count * page_size, Region.Flags.empty(), 0) orelse unreachable).descriptor.base_address) orelse unreachable;
        _kernelMMSpace.reserve_mutex.release();

        const pageframe_database_count = (physicalMemoryHighest + (page_size << 3)) >> page_bit_count;
        pmm.pageframes = @intToPtr(?[*]PageFrame, MMStandardAllocate(&_kernelMMSpace, pageframe_database_count * @sizeOf(PageFrame), Region.Flags.from_flag(.fixed), 0, true)) orelse unreachable;
        _ = BitsetInitialise(&pmm.free_or_zeroed_page_bitset, pageframe_database_count, true);
        pmm.pageframeDatabaseCount = pageframe_database_count;

        MMPhysicalInsertFreePagesStart();
        const commit_limit = MMArchPopulatePageFrameDatabase();
        MMPhysicalInsertFreePagesEnd();
        pmm.pageframeDatabaseInitialised = true;

        pmm.commit_limit = @intCast(i64, commit_limit);
        pmm.commit_fixed_limit = pmm.commit_limit;
        // @Log
    }

    {
    }

    {
        pmm.zero_page_event.auto_reset.write_volatile(true);
        _ = MMCommit(Physical.memory_manipulation_region_page_count * page_size, true);
        SpawnMemoryThreads();
    }

    {
        mmGlobalDataRegion = MMSharedCreateRegion(@sizeOf(GlobalData), false, 0) orelse unreachable;
        globalData = @intToPtr(?*GlobalData, MMMapShared(&_kernelMMSpace, mmGlobalDataRegion, 0, @sizeOf(GlobalData), Region.Flags.from_flag(.fixed), 0)) orelse unreachable;
        _ = MMFaultRange(@ptrToInt(globalData), @sizeOf(GlobalData), HandlePageFaultFlags.from_flag(.for_supervisor));
    }
}

extern fn SpawnMemoryThreads() callconv(.C) void;

extern fn CreateMainThread() callconv(.C) void;
export fn KThreadCreate(entry: u64, argument: u64) callconv(.C) bool
{
    return ThreadSpawn(entry, argument, Thread.Flags.empty(), null, 0) != null;
}


export fn ThreadSpawn(start_address: u64, argument1: u64, flags: Thread.Flags, maybe_process: ?*Process, argument2: u64) callconv(.C) ?*Thread
{
    if (start_address == 0 and !flags.contains(.idle)) KernelPanic("Start address is 0");
    const userland = flags.contains(.userland);
    const parent_thread = GetCurrentThread();
    const process = if (maybe_process) |process_r| process_r else kernelProcess;
    if (userland and process == kernelProcess) KernelPanic("cannot add userland thread to kernel process");

    _ = process.threads_mutex.acquire();
    defer process.threads_mutex.release();

    if (process.prevent_new_threads) return null;

    const thread = @intToPtr(?*Thread, PoolAdd(&scheduler.thread_pool, @sizeOf(Thread))) orelse return null;
    const kernel_stack_size = 0x5000;
    const user_stack_reserve: u64 = if (userland) 0x400000 else kernel_stack_size;
    const user_stack_commit: u64 = if (userland) 0x10000 else 0;
    var user_stack: u64 = 0;
    var kernel_stack: u64 = 0;

    var failed = false;
    if (!flags.contains(.idle))
    {
        kernel_stack = MMStandardAllocate(&_kernelMMSpace, kernel_stack_size, Region.Flags.from_flag(.fixed), 0, true);
        failed = (kernel_stack == 0);
        if (!failed)
        {
            if (userland)
            {
                user_stack = MMStandardAllocate(process.address_space, user_stack_reserve, Region.Flags.empty(), 0, false);
                // @TODO: this migh be buggy, since we are using an invalid stack to get a region?
                const region = MMFindAndPinRegion(process.address_space, user_stack, user_stack_reserve).?;
                _ = process.address_space.reserve_mutex.acquire();
                failed = !MMCommitRange(process.address_space, region, (user_stack_reserve - user_stack_commit) / page_size, user_stack_commit / page_size);
                process.address_space.reserve_mutex.release();
                MMUnpinRegion(process.address_space, region);
                failed = failed or user_stack == 0;
            }
            else
            {
                user_stack = kernel_stack;
            }
        }
    }

    if (!failed)
    {
        thread.paused.write_volatile((parent_thread != null and process == parent_thread.?.process and parent_thread.?.paused.read_volatile()) or flags.contains(.paused));
        thread.handle_count.write_volatile(2);
        thread.is_kernel_thread = !userland;
        thread.priority = if (flags.contains(.low_priority)) @enumToInt(Thread.Priority.low) else @enumToInt(Thread.Priority.normal);
        thread.kernel_stack_base = kernel_stack;
        thread.user_stack_base = if (userland) user_stack else 0;
        thread.user_stack_reserve = user_stack_reserve;
        thread.user_stack_commit.write_volatile(user_stack_commit);
        thread.terminatable_state.write_volatile(if (userland) .terminatable else .in_syscall);
        thread.type = 
            if (flags.contains(.async_task)) Thread.Type.async_task
            else if (flags.contains(.idle)) Thread.Type.idle
            else Thread.Type.normal;
        thread.id = @atomicRmw(u64, &scheduler.next_thread_id, .Add, 1, .SeqCst);
        thread.process = process;
        thread.item.value = thread;
        thread.all_item.value = thread;
        thread.process_item.value = thread;

        if (thread.type != .idle)
        {
            thread.interrupt_context = ArchInitialiseThread(kernel_stack, kernel_stack_size, thread, start_address, argument1, argument2, userland, user_stack, user_stack_reserve);
        }
        else
        {
            thread.state.write_volatile(.active);
            thread.executing.write_volatile(true);
        }

        process.threads.insert_at_end(&thread.process_item);

        _ = scheduler.all_threads_mutex.acquire();
        scheduler.all_threads.insert_at_start(&thread.all_item);
        scheduler.all_threads_mutex.release();

        // object process
        // @TODO
        _ = OpenHandleToObject(@ptrToInt(process), KernelObjectType.process, 0);

        if (thread.type == .normal)
        {
            scheduler.dispatch_spinlock.acquire();
            SchedulerAddActiveThread(thread, true);
            scheduler.dispatch_spinlock.release();
        }
        else
        {
            // do nothing
        }
        return thread;
    }
    else
    {
        // fail
        if (user_stack != 0) _ = MMFree(process.address_space, user_stack, 0, false);
        if (kernel_stack != 0) _ = MMFree(&_kernelMMSpace, kernel_stack, 0, false);
        PoolRemove(&scheduler.thread_pool, @ptrToInt(thread));
        return null;
    }
}

export fn MMFindRegion(space: *AddressSpace, address: u64) ?*Region
{
    space.reserve_mutex.assert_locked();

    if (space == &_coreMMSpace)
    {
        for (mmCoreRegions[0..mmCoreRegionCount]) |*region|
        {
            const matched = region.u.core.used and region.descriptor.base_address <= address and region.descriptor.base_address + region.descriptor.page_count * page_size > address;
            if (matched)
            {
                return region;
            }
        }
        return null;
    }
    else
    {
        const item = space.used_regions.find(address, .largest_below_or_equal) orelse return null;
        const region = item.value.?;
        if (region.descriptor.base_address > address) KernelPanic("broken used regions tree");
        if (region.descriptor.base_address + region.descriptor.page_count * page_size <= address) return null;
        return region;
    }
}

pub const Bitset = extern struct
{
    single_usage: [*]u32,
    group_usage: [*]u16, 
    single_usage_count: u64,
    group_usage_count: u64,

    pub fn init(self: *@This(), count: u64, map_all: bool) void
    {
        self.single_usage_count = (count + 31) & ~@as(u64, 31);
        self.group_usage_count = self.single_usage_count / group_size + 1;
        self.single_usage = @intToPtr([*]u32, MMStandardAllocate(&_kernelMMSpace, (self.single_usage_count >> 3) + (self.group_usage_count * 2), if (map_all) Region.Flags.from_flag(.fixed) else Region.Flags.empty(), 0, true));
        self.group_usage = @intToPtr([*]u16, @ptrToInt(self.single_usage) + ((self.single_usage_count >> 4) * @sizeOf(u16)));
    }

    pub fn put(self: *@This(), index: u64) void
    {
        self.single_usage[index >> 5] |= @as(u32, 1) << @truncate(u5, index);
        self.group_usage[index / group_size] += 1;
    }

    pub fn take(self: *@This(), index: u64) void
    {
        const group = index / group_size;
        self.group_usage[group] -= 1;
        self.single_usage[index >> 5] &= ~(@as(u32, 1) << @truncate(u5, index));
    }

    pub fn get(self: *@This(), count: u64, alignment: u64, asked_below: u64) u64
    {
        var return_value: u64 = std.math.maxInt(u64);

        const below = blk:
        {
            if (asked_below != 0)
            {
                if (asked_below < count) return return_value;
                break :blk asked_below - count;
            }
            else break :blk asked_below;
        };

        if (count == 1 and alignment == 1)
        {
            for (self.group_usage[0..self.group_usage_count]) |*group_usage, group_i|
            {
                if (group_usage.* != 0)
                {
                    var single_i: u64 = 0;
                    while (single_i < group_size) : (single_i += 1)
                    {
                        const index = group_i * group_size + single_i;
                        if (below != 0 and index >= below) return return_value;
                        const index_mask = (@as(u32, 1) << @intCast(u5, index));
                        if (self.single_usage[index >> 5] & index_mask != 0)
                        {
                            self.single_usage[index >> 5] &= ~index_mask;
                            self.group_usage[group_i] -= 1;
                            return index;
                        }
                    }
                }
            }
        }
        else if (count == 16 and alignment == 16)
        {
            TODO();
        }
        else if (count == 32 and alignment == 32)
        {
            TODO();
        }
        else
        {
            var found: u64 = 0;
            var start: u64 = 0;

            for (self.group_usage[0..self.group_usage_count]) |*group_usage, group_i|
            {
                if (group_usage.* == 0)
                {
                    found = 0;
                    continue;
                }

                var single_i: u64 = 0;
                while (single_i < group_size) : (single_i += 1)
                {
                    const index = group_i * group_size + single_i;
                    const index_mask = (@as(u32, 1) << @truncate(u5, index));

                    if (self.single_usage[index >> 5] & index_mask  != 0)
                    {
                        if (found == 0)
                        {
                            if (index >= below and below != 0) return return_value;
                            if (index % alignment != 0) continue;

                            start = index;
                        }

                        found += 1;
                    }
                    else
                    {
                        found = 0;
                    }

                    if (found == count)
                    {
                        return_value = start;

                        var i: u64 = 0;
                        while (i < count) : (i += 1)
                        {
                            const index_b = start + i;
                            self.single_usage[index_b >> 5] &= ~((@as(u32, 1) << @truncate(u5, index_b)));
                        }

                        return return_value;
                    }
                }
            }
        }

        return return_value;
    }

    const group_size = 0x1000;
};

export fn BitsetInitialise(self: *Bitset, count: u64, map_all: bool) callconv(.C) void
{
    self.init(count, map_all);
}

export fn BitsetPut(self: *Bitset, index: u64) callconv(.C) void
{
    self.put(index);
}

export fn BitsetTake(self: *Bitset, index: u64) callconv(.C) void
{
    self.take(index);
}

//extern fn BitsetGet(self: *Bitset, count: u64, alignment: u64, below: u64) callconv(.C) u64;
export fn BitsetGet(self: *Bitset, count: u64, alignment: u64, below: u64) callconv(.C) u64
{
    return self.get(count, alignment, below);
}

pub const PageFrame = extern struct
{
    state: Volatile(PageFrame.State),
    flags: Volatile(u8),
    cache_reference: ?*volatile u64,
    u: extern union
    {
        list: extern struct
        {
            next: Volatile(u64),
            previous: ?*volatile u64,
        },

        active: extern struct
        {
            references: Volatile(u64),
        },
    },

    pub const State = enum(i8)
    {
        unusable,
        bad,
        zeroed,
        free,
        standby,
        active,
    };
};

const ObjectCache = extern struct
{
    lock: Spinlock,
    items: SimpleList,
    count: u64,
    trim: fn (cache: *ObjectCache) callconv(.C) bool,
    trim_lock: WriterLock,
    item: LinkedList(ObjectCache).Item,
    average_object_bytes: u64,

    const trim_group_count = 1024;
};

pub const Physical = extern struct
{
    pub const Allocator = extern struct
    {
        pageframes: [*]PageFrame,
        pageframeDatabaseInitialised: bool,
        pageframeDatabaseCount: u64,

        first_free_page: u64,
        first_zeroed_page: u64,
        first_standby_page: u64,
        last_standby_page: u64,

        free_or_zeroed_page_bitset: Bitset,

        zeroed_page_count: u64,
        free_page_count: u64,
        standby_page_count: u64,
        active_page_count: u64,

        commit_fixed: i64,
        commit_pageable: i64,
        commit_fixed_limit: i64,
        commit_limit: i64,

        commit_mutex: Mutex,
        pageframe_mutex: Mutex,

        manipulation_lock: Mutex,
        manipulation_processor_lock: Spinlock,
        manipulation_region: ?*Region,

        zero_page_thread: *Thread,
        zero_page_event: Event,

        object_cache_list: LinkedList(ObjectCache),
        object_cache_list_mutex: Mutex,

        available_critical_event: Event,
        available_low_event: Event,
        available_not_critical_event: Event,

        approximate_total_object_cache_byte_count: u64,
        trim_object_cache_event: Event,

        next_process_to_balance: ?*Process,
        next_region_to_balance: ?*Region,
        balance_resume_position: u64,

        //pub fn allocate_with_flags(self: *@This(), flags: Physical.Flags) u64
        //{
            //return self.allocate_extended(flags, 1, 1, 0);
        //}

        //pub fn allocate_extended(self: *@This(), flags: Physical.Flags, count: u64, alignment: u64, below: u64) u64
        //{
            //const mutex_already_acquired = flags.contains(.lock_acquired);
            //if (!mutex_already_acquired) _ = self.pageframe_mutex.acquire() else self.pageframe_mutex.assert_locked();
            //defer if (!mutex_already_acquired) self.pageframe_mutex.release();

            //const commit_now = blk:
            //{
                //if (flags.contains(.commit_now))
                //{
                    //const result = count * page_size;
                    //if (!self.commit(result, true)) return 0;
                    //break :blk result;
                //}
                //else
                //{
                    //break :blk 0;
                //}
            //};
            //_ = commit_now;

            //const simple = count == 1 and alignment == 1 and below == 0;

            //if (self.pageframes.len == 0)
            //{
                //if (!simple)
                //{
                    //KernelPanic("non-simple allocation before page frame initialization\n");
                //}

                //const page = kernel.arch.early_allocate_page();

                //if (flags.contains(.zeroed))
                //{
                    //// @TODO: hack
                    //_ = kernel.arch.map_page(&kernel.core.address_space, page, @ptrToInt(&early_zero_buffer), MapPageFlags.from_flags(.{.overwrite, .no_new_tables, .frame_lock_acquired}));
                    //std.mem.set(u8, early_zero_buffer[0..], 0);
                //}

                //return page;
            //}
            //else if (!simple)
            //{
                //TODO();
            //}
            //else
            //{
                //var not_zeroed = false;
                //const page = blk:
                //{
                    //var p: u64 = 0;
                    //p = self.first_zeroed_page;
                    //if (p == 0) { p = self.first_free_page; not_zeroed = true; }
                    //if (p == 0) { p = self.last_standby_page; not_zeroed = true; }
                    //break :blk p;
                //};

                //if (page != 0)
                //{
                    //const frame = &self.pageframes[page];

                    //switch (frame.state.read_volatile())
                    //{
                        //.active =>
                        //{
                            //KernelPanic("corrupt pageframes");
                        //},
                        //.standby =>
                        //{
                            //if (frame.cache_reference.?.* != ((page << page_bit_count) | shared_entry_present))
                            //{
                                //KernelPanic("corrupt shared reference back pointer in frame");
                            //}

                            //frame.cache_reference.?.* = 0;
                        //},
                        //else =>
                        //{
                            //self.free_or_zeroed_page_bitset.take(page);
                        //}
                    //}

                    //self.activate_pages(page, 1);

                    //const address = page << page_bit_count;
                    //if (not_zeroed and flags.contains(.zeroed))
                    //{
                        //TODO();
                    //}

                    //return address;
                //}
            //}

            //// fail
            //if (!flags.contains(.can_fail))
            //{
                //KernelPanic("out of memory");
            //}

            //self.decommit(commit_now, true);
            //return 0;
        //}

        //pub fn commit(self: *@This(), byte_count: u64, fixed: bool) bool
        //{
            //if (byte_count & (page_size - 1) != 0) KernelPanic("expected multiple of page size\n");

            //const needed_page_count = byte_count / page_size;

            //_ = self.commit_mutex.acquire();
            //defer self.commit_mutex.release();

            //// If not true: we haven't started tracking commit counts yet
            //if (self.commit_limit != 0)
            //{
                //if (fixed)
                //{
                    //if (needed_page_count > self.commit_fixed_limit - self.commit_fixed)
                    //{
                        //return false;
                    //}

                    //if (self.get_available_page_count() - needed_page_count < critical_available_page_threshold and !get_current_thread().?.is_page_generator)
                    //{
                        //return false;
                    //}

                    //self.commit_fixed += needed_page_count;
                //}
                //else
                //{
                    //if (needed_page_count > self.get_remaining_commit() - if (get_current_thread().?.is_page_generator) @as(u64, 0) else @as(u64, critical_remaining_commit_threshold))
                    //{
                        //return false;
                    //}

                    //self.commit_pageable += needed_page_count;
                //}

                //if (self.should_trim_object_cache())
                //{
                    //TODO();
                //}
            //}
        
            //return true;
        //}

        //pub fn decommit(self: *@This(), byte_count: u64, fixed: bool) void
        //{
            //_ = self;
            //_ = byte_count;
            //_ = fixed;
            //TODO();
        //}
        //pub fn activate_pages(self: *@This(), pages: u64, page_count: u64) void
        //{
            //self.pageframe_mutex.assert_locked();

            //for (self.pageframes[pages..pages + page_count]) |*frame, frame_i|
            //{
                //switch (frame.state.read_volatile())
                //{
                    //.free =>
                    //{
                        //self.free_page_count -= 1;
                    //},
                    //.zeroed =>
                    //{
                        //self.zeroed_page_count -= 1;
                    //},
                    //.standby =>
                    //{
                        //self.standby_page_count -= 1;

                        //if (self.last_standby_page == pages + frame_i)
                        //{
                            //if (frame.u.list.previous == &self.first_standby_page)
                            //{
                                //self.last_standby_page = 0;
                            //}
                            //else
                            //{
                                //self.last_standby_page = (@ptrToInt(frame.u.list.previous) - @ptrToInt(self.pageframes.ptr)) / @sizeOf(PageFrame);
                            //}
                        //}
                    //},
                    //else => unreachable,
                //}

                //frame.u.list.previous.?.* = frame.u.list.next.read_volatile();
                //if (frame.u.list.next.read_volatile() != 0)
                //{
                    //self.pageframes[frame.u.list.next.read_volatile()].u.list.previous = frame.u.list.previous;
                //}

                //std.mem.set(u8, @ptrCast([*]u8, frame)[0..@sizeOf(@TypeOf(frame))], 0);
                //frame.state.write_volatile(.active);
            //}

            //self.active_page_count += page_count;
            //self.update_available_page_count(false);
        //}

        //pub fn insert_free_pages_next(self: *@This(), page: u64) void
        //{
            //const frame = &self.pageframes[page];
            //frame.state.write_volatile(.free);

            //frame.u.list.next.write_volatile(self.first_free_page);
            //frame.u.list.previous = &self.first_free_page;
            //if (self.first_free_page != 0)
            //{
                //self.pageframes[self.first_free_page].u.list.previous = &frame.u.list.next.value;
            //}
            //self.first_free_page = page;

            //self.free_or_zeroed_page_bitset.put(page);
            //self.free_page_count += 1;
        //}

        //pub fn free(self: *@This(), page: u64) void
        //{
            //return self.free_extended(page, false, 1);
        //}

        //pub fn free_extended(self: *@This(), page: u64, mutex_already_acquired: bool, count: u64) void
        //{
            //_ = self;
            //_ = page;
            //_ = mutex_already_acquired;
            //_ = count;
            //TODO();
        //}

        fn get_available_page_count(self: @This()) callconv(.Inline) u64
        {
            return self.zeroed_page_count + self.free_page_count + self.standby_page_count;
        }

        fn get_remaining_commit(self: @This()) callconv(.Inline) i64
        {
            return self.commit_limit - self.commit_pageable - self.commit_fixed;
        }

        fn should_trim_object_cache(self: @This()) callconv(.Inline) bool
        {
            return self.approximate_total_object_cache_byte_count / page_size > self.get_object_cache_maximum_cache_page_count();
        }

        fn get_object_cache_maximum_cache_page_count(self: @This()) callconv(.Inline) i64
        {
            return @divTrunc(self.commit_limit - self.get_non_cache_memory_page_count(), 2);
        }

        fn get_non_cache_memory_page_count(self: @This()) callconv(.Inline) i64
        {
            return @divTrunc(self.commit_fixed - self.commit_pageable - @intCast(i64, self.approximate_total_object_cache_byte_count), page_size);
        }

        fn start_insert_free_pages(self: *@This()) void
        {
            _ = self;
        }

        fn end_insert_free_pages(self: *@This()) void
        {
            if (self.free_page_count > zero_page_threshold)
            {
                _ = self.zero_page_event.set(true);
            }

            self.update_available_page_count(true);
        }

        fn update_available_page_count(self: *@This(), increase: bool) void
        {
            if (self.get_available_page_count() >= critical_available_page_threshold)
            {
                _ = self.available_not_critical_event.set(true);
                self.available_not_critical_event.reset();
            }
            else
            {
                self.available_not_critical_event.reset();
                _ = self.available_critical_event.set(true);

                if (!increase)
                {
                    // log
                }
            }

            if (self.get_available_page_count() >= low_available_page_threshold) self.available_low_event.reset()
            else _ = self.available_low_event.set(true);
        }

        const zero_page_threshold = 16;
        const low_available_page_threshold = 16777216 / page_size;
        const critical_available_page_threshold = 1048576 / page_size;
        const critical_remaining_commit_threshold = 1048576 / page_size;
        const page_count_to_find_balance = 4194304 / page_size;
    };

    pub const MemoryRegion = Region.Descriptor;

    pub const Flags = Bitflag(enum(u32)
        {
            can_fail = 0,
            commit_now = 1,
            zeroed = 2,
            lock_acquired = 3,
        });

    pub const memory_manipulation_region_page_count = 0x10;
};

export var pmm: Physical.Allocator = undefined;

export fn MMDecommit(byte_count: u64, fixed: bool) callconv(.C) void
{
    if (byte_count & (page_size - 1) != 0) KernelPanic("byte count not page-aligned");

    const needed_page_count = @intCast(i64, byte_count / page_size);
    _ = pmm.commit_mutex.acquire();
    defer pmm.commit_mutex.release();

    if (fixed)
    {
        if (pmm.commit_fixed < needed_page_count) KernelPanic("decommited too many pages");
        pmm.commit_fixed -= needed_page_count;
    }
    else
    {
        if (pmm.commit_pageable < needed_page_count) KernelPanic("decommited too many pages");
        pmm.commit_pageable -= needed_page_count;
    }
}

export fn MMDecommitRange(space: *AddressSpace, region: *Region, page_offset: u64, page_count: u64) callconv(.C) bool
{
    space.reserve_mutex.assert_locked();

    if (region.flags.contains(.no_commit_tracking)) KernelPanic("Region does not support commit tracking");
    if (page_offset >= region.descriptor.page_count or page_count > region.descriptor.page_count - page_offset) KernelPanic("invalid region offset and page count");
    if (!region.flags.contains(.normal)) KernelPanic("Cannot decommit from non-normal region");

    var delta: i64 = 0;

    if (!RangeSetClear(&region.data.u.normal.commit, page_offset, page_offset + page_count, &delta, true)) return false;

    if (delta > 0) KernelPanic("invalid delta calculation");
    const delta_u = @intCast(u64, -delta);

    if (region.data.u.normal.commit_page_count < delta_u) KernelPanic("invalid delta calculation");

    MMDecommit(delta_u * page_size, region.flags.contains(.fixed));
    space.commit_count -= delta_u;
    region.data.u.normal.commit_page_count -= delta_u;
    MMArchUnmapPages(space, region.descriptor.base_address + page_offset * page_size, page_count, UnmapPagesFlags.from_flag(.free), 0, null);
    
    return true;
}


fn round_down(comptime T: type, value: T, divisor: T) T
{
    return value / divisor * divisor;
}

fn round_up(comptime T: type, value: T, divisor: T) T
{
    return (value + (divisor - 1)) / divisor * divisor;
}

pub const HandlePageFaultFlags = Bitflag(enum(u32)
    {
        write = 0,
        lock_acquired = 1,
        for_supervisor = 2,
    }
);

pub const MapPageFlags = Bitflag(enum(u32)
    {
        not_cacheable = 0,
        user = 1,
        overwrite = 2,
        commit_tables_now = 3,
        read_only = 4,
        copied = 5,
        no_new_tables = 6,
        frame_lock_acquired = 7,
        write_combining = 8,
        ignore_if_mapped = 9,
    }
);

pub const UnmapPagesFlags = Bitflag(enum(u32)
    {
        free = 0,
        free_copied = 1,
        balance_file = 2,
    }
);

fn MMPhysicalAllocateWithFlags(flags: Physical.Flags) u64
{
    return MMPhysicalAllocate(flags, 1, 1, 0);
}

export fn MMHandlePageFault(space: *AddressSpace, asked_address: u64, flags: HandlePageFaultFlags) callconv(.C) bool
{
    const address = asked_address & ~@as(u64, page_size - 1);
    const lock_acquired = flags.contains(.lock_acquired);

    var region = blk:
    {
        if (lock_acquired)
        {
            space.reserve_mutex.assert_locked();
            const result = MMFindRegion(space, asked_address) orelse return false;
            if (!result.data.pin.take_extended(WriterLock.shared, true)) return false;
            break :blk result;
        }
        else
        {
            if (pmm.get_available_page_count() < Physical.Allocator.critical_available_page_threshold and GetCurrentThread() != null and !GetCurrentThread().?.is_page_generator)
            {
                _ = pmm.available_not_critical_event.wait();
            }
            _ = space.reserve_mutex.acquire();
            defer space.reserve_mutex.release();

            const result = MMFindRegion(space, asked_address) orelse return false;
            if (!result.data.pin.take_extended(WriterLock.shared, true)) return false;
            break :blk result;
        }
    };

    defer region.data.pin.return_lock(WriterLock.shared);
    _ = region.data.map_mutex.acquire();
    defer region.data.map_mutex.release();

    if (MMArchTranslateAddress(address, flags.contains(.write)) != 0) return true;

    var copy_on_write = false;
    var mark_modified = false;

    if (flags.contains(.write))
    {
        if (region.flags.contains(.copy_on_write)) copy_on_write = true
        else if (region.flags.contains(.read_only)) return false
        else mark_modified = true;
    }

    const offset_into_region = address - region.descriptor.base_address;
    _ = offset_into_region;
    var physical_allocation_flags = Physical.Flags.empty();
    var zero_page = true;

    if (space.user)
    {
         physical_allocation_flags = physical_allocation_flags.or_flag(.zeroed);
         zero_page = false;
    }

    var map_page_flags = MapPageFlags.empty();
    if (space.user) map_page_flags = map_page_flags.or_flag(.user);
    if (region.flags.contains(.not_cacheable)) map_page_flags = map_page_flags.or_flag(.not_cacheable);
    if (region.flags.contains(.write_combining)) map_page_flags = map_page_flags.or_flag(.write_combining);
    if (!mark_modified and !region.flags.contains(.fixed) and region.flags.contains(.file)) map_page_flags = map_page_flags.or_flag(.read_only);

    if (region.flags.contains(.physical))
    {
        _ = MMArchMapPage(space, region.data.u.physical.offset + address - region.descriptor.base_address, address, map_page_flags);
        return true;
    }
    else if (region.flags.contains(.shared))
    {
        const shared_region = region.data.u.shared.region.?;
        if (shared_region.handle_count.read_volatile() == 0) KernelPanic("Shared region has no handles");
        _ = shared_region.mutex.acquire();

        const offset = address - region.descriptor.base_address + region.data.u.shared.offset;

        if (offset >= shared_region.size)
        {
            shared_region.mutex.release();
            return false;
        }

        const entry = @intToPtr(*u64, shared_region.address + (offset / page_size * @sizeOf(u64)));

        // @TODO SHARED_ENTRY_PRESENT
        if (entry.* & 1 != 0) zero_page = false
        else entry.* = MMPhysicalAllocateWithFlags(physical_allocation_flags) | 1;

        _ = MMArchMapPage(space, entry.* & ~@as(u64, page_size - 1), address, map_page_flags);
        if (zero_page) EsMemoryZero(address, page_size);
        shared_region.mutex.release();
        return true;
    }
    else if (region.flags.contains(.file))
    {
        TODO();
    }
    else if (region.flags.contains(.normal))
    {
        if (!region.flags.contains(.no_commit_tracking))
        {
            if (!RangeSetContains(&region.data.u.normal.commit, offset_into_region >> page_bit_count))
            {
                return false;
            }
        }

        _ = MMArchMapPage(space, MMPhysicalAllocateWithFlags(physical_allocation_flags), address, map_page_flags);
        if (zero_page) EsMemoryZero(address, page_size);
        return true;
    }
    else if (region.flags.contains(.guard))
    {
        TODO();
    }
    else
    {
        return false;
    }
}

export fn MMUpdateAvailablePageCount(increase: bool) callconv(.C) void
{
    if (pmm.get_available_page_count() >= Physical.Allocator.critical_available_page_threshold)
    {
        _ = pmm.available_not_critical_event.set(true);
        pmm.available_critical_event.reset();
    }
    else
    {
        pmm.available_not_critical_event.reset();
        _ = pmm.available_critical_event.set(true);

        if (!increase)
        {
            // log error
        }
    }

    if (pmm.get_available_page_count() >= Physical.Allocator.low_available_page_threshold)
    {
        pmm.available_low_event.reset();
    }
    else
    {
        _ = pmm.available_low_event.set(true);
    }
}

export fn MMPhysicalActivatePages(pages: u64, count: u64) callconv(.C) void
{
    pmm.pageframe_mutex.assert_locked();

    for (pmm.pageframes[pages..pages+count]) |*frame, i|
    {
        switch (frame.state.read_volatile())
        {
            .free => pmm.free_page_count -= 1,
            .zeroed => pmm.zeroed_page_count -= 1,
            .standby =>
            {
                pmm.standby_page_count -= 1;

                if (pmm.last_standby_page == pages + i)
                {
                    if (frame.u.list.previous == &pmm.first_standby_page)
                    {
                        pmm.last_standby_page = 0;
                    }
                    else
                    {
                        pmm.last_standby_page = (@ptrToInt(frame.u.list.previous) - @ptrToInt(pmm.pageframes)) / @sizeOf(PageFrame);
                    }
                }
            },
            else => KernelPanic("Corrupt page frame database"),
        }

        frame.u.list.previous.?.* = frame.u.list.next.read_volatile();

        if (frame.u.list.next.read_volatile() != 0)
        {
            pmm.pageframes[frame.u.list.next.read_volatile()].u.list.previous = frame.u.list.previous;
        }
        EsMemoryZero(@ptrToInt(frame), @sizeOf(PageFrame));
        frame.state.write_volatile(.active);
    }

    pmm.active_page_count += count;
    MMUpdateAvailablePageCount(false);
}

export fn ThreadRemove(thread: *Thread) callconv(.C) void
{
    PoolRemove(&scheduler.thread_pool, @ptrToInt(thread));
}

export fn MMCommit(byte_count: u64, fixed: bool) callconv(.C) bool
{
    if (byte_count & (page_size - 1) != 0) KernelPanic("Bytes should be page-aligned");

    const needed_page_count = @intCast(i64, byte_count / page_size);

    _  = pmm.commit_mutex.acquire();
    defer pmm.commit_mutex.release();

    // Else we haven't started tracking commit counts yet
    if (pmm.commit_limit != 0)
    {
        if (fixed)
        {
            if (needed_page_count > pmm.commit_fixed_limit - pmm.commit_fixed) return false;
            if (@intCast(i64, pmm.get_available_page_count()) - needed_page_count < Physical.Allocator.critical_available_page_threshold and !GetCurrentThread().?.is_page_generator) return false;
            pmm.commit_fixed += needed_page_count;
        }
        else
        {
            if (needed_page_count > pmm.get_remaining_commit() - if (GetCurrentThread().?.is_page_generator) @as(i64, 0) else @as(i64, Physical.Allocator.critical_remaining_commit_threshold)) return false;
            pmm.commit_pageable += needed_page_count;
        }

        if (pmm.should_trim_object_cache()) _ = pmm.trim_object_cache_event.set(true);
    }

    return true;
}

export fn MMSharedResizeRegion(region: *SharedRegion, asked_size: u64) callconv(.C) bool
{
    _ = region.mutex.acquire();
    defer region.mutex.release();

    const size = (asked_size + page_size - 1) & ~@as(u64, page_size - 1);
    const page_count = size / page_size;
    const old_page_count = region.size / page_size;
    const old_address = region.address;

    const new_address = EsHeapAllocate(page_count * @sizeOf(u64), true, &heapCore);
    if (new_address == 0 and page_count != 0) return false;

    if (old_page_count > page_count)
    {
        MMDecommit(page_size * (old_page_count - page_count), true);
    }
    else if (page_count > old_page_count)
    {
        if (!MMCommit(page_size * (page_count - old_page_count), true))
        {
            EsHeapFree(new_address, page_count * @sizeOf(u64), &heapCore);
            return false;
        }
    }

    region.size = size;
    region.address = new_address;

    if (old_address == 0) return true;

    if (old_page_count > page_count)
    {
        var i = page_count;
        while (i < old_page_count) : (i += 1)
        {
            // @TODO
            const addresses = @intToPtr([*]u64, old_address);
            const address = addresses[i];
            // MM_SHARED_ENTRY_PRESENT
            if (address & 1 != 0) _ = MMPhysicalFree(address, false, 1);
        }
    }

    const copy = if (old_page_count > page_count) page_count else old_page_count;
    EsMemoryCopy(region.address, old_address, @sizeOf(u64) * copy);
    EsHeapFree(old_address, old_page_count * @sizeOf(u64), &heapCore);
    return true;
}

export fn MMSharedDestroyRegion(region: *SharedRegion) callconv(.C) void
{
    _ = MMSharedResizeRegion(region, 0);
    EsHeapFree(@ptrToInt(region), 0, &heapCore);
}

export fn MMSharedCreateRegion(size: u64, fixed: bool, below: u64) callconv(.C) ?*SharedRegion
{
    if (size == 0) return null;

    const region = @intToPtr(?*SharedRegion, EsHeapAllocate(@sizeOf(SharedRegion), true, &heapCore)) orelse return null;

    region.handle_count.write_volatile(1);

    if (!MMSharedResizeRegion(region, size))
    {
        EsHeapFree(@ptrToInt(region), 0, &heapCore);
        return null;
    }

    if (fixed)
    {
        var i: u64 = 0;
        while (i < region.size >> page_bit_count) : (i += 1)
        {
            @intToPtr([*]u64, region.address)[i] = MMPhysicalAllocate(Physical.Flags.from_flag(.zeroed), 1, 1, below) | 1; // MM_SHARED_ENTRY_PRESENT
        }
    }

    return region;
}

export fn MMUnreserve(space: *AddressSpace, region: *Region, unmap_pages: bool, guard_region: bool) callconv(.C) void
{
    space.reserve_mutex.assert_locked();

    if (pmm.next_region_to_balance == region)
    {
        pmm.next_region_to_balance = if (region.u.item.u.non_guard.next) |next| next.value else null;
        pmm.balance_resume_position = 0;
    }

    if (region.flags.contains(.normal))
    {
        if (region.data.u.normal.guard_before) |before| MMUnreserve(space, before, false, true);
        if (region.data.u.normal.guard_after) |after| MMUnreserve(space, after, false, true);
    }
    else if (region.flags.contains(.guard) and !guard_region)
    {
        // log error
        return;
    }

    if (region.u.item.u.non_guard.list != null and !guard_region)
    {
        region.u.item.u.non_guard.remove_from_list();
    }

    if (unmap_pages)
    {
        _ = MMArchUnmapPages(space, region.descriptor.base_address, region.descriptor.page_count, UnmapPagesFlags.empty(), 0, null);
    }

    space.reserve_count += region.descriptor.page_count;

    if (space == &_coreMMSpace)
    {
        region.u.core.used = false;

        var remove1: i64 = -1;
        var remove2: i64 = -1;

        for (mmCoreRegions[0..mmCoreRegionCount]) |*r, i|
        {
            if (!(remove1 != -1 or remove2 != 1)) break;
            if (r.u.core.used) continue;
            if (r == region) continue;

            if (r.descriptor.base_address == region.descriptor.base_address + (region.descriptor.page_count << page_bit_count))
            {
                region.descriptor.page_count += r.descriptor.page_count;
                remove1 = @intCast(i64, i);
            }
            else if (region.descriptor.base_address == r.descriptor.base_address + (r.descriptor.page_count << page_bit_count))
            {
                region.descriptor.page_count += r.descriptor.page_count;
                region.descriptor.base_address = r.descriptor.base_address;
                remove2 = @intCast(i64, i);
            }
        }

        if (remove1 != -1)
        {
            mmCoreRegionCount -= 1;
            mmCoreRegions[@intCast(u64, remove1)] = mmCoreRegions[mmCoreRegionCount];
            if (remove2 == @intCast(i64, mmCoreRegionCount)) remove2 = remove1;
        }

        if (remove2 != -1)
        {
            mmCoreRegionCount -= 1;
            mmCoreRegions[@intCast(u64, remove2)] = mmCoreRegions[mmCoreRegionCount];
        }
    }
    else
    {
        space.used_regions.remove(&region.u.item.base);
        const address = region.descriptor.base_address;

        if (space.free_region_base.find(address, .largest_below_or_equal)) |before|
        {
            if (before.value.?.descriptor.base_address + before.value.?.descriptor.page_count * page_size == region.descriptor.base_address)
            {
                region.descriptor.base_address = before.value.?.descriptor.base_address;
                region.descriptor.page_count += before.value.?.descriptor.page_count;
                space.free_region_base.remove(before);
                space.free_region_size.remove(&before.value.?.u.item.u.size);
                EsHeapFree(@ptrToInt(before.value), @sizeOf(Region), &heapCore);
            }
        }

        if (space.free_region_base.find(address, .smallest_above_or_equal)) |after|
        {
            if (region.descriptor.base_address + region.descriptor.page_count * page_size == after.value.?.descriptor.base_address)
            {
                region.descriptor.page_count += after.value.?.descriptor.page_count;
                space.free_region_base.remove(after);
                space.free_region_size.remove(&after.value.?.u.item.u.size);
                EsHeapFree(@ptrToInt(after.value), @sizeOf(Region), &heapCore);
            }
        }

        _ = space.free_region_base.insert(&region.u.item.base, region, region.descriptor.base_address, .panic);
        _ = space.free_region_size.insert(&region.u.item.u.size, region, region.descriptor.page_count, .allow);
    }
}

export fn MMFree(space: *AddressSpace, address: u64, expected_size: u64, user_only: bool) callconv(.C) bool
{
    {
        _ = space.reserve_mutex.acquire();
        defer space.reserve_mutex.release();

        const region = MMFindRegion(space, address) orelse return false;

        if (user_only and !region.flags.contains(.user)) return false;
        if (!region.data.pin.take_extended(WriterLock.exclusive, true)) return false;
        if (region.descriptor.base_address != address and !region.flags.contains(.physical)) return false;
        if (expected_size != 0 and (expected_size + page_size - 1) / page_size != region.descriptor.page_count) return false;

        var unmap_pages = true;

        if (region.flags.contains(.normal))
        {
            if (!MMDecommitRange(space, region, 0, region.descriptor.page_count)) KernelPanic("Could not decommit the entere region");
            if (region.data.u.normal.commit_page_count != 0) KernelPanic("After decommiting range covering the entere region, some pages were still commited");
            region.data.u.normal.commit.ranges.free();
            unmap_pages = false;
        }
        else if (region.flags.contains(.shared))
        {
            CloseHandleToObject(@ptrToInt(region.data.u.shared.region), .shared_memory, 0);
        }
        else if (region.flags.contains(.file))
        {
            TODO();
        }
        else if (region.flags.contains(.physical)) { } // do nothing
        else if (region.flags.contains(.guard)) return false
        else KernelPanic("unsupported region type");
        return true;
    }
}

const KernelObjectType = enum(u32)
{
    could_not_resolve = 0,
    none = 0x80000000,
    process = 0x1,
    thread = 0x2,
    window = 0x4,
    shared_memory = 0x8,
    node = 0x10,
    event = 0x20,
    constant_buffer = 0x40,
    posix_fd = 0x100,
    pipe = 0x200,
    embedded_window = 0x400,
    connection = 0x4000,
    device = 0x8000,
};

export fn ThreadSetTemporaryAddressSpace(space: ?*AddressSpace) callconv(.C) void
{
    scheduler.dispatch_spinlock.acquire();
    const thread = GetCurrentThread().?;
    const old_space = if (thread.temporary_address_space) |tas| tas else &_kernelMMSpace;
    thread.temporary_address_space = space;
    const new_space = if (space) |sp| sp else &_kernelMMSpace;
    MMSpaceOpenReference(new_space);
    ProcessorSetAddressSpace(&new_space.arch);
    scheduler.dispatch_spinlock.release();
    MMSpaceCloseReference(@ptrCast(*AddressSpace, old_space));
}

extern fn ProcessorSetAddressSpace(address_space: *ArchAddressSpace) callconv(.C) void;
fn ThreadKill(task: *AsyncTask) void
{
    const thread = @fieldParentPtr(Thread, "kill_async_task", task);
    ThreadSetTemporaryAddressSpace(thread.process.?.address_space);

    _ = scheduler.all_threads_mutex.acquire();
    scheduler.all_threads.remove(&thread.all_item);
    scheduler.all_threads_mutex.release();

    _ = thread.process.?.threads_mutex.acquire();
    thread.process.?.threads.remove(&thread.process_item);
    const last_thread = thread.process.?.threads.count == 0;
    thread.process.?.threads_mutex.release();

    if (last_thread) ProcessKill(thread.process.?);

    _ = MMFree(&_kernelMMSpace,thread.kernel_stack_base, 0, false);
    if (thread.user_stack_base != 0) _ = MMFree(thread.process.?.address_space, thread.user_stack_base, 0, false);
    _ = thread.killed_event.set(false);
    CloseHandleToObject(@ptrToInt(thread.process), KernelObjectType.process, 0);
    CloseHandleToObject(@ptrToInt(thread), KernelObjectType.thread, 0);
}

fn KRegisterAsyncTask(task: *AsyncTask, callback: AsyncTask.Callback) void
{
    scheduler.async_task_spinlock.acquire();

    if (task.callback == 0)
    {
        task.callback = @ptrToInt(callback);
        GetLocalStorage().?.async_task_list.insert(&task.item, false);
    }

    scheduler.async_task_spinlock.release();
}

export fn thread_exit(thread: *Thread) callconv(.C) void
{
    scheduler.dispatch_spinlock.acquire();

    var yield = false;
    const was_terminating = thread.terminating.read_volatile();
    if (!was_terminating)
    {
        thread.terminating.write_volatile(true);
        thread.paused.write_volatile(false);
    }

    if (thread == GetCurrentThread())
    {
        thread.terminatable_state.write_volatile(.terminatable);
        yield = true;
    }
    else if (!was_terminating and !thread.executing.read_volatile())
    {
        switch (thread.terminatable_state.read_volatile())
        {
            .terminatable =>
            {
                if (thread.state.read_volatile() != .active) KernelPanic("terminatable thread non-active");

                thread.item.remove_from_list();
                KRegisterAsyncTask(&thread.kill_async_task, ThreadKill);
                yield = true;
            },
            .user_block_request =>
            {
                const thread_state = thread.state.read_volatile();
                if (thread_state == .waiting_mutex or thread_state == .waiting_event) SchedulerUnblockThread(thread, null);
            },
            else => {}
        }
    }

    scheduler.dispatch_spinlock.release();
    if (yield) ProcessorFakeTimerInterrupt();
}

export fn MMSpaceOpenReference(space: *AddressSpace) callconv(.C) void
{
    if (space != &_kernelMMSpace)
    {
        if (space.reference_count.read_volatile() < 1) KernelPanic("space has invalid reference count");
        if (space.reference_count.read_volatile() >= max_processors + 1) KernelPanic("space has too many references");
        _ = space.reference_count.atomic_fetch_add(1);
    }
}

export fn MMSpaceDestroy(space: *AddressSpace) callconv(.C) void
{
    var maybe_item = space.used_regions_non_guard.first;
    while (maybe_item) |item|
    {
        const region = item.value.?;
        maybe_item = item.next;
        _ = MMFree(space, region.descriptor.base_address, 0, false);
    }

    while (space.free_region_base.find(0, .smallest_above_or_equal)) |item|
    {
        space.free_region_base.remove(&item.value.?.u.item.base);
        space.free_region_size.remove(&item.value.?.u.item.u.size);
        EsHeapFree(@ptrToInt(item.value), @sizeOf(Region), &heapCore);
    }

    MMArchFreeVAS(space);
}

export fn KThreadTerminate() callconv(.C) void
{
    thread_exit(GetCurrentThread().?);
}

export fn ProcessKill(process: *Process) callconv(.C) void
{
    if (process.handle_count.read_volatile() == 0) KernelPanic("process is on the all process list but there are no handles in it");

    _ = scheduler.active_process_count.atomic_fetch_add(1);

    _ = scheduler.all_processes_mutex.acquire();
    scheduler.all_processes.remove(&process.all_item);
    
    if (pmm.next_process_to_balance == process)
    {
        pmm.next_process_to_balance = if (process.all_item.next) |next| next.value else null;
        pmm.next_region_to_balance = null;
        pmm.balance_resume_position = 0;
    }

    scheduler.all_processes_mutex.release();

    scheduler.dispatch_spinlock.acquire();
    process.all_threads_terminated = true;
    scheduler.dispatch_spinlock.release();
    _ = process.killed_event.set(true);
    process.handle_table.destroy();
    MMSpaceDestroy(process.address_space);
    if (!scheduler.shutdown.read_volatile())
    {
        // @TODO @Desktop send message to the desktop
    }
}

export fn MMFindAndPinRegion(space: *AddressSpace, address: u64, size: u64) callconv(.C) ?*Region
{
    {
        var overflow_result: u64 = 0;
        if (@addWithOverflow(u64, address, size, &overflow_result))
        {
            return null;
        }
    }

    _ = space.reserve_mutex.acquire();
    defer space.reserve_mutex.release();

    const region = MMFindRegion(space, address) orelse return null;

    if (region.descriptor.base_address > address) return null;
    if (region.descriptor.base_address + region.descriptor.page_count * page_size < address + size) return null;
    if (!region.data.pin.take_extended(WriterLock.shared, true)) return null;

    return region;
}

export fn MMCommitRange(space: *AddressSpace, region: *Region, page_offset: u64, page_count: u64) callconv(.C) bool
{
    space.reserve_mutex.assert_locked();

    if (region.flags.contains(.no_commit_tracking)) KernelPanic("region does not support commit tracking");
    if (page_offset >= region.descriptor.page_count or page_count > region.descriptor.page_count - page_offset) KernelPanic("invalid region offset and page count");
    if (!region.flags.contains(.normal)) KernelPanic("cannot commit into non-normal region");

    var delta: i64 = 0;
    _ = RangeSetSet(&region.data.u.normal.commit, page_offset, page_offset + page_count, &delta, false);

    if (delta < 0) KernelPanic("Invalid delta calculation");
    if (delta == 0) return true;

    const delta_u = @intCast(u64, delta);

    if (!MMCommit(delta_u * page_size, region.flags.contains(.fixed))) return false;
    region.data.u.normal.commit_page_count += delta_u;
    space.commit_count += delta_u;

    if (region.data.u.normal.commit_page_count > region.descriptor.page_count) KernelPanic("invalid delta calculation increases region commit past page count");

    if (!RangeSetSet(&region.data.u.normal.commit, page_offset, page_offset + page_count, null, true))
    {
        MMDecommit(delta_u * page_size, region.flags.contains(.fixed));
        region.data.u.normal.commit_page_count -= delta_u;
        space.commit_count -= delta_u;
        return false;
    }

    if (region.flags.contains(.fixed))
    {
        var i = page_offset;
        while (i < page_offset + page_count) : (i += 1)
        {
            if (!MMHandlePageFault(space, region.descriptor.base_address + i * page_size, HandlePageFaultFlags.from_flag(.lock_acquired))) KernelPanic("unable to fix pages");
        }
    }

    return true;
}

export fn MMReserve(space: *AddressSpace, byte_count: u64, flags: Region.Flags, forced_address: u64) callconv(.C) ?*Region
{
    const needed_page_count = ((byte_count + page_size - 1) & ~@as(u64, page_size - 1)) / page_size;

    if (needed_page_count == 0) return null;

    space.reserve_mutex.assert_locked();

    const region = blk:
    {
        if (space == &_coreMMSpace)
        {
            if (mmCoreRegionCount == core_memory_region_count) return null;

            if (forced_address != 0) KernelPanic("Using a forced address in core address space\n");

            {
                const new_region_count = mmCoreRegionCount + 1;
                const needed_commit_page_count = new_region_count * @sizeOf(Region) / page_size;

                while (mmCoreRegionArrayCommit < needed_commit_page_count) : (mmCoreRegionArrayCommit += 1)
                {
                    if (!MMCommit(page_size, true)) return null;
                }
            }

            for (mmCoreRegions[0..mmCoreRegionCount]) |*region|
            {
                if (!region.u.core.used and region.descriptor.page_count >= needed_page_count)
                {
                    if (region.descriptor.page_count > needed_page_count)
                    {
                        const last = mmCoreRegionCount;
                        mmCoreRegionCount += 1;
                        var split = &mmCoreRegions[last];
                        split.* = region.*;
                        split.descriptor.base_address += needed_page_count * page_size;
                        split.descriptor.page_count -= needed_page_count;
                    }

                    region.u.core.used = true;
                    region.descriptor.page_count = needed_page_count;
                    region.flags = flags;
                    region.data = zeroes(@TypeOf(region.data));
                    assert(region.data.u.normal.commit.ranges.length() == 0);

                    break :blk region;
                }
            }

            return null;
        }
        else if (forced_address != 0)
        {
            if (space.used_regions.find(forced_address, .exact)) |_| return null;

            if (space.used_regions.find(forced_address, .smallest_above_or_equal)) |item|
            {
                if (item.value.?.descriptor.base_address < forced_address + needed_page_count * page_size) return null;
            }

            if (space.used_regions.find(forced_address + needed_page_count * page_size - 1, .largest_below_or_equal)) |item|
            {
                if (item.value.?.descriptor.base_address + item.value.?.descriptor.page_count * page_size > forced_address) return null;
            }

            if (space.free_region_base.find(forced_address, .exact)) |_| return null;

            if (space.free_region_base.find(forced_address, .smallest_above_or_equal)) |item|
            {
                if (item.value.?.descriptor.base_address < forced_address + needed_page_count * page_size) return null;
            }

            if (space.free_region_base.find(forced_address + needed_page_count * page_size - 1, .largest_below_or_equal)) |item|
            {
                if (item.value.?.descriptor.base_address + item.value.?.descriptor.page_count * page_size > forced_address) return null;
            }

            const region = @intToPtr(?*Region, EsHeapAllocate(@sizeOf(Region), true, &heapCore)) orelse unreachable;
            region.descriptor.base_address = forced_address;
            region.descriptor.page_count = needed_page_count;
            region.flags = flags;

            _ = space.used_regions.insert(&region.u.item.base, region, region.descriptor.base_address, .panic);

            region.data = zeroes(@TypeOf(region.data));
            break :blk region;
        }
        else
        {
            // @TODO: implement guard pages?

            if (space.free_region_size.find(needed_page_count, .smallest_above_or_equal)) |item|
            {
                const region = item.value.?;
                space.free_region_base.remove(&region.u.item.base);
                space.free_region_size.remove(&region.u.item.u.size);

                if (region.descriptor.page_count > needed_page_count)
                {
                    const split = @intToPtr(?*Region, EsHeapAllocate(@sizeOf(Region), true, &heapCore)) orelse unreachable;
                    split.* = region.*;

                    split.descriptor.base_address += needed_page_count * page_size;
                    split.descriptor.page_count -= needed_page_count;

                    _ = space.free_region_base.insert(&split.u.item.base, split, split.descriptor.base_address, .panic);
                    _ = space.free_region_size.insert(&split.u.item.u.size, split, split.descriptor.page_count, .allow);
                }

                region.data = zeroes(@TypeOf(region.data));
                region.descriptor.page_count = needed_page_count;
                region.flags = flags;

                // @TODO: if guard pages needed
                _ = space.used_regions.insert(&region.u.item.base, region, region.descriptor.base_address, .panic);
                break :blk region;
            }
            else
            {
                return null;
            }
        }
    };

    if (!MMArchCommitPageTables(space, region))
    {
        MMUnreserve(space, region, false, false);
        return null;
    }

    if (space != &_coreMMSpace)
    {
        region.u.item.u.non_guard = zeroes(@TypeOf(region.u.item.u.non_guard));
        region.u.item.u.non_guard.value = region;
        space.used_regions_non_guard.insert_at_end(&region.u.item.u.non_guard);
    }

    space.reserve_count += needed_page_count;

    return region;
}

export fn MMStandardAllocate(space: *AddressSpace, byte_count: u64, flags: Region.Flags, base_address: u64, commit_all: bool) callconv(.C) u64
{
    _ = space.reserve_mutex.acquire();
    defer space.reserve_mutex.release();

    const region = MMReserve(space, byte_count, flags.or_flag(.normal), base_address) orelse return 0;

    if (commit_all)
    {
        if (!MMCommitRange(space, region, 0, region.descriptor.page_count))
        {
            MMUnreserve(space, region, false, false);
            return 0;
        }
    }

    return region.descriptor.base_address;
}

export fn MMPhysicalInsertFreePagesStart() callconv(.C) void
{
}

export fn MMPhysicalInsertFreePagesEnd() callconv(.C) void
{
    if (pmm.free_page_count > Physical.Allocator.zero_page_threshold) _ = pmm.zero_page_event.set(true);
    MMUpdateAvailablePageCount(true);
}

export fn PMZero(asked_page_ptr: [*]u64, asked_page_count: u64, contiguous: bool) callconv(.C) void
{
    _ = pmm.manipulation_lock.acquire();

    var page_count = asked_page_count;
    var pages = asked_page_ptr;

    while (true)
    {
        const do_count = if (page_count > Physical.memory_manipulation_region_page_count) Physical.memory_manipulation_region_page_count else page_count;
        page_count -= do_count;

        const region = @ptrToInt(pmm.manipulation_region);
        var i: u64 = 0;
        while (i < do_count) : (i += 1)
        {
            _ = MMArchMapPage(&_coreMMSpace, if (contiguous) pages[0] + (i << page_bit_count) else pages[i], region + page_size * i, MapPageFlags.from_flags(.{ .overwrite, .no_new_tables }));
        }

        pmm.manipulation_processor_lock.acquire();

        i = 0;
        while (i < do_count) : (i += 1)
        {
            ProcessorInvalidatePage(region + i * page_size);
        }

        EsMemoryZero(region, do_count * page_size);
        pmm.manipulation_processor_lock.release();

        if (page_count != 0)
        {
            if (!contiguous) pages = @intToPtr([*]u64, @ptrToInt(pages) + Physical.memory_manipulation_region_page_count);
        }
        else break;
    }

    pmm.manipulation_lock.release();
}

export var earlyZeroBuffer: [page_size]u8 align(page_size) = undefined;

export fn MMPhysicalAllocate(flags: Physical.Flags, count: u64, alignment: u64, below: u64) callconv(.C) u64
{
    const mutex_already_acquired = flags.contains(.lock_acquired);
    if (!mutex_already_acquired) _ = pmm.pageframe_mutex.acquire()
    else pmm.pageframe_mutex.assert_locked();
    defer if (!mutex_already_acquired) pmm.pageframe_mutex.release();

    var commit_now = @intCast(i64, count * page_size);

    if (flags.contains(.commit_now))
    {
        if (!MMCommit(@intCast(u64, commit_now), true)) return 0;
    }
    else commit_now = 0;

    const simple = count == 1 and alignment == 1 and below == 0;

    if (!pmm.pageframeDatabaseInitialised)
    {
        if (!simple) KernelPanic("non-simple allocation before initialization of the pageframe database");
        const page = MMArchEarlyAllocatePage();
        if (flags.contains(.zeroed))
        {
            _ = MMArchMapPage(&_coreMMSpace, page, @ptrToInt(&earlyZeroBuffer), MapPageFlags.from_flags(.{ .overwrite, .no_new_tables, .frame_lock_acquired }));
            earlyZeroBuffer = zeroes(@TypeOf(earlyZeroBuffer));
        }

        return page;
    }
    else if (!simple)
    {
        const pages = BitsetGet(&pmm.free_or_zeroed_page_bitset, count, alignment, below);
        if (pages != std.math.maxInt(u64))
        {
            MMPhysicalActivatePages(pages, count);
            var address = pages << page_bit_count;
            if (flags.contains(.zeroed)) PMZero(@ptrCast([*]u64, &address), count, true);
            return address;
        }
        // else error
    }
    else
    {
        var not_zeroed = false;
        var page = pmm.first_zeroed_page;

        if (page == 0)
        {
            page = pmm.first_free_page;
            not_zeroed = true;
        }

        if (page == 0)
        {
            page = pmm.last_standby_page;
            not_zeroed = true;
        }

        if (page != 0)
        {
            const frame = &pmm.pageframes[page];

            switch (frame.state.read_volatile())
            {
                .active => KernelPanic("corrupt page frame database"),
                .standby =>
                {
                    if (frame.cache_reference.?.* != ((page << page_bit_count) | 1)) // MM_SHARED_ENTRY_PRESENT
                    {
                        KernelPanic("corrupt shared reference back pointer in frame");
                    }

                    frame.cache_reference.?.* = 0;
                },
                else =>
                {
                    BitsetTake(&pmm.free_or_zeroed_page_bitset, page);
                }
            }

            MMPhysicalActivatePages(page, 1);

            var address = page << page_bit_count;
            if (not_zeroed and flags.contains(.zeroed)) PMZero(@ptrCast([*]u64, &address), 1, false);

            return address;
        }
        // else fail
    }

    // failed
    if (!flags.contains(.can_fail))
    {
        KernelPanic("out of memory");
    }

    MMDecommit(@intCast(u64, commit_now), true);
    return 0;
}

export fn MMMapPhysical(space: *AddressSpace, asked_offset: u64, asked_byte_count: u64, caching: Region.Flags) callconv(.C) u64
{
    const offset2 = asked_offset & (page_size - 1);
    const offset = asked_offset - offset2;
    const byte_count = if (offset2 != 0) asked_byte_count + page_size else asked_byte_count;

    const region = blk:
    {
        _ = space.reserve_mutex.acquire();
        defer space.reserve_mutex.release();

        const result = MMReserve(space, byte_count, caching.or_flag(.fixed).or_flag(.physical), 0) orelse return 0;
        result.data.u.physical.offset = offset;
        break :blk result;
    };

    var i: u64 = 0;
    while (i < region.descriptor.page_count) : (i += 1)
    {
        _ = MMHandlePageFault(space, region.descriptor.base_address + i * page_size, HandlePageFaultFlags.empty());
    }

    return region.descriptor.base_address + offset2;
}

export fn MMPhysicalAllocateAndMap(asked_size: u64, asked_alignment: u64, maximum_bits: u64, zeroed: bool, flags: Region.Flags, p_virtual_address: *u64, p_physical_address: *u64) callconv(.C) bool
{
    const size = if (asked_size == 0) @as(u64, 1) else asked_size;
    const alignment = if (asked_alignment == 0) @as(u64, 1) else asked_alignment;

    const no_below = maximum_bits == 0 or maximum_bits >= 64;

    const size_in_pages = (size + page_size - 1) >> page_bit_count;
    const physical_address = MMPhysicalAllocate(Physical.Flags.from_flags(.{ .can_fail, .commit_now }), size_in_pages, (alignment + page_size - 1) >> page_bit_count, if (no_below) 0 else @as(u64, 1) << @truncate(u6, maximum_bits));
    if (physical_address == 0) return false;

    const virtual_address = MMMapPhysical(&_kernelMMSpace, physical_address, size, flags);
    if (virtual_address == 0)
    {
        MMPhysicalFree(physical_address, false, size_in_pages);
        return false;
    }

    if (zeroed) EsMemoryZero(virtual_address, size);

    p_virtual_address.* = virtual_address;
    p_physical_address.* = physical_address;

    return true;
}

export fn MMPhysicalInsertZeroedPage(page: u64) callconv(.C) void
{
    if (GetCurrentThread() != pmm.zero_page_thread) KernelPanic("inserting a zeroed page not on the mmzeropagethread");

    const frame = &pmm.pageframes[page];
    frame.state.write_volatile(.zeroed);

    frame.u.list.next.write_volatile(pmm.first_zeroed_page);
    frame.u.list.previous = &pmm.first_zeroed_page;
    if (pmm.first_zeroed_page != 0) pmm.pageframes[pmm.first_zeroed_page].u.list.previous = &frame.u.list.next.value;
    pmm.first_zeroed_page = page;

    pmm.zeroed_page_count += 1;
    BitsetPut(&pmm.free_or_zeroed_page_bitset, page);
    MMUpdateAvailablePageCount(true);
}

export fn MMZeroPageThread() callconv(.C) void
{
    while (true)
    {
        _ = pmm.zero_page_event.wait();
        _ = pmm.available_not_critical_event.wait();

        var done = false;

        while (!done)
        {
            var pages: [Physical.memory_manipulation_region_page_count]u64 = undefined;

            var i = blk:
            {
                _ = pmm.pageframe_mutex.acquire();
                defer pmm.pageframe_mutex.release();

                for (pages) |*page, page_i|
                {
                    if (pmm.first_free_page != 0)
                    {
                        page.* = pmm.first_free_page;
                        MMPhysicalActivatePages(page.*, 1);
                    }
                    else
                    {
                        done = true;
                        break :blk page_i;
                    }

                    const frame = &pmm.pageframes[page.*];
                    frame.state.write_volatile(.active);
                    BitsetTake(&pmm.free_or_zeroed_page_bitset, pages[page_i]);
                }

                break :blk pages.len;
            };

            var j: u64 = 0;
            while (j < i) : (j += 1)
            {
                pages[j] <<= page_bit_count;
            }

            if (i != 0) PMZero(&pages, i, false);

            _ = pmm.pageframe_mutex.acquire();
            pmm.active_page_count -= i;

            while (true)
            {
                const breaker = i;
                i -= 1;
                if (breaker == 0) break;
                MMPhysicalInsertZeroedPage(pages[i] >> page_bit_count);
            }

            pmm.pageframe_mutex.release();
        }
    }
}

export fn MMBalanceThread() callconv(.C) void
{
    var target_available_pages: u64 = 0;

    while (true)
    {
        if (pmm.get_available_page_count() >= target_available_pages)
        {
            _ = pmm.available_low_event.wait();
            target_available_pages = Physical.Allocator.low_available_page_threshold + Physical.Allocator.page_count_to_find_balance;
        }

        _ = scheduler.all_processes_mutex.acquire();
        const process = if (pmm.next_process_to_balance) |p| p else scheduler.all_processes.first.?.value.?;
        pmm.next_process_to_balance = if (process.all_item.next) |next| next.value else null;
        _ = OpenHandleToObject(@ptrToInt(process), KernelObjectType.process, 0);
        scheduler.all_processes_mutex.release();

        const space = process.address_space;
        ThreadSetTemporaryAddressSpace(space);
        _ = space.reserve_mutex.acquire();
        var maybe_item = if (pmm.next_region_to_balance) |r| &r.u.item.u.non_guard else space.used_regions_non_guard.first;

        while (maybe_item != null and pmm.get_available_page_count() < target_available_pages)
        {
            const item = maybe_item.?;
            const region = item.value.?;

            _ = region.data.map_mutex.acquire();

            var can_resume = false;

            if (region.flags.contains(.file))
            {
                TODO();
            }
            else if (region.flags.contains(.cache))
            {
                TODO();
                //_ = activeSectionManager.mutex.acquire();

                //var maybe_item2 = activeSectionManager.LRU_list.first;
                //while (maybe_item2 != null and pmm.get_available_page_count() < target_available_pages)
                //{
                    //const item2 = maybe_item2.?;
                    //const section = item2.value.?;
                    //if (section.cache != null and section.referenced_page_count != 0) 
                    //{
                        //TODO();
                        //// CCDereferenceActiveSection(section, 0);
                    //}
                    //maybe_item2 = item2.next;
                //}

                //activeSectionManager.mutex.release();
            }

            region.data.map_mutex.release();

            if (pmm.get_available_page_count() >= target_available_pages and can_resume) break;

            maybe_item = item.next;
            pmm.balance_resume_position = 0;
        }


        if (maybe_item) |item|
        {
            pmm.next_region_to_balance = item.value;
            pmm.next_process_to_balance = process;
        }
        else
        {
            pmm.next_region_to_balance = null;
            pmm.balance_resume_position = 0;
        }

        space.reserve_mutex.release();
        ThreadSetTemporaryAddressSpace(null);
        CloseHandleToObject(@ptrToInt(process), KernelObjectType.process, 0);
    }
}

export fn MMMapShared(space: *AddressSpace, shared_region: *SharedRegion, offset: u64, asked_byte_count: u64, flags: Region.Flags, base_address: u64) callconv(.C) u64
{
    _ = OpenHandleToObject(@ptrToInt(shared_region), KernelObjectType.shared_memory, 0);
    _ = space.reserve_mutex.acquire();
    defer space.reserve_mutex.release();

    const byte_count: u64 = if (offset & (page_size - 1) != 0) asked_byte_count + (offset & (page_size - 1)) else asked_byte_count;
    if (shared_region.size <= offset or shared_region.size < offset + byte_count)
    {
        CloseHandleToObject(@ptrToInt(shared_region), KernelObjectType.shared_memory, 0);
        return 0;
    }
    const region = MMReserve(space, byte_count, flags.or_flag(.shared), base_address) orelse
    {
        CloseHandleToObject(@ptrToInt(shared_region), KernelObjectType.shared_memory, 0);
        return 0;
    };

    if (!region.flags.contains(.shared)) KernelPanic("cannot commit into non-shared region");
    if (region.data.u.shared.region != null) KernelPanic("a shared region has already been bound");

    region.data.u.shared.region = shared_region;
    region.data.u.shared.offset = offset & ~@as(u64, page_size - 1);
    return region.descriptor.base_address + (offset & (page_size - 1));
}

export fn MMFaultRange(address: u64, byte_count: u64, flags: HandlePageFaultFlags) callconv(.C) bool
{
    const start = address & ~@as(u64, page_size - 1);
    const end = (address + byte_count - 1) & ~@as(u64, page_size - 1);
    var page = start;

    while (page <= end) : (page += page_size)
    {
        if (!MMArchHandlePageFault(page, flags)) return false;
    }

    return true;
}

// @TODO: MMInitialise

export fn MMSpaceCloseReference(space: *AddressSpace) callconv(.C) void
{
    if (space == &_kernelMMSpace) return;
    if (space.reference_count.read_volatile() < 1) KernelPanic("space has invalid reference count");
    if (space.reference_count.atomic_fetch_sub(1) > 1) return;

    KRegisterAsyncTask(&space.remove_async_task, CloseReferenceTask);
}

fn CloseReferenceTask(task: *AsyncTask) void
{
    const space = @fieldParentPtr(AddressSpace, "remove_async_task", task);
    MMArchFinalizeVAS(space);
    PoolRemove(&scheduler.address_space_pool, @ptrToInt(space));
}

export fn MMArchFinalizeVAS(space: *AddressSpace) callconv(.C) void
{
    _ = space;
    TODO();
}

const ACPI = extern struct
{
    processor_count: u64,
    IO_APIC_count: u64,
    interrupt_override_count: u64,
    LAPIC_NMI_count: u64,

    processors: [256]CPU,
    IO_APICs: [16]IO_APIC,
    interrupt_overrides: [256]InterruptOverride,
    LAPIC_NMIs: [32]LAPIC_NMI,

    rsdp: *RootSystemDescriptorPointer,
    madt: *align(1) DescriptorTable,

    LAPIC_address: [*]volatile u32,
    LAPIC_ticks_per_ms: u64,

    PS2_controller_unavailable: bool,
    VGA_controller_unavailable: bool,
    century_register_index: u8,

    HPET_base_address: ?[*]volatile u64,
    HPET_period: u64,

    computer: u64, // @ABICompatibility

    const RSDP_signature = 0x2052545020445352;
    const RSDT_signature = 0x54445352;
    const XSDT_signature = 0x54445358;
    const MADT_signature = 0x43495041;
    const FADT_signature = 0x50434146;
    const HPET_signature = 0x54455048;

    pub const RootSystemDescriptorPointer = extern struct
    {
        signature: u64,
        checksum: u8,
        OEM_ID: [6]u8,
        revision: u8,
        RSDT_address: u32,
        length: u32,
        XSDT_address: u64,
        extended_checksum: u8,
        reserved: [3]u8,

        pub const signature = 0x2052545020445352;
    };

    pub const IO_APIC = extern struct
    {
        id: u8,
        address: [*]volatile u32,
        GSI_base: u32,

        pub fn read(self: *@This(), register: u32) u32
        {
            self.address[0] = register;
            return self.address[4];
        }

        pub fn write(self: *@This(), register: u32, value: u32) void
        {
            self.address[0] = register;
            self.address[4] = value;
        }
    };

    pub const InterruptOverride = extern struct
    {
        source_IRQ: u8,
        GSI_number: u32,
        active_low: bool,
        level_triggered: bool,
    };

    pub const LAPIC_NMI = extern struct
    {
        processor: u8,
        lint_index: u8,
        active_low: bool,
        level_triggered: bool,
    };

    pub const DescriptorTable = extern struct
    {
        signature: u32,
        length: u32,
        id: u64,
        table_ID: u64,
        OEM_revision: u32,
        creator_ID: u32,
        creator_revision: u32,

        pub const header_length = 36;

        pub fn check(self: *align(1) @This()) void
        {
            if (EsMemorySumBytes(@ptrCast([*]u8, self), self.length) != 0)
            {
                KernelPanic("ACPI table checksum failed!");
            }
        }
    };

    pub const MultipleAPICDescriptionTable = extern struct
    {
        LAPIC_address: u32,
        flags: u32,
    };

    pub fn parse_tables(self: *@This()) void
    {
        var is_XSDT = false;
        const sdt = blk:
        {
            if (@intToPtr(?*RootSystemDescriptorPointer, MMMapPhysical(&_kernelMMSpace, ArchFindRootSystemDescriptorPointer(), 16384, Region.Flags.empty()))) |rsdp|
            {
                self.rsdp = rsdp;

                is_XSDT = self.rsdp.revision == 2 and self.rsdp.XSDT_address != 0;
                const sdt_physical_address =
                    if (is_XSDT) self.rsdp.XSDT_address
                    else self.rsdp.RSDT_address;

                break :blk @intToPtr(*align(1) DescriptorTable, MMMapPhysical(&_kernelMMSpace, sdt_physical_address, 16384, Region.Flags.empty()));
            }
            else
            {
                KernelPanic("unable to get RSDP");
            }
        };

        const is_valid = ((sdt.signature == XSDT_signature and is_XSDT) or (sdt.signature == RSDT_signature and !is_XSDT)) and sdt.length < 16384 and EsMemorySumBytes(@ptrCast([*]u8, sdt), sdt.length) == 0;

        if (!is_valid) KernelPanic("system descriptor pointer is invalid");

        const table_count = (sdt.length - @sizeOf(DescriptorTable)) >> (@as(u2, 2) + @boolToInt(is_XSDT));

        if (table_count == 0) KernelPanic("no tables found");

        const table_list_address = @ptrToInt(sdt) + DescriptorTable.header_length;

        var found_madt = false;
        var i: u64 = 0;

        while (i < table_count) : (i += 1)
        {
            const address =
                if (is_XSDT) @intToPtr([*]align(1) u64, table_list_address)[i]
                else @intToPtr([*]align(1) u32, table_list_address)[i];

            const header = @intToPtr(*align(1) DescriptorTable, MMMapPhysical(&_kernelMMSpace, address, @sizeOf(DescriptorTable), Region.Flags.empty()));

            switch (header.signature)
            {
                MADT_signature =>
                {
                    const madt_header = @intToPtr(*align(1) DescriptorTable, MMMapPhysical(&_kernelMMSpace, address, header.length, Region.Flags.empty()));
                    madt_header.check();

                    if (@intToPtr(?*align(1) MultipleAPICDescriptionTable, @ptrToInt(madt_header) + DescriptorTable.header_length)) |madt|
                    {
                        found_madt = true;

                        const start_length = madt_header.length - DescriptorTable.header_length - @sizeOf(MultipleAPICDescriptionTable);
                        var length = start_length;
                        var madt_bytes = @intToPtr([*]u8, @ptrToInt(madt) + @sizeOf(MultipleAPICDescriptionTable));
                        self.LAPIC_address = @intToPtr([*]volatile u32, map_physical_memory(madt.LAPIC_address, 0x10000));
                        _ = length;
                        _ = madt_bytes;

                        var entry_length: u8 = undefined;

                        while (length != 0 and length <= start_length) :
                            ({
                                length -= entry_length;
                                madt_bytes = @intToPtr([*]u8, @ptrToInt(madt_bytes) + entry_length);
                            })
                        {
                            const entry_type = madt_bytes[0];
                            entry_length = madt_bytes[1];

                            switch (entry_type)
                            {
                                0 =>
                                {
                                    if (madt_bytes[4] & 1 == 0) continue;
                                    const cpu = &self.processors[self.processor_count];
                                    cpu.processor_ID = madt_bytes[2];
                                    cpu.APIC_ID = madt_bytes[3];
                                    self.processor_count += 1;
                                },
                                1 =>
                                {
                                    const madt_u32 = @ptrCast([*]align(1)u32, madt_bytes);
                                    var io_apic = &self.IO_APICs[self.IO_APIC_count];
                                    io_apic.id = madt_bytes[2];
                                    io_apic.address = @intToPtr([*]volatile u32, map_physical_memory(madt_u32[1], 0x10000));
                                    // make sure it's mapped
                                    _ = io_apic.read(0);
                                    io_apic.GSI_base = madt_u32[2];
                                    self.IO_APIC_count += 1;
                                },
                                2 =>
                                {
                                    const madt_u32 = @ptrCast([*]align(1)u32, madt_bytes);
                                    const interrupt_override = &self.interrupt_overrides[self.interrupt_override_count];
                                    interrupt_override.source_IRQ = madt_bytes[3];
                                    interrupt_override.GSI_number = madt_u32[1];
                                    interrupt_override.active_low = madt_bytes[8] & 2 != 0;
                                    interrupt_override.level_triggered = madt_bytes[8] & 8 != 0;
                                    self.interrupt_override_count += 1;
                                },
                                4 =>
                                {
                                    const nmi = &self.LAPIC_NMIs[self.LAPIC_NMI_count];
                                    nmi.processor = madt_bytes[2];
                                    nmi.lint_index = madt_bytes[5];
                                    nmi.active_low = madt_bytes[3] & 2 != 0;
                                    nmi.level_triggered = madt_bytes[3] & 8 != 0;
                                    self.LAPIC_NMI_count += 1;
                                },
                                else => {},
                            }
                        }

                        if (self.processor_count > 256 or self.IO_APIC_count > 16 or self.interrupt_override_count > 256 or self.LAPIC_NMI_count > 32)
                        {
                            KernelPanic("wrong numbers");
                        }
                    }
                    else
                    {
                        KernelPanic("ACPI initialization - couldn't find the MADT table");
                    }
                },
                FADT_signature =>
                {
                    const fadt = @intToPtr(*align(1) DescriptorTable, MMMapPhysical(&_kernelMMSpace, address, header.length, Region.Flags.empty()));
                    fadt.check();

                    if (header.length > 109)
                    {
                        const fadt_bytes = @ptrCast([*]u8, fadt);
                        self.century_register_index = fadt_bytes[108];
                        const boot_architecture_flags = fadt_bytes[109];
                        self.PS2_controller_unavailable = (~boot_architecture_flags & (1 << 1)) != 0;
                        self.VGA_controller_unavailable = (boot_architecture_flags & (1 << 2)) != 0;
                    }

                    _ = MMFree(&_kernelMMSpace, @ptrToInt(fadt), 0, false);
                },
                HPET_signature =>
                {
                    const hpet = @intToPtr(*align(1) DescriptorTable, MMMapPhysical(&_kernelMMSpace, address, header.length, Region.Flags.empty()));
                    hpet.check();

                    const header_bytes = @ptrCast([*]u8, header);
                    if (header.length > 52 and header_bytes[52] == 0)
                    {
                        if (@intToPtr(?[*]volatile u64, MMMapPhysical(&_kernelMMSpace, @ptrCast(*align(1) u64, &header_bytes[44]).*, 1024, Region.Flags.empty()))) |HPET_base_address|
                        {
                            self.HPET_base_address = HPET_base_address;
                            self.HPET_base_address.?[2] |= 1; // start the main counter

                            self.HPET_period = self.HPET_base_address.?[0] >> 32;
                            // @INFO: Just for logging
                            //const revision_ID = @truncate(u8, self.HPET_base_address[0]);
                            //const initial_count = self.HPET_base_address[30];
                        }
                        else
                        {
                            KernelPanic("failed to map HPET base address\n");
                        }
                    }

                    _ = MMFree(&_kernelMMSpace, @ptrToInt(hpet), 0, false);
                },
                else => {},
            }


            _ = MMFree(&_kernelMMSpace, @ptrToInt(header), 0, false);
        }

        if (!found_madt) KernelPanic("MADT not found");
    }

    fn map_physical_memory(physical_address: u64, length: u64) u64
    {
        return MMMapPhysical(&_kernelMMSpace, physical_address, length, Region.Flags.from_flag(.not_cacheable));
    }
};

export fn ArchFindRootSystemDescriptorPointer() callconv(.C) u64
{
    const UEFI_RSDP = @intToPtr(*u64, low_memory_map_start + bootloader_information_offset + 0x7fe8).*;
    if (UEFI_RSDP != 0) return UEFI_RSDP;

    var search_regions: [2]Physical.MemoryRegion = undefined;
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

export var acpi: ACPI = undefined;

export fn ACPIIoApicReadRegister(self: *ACPI.IO_APIC, register: u32) callconv(.C) u32
{
    return self.read(register);
}

export fn ACPIIoApicWriteRegister(self: *ACPI.IO_APIC, register: u32, value: u32) callconv(.C) void
{
    self.write(register, value);
}

export fn ACPICheckTable(table: *align(1) ACPI.DescriptorTable) callconv(.C) void
{
    table.check();
}

export fn ACPIMapPhysicalMemory(physical_address: u64, length: u64) callconv(.C) u64
{
    return ACPI.map_physical_memory(physical_address, length);
}

export fn ACPIGetRSDP() callconv(.C) *ACPI.RootSystemDescriptorPointer
{
    return acpi.rsdp;
}

export fn ACPIGetCenturyRegisterIndex() callconv(.C) u8
{
    return acpi.century_register_index;
}

extern fn ACPIParseTables() callconv(.C) void;

export fn KGetCPUCount() callconv(.C) u64
{
    return acpi.processor_count;
}

export fn KGetCPULocal(index: u64) callconv(.C) ?*LocalStorage
{
    return acpi.processors[index].local_storage;
}
// @TODO: ArchInitialiseThread

export fn LapicReadRegister(register: u32) callconv(.C) u32
{
    return acpi.LAPIC_address[register];
}

export fn LapicWriteRegister(register: u32, value: u32) callconv(.C) void
{
    acpi.LAPIC_address[register] = value;
}

export fn LapicNextTimer(ms: u64) callconv(.C) void
{
    LapicWriteRegister(0x320 >> 2, timer_interrupt | (1 << 17));
    LapicWriteRegister(0x380 >> 2, @intCast(u32, acpi.LAPIC_ticks_per_ms * ms));
}

export fn LapicEndOfInterrupt() callconv(.C) void
{
    LapicWriteRegister(0xb0 >> 2, 0);
}

export var pciConfigSpinlock: Spinlock = undefined;
export var ipiLock: Spinlock = undefined;

export fn ProcessorSendIPI(interrupt: u64, nmi: bool, processor_ID: i32) callconv(.C) u64
{
    if (interrupt != kernel_panic_ipi) ipiLock.assert_locked();

    var ignored: u64 = 0;

    for (acpi.processors[0..acpi.processor_count]) |*processor|
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
            if (processor == GetLocalStorage().?.cpu or processor.local_storage == null or !processor.local_storage.?.scheduler_ready)
            {
                ignored += 1;
                continue;
            }
        }

        const destination = @intCast(u32, processor.APIC_ID) << 24;
        const command = @intCast(u32, interrupt | (1 << 14) | if (nmi) @as(u32, 0x400) else @as(u32, 0));
        LapicWriteRegister(0x310 >> 2, destination);
        LapicWriteRegister(0x300 >> 2, command);

        while (LapicReadRegister(0x300 >> 2) & (1 << 12) != 0) { }
    }

    return ignored;
}

export var tlbShootdownVirtualAddress: Volatile(u64) = undefined;
export var tlbShootdownPageCount: Volatile(u64) = undefined;

const CallFunctionOnAllProcessorsCallback = fn() void;
export var callFunctionOnAllProcessorsCallback: CallFunctionOnAllProcessorsCallback = undefined;
export var callFunctionOnAllProcessorsRemaining: Volatile(u64) = undefined;

const timer_interrupt = 0x40;
const yield_ipi = 0x41;
const irq_base = 0x50;
const call_function_on_all_processors_ipi = 0xf0;
const tlb_shootdown_ipi = 0xf1;
const kernel_panic_ipi = 0;

const interrupt_vector_msi_start = 0x70;
const interrupt_vector_msi_count = 0x40;

fn ArchCallFunctionOnAllProcessors(callback: CallFunctionOnAllProcessorsCallback, including_this_processor: bool) void
{
    ipiLock.assert_locked();
    //if (callback == 0) KernelPanic("Callback is null");

    const cpu_count = KGetCPUCount();
    if (cpu_count > 1)
    {
        @ptrCast(*volatile CallFunctionOnAllProcessorsCallback, &callFunctionOnAllProcessorsCallback).* = callback;
        callFunctionOnAllProcessorsRemaining.write_volatile(cpu_count);
        const ignored = ProcessorSendIPI(call_function_on_all_processors_ipi, false, -1);
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
            ProcessorInvalidatePage(page);
        }
    }
}

const KIRQHandler = fn(interrupt_index: u64, context: u64) callconv(.C) bool;
const MSIHandler = extern struct
{
    callback: ?KIRQHandler,
    context: u64,
};

const IRQHandler = extern struct
{
    callback: KIRQHandler,
    context: u64,
    line: i64,
    pci_device: u64, // @ABICompatibility
    owner_name: u64, // @ABICompatibility
};

export var pciIRQLines: [0x100][4]u8 = undefined;
export var msiHandlers: [interrupt_vector_msi_count]MSIHandler = undefined;
export var irqHandlers: [0x40]IRQHandler = undefined;
export var irqHandlersLock: Spinlock = undefined;


export var physicalMemoryRegions: [*]Physical.MemoryRegion = undefined;
export var physicalMemoryRegionsCount: u64 = undefined;
export var physicalMemoryRegionsPagesCount: u64 = undefined;
export var physicalMemoryOriginalPagesCount: u64 = undefined;
export var physicalMemoryRegionsIndex: u64 = undefined;
export var physicalMemoryHighest: u64 = undefined;

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

export fn MMArchFreeVAS(space: *AddressSpace) callconv(.C) void
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

                MMPhysicalFree(PageTables.access_at_index(.level2, k).* & ~@as(u64, page_size - 1), false, 1);
                space.arch.active_page_table_count -= 1;
            }

            MMPhysicalFree(PageTables.access_at_index(.level3, j).* & ~@as(u64, page_size - 1), false, 1);
            space.arch.active_page_table_count -= 1;
        }

        MMPhysicalFree(PageTables.access_at_index(.level4, i).* & ~@as(u64, page_size - 1), false, 1);
        space.arch.active_page_table_count -= 1;
    }

    if (space.arch.active_page_table_count != 0)
    {
        KernelPanic("space has still active page tables");
    }

    _ = _coreMMSpace.reserve_mutex.acquire();
    const l1_commit_region = MMFindRegion(&_coreMMSpace, @ptrToInt(space.arch.commit.L1)).?;
    MMArchUnmapPages(&_coreMMSpace, l1_commit_region.descriptor.base_address, l1_commit_region.descriptor.page_count, UnmapPagesFlags.from_flag(.free), 0, null);
    MMUnreserve(&_coreMMSpace, l1_commit_region, false, false);
    _coreMMSpace.reserve_mutex.release();
    MMDecommit(space.arch.commited_page_table_count * page_size, true);
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

export fn EarlyDelay1Ms() callconv(.C) void
{
    ProcessorOut8(IO_PIT_COMMAND, 0x30);
    ProcessorOut8(IO_PIT_DATA, 0xa9);
    ProcessorOut8(IO_PIT_DATA, 0x04);

    while (true)
    {
        ProcessorOut8(IO_PIT_COMMAND, 0xe2);

        if (ProcessorIn8(IO_PIT_DATA) & (1 << 7) != 0) break;
    }
}

//const UserSpinlock = extern struct
//{
    //state: Volatile(u8),

    //fn acquire(self: *@This()) void
    //{
        //@fence(atomic_order);
        //while (self.state.atomic_compare_and_swap(0, 1) != null) {}
        //@fence(atomic_order);
    //}

    //fn release(self: *@This()) void
    //{
        //@fence(atomic_order);
        //if (self.state.read_volatile() == 0) KernelPanic("spinlock not acquired");
        //self.state.write_volatile(0);
        //@fence(atomic_order);
    //}
//};

pub const RandomNumberGenerator = extern struct
{
    s: [4]u64,
    lock: UserSpinlock,

    pub fn add_entropy(self: *@This(), n: u64) void
    {
        @setRuntimeSafety(false); // We are relying on overflow here
        self.lock.acquire();
        var x = n;

        for (self.s) |*s|
        {
            x += 0x9E3779B97F4A7C15;
            var result = x;
            result = (result ^ (result >> 30)) * 0xBF58476D1CE4E5B9;
            result = (result ^ (result >> 27)) * 0x94D049BB133111EB;
            s.* ^= result ^ (result >> 31);
        }
        self.lock.release();
    }

    const UserSpinlock = extern struct
    {
        state: Volatile(u8),

        fn acquire(self: *@This()) void
        {
            @fence(.SeqCst);
            while (self.state.atomic_compare_and_swap(0, 1) == null) {}
            @fence(.SeqCst);
        }

        fn release(self: *@This()) void
        {
            @fence(.SeqCst);
            if (self.state.read_volatile() == 0) KernelPanic("spinlock not acquired");
            self.state.write_volatile(0);
            @fence(.SeqCst);
        }
    };
};

var rng: RandomNumberGenerator = undefined;

export var timeStampTicksPerMs: u64 = undefined;

const NewProcessorStorage = extern struct
{
    local: *LocalStorage,
    gdt: u64,

    fn allocate(cpu: *CPU) @This()
    {
        var storage: @This() = undefined;
        storage.local = @intToPtr(*LocalStorage, EsHeapAllocate(@sizeOf(LocalStorage), true, &heapFixed));
        const gdt_physical_address = MMPhysicalAllocateWithFlags(Physical.Flags.from_flag(.commit_now));
        storage.gdt = MMMapPhysical(&_kernelMMSpace, gdt_physical_address, page_size, Region.Flags.empty());
        storage.local.cpu = cpu;
        cpu.local_storage = storage.local;
        SchedulerCreateProcessorThreads(storage.local);
        cpu.kernel_processor_ID = @intCast(u8, storage.local.processor_ID);
        return storage;
    }
};

export fn ArchInitialise() callconv(.C) void
{
    acpi.parse_tables();

    const bootstrap_LAPIC_ID = @intCast(u8, LapicReadRegister(0x20 >> 2) >> 24);

    const current_cpu = blk:
    {
        for (acpi.processors[0..acpi.processor_count]) |*processor|
        {
            if (processor.APIC_ID == bootstrap_LAPIC_ID)
            {
                processor.boot_processor = true;
                break :blk processor;
            }
        }

        KernelPanic("could not find the bootstrap processor");
    };

    ProcessorDisableInterrupts();
    const start = ProcessorReadTimeStamp();
    LapicWriteRegister(0x380 >> 2, std.math.maxInt(u32));
    var i: u64 = 0;
    while (i < 8) : (i += 1)
    {
        EarlyDelay1Ms();
    }

    acpi.LAPIC_ticks_per_ms = (std.math.maxInt(u32) - LapicReadRegister(0x390 >> 2)) >> 4;
    rng.add_entropy(LapicReadRegister(0x390 >> 2));

    const end = ProcessorReadTimeStamp();
    timeStampTicksPerMs = (end - start) >> 3;
    ProcessorEnableInterrupts();

    var storage = NewProcessorStorage.allocate(current_cpu);
    SetupProcessor2(&storage);
}

export fn ProcessSpawn(process_type: Process.Type) callconv(.C) ?*Process
{
    if (scheduler.shutdown.read_volatile()) return null;

    const process = if (process_type == .kernel)  kernelProcess else (@intToPtr(?*Process, PoolAdd(&scheduler.process_pool, @sizeOf(Process))) orelse return null);

    process.address_space = if (process_type == .kernel) &_kernelMMSpace else (@intToPtr(?*AddressSpace, PoolAdd(&scheduler.address_space_pool, @sizeOf(Process))) orelse 
        {
            PoolRemove(&scheduler.process_pool, @ptrToInt(process));
            return null;
        });

    process.id = @atomicRmw(@TypeOf(scheduler.next_processor_id), &scheduler.next_process_id, .Add, 1, .SeqCst);
    process.address_space.reference_count.write_volatile(1);
    process.all_item.value = process;
    process.handle_count.write_volatile(1);
    process.handle_table.process = process;
    process.permissions = Process.Permission.all();
    process.type = process_type;

    if (process_type == .kernel)
    {
        _ = EsCRTstrcpy(@ptrCast([*:0]u8, &process.executable_name), "Kernel");
        scheduler.all_processes.insert_at_end(&process.all_item);
    }

    return process;
}

export fn ProcessorSendYieldIPI(thread: *Thread) callconv(.C) void
{
    thread.received_yield_IPI.write_volatile(false);
    ipiLock.acquire();
    _ = ProcessorSendIPI(yield_ipi, false, -1);
    ipiLock.release();
    while (!thread.received_yield_IPI.read_volatile()) {}
}
var get_time_from_PIT_ms_started = false;
var get_time_from_PIT_ms_cumulative: u64 = 0;
var get_time_from_PIT_ms_last: u64 = 0;

export fn ArchGetTimeFromPITMs() callconv(.C) u64
{
    if (!get_time_from_PIT_ms_started)
    {
        ProcessorOut8(IO_PIT_COMMAND, 0x30);
        ProcessorOut8(IO_PIT_DATA, 0xff);
        ProcessorOut8(IO_PIT_DATA, 0xff);
        get_time_from_PIT_ms_started = true;
        get_time_from_PIT_ms_last = 0xffff;
        return 0;
    }
    else
    {
        ProcessorOut8(IO_PIT_COMMAND, 0);
        var x: u16 = ProcessorIn8(IO_PIT_DATA);
        x |= @as(u16, ProcessorIn8(IO_PIT_DATA)) << 8;
        get_time_from_PIT_ms_cumulative += get_time_from_PIT_ms_last - x;
        if (x > get_time_from_PIT_ms_last) get_time_from_PIT_ms_cumulative += 0x10000;
        get_time_from_PIT_ms_last = x;
        return get_time_from_PIT_ms_cumulative * 1000 / 1193182;
    }
}

export fn ArchGetTimeMs() callconv(.C) u64
{
    timeStampCounterSynchronizationValue.write_volatile(((timeStampCounterSynchronizationValue.read_volatile() & 0x8000000000000000) ^ 0x8000000000000000) | ProcessorReadTimeStamp());
    if (acpi.HPET_base_address != null and acpi.HPET_period != 0)
    {
        const fs_to_ms = 1000000000000;
        const reading: u128 = acpi.HPET_base_address.?[30];
        return @intCast(u64, reading * acpi.HPET_period / fs_to_ms);
    }

    return ArchGetTimeFromPITMs();
}

export fn ThreadPause(thread: *Thread, resume_after: bool) callconv(.C) void
{
    scheduler.dispatch_spinlock.acquire();

    if (thread.paused.read_volatile() == !resume_after) return;

    thread.paused.write_volatile(!resume_after);

    if (!resume_after and thread.terminatable_state.read_volatile() == .terminatable)
    {
        if (thread.state.read_volatile() == .active)
        {
            if (thread.executing.read_volatile())
            {
                if (thread == GetCurrentThread())
                {
                    scheduler.dispatch_spinlock.release();

                    ProcessorFakeTimerInterrupt();

                    if (thread.paused.read_volatile()) KernelPanic("current thread incorrectly resumed");
                }
                else
                {
                    ProcessorSendYieldIPI(thread);
                }
            }
            else
            {
                thread.item.remove_from_list();
                SchedulerAddActiveThread(thread, false);
            }
        }
    }
    else if (resume_after and thread.item.list == &scheduler.paused_threads)
    {
        scheduler.paused_threads.remove(&thread.item);
        SchedulerAddActiveThread(thread, false);
    }

    scheduler.dispatch_spinlock.release();
}

export fn ProcessPause(process: *Process, resume_after: bool) callconv(.C) void
{
    _ = process.threads_mutex.acquire();
    var maybe_thread_item = process.threads.first;

    while (maybe_thread_item) |thread_item|
    {
        const thread = thread_item.value.?;
        maybe_thread_item = thread_item.next;
        ThreadPause(thread, resume_after);
    }

    process.threads_mutex.release();
}

export fn ProcessCrash(process: *Process, crash_reason: *CrashReason) callconv(.C) void
{
    if (process == kernelProcess) KernelPanic("kernel process has crashed");
    if (process.type != .normal) KernelPanic("A critical process has crashed");
    if (GetCurrentThread().?.process != process)
    {
        KernelPanic("Attempt to crash process from different process");
    }

    _ = process.crash_mutex.acquire();

    if (process.crashed)
    {
        process.crash_mutex.release();
        return;
    }

    process.crashed = true;

    EsMemoryCopy(@ptrToInt(&process.crash_reason), @ptrToInt(crash_reason), @sizeOf(CrashReason));

    if (!scheduler.shutdown.read_volatile())
    {
        // Send message to desktop
    }

    process.crash_mutex.release();
    ProcessPause(GetCurrentThread().?.process.?, false);
}

export fn MMPhysicalInsertFreePagesNext(page: u64) callconv(.C) void
{
    const frame = &pmm.pageframes[page];
    frame.state.write_volatile(.free);

    frame.u.list.next.write_volatile(pmm.first_free_page);
    frame.u.list.previous = &pmm.first_free_page;
    if (pmm.first_free_page != 0) pmm.pageframes[pmm.first_free_page].u.list.previous = &frame.u.list.next.value;
    pmm.first_free_page = page;

    BitsetPut(&pmm.free_or_zeroed_page_bitset, page);
    pmm.free_page_count += 1;
}

export fn MMArchPopulatePageFrameDatabase() callconv(.C) u64
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
            MMPhysicalInsertFreePagesNext(base + i);
        }
    }

    physicalMemoryRegionsPagesCount = 0;
    return commit_limit;
}

export fn MMArchGetPhysicalMemoryHighest() callconv(.C) u64
{
    return physicalMemoryHighest;
}

export fn MMArchInitialise() callconv(.C) void
{
    const cr3 = ProcessorReadCR3();
    _kernelMMSpace.arch.cr3 = cr3;
    _coreMMSpace.arch.cr3 = cr3;

    mmCoreRegions[0].descriptor.base_address = core_address_space_start;
    mmCoreRegions[0].descriptor.page_count = core_address_space_size / page_size;

    var i: u64 = 0x100;
    while (i < 0x200) : (i += 1)
    {
        if (PageTables.access_at_index(.level4, i).* == 0)
        {
            PageTables.access_at_index(.level4, i).* = MMPhysicalAllocateWithFlags(Physical.Flags.empty()) | 0b11;
            EsMemoryZero(@ptrToInt(PageTables.access_at_index(.level3, i * 0x200)), page_size);
        }
    }

    _coreMMSpace.arch.commit.L1 = &core_L1_commit;
    _ = _coreMMSpace.reserve_mutex.acquire();
    _kernelMMSpace.arch.commit.L1 = @intToPtr([*]u8, MMReserve(&_coreMMSpace, ArchAddressSpace.L1_commit_size, Region.Flags.from_flags(.{ .normal, .no_commit_tracking, .fixed }), 0).?.descriptor.base_address);
    _coreMMSpace.reserve_mutex.release();
}
export fn MMArchEarlyAllocatePage() callconv(.C) u64
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

        KernelPanic("Unable to early allocate a page\n");
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
    physicalMemoryRegions = @intToPtr([*]Physical.MemoryRegion, low_memory_map_start + 0x60000 + bootloader_information_offset);

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
    ProcessorOut8(port, value);
    _ = ProcessorIn8(IO_UNUSED_DELAY);
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
        ProcessorDebugOutputByte('-');
    }
    ProcessorDebugOutputByte('\r');
    ProcessorDebugOutputByte('\n');
}

export fn PCDisablePIC() callconv(.C) void
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

export fn ArchNextTimer(ms: u64) callconv(.C) void
{
    while (!scheduler.started.read_volatile()) { }
    GetLocalStorage().?.scheduler_ready = true;
    LapicNextTimer(ms);
}

export fn MMArchCommitPageTables(space: *AddressSpace, region: *Region) callconv(.C) bool
{
    _ = space.reserve_mutex.assert_locked();

    const base = (region.descriptor.base_address - @as(u64, if (space == &_coreMMSpace) core_address_space_start else 0)) & 0x7FFFFFFFF000;
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
        if (!MMCommit(needed * page_size, true))
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

fn handle_missing_page_table(space: *AddressSpace, comptime level: PageTables.Level, indices: PageTables.Indices, flags: MapPageFlags) callconv(.Inline) void
{
    assert(level != .level1);

    if (PageTables.access(level, indices).* & 1 == 0)
    {
        if (flags.contains(.no_new_tables)) KernelPanic("no new tables flag set but a table was missing\n");

        const physical_allocation_flags = Physical.Flags.from_flag(.lock_acquired);
        const physical_allocation = MMPhysicalAllocateWithFlags(physical_allocation_flags) | 0b111;
        PageTables.access(level, indices).* = physical_allocation;
        const previous_level = comptime @intToEnum(PageTables.Level, @enumToInt(level) - 1);

        const page = @ptrToInt(PageTables.access_at_index(previous_level, indices[@enumToInt(previous_level)]));
        ProcessorInvalidatePage(page);
        const page_slice = @intToPtr([*]u8, page & ~@as(u64, page_size - 1))[0..page_size];
        std.mem.set(u8, page_slice, 0);
        space.arch.active_page_table_count += 1;
    }
}

export fn MMArchMapPage(space: *AddressSpace, asked_physical_address: u64, asked_virtual_address: u64, flags: MapPageFlags) callconv(.C) bool
{
    if ((asked_virtual_address | asked_physical_address) & (page_size - 1) != 0)
    {
        KernelPanic("Mapping pages that are not aligned\n");
    }

    if (pmm.pageframeDatabaseCount != 0 and (asked_physical_address >> page_bit_count) < pmm.pageframeDatabaseCount)
    {
        const frame_state = pmm.pageframes[asked_physical_address >> page_bit_count].state.read_volatile();
        if (frame_state != .active and frame_state != .unusable)
        {
            KernelPanic("Physical pageframe not marked as active or unusable\n");
        }
    }

    if (asked_physical_address == 0) KernelPanic("Attempt to map physical page 0\n");
    if (asked_virtual_address == 0) KernelPanic("Attempt to map virtual page 0\n");

    if (asked_virtual_address < 0xFFFF800000000000 and ProcessorReadCR3() != space.arch.cr3)
    {
        KernelPanic("Attempt to map page into another address space\n");
    }

    const acquire_framelock = !flags.contains(.no_new_tables) and !flags.contains(.frame_lock_acquired);
    if (acquire_framelock) _ = pmm.pageframe_mutex.acquire();
    defer if (acquire_framelock) pmm.pageframe_mutex.release();

    const acquire_spacelock = !flags.contains(.no_new_tables);
    if (acquire_spacelock) _ = space.arch.mutex.acquire();
    defer if (acquire_spacelock) space.arch.mutex.release();

    const physical_address = asked_physical_address & 0xFFFFFFFFFFFFF000;
    const virtual_address = asked_virtual_address & 0x0000FFFFFFFFF000;

    const indices = PageTables.compute_indices(virtual_address);

    if (space != &_coreMMSpace and space != &_kernelMMSpace)
    {
        const index_L4 = indices[@enumToInt(PageTables.Level.level4)];
        if (space.arch.commit.L3[index_L4 >> 3] & (@as(u8, 1) << @truncate(u3, index_L4 & 0b111)) == 0) KernelPanic("attempt to map using uncommited L3 page table\n");

        const index_L3 = indices[@enumToInt(PageTables.Level.level3)];
        if (space.arch.commit.L2[index_L3 >> 3] & (@as(u8, 1) << @truncate(u3, index_L3 & 0b111)) == 0) KernelPanic("attempt to map using uncommited L3 page table\n");

        const index_L2 = indices[@enumToInt(PageTables.Level.level2)];
        if (space.arch.commit.L1[index_L2 >> 3] & (@as(u8, 1) << @truncate(u3, index_L2 & 0b111)) == 0) KernelPanic("attempt to map using uncommited L3 page table\n");
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
            KernelPanic("attempt to map page tha has already been mapped\n");
        }

        if (old_value == value)
        {
            KernelPanic("attempt to rewrite page translation\n");
        }
        else
        {
            const page_become_writable = old_value & 2 == 0 and value & 2 != 0;
            if (!page_become_writable)
            {
                KernelPanic("attempt to change flags mapping address\n");
            }
        }
    }

    PageTables.access(.level1, indices).* = value;

    ProcessorInvalidatePage(asked_virtual_address);

    return true;
}

export fn MMArchTranslateAddress(virtual_address: u64, write_access: bool) callconv(.C) u64
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

export fn MMArchHandlePageFault(fault_address: u64, flags: HandlePageFaultFlags) bool
{
    const virtual_address = fault_address & ~@as(u64, page_size - 1);
    const for_supervisor = flags.contains(.for_supervisor);

    if (!ProcessorAreInterruptsEnabled())
    {
        KernelPanic("Page fault with interrupts disabled\n");
    }

    const fault_in_very_low_memory = virtual_address < page_size;
    if (!fault_in_very_low_memory)
    {
        if (virtual_address >= low_memory_map_start and virtual_address < low_memory_map_start + low_memory_limit and for_supervisor)
        {
            const physical_address = virtual_address - low_memory_map_start;
            const map_page_flags = MapPageFlags.from_flag(.commit_tables_now);
          _ = MMArchMapPage(&_kernelMMSpace, physical_address, virtual_address, map_page_flags);
            return true;
        }
        else if (virtual_address >= core_memory_region_start and virtual_address < core_memory_region_start + core_memory_region_count * @sizeOf(Region) and for_supervisor)
        {
            const physical_allocation_flags = Physical.Flags.from_flag(.zeroed);
            const physical_address = MMPhysicalAllocateWithFlags(physical_allocation_flags);
            const map_page_flags = MapPageFlags.from_flag(.commit_tables_now);
            _ = MMArchMapPage(&_kernelMMSpace, physical_address, virtual_address, map_page_flags);
            return true;
        }
        else if (virtual_address >= core_address_space_start and virtual_address < core_address_space_start + core_address_space_size and for_supervisor)
        {
            return MMHandlePageFault(&_coreMMSpace, virtual_address, flags);
        }
        else if (virtual_address >= kernel_address_space_start and virtual_address < kernel_address_space_start + kernel_address_space_size and for_supervisor)
        {
            return MMHandlePageFault(&_kernelMMSpace, virtual_address, flags);
        }
        else if (virtual_address >= modules_start and virtual_address < modules_start + modules_size and for_supervisor)
        {
            return MMHandlePageFault(&_kernelMMSpace, virtual_address, flags);
        }
        else
        {
            // @Unsafe
            if (GetCurrentThread()) |current_thread|
            {
                const space = if (current_thread.temporary_address_space) |temporary_address_space| @ptrCast(*AddressSpace, temporary_address_space)
                else current_thread.process.?.address_space;
                return MMHandlePageFault(space, virtual_address, flags);
            }
            else
            {
                KernelPanic("unreachable path\n");
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
        KernelPanic("Context sanity check failed");
    }
}

export fn PostContextSwitch(context: *InterruptContext, old_address_space: *AddressSpace) callconv(.C) bool
{
    if (scheduler.dispatch_spinlock.interrupts_enabled.read_volatile()) KernelPanic ("Interrupts were enabled");

    scheduler.dispatch_spinlock.release_ex(true);

    const current_thread = GetCurrentThread().?;
    const local = GetLocalStorage().?;
    local.cpu.?.kernel_stack.* = current_thread.kernel_stack;

    const new_thread = current_thread.cpu_time_slices.read_volatile() == 1;
    LapicEndOfInterrupt();
    ContextSanityCheck(context);
    ProcessorSetThreadStorage(current_thread.tls_address);
    MMSpaceCloseReference(old_address_space);
    current_thread.last_known_execution_address = context.rip;

    if (ProcessorAreInterruptsEnabled()) KernelPanic("interrupts were enabled");

    if (local.spinlock_count != 0) KernelPanic("spinlock_count is not zero");

    current_thread.timer_adjust_ticks += ProcessorReadTimeStamp() - local.current_thread.?.last_interrupt_timestamp;

    if (current_thread.timer_adjust_address != 0 and MMArchIsBufferInUserRange(current_thread.timer_adjust_address, @sizeOf(u64)))
    {
        _ = MMArchSafeCopy(current_thread.timer_adjust_address, @ptrToInt(&local.current_thread.?.timer_adjust_ticks), @sizeOf(u64));
    }

    return new_thread;
}

extern fn MMArchSafeCopy(destination_address: u64, source_address: u64, byte_count: u64) callconv(.C) bool;

export fn AsyncTaskThread() callconv(.C) void
{
    const local = GetLocalStorage().?;

    while (true)
    {
        if (local.async_task_list.next_or_first) |first|
        {
            scheduler.async_task_spinlock.acquire();
            const item = first;
            const task = @fieldParentPtr(AsyncTask, "item", item);
            const callback = @intToPtr(?AsyncTask.Callback, task.callback) orelse unreachable;
            task.callback = 0;
            local.in_async_task = true;
            item.remove();
            scheduler.async_task_spinlock.release();
            callback(task);
            ThreadSetTemporaryAddressSpace(null);
            local.in_async_task = false;
        }
        else
        {
            ProcessorFakeTimerInterrupt();
        }
    }
}

export fn SetupProcessor2(storage: *NewProcessorStorage) callconv(.C) void
{
    for (acpi.LAPIC_NMIs[0..acpi.LAPIC_NMI_count]) |*nmi|
    {
        if (nmi.processor == 0xff or nmi.processor == storage.local.cpu.?.processor_ID)
        {
            const register_index = (0x350 + (@intCast(u32, nmi.lint_index) << 4)) >> 2;
            var value: u32 = 2 | (1 << 10);
            if (nmi.active_low) value |= 1 << 13;
            if (nmi.level_triggered) value |= 1 << 15;
            LapicWriteRegister(register_index, value);
        }
    }

    LapicWriteRegister(0x350 >> 2, LapicReadRegister(0x350 >> 2) & ~@as(u32, 1 << 16));
    LapicWriteRegister(0x360 >> 2, LapicReadRegister(0x360 >> 2) & ~@as(u32, 1 << 16));
    LapicWriteRegister(0x080 >> 2, 0);
    if (LapicReadRegister(0x30 >> 2) & 0x80000000 != 0) LapicWriteRegister(0x410 >> 2, 0);
    LapicEndOfInterrupt();

    LapicWriteRegister(0x3e0 >> 2, 2);
    ProcessorSetLocalStorage(storage.local);

    const gdt = storage.gdt;
    const bootstrap_GDT = @intToPtr(*align(1) u64, (@ptrToInt(&processorGDTR) + @sizeOf(u16))).*;
    EsMemoryCopy(gdt, bootstrap_GDT, 2048);
    const tss = gdt + 2048;
    storage.local.cpu.?.kernel_stack = @intToPtr(*align(1) u64, tss + @sizeOf(u32));
    ProcessorInstallTSS(gdt, tss);
}

export fn MMArchUnmapPages(space: *AddressSpace, virtual_address_start: u64, page_count: u64, flags: UnmapPagesFlags, unmap_maximum: u64, resume_position: ?*u64) callconv(.C) void
{
    _ = pmm.pageframe_mutex.acquire();
    defer pmm.pageframe_mutex.release();

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
            KernelPanic("page found without accessed or dirty bit set");
        }

        PageTables.access(.level1, indices).* = 0;
        const physical_address = translation & 0x0000FFFFFFFFF000;

        if (flags.contains(.free) or (flags.contains(.free_copied) and copy))
        {
            MMPhysicalFree(physical_address, true, 1);
        }
        else if (flags.contains(.balance_file))
        {
            _ = unmap_maximum;
            TODO();
        }
    }

    MMArchInvalidatePages(virtual_address_start, page_count);
}

export fn MMPhysicalFree(asked_page: u64, mutex_already_acquired: bool, count: u64) callconv(.C) void
{
    if (asked_page == 0) KernelPanic("invalid page");
    if (mutex_already_acquired) pmm.pageframe_mutex.assert_locked()
    else _ = pmm.pageframe_mutex.acquire();
    if (!pmm.pageframeDatabaseInitialised) KernelPanic("PMM not yet initialized");

    const page = asked_page >> page_bit_count;

    MMPhysicalInsertFreePagesStart();

    for (pmm.pageframes[0..count]) |*frame|
    {
        if (frame.state.read_volatile() == .free) KernelPanic("attempting to free a free page");
        if (pmm.commit_fixed_limit != 0) pmm.active_page_count -= 1;
        MMPhysicalInsertFreePagesNext(page);
    }

    MMPhysicalInsertFreePagesEnd();

    if (!mutex_already_acquired) pmm.pageframe_mutex.release();
}

export fn MMCheckUnusable(physical_start: u64, byte_count: u64) callconv(.C) void
{
    var i = physical_start / page_size;
    while (i < (physical_start + byte_count + page_size - 1) / page_size and i < pmm.pageframeDatabaseCount) : (i += 1)
    {
        if (pmm.pageframes[i].state.read_volatile() != .unusable) KernelPanic("Pageframe at address should be unusable");
    }
}

    const SyscallFn = fn (argument0: u64, argument1: u64, argument2: u64, argument3: u64, current_thread: *Thread, current_process: *Process, current_address_space: *AddressSpace, user_stack_pointer: ?*u64, fatal_error: *u8) callconv(.C) u64;

const SyscallType = enum(u32)
{
    exit = 0,
    batch = 1,
    const count = std.enums.values(SyscallType).len;
};
const syscall_functions = [SyscallType.count + 1]SyscallFn
{
    syscall_process_exit,
    undefined,
    undefined,
};


export fn DoSyscall(index: SyscallType, argument0: u64, argument1: u64, argument2: u64, argument3: u64, batched: bool, fatal: ?*bool, user_stack_pointer: ?*u64) callconv(.C) u64
{
    ProcessorEnableInterrupts();

    const current_thread = GetCurrentThread().?;
    const current_process = current_thread.process.?;
    const current_address_space = current_process.address_space;

    if (!batched)
    {
        if (current_thread.terminating.read_volatile())
        {
            ProcessorFakeTimerInterrupt();
        }

        if (current_thread.terminatable_state.read_volatile() != .terminatable) KernelPanic("Current thread was not terminatable");

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
            ProcessCrash(current_process, &reason);
        }
    }

    if (!batched)
    {
        current_thread.terminatable_state.write_volatile(.terminatable);
        if (current_thread.terminating.read_volatile() or current_thread.paused.read_volatile())
        {
            ProcessorFakeTimerInterrupt();
        }
    }

    return return_value;
}

export fn Syscall(argument0: u64, argument1: u64, argument2: u64, return_address: u64, argument3: u64, argument4: u64, user_stack_pointer: ?*u64) callconv(.C) u64
{
    _ = return_address;
    return DoSyscall(@intToEnum(SyscallType, argument0), argument1, argument2, argument3, argument4, false, null, user_stack_pointer);
}

export fn process_exit(process: *Process, status: i32) callconv(.C) void
{
    _ = process.threads_mutex.acquire();

    process.exit_status = status;
    process.prevent_new_threads = true;

    const current_thread = GetCurrentThread().?;
    const is_current_process = process == current_thread.process;
    var found_current_thread = false;
    var maybe_thread_item = process.threads.first;

    while (maybe_thread_item) |thread_item|
    {
        const thread = thread_item.value.?;
        maybe_thread_item = thread_item.next;

        if (thread != current_thread)
        {
            thread_exit(thread);
        }
        else if (is_current_process)
        {
            found_current_thread = true;
        }
        else
        {
            KernelPanic("found current thread in the wrong process");
        }
    }

    process.threads_mutex.release();

    if (!found_current_thread and is_current_process) KernelPanic("could not find current thread in the current process")
    else if (is_current_process)
    {
        thread_exit(current_thread);
    }
}

//extern fn syscall_process_exit (argument0: u64, argument1: u64, argument2: u64, argument3: u64, current_thread: *Thread, current_process: *Process, current_address_space: *AddressSpace, user_stack_pointer: ?*u64, fatal_error: ?*bool) callconv(.C) u64;
export fn syscall_process_exit(argument0: u64, argument1: u64, argument2: u64, argument3: u64, current_thread: *Thread, current_process: *Process, current_address_space: *AddressSpace, user_stack_pointer: ?*u64, fatal_error: *u8) callconv(.C) u64
{
    _ = argument2;
    _ = argument3;
    _ = current_thread;
    _ = current_address_space;
    _ = user_stack_pointer;

    var self = false;

    {
        var process_out: Handle = undefined;
        const status = current_process.handle_table.resolve_handle(&process_out, argument0, @enumToInt(KernelObjectType.process));
        if (status == .failed)
        {
            fatal_error.* = @enumToInt(FatalError.invalid_handle);
            return @boolToInt(true);
        }

        defer if (status == .normal) CloseHandleToObject(process_out.object, process_out.type, process_out.flags);
        const process = @intToPtr(*Process, process_out.object);
        if (process == current_process) self = true
        else process_exit(process, @intCast(i32, argument1));
    }

    if (self) process_exit(current_process, @intCast(i32, argument1));

    // @AIDS
    fatal_error.* = @bitCast(u8, @intCast(i8, ES_SUCCESS));
    return @boolToInt(false);
}

const ResolveHandleStatus = enum(u8)
{
    failed = 0,
    no_close = 1,
    normal = 2,
};


export fn KernelInitialise() callconv(.C) void
{
    kernelProcess = &_kernelProcess;
    kernelProcess = ProcessSpawn(.kernel).?;
    MMInitialise();
    // Currently it felt impossible to pass arguments to this function
    CreateMainThread();
    ArchInitialise();
    scheduler.started.write_volatile(true);
}

export fn KernelMain(_: u64) callconv(.C) void
{
    desktopProcess = ProcessSpawn(.desktop).?;
    drivers_init();

    start_desktop_process();
    _ = shutdownEvent.wait();
}

fn arch_pci_read_config32(bus: u8, device: u8, function: u8, offset: u8) u32
{
    return arch_pci_read_config(bus, device, function, offset, 32);
}

fn arch_pci_read_config(bus: u8, device: u8, function: u8, offset: u8, size: u32) u32
{
    pciConfigSpinlock.acquire();
    defer pciConfigSpinlock.release();

    if (offset & 3 != 0) KernelPanic("offset is not 4-byte aligned");
    ProcessorOut32(IO_PCI_CONFIG, 0x80000000 | (@intCast(u32, bus) << 16) | (@intCast(u32, device) << 11) | (@intCast(u32, function) << 8) | @intCast(u32, offset));
    if (size == 8) return ProcessorIn8(IO_PCI_DATA);
    if (size == 16) return ProcessorIn16(IO_PCI_DATA);
    if (size == 32) return ProcessorIn32(IO_PCI_DATA);
    KernelPanic("invalid size");
}

fn arch_pci_write_config(bus: u8, device: u8, function: u8, offset: u8, value: u32, size: u32) void
{
    pciConfigSpinlock.acquire();
    defer pciConfigSpinlock.release();

    if (offset & 3 != 0) KernelPanic("offset is not 4-byte aligned");
    ProcessorOut32(IO_PCI_CONFIG, 0x80000000 | (@intCast(u32, bus) << 16) | (@intCast(u32, device) << 11) | (@intCast(u32, function) << 8) | @intCast(u32, offset));
    if (size == 8) ProcessorOut8(IO_PCI_DATA, @intCast(u8, value))
    else if (size == 16) ProcessorOut16(IO_PCI_DATA, @intCast(u16, value))
    else if (size == 32) ProcessorOut32(IO_PCI_DATA, value)
    else KernelPanic("Invalid size\n");
}

var module_ptr: u64 = modules_start;

const PCI = struct
{
    const Driver = struct
    {
        devices: []Device,
        bus_scan_states: [256]u8,

        fn init() void
        {
            const devices_offset = round_up(u64, @sizeOf(Driver), @alignOf(PCI.Device));
            const allocation_size = devices_offset + (@sizeOf(PCI.Device) * PCI.Device.max_count);
            const address = MMStandardAllocate(&_kernelMMSpace, allocation_size, Region.Flags.from_flag(.fixed), module_ptr, true);
            if (address == 0) KernelPanic("Could not allocate memory for PCI driver");
            module_ptr += round_up(u64, allocation_size, page_size);

            driver = @intToPtr(*PCI.Driver, address);
            driver.devices.ptr = @intToPtr([*]PCI.Device, address + devices_offset);
            driver.devices.len = 0;
            driver.setup();
        }

        fn setup(self: *@This()) void
        {
            const base_header_type = arch_pci_read_config32(0, 0, 0, 0x0c);
            const base_bus_count: u8 = if (base_header_type & 0x80 != 0) 8 else 1;
            var bus_to_scan_count: u8 = 0;

            var base_bus: u8 = 0;
            while (base_bus < base_bus_count) : (base_bus += 1)
            {
                const device_id = arch_pci_read_config32(0, 0, base_bus, 0);
                if (device_id & 0xffff != 0xffff)
                {
                    self.bus_scan_states[base_bus] = @enumToInt(Bus.scan_next);
                    bus_to_scan_count += 1;
                }
            }

            if (bus_to_scan_count == 0) KernelPanic("No bus found");

            var found_usb = false;

            while (bus_to_scan_count > 0)
            {
                for (self.bus_scan_states) |*bus_scan_state, _bus|
                {
                    const bus = @intCast(u8, _bus);
                    if (bus_scan_state.* == @enumToInt(Bus.scan_next))
                    {
                        bus_scan_state.* = @enumToInt(Bus.scanned);
                        bus_to_scan_count -= 1;

                        var device: u8 = 0;
                        while (device < 32) : (device += 1)
                        {
                            const _device_id = arch_pci_read_config32(bus, device, 0, 0);
                            if (_device_id & 0xffff != 0xffff)
                            {
                                const header_type = @truncate(u8, arch_pci_read_config32(bus, device, 0, 0x0c) >> 16);
                                const function_count: u8 = if (header_type & 0x80 != 0) 8 else 1;

                                var function: u8 = 0;
                                while (function < function_count) : (function += 1)
                                {
                                    const device_id = arch_pci_read_config32(bus, device, function, 0);
                                    if (device_id & 0xffff != 0xffff)
                                    {
                                        const device_class = arch_pci_read_config32(bus, device, function, 0x08);
                                        const interrupt_information = arch_pci_read_config32(bus, device, function, 0x3c);
                                        const index = self.devices.len;
                                        self.devices.len += 1;

                                        const pci_device = &self.devices[index];
                                        pci_device.class_code = @truncate(u8, device_class >> 24);
                                        pci_device.subclass_code = @truncate(u8, device_class >> 16);
                                        pci_device.prog_IF = @truncate(u8, device_class >> 8);
                                        pci_device.bus = bus;
                                        pci_device.slot = device;
                                        pci_device.function = function;
                                        pci_device.interrupt_pin = @truncate(u8, interrupt_information >> 8);
                                        pci_device.interrupt_line = @truncate(u8, interrupt_information >> 0);
                                        pci_device.device_ID = arch_pci_read_config32(bus, device, function, 0);
                                        pci_device.subsystem_ID = arch_pci_read_config32(bus, device, function, 0x2c);

                                        for (pci_device.base_addresses) |*base_address, i|
                                        {
                                            base_address.* = pci_device.read_config_32(@intCast(u8, 0x10 + 4 * i));
                                        }

                                        const is_pci_bridge = pci_device.class_code == 0x06 and pci_device.subclass_code == 0x04;
                                        if (is_pci_bridge)
                                        {
                                            const secondary_bus = @truncate(u8, arch_pci_read_config32(bus, device, function, 0x18) >> 8);
                                            if (self.bus_scan_states[secondary_bus] == @enumToInt(Bus.do_not_scan))
                                            {
                                                bus_to_scan_count += 1;
                                                self.bus_scan_states[secondary_bus] = @enumToInt(Bus.scan_next);
                                            }
                                        }

                                        const is_usb = pci_device.class_code == 12 and pci_device.subclass_code == 3;
                                        if (is_usb) found_usb = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    };

    const Device = extern struct
    {
        device_ID: u32,
        subsystem_ID: u32,
        domain: u32,
        class_code: u8,
        subclass_code: u8,
        prog_IF: u8,
        bus: u8,
        slot: u8,
        function: u8,
        interrupt_pin: u8,
        interrupt_line: u8,
        base_addresses_virtual: [6]u64,
        base_addresses_physical: [6]u64,
        base_addresses_sizes: [6]u64,
        
        base_addresses: [6]u32,

        const max_count = 64;

        fn read_config_8(self: @This(), offset: u8) u8
        {
            return @truncate(u8, arch_pci_read_config(self.bus, self.slot, self.function, offset, 8));
        }

        fn read_config_16(self: @This(), offset: u8) u16
        {
            return @truncate(u16, arch_pci_read_config(self.bus, self.slot, self.function, offset, 16));
        }

        fn write_config_16(self: @This(), offset: u8, value: u16) void
        {
            arch_pci_write_config(self.bus, self.slot, self.function, offset, value, 16);
        }

        fn read_config_32(self: @This(), offset: u8) u32
        {
            return arch_pci_read_config(self.bus, self.slot, self.function, offset, 32);
        }

        fn write_config_32(self: @This(), offset: u8, value: u32) void
        {
            arch_pci_write_config(self.bus, self.slot, self.function, offset, value, 32);
        }

        fn enable_features(self: *@This(), features: Features) bool
        {
            var config = self.read_config_32(4);
            if (features.contains(.interrupts)) config &= ~(@as(u32, 1) << 10);
            if (features.contains(.busmastering_DMA)) config |= 1 << 2;
            if (features.contains(.memory_space_access)) config |= 1 << 1;
            if (features.contains(.io_port_access)) config |= 1 << 0;
            self.write_config_32(4, config);

            assert(self.read_config_32(4) == config);
            if (self.read_config_32(4) != config) return false;

            var i: u8 = 0;
            while (i < 6) : (i += 1)
            {
                if (~features.bits & (@as(u32, 1) << @intCast(u5, i)) != 0) continue;
                const bar_is_io_port = self.base_addresses[i] & 1 != 0;
                if (bar_is_io_port) continue;
                const size_is_64 = self.base_addresses[i] & 4 != 0;
                if (self.base_addresses[i] & 8 == 0) 
                {
                    // TODO
                }

                var address: u64 = undefined;
                var size: u64 = undefined;

                if (size_is_64)
                {
                    self.write_config_32(0x10 + 4 * i, 0xffffffff);
                    self.write_config_32(0x10 + 4 * (i + 1), 0xffffffff);
                    size = self.read_config_32(0x10 + 4 * i);
                    size |= @intCast(u64, self.read_config_32(0x10 + 4 * (i + 1))) << 32;
                    self.write_config_32(0x10 + 4 * i, self.base_addresses[i]);
                    self.write_config_32(0x10 + 4 * (i + 1), self.base_addresses[i + 1]);
                    address = self.base_addresses[i];
                    address |= @intCast(u64, self.base_addresses[i + 1]) << 32;
                }
                else
                {
                    self.write_config_32(0x10 + 4 * i, 0xffffffff);
                    size = self.read_config_32(0x10 + 4 * i);
                    size |= @intCast(u64, 0xffffffff) << 32;
                    self.write_config_32(0x10 + 4 * i, self.base_addresses[i]);
                    address = self.base_addresses[i];
                }

                if (size == 0) return false;
                if (address == 0) return false;

                size &= ~@as(@TypeOf(size), 0xf);
                size = ~size + 1;
                address &= ~@as(@TypeOf(address), 0xf);

                self.base_addresses_virtual[i] = MMMapPhysical(&_kernelMMSpace, address, size, Region.Flags.from_flag(.not_cacheable));
                assert(address != 0);
                assert(self.base_addresses_virtual[i] != 0);
                self.base_addresses_physical[i] = address;
                self.base_addresses_sizes[i] = size;
                MMCheckUnusable(address, size);
            }

            return true;
        }

        fn read_bar_8(self: @This(), index: u32, offset: u32) u8
        {
            const base_address = self.base_addresses[index];
                if (base_address & 1 != 0) return ProcessorIn8(@intCast(u16, (base_address & ~@as(u32, 3)) + offset))
                else return @intToPtr(*volatile u8, self.base_addresses_virtual[index] + offset).*;
        }

        fn read_bar32(self: @This(), index: u32, offset: u32) u32
        {
            const base_address = self.base_addresses[index];
            return
                if (base_address & 1 != 0)
                    ProcessorIn32(@intCast(u16, (base_address & ~@as(u32, 3)) + offset))
                else
                    @intToPtr(*volatile u32, self.base_addresses_virtual[index] + offset).*;
        }

        fn write_bar32(self: @This(), index: u32, offset: u32, value: u32) void
        {
            const base_address = self.base_addresses[index];
            if (base_address & 1 != 0)
            {
                ProcessorOut32(@intCast(u16, (base_address & ~@as(u32, 3)) + offset), value);
            }
            else
            {
                @intToPtr(*volatile u32, self.base_addresses_virtual[index] + offset).* = value;
            }
        }

        fn enable_single_interrupt(self: *@This(), handler: KIRQHandler, context: u64, owner_name: []const u8) bool
        {
            assert(@ptrToInt(handler) != 0);

            if (self.enable_MSI(handler, context, owner_name)) return true;
            if (self.interrupt_pin == 0) return false;
            if (self.interrupt_pin > 4) return false;

            const result = self.enable_features(Features.from_flag(.interrupts));
            assert(result);

            var line = @intCast(i64, self.interrupt_line);
            if (bootloader_ID == 2) line = -1;

            TODO();
        }

        fn enable_MSI(self: *@This(), handler: KIRQHandler, context: u64, owner_name: []const u8) bool
        {
            assert(@ptrToInt(handler) != 0);

            const status = @truncate(u16, self.read_config_32(0x04) >> 16);
            if (~status & (1 << 4) != 0) return false;

            var pointer = self.read_config_8(0x34);
            var index: u64 = 0;

            while (true)
            {
                if (pointer == 0) break;
                const _index = index;
                index += 1;
                if (_index >= 0xff) break;

                var dw = self.read_config_32(pointer);
                const next_pointer = @truncate(u8, dw >> 8);
                const id = @truncate(u8, dw);

                if (id != 5)
                {
                    pointer = next_pointer;
                    continue;
                }

                const msi = MSI.register(handler, context, owner_name);

                if (msi.address == 0) return false;
                var control = @truncate(u16, dw >> 16);

                if (msi.data & ~@as(u64, 0xffff) != 0)
                {
                    MSI.unregister(msi.tag);
                    return false;
                }

                if (msi.address & 0b11 != 0)
                {
                    MSI.unregister(msi.tag);
                    return false;
                }
                if (msi.address & 0xFFFFFFFF00000000 != 0 and ~control & (1 << 7) != 0)
                {
                    MSI.unregister(msi.tag);
                    return false;
                }

                control = (control & ~@as(u16, 7 << 4)) | (1 << 0);
                dw = @truncate(u16, dw) | (@as(u32, control) << 16);

                self.write_config_32(pointer + 0, dw);
                self.write_config_32(pointer + 4, @truncate(u32, msi.address));

                if (control & (1 << 7) != 0)
                {
                    self.write_config_32(pointer + 8, @truncate(u32, msi.address >> 32));
                    self.write_config_16(pointer + 12, @intCast(u16, (self.read_config_16(pointer + 12) & 0x3800) | msi.data));
                    if (control & (1 << 8) != 0) self.write_config_32(pointer + 16, 0);
                }
                else
                {
                    self.write_config_16(pointer + 8, @intCast(u16, msi.data));
                    if (control & (1 << 8) != 0) self.write_config_32(pointer + 12, 0);
                }

                return true;
            }

            return false;
        }
    };

    const Bus = enum(u8)
    {
        do_not_scan = 0,
        scan_next = 1,
        scanned = 2,
    };

    const Features = Bitflag(enum(u64)
    {
        bar_0 = 0,
        bar_1 = 1,
        bar_2 = 2,
        bar_3 = 3,
        bar_4 = 4,
        bar_5 = 5,
        interrupts = 8,
        busmastering_DMA = 9,
        memory_space_access = 10,
        io_port_access = 11,
    });

    var driver: *Driver = undefined;
};

const MSI = extern struct
{
    address: u64,
    data: u64,
    tag: u64,

    fn register(handler: KIRQHandler, context: u64, owner_name: []const u8) @This()
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

    fn unregister(tag: u64) void
    {
        irqHandlersLock.acquire();
        defer irqHandlersLock.release();
        msiHandlers[tag].callback = null;
    }
};

const Workgroup = extern struct
{
    remaining: Volatile(u64),
    success: Volatile(u64),
    event: Event,

    fn init(self: *@This()) void
    {
        self.remaining.write_volatile(1);
        self.success.write_volatile(1);
        self.event.reset();
    }

    fn wait(self: *@This()) bool
    {
        if (self.remaining.atomic_fetch_sub(1) != 1) _ = self.event.wait();
        if (self.remaining.read_volatile() != 0) KernelPanic("Expected remaining operations to be 0 after event set");

        return self.success.read_volatile() != 0;
    }

    fn start(self: *@This()) void
    {
        if (self.remaining.atomic_fetch_add(1) == 0) KernelPanic("Could not start operation on completed dispatch group");
    }

    fn end(self: *@This(), success: bool) void
    {
        if (!success)
        {
            self.success.write_volatile(0);
            @fence(.SeqCst);
        }

        if (self.remaining.atomic_fetch_sub(1) == 1) _ = self.event.set(false);
    }
};

export var recent_interrupt_events_pointer: Volatile(u64) = undefined;
export var recent_interrupt_events: [64]Volatile(InterruptEvent) = undefined;

const AHCI = struct
{
    fn GlobalRegister(comptime offset: u32) type
    {
        return struct
        {
            fn write(d: *AHCI.Driver, value: u32) void
            {
                d.pci.write_bar32(5, offset, value);
            }

            fn read(d: *AHCI.Driver) u32
            {
                return d.pci.read_bar32(5, offset);
            }
        };
    }

    fn PortRegister(comptime offset: u32) type
    {
        return struct
        {
            fn write(d: *AHCI.Driver, port: u32, value: u32) void
            {
                d.pci.write_bar32(5, offset + port * 0x80, value);
            }

            fn read(d: *AHCI.Driver, port: u32) u32
            {
                return d.pci.read_bar32(5, offset + port * 0x80);
            }
        };
    }

    const CAP = GlobalRegister(0);
    const GHC = GlobalRegister(4);
    const IS = GlobalRegister(8);
    const PI = GlobalRegister(0xc);
    const CAP2 = GlobalRegister(0x24);
    const BOHC = GlobalRegister(0x28);

    const PCLB = PortRegister(0x100);
    const PCLBU = PortRegister(0x104);
    const PFB = PortRegister(0x108);
    const PFBU = PortRegister(0x10c);
    const PIS = PortRegister(0x110);
    const PIE = PortRegister(0x114);
    const PCMD = PortRegister(0x118);
    const PTFD = PortRegister(0x120);
    const PSIG = PortRegister(0x124);
    const PSSTS = PortRegister(0x128);
    const PSCTL = PortRegister(0x12c);
    const PSERR = PortRegister(0x130);
    const PCI_register = PortRegister(0x138);

    const general_timeout = 5000;
    const command_list_size = 0x400;
    const received_FIS_size = 0x100;
    const PRDT_entry_count = 0x48;
    const command_table_size = 0x80 + PRDT_entry_count * 0x10;

    const Driver = struct
    {
        pci: *PCI.Device,
        drives: []AHCI.Drive,
        mbr_partitions: [4]MBR.Partition,
        mbr_partition_count: u64,
        partition_devices: []PartitionDevice,
        capabilities: u32,
        capabilities2: u32,
        command_slot_count: u64,
        timeout_timer: Timer,
        dma64_supported: bool,
        ports: [max_port_count]Port,

        const Port = extern struct
        {
            connected: bool,
            atapi: bool,
            ssd: bool,

            command_list: [*]u32,
            command_tables: [*]u8,
            sector_byte_count: u64,
            sector_count: u64,

            command_contexts: [32]?*Workgroup,
            command_start_timestamps: [32]u64,
            running_commands: u32,

            command_spinlock: Spinlock,
            command_slots_available_event: Event,

            model: [41]u8,
        };

        const max_port_count = 32;
        const class_code = 1;
        const subclass_code = 6;
        const prog_IF = 1;

        fn init() void
        {
            const drives_offset = round_up(u64, @sizeOf(Driver), @alignOf(AHCI.Drive));
            const partition_devices_offset = round_up(u64, drives_offset + (@sizeOf(AHCI.Drive) * AHCI.Drive.max_count), @alignOf(PartitionDevice));
            const allocation_size = partition_devices_offset + (@sizeOf(PartitionDevice) * PartitionDevice.max_count);
            const address = MMStandardAllocate(&_kernelMMSpace, allocation_size, Region.Flags.from_flag(.fixed), module_ptr, true);
            if (address == 0) KernelPanic("Could not allocate memory for PCI driver");
            module_ptr += round_up(u64, allocation_size, page_size);
            driver = @intToPtr(*AHCI.Driver, address);
            driver.drives.ptr = @intToPtr([*]AHCI.Drive, address + drives_offset);
            driver.drives.len = 0;
            driver.partition_devices.ptr = @intToPtr([*]PartitionDevice, address + partition_devices_offset);
            driver.partition_devices.len = 0;
            driver.setup();
        }

        fn setup(self: *@This()) void
        {
            self.pci = &PCI.driver.devices[3];

            const is_ahci_pci_device = self.pci.class_code == class_code and self.pci.subclass_code == subclass_code and self.pci.prog_IF == prog_IF;

            if (!is_ahci_pci_device) KernelPanic("AHCI PCI device not found");

            _ = self.pci.enable_features(PCI.Features.from_flags(.{ .interrupts, .busmastering_DMA, .memory_space_access, .bar_5 }));

            if (CAP2.read(self) & (1 << 0) != 0)
            {
                BOHC.write(self, BOHC.read(self) | (1 << 1));
                const timeout = Timeout.new(25);
                var status: u32 = undefined;

                while (true)
                {
                    status = BOHC.read(self);
                    if (status & (1 << 0) != 0) break;
                    if (timeout.hit()) break;
                }

                if (status & (1 << 0) != 0)
                {
                    var event = zeroes(Event);
                    _ = event.wait_extended(2000);
                }
            }

            {
                const timeout = Timeout.new(AHCI.general_timeout);
                GHC.write(self, GHC.read(self) | (1 << 0));
                while (GHC.read(self) & (1 << 0) != 0 and !timeout.hit())
                {
                }

                // error
                if (timeout.hit()) KernelPanic("AHCI timeout hit");
            }

            assert(@ptrToInt(handler) != 0);
            if (!self.pci.enable_single_interrupt(handler, @ptrToInt(self), "AHCI")) KernelPanic("Unable to initialize AHCI");

            GHC.write(self, GHC.read(self) | (1 << 31) | (1 << 1));
            self.capabilities = CAP.read(self);
            self.capabilities2 = CAP2.read(self);
            self.command_slot_count = ((self.capabilities >> 8) & 31) + 1;
            self.dma64_supported = self.capabilities & (1 << 31) != 0;
            if (!self.dma64_supported) KernelPanic("DMA is not supported");

            const maximum_number_of_ports = (self.capabilities & 31) + 1;
            var found_port_count: u64 = 0;
            const implemented_ports = PI.read(self);

            for (self.ports) |*port, i|
            {
                if (implemented_ports & (@as(u32, 1) << @intCast(u5, i)) != 0)
                {
                    found_port_count += 1;
                    if (found_port_count <= maximum_number_of_ports) port.connected = true;
                }
            }

            for (self.ports) |*port, _port_i|
            {
                if (port.connected)
                {
                    const port_i = @intCast(u32, _port_i);
                    const needed_byte_count = command_list_size + received_FIS_size + command_table_size * self.command_slot_count;

                    var virtual_address: u64 = 0;
                    var physical_address: u64 = 0;

                    if (!MMPhysicalAllocateAndMap(needed_byte_count, page_size, if (self.dma64_supported) 64 else 32, true, Region.Flags.from_flag(.not_cacheable), &virtual_address, &physical_address))
                    {
                        KernelPanic("AHCI allocation failure");
                    }

                    port.command_list = @intToPtr([*]u32, virtual_address);
                    port.command_tables = @intToPtr([*]u8, virtual_address + command_list_size + received_FIS_size);

                    PCLB.write(self, port_i, @truncate(u32, physical_address));
                    PFB.write(self, port_i, @truncate(u32, physical_address + 0x400));
                    if (self.dma64_supported)
                    {
                        PCLBU.write(self, port_i, @truncate(u32, physical_address >> 32));
                        PFBU.write(self, port_i, @truncate(u32, (physical_address + 0x400) >> 32));
                    }

                    var command_slot: u64 = 0;
                    while (command_slot < self.command_slot_count) : (command_slot += 1)
                    {
                        const address = physical_address + command_list_size + received_FIS_size + command_table_size * command_slot;
                        port.command_list[command_slot * 8 + 2] = @truncate(u32, address);
                        port.command_list[command_slot * 8 + 3] = @truncate(u32, address >> 32);
                    }

                    const timeout = Timeout.new(general_timeout);
                    const running_bits = (1 << 0) | (1 << 4) | (1 << 15) | (1 << 14);

                    while (true)
                    {
                        const status = PCMD.read(self, port_i);
                        if (status & running_bits == 0 or timeout.hit()) break;
                        PCMD.write(self, port_i, status & ~@as(u32, (1 << 0) | (1 << 4)));
                    }

                    const reset_port_timeout = PCMD.read(self, port_i) & running_bits != 0;
                    if (reset_port_timeout)
                    {
                        port.connected = false;
                        continue;
                    }

                    PIE.write(self, port_i, PIE.read(self, port_i) & 0x0e3fff0);
                    PIS.write(self, port_i, PIS.read(self, port_i));

                    PSCTL.write(self, port_i, PSCTL.read(self, port_i) | (3 << 8));
                    PCMD.write(self, port_i,
                        (PCMD.read(self, port_i) & 0x0FFFFFFF) |
                        (1 << 1) |
                        (1 << 2) |
                        (1 << 4) |
                        (1 << 28));

                    var link_timeout = Timeout.new(10);

                    while (PSSTS.read(self, port_i) & 0xf != 3 and !link_timeout.hit()) { }
                    const activate_port_timeout = PSSTS.read(self, port_i) & 0xf != 3;
                    if (activate_port_timeout)
                    {
                        port.connected = false;
                        continue;
                    }

                    PSERR.write(self, port_i, PSERR.read(self, port_i));

                    while (PTFD.read(self, port_i) & 0x88 != 0 and !timeout.hit()) { }
                    const port_ready_timeout = PTFD.read(self, port_i) & 0x88 != 0;
                    if (port_ready_timeout)
                    {
                        port.connected = false;
                        continue;
                    }

                    PCMD.write(self, port_i, PCMD.read(self, port_i) | (1 << 0));
                    PIE.write(self, port_i,
                        PIE.read(self, port_i) |
                        (1 << 5) |
                        (1 << 0) |
                        (1 << 30) |
                        (1 << 29) |
                        (1 << 28) |
                        (1 << 27) |
                        (1 << 26) |
                        (1 << 24) |
                        (1 << 23));
                }
            }

            for (self.ports) |*port, _port_i|
            {
                if (port.connected)
                {
                    const port_i = @intCast(u32, _port_i);

                    const status = PSSTS.read(self, port_i);

                    if (status & 0xf != 0x3 or status & 0xf0 == 0 or status & 0xf00 != 0x100)
                    {
                        port.connected = false;
                        continue;
                    }

                    const signature = PSIG.read(self, port_i);

                    if (signature == 0x00000101)
                    {
                        // SATA drive
                    }
                    else if (signature == 0xEB140101)
                    {
                        // SATAPI drive
                        port.atapi = true;
                    }
                    else if (signature == 0)
                    {
                        // no drive connected
                        port.connected = false;
                    }
                    else
                    {
                        // unrecognized drive signature
                        port.connected = false;
                    }
                }
            }

            var identify_data: u64 = 0;
            var identify_data_physical: u64 = 0;
            if (!MMPhysicalAllocateAndMap(0x200, page_size, if (self.dma64_supported) 64 else 32, true, Region.Flags.from_flag(.not_cacheable), &identify_data, &identify_data_physical))
            {
                KernelPanic("Allocation failure");
            }

            for (self.ports) |*port, _port_i|
            {
                if (port.connected)
                {
                    const port_i = @intCast(u32, _port_i);
                    EsMemoryZero(identify_data, 0x200);

                    port.command_list[0] = 5 | (1 << 16);
                    port.command_list[1] = 0;

                    const opcode: u32 = if (port.atapi) 0xa1 else 0xec;
                    const command_FIS = @ptrCast([*]u32, @alignCast(4, port.command_tables));
                    command_FIS[0] = 0x27 | (1 << 15) | (opcode << 16);
                    command_FIS[1] = 0;
                    command_FIS[2] = 0;
                    command_FIS[3] = 0;
                    command_FIS[4] = 0;

                    const prdt = @intToPtr([*]u32, @ptrToInt(port.command_tables) + 0x80);
                    prdt[0] = @truncate(u32, identify_data_physical);
                    prdt[1] = @truncate(u32, identify_data_physical >> 32);
                    prdt[2] = 0;
                    prdt[3] = 0x200 - 1;

                    if (!self.send_single_command(port_i))
                    {
                        PCMD.write(self, port_i, PCMD.read(self, port_i) & ~@as(u32, 1 << 0));
                        port.connected = false;
                        continue;
                    }

                    port.sector_byte_count = 0x200;

                    const identify_ptr = @intToPtr([*]u16, identify_data);
                    if (identify_ptr[106] & (1 << 14) != 0 and ~identify_ptr[106] & (1 << 15) != 0 and identify_ptr[106] & (1 << 12) != 0)
                    {
                        port.sector_byte_count = identify_ptr[117] | (@intCast(u32, identify_ptr[118]) << 16);
                    }

                    port.sector_count = identify_ptr[100] + (@intCast(u64, identify_ptr[101]) << 16) + (@intCast(u64, identify_ptr[102]) << 32) + (@intCast(u64, identify_ptr[103]) << 48);

                    if (!(identify_ptr[49] & (1 << 9) != 0 and identify_ptr[49] & (1 << 8) != 0))
                    {
                        port.connected = false;
                        continue;
                    }

                    if (port.atapi)
                    {
                        port.command_list[0] = 5 | (1 << 16) | (1 << 5);
                        command_FIS[0] = 0x27 | (1 << 15) | (0xa0 << 16);
                        command_FIS[1] = 8 << 8;
                        prdt[3] = 8 - 1;

                        const scsi_command = @ptrCast([*]u8, command_FIS);
                        EsMemoryZero(@ptrToInt(scsi_command), 10);
                        scsi_command[0] = 0x25;

                        if (!self.send_single_command(port_i))
                        {
                            PCMD.write(self, port_i, PCMD.read(self, port_i) & ~@as(u32, 1 << 0));
                            port.connected = false;
                            continue;
                        }

                        const capacity = @intToPtr([*]u8, identify_data);
                        port.sector_count = capacity[3] + (@intCast(u64, capacity[2]) << 8) + (@intCast(u64, capacity[1]) << 16) + (@intCast(u64, capacity[0]) << 24) + 1;
                        port.sector_byte_count = capacity[7] + (@intCast(u64, capacity[6]) << 8) + (@intCast(u64, capacity[5]) << 16) + (@intCast(u64, capacity[4]) << 24);
                    }

                    if (port.sector_count <= 128 or port.sector_byte_count & 0x1ff != 0 or port.sector_byte_count == 0 or port.sector_byte_count > 0x1000)
                    {
                        port.connected = false;
                        continue;
                    }

                    var model: u64 = 0;
                    while (model < 20) : (model += 1)
                    {
                        port.model[model * 2 + 0] = @truncate(u8, identify_ptr[27 + model] >> 8);
                        port.model[model * 2 + 1] = @truncate(u8, identify_ptr[27 + model]);
                    }
                    
                    port.model[40] = 0;

                    model = 39;

                    while (model > 0) : (model -= 1)
                    {
                        if (port.model[model] == ' ') port.model[model] = 0
                        else break;
                    }

                    port.ssd = identify_ptr[217] == 1;

                    var i: u64 = 10;
                    while (i < 20) : (i += 1)
                    {
                        identify_ptr[i] = (identify_ptr[i] >> 8) | (identify_ptr[i] << 8);
                    }

                    i = 23;
                    while (i < 27) : (i += 1)
                    {
                        identify_ptr[i] = (identify_ptr[i] >> 8) | (identify_ptr[i] << 8);
                    }

                    i = 27;
                    while (i < 47) : (i += 1)
                    {
                        identify_ptr[i] = (identify_ptr[i] >> 8) | (identify_ptr[i] << 8);
                    }
                }
            }


            _ = MMFree(&_kernelMMSpace, identify_data, 0, false);
            MMPhysicalFree(identify_data_physical, false, 1);

            self.timeout_timer.set_extended(general_timeout, TimeoutTimerHit, @ptrToInt(self));

            for (self.ports) |*port, _port_i|
            {
                if (port.connected)
                {
                    const port_i = @intCast(u32, _port_i);
                    const drive_index = self.drives.len;
                    self.drives.len += 1;
                    const drive = &self.drives[drive_index];
                    drive.port = port_i;
                    drive.block_device.sector_size = port.sector_byte_count;
                    drive.block_device.sector_count = port.sector_count;
                    drive.block_device.max_access_sector_count = if (port.atapi) (65535 / drive.block_device.sector_size) else (PRDT_entry_count - 1) * page_size / drive.block_device.sector_size;
                    drive.block_device.read_only = port.atapi;
                    comptime assert(port.model.len <= drive.block_device.model.len);
                    std.mem.copy(u8, drive.block_device.model[0..port.model.len], port.model[0..]);
                    drive.block_device.model_bytes = port.model.len;
                    drive.block_device.drive_type = if (port.atapi) DriveType.cdrom else if (port.ssd) DriveType.ssd else DriveType.hdd;
                    
                    drive.block_device.access = @ptrToInt(access_callback);
                    drive.block_device.register_filesystem();
                }
            }
        }

        fn access_callback(request: BlockDevice.AccessRequest) Error
        {
            const drive = @ptrCast(*AHCI.Drive, request.device);
            request.dispatch_group.?.start();

            if (!AHCI.driver.access(drive.port, request.offset, request.count, request.operation, request.buffer, request.flags, request.dispatch_group))
            {
                request.dispatch_group.?.end(false);
            }

            return ES_SUCCESS;
        }

        fn handle_IRQ(self: *@This()) bool
        {
            const global_interrupt_status = IS.read(self);
            if (global_interrupt_status == 0) return false;
            IS.write(self, global_interrupt_status);

            const event = &recent_interrupt_events[recent_interrupt_events_pointer.read_volatile()];
            event.access_volatile().timestamp = scheduler.time_ms;
            event.access_volatile().global_interrupt_status = global_interrupt_status;
            event.access_volatile().complete = false;
            recent_interrupt_events_pointer.write_volatile((recent_interrupt_events_pointer.read_volatile() + 1) % recent_interrupt_events.len);

            var command_completed = false;

            for (self.ports) |*port, _port_i|
            {
                const port_i = @intCast(u32, _port_i);
                if (~global_interrupt_status & (@as(u32, 1) << @intCast(u5, port_i)) != 0) continue;

                const interrupt_status = PIS.read(self, port_i);
                if (interrupt_status == 0) continue;

                PIS.write(self, port_i, interrupt_status);

                if (interrupt_status & ((1 << 30 | (1 << 29) | (1 << 28) | (1 << 27) | (1 << 26) | (1 << 24) | (1 << 23))) != 0)
                {
                    TODO();
                }
                port.command_spinlock.acquire();
                const commands_issued = PCI_register.read(self, port_i);

                if (port_i == 0)
                {
                    event.access_volatile().port_0_commands_issued = commands_issued;
                    event.access_volatile().port_0_commands_running = port.running_commands;
                }

                var i: u32 = 0;
                while (i < self.ports.len) : (i += 1)
                {
                    const shifter = (@as(u32, 1) << @intCast(u5, i));
                    if (~port.running_commands & shifter != 0) continue;
                    if (commands_issued & shifter != 0) continue;

                    port.command_contexts[i].?.end(true);
                    port.command_contexts[i] = null;
                    _ = port.command_slots_available_event.set(true);
                    port.running_commands &= ~shifter;

                    command_completed = true;
                }

                port.command_spinlock.release();
            }

            if (command_completed)
            {
                GetLocalStorage().?.IRQ_switch_thread = true;
            }

            event.access_volatile().complete = true;
            return true;
        }

        fn send_single_command(self: *@This(), port: u32) bool
        {
            const timeout = Timeout.new(general_timeout);
            
            while (PTFD.read(self, port) & ((1 << 7) | (1 << 3)) != 0 and !timeout.hit()) { }
            if (timeout.hit()) return false;
            @fence(.SeqCst);
            PCI_register.write(self, port, 1 << 0);
            var complete = false;

            while (!timeout.hit())
            {
                complete = ~PCI_register.read(self, port) & (1 << 0) != 0;
                if (complete)
                {
                    break;
                }
            }

            return complete;
        }

        fn access(self: *@This(), _port_index: u64, offset: u64, byte_count: u64, operation: i32, buffer: *DMABuffer, flags: BlockDevice.AccessRequest.Flags, dispatch_group: ?*Workgroup) bool
        {
            _ = flags;
            const port_index = @intCast(u32, _port_index);
            const port = &self.ports[port_index];

            var command_index: u64 = 0;

            while (true)
            {
                port.command_spinlock.acquire();

                const commands_available = ~PCI_register.read(self, port_index);

                var found = false;
                var slot: u64 = 0;
                while (slot < self.command_slot_count) : (slot += 1)
                {
                    if (commands_available & (@as(u32, 1) << @intCast(u5, slot)) != 0 and port.command_contexts[slot] == null)
                    {
                        command_index = slot;
                        found = true;
                        break;
                    }
                }

                if (!found)
                {
                    port.command_slots_available_event.reset();
                }
                else
                {
                    port.command_contexts[command_index] = dispatch_group;
                }

                port.command_spinlock.release();

                if (!found)
                {
                    _ = port.command_slots_available_event.wait();
                }
                else
                {
                    break;
                }
            }

            const sector_count = byte_count / port.sector_byte_count;
            const offset_sectors = offset / port.sector_byte_count;

            const command_FIS = @intToPtr([*]u32, @ptrToInt(port.command_tables) + command_table_size * command_index);
            command_FIS[0] = 0x27 | (1 << 15) | (@as(u32, if (operation == BlockDevice.write) 0x35 else 0x25) << 16);
            command_FIS[1] = (@intCast(u32, offset_sectors) & 0xffffff) | (1 << 30);
            command_FIS[2] = @intCast(u32, offset_sectors >> 24) & 0xffffff;
            command_FIS[3] = @truncate(u16, sector_count);
            command_FIS[4] = 0;

            var m_PRDT_entry_count: u64 = 0;
            const prdt = @intToPtr([*]u32, @ptrToInt(port.command_tables) + command_table_size * command_index + 0x80);

            while (!buffer.is_complete())
            {
                if (m_PRDT_entry_count == PRDT_entry_count) KernelPanic("Too many PRDT entries");

                const segment = buffer.next_segment(false);

                prdt[0 + 4 * m_PRDT_entry_count] = @truncate(u32, segment.physical_address);
                prdt[1 + 4 * m_PRDT_entry_count] = @truncate(u32, segment.physical_address >> 32);
                prdt[2 + 4 * m_PRDT_entry_count] = 0;
                prdt[3 + 4 * m_PRDT_entry_count] = (@intCast(u32, segment.byte_count) - 1) | @as(u32, if (segment.is_last) (1 << 31) else 0);
                m_PRDT_entry_count += 1;
            }

            port.command_list[command_index * 8 + 0] = 5 | (@intCast(u32, m_PRDT_entry_count) << 16) | @as(u32, if (operation == BlockDevice.write) (1 << 6) else 0);
            port.command_list[command_index * 8 + 1] = 0;

            if (port.atapi)
            {
                port.command_list[command_index * 8 + 0] |= (1 << 5);
                command_FIS[0] = 0x27 | (1 << 15) | (0xa0 << 16);
                command_FIS[1] = @intCast(u32, byte_count) << 8;

                const scsi_command = @intToPtr([*]u8, @ptrToInt(command_FIS) + 0x40);
                EsMemoryZero(@ptrToInt(scsi_command), 10);
                scsi_command[0] = 0xa8;
                scsi_command[2] = @truncate(u8, offset_sectors >> 0x18);
                scsi_command[3] = @truncate(u8, offset_sectors >> 0x10);
                scsi_command[4] = @truncate(u8, offset_sectors >> 0x08);
                scsi_command[5] = @truncate(u8, offset_sectors >> 0x00);
                scsi_command[9] = @intCast(u8, sector_count);
            }

            port.command_spinlock.acquire();
            port.running_commands |= @intCast(u32, 1) << @intCast(u5, command_index);
            @fence(.SeqCst);
            PCI_register.write(self, port_index, @intCast(u32, 1) << @intCast(u5, command_index));
            port.command_start_timestamps[command_index] = scheduler.time_ms;
            port.command_spinlock.release();

            return true;
        }
    };

    const Drive = extern struct
    {
        block_device: BlockDevice,
        port: u64,

        const max_count = 64;
    };

    var driver: *Driver = undefined;

    fn handler(_: u64, context: u64) callconv(.C) bool
    {
        return @intToPtr(*AHCI.Driver, context).handle_IRQ();
    }
};

const DriveType = enum(u8)
{
    other = 0,
    hdd = 1,
    ssd = 2,
    cdrom = 3,
    usb_mass_storage = 4,
};

const BlockDevice = extern struct
{
    access: u64,
    sector_size: u64,
    sector_count: u64,
    read_only: bool,
    nest_level: u8,
    drive_type: DriveType,
    model_bytes: u8,
    model: [64]u8,
    max_access_sector_count: u64,
    signature_block: [*]u8,
    detect_filesystem_mutex: Mutex,

    const AccessRequest = extern struct
    {
        device: *BlockDevice,
        offset: u64,
        count: u64,
        operation: i32,
        buffer: *DMABuffer,
        flags: Flags,
        dispatch_group: ?*Workgroup,

        const Flags = Bitflag(enum(u64)
            {
                cache = 0,
                soft_errors = 1,
            });
        const Callback = fn(self: @This()) i64;
    };

    fn register_filesystem(self: *@This()) void
    {
        self.detect_filesystem();
        // @TODO: notify desktop
    }

    fn detect_filesystem(self: *@This()) void
    {
        _ = self.detect_filesystem_mutex.acquire();
        defer self.detect_filesystem_mutex.release();

        if (self.nest_level > 4) KernelPanic("Filesystem nest limit");

        const sectors_to_read = (signature_block_size + self.sector_size - 1) / self.sector_size;
        if (sectors_to_read > self.sector_count) KernelPanic("Drive too small");

        const bytes_to_read = sectors_to_read * self.sector_size;
        self.signature_block = @intToPtr(?[*]u8, EsHeapAllocate(bytes_to_read, false, &heapFixed)) orelse KernelPanic("unable to allocate memory for fs detection"); 
        var dma_buffer = zeroes(DMABuffer);
        dma_buffer.virtual_address = @ptrToInt(self.signature_block);
        var request = zeroes(BlockDevice.AccessRequest);
        request.device = self;
        request.count = bytes_to_read;
        request.operation = read;
        request.buffer = &dma_buffer;

        if (FSBlockDeviceAccess(request) != ES_SUCCESS)
        {
            KernelPanic("Could not read disk");
        }
        assert(self.nest_level == 0);

        if (!self.check_mbr()) KernelPanic("Only MBR is supported\n");

        EsHeapFree(@ptrToInt(self.signature_block), bytes_to_read, &heapFixed);
    }

    fn check_mbr(self: *@This()) bool
    {
        if (MBR.get_partitions(self.signature_block, self.sector_count))
        {
            for (AHCI.driver.mbr_partitions) |partition|
            {
                if (partition.present)
                {
                    // @TODO: this should be a recursive call to fs_register
                    const index = AHCI.driver.partition_devices.len;
                    AHCI.driver.partition_devices.len += 1;
                    const partition_device = &AHCI.driver.partition_devices[index];
                    partition_device.register(self, partition.offset, partition.count, 0, "MBR partition");
                    return true;
                }
            }
        }
        
        return false;
    }

    const read = 0;
    const write = 1;
};

const MBR = extern struct
{
    const Partition = extern struct
    {
        offset: u32,
        count: u32,
        present: bool,
    };
    fn get_partitions(first_block: [*]u8, sector_count: u64) bool
    {
        const is_boot_magic_ok = first_block[510] == 0x55 and first_block[511] == 0xaa;
        if (!is_boot_magic_ok) return false;

        for (AHCI.driver.mbr_partitions) |*mbr_partition, i|
        {
            if (first_block[4 + 0x1be + i * 0x10] == 0)
            {
                mbr_partition.present = false;
                continue;
            }

            mbr_partition.offset =
                (@intCast(u32, first_block[0x1be + i * 0x10 + 8]) << 0) +
                (@intCast(u32, first_block[0x1be + i * 0x10 + 9]) << 8) +
                (@intCast(u32, first_block[0x1be + i * 0x10 + 10]) << 16) +
                (@intCast(u32, first_block[0x1be + i * 0x10 + 11]) << 24);
            mbr_partition.count =
                (@intCast(u32, first_block[0x1be + i * 0x10 + 12]) << 0) +
                (@intCast(u32, first_block[0x1be + i * 0x10 + 13]) << 8) +
                (@intCast(u32, first_block[0x1be + i * 0x10 + 14]) << 16) +
                (@intCast(u32, first_block[0x1be + i * 0x10 + 15]) << 24);
            mbr_partition.present = true;

            if (mbr_partition.offset > sector_count or mbr_partition.count > sector_count - mbr_partition.offset or mbr_partition.count < 32)
            {
                return false;
            }
            AHCI.driver.mbr_partition_count += 1;
        }

        return true;
    }
};

const PartitionDevice = extern struct
{
    block: BlockDevice,
    sector_offset: u64,
    parent: *BlockDevice,

    const max_count = 16;

    fn access(_request: BlockDevice.AccessRequest) Error
    {
        var request = _request;
        const device = @ptrCast(*PartitionDevice, request.device);
        request.device = @ptrCast(*BlockDevice, device.parent);
        request.offset += device.sector_offset * device.block.sector_size;
        return FSBlockDeviceAccess(request);
    }

    fn register(self: *@This(), parent: *BlockDevice, offset: u64, sector_count: u64, flags: u32, model: []const u8) void
    {
        _ = flags; // @TODO: refactor
        std.mem.copy(u8, self.block.model[0..model.len], model);

        self.parent = parent;
        self.block.sector_size = parent.sector_size;
        self.block.max_access_sector_count = parent.max_access_sector_count;
        self.sector_offset = offset;
        self.block.sector_count = sector_count;
        self.block.read_only = parent.read_only;
        self.block.access = @ptrToInt(access);
        self.block.model_bytes = @intCast(u8, model.len);
        self.block.nest_level = parent.nest_level + 1;
        self.block.drive_type = parent.drive_type;
    }
};

const Errors = struct
{
    const ES_ERROR_BLOCK_ACCESS_INVALID: Error = -74;
    const ES_ERROR_DRIVE_CONTROLLER_REPORTED: Error = -35;
    const ES_ERROR_UNSUPPORTED_EXECUTABLE: Error = -62;
    const ES_ERROR_INSUFFICIENT_RESOURCES: Error = -52;
};

fn FSBlockDeviceAccess(_request: BlockDevice.AccessRequest) Error
{
    var request = _request;
    const device = request.device;

    if (request.count == 0) return ES_SUCCESS;

    if (device.read_only and request.operation == BlockDevice.write)
    {
        if (request.flags.contains(.soft_errors)) return Errors.ES_ERROR_BLOCK_ACCESS_INVALID;
        KernelPanic("The device is read-only and the access requests for write permission");
    }

    if (request.offset / device.sector_size > device.sector_count or (request.offset + request.count) / device.sector_size > device.sector_count)
    {
        if (request.flags.contains(.soft_errors)) return Errors.ES_ERROR_BLOCK_ACCESS_INVALID;
        KernelPanic("Disk access out of bounds");
    }

    if (request.offset % device.sector_size != 0 or request.count % device.sector_size != 0)
    {
        if (request.flags.contains(.soft_errors)) return Errors.ES_ERROR_BLOCK_ACCESS_INVALID;
        KernelPanic("Unaligned access\n");
    }

    var buffer = request.buffer.*;

    if (buffer.virtual_address & 3 != 0)
    {
        if (request.flags.contains(.soft_errors)) return Errors.ES_ERROR_BLOCK_ACCESS_INVALID;
        KernelPanic("Buffer must be 4-byte aligned");
    }

    var fake_dispatch_group = zeroes(Workgroup);
    if (request.dispatch_group == null)
    {
        fake_dispatch_group.init();
        request.dispatch_group = &fake_dispatch_group;
    }

    var r = zeroes(BlockDevice.AccessRequest);
    r.device = request.device;
    r.buffer = &buffer;
    r.flags = request.flags;
    r.dispatch_group = request.dispatch_group;
    r.operation = request.operation;
    r.offset = request.offset;

    while (request.count != 0)
    {
        r.count = device.max_access_sector_count * device.sector_size;
        if (r.count > request.count) r.count = request.count;

        buffer.offset = 0;
        buffer.total_byte_count = r.count;
        //r.count = r.count;
        const callback = @intToPtr(BlockDevice.AccessRequest.Callback, device.access);
        _ =callback(r);
        //_ = device.access(r);
        r.offset += r.count;
        buffer.virtual_address += r.count;
        request.count -= r.count;
    }

    if (request.dispatch_group == &fake_dispatch_group)
    {
        return if (fake_dispatch_group.wait()) ES_SUCCESS else Errors.ES_ERROR_DRIVE_CONTROLLER_REPORTED;
    }
    else
    {
        return ES_SUCCESS;
    }
}

const signature_block_size = 65536;

const DMASegment = extern struct
{
    physical_address: u64,
    byte_count: u64,
    is_last: bool,
};

const DMABuffer = extern struct
{
    virtual_address: u64,
    total_byte_count: u64,
    offset: u64,

    fn is_complete(self: *@This()) bool
    {
        return self.offset == self.total_byte_count;
    }

    fn next_segment(self: *@This(), peek: bool) DMASegment
    {
        if (self.offset >= self.total_byte_count or self.virtual_address == 0) KernelPanic("Invalid state of DMA buffer");

        var transfer_byte_count: u64 = page_size;
        const virtual_address = self.virtual_address + self.offset;
        var physical_address = MMArchTranslateAddress(virtual_address, false);
        const offset_into_page = virtual_address & (page_size - 1);

        if (offset_into_page > 0)
        {
            transfer_byte_count = page_size - offset_into_page;
            physical_address += offset_into_page;
        }

        const total_minus_offset = self.total_byte_count - self.offset;
        if (transfer_byte_count > total_minus_offset)
        {
            transfer_byte_count = total_minus_offset;
        }

        const is_last = self.offset + transfer_byte_count == self.total_byte_count;
        if (!peek) self.offset += transfer_byte_count;

        return DMASegment
        {
            .physical_address = physical_address,
            .byte_count = transfer_byte_count,
            .is_last = is_last,
        };
    }
};

extern fn KSwitchThreadAfterIRQ() callconv(.C) void;

const InterruptEvent = extern struct
{
    timestamp: u64,
    global_interrupt_status: u32,
    port_0_commands_running: u32,
    port_0_commands_issued: u32,
    complete: bool,
};

fn drivers_init() callconv(.C) void
{
    PCI.Driver.init();
    AHCI.Driver.init();
}

const Timeout = extern struct
{
    end: u64,

    fn new(ms: u64) callconv(.Inline) Timeout
    {
        return Timeout
        {
            .end = scheduler.time_ms + ms,
        };
    }

    fn hit(self: @This()) callconv(.Inline) bool
    {
        return scheduler.time_ms >= self.end;
    }
};
export fn start_desktop_process() callconv(.C) void
{
    const result = process_start_with_something(desktopProcess);
    assert(result);
}

const ProcessStartupInformation = extern struct
{
    is_desktop: bool,
    is_bundle: bool,
    application_start_address: u64,
    tls_image_start: u64,
    tls_image_byte_count: u64,
    tls_byte_count: u64,
    timestamp_ticks_per_ms: u64,
    global_data_region: u64,
    process_create_data: ProcessCreateData,
};

const LoadedExecutable = extern struct
{
    start_address: u64,
    tls_image_start: u64,
    tls_image_byte_count: u64,
    tls_byte_count: u64,

    is_desktop: bool,
    is_bundle: bool,
};

const hardcoded_kernel_file_offset = 1056768;
const hardcoded_desktop_size = 17344;
comptime { assert(align_address(hardcoded_desktop_size, 0x200) < desktop_executable_buffer.len); }
export var desktop_executable_buffer: [0x8000]u8 align(0x1000) = undefined;

fn align_address(address: u64, alignment: u64) u64
{
    const mask = alignment - 1;
    assert(alignment & mask == 0);
    return (address + mask) & ~mask;
}

fn hard_disk_read_desktop_executable() Error
{
    const unaligned_desktop_offset = hardcoded_kernel_file_offset + kernel_size;
    const desktop_offset = align_address(unaligned_desktop_offset, 0x200);

    assert(AHCI.driver.drives.len > 0);
    assert(AHCI.driver.drives.len == 1);
    assert(AHCI.driver.mbr_partition_count > 0);
    assert(AHCI.driver.mbr_partition_count == 1);

    var buffer = zeroes(DMABuffer);
    buffer.virtual_address = @ptrToInt(&desktop_executable_buffer);
    var request = zeroes(BlockDevice.AccessRequest);
    request.offset = desktop_offset;
    request.count = align_address(hardcoded_desktop_size, 0x200);
    request.operation = BlockDevice.read;
    request.device = @ptrCast(*BlockDevice, &AHCI.driver.drives[0]);
    request.buffer = &buffer;

    const result = FSBlockDeviceAccess(request);
    assert(result == ES_SUCCESS);
    return result;
}

const ELF = extern struct
{
    const Header = extern struct
    {
        magic: u32,
        bits: u8,
        endianness: u8,
        version1: u8,
        abi: u8,
        unused: [8]u8,
        type: u16,
        instruction_set: u16,
        version2: u32,

        entry: u64,
        program_header_table: u64,
        section_header_table: u64,
        flags: u32,
        header_size: u16,
        program_header_entry_size: u16,
        program_header_entry_count: u16,
        section_header_entry_size: u16,
        section_header_entry_count: u16,
        section_name_index: u16,
    };

    const ProgramHeader = extern struct
    {
        type: u32,
        flags: u32,
        file_offset: u64,
        virtual_address: u64,
        unused0: u64,
        data_in_file: u64,
        segment_size: u64,
        alignment: u64,

        fn is_bad(self: *@This()) bool
        {
            return self.virtual_address >= 0xC0000000 or self.virtual_address < 0x1000 or self.segment_size > 0x10000000;
        }
    };
};

export fn LoadDesktopELF(exe: *LoadedExecutable) Error
{
    const process = GetCurrentThread().?.process.?;

    if (hard_disk_read_desktop_executable() != ES_SUCCESS) KernelPanic("Can't read desktop executable from the disk");

    const header = @ptrCast(*ELF.Header, &desktop_executable_buffer);
    if (header.magic != 0x464c457f) return Errors.ES_ERROR_UNSUPPORTED_EXECUTABLE;
    if (header.bits != 2) return Errors.ES_ERROR_UNSUPPORTED_EXECUTABLE;
    if (header.endianness != 1) return Errors.ES_ERROR_UNSUPPORTED_EXECUTABLE;
    if (header.abi != 0) return Errors.ES_ERROR_UNSUPPORTED_EXECUTABLE;
    if (header.type != 2) return Errors.ES_ERROR_UNSUPPORTED_EXECUTABLE;
    if (header.instruction_set != 0x3e) return Errors.ES_ERROR_UNSUPPORTED_EXECUTABLE;

    const program_headers = @intToPtr(?[*]ELF.ProgramHeader, EsHeapAllocate(header.program_header_entry_size * header.program_header_entry_count, false, &heapFixed)) orelse return Errors.ES_ERROR_INSUFFICIENT_RESOURCES; // K_PAGED
    defer EsHeapFree(@ptrToInt(program_headers), 0, &heapFixed); // K_PAGED

    const executable_offset = 0;
    EsMemoryCopy(@ptrToInt(program_headers), @ptrToInt(&desktop_executable_buffer[executable_offset + header.program_header_table]), header.program_header_entry_size * header.program_header_entry_count);

    var ph_i: u64 = 0;
    while (ph_i < header.program_header_entry_count) : (ph_i += 1)
    {
        const ph = @intToPtr(*ELF.ProgramHeader, @ptrToInt(program_headers) + header.program_header_entry_size * ph_i);

        if (ph.type == 1) // PT_LOAD
        {
            if (ph.is_bad()) return Errors.ES_ERROR_UNSUPPORTED_EXECUTABLE;

            const result = MMStandardAllocate(process.address_space, round_up(u64, ph.segment_size, page_size), Region.Flags.empty(), round_down(u64, ph.virtual_address, page_size), true);
            if (result != 0)
            {
                EsMemoryCopy(ph.virtual_address, @ptrToInt(&desktop_executable_buffer[executable_offset + ph.file_offset]), ph.data_in_file);
            }
            else
            {
                return Errors.ES_ERROR_INSUFFICIENT_RESOURCES;
            }
        }
        else if (ph.type == 7)  // PT_TLS
        {
            exe.tls_image_start = ph.virtual_address;
            exe.tls_image_byte_count = ph.data_in_file;
            exe.tls_byte_count = ph.segment_size;
        }
    }

    exe.start_address = header.entry;
    return ES_SUCCESS;
}

export fn ProcessLoadDesktopExecutable() callconv(.C) void
{
    const process = GetCurrentThread().?.process.?;
    var exe = zeroes(LoadedExecutable);
    exe.is_desktop = true;
    const result = LoadDesktopELF(&exe);
    if (result != ES_SUCCESS) KernelPanic("Failed to load desktop executable");

    const startup_information = @intToPtr(?*ProcessStartupInformation, MMStandardAllocate(process.address_space, @sizeOf(ProcessStartupInformation), Region.Flags.empty(), 0, true)) orelse KernelPanic("Can't allocate startup information");
    startup_information.is_desktop = true;
    startup_information.is_bundle = false;
    startup_information.application_start_address = exe.start_address;
    startup_information.tls_image_start = exe.tls_image_start;
    startup_information.tls_image_byte_count = exe.tls_image_byte_count;
    startup_information.tls_byte_count = exe.tls_byte_count;
    startup_information.timestamp_ticks_per_ms = timeStampTicksPerMs;
    startup_information.process_create_data = process.data;
    
    var thread_flags = Thread.Flags.from_flag(.userland);
    if (process.creation_flags.contains(.paused)) thread_flags = thread_flags.or_flag(.paused);
    process.executable_state = .loaded;
    process.executable_main_thread = ThreadSpawn(exe.start_address, @ptrToInt(startup_information), thread_flags, process, 0) orelse KernelPanic("Couldn't create main thread for executable");
    _ = process.executable_load_attempt_complete.set(false);
}

// ProcessStartWithNode
export fn process_start_with_something(process: *Process) bool
{
    scheduler.dispatch_spinlock.acquire();

    if (process.executable_start_request)
    {
        scheduler.dispatch_spinlock.release();
        return false;
    }

    process.executable_start_request = true;
    scheduler.dispatch_spinlock.release();

    if (!MMSpaceInitialise(process.address_space)) return false;

    if (scheduler.all_processes_terminated_event.poll())
    {
        KernelPanic("all process terminated event was set");
    }

    process.block_shutdown = true;
    _ = scheduler.active_process_count.atomic_fetch_add(1);
    _ = scheduler.block_shutdown_process_count.atomic_fetch_add(1);

    _ = scheduler.all_processes_mutex.acquire();
    scheduler.all_processes.insert_at_end(&process.all_item);
    const load_executable_thread = CreateLoadExecutableThread(process);
    scheduler.all_processes_mutex.release();

    if (load_executable_thread) |thread|
    {
        CloseHandleToObject(@ptrToInt(thread), .thread, 0);
        _ = process.executable_load_attempt_complete.wait();
        if (process.executable_state == .failed_to_load) return false;
        return true;
    }
    else
    {
        CloseHandleToObject(@ptrToInt(process), .process, 0);
        return false;
    }
}

fn TimeoutTimerHit(task: *AsyncTask) void
{
    const driver = @fieldParentPtr(AHCI.Driver, "timeout_timer", @fieldParentPtr(Timer, "async_task", task));
    const current_timestamp = scheduler.time_ms;

    for (driver.ports) |*port|
    {
        port.command_spinlock.acquire();

        var slot: u64 = 0;
        while (slot < driver.command_slot_count) : (slot += 1)
        {
            const slot_mask = @intCast(u32, 1) << @intCast(u5, slot);
            if (port.running_commands & slot_mask != 0 and port.command_start_timestamps[slot] + AHCI.general_timeout < current_timestamp)
            {
                port.command_contexts[slot].?.end(false);
                port.command_contexts[slot] = null;
                port.running_commands &= ~slot_mask;
            }
        }

        port.command_spinlock.release();
    }

    driver.timeout_timer.set_extended(AHCI.general_timeout, TimeoutTimerHit, @ptrToInt(driver));
}

extern fn CreateLoadExecutableThread(process: *Process) callconv(.C) ?*Thread;

export fn MMArchInitialiseUserSpace(space: *AddressSpace, region: *Region) callconv(.C) bool
{
    region.descriptor.base_address = user_space_start;
    region.descriptor.page_count = user_space_size / page_size;

    if (!MMCommit(page_size, true)) return false;

    space.arch.cr3 = MMPhysicalAllocateWithFlags(Physical.Flags.empty());

    {
        _ = _coreMMSpace.reserve_mutex.acquire();
        defer _coreMMSpace.reserve_mutex.release();

        const L1_region = MMReserve(&_coreMMSpace, ArchAddressSpace.L1_commit_size, Region.Flags.from_flags(.{ .normal, .no_commit_tracking, .fixed }), 0) orelse return false;
        space.arch.commit.L1 = @intToPtr([*]u8, L1_region.descriptor.base_address);
    }

    const page_table_address = @intToPtr(?[*]u64, MMMapPhysical(&_kernelMMSpace, space.arch.cr3, page_size, Region.Flags.empty())) orelse KernelPanic("Expected page table allocation to be good");
    EsMemoryZero(@ptrToInt(page_table_address), page_size / 2);
    EsMemoryCopy(@ptrToInt(page_table_address) + (0x100 * @sizeOf(u64)), @ptrToInt(PageTables.access_at_index(.level4, 0x100)), page_size / 2);
    page_table_address[512 - 2] = space.arch.cr3 | 0b11;
    _ = MMFree(&_kernelMMSpace, @ptrToInt(page_table_address), 0, false);

    return true;
}

export fn MMSpaceInitialise(space: *AddressSpace) callconv(.C) bool
{
    space.user = true;

    const region = @intToPtr(?*Region, EsHeapAllocate(@sizeOf(Region), true, &heapCore)) orelse return false;

    if (!MMArchInitialiseUserSpace(space, region))
    {
        EsHeapFree(@ptrToInt(region), @sizeOf(Region), &heapCore);
        return false;
    }

    _ = space.free_region_base.insert(&region.u.item.base, region, region.descriptor.base_address, .panic);
    _ = space.free_region_size.insert(&region.u.item.u.size, region, region.descriptor.page_count, .allow);

    return true;
}

export fn MMArchInvalidatePages(virtual_address_start: u64, page_count: u64) callconv(.C) void
{
    ipiLock.acquire();
    tlbShootdownVirtualAddress.access_volatile().* = virtual_address_start;
    tlbShootdownPageCount.access_volatile().* = page_count;

    ArchCallFunctionOnAllProcessors(TLBShootdownCallback, true);
    ipiLock.release();
}

export fn CallFunctionOnAllProcessorCallbackWrapper() callconv(.C) void
{
    @ptrCast(*volatile CallFunctionOnAllProcessorsCallback, &callFunctionOnAllProcessorsCallback).*();
}

extern fn Get_KThreadTerminateAddress() callconv(.C) u64;
export fn ArchInitialiseThread(kernel_stack: u64, kernel_stack_size: u64, thread: *Thread, start_address: u64, argument1: u64, argument2: u64, userland: bool, user_stack: u64, user_stack_size: u64) callconv(.C) *InterruptContext
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
    if (context.rip == 0) KernelPanic("RIP is 0");
    context.rsp = user_stack + user_stack_size - 8;
    context.rdi = argument1;
    context.rsi = argument2;

    return context;
}

export fn OpenHandleToObject(object: u64, object_type: KernelObjectType, flags: u32) callconv(.C) bool
{
    _ = flags;
    var had_no_handles = false;
    var failed = false;

    switch (object_type)
    {
        .process =>
        {
            had_no_handles = @intToPtr(*Process, object).handle_count.atomic_fetch_add(1) == 0;
        },
        .thread =>
        {
            had_no_handles = @intToPtr(*Thread, object).handle_count.atomic_fetch_add(1) == 0;
        },
        .shared_memory =>
        {
            const region = @intToPtr(*SharedRegion, object);
            _ = region.mutex.acquire();
            had_no_handles = (region.handle_count.read_volatile() == 0);
            if (!had_no_handles) region.handle_count.increment();
            region.mutex.release();
        },
        else => TODO(),
    }

    if (had_no_handles) KernelPanic("object had no handles");

    return !failed;
}

export fn CloseHandleToObject(object: u64, object_type: KernelObjectType, flags: u32) callconv(.C) void
{
    _ = flags;
    switch (object_type)
    {
        .process =>
        {
            const process = @intToPtr(*Process, object);
            const previous = process.handle_count.atomic_fetch_sub(1);
            // @Log
            if (previous == 0) KernelPanic("All handles to process have been closed")
            else if (previous == 1) TODO();
        },
        .thread =>
        {
            const thread = @intToPtr(*Thread, object);
            const previous = thread.handle_count.atomic_fetch_sub(1);

            if (previous == 0) KernelPanic("All handles to thread have been closed")
            else if (previous == 1) ThreadRemove(thread);
        },
        else => TODO(),
    }
}

export fn InterruptHandler(context: *InterruptContext) callconv(.C) void
{
    if (scheduler.panic.read_volatile() and context.interrupt_number != 2) return;
    if (ProcessorAreInterruptsEnabled()) KernelPanic("interrupts were enabled at the start of the interrupt handler");

    const interrupt = context.interrupt_number;
    var maybe_local = GetLocalStorage();
    if (maybe_local) |local|
    {
        if (local.current_thread) |current_thread| current_thread.last_interrupt_timestamp = ProcessorReadTimeStamp();
        if (local.spinlock_count != 0 and context.cr8 != 0xe) KernelPanic("Spinlock count is not zero but interrupts were enabled");
    }

    if (interrupt < 0x20)
    {
        if (interrupt == 2)
        {
            maybe_local.?.panic_context = context;
            ProcessorHalt();
        }

        const supervisor = context.cs & 3 == 0;

        if (!supervisor)
        {
            if (context.cs != 0x5b and context.cs != 0x6b) KernelPanic("Unexpected value of CS");
            const current_thread = GetCurrentThread().?;
            if (current_thread.is_kernel_thread) KernelPanic("Kernel thread executing user code");
            const previous_terminatable_state = current_thread.terminatable_state.read_volatile();
            current_thread.terminatable_state.write_volatile(.in_syscall);

            if (maybe_local) |local| if (local.spinlock_count != 0) KernelPanic("user exception occurred with spinlock acquired");

            ProcessorEnableInterrupts();
            maybe_local = null;

            if ((interrupt == 14 and !MMArchHandlePageFault(context.cr2, if (context.error_code & 2 != 0) HandlePageFaultFlags.from_flag(.write) else HandlePageFaultFlags.empty())) or interrupt != 14)
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
                ProcessCrash(current_thread.process.?, &crash_reason);
            }

            if (current_thread.terminatable_state.read_volatile() != .in_syscall) KernelPanic("thread changed terminatable state during interrupt");

            current_thread.terminatable_state.write_volatile(previous_terminatable_state);
            if (current_thread.terminating.read_volatile() or current_thread.paused.read_volatile()) ProcessorFakeTimerInterrupt();

            ProcessorDisableInterrupts();
        }
        else
        {
            if (context.cs != 0x48) KernelPanic("unexpected value of CS");

            if (interrupt == 14)
            {
                if (context.error_code & (1 << 3) != 0) KernelPanic("unresolvable page fault");

                if (maybe_local) |local| if (local.spinlock_count != 0 and (context.cr2 >= 0xFFFF900000000000 and context.cr2 < 0xFFFFF00000000000)) KernelPanic("page fault occurred with spinlocks active");

                if (context.flags & 0x200 != 0 and context.cr8 != 0xe)
                {
                    ProcessorEnableInterrupts();
                    maybe_local = null;
                }

                const result = MMArchHandlePageFault(context.cr2, (if (context.error_code & 2 != 0) HandlePageFaultFlags.from_flag(.write) else HandlePageFaultFlags.empty()).or_flag(.for_supervisor));
                var safe_copy = false;
                if (!result)
                {
                    if (GetCurrentThread().?.in_safe_copy and context.cr2 < 0x8000000000000000)
                    {
                        safe_copy = true;
                        context.rip = context.r8;
                    }
                }

                if (result or safe_copy)
                {
                    ProcessorDisableInterrupts();
                }
                else
                {
                    KernelPanic("unhandled page fault");
                }
            }
            else
            {
                KernelPanic("Unresolvable exception");
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
        TODO();
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

                if (local.IRQ_switch_thread and scheduler.started.read_volatile() and local.scheduler_ready)
                {
                    //TODO();
                    SchedulerYield(context);
                    KernelPanic("returned from scheduler yield");
                }
                else
                {
                    LapicEndOfInterrupt();
                }
            }
            else
            {
                KernelPanic("MSI handler didn't have a callback assigned");
            }
        }
        else
        {
            local.IRQ_switch_thread = false;

            if (interrupt == timer_interrupt)
            {
                local.IRQ_switch_thread = true;
            }
            else if (interrupt == yield_ipi)
            {
                local.IRQ_switch_thread = true;
                GetCurrentThread().?.received_yield_IPI.write_volatile(true);
            }
            else if (interrupt >= irq_base and interrupt < irq_base + 0x20)
            {
                TODO();
            }

            if (local.IRQ_switch_thread and scheduler.started.read_volatile() and local.scheduler_ready)
            {
                SchedulerYield(context);
                KernelPanic("returned from scheduler yield");
            }
            else
            {
                LapicEndOfInterrupt();
            }
        }
    }

    ContextSanityCheck(context);

    if (ProcessorAreInterruptsEnabled()) KernelPanic("interrupts were enabled while returning from an interrupt handler");
}

export fn EsHeapAllocate(size: u64, zero_memory: bool, heap: *Heap) callconv(.C) u64
{
    return heap.allocate(size, zero_memory);
}

export fn EsHeapFree(address: u64, expected_size: u64, heap: *Heap) callconv(.C) void
{
    heap.free(address, expected_size);
}

// @TODO: investigate why we should cast to u32
export fn HeapCalculateIndex(size: u64) callconv(.C) u64
{
    assert(size != 0 or size != std.math.maxInt(u32));
    const clz = @clz(u32, @intCast(u32, size));
    const msb = @sizeOf(u32) * 8 - clz - 1;
    return msb - 4;
}

export fn get_size_zig() callconv(.C) u64
{
    return @sizeOf(Scheduler);
}
