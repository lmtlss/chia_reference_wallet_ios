import Foundation
import SQLite

class PuzzleStore {
    let puzzles: Table = Table("puzzles")
    let index_col = Expression<Int>("index")
    let puzzle_hash_col = Expression<String>("puzzle_hash")
    let public_key_col = Expression<String>("public_key")
    let wallet_type_col = Expression<Int>("wallet_type")
    let did_id_col = Expression<String?>("did_id")
    let asset_id_col = Expression<String>("asset_id")
    let used_col = Expression<Bool>("used")
    let hardened_col = Expression<Bool>("hardened_col")
    let synced_height_col = Expression<Int>("synced_height_col")
    var db: Connection?

    init(pubkey: String) {
        do {
            self.db = try Connection(path_for_db(pubkey: pubkey).absoluteString)
            self.db!.busyTimeout = 5
    
            try db!.run(puzzles.create(ifNotExists: true) { t in
                t.column(index_col)
                t.column(puzzle_hash_col, primaryKey: true)
                t.column(public_key_col)
                t.column(wallet_type_col)
                t.column(asset_id_col)
                t.column(used_col)
                t.column(hardened_col)
                t.column(did_id_col)
                t.column(synced_height_col)
            })
        } catch {
            self.db = nil
            print("There was an error")
        }
    }

    func get_max_total() -> Int {
        let maxed = puzzles.select(index_col.max)
        var max = 1
        if let result = try? db!.prepare(maxed) {
            for m in result {
                if let max_value = m[index_col.max] {
                    max = max_value
                }
            }
        }
        print("Last total: \(max)")
        return max
    }

    func get_max_used() -> Int {
        var used = puzzles.filter(used_col == true)
        let maxed = used.select(index_col.max)
        var max = 1
        if let result = try? db!.prepare(maxed) {
            for m in result {
                if let max_value = m[index_col.max] {
                    print(max_value)
                    max = max_value
                }
            }
        }
        return max
    }

    func insert_puzzle_hash(index: Int,
                            puzzle_hash: String,
                            wallet_type: Int,
                            asset_id: String,
                            public_key: String,
                            hardened: Bool,
                            did_id: String?,
                            used: Bool=false,
                            synced_height: Int=0
                            
    ) {
        guard let database = self.db else {
            return
        }
        
        let insert = self.puzzles.insert(index_col <- index,
                                         puzzle_hash_col <- puzzle_hash.ox,
                                         public_key_col <- public_key.ox,
                                         used_col <- used,
                                         wallet_type_col <- wallet_type,
                                         asset_id_col <- asset_id,
                                         synced_height_col <- synced_height,
                                         hardened_col <- hardened,
                                         did_id_col <- did_id
        )
        try? database.run(insert)
    }

    func set_synced_height(puzzle_hash: String, height: Int) {
        guard let db = self.db else {
            return
        }
        
        let index = self.get_derivation_index_for_ph(puzzle_hash: puzzle_hash)
        let puz = puzzles.filter(index_col == index)
        try? db.run(puz.update(synced_height_col <- height))
    }

    func set_used(puzzle_hash: String) {
        guard let db = self.db else {
            return
        }
        
        let index = self.get_derivation_index_for_ph(puzzle_hash: puzzle_hash)
        let puz = puzzles.filter(index_col == index)
        try? db.run(puz.update(used_col <- true))
    }
    
    func get_all_phs_for_asset(asset_id: String) -> [String] {
        guard let database = self.db else {
            return []
        }
        var phs: [String] = []
        do {
            let query = puzzles.filter(asset_id_col == asset_id)
            for puzzle in try database.prepare(query) {
                phs.append(puzzle[puzzle_hash_col])
            }
        } catch {

        }

        return phs
    }

    func get_ph_for_asset(asset_id: String, at_index: Int, wallet_type: WalletType, did_id: String?=nil, hardened: Bool?=nil) -> String? {
        guard let database = self.db else {
            return nil
        }
        var query = puzzles.filter(asset_id_col == asset_id)
        query = query.filter(index_col == at_index)
        query = query.filter(wallet_type_col == wallet_type.rawValue)
        if let did_id = did_id {
            query = query.filter(did_id_col == did_id)
        }
        if hardened != nil {
            query = query.filter(hardened_col == hardened!)
        }
        if let row = try? database.pluck(query) {
            return row[puzzle_hash_col]
        }

        return nil
    }

    func get_all_phs() -> [String] {
        guard let database = self.db else {
            return []
        }
        var phs: [String] = []
        do {
            for puzzle in try database.prepare(puzzles) {
                phs.append(puzzle[puzzle_hash_col])
            }
        } catch {

        }

        return phs
    }

    func get_all_puzzle_records(asset: String?=nil) -> [PuzzleRecord] {
        guard let database = self.db else {
            return []
        }
        var phs: [PuzzleRecord] = []
        do {
            var query = puzzles
            if let asset = asset {
                query = query.filter(asset_id_col==asset)
            }
            for puzzle in try database.prepare(query) {
                  phs.append(parse_puzzle_record(puzzle))
            }
        } catch {

        }

        return phs
    }
    
    func parse_puzzle_record(_ puzzle: Row) -> PuzzleRecord{
        let index = puzzle[index_col]
        let ph = puzzle[puzzle_hash_col]
        let pk = puzzle[public_key_col]
        let walllet_type = puzzle[wallet_type_col]
        let asset_id = puzzle[asset_id_col]
        let used = puzzle[used_col]
        let synced_height = puzzle[synced_height_col]
        let hardened = puzzle[hardened_col]
        var did_id = puzzle[did_id_col]
        if did_id == "" {
            did_id = nil
        }
        let record = PuzzleRecord(index: index, puzzle_hash: ph, public_key: pk, wallet_type: walllet_type, asset_id: asset_id, used: used, synced_height: synced_height, hardened: hardened, did_id: did_id)
        return record
    }

    func get_derivation_record_for_ph(puzzle_hash: String) -> PuzzleRecord? {
        guard let database = self.db else {
            return nil
        }

        do {
            let query = puzzles.filter(puzzle_hash_col == puzzle_hash.ox)
            if let row = try? database.pluck(query) {
                return parse_puzzle_record(row)
            }
        } catch {
            
        }

        return nil
    }

    func get_derivation_index_for_ph(puzzle_hash: String) -> Int {
        guard let database = self.db else {
            return -1
        }
        var index = -1
        do {
            let query = puzzles.filter(puzzle_hash_col == puzzle_hash.ox)
            for puzzle in try database.prepare(query) {
                index = Int(puzzle[index_col])
                break
            }
        } catch {
            
        }

        return index
    }

    func get_derivation_index_for_pubkey(pubkey: String) -> Int {
        guard let database = self.db else {
            return -1
        }
        var index = -1
        do {
            let query = puzzles.filter(public_key_col == pubkey.ox)
            for puzzle in try database.prepare(query) {
                index = Int(puzzle[index_col])
                break
            }
        } catch {
            
        }

        return index
    }

    func get_wallet_type_and_asset_id(puzzle_hash: String) -> (Int?, String?) {
        guard let database = self.db else {
            return (nil, nil)
        }

        do {
            let query = puzzles.filter(puzzle_hash_col == puzzle_hash.ox)
            
            for puzzle in try database.prepare(query) {
                var wallet_type = Int(puzzle[wallet_type_col])
                var asset_id = puzzle[asset_id_col]
                return (wallet_type, asset_id)
            }
        } catch {
            
        }

        return (nil, nil)
    }

}
