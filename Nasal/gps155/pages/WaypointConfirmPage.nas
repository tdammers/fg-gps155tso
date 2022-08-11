var WaypointConfirmPage = {
    new: func (waypoint, accept, reject) {
        return {
            parents: [WaypointConfirmPage, BasePage],
            waypoint: waypoint,
            accept: accept,
            reject: reject,
        };
    },

    start: func {
        call(BasePage.start, [], me);
        me.redraw();
    },

    redraw: func {
        var extraInfo = '';
        var type = '';
        if (ghosttype(me.waypoint) == 'airport') {
        }
        elsif (me.waypoint.type == 'VOR') {
            extraInfo = format25khz(me.waypoint.frequency / 100);
        }
        elsif (me.waypoint.type == 'NDB') {
            extraInfo = format1khz(me.waypoint.frequency / 100);
        }
        var db = getWaypointDistanceAndBearing(me.waypoint);
        putLine(0,
            sprintf("%-3s %-5s %-11s",
                getWaypointType(me.waypoint, 1),
                substr(me.waypoint.id, 0, 5),
                extraInfo));
        putLine(1,
            sprintf(' %3i' ~ sc.deg ~ ' %5s',
                db.bearing,
                formatDistance(db.distance)));
        putLine(2,
            sprintf(' %-15s ok?',
                shorten(me.waypoint.name, 15)));
    },

    handleInput: func (what, amount) {
        if (call(BasePage.handleInput, [what, amount], me)) {
            return 1;
        }
        elsif (what == 'ENT') {
            me.accept();
            return 1;
        }
        elsif (what == 'CLR') {
            me.reject();
            return 1;
        }
    },
};
