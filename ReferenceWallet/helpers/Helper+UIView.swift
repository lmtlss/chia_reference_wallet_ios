import Foundation
import UIKit

extension UIView {
    
    @IBInspectable var cornerRadiusV: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }
    
    @IBInspectable var borderWidthV: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }
    
    @IBInspectable var borderColorV: UIColor? {
        get {
            return UIColor(cgColor: layer.borderColor!)
        }
        set {
            layer.borderColor = newValue?.cgColor
        }
    }
    
}


@IBDesignable
class FormTextField: UITextField {

    @IBInspectable var inset: CGFloat = 0

    override open func textRect(forBounds bounds: CGRect) -> CGRect {
        let padding = UIEdgeInsets(top: 0, left: self.inset, bottom: 0, right: 0)
        return bounds.inset(by: padding)
    }

    override open func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        let padding = UIEdgeInsets(top: 0, left: self.inset, bottom: 0, right: 0)
        return bounds.inset(by: padding)
    }

    override open func editingRect(forBounds bounds: CGRect) -> CGRect {
        let padding = UIEdgeInsets(top: 0, left: self.inset, bottom: 0, right: 0)
        return bounds.inset(by: padding)
    }
}

extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font : font], context: nil)

        return ceil(boundingBox.height)
    }

    func width(withConstrainedHeight height: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font : font], context: nil)

        return ceil(boundingBox.width)
    }
    /// Create `Data` from hexadecimal string representation
    ///
    /// This creates a `Data` object from hex string. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.
    
    var hex: Data? {
        var data = Data(capacity: count / 2)

    
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        var str = self
        if str.starts(with: "0x") {
            str = str.replacingOccurrences(of: "0x", with: "")
        }
        regex.enumerateMatches(in: str, range: NSRange(startIndex..., in: str)) { match, _, _ in
            let byteString = (str as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            if (byteString) != "0x" {
                data.append(num)
            }
        }
        if data.count < str.count / 2 {
            return nil
        }
        guard data.count > 0 else { return nil }
        
        return data
    }



    var ox: String {

        if self.starts(with: "0x") {
            return self
        }

        return "0x" + self
    }

    var noox: String {

        if self.starts(with: "0x") {
            return String(self.dropFirst(2))
        }

        return self
    }
}

extension Data {
    var hexString: String {
        let hexString = map { String(format: "%02.2hhx", $0) }.joined()
        return hexString
    }
}

extension UserDefaults {
    func reset() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
    }
}

public protocol AnyEncoder {
    /// Encode a given value into binary data.
    func encode<T: Encodable>(_ value: T) throws -> Data
}

extension JSONEncoder: AnyEncoder {}

#if canImport(ObjectiveC) || swift(>=5.1)
extension PropertyListEncoder: AnyEncoder {}
#endif

public extension Encodable {
    /// Encode this value, optionally using a specific encoder.
    /// If no explicit encoder is passed, then the value is encoded into JSON.
    func encoded(using encoder: AnyEncoder = JSONEncoder()) throws -> Data {
        return try encoder.encode(self)
    }
}

public extension Encoder {
    /// Encode a singular value into this encoder.
    func encodeSingleValue<T: Encodable>(_ value: T) throws {
        var container = singleValueContainer()
        try container.encode(value)
    }

    /// Encode a value for a given key, specified as a string.
    func encode<T: Encodable>(_ value: T, for key: String) throws {
        try encode(value, for: AnyCodingKey(key))
    }

    /// Encode a value for a given key, specified as a `CodingKey`.
    func encode<T: Encodable, K: CodingKey>(_ value: T, for key: K) throws {
        var container = self.container(keyedBy: K.self)
        try container.encode(value, forKey: key)
    }

    /// Encode a date for a given key (specified as a string), using a specific formatter.
    /// To encode a date without using a specific formatter, simply encode it like any other value.
    func encode<F: AnyDateFormatter>(_ date: Date, for key: String, using formatter: F) throws {
        try encode(date, for: AnyCodingKey(key), using: formatter)
    }

    /// Encode a date for a given key (specified using a `CodingKey`), using a specific formatter.
    /// To encode a date without using a specific formatter, simply encode it like any other value.
    func encode<K: CodingKey, F: AnyDateFormatter>(_ date: Date, for key: K, using formatter: F) throws {
        let string = formatter.string(from: date)
        try encode(string, for: key)
    }
}

// MARK: - Decoding

/// Protocol acting as a common API for all types of decoders,
/// such as `JSONDecoder` and `PropertyListDecoder`.
public protocol AnyDecoder {
    /// Decode a value of a given type from binary data.
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

extension JSONDecoder: AnyDecoder {}

#if canImport(ObjectiveC) || swift(>=5.1)
extension PropertyListDecoder: AnyDecoder {}
#endif

public extension Data {
    /// Decode this data into a value, optionally using a specific decoder.
    /// If no explicit encoder is passed, then the data is decoded as JSON.
    func decoded<T: Decodable>(as type: T.Type = T.self,
                               using decoder: AnyDecoder = JSONDecoder()) throws -> T {
        return try decoder.decode(T.self, from: self)
    }
}

public extension Decoder {
    /// Decode a singular value from the underlying data.
    func decodeSingleValue<T: Decodable>(as type: T.Type = T.self) throws -> T {
        let container = try singleValueContainer()
        return try container.decode(type)
    }

    /// Decode a value for a given key, specified as a string.
    func decode<T: Decodable>(_ key: String, as type: T.Type = T.self) throws -> T {
        return try decode(AnyCodingKey(key), as: type)
    }

    /// Decode a value for a given key, specified as a `CodingKey`.
    func decode<T: Decodable, K: CodingKey>(_ key: K, as type: T.Type = T.self) throws -> T {
        let container = try self.container(keyedBy: K.self)
        return try container.decode(type, forKey: key)
    }

    /// Decode an optional value for a given key, specified as a string. Throws an error if the
    /// specified key exists but is not able to be decoded as the inferred type.
    func decodeIfPresent<T: Decodable>(_ key: String, as type: T.Type = T.self) throws -> T? {
        return try decodeIfPresent(AnyCodingKey(key), as: type)
    }

    /// Decode an optional value for a given key, specified as a `CodingKey`. Throws an error if the
    /// specified key exists but is not able to be decoded as the inferred type.
    func decodeIfPresent<T: Decodable, K: CodingKey>(_ key: K, as type: T.Type = T.self) throws -> T? {
        let container = try self.container(keyedBy: K.self)
        return try container.decodeIfPresent(type, forKey: key)
    }

    /// Decode a date from a string for a given key (specified as a string), using a
    /// specific formatter. To decode a date using the decoder's default settings,
    /// simply decode it like any other value instead of using this method.
    func decode<F: AnyDateFormatter>(_ key: String, using formatter: F) throws -> Date {
        return try decode(AnyCodingKey(key), using: formatter)
    }

    /// Decode a date from a string for a given key (specified as a `CodingKey`), using
    /// a specific formatter. To decode a date using the decoder's default settings,
    /// simply decode it like any other value instead of using this method.
    func decode<K: CodingKey, F: AnyDateFormatter>(_ key: K, using formatter: F) throws -> Date {
        let container = try self.container(keyedBy: K.self)
        let rawString = try container.decode(String.self, forKey: key)

        guard let date = formatter.date(from: rawString) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Unable to format date string"
            )
        }

        return date
    }
}

// MARK: - Date formatters

/// Protocol acting as a common API for all types of date formatters,
/// such as `DateFormatter` and `ISO8601DateFormatter`.
public protocol AnyDateFormatter {
    /// Format a string into a date
    func date(from string: String) -> Date?
    /// Format a date into a string
    func string(from date: Date) -> String
}

extension DateFormatter: AnyDateFormatter {}

@available(iOS 10.0, macOS 10.12, tvOS 10.0, *)
extension ISO8601DateFormatter: AnyDateFormatter {}

// MARK: - Private supporting types

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) {
        stringValue = string
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
}



enum AssetsColor {
   case green
   case textPlaceholder
   case disabledButton
}
// ColorTextFieldPlaceholder
extension UIColor {

    static func appColor(_ name: AssetsColor) -> UIColor? {
        switch name {
        case .green:
            return UIColor(named: "ColorGreenMain")

        case .textPlaceholder:
            return UIColor(named: "ColorTextFieldPlaceholder")

        case .disabledButton:
            return UIColor(named: "ColorTextFieldPlaceholder")

        }
    }
}


extension UIView {
    func applyBlurEffect() {
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.layer.opacity = 0.9
        blurEffectView.frame = bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurEffectView)
    }
}

extension UIView {
    
    /// Remove UIBlurEffect from UIView
    func removeBlurEffect() {
        let blurredEffectViews = self.subviews.filter{$0 is UIVisualEffectView}
        blurredEffectViews.forEach{ blurView in
            blurView.removeFromSuperview()
        }
    }
}
