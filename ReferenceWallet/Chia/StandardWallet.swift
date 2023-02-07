import Foundation
import SwiftyJSON

class AmountWithPuzzlehash {
    let amount: Int
    let puzzle_hash: Data
    let memos: [Data]

    init(amount: Int, puzzle_hash: Data, memos: [Data]) {
        self.amount = amount
        self.puzzle_hash = puzzle_hash
        self.memos = memos
    }
}

class StandardWallet {
    let wallet: Wallet
    static let asset_id = "XCH"

    let standard_puzzle = "ff02ffff01ff02ffff03ff0bffff01ff02ffff03ffff09ff05ffff1dff0bffff1effff0bff0bffff02ff06ffff04ff02ffff04ff17ff8080808080808080ffff01ff02ff17ff2f80ffff01ff088080ff0180ffff01ff04ffff04ff04ffff04ff05ffff04ffff02ff06ffff04ff02ffff04ff17ff80808080ff80808080ffff02ff17ff2f808080ff0180ffff04ffff01ff32ff02ffff03ffff07ff0580ffff01ff0bffff0102ffff02ff06ffff04ff02ffff04ff09ff80808080ffff02ff06ffff04ff02ffff04ff0dff8080808080ffff01ff0bffff0101ff058080ff0180ff018080"

    init(wallet: Wallet) {
        self.wallet = wallet
    }

    func puzzle_hash_for_pk(public_key: String) -> String {
        let puzzle = puzzle_for_pk(public_key: public_key)
        let puzzle_hash = puzzle.tree_hash()
        return puzzle_hash
    }

    func puzzle_for_pk(public_key: String) -> Program {
        let synthetic: String = PrivateKey.calculate_synthetic_public_key(public_key: public_key)
        self.wallet.pk_cache[synthetic] = public_key
        let pk_program = Program(hexstr: synthetic.ox)
        let standard_program = Program(hexstr: standard_puzzle)
        let curried = standard_program.curry(program: pk_program)
        
        let new_c = standard_program.curry(args: ["\(pk_program.program_str.ox)"])
        return curried
    }

    static func make_solution(primaries: [AmountWithPuzzlehash],
                              fee: Int,
                              coin_announcements: [Announcement] = [],
                              coin_announcements_to_assert: [Announcement] = [],
                              puzzle_announcements_to_assert: [Announcement] = [],
                              puzzle_announcements: [Announcement] = []
    ) -> Program {
        var replacement = "(() (q"
        for amp in primaries {
            let amount = int_to_bytes_swift(value: amp.amount).hex
            if amp.memos.count == 0 {
                replacement = "\(replacement) (51 \(amp.puzzle_hash.hex) \(amount) (\(amp.puzzle_hash.hex)))"
            } else {
                replacement = "\(replacement) (51 \(amp.puzzle_hash.hex) \(amount) (\(amp.memos[0].hex)))"
            }
        }

        for ann in coin_announcements {
            replacement = "\(replacement) (60 \(ann.message.hex))"
        }

        for ann in coin_announcements_to_assert {
            replacement = "\(replacement) (61 \(ann.name().hex))"
        }

        for puzz in puzzle_announcements {
            replacement = "\(replacement) (62 \(puzz.message.hex))"
        }

        for puzz in puzzle_announcements_to_assert {
            replacement = "\(replacement) (63 \(puzz.name().hex))"
        }

        if fee > 0 {
            let fee_amount = int_to_bytes_swift(value: fee).hex
            replacement = "\(replacement) (52 \(fee_amount))"

        }

        replacement = "\(replacement)) ())"
        let program = Program(disassembled: replacement)
        return program
    }
    
    func get_coins(spendable: Bool) -> [Coin] {
        let unconfirmed = self.wallet.tx_store.get_unconfirmed_transactions(asset_id: StandardWallet.asset_id, wallet_type: WalletType.STANDARD, did_id: nil)
        let all_stored_coins = self.wallet.coin_store.get_all_coins(asset_id: StandardWallet.asset_id, wallet_type: WalletType.STANDARD, did_id: nil)

        var result: [Coin] = []
        for coin in all_stored_coins {
            var used = false
            for tx in unconfirmed {
                if tx.removed_coin_ids.contains(coin.coin_id.ox) {
                    used = true
                    break
                }
            }
            if coin.spent || used {
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
                    if let record = record, record.wallet_type == WalletType.STANDARD.rawValue {
                        result.append(add)
                    }
                }
            }
        }

        return result
    }
    
    func get_balance(spendable: Bool=false) -> Int {
        let coins = self.get_coins(spendable: spendable)
        var amount = 0
        for coin in coins {
            amount += coin.amount
        }

        return amount
    }
    
    func get_balance_string() -> String {
        let amount = self.get_balance()
        let xch = ChiaUnits.mojo_to_xch_string(mojos: amount)
        return xch
    }

    func get_puzzle_for_puzzle_hash(puzzle_hash: String) -> Program? {
        let drecord = self.wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: puzzle_hash)
        if let drecord = drecord {
            return puzzle_for_pk(public_key: drecord.public_key)
        } else {
            return nil
        }
    }

    func select_coins(amount: Int) -> ([Coin], Int) {
        let coins = self.get_coins(spendable: true)
        var selected_amount = 0
        var selected_coins: [Coin] = []
    
        for coin in coins {
            if !coin.spent {
                selected_coins.append(coin)
                selected_amount += coin.amount
                if selected_amount > amount {
                    break
                }
            }
        }

        return (selected_coins, selected_amount)
    }

    func sign(spend_bundle: SpendBundle) -> SpendBundle {
        var signatures: [Signature] = []
        for coin_spend in spend_bundle.coin_spends {
            let puzzle_reveal = coin_spend.puzzle_reveal
            let solution = coin_spend.solution

            let list_to_sign = conditions_dict_for_solution(puzzle: puzzle_reveal, solution: solution)

            for item in list_to_sign {
                let synth_pubkey = item["pubkey"]!
                let pk = self.wallet.get_pk_for_synthetic_pk(synth: synth_pubkey)

                let index = self.wallet.puzzle_store.get_derivation_index_for_pubkey(pubkey: pk!)
                let message = item["message"]!
                let privateKey = self.wallet.sk_for_index(index: index, hard: false)
                let secret_key: PrivateKey = PrivateKey.calculate_synthetic_secret_key(secret_key: privateKey)
                let coin_id = calculate_coin_id(parent_id: coin_spend.coin.parent_coin_id, puzzle_hash: coin_spend.coin.puzzle_hash, amount: coin_spend.coin.amount)
                let message_to_sign = message.hex! + coin_spend.coin.coin_id.hex! + ChiaNetwork.mainnet.hex!
                let signature = secret_key.sign(message: message_to_sign.hex)

                signatures.append(signature)
            }
        }

        var agg_sig: Signature? = nil
        for sig in signatures {
            if agg_sig == nil {
                agg_sig = sig
            } else {
                agg_sig = agg_sig?.aggregate(signature: sig)
            }
        }

        let sb = SpendBundle(coin_spends: spend_bundle.coin_spends, aggregated_signature: agg_sig?.data())
        return sb
    }

    func generate_signed_transaction(primaries:[AmountWithPuzzlehash],
                                     fee_amount: Int,
                                     coins: [Coin],
                                     origin_id: String? = nil,
                                     coin_announcements_to_consume: [Announcement] = [],
                                     puzzle_announcements_to_consume: [Announcement] = [],
                                     memos: [Data] = [],
                                     negative_change_allowed: Bool = false,
                                     min_coin_amount: Int? = nil,
                                     max_coin_amount: Int? = nil,
                                     exclude_coin_amounts: [Int] = [],
                                     exclude_coins: [Coin] = []
    ) -> TransactionRecord? {
        var coins_to_spend = coins
        let selected_amount = sum_coins(coins_to_spend)
        var added = false
        var signatures: [Signature] = []
        var coin_spends: [CoinSpend] = []
        if primaries.count == 0 {
            return nil
        }

        let to_ph = primaries[0].puzzle_hash.hex
        let xch_amount = primaries[0].amount

        for spend_coin in coins_to_spend {
            let puzzle_reveal = get_puzzle_for_puzzle_hash(puzzle_hash: spend_coin.puzzle_hash)!
            var solution = StandardWallet.make_solution(primaries: [], fee: 0)
            if !added {
                added = true
                solution = StandardWallet.make_solution(primaries: primaries, fee: fee_amount, coin_announcements_to_assert: coin_announcements_to_consume)
            }
            
            let coin_spend = CoinSpend(coin_record: spend_coin, puzzle_reveal: puzzle_reveal, solution: solution)
            coin_spends.append(coin_spend)
            let list_to_sign = conditions_dict_for_solution(puzzle: puzzle_reveal, solution: solution)
            guard let drecord = self.wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: spend_coin.puzzle_hash) else {
                return nil
            }
            
            for item in list_to_sign {
                let message = item["message"]!
                let privateKey = self.wallet.sk_for_index(index: drecord.index, hard: drecord.hardened)
                let pub = privateKey.get_g1_string()
                let secret_key: PrivateKey = PrivateKey.calculate_synthetic_secret_key(secret_key: privateKey)
                let coin_id = calculate_coin_id(parent_id: coin_spend.coin.parent_coin_id, puzzle_hash: coin_spend.coin.puzzle_hash, amount: coin_spend.coin.amount)
                let message_to_sign = message.hex! + coin_spend.coin.coin_id.hex! + ChiaNetwork.mainnet.hex!
                let signature = secret_key.sign(message: message_to_sign.hex)

                signatures.append(signature)
            }
        }
        
        var agg_sig: Signature? = nil
        for sig in signatures {
            if agg_sig == nil {
                agg_sig = sig
            } else {
                agg_sig = agg_sig?.aggregate(signature: sig)
            }
        }

        let sb = SpendBundle(coin_spends: coin_spends, aggregated_signature: agg_sig!.data())
        let timestamp = Int(NSDate().timeIntervalSince1970) + 60 * 60 * 24 * 100
        let additions = sb.additions()
        let transaction_record = TransactionRecord(tx_id: sb.id(), confirmed_height: 0, timestamp: timestamp, to_puzzle_hash: to_ph, amount: xch_amount, fee_amount: fee_amount, spend_bundle: sb, additions: additions, removals: sb.removals(), asset_id: StandardWallet.asset_id, type: TxType.Outgoing, wallet_type: WalletType.STANDARD, did_id: nil)
        return transaction_record
    }
    
    func send_xch(to: String, user_amount: Double, fee: Double) async -> (Bool, String?) {
        let xch_amount = Int(user_amount * 1000000000000)
        let fee_amount = Int(fee * 1000000000000)
        let total = xch_amount + fee_amount
        
        let spendable = self.get_balance(spendable: true)
        let total_balance = self.get_balance(spendable: false)

        if total > spendable {
            if total < total_balance {
                return (false, "Waiting for change from the previous transaction, please try again once it's confirmed")
            } else {
                return (false, "Can't send amount higher than current balance")
            }
        }
        
        let result = select_coins(amount: xch_amount+fee_amount)
        let coins_to_spend = result.0
        let selected_amount = result.1
        
        let first_coin: Coin = coins_to_spend[0]
        var primaries = [AmountWithPuzzlehash(amount: xch_amount, puzzle_hash: to.hex!, memos: [])]
        
        if xch_amount + fee_amount < selected_amount {
            let change = selected_amount - xch_amount - fee_amount
            let change_primary = AmountWithPuzzlehash(amount: change, puzzle_hash: first_coin.puzzle_hash.hex!, memos: [])
            primaries.append(change_primary)
        }

        guard let tx = self.generate_signed_transaction(primaries: primaries, fee_amount: fee_amount, coins: coins_to_spend) else {
            return (false, "Unable to generate tranaction")
        }
        
        self.wallet.tx_store.insert_transaction(tx_record: tx)
        return await WalletStateManager.shared.submit_spend_bundle(sb: tx.spend_bundle!)
    }

    func generate_fee_transaction(fee_amount: Int, coin_announcement: Announcement) -> (TransactionRecord?, String?) {
        let spendable = self.get_balance(spendable: true)
        let total_balance = self.get_balance(spendable: false)

        if fee_amount > spendable {
            if fee_amount < total_balance {
                return (nil, "Waiting for change from the previous transaction, please try again once it's confirmed")
            } else {
                return (nil, "Not enough XCH to cover the fee cost")
            }
        }

        let result = select_coins(amount: fee_amount)
        let coins_to_spend = result.0
        let selected_amount = result.1
        let first_coin: Coin = coins_to_spend[0]
        var primaries: [AmountWithPuzzlehash] = []

        if fee_amount < selected_amount {
            let change = selected_amount - fee_amount
            let change_primary = AmountWithPuzzlehash(amount: change, puzzle_hash: first_coin.puzzle_hash.hex!, memos: [])
            primaries.append(change_primary)
        }

        guard let tx = self.generate_signed_transaction(primaries: primaries, fee_amount: fee_amount, coins: coins_to_spend, coin_announcements_to_consume: [coin_announcement]) else {
            return (nil, "Unable to generate tranaction")
        }
        var tx_mod = tx
        tx_mod.to_puzzle_hash = "Fee"
        tx_mod.amount = fee_amount
        return (tx_mod, nil)

    }

    
}
