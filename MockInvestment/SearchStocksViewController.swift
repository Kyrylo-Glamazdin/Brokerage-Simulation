//
//  SearchStocksViewController.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/7/20.
//

import UIKit
import CoreData

class SearchStocksViewController: UIViewController {
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    var stateController: StateController!
    var stockSearchResults: [AvailableStock] = []
    var segmentedControlValue: Int = 0
    var searchBarInput: String = ""
    var selectedStock: AvailableStock?
    var managedObjectContext: NSManagedObjectContext!

    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        afterDelay(0.6){
            self.searchBar.becomeFirstResponder()
        }
        
        let cellNib = UINib(nibName: "NoResultsCell", bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: "NoResultsCell")
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)
    }
    
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        segmentedControlValue = sender.selectedSegmentIndex
    }
    
    func performLocalStockSearch(){
        stockSearchResults = []
        if searchBarInput.count == 0 {
        }
        else {
            if segmentedControlValue == 1 {
                for stock in stateController.availableStocks {
                    if stock.stockDescription.index(of: searchBarInput) != nil {
                        stockSearchResults.append(stock)
                    }
                }
            }
            else {
                for stock in stateController.availableStocks {
                    if stock.stockSymbol.index(of: searchBarInput) != nil && stock.stockDescription.count > 0 {
                        stockSearchResults.append(stock)
                    }
                }
                self.stockSearchResults.sort(by: symbolSizeSort)

            }
        }
        tableView.reloadData()
    }
    
}

extension SearchStocksViewController: UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    func tableView (_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        if (stockSearchResults.isEmpty){
            if searchBarInput.count > 0 {
                return 1
            }
            else {
                return 0
            }
        }
        else {
            return stockSearchResults.count
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let emptyCell = tableView.dequeueReusableCell(withIdentifier: "NoResultsCell", for: indexPath)
        if stockSearchResults.isEmpty {
            return emptyCell
        }
        
        let cellIdentifier = "StockSearchResultCell"
        
        var cell: UITableViewCell! = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: cellIdentifier)
        }

        let stock = stockSearchResults[indexPath.row]
        cell.textLabel!.text = stock.stockDescription
        cell.detailTextLabel!.text = stock.stockSymbol
        return cell
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange: String){
        searchBarInput = searchBar.text!.uppercased()
        performLocalStockSearch()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if stockSearchResults.count > 0 {
            self.selectedStock = stockSearchResults[indexPath.row]
            tableView.deselectRow(at: indexPath, animated: false)
            self.performSegue(withIdentifier: "ViewIndividualStock", sender: self)
        }
        else {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let individualStockViewController = segue.destination as! IndividualStockViewController
        individualStockViewController.managedObjectContext = managedObjectContext
        if selectedStock != nil {
            individualStockViewController.stockObj = selectedStock
        }
    }
    
 }

//code from StackOverflow (https://stackoverflow.com/questions/32305891/index-of-a-substring-in-a-string-with-swift)
extension StringProtocol {
    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }
    func endIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.upperBound
    }
    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
        ranges(of: string, options: options).map(\.lowerBound)
    }
    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
            let range = self[startIndex...]
                .range(of: string, options: options) {
                result.append(range)
                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}
