import Foundation
import SwiftyJSON

class DID: Codable {
    let coin: Coin
    let did_info: JSON
    let recovery_list: [String]
    let parent_info: String
    let did_id: String
    let launcher_coin: Coin
    let num_of_backup_ids_needed: Int
    let metadata: String

    init(launcher_coin: Coin, coin: Coin, info: JSON, did_id: String, recovery_list: [String], num_of_backup_ids_needed: Int, metadata: String, parent_info: String) {
        self.coin = coin
        self.did_info = info
        self.did_id = did_id
        self.launcher_coin = launcher_coin
        self.recovery_list = recovery_list
        self.num_of_backup_ids_needed = num_of_backup_ids_needed
        self.metadata = metadata
        self.parent_info = parent_info
    }

    var p2_puzzle: Program? {
        if let p2 = self.did_info["p2_puzzle"].string {
            return Program(hexstr: p2.noox)
        } else {
            return nil
        }
    }
    
    var metadata_json: JSON {
        return DIDPuzzles.json_from_metadata(metadata: self.metadata)
    }
    
    var name: String {
        if let name = self.metadata_json["name"].string {
             return name
        } else {
            return self.did_id
        }
    }

    var kyc_sig: String? {
        if let sig = self.metadata_json["kyc_did_id_sig"].string {
             return sig
        } else {
            return nil
        }
    }

}

class DIDWallet {
    let wallet: Wallet
    static let asset_id = "XCH_DID"
    let tasks: SafeDict<String, String> = SafeDict()

    init(wallet: Wallet) {
        self.wallet = wallet
    }

    func create_new_did_wallet_from_coin_spend(did_coin: Coin, launch_coin: Coin, did_puzzle: Program, coin_spend: CoinSpend, did_args: JSON) {
        let did_id = launch_coin.coin_id.did
        print("New did with id: \(did_id)")
        let recovery_list: [String] = []
        let inner_solution: Program = coin_spend.solution.rest().rest().first()
        guard let num_verification = did_args["num_verification"].string else {return}
        guard let recovery_list_hash = did_args["recovery_list_hash"].string else {return}
        guard let metadata = did_args["metadata"].string else {return}
        
        print(metadata)
        var metadata_json: JSON = DIDPuzzles.json_from_metadata(metadata: metadata)
    
        let num = int_from_bytes(value: num_verification.ox) ?? 0
        let backup_hash = String(recovery_list_hash.dropFirst(2))
        if backup_hash.ox != Program(disassembled: "()").tree_hash().ox {
            let list_program = inner_solution.rest().rest().rest().rest().rest().disassemble_program()
            let items = list_program.split(separator: " ")
        }
        let did = DID(launcher_coin: launch_coin, coin: did_coin, info: did_args, did_id: did_id, recovery_list: recovery_list, num_of_backup_ids_needed: num, metadata: metadata, parent_info: "")
        self.wallet.did_store.insert_did_info(did: did)
        self.wallet.coin_store.insert_coin_record(coin_record: did_coin, asset_id: DIDWallet.asset_id, wallet_type: WalletType.DID.rawValue, did_id: did.did_id)
        self.wallet.new_did_added(did: did)
        let inner_puzzle = self.get_inner_puzzle_for_puzzle_hash(puzzle_hash: did.p2_puzzle!.tree_hash(), did: did)

        let future_proof = LineageProof(
            parent_id: did_coin.parent_coin_id,
            inner_puzzle_hash: inner_puzzle.tree_hash(),
            amount: did_coin.amount
        )
    
        self.wallet.did_proof_store.insert_lineage(coin_id: did_coin.coin_id, proof: future_proof)

        Task.init {
            await self.did_coin_added(did: did, coin: did_coin)
        }
    }
        
    func did_coin_added(did: DID, coin: Coin) async {
        let proof = self.wallet.did_proof_store.get_lineage_proof(coin_id: coin.parent_coin_id)
        if proof == nil {
            let coin_result = await WalletServerAPI.shared.get_coin(coin_id: coin.parent_coin_id)
            if let parent = coin_result.0 {
                    let cs_result = await WalletServerAPI.shared.get_coin_spend(coin_id: coin.parent_coin_id)
                    if let cs = cs_result.0 {
                        print(cs.puzzle_reveal.disassemble_program())
                        guard let inner_puzzle = DIDPuzzles.get_innerpuzzle_from_puzzle(puzzle: cs.puzzle_reveal) else {return}
                        let proof = LineageProof(parent_id: cs.coin.parent_coin_id, inner_puzzle_hash: inner_puzzle.tree_hash(), amount: cs.coin.amount)
                        self.wallet.did_proof_store.insert_lineage(coin_id: coin.parent_coin_id, proof: proof)
                    }
                    let error = cs_result.1
                }
        }
    }

    func cat_coin_added(coin: Coin) async {
        if coin.spent {
            return
        }

        let proof = self.wallet.did_proof_store.get_lineage_proof(coin_id: coin.coin_id)
        if proof == nil {
            let parameters: Dictionary = [
                "coin_id": coin.parent_coin_id,
            ]
            let par_json = JSON(parameters)
            let result = await WalletServerAPI.shared.api_call(api_name: "get_lineage_proof", json_object: par_json)
            let success = result.0
            let response = result.1
            if success {
                if let response = result.1 {
                    if let proof = response["proof"] as? JSON {
                        let parent_name = proof["parent_name"].stringValue
                        let amount = proof["amount"].intValue
                        let inner_puzzle_hash = proof["inner_puzzle_hash"].stringValue
                        let lineage = LineageProof(parent_id: parent_name, inner_puzzle_hash: inner_puzzle_hash, amount: amount)
                        self.wallet.did_proof_store.insert_lineage(coin_id: coin.coin_id, proof: lineage)

                        self.wallet.update_delegates()
                    }
                }
            }
            self.tasks[coin.parent_coin_id] = nil
        }
    }

    func get_did_coins(current: Bool=true) -> [Coin] {
        var filtered: [Coin] = []
        let did_coins = self.wallet.coin_store.get_all_coins(asset_id: DIDWallet.asset_id, wallet_type: WalletType.DID, did_id: nil)
        for coin in did_coins {
            if coin.spent && current {
                continue
            }
            filtered.append(coin)
        }
        return filtered
    }

    func get_did_with_id(did_id: String) -> DID? {
        let coins = self.get_did_coins(current: true)
        var result: DID? = nil
        for coin in coins {
            if let did = self.wallet.did_store.get_did_info_for(coin: coin) {
                if did.did_id == did_id {
                    result = did
                    break
                }
            }
        }
        return result
    }

    func get_dids(current: Bool=true) -> [DID] {
        let coins = self.get_did_coins(current: current)
        var dids: [DID] = []
        for coin in coins {
            if let did = self.wallet.did_store.get_did_info_for(coin: coin) {
                dids.append(did)
            }
        }
        return dids
    }

    func puzzle_for_pk(did: DID, pubkey: String) -> Program {
        let origin_coin_name = did.launcher_coin.coin_id
        let puzzle = self.wallet.standard_wallet!.puzzle_for_pk(public_key: pubkey)
        let recovery_hash = String(did.did_info["recovery_list_hash"].string!.dropFirst(2))

        let metadata_json = JSON([:])
        let metadata_program = DIDPuzzles.metadata_to_program(metadata: metadata_json.dictionaryValue)
        let inner_puz = DIDPuzzles.create_inner_puz(p2_puzzle: puzzle,
                                                    recovery_list: [],
                                                    num_of_backup_ids_needed: did.num_of_backup_ids_needed,
                                                    launcher_id: did.launcher_coin.coin_id,
                                                    metadata: metadata_program,
                                                    recovery_list_hash: recovery_hash)
        
        let full_puz = DIDPuzzles.create_fullpuz(inner_puz: inner_puz, launcher_id: did.launcher_coin.coin_id)
        return full_puz
    }

    func inner_puzzle_for_pk(did: DID, pubkey: String, metadata: String) -> Program {
        let puzzle = self.wallet.standard_wallet!.puzzle_for_pk(public_key: pubkey)
        let recovery_hash = String(did.did_info["recovery_list_hash"].string!.dropFirst(2))
        let metadata_program = Program(hexstr: metadata)
        let inner_puz = DIDPuzzles.create_inner_puz(p2_puzzle: puzzle,
                                                    recovery_list: [],
                                                    num_of_backup_ids_needed: did.num_of_backup_ids_needed,
                                                    launcher_id: did.launcher_coin.coin_id,
                                                    metadata: metadata_program,
                                                    recovery_list_hash: recovery_hash)
        return inner_puz
    }
    
    func p2_puzzle_hash_for_did(did: DID) -> String {
        return self.p2_puzzle_for_did(did: did).tree_hash()
    }
    
    func p2_puzzle_for_did(did: DID) -> Program {
        let did_puzzle = DIDPuzzles.create_p2_did(launcher_id: did.launcher_coin.coin_id)
        return did_puzzle
    }

    func inner_puzzle_hash_for_pk(did: DID, pubkey: String) -> String {
        let puzzle = self.wallet.standard_wallet!.puzzle_for_pk(public_key: pubkey)
        let recovery_hash = String(did.did_info["recovery_list_hash"].string!.dropFirst(2))

        let metadata_json = JSON([:])
        let metadata_program = DIDPuzzles.metadata_to_program(metadata: metadata_json.dictionaryValue)
        let inner_puz = DIDPuzzles.create_inner_puz(p2_puzzle: puzzle,
                                                    recovery_list: [],
                                                    num_of_backup_ids_needed: did.num_of_backup_ids_needed,
                                                    launcher_id: did.launcher_coin.coin_id,
                                                    metadata: metadata_program,
                                                    recovery_list_hash: recovery_hash)
        return inner_puz.tree_hash()
    }

    func puzzle_hash_for_pk(did: DID, pubkey: String) -> String {
        return puzzle_for_pk(did: did, pubkey: pubkey).tree_hash()
    }

    func get_new_did_innerpuz(_ origin_id: String, p2: Program) -> Program {
        return DIDPuzzles.create_inner_puz(p2_puzzle: p2,
                                           recovery_list: [],
                                           num_of_backup_ids_needed: 0,
                                           launcher_id: origin_id,
                                           metadata: Program(disassembled: "()"),
                                           recovery_list_hash: Program(disassembled: "()").tree_hash())
    }
        
    func generate_eve_spend(coin: Coin, full_puzzle: Program, inner_puz: Program, p2: Program, origin_coin: Coin) -> SpendBundle {
        
        let amp = AmountWithPuzzlehash(amount: coin.amount, puzzle_hash: inner_puz.tree_hash().hex!, memos: [p2.tree_hash().hex!])
        let p2_solution = StandardWallet.make_solution(primaries: [amp], fee: 0)

        let innersol = Program(disassembled: "(1 \(p2_solution.disassemble_program()))")
        
        let origin_amount =  origin_coin.amount
        let coin_amount = coin.amount
        
        let full_sol = Program(disassembled: "((\(origin_coin.parent_coin_id.ox) \(origin_amount)) \(coin_amount) \(innersol.disassemble_program()))")
        let cs = CoinSpend(coin_record: coin, puzzle_reveal: full_puzzle, solution: full_sol)
        let unsigned = SpendBundle(coin_spends: [cs], aggregated_signature: nil)
        let signed = self.wallet.standard_wallet!.sign(spend_bundle: unsigned)
        return signed
    }

    func get_balance_string(asset_id: String, did: DID) -> String {
        let amount = self.get_balance(asset_id: asset_id, did: did)
        if asset_id == StandardWallet.asset_id {
            let xch = ChiaUnits.mojo_to_xch_string(mojos: amount)
            return xch
        } else {
            let xch = ChiaUnits.mojo_to_cat_string(mojos: amount)
            return xch
        }
    }

    func get_balance(asset_id: String, did: DID) -> Int {
        let all_stored_coins = self.wallet.coin_store.get_all_coins(asset_id: asset_id, wallet_type: WalletType.DID, did_id: did.did_id)
        let unconfirmed = self.wallet.tx_store.get_unconfirmed_transactions(asset_id: asset_id, wallet_type: WalletType.DID, did_id: did.did_id)
        var amount = 0
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

            amount += coin.amount
        }

        let p2 = self.p2_puzzle_for_did(did: did)
        let p2ph = p2.tree_hash()
        var cat_puzzle: Program? = nil
        var cat = false
        if asset_id != StandardWallet.asset_id && asset_id != DIDWallet.asset_id {
            cat = true
            cat_puzzle = CATWallet.construct_cat_puzzle(inner_puzzle: p2, asset_id: asset_id)
        }

        for tx in unconfirmed {
            let removed = tx.removed_coin_ids
            let added = tx.additions
            for add in added {
                if removed.contains(add.coin_id.ox) {
                    continue
                }
                if cat {
                    if add.puzzle_hash.ox == cat_puzzle!.tree_hash().ox {
                        amount += add.amount
                    }
                } else {
                    if add.puzzle_hash.ox == p2ph.ox {
                        amount += add.amount
                    }
                }
            }

        }

        return amount
    }
    
    func can_did_send_tx() {
        
    }

    func get_address(did: DID, new: Bool=false) -> String {
        if let last = self.wallet.puzzle_store.get_ph_for_asset(asset_id: StandardWallet.asset_id, at_index: 1, wallet_type: WalletType.DID, did_id: did.did_id) {
            return last.xch_address
        }
        return ""
    }

    func select_coins(asset_id: String, amount: Int, did: DID) -> ([Coin], Int) {
        var coins = self.wallet.coin_store.get_all_coins(asset_id: asset_id, wallet_type: WalletType.DID, did_id: did.did_id)
        var selected_amount = 0
        var selected_coins: [Coin] = []

        for coin in coins {
            if !coin.spent {
                selected_coins.append(coin)
                selected_amount += coin.amount
                if selected_amount >= amount {
                    break
                }
            }
        }

        return (selected_coins, selected_amount)
    }

    func get_puzzle_for_puzzle_hash(puzzle_hash: String, did: DID) -> Program {
        let drecord = self.wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: puzzle_hash)!
        return self.puzzle_for_pk(did: did, pubkey: drecord.public_key)
    }

    func get_inner_puzzle_for_puzzle_hash(puzzle_hash: String, did: DID) -> Program {
        let drecord = self.wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: puzzle_hash)!
        let inner_puzzle = self.inner_puzzle_for_pk(did: did, pubkey: drecord.public_key, metadata: did.metadata)
        if inner_puzzle.tree_hash().ox != puzzle_hash.ox {
            let metadata = DIDPuzzles.metadata_to_program(metadata: JSON([:]).dictionaryValue).program_str
            let dids = self.get_dids(current: false)
            for rdid in dids {
                let inner_puzzle = self.inner_puzzle_for_pk(did: rdid, pubkey: drecord.public_key, metadata: rdid.metadata)
                if inner_puzzle.tree_hash().ox == puzzle_hash.ox {
                    return inner_puzzle
                }
            }
            return inner_puzzle
        } else {
            return inner_puzzle
        }
    }

    func create_message_spend(did: DID, coin_announcements: [Announcement], puzzle_announcements: [Announcement]) -> SpendBundle? {
        let p2 = did.p2_puzzle!
        let drecord = self.wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: p2.tree_hash())!
        // let json = JSON([:])
        let innerpuz: Program = inner_puzzle_for_pk(did: did, pubkey: drecord.public_key, metadata: did.metadata)
        let amp = AmountWithPuzzlehash(amount: did.coin.amount, puzzle_hash: innerpuz.tree_hash().hex!, memos: [p2.tree_hash().hex!])
        let p2_solution = StandardWallet.make_solution(primaries: [amp], fee: 0, coin_announcements: coin_announcements, puzzle_announcements: puzzle_announcements)
        let innersol = Program(disassembled: "(1 \(p2_solution.disassemble_program()))")

        let full_puzzle = DIDPuzzles.create_fullpuz(did_puzzle: innerpuz, launcher_id: did.launcher_coin.coin_id)
        guard let proof = self.wallet.did_proof_store.get_lineage_proof(coin_id: did.coin.parent_coin_id) else {return nil}
        
        let full_sol = Program(disassembled: "((\(proof.parent_id.ox) \(proof.inner_puzzle_hash.ox) \(proof.amount)) \(did.coin.amount) \(innersol.disassemble_program()))")
        
        let coin_spend = CoinSpend(coin_record: did.coin, puzzle_reveal: full_puzzle, solution: full_sol)
        let sb = SpendBundle(coin_spends: [coin_spend], aggregated_signature: nil)
        let signed = self.wallet.standard_wallet?.sign(spend_bundle: sb)
        let result = full_puzzle.run(program: full_sol)
        print(result)
        return signed
    }
    
    func create_update_metadata_spend(did: DID, coin_announcements: [Announcement], puzzle_announcements: [Announcement], metadata: JSON) -> SpendBundle? {
        let p2 = did.p2_puzzle!
        let drecord = self.wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: p2.tree_hash())!
        let metadata_string = DIDPuzzles.metadata_to_program(metadata: metadata.dictionaryValue).program_str
        let new_innerpuz: Program = inner_puzzle_for_pk(did: did, pubkey: drecord.public_key, metadata: metadata_string)
        let innerpuz: Program = inner_puzzle_for_pk(did: did, pubkey: drecord.public_key, metadata: did.metadata)
        let amp = AmountWithPuzzlehash(amount: did.coin.amount, puzzle_hash: new_innerpuz.tree_hash().hex!, memos: [p2.tree_hash().hex!])
        let p2_solution = StandardWallet.make_solution(primaries: [amp], fee: 0, coin_announcements: coin_announcements, puzzle_announcements: puzzle_announcements)
        let innersol = Program(disassembled: "(1 \(p2_solution.disassemble_program()))")

        let full_puzzle = DIDPuzzles.create_fullpuz(did_puzzle: innerpuz, launcher_id: did.launcher_coin.coin_id)
        guard let proof = self.wallet.did_proof_store.get_lineage_proof(coin_id: did.coin.parent_coin_id) else {return nil}
        let full_sol = Program(disassembled: "((\(proof.parent_id.ox) \(proof.inner_puzzle_hash.ox) \(proof.amount)) \(did.coin.amount) \(innersol.disassemble_program()))")
        let coin_spend = CoinSpend(coin_record: did.coin, puzzle_reveal: full_puzzle, solution: full_sol)
        
        let full_puzzle_new = DIDPuzzles.create_fullpuz(did_puzzle: new_innerpuz, launcher_id: did.launcher_coin.coin_id)
        guard let new_proof = self.wallet.did_proof_store.get_lineage_proof(coin_id: did.coin.coin_id) else {return nil}
        let full_sol_new = Program(disassembled: "((\(new_proof.parent_id.ox) \(new_proof.inner_puzzle_hash.ox) \(new_proof.amount)) \(did.coin.amount) \(innersol.disassemble_program()))")
        let new_coin = coin_spend.additions()[0]
        let coin_spend_new = CoinSpend(coin_record: new_coin, puzzle_reveal: full_puzzle_new, solution: full_sol_new)

        let sb = SpendBundle(coin_spends: [coin_spend, coin_spend_new], aggregated_signature: nil)
        let signed = self.wallet.standard_wallet?.sign(spend_bundle: sb)
        let result = full_puzzle.run(program: full_sol)
        print(result)
        return signed
    }

    func generate_signed_transaction(did: DID,
                                     primaries:[AmountWithPuzzlehash],
                                     fee_amount: Int,
                                     coins: [Coin],
                                     origin_id: String? = nil,
                                     memos: [Data] = []
    ) -> TransactionRecord? {
        let selected_amount = sum_coins(coins)
        if primaries.count == 0 {
            return nil
        }
        let to_ph = primaries[0].puzzle_hash.hex
        let xch_amount = primaries[0].amount
        var added = false
        var coin_spends: [CoinSpend] = []
        var solutions: [(Coin, Program)] = []
        var announcement: Announcement? = nil
    
        for spend_coin in coins {
            let puzzle_reveal = p2_puzzle_for_did(did: did)
            var p2: Program? = nil
            if !added {
                added = true
                announcement = Announcement(origin_info: spend_coin.coin_id, message: spend_coin.coin_id.hex!, morph_bytes: nil)
                p2 = DIDWallet.make_p2_solution(primaries: primaries, fee: fee_amount, coin_announcements: [announcement!])
            } else {
                p2 = DIDWallet.make_p2_solution(primaries: [], fee: 0, coin_announcements_to_assert: [announcement!])
            }
        
            solutions.append((spend_coin, p2!))
            let drecord = self.wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: did.p2_puzzle!.tree_hash())!
            let inner_did_puzzle = self.inner_puzzle_for_pk(did: did, pubkey: drecord.public_key, metadata: did.metadata)
            let inner_did_puzzle_hash = inner_did_puzzle.tree_hash()
            
            let solution = Program(disassembled: "(\(inner_did_puzzle_hash.ox) \(spend_coin.coin_id.ox) \(p2!.disassemble_program()))")
            let coin_spend = CoinSpend(coin_record: spend_coin, puzzle_reveal: puzzle_reveal, solution: solution)
            print("solution \(solution.disassemble_program())")
            let result = puzzle_reveal.run(program: solution)
            print("result: \(result)")
            coin_spends.append(coin_spend)
        }
        
        let main = SpendBundle(coin_spends: coin_spends, aggregated_signature: nil)
        let main_signed = self.wallet.standard_wallet?.sign(spend_bundle: main)
        let approval = self.create_approval(did: did, spend_bundle: main_signed!, solutions: solutions)


        let all = SpendBundle.aggregate([main_signed!, approval])
        let timestamp = Int(NSDate().timeIntervalSince1970) + 99999999999

        let tx = TransactionRecord(tx_id: all.id(), confirmed_height: 0, timestamp: timestamp, to_puzzle_hash: to_ph, amount: xch_amount, fee_amount: fee_amount, spend_bundle: all, additions: all.additions(), removals: all.removals(), asset_id: StandardWallet.asset_id, type: TxType.Outgoing, wallet_type: WalletType.DID, did_id: did.did_id)
        return tx
    }

    static func make_p2_solution(primaries: [AmountWithPuzzlehash],
                              fee: Int,
                              coin_announcements: [Announcement] = [],
                              coin_announcements_to_assert: [Announcement] = [],
                              puzzle_announcements_to_assert: [Announcement] = [],
                              puzzle_announcements: [Announcement] = []
    ) -> Program {
        var p2 = StandardWallet.make_solution(primaries: primaries,
                                              fee: fee,
                                              coin_announcements: coin_announcements,
                                              coin_announcements_to_assert: coin_announcements_to_assert,
                                              puzzle_announcements_to_assert: puzzle_announcements_to_assert,
                                              puzzle_announcements: puzzle_announcements
        )
        p2 = p2.rest().first()
        return p2
    }

    func update_metadata_spend(did: DID, metadata: JSON) -> TransactionRecord {
        let all = self.create_update_metadata_spend(did: did, coin_announcements: [], puzzle_announcements: [], metadata: metadata)!
        var final: Coin? = nil
        let added = all.additions()
        let removals = all.removals()
        for add in added {
            var spent = false
            for removed in removals {
                if add.coin_id.ox == removed.coin_id.ox {
                    spent = true
                    break
                }
            }
            if !spent {
                final = add
                break
            }
        }
        let metadata_string = DIDPuzzles.metadata_to_program(metadata: metadata.dictionaryValue).program_str
        print("final \(final?.coin_id) \(final?.parent_coin_id)")

        let future_did = DID(launcher_coin: did.launcher_coin, coin: final!, info: did.did_info, did_id: did.did_id, recovery_list: did.recovery_list, num_of_backup_ids_needed: did.num_of_backup_ids_needed, metadata: metadata_string, parent_info: "")

        let timestamp = Int(NSDate().timeIntervalSince1970) + 99999999999

        let tx = TransactionRecord(tx_id: all.id(), confirmed_height: 0, timestamp: timestamp, to_puzzle_hash: did.p2_puzzle!.tree_hash(), amount: 1, fee_amount: 0, spend_bundle: all, additions: all.additions(), removals: all.removals(), asset_id: StandardWallet.asset_id, type: TxType.Outgoing, wallet_type: WalletType.DID, did_id: did.did_id)
        return tx
    }
    
    func send_update_metadata_spend(did: DID, metadata: JSON) async {
        let tx = update_metadata_spend(did: did, metadata: metadata)
        self.wallet.tx_store.insert_transaction(tx_record: tx)

        let parameters: Dictionary = [
            "spend_bundle": tx.spend_bundle!.to_json(),
        ]
        let par_json = JSON(parameters)
        let result = await WalletServerAPI.shared.api_call(api_name: "submit_spend_bundle", json_object: par_json)
    }

    func send_cat(asset_id: String, user_amount: Double, fee: Double, to_puzzle_hash: String, did: DID) async -> (Bool, String?) {
        let cat_amount = Int(user_amount * 1000)
        let fee_amount = Int(fee * 1000)
        
        
        let result = select_coins(asset_id: asset_id, amount: cat_amount, did: did)
        let coins_to_spend = result.0
        let selected_amount = result.1

        let first_coin: Coin = coins_to_spend[0]
        var primaries = [AmountWithPuzzlehash(amount: cat_amount, puzzle_hash: to_puzzle_hash.hex!, memos: [to_puzzle_hash.hex!])]
        let change_address = self.p2_puzzle_hash_for_did(did: did)
        
        
        if cat_amount < selected_amount {
            let change = selected_amount - cat_amount
            let change_primary = AmountWithPuzzlehash(amount: change, puzzle_hash: change_address.hex!, memos: [change_address.hex!])
            primaries.append(change_primary)
        }
        let tx = self.generate_signed_cat_transaction(asset_id: asset_id, did: did, primaries: primaries, coins: coins_to_spend)
        guard let tx = tx else {
            return (false, nil)
        }

        self.wallet.tx_store.insert_transaction(tx_record: tx)
        
        let parameters: Dictionary = [
            "spend_bundle": tx.spend_bundle!.to_json(),
        ]
        let par_json = JSON(parameters)
        let submit_result = await WalletServerAPI.shared.api_call(api_name: "submit_spend_bundle", json_object: par_json)
        return (submit_result.0, nil)
    }

    func full_p2_solution(p2_solution: Program, did: DID, coin: Coin) -> Program {
        let drecord = self.wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: did.p2_puzzle!.tree_hash())!
        let inner_did_puzzle = self.inner_puzzle_for_pk(did: did, pubkey: drecord.public_key, metadata: did.metadata)
        let inner_did_puzzle_hash = inner_did_puzzle.tree_hash()
        let solution = Program(disassembled: "(\(inner_did_puzzle_hash.ox) \(coin.coin_id.ox) \(p2_solution.disassemble_program()))")
        return solution
    }

    func generate_signed_cat_transaction(asset_id: String, did: DID, primaries: [AmountWithPuzzlehash], coins: [Coin]) -> TransactionRecord? {
        var spendable_cat_list: [CATSpend] = []
        var first = true
        var announcement: Announcement? = nil
        var message = Data()
        for coin in coins {
            message += coin.coin_id.hex!
        }
        if primaries.count == 0 {
            return nil
        }
        let to_ph = primaries[0].puzzle_hash.hex
        let cat_amount = primaries[0].amount

        message = sha256(data: message)
        var inner_solutions: [(Coin, Program)] = []
    
        for coin in coins {
            var p2: Program? = nil
            if first {
                first = false
                announcement = Announcement(origin_info: coin.coin_id, message: message, morph_bytes: nil)
                p2 = DIDWallet.make_p2_solution(primaries: primaries, fee: 0, coin_announcements: [announcement!])
            } else {
                p2 = DIDWallet.make_p2_solution(primaries: [], fee: 0, coin_announcements_to_assert: [announcement!])
            }

            let drecord = self.wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: did.p2_puzzle!.tree_hash())!
            let inner_did_puzzle = self.inner_puzzle_for_pk(did: did, pubkey: drecord.public_key, metadata: did.metadata)
            let inner_did_puzzle_hash = inner_did_puzzle.tree_hash()
            
            let solution = Program(disassembled: "(\(inner_did_puzzle_hash.ox) \(coin.coin_id.ox) \(p2!.disassemble_program()))")
    
            inner_solutions.append((coin, p2!))

            let lineage_proof = self.wallet.did_proof_store.get_lineage_proof(coin_id: coin.coin_id)!
            let inner_puzzle: Program = self.p2_puzzle_for_did(did: did)
            let limitations_solution = Program(hexstr: "0x80")
            let limitations_program_reveal = Program(hexstr: "0x80")

            let spend = CATSpend(coin: coin, tail: asset_id, inner_puzzle: inner_puzzle, inner_solution: solution, limitations_solution: limitations_solution, lineage_proof: lineage_proof, limitations_program_reveal: limitations_program_reveal)
            spendable_cat_list.append(spend)
        }
        let sb: SpendBundle = CATWallet.spendbundle_from_cat_spends(spendable_cat_list: spendable_cat_list)
        let main_signed = self.wallet.standard_wallet!.sign(spend_bundle: sb)
        let approval = self.create_approval(did: did, spend_bundle: main_signed, solutions: inner_solutions)

        let all = SpendBundle.aggregate([main_signed, approval])
        let timestamp = Int(NSDate().timeIntervalSince1970) + 99999999999

        let tx = TransactionRecord(tx_id: all.id(), confirmed_height: 0, timestamp: timestamp, to_puzzle_hash: to_ph, amount: cat_amount, fee_amount: 0, spend_bundle: all, additions: all.additions(), removals: all.removals(), asset_id: asset_id, type: TxType.Outgoing, wallet_type: WalletType.DID, did_id: did.did_id)

        return tx
    }
    
    func create_approval(did: DID, spend_bundle: SpendBundle, solutions: [(Coin, Program)]) -> SpendBundle {
        var puzzle_announcements: [Announcement] = []
        for (coin, sol) in solutions {
            let message_str = "(\(sol.disassemble_program()) \(coin.coin_id.ox))"
            let message = Program(disassembled: message_str).tree_hash()
            let ann = Announcement(origin_info: did.coin.coin_id, message: message.hex!, morph_bytes: nil)
            puzzle_announcements.append(ann)
        }
        let approval = self.create_message_spend(did: did, coin_announcements: [], puzzle_announcements: puzzle_announcements)!
        return approval
    }
    
    func send_xch(asset_id: String, user_amount: Double, fee: Double, to_puzzle_hash: String, did: DID) async -> (Bool, String?){
        let xch_amount = Int(user_amount * 1000000000000)
        let fee_amount = Int(fee * 1000000000000)

        let result = select_coins(asset_id: asset_id, amount: xch_amount+fee_amount, did: did)

        let coins_to_spend = result.0
        let selected_amount = result.1
        
        let first_coin: Coin = coins_to_spend[0]
        var primaries = [AmountWithPuzzlehash(amount: xch_amount, puzzle_hash: to_puzzle_hash.hex!, memos: [])]
        
        if xch_amount + fee_amount < selected_amount {
            let change = selected_amount - xch_amount - fee_amount
            let change_primary = AmountWithPuzzlehash(amount: change, puzzle_hash: first_coin.puzzle_hash.hex!, memos: [])
            primaries.append(change_primary)
        }
        let tx = self.generate_signed_transaction(did: did, primaries: primaries, fee_amount: fee_amount, coins: coins_to_spend)
        self.wallet.tx_store.insert_transaction(tx_record: tx!)

        let parameters: Dictionary = [
            "spend_bundle": tx!.spend_bundle!.to_json(),
        ]
        let par_json = JSON(parameters)
        let submit_result = await WalletServerAPI.shared.api_call(api_name: "submit_spend_bundle", json_object: par_json)
        let call_success = submit_result.0
        let response = submit_result.1
        return (call_success, nil)
    }

    func send(asset_id: String, user_amount: Double, fee: Double, to_puzzle_hash: String, did: DID) async -> (Bool, String?) {
        if asset_id == StandardWallet.asset_id {
            return await self.send_xch(asset_id: asset_id, user_amount: user_amount, fee: fee, to_puzzle_hash: to_puzzle_hash, did: did)
        } else {
            return await self.send_cat(asset_id: asset_id, user_amount: user_amount, fee: fee, to_puzzle_hash: to_puzzle_hash, did: did)
        }
    }

    func generate_new_did(fee: Int) async -> (Bool, String?){
        let total_amount = 1 + fee
        let coins_result = self.wallet.standard_wallet!.select_coins(amount: total_amount)
        let coins = coins_result.0
        let coin_sum = coins_result.1
        
        
        let spendable = self.wallet.standard_wallet!.get_balance(spendable: true)
        let total_balance = self.wallet.standard_wallet!.get_balance(spendable: false)

        if total_amount > spendable {
            if total_amount < total_balance {
                return (false, "Waiting for change from the previous transaction, please try again once it's confirmed")
            } else {
                return (false, "Can't send amount higher than current balance")
            }
        }

        let origin = coins[0]
        let genesis_launcher_puzzle = DIDPuzzles.LAUNCHER_PUZZLE
        let launcher_coin = Coin(amount: 1, puzzle_hash: genesis_launcher_puzzle.tree_hash(), parent_coin_id: origin.coin_id)
        
        let pk = self.wallet.pk_for_index(index: 1, hard: false)
        let p2 = self.wallet.standard_wallet!.puzzle_for_pk(public_key: pk)
        
        let did_inner: Program = self.get_new_did_innerpuz(launcher_coin.coin_id, p2: p2)

        let did_inner_hash = did_inner.tree_hash()
        let did_full_puz = DIDPuzzles.create_fullpuz(inner_puz: did_inner, launcher_id: launcher_coin.coin_id)
        let did_puzzle_hash = did_full_puz.tree_hash()
        var announcement_set: [Announcement] = []
        let announcement_message = Program(disassembled:"(\(did_puzzle_hash.ox) 1 0x80)").tree_hash()
        announcement_set.append(Announcement(origin_info: launcher_coin.coin_id, message: announcement_message.hex!, morph_bytes: nil))
        let amp = AmountWithPuzzlehash(amount: 1, puzzle_hash: genesis_launcher_puzzle.tree_hash().hex!, memos: [p2.tree_hash().hex!])
        var primaries: [AmountWithPuzzlehash] = [amp]
        var change = 0
        if coin_sum > total_amount {
            change = coin_sum - total_amount
        }
        if change > 0 {
            let chg = AmountWithPuzzlehash(amount: change, puzzle_hash: p2.tree_hash().hex!, memos: [p2.tree_hash().hex!])
            primaries.append(chg)
        }

        let tx_record = self.wallet.standard_wallet!.generate_signed_transaction(primaries: primaries, fee_amount: fee, coins: coins, origin_id: origin.coin_id, coin_announcements_to_consume: announcement_set)
        guard let tx_record = tx_record else {return (false, "Failed to generate a transacion")}
        
        
        let genesis_launcher_solution = Program(disassembled:"(\(did_puzzle_hash.ox) 1 0x80)")
        
        let launcher_cs = CoinSpend(coin_record: launcher_coin, puzzle_reveal: genesis_launcher_puzzle, solution: genesis_launcher_solution)
        let launcher_sb = SpendBundle(coin_spends: [launcher_cs], aggregated_signature: nil)
        let eve_coin = Coin(amount: 1, puzzle_hash: did_puzzle_hash, parent_coin_id: launcher_coin.coin_id)
        
        let eve_spend = self.generate_eve_spend(coin: eve_coin, full_puzzle: did_full_puz, inner_puz: did_inner, p2: p2, origin_coin: launcher_coin)
        let agg = SpendBundle.aggregate([tx_record.spend_bundle!, eve_spend, launcher_sb])
        
        self.wallet.tx_store.insert_transaction(tx_record: tx_record)
        return await WalletStateManager.shared.submit_spend_bundle(sb: agg)
    }
}
