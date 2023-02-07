import Foundation
import UIKit

class CATCOSTANTS {
    
    static let CHIA_HOLIDAY_TOKEN = Asset(name: "Chia Holiday Token",
                                          code: "CH21",
                                          asset_id: "509deafe3cd8bbfbb9ccce1d930e3d7b57b40c964fa33379b18d628175eb7a8f",
                                          asset_image_url:  URL.localURLForXCAsset(name: "ch21")!.absoluteString,
                                          wallet_type: WalletType.CAT.rawValue)

    static let STABLY_USDS = Asset(name: "Stably USD",
                                   code: "USDS",
                                   asset_id: "6d95dae356e32a71db5ddcb42224754a02524c615c5fc35f568c2af04774e589",
                                   asset_image_url:  URL.localURLForXCAsset(name: "USDS")!.absoluteString,
                                   wallet_type: WalletType.CAT.rawValue)
    static let MARMOT = Asset(name: "Marmot",
                              code: "MRMT",
                              asset_id: "8ebf855de6eb146db5602f0456d2f0cbe750d57f821b6f91a8592ee9f1d4cf31",
                              asset_image_url:   URL.localURLForXCAsset(name: "MRMT")!.absoluteString,
                              wallet_type: WalletType.CAT.rawValue)
    static let SPACEBUCKS = Asset(name: "Spacebucks",
                                  code: "SBX",
                                  asset_id: "a628c1c2c6fcb74d53746157e438e108eab5c0bb3e5c80ff9b1910b3e4832913",
                                  asset_image_url:  URL.localURLForXCAsset(name: "SBX")!.absoluteString,
                                  wallet_type: WalletType.CAT.rawValue)
    
    static let COPYCAT = Asset(name: "Copycat",
                                  code: "CCN",
                                  asset_id: "daab2989d2ea820469cc6304f8987649da204b6411e492954c013baa90b4722a",
                                  asset_image_url:  URL.localURLForXCAsset(name: "CCN")!.absoluteString,
                                  wallet_type: WalletType.CAT.rawValue)
    
//    static let TESTCAT = Asset(name: "TEST CAT",
//                                  code: "test",
//                                  asset_id: "b8ed8e4e891f1e97558fd8539ade4094dc443ac42ab592b5a9660d62a3ae7072",
//                                  asset_image_url:  URL.localURLForXCAsset(name: "XCC")!.absoluteString,
//                                  wallet_type: WalletType.CAT.rawValue)

    static let default_cats: [Asset] = [COPYCAT, STABLY_USDS, SPACEBUCKS, CHIA_HOLIDAY_TOKEN,  MARMOT]
}

extension URL {
    static func localURLForXCAsset(name: String) -> URL? {
        let fileManager = FileManager.default
        guard let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {return nil}
        let url = cacheDirectory.appendingPathComponent("\(name).png")
        let path = url.path
        if !fileManager.fileExists(atPath: path) {
            guard let image = UIImage(named: name), let data = image.pngData() else {return nil}
            fileManager.createFile(atPath: path, contents: data, attributes: nil)
        }
        return url
    }
}
