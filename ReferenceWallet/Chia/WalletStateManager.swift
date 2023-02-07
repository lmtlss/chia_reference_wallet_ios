import Foundation
import SwiftyJSON
import KeychainSwift

class KeyMetadata: Codable {
    let pubkey: String
    let name: String
    init(name: String, pubkey: String) {
        self.name = name
        self.pubkey = pubkey
    }
}

class WalletStateManager {
    static let shared = WalletStateManager()
    var initialzied = false
    var keychain: KeychainSwift = KeychainSwift()
    var key_info: [KeyMetadata] = []
    var wallets: [Wallet] = []
    var puzzle_hash_for_wallet: Dictionary<String, Set<String>> = [:]
    var added_assets: [Asset] = []
    
    var request_phs: SafeDict<String, [String]> = SafeDict()
    var request_coin_ids: SafeDict<String, [String]> = SafeDict()
    
    var current_peak: Peak?
    var last_tx_peak: Peak?
    static let db_version = "1.4"
    
    var subscribed_phs: SafeSet<String> = SafeSet()
    var subscribed_coin_ids: SafeSet<String> = SafeSet()
    let coin_state_lock = NSLock()

    
    func clean_state() {
        for wallet in self.wallets {
            let path = path_for_db(pubkey: wallet.private_key.get_g1_string())
//            try? FileManager.default.removeItem(at: path)
        }
        self.keychain.clear()
        UserDefaults.standard.reset()
        self.last_tx_peak = nil
        self.current_peak = nil
        self.request_phs = SafeDict()
        self.added_assets = []
        self.puzzle_hash_for_wallet = [:]
        self.wallets = []
        self.key_info = []
    }
    
    func load_keys() -> [KeyMetadata] {
        if let storedArray: Data = UserDefaults.standard.object(forKey: "keys") as? Data {
            guard let key_list = try? storedArray.decoded() as [KeyMetadata] else {
                return []
            }
            return key_list
        }
        return []
    }
    
    func load_assets() -> [Asset] {
        if let storedArray: Data = UserDefaults.standard.object(forKey: "assets") as? Data {
            guard let assetList = try? storedArray.decoded() as [Asset] else {
                return []
            }
            return assetList
        }
        return []
    }
    
    func add_asset(asset: Asset) {
        self.added_assets.append(asset)
        UserDefaults.standard.set(try? self.added_assets.encoded(), forKey: "assets")
        for wallet in wallets {
            wallet.add_asset(asset: asset)
        }
    }
    
    private init() {
        self.initialize()
    }
    
    func initialize() {
        key_info = load_keys()
        added_assets = load_assets()
        
        for info in self.key_info {
            let mnemonic = keychain.get(info.pubkey)
            guard let mnemonic = mnemonic else {continue}
            let private_key = KeyChain().add_private_key(mnemonic: mnemonic)
            let path = path_for_db(pubkey: private_key.get_g1_string())
            let db_check = private_key.get_g1_string() + WalletStateManager.db_version
            // try? FileManager.default.removeItem(at: path)
            
            if !UserDefaults.standard.bool(forKey: db_check) {
                try? FileManager.default.removeItem(at: path)
                UserDefaults.standard.set(true, forKey: db_check)
            }
            let w = Wallet(key: private_key, extra_assets: added_assets, metadata: info)
            wallets.append(w)
        }
        
        Task.init {
            for wallet in wallets {
                wallet.initialize_addresses()
            }
            WalletServerAPI.shared
        }
    }
    
    func subscribe_to_coin_ids(_ coin_ids: [String]) {
        let request_id = Data.random_token().hex
        self.request_coin_ids[request_id] = coin_ids
        WalletServerAPI.shared.send_json(msg: ["coin_ids": coin_ids], type: WSMessageType.SUBSCRIBE_COIN_IDS, request_id: request_id)
    }
    
    func subscribe_to_phs(phs: [String]) {
        let request_id = Data.random_token().hex
        self.request_phs[request_id] = phs
        WalletServerAPI.shared.send_json(msg: ["phs": phs], type: WSMessageType.SUBSCRIBE, request_id: request_id)
    }
    
    func get_phs_for_wallet(wallet: Wallet) -> Set<String> {
        if let phs = self.puzzle_hash_for_wallet[wallet.pubkey] {
            return phs
        } else {
            let phs: Set<String> = Set()
            self.puzzle_hash_for_wallet[wallet.pubkey] = phs
            return phs
        }
    }
    
    func add_phs(phs: [PuzzleRecord], wallet: Wallet) {
        var current_phs = get_phs_for_wallet(wallet: wallet)
        var to_subscribe: [String] = []
        for ph in phs {
            if self.subscribed_phs.contains(ph.puzzle_hash.ox) {
                continue
            }
            current_phs.insert(ph.puzzle_hash.ox)
            if ph.asset_id == StandardWallet.asset_id {
                to_subscribe.append(ph.puzzle_hash.ox)
            } else if ph.wallet_type == WalletType.DID.rawValue {
                to_subscribe.append(ph.puzzle_hash.ox)
            }
        }
        self.subscribe_to_phs(phs: to_subscribe)
    }
    
    func new_peak(peak: Peak) {
        self.current_peak = peak
        if let timestamp = peak.timestamp {
            self.last_tx_peak = peak
            Task.init {
                await self.update_wallet_sync_status()
                await self.resubmit_txs()
            }
        }
    }
    
    func submit_spend_bundle(sb: SpendBundle) async -> (Bool, String?) {
        let parameters: Dictionary = [
            "spend_bundle": sb.to_json(),
        ]
        let par_json = JSON(parameters)
        let submit_result = await WalletServerAPI.shared.api_call(api_name: "submit_spend_bundle", json_object: par_json)
        if let result = submit_result.1 {
            print(result)
            if let status_str = result["result"]["status"].string {
                if status_str == "SUCCESS" {
                    return (true, nil)
                } else {
                    return (false, "Error: \(status_str)")
                }
            } else {
                return (false, "Unknown error occurend while sending tx")
            }
        } else {
            return (false, "Unknown error occurend while sending tx")
        }
        
    }
    
    func resubmit_txs() async {
        for wallet in wallets {
            let unconf = wallet.tx_store.get_unconfirmed_transactions(asset_id: nil, wallet_type: nil, did_id: nil)
            for unconf in unconf {
                if let sb = unconf.spend_bundle {
                    await self.submit_spend_bundle(sb: sb)
                }
            }
        }
    }
    
    func disconnected() {
        self.subscribed_phs = SafeSet()
    }
    
    func connected() {
        Task.init {
            await self.update_wallet_sync_status()
        }
        
        var phs: [String] = []
        for wallet in wallets {
            let all_phs = wallet.puzzle_store.get_all_phs()
            // subscrive to standard only
            let ph_for_wallet = wallet.puzzle_store.get_all_phs_for_asset(asset_id: StandardWallet.asset_id)
            phs.append(contentsOf: ph_for_wallet)
            // track all
            puzzle_hash_for_wallet[wallet.pubkey] = Set(all_phs)
            
            // Subscribe to coin states
            let all_coins = wallet.coin_store.get_all_coin_ids()
            self.subscribe_to_coin_ids(all_coins)
        }
        self.subscribe_to_phs(phs: phs)
        
    }
    
    func new_mnemonic(mnemonics: [String], name: String) {
        let mnemonic = mnemonics.joined(separator: " ")
        let private_key = KeyChain().add_private_key(mnemonic: mnemonic)
        let pub = private_key.get_g1_string()
        let new_meta = KeyMetadata(name: name, pubkey: pub)
        key_info.append(new_meta)
        keychain.set(mnemonic, forKey: pub)
        let w = Wallet(key: private_key, extra_assets: self.added_assets, metadata: new_meta)
        wallets.append(w)
        UserDefaults.standard.set(try? self.key_info.encoded(), forKey: "keys")
        Task.init {
            w.initialize_addresses()
            if WalletServerAPI.shared.isConnected {
                let all_phs = w.puzzle_store.get_all_phs()
                let ph_for_wallet = w.puzzle_store.get_all_phs_for_asset(asset_id: StandardWallet.asset_id)
                puzzle_hash_for_wallet[w.pubkey] = Set(all_phs)
                self.subscribe_to_phs(phs: ph_for_wallet)
            }
        }
        
    }
    
    func handle_did(did_args: JSON, coin: Coin) async {
        guard let metadata = did_args["metadata"].string else {return}
        guard let num_verification = did_args["num_verification"].string else {return}
        guard let singleton_struct = did_args["singleton_struct"].string else {return}
        guard let p2_puzzle = did_args["p2_puzzle"].string else {return}
        guard let recovery_list_hash = did_args["recovery_list_hash"].string else {return}
        guard let hint_list = did_args["hint_list"].array else {return}
        guard let coin_spend_dict = did_args["coin_spend"].dictionary else {return}
        guard let reveal = did_args["coin_spend"]["puzzle_reveal"].string else {return}
        guard let solution = did_args["coin_spend"]["solution"].string else {return}
        
        let coin_spend = CoinSpend(coin_record: coin, puzzle_reveal: Program(hexstr: reveal.noox), solution: Program(hexstr: solution.noox))
        
        for hint in hint_list {
            if let ph = hint.string {
                for wallet in wallets {
                    guard let derivation_record: PuzzleRecord = wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: ph) else {continue}
                    let our_inner_puzzle: Program = wallet.standard_wallet!.puzzle_for_pk(public_key: derivation_record.public_key)
                    let singleton_struct_prog = Program(hexstr: singleton_struct)
                    var args: [String] = []
                    args.append(our_inner_puzzle.disassemble_program())
                    args.append(String(recovery_list_hash.dropFirst(2)).ox)
                    args.append(Program(hexstr: num_verification).disassemble_program())
                    args.append(singleton_struct_prog.disassemble_program())
                    args.append(Program(hexstr: metadata).disassemble_program())
                    let launch_id = String(singleton_struct_prog.rest().first().program_str.dropFirst(2))
                    
                    let did_puzzle =  DIDPuzzles.DID_INNERPUZ_MOD.curry(args:args)
                    let full_puzzle = DIDPuzzles.create_fullpuz(did_puzzle: did_puzzle, launcher_id: launch_id)
                    let full_puzzle1 = DIDPuzzles.create_fullpuz(did_puzzle: did_puzzle, launcher_id: launch_id)
                    print("launch_id: \(launch_id)")
                    
                    let did_puzzle_empty_recovery = DIDPuzzles.DID_INNERPUZ_MOD.curry(args:
                                                                                        [our_inner_puzzle.disassemble_program(),
                                                                                         Program(disassembled: "()").tree_hash().ox,
                                                                                         Program(hexstr: num_verification).disassemble_program(),
                                                                                         singleton_struct_prog.disassemble_program(),
                                                                                         Program(hexstr: metadata).disassemble_program()]
                    )
                    let full_puzzle_empty_recovery = DIDPuzzles.create_fullpuz(did_puzzle: did_puzzle_empty_recovery, launcher_id: launch_id)
                    if full_puzzle.tree_hash().ox != coin.puzzle_hash.ox {
                        if full_puzzle_empty_recovery.tree_hash().ox == coin.puzzle_hash.ox {
                            print("DID recovery list was reset by the previous owner.")
                        } else {
                            print("metadata: \(metadata)")
                            
                            let result = coin_spend.puzzle_reveal.run(program: coin_spend.solution)
                            print("result: \(result)")
                            print("DID puzzle hash doesn't match, please check curried parameters.")
                            return
                        }
                    }
                    let launch_coin_result = await WalletServerAPI.shared.get_coin(coin_id: launch_id)
                    if let launch_coin = launch_coin_result.0 {
                        wallet.did_wallet!.create_new_did_wallet_from_coin_spend(did_coin: coin, launch_coin: launch_coin, did_puzzle: did_puzzle, coin_spend: coin_spend, did_args: did_args)
                    }
                    //
                    print("This is our did \(our_inner_puzzle)")
                    
                }
            }
        }
        
    }
    
    func get_wallet(pubkey: String) -> Wallet?{
        for wallet in wallets {
            if wallet.pubkey == pubkey {
                return wallet
            }
        }
        return nil
    }
    
    func is_this_nft(coin: Coin) async {
        if coin.spent {
            return
        }
        print("Is this nft coin: \(coin.coin_id) \(coin.amount)")
        
        let parameters: Dictionary = [
            "parent_coin_id": coin.parent_coin_id,
        ]
        let par_json = JSON(parameters)
        let result = await WalletServerAPI.shared.api_call(api_name: "get_nft_or_did_info", json_object: par_json)
        if result.0 == true {
            guard let result_json = result.1 else {return}
            
            if let did_args = result_json["did_args"].dictionary {
                await self.handle_did(did_args: result_json["did_args"], coin: coin)
            }
            
            if let nft_info_j = result_json["uncurried_nft"].dictionary {
                print("nft_info: \(nft_info_j)")
                let nft_info = result_json["uncurried_nft"]
                guard let p2_puzzle_hash = nft_info["new_p2_puzhash"].string else {return}
                print("NFT \(p2_puzzle_hash) \(coin.spent)")
                for wallet in wallets {
                    if let record = wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: p2_puzzle_hash) {
                        await wallet.coin_records_added(coin_records: [coin], nft_info: nft_info)
                    }
                }
                
            }
            let nft_info = result_json["uncurried_nft"]
            
        }
    }
    
    func update_wallet_sync_status () async {
        
        while true {
            if self.current_peak == nil {
                print("sleeping")
                try? await Task.sleep(for: .seconds(1))
                continue
            }
            break
        }
        
        let peak_height = self.current_peak!.height
        var synced = true
        
        for wallet in wallets {
            var not_synced_records: [PuzzleRecord] = []
            let ph_for_wallet = wallet.puzzle_store.get_all_puzzle_records(asset: StandardWallet.asset_id)
            for ph in ph_for_wallet {
                if ph.synced_height < peak_height - 2  {
                    var contains = self.subscribed_phs.contains(ph.puzzle_hash.ox)
                    if !contains {
                        synced = false
                        print("Missing ph record \(ph)")
                        
                        not_synced_records.append(ph)
                        break
                    }
                }
            }
            
            let coin_records_for_wallet = wallet.coin_store.get_all_records()
            for coin_record in coin_records_for_wallet {
                if coin_record.synced_height < peak_height - 2 {
                    var contains = false
                    contains = self.subscribed_coin_ids.contains(coin_record.coin.coin_id.ox)
                    if !contains {
                        self.subscribe_to_coin_ids([coin_record.coin.coin_id])
                        print("Missing sync coin \(coin_record)")
                        synced = false
                        break
                    }
                }
            }

            if not_synced_records.count > 0  {
                print("Not synced puzle record count is: \(not_synced_records.count)")
            }
            
            if synced {
                wallet.set_status(status: WalletStatus.synced)
            } else {
                wallet.set_status(status: WalletStatus.syncing)
            }
        }
        
    }
    
    func is_subscribed_coin_id(_ coin_id: String) -> Bool {
        return self.subscribed_coin_ids.contains(coin_id.ox)
    }
    
    func new_coin_updates(coins: [Coin], request_id: String?=nil, height: Int) async {
        self.coin_state_lock.lock()
        defer {
            self.coin_state_lock.unlock()
        }

        await self._new_coin_updates(coins: coins, request_id:  request_id, height: height)
    }

    func _new_coin_updates(coins: [Coin], request_id: String?=nil, height: Int) async {
        //        var sorted = coins.sorted(by: { $0.confirmed_height < $1.confirmed_height })
        print("request_debug started \(request_id)")
        let sorted = coins.sorted { (lhs, rhs) in
            if lhs.confirmed_height == rhs.confirmed_height { // <1>
                return lhs.spent_height < rhs.spent_height
            }
            
            return lhs.confirmed_height < rhs.confirmed_height // <2>
        }
        var coin_dict: [String: Coin] = [:]
        for coin in sorted {
            coin_dict[coin.coin_id.ox] = coin
            var found_wallet = false
            for wallet in wallets {
                if let ph_set = puzzle_hash_for_wallet[wallet.pubkey] {
                    if ph_set.contains(coin.puzzle_hash.ox) {
                        found_wallet = true
                    }
                }
                if !found_wallet {
                    let current = wallet.coin_store.get_coin(coin_id: coin.coin_id)
                    let did = wallet.did_store.get_did_info_for(coin: coin)
                    let phc = wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: coin.puzzle_hash)
                    if current != nil || did != nil  || phc != nil {
                        found_wallet = true
                    }
                }
                if !found_wallet {
                    if let ph = wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: coin.puzzle_hash) {
                        found_wallet = true
                    }
                }
                if found_wallet {
                    await wallet.coin_records_added(coin_records: [coin])
                }
            }
            
            if (!found_wallet) {
                Task.init {
                    await self.is_this_nft(coin: coin)
                }
            }
        }
        for wallet in wallets {
            wallet.update_delegates()
        }
        
        guard let request_id = request_id else {return}
        if let coin_ids = self.request_coin_ids[request_id] {
            
            for id in coin_ids {
                if coin_dict[id.ox] == nil {
                    print("Coin has been reorged: \(id)")
                    for wallet in self.wallets {
                        wallet.coin_reorged(coin_id: id)
                    }
                }
                self.subscribed_coin_ids.insert(id.ox)
            }
            
            print("coin_ids \(coin_ids)")
            for id in coin_ids {
                for wallet in wallets {
                    if let coin = wallet.coin_store.get_coin(coin_id: id) {
                        wallet.coin_store.set_synced_height(coin_id: coin.coin_id, height: height)
                    }
                }
            }
            Task.init {
                await self.update_wallet_sync_status()
            }
        }
        
        if let phs = self.request_phs[request_id] {
            for ph in phs {
                self.subscribed_phs.insert(ph.ox)
                for wallet in wallets {
                    guard let ph_set = puzzle_hash_for_wallet[wallet.pubkey] else {
                        continue
                    }
                    if ph_set.contains(ph.ox) {
                        wallet.puzzle_store.set_synced_height(puzzle_hash: ph, height: height)
                    }
                }
            }
            
            var coin_ids: [String] = []
            for coin in coins {
                coin_ids.append(coin.coin_id.ox)
            }
            self.subscribe_to_coin_ids(coin_ids)
            Task.init {
                await self.update_wallet_sync_status()
            }
        }
        print("request_debug ended \(request_id)")
    }
    
}
