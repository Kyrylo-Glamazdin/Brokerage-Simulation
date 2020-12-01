//
//  IndividualStockViewController.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/14/20.
//

import Foundation
import UIKit
import CoreData

class IndividualStockViewController: UIViewController {
    
    @IBOutlet weak var stockSymbolLabel: UILabel!
    @IBOutlet weak var stockNameLabel: UILabel!
    @IBOutlet weak var stockPriceLabel: UILabel!
    @IBOutlet weak var stockPriceChangeLabel: UILabel!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var userSharesLabel: UILabel!
    @IBOutlet weak var userBalanceLabel: UILabel!
    @IBOutlet weak var sellSharesError: UILabel!
    @IBOutlet weak var buyButton: UIButton!
    @IBOutlet weak var sellButton: UIButton!
    @IBOutlet weak var intervalLabel: UILabel!
    
    var userAvailableBalances = [UserAvailableBalance]()
    var userPortfolios = [UserPortfolioState]()
    var stockObj: AvailableStock!
    var dataTask: URLSessionDataTask?
    var managedObjectContext: NSManagedObjectContext!
    var currentStockPrice: StockPriceObj?
    var canPerformSellSegue: Bool = true
    var dailyChange: Double = 0
    var weeklyChange: Double = 0
    var monthlyChange: Double = 0
    var canToggleSegmentedControl: Bool = false
    
    let dispatchGroup = DispatchGroup()
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateDataAndLabels), name: Notification.Name(rawValue: "StockTransactionCompleted"), object: nil)
        stockSymbolLabel.text! = stockObj.stockSymbol
        stockNameLabel.text! = stockObj.stockDescription
        buyButton.setTitle(String("Buy " + stockObj.stockSymbol), for: .normal)
        sellButton.setTitle(String("Sell " + stockObj.stockSymbol), for: .normal)
        updateDataAndLabels()
        
        dispatchGroup.notify(queue: .main){
            self.canToggleSegmentedControl = true
        }
        
    }
    
    @IBAction func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        if canToggleSegmentedControl {
            let segmentedControlValue = sender.selectedSegmentIndex
            if segmentedControlValue == 0 {
                if let curPrice = self.currentStockPrice?.currentPrice {
                    let dailyPriceChange = curPrice - self.currentStockPrice!.previousClose
                    let dailyPercentageChange = (dailyPriceChange/self.currentStockPrice!.previousClose) * 100
                    if dailyPriceChange < 0 {
                        self.stockPriceChangeLabel.text! = String(format: "%.2f", dailyPercentageChange) + "% ($" + String(format: "%.2f", dailyPriceChange * (-1)) + ")"
                        self.stockPriceChangeLabel.textColor = UIColor.red
                    }
                    else {
                        self.stockPriceChangeLabel.text! = "+" + String(format: "%.2f", dailyPercentageChange) + "% ($" + String(format: "%.2f", dailyPriceChange) + ")"
                        self.stockPriceChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                    }
                }
                else{
                    self.stockPriceChangeLabel.text! = "0% ($0.00)"
                    self.stockPriceChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                }
                intervalLabel.text! = "(Today)"
            }
            else if segmentedControlValue == 1 {
                if let curPrice = self.currentStockPrice?.currentPrice {
                    let weeklyPercentageChange = (weeklyChange / curPrice) * 100
                    if weeklyPercentageChange < 0 {
                        self.stockPriceChangeLabel.text! = String(format: "%.2f", weeklyPercentageChange) + "% ($" + String(format: "%.2f", weeklyChange * (-1)) + ")"
                        self.stockPriceChangeLabel.textColor = UIColor.red
                    }
                    else {
                        self.stockPriceChangeLabel.text! = "+" + String(format: "%.2f", weeklyPercentageChange) + "% ($" + String(format: "%.2f", weeklyChange) + ")"
                        self.stockPriceChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                    }
                }
                else {
                    self.stockPriceChangeLabel.text! = "0% ($0.00)"
                    self.stockPriceChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                }
                intervalLabel.text! = "(Week)"
            }
            else if segmentedControlValue == 2 {
                if let curPrice = self.currentStockPrice?.currentPrice {
                    let monthlyPercentageChange = (monthlyChange / curPrice) * 100
                    if monthlyPercentageChange < 0 {
                        self.stockPriceChangeLabel.text! = String(format: "%.2f", monthlyPercentageChange) + "% ($" + String(format: "%.2f", monthlyChange * (-1)) + ")"
                        self.stockPriceChangeLabel.textColor = UIColor.red
                    }
                    else {
                        self.stockPriceChangeLabel.text! = "+" + String(format: "%.2f", monthlyPercentageChange) + "% ($" + String(format: "%.2f", monthlyChange) + ")"
                        self.stockPriceChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                    }
                }
                else {
                    self.stockPriceChangeLabel.text! = "0% ($0.00)"
                    self.stockPriceChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                }
                intervalLabel.text! = "(Month)"
            }
        }
    }
    
    @objc func updateDataAndLabels() {
        getStockPrice()
        performDataFetch()
        callPercentageFetches()
    }
    
    func performDataFetch(){
        let fetchRequest1 = NSFetchRequest<UserAvailableBalance>()
        let fetchRequest2 = NSFetchRequest<UserPortfolioState>()

        let entity1 = UserAvailableBalance.entity()
        fetchRequest1.entity = entity1
        let entity2 = UserPortfolioState.entity()
        fetchRequest2.entity = entity2
        
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)

        fetchRequest1.sortDescriptors = [sortDescriptor]
        fetchRequest2.sortDescriptors = [sortDescriptor]
        
        do {
            userAvailableBalances = try managedObjectContext.fetch(fetchRequest1)
            userPortfolios = try managedObjectContext.fetch(fetchRequest2)
        }
        catch {
            fatalError("Error: \(error)")
        }
        
        if userAvailableBalances.count == 0 {
            self.userBalanceLabel.text! = "$0.00"
        }
        else{
            self.userBalanceLabel.text! = "$" + String(format: "%.2f", userAvailableBalances[0].availableBalance)
        }
        
        if userPortfolios.count == 0 {
            self.userSharesLabel.text! = "You don't have any " + stockObj.stockDisplaySymbol + " shares"
        }
        else {
            var stockFound = false
            let latestPortfolio = userPortfolios[0]
            for stock in latestPortfolio.stocks {
                if stock.symbol == stockObj.stockSymbol {
                    stockFound = true
                    if stock.quantity == 1 {
                        self.userSharesLabel.text! = "You own 1 share of " + stock.symbol
                    }
                    else {
                        self.userSharesLabel.text! = "You own " + String(stock.quantity) + " shares of " + stock.symbol
                    }
                }
            }
            if !stockFound {
                self.userSharesLabel.text! = "You don't have any " + stockObj.stockDisplaySymbol + " shares"
            }
        }
    }
    
    func callPercentageFetches() {
        getCandlePrices(resolution: 1)
        getCandlePrices(resolution: 2)
    }
    
    func stockPriceURL() -> URL {
        let urlStringFirstHalf = "https://finnhub.io/api/v1/quote?symbol="
        let stockSymbol = stockObj.stockSymbol
        let urlStringSecondHalf = "&token=API_KEY"
        let fullURL = urlStringFirstHalf + stockSymbol + urlStringSecondHalf
        let url = URL(string: fullURL)
        return url!
    }
    
    func parse(data: Data) -> StockPriceObj {
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(StockPriceObj.self, from: data)
            return result
        }
        catch {
            print ("JSON Decoder Error: \(error)")
            let emptyCurrentPrice = StockPriceObj()
            return emptyCurrentPrice
        }
    }
    
    func getStockPrice(){
        let url = stockPriceURL()
        let session = URLSession.shared
        dataTask = session.dataTask(with: url, completionHandler: { (data, response, error) in
            if let error = error as NSError? {
                print(error)
            }
            else if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 {
                if let data = data {
                    self.currentStockPrice = self.parse(data: data)
                    DispatchQueue.main.async {
                        self.stockPriceLabel.text! = "$" + String(format: "%.2f", self.currentStockPrice?.currentPrice ?? 0.00)
                        if let curPrice = self.currentStockPrice?.currentPrice {
                            let dailyPriceChange = curPrice - self.currentStockPrice!.previousClose
                            self.dailyChange = dailyPriceChange
                            let dailyPercentageChange = (dailyPriceChange/self.currentStockPrice!.previousClose) * 100
                            if dailyPriceChange < 0 {
                                self.stockPriceChangeLabel.text! = String(format: "%.2f", dailyPercentageChange) + "% ($" + String(format: "%.2f", dailyPriceChange * (-1)) + ")"
                                self.stockPriceChangeLabel.textColor = UIColor.red
                            }
                            else {
                                self.stockPriceChangeLabel.text! = "+" + String(format: "%.2f", dailyPercentageChange) + "% ($" + String(format: "%.2f", dailyPriceChange) + ")"
                                self.stockPriceChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                            }
                        }
                        else{
                            self.stockPriceChangeLabel.text! = "0% ($0.00)"
                        }
                    }
                    return
                }
            }
            else {
                print("Error!")
            }
        })
        dataTask?.resume()
    }
    
    func candlePriceURL(resolution: Int) -> URL {
        var resolutionChar = "5"
        let curDateTimestamp = Int(Date().timeIntervalSince1970)
        var pastDateTimestamp = curDateTimestamp - 604800
        if resolution == 2 {
            resolutionChar = "30"
            pastDateTimestamp = curDateTimestamp - 2592000
        }
        let urlStringSymbol = "https://finnhub.io/api/v1/stock/candle?symbol="
        let stockSymbol = stockObj.stockSymbol
        let urlStringResolution = "&resolution="
        let urlStringFrom = "&from="
        let urlStringTo = "&to="
        let urlStringToken = "&token=API_KEY"
        let fullURL = urlStringSymbol + stockSymbol + urlStringResolution + resolutionChar + urlStringFrom + String(pastDateTimestamp) + urlStringTo + String(curDateTimestamp) + urlStringToken
        let url = URL(string: fullURL)
        return url!
    }
    
    func parseCandle(data: Data) -> Candle {
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(Candle.self, from: data)
            return result
        }
        catch {
            print ("JSON Decoder Error: \(error)")
            let emptyCandle = Candle()
            return emptyCandle
        }
    }
    
    func getCandlePrices(resolution: Int){
        dispatchGroup.enter()
        let url = candlePriceURL(resolution: resolution)
        let session = URLSession.shared
        dataTask = session.dataTask(with: url, completionHandler: { (data, response, error) in
            if let error = error as NSError? {
                print(error)
            }
            else if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 {
                if let data = data {
                    let candle = self.parseCandle(data: data)
                    DispatchQueue.main.async {
                        if resolution == 2 {
                            if self.currentStockPrice != nil {
                                self.monthlyChange = self.currentStockPrice!.currentPrice - candle.openPrice
                            }
                        }
                        else {
                            if self.currentStockPrice != nil {
                                self.weeklyChange = self.currentStockPrice!.currentPrice - candle.openPrice
                            }
                        }
                    }
                    self.dispatchGroup.leave()
                    return
                }
            }
            else {
                print("Error!")
            }
        })
        dataTask?.resume()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "SellStock" {
            if userPortfolios.count == 0 {
                sellSharesError.text! = "You don't have any " + stockObj.stockSymbol + " shares"
                afterDelay(5){
                    self.sellSharesError.text! = ""
                }
                return false
            }
            else {
                let latestPortfolio = userPortfolios[0].stocks
                for stock in latestPortfolio {
                    if stock.symbol == stockObj.stockSymbol {
                        self.sellSharesError.text! = ""
                        return true
                    }
                }
                sellSharesError.text! = "You don't have any " + stockObj.stockSymbol + " shares"
                afterDelay(5){
                    self.sellSharesError.text! = ""
                }
                return false
            }
        }
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "BuyStock" {
            let controller = segue.destination as! BuyStockViewController
            controller.managedObjectContext = managedObjectContext
            controller.stockObj = stockObj
            controller.currentStockPrice = currentStockPrice
        }
        else if segue.identifier == "SellStock" {
            let controller = segue.destination as! SellStockViewController
            controller.managedObjectContext = managedObjectContext
            controller.stockObj = stockObj
            controller.currentStockPrice = currentStockPrice
        }
    }
    
    @IBAction func back() {
        navigationController?.popViewController(animated: true)
    }
    
}
