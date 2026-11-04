//
//  AllMightTests.swift
//  AllMightTests
//
//  Created by KUN on 2026/11/4.
//

import Foundation
import Testing
@testable import AllMight

struct AllMightTests {

    @Test("App 佔位：FileStore 能取得 Videos 目錄")
    func fileStoreProvidesVideosDirectory() throws {
        let store = FileStore()
        let dir = try store.directory(for: .videos)
        #expect(dir.lastPathComponent == "Videos")
    }

}
