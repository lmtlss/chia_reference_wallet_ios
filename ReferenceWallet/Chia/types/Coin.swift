import Foundation
import BigInt

class CoinRecord: NSObject, Codable {
    let coin: Coin
    let synced_height: Int
    let asset_id: String
    
    init(coin: Coin, synced_height: Int, asset_id: String) {
        self.coin = coin
        self.synced_height = synced_height
        self.asset_id = asset_id
    }
    override var description: String {
        return "CoinRecord: \(self.coin), synced_height: \(synced_height), asset_id: \(asset_id)"
    }
}

func sum_coins(_ coins: [Coin]) -> Int {
    var sum = 0
    for coin in coins {
        sum += coin.amount
    }
    return sum
}

class Coin: NSObject, Codable {
    let coin_id: String
    let confirmed_height: Int
    let spent_height: Int
    let timestamp: Int
    let spent: Bool
    let coinbase: Bool
    let puzzle_hash: String
    let parent_coin_id: String
    let amount: Int

    init(amount: Int, parent_coin_id: String, puzzle_hash: String, coinbase: Bool, spent: Bool, timestamp: Int, spent_height: Int, confirmed_height: Int) {
        self.amount = amount
        self.parent_coin_id = parent_coin_id
        self.puzzle_hash = puzzle_hash
        self.coinbase = coinbase
        self.spent = spent
        self.timestamp = timestamp
        self.spent_height = spent_height
        self.confirmed_height = confirmed_height
        self.coin_id = calculate_coin_id(parent_id: parent_coin_id, puzzle_hash: puzzle_hash, amount: amount)
    }
    
    init(amount: Int, puzzle_hash: String, parent_coin_id: String) {
        self.amount = amount
        self.parent_coin_id = parent_coin_id
        self.puzzle_hash = puzzle_hash
        self.coinbase = false
        self.spent = false
        self.timestamp = 0
        self.spent_height = -1
        self.confirmed_height = -1
        self.coin_id = calculate_coin_id(parent_id: parent_coin_id, puzzle_hash: puzzle_hash, amount: amount)
    }
    
    override var description: String {
        return "Coin_id: \(coin_id), amount: \(amount), parent: \(parent_coin_id), spent: \(spent)"
    }

}

func calculate_coin_id(parent_id: String, puzzle_hash: String, amount: Int) -> String {
    let int_bytes = int_to_bytes_swift(value: amount)
    let coin_id = sha256(data: parent_id.hex!+puzzle_hash.hex!+int_bytes).hex
    return coin_id
}
