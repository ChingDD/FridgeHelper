//
//  Logger.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2024/5/21.
//

import Foundation

func print(_ message: Any..., fileName: String = #file, functionName: String = #function, lineNumber: UInt = #line) {
    
    var messageString = ""
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    messageString = messageString + "[" + formatter.string(from: Date()) + "]" + " | "
    messageString = messageString + message.map({"\($0)"}).joined(separator: " ") + " | "
    
    let fileName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
    messageString = messageString + fileName + " -> "
    messageString = messageString + functionName + ": \(lineNumber)"
    
    print("@@@" + messageString)
}
