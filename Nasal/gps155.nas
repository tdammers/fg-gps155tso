var version = '0.1beta';
var specialChars = {
    'updown': utf8.chstr(0x12),
    'cursor': utf8.chstr(0x16),
    'arrowL': utf8.chstr(0x1b),
    'arrowR': utf8.chstr(0x1a),
    'arrowUp': utf8.chstr(0x18),
    'arrowDn': utf8.chstr(0x19),

    'ft': utf8.chstr(0x80),
    'mt': utf8.chstr(0x81),
    'nm': utf8.chstr(0x82),
    'mi': utf8.chstr(0x83),
    'km': utf8.chstr(0x84),
    'kt': utf8.chstr(0x85),
    'mh': utf8.chstr(0x86),
    'kh': utf8.chstr(0x87),
    'gl': utf8.chstr(0x88),
    'kg': utf8.chstr(0x89),
    'lt': utf8.chstr(0x8a),
    'ig': utf8.chstr(0x8b),
    'lb': utf8.chstr(0x8c),
    'hg': utf8.chstr(0x8d),
    'mb': utf8.chstr(0x8e),

    'fr': utf8.chstr(0x90),
    'if': utf8.chstr(0x91),
    'ff': utf8.chstr(0x92),
    'mp': utf8.chstr(0x93),

    'copy': utf8.chstr(0xb9),
    'deg': utf8.chstr(0xc0),
    'degC': utf8.chstr(0xc4),
    'degF': utf8.chstr(0xc5),
    'dot': utf8.chstr(0xc7),
};

var currentNavPage = 1;

# Convert a regular numeric string into a small-size string, as per the GPS155
# font.
# The following special characters and transformations are applied:
# - A digit or underscore following a dot character is converted to the
#   corresponding small-size character with integrated leading dot
#   (0xD0 series)
# - A digit or underscore followed by a tick character is converted to the
#   corresponding small-size character with integrated trailing tick
#   (0xE0 series)
# - A digit or underscore following a backtick character is converted to the
#   corresponding right-aligned small-size character (0xA0 series), and the
#   backtick removed
# - A space following a backtick character is converted to a plain space, and
#   the backtick removed
# - A digit or underscore outside of the above situations is converted to the
#   corresponding regular small-size character (0xF0 series)
# - All other characters are left untouched
var smallStr = func (str) {
    var accum = '';
    var rem = isstr(str) ? str : '';
    var c = '';
    var d = '';
    var series = 0xf0;
    var offset = 0x00;
    var dot = utf8.strc('.', 0);
    var tick = utf8.strc('\'', 0);
    var backtick = utf8.strc('`', 0);
    var underscore = utf8.strc('_', 0);
    var space = utf8.strc(' ', 0);
    while (size(rem) > 0) {
        c = (size(rem) >= 1) ? rem[0] : 0;
        d = (size(rem) >= 2) ? rem[1] : 0;

        if (c == dot and string.isdigit(d)) {
            series = 0xd0;
            offset = d & 0x0f;
            rem = substr(rem, 2);
            accum = accum ~ utf8.chstr(series + offset);
        }
        elsif (c == dot and d == underscore) {
            series = 0xd0;
            offset = 0x0a;
            rem = substr(rem, 2);
            accum = accum ~ utf8.chstr(series + offset);
        }
        elsif (c == backtick and string.isdigit(d)) {
            series = 0xa0;
            offset = d & 0x0f;
            rem = substr(rem, 2);
            accum = accum ~ utf8.chstr(series + offset);
        }
        elsif (c == backtick and d == underscore) {
            series = 0xa0;
            offset = 0x0a;
            rem = substr(rem, 2);
            accum = accum ~ utf8.chstr(series + offset);
        }
        elsif (c == backtick and d == space) {
            rem = substr(rem, 2);
            accum = accum ~ ' ';
        }
        elsif (d == tick and string.isdigit(c)) {
            series = 0xe0;
            offset = c & 0x0f;
            rem = substr(rem, 2);
            accum = accum ~ utf8.chstr(series + offset);
        }
        elsif (d == tick and c == underscore) {
            series = 0xe0;
            offset = 0x0a;
            rem = substr(rem, 2);
            accum = accum ~ utf8.chstr(series + offset);
        }
        elsif (string.isdigit(c)) {
            series = 0xf0;
            offset = c & 0x0f;
            rem = substr(rem, 1);
            accum = accum ~ utf8.chstr(series + offset);
        }
        elsif (c == underscore) {
            series = 0xf0;
            offset = 0x0a;
            rem = substr(rem, 1);
            accum = accum ~ utf8.chstr(series + offset);
        }
        else {
            accum = accum ~ utf8.substr(rem, 0, 1);
            rem = substr(rem, 1);
        }
    }
    return accum;
};

var formatLat = func (lat) {
    var result = '';
    if (lat < 0) {
        result = 'S';
        lat = -lat;
    }
    else {
        result = 'N';
    }
    var degrees = math.floor(lat);
    var minutesF = (lat - degrees) * 60;
    var minutes = math.floor(minutesF);
    var minutesFrac = math.floor((minutesF - minutes) * 1000);

    result ~= sprintf('%02i', degrees) ~
              specialChars.deg ~
              sprintf('%02i', minutes) ~
              smallStr(sprintf('.%03i\'', minutesFrac));
};

var formatLon = func (lat) {
    var result = '';
    if (lat < 0) {
        result = 'W';
        lat = -lat;
    }
    else {
        result = 'E';
    }
    var degrees = math.floor(lat);
    var minutesF = (lat - degrees) * 60;
    var minutes = math.floor(minutesF);
    var minutesFrac = math.floor((minutesF - minutes) * 1000);

    result ~= sprintf('%03i', degrees) ~
              specialChars.deg ~
              sprintf('%02i', minutes) ~
              smallStr(sprintf('.%03i\'', minutesFrac));
};

var formatDistanceLong = func (dist) {
    if (dist > 999999) {
        return '++++++';
    }
    elsif (dist < 0) {
        return '------';
    }
    elsif (dist < 1000) {
        var i = math.floor(dist);
        var f = math.floor((dist - i) * 100);
        return sprintf('%3i', i) ~ smallStr(sprintf('.%02i', f)) ~ specialChars.nm;
    }
    else {
        return sprintf('%6i', dist) ~ specialChars.nm;
    }
};

var formatDistance = func (dist) {
    if (dist > 99999) {
        return '+++++';
    }
    elsif (dist < 0) {
        return '-----';
    }
    elsif (dist < 100) {
        var i = math.floor(dist);
        var f = math.floor((dist - i) * 100);
        return sprintf('%2i', i) ~ smallStr(sprintf('.%02i', f)) ~ specialChars.nm;
    }
    elsif (dist < 1000) {
        var i = math.floor(dist);
        var f = math.floor((dist - i) * 10);
        return sprintf('%3i', i) ~ smallStr(sprintf('.%01i', f)) ~ specialChars.nm;
    }
    else {
        return sprintf('%5i', dist) ~ specialChars.nm;
    }
};

var formatDistanceShort = func (dist) {
    if (dist > 9999) {
        return '++++';
    }
    elsif (dist < 0) {
        return '----';
    }
    if (dist < 100) {
        var i = math.floor(dist);
        var f = math.floor((dist - i) * 100);
        return sprintf('%2i', i) ~ smallStr(sprintf('.%01i', f)) ~ specialChars.nm;
    }
    else {
        return sprintf('%4i', dist) ~ specialChars.nm;
    }
};

var initialized = 0;
var gpsCanvas = nil;
var gpsScreen = nil;

var charElems = [];
var displayLineProps = [];
var powered = 0;
var modeLightProp = nil;
var msgLightProp = nil;
var modeProp = nil;
var msgProp = nil;

var dataKnobValues = { inner: 0, outer: 0 };
var dataKnobProps = {};

var putLine = func (row, str) {
    displayLineProps[row].setValue(str);
};

var clearScreen = func () {
    displayLineProps[0].setValue('');
    displayLineProps[1].setValue('');
    displayLineProps[2].setValue('');
};

var currentPage = nil;

var unloadPage = func {
    if (currentPage == nil) return;
    currentPage.stop();
    currentPage = nil;
};

var loadPage = func (page) {
    unloadPage();
    currentPage = page;
    if (currentPage == nil) {
        clearScreen();
    }
    else {
        currentPage.start();
    }
};

var update = func (dt) {
    if (!powered) return;
    if (currentPage != nil) {
        currentPage.update(dt);
    }
};

var handleInput = func (what, amount=0) {
    if (!powered) return;
    if (currentPage != nil) {
        if (currentPage.handleInput(what, amount)) {
            return;
        }
    }
    # Page hasn't handled the key
};

var updateTimer = maketimer(0.5, func { update(0.5); });
updateTimer.simulatedTime = 1;

var BasePage = {
    start: func {},
    stop: func {},
    update: func (dt) {},
    handleInput: func (what, amount=0) {},
};

var NavPage = {
    new: func {
        return {
            parents: [NavPage, BasePage],
        };
    },

    start: func {
        modeLightProp.setValue('NAV');
        me.redraw();
    },

    stop: func {
        modeLightProp.setValue('');
    },

    handleInput: func (what, amount=0) {
        if (what == 'NAV') {
            currentNavPage = (currentNavPage + 1) & 3;
            me.redraw();
            return 1;
        }
        elsif (what == 'data-outer') {
            if (amount > 0) {
                currentNavPage = (currentNavPage + amount) & 3;
            }
            else {
                currentNavPage = math.max(0, currentNavPage + amount);
            }
            me.redraw();
            return 1;
        }
        else {
            return 0;
        }
    },

    update: func (dt) {
        me.redraw();
    },

    redraw: func {
        if (currentNavPage == 0)
            me.redrawCDI();
        elsif (currentNavPage == 1)
            me.redrawPosition();
        elsif (currentNavPage == 2)
            me.redrawNavMenu(0);
        elsif (currentNavPage == 3)
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
        var distanceFormatted = "___" ~ smallStr('.__') ~ specialChars.nm;
        var trackFormatted = "___";
        var legInfo = "_____" ~ specialChars.arrowR ~ "_____";
        var eteFormatted = "__:__";

        if (tgtID != '' or mode == 'obs') {
            var needlePos = 5 + math.min(5, math.max(-5, math.round(cte / 2)));
            cdiFormatted = '';
            var i = 0;
            for (i = 0; i < needlePos; i += 1)
                cdiFormatted ~= specialChars.dot;
            if (fromFlag)
                cdiFormatted ~= specialChars.arrowDn;
            else
                cdiFormatted ~= specialChars.arrowUp;
            for (i = needlePos + 1; i < 11; i += 1)
                cdiFormatted ~= specialChars.dot;
            gsFormatted = sprintf('%3i', gs);
            distanceFormatted = formatDistanceLong(tgtDST);
            trackFormatted = sprintf('%03i', legTRK);
            if (mode == 'dto') {
                legInfo = sprintf('go to:%-5s', substr(tgtID, 0, 5));
            }
            elsif (mode == 'leg') {
                legInfo = sprintf('%-5s' ~ specialChars.arrowR ~ '%-5s',
                                substr(fromID, 0, 5), substr(tgtID, 0, 5));
            }
            if (ete != '')
                eteFormatted = substr(ete, 0, 5);
        }

        putLine(0, cdiFormatted ~ " gs :" ~ gsFormatted ~ specialChars.kt);
        putLine(1, "dis " ~ distanceFormatted ~ '  dtk ' ~ trackFormatted ~ specialChars.deg);
        putLine(2, legInfo ~ " ete" ~ eteFormatted);
    },

    redrawPosition: func {
        var lat = getprop('/instrumentation/gps/indicated-latitude-deg') or 0;
        var lon = getprop('/instrumentation/gps/indicated-longitude-deg') or 0;
        var refID = getprop('/instrumentation/gps/wp/wp[1]/ID') or '';
        var refBRG = getprop('/instrumentation/gps/wp/wp[1]/bearing-mag-deg');
        var refDST = getprop('/instrumentation/gps/wp/wp[1]/distance-nm');
        var alt = getprop('/instrumentation/altimeter/indicated-altitude-ft') or 0;

        var formattedLat = '___.__°__' ~ smallStr('.___');
        var formattedLon = '____.__°__' ~ smallStr('.___');
        var formattedDistance = '__' ~ smallStr('.__') ~ specialChars.nm;
        var line2 = '____ ____ ___' ~ specialChars.deg ~ formattedDistance;
        
        if (refID != '') {
            formattedLat = formatLat(lat);
            formattedLon = formatLon(lon);
            formattedDistance = formatDistance(refDST);
            line2 = specialChars.fr ~ 'apt ' ~ sprintf('%-5s', refID) ~ ' ' ~
                        sprintf('%03.0f', refBRG) ~ specialChars.deg ~
                        formattedDistance;
        }

        putLine(0, sprintf('alt %5.0f' ~ specialChars.ft, alt));
        putLine(1, formattedLat ~ ' ' ~ formattedLon);
        putLine(2, line2);
    },
};

var SatAcquirePage = {
    new: func {
        return {
            parents: [SatAcquirePage, BasePage],
            satellites: [],
            timeLeft: 0,
        };
    },

    start: func {
        me.satellites = [];
        var satsUsed = {};
        var n = 0;
        for (var i = 0; i < 7; i += 1) {
            n = math.floor(rand() * 32) + 1;
            while (contains(satsUsed, n)) {
                printf("%i already in list", n);
                n = math.floor(rand() * 32) + 1;
            }
            printf("new sat: %i", n);
            satsUsed[n] = 1;
            append(me.satellites, {
                ident: n,
                sgl: rand(),
            });
        }
        # DEBUG
        me.timeLeft = 5; # (rand() * 300) + 120;
        me.redraw();
    },

    redraw: func {
        var identLine = 'sat ';
        var sglLine = 'sgl ';
        foreach (var sat; me.satellites) {
            identLine ~= smallStr(sprintf('`%2i', sat.ident));
            sglLine ~= smallStr(sprintf('`%2i', math.round(sat.sgl * 10)));
        }

        putLine(0, 'Acquiring   epe____' ~ specialChars.ft);
        putLine(1, identLine);
        putLine(2, sglLine);
    },

    handleInput: func (what, amount=0) {
        return 1;
    },

    update: func (dt) {
        foreach (var sat; me.satellites) {
            sat.sgl += (rand() - 0.5) * dt * 0.1;
            sat.sgl = math.max(0, math.min(1, sat.sgl));
        }

        me.timeLeft -= dt;

        if (me.timeLeft <= 0) {
            currentNavPage = 1;
            loadPage(NavPage.new());
        }
        else {
            me.redraw();
        }
    },

};

var DatabaseConfirmationPage = {
    new: func {
        return {
            parents: [DatabaseConfirmationPage, BasePage],
        };
    },

    start: func {
        putLine(0, '    WORLD IFR SUA   ');
        putLine(1, 'eff 01-jan-70 (7001)');
        putLine(2, 'exp 28-jan-70    ok?');
    },

    handleInput: func (what, amount=0) {
        if (what == 'ENT') {
            loadPage(SatAcquirePage.new());
            return 1;
        }
        else {
            return 1;
        }
    },
};

var CharsetTestPage = {
    new: func {
        return {
            parents: [CharsetTestPage, BasePage],
            selectedCodepoint: 0,
        };
    },

    redraw: func {
        putLine(0, 'Character/Font Test');
        putLine(1, sprintf('0x%02x %3s [%1s]',
            me.selectedCodepoint,
            smallStr(sprintf('`%3i', me.selectedCodepoint)),
            utf8.chstr(me.selectedCodepoint)));
        putLine(2, '');
    },

    start: func {
        me.redraw();
    },

    handleInput: func (what, amount=0) {
        if (what == 'data-inner') {
            me.selectedCodepoint =
                (me.selectedCodepoint + amount) & 0xff;
            me.redraw();
            return 1;
        }
        else {
            return 0;
        }
    },
};

var InitializationPage = {
    new: func {
        return {
            parents: [InitializationPage, BasePage],
            timeLeft: 10.0,
        };
    },

    start: func {
        putLine(0, sprintf(' GPS 155 Ver %s', version));
        putLine(1, specialChars.copy ~ "1994-95 GARMIN Corp");
        putLine(2, 'Performing self test');
        me.timeLeft = 10.0;
    },

    update: func (dt) {
        me.timeLeft -= dt;
        if (me.timeLeft <= 0.0) {
            loadPage(DatabaseConfirmationPage.new());
        }
    },

    handleInput: func (what, amount=0) {
        return 1;
    },
};

var initialize = func {
    if (initialized) return;
    initialized = 1;

    gpsCanvas = canvas.new({
        "name": "GPS155",
        "size": [1024, 128],
        "view": [256, 32],
        "mipmapping": 1
    });
    gpsCanvas.addPlacement({"texture": "gps155-screen.png"});
    gpsScreen = gpsCanvas.createGroup();
    for (var y = 0; y < 3; y += 1) {
        append(charElems, []);
        for (var x = 0; x < 20; x += 1) {
            append(charElems[y],
                gpsScreen.createChild('text')
                         .setText('?')
                         .setFont('gps155.txf')
                         .setColor(0, 1, 0)
                         .setTranslation(59 + x * 7, 9 + y * 10)
                         .setFontSize(7, 1));
        }
    }
    for (var l = 0; l < 3; l += 1) {
        (func (y) {
            var prop = props.globals.getNode('/instrumentation/gps155/display/line[' ~ y ~ ']', 1);
            prop.setValue('');
            append(displayLineProps, prop);
            setlistener(prop, func (node) {
                var txt = node.getValue();
                for (var x = 0; x < 20; x += 1) {
                    charElems[y][x].setText(
                        utf8.substr(txt, x, 1));
                }
            }, 1, 0);
        })(l);
    }
    foreach (var which; ['inner', 'outer']) {
        (func (which) {
            dataKnobProps[which] = props.globals.getNode('controls/gps155/data-' ~ which, 1);
            dataKnobProps[which].setValue(dataKnobValues[which]);
            setlistener(dataKnobProps[which], func (node) {
                var val = node.getValue();
                var dist = val - dataKnobValues[which];
                if (dist > 500) {
                    dist -= 1000;
                }
                elsif (dist < -500) {
                    dist += 1000;
                }
                dataKnobValues[which] = val;
                handleInput('data-' ~ which, dist);
            }, 1, 0);
        })(which);
    }
    modeLightProp = props.globals.getNode('/instrumentation/gps155/lights/mode', 1);
    msgLightProp = props.globals.getNode('/instrumentation/gps155/lights/msg', 1);
    setlistener('controls/gps155/key', func (node) {
        var which = node.getValue();
        if (which != '') {
            handleInput(which);
        }
    }, 1, 0);
    setlistener('controls/gps155/power', func (node) {
        if (node.getBoolValue()) {
            powered = 1;
            loadPage(InitializationPage.new());
            updateTimer.start();
        }
        else {
            powered = 0;
            updateTimer.stop();
            loadPage(nil);
        }
    }, 1, 0);
};

setlistener("sim/signals/fdm-initialized", initialize);
