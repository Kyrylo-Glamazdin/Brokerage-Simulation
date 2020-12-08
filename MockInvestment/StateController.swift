//
//  StateController.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/10/20.
//

import Foundation

//This class is used for passing data between tabs
class StateController {
    //available stocks are fetched from the API in InvestmentsViewController and passed to SearchStocksViewController using this class given to both in SceneDelegate
    var availableStocks: [AvailableStock] = []
    var updateIsRequired: Bool = false
}
