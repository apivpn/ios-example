//
//  PacketTunnelProvider.swift
//  apiVPNTunnel
//
//  Created by Eric on 2022/11/22.
//

import NetworkExtension
import ApiVPN

public let apiServer = "api.devop.pw"
public let appGroup = "group.io.apivpn.ios.apivpn-ios-example"
public let keySelectedServerId = "selected_server_id"
public let appToken = "1dc5d3126b46dc79b3908b28c32ac7b9909d1d6b"

public enum TunnelError: Error {
    case ServerNotFounds
    case VPNStartFailed
    case Timeout
}

class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "240.0.0.1")
        settings.ipv4Settings = NEIPv4Settings(addresses: ["240.0.0.2"], subnetMasks: ["255.255.255.0"])
        settings.ipv4Settings?.includedRoutes = [NEIPv4Route.`default`()]
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1"])
        settings.mtu = 1500
        setTunnelNetworkSettings(settings) { error in
            let dataDir = FileManager().containerURL(forSecurityApplicationGroupIdentifier: appGroup)!.path
            ApiVpn.shared.initialize(appToken, apiServer, dataDir) { error in
                guard error == nil else {
                    print("Initialization error: \(error)")
                    completionHandler(error)
                    return
                }
                if let serverId = UserDefaults.init(suiteName: appGroup)?.integer(forKey: keySelectedServerId) {
                    DispatchQueue.global().async {
                        NSLog("Start server \(serverId)")
                        let altRules = """
{
  "rules": [
    {
      "ip": ["1.1.1.1"],
      "outboundTag": "Proxy"
    }
  ]
}
"""
                        ApiVpn.shared.start_v2ray(Int32(serverId), self.packetFlow, altRules) { error in
                            guard error == nil else {
                                NSLog("Start V2Ray error: \(error)")
                                completionHandler(error)
                                return
                            }
                        }
                    }
                    DispatchQueue.global().async {
                        for i in 1...10 {
                            Thread.sleep(forTimeInterval: 1)
                            if (ApiVpn.shared.is_running()) {
                                NSLog("VPN started.")
                                completionHandler(nil)
                                return
                            }
                        }
                        completionHandler(TunnelError.Timeout)
                    }
                } else {
                    completionHandler(TunnelError.ServerNotFounds)
                }
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        ApiVpn.shared.stop()
        NSLog("VPN tunnel stopped.")
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
}
