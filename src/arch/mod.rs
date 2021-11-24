mod x86_64;
pub use self::x86_64::{Memory, AddressSpace, GetCurrentThread, ProcessorAreInterruptsEnabled, ProcessorEnableInterrupts, ProcessorDisableInterrupts, CPULocalStorage, GetLocalStorage, ProcessorFakeTimerInterrupt, PAGE_SIZE, early_allocate_page, map_page, MapPageFlags};

pub struct CPU
{
}


