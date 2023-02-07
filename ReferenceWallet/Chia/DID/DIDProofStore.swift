import Foundation
import SQLite
import SwiftyJSON

class DIDProofStore {
    let proof_tanble: Table = Table("did_lineage_proofs")
    let coin_id_col = Expression<String>("coin_id")
    let lineage_proof_col = Expression<Data>("lineage_proof_col")

    
    var db: Connection?

    init(pubkey: String) {
        do {
            self.db = try Connection(path_for_db(pubkey: pubkey).absoluteString)
            self.db!.busyTimeout = 5

            try db!.run(proof_tanble.create(ifNotExists: true) { t in
                t.column(coin_id_col, primaryKey: true)
                t.column(lineage_proof_col)
            })

        } catch {
            self.db = nil
            print("There was an error")
        }
    }

    func insert_lineage(coin_id: String, proof: LineageProof) {
        guard let database = self.db else {
            return
        }
        if let data = try? proof.encoded() {
            let insert = self.proof_tanble.insert(
                or: .replace,
                coin_id_col <- coin_id,
                lineage_proof_col <- data
            )
            let rowid = try? database.run(insert)
        } else {
            print("json.rawString is nil")
        }
    }

    func get_lineage_proof(coin_id: String) -> LineageProof? {
        guard let database = self.db else {
            return nil
        }

        do {
            let query = proof_tanble.filter(coin_id_col == coin_id)
            for coin_row in try database.prepare(query) {
                let proof_data = coin_row[lineage_proof_col]
                guard let did = try? proof_data.decoded() as LineageProof else {
                    return nil
                }
                return did
            }
        } catch {
            
        }

        return nil
    }

}
