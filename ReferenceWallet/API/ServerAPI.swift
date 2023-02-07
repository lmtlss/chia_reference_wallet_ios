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
import SwiftyJSON

class ServerAPI {
    static let shared = ServerAPI()
     static let host = "https://api.copycat.sh"
     //static let host = "http://10.0.0.3:4000"

    let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)

    static func buildURL(suffix: String) -> String {
        let url =  String(format: "%@/api/%@", host, suffix)
        print(url)
        return url
    }

    private init() {

    }

    func api_call(api_name: String, json_object: Optional<JSON>) async -> (Bool, JSON?) {
        do {
            var json_s = json_object
            if json_s == nil {
                json_s = JSON([:])
            }
            json_s!["app_id"] = "copycat"
            var request = HTTPClientRequest(url: ServerAPI.buildURL(suffix: api_name))
            request.method = .POST
            request.headers.add(name: "Content-Type", value: "application/json")
            let url = URL(string: ServerAPI.buildURL(suffix: api_name))

            if let saved_cookies = HTTPCookieStorage.shared.cookies(for: url!) {
                for saved in saved_cookies {
                    print("\(saved.name)=\(saved.value)")
                    request.headers.add(name: "Cookie", value: "\(saved.name)=\(saved.value)")
                }
            }

            if let json = json_s {
                request.body = .bytes(ByteBuffer(string: json.rawString([.castNilToNSNull: true])!))
            }
            
            let response = try await httpClient.execute(request, timeout: .seconds(30))
            let headers = response.headers
            let cookies = headers["Set-Cookie"]
            for cookie in cookies {
                let coo = HTTPClient.Cookie(header: cookie, defaultDomain: url!.host!)
                let sookie = HTTPCookie(properties: [
                    .name: coo!.name,
                    .value: coo!.value,
                    .domain: url!.host,
                    .path: "/",
                    .expires: "2033-05-16 10:20:22 +0000",
                    .comment: "Test cookie"
                ])!
                if let saved_cookies = HTTPCookieStorage.shared.cookies(for: url!) {
                    for s in saved_cookies {
                        HTTPCookieStorage.shared.deleteCookie(s)
                    }
                }
                HTTPCookieStorage.shared.setCookie(sookie)
            }
            
            if response.status == .ok {
                let body = try await response.body.collect(upTo: 50 * 1024 * 1024) // 1 MB
                let readable = body.readableBytes
                let data = body.getData(at: 0, length: readable)
                let json = try JSON(data: data!)
//                try await httpClient.shutdown()
                return (true, json)
            } else {
                print("error")
//                try await httpClient.shutdown()
                return (false, nil)
            }
        } catch {
            do {
//                try await httpClient.shutdown()
            } catch {
                print("error in shutdown")
            }
            return (false, nil)
        }

    }

    func api_call_data(api_name: String, data: Data) async -> (Bool, JSON?) {
        do {
            var request = HTTPClientRequest(url: ServerAPI.buildURL(suffix: api_name))
            request.method = .POST
            request.headers.add(name: "Content-Type", value: "multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW")
            request.body = .bytes(ByteBuffer(data: data))
            let response = try await httpClient.execute(request, timeout: .seconds(30))
            if response.status == .ok {
                let body = try await response.body.collect(upTo: 50 * 1024 * 1024) // 1 MB
                let readable = body.readableBytes
                let data = body.getData(at: 0, length: readable)
                let json = try JSON(data: data!)
//                try await httpClient.shutdown()
                return (true, json)
            } else {
                print("error")
//                try await httpClient.shutdown()
                return (false, nil)
            }
        } catch {
            do {
//                try await httpClient.shutdown()
            } catch {
                print("error in shutdown")
            }
            return (false, nil)
        }

    }



}

