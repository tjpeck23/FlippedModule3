//
//  OldViewController.swift
//  VisionFaceTrack
//
//  Created by Travis Peck on 11/3/24.
//  Copyright © 2024 Apple. All rights reserved.
//

import UIKit
import AVKit
import Vision

//automatic fix by Xcode for detecting human body pose
@available(iOS 14.0, *)
class OldViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var previewView: UIView!
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var videoDataOutput: AVCaptureVideoDataOutput?
    var videoDataOutputQueue: DispatchQueue?
    var rootLayer: CALayer?
    var detectionOverlay: CALayer?
    var captureDevice: AVCaptureDevice?
    var captureDeviceResolution: CGSize = CGSize()
    
    // Request for detecting human body pose
    private var bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.session = self.setupAVCaptureSession()
        self.session?.startRunning()
        //self.prepareVisionRequest()
    }
    
    func setupAVCaptureSession() -> AVCaptureSession? {
        let captureSession = AVCaptureSession()
        //guard let session = session else { return nil }
        
        captureSession.sessionPreset = .high
        /*guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return nil }
        guard let input = try? AVCaptureDeviceInput(device: device) else { return nil }
        captureSession.addInput(input)
        
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(videoDataOutput!)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = previewView.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(previewLayer!)
        */
        
        do {
            let inputDevice = try self.configureFrontCamera(for: captureSession)
            self.configureVideoDataOutput(for: inputDevice.device, resolution: inputDevice.resolution, captureSession: captureSession)
            self.designatePreviewLayer(for: captureSession)
            return captureSession
        } catch let executionError as NSError {
            self.presentError(executionError)
        } catch {
            self.presentErrorAlert(message: "An unexpected failure has occured")
        }
        self.teardownAVCapture()
        
        return nil
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
    
    /// - Tag: ConfigureDeviceResolution
    func highestResolution420Format(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        var highestResolutionFormat: AVCaptureDevice.Format? = nil
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)
        
        for format in device.formats {
            let deviceFormat = format as AVCaptureDevice.Format
            
            let deviceFormatDescription = deviceFormat.formatDescription
            if CMFormatDescriptionGetMediaSubType(deviceFormatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
                let candidateDimensions = CMVideoFormatDescriptionGetDimensions(deviceFormatDescription)
                if (highestResolutionFormat == nil) || (candidateDimensions.width > highestResolutionDimensions.width) {
                    highestResolutionFormat = deviceFormat
                    highestResolutionDimensions = candidateDimensions
                }
            }
        }
        
        if highestResolutionFormat != nil {
            let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width), height: CGFloat(highestResolutionDimensions.height))
            return (highestResolutionFormat!, resolution)
        }
        
        return nil
    }
    
    
    func configureFrontCamera(for captureSession: AVCaptureSession) throws -> (device: AVCaptureDevice, resolution: CGSize) {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        
        if let device = deviceDiscoverySession.devices.first {
            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                }
                
                if let highestResolution = self.highestResolution420Format(for: device) {
                    try device.lockForConfiguration()
                    device.activeFormat = highestResolution.format
                    device.unlockForConfiguration()
                    
                    return (device, highestResolution.resolution)
                }
            }
        }
        
        throw NSError(domain: "ViewController", code: 1, userInfo: nil)
    }
    
    func configureVideoDataOutput(for inputDevice: AVCaptureDevice, resolution: CGSize, captureSession: AVCaptureSession) {
                
                let videoDataOutput = AVCaptureVideoDataOutput()
                videoDataOutput.alwaysDiscardsLateVideoFrames = true
                
                // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
                // A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
                let videoDataOutputQueue = DispatchQueue(label: "com.example.apple-samplecode.VisionFaceTrack")
                videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
                
                if captureSession.canAddOutput(videoDataOutput) {
                    captureSession.addOutput(videoDataOutput)
                }
                
                videoDataOutput.connection(with: .video)?.isEnabled = true
                
                if let captureConnection = videoDataOutput.connection(with: AVMediaType.video) {
                    if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                        captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
                    }
                }
                
                self.videoDataOutput = videoDataOutput
                self.videoDataOutputQueue = videoDataOutputQueue
                
                self.captureDevice = inputDevice
                self.captureDeviceResolution = resolution
            }
    /// - Tag: DesignatePreviewLayer
            func designatePreviewLayer(for captureSession: AVCaptureSession) {
                let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                self.previewLayer = videoPreviewLayer
                
                videoPreviewLayer.name = "CameraPreview"
                videoPreviewLayer.backgroundColor = UIColor.black.cgColor
                videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                
                if let previewRootLayer = self.previewView?.layer {
                    self.rootLayer = previewRootLayer
                    
                    previewRootLayer.masksToBounds = true
                    videoPreviewLayer.frame = previewRootLayer.bounds
                    previewRootLayer.addSublayer(videoPreviewLayer)
                }
            }
            
            // Removes infrastructure for AVCapture as part of cleanup.
            func teardownAVCapture() {
                self.videoDataOutput = nil
                self.videoDataOutputQueue = nil
                
                if let previewLayer = self.previewLayer {
                    previewLayer.removeFromSuperlayer()
                    self.previewLayer = nil
                }
            }
    
    
    func presentErrorAlert(withTitle title: String = "Unexpected Failure", message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        self.present(alertController, animated: true)
    }
    
    func presentError(_ error: NSError) {
        self.presentErrorAlert(withTitle: "Failed with error \(error.code)", message: error.localizedDescription)
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
            
            print(rightWristPoint.y)
            
        }
        
    }
}
