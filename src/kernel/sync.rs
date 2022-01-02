use kernel::*;
use crate::kernel::scheduler::{ThreadState, ThreadTerminatableState};

pub struct Spinlock
{
    state: Volatile<AtomicU8>,
    interrupts_enabled: Volatile<bool>,
    owner_CPU: Volatile<u8>,
}

impl const Default for Spinlock
{
    fn default() -> Self {
        Self
        {
            state: Volatile::new(AtomicU8::new(0)),
            interrupts_enabled: Volatile::new(false),
            owner_CPU: Volatile::new(0),
        }
    }
}

#[derive(Copy, Clone)]
pub struct Mutex
{
    pub owner: VolatilePointer<Thread>,
}

impl const Default for Mutex
{
    fn default() -> Self {
        Self
        {
            owner: VolatilePointer::<Thread>::new(0 as *mut Thread),
        }
    }
}

#[derive(Copy, Clone)]
pub struct WriterLock
{
}

#[derive(Copy, Clone)]
pub struct Event
{
}

impl Spinlock
{
    // debug builds
    pub fn acquire(&mut self)
    {
        if unsafe { kernel.scheduler.panic } { return }

        let interrupts_enabled = arch::interrupts::are_enabled();
        arch::interrupts::disable();

        let storage = arch::get_local_storage();
        if let Some(local_storage) = unsafe { storage.as_mut() }
        {
            local_storage.spinlock_count += 1;
        }

        #[allow(deprecated)]
        while self.state.value.compare_and_swap(0, 1, Ordering::SeqCst) != 0 { }
        fence(Ordering::SeqCst);

        self.interrupts_enabled.write(interrupts_enabled);

        if let Some(local_storage) = unsafe { storage.as_mut() }
        {
            // @TODO: possible error?
            self.owner_CPU.write(local_storage.processor_ID as u8);
        }
    }

    pub fn release(&mut self)
    {
        if unsafe { kernel.scheduler.panic } { return }

        let storage = arch::get_local_storage();
        if let Some(local_storage) = unsafe { storage.as_mut() }
        {
            local_storage.spinlock_count -= 1;
        }

        self.assert_locked();

        let were_interrupts_enabled = self.interrupts_enabled.read();
        fence(Ordering::SeqCst);
        *self.state.value.get_mut() = 0;

        if were_interrupts_enabled { arch::interrupts::enable() }
    }

    pub fn release_forced(&mut self)
    {
        if unsafe { kernel.scheduler.panic } { return }

        let storage = arch::get_local_storage();
        if let Some(local_storage) = unsafe { storage.as_mut() }
        {
            local_storage.spinlock_count -= 1;
        }

        let were_interrupts_enabled = self.interrupts_enabled.read();
        fence(Ordering::SeqCst);
        *self.state.value.get_mut() = 0;

        if were_interrupts_enabled { arch::interrupts::enable() }
    }

    pub fn assert_locked(&mut self)
    {
        if unsafe { kernel.scheduler.panic } { return }
        if self.state.read().into_inner() == 0 || arch::interrupts::are_enabled()
        {
            panic("Spinlock not correclty acquired\n");
        }
    }
}

impl Mutex
{
    pub fn acquire(&mut self) -> bool
    {
        if unsafe { kernel.scheduler.panic } { return false }

        let current_thread =
        {
            if let Some(thread) = unsafe { arch::get_current_thread().as_mut() }
            {
                if thread.terminatable_state.read() == ThreadTerminatableState::terminatable
                {
                    panic("thread is terminatable\n");
                }

                if self.owner.ptr == thread as *mut _
                {
                    panic("attempt to acquire mutex owned by current thread\n");
                }

                thread
            }
            else
            {
                unsafe { (1 as *mut Thread).as_mut().unwrap_unchecked() }
            }
        };

        if !arch::interrupts::are_enabled()
        {
            panic("trying to acquire a mutex while interrupts are disabled\n");
        }

        loop
        {
            unsafe { kernel .scheduler.dispatch_spinlock.acquire() }

            if self.owner.ptr.is_null()
            {
                self.owner.ptr = current_thread;
                unsafe { kernel .scheduler.dispatch_spinlock.release() };
                break;
            }
            else
            {
                unsafe { kernel .scheduler.dispatch_spinlock.release() };
            }

            fence(Ordering::SeqCst);

            if let Some(local_storage) = unsafe { arch::get_local_storage().as_ref() }
            {
                if local_storage.scheduler_ready
                {
                    if current_thread.state.read() != ThreadState::active
                    {
                        panic("attempting to wait on a mutex in a non-active thread\n");
                    }

                    current_thread.blocking.mutex.ptr = self;
                    fence(Ordering::SeqCst);

                    unsafe { kernel .scheduler.dispatch_spinlock.acquire() }

                    let spin =
                    {
                        if !self.owner.ptr.is_null()
                        {
                            self.owner.read().executing.read()
                        }
                        else
                        {
                            false
                        }
                    };

                    if !spin && !current_thread.blocking.mutex.read().owner.ptr.is_null()
                    {
                        unimplemented!();
                    }

                    while (!current_thread.terminating.read() || current_thread.terminatable_state.read() != ThreadTerminatableState::user_block_request)
                        && !self.owner.ptr.is_null()
                    {
                        current_thread.state.write(ThreadState::waiting_for_mutex);
                    }

                    current_thread.state.write(ThreadState::active);

                    if current_thread.terminating.read() && current_thread.terminatable_state.read() == ThreadTerminatableState::user_block_request
                    {
                        return false
                    }
                }
            }
        }

        fence(Ordering::SeqCst);

        if self.owner.ptr != current_thread as *mut _
        {
            panic("invalid owner thread\n");
        }

        return true
    }

    pub fn assert_locked(&self)
    {
        unimplemented!();
    }
}
