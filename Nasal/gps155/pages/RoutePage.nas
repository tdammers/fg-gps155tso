var RoutePage = {
    new: func () {
        var m = MultiPage.new(deviceProps.currentPage.rte, 'RTE');
        m.parents = [RoutePage] ~ m.parents;
        return m;
    },

    SUBPAGE_ACTIVE_ROUTE: 0,
    SUBPAGE_APPROACH_SELECT: 1,

    getNumSubpages: func { return 2; },
    getSubpage: func (i) {
        if (i == RoutePage.SUBPAGE_ACTIVE_ROUTE) {
            return ActiveRoutePage.new();
        }
        elsif (i == RoutePage.SUBPAGE_APPROACH_SELECT) {
            return ApproachSelectPage.new();
        }
        else {
            return nil;
        }
    },

    start: func {
        call(MultiPage.start, [], me);
        modeLightProp.setValue('RTE');
    },

    stop: func {
        call(MultiPage.stop, [], me);
        modeLightProp.setValue('');
    },
};

var ActiveRoutePage = {
    new: func () {
        return {
            parents: [ActiveRoutePage, BasePage],
            editableWaypointID: '',
            deletingWaypoint: 0,
        };
    },

    scrollResetTimer: 0,
    scrollPos: 0,

    start: func {
        call(BasePage.start, [], me);
        var fp = flightplan();
        if (fp != nil) {
            var idx = ActiveRoutePage.scrollPos + 1;
            if (idx < fp.getPlanSize()) {
                me.editableWaypointID = fp.getWP(idx).id;
            }
        }
        me.setSelectableFields();
        me.redraw();
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

    update: func (dt) {
        var fp = flightplan();
        if (me.selectedField < 0 and fp != nil) {
            ActiveRoutePage.scrollResetTimer -= dt;
            if (ActiveRoutePage.scrollResetTimer <= 0)
                ActiveRoutePage.scrollPos = math.max(0, fp.current - 1);
        }
        else {
            ActiveRoutePage.scrollResetTimer = 10;
        }
        me.redraw();
    },

    redraw: func {
        var fp = flightplan();
        var fromID = deviceProps.wp[0].ident.getValue() or '';
        var tgtID = deviceProps.wp[1].ident.getValue() or '';
        var mode = deviceProps.mode.getValue() or 'obs';
        var legInfo = '_____' ~ sc.arrowR ~ '_____';

        var lines = ['', 'NO ACTIVE ROUTE', ''];
        if (mode == 'dto') {
            legInfo = sprintf('go to:%-5s', navid5(tgtID));
        }
        elsif (mode == 'leg') {
            legInfo = sprintf('%-5s' ~ sc.arrowR ~ '%-5s',
                            navid5(fromID), navid5(tgtID));
        }

        lines[0] = sprintf('%-11s leg dtk', legInfo);

        if (fp != nil and fp.getPlanSize() > 1) {
            for (var y = 0; y < 2; y += 1) {
                var index = ActiveRoutePage.scrollPos + y;
                var wp = fp.getWP(index);
                var wpPrev = (index > 0) ? fp.getWP(index - 1) : nil;
                var current = index == fp.current;
                var first = ActiveRoutePage.scrollPos == 0;
                var last = ActiveRoutePage.scrollPos >= fp.getPlanSize() - 1;
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
                var wpSymbol = '';

                if (wpPrev != nil and wp != nil) {
                    # Determine IAF
                    # debug.dump(wp.wp_role, wpPrev.wp_role);
                    if (wp.wp_role == 'approach' and wpPrev.wp_role != 'approach') {
                        wpSymbol = sc['if'];
                    }
                }

                if (y == 1 and me.editingWaypoint()) {
                    identStr = me.editableWaypointID;
                }
                elsif (wp != nil) {
                    distStr = formatDistance(wp.leg_distance);
                    bearingStr = formatHeading(wp.leg_bearing);
                    identStr = navid5(wp.id, 5);
                }

                if (me.deletingWaypoint and y == 1) {
                    lines[y+1] = sprintf('%1s%1s%1s%_____           ',
                        (y == 0) ? ' ' : scrollSymbol,
                        wpSymbol,
                        current ? sc.arrowR : ':');
                }
                else {
                    lines[y+1] = sprintf('%1s%1s%1s%-5s %5s %4s',
                        (y == 0) ? ' ' : scrollSymbol,
                        wpSymbol,
                        current ? sc.arrowR : ':',
                        identStr,
                        distStr,
                        bearingStr);
                }
            }
        }
        else {
            if (me.editingWaypoint()) {
                lines[2] = sprintf('   %-5s _____ ___°', me.editableWaypointID);
            }
        }

        putScreen(lines);
    },

    handleInput: func (what, amount) {
        var fp = flightplan();
        if (call(BasePage.handleInput, [what, amount], me)) {
            return 1;
        }
        elsif (what == 'data-inner') {
            if (fp == nil) {
                ActiveRoutePage.scrollPos = 0;
            }
            else {
                var maxPos = fp.getPlanSize() - 2;
                ActiveRoutePage.scrollPos += amount;
                if (ActiveRoutePage.scrollPos < 0) ActiveRoutePage.scrollPos = 0;
                if (ActiveRoutePage.scrollPos > maxPos) ActiveRoutePage.scrollPos = maxPos;
            }
            var idx = ActiveRoutePage.scrollPos + 1;
            if (fp != nil and idx < fp.getPlanSize()) {
                me.editableWaypointID = fp.getWP(idx).id;
            }
            ActiveRoutePage.scrollResetTimer = 10;
            me.redraw();
        }
        elsif (what == 'CLR') {
            (func (returnPage) {
                loadPage(
                    ConfirmPage.new(
                        "CLEAR ROUTE",
                        # confirm
                        func {
                            fp.cleanPlan();
                            RoutePage.scrollPos = 0;
                            loadPage(NavPage.new());
                        },
                        # reject
                        func {
                            loadPage(returnPage);
                        }
                    ));
                })(currentPage);
        }
        elsif (what == 'DCT') {
            (func (returnPage) {
                var wp = fp.getWP(RoutePage.scrollPos + 1);
                if (wp != nil) {
                    # debug.dump(wp);
                    loadPage(
                        WaypointConfirmPage.new(
                            wp,
                            # confirm
                            func {
                                setDTO(wp);
                                loadPage(NavPage.new(NavPage.SUBPAGE_CDI));
                            },
                            # reject
                            func {
                                loadPage(returnPage);
                            }
                        ));
                }
                else {
                    # If no "current" waypoint is defined, fire up a waypoint
                    # selector menu (TODO).
                }
            })(currentPage);
        }
        elsif (what == 'ENT' and me.deletingWaypoint) {
            fp.deleteWP(RoutePage.scrollPos + 1);
            me.deletingWaypoint = 0;
            me.selectedField = -1;
            unsetCursor();
            me.redraw();
        }
        elsif (what == 'ENT' and me.editingWaypoint()) {
            var self = me;
            searchAndConfirmWaypoint(me.editableWaypointID, self, func (waypoint) {
                var leg = createWP(waypoint.lat, waypoint.lon, waypoint.ident);
                if (fp.getPlanSize() == 1 and (ghosttype(waypoint) == 'airport' or ghosttype(waypoint) == 'FGAirport')) {
                    fp.destination = findAirportsByICAO(waypoint.id)[0];
                }
                elsif (RoutePage.scrollPos >= fp.getPlanSize())
                    fp.appendWP(leg);
                else
                    fp.insertWPAfter(leg, RoutePage.scrollPos);
                RoutePage.scrollPos += 1;
            });
        }
        elsif (what == 'ENT' and deviceProps.mode.getValue() != 'leg') {
            deviceProps.command.setValue('leg');
            # TODO: find closest leg
            me.redraw();
        }
        elsif (what == 'CLR' and me.deletingWaypoint) {
            me.deletingWaypoint = 0;
            me.redraw();
        }
        elsif (what == 'CLR' and me.editingWaypoint() and me.scrollPos + 1 < fp.getPlanSize()) {
            me.deletingWaypoint = 1;
            me.redraw();
        }
    },
};

var ApproachSelectPage = {
    new: func {
        var m = BasePage.new();
        m.parents = [ApproachSelectPage] ~ m.parents;
        m.selectedApproach = nil;
        m.fp = nil;
        m.available = 0;
        m.scrollPos = 0;
        m.approaches = [];
        return m;
    },

    start: func {
        var self = me;
        call(BasePage.start, [], me);
        me.fp = flightplan();
        me.available = me.fp.active and me.fp.destination != nil;
        me.approaches = (me.fp.destination == nil) ? [] : me.fp.destination.getApproachList();
        me.selectableFields = [];
        if (me.available) {
            me.selectableFields = [
                {
                    row: 1,
                    col: 2,
                    accept: func {
                        self.fp.approach = self.approaches[self.scrollPos];
                        self.deselectField();
                        self.redraw();
                    },
                },
                {
                    row: 2,
                    col: 2,
                    accept: func {
                        self.fp.approach = self.approaches[self.scrollPos + 1];
                        self.deselectField();
                        self.redraw();
                    },
                },
            ];
        }
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
        me.redraw();
    },

    redraw: func {
        if (me.available) {
            putLine(0,
                sprintf("Rt 0 %4s %5s appr",
                    me.fp.destination.id,
                    (me.fp.approach == nil) ? 'slct' : '*actv'));
            for (var i = 0; i < 2; i += 1) {
                var pos = me.scrollPos + i;
                var approach = me.approaches[pos] or nil;
                var marker = ' ';
                if (i == 1) {
                    if (pos == 1)
                        marker = sc.arrowDn;
                    elsif (pos == size(me.approaches) - 1)
                        marker = sc.arrowUp;
                    else
                        marker = sc.updown;
                }
                if (approach == nil)
                    putLine(i + 1, marker);
                else
                    putLine(i + 1, sprintf('%1s%1s%s',
                        marker, 
                        (me.fp.approach != nil and approach == me.fp.approach.id) ? '*' : '',
                        formatApproach(approach)));
            }
        }
        else {
            putScreen(["Rt 0 ----  slct appr", "NO ROUTE", ""]);
        }
    },

    handleInput: func (what, amount=1) {
        if (call(BasePage.handleInput, [what, amount], me)) {
            return 1;
        }
        elsif (what == 'data-inner') {
            me.scrollPos += amount;
            if (!me.available)
                me.scrollPos = 0;
            else
                me.scrollPos =
                    math.min(size(me.approaches) - 2,
                    math.max(0,
                    me.scrollPos));
            me.redraw();
        }
    },
};
