import Foundation
import CommonCrypto

class KeyChain: NSObject {

    private func pbkdf2(password: String, saltData: Data, keyByteCount: Int, prf: CCPseudoRandomAlgorithm, rounds: Int) -> Data? {
        guard let passwordData = password.data(using: .utf8) else { return nil }
        var derivedKeyData = Data(repeating: 0, count: keyByteCount)
        let derivedCount = derivedKeyData.count
        let derivationStatus: Int32 = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            let keyBuffer: UnsafeMutablePointer<UInt8> =
                derivedKeyBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return saltData.withUnsafeBytes { saltBytes -> Int32 in
                let saltBuffer: UnsafePointer<UInt8> = saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    password,
                    passwordData.count,
                    saltBuffer,
                    saltData.count,
                    prf,
                    UInt32(rounds),
                    keyBuffer,
                    derivedCount)
            }
        }
        return derivationStatus == kCCSuccess ? derivedKeyData : nil
    }

    func mnemonic_to_seed(mnemonic: String, passphrase: String) -> Data {
        //        """
        //        Uses BIP39 standard to derive a seed from entropy bytes.
        //        """
        let salt_str: String = "mnemonic" + passphrase
        let seed = pbkdf2(password: mnemonic, saltData: salt_str.data(using: .utf8)!, keyByteCount: 64, prf: CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512), rounds: 2048)
        
        return seed!
    }

    func add_private_key(mnemonic: String) -> PrivateKey {
        let seed = mnemonic_to_seed(mnemonic: mnemonic, passphrase: "")
        let key = PrivateKey(from_seed: seed)
        return key
    }
        
    func bytes_to_mnemonic(bytes: Data) -> [String] {
        var word_list: [String]? = nil
        if let path = Bundle.main.path(forResource: "english", ofType: "txt") {
            do {
                let data = try String(contentsOfFile: path, encoding: .utf8)
                let myStrings = data.components(separatedBy: .newlines)
                word_list = myStrings
            } catch {
                print(error)
            }
        }
        guard let word_list = word_list else {
            return []
        }

        let checksum_bits = 8
        let hashed_mnemonic = sha256(data: bytes)
        let checkSum = hashed_mnemonic.toBitArray()
        var seedBits = bytes.toBitArray()
        for i in 0 ..< checksum_bits {
            seedBits.append(checkSum[i])
        }

        let mnemonicCount = seedBits.count / 11
        var mnemonic = [String]()
        for i in 0 ..< mnemonicCount {
            let length = 11
            let startIndex = i * length
            let subArray = seedBits[startIndex ..< startIndex + length]
            let subString = subArray.joined(separator: "")
            let index = Int(subString, radix: 2)!
            mnemonic.append(word_list[index])
        }
        return mnemonic
    }
    
    func generate_mnemonic() -> [String] {
        var keyData = Data(count: 32)
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        return self.bytes_to_mnemonic(bytes: keyData)
    }

}

extension Data {
    var hex: String {
        return "0x" + reduce("") {$0 + String(format: "%02x", $1)}
    }
    
    static func random_token() -> Data {
        var keyData = Data(count: 32)
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        return keyData
    }

}
