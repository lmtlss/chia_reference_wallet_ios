import Foundation
import SceneKit
import UIKit

class SendNFTVC: ViewController, MTSlideToOpenDelegate {
    var currentWallet: Wallet? = nil
    @IBOutlet weak var feeTextfield: FormTextField!
    @IBOutlet weak var addressTextfield: FormTextField!
    @IBOutlet weak var sendButton: UIButton!
    var nft_item: NFTItem? = nil

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

    func set_wallet(wallet: Wallet) {
        self.currentWallet = wallet
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

    @IBAction func back(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    override func viewDidLoad() {
        self.hideKeyboard()
        self.feeTextfield.delegate = self
        self.addressTextfield.delegate = self
        self.addressTextfield.text = ""
        self.feeTextfield.text = ""
        self.view.addSubview(slideToOpen)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.slideToOpen.frame = sendButton.frame
    }
    
    override func viewWillAppear(_ animated: Bool) {
        sendButton.isHidden = true
        self.slideToOpen.frame = sendButton.frame
    }
    
    func mtSlideToOpenDelegateDidFinish(_ sender: MTSlideToOpenView) {
        
        self.send()
        sender.resetStateWithAnimation(false)
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

        guard let fee = Double(feeTextfield.text!) else {
            self.show_auto_dismissed_alert(text: "Invalid fee amount", time: 0.5)
            return
        }
        
        self.nft_item!.wallet.send_nft(nft: self.nft_item!.nft, to_address: address, fee: fee)
        self.navigationController?.popToRootViewController(animated: true)
    }

    @IBAction func sendAction(_ sender: Any) {
        self.send()
    }

}
