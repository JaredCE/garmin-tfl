import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

module BusNearMe {

    // Layout values computed once based on screen shape and size.
    // All draw functions read from this so there are no hardcoded pixel values.
    class Layout {

        var w           as Number;
        var h           as Number;
        var cx          as Number;
        var cy          as Number;
        var isRound     as Boolean;

        // Header zone
        var headerY     as Number;   // centre Y of header text
        var dividerY    as Number;   // Y of thin line under header
        var dividerX    as Number;   // left X of header divider (mirrors right)

        // List zone
        var listTop     as Number;   // Y where first row starts
        var stopRowH    as Number;   // height of each stop row
        var arrRowH     as Number;   // height of each arrival row
        var stopVisible as Number;   // how many stop rows fit
        var arrVisible  as Number;   // how many arrival rows fit

        // Row decoration
        var marginX     as Number;   // outer margin for highlight rect and row dividers
        var maxStopChars   as Number;
        var maxHeaderChars as Number;
        var maxDestChars   as Number;

        // Bottom zone
        var dotsY       as Number;   // Y of scroll indicator dots
        var hintY       as Number;   // Y of bottom hint text

        function initialize() {
            var ds    = System.getDeviceSettings();
            w         = ds.screenWidth;
            h         = ds.screenHeight;
            cx        = w / 2;
            cy        = h / 2;

            var shape = ds.screenShape;
            isRound   = (shape == System.SCREEN_SHAPE_ROUND ||
                        shape == System.SCREEN_SHAPE_SEMI_ROUND);

            if (isRound) {
                headerY      = (h * 0.14).toNumber();
                dividerY     = (h * 0.18).toNumber();
                dividerX     = (w * 0.23).toNumber();
                listTop      = (h * 0.21).toNumber();
                marginX      = (w * 0.08).toNumber();
                dotsY        = (h * 0.86).toNumber();
                hintY        = (h * 0.92).toNumber();

                var charWidth   = (w * 0.046).toNumber();
                if (charWidth < 1) { charWidth = 1; }
                maxStopChars    = (w * 0.77).toNumber() / charWidth;
                maxHeaderChars  = (w * 0.69).toNumber() / charWidth;
                maxDestChars    = (w * 0.50).toNumber() / charWidth;
            } else {
                headerY      = (h * 0.04).toNumber();
                dividerY     = (h * 0.07).toNumber();
                dividerX     = (w * 0.01).toNumber();
                listTop      = (h * 0.10).toNumber();
                marginX      = (w * 0.01).toNumber();
                dotsY        = (h * 0.91).toNumber();
                hintY        = (h * 0.97).toNumber();

                var charWidth   = (w * 0.046).toNumber();
                if (charWidth < 1) { charWidth = 1; }
                maxStopChars    = (w * 0.90).toNumber() / charWidth;
                maxHeaderChars  = (w * 0.90).toNumber() / charWidth;
                maxDestChars    = (w * 0.65).toNumber() / charWidth;
            }

            // stopRowH, arrRowH, stopVisible, arrVisible computed later in onUpdate
            // once we have a dc to measure font heights
            stopRowH     = 0;
            arrRowH      = 0;
            stopVisible  = 3;
            arrVisible   = 3;
        }

        function computeRowHeights(dc as Graphics.Dc) as Void {
            // Row height = main font + small font + 3 lots of padding
            var mainH  = dc.getFontHeight(Graphics.FONT_SMALL);
            var subH   = dc.getFontHeight(Graphics.FONT_XTINY);
            var pad    = (h * 0.04).toNumber(); // 4% of screen height as padding
            if (pad < 4) { pad = 4; }

            stopRowH = mainH + subH + (pad * 3);
            arrRowH  = stopRowH;

            // How many rows fit between listTop and dotsY
            var listH   = dotsY - listTop - 10;
            stopVisible = listH / stopRowH;
            arrVisible  = listH / arrRowH;
            if (stopVisible < 1) { stopVisible = 1; }
            if (arrVisible  < 1) { arrVisible  = 1; }
        }

    }

    class AppView extends WatchUi.View {

        function initialize() {
            View.initialize();
        }

        // Build a fresh Layout each frame — cheap struct read, no allocations
        function layout() as Layout {
            return new Layout();
        }

        function onUpdate(dc as Graphics.Dc) as Void {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();

            var ctrl = getApp().controller;
            var lm   = layout();
            lm.computeRowHeights(dc);  // finish layout now we have dc

            switch (ctrl.state) {
                case AppState.GPS:
                    drawCentered(dc, lm, WatchUi.loadResource(Rez.Strings.Loading) as String);
                    break;
                case AppState.FETCHING_STOPS:
                    drawCentered(dc, lm, WatchUi.loadResource(Rez.Strings.FetchingStops) as String);
                    break;
                case AppState.FETCHING_ARRIVALS:
                    drawCentered(dc, lm, WatchUi.loadResource(Rez.Strings.FetchingArrivals) as String);
                    break;
                case AppState.STOPS:
                    drawStops(dc, lm, ctrl.stops as Array, ctrl.scrollIndex);
                    break;
                case AppState.ARRIVALS:
                    drawArrivals(
                        dc, lm,
                        ctrl.arrivals     as Array,
                        ctrl.arrivalsRaw  as Array,
                        ctrl.selectedStop as Stop,
                        ctrl.scrollIndex
                    );
                    break;
                case AppState.ERROR:
                    drawError(dc, lm, ctrl.errorMsg as String);
                    break;
            }
        }

        // ---------------------------------------------------------------
        // Shared helpers
        // ---------------------------------------------------------------

        function drawCentered(dc as Graphics.Dc, lm as Layout, msg as String) as Void {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                lm.cx, lm.cy,
                Graphics.FONT_MEDIUM,
                msg,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        function drawError(dc as Graphics.Dc, lm as Layout, msg as String) as Void {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                lm.cx, lm.cy - 20,
                Graphics.FONT_MEDIUM,
                msg,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                lm.cx, lm.cy + 20,
                Graphics.FONT_SMALL,
                WatchUi.loadResource(Rez.Strings.Refresh) as String,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        function drawHeader(
            dc    as Graphics.Dc,
            lm    as Layout,
            title as String
        ) as Void {
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                lm.cx, lm.headerY,
                Graphics.FONT_XTINY,
                title,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(lm.dividerX, lm.dividerY, lm.w - lm.dividerX, lm.dividerY);
        }

        function drawHint(dc as Graphics.Dc, lm as Layout, msg as String) as Void {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                lm.cx, lm.hintY,
                Graphics.FONT_XTINY,
                msg,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        function truncate(str as String, maxChars as Number) as String {
            if (str.length() > maxChars) {
                return str.substring(0, maxChars - 2) + "..";
            }
            return str;
        }

        // ---------------------------------------------------------------
        // Stop list
        // ---------------------------------------------------------------

        function drawStops(
            dc          as Graphics.Dc,
            lm          as Layout,
            stops       as Array,
            scrollIndex as Number
        ) as Void {

            drawHeader(dc, lm, "NEARBY STOPS");

            var maxScroll = stops.size() - lm.stopVisible;
            if (maxScroll < 0) { maxScroll = 0; }
            var idx = scrollIndex;
            if (idx > maxScroll) { idx = maxScroll; }
            if (idx < 0)         { idx = 0; }

            for (var i = 0; i < lm.stopVisible && (i + idx) < stops.size(); i++) {
                var stop       = stops[i + idx] as Stop;
                var y          = lm.listTop + (i * lm.stopRowH);
                var isSelected = (i + idx) == scrollIndex;
                var isLast     = (i + idx) == stops.size() - 1;
                drawStopRow(dc, lm, stop, y, isSelected, isLast);
            }

            if (stops.size() > lm.stopVisible) {
                drawScrollDots(dc, lm, stops.size(), lm.stopVisible, idx);
            }

            drawHint(dc, lm, "START to select");
        }

        function drawStopRow(
            dc         as Graphics.Dc,
            lm         as Layout,
            stop       as Stop,
            y          as Number,
            isSelected as Boolean,
            isLast     as Boolean
        ) as Void {

            var mainH = dc.getFontHeight(Graphics.FONT_SMALL);
            var subH  = dc.getFontHeight(Graphics.FONT_XTINY);
            var pad   = (lm.h * 0.04).toNumber();
            if (pad < 4) { pad = 4; }

            // Name sits pad below top of row
            // Sub-label sits pad below bottom of name
            var nameY = y + pad;
            var subY  = nameY + mainH + pad;

            if (isSelected) {
                dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLUE);
                dc.fillRectangle(lm.marginX, y, lm.w - (lm.marginX * 2), lm.stopRowH);
            }

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                lm.cx, nameY,
                Graphics.FONT_SMALL,
                truncate(stop.name, lm.maxStopChars),
                Graphics.TEXT_JUSTIFY_CENTER
            );

            var subLabel = stop.distance + "m";
            if (stop.indicator.length() > 0) {
                subLabel = stop.indicator + " · " + stop.distance + "m";
            }

            dc.setColor(isSelected ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                lm.cx, subY,
                Graphics.FONT_XTINY,
                subLabel,
                Graphics.TEXT_JUSTIFY_CENTER
            );

            if (!isLast && !isSelected) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(lm.marginX, y + lm.stopRowH, lm.w - lm.marginX, y + lm.stopRowH);
            }
        }

        // ---------------------------------------------------------------
        // Arrivals
        // ---------------------------------------------------------------

        function drawArrivals(
            dc          as Graphics.Dc,
            lm          as Layout,
            arrivals    as Array,
            arrivalsRaw as Array,
            stop        as Stop,
            scrollIndex as Number
        ) as Void {

            drawHeader(dc, lm, truncate(stop.name, lm.maxHeaderChars));

            if (arrivals.size() == 0) {
                drawCentered(dc, lm, WatchUi.loadResource(Rez.Strings.NoArrivals) as String);
                return;
            }

            var maxScroll = arrivals.size() - lm.arrVisible;
            if (maxScroll < 0) { maxScroll = 0; }
            var idx = scrollIndex;
            if (idx > maxScroll) { idx = maxScroll; }
            if (idx < 0)         { idx = 0; }

            for (var i = 0; i < lm.arrVisible && (i + idx) < arrivals.size(); i++) {
                var arrival = arrivals[i + idx] as Arrival;
                var y       = lm.listTop + (i * lm.arrRowH);
                var isLast  = (i + idx) == arrivals.size() - 1;
                drawArrivalRow(dc, lm, arrival, arrivalsRaw, y, isLast);
            }

            if (arrivals.size() > lm.arrVisible) {
                drawScrollDots(dc, lm, arrivals.size(), lm.arrVisible, idx);
            }

            drawHint(dc, lm, "START to refresh");
        }

        function drawArrivalRow(
            dc          as Graphics.Dc,
            lm          as Layout,
            arrival     as Arrival,
            arrivalsRaw as Array,
            y           as Number,
            isLast      as Boolean
        ) as Void {

            var mainH = dc.getFontHeight(Graphics.FONT_SMALL);
            var pad   = (lm.h * 0.04).toNumber();
            if (pad < 4) { pad = 4; }

            var lineY = y + pad;
            var etaY  = lineY + mainH + pad;

            var lineX = lm.isRound
                ? lm.cx - (lm.w * 0.29).toNumber()
                : lm.marginX + 4;

            var lineDims = dc.getTextDimensions(arrival.line, Graphics.FONT_SMALL);
            var lineNumW = (lineDims[0] as Number) + 8;

            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                lineX, lineY,
                Graphics.FONT_SMALL,
                arrival.line,
                Graphics.TEXT_JUSTIFY_LEFT
            );

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                lineX + lineNumW, lineY,
                Graphics.FONT_SMALL,
                truncate(arrival.destination, lm.maxDestChars),
                Graphics.TEXT_JUSTIFY_LEFT
            );

            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                lm.cx, etaY,
                Graphics.FONT_XTINY,
                buildEtaLabel(arrivalsRaw, arrival),
                Graphics.TEXT_JUSTIFY_CENTER
            );

            if (!isLast) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(lm.marginX, y + lm.arrRowH, lm.w - lm.marginX, y + lm.arrRowH);
            }
        }

        // ---------------------------------------------------------------
        // ETA label builder — scans raw arrivals for same line+destination
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
            lm          as Layout,
            totalItems  as Number,
            visibleRows as Number,
            current     as Number
        ) as Void {
            var totalDots = totalItems - visibleRows + 1;
            if (totalDots <= 1) { return; }

            var dotSize = 4;
            var dotGap  = 8;
            var totalW  = (totalDots * dotSize) + ((totalDots - 1) * dotGap);
            var startX  = (lm.w - totalW) / 2;

            for (var i = 0; i < totalDots; i++) {
                var x = startX + (i * (dotSize + dotGap));
                dc.setColor(
                    i == current ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY,
                    Graphics.COLOR_TRANSPARENT
                );
                dc.fillCircle(x + dotSize / 2, lm.dotsY, dotSize / 2);
            }
        }

    }

}
