#![allow(non_snake_case)]

use synchronization::Mutex;


const ARCH_PCI_READ_CONFIG_DEFAULT_SIZE: i32 = 32;
extern {
    fn ArchPCIReadConfig(bus: u8, device: u8, function: u8, offset: u8, size: i32) -> u32;
    fn KernelPanic(format: *const u8, ...);
}

const BUS_SCAN_NEXT: u8 = 1;
const BUS_SCANNED: u8 = 2;

pub struct Controller
{
    bus_scan_states: [u8;256],
}

//pub struct EsHeap {
    //pub mutex: Mutex,
    //pub regions: [*mut HeapRegion; 12usize],
    //pub allocationsCount: usize,
    //pub size: usize,
    //pub blockCount: usize,
    //pub blocks: [u64; 16],
    //pub cannotValidate: bool,
//}

//extern "C" {
    //pub fn EsHeapAllocate(
        //size: usize,
        //zeroMemory: bool,
        //kernelHeap: *mut EsHeap,
    //) -> u64;
//}


const feature_bar_0: u64 = 1 << 0;
const feature_bar_1: u64 = 1 << 1;
const feature_bar_2: u64 = 1 << 2;
const feature_bar_3: u64 = 1 << 3;
const feature_bar_4: u64 = 1 << 4;
const feature_bar_5: u64 = 1 << 5;
const feature_interrupts: u64 = 1 << 8;
const feature_busmastering_DMA: u64 = 1 << 9;
const feature_memory_space_access: u64 = 1 << 10;
const feature_IO_port_access: u64 = 1 << 11;

struct Device
{
    device_id: u32,
    subsystem_id: u32,
    domain: u32,
    class_code: u8,
    subclass_code: u8,
    prog_IF: u8,
    bus: u8,
    slot: u8,
    function: u8,
    interrupt_PIN: u8,
    interrupt_line: u8,
}

impl Controller
{
    pub fn setup()
    {
        let mut pci: Controller = unsafe { core::mem::zeroed() };
        let base_header_type = unsafe {
            ArchPCIReadConfig(0, 0, 0, 0x0c, ARCH_PCI_READ_CONFIG_DEFAULT_SIZE)
        };
        let base_buses = if base_header_type & 0x80 != 0 { 8 } else { 1 };

        let mut bus_to_scan_count: u32 = 0;
        for base_bus in 0..base_buses
        {
            let device_id = unsafe { ArchPCIReadConfig(0, 0, base_bus, 0, ARCH_PCI_READ_CONFIG_DEFAULT_SIZE) };

            if device_id & 0xffff == 0xffff { continue; }
            pci.bus_scan_states[base_buses as usize] = BUS_SCAN_NEXT;
            bus_to_scan_count += 1;
        }

        if bus_to_scan_count == 0
        {
            unsafe { KernelPanic("No buses found\n".as_ptr() as *const u8); }
        }

        while bus_to_scan_count > 0
        {
            for bus in pci.bus_scan_states.iter_mut()
            {
                if *bus != BUS_SCAN_NEXT { continue }
                *bus = BUS_SCANNED;
                bus_to_scan_count -= 1;

                for device in 0..32 as u8
                {
                    let device_id = unsafe { ArchPCIReadConfig(*bus, device, 0, 0, ARCH_PCI_READ_CONFIG_DEFAULT_SIZE) };
                    if device_id & 0xffff == 0xffff { continue; }

                    let header_type = ((unsafe { ArchPCIReadConfig(*bus, device, 0, 0x0c, ARCH_PCI_READ_CONFIG_DEFAULT_SIZE) }) >> 16) as u8;

                    let function_count = if header_type & 0x80 != 0 { 8 } else { 1 };
                    for function in 0..function_count
                    {
                        let device_id = unsafe { ArchPCIReadConfig(*bus, device, 0, 0, ARCH_PCI_READ_CONFIG_DEFAULT_SIZE) };
                        if device_id & 0xffff == 0xffff { continue }

                        let device_class = unsafe { ArchPCIReadConfig(*bus, device, function, 0x08, ARCH_PCI_READ_CONFIG_DEFAULT_SIZE) };
                        let interruption_information = unsafe { ArchPCIReadConfig(*bus, device, function, 0x3c, ARCH_PCI_READ_CONFIG_DEFAULT_SIZE) };

                    }
                }
            }
        }
    }
}
