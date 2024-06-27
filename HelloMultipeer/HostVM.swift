//
//  HostVM.swift
//  MultipeerVideo-Assignment
//
//  Created by cleanmac on 16/01/23.
//

import Foundation
import Combine
import MultipeerConnectivity
import AVKit

enum RecordingState: String {
    case notRecording
    case isRecording
    case finishedRecording
}

final class HostVM: NSObject, ObservableObject {
    private let serviceType = "camio-peer"
    private let peerId = MCPeerID(displayName: UIDevice.current.name)
    private let peerAdvertiser: MCNearbyServiceAdvertiser
    private let peerBrowser: MCNearbyServiceBrowser
    private let peerSession: MCSession
    private let peerBrowserVc: MCBrowserViewController
    private weak var viewController: ViewController?
    
    var receivedData = Data()
    var receivedImageData = Data()
    var receivedImageDataFromStream = UIImage()
    
    
    @Published private(set) var connectedPeers: [MCPeerID] = []

    
    init(viewController: ViewController) {
        peerSession = MCSession(peer: peerId, securityIdentity: nil, encryptionPreference: .none)
        peerBrowser = MCNearbyServiceBrowser(peer: peerId, serviceType: serviceType)
        peerBrowserVc = MCBrowserViewController(serviceType: serviceType, session: peerSession)
        peerAdvertiser = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: nil, serviceType: serviceType)
        self.viewController = viewController
        
        super.init()
        
        peerSession.delegate = self
        peerBrowser.delegate = self
        peerBrowserVc.delegate = self


        peerAdvertiser.delegate = self
        peerAdvertiser.startAdvertisingPeer()

    }
    
    
    func changeState() {
//        do {
//            if recordingState == .notRecording {
//                recordingState = .isRecording
//            } else if recordingState == .isRecording {
//                recordingState = .finishedRecording
//            } else {
//                recordingState = .notRecording
//            }
//            
//            try peerSession.send(recordingState.rawValue.data(using: .utf8)!,
//                             toPeers: connectedPeers,
//                             with: .reliable)
//        } catch {
//            print(error.localizedDescription)
//            recordingState = .notRecording
//        }
    }
    
    func showPeerBrowserModal() {
        viewController?.present(peerBrowserVc, animated: true)
    }

}

extension HostVM: MCSessionDelegate,StreamDelegate {
    
    func session(_ session: MCSession,
                 peer peerID: MCPeerID,
                 didChange state: MCSessionState) {
        print("State \(state.rawValue)")
        connectedPeers = session.connectedPeers
    }
    func s2float2(_ s:String) -> (Float,Float){
        let p = s.split(separator: " ")
        let x  = (p[0] as NSString).floatValue
        let y  = (p[1] as NSString).floatValue
        return (x,y)
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        print("data received: \(data)")
        if let message = String(data: data, encoding: .utf8) {
            print("Received message: \(message) from \(peerID.displayName)")
            if message.contains("Image, Please"){
                viewController?.sendImage = true
            } else if message.contains("Landmark Data:"){
                let dat = message.split(separator: "\n")
//                let wh = s2float2(String(dat[1]))
//                print("w, h = \(wh.0), \(wh.1)")
                viewController?.clearCalib()
                for p in dat[1...]{
                    print(p)
                    let xy = s2float2(String(p))
                    viewController?.addCalibPoint(CGPoint(x:Double(xy.0),y:Double(xy.1)))
                }
                viewController?.redraw()
            }
        }
    }
    
    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 with progress: Progress) {
        
    }
    
    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 at localURL: URL?,
                 withError error: Error?) {
        
    }
    
    func sendData(data: Data) {
        do {
            try peerSession.send(data, toPeers: peerSession.connectedPeers, with: .reliable)
            print("Data sent successfully.")
        } catch {
            print("Error sending data: \(error.localizedDescription)")
        }
    }
    
    func sendText(_ txt: String){
        sendData(data: txt.data(using: .utf8)!)
    }
    
    func sendImage(_ image: UIImage){
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            sendLargeData(imageData)
        }
    }
    
    func sendLargeData(_ data: Data) {
        let chunkSize = 8192 // 8 KB chunks
        var offset = 0

        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            let chunk = data.subdata(in: offset..<end)
            do {
                try peerSession.send(chunk, toPeers: peerSession.connectedPeers, with: .reliable)
            } catch {
                print("Error sending chunk: \(error.localizedDescription)")
            }
            offset += chunkSize
        }
    }
    
    func sendImageStream(_ image: UIImage) {
        print("in sendImageStream()")
        if peerSession.connectedPeers.isEmpty {
            print("peerSession.connectedPeers.isEmpty!!!")
            return
        }
        if let imageData = image.jpegData(compressionQuality: 0.25),
           let outputStream = try? peerSession.startStream(withName: "imageStream", toPeer: peerSession.connectedPeers.first!) {
            outputStream.open()
            _ = imageData.withUnsafeBytes { outputStream.write($0, maxLength: imageData.count) }
            outputStream.close()
        }
    }
    
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("didReceive stream:")
        if streamName == "imageStream" {
            stream.delegate = self
            stream.schedule(in: .main, forMode: .default)
            stream.open()
        }
    }

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
//        print("in func stream()")
        guard let inputStream = aStream as? InputStream else { return }

        switch eventCode {
        case .hasBytesAvailable:
            var buffer = [UInt8](repeating: 0, count: 8192)
            let bytesRead = inputStream.read(&buffer, maxLength: buffer.count)
            if bytesRead > 0 {
                receivedImageData.append(buffer, count: bytesRead)
            }
        case .endEncountered:
            inputStream.close()
            inputStream.remove(from: .main, forMode: .default)
            if let image = UIImage(data: receivedImageData) {
                // Use the image
                receivedImageDataFromStream = image
                loadImage(image)
            }
            receivedImageData = Data() // Reset for next transfer
        default:
            break
        }
    }
    
    func loadImage(_ image: UIImage){
        print("loadImage(), image.size = \(image.size)")
        self.viewController?.imageView.image = image
    }
}

extension HostVM: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, peerSession)
    }
    
}

extension HostVM: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String : String]?) {
        
    }
    
    func browser(_ browser: MCNearbyServiceBrowser,
                 lostPeer peerID: MCPeerID) {
        
    }
    
}

extension HostVM: MCBrowserViewControllerDelegate {
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true)
    }
}
