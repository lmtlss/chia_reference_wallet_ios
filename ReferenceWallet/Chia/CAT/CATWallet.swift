import Foundation
import SwiftyJSON

class ChiaNetwork {
    static let mainnet = "ccd5bb71183532bff220ba46c268991a3ff07eb358e8255a65c30a2dce0e5fbb"
    static let testnet10 = "ae83525ba8d1dd3f09b277de18ca3e43fc0af20d20c4b3e92ef2a48bd291ccb2"
}

class LineageProof: Codable {
    let parent_id: String
    let inner_puzzle_hash: String
    let amount: Int

    init(parent_id: String, inner_puzzle_hash: String, amount: Int) {
        self.parent_id = parent_id
        self.inner_puzzle_hash = inner_puzzle_hash
        self.amount = amount
    }
    
    func to_program() -> Program {
        var program = "(\(parent_id) \(inner_puzzle_hash) \(amount))"
        return Program(disassembled: program)
    }

}

class Announcement {
    let origin_info: String
    let message: Data
    let morph_bytes: Data?

    init(origin_info: String, message: Data, morph_bytes: Data?) {
        self.origin_info = origin_info
        self.message = message
        self.morph_bytes = morph_bytes
    }
    
    func name() -> Data {
        if let morph_bytes = self.morph_bytes {
            let message = sha256(data: morph_bytes + self.message)
            let result = sha256(data: self.origin_info.hex! + message)
            return result
        } else {
            let message = self.message
            let result = sha256(data: self.origin_info.hex! + message)
            return result
        }
    }
}

class CATSpend {
    let coin: Coin
    let tail: String
    let inner_puzzle: Program
    let inner_solution: Program
    let limitations_solution: Program
    let lineage_proof: LineageProof
    let limitation_program_reveal: Program
    
    init(coin: Coin, tail: String, inner_puzzle: Program, inner_solution: Program, limitations_solution: Program, lineage_proof: LineageProof, limitations_program_reveal: Program) {
        self.coin = coin
        self.inner_puzzle = inner_puzzle
        self.tail = tail
        self.inner_solution = inner_solution
        self.limitations_solution = limitations_solution
        self.lineage_proof = lineage_proof
        self.limitation_program_reveal = limitations_program_reveal
    }
}

class CATWallet {
    let wallet: Wallet
    var proofs: [String: LineageProof] = [:]
    var tasks: [String: String] = [:]
    let proof_store: ProofStore

    static let cat_2_puzzle = Program(hexstr: "ff02ffff01ff02ff5effff04ff02ffff04ffff04ff05ffff04ffff0bff34ff0580ffff04ff0bff80808080ffff04ffff02ff17ff2f80ffff04ff5fffff04ffff02ff2effff04ff02ffff04ff17ff80808080ffff04ffff02ff2affff04ff02ffff04ff82027fffff04ff82057fffff04ff820b7fff808080808080ffff04ff81bfffff04ff82017fffff04ff8202ffffff04ff8205ffffff04ff820bffff80808080808080808080808080ffff04ffff01ffffffff3d46ff02ff333cffff0401ff01ff81cb02ffffff20ff02ffff03ff05ffff01ff02ff32ffff04ff02ffff04ff0dffff04ffff0bff7cffff0bff34ff2480ffff0bff7cffff0bff7cffff0bff34ff2c80ff0980ffff0bff7cff0bffff0bff34ff8080808080ff8080808080ffff010b80ff0180ffff02ffff03ffff22ffff09ffff0dff0580ff2280ffff09ffff0dff0b80ff2280ffff15ff17ffff0181ff8080ffff01ff0bff05ff0bff1780ffff01ff088080ff0180ffff02ffff03ff0bffff01ff02ffff03ffff09ffff02ff2effff04ff02ffff04ff13ff80808080ff820b9f80ffff01ff02ff56ffff04ff02ffff04ffff02ff13ffff04ff5fffff04ff17ffff04ff2fffff04ff81bfffff04ff82017fffff04ff1bff8080808080808080ffff04ff82017fff8080808080ffff01ff088080ff0180ffff01ff02ffff03ff17ffff01ff02ffff03ffff20ff81bf80ffff0182017fffff01ff088080ff0180ffff01ff088080ff018080ff0180ff04ffff04ff05ff2780ffff04ffff10ff0bff5780ff778080ffffff02ffff03ff05ffff01ff02ffff03ffff09ffff02ffff03ffff09ff11ff5880ffff0159ff8080ff0180ffff01818f80ffff01ff02ff26ffff04ff02ffff04ff0dffff04ff0bffff04ffff04ff81b9ff82017980ff808080808080ffff01ff02ff7affff04ff02ffff04ffff02ffff03ffff09ff11ff5880ffff01ff04ff58ffff04ffff02ff76ffff04ff02ffff04ff13ffff04ff29ffff04ffff0bff34ff5b80ffff04ff2bff80808080808080ff398080ffff01ff02ffff03ffff09ff11ff7880ffff01ff02ffff03ffff20ffff02ffff03ffff09ffff0121ffff0dff298080ffff01ff02ffff03ffff09ffff0cff29ff80ff3480ff5c80ffff01ff0101ff8080ff0180ff8080ff018080ffff0109ffff01ff088080ff0180ffff010980ff018080ff0180ffff04ffff02ffff03ffff09ff11ff5880ffff0159ff8080ff0180ffff04ffff02ff26ffff04ff02ffff04ff0dffff04ff0bffff04ff17ff808080808080ff80808080808080ff0180ffff01ff04ff80ffff04ff80ff17808080ff0180ffff02ffff03ff05ffff01ff04ff09ffff02ff56ffff04ff02ffff04ff0dffff04ff0bff808080808080ffff010b80ff0180ff0bff7cffff0bff34ff2880ffff0bff7cffff0bff7cffff0bff34ff2c80ff0580ffff0bff7cffff02ff32ffff04ff02ffff04ff07ffff04ffff0bff34ff3480ff8080808080ffff0bff34ff8080808080ffff02ffff03ffff07ff0580ffff01ff0bffff0102ffff02ff2effff04ff02ffff04ff09ff80808080ffff02ff2effff04ff02ffff04ff0dff8080808080ffff01ff0bffff0101ff058080ff0180ffff04ffff04ff30ffff04ff5fff808080ffff02ff7effff04ff02ffff04ffff04ffff04ff2fff0580ffff04ff5fff82017f8080ffff04ffff02ff26ffff04ff02ffff04ff0bffff04ff05ffff01ff808080808080ffff04ff17ffff04ff81bfffff04ff82017fffff04ffff02ff2affff04ff02ffff04ff8204ffffff04ffff02ff76ffff04ff02ffff04ff09ffff04ff820affffff04ffff0bff34ff2d80ffff04ff15ff80808080808080ffff04ff8216ffff808080808080ffff04ff8205ffffff04ff820bffff808080808080808080808080ff02ff5affff04ff02ffff04ff5fffff04ff3bffff04ffff02ffff03ff17ffff01ff09ff2dffff02ff2affff04ff02ffff04ff27ffff04ffff02ff76ffff04ff02ffff04ff29ffff04ff57ffff04ffff0bff34ff81b980ffff04ff59ff80808080808080ffff04ff81b7ff80808080808080ff8080ff0180ffff04ff17ffff04ff05ffff04ff8202ffffff04ffff04ffff04ff78ffff04ffff0eff5cffff02ff2effff04ff02ffff04ffff04ff2fffff04ff82017fff808080ff8080808080ff808080ffff04ffff04ff20ffff04ffff0bff81bfff5cffff02ff2effff04ff02ffff04ffff04ff15ffff04ffff10ff82017fffff11ff8202dfff2b80ff8202ff80ff808080ff8080808080ff808080ff138080ff80808080808080808080ff018080")

    static let mod_code_hash: String = cat_2_puzzle.tree_hash()

    init(wallet: Wallet) {
        self.wallet = wallet
        self.proof_store = ProofStore(pubkey: wallet.pubkey)
    }

    static func construct_cat_puzzle(
        inner_puzzle: Program, asset_id: String
    ) -> Program {
        """
        Given an inner puzzle hash and tail hash calculate a puzzle program for a specific cc.
        """
        let cat_mod = cat_2_puzzle.disassemble_program()
        let hexed = inner_puzzle.disassemble_program()
        let list = "(c (q . \(mod_code_hash.ox)) (c (q . \(asset_id.ox)) (c (q . \(hexed)) 1)))"
        let curried = "(a (q . \(cat_mod)) \(list))"
        let curried_program = Program(disassembled: curried)
        return curried_program
    }

    func puzzle_for_pk(public_key: String, asset_id: String) -> Program {
        let inner_puzzle: Program = self.wallet.standard_wallet!.puzzle_for_pk(public_key: public_key)
        let curried = CATWallet.construct_cat_puzzle(inner_puzzle: inner_puzzle, asset_id: asset_id)
        return curried
    }
    
    func puzzle_for_inner_puzzle(inner_puzzle: Program, asset_id: String) -> Program {
        let curried = CATWallet.construct_cat_puzzle(inner_puzzle: inner_puzzle, asset_id: asset_id)
        return curried
    }

    func puzzle_hash_for_pk(public_key: String, asset_id: String) -> String {
        let puzzle = puzzle_for_pk(public_key: public_key, asset_id: asset_id)
        let puzzle_hash = puzzle.tree_hash()
        return puzzle_hash
    }

    func get_coins(asset_id: String, spendable: Bool) -> [Coin] {
        let unconfirmed = self.wallet.tx_store.get_unconfirmed_transactions(asset_id: asset_id, wallet_type: WalletType.CAT, did_id: nil)
        let all_stored_coins = self.wallet.coin_store.get_all_coins(asset_id: asset_id, wallet_type: WalletType.CAT, did_id: nil)

        var result: [Coin] = []
        for coin in all_stored_coins {
            var used = false
            for tx in unconfirmed {
                if tx.removed_coin_ids.contains(coin.coin_id.ox) {
                    used = true
                    break
                }
            }
            let proof = self.proof_store.get_lineage_proof(coin_id: coin.coin_id)
            
            if proof == nil {
                Task.detached {
                    await self.fetch_lineage_proof(coin:coin)
                }
            }

            if coin.spent || used  || proof == nil{
                continue
            }

            result.append(coin)
        }

        // calcualte the change from unconfirmed txs
        if !spendable {
            for tx in unconfirmed {
                let removed = tx.removed_coin_ids
                let added = tx.additions
                for add in added {
                    if removed.contains(add.coin_id.ox) {
                        continue
                    }
                    let record = self.wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: add.puzzle_hash)
                    if let record = record, record.wallet_type == WalletType.CAT.rawValue {
                        result.append(add)
                    }
                }
            }
        }

        return result
    }

    func get_balance(asset_id: String, spendable: Bool) -> Int {
        let all_stored_coins = self.get_coins(asset_id: asset_id, spendable: spendable)
        var amount = 0
        for coin in all_stored_coins {
            if !coin.spent {
                amount += coin.amount
            }
        }
        return amount
    }

    func get_balance_string(asset_id: String, spendable: Bool) -> String {
        let amount = self.get_balance(asset_id: asset_id, spendable: spendable)
        let xch = ChiaUnits.mojo_to_cat_string(mojos: amount)
        return xch
    }

    func select_coins(amount: Int, asset_id: String) -> [Coin]{
        let coins = self.get_coins(asset_id: asset_id, spendable: true)
        var selected: [Coin] = []
        var current_amount = 0
        for coin in coins {
            selected.append(coin)
            current_amount += coin.amount
            if current_amount >= amount {
                break
            }
        }
        return selected
    }

    static func next_info_for_spendable_cat(spend: CATSpend) -> String {
        let c = spend.coin
        let int_clvm = int_to_bytes_swift(value: c.amount)
        var res = "(\(c.parent_coin_id.ox) \(spend.inner_puzzle.tree_hash().ox) \(int_clvm.hex.ox))"
        return res
    }
    
    static func coin_as_list(coin: Coin) -> String {
        let int_clvm = int_to_bytes_swift(value: coin.amount)
        var res = "(\(coin.parent_coin_id.ox) \(coin.puzzle_hash.ox) \(int_clvm.hex.ox))"
        return res
    }

    static func spendbundle_from_cat_spends(spendable_cat_list: [CATSpend]) -> SpendBundle{
        var deltas: [Int] = []

        for spend_info in spendable_cat_list {
            let conditions = addition_conditions(puzzle: spend_info.inner_puzzle, solution: spend_info.inner_solution)
            var total = 0
            for cond in conditions {
                total += cond["amount"] as! Int
            }
            deltas.append(spend_info.coin.amount - total)
        }
        var delta_sum = 0
        for i in deltas {
            delta_sum += i
        }
        let subtotals = subtotals_for_deltas(deltas: deltas)
        var infos_for_next: [String] = []
        var infos_for_me: [String] = []
        var ids: [String] = []
        
        for spend_info in spendable_cat_list {
            infos_for_next.append(next_info_for_spendable_cat(spend: spend_info))
            infos_for_me.append(coin_as_list(coin: spend_info.coin))
            ids.append(spend_info.coin.coin_id.ox)
        }
        let N = spendable_cat_list.count
        var coin_spends: [CoinSpend] = []
        for index in 0..<N {
            let spend_info = spendable_cat_list[index]
            
            let puzzle_reveal = construct_cat_puzzle(inner_puzzle: spend_info.inner_puzzle, asset_id: spend_info.tail)
            var prev_index = (index - 1) % N
            let next_index = (index + 1) % N
            if prev_index < 0 {
                prev_index = N - 1
            }

            let prev_id = ids[prev_index]
            let my_info = infos_for_me[index]
            let next_info = infos_for_next[next_index]
            
            var solution = "("
            solution = "\(solution) \(spend_info.inner_solution.disassemble_program())"
            solution = "\(solution) \(spend_info.lineage_proof.to_program().disassemble_program())"
            solution = "\(solution) \(prev_id)"
            solution = "\(solution) \(my_info)"
            solution = "\(solution) \(next_info)"
            solution = "\(solution) \(subtotals[index])"
            solution = "\(solution) () ())"

            let solution_program = Program(disassembled: solution)
            let cs = CoinSpend(coin_record: spend_info.coin, puzzle_reveal: puzzle_reveal, solution: solution_program)
            coin_spends.append(cs)
        }

        return SpendBundle(coin_spends: coin_spends, aggregated_signature: nil)
    }
    
    static func subtotals_for_deltas(deltas: [Int]) -> [Int]{
        var subtotals: [Int] = []
        var subtotal = 0
        var subtotal_offset = 0
        for delta in deltas {
            subtotals.append(subtotal)
            subtotal += delta
        }
        // tweak the subtotals so the smallest value is 0
        for sub in subtotals {
            if sub < subtotal_offset {
                 subtotal_offset = sub
            }
        }
        var tweaked: [Int] = []
        for sub in subtotals {
            tweaked.append(sub - subtotal_offset)
        }
        return tweaked
    }
       
    func send_cat(asset_id: String, user_amount: Double, fee: Double, to_puzzle_hash: String) async -> (Bool, String?) {
        let xch_amount = Int(user_amount * 1000)
        let fee_amount = Int(fee * 1000000000000)
        
        let total_balance = self.get_balance(asset_id: asset_id, spendable: false)
        let spendable_balance = self.get_balance(asset_id: asset_id, spendable: true)

        if xch_amount > spendable_balance {
            if xch_amount < total_balance {
                return (false, "Waiting for change from the previous transaction, please try again once it's confirmed")
            } else {
                return (false, "Can't send amount higher than current balance")
            }
        }

        var coins = select_coins(amount: xch_amount, asset_id: asset_id)
        var selected_cat_amount = 0
        for coin in coins {
            selected_cat_amount += coin.amount
        }
        let change = selected_cat_amount - xch_amount
        var primaries: [AmountWithPuzzlehash] = [AmountWithPuzzlehash(amount: xch_amount, puzzle_hash: to_puzzle_hash.hex!, memos: [])]

        if change > 0 {
            let change_address = self.wallet.get_puzzle_hash()
            let change_primary = AmountWithPuzzlehash(amount: change, puzzle_hash: change_address.hex!, memos: [])
            primaries.append(change_primary)
        }
        let limitations_program_reveal = Program(hexstr: "0x")
        var first = true
        var spendable_cat_list: [CATSpend] = []
        var message = Data()
        for coin in coins {
            message += coin.coin_id.hex!
        }
        message = sha256(data: message)
        var announcement: Announcement? = nil
        for coin in coins {
            var innersol: Program? = nil
            if first {
                first = false
                announcement = Announcement(origin_info: coin.coin_id, message: message, morph_bytes: nil)
                innersol = StandardWallet.make_solution(primaries: primaries, fee: 0, coin_announcements: [announcement!])
            } else {
                innersol = StandardWallet.make_solution(primaries: [], fee: 0, coin_announcements_to_assert: [announcement!])
            }
            guard let lineage_proof = self.proof_store.get_lineage_proof(coin_id: coin.coin_id) else {
                return  (false, "Failed to create a transaction")
            }
            
            let inner_puzzle: Program = inner_puzzle_for_cat_puzzle_hash(puzzle_hash: coin.puzzle_hash, asset_id: asset_id)
            let limitations_solution = Program(hexstr: "0x80")
            let limitations_program_reveal = Program(hexstr: "0x80")

            let spend = CATSpend(coin: coin, tail: asset_id, inner_puzzle: inner_puzzle, inner_solution: innersol!, limitations_solution: limitations_solution, lineage_proof: lineage_proof, limitations_program_reveal: limitations_program_reveal)
            spendable_cat_list.append(spend)
        }
        var sb: SpendBundle = CATWallet.spendbundle_from_cat_spends(spendable_cat_list: spendable_cat_list)
        let spend_bundle = self.wallet.standard_wallet!.sign(spend_bundle: sb)
        
        let timestamp = Int(NSDate().timeIntervalSince1970) + 60 * 60 * 24 * 100

        let additions = spend_bundle.additions()
        let transaction_record = TransactionRecord(tx_id: spend_bundle.id(), confirmed_height: 0, timestamp: timestamp, to_puzzle_hash: to_puzzle_hash, amount: xch_amount, fee_amount: fee_amount, spend_bundle: spend_bundle, additions: additions, removals: spend_bundle.removals(), asset_id: asset_id, type: TxType.Outgoing, wallet_type: WalletType.CAT, did_id: nil)
        
        var full_spend_bundle: SpendBundle = transaction_record.spend_bundle!
        
        if fee_amount > 0 {
          let tx_result = self.wallet.standard_wallet!.generate_fee_transaction(fee_amount: fee_amount, coin_announcement: announcement!)
            if let fee_tx = tx_result.0 {
                full_spend_bundle = SpendBundle.aggregate([full_spend_bundle, fee_tx.spend_bundle!])
                self.wallet.tx_store.insert_transaction(tx_record: fee_tx)
            } else {
                return (false, tx_result.1)
            }
        }

        self.wallet.tx_store.insert_transaction(tx_record: transaction_record)
        
        return await WalletStateManager.shared.submit_spend_bundle(sb: full_spend_bundle)
    }

    func inner_puzzle_for_cat_puzzle_hash(puzzle_hash: String, asset_id: String) -> Program {
        let drecord = self.wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: puzzle_hash)!
        return self.wallet.standard_wallet!.puzzle_for_pk(public_key: drecord.public_key)
    }

    func coin_added(coin: Coin) async {
        if coin.spent {
            return
        }

        let proof = self.proof_store.get_lineage_proof(coin_id: coin.coin_id)
        if proof == nil {
            await self.fetch_lineage_proof(coin: coin)
        }
    }

    func fetch_lineage_proof(coin: Coin) async -> LineageProof? {
        let parameters: Dictionary = [
            "coin_id": coin.parent_coin_id,
        ]
        let par_json = JSON(parameters)
        let result = await WalletServerAPI.shared.api_call(api_name: "get_lineage_proof", json_object: par_json)
        let success = result.0
        let response = result.1

        if success {
            if let response = result.1 {
                let proof = response["proof"]
                guard let parent_name = proof["parent_name"].string else {return nil}
                guard let amount = proof["amount"].int else {return nil}
                guard let inner_puzzle_hash = proof["inner_puzzle_hash"].string else {return nil}
                let lineage = LineageProof(parent_id: parent_name, inner_puzzle_hash: inner_puzzle_hash, amount: amount)
                self.proof_store.insert_lineage(coin_id: coin.coin_id, proof: lineage)
                return lineage
            }
        }
        return nil
    }

}
