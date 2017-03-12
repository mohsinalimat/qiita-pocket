//
//  SearchArticleViewController.swift
//  QiitaPocket
//
//  Created by hirothings on 2017/02/11.
//  Copyright © 2017年 hirothings. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class SearchArticleViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var sortSegment: UISegmentedControl!
    @IBOutlet weak var periodSegment: UISegmentedControl!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var contentViewHeight: NSLayoutConstraint!
    
    var didSelectSearchHistory = PublishSubject<String>()
    
    private let bag = DisposeBag()
    private let searchHistories: [String] = SearchHistory.tags
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initSegmentValue()
        saveSearchSettings()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView(frame: CGRect.zero)
    }
    
    override func viewDidLayoutSubviews() {
        let tablecellHeight: CGFloat = 44.0
        // tableView分の高さを追加する
        contentViewHeight.constant = tablecellHeight * CGFloat(searchHistories.count)
    }
    
    
    // MARK: - TableView Delegate

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchHistories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CustomCell", for: indexPath)
        cell.textLabel?.text = searchHistories[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let history = searchHistories[indexPath.row]
        didSelectSearchHistory.onNext(history)
    }
    
    
    // MARK: - Private Method
    
    func initSegmentValue() {
        guard let sortType = UserSettings.getSearchSort() else {
            return
        }
        guard let periodType = UserSettings.getSearchPeriod() else {
            return
        }
        
        switch sortType {
        case .recent:
            sortSegment.selectedSegmentIndex = 0
        case .popular:
            sortSegment.selectedSegmentIndex = 1
        }
        
        switch periodType {
        case .all:
            periodSegment.selectedSegmentIndex = 0
        case .month:
            periodSegment.selectedSegmentIndex = 1
        case .week:
            periodSegment.selectedSegmentIndex = 2
        }
    }
    
    func saveSearchSettings() {
        sortSegment.rx.value
            .subscribe(onNext: { index in
                switch index {
                case 0:
                    UserSettings.setSearchSort(SearchSort.recent)
                case 1:
                    UserSettings.setSearchSort(SearchSort.popular)
                default:
                    break
                }
            })
            .addDisposableTo(bag)
        
        periodSegment.rx.value
            .subscribe(onNext: { index in
                switch index {
                case 0:
                    UserSettings.setSearchPeriod(SearchPeriod.all)
                case 1:
                    UserSettings.setSearchPeriod(SearchPeriod.month)
                case 2:
                    UserSettings.setSearchPeriod(SearchPeriod.week)
                default:
                    break
                }
            })
            .addDisposableTo(bag)
    }
    
}
