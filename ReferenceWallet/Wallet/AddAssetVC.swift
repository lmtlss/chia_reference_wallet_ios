import Foundation
class AddAssetVC: ViewController {
    @IBOutlet weak var assetName: FormTextField!
    @IBOutlet weak var assetId: FormTextField!
    @IBOutlet weak var assetSymbol: FormTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func back(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func add(_ sender: Any) {
        self.view.activityStartAnimating(activityColor: .white, backgroundColor: .black)
        let new = Asset(name: assetName.text!,
                                  code: assetSymbol.text!,
                                  asset_id: assetId.text!,
                                  asset_image_url:  nil,
                                  wallet_type: 2)
        WalletStateManager.shared.add_asset(asset: new)
        self.view.activityStopAnimating()
        self.navigationController?.popViewController(animated: true)
    }
}
