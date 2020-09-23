//
//  InterfaceController.swift
//  prc_watch Extension
//
//  Created by Craig Hewlett on 2020-09-22.
//

import WatchKit
import Foundation
import WatchConnectivity


class InterfaceController: WKInterfaceController, WCSessionDelegate {
    
    @IBOutlet weak var volAway_label: WKInterfaceLabel!
    @IBOutlet weak var pumpRate_label: WKInterfaceLabel!
    @IBOutlet weak var coefficient_label: WKInterfaceLabel!
    
    let defaults = UserDefaults.standard
    enum dataKeys : String {case efficiency, coefficient, timesLoaded, startTime, spm}
    
    let shareSession = WCSession.default
    
    var startTime: Date?
    var tapCount = 0
    var spm = 0.0
    var pumpRate = 0.0
    var coefficient = 0.0056
    var efficiency = 1.0

    var timer = Timer()

    override func awake(withContext context: Any?) {
        // Configure interface objects here.
        
        shareSession.delegate = self
        shareSession.activate()
        
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        loadValuesFromDefaults()
        
        requestCoefficient()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    func setDefaultLabelValues(){
        
        volAway_label.setText("---")
        pumpRate_label.setText("---")

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
        
        coefficient_label.setText("Coefficient \(String(format: "%.4f", coefficient))")
        
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
        
        pumpRate_label.setText("\(String(format: "%.3f", pumpRate)) m3/min")
        
    }
    
    //bypass the startTime set in the event that the app is firing up from teminated state and the startDate is already set
    func startTimer(ignore_startTime: Bool){
        
        if !ignore_startTime {
            startTime = Date.init()
            defaults.set(startTime, forKey: dataKeys.startTime.rawValue)
        }

        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(update_volumeAway_timeElapsed), userInfo: nil, repeats: true)
        
    }
    
    @objc func update_volumeAway_timeElapsed(){
        
        if startTime != nil{
        let timeElapsed = Date.init().timeIntervalSince(startTime!)
        let volAway = (timeElapsed / 60) * pumpRate
        
        volAway_label.setText("\(String(format: "%.3f", volAway)) m3 away")
        }
    }

    @IBAction func resetButton_tapped(_ sender: Any) {
        
        timer.invalidate()
        startTime = nil
        setDefaultLabelValues()
        tapCount = 0
        defaults.set(nil, forKey: dataKeys.startTime.rawValue)
        
        WKInterfaceDevice.current().play(.click)

        
    }
    
    @IBAction func mainButton_tapped(_ sender: Any) {
        
        if startTime != nil{
            tapCount += 1
            calculateStrokesPerMinute(ignore_tapCount: false)
        }else{
            startTimer(ignore_startTime: false)
        }
        
        WKInterfaceDevice.current().play(.click)

    }
    
    func requestCoefficient(){
        shareSession.sendMessage(["watch":"coef"], replyHandler: nil, errorHandler: nil)
    }
    

    //WCSessionDelegate methods
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        if activationState == .activated{
            requestCoefficient()
        }
    }
        
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        
        if let coefficient = message["coefficient"] as? Double{
            self.coefficient = coefficient
            defaults.setValue(coefficient, forKey: dataKeys.coefficient.rawValue)

            coefficient_label.setText("Coefficient \(String(format: "%.4f", coefficient))")
        }
    }
}
