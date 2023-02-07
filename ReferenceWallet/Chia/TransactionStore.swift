import Foundation
import SQLite

class TransactionStore {
    let db_table: Table = Table("transactions")
    let bundle_id = Expression<String>("bundle_id")
    let confirmed_height_col = Expression<Int>("confirmed_height")
    let created_time_col = Expression<Int>("created_time")
    let to_puzzle_hash_col = Expression<String>("to_puzzle_hash")
    let amount_col = Expression<Int>("amount")
    let fee_amount_col = Expression<Int>("fee_amount")
    let confirmed_col = Expression<Bool>("confirmed")
    let asset_id_col = Expression<String>("asset_id")
    let did_id_col = Expression<String?>("did_id")
    let wallet_type_col = Expression<Int>("wallet_type_col")
    let transaction_record_json_col = Expression<Data>("transaction_record_json")

    var db: Connection?


    init(pubkey: String) {
        do {
            self.db = try Connection(path_for_db(pubkey: pubkey).absoluteString)
            self.db!.busyTimeout = 5

            try db!.run(db_table.create(ifNotExists: true) { t in
                t.column(bundle_id, primaryKey: true)
                t.column(confirmed_height_col)
                t.column(created_time_col)
                t.column(to_puzzle_hash_col)
                t.column(amount_col)
                t.column(fee_amount_col)
                t.column(confirmed_col)
                t.column(wallet_type_col)
                t.column(asset_id_col)
                t.column(did_id_col)
                t.column(transaction_record_json_col)
            })
            try db!.run(db_table.createIndex(asset_id_col, ifNotExists: true))

        } catch {
            self.db = nil
            print("There was an error")
        }
    }

    func insert_transaction(tx_record: TransactionRecord) {
        guard let database = self.db else {
            return
        }
        var confirmed = false
        if tx_record.confirmed_height > 0 {
            confirmed = true
        }
        let encoder = JSONEncoder()
        let data = try? encoder.encode(tx_record)

        let insert = self.db_table.insert(
            bundle_id <- tx_record.tx_id,
            confirmed_height_col <- tx_record.confirmed_height,
            created_time_col <- tx_record.timestamp,
            to_puzzle_hash_col <- tx_record.to_puzzle_hash,
            amount_col <- tx_record.amount,
            fee_amount_col <- tx_record.fee_amount,
            confirmed_col <- confirmed,
            wallet_type_col <- tx_record.wallet_type.rawValue,
            asset_id_col <- tx_record.asset_id,
            transaction_record_json_col <- data!,
            did_id_col <- tx_record.did_id
        )
        let rowid = try? database.run(insert)
    }
    
    func get_transactions(asset_id: String, wallet_type: WalletType, did_id: String?) -> [TransactionRecord] {
        guard let database = self.db else {
            return []
        }
        let decoder = JSONDecoder()
        var records: [TransactionRecord] = []
        do {
            var query = db_table.filter(asset_id_col == asset_id)
            query = query.filter(wallet_type_col == wallet_type.rawValue)
            if let did_id = did_id {
                query = query.filter(did_id_col == did_id)
            }
            for record_row in try database.prepare(query) {
                let data = record_row[transaction_record_json_col]
                if let decoded_data = try? decoder.decode(TransactionRecord.self, from: data) {
                    records.append(decoded_data)
                }
            }
        } catch {
            
        }
        let all = records.reversed().sorted(by: { $0.timestamp > $1.timestamp })
        return all
    }

    func get_unconfirmed_transactions(asset_id: String?, wallet_type: WalletType?, did_id: String?) -> [TransactionRecord] {
        guard let database = self.db else {
            return []
        }
        var query = db_table.filter(confirmed_col == false)

        if let asset_id = asset_id {
            query = query.filter(asset_id_col == asset_id)
        }

        if let wallet_type = wallet_type {
            query = query.filter(wallet_type_col == wallet_type.rawValue)
        }

        if let did_id = did_id {
            query = query.filter(did_id_col == did_id)
        }
        var records: [TransactionRecord] = []
        let decoder = JSONDecoder()

        for record_row in try! database.prepare(query) {
            let data = record_row[transaction_record_json_col]
            if let decoded_data = try? decoder.decode(TransactionRecord.self, from: data) {
                records.append(decoded_data)
            }
        }
        return records
    }

    func get_unconfirmed_transactions_with_coin(coin_id: String, did_id: String?) -> [TransactionRecord] {
        guard let database = self.db else {
            return []
        }
        let decoder = JSONDecoder()
        var records: [TransactionRecord] = []
        do {
            var query = db_table.filter(confirmed_col == false)
            if let did_id = did_id {
                query = query.filter(did_id_col == did_id)
            }
            for record_row in try database.prepare(query) {
                let data = record_row[transaction_record_json_col]
                if let decoded_data = try? decoder.decode(TransactionRecord.self, from: data) {
                    var coins: [String] = []
                    for coin in decoded_data.removals {
                        coins.append(coin.coin_id.ox)
                    }
                    for coin in decoded_data.additions {
                        coins.append(coin.coin_id.ox)
                    }
                    if coins.contains(coin_id.ox) {
                        records.append(decoded_data)
                    }
                }
            }
        } catch {
            
        }
        let all = records.reversed().sorted(by: { $0.timestamp > $1.timestamp })
        return all
    }

    func get_tx_at_height(height: Int, did_id: String?) -> [TransactionRecord] {
        guard let database = self.db else {
            return []
        }
        let decoder = JSONDecoder()
        var records: [TransactionRecord] = []
        do {
            var query = db_table.filter(confirmed_height_col == height)
            if let did_id = did_id {
                query = query.filter(did_id_col == did_id)
            }
            for record_row in try database.prepare(query) {
                let data = record_row[transaction_record_json_col]
                if let decoded_data = try? decoder.decode(TransactionRecord.self, from: data) {
                    records.append(decoded_data)
                }
            }
        } catch {
            
        }
        return records
    }
    
    func delete_tx(tx_id: String) {
        guard let database = self.db else {
            return
        }
        let tx = db_table.filter(bundle_id == tx_id)
        try? database.run(tx.delete())
    }

    func confirm_transaction(tx_id: String, timestamp: Int, height: Int) {
        guard let database = self.db else {
            return
        }
        let tx = db_table.filter(bundle_id == tx_id)
        if let tx_record = try? database.pluck(tx) {
            let decoder = JSONDecoder()
            let data = tx_record[transaction_record_json_col]
            if var old = try? decoder.decode(TransactionRecord.self, from: data) {
                let new_tx = TransactionRecord(tx_id: old.tx_id, confirmed_height: height, timestamp: timestamp, to_puzzle_hash: old.to_puzzle_hash, amount: old.amount, fee_amount: old.fee_amount, spend_bundle: old.spend_bundle, additions: old.additions, removals: old.removals, asset_id: old.asset_id, type: old.type, wallet_type: old.wallet_type, did_id: old.did_id)
                let encoder = JSONEncoder()
                let new_data = try? encoder.encode(new_tx)
                try? database.run(tx.update(confirmed_col <- true,
                                            confirmed_height_col <- height,
                                            created_time_col <- timestamp,
                                            transaction_record_json_col <- new_data!
                                           ))
            } else {
                try? database.run(tx.update(confirmed_col <- true, confirmed_height_col <- height, created_time_col <- timestamp))
            }
        }

    }

}
