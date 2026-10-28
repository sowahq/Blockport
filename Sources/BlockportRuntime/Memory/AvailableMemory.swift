import Darwin
import Foundation

/// Replacement for `os_proc_available_memory`.
///
/// On iOS the function reports how much the process may still allocate
/// before the system terminates it, and the game scales its caches and
/// budgets to it. On macOS there is no such limit and the function returns 0,
/// so the game believes it is out of memory. The replacement reports a budget
/// of half the physical memory minus the process's current footprint.
enum AvailableMemory {
    static let budgetFraction: UInt64 = 2

    static func available(physical: UInt64, footprint: UInt64) -> UInt64 {
        let budget = physical / budgetFraction
        return budget > footprint ? budget - footprint : 0
    }

    static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? info.phys_footprint : 0
    }
}

@_cdecl("blockport_os_proc_available_memory")
public func blockportAvailableMemory() -> Int {
    let available = AvailableMemory.available(physical: ProcessInfo.processInfo.physicalMemory, footprint: AvailableMemory.footprint())
    return Int(clamping: available)
}
