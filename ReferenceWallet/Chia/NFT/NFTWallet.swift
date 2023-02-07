import Foundation
import SwiftyJSON

class NFT {
    let coin: Coin
    let nft_info: JSON
    
    init(coin: Coin, info: JSON) {
        self.coin = coin
        self.nft_info = info
    }

    var p2: String {
        return nft_info["new_p2_puzhash"].stringValue.ox
    }

}

class NFTWallet {
    let wallet: Wallet
    static let asset_id = "XCH_NFT"

    init(wallet: Wallet) {
        self.wallet = wallet
    }

    func send_nft(nft:NFT, to: String, fee: Double) async -> (Bool, String?) {
        
        let fee_amount = Int(fee * 1000000000000)

        let unft = nft.nft_info
        let singleton_id = unft["singleton_id"].stringValue
        let metadata = unft["metadata1"].stringValue
        let updater_puzhash = unft["nft_info"]["updater_puzhash"].stringValue
        let new_p2_puzhash = unft["new_p2_puzhash"].stringValue.ox
        var did: DID? = nil
        var inner_puzzle: Program? = nil
        let puzzle_record = self.wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: new_p2_puzhash)

        if let puzzle_record = puzzle_record {
            if puzzle_record.did_id != nil {
                if let found_did = self.wallet.did_wallet!.get_did_with_id(did_id: puzzle_record.did_id!) {
                    inner_puzzle = self.wallet.did_wallet!.p2_puzzle_for_did(did: found_did)
                    did = found_did
                }
            } else {
                inner_puzzle = self.wallet.standard_wallet?.get_puzzle_for_puzzle_hash(puzzle_hash: new_p2_puzhash)
            }
        }
        
        
        let json = JSON(["singleton_id":singleton_id,
                         "metadata": metadata,
                         "metadata_updater_hash": updater_puzhash,
                         "inner_puzzle": inner_puzzle!.program_str,
                        "parent_coin_id": nft.coin.parent_coin_id])

        let result = await WalletServerAPI.shared.api_call(api_name: "get_nft_puzzle", json_object: json)
        if result.0 {
            let puzzle = result.1!["puzzle"].stringValue
            let puzzle_reveal = Program(hexstr: puzzle)
            if nft.coin.puzzle_hash.hex! == puzzle_reveal.tree_hash().hex! {
                print("correct puzzle received")
                var primaries = [AmountWithPuzzlehash(amount: nft.coin.amount, puzzle_hash: to.hex!, memos: [to.hex!])]
                let announcement = Announcement(origin_info: nft.coin.coin_id, message: nft.coin.coin_id.hex!, morph_bytes: nil)

                var innersol = StandardWallet.make_solution(primaries: primaries, fee: 0, coin_announcements: [announcement])
                var sol_for_magic = innersol.at(path: "rfr").disassemble_program()
                var did_solutions: [(Coin, Program)] = []
                
                var magic_confition = "(-10 () () ())"
                var sol2 = "((() (q \(magic_confition) . \(sol_for_magic)) ()))"
                if let did = did {
                    let p2 = DIDWallet.make_p2_solution(primaries: primaries, fee: 0)
                    print("p2: \(p2.disassemble_program())" )
                    print("p2 rest: \(p2.rest().disassemble_program())" )
                    let p2_rest = p2.rest().first().disassemble_program()
                    var fixed = Program(disassembled: "(q \(magic_confition) \(p2_rest))")
                    print("fixed: \(fixed.disassemble_program())")
                    did_solutions.append((nft.coin, fixed))
                    sol2 = self.wallet.did_wallet!.full_p2_solution(p2_solution: fixed, did: did, coin: nft.coin).disassemble_program()
                    sol2 = "(\(sol2))"
                    print("sol2: \(sol2)")
                }
    
                var nft_layer_solution = "(\(sol2))"
                let lineage = unft["lineage_proof"]
                let lp = LineageProof(parent_id:lineage["parent_name"].stringValue, inner_puzzle_hash:  lineage["inner_puzzle_hash"].stringValue, amount:  lineage["amount"].intValue)
                let singleton_solution = "(\(lp.to_program().disassemble_program()) \(nft.coin.amount) \(nft_layer_solution))"
                let solution = Program(disassembled: singleton_solution)
                let coin_spend = CoinSpend(coin_record: nft.coin, puzzle_reveal: puzzle_reveal, solution: solution)
                let result = puzzle_reveal.run(program: solution)

                let spend = SpendBundle(coin_spends: [coin_spend], aggregated_signature: nil)
                let list_to_sign = conditions_dict_for_solution(puzzle: puzzle_reveal, solution: solution)
                let signed = self.wallet.standard_wallet!.sign(spend_bundle: spend)

                let timestamp = Int(NSDate().timeIntervalSince1970) + 60 * 60 * 24 * 100
                var all = signed
                
                if let did = did {
                    let approval = self.wallet.did_wallet!.create_approval(did: did, spend_bundle: all, solutions: did_solutions)
                    all = SpendBundle.aggregate([all, approval])
                }
                
                if fee_amount > 0 {
                    if let did = did {
                        
                    } else {
                        let tx_result = self.wallet.standard_wallet!.generate_fee_transaction(fee_amount: fee_amount, coin_announcement: announcement)
                          if let fee_tx = tx_result.0 {
                              all = SpendBundle.aggregate([all, fee_tx.spend_bundle!])
                              self.wallet.tx_store.insert_transaction(tx_record: fee_tx)
                          } else {
                              return (false, tx_result.1)
                          }
                    }
                }
                
                return await WalletStateManager.shared.submit_spend_bundle(sb: all)
            }
        }
        return (false, "Failed to generate transaction")
    }

}
