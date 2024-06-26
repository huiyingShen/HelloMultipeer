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
    
    private var circleLayer = CAShapeLayer()
    private var combinedPath = UIBezierPath()
    private var vPoint = [CGPoint]()
    
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
        setupImageView()
        
        viewModel = HostVM(viewController: self)
        connectionStatusLabel = addLabel(x: 10, y: 50, w: 150, h: 30, text: "lbl", color: .cyan)
        connectionButton = addButton(x: 10, y: 100, w: 150, h: 30, title: "connection", color: .darkGray, selector: #selector(showPeerBrowserModal))
        _ = addButton(x: 10, y: 150, w: 150, h: 30, title: "img, pls", color: .darkGray, selector: #selector(ask4image))
        _ = addButton(x: 10, y: 200, w: 150, h: 30, title: "send data", color: .darkGray, selector: #selector(sendData))
        _ = addButton(x: 10, y: 250, w: 150, h: 30, title: "redraw", color: .darkGray, selector: #selector(redraw))
        setupBindings()
        

    }
    
    func clearCalib(){
        vPoint.removeAll()
    }
    
    @objc func sendData(){
        print("imageView.frme = \(imageView.frame.width), \(imageView.frame.height)")
        if let im = imageView.image{
            print("im.size = \(im.size)")
            var txt = "calib data\n"
            txt.append((String(format: "%.1f, %.1f\n",imageView.frame.width, imageView.frame.height)))
            for p in vPoint{
                txt.append(String(format: "%.1f, %.1f\n", p.x,p.y))
            }
            print(txt)
            viewModel.sendText(txt)
        }
    }
    
    @objc func imageTapped(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: view)
        addCircle(at: location)
    }
    func addCalibPoint(_ p:CGPoint){
        print("added point: \(p)")
        vPoint.append(p)
    }
    func addCircle(at point: CGPoint) {
        if (imageView.image != nil){
            guard let p = imageViewToImageCoordinates(imageViewSize: imageView.bounds.size, imageSize: imageView.image!.size, pointInImageView: point) else { return }
            addCalibPoint(p)
        }
        let circlePath = UIBezierPath(arcCenter: point, radius: 3, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        combinedPath.append(circlePath)
        circleLayer.path = combinedPath.cgPath
    }
    
    @objc func redraw(){
        combinedPath = UIBezierPath()
        for p in vPoint{
            let point = imageToImageViewCoordinates(imageViewSize: imageView.bounds.size, imageSize: imageView.image!.size, pointInImage: p)
            combinedPath.append(UIBezierPath(arcCenter: point, radius: 5, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true))
        }
        circleLayer.path = combinedPath.cgPath
        circleLayer.displayIfNeeded()
    }
    
    
    func setupImageView() {
        imageView.isUserInteractionEnabled = true
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        imageView.addGestureRecognizer(tapGestureRecognizer)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = view.bounds
        view.addSubview(imageView)
        
        circleLayer.frame = view.frame
        circleLayer.lineWidth = 3.0
        circleLayer.strokeColor = UIColor.red.cgColor
        circleLayer.fillColor = nil
        view.layer.addSublayer(circleLayer)
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
extension UIViewController{
    func calculateScaleAndOffset(imageViewSize: CGSize, imageSize: CGSize) -> (scaleFactor: CGFloat, offset: CGPoint) {
//        let imageViewSize = imageView.bounds.size
//        let imageSize = image.size
//        print(imageView.bounds)
        
        // Calculate aspect ratios
        let imageViewAspectRatio = imageViewSize.width / imageViewSize.height
        let imageAspectRatio = imageSize.width / imageSize.height
        
        var scaledImageSize: CGSize
        var scaleFactor: CGFloat
        
        if imageAspectRatio > imageViewAspectRatio {
            // Image is wider than imageView
            scaleFactor = imageViewSize.width / imageSize.width
            scaledImageSize = CGSize(width: imageViewSize.width, height: imageSize.height * scaleFactor)
        } else {
            // Image is taller than imageView
            scaleFactor = imageViewSize.height / imageSize.height
            scaledImageSize = CGSize(width: imageSize.width * scaleFactor, height: imageViewSize.height)
        }
        
        // Calculate the offsets
        let xOffset = (imageViewSize.width - scaledImageSize.width) / 2
        let yOffset = (imageViewSize.height - scaledImageSize.height) / 2
        
        return (scaleFactor, CGPoint(x:xOffset, y:yOffset))
    }

    func imageViewToImageCoordinates(imageViewSize: CGSize, imageSize: CGSize, pointInImageView: CGPoint) -> CGPoint? {
        let (scaleFactor, offset) = calculateScaleAndOffset(imageViewSize: imageViewSize, imageSize: imageSize)
        // Check if the point is within the scaled image bounds
        guard pointInImageView.x >= offset.x, pointInImageView.x <= offset.x + imageSize.width * scaleFactor,
              pointInImageView.y >= offset.y, pointInImageView.y <= offset.y + imageSize.height * scaleFactor else {
            return nil
        }
        return CGPoint(x: (pointInImageView.x - offset.x) / scaleFactor, y: (pointInImageView.y - offset.y) / scaleFactor)
    }

    func imageToImageViewCoordinates(imageViewSize: CGSize, imageSize: CGSize, pointInImage: CGPoint) -> CGPoint {
        let (scaleFactor, offset) = calculateScaleAndOffset(imageViewSize: imageViewSize, imageSize: imageSize)
        return CGPoint(x: pointInImage.x * scaleFactor + offset.x, y: pointInImage.y * scaleFactor + offset.y)
    }
}
