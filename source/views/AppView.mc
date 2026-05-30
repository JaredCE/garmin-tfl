import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

module BusNearMe {

    class AppView extends WatchUi.View {

        function initialize() {
            View.initialize();
        }

        function onUpdate(dc as Graphics.Dc) as Void {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();

            var ctrl = getApp().controller;

            switch (ctrl.state) {
                case AppState.GPS:
                    drawCentered(dc, WatchUi.loadResource(Rez.Strings.Loading) as String);
                    break;
                case AppState.FETCHING_STOPS:
                    drawCentered(dc, WatchUi.loadResource(Rez.Strings.FetchingStops) as String);
                    break;
                case AppState.FETCHING_ARRIVALS:
                    drawCentered(dc, WatchUi.loadResource(Rez.Strings.FetchingArrivals) as String);
                    break;
                case AppState.STOPS:
                    drawStops(dc, ctrl.stops as Array, ctrl.scrollIndex, ctrl.radius);
                    break;
                case AppState.ARRIVALS:
                    drawArrivals(
                        dc,
                        ctrl.arrivals     as Array,
                        ctrl.arrivalsRaw  as Array,
                        ctrl.selectedStop as Stop,
                        ctrl.scrollIndex
                    );
                    break;
                case AppState.ERROR:
                    drawError(dc, ctrl.errorMsg as String);
                    break;
            }
        }

        // ---------------------------------------------------------------
        // Screen geometry helpers
        // ---------------------------------------------------------------

        // Returns true if the device has a round screen
        function isRound() as Boolean {
            var shape = System.getDeviceSettings().screenShape;
            return (shape == System.SCREEN_SHAPE_ROUND ||
                    shape == System.SCREEN_SHAPE_SEMI_ROUND);
        }

        // Proportional value — n% of dimension d
        function pct(d as Number, n as Float) as Number {
            return (d * n).toNumber();
        }

        // Truncate string to maxChars, appending ".." if trimmed
        function trunc(str as String, maxChars as Number) as String {
            if (str.length() > maxChars) {
                return str.substring(0, maxChars - 2) + "..";
            }
            return str;
        }

        // ---------------------------------------------------------------
        // Loading / error
        // ---------------------------------------------------------------

        function drawCentered(dc as Graphics.Dc, msg as String) as Void {
            var w = dc.getWidth();
            var h = dc.getHeight();
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                w / 2, h / 2,
                Graphics.FONT_MEDIUM,
                msg,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        function drawError(dc as Graphics.Dc, msg as String) as Void {
            var w = dc.getWidth();
            var h = dc.getHeight();
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                w / 2, (h / 2) - 20,
                Graphics.FONT_MEDIUM,
                msg,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                w / 2, (h / 2) + 20,
                Graphics.FONT_SMALL,
                WatchUi.loadResource(Rez.Strings.Refresh) as String,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // ---------------------------------------------------------------
        // Stop list
        // ---------------------------------------------------------------

        function drawStops(
            dc          as Graphics.Dc,
            stops       as Array,
            scrollIndex as Number,
            radius      as Number
        ) as Void {
            var w  = dc.getWidth();
            var h  = dc.getHeight();
            var cx = w / 2;
            var round = isRound();

            // Font heights — row sizing derived from actual font metrics
            var mainH = dc.getFontHeight(Graphics.FONT_SMALL);
            var subH  = dc.getFontHeight(Graphics.FONT_XTINY);
            var pad   = pct(h, 0.03f);
            if (pad < 3) { pad = 3; }

            // rowHeight = top pad + main text + pad + sub text + bottom pad
            var rowH = pad + mainH + pad + subH + pad;

            // Header zone — proportional to screen height
            var headerY  = pct(h, 0.08f);
            var dividerY = pct(h, 0.14f);
            var dividerX = round ? pct(w, 0.23f) : pct(w, 0.01f);
            var listTop  = dividerY + pad;

            // Bottom zone
            var hintY    = round ? pct(h, 0.88f) : h - pct(h, 0.03f);
            var dotsY    = hintY - subH - pad;

            // How many rows fit
            var listH      = dotsY - listTop - pad;
            var visibleRows = listH / rowH;
            if (visibleRows < 1) { visibleRows = 1; }

            // Header
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, headerY,
                Graphics.FONT_XTINY,
                "NEARBY STOPS · " + radius + "m",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(dividerX, dividerY, w - dividerX, dividerY);

            // Clamp scroll
            var maxScroll = stops.size() - visibleRows;
            if (maxScroll < 0) { maxScroll = 0; }
            var idx = scrollIndex;
            if (idx > maxScroll) { idx = maxScroll; }
            if (idx < 0)         { idx = 0; }

            // Rows
            var marginX = round ? pct(w, 0.08f) : pct(w, 0.01f);
            var maxChars = round ? 20 : 28;

            for (var i = 0; i < visibleRows && (i + idx) < stops.size(); i++) {
                var stop       = stops[i + idx] as Stop;
                var y          = listTop + (i * rowH);
                var isSelected = (i + idx) == scrollIndex;
                var isLast     = (i + idx) == stops.size() - 1;

                // Highlight
                if (isSelected) {
                    dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLUE);
                    dc.fillRectangle(marginX, y, w - (marginX * 2), rowH);
                }

                // Stop name — top-aligned so descenders don't overlap sub-label
                var nameY = y + pad;
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    cx, nameY,
                    Graphics.FONT_SMALL,
                    trunc(stop.name, maxChars),
                    Graphics.TEXT_JUSTIFY_CENTER
                );

                // Sub-label — placed below full font height
                var subLabel = stop.distance + "m";
                if (stop.indicator.length() > 0) {
                    subLabel = stop.indicator + " · " + stop.distance + "m";
                }
                var subY = nameY + mainH + pad;
                dc.setColor(isSelected ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    cx, subY,
                    Graphics.FONT_XTINY,
                    subLabel,
                    Graphics.TEXT_JUSTIFY_CENTER
                );

                // Divider at exact bottom of row
                if (!isLast && !isSelected) {
                    dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(marginX, y + rowH, w - marginX, y + rowH);
                }
            }

            // Scroll dots
            if (stops.size() > visibleRows) {
                drawScrollDots(dc, stops.size(), visibleRows, idx, w, dotsY);
            }

            // Hint
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, hintY,
                Graphics.FONT_XTINY,
                "START=select  HOLD UP=radius",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // ---------------------------------------------------------------
        // Arrivals
        // ---------------------------------------------------------------

        function drawArrivals(
            dc          as Graphics.Dc,
            arrivals    as Array,
            arrivalsRaw as Array,
            stop        as Stop,
            scrollIndex as Number
        ) as Void {
            var w  = dc.getWidth();
            var h  = dc.getHeight();
            var cx = w / 2;
            var round = isRound();

            var mainH = dc.getFontHeight(Graphics.FONT_SMALL);
            var subH  = dc.getFontHeight(Graphics.FONT_XTINY);
            var pad   = pct(h, 0.03f);
            if (pad < 3) { pad = 3; }

            var rowH = pad + mainH + pad + subH + pad;

            var headerY  = pct(h, 0.08f);
            var dividerY = pct(h, 0.14f);
            var dividerX = round ? pct(w, 0.23f) : pct(w, 0.01f);
            var listTop  = dividerY + pad;
            var hintY    = round ? pct(h, 0.88f) : h - pct(h, 0.03f);
            var dotsY    = hintY - subH - pad;

            var listH       = dotsY - listTop - pad;
            var visibleRows = listH / rowH;
            if (visibleRows < 1) { visibleRows = 1; }

            // Header
            var maxHeaderChars = round ? 18 : 30;
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, headerY,
                Graphics.FONT_XTINY,
                trunc(stop.name, maxHeaderChars),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(dividerX, dividerY, w - dividerX, dividerY);

            if (arrivals.size() == 0) {
                drawCentered(dc, WatchUi.loadResource(Rez.Strings.NoArrivals) as String);
                return;
            }

            var maxScroll = arrivals.size() - visibleRows;
            if (maxScroll < 0) { maxScroll = 0; }
            var idx = scrollIndex;
            if (idx > maxScroll) { idx = maxScroll; }
            if (idx < 0)         { idx = 0; }

            var marginX    = round ? pct(w, 0.08f) : pct(w, 0.01f);
            var maxDestChars = round ? 13 : 20;

            // lineX — where the line number starts
            // On round: offset left from centre to keep content in safe zone
            // On rect:  from left margin
            var lineX = round ? cx - pct(w, 0.29f) : marginX + 4;

            for (var i = 0; i < visibleRows && (i + idx) < arrivals.size(); i++) {
                var arrival = arrivals[i + idx] as Arrival;
                var y       = listTop + (i * rowH);
                var isLast  = (i + idx) == arrivals.size() - 1;

                // Line number — top-aligned
                var lineY = y + pad;
                dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    lineX, lineY,
                    Graphics.FONT_SMALL,
                    arrival.line,
                    Graphics.TEXT_JUSTIFY_LEFT
                );

                // Destination — measure line number width so they never overlap
                var lineDims = dc.getTextDimensions(arrival.line, Graphics.FONT_SMALL);
                var lineNumW = (lineDims[0] as Number) + 8;
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    lineX + lineNumW, lineY,
                    Graphics.FONT_SMALL,
                    trunc(arrival.destination, maxDestChars),
                    Graphics.TEXT_JUSTIFY_LEFT
                );

                // ETA — placed below full font height, never overlaps line above
                var etaY = lineY + mainH + pad;
                dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    cx, etaY,
                    Graphics.FONT_XTINY,
                    buildEtaLabel(arrivalsRaw, arrival),
                    Graphics.TEXT_JUSTIFY_CENTER
                );

                // Divider at exact bottom of row
                if (!isLast) {
                    dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(marginX, y + rowH, w - marginX, y + rowH);
                }
            }

            if (arrivals.size() > visibleRows) {
                drawScrollDots(dc, arrivals.size(), visibleRows, idx, w, dotsY);
            }

            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, hintY,
                Graphics.FONT_XTINY,
                "START to refresh",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // ---------------------------------------------------------------
        // ETA label builder
        // ---------------------------------------------------------------

        function buildEtaLabel(arrivals as Array, current as Arrival) as String {
            var label = "";
            var count = 0;

            for (var i = 0; i < arrivals.size() && count < 3; i++) {
                var a = arrivals[i] as Arrival;
                if (!a.line.equals(current.line) ||
                    !a.destination.equals(current.destination)) {
                    continue;
                }
                if (count > 0) { label = label + " · "; }
                label = label + a.etaLabel();
                count++;
            }

            return label;
        }

        // ---------------------------------------------------------------
        // Scroll dots
        // ---------------------------------------------------------------

        function drawScrollDots(
            dc          as Graphics.Dc,
            totalItems  as Number,
            visibleRows as Number,
            current     as Number,
            w           as Number,
            dotY        as Number
        ) as Void {
            var totalDots = totalItems - visibleRows + 1;
            if (totalDots <= 1) { return; }

            var dotSize = 4;
            var dotGap  = 8;
            var totalW  = (totalDots * dotSize) + ((totalDots - 1) * dotGap);
            var startX  = (w - totalW) / 2;

            for (var i = 0; i < totalDots; i++) {
                var x = startX + (i * (dotSize + dotGap));
                dc.setColor(
                    i == current ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY,
                    Graphics.COLOR_TRANSPARENT
                );
                dc.fillCircle(x + dotSize / 2, dotY, dotSize / 2);
            }
        }

    }

}
