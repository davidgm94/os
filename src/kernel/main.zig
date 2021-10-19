export fn kernel_main() noreturn
{
    while (true) {}
}

export fn interrupt_handler() noreturn
{
    while (true) {}
}

export fn syscall(argument0: u64, argument1: u64, argument2: u64, return_address: u64, argument3: u64, argument4: u64, user_stack_pointer: *u64) u64
{
    _ = argument0;
    _ = argument1;
    _ = argument2;
    _ = argument3;
    _ = argument4;
    _ = return_address;
    _ = user_stack_pointer;
    if (true) unreachable;
    return 0;
}
