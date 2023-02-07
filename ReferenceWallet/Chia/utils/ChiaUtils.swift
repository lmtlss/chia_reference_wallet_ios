import Foundation
import CryptoKit
import CommonCrypto
import SwiftyJSON

func sha256(data : Data) -> Data {
    var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
        _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
    }
    return Data(hash)
}

func int_to_bytes_swift(value : Int) -> Data {
    let cstring = int_to_bytes(value)!
    let swift_result = String(cString: cstring)
    cstring.deallocate()
    return swift_result.hex ?? Data()
}

func int_from_bytes(value : String) -> Int? {
    let cstring = int_from_bytes_swift(value)!
    let swift_result = String(cString: cstring)
    cstring.deallocate()
    return Int(swift_result)
}

public extension UInt8 {
    func mnemonicBits() -> [String] {
        let totalBitsCount = MemoryLayout<UInt8>.size * 8

        var bitsArray = [String](repeating: "0", count: totalBitsCount)

        for j in 0 ..< totalBitsCount {
            let bitVal: UInt8 = 1 << UInt8(totalBitsCount - 1 - j)
            let check = self & bitVal

            if check != 0 {
                bitsArray[j] = "1"
            }
        }
        return bitsArray
    }
}

public extension Data {
    func toBitArray() -> [String] {
        var toReturn = [String]()
        for num in [UInt8](self) {
            toReturn.append(contentsOf: num.mnemonicBits())
        }
        return toReturn
    }
}

public extension Array where Element == UInt8 {
    func toBitArray() -> [String] {
        var toReturn = [String]()
        for num in self {
            toReturn.append(contentsOf: num.mnemonicBits())
        }
        return toReturn
    }
}

func parse_coin_record(json: JSON) -> Coin {
    let amount: Int = json["coin"]["amount"].intValue
    let puzzle_hash: String = json["coin"]["puzzle_hash"].stringValue
    let parent_id: String = json["coin"]["parent_coin_info"].stringValue
    let coinbase = json["coinbase"].boolValue
    let confirmed_height: Int = json["confirmed_block_index"].intValue
    let spent_height: Int = json["spent_block_index"].intValue
    let spent: Bool = spent_height != 0
    let timestamp = json["timestamp"].intValue
    let coin = Coin(amount: amount, parent_coin_id: parent_id, puzzle_hash: puzzle_hash, coinbase: coinbase, spent: spent, timestamp: timestamp, spent_height: spent_height, confirmed_height: confirmed_height)
    return coin
}

func parse_coin_spend(json: JSON) -> CoinSpend {
    let amount: Int = json["coin_spend"]["coin"]["amount"].intValue
    let puzzle_hash: String = json["coin_spend"]["coin"]["puzzle_hash"].stringValue
    let parent_id: String = json["coin_spend"]["coin"]["parent_coin_info"].stringValue
    let coinbase = json["coinbase"].boolValue
    let confirmed_height: Int = json["confirmed_block_index"].intValue
    let spent_height: Int = json["spent_block_index"].intValue
    let spent: Bool = spent_height != 0
    let timestamp = json["timestamp"].intValue
    let int_bytes = int_to_bytes_swift(value: amount)
    let coin_id = sha256(data: parent_id.hex!+puzzle_hash.hex!+int_bytes).hex
    let coin = Coin(amount: amount, parent_coin_id: parent_id, puzzle_hash: puzzle_hash, coinbase: coinbase, spent: spent, timestamp: timestamp, spent_height: spent_height, confirmed_height: confirmed_height)
    
    
    let puzzle: Program = Program(hexstr: json["coin_spend"]["puzzle_reveal"].stringValue.noox)
    let solution: Program = Program(hexstr: json["coin_spend"]["solution"].stringValue.noox)

    let coin_spend = CoinSpend(coin_record: coin, puzzle_reveal: puzzle, solution: solution)
    return coin_spend
}
