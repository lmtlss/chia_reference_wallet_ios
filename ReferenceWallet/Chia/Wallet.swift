import Foundation
import SwiftyJSON
import KeychainSwift

protocol WalletDelegate: Hashable {
    func new_coins()
    func sync_status(sync_status: WalletStatus)
}

class Asset: Codable {
    let asset_name: String
    let asset_code: String
    let asset_id: String
    let asset_image_url: String?
    let wallet_type: Int
    
    init(name: String, code: String, asset_id: String, asset_image_url: String?, wallet_type: Int) {
        self.asset_name = name
        self.asset_code = code
        self.asset_id = asset_id
        self.asset_image_url = asset_image_url
        self.wallet_type = wallet_type
    }
}

class Wallet {
    let private_key: PrivateKey
    var pubkey: String
    
    var puzzle_store: PuzzleStore
    var coin_store: CoinStore
    var standard_wallet: StandardWallet?
    var cat_wallet: CATWallet?
    var nft_wallet: NFTWallet?
    var did_wallet: DIDWallet?
    
    let did_store: DIDStore
    let nft_store: NFTStore
    let tx_store: TransactionStore
    let did_proof_store: DIDProofStore
    
    var initialized: Bool = false
    var delegates: [String: any WalletDelegate] = [:]
    
    let default_asset = Asset(name: "Chia", code: "XCH", asset_id: StandardWallet.asset_id, asset_image_url:  URL.localURLForXCAsset(name: "chiaIcon")!.absoluteString, wallet_type: WalletType.STANDARD.rawValue)
    var supportedAssets: [Asset] = []
    var keychain: KeychainSwift = KeychainSwift()
    
    var selected_asset: Asset
    var status: WalletStatus
    let metadata: KeyMetadata
    var pk_cache: SafeDict<String, String> = SafeDict()
    init(key: PrivateKey, extra_assets: [Asset], metadata: KeyMetadata) {
        self.private_key = key
        self.pubkey = key.get_g1_string()
        self.puzzle_store = PuzzleStore(pubkey: self.pubkey)
        self.coin_store = CoinStore(pubkey: self.pubkey)
        self.tx_store = TransactionStore(pubkey: self.pubkey)
        self.nft_store = NFTStore(pubkey: self.pubkey)
        self.did_store = DIDStore(pubkey: self.pubkey)
        self.did_proof_store = DIDProofStore(pubkey: self.pubkey)
        
        self.status = WalletStatus.not_synced
        selected_asset = default_asset
        supportedAssets.append(default_asset)
        supportedAssets.append(contentsOf: CATCOSTANTS.default_cats)
        supportedAssets.append(contentsOf: extra_assets)
        self.metadata = metadata
    }
    
    func get_added_assets() -> [Asset] {
        return []
    }
    
    func set_status(status: WalletStatus) {
        self.status = status
        for delegate in delegates {
            DispatchQueue.main.async{
                delegate.value.sync_status(sync_status: status)
            }
        }
    }
    
    func add_asset(asset: Asset) {
        self.supportedAssets.append(asset)
        self.change_selected_asset(asset: asset)
        let max_total = self.puzzle_store.get_max_total()
        let new_phs = self.add_puzzles(from: 1, to: max_total, asset: asset)
        if new_phs.count > 0 {
            Task.init {
                WalletStateManager.shared.add_phs(phs: new_phs, wallet: self)
            }
        }
    }
    
    func update_delegates() {
        for delegate in delegates {
            DispatchQueue.main.async{
                delegate.value.new_coins()
            }
        }
    }
    
    func get_mnemonic() -> [String] {
        let mne_string = self.keychain.get(self.pubkey)!
        let mnemonics = mne_string.components(separatedBy: " ")
        return mnemonics
    }
    
    func get_pk_for_synthetic_pk(synth: String) -> String? {
        if let pk = self.pk_cache[synth] {
            return pk
        }
        let max_total = self.puzzle_store.get_max_total()
        
        for i in 0..<max_total {
            let public_key = self.pk_for_index(index: i, hard: false)
            let synthetic: String = PrivateKey.calculate_synthetic_public_key(public_key: public_key)
            self.pk_cache[synthetic.ox] = public_key.ox
            
            let public_key_hard = self.pk_for_index(index: i, hard: true)
            let synthetic_hard: String = PrivateKey.calculate_synthetic_public_key(public_key: public_key_hard)
            self.pk_cache[synthetic_hard.ox] = public_key_hard.ox
        }
        if let pk = self.pk_cache[synth] {
            return pk
        }
        
        return nil
    }
    func change_selected_asset(asset: Asset) {
        self.selected_asset = asset
        self.update_delegates()
    }
    
    func add_delegate(delegate: any WalletDelegate) {
        delegates["\(delegate.hashValue)"] = delegate
    }
    
    func initialize_addresses() {
        self.standard_wallet = StandardWallet(wallet: self)
        self.cat_wallet = CATWallet(wallet: self)
        self.nft_wallet = NFTWallet(wallet: self)
        self.did_wallet = DIDWallet(wallet: self)
        
        let max_used = self.puzzle_store.get_max_used()
        let max_total = self.puzzle_store.get_max_total()
        
        for i in 0..<max_total {
            let public_key = self.pk_for_index(index: i, hard: false)
            let synthetic: String = PrivateKey.calculate_synthetic_public_key(public_key: public_key)
            self.pk_cache[synthetic.ox] = public_key.ox
            
            let public_key_hard = self.pk_for_index(index: i, hard: true)
            let synthetic_hard: String = PrivateKey.calculate_synthetic_public_key(public_key: public_key_hard)
            self.pk_cache[synthetic_hard.ox] = public_key_hard.ox
        }
        
        let count = 100
        if max_used  > max_total - count {
            let diff = count - (max_total - max_used)
            let new_phs = self.add_puzzles(from: 0, to: max_total+diff)
            print("add more: \(diff)")
        }
        self.initialized = true
        self.update_delegates()
    }
    
    func add_puzzles(from: Int, to: Int, asset: Asset?=nil) -> [PuzzleRecord] {
        var phs: [PuzzleRecord] = []
        for i in from..<to {
            var ast = supportedAssets
            if let set = asset {
                ast = [set]
            }
            
            for supported_asset in supportedAssets {
                if supported_asset.wallet_type == WalletType.STANDARD.rawValue {
                    let ph = self.add_puzzle_for_standard_wallet(i: i)
                    phs.append(contentsOf: ph)
                } else if (supported_asset.wallet_type == WalletType.CAT.rawValue) {
                    let ph = self.add_puzzle_for_cat_wallet(i: i, asset_id: supported_asset.asset_id)
                    phs.append(ph)
                }
            }
        }
        let dids = self.did_wallet!.get_dids()
        for did in dids {
            let did_puzzles = self.add_puzzles_for_did(from: from, to: to, did: did)
            phs.append(contentsOf: did_puzzles)
        }
        return phs
    }
    
    func add_puzzles_for_did(from: Int, to: Int, did: DID) -> [PuzzleRecord] {
        var phs: [PuzzleRecord] = []
        // p2 puzzle
        let p2_puzzle = self.did_wallet!.p2_puzzle_for_did(did: did)
        let puzzle_hash = p2_puzzle.tree_hash()
        
        let record = PuzzleRecord(index: 1, puzzle_hash: puzzle_hash, public_key: did.did_id, wallet_type: WalletType.DID.rawValue, asset_id: StandardWallet.asset_id, used: false, synced_height: 0, hardened: false, did_id: did.did_id)
        self.puzzle_store.insert_puzzle_hash(index: 1, puzzle_hash: puzzle_hash, wallet_type: WalletType.DID.rawValue, asset_id: StandardWallet.asset_id, public_key: did.did_id, hardened: false, did_id: did.did_id)
        phs.append(record)
        for i in from..<to {
            let sk = PrivateKey.master_sk_to_wallet_sk_unhardened(master: self.private_key, index: i)
            let pk = sk.get_g1_string()
            let puzzle_hash = self.did_wallet!.inner_puzzle_hash_for_pk(did: did, pubkey: pk)
            let did_record = PuzzleRecord(index: i, puzzle_hash: puzzle_hash, public_key: pk, wallet_type: WalletType.DID.rawValue, asset_id: DIDWallet.asset_id, used: false, synced_height: 0, hardened: false, did_id: did.did_id)
            self.puzzle_store.insert_puzzle_hash(index: i, puzzle_hash: puzzle_hash, wallet_type: WalletType.DID.rawValue, asset_id: DIDWallet.asset_id, public_key: pk, hardened: false, did_id: did.did_id)
            phs.append(did_record)
        }
        
        for supported_asset in supportedAssets {
            if supported_asset.wallet_type == WalletType.STANDARD.rawValue {
                continue
            } else if (supported_asset.wallet_type == WalletType.CAT.rawValue) {
                let cat_p2 = self.cat_wallet!.puzzle_for_inner_puzzle(inner_puzzle: p2_puzzle, asset_id: supported_asset.asset_id)
                let cat_p2_ph = cat_p2.tree_hash()
                
                let did_record = PuzzleRecord(index: 1, puzzle_hash: cat_p2_ph, public_key: did.did_id, wallet_type: WalletType.DID.rawValue, asset_id: supported_asset.asset_id, used: false, synced_height: 0, hardened: false, did_id: did.did_id)
                self.puzzle_store.insert_puzzle_hash(index: 1, puzzle_hash: cat_p2_ph, wallet_type: WalletType.DID.rawValue, asset_id: supported_asset.asset_id, public_key: did.did_id, hardened: false, did_id: did.did_id)
                phs.append(did_record)
            }
        }
        
        return phs
    }
    
    func add_puzzle_for_standard_wallet(i: Int) -> [PuzzleRecord] {
        let sk = PrivateKey.master_sk_to_wallet_sk_unhardened(master: self.private_key, index: i)
        let pk = sk.get_g1_string()
        let puzzle_hash = self.standard_wallet!.puzzle_hash_for_pk(public_key: pk)
        self.puzzle_store.insert_puzzle_hash(index: i, puzzle_hash: puzzle_hash, wallet_type: 1, asset_id: StandardWallet.asset_id, public_key: pk,hardened: false, did_id: "")
        let precord = PuzzleRecord(index: i, puzzle_hash: puzzle_hash, public_key: pk, wallet_type: 1, asset_id: StandardWallet.asset_id, used: false, synced_height: 0, hardened: false, did_id: nil)
        
        let sk_hard = PrivateKey.master_sk_to_wallet_sk_hardened(master: self.private_key, index: i)
        let pk_hard = sk_hard.get_g1_string()
        let puzzle_hash_hard = self.standard_wallet!.puzzle_hash_for_pk(public_key: pk_hard)
        self.puzzle_store.insert_puzzle_hash(index: i, puzzle_hash: puzzle_hash_hard, wallet_type: 1, asset_id: StandardWallet.asset_id, public_key: pk_hard, hardened: true, did_id: "")
        let precord_hard = PuzzleRecord(index: i, puzzle_hash: puzzle_hash_hard, public_key: pk_hard, wallet_type: 1, asset_id: StandardWallet.asset_id, used: false, synced_height: 0, hardened: true, did_id: nil)
        
        return [precord, precord_hard]
    }
    
    func add_puzzle_for_cat_wallet(i: Int, asset_id: String) -> PuzzleRecord {
        let sk = PrivateKey.master_sk_to_wallet_sk_unhardened(master: self.private_key, index: i)
        let pk = sk.get_g1_string()
        let puzzle_hash = self.cat_wallet!.puzzle_hash_for_pk(public_key: pk, asset_id: asset_id)
        self.puzzle_store.insert_puzzle_hash(index: i, puzzle_hash: puzzle_hash, wallet_type: 2, asset_id: asset_id, public_key: pk, hardened: false, did_id: nil)
        let precord = PuzzleRecord(index: i, puzzle_hash: puzzle_hash, public_key: pk, wallet_type: 2, asset_id: asset_id, used: false, synced_height: 0, hardened: false, did_id: nil)
        return precord
    }
    
    func get_puzzle_hash() -> String {
        let all_phs = self.puzzle_store.get_all_phs_for_asset(asset_id: StandardWallet.asset_id)
        let last = all_phs[0]
        return last
    }
    
    func get_address(new: Bool=false) -> String {
        var max = self.puzzle_store.get_max_used()
        if new {
            max = max + 1
            let last = self.puzzle_store.get_ph_for_asset(asset_id: StandardWallet.asset_id, at_index: max, wallet_type: WalletType.STANDARD)!
            self.puzzle_store.set_used(puzzle_hash: last)
            Task.init {
                self.maybe_add_more_puzzles()
            }
        }
        let last = self.puzzle_store.get_ph_for_asset(asset_id: StandardWallet.asset_id, at_index: max, wallet_type: WalletType.STANDARD)!
        return last.xch_address
    }
    
    func sk_for_index(index: Int, hard: Bool) -> PrivateKey {
        if hard {
            return PrivateKey.master_sk_to_wallet_sk_hardened(master: self.private_key, index: index)
        } else {
            return PrivateKey.master_sk_to_wallet_sk_unhardened(master: self.private_key, index: index)
        }
    }
    
    func pk_for_index(index: Int, hard: Bool) -> String {
        let sk = sk_for_index(index: index, hard: hard)
        return sk.get_g1_string()
    }
    
    func send(amount:Double, asset: Asset, to_address: String, fee: Double, did: DID?) async -> (Bool, String?){
        let ph = to_address.to_puzzle_hash!
        
        if let did = did {
            return await self.did_wallet!.send(asset_id: asset.asset_id, user_amount: amount, fee: fee, to_puzzle_hash: ph, did: did)
        } else {
            if asset.asset_id == "XCH" {
                return await self.standard_wallet!.send_xch(to: ph, user_amount: amount, fee: fee)
            } else {
                return await self.cat_wallet!.send_cat(asset_id: asset.asset_id, user_amount: amount, fee: fee, to_puzzle_hash: ph)
            }
        }
    }
    
    func send_nft(nft:NFT, to_address: String, fee: Double) {
        print("sending nft")
        let ph = to_address.to_puzzle_hash!
        Task.init{
            await self.nft_wallet!.send_nft(nft: nft, to: ph, fee: fee)
        }
    }

    func new_did_added(did: DID) {
        let max_used = self.puzzle_store.get_max_used()
        let max_total = self.puzzle_store.get_max_total()
        let diff = 100 - (max_total - max_used)
        
        let new_records = self.add_puzzles_for_did(from: 0, to: max_total+diff, did: did)
        WalletStateManager.shared.add_phs(phs: new_records, wallet: self)
        WalletStateManager.shared.subscribe_to_coin_ids([did.coin.coin_id])
    }

    func coin_reorged(coin_id: String) {
        if let current = self.coin_store.get_coin(coin_id: coin_id) {
            if current.spent {
                let out_txs = self.tx_store.get_tx_at_height(height: current.spent_height, did_id: nil)
                for out in out_txs {
                    for removed_coin in out.removals {
                        if coin_id.ox == removed_coin.coin_id.ox {
                            self.tx_store.delete_tx(tx_id: out.tx_id)
                        }
                    }
                }
            }

            let in_tx = self.tx_store.get_tx_at_height(height: current.confirmed_height, did_id: nil)
            for tx in in_tx {
                for added_coin in tx.additions {
                    if coin_id.ox == added_coin.coin_id.ox {
                        self.tx_store.delete_tx(tx_id: tx.tx_id)
                    }
                }
            }
            self.coin_store.delete_coin(coin_id: coin_id)
        }
    }

    func maybe_add_more_puzzles(send: Bool=true) {
        let max_used = self.puzzle_store.get_max_used()
        let max_total = self.puzzle_store.get_max_total()
        if max_used  > max_total - 100 {
            let diff = 100 - (max_total - max_used)
            let new_phs = self.add_puzzles(from: max_total, to: max_total+diff)
            if new_phs.count > 0  && send {
                WalletStateManager.shared.add_phs(phs: new_phs, wallet: self)
            }
            print("add more")
        }
    }
    
    func coin_records_added(coin_records: [Coin], nft_info: JSON? = nil) async {
        var coin_ids: [String] = []
        for coin in coin_records {
            coin_ids.append(coin.coin_id)
        }
        
        for coin in coin_records {
            if let nft = nft_info {
                let new_p2_puzhash = nft["new_p2_puzhash"].stringValue.ox
                if let record = self.puzzle_store.get_derivation_record_for_ph(puzzle_hash: new_p2_puzhash) {
                    self.puzzle_store.set_used(puzzle_hash: new_p2_puzhash)
                    self.nft_store.insert_nft_info(nft_info: nft, coin: coin)
                    self.coin_store.insert_coin_record(coin_record: coin, asset_id: NFTWallet.asset_id, wallet_type: WalletType.NFT.rawValue, did_id: record.did_id)
                }
            } else {
                let result = self.puzzle_store.get_derivation_record_for_ph(puzzle_hash: coin.puzzle_hash)
                let existing = self.coin_store.get_coin(coin_id: coin.coin_id)
                
                var wallet_type = result?.wallet_type
                var asset_id = result?.asset_id
                var did_id = result?.did_id
                print("did_id: \(did_id)")
                if asset_id == nil && wallet_type == nil {
                    did_id = self.coin_store.get_did_id_for_coin(coin_id: coin.coin_id)
                    if did_id != nil {
                        wallet_type = WalletType.DID.rawValue
                        asset_id = DIDWallet.asset_id
                    }
                }
                
                if wallet_type == nil && existing != nil {
                    // NFT Coins don't have saved puzzle_hash
                    wallet_type = self.coin_store.get_wallet_type_for_coin(coin_id: coin.coin_id)
                }
                guard let wallet_type = wallet_type else {return}
                
                if wallet_type == WalletType.STANDARD.rawValue {
                    asset_id = StandardWallet.asset_id
                } else if wallet_type == WalletType.NFT.rawValue {
                    asset_id = NFTWallet.asset_id
                }
                
                guard let asset_id = asset_id else {return}
                
                if wallet_type == WalletType.CAT.rawValue {
                    await self.cat_wallet?.coin_added(coin: coin)
                }
                
                if wallet_type == WalletType.DID.rawValue && asset_id != DIDWallet.asset_id && asset_id != StandardWallet.asset_id {
                    await self.did_wallet!.cat_coin_added(coin: coin)
                }
                
                if existing == nil{
                    self.coin_store.insert_coin_record(coin_record: coin, asset_id: asset_id, wallet_type: wallet_type, did_id: did_id)
                } else {
                    if coin.spent && !existing!.spent {
                        self.coin_store.set_spent(coin_id: coin.coin_id, is_spent: coin.spent, spent_height: coin.spent_height)
                    }
                }
                

                
                let current_txs = self.tx_store.get_tx_at_height(height: coin.confirmed_height, did_id: did_id)
                
                var has_in_tx = false
                for tx in current_txs {
                    if tx.added_coin_ids.contains(coin.coin_id.ox) {
                        has_in_tx = true
                    }
                }
                
                if !has_in_tx {
                    let tx_record = TransactionRecord(tx_id: coin.coin_id, confirmed_height: coin.confirmed_height, timestamp: coin.timestamp, to_puzzle_hash: coin.puzzle_hash, amount: coin.amount, fee_amount: 0, spend_bundle: nil, additions: [coin], removals: [], asset_id: asset_id, type: TxType.Incoming, wallet_type: WalletType(rawValue: wallet_type)!, did_id: did_id)
                    self.tx_store.insert_transaction(tx_record: tx_record)
                }
        
                let unconfirmed_txs = self.tx_store.get_unconfirmed_transactions_with_coin(coin_id: coin.coin_id, did_id: nil)
                var ignore = false
                if existing?.spent == coin.spent  && unconfirmed_txs.count == 0 {
                    ignore = true
                }
                if coin.spent && !ignore {
                    // Confirm unconfimed txs
                    let current_txs = self.tx_store.get_tx_at_height(height: coin.spent_height, did_id: nil)
                    var has_out_tx = false
                    for tx in current_txs {
                        if tx.removed_coin_ids.contains(coin.coin_id.ox) {
                            has_out_tx = true
                        }
                    }
                    for tx in unconfirmed_txs {
                        if tx.removed_coin_ids.contains(coin.coin_id.ox) {
                            has_out_tx = true
                        }
                    }

                    // We want to fetch the timestmap
                    if !has_out_tx || unconfirmed_txs.count > 0 {
                        let json = JSON(["coin_id": coin.coin_id])
                        print("get_children \(coin.coin_id)")
                        let children_response = await WalletServerAPI.shared.api_call(api_name: "get_children", json_object: json)
                        guard let json = children_response.1 else {break}
                        let children = json["children"].arrayValue
                        var additions: [Coin] = []
                        if children.count > 0 {
                            let timestamp = children[0]["timestamp"].intValue - 1
                            for tx in unconfirmed_txs {
                                self.tx_store.confirm_transaction(tx_id: tx.tx_id, timestamp: timestamp, height: coin.spent_height)
                            }
                            var total_amount = 0
                            var out_amount = 0
                            var change = 0
                            var to_ph = children[0]["coin"]["puzzle_hash"].stringValue
                            var is_fee_spend = true
                            for child in children {
                                guard let ph = child["coin"]["puzzle_hash"].string else {continue}
                                let coin_amount = child["coin"]["amount"].intValue
                                let parent_id = child["coin"]["parent_coin_info"].stringValue
                                
                                total_amount += coin_amount
                                if let record = self.puzzle_store.get_derivation_record_for_ph(puzzle_hash: ph) {
                                    if record.did_id == did_id {
                                        change += coin_amount
                                    } else {
                                        out_amount += coin_amount
                                    }
                                } else {
                                    out_amount += coin_amount
                                    to_ph = ph
                                    is_fee_spend = false
                                }
                                let add = Coin(amount: coin_amount, parent_coin_id: parent_id, puzzle_hash: ph, coinbase: false, spent: false, timestamp: timestamp, spent_height: 0, confirmed_height: coin.spent_height)
                                additions.append(add)
                            }
                            let fee = total_amount

                            if children.count == 1 && is_fee_spend {
                                to_ph = "Fee"
                                out_amount = coin.amount - children[0]["coin"]["amount"].intValue
                            }

                            if let did_id = did_id {
                                if  let did = self.did_wallet?.get_did_with_id(did_id: did_id) {
                                    to_ph = self.did_wallet!.p2_puzzle_hash_for_did(did: did)
                                }
                            }
                            if !has_out_tx {
                                let tx_record = TransactionRecord(tx_id: Data.random_token().hex, confirmed_height: coin.spent_height, timestamp: timestamp, to_puzzle_hash: to_ph, amount: out_amount, fee_amount: fee, spend_bundle: nil, additions: additions, removals: [coin], asset_id: asset_id, type: TxType.Outgoing, wallet_type: WalletType(rawValue: wallet_type)!, did_id: did_id)
                                self.tx_store.insert_transaction(tx_record: tx_record)
                            }
                        }
                    }
                    
                }
                
                
                
            }
        }
    }
}
