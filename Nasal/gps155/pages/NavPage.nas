var NavPage = {
    new: func {
        var m = MultiPage.new(deviceProps.currentPage.nav, 'NAV', 0);
        m.parents = [NavPage] ~ m.parents;
        return m;
    },

    SUBPAGE_CDI: 0,
    SUBPAGE_POSITION: 1,
    SUBPAGE_MENU1: 2,
    SUBPAGE_MENU2: 3,

    getNumPages: func { return 2; },

    start: func {
        call(MultiPage.start, [], me);
        modeLightProp.setValue('NAV');
    },

    stop: func {
        call(MultiPage.stop, [], me);
        modeLightProp.setValue('');
    },

    handleSubpageChange: func {
        me.updateVisibleWaypoint();
    },

    updateVisibleWaypoint: func {
        if (me.getCurrentPage() == 1) {
            visibleWaypoint = referenceWaypoint;
        }
        else {
            visibleWaypoint = nil;
        }
    },

    setSelectableFields: func {
        var self = me;
        if (me.getCurrentPage() == 1) {
            me.selectableFields = [
                { row: 2, col:  1,
                    changeValue: func (amount) {
                        changeRefMode(amount);
                        self.updateVisibleWaypoint();
                        self.setSelectableFields();
                        self.redraw();
                    }
                },
            ];
            if (deviceProps.referenceMode.getValue() == 'wpt') {
                for (var i = 0; i < 5; i += 1) {
                    (func (i) {
                        append(me.selectableFields, {
                            row: 2,
                            col: 5 + i,
                            changeValue: func (amount) {
                                var str = deviceProps.referenceSearchID.getValue();
                                deviceProps.referenceSearchID.setValue(scrollChar(str, i, amount));
                                self.redraw();
                            }
                        });
                    })(i);
                }
            }
        }
        else {
            me.selectableFields = [];
        }
    },

    handleInput: func (what, amount=0) {
        var self = me;
        if (call(MultiPage.handleInput, [what, amount], me)) {
            return 1;
        }
        elsif (what == 'ENT' and
               me.getCurrentPage() == 1 and
               deviceProps.referenceMode.getValue() == 'wpt' and
               me.selectedField > 0) {
            var searchID = deviceProps.referenceSearchID.getValue();

            searchAndConfirmWaypoint(searchID, self, func (waypoint) {
                referenceWaypoint = waypoint;
                deviceProps.referenceSearchID.setValue(referenceWaypoint.id);
                updateReference();
            });
            return 1;
        }
        else {
            return 0;
        }
    },

    update: func (dt) {
        me.updateVisibleWaypoint();
        me.redraw();
    },

    redraw: func {
        if (me.getCurrentPage() == 0)
            me.redrawCDI();
        elsif (me.getCurrentPage() == 1)
            me.redrawPosition();
        elsif (me.getCurrentPage() == 2)
            me.redrawNavMenu(0);
        elsif (me.getCurrentPage() == 3)
            me.redrawNavMenu(1);
    },

    redrawNavMenu: func (n) {
        putLine(0, "NAV MENU " ~ (n+1));
        putLine(1, "");
        putLine(2, "(not implemented)");
    },

    redrawCDI: func {
        var mode = getprop('/instrumentation/gps/mode') or 'obs';
        var cte = getprop('/instrumentation/gps/cdi-deflection') or 0;
        var tgtID = getprop('/instrumentation/gps/wp/wp[1]/ID') or '';
        var fromID = getprop('/instrumentation/gps/wp/wp[0]/ID') or '';
        var tgtBRG = getprop('/instrumentation/gps/wp/wp[1]/bearing-mag-deg');
        var tgtDST = getprop('/instrumentation/gps/wp/wp[1]/distance-nm');
        var legTRK = getprop('/instrumentation/gps/wp/leg-mag-course-deg');
        var ete = getprop('/instrumentation/gps/wp/wp[1]/TTW') or '';
        var fromFlag = getprop('/instrumentation/gps/from-flag') or 0;
        var gs = getprop('/instrumentation/gps/indicated-ground-speed-kt') or 0;

        var cdiFormatted = 'No actv wpt';
        var gsFormatted = '___ ';
        var distanceFormatted = "___" ~ smallStr('.__') ~ sc.nm;
        var trackFormatted = "___";
        var legInfo = "_____" ~ sc.arrowR ~ "_____";
        var eteFormatted = "__:__";

        if (tgtID != '' or mode == 'obs') {
            var needlePos = 5 + math.min(5, math.max(-5, math.round(cte / 2)));
            cdiFormatted = '';
            var i = 0;
            for (i = 0; i < needlePos; i += 1)
                cdiFormatted ~= sc.dot;
            if (fromFlag)
                cdiFormatted ~= sc.arrowDn;
            else
                cdiFormatted ~= sc.arrowUp;
            for (i = needlePos + 1; i < 11; i += 1)
                cdiFormatted ~= sc.dot;
            gsFormatted = formatSpeed(gs, 'kt');
            distanceFormatted = formatDistance(tgtDST);
            trackFormatted = formatHeading(legTRK);
            if (mode == 'dto' or (mode == 'leg' and fromID == '')) {
                legInfo = sprintf('go to:%-5s', navid5(tgtID));
            }
            elsif (mode == 'leg') {
                legInfo = sprintf('%-5s' ~ sc.arrowR ~ '%-5s',
                                navid5(fromID), navid5(tgtID));
            }
            if (ete != '')
                eteFormatted = substr(ete, 0, 5);
        }

        putLine(0, cdiFormatted ~ " gs :" ~ gsFormatted);
        putLine(1, "dis " ~ distanceFormatted ~ '  dtk ' ~ trackFormatted);
        putLine(2, legInfo ~ " ete" ~ eteFormatted);
    },

    redrawPosition: func {
        var lat = getprop('/instrumentation/gps/indicated-latitude-deg') or 0;
        var lon = getprop('/instrumentation/gps/indicated-longitude-deg') or 0;
        var searchID = deviceProps.referenceSearchID.getValue() or '';
        var refID = deviceProps.referenceID.getValue() or '';
        var refBRG = deviceProps.referenceBRG.getValue() or 0;
        var refDST = deviceProps.referenceDist.getValue() or -1;
        var refMode = deviceProps.referenceMode.getValue() or '';
        var alt = getprop('/instrumentation/altimeter/indicated-altitude-ft') or 0;

        var formattedLat = '___.__' ~ sc.deg ~ '__' ~ smallStr('.___');
        var formattedLon = '____.__' ~ sc.deg ~ '__' ~ smallStr('.___');
        var formattedDistance = '__' ~ smallStr('.__') ~ '_';
        var formattedBearing = '___';
        var line2 = '____ ____ ___' ~ sc.deg ~ formattedDistance;
        var visibleID = '_____';

        if (refMode == 'wpt' and me.selectedField > 0)
            visibleID = searchID;
        else
            visibleID = refID;
        
        if (lat and lon) {
            formattedLat = formatLat(lat);
            formattedLon = formatLon(lon);
        }
        if (refDST >= 0)
            formattedDistance = formatDistanceShort(refDST);
        if (refBRG >= 0)
            formattedBearing = sprintf('%03.0f', refBRG);
        line2 = sc.fr ~ refMode ~ ' ' ~ sprintf('%-5s', visibleID) ~ ' ' ~
                    formattedBearing ~ sc.deg ~
                    formattedDistance;

        putLine(0, sprintf('alt %6s', formatAltitude(alt)));
        putLine(1, formattedLat ~ ' ' ~ formattedLon);
        putLine(2, line2);
    },
};
