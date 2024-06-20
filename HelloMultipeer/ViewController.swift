//
//  HostVC.swift
//  MultipeerVideo-Assignment
//
//  Created by cleanmac on 16/01/23.
//

import UIKit
import AVFoundation
import Combine

class ViewController: UIViewController {
    
    private var viewModel: HostVM!
    private var disposables = Set<AnyCancellable>()
    

    var buttons = [UIButton]()
    var labels = [UILabel]()
    
    var connectionStatusLabel = UILabel()
    var connectionButton = UIButton()
    var imageView = UIImageView()
    private lazy var cameraFeedService = CameraFeedService()
    
    var sendImage = false
    
    func addButton(x: Int, y: Int, w: Int, h: Int, title: String, color: UIColor, selector: Selector) -> UIButton {
        let btn = UIButton()
        btn.frame = CGRect(x: x, y: y, width: w, height: h)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(color, for: .normal)
        btn.backgroundColor = .lightGray
        btn.addTarget(self, action: selector, for: .touchUpInside)
        view.addSubview(btn)
        buttons.append(btn)
        return btn
    }
    
    func addLabel(x: Int, y: Int, w: Int, h: Int, text: String, color: UIColor) -> UILabel {
        let label = UILabel()
        label.frame = CGRect(x: x, y: y, width: w, height: h)
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = color
        label.backgroundColor = .lightGray
        label.text = text
        view.addSubview(label)
        labels.append(label)
        return label
    }
    private func presentVideoConfigurationErrorAlert() {
        let alert = UIAlertController(title: "Camera Configuration Failed", message: "There was an error while configuring camera.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
    
    private func presentCameraPermissionsDeniedAlert() {
        let alertController = UIAlertController(
            title: "Camera Permissions Denied",
            message: "Camera permissions have been denied for this app. You can change this by going to Settings",
            preferredStyle: .alert
        )
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(settingsAction)
        
        present(alertController, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraFeedService.startLiveCameraSession { [weak self] cameraConfiguration in
            DispatchQueue.main.async {
                switch cameraConfiguration {
                case .failed:
                    self?.presentVideoConfigurationErrorAlert()
                case .permissionDenied:
                    self?.presentCameraPermissionsDeniedAlert()
                default:
                    break
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraFeedService.delegate = self
        
        viewModel = HostVM(viewController: self)
        setupImageView()
        connectionStatusLabel = addLabel(x: 10, y: 50, w: 150, h: 30, text: "lbl", color: .cyan)
        connectionButton = addButton(x: 10, y: 100, w: 150, h: 30, title: "connection", color: .darkGray, selector: #selector(showPeerBrowserModal))
        _ = addButton(x: 10, y: 150, w: 150, h: 30, title: "img, pls", color: .darkGray, selector: #selector(ask4image))
        setupBindings()
    }
    
    func setupImageView() {
        view.addSubview(imageView)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = view.bounds
    }
    
    private func setupBindings() {
        viewModel
            .$connectedPeers
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard !value.isEmpty else {
                    self?.connectionStatusLabel.text = "Not connected"
                    return
                }
                
                let peers = String(describing: value.map{ $0.displayName })
                self?.connectionStatusLabel.text = "Connected to: \(peers)"
            }.store(in: &disposables)
    }
    @objc func ask4image(){
        viewModel.sendText("Image, Please")
    }
    @objc func showPeerBrowserModal(){
        viewModel.showPeerBrowserModal()
    }
    
}

extension ViewController: CameraFeedServiceDelegate {
    func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        DispatchQueue.main.sync {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            guard let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else { return }
            let image = UIImage(cgImage: cgImage)
   
            if self.sendImage{
                viewModel.sendImageStream(image)
//                viewModel.sendImage(image)
                self.sendImage = false
            }
            self.imageView.image = image
        }
    }
    
    func didEncounterSessionRuntimeError() {
//        <#code#>
    }
    
    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
//        <#code#>
    }
    
    func sessionInterruptionEnded() {
//        <#code#>
    }
    
}
