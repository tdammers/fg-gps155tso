var RoutePage = {
    new: func () {
        return {
            parents: [RoutePage, BasePage],
            editableWaypointID: '',
            deletingWaypoint: 0,
        };
    },

    scrollPos: 0,

    start: func {
        call(BasePage.start, [], me);
        modeLightProp.setValue('RTE');
        var fp = flightplan();
        if (fp != nil) {
            RoutePage.scrollPos = fp.current;
            var idx = RoutePage.scrollPos + 1;
            if (idx < fp.getPlanSize()) {
                me.editableWaypointID = fp.getWP(idx).id;
            }
        }
        me.setSelectableFields();
        me.redraw();
    },

    stop: func {
        call(BasePage.stop, [], me);
        modeLightProp.setValue('');
    },

    editingWaypoint: func {
        return (me.selectedField >= 0 and me.selectedField < 5);
    },

    setSelectableFields: func {
        var self = me;
        me.selectableFields = [];
        for (var i = 0; i < 5; i += 1) {
            (func (i) {
                append(self.selectableFields, {
                    row: 2,
                    col: 3 + i,
                    changeValue: func (amount) {
                        self.editableWaypointID = scrollChar(self.editableWaypointID, i, amount);
                        self.redraw();
                    }
                });
            })(i);
        }
    },

    update: func {
        me.redraw();
    },

    redraw: func {
        var fp = flightplan();
        var from = deviceProps.wp[0].ident.getValue() or '';
        var to = deviceProps.wp[1].ident.getValue() or '';

        var lines = ['', 'NO ACTIVE ROUTE', ''];

        lines[0] = sprintf('%-5s' ~ sc.arrowR ~ '%-5s leg dtk',
            navid5(from),
            navid5(to));

        if (fp != nil) {
            for (var y = 0; y < 2; y += 1) {
                var wp = fp.getWP(RoutePage.scrollPos + y);
                var current = RoutePage.scrollPos + y == fp.current;
                var first = RoutePage.scrollPos == 0;
                var last = RoutePage.scrollPos >= fp.getPlanSize() - 1;
                var scrollSymbol = ' ';
                if (!first) {
                    if (!last) {
                        scrollSymbol = sc.updown;
                    }
                    else {
                        scrollSymbol = sc.arrowUp;
                    }
                }
                else {
                    if (!last) {
                        scrollSymbol = sc.arrowDn;
                    }
                    else {
                        scrollSymbol = ' ';
                    }
                }

                var distStr = '__.___';
                var bearingStr = '___°';
                var identStr = '';

                if (y == 1 and me.selectedField >= 0 and me.selectedField < 5) {
                    identStr = me.editableWaypointID;
                }
                elsif (wp != nil) {
                    distStr = formatDistance(wp.leg_distance);
                    bearingStr = formatHeading(wp.leg_bearing);
                    identStr = navid5(wp.id, 5);
                }

                if (me.deletingWaypoint and y == 1) {
                    lines[y+1] = sprintf('%1s %1s%-5s    Delete?',
                        (y == 0) ? ' ' : scrollSymbol,
                        current ? sc.arrowR : ':',
                        identStr);
                }
                else {
                    lines[y+1] = sprintf('%1s %1s%-5s %5s %4s',
                        (y == 0) ? ' ' : scrollSymbol,
                        current ? sc.arrowR : ':',
                        identStr,
                        distStr,
                        bearingStr);
                }
            }
        }

        putScreen(lines);
    },

    handleInput: func (what, amount) {
        if (call(BasePage.handleInput, [what, amount], me)) {
            return 1;
        }
        elsif (what == 'data-inner') {
            var fp = flightplan();
            if (fp == nil) {
                RoutePage.scrollPos = 0;
            }
            else {
                var maxPos = fp.getPlanSize() - 1;
                RoutePage.scrollPos += amount;
                if (RoutePage.scrollPos < 0) RoutePage.scrollPos = 0;
                if (RoutePage.scrollPos > maxPos) RoutePage.scrollPos = maxPos;
            }
            var idx = RoutePage.scrollPos + 1;
            if (fp != nil and idx < fp.getPlanSize()) {
                me.editableWaypointID = fp.getWP(idx).id;
            }
            me.redraw();
        }
        elsif (what == 'ENT' and me.deletingWaypoint) {
            var fp = flightplan();
            fp.deleteWP(RoutePage.scrollPos + 1);
            me.deletingWaypoint = 0;
            me.selectedField = -1;
            unsetCursor();
            me.redraw();
        }
        elsif (what == 'ENT' and me.editingWaypoint()) {
            var self = me;
            searchAndConfirmWaypoint(me.editableWaypointID, self, func (waypoint) {
                var fp = flightplan();
                var leg = createWP(waypoint.lat, waypoint.lon, waypoint.ident);
                if (RoutePage.scrollPos >= fp.getPlanSize())
                    fp.appendWP(leg);
                else
                    fp.insertWPAfter(leg, RoutePage.scrollPos);
                RoutePage.scrollPos += 1;
            });
        }
        elsif (what == 'CLR' and me.deletingWaypoint) {
            me.deletingWaypoint = 0;
            me.redraw();
        }
        elsif (what == 'CLR' and me.editingWaypoint()) {
            me.deletingWaypoint = 1;
            me.redraw();
        }
    },
};

