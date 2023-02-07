import Foundation
import SceneKit
import UIKit

class Shownemonic: UIViewController {

    var mnemonic: [String] = []
    @IBOutlet weak var collectionView: UICollectionView!
    var wallet_name = "Wallet"

    override public func viewDidLoad() {
        mnemonic = WalletStateManager.shared.wallets[0].get_mnemonic()
        collectionView.register(UINib(nibName: "MnemonicItem", bundle: nil), forCellWithReuseIdentifier: "MnemonicItem")
        collectionView.delegate = self
        collectionView.dataSource = self;
    }

    @IBAction func bck(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        collectionView.collectionViewLayout.invalidateLayout()
        self.collectionView.reloadData()
    }
}


extension Shownemonic: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout{
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return mnemonic.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MnemonicItem", for: indexPath) as! MnemonicItem
        let mnemonic: String = self.mnemonic[indexPath.row]
        let index = indexPath.row + 1
        cell.itemIndex.text = "\(index):"
        cell.itemMnemonic.text = mnemonic
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
       // return
        let cellWidth = (self.collectionView.frame.size.width - 20) / 3 
        let itemHeight = 54.0
        return CGSize(width: cellWidth, height: itemHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: 0, bottom: 100, right: 0)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

    }
}

