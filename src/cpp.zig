const std = @import("std");
const assert = std.debug.assert;
const zeroes = std.mem.zeroes;
pub const max_wait_count = 8;
pub const wait_no_timeout = std.math.maxInt(u64);
pub const page_bit_count = 12;
pub const page_size = 0x1000;

pub const entry_per_page_table_count = 512;
pub const entry_per_page_table_bit_count = 9;

export var _stack: [0x4000]u8 align(0x1000) linksection(".bss") = zeroes([0x4000]u8);
export var _idt_data: [idt_entry_count]IDTEntry align(0x1000) linksection(".bss") = zeroes([idt_entry_count]IDTEntry);
export var _cpu_local_storage: [0x2000]u8 align(0x1000) linksection(".bss") = zeroes([0x2000]u8);

export var timeStampCounterSynchronizationValue = Volatile(u64) { .value = 0 };

export var idt_descriptor: DescriptorTable linksection(".data") = undefined;
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
extern var kernelProcess: *Process;

extern fn ProcessorAreInterruptsEnabled() callconv(.C) bool;
extern fn ProcessorEnableInterrupts() callconv(.C) void;
extern fn ProcessorDisableInterrupts() callconv(.C) void;
extern fn ProcessorFakeTimerInterrupt() callconv(.C) void;
extern fn GetLocalStorage() callconv(.C) ?*LocalStorage;
extern fn GetCurrentThread() callconv(.C) ?*Thread;

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

        pub fn increment(self: *@This()) void
        {
            self.write_volatile(self.read_volatile() + 1);
        }

        pub fn decrement(self: *@This()) void
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

        pub fn atomic_compare_and_swap(self: *@This(), expected_value: T, new_value: T) ?T
        {
            return @cmpxchgStrong(@TypeOf(self.value), &self.value, expected_value, new_value, .SeqCst, .SeqCst);
        }
    };
}

fn UnalignedVolatilePointer(comptime T: type) type
{
    return VolatilePointerExtended(T, 1);
}

fn VolatilePointer(comptime T: type) type
{
    return VolatilePointerExtended(T, null);
}

fn VolatilePointerExtended(comptime T: type, comptime alignment: ?comptime_int) type
{
    return extern struct
    {
        ptr: ?PtrType,

        const PtrType = *volatile align(if (alignment) |alignment_nn| alignment_nn else @alignOf(T)) T;

        fn equal(self: *volatile @This(), other: ?PtrType) bool
        {
            return self.ptr == other;
        }

        fn dereference(self: *volatile @This()) T
        {
            return self.ptr.?.*;
        }

        fn overwrite(self: *volatile @This(), ptr: ?PtrType) void
        {
            self.ptr = ptr;
        }

        fn access(self: *volatile @This()) PtrType
        {
            return self.ptr.?;
        }

        fn get(self: *volatile @This()) ?PtrType
        {
            return self.ptr;
        }

        fn is_null(self: *volatile @This()) bool
        {
            return self.ptr == null;
        }

        fn atomic_compare_and_swap(self: *volatile @This(), expected_value: ?PtrType, new_value: ?PtrType) ??PtrType
        {
            return @cmpxchgStrong(?PtrType, @ptrCast(*?PtrType, &self.ptr), expected_value, new_value, .SeqCst, .SeqCst);
        }
    };
}

const DescriptorTable = packed struct 
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

fn TODO() noreturn
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
        var handler_address = @ptrToInt(InterruptHandler(interrupt_number, has_error_code_pushed).routine);

        _idt_data[interrupt_number].foo1 = @truncate(u16, handler_address);
        _idt_data[interrupt_number].foo2 = 0x48;
        _idt_data[interrupt_number].foo3 = 0x8e00;
        handler_address >>= 16;
        _idt_data[interrupt_number].foo4 = @truncate(u16, handler_address);
        handler_address >>= 16;
        _idt_data[interrupt_number].masked_handler = handler_address;
    }
}

fn InterruptHandler(comptime number: u64, comptime has_error_code: bool) type
{
    return struct
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
                \\
                \\cld
                \\
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
                \\
                \\mov rax, cr8
                \\push rax
                \\
                \\mov rax, 0x123456789ABCDEF
                \\push rax
                \\
                \\mov rbx, rsp
                \\and rsp, ~0xf
                \\fxsave [rsp - 512]
                \\mov rsp, rbx
                \\sub rsp, 512 + 16
                \\
                \\xor rax, rax
                \\mov ax, ds
                \\push rax
                \\mov ax, 0x10
                \\mov ds, ax
                \\mov es, ax
                \\mov rax, cr2
                \\push rax
                \\
                \\mov rdi, rsp
                \\mov rbx, rsp
                \\and rsp, ~0xf
                \\call InterruptHandler
                \\mov rsp, rbx
                \\xor rax, rax
                \\
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

        const maybe_local_storage = LocalStorage.get();
        if (maybe_local_storage) |local_storage|
        {
            local_storage.spinlock_count += 1;
        }

        _ = @cmpxchgStrong(@TypeOf(self.state.value), &self.state.value, 0, 1, .SeqCst, .SeqCst);
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

        const maybe_local_storage = LocalStorage.get();
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

    thread_pool: Pool(Thread),
    process_pool: Pool(Process),
    address_space_pool: Pool(AddressSpace),

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
};

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
    pub fn get() callconv(.Inline) ?*@This()
    {
        return asm volatile(
                \\mov %%gs:0x0, %[out]
                : [out] "=r" (-> ?*@This())
        );
    }

    fn set(storage: *@This()) callconv(.Inline) void
    {
        asm volatile(
            \\mov %[in], %%gs:0x0
            :
            : [in] "r" (storage)
        );
    }
    //extern fn set(storage: *LocalStorage) callconv(.C) void;
    //comptime asm
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
        mutex: VolatilePointer(Mutex),
        writer: struct
        {
            lock: VolatilePointer(WriterLock),
            type: bool,
        },
        event: struct
        {
            items: ?[*]volatile LinkedList(Thread).Item,
            array: [max_wait_count]VolatilePointer(Event),
            count: u64,
        },
    },

    killed_event: Event,
    kill_async_task: AsyncTask,

    temporary_address_space: VolatilePointer(AddressSpace),
    interrupt_context: *InterruptContext,
    last_known_execution_address: u64, // @TODO: for debugging

    name: [*:0]u8,

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
        const Self = @This();

        first: ?*Item,
        last: ?*Item,
        count: u64,

        pub const Item = extern struct
        {
            previous: ?*Item,
            next: ?*Item,
            list: ?*Self,
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
            // @TODO: modchecks

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
            self.count -= 1;
            self.validate();
        }

        fn validate(self: *@This()) void
        {
            if (self.count == 0)
            {
                TODO();
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
    callback: ?AsyncTask.Callback,
    argument: u64,

    pub fn set_extended(self: *@This(), trigger_in_ms: u64, maybe_callback: ?AsyncTask.Callback, maybe_argument: u64) void
    {
        scheduler.active_timers_spinlock.acquire();

        if (self.item.list != null) scheduler.active_timers.remove(&self.item);

        self.event.reset();

        self.trigger_time_ms = trigger_in_ms + scheduler.time_ms;
        self.callback = maybe_callback;
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

        if (self.callback != null) KernelPanic("timer with callback cannot be removed");

        if (self.item.list != null) scheduler.active_timers.remove(&self.item);

        scheduler.active_timers_spinlock.release();
    }
};

pub const Mutex = extern struct
{
    owner: UnalignedVolatilePointer(Thread),
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

                    if (!self.owner.is_null() and self.owner.equal(current_thread))
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

            break :blk UnalignedVolatilePointer(Thread) { .ptr = @intToPtr(*volatile align(1) Thread, thread_address) };
        };

        if (!ProcessorAreInterruptsEnabled())
        {
            KernelPanic("trying to acquire a mutex with interrupts disabled");
        }

        while (true)
        {
            scheduler.dispatch_spinlock.acquire();
            const old = self.owner.get();
            if (old == null) self.owner.overwrite(current_thread.get());
            scheduler.dispatch_spinlock.release();
            if (old == null) break;

            @fence(.SeqCst);

            if (LocalStorage.get()) |local_storage|
            {
                if (local_storage.scheduler_ready)
                {
                    if (current_thread.access().state.read_volatile() != .active)
                    {
                        KernelPanic("Attempting to wait on a mutex in a non-active thread\n");
                    }

                    current_thread.access().blocking.mutex.overwrite(self);
                    @fence(.SeqCst);

                    current_thread.access().state.write_volatile(.waiting_mutex);

                    scheduler.dispatch_spinlock.acquire();
                    const spin = blk:
                    {
                        if (self.owner.get()) |owner|
                        {
                            const boolean = owner.executing;
                            break :blk boolean.read_volatile();
                        }
                        break :blk false;
                    };

                    scheduler.dispatch_spinlock.release();

                    if (!spin and !current_thread.access().blocking.mutex.access().owner.is_null())
                    {
                        ProcessorFakeTimerInterrupt();
                    }

                    while ((!current_thread.access().terminating.read_volatile() or current_thread.access().terminatable_state.read_volatile() != .user_block_request) and !self.owner.is_null())
                    {
                        current_thread.access().state.write_volatile(.waiting_mutex);
                    }

                    current_thread.access().state.write_volatile(.active);

                    if (current_thread.access().terminating.read_volatile() and current_thread.access().terminatable_state.read_volatile() == .user_block_request)
                    {
                        // mutex was not acquired because the thread is terminating
                        return false;
                    }
                }
            }
        }

        @fence(.SeqCst);

        if (self.owner.ptr != current_thread.ptr)
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
            if (self.owner.atomic_compare_and_swap(current_thread, null) != null)
            {
                KernelPanic("Invalid owner thread\n");
            }
        }
        else self.owner.overwrite(null);

        const preempt = self.blocked_threads.count != 0;
        if (scheduler.started.read_volatile())
        {
            TODO();
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

        if (!self.owner.equal(current_thread))
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

const Error = i64;
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
    process_exception,
    recursive_batch,
    unknown_syscall,
};

pub const CrashReason = extern struct
{
    error_code: FatalError,
    during_system_call: i32,
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
    creation_flags: u32,
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

    executable_state: u8,
    executable_start_request: bool,
    executable_load_attempt_complete: Event,
    executable_main_thread: ?*Thread,

    cpu_time_slices: u64,
    idle_time_slices: u64,
    
    pub const Type = enum(u32)
    {
        normal,
        desktop,
        kernel,
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

pub fn Pool(comptime T: type) type
{
    return extern struct
    {
        cache_entries: [cache_count]?*T,
        cache_entry_count: u64,
        mutex: Mutex,

        const cache_count = 16;

        //pub fn add(self: *@This()) ?*T
        //{
            //_ = self.mutex.acquire();
            //defer self.mutex.release();

            //if (self.cache_entry_count != 0)
            //{
                //self.cache_entry_count -= 1;
                //const address = self.cache_entries[self.cache_entry_count];
                //std.mem.set(u8, @ptrCast([*]u8, address)[0..@sizeOf(T)], 0);
                //return address;
            //}
            //else
            //{
                //return @intToPtr(?*T, kernel.core.fixed_heap.allocate(@sizeOf(T), true));
            //}
        //}

        //pub fn remove(self: *@This(), pointer: ?*T) void
        //{
            //_ = self.mutex.acquire();
            //defer self.mutex.release();

            //if (pointer == null) return;

            //if (self.cache_entry_count == cache_count)
            //{
                //kernel.core.fixed_heap.free(@ptrToInt(pointer), @sizeOf(T));
            //}
            //else
            //{
                //self.cache_entries[self.cache_entry_count] = pointer;
                //self.cache_entry_count += 1;
            //}
        //}
    };
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

    var core_L1_commit: [(0xFFFF800200000000 - 0xFFFF800100000000) >> (entry_per_page_table_bit_count + page_bit_count + 3)]u8 = undefined;
};

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
                TODO();
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
        _ = self; TODO();
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
            const index = wait_multiple(events[0..1]);
            return index == 0;
        }
        else
        {
            var timer: Timer = undefined;
            std.mem.set(u8, @ptrCast([*]u8, &timer)[0..@sizeOf(Timer)], 0);
            timer.set(timeout_ms);
            events[1] = &timer.event;
            const index = wait_multiple(events[0..2]);
            timer.remove();
            return index == 0;
        }
    }

    fn wait_multiple(events: []*Event) u64
    {
        if (events.len > max_wait_count) KernelPanic("count too high")
        else if (events.len == 0) KernelPanic("count 0")
        else if (!ProcessorAreInterruptsEnabled()) KernelPanic("timer with interrupts disabled");

        const thread = GetCurrentThread().?;
        thread.blocking.event.count = events.len;

        var event_items = zeroes([512]LinkedList(Thread).Item);
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

pub const CPU = extern struct
{
    processor_ID: u8,
    kernel_processor_ID: u8,
    APIC_ID: u8,
    boot_processor: bool,
    kernel_stack: *align(1) u64,
    local_storage: *LocalStorage,
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
        if (self.previous_or_last.next != self or self.next_or_first.previous != self) KernelPanic("bad links");

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
            scheduler.notify_object(&self.blocked_threads, true);
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

    pub const shared = false;
    pub const exclusive = true;
};
pub const AsyncTask = extern struct
{
    item: SimpleList,
    callback: ?Callback,

    pub const Callback = fn (*@This()) callconv(.C) void;

    pub fn register(self: *@This(), callback: Callback) void
    {
        scheduler.async_task_spinlock.acquire();
        if (self.callback == null)
        {
            self.callback = callback;
            LocalStorage.get().?.async_task_list.insert(&self.item, false);
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
        ptr: [*]T,
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
    type: u32,
};

const HandleTableL2 = extern struct
{
    t: [256]Handle,
};

const HandleTableL1 = extern struct
{
    t: [256]?*HandleTableL2,
    u: [256]u16,
};

const HandleTable = extern struct
{
    l1r: HandleTableL1,
    lock: Mutex,
    process: ?*Process,
    destroyed: bool,
    handleCount: u32,
};

pub fn AVLTree(comptime T: type) type
{
    return extern struct
    {
        root: ?*Item,
        modcheck: bool,

        const Tree = @This();
        const Key = u64;

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

        pub fn insert(self: *@This(), item: *Item, item_value: ?*T, key: Key, duplicate_key_policy: DuplicateKeyPolicy) bool
        {
            self.validate();
            
            if (item.tree != null)
            {
                KernelPanic("item already in a tree\n");
            }

            item.tree = self;

            item.key = key;
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
            fake_root.key = 0;
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

                if (balance > 1 and Item.compare_keys(key, item_it.children[0].?.key) <= 0)
                {
                    const right_rotation = item_it.rotate_right();
                    new_root = right_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                    old_parent.children[old_parent_child_index] = right_rotation;
                }
                else if (balance > 1 and Item.compare_keys(key, item_it.children[0].?.key) > 0 and item_it.children[0].?.children[1] != null)
                {
                    item_it.children[0] = item_it.children[0].?.rotate_left();
                    item_it.children[0].?.parent = item_it;
                    const right_rotation = item_it.rotate_right();
                    new_root = right_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                    old_parent.children[old_parent_child_index] = right_rotation;
                }
                else if (balance < -1 and Item.compare_keys(key, item_it.children[1].?.key) > 0)
                {
                    const left_rotation = item_it.rotate_left();
                    new_root = left_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                    old_parent.children[old_parent_child_index] = left_rotation;
                }
                else if (balance < -1 and Item.compare_keys(key, item_it.children[1].?.key) <= 0 and item_it.children[1].?.children[0] != null)
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

        pub fn find(self: *@This(), key: Key, search_mode: SearchMode) ?*Item
        {
            if (self.modcheck) KernelPanic("concurrent access\n");
            self.validate();
            return self.find_recursive(self.root, key, search_mode);
        }

        pub fn find_recursive(self: *@This(), maybe_root: ?*Item, key: Key, search_mode: SearchMode) ?*Item
        {
            if (maybe_root) |root|
            {
                if (Item.compare_keys(root.key, key) == 0) return root;

                switch (search_mode)
                {
                    .exact => return self.find_recursive(root.children[0], key, search_mode),
                    .smallest_above_or_equal =>
                    {
                        if (Item.compare_keys(root.key, key) > 0)
                        {
                            if (self.find_recursive(root.children[0], key, search_mode)) |item| return item
                            else return root;
                        }
                        else return self.find_recursive(root.children[1], key, search_mode);
                    },
                    .largest_below_or_equal =>
                    {
                        if (Item.compare_keys(root.key, key) < 0)
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
            fake_root.key = 0;
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
                return compare_keys(self.key, other.key);
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
            physical: struct
            {
                offset: u64,
            },
            shared: struct
            {
                region: ?*SharedRegion,
                offset: u64,
            },
            file: struct
            {
            },
            normal: struct
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
    };
};