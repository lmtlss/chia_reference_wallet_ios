import Foundation
import UIKit

class CatalogItem : UICollectionViewCell {
    
    @IBOutlet weak var itemImage: UIImageView!
    
    @IBOutlet weak var did_label: UILabel!
    @IBOutlet weak var titleTop: NSLayoutConstraint!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
}
