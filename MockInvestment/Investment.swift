//
//  Investment.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/2/20.
//

import Foundation

//Investment is the class used for displaying each individual stock present in user's portfolio in the tableView on InvestmentsViewController
class Investment{
    var symbol = ""
    var percentageChange = ""
    var shares = 0
    var percentageChangeVal: Double = 0
}
