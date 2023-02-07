import Foundation

class Program: NSObject, Codable {
    var program_str: String

    init(hexstr: String) {
        self.program_str = hexstr
    }

    init(disassembled: String) {
        let c_string = swift_assemble(disassembled)!
        let swift_result = String(cString: c_string)
        c_string.deallocate()
        self.program_str = swift_result
    }

    func curry(program: Program) -> Program {
        let curried = c_curry(self.program_str, program.program_str)
        let swift_result = String(cString: curried!)
        return Program(hexstr: swift_result)
    }

    func curry(args: [String]) -> Program {
        var fixed_args = "1"
        for arg in args.reversed() {
            fixed_args = "(c (q . \(arg)) \(fixed_args))"
        }
        let result = "(a (q . \(self.disassemble_program())) \(fixed_args))"
        return Program(disassembled: result)
    }

    func tree_hash() -> String {
        let treehash = treehash(self.program_str)!
        let swift_result = String(cString: treehash)
        return swift_result
    }
    
    func run(program: Program) -> String {
        let c_string = swift_run(self.program_str, program.program_str)!
        let swift_result = String(cString: c_string)
        c_string.deallocate()
        return swift_result
    }

    func disassemble_program() -> String {
        let c_string = swift_disassemble(self.program_str)!
        let swift_result = String(cString: c_string)
        c_string.deallocate()
        return swift_result
    }
    
    func first() -> Program {
        let c_string = swift_first(self.program_str)!
        let swift_result = String(cString: c_string)
        c_string.deallocate()
        return Program(hexstr: swift_result)
    }
    
    func rest() -> Program {
        let c_string = swift_rest(self.program_str)!
        let swift_result = String(cString: c_string)
        c_string.deallocate()
        return Program(hexstr: swift_result)
    }
    
    func at(path: String) -> Program {
        var result = self
        for char in path {
            if char == "f" {
                result = result.first()
            } else if char == "r" {
                result = result.rest()
            }
        }
        return result
    }

}



