//
//  PortfolioStock.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/14/20.
//

import Foundation

//A stock class used for saving the info about user portfolio
//Each stock has a symbol, a name (or description), and quantity
public class PortfolioStock: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool = true
    
    public var symbol: String = ""
    public var name: String = ""
    public var quantity: Int = 0
    
    enum Key:String {
        case symbol = "symbol"
        case name = "name"
        case quantity = "quantity"
    }
    
    init (symbol: String, name: String, quantity: Int) {
        self.symbol = symbol
        self.name = name
        self.quantity = quantity
    }
    
    public override init(){
        super.init()
    }
    
    //encode a stock object
    public func encode(with aCoder: NSCoder){
        aCoder.encode(symbol, forKey: Key.symbol.rawValue)
        aCoder.encode(name, forKey: Key.name.rawValue)
        aCoder.encode(quantity, forKey: Key.quantity.rawValue)
    }
    
    //decode a stock object
    public required convenience init?(coder aDecoder: NSCoder){
        let mySymbol = aDecoder.decodeObject(forKey: Key.symbol.rawValue) as! String
        let myName = aDecoder.decodeObject(forKey: Key.name.rawValue) as! String
        let myQuantity = aDecoder.decodeInt32(forKey: Key.quantity.rawValue)
        
        self.init(symbol: mySymbol, name: myName, quantity: Int(myQuantity))
    }
}
