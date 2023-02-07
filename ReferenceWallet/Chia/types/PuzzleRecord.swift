import Foundation

class PuzzleRecord: NSObject {
    let index: Int
    let puzzle_hash: String
    let public_key: String
    let wallet_type: Int
    let asset_id: String
    let used: Bool
    let hardened: Bool
    let synced_height: Int
    let did_id: String?

    init(index: Int, puzzle_hash: String, public_key: String, wallet_type: Int, asset_id: String, used: Bool, synced_height: Int, hardened: Bool, did_id: String?) {
        self.index = index
        self.puzzle_hash = puzzle_hash
        self.public_key = public_key
        self.wallet_type = wallet_type
        self.asset_id = asset_id
        self.used = used
        self.synced_height = synced_height
        self.hardened = hardened
        self.did_id = did_id
    }
    
    override var description: String {
        return "PuzzleRecord: index: \(index), wallet_type: \(wallet_type), asset_id: \(asset_id), puzzle_hash: \(puzzle_hash)"
    }
}
