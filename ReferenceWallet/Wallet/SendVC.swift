import Foundation
import SceneKit
import UIKit

class SendVC: ViewController, MTSlideToOpenDelegate, WalletDelegate {

    
    var currentAccount: Account? = nil
    @IBOutlet weak var feeTextfield: FormTextField!
    @IBOutlet weak var amountTextfield: FormTextField!
    @IBOutlet weak var addressTextfield: FormTextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var fee_code_label: UILabel!
    var parent_card: WalletUIVC? = nil
    @IBOutlet weak var asset_code_label: UILabel!
    
    lazy var slideToOpen: MTSlideToOpenView = {
        let slide = MTSlideToOpenView(frame: sendButton.frame)
        slide.sliderViewTopDistance = 0
        slide.sliderCornerRadius = 26
        slide.showSliderText = true
        slide.thumbnailColor = UIColor.appColor(.green)!
        slide.slidingColor = UIColor.appColor(.green)!
        slide.textColor = UIColor.white
        slide.sliderBackgroundColor = UIColor.clear
        slide.delegate = self
        slide.labelText = "Send"
        slide.thumnailImageView.image = #imageLiteral(resourceName: "rightArrow").imageFlippedForRightToLeftLayoutDirection()
        slide.sliderHolderView.layer.borderWidth = 2
        slide.sliderHolderView.layer.borderColor = UIColor.appColor(.green)!.cgColor
        return slide
    }()

    func set_wallet(account: Account) {
        self.currentAccount = account
        asset_code_label.text = account.wallet.selected_asset.asset_code
        account.wallet.add_delegate(delegate: self)

    }

    func new_coins() {
        asset_code_label.text = self.currentAccount!.wallet.selected_asset.asset_code
    }
    
    func sync_status(sync_status: WalletStatus) {
        
    }

    override func viewDidLoad() {
        self.hideKeyboard()
        self.feeTextfield.delegate = self
        self.amountTextfield.delegate = self
        self.addressTextfield.delegate = self
        self.addressTextfield.text = ""
        self.amountTextfield.text = ""
        self.feeTextfield.text = "0"
        self.view.addSubview(slideToOpen)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.slideToOpen.frame = sendButton.frame
        self.view.bringSubviewToFront(self.fee_code_label)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        sendButton.isHidden = true
        self.slideToOpen.frame = sendButton.frame
        self.view.bringSubviewToFront(self.fee_code_label)
    }
    
    func mtSlideToOpenDelegateDidFinish(_ sender: MTSlideToOpenView) {
        defer {
            sender.resetStateWithAnimation(false)
        }

        if self.currentAccount!.wallet.status != WalletStatus.synced {
            self.show_auto_dismissed_alert(text: "Wallet must be synced before sending", time: 1)
            return
        }
        self.send()
    }
    
    func reset_fields() {
        self.amountTextfield.text = ""
        self.addressTextfield.text = ""
        self.feeTextfield.text = ""
        self.currentAccount!.wallet.update_delegates()
        self.parent_card?.tabSelected = 0
        self.parent_card?.updateTabView()
        self.view.endEditing(true)
    }

    func textFieldDidBeginEditing(_ textField: UITextField!) {    //delegate method
        if textField == self.addressTextfield {
            let pasteboard = UIPasteboard.general
            if let pasted = pasteboard.string {
                if let ph = pasted.to_puzzle_hash {
                    self.addressTextfield.text = pasted
                }
            }
        }
    }

    func send() {
        self.vibrate(style: .heavy)

        guard let address = addressTextfield.text else {
            self.show_auto_dismissed_alert(text: "Invalid address", time: 0.5)
            return
        }

        guard let ph = address.to_puzzle_hash else {
            self.show_auto_dismissed_alert(text: "Invalid address", time: 0.5)
            return
        }

        guard let amount = Double(amountTextfield.text!) else {
            self.show_auto_dismissed_alert(text: "Amount is missing", time: 0.5)
            return
        }

        guard let fee = Double(feeTextfield.text!) else {
            self.show_auto_dismissed_alert(text: "Invalid fee amount", time: 0.5)
            return
        }
        self.show_auto_dismissed_alert(text: "sending", time: 0.5)
        let asset = self.currentAccount!.wallet.selected_asset

        Task.init {
            self.sendButton.activityStartAnimating(activityColor: .white, backgroundColor: UIColor.appColor(.green)!)
            let result = await self.currentAccount!.wallet.send(amount: amount, asset: asset, to_address: address, fee: fee, did: self.currentAccount!.did)
            let success = result.0
            let error = result.1
            if success {
                self.sendButton.activityStopAnimating()
                self.reset_fields()
            } else {
                self.sendButton.activityStopAnimating()
                try? await Task.sleep(for: .seconds(1))
                if let error = error {
                    self.show_auto_dismissed_alert(text: error, time: 2)
                } else {
                    self.show_auto_dismissed_alert(text: "Unknown error occured, transaction not sent", time: 2)
                }
            }

        }
    }

    @IBAction func sendAction(_ sender: Any) {
        self.send()
    }

}
