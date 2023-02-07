import UIKit
import Foundation

class Account {
    let wallet: Wallet
    let did: DID?
    
    init(wallet: Wallet, did: DID?) {
        self.wallet = wallet
        self.did = did
    }
}

class WalletSelectVC: ViewController, UITableViewDelegate, UITableViewDataSource {
    
    var wallets: [Wallet] = []
    var dids: [DID] = []
    var accounts: [Account] = []
    weak var vc: WalletViewController? = nil

    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        tableView.register(UINib(nibName: "WalletCell", bundle: nil), forCellReuseIdentifier: "WalletCell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        self.wallets = WalletStateManager.shared.wallets
        dids = []
        accounts = []
        for wallet in wallets {
            accounts.append(Account(wallet: wallet, did: nil))
            let w_dids = wallet.did_wallet!.get_dids()
            dids.append(contentsOf: w_dids)
            for did in w_dids {
                accounts.append(Account(wallet: wallet, did: did))
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accounts.count;
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "WalletCell", for: indexPath) as? WalletCell else { fatalError("Fail to dequeue reusable cell") }
        let account = accounts[indexPath.row]
        let wallet = account.wallet

        if account.did == nil {
            cell.walletNameLabel.text = wallet.metadata.name
            cell.walletBalenceLabel.text = wallet.standard_wallet?.get_balance_string()
        } else {
            cell.walletNameLabel.text = "\(account.did!.name)"
            cell.walletBalenceLabel.text = wallet.did_wallet!.get_balance_string(asset_id: StandardWallet.asset_id, did: account.did!)
        }

        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0;
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //Change the selected background view of the cell.
        tableView.deselectRow(at: indexPath, animated: true)
        let account = accounts[indexPath.row]
        vc?.set_account(account: account)
        self.dismiss(animated: true)
        
    }

    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true)
    }

}

