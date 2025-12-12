//
//  MovieTransferable.swift
//  SwingDeep
//
//  Created by Nozo on 2025/11/26.
//

import SwiftUI
import UniformTypeIdentifiers // ★ここを追加

struct MovieTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let id = UUID().uuidString
            let copy = URL.documentsDirectory.appending(path: "importedVideo_\(id).mov")
            
            if FileManager.default.fileExists(atPath: copy.path()) {
                try FileManager.default.removeItem(at: copy)
            }
            
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}
