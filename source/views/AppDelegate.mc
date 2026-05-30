import Toybox.Lang;
import Toybox.WatchUi;

module BusNearMe {

    class AppDelegate extends WatchUi.BehaviorDelegate {

        function initialize() {
            BehaviorDelegate.initialize();
        }

        function onPreviousPage() as Boolean {
            var ctrl = getApp().controller;
            if (ctrl.scrollIndex > 0) {
                ctrl.scrollIndex--;
                WatchUi.requestUpdate();
            }
            return true;
        }

        function onNextPage() as Boolean {
            var ctrl     = getApp().controller;
            var maxIndex = getMaxScrollIndex(ctrl);
            if (ctrl.scrollIndex < maxIndex) {
                ctrl.scrollIndex++;
                WatchUi.requestUpdate();
            }
            return true;
        }

        function onSelect() as Boolean {
            var ctrl = getApp().controller;

            if (ctrl.state == AppState.STOPS && ctrl.stops != null) {
                var stops = ctrl.stops as Array;
                var index = ctrl.scrollIndex;
                if (index < stops.size()) {
                    ctrl.selectStop(stops[index] as Stop);
                }
            } else if (ctrl.state == AppState.ARRIVALS) {
                ctrl.scrollIndex = 0;
                ctrl.refreshArrivals();
            } else if (ctrl.state == AppState.ERROR) {
                ctrl.retry();
            }

            return true;
        }

        function onBack() as Boolean {
            var ctrl = getApp().controller;

            if (ctrl.state == AppState.ARRIVALS ||
                ctrl.state == AppState.FETCHING_ARRIVALS) {
                ctrl.backToStops();
                return true;
            }

            return false;
        }

        function getMaxScrollIndex(ctrl as AppController) as Number {
            if (ctrl.state == AppState.STOPS && ctrl.stops != null) {
                var size = (ctrl.stops as Array).size();
                return size > 0 ? size - 1 : 0;
            }
            if (ctrl.state == AppState.ARRIVALS && ctrl.arrivals != null) {
                var size = (ctrl.arrivals as Array).size();
                return size > 0 ? size - 1 : 0;
            }
            return 0;
        }

    }

}
