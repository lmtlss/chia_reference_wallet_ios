import Foundation
import SceneKit
import UIKit

class TransactionVC: UIViewController, UITableViewDelegate, UITableViewDataSource, WalletDelegate {

    var currentAccount: Account? = nil
    @IBOutlet weak var emptyView: UIView!
    var txs: [TransactionRecord] = []
    @IBOutlet weak var tableview: UITableView!
    
    func set_wallet(account: Account) {
        self.currentAccount = account
        account.wallet.add_delegate(delegate: self)
        self.update_view()
    }

    override func viewDidLoad() {
        tableview.register(UINib(nibName: "TransactionCell", bundle: nil), forCellReuseIdentifier: "TransactionCell")
        tableview.delegate = self
        tableview.dataSource = self
        tableview.tableFooterView = UIView()
        update_view()

    }

    func update_view() {
        guard let currentAccount = currentAccount else {
            return
        }
        let wallet = currentAccount.wallet
        if let did = currentAccount.did {
            self.txs = wallet.tx_store.get_transactions(asset_id:  wallet.selected_asset.asset_id, wallet_type: WalletType.DID, did_id: did.did_id)
        } else {
            self.txs = wallet.tx_store.get_transactions(asset_id: wallet.selected_asset.asset_id, wallet_type: WalletType(rawValue: wallet.selected_asset.wallet_type)!, did_id: nil)
        }

        if self.txs.count == 0 {
            self.emptyView.isHidden = false
        } else {
            self.emptyView.isHidden = true
        }
        self.tableview.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return txs.count
    }

    func new_coins() {
        DispatchQueue.main.async {
            self.update_view()
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TransactionCell", for: indexPath) as? TransactionCell else { fatalError("Fail to dequeue reusable cell") }
        let tx: TransactionRecord = txs[indexPath.row]
        var calculated = ""
        let asset = self.currentAccount!.wallet.selected_asset
    
        if asset.wallet_type == 1 {
            calculated = ChiaUnits.mojo_to_xch_string(mojos: tx.amount)
        } else {
            calculated = ChiaUnits.mojo_to_cat_string(mojos: tx.amount)
        }

        cell.amountLabel.text = "\(calculated) \(asset.asset_code)"
        let date = Date(timeIntervalSince1970: Double(tx.timestamp))

        if tx.type == TxType.Outgoing {
            cell.tx_image.image = UIImage(named: "TXoutgoing")
        } else {
            cell.tx_image.image = UIImage(named: "TXincoming")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "MM-dd HH:mm" //Specify your format that you want
        let strDate = dateFormatter.string(from: date)
        if tx.to_puzzle_hash == "Fee" {
            cell.address_label.text = tx.to_puzzle_hash
        } else {
            cell.address_label.text = tx.to_puzzle_hash.xch_address
        }

        if tx.confirmed_height > 0 {
            cell.date_label.text = "\(strDate)"
        } else {
            cell.date_label.text = "Not confirmed"
        }
        cell.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        return cell
    }

    override func viewWillAppear(_ animated: Bool) {
        update_view()
        self.tableview.reloadData()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54.0;
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func sync_status(sync_status: WalletStatus) {
        
    }
    
}
