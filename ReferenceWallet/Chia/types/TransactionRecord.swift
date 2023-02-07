import Foundation
import BigInt

class TransactionRecord: NSObject, Codable {
    let tx_id: String
    let confirmed_height: Int
    let timestamp: Int
    var to_puzzle_hash: String
    var amount: Int
    var fee_amount: Int
    let spend_bundle: SpendBundle?
    let additions: [Coin]
    let removals: [Coin]
    let asset_id: String
    let type: TxType
    let wallet_type: WalletType
    let did_id: String?

    init(tx_id: String, confirmed_height: Int, timestamp: Int, to_puzzle_hash: String, amount: Int, fee_amount: Int, spend_bundle: SpendBundle?, additions: [Coin], removals: [Coin], asset_id: String, type: TxType, wallet_type: WalletType, did_id: String?) {
        self.tx_id = tx_id
        self.confirmed_height = confirmed_height
        self.timestamp = timestamp
        self.to_puzzle_hash = to_puzzle_hash
        self.amount = amount
        self.fee_amount = fee_amount
        self.spend_bundle = spend_bundle
        self.additions = additions
        self.removals = removals
        self.asset_id = asset_id
        self.type = type
        self.wallet_type = wallet_type
        self.did_id = did_id
    }

    var removed_coin_ids: Set<String> {
        var result: Set<String> = Set()
        for removed in removals {
            result.insert(removed.coin_id.ox)
        }
        return result
    }

    var added_coin_ids: Set<String> {
        var result: Set<String> = Set()
        for added in additions {
            result.insert(added.coin_id.ox)
        }
        return result
    }

    var coin_ids: Set<String> {
        var result: Set<String> = Set()
        for removed in removals {
            result.insert(removed.coin_id.ox)
        }
        for added in additions {
            result.insert(added.coin_id.ox)
        }
        return result
    }
    
}
