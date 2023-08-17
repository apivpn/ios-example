//
//  HomeController.swift
//  apivpn-ios-example
//
//  Created by Eric on 2022/12/2.
//

import UIKit
import NetworkExtension
import ApiVPN

class HomeController: UITableViewController {
    
    public var vpnManager = NEVPNManager.shared()
    
    let dataDir = FileManager().containerURL(forSecurityApplicationGroupIdentifier: appGroup)!.path
        
    @IBOutlet weak var vpnToggleBtn: UIButton!
    
    @IBOutlet weak var selectedServerLabel: UILabel!
    
    @IBAction func toggleVpn(_ sender: Any) {
        self.vpnManager.isEnabled = true
        self.vpnManager.saveToPreferences { error in
            guard error == nil else {
                print("Unable to save VPN configuration: \(String(describing: error))")
                return
            }
            self.vpnManager.loadFromPreferences { error in
                guard error == nil else {
                    print("Unable to load VPN configuration: \(String(describing: error))")
                    return
                }

                NotificationCenter.default.addObserver(self, selector: #selector(self.updateVpnStatus), name: NSNotification.Name.NEVPNStatusDidChange, object: self.vpnManager.connection)

                switch self.vpnManager.connection.status {
                case .disconnected, .invalid:
                    do {
                        try self.vpnManager.connection.startVPNTunnel()
                    } catch {
                        print("Unable to start VPN tunnel: \(error)")
                    }
                default:
                    self.vpnManager.connection.stopVPNTunnel()
                    // Prints the transfered connections after VPN stop
                    self.printConnections()
                }
            }
        }
    }
    
    func printConnections() {
        ApiVpn.shared.connection_log_file() { path, error in
            guard error == nil else {
                print("Unable to get connection log file: \(error)")
                return
            }
            if let path = path {
                do {
                    let data = try String(contentsOfFile: path, encoding: .utf8)
                    let lines = data.components(separatedBy: .newlines)
                    for line in lines {
                        print(line)
                    }
                } catch {
                    print("Unable to read file \(path): \(error)")
                }
            }
        }
    }
    
    func loadOrCreateVPNManager(completionHandler: @escaping (Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences(completionHandler: { managers, error in
            guard let managers = managers, error == nil else {
                completionHandler(error)
                return
            }
            // Take an existing VPN configuration or create a new one if none exist.
            if managers.count > 0 {
                self.vpnManager = managers[0]
            } else {
                let manager = NETunnelProviderManager()
                manager.protocolConfiguration = NETunnelProviderProtocol()
                manager.localizedDescription = "apiVPN"
                manager.protocolConfiguration?.serverAddress = "apiVPN"
                manager.saveToPreferences { error in
                    guard error == nil else {
                        completionHandler(error)
                        return
                    }
                    manager.loadFromPreferences { error in
                        self.vpnManager = manager
                    }
                }
            }
            completionHandler(nil)
        })
    }

    @objc func updateVpnStatus() {
        // Update button label according to VPN connection status.
        switch vpnManager.connection.status {
        case .connected:
            vpnToggleBtn.setTitle("Connected", for: .normal)
            break
        case .connecting:
            vpnToggleBtn.setTitle("Connecting", for: .normal)
            break
        case .disconnected:
            vpnToggleBtn.setTitle("Disconnected", for: .normal)
            break
        case .disconnecting:
            vpnToggleBtn.setTitle("Disconnecting", for: .normal)
            break
        case .invalid:
            vpnToggleBtn.setTitle("Invalid", for: .normal)
            break
        case .reasserting:
            vpnToggleBtn.setTitle("Reasserting", for: .normal)
            break
        default:
            vpnToggleBtn.setTitle("Unknown", for: .normal)
        }
    }
    
    func updateUI() {
        ApiVpn.shared.initialize(appToken, apiServer, dataDir) { error in
            guard error == nil else {
                print("Initialization error: \(error)")
                return
            }
            ApiVpn.shared.servers() { servers, error in
                guard error == nil, let servers = servers else {
                    print("Server list error: \(error)")
                    return
                }
                if let selectedId = UserDefaults.init(suiteName: appGroup)?.integer(forKey: keySelectedServerId) {
                    for server in servers {
                        if server.id == selectedId {
                            DispatchQueue.main.async {
                                self.selectedServerLabel.text = server.name
                            }
                        }
                    }
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.updateVpnStatus()
        
        // Load or create a VPN configuration, this will ask user for VPN permission for the first time.
        loadOrCreateVPNManager(completionHandler: { error in
            guard error == nil else {
                print("Unable to load or create VPN manager: \(String(describing: error))")
                return
            }
            self.updateVpnStatus()
            // Observe VPN connection status changes.
            NotificationCenter.default.addObserver(self, selector: #selector(self.updateVpnStatus), name: NSNotification.Name.NEVPNStatusDidChange, object: self.vpnManager.connection)
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: self.vpnManager.connection)
    }
}
