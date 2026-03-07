import Foundation

// ============================================================================
// SHARED LZW DECOMPRESSOR
// GIF-style variable-width LZW (9-12 bits) used by DreamGrafix format
// ============================================================================

struct LZWDecompressor {

    /// Maximum output size safety limit (prevents runaway decompression)
    static let defaultMaxOutputSize = 50000

    /// Decompress DreamGrafix LZW-compressed data.
    ///
    /// Uses GIF-style variable-width codes starting at 9 bits, growing up to 12 bits.
    /// Supports clear codes (256) for dictionary reset and end codes (257) for stream termination.
    ///
    /// - Parameters:
    ///   - data: The LZW-compressed input data
    ///   - maxOutputSize: Safety limit for output size (default: 50000 bytes)
    /// - Returns: Decompressed data, or nil if decompression fails
    static func decompressDreamGrafixLZW(data: Data, maxOutputSize: Int = defaultMaxOutputSize) -> Data? {
        guard data.count > 0 else { return nil }

        var output = Data()
        output.reserveCapacity(65536)

        // LZW constants
        let clearCode = 256
        let endCode = 257
        let maxCode = 4095  // Max 12 bits

        // Variable code width (starts at 9 bits for 8-bit data)
        var codeWidth = 9
        var nextCodeWidthThreshold = 512  // When to increase code width

        // Dictionary: maps code -> sequence of bytes
        var dictionary: [[UInt8]] = []

        // Initialize dictionary with single-byte entries
        func resetDictionary() {
            dictionary = []
            for i in 0..<256 {
                dictionary.append([UInt8(i)])
            }
            // Add clear and end codes (indices 256, 257)
            dictionary.append([])  // clear code placeholder
            dictionary.append([])  // end code placeholder
            codeWidth = 9
            nextCodeWidthThreshold = 512
        }

        resetDictionary()

        // Bit reader for extracting variable-width codes (LSB-first)
        var bitBuffer: UInt32 = 0
        var bitsInBuffer = 0
        var bytePos = 0

        func readCode() -> Int? {
            // Fill buffer with enough bits
            while bitsInBuffer < codeWidth && bytePos < data.count {
                bitBuffer |= UInt32(data[bytePos]) << bitsInBuffer
                bitsInBuffer += 8
                bytePos += 1
            }

            guard bitsInBuffer >= codeWidth else { return nil }

            let mask = (1 << codeWidth) - 1
            let code = Int(bitBuffer) & mask
            bitBuffer >>= codeWidth
            bitsInBuffer -= codeWidth

            return code
        }

        // Read first code (should be clear code)
        guard let firstCodeValue = readCode() else { return nil }

        var prevCode: Int

        if firstCodeValue == clearCode {
            // Handle initial clear code
            guard let nextCode = readCode() else { return nil }
            if nextCode == endCode { return output }
            if nextCode < 256 {
                output.append(UInt8(nextCode))
            }
            prevCode = nextCode
        } else if firstCodeValue < 256 {
            output.append(UInt8(firstCodeValue))
            prevCode = firstCodeValue
        } else {
            return nil  // Invalid first code
        }

        if prevCode == endCode { return output }

        // Main decompression loop
        while let code = readCode() {
            if code == endCode {
                break
            }

            if code == clearCode {
                resetDictionary()
                guard let nextCode = readCode() else { break }
                if nextCode == endCode { break }
                if nextCode < 256 {
                    output.append(UInt8(nextCode))
                    prevCode = nextCode
                }
                continue
            }

            var sequence: [UInt8]

            if code < dictionary.count {
                // Code is in dictionary
                sequence = dictionary[code]
            } else if code == dictionary.count {
                // Special case: code not yet in dictionary
                // This happens when encoder emits code for string just added
                if prevCode < dictionary.count {
                    let prevSequence = dictionary[prevCode]
                    sequence = prevSequence + [prevSequence[0]]
                } else {
                    // Error case
                    break
                }
            } else {
                // Invalid code
                break
            }

            // Output the sequence
            output.append(contentsOf: sequence)

            // Add new entry to dictionary: previous sequence + first byte of current
            if dictionary.count <= maxCode && prevCode < dictionary.count {
                let prevSequence = dictionary[prevCode]
                let newEntry = prevSequence + [sequence[0]]
                dictionary.append(newEntry)

                // Increase code width when dictionary reaches threshold
                if dictionary.count == nextCodeWidthThreshold && codeWidth < 12 {
                    codeWidth += 1
                    nextCodeWidthThreshold *= 2
                }
            }

            prevCode = code

            // Safety limit to prevent runaway decompression
            if output.count > maxOutputSize {
                break
            }
        }

        return output.isEmpty ? nil : output
    }
}
