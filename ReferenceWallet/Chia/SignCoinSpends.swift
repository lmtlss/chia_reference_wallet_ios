import Foundation


func conditions_dict_for_solution(puzzle: Program, solution: Program) -> [[String:String]] {
    var result = puzzle.run(program: solution)
    result = result.replacingOccurrences(of: "(", with: "", options: NSString.CompareOptions.literal, range: nil)
    result = result.replacingOccurrences(of: ")", with: "", options: NSString.CompareOptions.literal, range: nil)
    let components = result.components(separatedBy: " ")
    var list: [[String:String]] = []
    for index in 0...components.count-1 {
        let current = components[index]
        if current == "50" {
            var condition: [String:String] = [:]
            let pubkey = components[index+1]
            let msg = components[index+2]
            condition = ["pubkey": pubkey, "message": msg]
            list.append(condition)
        }
    }

    return list
}

func addition_conditions(puzzle: Program, solution: Program) -> [[String:Any]] {
    var result = puzzle.run(program: solution)
    result = result.replacingOccurrences(of: "(", with: "", options: NSString.CompareOptions.literal, range: nil)
    result = result.replacingOccurrences(of: ")", with: "", options: NSString.CompareOptions.literal, range: nil)
    let components = result.components(separatedBy: " ")
    var list: [[String:Any]] = []
    for index in 0...components.count-1 {
        let current = components[index]
        if current == "51" {
            var condition: [String:Any] = [:]
            let pubkey = components[index+1]
            var amount = 0
            var msg = components[index+2]
            if msg.starts(with: "0x") {
                msg = msg.replacingOccurrences(of: "0x", with: "")
                amount = Int(msg, radix: 16)!
            } else {
                amount = Int(msg, radix: 10)!
            }

            condition = ["puzzle_hash": pubkey, "amount": amount]
            list.append(condition)
        }
    }

    return list
}
