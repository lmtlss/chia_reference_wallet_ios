import UIKit

class TabBarController:  UITabBarController, UITabBarControllerDelegate {

    override func viewDidLoad(){
        super.viewDidLoad()
        self.delegate = self
    }

    //MARK: UITabbar Delegate

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
      return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

    }

}
