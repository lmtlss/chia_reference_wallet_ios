import Foundation

public class AddressCoder {
    private let bech32: Bech32

    public init(bech32m: Bool = false) {
        bech32 = Bech32(bech32m: bech32m)
    }

    private func convertBits(from: Int, to: Int, pad: Bool, idata: Data) throws -> Data {
        var acc: Int = 0
        var bits: Int = 0
        let maxv: Int = (1 << to) - 1
        let maxAcc: Int = (1 << (from + to - 1)) - 1
        var odata = Data()
        for ibyte in idata {
            acc = ((acc << from) | Int(ibyte)) & maxAcc
            bits += from
            while bits >= to {
                bits -= to
                odata.append(UInt8((acc >> bits) & maxv))
            }
        }
        if pad {
            if bits != 0 {
                odata.append(UInt8((acc << (to - bits)) & maxv))
            }
        } else if (bits >= from || ((acc << (to - bits)) & maxv) != 0) {
            throw CoderError.bitsConversionFailed
        }
        return odata
    }

    public func decode(hrp: String, addr: String) throws -> (version: Int, program: Data) {
        let dec = try bech32.decode(addr)
        guard dec.hrp == hrp else {
            throw CoderError.hrpMismatch(dec.hrp, hrp)
        }
        guard dec.checksum.count >= 1 else {
            throw CoderError.checksumSizeTooLow
        }
        let conv = try convertBits(from: 5, to: 8, pad: false, idata: dec.checksum.advanced(by: 0))
        guard conv.count >= 2 && conv.count <= 40 else {
            throw CoderError.dataSizeMismatch(conv.count)
        }

        return (Int(dec.checksum[0]), conv)
    }
    
    public func encode(hrp: String, version: Int, program: Data) throws -> String {
        var enc = Data()
        enc.append(try convertBits(from: 8, to: 5, pad: true, idata: program))
        let result = bech32.encode(hrp, values: enc)
        guard let _ = try? decode(hrp: hrp, addr: result) else {
            throw CoderError.encodingCheckFailed
        }
        return result
    }
}

extension String {

    var xch_address: String {
        
        let coder = AddressCoder(bech32m: true)
        
        do {
            let encoded = try coder.encode(hrp: "xch", version: 1, program: self.hex!)
            return encoded
        } catch {
            
        }
        return ""
    }

    var did: String {
        
        let coder = AddressCoder(bech32m: true)
        
        do {
            let encoded = try coder.encode(hrp: "did:chia:", version: 1, program: self.hex!)
            return encoded
        } catch {
            
        }
        return ""
    }

    var to_puzzle_hash: String? {
        let coder = AddressCoder(bech32m: true)
        if let decoded = try? coder.decode(hrp: "xch", addr: self) {
            let ph: Data = decoded.1
            return ph.hex
        } else {
            return nil
        }
    }
}

extension AddressCoder {
    public enum CoderError: LocalizedError {
        case bitsConversionFailed
        case hrpMismatch(String, String)
        case checksumSizeTooLow
        
        case dataSizeMismatch(Int)
        case encodingCheckFailed
        
        public var errorDescription: String? {
            switch self {
            case .bitsConversionFailed:
                return "Failed to perform bits conversion"
            case .checksumSizeTooLow:
                return "Checksum size is too low"
            case .dataSizeMismatch(let size):
                return "Program size \(size) does not meet required range 2...40"
            case .encodingCheckFailed:
                return "Failed to check result after encoding"
            case .hrpMismatch(let got, let expected):
                return "Human-readable-part \"\(got)\" does not match requested \"\(expected)\""
            }
        }
    }
}
