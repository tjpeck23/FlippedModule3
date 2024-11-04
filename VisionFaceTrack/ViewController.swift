

// Working View Controller
import UIKit
import AVKit
import Vision

@available(iOS 14.0, *)
class ViewController: UIViewController {
    
    // Main view for showing camera content.
    @IBOutlet weak var previewView: UIView?
    
    // AVCapture variables to hold sequence data
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var videoDataOutput: AVCaptureVideoDataOutput?
    var videoDataOutputQueue: DispatchQueue?
    
    var captureDevice: AVCaptureDevice?
    var captureDeviceResolution: CGSize = CGSize()
    
    // Vision requests
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
    private var bodyPoseRequests: [VNDetectHumanBodyPoseRequest]?
    
    private var didFindPose:Bool = false
    private var didFindInitialFace:Bool = false
    
    private var detectionOverlay: CAShapeLayer?
    
    
    // MARK: UIViewController overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup video for high resolution, drop frames when busy, and front camera
        self.session = self.setupAVCaptureSession()
        
        // setup the vision objects for (1) detection and (2) tracking
        self.prepareVisionRequest2()
        
        // start the capture session and get processing a face!
        self.session?.startRunning()
        
        setupOverlay()
        
        self.didFindPose = false
    }
    
    private func setupOverlay() {
            let overlayLayer = CAShapeLayer()
            overlayLayer.frame = previewView?.bounds ?? .zero
            overlayLayer.strokeColor = UIColor.clear.cgColor
            overlayLayer.lineWidth = 2.0
            overlayLayer.fillColor = UIColor.clear.cgColor
            previewView?.layer.addSublayer(overlayLayer)
            self.detectionOverlay = overlayLayer
        }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // Ensure that the interface stays locked in Portrait.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    // Ensure that the interface stays locked in Portrait.
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    
    
    // MARK: Performing Vision Requests
    
    /// - Tag: WriteCompletionHandler
    fileprivate func prepareVisionRequest() {
    
        
        // create a detection request that processes an image and returns face features
        // completion handler does not run immediately, it is run
        // after a face is detected
        let faceDetectionRequest:VNDetectFaceRectanglesRequest = VNDetectFaceRectanglesRequest(completionHandler: self.faceDetectionCompletionHandler)
        
        // Save this detection request for later processing
        self.detectionRequests = [faceDetectionRequest]
    }
    
    fileprivate func prepareVisionRequest2() {
        // create a detection request that processes an image and returns face features
        // completion handler does not run immediately, it is run
        // after a face is detected
        // let faceDetectionRequest:VNDetectFaceRectanglesRequest = VNDetectFaceRectanglesRequest(completionHandler: self.faceDetectionCompletionHandler)
        
        let bodyDetectionRequest:VNDetectHumanBodyPoseRequest = VNDetectHumanBodyPoseRequest(completionHandler: self.bodyDetectionCompletionHandler)
        self.bodyPoseRequests = [bodyDetectionRequest]
        
        // Save this detection request for later processing
        //self.detectionRequests = [faceDetectionRequest]
        
        
    }
    
    func bodyDetectionCompletionHandler(request: VNRequest, error: Error?) {
        if error != nil {
            print("BodyDetectionRequest failed: \(error!.localizedDescription)")
        }
        
        guard let bodyDetectionRequest = request as? VNDetectHumanBodyPoseRequest,
              let results = bodyDetectionRequest.results as? [VNHumanBodyPoseObservation] else {
            print("BodyDetectionRequest failed to return results")
            return
        }
        
        if results.isEmpty {
            print("BodyDetectionRequest is empty")
            return
        }
        
        DispatchQueue.main.async {
            print("Initial body pose found...")
            
            results.forEach { self.processObservation($0) }
            /*
            for observation in results{
                if self.detectFlexedBicepPose(from: observation) {
                    print("Flexed bicep detected!")
                    self.didFindPose = true
                    
                    
                    DispatchQueue.main.asyncAfter(deadline: .now()+5, execute: {
                        print("Resetting body detection...")
                        self.didFindPose = false
                    })
                }else{
                    print("No flexed bicep detected...")
                }
            }
            */
            
        }
        
        
    }
    
    func detectFlexedBicepPose(from observation: VNHumanBodyPoseObservation) -> Bool {
        // Detect right arm flexed bicep
        guard let rightWrist = try? observation.recognizedPoint(.rightWrist),
              let rightElbow = try? observation.recognizedPoint(.rightElbow),
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder) else {
            print("Required right arm key points not found.")
            return false
        }
        
        // Check confidence for right arm key points
        guard rightWrist.confidence > 0.5, rightElbow.confidence > 0.5, rightShoulder.confidence > 0.5 else {
            return false
        }
        
        let isRightElbowRaised = rightElbow.location.y >= rightShoulder.location.y
        let isRightWristNearShoulder = abs(rightWrist.location.x - rightShoulder.location.x) < 0.1 &&
                                       abs(rightWrist.location.y - rightShoulder.location.y) < 0.1
        
        let isRightBicepFlexed = isRightElbowRaised && isRightWristNearShoulder
        
        // Detect left arm flexed bicep
        guard let leftWrist = try? observation.recognizedPoint(.leftWrist),
              let leftElbow = try? observation.recognizedPoint(.leftElbow),
              let leftShoulder = try? observation.recognizedPoint(.leftShoulder) else {
            print("Required left arm key points not found.")
            return isRightBicepFlexed // Return true if right arm is flexed
        }
        
        // Check confidence for left arm key points
        guard leftWrist.confidence > 0.5, leftElbow.confidence > 0.5, leftShoulder.confidence > 0.5 else {
            return isRightBicepFlexed
        }
        
        let isLeftElbowRaised = leftElbow.location.y >= leftShoulder.location.y
        let isLeftWristNearShoulder = abs(leftWrist.location.x - leftShoulder.location.x) < 0.1 &&
                                      abs(leftWrist.location.y - leftShoulder.location.y) < 0.1
        
        let isLeftBicepFlexed = isLeftElbowRaised && isLeftWristNearShoulder
        
        // Return true if either bicep is flexed
        return isRightBicepFlexed || isLeftBicepFlexed
    }

    
    // define behavior for when we detect a face
    func faceDetectionCompletionHandler(request:VNRequest, error: Error?){
        // any errors? If yes, show and try to keep going
        if error != nil {
            print("FaceDetection error: \(String(describing: error)).")
        }
        
        // see if we can get any face features, this will fail if no faces detected
        // try to save the face observations to a results vector
        guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
            let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                return
        }
        
        if results.isEmpty{
            return
        }
        
        // if we got here, then a face was detected and we have its features saved
        // This initial detection is the most computational part of what we do
        // from here we just need to add tracking
        DispatchQueue.main.async {
            print("Initial Face found...")
            self.didFindInitialFace = true
            
            // set a delayed false here to perform face detection again
            DispatchQueue.main.asyncAfter(deadline: .now()+5, execute: {
                print("Resetting face detection.")
                self.didFindInitialFace = false
            })
            
        }
        
    }
    
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    /// - Tag: PerformRequests
    // Handle delegate method callback on receiving a sample buffer.
    // This is where we get the pixel buffer from the camera and need to
    // generate the vision requests
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        // see if camera has any instrinsic transforms on it
        // if it does, add these to the options for requests
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        // check to see if we can get the pixels for processing, else return
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        
        // get portrait orientation for UI
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()
        
  
        
        
        
        // check to see if the tracking request is empty (no face currently detected)
        // if it is empty,
        
        
        if !self.didFindPose{
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: exifOrientation,
                                                            options: requestHandlerOptions)
            
            do {
                if let poseRequests = self.bodyPoseRequests{
                    try imageRequestHandler.perform(poseRequests)
                }
            } catch let error as NSError {
                NSLog("Failed to perform PoseRequest: %@", error)
            }
        }
        
    }
    
    
}


// MARK: Helper Methods
extension UIViewController{
    
    // Helper Methods for Error Presentation
    
    fileprivate func presentErrorAlert(withTitle title: String = "Unexpected Failure", message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        self.present(alertController, animated: true)
    }
    
    fileprivate func presentError(_ error: NSError) {
        self.presentErrorAlert(withTitle: "Failed with error \(error.code)", message: error.localizedDescription)
    }
    
    // Helper Methods for Handling Device Orientation & EXIF
    
    fileprivate func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
        return CGFloat(Double(degrees) * Double.pi / 180.0)
    }
    
    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
            
        case .landscapeLeft:
            return .downMirrored
            
        case .landscapeRight:
            return .upMirrored
            
        default:
            return .leftMirrored
        }
    }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
}


// MARK: Extension for AVCapture Setup
@available(iOS 14.0, *)
extension ViewController:AVCaptureVideoDataOutputSampleBufferDelegate{
    
    
    /// - Tag: CreateCaptureSession
    fileprivate func setupAVCaptureSession() -> AVCaptureSession? {
        let captureSession = AVCaptureSession()
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
    
    /// - Tag: ConfigureDeviceResolution
    fileprivate func highestResolution420Format(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
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
    
    fileprivate func configureFrontCamera(for captureSession: AVCaptureSession) throws -> (device: AVCaptureDevice, resolution: CGSize) {
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
    
    /// - Tag: CreateSerialDispatchQueue
    fileprivate func configureVideoDataOutput(for inputDevice: AVCaptureDevice, resolution: CGSize, captureSession: AVCaptureSession) {
        
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
    fileprivate func designatePreviewLayer(for captureSession: AVCaptureSession) {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer = videoPreviewLayer
        
        videoPreviewLayer.name = "CameraPreview"
        videoPreviewLayer.backgroundColor = UIColor.black.cgColor
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        if let previewRootLayer = self.previewView?.layer {
            
            previewRootLayer.masksToBounds = true
            videoPreviewLayer.frame = previewRootLayer.bounds
            previewRootLayer.addSublayer(videoPreviewLayer)
        }
    }
    
    // Removes infrastructure for AVCapture as part of cleanup.
    fileprivate func teardownAVCapture() {
        self.videoDataOutput = nil
        self.videoDataOutputQueue = nil
        
        if let previewLayer = self.previewLayer {
            previewLayer.removeFromSuperlayer()
            self.previewLayer = nil
        }
    }
    
    func processObservation(_ observation: VNHumanBodyPoseObservation) {
        
        // Retrieve all torso points.
        guard let armPoints = try? observation.recognizedPoints(.leftArm) else { return }
        guard let torsoPoints =
                try? observation.recognizedPoints(.torso) else { return }
        //Commenting out because they make a lot of noise but feel free to uncomment them out to see what their results are if you need them
        //print(armPoints)
        //print(torsoPoints)
        
        if self.detectFlexedBicepPose(from: observation) {
            print("Flexed bicep detected!")
            self.didFindPose = true
        
            DispatchQueue.main.asyncAfter(deadline: .now()+5, execute: {
            print("Resetting body detection...")
            self.didFindPose = false
        })
        }else{
        print("No flexed bicep detected...")
        }
        /*
                                            // Torso joint names in a clockwise ordering.
                                            let torsoJointNames: [VNHumanBodyPoseObservation.JointName] = [
                                            .neck,
                                            .rightShoulder,
                                            .rightHip,
                                            .root,
                                            .leftHip,
                                            .leftShoulder
                                            ]
                                            */
            

    }
    
}


