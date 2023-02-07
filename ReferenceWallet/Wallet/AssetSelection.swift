import Foundation
import Kingfisher

class AssetSellection: UIViewController, UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.wallet!.supportedAssets.count
    }
    
    var wallet: Wallet? = nil
    @IBOutlet weak var tableview: UITableView!
    
    override func viewDidLoad() {
        tableview.register(UINib(nibName: "AssetCell", bundle: nil), forCellReuseIdentifier: "AssetCell")
        tableview.delegate = self
        tableview.dataSource = self
        tableview.tableFooterView = UIView()
        
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "AssetCell", for: indexPath) as? AssetCell else { fatalError("Fail to dequeue reusable cell") }
        
        
        let asset: Asset = self.wallet!.supportedAssets[indexPath.row]
        cell.asset_name.text = asset.asset_name
        cell.asset_code.text = asset.asset_code
        if let url = asset.asset_image_url {
            cell.tx_image.kf.setImage(with: URL(string: url))
        } else {
            cell.tx_image.image = UIImage(color: .green, size: CGSize(width: 100, height: 100))
        }
        cell.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.0;
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let asset: Asset = self.wallet!.supportedAssets[indexPath.row]
        self.wallet!.change_selected_asset(asset: asset)
        tableView.deselectRow(at: indexPath, animated: true)
        self.dismiss(animated: true)
    }
}
