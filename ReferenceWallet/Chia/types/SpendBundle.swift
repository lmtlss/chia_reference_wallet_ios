import Foundation
import SwiftyJSON

class SpendBundle: Codable {
    let coin_spends: [CoinSpend]
    let aggregated_signature: Data?
    
    init(coin_spends: [CoinSpend], aggregated_signature: Data?) {
        self.coin_spends = coin_spends
        self.aggregated_signature = aggregated_signature
    }

    func to_json() -> JSON {
        var dict: [String: Any] = [:]
        var coin_spends_list: [JSON] = []
        for cs in self.coin_spends {
            coin_spends_list.append(cs.to_json())
        }
        dict["coin_spends"] = coin_spends_list
        dict["aggregated_signature"] = self.aggregated_signature!.hex.ox
        let json = JSON(dict)
        return json
    }
    
    func id() -> String {
        var merged = ""
        for cs in coin_spends {
            merged += cs.coin.coin_id
        }
        let hash = sha256(data: merged.hex!)
        return hash.hex
    }
    
    func removals() -> [Coin] {
        var coins: [Coin] = []
        for cs in coin_spends {
            coins.append(cs.coin)
        }
        return coins
    }

    func additions() ->[Coin] {
        var coins: [Coin] = []
        
        for cs in coin_spends {
            let conditions = addition_conditions(puzzle: cs.puzzle_reveal, solution: cs.solution)
            for cond in conditions {
                let amount = cond["amount"] as! Int
                let puzzle_hash = cond["puzzle_hash"] as! String
                let coin = Coin(amount: amount, puzzle_hash: puzzle_hash, parent_coin_id: cs.coin.coin_id)
                coins.append(coin)
            }
        }
        return coins
    }
    
    static func aggregate(_ spend_bundles: [SpendBundle]) -> SpendBundle {
        var agg_sig: Signature? = nil
        var coin_spends: [CoinSpend] = []

        for sb in spend_bundles {
            coin_spends.append(contentsOf: sb.coin_spends)
            guard let current_agg = sb.aggregated_signature else {continue}
            if agg_sig == nil {
                agg_sig = Signature(hexstr: current_agg.hex)
            } else {
                agg_sig = agg_sig?.aggregate(signature: Signature(hexstr: current_agg.hex))
            }
        }
        return SpendBundle(coin_spends: coin_spends, aggregated_signature: agg_sig!.data())
    }
}
