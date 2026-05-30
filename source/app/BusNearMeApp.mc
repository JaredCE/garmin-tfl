import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

module BusNearMe {

    // Single global controller instance — accessed by views via App.getApp().controller
    class BusNearMeApp extends Application.AppBase {

        var controller as AppController;

        function initialize() {
            AppBase.initialize();
            controller = new AppController();
        }

        function onStart(state as Dictionary or Null) as Void {
            controller.startGps();
        }

        function onStop(state as Dictionary or Null) as Void {
            controller.stopGps();
        }

        function getInitialView() {
            return [new AppView(), new AppDelegate()];
        }

    }

    // Entry point function — required by Connect IQ
    function getApp() as BusNearMeApp {
        return Application.getApp() as BusNearMeApp;
    }

}
