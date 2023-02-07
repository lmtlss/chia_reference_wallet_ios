import UIKit
import Foundation

extension Double {
    func clean() -> String {
        let formatter = NumberFormatter()
        let number = NSNumber(value: self)
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 16 //maximum digits in Double after dot (maximum precision)
        return String(formatter.string(from: number) ?? "")
    }
}

class ChiaUnits {

    static func mojo_to_xch_string(mojos: Int) -> String {
        let xch = Double(mojos) / pow(10, 12)
        return xch.clean()
    }

    static func mojo_to_cat_string(mojos: Int) -> String {
        let xch = Double(mojos) / pow(10, 3)
        return xch.clean()
    }

}
