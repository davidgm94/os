#include <stdint.h>
typedef uint64_t Handle;
extern "C" uintptr_t _syscall(uintptr_t arg0, uintptr_t arg1, uintptr_t arg2, uintptr_t unused, uintptr_t arg3, uintptr_t arg4);

inline uintptr_t syscall(uintptr_t arg0, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3, uintptr_t arg4)
{
    return _syscall(arg0, arg1, arg2, 0, arg3, arg4);
}

void exit_process(Handle process_handle, int32_t status)
{
    const uintptr_t exit_process = 0;
    syscall(exit_process, process_handle, status, 0, 0);
}

const Handle current_process = 0x11;
void exit_current_process(int32_t status)
{
    exit_process(current_process, 0);
}

extern "C" void _start()
{
    exit_current_process(0);
}
