import UIKit

class WalletOptions: ViewController, UITableViewDelegate, UITableViewDataSource {

    let titles = ["New DID", "Add token", "Logout"]
    @IBOutlet weak var tableView: UITableView!


    @IBAction func back(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    override func viewDidLoad() {
        tableView.register(UINib(nibName: "ModelCell", bundle: nil), forCellReuseIdentifier: "ModelCell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titles.count;
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ModelCell", for: indexPath) as? ModelCell else { fatalError("Fail to dequeue reusable cell") }
        cell.rightText.text = titles[indexPath.row]
        cell.backgroundColor = UIColor.init(named: "ColorDarkBG")
        cell.rightText.textColor = .white
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
        if (indexPath.row == 0) {
            self.performSegue(withIdentifier: "wallets", sender: nil)
        } else if (indexPath.row == 1) {
            self.performSegue(withIdentifier: "addToken", sender: nil)
        } else if (indexPath.row == 2) {
            WalletStateManager.shared.clean_state()
            DispatchQueue.main.async {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let initialViewController = storyboard.instantiateViewController(withIdentifier: "first")
                let mySceneDelegate = self.view.window!.windowScene!.delegate as! SceneDelegate
                mySceneDelegate.window?.rootViewController = initialViewController
                mySceneDelegate.window?.makeKeyAndVisible()
            }
       }
    }
}
