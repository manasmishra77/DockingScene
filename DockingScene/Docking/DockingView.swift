//
//  DockingView.swift
//  DrawerVC
//
//  Created by Manas Mishra on 28/11/18.
//  Copyright © 2018 manas. All rights reserved.
//

import UIKit

enum DockingViewState {
    case expanded
    case docked
    case dismissed
    case transitionUpWard
    case transitionDownWard
    case transitionLeftSide
    case transitionRightSide
}

class DockingView: UIView {
    
    private struct DeviceSpecific {
        static private var appDelegate: AppDelegate? {
            return UIApplication.shared.delegate as? AppDelegate
        }
        struct DeviceConstants {
            @available(iOS 11.0, *)
            private static let safeAreaTopPadding: CGFloat = appDelegate?.window?.safeAreaInsets.top ?? 0
            @available(iOS 11.0, *)
            private static let safeAreaBottomPadding: CGFloat = appDelegate?.window?.safeAreaInsets.bottom ?? 0
            
            static var topPadding: CGFloat {
                var safeAreaVal: CGFloat = 0
                if #available(iOS 11.0, *) {
                    safeAreaVal = DeviceConstants.safeAreaTopPadding
                } else {
                    // Fallback on earlier versions
                }
                return safeAreaVal
            }
            static var bottomPadding: CGFloat {
                var safeAreaVal: CGFloat = 0
                if #available(iOS 11.0, *) {
                    safeAreaVal = DeviceConstants.safeAreaBottomPadding
                } else {
                    // Fallback on earlier versions
                }
                return safeAreaVal
            }
            static var hasSafeArea: Bool {
                return topPadding > 0
            }
        }
        static let height = UIScreen.main.bounds.height - DeviceConstants.topPadding
        static let width = UIScreen.main.bounds.width
        static let thresholdSpeed: Double = 150
        static let cornerRadiusForDockedsize: CGFloat = 3
    }
    
    enum AnimationTime: Double {
        case backButtonTapped = 0.3
        case present = 0.4
    }
    private struct PresentingViewAplha {
        static let minimum: CGFloat = 0.3
        static let maximum: CGFloat = 1.0
    }
    
    
    weak var topView: UIView!
    weak var centralView: UIView!
    weak private var containerView: UIView?
    
    //State of the view
    private var dockingViewState: DockingViewState = .dismissed {
        didSet {
            if dockingViewState == .docked {
                tapGesture?.isEnabled = true
                swipeLeftGesture?.isEnabled = true
                swipeRightGesture?.isEnabled = true
            } else {
                tapGesture?.isEnabled = false
                swipeLeftGesture?.isEnabled = true
                swipeRightGesture?.isEnabled = true
            }
        }
    }
    
    //Touch starting point for transition
    private var touchStartingPoint: CGPoint?
    //Touch starting time
    private var touchStartingTime: Date?
    
    //Used when panning starts initially to fire viewWillStartTransition(_:_:)
    private var isTransitionPannigStarted = false
    
    //Used to control the frequency of frame change when touching is going on
    private var shouldConsiderTouchMove = true
    
    private var widthToHeightRatioConstraint: NSLayoutConstraint?
    
    private var tapGesture: UITapGestureRecognizer?
    private var swipeLeftGesture: UISwipeGestureRecognizer?
    private var swipeRightGesture: UISwipeGestureRecognizer?
    
    
    convenience init(referenceView: UIView) {
        let container = UIView()
        container.frame = referenceView.bounds
        referenceView.addSubview(container)
        self.init(frame: container.bounds)
        let newDView = self
        let topView = UIView(frame: newDView.bounds)
        newDView.topView = topView
        newDView.addSubview(topView)
        topView.addThreeConstraints(newDView)
        let centralView = UIView(frame: newDView.bounds)
        newDView.centralView = centralView
        newDView.addSubview(newDView.centralView)
        centralView.addThreeConstraintsWiIgnoringTheTop(newDView)
        centralView.topAnchor.constraint(equalTo: topView.bottomAnchor, constant: 0).isActive = true
        newDView.topViewRatio = 16/9
        newDView.addGestureRecognizer()
        newDView.addSwipeGestureRecognizer()
        newDView.containerView = container
        newDView.referenceView = referenceView
        newDView.addAsSubViewWithConstraints(container)
//        newDView.backgroundColor = .red
//        newDView.centralView.backgroundColor = .green
//        newDView.topView.backgroundColor = .blue
    }
    
    
    deinit {
        print("Docking View deinit")
    }
    
    
    //Overidable methods and variables
    //Used to transition up nd down
    var panLength: CGFloat {
        if (dockingViewState == .expanded || dockingViewState == .transitionDownWard), let initialPoint = touchStartingPoint {
            let newPanLength = dockedStateFrame.origin.y - initialPoint.y
            return newPanLength
        }
        return 350
    }
    
    var minimumPanLengthToStartPanning: CGFloat {
        return 0.1*panLength
    }
    
    //Used as panlength to dismis while swipping left in docked state
    var panLengthForLeftSwipeDismiss: CGFloat {
        if let initialPoint = touchStartingPoint {
            return initialPoint.x
        }
        return DeviceSpecific.width - 100
    }
    
    //Used as panlength to dismis while swipping left in docked state
    var panLengthForRightSwipeDismiss: CGFloat {
        if let initialPoint = touchStartingPoint {
            return DeviceSpecific.width - initialPoint.x
        }
        return DeviceSpecific.width - 100
    }
    
    
    
    var isDockingAllowed: Bool = true
    
    //Refernce view used for touch location of the docking view wrt reference view
    weak var referenceView: UIView?
    
    //dockedStateY = DeviceHeight-Dockedstae height-dockedStateClearanceFromBottm
    var dockedStateClearanceFromBottm: CGFloat {
        return 50
    }
    
    //dockedStateX = DeviceWidth-Dockedstae width-dockedStateClearanceFromTrail
    var dockedStateClearanceFromTrail: CGFloat {
        return 15
    }
    
    //minimumWidth = DeviceWidth/dockedStateWidthWRTDeviceWidth
    var dockedStateWidthWRTDeviceWidth: CGFloat {
        return 2
    }
    
    //topViewHeight = topViewWidth/topViewRatio
    var topViewRatio: CGFloat = 16/9 {
        didSet {
            self.setMultiPlierConstraintsForView(self.topView, multiplier: topViewRatio)
        }
    }
    
    //Actual threSholdHeight = thresholdHeightForTransitionWRTScreenHegiht*DeviceHeight
    var thresholdHeightForTransitionWRTScreenHegiht: CGFloat {
        return 0.5
    }
    
    // Getter function for docking view state
    func getDockingViewState() -> DockingViewState {
        return self.dockingViewState
    }
    
    // Called before view is appeared and subclass may override this method
    func viewIsGoingToAppear(fromState: DockingViewState, toState: DockingViewState) {}
    
    // Called after view is appeared and subclass may override this method
    func viewAppeared(fromState: DockingViewState, toState: DockingViewState) {}
    
    //Called when transition gets started
    func viewWillStartTransition(currentState: DockingViewState, toState: DockingViewState) {}
    
    // Called before view is in the screen, but going to transit and subclass may override this method
    func viewStateWillChangeTo(fromState: DockingViewState, toState: DockingViewState) {}
    
    // Called before view is in the screen, but going to transit and subclass may override this method
    func viewStateChanged(fromState: DockingViewState, toState: DockingViewState) {}
    
    // Called before view is going to disappear and subclass may override this method
    func viewGoingToDisAppear(viewState: DockingViewState) {}
    
    // Called after view is going to disappear and subclass may override this method
    //Do removefromsuperview() here
    func viewDisAppeared(viewState: DockingViewState) {}
    
    // Called when docking view is in transition and scale is minimum(0) at docking state and maximum(1) at expanded state, Varries between 0 to 1
    func dockingViewRatioChangeInTransition(_ scale: CGFloat) {}
    
    // Called when docking view is in transition state from docking to dismiss state only and scale is minimum(0) at dismiss state and maximum(1) at docked state, Varries between 0 to 1
    func dockingViewRatioChangeInTransitionDuringDismiss(_ scale: CGFloat) {}
}

// Methods For only this class and non-overidable by sub classes
extension DockingView {
    private var dockedStatesize: CGSize {
        let width = DeviceSpecific.width/dockedStateWidthWRTDeviceWidth
        let height = width/topViewRatio
        return CGSize(width: width, height: height)
    }
    private var dockedStateOrigin: CGPoint {
        let dockX = DeviceSpecific.width-dockedStatesize.width-dockedStateClearanceFromTrail
        let dockY = DeviceSpecific.height-dockedStatesize.height-dockedStateClearanceFromBottm
        return CGPoint(x: dockX, y: dockY)
    }
    private var dockedStateFrame: CGRect {
        return CGRect(x: dockedStateOrigin.x, y: dockedStateOrigin.y, width: dockedStatesize.width, height: dockedStatesize.height)
    }
    var expandedStateFrame: CGRect {
        return CGRect(x: 0, y: DeviceSpecific.DeviceConstants.topPadding, width: DeviceSpecific.width, height: DeviceSpecific.height)
    }
    
    private var thresholdSize: CGSize {
        return CGSize(width: DeviceSpecific.width*thresholdHeightForTransitionWRTScreenHegiht, height: DeviceSpecific.height*thresholdHeightForTransitionWRTScreenHegiht)
    }
    
    func present(animation: Bool = true) {
        guard let containerView = self.containerView else {return}
        let animationTime = animation ? 0.5 : 0
        let newFrame = expandedStateFrame
        let previousState = self.dockingViewState
        if previousState == .docked {
            self.viewStateWillChangeTo(fromState: previousState, toState: .expanded)
        } else {
            self.viewIsGoingToAppear(fromState: previousState, toState: .expanded)
        }
        containerView.clipsToBounds = true
        UIView.animate(withDuration: animationTime, animations: {
            containerView.frame = newFrame
            containerView.isHidden = false
            containerView.layoutIfNeeded()
        }) { (_) in
            self.dockingViewState = .expanded
            self.dockingViewRatioChangeInTransition(1)
            if previousState == .docked {
                self.viewStateChanged(fromState: previousState, toState: .expanded)
            } else {
                self.viewAppeared(fromState: previousState, toState: .expanded)
            }
        }
    }
    
    // Called when forcefully/programmatically state need to be changed,
    func changeStateTo(toState: DockingViewState, animationTime: AnimationTime, _ completion: ((_ isSuccess: Bool) -> ())?) {
        guard let containerView = self.containerView else {
            completion?(false)
            return
        }
        if toState == .docked, self.dockingViewState == .expanded {
            self.viewStateWillChangeTo(fromState: self.dockingViewState, toState: toState)
            self.viewWillStartTransition(currentState: self.dockingViewState, toState: toState)
            UIView.animate(withDuration: animationTime.rawValue, animations: {
                containerView.frame = self.dockedStateFrame
                containerView.layoutIfNeeded()
            }) { (success) in
                if success {
                    let previousState = self.dockingViewState
                    self.dockingViewState = toState
                    self.dockingViewRatioChangeInTransition(0)
                    self.viewStateChanged(fromState: previousState, toState: toState)
                } else {
                    self.viewStateChanged(fromState: self.dockingViewState, toState: self.dockingViewState)
                }
                completion?(success)
            }
        } else if toState == .expanded, self.dockingViewState == .docked {
            self.viewStateWillChangeTo(fromState: self.dockingViewState, toState: toState)
            self.viewWillStartTransition(currentState: self.dockingViewState, toState: toState)
            UIView.animate(withDuration: animationTime.rawValue, animations: {
                containerView.frame = self.expandedStateFrame
                containerView.layoutIfNeeded()
            }) { (success) in
                if success {
                    let previousState = self.dockingViewState
                    self.dockingViewState = toState
                    self.dockingViewRatioChangeInTransition(1)
                    self.viewStateChanged(fromState: previousState, toState: toState)
                } else {
                    self.viewStateChanged(fromState: self.dockingViewState, toState: self.dockingViewState)
                }
                completion?(success)
            }
        } else {
            completion?(false)
        }
    }
}

// Touch Related methods
extension DockingView {
    enum TouchState {
        case began
        case transition
        case end
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDockingAllowed else {return}
        if let touch = touches.first {
            let currentPoint = touch.location(in: referenceView)
            _ = self.viewIsTouched(touchingPoint: currentPoint, touchState: .began)
            // print("lastPoint=== \(String(describing: lastPoint))")
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDockingAllowed else {return}
        guard let containerView = self.containerView else {return}
        guard let refernceView = self.referenceView else {return}
        if let touch = touches.first {
            let currentPoint = touch.location(in: refernceView)
            //print("lastPoint=== \(String(describing: currentPoint))")
            
            if let newFrame = self.viewIsTouched(touchingPoint: currentPoint, touchState: .transition) {
                //self.frame = newFrame
                containerView.frame = newFrame
                containerView.layoutIfNeeded()
            }
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDockingAllowed else {return}
        guard let containerView = self.containerView else {return}
        //guard let refernceView = self.referenceView else {return}
        if let touch = touches.first {
            let currentPoint = touch.location(in: referenceView)
            let previousState = self.dockingViewState
            if let newFrame = self.viewIsTouched(touchingPoint: currentPoint, touchState: .end) {
                if previousState != self.dockingViewState {
                    self.viewStateWillChangeTo(fromState: previousState, toState: self.dockingViewState)
                }
                if previousState == .transitionLeftSide || previousState == .transitionRightSide {
                    let containerViewAlpha: CGFloat = (self.dockingViewState == .docked) ? 1 : 0
                    if self.dockingViewState == .dismissed {
                        self.viewGoingToDisAppear(viewState: .dismissed)
                    }
                    UIView.animate(withDuration: 0.2, animations: {
                        containerView.alpha = containerViewAlpha
                        containerView.frame = newFrame
                        containerView.layoutIfNeeded()
                    }) { (_) in
                        if previousState != self.dockingViewState {
                            self.viewStateChanged(fromState: previousState, toState: self.dockingViewState)
                        }
                        if self.dockingViewState == .dismissed {
                            self.viewDisAppeared(viewState: .dismissed)
                        }
                    }
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        containerView.frame = newFrame
                        containerView.layoutIfNeeded()
                    }) { (_) in
                        if previousState != self.dockingViewState {
                            self.viewStateChanged(fromState: previousState, toState: self.dockingViewState)
                        }
                    }
                }
            }
        }
    }
}


//Touch Transition related Helper functions
private extension DockingView {
    //Getting MultiplierConstraints
    func setMultiPlierConstraintsForView(_ view: UIView, multiplier: CGFloat) {
        if let existingConstraint = self.widthToHeightRatioConstraint {
            existingConstraint.isActive = false
            view.removeConstraint(existingConstraint)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        let newConstraint = NSLayoutConstraint(item: view, attribute: .width, relatedBy: .equal, toItem: view, attribute: .height, multiplier: multiplier, constant: 0)
        newConstraint.isActive = true
        view.addConstraint(newConstraint)
        widthToHeightRatioConstraint = newConstraint
    }
    
    func viewIsTouched(touchingPoint: CGPoint, touchState: TouchState) -> CGRect? {
        if touchState == .began {
            touchStartingPoint = nil
            touchStartingTime = nil
            if self.dockingViewState == .expanded {
                if touchingPoint.y < (topView.frame.origin.y + topView.frame.height) {
                    touchStartingPoint = touchingPoint
                    touchStartingTime = Date()
                }
            } else if self.dockingViewState == .docked {
                let isValidY: Bool = touchingPoint.y > dockedStateOrigin.y
                let isValidX: Bool = touchingPoint.x > dockedStateOrigin.x
                if isValidX, isValidY {
                    touchStartingPoint = touchingPoint
                    touchStartingTime = Date()
                }
            } else {
                guard let containerView = self.containerView else {return nil}
                let currentFrame = containerView.frame
                if currentFrame.height < thresholdSize.height {
                    containerView.frame = getFrameForState(.docked)
                    containerView.layoutIfNeeded()
                    self.viewStateChanged(fromState: .expanded, toState: .docked)
                } else {
                    containerView.frame = getFrameForState(.expanded)
                    containerView.layoutIfNeeded()
                    self.viewStateChanged(fromState: .docked, toState: .expanded)
                }
            }
        } else if touchState == .transition {
            guard touchStartingPoint != nil else {return nil}
            
            switch dockingViewState {
            case .transitionDownWard, .transitionUpWard:
                if shouldConsiderTouchMove {
                    shouldConsiderTouchMove = false
                    return getFrameOfTheDockingView(touchingPoint: touchingPoint, viewState: dockingViewState)
                } else {
                    shouldConsiderTouchMove = true
                    return nil
                }
                
            case .transitionLeftSide, .transitionRightSide:
                return getFrameOfDockingViewForLeftSwipeDismiss(touchingPoint: touchingPoint, viewState: dockingViewState)
            default:
                if dockingViewState == .docked {
                    //To handle the upward panning case
                    if (touchStartingPoint?.y ?? 0) - touchingPoint.y > minimumPanLengthToStartPanning {
                        if !isTransitionPannigStarted {
                            isTransitionPannigStarted = true
                            let currentState = dockingViewState
                            dockingViewState = .transitionUpWard
                            self.viewWillStartTransition(currentState: currentState, toState: dockingViewState)
                        }
                    } else if let touchStartingPoint = touchStartingPoint, touchingPoint.y > dockedStateOrigin.y {
                        if (touchStartingPoint.x - touchingPoint.x) > 20 {
                            if !isTransitionPannigStarted {
                                isTransitionPannigStarted = true
                                let currentState = dockingViewState
                                dockingViewState = .transitionLeftSide
                                self.viewWillStartTransition(currentState: currentState, toState: dockingViewState)
                            }
                        } else if (touchingPoint.x - touchStartingPoint.x) > 20 {
                            if !isTransitionPannigStarted {
                                isTransitionPannigStarted = true
                                let currentState = dockingViewState
                                dockingViewState = .transitionRightSide
                                self.viewWillStartTransition(currentState: currentState, toState: dockingViewState)
                            }
                        }
                    }

                } else if dockingViewState == .expanded {
                    if touchingPoint.y - (touchStartingPoint?.y ?? 0) > minimumPanLengthToStartPanning {
                        if !isTransitionPannigStarted {
                            isTransitionPannigStarted = true
                            let currentState = dockingViewState
                            dockingViewState = .transitionDownWard
                            self.viewWillStartTransition(currentState: currentState, toState: dockingViewState)
                        }
                    }
                } else {
                    touchStartingPoint = nil
                    touchStartingTime = nil
                }
                
            }
        } else if touchState == .end {
            guard touchStartingPoint != nil else {return nil}
            guard isTransitionPannigStarted else {return nil}
            isTransitionPannigStarted = false
            let endFrame = getFrameOfTheDockingView(touchingPoint: touchingPoint, viewState: self.dockingViewState)
            var newFrame = endFrame
            if dockingViewState == .transitionLeftSide  || dockingViewState == .transitionRightSide {
                newFrame = gettingFinalFrameInTouchEndForLeftSwipeToDismiss(endFrame, viewState: self.dockingViewState, endPoint: touchingPoint)
            } else {
                newFrame =  gettingFinalFrameForTouchEnd(endFrame, viewState: self.dockingViewState, endPoint: touchingPoint)
            }

            touchStartingPoint = nil
            touchStartingTime = nil
            return newFrame
        }
        return nil
    }
    func gettingFinalFrameForTouchEnd(_ endFrame: CGRect, viewState: DockingViewState, endPoint: CGPoint) -> CGRect {
        var newFrame = endFrame
        var dC = endPoint.y - (touchStartingPoint?.y ?? 0)
        dC = (dC<0) ? -dC: dC
        dC = (dC == 0) ? 1: dC
        //Used for getting the frame according to the speed
        if getSpeedOfPanning(distanceCovered: dC) > DeviceSpecific.thresholdSpeed {
            if (viewState == .transitionDownWard) || (viewState == .expanded) {
                newFrame = getFrameForState(.docked)
            } else if viewState == .transitionUpWard || (viewState == .docked) {
                newFrame = getFrameForState(.expanded)
            }
        } else {
            //Used for getting the frame according to the panning length
            if dC < (0.1*panLength) {
                if (viewState == .transitionDownWard) || (viewState == .expanded) {
                    newFrame = getFrameForState(.expanded)
                } else if viewState == .transitionUpWard || (viewState == .docked) {
                    newFrame = getFrameForState(.docked)
                }
            } else {
                if viewState == .transitionDownWard ||  viewState == .transitionUpWard {
                    if endFrame.size.width > thresholdSize.width {
                        newFrame = getFrameForState(.expanded)
                    } else {
                        newFrame = getFrameForState(.docked)
                    }
                }
            }
        }
        return newFrame
    }
    private func getFrameForState(_ state: DockingViewState) -> CGRect {
        let scale: CGFloat = state == .expanded ? 1: 0
        dockingViewRatioChangeInTransition(scale)
        self.dockingViewState = state
        let newFrame = state == .expanded ? expandedStateFrame : dockedStateFrame
        return newFrame
    }
    private func getSpeedOfPanning(distanceCovered: CGFloat) -> Double {
        guard let initialTime = touchStartingTime else {return 0.0}
        let durationOfTouching: Double = -(initialTime.timeIntervalSinceNow)
        let speed = Double(distanceCovered)/durationOfTouching
        //print("Speed \(speed)")
        return speed
    }
    
    func getFrameOfTheDockingView(touchingPoint: CGPoint, viewState: DockingViewState) -> CGRect {
        var dC = touchingPoint.y - (touchStartingPoint?.y ?? 0)
        dC = (dC>(panLength-1)) ? (panLength-1) : dC
        dC = viewState == .transitionUpWard ? panLength+dC:dC
        var scale = (panLength-dC)/panLength
        if scale < 0 {
            scale = 0
        } else if scale > 1 {
            scale = 1
        }
        var currentHeight = (DeviceSpecific.height - dockedStatesize.height)*scale + dockedStatesize.height
        var currentWidth = (DeviceSpecific.width - dockedStatesize.width)*scale + dockedStatesize.width
        dockingViewRatioChangeInTransition(scale)
        var currentY = DockingView.DeviceSpecific.height-currentHeight
        if currentY > dockedStateOrigin.y {
            currentY = dockedStateOrigin.y
        } else if currentY < expandedStateFrame.origin.y {
            currentY = expandedStateFrame.origin.y
        }
        var currentX = DockingView.DeviceSpecific.width-currentWidth
        if currentX > dockedStateOrigin.x {
            currentX = dockedStateOrigin.x
        } else if currentX < expandedStateFrame.origin.x {
            currentX = expandedStateFrame.origin.x
        }
        currentHeight -= changesInSizeForBottomEffect(scale).height
        if currentHeight < dockedStatesize.height {
            currentHeight = dockedStatesize.height
        }
        currentWidth -= changesInSizeForBottomEffect(scale).width
        if currentWidth < dockedStatesize.width {
            currentWidth = dockedStatesize.width
        }
        let newFrame = CGRect(x: currentX, y: currentY, width: currentWidth, height: currentHeight)
        return newFrame
    }
    
    func changesInSizeForBottomEffect(_ scale: CGFloat) -> CGSize {
        let heightForBottomToConsider = (DeviceSpecific.height - dockedStateOrigin.y - dockedStatesize.height)*(1-scale)
        let widthForBottomToConsider = (DeviceSpecific.width - dockedStateOrigin.x - dockedStatesize.width)*(1-scale)
        return CGSize(width: widthForBottomToConsider, height: heightForBottomToConsider)
    }
}

//Tap Gesture related methods
private extension DockingView {
    func addGestureRecognizer() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTapGesture(tapGesture:)))
        self.addGestureRecognizer(tapGesture)
        self.tapGesture = tapGesture
    }
    @objc func handleTapGesture(tapGesture: UITapGestureRecognizer) {
        //HandleTap
        guard (tapGesture.view as? DockingView) != nil else {return}
        if dockingViewState == .docked {
            present()
        }
    }
}

//Swipe Gesture related methods
private extension DockingView {
    func addSwipeGestureRecognizer() {
        let swipeLeftGesture = UISwipeGestureRecognizer(target: self, action: #selector(self.handleSwipeGesture(swipeGesture:)))
        let swipeRightGesture = UISwipeGestureRecognizer(target: self, action: #selector(self.handleSwipeGesture(swipeGesture:)))
        swipeLeftGesture.direction = .left
        swipeRightGesture.direction = .right
        //self.addGestureRecognizer(swipeLeftGesture)
        //self.addGestureRecognizer(swipeRightGesture)
        //self.swipeLeftGesture = swipeLeftGesture
        //self.swipeRightGesture = swipeRightGesture

    }
    @objc func handleSwipeGesture(swipeGesture: UISwipeGestureRecognizer) {
        //HandleTap
        guard (swipeGesture.view as? DockingView) != nil else {return}
        guard let containerView = self.containerView else {return}
        if dockingViewState == .docked, swipeGesture.direction == .left {
            var newFrame = containerView.frame
            newFrame.origin.x = 0
            self.viewGoingToDisAppear(viewState: .dismissed)
            UIView.animate(withDuration: 0.5, animations: {
                containerView.frame = newFrame
                containerView.alpha = 0
                containerView.layoutIfNeeded()
            }) { (_) in
                self.dockingViewState = .dismissed
                containerView.removeFromSuperview()
                self.viewDisAppeared(viewState: .dismissed)
            }
        } else if dockingViewState == .docked, swipeGesture.direction == .right {
            var newFrame = containerView.frame
            newFrame.origin.x = DeviceSpecific.width
            self.viewGoingToDisAppear(viewState: .dismissed)
            UIView.animate(withDuration: 0.5, animations: {
                containerView.frame = newFrame
                containerView.alpha = 0
                containerView.layoutIfNeeded()
            }) { (_) in
                self.dockingViewState = .dismissed
                containerView.removeFromSuperview()
                self.viewDisAppeared(viewState: .dismissed)
            }
        }
    }
}

//Swipe to dismiss related methods
private extension DockingView {
    func getFrameOfDockingViewForLeftSwipeDismiss(touchingPoint: CGPoint, viewState: DockingViewState) -> CGRect {
        if viewState == .transitionLeftSide {
            let dC = (touchStartingPoint?.x ?? 0) - touchingPoint.x
            var scale = dC/panLengthForLeftSwipeDismiss
            if scale < 0 {
                scale = 0
            } else if scale > 1 {
                scale = 1
            }
            let currentX = -dockedStatesize.width + ((1-scale)*dockedStateFrame.maxX)
            var newFrame = dockedStateFrame
            if currentX < newFrame.origin.x {
                newFrame.origin.x = currentX
            }
            self.containerView?.alpha = 1-scale
            self.dockingViewRatioChangeInTransitionDuringDismiss(scale)
            return newFrame
        } else if viewState == .transitionRightSide {
            let dC = touchingPoint.x - (touchStartingPoint?.x ?? 0)
            var scale = dC/panLengthForRightSwipeDismiss
            if scale < 0 {
                scale = 0
            } else if scale > 1 {
                scale = 1
            }
            let currentX = dockedStateOrigin.x + (DeviceSpecific.width - dockedStateOrigin.x)*scale
            var newFrame = dockedStateFrame
            if currentX > newFrame.origin.x {
                newFrame.origin.x = currentX
            }
            self.containerView?.alpha = 1-scale
            self.dockingViewRatioChangeInTransitionDuringDismiss(scale)
            return newFrame
        }
        return CGRect.zero
        
    }
    
    func gettingFinalFrameInTouchEndForLeftSwipeToDismiss(_ endFrame: CGRect, viewState: DockingViewState, endPoint: CGPoint) -> CGRect {
        if viewState == .transitionLeftSide {
            let dC = (touchStartingPoint?.x ?? 0) - endPoint.x
            if getSpeedOfPanning(distanceCovered: dC) > DeviceSpecific.thresholdSpeed {
                self.dockingViewState = .dismissed
                var newFrame = dockedStateFrame
                newFrame.origin.x = -dockedStatesize.width
                self.dockingViewRatioChangeInTransitionDuringDismiss(0)
                return newFrame
            } else {
                if endPoint.x > (panLengthForLeftSwipeDismiss/2) {
                    self.dockingViewState = .docked
                    self.dockingViewRatioChangeInTransitionDuringDismiss(1)
                    return dockedStateFrame
                } else {
                    self.dockingViewState = .dismissed
                    var newFrame = dockedStateFrame
                    newFrame.origin.x = -dockedStatesize.width
                    self.dockingViewRatioChangeInTransitionDuringDismiss(0)
                    return newFrame
                }
            }
        } else if viewState == .transitionRightSide {
            if endPoint.x < (dockedStateOrigin.x + (DeviceSpecific.width - dockedStateOrigin.x)*0.5) {
                self.dockingViewState = .docked
                self.dockingViewRatioChangeInTransitionDuringDismiss(1)
                return dockedStateFrame
            } else {
                self.dockingViewState = .dismissed
                var newFrame = dockedStateFrame
                newFrame.origin.x = DeviceSpecific.width
                self.dockingViewRatioChangeInTransitionDuringDismiss(0)
                return newFrame
            }
        }
        return CGRect.zero
    }

}

extension NSLayoutConstraint {
    func constraintWithMultiplier(_ multiplier: CGFloat) -> NSLayoutConstraint {
        return NSLayoutConstraint(item: self.firstItem as Any, attribute: self.firstAttribute, relatedBy: self.relation, toItem: self.secondItem, attribute: self.secondAttribute, multiplier: multiplier, constant: self.constant)
    }
}

extension UIView {
    func addAsSubViewWithConstraints(_ superview: UIView) {
        self.frame = superview.bounds
        superview.addSubview(self)
        self.addFourConstraints(superview)
    }
    
    func addFourConstraints(_ superview: UIView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.topAnchor.constraint(equalTo: superview.topAnchor).isActive = true
        self.bottomAnchor.constraint(equalTo: superview.bottomAnchor).isActive = true
        self.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: 0).isActive = true
        self.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: 0).isActive = true
    }
    //Ignoring the bottom
    func addThreeConstraints(_ superview: UIView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.topAnchor.constraint(equalTo: superview.topAnchor).isActive = true
        self.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: 0).isActive = true
        self.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: 0).isActive = true
    }
    
    func addThreeConstraintsWiIgnoringTheTop(_ superview: UIView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.bottomAnchor.constraint(equalTo: superview.bottomAnchor).isActive = true
        self.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: 0).isActive = true
        self.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: 0).isActive = true
    }
    
}
