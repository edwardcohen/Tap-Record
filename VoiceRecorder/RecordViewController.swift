//
//  RecordViewController.swift
//  VoiceRecorder
//
//  Created by Eddie Cohen & Jason Toff on 8/2/16.
//  Copyright © 2016 zelig. All rights reserved.
//

import UIKit
import AVFoundation
import CloudKit
import CoreLocation
import CoreData
import Speech
import KDCircularProgress
//import SwiftSiriWaveformView

class RecordViewController: UIViewController, SFSpeechRecognizerDelegate,NSFetchedResultsControllerDelegate,UIViewControllerTransitioningDelegate, AVAudioRecorderDelegate, CLLocationManagerDelegate, UITextFieldDelegate, PulleyPrimaryContentControllerDelegate {
    @IBOutlet var recordButton: UIButton!
//    @IBOutlet var chevronButton: UIButton!
    @IBOutlet var transTextView: UITextView!
    @IBOutlet var backgroundImage: UIImageView!
    @IBOutlet var viewCenterRecord: UIView!
//    @IBOutlet var timerLabel: UILabel!
    @IBOutlet var doneButton: UIButton!
    @IBOutlet var titleText: UITextField!
    @IBOutlet var transText: UITextField!
    @IBOutlet var deleteButton: UIButton!
//    @IBOutlet var recordProgress: UIProgressView!
    @IBOutlet var spinner: UIActivityIndicatorView!
//    @IBOutlet var tagView: UICollectionView!
//    @IBOutlet var audioWaveformView: SwiftSiriWaveformView!
    
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var locationManager: CLLocationManager!
    

//    var usersaved : Bool = false
//    var maxTimereached : Bool = false

   
    
    @IBOutlet var vCircularProgress: KDCircularProgress!
    
    
    var currentLocation: CLLocation?
    var audioFileURL: NSURL?
    var fetchResultController:NSFetchedResultsController!
    var voiceRecords:[Voice] = []
    var isSpeechEnabled = false
    var isconverstionActive = false

    var tags = ["+"]
    var marks = [Double]()
    ///// Speech Recognizor
    private let speechRecognizer = SFSpeechRecognizer(locale: NSLocale.init(localeIdentifier: "en-US"))  //1
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    var sizingCell: TagCellView?
    

    enum RecordState: Int {
        case None
        case OneTime
        case Continuous
        case Pause
        case Done
    }
    
    var recordState: RecordState = RecordState.None
    var recordingTimer: NSTimer!
    var timerCount: Double!
    
    var displayLink:CADisplayLink!
    
    let customPresentAnimationController = CustomPresentAnimationController()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewCenterRecord.layer.cornerRadius = 27.5
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        let now = dateFormatter.stringFromDate(NSDate())
        titleText.text = now
        titleText.delegate = self
        transText.delegate = self
        transText.userInteractionEnabled = false

        speechRecognizer!.delegate = self  //3
        SFSpeechRecognizer.requestAuthorization { (authStatus) in

            switch authStatus {
                
            case .Authorized:
                self.isSpeechEnabled = true
                
            case .Denied:
                self.isSpeechEnabled = false
                
            case .Restricted:
                self.isSpeechEnabled = false
                
            case .NotDetermined:
                self.isSpeechEnabled = false
                
            }
            
            self.isconverstionActive = self.isSpeechEnabled
        }

        displayLink = CADisplayLink(target: self, selector: #selector(updateMeters))
        displayLink.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        
        spinner.hidesWhenStopped = true
        spinner.center = view.center
        view.addSubview(spinner)

        backgroundImage.userInteractionEnabled = true

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
        longPress.minimumPressDuration = 0.2
        recordButton.addGestureRecognizer(longPress)
        let swipeLeft  = UISwipeGestureRecognizer(target:self ,action: #selector (showCalender) )
        swipeLeft.direction = UISwipeGestureRecognizerDirection.Left
        self.view.addGestureRecognizer(swipeLeft)
//        let swipeRight  = UISwipeGestureRecognizer(target:self ,action: #selector (fetchAllRecords) )
//        swipeRight.direction = UISwipeGestureRecognizerDirection.Right
//        
//        self.view.addGestureRecognizer(swipeRight)
        
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        
        getQuickLocationUpdate()
        
        updateUI()
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(AVAudioSessionCategoryRecord)
//            try recordingSession.setActive(true)
//           try recordingSession.setActive(true, withOptions:AVAudioSessionSetActiveOptions.NotifyOthersOnDeactivation)
            try recordingSession.setMode(AVAudioSessionModeMeasurement)
            try recordingSession.setActive(true, withOptions:AVAudioSessionSetActiveOptions.NotifyOthersOnDeactivation)
            recordingSession.requestRecordPermission() { [unowned self] (allowed: Bool) -> Void in
                dispatch_async(dispatch_get_main_queue()) {
                    if !allowed {
                        self.showErrorMessage("You need to configure Microphone permission")
                    }
                }
            }
        } catch {
            showErrorMessage("Failed to configure AVAudioSession!")
        }
//        tagView.dataSource = self
//        tagView.delegate = self
        
        let cellNib = UINib(nibName: "TagCellView", bundle: nil)
//        self.tagView.registerNib(cellNib, forCellWithReuseIdentifier: "TagCell")
//        self.tagView.backgroundColor = UIColor.clearColor()
        self.sizingCell = (cellNib.instantiateWithOwner(nil, options: nil) as NSArray).firstObject as! TagCellView?
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showLastRecord" {
            let destinationController = segue.destinationViewController as! VoiceDetailViewController
            let voiceRecord = voiceRecords[0]
            destinationController.voice = voiceRecord
        }
    }
    
    func showCalender() {
        self.performSegueWithIdentifier("SwipeToCalender", sender: nil)
    }
    
    // MARK : UITextFieldDelegate
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        titleText.resignFirstResponder()
        transText.resignFirstResponder()
        return true
    }
    
    func textFieldDidBeginEditing(textField: UITextField) {
        if textField.text == titleText {
        }
    }
    
    func updateMeters() {
        
//        if audioRecorder != nil {
//            audioRecorder.updateMeters()
//            let normalizedValue:CGFloat = 1.0 - pow(10, CGFloat(audioRecorder.averagePowerForChannel(0))/20)
////            audioWaveformView.amplitude = normalizedValue
//        }
    }
    
    @IBAction func handleDelete() {
        self.view.endEditing(true)
        let deleteAlert = UIAlertController(title: "Delete Record", message: "Are you sure you want to delete this record?", preferredStyle: .Alert)
        deleteAlert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        deleteAlert.addAction(UIAlertAction(title: "Yes", style: .Default, handler: { action in
            if self.recordState == RecordState.Pause {
                self.tags.removeAll()
                self.tags.append("+")
//                self.tagView.reloadData()
                self.marks.removeAll()
                self.recordState = RecordState.None
                let dateFormatter = NSDateFormatter()
                dateFormatter.dateFormat = "MMM dd, yyyy"
                let now = dateFormatter.stringFromDate(NSDate())
                self.transTextView.text = "Transcript goes here..."
                self.titleText.text = now
                self.updateUI()
            }
        }))
        presentViewController(deleteAlert, animated: true, completion: nil)
    }
    
    func showErrorMessage(message: String) {
        let alertController = UIAlertController(title: "Error",
                                                message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alertController.addAction(UIAlertAction(title: "OK", style:
            UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alertController, animated: true, completion:
            nil)
    }
    
//else {
//    startRecording()
//    }
    
    func longPressed(gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case UIGestureRecognizerState.Began:
            print("begin long press")

            if recordState == RecordState.None {
                startRecording()
                SpeechTotextConversion()
              if self.displayLink.paused == true {
                    self.displayLink.paused = false
                }
                recordState = RecordState.Continuous
                updateUI()
            }
            else if recordState == RecordState.Pause {
                self.displayLink.paused = false
                marks.append(timerCount)
                audioRecorder.record()
                SpeechTotextConversion()
                recordingTimer = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
                timerUpdate()
                recordState = RecordState.Continuous
                updateUI()
            }
        case .Ended, .Cancelled:
            print("end long press")
            
            if recordState == RecordState.Continuous {
                if audioEngine.running {
                    audioEngine.stop()
                    recognitionRequest?.endAudio()
                    isconverstionActive = false
                }
                self.displayLink.paused = true
                audioRecorder.pause()
                recordingTimer.invalidate()
                recordState = RecordState.Pause
                updateUI()
            }
        default:
            print("other event at long press")
        }
    }
    
    func doubleTapped() {
        print("double tapped")
        
        if recordState == RecordState.None {
            startRecording()
            recordState = RecordState.Continuous
            updateUI()
        }
    }
    
    func singleTapped() {
        print("single tapped")
        
        var newState: RecordState = recordState
        
        switch recordState {
        case RecordState.Continuous:
            audioRecorder.pause()
            recordingTimer.invalidate()
            newState = RecordState.Pause
        case RecordState.Pause:
            marks.append(timerCount)
            audioRecorder.record()
            recordingTimer = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
            timerUpdate()
            newState = RecordState.Continuous
        default: break
        }

        print("old state=\(recordState), new state=\(newState)")
        recordState = newState
        updateUI()
    }
    
    func updateUI() {
        switch recordState {
        case RecordState.None:

                viewCenterRecord.backgroundColor = UIColor.whiteColor()
                vCircularProgress.angle = 0
                doneButton.alpha = 0.0
                deleteButton.alpha = 0.0
                backgroundImage.image = UIImage(named:"bg")


        case RecordState.OneTime, RecordState.Continuous:
            viewCenterRecord.backgroundColor = UIColor(red: 0xFE/255, green: 0x00/255, blue: 0x00/255, alpha: 1.0)
            backgroundImage.image = UIImage(named:"bgrecord")
            doneButton.alpha = 0.0
            deleteButton.alpha = 0.0

        case RecordState.Done:
            viewCenterRecord.backgroundColor = UIColor.whiteColor()
            backgroundImage.image = UIImage(named:"bg")

//            recordButton.setBackgroundImage(UIImage(named:"progress0"), forState:  UIControlState.Normal)
            vCircularProgress.angle = 0

            doneButton.alpha = 0.0
            deleteButton.alpha = 0.0

        case RecordState.Pause:
            viewCenterRecord.backgroundColor = UIColor.whiteColor()
            backgroundImage.image = UIImage(named:"bg")
            doneButton.alpha = 1.0
            deleteButton.alpha = 1.0


        }
    }
    
    func getDocumentsDirectoryURL() -> NSURL {
        let manager = NSFileManager.defaultManager()
        let URLs = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return URLs[0]
    }
    
    func startRecording() {
        let filename = NSUUID().UUIDString + ".m4a"
        audioFileURL = getDocumentsDirectoryURL().URLByAppendingPathComponent(filename)
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000.0,
            AVNumberOfChannelsKey: 1 as NSNumber,
            AVEncoderAudioQualityKey: AVAudioQuality.High.rawValue
        ]
        
        do {
            try recordingSession.setCategory(AVAudioSessionCategoryRecord)
//            try recordingSession.setActive(true)
            try recordingSession.setMode(AVAudioSessionModeMeasurement)
            try recordingSession.setActive(true, withOptions:AVAudioSessionSetActiveOptions.NotifyOthersOnDeactivation)
            audioRecorder = try AVAudioRecorder(URL: audioFileURL!, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.recordForDuration(60.0)
            audioRecorder.prepareToRecord()
            audioRecorder.record()
            timerCount = 0
            recordingTimer = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
            timerUpdate()
        } catch {
            abortRecording()
        }
    }
    func SpeechTotextConversion()
    {
        if audioEngine.running == true
        {
            return
        }
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
//        let audioSession = AVAudioSession.sharedInstance()
//        do {
//            try audioSession.setCategory(AVAudioSessionCategoryRecord)
//            try audioSession.setMode(AVAudioSessionModeMeasurement)
//            try audioSession.setActive(true, withOptions:AVAudioSessionSetActiveOptions.NotifyOthersOnDeactivation)
//            
//        } catch {
//            print("audioSession properties weren't set because of an error.")
//        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        if self.transTextView.text == "Transcript goes here..." {
            self.transTextView.text = ""
        }
        let beforeString = self.transTextView.text
        
        recognitionTask = speechRecognizer?.recognitionTaskWithRequest(recognitionRequest, resultHandler: { (result  , error) in

            
            var isFinal = false
            if result != nil {
                self.transTextView.text = NSString(format: "%@ %@",beforeString!,(result?.bestTranscription.formattedString)!) as String
                
                let rangeBotm = NSMakeRange(self.transTextView.text.characters.count-1, 1)
            
                self.transTextView.scrollRangeToVisible(rangeBotm)

                isFinal = (result?.final)!
            }
            if error != nil || isFinal {
//                NSRange bottom = NSMakeRange(textView.text.length -1, 1);
//                [textView scrollRangeToVisible:bottom];
//                let rangeBotm = NSMakeRange(self.transTextView.text.characters.count-1, 1)
//                self.transTextView.scrollRangeToVisible(rangeBotm)
                
                self.audioEngine.stop()
                inputNode.removeTapOnBus(0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isconverstionActive = true
                
            }
        })

        
        let recordingFormat = inputNode.outputFormatForBus(0)
        inputNode.removeTapOnBus(0)
        inputNode.installTapOnBus(0, bufferSize: 1024, format: recordingFormat, block: { (buffer, when) in
            self.recognitionRequest?.appendAudioPCMBuffer(buffer)
        })
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }

    }
    
    func speechRecognizer(speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            self.isconverstionActive = true
        } else {
            self.isconverstionActive = false
        }
    }
    func stopRecording() {
        audioRecorder.stop()
        recordingTimer.invalidate()
        audioRecorder = nil
    }
    
    func abortRecording() {
        audioRecorder.stop()
        recordingTimer.invalidate()
        showErrorMessage("Recorder did finish recording unsuccessfully")
        audioRecorder = nil
        timerCount = 0
    }
    
    func audioRecorderDidFinishRecording(recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            abortRecording()
            recordState = RecordState.None
            updateUI()
        }
    }
    
    func timerUpdate() {
//        timerLabel.text = String(timerCount)
//        recordProgress.setProgress(Float(timerCount)/60, animated: false)
//        
//        let milliseconds = timerCount * 100;
//        let remaingMilliseconds = Int((milliseconds % 1000) / 10);
//        let seconds = Int((milliseconds / 1000) % 60)
        let progress = 360/60 * Double(timerCount)
        
        
//        let angle = 360/60000 * Double(timerCount)
        let angle = progress

        
        print(timerCount)
        print(angle)

        vCircularProgress.angle = angle
//        let imageName = String(format: "progress%f",Float(timerCount))
        
        
//        recordButton.setBackgroundImage(UIImage(named:imageName), forState:  UIControlState.Normal)
        if (timerCount >= 60) {
            audioRecorder.stop()
//            audioRecorder = nil
            vCircularProgress.angle = 360
            recordingTimer.invalidate()
//            recordState = RecordState.Done
//            updateUI()
        }
        timerCount = timerCount + 0.01
    }
    
    func getQuickLocationUpdate() {
        // Request location authorization
        if CLLocationManager.locationServicesEnabled() {
            if self.locationManager.respondsToSelector(#selector(CLLocationManager.requestWhenInUseAuthorization)) {
                self.locationManager.requestWhenInUseAuthorization()
            } else {
                self.locationManager.startUpdatingLocation()
            }
        }
//        self.locationManager.requestWhenInUseAuthorization()
        
        // Request a location update
        self.locationManager.requestLocation()
        // Note: requestLocation may timeout and produce an error if authorization has not yet been granted by the user
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("Got current location.")
        currentLocation = locations.last
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print("Error while updating location " + error.localizedDescription)
    }
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch status {
        case .NotDetermined:
            locationManager.requestAlwaysAuthorization()
            break
        case .AuthorizedWhenInUse:
            locationManager.startUpdatingLocation()
            break
        case .AuthorizedAlways:
            locationManager.startUpdatingLocation()
            break
        default:
            break
        }
    }
//    @IBAction func recordTouchDown() {
//
//        
////        if recordState == RecordState.Continuous {
////            self.displayLink.paused = true
////            audioRecorder.pause()
////            recordingTimer.invalidate()
////            recordState = RecordState.Pause
////            updateUI()
////        }
//
//
//    }
//    @IBAction func recordTouchUp() {
//        
////        if recordState == RecordState.None {
////            startRecording()
////            if self.displayLink.paused == true {
////                self.displayLink.paused = false
////            }
////            //                recordState = RecordState.OneTime
////            recordState = RecordState.Continuous
////            updateUI()
////        } else if recordState == RecordState.Pause {
////            self.displayLink.paused = false
////            marks.append(timerCount)
////            audioRecorder.record()
////            recordingTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
////            timerUpdate()
////            recordState = RecordState.Continuous
////            updateUI()
////        }
//        
//        
//    }
    @IBAction func doneTapped() {
        self.view.endEditing(true)
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        let now = dateFormatter.stringFromDate(NSDate())
        if transTextView.text == "Transcript goes here..." {
            transTextView.text = ""
        }
        let title = !((titleText.text?.isEmpty)!) ? titleText.text : now
        let trans = !((transTextView.text?.isEmpty)!) ? transTextView.text : ""

        let length = timerCount - 1 < 0 ? 0 : timerCount - 1
        let tags = self.tags.filter() { $0 != "+" }
        let location = currentLocation != nil ? currentLocation! : CLLocation()
        let date = NSDate()
        let marks = self.marks
        let audio = audioFileURL!
        
//        let voice = Voice(title: title,transcript :trans ,length: length, date: date, tags: tags, location: location, marks: marks, audio: audio)
        
//        saveRecordToCloud(voice)
        if recordState == RecordState.Pause {
//            self.displayLink.invalidate()
            stopRecording()
            recordState = RecordState.Done
            updateUI()
        }

        spinner.startAnimating()
        
        var voice:Voice!
        
        if let managedObjectContext = (UIApplication.sharedApplication().delegate as? AppDelegate)?.managedObjectContext {
            voice = NSEntityDescription.insertNewObjectForEntityForName("Voice", inManagedObjectContext: managedObjectContext) as! Voice
            voice.title = title
            voice.tags = tags
            voice.marks = marks
            voice.length = length
            voice.location = location
            voice.date = date
            voice.audio = audio
            voice.transcript = trans
//            saveRecordToCloud(voice)

            do {
                try managedObjectContext.save()
                self.spinner.stopAnimating()
                print("Successed in saving records to the core data")
            } catch {
                print("Failed to save record to the core data: \(error)")
                return
            }
        }
        
        if recordState == RecordState.Done {
            self.tags.removeAll()
            self.tags.append("+")
//            tagView.reloadData()
            self.marks.removeAll()
            recordState = RecordState.None
            updateUI()
            titleText.text = now
            transTextView.text = "Transcript goes here..."
            self.displayLink.paused = false
        }
    }
    
    // MARK: - CloudKit Methods
    
    func fetchAllRecords()
    {
        let fetchRequest = NSFetchRequest(entityName:"Voice")
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        if let managedObjectContext = (UIApplication.sharedApplication().delegate as? AppDelegate)?.managedObjectContext {
            fetchResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
            fetchResultController.delegate = self
            
            do {
                try fetchResultController.performFetch()
                voiceRecords = fetchResultController.fetchedObjects as! [Voice]
                self.performSegueWithIdentifier("showLastRecord", sender: nil)
                
                print("Retrived data from core data")
//                completionHandler(true)
            } catch {
                print("Failed to get data from core data - \(error)")
//                completionHandler(false)
            }
        }
    }
    
    func saveRecordToCloud(voice: Voice) -> Void {
        spinner.startAnimating()
        
        // Prepare the record to save
        let record = CKRecord(recordType: "Voice")
        record.setValue(voice.title, forKey: "title")
        record.setValue(voice.length, forKey: "length")
        record.setValue(voice.tags, forKey: "tags")
        record.setValue(voice.location, forKey: "location")
        record.setValue(voice.marks, forKey: "marks")
        record.setValue(voice.date, forKey: "date")
        record.setValue(voice.transcript, forKey: "transcript")
        // Create audio asset for upload
        let audioAsset = CKAsset(fileURL: voice.audio)
        record.setValue(audioAsset, forKey: "audio")
        
        // Get the Public iCloud Database
        let publicDatabase = CKContainer.defaultContainer().publicCloudDatabase
        
        let saveRecordsOperation = CKModifyRecordsOperation()
        saveRecordsOperation.recordsToSave = [record]
        saveRecordsOperation.savePolicy = .AllKeys
        saveRecordsOperation.queuePriority = .VeryHigh

        saveRecordsOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            if (error == nil) {
                // Remove temp file
                do {
                    try NSFileManager.defaultManager().removeItemAtPath(voice.audio.path!)
                    print("Saved record to the cloud.")
                    
                    NSOperationQueue.mainQueue().addOperationWithBlock() {
                        self.spinner.stopAnimating()
                        self.performSegueWithIdentifier("doneRecording", sender: self)
                    }
                } catch {
                    print("Failed to delete temparary file.")
                }
            } else {
                print("Failed to save record to the cloud: \(error)")
            }
        }

        publicDatabase.addOperation(saveRecordsOperation)
    }
}

extension RecordViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tags.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let tagCell = collectionView.dequeueReusableCellWithReuseIdentifier("TagCell", forIndexPath: indexPath) as! TagCellView
        self.configureCell(tagCell, forIndexPath: indexPath)
        return tagCell
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        self.configureCell(self.sizingCell!, forIndexPath: indexPath)
        return self.sizingCell!.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
    }
    
    func configureCell(cell: TagCellView, forIndexPath indexPath: NSIndexPath) {
        cell.tagLabel.text = tags[indexPath.item]
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        if tags[indexPath.item] == "+" {
            var tagTextField: UITextField?
            
            let alertController = UIAlertController(title: "Add Tag", message: nil, preferredStyle: .Alert)
            let ok = UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
                if let tagText = tagTextField!.text {
                    self.tags.insert(tagText, atIndex: self.tags.count-1)
//                    self.tagView.reloadData()
                }
            })
            let cancel = UIAlertAction(title: "Cancel", style: .Default, handler: nil)
            alertController.addAction(cancel)
            alertController.addAction(ok)
            alertController.addTextFieldWithConfigurationHandler { (textField) -> Void in
                tagTextField = textField
                tagTextField!.placeholder = "Tag"
                tagTextField?.autocapitalizationType = UITextAutocapitalizationType.Sentences
            }
            presentViewController(alertController, animated: true, completion: nil)
        }
    }
}

//extension UIViewController {
//    func hideKeyboardWhenTappedAround() {
//        let tap:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
//        view.addGestureRecognizer(tap)
//    }
//    
//    func dismissKeyboard() {
//        view.endEditing(true)
//    }
//}
