import Testing
@testable import BlockportRuntime

struct AvailableMemoryTests {
    @Test(arguments: [
        (UInt64(24) << 30, UInt64(2) << 30, UInt64(10) << 30),
        (UInt64(8) << 30, UInt64(4) << 30, UInt64(0)),
        (UInt64(8) << 30, UInt64(6) << 30, UInt64(0)),
    ])
    func availableMemoryIsHalfThePhysicalMemoryMinusTheFootprint(physical: UInt64, footprint: UInt64, expected: UInt64) {
        #expect(AvailableMemory.available(physical: physical, footprint: footprint) == expected)
    }

    @Test func footprintIsMeasured() {
        #expect(AvailableMemory.footprint() > 0)
    }
}
