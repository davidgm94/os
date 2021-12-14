#include <stdint.h>
typedef uint64_t Handle;
extern "C" uintptr_t _syscall(uintptr_t argument0, uintptr_t argument1, uintptr_t argument2, uintptr_t unused, uintptr_t argument3, uintptr_t argument4);
extern "C" uintptr_t syscall(uintptr_t a, uintptr_t b, uintptr_t c, uintptr_t d, uintptr_t e)
{
    return _syscall((a), (b), (c), 0, (d), (e));
}

void exit_process(Handle process_handle, int32_t status)
{
    const uintptr_t exit_process = 0;
    syscall(exit_process, process_handle, status, 0, 0);
}

extern "C" void _start()
{
    const uint64_t current_process = 0x11;
    exit_process(current_process, 0);
}
