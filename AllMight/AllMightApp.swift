//
//  AllMightApp.swift
//  AllMight
//
//  Created by KUN on 2026/11/3.
//

import SwiftData
import SwiftUI

@main
struct AllMightApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: WorkoutSet.self)
        } catch {
            fatalError("無法建立 SwiftData ModelContainer：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
