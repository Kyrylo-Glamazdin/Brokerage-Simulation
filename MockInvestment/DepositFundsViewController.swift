//
//  DepositFundsViewController.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/3/20.
//

import CoreData
import UIKit
import AVFoundation

protocol DepositFundsViewControllerDelegate: class {
    func transactionComplete(sender: DepositFundsViewController)
}

class DepositFundsViewController: UIViewController {
    
    @IBOutlet weak var depositAmountTextField: UITextField!
    @IBOutlet weak var errorDepositText: UILabel!
    var managedObjectContext: NSManagedObjectContext!
    var userTotalBalances = [UserTotalBalance]()
    var userTotalDepositBalances = [UserTotalDepositedBalance]()
    var userAvailableBalances = [UserAvailableBalance]()
    var amountAdded: ((_ item: Double) -> Void)?
    var audioPlayer = AVAudioPlayer()
    weak var delegate: DepositFundsViewControllerDelegate?
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let sound = Bundle.main.path(forResource: "CompleteSound", ofType: "caf")
        do {
            if sound != nil {
                audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: sound!))
            }
        }
        catch {
            print(error)
        }
        
        let fetchRequest1 = NSFetchRequest<UserTotalBalance>()
        let fetchRequest2 = NSFetchRequest<UserTotalDepositedBalance>()
        let fetchRequest3 = NSFetchRequest<UserAvailableBalance>()
        
        let entity1 = UserTotalBalance.entity()
        fetchRequest1.entity = entity1
        let entity2 = UserTotalDepositedBalance.entity()
        fetchRequest2.entity = entity2
        let entity3 = UserAvailableBalance.entity()
        fetchRequest3.entity = entity3
        
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest1.sortDescriptors = [sortDescriptor]
        fetchRequest2.sortDescriptors = [sortDescriptor]
        fetchRequest3.sortDescriptors = [sortDescriptor]
        
        do {
            userTotalBalances = try managedObjectContext.fetch(fetchRequest1)
            userTotalDepositBalances = try managedObjectContext.fetch(fetchRequest2)
            userAvailableBalances = try managedObjectContext.fetch(fetchRequest3)
        }
        catch {
            fatalError("Error: \(error)")
        }
        
        afterDelay(0.6){
            self.depositAmountTextField.becomeFirstResponder()
        }
    }
    
    @IBAction func cancel() {
        dismiss(animated: true, completion: nil)
    }
    @IBAction func processDeposit() {
        let date = Date()
        if let enteredAmount = Double(depositAmountTextField.text!) {
            errorDepositText.text! = ""
            let userAvailableBalance = UserAvailableBalance(context: managedObjectContext)
            let userTotalDepositedBalance = UserTotalDepositedBalance(context: managedObjectContext)
            let userTotalBalance = UserTotalBalance(context: managedObjectContext)
            if userAvailableBalances.count == 0 {
                userAvailableBalance.availableBalance = enteredAmount
            }
            else {
                userAvailableBalance.availableBalance = userAvailableBalances[0].availableBalance + enteredAmount

            }
            if userTotalDepositBalances.count == 0 {
                userTotalDepositedBalance.totalDepositedBalance = enteredAmount

            }
            else{
                userTotalDepositedBalance.totalDepositedBalance = userTotalDepositBalances[0].totalDepositedBalance + enteredAmount

            }
            if userTotalBalances.count == 0 {
                userTotalBalance.totalBalance = enteredAmount

            }
            else {
                userTotalBalance.totalBalance = userTotalBalances[0].totalBalance + enteredAmount

            }
            userAvailableBalance.date = date
            userTotalDepositedBalance.date = date
            userTotalBalance.date = date
            
            do {
                try managedObjectContext.save()
                amountAdded?(enteredAmount)
                let hudView = HudView.hud(inView: view, animated: true)
                hudView.text = "Done"
                audioPlayer.play()
                delegate?.transactionComplete(sender: self)
                afterDelay(0.6){
                    hudView.hide()
                    self.dismiss(animated: true, completion: nil)
                }
            }
            catch {
                fatalError("Error: \(error)")
            }
        }
        else {
            errorDepositText.text! = "Please enter a valid amount"
        }
    }
}
