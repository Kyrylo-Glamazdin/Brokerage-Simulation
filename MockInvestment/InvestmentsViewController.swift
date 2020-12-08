//
//  ViewController.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/2/20.
//

// This is the main view of the application. It is showing the current state of user's portfolio, including their balances and purchased stocks
import CoreData
import UIKit

class InvestmentsViewController: UIViewController {
    
    //outlets to screen's components
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var userInvestmentBalanceLabel: UILabel!
    @IBOutlet weak var userAvailableBalanceLabel: UILabel!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var userInvestmentBalancePercentageChangeLabel: UILabel!
    
    
    var managedObjectContext: NSManagedObjectContext!
    var dataTask: URLSessionDataTask?
    var stateController: StateController! //state controller used for passing all of the available stocks to searchStocksViewController on a different tab
    
    var currentInvestments = [Investment]() // investments define the current state of user's portfolio (used in a tableView)
    
    //data from the local database
    var userTotalBalances = [UserTotalBalance]()
    var userTotalDepositBalances = [UserTotalDepositedBalance]()
    var userAvailableBalances = [UserAvailableBalance]()
    var userPortfolios = [UserPortfolioState]()
    var availableStocks = [AvailableStock]()
    
    var portfolioStockPrices = [StockPriceObj]() //prices of stocks in portfolio
    var stockPriceObjects = [StockPrice]()
    
    var selectedStock: AvailableStock? //stock that has been selected in a tableView
    
    // strings to display in a userInvestmentBalancePercentageChangeLabel depending on the selected value of segmentedControl
    var dailyChange: String = "Loading..."
    var weeklyChange: String = "Loading..."
    var monthlyChange: String = "Loading..."
    var allTimeChange: String = "Loading..."
    
    //values of user's personal percentage changes for day, week, month, and all-time
    var dailyChangeVal: Double = 0
    var weeklyChangeVal: Double = 0
    var monthlyChangeVal: Double = 0
    var allTimeChangeVal: Double = 0
    
    // user portfolio net worth 1 day, 1 week, and 1 month ago
    var dailyChangeGroup = [Double]()
    var weeklyChangeGroup = [Double]()
    var monthlyChangeGroup = [Double]()
    
    var userInvestmentBalanceTotal: Double = 0
    var canToggleSegmentedControl: Bool = false // becomes true when historical prices are loaded
    
    let defaults = UserDefaults.standard //used for saving the previous segmentedControl selection
    var selectedPercentageChangeSegment = 0
    
    // dispatch groups that notify when each task in them finished executing (used for multiple API calls)
    let dispatchGroup = DispatchGroup()
    let dispatchGroup2 = DispatchGroup()
    
    struct TableView {
        struct CellIdentifiers {
            static let investmentCell = "InvestmentCell"
            static let noInvestmentsCell = "NoInvestmentsCell"
        }
    }
    
    struct StockPrice {
        var symbol: String = ""
        var price: Double = 0
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //listen for the notifications to complete further updates (when app state changes or finishes loading the API data)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateDataAndLabels), name: Notification.Name(rawValue: "StockTransactionCompleted"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.getPersonalPercentageChanges), name: Notification.Name(rawValue: "BalanceComputationCompleted"), object: nil)
        
        updateDataAndLabels() //fetch and display portfolio data
        userInvestmentBalanceLabel.text! = "Loading..."
        

        //register custom cells
        var cellNib = UINib(nibName: TableView.CellIdentifiers.investmentCell, bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: TableView.CellIdentifiers.investmentCell)
        cellNib = UINib(nibName: TableView.CellIdentifiers.noInvestmentsCell, bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: TableView.CellIdentifiers.noInvestmentsCell)
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        selectedPercentageChangeSegment = defaults.integer(forKey: "selectedSegment")
        segmentedControl.selectedSegmentIndex = 0
        
        //updating the labels and tableView after API calls
        dispatchGroup.notify(queue: .main){
            self.tableView.reloadData()
            self.updateInvestmentLabel()
        }
    }
    
    // MARK: - Data Fetches
    
    //fetches and displays portfolio data
    @objc func updateDataAndLabels() {
        performDataFetch()
        performStockSymbolFetch()
        fetchPrices()
    }
    
    //loads data from the local database
    func performDataFetch(){
        let fetchRequest1 = NSFetchRequest<UserTotalBalance>()
        let fetchRequest2 = NSFetchRequest<UserTotalDepositedBalance>()
        let fetchRequest3 = NSFetchRequest<UserAvailableBalance>()
        let fetchRequest4 = NSFetchRequest<UserPortfolioState>()
        
        let entity1 = UserTotalBalance.entity()
        fetchRequest1.entity = entity1
        let entity2 = UserTotalDepositedBalance.entity()
        fetchRequest2.entity = entity2
        let entity3 = UserAvailableBalance.entity()
        fetchRequest3.entity = entity3
        let entity4 = UserPortfolioState.entity()
        fetchRequest4.entity = entity4
        
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false) //sort by descending date
        fetchRequest1.sortDescriptors = [sortDescriptor]
        fetchRequest2.sortDescriptors = [sortDescriptor]
        fetchRequest3.sortDescriptors = [sortDescriptor]
        fetchRequest4.sortDescriptors = [sortDescriptor]
        
        do {
            userTotalBalances = try managedObjectContext.fetch(fetchRequest1)
            userTotalDepositBalances = try managedObjectContext.fetch(fetchRequest2)
            userAvailableBalances = try managedObjectContext.fetch(fetchRequest3)
            userPortfolios = try managedObjectContext.fetch(fetchRequest4)
        }
        catch {
            fatalError("Error: \(error)")
        }
        
        if userAvailableBalances.count == 0 {
            self.userAvailableBalanceLabel.text! = "$0.00"
        }
        else{
            self.userAvailableBalanceLabel.text! = "$" + String(format: "%.2f", userAvailableBalances[0].availableBalance)
        }
        
        //display portfolio stocks in the tableView
        currentInvestments = []
        if userPortfolios.count != 0 {
            for stock in userPortfolios[0].stocks {
                let investment = Investment()
                investment.symbol = stock.symbol
                investment.shares = stock.quantity
                investment.percentageChange = "Loading..."
                currentInvestments.append(investment)
            }
        }
        
        tableView.reloadData()
    }
    
    //fetch current prices for each stock in the portfolio
    func fetchPrices() {
        stockPriceObjects = []
        portfolioStockPrices = []
        for i in 0..<currentInvestments.count {
            getStockPrice(stockSymbol: currentInvestments[i].symbol, indexInCurrentInvestments: i)
        }
    }
    
    //url to the endpoint for getting all supported stocks
    func finnhubURL() -> URL {
        let urlString = "https://finnhub.io/api/v1/stock/symbol?exchange=US&token=" + apiKey
        let url = URL(string: urlString)
        return url!
    }
    
    //parsing all supported stocks
    func parse(data: Data) -> [AvailableStock] {
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode([AvailableStock].self, from: data)
            return result
        }
        catch {
            print ("JSON Decoder Error: \(error)")
            return []
        }
    }
    
    //fetching all the stocks that are supported by finnhub.io API service
    func performStockSymbolFetch(){
        let url = finnhubURL()
        let session = URLSession.shared
        dataTask = session.dataTask(with: url, completionHandler: { (data, response, error) in
            if let error = error as NSError? {
                print(error)
            }
            else if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 {
                if let data = data {
                    self.availableStocks = self.parse(data: data)
                    self.availableStocks.sort(by: <)
                    self.stateController.availableStocks = self.availableStocks
                    return
                }
            }
            else {
                print("Error!")
            }
        })
        dataTask?.resume()
    }
    
    //url for the endpoint providing current stock prices
    func stockPriceURL(stockSymbol: String) -> URL {
        let urlStringFirstHalf = "https://finnhub.io/api/v1/quote?symbol="
        let stockSymbol = stockSymbol
        let urlStringSecondHalf = "&token=" + apiKey
        let fullURL = urlStringFirstHalf + stockSymbol + urlStringSecondHalf
        let url = URL(string: fullURL)
        return url!
    }
    
    //parsing stockPrice objects
    func parseStockPrice(data: Data) -> StockPriceObj {
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
    
    //fetching stock prices
    func getStockPrice(stockSymbol: String, indexInCurrentInvestments: Int){
        dispatchGroup.enter() //use dispatch group to await for all stock prices to finish fetching
        let url = stockPriceURL(stockSymbol: stockSymbol)
        let session = URLSession.shared
        dataTask = session.dataTask(with: url, completionHandler: { (data, response, error) in
            if let error = error as NSError? {
                print(error)
            }
            else if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 {
                if let data = data {
                    let currentStockPrice = (self.parseStockPrice(data: data))
                    self.portfolioStockPrices.append(currentStockPrice)
                    let curPrice = currentStockPrice.currentPrice
                    let previousClose = currentStockPrice.previousClose
                    let dailyPriceChange = curPrice - previousClose
                    let dailyPercentageChange = (dailyPriceChange / previousClose) * 100
                    var percentageChangeString = String(format: "%.2f", dailyPercentageChange)
                    if dailyPercentageChange > 0 {
                        percentageChangeString = "+" + percentageChangeString
                    }
                    self.currentInvestments[indexInCurrentInvestments].percentageChange = percentageChangeString + "%"
                    self.currentInvestments[indexInCurrentInvestments].percentageChangeVal = dailyPercentageChange
                    let curStockPriceObject = StockPrice(symbol: stockSymbol, price: curPrice)
                    self.stockPriceObjects.append(curStockPriceObject)
                    self.dispatchGroup.leave()
                }
            }
            else {
                print("Error!")
            }
        })
        dataTask?.resume()
    }
    
    //url for the endpoint to get the candle prices (for historical price data)
    //@resolution defines which time interval to fetch
    func candlePriceURL(resolution: Int, stockSymbol: String) -> URL {
        var resolutionChar = "5"
        let curDateTimestamp = Int(Date().timeIntervalSince1970)
        var pastDateTimestamp = curDateTimestamp - 604800 // 1 week ago
        if resolution == 2 {
            resolutionChar = "30"
            pastDateTimestamp = curDateTimestamp - 2592000 // 1 month ago
        }
        // using same for day change as for week change due to API inconsistency (use a different value later)
        else if resolution == 0 {
            resolutionChar = "5"
            pastDateTimestamp = curDateTimestamp - 604800
        }
        let urlStringSymbol = "https://finnhub.io/api/v1/stock/candle?symbol="
        let stockSymbol = stockSymbol
        let urlStringResolution = "&resolution="
        let urlStringFrom = "&from="
        let urlStringTo = "&to="
        let urlStringToken = "&token=" + apiKey
        let fullURL = urlStringSymbol + stockSymbol + urlStringResolution + resolutionChar + urlStringFrom + String(pastDateTimestamp) + urlStringTo + String(curDateTimestamp) + urlStringToken
        let url = URL(string: fullURL)
        return url!
    }
    
    //parse candle data objects
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
    
    //fetch historical prices of the stock (in a form of candle data)
    //append to the correct array based on the @resolution provided
    func getCandlePrice(resolution: Int, stockSymbol: String, quantity: Int){
        dispatchGroup2.enter()
        let url = candlePriceURL(resolution: resolution, stockSymbol: stockSymbol)
        let session = URLSession.shared
        dataTask = session.dataTask(with: url, completionHandler: { (data, response, error) in
            if let error = error as NSError? {
                print(error)
            }
            else if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 {
                if let data = data {
                    let candle = self.parseCandle(data: data)
                    if candle.status != "no_data"{
                        if resolution == 2 {
                            self.monthlyChangeGroup.append(candle.openPrice * Double(quantity))
                        }
                        else if resolution == 1{
                            self.weeklyChangeGroup.append(candle.openPrice * Double(quantity))
                        }
                        else {
                            self.dailyChangeGroup.append(candle.specialOpenPrice * Double(quantity))
                        }
                        self.dispatchGroup2.leave()
                        return
                    }
                }
            }
            else {
                print("Error!")
            }
        })
        dataTask?.resume()
    }
    
    //MARK: - Updating labels using fetched data
    
    //computes user's personal percentages for the portfolio's net worth.
    //fetches the user's portfolio at that point in time (1 day, 1 week, and 1 month ago), and gets historical stock prices as well as available balances
    @objc func getPersonalPercentageChanges() {
        dailyChangeGroup = []
        weeklyChangeGroup = []
        monthlyChangeGroup = []
        let oneDayToThePast = Int(Date().timeIntervalSince1970) - 86400
        let oneWeekToThePast = Int(Date().timeIntervalSince1970) - 604800
        let oneMonthToThePast = Int(Date().timeIntervalSince1970) - 2592000
        var oneDayAgoInvestments: [PortfolioStock] = []
        var oneWeekAgoInvestments: [PortfolioStock] = []
        var oneMonthAgoInvestments: [PortfolioStock] = []
        
        //get user's available balances for 1 day, week, month ago
        if userAvailableBalances.count > 0 {
            if Int(userAvailableBalances[0].date.timeIntervalSince1970) < oneDayToThePast {
                dailyChangeGroup.append(userAvailableBalances[0].availableBalance)
            }
            else if Int(userAvailableBalances[userAvailableBalances.count - 1].date.timeIntervalSince1970) > oneDayToThePast {
                // do nothing
            }
            else {
                for i in 0..<userAvailableBalances.count - 1 {
                    if Int(userAvailableBalances[i].date.timeIntervalSince1970) > oneDayToThePast && Int(userAvailableBalances[i + 1].date.timeIntervalSince1970) <= oneDayToThePast {
                        dailyChangeGroup.append(userAvailableBalances[i+1].availableBalance)
                        break
                    }
                }
            }
            
            if Int(userAvailableBalances[0].date.timeIntervalSince1970) < oneWeekToThePast {
                weeklyChangeGroup.append(userAvailableBalances[0].availableBalance)
            }
            else if Int(userAvailableBalances[userAvailableBalances.count - 1].date.timeIntervalSince1970) > oneWeekToThePast {
                // do nothing
            }
            else {
                for i in 0..<userAvailableBalances.count - 1 {
                    if Int(userAvailableBalances[i].date.timeIntervalSince1970) > oneWeekToThePast && Int(userAvailableBalances[i + 1].date.timeIntervalSince1970) <= oneWeekToThePast {
                        weeklyChangeGroup.append(userAvailableBalances[i+1].availableBalance)
                        break
                    }
                }
            }
            
            if Int(userAvailableBalances[0].date.timeIntervalSince1970) < oneMonthToThePast {
                monthlyChangeGroup.append(userAvailableBalances[0].availableBalance)
            }
            else if Int(userAvailableBalances[userAvailableBalances.count - 1].date.timeIntervalSince1970) > oneMonthToThePast {
                // do nothing
            }
            else {
                for i in 0..<userAvailableBalances.count - 1 {
                    if Int(userAvailableBalances[i].date.timeIntervalSince1970) > oneMonthToThePast && Int(userAvailableBalances[i + 1].date.timeIntervalSince1970) <= oneMonthToThePast {
                        monthlyChangeGroup.append(userAvailableBalances[i+1].availableBalance)
                        break
                    }
                }
            }
        }
        
        //get stocks in user's potfolio for 1 day, week, and month ago
        if userPortfolios.count > 0 {
            if Int(userPortfolios[0].date.timeIntervalSince1970) < oneDayToThePast {
                oneDayAgoInvestments = userPortfolios[0].stocks
            }
            else if Int(userPortfolios[userPortfolios.count - 1].date.timeIntervalSince1970) > oneDayToThePast {
                oneDayAgoInvestments = []
            }
            else {
                for i in 0..<userPortfolios.count - 1 {
                    if Int(userPortfolios[i].date.timeIntervalSince1970) > oneDayToThePast && Int(userPortfolios[i + 1].date.timeIntervalSince1970) <= oneDayToThePast {
                        oneDayAgoInvestments = userPortfolios[i+1].stocks
                        break
                    }
                }
            }
            
            if Int(userPortfolios[0].date.timeIntervalSince1970) < oneWeekToThePast {
                oneWeekAgoInvestments = userPortfolios[0].stocks
            }
            else if Int(userPortfolios[userPortfolios.count - 1].date.timeIntervalSince1970) > oneWeekToThePast {
                oneWeekAgoInvestments = []
            }
            else {
                for i in 0..<userPortfolios.count - 1 {
                    if Int(userPortfolios[i].date.timeIntervalSince1970) > oneWeekToThePast && Int(userPortfolios[i + 1].date.timeIntervalSince1970) <= oneWeekToThePast {
                        oneWeekAgoInvestments = userPortfolios[i+1].stocks
                        break
                    }
                }
            }
            
            if Int(userPortfolios[0].date.timeIntervalSince1970) < oneMonthToThePast {
                oneMonthAgoInvestments = userPortfolios[0].stocks
            }
            else if Int(userPortfolios[userPortfolios.count - 1].date.timeIntervalSince1970) > oneMonthToThePast {
                oneMonthAgoInvestments = []
            }
            else {
                for i in 0..<userPortfolios.count - 1 {
                    if Int(userPortfolios[i].date.timeIntervalSince1970) > oneMonthToThePast && Int(userPortfolios[i + 1].date.timeIntervalSince1970) <= oneMonthToThePast {
                        oneMonthAgoInvestments = userPortfolios[i+1].stocks
                        break
                    }
                }
            }
            
            //fetch historical prices for each stock that was in user's portfolio in particular points in time
            for investment in oneDayAgoInvestments {
                getCandlePrice(resolution: 0, stockSymbol: investment.symbol, quantity: investment.quantity)
            }
            
            for investment in oneWeekAgoInvestments {
                getCandlePrice(resolution: 1, stockSymbol: investment.symbol, quantity: investment.quantity)
            }
            
            for investment in oneMonthAgoInvestments {
                getCandlePrice(resolution: 2, stockSymbol: investment.symbol, quantity: investment.quantity)
            }
        }
        else {
            self.dailyChange = "0.00% ($0.00)"
            self.weeklyChange = "0.00% ($0.00)"
            self.monthlyChange = "0.00% ($0.00)"
        }
        //compute all time net worth change
        var latestTotalDeposit: Double = 1
        if userTotalDepositBalances.count > 0 {
            latestTotalDeposit = userTotalDepositBalances[0].totalDepositedBalance
            let priceDifference = userInvestmentBalanceTotal - latestTotalDeposit
            let percentageDifference = (priceDifference / latestTotalDeposit) * 100
            if percentageDifference < 0 {
                self.allTimeChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference * (-1)) + ")"
            }
            else {
                self.allTimeChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference) + ")"
            }
            self.allTimeChangeVal = percentageDifference
        }
        else {
            self.allTimeChange = "0.00% ($0.00)"
        }
        
        //await for the api calls and finish updating the labels
        dispatchGroup2.notify(queue: .main) {
            self.finishUpdatingPercentageLabels()
        }
    }
    
    //gets called when the historical prices are fetched
    //updates the labels accordingly
    func finishUpdatingPercentageLabels() {
        
        //compute 1 day change
        var currentInvestmentSum: Double = 0
        if dailyChangeGroup.count > 0 {
            for price in dailyChangeGroup {
                currentInvestmentSum = currentInvestmentSum + price
            }
            let priceDifference = userInvestmentBalanceTotal - currentInvestmentSum
            let percentageDifference = (priceDifference / currentInvestmentSum) * 100
            if percentageDifference < 0 {
                self.dailyChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference * (-1)) + ")"

            }
            else {
                self.dailyChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference) + ")"
            }
            self.dailyChangeVal = percentageDifference
        }
        else {
            self.dailyChange = "0.00% ($0.00)"
        }
        
        //compute 1 week change
        currentInvestmentSum = 0
        if weeklyChangeGroup.count > 0 {
            for price in weeklyChangeGroup {
                currentInvestmentSum = currentInvestmentSum + price
            }
            let priceDifference = userInvestmentBalanceTotal - currentInvestmentSum
            let percentageDifference = (priceDifference / currentInvestmentSum) * 100
            if percentageDifference < 0 {
                self.weeklyChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference * (-1)) + ")"
            }
            else {
                self.weeklyChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference) + ")"
            }
            self.weeklyChangeVal = percentageDifference
        }
        else {
            self.weeklyChange = "0.00% ($0.00)"
        }
        
        //compute 1 month change
        currentInvestmentSum = 0
        if monthlyChangeGroup.count > 0 {
            for price in monthlyChangeGroup {
                currentInvestmentSum = currentInvestmentSum + price
            }
            let priceDifference = userInvestmentBalanceTotal - currentInvestmentSum
            let percentageDifference = (priceDifference / currentInvestmentSum) * 100
            if percentageDifference < 0 {
                self.monthlyChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference * (-1)) + ")"
            }
            else {
                self.monthlyChange = String(format: "%.2f", percentageDifference) + "% ($" + String(format: "%.2f", priceDifference) + ")"
            }
            self.monthlyChangeVal = percentageDifference
        }
        else {
            self.monthlyChange = "0.00% ($0.00)"
        }
        
        canToggleSegmentedControl = true
        
        //set personal percentage change label to the value corresponding to the index of segmentedControl set in userDefaults
        segmentedControl.selectedSegmentIndex = selectedPercentageChangeSegment
        
        let segmentedControlValue = selectedPercentageChangeSegment
        if segmentedControlValue == 0 {
            userInvestmentBalancePercentageChangeLabel.text! = dailyChange
            if dailyChangeVal < 0 {
                userInvestmentBalancePercentageChangeLabel.textColor = UIColor.red
            }
            else {
                userInvestmentBalancePercentageChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
            }
        }
        else if segmentedControlValue == 1 {
            userInvestmentBalancePercentageChangeLabel.text! = weeklyChange
            if weeklyChangeVal < 0 {
                userInvestmentBalancePercentageChangeLabel.textColor = UIColor.red
            }
            else {
                userInvestmentBalancePercentageChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
            }
        }
        else if segmentedControlValue == 2 {
            userInvestmentBalancePercentageChangeLabel.text! = monthlyChange
            if monthlyChangeVal < 0 {
                userInvestmentBalancePercentageChangeLabel.textColor = UIColor.red
            }
            else {
                userInvestmentBalancePercentageChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
            }
        }
        else {
            userInvestmentBalancePercentageChangeLabel.text! = allTimeChange
            if allTimeChangeVal < 0 {
                userInvestmentBalancePercentageChangeLabel.textColor = UIColor.red
            }
            else {
                userInvestmentBalancePercentageChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
            }
        }
        
    }
    
    // update the label that shows the total balance of the user's portfolio using current stock prices and available balance
    func updateInvestmentLabel() {
        var userAvailableBalance: Double = 0
        if userAvailableBalances.count > 0 {
            userAvailableBalance = userAvailableBalances[0].availableBalance
        }
        var totalStockPrices: Double = 0
        for stock in currentInvestments {
            let thisStockShares = stock.shares
            for stockPriceObject in stockPriceObjects {
                if stockPriceObject.symbol == stock.symbol {
                    totalStockPrices = totalStockPrices + Double(stockPriceObject.price * Double(thisStockShares))
                    break
                }
            }
        }
        let userTotalInvestmentBalance = totalStockPrices + userAvailableBalance
        userInvestmentBalanceTotal = userTotalInvestmentBalance
        userInvestmentBalanceLabel.text! = "$" + String(format: "%.2f", userTotalInvestmentBalance)
        postBalanceFetchedNotification()
    }
    
    //post a notification signifying the completion of balance computation
    func postBalanceFetchedNotification() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "BalanceComputationCompleted"), object: nil)
    }
    
    //display the percentage change corresponding to the selected segmentedControl segment
    @IBAction func priceChangeSegmentChanged(_ sender: UISegmentedControl) {
        if canToggleSegmentedControl {
            let segmentedControlValue = sender.selectedSegmentIndex
            if segmentedControlValue == 0 {
                userInvestmentBalancePercentageChangeLabel.text! = dailyChange
                if dailyChangeVal < 0 {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor.red
                }
                else {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                }
                defaults.set(0, forKey: "selectedSegment")
            }
            else if segmentedControlValue == 1 {
                userInvestmentBalancePercentageChangeLabel.text! = weeklyChange
                if weeklyChangeVal < 0 {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor.red
                }
                else {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                }
                defaults.set(1, forKey: "selectedSegment")
            }
            else if segmentedControlValue == 2 {
                userInvestmentBalancePercentageChangeLabel.text! = monthlyChange
                if monthlyChangeVal < 0 {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor.red
                }
                else {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                }
                defaults.set(2, forKey: "selectedSegment")
            }
            else {
                userInvestmentBalancePercentageChangeLabel.text! = allTimeChange
                if allTimeChangeVal < 0 {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor.red
                }
                else {
                    userInvestmentBalancePercentageChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
                }
                defaults.set(3, forKey: "selectedSegment")
            }
        }
    }
    
    //MARK: - Helper Methods
    
    //hide and show the nav bar
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.isNavigationBarHidden = false
    }
    
    //prepare the controllers for segue (pass managedObjectContext & other significalnt variables)
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "DepositFunds" {
            let controller = segue.destination as! DepositFundsViewController
            controller.delegate = self
            controller.managedObjectContext = managedObjectContext
        }
        else if segue.identifier == "ViewIndividualStockFromPortfolio" {
            let controller = segue.destination as! IndividualStockViewController
            controller.managedObjectContext = managedObjectContext
            if selectedStock != nil {
                controller.stockObj = selectedStock
            }
        }
    }
}

//MARK: - TableView delegate methods

extension InvestmentsViewController: UITableViewDelegate, UITableViewDataSource {
    //returns the number of table cells that tablreView has to display
    func tableView (_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        if currentInvestments.count == 0 {
            return 1
        }
        else {
            return currentInvestments.count
        }
    }
    
    //set the value of each tableView cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let emptyCell = tableView.dequeueReusableCell(withIdentifier: TableView.CellIdentifiers.noInvestmentsCell, for: indexPath)
        if currentInvestments.count == 0 {
            return emptyCell
        }
        else {
            let cell = tableView.dequeueReusableCell(withIdentifier: TableView.CellIdentifiers.investmentCell, for: indexPath) as! InvestmentCell
            let investment = currentInvestments[indexPath.row]
            cell.symbolLabel.text = investment.symbol
            cell.percentageChangeLabel.text = investment.percentageChange
            if investment.percentageChangeVal < 0 {
                cell.percentageChangeLabel.textColor = UIColor.red
            }
            else {
                cell.percentageChangeLabel.textColor = UIColor(red: 0, green: 178/255, blue: 8/255, alpha: 1)
            }
            cell.sharesLabel.text = String(investment.shares) + " shares"
            if investment.shares == 1 {
                cell.sharesLabel.text = String(1) + " share"
            }
            return cell
        }
    }
    
    // perform a segue when the user selects a tableView cell
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if currentInvestments.count > 0 {
            let selectedInvestmentSymbol = currentInvestments[indexPath.row].symbol
            self.selectedStock = nil
            for stock in availableStocks {
                if stock.stockSymbol == selectedInvestmentSymbol {
                    self.selectedStock = stock
                    break
                }
            }
            tableView.deselectRow(at: indexPath, animated: false)
            if self.selectedStock != nil {
                self.performSegue(withIdentifier: "ViewIndividualStockFromPortfolio", sender: self)
            }
        }
        else {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
 }

//MARK: - DepositFundsViewController delegate method

//update the data when funds were added
extension InvestmentsViewController: DepositFundsViewControllerDelegate {
    func transactionComplete(sender: DepositFundsViewController) {
        self.updateDataAndLabels()
        dispatchGroup.notify(queue: .main){
            self.tableView.reloadData()
            self.updateInvestmentLabel()
        }
    }
}
