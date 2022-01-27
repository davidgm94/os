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
export var _kernelProcess: Process = undefined;
export var _desktopProcess: Process = undefined;
export var kernelProcess: *Process = undefined;
export var desktopProcess: *Process = undefined;

extern fn ProcessorAreInterruptsEnabled() callconv(.C) bool;
extern fn ProcessorEnableInterrupts() callconv(.C) void;
extern fn ProcessorDisableInterrupts() callconv(.C) void;
extern fn ProcessorFakeTimerInterrupt() callconv(.C) void;
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

//fn UnalignedVolatilePointer(comptime T: type) type
//{
    //return VolatilePointerExtended(T, 1);
//}

//fn VolatilePointer(comptime T: type) type
//{
    //return VolatilePointerExtended(T, null);
//}

//fn VolatilePointerExtended(comptime T: type, comptime alignment: ?comptime_int) type
//{
    //return extern struct
    //{
        //ptr: ?PtrType,

        //const PtrType = *volatile align(if (alignment) |alignment_nn| alignment_nn else @alignOf(T)) T;

        //fn equal(self: *volatile @This(), other: ?PtrType) bool
        //{
            //return self.ptr == other;
        //}

        //fn dereference(self: *volatile @This()) T
        //{
            //return self.ptr.?.*;
        //}

        //fn overwrite(self: *volatile @This(), ptr: ?PtrType) void
        //{
            //self.ptr = ptr;
        //}

        //fn access(self: *volatile @This()) PtrType
        //{
            //return self.ptr.?;
        //}

        //fn get(self: *volatile @This()) ?PtrType
        //{
            //return self.ptr;
        //}

        //fn is_null(self: *volatile @This()) bool
        //{
            //return self.ptr == null;
        //}

        //fn atomic_compare_and_swap(self: *volatile @This(), expected_value: ?PtrType, new_value: ?PtrType) ??PtrType
        //{
            //return @cmpxchgStrong(?PtrType, @ptrCast(*?PtrType, &self.ptr), expected_value, new_value, .SeqCst, .SeqCst);
        //}
    //};
//}

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
};

extern fn SchedulerYield(context: *InterruptContext) callconv(.C) void;
extern fn SchedulerCreateProcessorThreads(local: *LocalStorage) callconv(.C) void;
extern fn SchedulerAddActiveThread(thread: *Thread, start: bool) callconv(.C) void;
extern fn SchedulerMaybeUpdateActiveList(thread: *Thread) callconv(.C) void;
extern fn SchedulerNotifyObject(blocked_threads: *LinkedList(Thread), unblock_all: bool, previous_mutex_owner: ?*Thread) callconv(.C) void;
extern fn SchedulerUnblockThread(thread: *Thread, previous_mutex_owner: ?*Thread) callconv(.C) void;
extern fn SchedulerPickThread(local: *LocalStorage) callconv(.C) ?*Thread;
extern fn SchedulerGetThreadEffectivePriority(thread: *Thread) callconv(.C) i8;

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

    name: [*:0]const u8,

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

export fn KTimerSet(timer: *Timer, trigger_in_ms: u64, callback: ?AsyncTask.Callback, argument: u64) callconv(.C) void
{
    timer.set_extended(trigger_in_ms, callback, argument);
}

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

extern fn ProcessSpawn(process_type: Process.Type) callconv(.C) ?*Process;

pub const Heap = extern struct
{
    mutex: Mutex,
    regions: [12]?*HeapRegion,
    allocation_count: Volatile(u64),
    size: Volatile(u64),
    block_count: Volatile(u64),
    blocks: [16]?*HeapRegion,
    cannot_validate: bool,

    //pub fn allocate(self: *@This(), asked_size: u64, zero_memory: bool) u64
    //{
        //if (@bitCast(i64, asked_size) < 0) KernelPanic("heap panic");

        //const size = (asked_size + HeapRegion.used_header_size + 0x1f) & ~@as(u64, 0x1f);

        //if (size >= large_allocation_threshold)
        //{
            //if (@intToPtr(?*HeapRegion, self.allocate_call(size))) |region|
            //{
                //region.used = HeapRegion.used_magic;
                //region.u1.size = 0;
                //region.u2.allocation_size = asked_size;
                //_ = self.size.atomic_fetch_add(asked_size);
                //return region.get_data();
            //}
            //else
            //{
                //return 0;
            //}
        //}

        //_ = self.mutex.acquire();

        //self.validate();

        //const region = blk:
        //{
            //var heap_index = heap_calculate_index(size);
            //if (heap_index < self.regions.len)
            //{
                //for (self.regions[heap_index..]) |maybe_heap_region|
                //{
                    //if (maybe_heap_region) |heap_region|
                    //{
                        //if (heap_region.u1.size >= size)
                        //{
                            //const result = heap_region;
                            //result.remove_free();
                            //break :blk result;
                        //}
                    //}
                //}
            //}

            //const allocation = @intToPtr(?*HeapRegion, self.allocate_call(65536));
            //if (self.block_count.read_volatile() < 16)
            //{
                //self.blocks[self.block_count.read_volatile()] = allocation;
            //}
            //else
            //{
                //self.cannot_validate = true;
            //}
            //self.block_count.increment();

            //if (allocation) |result|
            //{
                //result.u1.size = 65536 - 32;
                //const end_region = result.get_next().?;
                //end_region.used = HeapRegion.used_magic;
                //end_region.offset = 65536 - 32;
                //end_region.u1.next = 32;
                //@intToPtr(?*?*Heap, end_region.get_data()).?.* = self;

                //break :blk result;
            //}
            //else
            //{
                //// it failed
                //self.mutex.release();
                //return 0;
            //}
        //};

        //if (region.used != 0 or region.u1.size < size) KernelPanic("heap panic\n");

        //self.allocation_count.increment();
        //_ = self.size.atomic_fetch_add(size);

        //if (region.u1.size != size)
        //{
            //const old_size = region.u1.size;
            //assert(size <= std.math.maxInt(u16));
            //const truncated_size = @intCast(u16, size);
            //region.u1.size = truncated_size;
            //region.used = HeapRegion.used_magic;

            //const free_region = region.get_next().?;
            //free_region.u1.size = old_size - truncated_size;
            //free_region.previous = truncated_size;
            //free_region.offset = region.offset + truncated_size;
            //free_region.used = 0;
            //self.add_free_region(free_region);

            //const next_region = free_region.get_next().?;
            //next_region.previous = free_region.u1.size;

            //self.validate();
        //}

        //region.used = HeapRegion.used_magic;
        //region.u2.allocation_size = asked_size;
        //self.mutex.release();

        //const address = region.get_data();
        //const memory = @intToPtr([*]u8, address)[0..asked_size];
        //if (zero_memory)
        //{
            //std.mem.set(u8, memory, 0);
        //}
        //else
        //{
            //std.mem.set(u8, memory, 0xa1);
        //}

        //return address;
    //}

    //fn allocateT(self: *@This(), comptime T: type, zero_memory: bool) callconv(.Inline) ?*T
    //{
        //return @intToPtr(?*T, self.allocate(@sizeOf(T), zero_memory));
    //}

    //fn add_free_region(self: *@This(), region: *HeapRegion) void
    //{
        //if (region.used != 0 or region.u1.size < 32)
        //{
            //KernelPanic("heap panic\n");
        //}

        //const index = heap_calculate_index(region.u1.size);
        //region.u2.region_list_next = self.regions[index];
        //if (region.u2.region_list_next) |region_list_next|
        //{
            //region_list_next.region_list_reference = &region.u2.region_list_next;
        //}
        //self.regions[index] = region;
        //region.region_list_reference = &self.regions[index];
    //}

    //fn allocate_call(self: *@This(), size: u64) u64
    //{
        //if (self == &kernel.core.heap)
        //{
            //return kernel.core.address_space.standard_allocate(size, Region.Flags.from_flag(.fixed));
        //}
        //else
        //{
            //return kernel.process.address_space.standard_allocate(size, Region.Flags.from_flag(.fixed));
        //}
    //}

    //fn free_call(self: *@This(), region: *HeapRegion) void
    //{
        //if (self == &kernel.core.heap)
        //{
            //_ = kernel.core.address_space.free(@ptrToInt(region));
        //}
        //else
        //{
            //_ = kernel.process.address_space.free(@ptrToInt(region));
        //}
    //}

    //pub fn free(self: *@This(), address: u64, expected_size: u64) void
    //{
        //if (address == 0 and expected_size != 0) KernelPanic("heap panic");
        //if (address == 0) return;

        //var region = @intToPtr(*HeapRegion, address).get_header().?;
        //if (region.used != HeapRegion.used_magic) KernelPanic("heap panic");
        //if (expected_size != 0 and region.u2.allocation_size != expected_size) KernelPanic("heap panic");

        //if (region.u1.size == 0)
        //{
            //_ = self.size.atomic_fetch_sub(region.u2.allocation_size);
            //self.free_call(region);
            //return;
        //}

        //{
            //const first_region = @intToPtr(*HeapRegion, @ptrToInt(region) - region.offset + 65536 - 32);
            //if (@intToPtr(**Heap, first_region.get_data()).* != self) KernelPanic("heap panic");
        //}

        //_ = self.mutex.acquire();

        //self.validate();

        //region.used = 0;

        //if (region.offset < region.previous) KernelPanic("heap panic");

        //self.allocation_count.decrement();
        //_ = self.size.atomic_fetch_sub(region.u1.size);

        //if (region.get_next()) |next_region|
        //{
            //if (next_region.used == 0)
            //{
                //next_region.remove_free();
                //region.u1.size += next_region.u1.size;
                //next_region.get_next().?.previous = region.u1.size;
            //}
        //}

        //if (region.get_previous()) |previous_region|
        //{
            //if (previous_region.used == 0)
            //{
                //previous_region.remove_free();

                //previous_region.u1.size += region.u1.size;
                //region.get_next().?.previous = previous_region.u1.size;
                //region = previous_region;
            //}
        //}

        //if (region.u1.size == 65536 - 32)
        //{
            //if (region.offset != 0) KernelPanic("heap panic");

            //self.block_count.decrement();

            //if (!self.cannot_validate)
            //{
                //var found = false;
                //for (self.blocks[0..self.block_count.read_volatile() + 1]) |*heap_region|
                //{
                    //if (heap_region.* == region)
                    //{
                        //heap_region.* = self.blocks[self.block_count.read_volatile()];
                        //found = true;
                        //break;
                    //}
                //}

                //assert(found);
            //}

            //self.free_call(region);
            //self.mutex.release();
            //return;
        //}

        //self.add_free_region(region);
        //self.validate();
        //self.mutex.release();
    //}

    //fn validate(self: *@This()) void
    //{
        //if (self.cannot_validate) return;

        //for (self.blocks[0..self.block_count.read_volatile()]) |maybe_start, i|
        //{
            //if (maybe_start) |start|
            //{
                //const end = @intToPtr(*HeapRegion, @ptrToInt(self.blocks[i]) + 65536);
                //var maybe_previous: ?* HeapRegion = null;
                //var region = start;

                //while (@ptrToInt(region) < @ptrToInt(end))
                //{
                    //if (maybe_previous) |previous|
                    //{
                        //if (@ptrToInt(previous) != @ptrToInt(region.get_previous()))
                        //{
                            //KernelPanic("heap panic\n");
                        //}
                    //}
                    //else
                    //{
                        //if (region.previous != 0) KernelPanic("heap panic\n");
                    //}

                    //if (region.u1.size & 31 != 0) KernelPanic("heap panic");

                    //if (@ptrToInt(region) - @ptrToInt(start) != region.offset)
                    //{
                        //KernelPanic("heap panic\n");
                    //}

                    //if (region.used != HeapRegion.used_magic and region.used != 0)
                    //{
                        //KernelPanic("heap panic");
                    //}

                    //if (region.used == 0 and region.region_list_reference == null)
                    //{
                        //KernelPanic("heap panic\n");
                    //}

                    //if (region.used == 0 and region.u2.region_list_next != null and region.u2.region_list_next.?.region_list_reference != &region.u2.region_list_next)
                    //{
                        //KernelPanic("heap panic");
                    //}

                    //maybe_previous = region;
                    //region = region.get_next().?;
                //}

                //if (region != end)
                //{
                    //KernelPanic("heap panic");
                //}
            //}
        //}
    //}

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

    //const large_allocation_threshold = 32768;
};

export var heapCore: Heap = undefined;
export var heapFixed: Heap = undefined;

extern fn EsHeapAllocate(size: u64, zeroMemory: bool, heap: *Heap) callconv(.C) u64;
extern fn EsHeapReallocate(old_address: u64, new_allocation_size: u64, zero_new_space: bool, heap: *Heap) callconv(.C) u64;
extern fn EsHeapFree(address: u64, expectedSize: u64, heap: *Heap) callconv(.C) void;

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

    //fn remove_free(self: *@This()) void
    //{
        //if (self.region_list_reference == null or self.used != 0) KernelPanic("heap panic\n");

        //self.region_list_reference.?.* = self.u2.region_list_next;

        //if (self.u2.region_list_next) |region_list_next|
        //{
            //region_list_next.region_list_reference = self.region_list_reference;
        //}
        //self.region_list_reference = null;
    //}

    //fn get_header(self: *@This()) ?*HeapRegion
    //{
        //return @intToPtr(?*HeapRegion, @ptrToInt(self) - used_header_size);
    //}

    //fn get_data(self: *@This()) u64
    //{
        //return @ptrToInt(self) + used_header_size;
    //}

    //fn get_next(self: *@This()) ?*HeapRegion
    //{
        //return @intToPtr(?*HeapRegion, @ptrToInt(self) + self.u1.next);
    //}

    //fn get_previous(self: *@This()) ?*HeapRegion
    //{
        //if (self.previous != 0)
        //{
            //return @intToPtr(?*HeapRegion, @ptrToInt(self) - self.previous);
        //}
        //else
        //{
            //return null;
        //}
    //}
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
        ptr: ?[*]T,

        fn length(self: @This()) u64
        {
            return ArrayHeaderGetLength(@ptrCast(?*u64, self.ptr));
        }

        fn get_slice(self: @This()) []T
        {
            return self.ptr.?[0..self.length()];
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
    };
};

extern fn RangeSetFind(range_set: *Range.Set, offset: u64, touching: bool) callconv(.C) ?*Range;
extern fn RangeSetContains(range_set: *Range.Set, offset: u64) callconv(.C) bool;
extern fn RangeSetValidate(range_set: *Range.Set) callconv(.C) void;
extern fn RangeSetClear(range_set: *Range.Set, from: u64, to: u64, delta: ?*i64, modify: bool) callconv(.C) bool;
extern fn RangeSetSet(range_set: *Range.Set, from: u64, to: u64, delta: ?*i64, modify: bool) callconv(.C) bool;
extern fn RangeSetNormalize(range_set: *Range.Set) callconv(.C) bool;

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

    if (@intToPtr(?*ArrayHeader, EsHeapReallocate(@ptrToInt(old_header) - additional_header_bytes, @sizeOf(ArrayHeader) + additional_header_bytes + item_size * minimum_allocated, false, heap))) |new_header|
    {
        new_header.allocated = minimum_allocated;
        array.* = @intToPtr(?*u64, @ptrToInt(new_header) + @sizeOf(ArrayHeader) + additional_header_bytes);
        return true;
    }
    else
    {
        return false;
    }
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

extern fn drivers_init() callconv(.C) void;
extern fn start_desktop_process() callconv(.C) void;

export var shutdownEvent: Event = undefined;

export fn KernelMain(_: u64) callconv(.C) void
{
    desktopProcess = ProcessSpawn(.desktop).?;
    drivers_init();

    start_desktop_process();
    _ = shutdownEvent.wait();
}

extern fn MMInitialise() callconv(.C) void;
extern fn ArchInitialise() callconv(.C) void;
extern fn CreateMainThread() callconv(.C) void;
export fn KThreadCreate(name: [*:0]const u8, entry: fn (u64) callconv(.C) void, argument: u64) callconv(.C) bool
{
    return ThreadSpawn(name, @ptrToInt(entry), argument, Thread.Flags.empty(), null, 0) != null;
}

extern fn MMStandardAllocate(space: *AddressSpace, bytes: u64, flags: Region.Flags, base_address: u64, commit_all: bool) callconv(.C) u64;
extern fn MMCommitRange(space: *AddressSpace, region: *Region, page_offset: u64, page_count: u64) callconv(.C) bool;
extern fn OpenHandleToObject(object: u64, type: u32, flags: u32) callconv(.C) bool;
extern fn MMFindAndPinRegion(address_space: *AddressSpace, address: u64, size: u64) callconv(.C) ?*Region;
extern fn ArchInitialiseThread(kernel_stack: u64, kernel_stack_size: u64, thread: *Thread, start_address: u64, argument1: u64, argument2: u64, userland: bool, user_stack: u64, user_stack_size: u64) callconv(.C) *InterruptContext;
extern fn MMFree(space: *AddressSpace, address: u64, expected_size: u64, user_only: bool) callconv(.C) bool;

export fn ThreadSpawn(name: [*:0]const u8, start_address: u64, argument1: u64, flags: Thread.Flags, maybe_process: ?*Process, argument2: u64) callconv(.C) ?*Thread
{
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
        thread.name = name;
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
        _ = OpenHandleToObject(@ptrToInt(process), 1, 0);

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

    //pub fn init(self: *@This(), count: u64, map_all: bool) void
    //{
        //self.single_usage.len = (count + 31) & ~@as(u64, 31);
        //self.group_usage.len = self.single_usage.len / group_size + 1;
        //self.single_usage.ptr = @intToPtr([*]u32, kernel.process.address_space.standard_allocate((self.single_usage.len >> 3) + (self.group_usage.len * 2), if (map_all) memory.Region.Flags.from_flag(.fixed) else memory.Region.Flags.empty()));
        //self.group_usage.ptr = @intToPtr([*]u16, @ptrToInt(self.single_usage.ptr) + ((self.single_usage.len >> 4) * @sizeOf(u16)));
    //}

    //pub fn put(self: *@This(), index: u64) void
    //{
        //self.single_usage[index >> 5] |= @as(u32, 1) << @truncate(u5, index);
        //self.group_usage[index / group_size] += 1;
    //}

    //pub fn take(self: *@This(), index: u64) void
    //{
        //const group = index / group_size;
        //self.group_usage[group] -= 1;
        //self.single_usage[index >> 5] &= ~(@as(u32, 1) << @truncate(u5, index));
    //}

    const group_size = 0x1000;
};


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
    };

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

extern fn MMArchUnmapPages(address_space: *AddressSpace, virtual_address_start: u64, page_count: u64, flags: UnmapPagesFlags, unmap_maximum: u64, resume_position: ?*u64) callconv(.C) void;

const ActiveSession = extern struct
{
    load_complete_event: Event,
    write_complete_event: Event,
    list_item: LinkedList(ActiveSession).Item,
    offset: u64,
    cache: ?*CCSpace,
    accessors: u64,
    loading: Volatile(bool),
    writing: Volatile(bool),
    modified: Volatile(bool),
    flush: Volatile(bool),
    referenced_page_count: u64,
    referenced_pages: [ActiveSession.size / page_size / 8]u8,
    modified_pages: [ActiveSession.size / page_size / 8]u8,

    const size = 262144;

    const Manager = extern struct
    {
        sections: [*]ActiveSession,
        section_count: u64,
        base_address: u64,
        mutex: Mutex,
        LRU_list: LinkedList(ActiveSession),
        modified_list: LinkedList(ActiveSession),
        modified_non_empty_event: Event,
        modified_non_full_event: Event,
        modified_getting_full_event: Event,
        write_back_thread: ?*Thread,
    };
};

const Error = i64;

const CCSpace = extern struct
{
    cached_sections_mutex: Mutex,
    cached_sections: Array(CCCachedSection, .core),
    active_sections_mutex: Mutex,
    active_sections: Array(CCActiveSectionReference, .core),
    write_complete_event: Event,
    callbacks: ?*Callbacks,

    const Callbacks = extern struct
    {
        read_into: fn(file_cache: *CCSpace, buffer: u64, offset: u64, count: u64) callconv(.C) Error,
        write_from: fn(file_cache: *CCSpace, buffer: u64, offset: u64, count: u64) callconv(.C) Error,
    };
};

const CCCachedSection = extern struct
{
    offset: u64,
    page_count: u64,
    mapped_region_count: Volatile(u64),
    data: ?[*]u64,
};

export var activeSessionManager: ActiveSession.Manager = undefined;

export fn CCDereferenceActiveSection(section: *ActiveSession, starting_page: u64) callconv(.C) void
{
    activeSessionManager.mutex.assert_locked();

    if (starting_page == 0)
    {
        MMArchUnmapPages(&_kernelMMSpace, activeSessionManager.base_address + ((@ptrToInt(section) - @ptrToInt(activeSessionManager.sections)) / @sizeOf(ActiveSession)) * ActiveSession.size, ActiveSession.size / page_size, UnmapPagesFlags.from_flag(.balance_file), 0, null);
        std.mem.set(u8, section.referenced_pages[0..], 0);
        std.mem.set(u8, section.modified_pages[0..], 0);
        section.referenced_page_count = 0;
    }
    else
    {
        MMArchUnmapPages(&_kernelMMSpace, activeSessionManager.base_address + ((@ptrToInt(section) - @ptrToInt(activeSessionManager.sections)) / @sizeOf(ActiveSession)) * ActiveSession.size + starting_page * page_size, ActiveSession.size / page_size - starting_page, UnmapPagesFlags.from_flag(.balance_file), 0, null);

        var i = starting_page;
        while (i < ActiveSession.size / page_size) : (i += 1)
        {
            const index = i >> 3;
            const shifter = @as(u8, 1) << @truncate(u3, i);

            if (section.referenced_pages[index] & shifter != 0)
            {
                section.referenced_pages[index] &= ~shifter;
                section.modified_pages[index] &= ~shifter;
                section.referenced_page_count -= 1;
            }
        }
    }
}

const CCActiveSectionReference = extern struct
{
    offset: u64,
    index: u64,
};

export fn CCFindCachedSectionContaining(cache: *CCSpace, section_offset: u64) ?*CCCachedSection
{
    cache.cached_sections_mutex.assert_locked();

    if (cache.cached_sections.length() == 0) return null;

    var low: i64 = 0;
    var high: i64 = @intCast(i64, cache.cached_sections.length()) - 1;

    var found = false;
    var cached_section: *CCCachedSection = undefined;

    while (low <= high)
    {
        const i = low + @divTrunc(high - low,  2);
        cached_section = &cache.cached_sections.ptr.?[@intCast(u64, i)];
        if (cached_section.offset + cached_section.page_count * page_size <= section_offset) low = i + 1
        else if (cached_section.offset > section_offset) high = i - 1
        else
        {
            found = true;
            break;
        }
    }

    return if (found) cached_section else null;
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

extern fn MMArchTranslateAddress(_: *AddressSpace, virtual_address: u64, write_access: bool) callconv(.C) u64;
extern fn MMArchMapPage(space: *AddressSpace, physical_address: u64, virtual_address: u64, flags: MapPageFlags) callconv(.C) bool;
extern fn MMPhysicalAllocate(flags: Physical.Flags, count: u64, alignment: u64, below: u64) callconv(.C) u64;
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

    if (MMArchTranslateAddress(space, address, flags.contains(.write)) != 0) return true;

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

export fn KernelInitialise() callconv(.C) void
{
    kernelProcess = &_kernelProcess;
    desktopProcess = &_desktopProcess;
    kernelProcess = ProcessSpawn(.kernel).?;
    MMInitialise();
    // Currently it felt impossible to pass arguments to this function
    CreateMainThread();
    ArchInitialise();
    scheduler.started.write_volatile(true);
}

export fn get_size_zig() callconv(.C) u64
{
    return @sizeOf(Region);
}
