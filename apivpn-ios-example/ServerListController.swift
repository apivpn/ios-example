//
//  ServerListController.swift
//  apivpn-ios-example
//
//  Created by Eric on 2022/12/3.
//

import UIKit
import ApiVPN

class ServerListController: UITableViewController {
    
    @IBOutlet var table: UITableView!
    
    var servers: [Server] = []
    var selected: Int?
    
    func endLoading() {
        DispatchQueue.main.async {
            self.table.reloadData()
            self.refreshControl?.endRefreshing()
        }
    }
    
    @objc func load() {
        let dataDir = FileManager().containerURL(forSecurityApplicationGroupIdentifier: appGroup)!.path
        print(dataDir)

        let fileManager = FileManager.default
        do {
            let dataPath = FileManager().containerURL(forSecurityApplicationGroupIdentifier: appGroup)!
            let pathToken = dataPath.appendingPathComponent("APIVPN_CUSTOMER_TOKEN")
            let text2 = try String(contentsOf: pathToken, encoding: .utf8)
            print(text2)
        } catch {
            let dataPath = FileManager().containerURL(forSecurityApplicationGroupIdentifier: appGroup)!
            print("Error while enumerating files \(dataPath.path): \(error.localizedDescription)")
        }
        
        ApiVpn.shared.initialize(appToken, apiServer, dataDir) { error in
            guard error == nil else {
                print("Initialization error: \(error)")
                self.endLoading()
                return
            }
            ApiVpn.shared.servers() { servers, error in
                guard error == nil, let servers = servers else {
                    print("Server list error: \(error)")
                    self.endLoading()
                    return
                }
                self.servers = servers
                self.reload()
            }
        }
    }
    
    func reload() {
        if let id = UserDefaults.init(suiteName: appGroup)?.integer(forKey: keySelectedServerId) {
            selected = id
        }
        endLoading()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.refreshControl = UIRefreshControl()
        tableView.addSubview(self.refreshControl!)
        refreshControl?.addTarget(self, action: #selector(load), for: .valueChanged)
        refreshControl?.beginRefreshing()
        load()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return servers.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "server-item", for: indexPath)
        let server = servers[indexPath.row]
        cell.textLabel?.text = server.name
        cell.accessoryType = .none
        if let selected {
            if server.id == selected {
                cell.accessoryType = .checkmark
            }
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedServer = servers[indexPath.row]
        UserDefaults.init(suiteName: appGroup)?.set(selectedServer.id, forKey: keySelectedServerId)
        reload()
    }
}
