var specialChars = {
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

var formatDistance = func (dist) {
    if (dist < 100) {
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
            page: 0,
        };
    },

    redraw: func {
    },

    start: func {
        modeLightProp.setValue('NAV');
        me.page = 0;
        me.redraw();
    },

    stop: func {
        modeLightProp.setValue('');
    },

    update: func (dt) {
        me.redraw();
    },

    redraw: func {
        var lat = getprop('/instrumentation/gps/indicated-latitude-deg') or 0;
        var lon = getprop('/instrumentation/gps/indicated-longitude-deg') or 0;
        var refID = getprop('/instrumentation/gps/wp/wp[1]/ID') or '----';
        var refBRG = getprop('/instrumentation/gps/wp/wp[1]/bearing-mag-deg');
        var refDST = getprop('/instrumentation/gps/wp/wp[1]/distance-nm');
        var alt = getprop('/instrumentation/altimeter/indicated-altitude-ft') or 0;

        var formattedLat = formatLat(lat);
        var formattedLon = formatLon(lon);
        var formattedDistance = formatDistance(refDST);
        
        putLine(0, sprintf('alt %5.0f' ~ specialChars.ft, alt));
        putLine(1, formattedLat ~ ' ' ~ formattedLon);
        putLine(2,
            specialChars.fr ~ 'apt ' ~ sprintf('%-5s', refID) ~ ' ' ~
            sprintf('%03.0f', refBRG) ~ specialChars.deg ~
            formattedDistance);
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
        putLine(0, ' GPS 155 Ver  3.06  ');
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
