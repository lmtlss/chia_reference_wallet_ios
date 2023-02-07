import Foundation
import SwiftyJSON

class CoinSpend: Codable {
    let coin: Coin
    let puzzle_reveal: Program
    let solution: Program
    
    init(coin_record: Coin, puzzle_reveal: Program, solution: Program) {
        self.coin = coin_record
        self.puzzle_reveal = puzzle_reveal
        self.solution = solution
    }
    
    func to_json() -> JSON{
        var dict: [String: Any] = [:]
        var coin_dict: [String: Any] = ["parent_coin_info": coin.parent_coin_id.ox, "puzzle_hash": coin.puzzle_hash.ox, "amount": coin.amount]
        dict["coin"] = coin_dict
        dict["puzzle_reveal"] = puzzle_reveal.program_str.ox
        dict["solution"] = solution.program_str.ox
        let json = JSON(dict)
        return json
    }

    func additions() ->[Coin] {
        var coins: [Coin] = []
        let conditions = addition_conditions(puzzle: self.puzzle_reveal, solution: self.solution)
        for cond in conditions {
            let amount = cond["amount"] as! Int
            let puzzle_hash = cond["puzzle_hash"] as! String
            let coin = Coin(amount: amount, puzzle_hash: puzzle_hash, parent_coin_id: self.coin.coin_id)
            coins.append(coin)
        }
        return coins
    }
}
