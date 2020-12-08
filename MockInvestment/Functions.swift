//
//  Functions.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/4/20.
//

//This is the file with some general-purpose global function that can be called from any ViewContoller

import Foundation

//async function that executes some code after the specified delay
func afterDelay(_ seconds: Double, run: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: run)
}

//returns the path to the app's local database directory
let applicationDocumentsDirectory: URL = {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}()
