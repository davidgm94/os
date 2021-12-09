//#define DEBUG_BUILD
#define ES_BITS_64
#define ES_ARCH_X86_64
#define KERNEL
#define TREE_VALIDATE
#define K_ARCH_STACK_GROWS_DOWN

#include <stdint.h>
#include <stddef.h>
#include <stdarg.h>

#define ES_PTR64_MS32(x) ((uint32_t) ((uintptr_t) (x) >> 32))
#define ES_PTR64_LS32(x) ((uint32_t) ((uintptr_t) (x) & 0xFFFFFFFF))

#define K_NOT_IMPLEMENTED() KernelPanic("Not implemented. Function: %s. File: %s. Line: %d\n", __func__, __FILE__, __LINE__)

typedef uint64_t uint64_t_unaligned __attribute__((aligned(1)));
typedef uint32_t uint32_t_unaligned __attribute__((aligned(1)));

typedef int64_t EsListViewIndex;
typedef uintptr_t EsHandle;
typedef uint64_t EsObjectID;
typedef uint64_t EsFileOffset;
typedef intptr_t EsError;
typedef uint8_t EsNodeType;
typedef int64_t EsFileOffsetDifference;
typedef uint64_t _EsLongConstant;

extern uint32_t kernel_size;

enum KernelObjectType : uint32_t {
	COULD_NOT_RESOLVE_HANDLE	= 0x00000000,
	KERNEL_OBJECT_NONE		= 0x80000000,

	KERNEL_OBJECT_PROCESS 		= 0x00000001, // A process.
	KERNEL_OBJECT_THREAD		= 0x00000002, // A thread.
	KERNEL_OBJECT_WINDOW		= 0x00000004, // A window.
	KERNEL_OBJECT_SHMEM		= 0x00000008, // A region of shared memory.
	KERNEL_OBJECT_NODE		= 0x00000010, // A file system node (file or directory).
	KERNEL_OBJECT_EVENT		= 0x00000020, // A synchronisation event.
	KERNEL_OBJECT_CONSTANT_BUFFER	= 0x00000040, // A buffer of unmodifiable data stored in the kernel's address space.
#ifdef ENABLE_POSIX_SUBSYSTEM
	KERNEL_OBJECT_POSIX_FD		= 0x00000100, // A POSIX file descriptor, used in the POSIX subsystem.
#endif
	KERNEL_OBJECT_PIPE		= 0x00000200, // A pipe through which data can be sent between processes, blocking when full or empty.
	KERNEL_OBJECT_EMBEDDED_WINDOW	= 0x00000400, // An embedded window object, referencing its container Window.
	KERNEL_OBJECT_CONNECTION	= 0x00004000, // A network connection.
	KERNEL_OBJECT_DEVICE		= 0x00008000, // A device.
};


#define ES_PERMISSION_NETWORKING				(1 << 0)
#define ES_PERMISSION_PROCESS_CREATE			(1 << 1)
#define ES_PERMISSION_PROCESS_OPEN			(1 << 2)
#define ES_PERMISSION_SCREEN_MODIFY			(1 << 3)	
#define ES_PERMISSION_SHUTDOWN				(1 << 4)
#define ES_PERMISSION_TAKE_SYSTEM_SNAPSHOT		(1 << 5)
#define ES_PERMISSION_GET_VOLUME_INFORMATION		(1 << 6)
#define ES_PERMISSION_WINDOW_MANAGER			(1 << 7)
#define ES_PERMISSION_POSIX_SUBSYSTEM			(1 << 8)
#define ES_PERMISSION_ALL				((_EsLongConstant) (-1))
#define ES_PERMISSION_INHERIT				((_EsLongConstant) (1) << 63)


#define EsLiteral(x) (char *) x, EsCStringLength((char *) x)
#define EsAssert(x) do { if (!(x)) { EsAssertionFailure(__FILE__, __LINE__); } } while (0)
#define EsCRTassert EsAssert

#define ES_MEMORY_MOVE_BACKWARDS -


struct EsHeap;
#define K_CORE (&heapCore)
#define K_FIXED (&heapFixed)
#define K_PAGED (&heapFixed)
extern EsHeap heapCore;
extern EsHeap heapFixed;
struct MMSpace;
extern MMSpace _kernelMMSpace, _coreMMSpace;
#define kernelMMSpace (&_kernelMMSpace)
#define coreMMSpace (&_coreMMSpace)

#define CC_ACCESS_MAP                (1 << 0)
#define CC_ACCESS_READ               (1 << 1)
#define CC_ACCESS_WRITE              (1 << 2)
#define CC_ACCESS_WRITE_BACK         (1 << 3) // Wait for the write to complete before returning.
#define CC_ACCESS_PRECISE            (1 << 4) // Do not write back bytes not touched by this write. (Usually modified tracking is to page granularity.) Requires WRITE_BACK.
#define CC_ACCESS_USER_BUFFER_MAPPED (1 << 5) // Set if the user buffer is memory-mapped to mirror this or another cache.


void CloseHandleToObject(void *object, KernelObjectType type, uint32_t flags = 0);
void *MMStandardAllocate(MMSpace *space, size_t bytes, uint32_t flags, void *baseAddress = nullptr, bool commitAll = true);
bool MMFree(MMSpace *space, void *address, size_t expectedSize = 0, bool userOnly = false);

void EsMemoryFill(void *from, void *to, uint8_t byte)
{
	uint8_t *a = (uint8_t *) from;
	uint8_t *b = (uint8_t *) to;
	while (a != b) *a = byte, a++;
}

uint8_t EsMemorySumBytes(uint8_t *source, size_t bytes) {
	if (!bytes) {
		return 0;
	}

	uint64_t total = 0;

	for (uintptr_t i = 0; i < bytes; i++) {
		total += source[i];
	}

	return (uint8_t)total;
}

int EsMemoryCompare(const void *a, const void *b, size_t bytes) {
	if (!bytes) {
		return 0;
	}

	const uint8_t *x = (const uint8_t *) a;
	const uint8_t *y = (const uint8_t *) b;

	for (uintptr_t i = 0; i < bytes; i++) {
		if (x[i] < y[i]) {
			return -1;
		} else if (x[i] > y[i]) {
			return 1;
		}
	}

	return 0;
}
void EsMemoryZero(void *destination, size_t bytes) {
	// TODO Prevent this from being optimised out in the kernel.

	if (!bytes) {
		return;
	}

	for (uintptr_t i = 0; i < bytes; i++) {
		((uint8_t *) destination)[i] = 0;
	}
}

void EsMemoryCopy(void *_destination, const void *_source, size_t bytes) {
	// TODO Prevent this from being optimised out in the kernel.

	if (!bytes) {
		return;
	}

	uint8_t *destination = (uint8_t *) _destination;
	uint8_t *source = (uint8_t *) _source;

	while (bytes >= 1) {
		((uint8_t *) destination)[0] = ((uint8_t *) source)[0];

		source += 1;
		destination += 1;
		bytes -= 1;
	}
}

void *EsCRTmemcpy(void *dest, const void *src, size_t n) {
	uint8_t *dest8 = (uint8_t *) dest;
	const uint8_t *src8 = (const uint8_t *) src;
	for (uintptr_t i = 0; i < n; i++) {
		dest8[i] = src8[i];
	}
	return dest;
}


size_t EsCRTstrlen(const char *s) {
	size_t n = 0;
	while (s[n]) n++;
	return n;
}

char *EsCRTstrcpy(char *dest, const char *src) {
	size_t stringLength = EsCRTstrlen(src);
	EsCRTmemcpy(dest, src, stringLength + 1);
	return dest;
}




#define ES_MEMORY_OPEN_FAIL_IF_FOUND     (0x1000)
#define ES_MEMORY_OPEN_FAIL_IF_NOT_FOUND (0x2000)

#define ES_THREAD_EVENT_MUTEX_ACQUIRE (1)
#define ES_THREAD_EVENT_MUTEX_RELEASE (2)


enum KLogLevel {
	LOG_VERBOSE,
	LOG_INFO,
	LOG_ERROR,
};



struct ConstantBuffer {
	volatile size_t handles;
	size_t bytes;
	bool isPaged;
	// Data follows.
};

size_t EsCStringLength(const char *string) {
	if (!string) {
		return 0;
	}

	size_t size = 0;

	while (true) {
		if (*string) {
			size++;
			string++;
		} else {
			return size;
		}
	}
}

int EsStringCompareRaw(const char *s1, ptrdiff_t length1, const char *s2, ptrdiff_t length2) {
	if (length1 == -1) length1 = EsCStringLength(s1);
	if (length2 == -1) length2 = EsCStringLength(s2);

	while (length1 || length2) {
		if (!length1) return -1;
		if (!length2) return 1;

		char c1 = *s1;
		char c2 = *s2;

		if (c1 != c2) {
			return c1 - c2;
		}

		length1--;
		length2--;
		s1++;
		s2++;
	}

	return 0;
}

#define K_MAX_PROCESSORS (256)

#define _ES_NODE_FROM_WRITE_EXCLUSIVE	(0x020000)
#define _ES_NODE_DIRECTORY_WRITE		(0x040000)
#define _ES_NODE_NO_WRITE_BASE		(0x080000)


#define NODE_INCREMENT_HANDLE_COUNT(node) \
	node->handles++; \
	node->fileSystem->totalHandleCount++; \
	fs.totalHandleCount++;



#define ES_ERROR_BUFFER_TOO_SMALL		(-2)
#define ES_ERROR_UNKNOWN 			(-7)
#define ES_ERROR_NO_MESSAGES_AVAILABLE		(-9)
#define ES_ERROR_MESSAGE_QUEUE_FULL		(-10)
#define ES_ERROR_PATH_NOT_WITHIN_MOUNTED_VOLUME	(-14)
#define ES_ERROR_PATH_NOT_TRAVERSABLE		(-15)
#define ES_ERROR_FILE_ALREADY_EXISTS		(-19)
#define ES_ERROR_FILE_DOES_NOT_EXIST		(-20)
#define ES_ERROR_DRIVE_ERROR_FILE_DAMAGED	(-21) 
#define ES_ERROR_ACCESS_NOT_WITHIN_FILE_BOUNDS	(-22) 
#define ES_ERROR_PERMISSION_NOT_GRANTED		(-23)
#define ES_ERROR_FILE_IN_EXCLUSIVE_USE		(-24)
#define ES_ERROR_FILE_CANNOT_GET_EXCLUSIVE_USE	(-25)
#define ES_ERROR_INCORRECT_NODE_TYPE		(-26)
#define ES_ERROR_EVENT_NOT_SET			(-27)
#define ES_ERROR_FILE_HAS_WRITERS		(-28)
#define ES_ERROR_TIMEOUT_REACHED			(-29)
#define ES_ERROR_FILE_ON_READ_ONLY_VOLUME	(-32)
#define ES_ERROR_INVALID_DIMENSIONS		(-34)
#define ES_ERROR_DRIVE_CONTROLLER_REPORTED	(-35)
#define ES_ERROR_COULD_NOT_ISSUE_PACKET		(-36)
#define ES_ERROR_HANDLE_TABLE_FULL		(-37)
#define ES_ERROR_COULD_NOT_RESIZE_FILE		(-38)
#define ES_ERROR_DIRECTORY_NOT_EMPTY		(-39)
#define ES_ERROR_NODE_DELETED			(-41)
#define ES_ERROR_VOLUME_MISMATCH			(-43)
#define ES_ERROR_TARGET_WITHIN_SOURCE		(-44)
#define ES_ERROR_TARGET_INVALID_TYPE		(-45)
#define ES_ERROR_MALFORMED_NODE_PATH		(-47)
#define ES_ERROR_TARGET_IS_SOURCE		(-49)
#define ES_ERROR_INVALID_NAME			(-50)
#define ES_ERROR_CORRUPT_DATA			(-51)
#define ES_ERROR_INSUFFICIENT_RESOURCES		(-52)
#define ES_ERROR_UNSUPPORTED_FEATURE		(-53)
#define ES_ERROR_FILE_TOO_FRAGMENTED		(-54)
#define ES_ERROR_DRIVE_FULL			(-55)
#define ES_ERROR_COULD_NOT_RESOLVE_SYMBOL	(-56)
#define ES_ERROR_ALREADY_EMBEDDED		(-57)
#define ES_ERROR_UNSUPPORTED_CONVERSION		(-60)
#define ES_ERROR_SOURCE_EMPTY			(-61)
#define ES_ERROR_UNSUPPORTED_EXECUTABLE		(-62)
#define ES_ERROR_NO_ADDRESS_FOR_DOMAIN_NAME	(-63)
#define ES_ERROR_NO_CONNECTED_NETWORK_INTERFACES	(-64)
#define ES_ERROR_BAD_DOMAIN_NAME			(-65)
#define ES_ERROR_LOST_IP_ADDRESS			(-66)
#define ES_ERROR_CONNECTION_RESET		(-67)
#define ES_ERROR_CONNECTION_REFUSED		(-68)
#define ES_ERROR_ILLEGAL_PATH			(-69)
#define ES_ERROR_NODE_NOT_LOADED			(-71)
#define ES_ERROR_DIRECTORY_ENTRY_BEING_REMOVED   (-72)
#define ES_ERROR_CANCELLED			(-73)
#define ES_ERROR_BLOCK_ACCESS_INVALID		(-74)
#define ES_ERROR_DEVICE_REMOVED			(-75)
#define ES_ERROR_TOO_MANY_FILES_WITH_NAME	(-76)


#define K_USER_BUFFER // Used to mark pointers that (might) point to non-kernel memory.

// Interval between write behinds. (Assuming no low memory conditions are in effect.)
#define CC_WAIT_FOR_WRITE_BEHIND                  (1000)                              

// Divisor of the modified list size for each write behind batch.
// That is, every CC_WAIT_FOR_WRITE_BEHIND ms, 1/CC_WRITE_BACK_DIVISORth of the modified list is written back.
#define CC_WRITE_BACK_DIVISOR                     (8)
                                                                                      
// Describes the virtual memory covering a section of a file.  
#define CC_ACTIVE_SECTION_SIZE                    ((EsFileOffset) 262144)             

// Maximum number of active sections on the modified list. If exceeded, writers will wait for it to drop before retrying.
// TODO This should based off the amount of physical memory.
#define CC_MAX_MODIFIED                           (67108864 / CC_ACTIVE_SECTION_SIZE) 

// The size at which the modified list is determined to be getting worryingly full;
// passing this threshold causes the write back thread to immediately start working.
#define CC_MODIFIED_GETTING_FULL                  (CC_MAX_MODIFIED * 2 / 3)
										      
// The size of the kernel's address space used for mapping active sections.
#if defined(ES_BITS_32)                                                                  
#define CC_SECTION_BYTES                          (ClampIntptr(0, 64L * 1024 * 1024, pmm.commitFixedLimit * K_PAGE_SIZE / 4)) 
#elif defined(ES_BITS_64)
#define CC_SECTION_BYTES                          (ClampIntptr(0, 1024L * 1024 * 1024, pmm.commitFixedLimit * K_PAGE_SIZE / 4)) 
#endif

// When we reach a critical number of pages, FIXED allocations start failing,
// and page faults are blocked, unless you are on a page generating thread (the modified page writer or the balancer).
#define MM_CRITICAL_AVAILABLE_PAGES_THRESHOLD     (1048576 / K_PAGE_SIZE)             

// The number of pages at which balancing starts.
#define MM_LOW_AVAILABLE_PAGES_THRESHOLD          (16777216 / K_PAGE_SIZE)            

// The number of pages past MM_LOW_AVAILABLE_PAGES_THRESHOLD to aim for when balancing.
#define MM_PAGES_TO_FIND_BALANCE                  (4194304 / K_PAGE_SIZE)             

// The number of pages in the zero list before signaling the page zeroing thread.
#define MM_ZERO_PAGE_THRESHOLD                    (16)                                

// The amount of commit reserved specifically for page generating threads.
#define MM_CRITICAL_REMAINING_COMMIT_THRESHOLD    (1048576 / K_PAGE_SIZE)             

// The number of objects that are trimmed from a MMObjectCache at a time.
#define MM_OBJECT_CACHE_TRIM_GROUP_COUNT          (1024)

// The current target maximum size for the object caches. (This uses the approximate sizes of objects.)
// We want to keep a reasonable amount of commit available at all times,
// since when the kernel is allocating memory it might not be able to wait for the caches to be trimmed without deadlock.
// So, try to keep the commit quota used by the object caches at most half the available space.
#define MM_NON_CACHE_MEMORY_PAGES()               (pmm.commitFixed + pmm.commitPageable - pmm.approximateTotalObjectCacheBytes / K_PAGE_SIZE)
#define MM_OBJECT_CACHE_PAGES_MAXIMUM()           ((pmm.commitLimit - MM_NON_CACHE_MEMORY_PAGES()) / 2)

#define PHYSICAL_MEMORY_MANIPULATION_REGION_PAGES (16)
#define POOL_CACHE_COUNT                          (16)


#define ES_SUCCESS (-1)

#define ES_WAIT_NO_TIMEOUT            (-1)
#define ES_MAX_WAIT_COUNT             (8)

#define ES_NODE_FILE			(0)
#define ES_NODE_DIRECTORY		(0x10)
#define ES_NODE_INVALID			(0x20)

#define ES_INSTANCE_TYPE Instance
#define ES_FLAGS_DEFAULT (0)

#define ES_NODE_FAIL_IF_FOUND		(0x001000)
#define ES_NODE_FAIL_IF_NOT_FOUND	(0x002000)
#define ES_NODE_PREVENT_RESIZE		(0x004000)
#define ES_NODE_CREATE_DIRECTORIES	(0x008000)  // Create the directories leading to the file, if they don't already exist.



#define NODE_MAX_ACCESSORS (16777216)

// KNode flags:
#define NODE_HAS_EXCLUSIVE_WRITER (1 << 0)
#define NODE_ENUMERATED_ALL_DIRECTORY_ENTRIES (1 << 1)
#define NODE_CREATED_ON_FILE_SYSTEM (1 << 2)
#define NODE_DELETED (1 << 3)
#define NODE_MODIFIED (1 << 4)
#define NODE_IN_CACHE_LIST (1 << 5) // Node has no handles and no directory entries, so it can be freed.

// Modes for opening a node handle.
#define FS_NODE_OPEN_HANDLE_STANDARD            (0)
#define FS_NODE_OPEN_HANDLE_FIRST               (1)
#define FS_NODE_OPEN_HANDLE_DIRECTORY_TEMPORARY (2)

struct Thread;
struct Process;
struct EsCrashReason;
struct InterruptContext;
struct NewProcessorStorage;

extern "C" uintptr_t _KThreadTerminate;
extern "C"
{
    void KernelLog(KLogLevel level, const char *subsystem, const char *event, const char *format, ...);
    void KernelPanic(const char *format, ...);
    void EsPrint(const char *format, ...);

    void *EsHeapAllocate(size_t size, bool zeroMemory, EsHeap *kernelHeap);
    void EsHeapFree(void *address, size_t expectedSize, EsHeap *kernelHeap);
    void MMPhysicalActivatePages(uintptr_t pages, uintptr_t count, unsigned flags);
    bool MMCommit(uint64_t bytes, bool fixed);
    void PMCopy(uintptr_t page, void *_source, size_t pageCount);
    uintptr_t ProcessorGetRSP();
    uintptr_t ProcessorGetRBP();
    void ProcessorDebugOutputByte(uint8_t byte);
    void SetupProcessor2(NewProcessorStorage *storage);
    void processorGDTR();
    bool PostContextSwitch(InterruptContext *context, MMSpace *oldAddressSpace);
    void InterruptHandler(InterruptContext *context);
    uintptr_t Syscall(uintptr_t argument0, uintptr_t argument1, uintptr_t argument2, uintptr_t returnAddress, uintptr_t argument3, uintptr_t argument4, uintptr_t *userStackPointer);
    void PCProcessMemoryMap();
    void ProcessorHalt();
    void ProcessorInstallTSS(uint32_t *gdt, uint32_t *tss);
    bool ProcessorAreInterruptsEnabled();
    Thread* GetCurrentThread();
    void ProcessorEnableInterrupts();
    uint64_t ProcessorReadCR3();
    void ProcessorInvalidatePage(uintptr_t virtualAddress);
    void ProcessorOut8(uint16_t port, uint8_t value);
    uint8_t ProcessorIn8(uint16_t port);
    void ProcessorOut16(uint16_t port, uint16_t value);
    uint16_t ProcessorIn16(uint16_t port);
    void ProcessorOut32(uint16_t port, uint32_t value);
    uint32_t ProcessorIn32(uint16_t port);
    uint64_t ProcessorReadMXCSR();
    void PCSetupCOM1();
    void PCDisablePIC();
    void ProcessCrash(Process *process, EsCrashReason *crashReason);
    void MMInitialise();
    void ArchInitialise();
    void ArchShutdown();
    void ArchNextTimer(size_t ms); // Schedule the next TIMER_INTERRUPT.
    uint64_t ArchGetTimeMs(); // Called by the scheduler on the boot processor every context switch.
    InterruptContext *ArchInitialiseThread(uintptr_t kernelStack, uintptr_t kernelStackSize, struct Thread *thread, 
            uintptr_t startAddress, uintptr_t argument1, uintptr_t argument2,
            bool userland, uintptr_t stack, uintptr_t userStackSize);
    void ArchSwitchContext(struct InterruptContext *context, struct MMArchVAS *virtualAddressSpace, uintptr_t threadKernelStack, 
            struct Thread *newThread, struct MMSpace *oldAddressSpace);
    EsError ArchApplyRelocation(uintptr_t type, uint8_t *buffer, uintptr_t offset, uintptr_t result);

    bool MMArchMapPage(MMSpace *space, uintptr_t physicalAddress, uintptr_t virtualAddress, unsigned flags); // Returns false if the page was already mapped.
    void MMArchUnmapPages(MMSpace *space, uintptr_t virtualAddressStart, uintptr_t pageCount, unsigned flags, size_t unmapMaximum = 0, uintptr_t *resumePosition = nullptr);
    bool MMArchMakePageWritable(MMSpace *space, uintptr_t virtualAddress);
    bool MMArchHandlePageFault(uintptr_t address, uint32_t flags);
    bool MMArchIsBufferInUserRange(uintptr_t baseAddress, size_t byteCount);
    bool MMArchSafeCopy(uintptr_t destinationAddress, uintptr_t sourceAddress, size_t byteCount); // Returns false if a page fault occured during the copy.
    bool MMArchCommitPageTables(MMSpace *space, struct MMRegion *region);
    bool MMArchInitialiseUserSpace(MMSpace *space, struct MMRegion *firstRegion);
    void MMArchInitialise();
    void MMArchFreeVAS(MMSpace *space);
    void MMArchFinalizeVAS(MMSpace *space);
    uintptr_t MMArchEarlyAllocatePage();
    uint64_t MMArchPopulatePageFrameDatabase();
    uintptr_t MMArchGetPhysicalMemoryHighest();

    void ProcessorDisableInterrupts();
    void ProcessorEnableInterrupts();
    bool ProcessorAreInterruptsEnabled();
    void ProcessorHalt();
    void ProcessorSendYieldIPI(Thread *thread);
    void ProcessorFakeTimerInterrupt();
    void ProcessorInvalidatePage(uintptr_t virtualAddress);
    void ProcessorInvalidateAllPages();
    void ProcessorFlushCodeCache();
    void ProcessorFlushCache();
    void ProcessorSetLocalStorage(struct CPULocalStorage *cls);
    void ProcessorSetThreadStorage(uintptr_t tls);
    void ProcessorSetAddressSpace(struct MMArchVAS *virtualAddressSpace); // Need to call MMSpaceOpenReference/MMSpaceCloseReference if using this.
    uint64_t ProcessorReadTimeStamp();

    struct CPULocalStorage *GetLocalStorage();
    struct Thread *GetCurrentThread();
    void MMSpaceCloseReference(MMSpace* space);
    void KThreadTerminate();
    void ThreadSetTemporaryAddressSpace(MMSpace *space);
    void ProcessKill(Process* process);


    // From module.h: 
    // uintptr_t MMArchTranslateAddress(MMSpace *space, uintptr_t virtualAddress, bool writeAccess); 
    // uint32_t KPCIReadConfig(uint8_t bus, uint8_t device, uint8_t function, uint8_t offset, int size);
    // void KPCIWriteConfig(uint8_t bus, uint8_t device, uint8_t function, uint8_t offset, uint32_t value, int size);
    // bool KRegisterIRQ(intptr_t interruptIndex, KIRQHandler handler, void *context, const char *cOwnerName, struct KPCIDevice *pciDevice);
    // KMSIInformation KRegisterMSI(KIRQHandler handler, void *context, const char *cOwnerName);
    // void KUnregisterMSI(uintptr_t tag);
    // size_t KGetCPUCount();
    // struct CPULocalStorage *KGetCPULocal(uintptr_t index);
    // ProcessorOut/ProcessorIn functions.

    // The architecture layer must also define:
    // - MM_CORE_REGIONS_START and MM_CORE_REGIONS_COUNT.
    // - MM_KERNEL_SPACE_START and MM_KERNEL_SPACE_SIZE.
    // - MM_MODULES_START and MM_MODULES_SIZE.
    // - ArchCheckBundleHeader and ArchCheckELFHeader.
    // - K_ARCH_STACK_GROWS_DOWN or K_ARCH_STACK_GROWS_UP.
    // - K_ARCH_NAME.
}

void EsMemoryCopyReverse(void *_destination, void *_source, size_t bytes) {
	// TODO Prevent this from being optimised out in the kernel.

	if (!bytes) {
		return;
	}

	uint8_t *destination = (uint8_t *) _destination;
	uint8_t *source = (uint8_t *) _source;

	destination += bytes - 1;
	source += bytes - 1;

	while (bytes >= 1) {
		((uint8_t *) destination)[0] = ((uint8_t *) source)[0];

		source -= 1;
		destination -= 1;
		bytes -= 1;
	}
}


void EsMemoryMove(void *_start, void *_end, intptr_t amount, bool zeroEmptySpace) {
	// TODO Prevent this from being optimised out in the kernel.

	uint8_t *start = (uint8_t *) _start;
	uint8_t *end = (uint8_t *) _end;

	if (end < start) {
		EsPrint("MemoryMove end < start: %x %x %x %d\n", start, end, amount, zeroEmptySpace);
		return;
	}

	if (amount > 0) {
		EsMemoryCopyReverse(start + amount, start, end - start);

		if (zeroEmptySpace) {
			EsMemoryZero(start, amount);
		}
	} else if (amount < 0) {
		EsMemoryCopy(start + amount, start, end - start);

		if (zeroEmptySpace) {
			EsMemoryZero(end + amount, -amount);
		}
	}
}

void EsAssertionFailure(const char *file, int line) {
	KernelPanic("%z:%d - EsAssertionFailure called.\n", file, line);
}

union EsGeneric {
	uintptr_t u;
	intptr_t i;
	void *p;

	inline EsGeneric() = default;

#ifdef ES_BITS_64
	inline EsGeneric(uintptr_t y) { u = y; }
	inline EsGeneric( intptr_t y) { i = y; }
#endif
	inline EsGeneric(unsigned  y) { u = y; }
	inline EsGeneric(     int  y) { i = y; }
	inline EsGeneric(    void *y) { p = y; }

	inline bool operator==(EsGeneric r) const { return r.u == u; }
};

#define ES_FILE_READ_SHARED		(0x1) // Read-only. The file can still be opened for writing.
#define ES_FILE_READ			(0x2) // Read-only. The file will not openable for writing. This will fail if the file is already opened for writing.
#define ES_FILE_WRITE_SHARED		(0x4) // Read-write. The file can still be opened for writing. This will fail if the file is already opened for exclusive writing.
#define ES_FILE_WRITE 			(0x8) // Read-write. The file will not openable for writing. This will fail if the file is already opened for writing.



#define MM_REGION_FIXED              (0x01) // A region where all the physical pages are allocated up-front, and cannot be removed from the working set.
#define MM_REGION_NOT_CACHEABLE      (0x02) // Do not cache the pages in the region.
#define MM_REGION_NO_COMMIT_TRACKING (0x04) // Page committing is manually tracked.
#define MM_REGION_READ_ONLY	     (0x08) // Generate page faults when written to.
#define MM_REGION_COPY_ON_WRITE	     (0x10) // Copy on write.
#define MM_REGION_WRITE_COMBINING    (0x20) // Write combining caching is enabled. Incompatible with MM_REGION_NOT_CACHEABLE.
#define MM_REGION_EXECUTABLE         (0x40) 
#define MM_REGION_USER               (0x80) // The application created it, and is therefore allowed to modify it.
// Limited by region type flags.


#define K_PAGE_BITS (12)
#define K_PAGE_SIZE (0x1000)

#define MM_CORE_REGIONS_START (0xFFFF8001F0000000)
#define MM_CORE_REGIONS_COUNT ((0xFFFF800200000000 - 0xFFFF8001F0000000) / sizeof(MMRegion))
#define MM_KERNEL_SPACE_START (0xFFFF900000000000)
#define MM_KERNEL_SPACE_SIZE  (0xFFFFF00000000000 - 0xFFFF900000000000)
#define MM_MODULES_START      (0xFFFFFFFF90000000)
#define MM_MODULES_SIZE	      (0xFFFFFFFFC0000000 - 0xFFFFFFFF90000000)

#define MM_CORE_SPACE_START   (0xFFFF800100000000)
#define MM_CORE_SPACE_SIZE    (0xFFFF8001F0000000 - 0xFFFF800100000000)
#define MM_USER_SPACE_START   (0x100000000000)
#define MM_USER_SPACE_SIZE    (0xF00000000000 - 0x100000000000)
#define LOW_MEMORY_MAP_START  (0xFFFFFE0000000000)
#define LOW_MEMORY_LIMIT      (0x100000000) // The first 4GB is mapped here.

#define EsContainerOf(type, member, pointer) ((type *) ((uint8_t *) pointer - offsetof(type, member)))
#define _ES_C_PREPROCESSOR_JOIN(x, y) x ## y
#define ES_C_PREPROCESSOR_JOIN(x, y) _ES_C_PREPROCESSOR_JOIN(x, y)


template <typename F> struct _EsDefer4 { F f; _EsDefer4(F f) : f(f) {} ~_EsDefer4() { f(); } };
template <typename F> _EsDefer4<F> _EsDeferFunction(F f) { return _EsDefer4<F>(f); }
#define EsDEFER_3(x) ES_C_PREPROCESSOR_JOIN(x, __COUNTER__)
#define _EsDefer5(code) auto EsDEFER_3(_defer_) = _EsDeferFunction([&](){code;})
#define EsDefer(code) _EsDefer5(code)


#define EsPanic KernelPanic

template <class T>
T RoundDown(T value, T divisor) {
	value /= divisor;
	value *= divisor;
	return value;
}

template <class T>
T RoundUp(T value, T divisor) {
	value += divisor - 1;
	value /= divisor;
	value *= divisor;
	return value;
}

template <class T>
struct LinkedList;

template <class T>
struct LinkedItem {
	void RemoveFromList();

	LinkedItem<T> *previousItem;
	LinkedItem<T> *nextItem;

	// TODO Separate these out?
	struct LinkedList<T> *list;
	T *thisItem;
};

template <class T>
struct LinkedList {
	void InsertStart(LinkedItem<T> *item);
	void InsertEnd(LinkedItem<T> *item);
	void InsertBefore(LinkedItem<T> *newItem, LinkedItem<T> *beforeItem);
	void Remove(LinkedItem<T> *item);

	void Validate(int from); 

	LinkedItem<T> *firstItem;
	LinkedItem<T> *lastItem;

	size_t count;

#ifdef DEBUG_BUILD
	bool modCheck;
#endif
};
template <class T>
void LinkedItem<T>::RemoveFromList() {
	if (!list) {
		EsPanic("LinkedItem::RemoveFromList - Item not in list.\n");
	}

	list->Remove(this);
}

struct SimpleList {
	void Insert(SimpleList *link, bool start);
	void Remove();

	union { SimpleList *previous, *last; };
	union { SimpleList *next, *first; };
};
typedef SimpleList MMObjectCacheItem;

template <class T>
void LinkedList<T>::InsertStart(LinkedItem<T> *item) {
#ifdef DEBUG_BUILD
	if (modCheck) EsPanic("LinkedList::InsertStart - Concurrent modification\n");
	modCheck = true; EsDefer({modCheck = false;});
#endif

	if (item->list == this) EsPanic("LinkedList::InsertStart - Inserting an item that is already in this list\n");
	if (item->list) EsPanic("LinkedList::InsertStart - Inserting an item that is already in a list\n");

	if (firstItem) {
		item->nextItem = firstItem;
		item->previousItem = nullptr;
		firstItem->previousItem = item;
		firstItem = item;
	} else {
		firstItem = lastItem = item;
		item->previousItem = item->nextItem = nullptr;
	}

	count++;
	item->list = this;
	Validate(0);
}

template <class T>
void LinkedList<T>::InsertEnd(LinkedItem<T> *item) {
#ifdef DEBUG_BUILD
	if (modCheck) EsPanic("LinkedList::InsertEnd - Concurrent modification\n");
	modCheck = true; EsDefer({modCheck = false;});
#endif

	if (item->list == this) EsPanic("LinkedList::InsertEnd - Inserting a item that is already in this list\n");
	if (item->list) EsPanic("LinkedList::InsertEnd - Inserting a item that is already in a list\n");

	if (lastItem) {
		item->previousItem = lastItem;
		item->nextItem = nullptr;
		lastItem->nextItem = item;
		lastItem = item;
	} else {
		firstItem = lastItem = item;
		item->previousItem = item->nextItem = nullptr;
	}

	count++;
	item->list = this;
	Validate(1);
}

template <class T>
void LinkedList<T>::InsertBefore(LinkedItem<T> *item, LinkedItem<T> *before) {
#ifdef DEBUG_BUILD
	if (modCheck) EsPanic("LinkedList::InsertBefore - Concurrent modification\n");
	modCheck = true; EsDefer({modCheck = false;});
#endif

	if (item->list == this) EsPanic("LinkedList::InsertBefore - Inserting a item that is already in this list\n");
	if (item->list) EsPanic("LinkedList::InsertBefore - Inserting a item that is already in a list\n");

	if (before != firstItem) {
		item->previousItem = before->previousItem;
		item->previousItem->nextItem = item;
	} else {
		firstItem = item;
		item->previousItem = nullptr;
	}

	item->nextItem = before;
	before->previousItem = item;

	count++;
	item->list = this;
	Validate(3);
}

template <class T>
void LinkedList<T>::Remove(LinkedItem<T> *item) {
#ifdef DEBUG_BUILD
	if (modCheck) EsPanic("LinkedList::Remove - Concurrent modification\n");
	modCheck = true; EsDefer({modCheck = false;});
#endif

	if (!item->list) EsPanic("LinkedList::Remove - Removing an item that has already been removed\n");
	if (item->list != this) EsPanic("LinkedList::Remove - Removing an item from a different list (list = %x, this = %x)\n", item->list, this);

	if (item->previousItem) {
		item->previousItem->nextItem = item->nextItem;
	} else {
		firstItem = item->nextItem;
	}

	if (item->nextItem) {
		item->nextItem->previousItem = item->previousItem;
	} else {
		lastItem = item->previousItem;
	}

	item->previousItem = item->nextItem = nullptr;
	item->list = nullptr;
	count--;
	Validate(2);
}

template <class T>
void LinkedList<T>::Validate(int from) {
#ifdef DEBUG_BUILD
	if (count == 0) {
		if (firstItem || lastItem) {
			EsPanic("LinkedList::Validate (%d) - Invalid list (1)\n", from);
		}
	} else if (count == 1) {
		if (firstItem != lastItem
				|| firstItem->previousItem
				|| firstItem->nextItem
				|| firstItem->list != this
				|| !firstItem->thisItem) {
			EsPanic("LinkedList::Validate (%d) - Invalid list (2)\n", from);
		}
	} else {
		if (firstItem == lastItem
				|| firstItem->previousItem
				|| lastItem->nextItem) {
			EsPanic("LinkedList::Validate (%d) - Invalid list (3) %x %x %x %x\n", from, firstItem, lastItem, firstItem->previousItem, lastItem->nextItem);
		}

		{
			LinkedItem<T> *item = firstItem;
			size_t index = count;

			while (--index) {
				if (item->nextItem == item || item->list != this || !item->thisItem) {
					EsPanic("LinkedList::Validate (%d) - Invalid list (4)\n", from);
				}

				item = item->nextItem;
			}

			if (item != lastItem) {
				EsPanic("LinkedList::Validate (%d) - Invalid list (5)\n", from);
			}
		}

		{
			LinkedItem<T> *item = lastItem;
			size_t index = count;

			while (--index) {
				if (item->previousItem == item) {
					EsPanic("LinkedList::Validate (%d) - Invalid list (6)\n", from);
				}

				item = item->previousItem;
			}

			if (item != firstItem) {
				EsPanic("LinkedList::Validate (%d) - Invalid list (7)\n", from);
			}
		}
	}
#else
	(void) from;
#endif
}

void SimpleList::Insert(SimpleList *item, bool start) {
	if (item->previous || item->next) {
		EsPanic("SimpleList::Insert - Bad links in %x.\n", this);
	}

	if (!first && !last) {
		item->previous = this;
		item->next = this;
		first = item;
		last = item;
	} else if (start) {
		item->previous = this;
		item->next = first;
		first->previous = item;
		first = item;
	} else {
		item->previous = last;
		item->next = this;
		last->next = item;
		last = item;
	}
}

void SimpleList::Remove() {
	if (previous->next != this || next->previous != this) {
		EsPanic("SimpleList::Remove - Bad links in %x.\n", this);
	}

	if (previous == next) {
		next->first = nullptr;
		next->last = nullptr;
	} else {
		previous->next = next;
		next->previous = previous;
	}

	previous = next = nullptr;
}

#define AVLPanic KernelPanic
enum TreeSearchMode {
	TREE_SEARCH_EXACT,
	TREE_SEARCH_SMALLEST_ABOVE_OR_EQUAL,
	TREE_SEARCH_LARGEST_BELOW_OR_EQUAL,
};

template <class T> struct AVLTree;
struct AVLKey {
	union {
		uintptr_t shortKey;

		struct {
			void *longKey;
			size_t longKeyBytes;
		};
	};
};
inline AVLKey MakeShortKey(uintptr_t shortKey) {
	AVLKey key = {};
	key.shortKey = shortKey;
	return key;
}

inline AVLKey MakeLongKey(const void *longKey, size_t longKeyBytes) {
	AVLKey key = {};
	key.longKey = (void *) longKey;
	key.longKeyBytes = longKeyBytes;
	return key;
}

inline AVLKey MakeCStringKey(const char *cString) {
	return MakeLongKey(cString, EsCStringLength(cString) + 1);
}

template <class T>
struct AVLItem {
	T *thisItem;
	AVLItem<T> *children[2], *parent;
#ifdef TREE_VALIDATE
	AVLTree<T> *tree;
#endif
	AVLKey key;
	int height;
};

template <class T>
struct AVLTree {
	AVLItem<T> *root;
	bool modCheck;
	bool longKeys;
};

template <class T>
void TreeRelink(AVLItem<T> *item, AVLItem<T> *newLocation) {
	item->parent->children[item->parent->children[1] == item] = newLocation;
	if (item->children[0]) item->children[0]->parent = newLocation;
	if (item->children[1]) item->children[1]->parent = newLocation;
}

template <class T>
void TreeSwapItems(AVLItem<T> *a, AVLItem<T> *b) {
	// Set the parent of each item to point to the opposite one.
	a->parent->children[a->parent->children[1] == a] = b;
	b->parent->children[b->parent->children[1] == b] = a;

	// Swap the data between items.
	AVLItem<T> ta = *a, tb = *b;
	a->parent = tb.parent;
	b->parent = ta.parent;
	a->height = tb.height;
	b->height = ta.height;
	a->children[0] = tb.children[0];
	a->children[1] = tb.children[1];
	b->children[0] = ta.children[0];
	b->children[1] = ta.children[1];

	// Make all the children point to the correct item.
	if (a->children[0]) a->children[0]->parent = a; 
	if (a->children[1]) a->children[1]->parent = a; 
	if (b->children[0]) b->children[0]->parent = b;
	if (b->children[1]) b->children[1]->parent = b;
}

template <class T>
inline int TreeCompare(AVLTree<T> *tree, AVLKey *key1, AVLKey *key2) {
	if (tree->longKeys) {
		if (!key1->longKey && !key2->longKey) return 0;
		if (!key2->longKey) return  1;
		if (!key1->longKey) return -1;
		return EsStringCompareRaw((const char *) key1->longKey, key1->longKeyBytes, (const char *) key2->longKey, key2->longKeyBytes);
	} else {
		if (key1->shortKey < key2->shortKey) return -1;
		if (key1->shortKey > key2->shortKey) return  1;
		return 0;
	}
}

template <class T>
int TreeValidate(AVLItem<T> *root, bool before, AVLTree<T> *tree, AVLItem<T> *parent = nullptr, int depth = 0) {
#ifdef TREE_VALIDATE
	if (!root) return 0;
	if (root->parent != parent) AVLPanic("TreeValidate - Invalid binary tree 1 (%d).\n", before);
	if (root->tree != tree) AVLPanic("TreeValidate - Invalid binary tree 4 (%d).\n", before);

	AVLItem<T> *left  = root->children[0];
	AVLItem<T> *right = root->children[1];

	if (left  && TreeCompare(tree, &left->key,  &root->key) > 0) AVLPanic("TreeValidate - Invalid binary tree 2 (%d).\n", before);
	if (right && TreeCompare(tree, &right->key, &root->key) < 0) AVLPanic("TreeValidate - Invalid binary tree 3 (%d).\n", before);

	int leftHeight = TreeValidate(left, before, tree, root, depth + 1);
	int rightHeight = TreeValidate(right, before, tree, root, depth + 1);
	int height = (leftHeight > rightHeight ? leftHeight : rightHeight) + 1;
	if (height != root->height) AVLPanic("TreeValidate - Invalid AVL tree 1 (%d).\n", before);

#if 0
	static int maxSeenDepth = 0;
	if (maxSeenDepth < depth) {
		maxSeenDepth = depth;
		EsPrint("New depth reached! %d\n", maxSeenDepth);
	}
#endif

	return height;
#else
	(void) root;
	(void) before;
	(void) tree;
	(void) parent;
	(void) depth;
	return 0;
#endif
}

template <class T>
AVLItem<T> *TreeRotateLeft(AVLItem<T> *x) {
	AVLItem<T> *y = x->children[1], *t = y->children[0];
	y->children[0] = x, x->children[1] = t;
	if (x) x->parent = y; 
	if (t) t->parent = x;

	int leftHeight, rightHeight, balance;

	leftHeight  = x->children[0] ? x->children[0]->height : 0;
	rightHeight = x->children[1] ? x->children[1]->height : 0;
	balance     = leftHeight - rightHeight;
	x->height   = (balance > 0 ? leftHeight : rightHeight) + 1;

	leftHeight  = y->children[0] ? y->children[0]->height : 0;
	rightHeight = y->children[1] ? y->children[1]->height : 0;
	balance    = leftHeight - rightHeight;
	y->height   = (balance > 0 ? leftHeight : rightHeight) + 1;

	return y;
}

template <class T>
AVLItem<T> *TreeRotateRight(AVLItem<T> *y) {
	AVLItem<T> *x = y->children[0], *t = x->children[1];
	x->children[1] = y, y->children[0] = t;
	if (y) y->parent = x;
	if (t) t->parent = y;

	int leftHeight, rightHeight, balance;

	leftHeight  = y->children[0] ? y->children[0]->height : 0;
	rightHeight = y->children[1] ? y->children[1]->height : 0;
	balance     = leftHeight - rightHeight;
	y->height   = (balance > 0 ? leftHeight : rightHeight) + 1;

	leftHeight  = x->children[0] ? x->children[0]->height : 0;
	rightHeight = x->children[1] ? x->children[1]->height : 0;
	balance     = leftHeight - rightHeight;
	x->height   = (balance > 0 ? leftHeight : rightHeight) + 1;

	return x;
}

enum AVLDuplicateKeyPolicy {
	AVL_DUPLICATE_KEYS_PANIC,
	AVL_DUPLICATE_KEYS_ALLOW,
	AVL_DUPLICATE_KEYS_FAIL,
};

template <class T>
bool TreeInsert(AVLTree<T> *tree, AVLItem<T> *item, T *thisItem, AVLKey key, AVLDuplicateKeyPolicy duplicateKeyPolicy = AVL_DUPLICATE_KEYS_PANIC) {
	if (tree->modCheck) AVLPanic("TreeInsert - Concurrent modification\n");
	tree->modCheck = true; EsDefer({tree->modCheck = false;});

	TreeValidate(tree->root, true, tree);

#ifdef TREE_VALIDATE
	if (item->tree) {
		AVLPanic("TreeInsert - Item %x already in tree %x (adding to %x).\n", item, item->tree, tree);
	}

	item->tree = tree;
#endif

	item->key = key;
	item->children[0] = item->children[1] = nullptr;
	item->thisItem = thisItem;
	item->height = 1;

	AVLItem<T> **link = &tree->root, *parent = nullptr;

	while (true) {
		AVLItem<T> *node = *link;

		if (!node) {
			*link = item;
			item->parent = parent;
			break;
		}

		if (TreeCompare(tree, &item->key, &node->key) == 0) {
			if (duplicateKeyPolicy == AVL_DUPLICATE_KEYS_PANIC) {
				AVLPanic("TreeInsertRecursive - Duplicate keys: %x and %x both have key %x.\n", item, node, node->key);
			} else if (duplicateKeyPolicy == AVL_DUPLICATE_KEYS_FAIL) {
				return false;
			}
		}

		link = node->children + (TreeCompare(tree, &item->key, &node->key) > 0);
		parent = node;
	}

	AVLItem<T> fakeRoot = {};
	tree->root->parent = &fakeRoot;
#ifdef TREE_VALIDATE
	fakeRoot.tree = tree;
#endif
	fakeRoot.key = {};
	fakeRoot.children[0] = tree->root;

	item = item->parent;

	while (item != &fakeRoot) {
		int leftHeight  = item->children[0] ? item->children[0]->height : 0;
		int rightHeight = item->children[1] ? item->children[1]->height : 0;
		int balance = leftHeight - rightHeight;

		item->height = (balance > 0 ? leftHeight : rightHeight) + 1;
		AVLItem<T> *newRoot = nullptr;
		AVLItem<T> *oldParent = item->parent;

		if (balance > 1 && TreeCompare(tree, &key, &item->children[0]->key) <= 0) {
			oldParent->children[oldParent->children[1] == item] = newRoot = TreeRotateRight(item);
		} else if (balance > 1 && TreeCompare(tree, &key, &item->children[0]->key) > 0 && item->children[0]->children[1]) {
			item->children[0] = TreeRotateLeft(item->children[0]);
			item->children[0]->parent = item;
			oldParent->children[oldParent->children[1] == item] = newRoot = TreeRotateRight(item);
		} else if (balance < -1 && TreeCompare(tree, &key, &item->children[1]->key) > 0) {
			oldParent->children[oldParent->children[1] == item] = newRoot = TreeRotateLeft(item);
		} else if (balance < -1 && TreeCompare(tree, &key, &item->children[1]->key) <= 0 && item->children[1]->children[0]) {
			item->children[1] = TreeRotateRight(item->children[1]);
			item->children[1]->parent = item;
			oldParent->children[oldParent->children[1] == item] = newRoot = TreeRotateLeft(item);
		}

		if (newRoot) newRoot->parent = oldParent;
		item = oldParent;
	}

	tree->root = fakeRoot.children[0];
	tree->root->parent = nullptr;

	TreeValidate(tree->root, false, tree);
	return true;
}

template <class T>
AVLItem<T> *TreeFindRecursive(AVLTree<T> *tree, AVLItem<T> *root, AVLKey *key, TreeSearchMode mode) {
	if (!root) return nullptr;
	if (TreeCompare(tree, &root->key, key) == 0) return root;

	if (mode == TREE_SEARCH_EXACT) {
		return TreeFindRecursive(tree, root->children[TreeCompare(tree, &root->key, key) < 0], key, mode);
	} else if (mode == TREE_SEARCH_SMALLEST_ABOVE_OR_EQUAL) {
		if (TreeCompare(tree, &root->key, key) > 0) { 
			AVLItem<T> *item = TreeFindRecursive(tree, root->children[0], key, mode); 
			if (item) return item; else return root;
		} else { 
			return TreeFindRecursive(tree, root->children[1], key, mode); 
		}
	} else if (mode == TREE_SEARCH_LARGEST_BELOW_OR_EQUAL) {
		if (TreeCompare(tree, &root->key, key) < 0) { 
			AVLItem<T> *item = TreeFindRecursive(tree, root->children[1], key, mode); 
			if (item) return item; else return root;
		} else { 
			return TreeFindRecursive(tree, root->children[0], key, mode); 
		}
	} else {
		AVLPanic("TreeFindRecursive - Invalid search mode.\n");
		return nullptr;
	}
}

template <class T>
AVLItem<T> *TreeFind(AVLTree<T> *tree, AVLKey key, TreeSearchMode mode) {
	if (tree->modCheck) AVLPanic("TreeFind - Concurrent access\n");

	TreeValidate(tree->root, true, tree);
	return TreeFindRecursive(tree, tree->root, &key, mode);
}

template <class T>
int TreeGetBalance(AVLItem<T> *item) {
	if (!item) return 0;

	int leftHeight  = item->children[0] ? item->children[0]->height : 0;
	int rightHeight = item->children[1] ? item->children[1]->height : 0;
	return leftHeight - rightHeight;
}

template <class T>
void TreeRemove(AVLTree<T> *tree, AVLItem<T> *item) {
	if (tree->modCheck) AVLPanic("TreeRemove - Concurrent modification\n");
	tree->modCheck = true; EsDefer({tree->modCheck = false;});

	TreeValidate(tree->root, true, tree);

#ifdef TREE_VALIDATE
	if (item->tree != tree) AVLPanic("TreeRemove - Item %x not in tree %x (in %x).\n", item, tree, item->tree);
#endif

	AVLItem<T> fakeRoot = {};
	tree->root->parent = &fakeRoot;
#ifdef TREE_VALIDATE
	fakeRoot.tree = tree;
#endif
	fakeRoot.key = {}; 
	fakeRoot.children[0] = tree->root;

	if (item->children[0] && item->children[1]) {
		// Swap the item we're removing with the smallest item on its right side.
		AVLKey smallest = {};
		TreeSwapItems(TreeFindRecursive(tree, item->children[1], &smallest, TREE_SEARCH_SMALLEST_ABOVE_OR_EQUAL), item);
	}

	AVLItem<T> **link = item->parent->children + (item->parent->children[1] == item);
	*link = item->children[0] ? item->children[0] : item->children[1];
	if (*link) (*link)->parent = item->parent;
#ifdef TREE_VALIDATE
	item->tree = nullptr;
#endif
	if (*link) item = *link; else item = item->parent;

	while (item != &fakeRoot) {
		int leftHeight  = item->children[0] ? item->children[0]->height : 0;
		int rightHeight = item->children[1] ? item->children[1]->height : 0;
		int balance = leftHeight - rightHeight;

		item->height = (balance > 0 ? leftHeight : rightHeight) + 1;
		AVLItem<T> *newRoot = nullptr;
		AVLItem<T> *oldParent = item->parent;

		if (balance > 1 && TreeGetBalance(item->children[0]) >= 0) {
			oldParent->children[oldParent->children[1] == item] = newRoot = TreeRotateRight(item);
		} else if (balance > 1 && TreeGetBalance(item->children[0]) < 0) {
			item->children[0] = TreeRotateLeft(item->children[0]);
			item->children[0]->parent = item;
			oldParent->children[oldParent->children[1] == item] = newRoot = TreeRotateRight(item);
		} else if (balance < -1 && TreeGetBalance(item->children[1]) <= 0) {
			oldParent->children[oldParent->children[1] == item] = newRoot = TreeRotateLeft(item);
		} else if (balance < -1 && TreeGetBalance(item->children[1]) > 0) {
			item->children[1] = TreeRotateRight(item->children[1]);
			item->children[1]->parent = item;
			oldParent->children[oldParent->children[1] == item] = newRoot = TreeRotateLeft(item);
		}

		if (newRoot) newRoot->parent = oldParent;
		item = oldParent;
	}

	tree->root = fakeRoot.children[0];

	if (tree->root) {
		if (tree->root->parent != &fakeRoot) AVLPanic("TreeRemove - Incorrect root parent.\n");
		tree->root->parent = nullptr;
	}

	TreeValidate(tree->root, false, tree);
}


struct Thread;

struct KWriterLock { // One writer or many readers.
	LinkedList<Thread> blockedThreads;
	volatile intptr_t state; // -1: exclusive; >0: shared owners.
#ifdef DEBUG_BUILD
	volatile Thread *exclusiveOwner;
#endif
};

#define K_LOCK_EXCLUSIVE (true)
#define K_LOCK_SHARED (false)

bool KWriterLockTake(KWriterLock *lock, bool write, bool poll = false);
void KWriterLockReturn(KWriterLock *lock, bool write);
void KWriterLockConvertExclusiveToShared(KWriterLock *lock);
void KWriterLockAssertExclusive(KWriterLock *lock);
void KWriterLockAssertShared(KWriterLock *lock);
void KWriterLockAssertLocked(KWriterLock *lock);


struct KMutex { // Mutual exclusion. Thread-owned.
	struct Thread *volatile owner;
#ifdef DEBUG_BUILD
	uintptr_t acquireAddress, releaseAddress, id; 
#endif
	LinkedList<struct Thread> blockedThreads;
};

#ifdef DEBUG_BUILD
bool _KMutexAcquire(KMutex *mutex, const char *cMutexString, const char *cFile, int line);
void _KMutexRelease(KMutex *mutex, const char *cMutexString, const char *cFile, int line);
#define KMutexAcquire(mutex) _KMutexAcquire(mutex, #mutex, __FILE__, __LINE__)
#define KMutexRelease(mutex) _KMutexRelease(mutex, #mutex, __FILE__, __LINE__)
#else
bool KMutexAcquire(KMutex *mutex);
void KMutexRelease(KMutex *mutex);
#endif
void KMutexAssertLocked(KMutex *mutex);

#define PHYSICAL_MEMORY_MANIPULATION_REGION_PAGES (16)
#define POOL_CACHE_COUNT                          (16)
struct CPULocalStorage {
	struct Thread *currentThread;          // The currently executing thread on this CPU.
	struct Thread *idleThread;             // The CPU's idle thread.
	struct Thread *asyncTaskThread;        // The CPU's async task thread, used to process the asyncTaskList.
	struct InterruptContext *panicContext; // The interrupt context saved from a kernel panic IPI.
	bool irqSwitchThread;                  // The CPU should call Scheduler::Yield after the IRQ handler exits.
	bool schedulerReady;                   // The CPU is ready to execute threads from the pre-emptive scheduler.
	bool inIRQ;                            // The CPU is currently executing an IRQ handler registered with KRegisterIRQ.
	bool inAsyncTask;                      // The CPU is currently executing an asynchronous task.
	uint32_t processorID;                  // The scheduler's ID for the process.
	size_t spinlockCount;                  // The number of spinlocks currently acquired.
	struct ArchCPU *archCPU;               // The architecture layer's data for the CPU.
	SimpleList asyncTaskList;              // The list of AsyncTasks to be processed.
};


struct KSpinlock { // Mutual exclusion. CPU-owned. Disables interrupts. The only synchronisation primitive that can be acquired with interrupts disabled.
	volatile uint8_t state, ownerCPU;
	volatile bool interruptsEnabled;
#ifdef DEBUG_BUILD
	struct Thread *volatile owner;
	volatile uintptr_t acquireAddress, releaseAddress;
#endif
};

void KSpinlockAcquire(KSpinlock *spinlock);
void KSpinlockRelease(KSpinlock *spinlock, bool force = false);
void KSpinlockAssertLocked(KSpinlock *spinlock);



struct Pool {
    void *Add(size_t _elementSize) { 		// Aligned to the size of a pointer.
        KMutexAcquire(&mutex);
        EsDefer(KMutexRelease(&mutex));

        if (elementSize && _elementSize != elementSize) KernelPanic("Pool::Add - Pool element size mismatch.\n");
        elementSize = _elementSize;

        void *address;

        if (cacheEntries) {
            address = cache[--cacheEntries];
            EsMemoryZero(address, elementSize);
        } else {
            address = EsHeapAllocate(elementSize, true, K_FIXED);
        }

        return address;

    }
    void Remove(void *address) {

        KMutexAcquire(&mutex);
        EsDefer(KMutexRelease(&mutex));

        if (!address) return;

#if 1
        if (cacheEntries == POOL_CACHE_COUNT) {
            EsHeapFree(address, elementSize, K_FIXED);
        } else {
            cache[cacheEntries++] = address;
        }
#else
        EsHeapFree(address, elementSize);
#endif
    }

	size_t elementSize;
	void *cache[POOL_CACHE_COUNT];
	size_t cacheEntries;
	KMutex mutex;
};

struct KEvent { // Waiting and notifying. Can wait on multiple at once. Can be set and reset with interrupts disabled.
	volatile bool autoReset; // This should be first field in the structure, so that the type of KEvent can be easily declared with {autoReset}.
	volatile uintptr_t state;
	LinkedList<Thread> blockedThreads;
	volatile size_t handles;
};

bool KEventSet(KEvent *event, bool maybeAlreadySet = false);
void KEventReset(KEvent *event); 
bool KEventPoll(KEvent *event); // TODO Remove this! Currently it is only used by KAudioFillBuffersFromMixer.
bool KEventWait(KEvent *event, uint64_t timeoutMs = ES_WAIT_NO_TIMEOUT); // See KEventWaitMultiple to wait for multiple events. Returns false if the wait timed out.

#ifdef DEBUG_BUILD
#define MAYBE_VALIDATE_HEAP() HeapValidate(&heap)
#else
#define MAYBE_VALIDATE_HEAP() 
#endif

#ifndef KERNEL
// #define MEMORY_LEAK_DETECTOR
#endif

#define LARGE_ALLOCATION_THRESHOLD (32768)
#define USED_HEAP_REGION_MAGIC (0xABCD)

struct HeapRegion {
	union {
		uint16_t next;
		uint16_t size;
	};

	uint16_t previous;
	uint16_t offset;
	uint16_t used;

	union {
		uintptr_t allocationSize;

		// Valid if the region is not in use.
		HeapRegion *regionListNext;
	};

	// Free regions only:
	HeapRegion **regionListReference;
#define USED_HEAP_REGION_HEADER_SIZE (sizeof(HeapRegion) - sizeof(HeapRegion **))
#define FREE_HEAP_REGION_HEADER_SIZE (sizeof(HeapRegion))
};

static uintptr_t HeapCalculateIndex(uintptr_t size) {
	int x = __builtin_clz(size);
	uintptr_t msb = sizeof(unsigned int) * 8 - x - 1;
	return msb - 4;
}

#ifdef MEMORY_LEAK_DETECTOR
extern "C" uint64_t ProcessorGetRBP();

struct MemoryLeakDetectorEntry {
	void *address;
	size_t bytes;
	uintptr_t stack[8];
	size_t seenCount;
};
#else
#define MemoryLeakDetectorAdd(...)
#define MemoryLeakDetectorRemove(...)
#define MemoryLeakDetectorCheckpoint(...)
#endif

struct EsHeap {
#ifdef KERNEL
	KMutex mutex;
#else
	EsMutex mutex;
#endif

	HeapRegion *regions[12];
	volatile size_t allocationsCount, size, blockCount;
	void *blocks[16];

	bool cannotValidate;

#ifdef MEMORY_LEAK_DETECTOR
	MemoryLeakDetectorEntry leakDetectorEntries[4096];
#endif
};

// TODO Better heap panic messages.
#define HEAP_PANIC(n, x, y) EsPanic("Heap panic (%d/%x/%x).\n", n, x, y)

#ifdef KERNEL
EsHeap heapCore, heapFixed;
#define HEAP_ACQUIRE_MUTEX(a) KMutexAcquire(&(a))
#define HEAP_RELEASE_MUTEX(a) KMutexRelease(&(a))
#define HEAP_ALLOCATE_CALL(x) MMStandardAllocate(_heap == &heapCore ? coreMMSpace : kernelMMSpace, x, MM_REGION_FIXED)
#define HEAP_FREE_CALL(x) MMFree(_heap == &heapCore ? coreMMSpace : kernelMMSpace, x)
#else
EsHeap heap;
#define HEAP_ACQUIRE_MUTEX(a) EsMutexAcquire(&(a))
#define HEAP_RELEASE_MUTEX(a) EsMutexRelease(&(a))
#define HEAP_ALLOCATE_CALL(x) EsMemoryReserve(x)
#define HEAP_FREE_CALL(x) EsMemoryUnreserve(x)
#endif

#define HEAP_REGION_HEADER(region) ((HeapRegion *) ((uint8_t *) region - USED_HEAP_REGION_HEADER_SIZE))
#define HEAP_REGION_DATA(region) ((uint8_t *) region + USED_HEAP_REGION_HEADER_SIZE)
#define HEAP_REGION_NEXT(region) ((HeapRegion *) ((uint8_t *) region + region->next))
#define HEAP_REGION_PREVIOUS(region) (region->previous ? ((HeapRegion *) ((uint8_t *) region - region->previous)) : nullptr)

#ifdef USE_PLATFORM_HEAP
void *PlatformHeapAllocate(size_t size, bool zero);
void PlatformHeapFree(void *address);
void *PlatformHeapReallocate(void *oldAddress, size_t newAllocationSize, bool zeroNewSpace);
#endif

#ifdef MEMORY_LEAK_DETECTOR
static void MemoryLeakDetectorAdd(EsHeap *heap, void *address, size_t bytes) {
	if (!address || !bytes) {
		return;
	}

	for (uintptr_t i = 0; i < sizeof(heap->leakDetectorEntries) / sizeof(heap->leakDetectorEntries[0]); i++) {
		MemoryLeakDetectorEntry *entry = &heap->leakDetectorEntries[i];

		if (entry->address) {
			continue;
		}

		entry->address = address;
		entry->bytes = bytes;
		entry->seenCount = 0;

		uint64_t rbp = ProcessorGetRBP();
		uintptr_t traceDepth = 0;

		while (rbp && traceDepth < sizeof(entry->stack) / sizeof(entry->stack[0])) {
			uint64_t value = *(uint64_t *) (rbp + 8);
			entry->stack[traceDepth++] = value;
			if (!value) break;
			rbp = *(uint64_t *) rbp;
		}

		break;
	}
}

static void MemoryLeakDetectorRemove(EsHeap *heap, void *address) {
	if (!address) {
		return;
	}

	for (uintptr_t i = 0; i < sizeof(heap->leakDetectorEntries) / sizeof(heap->leakDetectorEntries[0]); i++) {
		if (heap->leakDetectorEntries[i].address == address) {
			heap->leakDetectorEntries[i].address = nullptr;
			break;
		}
	}
}

static void MemoryLeakDetectorCheckpoint(EsHeap *heap) {
	EsPrint("--- MemoryLeakDetectorCheckpoint ---\n");

	for (uintptr_t i = 0; i < sizeof(heap->leakDetectorEntries) / sizeof(heap->leakDetectorEntries[0]); i++) {
		MemoryLeakDetectorEntry *entry = &heap->leakDetectorEntres[i];
		if (!entry->address) continue;
		entry->seenCount++;
		EsPrint("  %d %d %x %d\n", i, entry->seenCount, entry->address, entry->bytes);
	}
}
#endif

static void HeapRemoveFreeRegion(HeapRegion *region) {
	if (!region->regionListReference || region->used) {
		HEAP_PANIC(50, region, 0);
	}

	*region->regionListReference = region->regionListNext;

	if (region->regionListNext) {
		region->regionListNext->regionListReference = region->regionListReference;
	}

	region->regionListReference = nullptr;
}

static void HeapAddFreeRegion(HeapRegion *region, HeapRegion **heapRegions) {
	if (region->used || region->size < 32) {
		HEAP_PANIC(1, region, heapRegions);
	}

	int index = HeapCalculateIndex(region->size);
	region->regionListNext = heapRegions[index];
	if (region->regionListNext) region->regionListNext->regionListReference = &region->regionListNext;
	heapRegions[index] = region;
	region->regionListReference = heapRegions + index;
}

static void HeapValidate(EsHeap *heap) {
	if (heap->cannotValidate) return;

	for (uintptr_t i = 0; i < heap->blockCount; i++) {
		HeapRegion *start = (HeapRegion *) heap->blocks[i];
		if (!start) continue;

		HeapRegion *end = (HeapRegion *) ((uint8_t *) heap->blocks[i] + 65536);
		HeapRegion *previous = nullptr;
		HeapRegion *region = start;

		while (region < end) {
			if (previous && previous != HEAP_REGION_PREVIOUS(region)) {
				HEAP_PANIC(21, previous, region);
			}

			if (!previous && region->previous) {
				HEAP_PANIC(23, previous, region);
			}

			if (region->size & 31) {
				HEAP_PANIC(51, region, start);
			}

			if ((char *) region - (char *) start != region->offset) {
				HEAP_PANIC(22, region, start);
			}

			if (region->used != USED_HEAP_REGION_MAGIC && region->used != 0x0000) {
				HEAP_PANIC(24, region, region->used);
			}

			if (region->used == 0x0000 && !region->regionListReference) {
				HEAP_PANIC(25, region, region->regionListReference);
			}

			if (region->used == 0x0000 && region->regionListNext && region->regionListNext->regionListReference != &region->regionListNext) {
				HEAP_PANIC(26, region->regionListNext, region);
			}
				
			previous = region;
			region = HEAP_REGION_NEXT(region);
		}

		if (region != end) {
			HEAP_PANIC(20, region, end);
		}
	}
}

static void HeapPrintAllocatedRegions(EsHeap *heap) {
	EsPrint("--- Heap (%d allocations, %d bytes, %d blocks) ---\n", heap->allocationsCount, heap->size, heap->blockCount);
	HeapValidate(heap);
	if (heap->cannotValidate) return;

	for (uintptr_t i = 0; i < heap->blockCount; i++) {
		HeapRegion *start = (HeapRegion *) heap->blocks[i];
		if (!start) continue;

		HeapRegion *end = (HeapRegion *) ((uint8_t *) heap->blocks[i] + 65536);
		HeapRegion *region = start;

		while (region < end) {
			if (region->used == USED_HEAP_REGION_MAGIC) {
				EsPrint("%x %d\n", HEAP_REGION_DATA(region), region->size);
			}

			region = HEAP_REGION_NEXT(region);
		}
	}

	MemoryLeakDetectorCheckpoint(heap);
}

void *EsHeapAllocate(size_t size, bool zeroMemory, EsHeap *_heap) {
#ifndef KERNEL
	if (!_heap) _heap = &heap;
#endif
	EsHeap &heap = *(EsHeap *) _heap;
	if (!size) return nullptr;

#ifdef USE_PLATFORM_HEAP
	return PlatformHeapAllocate(size, zeroMemory);
#endif

	size_t largeAllocationThreshold = LARGE_ALLOCATION_THRESHOLD;

#ifndef KERNEL
	// EsPrint("Allocate: %d\n", size);
#else
	// EsPrint("%z: %d\n", mmvmm ? "CORE" : "KERN", size);
#endif

	size_t originalSize = size;

	if ((ptrdiff_t) size < 0) {
		HEAP_PANIC(0, 0, 0);
	}

	size += USED_HEAP_REGION_HEADER_SIZE; // Region metadata.
	size = (size + 0x1F) & ~0x1F; // Allocation granularity: 32 bytes.

	if (size >= largeAllocationThreshold) {
		// This is a very large allocation, so allocate it by itself.
		// We don't need to zero this memory. (It'll be done by the PMM).
		HeapRegion *region = (HeapRegion *) HEAP_ALLOCATE_CALL(size);
		if (!region) return nullptr; 
		region->used = USED_HEAP_REGION_MAGIC;
		region->size = 0;
		region->allocationSize = originalSize;
		__sync_fetch_and_add(&heap.size, originalSize);
		MemoryLeakDetectorAdd(&heap, HEAP_REGION_DATA(region), originalSize);
		return HEAP_REGION_DATA(region);
	}

	HEAP_ACQUIRE_MUTEX(heap.mutex);

	MAYBE_VALIDATE_HEAP();

	HeapRegion *region = nullptr;

	for (int i = HeapCalculateIndex(size); i < 12; i++) {
		if (heap.regions[i] == nullptr || heap.regions[i]->size < size) {
			continue;
		}

		region = heap.regions[i];
		HeapRemoveFreeRegion(region);
		goto foundRegion;
	}

	region = (HeapRegion *) HEAP_ALLOCATE_CALL(65536);
	if (heap.blockCount < 16) heap.blocks[heap.blockCount] = region;
	else heap.cannotValidate = true;
	heap.blockCount++;
	if (!region) {
		HEAP_RELEASE_MUTEX(heap.mutex);
		return nullptr; 
	}
	region->size = 65536 - 32;

	// Prevent EsHeapFree trying to merge off the end of the block.
	{
		HeapRegion *endRegion = HEAP_REGION_NEXT(region);
		endRegion->used = USED_HEAP_REGION_MAGIC;
		endRegion->offset = 65536 - 32;
		endRegion->next = 32;
		*((EsHeap **) HEAP_REGION_DATA(endRegion)) = &heap;
	}

	foundRegion:

	if (region->used || region->size < size) {
		HEAP_PANIC(4, region, size);
	}

	heap.allocationsCount++;
	__sync_fetch_and_add(&heap.size, size);

	if (region->size == size) {
		// If the size of this region is equal to the size of the region we're trying to allocate,
		// return this region immediately.
		region->used = USED_HEAP_REGION_MAGIC;
		region->allocationSize = originalSize;
		HEAP_RELEASE_MUTEX(heap.mutex);
		uint8_t *address = (uint8_t *) HEAP_REGION_DATA(region);
		if (zeroMemory) EsMemoryZero(address, originalSize);
#ifdef DEBUG_BUILD
		else EsMemoryFill(address, (uint8_t *) address + originalSize, 0xA1);
#endif
		MemoryLeakDetectorAdd(&heap, address, originalSize);
		return address;
	}

	// Split the region into 2 parts.
	
	HeapRegion *allocatedRegion = region;
	size_t oldSize = allocatedRegion->size;
	allocatedRegion->size = size;
	allocatedRegion->used = USED_HEAP_REGION_MAGIC;

	HeapRegion *freeRegion = HEAP_REGION_NEXT(allocatedRegion);
	freeRegion->size = oldSize - size;
	freeRegion->previous = size;
	freeRegion->offset = allocatedRegion->offset + size;
	freeRegion->used = false;
	HeapAddFreeRegion(freeRegion, heap.regions);

	HeapRegion *nextRegion = HEAP_REGION_NEXT(freeRegion);
	nextRegion->previous = freeRegion->size;

	MAYBE_VALIDATE_HEAP();

	region->allocationSize = originalSize;

	HEAP_RELEASE_MUTEX(heap.mutex);

	void *address = HEAP_REGION_DATA(region);

	if (zeroMemory) EsMemoryZero(address, originalSize);
#ifdef DEBUG_BUILD
	else EsMemoryFill(address, (uint8_t *) address + originalSize, 0xA1);
#endif

	MemoryLeakDetectorAdd(&heap, address, originalSize);
	return address;
}

void EsHeapFree(void *address, size_t expectedSize, EsHeap *_heap) {
#ifndef KERNEL
	if (!_heap) _heap = &heap;
#endif
	EsHeap &heap = *(EsHeap *) _heap;

	if (!address && expectedSize) HEAP_PANIC(10, address, expectedSize);
	if (!address) return;

#ifdef USE_PLATFORM_HEAP
	PlatformHeapFree(address);
	return;
#endif

	MemoryLeakDetectorRemove(&heap, address);

	HeapRegion *region = HEAP_REGION_HEADER(address);
	if (region->used != USED_HEAP_REGION_MAGIC) HEAP_PANIC(region->used, region, nullptr);
	if (expectedSize && region->allocationSize != expectedSize) HEAP_PANIC(6, region, expectedSize);

	if (!region->size) {
		// The region was allocated by itself.
		__sync_fetch_and_sub(&heap.size, region->allocationSize);
		HEAP_FREE_CALL(region);
		return;
	}

#ifdef DEBUG_BUILD
	EsMemoryFill(address, (uint8_t *) address + region->allocationSize, 0xB1);
#endif

	// Check this is the correct heap.

	if (*(EsHeap **) HEAP_REGION_DATA((uint8_t *) region - region->offset + 65536 - 32) != &heap) {
		HEAP_PANIC(52, address, 0);
	}

	HEAP_ACQUIRE_MUTEX(heap.mutex);

	MAYBE_VALIDATE_HEAP();

	region->used = false;

	if (region->offset < region->previous) {
		HEAP_PANIC(31, address, 0);
	}

	heap.allocationsCount--;
	__sync_fetch_and_sub(&heap.size, region->size);

	// Attempt to merge with the next region.

	HeapRegion *nextRegion = HEAP_REGION_NEXT(region);

	if (nextRegion && !nextRegion->used) {
		HeapRemoveFreeRegion(nextRegion);

		// Merge the regions.
		region->size += nextRegion->size;
		HEAP_REGION_NEXT(nextRegion)->previous = region->size;
	}

	// Attempt to merge with the previous region.

	HeapRegion *previousRegion = HEAP_REGION_PREVIOUS(region);

	if (previousRegion && !previousRegion->used) {
		HeapRemoveFreeRegion(previousRegion);

		// Merge the regions.
		previousRegion->size += region->size;
		HEAP_REGION_NEXT(region)->previous = previousRegion->size;
		region = previousRegion;
	}

	if (region->size == 65536 - 32) {
		if (region->offset) HEAP_PANIC(7, region, region->offset);

		// The memory block is empty.
		heap.blockCount--;

		if (!heap.cannotValidate) {
			bool found = false;

			for (uintptr_t i = 0; i <= heap.blockCount; i++) {
				if (heap.blocks[i] == region) {
					heap.blocks[i] = heap.blocks[heap.blockCount];
					found = true;
					break;
				}
			}

			EsAssert(found);
		}

		HEAP_FREE_CALL(region);
		HEAP_RELEASE_MUTEX(heap.mutex);
		return;
	}

	// Put the free region in the region list.
	HeapAddFreeRegion(region, heap.regions);

	MAYBE_VALIDATE_HEAP();

	HEAP_RELEASE_MUTEX(heap.mutex);
}

void *EsHeapReallocate(void *oldAddress, size_t newAllocationSize, bool zeroNewSpace, EsHeap *_heap) {
#ifndef KERNEL
	if (!_heap) _heap = &heap;
#endif
	EsHeap &heap = *(EsHeap *) _heap;

	/*
		Test with:
			void *a = EsHeapReallocate(nullptr, 128, true);
			a = EsHeapReallocate(a, 256, true);
			a = EsHeapReallocate(a, 128, true);
			a = EsHeapReallocate(a, 65536, true);
			a = EsHeapReallocate(a, 128, true);
			a = EsHeapReallocate(a, 128, true);
			void *b = EsHeapReallocate(nullptr, 64, true);
			void *c = EsHeapReallocate(nullptr, 64, true);
			EsHeapReallocate(b, 0, true);
			a = EsHeapReallocate(a, 128 + 88, true);
			a = EsHeapReallocate(a, 128, true);
			EsHeapReallocate(a, 0, true);
			EsHeapReallocate(c, 0, true);
	*/

	if (!oldAddress) {
		return EsHeapAllocate(newAllocationSize, zeroNewSpace, _heap);
	} else if (!newAllocationSize) {
		EsHeapFree(oldAddress, 0, _heap);
		return nullptr;
	}

#ifdef USE_PLATFORM_HEAP
	return PlatformHeapReallocate(oldAddress, newAllocationSize, zeroNewSpace);
#endif

	HeapRegion *region = HEAP_REGION_HEADER(oldAddress);

	if (region->used != USED_HEAP_REGION_MAGIC) {
		HEAP_PANIC(region->used, region, nullptr);
	}

	size_t oldAllocationSize = region->allocationSize;
	size_t oldRegionSize = region->size;
	size_t newRegionSize = (newAllocationSize + USED_HEAP_REGION_HEADER_SIZE + 0x1F) & ~0x1F;
	void *newAddress = oldAddress;
	bool inHeapBlock = region->size;
	bool canMerge = true;

	if (inHeapBlock) {
		HEAP_ACQUIRE_MUTEX(heap.mutex);
		MAYBE_VALIDATE_HEAP();

		HeapRegion *adjacent = HEAP_REGION_NEXT(region);

		if (oldRegionSize < newRegionSize) {
			if (!adjacent->used && newRegionSize < oldRegionSize + adjacent->size - FREE_HEAP_REGION_HEADER_SIZE) {
				HeapRegion *post = HEAP_REGION_NEXT(adjacent);
				HeapRemoveFreeRegion(adjacent);
				region->size = newRegionSize;
				adjacent = HEAP_REGION_NEXT(region);
				adjacent->next = (uint8_t *) post - (uint8_t *) adjacent;
				adjacent->used = 0;
				adjacent->offset = region->offset + region->size;
				post->previous = adjacent->next;
				adjacent->previous = region->next;
				HeapAddFreeRegion(adjacent, heap.regions);
			} else if (!adjacent->used && newRegionSize <= oldRegionSize + adjacent->size) {
				HeapRegion *post = HEAP_REGION_NEXT(adjacent);
				HeapRemoveFreeRegion(adjacent);
				region->size = newRegionSize;
				post->previous = region->next;
			} else {
				canMerge = false;
			}
		} else if (newRegionSize < oldRegionSize) {
			if (!adjacent->used) {
				HeapRegion *post = HEAP_REGION_NEXT(adjacent);
				HeapRemoveFreeRegion(adjacent);
				region->size = newRegionSize;
				adjacent = HEAP_REGION_NEXT(region);
				adjacent->next = (uint8_t *) post - (uint8_t *) adjacent;
				adjacent->used = 0;
				adjacent->offset = region->offset + region->size;
				post->previous = adjacent->next;
				adjacent->previous = region->next;
				HeapAddFreeRegion(adjacent, heap.regions);
			} else if (newRegionSize + USED_HEAP_REGION_HEADER_SIZE <= oldRegionSize) {
				region->size = newRegionSize;
				HeapRegion *middle = HEAP_REGION_NEXT(region);
				middle->size = oldRegionSize - newRegionSize;
				middle->used = 0;
				middle->previous = region->size;
				middle->offset = region->offset + region->size;
				adjacent->previous = middle->size;
				HeapAddFreeRegion(middle, heap.regions);
			}
		}

		MAYBE_VALIDATE_HEAP();
		HEAP_RELEASE_MUTEX(heap.mutex);
	} else {
		canMerge = false;
	}

	if (!canMerge) {
		newAddress = EsHeapAllocate(newAllocationSize, false, _heap);
		EsMemoryCopy(newAddress, oldAddress, oldAllocationSize > newAllocationSize ? newAllocationSize : oldAllocationSize);
		EsHeapFree(oldAddress, 0, _heap);
	} else {
		HEAP_REGION_HEADER(newAddress)->allocationSize = newAllocationSize;
		__sync_fetch_and_add(&heap.size, newRegionSize - oldRegionSize);
	}

	if (zeroNewSpace && newAllocationSize > oldAllocationSize) {
		EsMemoryZero((uint8_t *) newAddress + oldAllocationSize, newAllocationSize - oldAllocationSize);
	}
	return newAddress;
}

#ifndef KERNEL
void EsHeapValidate() {
	HeapValidate(&heap);

#endif

enum EsSyscallType {
	// Memory.

	ES_SYSCALL_MEMORY_ALLOCATE,
	ES_SYSCALL_MEMORY_FREE,
	ES_SYSCALL_MEMORY_MAP_OBJECT,
	ES_SYSCALL_MEMORY_OPEN,
	ES_SYSCALL_MEMORY_COMMIT,
	ES_SYSCALL_MEMORY_FAULT_RANGE,
	ES_SYSCALL_MEMORY_GET_AVAILABLE,

	// Processing.

	ES_SYSCALL_EVENT_CREATE,
	ES_SYSCALL_EVENT_RESET,
	ES_SYSCALL_EVENT_SET,
	ES_SYSCALL_PROCESS_CRASH,
	ES_SYSCALL_PROCESS_CREATE,
	ES_SYSCALL_PROCESS_GET_STATE,
	ES_SYSCALL_PROCESS_GET_STATUS,
	ES_SYSCALL_PROCESS_GET_TLS,
	ES_SYSCALL_PROCESS_OPEN,
	ES_SYSCALL_PROCESS_PAUSE,
	ES_SYSCALL_PROCESS_SET_TLS,
	ES_SYSCALL_PROCESS_TERMINATE,
	ES_SYSCALL_SLEEP,
	ES_SYSCALL_THREAD_CREATE,
	ES_SYSCALL_THREAD_GET_ID,
	ES_SYSCALL_THREAD_STACK_SIZE,
	ES_SYSCALL_THREAD_TERMINATE,
	ES_SYSCALL_WAIT,
	ES_SYSCALL_YIELD_SCHEDULER,

	// Windowing.

	ES_SYSCALL_MESSAGE_GET,
	ES_SYSCALL_MESSAGE_POST,
	ES_SYSCALL_MESSAGE_WAIT,

	ES_SYSCALL_CURSOR_POSITION_GET,
	ES_SYSCALL_CURSOR_POSITION_SET,
	ES_SYSCALL_CURSOR_PROPERTIES_SET,
	ES_SYSCALL_GAME_CONTROLLER_STATE_POLL,
	ES_SYSCALL_EYEDROP_START,
	ES_SYSCALL_SCREEN_WORK_AREA_SET,
	ES_SYSCALL_SCREEN_WORK_AREA_GET,
	ES_SYSCALL_SCREEN_BOUNDS_GET,
	ES_SYSCALL_SCREEN_FORCE_UPDATE,

	ES_SYSCALL_WINDOW_CREATE,
	ES_SYSCALL_WINDOW_CLOSE,
	ES_SYSCALL_WINDOW_REDRAW,
	ES_SYSCALL_WINDOW_MOVE,
	ES_SYSCALL_WINDOW_TRANSFER_PRESS,
	ES_SYSCALL_WINDOW_FIND_BY_POINT,
	ES_SYSCALL_WINDOW_GET_ID,
	ES_SYSCALL_WINDOW_GET_BOUNDS,
	ES_SYSCALL_WINDOW_SET_BITS,
	ES_SYSCALL_WINDOW_SET_CURSOR,
	ES_SYSCALL_WINDOW_SET_PROPERTY,

	ES_SYSCALL_MESSAGE_DESKTOP,

	// IO.

	ES_SYSCALL_NODE_OPEN,
	ES_SYSCALL_NODE_DELETE,
	ES_SYSCALL_NODE_MOVE,
	ES_SYSCALL_FILE_READ_SYNC,
	ES_SYSCALL_FILE_WRITE_SYNC,
	ES_SYSCALL_FILE_RESIZE,
	ES_SYSCALL_FILE_GET_SIZE,
	ES_SYSCALL_FILE_CONTROL,
	ES_SYSCALL_DIRECTORY_ENUMERATE,
	ES_SYSCALL_VOLUME_GET_INFORMATION,
	ES_SYSCALL_DEVICE_CONTROL,

	// Networking.

	ES_SYSCALL_DOMAIN_NAME_RESOLVE,
	ES_SYSCALL_ECHO_REQUEST,
	ES_SYSCALL_CONNECTION_OPEN,
	ES_SYSCALL_CONNECTION_POLL,
	ES_SYSCALL_CONNECTION_NOTIFY,

	// IPC.

	ES_SYSCALL_CONSTANT_BUFFER_READ,
	ES_SYSCALL_CONSTANT_BUFFER_CREATE,
	ES_SYSCALL_PIPE_CREATE,
	ES_SYSCALL_PIPE_WRITE,
	ES_SYSCALL_PIPE_READ,

	// Misc.

	ES_SYSCALL_HANDLE_CLOSE,
	ES_SYSCALL_HANDLE_SHARE,
	ES_SYSCALL_BATCH,
	ES_SYSCALL_DEBUG_COMMAND,
	ES_SYSCALL_POSIX,
	ES_SYSCALL_PRINT,
	ES_SYSCALL_SHUTDOWN,
	ES_SYSCALL_SYSTEM_TAKE_SNAPSHOT,
	ES_SYSCALL_PROCESSOR_COUNT,

	// End.

	ES_SYSCALL_COUNT,
};


// MMArchMapPage.
#define MM_MAP_PAGE_NOT_CACHEABLE 		(1 << 0)
#define MM_MAP_PAGE_USER 			(1 << 1)
#define MM_MAP_PAGE_OVERWRITE 			(1 << 2)
#define MM_MAP_PAGE_COMMIT_TABLES_NOW 		(1 << 3)
#define MM_MAP_PAGE_READ_ONLY			(1 << 4)
#define MM_MAP_PAGE_COPIED			(1 << 5)
#define MM_MAP_PAGE_NO_NEW_TABLES		(1 << 6)
#define MM_MAP_PAGE_FRAME_LOCK_ACQUIRED		(1 << 7)
#define MM_MAP_PAGE_WRITE_COMBINING		(1 << 8)
#define MM_MAP_PAGE_IGNORE_IF_MAPPED		(1 << 9)

// MMArchUnmapPages.
#define MM_UNMAP_PAGES_FREE 			(1 << 0)
#define MM_UNMAP_PAGES_FREE_COPIED		(1 << 1)
#define MM_UNMAP_PAGES_BALANCE_FILE		(1 << 2)

// MMPhysicalAllocate.
// --> Moved to module.h.

// MMHandlePageFault.
#define MM_HANDLE_PAGE_FAULT_WRITE 		(1 << 0)
#define MM_HANDLE_PAGE_FAULT_LOCK_ACQUIRED	(1 << 1)
#define MM_HANDLE_PAGE_FAULT_FOR_SUPERVISOR	(1 << 2)

// MMStandardAllocate - flags passed through into MMReserve.
// --> Moved to module.h.

// MMReserve - region types.
#define MM_REGION_PHYSICAL                      (0x0100) // The region is mapped to device memory.
#define MM_REGION_NORMAL                        (0x0200) // A normal region.
#define MM_REGION_SHARED                        (0x0400) // The region's contents is shared via a MMSharedRegion.
#define MM_REGION_GUARD	                        (0x0800) // A guard region, to make sure we don't accidentally go into other regions.
#define MM_REGION_CACHE	                        (0x1000) // Used for the file cache.
#define MM_REGION_FILE	                        (0x2000) // A mapped file. 

#define MM_SHARED_ENTRY_PRESENT 		(1)


#define MM_PHYSICAL_ALLOCATE_CAN_FAIL		(1 << 0)	// Don't panic if the allocation fails.
#define MM_PHYSICAL_ALLOCATE_COMMIT_NOW 	(1 << 1)	// Commit (fixed) the allocated pages.
#define MM_PHYSICAL_ALLOCATE_ZEROED		(1 << 2)	// Zero the pages.
#define MM_PHYSICAL_ALLOCATE_LOCK_ACQUIRED	(1 << 3)	// The page frame mutex is already acquired.





#define MM_HANDLE_PAGE_FAULT_WRITE 		(1 << 0)
#define MM_HANDLE_PAGE_FAULT_LOCK_ACQUIRED	(1 << 1)
#define MM_HANDLE_PAGE_FAULT_FOR_SUPERVISOR	(1 << 2)






enum EsDeviceType {
	ES_DEVICE_OTHER,
	ES_DEVICE_CONTROLLER,
	ES_DEVICE_FILE_SYSTEM,
	ES_DEVICE_GRAPHICS_TARGET,
	ES_DEVICE_BLOCK,
	ES_DEVICE_AUDIO,
	ES_DEVICE_KEYBOARD,
	ES_DEVICE_MOUSE,
	ES_DEVICE_GAME_CONTROLLER,
	ES_DEVICE_NETWORK_CARD,
	ES_DEVICE_USB,
	ES_DEVICE_PCI_FUNCTION,
	ES_DEVICE_CLOCK,
};

enum ProcessType {
	PROCESS_NORMAL,
	PROCESS_KERNEL,
	PROCESS_DESKTOP,
};

struct EsUniqueIdentifier {
	uint8_t d[16];
};

struct PhysicalMemoryRegion {
	uint64_t baseAddress;
	uint64_t pageCount;
};

struct _ArrayHeader {
	size_t length, allocated;
};

#define ArrayHeader(array) ((_ArrayHeader *) (array) - 1)
#define ArrayLength(array) ((array) ? (ArrayHeader(array)->length) : 0)

bool _ArrayMaybeInitialise(void **array, size_t itemSize, EsHeap *heap) {
	if (*array) return true;
	size_t newLength = 4;
	_ArrayHeader *header = (_ArrayHeader *) EsHeapAllocate(sizeof(_ArrayHeader) + itemSize * newLength, true, heap);
	if (!header) return false;
	header->length = 0;
	header->allocated = newLength;
	*array = header + 1;
	return true;
}

bool _ArrayEnsureAllocated(void **array, size_t minimumAllocated, size_t itemSize, uint8_t additionalHeaderBytes, EsHeap *heap) {
	if (!_ArrayMaybeInitialise(array, itemSize, heap)) {
		return false;
	}

	_ArrayHeader *oldHeader = ArrayHeader(*array);

	if (oldHeader->allocated >= minimumAllocated) {
		return true;
	}

	_ArrayHeader *newHeader = (_ArrayHeader *) EsHeapReallocate((uint8_t *) oldHeader - additionalHeaderBytes, 
			sizeof(_ArrayHeader) + additionalHeaderBytes + itemSize * minimumAllocated, false, heap);

	if (!newHeader) {
		return false;
	}

	newHeader->allocated = minimumAllocated;
	*array = (uint8_t *) (newHeader + 1) + additionalHeaderBytes;
	return true;
}

bool _ArraySetLength(void **array, size_t newLength, size_t itemSize, uint8_t additionalHeaderBytes, EsHeap *heap) {
	if (!_ArrayMaybeInitialise(array, itemSize, heap)) {
		return false;
	}

	_ArrayHeader *header = ArrayHeader(*array);

	if (header->allocated >= newLength) {
		header->length = newLength;
		return true;
	}

	if (!_ArrayEnsureAllocated(array, header->allocated * 2 > newLength ? header->allocated * 2 : newLength + 16, itemSize, additionalHeaderBytes, heap)) {
		return false;
	}

	header = ArrayHeader(*array);
	header->length = newLength;
	return true;
}

void _ArrayDelete(void *array, uintptr_t position, size_t itemSize, size_t count) {
	if (!count) return;
	size_t oldArrayLength = ArrayLength(array);
	if (position >= oldArrayLength) EsPanic("_ArrayDelete - Position out of bounds (%d/%d).\n", position, oldArrayLength);
	if (count > oldArrayLength - position) EsPanic("_ArrayDelete - Count out of bounds (%d/%d/%d).\n", position, count, oldArrayLength);
	ArrayHeader(array)->length = oldArrayLength - count;
	uint8_t *data = (uint8_t *) array;
	EsMemoryMove(data + itemSize * (position + count), data + itemSize * oldArrayLength, ES_MEMORY_MOVE_BACKWARDS itemSize * count, false);
}

void _ArrayDeleteSwap(void *array, uintptr_t position, size_t itemSize) {
	size_t oldArrayLength = ArrayLength(array);
	if (position >= oldArrayLength) EsPanic("_ArrayDeleteSwap - Position out of bounds (%d/%d).\n", position, oldArrayLength);
	ArrayHeader(array)->length = oldArrayLength - 1;
	uint8_t *data = (uint8_t *) array;
	EsMemoryCopy(data + itemSize * position, data + itemSize * ArrayLength(array), itemSize);
}

void *_ArrayInsert(void **array, const void *item, size_t itemSize, ptrdiff_t position, uint8_t additionalHeaderBytes, EsHeap *heap) {
	size_t oldArrayLength = ArrayLength(*array);
	if (position == -1) position = oldArrayLength;
	if (position < 0 || (size_t) position > oldArrayLength) EsPanic("_ArrayInsert - Position out of bounds (%d/%d).\n", position, oldArrayLength);
	if (!_ArraySetLength(array, oldArrayLength + 1, itemSize, additionalHeaderBytes, heap)) return nullptr;
	uint8_t *data = (uint8_t *) *array;
	EsMemoryMove(data + itemSize * position, data + itemSize * oldArrayLength, itemSize, false);
	if (item) EsMemoryCopy(data + itemSize * position, item, itemSize);
	else EsMemoryZero(data + itemSize * position, itemSize);
	return data + itemSize * position;
}

void *_ArrayInsertMany(void **array, size_t itemSize, ptrdiff_t position, size_t insertCount, EsHeap *heap) {
	size_t oldArrayLength = ArrayLength(*array);
	if (position == -1) position = oldArrayLength;
	if (position < 0 || (size_t) position > oldArrayLength) EsPanic("_ArrayInsertMany - Position out of bounds (%d/%d).\n", position, oldArrayLength);
	if (!_ArraySetLength(array, oldArrayLength + insertCount, itemSize, 0, heap)) return nullptr;
	uint8_t *data = (uint8_t *) *array;
	EsMemoryMove(data + itemSize * position, data + itemSize * oldArrayLength, itemSize * insertCount, false);
	return data + itemSize * position;
}

void _ArrayFree(void **array, size_t itemSize, EsHeap *heap) {
	if (!(*array)) return;
	EsHeapFree(ArrayHeader(*array), sizeof(_ArrayHeader) + itemSize * ArrayHeader(*array)->allocated, heap);
	*array = nullptr;
}


template <class T, EsHeap *heap>
struct Array
{
    T *array;

	inline size_t Length() { return array ? ArrayHeader(array)->length : 0; }
	inline T &First() { return array[0]; }
	inline T &Last() { return array[Length() - 1]; }
	inline void Delete(uintptr_t position) { _ArrayDelete(array, position, sizeof(T), 1); }
	inline void DeleteSwap(uintptr_t position) { _ArrayDeleteSwap(array, position, sizeof(T)); }
	inline void DeleteMany(uintptr_t position, size_t count) { _ArrayDelete(array, position, sizeof(T), count); }
	inline T *Add(T item) { return (T *) _ArrayInsert((void **) &array, &item, sizeof(T), -1, 0, heap); }
	inline T *Add() { return (T *) _ArrayInsert((void **) &array, nullptr, sizeof(T), -1, 0, heap); }
	inline T *Insert(T item, uintptr_t position) { return (T *) _ArrayInsert((void **) &array, &item, sizeof(T), position, 0, heap); }
	inline T *AddPointer(const T *item) { return (T *) _ArrayInsert((void **) &(array), item, sizeof(T), -1, 0, heap); }
	inline T *InsertPointer(const T *item, uintptr_t position) { return (T *) _ArrayInsert((void **) &array, item, sizeof(T), position, 0, heap); }
	inline T *InsertMany(uintptr_t position, size_t count) { return (T *) _ArrayInsertMany((void **) &array, sizeof(T), position, count, heap); }
	inline bool SetLength(size_t length) { return _ArraySetLength((void **) &array, length, sizeof(T), 0, heap); }
	inline void Free() { _ArrayFree((void **) &array, sizeof(T), heap); }
	inline T Pop() { T t = Last(); Delete(Length() - 1); return t; }
	inline T &operator[](uintptr_t index) { return array[index]; }

	inline intptr_t Find(T item, bool failIfNotFound) {
		for (uintptr_t i = 0; i < Length(); i++) {
			if (array[i] == item) {
				return i;
			}
		}

		if (failIfNotFound) EsPanic("Array::Find - Item not found in %x.\n", this);
		return -1;
	}

	inline bool FindAndDelete(T item, bool failIfNotFound) {
		intptr_t index = Find(item, failIfNotFound);
		if (index == -1) return false;
		Delete(index);
		return true;
	}

	inline bool FindAndDeleteSwap(T item, bool failIfNotFound) { 
		intptr_t index = Find(item, failIfNotFound);
		if (index == -1) return false;
		DeleteSwap(index);
		return true;
	}

	inline void AddFast(T item) { 
		if (!array) { Add(item); return; }
		_ArrayHeader *header = ArrayHeader(array);
		if (header->length == header->allocated) { Add(item); return; }
		array[header->length++] = item;
	}
};

struct Range {
	uintptr_t from, to;
};

struct RangeSet {
	Array<Range, K_CORE> ranges;
	uintptr_t contiguous;

    Range *Find(uintptr_t offset, bool touching) {
        if (!ranges.Length()) return nullptr;

        intptr_t low = 0, high = ranges.Length() - 1;

        while (low <= high) {
            intptr_t i = low + (high - low) / 2;
            Range *range = &ranges[i];

            if (range->from <= offset && (offset < range->to || (touching && offset <= range->to))) {
                return range;
            } else if (range->from <= offset) {
                low = i + 1;
            } else {
                high = i - 1;
            }
        }

        return nullptr;
    }

    bool Contains(uintptr_t offset) {
        if (ranges.Length()) {
            return Find(offset, false);
        } else {
            return offset < contiguous;
        }
    }

    void Validate() {
#ifdef DEBUG_BUILD
        uintptr_t previousTo = 0;

        if (!ranges.Length()) return;

        for (uintptr_t i = 0; i < ranges.Length(); i++) {
            Range *range = &ranges[i];

            if (previousTo && range->from <= previousTo) {
                KernelPanic("RangeSet::Validate - Range %d in set %x is not placed after the prior range.\n", i, this);
            }

            if (range->from >= range->to) {
                KernelPanic("RangeSet::Validate - Range %d in set %x is invalid.\n", i, this);
            }

            previousTo = range->to;
        }
#endif

#if 0
        for (uintptr_t i = 0; i < sizeof(check); i++) {
            if (check[i]) {
                assert(Find(set, i, false));
            } else {
                assert(!Find(set, i, false));
            }
        }
#endif
    }

    bool Normalize() {
        KernelLog(LOG_INFO, "RangeSet", "normalize", "Normalizing range set %x...\n", this);

        if (contiguous) {
            uintptr_t oldContiguous = contiguous;
            contiguous = 0;

            if (!Set(0, oldContiguous, nullptr, true)) {
                return false;
            }
        }

        return true;
    }

    bool Set(uintptr_t from, uintptr_t to, intptr_t *delta, bool modify) {
#if 0
        for (uintptr_t i = from; i < to; i++) {
            check[i] = true;
        }
#endif

        if (to <= from) {
            KernelPanic("RangeSet::Set - Invalid range %x to %x.\n", from, to);
        }

        // Can we store this as a single contiguous range?

        if (!ranges.Length()) {
            if (delta) {
                if (from >= contiguous) {
                    *delta = to - from;
                } else if (to >= contiguous) {
                    *delta = to - contiguous;
                } else {
                    *delta = 0;
                }
            }

            if (!modify) {
                return true;
            }

            if (from <= contiguous) {
                if (to > contiguous) {
                    contiguous = to;
                }

                return true;
            }

            if (!Normalize()) {
                return false;
            }
        }

        // Calculate the contiguous range covered.

        Range newRange = {};

        {
            Range *left = Find(from, true);
            Range *right = Find(to, true);

            newRange.from = left ? left->from : from;
            newRange.to = right ? right->to : to;
        }

        // Insert the new range.

        uintptr_t i = 0;

        for (; i <= ranges.Length(); i++) {
            if (i == ranges.Length() || ranges[i].to > newRange.from) {
                if (modify) {
                    if (!ranges.Insert(newRange, i)) {
                        return false;
                    }

                    i++;
                }

                break;
            }
        }

        // Remove overlapping ranges.

        uintptr_t deleteStart = i;
        size_t deleteCount = 0;
        uintptr_t deleteTotal = 0;

        for (; i < ranges.Length(); i++) {
            Range *range = &ranges[i];

            bool overlap = (range->from >= newRange.from && range->from <= newRange.to) 
                || (range->to >= newRange.from && range->to <= newRange.to);

            if (overlap) {
                deleteCount++;
                deleteTotal += range->to - range->from;
            } else {
                break;
            }
        }

        if (modify) {
            ranges.DeleteMany(deleteStart, deleteCount);
        }

        Validate();

        if (delta) {
            *delta = newRange.to - newRange.from - deleteTotal;
        }

        return true;

    }
    bool Clear(uintptr_t from, uintptr_t to, intptr_t *delta, bool modify) {
#if 0
        for (uintptr_t i = from; i < to; i++) {
            check[i] = false;
        }
#endif

        if (to <= from) {
            KernelPanic("RangeSet::Clear - Invalid range %x to %x.\n", from, to);
        }

        if (!ranges.Length()) {
            if (from < contiguous && contiguous) {
                if (to < contiguous) {
                    if (modify) {
                        if (!Normalize()) return false;
                    } else {
                        if (delta) *delta = from - to;
                        return true;
                    }
                } else {
                    if (delta) *delta = from - contiguous;
                    if (modify) contiguous = from;
                    return true;
                }
            } else {
                if (delta) *delta = 0;
                return true;
            }
        }

        if (!ranges.Length()) {
            ranges.Free();
            if (delta) *delta = 0;
            return true;
        }

        if (to <= ranges.First().from || from >= ranges.Last().to) {
            if (delta) *delta = 0;
            return true;
        }

        if (from <= ranges.First().from && to >= ranges.Last().to) {
            if (delta) {
                intptr_t total = 0;

                for (uintptr_t i = 0; i < ranges.Length(); i++) {
                    total += ranges[i].to - ranges[i].from;
                }

                *delta = -total;
            }

            if (modify) {
                ranges.Free();
            }

            return true;
        }

        // Find the first and last overlapping regions.

        uintptr_t overlapStart = ranges.Length();
        size_t overlapCount = 0;

        for (uintptr_t i = 0; i < ranges.Length(); i++) {
            Range *range = &ranges[i];

            if (range->to > from && range->from < to) {
                overlapStart = i;
                overlapCount = 1;
                break;
            }
        }

        for (uintptr_t i = overlapStart + 1; i < ranges.Length(); i++) {
            Range *range = &ranges[i];

            if (range->to >= from && range->from < to) {
                overlapCount++;
            } else {
                break;
            }
        }

        // Remove the overlapping sections.

        intptr_t _delta = 0;

        if (overlapCount == 1) {
            Range *range = &ranges[overlapStart];

            if (range->from < from && range->to > to) {
                Range newRange = { to, range->to };
                _delta -= to - from;

                if (modify) {
                    if (!ranges.Insert(newRange, overlapStart + 1)) {
                        return false;
                    }

                    ranges[overlapStart].to = from;
                }
            } else if (range->from < from) {
                _delta -= range->to - from;
                if (modify) range->to = from;
            } else if (range->to > to) {
                _delta -= to - range->from;
                if (modify) range->from = to;
            } else {
                _delta -= range->to - range->from;
                if (modify) ranges.Delete(overlapStart);
            }
        } else if (overlapCount > 1) {
            Range *left = &ranges[overlapStart];
            Range *right = &ranges[overlapStart + overlapCount - 1];

            if (left->from < from) {
                _delta -= left->to - from;
                if (modify) left->to = from;
                overlapStart++, overlapCount--;
            }

            if (right->to > to) {
                _delta -= to - right->from;
                if (modify) right->from = to;
                overlapCount--;
            }

            if (delta) {
                for (uintptr_t i = overlapStart; i < overlapStart + overlapCount; i++) {
                    _delta -= ranges[i].to - ranges[i].from;
                }
            }

            if (modify) {
                ranges.DeleteMany(overlapStart, overlapCount);
            }
        }

        if (delta) {
            *delta = _delta;
        }

        Validate();
        return true;

    }
};

struct KDevice {
	const char *cDebugName;

	KDevice *parent;                    // The parent device.
	Array<KDevice *, K_FIXED> children; // Child devices.

#define K_DEVICE_REMOVED         (1 << 0)
#define K_DEVICE_VISIBLE_TO_USER (1 << 1)   // A ES_MSG_DEVICE_CONNECTED message was sent to Desktop for this device.
	uint8_t flags;
	uint32_t handles;
	EsDeviceType type;
	EsObjectID objectID;

	// These callbacks are called with the deviceTreeMutex locked, and are all optional.
	void (*shutdown)(KDevice *device);  // Called when the computer is about to shutdown.
	void (*dumpState)(KDevice *device); // Dump the entire state of the device for debugging.
	void (*removed)(KDevice *device);   // Called when the device is removed. Called after the children are informed.
	void (*destroy)(KDevice *device);   // Called just before the device is destroyed.
};




#define ES_SNAPSHOT_MAX_PROCESS_NAME_LENGTH 	(31)

struct Process;
struct Thread;
struct Handle;
struct Scheduler;
struct MessageQueue;


struct EsThreadEventLogEntry {
	char file[31];
	uint8_t fileBytes;
	char expression[31];
	uint8_t expressionBytes;
	uint8_t event;
	uint16_t line;
	EsObjectID objectID, threadID;
};






struct EsProcessCreateData {
	EsHandle environment, initialMountPoints, initialDevices;
};

enum EsFatalError {
	ES_FATAL_ERROR_ABORT,
	ES_FATAL_ERROR_INCORRECT_FILE_ACCESS,
	ES_FATAL_ERROR_INCORRECT_NODE_TYPE,
	ES_FATAL_ERROR_INSUFFICIENT_PERMISSIONS,
	ES_FATAL_ERROR_INVALID_BUFFER,
	ES_FATAL_ERROR_INVALID_HANDLE,
	ES_FATAL_ERROR_INVALID_MEMORY_REGION,
	ES_FATAL_ERROR_OUT_OF_RANGE, // A parameter exceeds a limit, or is not a valid choice from an enumeration.
	ES_FATAL_ERROR_PROCESSOR_EXCEPTION,
	ES_FATAL_ERROR_RECURSIVE_BATCH,
	ES_FATAL_ERROR_UNKNOWN_SYSCALL,
	ES_FATAL_ERROR_COUNT,
};

struct EsCrashReason {
	EsFatalError errorCode;
	int32_t duringSystemCall;
};

#define ES_INVALID_HANDLE 		((EsHandle) (0))







// This file is part of the Essence operating system.
// It is released under the terms of the MIT license -- see LICENSE.md.
// Written by: nakst.




#define THREAD_PRIORITY_NORMAL 	(0) // Lower value = higher priority.
#define THREAD_PRIORITY_LOW 	(1)
#define THREAD_PRIORITY_COUNT	(2)

enum ThreadState : int8_t {
	THREAD_ACTIVE,			// An active thread. Not necessarily executing; `executing` determines if it executing.
	THREAD_WAITING_MUTEX,		// Waiting for a mutex to be released.
	THREAD_WAITING_EVENT,		// Waiting for a event to be notified.
	THREAD_WAITING_WRITER_LOCK,	// Waiting for a writer lock to be notified.
	THREAD_TERMINATED,		// The thread has been terminated. It will be deallocated when all handles are closed.
};

enum ThreadType : int8_t {
	THREAD_NORMAL,			// A normal thread.
	THREAD_IDLE,			// The CPU's idle thread.
	THREAD_ASYNC_TASK,		// A thread that processes the CPU's asynchronous tasks.
};

enum ThreadTerminatableState : int8_t {
	THREAD_INVALID_TS,
	THREAD_TERMINATABLE,		// The thread is currently executing user code.
	THREAD_IN_SYSCALL,		// The thread is currently executing kernel code from a system call.
					// It cannot be terminated/paused until it returns from the system call.
	THREAD_USER_BLOCK_REQUEST,	// The thread is sleeping because of a user system call to sleep.
					// It can be unblocked, and then terminated when it returns from the system call.
};

typedef void (*KAsyncTaskCallback)(struct KAsyncTask *task);

struct KAsyncTask {
	SimpleList item;
	KAsyncTaskCallback callback;
};

struct Thread {
	// ** Must be the first item in the structure; see MMArchSafeCopy. **
	bool inSafeCopy;

	LinkedItem<Thread> item;        // Entry in relevent thread queue or blockedThreads list for mutexes/writer locks.
	LinkedItem<Thread> allItem;     // Entry in the allThreads list.
	LinkedItem<Thread> processItem; // Entry in the process's list of threads.

	struct Process *process;

	EsObjectID id;
	volatile uintptr_t cpuTimeSlices;
	volatile size_t handles;
	uint32_t executingProcessorID;

	uintptr_t userStackBase;
	uintptr_t kernelStackBase;
	uintptr_t kernelStack;
	uintptr_t tlsAddress;
	size_t userStackReserve;
	volatile size_t userStackCommit;

	ThreadType type;
	bool isKernelThread, isPageGenerator;
	int8_t priority;
	int32_t blockedThreadPriorities[THREAD_PRIORITY_COUNT]; // The number of threads blocking on this thread at each priority level.

	volatile ThreadState state;
	volatile ThreadTerminatableState terminatableState;
	volatile bool executing;
	volatile bool terminating; 	// Set when a request to terminate the thread has been registered.
	volatile bool paused;	   	// Set to pause a thread. Paused threads are not executed (unless the terminatableState prevents that).
	volatile bool receivedYieldIPI; // Used to terminate a thread executing on a different processor.

	union {
		KMutex *volatile mutex;

		struct {
			KWriterLock *volatile writerLock;
			bool writerLockType;
		};

		struct {
			LinkedItem<Thread> *eventItems; // Entries in the blockedThreads lists (one per event).
			KEvent *volatile events[ES_MAX_WAIT_COUNT];
			volatile size_t eventCount; 
		};
	} blocking;

	KEvent killedEvent;
	KAsyncTask killAsyncTask;

	// If the type of the thread is THREAD_ASYNC_TASK,
	// then this is the virtual address space that should be loaded
	// when the task is being executed.
	MMSpace *volatile temporaryAddressSpace;

	InterruptContext *interruptContext;  // TODO Store the userland interrupt context instead?
	uintptr_t lastKnownExecutionAddress; // For debugging.

#ifdef ENABLE_POSIX_SUBSYSTEM
	struct POSIXThread *posixData;
#endif

	const char *cName;
};

struct KNode {
	void *driverNode;

	volatile size_t handles;
	struct FSDirectoryEntry *directoryEntry;
	struct KFileSystem *fileSystem;
	uint64_t id;
	KWriterLock writerLock; // Acquire before the parent's.
	EsError error;
	volatile uint32_t flags;
	MMObjectCacheItem cacheItem;
};

struct KNodeMetadata {
	// Metadata stored in the node's directory entry.
	EsNodeType type;
	bool removingNodeFromCache, removingThisFromCache;
	EsFileOffset totalSize;
	EsFileOffsetDifference directoryChildren; // ES_DIRECTORY_CHILDREN_UNKNOWN if not supported by the file system.
};

struct FSDirectoryEntry : KNodeMetadata {
	MMObjectCacheItem cacheItem;
	AVLItem<FSDirectoryEntry> item; // item.key.longKey contains the entry's name.
	struct FSDirectory *parent; // The directory containing this entry.
	KNode *volatile node; // nullptr if the node hasn't been loaded.
	char inlineName[16]; // Store the name of the entry inline if it is small enough.
	// Followed by driver data.
};

struct FSDirectory : KNode {
	AVLTree<FSDirectoryEntry> entries;
	size_t entryCount;
};

struct CCCachedSection {
	EsFileOffset offset, 			// The offset into the file.
		     pageCount;			// The number of pages in the section.
	volatile size_t mappedRegionsCount; 	// The number of mapped regions that use this section.
	uintptr_t *data;			// A list of page frames covering the section.
};

struct CCSpace;

struct CCSpaceCallbacks {
	EsError (*readInto)(CCSpace *fileCache, void *buffer, EsFileOffset offset, EsFileOffset count);
	EsError (*writeFrom)(CCSpace *fileCache, const void *buffer, EsFileOffset offset, EsFileOffset count);
};

struct CCSpace {
	// A sorted list of the cached sections in the file.
	// Maps offset -> physical address.
	KMutex cachedSectionsMutex;
	Array<struct CCCachedSection, K_CORE> cachedSections;

	// A sorted list of the active sections.
	// Maps offset -> virtual address.
	KMutex activeSectionsMutex;
	Array<struct CCActiveSectionReference, K_CORE> activeSections;

	// Used by CCSpaceFlush.
	KEvent writeComplete;

	// Callbacks.
	const struct CCSpaceCallbacks *callbacks;
};

struct FSFile : KNode {
	int32_t countWrite /* negative indicates non-shared readers */, blockResize;
	EsFileOffset fsFileSize; // Files are lazily resized; this is the size the file system thinks the file is.
	EsFileOffset fsZeroAfter; // This is the smallest size the file has reached without telling the file system.
	CCSpace cache;
	KWriterLock resizeLock; // Take exclusive for resizing or flushing.
};

struct EsRectangle {
	int32_t l; // Inclusive.
	int32_t r; // Exclusive.
	int32_t t; // Inclusive.
	int32_t b; // Exclusive.
};

struct EsElement;
struct EsBundle;
struct Instance;
struct EsMountPoint;

enum EsMessageType {
	ES_MSG_INVALID				= 0x0000,
		
	// Window manager messages (don't rearrange; see SendMessageToWindow in kernel/window_manager.cpp):
	ES_MSG_WM_START				= 0x1000,
	ES_MSG_MOUSE_MOVED 			= 0x1001,
	ES_MSG_WINDOW_ACTIVATED			= 0x1002,
	ES_MSG_WINDOW_DEACTIVATED		= 0x1003,
	ES_MSG_WINDOW_DESTROYED 		= 0x1004,
	ES_MSG_MOUSE_EXIT			= 0x1006 ,
	ES_MSG_WINDOW_RESIZED			= 0x1007,
	ES_MSG_MOUSE_LEFT_DOWN 			= 0x1008,	// Return ES_REJECTED to prevent taking focus, even if ES_ELEMENT_FOCUSABLE is set. Propagates.
	ES_MSG_MOUSE_LEFT_UP 			= 0x1009,	// Propagates.
	ES_MSG_MOUSE_RIGHT_DOWN 		= 0x100A,	// Propagates.
	ES_MSG_MOUSE_RIGHT_UP 			= 0x100B,	// Propagates.
	ES_MSG_MOUSE_MIDDLE_DOWN 		= 0x100C,	// Propagates.
	ES_MSG_MOUSE_MIDDLE_UP 			= 0x100D,	// Propagates.
	ES_MSG_KEY_DOWN				= 0x100E,	// Propagates to ancestors if unhandled.
	ES_MSG_KEY_UP				= 0x100F,
	ES_MSG_UPDATE_WINDOW			= 0x1010,
	ES_MSG_SCROLL_WHEEL			= 0x1011,
	ES_MSG_WM_END				= 0x13FF,

	// Internal GUI messages:				// None of these should be sent directly.
	ES_MSG_PAINT				= 0x2000,	// Paint the element using the painter specified in the message.
	ES_MSG_PAINT_BACKGROUND			= 0x2001,	// Paint the element's background. Sent before ES_MSG_PAINT. 
								// If unhandled, the background is drawn using the default settings. 
								// The width/height parameters of EsPainter may be larger than expected - this includes the 'non-client' area.
	ES_MSG_GET_CURSOR			= 0x2003,	// Get the cursor for the element.
	ES_MSG_ANIMATE				= 0x2004,	// Animate the element. Returns the number of microseconds to wait for the next frame, 
								// or whether the animation is complete.
	ES_MSG_Z_ORDER				= 0x2005,	// Get the child of an element based on its Z-order.
	ES_MSG_DESTROY				= 0x2006,	// The element has been marked to be destroyed. Free any resources allocated. 
								// Sent after the parent receives its ES_MSG_REMOVE_CHILD message.
	ES_MSG_GET_WIDTH			= 0x2007,	// Measure the element's width. If known, the height is specified.
	ES_MSG_GET_HEIGHT			= 0x2008,	// Measure the element's height. If known, the width is specified.
	ES_MSG_LAYOUT				= 0x2009,	// The size of the element has been updated. Layout the element's children.
	ES_MSG_ENSURE_VISIBLE			= 0x200A,	// Center the specified child (where possible) in your scrolled viewport.
	ES_MSG_ADD_CHILD			= 0x200B,	// An element has been created with this element as its parent.
	ES_MSG_REMOVE_CHILD			= 0x200C,	// An element has been destroyed with this element as its parent. 
								// Sent before the child receives its ES_MSG_DESTROY message. 
								// It will be removed from the `children` later (but before the next ES_MSG_LAYOUT message is received).
	ES_MSG_PRE_ADD_CHILD			= 0x200D,	// An element has been created with this element as its parent, but is not yet added to the parent.
	ES_MSG_HIT_TEST				= 0x200E,	// For non-rectangular elements: test whether a pixel should be considered inside the element. Set response to ES_HANDLED.
	ES_MSG_KEY_TYPED			= 0x2011,	// Sent to the focused element when a key is pressed. Only if ES_HANDLED is returned the message will not propagate; this allows messageUser to block input processing by returning ES_REJECTED.
	ES_MSG_SCROLL_X				= 0x2012,	// The element has been horizontally scrolled.
	ES_MSG_SCROLL_Y				= 0x2013,	// The element has been vertically scrolled.
	ES_MSG_STRONG_FOCUS_END			= 0x2014,	// Sent once when the user 'clicks off' the element, even if a new element was not necessarily focused.
	ES_MSG_BEFORE_Z_ORDER			= 0x2015,	// Sent before a batch of Z_ORDER messages.
	ES_MSG_AFTER_Z_ORDER			= 0x2016,	// Sent after a batch of Z_ORDER messages.
	ES_MSG_PAINT_CHILDREN			= 0x2017,	// Paint the element's children. Useful for animations, with EsPaintTargetTake/Return.
	ES_MSG_DESTROY_CONTENTS			= 0x2018,	// Sent after EsElementDestroyContents is called.
	ES_MSG_GET_INSPECTOR_INFORMATION	= 0x2019,	// Get a string containing information about the element to display in the inspector.
	ES_MSG_NOT_VISIBLE			= 0x2020,	// Sent to elements in the check visible list when they move off-screen.
	ES_MSG_GET_CHILD_STYLE_VARIANT		= 0x2021,	// Allows the parent of an element to customize its default style.
	ES_MSG_PAINT_ICON			= 0x2022,	// Sent during EsDrawContent.
	ES_MSG_MOUSE_LEFT_CLICK			= 0x2023,	// Indicates the element has been "clicked" (might be different for other input devices).
	ES_MSG_MOUSE_RIGHT_CLICK		= 0x2024,	// Right click, similar to LEFT_CLICK above.
	ES_MSG_MOUSE_MIDDLE_CLICK		= 0x2025,	// Middle click, similar to LEFT_CLICK above.
	ES_MSG_MOUSE_LEFT_DRAG			= 0x2026,	// Left button is pressed and the mouse is moving. 
								// Only starts being sent after a threshold is reached. 
								// This will NOT be sent if the element did not handle LEFT_DOWN.
	ES_MSG_MOUSE_RIGHT_DRAG			= 0x2027,	// Similar to LEFT_DRAG above, but for the right button. 
	ES_MSG_MOUSE_MIDDLE_DRAG		= 0x2028,	// Similar to LEFT_DRAG above, but for the middle button. 
	ES_MSG_GET_ACCESS_KEY_HINT_BOUNDS	= 0x2029,	// Get the bounds to display an access key hint.
	ES_MSG_UI_SCALE_CHANGED			= 0x202A,	// The UI scale has changed.
	ES_MSG_TRANSITION_COMPLETE		= 0x202B,	// The transition started with EsElementStartTransition completed.

	// State change messages: (causes a style refresh)
	ES_MSG_STATE_CHANGE_MESSAGE_START	= 0x2080,
	ES_MSG_HOVERED_START			= 0x2081,	// Sent when the mouse starts hovering over an element.
	ES_MSG_HOVERED_END			= 0x2082,	// Opposite of ES_MSG_HOVERED_START. Sent before ES_MSG_HOVERED_START is sent to the new hovered element.
	ES_MSG_PRESSED_START			= 0x2083,	// Sent when an element is pressed.
	ES_MSG_PRESSED_END			= 0x2084,	// Opposite of ES_MSG_PRESSED_START. 
	ES_MSG_FOCUSED_START			= 0x2085,	// Sent when an element is focused.
	ES_MSG_FOCUSED_END			= 0x2086,	// Opposite of ES_MSG_FOCUSED_START. 
	ES_MSG_FOCUS_WITHIN_START		= 0x2087,	// Sent when an element is focused.
	ES_MSG_FOCUS_WITHIN_END			= 0x2088,	// Opposite of ES_MSG_FOCUSED_START. 
	ES_MSG_STATE_CHANGE_MESSAGE_END		= 0x20FF,

	// Element messages:
	ES_MSG_SCROLLBAR_MOVED			= 0x3000,	// The scrollbar has been moved.
	ES_MSG_CHECK_UPDATED			= 0x3001,	// Button's check state has changed. See message->checkState.
	ES_MSG_RADIO_GROUP_UPDATED		= 0x3002,	// Sent to all siblings of a radiobox when it is checked, so they can uncheck themselves.
	ES_MSG_COLOR_CHANGED			= 0x3003,	// Color well's color has changed. See message->colorChanged.
	ES_MSG_LIST_DISPLAY_GET_MARKER		= 0x3004,	// Get the string for a marker in an EsListDisplay. See message->getContent.
	ES_MSG_SLIDER_MOVED			= 0x3006,	// The slider has been moved.

	// Desktop messages: 
	ES_MSG_EMBEDDED_WINDOW_DESTROYED 	= 0x4802,
	ES_MSG_SET_SCREEN_RESOLUTION		= 0x4803,
	ES_MSG_REGISTER_FILE_SYSTEM		= 0x4804,
	ES_MSG_UNREGISTER_FILE_SYSTEM		= 0x4805,
	ES_MSG_DESKTOP	                        = 0x4806,
	ES_MSG_DEVICE_CONNECTED			= 0x4807,
	ES_MSG_DEVICE_DISCONNECTED		= 0x4808,

	// Messages sent from Desktop to application instances:
	ES_MSG_TAB_INSPECT_UI			= 0x4A01,
	ES_MSG_TAB_CLOSE_REQUEST		= 0x4A02,
	ES_MSG_INSTANCE_SAVE_RESPONSE		= 0x4A03,	// Sent by Desktop after an application requested to save its document.
	ES_MSG_INSTANCE_DOCUMENT_RENAMED	= 0x4A04,
	ES_MSG_INSTANCE_DOCUMENT_UPDATED	= 0x4A05,
	ES_MSG_PRIMARY_CLIPBOARD_UPDATED	= 0x4A06,
	ES_MSG_INSTANCE_RENAME_RESPONSE		= 0x4A07,

	// Debugger messages:
	ES_MSG_APPLICATION_CRASH		= 0x4C00,
	ES_MSG_PROCESS_TERMINATED		= 0x4C01,

	// Undo item messages:
	ES_MSG_UNDO_CANCEL			= 0x4D00,
	ES_MSG_UNDO_INVOKE			= 0x4D01,
	ES_MSG_UNDO_TO_STRING			= 0x4D02,

	// Misc messages:
	ES_MSG_EYEDROP_REPORT			= 0x5001,
	ES_MSG_TIMER				= 0x5003,
	ES_MSG_PING				= 0x5004,	// Sent by Desktop to check processes are processing messages.
	ES_MSG_WAKEUP				= 0x5005,	// Sent to wakeup the message thread, so that it can process locally posted messages.

	// File Manager messages:
	ES_MSG_FILE_MANAGER_FILE_MODIFIED	= 0x5100,
	ES_MSG_FILE_MANAGER_PATH_MOVED		= 0x5101,
	ES_MSG_FILE_MANAGER_DOCUMENT_UPDATE	= 0x5102,	// The managed list of open documents has been updated.

	// Textbox messages:
	ES_MSG_TEXTBOX_UPDATED			= 0x5200,
	ES_MSG_TEXTBOX_EDIT_START		= 0x5201, 	// Set ES_TEXTBOX_EDIT_BASED to receive.
	ES_MSG_TEXTBOX_EDIT_END			= 0x5202, 	// Set ES_TEXTBOX_EDIT_BASED to receive.
	ES_MSG_TEXTBOX_NUMBER_DRAG_START	= 0x5203, 	// For EsTextboxUseNumberOverlay.
	ES_MSG_TEXTBOX_NUMBER_DRAG_END		= 0x5204, 	// For EsTextboxUseNumberOverlay.
	ES_MSG_TEXTBOX_NUMBER_DRAG_DELTA	= 0x5205, 	// For EsTextboxUseNumberOverlay.
	ES_MSG_TEXTBOX_NUMBER_UPDATED		= 0x5206, 	// For EsTextboxUseNumberOverlay with defaultBehaviour=true.
	ES_MSG_TEXTBOX_GET_BREADCRUMB		= 0x5207, 	// For EsTextboxUseBreadcrumbOverlay.
	ES_MSG_TEXTBOX_ACTIVATE_BREADCRUMB	= 0x5208, 	// For EsTextboxUseBreadcrumbOverlay.

	// List view messages:
	ES_MSG_LIST_VIEW_FIND_INDEX		= 0x5305,
	ES_MSG_LIST_VIEW_MEASURE_RANGE		= 0x5307,
	ES_MSG_LIST_VIEW_MEASURE_ITEM		= 0x5308,
	ES_MSG_LIST_VIEW_CREATE_ITEM		= 0x5309,
	ES_MSG_LIST_VIEW_GET_CONTENT		= 0x530A,
	ES_MSG_LIST_VIEW_GET_INDENT		= 0x530B,
	ES_MSG_LIST_VIEW_FIND_POSITION		= 0x530C,
	ES_MSG_LIST_VIEW_IS_SELECTED		= 0x530D,
	ES_MSG_LIST_VIEW_SELECT			= 0x530E,
	ES_MSG_LIST_VIEW_SELECT_RANGE		= 0x530F,
	ES_MSG_LIST_VIEW_CHOOSE_ITEM		= 0x5310,
	ES_MSG_LIST_VIEW_SEARCH			= 0x5311,
	ES_MSG_LIST_VIEW_CONTEXT_MENU		= 0x5312,
	ES_MSG_LIST_VIEW_COLUMN_MENU		= 0x5313,
	ES_MSG_LIST_VIEW_GET_SUMMARY		= 0x5314,
	ES_MSG_LIST_VIEW_GET_COLUMN_SORT	= 0x5315,

	// Reorder list messages:
	ES_MSG_REORDER_ITEM_TEST		= 0x5400,
	ES_MSG_REORDER_ITEM_MOVED		= 0x5401,

	// Application messages:
	ES_MSG_APPLICATION_EXIT			= 0x7001,
	ES_MSG_INSTANCE_CREATE			= 0x7002,
	ES_MSG_INSTANCE_OPEN			= 0x7003,
	ES_MSG_INSTANCE_SAVE			= 0x7004,
	ES_MSG_INSTANCE_DESTROY			= 0x7005,
	ES_MSG_INSTANCE_CLOSE			= 0x7006,

	// User messages:
	ES_MSG_USER_START			= 0x8000,
	ES_MSG_USER_END				= 0xBFFF,
};


struct EsFileStore {
#define FILE_STORE_HANDLE        (1)
#define FILE_STORE_PATH          (2)
#define FILE_STORE_EMBEDDED_FILE (3)
	uint8_t type;

	bool operationComplete;
	uint32_t handles;
	EsError error;

	union {
		EsHandle handle;

		struct {
			const EsBundle *bundle;
			char *path;
			size_t pathBytes;
		};
	};
};



struct EsBuffer {
	union { const uint8_t *in; uint8_t *out; };
	size_t position, bytes;
	void *context;
	EsFileStore *fileStore;
	bool error, canGrow;
};


struct EsMessageMouseMotion {
	int newPositionX;
	int newPositionY;
	int originalPositionX; // For MOUSE_DRAGGED only.
	int originalPositionY;
};

struct EsMessageMouseButton {
	int positionX;
	int positionY;
	uint8_t clickChainCount;
};

struct EsMessageKeyboard {
	uint16_t scancode; 
	uint8_t modifiers;
	bool repeat, numpad, numlock, single;
};

struct EsMessageWindowActivated {
	uint8_t leftModifiers, rightModifiers;
};

struct EsMessageScrollWheel {
	int32_t dx, dy;
};

struct EsMessageAnimate {
	int64_t deltaMs, waitMs;
	bool complete;
};

struct EsMessageLayout {
	bool sizeChanged;
};

struct EsMessageWindowResized {
	EsRectangle content;
	bool hidden;
};

struct EsMessageMeasure {
	int width, height;
};

struct EsMessageHitTest {
	int x, y;
	bool inside;
};

struct EsMessageZOrder {
	uintptr_t index;
	EsElement *child;
};

struct EsMessageBeforeZOrder {
	uintptr_t start, end, nonClient;
	EsRectangle clip;
};

struct EsMessageItemToString {
	EsGeneric item;
	const char* text;
};

// List view messages.

struct EsMessageIterateIndex {
	EsListViewIndex group;
	EsListViewIndex index;

	// FIND_INDEX and FIND_POSITION: (TODO Pass the reference item?)
	int64_t position;
};

struct EsMessageItemRange {
	EsListViewIndex group;
	EsListViewIndex firstIndex;
	uint64_t count;
	int64_t result;
};

struct EsMessageMeasureItem {
	EsListViewIndex group;
	EsListViewIndex index;
	int64_t result;
};

struct EsMessageCreateItem {
	EsListViewIndex group;
	EsListViewIndex index;
	EsElement *item;
};



struct EsMessageGetContent {
	EsListViewIndex index;
	EsListViewIndex group;
	uint32_t icon;
	uint32_t drawContentFlags;
	EsBuffer *buffer;
	uint8_t column;
};

struct EsMessageGetIndent {
	EsListViewIndex group;
	EsListViewIndex index;

	uint8_t indent;
};

struct EsMessageSelectRange {
	EsListViewIndex fromIndex, toIndex;
	EsListViewIndex group; 
	bool select, toggle;
};

struct EsMessageSelectItem {
	EsListViewIndex group;
	EsListViewIndex index;
	bool isSelected;
};

struct EsMessageChooseItem {
	EsListViewIndex group;
	EsListViewIndex index;
};

struct EsMessageSearchItem {
	EsListViewIndex group;
	EsListViewIndex index;
	const char* query;
};

struct EsMessageFocus {
	uint32_t flags;
};

struct EsMessageColumnMenu {
	uint8_t index;
	EsElement *source;
};

struct EsMessageGetColumnSort {
	uint8_t index;
};

// Specific element messages.

struct EsMessageScrollbarMoved {
	int scroll, previous;
};

struct EsMessageSliderMoved {
	double value, previous;
	bool inDrag;
};

struct EsMessageColorChanged {
	uint32_t newColor;
	bool pickerClosed;
};

struct EsMessageNumberDragDelta {
	int delta;
	int32_t hoverCharacter;
	bool fast;
};

struct EsMessageNumberUpdated {
	double delta;
	double newValue;
};

struct EsMessageGetBreadcrumb {
	uintptr_t index; // Set response to ES_REJECTED if this equals the number of breadcrumbs.
	EsBuffer *buffer;
	uint32_t icon;
};

struct EsMessageEndEdit {
	bool rejected, unchanged;
};

// Instance messages.

struct EsMessageInstanceOpen {
	ES_INSTANCE_TYPE *instance;
	EsFileStore *file;
	const char* name;
	bool update;
};

struct EsMessageInstanceSave {
	ES_INSTANCE_TYPE *instance;
	EsFileStore *file;
	const char* name;
};

struct EsMessageInstanceDestroy {
	ES_INSTANCE_TYPE *instance;
};

struct EsMessageInstanceClose {
	ES_INSTANCE_TYPE *instance;
};

// Internal system messages.

struct EsMessageProcessCrash {
	EsCrashReason reason;
	uintptr_t pid;
};

struct EsMessageDesktop {
	EsObjectID windowID, processID;
	EsHandle buffer, pipe;
	size_t bytes;
};

struct EsMessageEyedrop {
	uint32_t color;
	bool cancelled;
};

struct EsMessageCreateInstance {
	EsHandle window;
	EsHandle data;
	size_t dataBytes;
};

struct EsMessageTabOperation {
	EsObjectID id;
	EsHandle handle;
	union { size_t bytes; bool isSource; };
	EsError error;
};

struct EsMessageRegisterFileSystem {
	EsHandle rootDirectory;
	bool isBootFileSystem;
	EsMountPoint *mountPoint;
};

struct EsMessageUnregisterFileSystem {
	EsObjectID id;
	EsMountPoint *mountPoint;
};

struct EsMessageDevice {
	EsObjectID id;
	EsHandle handle;
	EsDeviceType type;
};

// Message structure.

struct EsMessageUser {
	EsGeneric context1, context2, context3, context4;
};

struct EsStyle;
struct EsPainter;


enum EsCursorStyle {
	ES_CURSOR_NORMAL,
	ES_CURSOR_TEXT ,
	ES_CURSOR_RESIZE_VERTICAL ,
	ES_CURSOR_RESIZE_HORIZONTAL,
	ES_CURSOR_RESIZE_DIAGONAL_1, // '/'
	ES_CURSOR_RESIZE_DIAGONAL_2, // '\'
	ES_CURSOR_SPLIT_VERTICAL,
	ES_CURSOR_SPLIT_HORIZONTAL,
	ES_CURSOR_HAND_HOVER,
	ES_CURSOR_HAND_DRAG,
	ES_CURSOR_HAND_POINT,
	ES_CURSOR_SCROLL_UP_LEFT,
	ES_CURSOR_SCROLL_UP,
	ES_CURSOR_SCROLL_UP_RIGHT,
	ES_CURSOR_SCROLL_LEFT,
	ES_CURSOR_SCROLL_CENTER,
	ES_CURSOR_SCROLL_RIGHT,
	ES_CURSOR_SCROLL_DOWN_LEFT,
	ES_CURSOR_SCROLL_DOWN,
	ES_CURSOR_SCROLL_DOWN_RIGHT,
	ES_CURSOR_SELECT_LINES,
	ES_CURSOR_DROP_TEXT,
	ES_CURSOR_CROSS_HAIR_PICK,
	ES_CURSOR_CROSS_HAIR_RESIZE,
	ES_CURSOR_MOVE_HOVER,
	ES_CURSOR_MOVE_DRAG,
	ES_CURSOR_ROTATE_HOVER,
	ES_CURSOR_ROTATE_DRAG,
	ES_CURSOR_BLANK,
	ES_CURSOR_COUNT,
};

enum EsCheckState {
	ES_CHECK_UNCHECKED = 0,
	ES_CHECK_CHECKED = 1,
	ES_CHECK_INDETERMINATE = 2,
};

struct EsMessage {
	EsMessageType type;

	union {
		struct { uintptr_t _size[4]; } _size; // EsMessagePost supports messages at most 4 pointers in size.
		EsMessageUser user; // For application specific messages.

		// User interface messages:
		EsMessageMouseMotion mouseMoved;
		EsMessageMouseMotion mouseDragged;
		EsMessageMouseButton mouseDown;
		EsMessageKeyboard keyboard;
		EsMessageWindowResized windowResized;
		EsMessageAnimate animate;
		EsMessageLayout layout;
		EsMessageMeasure measure;
		EsMessageHitTest hitTest;
		EsMessageZOrder zOrder;
		EsMessageBeforeZOrder beforeZOrder;
		EsMessageItemToString itemToString;
		EsMessageFocus focus;
		EsMessageScrollWheel scrollWheel;
		EsMessageWindowActivated windowActivated;
		const EsStyle *childStyleVariant;
		EsRectangle *accessKeyHintBounds;
		EsPainter *painter;
		EsElement *child;
		EsCursorStyle cursorStyle;

		// List view messages:
		EsMessageIterateIndex iterateIndex;
		EsMessageItemRange itemRange;
		EsMessageMeasureItem measureItem;
		EsMessageCreateItem createItem;
		EsMessageGetContent getContent;
		EsMessageGetIndent getIndent;
		EsMessageSelectRange selectRange;
		EsMessageSelectItem selectItem;
		EsMessageChooseItem chooseItem;
		EsMessageSearchItem searchItem;
		EsMessageColumnMenu columnMenu;
		EsMessageGetColumnSort getColumnSort;

		// Specific element messages:
		EsMessageScrollbarMoved scrollbarMoved;
		EsMessageSliderMoved sliderMoved;
		EsMessageColorChanged colorChanged;
		EsMessageNumberDragDelta numberDragDelta;
		EsMessageNumberUpdated numberUpdated;
		EsMessageGetBreadcrumb getBreadcrumb;
		EsMessageEndEdit endEdit;
		uintptr_t activateBreadcrumb;
		EsCheckState checkState;

		// Instance messages:
		EsMessageInstanceOpen instanceOpen;
		EsMessageInstanceSave instanceSave;
		EsMessageInstanceDestroy instanceDestroy;
		EsMessageInstanceClose instanceClose;

		// Internal messages:
		void *_argument;
		EsMessageProcessCrash crash;
		EsMessageDesktop desktop;
		EsMessageEyedrop eyedrop;
		EsMessageCreateInstance createInstance;
		EsMessageTabOperation tabOperation;
		EsMessageRegisterFileSystem registerFileSystem;
		EsMessageUnregisterFileSystem unregisterFileSystem;
		EsMessageDevice device;
	};
};

struct _EsMessageWithObject {
	void *object;
	EsMessage message;
};

struct MessageQueue {
	bool SendMessage(void *target, EsMessage *message); // Returns false if the message queue is full.
	bool SendMessage(_EsMessageWithObject *message); // Returns false if the message queue is full.
	bool GetMessage(_EsMessageWithObject *message);

#define MESSAGE_QUEUE_MAX_LENGTH (4096)
	Array<_EsMessageWithObject, K_FIXED> messages;

	uintptr_t mouseMovedMessage, 
		  windowResizedMessage, 
		  eyedropResultMessage,
		  keyRepeatMessage;

	bool pinged;

	KMutex mutex;
	KEvent notEmpty;
};

struct Handle {
	void *object;	
	uint32_t flags;
	KernelObjectType type;
};

extern uint64_t totalHandleCount;

struct HandleTableL2 {
#define HANDLE_TABLE_L2_ENTRIES (256)
	Handle t[HANDLE_TABLE_L2_ENTRIES];
};

struct HandleTableL1 {
#define HANDLE_TABLE_L1_ENTRIES (256)
	HandleTableL2 *t[HANDLE_TABLE_L1_ENTRIES];
	uint16_t u[HANDLE_TABLE_L1_ENTRIES];
};

struct HandleTable {
	HandleTableL1 l1r;
	KMutex lock;
	struct Process *process;
	bool destroyed;
	uint32_t handleCount;

	// Be careful putting handles in the handle table!
	// The process will be able to immediately close it.
	// If this fails, the handle is closed and ES_INVALID_HANDLE is returned.
	EsHandle OpenHandle(void *_object, uint32_t _flags, KernelObjectType _type, EsHandle at = ES_INVALID_HANDLE);

	bool CloseHandle(EsHandle handle);
	void ModifyFlags(EsHandle handle, uint32_t newFlags);

	// Resolve the handle if it is valid.
	// The initial value of type is used as a mask of expected object types for the handle.
#define RESOLVE_HANDLE_FAILED (0)
#define RESOLVE_HANDLE_NO_CLOSE (1)
#define RESOLVE_HANDLE_NORMAL (2)
	uint8_t ResolveHandle(Handle *outHandle, EsHandle inHandle, KernelObjectType typeMask); 


    void Destroy() {
	KMutexAcquire(&lock);
	EsDefer(KMutexRelease(&lock));

	if (destroyed) {
		return;
	}

	destroyed = true;
	HandleTableL1 *l1 = &l1r;

	for (uintptr_t i = 0; i < HANDLE_TABLE_L1_ENTRIES; i++) {
		if (!l1->u[i]) continue;

		for (uintptr_t k = 0; k < HANDLE_TABLE_L2_ENTRIES; k++) {
			Handle *handle = &l1->t[i]->t[k];
			if (handle->object) CloseHandleToObject(handle->object, handle->type, handle->flags);
		}

		EsHeapFree(l1->t[i], 0, K_FIXED);
	}
}

};

struct Process {
	MMSpace *vmm;
    MessageQueue messageQueue;
	HandleTable handleTable;

	LinkedList<Thread> threads;
	KMutex threadsMutex;

	// Creation information:
	KNode *executableNode;
	char cExecutableName[ES_SNAPSHOT_MAX_PROCESS_NAME_LENGTH + 1];
	EsProcessCreateData data;
	uint64_t permissions;
	uint32_t creationFlags; 
	ProcessType type;

	// Object management:
	EsObjectID id;
	volatile size_t handles;
	LinkedItem<Process> allItem;

	// Crashing:
	KMutex crashMutex;
	EsCrashReason crashReason;
	bool crashed;

	// Termination:
	bool allThreadsTerminated;
	bool blockShutdown;
	bool preventNewThreads; // Set by ProcessTerminate.
	int exitStatus; // TODO Remove this.
	KEvent killedEvent;

	// Executable state:
	uint8_t executableState;
	bool executableStartRequest;
	KEvent executableLoadAttemptComplete;
	Thread *executableMainThread;

	// Statistics:
	uintptr_t cpuTimeSlices, idleTimeSlices;

	// POSIX:
#ifdef ENABLE_POSIX_SUBSYSTEM
	bool posixForking;
	int pgid;
#endif
};

Process _kernelProcess;
Process _desktopProcess;
Process* kernelProcess = &_kernelProcess;
Process* desktopProcess = &_desktopProcess;

#define SPAWN_THREAD_USERLAND     (1 << 0)
#define SPAWN_THREAD_LOW_PRIORITY (1 << 1)
#define SPAWN_THREAD_PAUSED       (1 << 2)
#define SPAWN_THREAD_ASYNC_TASK   (1 << 3)
#define SPAWN_THREAD_IDLE         (1 << 4)

#define THREAD_PRIORITY_NORMAL 	(0) // Lower value = higher priority.
#define THREAD_PRIORITY_LOW 	(1)
#define THREAD_PRIORITY_COUNT	(2)

struct KTimer {
	KEvent event;
	KAsyncTask asyncTask;
	LinkedItem<KTimer> item;
	uint64_t triggerTimeMs;
	KAsyncTaskCallback callback;
	EsGeneric argument;
};

void KTimerSet(KTimer *timer, uint64_t triggerInMs, KAsyncTaskCallback callback = nullptr, EsGeneric argument = 0);
void KTimerRemove(KTimer *timer); // Timers with callbacks cannot be removed (it'd race with async task delivery).
struct Scheduler {
	void Yield(InterruptContext *context);
	void CreateProcessorThreads(CPULocalStorage *local);
	void AddActiveThread(Thread *thread, bool start /* put it at the start of the active list */) // Add an active thread into the queue.
    {
        if (thread->type == THREAD_ASYNC_TASK) {
            // An asynchronous task thread was unblocked.
            // It will be run immediately, so there's no need to add it to the active thread list.
            return;
        }

        KSpinlockAssertLocked(&dispatchSpinlock);

        if (thread->state != THREAD_ACTIVE) {
            KernelPanic("Scheduler::AddActiveThread - Thread %d not active\n", thread->id);
        } else if (thread->executing) {
            KernelPanic("Scheduler::AddActiveThread - Thread %d executing\n", thread->id);
        } else if (thread->type != THREAD_NORMAL) {
            KernelPanic("Scheduler::AddActiveThread - Thread %d has type %d\n", thread->id, thread->type);
        } else if (thread->item.list) {
            KernelPanic("Scheduler::AddActiveThread - Thread %d is already in queue %x.\n", thread->id, thread->item.list);
        }

        if (thread->paused && thread->terminatableState == THREAD_TERMINATABLE) {
            // The thread is paused, so we can put it into the paused queue until it is resumed.
            pausedThreads.InsertStart(&thread->item);
        } else {
            int8_t effectivePriority = GetThreadEffectivePriority(thread);

            if (start) {
                activeThreads[effectivePriority].InsertStart(&thread->item);
            } else {
                activeThreads[effectivePriority].InsertEnd(&thread->item);
            }
        }

    }
	void MaybeUpdateActiveList(Thread *thread); // After changing the priority of a thread, call this to move it to the correct active thread queue if needed.
    void NotifyObject(LinkedList<Thread> *blockedThreads, bool unblockAll, Thread *previousMutexOwner = nullptr) {
        KSpinlockAssertLocked(&dispatchSpinlock);

        LinkedItem<Thread> *unblockedItem = blockedThreads->firstItem;

        if (!unblockedItem) {
            // There weren't any threads blocking on the object.
            return; 
        }

        do {
            LinkedItem<Thread> *nextUnblockedItem = unblockedItem->nextItem;
            Thread *unblockedThread = unblockedItem->thisItem;
            UnblockThread(unblockedThread, previousMutexOwner);
            unblockedItem = nextUnblockedItem;
        } while (unblockAll && unblockedItem);
    }
    void UnblockThread(Thread *unblockedThread, Thread *previousMutexOwner = nullptr) {
        KSpinlockAssertLocked(&dispatchSpinlock);

        if (unblockedThread->state == THREAD_WAITING_MUTEX) {
            if (unblockedThread->item.list) {
                // If we get here from KMutex::Release -> Scheduler::NotifyObject -> Scheduler::UnblockedThread,
                // the mutex owner has already been cleared to nullptr, so use the previousMutexOwner parameter.
                // But if we get here from Scheduler::TerminateThread, the mutex wasn't released;
                // rather, the waiting thread was unblocked as it is in the WAIT system call, but needs to terminate.

                if (!previousMutexOwner) {
                    KMutex *mutex = EsContainerOf(KMutex, blockedThreads, unblockedThread->item.list);

                    if (&mutex->blockedThreads != unblockedThread->item.list) {
                        KernelPanic("Scheduler::UnblockThread - Unblocked thread %x was not in a mutex blockedThreads list.\n", 
                                unblockedThread);
                    }

                    previousMutexOwner = mutex->owner;
                }

                if (!previousMutexOwner->blockedThreadPriorities[unblockedThread->priority]) {
                    KernelPanic("Scheduler::UnblockThread - blockedThreadPriorities was zero (%x/%x).\n", 
                            unblockedThread, previousMutexOwner);
                }

                previousMutexOwner->blockedThreadPriorities[unblockedThread->priority]--;
                MaybeUpdateActiveList(previousMutexOwner);

                unblockedThread->item.RemoveFromList();
            }
        } else if (unblockedThread->state == THREAD_WAITING_EVENT) {
            for (uintptr_t i = 0; i < unblockedThread->blocking.eventCount; i++) {
                if (unblockedThread->blocking.eventItems[i].list) {
                    unblockedThread->blocking.eventItems[i].RemoveFromList();
                }
            }
        } else if (unblockedThread->state == THREAD_WAITING_WRITER_LOCK) {
            if (unblockedThread->item.list) {
                KWriterLock *lock = EsContainerOf(KWriterLock, blockedThreads, unblockedThread->item.list);

                if (&lock->blockedThreads != unblockedThread->item.list) {
                    KernelPanic("Scheduler::UnblockThread - Unblocked thread %x was not in a writer lock blockedThreads list.\n", 
                            unblockedThread);
                }

                if ((unblockedThread->blocking.writerLockType == K_LOCK_SHARED && lock->state >= 0)
                        || (unblockedThread->blocking.writerLockType == K_LOCK_EXCLUSIVE && lock->state == 0)) {
                    unblockedThread->item.RemoveFromList();
                }
            }
        } else {
            KernelPanic("Scheduler::UnblockedThread - Blocked thread in invalid state %d.\n", 
                    unblockedThread->state);
        }

        unblockedThread->state = THREAD_ACTIVE;

        if (!unblockedThread->executing) {
            // Put the unblocked thread at the start of the activeThreads list
            // so that it is immediately executed when the scheduler yields.
            AddActiveThread(unblockedThread, true);
        } 

        // TODO If any processors are idleing, send them a yield IPI.

    }
	Thread *PickThread(CPULocalStorage *local); // Pick the next thread to execute.
	int8_t GetThreadEffectivePriority(Thread *thread);

	KSpinlock dispatchSpinlock; // For accessing synchronisation objects, thread states, scheduling lists, etc. TODO Break this up!
	KSpinlock activeTimersSpinlock; // For accessing the activeTimers lists.
	LinkedList<Thread> activeThreads[THREAD_PRIORITY_COUNT];
	LinkedList<Thread> pausedThreads;
	LinkedList<KTimer> activeTimers;

	KMutex allThreadsMutex; // For accessing the allThreads list.
	KMutex allProcessesMutex; // For accessing the allProcesses list.
	KSpinlock asyncTaskSpinlock; // For accessing the per-CPU asyncTaskList.
	LinkedList<Thread> allThreads;
	LinkedList<Process> allProcesses;

	Pool threadPool, processPool, mmSpacePool;
	EsObjectID nextThreadID, nextProcessID, nextProcessorID;

	KEvent allProcessesTerminatedEvent; // Set during shutdown when all processes have been terminated.
	volatile uintptr_t blockShutdownProcessCount;
	volatile size_t activeProcessCount;
	volatile bool started, panic, shutdown;
	uint64_t timeMs;

#ifdef DEBUG_BUILD
	EsThreadEventLogEntry *volatile threadEventLog;
	volatile uintptr_t threadEventLogPosition;
	volatile size_t threadEventLogAllocated;
#endif
};
Scheduler scheduler;

void KTimerSet(KTimer *timer, uint64_t triggerInMs, KAsyncTaskCallback _callback, EsGeneric _argument) {
	KSpinlockAcquire(&scheduler.activeTimersSpinlock);

	// Reset the timer state.

	if (timer->item.list) {
		scheduler.activeTimers.Remove(&timer->item);
	}

	KEventReset(&timer->event);

	// Set the timer information.

	timer->triggerTimeMs = triggerInMs + scheduler.timeMs;
	timer->callback = _callback;
	timer->argument = _argument;
	timer->item.thisItem = timer;

	// Add the timer to the list of active timers, keeping the list sorted by trigger time.

	LinkedItem<KTimer> *_timer = scheduler.activeTimers.firstItem;

	while (_timer) {
		KTimer *timer2 = _timer->thisItem;
		LinkedItem<KTimer> *next = _timer->nextItem;

		if (timer2->triggerTimeMs > timer->triggerTimeMs) {
			break; // Insert before this timer.
		}

		_timer = next;
	}

	if (_timer) {
		scheduler.activeTimers.InsertBefore(&timer->item, _timer);
	} else {
		scheduler.activeTimers.InsertEnd(&timer->item);
	}

	KSpinlockRelease(&scheduler.activeTimersSpinlock);
}

void KTimerRemove(KTimer *timer) {
	KSpinlockAcquire(&scheduler.activeTimersSpinlock);

	if (timer->callback) {
		KernelPanic("KTimer::Remove - Timers with callbacks cannot be removed.\n");
	}

	if (timer->item.list) {
		scheduler.activeTimers.Remove(&timer->item);
	}

	KSpinlockRelease(&scheduler.activeTimersSpinlock);
}



bool KEventSet(KEvent *event, bool maybeAlreadySet) {
	if (event->state && !maybeAlreadySet) {
		KernelLog(LOG_ERROR, "Synchronisation", "event already set", "KEventSet - Attempt to set a event that had already been set\n");
	}

	KSpinlockAcquire(&scheduler.dispatchSpinlock);
	volatile bool unblockedThreads = false;

	if (!event->state) {
		event->state = true;

		if (scheduler.started) {
			if (event->blockedThreads.count) {
				unblockedThreads = true;
			}

			// If this is a manually reset event, unblock all the waiting threads.
			scheduler.NotifyObject(&event->blockedThreads, !event->autoReset);
		}
	}

	KSpinlockRelease(&scheduler.dispatchSpinlock);
	return unblockedThreads;
}

void KEventReset(KEvent *event) {
	if (event->blockedThreads.firstItem && event->state) {
		// TODO Is it possible for this to happen?
		KernelLog(LOG_ERROR, "Synchronisation", "reset event with threads blocking", 
				"KEvent::Reset - Attempt to reset a event while threads are blocking on the event\n");
	}

	event->state = false;
}

bool KEventPoll(KEvent *event) {
	if (event->autoReset) {
		return __sync_val_compare_and_swap(&event->state, true, false);
	} else {
		return event->state;
	}
}

uintptr_t KEventWaitMultiple(KEvent **events, size_t count) {
	if (count > ES_MAX_WAIT_COUNT) {
		KernelPanic("KEventWaitMultiple - count (%d) > ES_MAX_WAIT_COUNT (%d)\n", count, ES_MAX_WAIT_COUNT);
	} else if (!count) {
		KernelPanic("KEventWaitMultiple - Count is 0.\n");
	} else if (!ProcessorAreInterruptsEnabled()) {
		KernelPanic("KEventWaitMultiple - Interrupts disabled.\n");
	}

	Thread *thread = GetCurrentThread();
	thread->blocking.eventCount = count;

	LinkedItem<Thread> eventItems[count]; // Max size 16 * 32 = 512.
	EsMemoryZero(eventItems, count * sizeof(LinkedItem<Thread>));
	thread->blocking.eventItems = eventItems;
	EsDefer(thread->blocking.eventItems = nullptr);

	for (uintptr_t i = 0; i < count; i++) {
		eventItems[i].thisItem = thread;
		thread->blocking.events[i] = events[i];
	}

	while (!thread->terminating || thread->terminatableState != THREAD_USER_BLOCK_REQUEST) {
		thread->state = THREAD_WAITING_EVENT;

		for (uintptr_t i = 0; i < count; i++) {
			if (events[i]->autoReset) {
				if (events[i]->state) {
					thread->state = THREAD_ACTIVE;

					if (__sync_val_compare_and_swap(&events[i]->state, true, false)) {
						return i;
					}

					thread->state = THREAD_WAITING_EVENT;
				}
			} else {
				if (events[i]->state) {
					thread->state = THREAD_ACTIVE;
					return i;
				}
			}
		}

		ProcessorFakeTimerInterrupt();
	}

	return -1; // Exited from termination.
}


bool KEventWait(KEvent *_this, uint64_t timeoutMs) {
	KEvent *events[2];
	events[0] = _this;

	if (timeoutMs == (uint64_t) ES_WAIT_NO_TIMEOUT) {
		int index = KEventWaitMultiple(events, 1);
		return index == 0;
	} else {
		KTimer timer = {};
		KTimerSet(&timer, timeoutMs);
		events[1] = &timer.event;
		int index = KEventWaitMultiple(events, 2);
		KTimerRemove(&timer);
		return index == 0;
	}
}



void KSpinlockAcquire(KSpinlock *spinlock) {
	if (scheduler.panic) return;

	bool _interruptsEnabled = ProcessorAreInterruptsEnabled();
	ProcessorDisableInterrupts();

	CPULocalStorage *storage = GetLocalStorage();

#ifdef DEBUG_BUILD
	if (storage && storage->currentThread && spinlock->owner && spinlock->owner == storage->currentThread) {
		KernelPanic("KSpinlock::Acquire - Attempt to acquire a spinlock owned by the current thread (%x/%x, CPU: %d/%d).\nAcquired at %x.\n", 
				storage->currentThread, spinlock->owner, storage->processorID, spinlock->ownerCPU, spinlock->acquireAddress);
	}
#endif

	if (storage) {
		storage->spinlockCount++;
	}

	while (__sync_val_compare_and_swap(&spinlock->state, 0, 1));
	__sync_synchronize();

	spinlock->interruptsEnabled = _interruptsEnabled;

	if (storage) {
#ifdef DEBUG_BUILD
		spinlock->owner = storage->currentThread;
#endif
		spinlock->ownerCPU = storage->processorID;
	} else {
		// Because spinlocks can be accessed very early on in initialisation there may not be
		// a CPULocalStorage available for the current processor. Therefore, just set this field to nullptr.

#ifdef DEBUG_BUILD
		spinlock->owner = nullptr;
#endif
	}

#ifdef DEBUG_BUILD
	spinlock->acquireAddress = (uintptr_t) __builtin_return_address(0);
#endif
}

void KSpinlockRelease(KSpinlock *spinlock, bool force) {
	if (scheduler.panic) return;

	CPULocalStorage *storage = GetLocalStorage();

	if (storage) {
		storage->spinlockCount--;
	}

	if (!force) {
		KSpinlockAssertLocked(spinlock);
	}
	
	volatile bool wereInterruptsEnabled = spinlock->interruptsEnabled;

#ifdef DEBUG_BUILD
	spinlock->owner = nullptr;
#endif
	__sync_synchronize();
	spinlock->state = 0;

	if (wereInterruptsEnabled) ProcessorEnableInterrupts();

#ifdef DEBUG_BUILD
	spinlock->releaseAddress = (uintptr_t) __builtin_return_address(0);
#endif
}

void KSpinlockAssertLocked(KSpinlock *spinlock) {
	if (scheduler.panic) return;

#ifdef DEBUG_BUILD
	CPULocalStorage *storage = GetLocalStorage();

	if (!spinlock->state || ProcessorAreInterruptsEnabled() 
			|| (storage && spinlock->owner != storage->currentThread)) {
#else
	if (!spinlock->state || ProcessorAreInterruptsEnabled()) {
#endif
		KernelPanic("KSpinlock::AssertLocked - KSpinlock not correctly acquired\n"
				"Return address = %x.\n"
				"state = %d, ProcessorAreInterruptsEnabled() = %d, this = %x\n",
				__builtin_return_address(0), spinlock->state, 
				ProcessorAreInterruptsEnabled(), spinlock);
	}
}

#ifdef DEBUG_BUILD
bool _KMutexAcquire(KMutex *mutex, const char *cMutexString, const char *cFile, int line) {
#else
bool KMutexAcquire(KMutex *mutex) {
#endif
	if (scheduler.panic) return false;

	Thread *currentThread = GetCurrentThread();
	bool hasThread = currentThread;

	if (!currentThread) {
		currentThread = (Thread *) 1;
	} else {
		if (currentThread->terminatableState == THREAD_TERMINATABLE) {
			KernelPanic("KMutex::Acquire - Thread is terminatable.\n");
		}
	}

	if (hasThread && mutex->owner && mutex->owner == currentThread) {
#ifdef DEBUG_BUILD
		KernelPanic("KMutex::Acquire - Attempt to acquire mutex (%x) at %x owned by current thread (%x) acquired at %x.\n", 
				mutex, __builtin_return_address(0), currentThread, mutex->acquireAddress);
#else
		KernelPanic("KMutex::Acquire - Attempt to acquire mutex (%x) at %x owned by current thread (%x).\n", 
				mutex, __builtin_return_address(0), currentThread);
#endif
	}

	if (!ProcessorAreInterruptsEnabled()) {
		KernelPanic("KMutex::Acquire - Trying to acquire a mutex while interrupts are disabled.\n");
	}

	while (true) {
		KSpinlockAcquire(&scheduler.dispatchSpinlock);
		Thread *old = mutex->owner;
		if (!old) mutex->owner = currentThread;
		KSpinlockRelease(&scheduler.dispatchSpinlock);
		if (!old) break;

		__sync_synchronize();

		if (GetLocalStorage() && GetLocalStorage()->schedulerReady) {
			if (currentThread->state != THREAD_ACTIVE) {
				KernelPanic("KWaitMutex - Attempting to wait on a mutex in a non-active thread.\n");
			}

			currentThread->blocking.mutex = mutex;
			__sync_synchronize();

			// Instead of spinning on the lock, 
			// let's tell the scheduler to not schedule this thread
			// until it's released.
			currentThread->state = THREAD_WAITING_MUTEX;

			KSpinlockAcquire(&scheduler.dispatchSpinlock);
			// Is the owner of this mutex executing?
			// If not, there's no point in spinning on it.
			bool spin = mutex && mutex->owner && mutex->owner->executing;
			KSpinlockRelease(&scheduler.dispatchSpinlock);

			if (!spin && currentThread->blocking.mutex->owner) {
				ProcessorFakeTimerInterrupt();
			}

			// Early exit if this is a user request to block the thread and the thread is terminating.
			while ((!currentThread->terminating || currentThread->terminatableState != THREAD_USER_BLOCK_REQUEST) && mutex->owner) {
				currentThread->state = THREAD_WAITING_MUTEX;
			}

			currentThread->state = THREAD_ACTIVE;

			if (currentThread->terminating && currentThread->terminatableState == THREAD_USER_BLOCK_REQUEST) {
				// We didn't acquire the mutex because the thread is terminating.
				return false;
			}
		}
	}

	__sync_synchronize();

	if (mutex->owner != currentThread) {
		KernelPanic("KMutex::Acquire - Invalid owner thread (%x, expected %x).\n", mutex->owner, currentThread);
	}

#ifdef DEBUG_BUILD
	mutex->acquireAddress = (uintptr_t) __builtin_return_address(0);
	KMutexAssertLocked(mutex);

	if (!mutex->id) {
		static uintptr_t nextMutexID;
		mutex->id = __sync_fetch_and_add(&nextMutexID, 1);
	}

	if (currentThread && scheduler.threadEventLog) {
		uintptr_t position = __sync_fetch_and_add(&scheduler.threadEventLogPosition, 1);

		if (position < scheduler.threadEventLogAllocated) {
			EsThreadEventLogEntry *entry = scheduler.threadEventLog + position;
			entry->event = ES_THREAD_EVENT_MUTEX_ACQUIRE;
			entry->objectID = mutex->id;
			entry->threadID = currentThread->id;
			entry->line = line;
			entry->fileBytes = EsCStringLength(cFile);
			if (entry->fileBytes > sizeof(entry->file)) entry->fileBytes = sizeof(entry->file);
			entry->expressionBytes = EsCStringLength(cMutexString);
			if (entry->expressionBytes > sizeof(entry->expression)) entry->expressionBytes = sizeof(entry->expression);
			EsMemoryCopy(entry->file, cFile, entry->fileBytes);
			EsMemoryCopy(entry->expression, cMutexString, entry->expressionBytes);
		}
	}
#endif

	return true;
}

#ifdef DEBUG_BUILD
void _KMutexRelease(KMutex *mutex, const char *cMutexString, const char *cFile, int line) {
#else
void KMutexRelease(KMutex *mutex) {
#endif
	if (scheduler.panic) return;

	KMutexAssertLocked(mutex);
	Thread *currentThread = GetCurrentThread();
	KSpinlockAcquire(&scheduler.dispatchSpinlock);

#ifdef DEBUG_BUILD
	// EsPrint("$%x:%x:0\n", owner, id);
#endif

	if (currentThread) {
		Thread *temp = __sync_val_compare_and_swap(&mutex->owner, currentThread, nullptr);
		if (currentThread != temp) KernelPanic("KMutex::Release - Invalid owner thread (%x, expected %x).\n", temp, currentThread);
	} else mutex->owner = nullptr;

	volatile bool preempt = mutex->blockedThreads.count;

	if (scheduler.started) {
		// NOTE We unblock all waiting threads, because of how blockedThreadPriorities works.
		scheduler.NotifyObject(&mutex->blockedThreads, true, currentThread); 
	}

	KSpinlockRelease(&scheduler.dispatchSpinlock);
	__sync_synchronize();

#ifdef DEBUG_BUILD
	mutex->releaseAddress = (uintptr_t) __builtin_return_address(0);

	if (currentThread && scheduler.threadEventLog) {
		uintptr_t position = __sync_fetch_and_add(&scheduler.threadEventLogPosition, 1);

		if (position < scheduler.threadEventLogAllocated) {
			EsThreadEventLogEntry *entry = scheduler.threadEventLog + position;
			entry->event = ES_THREAD_EVENT_MUTEX_RELEASE;
			entry->objectID = mutex->id;
			entry->threadID = currentThread->id;
			entry->line = line;
			entry->fileBytes = EsCStringLength(cFile);
			if (entry->fileBytes > sizeof(entry->file)) entry->fileBytes = sizeof(entry->file);
			entry->expressionBytes = EsCStringLength(cMutexString);
			if (entry->expressionBytes > sizeof(entry->expression)) entry->expressionBytes = sizeof(entry->expression);
			EsMemoryCopy(entry->file, cFile, entry->fileBytes);
			EsMemoryCopy(entry->expression, cMutexString, entry->expressionBytes);
		}
	}
#endif

	if (preempt) ProcessorFakeTimerInterrupt();
}

void KMutexAssertLocked(KMutex *mutex) {
	Thread *currentThread = GetCurrentThread();

	if (!currentThread) {
		currentThread = (Thread *) 1;
	}

	if (mutex->owner != currentThread) {
#ifdef DEBUG_BUILD
		KernelPanic("KMutex::AssertLocked - Mutex not correctly acquired\n"
				"currentThread = %x, owner = %x\nthis = %x\nReturn %x/%x\nLast used from %x->%x\n", 
				currentThread, mutex->owner, mutex, __builtin_return_address(0), __builtin_return_address(1), 
				mutex->acquireAddress, mutex->releaseAddress);
#else
		KernelPanic("KMutex::AssertLocked - Mutex not correctly acquired\n"
				"currentThread = %x, owner = %x\nthis = %x\nReturn %x\n", 
				currentThread, mutex->owner, mutex, __builtin_return_address(0));
#endif
	}
}




struct MMArchVAS {
	// NOTE Must be first in the structure. See ProcessorSetAddressSpace and ArchSwitchContext.
	uintptr_t cr3;

	// Each process has a 47-bit address space.
	// That's 2^35 pages.
	// That's 2^26 L1 page tables. 2^23 bytes of bitset.
	// That's 2^17 L2 page tables. 2^14 bytes of bitset.
	// That's 2^ 8 L3 page tables. 2^ 5 bytes of bitset.
	// Tracking of the committed L1 tables is done in l1Commit, a region of coreMMSpace.
	// 	(This array is committed as needed, tracked using l1CommitCommit.)
	// Tracking of the committed L2 tables is done in l2Commit.
	// Tracking of the committed L3 tables is done in l3Commit.
#define L1_COMMIT_SIZE_BYTES (1 << 23)
#define L1_COMMIT_COMMIT_SIZE_BYTES (1 << 8)
#define L2_COMMIT_SIZE_BYTES (1 << 14)
#define L3_COMMIT_SIZE_BYTES (1 << 5)
	uint8_t *l1Commit;
	uint8_t l1CommitCommit[L1_COMMIT_COMMIT_SIZE_BYTES];
	uint8_t l2Commit[L2_COMMIT_SIZE_BYTES];
	uint8_t l3Commit[L3_COMMIT_SIZE_BYTES];
	size_t pageTablesCommitted;
	size_t pageTablesActive;

	// TODO Consider core/kernel mutex consistency? I think it's fine, but...
	KMutex mutex; // Acquire to modify the page tables.
};

struct MMSpace {
	MMArchVAS data;                  // Architecture specific data.

	AVLTree<MMRegion>                // Key =
		freeRegionsBase,         // Base address
		freeRegionsSize,         // Page count
		usedRegions;             // Base address
	LinkedList<MMRegion> usedRegionsNonGuard;

	KMutex reserveMutex;             // Acquire to Access the region trees.

	volatile int32_t referenceCount; // One per CPU using the space, and +1 while the process is alive.
	                                 // We don't bother tracking for kernelMMSpace.

	bool user; 	                 // Regions in the space may be accessed from userspace.
	uint64_t commit;                 // An *approximate* commit in pages. TODO Better memory usage tracking.
	uint64_t reserve;                // The number of reserved pages.

	KAsyncTask removeAsyncTask;      // The asynchronous task for deallocating the memory space once it's no longer in use.
};
MMSpace _coreMMSpace, _kernelMMSpace;

struct GlobalData {
	volatile int32_t clickChainTimeoutMs;
	volatile float uiScale;
	volatile bool swapLeftAndRightButtons;
	volatile bool showCursorShadow;
	volatile bool useSmartQuotes;
	volatile bool enableHoverState;
	volatile float animationTimeMultiplier;
	volatile uint64_t schedulerTimeMs;
	volatile uint64_t schedulerTimeOffset;
	volatile uint16_t keyboardLayout;
};
struct MMRegion {
	uintptr_t baseAddress;
	size_t pageCount;
	uint32_t flags;

	struct {
		union {
			struct {
				uintptr_t offset;
			} physical;

			struct {
				struct MMSharedRegion *region;
				uintptr_t offset;
			} shared;

			struct {
				struct FSFile *node;
				EsFileOffset offset;
				size_t zeroedBytes;
				uint64_t fileHandleFlags;
			} file;

			struct {
				RangeSet commit; // TODO Currently guarded by MMSpace::reserveMutex, maybe give it its own mutex?
				size_t commitPageCount;
				MMRegion *guardBefore, *guardAfter;
			} normal;
		};

		KWriterLock pin; // Take SHARED when using the region in a system call. Take EXCLUSIVE to free the region.
		KMutex mapMutex; // Access the page tables for a specific region, e.g. to atomically check if a mapping exists and if not, create it.
	} data;

	union {
		struct {
			AVLItem<MMRegion> itemBase;

			union {
				AVLItem<MMRegion> itemSize;
				LinkedItem<MMRegion> itemNonGuard;
			};
		};

		struct {
			bool used;
		} core;
	};
};

MMRegion *MMFindAndPinRegion(MMSpace *space, uintptr_t address, uintptr_t size); 
bool MMCommitRange(MMSpace *space, MMRegion *region, uintptr_t pageOffset, size_t pageCount);
void MMUnpinRegion(MMSpace *space, MMRegion *region) {
	KMutexAcquire(&space->reserveMutex);
	KWriterLockReturn(&region->data.pin, K_LOCK_SHARED);
	KMutexRelease(&space->reserveMutex);
}


void KWriterLockAssertLocked(KWriterLock *lock) {
	if (lock->state == 0) {
		KernelPanic("KWriterLock::AssertLocked - Unlocked.\n");
	}
}

void KWriterLockAssertShared(KWriterLock *lock) {
	if (lock->state == 0) {
		KernelPanic("KWriterLock::AssertShared - Unlocked.\n");
	} else if (lock->state < 0) {
		KernelPanic("KWriterLock::AssertShared - In exclusive mode.\n");
	}
}

void KWriterLockAssertExclusive(KWriterLock *lock) {
	if (lock->state == 0) {
		KernelPanic("KWriterLock::AssertExclusive - Unlocked.\n");
	} else if (lock->state > 0) {
		KernelPanic("KWriterLock::AssertExclusive - In shared mode, with %d readers.\n", lock->state);
	}
}

void KWriterLockReturn(KWriterLock *lock, bool write) {
	KSpinlockAcquire(&scheduler.dispatchSpinlock);

	if (lock->state == -1) {
		if (!write) {
			KernelPanic("KWriterLock::Return - Attempting to return shared access to an exclusively owned lock.\n");
		}

		lock->state = 0;
	} else if (lock->state == 0) {
		KernelPanic("KWriterLock::Return - Attempting to return access to an unowned lock.\n");
	} else {
		if (write) {
			KernelPanic("KWriterLock::Return - Attempting to return exclusive access to an shared lock.\n");
		}

		lock->state--;
	}

	if (!lock->state) {
		scheduler.NotifyObject(&lock->blockedThreads, true);
	}

	KSpinlockRelease(&scheduler.dispatchSpinlock);
}

bool KWriterLockTake(KWriterLock *lock, bool write, bool poll) {
	// TODO Preventing exclusive access starvation.
	// TODO Do this without taking the scheduler's lock?

	bool done = false;

	Thread *thread = GetCurrentThread();

	if (thread) {
		thread->blocking.writerLock = lock;
		thread->blocking.writerLockType = write;
		__sync_synchronize();
	}

	while (true) {
		KSpinlockAcquire(&scheduler.dispatchSpinlock);

		if (write) {
			if (lock->state == 0) {
				lock->state = -1;
				done = true;
#ifdef DEBUG_BUILD
				lock->exclusiveOwner = thread;
#endif
			}
		} else {
			if (lock->state >= 0) {
				lock->state++;
				done = true;
			}
		}

		KSpinlockRelease(&scheduler.dispatchSpinlock);

		if (poll || done) {
			break;
		} else {
			if (!thread) {
				KernelPanic("KWriterLock::Take - Scheduler not ready yet.\n");
			}

			thread->state = THREAD_WAITING_WRITER_LOCK;
			ProcessorFakeTimerInterrupt();
			thread->state = THREAD_ACTIVE;
		}
	}

	return done;
}

void KWriterLockTakeMultiple(KWriterLock **locks, size_t lockCount, bool write) {
	uintptr_t i = 0, taken = 0;

	while (taken != lockCount) {
		if (KWriterLockTake(locks[i], write, taken)) {
			taken++, i++;
			if (i == lockCount) i = 0;
		} else {
			intptr_t j = i - 1;

			while (taken) {
				if (j == -1) j = lockCount - 1;
				KWriterLockReturn(locks[j], write);
				j--, taken--;
			}
		}
	}
}

void KWriterLockConvertExclusiveToShared(KWriterLock *lock) {
	KSpinlockAcquire(&scheduler.dispatchSpinlock);
	KWriterLockAssertExclusive(lock);
	lock->state = 1;
	scheduler.NotifyObject(&lock->blockedThreads, true);
	KSpinlockRelease(&scheduler.dispatchSpinlock);
}


#define ES_SHARED_MEMORY_NAME_MAX_LENGTH (32)
struct MMSharedRegion {
	size_t sizeBytes;
	volatile size_t handles;
	KMutex mutex;
	LinkedItem<MMSharedRegion> namedItem;
	char cName[ES_SHARED_MEMORY_NAME_MAX_LENGTH + 1];
	void *data;
};

bool OpenHandleToObject(void *object, KernelObjectType type, uint32_t flags);



Thread *ThreadSpawn(const char *cName, uintptr_t startAddress, uintptr_t argument1 = 0, 
		uint32_t flags = ES_FLAGS_DEFAULT, Process *process = nullptr, uintptr_t argument2 = 0)
{
    bool userland = flags & SPAWN_THREAD_USERLAND;
	Thread *parentThread = GetCurrentThread();

	if (!process) {
		process = kernelProcess;
	}

	if (userland && process == kernelProcess) {
		KernelPanic("ThreadSpawn - Cannot add userland thread to kernel process.\n");
	}

	// Adding the thread to the owner's list of threads and adding the thread to a scheduling list
	// need to be done in the same atomic block.
	KMutexAcquire(&process->threadsMutex);
	EsDefer(KMutexRelease(&process->threadsMutex));

	if (process->preventNewThreads) {
		return nullptr;
	}

	Thread *thread = (Thread *) scheduler.threadPool.Add(sizeof(Thread));
	if (!thread) return nullptr;
	KernelLog(LOG_INFO, "Scheduler", "spawn thread", "Created thread, %x to start at %x\n", thread, startAddress);

	// Allocate the thread's stacks.
#if defined(ES_BITS_64)
	uintptr_t kernelStackSize = 0x5000 /* 20KB */;
#elif defined(ES_BITS_32)
	uintptr_t kernelStackSize = 0x4000 /* 16KB */;
#endif
	uintptr_t userStackReserve = userland ? 0x400000 /* 4MB */ : kernelStackSize;
	uintptr_t userStackCommit = userland ? 0x10000 /* 64KB */ : 0;
	uintptr_t stack = 0, kernelStack = 0;

	if (flags & SPAWN_THREAD_IDLE) goto skipStackAllocation;

	kernelStack = (uintptr_t) MMStandardAllocate(kernelMMSpace, kernelStackSize, MM_REGION_FIXED);
	if (!kernelStack) goto fail;

	if (userland) {
		stack = (uintptr_t) MMStandardAllocate(process->vmm, userStackReserve, ES_FLAGS_DEFAULT, nullptr, false);

		MMRegion *region = MMFindAndPinRegion(process->vmm, stack, userStackReserve);
		KMutexAcquire(&process->vmm->reserveMutex);
#ifdef K_ARCH_STACK_GROWS_DOWN
		bool success = MMCommitRange(process->vmm, region, (userStackReserve - userStackCommit) / K_PAGE_SIZE, userStackCommit / K_PAGE_SIZE); 
#else
		bool success = MMCommitRange(process->vmm, region, 0, userStackCommit / K_PAGE_SIZE); 
#endif
		KMutexRelease(&process->vmm->reserveMutex);
		MMUnpinRegion(process->vmm, region);
		if (!success) goto fail;
	} else {
		stack = kernelStack;
	}

	if (!stack) goto fail;
	skipStackAllocation:;

	// If ProcessPause is called while a thread in that process is spawning a new thread, mark the thread as paused. 
	// This is synchronized under the threadsMutex.
	thread->paused = (parentThread && process == parentThread->process && parentThread->paused) || (flags & SPAWN_THREAD_PAUSED);

	// 2 handles to the thread:
	// 	One for spawning the thread, 
	// 	and the other for remaining during the thread's life.
	thread->handles = 2;

	thread->isKernelThread = !userland;
	thread->priority = (flags & SPAWN_THREAD_LOW_PRIORITY) ? THREAD_PRIORITY_LOW : THREAD_PRIORITY_NORMAL;
	thread->cName = cName;
	thread->kernelStackBase = kernelStack;
	thread->userStackBase = userland ? stack : 0;
	thread->userStackReserve = userStackReserve;
	thread->userStackCommit = userStackCommit;
	thread->terminatableState = userland ? THREAD_TERMINATABLE : THREAD_IN_SYSCALL;
	thread->type = (flags & SPAWN_THREAD_ASYNC_TASK) ? THREAD_ASYNC_TASK : (flags & SPAWN_THREAD_IDLE) ? THREAD_IDLE : THREAD_NORMAL;
	thread->id = __sync_fetch_and_add(&scheduler.nextThreadID, 1);
	thread->process = process;
	thread->item.thisItem = thread;
	thread->allItem.thisItem = thread;
	thread->processItem.thisItem = thread;

	if (thread->type != THREAD_IDLE) {
		thread->interruptContext = ArchInitialiseThread(kernelStack, kernelStackSize, thread, 
				startAddress, argument1, argument2, userland, stack, userStackReserve);
	} else {
		thread->state = THREAD_ACTIVE;
		thread->executing = true;
	}

	process->threads.InsertEnd(&thread->processItem);

	KMutexAcquire(&scheduler.allThreadsMutex);
	scheduler.allThreads.InsertStart(&thread->allItem);
	KMutexRelease(&scheduler.allThreadsMutex);

	// Each thread owns a handles to the owner process.
	// This makes sure the process isn't destroyed before all its threads have been destroyed.
	OpenHandleToObject(process, KERNEL_OBJECT_PROCESS, ES_FLAGS_DEFAULT);

	KernelLog(LOG_INFO, "Scheduler", "thread stacks", "Spawning thread with stacks (k,u): %x->%x, %x->%x\n", 
			kernelStack, kernelStack + kernelStackSize, stack, stack + userStackReserve);
	KernelLog(LOG_INFO, "Scheduler", "create thread", "Create thread ID %d, type %d, owner process %d\n", 
			thread->id, thread->type, process->id);

	if (thread->type == THREAD_NORMAL) {
		// Add the thread to the start of the active thread list to make sure that it runs immediately.
		KSpinlockAcquire(&scheduler.dispatchSpinlock);
		scheduler.AddActiveThread(thread, true);
		KSpinlockRelease(&scheduler.dispatchSpinlock);
	} else {
		// Idle and asynchronous task threads don't need to be added to a scheduling list.
	}

	// The thread may now be terminated at any moment.

	return thread;

	fail:;
	if (stack) MMFree(process->vmm, (void *) stack);
	if (kernelStack) MMFree(kernelMMSpace, (void *) kernelStack);
	scheduler.threadPool.Remove(thread);
	return nullptr;
}

bool KThreadCreate(const char *cName, void (*startAddress)(uintptr_t), uintptr_t argument) {
	return ThreadSpawn(cName, (uintptr_t) startAddress, argument) ? true : false;
}














bool KThreadCreate(const char *cName, void (*startAddress)(uintptr_t), uintptr_t argument = 0);
Process *ProcessSpawn(ProcessType processType);

struct InterruptContext;
struct CPULocalStorage;






#define ES_WAIT_NO_TIMEOUT            (-1)
#define ES_MAX_WAIT_COUNT             (8)






struct CPULocalStorage;


struct MMPageFrame {
	volatile enum : uint8_t {
		// Frames that can't be used.
		UNUSABLE,	// Not connected to RAM.
		BAD,		// Connected to RAM with errors. TODO

		// Frames that aren't referenced.
		ZEROED,		// Cleared with zeros.
		FREE,		// Contains whatever data is had when it was freed.

		// Frames that are referenced by an invalid [shared] page mapping.
		// In shared regions, each invalid page mapping points to the shared page mapping.
		// This means only one variable must be updated to reuse the frame.
		STANDBY,	// Data has been written to page file or backing file. 

		// Frames that are referenced by one or more valid page mappings.
		ACTIVE,
	} state;

	volatile uint8_t flags;

	// The reference to this frame in a CCCachedSection.
	volatile uintptr_t *cacheReference;

	union {
		struct {
			// For STANDBY, MODIFIED, UPDATED, ZEROED and FREE.
			// The frame's position in a list.
			volatile uintptr_t next, *previous;
		} list;

		struct {
			// For ACTIVE.
			// For file pages, this tracks how many valid page table entries point to this frame.
			volatile uintptr_t references;
		} active;
	};
};

struct Bitset {
	void Initialise(size_t count, bool mapAll = false);
	void PutAll();
	uintptr_t Get(size_t count = 1, uintptr_t align = 1, uintptr_t below = 0);
	void Put(uintptr_t index);
	void Take(uintptr_t index);
	bool Read(uintptr_t index);

#define BITSET_GROUP_SIZE (4096)
	uint32_t *singleUsage;
	uint16_t *groupUsage;

	size_t singleCount; 
	size_t groupCount;

#ifdef DEBUG_BUILD
	bool modCheck;
#endif
};

void Bitset::Initialise(size_t count, bool mapAll) {
	singleCount = (count + 31) & ~31;
	groupCount = singleCount / BITSET_GROUP_SIZE + 1;

	singleUsage = (uint32_t *) MMStandardAllocate(kernelMMSpace, (singleCount >> 3) + (groupCount * 2), mapAll ? MM_REGION_FIXED : 0);
	groupUsage = (uint16_t *) singleUsage + (singleCount >> 4);
}

void Bitset::PutAll() {
	for (uintptr_t i = 0; i < singleCount; i += 32) {
		groupUsage[i / BITSET_GROUP_SIZE] += 32;
		singleUsage[i / 32] |= 0xFFFFFFFF;
	}
}

uintptr_t Bitset::Get(size_t count, uintptr_t align, uintptr_t below) {
#ifdef DEBUG_BUILD
	if (modCheck) KernelPanic("Bitset::Allocate - Concurrent modification.\n");
	modCheck = true; EsDefer({modCheck = false;});
#endif

	uintptr_t returnValue = (uintptr_t) -1;

	if (below) {
		if (below < count) goto done;
		below -= count;
	}

	if (count == 1 && align == 1) {
		for (uintptr_t i = 0; i < groupCount; i++) {
			if (groupUsage[i]) {
				for (uintptr_t j = 0; j < BITSET_GROUP_SIZE; j++) {
					uintptr_t index = i * BITSET_GROUP_SIZE + j;
					if (below && index >= below) goto done;

					if (singleUsage[index >> 5] & (1 << (index & 31))) {
						singleUsage[index >> 5] &= ~(1 << (index & 31));
						groupUsage[i]--;
						returnValue = index;
						goto done;
					}
				}
			}
		}
	} else if (count == 16 && align == 16) {
		for (uintptr_t i = 0; i < groupCount; i++) {
			if (groupUsage[i] >= 16) {
				for (uintptr_t j = 0; j < BITSET_GROUP_SIZE; j += 16) {
					uintptr_t index = i * BITSET_GROUP_SIZE + j;
					if (below && index >= below) goto done;

					if (((uint16_t *) singleUsage)[index >> 4] == (uint16_t) (-1)) {
						((uint16_t *) singleUsage)[index >> 4] = 0;
						groupUsage[i] -= 16;
						returnValue = index;
						goto done;
					}
				}
			}
		}
	} else if (count == 32 && align == 32) {
		for (uintptr_t i = 0; i < groupCount; i++) {
			if (groupUsage[i] >= 32) {
				for (uintptr_t j = 0; j < BITSET_GROUP_SIZE; j += 32) {
					uintptr_t index = i * BITSET_GROUP_SIZE + j;
					if (below && index >= below) goto done;

					if (singleUsage[index >> 5] == (uint32_t) (-1)) {
						singleUsage[index >> 5] = 0;
						groupUsage[i] -= 32;
						returnValue = index;
						goto done;
					}
				}
			}
		}
	} else {
		// TODO Optimise this?

		size_t found = 0;
		uintptr_t start = 0;

		for (uintptr_t i = 0; i < groupCount; i++) {
			if (!groupUsage[i]) {
				found = 0;
				continue;
			}

			for (uintptr_t j = 0; j < BITSET_GROUP_SIZE; j++) {
				uintptr_t index = i * BITSET_GROUP_SIZE + j;

				if (singleUsage[index >> 5] & (1 << (index & 31))) {
					if (!found) {
						if (index >= below && below) goto done;
						if (index  % align)          continue;

						start = index;
					}

					found++;
				} else {
					found = 0;
				}

				if (found == count) {
					returnValue = start;

					for (uintptr_t i = 0; i < count; i++) {
						uintptr_t index = start + i;
						singleUsage[index >> 5] &= ~(1 << (index & 31));
					}

					goto done;
				}
			}
		}
	}

	done:;
	return returnValue;
}

bool Bitset::Read(uintptr_t index) {
	// We don't want to set modCheck, 
	// since we allow other bits to be modified while this bit is being read,
	// and we allow multiple readers of this bit.
	return singleUsage[index >> 5] & (1 << (index & 31));
}

void Bitset::Take(uintptr_t index) {
#ifdef DEBUG_BUILD
	if (modCheck) KernelPanic("Bitset::Take - Concurrent modification.\n");
	modCheck = true; EsDefer({modCheck = false;});
#endif

	uintptr_t group = index / BITSET_GROUP_SIZE;

#ifdef DEBUG_BUILD
	if (!(singleUsage[index >> 5] & (1 << (index & 31)))) {
		KernelPanic("Bitset::Take - Attempting to take a entry that hasalready been taken.\n");
	}
#endif

	groupUsage[group]--;
	singleUsage[index >> 5] &= ~(1 << (index & 31));
}

void Bitset::Put(uintptr_t index) {
#ifdef DEBUG_BUILD
	if (modCheck) KernelPanic("Bitset::Put - Concurrent modification.\n");
	modCheck = true; EsDefer({modCheck = false;});

	if (index > singleCount) {
		KernelPanic("Bitset::Put - Index greater than single code.\n");
	}

	if (singleUsage[index >> 5] & (1 << (index & 31))) {
		KernelPanic("Bitset::Put - Duplicate entry.\n");
	}
#endif

	{
		singleUsage[index >> 5] |= 1 << (index & 31);
		groupUsage[index / BITSET_GROUP_SIZE]++;
	}
}
 
struct MMObjectCache {
	KSpinlock lock; // Used instead of a mutex to keep accesses to the list lightweight.
	SimpleList items;
	size_t count;
	bool (*trim)(MMObjectCache *cache); // Return true if an object was trimmed.
	KWriterLock trimLock; // Open in shared access to trim the cache.
	LinkedItem<MMObjectCache> item;
	size_t averageObjectBytes;
};

uintptr_t /* Returns physical address of first page, or 0 if none were available. */ MMPhysicalAllocate(unsigned flags, 
		uintptr_t count = 1 /* Number of contiguous pages to allocate. */, 
		uintptr_t align = 1 /* Alignment, in pages. */, 
		uintptr_t below = 0 /* Upper limit of physical address, in pages. E.g. for 32-bit pages only, pass (0x100000000 >> K_PAGE_BITS). */);
void MMPhysicalFree(uintptr_t page /* Physical address. */, 
		bool mutexAlreadyAcquired = false /* Internal use. Pass false. */, 
		size_t count = 1 /* Number of consecutive pages to free. */);

bool MMPhysicalAllocateAndMap(size_t sizeBytes, size_t alignmentBytes, size_t maximumBits, bool zeroed, 
		uint64_t caching, uint8_t **virtualAddress, uintptr_t *physicalAddress);
void MMPhysicalFreeAndUnmap(void *virtualAddress, uintptr_t physicalAddress);






struct PMM {
	MMPageFrame *pageFrames;
	bool pageFrameDatabaseInitialised;
	uintptr_t pageFrameDatabaseCount;

	uintptr_t firstFreePage;
	uintptr_t firstZeroedPage;
	uintptr_t firstStandbyPage, lastStandbyPage;
	Bitset freeOrZeroedPageBitset; // Used for allocating large pages.

	uintptr_t countZeroedPages, countFreePages, countStandbyPages, countActivePages;

#define MM_REMAINING_COMMIT() (pmm.commitLimit - pmm.commitPageable - pmm.commitFixed)
	int64_t commitFixed, commitPageable, 
		  commitFixedLimit, commitLimit;

	                      // Acquire to:
	KMutex commitMutex,   // (Un)commit pages.
	      pageFrameMutex; // Allocate or free pages.

	KMutex pmManipulationLock;
	KSpinlock pmManipulationProcessorLock;
	void *pmManipulationRegion;

	Thread *zeroPageThread;
	KEvent zeroPageEvent;

	LinkedList<MMObjectCache> objectCacheList;
	KMutex objectCacheListMutex;

	// Events for when the number of available pages is low.
#define MM_AVAILABLE_PAGES() (pmm.countZeroedPages + pmm.countFreePages + pmm.countStandbyPages)
	KEvent availableCritical, availableLow;
	KEvent availableNotCritical;

	// Event for when the object cache should be trimmed.
#define MM_OBJECT_CACHE_SHOULD_TRIM() (pmm.approximateTotalObjectCacheBytes / K_PAGE_SIZE > MM_OBJECT_CACHE_PAGES_MAXIMUM())
	uintptr_t approximateTotalObjectCacheBytes;
	KEvent trimObjectCaches;

	// These variables will be cleared if the object they point to is removed.
	// See MMUnreserve and Scheduler::RemoveProcess.
	struct Process *nextProcessToBalance;
	MMRegion *nextRegionToBalance;
	uintptr_t balanceResumePosition;
};

// So, try to keep the commit quota used by the object caches at most half the available space.
#define MM_NON_CACHE_MEMORY_PAGES()               (pmm.commitFixed + pmm.commitPageable - pmm.approximateTotalObjectCacheBytes / K_PAGE_SIZE)
#define MM_OBJECT_CACHE_PAGES_MAXIMUM()           ((pmm.commitLimit - MM_NON_CACHE_MEMORY_PAGES()) / 2)

PMM pmm;

MMRegion *mmCoreRegions = (MMRegion *) MM_CORE_REGIONS_START;
size_t mmCoreRegionCount, mmCoreRegionArrayCommit;

LinkedList<MMSharedRegion> mmNamedSharedRegions;
KMutex mmNamedSharedRegionsMutex;

GlobalData *globalData; // Shared with all processes.

typedef bool (*KIRQHandler)(uintptr_t interruptIndex /* tag for MSI */, void *context);
struct KPCIDevice : KDevice {
	void WriteBAR8(uintptr_t index, uintptr_t offset, uint8_t value);
	uint8_t ReadBAR8(uintptr_t index, uintptr_t offset);
	void WriteBAR16(uintptr_t index, uintptr_t offset, uint16_t value);
	uint16_t ReadBAR16(uintptr_t index, uintptr_t offset);
	void WriteBAR32(uintptr_t index, uintptr_t offset, uint32_t value);
	uint32_t ReadBAR32(uintptr_t index, uintptr_t offset);
	void WriteBAR64(uintptr_t index, uintptr_t offset, uint64_t value);
	uint64_t ReadBAR64(uintptr_t index, uintptr_t offset);

	void WriteConfig8(uintptr_t offset, uint8_t value);
	uint8_t ReadConfig8(uintptr_t offset);
	void WriteConfig16(uintptr_t offset, uint16_t value);
	uint16_t ReadConfig16(uintptr_t offset);
	void WriteConfig32(uintptr_t offset, uint32_t value);
	uint32_t ReadConfig32(uintptr_t offset);

#define K_PCI_FEATURE_BAR_0                     (1 <<  0)
#define K_PCI_FEATURE_BAR_1                     (1 <<  1)
#define K_PCI_FEATURE_BAR_2                     (1 <<  2)
#define K_PCI_FEATURE_BAR_3                     (1 <<  3)
#define K_PCI_FEATURE_BAR_4                     (1 <<  4)
#define K_PCI_FEATURE_BAR_5                     (1 <<  5)
#define K_PCI_FEATURE_INTERRUPTS 		(1 <<  8)
#define K_PCI_FEATURE_BUSMASTERING_DMA 		(1 <<  9)
#define K_PCI_FEATURE_MEMORY_SPACE_ACCESS 	(1 << 10)
#define K_PCI_FEATURE_IO_PORT_ACCESS		(1 << 11)
	bool EnableFeatures(uint64_t features);
	bool EnableSingleInterrupt(KIRQHandler irqHandler, void *context, const char *cOwnerName); 

	uint32_t deviceID, subsystemID, domain;
	uint8_t  classCode, subclassCode, progIF;
	uint8_t  bus, slot, function;
	uint8_t  interruptPin, interruptLine;

	uint8_t  *baseAddressesVirtual[6];
	uintptr_t baseAddressesPhysical[6];
	size_t    baseAddressesSizes[6];

	uint32_t baseAddresses[6];

	bool EnableMSI(KIRQHandler irqHandler, void *context, const char *cOwnerName); 
};

MMRegion *MMFindRegion(MMSpace *space, uintptr_t address) {
	KMutexAssertLocked(&space->reserveMutex);

	if (space == coreMMSpace) {
		for (uintptr_t i = 0; i < mmCoreRegionCount; i++) {
			MMRegion *region = mmCoreRegions + i;

			if (region->core.used && region->baseAddress <= address
					&& region->baseAddress + region->pageCount * K_PAGE_SIZE > address) {
				return region;
			}
		}
	} else {
		AVLItem<MMRegion> *item = TreeFind(&space->usedRegions, MakeShortKey(address), TREE_SEARCH_LARGEST_BELOW_OR_EQUAL);
		if (!item) return nullptr;

		MMRegion *region = item->thisItem;
		if (region->baseAddress > address) KernelPanic("MMFindRegion - Broken usedRegions tree.\n");
		if (region->baseAddress + region->pageCount * K_PAGE_SIZE <= address) return nullptr;
		return region;
	}

	return nullptr;
}

void MMDecommit(uint64_t bytes, bool fixed) {
	// EsPrint("De-Commit %d %d\n", bytes, fixed);

	if (bytes & (K_PAGE_SIZE - 1)) KernelPanic("MMDecommit - Expected multiple of K_PAGE_SIZE bytes.\n");
	int64_t pagesNeeded = bytes / K_PAGE_SIZE;

	KMutexAcquire(&pmm.commitMutex);
	EsDefer(KMutexRelease(&pmm.commitMutex));

	if (fixed) {
		if (pmm.commitFixed < pagesNeeded) KernelPanic("MMDecommit - Decommitted too many pages.\n");
		pmm.commitFixed -= pagesNeeded;
	} else {
		if (pmm.commitPageable < pagesNeeded) KernelPanic("MMDecommit - Decommitted too many pages.\n");
		pmm.commitPageable -= pagesNeeded;
	}

	KernelLog(LOG_VERBOSE, "Memory", "decommit", "Decommit %D%z. Now at %D.\n", bytes, fixed ? ", fixed" : "", (pmm.commitFixed + pmm.commitPageable) << K_PAGE_BITS);
}

bool MMDecommitRange(MMSpace *space, MMRegion *region, uintptr_t pageOffset, size_t pageCount) {
	KMutexAssertLocked(&space->reserveMutex);

	if (region->flags & MM_REGION_NO_COMMIT_TRACKING) {
		KernelPanic("MMDecommitRange - Region does not support commit tracking.\n");
	}

	if (pageOffset >= region->pageCount || pageCount > region->pageCount - pageOffset) {
		KernelPanic("MMDecommitRange - Invalid region offset and page count.\n");
	}

	if (~region->flags & MM_REGION_NORMAL) {
		KernelPanic("MMDecommitRange - Cannot decommit from non-normal region.\n");
	}

	intptr_t delta = 0;

	if (!region->data.normal.commit.Clear(pageOffset, pageOffset + pageCount, &delta, true)) {
		return false;
	}

	if (delta > 0) {
		KernelPanic("MMDecommitRange - Invalid delta calculation removing %x, %x from %x.\n", pageOffset, pageCount, region);
	}

	delta = -delta;

	if (region->data.normal.commitPageCount < (size_t) delta) {
		KernelPanic("MMDecommitRange - Invalid delta calculation decreases region %x commit below zero.\n", region);
	}

	// EsPrint("\tdecommit = %x\n", pagesRemoved);

	MMDecommit(delta * K_PAGE_SIZE, region->flags & MM_REGION_FIXED);
	space->commit -= delta;
	region->data.normal.commitPageCount -= delta;
	MMArchUnmapPages(space, region->baseAddress + pageOffset * K_PAGE_SIZE, pageCount, MM_UNMAP_PAGES_FREE);

	return true;
}


uintptr_t MMArchTranslateAddress(MMSpace *, uintptr_t virtualAddress, bool writeAccess =false);

#define CC_ACTIVE_SECTION_SIZE                    ((EsFileOffset) 262144)

struct CCActiveSectionReference {
	EsFileOffset offset; // Offset into the file; multiple of CC_ACTIVE_SECTION_SIZE.
	uintptr_t index; // Index of the active section.
};

struct CCActiveSection {
	KEvent loadCompleteEvent, writeCompleteEvent; 
	LinkedItem<CCActiveSection> listItem; // Either in the LRU list, or the modified list. If accessors > 0, it should not be in a list.

	EsFileOffset offset;
	struct CCSpace *cache;

	size_t accessors;
	volatile bool loading, writing, modified, flush;

	uint16_t referencedPageCount; 
	uint8_t referencedPages[CC_ACTIVE_SECTION_SIZE / K_PAGE_SIZE / 8]; // If accessors > 0, then pages cannot be dereferenced.

	uint8_t modifiedPages[CC_ACTIVE_SECTION_SIZE / K_PAGE_SIZE / 8];
};

struct MMActiveSectionManager {
	CCActiveSection *sections;
	size_t sectionCount;
	uint8_t *baseAddress;
	KMutex mutex;
	LinkedList<CCActiveSection> lruList;
	LinkedList<CCActiveSection> modifiedList;
	KEvent modifiedNonEmpty, modifiedNonFull, modifiedGettingFull;
	Thread *writeBackThread;
};

MMActiveSectionManager activeSectionManager;

#define CC_MAX_MODIFIED                           (67108864 / CC_ACTIVE_SECTION_SIZE)
#define CC_MODIFIED_GETTING_FULL                  (CC_MAX_MODIFIED * 2 / 3)

void CCDereferenceActiveSection(CCActiveSection *section, uintptr_t startingPage = 0) {
	KMutexAssertLocked(&activeSectionManager.mutex);

	if (!startingPage) {
		MMArchUnmapPages(kernelMMSpace, 
				(uintptr_t) activeSectionManager.baseAddress + (section - activeSectionManager.sections) * CC_ACTIVE_SECTION_SIZE, 
				CC_ACTIVE_SECTION_SIZE / K_PAGE_SIZE, MM_UNMAP_PAGES_BALANCE_FILE);
		EsMemoryZero(section->referencedPages, sizeof(section->referencedPages));
		EsMemoryZero(section->modifiedPages, sizeof(section->modifiedPages));
		section->referencedPageCount = 0;
	} else {
		MMArchUnmapPages(kernelMMSpace, 
				(uintptr_t) activeSectionManager.baseAddress 
					+ (section - activeSectionManager.sections) * CC_ACTIVE_SECTION_SIZE 
					+ startingPage * K_PAGE_SIZE, 
				(CC_ACTIVE_SECTION_SIZE / K_PAGE_SIZE - startingPage), MM_UNMAP_PAGES_BALANCE_FILE);

		for (uintptr_t i = startingPage; i < CC_ACTIVE_SECTION_SIZE / K_PAGE_SIZE; i++) {
			if (section->referencedPages[i >> 3] & (1 << (i & 7))) {
				section->referencedPages[i >> 3] &= ~(1 << (i & 7));
				section->modifiedPages[i >> 3] &= ~(1 << (i & 7));
				section->referencedPageCount--;
			}
		}
	}
}

CCCachedSection *CCFindCachedSectionContaining(CCSpace *cache, EsFileOffset sectionOffset) {
	KMutexAssertLocked(&cache->cachedSectionsMutex);

	if (!cache->cachedSections.Length()) {
		return nullptr;
	}

	CCCachedSection *cachedSection = nullptr;

	bool found = false;
	intptr_t low = 0, high = cache->cachedSections.Length() - 1;

	while (low <= high) {
		intptr_t i = low + (high - low) / 2;
		cachedSection = &cache->cachedSections[i];

		if (cachedSection->offset + cachedSection->pageCount * K_PAGE_SIZE <= sectionOffset) {
			low = i + 1;
		} else if (cachedSection->offset > sectionOffset) {
			high = i - 1;
		} else {
			found = true;
			break;
		}
	}

	return found ? cachedSection : nullptr;
}

void CCSpaceUncover(CCSpace *cache, EsFileOffset removeStart, EsFileOffset removeEnd) {
	KMutexAssertLocked(&cache->cachedSectionsMutex);

	removeStart = RoundDown(removeStart, (EsFileOffset) K_PAGE_SIZE);
	removeEnd = RoundUp(removeEnd, (EsFileOffset) K_PAGE_SIZE);

	CCCachedSection *first = CCFindCachedSectionContaining(cache, removeStart);

	if (!first) {
		KernelPanic("CCSpaceUncover - Range %x->%x was not covered in cache %x.\n", removeStart, removeEnd, cache);
	}

	for (uintptr_t i = first - cache->cachedSections.array; i < cache->cachedSections.Length(); i++) {
		CCCachedSection *section = &cache->cachedSections[i];

		EsFileOffset sectionStart = section->offset, 
			     sectionEnd = section->offset + section->pageCount * K_PAGE_SIZE;

		if (removeEnd > sectionStart && removeStart < sectionEnd) {
			if (!section->mappedRegionsCount) KernelPanic("CCSpaceUncover - Section wasn't mapped.\n");
			section->mappedRegionsCount--;
			// EsPrint("- %x %x %d\n", cache, section->data, section->mappedRegionsCount);
		} else {
			break;
		}
	}
}

bool CCSpaceCover(CCSpace *cache, EsFileOffset insertStart, EsFileOffset insertEnd) {
	KMutexAssertLocked(&cache->cachedSectionsMutex);

	// TODO Test this thoroughly.
	// TODO Break up really large sections. (maybe into GBs?)

	insertStart = RoundDown(insertStart, (EsFileOffset) K_PAGE_SIZE);
	insertEnd = RoundUp(insertEnd, (EsFileOffset) K_PAGE_SIZE);
	EsFileOffset position = insertStart, lastEnd = 0;
	CCCachedSection *result = nullptr;

	// EsPrint("New: %d, %d\n", insertStart / K_PAGE_SIZE, insertEnd / K_PAGE_SIZE);

	for (uintptr_t i = 0; i < cache->cachedSections.Length(); i++) {
		CCCachedSection *section = &cache->cachedSections[i];

		EsFileOffset sectionStart = section->offset, 
			     sectionEnd = section->offset + section->pageCount * K_PAGE_SIZE;

		// EsPrint("Existing (%d): %d, %d\n", i, sectionStart / K_PAGE_SIZE, sectionEnd / K_PAGE_SIZE);

		if (insertStart > sectionEnd) continue;

		// If the inserted region starts before this section starts, then we need to make a new section before us.

		if (position < sectionStart) {
			CCCachedSection newSection = {};
			newSection.mappedRegionsCount = 0;
			newSection.offset = position;
			newSection.pageCount = ((insertEnd > sectionStart ? sectionStart : insertEnd) - position) / K_PAGE_SIZE;

			if (newSection.pageCount) {
				// EsPrint("\tAdded: %d, %d\n", newSection.offset / K_PAGE_SIZE, newSection.pageCount);
				newSection.data = (uintptr_t *) EsHeapAllocate(sizeof(uintptr_t) * newSection.pageCount, true, K_CORE);

				if (!newSection.data) {
					goto fail;
				}

				if (!cache->cachedSections.Insert(newSection, i)) { 
					EsHeapFree(newSection.data, sizeof(uintptr_t) * newSection.pageCount, K_CORE); 
					goto fail; 
				}

				i++;
			}

		}

		position = sectionEnd;
		if (position > insertEnd) break;
	}

	// Insert the final section if necessary.

	if (position < insertEnd) {
		CCCachedSection newSection = {};
		newSection.mappedRegionsCount = 0;
		newSection.offset = position;
		newSection.pageCount = (insertEnd - position) / K_PAGE_SIZE;
		newSection.data = (uintptr_t *) EsHeapAllocate(sizeof(uintptr_t) * newSection.pageCount, true, K_CORE);
		// EsPrint("\tAdded (at end): %d, %d\n", newSection.offset / K_PAGE_SIZE, newSection.pageCount);

		if (!newSection.data) {
			goto fail;
		}

		if (!cache->cachedSections.Add(newSection)) { 
			EsHeapFree(newSection.data, sizeof(uintptr_t) * newSection.pageCount, K_CORE); 
			goto fail; 
		}
	}

	for (uintptr_t i = 0; i < cache->cachedSections.Length(); i++) {
		CCCachedSection *section = &cache->cachedSections[i];

		EsFileOffset sectionStart = section->offset, 
			     sectionEnd = section->offset + section->pageCount * K_PAGE_SIZE;

		if (sectionStart < lastEnd) KernelPanic("CCSpaceCover - Overlapping MMCachedSections.\n");

		// If the inserted region ends after this section starts, 
		// and starts before this section ends, then it intersects it.

		if (insertEnd > sectionStart && insertStart < sectionEnd) {
			section->mappedRegionsCount++;
			// EsPrint("+ %x %x %d\n", cache, section->data, section->mappedRegionsCount);
			if (result && sectionStart != lastEnd) KernelPanic("CCSpaceCover - Incomplete MMCachedSections.\n");
			if (!result) result = section;
		}

		lastEnd = sectionEnd;
	}

	return true;

	fail:;
	return false; // TODO Remove unused cached sections?
}

void CCWriteSection(CCActiveSection *section) {
	// Write any modified pages to the backing store.

	uint8_t *sectionBase = activeSectionManager.baseAddress + (section - activeSectionManager.sections) * CC_ACTIVE_SECTION_SIZE;
	EsError error = ES_SUCCESS;

	for (uintptr_t i = 0; i < CC_ACTIVE_SECTION_SIZE / K_PAGE_SIZE; i++) {
		uintptr_t from = i, count = 0;

		while (i != CC_ACTIVE_SECTION_SIZE / K_PAGE_SIZE 
				&& (section->modifiedPages[i >> 3] & (1 << (i & 7)))) {
			count++, i++;
		}

		if (!count) continue;

		error = section->cache->callbacks->writeFrom(section->cache, sectionBase + from * K_PAGE_SIZE, 
				section->offset + from * K_PAGE_SIZE, count * K_PAGE_SIZE);

		if (error != ES_SUCCESS) {
			break;
		}
	}

	// Return the active section.

	KMutexAcquire(&activeSectionManager.mutex);

	if (!section->accessors) KernelPanic("CCWriteSection - Section %x has no accessors while being written.\n", section);
	if (section->modified) KernelPanic("CCWriteSection - Section %x was modified while being written.\n", section);

	section->accessors--;
	section->writing = false;
	EsMemoryZero(section->modifiedPages, sizeof(section->modifiedPages));
	__sync_synchronize();
	KEventSet(&section->writeCompleteEvent);
	KEventSet(&section->cache->writeComplete, true);

	if (!section->accessors) {
		if (section->loading) KernelPanic("CCSpaceAccess - Active section %x with no accessors is loading.", section);
		activeSectionManager.lruList.InsertEnd(&section->listItem);
	}

	KMutexRelease(&activeSectionManager.mutex);
}

void CCWriteSectionPrepare(CCActiveSection *section) {
	KMutexAssertLocked(&activeSectionManager.mutex);
	if (!section->modified) KernelPanic("CCWriteSectionPrepare - Unmodified section %x on modified list.\n", section);
	if (section->accessors) KernelPanic("CCWriteSectionPrepare - Section %x with accessors on modified list.\n", section);
	if (section->writing) KernelPanic("CCWriteSectionPrepare - Section %x already being written.\n", section);
	activeSectionManager.modifiedList.Remove(&section->listItem);
	section->writing = true;
	section->modified = false;
	section->flush = false;
	KEventReset(&section->writeCompleteEvent);
	section->accessors = 1;
	if (!activeSectionManager.modifiedList.count) KEventReset(&activeSectionManager.modifiedNonEmpty);
	if (activeSectionManager.modifiedList.count < CC_MODIFIED_GETTING_FULL) KEventReset(&activeSectionManager.modifiedGettingFull);
	KEventSet(&activeSectionManager.modifiedNonFull, true);
}

void CCActiveSectionReturnToLists(CCActiveSection *section, bool writeBack) {
	bool waitNonFull = false;

	if (section->flush) {
		writeBack = true;
	}

	while (true) {
		// If modified, wait for the modified list to be below a certain size.

		if (section->modified && waitNonFull) {
			KEventWait(&activeSectionManager.modifiedNonFull);
		}

		// Decrement the accessors count.

		KMutexAcquire(&activeSectionManager.mutex);
		EsDefer(KMutexRelease(&activeSectionManager.mutex));

		if (!section->accessors) KernelPanic("CCSpaceAccess - Active section %x has no accessors.\n", section);

		if (section->accessors == 1) {
			if (section->loading) KernelPanic("CCSpaceAccess - Active section %x with no accessors is loading.", section);

			// If nobody is accessing the section, put it at the end of the LRU list.

			if (section->modified) {
				if (activeSectionManager.modifiedList.count > CC_MAX_MODIFIED) {
					waitNonFull = true;
					continue;
				}

				if (activeSectionManager.modifiedList.count == CC_MAX_MODIFIED) {
					KEventReset(&activeSectionManager.modifiedNonFull);
				}

				if (activeSectionManager.modifiedList.count >= CC_MODIFIED_GETTING_FULL) {
					KEventSet(&activeSectionManager.modifiedGettingFull, true);
				}

				KEventSet(&activeSectionManager.modifiedNonEmpty, true);

				activeSectionManager.modifiedList.InsertEnd(&section->listItem);
			} else {
				activeSectionManager.lruList.InsertEnd(&section->listItem);
			}
		}

		section->accessors--;

		if (writeBack && !section->accessors && section->modified) {
			CCWriteSectionPrepare(section);
		} else {
			writeBack = false;
		}

		break;
	}

	if (writeBack) {
		CCWriteSection(section);
	}
}


EsError CCSpaceAccess(CCSpace *cache, K_USER_BUFFER void *_buffer, EsFileOffset offset, EsFileOffset count, uint32_t flags, 
        MMSpace *mapSpace = nullptr, unsigned mapFlags = ES_FLAGS_DEFAULT) {

    // TODO Reading in multiple active sections at the same time - will this give better performance on AHCI/NVMe?
    // 	- Each active section needs to be separately committed.
    // TODO Read-ahead.

    // Commit CC_ACTIVE_SECTION_SIZE bytes, since we require an active section to be active at a time.

    if (!MMCommit(CC_ACTIVE_SECTION_SIZE, true)) {
        return ES_ERROR_INSUFFICIENT_RESOURCES;
    }

    EsDefer(MMDecommit(CC_ACTIVE_SECTION_SIZE, true));

    K_USER_BUFFER uint8_t *buffer = (uint8_t *) _buffer;

    EsFileOffset firstSection = RoundDown(offset, CC_ACTIVE_SECTION_SIZE),
                 lastSection = RoundUp(offset + count, CC_ACTIVE_SECTION_SIZE);

    uintptr_t guessedActiveSectionIndex = 0;

    bool writeBack = (flags & CC_ACCESS_WRITE_BACK) && (~flags & CC_ACCESS_PRECISE);
    bool preciseWriteBack = (flags & CC_ACCESS_WRITE_BACK) && (flags & CC_ACCESS_PRECISE);

    for (EsFileOffset sectionOffset = firstSection; sectionOffset < lastSection; sectionOffset += CC_ACTIVE_SECTION_SIZE) {
        if (MM_AVAILABLE_PAGES() < MM_CRITICAL_AVAILABLE_PAGES_THRESHOLD && !GetCurrentThread()->isPageGenerator) {
            KernelLog(LOG_ERROR, "Memory", "waiting for non-critical state", "File cache read on non-generator thread, waiting for more available pages.\n");
            KEventWait(&pmm.availableNotCritical);
        }

        EsFileOffset start = sectionOffset < offset ? offset - sectionOffset : 0;
        EsFileOffset   end = sectionOffset + CC_ACTIVE_SECTION_SIZE > offset + count ? offset + count - sectionOffset : CC_ACTIVE_SECTION_SIZE;

        EsFileOffset pageStart = RoundDown(start, (EsFileOffset) K_PAGE_SIZE) / K_PAGE_SIZE;
        EsFileOffset   pageEnd =   RoundUp(end,   (EsFileOffset) K_PAGE_SIZE) / K_PAGE_SIZE;

        // Find the section in the active sections list.

        KMutexAcquire(&cache->activeSectionsMutex);

        bool found = false;
        uintptr_t index = 0;

        if (guessedActiveSectionIndex < cache->activeSections.Length()
                && cache->activeSections[guessedActiveSectionIndex].offset == sectionOffset) {
            index = guessedActiveSectionIndex;
            found = true;
        }

        if (!found && cache->activeSections.Length()) {
            intptr_t low = 0, high = cache->activeSections.Length() - 1;

            while (low <= high) {
                intptr_t i = low + (high - low) / 2;

                if (cache->activeSections[i].offset < sectionOffset) {
                    low = i + 1;
                } else if (cache->activeSections[i].offset > sectionOffset) {
                    high = i - 1;
                } else {
                    index = i;
                    found = true;
                    break;
                }
            }

            if (!found) {
                index = low;
                if (high + 1 != low) KernelPanic("CCSpaceAccess - Bad binary search.\n");
            }
        }

        if (found) {
            guessedActiveSectionIndex = index + 1;
        }

        KMutexAcquire(&activeSectionManager.mutex);

        CCActiveSection *section;

        // Replace active section in list if it has been used for something else.

        bool replace = false;

        if (found) {
            CCActiveSection *section = activeSectionManager.sections + cache->activeSections[index].index;

            if (section->cache != cache || section->offset != sectionOffset) {
                replace = true, found = false;
            }
        }

        if (!found) {
            // Allocate a new active section.

            if (!activeSectionManager.lruList.count) {
                KMutexRelease(&activeSectionManager.mutex);
                KMutexRelease(&cache->activeSectionsMutex);
                return ES_ERROR_INSUFFICIENT_RESOURCES;
            }

            section = activeSectionManager.lruList.firstItem->thisItem;

            // Add it to the file cache's list of active sections.

            CCActiveSectionReference reference = { .offset = sectionOffset, .index = (uintptr_t) (section - activeSectionManager.sections) };

            if (replace) {
                cache->activeSections[index] = reference;
            } else {
                if (!cache->activeSections.Insert(reference, index)) {
                    KMutexRelease(&activeSectionManager.mutex);
                    KMutexRelease(&cache->activeSectionsMutex);
                    return ES_ERROR_INSUFFICIENT_RESOURCES;
                }
            }

            if (section->cache) {
                // Dereference pages.

                if (section->accessors) {
                    KernelPanic("CCSpaceAccess - Attempting to dereference active section %x with %d accessors.\n", 
                            section, section->accessors);
                }

                CCDereferenceActiveSection(section);

                // Uncover the section's previous contents.

                KMutexAcquire(&section->cache->cachedSectionsMutex);
                CCSpaceUncover(section->cache, section->offset, section->offset + CC_ACTIVE_SECTION_SIZE);
                KMutexRelease(&section->cache->cachedSectionsMutex);

                section->cache = nullptr;
            }

            // Make sure there are cached sections covering the region of the active section.

            KMutexAcquire(&cache->cachedSectionsMutex);

            if (!CCSpaceCover(cache, sectionOffset, sectionOffset + CC_ACTIVE_SECTION_SIZE)) {
                KMutexRelease(&cache->cachedSectionsMutex);
                cache->activeSections.Delete(index);
                KMutexRelease(&activeSectionManager.mutex);
                KMutexRelease(&cache->activeSectionsMutex);
                return ES_ERROR_INSUFFICIENT_RESOURCES;
            }

            KMutexRelease(&cache->cachedSectionsMutex);

            // Remove it from the LRU list.

            activeSectionManager.lruList.Remove(activeSectionManager.lruList.firstItem);

            // Setup the section.

            if (section->accessors) KernelPanic("CCSpaceAccess - Active section %x in the LRU list had accessors.\n", section);
            if (section->loading) KernelPanic("CCSpaceAccess - Active section %x in the LRU list was loading.\n", section);

            section->accessors = 1;
            section->offset = sectionOffset;
            section->cache = cache;

#if 0
            {
                Node *node = EsContainerOf(Node, file.cache, cache);
                EsPrint("active section %d: %s, %x\n", reference.index, node->nameBytes, node->nameBuffer, section->offset);
            }
#endif

#ifdef DEBUG_BUILD
            for (uintptr_t i = 1; i < cache->activeSections.Length(); i++) {
                if (cache->activeSections[i - 1].offset >= cache->activeSections[i].offset) {
                    KernelPanic("CCSpaceAccess - Active sections list in cache %x unordered.\n", cache);
                }
            }
#endif
        } else {
            // Remove the active section from the LRU/modified list, if present, 
            // and increment the accessors count.
            // Don't bother keeping track of its place in the modified list.

            section = activeSectionManager.sections + cache->activeSections[index].index;

            if (!section->accessors) {
                if (section->writing) KernelPanic("CCSpaceAccess - Active section %x in list is being written.\n", section);
                section->listItem.RemoveFromList();
            } else if (section->listItem.list) {
                KernelPanic("CCSpaceAccess - Active section %x in list had accessors (2).\n", section);
            }

            section->accessors++;
        }

        KMutexRelease(&activeSectionManager.mutex);
        KMutexRelease(&cache->activeSectionsMutex);

        if ((flags & CC_ACCESS_WRITE) && section->writing) {
            // If writing, wait for any in progress write-behinds to complete.
            // Note that, once this event is set, a new write can't be started until accessors is 0.

            KEventWait(&section->writeCompleteEvent);
        }

        uint8_t *sectionBase = activeSectionManager.baseAddress + (section - activeSectionManager.sections) * CC_ACTIVE_SECTION_SIZE;

        // Check if all the pages are already referenced (and hence loaded and mapped).

        bool allReferenced = true;

        for (uintptr_t i = pageStart; i < pageEnd; i++) {
            if (~section->referencedPages[i >> 3] & (1 << (i & 7))) {
                allReferenced = false;
                break;
            }
        }

        uint8_t alreadyWritten[CC_ACTIVE_SECTION_SIZE / K_PAGE_SIZE / 8] = {};

        if (allReferenced) {
            goto copy;
        }

        while (true) {
            KMutexAcquire(&cache->cachedSectionsMutex);

            // Find the first cached section covering this active section.

            CCCachedSection *cachedSection = CCFindCachedSectionContaining(cache, sectionOffset);

            if (!cachedSection) {
                KernelPanic("CCSpaceAccess - Active section %x not covered.\n", section);
            }

            // Find where the requested region is located.

            uintptr_t pagesToSkip = pageStart + (sectionOffset - cachedSection->offset) / K_PAGE_SIZE,
                      pageInCachedSectionIndex = 0;

            while (pagesToSkip) {
                if (pagesToSkip >= cachedSection->pageCount) {
                    pagesToSkip -= cachedSection->pageCount;
                    cachedSection++;
                } else {
                    pageInCachedSectionIndex = pagesToSkip;
                    pagesToSkip = 0;
                }
            }

            if (pageInCachedSectionIndex >= cachedSection->pageCount 
                    || cachedSection >= cache->cachedSections.array + cache->cachedSections.Length()) {
                KernelPanic("CCSpaceAccess - Invalid requested region search result.\n");
            }

            // Reference all loaded pages, and record the ones we need to load.

            uintptr_t *pagesToLoad[CC_ACTIVE_SECTION_SIZE / K_PAGE_SIZE];
            uintptr_t loadCount = 0;

            for (uintptr_t i = pageStart; i < pageEnd; i++) {
                if (cachedSection == cache->cachedSections.array + cache->cachedSections.Length()) {
                    KernelPanic("CCSpaceAccess - Not enough cached sections.\n");
                }

                KMutexAcquire(&pmm.pageFrameMutex);

                uintptr_t entry = cachedSection->data[pageInCachedSectionIndex];
                pagesToLoad[i] = nullptr;

                if ((entry & MM_SHARED_ENTRY_PRESENT) && (~section->referencedPages[i >> 3] & (1 << (i & 7)))) {
                    MMPageFrame *frame = pmm.pageFrames + (entry >> K_PAGE_BITS);

                    if (frame->state == MMPageFrame::STANDBY) {
                        // The page was mapped out from all MMSpaces, and therefore was placed on the standby list.
                        // Mark the page as active before we map it.
                        MMPhysicalActivatePages(entry / K_PAGE_SIZE, 1, ES_FLAGS_DEFAULT);
                        frame->cacheReference = cachedSection->data + pageInCachedSectionIndex;
                    } else if (frame->state != MMPageFrame::ACTIVE) {
                        KernelPanic("CCSpaceAccess - Page frame %x was neither standby nor active.\n", frame);
                    } else if (!frame->active.references) {
                        KernelPanic("CCSpaceAccess - Active page frame %x had no references.\n", frame);
                    }

                    frame->active.references++;
                    MMArchMapPage(kernelMMSpace, entry & ~(K_PAGE_SIZE - 1), (uintptr_t) sectionBase + i * K_PAGE_SIZE, MM_MAP_PAGE_FRAME_LOCK_ACQUIRED);

                    __sync_synchronize();
                    section->referencedPages[i >> 3] |= 1 << (i & 7);
                    section->referencedPageCount++;
                } else if (~entry & MM_SHARED_ENTRY_PRESENT) {
                    if (section->referencedPages[i >> 3] & (1 << (i & 7))) {
                        KernelPanic("CCSpaceAccess - Referenced page was not present.\n");
                    }

                    pagesToLoad[i] = cachedSection->data + pageInCachedSectionIndex;
                    loadCount++;
                }

                KMutexRelease(&pmm.pageFrameMutex);

                pageInCachedSectionIndex++;

                if (pageInCachedSectionIndex == cachedSection->pageCount) {
                    pageInCachedSectionIndex = 0;
                    cachedSection++;
                }
            }

            if (!loadCount) {
                KMutexRelease(&cache->cachedSectionsMutex);
                goto copy;
            }

            // If another thread is already trying to load pages into the active section,
            // then wait for it to complete.

            bool loadCollision = section->loading;

            if (!loadCollision) {
                section->loading = true;
                KEventReset(&section->loadCompleteEvent);
            }

            KMutexRelease(&cache->cachedSectionsMutex);

            if (loadCollision) {
                KEventWait(&section->loadCompleteEvent);
                continue;
            }

            // Allocate, reference and map physical pages.

            uintptr_t pageFrames[CC_ACTIVE_SECTION_SIZE / K_PAGE_SIZE];

            for (uintptr_t i = pageStart; i < pageEnd; i++) {
                if (!pagesToLoad[i]) {
                    continue;
                }

                pageFrames[i] = MMPhysicalAllocate(ES_FLAGS_DEFAULT);

                MMPageFrame *frame = pmm.pageFrames + (pageFrames[i] >> K_PAGE_BITS);
                frame->active.references = 1;
                frame->cacheReference = pagesToLoad[i];

                MMArchMapPage(kernelMMSpace, pageFrames[i], (uintptr_t) sectionBase + i * K_PAGE_SIZE, ES_FLAGS_DEFAULT);
            }

            // Read from the cache's backing store.

            EsError error = ES_SUCCESS;

            if ((flags & CC_ACCESS_WRITE) && (~flags & CC_ACCESS_USER_BUFFER_MAPPED)) {
                bool loadedStart = false;

                if (error == ES_SUCCESS && (start & (K_PAGE_SIZE - 1)) && pagesToLoad[pageStart]) {
                    // Left side of the accessed region is not page aligned, so we need to load in the page.

                    error = cache->callbacks->readInto(cache, sectionBase + pageStart * K_PAGE_SIZE, 
                            section->offset + pageStart * K_PAGE_SIZE, K_PAGE_SIZE);
                    loadedStart = true;
                }

                if (error == ES_SUCCESS && (end & (K_PAGE_SIZE - 1)) && !(pageStart == pageEnd - 1 && loadedStart) && pagesToLoad[pageEnd - 1]) {
                    // Right side of the accessed region is not page aligned, so we need to load in the page.

                    error = cache->callbacks->readInto(cache, sectionBase + (pageEnd - 1) * K_PAGE_SIZE, 
                            section->offset + (pageEnd - 1) * K_PAGE_SIZE, K_PAGE_SIZE);
                }

                K_USER_BUFFER uint8_t *buffer2 = buffer;

                // Initialise the rest of the contents HERE, before referencing the pages.
                // The user buffer cannot be mapped otherwise we could deadlock while reading from it,
                // as we have marked the active section in the loading state.

                for (uintptr_t i = pageStart; i < pageEnd; i++) {
                    uintptr_t left = i == pageStart ? (start & (K_PAGE_SIZE - 1)) : 0;
                    uintptr_t right = i == pageEnd - 1 ? (end & (K_PAGE_SIZE - 1)) : K_PAGE_SIZE;
                    if (!right) right = K_PAGE_SIZE;

                    if (pagesToLoad[i]) {
                        EsMemoryCopy(sectionBase + i * K_PAGE_SIZE + left, buffer2, right - left);
                        alreadyWritten[i >> 3] |= 1 << (i & 7);
                    }

                    buffer2 += right - left;
                }

                if (buffer + (end - start) != buffer2) {
                    KernelPanic("CCSpaceAccess - Incorrect page left/right calculation.\n");
                }
            } else {
                for (uintptr_t i = pageStart; i < pageEnd; i++) {
                    uintptr_t from = i, count = 0;

                    while (i != pageEnd && pagesToLoad[i]) {
                        count++, i++;
                    }

                    if (!count) continue;

                    error = cache->callbacks->readInto(cache, sectionBase + from * K_PAGE_SIZE, 
                            section->offset + from * K_PAGE_SIZE, count * K_PAGE_SIZE);

                    if (error != ES_SUCCESS) {
                        break;
                    }
                }
            }

            if (error != ES_SUCCESS) {
                // Free and unmap the pages we allocated if there was an error.

                for (uintptr_t i = pageStart; i < pageEnd; i++) {
                    if (!pagesToLoad[i]) continue;
                    MMArchUnmapPages(kernelMMSpace, (uintptr_t) sectionBase + i * K_PAGE_SIZE, 1, ES_FLAGS_DEFAULT);
                    MMPhysicalFree(pageFrames[i], false, 1);
                }
            }

            KMutexAcquire(&cache->cachedSectionsMutex);

            // Write the pages to the cached sections, and mark them as referenced.

            if (error == ES_SUCCESS) {
                for (uintptr_t i = pageStart; i < pageEnd; i++) {
                    if (pagesToLoad[i]) {
                        *pagesToLoad[i] = pageFrames[i] | MM_SHARED_ENTRY_PRESENT;
                        section->referencedPages[i >> 3] |= 1 << (i & 7);
                        section->referencedPageCount++;
                    }
                }
            }

            // Return active section to normal state, and set the load complete event.

            section->loading = false;
            KEventSet(&section->loadCompleteEvent);

            KMutexRelease(&cache->cachedSectionsMutex);

            if (error != ES_SUCCESS) {
                return error;
            }

            break;
        }

copy:;

     if (GetLocalStorage()->spinlockCount) {
         KernelPanic("CCSpaceAccess - Spinlocks acquired.\n");
     }

     // Copy into/from the user's buffer.

     if (buffer) {
         if (flags & CC_ACCESS_MAP) {
             if ((start & (K_PAGE_SIZE - 1)) || (end & (K_PAGE_SIZE - 1)) || ((uintptr_t) buffer & (K_PAGE_SIZE - 1))) {
                 KernelPanic("CCSpaceAccess - Passed READ_MAP flag, but start/end/buffer misaligned.\n");
             }

             for (uintptr_t i = start; i < end; i += K_PAGE_SIZE) {
                 uintptr_t physicalAddress = MMArchTranslateAddress(kernelMMSpace, (uintptr_t) sectionBase + i, false);
                 KMutexAcquire(&pmm.pageFrameMutex);
                 MMPageFrame *frame = &pmm.pageFrames[physicalAddress / K_PAGE_SIZE];

                 if (frame->state != MMPageFrame::ACTIVE || !frame->active.references) {
                     KernelPanic("CCSpaceAccess - Bad active frame %x; removed while still in use by the active section.\n", frame);
                 }

                 frame->active.references++;

                 if (!MMArchMapPage(mapSpace, physicalAddress, (uintptr_t) buffer, 
                             mapFlags | MM_MAP_PAGE_IGNORE_IF_MAPPED /* since this isn't locked */
                             | MM_MAP_PAGE_FRAME_LOCK_ACQUIRED)) {
                     // The page was already mapped.
                     // Don't need to check if this goes to zero, because the page frame mutex is still acquired.
                     frame->active.references--;
                 }

                 KMutexRelease(&pmm.pageFrameMutex);
                 buffer += K_PAGE_SIZE;
             }
         } else if (flags & CC_ACCESS_READ) {
             EsMemoryCopy(buffer, sectionBase + start, end - start);
             buffer += end - start;
         } else if (flags & CC_ACCESS_WRITE) {
             for (uintptr_t i = pageStart; i < pageEnd; i++) {
                 uintptr_t left = i == pageStart ? (start & (K_PAGE_SIZE - 1)) : 0;
                 uintptr_t right = i == pageEnd - 1 ? (end & (K_PAGE_SIZE - 1)) : K_PAGE_SIZE;
                 if (!right) right = K_PAGE_SIZE;

                 if (~alreadyWritten[i >> 3] & (1 << (i & 7))) {
                     EsMemoryCopy(sectionBase + i * K_PAGE_SIZE + left, buffer, right - left);
                 }

                 buffer += right - left;

                 if (!preciseWriteBack) {
                     __sync_fetch_and_or(section->modifiedPages + (i >> 3), 1 << (i & 7));
                 }
             }

             if (!preciseWriteBack) {
                 section->modified = true;
             } else {
                 uint8_t *sectionBase = activeSectionManager.baseAddress + (section - activeSectionManager.sections) * CC_ACTIVE_SECTION_SIZE;
                 EsError error = section->cache->callbacks->writeFrom(section->cache, sectionBase + start, section->offset + start, end - start);

                 if (error != ES_SUCCESS) {
                     CCActiveSectionReturnToLists(section, writeBack);
                     return error;
                 }
             }
         }
     }

     CCActiveSectionReturnToLists(section, writeBack);
    }

    return ES_SUCCESS;

}


bool MMHandlePageFault(MMSpace *space, uintptr_t address, unsigned faultFlags) {
	// EsPrint("HandlePageFault: %x/%x/%x\n", space, address, faultFlags);

	address &= ~(K_PAGE_SIZE - 1);

	bool lockAcquired = faultFlags & MM_HANDLE_PAGE_FAULT_LOCK_ACQUIRED;
	MMRegion *region;

	if (!lockAcquired && MM_AVAILABLE_PAGES() < MM_CRITICAL_AVAILABLE_PAGES_THRESHOLD && GetCurrentThread() && !GetCurrentThread()->isPageGenerator) {
		KernelLog(LOG_ERROR, "Memory", "waiting for non-critical state", "Page fault on non-generator thread, waiting for more available pages.\n");
		KEventWait(&pmm.availableNotCritical);
	}

	{
		if (!lockAcquired) KMutexAcquire(&space->reserveMutex);
		else KMutexAssertLocked(&space->reserveMutex);
		EsDefer(if (!lockAcquired) KMutexRelease(&space->reserveMutex));

		// Find the region, and pin it (so it can't be freed).
		region = MMFindRegion(space, address);
		if (!region) return false;
		if (!KWriterLockTake(&region->data.pin, K_LOCK_SHARED, true /* poll */)) return false;
	}

	EsDefer(KWriterLockReturn(&region->data.pin, K_LOCK_SHARED));
	KMutexAcquire(&region->data.mapMutex);
	EsDefer(KMutexRelease(&region->data.mapMutex));

	if (MMArchTranslateAddress(space, address, faultFlags & MM_HANDLE_PAGE_FAULT_WRITE)) {
		// Spurious page fault.
		return true;
	}

	bool copyOnWrite = false, markModified = false;

	if (faultFlags & MM_HANDLE_PAGE_FAULT_WRITE) {
		if (region->flags & MM_REGION_COPY_ON_WRITE) {
			// This is copy-on-write page that needs to be copied.
			copyOnWrite = true;
		} else if (region->flags & MM_REGION_READ_ONLY) {
			// The page was read-only.
			KernelLog(LOG_ERROR, "Memory", "read only page fault", "MMHandlePageFault - Page was read only.\n");
			return false;
		} else {
			// We mapped the page as read-only so we could track whether it has been written to.
			// It has now been written to.
			markModified = true;
		}
	}

	uintptr_t offsetIntoRegion = address - region->baseAddress;
	uint64_t needZeroPages = 0;
	bool zeroPage = true;

	if (space->user) {
		needZeroPages = MM_PHYSICAL_ALLOCATE_ZEROED;
		zeroPage = false;
	}

	unsigned flags = ES_FLAGS_DEFAULT;

	if (space->user) flags |= MM_MAP_PAGE_USER;
	if (region->flags & MM_REGION_NOT_CACHEABLE) flags |= MM_MAP_PAGE_NOT_CACHEABLE;
	if (region->flags & MM_REGION_WRITE_COMBINING) flags |= MM_MAP_PAGE_WRITE_COMBINING;
	if (!markModified && !(region->flags & MM_REGION_FIXED) && (region->flags & MM_REGION_FILE)) flags |= MM_MAP_PAGE_READ_ONLY;

	if (region->flags & MM_REGION_PHYSICAL) {
		MMArchMapPage(space, region->data.physical.offset + address - region->baseAddress, address, flags);
		return true;
	} else if (region->flags & MM_REGION_SHARED) {
		MMSharedRegion *sharedRegion = region->data.shared.region;

		if (!sharedRegion->handles) {
			KernelPanic("MMHandlePageFault - Shared region has no handles.\n");
		}

		KMutexAcquire(&sharedRegion->mutex);

		uintptr_t offset = address - region->baseAddress + region->data.shared.offset;

		if (offset >= sharedRegion->sizeBytes) {
			KMutexRelease(&sharedRegion->mutex);
			KernelLog(LOG_ERROR, "Memory", "outside shared size", "MMHandlePageFault - Attempting to access shared memory past end of region.\n");
			return false;
		}

		uintptr_t *entry = (uintptr_t *) sharedRegion->data + (offset / K_PAGE_SIZE);

		if (*entry & MM_SHARED_ENTRY_PRESENT) zeroPage = false;
		else *entry = MMPhysicalAllocate(needZeroPages) | MM_SHARED_ENTRY_PRESENT;

		MMArchMapPage(space, *entry & ~(K_PAGE_SIZE - 1), address, flags);
		if (zeroPage) EsMemoryZero((void *) address, K_PAGE_SIZE); 
		KMutexRelease(&sharedRegion->mutex);
		return true;
	} else if (region->flags & MM_REGION_FILE) {
		if (address >= region->baseAddress + (region->pageCount << K_PAGE_BITS) - region->data.file.zeroedBytes) {
			// EsPrint("%x:%d\n", address, needZeroPages);
			MMArchMapPage(space, MMPhysicalAllocate(needZeroPages), address, (flags & ~MM_MAP_PAGE_READ_ONLY) | MM_MAP_PAGE_COPIED);
			if (zeroPage) EsMemoryZero((void *) address, K_PAGE_SIZE); 
			return true;
		}

		if (copyOnWrite) {
			doCopyOnWrite:;
			uintptr_t existingTranslation = MMArchTranslateAddress(space, address);

			if (existingTranslation) {
				// We need to use PMCopy, because as soon as the page is mapped for the user,
				// other threads can access it.
				uintptr_t page = MMPhysicalAllocate(ES_FLAGS_DEFAULT);
				PMCopy(page, (void *) address, 1);
				MMArchUnmapPages(space, address, 1, MM_UNMAP_PAGES_BALANCE_FILE);
				MMArchMapPage(space, page, address, (flags & ~MM_MAP_PAGE_READ_ONLY) | MM_MAP_PAGE_COPIED);
				return true;
			} else {
				// EsPrint("Write to unmapped, %x.\n", address);
			}
		}

		KMutexRelease(&region->data.mapMutex);

		size_t pagesToRead = 16;

		if (region->pageCount - (offsetIntoRegion + region->data.file.zeroedBytes) / K_PAGE_SIZE < pagesToRead) {
			pagesToRead = region->pageCount - (offsetIntoRegion + region->data.file.zeroedBytes) / K_PAGE_SIZE;
		}

		EsError error = CCSpaceAccess(&region->data.file.node->cache, (void *) address, 
				offsetIntoRegion + region->data.file.offset, pagesToRead * K_PAGE_SIZE, 
				CC_ACCESS_MAP, space, flags);

		KMutexAcquire(&region->data.mapMutex);

		if (error != ES_SUCCESS) {
			KernelLog(LOG_ERROR, "Memory", "mapped file read error", "MMHandlePageFault - Could not read from file %x. Error: %d.\n", 
					region->data.file.node, error);
			return false;
		}

		if (copyOnWrite) {
			goto doCopyOnWrite;
		}

		return true;
	} else if (region->flags & MM_REGION_NORMAL) {
		if (!(region->flags & MM_REGION_NO_COMMIT_TRACKING)) {
			if (!region->data.normal.commit.Contains(offsetIntoRegion >> K_PAGE_BITS)) {
				KernelLog(LOG_ERROR, "Memory", "outside commit range", "MMHandlePageFault - Attempting to access uncommitted memory in reserved region.\n");
				return false;
			}
		}

		MMArchMapPage(space, MMPhysicalAllocate(needZeroPages), address, flags);
		if (zeroPage) EsMemoryZero((void *) address, K_PAGE_SIZE); 
		return true;
	} else if (region->flags & MM_REGION_GUARD) {
		KernelLog(LOG_ERROR, "Memory", "guard page hit", "MMHandlePageFault - Guard page hit!\n");
		return false;
	} else {
		KernelLog(LOG_ERROR, "Memory", "cannot fault in region", "MMHandlePageFault - Unsupported region type (flags: %x).\n", region->flags);
		return false;
	}
}







struct KDMASegment
{
    uintptr_t physicalAddress;
    size_t byteCount;
    bool isLast;
};

#define K_ACCESS_READ (0)
#define K_ACCESS_WRITE (1)

struct KDMABuffer {
	uintptr_t virtualAddress;
	size_t totalByteCount;
	uintptr_t offsetBytes;

    bool is_complete()
    {
        return offsetBytes == totalByteCount;
    }

    KDMASegment next_segment(bool peek = false)
    {
        if (offsetBytes >= totalByteCount || !virtualAddress)
        {
            KernelPanic("Invalid state KDMABuffer\n");
        }

        size_t transfer_byte_count = K_PAGE_SIZE;
        uintptr_t virtual_address = virtualAddress + offsetBytes; 
        uintptr_t physical_address = MMArchTranslateAddress(kernelMMSpace, virtual_address);
        uintptr_t offset_into_page = virtual_address & (K_PAGE_SIZE - 1);

        if (physical_address == 0) KernelPanic("Page in buffer unmapped\n");

        if (offset_into_page > 0)
        {
            transfer_byte_count = K_PAGE_SIZE - offset_into_page;
            physical_address += offset_into_page;
        }

        auto total_minus_offset = this->totalByteCount - this->offsetBytes;
        if (transfer_byte_count > total_minus_offset)
        {
            transfer_byte_count = total_minus_offset;
        }

        bool is_last = this->offsetBytes + transfer_byte_count == this->totalByteCount;
        if (!peek) this->offsetBytes += transfer_byte_count;

        return { physical_address, transfer_byte_count, is_last };
    }
};


struct KWorkGroup {
	inline void Initialise() {
		remaining = 1;
		success = 1;
		KEventReset(&event);
	}

	inline bool Wait() {
		if (__sync_fetch_and_sub(&remaining, 1) != 1) {
			KEventWait(&event);
		}

		if (remaining) {
			KernelPanic("KWorkGroup::Wait - Expected remaining operations to be 0 after event set.\n");
		}

		return success ? true : false;
	}

	inline void Start() {
		if (__sync_fetch_and_add(&remaining, 1) == 0) {
			KernelPanic("KWorkGroup::Start - Could not start operation on completed dispatch group.\n");
		}
	}

	inline void End(bool _success) {
		if (!_success) {
			success = false;
			__sync_synchronize();
		}

		if (__sync_fetch_and_sub(&remaining, 1) == 1) {
			KEventSet(&event);
		}
	}

	volatile uintptr_t remaining;
	volatile uintptr_t success;
	KEvent event;
};

struct EsBlockDeviceInformation {
	size_t sectorSize;
	EsFileOffset sectorCount;
	bool readOnly;
	uint8_t nestLevel;
	uint8_t driveType;
	uint8_t modelBytes;
	char model[64];
};

struct KBlockDeviceAccessRequest {
	struct KBlockDevice *device;
	EsFileOffset offset;
	size_t count;
	int operation;
	KDMABuffer *buffer;
	uint64_t flags;
	KWorkGroup *dispatchGroup;
};

typedef void (*KDeviceAccessCallbackFunction)(KBlockDeviceAccessRequest request);

struct KBlockDevice : KDevice {
	KDeviceAccessCallbackFunction access; // Don't call directly; see KFileSystem::Access.
	EsBlockDeviceInformation information;
	size_t maxAccessSectorCount;

	uint8_t *signatureBlock; // Signature block. Only valid during fileSystem detection.
	KMutex detectFileSystemMutex;
};



struct KFileSystem : KDevice {
	KBlockDevice *block; // Gives the sector size and count.

	KNode *rootDirectory;

	// Only use this for file system metadata that isn't cached in a Node. 
	// This must be used consistently, i.e. if you ever read a region cached, then you must always write that region cached, and vice versa.
#define FS_BLOCK_ACCESS_CACHED (1) 
#define FS_BLOCK_ACCESS_SOFT_ERRORS (2)
	// Access the block device. Returns true on success.
	// Offset and count must be sector aligned. Buffer must be DWORD aligned.
	EsError Access(EsFileOffset offset, size_t count, int operation, void *buffer, uint32_t flags, KWorkGroup *dispatchGroup = nullptr);

	// Fill these fields in before registering the file system:

	char name[64];
	size_t nameBytes;

	size_t directoryEntryDataBytes; // The size of the driverData passed to FSDirectoryEntryFound and received in the load callback.
	size_t nodeDataBytes; // The average bytes allocated by the driver per node (used for managing cache sizes).

	EsFileOffsetDifference rootDirectoryInitialChildren;
	EsFileOffset spaceTotal, spaceUsed;
	EsUniqueIdentifier identifier;

	size_t  	(*read)		(KNode *node, void *buffer, EsFileOffset offset, EsFileOffset count);
	size_t  	(*write)	(KNode *node, const void *buffer, EsFileOffset offset, EsFileOffset count);
	void  		(*sync)		(KNode *directory, KNode *node); // TODO Error reporting?
	EsError		(*scan)		(const char *name, size_t nameLength, KNode *directory); // Add the entry with FSDirectoryEntryFound.
	EsError		(*load)		(KNode *directory, KNode *node, KNodeMetadata *metadata /* for if you need to update it */, 
						const void *entryData /* driverData passed to FSDirectoryEntryFound */);
	EsFileOffset  	(*resize)	(KNode *file, EsFileOffset newSize, EsError *error);
	EsError		(*create)	(const char *name, size_t nameLength, EsNodeType type, KNode *parent, KNode *node, void *driverData);
	EsError 	(*enumerate)	(KNode *directory); // Add the entries with FSDirectoryEntryFound.
	EsError		(*remove)	(KNode *directory, KNode *file);
	EsError  	(*move)		(KNode *oldDirectory, KNode *file, KNode *newDirectory, const char *newName, size_t newNameLength);
	void  		(*close)	(KNode *node);
	void		(*unmount)	(KFileSystem *fileSystem);

	// TODO Normalizing file names, for case-insensitive filesystems.
	// void *       (*normalize)    (const char *name, size_t nameLength, size_t *resultLength); 

	// Internals.

	KMutex moveMutex;
	bool isBootFileSystem, unmounting;
	EsUniqueIdentifier installationIdentifier;
	volatile uint64_t totalHandleCount;
	CCSpace cacheSpace;

	MMObjectCache cachedDirectoryEntries, // Directory entries without a loaded node.
		      cachedNodes; // Nodes with no handles or directory entries.
};


struct {
	KWriterLock fileSystemsLock;

	KFileSystem *bootFileSystem;
	KEvent foundBootFileSystemEvent;

	KSpinlock updateNodeHandles; // Also used for node/directory entry cache operations.

	bool shutdown;

	volatile uint64_t totalHandleCount;
	volatile uintptr_t fileSystemsUnmounting;
	KEvent fileSystemUnmounted;
} fs = {
	.fileSystemUnmounted = { .autoReset = true },
};


void MMObjectCacheInsert(MMObjectCache *cache, MMObjectCacheItem *item) {
	KSpinlockAcquire(&cache->lock);
	cache->items.Insert(item, false /* end */);
	cache->count++;
	__sync_fetch_and_add(&pmm.approximateTotalObjectCacheBytes, cache->averageObjectBytes);

	if (MM_OBJECT_CACHE_SHOULD_TRIM()) {
		KEventSet(&pmm.trimObjectCaches, true);
	}

	KSpinlockRelease(&cache->lock);
}

void MMObjectCacheUnregister(MMObjectCache *cache) {
	KMutexAcquire(&pmm.objectCacheListMutex);
	pmm.objectCacheList.Remove(&cache->item);
	KMutexRelease(&pmm.objectCacheListMutex);

	// Wait for any trim threads still using the cache to finish.
	KWriterLockTake(&cache->trimLock, K_LOCK_EXCLUSIVE);
	KWriterLockReturn(&cache->trimLock, K_LOCK_EXCLUSIVE);
}

void MMObjectCacheFlush(MMObjectCache *cache) {
	if (cache->item.list) KernelPanic("MMObjectCacheFlush - Cache %x must be unregistered before flushing.\n", cache);

	// Wait for any trim threads still using the cache to finish.
	KWriterLockTake(&cache->trimLock, K_LOCK_EXCLUSIVE);

	// Trim the cache until it is empty.
	// The trim callback is allowed to increase cache->count,
	// but nobody else should be increasing it once it has been unregistered.
	while (cache->count) cache->trim(cache);

	// Return the trim lock.
	KWriterLockReturn(&cache->trimLock, K_LOCK_EXCLUSIVE);
}

KDevice *deviceTreeRoot;
KMutex deviceTreeMutex;

void KDeviceOpenHandle(KDevice *device) {
	KMutexAcquire(&deviceTreeMutex);
	if (!device->handles) KernelPanic("KDeviceOpenHandle - Device %s has no handles.\n", device);
	device->handles++;
	KMutexRelease(&deviceTreeMutex);
}


void DeviceDestroy(KDevice *device) {
	device->children.Free();
	if (device->destroy) device->destroy(device);
	EsHeapFree(device, 0, K_FIXED);
}

void KDeviceCloseHandle(KDevice *device) {
	KMutexAcquire(&deviceTreeMutex);

	if (!device->handles) KernelPanic("KDeviceCloseHandle - Device %s has no handles.\n", device);
	device->handles--;

	while (!device->handles && !device->children.Length()) {
		device->parent->children.FindAndDeleteSwap(device, true /* fail if not found */);
		KDevice *parent = device->parent;
		DeviceDestroy(device);
		device = parent;
	}

	KMutexRelease(&deviceTreeMutex);
}

void FSUnmountFileSystem(uintptr_t argument) {
	KFileSystem *fileSystem = (KFileSystem *) argument;
	KernelLog(LOG_INFO, "FS", "unmount start", "Unmounting file system %x...\n", fileSystem);

	MMObjectCacheUnregister(&fileSystem->cachedNodes);
	MMObjectCacheUnregister(&fileSystem->cachedDirectoryEntries);

	while (fileSystem->cachedNodes.count || fileSystem->cachedDirectoryEntries.count) {
		MMObjectCacheFlush(&fileSystem->cachedNodes);
		MMObjectCacheFlush(&fileSystem->cachedDirectoryEntries);
	}

	if (fileSystem->unmount) {
		fileSystem->unmount(fileSystem);
	}

	KernelLog(LOG_INFO, "FS", "unmount complete", "Unmounted file system %x.\n", fileSystem);
	KDeviceCloseHandle(fileSystem);
	__sync_fetch_and_sub(&fs.fileSystemsUnmounting, 1);
	KEventSet(&fs.fileSystemUnmounted, true);
}









void CCSpaceFlush(CCSpace *cache) {
	while (true) {
		bool complete = true;

		KMutexAcquire(&cache->activeSectionsMutex);
		KMutexAcquire(&activeSectionManager.mutex);

		for (uintptr_t i = 0; i < cache->activeSections.Length(); i++) {
			CCActiveSection *section = activeSectionManager.sections + cache->activeSections[i].index;

			if (section->cache == cache && section->offset == cache->activeSections[i].offset) {
				if (section->writing) {
					// The section is being written; wait for it to complete.
					complete = false;
				} else if (section->modified) {
					if (section->accessors) {
						// Someone is accessing this section; mark it to be written back once they are done.
						section->flush = true;
						complete = false;
					} else {
						// Nobody is accessing the section; we can write it ourselves.
						complete = false;
						CCWriteSectionPrepare(section);
						KMutexRelease(&activeSectionManager.mutex);
						KMutexRelease(&cache->activeSectionsMutex);
						CCWriteSection(section);
						KMutexAcquire(&cache->activeSectionsMutex);
						KMutexAcquire(&activeSectionManager.mutex);
					}
				}
			}

		}

		KMutexRelease(&activeSectionManager.mutex);
		KMutexRelease(&cache->activeSectionsMutex);

		if (!complete) {
			KEventWait(&cache->writeComplete);
		} else {
			break;
		}
	}
}


void MMUpdateAvailablePageCount(bool increase) {
	if (MM_AVAILABLE_PAGES() >= MM_CRITICAL_AVAILABLE_PAGES_THRESHOLD) {
		KEventSet(&pmm.availableNotCritical, true);
		KEventReset(&pmm.availableCritical);
	} else {
		KEventReset(&pmm.availableNotCritical);
		KEventSet(&pmm.availableCritical, true);

		if (!increase) {
			KernelLog(LOG_ERROR, "Memory", "critical page limit hit", 
					"Critical number of available pages remain: %d (%dKB).\n", MM_AVAILABLE_PAGES(), MM_AVAILABLE_PAGES() * K_PAGE_SIZE / 1024);
		}
	}

	if (MM_AVAILABLE_PAGES() >= MM_LOW_AVAILABLE_PAGES_THRESHOLD) {
		KEventReset(&pmm.availableLow);
	} else {
		KEventSet(&pmm.availableLow, true);
	}
}

void MMPhysicalActivatePages(uintptr_t pages, uintptr_t count, unsigned flags) {
	(void) flags;

	KMutexAssertLocked(&pmm.pageFrameMutex);

	for (uintptr_t i = 0; i < count; i++) {
		MMPageFrame *frame = pmm.pageFrames + pages + i;

		if (frame->state == MMPageFrame::FREE) {
			pmm.countFreePages--;
		} else if (frame->state == MMPageFrame::ZEROED) {
			pmm.countZeroedPages--;
		} else if (frame->state == MMPageFrame::STANDBY) {
			pmm.countStandbyPages--;

			if (pmm.lastStandbyPage == pages + i) {
				if (frame->list.previous == &pmm.firstStandbyPage) {
					// There are no more pages in the list.
					pmm.lastStandbyPage = 0;
				} else {
					pmm.lastStandbyPage = ((uintptr_t) frame->list.previous - (uintptr_t) pmm.pageFrames) / sizeof(MMPageFrame);
				}
			}
		} else {
			KernelPanic("MMPhysicalActivatePages - Corrupt page frame database (4).\n");
		}

		// Unlink the frame from its list.
		*frame->list.previous = frame->list.next;
		if (frame->list.next) pmm.pageFrames[frame->list.next].list.previous = frame->list.previous;

		EsMemoryZero(frame, sizeof(MMPageFrame));
		frame->state = MMPageFrame::ACTIVE;
	}

	pmm.countActivePages += count;
	MMUpdateAvailablePageCount(false);
}

void CCSpaceDestroy(CCSpace *cache) {
	CCSpaceFlush(cache);

	for (uintptr_t i = 0; i < cache->activeSections.Length(); i++) {
		KMutexAcquire(&activeSectionManager.mutex);

		CCActiveSection *section = activeSectionManager.sections + cache->activeSections[i].index;

		if (section->cache == cache && section->offset == cache->activeSections[i].offset) {
			CCDereferenceActiveSection(section);
			section->cache = nullptr;

			if (section->accessors || section->modified || section->listItem.list != &activeSectionManager.lruList) {
				KernelPanic("CCSpaceDestroy - Section %x has invalid state to destroy cache space %x.\n",
						section, cache);
			}

			section->listItem.RemoveFromList();
			activeSectionManager.lruList.InsertStart(&section->listItem);
		}

		KMutexRelease(&activeSectionManager.mutex);
	}

	for (uintptr_t i = 0; i < cache->cachedSections.Length(); i++) {
		CCCachedSection *section = &cache->cachedSections[i];

		for (uintptr_t i = 0; i < section->pageCount; i++) {
			KMutexAcquire(&pmm.pageFrameMutex);

			if (section->data[i] & MM_SHARED_ENTRY_PRESENT) {
				uintptr_t page = section->data[i] & ~(K_PAGE_SIZE - 1);

				if (pmm.pageFrames[page >> K_PAGE_BITS].state != MMPageFrame::ACTIVE) {
				       MMPhysicalActivatePages(page >> K_PAGE_BITS, 1, ES_FLAGS_DEFAULT);
				}

				MMPhysicalFree(page, true, 1);
			}

			KMutexRelease(&pmm.pageFrameMutex);
		}

		EsHeapFree(section->data, sizeof(uintptr_t) * section->pageCount, K_CORE);
	}

	cache->cachedSections.Free();
	cache->activeSections.Free();
}

EsError FSNodeOpenHandle(KNode *node, uint32_t flags, uint8_t mode) {
	{
		// See comment in FSNodeCloseHandle for why we use the spinlock.
		KSpinlockAcquire(&fs.updateNodeHandles);
		EsDefer(KSpinlockRelease(&fs.updateNodeHandles));

		if (node->handles && mode == FS_NODE_OPEN_HANDLE_FIRST) {
			KernelPanic("FSNodeOpenHandle - Trying to open first handle to %x, but it already has handles.\n", node);
		} else if (!node->handles && mode == FS_NODE_OPEN_HANDLE_STANDARD) {
			KernelPanic("FSNodeOpenHandle - Trying to open handle to %x, but it has no handles.\n", node);
		}

		if (node->handles == NODE_MAX_ACCESSORS) { 
			return ES_ERROR_INSUFFICIENT_RESOURCES; 
		}

		if (node->directoryEntry->type == ES_NODE_FILE) {
			FSFile *file = (FSFile *) node;

			if (flags & ES_FILE_READ) {
				if (file->countWrite > 0) return ES_ERROR_FILE_HAS_WRITERS; 
			} else if (flags & ES_FILE_WRITE) {
				if (flags & _ES_NODE_FROM_WRITE_EXCLUSIVE) {
					if (!file->countWrite || (~file->flags & NODE_HAS_EXCLUSIVE_WRITER)) {
						KernelPanic("FSNodeOpenHandle - File %x is invalid state for a handle to have the _ES_NODE_FROM_WRITE_EXCLUSIVE flag.\n", file);
					}
				} else {
					if (file->countWrite) {
						return ES_ERROR_FILE_CANNOT_GET_EXCLUSIVE_USE; 
					}
				}
			} else if (flags & ES_FILE_WRITE_SHARED) {
				if ((file->flags & NODE_HAS_EXCLUSIVE_WRITER) || file->countWrite < 0) return ES_ERROR_FILE_IN_EXCLUSIVE_USE;
			}

			if (flags & (ES_FILE_WRITE_SHARED | ES_FILE_WRITE)) {
				if (!file->fileSystem->write) {
					return ES_ERROR_FILE_ON_READ_ONLY_VOLUME;
				}
			}

			if (flags & (ES_FILE_WRITE_SHARED | ES_FILE_WRITE)) file->countWrite++;
			if (flags & ES_FILE_READ) file->countWrite--;
			if (flags & ES_FILE_WRITE) __sync_fetch_and_or(&node->flags, NODE_HAS_EXCLUSIVE_WRITER);
		}

		NODE_INCREMENT_HANDLE_COUNT(node);

		// EsPrint("Open handle to %s (%d; %d).\n", node->directoryEntry->item.key.longKeyBytes, 
		// 		node->directoryEntry->item.key.longKey, node->handles, fs.totalHandleCount);
	}

	if (node->directoryEntry->type == ES_NODE_FILE && (flags & ES_NODE_PREVENT_RESIZE)) {
		// Modify blockResize with the resizeLock, to prevent a resize being in progress when blockResize becomes positive.
		FSFile *file = (FSFile *) node;
		KWriterLockTake(&file->resizeLock, K_LOCK_EXCLUSIVE);
		file->blockResize++;
		KWriterLockReturn(&file->resizeLock, K_LOCK_EXCLUSIVE);
	}

	return ES_SUCCESS;
}

void FSNodeFree(KNode *node) {
	FSDirectoryEntry *entry = node->directoryEntry;

	if (entry->node != node) {
		KernelPanic("FSNodeFree - FSDirectoryEntry node mismatch for node %x.\n", node);
	} else if (node->flags & NODE_IN_CACHE_LIST) {
		KernelPanic("FSNodeFree - Node %x is in the cache list.\n", node);
	}

	if (entry->type == ES_NODE_FILE) {
		CCSpaceDestroy(&((FSFile *) node)->cache);
	} else if (entry->type == ES_NODE_DIRECTORY) {
		if (((FSDirectory *) node)->entries.root) {
			KernelPanic("FSNodeFree - Directory %x still had items in its tree.\n", node);
		}
	}

	if (node->driverNode) {
		node->fileSystem->close(node);
	}

	// EsPrint("Freeing node with name '%s'...\n", entry->item.key.longKeyBytes, entry->item.key.longKey);

	bool deleted = node->flags & NODE_DELETED;

	KFileSystem *fileSystem = node->fileSystem;
	EsHeapFree(node, entry->type == ES_NODE_DIRECTORY ? sizeof(FSDirectory) : sizeof(FSFile), K_FIXED);

	if (!deleted) {
		KSpinlockAcquire(&fs.updateNodeHandles);
		MMObjectCacheInsert(&fileSystem->cachedDirectoryEntries, &entry->cacheItem);
		entry->node = nullptr;
		entry->removingNodeFromCache = false;
		KSpinlockRelease(&fs.updateNodeHandles);
	} else {
		// The node has been deleted, and we're about to deallocate the directory entry anyway.
		// See FSNodeCloseHandle.
	}
}

void FSDirectoryEntryFree(FSDirectoryEntry *entry) {
	if (entry->cacheItem.previous || entry->cacheItem.next) {
		KernelPanic("FSDirectoryEntryFree - Entry %x is in cache.\n", entry);
#ifdef TREE_VALIDATE
	} else if (entry->item.tree) {
		KernelPanic("FSDirectoryEntryFree - Entry %x is in parent's tree.\n", entry);
#endif
	}

	// EsPrint("Freeing directory entry with name '%s'...\n", entry->item.key.longKeyBytes, entry->item.key.longKey);

	if (entry->item.key.longKey != entry->inlineName) {
		EsHeapFree((void *) entry->item.key.longKey, entry->item.key.longKeyBytes, K_FIXED);
	}

	EsHeapFree(entry, 0, K_FIXED);
}

void FSNodeCloseHandle(KNode *node, uint32_t flags) {
	if (node->directoryEntry->type == ES_NODE_FILE && (flags & ES_NODE_PREVENT_RESIZE)) {
		FSFile *file = (FSFile *) node;
		KWriterLockTake(&file->resizeLock, K_LOCK_EXCLUSIVE);
		file->blockResize--;
		KWriterLockReturn(&file->resizeLock, K_LOCK_EXCLUSIVE);
	}

	// Don't use the node's writer lock for this.
	// It'd be unnecessarily require getting exclusive access.
	// There's not much to do, so just use a global spinlock.
	KSpinlockAcquire(&fs.updateNodeHandles);

	if (node->handles) {
		node->handles--;
		node->fileSystem->totalHandleCount--;
		fs.totalHandleCount--;

		// EsPrint("Close handle to %s (%d; %d).\n", node->directoryEntry->item.key.longKeyBytes, 
		// 		node->directoryEntry->item.key.longKey, node->handles, fs.totalHandleCount);
	} else {
		KernelPanic("FSNodeCloseHandle - Node %x had no handles.\n", node);
	}

	if (node->directoryEntry->type == ES_NODE_FILE) {
		FSFile *file = (FSFile *) node;

		if ((flags & (ES_FILE_WRITE_SHARED | ES_FILE_WRITE))) {
			if (file->countWrite <= 0) KernelPanic("FSNodeCloseHandle - Invalid countWrite on node %x.\n", node);
			file->countWrite--;
		}

		if ((flags & ES_FILE_READ)) {
			if (file->countWrite >= 0) KernelPanic("FSNodeCloseHandle - Invalid countWrite on node %x.\n", node);
			file->countWrite++;
		}

		if ((flags & ES_FILE_WRITE) && file->countWrite == 0) {
			if (~file->flags & NODE_HAS_EXCLUSIVE_WRITER) KernelPanic("FSNodeCloseHandle - Missing exclusive flag on node %x.\n", node);
			__sync_fetch_and_and(&node->flags, ~NODE_HAS_EXCLUSIVE_WRITER);
		}
	}

	bool deleted = (node->flags & NODE_DELETED) && !node->handles;
	bool unmounted = !node->fileSystem->totalHandleCount;
	bool hasEntries = node->directoryEntry->type == ES_NODE_DIRECTORY && ((FSDirectory *) node)->entryCount;
	if (unmounted && node->handles) KernelPanic("FSNodeCloseHandle - File system has no handles but this node %x has handles.\n", node);
	KFileSystem *fileSystem = node->fileSystem;

	if (!node->handles && !deleted && !hasEntries) {
		if (node->flags & NODE_IN_CACHE_LIST) KernelPanic("FSNodeCloseHandle - Node %x is already in the cache list.\n", node);
		MMObjectCacheInsert(&node->fileSystem->cachedNodes, &node->cacheItem);
		__sync_fetch_and_or(&node->flags, NODE_IN_CACHE_LIST);
		node = nullptr; // The node could be freed at any time after MMObjectCacheInsert.
	}

	KSpinlockRelease(&fs.updateNodeHandles);

	if (unmounted && !fileSystem->unmounting) {
		// All handles to all nodes in the file system have been closed.
		// Spawn a thread to unmount it.
		fileSystem->unmounting = true;
		__sync_fetch_and_add(&fs.fileSystemsUnmounting, 1);
		KThreadCreate("FSUnmount", FSUnmountFileSystem, (uintptr_t) fileSystem); // TODO What should happen if creating the thread fails?
	}

	if (deleted) {
		if (!node->directoryEntry->parent) KernelPanic("FSNodeCloseHandle - A root directory %x was deleted.\n", node);

		// The node has been deleted, and no handles remain.
		// When it was deleted, it should have been removed from its parent directory,
		// both on the file system and in the directory lookup structures.
		// So, we are free to deallocate the node.

		FSDirectoryEntry *entry = node->directoryEntry;
		FSNodeFree(node);
		FSDirectoryEntryFree(entry);
	} 
}

void ThreadRemove(Thread *thread) {
	KernelLog(LOG_INFO, "Scheduler", "remove thread", "Removing thread %d.\n", thread->id);

	// The last handle to the thread has been closed,
	// so we can finally deallocate the thread.

#ifdef ENABLE_POSIX_SUBSYSTEM
	if (thread->posixData) {
		if (thread->posixData->forkStack) {
			EsHeapFree(thread->posixData->forkStack, thread->posixData->forkStackSize, K_PAGED);
			CloseHandleToObject(thread->posixData->forkProcess, KERNEL_OBJECT_PROCESS);
		}

		EsHeapFree(thread->posixData, sizeof(POSIXThread), K_PAGED);
	}
#endif

	scheduler.threadPool.Remove(thread);
}

KMutex objectHandleCountChange;





bool MMCommit(uint64_t bytes, bool fixed) {
	if (bytes & (K_PAGE_SIZE - 1)) KernelPanic("MMCommit - Expected multiple of K_PAGE_SIZE bytes.\n");
	int64_t pagesNeeded = bytes / K_PAGE_SIZE;

	KMutexAcquire(&pmm.commitMutex);
	EsDefer(KMutexRelease(&pmm.commitMutex));

	if (pmm.commitLimit) {
		if (fixed) {
			if (pagesNeeded > pmm.commitFixedLimit - pmm.commitFixed) {
				KernelLog(LOG_ERROR, "Memory", "failed fixed commit", "Failed fixed commit %d pages (currently %d/%d).\n",
						pagesNeeded, pmm.commitFixed, pmm.commitFixedLimit);
				return false;
			}

			if (MM_AVAILABLE_PAGES() - pagesNeeded < MM_CRITICAL_AVAILABLE_PAGES_THRESHOLD && !GetCurrentThread()->isPageGenerator) {
				KernelLog(LOG_ERROR, "Memory", "failed fixed commit", 
						"Failed fixed commit %d as the available pages (%d, %d, %d) would cross the critical threshold, %d.\n.",
						pagesNeeded, pmm.countZeroedPages, pmm.countFreePages, pmm.countStandbyPages, MM_CRITICAL_AVAILABLE_PAGES_THRESHOLD);
				return false;
			}

			pmm.commitFixed += pagesNeeded;
		} else {
			if (pagesNeeded > MM_REMAINING_COMMIT() - (intptr_t) (GetCurrentThread()->isPageGenerator ? 0 : MM_CRITICAL_REMAINING_COMMIT_THRESHOLD)) {
				KernelLog(LOG_ERROR, "Memory", "failed pageable commit",
						"Failed pageable commit %d pages (currently %d/%d).\n",
						pagesNeeded, pmm.commitPageable + pmm.commitFixed, pmm.commitLimit);
				return false;
			}

			pmm.commitPageable += pagesNeeded;
		}

		if (MM_OBJECT_CACHE_SHOULD_TRIM()) {
			KEventSet(&pmm.trimObjectCaches, true);
		}
	} else {
		// We haven't started tracking commit counts yet.
	}

	KernelLog(LOG_VERBOSE, "Memory", "commit", "Commit %D%z. Now at %D.\n", bytes, fixed ? ", fixed" : "", (pmm.commitFixed + pmm.commitPageable) << K_PAGE_BITS);
		
	return true;
}

bool MMSharedResizeRegion(MMSharedRegion *region, size_t sizeBytes) {
	KMutexAcquire(&region->mutex);
	EsDefer(KMutexRelease(&region->mutex));

	sizeBytes = (sizeBytes + K_PAGE_SIZE - 1) & ~(K_PAGE_SIZE - 1);

	size_t pages = sizeBytes / K_PAGE_SIZE;
	size_t oldPages = region->sizeBytes / K_PAGE_SIZE;
	void *oldData = region->data;

	void *newData = EsHeapAllocate(pages * sizeof(void *), true, K_CORE);

	if (!newData && pages) {
		return false;
	}

	if (oldPages > pages) {
		MMDecommit(K_PAGE_SIZE * (oldPages - pages), true);
	} else if (pages > oldPages) {
		if (!MMCommit(K_PAGE_SIZE * (pages - oldPages), true)) {
			EsHeapFree(newData, pages * sizeof(void *), K_CORE);
			return false;
		}
	}

	region->sizeBytes = sizeBytes;
	region->data = newData; 

	// The old shared memory region was empty.
	if (!oldData) return true;

	if (oldPages > pages) {
		for (uintptr_t i = pages; i < oldPages; i++) {
			uintptr_t *addresses = (uintptr_t *) oldData;
			uintptr_t address = addresses[i];
			if (address & MM_SHARED_ENTRY_PRESENT) MMPhysicalFree(address);
		}
	}

	uintptr_t copy = oldPages > pages ? pages : oldPages;
	EsMemoryCopy(region->data, oldData, sizeof(void *) * copy);
	EsHeapFree(oldData, oldPages * sizeof(void *), K_CORE); 

	return true;
}

void MMSharedDestroyRegion(MMSharedRegion *region) {
	MMSharedResizeRegion(region, 0); // TODO Check leaks.
	EsHeapFree(region, 0, K_CORE);
}

MMSharedRegion *MMSharedCreateRegion(size_t sizeBytes, bool fixed = false, uintptr_t below = 0) {
	if (!sizeBytes) return nullptr;

	MMSharedRegion *region = (MMSharedRegion *) EsHeapAllocate(sizeof(MMSharedRegion), true, K_CORE);
	if (!region) return nullptr;
	region->handles = 1;

	if (!MMSharedResizeRegion(region, sizeBytes)) {
		EsHeapFree(region, 0, K_CORE);
		return nullptr;
	}

	if (fixed) {
		for (uintptr_t i = 0; i < region->sizeBytes >> K_PAGE_BITS; i++) {
			((uintptr_t *) region->data)[i] = MMPhysicalAllocate(MM_PHYSICAL_ALLOCATE_ZEROED, 1, 1, below) | MM_SHARED_ENTRY_PRESENT;
		}
	}

	return region;
}

struct EmbeddedWindow {
	void Destroy() {};
	void Close();
	void SetEmbedOwner(Process *process);

	Process *volatile owner;
	void *volatile apiWindow;
	volatile uint32_t handles;
	struct Window *container;
	EsObjectID id;
	bool closed;
};


struct EsPoint {
	int32_t x;
	int32_t y;
};

enum EsWindowStyle {
	ES_WINDOW_NORMAL,
	ES_WINDOW_CONTAINER,
	ES_WINDOW_MENU,
	ES_WINDOW_TIP,
	ES_WINDOW_PLAIN,
	ES_WINDOW_INSPECTOR,
};

struct EsPaintTarget {
	void *bits;
	uint32_t width, height, stride;
	bool fullAlpha, readOnly, fromBitmap, forWindowManager;
};

struct Surface : EsPaintTarget {
	bool Resize(size_t newResX, size_t newResY, uint32_t clearColor = 0, bool copyOldBits = false);
	void Copy(Surface *source, EsPoint destinationPoint, EsRectangle sourceRegion, bool addToModifiedRegion); 
	void Draw(Surface *source, EsRectangle destinationRegion, int sourceX, int sourceY, uint16_t alpha);
	void BlendWindow(Surface *source, EsPoint destinationPoint, EsRectangle sourceRegion, int material, uint8_t alpha, EsRectangle materialRegion);
	void Blur(EsRectangle region, EsRectangle clip);
	void SetBits(K_USER_BUFFER const void *bits, uintptr_t stride, EsRectangle region);
	void Scroll(EsRectangle region, ptrdiff_t delta, bool vertical);
	void CreateCursorShadow(Surface *source);

	EsRectangle modifiedRegion;
};

#define ES_GAME_CONTROLLER_MAX_COUNT (16)


struct Pipe {
#define PIPE_READER (1)
#define PIPE_WRITER (2)
#define PIPE_BUFFER_SIZE (K_PAGE_SIZE)
#define PIPE_CLOSED (0)

	volatile char buffer[PIPE_BUFFER_SIZE];
	volatile size_t writers, readers;
	volatile uintptr_t writePosition, readPosition, unreadData;
	KEvent canWrite, canRead;
	KMutex mutex;

	size_t Access(void *buffer, size_t bytes, bool write, bool userBlockRequest);
};


struct EsAnalogInput {
	uint8_t x, y, z;
};

struct EsGameControllerState {
	EsObjectID id; 
	uint8_t buttonCount, analogCount; // Number of buttons and analog inputs.
	uint8_t directionalPad; // Directions given from 0-7, starting at up, going clockwise. 15 indicates unpressed.
	uint32_t buttons; // Bitset of pressed buttons.
	EsAnalogInput analog[8];
};

struct WindowManager {
	void *CreateWindow(Process *process, void *apiWindow, EsWindowStyle style);
	void *CreateEmbeddedWindow(Process *process, void *apiWindow);
	Window *FindWindowAtPosition(int cursorX, int cursorY, EsObjectID exclude = 0);

	void Initialise();

	void MoveCursor(int64_t xMovement, int64_t yMovement);
	void ClickCursor(uint32_t buttons);
	void ScrollWheel(int32_t dx, int32_t dy);
	void PressKey(uint32_t scancode);

	void Redraw(EsPoint position, int width, int height, Window *except = nullptr, int startingAt = 0, bool addToModifiedRegion = true);

	bool ActivateWindow(Window *window); // Returns true if any menus were closed.
	void HideWindow(Window *window);
	Window *FindWindowToActivate(Window *excluding = nullptr);
	uintptr_t GetActivationZIndex();
	void ChangeWindowDepth(Window *window, bool alwaysRedraw, ptrdiff_t newZDepth);
	intptr_t FindWindowDepth(Window *window);
	bool CloseMenus(); // Returns true if any menus were closed.
	
	void StartEyedrop(uintptr_t object, Window *avoid, uint32_t cancelColor);
	void EndEyedrop(bool cancelled);

	bool initialised;

	// Windows:

	Array<Window *, K_FIXED> windows; // Sorted by z.
	Array<EmbeddedWindow *, K_FIXED> embeddedWindows;
	Window *pressedWindow, *activeWindow, *hoverWindow;
	KMutex mutex;
	KEvent windowsToCloseEvent;
	EsObjectID currentWindowID;
	size_t inspectorWindowCount;
	EsMessageType pressedWindowButton;

	// Cursor:

	int32_t cursorX, cursorY;
	int32_t cursorXPrecise, cursorYPrecise; // Scaled up by a factor of K_CURSOR_MOVEMENT_SCALE.
	uint32_t lastButtons;

	Surface cursorSurface, cursorSwap, cursorTemporary;
	int cursorImageOffsetX, cursorImageOffsetY;
	uintptr_t cursorID;
	bool cursorShadow;
	bool changedCursorImage;

	uint32_t cursorProperties; 

	// Keyboard:

	bool numlock;
	uint8_t leftModifiers, rightModifiers;
	uint16_t keysHeld, maximumKeysHeld /* cleared when all released */;
	uint8_t keysHeldBitSet[512 / 8];

	// Eyedropper:

	uintptr_t eyedropObject;
	bool eyedropping;
	Process *eyedropProcess;
	uint64_t eyedropAvoidID;
	uint32_t eyedropCancelColor;

	// Miscellaneous:

	EsRectangle workArea;

	// Devices:

	KMutex deviceMutex;

	Array<KDevice *, K_FIXED> hiDevices;

	EsGameControllerState gameControllers[ES_GAME_CONTROLLER_MAX_COUNT];
	size_t gameControllerCount;
	EsObjectID gameControllerID;

	// Flicker-free resizing:

#define RESIZE_FLICKER_TIMEOUT_MS (40)
#define RESIZE_SLOW_THRESHOLD (RESIZE_FLICKER_TIMEOUT_MS * 3 / 4)
	Window *resizeWindow;
	bool resizeReceivedBitsFromContainer;
	bool resizeReceivedBitsFromEmbed;
	uint64_t resizeStartTimeStampMs;
	EsRectangle resizeQueuedRectangle;
	bool resizeQueued;
	bool resizeSlow; // Set if the previous resize went past RESIZE_FLICKER_SLOW_THRESHOLD; 
			 // when set, the old surface bits are copied on resize, so that if the resize times out the result will be reasonable.
};

WindowManager windowManager;

struct Window {
	void Update(EsRectangle *region, bool addToModifiedRegion);
	bool UpdateDirect(K_USER_BUFFER void *bits, uintptr_t stride, EsRectangle region);
	void Destroy() {}; 
	void Close();
	bool Move(EsRectangle newBounds, uint32_t flags);
	void SetEmbed(EmbeddedWindow *window);
	bool IsVisible();
	void ResizeEmbed(); // Send a message to the embedded window telling it to resize.

	// State:
	EsWindowStyle style;
	EsRectangle solidOffsets, embedInsets;
	bool solid, noClickActivate, hidden, isMaximised, alwaysOnTop, hoveringOverEmbed, activationClick, noBringToFront;
	volatile bool closed;

	// Appearance:
	Surface surface;
	EsRectangle opaqueBounds, blurBounds;
	uint8_t alpha, material;

	// Owner and children:
	Process *owner;
	void *apiWindow;
	EmbeddedWindow *embed;
	volatile uint32_t handles;
	EsObjectID id;

	// Location:
	EsPoint position;
	size_t width, height;
};

struct NetTask {
	void (*callback)(NetTask *task, void *receivedData);
	struct NetInterface *interface;
	uint16_t index;
	int16_t error;
	uint8_t step;
	bool completed;
};


struct KMACAddress {
	uint8_t d[6];
};

struct EsAddress {
	union {
		struct {
			uint32_t ipv4;
			uint16_t port;
		};

		uint8_t d[20];
	};
};

struct NetTCPConnectionTask : NetTask {
	uint32_t sendUnacknowledged; // Points at the end of the data the server has acknowledged receiving from us.
	uint32_t sendNext; // Points at the end of data we've sent.
	uint32_t sendWindow; // The maximum distance sendNext can be past sendUnacknowledged.
	uint32_t receiveNext; // Points at the end of data we've acknowledged receiving from the server.
	uint16_t receiveWindow; // The maximum distance the server can sent data past receiveNext.

	uint32_t initialSend, initialReceive;
	uint32_t finSequence;
	uint32_t sendWL1;
	uint32_t sendWL2;

	KMACAddress destinationMAC;
};

struct NetConnection {
	NetTCPConnectionTask task;

	MMSharedRegion *bufferRegion;
	uint8_t *sendBuffer;
	uint8_t *receiveBuffer;
	size_t sendBufferBytes;
	size_t receiveBufferBytes;

	uintptr_t sendReadPointer; // The end of the data that we've sent to the server (possibly unacknolwedged).
	uintptr_t sendWritePointer; // The end of the data that the application has written for us to send.
	uintptr_t receiveWritePointer; // The end of the data that we've received from the server with no missing segments.
	uintptr_t receiveReadPointer; // The end of the data that the user has processed from the receive buffer.

	RangeSet receivedData;

	EsAddress address;
	KMutex mutex;

	volatile uintptr_t handles;
};

// @TODO: implement
NetConnection *NetConnectionOpen(EsAddress *address, size_t sendBufferBytes, size_t receiveBufferBytes, uint32_t flags)
{
    (void)address;
    (void)sendBufferBytes;
    (void)receiveBufferBytes;
    (void)flags;
    KernelPanic("Unimplemented");
    return nullptr;
}
void NetConnectionClose(NetConnection *connection)
{
    (void)connection;
    KernelPanic("Unimplemented");
}
void NetConnectionNotify(NetConnection *connection, uintptr_t sendWritePointer, uintptr_t receiveReadPointer)
{
    (void)connection;
    (void)sendWritePointer;
    (void)receiveReadPointer;
    KernelPanic("Unimplemented");
}
void NetConnectionDestroy(NetConnection *connection)
{
    (void)connection;
    KernelPanic("Unimplemented");
}

void ProcessRemove(Process *process);
void CloseHandleToObject(void *object, KernelObjectType type, uint32_t flags)
{
	switch (type) {
		case KERNEL_OBJECT_PROCESS: {
			Process *process = (Process *) object;
			uintptr_t previous = __sync_fetch_and_sub(&process->handles, 1);
			KernelLog(LOG_VERBOSE, "Scheduler", "close process handle", "Closed handle to process %d; %d handles remain.\n", process->id, process->handles);

			if (previous == 0) {
				KernelPanic("CloseHandleToProcess - All handles to process %x have been closed.\n", process);
			} else if (previous == 1) {
				ProcessRemove(process);
			}
		} break;

		case KERNEL_OBJECT_THREAD: {
			Thread *thread = (Thread *) object;
			uintptr_t previous = __sync_fetch_and_sub(&thread->handles, 1);

			if (previous == 0) {
				KernelPanic("CloseHandleToObject - All handles to thread %x have been closed.\n", thread);
			} else if (previous == 1) {
				ThreadRemove(thread);
			}
		} break;

		case KERNEL_OBJECT_NODE: {
			FSNodeCloseHandle((KNode *) object, flags);
		} break;

		case KERNEL_OBJECT_EVENT: {
			KEvent *event = (KEvent *) object;
			KMutexAcquire(&objectHandleCountChange);
			bool destroy = event->handles == 1;
			event->handles--;
			KMutexRelease(&objectHandleCountChange);

			if (destroy) {
				EsHeapFree(event, sizeof(KEvent), K_FIXED);
			}
		} break;

		case KERNEL_OBJECT_CONSTANT_BUFFER: {
			ConstantBuffer *buffer = (ConstantBuffer *) object;
			KMutexAcquire(&objectHandleCountChange);
			bool destroy = buffer->handles == 1;
			buffer->handles--;
			KMutexRelease(&objectHandleCountChange);

			if (destroy) {
				EsHeapFree(object, sizeof(ConstantBuffer) + buffer->bytes, buffer->isPaged ? K_PAGED : K_FIXED);
			}
		} break;

		case KERNEL_OBJECT_SHMEM: {
			MMSharedRegion *region = (MMSharedRegion *) object;
			KMutexAcquire(&region->mutex);
			bool destroy = region->handles == 1;
			region->handles--;
			KMutexRelease(&region->mutex);

			if (destroy) {
				MMSharedDestroyRegion(region);
			}
		} break;

		case KERNEL_OBJECT_WINDOW: {
			Window *window = (Window *) object;
			unsigned previous = __sync_fetch_and_sub(&window->handles, 1);
			if (!previous) KernelPanic("CloseHandleToObject - Window %x has no handles.\n", window);

			if (previous == 2) {
				KEventSet(&windowManager.windowsToCloseEvent, true /* maybe already set */);
			} else if (previous == 1) {
				window->Destroy();
			}
		} break;

		case KERNEL_OBJECT_EMBEDDED_WINDOW: {
			EmbeddedWindow *window = (EmbeddedWindow *) object;
			unsigned previous = __sync_fetch_and_sub(&window->handles, 1);
			if (!previous) KernelPanic("CloseHandleToObject - EmbeddedWindow %x has no handles.\n", window);

			if (previous == 2) {
				KEventSet(&windowManager.windowsToCloseEvent, true /* maybe already set */);
			} else if (previous == 1) {
				window->Destroy();
			}
		} break;

#ifdef ENABLE_POSIX_SUBSYSTEM
		case KERNEL_OBJECT_POSIX_FD: {
			POSIXFile *file = (POSIXFile *) object;
			KMutexAcquire(&file->mutex);
			file->handles--;
			bool destroy = !file->handles;
			KMutexRelease(&file->mutex);

			if (destroy) {
				if (file->type == POSIX_FILE_NORMAL || file->type == POSIX_FILE_DIRECTORY) CloseHandleToObject(file->node, KERNEL_OBJECT_NODE, file->openFlags);
				if (file->type == POSIX_FILE_PIPE) CloseHandleToObject(file->pipe, KERNEL_OBJECT_PIPE, file->openFlags);
				EsHeapFree(file->path, 0, K_FIXED);
				EsHeapFree(file->directoryBuffer, file->directoryBufferLength, K_PAGED);
				EsHeapFree(file, sizeof(POSIXFile), K_FIXED);
			}
		} break;
#endif

		case KERNEL_OBJECT_PIPE: {
			Pipe *pipe = (Pipe *) object;
			KMutexAcquire(&pipe->mutex);

			if (flags & PIPE_READER) {
				pipe->readers--;

				if (!pipe->readers) {
					// If there are no more readers, wake up any blocking writers.
					KEventSet(&pipe->canWrite, true);
				}
			} 
			
			if (flags & PIPE_WRITER) {
				pipe->writers--;

				if (!pipe->writers) {
					// If there are no more writers, wake up any blocking readers.
					KEventSet(&pipe->canRead, true);
				}
			} 

			bool destroy = pipe->readers == 0 && pipe->writers == 0;

			KMutexRelease(&pipe->mutex);

			if (destroy) {
				EsHeapFree(pipe, sizeof(Pipe), K_PAGED);
			}
		} break;

		case KERNEL_OBJECT_CONNECTION: {
			NetConnection *connection = (NetConnection *) object;
			unsigned previous = __sync_fetch_and_sub(&connection->handles, 1);
			if (!previous) KernelPanic("CloseHandleToObject - NetConnection %x has no handles.\n", connection);
			if (previous == 1) NetConnectionClose(connection);
		} break;

		case KERNEL_OBJECT_DEVICE: {
			KDeviceCloseHandle((KDevice *) object);
		} break;

		default: {
			KernelPanic("CloseHandleToObject - Cannot close object of type %x.\n", type);
		} break;
	}
}

void ProcessRemove(Process *process) {
	KernelLog(LOG_INFO, "Scheduler", "remove process", "Removing process %d.\n", process->id);

	if (process->executableNode) {
		// Close the handle to the executable node.
		CloseHandleToObject(process->executableNode, KERNEL_OBJECT_NODE, ES_FILE_READ);
		process->executableNode = nullptr;
	}

	// Destroy the process's handle table, if it hasn't already been destroyed.
	// For most processes, the handle table is destroyed when the last thread terminates.
	process->handleTable.Destroy();

	// Free all the remaining messages in the message queue.
	// This is done after closing all handles, since closing handles can generate messages.
	process->messageQueue.messages.Free();

	if (process->blockShutdown) {
		if (1 == __sync_fetch_and_sub(&scheduler.blockShutdownProcessCount, 1)) {
			// If this is the last process to exit, set the allProcessesTerminatedEvent.
			KEventSet(&scheduler.allProcessesTerminatedEvent);
		}
	}

	// Free the process.
	MMSpaceCloseReference(process->vmm);
	scheduler.processPool.Remove(process); 
}


bool OpenHandleToObject(void *object, KernelObjectType type, uint32_t flags = 0) {
    bool hadNoHandles = false, failed = false;

	switch (type) {
		case KERNEL_OBJECT_EVENT: {
			KMutexAcquire(&objectHandleCountChange);
			KEvent *event = (KEvent *) object;
			if (!event->handles) hadNoHandles = true;
			else event->handles++;
			KMutexRelease(&objectHandleCountChange);
		} break;

		case KERNEL_OBJECT_PROCESS: {
			hadNoHandles = 0 == __sync_fetch_and_add(&((Process *) object)->handles, 1);
		} break;

		case KERNEL_OBJECT_THREAD: {
			hadNoHandles = 0 == __sync_fetch_and_add(&((Thread *) object)->handles, 1);
		} break;

		case KERNEL_OBJECT_SHMEM: {
			MMSharedRegion *region = (MMSharedRegion *) object;
			KMutexAcquire(&region->mutex);
			if (!region->handles) hadNoHandles = true;
			else region->handles++;
			KMutexRelease(&region->mutex);
		} break;

		case KERNEL_OBJECT_WINDOW: {
			// NOTE The handle count of Window object is modified elsewhere.
			Window *window = (Window *) object;
			hadNoHandles = 0 == __sync_fetch_and_add(&window->handles, 1);
		} break;

		case KERNEL_OBJECT_EMBEDDED_WINDOW: {
			EmbeddedWindow *window = (EmbeddedWindow *) object;
			hadNoHandles = 0 == __sync_fetch_and_add(&window->handles, 1);
		} break;

		case KERNEL_OBJECT_CONSTANT_BUFFER: {
			ConstantBuffer *buffer = (ConstantBuffer *) object;
			KMutexAcquire(&objectHandleCountChange);
			if (!buffer->handles) hadNoHandles = true;
			else buffer->handles++;
			KMutexRelease(&objectHandleCountChange);
		} break;

#ifdef ENABLE_POSIX_SUBSYSTEM
		case KERNEL_OBJECT_POSIX_FD: {
			POSIXFile *file = (POSIXFile *) object;
			KMutexAcquire(&file->mutex);
			if (!file->handles) hadNoHandles = true;
			else file->handles++;
			KMutexRelease(&file->mutex);
		} break;
#endif

		case KERNEL_OBJECT_NODE: {
			failed = ES_SUCCESS != FSNodeOpenHandle((KNode *) object, flags, FS_NODE_OPEN_HANDLE_STANDARD);
		} break;

		case KERNEL_OBJECT_PIPE: {
			Pipe *pipe = (Pipe *) object;
			KMutexAcquire(&pipe->mutex);

			if (((flags & PIPE_READER) && !pipe->readers)
					|| ((flags & PIPE_WRITER) && !pipe->writers)) {
				hadNoHandles = true;
			} else {
				if (flags & PIPE_READER) {
					pipe->readers++;
				} 

				if (flags & PIPE_WRITER) {
					pipe->writers++;
				} 
			}

			KMutexRelease(&pipe->mutex);
		} break;

		case KERNEL_OBJECT_CONNECTION: {
			NetConnection *connection = (NetConnection *) object;
			hadNoHandles = 0 == __sync_fetch_and_add(&connection->handles, 1);
		} break;

		case KERNEL_OBJECT_DEVICE: {
			KDeviceOpenHandle((KDevice *) object);
		} break;

		default: {
			KernelPanic("OpenHandleToObject - Cannot open object of type %x.\n", type);
		} break;
	}

	if (hadNoHandles) {
		KernelPanic("OpenHandleToObject - Object %x of type %x had no handles.\n", object, type);
	}

	return !failed;
}



void MMUnreserve(MMSpace *space, MMRegion *remove, bool unmapPages, bool guardRegion = false) {
	// EsPrint("unreserve: %x, %x, %d, %d\n", remove->baseAddress, remove->flags, unmapPages, guardRegion);
	// EsDefer(EsPrint("unreserve complete\n"););

	KMutexAssertLocked(&space->reserveMutex);

	if (pmm.nextRegionToBalance == remove) {
		// If the balance thread paused while balancing this region,
		// switch to the next region.
		pmm.nextRegionToBalance = remove->itemNonGuard.nextItem ? remove->itemNonGuard.nextItem->thisItem : nullptr;
		pmm.balanceResumePosition = 0;
	}

	if (!remove) {
		KernelPanic("MMUnreserve - Region to remove was null.\n");
	}

	if (remove->flags & MM_REGION_NORMAL) {
		if (remove->data.normal.guardBefore) MMUnreserve(space, remove->data.normal.guardBefore, false, true);
		if (remove->data.normal.guardAfter)  MMUnreserve(space, remove->data.normal.guardAfter,  false, true);
	} else if ((remove->flags & MM_REGION_GUARD) && !guardRegion) {
		// You can't free a guard region!
		// TODO Error.
		KernelLog(LOG_ERROR, "Memory", "attempt to unreserve guard page", "MMUnreserve - Attempting to unreserve a guard page.\n");
		return;
	}

	if (remove->itemNonGuard.list && !guardRegion) {
		// EsPrint("Remove item non guard...\n");
		remove->itemNonGuard.RemoveFromList();
		// EsPrint("Removed.\n");
	}

	if (unmapPages) {
		MMArchUnmapPages(space, remove->baseAddress, remove->pageCount, ES_FLAGS_DEFAULT);
	}
	
	space->reserve += remove->pageCount;

	if (space == coreMMSpace) {
		remove->core.used = false;

		intptr_t remove1 = -1, remove2 = -1;

		for (uintptr_t i = 0; i < mmCoreRegionCount && (remove1 != -1 || remove2 != 1); i++) {
			MMRegion *r = mmCoreRegions + i;

			if (r->core.used) continue;
			if (r == remove) continue;

			if (r->baseAddress == remove->baseAddress + (remove->pageCount << K_PAGE_BITS)) {
				remove->pageCount += r->pageCount;
				remove1 = i;
			} else if (remove->baseAddress == r->baseAddress + (r->pageCount << K_PAGE_BITS)) { 
				remove->pageCount += r->pageCount;
				remove->baseAddress = r->baseAddress;
				remove2 = i;
			}
		}

		if (remove1 != -1) {
			mmCoreRegions[remove1] = mmCoreRegions[--mmCoreRegionCount];
			if ((uintptr_t) remove2 == mmCoreRegionCount) remove2 = remove1;
		}

		if (remove2 != -1) {
			mmCoreRegions[remove2] = mmCoreRegions[--mmCoreRegionCount];
		}
	} else {
		TreeRemove(&space->usedRegions, &remove->itemBase);
		uintptr_t address = remove->baseAddress;

		{
			AVLItem<MMRegion> *before = TreeFind(&space->freeRegionsBase, MakeShortKey(address), TREE_SEARCH_LARGEST_BELOW_OR_EQUAL);

			if (before && before->thisItem->baseAddress + before->thisItem->pageCount * K_PAGE_SIZE == remove->baseAddress) {
				remove->baseAddress = before->thisItem->baseAddress;
				remove->pageCount += before->thisItem->pageCount;
				TreeRemove(&space->freeRegionsBase, before);
				TreeRemove(&space->freeRegionsSize, &before->thisItem->itemSize);
				EsHeapFree(before->thisItem, sizeof(MMRegion), K_CORE);
			}
		}

		{
			AVLItem<MMRegion> *after = TreeFind(&space->freeRegionsBase, MakeShortKey(address), TREE_SEARCH_SMALLEST_ABOVE_OR_EQUAL);

			if (after && remove->baseAddress + remove->pageCount * K_PAGE_SIZE == after->thisItem->baseAddress) {
				remove->pageCount += after->thisItem->pageCount;
				TreeRemove(&space->freeRegionsBase, after);
				TreeRemove(&space->freeRegionsSize, &after->thisItem->itemSize);
				EsHeapFree(after->thisItem, sizeof(MMRegion), K_CORE);
			}
		}

		TreeInsert(&space->freeRegionsBase, &remove->itemBase, remove, MakeShortKey(remove->baseAddress));
		TreeInsert(&space->freeRegionsSize, &remove->itemSize, remove, MakeShortKey(remove->pageCount), AVL_DUPLICATE_KEYS_ALLOW);
	}
}

bool MMFree(MMSpace *space, void *address, size_t expectedSize, bool userOnly) {
	if (!space) space = kernelMMSpace;

	MMSharedRegion *sharedRegionToFree = nullptr;
	FSFile *nodeToFree = nullptr;
	uint64_t fileHandleFlags = 0;

	{
		KMutexAcquire(&space->reserveMutex);
		EsDefer(KMutexRelease(&space->reserveMutex));

		MMRegion *region = MMFindRegion(space, (uintptr_t) address);

		if (!region) {
			return false;
		}

		if (userOnly && (~region->flags & MM_REGION_USER)) {
			KernelLog(LOG_ERROR, "Memory", "attempt to free non-user region", 
					"MMFree - A user process is attempting to free a region %x that is not marked with MM_REGION_USER.\n", region);
			return false;
		}

		if (!KWriterLockTake(&region->data.pin, K_LOCK_EXCLUSIVE, true /* poll */)) {
			KernelLog(LOG_ERROR, "Memory", "attempt to free in use region", 
					"MMFree - Attempting to free a region %x that is currently in by a system call.\n", region);
			return false;
		}

		if (region->baseAddress != (uintptr_t) address && (~region->flags & MM_REGION_PHYSICAL /* physical region bases are not page aligned */)) {
			KernelLog(LOG_ERROR, "Memory", "incorrect base address", "MMFree - Passed the address %x to free region %x, which has baseAddress of %x.\n",
					address, region, region->baseAddress);
			return false;
		}

		if (expectedSize && (expectedSize + K_PAGE_SIZE - 1) / K_PAGE_SIZE != region->pageCount) {
			KernelLog(LOG_ERROR, "Memory", "incorrect free size", "MMFree - The region page count is %d, but the expected free size is %d.\n",
					region->pageCount, (expectedSize + K_PAGE_SIZE - 1) / K_PAGE_SIZE);
			return false;
		}

		bool unmapPages = true;

		if (region->flags & MM_REGION_NORMAL) {
			if (!MMDecommitRange(space, region, 0, region->pageCount)) {
				KernelPanic("MMFree - Could not decommit entire region %x (should not fail).\n", region);
			}

			if (region->data.normal.commitPageCount) {
				KernelPanic("MMFree - After decommiting range covering the entire region (%x), some pages were still commited.\n", region);
			}

			region->data.normal.commit.ranges.Free();
			unmapPages = false;
		} else if (region->flags & MM_REGION_SHARED) {
			sharedRegionToFree = region->data.shared.region;
		} else if (region->flags & MM_REGION_FILE) {
			MMArchUnmapPages(space, region->baseAddress, region->pageCount, MM_UNMAP_PAGES_FREE_COPIED | MM_UNMAP_PAGES_BALANCE_FILE);
			unmapPages = false;

			FSFile *node = region->data.file.node;
			EsFileOffset removeStart = RoundDown(region->data.file.offset, (EsFileOffset) K_PAGE_SIZE);
			EsFileOffset removeEnd = RoundUp(removeStart + (region->pageCount << K_PAGE_BITS) - region->data.file.zeroedBytes, (EsFileOffset) K_PAGE_SIZE);
			nodeToFree = node;
			fileHandleFlags = region->data.file.fileHandleFlags;

			KMutexAcquire(&node->cache.cachedSectionsMutex);
			CCSpaceUncover(&node->cache, removeStart, removeEnd);
			KMutexRelease(&node->cache.cachedSectionsMutex);

			if (region->flags & MM_REGION_COPY_ON_WRITE) {
				MMDecommit(region->pageCount << K_PAGE_BITS, false);
			}
		} else if (region->flags & MM_REGION_PHYSICAL) {
		} else if (region->flags & MM_REGION_GUARD) {
			KernelLog(LOG_ERROR, "Memory", "attempt to free guard region", "MMFree - Attempting to free a guard region!\n");
			return false;
		} else {
			KernelPanic("MMFree - Unsupported region type.\n");
		}

		MMUnreserve(space, region, unmapPages);
	}

	if (sharedRegionToFree) CloseHandleToObject(sharedRegionToFree, KERNEL_OBJECT_SHMEM);
	if (nodeToFree && fileHandleFlags) CloseHandleToObject(nodeToFree, KERNEL_OBJECT_NODE, fileHandleFlags);

	return true;
}


void ThreadKill(KAsyncTask *task) {
	Thread *thread = EsContainerOf(Thread, killAsyncTask, task);
	ThreadSetTemporaryAddressSpace(thread->process->vmm);

	KMutexAcquire(&scheduler.allThreadsMutex);
	scheduler.allThreads.Remove(&thread->allItem);
	KMutexRelease(&scheduler.allThreadsMutex);

	KMutexAcquire(&thread->process->threadsMutex);
	thread->process->threads.Remove(&thread->processItem);
	bool lastThread = thread->process->threads.count == 0;
	KMutexRelease(&thread->process->threadsMutex);

	KernelLog(LOG_INFO, "Scheduler", "killing thread", 
			"Killing thread (ID %d, %d remain in process %d) %x...\n", thread->id, thread->process->threads.count, thread->process->id, thread);

	if (lastThread) {
		ProcessKill(thread->process);
	}

	MMFree(kernelMMSpace, (void *) thread->kernelStackBase);
	if (thread->userStackBase) MMFree(thread->process->vmm, (void *) thread->userStackBase);

	KEventSet(&thread->killedEvent);

	// Close the handle that this thread owns of its owner process, and the handle it owns of itself.
	CloseHandleToObject(thread->process, KERNEL_OBJECT_PROCESS);
	CloseHandleToObject(thread, KERNEL_OBJECT_THREAD);
}


void KRegisterAsyncTask(KAsyncTask *task, KAsyncTaskCallback callback) {
	KSpinlockAcquire(&scheduler.asyncTaskSpinlock);

	if (!task->callback) {
		task->callback = callback;
		GetLocalStorage()->asyncTaskList.Insert(&task->item, false);
	}

	KSpinlockRelease(&scheduler.asyncTaskSpinlock);
}

void ThreadTerminate(Thread *thread) {
	// Overview:
	//	Set terminating true, and paused false.
	// 	Is this the current thread?
	// 		Mark as terminatable, then yield.
	// 	Else, is thread->terminating not set?
	// 		Set thread->terminating.
	//
	// 		Is this the current thread?
	// 			Mark as terminatable, then yield.
	// 		Else, are we executing user code?
	// 			If we aren't currently executing the thread, remove the thread from its scheduling queue and kill it.
	//		Else, is the user waiting on a mutex/event?
	//			If we aren't currently executing the thread, unblock the thread.
		
	KSpinlockAcquire(&scheduler.dispatchSpinlock);

	bool yield = false;

	if (thread->terminating) {
		KernelLog(LOG_INFO, "Scheduler", "thread already terminating", "Already terminating thread %d.\n", thread->id);
		if (thread == GetCurrentThread()) goto terminateThisThread;
		else goto done;
	}

	KernelLog(LOG_INFO, "Scheduler", "terminate thread", "Terminating thread %d...\n", thread->id);
	thread->terminating = true;
	thread->paused = false;

	if (thread == GetCurrentThread()) {
		terminateThisThread:;

		// Mark the thread as terminatable.
		thread->terminatableState = THREAD_TERMINATABLE;
		KSpinlockRelease(&scheduler.dispatchSpinlock);

		// We cannot return to the previous function as it expects to be killed.
		ProcessorFakeTimerInterrupt();
		KernelPanic("Scheduler::ThreadTerminate - ProcessorFakeTimerInterrupt returned.\n");
	} else {
		if (thread->terminatableState == THREAD_TERMINATABLE) {
			// We're in user code..

			if (thread->executing) {
				// The thread is executing, so the next time it tries to make a system call or
				// is pre-empted, it will be terminated.
			} else {
				if (thread->state != THREAD_ACTIVE) {
					KernelPanic("Scheduler::ThreadTerminate - Terminatable thread non-active.\n");
				}

				// The thread is terminatable and it isn't executing.
				// Remove it from its queue, and then remove the thread.
				thread->item.RemoveFromList();
				KRegisterAsyncTask(&thread->killAsyncTask, ThreadKill);
				yield = true;
			}
		} else if (thread->terminatableState == THREAD_USER_BLOCK_REQUEST) {
			// We're in the kernel, but because the user wanted to block on a mutex/event.

			if (thread->executing) {
				// The mutex and event waiting code is designed to recognise when a thread is in this state,
				// and exit to the system call handler immediately.
				// If the thread however is pre-empted while in a blocked state before this code can execute,
				// Scheduler::Yield will automatically force the thread to be active again.
			} else {
				// Unblock the thread.
				// See comment above.
				if (thread->state == THREAD_WAITING_MUTEX || thread->state == THREAD_WAITING_EVENT) {
					scheduler.UnblockThread(thread);
				}
			}
		} else {
			// The thread is executing kernel code.
			// Therefore, we can't simply terminate the thread.
			// The thread will set its state to THREAD_TERMINATABLE whenever it can be terminated.
		}
	}

	done:;

	KSpinlockRelease(&scheduler.dispatchSpinlock);
	if (yield) ProcessorFakeTimerInterrupt(); // Process the asynchronous task.
}


void KThreadTerminate() {
	ThreadTerminate(GetCurrentThread());
}

void MMSpaceOpenReference(MMSpace *space) {
	if (space == kernelMMSpace) {
		return;
	}

	if (space->referenceCount < 1) {
		KernelPanic("MMSpaceOpenReference - Space %x has invalid reference count.\n", space);
	}

	if (space->referenceCount >= K_MAX_PROCESSORS + 1) {
		KernelPanic("MMSpaceOpenReference - Space %x has too many references (expected a maximum of %d).\n", K_MAX_PROCESSORS + 1);
	}

	__sync_fetch_and_add(&space->referenceCount, 1);
}

void ThreadSetTemporaryAddressSpace(MMSpace *space) {
	KSpinlockAcquire(&scheduler.dispatchSpinlock);
	Thread *thread = GetCurrentThread();
	MMSpace *oldSpace = thread->temporaryAddressSpace ?: kernelMMSpace;
	thread->temporaryAddressSpace = space;
	MMSpace *newSpace = space ?: kernelMMSpace;
	MMSpaceOpenReference(newSpace);
	ProcessorSetAddressSpace(&newSpace->data);
	KSpinlockRelease(&scheduler.dispatchSpinlock);
	MMSpaceCloseReference(oldSpace);
}

void MMArchFreeVAS(MMSpace *space) {
    (void)space;
	// TODO.
	KernelPanic("Unimplemented!\n");
}

void MMSpaceDestroy(MMSpace *space) {
	LinkedItem<MMRegion> *item = space->usedRegionsNonGuard.firstItem;

	while (item) {
		MMRegion *region = item->thisItem;
		item = item->nextItem;
		MMFree(space, (void *) region->baseAddress);
	}

	while (true) {
		AVLItem<MMRegion> *item = TreeFind(&space->freeRegionsBase, MakeShortKey(0), TREE_SEARCH_SMALLEST_ABOVE_OR_EQUAL);
		if (!item) break;
		TreeRemove(&space->freeRegionsBase, &item->thisItem->itemBase);
		TreeRemove(&space->freeRegionsSize, &item->thisItem->itemSize);
		EsHeapFree(item->thisItem, sizeof(MMRegion), K_CORE);
	}

	MMArchFreeVAS(space);
}


void DesktopSendMessage(_EsMessageWithObject *message) {
    (void)message;
    return;
}

void ProcessKill(Process *process) {
	// This function should only be called by ThreadKill, when the last thread in the process exits.
	// There should be at least one remaining handle to the process here, owned by that thread.
	// It will be closed at the end of the ThreadKill function.

	if (!process->handles) {
		KernelPanic("ProcessKill - Process %x is on the allProcesses list but there are no handles to it.\n", process);
	}

	KernelLog(LOG_INFO, "Scheduler", "killing process", "Killing process (%d) %x...\n", process->id, process);

	__sync_fetch_and_sub(&scheduler.activeProcessCount, 1);

	// Remove the process from the list of processes.
	KMutexAcquire(&scheduler.allProcessesMutex);
	scheduler.allProcesses.Remove(&process->allItem);

	if (pmm.nextProcessToBalance == process) {
		// If the balance thread got interrupted while balancing this process,
		// start at the beginning of the next process.
		pmm.nextProcessToBalance = process->allItem.nextItem ? process->allItem.nextItem->thisItem : nullptr;
		pmm.nextRegionToBalance = nullptr;
		pmm.balanceResumePosition = 0;
	}

	KMutexRelease(&scheduler.allProcessesMutex);

	KSpinlockAcquire(&scheduler.dispatchSpinlock);
	process->allThreadsTerminated = true;
	bool setProcessKilledEvent = true;

#ifdef ENABLE_POSIX_SUBSYSTEM
	if (process->posixForking) {
		// If the process is from an incomplete vfork(),
		// then the parent process gets to set the killed event
		// and the exit status.
		setProcessKilledEvent = false;
	}
#endif

	KSpinlockRelease(&scheduler.dispatchSpinlock);

	if (setProcessKilledEvent) {
		// We can now also set the killed event on the process.
		KEventSet(&process->killedEvent, true);
	}

	// There are no threads left in this process.
	// We should destroy the handle table at this point.
	// Otherwise, the process might never be freed
	// because of a cyclic-dependency.
	process->handleTable.Destroy();

	// Destroy the virtual memory space.
	// Don't actually deallocate it yet though; that is done on an async task queued by ProcessRemove.
	// This must be destroyed after the handle table!
	MMSpaceDestroy(process->vmm); 

	// Tell Desktop the process has terminated.
	if (!scheduler.shutdown) {
		_EsMessageWithObject m;
		EsMemoryZero(&m, sizeof(m));
		m.message.type = ES_MSG_PROCESS_TERMINATED;
		m.message.crash.pid = process->id;
		DesktopSendMessage(&m);
	}
}

MMRegion *MMReserve(MMSpace *space, size_t bytes, unsigned flags, uintptr_t forcedAddress = 0, bool generateGuardPages = false) {
	// TODO Handling EsHeapAllocate failures.
    (void)generateGuardPages;
	
	MMRegion *outputRegion = nullptr;
	size_t pagesNeeded = ((bytes + K_PAGE_SIZE - 1) & ~(K_PAGE_SIZE - 1)) / K_PAGE_SIZE;

	if (!pagesNeeded) return nullptr;

	KMutexAssertLocked(&space->reserveMutex);

	if (space == coreMMSpace) {
		if (mmCoreRegionCount == MM_CORE_REGIONS_COUNT) {
			return nullptr;
		}

		if (forcedAddress) {
			KernelPanic("MMReserve - Using a forced address in coreMMSpace.\n");
		}

		{
			uintptr_t newRegionCount = mmCoreRegionCount + 1;
			uintptr_t commitPagesNeeded = newRegionCount * sizeof(MMRegion) / K_PAGE_SIZE + 1;

			while (mmCoreRegionArrayCommit < commitPagesNeeded) {
				if (!MMCommit(K_PAGE_SIZE, true)) return nullptr;
				mmCoreRegionArrayCommit++;
			}
		}

		for (uintptr_t i = 0; i < mmCoreRegionCount; i++) {
			MMRegion *region = mmCoreRegions + i;

			if (!region->core.used && region->pageCount >= pagesNeeded) {
				if (region->pageCount > pagesNeeded) {
					MMRegion *split = mmCoreRegions + mmCoreRegionCount++;
					EsMemoryCopy(split, region, sizeof(MMRegion));
					split->baseAddress += pagesNeeded * K_PAGE_SIZE;
					split->pageCount -= pagesNeeded;
				}

				region->core.used = true;
				region->pageCount = pagesNeeded;

				region->flags = flags;
				EsMemoryZero(&region->data, sizeof(region->data));
				outputRegion = region;
				goto done;
			}
		}
	} else if (forcedAddress) {
		AVLItem<MMRegion> *item;

		// EsPrint("reserve forced: %x\n", forcedAddress);

		// Check for a collision.
		item = TreeFind(&space->usedRegions, MakeShortKey(forcedAddress), TREE_SEARCH_EXACT);
		if (item) return nullptr;
		item = TreeFind(&space->usedRegions, MakeShortKey(forcedAddress), TREE_SEARCH_SMALLEST_ABOVE_OR_EQUAL);
		if (item && item->thisItem->baseAddress < forcedAddress + pagesNeeded * K_PAGE_SIZE) return nullptr;
		item = TreeFind(&space->usedRegions, MakeShortKey(forcedAddress + pagesNeeded * K_PAGE_SIZE - 1), TREE_SEARCH_LARGEST_BELOW_OR_EQUAL);
		if (item && item->thisItem->baseAddress + item->thisItem->pageCount * K_PAGE_SIZE > forcedAddress) return nullptr;
		item = TreeFind(&space->freeRegionsBase, MakeShortKey(forcedAddress), TREE_SEARCH_EXACT);
		if (item) return nullptr;
		item = TreeFind(&space->freeRegionsBase, MakeShortKey(forcedAddress), TREE_SEARCH_SMALLEST_ABOVE_OR_EQUAL);
		if (item && item->thisItem->baseAddress < forcedAddress + pagesNeeded * K_PAGE_SIZE) return nullptr;
		item = TreeFind(&space->freeRegionsBase, MakeShortKey(forcedAddress + pagesNeeded * K_PAGE_SIZE - 1), TREE_SEARCH_LARGEST_BELOW_OR_EQUAL);
		if (item && item->thisItem->baseAddress + item->thisItem->pageCount * K_PAGE_SIZE > forcedAddress) return nullptr;

		// EsPrint("(no collisions)\n");

		MMRegion *region = (MMRegion *) EsHeapAllocate(sizeof(MMRegion), true, K_CORE);
		region->baseAddress = forcedAddress;
		region->pageCount = pagesNeeded;
		region->flags = flags;
		TreeInsert(&space->usedRegions, &region->itemBase, region, MakeShortKey(region->baseAddress));

		EsMemoryZero(&region->data, sizeof(region->data));
		outputRegion = region;
	} else {
#ifdef GUARD_PAGES
		size_t guardPagesNeeded = generateGuardPages ? 2 : 0;
#else
		size_t guardPagesNeeded = 0;
#endif

		AVLItem<MMRegion> *item = TreeFind(&space->freeRegionsSize, MakeShortKey(pagesNeeded + guardPagesNeeded), TREE_SEARCH_SMALLEST_ABOVE_OR_EQUAL);

		if (!item) {
			goto done;
		}

		MMRegion *region = item->thisItem;
		TreeRemove(&space->freeRegionsBase, &region->itemBase);
		TreeRemove(&space->freeRegionsSize, &region->itemSize);

		if (region->pageCount > pagesNeeded + guardPagesNeeded) {
			MMRegion *split = (MMRegion *) EsHeapAllocate(sizeof(MMRegion), true, K_CORE);
			EsMemoryCopy(split, region, sizeof(MMRegion));

			split->baseAddress += (pagesNeeded + guardPagesNeeded) * K_PAGE_SIZE;
			split->pageCount -= (pagesNeeded + guardPagesNeeded);

			TreeInsert(&space->freeRegionsBase, &split->itemBase, split, MakeShortKey(split->baseAddress));
			TreeInsert(&space->freeRegionsSize, &split->itemSize, split, MakeShortKey(split->pageCount), AVL_DUPLICATE_KEYS_ALLOW);
		}

		EsMemoryZero(&region->data, sizeof(region->data));

		region->pageCount = pagesNeeded;
		region->flags = flags;

		if (guardPagesNeeded) {
			MMRegion *guardBefore = (MMRegion *) EsHeapAllocate(sizeof(MMRegion), true, K_CORE);
			MMRegion *guardAfter =  (MMRegion *) EsHeapAllocate(sizeof(MMRegion), true, K_CORE);

			EsMemoryCopy(guardBefore, region, sizeof(MMRegion));
			EsMemoryCopy(guardAfter,  region, sizeof(MMRegion));

			guardAfter->baseAddress += K_PAGE_SIZE * (pagesNeeded + 1);
			guardBefore->pageCount = guardAfter->pageCount = 1;
			guardBefore->flags     = guardAfter->flags     = MM_REGION_GUARD;

			region->baseAddress += K_PAGE_SIZE;
			region->data.normal.guardBefore = guardBefore;
			region->data.normal.guardAfter  = guardAfter;

			EsMemoryZero(&guardBefore->itemNonGuard, sizeof(guardBefore->itemNonGuard));
			EsMemoryZero(&guardAfter->itemNonGuard,  sizeof(guardAfter->itemNonGuard));

			TreeInsert(&space->usedRegions, &guardBefore->itemBase, guardBefore, MakeShortKey(guardBefore->baseAddress));
			TreeInsert(&space->usedRegions, &guardAfter ->itemBase, guardAfter,  MakeShortKey(guardAfter->baseAddress));

#if 0
			EsPrint("Guarded region: %x->%x/%x->%x/%x->%x\n", guardBefore->baseAddress, guardBefore->pageCount * K_PAGE_SIZE + guardBefore->baseAddress,
					region->baseAddress, region->pageCount * K_PAGE_SIZE + region->baseAddress,
					guardAfter->baseAddress, guardAfter->pageCount * K_PAGE_SIZE + guardAfter->baseAddress);
#endif
		}

		TreeInsert(&space->usedRegions, &region->itemBase, region, MakeShortKey(region->baseAddress));

		outputRegion = region;
		goto done;
	}

	done:;
	// EsPrint("reserve: %x -> %x\n", address, (uintptr_t) address + pagesNeeded * K_PAGE_SIZE);

	if (outputRegion) {
		// We've now got an address range for the region.
		// So we should commit the page tables that will be needed to map it.

		if (!MMArchCommitPageTables(space, outputRegion)) {
			// We couldn't commit the leading page tables.
			// So we'll have to unreserve the region.
			MMUnreserve(space, outputRegion, false);
			return nullptr;
		}

		if (space != coreMMSpace) {
			EsMemoryZero(&outputRegion->itemNonGuard, sizeof(outputRegion->itemNonGuard));
			outputRegion->itemNonGuard.thisItem = outputRegion;
			space->usedRegionsNonGuard.InsertEnd(&outputRegion->itemNonGuard); 
		}

		space->reserve += pagesNeeded;
	}

	// EsPrint("Reserve: %x->%x\n", outputRegion->baseAddress, outputRegion->pageCount * K_PAGE_SIZE + outputRegion->baseAddress);
	return outputRegion;
}

MMRegion *MMFindAndPinRegion(MMSpace *space, uintptr_t address, uintptr_t size) {
	if (address + size < address) {
		return nullptr;
	}

	KMutexAcquire(&space->reserveMutex);
	EsDefer(KMutexRelease(&space->reserveMutex));

	MMRegion *region = MMFindRegion(space, address);

	if (!region) {
		return nullptr;
	}

	if (region->baseAddress > address) {
		return nullptr;
	}

	if (region->baseAddress + region->pageCount * K_PAGE_SIZE < address + size) {
		return nullptr;
	}

	if (!KWriterLockTake(&region->data.pin, K_LOCK_SHARED, true /* poll */)) {
		return nullptr;
	}

	return region;
}


bool MMCommitRange(MMSpace *space, MMRegion *region, uintptr_t pageOffset, size_t pageCount) {
	KMutexAssertLocked(&space->reserveMutex);

	if (region->flags & MM_REGION_NO_COMMIT_TRACKING) {
		KernelPanic("MMCommitRange - Region does not support commit tracking.\n");
	}

	if (pageOffset >= region->pageCount || pageCount > region->pageCount - pageOffset) {
		KernelPanic("MMCommitRange - Invalid region offset and page count.\n");
	}

	if (~region->flags & MM_REGION_NORMAL) {
		KernelPanic("MMCommitRange - Cannot commit into non-normal region.\n");
	}

	intptr_t delta = 0;
	region->data.normal.commit.Set(pageOffset, pageOffset + pageCount, &delta, false);

	if (delta < 0) {
		KernelPanic("MMCommitRange - Invalid delta calculation adding %x, %x to %x.\n", pageOffset, pageCount, region);
	}

	if (delta == 0) {
		return true;
	}

	{
		if (!MMCommit(delta * K_PAGE_SIZE, region->flags & MM_REGION_FIXED)) {
			return false;
		}

		region->data.normal.commitPageCount += delta;
		space->commit += delta;

		if (region->data.normal.commitPageCount > region->pageCount) {
			KernelPanic("MMCommitRange - Invalid delta calculation increases region %x commit past page count.\n", region);
		}
	}

	if (!region->data.normal.commit.Set(pageOffset, pageOffset + pageCount, nullptr, true)) {
		MMDecommit(delta * K_PAGE_SIZE, region->flags & MM_REGION_FIXED);
		region->data.normal.commitPageCount -= delta;
		space->commit -= delta;
		return false;
	}

	if (region->flags & MM_REGION_FIXED) {
		for (uintptr_t i = pageOffset; i < pageOffset + pageCount; i++) {
			// TODO Don't call into MMHandlePageFault. I don't like MM_HANDLE_PAGE_FAULT_LOCK_ACQUIRED.

			if (!MMHandlePageFault(space, region->baseAddress + i * K_PAGE_SIZE, MM_HANDLE_PAGE_FAULT_LOCK_ACQUIRED)) {
				KernelPanic("MMCommitRange - Unable to fix pages.\n");
			}
		}
	}

	return true;
}

void *MMStandardAllocate(MMSpace *space, size_t bytes, uint32_t flags, void *baseAddress, bool commitAll)
{
	if (!space) space = kernelMMSpace;

	KMutexAcquire(&space->reserveMutex);
	EsDefer(KMutexRelease(&space->reserveMutex));

	MMRegion *region = MMReserve(space, bytes, flags | MM_REGION_NORMAL, (uintptr_t) baseAddress, true);
	if (!region) return nullptr;

	if (commitAll) {
		if (!MMCommitRange(space, region, 0, region->pageCount)) {
			MMUnreserve(space, region, false /* No pages have been mapped. */);
			return nullptr;
		}
	}

	return (void *) region->baseAddress;
}

void MMPhysicalInsertFreePagesStart() {}

void MMPhysicalInsertFreePagesEnd() {
	if (pmm.countFreePages > MM_ZERO_PAGE_THRESHOLD) {
		KEventSet(&pmm.zeroPageEvent, true);
	}

	MMUpdateAvailablePageCount(true);
}


#define CC_SECTION_BYTES                          (ClampIntptr(0, 1024L * 1024 * 1024, pmm.commitFixedLimit * K_PAGE_SIZE / 4))

inline intptr_t ClampIntptr(intptr_t low, intptr_t high, intptr_t integer) {
	if (integer < low) return low;
	if (integer > high) return high;
	return integer;
}

bool CCWriteBehindSection() {
	CCActiveSection *section = nullptr;
	KMutexAcquire(&activeSectionManager.mutex);

	if (activeSectionManager.modifiedList.count) {
		section = activeSectionManager.modifiedList.firstItem->thisItem;
		CCWriteSectionPrepare(section);
	}

	KMutexRelease(&activeSectionManager.mutex);

	if (section) {
		CCWriteSection(section);
		return true;
	} else {
		return false;
	}
}

void CCWriteBehindThread() {
	uintptr_t lastWriteMs = 0;

	while (true) {
#if 0
		KEventWait(&activeSectionManager.modifiedNonEmpty);

		if (MM_AVAILABLE_PAGES() > MM_LOW_AVAILABLE_PAGES_THRESHOLD && !scheduler.shutdown) {
			// If there are sufficient available pages, wait before we start writing sections.
			KEventWait(&pmm.availableLow, CC_WAIT_FOR_WRITE_BEHIND);
		}

		while (CCWriteBehindSection());
#else
		// Wait until the modified list is non-empty.
		KEventWait(&activeSectionManager.modifiedNonEmpty); 

		if (lastWriteMs < CC_WAIT_FOR_WRITE_BEHIND) {
			// Wait for a reason to want to write behind.
			// - The CC_WAIT_FOR_WRITE_BEHIND timer expires.
			// - The number of available page frames is low (pmm.availableLow).
			// - The system is shutting down and so the cache must be flushed (scheduler.allProcessesTerminatedEvent).
			// - The modified list is getting full (activeSectionManager.modifiedGettingFull).
			KTimer timer = {};
			KTimerSet(&timer, CC_WAIT_FOR_WRITE_BEHIND - lastWriteMs);
			KEvent *events[] = { &timer.event, &pmm.availableLow, &scheduler.allProcessesTerminatedEvent, &activeSectionManager.modifiedGettingFull };
			KEventWaitMultiple(events, sizeof(events) / sizeof(events[0]));
			KTimerRemove(&timer);
		}

		// Write back 1/CC_WRITE_BACK_DIVISORth of the modified list.
		lastWriteMs = scheduler.timeMs;
		KMutexAcquire(&activeSectionManager.mutex);
		uintptr_t writeCount = (activeSectionManager.modifiedList.count + CC_WRITE_BACK_DIVISOR - 1) / CC_WRITE_BACK_DIVISOR;
		KMutexRelease(&activeSectionManager.mutex);
		while (writeCount && CCWriteBehindSection()) writeCount--;
		lastWriteMs = scheduler.timeMs - lastWriteMs;
#endif
	}
}



void CCInitialise() {
	activeSectionManager.sectionCount = CC_SECTION_BYTES / CC_ACTIVE_SECTION_SIZE;
	activeSectionManager.sections = (CCActiveSection *) EsHeapAllocate(activeSectionManager.sectionCount * sizeof(CCActiveSection), true, K_FIXED);

	KMutexAcquire(&kernelMMSpace->reserveMutex);
	activeSectionManager.baseAddress = (uint8_t *) MMReserve(kernelMMSpace, activeSectionManager.sectionCount * CC_ACTIVE_SECTION_SIZE, MM_REGION_CACHE)->baseAddress;
	KMutexRelease(&kernelMMSpace->reserveMutex);

	for (uintptr_t i = 0; i < activeSectionManager.sectionCount; i++) {
		activeSectionManager.sections[i].listItem.thisItem = &activeSectionManager.sections[i];
		activeSectionManager.lruList.InsertEnd(&activeSectionManager.sections[i].listItem);
	}

	KernelLog(LOG_INFO, "Memory", "cache initialised", "MMInitialise - Active section manager initialised with a maximum of %d of entries.\n", 
			activeSectionManager.sectionCount);

	KEventSet(&activeSectionManager.modifiedNonFull);
	activeSectionManager.writeBackThread = ThreadSpawn("CCWriteBehind", (uintptr_t) CCWriteBehindThread, 0, ES_FLAGS_DEFAULT);
	activeSectionManager.writeBackThread->isPageGenerator = true;
}


void PMZero(uintptr_t *pages, size_t pageCount, bool contiguous) {
	KMutexAcquire(&pmm.pmManipulationLock);

	repeat:;
	size_t doCount = pageCount > PHYSICAL_MEMORY_MANIPULATION_REGION_PAGES ? PHYSICAL_MEMORY_MANIPULATION_REGION_PAGES : pageCount;
	pageCount -= doCount;

	{
		MMSpace *vas = coreMMSpace;
		void *region = pmm.pmManipulationRegion;

		for (uintptr_t i = 0; i < doCount; i++) {
			MMArchMapPage(vas, contiguous ? pages[0] + (i << K_PAGE_BITS) : pages[i], 
					(uintptr_t) region + K_PAGE_SIZE * i, MM_MAP_PAGE_OVERWRITE | MM_MAP_PAGE_NO_NEW_TABLES);
		}

		KSpinlockAcquire(&pmm.pmManipulationProcessorLock);

		for (uintptr_t i = 0; i < doCount; i++) {
			ProcessorInvalidatePage((uintptr_t) region + i * K_PAGE_SIZE);
		}

		EsMemoryZero(region, doCount * K_PAGE_SIZE);

		KSpinlockRelease(&pmm.pmManipulationProcessorLock);
	}

	if (pageCount) {
		if (!contiguous) pages += PHYSICAL_MEMORY_MANIPULATION_REGION_PAGES;
		goto repeat;
	}

	// if (pageNumbers) EsPrint("w%d\n", pmm.pmManipulationLock.blockedThreads.count);
	KMutexRelease(&pmm.pmManipulationLock);
}

alignas(K_PAGE_SIZE) uint8_t earlyZeroBuffer[K_PAGE_SIZE];

uintptr_t MMPhysicalAllocate(unsigned flags, uintptr_t count, uintptr_t align, uintptr_t below) {
	bool mutexAlreadyAcquired = flags & MM_PHYSICAL_ALLOCATE_LOCK_ACQUIRED;
	if (!mutexAlreadyAcquired) KMutexAcquire(&pmm.pageFrameMutex);
	else KMutexAssertLocked(&pmm.pageFrameMutex);
	EsDefer(if (!mutexAlreadyAcquired) KMutexRelease(&pmm.pageFrameMutex););

	intptr_t commitNow = count * K_PAGE_SIZE;

	if (flags & MM_PHYSICAL_ALLOCATE_COMMIT_NOW) {
		if (!MMCommit(commitNow, true)) return 0;
	} else commitNow = 0;

	bool simple = count == 1 && align == 1 && below == 0;

	if (!pmm.pageFrameDatabaseInitialised) {
		// Early page allocation before the page frame database is initialised.

		if (!simple) {
			KernelPanic("MMPhysicalAllocate - Non-simple allocation before initialisation of the page frame database.\n");
		}

		uintptr_t page = MMArchEarlyAllocatePage();

		if (flags & MM_PHYSICAL_ALLOCATE_ZEROED) {
			// TODO Hack!
			MMArchMapPage(coreMMSpace, page, (uintptr_t) earlyZeroBuffer, 
					MM_MAP_PAGE_OVERWRITE | MM_MAP_PAGE_NO_NEW_TABLES | MM_MAP_PAGE_FRAME_LOCK_ACQUIRED);
			EsMemoryZero(earlyZeroBuffer, K_PAGE_SIZE);
		}

		return page;
	} else if (!simple) {
		// Slow path.
		// TODO Use standby pages.

		uintptr_t pages = pmm.freeOrZeroedPageBitset.Get(count, align, below);
		if (pages == (uintptr_t) -1) goto fail;
		MMPhysicalActivatePages(pages, count, flags);
		uintptr_t address = pages << K_PAGE_BITS;
		if (flags & MM_PHYSICAL_ALLOCATE_ZEROED) PMZero(&address, count, true);
		return address;
	} else {
		uintptr_t page = 0;
		bool notZeroed = false;

		if (!page) page = pmm.firstZeroedPage;
		if (!page) page = pmm.firstFreePage, notZeroed = true;
		if (!page) page = pmm.lastStandbyPage, notZeroed = true;
		if (!page) goto fail;

		MMPageFrame *frame = pmm.pageFrames + page;

		if (frame->state == MMPageFrame::ACTIVE) {
			KernelPanic("MMPhysicalAllocate - Corrupt page frame database (2).\n");
		}

		if (frame->state == MMPageFrame::STANDBY) {
			// EsPrint("Clear RT %x\n", frame);

			if (*frame->cacheReference != ((page << K_PAGE_BITS) | MM_SHARED_ENTRY_PRESENT)) {
				KernelPanic("MMPhysicalAllocate - Corrupt shared reference back pointer in frame %x.\n", frame);
			}

			// Clear the entry in the CCCachedSection that referenced this standby frame.
			*frame->cacheReference = 0;

			// TODO If the CCCachedSection is empty, remove it from its CCSpace.
		} else {
			pmm.freeOrZeroedPageBitset.Take(page);
		}

		MMPhysicalActivatePages(page, 1, flags);

		// EsPrint("PAGE FRAME ALLOCATE: %x\n", page << K_PAGE_BITS);

		uintptr_t address = page << K_PAGE_BITS;
		if (notZeroed && (flags & MM_PHYSICAL_ALLOCATE_ZEROED)) PMZero(&address, 1, false);
		// if (!notZeroed) PMCheckZeroed(address);
		return address;
	}

	fail:;

	if (!(flags & MM_PHYSICAL_ALLOCATE_CAN_FAIL)) {
		EsPrint("Out of memory. Committed %d/%d fixed and %d pageable out of a maximum %d.\n", pmm.commitFixed, pmm.commitFixedLimit, pmm.commitPageable, pmm.commitLimit);
		KernelPanic("MMPhysicalAllocate - Out of memory.\n");
	}

	MMDecommit(commitNow, true);
	return 0;
}

void *MMMapPhysical(MMSpace *space, uintptr_t offset, size_t bytes, uint64_t caching) {
	if (!space) space = kernelMMSpace;

	uintptr_t offset2 = offset & (K_PAGE_SIZE - 1);
	offset -= offset2;
	if (offset2) bytes += K_PAGE_SIZE;

	MMRegion *region;

	{
		KMutexAcquire(&space->reserveMutex);
		EsDefer(KMutexRelease(&space->reserveMutex));

		region = MMReserve(space, bytes, MM_REGION_PHYSICAL | MM_REGION_FIXED | caching);
		if (!region) return nullptr;

		region->data.physical.offset = offset;
	}

	for (uintptr_t i = 0; i < region->pageCount; i++) {
		MMHandlePageFault(space, region->baseAddress + i * K_PAGE_SIZE, ES_FLAGS_DEFAULT);
	}

	return (uint8_t *) region->baseAddress + offset2;
}

bool MMPhysicalAllocateAndMap(size_t sizeBytes, size_t alignmentBytes, size_t maximumBits, bool zeroed, uint64_t caching, uint8_t **_virtualAddress, uintptr_t *_physicalAddress) {
	if (!sizeBytes) sizeBytes = 1;
	if (!alignmentBytes) alignmentBytes = 1;

	bool noBelow = false;

#ifdef ES_BITS_32
	if (!maximumBits || maximumBits >= 32) noBelow = true;
#endif

#ifdef ES_BITS_64
	if (!maximumBits || maximumBits >= 64) noBelow = true;
#endif

	uintptr_t sizePages = (sizeBytes + K_PAGE_SIZE - 1) >> K_PAGE_BITS;

	uintptr_t physicalAddress = MMPhysicalAllocate(MM_PHYSICAL_ALLOCATE_CAN_FAIL | MM_PHYSICAL_ALLOCATE_COMMIT_NOW, 
			sizePages, (alignmentBytes + K_PAGE_SIZE - 1) >> K_PAGE_BITS, 
			noBelow ? 0 : ((size_t) 1 << maximumBits));

	if (!physicalAddress) {
		return false;
	}

	void *virtualAddress = MMMapPhysical(kernelMMSpace, physicalAddress, sizeBytes, caching);

	if (!virtualAddress) {
		MMPhysicalFree(physicalAddress, false, sizePages);
		return false;
	}

	if (zeroed) {
		EsMemoryZero(virtualAddress, sizeBytes);
	}

	*_virtualAddress = (uint8_t *) virtualAddress;
	*_physicalAddress = physicalAddress;
	return true;
}

void PMCopy(uintptr_t page, void *_source, size_t pageCount) {
	uint8_t *source = (uint8_t *) _source;
	KMutexAcquire(&pmm.pmManipulationLock);

	repeat:;
	size_t doCount = pageCount > PHYSICAL_MEMORY_MANIPULATION_REGION_PAGES ? PHYSICAL_MEMORY_MANIPULATION_REGION_PAGES : pageCount;
	pageCount -= doCount;

	{
		MMSpace *vas = coreMMSpace;
		void *region = pmm.pmManipulationRegion;

		for (uintptr_t i = 0; i < doCount; i++) {
			MMArchMapPage(vas, page + K_PAGE_SIZE * i, (uintptr_t) region + K_PAGE_SIZE * i, 
					MM_MAP_PAGE_OVERWRITE | MM_MAP_PAGE_NO_NEW_TABLES);
		}

		KSpinlockAcquire(&pmm.pmManipulationProcessorLock);

		for (uintptr_t i = 0; i < doCount; i++) {
			ProcessorInvalidatePage((uintptr_t) region + i * K_PAGE_SIZE);
		}

		EsMemoryCopy(region, source, doCount * K_PAGE_SIZE);

		KSpinlockRelease(&pmm.pmManipulationProcessorLock);
	}

	if (pageCount) {
		page += PHYSICAL_MEMORY_MANIPULATION_REGION_PAGES * K_PAGE_SIZE;
		source += PHYSICAL_MEMORY_MANIPULATION_REGION_PAGES * K_PAGE_SIZE;
		goto repeat;
	}

	KMutexRelease(&pmm.pmManipulationLock);
}

void MMPhysicalInsertZeroedPage(uintptr_t page) {
	if (GetCurrentThread() != pmm.zeroPageThread) {
		KernelPanic("MMPhysicalInsertZeroedPage - Inserting a zeroed page not on the MMZeroPageThread.\n");
	}

	MMPageFrame *frame = pmm.pageFrames + page;
	frame->state = MMPageFrame::ZEROED;

	{
		frame->list.next = pmm.firstZeroedPage;
		frame->list.previous = &pmm.firstZeroedPage;
		if (pmm.firstZeroedPage) pmm.pageFrames[pmm.firstZeroedPage].list.previous = &frame->list.next;
		pmm.firstZeroedPage = page;
	}

	pmm.countZeroedPages++;
	pmm.freeOrZeroedPageBitset.Put(page);

	MMUpdateAvailablePageCount(true);
}

void MMZeroPageThread() {
	while (true) {
		KEventWait(&pmm.zeroPageEvent);
		KEventWait(&pmm.availableNotCritical);

		bool done = false;

		while (!done) {
			uintptr_t pages[PHYSICAL_MEMORY_MANIPULATION_REGION_PAGES]; 
			int i = 0;

			{
				KMutexAcquire(&pmm.pageFrameMutex);
				EsDefer(KMutexRelease(&pmm.pageFrameMutex));

				for (; i < PHYSICAL_MEMORY_MANIPULATION_REGION_PAGES; i++) {
					if (pmm.firstFreePage) {
						pages[i] = pmm.firstFreePage;
						MMPhysicalActivatePages(pages[i], 1, ES_FLAGS_DEFAULT);
					} else {
						done = true;
						break;
					}

					MMPageFrame *frame = pmm.pageFrames + pages[i];
					frame->state = MMPageFrame::ACTIVE;
					pmm.freeOrZeroedPageBitset.Take(pages[i]);
				}
			}

			for (int j = 0; j < i; j++) pages[j] <<= K_PAGE_BITS;
			if (i) PMZero(pages, i, false);

			KMutexAcquire(&pmm.pageFrameMutex);
			pmm.countActivePages -= i;

			while (i--) {
				MMPhysicalInsertZeroedPage(pages[i] >> K_PAGE_BITS);
			}

			KMutexRelease(&pmm.pageFrameMutex);
		}
	}
}

void MMObjectCacheTrimThread() {
	MMObjectCache *cache = nullptr;

	while (true) {
		while (!MM_OBJECT_CACHE_SHOULD_TRIM()) {
			KEventReset(&pmm.trimObjectCaches);
			KEventWait(&pmm.trimObjectCaches);
		}

		KMutexAcquire(&pmm.objectCacheListMutex);

		// TODO Is there a faster way to find the next cache?
		// This needs to work with multiple producers and consumers.
		// And I don't want to put the caches in an array, because then registering a cache could fail.

		MMObjectCache *previousCache = cache;
		cache = nullptr;

		LinkedItem<MMObjectCache> *item = pmm.objectCacheList.firstItem;

		while (item) {
			if (item->thisItem == previousCache && item->nextItem) {
				cache = item->nextItem->thisItem;
				break;
			}

			item = item->nextItem;
		}

		if (!cache && pmm.objectCacheList.firstItem) {
			cache = pmm.objectCacheList.firstItem->thisItem;
		}

		if (cache) {
			KWriterLockTake(&cache->trimLock, K_LOCK_SHARED);
		}
		
		KMutexRelease(&pmm.objectCacheListMutex);

		if (!cache) {
			continue;
		}

		for (uintptr_t i = 0; i < MM_OBJECT_CACHE_TRIM_GROUP_COUNT; i++) {
			if (!cache->trim(cache)) {
				break;
			}
		}

		KWriterLockReturn(&cache->trimLock, K_LOCK_SHARED);
	}
}

void MMBalanceThread() {
	size_t targetAvailablePages = 0;

	while (true) {
#if 1
		if (MM_AVAILABLE_PAGES() >= targetAvailablePages) {
			// Wait for there to be a low number of available pages.
			KEventWait(&pmm.availableLow);
			targetAvailablePages = MM_LOW_AVAILABLE_PAGES_THRESHOLD + MM_PAGES_TO_FIND_BALANCE;
		}
#else
		// Test the balance thread works correctly by running it constantly.
		targetAvailablePages = MM_AVAILABLE_PAGES() * 2;
#endif

		// EsPrint("--> Balance!\n");

		// Find a process to balance.
		
		KMutexAcquire(&scheduler.allProcessesMutex);
		Process *process = pmm.nextProcessToBalance ?: scheduler.allProcesses.firstItem->thisItem;
		pmm.nextProcessToBalance = process->allItem.nextItem ? process->allItem.nextItem->thisItem : nullptr;
		OpenHandleToObject(process, KERNEL_OBJECT_PROCESS, ES_FLAGS_DEFAULT);
		KMutexRelease(&scheduler.allProcessesMutex);

		// For every memory region...

		MMSpace *space = process->vmm;
		ThreadSetTemporaryAddressSpace(space);
		KMutexAcquire(&space->reserveMutex);
		LinkedItem<MMRegion> *item = pmm.nextRegionToBalance ? &pmm.nextRegionToBalance->itemNonGuard : space->usedRegionsNonGuard.firstItem;

		while (item && MM_AVAILABLE_PAGES() < targetAvailablePages) {
			MMRegion *region = item->thisItem;

			// EsPrint("process = %x, region = %x, offset = %x\n", process, region, pmm.balanceResumePosition);

			KMutexAcquire(&region->data.mapMutex);

			bool canResume = false;

			if (region->flags & MM_REGION_FILE) {
				canResume = true;
				MMArchUnmapPages(space, 
						region->baseAddress, region->pageCount, 
						MM_UNMAP_PAGES_BALANCE_FILE, 
						targetAvailablePages - MM_AVAILABLE_PAGES(), &pmm.balanceResumePosition);
			} else if (region->flags & MM_REGION_CACHE) {
				// TODO Trim the cache's active sections and cached sections lists.

				KMutexAcquire(&activeSectionManager.mutex);

				LinkedItem<CCActiveSection> *item = activeSectionManager.lruList.firstItem;

				while (item && MM_AVAILABLE_PAGES() < targetAvailablePages) {
					CCActiveSection *section = item->thisItem;
					if (section->cache && section->referencedPageCount) CCDereferenceActiveSection(section);
					item = item->nextItem;
				}

				KMutexRelease(&activeSectionManager.mutex);
			}

			KMutexRelease(&region->data.mapMutex);

			if (MM_AVAILABLE_PAGES() >= targetAvailablePages && canResume) {
				// We have enough to pause.
				break;
			}

			item = item->nextItem;
			pmm.balanceResumePosition = 0;
		}

		if (item) {
			// Continue with this region next time.
			pmm.nextRegionToBalance = item->thisItem;
			pmm.nextProcessToBalance = process;
			// EsPrint("will resume at %x\n", pmm.balanceResumePosition);
		} else {
			// Go to the next process.
			pmm.nextRegionToBalance = nullptr;
			pmm.balanceResumePosition = 0;
		}

		KMutexRelease(&space->reserveMutex);
		ThreadSetTemporaryAddressSpace(nullptr);
		CloseHandleToObject(process, KERNEL_OBJECT_PROCESS);
	}
}

MMSharedRegion *MMSharedOpenRegion(const char *name, size_t nameBytes, size_t fallbackSizeBytes, uint64_t flags) {
	if (nameBytes > ES_SHARED_MEMORY_NAME_MAX_LENGTH) return nullptr;

	KMutexAcquire(&mmNamedSharedRegionsMutex);
	EsDefer(KMutexRelease(&mmNamedSharedRegionsMutex));

	LinkedItem<MMSharedRegion> *item = mmNamedSharedRegions.firstItem;

	while (item) {
		MMSharedRegion *region = item->thisItem;

		if (EsCStringLength(region->cName) == nameBytes && 0 == EsMemoryCompare(region->cName, name, nameBytes)) {
			if (flags & ES_MEMORY_OPEN_FAIL_IF_FOUND) return nullptr;
			OpenHandleToObject(region, KERNEL_OBJECT_SHMEM);
			return region;
		}

		item = item->nextItem;
	}

	if (flags & ES_MEMORY_OPEN_FAIL_IF_NOT_FOUND) return nullptr;

	MMSharedRegion *region = MMSharedCreateRegion(fallbackSizeBytes);
	if (!region) return nullptr;
	EsMemoryCopy(region->cName, name, nameBytes);

	region->namedItem.thisItem = region;
	mmNamedSharedRegions.InsertEnd(&region->namedItem);

	return region;
}

void *MMMapShared(MMSpace *space, MMSharedRegion *sharedRegion, uintptr_t offset, size_t bytes, uint32_t additionalFlags = ES_FLAGS_DEFAULT, void *baseAddress = nullptr) {
	MMRegion *region;
	OpenHandleToObject(sharedRegion, KERNEL_OBJECT_SHMEM);

	KMutexAcquire(&space->reserveMutex);
	EsDefer(KMutexRelease(&space->reserveMutex));

	if (offset & (K_PAGE_SIZE - 1)) bytes += offset & (K_PAGE_SIZE - 1); 
	if (sharedRegion->sizeBytes <= offset) goto fail;
	if (sharedRegion->sizeBytes < offset + bytes) goto fail;

	region = MMReserve(space, bytes, MM_REGION_SHARED | additionalFlags, (uintptr_t) baseAddress);
	if (!region) goto fail;

	if (!(region->flags & MM_REGION_SHARED)) KernelPanic("MMMapShared - Cannot commit into non-shared region.\n");
	if (region->data.shared.region) KernelPanic("MMMapShared - A shared region has already been bound.\n");

	region->data.shared.region = sharedRegion;
	region->data.shared.offset = offset & ~(K_PAGE_SIZE - 1);

	return (uint8_t *) region->baseAddress + (offset & (K_PAGE_SIZE - 1));

	fail:;
	CloseHandleToObject(sharedRegion, KERNEL_OBJECT_SHMEM);
	return nullptr;
}

bool MMFaultRange(uintptr_t address, uintptr_t byteCount, uint32_t flags = ES_FLAGS_DEFAULT) {
	uintptr_t start = address & ~(K_PAGE_SIZE - 1);
	uintptr_t end = (address + byteCount - 1) & ~(K_PAGE_SIZE - 1);

	for (uintptr_t page = start; page <= end; page += K_PAGE_SIZE) {
		if (!MMArchHandlePageFault(page, flags)) {
			return false;
		}
	}

	return true;
}

void MMInitialise() {
	{
		// Initialise coreMMSpace and kernelMMSpace.

		mmCoreRegions[0].core.used = false;
		mmCoreRegionCount = 1;
		MMArchInitialise();

		MMRegion *region = (MMRegion *) EsHeapAllocate(sizeof(MMRegion), true, K_CORE);
		region->baseAddress = MM_KERNEL_SPACE_START; 
		region->pageCount = MM_KERNEL_SPACE_SIZE / K_PAGE_SIZE;
		TreeInsert(&kernelMMSpace->freeRegionsBase, &region->itemBase, region, MakeShortKey(region->baseAddress));
		TreeInsert(&kernelMMSpace->freeRegionsSize, &region->itemSize, region, MakeShortKey(region->pageCount), AVL_DUPLICATE_KEYS_ALLOW);
	}



	{
		// Initialise physical memory management.

		KMutexAcquire(&kernelMMSpace->reserveMutex);
		pmm.pmManipulationRegion = (void *) MMReserve(kernelMMSpace, PHYSICAL_MEMORY_MANIPULATION_REGION_PAGES * K_PAGE_SIZE, ES_FLAGS_DEFAULT)->baseAddress; 
		KMutexRelease(&kernelMMSpace->reserveMutex);

		// 1 extra for the top page, then round up so the page bitset is byte-aligned.
		uintptr_t pageFrameDatabaseCount = (MMArchGetPhysicalMemoryHighest() + (K_PAGE_SIZE << 3)) >> K_PAGE_BITS;
		pmm.pageFrames = (MMPageFrame *) MMStandardAllocate(kernelMMSpace, pageFrameDatabaseCount * sizeof(MMPageFrame), MM_REGION_FIXED);
		pmm.freeOrZeroedPageBitset.Initialise(pageFrameDatabaseCount, true);
		pmm.pageFrameDatabaseCount = pageFrameDatabaseCount; // Only set this after the database is ready, or it may be accessed mid-allocation!

		MMPhysicalInsertFreePagesStart();
		uint64_t commitLimit = MMArchPopulatePageFrameDatabase();
		MMPhysicalInsertFreePagesEnd();
		pmm.pageFrameDatabaseInitialised = true;

		pmm.commitLimit = pmm.commitFixedLimit = commitLimit;
		KernelLog(LOG_INFO, "Memory", "pmm initialised", "MMInitialise - PMM initialised with a fixed commit limit of %d pages.\n", pmm.commitLimit);
	}

	{
		// Initialise file cache.

		CCInitialise();
	}

	{
		// Create threads.

		pmm.zeroPageEvent.autoReset = true;
		MMCommit(PHYSICAL_MEMORY_MANIPULATION_REGION_PAGES * K_PAGE_SIZE, true);
		pmm.zeroPageThread = ThreadSpawn("MMZero", (uintptr_t) MMZeroPageThread, 0, SPAWN_THREAD_LOW_PRIORITY);
		ThreadSpawn("MMBalance", (uintptr_t) MMBalanceThread, 0, ES_FLAGS_DEFAULT)->isPageGenerator = true;
		ThreadSpawn("MMObjTrim", (uintptr_t) MMObjectCacheTrimThread, 0, ES_FLAGS_DEFAULT);
	}

	{
		// Create the global data shared region.

		MMSharedRegion *region = MMSharedOpenRegion(EsLiteral("Desktop.Global"), sizeof(GlobalData), ES_FLAGS_DEFAULT); 
		globalData = (GlobalData *) MMMapShared(kernelMMSpace, region, 0, sizeof(GlobalData), MM_REGION_FIXED);
		MMFaultRange((uintptr_t) globalData, sizeof(GlobalData), MM_HANDLE_PAGE_FAULT_FOR_SUPERVISOR);
	}
}
void MMSpaceCloseReference(MMSpace *space) {
	if (space == kernelMMSpace) {
		return;
	}

	if (space->referenceCount < 1) {
		KernelPanic("MMSpaceCloseReference - Space %x has invalid reference count.\n", space);
	}

	if (__sync_fetch_and_sub(&space->referenceCount, 1) > 1) {
		return;
	}

	KRegisterAsyncTask(&space->removeAsyncTask, [] (KAsyncTask *task) { 
		MMSpace *space = EsContainerOf(MMSpace, removeAsyncTask, task);
		MMArchFinalizeVAS(space);
		scheduler.mmSpacePool.Remove(space);
	});
}

#define SIGNATURE_RSDP (0x2052545020445352)
#define SIGNATURE_RSDT (0x54445352)
#define SIGNATURE_XSDT (0x54445358)
#define SIGNATURE_MADT (0x43495041)
#define SIGNATURE_FADT (0x50434146)
#define SIGNATURE_HPET (0x54455048)


struct RootSystemDescriptorPointer {
	uint64_t signature;
	uint8_t checksum;
	char OEMID[6];
	uint8_t revision;
	uint32_t rsdtAddress;
	uint32_t length;
	uint64_t xsdtAddress;
	uint8_t extendedChecksum;
	uint8_t reserved[3];
};

struct _ACPIDescriptorTable {
#define ACPI_DESCRIPTOR_TABLE_HEADER_LENGTH (36)
	uint32_t signature;
	uint32_t length;
	uint64_t id;
	uint64_t tableID;
	uint32_t oemRevision;
	uint32_t creatorID;
	uint32_t creatorRevision;
};
typedef _ACPIDescriptorTable ACPIDescriptorTable __attribute__((aligned(1)));

struct _MultipleAPICDescriptionTable {
	uint32_t lapicAddress; 
	uint32_t flags;
};
typedef _MultipleAPICDescriptionTable MultipleAPICDescriptionTable __attribute__((aligned(1)));

struct ArchCPU {
	uint8_t processorID, kernelProcessorID;
	uint8_t apicID;
	bool bootProcessor;
	uint64_t_unaligned *kernelStack;
	CPULocalStorage *local;
};

struct ACPIIoApic {
	uint8_t id;
	uint32_t volatile *address;
	uint32_t gsiBase;
};

struct ACPIInterruptOverride {
	uint8_t sourceIRQ;
	uint32_t gsiNumber;
	bool activeLow, levelTriggered;
};

struct ACPILapicNMI {
	uint8_t processor; // 0xFF for all processors
	uint8_t lintIndex;
	bool activeLow, levelTriggered;
};

struct ACPI {
	size_t processorCount;
	size_t ioapicCount;
	size_t interruptOverrideCount;
	size_t lapicNMICount;

	ArchCPU processors[256];
	ACPIIoApic ioApics[16];
	ACPIInterruptOverride interruptOverrides[256];
	ACPILapicNMI lapicNMIs[32];

	RootSystemDescriptorPointer *rsdp;
	ACPIDescriptorTable *madt;

	volatile uint32_t *lapicAddress;
	size_t lapicTicksPerMs;

	bool ps2ControllerUnavailable;
	bool vgaControllerUnavailable;
	uint8_t centuryRegisterIndex;

	volatile uint64_t *hpetBaseAddress;
	uint64_t hpetPeriod; // 10^-15 seconds.

	KDevice *computer;
};

ACPI acpi;

uint32_t ACPIIoApicReadRegister(ACPIIoApic *apic, uint32_t reg) {
	apic->address[0] = reg; 
	return apic->address[4];
}

void ACPIIoApicWriteRegister(ACPIIoApic *apic, uint32_t reg, uint32_t value) {
	apic->address[0] = reg; 
	apic->address[4] = value;
}
void ACPICheckTable(const ACPIDescriptorTable *table) {
	if (!EsMemorySumBytes((uint8_t *) table, table->length)) {
		return;
	}

	KernelPanic("ACPICheckTable - ACPI table with signature %s had invalid checksum: "
			"length: %D, ID = %s, table = %s, OEM revision = %d, creator = %s, creator revision = %d.\n",
			4, &table->signature, table->length, 8, &table->id, 8, &table->tableID, 
			table->oemRevision, 4, &table->creatorID, table->creatorRevision);
}




void *ACPIMapPhysicalMemory(uintptr_t physicalAddress, size_t length) {
	return MMMapPhysical(kernelMMSpace, physicalAddress, length, MM_REGION_NOT_CACHEABLE);
}



void *ACPIGetRSDP() {
	return acpi.rsdp;
}

uint8_t ACPIGetCenturyRegisterIndex() {
	return acpi.centuryRegisterIndex;
}

uintptr_t GetBootloaderInformationOffset();


uintptr_t ArchFindRootSystemDescriptorPointer() {
	uint64_t uefiRSDP = *((uint64_t *) (LOW_MEMORY_MAP_START + GetBootloaderInformationOffset() + 0x7FE8));

	if (uefiRSDP) {
		return uefiRSDP;
	}

	PhysicalMemoryRegion searchRegions[2];

	searchRegions[0].baseAddress = (uintptr_t) (((uint16_t *) LOW_MEMORY_MAP_START)[0x40E] << 4) + LOW_MEMORY_MAP_START;
	searchRegions[0].pageCount = 0x400;
	searchRegions[1].baseAddress = (uintptr_t) 0xE0000 + LOW_MEMORY_MAP_START;
	searchRegions[1].pageCount = 0x20000;

	for (uintptr_t i = 0; i < 2; i++) {
		for (uintptr_t address = searchRegions[i].baseAddress;
				address < searchRegions[i].baseAddress + searchRegions[i].pageCount;
				address += 16) {
			RootSystemDescriptorPointer *rsdp = (RootSystemDescriptorPointer *) address;

			if (rsdp->signature != SIGNATURE_RSDP) {
				continue;
			}

			if (rsdp->revision == 0) {
				if (EsMemorySumBytes((uint8_t *) rsdp, 20)) {
					continue;
				}

				return (uintptr_t) rsdp - LOW_MEMORY_MAP_START;
			} else if (rsdp->revision == 2) {
				if (EsMemorySumBytes((uint8_t *) rsdp, sizeof(RootSystemDescriptorPointer))) {
					continue;
				}

				return (uintptr_t) rsdp - LOW_MEMORY_MAP_START;
			}
		}
	}

	return 0;
}


void ACPIParseTables() {
	acpi.rsdp = (RootSystemDescriptorPointer *) MMMapPhysical(kernelMMSpace, ArchFindRootSystemDescriptorPointer(), 16384, ES_FLAGS_DEFAULT);

	ACPIDescriptorTable* madtHeader = nullptr;
	ACPIDescriptorTable* sdt = nullptr; 
	bool isXSDT = false;

	if (acpi.rsdp) {
		if (acpi.rsdp->revision == 2 && acpi.rsdp->xsdtAddress) {
			isXSDT = true;
			sdt = (ACPIDescriptorTable *) acpi.rsdp->xsdtAddress;
		} else {
			isXSDT = false;
			sdt = (ACPIDescriptorTable *) (uintptr_t) acpi.rsdp->rsdtAddress;
		}

		sdt = (ACPIDescriptorTable *) MMMapPhysical(kernelMMSpace, (uintptr_t) sdt, 16384, ES_FLAGS_DEFAULT);
	} else {
		KernelPanic("ACPIInitialise - Could not find supported root system descriptor pointer.\nACPI support is required.\n");
	}

	if (((sdt->signature == SIGNATURE_XSDT && isXSDT) || (sdt->signature == SIGNATURE_RSDT && !isXSDT)) 
			&& sdt->length < 16384 && !EsMemorySumBytes((uint8_t *) sdt, sdt->length)) {
		// The SDT is valid.
	} else {
		KernelPanic("ACPIInitialise - Could not find a valid or supported system descriptor table.\nACPI support is required.\n");
	}

	size_t tablesCount = (sdt->length - sizeof(ACPIDescriptorTable)) >> (isXSDT ? 3 : 2);

	if (tablesCount < 1) {
		KernelPanic("ACPIInitialise - The system descriptor table contains an unsupported number of tables (%d).\n", tablesCount);
	} 

	uintptr_t tableListAddress = (uintptr_t) sdt + ACPI_DESCRIPTOR_TABLE_HEADER_LENGTH;

	KernelLog(LOG_INFO, "ACPI", "table count", "ACPIInitialise - Found %d tables.\n", tablesCount);

	for (uintptr_t i = 0; i < tablesCount; i++) {
		uintptr_t address;

		if (isXSDT) {
            uint64_t_unaligned* ptr = (uint64_t*) tableListAddress;
			address = ptr[i];
		} else {
            uint32_t_unaligned* ptr = (uint32_t*) tableListAddress;
			address = ptr[i];
		}

		ACPIDescriptorTable *header = (ACPIDescriptorTable *) MMMapPhysical(kernelMMSpace, address, sizeof(ACPIDescriptorTable), ES_FLAGS_DEFAULT);

		KernelLog(LOG_INFO, "ACPI", "table enumerated", "ACPIInitialise - Found ACPI table '%s'.\n", 4, &header->signature);

		if (header->signature == SIGNATURE_MADT) {
			madtHeader = (ACPIDescriptorTable *) MMMapPhysical(kernelMMSpace, address, header->length, ES_FLAGS_DEFAULT);
			ACPICheckTable(madtHeader);
		} else if (header->signature == SIGNATURE_FADT) {
			ACPIDescriptorTable *fadt = (ACPIDescriptorTable *) MMMapPhysical(kernelMMSpace, address, header->length, ES_FLAGS_DEFAULT);
			ACPICheckTable(fadt);
			
			if (header->length > 109) {
				acpi.centuryRegisterIndex = ((uint8_t *) fadt)[108];
				uint8_t bootArchitectureFlags = ((uint8_t *) fadt)[109];
				acpi.ps2ControllerUnavailable = ~bootArchitectureFlags & (1 << 1);
				acpi.vgaControllerUnavailable =  bootArchitectureFlags & (1 << 2);
				KernelLog(LOG_INFO, "ACPI", "FADT", "PS/2 controller is %z; VGA controller is %z.\n",
						acpi.ps2ControllerUnavailable ? "unavailble" : "present",
						acpi.vgaControllerUnavailable ? "unavailble" : "present");
			}

			MMFree(kernelMMSpace, fadt);
		} else if (header->signature == SIGNATURE_HPET) {
			ACPIDescriptorTable *hpet = (ACPIDescriptorTable *) MMMapPhysical(kernelMMSpace, address, header->length, ES_FLAGS_DEFAULT);
			ACPICheckTable(hpet);
			
			if (header->length > 52 && ((uint8_t *) header)[52] == 0) {
				uint64_t baseAddress;
				EsMemoryCopy(&baseAddress, (uint8_t *) header + 44, sizeof(uint64_t));
				KernelLog(LOG_INFO, "ACPI", "HPET", "Found primary HPET with base address %x.\n", baseAddress);
				acpi.hpetBaseAddress = (uint64_t *) MMMapPhysical(kernelMMSpace, baseAddress, 1024, ES_FLAGS_DEFAULT);

				if (acpi.hpetBaseAddress) {
					acpi.hpetBaseAddress[2] |= 1; // Start the main counter.

					acpi.hpetPeriod = acpi.hpetBaseAddress[0] >> 32;
					uint8_t revisionID = acpi.hpetBaseAddress[0] & 0xFF;
					uint64_t initialCount = acpi.hpetBaseAddress[30];

					KernelLog(LOG_INFO, "ACPI", "HPET", "HPET has period of %d fs, revision ID %d, and initial count %d.\n",
							acpi.hpetPeriod, revisionID, initialCount);
				}
			}

			MMFree(kernelMMSpace, hpet);
		}

		MMFree(kernelMMSpace, header);
	}

	MultipleAPICDescriptionTable *madt = (MultipleAPICDescriptionTable *) ((uint8_t *) madtHeader + ACPI_DESCRIPTOR_TABLE_HEADER_LENGTH);

	if (!madt) {
		KernelPanic("ACPIInitialise - Could not find the MADT table.\nThis is required to use the APIC.\n");
	}

	uintptr_t length = madtHeader->length - ACPI_DESCRIPTOR_TABLE_HEADER_LENGTH - sizeof(MultipleAPICDescriptionTable);
	uintptr_t startLength = length;
	uint8_t *data = (uint8_t *) (madt + 1);

#ifdef ES_ARCH_X86_64
	acpi.lapicAddress = (uint32_t volatile *) ACPIMapPhysicalMemory(madt->lapicAddress, 0x10000);
#endif

	while (length && length <= startLength) {
		uint8_t entryType = data[0];
		uint8_t entryLength = data[1];

		switch (entryType) {
			case 0: {
				// A processor and its LAPIC.
				if ((data[4] & 1) == 0) goto nextEntry;
				ArchCPU *processor = acpi.processors + acpi.processorCount;
				processor->processorID = data[2];
				processor->apicID = data[3];
				acpi.processorCount++;
			} break;

			case 1: {
				// An I/O APIC.
				acpi.ioApics[acpi.ioapicCount].id = data[2];
				acpi.ioApics[acpi.ioapicCount].address = (uint32_t volatile *) ACPIMapPhysicalMemory(((uint32_t_unaligned *) data)[1], 0x10000);
				ACPIIoApicReadRegister(&acpi.ioApics[acpi.ioapicCount], 0); // Make sure it's mapped.
				acpi.ioApics[acpi.ioapicCount].gsiBase = ((uint32_t_unaligned *) data)[2];
				acpi.ioapicCount++;
			} break;

			case 2: {
				// An interrupt source override structure.
				acpi.interruptOverrides[acpi.interruptOverrideCount].sourceIRQ = data[3];
				acpi.interruptOverrides[acpi.interruptOverrideCount].gsiNumber = ((uint32_t_unaligned *) data)[1];
				acpi.interruptOverrides[acpi.interruptOverrideCount].activeLow = (data[8] & 2) ? true : false;
				acpi.interruptOverrides[acpi.interruptOverrideCount].levelTriggered = (data[8] & 8) ? true : false;
				KernelLog(LOG_INFO, "ACPI", "interrupt override", "ACPIInitialise - Source IRQ %d is mapped to GSI %d%z%z.\n",
						acpi.interruptOverrides[acpi.interruptOverrideCount].sourceIRQ,
						acpi.interruptOverrides[acpi.interruptOverrideCount].gsiNumber,
						acpi.interruptOverrides[acpi.interruptOverrideCount].activeLow ? ", active low" : ", active high",
						acpi.interruptOverrides[acpi.interruptOverrideCount].levelTriggered ? ", level triggered" : ", edge triggered");
				acpi.interruptOverrideCount++;
			} break;

			case 4: {
				// A non-maskable interrupt.
				acpi.lapicNMIs[acpi.lapicNMICount].processor = data[2];
				acpi.lapicNMIs[acpi.lapicNMICount].lintIndex = data[5];
				acpi.lapicNMIs[acpi.lapicNMICount].activeLow = (data[3] & 2) ? true : false;
				acpi.lapicNMIs[acpi.lapicNMICount].levelTriggered = (data[3] & 8) ? true : false;
				acpi.lapicNMICount++;
			} break;

			default: {
				KernelLog(LOG_ERROR, "ACPI", "unrecognised MADT entry", "ACPIInitialise - Found unknown entry of type %d in MADT\n", entryType);
			} break;
		}

		nextEntry:
		length -= entryLength;
		data += entryLength;
	}

	if (acpi.processorCount > 256 || acpi.ioapicCount > 16 || acpi.interruptOverrideCount > 256 || acpi.lapicNMICount > 32) {
		KernelPanic("ACPIInitialise - Invalid number of processors (%d/%d), \n"
			    "                    I/O APICs (%d/%d), interrupt overrides (%d/%d)\n"
			    "                    and LAPIC NMIs (%d/%d)\n", 
			    acpi.processorCount, 256, acpi.ioapicCount, 16, acpi.interruptOverrideCount, 256, acpi.lapicNMICount, 32);
	}
}


size_t KGetCPUCount() {
	return acpi.processorCount;
}

CPULocalStorage *KGetCPULocal(uintptr_t index) {
	return acpi.processors[index].local;
}

struct InterruptContext {
	uint64_t cr2, ds;
	uint8_t  fxsave[512 + 16];
	uint64_t _check, cr8;
	uint64_t r15, r14, r13, r12, r11, r10, r9, r8;
	uint64_t rbp, rdi, rsi, rdx, rcx, rbx, rax;
	uint64_t interruptNumber, errorCode;
	uint64_t rip, cs, flags, rsp, ss;
};

InterruptContext *ArchInitialiseThread(uintptr_t kernelStack, uintptr_t kernelStackSize, Thread *thread, 
		uintptr_t startAddress, uintptr_t argument1, uintptr_t argument2,
		bool userland, uintptr_t stack, uintptr_t userStackSize) {
	InterruptContext *context = ((InterruptContext *) (kernelStack + kernelStackSize - 8)) - 1;
	thread->kernelStack = kernelStack + kernelStackSize - 8;
	
	// Terminate the thread when the outermost function exists.
	*((uintptr_t *) (kernelStack + kernelStackSize - 8)) = (uintptr_t) &_KThreadTerminate;

	context->fxsave[32] = 0x80;
	context->fxsave[33] = 0x1F;

	if (userland) {
		context->cs = 0x5B;
		context->ds = 0x63;
		context->ss = 0x63;
	} else {
		context->cs = 0x48;
		context->ds = 0x50;
		context->ss = 0x50;
	}

	context->_check = 0x123456789ABCDEF; // Stack corruption detection.
	context->flags = 1 << 9; // Interrupt flag
	context->rip = startAddress;
	context->rsp = stack + userStackSize - 8; // The stack should be 16-byte aligned before the call instruction.
	context->rdi = argument1;
	context->rsi = argument2;

	return context;
}


struct MSIHandler {
	KIRQHandler callback;
	void *context;
};

struct PCIDevice;
struct IRQHandler {
	KIRQHandler callback;
	void *context;
	intptr_t line;
	PCIDevice *pciDevice;
	const char *cOwnerName;
};

const char *const exceptionInformation[] = {
	"0x00: Divide Error (Fault)",
	"0x01: Debug Exception (Fault/Trap)",
	"0x02: Non-Maskable External Interrupt (Interrupt)",
	"0x03: Breakpoint (Trap)",
	"0x04: Overflow (Trap)",
	"0x05: BOUND Range Exceeded (Fault)",
	"0x06: Invalid Opcode (Fault)",
	"0x07: x87 Coprocessor Unavailable (Fault)",
	"0x08: Double Fault (Abort)",
	"0x09: x87 Coprocessor Segment Overrun (Fault)",
	"0x0A: Invalid TSS (Fault)",
	"0x0B: Segment Not Present (Fault)",
	"0x0C: Stack Protection (Fault)",
	"0x0D: General Protection (Fault)",
	"0x0E: Page Fault (Fault)",
	"0x0F: Reserved/Unknown",
	"0x10: x87 FPU Floating-Point Error (Fault)",
	"0x11: Alignment Check (Fault)",
	"0x12: Machine Check (Abort)",
	"0x13: SIMD Floating-Point Exception (Fault)",
	"0x14: Virtualization Exception (Fault)",
	"0x15: Reserved/Unknown",
	"0x16: Reserved/Unknown",
	"0x17: Reserved/Unknown",
	"0x18: Reserved/Unknown",
	"0x19: Reserved/Unknown",
	"0x1A: Reserved/Unknown",
	"0x1B: Reserved/Unknown",
	"0x1C: Reserved/Unknown",
	"0x1D: Reserved/Unknown",
	"0x1E: Reserved/Unknown",
	"0x1F: Reserved/Unknown",
};

#define TIMER_INTERRUPT (0x40)
#define YIELD_IPI (0x41)
#define IRQ_BASE (0x50)
#define CALL_FUNCTION_ON_ALL_PROCESSORS_IPI (0xF0)
#define TLB_SHOOTDOWN_IPI (0xF1)
#define KERNEL_PANIC_IPI (0) // NMIs ignore the interrupt vector.

#define INTERRUPT_VECTOR_MSI_START (0x70)
#define INTERRUPT_VECTOR_MSI_COUNT (0x40)

volatile uintptr_t tlbShootdownVirtualAddress;
volatile size_t tlbShootdownPageCount;

typedef void (*CallFunctionOnAllProcessorsCallbackFunction)();
volatile CallFunctionOnAllProcessorsCallbackFunction callFunctionOnAllProcessorsCallback;
volatile uintptr_t callFunctionOnAllProcessorsRemaining;
//
// Spinlock since some drivers need to access it in IRQs (e.g. ACPICA).
KSpinlock pciConfigSpinlock; 
KSpinlock ipiLock;

uint32_t LapicReadRegister(uint32_t reg) {
	return acpi.lapicAddress[reg];
}

void LapicWriteRegister(uint32_t reg, uint32_t value) {
	acpi.lapicAddress[reg] = value;
}

void LapicNextTimer(size_t ms) {
	LapicWriteRegister(0x320 >> 2, TIMER_INTERRUPT | (1 << 17)); 
	LapicWriteRegister(0x380 >> 2, acpi.lapicTicksPerMs * ms); 
}

void LapicEndOfInterrupt() {
	LapicWriteRegister(0xB0 >> 2, 0);
}

size_t ProcessorSendIPI(uintptr_t interrupt, bool nmi = false, int processorID = -1) {
	// It's possible that another CPU is trying to send an IPI at the same time we want to send the panic IPI.
	// TODO What should we do in this case?
	if (interrupt != KERNEL_PANIC_IPI) KSpinlockAssertLocked(&ipiLock);

	// Note: We send IPIs at a special priority that ProcessorDisableInterrupts doesn't mask.

	size_t ignored = 0;

	for (uintptr_t i = 0; i < acpi.processorCount; i++) {
		ArchCPU *processor = acpi.processors + i;

		if (processorID != -1) {
			if (processorID != processor->kernelProcessorID) {
				ignored++;
				continue;
			}
		} else {
			if (processor == GetLocalStorage()->archCPU || !processor->local || !processor->local->schedulerReady) {
				ignored++;
				continue;
			}
		}

		uint32_t destination = acpi.processors[i].apicID << 24;
		uint32_t command = interrupt | (1 << 14) | (nmi ? 0x400 : 0);
		LapicWriteRegister(0x310 >> 2, destination);
		LapicWriteRegister(0x300 >> 2, command); 

		// Wait for the interrupt to be sent.
		while (LapicReadRegister(0x300 >> 2) & (1 << 12));
	}

	return ignored;
}

void ArchCallFunctionOnAllProcessors(CallFunctionOnAllProcessorsCallbackFunction callback, bool includingThisProcessor) {
	KSpinlockAssertLocked(&ipiLock);

	if (KGetCPUCount() > 1) {
		callFunctionOnAllProcessorsCallback = callback;
		callFunctionOnAllProcessorsRemaining = KGetCPUCount();
		size_t ignored = ProcessorSendIPI(CALL_FUNCTION_ON_ALL_PROCESSORS_IPI);
		__sync_fetch_and_sub(&callFunctionOnAllProcessorsRemaining, ignored);
		while (callFunctionOnAllProcessorsRemaining);
		static volatile size_t totalIgnored = 0;
		totalIgnored += ignored;
	}

	if (includingThisProcessor) callback();
}

#define INVALIDATE_ALL_PAGES_THRESHOLD (1024)

void TLBShootdownCallback() {
	uintptr_t page = tlbShootdownVirtualAddress;

	if (tlbShootdownPageCount > INVALIDATE_ALL_PAGES_THRESHOLD) { 
		ProcessorInvalidateAllPages();
	} else {
		for (uintptr_t i = 0; i < tlbShootdownPageCount; i++, page += K_PAGE_SIZE) {
			ProcessorInvalidatePage(page);
		}
	}
}


uint8_t pciIRQLines[0x100 /* slots */][4 /* pins */];

MSIHandler msiHandlers[INTERRUPT_VECTOR_MSI_COUNT];
IRQHandler irqHandlers[0x40];
KSpinlock irqHandlersLock; // Also for msiHandlers.

extern volatile uint64_t timeStampCounterSynchronizationValue;

PhysicalMemoryRegion *physicalMemoryRegions;
size_t physicalMemoryRegionsCount;
size_t physicalMemoryRegionsPagesCount;
size_t physicalMemoryOriginalPagesCount;
size_t physicalMemoryRegionsIndex;
uintptr_t physicalMemoryHighest;

EsUniqueIdentifier installationID; // The identifier of this OS installation, given to us by the bootloader.
uint32_t bootloaderID;
uintptr_t bootloaderInformationOffset;

uintptr_t GetBootloaderInformationOffset() {
	return bootloaderInformationOffset;
}


// Recursive page table mapping in slot 0x1FE, so that the top 2GB are available for mcmodel kernel.
#define PAGE_TABLE_L4 ((volatile uint64_t *) 0xFFFFFF7FBFDFE000)
#define PAGE_TABLE_L3 ((volatile uint64_t *) 0xFFFFFF7FBFC00000)
#define PAGE_TABLE_L2 ((volatile uint64_t *) 0xFFFFFF7F80000000)
#define PAGE_TABLE_L1 ((volatile uint64_t *) 0xFFFFFF0000000000)
#define ENTRIES_PER_PAGE_TABLE (512)
#define ENTRIES_PER_PAGE_TABLE_BITS (9)



uint8_t coreL1Commit[(0xFFFF800200000000 - 0xFFFF800100000000) >> (/* ENTRIES_PER_PAGE_TABLE_BITS */ 9 + K_PAGE_BITS + 3)];


#define IO_PIC_1_COMMAND		(0x0020)
#define IO_PIC_1_DATA			(0x0021)
#define IO_PIT_DATA			(0x0040)
#define IO_PIT_COMMAND			(0x0043)
#define IO_PS2_DATA			(0x0060)
#define IO_PC_SPEAKER			(0x0061)
#define IO_PS2_STATUS			(0x0064)
#define IO_PS2_COMMAND			(0x0064)
#define IO_RTC_INDEX 			(0x0070)
#define IO_RTC_DATA 			(0x0071)
#define IO_UNUSED_DELAY			(0x0080)
#define IO_PIC_2_COMMAND		(0x00A0)
#define IO_PIC_2_DATA			(0x00A1)
#define IO_BGA_INDEX			(0x01CE)
#define IO_BGA_DATA			(0x01CF)
#define IO_ATA_1			(0x0170) // To 0x0177.
#define IO_ATA_2			(0x01F0) // To 0x01F7.
#define IO_COM_4			(0x02E8) // To 0x02EF.
#define IO_COM_2			(0x02F8) // To 0x02FF.
#define IO_ATA_3			(0x0376)
#define IO_VGA_AC_INDEX 		(0x03C0)
#define IO_VGA_AC_WRITE 		(0x03C0)
#define IO_VGA_AC_READ  		(0x03C1)
#define IO_VGA_MISC_WRITE 		(0x03C2)
#define IO_VGA_MISC_READ  		(0x03CC)
#define IO_VGA_SEQ_INDEX 		(0x03C4)
#define IO_VGA_SEQ_DATA  		(0x03C5)
#define IO_VGA_DAC_READ_INDEX  		(0x03C7)
#define IO_VGA_DAC_WRITE_INDEX 		(0x03C8)
#define IO_VGA_DAC_DATA        		(0x03C9)
#define IO_VGA_GC_INDEX 		(0x03CE)
#define IO_VGA_GC_DATA  		(0x03CF)
#define IO_VGA_CRTC_INDEX 		(0x03D4)
#define IO_VGA_CRTC_DATA  		(0x03D5)
#define IO_VGA_INSTAT_READ 		(0x03DA)
#define IO_COM_3			(0x03E8) // To 0x03EF.
#define IO_ATA_4			(0x03F6)
#define IO_COM_1			(0x03F8) // To 0x03FF.
#define IO_PCI_CONFIG 			(0x0CF8)
#define IO_PCI_DATA   			(0x0CFC)


int8_t Scheduler::GetThreadEffectivePriority(Thread *thread) {
	KSpinlockAssertLocked(&dispatchSpinlock);

	for (int8_t i = 0; i < thread->priority; i++) {
		if (thread->blockedThreadPriorities[i]) {
			// A thread is blocking on a resource owned by this thread,
			// and the blocking thread has a higher priority than this thread.
			// Therefore, this thread should assume that higher priority,
			// until it releases the resource.
			return i;
		}
	}

	return thread->priority;
}

void MMArchFinalizeVAS(MMSpace *space) {
    (void)space;
	// TODO.
	KernelPanic("Unimplemented!\n");
}

void EarlyDelay1Ms() {
	ProcessorOut8(IO_PIT_COMMAND, 0x30);
	ProcessorOut8(IO_PIT_DATA, 0xA9);
	ProcessorOut8(IO_PIT_DATA, 0x04);

	while (true) {
		ProcessorOut8(IO_PIT_COMMAND, 0xE2);

		if (ProcessorIn8(IO_PIT_DATA) & (1 << 7)) {
			break;
		}
	}
}

struct EsSpinlock {
	volatile uint8_t state;
};

void EsSpinlockAcquire(EsSpinlock *spinlock) {
	__sync_synchronize();
	while (__sync_val_compare_and_swap(&spinlock->state, 0, 1));
	__sync_synchronize();
}

void EsSpinlockRelease(EsSpinlock *spinlock) {
	__sync_synchronize();

	if (!spinlock->state) {
		EsPanic("EsSpinlockRelease - Spinlock %x not acquired.\n", spinlock);
	}

	spinlock->state = 0;
	__sync_synchronize();
}


struct RNGState {
	uint64_t s[4];
	EsSpinlock lock;
};

RNGState rngState;

void EsRandomAddEntropy(uint64_t x) {
	EsSpinlockAcquire(&rngState.lock);

	for (uintptr_t i = 0; i < 4; i++) {
		x += 0x9E3779B97F4A7C15;

		uint64_t result = x;
		result = (result ^ (result >> 30)) * 0xBF58476D1CE4E5B9;
		result = (result ^ (result >> 27)) * 0x94D049BB133111EB;
		rngState.s[i] ^= result ^ (result >> 31);
	}

	EsSpinlockRelease(&rngState.lock);
}


uint64_t timeStampTicksPerMs;

struct NewProcessorStorage {
	struct CPULocalStorage *local;
	uint32_t *gdt;
};

NewProcessorStorage AllocateNewProcessorStorage(ArchCPU *archCPU) {
	NewProcessorStorage storage = {};
	storage.local = (CPULocalStorage *) EsHeapAllocate(sizeof(CPULocalStorage), true, K_FIXED);
#ifdef ES_ARCH_X86_64
	storage.gdt = (uint32_t *) MMMapPhysical(kernelMMSpace, MMPhysicalAllocate(MM_PHYSICAL_ALLOCATE_COMMIT_NOW), K_PAGE_SIZE, ES_FLAGS_DEFAULT);
#endif
	storage.local->archCPU = archCPU;
	archCPU->local = storage.local;
	scheduler.CreateProcessorThreads(storage.local);
	archCPU->kernelProcessorID = storage.local->processorID;
	return storage;
}


void ArchInitialise() {
	ACPIParseTables();

	uint8_t bootstrapLapicID = (LapicReadRegister(0x20 >> 2) >> 24); 

	ArchCPU *currentCPU = nullptr;

	for (uintptr_t i = 0; i < acpi.processorCount; i++) {
		if (acpi.processors[i].apicID == bootstrapLapicID) {
			// That's us!
			currentCPU = acpi.processors + i;
			currentCPU->bootProcessor = true;
			break;
		}
	}

	if (!currentCPU) {
		KernelPanic("ArchInitialise - Could not find the bootstrap processor\n");
	}

	// Calibrate the LAPIC's timer and processor's timestamp counter.
	ProcessorDisableInterrupts();
	uint64_t start = ProcessorReadTimeStamp();
	LapicWriteRegister(0x380 >> 2, (uint32_t) -1); 
	for (int i = 0; i < 8; i++) EarlyDelay1Ms(); // Average over 8ms
	acpi.lapicTicksPerMs = ((uint32_t) -1 - LapicReadRegister(0x390 >> 2)) >> 4;
	EsRandomAddEntropy(LapicReadRegister(0x390 >> 2));
	uint64_t end = ProcessorReadTimeStamp();
	timeStampTicksPerMs = (end - start) >> 3;
	ProcessorEnableInterrupts();
	// EsPrint("timeStampTicksPerMs = %d\n", timeStampTicksPerMs);

	// Finish processor initialisation.
	// This sets up interrupts, the timer, CPULocalStorage, the GDT and TSS,
	// and registers the processor with the scheduler.

	NewProcessorStorage storage = AllocateNewProcessorStorage(currentCPU);
	SetupProcessor2(&storage);
}

Process *ProcessSpawn(ProcessType processType) {
	if (scheduler.shutdown) return nullptr;

	Process *process = processType == PROCESS_KERNEL ? kernelProcess : (Process *) scheduler.processPool.Add(sizeof(Process));

	if (!process) {
		return nullptr;
	}

	process->vmm = processType == PROCESS_KERNEL ? kernelMMSpace : (MMSpace *) scheduler.mmSpacePool.Add(sizeof(MMSpace));

	if (!process->vmm) {
		scheduler.processPool.Remove(process);
		return nullptr;
	}

	process->id = __sync_fetch_and_add(&scheduler.nextProcessID, 1);
	process->vmm->referenceCount = 1;
	process->allItem.thisItem = process;
	process->handles = 1;
	process->handleTable.process = process;
	process->permissions = ES_PERMISSION_ALL;
	process->type = processType;

	if (processType == PROCESS_KERNEL) {
		EsCRTstrcpy(process->cExecutableName, "Kernel");
		scheduler.allProcesses.InsertEnd(&process->allItem);
	}

	return process; 
}

Thread *Scheduler::PickThread(CPULocalStorage *local) {
	KSpinlockAssertLocked(&dispatchSpinlock);

	if ((local->asyncTaskList.first || local->inAsyncTask) && local->asyncTaskThread->state == THREAD_ACTIVE) {
		// If the asynchronous task thread for this processor isn't blocked, and has tasks to process, execute it.
		return local->asyncTaskThread;
	}

	for (int i = 0; i < THREAD_PRIORITY_COUNT; i++) {
		// For every priority, check if there is a thread available. If so, execute it.
		LinkedItem<Thread> *item = activeThreads[i].firstItem;
		if (!item) continue;
		item->RemoveFromList();
		return item->thisItem;
	}

	// If we couldn't find a thread to execute, idle.
	return local->idleThread;
}


void Scheduler::MaybeUpdateActiveList(Thread *thread) {
	// TODO Is this correct with regards to paused threads?

	if (thread->type == THREAD_ASYNC_TASK) {
		// Asynchronous task threads do not go in the activeThreads lists.
		return;
	}

	if (thread->type != THREAD_NORMAL) {
		KernelPanic("Scheduler::MaybeUpdateActiveList - Trying to update the active list of a non-normal thread %x.\n", thread);
	}

	KSpinlockAssertLocked(&dispatchSpinlock);

	if (thread->state != THREAD_ACTIVE || thread->executing) {
		// The thread is not currently in an active list, 
		// so it'll end up in the correct activeThreads list when it becomes active.
		return;
	}

	if (!thread->item.list) {
		KernelPanic("Scheduler::MaybeUpdateActiveList - Despite thread %x being active and not executing, it is not in an activeThreads lists.\n", thread);
	}

	int8_t effectivePriority = GetThreadEffectivePriority(thread);

	if (&activeThreads[effectivePriority] == thread->item.list) {
		// The thread's effective priority has not changed.
		// We don't need to do anything.
		return;
	}

	// Remove the thread from its previous active list.
	thread->item.RemoveFromList();

	// Add it to the start of its new active list.
	// TODO I'm not 100% sure we want to always put it at the start.
	activeThreads[effectivePriority].InsertStart(&thread->item);
}


uint64_t ArchGetTimeFromPITMs() {
	// TODO This isn't working on real hardware, but EarlyDelay1Ms is?

	// NOTE This will only work if called at least once every 50 ms.
	// 	(The PIT only stores a 16-bit counter, which is depleted every 50 ms.)

	static bool started = false;
	static uint64_t cumulative = 0, last = 0;

	if (!started) {
		ProcessorOut8(IO_PIT_COMMAND, 0x30);
		ProcessorOut8(IO_PIT_DATA, 0xFF);
		ProcessorOut8(IO_PIT_DATA, 0xFF);
		started = true;
		last = 0xFFFF;
		return 0;
	} else {
		ProcessorOut8(IO_PIT_COMMAND, 0x00);
		uint16_t x = ProcessorIn8(IO_PIT_DATA);
		x |= (ProcessorIn8(IO_PIT_DATA)) << 8;
		cumulative += last - x;
		if (x > last) cumulative += 0x10000;
		last = x;
		return cumulative * 1000 / 1193182;
	}
}



uint64_t ArchGetTimeMs() {
	// Update the time stamp counter synchronization value.
	timeStampCounterSynchronizationValue = ((timeStampCounterSynchronizationValue & 0x8000000000000000) 
			^ 0x8000000000000000) | ProcessorReadTimeStamp();

#ifdef ES_ARCH_X86_64
	if (acpi.hpetBaseAddress && acpi.hpetPeriod) {
		__int128 fsToMs = 1000000000000;
		__int128 reading = acpi.hpetBaseAddress[30];
		return (uint64_t) (reading * (__int128) acpi.hpetPeriod / fsToMs);
	}
#endif

	return ArchGetTimeFromPITMs();
}

void Scheduler::Yield(InterruptContext *context) {
	CPULocalStorage *local = GetLocalStorage();

	if (!started || !local || !local->schedulerReady) {
		return;
	}

	if (!local->processorID) {
		// Update the scheduler's time.
		timeMs = ArchGetTimeMs();
		globalData->schedulerTimeMs = timeMs;

		// Notify the necessary timers.
		KSpinlockAcquire(&activeTimersSpinlock);
		LinkedItem<KTimer> *_timer = activeTimers.firstItem;

		while (_timer) {
			KTimer *timer = _timer->thisItem;
			LinkedItem<KTimer> *next = _timer->nextItem;

			if (timer->triggerTimeMs <= timeMs) {
				activeTimers.Remove(_timer);
				KEventSet(&timer->event);

				if (timer->callback) {
					KRegisterAsyncTask(&timer->asyncTask, timer->callback);
				}
			} else {
				break; // Timers are kept sorted, so there's no point continuing.
			}

			_timer = next;
		}

		KSpinlockRelease(&activeTimersSpinlock);
	}

	if (local->spinlockCount) {
		KernelPanic("Scheduler::Yield - Spinlocks acquired while attempting to yield.\n");
	}

	ProcessorDisableInterrupts(); // We don't want interrupts to get reenabled after the context switch.
	KSpinlockAcquire(&dispatchSpinlock);

	if (dispatchSpinlock.interruptsEnabled) {
		KernelPanic("Scheduler::Yield - Interrupts were enabled when scheduler lock was acquired.\n");
	}

	if (!local->currentThread->executing) {
		KernelPanic("Scheduler::Yield - Current thread %x marked as not executing (%x).\n", local->currentThread, local);
	}

	MMSpace *oldAddressSpace = local->currentThread->temporaryAddressSpace ?: local->currentThread->process->vmm;

	local->currentThread->interruptContext = context;
	local->currentThread->executing = false;

	bool killThread = local->currentThread->terminatableState == THREAD_TERMINATABLE 
		&& local->currentThread->terminating;
	bool keepThreadAlive = local->currentThread->terminatableState == THREAD_USER_BLOCK_REQUEST
		&& local->currentThread->terminating; // The user can't make the thread block if it is terminating.

	if (killThread) {
		local->currentThread->state = THREAD_TERMINATED;
		KernelLog(LOG_INFO, "Scheduler", "terminate yielded thread", "Terminated yielded thread %x\n", local->currentThread);
		KRegisterAsyncTask(&local->currentThread->killAsyncTask, ThreadKill);
	}

	// If the thread is waiting for an object to be notified, put it in the relevant blockedThreads list.
	// But if the object has been notified yet hasn't made itself active yet, do that for it.

	else if (local->currentThread->state == THREAD_WAITING_MUTEX) {
		KMutex *mutex = local->currentThread->blocking.mutex;

		if (!keepThreadAlive && mutex->owner) {
			mutex->owner->blockedThreadPriorities[local->currentThread->priority]++;
			MaybeUpdateActiveList(mutex->owner);
			mutex->blockedThreads.InsertEnd(&local->currentThread->item);
		} else {
			local->currentThread->state = THREAD_ACTIVE;
		}
	}

	else if (local->currentThread->state == THREAD_WAITING_EVENT) {
		if (keepThreadAlive) {
			local->currentThread->state = THREAD_ACTIVE;
		} else {
			bool unblocked = false;

			for (uintptr_t i = 0; i < local->currentThread->blocking.eventCount; i++) {
				if (local->currentThread->blocking.events[i]->state) {
					local->currentThread->state = THREAD_ACTIVE;
					unblocked = true;
					break;
				}
			}

			if (!unblocked) {
				for (uintptr_t i = 0; i < local->currentThread->blocking.eventCount; i++) {
					local->currentThread->blocking.events[i]->blockedThreads.InsertEnd(&local->currentThread->blocking.eventItems[i]);
				}
			}
		}
	}

	else if (local->currentThread->state == THREAD_WAITING_WRITER_LOCK) {
		KWriterLock *lock = local->currentThread->blocking.writerLock;

		if ((local->currentThread->blocking.writerLockType == K_LOCK_SHARED && lock->state >= 0)
				|| (local->currentThread->blocking.writerLockType == K_LOCK_EXCLUSIVE && lock->state == 0)) {
			local->currentThread->state = THREAD_ACTIVE;
		} else {
			local->currentThread->blocking.writerLock->blockedThreads.InsertEnd(&local->currentThread->item);
		}
	}

	// Put the current thread at the end of the activeThreads list.
	if (!killThread && local->currentThread->state == THREAD_ACTIVE) {
		if (local->currentThread->type == THREAD_NORMAL) {
			AddActiveThread(local->currentThread, false);
		} else if (local->currentThread->type == THREAD_IDLE || local->currentThread->type == THREAD_ASYNC_TASK) {
			// Do nothing.
		} else {
			KernelPanic("Scheduler::Yield - Unrecognised thread type\n");
		}
	}

	// Get the next thread to execute.
	Thread *newThread = local->currentThread = PickThread(local);

	if (!newThread) {
		KernelPanic("Scheduler::Yield - Could not find a thread to execute.\n");
	}

	if (newThread->executing) {
		KernelPanic("Scheduler::Yield - Thread (ID %d) in active queue already executing with state %d, type %d.\n", 
				local->currentThread->id, local->currentThread->state, local->currentThread->type);
	}

	// Store information about the thread.
	newThread->executing = true;
	newThread->executingProcessorID = local->processorID;
	newThread->cpuTimeSlices++;
	if (newThread->type == THREAD_IDLE) newThread->process->idleTimeSlices++;
	else newThread->process->cpuTimeSlices++;

	// Prepare the next timer interrupt.
	ArchNextTimer(1 /* ms */);

	InterruptContext *newContext = newThread->interruptContext;
	MMSpace *addressSpace = newThread->temporaryAddressSpace ?: newThread->process->vmm;
	MMSpaceOpenReference(addressSpace);
	ArchSwitchContext(newContext, &addressSpace->data, newThread->kernelStack, newThread, oldAddressSpace);
	KernelPanic("Scheduler::Yield - DoContextSwitch unexpectedly returned.\n");
}



void ProcessorSendYieldIPI(Thread *thread) {
	thread->receivedYieldIPI = false;
	KSpinlockAcquire(&ipiLock);
	ProcessorSendIPI(YIELD_IPI, false);
	KSpinlockRelease(&ipiLock);
	while (!thread->receivedYieldIPI); // Spin until the thread gets the IPI.
}

void ThreadPause(Thread *thread, bool resume) {
	KSpinlockAcquire(&scheduler.dispatchSpinlock);

	if (thread->paused == !resume) {
		return;
	}

	thread->paused = !resume;

	if (!resume && thread->terminatableState == THREAD_TERMINATABLE) {
		if (thread->state == THREAD_ACTIVE) {
			if (thread->executing) {
				if (thread == GetCurrentThread()) {
					KSpinlockRelease(&scheduler.dispatchSpinlock);

					// Yield.
					ProcessorFakeTimerInterrupt();

					if (thread->paused) {
						KernelPanic("ThreadPause - Current thread incorrectly resumed.\n");
					}
				} else {
					// The thread is executing, but on a different processor.
					// Send them an IPI to stop.
					ProcessorSendYieldIPI(thread);
					// TODO The interrupt context might not be set at this point.
				}
			} else {
				// Remove the thread from the active queue, and put it into the paused queue.
				thread->item.RemoveFromList();
				scheduler.AddActiveThread(thread, false);
			}
		} else {
			// The thread doesn't need to be in the paused queue as it won't run anyway.
			// If it is unblocked, then AddActiveThread will put it into the correct queue.
		}
	} else if (resume && thread->item.list == &scheduler.pausedThreads) {
		// Remove the thread from the paused queue, and put it into the active queue.
		scheduler.pausedThreads.Remove(&thread->item);
		scheduler.AddActiveThread(thread, false);
	}

	KSpinlockRelease(&scheduler.dispatchSpinlock);
}


void ProcessPause(Process *process, bool resume) {
	KMutexAcquire(&process->threadsMutex);
	LinkedItem<Thread> *thread = process->threads.firstItem;

	while (thread) {
		Thread *threadObject = thread->thisItem;
		thread = thread->nextItem;
		ThreadPause(threadObject, resume);
	}

	KMutexRelease(&process->threadsMutex);
}


void ProcessCrash(Process *process, EsCrashReason *crashReason) {
	if (process == kernelProcess) {
		KernelPanic("ProcessCrash - Kernel process has crashed (%d).\n", crashReason->errorCode);
	}

	if (process->type != PROCESS_NORMAL) {
		KernelPanic("ProcessCrash - A critical process has crashed (%d).\n", crashReason->errorCode);
	}

	if (GetCurrentThread()->process != process) {
		KernelPanic("ProcessCrash - Attempt to crash process from different process.\n");
	}

	KMutexAcquire(&process->crashMutex);

	if (process->crashed) {
		KMutexRelease(&process->crashMutex);
		return;
	}

	process->crashed = true;

	KernelLog(LOG_ERROR, "Scheduler", "process crashed", "Process %x has crashed! (%d)\n", process, crashReason->errorCode);

	EsMemoryCopy(&process->crashReason, crashReason, sizeof(EsCrashReason));

	if (!scheduler.shutdown) {
		_EsMessageWithObject m;
		EsMemoryZero(&m, sizeof(m));
		m.message.type = ES_MSG_APPLICATION_CRASH;
		m.message.crash.pid = process->id;
		EsMemoryCopy(&m.message.crash.reason, crashReason, sizeof(EsCrashReason));
		DesktopSendMessage(&m);
	}

	KMutexRelease(&process->crashMutex);

	// TODO Shouldn't this be done before sending the desktop message?
	ProcessPause(GetCurrentThread()->process, false);
}


void MMPhysicalInsertFreePagesNext(uintptr_t page) {
	MMPageFrame *frame = pmm.pageFrames + page;
	frame->state = MMPageFrame::FREE;

	{
		frame->list.next = pmm.firstFreePage;
		frame->list.previous = &pmm.firstFreePage;
		if (pmm.firstFreePage) pmm.pageFrames[pmm.firstFreePage].list.previous = &frame->list.next;
		pmm.firstFreePage = page;
	}

	pmm.freeOrZeroedPageBitset.Put(page);
	pmm.countFreePages++;
}

uint64_t MMArchPopulatePageFrameDatabase() {
	uint64_t commitLimit = 0;

	for (uintptr_t i = 0; i < physicalMemoryRegionsCount; i++) {
		uintptr_t base = physicalMemoryRegions[i].baseAddress >> K_PAGE_BITS;
		uintptr_t count = physicalMemoryRegions[i].pageCount;
		commitLimit += count;

		for (uintptr_t j = 0; j < count; j++) {
			MMPhysicalInsertFreePagesNext(base + j);
		}
	}

	physicalMemoryRegionsPagesCount = 0;
	return commitLimit;
}


uintptr_t MMArchGetPhysicalMemoryHighest() {
	return physicalMemoryHighest;
}

void MMArchInitialise() {
	coreMMSpace->data.cr3 = kernelMMSpace->data.cr3 = ProcessorReadCR3();

	mmCoreRegions[0].baseAddress = MM_CORE_SPACE_START;
	mmCoreRegions[0].pageCount = MM_CORE_SPACE_SIZE / K_PAGE_SIZE;

#ifdef ES_ARCH_X86_64
	for (uintptr_t i = 0x100; i < 0x200; i++) {
		if (PAGE_TABLE_L4[i] == 0) {
			// We don't need to commit anything because the PMM isn't ready yet.
			PAGE_TABLE_L4[i] = MMPhysicalAllocate(ES_FLAGS_DEFAULT) | 3; 
			EsMemoryZero((void *) (PAGE_TABLE_L3 + i * 0x200), K_PAGE_SIZE);
		}
	}

	coreMMSpace->data.l1Commit = coreL1Commit;
	KMutexAcquire(&coreMMSpace->reserveMutex);
	kernelMMSpace->data.l1Commit = (uint8_t *) MMReserve(coreMMSpace, L1_COMMIT_SIZE_BYTES, MM_REGION_NORMAL | MM_REGION_NO_COMMIT_TRACKING | MM_REGION_FIXED)->baseAddress;
	KMutexRelease(&coreMMSpace->reserveMutex);
#endif
}



bool MMArchCommitPageTables(MMSpace *space, MMRegion *region) {
	KMutexAssertLocked(&space->reserveMutex);

	MMArchVAS *data = &space->data;

	uintptr_t base = (region->baseAddress - (space == coreMMSpace ? MM_CORE_SPACE_START : 0)) & 0x7FFFFFFFF000;
	uintptr_t end = base + (region->pageCount << K_PAGE_BITS);
	uintptr_t needed = 0;

	for (uintptr_t i = base; i < end; i += 1L << (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 3)) {
		uintptr_t indexL4 = i >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 3);
		if (!(data->l3Commit[indexL4 >> 3] & (1 << (indexL4 & 7)))) needed++;
		i = indexL4 << (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 3);
	}

	for (uintptr_t i = base; i < end; i += 1L << (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 2)) {
		uintptr_t indexL3 = i >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 2);
		if (!(data->l2Commit[indexL3 >> 3] & (1 << (indexL3 & 7)))) needed++;
		i = indexL3 << (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 2);
	}

	uintptr_t previousIndexL2I = -1;

	for (uintptr_t i = base; i < end; i += 1L << (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 1)) {
		uintptr_t indexL2 = i >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 1);
		uintptr_t indexL2I = indexL2 >> 15;
		if (!(data->l1CommitCommit[indexL2I >> 3] & (1 << (indexL2I & 7)))) needed += previousIndexL2I != indexL2I ? 2 : 1;
		else if (!(data->l1Commit[indexL2 >> 3] & (1 << (indexL2 & 7)))) needed++;
		previousIndexL2I = indexL2I;
		i = indexL2 << (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 1);
	}

	if (needed) {
		if (!MMCommit(needed * K_PAGE_SIZE, true)) {
			return false;
		}

		data->pageTablesCommitted += needed;
	}

	for (uintptr_t i = base; i < end; i += 1L << (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 3)) {
		uintptr_t indexL4 = i >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 3);
		data->l3Commit[indexL4 >> 3] |= (1 << (indexL4 & 7));
		i = indexL4 << (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 3);
	}

	for (uintptr_t i = base; i < end; i += 1L << (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 2)) {
		uintptr_t indexL3 = i >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 2);
		data->l2Commit[indexL3 >> 3] |= (1 << (indexL3 & 7));
		i = indexL3 << (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 2);
	}

	for (uintptr_t i = base; i < end; i += 1L << (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 1)) {
		uintptr_t indexL2 = i >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 1);
		uintptr_t indexL2I = indexL2 >> 15;
		data->l1CommitCommit[indexL2I >> 3] |= (1 << (indexL2I & 7));
		data->l1Commit[indexL2 >> 3] |= (1 << (indexL2 & 7));
		i = indexL2 << (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 1);
	}

	return true;
}


uintptr_t MMArchEarlyAllocatePage() {
	uintptr_t i = physicalMemoryRegionsIndex;

	while (!physicalMemoryRegions[i].pageCount) {
		i++;

		if (i == physicalMemoryRegionsCount) {
			KernelPanic("MMArchEarlyAllocatePage - Expected more pages in physical regions.\n");
		}
	}

	PhysicalMemoryRegion *region = physicalMemoryRegions + i;
	uintptr_t returnValue = region->baseAddress;

	region->baseAddress += K_PAGE_SIZE;
	region->pageCount--;
	physicalMemoryRegionsPagesCount--;
	physicalMemoryRegionsIndex = i;

	return returnValue;
}


void PCProcessMemoryMap() {
	physicalMemoryRegions = (PhysicalMemoryRegion *) (LOW_MEMORY_MAP_START + 0x60000 + bootloaderInformationOffset);

	for (uintptr_t i = 0; physicalMemoryRegions[i].baseAddress; i++) {
		PhysicalMemoryRegion region = physicalMemoryRegions[i];
		uint64_t end = region.baseAddress + (region.pageCount << K_PAGE_BITS);
#ifdef ES_BITS_32
		if (end > 0x100000000) { region.pageCount = 0; continue; }
#endif
		physicalMemoryRegionsPagesCount += region.pageCount;
		if (end > physicalMemoryHighest) physicalMemoryHighest = end;
		physicalMemoryRegionsCount++;
	}

	physicalMemoryOriginalPagesCount = physicalMemoryRegions[physicalMemoryRegionsCount].pageCount;
}


void ProcessorOut8Delayed(uint16_t port, uint8_t value) {
	ProcessorOut8(port, value);

	// Read an unused port to get a short delay.
	ProcessorIn8(IO_UNUSED_DELAY);
}

bool MMArchIsBufferInUserRange(uintptr_t baseAddress, size_t byteCount) {
	if (baseAddress               & 0xFFFF800000000000) return false;
	if (byteCount                 & 0xFFFF800000000000) return false;
	if ((baseAddress + byteCount) & 0xFFFF800000000000) return false;
	return true;
}

void PCSetupCOM1() {
#ifdef COM_OUTPUT
	ProcessorOut8Delayed(IO_COM_1 + 1, 0x00);
	ProcessorOut8Delayed(IO_COM_1 + 3, 0x80);
	ProcessorOut8Delayed(IO_COM_1 + 0, 0x03);
	ProcessorOut8Delayed(IO_COM_1 + 1, 0x00);
	ProcessorOut8Delayed(IO_COM_1 + 3, 0x03);
	ProcessorOut8Delayed(IO_COM_1 + 2, 0xC7);
	ProcessorOut8Delayed(IO_COM_1 + 4, 0x0B);

	// Print a divider line.
	for (uint8_t i = 0; i < 10; i++) ProcessorDebugOutputByte('-');
	ProcessorDebugOutputByte('\r');
	ProcessorDebugOutputByte('\n');
#endif
}

void PCDisablePIC() {
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

void ArchNextTimer(size_t ms) {
	while (!scheduler.started);               // Wait until the scheduler is ready.
	GetLocalStorage()->schedulerReady = true; // Make sure this CPU can be scheduled.
	LapicNextTimer(ms);                       // Set the next timer.
}

bool MMArchMapPage(MMSpace *space, uintptr_t physicalAddress, uintptr_t virtualAddress, unsigned flags) {
	// TODO Use the no-execute bit.

	if ((physicalAddress | virtualAddress) & (K_PAGE_SIZE - 1)) {
		KernelPanic("MMArchMapPage - Address not page aligned.\n");
	}

	if (pmm.pageFrames && (physicalAddress >> K_PAGE_BITS) < pmm.pageFrameDatabaseCount) {
		if (pmm.pageFrames[physicalAddress >> K_PAGE_BITS].state != MMPageFrame::ACTIVE
				&& pmm.pageFrames[physicalAddress >> K_PAGE_BITS].state != MMPageFrame::UNUSABLE) {
			KernelPanic("MMArchMapPage - Physical page frame %x not marked as ACTIVE or UNUSABLE.\n", physicalAddress);
		}
	}

	if (!physicalAddress) {
		KernelPanic("MMArchMapPage - Attempt to map physical page 0.\n");
	} else if (!virtualAddress) {
		KernelPanic("MMArchMapPage - Attempt to map virtual page 0.\n");
#ifdef ES_ARCH_X86_64
	} else if (virtualAddress < 0xFFFF800000000000 && ProcessorReadCR3() != space->data.cr3) {
#else
	} else if (virtualAddress < 0xC0000000 && ProcessorReadCR3() != space->data.cr3) {
#endif
		KernelPanic("MMArchMapPage - Attempt to map page into other address space.\n");
	}

	bool acquireFrameLock = !(flags & (MM_MAP_PAGE_NO_NEW_TABLES | MM_MAP_PAGE_FRAME_LOCK_ACQUIRED));
	if (acquireFrameLock) KMutexAcquire(&pmm.pageFrameMutex);
	EsDefer(if (acquireFrameLock) KMutexRelease(&pmm.pageFrameMutex););

	bool acquireSpaceLock = ~flags & MM_MAP_PAGE_NO_NEW_TABLES;
	if (acquireSpaceLock) KMutexAcquire(&space->data.mutex);
	EsDefer(if (acquireSpaceLock) KMutexRelease(&space->data.mutex));

	// EsPrint("\tMap, %x -> %x\n", virtualAddress, physicalAddress);

	uintptr_t oldVirtualAddress = virtualAddress;
#ifdef ES_ARCH_X86_64
	physicalAddress &= 0xFFFFFFFFFFFFF000;
	virtualAddress  &= 0x0000FFFFFFFFF000;
#endif

#ifdef ES_ARCH_X86_64
	uintptr_t indexL4 = virtualAddress >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 3);
	uintptr_t indexL3 = virtualAddress >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 2);
#endif
	uintptr_t indexL2 = virtualAddress >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 1);
	uintptr_t indexL1 = virtualAddress >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 0);

	if (space != coreMMSpace && space != kernelMMSpace /* Don't check the kernel's space since the bootloader's tables won't be committed. */) {
#ifdef ES_ARCH_X86_64
		if (!(space->data.l3Commit[indexL4 >> 3] & (1 << (indexL4 & 7)))) KernelPanic("MMArchMapPage - Attempt to map using uncommitted L3 page table.\n");
		if (!(space->data.l2Commit[indexL3 >> 3] & (1 << (indexL3 & 7)))) KernelPanic("MMArchMapPage - Attempt to map using uncommitted L2 page table.\n");
#endif
		if (!(space->data.l1Commit[indexL2 >> 3] & (1 << (indexL2 & 7)))) KernelPanic("MMArchMapPage - Attempt to map using uncommitted L1 page table.\n");
	}

#ifdef ES_ARCH_X86_64
	if ((PAGE_TABLE_L4[indexL4] & 1) == 0) {
		if (flags & MM_MAP_PAGE_NO_NEW_TABLES) KernelPanic("MMArchMapPage - NO_NEW_TABLES flag set, but a table was missing.\n");
		PAGE_TABLE_L4[indexL4] = MMPhysicalAllocate(MM_PHYSICAL_ALLOCATE_LOCK_ACQUIRED) | 7;
		ProcessorInvalidatePage((uintptr_t) (PAGE_TABLE_L3 + indexL3)); // Not strictly necessary.
		EsMemoryZero((void *) ((uintptr_t) (PAGE_TABLE_L3 + indexL3) & ~(K_PAGE_SIZE - 1)), K_PAGE_SIZE);
		space->data.pageTablesActive++;
	}

	if ((PAGE_TABLE_L3[indexL3] & 1) == 0) {
		if (flags & MM_MAP_PAGE_NO_NEW_TABLES) KernelPanic("MMArchMapPage - NO_NEW_TABLES flag set, but a table was missing.\n");
		PAGE_TABLE_L3[indexL3] = MMPhysicalAllocate(MM_PHYSICAL_ALLOCATE_LOCK_ACQUIRED) | 7;
		ProcessorInvalidatePage((uintptr_t) (PAGE_TABLE_L2 + indexL2)); // Not strictly necessary.
		EsMemoryZero((void *) ((uintptr_t) (PAGE_TABLE_L2 + indexL2) & ~(K_PAGE_SIZE - 1)), K_PAGE_SIZE);
		space->data.pageTablesActive++;
	}
#endif

	if ((PAGE_TABLE_L2[indexL2] & 1) == 0) {
		if (flags & MM_MAP_PAGE_NO_NEW_TABLES) KernelPanic("MMArchMapPage - NO_NEW_TABLES flag set, but a table was missing.\n");
		PAGE_TABLE_L2[indexL2] = MMPhysicalAllocate(MM_PHYSICAL_ALLOCATE_LOCK_ACQUIRED) | 7;
		ProcessorInvalidatePage((uintptr_t) (PAGE_TABLE_L1 + indexL1)); // Not strictly necessary.
		EsMemoryZero((void *) ((uintptr_t) (PAGE_TABLE_L1 + indexL1) & ~(K_PAGE_SIZE - 1)), K_PAGE_SIZE);
		space->data.pageTablesActive++;
	}

	uintptr_t oldValue = PAGE_TABLE_L1[indexL1];
	uintptr_t value = physicalAddress | 3;

#ifdef ES_ARCH_X86_64
	if (flags & MM_MAP_PAGE_WRITE_COMBINING) value |= 16; // This only works because we modified the PAT in SetupProcessor1.
#else
	if (flags & MM_MAP_PAGE_WRITE_COMBINING) KernelPanic("MMArchMapPage - Write combining is unimplemented.\n"); // TODO.
#endif
	if (flags & MM_MAP_PAGE_NOT_CACHEABLE) value |= 24;
	if (flags & MM_MAP_PAGE_USER) value |= 7;
	else value |= 1 << 8; // Global.
	if (flags & MM_MAP_PAGE_READ_ONLY) value &= ~2;
	if (flags & MM_MAP_PAGE_COPIED) value |= 1 << 9; // Ignored by the CPU.

	// When the CPU accesses or writes to a page, 
	// it will modify the table entry to set the accessed or dirty bits respectively,
	// but it uses its TLB entry as the assumed previous value of the entry.
	// When unmapping pages we can't atomically remove an entry and do the TLB shootdown.
	// This creates a race condition:
	// 1. CPU 0 maps a page table entry. The dirty bit is not set.
	// 2. CPU 1 reads from the page. A TLB entry is created with the dirty bit not set.
	// 3. CPU 0 unmaps the entry.
	// 4. CPU 1 writes to the page. As the TLB entry has the dirty bit cleared, it sets the entry to its cached entry ORed with the dirty bit.
	// 5. CPU 0 invalidates the entry.
	// That is, CPU 1 didn't realize the page was unmapped when it wrote out its entry, so the page becomes mapped again.
	// To prevent this, we mark all pages with the dirty and accessed bits when we initially map them.
	// (We don't use these bits for anything, anyway. They're basically useless on SMP systems, as far as I can tell.)
	// That said, a CPU won't overwrite and clear a dirty bit when writing out its accessed flag (tested on Qemu);
	// see here https://stackoverflow.com/questions/69024372/.
	// Tl;dr: if a CPU ever sees an entry without these bits set, it can overwrite the entry with junk whenever it feels like it.
	// TODO Should we be marking page tables as dirty/accessed? (Including those made by the 32-bit AND 64-bit bootloader and MMArchInitialise).
	// 	When page table trimming is implemented, we'll probably need to do this.
	value |= (1 << 5) | (1 << 6);

	if ((oldValue & 1) && !(flags & MM_MAP_PAGE_OVERWRITE)) {
		if (flags & MM_MAP_PAGE_IGNORE_IF_MAPPED) {
			return false;
		}

		if ((oldValue & ~(K_PAGE_SIZE - 1)) != physicalAddress) {
			KernelPanic("MMArchMapPage - Attempt to map %x to %x that has already been mapped to %x.\n", 
					virtualAddress, physicalAddress, oldValue & (~(K_PAGE_SIZE - 1)));
		}

		if (oldValue == value) {
			KernelPanic("MMArchMapPage - Attempt to rewrite page translation.\n", 
					physicalAddress, virtualAddress, oldValue & (K_PAGE_SIZE - 1), value & (K_PAGE_SIZE - 1));
		} else if (!(oldValue & 2) && (value & 2)) {
			// The page has become writable.
		} else {
			KernelPanic("MMArchMapPage - Attempt to change flags mapping %x address %x from %x to %x.\n", 
					physicalAddress, virtualAddress, oldValue & (K_PAGE_SIZE - 1), value & (K_PAGE_SIZE - 1));
		}
	}

	PAGE_TABLE_L1[indexL1] = value;

	// We rely on this page being invalidated on this CPU in some places.
	ProcessorInvalidatePage(oldVirtualAddress);

	return true;
}

uintptr_t MMArchTranslateAddress(MMSpace *, uintptr_t virtualAddress, bool writeAccess) {
	// TODO This mutex will be necessary if we ever remove page tables.
	// space->data.mutex.Acquire();
	// EsDefer(space->data.mutex.Release());

#ifdef ES_ARCH_X86_64
	virtualAddress &= 0x0000FFFFFFFFF000;
	if ((PAGE_TABLE_L4[virtualAddress >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 3)] & 1) == 0) return 0;
	if ((PAGE_TABLE_L3[virtualAddress >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 2)] & 1) == 0) return 0;
#endif
	if ((PAGE_TABLE_L2[virtualAddress >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 1)] & 1) == 0) return 0;
	uintptr_t physicalAddress = PAGE_TABLE_L1[virtualAddress >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 0)];
	if (writeAccess && !(physicalAddress & 2)) return 0;
#ifdef ES_ARCH_X86_64
	return (physicalAddress & 1) ? (physicalAddress & 0x0000FFFFFFFFF000) : 0;
#else
	return (physicalAddress & 1) ? (physicalAddress & 0xFFFFF000) : 0;
#endif
}

bool MMArchHandlePageFault(uintptr_t address, uint32_t flags) {
	// EsPrint("Fault %x\n", address);
	address &= ~(K_PAGE_SIZE - 1);
	bool forSupervisor = flags & MM_HANDLE_PAGE_FAULT_FOR_SUPERVISOR;

	if (!ProcessorAreInterruptsEnabled()) {
		KernelPanic("MMArchHandlePageFault - Page fault with interrupts disabled.\n");
	}

	if (address < K_PAGE_SIZE) {
	} else if (address >= LOW_MEMORY_MAP_START && address < LOW_MEMORY_MAP_START + LOW_MEMORY_LIMIT && forSupervisor) {
		// We want to access a physical page within the first 4GB.
		MMArchMapPage(kernelMMSpace, address - LOW_MEMORY_MAP_START, address, MM_MAP_PAGE_COMMIT_TABLES_NOW);
		return true;
	} else if (address >= MM_CORE_REGIONS_START && address < MM_CORE_REGIONS_START + MM_CORE_REGIONS_COUNT * sizeof(MMRegion) && forSupervisor) {
		// This is where coreMMSpace stores its regions.
		// Allocate physical memory and map it.
		MMArchMapPage(kernelMMSpace, MMPhysicalAllocate(MM_PHYSICAL_ALLOCATE_ZEROED), address, MM_MAP_PAGE_COMMIT_TABLES_NOW);
		return true;
	} else if (address >= MM_CORE_SPACE_START && address < MM_CORE_SPACE_START + MM_CORE_SPACE_SIZE && forSupervisor) {
		return MMHandlePageFault(coreMMSpace, address, flags);
	} else if (address >= MM_KERNEL_SPACE_START && address < MM_KERNEL_SPACE_START + MM_KERNEL_SPACE_SIZE && forSupervisor) {
		return MMHandlePageFault(kernelMMSpace, address, flags);
	} else if (address >= MM_MODULES_START && address < MM_MODULES_START + MM_MODULES_SIZE && forSupervisor) {
		return MMHandlePageFault(kernelMMSpace, address, flags);
	} else {
		Thread *thread = GetCurrentThread();
		MMSpace *space = thread->temporaryAddressSpace;
		if (!space) space = thread->process->vmm;
		return MMHandlePageFault(space, address, flags);
	}

	return false;
}

void ContextSanityCheck(InterruptContext *context) {
	if (!context || context->cs > 0x100 || context->ds > 0x100 || context->ss > 0x100 
			|| (context->rip >= 0x1000000000000 && context->rip < 0xFFFF000000000000)
			|| (context->rip < 0xFFFF800000000000 && context->cs == 0x48)) {
		KernelPanic("ContextSanityCheck - Corrupt context (%x/%x/%x/%x)\nRIP = %x, RSP = %x\n", context, context->cs, context->ds, context->ss, context->rip, context->rsp);
	}
}

bool PostContextSwitch(InterruptContext *context, MMSpace *oldAddressSpace) {
	if (scheduler.dispatchSpinlock.interruptsEnabled) {
		KernelPanic("PostContextSwitch - Interrupts were enabled. (3)\n");
	}

	// We can only free the scheduler's spinlock when we are no longer using the stack
	// from the previous thread. See DoContextSwitch.
	// (Another CPU can KillThread this once it's back in activeThreads.)
	KSpinlockRelease(&scheduler.dispatchSpinlock, true);

	Thread *currentThread = GetCurrentThread();

#ifdef ES_ARCH_X86_64
	CPULocalStorage *local = GetLocalStorage();
	*local->archCPU->kernelStack = currentThread->kernelStack;
#endif

	bool newThread = currentThread->cpuTimeSlices == 1;
	LapicEndOfInterrupt();
	ContextSanityCheck(context);
	ProcessorSetThreadStorage(currentThread->tlsAddress);
	MMSpaceCloseReference(oldAddressSpace);

#ifdef ES_ARCH_X86_64
	KernelLog(LOG_VERBOSE, "Arch", "context switch", "Context switch to %zthread %x at %x\n", newThread ? "new " : "", currentThread, context->rip);
	currentThread->lastKnownExecutionAddress = context->rip;
#else
	KernelLog(LOG_VERBOSE, "Arch", "context switch", "Context switch to %zthread %x at %x\n", newThread ? "new " : "", currentThread, context->eip);
	currentThread->lastKnownExecutionAddress = context->eip;
#endif

	if (ProcessorAreInterruptsEnabled()) {
		KernelPanic("PostContextSwitch - Interrupts were enabled. (2)\n");
	}

	if (local->spinlockCount) {
		KernelPanic("PostContextSwitch - spinlockCount is non-zero (%x).\n", local);
	}

#ifdef ES_ARCH_X86_32
	if (context->fromRing0) {
		// Returning to a kernel thread; we need to fix the stack.
		uint32_t irq = context->esp;
		uint32_t errorCode = context->ss;
		context->ss = context->flags;
		context->esp = context->cs;
		context->flags = context->eip;
		context->cs = context->errorCode;
		context->eip = context->irq;
		context->irq = irq;
		context->errorCode = errorCode;
	}
#endif

	return newThread;
}

void AsyncTaskThread() {
	CPULocalStorage *local = GetLocalStorage();

	while (true) {
		if (!local->asyncTaskList.first) {
			ProcessorFakeTimerInterrupt();
		} else {
			KSpinlockAcquire(&scheduler.asyncTaskSpinlock);
			SimpleList *item = local->asyncTaskList.first;
			KAsyncTask *task = EsContainerOf(KAsyncTask, item, item);
			KAsyncTaskCallback callback = task->callback;
			task->callback = nullptr;
			local->inAsyncTask = true;
			item->Remove();
			KSpinlockRelease(&scheduler.asyncTaskSpinlock);
			callback(task); // This may cause the task to be deallocated.
			ThreadSetTemporaryAddressSpace(nullptr); // The task may have modified the address space.
			local->inAsyncTask = false;
		}
	}
}

void Scheduler::CreateProcessorThreads(CPULocalStorage *local) {
	local->asyncTaskThread = ThreadSpawn("AsyncTasks", (uintptr_t) AsyncTaskThread, 0, SPAWN_THREAD_ASYNC_TASK);
	local->currentThread = local->idleThread = ThreadSpawn("Idle", 0, 0, SPAWN_THREAD_IDLE);
	local->processorID = __sync_fetch_and_add(&nextProcessorID, 1);

	if (local->processorID >= K_MAX_PROCESSORS) { 
		KernelPanic("Scheduler::CreateProcessorThreads - Maximum processor count (%d) exceeded.\n", local->processorID);
	}
}


void SetupProcessor2(NewProcessorStorage *storage) {
	// Setup the local interrupts for the current processor.
		
	for (uintptr_t i = 0; i < acpi.lapicNMICount; i++) {
		if (acpi.lapicNMIs[i].processor == 0xFF
				|| acpi.lapicNMIs[i].processor == storage->local->archCPU->processorID) {
			uint32_t registerIndex = (0x350 + (acpi.lapicNMIs[i].lintIndex << 4)) >> 2;
			uint32_t value = 2 | (1 << 10); // NMI exception interrupt vector.
			if (acpi.lapicNMIs[i].activeLow) value |= 1 << 13;
			if (acpi.lapicNMIs[i].levelTriggered) value |= 1 << 15;
			LapicWriteRegister(registerIndex, value);
		}
	}

	LapicWriteRegister(0x350 >> 2, LapicReadRegister(0x350 >> 2) & ~(1 << 16));
	LapicWriteRegister(0x360 >> 2, LapicReadRegister(0x360 >> 2) & ~(1 << 16));
	LapicWriteRegister(0x080 >> 2, 0);
	if (LapicReadRegister(0x30 >> 2) & 0x80000000) LapicWriteRegister(0x410 >> 2, 0);
	LapicEndOfInterrupt();

	// Configure the LAPIC's timer.

	LapicWriteRegister(0x3E0 >> 2, 2); // Divisor = 16

	// Create the processor's local storage.

	ProcessorSetLocalStorage(storage->local);

	// Setup a GDT and TSS for the processor.

#ifdef ES_ARCH_X86_64
	uint32_t *gdt = storage->gdt;
	void *bootstrapGDT = (void *) (((uint64_t_unaligned *) ((uint16_t *) processorGDTR + 1))[0]);
	EsMemoryCopy(gdt, bootstrapGDT, 2048);
	uint32_t *tss = (uint32_t *) ((uint8_t *) storage->gdt + 2048);
	storage->local->archCPU->kernelStack = (uint64_t_unaligned *) (tss + 1);
	ProcessorInstallTSS(gdt, tss);
#endif
}


bool debugKeyPressed;


void DriversDumpStateRecurse(KDevice *device) {
	if (device->dumpState) {
		device->dumpState(device);
	}

	for (uintptr_t i = 0; i < device->children.Length(); i++) {
		DriversDumpStateRecurse(device->children[i]);
	}
}

void DriversDumpState() {
	KMutexAcquire(&deviceTreeMutex);
	DriversDumpStateRecurse(deviceTreeRoot);
	KMutexRelease(&deviceTreeMutex);
}

struct KGraphicsTarget : KDevice {
	size_t screenWidth, screenHeight;
	bool reducedColors; // Set to true if using less than 15 bit color.

	void (*updateScreen)(K_USER_BUFFER const uint8_t *source, uint32_t sourceWidth, uint32_t sourceHeight, uint32_t sourceStride, 
			uint32_t destinationX, uint32_t destinationY);
	void (*debugPutBlock)(uintptr_t x, uintptr_t y, bool toggle);
	void (*debugClearScreen)();
};

struct Graphics {
    KGraphicsTarget *target;
    size_t width, height; 
	Surface frameBuffer;
	bool debuggerActive;
	size_t totalSurfaceBytes;
};

Graphics graphics;
size_t debugRows, debugColumns, debugCurrentRow, debugCurrentColumn;
bool printToDebugger = false;
uintptr_t terminalPosition = 80;

#define KERNEL_LOG_SIZE (262144)
char kernelLog[KERNEL_LOG_SIZE];
uintptr_t kernelLogPosition;

KSpinlock terminalLock; 
KSpinlock printLock;
#define VGA_FONT_WIDTH (9)
#define VGA_FONT_HEIGHT (16)

const uint64_t vgaFont[] = {
	0x0000000000000000UL, 0x0000000000000000UL, 0xBD8181A5817E0000UL, 0x000000007E818199UL, 0xC3FFFFDBFF7E0000UL, 0x000000007EFFFFE7UL, 0x7F7F7F3600000000UL, 0x00000000081C3E7FUL, 
	0x7F3E1C0800000000UL, 0x0000000000081C3EUL, 0xE7E73C3C18000000UL, 0x000000003C1818E7UL, 0xFFFF7E3C18000000UL, 0x000000003C18187EUL, 0x3C18000000000000UL, 0x000000000000183CUL, 
	0xC3E7FFFFFFFFFFFFUL, 0xFFFFFFFFFFFFE7C3UL, 0x42663C0000000000UL, 0x00000000003C6642UL, 0xBD99C3FFFFFFFFFFUL, 0xFFFFFFFFFFC399BDUL, 0x331E4C5870780000UL, 0x000000001E333333UL, 
	0x3C666666663C0000UL, 0x0000000018187E18UL, 0x0C0C0CFCCCFC0000UL, 0x00000000070F0E0CUL, 0xC6C6C6FEC6FE0000UL, 0x0000000367E7E6C6UL, 0xE73CDB1818000000UL, 0x000000001818DB3CUL, 
	0x1F7F1F0F07030100UL, 0x000000000103070FUL, 0x7C7F7C7870604000UL, 0x0000000040607078UL, 0x1818187E3C180000UL, 0x0000000000183C7EUL, 0x6666666666660000UL, 0x0000000066660066UL, 
	0xD8DEDBDBDBFE0000UL, 0x00000000D8D8D8D8UL, 0x6363361C06633E00UL, 0x0000003E63301C36UL, 0x0000000000000000UL, 0x000000007F7F7F7FUL, 0x1818187E3C180000UL, 0x000000007E183C7EUL, 
	0x1818187E3C180000UL, 0x0000000018181818UL, 0x1818181818180000UL, 0x00000000183C7E18UL, 0x7F30180000000000UL, 0x0000000000001830UL, 0x7F060C0000000000UL, 0x0000000000000C06UL, 
	0x0303000000000000UL, 0x0000000000007F03UL, 0xFF66240000000000UL, 0x0000000000002466UL, 0x3E1C1C0800000000UL, 0x00000000007F7F3EUL, 0x3E3E7F7F00000000UL, 0x0000000000081C1CUL, 
	0x0000000000000000UL, 0x0000000000000000UL, 0x18183C3C3C180000UL, 0x0000000018180018UL, 0x0000002466666600UL, 0x0000000000000000UL, 0x36367F3636000000UL, 0x0000000036367F36UL, 
	0x603E0343633E1818UL, 0x000018183E636160UL, 0x1830634300000000UL, 0x000000006163060CUL, 0x3B6E1C36361C0000UL, 0x000000006E333333UL, 0x000000060C0C0C00UL, 0x0000000000000000UL, 
	0x0C0C0C0C18300000UL, 0x0000000030180C0CUL, 0x30303030180C0000UL, 0x000000000C183030UL, 0xFF3C660000000000UL, 0x000000000000663CUL, 0x7E18180000000000UL, 0x0000000000001818UL, 
	0x0000000000000000UL, 0x0000000C18181800UL, 0x7F00000000000000UL, 0x0000000000000000UL, 0x0000000000000000UL, 0x0000000018180000UL, 0x1830604000000000UL, 0x000000000103060CUL, 
	0xDBDBC3C3663C0000UL, 0x000000003C66C3C3UL, 0x1818181E1C180000UL, 0x000000007E181818UL, 0x0C183060633E0000UL, 0x000000007F630306UL, 0x603C6060633E0000UL, 0x000000003E636060UL, 
	0x7F33363C38300000UL, 0x0000000078303030UL, 0x603F0303037F0000UL, 0x000000003E636060UL, 0x633F0303061C0000UL, 0x000000003E636363UL, 0x18306060637F0000UL, 0x000000000C0C0C0CUL, 
	0x633E6363633E0000UL, 0x000000003E636363UL, 0x607E6363633E0000UL, 0x000000001E306060UL, 0x0000181800000000UL, 0x0000000000181800UL, 0x0000181800000000UL, 0x000000000C181800UL, 
	0x060C183060000000UL, 0x000000006030180CUL, 0x00007E0000000000UL, 0x000000000000007EUL, 0x6030180C06000000UL, 0x00000000060C1830UL, 0x18183063633E0000UL, 0x0000000018180018UL, 
	0x7B7B63633E000000UL, 0x000000003E033B7BUL, 0x7F6363361C080000UL, 0x0000000063636363UL, 0x663E6666663F0000UL, 0x000000003F666666UL, 0x03030343663C0000UL, 0x000000003C664303UL, 
	0x66666666361F0000UL, 0x000000001F366666UL, 0x161E1646667F0000UL, 0x000000007F664606UL, 0x161E1646667F0000UL, 0x000000000F060606UL, 0x7B030343663C0000UL, 0x000000005C666363UL, 
	0x637F636363630000UL, 0x0000000063636363UL, 0x18181818183C0000UL, 0x000000003C181818UL, 0x3030303030780000UL, 0x000000001E333333UL, 0x1E1E366666670000UL, 0x0000000067666636UL, 
	0x06060606060F0000UL, 0x000000007F664606UL, 0xC3DBFFFFE7C30000UL, 0x00000000C3C3C3C3UL, 0x737B7F6F67630000UL, 0x0000000063636363UL, 0x63636363633E0000UL, 0x000000003E636363UL, 
	0x063E6666663F0000UL, 0x000000000F060606UL, 0x63636363633E0000UL, 0x000070303E7B6B63UL, 0x363E6666663F0000UL, 0x0000000067666666UL, 0x301C0663633E0000UL, 0x000000003E636360UL, 
	0x18181899DBFF0000UL, 0x000000003C181818UL, 0x6363636363630000UL, 0x000000003E636363UL, 0xC3C3C3C3C3C30000UL, 0x00000000183C66C3UL, 0xDBC3C3C3C3C30000UL, 0x000000006666FFDBUL, 
	0x18183C66C3C30000UL, 0x00000000C3C3663CUL, 0x183C66C3C3C30000UL, 0x000000003C181818UL, 0x0C183061C3FF0000UL, 0x00000000FFC38306UL, 0x0C0C0C0C0C3C0000UL, 0x000000003C0C0C0CUL, 
	0x1C0E070301000000UL, 0x0000000040607038UL, 0x30303030303C0000UL, 0x000000003C303030UL, 0x0000000063361C08UL, 0x0000000000000000UL, 0x0000000000000000UL, 0x0000FF0000000000UL, 
	0x0000000000180C0CUL, 0x0000000000000000UL, 0x3E301E0000000000UL, 0x000000006E333333UL, 0x66361E0606070000UL, 0x000000003E666666UL, 0x03633E0000000000UL, 0x000000003E630303UL, 
	0x33363C3030380000UL, 0x000000006E333333UL, 0x7F633E0000000000UL, 0x000000003E630303UL, 0x060F0626361C0000UL, 0x000000000F060606UL, 0x33336E0000000000UL, 0x001E33303E333333UL, 
	0x666E360606070000UL, 0x0000000067666666UL, 0x18181C0018180000UL, 0x000000003C181818UL, 0x6060700060600000UL, 0x003C666660606060UL, 0x1E36660606070000UL, 0x000000006766361EUL, 
	0x18181818181C0000UL, 0x000000003C181818UL, 0xDBFF670000000000UL, 0x00000000DBDBDBDBUL, 0x66663B0000000000UL, 0x0000000066666666UL, 0x63633E0000000000UL, 0x000000003E636363UL, 
	0x66663B0000000000UL, 0x000F06063E666666UL, 0x33336E0000000000UL, 0x007830303E333333UL, 0x666E3B0000000000UL, 0x000000000F060606UL, 0x06633E0000000000UL, 0x000000003E63301CUL, 
	0x0C0C3F0C0C080000UL, 0x00000000386C0C0CUL, 0x3333330000000000UL, 0x000000006E333333UL, 0xC3C3C30000000000UL, 0x00000000183C66C3UL, 0xC3C3C30000000000UL, 0x0000000066FFDBDBUL, 
	0x3C66C30000000000UL, 0x00000000C3663C18UL, 0x6363630000000000UL, 0x001F30607E636363UL, 0x18337F0000000000UL, 0x000000007F63060CUL, 0x180E181818700000UL, 0x0000000070181818UL, 
	0x1800181818180000UL, 0x0000000018181818UL, 0x18701818180E0000UL, 0x000000000E181818UL, 0x000000003B6E0000UL, 0x0000000000000000UL, 0x63361C0800000000UL, 0x00000000007F6363UL, 
};

typedef void (*FormatCallback)(int character, void *data);

#define UTF8_LENGTH_CHAR(character, value) { \
	char first = *(character); \
 \
	if (!(first & 0x80)) \
		value = 1; \
	else if ((first & 0xE0) == 0xC0) \
		value = 2; \
	else if ((first & 0xF0) == 0xE0) \
		value = 3; \
  	else if ((first & 0xF8) == 0xF0) \
		value = 4; \
	else if ((first & 0xFC) == 0xF8) \
		value = 5; \
	else if ((first & 0xFE) == 0xFC) \
		value = 6; \
	else \
		value = 0; \
}

#define ES_STRING_FORMAT_SIMPLE		(1 << 0)


#define DEFINE_INTERFACE_STRING(name, text) static const char *interfaceString_ ## name = text;
#define INTERFACE_STRING(name) interfaceString_ ## name, -1

#define ELLIPSIS "…"
#define HYPHENATION_POINT "‧"
#define OPEN_SPEECH "\u201C"
#define CLOSE_SPEECH "\u201D"
#define SYSTEM_BRAND_SHORT "Essence"

// Common.

DEFINE_INTERFACE_STRING(CommonErrorTitle, "Error");

DEFINE_INTERFACE_STRING(CommonOK, "OK");
DEFINE_INTERFACE_STRING(CommonCancel, "Cancel");

DEFINE_INTERFACE_STRING(CommonUndo, "Undo");
DEFINE_INTERFACE_STRING(CommonRedo, "Redo");
DEFINE_INTERFACE_STRING(CommonClipboardCut, "Cut");
DEFINE_INTERFACE_STRING(CommonClipboardCopy, "Copy");
DEFINE_INTERFACE_STRING(CommonClipboardPaste, "Paste");
DEFINE_INTERFACE_STRING(CommonSelectionSelectAll, "Select all");
DEFINE_INTERFACE_STRING(CommonSelectionDelete, "Delete");

DEFINE_INTERFACE_STRING(CommonFormatPopup, "Format");
DEFINE_INTERFACE_STRING(CommonFormatSize, "Text size:");
DEFINE_INTERFACE_STRING(CommonFormatLanguage, "Language:");
DEFINE_INTERFACE_STRING(CommonFormatPlainText, "Plain text");

DEFINE_INTERFACE_STRING(CommonFileMenu, "File");
DEFINE_INTERFACE_STRING(CommonFileSave, "Save");
DEFINE_INTERFACE_STRING(CommonFileShare, "Share");
DEFINE_INTERFACE_STRING(CommonFileMakeCopy, "Make a copy");
DEFINE_INTERFACE_STRING(CommonFileVersionHistory, "Version history" ELLIPSIS);
DEFINE_INTERFACE_STRING(CommonFileShowInFileManager, "Show in File Manager" ELLIPSIS);
DEFINE_INTERFACE_STRING(CommonFileMenuFileSize, "Size:");
DEFINE_INTERFACE_STRING(CommonFileMenuFileLocation, "Where:");
DEFINE_INTERFACE_STRING(CommonFileUnchanged, "(All changes saved.)");

DEFINE_INTERFACE_STRING(CommonZoomIn, "Zoom in");
DEFINE_INTERFACE_STRING(CommonZoomOut, "Zoom out");

DEFINE_INTERFACE_STRING(CommonSearchOpen, "Search");
DEFINE_INTERFACE_STRING(CommonSearchNoMatches, "No matches found.");
DEFINE_INTERFACE_STRING(CommonSearchNext, "Find next");
DEFINE_INTERFACE_STRING(CommonSearchPrevious, "Find previous");
DEFINE_INTERFACE_STRING(CommonSearchPrompt, "Search for:");
DEFINE_INTERFACE_STRING(CommonSearchPrompt2, "Enter text to search for.");

DEFINE_INTERFACE_STRING(CommonItemFolder, "Folder");
DEFINE_INTERFACE_STRING(CommonItemFile, "File");

DEFINE_INTERFACE_STRING(CommonSortAscending, "Sort ascending");
DEFINE_INTERFACE_STRING(CommonSortDescending, "Sort descending");

DEFINE_INTERFACE_STRING(CommonDriveHDD, "Hard disk");
DEFINE_INTERFACE_STRING(CommonDriveSSD, "SSD");
DEFINE_INTERFACE_STRING(CommonDriveCDROM, "CD-ROM");
DEFINE_INTERFACE_STRING(CommonDriveUSBMassStorage, "USB drive");

DEFINE_INTERFACE_STRING(CommonSystemBrand, SYSTEM_BRAND_SHORT " Alpha v0.1");

DEFINE_INTERFACE_STRING(CommonListViewType, "List view");
DEFINE_INTERFACE_STRING(CommonListViewTypeThumbnails, "Thumbnails");
DEFINE_INTERFACE_STRING(CommonListViewTypeTiles, "Tiles");
DEFINE_INTERFACE_STRING(CommonListViewTypeDetails, "Details");

DEFINE_INTERFACE_STRING(CommonAnnouncementCopied, "Copied");
DEFINE_INTERFACE_STRING(CommonAnnouncementCut, "Cut");
DEFINE_INTERFACE_STRING(CommonAnnouncementTextCopied, "Text copied");
DEFINE_INTERFACE_STRING(CommonAnnouncementCopyErrorResources, "There's not enough space to copy this");
DEFINE_INTERFACE_STRING(CommonAnnouncementCopyErrorOther, "Could not copy");
DEFINE_INTERFACE_STRING(CommonAnnouncementPasteErrorOther, "Could not paste");

DEFINE_INTERFACE_STRING(CommonEmpty, "empty");

DEFINE_INTERFACE_STRING(CommonUnitPercent, "%");
DEFINE_INTERFACE_STRING(CommonUnitBytes, " B");
DEFINE_INTERFACE_STRING(CommonUnitKilobytes, " KB");
DEFINE_INTERFACE_STRING(CommonUnitMegabytes, " MB");
DEFINE_INTERFACE_STRING(CommonUnitGigabytes, " GB");
DEFINE_INTERFACE_STRING(CommonUnitMilliseconds, " ms");

// Desktop.

DEFINE_INTERFACE_STRING(DesktopNewTabTitle, "New Tab");
DEFINE_INTERFACE_STRING(DesktopShutdownTitle, "Shut Down");
DEFINE_INTERFACE_STRING(DesktopShutdownAction, "Shut down");
DEFINE_INTERFACE_STRING(DesktopRestartAction, "Restart");
DEFINE_INTERFACE_STRING(DesktopForceQuit, "Force quit");
DEFINE_INTERFACE_STRING(DesktopCrashedApplication, "The application has crashed. If you're a developer, more information is available in System Monitor.");
DEFINE_INTERFACE_STRING(DesktopNoSuchApplication, "The requested application could not found. It may have been uninstalled.");
DEFINE_INTERFACE_STRING(DesktopApplicationStartupError, "The requested application could not be started. Your system may be low on resources, or the application files may have been corrupted.");
DEFINE_INTERFACE_STRING(DesktopNotResponding, "The application is not responding.\nIf you choose to force quit, any unsaved data may be lost.");
DEFINE_INTERFACE_STRING(DesktopConfirmShutdown, "Are you sure you want to turn off your computer? All applications will be closed.");

DEFINE_INTERFACE_STRING(DesktopCloseTab, "Close tab");
DEFINE_INTERFACE_STRING(DesktopMoveTabToNewWindow, "Move tab to new window");
DEFINE_INTERFACE_STRING(DesktopMoveTabToNewWindowSplitLeft, "Move tab to left of screen");
DEFINE_INTERFACE_STRING(DesktopMoveTabToNewWindowSplitRight, "Move tab to right of screen");
DEFINE_INTERFACE_STRING(DesktopInspectUI, "Inspect UI");
DEFINE_INTERFACE_STRING(DesktopCloseWindow, "Close window");
DEFINE_INTERFACE_STRING(DesktopCloseAllTabs, "Close all tabs");
DEFINE_INTERFACE_STRING(DesktopMaximiseWindow, "Fill screen");
DEFINE_INTERFACE_STRING(DesktopRestoreWindow, "Restore position");
DEFINE_INTERFACE_STRING(DesktopMinimiseWindow, "Hide");
DEFINE_INTERFACE_STRING(DesktopCenterWindow, "Center in screen");
DEFINE_INTERFACE_STRING(DesktopSnapWindowLeft, "Move to left side");
DEFINE_INTERFACE_STRING(DesktopSnapWindowRight, "Move to right side");

DEFINE_INTERFACE_STRING(DesktopSettingsApplication, "Settings");
DEFINE_INTERFACE_STRING(DesktopSettingsTitle, "Settings");
DEFINE_INTERFACE_STRING(DesktopSettingsBackButton, "All settings");
DEFINE_INTERFACE_STRING(DesktopSettingsUndoButton, "Undo changes");
DEFINE_INTERFACE_STRING(DesktopSettingsAccessibility, "Accessibility");
DEFINE_INTERFACE_STRING(DesktopSettingsApplications, "Applications");
DEFINE_INTERFACE_STRING(DesktopSettingsDateAndTime, "Date and time");
DEFINE_INTERFACE_STRING(DesktopSettingsDevices, "Devices");
DEFINE_INTERFACE_STRING(DesktopSettingsDisplay, "Display");
DEFINE_INTERFACE_STRING(DesktopSettingsKeyboard, "Keyboard");
DEFINE_INTERFACE_STRING(DesktopSettingsLocalisation, "Localisation");
DEFINE_INTERFACE_STRING(DesktopSettingsMouse, "Mouse");
DEFINE_INTERFACE_STRING(DesktopSettingsNetwork, "Network");
DEFINE_INTERFACE_STRING(DesktopSettingsPower, "Power");
DEFINE_INTERFACE_STRING(DesktopSettingsSound, "Sound");
DEFINE_INTERFACE_STRING(DesktopSettingsTheme, "Theme");

DEFINE_INTERFACE_STRING(DesktopSettingsKeyboardKeyRepeatDelay, "Key repeat delay:");
DEFINE_INTERFACE_STRING(DesktopSettingsKeyboardKeyRepeatRate, "Key repeat rate:");
DEFINE_INTERFACE_STRING(DesktopSettingsKeyboardCaretBlinkRate, "Caret blink rate:");
DEFINE_INTERFACE_STRING(DesktopSettingsKeyboardTestTextboxIntroduction, "Try your settings in the textbox below:");
DEFINE_INTERFACE_STRING(DesktopSettingsKeyboardUseSmartQuotes, "Use smart quotes when typing");
DEFINE_INTERFACE_STRING(DesktopSettingsKeyboardLayout, "Keyboard layout:");

DEFINE_INTERFACE_STRING(DesktopSettingsMouseDoubleClickSpeed, "Double click time:");
DEFINE_INTERFACE_STRING(DesktopSettingsMouseSpeed, "Cursor movement speed:");
DEFINE_INTERFACE_STRING(DesktopSettingsMouseCursorTrails, "Cursor trail count:");
DEFINE_INTERFACE_STRING(DesktopSettingsMouseLinesPerScrollNotch, "Lines to scroll per wheel notch:");
DEFINE_INTERFACE_STRING(DesktopSettingsMouseSwapLeftAndRightButtons, "Swap left and right buttons");
DEFINE_INTERFACE_STRING(DesktopSettingsMouseShowShadow, "Show shadow below cursor");
DEFINE_INTERFACE_STRING(DesktopSettingsMouseLocateCursorOnCtrl, "Highlight cursor location when Ctrl is pressed");
DEFINE_INTERFACE_STRING(DesktopSettingsMouseTestDoubleClickIntroduction, "Double click the circle below to try your setting. If it does not change color, increase the double click time.");
DEFINE_INTERFACE_STRING(DesktopSettingsMouseUseAcceleration, "Move cursor faster when mouse is moved quickly");
DEFINE_INTERFACE_STRING(DesktopSettingsMouseSlowOnAlt, "Move cursor slower when Alt is held");
DEFINE_INTERFACE_STRING(DesktopSettingsMouseSpeedSlow, "Slow");
DEFINE_INTERFACE_STRING(DesktopSettingsMouseSpeedFast, "Fast");
DEFINE_INTERFACE_STRING(DesktopSettingsMouseCursorTrailsNone, "None");
DEFINE_INTERFACE_STRING(DesktopSettingsMouseCursorTrailsMany, "Many");

DEFINE_INTERFACE_STRING(DesktopSettingsDisplayUIScale, "Interface scale:");

DEFINE_INTERFACE_STRING(DesktopSettingsThemeWindowColor, "Window color:");
DEFINE_INTERFACE_STRING(DesktopSettingsThemeEnableHoverState, "Highlight the item the cursor is over");
DEFINE_INTERFACE_STRING(DesktopSettingsThemeEnableAnimations, "Animate the user interface");
DEFINE_INTERFACE_STRING(DesktopSettingsThemeWallpaper, "Wallpaper");

// File operations.

DEFINE_INTERFACE_STRING(FileCannotSave, "The document was not saved.");
DEFINE_INTERFACE_STRING(FileCannotOpen, "The file could not be opened.");
DEFINE_INTERFACE_STRING(FileCannotRename, "The file could not be renamed.");

DEFINE_INTERFACE_STRING(FileRenameSuccess, "Renamed");

DEFINE_INTERFACE_STRING(FileSaveErrorFileDeleted, "Another application deleted the file.");
DEFINE_INTERFACE_STRING(FileSaveErrorCorrupt, "The file has been corrupted, and it cannot be modified.");
DEFINE_INTERFACE_STRING(FileSaveErrorDrive, "The drive containing the file was unable to modify it.");
DEFINE_INTERFACE_STRING(FileSaveErrorTooLarge, "The drive does not support files large enough to store this document.");
DEFINE_INTERFACE_STRING(FileSaveErrorConcurrentAccess, "Another application is modifying the file.");
DEFINE_INTERFACE_STRING(FileSaveErrorDriveFull, "The drive is full. Try deleting some files to free up space.");
DEFINE_INTERFACE_STRING(FileSaveErrorResourcesLow, "The system is low on resources. Close some applcations and try again.");
DEFINE_INTERFACE_STRING(FileSaveErrorAlreadyExists, "There is already a file called " OPEN_SPEECH "%s" CLOSE_SPEECH " in this folder.");
DEFINE_INTERFACE_STRING(FileSaveErrorTooManyFiles, "Too many files already have the same name.");
DEFINE_INTERFACE_STRING(FileSaveErrorUnknown, "An unknown error occurred. Please try again later.");

DEFINE_INTERFACE_STRING(FileLoadErrorCorrupt, "The file has been corrupted, and it cannot be opened.");
DEFINE_INTERFACE_STRING(FileLoadErrorDrive, "The drive containing the file was unable to access its contents.");
DEFINE_INTERFACE_STRING(FileLoadErrorResourcesLow, "The system is low on resources. Close some applcations and try again.");
DEFINE_INTERFACE_STRING(FileLoadErrorUnknown, "An unknown error occurred. Please try again later.");

DEFINE_INTERFACE_STRING(FileCloseWithModificationsTitle, "Do you want to save this document?");
DEFINE_INTERFACE_STRING(FileCloseWithModificationsContent, "You need to save your changes to " OPEN_SPEECH "%s" CLOSE_SPEECH " before you can close it.");
DEFINE_INTERFACE_STRING(FileCloseWithModificationsSave, "Save and close");
DEFINE_INTERFACE_STRING(FileCloseWithModificationsDelete, "Discard");
DEFINE_INTERFACE_STRING(FileCloseNewTitle, "Do you want to keep this document?");
DEFINE_INTERFACE_STRING(FileCloseNewContent, "You need to save it before you can close " OPEN_SPEECH "%s" CLOSE_SPEECH ".");
DEFINE_INTERFACE_STRING(FileCloseNewName, "Name:");

// Image Editor.

DEFINE_INTERFACE_STRING(ImageEditorToolBrush, "Brush");
DEFINE_INTERFACE_STRING(ImageEditorToolFill, "Fill");
DEFINE_INTERFACE_STRING(ImageEditorToolRectangle, "Rectangle");
DEFINE_INTERFACE_STRING(ImageEditorToolSelect, "Select");
DEFINE_INTERFACE_STRING(ImageEditorToolText, "Text");

DEFINE_INTERFACE_STRING(ImageEditorCanvasSize, "Canvas size");

DEFINE_INTERFACE_STRING(ImageEditorPropertyWidth, "Width:");
DEFINE_INTERFACE_STRING(ImageEditorPropertyHeight, "Height:");
DEFINE_INTERFACE_STRING(ImageEditorPropertyColor, "Color:");
DEFINE_INTERFACE_STRING(ImageEditorPropertyBrushSize, "Brush size:");

DEFINE_INTERFACE_STRING(ImageEditorImageTransformations, "Transform image");
DEFINE_INTERFACE_STRING(ImageEditorRotateLeft, "Rotate left");
DEFINE_INTERFACE_STRING(ImageEditorRotateRight, "Rotate right");
DEFINE_INTERFACE_STRING(ImageEditorFlipHorizontally, "Flip horizontally");
DEFINE_INTERFACE_STRING(ImageEditorFlipVertically, "Flip vertically");

DEFINE_INTERFACE_STRING(ImageEditorImage, "Image");
DEFINE_INTERFACE_STRING(ImageEditorPickTool, "Pick tool");

DEFINE_INTERFACE_STRING(ImageEditorUnsupportedFormat, "The image is in an unsupported format. Try opening it with another application.");

DEFINE_INTERFACE_STRING(ImageEditorNewFileName, "untitled.png");
DEFINE_INTERFACE_STRING(ImageEditorNewDocument, "New bitmap image");

DEFINE_INTERFACE_STRING(ImageEditorTitle, "Image Editor");

// Text Editor.

DEFINE_INTERFACE_STRING(TextEditorTitle, "Text Editor");
DEFINE_INTERFACE_STRING(TextEditorNewFileName, "untitled.txt");
DEFINE_INTERFACE_STRING(TextEditorNewDocument, "New text document");

// Markdown Viewer.

DEFINE_INTERFACE_STRING(MarkdownViewerTitle, "Markdown Viewer");

// POSIX.

DEFINE_INTERFACE_STRING(POSIXUnavailable, "This application depends on the POSIX subsystem. To enable it, select \am]Flag.ENABLE_POSIX_SUBSYSTEM\a] in \am]config\a].");
DEFINE_INTERFACE_STRING(POSIXTitle, "POSIX Application");

// Font Book.

DEFINE_INTERFACE_STRING(FontBookTitle, "Font Book");
DEFINE_INTERFACE_STRING(FontBookTextSize, "Text size:");
DEFINE_INTERFACE_STRING(FontBookPreviewText, "Preview text:");
DEFINE_INTERFACE_STRING(FontBookVariants, "Variants");
DEFINE_INTERFACE_STRING(FontBookPreviewTextDefault, "Looking for a change of mind.");
DEFINE_INTERFACE_STRING(FontBookPreviewTextLongDefault, "Sphinx of black quartz, judge my vow.");
DEFINE_INTERFACE_STRING(FontBookOpenFont, "Open");
DEFINE_INTERFACE_STRING(FontBookNavigationBack, "Back to all fonts");
DEFINE_INTERFACE_STRING(FontBookVariantNormal100, "Thin");
DEFINE_INTERFACE_STRING(FontBookVariantNormal200, "Extra light");
DEFINE_INTERFACE_STRING(FontBookVariantNormal300, "Light");
DEFINE_INTERFACE_STRING(FontBookVariantNormal400, "Normal");
DEFINE_INTERFACE_STRING(FontBookVariantNormal500, "Medium");
DEFINE_INTERFACE_STRING(FontBookVariantNormal600, "Semi bold");
DEFINE_INTERFACE_STRING(FontBookVariantNormal700, "Bold");
DEFINE_INTERFACE_STRING(FontBookVariantNormal800, "Extra bold");
DEFINE_INTERFACE_STRING(FontBookVariantNormal900, "Black");
DEFINE_INTERFACE_STRING(FontBookVariantItalic100, "Thin (italic)");
DEFINE_INTERFACE_STRING(FontBookVariantItalic200, "Extra light (italic)");
DEFINE_INTERFACE_STRING(FontBookVariantItalic300, "Light (italic)");
DEFINE_INTERFACE_STRING(FontBookVariantItalic400, "Normal (italic)");
DEFINE_INTERFACE_STRING(FontBookVariantItalic500, "Medium (italic)");
DEFINE_INTERFACE_STRING(FontBookVariantItalic600, "Semi bold (italic)");
DEFINE_INTERFACE_STRING(FontBookVariantItalic700, "Bold (italic)");
DEFINE_INTERFACE_STRING(FontBookVariantItalic800, "Extra bold (italic)");
DEFINE_INTERFACE_STRING(FontBookVariantItalic900, "Black (italic)");

// File Manager.

DEFINE_INTERFACE_STRING(FileManagerOpenFolderError, "The folder could not be opened.");
DEFINE_INTERFACE_STRING(FileManagerNewFolderError, "Could not create the folder.");
DEFINE_INTERFACE_STRING(FileManagerRenameItemError, "The item could not be renamed.");
DEFINE_INTERFACE_STRING(FileManagerUnknownError, "An unknown error occurred.");
DEFINE_INTERFACE_STRING(FileManagerTitle, "File Manager");
DEFINE_INTERFACE_STRING(FileManagerRootFolder, "Computer");
DEFINE_INTERFACE_STRING(FileManagerColumnName, "Name");
DEFINE_INTERFACE_STRING(FileManagerColumnType, "Type");
DEFINE_INTERFACE_STRING(FileManagerColumnSize, "Size");
DEFINE_INTERFACE_STRING(FileManagerOpenFolderTask, "Opening folder" ELLIPSIS);
DEFINE_INTERFACE_STRING(FileManagerOpenFileError, "The file could not be opened.");
DEFINE_INTERFACE_STRING(FileManagerNoRegisteredApplicationsForFile, "None of the applications installed on this computer can open this type of file.");
DEFINE_INTERFACE_STRING(FileManagerFolderNamePrompt, "Folder name:");
DEFINE_INTERFACE_STRING(FileManagerNewFolderAction, "Create");
DEFINE_INTERFACE_STRING(FileManagerNewFolderTask, "Creating folder" ELLIPSIS);
DEFINE_INTERFACE_STRING(FileManagerRenameTitle, "Rename");
DEFINE_INTERFACE_STRING(FileManagerRenamePrompt, "Type the new name of the item:");
DEFINE_INTERFACE_STRING(FileManagerRenameAction, "Rename");
DEFINE_INTERFACE_STRING(FileManagerRenameTask, "Renaming item" ELLIPSIS);
DEFINE_INTERFACE_STRING(FileManagerEmptyBookmarkView, "Drag folders here to bookmark them.");
DEFINE_INTERFACE_STRING(FileManagerEmptyFolderView, "Drag items here to add them to the folder.");
DEFINE_INTERFACE_STRING(FileManagerNewFolderToolbarItem, "New folder");
DEFINE_INTERFACE_STRING(FileManagerNewFolderName, "New folder");
DEFINE_INTERFACE_STRING(FileManagerGenericError, "The cause of the error could not be identified.");
DEFINE_INTERFACE_STRING(FileManagerItemAlreadyExistsError, "The item already exists in the folder.");
DEFINE_INTERFACE_STRING(FileManagerItemDoesNotExistError, "The item does not exist.");
DEFINE_INTERFACE_STRING(FileManagerPermissionNotGrantedError, "You don't have permission to modify this folder.");
DEFINE_INTERFACE_STRING(FileManagerOngoingTaskDescription, "This shouldn't take long.");
DEFINE_INTERFACE_STRING(FileManagerPlacesDrives, "Drives");
DEFINE_INTERFACE_STRING(FileManagerPlacesBookmarks, "Bookmarks");
DEFINE_INTERFACE_STRING(FileManagerBookmarksAddHere, "Add bookmark here");
DEFINE_INTERFACE_STRING(FileManagerBookmarksRemoveHere, "Remove bookmark here");
DEFINE_INTERFACE_STRING(FileManagerDrivesPage, "Drives/");
DEFINE_INTERFACE_STRING(FileManagerInvalidPath, "The current path does not lead to a folder. It may have been deleted or moved.");
DEFINE_INTERFACE_STRING(FileManagerInvalidDrive, "The drive containing this folder was disconnected.");
DEFINE_INTERFACE_STRING(FileManagerRefresh, "Refresh");
DEFINE_INTERFACE_STRING(FileManagerListContextActions, "Actions");
DEFINE_INTERFACE_STRING(FileManagerCopyTask, "Copying" ELLIPSIS);
DEFINE_INTERFACE_STRING(FileManagerMoveTask, "Moving" ELLIPSIS);
DEFINE_INTERFACE_STRING(FileManagerGoBack, "Go back");
DEFINE_INTERFACE_STRING(FileManagerGoForwards, "Go forwards");
DEFINE_INTERFACE_STRING(FileManagerGoUp, "Go to containing folder");
DEFINE_INTERFACE_STRING(FileManagerFileOpenIn, "File is open in " OPEN_SPEECH "%s" CLOSE_SPEECH);

// 2048.

DEFINE_INTERFACE_STRING(Game2048Score, "Score:");
DEFINE_INTERFACE_STRING(Game2048Instructions, "Use the \aw6]arrow-keys\a] to slide the tiles. When matching tiles touch, they \aw6]merge\a] into one. Try to create the number \aw6]2048\a]!");
DEFINE_INTERFACE_STRING(Game2048GameOver, "Game over");
DEFINE_INTERFACE_STRING(Game2048GameOverExplanation, "There are no valid moves left.");
DEFINE_INTERFACE_STRING(Game2048NewGame, "New game");
DEFINE_INTERFACE_STRING(Game2048HighScore, "High score: \aw6]%d\a]");
DEFINE_INTERFACE_STRING(Game2048NewHighScore, "You reached a new high score!");

// Installer.

DEFINE_INTERFACE_STRING(InstallerTitle, "Install " SYSTEM_BRAND_SHORT);
DEFINE_INTERFACE_STRING(InstallerDrivesList, "Select the drive to install on:");
DEFINE_INTERFACE_STRING(InstallerDrivesSelectHint, "Choose a drive from the list on the left.");
DEFINE_INTERFACE_STRING(InstallerDriveRemoved, "The drive was disconnected.");
DEFINE_INTERFACE_STRING(InstallerDriveReadOnly, "This drive is read-only. You cannot install " SYSTEM_BRAND_SHORT " on this drive.");
DEFINE_INTERFACE_STRING(InstallerDriveNotEnoughSpace, "This drive does not have enough space to install " SYSTEM_BRAND_SHORT ".");
DEFINE_INTERFACE_STRING(InstallerDriveCouldNotRead, "The drive could not be accessed. It may not be working correctly.");
DEFINE_INTERFACE_STRING(InstallerDriveAlreadyHasPartitions, "The drive already has data on it. You cannot install " SYSTEM_BRAND_SHORT " on this drive.");
DEFINE_INTERFACE_STRING(InstallerDriveUnsupported, "This drive uses unsupported features. You cannot install " SYSTEM_BRAND_SHORT " on this drive.");
DEFINE_INTERFACE_STRING(InstallerDriveOkay, SYSTEM_BRAND_SHORT " can be installed on this drive.");
DEFINE_INTERFACE_STRING(InstallerInstall, "Install");
DEFINE_INTERFACE_STRING(InstallerViewLicenses, "Licenses");
DEFINE_INTERFACE_STRING(InstallerGoBack, "Back");
DEFINE_INTERFACE_STRING(InstallerFinish, "Finish");
DEFINE_INTERFACE_STRING(InstallerCustomizeOptions, "Customize your computer.");
DEFINE_INTERFACE_STRING(InstallerCustomizeOptionsHint, "More options will be available in Settings.");
DEFINE_INTERFACE_STRING(InstallerUserName, "User name:");
DEFINE_INTERFACE_STRING(InstallerTime, "Current time:");
DEFINE_INTERFACE_STRING(InstallerSystemFont, "System font:");
DEFINE_INTERFACE_STRING(InstallerFontDefault, "Default");
DEFINE_INTERFACE_STRING(InstallerProgressMessage, "Installing, please wait" ELLIPSIS "\nDo not turn off your computer.\nProgress: \aw6]");
DEFINE_INTERFACE_STRING(InstallerCompleteFromOther, "Installation has completed successfully. Remove the installation disk, and restart your computer.");
DEFINE_INTERFACE_STRING(InstallerCompleteFromUSB, "Installation has completed successfully. Disconnect the installation USB, and restart your computer.");
DEFINE_INTERFACE_STRING(InstallerVolumeLabel, "Essence HD");
DEFINE_INTERFACE_STRING(InstallerUseMBR, "Use legacy BIOS boot (select for older computers)");
DEFINE_INTERFACE_STRING(InstallerFailedArchiveCRCError, "The installation data has been corrupted. Create a new installation USB or disk, and try again.");
DEFINE_INTERFACE_STRING(InstallerFailedGeneric, "The installation could not complete. This likely means that the drive you selected is failing. Try installing on a different drive.");
DEFINE_INTERFACE_STRING(InstallerFailedResources, "The installation could not complete. Your computer does not have enough memory to install " SYSTEM_BRAND_SHORT);
DEFINE_INTERFACE_STRING(InstallerNotSupported, "Your computer does not meet the minimum system requirements to install " SYSTEM_BRAND_SHORT ". Remove the installer, and restart your computer.");

// TODO System Monitor.



void _FormatInteger(FormatCallback callback, void *callbackData, long value, int pad = 0, bool simple = false) {
	char buffer[32];

	if (value < 0) {
		callback('-', callbackData);
	} else if (value == 0) {
		for (int i = 0; i < (pad ?: 1); i++) {
			callback('0', callbackData);
		}

		return;
	}

	int bp = 0;

	while (value) {
		int digit = (value % 10);
		if (digit < 0) digit = -digit;
		buffer[bp++] = '0' + digit;
		value /= 10;
	}

	int cr = bp % 3;

	for (int i = 0; i < pad - bp; i++) {
		callback('0', callbackData);
	}

	for (int i = bp - 1; i >= 0; i--, cr--) {
		if (!cr && !pad) {
			if (i != bp - 1 && !simple) callback(',', callbackData);
			cr = 3;
		}

		callback(buffer[i], callbackData);
	}
}

static int utf8_length_char(const char *character) {
	int value;
	UTF8_LENGTH_CHAR(character, value);
	return value;
}

static int utf8_value(const char *character, int maximumLength, int *_length) {
	if (!maximumLength) return 0;
	int length;
	char first = *character; 

	if (!(first & 0x80)) 
		length = 1; 
	else if ((first & 0xE0) == 0xC0) 
		length = 2; 
	else if ((first & 0xF0) == 0xE0) 
		length = 3; 
	else if ((first & 0xF8) == 0xF0) 
		length = 4; 
	else if ((first & 0xFC) == 0xF8) 
		length = 5; 
	else if ((first & 0xFE) == 0xFC) 
		length = 6; 
	else 
		length = 0; 

	if (maximumLength < length) return 0;
	if (_length) *_length = length;

	if (length == 1)
		return (int)first;
	else if (length == 2)
		return (((int)first & 0x1F) << 6) | (((int)character[1]) & 0x3F);
	else if (length == 3)
		return (((int)first & 0xF) << 12) | ((((int)character[1]) & 0x3F) << 6) | (((int)character[2]) & 0x3F);
	else if (length == 4)
		return (((int)first & 0x7) << 18) | ((((int)character[1]) & 0x3F) << 12) | ((((int)character[2]) & 0x3F) << 6) |
		(((int)character[3]) & 0x3F);
	else if (length == 5)
		return (((int)first & 0x3) << 24) | ((((int)character[1]) & 0x3F) << 18) | ((((int)character[2]) & 0x3F) << 12) |
		((((int)character[4]) & 0x3F) << 6) | (((int)character[5]) & 0x3F);
	else if (length == 6)
		return (((int)first & 0x1) << 30) | ((((int)character[1]) & 0x3F) << 24) | ((((int)character[2]) & 0x3F) << 18) |
		((((int)character[4]) & 0x3F) << 12) | ((((int)character[5]) & 0x3F) << 6) | (((int)character[6]) & 0x3F);
	else
		return 0; // Invalid code point
}

static int utf8_value(const char *character) {
	int length;
	UTF8_LENGTH_CHAR(character, length);

	char first = *character;

	int value;

	if (length == 1)
		value = (int)first;
	else if (length == 2)
		value = (((int)first & 0x1F) << 6) | (((int)character[1]) & 0x3F);
	else if (length == 3)
		value = (((int)first & 0xF) << 12) | ((((int)character[1]) & 0x3F) << 6) | (((int)character[2]) & 0x3F);
	else if (length == 4)
		value = (((int)first & 0x7) << 18) | ((((int)character[1]) & 0x3F) << 12) | ((((int)character[2]) & 0x3F) << 6) |
		(((int)character[3]) & 0x3F);
	else if (length == 5)
		value = (((int)first & 0x3) << 24) | ((((int)character[1]) & 0x3F) << 18) | ((((int)character[2]) & 0x3F) << 12) |
		((((int)character[4]) & 0x3F) << 6) | (((int)character[5]) & 0x3F);
	else if (length == 6)
		value = (((int)first & 0x1) << 30) | ((((int)character[1]) & 0x3F) << 24) | ((((int)character[2]) & 0x3F) << 18) |
		((((int)character[4]) & 0x3F) << 12) | ((((int)character[5]) & 0x3F) << 6) | (((int)character[6]) & 0x3F);
	else
		value = 0; // Invalid code point

	return value;
}

static int utf8_encode(int value, char *buffer) {
	if (value < (1 << 7)) {
		if (buffer) {
			buffer[0] = value & 0x7F;
		}

		return 1;
	} else if (value < (1 << 11)) {
		if (buffer) {
			buffer[0] = 0xC0 | ((value >> 6) & 0x1F);
			buffer[1] = 0x80 | (value & 0x3F);
		}

		return 2;
	} else if (value < (1 << 16)) {
		if (buffer) {
			buffer[0] = 0xE0 | ((value >> 12) & 0xF);
			buffer[1] = 0x80 | ((value >> 6) & 0x3F);
			buffer[2] = 0x80 | (value & 0x3F);
		}

		return 3;
	} else if (value < (1 << 21)) {
		if (buffer) {
			buffer[0] = 0xF0 | ((value >> 18) & 0x7);
			buffer[1] = 0x80 | ((value >> 12) & 0x3F);
			buffer[2] = 0x80 | ((value >> 6) & 0x3F);
			buffer[3] = 0x80 | (value & 0x3F);
		}

		return 4;
	}

	return 0; // Cannot encode character
}

static char *utf8_advance(const char *string) {
	int length;
	UTF8_LENGTH_CHAR(string, length);

	if (!length) // Invalid code point 
		return NULL;

	return (char *) string + length;
}

static char *utf8_retreat(const char *string) {
	// Keep going backwards until we find a non continuation character
	do string--;
	while (((*string) & 0xC0) == 0x80);
	return (char *) string;
}

static int utf8_length(char *string, int max_bytes) {
	if (!string)
		return 0;
	if (!(*string))
		return 0;

	if (!max_bytes) return 0;

	int length = 0;
	char *limit = string + max_bytes;

	while ((max_bytes == -1 || string < limit) && *string) {
		if (!string) // Invalid code point
			return -1;

		length++;
		string = utf8_advance(string);
	}

	return length;
}

void WriteCStringToCallback(FormatCallback callback, void *callbackData, const char *cString) {
	while (cString && *cString) {
		callback(utf8_value(cString), callbackData);
		cString = utf8_advance(cString);
	}
}

void _StringFormat(FormatCallback callback, void *callbackData, const char *format, va_list arguments) {
	int c;
	int pad = 0;
	uint32_t flags = 0;

	char buffer[32];
	const char *hexChars = "0123456789ABCDEF";

	while ((c = utf8_value((char *) format))) {
		if (c == '%') {
			repeat:;
			format = utf8_advance((char *) format);
			c = utf8_value((char *) format);

			switch (c) {
				case 'd': {
					long value = va_arg(arguments, long);
					_FormatInteger(callback, callbackData, value, pad, flags & ES_STRING_FORMAT_SIMPLE);
				} break;

				case 'i': {
					int value = va_arg(arguments, int);
					_FormatInteger(callback, callbackData, value, pad, flags & ES_STRING_FORMAT_SIMPLE);
				} break;

				case 'D': {
					long value = va_arg(arguments, long);

					if (value == 0) {
						WriteCStringToCallback(callback, callbackData, interfaceString_CommonEmpty);
					} else if (value < 1000) {
						_FormatInteger(callback, callbackData, value, pad);
						WriteCStringToCallback(callback, callbackData, interfaceString_CommonUnitBytes);
					} else if (value < 1000000) {
						_FormatInteger(callback, callbackData, value / 1000, pad);
						callback('.', callbackData);
						_FormatInteger(callback, callbackData, (value / 100) % 10, pad);
						WriteCStringToCallback(callback, callbackData, interfaceString_CommonUnitKilobytes);
					} else if (value < 1000000000) {
						_FormatInteger(callback, callbackData, value / 1000000, pad);
						callback('.', callbackData);
						_FormatInteger(callback, callbackData, (value / 100000) % 10, pad);
						WriteCStringToCallback(callback, callbackData, interfaceString_CommonUnitMegabytes);
					} else {
						_FormatInteger(callback, callbackData, value / 1000000000, pad);
						callback('.', callbackData);
						_FormatInteger(callback, callbackData, (value / 100000000) % 10, pad);
						WriteCStringToCallback(callback, callbackData, interfaceString_CommonUnitGigabytes);
					}
				} break;

				case 'R': {
					EsRectangle value = va_arg(arguments, EsRectangle);
					callback('{', callbackData);
					_FormatInteger(callback, callbackData, value.l);
					callback('-', callbackData);
					callback('>', callbackData);
					_FormatInteger(callback, callbackData, value.r);
					callback(';', callbackData);
					_FormatInteger(callback, callbackData, value.t);
					callback('-', callbackData);
					callback('>', callbackData);
					_FormatInteger(callback, callbackData, value.b);
					callback('}', callbackData);
				} break;

				case 'X': {
					uintptr_t value = va_arg(arguments, uintptr_t);
					callback(hexChars[(value & 0xF0) >> 4], callbackData);
					callback(hexChars[(value & 0xF)], callbackData);
				} break;

				case 'W': {
					uintptr_t value = va_arg(arguments, uintptr_t);
					callback(hexChars[(value & 0xF000) >> 12], callbackData);
					callback(hexChars[(value & 0xF00) >> 8], callbackData);
					callback(hexChars[(value & 0xF0) >> 4], callbackData);
					callback(hexChars[(value & 0xF)], callbackData);
				} break;

				case 'x': {
					uintptr_t value = va_arg(arguments, uintptr_t);
					bool simple = flags & ES_STRING_FORMAT_SIMPLE;
					if (!simple) callback('0', callbackData);
					if (!simple) callback('x', callbackData);
					int bp = 0;
					while (value) {
						buffer[bp++] = hexChars[value % 16];
						value /= 16;
					}
					int j = 0, k = 0;
					for (int i = 0; i < 16 - bp; i++) {
						callback('0', callbackData);
						j++;k++;if (k != 16 && j == 4 && !simple) { callback('_',callbackData); } j&=3;
					}
					for (int i = bp - 1; i >= 0; i--) {
						callback(buffer[i], callbackData);
						j++;k++;if (k != 16 && j == 4 && !simple) { callback('_',callbackData); } j&=3;
					}
				} break;

				case 'c': {
					callback(va_arg(arguments, int), callbackData);
				} break;

				case '%': {
					callback('%', callbackData);
				} break;

				case 's': {
					size_t length = va_arg(arguments, size_t);
					char *string = va_arg(arguments, char *);
					char *position = string;

					while (position < string + length) {
						callback(utf8_value(position), callbackData);
						position = utf8_advance(position);
					}
				} break;

				case 'z': {
					const char *string = va_arg(arguments, const char *);
					if (!string) string = "[null]";
					WriteCStringToCallback(callback, callbackData, string);
				} break;

				case 'F': {
					double number = va_arg(arguments, double);

					if (__builtin_isnan(number)) {
						WriteCStringToCallback(callback, callbackData, "NaN");
						break;
					} else if (__builtin_isinf(number)) {
						if (number < 0) callback('-', callbackData);
						WriteCStringToCallback(callback, callbackData, "inf");
						break;
					}

					if (number < 0) {
						callback('-', callbackData);
						number = -number;
					}

					int digits[32];
					size_t digitCount = 0;
					const size_t maximumDigits = 12;

					int64_t integer = number;
					number -= integer;
					// number is now in the range [0,1).

					while (number && digitCount <= maximumDigits) {
						// Extract the fractional digits.
						number *= 10;
						int digit = number;
						number -= digit;
						digits[digitCount++] = digit;
					}

					if (digitCount > maximumDigits) {
						if (digits[maximumDigits] >= 5) {
							// Round up.
							for (intptr_t i = digitCount - 2; i >= -1; i--) {
								if (i == -1) { 
									integer++;
								} else {
									digits[i]++;

									if (digits[i] == 10) {
										digits[i] = 0;
									} else {
										break;
									}
								}
							}
						}

						// Hide the last digit.
						digitCount = maximumDigits;
					}

					// Trim trailing zeroes.
					while (digitCount) {
						if (!digits[digitCount - 1]) {
							digitCount--;
						} else {
							break;
						}
					}

					// Integer digits.
					_FormatInteger(callback, callbackData, integer, pad, flags & ES_STRING_FORMAT_SIMPLE);

					// Decimal separator.
					if (digitCount) {
						callback('.', callbackData);
					}

					// Fractional digits.
					for (uintptr_t i = 0; i < digitCount; i++) {
						callback('0' + digits[i], callbackData);
					}
				} break;

				case '*': {
					pad = va_arg(arguments, int);
					goto repeat;
				} break;

				case 'f': {
					flags = va_arg(arguments, uint32_t);
					goto repeat;
				} break;
			}

			pad = 0;
			flags = 0;
		} else {
			callback(c, callbackData);
		}

		format = utf8_advance((char *) format);
	}
}




void StartDebugOutput() {
	if (graphics.target && graphics.target->debugClearScreen && graphics.target->debugPutBlock && !printToDebugger) {
		debugRows = (graphics.height - 1) / VGA_FONT_HEIGHT;
		debugColumns = (graphics.width - 1) / VGA_FONT_WIDTH - 2;
		debugCurrentRow = debugCurrentColumn = 0;
		printToDebugger = true;
		graphics.target->debugClearScreen();
	}
}

void DebugWriteCharacter(uintptr_t character) {
	if (!graphics.target || !graphics.target->debugPutBlock) return;

	if (debugCurrentRow == debugRows) {
		debugCurrentRow = 0;

		// uint64_t start = ProcessorReadTimeStamp();
		// uint64_t end = start + 3000 * KGetTimeStampTicksPerMs();
		// while (ProcessorReadTimeStamp() < end);

		graphics.target->debugClearScreen();
	}

	uintptr_t row = debugCurrentRow;
	uintptr_t column = debugCurrentColumn;

	if (character == '\n') {
		debugCurrentRow++;
		debugCurrentColumn = 0;
		return;
	}

	if (character > 127) character = ' ';
	if (row >= debugRows) return;
	if (column >= debugColumns) return;

	for (int j = 0; j < VGA_FONT_HEIGHT; j++) {
		uint8_t byte = ((uint8_t *) vgaFont)[character * 16 + j];

		for (int i = 0; i < 8; i++) {
			uint8_t bit = byte & (1 << i);
			if (bit) graphics.target->debugPutBlock((column + 1) * 9 + i, row * 16 + j, false);
		}
	}

	debugCurrentColumn++;

	if (debugCurrentColumn == debugColumns) {
		debugCurrentRow++;
		debugCurrentColumn = 4;
	}
}


static void TerminalCallback(int character, void *) {
	if (!character) return;

	KSpinlockAcquire(&terminalLock);
	EsDefer(KSpinlockRelease(&terminalLock));

	if (sizeof(kernelLog)) {
		kernelLog[kernelLogPosition] = character;
		kernelLogPosition++;
		if (kernelLogPosition == sizeof(kernelLog)) kernelLogPosition = 0;
	}

#ifdef VGA_TEXT_MODE
	{
		if (character == '\n') {
			terminalPosition = terminalPosition - (terminalPosition % 80) + 80;
		} else {
			TERMINAL_ADDRESS[terminalPosition] = (uint16_t) character | 0x0700;
			terminalPosition++;
		}

		if (terminalPosition >= 80 * 25) {
			for (int i = 80; i < 80 * 25; i++) {
				TERMINAL_ADDRESS[i - 80] = TERMINAL_ADDRESS[i];
			}

			for (int i = 80 * 24; i < 80 * 25; i++) {
				TERMINAL_ADDRESS[i] = 0x700;
			}

			terminalPosition -= 80;

			// uint64_t start = ProcessorReadTimeStamp();
			// uint64_t end = start + 250 * KGetTimeStampTicksPerMs();
			// while (ProcessorReadTimeStamp() < end);
		}

		{
			ProcessorOut8(0x3D4, 0x0F);
			ProcessorOut8(0x3D5, terminalPosition);
			ProcessorOut8(0x3D4, 0x0E);
			ProcessorOut8(0x3D5, terminalPosition >> 8);
		}
	}
#endif

	{
		ProcessorDebugOutputByte((uint8_t) character);

		if (character == '\n') {
			ProcessorDebugOutputByte((uint8_t) 13);
		}
	}

	if (printToDebugger) {
		DebugWriteCharacter(character);
		if (character == '\t') DebugWriteCharacter(' ');
	}
}

void EsPrint(const char *format, ...) {
	KSpinlockAcquire(&printLock);
	EsDefer(KSpinlockRelease(&printLock));

	va_list arguments;
	va_start(arguments, format);
	_StringFormat(TerminalCallback, (void *) 0x0700, format, arguments);
	va_end(arguments);
}



void MMArchInvalidatePages(uintptr_t virtualAddressStart, uintptr_t pageCount) {
	// This must be done with spinlock acquired, otherwise this processor could change.

	// TODO Only send the IPI to the processors that are actually executing threads with the virtual address space.
	// 	Currently we only support the kernel's virtual address space, so this'll apply to all processors.
	// 	If we use Intel's PCID then we may have to send this to all processors anyway.
	// 	And we'll probably also have to be careful with shared memory regions.
	//	...actually I think we might not bother doing this.

	KSpinlockAcquire(&ipiLock);
	tlbShootdownVirtualAddress = virtualAddressStart;
	tlbShootdownPageCount = pageCount;
	ArchCallFunctionOnAllProcessors(TLBShootdownCallback, true);
	KSpinlockRelease(&ipiLock);
}


bool MMUnmapFilePage(uintptr_t frameNumber) {
	KMutexAssertLocked(&pmm.pageFrameMutex);
	MMPageFrame *frame = pmm.pageFrames + frameNumber;

	if (frame->state != MMPageFrame::ACTIVE || !frame->active.references) {
		KernelPanic("MMUnmapFilePage - Corrupt page frame database (%d/%x).\n", frameNumber, frame);
	}

	// Decrease the reference count.
	frame->active.references--;

	if (frame->active.references) {
		return false;
	}

	// If there are no more references, then the frame can be moved to the standby or modified list.

	// EsPrint("Unmap file page: %x\n", frameNumber << K_PAGE_BITS);

	frame->state = MMPageFrame::STANDBY;
	pmm.countStandbyPages++;

	if (*frame->cacheReference != ((frameNumber << K_PAGE_BITS) | MM_SHARED_ENTRY_PRESENT)) {
		KernelPanic("MMUnmapFilePage - Corrupt shared reference back pointer in frame %x.\n", frame);
	}

	frame->list.next = pmm.firstStandbyPage;
	frame->list.previous = &pmm.firstStandbyPage;
	if (pmm.firstStandbyPage) pmm.pageFrames[pmm.firstStandbyPage].list.previous = &frame->list.next;
	if (!pmm.lastStandbyPage) pmm.lastStandbyPage = frameNumber;
	pmm.firstStandbyPage = frameNumber;

	MMUpdateAvailablePageCount(true);

	pmm.countActivePages--;
	return true;
}



void MMArchUnmapPages(MMSpace *space, uintptr_t virtualAddressStart, uintptr_t pageCount, unsigned flags, size_t unmapMaximum, uintptr_t *resumePosition) {
	// We can't let anyone use the unmapped pages until they've been invalidated on all processors.
	// This also synchronises modified bit updating.
	KMutexAcquire(&pmm.pageFrameMutex);
	EsDefer(KMutexRelease(&pmm.pageFrameMutex));

	KMutexAcquire(&space->data.mutex);
	EsDefer(KMutexRelease(&space->data.mutex));

#ifdef ES_ARCH_X86_64
	uintptr_t tableBase = virtualAddressStart & 0x0000FFFFFFFFF000;
#else
	uintptr_t tableBase = virtualAddressStart & 0xFFFFF000;
#endif
	uintptr_t start = resumePosition ? *resumePosition : 0;

	// TODO Freeing newly empty page tables.
	// 	- What do we need to invalidate when we do this?

	for (uintptr_t i = start; i < pageCount; i++) {
		uintptr_t virtualAddress = (i << K_PAGE_BITS) + tableBase;

#ifdef ES_ARCH_X86_64
		if ((PAGE_TABLE_L4[virtualAddress >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 3)] & 1) == 0) {
			i -= (virtualAddress >> K_PAGE_BITS) % (1 << (ENTRIES_PER_PAGE_TABLE_BITS * 3));
			i += (1 << (ENTRIES_PER_PAGE_TABLE_BITS * 3));
			continue;
		}

		if ((PAGE_TABLE_L3[virtualAddress >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 2)] & 1) == 0) {
			i -= (virtualAddress >> K_PAGE_BITS) % (1 << (ENTRIES_PER_PAGE_TABLE_BITS * 2));
			i += (1 << (ENTRIES_PER_PAGE_TABLE_BITS * 2));
			continue;
		}
#endif

		if ((PAGE_TABLE_L2[virtualAddress >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 1)] & 1) == 0) {
			i -= (virtualAddress >> K_PAGE_BITS) % (1 << (ENTRIES_PER_PAGE_TABLE_BITS * 1));
			i += (1 << (ENTRIES_PER_PAGE_TABLE_BITS * 1));
			continue;
		}

		uintptr_t indexL1 = virtualAddress >> (K_PAGE_BITS + ENTRIES_PER_PAGE_TABLE_BITS * 0);

		uintptr_t translation = PAGE_TABLE_L1[indexL1];

		if (!(translation & 1)) {
			// The page wasn't mapped.
			continue;
		}

		bool copy = translation & (1 << 9);

		if (copy && (flags & MM_UNMAP_PAGES_BALANCE_FILE) && (~flags & MM_UNMAP_PAGES_FREE_COPIED)) {
			// Ignore copied pages when balancing file mappings.
			continue;
		}

		if ((~translation & (1 << 5)) || (~translation & (1 << 6))) {
			// See MMArchMapPage for a discussion of why these bits must be set.
			KernelPanic("MMArchUnmapPages - Page found without accessed or dirty bit set (virtualAddress: %x, translation: %x).\n", 
					virtualAddress, translation);
		}

		PAGE_TABLE_L1[indexL1] = 0;

#ifdef ES_ARCH_X86_64
		uintptr_t physicalAddress = translation & 0x0000FFFFFFFFF000;
#else
		uintptr_t physicalAddress = translation & 0xFFFFF000;
#endif

		if ((flags & MM_UNMAP_PAGES_FREE) || ((flags & MM_UNMAP_PAGES_FREE_COPIED) && copy)) {
			MMPhysicalFree(physicalAddress, true);
		} else if (flags & MM_UNMAP_PAGES_BALANCE_FILE) {
			// It's safe to do this before page invalidation,
			// because the page fault handler is synchronised with the same mutexes acquired above.

			if (MMUnmapFilePage(physicalAddress >> K_PAGE_BITS)) {
				if (resumePosition) {
					if (!unmapMaximum--) {
						*resumePosition = i;
						break;
					}
				}
			}
		}
	}

	MMArchInvalidatePages(virtualAddressStart, pageCount);
}



void MMPhysicalFree(uintptr_t page, bool mutexAlreadyAcquired, size_t count) {
	if (!page) KernelPanic("MMPhysicalFree - Invalid page.\n");
	if (mutexAlreadyAcquired) KMutexAssertLocked(&pmm.pageFrameMutex);
	else KMutexAcquire(&pmm.pageFrameMutex);
	if (!pmm.pageFrameDatabaseInitialised) KernelPanic("MMPhysicalFree - PMM not yet initialised.\n");

	page >>= K_PAGE_BITS;

	MMPhysicalInsertFreePagesStart();

	for (uintptr_t i = 0; i < count; i++, page++) {
		MMPageFrame *frame = pmm.pageFrames + page;

		if (frame->state == MMPageFrame::FREE) {
			KernelPanic("MMPhysicalFree - Attempting to free a FREE page.\n");
		}

		if (pmm.commitFixedLimit) {
			pmm.countActivePages--;
		}

		MMPhysicalInsertFreePagesNext(page);
	}

	MMPhysicalInsertFreePagesEnd();

	if (!mutexAlreadyAcquired) KMutexRelease(&pmm.pageFrameMutex);
}

void MMCheckUnusable(uintptr_t physicalStart, size_t bytes) {
	for (uintptr_t i = physicalStart / K_PAGE_SIZE; i < (physicalStart + bytes + K_PAGE_SIZE - 1) / K_PAGE_SIZE
			&& i < pmm.pageFrameDatabaseCount; i++) {
		if (pmm.pageFrames[i].state != MMPageFrame::UNUSABLE) {
			KernelPanic("MMCheckUnusable - Page frame at address %x should be unusable.\n", i * K_PAGE_SIZE);
		}
	}
}

void KernelPanic(const char *format, ...) {
	ProcessorDisableInterrupts();
	ProcessorSendIPI(KERNEL_PANIC_IPI, true);

	// Disable synchronisation objects. The panic IPI must be sent before this, 
	// so other processors don't start getting "mutex not correctly acquired" panics.
	scheduler.panic = true; 

	if (debugKeyPressed) {
		DriversDumpState();
	}

	StartDebugOutput();

	EsPrint("\n--- System Error ---\n>> ");

	va_list arguments;
	va_start(arguments, format);
	_StringFormat(TerminalCallback, (void *) 0x4F00, format, arguments);
	va_end(arguments);

	EsPrint("Current thread = %x\n", GetCurrentThread());
	EsPrint("Trace: %x\n", __builtin_return_address(0));
#ifdef ES_ARCH_X86_64
	EsPrint("RSP: %x; RBP: %x\n", ProcessorGetRSP(), ProcessorGetRBP());
#endif
	// EsPrint("Memory: %x/%x\n", pmm.pagesAllocated, pmm.startPageCount);

	{
		EsPrint("Threads:\n");

		LinkedItem<Thread> *item = scheduler.allThreads.firstItem;

		while (item) {
			Thread *thread = item->thisItem;

#ifdef ES_ARCH_X86_64
			EsPrint("%z %d %x @%x:%x ", (GetCurrentThread() == thread) ? "=>" : "  ", 
					thread->id, thread, thread->interruptContext->rip, thread->interruptContext->rbp);
#endif

			if (thread->state == THREAD_WAITING_EVENT) {
				EsPrint("WaitEvent(Count:%d, %x) ", thread->blocking.eventCount, thread->blocking.events[0]);
			} else if (thread->state == THREAD_WAITING_MUTEX) {
				EsPrint("WaitMutex(%x, Owner:%d) ", thread->blocking.mutex, thread->blocking.mutex->owner->id);
			} else if (thread->state == THREAD_WAITING_WRITER_LOCK) {
				EsPrint("WaitWriterLock(%x, %d) ", thread->blocking.writerLock, thread->blocking.writerLockType);
			}

			Process *process = thread->process;
			EsPrint("%z:%z\n", process->cExecutableName, thread->cName);

			item = item->nextItem;
		}
	}

	for (uintptr_t i = 0; i < KGetCPUCount(); i++) {
		CPULocalStorage *local = KGetCPULocal(i);

		if (local->panicContext) {
#ifdef ES_ARCH_X86_64
			EsPrint("CPU %d LS %x RIP/RBP %x:%x TID %d\n", local->processorID, local,
					local->panicContext->rip, local->panicContext->rbp,
					local->currentThread ? local->currentThread->id : 0);
#endif
		}
	}

#ifdef POST_PANIC_DEBUGGING
	uintptr_t kernelLogEnd = kernelLogPosition;
	EsPrint("Press 'D' to enter debugger.\n");

	while (true) {
		int key = KWaitKey();
		if (key == ES_SCANCODE_D) break;
		if (key == -1) ProcessorHalt();
	}

	graphics.debuggerActive = true;

	while (true) {
#ifdef VGA_TEXT_MODE
		for (uintptr_t i = 0; i < 80 * 25; i++) {
			TERMINAL_ADDRESS[i] = 0x0700;
		}

		terminalPosition = 80;
#else
		graphics.target->debugClearScreen();

		debugCurrentRow = debugCurrentColumn = 0;
#endif


		EsPrint("0 - view log\n1 - reset\n2 - view pmem\n3 - view vmem\n4 - stack trace\n");

		int key = KWaitKey();

		if (key == ES_SCANCODE_0) {
			uintptr_t position = 0, nextPosition = 0;
			uintptr_t x = 0, y = 0;

#ifdef VGA_TEXT_MODE
			for (uintptr_t i = 0; i < 80 * 25; i++) {
				TERMINAL_ADDRESS[i] = 0x0700;
			}
#else
			graphics.target->debugClearScreen();
#endif

			while (position < kernelLogEnd) {
				char c = kernelLog[position];

				if (c != '\n') {
#ifdef VGA_TEXT_MODE
					TERMINAL_ADDRESS[x + y * 80] = c | 0x0700;
#else
					debugCurrentRow = y, debugCurrentColumn = x;
					DebugWriteCharacter(c);
#endif
				}

				x++;

				if (x == 
#ifdef VGA_TEXT_MODE
						80 
#else
						debugColumns
#endif
						|| c == '\n') {
					x = 0;
					y++;

					if (y == 1) {
						nextPosition = position;
					}
				}

				if (y == 
#ifdef VGA_TEXT_MODE
						25
#else
						debugRows
#endif
						) {
					while (true) {
						int key = KWaitKey();

						if (key == ES_SCANCODE_SPACE || key == ES_SCANCODE_DOWN_ARROW) {
							position = nextPosition;
							break;
						} else if (key == ES_SCANCODE_UP_ARROW) {
							position = nextPosition;
							if (position < 240) position = 0;
							else position -= 240;
							break;
						}
					}

#ifdef VGA_TEXT_MODE
					for (uintptr_t i = 0; i < 80 * 25; i++) {
						TERMINAL_ADDRESS[i] = 0x0700;
					}
#else
					graphics.target->debugClearScreen();
#endif

					y = 0;
				}

				position++;
			}

			KWaitKey();
		} else if (key == ES_SCANCODE_1) {
			ProcessorReset();
		} else if (key == ES_SCANCODE_2) {
			EsPrint("Enter address: ");
			uintptr_t address = DebugReadNumber();
			uintptr_t offset = address & (K_PAGE_SIZE - 1);
			MMRemapPhysical(kernelMMSpace, pmm.pmManipulationRegion, address - offset);
			uintptr_t *data = (uintptr_t *) ((uint8_t *) pmm.pmManipulationRegion + offset);

			for (uintptr_t i = 0; i < 8 && (offset + 8 * sizeof(uintptr_t) < K_PAGE_SIZE); i++) {
				EsPrint("\n%x - %x\n", address + 8 * sizeof(uintptr_t), data[i]);
			}

			while (KWaitKey() != ES_SCANCODE_ENTER);
		} else if (key == ES_SCANCODE_3) {
			EsPrint("Enter address: ");
			uintptr_t address = DebugReadNumber();
			uintptr_t offset = address & (K_PAGE_SIZE - 1);
			uintptr_t *data = (uintptr_t *) address;

			for (uintptr_t i = 0; i < 8 && (offset + i * sizeof(uintptr_t) < K_PAGE_SIZE); i++) {
				EsPrint("\n%x - %x", address + i * sizeof(uintptr_t), data[i]);
			}

			while (KWaitKey() != ES_SCANCODE_ENTER);
		} else if (key == ES_SCANCODE_4) {
			EsPrint("Enter RBP: ");
			uintptr_t address = DebugReadNumber();

			while (address) {
				EsPrint("\n%x", ((uintptr_t *) address)[1]);
				address = ((uintptr_t *) address)[0];
			}

			while (KWaitKey() != ES_SCANCODE_ENTER);
		}
	}
#endif

	ProcessorHalt();
}

void __KernelLog(const char *format, ...) {
	va_list arguments;
	va_start(arguments, format);
	_StringFormat(TerminalCallback, nullptr, format, arguments);
	va_end(arguments);
}


void KernelLog(KLogLevel level, const char *subsystem, const char *event, const char *format, ...) {
	if (level == LOG_VERBOSE) return;
	(void) event;

	KSpinlockAcquire(&printLock);
	EsDefer(KSpinlockRelease(&printLock));

	__KernelLog("[%z:%z] ", level == LOG_INFO ? "Info" : level == LOG_ERROR ? "**Error**" : level == LOG_VERBOSE ? "Verbose" : "", subsystem);

	va_list arguments;
	va_start(arguments, format);
	_StringFormat(TerminalCallback, nullptr, format, arguments);
	va_end(arguments);
}

uintptr_t Syscall(uintptr_t argument0, uintptr_t argument1, uintptr_t argument2, uintptr_t returnAddress, uintptr_t argument3, uintptr_t argument4, uintptr_t *userStackPointer) {
    (void)argument0;
    (void)argument1;
    (void)argument2;
    (void)argument3;
    (void)argument4;
    (void)userStackPointer;
    (void)returnAddress;
    return 0;
	//(void) returnAddress;
	//return DoSyscall((EsSyscallType) argument0, argument1, argument2, argument3, argument4, false, nullptr, userStackPointer);
}


void InterruptHandler(InterruptContext *context) {
	if (scheduler.panic && context->interruptNumber != 2) {
		return;
	}

	if (ProcessorAreInterruptsEnabled()) {
		KernelPanic("InterruptHandler - Interrupts were enabled at the start of an interrupt handler.\n");
	}

	CPULocalStorage *local = GetLocalStorage();
	uintptr_t interrupt = context->interruptNumber;

	if (local && local->spinlockCount && context->cr8 != 0xE) {
		KernelPanic("InterruptHandler - Local spinlockCount is %d but interrupts were enabled (%x/%x).\n", local->spinlockCount, local, context);
	}

#if 0
#ifdef EARLY_DEBUGGING
#ifdef VGA_TEXT_MODE
	if (local) {
		TERMINAL_ADDRESS[local->processorID] += 0x1000;
	}
#else
	if (graphics.target && graphics.target->debugPutBlock) {
		graphics.target->debugPutBlock(local->processorID * 3 + 3, 3, true);
		graphics.target->debugPutBlock(local->processorID * 3 + 4, 3, true);
		graphics.target->debugPutBlock(local->processorID * 3 + 3, 4, true);
		graphics.target->debugPutBlock(local->processorID * 3 + 4, 4, true);
	}
#endif
#endif
#endif

	if (interrupt < 0x20) {
		// If we received a non-maskable interrupt, halt execution.
		if (interrupt == 2) {
			local->panicContext = context;
			ProcessorHalt();
		}

		bool supervisor = (context->cs & 3) == 0;

		if (!supervisor) {
			// EsPrint("User interrupt: %x/%x/%x\n", interrupt, context->cr2, context->errorCode);

			if (context->cs != 0x5B && context->cs != 0x6B) {
				KernelPanic("InterruptHandler - Unexpected value of CS 0x%X\n", context->cs);
			}

			if (GetCurrentThread()->isKernelThread) {
				KernelPanic("InterruptHandler - Kernel thread executing user code. (1)\n");
			}

			// User-code exceptions are *basically* the same thing as system calls.
			Thread *currentThread = GetCurrentThread();
			ThreadTerminatableState previousTerminatableState;
			previousTerminatableState = currentThread->terminatableState;
			currentThread->terminatableState = THREAD_IN_SYSCALL;

			if (local && local->spinlockCount) {
				KernelPanic("InterruptHandler - User exception occurred with spinlock acquired.\n");
			}

			// Re-enable interrupts during exception handling.
			ProcessorEnableInterrupts();

			if (interrupt == 14) {
				bool success = MMArchHandlePageFault(context->cr2, (context->errorCode & 2) ? MM_HANDLE_PAGE_FAULT_WRITE : 0);

				if (success) {
					goto resolved;
				}
			}

			if (interrupt == 0x13) {
				EsPrint("ProcessorReadMXCSR() = %x\n", ProcessorReadMXCSR());
			}

			// TODO Usermode exceptions and debugging.
			KernelLog(LOG_ERROR, "Arch", "unhandled userland exception", 
					"InterruptHandler - Exception (%z) in userland process (%z).\nRIP = %x (CPU %d)\nRSP = %x\nX86_64 error codes: [err] %x, [cr2] %x\n", 
					exceptionInformation[interrupt], 
					currentThread->process->cExecutableName,
					context->rip, local->processorID, context->rsp, context->errorCode, context->cr2);

			EsPrint("Attempting to make a stack trace...\n");

			{
				uint64_t rbp = context->rbp;
				int traceDepth = 0;

				while (rbp && traceDepth < 32) {
					uint64_t value;
					if (!MMArchIsBufferInUserRange(rbp, 16)) break;
					if (!MMArchSafeCopy((uintptr_t) &value, rbp + 8, sizeof(uint64_t))) break;
					EsPrint("\t%d: %x\n", ++traceDepth, value);
					if (!value) break;
					if (!MMArchSafeCopy((uintptr_t) &rbp, rbp, sizeof(uint64_t))) break;
				}
			}

			EsPrint("Stack trace complete.\n");

			EsCrashReason crashReason;
			EsMemoryZero(&crashReason, sizeof(EsCrashReason));
			crashReason.errorCode = ES_FATAL_ERROR_PROCESSOR_EXCEPTION;
			crashReason.duringSystemCall = (EsSyscallType) -1;
			ProcessCrash(currentThread->process, &crashReason);

			resolved:;

			if (currentThread->terminatableState != THREAD_IN_SYSCALL) {
				KernelPanic("InterruptHandler - Thread changed terminatable status during interrupt.\n");
			}

			currentThread->terminatableState = previousTerminatableState;

			if (currentThread->terminating || currentThread->paused) {
				ProcessorFakeTimerInterrupt();
			}

			// Disable interrupts when we're done.
			ProcessorDisableInterrupts();

			// EsPrint("User interrupt complete.\n", interrupt, context->cr2);
		} else {
			if (context->cs != 0x48) {
				KernelPanic("InterruptHandler - Unexpected value of CS 0x%X\n", context->cs);
			}

			if (interrupt == 14) {
				// EsPrint("PF: %x\n", context->cr2);

				if ((context->errorCode & (1 << 3))) {
					goto fault;
				}

				if ((context->flags & 0x200) && context->cr8 != 0xE) {
					ProcessorEnableInterrupts();
				}

				if (local && local->spinlockCount && ((context->cr2 >= 0xFFFF900000000000 && context->cr2 < 0xFFFFF00000000000) 
							|| context->cr2 < 0x8000000000000000)) {
					KernelPanic("HandlePageFault - Page fault occurred with spinlocks active at %x (S = %x, B = %x, LG = %x, CR2 = %x, local = %x).\n", 
							context->rip, context->rsp, context->rbp, local->currentThread->lastKnownExecutionAddress, context->cr2, local);
				}
				
				if (!MMArchHandlePageFault(context->cr2, MM_HANDLE_PAGE_FAULT_FOR_SUPERVISOR
							| ((context->errorCode & 2) ? MM_HANDLE_PAGE_FAULT_WRITE : 0))) {
					if (local->currentThread->inSafeCopy && context->cr2 < 0x8000000000000000) {
						context->rip = context->r8; // See definition of MMArchSafeCopy.
					} else {
						goto fault;
					}
				}

				ProcessorDisableInterrupts();
			} else {
				fault:
				KernelPanic("Unresolvable processor exception encountered in supervisor mode.\n%z\nRIP = %x (CPU %d)\nX86_64 error codes: [err] %x, [cr2] %x\n"
						"Stack: [rsp] %x, [rbp] %x\nRegisters: [rax] %x, [rbx] %x, [rsi] %x, [rdi] %x.\nThread ID = %d\n", 
						exceptionInformation[interrupt], context->rip, local ? local->processorID : -1, context->errorCode, context->cr2, 
						context->rsp, context->rbp, context->rax, context->rbx, context->rsi, context->rdi, 
						local && local->currentThread ? local->currentThread->id : -1);
			}
		}
	} else if (interrupt == 0xFF) {
		// Spurious interrupt (APIC), ignore.
	} else if (interrupt >= 0x20 && interrupt < 0x30) {
		// Spurious interrupt (PIC), ignore.
	} else if (interrupt >= 0xF0 && interrupt < 0xFE) {
		// IPI.
		// Warning: This code executes at a special IRQL! Do not acquire spinlocks!!

		if (interrupt == CALL_FUNCTION_ON_ALL_PROCESSORS_IPI) {
			if (!callFunctionOnAllProcessorsRemaining) KernelPanic("InterruptHandler - callFunctionOnAllProcessorsRemaining is 0 (a).\n");
			callFunctionOnAllProcessorsCallback();
			if (!callFunctionOnAllProcessorsRemaining) KernelPanic("InterruptHandler - callFunctionOnAllProcessorsRemaining is 0 (b).\n");
			__sync_fetch_and_sub(&callFunctionOnAllProcessorsRemaining, 1);
		}

		LapicEndOfInterrupt();
	} else if (interrupt >= INTERRUPT_VECTOR_MSI_START && interrupt < INTERRUPT_VECTOR_MSI_START + INTERRUPT_VECTOR_MSI_COUNT && local) {
		KSpinlockAcquire(&irqHandlersLock);
		MSIHandler handler = msiHandlers[interrupt - INTERRUPT_VECTOR_MSI_START];
		KSpinlockRelease(&irqHandlersLock);
		local->irqSwitchThread = false;

		if (!handler.callback) {
			KernelLog(LOG_ERROR, "Arch", "unexpected MSI", "Unexpected MSI vector %X (no handler).\n", interrupt);
		} else {
			handler.callback(interrupt - INTERRUPT_VECTOR_MSI_START, handler.context);
		}

		if (local->irqSwitchThread && scheduler.started && local->schedulerReady) {
			scheduler.Yield(context); // LapicEndOfInterrupt is called in PostContextSwitch.
			KernelPanic("InterruptHandler - Returned from Scheduler::Yield.\n");
		}

		LapicEndOfInterrupt();
	} else if (local) {
		// IRQ.

		local->irqSwitchThread = false;

		if (interrupt == TIMER_INTERRUPT) {
			local->irqSwitchThread = true;
		} else if (interrupt == YIELD_IPI) {
			local->irqSwitchThread = true;
			GetCurrentThread()->receivedYieldIPI = true;
		} else if (interrupt >= IRQ_BASE && interrupt < IRQ_BASE + 0x20) {
            KernelPanic("PCI involved, not implemented\n");
			//GetLocalStorage()->inIRQ = true;

			//uintptr_t line = interrupt - IRQ_BASE;
			//KernelLog(LOG_VERBOSE, "Arch", "IRQ start", "IRQ start %d.\n", line);
			//KSpinlockAcquire(&irqHandlersLock);

			//for (uintptr_t i = 0; i < sizeof(irqHandlers) / sizeof(irqHandlers[0]); i++) {
				//IRQHandler handler = irqHandlers[i];
				//if (!handler.callback) continue;

				//if (handler.line == -1) {
					//// Before we get the actual IRQ line information from ACPI (which might take it a while),
					//// only test that the IRQ is in the correct range for PCI interrupts.
					//// This is a bit slower because we have to dispatch the interrupt to more drivers,
					//// but it shouldn't break anything because they're all supposed to handle overloading anyway.
					//// This is mess. Hopefully all modern computers will use MSIs for anything important.

					//if (line != 9 && line != 10 && line != 11) {
						//continue;
					//} else {
						//uint8_t mappedLine = pciIRQLines[handler.pciDevice->slot][handler.pciDevice->interruptPin - 1];

						//if (mappedLine && line != mappedLine) {
							//continue;
						//}
					//}
				//} else {
					//if ((uintptr_t) handler.line != line) {
						//continue;
					//}
				//}

				//KSpinlockRelease(&irqHandlersLock);
				//handler.callback(interrupt - IRQ_BASE, handler.context);
				//KSpinlockAcquire(&irqHandlersLock);
			//}

			//KSpinlockRelease(&irqHandlersLock);
			//KernelLog(LOG_VERBOSE, "Arch", "IRQ end", "IRQ end %d.\n", line);

			//GetLocalStorage()->inIRQ = false;
		}

		if (local->irqSwitchThread && scheduler.started && local->schedulerReady) {
			scheduler.Yield(context); // LapicEndOfInterrupt is called in PostContextSwitch.
			KernelPanic("InterruptHandler - Returned from Scheduler::Yield.\n");
		}

		LapicEndOfInterrupt();
	}

	// Sanity check.
	ContextSanityCheck(context);

	if (ProcessorAreInterruptsEnabled()) {
		KernelPanic("InterruptHandler - Interrupts were enabled while returning from an interrupt handler.\n");
	}
}

struct KMSIInformation
{
    uintptr_t address;
    uintptr_t data;
    uintptr_t tag;
};

void KUnregisterMSI(uintptr_t tag) {
	KSpinlockAcquire(&irqHandlersLock);
	EsDefer(KSpinlockRelease(&irqHandlersLock));
	msiHandlers[tag].callback = nullptr;
}

KMSIInformation KRegisterMSI(KIRQHandler handler, void *context, const char *cOwnerName) {
	KSpinlockAcquire(&irqHandlersLock);
	EsDefer(KSpinlockRelease(&irqHandlersLock));

	for (uintptr_t i = 0; i < INTERRUPT_VECTOR_MSI_COUNT; i++) {
		if (msiHandlers[i].callback) continue;
		msiHandlers[i] = { handler, context };

		// TODO Selecting the best target processor.
		// 	Currently this sends everything to processor 0.

		KernelLog(LOG_INFO, "Arch", "register MSI", "Register MSI with vector %X for '%z'.\n", 
				INTERRUPT_VECTOR_MSI_START + i, cOwnerName);

		return {
			.address = 0xFEE00000,
			.data = INTERRUPT_VECTOR_MSI_START + i,
			.tag = i,
		};
	}

	return {};
}

bool SetupInterruptRedirectionEntry(uintptr_t _line) {
	KSpinlockAssertLocked(&irqHandlersLock);

	static uint32_t alreadySetup = 0;

	if (alreadySetup & (1 << _line)) {
		return true;
	}

	// Work out which interrupt the IoApic will sent to the processor.
	// TODO Use the upper 4 bits for IRQ priority.

	uintptr_t line = _line;
	uintptr_t thisProcessorIRQ = line + IRQ_BASE;

	bool activeLow = false;
	bool levelTriggered = true;

	// If there was an interrupt override entry in the MADT table,
	// then we'll have to use that number instead.

	for (uintptr_t i = 0; i < acpi.interruptOverrideCount; i++) {
		ACPIInterruptOverride *interruptOverride = acpi.interruptOverrides + i;

		if (interruptOverride->sourceIRQ == line) {
			line = interruptOverride->gsiNumber;
			activeLow = interruptOverride->activeLow;
			levelTriggered = interruptOverride->levelTriggered;
			break;
		}
	}

	KernelLog(LOG_INFO, "Arch", "IRQ flags", "SetupInterruptRedirectionEntry - IRQ %d is active %z, %z triggered.\n",
			line, activeLow ? "low" : "high", levelTriggered ? "level" : "edge");

	ACPIIoApic *ioApic;
	bool foundIoApic = false;

	// Look for the IoApic to which this interrupt is sent.

	for (uintptr_t i = 0; i < acpi.ioapicCount; i++) {
		ioApic = acpi.ioApics + i;
		if (line >= ioApic->gsiBase && line < (ioApic->gsiBase + (0xFF & (ACPIIoApicReadRegister(ioApic, 1) >> 16)))) {
			foundIoApic = true;
			line -= ioApic->gsiBase;
			break;
		}
	}

	// We couldn't find the IoApic that handles this interrupt.

	if (!foundIoApic) {
		KernelLog(LOG_ERROR, "Arch", "no IOAPIC", "SetupInterruptRedirectionEntry - Could not find an IOAPIC handling interrupt line %d.\n", line);
		return false;
	}

	// A normal priority interrupt.

	uintptr_t redirectionTableIndex = line * 2 + 0x10;
	uint32_t redirectionEntry = thisProcessorIRQ;
	if (activeLow) redirectionEntry |= (1 << 13);
	if (levelTriggered) redirectionEntry |= (1 << 15);

	// Send the interrupt to the processor that registered the interrupt.

	ACPIIoApicWriteRegister(ioApic, redirectionTableIndex, 1 << 16); // Mask the interrupt while we modify the entry.
	ACPIIoApicWriteRegister(ioApic, redirectionTableIndex + 1, GetLocalStorage()->archCPU->apicID << 24); 
	ACPIIoApicWriteRegister(ioApic, redirectionTableIndex, redirectionEntry);

	alreadySetup |= 1 << _line;
	return true;
}

struct PCIDevice;

bool KRegisterIRQ(intptr_t line, KIRQHandler handler, void *context, const char *cOwnerName, PCIDevice *pciDevice) {
	if (line == -1 && !pciDevice) {
		KernelPanic("KRegisterIRQ - Interrupt line is %d, and pciDevice is %x.\n", line, pciDevice);
	}

	// Save the handler callback and context.

	if (line > 0x20 || line < -1) KernelPanic("KRegisterIRQ - Unexpected IRQ %d\n", line);
	bool found = false;

	KSpinlockAcquire(&irqHandlersLock);

	for (uintptr_t i = 0; i < sizeof(irqHandlers) / sizeof(irqHandlers[0]); i++) {
		if (!irqHandlers[i].callback) {
			found = true;
			irqHandlers[i].callback = handler;
			irqHandlers[i].context = context;
			irqHandlers[i].line = line;
			irqHandlers[i].pciDevice = pciDevice;
			irqHandlers[i].cOwnerName = cOwnerName;
			break;
		}
	}

	bool result = true;

	if (!found) {
		KernelLog(LOG_ERROR, "Arch", "too many IRQ handlers", "The limit of IRQ handlers was reached (%d), and the handler for '%z' was not registered.\n",
				sizeof(irqHandlers) / sizeof(irqHandlers[0]), cOwnerName);
		result = false;
	} else {
		KernelLog(LOG_INFO, "Arch", "register IRQ", "KRegisterIRQ - Registered IRQ %d to '%z'.\n", line, cOwnerName);

		if (line != -1) {
			if (!SetupInterruptRedirectionEntry(line)) {
				result = false;
			}
		} else {
			SetupInterruptRedirectionEntry(9);
			SetupInterruptRedirectionEntry(10);
			SetupInterruptRedirectionEntry(11);
		}
	}

	KSpinlockRelease(&irqHandlersLock);

	return result;
}

uint64_t KGetTimeInMs() {
	return scheduler.timeMs;
}

struct KTimeout { 
	uint64_t end; 
	inline KTimeout(int ms) { end = KGetTimeInMs() + ms; } 
	inline bool Hit() { return KGetTimeInMs() >= end; }
};

// my code
typedef uint8_t  u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t   s8;
typedef int16_t  s16;
typedef int32_t  s32;
typedef int64_t  s64;


uint32_t arch_pci_read_config(u8 bus, u8 device, u8 function, u8 offset, u32 size = 32) {
	KSpinlockAcquire(&pciConfigSpinlock);
	EsDefer(KSpinlockRelease(&pciConfigSpinlock));
	if (offset & 3) KernelPanic("KPCIReadConfig - offset is not 4-byte aligned.");
	ProcessorOut32(IO_PCI_CONFIG, (uint32_t) (0x80000000 | (bus << 16) | (device << 11) | (function << 8) | offset));
	if (size == 8) return ProcessorIn8(IO_PCI_DATA);
	if (size == 16) return ProcessorIn16(IO_PCI_DATA);
	if (size == 32) return ProcessorIn32(IO_PCI_DATA);
	KernelPanic("PCIController::ReadConfig - Invalid size %d.\n", size);
	return 0;
}

void arch_pci_write_config(uint8_t bus, uint8_t device, uint8_t function, uint8_t offset, uint32_t value, u32 size = 0) {
	KSpinlockAcquire(&pciConfigSpinlock);
	EsDefer(KSpinlockRelease(&pciConfigSpinlock));
	if (offset & 3) KernelPanic("KPCIWriteConfig - offset is not 4-byte aligned.");
	ProcessorOut32(IO_PCI_CONFIG, (uint32_t) (0x80000000 | (bus << 16) | (device << 11) | (function << 8) | offset));
	if (size == 8) ProcessorOut8(IO_PCI_DATA, value);
	else if (size == 16) ProcessorOut16(IO_PCI_DATA, value);
	else if (size == 32) ProcessorOut32(IO_PCI_DATA, value);
	else KernelPanic("PCIController::WriteConfig - Invalid size %d.\n", size);
}


#define PCI_BUS_DO_NOT_SCAN 0
#define PCI_BUS_SCAN_NEXT 1
#define PCI_BUS_SCANNED 2

#define K_PCI_FEATURE_BAR_0                     (1 <<  0)
#define K_PCI_FEATURE_BAR_1                     (1 <<  1)
#define K_PCI_FEATURE_BAR_2                     (1 <<  2)
#define K_PCI_FEATURE_BAR_3                     (1 <<  3)
#define K_PCI_FEATURE_BAR_4                     (1 <<  4)
#define K_PCI_FEATURE_BAR_5                     (1 <<  5)
#define K_PCI_FEATURE_INTERRUPTS 		(1 <<  8)
#define K_PCI_FEATURE_BUSMASTERING_DMA 		(1 <<  9)
#define K_PCI_FEATURE_MEMORY_SPACE_ACCESS 	(1 << 10)
#define K_PCI_FEATURE_IO_PORT_ACCESS		(1 << 11)


#define PCI_DEVICE_MAX 1000
struct PCIDevice
{
    u32 device_ID;
    u32 subsystem_ID;
    u32 domain;
    u8 class_code;
    u8 subclass_code;
    u8 prog_IF;
    u8 bus;
    u8 slot;
    u8 function;
    u8 interrupt_pin;
    u8 interrupt_line;

    u8* base_addresses_virtual[6];
    u64 base_addresses_physical[6];
    u64 base_addresses_sizes[6];

    u32 base_addresses[6];

    u8 read_config_8(u64 offset)
    {
        return arch_pci_read_config(bus, slot, function, offset, 8);
    }

    void write_config_8(u64 offset, u8 value)
    {
        arch_pci_write_config(bus, slot, function, offset, value, 8);
    }

    u16 read_config_16(u64 offset)
    {
        return arch_pci_read_config(bus, slot, function, offset, 16);
    }

    void write_config_16(u64 offset, u16 value)
    {
        arch_pci_write_config(bus, slot, function, offset, value, 16);
    }

    u32 read_config_32(u64 offset)
    {
        return arch_pci_read_config(bus, slot, function, offset, 32);
    }

    void write_config_32(u64 offset, u32 value)
    {
        arch_pci_write_config(bus, slot, function, offset, value, 32);
    }

    bool enable_features(u64 features)
    {
        u32 config = read_config_32(4);

        if (features & K_PCI_FEATURE_INTERRUPTS) 		config &= ~(1 << 10);
        if (features & K_PCI_FEATURE_BUSMASTERING_DMA) 		config |= 1 << 2;
        if (features & K_PCI_FEATURE_MEMORY_SPACE_ACCESS) 	config |= 1 << 1;
        if (features & K_PCI_FEATURE_IO_PORT_ACCESS)		config |= 1 << 0;
        write_config_32(4, config);

        // cannot update pci config
        if (read_config_32(4) != config) return false;

        for (u32 i = 0; i < 6; i++)
        {
            if (~features & (1 << i)) continue;
            bool bar_is_io_port = base_addresses[i] & 1;
            if (bar_is_io_port) continue;
            bool size_is_64 = base_addresses[i] & 4;
            if (!(base_addresses[i] & 8)) { // @TODO
            }

            u64 address, size;
            if (size_is_64)
            {
                write_config_32(0x10 + 4 * i, 0xFFFFFFFF);
                write_config_32(0x10 + 4 * (i + 1), 0xFFFFFFFF);
                size = read_config_32(0x10 + 4 * i);
                size |= ((u64)read_config_32(0x10 + 4 * (i + 1))) << 32;
                write_config_32(0x10 + 4 * i, base_addresses[i]);
                write_config_32(0x10 + 4 * (i+1), base_addresses[i+1]);
                address = base_addresses[i];
                address |= ((u64)base_addresses[i+i]) << 32;
            }
            else
            {
                write_config_32(0x10 + 4 * i, 0xFFFFFFFF);
                size = read_config_32(0x10 + 4 * i);
                size |= (u64)0xFFFFFFFF << 32;
                write_config_32(0x10 + 4 * i, base_addresses[i]);
                address = base_addresses[i];
            }

            if (size == 0) return false;
            if (address == 0) return false;

            size &= ~15;
            size = ~size + 1;
            address &= ~15;

            base_addresses_virtual[i] = (u8*) MMMapPhysical(kernelMMSpace, address, size, MM_REGION_NOT_CACHEABLE);
            base_addresses_physical[i] = address;
            base_addresses_sizes[i] = size;

            MMCheckUnusable(address, size);
        }

        return true;
    }
    
    u8 read_bar_8(u64 index, u64 offset)
    {
        u32 base_address = base_addresses[index];
        u8 result;
        if (base_address & 1)
        {
            result = ProcessorIn8((base_address & ~3) + offset);
        }
        else
        {
            result = *(volatile u8*) (base_addresses_virtual[index] + offset);
        }

        return result;
    }

    void write_bar_8(u64 index, u64 offset, u8 value)
    {
        u32 base_address = base_addresses[index];
        
        if (base_address & 1)
        {
            ProcessorOut8((base_address & ~3) + offset, value);
        }
        else
        {
            *(volatile u8*) (base_addresses_virtual[index] + offset) = value;
        }
    }

    u16 read_bar_16(u64 index, u64 offset)
    {
        u32 base_address = base_addresses[index];
        u16 result;
        if (base_address & 1)
        {
            result = ProcessorIn16((base_address & ~3) + offset);
        }
        else
        {
            result = *(volatile u16*) (base_addresses_virtual[index] + offset);
        }

        return result;
    }

    void write_bar_16(u64 index, u64 offset, u16 value)
    {
        u32 base_address = base_addresses[index];
        
        if (base_address & 1)
        {
            ProcessorOut16((base_address & ~3) + offset, value);
        }
        else
        {
            *(volatile u16*) (base_addresses_virtual[index] + offset) = value;
        }
    }

    u32 read_bar_32(u64 index, u64 offset)
    {
        u32 base_address = base_addresses[index];
        u32 result;
        if (base_address & 1)
        {
            result = ProcessorIn32((base_address & ~3) + offset);
        }
        else
        {
            result = *(volatile u32*) (base_addresses_virtual[index] + offset);
        }

        return result;
    }

    void write_bar_32(u64 index, u64 offset, u32 value)
    {
        u32 base_address = base_addresses[index];
        
        if (base_address & 1)
        {
            ProcessorOut32((base_address & ~3) + offset, value);
        }
        else
        {
            *(volatile u32*) (base_addresses_virtual[index] + offset) = value;
        }
    }

    u64 read_bar_64(u64 index, u64 offset)
    {
        u32 base_address = base_addresses[index];
        u64 result;

        if (base_address & 1)
        {
            result = (u64)read_bar_32(index, offset) | ((u64)read_bar_32(index, offset + 4) << 32);
        }
        else
        {
            result = *(volatile u64*) (base_addresses_virtual[index] + offset);
        }
        return result;
    }

    void write_bar_64(u64 index, u64 offset, u64 value)
    {
        u32 base_address = base_addresses[index];

        if (base_address & 1)
        {
            write_bar_32(index, offset, value & 0xffffffff);
            write_bar_32(index, offset + 4, (value >> 32) & 0xffffffff);
        }
        else
        {
            *(volatile u64*) (base_addresses_virtual[index] + offset) = value;
        }
    }

    bool enable_MSI(KIRQHandler IRQ_handler, void* context, const char* cOwnerName)
    {
        u16 status = (u16)(read_config_32(0x04) >> 16);

        if (~status & (1 << 4)) return false;

        u8 pointer = read_config_8(0x34);
        u64 index = 0;

        while (pointer && index++ < 0xff)
        {
            u32 dw = read_config_32(pointer);
            u8 next_pointer = (dw >> 8) & 0xff;
            u8 id = dw & 0xff;

            if (id != 5)
            {
                pointer = next_pointer;
                continue;
            }

            KMSIInformation msi = KRegisterMSI(IRQ_handler, context, cOwnerName);

            if (!msi.address) return false;

            u16 control = (dw >> 16) & 0xffff;

            if (msi.data & ~0xffff)
            {
                KUnregisterMSI(msi.tag);
                return false;
            }

            if (msi.address & 0b11)
            {
                KUnregisterMSI(msi.tag);
                return false;
            }

            if ((msi.address & 0xFFFFFFFF00000000) && (~control & (1 << 7)))
            {
                KUnregisterMSI(msi.tag);
                return false;
            }

            control = (control & ~(7 << 4)) | (1 << 0);
            dw = (dw & 0x0000ffff) | (control << 16);

            write_config_32(pointer + 0, dw);
            write_config_32(pointer + 4, msi.address & 0xFFFFFFFF);

            if (control & (1 << 7))
            {
                write_config_32(pointer + 8, ES_PTR64_MS32(msi.address));
                write_config_16(pointer + 12, (read_config_16(pointer + 12) & 0x3800) | msi.data);
                if (control & (1 << 8)) write_config_32(pointer + 16, 0);
            }
            else
            {
                write_config_16(pointer + 8, msi.data);
                if (control & (1 << 8)) write_config_32(pointer + 12, 0);
            }

            return true;
        }

        return false;
    }

    bool enable_single_interrupt(KIRQHandler IRQ_handler, void* context, const char* cOwnerName)
    {
        if (enable_MSI(IRQ_handler, context, cOwnerName)) return true;
        if (interrupt_pin == 0) return false;
        if (interrupt_pin > 4) return false;

        enable_features(K_PCI_FEATURE_INTERRUPTS);

        intptr_t line = interrupt_line;
        if (bootloaderID == 2) line = -1;

        if (KRegisterIRQ(line, IRQ_handler, context, cOwnerName, this)) return true;

        return false;
    }
};

PCIDevice pci_devices[PCI_DEVICE_MAX];
u32 pci_device_count;

struct PCIDriver
{
    u8 bus_scan_states[256];

    void init()
    {
        u32 base_header_type = arch_pci_read_config(0, 0, 0, 0x0c);
        u32 base_bus_count = (base_header_type & 0x80) ? 8: 1;
        u32 bus_to_scan_count = 0;

        for (u32 base_bus = 0; base_bus < base_bus_count; base_bus++)
        {
            u32 device_id = arch_pci_read_config(0, 0, base_bus, 0);
            if ((device_id & 0xffff) != 0xffff) 
            {
                this->bus_scan_states[base_bus] = PCI_BUS_SCAN_NEXT;
                bus_to_scan_count += 1;
            }
        }

        if (bus_to_scan_count == 0) KernelPanic("No bus found\n");

        bool found_usb = false;

        while (bus_to_scan_count > 0)
        {
            for (u32 bus = 0; bus < 256; bus++)
            {
                if (bus_scan_states[bus] == PCI_BUS_SCAN_NEXT)
                {
                    bus_scan_states[bus] = PCI_BUS_SCANNED;
                    bus_to_scan_count -= 1;

                    for (u32 device = 0; device < 32; device++)
                    {
                        u32 device_id = arch_pci_read_config(bus, device, 0, 0);
                        if ((device_id & 0xffff) != 0xffff)
                        {
                            u32 header_type = (arch_pci_read_config(bus, device, 0, 0x0C) >> 16) & 0xFF;
                            u32 function_count = (header_type & 0x80) ? 8 : 1;

                            for (u32 function = 0; function < function_count; function++)
                            {
                                u32 device_id = arch_pci_read_config(bus, device, function, 0);
                                if ((device_id & 0xffff) != 0xffff)
                                {
                                    u32 device_class = arch_pci_read_config(bus, device, function, 0x08);
                                    u32 interrupt_information = arch_pci_read_config(bus, device, function, 0x3c);

                                    // reserve memory. For now we are doing it statically
                                    
                                    PCIDevice* d = &pci_devices[pci_device_count];
                                    EsDefer(pci_device_count += 1);

                                    d->class_code = (device_class >> 24) & 0xff;
                                    d->subclass_code = (device_class >> 16) & 0xff;
                                    d->prog_IF = (device_class >> 8) & 0xff;

                                    d->bus = bus;
                                    d->slot = device;
                                    d->function = function;

                                    d->interrupt_pin = (interrupt_information >> 8) & 0xff;
                                    d->interrupt_line = (interrupt_information >> 0) & 0xff;

                                    d->device_ID = arch_pci_read_config(bus, device, function, 0);
                                    d->subsystem_ID = arch_pci_read_config(bus, device, function, 0x2c);

                                    for (u32 i = 0; i < 6; i++)
                                    {
                                        d->base_addresses[i] = d->read_config_32(0x10 + 4 * i);
                                    }

                                    bool is_pci_bridge = d->class_code == 0x06 && d->subclass_code == 0x04;
                                    if (is_pci_bridge)
                                    {
                                        u8 secondary_bus = (arch_pci_read_config(bus, device, function, 0x18) >> 8) & 0xff;
                                        if (bus_scan_states[secondary_bus] == PCI_BUS_DO_NOT_SCAN)
                                        {
                                            bus_to_scan_count += 1;
                                            bus_scan_states[secondary_bus] = PCI_BUS_SCAN_NEXT;
                                        }
                                    }

                                    bool is_usb = d->class_code == 12 && d->subclass_code == 3;
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

PCIDriver pci_driver;

auto ahci_class_code = 1;
auto ahci_subclass_code = 6;

#define AHCI_GENERAL_TIMEOUT (5000)
#define AHCI_COMMAND_LIST_SIZE  (0x400)
#define AHCI_RECEIVED_FIS_SIZE  (0x100)
#define AHCI_PRDT_ENTRY_COUNT   (0x48) // If one page each, this covers more than CC_ACTIVE_SECTION_SIZE. This must be a multiple of 8.
#define AHCI_COMMAND_TABLE_SIZE (0x80 + AHCI_PRDT_ENTRY_COUNT * 0x10) 

extern struct AHCIDriver ahci_driver;

void TimeoutTimerHit(KAsyncTask* task);

struct BlockDeviceAccessRequest {
	struct BlockDevice *device;
	EsFileOffset offset;
	size_t count;
	int operation;
	KDMABuffer *buffer;
	uint64_t flags;
	KWorkGroup *dispatchGroup;

};

#define K_SIGNATURE_BLOCK_SIZE (65536)

struct MBRPartition
{
    u32 offset;
    u32 count;
    bool present;
};

struct GPTPartition
{
    u64 offset;
    u64 count;
    bool present;
    bool is_ESP;
};

struct GPTHeader
{
    u8 signature[8];
    u32 revision;
    u32 header_bytes;
    u32 header_CRC32;
    u32 _reserved0;
    u64 header_self_LBA;
    u64 header_backup_LBA;
    u64 first_usable_LBA;
    u64 last_usable_LBA;
    u8 drive_GUID[16];
    u64 table_LBA;
    u32 partition_entry_count;
    u32 partition_entry_bytes;
    u32 table_CRC32;
};

struct GPTEntry
{
    u8 type_GUID[16];
    u8 partition_GUID[16];
    u64 first_LBA;
    u64 last_LBA;
    u64 attributes;
    u16 name[36];
};

bool MBRGetPartitions(uint8_t *firstBlock, EsFileOffset sectorCount, MBRPartition *partitions /* 4 */) {
	if (firstBlock[510] != 0x55 || firstBlock[511] != 0xAA) {
		return false;
	}

#ifdef KERNEL
	KernelLog(LOG_INFO, "FS", "probing MBR", "First sector on device looks like an MBR...\n");
#endif

	for (uintptr_t i = 0; i < 4; i++) {
		if (!firstBlock[4 + 0x1BE + i * 0x10]) {
			partitions[i].present = false;
			continue;
		}

		partitions[i].offset =  
			  ((uint32_t) firstBlock[0x1BE + i * 0x10 + 8 ] <<  0)
			+ ((uint32_t) firstBlock[0x1BE + i * 0x10 + 9 ] <<  8)
			+ ((uint32_t) firstBlock[0x1BE + i * 0x10 + 10] << 16)
			+ ((uint32_t) firstBlock[0x1BE + i * 0x10 + 11] << 24);
		partitions[i].count =
			  ((uint32_t) firstBlock[0x1BE + i * 0x10 + 12] <<  0)
			+ ((uint32_t) firstBlock[0x1BE + i * 0x10 + 13] <<  8)
			+ ((uint32_t) firstBlock[0x1BE + i * 0x10 + 14] << 16)
			+ ((uint32_t) firstBlock[0x1BE + i * 0x10 + 15] << 24);
		partitions[i].present = true;

		if (partitions[i].offset > sectorCount || partitions[i].count > sectorCount - partitions[i].offset || partitions[i].count < 32) {
#ifdef KERNEL
			KernelLog(LOG_INFO, "FS", "invalid MBR", "Partition %d has offset %d and count %d, which is invalid. Ignoring the rest of the MBR...\n",
					i, partitions[i].offset, partitions[i].count);
#endif
			return false;
		}
	}

	return true;
}

EsError FSBlockDeviceAccess(BlockDeviceAccessRequest request);
typedef EsError (*DeviceAccessCallbackFunction)(BlockDeviceAccessRequest request);

MBRPartition mbr_partitions[4];
struct PartitionDevice* partitions[16];
u64 mbr_partition_count = 0;


struct PartitionDevice* PartitionDeviceCreate(BlockDevice* parent, EsFileOffset offset, EsFileOffset sector_count, u32 flags, const char* model, size_t model_bytes);

struct BlockDevice
{
    DeviceAccessCallbackFunction access;
    u64 sector_size;
    u64 sector_count;
    bool read_only;
    u8 nest_level;
    u8 drive_type;
    u8 model_bytes;
    char model[64];
    u64 max_access_sector_count;

    u8* signature_block;
    KMutex detect_filesystem_mutex;

    void detect_fs()
    {
        KMutexAcquire(&detect_filesystem_mutex);
        EsDefer(KMutexRelease(&detect_filesystem_mutex));

        if (nest_level > 4)
        {
            KernelPanic("Filesystem nest limit");
        }

        u64 sectors_to_read = (K_SIGNATURE_BLOCK_SIZE + sector_size - 1) / sector_size;

        if (sectors_to_read > sector_count)
        {
            KernelPanic("Drive too small\n");
        }

        u64 bytes_to_read = sectors_to_read * sector_size;
        u8* signature_block_memory = (u8*)EsHeapAllocate(bytes_to_read, false, K_FIXED);
        if (signature_block_memory != nullptr)
        {
            signature_block = signature_block_memory;

            KDMABuffer dma_buffer = { (uintptr_t)signature_block };
            BlockDeviceAccessRequest request = {};
            request.device = this;
            request.count = bytes_to_read;
            request.operation = K_ACCESS_READ;
            request.buffer = &dma_buffer;

            if (ES_SUCCESS != FSBlockDeviceAccess(request))
            {
                KernelPanic("Could't read disk");
            }

            // @TODO: support GPT and more than one partition
            EsAssert(nest_level == 0);
            // @INFO: this also "initializes" partition
            if (!check_mbr())
            {
                KernelPanic("Only MBR is supported\n");
            }

            EsHeapFree(signature_block_memory, bytes_to_read, K_FIXED);
        }
    }

    void fs_register()
    {
        detect_fs();
        // @TODO: notify desktop
    }

    bool check_mbr()
    {
        if (MBRGetPartitions(this->signature_block, this->sector_count, mbr_partitions))
        {
            bool found_any = false;

            for (u64 partition_i = 0; partition_i < 4; partition_i++)
            {
                MBRPartition* partition = &mbr_partitions[partition_i];
                if (partition->present)
                {
                    // @TODO: this should be a recursive call to fs_register
                    PartitionDevice* partition_device = PartitionDeviceCreate(this, partition->offset, partition->count, 0, "MBR partition", EsCStringLength("MBR partitition"));
                    return true;
                    // @TODO support more partitions
                    // @TODO: support GPT
                }
            }

            return found_any;
        }
        else
        {
            return false;
        }
    }
};

struct PartitionDevice : BlockDevice
{
    EsFileOffset sector_offset;
    BlockDevice* parent;
};

EsError PartitionDeviceAccess(BlockDeviceAccessRequest request)
{
    PartitionDevice* device = (PartitionDevice*)request.device;
    request.device = (BlockDevice*)device->parent;
    request.offset += device->sector_offset * device->sector_size;
    return FSBlockDeviceAccess(request);
}

PartitionDevice* PartitionDeviceCreate(BlockDevice* parent, EsFileOffset offset, EsFileOffset sector_count, u32 flags, const char* model, size_t model_bytes)
{
    PartitionDevice* partition = (PartitionDevice*) EsHeapAllocate(sizeof(PartitionDevice), true, K_FIXED);
    if (!partition) return nullptr;

    if (model_bytes > sizeof(partition->model)) model_bytes = sizeof(partition->model);

    EsMemoryCopy(partition->model, model, model_bytes);

    partition->parent = parent;
    partition->sector_size = parent->sector_size;
    partition->max_access_sector_count = parent->max_access_sector_count;
    partition->sector_offset = offset;
    partition->sector_count = sector_count;
    partition->read_only = parent->read_only;
    partition->access = PartitionDeviceAccess;
    partition->model_bytes = model_bytes;
    partition->nest_level = parent->nest_level + 1;
    partition->drive_type = parent->drive_type;

    // @TODO proper register
    // @WARN @ERROR maybe race condition
    partitions[mbr_partition_count] = partition;
    mbr_partition_count += 1;

    return partition;
}

EsError FSBlockDeviceAccess(BlockDeviceAccessRequest request)
{
    BlockDevice* device = request.device;

    if (request.count == 0) return ES_SUCCESS;

    if (device->read_only && request.operation == K_ACCESS_WRITE)
    {
        if (request.flags & FS_BLOCK_ACCESS_SOFT_ERRORS) return ES_ERROR_BLOCK_ACCESS_INVALID;
        KernelPanic("Read only\n");
    }

    if (request.offset / device->sector_size > device->sector_count || (request.offset + request.count) / device->sector_size > device->sector_count)
    {
        if (request.flags & FS_BLOCK_ACCESS_SOFT_ERRORS) return ES_ERROR_BLOCK_ACCESS_INVALID;
        KernelPanic("Disk access out of bounds\n");
    }

    if (request.offset % device->sector_size != 0 || request.count % device->sector_size != 0)
    {
        if (request.flags & FS_BLOCK_ACCESS_SOFT_ERRORS) return ES_ERROR_BLOCK_ACCESS_INVALID;
        KernelPanic("Unaligned access\n");
    }

    KDMABuffer buffer = *request.buffer;

    if (buffer.virtualAddress & 3)
    {
        if (request.flags & FS_BLOCK_ACCESS_SOFT_ERRORS) return ES_ERROR_BLOCK_ACCESS_INVALID;
        KernelPanic("Buffer must be 4-byte aligned\n");
    }

    KWorkGroup fake_dispatch_group = {};

    if (!request.dispatchGroup)
    {
        fake_dispatch_group.Initialise();
        request.dispatchGroup = &fake_dispatch_group;
    }

    BlockDeviceAccessRequest r = {};
    r.device = request.device;
    r.buffer = &buffer;
    r.flags = request.flags;
    r.dispatchGroup = request.dispatchGroup;
    r.operation = request.operation;
    r.offset = request.offset;

    while (request.count != 0)
    {
        r.count = device->max_access_sector_count * device->sector_size;
        if (r.count > request.count) r.count = request.count;

        buffer.offsetBytes = 0;
        buffer.totalByteCount = r.count;
        r.count = r.count;
        device->access(r);
        r.offset += r.count;
        buffer.virtualAddress += r.count;
        request.count -= r.count;
    }

    if (request.dispatchGroup == &fake_dispatch_group)
    {
        return fake_dispatch_group.Wait() ? ES_SUCCESS : ES_ERROR_DRIVE_CONTROLLER_REPORTED;
    }
    else
    {
        return ES_SUCCESS;
    }
}

struct AHCIDrive
{
    BlockDevice block_device;
    u64 port;
};

AHCIDrive ahci_drives[64];
u64 ahci_drive_count;

#define ES_DRIVE_TYPE_OTHER            (0)
#define ES_DRIVE_TYPE_HDD              (1)
#define ES_DRIVE_TYPE_SSD              (2)
#define ES_DRIVE_TYPE_CDROM            (3)
#define ES_DRIVE_TYPE_USB_MASS_STORAGE (4)

struct InterruptEvent
{
    u64 timestamp;
    u32 global_interrupt_status;
    u32 port_0_commands_running;
    u32 port_0_commands_issued;
    bool complete;
};

void KSwitchThreadAfterIRQ()
{
    GetLocalStorage()->irqSwitchThread = true;
}

volatile uintptr_t recent_interrupt_events_pointer;
volatile InterruptEvent recent_interrupt_events[64];

struct AHCIDriver
{
    struct Port
    {
        bool connected;
        bool atapi;
        bool ssd;

        u32* command_list;
        u8* command_tables;

        u64 sector_bytes;
        u64 sector_count;

        KWorkGroup* command_contexts[32];
        u64 command_start_timestamps[32];
        u32 running_commands;

        KSpinlock command_spinlock;
        KEvent command_slots_available;

        char model[41];
    };

    PCIDevice* device;
    u32 capabilities;
    u32 capabilities2;
    u64 command_slot_count;
    KTimer timeout_timer;
    bool dma64_supported;
#define MAX_PORTS (32)
    Port ports[MAX_PORTS];

    void init()
    {
        // PCI stuff
        // @TODO: avoid this hardcoding
        ahci_driver.device = &pci_devices[3];
        bool is_ahci_pci_device = ahci_driver.device->class_code == ahci_class_code && ahci_driver.device->subclass_code == ahci_subclass_code && ahci_driver.device->prog_IF == 1;

        if (!is_ahci_pci_device)
        {
            KernelPanic("AHCI driver not found\n");
        }

        ahci_driver.device->enable_features(K_PCI_FEATURE_INTERRUPTS
                | K_PCI_FEATURE_BUSMASTERING_DMA
                | K_PCI_FEATURE_MEMORY_SPACE_ACCESS
                | K_PCI_FEATURE_BAR_5);

        // Perform BIOS/OS handoff, if necessary
        if (CAP2.read() & (1 << 0))
        {
            BOHC.write(BOHC.read() | (1 << 1));
            KTimeout timeout(25);
            u32 status;

            while (true)
            {
                status = BOHC.read();
                if (status & (1 << 0)) break;
                if (timeout.Hit()) break;
            }

            if (status & (1 << 0))
            {
                KEvent event = {};
                KEventWait(&event, 2000);
            }
        }

        // Reset controller
        {
            KTimeout timeout(AHCI_GENERAL_TIMEOUT);
            GHC.write(GHC.read() | (1 << 0));
            while ((GHC.read() & (1 << 0)) && !timeout.Hit()) { }

            if (timeout.Hit())
            {
                // error
                return;
            }
        }

        // Register IRQ handler
        KIRQHandler handler = [] (uintptr_t, void* context)
        {
            return ((AHCIDriver*)context)->handle_IRQ();
        };

        if (!device->enable_single_interrupt(handler, this, "AHCI"))
        {
            return;
        }

        // Enable AHCI mode and interrupts
        GHC.write(GHC.read() | (1 << 31) | (1 << 1));

        capabilities = CAP.read();
        capabilities2 = CAP2.read();
        command_slot_count = ((capabilities >> 8) & 31) + 1;
        dma64_supported = capabilities & (1 << 31);

        if (!dma64_supported)
        {
            return;
        }

        // Work out which ports have drives connected
        u64 maximum_number_of_ports = (capabilities & 31) + 1;
        u64 found_ports = 0;

        u32 ports_implemented = PI.read();

        for (u64 i = 0; i < MAX_PORTS; i++)
        {
            if (ports_implemented & (1 << i))
            {
                found_ports += 1;

                if (found_ports <= maximum_number_of_ports)
                {
                    ports[i].connected = true;
                }
            }
        }

        // Setup the command lists, FISes and command tables
        for (u64 port_i = 0; port_i < MAX_PORTS; port_i++)
        {
            if (ports[port_i].connected)
            {
                u64 needed_bytes = AHCI_COMMAND_LIST_SIZE + AHCI_RECEIVED_FIS_SIZE + AHCI_COMMAND_TABLE_SIZE * command_slot_count;

                u8* virtual_address;
                u64 physical_address;

                if (!MMPhysicalAllocateAndMap(needed_bytes, K_PAGE_SIZE, dma64_supported ? 64 : 32, true, MM_REGION_NOT_CACHEABLE, &virtual_address, &physical_address))
                {
                    KernelLog(LOG_ERROR, "AHCI", "allocation failure", "Could not allocate physical memory for port %d.\n", port_i);
                    break;
                }

                ports[port_i].command_list = (u32*)virtual_address;
                ports[port_i].command_tables = virtual_address + AHCI_COMMAND_LIST_SIZE + AHCI_RECEIVED_FIS_SIZE;

                // Set the registers to the physical addresses
                PCLB.write(port_i, ES_PTR64_LS32(physical_address));
                PFB.write(port_i, ES_PTR64_LS32(physical_address + 0x400));

                if (dma64_supported)
                {
                    PCLBU.write(port_i, ES_PTR64_MS32(physical_address));
                }

                if (dma64_supported)
                {
                    PFBU.write(port_i, ES_PTR64_MS32(physical_address + 0x400));
                }

                // Point each command list entry to the corresponding command table
                u32* command_list = ports[port_i].command_list;

                for (u64 command_slot = 0; command_slot < command_slot_count; command_slot++)
                {
                    u64 address = physical_address + AHCI_COMMAND_LIST_SIZE + AHCI_RECEIVED_FIS_SIZE + AHCI_COMMAND_TABLE_SIZE * command_slot;
                    command_list[command_slot * 8 + 2] = ES_PTR64_LS32(address);
                    command_list[command_slot * 8 + 3] = ES_PTR64_MS32(address);
                }

                // Reset the port
                KTimeout timeout(AHCI_GENERAL_TIMEOUT);

                u32 running_bits = 
                    (1 << 0)  | // start
                    (1 << 4)  | // receive FIS enable
                    (1 << 15) | // command list running
                    (1 << 14);  // receive FIS running

                while (true)
                {
                    u32 status = PCMD.read(port_i);

                    if ((status & running_bits) == 0 || timeout.Hit()) break;

                    PCMD.write(port_i, status & ~((1 << 0) | (1 << 4)));
                }

                bool reset_port_timeout = PCMD.read(port_i) & running_bits;
                if (reset_port_timeout)
                {
                    ports[port_i].connected = false;
                    continue;
                }

                // Clear IRQs
                PIE.write(port_i, PIE.read(port_i) & 0x0E3FFF00);
                PIS.write(port_i, PIS.read(port_i));

                // Enable receive FIS and activate the drive
                PSCTL.write(port_i, PSCTL.read(port_i) | (3 << 8));
                PCMD.write(port_i,
                        (PCMD.read(port_i) & 0x0FFFFFFF) |
                        (1 << 1) | // spin up
                        (1 << 2) | // power on
                        (1 << 4) | // FIS receive
                        (1 << 28));// activate

                KTimeout link_timeout(10);

                while ((PSSTS.read(port_i) & 0x0f) != 3 && !link_timeout.Hit()) {}

                bool activate_port_timeout = (PSSTS.read(port_i) & 0x0f) != 3;
                if (activate_port_timeout)
                {
                    ports[port_i].connected = false;
                    continue;
                }

                // Clear errors
                PSERR.write(port_i, PSERR.read(port_i));

                // Wait for the device to be ready
                while ((PTFD.read(port_i) & 0x88) && !timeout.Hit()) { }

                bool port_ready_timeout = (PTFD.read(port_i) & 0x88);
                if (port_ready_timeout)
                {
                    ports[port_i].connected = false;
                    continue;
                }

                // Start command list processing
                PCMD.write(port_i, PCMD.read(port_i) | (1 << 0));

                // Enable interrupts
                PIE.write(port_i,
                        PIE.read(port_i) |
                        (1 << 5)  | // descriptor complete
                        (1 << 0)  | // D2H
                        (1 << 30) | // errors (...)
                        (1 << 29) |
                        (1 << 28) |
                        (1 << 27) |
                        (1 << 26) |
                        (1 << 24) |
                        (1 << 23));
            }
        }

        // Read the status and signature for each implemented port to work out if it is connected
        for (u64 port_i = 0; port_i < MAX_PORTS; port_i++)
        {
            if (ports[port_i].connected)
            {
                u32 status = PSSTS.read(port_i);

                if ((status & 0x00f) != 0x003 || (status & 0x0f0) == 0x000 || (status & 0xf00) != 0x100)
                {
                    ports[port_i].connected = false;
                    continue;
                }

                u32 signature = PSIG.read(port_i);

                if (signature == 0x00000101)
                {
                    // SATA drive
                }
                else if (signature == 0xEB140101)
                {
                    // SATAPI drive
                    ports[port_i].atapi = true;
                }
                else if (signature == 0)
                {
                    // no drive connected
                    ports[port_i].connected = false;
                }
                else
                {
                    // unrecognized drive signature
                    ports[port_i].connected = false;
                }
            }
        }

        // Identify each connected drive
        u16* identify_data;
        u64 identify_data_physical;

        if (!MMPhysicalAllocateAndMap(0x200, K_PAGE_SIZE, dma64_supported ? 64 : 32, true, MM_REGION_NOT_CACHEABLE, (uint8_t **) &identify_data, &identify_data_physical))
        {
            KernelLog(LOG_ERROR, "AHCI", "allocation failure", "Could not allocate physical memory for identify data buffer.\n");
            return;
        }

        for (u64 port_i = 0; port_i < MAX_PORTS; port_i++)
        {
            if (ports[port_i].connected)
            {
                EsMemoryZero(identify_data, 0x200);

                // Setup command list entry
                ports[port_i].command_list[0] = 5 /* FIS is 5 DWORDs */ | (1 << 16) /* 1 PDRT entry */;
                ports[port_i].command_list[1] = 0;

                // Setup the command FIS
                u8 opcode = ports[port_i].atapi ? 0xa1 /*identify packet */ : 0xec; // identify
                u32* command_FIS = (u32*)ports[port_i].command_tables;
                command_FIS[0] =
                    0x27 | // H2D
                    (1 << 15) | // command
                    (opcode << 16);
                command_FIS[1] = command_FIS[2] = command_FIS[3] = command_FIS[4] = 0;

                // Setup the PRDT
                u32* prdt = (u32*) (ports[port_i].command_tables + 0x80);
                prdt[0] = ES_PTR64_LS32(identify_data_physical);
                prdt[1] = ES_PTR64_MS32(identify_data_physical);
                prdt[2] = 0;
                prdt[3] = 0x200 - 1;

                if (!send_single_command(port_i))
                {
                    // stop command processing
                    PCMD.write(port_i, PCMD.read(port_i) & ~(1 << 0));
                    ports[port_i].connected = false;
                    continue;
                }

                ports[port_i].sector_bytes = 0x200;

                if ((identify_data[106] & (1 << 14)) && (~identify_data[106] & (1 << 15)) && (identify_data[106] & (1 << 12)))
                {
                    ports[port_i].sector_bytes = (u32)identify_data[117] | ((u32)identify_data[118] << 16);
                }

                ports[port_i].sector_count = ((u64)identify_data[100] << 0) + ((u64)identify_data[101] << 16) + ((u64)identify_data[102] << 32) + ((u64) identify_data[103] << 48);

                if (!((identify_data[49] & (1 << 9)) && (identify_data[49] & (1 << 8))))
                {
                    ports[port_i].connected = false;
                    continue;
                }

                if (ports[port_i].atapi)
                {
                    // Send a read capacity command
                    ports[port_i].command_list[0] = 5 | (1 << 16) | (1 << 5);
                    command_FIS[0] = 0x27 | (1 << 15) | (0xa0 << 16);
                    command_FIS[1] = 8 << 8;
                    prdt[3] = 8 - 1;

                    u8* scsi_command = (u8*)command_FIS + 0x40;
                    EsMemoryZero(scsi_command, 10);
                    scsi_command[0] = 0x25;

                    if (!send_single_command(port_i))
                    {
                        PCMD.write(port_i, PCMD.read(port_i) & ~(1 << 0));
                        ports[port_i].connected = false;
                        continue;
                    }

                    u8* capacity = (u8*)identify_data;

                    ports[port_i].sector_count = (((u64) capacity[3] << 0) + ((u64) capacity[2] << 8) + ((u64) capacity[1] << 16) + ((u64) capacity[0] << 24)) + 1;
                    ports[port_i].sector_bytes = ((u64) capacity[7] << 0) + ((u64) capacity[6] << 8) + ((u64) capacity[5] << 16) + ((u64) capacity[4] << 24);
                }

                if (ports[port_i].sector_count <= 128 || (ports[port_i].sector_bytes & 0x1ff) || !ports[port_i].sector_bytes || ports[port_i].sector_bytes > 0x1000)
                {
                    ports[port_i].connected = false;
                    continue;
                }

                for (u64 model_i = 0; model_i < 20; model_i++)
                {
                    ports[port_i].model[model_i * 2 + 0] = identify_data[27 + model_i] >> 8;
                    ports[port_i].model[model_i * 2 + 1] = identify_data[27 + model_i] & 0xff;
                }

                ports[port_i].model[40] = 0;

                for (u64 model_i = 39; model_i > 0; model_i -= 1)
                {
                    if (ports[port_i].model[model_i] == ' ')
                    {
                        ports[port_i].model[model_i] = 0;
                    }
                    else
                    {
                        break;
                    }
                }

                ports[port_i].ssd = identify_data[217] == 1;

                for (u64 i = 10; i < 20; i++) identify_data[i] = (identify_data[i] >> 8) | (identify_data[i] << 8);
                for (u64 i = 23; i < 27; i++) identify_data[i] = (identify_data[i] >> 8) | (identify_data[i] << 8);
                for (u64 i = 27; i < 47; i++) identify_data[i] = (identify_data[i] >> 8) | (identify_data[i] << 8);
            }
        }

        MMFree(kernelMMSpace, identify_data);
        MMPhysicalFree(identify_data_physical);

        // Start the timeout timer
        KTimerSet(&timeout_timer, AHCI_GENERAL_TIMEOUT, TimeoutTimerHit, this);

        // Register drives

        for (u64 port_i = 0; port_i < MAX_PORTS; port_i++)
        {
            if (ports[port_i].connected)
            {
                AHCIDrive* drive = &ahci_drives[port_i];
                ahci_drive_count++;

                drive->port = port_i;
                drive->block_device.sector_size = ports[port_i].sector_bytes;
                drive->block_device.sector_count = ports[port_i].sector_count;
                drive->block_device.max_access_sector_count = ports[port_i].atapi ? (65535 / drive->block_device.sector_size) : ((AHCI_PRDT_ENTRY_COUNT - 1) * K_PAGE_SIZE / drive->block_device.sector_size);
                drive->block_device.read_only = ports[port_i].atapi;
                EsAssert(sizeof(ports[port_i].model) <= sizeof(drive->block_device.model));
                EsMemoryCopy(drive->block_device.model, ports[port_i].model, sizeof(ports[port_i].model));
                drive->block_device.model_bytes = sizeof(ports[port_i].model);
                drive->block_device.drive_type = ports[port_i].atapi ? ES_DRIVE_TYPE_CDROM : ports[port_i].ssd ? ES_DRIVE_TYPE_SSD : ES_DRIVE_TYPE_HDD;

                drive->block_device.access = [] (BlockDeviceAccessRequest request) -> EsError
                {
                    AHCIDrive* drive = (AHCIDrive*)request.device;
                    request.dispatchGroup->Start();

                    if (!ahci_driver.access(drive->port, request.offset, request.count, request.operation, request.buffer, request.flags, request.dispatchGroup))
                    {
                        request.dispatchGroup->End(false);
                    }

                    return ES_SUCCESS;
                };

                BlockDevice* _device = (BlockDevice*) drive;
                _device->fs_register();
            }
        }
    }

    bool handle_IRQ()
    {
        u32 global_interrupt_status = IS.read();
        if (global_interrupt_status == 0) return false;
        IS.write(global_interrupt_status);

        volatile InterruptEvent* event = recent_interrupt_events + recent_interrupt_events_pointer;
        event->timestamp = KGetTimeInMs();
        event->global_interrupt_status = global_interrupt_status;
        event->complete = false;
        recent_interrupt_events_pointer = (recent_interrupt_events_pointer + 1) % (sizeof(recent_interrupt_events) / sizeof(recent_interrupt_events[0]));

        bool command_completed = false;

        for (u64 port_i = 0; port_i < MAX_PORTS; port_i++)
        {
            if (~global_interrupt_status & (1 << port_i)) continue;

            u32 interrupt_status = PIS.read(port_i);
            if (interrupt_status == 0) continue;

            PIS.write(port_i, interrupt_status);

            Port* port = ports + port_i;

            if (interrupt_status & ((1 << 30) | (1 << 29) | (1 << 28) | (1 << 27) | (1 << 26) | (1 << 24) | (1 << 23)))
            {
                KSpinlockAcquire(&port->command_spinlock);

                // Stop command processing
                PCMD.write(port_i, PCMD.read(port_i) & ~(1 << 0));

                // Fail all outstanding commands
                for (u64 port_j = 0; port_j < MAX_PORTS; port_j++)
                {
                    if (port->running_commands & (1 << port_j))
                    {
                        port->command_contexts[port_j]->End(false);
                        port->command_contexts[port_j] = nullptr;
                    }
                }

                port->running_commands = 0;
                KEventSet(&port->command_slots_available, true);

                // Restart command processing
                PSERR.write(port_i, 0xffffffff);
                KTimeout timeout(5);
                while ((PCMD.read(port_i) & (1 << 15)) && !timeout.Hit()) { }
                PCMD.write(port_i, PCMD.read(port_i) | (1 << 0));

                KSpinlockRelease(&port->command_spinlock);
                
                continue;
            }

            KSpinlockAcquire(&port->command_spinlock);
            
            u32 commands_issued = PCI.read(port_i);

            if (port_i == 0)
            {
                event->port_0_commands_issued = commands_issued;
                event->port_0_commands_running = port->running_commands;
            }

            for (u64 port_j = 0; port_j < MAX_PORTS; port_j++)
            {
                if (~port->running_commands & (1 << port_j)) continue;
                if (commands_issued & (1 << port_j)) continue;

                port->command_contexts[port_j]->End(true);
                port->command_contexts[port_j] = nullptr;
                KEventSet(&port->command_slots_available, true);
                port->running_commands &= ~(1 << port_j);

                command_completed = true;
            }

            KSpinlockRelease(&port->command_spinlock);
        }

        if (command_completed)
        {
            KSwitchThreadAfterIRQ();
        }

        event->complete = true;

        return true;
    }

    bool send_single_command(u64 port)
    {
        KTimeout timeout(AHCI_GENERAL_TIMEOUT);

        while ((PTFD.read(port) & ((1 << 7) | (1 << 3))) && !timeout.Hit()) { }

        if (timeout.Hit())
        {
            return false;
        }

        __sync_synchronize();
        PCI.write(port, 1 << 0);

        bool complete = false;
        while (!timeout.Hit())
        {
            if (~PCI.read(port) & (1 << 0))
            {
                complete = true;
                break;
            }
        }

        return complete;
    }

    bool access(u64 port_index, u64 offset_bytes, u64 count_bytes, int operation, KDMABuffer* buffer, u64 _not_used, KWorkGroup* dispath_group)
    {
        Port* port = ports + port_index;

        // Find a command slot to use
        u64 command_index = 0;

        while (true)
        {
            KSpinlockAcquire(&port->command_spinlock);

            u32 commands_available = ~PCI.read(port_index);

            bool found = false;

            for (u64 slot_i = 0; slot_i < command_slot_count; slot_i++)
            {
                if ((commands_available & (1 << slot_i)) && !port->command_contexts[slot_i])
                {
                    command_index = slot_i;
                    found = true;
                    break;
                }
            }

            if (!found)
            {
                KEventReset(&port->command_slots_available);
            }
            else
            {
                port->command_contexts[command_index] = dispath_group;
            }

            KSpinlockRelease(&port->command_spinlock);

            if (!found)
            {
                KEventWait(&ports->command_slots_available);
            }
            else
            {
                break;
            }
        }

        // Setup the command FIS
        u32 count_sectors = count_bytes / port->sector_bytes;
        u64 offset_sectors = offset_bytes / port->sector_bytes;

        if (count_sectors & ~0xffff)
        {
            KernelPanic("Too many sectors to read\n");
        }

        u32* command_FIS = (u32*) (port->command_tables + (AHCI_COMMAND_TABLE_SIZE * command_index));
        command_FIS[0] = 0x27 | (1 << 15) | ((operation == K_ACCESS_WRITE ? 0x35 : 0x25) << 16);
        command_FIS[1] = (offset_sectors & 0xFFFFFF) | (1 << 30);
        command_FIS[2] = (offset_sectors >> 24) & 0xFFFFFF;
        command_FIS[3] = count_sectors & 0xffff;
        command_FIS[4] = 0;

        // Setup the PRDT
        u64 PRDT_entry_count = 0;
        u32* prdt = (u32*) (port->command_tables + AHCI_COMMAND_TABLE_SIZE * command_index + 0x80);

        while (!buffer->is_complete())
        {
            if (PRDT_entry_count == AHCI_PRDT_ENTRY_COUNT)
            {
                KernelPanic("Too many PRDT entries\n");
            }


            KDMASegment segment = buffer->next_segment();

            prdt[0 + 4 * PRDT_entry_count] = ES_PTR64_LS32(segment.physicalAddress);
            prdt[1 + 4 * PRDT_entry_count] = ES_PTR64_MS32(segment.physicalAddress);
            prdt[2 + 4 * PRDT_entry_count] = 0;
            prdt[3 + 4 * PRDT_entry_count] = (segment.byteCount - 1) | (segment.isLast ? (1 << 31) : 0);

            PRDT_entry_count++;
        }

        // Setup the command list entry and issue the command
        port->command_list[command_index * 8 + 0] = 5 | (PRDT_entry_count << 16) | (operation == K_ACCESS_WRITE ? (1 << 6) : 0);
        port->command_list[command_index * 8 + 1] = 0;

        if (port->atapi)
        {
            port->command_list[command_index * 8 + 0] |= (1 << 5);
            command_FIS[0] = 0x27 | (1 << 15) | (0xa0 << 16);
            command_FIS[1] = count_bytes << 8;

            u8* SCSI_command = (u8*)command_FIS + 0x40;
            EsMemoryZero(SCSI_command, 10);
            SCSI_command[0] = 0xa8;
            SCSI_command[2] = (offset_sectors >> 0x18) & 0xFF;
            SCSI_command[3] = (offset_sectors >> 0x10) & 0xFF;
            SCSI_command[4] = (offset_sectors >> 0x08) & 0xFF;
            SCSI_command[5] = (offset_sectors >> 0x00) & 0xFF;
            SCSI_command[9] = count_sectors;
        }

        // Start executing the command
        KSpinlockAcquire(&port->command_spinlock);
        port->running_commands |= 1 << command_index;
        __sync_synchronize();
        PCI.write(port_index, 1 << command_index);
        port->command_start_timestamps[command_index] = KGetTimeInMs();
        KSpinlockRelease(&port->command_spinlock);

        return true;
    }

    struct GlobalRegister
    {
        u64 offset;

        void write(u32 value)
        {
            ahci_driver.device->write_bar_32(5, offset, value);
        }

        u32 read()
        {
            return ahci_driver.device->read_bar_32(5, offset);
        }
    };

    struct PortRegister
    {
        u64 offset;

        void write(u64 port, u32 value)
        {
            ahci_driver.device->write_bar_32(5, offset + port * 0x80, value);
        }

        u32 read(u64 port)
        {
            return ahci_driver.device->read_bar_32(5, offset + port * 0x80);
        }
    };

    GlobalRegister CAP = { 0 };
    GlobalRegister GHC = { 4 };
    GlobalRegister IS  = { 8 };
    GlobalRegister PI  = { 0xc };
    GlobalRegister CAP2 = { 0x24 };
    GlobalRegister BOHC = { 0x28 };

    PortRegister PCLB = { 0x100 };
    PortRegister PCLBU = { 0x104 };
    PortRegister PFB = { 0x108 };
    PortRegister PFBU = { 0x10C };
    PortRegister PIS = { 0x110 };
    PortRegister PIE = { 0x114 };
    PortRegister PCMD = { 0x118 };
    PortRegister PTFD = { 0x120 };
    PortRegister PSIG = { 0x124 };
    PortRegister PSSTS = { 0x128 };
    PortRegister PSCTL = { 0x12C };
    PortRegister PSERR = { 0x130 };
    PortRegister PCI = { 0x138 };
};

void TimeoutTimerHit(KAsyncTask* task)
{
    AHCIDriver* driver = (AHCIDriver*) ((u64)task + offsetof(AHCIDriver, timeout_timer.asyncTask));
    u64 current_timestamp = KGetTimeInMs();

    for (u64 i = 0; i < MAX_PORTS; i++)
    {
        AHCIDriver::Port* port = driver->ports + i;

        KSpinlockAcquire(&port->command_spinlock);

        for (u64 slot_i = 0; slot_i < driver->command_slot_count; slot_i++)
        {
            if ((port->running_commands & (1 << slot_i)) && port->command_start_timestamps[slot_i] + AHCI_GENERAL_TIMEOUT < current_timestamp)
            {
                port->command_contexts[slot_i]->End(false);
                port->command_contexts[slot_i] = nullptr;
                port->running_commands &= ~(1 << slot_i);
            }
        }

        KSpinlockRelease(&port->command_spinlock);
    }

    KTimerSet(&driver->timeout_timer, AHCI_GENERAL_TIMEOUT, TimeoutTimerHit, driver);
}

AHCIDriver ahci_driver;

void drivers_init()
{
    pci_driver.init();
    ahci_driver.init();
}

u64 align(u64 n, u64 alignment)
{
    u64 mask = alignment - 1;
    EsAssert((alignment & mask) == 0);
    return (n + mask) & ~mask;
}

const u32 hardcoded_desktop_size = 1928;
const u32 hardcoded_kernel_file_offset = 1056768;

bool MMArchInitialiseUserSpace(MMSpace *space, MMRegion *region) {
	region->baseAddress = MM_USER_SPACE_START; 
	region->pageCount = MM_USER_SPACE_SIZE / K_PAGE_SIZE;

	if (!MMCommit(K_PAGE_SIZE, true)) {
		return false;
	}

	space->data.cr3 = MMPhysicalAllocate(ES_FLAGS_DEFAULT);

	KMutexAcquire(&coreMMSpace->reserveMutex);
	MMRegion *l1Region = MMReserve(coreMMSpace, L1_COMMIT_SIZE_BYTES, MM_REGION_NORMAL | MM_REGION_NO_COMMIT_TRACKING | MM_REGION_FIXED);
	if (l1Region) space->data.l1Commit = (uint8_t *) l1Region->baseAddress;
	KMutexRelease(&coreMMSpace->reserveMutex);

	if (!space->data.l1Commit) {
		return false;
	}

	uint64_t *pageTable = (uint64_t *) MMMapPhysical(kernelMMSpace, (uintptr_t) space->data.cr3, K_PAGE_SIZE, ES_FLAGS_DEFAULT);
	EsMemoryZero(pageTable + 0x000, K_PAGE_SIZE / 2);
	EsMemoryCopy(pageTable + 0x100, (uint64_t *) (PAGE_TABLE_L4 + 0x100), K_PAGE_SIZE / 2);
	pageTable[512 - 2] = space->data.cr3 | 3;
	MMFree(kernelMMSpace, pageTable);

	return true;
}

bool MMSpaceInitialise(MMSpace* space)
{
    space->user = true;

    MMRegion* region = (MMRegion*)EsHeapAllocate(sizeof(MMRegion), true, K_CORE);

    if (!region) return false;

    if (!MMArchInitialiseUserSpace(space, region))
    {
        EsHeapFree(region, sizeof(MMRegion), K_CORE);
        return false;
    }

    TreeInsert(&space->freeRegionsBase, &region->itemBase, region, MakeShortKey(region->baseAddress));
    TreeInsert(&space->freeRegionsSize, &region->itemSize, region, MakeShortKey(region->pageCount), AVL_DUPLICATE_KEYS_ALLOW);

    return true;
}

#define ES_PROCESS_EXECUTABLE_NOT_LOADED     (0)
#define ES_PROCESS_EXECUTABLE_FAILED_TO_LOAD (1)
#define ES_PROCESS_EXECUTABLE_LOADED         (2)

struct KLoadedExecutable {
	uintptr_t startAddress;

	uintptr_t tlsImageStart;
	uintptr_t tlsImageBytes;
	uintptr_t tlsBytes; // All bytes after the image are to be zeroed.

	bool isDesktop, isBundle;
};

u8 desktop_executable_buffer[8192] = {};

EsError hard_disk_read_desktop_executable()
{
    u32 unaligned_desktop_offset = hardcoded_kernel_file_offset + kernel_size;
    u32 desktop_offset = (u32)align(unaligned_desktop_offset, 0x200);

    EsAssert(ahci_drive_count > 0);
    EsAssert(ahci_drive_count == 1);
    EsAssert(mbr_partition_count > 0);
    EsAssert(mbr_partition_count == 1);

    KDMABuffer buffer = { (uintptr_t) desktop_executable_buffer };
    BlockDeviceAccessRequest request = {};
    request.offset = desktop_offset;
    request.count = align(hardcoded_desktop_size, 0x200);
    request.operation = K_ACCESS_READ;
    request.device = (BlockDevice*) &ahci_drives[0];
    request.buffer = &buffer;

    EsError result = FSBlockDeviceAccess(request);
    EsAssert(result == ES_SUCCESS);

    return result;
}

struct ElfHeader {
	uint32_t magicNumber; // 0x7F followed by 'ELF'
	uint8_t bits; // 1 = 32 bit, 2 = 64 bit
	uint8_t endianness; // 1 = LE, 2 = BE
	uint8_t version1;
	uint8_t abi; // 0 = System V
	uint8_t _unused0[8];
	uint16_t type; // 1 = relocatable, 2 = executable, 3 = shared
	uint16_t instructionSet; // 0x03 = x86, 0x28 = ARM, 0x3E = x86-64, 0xB7 = AArch64
	uint32_t version2;

#ifdef ES_BITS_32
	uint32_t entry;
	uint32_t programHeaderTable;
	uint32_t sectionHeaderTable;
	uint32_t flags;
	uint16_t headerSize;
	uint16_t programHeaderEntrySize;
	uint16_t programHeaderEntries;
	uint16_t sectionHeaderEntrySize;
	uint16_t sectionHeaderEntries;
	uint16_t sectionNameIndex;
#else
	uint64_t entry;
	uint64_t programHeaderTable;
	uint64_t sectionHeaderTable;
	uint32_t flags;
	uint16_t headerSize;
	uint16_t programHeaderEntrySize;
	uint16_t programHeaderEntries;
	uint16_t sectionHeaderEntrySize;
	uint16_t sectionHeaderEntries;
	uint16_t sectionNameIndex;
#endif
};

struct ElfProgramHeader {
	uint32_t type; // 0 = unused, 1 = load, 2 = dynamic, 3 = interp, 4 = note
	uint32_t flags; // 1 = executable, 2 = writable, 4 = readable
	uint64_t fileOffset;
	uint64_t virtualAddress;
	uint64_t _unused0;
	uint64_t dataInFile;
	uint64_t segmentSize;
	uint64_t alignment;

    bool arch_check()
    {
        // 64 bit
        return virtualAddress >= 0xC0000000ULL || virtualAddress < 0x1000 || segmentSize > 0x10000000ULL;
    }
};

EsError k_load_desktop_elf(KLoadedExecutable* executable)
{
    Process* process = GetCurrentThread()->process;

    u64 executable_offset = 0;
    u64 file_size = hardcoded_desktop_size;

    {
        // Bundle
    }

    if (ES_SUCCESS != hard_disk_read_desktop_executable())
    {
        KernelPanic("Can't read desktop exe\n");
    }

    ElfHeader* header = (ElfHeader*) desktop_executable_buffer;

    uint16_t program_header_entry_size = header->programHeaderEntrySize;

	if (header->magicNumber != 0x464C457F) return ES_ERROR_UNSUPPORTED_EXECUTABLE;
	if (header->bits != 2) return ES_ERROR_UNSUPPORTED_EXECUTABLE;
	if (header->endianness != 1) return ES_ERROR_UNSUPPORTED_EXECUTABLE;
	if (header->abi != 0) return ES_ERROR_UNSUPPORTED_EXECUTABLE;
	if (header->type != 2) return ES_ERROR_UNSUPPORTED_EXECUTABLE;
	if (header->instructionSet != 0x3E) return ES_ERROR_UNSUPPORTED_EXECUTABLE;

    ElfProgramHeader *programHeaders = (ElfProgramHeader *) EsHeapAllocate(program_header_entry_size * header->programHeaderEntries, false, K_PAGED);
	if (!programHeaders) return ES_ERROR_INSUFFICIENT_RESOURCES;
	EsDefer(EsHeapFree(programHeaders, 0, K_PAGED));

    EsMemoryCopy(programHeaders, &desktop_executable_buffer[executable_offset + header->programHeaderTable], program_header_entry_size * header->programHeaderEntries);

    for (u64 ph_i = 0; ph_i < header->programHeaderEntries; ph_i++)
    {
        ElfProgramHeader* ph = (ElfProgramHeader*) ((u8*)programHeaders + program_header_entry_size * ph_i);

        
        if (ph->type == 1) // PT_LOAD
        {
            if (ph->arch_check())
            {
                return ES_ERROR_UNSUPPORTED_EXECUTABLE;
            }

            // @TODO: could do this part mmaping the file, but this is easier to start with
            void* success = MMStandardAllocate(process->vmm, RoundUp(ph->segmentSize, (u64)K_PAGE_SIZE), ES_FLAGS_DEFAULT, (u8*)RoundDown(ph->virtualAddress, (u64)K_PAGE_SIZE));

            if (success)
            {
                EsMemoryCopy((void*)ph->virtualAddress, &desktop_executable_buffer[executable_offset + ph->fileOffset], ph->dataInFile);
            }
            else
            {
                return ES_ERROR_INSUFFICIENT_RESOURCES;
            }
        }
        else if (ph->type == 7) // PT_TLS
        {
            executable->tlsImageStart = ph->virtualAddress;
            executable->tlsImageBytes = ph->dataInFile;
            executable->tlsBytes = ph->segmentSize;
        }
    }

    executable->startAddress = header->entry;
    return ES_SUCCESS;
}

struct EsProcessStartupInformation {
	bool isDesktop, isBundle;
	uintptr_t applicationStartAddress;
	uintptr_t tlsImageStart;
	uintptr_t tlsImageBytes;
	uintptr_t tlsBytes; // All bytes after the image are to be zeroed.
	uintptr_t timeStampTicksPerMs;
	EsProcessCreateData data;
};


#define ES_PROCESS_CREATE_PAUSED (1 << 0)

void process_load_desktop_executable()
{
    Process* process = GetCurrentThread()->process;

    KLoadedExecutable exe = {};
    exe.isDesktop = true;
    EsError load_error = ES_SUCCESS;

    k_load_desktop_elf(&exe);
    EsProcessStartupInformation* startup_information = (EsProcessStartupInformation*) MMStandardAllocate(process->vmm, sizeof(EsProcessStartupInformation), ES_FLAGS_DEFAULT);
    if (!startup_information) KernelPanic("Can't allocate startup information\n");

    startup_information->isDesktop = true;
    startup_information->isBundle = false;
    startup_information->applicationStartAddress = exe.startAddress;
    startup_information->tlsImageStart = exe.tlsImageStart;
    startup_information->tlsImageBytes = exe.tlsImageBytes;
    startup_information->tlsBytes = exe.tlsBytes;
    startup_information->timeStampTicksPerMs = timeStampTicksPerMs;
    EsMemoryCopy(&startup_information->data, &process->data, sizeof(EsProcessCreateData));
    
    u64 thread_flags = SPAWN_THREAD_USERLAND;
    if (process->creationFlags & ES_PROCESS_CREATE_PAUSED) thread_flags |= SPAWN_THREAD_PAUSED;

    process->executableState = ES_PROCESS_EXECUTABLE_LOADED;
    process->executableMainThread = ThreadSpawn("MainThread", exe.startAddress, (uintptr_t)startup_information, thread_flags, process);

    if (!process->executableMainThread) KernelPanic("Couldnt create main thread for executable\n");

    KEventSet(&process->executableLoadAttemptComplete);
}

// ProcessStartWithNode
bool process_start_with_something(Process* process)
{
    KSpinlockAcquire(&scheduler.dispatchSpinlock);
    if (process->executableStartRequest)
    {
        KSpinlockRelease(&scheduler.dispatchSpinlock);
        return false;
    }

    process->executableStartRequest = true;
    KSpinlockRelease(&scheduler.dispatchSpinlock);

    // @TODO: get the name of the process from the file node

    // initialize the memory space
    bool success = MMSpaceInitialise(process->vmm);
    if (!success) return false;

    // open file handle

    // ?? @TODO @WARNING
    if (KEventPoll(&scheduler.allProcessesTerminatedEvent))
    {
        KernelPanic("ProcessStartWithNode - allProcessesTerminatedEvent was set\n");
    }

    // assign node
    
    process->blockShutdown = true;
    __sync_fetch_and_add(&scheduler.activeProcessCount, 1);
    __sync_fetch_and_add(&scheduler.blockShutdownProcessCount, 1);

    // Add the process to the list of all processes,
    // and spawn the kernel thread to load the executable.
    // This is synchronized under allProcessesMutex so that the process can't be terminated or paused
    // until loadExecutableThread has been spawned.
    KMutexAcquire(&scheduler.allProcessesMutex);
    scheduler.allProcesses.InsertEnd(&process->allItem);
    // @TODO: change thread fn
    Thread *loadExecutableThread = ThreadSpawn("ExecLoad", (uintptr_t) process_load_desktop_executable, 0, ES_FLAGS_DEFAULT, process);
    KMutexRelease(&scheduler.allProcessesMutex);

    if (!loadExecutableThread) {
        CloseHandleToObject(process, KERNEL_OBJECT_PROCESS);
        return false;
    }

    // Wait for the executable to be loaded.

    CloseHandleToObject(loadExecutableThread, KERNEL_OBJECT_THREAD);
    KEventWait(&process->executableLoadAttemptComplete, ES_WAIT_NO_TIMEOUT);

    if (process->executableState == ES_PROCESS_EXECUTABLE_FAILED_TO_LOAD) {
        KernelLog(LOG_ERROR, "Scheduler", "executable load failure", "Executable failed to load.\n");
        return false;
    }

    return true;
}

void start_desktop_process()
{
    process_start_with_something(desktopProcess);
}
KEvent shutdownEvent;

extern "C" void KernelMain(uintptr_t _)
{
    desktopProcess = ProcessSpawn(PROCESS_DESKTOP);
    drivers_init();

    start_desktop_process();
    KEventWait(&shutdownEvent, ES_WAIT_NO_TIMEOUT);
}

extern "C" void KernelInitialise()
{										
	kernelProcess = ProcessSpawn(PROCESS_KERNEL);			// Spawn the kernel process.
	MMInitialise();							// Initialise the memory manager.
	KThreadCreate("KernelMain", KernelMain);			// Create the KernelMain thread.
	ArchInitialise(); 						// Start processors and initialise CPULocalStorage. 
	scheduler.started = true;					// Start the pre-emptive scheduler.
}
