var refModes = ['apt', 'vor', 'ndb', 'int', 'wpt'];

var NavPage = {
    new: func {
        return {
            parents: [NavPage, BasePage],
            selectedField: -1,
            selectableFields: [],
        };
    },

    currentSubpage: 1,

    start: func {
        modeLightProp.setValue('NAV');
        me.setSelectableFields();
        me.redraw();
    },

    stop: func {
        modeLightProp.setValue('');
    },

    setSelectableFields: func {
        var self = me;
        if (NavPage.currentSubpage == 1) {
            me.selectableFields = [
                { row: 0, col:  0, changeValue: func {} },
                { row: 2, col:  1,
                    changeValue: func (amount) {
                        var mode = deviceProps.referenceMode.getValue();
                        var refModeIdx = vecindex(refModes, mode);
                        if (refModeIdx == nil) {
                            refModeIdx = 0;
                        }
                        else {
                            refModeIdx = math.mod(refModeIdx + amount, size(refModes));
                            if (refModeIdx < 0) {
                                refModeIdx += size(refModes);
                            }
                        }
                        deviceProps.referenceMode.setValue(refModes[refModeIdx]);
                        self.redraw();
                    }
                },
            ];
        }
        else {
            me.selectableFields = [];
        }
    },

    handleInput: func (what, amount=0) {
        if (call(BasePage.handleInput, [what, amount], me)) {
            return 1;
        }
        if (what == 'NAV') {
            NavPage.currentSubpage = (NavPage.currentSubpage + 1) & 3;
            me.setSelectableFields();
            me.redraw();
            return 1;
        }
        elsif (what == 'data-outer') {
            if (me.selectedField == -1) {
                if (amount > 0) {
                    NavPage.currentSubpage = (NavPage.currentSubpage + amount) & 3;
                }
                else {
                    NavPage.currentSubpage = math.max(0, NavPage.currentSubpage + amount);
                }
                me.setSelectableFields();
                me.redraw();
                return 1;
            }
        }
        else {
            return 0;
        }
    },

    update: func (dt) {
        me.redraw();
    },

    redraw: func {
        if (NavPage.currentSubpage == 0)
            me.redrawCDI();
        elsif (NavPage.currentSubpage == 1)
            me.redrawPosition();
        elsif (NavPage.currentSubpage == 2)
            me.redrawNavMenu(0);
        elsif (NavPage.currentSubpage == 3)
            me.redrawNavMenu(1);
    },

    redrawNavMenu: func (n) {
        putLine(0, "NAV MENU " ~ (n+1));
        putLine(1, "--------------------");
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
        var gsFormatted = '___';
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
            gsFormatted = sprintf('%3i', gs);
            distanceFormatted = formatDistanceLong(tgtDST);
            trackFormatted = sprintf('%03i', legTRK);
            if (mode == 'dto') {
                legInfo = sprintf('go to:%-5s', substr(tgtID, 0, 5));
            }
            elsif (mode == 'leg') {
                legInfo = sprintf('%-5s' ~ sc.arrowR ~ '%-5s',
                                substr(fromID, 0, 5), substr(tgtID, 0, 5));
            }
            if (ete != '')
                eteFormatted = substr(ete, 0, 5);
        }

        putLine(0, cdiFormatted ~ " gs :" ~ gsFormatted ~ sc.kt);
        putLine(1, "dis " ~ distanceFormatted ~ '  dtk ' ~ trackFormatted ~ sc.deg);
        putLine(2, legInfo ~ " ete" ~ eteFormatted);
    },

    redrawPosition: func {
        var lat = getprop('/instrumentation/gps/indicated-latitude-deg') or 0;
        var lon = getprop('/instrumentation/gps/indicated-longitude-deg') or 0;
        var refID = deviceProps.referenceID.getValue() or '';
        var refBRG = deviceProps.referenceBRG.getValue() or 0;
        var refDST = deviceProps.referenceDist.getValue() or -1;
        var refMode = deviceProps.referenceMode.getValue() or '';
        var alt = getprop('/instrumentation/altimeter/indicated-altitude-ft') or 0;

        var formattedLat = '___.__' ~ sc.deg ~ '__' ~ smallStr('.___');
        var formattedLon = '____.__' ~ sc.deg ~ '__' ~ smallStr('.___');
        var formattedDistance = '__' ~ smallStr('.__') ~ sc.nm;
        var formattedBearing = '___';
        var line2 = '____ ____ ___' ~ sc.deg ~ formattedDistance;
        
        if (lat and lon) {
            formattedLat = formatLat(lat);
            formattedLon = formatLon(lon);
        }
        if (refDST >= 0)
            formattedDistance = formatDistance(refDST);
        if (refBRG >= 0)
            formattedBearing = sprintf('%03.0f', refBRG);
        line2 = sc.fr ~ refMode ~ ' ' ~ sprintf('%-5s', refID) ~ ' ' ~
                    formattedBearing ~ sc.deg ~
                    formattedDistance;

        putLine(0, sprintf('alt %5.0f' ~ sc.ft, alt));
        putLine(1, formattedLat ~ ' ' ~ formattedLon);
        putLine(2, line2);
    },
};
