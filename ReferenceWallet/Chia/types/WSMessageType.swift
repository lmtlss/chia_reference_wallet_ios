import Foundation

enum WSMessageType: String, Codable {
    case SUBSCRIBE = "SUBSCRIBE"
    case SUBSCRIBE_COIN_IDS = "SUBSCRIBE_COIN_IDS"
    case UPDATES = "UPDATES"
    case PEAK = "PEAK"

}
