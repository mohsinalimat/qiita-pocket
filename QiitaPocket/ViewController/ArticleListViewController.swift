//
//  ArticleListViewController.swift
//  
//
//  Created by hirothings on 2016/05/04.
//
//

import UIKit
import RxSwift
import RxCocoa
import SafariServices


class ArticleListViewController:  UIViewController, UITableViewDataSource, UITableViewDelegate, SwipeCellDelegate, UISearchBarDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var topIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var bottomIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var noneDataLabel: UILabel!

    var articles: [Article] = []
    var refreshControll = UIRefreshControl()
    
    private var viewModel: ArticleListViewModel!
    private var fetchTrigger = PublishSubject<String>()
    private var searchArticleVC = SearchArticleViewController()
    private var searchBar: UISearchBar!
    private let bag = DisposeBag()
    private var nvc: ArticleListNavigationController!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let nib: UINib = UINib(nibName: "ArticleTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "ArticleTableViewCell")
        
        viewModel = ArticleListViewModel(fetchTrigger: fetchTrigger)
        
        tableView.estimatedRowHeight = 103.0
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.separatorInset = UIEdgeInsets.zero
        tableView.sectionHeaderHeight = 30.0
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.isHidden = true
        noneDataLabel.isHidden = true
        
        nvc = self.navigationController as! ArticleListNavigationController
        searchBar = nvc.searchBar
        searchBar.delegate = self
        
        tableView.refreshControl = refreshControll
        
        bottomIndicatorView.hidesWhenStopped = true
        topIndicatorView.hidesWhenStopped = true
        
        
        // bind
        
        tableView.rx.reachedBottom
            .asDriver()
            .drive(viewModel.loadNextPageTrigger)
            .disposed(by: bag)
        
        refreshControll.rx.controlEvent(.valueChanged)
            .startWith(())
            .flatMap { Observable.just(UserSettings.getcurrentTag()) }
            .bind(to: fetchTrigger)
            .addDisposableTo(bag)
        
        viewModel.isLoading
            .do(onNext: { [weak self] in
                self?.noneDataLabel.isHidden = $0
            })
            .drive(UIApplication.shared.rx.isNetworkActivityIndicatorVisible)
            .addDisposableTo(bag)
        
        viewModel.isLoading
            .drive(bottomIndicatorView.rx.isAnimating)
            .addDisposableTo(bag)
        
        viewModel.isLoading
            .drive(topIndicatorView.rx.isAnimating)
            .addDisposableTo(bag)
        
        viewModel.hasData.asObservable()
            .skip(1)
            .bind(to: noneDataLabel.rx.isHidden)
            .addDisposableTo(bag)
        
        viewModel.firstLoad
            .bind(onNext: { [unowned self] articles in
                print("first load done")
                
                self.articles = articles
                self.setUpBottomView()
                self.tableView.reloadData()
                let topIndexPath = IndexPath(row: 0, section: 0)
                self.tableView.scrollToRow(at: topIndexPath, at: .top, animated: false)
                self.tableView.isHidden = false
                self.refreshControll.endRefreshing()
            })
            .addDisposableTo(bag)
        
        viewModel.additionalLoad
            .bind(onNext: { [unowned self] articles in
                print("additional load done")

                let indexPath: [IndexPath] = Array(self.articles.count..<articles.count).map { IndexPath(row: $0, section: 0) }
                self.articles = articles
                self.tableView.insertRows(at: indexPath, with: .none)
            })
            .disposed(by: bag)
        
        viewModel.alertTrigger
            .asObservable()
            .bind(onNext: { [weak self] in
                self?.showAlert(message: $0)
            })
            .disposed(by: bag)
    }
    
    
    // MARK: - TableView DataSource
    
    /// tableViewの行数を指定
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return articles.count
    }
    
    /// tableViewのcellを生成
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ArticleTableViewCell", for: indexPath) as! ArticleTableViewCell
        cell.article = articles[indexPath.row]
        cell.delegate = self
        
        return cell
    }
    
    
    // MARK: - TableView Delegate
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label: UILabel = {
            let lb = UILabel(frame: CGRect(x: 10.0, y: 0.0, width: UIScreen.main.bounds.width, height: 30.0))
            lb.text = viewModel.searchTitle
            lb.textColor = UIColor.white
            lb.font = UIFont.boldSystemFont(ofSize: 12.0)
            return lb
        }()
        
        let view: UIView = {
            let v = UIView()
            v.backgroundColor = viewModel.titleColor
            return v
        }()
        
        view.addSubview(label)
        return view
    }
    
    /// tableViewタップ時webViewに遷移する
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let article = articles[indexPath.row]
        
        guard let url = URL(string: article.url) else { return }
        let safariVC = SFSafariViewController(url: url)
        safariVC.modalPresentationStyle = .popover
        self.present(safariVC, animated: true, completion: nil)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }

    
    // MARK: - SwipeCellDelegate
    
    func isSwipingCell(isSwiping: Bool) {
        tableView.panGestureRecognizer.isEnabled = !(isSwiping)
    }
    
    func didSwipe(cell: UITableViewCell) {
        tableView.beginUpdates()
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        let article = articles[indexPath.row]
        ArticleManager.add(readLater: article) // Realmに記事を保存
        
        articles.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        tableView.endUpdates()
    }
    
    
    // MARK: - Private Method
    
    /// 検索ViewControllerをセット
    private func setupSearchArticleVC() {
        searchArticleVC = self.storyboard!.instantiateViewController(withIdentifier: "SearchArticleViewController") as! SearchArticleViewController
        self.addChildViewController(searchArticleVC)
        self.view.addSubview(searchArticleVC.view)
        searchArticleVC.didMove(toParentViewController: self)
        
        // 検索履歴タップ時のイベント
        searchArticleVC.didSelectSearchHistory
            .subscribe(onNext: { [unowned self] (tag: String) in
                self.searchBar.text = tag
                self.fetchTrigger.onNext(tag)
                self.searchBar.endEditing(true)
                self.searchBar.showsCancelButton = false
                self.removeSearchArticleVC()
                self.tableView.isHidden = true
            })
            .addDisposableTo(bag)
        
        nvc.unsetSettingButton()
    }
    
    /// 検索ViewControllerを削除
    private func removeSearchArticleVC() {
        searchArticleVC.willMove(toParentViewController: self)
        searchArticleVC.view.removeFromSuperview()
        searchArticleVC.removeFromParentViewController()
        nvc.setupSettingButton()
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let defAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(defAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    private func setUpBottomView() {
        let rect = CGRect(x: bottomView.bounds.origin.x,
                          y: bottomView.bounds.origin.y,
                          width: bottomView.bounds.width,
                          height: viewModel.bottomViewHeight)
        self.bottomView.frame = rect
    }
    
    
    // MARK: - UISearchBarDelegate
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        setupSearchArticleVC()
        searchBar.showsCancelButton = true
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        removeSearchArticleVC()
        searchBar.endEditing(true)
        searchBar.showsCancelButton = false
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        removeSearchArticleVC()
        searchBar.endEditing(true)
        searchBar.showsCancelButton = false
        fetchTrigger.onNext(searchBar.text!)
        self.tableView.isHidden = true
    }
}
