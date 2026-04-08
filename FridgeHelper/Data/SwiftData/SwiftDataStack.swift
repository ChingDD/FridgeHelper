//
//  SwiftDataStack.swift
//  FridgeHelper
//
//  Created by Aco on 2026/4/8.
//

import Foundation
import SwiftData

class SwiftDataStack {
     let container: ModelContainer

     init(inMemory: Bool = false) throws {
         let config = ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
         container = try ModelContainer(for: Item.self, configurations: config)
     }

    @MainActor
     var context: ModelContext {
         container.mainContext
     }
 }
