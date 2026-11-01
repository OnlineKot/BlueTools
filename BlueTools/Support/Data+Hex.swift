import Foundation

extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    var readableText: String? {
        guard !isEmpty, let text = String(data: self, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        let printable = trimmed.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar) || scalar == "\n" || scalar == "\r" || scalar == "\t"
        }
        return printable && !trimmed.isEmpty ? trimmed : nil
    }

    init?(hex: String) {
        let cleaned = hex
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: "0X", with: "")
            .filter { !$0.isWhitespace && $0 != ":" && $0 != "-" && $0 != "," }
        guard !cleaned.isEmpty, cleaned.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}

extension Date {
    var shortAgo: String {
        let seconds = Int(Date().timeIntervalSince(self))
        if seconds < 3 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }
}
