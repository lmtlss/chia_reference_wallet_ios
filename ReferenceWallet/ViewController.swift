import UIKit
import SwiftyJSON
import EffectsLibrary
import SwiftUI

class ViewController: UIViewController, UITextFieldDelegate {
    var firework: UIViewController? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func vibrate(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred(intensity: 1.0)
    }
    
    func show_auto_dismissed_alert(text: String, time: Double) {
        let alert = UIAlertController(title: "", message: text, preferredStyle: .alert)
        self.present(alert, animated: true, completion: {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + time) {
                alert.dismiss(animated: true)
            }
        })
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    func remove_firework(){
        UIView.animate(withDuration: 1.0, animations: {
            self.firework?.view.alpha = 0.0
        }, completion: { finished in
            self.firework?.view.removeFromSuperview()
        })
    }
    
    func insert_firework(duration: Double=5) {
        let fireworks = ConfettiView(
            config: ConfettiConfig(
                content: [
                    .emoji("🚀", 0.7),
                    .emoji("🌱", 0.6),
                    .emoji("🌱", 0.7),
                ],
                intensity: .medium,
                lifetime: .long,
                initialVelocity: .medium,
                fadeOut: .slow
            )).edgesIgnoringSafeArea(.all)
        
        let childView = UIHostingController(rootView:fireworks)
        childView.view.frame = self.view.frame
        childView.view.backgroundColor = .clear
        if let window = UIApplication.shared.keyWindow {
            let overlayView = UIView()
            overlayView.frame = window.frame
            overlayView.backgroundColor = .red
            window.addSubview(childView.view)
        }
        
        //self.view.addSubview()
        self.firework = childView
        
        addChild(childView)
        childView.didMove(toParent: self)
        Task.init {
            try? await Task.sleep(for: .seconds(duration))
            DispatchQueue.main.async {
                self.remove_firework()
            }
        }
    }
    
}

