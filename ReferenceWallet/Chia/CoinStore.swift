import Foundation
import Foundation
import SQLite

class CoinStore {
    let coins_table: Table = Table("coins")
    let coin_id_col = Expression<String>("coin_id")
    let confirmed_height_col = Expression<Int>("confirmed_height")
    let spent_height_col = Expression<Int>("spend_height")
    let timestamp = Expression<Int>("timestamp")
    let spent = Expression<Bool>("spent")
    let coinbase = Expression<Bool>("coinbase")
    let puzzle_hash_col = Expression<String>("puzzle_hash")
    let parent_coin_id_col = Expression<String>("parent_coin_id")
    let asset_id_col = Expression<String>("asset_id")
    let did_id_col = Expression<String?>("did_id")
    let wallet_type_col = Expression<Int>("wallet_type_col")
    let amount_col = Expression<Int>("amount")
    let synced_height_col = Expression<Int>("synced_height_col")

    var db: Connection?

    init(pubkey: String) {
        do {
            self.db = try Connection(path_for_db(pubkey: pubkey).absoluteString)
            self.db!.busyTimeout = 5

            try db!.run(coins_table.create(ifNotExists: true) { t in
                t.column(coin_id_col, primaryKey: true)
                t.column(confirmed_height_col)
                t.column(spent_height_col)
                t.column(spent)
                t.column(coinbase)
                t.column(puzzle_hash_col)
                t.column(parent_coin_id_col)
                t.column(asset_id_col)
                t.column(amount_col)
                t.column(timestamp)
                t.column(did_id_col)
                t.column(wallet_type_col)
                t.column(synced_height_col)
            })

        } catch {
            self.db = nil
            print("There was an error")
        }
    }

    func insert_coin_record(coin_record: Coin, asset_id: String, wallet_type: Int, did_id: String?) {
        guard let database = self.db else {
            return
        }
        let insert = self.coins_table.insert(
            coin_id_col <- coin_record.coin_id.ox,
            confirmed_height_col <- coin_record.confirmed_height,
            spent_height_col <- coin_record.spent_height,
            timestamp <- coin_record.timestamp,
            spent <- coin_record.spent,
            coinbase <- coin_record.coinbase,
            puzzle_hash_col <- coin_record.puzzle_hash,
            parent_coin_id_col <- coin_record.parent_coin_id,
            asset_id_col <- asset_id,
            amount_col <- coin_record.amount,
            synced_height_col <- 0,
            wallet_type_col <- wallet_type,
            did_id_col <- did_id
        )
        let rowid = try? database.run(insert)
    }
    
    func get_coin(coin_id: String) -> Coin? {
        guard let database = self.db else {
            return nil
        }
        var query = coins_table.filter(coin_id_col == coin_id.ox)
        if let row = try? database.pluck(query) {
            return serialize_coin(row: row)
        }

        return nil
    }

    func delete_coin(coin_id: String) {
        guard let database = self.db else {
            return
        }
        let tx = coins_table.filter(coin_id_col == coin_id.ox)
        try? database.run(tx.delete())
    }

    func get_did_id_for_coin(coin_id: String) -> String? {
        guard let database = self.db else {
            return nil
        }
        var query = coins_table.filter(coin_id_col == coin_id)
        if let row = try? database.pluck(query) {
            return row[did_id_col]
        }

        return nil
    }

    func get_asset_id_for_coin(coin_id: String) -> String? {
        guard let database = self.db else {
            return nil
        }
        var query = coins_table.filter(coin_id_col == coin_id)
        if let row = try? database.pluck(query) {
            return row[asset_id_col]
        }

        return nil
    }

    func get_wallet_type_for_coin(coin_id: String) -> Int? {
        guard let database = self.db else {
            return nil
        }
        var query = coins_table.filter(coin_id_col == coin_id)
        if let row = try? database.pluck(query) {
            return row[wallet_type_col]
        }

        return nil
    }

    func serialize_coin(row : Row) -> Coin {
        let puzzle_hash = row[puzzle_hash_col]
        let parent_coin_id = row[parent_coin_id_col]
        let amount = row[amount_col]
        let coinbase = row[coinbase]
        let spent = row[spent]
        let timestamp = row[timestamp]
        let spent_height = row[spent_height_col]
        let confirmed_height = row[confirmed_height_col]
        let coin_id = row[coin_id_col]
        
        let coin = Coin(amount: amount, parent_coin_id: parent_coin_id, puzzle_hash: puzzle_hash, coinbase: coinbase, spent: spent, timestamp: timestamp, spent_height: spent_height, confirmed_height: confirmed_height)
        return coin
    }
    
    func serialize_coin_record(row : Row) -> CoinRecord {
        let asset_id = row[asset_id_col]
        let synced_height = row[synced_height_col]
        let coin = serialize_coin(row: row)
        let coin_record = CoinRecord(coin: coin, synced_height: synced_height, asset_id: asset_id)
        return coin_record
    }

    func get_all_records() -> [CoinRecord] {
        guard let database = self.db else {
            return []
        }
        var records: [CoinRecord] = []
        do {
            for coin_row in try database.prepare(coins_table) {
                records.append(serialize_coin_record(row: coin_row))
            }
        } catch {
            
        }

        return records
    }

    func set_synced_height(coin_id: String, height: Int) {
        guard let db = self.db else {
            return
        }
        
        let coin = coins_table.filter(coin_id_col == coin_id.ox)
        try? db.run(coin.update(synced_height_col <- height))
    }

    func set_spent(coin_id: String, is_spent: Bool, spent_height: Int) {
        guard let db = self.db else {
            return
        }
        
        let coin = coins_table.filter(coin_id_col == coin_id.ox)
        try? db.run(coin.update(spent_height_col <- spent_height, spent <- is_spent))
    }

    func get_all_coin_ids() -> [String] {
        guard let database = self.db else {
            return []
        }
        var coins: [String] = []
        do {
            for coin_row in try database.prepare(coins_table) {
                coins.append(coin_row[coin_id_col].ox)
            }
        } catch {
            
        }

        return coins
    }

    func get_all_coins(asset_id: String, wallet_type: WalletType, did_id: String?) -> [Coin] {
        guard let database = self.db else {
            return []
        }
        var coins: [Coin] = []
        do {
            var query = coins_table.filter(asset_id_col == asset_id)
            query = query.filter(wallet_type_col == wallet_type.rawValue)
            if let did_id = did_id {
                query = query.filter(did_id_col == did_id)
            }
            for coin_row in try database.prepare(query) {
                coins.append(serialize_coin(row: coin_row))
            }
        } catch {
            
        }

        return coins
    }

}
