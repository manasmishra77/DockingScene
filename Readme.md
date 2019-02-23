About the Docking View:

- It isa view which has two parts: TopView and CentralView.
- When you will dock it in the leftside corner, the Centralview gradually gets hidden and Topview will cover the whole the view
- To dismiss the view user has to right swipe or left swipe on the docking view when it is in docked state

- To disable docking: Make the boolean false: dockingIsAllowed = false

- To use the docking view one has to subclass it, initalize the subclass with superclass's convenience init method and call the instanc's present method
- Sub class can modify the dockingview size, panlength etc. All overridable mehtods are written initial of the DockingView file

- Sub class can get all the calls(Like viewcontroller's)  More detail, go through the DockingView class

/*
Ex: //Please go in the Docking view Class to get whole lot of overridable methods for each instance
override func viewAppeared(fromState: DockingViewState, toState: DockingViewState) {
addViewToTopView()
addViewToCentralView()
}

override func viewGoingToDisAppear(viewState: DockingViewState) {

}

override func viewIsGoingToAppear(fromState: DockingViewState, toState: DockingViewState) {

}
override func viewWillStartTransition(currentState: DockingViewState, toState: DockingViewState) {

}

override func dockingViewRatioChangeInTransition(_ scale: CGFloat) {

}
*/

- To use the topview, developer has to add their view as a subview to the topview, same for centralview also
call the mehods whenever convenint for you
/*
Ex: 
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

*/






Explaing the Demo:

Step-1:  Add the DockingViewClass in the Docking group of the example project(Docking Scene) to your project
Step2: Create a subclass of DockingView Class
/*
For reference- ViewController File of the example project(Docking Scene), Line no: 33

class DockingViewSubClass: DockingView {

}
*/
Step3: Initialize the DockingViewSubClass 
/*

/*
For reference- ViewController File of the example project(Docking Scene), Line no: 26

dockingView = DockingViewSubClass(referenceView: self.view)
*/

Step4: Call the initialized object's present() function

/*
For reference- ViewController File of the example project(Docking Scene), Line no: 27

dockingView?.present()
*/



