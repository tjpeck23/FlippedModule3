//
//  BodyViewController.swift
//  VisionFaceTrack
//
//  Created by Cady Studdard on 11/3/24.
//  Copyright © 2024 Apple. All rights reserved.
//

import UIKit
import AVKit
import Vision

//automatic fix by Xcode for detecting human body pose
@available(iOS 14.0, *)
class BodyViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var previewView: UIView!
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var videoDataOutput: AVCaptureVideoDataOutput?
    var detectionOverlay: CALayer?
    
    // Request for detecting human body pose
    private var bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAVCaptureSession()
        setupOverlay()
    }
    
    func setupAVCaptureSession() {
        session = AVCaptureSession()
        guard let session = session else { return }
        
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return }
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)
        
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        session.addOutput(videoDataOutput!)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.frame = previewView.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(previewLayer!)
        
        session.startRunning()
    }
    
    func setupOverlay() {
        detectionOverlay = CALayer()
        detectionOverlay?.frame = previewView.bounds
        previewView.layer.addSublayer(detectionOverlay!)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
    }
    
}
