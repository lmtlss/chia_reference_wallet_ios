import Foundation
import SceneKit
import UIKit

class ReceiveVC: ViewController, WalletDelegate {


    var currentAccount: Account? = nil
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var addressView: UIView!
    
    func set_wallet(account: Account) {
        self.currentAccount = account
        account.wallet.add_delegate(delegate: self)
        updateReceiveLabel()
    }

    func new_coins() {
        updateReceiveLabel()
    }

    func updateReceiveLabel() {
        if let currentAccount = currentAccount {
            DispatchQueue.main.async {
                if currentAccount.wallet.initialized {
                    if currentAccount.did == nil {
                        self.addressLabel.text = currentAccount.wallet.get_address()
                    } else {
                        self.addressLabel.text = currentAccount.wallet.did_wallet!.get_address(did: currentAccount.did!)
                    }
                }
            }
        }
    }

    override func viewDidLoad() {
        updateReceiveLabel()
        self.addressLabel.text = ""

        addressView.onClick {
            let pasteboard = UIPasteboard.general
            pasteboard.string = self.addressLabel.text
            self.show_auto_dismissed_alert(text: "Address copied", time: 0.3)
            self.vibrate(style: .soft)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        Task.init {
            try await Task.sleep(for: .seconds(0.2))
            DispatchQueue.main.async {
                self.updateReceiveLabel()
            }
        }
        updateReceiveLabel()
    }

    @IBAction func newAddessAction(_ sender: Any) {
        if currentAccount!.did == nil {
            self.addressLabel.text = currentAccount!.wallet.get_address(new: true)
        } else {
            self.addressLabel.text = currentAccount!.wallet.did_wallet!.get_address(did: currentAccount!.did!, new: true)
        }
        self.vibrate(style: .soft)
    }

    func sync_status(sync_status: WalletStatus) {
    }

}

extension UIView {
    struct OnClickHolder {
        static var closures: [UIView: ()->()]  = [:]
        static var _closure:()->() = {}
    }

    var onClickClosure: () -> () {
        get { return OnClickHolder.closures[self] ?? {} }
        set { OnClickHolder.closures[self] = newValue }
    }


    func onClick(target: Any, _ selector: Selector) {
        isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: selector)
        addGestureRecognizer(tap)
    }

    func onClick(closure: @escaping ()->()) {
        self.onClickClosure = closure

        isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(onClickAction))
        addGestureRecognizer(tap)
    }

    @objc private func onClickAction() {
        onClickClosure()
    }

}
