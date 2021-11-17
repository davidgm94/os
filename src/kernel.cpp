#define DEBUG_BUILD
#define ES_BITS_64
#define ES_ARCH_X86_64
#include <stdint.h>
#include <stddef.h>

typedef int64_t EsListViewIndex;
typedef uintptr_t EsHandle;
typedef uint64_t EsObjectID;
typedef uint64_t EsFileOffset;
typedef intptr_t EsError;
typedef uint8_t EsNodeType;
typedef int64_t EsFileOffsetDifference;

#define EsLiteral(x) (char *) x, EsCStringLength((char *) x)

inline int EsMemoryCompare(const void *a, const void *b, size_t bytes) {
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

#define ES_MEMORY_OPEN_FAIL_IF_FOUND     (0x1000)
#define ES_MEMORY_OPEN_FAIL_IF_NOT_FOUND (0x2000)

struct EsHeap;
enum KLogLevel {
	LOG_VERBOSE,
	LOG_INFO,
	LOG_ERROR,
};

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

void KernelLog(KLogLevel level, const char *subsystem, const char *event, const char *format, ...);
void KernelPanic(const char *format, ...);
void EsPrint(const char *format, ...);

void *EsHeapAllocate(size_t size, bool zeroMemory, EsHeap *kernelHeap);
void EsHeapFree(void *address, size_t expectedSize, EsHeap *kernelHeap);

struct ConstantBuffer {
	volatile size_t handles;
	size_t bytes;
	bool isPaged;
	// Data follows.
};

inline size_t EsCStringLength(const char *string) {
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

inline int EsStringCompareRaw(const char *s1, ptrdiff_t length1, const char *s2, ptrdiff_t length2) {
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

extern "C" {
    void ProcessorHalt();
    bool ProcessorAreInterruptsEnabled();
    Thread* GetCurrentThread();
    void ProcessorEnableInterrupts();
    uint64_t ProcessorReadCR3();
    void ProcessorInvalidatePage(uintptr_t virtualAddress);
    void ProcessorOut8(uint16_t port, uint8_t value);
    uint8_t ProcessorIn8(uint16_t port);
    void ProcessorOut16(uint16_t port, uint16_t value);
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


void EsPanic(const char*, ...);

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

bool KMutexAcquire(KMutex *mutex);
void KMutexRelease(KMutex *mutex);
void KMutexAssertLocked(KMutex *mutex);

#define PHYSICAL_MEMORY_MANIPULATION_REGION_PAGES (16)
#define POOL_CACHE_COUNT                          (16)


struct Pool {
	void *Add(size_t elementSize); 		// Aligned to the size of a pointer.
	void Remove(void *element);

	size_t elementSize;
	void *cache[POOL_CACHE_COUNT];
	size_t cacheEntries;
	KMutex mutex;
};

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




#define K_CORE (&heapCore)
#define K_FIXED (&heapFixed)
struct EsHeap;
extern EsHeap heapCore;
extern EsHeap heapFixed;

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

bool _ArrayEnsureAllocated(void **array, size_t minimumAllocated, size_t itemSize, uint8_t additionalHeaderBytes, EsHeap *heap);
bool _ArraySetLength(void **array, size_t newLength, size_t itemSize, uint8_t additionalHeaderBytes, EsHeap *heap);
void _ArrayDelete(void *array, uintptr_t position, size_t itemSize, size_t count);
void _ArrayDeleteSwap(void *array, uintptr_t position, size_t itemSize);
void *_ArrayInsert(void **array, const void *item, size_t itemSize, ptrdiff_t position, uint8_t additionalHeaderBytes, EsHeap *heap);
void *_ArrayInsertMany(void **array, size_t itemSize, ptrdiff_t position, size_t count, EsHeap *heap);
void _ArrayFree(void **array, size_t itemSize, EsHeap *heap);

#define ArrayHeader(array) ((_ArrayHeader *) (array) - 1)
#define ArrayLength(array) ((array) ? (ArrayHeader(array)->length) : 0)

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

	Range *Find(uintptr_t offset, bool touching);
	bool Contains(uintptr_t offset);
	void Validate();
	bool Normalize();

	bool Set(uintptr_t from, uintptr_t to, intptr_t *delta, bool modify);
	bool Clear(uintptr_t from, uintptr_t to, intptr_t *delta, bool modify);
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
struct MMSpace;
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



extern Process _kernelProcess;
extern Process* kernelProcess;
extern Scheduler scheduler;

#define K_PAGED (&heapFixed)


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




inline void EsMemoryZero(void *destination, size_t bytes) {
	// TODO Prevent this from being optimised out in the kernel.

	if (!bytes) {
		return;
	}

	for (uintptr_t i = 0; i < bytes; i++) {
		((uint8_t *) destination)[i] = 0;
	}
}



// This file is part of the Essence operating system.
// It is released under the terms of the MIT license -- see LICENSE.md.
// Written by: nakst.



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

	void Destroy(); 
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

#define SPAWN_THREAD_USERLAND     (1 << 0)
#define SPAWN_THREAD_LOW_PRIORITY (1 << 1)
#define SPAWN_THREAD_PAUSED       (1 << 2)
#define SPAWN_THREAD_ASYNC_TASK   (1 << 3)
#define SPAWN_THREAD_IDLE         (1 << 4)


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
	void AddActiveThread(Thread *thread, bool start /* put it at the start of the active list */); // Add an active thread into the queue.
	void MaybeUpdateActiveList(Thread *thread); // After changing the priority of a thread, call this to move it to the correct active thread queue if needed.
	void NotifyObject(LinkedList<Thread> *blockedThreads, bool unblockAll, Thread *previousMutexOwner = nullptr);
	void UnblockThread(Thread *unblockedThread, Thread *previousMutexOwner = nullptr);
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


MMSpace _kernelMMSpace, _coreMMSpace;
#define kernelMMSpace (&_kernelMMSpace)
#define coreMMSpace (&_coreMMSpace)
void *MMStandardAllocate(MMSpace *space, size_t bytes, uint32_t flags, void *baseAddress = nullptr, bool commitAll = true);
MMRegion *MMFindAndPinRegion(MMSpace *space, uintptr_t address, uintptr_t size); 
bool MMCommitRange(MMSpace *space, MMRegion *region, uintptr_t pageOffset, size_t pageCount);
void MMUnpinRegion(MMSpace *space, MMRegion *region);


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
bool MMFree(MMSpace *space, void *address, size_t expectedSize = 0, bool userOnly = false);



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










bool KThreadCreate(const char *cName, void (*startAddress)(uintptr_t), uintptr_t argument = 0);
Process *ProcessSpawn(ProcessType processType);

struct InterruptContext;
struct CPULocalStorage;






#define ES_WAIT_NO_TIMEOUT            (-1)
#define ES_MAX_WAIT_COUNT             (8)






struct CPULocalStorage;

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

struct MMObjectCache {
	KSpinlock lock; // Used instead of a mutex to keep accesses to the list lightweight.
	SimpleList items;
	size_t count;
	bool (*trim)(MMObjectCache *cache); // Return true if an object was trimmed.
	KWriterLock trimLock; // Open in shared access to trim the cache.
	LinkedItem<MMObjectCache> item;
	size_t averageObjectBytes;
};




bool MMHandlePageFault(MMSpace *space, uintptr_t address, unsigned flags);

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



Scheduler scheduler;

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




#define K_ACCESS_READ (0)
#define K_ACCESS_WRITE (1)

struct KDMABuffer {
	uintptr_t virtualAddress;
	size_t totalByteCount;
	uintptr_t offsetBytes;
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

struct CCSpaceCallbacks {
	EsError (*readInto)(CCSpace *fileCache, void *buffer, EsFileOffset offset, EsFileOffset count);
	EsError (*writeFrom)(CCSpace *fileCache, const void *buffer, EsFileOffset offset, EsFileOffset count);
};


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
	void Destroy();
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
	void Destroy(); 
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

NetConnection *NetConnectionOpen(EsAddress *address, size_t sendBufferBytes, size_t receiveBufferBytes, uint32_t flags);
void NetConnectionClose(NetConnection *connection);
void NetConnectionNotify(NetConnection *connection, uintptr_t sendWritePointer, uintptr_t receiveReadPointer);
void NetConnectionDestroy(NetConnection *connection);

void ProcessRemove(Process *process);
void CloseHandleToObject(void *object, KernelObjectType type, uint32_t flags = 0)
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

struct ACPIDescriptorTable {
#define ACPI_DESCRIPTOR_TABLE_HEADER_LENGTH (36)
	uint32_t signature;
	uint32_t length;
	uint64_t id;
	uint64_t tableID;
	uint32_t oemRevision;
	uint32_t creatorID;
	uint32_t creatorRevision;
};

struct MultipleAPICDescriptionTable {
	uint32_t lapicAddress; 
	uint32_t flags;
};

struct ArchCPU {
	uint8_t processorID, kernelProcessorID;
	uint8_t apicID;
	bool bootProcessor;
	void **kernelStack;
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


extern "C"
{
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

struct MSIHandler {
	KIRQHandler callback;
	void *context;
};

struct IRQHandler {
	KIRQHandler callback;
	void *context;
	intptr_t line;
	KPCIDevice *pciDevice;
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


typedef void (*CallFunctionOnAllProcessorsCallbackFunction)();
volatile CallFunctionOnAllProcessorsCallbackFunction callFunctionOnAllProcessorsCallback;
volatile uintptr_t callFunctionOnAllProcessorsRemaining;

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


// Recursive page table mapping in slot 0x1FE, so that the top 2GB are available for mcmodel kernel.
#define PAGE_TABLE_L4 ((volatile uint64_t *) 0xFFFFFF7FBFDFE000)
#define PAGE_TABLE_L3 ((volatile uint64_t *) 0xFFFFFF7FBFC00000)
#define PAGE_TABLE_L2 ((volatile uint64_t *) 0xFFFFFF7F80000000)
#define PAGE_TABLE_L1 ((volatile uint64_t *) 0xFFFFFF0000000000)
#define ENTRIES_PER_PAGE_TABLE (512)
#define ENTRIES_PER_PAGE_TABLE_BITS (9)


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

bool MMArchHandlePageFault(uintptr_t address, uint32_t flags) {
	address &= ~(K_PAGE_SIZE - 1);
	bool forSupervisor = flags & MM_HANDLE_PAGE_FAULT_FOR_SUPERVISOR;

	if (!ProcessorAreInterruptsEnabled()) {
		KernelPanic("MMArchHandlePageFault - Page fault with interrupts disabled.\n");
	}

	if (address >= MM_CORE_REGIONS_START && address < MM_CORE_REGIONS_START + MM_CORE_REGIONS_COUNT * sizeof(MMRegion) && forSupervisor) {
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
	} else if (address >= K_PAGE_SIZE) {
		Thread *thread = GetCurrentThread();
		return MMHandlePageFault(thread->temporaryAddressSpace ?: thread->process->vmm, address, flags);
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
	void *kernelStack = (void *) currentThread->kernelStack;
	*local->archCPU->kernelStack = kernelStack;
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
			GetLocalStorage()->inIRQ = true;

			uintptr_t line = interrupt - IRQ_BASE;
			KernelLog(LOG_VERBOSE, "Arch", "IRQ start", "IRQ start %d.\n", line);
			KSpinlockAcquire(&irqHandlersLock);

			for (uintptr_t i = 0; i < sizeof(irqHandlers) / sizeof(irqHandlers[0]); i++) {
				IRQHandler handler = irqHandlers[i];
				if (!handler.callback) continue;

				if (handler.line == -1) {
					// Before we get the actual IRQ line information from ACPI (which might take it a while),
					// only test that the IRQ is in the correct range for PCI interrupts.
					// This is a bit slower because we have to dispatch the interrupt to more drivers,
					// but it shouldn't break anything because they're all supposed to handle overloading anyway.
					// This is mess. Hopefully all modern computers will use MSIs for anything important.

					if (line != 9 && line != 10 && line != 11) {
						continue;
					} else {
						uint8_t mappedLine = pciIRQLines[handler.pciDevice->slot][handler.pciDevice->interruptPin - 1];

						if (mappedLine && line != mappedLine) {
							continue;
						}
					}
				} else {
					if ((uintptr_t) handler.line != line) {
						continue;
					}
				}

				KSpinlockRelease(&irqHandlersLock);
				handler.callback(interrupt - IRQ_BASE, handler.context);
				KSpinlockAcquire(&irqHandlersLock);
			}

			KSpinlockRelease(&irqHandlersLock);
			KernelLog(LOG_VERBOSE, "Arch", "IRQ end", "IRQ end %d.\n", line);

			GetLocalStorage()->inIRQ = false;
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

extern "C" void KernelMain(uintptr_t)
{
}

extern "C" void KernelInitialise()
{										
	kernelProcess = ProcessSpawn(PROCESS_KERNEL);			// Spawn the kernel process.
	MMInitialise();							// Initialise the memory manager.
	KThreadCreate("KernelMain", KernelMain);			// Create the KernelMain thread.
	ArchInitialise(); 						// Start processors and initialise CPULocalStorage. 
	scheduler.started = true;					// Start the pre-emptive scheduler.
}
