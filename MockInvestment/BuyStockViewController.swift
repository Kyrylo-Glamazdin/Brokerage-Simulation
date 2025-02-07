//
//  BuyStockViewController.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/15/20.
//

import Foundation
import UIKit
import CoreData
import AVFoundation

//This class is responsible for processing the transactions that simulate buying stocks and adding them to user's portfolio
class BuyStockViewController: UIViewController {
    //outlets
    @IBOutlet weak var buyStockLabel: UILabel!
    @IBOutlet weak var marketPriceLabel: UILabel!
    @IBOutlet weak var availableBalanceLabel: UILabel!
    @IBOutlet weak var numberOfSharesLabel: UITextField!
    @IBOutlet weak var estimatedCostLabel: UILabel!
    
    
    @IBAction func placeOrder(_ sender: Any) {
        checkTransactionValidity()
    }
    
    @IBOutlet weak var errorLabel: UILabel!
    
    var managedObjectContext: NSManagedObjectContext!
    var stockObj: AvailableStock!
    var currentStockPrice: StockPriceObj?
    
    //vars for local database fetches
    var userAvailableBalances = [UserAvailableBalance]()
    var userInvestmentBalances = [UserInvestmentBalance]()
    var userPortfolios = [UserPortfolioState]()
    
    var audioPlayer = AVAudioPlayer() //audio player to play the transaction sound
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        buyStockLabel.text! = "Buy " + stockObj.stockSymbol
        if currentStockPrice != nil{
            marketPriceLabel.text! = "Market price: $" + String(currentStockPrice!.currentPrice)
        }
        else {
            marketPriceLabel.text! = "Market price: $0.00"
        }
        
        //load sound into audio player
        let sound = Bundle.main.path(forResource: "CompleteSound", ofType: "caf")
        do {
            if sound != nil {
                audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: sound!))
            }
        }
        catch {
            print(error)
        }
        
        getPersonalFundsData()
        afterDelay(0.6) {
            self.numberOfSharesLabel.becomeFirstResponder()
        }
    }
    
    //fetch personal balance and portfolio data from local database
    func getPersonalFundsData() {
        //create requests
        let fetchRequest1 = NSFetchRequest<UserAvailableBalance>()
        let fetchRequest2 = NSFetchRequest<UserInvestmentBalance>()
        let fetchRequest3 = NSFetchRequest<UserPortfolioState>()
        
        let entity1 = UserAvailableBalance.entity()
        fetchRequest1.entity = entity1
        let entity2 = UserInvestmentBalance.entity()
        fetchRequest2.entity = entity2
        let entity3 = UserPortfolioState.entity()
        fetchRequest3.entity = entity3
        
        //sort by date from newest to oldest
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest1.sortDescriptors = [sortDescriptor]
        fetchRequest2.sortDescriptors = [sortDescriptor]
        fetchRequest3.sortDescriptors = [sortDescriptor]
        
        //fetch data
        do {
            userAvailableBalances = try managedObjectContext.fetch(fetchRequest1)
            userInvestmentBalances = try managedObjectContext.fetch(fetchRequest2)
            userPortfolios = try managedObjectContext.fetch(fetchRequest3)
        }
        catch {
            fatalError("Error: \(error)")
        }
        
        if userAvailableBalances.count == 0 {
            self.availableBalanceLabel.text! = "$0.00 Available"
        }
        else{
            self.availableBalanceLabel.text! = "$" + String(format: "%.2f", userAvailableBalances[0].availableBalance) + " Available"
        }
    }
    
    //MARK: - Validate and process transaction
    
    //check if transaction is valid by checking the entered amount of shares and available balance.
    //if transaction can be completed, process the transaction
    func checkTransactionValidity() {
        if let enteredSharesAmount = Double(numberOfSharesLabel.text!) {
            if enteredSharesAmount == 0 {
                errorLabel.text! = "Enter a valid amount of shares"
                afterDelay(5) {
                    self.errorLabel.text! = ""
                }
                return
            }
            if currentStockPrice != nil {
                let requiredPurchaseBalance = currentStockPrice!.currentPrice * enteredSharesAmount
                if userAvailableBalances.count == 0 {
                    errorLabel.text! = "Not enough buying power"
                    afterDelay(5) {
                        self.errorLabel.text! = ""
                    }
                }
                else {
                    let latestBalance = userAvailableBalances[0]
                    if latestBalance.availableBalance >= requiredPurchaseBalance {
                        //process transaction
                        completePurchase(totalTransactionCost: requiredPurchaseBalance)
                    }
                    else {
                        errorLabel.text! = "Not enough buying power"
                        afterDelay(5) {
                            self.errorLabel.text! = ""
                        }
                    }
                }
            }
            else {
                //this indicates an API issue, most likely exceeding API call limit. Try again in a minute
                errorLabel.text! = "Price error: Could not place your order"
                afterDelay(5) {
                    self.errorLabel.text! = ""
                }
            }
        }
        else {
            errorLabel.text! = "Enter a valid amount of shares"
            afterDelay(5) {
                self.errorLabel.text! = ""
            }
        }
    }
    
    //this method processes the transaction and adds stocks to user's portfolio
    //@precondion: number of stocks entered is valid and @totalTransactionCost does not exceed user's available balance
    func completePurchase(totalTransactionCost: Double) {
        let date = Date()
        let enteredSharesAmount = Double(numberOfSharesLabel.text!)
        
        //check if this is the first ever stock in user's portfolio
        if userPortfolios.count == 0 {
            let availableBalance = UserAvailableBalance(context: managedObjectContext)
            let investmentBalance = UserInvestmentBalance(context: managedObjectContext)
            let userPortfolio = UserPortfolioState(context: managedObjectContext)
            
            //append the new stock
            let newStock = PortfolioStock()
            newStock.symbol = stockObj.stockSymbol
            newStock.name = stockObj.stockDescription
            newStock.quantity = Int(enteredSharesAmount!)
            userPortfolio.stocks.append(newStock)
            userPortfolio.date = date
            
            availableBalance.availableBalance = userAvailableBalances[0].availableBalance - totalTransactionCost
            if userInvestmentBalances.count == 0 {
                investmentBalance.investmentBalance = totalTransactionCost
            }
            else {
                investmentBalance.investmentBalance = userInvestmentBalances[0].investmentBalance + totalTransactionCost
            }
            
            availableBalance.date = date
            investmentBalance.date = date
            
            //save the portfolio, show the animation, and play transaction completion sound
            do {
                try managedObjectContext.save()
                postCompletionNotification()
                numberOfSharesLabel.resignFirstResponder()
                let hudView = HudView.hud(inView: view, animated: true)
                hudView.text = "Done"
                audioPlayer.play()
                afterDelay(0.6){
                    hudView.hide()
                    self.dismiss(animated: true, completion: nil)
                }
            }
            catch {
                fatalError("Error: \(error)")
            }
        }
        //else is triggered when the user already has a portfolio history
        else {
            var stockAlreadyInPortfolio = false
            let latestUserPortfolio = userPortfolios[0]
            let availableBalance = UserAvailableBalance(context: managedObjectContext)
            let investmentBalance = UserInvestmentBalance(context: managedObjectContext)
            let userPortfolio = UserPortfolioState(context: managedObjectContext)
            for stock in latestUserPortfolio.stocks {
                //check if this stock is already present in user's portfolio. if so, just increment its count
                if stock.symbol == stockObj.stockSymbol {
                    stockAlreadyInPortfolio = true
                    let existingStock = stock
                    existingStock.quantity = Int(enteredSharesAmount!) + existingStock.quantity
                    userPortfolio.stocks.append(existingStock)
                    
                    availableBalance.availableBalance = userAvailableBalances[0].availableBalance - totalTransactionCost
                    investmentBalance.investmentBalance = userInvestmentBalances[0].investmentBalance + totalTransactionCost
                    
                    userPortfolio.date = date
                    availableBalance.date = date
                    investmentBalance.date = date
                }
                //append other existing stocks
                else {
                    userPortfolio.stocks.append(stock)
                }
            }
            //if this stock is not yet in the portfolio, append it to @stocks without incrementing the existion stock count
            if !stockAlreadyInPortfolio {
                let newStock = PortfolioStock()
                newStock.symbol = stockObj.stockSymbol
                newStock.name = stockObj.stockDescription
                newStock.quantity = Int(enteredSharesAmount!)
                userPortfolio.stocks.append(newStock)
                
                availableBalance.availableBalance = userAvailableBalances[0].availableBalance - totalTransactionCost
                investmentBalance.investmentBalance = userInvestmentBalances[0].investmentBalance + totalTransactionCost
                
                userPortfolio.date = date
                availableBalance.date = date
                investmentBalance.date = date
            }
            
            //save the portfolio, show the animation, and play transaction completion sound
            do {
                try managedObjectContext.save()
                postCompletionNotification()
                self.numberOfSharesLabel.resignFirstResponder()
                let hudView = HudView.hud(inView: view, animated: true)
                hudView.text = "Done"
                audioPlayer.play()
                afterDelay(0.6){
                    hudView.hide()
                    self.dismiss(animated: true, completion: nil)
                }
            }
            catch {
                fatalError("Error: \(error)")
            }
        }
    }
    
    //when the number of entered shares changes, update the estimated price label
    @IBAction func numberOfEnteredSharesDidChange(_ sender: Any) {
        if let enteredSharesAmount = Double(numberOfSharesLabel.text!) {
            let newTransactionPrice = enteredSharesAmount * (currentStockPrice?.currentPrice ?? 0)
            estimatedCostLabel.text! = "$" + String(format: "%.2f", newTransactionPrice)
        }
        else {
            estimatedCostLabel.text! = "$0.00"
        }
    }
    
    
    @IBAction func cancel() {
        dismiss(animated: true, completion: nil)
    }
    
    //issue a notification indicating that the portfolio has been updated and other controllers must re-fetch data
    func postCompletionNotification() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "StockTransactionCompleted"), object: nil)
    }
}
