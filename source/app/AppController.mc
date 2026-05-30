import Toybox.Lang;
import Toybox.Position;
import Toybox.WatchUi;

module BusNearMe {

    // All possible app states
    module AppState {
        const GPS             = 0;
        const FETCHING_STOPS  = 1;
        const STOPS           = 2;
        const FETCHING_ARRIVALS = 3;
        const ARRIVALS        = 4;
        const ERROR           = 5;
    }

    class AppController {

        // State
        var state       as Number;
        var errorMsg    as String or Null;

        // Data
        var stops       as Array or Null;
        var arrivals    as Array or Null;
        var arrivalsRaw as Array or Null;  // pre-dedup, for ETA label scanning
        var scrollIndex as Number = 0;
        var selectedStop as Stop or Null;

        // Active provider module reference
        // We store as an Object so we can call methods on it generically
        var provider as TransitProviderBase or Null;

        // GPS search radius in metres
        const RADIUS = 100;

        function initialize() {
            state        = AppState.GPS;
            errorMsg     = null;
            stops        = null;
            arrivals     = null;
            selectedStop = null;
            provider     = null;
            scrollIndex  = 0;
            resolveProvider();
        }

        // --- Provider resolution ---

        // Reads the "transitProvider" property and binds the right module.
        // Defaults to TfL if unset or unrecognised.
        function resolveProvider() as Void {
            // var key = TransitProvider.getStringProperty("transitProvider");
            // Currently only TfL — future providers added here
            // e.g. if key.equals("bustimes") { provider = BusTimesProvider; }
            // We use a wrapper object so call sites are identical regardless of provider
            provider = new TfLProviderWrapper();
        }

        // --- GPS ---

        function startGps() as Void {
            state = AppState.GPS;
            Position.enableLocationEvents(
                Position.LOCATION_CONTINUOUS,
                method(:onPosition)
            );
        }

        function stopGps() as Void {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        }

        // Called by Garmin positioning system
        function onPosition(info as Position.Info) as Void {
            // Wait until we have an accurate fix
            if (info.accuracy < Position.QUALITY_USABLE) {
                return;
            }

            stopGps(); // single fix is enough

            var coords = info.position.toDegrees(); // [lat, lon]
            var lat = coords[0].toFloat();
            var lon = coords[1].toFloat();

            fetchStops(lat, lon);
        }

        // --- Stops ---

        function fetchStops(lat as Float, lon as Float) as Void {
            state = AppState.FETCHING_STOPS;
            requestUiUpdate();

            if (provider != null) {
                (provider as TransitProviderBase).fetchNearbyStops(lat, lon, RADIUS, method(:onStopsResult));
            }
        }


        function onStopsResult(resultCode as Number, data as Array or Null) as Void {
            if (resultCode != ProviderResult.SUCCESS || data == null || data.size() == 0) {
                setError(errorMessageForCode(resultCode, data));
                return;
            }

            stops = data;
            state = AppState.STOPS;
            scrollIndex = 0;
            requestUiUpdate();
        }

        // --- Arrivals ---

        function selectStop(stop as Stop) as Void {
            selectedStop = stop;
            scrollIndex = 0;
            fetchArrivals(stop.id);
        }

        function fetchArrivals(stopId as String) as Void {
            state = AppState.FETCHING_ARRIVALS;
            requestUiUpdate();

            if (provider != null) {
                (provider as TransitProviderBase).fetchArrivals(stopId, method(:onArrivalsResult));
            }
        }

        function onArrivalsResult(resultCode as Number, data as Array or Null) as Void {
            if (resultCode != ProviderResult.SUCCESS || data == null) {
                setError(errorMessageForCode(resultCode, data));
                return;
            }

            arrivalsRaw = data;
            arrivals    = TfLProvider.deduplicateArrivals(data);
            state       = AppState.ARRIVALS;
            requestUiUpdate();
        }

        // Refresh arrivals for the currently selected stop
        function refreshArrivals() as Void {
            if (selectedStop == null) {
                return;
            }
            fetchArrivals(selectedStop.id);
        }

        // Go back from arrivals to stop list
        function backToStops() as Void {
            arrivals = null;
            arrivalsRaw = null;
            scrollIndex = 0;
            state = AppState.STOPS;
            requestUiUpdate();
        }

        // --- Error handling ---

        function setError(msg as String) as Void {
            state    = AppState.ERROR;
            errorMsg = msg;
            requestUiUpdate();
        }

        // Retry from error — restart from GPS
        function retry() as Void {
            stops        = null;
            arrivals     = null;
            arrivalsRaw  = null;
            selectedStop = null;
            errorMsg     = null;
            scrollIndex  = 0;
            startGps();
            requestUiUpdate();
        }

        // Map result codes to user-facing strings
        function errorMessageForCode(code as Number, data as Array or Null) as String {
            if (data != null && data.size() == 0) {
                return WatchUi.loadResource(Rez.Strings.NoStops) as String;
            }
            switch (code) {
                case ProviderResult.ERROR_AUTH:
                    return WatchUi.loadResource(Rez.Strings.ErrorNoKey) as String;
                case ProviderResult.ERROR_NETWORK:
                    return WatchUi.loadResource(Rez.Strings.ErrorNetwork) as String;
                default:
                    return WatchUi.loadResource(Rez.Strings.ErrorNetwork) as String;
            }
        }

        // --- UI ---

        function requestUiUpdate() as Void {
            WatchUi.requestUpdate();
        }

    }

}
