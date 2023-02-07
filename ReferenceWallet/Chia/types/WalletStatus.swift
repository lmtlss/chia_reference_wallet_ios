import Foundation

enum WalletStatus: Int, Codable {
    case not_synced = 0
    case syncing = 1
    case synced = 2
}
