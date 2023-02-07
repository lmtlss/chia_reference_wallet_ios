import Foundation
import UIKit

class SafeDict<T: Hashable, V>{
    var threadUnsafeDict = [T: V]()
    private let dispatchQueue = DispatchQueue(label: "SafeDict")

    func getValue(key: T) -> V? {
        var result: V?
        dispatchQueue.sync {
            result = threadUnsafeDict[key]
        }
        return result
    }

    func setObject(key: T, value: V?) {
        dispatchQueue.async(flags: .barrier) {
            self.threadUnsafeDict[key] = value
        }
    }

    subscript (key: T) -> V? {
          // the getter is required
       get {
           return self.getValue(key: key)
       }
       set(newValue) {
           self.setObject(key: key, value: newValue)
       }
    }
    
}

class SafeSet<T: Hashable>{
    private var threadUnsafeSet: Set<T> = Set()
    private let dispatchQueue = DispatchQueue(label: "SafeSet")

    func contains(_ key: T) -> Bool {
        var result: Bool = false
        dispatchQueue.sync {
            result = threadUnsafeSet.contains(key)
        }
        return result
    }

    func insert(_ newMember: T) {
        dispatchQueue.async(flags: .barrier) {
            self.threadUnsafeSet.insert(newMember)
        }
    }

    func insert(_ newMembers: [T]) {
        dispatchQueue.async(flags: .barrier) {
            self.threadUnsafeSet.insert(newMembers as! T)
        }
    }
    
}
