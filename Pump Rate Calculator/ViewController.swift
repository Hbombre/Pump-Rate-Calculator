//
//  ViewController.swift
//  Pump Rate Calculator
//
//  Created by Craig Hewlett on 2020-09-21.
//

import UIKit
import WatchConnectivity

class ViewController: UIViewController, WCSessionDelegate {
    
    @IBOutlet weak var SPM_label: UILabel!
    @IBOutlet weak var startTime_label: UILabel!
    @IBOutlet weak var volumeAway_label: UILabel!
    @IBOutlet weak var timeElapsed_label: UILabel!
    @IBOutlet weak var pumpRate_label: UILabel!
    @IBOutlet weak var coefficient_textfield: UITextField!
    @IBOutlet weak var efficiency_textfield: UITextField!
    
    var startTime: Date?
    var tapCount = 0
    var spm = 0.0
    var pumpRate = 0.0
    var coefficient = 0.0056
    var efficiency = 1.0

    var timer = Timer()
    let defaults = UserDefaults.standard
    
    var watchSession: WCSession?
    
    enum dataKeys : String {
        case efficiency, coefficient, timesLoaded, startTime, spm
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureWatchKitSesstion()
        
        hideKeyboardWhenTappedAround()
        
        //Increment the times the app has been opened. Used for when prompting for user reviews.
        let timesLoaded = defaults.integer(forKey: dataKeys.timesLoaded.rawValue) + 1
        defaults.setValue(timesLoaded, forKey: dataKeys.timesLoaded.rawValue)
        
        setDefaultLabelValues()
        loadValuesFromDefaults()
    }
    
    func setDefaultLabelValues(){
        
        SPM_label.text = "---"
        startTime_label.text = "---"
        volumeAway_label.text = "---"
        timeElapsed_label.text = "---"
        pumpRate_label.text = "---"

    }
    
    //loading values from fully terminated state
    func loadValuesFromDefaults(){
        
        coefficient = defaults.double(forKey: dataKeys.coefficient.rawValue)
        efficiency = defaults.double(forKey: dataKeys.efficiency.rawValue)
        
        //if effeciency is 0 (most likely from inital start up on device) set it to 1
        if efficiency == 0.0{
            efficiency = 1.0
            defaults.setValue(efficiency, forKey: dataKeys.efficiency.rawValue)
        }
        
        //if coeefcient is 0 (most likely from inital start up on device) set it to 0.0056
        if coefficient == 0.0{
            coefficient = 0.0056
            defaults.setValue(coefficient, forKey: dataKeys.coefficient.rawValue)
        }
        
        coefficient_textfield.text = String(format: "%.5f", coefficient)
        efficiency_textfield.text = "\(String(format: "%.0f", efficiency * 100))%"
        
        //resumes pumping calculations as if the app wasn't terminated if there is a valid startTime saved
        if let time = defaults.object(forKey: dataKeys.startTime.rawValue) as? Date {
            startTime = time
            spm = defaults.double(forKey: dataKeys.spm.rawValue)
            calculateStrokesPerMinute(ignore_tapCount: true)
            startTimer(ignore_startTime: true)
        }

    }
    
    //bypass the spm calculation in the event that the app is firing up from teminated state and the tapcount isn't valid
    func calculateStrokesPerMinute(ignore_tapCount: Bool){
        
        guard let start = startTime else {
            print("startTime Not set, calculateStrokesPerMinute should not be called")
            return
        }
        
        let timeElapsed = Date.init().timeIntervalSince(start)
        
        if !ignore_tapCount{
            spm = (60.0 / timeElapsed) * Double(tapCount)
            defaults.set(spm, forKey: dataKeys.spm.rawValue)
        }

        pumpRate = spm * coefficient * efficiency
        
        SPM_label.text = String(format: "%.1f", spm)
        pumpRate_label.text = String(format: "%.3f", pumpRate)
        
    }
    
    //bypass the startTime set in the event that the app is firing up from teminated state and the startDate is already set
    func startTimer(ignore_startTime: Bool){
        
        if !ignore_startTime {
            startTime = Date.init()
            defaults.set(startTime, forKey: dataKeys.startTime.rawValue)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm:ss a"
        startTime_label.text = dateFormatter.string(from: startTime!)
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(update_volumeAway_timeElapsed), userInfo: nil, repeats: true)
        
    }
    
    func configureWatchKitSesstion() {
      
      if WCSession.isSupported() {//4.1
        watchSession = WCSession.default//4.2
        watchSession?.delegate = self//4.3
        watchSession?.activate()//4.4
      }
    }
    
    @objc func update_volumeAway_timeElapsed(){
        let timeElapsed = Date.init().timeIntervalSince(startTime!)
        let volAway = (timeElapsed / 60) * pumpRate
        
        let intSeconds = Int(timeElapsed)
        let hours = intSeconds / 3600
        let minutes = (intSeconds % 3600) / 60
        let seconds = (intSeconds % 3600) % 60
        
        timeElapsed_label.text = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        volumeAway_label.text = String(format: "%.3f", volAway)
    }

    @IBAction func resetButton_tapped(_ sender: Any) {
             
        startTime = nil
        setDefaultLabelValues()
        tapCount = 0
        timer.invalidate()
        defaults.set(nil, forKey: dataKeys.startTime.rawValue)
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
    }
    
    @IBAction func mainButton_tapped(_ sender: Any) {
        
        if startTime != nil{
            tapCount += 1
            calculateStrokesPerMinute(ignore_tapCount: false)
        }else{
            startTimer(ignore_startTime: false)
        }
        
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    @IBAction func promoButton_tapped(_ sender: Any) {
        
        if let url = URL(string: "https://apps.apple.com/app/id1140689878") {
            UIApplication.shared.open(url)
        }
        
    }
    
    @IBAction func coefficient_textField_editingDidEnd(_ sender: Any) {
        
        //ensure value is a valid float
        if Double(coefficient_textfield.text!) == nil{
            showAlert(title: "Invalid Value", message: "Enter a numeric value")
            coefficient_textfield.text = String(defaults.double(forKey: dataKeys.coefficient.rawValue))
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }else{
            coefficient = Double(coefficient_textfield.text!)!
            defaults.setValue(coefficient, forKey: dataKeys.coefficient.rawValue)
            share_coefficient_toWatch()
        }
    }
    
    @IBAction func efficiency_textfield_editingDidEnd(_ sender: Any) {
        
        //ensure value is a valid float
        if let effVal = Double(efficiency_textfield.text!.replacingOccurrences(of: "%", with: "")){
            efficiency = effVal / 100
            defaults.setValue(efficiency, forKey: dataKeys.efficiency.rawValue)
            efficiency_textfield.text = "\(String(format: "%.0f", efficiency * 100))%"
        }else{
            showAlert(title: "Invalid Value", message: "Enter a numeric value")
            efficiency_textfield.text = String(defaults.double(forKey: dataKeys.efficiency.rawValue))
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
    
    func share_coefficient_toWatch(){
        if let validSession = self.watchSession, validSession.isReachable {
          let data: [String: Any] = ["coefficient": coefficient]
            print("Sending data to watch: \(data)")
          validSession.sendMessage(data, replyHandler: nil, errorHandler: nil)
        }else{
            print("No available watch connection")
        }
    }
    
    //WCSessionDelegate methods
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        if activationState == .activated{
            share_coefficient_toWatch()

        }
        
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        
        
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
       print("received message: \(message)")
       DispatchQueue.main.async { //6
        if (message["watch"] as? String) != nil {
            self.share_coefficient_toWatch()
         }
       }
     }
    
}


