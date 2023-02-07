import Foundation

func directory_path() -> URL {
    let documentsURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    return documentsURL
}

func path_for(name: String) -> URL {
    let documentsURL = directory_path()
    return documentsURL.appendingPathComponent("\(name)")
}

func path_for_db(pubkey: String) -> URL {
    return path_for(name: "db\(pubkey).sqlite")
}
