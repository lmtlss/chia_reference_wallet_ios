import Foundation
import MKRingProgressView
import SceneKit
import UIKit


class DisplayNFTVC: UIViewController, SCNSceneRendererDelegate{
    @IBOutlet weak var percentageLabel: UILabel!
    @IBOutlet weak var progressRing: RingProgressView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var sceneView: SCNView!

    private var _containerNode = SCNNode()
    private var _pointCloudNode: SCNNode?
    private var _initialPointOfView = SCNMatrix4Identity
    var loaded = false
    var url: String? = nil
    var nft_item: NFTItem? = nil
    var copycat: Bool = true

    private var _terrain: RBTerrain?

    
    private func addTerrain() {
        // Create terrain
        let width: Float = 64.0
        _terrain = RBTerrain(width: Int(width), length: Int(width), scale: 128)
        _terrain!.create(withColor: UIColor.appColor(.disabledButton)!)
        _terrain!.position = SCNVector3Make(-(width-1)/2.0, 0, -(width-1)/2.0)
        _terrain!.geometry?.firstMaterial?.fillMode = .lines

        self._containerNode.addChildNode(_terrain!)
    }

    @IBOutlet weak var sendButton: UIButton!
    override func viewDidLoad() {
        _containerNode.name = "Container"
        sceneView.scene?.rootNode.addChildNode(_containerNode)
        sceneView.delegate = self
        _initialPointOfView = sceneView.pointOfView!.transform
        for child in _containerNode.childNodes {
            child.removeFromParentNode()
        }
        _pointCloudNode?.name = "Point cloud"
        self.load_file()
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true

    }

    @IBAction func back(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        if nft_item == nil {
            self.sendButton.isHidden = true
        }

        sceneView.pointOfView!.transform = _initialPointOfView
    }

    override public func viewDidLayoutSubviews() {
        sceneView.frame = view.bounds
    }

    func load_file() {
        if loaded  {
            return
        }
        if let objurl = self.url {
            if objurl != "" {
                loaded = true
                OBJCacheManager.shared.get_object(url: objurl).then { response in
                    if let data = response as! Data? {
                        if self.copycat {
                            let tmpURL = FileManager.default.temporaryDirectory
                            let uri = URL(string: "file.usdz", relativeTo: tmpURL)!
                            try data.write(to: uri)
                            let referenceNode = SCNReferenceNode(url: uri)!
                            referenceNode.load()
                            var min = referenceNode.boundingBox.min.y
                            if min < 0 {
                                referenceNode.position.y = referenceNode.position.y - min
                            } else {
                                referenceNode.position.y = referenceNode.position.y + min
                            }

                            let minx = referenceNode.boundingBox.min.x
                            let maxx = referenceNode.boundingBox.max.x
                            var maxy = referenceNode.boundingBox.max.y

                            if minx < 0 {
                                referenceNode.position.x = referenceNode.position.x - (minx + maxx) / 2
                            } else {
                                referenceNode.position.x = referenceNode.position.x + (minx + maxx) / 2
                            }
                            var minz = referenceNode.boundingBox.min.z
                            let maxz = referenceNode.boundingBox.max.z

                            if minz < 0 {
                                referenceNode.position.z = referenceNode.position.z - (minz + maxz) / 2
                            } else {
                                referenceNode.position.z = referenceNode.position.z + (minz + maxz) / 2
                            }
                            let height = maxy - min
                            if let current = self.sceneView.defaultCameraController.pointOfView?.position  {
                                var mod = current
                                mod.z = height * 4
                                mod.y = mod.z / 2
                                self.sceneView.defaultCameraController.pointOfView?.position = mod
                                print(mod)
                            }
                            self.addTerrain()
                            self._containerNode.addChildNode(referenceNode)
                        } else {
                            let tmpURL = FileManager.default.temporaryDirectory
                            let uri = URL(string: "file.png", relativeTo: tmpURL)!
                            try data.write(to: uri)
                            let box = SCNBox(width: 1, height: 1, length: 0.005, chamferRadius: 0)
                            let material = SCNMaterial()
                            material.diffuse.contents = UIImage(data: data)
                            box.materials = [material]

                            let boxNode = SCNNode(geometry: box)
                            boxNode.opacity = 1.0
                            boxNode.position = SCNVector3(0,0.5, 0)
                            self.addTerrain()

                            self._containerNode.addChildNode(boxNode)
                        }

                    }
                }
            }
        }
    }

    @IBAction func sendButton(_ sender: Any) {
        self.performSegue(withIdentifier: "send", sender: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? SendNFTVC {
            vc.nft_item = self.nft_item!
        }
    }

    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let currentFOV = sceneView.pointOfView!.camera!.fieldOfView
        let pointSize = 20.2 - 0.078 * currentFOV

        if let pointsElement = _pointCloudNode?.geometry?.elements.first {
            pointsElement.pointSize = pointSize
            pointsElement.minimumPointScreenSpaceRadius = pointSize
            pointsElement.maximumPointScreenSpaceRadius = pointSize
        }
    }
    
}
