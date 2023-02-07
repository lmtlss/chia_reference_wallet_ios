import UIKit

class SettingsViewController: ViewController, UITableViewDelegate, UITableViewDataSource {
    
    let titles = ["Show Mnemonics", "Notification Settings", "Support", "Legal", "Delete Account", "Log Out"]
    @IBOutlet weak var tableView: UITableView!
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titles.count;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ModelCell", for: indexPath) as? ModelCell else { fatalError("Fail to dequeue reusable cell") }
        cell.rightText.text = titles[indexPath.row]
        cell.backgroundColor = UIColor.init(named: "ColorDarkBG")
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0;
    }
    
    func log_out() {
        let alert = UIAlertController(
            title: "Log out",
            message: "Are you sure you want to log out?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: "Log out",
            style: .destructive,
            handler: { _ in
                UserDefaults.standard.reset()
                
            }))
        alert.addAction(UIAlertAction(
            title: "Cancel",
            style: .cancel,
            handler: { _ in
                // cancel action
            }))
        present(alert,
                animated: true,
                completion: nil)
        
        
    }
    
    func delete_account() {
        let alert = UIAlertController(
            title: "Delete account",
            message: "Are you sure you want to permanently delete your account?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: "DELETE ACCOUNT",
            style: .destructive,
            handler: { _ in
                //                UserManager.shared.delete_account().then({response in
                //                    UserDefaults.standard.reset()
                //                    if (response) {
                //                        let storyboard = UIStoryboard(name: "Main", bundle: nil)
                //                        let initialViewController = storyboard.instantiateViewController(withIdentifier: "first")
                //                        let appDelegate = UIApplication.shared.delegate as! AppDelegate
                //                        appDelegate.window?.rootViewController = initialViewController
                //                        appDelegate.window?.makeKeyAndVisible()
                //                    } else {
                //                        UserDefaults.standard.reset()
                //                        print("failed to log out")
                //                    }
                //                })
            }))
        alert.addAction(UIAlertAction(
            title: "Cancel",
            style: .cancel,
            handler: { _ in
                // cancel action
            }))
        present(alert,
                animated: true,
                completion: nil)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //Change the selected background view of the cell.
        tableView.deselectRow(at: indexPath, animated: true)
        if (indexPath.row == 0) {
            let wallet_count = WalletStateManager.shared.wallets.count
            if wallet_count == 0 {
                self.show_auto_dismissed_alert(text: "No wallets", time: 1)
            } else {
                self.performSegue(withIdentifier: "show_mnemonics", sender: nil)
            }
        }
        else if (indexPath.row == 1) {
            self.performSegue(withIdentifier: "notification", sender: nil)
        } else if (indexPath.row == 2) {
            self.performSegue(withIdentifier: "support", sender: nil)
        } else if (indexPath.row == 3) {
            self.performSegue(withIdentifier: "legal", sender: nil)
        } else if (indexPath.row == 4) {
            self.delete_account()
        } else if (indexPath.row == 5) {
            self.log_out()
        }
    }
    
    @IBAction func back(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    override func viewDidLoad() {
        tableView.register(UINib(nibName: "ModelCell", bundle: nil), forCellReuseIdentifier: "ModelCell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
    }
    
}
