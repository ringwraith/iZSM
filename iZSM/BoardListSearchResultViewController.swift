//
//  BoardListSearchResultViewController.swift
//  iZSM
//
//  Created by Naitong Yu on 2017/8/13.
//  Copyright © 2017年 Naitong Yu. All rights reserved.
//

import UIKit

class BoardListSearchResultViewController: BaseTableViewController, UISearchControllerDelegate, UISearchBarDelegate, UISearchResultsUpdating {
    
    private let kBoardCellIdentifier = "BoardSearchResult"
    
    private var boards: [SMBoard] = []
    
    private var searchString = ""
    
    private var searchController = UISearchController(searchResultsController: nil)
    
    var completionHandler: ((SMBoard) -> Void)?
    
    func didPresentSearchController(_ searchController: UISearchController) {
        searchController.searchBar.becomeFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        dismiss(animated: true)
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        guard let currentSearchString = searchController.searchBar.text else { return }
        if currentSearchString.isEmpty, let topSearchResult = SMBoardInfoUtil.topSearchResult() {
            searchString = currentSearchString
            boards = topSearchResult
            tableView.reloadData()
            return
        }
        guard currentSearchString != searchString else { return }
        searchString = currentSearchString
        networkActivityIndicatorStart()
        var result: [SMBoard]?
        
        DispatchQueue.global().async {
            result = self.api.queryBoard(query: currentSearchString)
            DispatchQueue.main.async {
                networkActivityIndicatorStop()
                if currentSearchString != self.searchString { return } //模式已经改变，则丢弃数据
                self.boards.removeAll()
                if let result = result {
                    let filteredResult = result.filter { ($0.flag != -1) && ($0.flag & 0x400 == 0) }
                    self.boards += filteredResult
                    SMBoardInfoUtil.save(boardList: filteredResult)
                }
                self.tableView.reloadData()
                self.api.displayErrorIfNeeded()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.mj_header.isHidden = true
        definesPresentationContext = true
        if #available(iOS 9.1, *) {
            searchController.obscuresBackgroundDuringPresentation = false
        } else {
            searchController.dimsBackgroundDuringPresentation = false
        }
        searchController.delegate = self
        searchController.searchBar.delegate = self
        searchController.searchResultsUpdater = self
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = "版面名称/关键字搜索"
        tableView.tableHeaderView = searchController.searchBar
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // don't call super.viewDidAppear(_:) to avoid fatal error
        searchController.isActive = true
    }
    
    override func changeColor() {
        super.changeColor()
        if setting.nightMode {
            searchController.searchBar.barStyle = .black
        } else {
            searchController.searchBar.barStyle = .default
        }
    }
    
    override func clearContent() {
        boards.removeAll()
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let board = boards[indexPath.row]
        if (board.flag != -1) && (board.flag & 0x400 == 0) && (completionHandler != nil) {
            SMBoardInfoUtil.hitSearch(for: board)
            completionHandler!(board)
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if searchString.isEmpty {
            return true
        }
        return false
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let board = boards.remove(at: indexPath.row)
            SMBoardInfoUtil.clearSearchCount(for: board)
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.endUpdates()
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerFooterView = view as? UITableViewHeaderFooterView {
            headerFooterView.contentView.backgroundColor = AppTheme.shared.lightBackgroundColor
            headerFooterView.textLabel?.textColor = AppTheme.shared.textColor
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return boards.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let board = boards[indexPath.row]
        var cell: UITableViewCell
        if let newCell = tableView.dequeueReusableCell(withIdentifier: kBoardCellIdentifier) {
            cell = newCell
        } else {
            cell = UITableViewCell(style: .value1, reuseIdentifier: kBoardCellIdentifier)
        }
        cell.textLabel?.text = board.name
        cell.detailTextLabel?.text = board.boardID
        
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
        cell.textLabel?.textColor = AppTheme.shared.textColor
        cell.detailTextLabel?.textColor = AppTheme.shared.lightTextColor
        cell.backgroundColor = AppTheme.shared.backgroundColor
        let selectedBackgroundView = UIView(frame: cell.contentView.bounds)
        selectedBackgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cell.selectedBackgroundView = selectedBackgroundView
        cell.selectedBackgroundView?.backgroundColor = AppTheme.shared.selectedBackgroundColor
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 && searchString.isEmpty && !boards.isEmpty {
            return "搜索历史"
        }
        return nil
    }
    
    static func searchResultController(title: String?, completionHandler: ((SMBoard) -> Void)?) -> UIViewController {
        let searchResultController = BoardListSearchResultViewController()
        searchResultController.title = title
        searchResultController.completionHandler = completionHandler
        return NTNavigationController(rootViewController: searchResultController)
    }
}
