//
//  VoiceDetailViewController.swift
//  VoiceRecorder
//
//  Created by developer on 8/5/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer
import MapKit

class VoiceDetailViewController: UIViewController, AVAudioPlayerDelegate {

    var voice: Voice!
    
    var audioPlayer: AVAudioPlayer?
    
    var timer: NSTimer?
    
    var previousView : NSString?
    @IBOutlet var lblHeading: UITextField!
    
    @IBOutlet var lblTranscript: UITextField!
    
    
    @IBOutlet var titleText: UITextField!
    @IBOutlet var lengthLabel: UILabel!
//    @IBOutlet var tagView: UICollectionView!
    
    @IBOutlet var transTextView: UITextView!
    
    
    @IBOutlet var mapView: MKMapView!
    @IBOutlet var playingProgress: UIProgressView!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var deleteButton: UIButton!
    @IBOutlet var favoriteButton: UIButton!
    @IBOutlet var exportButton: UIButton!
    
    var sizingCell: TagCellView?

    override func viewDidLoad() {
        super.viewDidLoad()

        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "MMMM dd, yyyy"
        let dateStr = dateFormatter.stringFromDate(voice.date)
        titleText.text = dateStr
        lblHeading.text = voice.title
        transTextView.text = voice.transcript
        let  minutes = voice.length.intValue / 60
        let  seconds = voice.length.intValue % 60
        lengthLabel.text = String(format:"%02i:%02i", minutes, seconds)

        
        let annotation = MKPointAnnotation()
        annotation.coordinate = voice.location.coordinate
        mapView.showAnnotations([annotation], animated: true)
        mapView.selectAnnotation(annotation, animated: true)
        mapView.layer.cornerRadius = 10
        
        do {
            try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try! AVAudioSession.sharedInstance().setActive(true)
            let audioFileName = voice.audio.lastPathComponent
            let documentDirectory = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0]
//            print("DocumentDirectory-\(documentDirectory)")
            let soundFileURL = documentDirectory.URLByAppendingPathComponent(audioFileName!)
//            print("SoundFileURL-\(soundFileURL)")
            let fileManager = NSFileManager.defaultManager()
            if fileManager.fileExistsAtPath(soundFileURL!.path!) {
                print("File Avaliable")
                try audioPlayer = AVAudioPlayer(contentsOfURL: soundFileURL!, fileTypeHint: AVFileTypeAppleM4A)
                audioPlayer!.prepareToPlay()
                audioPlayer!.volume = 1.0
            } else {
                print("File Not Avaliable")
            }
        } catch {
            print("error initializing AVAudioPlayer: \(error)")
        }
        
        voice.tags?.append("+")
        
//        tagView.dataSource = self
//        tagView.delegate = self
        
        let cellNib = UINib(nibName: "TagCellView", bundle: nil)
//        self.tagView.registerNib(cellNib, forCellWithReuseIdentifier: "TagCell")
//        self.tagView.backgroundColor = UIColor.clearColor()
        self.sizingCell = (cellNib.instantiateWithOwner(nil, options: nil) as NSArray).firstObject as! TagCellView?
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func playVoice() {
        if let player = audioPlayer {
            player.play()
            startTimer()
            player.delegate = self
        }
    }
    @IBAction func onBtnBack()
    {

        if previousView == "tble" {
            self.dismissViewControllerAnimated(true, completion: { 
                
            })
        }else
        {
        let transition  = CATransition()
        transition.duration = 0.3
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromRight
        self.navigationController?.view.layer.addAnimation(transition, forKey: nil)
        self.navigationController?.popViewControllerAnimated(false)
        }

    }
    @IBAction func onBtnDelete()
    {
        
    }
    @IBAction func onBtnExport()
    {
        
    }
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        audioPlayer!.stop()
        timer?.invalidate()
    }
    
    func startTimer() {
        timer = NSTimer(timeInterval: 0.1, target: self, selector: #selector(VoiceDetailViewController.updateProgress), userInfo: nil, repeats: true)
        NSRunLoop.mainRunLoop().addTimer(timer!, forMode: "NSDefaultRunLoopMode")
    }
    
    func updateProgress() {
        audioPlayer!.updateMeters()
        let progress = Float(audioPlayer!.currentTime/audioPlayer!.duration)
        playingProgress.progress = progress > 0.98 ? 1: progress
//        print(playingProgress.progress)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension VoiceDetailViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return voice.tags!.count
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
        cell.tagLabel.text = voice.tags![indexPath.item]
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        if voice.tags![indexPath.item] == "+" {
            var tagTextField: UITextField?
            
            let alertController = UIAlertController(title: "Add Tag", message: nil, preferredStyle: .Alert)
            let ok = UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
                if let tagText = tagTextField!.text {
                    self.voice.tags!.insert(tagText, atIndex: self.voice.tags!.count-1)
//                    self.tagView.reloadData()
                }
            })
            let cancel = UIAlertAction(title: "Cancel", style: .Default, handler: nil)
            alertController.addAction(ok)
            alertController.addAction(cancel)
            alertController.addTextFieldWithConfigurationHandler { (textField) -> Void in
                tagTextField = textField
                tagTextField!.placeholder = "Tag"
            }
            presentViewController(alertController, animated: true, completion: nil)
        }
    }
}
