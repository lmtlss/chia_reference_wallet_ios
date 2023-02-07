import Foundation
import SceneKit
import UIKit

class WalletViewController: UIViewController, WalletDelegate {

    
    func sync_status(sync_status: WalletStatus) {
        self.update_sync_view()
    }
    
       
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var downArrow: UIImageView!
    @IBOutlet weak var emptyView: UIView!
    var walletContainer: WalletUIVC? = nil
    var wallets: [Wallet] = []
    @IBOutlet weak var middleArea: UIView!
    @IBOutlet weak var walletStatusLabel: UILabel!
    @IBOutlet weak var walletStatusCircle: UIView!
    @IBOutlet weak var walletView: UIView!
    @IBOutlet weak var rightButton: UIButton!
    @IBOutlet weak var walletName: UILabel!
    var account: Account? = nil

    override func viewDidLoad() {
        update_view()
        middleArea.onClick{
            self.performSegue(withIdentifier: "accounts", sender: nil)
        }
    }
    

    @IBAction func createNewWallet(_ sender: Any) {
        self.performSegue(withIdentifier: "newWallet", sender: nil)
    }

    @IBAction func importExistingWallet(_ sender: Any) {
        self.performSegue(withIdentifier: "existingWallet", sender: nil)
    }

    @IBAction func options(_ sender: Any) {
        self.performSegue(withIdentifier: "options", sender: nil)
    }


    func update_sync_view() {
        DispatchQueue.main.async {
            if self.wallets.count == 0 {
                self.walletStatusCircle.isHidden = true
                self.walletStatusLabel.isHidden = true
                self.rightButton.isHidden = true
                return
            }
            self.walletStatusCircle.isHidden = false

            let wallet: Wallet = self.wallets[0]
            if wallet.status == .not_synced  {
                self.walletStatusCircle.backgroundColor = UIColor.red
                self.walletStatusLabel.text = "Not synced"
            } else if wallet.status == .syncing {
                self.walletStatusCircle.backgroundColor = UIColor.blue
                self.walletStatusLabel.text = "Syncing"
            } else if wallet.status == .synced {
                self.walletStatusLabel.text = "Synced"
                self.walletStatusCircle.backgroundColor = UIColor.appColor(.green)!
            }
            self.walletStatusLabel.isHidden = false
        }
    }

    func update_view() {
        let wallets = WalletStateManager.shared.wallets
        for wallet in wallets {
            wallet.add_delegate(delegate: self)
        }

        self.wallets = wallets
        if wallets.count == 0 {
            emptyView.isHidden = false
            walletView.isHidden = true
        } else {
            emptyView.isHidden = true
            walletView.isHidden = false
            if self.account == nil {
                self.set_account(account: Account(wallet: wallets[0], did: nil))
            }
        }

        update_sync_view()
    }

    func new_coins() {
        DispatchQueue.main.async {
            if let did = self.account!.did {
                if let updated = self.account?.wallet.did_wallet?.get_did_with_id(did_id: did.did_id) {
                    self.set_account(account: Account(wallet: self.account!.wallet, did: updated))
                }
            }
        }
    }

    func set_account(account: Account) {
        if account.did != nil {
            walletName.text = account.did!.name
        } else {
            walletName.text = account.wallet.metadata.name
        }
        account.wallet.add_delegate(delegate: self)
        self.account = account
        self.walletContainer?.set_wallet(account: account)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update_view()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? WalletUIVC {
            self.walletContainer = vc
        }

        if let vc = segue.destination as? WalletSelectVC {
            vc.vc = self
        }
    
    }
}
