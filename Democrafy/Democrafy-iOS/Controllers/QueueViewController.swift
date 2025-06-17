import UIKit

class QueueViewController: UIViewController {
    private let tableView = UITableView()
    private let viewModel: QueueViewModel
    
    init(room: PartyRoom) {
        viewModel = QueueViewModel(room: room)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        viewModel.fetchSuggestions()
    }
    
    private func setupUI() {
        title = viewModel.room.name
        view.backgroundColor = .systemBackground
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TrackCell")
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Search", style: .plain, target: self, action: #selector(showSearch))
    }
    
    @objc private func showSearch() {
        let searchVC = SearchViewController(room: viewModel.room)
        navigationController?.pushViewController(searchVC, animated: true)
    }
}

extension QueueViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.suggestions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TrackCell", for: indexPath)
        let suggestion = viewModel.suggestions[indexPath.row]
        cell.textLabel?.text = suggestion.title
        cell.detailTextLabel?.text = suggestion.artist
        return cell
    }
}
