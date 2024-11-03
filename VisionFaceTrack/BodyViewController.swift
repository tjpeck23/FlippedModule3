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
        
        do {
                   try requestHandler.perform([bodyPoseRequest])
                   if let results = bodyPoseRequest.results, !results.isEmpty {
                       handleBodyPose(results)
                   }
               } catch {
                   print("Failed to perform body pose request: \(error)")
               }
        
    }
    
    //trying to get it to work to detect if someone dabs
    //like one arm going diagonlly up and the other bent across the face
    func handleBodyPose(_ observations: [VNHumanBodyPoseObservation]) {
        guard let overlay = detectionOverlay else { return }
        overlay.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        for observation in observations {
            //get key joints to do the dab
            guard let leftWrist = try? observation.recognizedPoint(.leftWrist),
                  let leftElbow = try? observation.recognizedPoint(.leftElbow),
                  let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
                  let rightWrist = try? observation.recognizedPoint(.rightWrist),
                  let rightElbow = try? observation.recognizedPoint(.rightElbow),
                  let rightShoulder = try? observation.recognizedPoint(.rightShoulder) else {
                continue
            }
            
            //gotta convert the points
            let leftWristPoint = CGPoint(x: leftWrist.location.x * overlay.bounds.width, y: (1 - leftWrist.location.y) * overlay.bounds.height)
            let leftElbowPoint = CGPoint(x: leftElbow.location.x * overlay.bounds.width, y: (1 - leftElbow.location.y) * overlay.bounds.height)
            let leftShoulderPoint = CGPoint(x: leftShoulder.location.x * overlay.bounds.width, y: (1 - leftShoulder.location.y) * overlay.bounds.height)
            let rightWristPoint = CGPoint(x: rightWrist.location.x * overlay.bounds.width, y: (1 -  rightWrist.location.y) * overlay.bounds.height)
            let rightElbowPoint = CGPoint(x: rightElbow.location.x * overlay.bounds.width, y: (1 - rightElbow.location.y) * overlay.bounds.height)
            let rightShoulderPoint = CGPoint(x: rightShoulder.location.x * overlay.bounds.width, y: (1 - rightShoulder.location.y) * overlay.bounds.height)
                    
            
        }
        
    }
}
