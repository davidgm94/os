const std = @import("std");
const assert = std.debug.assert;
const zeroes = std.mem.zeroes;

export var _stack: [0x4000]u8 align(0x1000) linksection(".bss") = zeroes([0x4000]u8);
export var _idt_data: [idt_entry_count]IDTEntry align(0x1000) linksection(".bss") = zeroes([idt_entry_count]IDTEntry);
export var _cpu_local_storage: [0x2000]u8 align(0x1000) linksection(".bss") = zeroes([0x2000]u8);

pub fn Volatile(comptime T: type) type
{
    return extern struct
    {
        value: T,

        pub fn read_volatile(self: *const @This()) callconv(.Inline) T
        {
            return @ptrCast(*const volatile T, &self.value).*;
        }

        pub fn write_volatile(self: *@This(), value: T) callconv(.Inline) void
        {
            @ptrCast(*volatile T, &self.value).* = value;
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
        
        pub fn increment(self: *@This()) void
        {
            self.write_volatile(self.read_volatile() + 1);
        }

        pub fn decrement(self: *@This()) void
        {
            self.write_volatile(self.read_volatile() - 1);
        }

        pub fn atomic_compare_and_swap(self: *@This(), expected_value: T, new_value: T) ?T
        {
            return @cmpxchgStrong(@TypeOf(self.value), &self.value, expected_value, new_value, .SeqCst, .SeqCst);
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

export var timeStampCounterSynchronizationValue = Volatile(u64) { .value = 0 };

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
