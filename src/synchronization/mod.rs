use {VolatilePointer, Volatile};
use kernel;
use scheduler::{Thread, ThreadState, ThreadTerminatableState};
use scheduler;
use arch;
use panic;

#[repr(C)]
#[repr(align(8))]
pub struct Mutex
{
    data: [u8;32],
}

impl Mutex
{
    pub fn acquire(&mut self) -> bool
    {
        return unsafe { _KMutexAcquire(self as *mut _, 0 as *const u8, 0 as *const u8, 0)};
    }

    pub fn release(&mut self)
    {
        unsafe { _KMutexRelease(self as *mut _, 0 as *const u8, 0 as *const u8, 0) };
    }

    pub fn assert_locked(&mut self)
    {
        unsafe { KMutexAssertLocked(self as *mut _) };
    }

    pub const fn zeroed() -> Self
    {
        Self
        {
            data: [0;32]
        }
    }
}

extern "C"
{
    fn _KMutexAcquire(mutex: *mut Mutex, mutex_string: *const u8, file: *const u8, line: i32) -> bool;
    fn _KMutexRelease(mutex: *mut Mutex, mutex_string: *const u8, file: *const u8, line: i32);
    fn KMutexAssertLocked(mutex: *mut Mutex);
}

#[repr(C)]
pub struct Spinlock
{
    data: [u8;3],
}

impl Spinlock
{
    pub fn acquire(&mut self)
    {
        unsafe { KSpinlockAcquire(self as *mut _) };
    }
    pub fn release(&mut self)
    {
        unsafe { KSpinlockRelease(self as *mut _) };
    }
    pub fn release_forced(&mut self)
    {
        unsafe { KSpinlockReleaseForced(self as *mut _) };
    }
    pub fn assert_locked(&mut self)
    {
        unsafe { KSpinlockAssertLocked(self as *mut _) };
    }
    pub const fn zeroed() -> Self
    {
        Self
        {
            data: [0;3]
        }
    }
}

extern "C"
{
    fn KSpinlockAcquire(spinlock: *mut Spinlock);
    fn KSpinlockRelease(spinlock: *mut Spinlock);
    fn KSpinlockReleaseForced(spinlock: *mut Spinlock);
    fn KSpinlockAssertLocked(spinlock: *mut Spinlock);
}
//use core::sync::atomic::{AtomicU8, AtomicU64, Ordering, fence};

//pub struct Mutex
//{
    //pub owner_thread_id: Volatile<Option<u64>>, // thread id
    //// debug build
    //pub acquire_address: u64,
    //pub release_address: u64,
    //pub id: u64,
    //// end debug build
    //pub blocked_threads: [u64;64],
    //pub blocked_thread_count: u64,
//}

////impl Default for Mutex
////{
    ////fn default() -> Self {
        ////Self { owner_thread_id: Default::default(), acquire_address: Default::default(), release_address: Default::default(), id: Default::default(), blocked_threads: [0;64], blocked_thread_count: Default::default() }
    ////}
////}

//impl Mutex
//{
    //pub const fn zeroed() -> Self
    //{
        //Self
        //{
            //owner_thread_id: Volatile::<Option<u64>>::new(None),
            //acquire_address: 0,
            //release_address: 0,
            //id: 0,
            //blocked_threads: [0;64],
            //blocked_thread_count: 0,
        //}
    //}

    //pub fn acquire(&mut self) -> bool
    //{
        //unsafe { if kernel.scheduler.panic { return false } }
        //let thread = unsafe { arch::GetCurrentThread() };
        //let has_thread = !thread.is_null();
        
        //let current_thread =
        //{
            //if let Some(current_thread) = unsafe { arch::GetCurrentThread().as_mut() }
            //{
                //if current_thread.terminatable_state.read() == crate::scheduler::ThreadTerminatableState::terminatable { panic() }

                //if let Some(mutex_owner_thread_id) = self.owner_thread_id.read()
                //{
                    //if mutex_owner_thread_id == current_thread.id
                    //{
                        //panic();
                    //}
                //}

                //current_thread
            //}
            //else
            //{
                //unsafe { (1 as *mut Thread).as_mut().unwrap_unchecked() }
            //}
        //};

        //if unsafe { !arch::ProcessorAreInterruptsEnabled() } { panic() }

        //loop
        //{
            //unsafe { kernel.scheduler.dispatch_spinlock.acquire(); }

            //let old = self.owner_thread_id.read();
            //let old_thread_null = old.is_none();
            //if old_thread_null
            //{
                //self.owner_thread_id.write(Some(current_thread.id));
            //}
            //unsafe { kernel.scheduler.dispatch_spinlock.release(); }
            //if old_thread_null { break }

            //fence(Ordering::SeqCst);

            //if let Some(local_storage) = unsafe { arch::GetLocalStorage().as_ref() }
            //{
                //if local_storage.scheduler_ready
                //{
                    //if current_thread.state.read() != ThreadState::active
                    //{
                        //panic();
                    //}

                    //current_thread.blocking.mutex = (self as *mut _) as u64;
                    //fence(Ordering::SeqCst);

                    //current_thread.state.write(ThreadState::waiting_mutex);

                    //unsafe { kernel.scheduler.dispatch_spinlock.acquire(); }
                    //let spin = self.owner_thread_id.read().is_some() && unsafe { kernel.scheduler.get_thread(self.owner_thread_id.read().unwrap_unchecked()).as_ref().unwrap_unchecked() }.executing.read();
                    //unsafe { kernel.scheduler.dispatch_spinlock.release(); }

                    //if !spin && unsafe { (current_thread.blocking.mutex as *mut Mutex).as_ref().unwrap_unchecked().owner_thread_id.read().is_some() }
                    //{
                        //unsafe {arch::ProcessorFakeTimerInterrupt() }
                    //}

                    //while (!current_thread.terminating.read() || current_thread.terminatable_state.read() != ThreadTerminatableState::user_block_request) && self.owner_thread_id.read().is_some()
                    //{
                        //current_thread.state.write(ThreadState::waiting_mutex);
                    //}

                    //current_thread.state.write(ThreadState::active);

                    //if current_thread.terminating.read() && current_thread.terminatable_state.read().eq(&ThreadTerminatableState::user_block_request)
                    //{
                        //return false;
                    //}
                //}
            //}
        //}

        //fence(Ordering::SeqCst);

        //if self.owner_thread_id.read().unwrap() != current_thread.id
        //{
            //panic();
        //}

        ////self.acquire_address = unsafe { return_address() };
        //self.assert_locked();

        //if self.id == 0
        //{
            //self.id = NEXT_MUTEX_ID.fetch_add(1, Ordering::SeqCst);
        //}

        //return true;
    //}

    //pub fn release(&mut self)
    //{
        //unsafe { if kernel.scheduler.panic { return } }

        //self.assert_locked();

        //unsafe { kernel.scheduler.dispatch_spinlock.acquire(); }

        //if let Some(current_thread) = unsafe { arch::GetCurrentThread().as_ref() }
        //{
            //let temp_volatile = self.owner_thread_id.read().unwrap();
            //let temp = AtomicU64::new(temp_volatile);
            //if temp.compare_exchange(temp_volatile, current_thread.id, Ordering::SeqCst, Ordering::SeqCst).is_err()
            //{
                //panic();
            //}
            //assert!(self.owner_thread_id.read().unwrap() == current_thread.id);
        //}
        //else
        //{
            //self.owner_thread_id.write(None);
        //}

        //let preempt = self.blocked_thread_count > 0;

        //if unsafe { kernel.scheduler.started }
        //{
            //panic();
        //}

        //unsafe { kernel.scheduler.dispatch_spinlock.release(); }
        //fence(Ordering::SeqCst);

        ////self.release_address = unsafe { return_address() };

        //if preempt
        //{
            //unsafe { arch::ProcessorFakeTimerInterrupt() }
        //}
    //}

    //pub fn assert_locked(&self)
    //{
        //let current_thread = 
        //{
            //if let Some(current_thread) = unsafe { arch::GetCurrentThread().as_ref() }
            //{
                //current_thread
            //}
            //else
            //{
                //unsafe { (1 as *mut Thread).as_ref().unwrap_unchecked() }
            //}
        //};

        //if self.owner_thread_id.read().unwrap() != current_thread.id
        //{
            //panic();
        //}
    //}
//}

//pub static NEXT_MUTEX_ID: AtomicU64 = AtomicU64::new(0);

//pub struct Spinlock
//{
    //state: AtomicU8,
    //owner_cpu: Volatile<u8>,
    //interrupts_enabled: Volatile<bool>,
    //owner_thread_id: Volatile<Option<u64>>,
    //acquire_address: Volatile<u64>,
    //release_address: Volatile<u64>,
//}

//impl Spinlock
//{
    //pub fn acquire(&mut self)
    //{
        //unsafe { if kernel.scheduler.panic { return; } }

        //let interrupts_enabled = unsafe { arch::ProcessorAreInterruptsEnabled() };
        //unsafe { arch::ProcessorDisableInterrupts(); }
        
        //if let Some(local_storage) = unsafe { arch::GetLocalStorage().as_mut() }
        //{
            //if let Some(current_thread) = local_storage.current_thread
            //{
                //if let Some(spinlock_owner_thread) = self.owner_thread_id.read()
                //{
                    //if spinlock_owner_thread == current_thread
                    //{
                        //panic();
                    //}
                //}
            //}

            //local_storage.spinlock_count += 1;

            //loop
            //{
                //if self.state.compare_exchange(0, 1, Ordering::SeqCst, Ordering::SeqCst).is_ok()
                //{
                    //break
                //}
            //}

            //fence(Ordering::SeqCst);

            //self.interrupts_enabled.write(interrupts_enabled);

            //self.owner_thread_id.write(local_storage.current_thread);
            //self.owner_cpu.write(local_storage.processor_ID as u8);
        //}
        //else
        //{
            //loop
            //{
                //if self.state.compare_exchange(0, 1, Ordering::SeqCst, Ordering::SeqCst).is_ok()
                //{
                    //break
                //}
            //}
            //fence(Ordering::SeqCst);

            //self.interrupts_enabled.write(interrupts_enabled);
            //self.owner_thread_id.write(None);
        //}

        ////self.acquire_address.write(unsafe {return_address()});
    //}

    //fn release_internal(&mut self, force: bool)
    //{
        //unsafe { if kernel.scheduler.panic { return } }

        //let maybe_local_storage = unsafe { arch::GetLocalStorage() };
        //if let Some(local_storage) = unsafe { maybe_local_storage.as_mut() }
        //{
            //local_storage.spinlock_count -= 1;
        //}

        //if !force
        //{
            //self.assert_locked();
        //}

        //let mut were_interrupts_enabled = Volatile::<bool>
        //{
            //value: self.interrupts_enabled.read(),
        //};

        //self.owner_thread_id.write(None);

        //fence(Ordering::SeqCst);

        //self.state.store(0, Ordering::SeqCst);

        //if were_interrupts_enabled.read()
        //{
            //unsafe { arch::ProcessorEnableInterrupts() }
        //}
        ////self.release_address.write(unsafe { return_address()});
    //}

    //pub fn release(&mut self)
    //{
        //self.release_internal(false);
    //}

    //pub fn release_forced(&mut self)
    //{
        //self.release_internal(true);
    //}

    //pub fn assert_locked(&self)
    //{
        //unsafe { if kernel.scheduler.panic { return } }

        //if self.state.load(Ordering::SeqCst) == 0 { panic() }
        //if unsafe { arch::ProcessorAreInterruptsEnabled() } { panic() }
        //if let Some(local_storage) = unsafe { arch::GetLocalStorage().as_ref() }
        //{
            //if self.owner_thread_id.read() != local_storage.current_thread
            //{
                //panic()
            //}
        //}
    //}

    //pub const fn zeroed() -> Self
    //{
        //return Self
        //{
            //state: AtomicU8::new(0),
            //owner_cpu: Volatile::<u8>
            //{
                //value: 0,
            //},
            //interrupts_enabled: Volatile::<bool>
            //{
                //value: false,
            //},
            //owner_thread_id: Volatile::<Option<u64>>
            //{
                //value: None,
            //},
            //acquire_address: Volatile::<u64>
            //{
                //value: 0,
            //},
            //release_address: Volatile::<u64>
            //{
                //value: 0,
            //},
        //};
    //}
//}
//


