//
//  ViewController.swift
//  DAVisionML
//
//  Created by Danilo Altheman on 25/03/18.
//  Copyright © 2018 Apple Inc. All rights reserved.
//

import UIKit
import Vision
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var resultsLabel: UILabel!
    @IBOutlet weak var dragButton: UIButton!
    
    var cameraDevice: AVCaptureDevice?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureHandler(panGesture:)))
        self.dragButton.addGestureRecognizer(gesture)
        
        setupCaptureSession()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    @IBAction func zoomInCamera(_ sender: Any) {
        if let camera = cameraDevice {
            try? camera.lockForConfiguration()
            camera.focusMode = .continuousAutoFocus
            camera.videoZoomFactor = 10
            camera.unlockForConfiguration()
        }
    }
    
    
    var buttonOrigin : CGPoint = CGPoint(x: 0, y: 0)
    
    @objc func panGestureHandler(panGesture recognizer: UIPanGestureRecognizer) {
        print("Being Dragged")
        if recognizer.state == .began {
            print("panIF")
            buttonOrigin = recognizer.location(in: dragButton)
        }else {
            print("panELSE")
            let location = recognizer.location(in: view) // get pan location
            dragButton.frame.origin = CGPoint(x: location.x - buttonOrigin.x, y: location.y - buttonOrigin.y)
        }
    }
    
    func setupCaptureSession() {
        let captureSession = AVCaptureSession()
        let availableDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInDualCamera], mediaType: .video, position: .back).devices
        if let captureDevice = availableDevices.first {
            do {
                cameraDevice = captureDevice
                let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
                captureSession.addInput(captureDeviceInput)
            } catch {
                let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        }

        let captureOutput = AVCaptureVideoDataOutput()
        captureOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(captureOutput)

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.frame

        view.layer.insertSublayer(previewLayer, at: 0)
        captureSession.startRunning()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let model = try? VNCoreMLModel(for: MoneyClassification().model) else {
            fatalError("Unexpected error loading model")
        }
        let modelRequest = VNCoreMLRequest(model: model) { (request, _) in
            guard let observations = request.results as? [VNClassificationObservation] else {
                fatalError("Unexpected result from VNCOreMLRequest")
            }
            guard let best = observations.first else {
                fatalError("Cannot get the best result observation")
            }
            DispatchQueue.main.async {
                let percentage: Float = Float(best.confidence) * 100
                self.resultsLabel.text = String(format: "Sure %.2f%% is %@", percentage, best.identifier)
            }
        }
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? imageRequestHandler.perform([modelRequest])
    }
}
