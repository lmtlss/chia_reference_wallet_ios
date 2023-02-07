import UIKit

class DIDOptions: ViewController, UITableViewDelegate, UITableViewDataSource {

    let titles = ["Metadata", "Connect"]
    @IBOutlet weak var tableView: UITableView!
    var currentAccount: Account? = nil

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
            self.performSegue(withIdentifier: "metadata", sender: nil)
        } else if (indexPath.row == 1) {
            self.performSegue(withIdentifier: "kyc", sender: nil)
        } else if (indexPath.row == 2) {
            self.show_auto_dismissed_alert(text: "Not yet available", time: 1)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? DIDMetadataVC {
            vc.currentAccount = self.currentAccount!
        }
    }

}
