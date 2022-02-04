#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wc99-designator"
#define ES_BITS_64
#define ES_ARCH_X86_64
#define KERNEL
#define TREE_VALIDATE
#define K_ARCH_STACK_GROWS_DOWN
#define COM_OUTPUT

#include <stdint.h>
#include <stddef.h>
#include <stdarg.h>

#include <mmintrin.h>
#include <xmmintrin.h>
#include <emmintrin.h>

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

#define ES_MEMORY_MAP_OBJECT_ALL (0) // Set size to this to map the entire object.
#define ES_MEMORY_MAP_OBJECT_READ_WRITE    (1 << 0)
#define ES_MEMORY_MAP_OBJECT_READ_ONLY     (1 << 1)
#define ES_MEMORY_MAP_OBJECT_COPY_ON_WRITE (1 << 2) // Files only.

#define ES_SHARED_MEMORY_READ_WRITE (1 << 0)

#define ES_SUBSYSTEM_ID_NATIVE (0)
#define ES_SUBSYSTEM_ID_POSIX (1)

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
extern EsHeap heapCore;
extern EsHeap heapFixed;
#define K_CORE (&heapCore)
#define K_FIXED (&heapFixed)
#define K_PAGED (&heapFixed)

struct MMSpace;
extern MMSpace _kernelMMSpace;
extern MMSpace _coreMMSpace;
#define kernelMMSpace (&_kernelMMSpace)
#define coreMMSpace (&_coreMMSpace)

#define CC_ACCESS_MAP                (1 << 0)
#define CC_ACCESS_READ               (1 << 1)
#define CC_ACCESS_WRITE              (1 << 2)
#define CC_ACCESS_WRITE_BACK         (1 << 3) // Wait for the write to complete before returning.
#define CC_ACCESS_PRECISE            (1 << 4) // Do not write back bytes not touched by this write. (Usually modified tracking is to page granularity.) Requires WRITE_BACK.
#define CC_ACCESS_USER_BUFFER_MAPPED (1 << 5) // Set if the user buffer is memory-mapped to mirror this or another cache.


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

extern "C" void CloseHandleToObject(void *object, KernelObjectType type, uint32_t flags = 0);
extern "C" void *MMStandardAllocate(MMSpace *space, size_t bytes, uint32_t flags, void *baseAddress = nullptr, bool commitAll = true);
extern "C" bool MMFree(MMSpace *space, void *address, size_t expectedSize = 0, bool userOnly = false);

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

extern "C" uintptr_t _KThreadTerminate;
extern "C"
{
    void TODO() __attribute__((noreturn));
    void KernelPanic(const char *format, ...) __attribute__((noreturn));

    void *EsHeapAllocate(size_t size, bool zeroMemory, EsHeap *kernelHeap);
    void *EsHeapReallocate(void *oldAddress, size_t newAllocationSize, bool zeroNewSpace, EsHeap *_heap);
    void EsHeapFree(void *address, size_t expectedSize, EsHeap *kernelHeap);
    void MMPhysicalActivatePages(uintptr_t pages, uintptr_t count);
    bool MMCommit(uint64_t bytes, bool fixed);
    void PMCopy(uintptr_t page, void *_source, size_t pageCount);
    uintptr_t ProcessorGetRSP();
    uintptr_t ProcessorGetRBP();
    void ProcessorDebugOutputByte(uint8_t byte);
    void processorGDTR();
    bool PostContextSwitch(InterruptContext *context, MMSpace *oldAddressSpace);
    void InterruptHandler(InterruptContext *context);
    uintptr_t Syscall(uintptr_t argument0, uintptr_t argument1, uintptr_t argument2, uintptr_t returnAddress, uintptr_t argument3, uintptr_t argument4, uintptr_t *userStackPointer);
    void PCProcessMemoryMap();
    void ProcessorHalt() __attribute__((noreturn));
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
    void ProcessCrash(Process *process, EsCrashReason *crashReason);
    void MMInitialise();
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
    void MMArchInitialise();
    void MMArchFreeVAS(MMSpace *space);
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
    void EsMemoryFill(void *from, void *to, uint8_t byte);
    uint8_t EsMemorySumBytes(uint8_t *source, size_t bytes);
    int EsMemoryCompare(const void *a, const void *b, size_t bytes);
    void EsMemoryZero(void *destination, size_t bytes);
    void EsMemoryCopy(void *_destination, const void *_source, size_t bytes);
    void *EsCRTmemcpy(void *dest, const void *src, size_t n);
    size_t EsCRTstrlen(const char *s);
    char *EsCRTstrcpy(char *dest, const char *src);
    void EsMemoryCopyReverse(void *_destination, void *_source, size_t bytes);
    void EsMemoryMove(void *_start, void *_end, intptr_t amount, bool zeroEmptySpace);
    void EsAssertionFailure(const char *file, int line);
    size_t EsCStringLength(const char *string);
    int EsStringCompareRaw(const char *s1, ptrdiff_t length1, const char *s2, ptrdiff_t length2);
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

extern "C"
{
    bool KWriterLockTake(KWriterLock *lock, bool write, bool poll = false);
    void KWriterLockReturn(KWriterLock *lock, bool write);
    void KWriterLockConvertExclusiveToShared(KWriterLock *lock);
    void KWriterLockAssertExclusive(KWriterLock *lock);
    void KWriterLockAssertShared(KWriterLock *lock);
    void KWriterLockAssertLocked(KWriterLock *lock);
}

struct KMutex { // Mutual exclusion. Thread-owned.
	struct Thread *volatile owner;
#ifdef DEBUG_BUILD
	uintptr_t acquireAddress, releaseAddress, id; 
#endif
	LinkedList<struct Thread> blockedThreads;
};

extern "C"
{
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
}

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

extern "C"
{
    void KSpinlockAcquire(KSpinlock *spinlock);
    void KSpinlockRelease(KSpinlock *spinlock);
    void KSpinlockReleaseForced(KSpinlock *spinlock);
    void KSpinlockAssertLocked(KSpinlock *spinlock);
}

struct Pool {
	size_t elementSize;
	void *cache[POOL_CACHE_COUNT];
	size_t cacheEntries;
	KMutex mutex;
};

extern "C"
{
    void *PoolAdd(Pool* pool, size_t _elementSize); 		// Aligned to the size of a pointer
    void PoolRemove(Pool* pool, void *address);
}

struct KEvent { // Waiting and notifying. Can wait on multiple at once. Can be set and reset with interrupts disabled.
	volatile bool autoReset; // This should be first field in the structure, so that the type of KEvent can be easily declared with {autoReset}.
	volatile uintptr_t state; // @TODO: change this into a bool?
	LinkedList<Thread> blockedThreads;
	volatile size_t handles;
};

extern "C"
{
    bool KEventSet(KEvent *event, bool maybeAlreadySet = false);
    void KEventReset(KEvent *event); 
    bool KEventPoll(KEvent *event); // TODO Remove this! Currently it is only used by KAudioFillBuffersFromMixer.
    bool KEventWait(KEvent *event, uint64_t timeoutMs = ES_WAIT_NO_TIMEOUT); // See KEventWaitMultiple to wait for multiple events. Returns false if the wait timed out.
    uintptr_t KEventWaitMultiple(KEvent **events, size_t count);
}

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

extern "C" uintptr_t HeapCalculateIndex(uintptr_t size) {
	int x = __builtin_clz(size);
	uintptr_t msb = sizeof(unsigned int) * 8 - x - 1;
	return msb - 4;
}

#define MemoryLeakDetectorAdd(...)
#define MemoryLeakDetectorRemove(...)
#define MemoryLeakDetectorCheckpoint(...)

struct EsHeap {
	KMutex mutex;

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

#define HEAP_ACQUIRE_MUTEX(a) KMutexAcquire(&(a))
#define HEAP_RELEASE_MUTEX(a) KMutexRelease(&(a))
#define HEAP_ALLOCATE_CALL(x) MMStandardAllocate(_heap == &heapCore ? coreMMSpace : kernelMMSpace, x, MM_REGION_FIXED)
#define HEAP_FREE_CALL(x) MMFree(_heap == &heapCore ? coreMMSpace : kernelMMSpace, x)

#define HEAP_REGION_HEADER(region) ((HeapRegion *) ((uint8_t *) region - USED_HEAP_REGION_HEADER_SIZE))
#define HEAP_REGION_DATA(region) ((uint8_t *) region + USED_HEAP_REGION_HEADER_SIZE)
#define HEAP_REGION_NEXT(region) ((HeapRegion *) ((uint8_t *) region + region->next))
#define HEAP_REGION_PREVIOUS(region) (region->previous ? ((HeapRegion *) ((uint8_t *) region - region->previous)) : nullptr)


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

extern "C" void *EsHeapAllocate(size_t size, bool zeroMemory, EsHeap *_heap)
{
#ifndef KERNEL
	if (!_heap) _heap = &heap;
#endif
	EsHeap &heap = *(EsHeap *) _heap;
	if (!size) return nullptr;

#ifdef USE_PLATFORM_HEAP
	return PlatformHeapAllocate(size, zeroMemory);
#endif

	size_t largeAllocationThreshold = LARGE_ALLOCATION_THRESHOLD;

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

extern "C" void EsHeapFree(void *address, size_t expectedSize, EsHeap *_heap) {
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

enum EsSyscallType
{
    ES_SYSCALL_PROCESS_EXIT,
    ES_SYSCALL_BATCH,
    ES_SYSCALL_COUNT,
};

//enum EsSyscallType {
	//// Memory.

	//ES_SYSCALL_MEMORY_ALLOCATE,
	//ES_SYSCALL_MEMORY_FREE,
	//ES_SYSCALL_MEMORY_MAP_OBJECT,
	//ES_SYSCALL_MEMORY_OPEN,
	//ES_SYSCALL_MEMORY_COMMIT,
	//ES_SYSCALL_MEMORY_FAULT_RANGE,
	//ES_SYSCALL_MEMORY_GET_AVAILABLE,

	//// Processing.

	//ES_SYSCALL_EVENT_CREATE,
	//ES_SYSCALL_EVENT_RESET,
	//ES_SYSCALL_EVENT_SET,
	//ES_SYSCALL_PROCESS_CRASH,
	//ES_SYSCALL_PROCESS_CREATE,
	//ES_SYSCALL_PROCESS_GET_STATE,
	//ES_SYSCALL_PROCESS_GET_STATUS,
	//ES_SYSCALL_PROCESS_GET_TLS,
	//ES_SYSCALL_PROCESS_OPEN,
	//ES_SYSCALL_PROCESS_PAUSE,
	//ES_SYSCALL_PROCESS_SET_TLS,
	//ES_SYSCALL_PROCESS_TERMINATE,
	//ES_SYSCALL_SLEEP,
	//ES_SYSCALL_THREAD_CREATE,
	//ES_SYSCALL_THREAD_GET_ID,
	//ES_SYSCALL_THREAD_STACK_SIZE,
	//ES_SYSCALL_THREAD_TERMINATE,
	//ES_SYSCALL_WAIT,
	//ES_SYSCALL_YIELD_SCHEDULER,

	//// Windowing.

	//ES_SYSCALL_MESSAGE_GET,
	//ES_SYSCALL_MESSAGE_POST,
	//ES_SYSCALL_MESSAGE_WAIT,

	//ES_SYSCALL_CURSOR_POSITION_GET,
	//ES_SYSCALL_CURSOR_POSITION_SET,
	//ES_SYSCALL_CURSOR_PROPERTIES_SET,
	//ES_SYSCALL_GAME_CONTROLLER_STATE_POLL,
	//ES_SYSCALL_EYEDROP_START,
	//ES_SYSCALL_SCREEN_WORK_AREA_SET,
	//ES_SYSCALL_SCREEN_WORK_AREA_GET,
	//ES_SYSCALL_SCREEN_BOUNDS_GET,
	//ES_SYSCALL_SCREEN_FORCE_UPDATE,

	//ES_SYSCALL_WINDOW_CREATE,
	//ES_SYSCALL_WINDOW_CLOSE,
	//ES_SYSCALL_WINDOW_REDRAW,
	//ES_SYSCALL_WINDOW_MOVE,
	//ES_SYSCALL_WINDOW_TRANSFER_PRESS,
	//ES_SYSCALL_WINDOW_FIND_BY_POINT,
	//ES_SYSCALL_WINDOW_GET_ID,
	//ES_SYSCALL_WINDOW_GET_BOUNDS,
	//ES_SYSCALL_WINDOW_SET_BITS,
	//ES_SYSCALL_WINDOW_SET_CURSOR,
	//ES_SYSCALL_WINDOW_SET_PROPERTY,

	//ES_SYSCALL_MESSAGE_DESKTOP,

	//// IO.

	//ES_SYSCALL_NODE_OPEN,
	//ES_SYSCALL_NODE_DELETE,
	//ES_SYSCALL_NODE_MOVE,
	//ES_SYSCALL_FILE_READ_SYNC,
	//ES_SYSCALL_FILE_WRITE_SYNC,
	//ES_SYSCALL_FILE_RESIZE,
	//ES_SYSCALL_FILE_GET_SIZE,
	//ES_SYSCALL_FILE_CONTROL,
	//ES_SYSCALL_DIRECTORY_ENUMERATE,
	//ES_SYSCALL_VOLUME_GET_INFORMATION,
	//ES_SYSCALL_DEVICE_CONTROL,

	//// Networking.

	//ES_SYSCALL_DOMAIN_NAME_RESOLVE,
	//ES_SYSCALL_ECHO_REQUEST,
	//ES_SYSCALL_CONNECTION_OPEN,
	//ES_SYSCALL_CONNECTION_POLL,
	//ES_SYSCALL_CONNECTION_NOTIFY,

	//// IPC.

	//ES_SYSCALL_CONSTANT_BUFFER_READ,
	//ES_SYSCALL_CONSTANT_BUFFER_CREATE,
	//ES_SYSCALL_PIPE_CREATE,
	//ES_SYSCALL_PIPE_WRITE,
	//ES_SYSCALL_PIPE_READ,

	//// Misc.

	//ES_SYSCALL_HANDLE_CLOSE,
	//ES_SYSCALL_HANDLE_SHARE,
	//ES_SYSCALL_BATCH,
	//ES_SYSCALL_DEBUG_COMMAND,
	//ES_SYSCALL_POSIX,
	//ES_SYSCALL_PRINT,
	//ES_SYSCALL_SHUTDOWN,
	//ES_SYSCALL_SYSTEM_TAKE_SNAPSHOT,
	//ES_SYSCALL_PROCESSOR_COUNT,

	//// End.

	//ES_SYSCALL_COUNT,
//};

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

extern "C"
{
    _ArrayHeader* ArrayHeaderGet(void* array);
    uint64_t ArrayHeaderGetLength(void* array);
    bool _ArrayMaybeInitialise(void **array, size_t itemSize, EsHeap *heap);
    bool _ArrayEnsureAllocated(void **array, size_t minimumAllocated, size_t itemSize, uint8_t additionalHeaderBytes, EsHeap *heap);
    bool _ArraySetLength(void **array, size_t newLength, size_t itemSize, uint8_t additionalHeaderBytes, EsHeap *heap);
    void _ArrayDelete(void *array, uintptr_t position, size_t itemSize, size_t count);
    void _ArrayDeleteSwap(void *array, uintptr_t position, size_t itemSize);
    void *_ArrayInsert(void **array, const void *item, size_t itemSize, ptrdiff_t position, uint8_t additionalHeaderBytes, EsHeap *heap);
    void *_ArrayInsertMany(void **array, size_t itemSize, ptrdiff_t position, size_t insertCount, EsHeap *heap);
    void _ArrayFree(void **array, size_t itemSize, EsHeap *heap);
}

template <class T, EsHeap *heap>
struct Array
{
    T *array;

	inline size_t Length() { return array ? ArrayHeaderGet(array)->length : 0; }
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
		_ArrayHeader *header = ArrayHeaderGet(array);
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
    }

    bool Normalize() {
        // @Log

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

// Range C API
extern "C"
{
    Range* RangeSetFind(RangeSet* rangeSet, uintptr_t offset, bool touching)
    {
        return rangeSet->Find(offset, touching);
    }
    bool RangeSetContains(RangeSet* rangeSet, uintptr_t offset)
    {
        return rangeSet->Contains(offset);
    }
    void RangeSetValidate(RangeSet* rangeSet)
    {
        rangeSet->Validate();
    }
    bool RangeSetClear(RangeSet* rangeSet, uintptr_t from, uintptr_t to, intptr_t* delta, bool modify)
    {
        return rangeSet->Clear(from, to, delta, modify);
    }
    bool RangeSetSet(RangeSet* rangeSet, uintptr_t from, uintptr_t to, intptr_t* delta, bool modify)
    {
        return rangeSet->Set(from, to, delta, modify);
    }
    bool RangeSetNormalize(RangeSet* rangeSet)
    {
        return rangeSet->Normalize();
    }
}

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
    EsHandle systemData;
    EsHandle subsystemData;
    EsGeneric userData;
    uint8_t subsystemID;
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
#define ES_CURRENT_THREAD	 	((EsHandle) (0x10))
#define ES_CURRENT_PROCESS	 	((EsHandle) (0x11))

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
	size_t userStackReserve;
	volatile size_t userStackCommit;

	uintptr_t tlsAddress;
    uintptr_t timerAdjustAddress;
    uint64_t timerAdjustTicks;
    uint64_t lastInterruptTimeStamp;

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

struct EsMessage {
	EsMessageType type;

	union {
		struct { uintptr_t _size[4]; } _size; // EsMessagePost supports messages at most 4 pointers in size.
	};
};

struct _EsMessageWithObject {
	void *object;
	EsMessage message;
};

struct MessageQueue {
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
    //EsHandle OpenHandle(void *_object, uint32_t _flags, KernelObjectType _type, EsHandle at = ES_INVALID_HANDLE);

    //bool CloseHandle(EsHandle handle);
    //void ModifyFlags(EsHandle handle, uint32_t newFlags);

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

//extern "C" EsHandle HandleTableOpenHandle(HandleTable* self, void* object, uint32_t flags, KernelObjectType type, EsHandle at)
//{
    //return self->OpenHandle(object, flags, type, at);
//}
//extern "C" EsHandle HandleTableCloseHandle(HandleTable* self, EsHandle handle)
//{
    //return self->CloseHandle(handle);
//}
//extern "C" void HandleTableModifyFlags(HandleTable self, EsHandle handle, uint32_t new_flags)
//{
    //return self.ModifyFlags(handle, new_flags);
//}

extern "C" uint8_t HandleTableResolveHandle(HandleTable* self, Handle* out_handle, EsHandle in_handle, KernelObjectType type_mask)
{
    return self->ResolveHandle(out_handle, in_handle, type_mask);
}

extern "C" void HandleTableDestroy(HandleTable* self)
{
    self->Destroy();
}

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

extern Process _kernelProcess;
extern Process* kernelProcess;
extern Process* desktopProcess;

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

extern "C"
{
    void KTimerSet(KTimer *timer, uint64_t triggerInMs, KAsyncTaskCallback callback = nullptr, EsGeneric argument = 0);
    void KTimerRemove(KTimer *timer); // Timers with callbacks cannot be removed (it'd race with async task delivery).
}
extern "C"
{
    void SchedulerYield(InterruptContext *context);
    void SchedulerCreateProcessorThreads(CPULocalStorage *local);
    void SchedulerAddActiveThread(Thread *thread, bool start); // Add an active thread into the queue.
    void SchedulerMaybeUpdateActiveList(Thread *thread); // After changing the priority of a thread, call this to move it to the correct active thread queue if needed.
    void SchedulerNotifyObject(LinkedList<Thread> *blockedThreads, bool unblockAll, Thread *previousMutexOwner = nullptr);
    void SchedulerUnblockThread(Thread *unblockedThread, Thread *previousMutexOwner = nullptr);
    Thread * SchedulerPickThread(CPULocalStorage *local); // Pick the next thread to execute.
    int8_t SchedulerGetThreadEffectivePriority(Thread *thread);
}

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
            int8_t effectivePriority = SchedulerGetThreadEffectivePriority(thread);

            if (start) {
                activeThreads[effectivePriority].InsertStart(&thread->item);
            } else {
                activeThreads[effectivePriority].InsertEnd(&thread->item);
            }
        }

    }
	void MaybeUpdateActiveList(Thread *thread); // After changing the priority of a thread, call this to move it to the correct active thread queue if needed.

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
                SchedulerMaybeUpdateActiveList(previousMutexOwner);

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
            SchedulerAddActiveThread(unblockedThread, true);
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

extern Scheduler scheduler;
extern "C"
{
    void SchedulerYield(InterruptContext *context)
    {
        scheduler.Yield(context);
    }
    void SchedulerCreateProcessorThreads(CPULocalStorage *local)
    {
        scheduler.CreateProcessorThreads(local);
    }
    void SchedulerAddActiveThread(Thread *thread, bool start) // Add an active thread into the queue.
    {
        scheduler.AddActiveThread(thread, start);
    }
    void SchedulerMaybeUpdateActiveList(Thread *thread) // After changing the priority of a thread, call this to move it to the correct active thread queue if needed.
    {
        scheduler.MaybeUpdateActiveList(thread);
    }
    //{
        //scheduler.NotifyObject(blockedThreads, unblockAll, previousMutexOwner);
    //}
    void SchedulerUnblockThread(Thread *unblockedThread, Thread *previousMutexOwner)
    {
        scheduler.UnblockThread(unblockedThread, previousMutexOwner);
    }
    Thread * SchedulerPickThread(CPULocalStorage *local) // Pick the next thread to execute.
    {
        return scheduler.PickThread(local);
    }
    int8_t SchedulerGetThreadEffectivePriority(Thread *thread)
    {
        return scheduler.GetThreadEffectivePriority(thread);
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

extern "C" MMRegion *MMFindAndPinRegion(MMSpace *space, uintptr_t address, uintptr_t size); 
extern "C" bool MMCommitRange(MMSpace *space, MMRegion *region, uintptr_t pageOffset, size_t pageCount);
extern "C" void MMUnpinRegion(MMSpace *space, MMRegion *region);

#define ES_SHARED_MEMORY_NAME_MAX_LENGTH (32)
struct MMSharedRegion {
	size_t sizeBytes;
	volatile size_t handles;
	KMutex mutex;
	void *data;
};

extern "C" bool OpenHandleToObject(void *object, KernelObjectType type, uint32_t flags);

extern "C" Thread* ThreadSpawn(const char *cName, uintptr_t startAddress, uintptr_t argument1 = 0, uint32_t flags = ES_FLAGS_DEFAULT, Process *process = nullptr, uintptr_t argument2 = 0);

extern "C" bool KThreadCreate(const char *cName, void (*startAddress)(uintptr_t), uintptr_t argument = 0);

struct InterruptContext;
struct CPULocalStorage;

#define ES_WAIT_NO_TIMEOUT            (-1)
#define ES_MAX_WAIT_COUNT             (8)

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

extern "C" uintptr_t BitsetGet(Bitset* self, size_t count, uintptr_t align, uintptr_t below)
{
    return self->Get(count, align, below);
}

extern "C" void BitsetTake(Bitset* self, uintptr_t index)
{
    self->Take(index);
}

extern "C" void BitsetPut(Bitset* self, uintptr_t index)
{
    self->Put(index);
}

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

extern "C" uintptr_t /* Returns physical address of first page, or 0 if none were available. */ MMPhysicalAllocate(unsigned flags, 
		uintptr_t count = 1 /* Number of contiguous pages to allocate. */, 
		uintptr_t align = 1 /* Alignment, in pages. */, 
		uintptr_t below = 0 /* Upper limit of physical address, in pages. E.g. for 32-bit pages only, pass (0x100000000 >> K_PAGE_BITS). */);
extern "C" void MMPhysicalFree(uintptr_t page /* Physical address. */, 
		bool mutexAlreadyAcquired = false /* Internal use. Pass false. */, 
		size_t count = 1 /* Number of consecutive pages to free. */);

extern "C" bool MMPhysicalAllocateAndMap(size_t sizeBytes, size_t alignmentBytes, size_t maximumBits, bool zeroed, 
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

extern PMM pmm;

extern MMRegion *mmCoreRegions;
extern size_t mmCoreRegionCount, mmCoreRegionArrayCommit;

extern MMSharedRegion* mmGlobalDataRegion;
extern GlobalData *globalData; // Shared with all processes.

typedef bool (*KIRQHandler)(uintptr_t interruptIndex /* tag for MSI */, void *context);

extern "C" MMRegion *MMFindRegion(MMSpace *space, uintptr_t address);
extern "C" void MMDecommit(uint64_t bytes, bool fixed);
extern "C" bool MMDecommitRange(MMSpace *space, MMRegion *region, uintptr_t pageOffset, size_t pageCount);
extern "C" uintptr_t MMArchTranslateAddress(uintptr_t virtualAddress, bool writeAccess =false);

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

extern MMActiveSectionManager activeSectionManager;

#define CC_MAX_MODIFIED                           (67108864 / CC_ACTIVE_SECTION_SIZE)
#define CC_MODIFIED_GETTING_FULL                  (CC_MAX_MODIFIED * 2 / 3)

extern "C" void CCDereferenceActiveSection(CCActiveSection *section, uintptr_t startingPage = 0);

extern "C" CCCachedSection *CCFindCachedSectionContaining(CCSpace *cache, EsFileOffset sectionOffset);

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
            // @Log
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
                        MMPhysicalActivatePages(entry / K_PAGE_SIZE, 1);
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
                CCActiveSectionReturnToLists(section, false);
                return error;
            }

            break;
        }

copy:;

     // Copy into/from the user's buffer.

     if (buffer) {
         if (flags & CC_ACCESS_MAP) {
             if ((start & (K_PAGE_SIZE - 1)) || (end & (K_PAGE_SIZE - 1)) || ((uintptr_t) buffer & (K_PAGE_SIZE - 1))) {
                 KernelPanic("CCSpaceAccess - Passed READ_MAP flag, but start/end/buffer misaligned.\n");
             }

             for (uintptr_t i = start; i < end; i += K_PAGE_SIZE) {
                 uintptr_t physicalAddress = MMArchTranslateAddress((uintptr_t) sectionBase + i, false);
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

extern "C" bool MMHandlePageFault(MMSpace *space, uintptr_t address, unsigned faultFlags);

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
        uintptr_t physical_address = MMArchTranslateAddress(virtual_address);
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
	// @Log

	MMObjectCacheUnregister(&fileSystem->cachedNodes);
	MMObjectCacheUnregister(&fileSystem->cachedDirectoryEntries);

	while (fileSystem->cachedNodes.count || fileSystem->cachedDirectoryEntries.count) {
		MMObjectCacheFlush(&fileSystem->cachedNodes);
		MMObjectCacheFlush(&fileSystem->cachedDirectoryEntries);
	}

	if (fileSystem->unmount) {
		fileSystem->unmount(fileSystem);
	}

	// @Log
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

extern "C" void MMUpdateAvailablePageCount(bool increase);

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
                    MMPhysicalActivatePages(page >> K_PAGE_BITS, 1);
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

KMutex objectHandleCountChange;

extern "C" bool MMSharedResizeRegion(MMSharedRegion *region, size_t sizeBytes);
extern "C" void MMSharedDestroyRegion(MMSharedRegion *region);
extern "C" MMSharedRegion *MMSharedCreateRegion(size_t sizeBytes, bool fixed = false, uintptr_t below = 0);


void ProcessRemove(Process *process);
extern "C" void ThreadRemove(Thread* thread);
void CloseHandleToObject(void *object, KernelObjectType type, uint32_t flags)
{
	switch (type) {
		case KERNEL_OBJECT_PROCESS: {
			Process *process = (Process *) object;
			uintptr_t previous = __sync_fetch_and_sub(&process->handles, 1);
			// @Log

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
                                                TODO();
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
            TODO();
		} break;

		case KERNEL_OBJECT_EMBEDDED_WINDOW: {
            TODO();
		} break;

		case KERNEL_OBJECT_PIPE: {
            TODO();
		} break;

		case KERNEL_OBJECT_CONNECTION: {
            TODO();
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
	// @Log

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
	PoolRemove(&scheduler.processPool, process); 
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
            TODO();
		} break;

		case KERNEL_OBJECT_EMBEDDED_WINDOW: {
            TODO();
		} break;

		case KERNEL_OBJECT_CONSTANT_BUFFER: {
                                                TODO();
		} break;

		case KERNEL_OBJECT_NODE: {
			failed = ES_SUCCESS != FSNodeOpenHandle((KNode *) object, flags, FS_NODE_OPEN_HANDLE_STANDARD);
		} break;

		case KERNEL_OBJECT_PIPE: {
            TODO();
		} break;

		case KERNEL_OBJECT_CONNECTION: {
            TODO();
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

extern "C" void MMUnreserve(MMSpace *space, MMRegion *remove, bool unmapPages, bool guardRegion = false);
extern "C" void ThreadKill(KAsyncTask *task);
extern "C" void KRegisterAsyncTask(KAsyncTask *task, KAsyncTaskCallback callback);
extern "C" void thread_exit(Thread *thread);
extern "C" void KThreadTerminate();
extern "C" void MMSpaceOpenReference(MMSpace *space);
extern "C" void MMSpaceDestroy(MMSpace *space);

extern "C" MMRegion *MMReserve(MMSpace *space, size_t bytes, unsigned flags, uintptr_t forcedAddress = 0) {
	// TODO Handling EsHeapAllocate failures.
	
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
		size_t guardPagesNeeded = 0;

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

extern "C" void MMPhysicalInsertFreePagesStart();
extern "C" void MMPhysicalInsertFreePagesEnd();

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

	// @Log

	KEventSet(&activeSectionManager.modifiedNonFull);
	activeSectionManager.writeBackThread = ThreadSpawn("CCWriteBehind", (uintptr_t) CCWriteBehindThread, 0, ES_FLAGS_DEFAULT);
	activeSectionManager.writeBackThread->isPageGenerator = true;
}

extern "C" void PMZero(uintptr_t *pages, size_t pageCount, bool contiguous);
extern "C" void *MMMapPhysical(MMSpace *space, uintptr_t offset, size_t bytes, uint64_t caching);
extern "C" void MMPhysicalInsertZeroedPage(uintptr_t page);
extern "C" void MMZeroPageThread();
extern "C" void MMObjectCacheTrimThread();
extern "C" void MMBalanceThread();
extern "C" void *MMMapShared(MMSpace *space, MMSharedRegion *sharedRegion, uintptr_t offset, size_t bytes, uint32_t additionalFlags = ES_FLAGS_DEFAULT, void *baseAddress = nullptr);
extern "C" bool MMFaultRange(uintptr_t address, uintptr_t byteCount, uint32_t flags = ES_FLAGS_DEFAULT);

void MMInitialise() {
	{
		// Initialise coreMMSpace and kernelMMSpace.
        mmCoreRegions = (MMRegion*)MM_CORE_REGIONS_START;
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
		// @Log
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

        mmGlobalDataRegion = MMSharedCreateRegion(sizeof(GlobalData), false, 0);
		globalData = (GlobalData *) MMMapShared(kernelMMSpace, mmGlobalDataRegion, 0, sizeof(GlobalData), MM_REGION_FIXED);
		MMFaultRange((uintptr_t) globalData, sizeof(GlobalData), MM_HANDLE_PAGE_FAULT_FOR_SUPERVISOR);
	}
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

extern ACPI acpi;

extern "C" uint32_t ACPIIoApicReadRegister(ACPIIoApic *apic, uint32_t reg);
extern "C" void ACPIIoApicWriteRegister(ACPIIoApic *apic, uint32_t reg, uint32_t value);
extern "C" void ACPICheckTable(const ACPIDescriptorTable *table);
extern "C" void *ACPIMapPhysicalMemory(uintptr_t physicalAddress, size_t length);
extern "C" void *ACPIGetRSDP();
extern "C" uint8_t ACPIGetCenturyRegisterIndex();

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

extern "C" void ACPIParseTables()
{
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

    // @Log

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

        // @Log

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
                // @Log
            }

            MMFree(kernelMMSpace, fadt);
        } else if (header->signature == SIGNATURE_HPET) {
            ACPIDescriptorTable *hpet = (ACPIDescriptorTable *) MMMapPhysical(kernelMMSpace, address, header->length, ES_FLAGS_DEFAULT);
            ACPICheckTable(hpet);
            
            if (header->length > 52 && ((uint8_t *) header)[52] == 0) {
                uint64_t baseAddress;
                EsMemoryCopy(&baseAddress, (uint8_t *) header + 44, sizeof(uint64_t));
                // @Log
                acpi.hpetBaseAddress = (uint64_t *) MMMapPhysical(kernelMMSpace, baseAddress, 1024, ES_FLAGS_DEFAULT);

                if (acpi.hpetBaseAddress) {
                    acpi.hpetBaseAddress[2] |= 1; // Start the main counter.

                    acpi.hpetPeriod = acpi.hpetBaseAddress[0] >> 32;
                    uint8_t revisionID = acpi.hpetBaseAddress[0] & 0xFF;
                    uint64_t initialCount = acpi.hpetBaseAddress[30];

                    // @Log
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
                // @Log
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
                // @Log
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

extern "C" size_t KGetCPUCount();
extern "C" CPULocalStorage *KGetCPULocal(uintptr_t index);

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
    if (context->rip == 0) KernelPanic("RIP is 0");
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

extern volatile uintptr_t tlbShootdownVirtualAddress;
extern volatile size_t tlbShootdownPageCount;

extern volatile uintptr_t callFunctionOnAllProcessorsRemaining;
extern "C" void CallFunctionOnAllProcessorCallbackWrapper(); // @INFO: this is to avoid ABI issues
//
// Spinlock since some drivers need to access it in IRQs (e.g. ACPICA).
extern KSpinlock pciConfigSpinlock; 
extern KSpinlock ipiLock;

extern "C" uint32_t LapicReadRegister(uint32_t reg);
extern "C" void LapicWriteRegister(uint32_t reg, uint32_t value);
extern "C" void LapicNextTimer(size_t ms);
extern "C" void LapicEndOfInterrupt();
extern "C" size_t ProcessorSendIPI(uintptr_t interrupt, bool nmi = false, int processorID = -1);

extern uint8_t pciIRQLines[0x100 /* slots */][4 /* pins */];

extern MSIHandler msiHandlers[INTERRUPT_VECTOR_MSI_COUNT];
extern IRQHandler irqHandlers[0x40];
extern KSpinlock irqHandlersLock; // Also for msiHandlers.

extern volatile uint64_t timeStampCounterSynchronizationValue;

extern PhysicalMemoryRegion *physicalMemoryRegions;
extern size_t physicalMemoryRegionsCount;
extern size_t physicalMemoryRegionsPagesCount;
extern size_t physicalMemoryOriginalPagesCount;
extern size_t physicalMemoryRegionsIndex;
extern uintptr_t physicalMemoryHighest;

extern EsUniqueIdentifier installation_ID; // The identifier of this OS installation, given to us by the bootloader.
extern uint32_t bootloader_ID;
extern uintptr_t bootloader_information_offset;

uintptr_t GetBootloaderInformationOffset() {
	return bootloader_information_offset;
}

#define ENTRIES_PER_PAGE_TABLE_BITS (9)


extern uint8_t core_L1_commit[(0xFFFF800200000000 - 0xFFFF800100000000) >> (/* ENTRIES_PER_PAGE_TABLE_BITS */ 9 + K_PAGE_BITS + 3)];

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

extern uint64_t timeStampTicksPerMs;

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

	int8_t effectivePriority = SchedulerGetThreadEffectivePriority(thread);

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

extern "C" uint64_t ArchGetTimeFromPITMs();

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
		// @Log
		KRegisterAsyncTask(&local->currentThread->killAsyncTask, ThreadKill);
	}

	// If the thread is waiting for an object to be notified, put it in the relevant blockedThreads list.
	// But if the object has been notified yet hasn't made itself active yet, do that for it.

	else if (local->currentThread->state == THREAD_WAITING_MUTEX) {
		KMutex *mutex = local->currentThread->blocking.mutex;

		if (!keepThreadAlive && mutex->owner) {
			mutex->owner->blockedThreadPriorities[local->currentThread->priority]++;
			SchedulerMaybeUpdateActiveList(mutex->owner);
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
			SchedulerAddActiveThread(local->currentThread, false);
		} else if (local->currentThread->type == THREAD_IDLE || local->currentThread->type == THREAD_ASYNC_TASK) {
			// Do nothing.
		} else {
			KernelPanic("Scheduler::Yield - Unrecognised thread type\n");
		}
	}

	// Get the next thread to execute.
	Thread *newThread = local->currentThread = SchedulerPickThread(local);

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
    if (newContext->rip == 0)
    {
        KernelPanic("RIP is 0");
    }
	MMSpace *addressSpace = newThread->temporaryAddressSpace ?: newThread->process->vmm;
	MMSpaceOpenReference(addressSpace);
	ArchSwitchContext(newContext, &addressSpace->data, newThread->kernelStack, newThread, oldAddressSpace);
	KernelPanic("Scheduler::Yield - DoContextSwitch unexpectedly returned.\n");
}

extern "C" uint64_t MMArchPopulatePageFrameDatabase();
extern "C" uintptr_t MMArchGetPhysicalMemoryHighest();
extern "C" bool MMArchIsBufferInUserRange(uintptr_t baseAddress, size_t byteCount);
extern "C" void ContextSanityCheck(InterruptContext *context);
extern "C" void AsyncTaskThread();

void Scheduler::CreateProcessorThreads(CPULocalStorage *local) {
	local->asyncTaskThread = ThreadSpawn("AsyncTasks", (uintptr_t) AsyncTaskThread, 0, SPAWN_THREAD_ASYNC_TASK);
	local->currentThread = local->idleThread = ThreadSpawn("Idle", 0, 0, SPAWN_THREAD_IDLE);
	local->processorID = __sync_fetch_and_add(&nextProcessorID, 1);

	if (local->processorID >= K_MAX_PROCESSORS) { 
		KernelPanic("Scheduler::CreateProcessorThreads - Maximum processor count (%d) exceeded.\n", local->processorID);
	}
}

extern "C" void MMCheckUnusable(uintptr_t physicalStart, size_t bytes);

void KernelPanic(const char *format, ...) {
	ProcessorDisableInterrupts();
	ProcessorSendIPI(KERNEL_PANIC_IPI, true);

	// Disable synchronisation objects. The panic IPI must be sent before this, 
	// so other processors don't start getting "mutex not correctly acquired" panics.
	scheduler.panic = true; 

    // @TODO @Log
	ProcessorHalt();
}

uint8_t HandleTable::ResolveHandle(Handle *outHandle, EsHandle inHandle, KernelObjectType typeMask) {
	// Special handles.
	if (inHandle == ES_CURRENT_THREAD && (typeMask & KERNEL_OBJECT_THREAD)) {
		outHandle->type = KERNEL_OBJECT_THREAD;
		outHandle->object = GetCurrentThread();
		outHandle->flags = 0;
		return RESOLVE_HANDLE_NO_CLOSE;
	} else if (inHandle == ES_CURRENT_PROCESS && (typeMask & KERNEL_OBJECT_PROCESS)) {
		outHandle->type = KERNEL_OBJECT_PROCESS;
		outHandle->object = GetCurrentThread()->process;
		outHandle->flags = 0;
		return RESOLVE_HANDLE_NO_CLOSE;
	} else if (inHandle == ES_INVALID_HANDLE && (typeMask & KERNEL_OBJECT_NONE)) {
		outHandle->type = KERNEL_OBJECT_NONE;
		outHandle->object = nullptr;
		outHandle->flags = 0;
		return RESOLVE_HANDLE_NO_CLOSE;
	}

	// Check that the handle is within the correct bounds.
	if ((!inHandle) || inHandle >= HANDLE_TABLE_L1_ENTRIES * HANDLE_TABLE_L2_ENTRIES) {
		return RESOLVE_HANDLE_FAILED;
	}

	KMutexAcquire(&lock);
	EsDefer(KMutexRelease(&lock));

	HandleTableL2 *l2 = l1r.t[inHandle / HANDLE_TABLE_L2_ENTRIES];
	if (!l2) return RESOLVE_HANDLE_FAILED;

	Handle *_handle = l2->t + (inHandle % HANDLE_TABLE_L2_ENTRIES);

	if ((_handle->type & typeMask) && (_handle->object)) {
		// Open a handle to the object so that it can't be destroyed while the system call is still using it.
		// The handle is closed in the KObject's destructor.
		if (OpenHandleToObject(_handle->object, _handle->type, _handle->flags)) {
			*outHandle = *_handle;
			return RESOLVE_HANDLE_NORMAL;
		}
	}

	return RESOLVE_HANDLE_FAILED;
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

    if (local && local->currentThread)
    {
        local->currentThread->lastInterruptTimeStamp = ProcessorReadTimeStamp();
    }

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
        Thread* currentThread = GetCurrentThread();

		if (!supervisor) {
			// EsPrint("User interrupt: %x/%x/%x\n", interrupt, context->cr2, context->errorCode);

			if (context->cs != 0x5B && context->cs != 0x6B) {
				KernelPanic("InterruptHandler - Unexpected value of CS 0x%X\n", context->cs);
			}

			if (currentThread->isKernelThread) {
				KernelPanic("InterruptHandler - Kernel thread executing user code. (1)\n");
			}

			// User-code exceptions are *basically* the same thing as system calls.
			ThreadTerminatableState previousTerminatableState = currentThread->terminatableState;
			currentThread->terminatableState = THREAD_IN_SYSCALL;

			if (local && local->spinlockCount) {
				KernelPanic("InterruptHandler - User exception occurred with spinlock acquired.\n");
			}

			// Re-enable interrupts during exception handling.
			ProcessorEnableInterrupts();
            local = nullptr; // The CPU we're executing on could change

			if (interrupt == 14) {
				bool success = MMArchHandlePageFault(context->cr2, (context->errorCode & 2) ? MM_HANDLE_PAGE_FAULT_WRITE : 0);

				if (success) {
					goto resolved;
				}
			}

			if (interrupt == 0x13) {
				//EsPrint("ProcessorReadMXCSR() = %x\n", ProcessorReadMXCSR());
			}

			// TODO Usermode exceptions and debugging.
            // @Log
			//KernelLog(LOG_ERROR, "Arch", "unhandled userland exception", 
					//"InterruptHandler - Exception (%z) in userland process (%z).\nRIP = %x\nRSP = %x\nX86_64 error codes: [err] %x, [cr2] %x\n", 
					//exceptionInformation[interrupt], 
					//currentThread->process->cExecutableName,
					//context->rip, context->rsp, context->errorCode, context->cr2);

			//EsPrint("Attempting to make a stack trace...\n");

			{
				uint64_t rbp = context->rbp;
				int traceDepth = 0;

				while (rbp && traceDepth < 32) {
					uint64_t value;
					if (!MMArchIsBufferInUserRange(rbp, 16)) break;
					if (!MMArchSafeCopy((uintptr_t) &value, rbp + 8, sizeof(uint64_t))) break;
					//EsPrint("\t%d: %x\n", ++traceDepth, value);
					if (!value) break;
					if (!MMArchSafeCopy((uintptr_t) &rbp, rbp, sizeof(uint64_t))) break;
				}
			}

			//EsPrint("Stack trace complete.\n");

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

				if (local && local->spinlockCount && ((context->cr2 >= 0xFFFF900000000000 && context->cr2 < 0xFFFFF00000000000) 
							|| context->cr2 < 0x8000000000000000)) {
					KernelPanic("HandlePageFault - Page fault occurred with spinlocks active at %x (S = %x, B = %x, LG = %x, CR2 = %x, local = %x).\n", 
							context->rip, context->rsp, context->rbp, local->currentThread->lastKnownExecutionAddress, context->cr2, local);
				}

				if ((context->flags & 0x200) && context->cr8 != 0xE) {
					ProcessorEnableInterrupts();
                    local = nullptr; // The CPU we're executing on could change
				}
				
				if (!MMArchHandlePageFault(context->cr2, MM_HANDLE_PAGE_FAULT_FOR_SUPERVISOR
							| ((context->errorCode & 2) ? MM_HANDLE_PAGE_FAULT_WRITE : 0))) {
					if (currentThread->inSafeCopy && context->cr2 < 0x8000000000000000) {
						context->rip = context->r8; // See definition of MMArchSafeCopy.
					} else {
						goto fault;
					}
				}

				ProcessorDisableInterrupts();
			} else {
				fault:
				KernelPanic("Unresolvable processor exception encountered in supervisor mode.\n%z\nRIP = %x\nX86_64 error codes: [err] %x, [cr2] %x\n"
						"Stack: [rsp] %x, [rbp] %x\nRegisters: [rax] %x, [rbx] %x, [rsi] %x, [rdi] %x.\nThread ID = %d\n", 
						exceptionInformation[interrupt], context->rip, context->errorCode, context->cr2, 
						context->rsp, context->rbp, context->rax, context->rbx, context->rsi, context->rdi, 
						currentThread ? currentThread->id : -1);
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
			CallFunctionOnAllProcessorCallbackWrapper();
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
			// @Log
		} else {
			handler.callback(interrupt - INTERRUPT_VECTOR_MSI_START, handler.context);
		}

		if (local->irqSwitchThread && scheduler.started && local->schedulerReady) {
			SchedulerYield(context); // LapicEndOfInterrupt is called in PostContextSwitch.
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
			SchedulerYield(context); // LapicEndOfInterrupt is called in PostContextSwitch.
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

extern "C" void ProcessLoadDesktopExecutable();
extern "C" Thread* CreateLoadExecutableThread(Process* process)
{
    Thread *loadExecutableThread = ThreadSpawn("ExecLoad", (uintptr_t) ProcessLoadDesktopExecutable, 0, ES_FLAGS_DEFAULT, process);
    return loadExecutableThread;
}

extern "C" void KernelMain(uintptr_t);

extern "C" void CreateMainThread()
{
    KThreadCreate("KernelMain", KernelMain);
}

extern "C" uint64_t get_size(MMRegion* region)
{
    return offsetof(MMRegion, core.used);
}
