import Foundation
import Alamofire
import Promises
import SwiftyJSON
import KeychainSwift
import SDWebImage
import Cache

class OBJCacheManager {
    static let shared = OBJCacheManager()
    var storage: Storage<String, Data>?

    private init() {
        let diskConfig = DiskConfig(name: "cache", expiry: .never, maxSize: 1024 * 1000 * 1000 * 10)
        let memoryConfig = MemoryConfig(expiry: .never, countLimit: 50, totalCostLimit: 0)

        self.storage = try? Storage(
          diskConfig: diskConfig,
          memoryConfig: memoryConfig,
          transformer: TransformerFactory.forCodable(ofType: Data.self)
        )
    }

    func get_object(url: String) -> Promise<Any> {
        return Promise<Any>{fulfill, reject  in
            let stored = try? self.storage!.object(forKey: url)
            if stored != nil {
                fulfill(stored)
            } else {
                AF.download(url).response { response in
                    switch response.result{
                    case .success:
                        if response.error == nil, let filePath = response.fileURL?.path {
                            if let data = try? Data(contentsOf: response.fileURL!) {
                                try? self.storage!.setObject(data, forKey: url)
                                fulfill(data)
                            }
                            fulfill("error")
                        }
                    case .failure:
                        reject(response.error!)
                    }
                }
                // download
            }
        }
    }
 
}

