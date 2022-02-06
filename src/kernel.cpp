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
    void *MMStandardAllocate(MMSpace *space, size_t bytes, uint32_t flags, void *baseAddress = nullptr, bool commitAll = true);
    void CloseHandleToObject(void *object, KernelObjectType type, uint32_t flags = 0);
    bool MMFree(MMSpace *space, void *address, size_t expectedSize = 0, bool userOnly = false);
    bool OpenHandleToObject(void *object, KernelObjectType type, uint32_t flags);
uintptr_t /* Returns physical address of first page, or 0 if none were available. */ MMPhysicalAllocate(unsigned flags, 
		uintptr_t count = 1 /* Number of contiguous pages to allocate. */, 
		uintptr_t align = 1 /* Alignment, in pages. */, 
		uintptr_t below = 0 /* Upper limit of physical address, in pages. E.g. for 32-bit pages only, pass (0x100000000 >> K_PAGE_BITS). */);
    void MMPhysicalFree(uintptr_t page /* Physical address. */, 
		bool mutexAlreadyAcquired = false /* Internal use. Pass false. */, 
		size_t count = 1 /* Number of consecutive pages to free. */);

    bool MMPhysicalAllocateAndMap(size_t sizeBytes, size_t alignmentBytes, size_t maximumBits, bool zeroed, uint64_t caching, uint8_t **virtualAddress, uintptr_t *physicalAddress);
    void MMPhysicalFreeAndUnmap(void *virtualAddress, uintptr_t physicalAddress);
}

typedef uint64_t EsGeneric;

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
	union { SimpleList *previous, *last; };
	union { SimpleList *next, *first; };
};

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

struct KWriterLock { // One writer or many readers.
	LinkedList<Thread> blockedThreads;
	volatile intptr_t state; // -1: exclusive; >0: shared owners.
#ifdef DEBUG_BUILD
	volatile Thread *exclusiveOwner;
#endif
};

#define K_LOCK_EXCLUSIVE (true)
#define K_LOCK_SHARED (false)

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
    void KSpinlockAssertLocked(KSpinlock *spinlock);
}

struct Pool {
	size_t elementSize;
	void *cache[POOL_CACHE_COUNT];
	size_t cacheEntries;
	KMutex mutex;
};

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
    bool KEventWait(KEvent *event, uint64_t timeoutMs = ES_WAIT_NO_TIMEOUT); // See KEventWaitMultiple to wait for multiple events. Returns false if the wait timed out.
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
};

struct Process {
	MMSpace *vmm;
    MessageQueue messageQueue;
	HandleTable handleTable;

	LinkedList<Thread> threads;
	KMutex threadsMutex;

	// Creation information:
	struct KNode *executableNode;
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

struct Scheduler {
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
};

extern "C" void AsyncTaskThread();
extern "C" Thread* ThreadSpawn(const char *cName, uintptr_t startAddress, uintptr_t argument1 = 0, uint32_t flags = ES_FLAGS_DEFAULT, Process *process = nullptr, uintptr_t argument2 = 0);
extern "C" void SchedulerCreateProcessorThreadsWrapper(CPULocalStorage* local)
{
    local->asyncTaskThread = ThreadSpawn("AsyncTasks", (uintptr_t) AsyncTaskThread, 0, SPAWN_THREAD_ASYNC_TASK);
    local->idleThread = ThreadSpawn("Idle", 0, 0, SPAWN_THREAD_IDLE);
}

extern Scheduler scheduler;
extern "C"
{
    void SchedulerYield(InterruptContext *context);
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

extern "C" void BitsetInitialise(Bitset* self, size_t count, bool mapAll)
{
    self->Initialise(count, mapAll);
}

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
extern "C" bool MMHandlePageFault(MMSpace *space, uintptr_t address, unsigned faultFlags);
extern "C" void MMUpdateAvailablePageCount(bool increase);
extern "C" bool MMSharedResizeRegion(MMSharedRegion *region, size_t sizeBytes);
extern "C" void MMSharedDestroyRegion(MMSharedRegion *region);
extern "C" MMSharedRegion *MMSharedCreateRegion(size_t sizeBytes, bool fixed = false, uintptr_t below = 0);
extern "C" void ThreadRemove(Thread* thread);
extern "C" void MMUnreserve(MMSpace *space, MMRegion *remove, bool unmapPages, bool guardRegion = false);
extern "C" void ThreadKill(KAsyncTask *task);
extern "C" void thread_exit(Thread *thread);
extern "C" void MMSpaceOpenReference(MMSpace *space);
extern "C" void MMZeroPageThread();
extern "C" void MMBalanceThread();

extern "C" void SpawnMemoryThreads()
{
    pmm.zeroPageThread = ThreadSpawn("MMZero", (uintptr_t) MMZeroPageThread, 0, SPAWN_THREAD_LOW_PRIORITY);
    ThreadSpawn("MMBalance", (uintptr_t) MMBalanceThread, 0, ES_FLAGS_DEFAULT)->isPageGenerator = true;
    //ThreadSpawn("MMObjTrim", (uintptr_t) MMObjectCacheTrimThread, 0, ES_FLAGS_DEFAULT);
}

struct ArchCPU {
	uint8_t processorID, kernelProcessorID;
	uint8_t apicID;
	bool bootProcessor;
	uint64_t_unaligned *kernelStack;
	CPULocalStorage *local;
};

struct InterruptContext {
	uint64_t cr2, ds;
	uint8_t  fxsave[512 + 16];
	uint64_t _check, cr8;
	uint64_t r15, r14, r13, r12, r11, r10, r9, r8;
	uint64_t rbp, rdi, rsi, rdx, rcx, rbx, rax;
	uint64_t interruptNumber, errorCode;
	uint64_t rip, cs, flags, rsp, ss;
};

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
#define KERNEL_PANIC_IPI (0) // NMIs ignore the interrupt vector.

#define INTERRUPT_VECTOR_MSI_START (0x70)
#define INTERRUPT_VECTOR_MSI_COUNT (0x40)

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

extern uint64_t timeStampTicksPerMs;

extern "C" uint64_t MMArchPopulatePageFrameDatabase();
extern "C" uintptr_t MMArchGetPhysicalMemoryHighest();
extern "C" bool MMArchIsBufferInUserRange(uintptr_t baseAddress, size_t byteCount);
extern "C" void ContextSanityCheck(InterruptContext *context);

//void Scheduler::CreateProcessorThreads(CPULocalStorage *local) {
	//local->asyncTaskThread = ThreadSpawn("AsyncTasks", (uintptr_t) AsyncTaskThread, 0, SPAWN_THREAD_ASYNC_TASK);
	//local->currentThread = local->idleThread = ThreadSpawn("Idle", 0, 0, SPAWN_THREAD_IDLE);
	//local->processorID = __sync_fetch_and_add(&nextProcessorID, 1);

	//if (local->processorID >= K_MAX_PROCESSORS) { 
		//KernelPanic("Scheduler::CreateProcessorThreads - Maximum processor count (%d) exceeded.\n", local->processorID);
	//}
//}

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
    return sizeof(Thread);
}
