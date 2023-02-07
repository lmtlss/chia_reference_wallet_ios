import Foundation
import UIKit
import Kingfisher
import SwiftyJSON

class NFTItem{
    let nft: NFT
    let wallet: Wallet
    let did_id: String?

    init(nft: NFT, wallet: Wallet, did_id: String?) {
        self.nft = nft
        self.wallet = wallet
        self.did_id = did_id
    }
}

class NFTCollectionViewController: UIViewController  {
    var nfts: Array<NFTItem> = []
    @IBOutlet weak var collectionView: UICollectionView!
    var first_time = true
    var copycat_cache: [String: Bool] = [:]

    override func viewDidLoad() {
        collectionView.register(UINib(nibName: "CatalogItem", bundle: nil), forCellWithReuseIdentifier: "CatalogItem")
        collectionView.delegate = self
        collectionView.dataSource = self;
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        self.updateNFTs()
    }
    
    func updateNFTs() {
        nfts = []
        for wallet in WalletStateManager.shared.wallets {
            let nft_coins = wallet.coin_store.get_all_coins(asset_id: NFTWallet.asset_id, wallet_type: WalletType.NFT, did_id: nil)
            for coin in nft_coins {
                guard let nft_info = wallet.nft_store.get_nft_info_for(coin_id: coin.coin_id) else {continue}
                if !coin.spent {
                    let nft = NFT(coin: coin, info: nft_info)
                    guard let record = wallet.puzzle_store.get_derivation_record_for_ph(puzzle_hash: nft.p2) else {continue}
                    let wnft = NFTItem(nft: nft, wallet: wallet, did_id: record.did_id)
                    self.nfts.append(wnft)
                }
            }
            let sortedItems = self.nfts.sorted {
                $0.nft.coin.timestamp > $1.nft.coin.timestamp
            }
            self.nfts = sortedItems
        }
        if self.nfts.count == 0 {
            self.collectionView.isHidden = true
        } else {
            self.collectionView.isHidden = false
        }

        self.collectionView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if first_time {
            first_time = false
            let alignedFlowLayout = collectionView.collectionViewLayout as? AlignedCollectionViewFlowLayout
            alignedFlowLayout?.horizontalAlignment = .left
            alignedFlowLayout?.verticalAlignment = .bottom
            collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.reloadData()
        }
        self.updateNFTs()
    }

}


extension NFTCollectionViewController: UICollectionViewDataSource , UICollectionViewDelegateFlowLayout{
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return nfts.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CatalogItem", for: indexPath) as! CatalogItem
        let nft: NFTItem = self.nfts[indexPath.row]
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.locale = NSLocale.current
        let calendar = Calendar.current

        dateFormatter.dateFormat = "MMM HH:mm" //Specify your format that you want
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .ordinal

        let date = Date(timeIntervalSince1970: Double(nft.nft.coin.timestamp))
        let dateComponents = calendar.component(.day, from: date)
        let day = numberFormatter.string(from: dateComponents as NSNumber)
        let strDate = dateFormatter.string(from: date)
        if let did_id = nft.did_id {
            cell.did_label.isHidden = false
        } else {
            cell.did_label.isHidden = true
        }

        cell.dateLabel.text = "\(day!) \(strDate)"

        cell.titleLabel.text =  ""
        cell.itemImage.image = nil

        if let data_uris = nft.nft.nft_info["nft_info"]["metadata_uris"].array {
            let metadata_url = data_uris[0].stringValue
            OBJCacheManager.shared.get_object(url: metadata_url).then { response in
                if let data = response as! Data? {
                    let metadata_json = JSON(data)
                    let attributes = metadata_json["collection"]["attributes"].arrayValue
                    var copycat = false
                    for attribute in attributes {
                        let type = attribute["type"].stringValue
                        if type == "twitter" {
                            let name = attribute["value"].stringValue
                            if name == "@copycat_sh" {
                                copycat = true
                                break
                            }
                        }
                    }
                    self.copycat_cache[nft.nft.coin.coin_id] = copycat
                    if copycat {
                        let nft_attr = metadata_json["attributes"].arrayValue
                        for attribute in nft_attr {
                            let type = attribute["type"].stringValue
                            if type == "preview" {
                                let preview_url = attribute["value"].stringValue
                                cell.itemImage.kf.setImage(with: URL(string: preview_url))
                            }
                        }
                    } else {
                        if let data_uris = nft.nft.nft_info["nft_info"]["data_uris"].array {
                            let image = data_uris[0].stringValue
                            cell.itemImage.kf.setImage(with: URL(string: image))
                            print(image)
                            print("hello")
                        }
                    }

                    cell.titleLabel.text =  metadata_json["name"].stringValue
                    print("hello")
                }
            }
        }


        // cell.itemImage.kf.setImage(with: URL(string: url))

        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
       // return
        let cellWidth = (self.collectionView.frame.size.width - 16) / 2
        let itemHeight = cellWidth * (1 / 0.8)
        return CGSize(width: cellWidth, height: itemHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? DisplayNFTVC {
            let result = sender! as! (NFTItem, Bool?)
            let nft_item = result.0 as! NFTItem
            let nft = nft_item.nft
            var copycat = false
            if result.1 == true {
                copycat = true
            }

            if let data_uris = nft.nft_info["nft_info"]["data_uris"].array {
                vc.url = data_uris[0].stringValue
                vc.nft_item = nft_item
                vc.copycat = copycat
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let nft: NFTItem = self.nfts[indexPath.row]
        self.performSegue(withIdentifier: "show_nft", sender: (nft, self.copycat_cache[nft.nft.coin.coin_id]))
    }

}

