import UIKit
import SwiftyJSON

class DIDMetadataVC: ViewController {
    var currentAccount: Account? = nil
    var items: [(String, String)] = []
    @IBOutlet weak var collectionView: UICollectionView!

    override func viewDidLoad() {
        collectionView.register(UINib(nibName: "MetadataTextfield", bundle: nil), forCellWithReuseIdentifier: "MetadataTextfield")
        collectionView.delegate = self
        collectionView.dataSource = self;
        items = []
        self.hideKeyboard()
    }
    
    @IBAction func save(_ sender: Any) {
        Task.init {
            let did = currentAccount!.did!
            var dict: [String: String] = [:]
            for item in items {
                dict[item.0] = item.1
            }
            print(dict)

            var metadata = JSON(dict)
            let submit_result = await self.currentAccount?.wallet.did_wallet?.send_update_metadata_spend(did: did, metadata: metadata)

            self.navigationController?.popToRootViewController(animated: true)
        }
    }

    @IBAction func addField(_ sender: Any) {
        items.append(("", ""))
        self.collectionView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        let dict = currentAccount!.did!.metadata_json.dictionaryValue
        print(dict)
        
        for item in dict {
            items.append((item.key, item.value.stringValue))
        }
        print("")
    }
    //                 await self.currentAccount?.wallet.did_wallet?.send_update_metadata_spend(did: did, metadata: current_metadata)


    @IBAction func back(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
}


extension DIDMetadataVC: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout{
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MetadataTextfield", for: indexPath) as! MetadataTextfield
        let item = self.items[indexPath.row]
        let key = item.0
        let value = item.1
        var kyc = false
        if key.starts(with: "kyc_did") {
            cell.valueTextfield.isEnabled = false
            kyc = true
        } else {
            cell.valueTextfield.isEnabled = true
        }

        cell.keyTextfield.tag = indexPath.row * 2
        cell.valueTextfield.tag = (indexPath.row * 2) + 1
        cell.keyTextfield.text = item.0
        cell.valueTextfield.text = item.1
        cell.keyTextfield.delegate = self
        cell.valueTextfield.delegate = self
        cell.keyTextfield.addTarget(self, action: #selector(yourHandler(textField:)), for: .editingChanged)
        cell.valueTextfield.addTarget(self, action: #selector(yourHandler(textField:)), for: .editingChanged)
        cell.trashButton.onClick {
            if kyc {
                // pass
            } else {
                self.collectionView.deleteItems(at: [indexPath])
                self.items.remove(at: indexPath.row)
            }

        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
       // return
        let cellWidth = (self.collectionView.frame.size.width - 32)
        let itemHeight = 54.0
        return CGSize(width: cellWidth, height: itemHeight)
    }

    @objc final private func yourHandler(textField: UITextField) {
        let item_index = textField.tag / 2
        var current = self.items[item_index]

        if textField.tag % 2  == 0 {
            current.0 = textField.text!
            self.items[item_index] = current
        } else {
            current.1 = textField.text!
            self.items[item_index] = current
        }

    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: 0, bottom: 400, right: 0)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

    }
}

