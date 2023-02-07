import Foundation
import BigInt


class PrivateKey: NSObject {
    let key: String
    static let GROUP_ORDER = "0x0073EDA753299D7D483339D80809A1D80553BDA402FFFE5BFEFFFFFFFF00000001"

    init(hexstr: String) {
        self.key = hexstr
    }

    init(from_seed: Data) {
        let cstring = generate_key(from_seed.hex)!
        let key = String(cString: cstring)
        cstring.deallocate()
        self.key = key
    }

    func get_g1_string() -> String {
        let cstring = get_g1(self.key)!
        let g1 = String(cString: cstring)
        cstring.deallocate()
        return g1
    }

    class func derive_child_sk(_ sk: PrivateKey, _ index: Int) -> PrivateKey {
        let cstring = derive_child_key_unhardened(sk.key, Int32(index))!
        let new_key = String(cString: cstring)
        cstring.deallocate()
        let sk1 = PrivateKey(hexstr: new_key)
        return sk1
    }
    
    class func derive_child_sk_hardened(_ sk: PrivateKey, _ index: Int) -> PrivateKey {
        let cstring = derive_child_key_hardened(sk.key, Int32(index))!
        let new_key = String(cString: cstring)
        cstring.deallocate()
        let sk1 = PrivateKey(hexstr: new_key)
        return sk1
    }

    class func derive_path(sk: PrivateKey, path: [Int]) -> PrivateKey {
        var key = sk
        for index in path {
            key = PrivateKey.derive_child_sk(key, index)
        }
        return key
    }

    class func derive_path_hardened(sk: PrivateKey, path: [Int]) -> PrivateKey {
        var key = sk
        for index in path {
            key = PrivateKey.derive_child_sk_hardened(key, index)
        }
        return key
    }

    class func master_sk_to_wallet_sk_hardened_intermediate(master: PrivateKey) -> PrivateKey {
        return PrivateKey.derive_path_hardened(sk: master, path: [12381, 8444, 2])
    }

    class func master_sk_to_wallet_sk_hardened(master: PrivateKey, index: Int) -> PrivateKey {
        let intermediate = PrivateKey.master_sk_to_wallet_sk_hardened_intermediate(master: master)
        return PrivateKey.derive_child_sk_hardened(intermediate, index)
    }

    class func master_sk_to_wallet_sk_unhardened_intermediate(master: PrivateKey) -> PrivateKey {
        return PrivateKey.derive_path(sk: master, path: [12381, 8444, 2])
    }

    class func master_sk_to_wallet_sk_unhardened(master: PrivateKey, index: Int) -> PrivateKey {
        let intermediate = PrivateKey.master_sk_to_wallet_sk_unhardened_intermediate(master: master)
        return PrivateKey.derive_child_sk(intermediate, index)
    }

    class func calculate_synthetic_offset(public_key: String, hidden_puzzle_hash: String) -> BigInt {
        let bytes = public_key.hex! + hidden_puzzle_hash.hex!
        let blob = sha256(data: bytes)
        var offset = BigInt(data1: blob)
        let group_order = BigInt(data1: GROUP_ORDER.hex!)
        if offset < 0 {
            // this is implement of python mod
            var multiplier = BigInt(0)
            multiplier = offset / group_order - BigInt(1)
            let result = offset - (multiplier * group_order)
            return result
        } else {
            let result = offset % group_order
            return result
        }

    }

    class func calculate_synthetic_secret_key(secret_key: PrivateKey) -> PrivateKey {
        let hidden_puzzle_hash = "711d6c4e32c92e53179b199484cf8c897542bc57f2b22582799f9d657eec4699"
        let secret_exponent = BigInt(data1: secret_key.key.hex!)
        let synthetic_offset_big = calculate_synthetic_offset(public_key: secret_key.get_g1_string(), hidden_puzzle_hash: hidden_puzzle_hash)
        let group_order = BigInt(data1: GROUP_ORDER.hex!)
        let synthetic_secret_exponent = (secret_exponent + synthetic_offset_big) % group_order

        var blob = synthetic_secret_exponent.serialize_32()
        if blob.count == 33 {
            blob = blob.advanced(by: 1)
        }
        let synthetic_secret_key = PrivateKey(hexstr: blob.hex)
        return synthetic_secret_key
    }

    class func calculate_synthetic_public_key(public_key: String) -> String {
        let hidden_puzzle_hash = "711d6c4e32c92e53179b199484cf8c897542bc57f2b22582799f9d657eec4699"
        let synthetic_offset = calculate_synthetic_offset(public_key: public_key, hidden_puzzle_hash: hidden_puzzle_hash)
        var ser = synthetic_offset.serialize_32()

        if ser.count == 33 {
            ser = ser.advanced(by: 1)
        }

        let synthetic_offset_key = PrivateKey(hexstr: ser.hex)
        let synthetic_key_offset_pk = synthetic_offset_key.get_g1_string()
        let cstring = add_g1(public_key, synthetic_key_offset_pk)!
        let added = String(cString: cstring)
        cstring.deallocate()
        return added
    }

    func sign(message: String) -> Signature {
        let cstring = swift_sign(self.key, message)!
        let g1 = String(cString: cstring)
        cstring.deallocate()
        return Signature(hexstr: g1)
    }


}

extension BigInt {
    
    public func serialize_32() -> Data {
        // Create a data object for the magnitude portion of the BigInt
        let magnitudeData = self.magnitude.serialize()
        
        // Similar to BigUInt, a value of 0 should return an initialized, empty Data struct
        guard magnitudeData.count > 0 else { return magnitudeData }
        
        // Create a new Data struct for the signed BigInt value
        var data = Data(capacity: magnitudeData.count + 1)
        
        // The first byte should be 0 for a positive value, or 1 for a negative value
        // i.e., the sign bit is the LSB
        data.append(self.sign == .plus ? 0 : 1)
        
        data.append(magnitudeData)
        
        if data.count < 32 {
            let tmp = Data(data)
            data = Data()
            for _ in 0..<32-tmp.count {
                data.append("00".hex!)
            }
            data.append(tmp)
        }

        return data
    }
    
    public init(data1: Data) {
        var dataArray = Array(data1)
        var sign: BigInt.Sign = BigInt.Sign.plus
        
        if dataArray.count > 0 {
            if dataArray[0] >= 128 {
                sign = BigInt.Sign.minus
                dataArray[0] = UInt8(255 - Int(dataArray[0]))
                
                if dataArray.count > 1 {
                    for index in 1..<dataArray.count {
                        dataArray[index] = UInt8(255 - Int(dataArray[index]))
                    }
                    if dataArray[dataArray.count - 1] == 255 {
                        print("Hello")
                        for i in stride(from: dataArray.count-1, to: 0, by: -1) {
                            if dataArray[i] == 255 {
                                dataArray[i] = 0
                                if (i == 30) {
                                    print("Hello 112")
                                }
                            } else {
                                dataArray[i] += 1
                                break
                            }
                        }
//                        dataArray[dataArray.count - 1] = 0
//                        dataArray[dataArray.count - 2] += 1
                    } else {
                        dataArray[dataArray.count - 1] = UInt8((Int(dataArray[dataArray.count - 1]) + 1) % 255)
                    }
                }
            }
        }

        let magnitude = BigUInt.init(Data.init(bytes: dataArray))
        self .init(sign: sign, magnitude: magnitude)
    }
}
