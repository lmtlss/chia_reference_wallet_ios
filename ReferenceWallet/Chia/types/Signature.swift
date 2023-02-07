import Foundation

class Signature: NSObject {
    let sig: String
    
    init(hexstr: String) {
        self.sig = hexstr
    }

    func data() -> Data {
        return self.sig.hex!
    }

    func aggregate(signature: Signature) -> Signature {
        let c_string = swift_aggregate(self.sig, signature.sig)!
        let swift_result = String(cString: c_string)
        c_string.deallocate()
        return Signature(hexstr: swift_result)
    }

}
