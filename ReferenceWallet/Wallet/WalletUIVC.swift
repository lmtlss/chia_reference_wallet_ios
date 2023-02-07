import Foundation
import UIKit
import Kingfisher

class WalletUIVC: UIViewController, WalletDelegate  {

    


    var tabSelected = 0

    @IBOutlet weak var leftIndicator: UIView!
    @IBOutlet weak var middleIndicator: UIView!
    @IBOutlet weak var rightIndicator: UIView!

    @IBOutlet weak var TransactionContainer: UIView!
    @IBOutlet weak var ReceiveContainer: UIView!
    @IBOutlet weak var SendContainer: UIView!

    
    @IBOutlet weak var assetLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    var currentAccount: Account? = nil
    
    var receive_container: ReceiveVC? = nil
    var send_container: SendVC? = nil
    var tx_container: TransactionVC? = nil
    @IBOutlet weak var didButton: UIButton!
    @IBOutlet weak var downArrow: UIImageView!
    
    func set_wallet(account: Account) {
        self.currentAccount = account
        if account.did == nil {
            didButton.isHidden = true
        } else {
            didButton.isHidden = false
        }
        send_container?.set_wallet(account: account)
        receive_container?.set_wallet(account: account)
        tx_container?.set_wallet(account: account)
        account.wallet.add_delegate(delegate: self)
        self.update_balance()
    }

    func new_coins() {
        update_balance()
    }

    func sync_status(sync_status: WalletStatus) {
        print(sync_status)
        update_balance()
    }
    
    
    @IBAction func did_options(_ sender: Any) {
        self.performSegue(withIdentifier: "did_options", sender: nil)
    }

    override func viewDidLoad() {
        update_balance()
        self.hideKeyboard()
        downArrow.onClick {
            self.performSegue(withIdentifier: "assets", sender: nil)
        }
    }

    func update_balance() {
        print("update_balance")
        if let currentAccount = currentAccount {
            let currentWallet = currentAccount.wallet
            DispatchQueue.main.async {
                let asset = currentAccount.wallet.selected_asset
                self.assetLabel.text = "\(asset.asset_name) (\(asset.asset_code))"

                if let did = currentAccount.did {
                    let balance = currentWallet.did_wallet!.get_balance_string(asset_id: asset.asset_id, did: did)
                    self.balanceLabel.text = "\(balance) \(currentAccount.wallet.selected_asset.asset_code)"
                } else {
                    if asset.wallet_type == 1 {
                        if let standard_wallet = currentAccount.wallet.standard_wallet {
                            let balance = standard_wallet.get_balance_string()
                            self.balanceLabel.text = "\(balance) \(currentAccount.wallet.selected_asset.asset_code)"
                        }
                    } else {
                        let balance = currentAccount.wallet.cat_wallet!.get_balance_string(asset_id: currentWallet.selected_asset.asset_id, spendable: false)
                        self.balanceLabel.text = "\(balance) \(currentAccount.wallet.selected_asset.asset_code)"
                    }
                }

            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update_balance()
        self.updateTabView()
    }

    func updateTabView() {
        if tabSelected == 0 {
            leftIndicator.isHidden = false
            middleIndicator.isHidden = true
            rightIndicator.isHidden = true
            TransactionContainer.isHidden = false
            ReceiveContainer.isHidden = true
            SendContainer.isHidden = true
        } else if tabSelected == 1 {
            leftIndicator.isHidden = true
            middleIndicator.isHidden = false
            rightIndicator.isHidden = true
            TransactionContainer.isHidden = true
            ReceiveContainer.isHidden = false
            SendContainer.isHidden = true
        } else if tabSelected == 2 {
            leftIndicator.isHidden = true
            middleIndicator.isHidden = true
            rightIndicator.isHidden = false
            TransactionContainer.isHidden = true
            ReceiveContainer.isHidden = true
            SendContainer.isHidden = false
        }
    }

    @IBAction func activityTabSelected(_ sender: Any) {
        tabSelected = 0
        updateTabView()
    }
    

    @IBAction func nftTabSelected(_ sender: Any) {
        tabSelected = 1
        updateTabView()
    }

    @IBAction func scanTabSelected(_ sender: Any) {
        tabSelected = 2
        updateTabView()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? ReceiveVC {
            self.receive_container = vc
        }
        if let vc = segue.destination as? SendVC {
            self.send_container = vc
            vc.parent_card = self
        }
        if let vc = segue.destination as? TransactionVC {
            self.tx_container = vc
        }
        if let vc = segue.destination as? AssetSellection {
            vc.wallet = self.currentAccount!.wallet
        }
        if let vc = segue.destination as? DIDOptions {
            vc.currentAccount = self.currentAccount!
        }
    }

    @IBAction func assetSelection(_ sender: Any) {
        self.performSegue(withIdentifier: "assets", sender: nil)
    }

}
