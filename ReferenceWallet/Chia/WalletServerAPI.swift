import Foundation
import Alamofire
import SwiftyJSON
import Promises
import AsyncHTTPClient
import NIO
import NIOConcurrencyHelpers
import NIOFoundationCompat
import NIOHTTP1
import NIOHTTPCompression
import NIOSSL
import Starscream

class Peak {
    let header_hash: String
    let fork: Int
    let height: Int
    let timestamp: Int?

    init(header_hash: String, fork: Int, height: Int, timestamp: Int?) {
        self.header_hash = header_hash
        self.fork = fork
        self.height = height
        self.timestamp = timestamp
    }
}

class WalletServerAPI: WebSocketDelegate {
    static let shared = WalletServerAPI()
    static let host = "https://wapi.copycat.sh"
    // static let host = "http://10.0.0.3:4001"

    var socket: WebSocket!
    var isConnected = false
    var connect_task = false

    static func buildURL(suffix: String) -> String {
        let url =  String(format: "%@/api/wallet/%@", host, suffix)
        print(url)
        return url
    }

    private init() {
        Task.detached {
            await self.reconnect()
        }
    }

    func reconnect() async {
        if connect_task {
            return
        }
        connect_task = true
        defer {connect_task = false}
        while true {
            if self.isConnected {
                try? await Task.sleep(for: .seconds(10))
                continue
            }

            let url = WalletServerAPI.buildURL(suffix: "ws")
            var request = URLRequest(url: URL(string: url)!)
            request.timeoutInterval = 30
            socket = WebSocket(request: request)
            socket.delegate = self
            socket.connect()
            try? await Task.sleep(for: .seconds(7))
            if !self.isConnected {
                self.socket.delegate = nil
                self.socket.forceDisconnect()
            }
        }
    }

    func api_call(api_name: String, json_object: Optional<JSON>) async -> (Bool, JSON?) {
        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        do {
            var request = HTTPClientRequest(url: WalletServerAPI.buildURL(suffix: api_name))
            request.method = .POST
            request.headers.add(name: "Content-Type", value: "application/json")
            if let json = json_object {
                request.body = .bytes(ByteBuffer(string: json.rawString([.castNilToNSNull: true])!))
            }
            
            let response = try await httpClient.execute(request, timeout: .seconds(15))
            if response.status == .ok {
                let body = try await response.body.collect(upTo: 50 * 1024 * 1024) // 1 MB
                let readable = body.readableBytes
                let data = body.getData(at: 0, length: readable)
                let json = try JSON(data: data!)
                try await httpClient.shutdown()
                return (true, json)
            } else {
                print("error")
                try await httpClient.shutdown()
                return (false, nil)
            }
        } catch {
            do {
                try await httpClient.shutdown()
            } catch {
                print("error in shutdown")
            }
            return (false, nil)
        }

    }

    func get_coin(coin_id: String) async -> (Coin?, String?)  {
        let json = JSON(["coin_id": coin_id])
        let coin_response = await WalletServerAPI.shared.api_call(api_name: "get_coin", json_object: json)
        if coin_response.0 == true {
            if let json = coin_response.1 {
                let coin = parse_coin_record(json: json["coin"])
                return (coin, nil)
            } else {
                return (nil, nil)
            }
        } else {
            return (nil, nil)
        }
    }

    func get_coin_spend(coin_id: String) async -> (CoinSpend?, String?)  {
        let json = JSON(["coin_id": coin_id])
        let coin_response = await WalletServerAPI.shared.api_call(api_name: "get_coin_spend", json_object: json)
        if coin_response.0 == true {
            if let json = coin_response.1 {
                let coin_spend = parse_coin_spend(json: json)
                return (coin_spend, nil)
            } else {
                return (nil, "Unknown error")
            }
        } else {
            return (nil, "Unknown error")
        }
    }

    func send_json(msg: Dictionary<String, Any>, type: WSMessageType, request_id: String?=nil) {
        var request = Data.random_token().hex
        if let request_id = request_id {
            request = request_id
        }

        let payload = [
            "type": type.rawValue,
            "ack": false,
            "data": msg,
            "request_id": request,
        ] as [String : Any]

        print("Sent Message type \(type)")

        let par_json = JSON(payload)
        if let rawString = par_json.rawString() {
            socket.write(string: rawString)
        } else {
            print("json.rawString is nil")
        }
    }

    func didReceive(event: WebSocketEvent, client: WebSocket) {

        switch event {
        case .connected(let headers):
            isConnected = true
            WalletStateManager.shared.connected()
            print("websocket is connected: \(headers)")
        case .disconnected(let reason, let code):
            WalletStateManager.shared.disconnected()
            isConnected = false
            print("websocket is disconnected: \(reason) with code: \(code)")
        case .text(let string):
            let json = JSON.init(parseJSON: string)
            if let ws_message_type = json["type"].string {
                //Now you got your value
                print("Received Message type \(ws_message_type)")
                switch ws_message_type {
                case WSMessageType.SUBSCRIBE.rawValue:
                    handle_new_message(msg: json)
                case WSMessageType.UPDATES.rawValue:
                    handle_new_coin_update(msg: json)
                case WSMessageType.SUBSCRIBE_COIN_IDS.rawValue:
                    handle_new_coin_subscribe_response(msg: json)
                case WSMessageType.PEAK.rawValue:
                    handle_new_peak(msg: json)
                default:
                    print("unknown message type \(ws_message_type)")
                }
            }
        case .binary(let data):
            print("Received data: \(data.count)")
        case .ping(_):
            socket.write(pong: Data())
            break
        case .pong(_):
            break
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            print("disconnected")
            break
        case .cancelled:
            print("cancelled")
            isConnected = false
            WalletStateManager.shared.disconnected()
        case .error(let error):
            print("error")
            WalletStateManager.shared.disconnected()
            isConnected = false
            handleError(error)
        }
    }

    func handle_new_peak(msg: JSON) {
        let data = msg["data"]
    
        let header_hash = data["header_hash"].stringValue
        let height = data["height"].intValue
        let fork_point = data["fork_point_with_previous_peak"].intValue
        let timestamp = data["timestamp"].int
        
        let peak = Peak(header_hash: header_hash, fork: fork_point, height: height, timestamp: timestamp)
        Task.detached {
            WalletStateManager.shared.new_peak(peak: peak)
        }
    }

    func handle_new_coin_update(msg: JSON) {
        Task.detached {
            let json_data = msg["data"].arrayValue
            let height = msg["height"].intValue
            let request_id = msg["request_id"].string

            var coins: [Coin] = []
            for json in json_data {
                let coin = parse_coin_record(json: json)
                coins.append(coin)
            }
            await WalletStateManager.shared.new_coin_updates(coins: coins, request_id: request_id, height: height)
        }
    }

    func handle_new_message(msg: JSON) {
        Task.detached {
            let json_data = msg["data"].arrayValue
            let request_id = msg["request_id"].string
            let height = msg["height"].intValue

            var coins: [Coin] = []
            for json in json_data {
                let coin = parse_coin_record(json: json)
                coins.append(coin)
            }
            print("Coins: \(coins)")
            await WalletStateManager.shared.new_coin_updates(coins: coins, request_id: request_id, height: height)
        }
    }

    func handle_new_coin_subscribe_response(msg: JSON) {
        Task.detached {
            let json_data = msg["data"].arrayValue
            let request_id = msg["request_id"].string
            let height = msg["height"].intValue

            var coins: [Coin] = []
            for json in json_data {
                let coin = parse_coin_record(json: json)
                coins.append(coin)
            }
            print("Coins: \(coins)")
            await WalletStateManager.shared.new_coin_updates(coins: coins, request_id: request_id, height: height)
        }
    }

    func handleError(_ error: Error?) {
        if let e = error as? WSError {
            print("websocket encountered an error: \(e.message)")
        } else if let e = error {
            print("websocket encountered an error: \(e.localizedDescription)")
        } else {
            print("websocket encountered an error")
        }
    }
}
