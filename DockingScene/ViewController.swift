//
//  ViewController.swift
//  DockingScene
//
//  Created by Manas Mishra on 23/02/19.
//  Copyright © 2019 manas. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    weak var dockingView: DockingViewSubClass?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let button = UIButton(frame: CGRect(x: 100, y: 100, width: 100, height: 50))
        button.backgroundColor = .red
        button.setTitle("Present", for: .normal)
        button.addTarget(self, action: #selector(clickedOnButton), for: .touchUpInside)
        self.view.addSubview(button)
    }
    
    @objc func clickedOnButton() {
        dockingView = DockingViewSubClass(referenceView: self.view)
        dockingView?.addViewToTopView()
        dockingView?.addViewToCentralView()
        dockingView?.present()
    }
}



class DockingViewSubClass: DockingView {
    
    //Please go in the Docking view Class to get whole lot of overridable methods for each instance
    override func viewAppeared(fromState: DockingViewState, toState: DockingViewState) {
    }
    
    override func viewGoingToDisAppear(viewState: DockingViewState) {
        
    }
    
    override func viewIsGoingToAppear(fromState: DockingViewState, toState: DockingViewState) {
        
    }
    override func viewWillStartTransition(currentState: DockingViewState, toState: DockingViewState) {
        
    }
    override func dockingViewRatioChangeInTransition(_ scale: CGFloat) {
        
    }
    
    func addViewToTopView() {
        let view = UIView(frame: self.topView.bounds)
        view.addAsSubViewWithConstraints(self.topView)
        view.backgroundColor = .gray
    }
    
    func addViewToCentralView() {
        let view = UIView(frame: self.centralView.bounds)
        view.addAsSubViewWithConstraints(self.centralView)
        view.backgroundColor = .orange
    }
}

