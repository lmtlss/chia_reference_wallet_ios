import Foundation
import SceneKit
import UIKit

class NewWalletVC: UIViewController {
       
    @IBOutlet weak var textField: FormTextField!
    @IBOutlet weak var nextButton: UIButton!

    override public func viewDidLoad() {

    }
    
    @IBAction func nextButtonTouched(_ sender: Any) {
        self.performSegue(withIdentifier: "next", sender: nil)
    }
    
    @IBAction func back(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? NewMnemonic {
            if textField.text! != "" {
                vc.wallet_name = textField.text!
            }
        }
    }

}
