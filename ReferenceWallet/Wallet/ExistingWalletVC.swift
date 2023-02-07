import Foundation
import SceneKit
import UIKit

class ExistingWalletVC: UIViewController {

    var mnemonic: [String] = []

    @IBOutlet weak var collectionView: UICollectionView!
    var wallet_name = "Wallet"
    let trie = Trie()
    let generator = UIImpactFeedbackGenerator(style: .heavy)

    override public func viewDidLoad() {
        collectionView.register(UINib(nibName: "MnemonicTextfield", bundle: nil), forCellWithReuseIdentifier: "MnemonicTextfield")
        collectionView.delegate = self
        collectionView.dataSource = self;
        for i in 0..<24 {
            mnemonic.append("")
        }

        if let path = Bundle.main.path(forResource: "english", ofType: "txt") {
            do {
                let data = try String(contentsOfFile: path, encoding: .utf8)
                let myStrings = data.components(separatedBy: .newlines)
                for word in myStrings {
                    self.trie.insert(word: word)
                }
            } catch {
                print(error)
            }
        }

        self.hideKeyboard()

    }

    @IBAction func bck(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    func showAlert(title: String, message: String, buttonTitle: String? = "OK", showCancel: Bool = false, buttonHandler: ((UIAlertAction) -> Void)? = nil) {
        print(title + "\n" + message)
        
        var actions = [UIAlertAction]()
        if let buttonTitle = buttonTitle {
            actions.append(UIAlertAction(title: buttonTitle, style: .default, handler: buttonHandler))
        }
        if showCancel {
            actions.append(UIAlertAction(title: "Cancel", style: .cancel))
        }
        self.showAlert(title: title, message: message, actions: actions)
    }

    func showAlert(title: String, message: String, actions: [UIAlertAction]) {
        let showAlertBlock = {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            actions.forEach { alertController.addAction($0) }
            DispatchQueue.main.async {
                self.present(alertController, animated: true, completion: nil)
            }
        }
        
        if presentedViewController != nil {
            dismiss(animated: true) {
                showAlertBlock()
            }
        } else {
            showAlertBlock()
        }
    }

    @IBAction func createWalletTouched(_ sender: Any) {
        var correct = true
        for word in mnemonic {
            let matches = self.trie.findWordsWithPrefix(prefix: word)
            if matches.count != 1{
                correct = false
                generator.impactOccurred()
                generator.impactOccurred()
                generator.impactOccurred()
                self.showAlert(title: "Error", message: "Invalid mnemonic", buttonTitle: "Ok", showCancel: false, buttonHandler: nil)
                return
                break
            }
        }

        WalletStateManager.shared.new_mnemonic(mnemonics: self.mnemonic, name: self.wallet_name)
        self.performSegue(withIdentifier: "wallet", sender: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collectionView.collectionViewLayout.invalidateLayout()
        self.collectionView.reloadData()
    }
}


extension ExistingWalletVC: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout{
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 24
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MnemonicTextfield", for: indexPath) as! MnemonicTextfield
        let mnemonic: String = self.mnemonic[indexPath.row]
        let index = indexPath.row + 1
        cell.itemIndex.text = "\(index)"
        cell.itemTextfield.text = mnemonic
        cell.itemTextfield.tag = indexPath.row
        cell.itemTextfield.addTarget(self, action: #selector(yourHandler(textField:)), for: .editingChanged)
        cell.itemTextfield.autocorrectionType = .no
        let matches = self.trie.findWordsWithPrefix(prefix: cell.itemTextfield.text!)

        if cell.itemTextfield.text != "" && matches.count == 0 {
            cell.itemTextfield.textColor = UIColor.red
        } else {
            cell.itemTextfield.textColor = UIColor.white
        }
        return cell
    }

    @objc final private func yourHandler(textField: UITextField) {
        let current = self.mnemonic[textField.tag]

        self.mnemonic[textField.tag] = textField.text ?? ""
        let matches = self.trie.findWordsWithPrefix(prefix: textField.text!)
        var override = false
        if textField.text!.count == current.count-1 {
            override = true
        }

        if matches.count == 1 && !override {
            textField.text = matches[0]
            generator.impactOccurred()
            self.mnemonic[textField.tag] = matches[0]
        }
        let current_field = textField.text!
    
        if textField.text != "" && matches.count == 0 {
            var fixed = false
            if current_field.count > 3 {
                var previous = String(current_field.dropLast(1))
                let matches = self.trie.findWordsWithPrefix(prefix: previous)
                if matches.count == 1 {
                    textField.text = matches[0]
                    generator.impactOccurred()
                    self.mnemonic[textField.tag] = matches[0]
                    fixed = true
                }
            }
            if !fixed {
                textField.textColor = UIColor.red
                generator.impactOccurred()
            }
        } else {
            textField.textColor = UIColor.white
        }
        print(matches)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
       // return
        let cellWidth = (self.collectionView.frame.size.width - 8) / 3 - 4
        let itemHeight = 54.0
        return CGSize(width: cellWidth, height: itemHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: 0, bottom: 400, right: 0)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

    }
}

