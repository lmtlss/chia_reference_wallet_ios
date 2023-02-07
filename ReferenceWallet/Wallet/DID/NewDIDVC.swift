import Foundation
import UIKit

class NewDIDVC: ViewController, UITableViewDelegate, UITableViewDataSource {
    
    var wallets: [Wallet] = []
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        tableView.register(UINib(nibName: "WalletCell", bundle: nil), forCellReuseIdentifier: "WalletCell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        self.wallets = WalletStateManager.shared.wallets
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return wallets.count;
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "WalletCell", for: indexPath) as? WalletCell else { fatalError("Fail to dequeue reusable cell") }
        let wallet = wallets[indexPath.row]
        cell.walletNameLabel.text = wallet.metadata.name
        cell.walletBalenceLabel.text = wallet.standard_wallet?.get_balance_string()
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
        let wallet = wallets[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        Task.init {
            let result = await wallet.did_wallet!.generate_new_did(fee: 0)
            if result.0 {
                self.navigationController?.popToRootViewController(animated: true)
            }
            if let error = result.1 {
                self.show_auto_dismissed_alert(text: error, time: 2)
            } else {
                self.show_auto_dismissed_alert(text: "Unknown error", time: 2)
            }
        }
    }

    @IBAction func back(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

}
