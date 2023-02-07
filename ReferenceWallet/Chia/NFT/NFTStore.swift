import Foundation
import SQLite
import SwiftyJSON

class NFTStore {
    let coins_table: Table = Table("nft_info")
    let coin_id_col = Expression<String>("coin_id")
    let nft_info_col = Expression<String>("nft_info")
    var db: Connection?

    init(pubkey: String) {
        do {
            self.db = try Connection(path_for_db(pubkey: pubkey).absoluteString)
            self.db!.busyTimeout = 5

            try db!.run(coins_table.create(ifNotExists: true) { t in
                t.column(coin_id_col, primaryKey: true)
                t.column(nft_info_col)
            })

        } catch {
            self.db = nil
            print("There was an error")
        }
    }

    func insert_nft_info(nft_info: JSON, coin: Coin) {
        guard let database = self.db else {
            return
        }
        if let rawString = nft_info.rawString() {
            let insert = self.coins_table.insert(
                or: .replace,
                coin_id_col <- coin.coin_id,
                nft_info_col <- rawString
            )
            let rowid = try? database.run(insert)
        } else {
            print("json.rawString is nil")
        }

    }
   
    func get_nft_info_for(coin_id: String) -> JSON? {
        guard let database = self.db else {
            return nil
        }

        do {
            let query = coins_table.filter(coin_id_col == coin_id)
            for coin_row in try database.prepare(query) {
                let nft_string = coin_row[nft_info_col]
                let json = JSON(parseJSON: nft_string)
                return json
            }
        } catch {
            
        }

        return nil
    }

}
