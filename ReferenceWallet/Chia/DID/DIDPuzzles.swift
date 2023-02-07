import Foundation
import SwiftyJSON

class DIDPuzzles {
    static let P2_DID = Program(hexstr: "ff02ffff01ff04ffff04ff10ffff04ff5fff808080ffff04ffff04ff18ffff04ffff0bffff02ff2effff04ff02ffff04ff05ffff04ff2fffff04ffff02ff3effff04ff02ffff04ffff04ff05ffff04ff0bff178080ff80808080ff808080808080ffff02ff3effff04ff02ffff04ffff04ff81bfffff04ff5fff808080ff8080808080ff808080ffff02ff81bfff80808080ffff04ffff01ffffff463fff02ff0401ffff0102ffff02ffff03ff05ffff01ff02ff16ffff04ff02ffff04ff0dffff04ffff0bff1affff0bff3cff2c80ffff0bff1affff0bff1affff0bff3cff1280ff0980ffff0bff1aff0bffff0bff3cff8080808080ff8080808080ffff010b80ff0180ffff0bff1affff0bff3cff1480ffff0bff1affff0bff1affff0bff3cff1280ff0580ffff0bff1affff02ff16ffff04ff02ffff04ff07ffff04ffff0bff3cff3c80ff8080808080ffff0bff3cff8080808080ff02ffff03ffff07ff0580ffff01ff0bffff0102ffff02ff3effff04ff02ffff04ff09ff80808080ffff02ff3effff04ff02ffff04ff0dff8080808080ffff01ff0bffff0101ff058080ff0180ff018080")

    static let SINGLETON_TOP_LAYER_MOD = Program(hexstr: "ff02ffff01ff02ffff03ffff18ff2fff3480ffff01ff04ffff04ff20ffff04ff2fff808080ffff04ffff02ff3effff04ff02ffff04ff05ffff04ffff02ff2affff04ff02ffff04ff27ffff04ffff02ffff03ff77ffff01ff02ff36ffff04ff02ffff04ff09ffff04ff57ffff04ffff02ff2effff04ff02ffff04ff05ff80808080ff808080808080ffff011d80ff0180ffff04ffff02ffff03ff77ffff0181b7ffff015780ff0180ff808080808080ffff04ff77ff808080808080ffff02ff3affff04ff02ffff04ff05ffff04ffff02ff0bff5f80ffff01ff8080808080808080ffff01ff088080ff0180ffff04ffff01ffffffff4947ff0233ffff0401ff0102ffffff20ff02ffff03ff05ffff01ff02ff32ffff04ff02ffff04ff0dffff04ffff0bff3cffff0bff34ff2480ffff0bff3cffff0bff3cffff0bff34ff2c80ff0980ffff0bff3cff0bffff0bff34ff8080808080ff8080808080ffff010b80ff0180ffff02ffff03ffff22ffff09ffff0dff0580ff2280ffff09ffff0dff0b80ff2280ffff15ff17ffff0181ff8080ffff01ff0bff05ff0bff1780ffff01ff088080ff0180ff02ffff03ff0bffff01ff02ffff03ffff02ff26ffff04ff02ffff04ff13ff80808080ffff01ff02ffff03ffff20ff1780ffff01ff02ffff03ffff09ff81b3ffff01818f80ffff01ff02ff3affff04ff02ffff04ff05ffff04ff1bffff04ff34ff808080808080ffff01ff04ffff04ff23ffff04ffff02ff36ffff04ff02ffff04ff09ffff04ff53ffff04ffff02ff2effff04ff02ffff04ff05ff80808080ff808080808080ff738080ffff02ff3affff04ff02ffff04ff05ffff04ff1bffff04ff34ff8080808080808080ff0180ffff01ff088080ff0180ffff01ff04ff13ffff02ff3affff04ff02ffff04ff05ffff04ff1bffff04ff17ff8080808080808080ff0180ffff01ff02ffff03ff17ff80ffff01ff088080ff018080ff0180ffffff02ffff03ffff09ff09ff3880ffff01ff02ffff03ffff18ff2dffff010180ffff01ff0101ff8080ff0180ff8080ff0180ff0bff3cffff0bff34ff2880ffff0bff3cffff0bff3cffff0bff34ff2c80ff0580ffff0bff3cffff02ff32ffff04ff02ffff04ff07ffff04ffff0bff34ff3480ff8080808080ffff0bff34ff8080808080ffff02ffff03ffff07ff0580ffff01ff0bffff0102ffff02ff2effff04ff02ffff04ff09ff80808080ffff02ff2effff04ff02ffff04ff0dff8080808080ffff01ff0bffff0101ff058080ff0180ff02ffff03ffff21ff17ffff09ff0bff158080ffff01ff04ff30ffff04ff0bff808080ffff01ff088080ff0180ff018080")
    static let SINGLETON_TOP_LAYER_MOD_HASH = SINGLETON_TOP_LAYER_MOD.tree_hash()
    static let SINGLETON_TOP_LAYER_MOD_HASH_QUOTED = "5eddd794ba57b81c2311f001c3ddb3d17b5669857be61b3056f3f71008f096d2"

    static let LAUNCHER_PUZZLE = Program(hexstr: "ff02ffff01ff04ffff04ff04ffff04ff05ffff04ff0bff80808080ffff04ffff04ff0affff04ffff02ff0effff04ff02ffff04ffff04ff05ffff04ff0bffff04ff17ff80808080ff80808080ff808080ff808080ffff04ffff01ff33ff3cff02ffff03ffff07ff0580ffff01ff0bffff0102ffff02ff0effff04ff02ffff04ff09ff80808080ffff02ff0effff04ff02ffff04ff0dff8080808080ffff01ff0bffff0101ff058080ff0180ff018080")
    static let LAUNCHER_PUZZLE_HASH = DIDPuzzles.LAUNCHER_PUZZLE.tree_hash()
    
    static let DID_INNERPUZ_MOD = Program(hexstr: "ff02ffff01ff02ffff03ff81bfffff01ff02ff05ff82017f80ffff01ff02ffff03ffff22ffff09ffff02ff7effff04ff02ffff04ff8217ffff80808080ff0b80ffff15ff17ff808080ffff01ff04ffff04ff28ffff04ff82017fff808080ffff04ffff04ff34ffff04ff8202ffffff04ff82017fffff04ffff04ff8202ffff8080ff8080808080ffff04ffff04ff38ffff04ff822fffff808080ffff02ff26ffff04ff02ffff04ff2fffff04ff17ffff04ff8217ffffff04ff822fffffff04ff8202ffffff04ff8205ffffff04ff820bffffff01ff8080808080808080808080808080ffff01ff088080ff018080ff0180ffff04ffff01ffffffff313dff4946ffff0233ff3c04ffffff0101ff02ff02ffff03ff05ffff01ff02ff3affff04ff02ffff04ff0dffff04ffff0bff2affff0bff22ff3c80ffff0bff2affff0bff2affff0bff22ff3280ff0980ffff0bff2aff0bffff0bff22ff8080808080ff8080808080ffff010b80ff0180ffffff02ffff03ff17ffff01ff02ffff03ff82013fffff01ff04ffff04ff30ffff04ffff0bffff0bffff02ff36ffff04ff02ffff04ff05ffff04ff27ffff04ff82023fffff04ff82053fffff04ff820b3fff8080808080808080ffff02ff7effff04ff02ffff04ffff02ff2effff04ff02ffff04ff2fffff04ff5fffff04ff82017fff808080808080ff8080808080ff2f80ff808080ffff02ff26ffff04ff02ffff04ff05ffff04ff0bffff04ff37ffff04ff2fffff04ff5fffff04ff8201bfffff04ff82017fffff04ffff10ff8202ffffff010180ff808080808080808080808080ffff01ff02ff26ffff04ff02ffff04ff05ffff04ff37ffff04ff2fffff04ff5fffff04ff8201bfffff04ff82017fffff04ff8202ffff8080808080808080808080ff0180ffff01ff02ffff03ffff15ff8202ffffff11ff0bffff01018080ffff01ff04ffff04ff20ffff04ff82017fffff04ff5fff80808080ff8080ffff01ff088080ff018080ff0180ff0bff17ffff02ff5effff04ff02ffff04ff09ffff04ff2fffff04ffff02ff7effff04ff02ffff04ffff04ff09ffff04ff0bff1d8080ff80808080ff808080808080ff5f80ffff04ffff0101ffff04ffff04ff2cffff04ff05ff808080ffff04ffff04ff20ffff04ff17ffff04ff0bff80808080ff80808080ffff0bff2affff0bff22ff2480ffff0bff2affff0bff2affff0bff22ff3280ff0580ffff0bff2affff02ff3affff04ff02ffff04ff07ffff04ffff0bff22ff2280ff8080808080ffff0bff22ff8080808080ff02ffff03ffff07ff0580ffff01ff0bffff0102ffff02ff7effff04ff02ffff04ff09ff80808080ffff02ff7effff04ff02ffff04ff0dff8080808080ffff01ff0bffff0101ff058080ff0180ff018080")
    static let DID_INNERPUZ_MOD_HASH = DID_INNERPUZ_MOD.tree_hash()
    static let INTERMEDIATE_LAUNCHER_MOD = Program(hexstr: "ff02ffff01ff04ffff04ff04ffff04ff05ffff01ff01808080ffff04ffff04ff06ffff04ffff0bff0bff1780ff808080ff808080ffff04ffff01ff333cff018080")
    
    
    static func create_fullpuz(did_puzzle: Program, launcher_id: String) -> Program {
        let singleton_struct = "(\(SINGLETON_TOP_LAYER_MOD_HASH.ox) . (\(launcher_id.ox) . \(LAUNCHER_PUZZLE_HASH.ox)))"
        return SINGLETON_TOP_LAYER_MOD.curry(args: [singleton_struct, did_puzzle.disassemble_program()])
    }

    static func metadata_to_program(metadata: [String:JSON]) -> Program {
        var program_str = "("
        for (key, value) in metadata {
            program_str.append("(\(key) . \(value.stringValue))")
        }
        
        program_str.append(")")
        return Program(disassembled: program_str)
    }
    
    static func create_inner_puz(
        p2_puzzle: Program,
        recovery_list: [String],
        num_of_backup_ids_needed: Int,
        launcher_id: String,
        metadata: Program,
        recovery_list_hash: String
    ) -> Program {
        let singleton_struct_str = "(\(SINGLETON_TOP_LAYER_MOD_HASH.ox) . (\(launcher_id.ox) . \(LAUNCHER_PUZZLE_HASH.ox)))"
        var curry_list: [String] = []
        curry_list.append(p2_puzzle.disassemble_program())
        curry_list.append(recovery_list_hash.ox)
        var int_bytes = int_to_bytes_swift(value: num_of_backup_ids_needed)
        if int_bytes == Data() {
            curry_list.append("()")
        } else {
            curry_list.append(int_bytes.hex)
        }
        curry_list.append(singleton_struct_str)
        curry_list.append(metadata.disassemble_program())
        return DID_INNERPUZ_MOD.curry(args: curry_list)
    }

    static func create_p2_did(
        launcher_id: String
    ) -> Program {
        var curry_list: [String] = []
        curry_list.append(SINGLETON_TOP_LAYER_MOD_HASH.ox)
        curry_list.append(launcher_id.ox)
        curry_list.append(LAUNCHER_PUZZLE_HASH.ox)
        return P2_DID.curry(args: curry_list)
    }
    
    static func create_fullpuz(inner_puz: Program, launcher_id: String) -> Program {
        let singleton_struct_str = "(\(SINGLETON_TOP_LAYER_MOD_HASH.ox) . (\(launcher_id.ox) . \(LAUNCHER_PUZZLE_HASH.ox)))"
        var curry_list: [String] = []
        curry_list.append(singleton_struct_str)
        curry_list.append(inner_puz.disassemble_program())
        return SINGLETON_TOP_LAYER_MOD.curry(args: curry_list)
    }
    
    static func get_innerpuzzle_from_puzzle(puzzle: Program) -> Program? {
        print(puzzle.disassemble_program())
        // (2 (1 . self) rest)
        let singleton = puzzle.rest().first()
        if abs(singleton.program_str.count - SINGLETON_TOP_LAYER_MOD.program_str.count) > 10 {
            print("puzzle \(puzzle.disassemble_program())")
            print("singleton \(singleton.disassemble_program())")
            print("SINGLETON_TOP_LAYER_MOD \(SINGLETON_TOP_LAYER_MOD.disassemble_program())")

            return nil
        }
        let args = puzzle.rest().rest()
        var inner = args.first().rest().rest().first().rest().first().disassemble_program()
        inner = String(inner.dropFirst(4))
        inner = "(a\(inner)"
        let inner_puzzle = Program(disassembled: inner)
        return inner_puzzle
    }
    
    static func program_as_list(program: Program) -> [Program] {
        var current = program
        var result: [Program] = []
        if current.disassemble_program() ==  "()" {
            return result
        }
        while true {
            var rest = current.rest()
            current = current.first()
            result.append(current)
            current = rest
            if current.disassemble_program() ==  "()" {
                return result
            }
        }
        
    }
    
    static func clean_str(_ txt: String) -> String {
        var res = txt
        res = String(res.dropFirst(1))
        res = String(res.dropLast(1))
        return res
    }

    static func json_from_metadata(metadata: String) -> JSON {
        var dict: [String:String] = [:]
        let metadata_program = Program(hexstr: metadata.noox)
        let program_list = program_as_list(program: metadata_program)
        print(program_list)
        print(metadata_program.disassemble_program())
        for program in program_list {
            let first = String(program.first().program_str.dropFirst(2))
            let key = clean_str(program.first().disassemble_program())
            let rest = clean_str(program.rest().disassemble_program())
            
//
//            let key = hexStringtoAscii(first)
//            let rest = String(program.rest().program_str.dropFirst(2))
            
            if let hexdata = rest.hex {
                dict[key] = rest.ox
            } else {
                dict[key] = rest
            }
        }
        if metadata.count > 4 {
            print(program_list)
            print(metadata_program.disassemble_program())
        }
        return JSON(dict)
    }

    static func hexStringtoAscii(_ hexString : String) -> String {
        let pattern = "(0x)?([0-9a-f]{2})"
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let nsString = hexString as NSString
        let matches = regex.matches(in: hexString, options: [], range: NSMakeRange(0, nsString.length))
        let characters = matches.map {
            Character(UnicodeScalar(UInt32(nsString.substring(with: $0.range(at: 2)), radix: 16)!)!)
        }
        return String(characters)
    }

}
