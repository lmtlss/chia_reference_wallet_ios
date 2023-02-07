import Foundation
import SQLite
import SwiftyJSON

class DIDStore {
    let did_table: Table = Table("did_info_table")
    let coin_id_col = Expression<String>("coin_id")
    let did_info_col = Expression<Data>("did_info")

    
    var db: Connection?

    init(pubkey: String) {
        do {
            self.db = try Connection(path_for_db(pubkey: pubkey).absoluteString)
            self.db!.busyTimeout = 5

            try db!.run(did_table.create(ifNotExists: true) { t in
                t.column(coin_id_col, primaryKey: true)
                t.column(did_info_col)
            })

        } catch {
            self.db = nil
            print("There was an error")
        }
    }

    func insert_did_info(did: DID) {
        guard let database = self.db else {
            return
        }
        if let data = try? did.encoded() {
            let insert = self.did_table.insert(
                or: .replace,
                coin_id_col <- did.coin.coin_id,
                did_info_col <- data
            )
            let rowid = try? database.run(insert)
        } else {
            print("json.rawString is nil")
        }
    }

    func get_did_info_for(coin: Coin) -> DID? {
        guard let database = self.db else {
            return nil
        }

        do {
            let query = did_table.filter(coin_id_col == coin.coin_id)
            for coin_row in try database.prepare(query) {
                let did_data = coin_row[did_info_col]
                guard let did = try? did_data.decoded() as DID else {
                    return nil
                }
                return did
            }
        } catch {
            
        }

        return nil
    }

}
