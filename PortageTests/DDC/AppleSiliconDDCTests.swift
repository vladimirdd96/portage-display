import Testing

@testable import Portage

@Suite("AppleSiliconDDC.interpretReadResult")
struct AppleSiliconDDCTests {
    @Test("Returns false when read I2C fails even if write succeeded")
    func readFailsAfterWriteSuccess() {
        var reply: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        let result = AppleSiliconDDC.interpretReadResult(
            writeSucceeded: true, readReturnCode: -1, reply: &reply
        )
        #expect(result == false)
    }

    @Test("Returns writeSucceeded when reply is empty (write-only path)")
    func writeOnlyReturnsWriteResult() {
        var emptyReply: [UInt8] = []
        #expect(
            AppleSiliconDDC.interpretReadResult(
                writeSucceeded: true, readReturnCode: 0, reply: &emptyReply
            ) == true)

        var emptyReply2: [UInt8] = []
        #expect(
            AppleSiliconDDC.interpretReadResult(
                writeSucceeded: false, readReturnCode: 0, reply: &emptyReply2
            ) == false)
    }

    @Test("Returns false on checksum mismatch")
    func checksumMismatch() {
        // Valid structure but 0xFF is not a valid checksum for this payload
        var reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x00, 0x00, 0x00, 0x12, 0x00, 0x05, 0xFF]
        let result = AppleSiliconDDC.interpretReadResult(
            writeSucceeded: true, readReturnCode: 0, reply: &reply
        )
        #expect(result == false)
    }

    @Test("Returns true when read succeeds with valid checksum")
    func validRead() {
        // Build a reply where checksum is correct: XOR of 0x50 with bytes[0..9]
        var reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x00, 0x00, 0x00, 0x12, 0x00, 0x05, 0x00]
        var chk: UInt8 = 0x50
        for i in 0...9 {
            chk ^= reply[i]
        }
        reply[10] = chk
        let result = AppleSiliconDDC.interpretReadResult(
            writeSucceeded: true, readReturnCode: 0, reply: &reply
        )
        #expect(result == true)
    }
}
