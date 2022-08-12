var sc = {
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
              sc.deg ~
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
              sc.deg ~
              sprintf('%02i', minutes) ~
              smallStr(sprintf('.%03i\'', minutesFrac));
};

formatWaypointInfo = func (waypoint, indexStr = '', promptStr = '') {
    var extraInfo0 = '';
    var extraInfo1 = '';
    var extraInfo2 = waypoint.name;

    var line0 = '';
    var line1 = '';
    var line2 = '';

    var type = '';
    if (ghosttype(waypoint) == 'airport' or ghosttype(waypoint) == 'FGAirport') {
        var apinfo = airportinfo(waypoint.id);
        extraInfo0 = formatAltitude(waypoint.elevation);
        var twrStation = nil;
        var ctfStation = nil;
        var uniStation = nil;
        foreach (var commStation; waypoint.comms()) {
            # debug.dump(commStation.name ~ ' ' ~ commStation.frequency);
            if (twrStation == nil and
                (commStation.name == 'TWR' or
                    string.imatch(commStation.name, '* TWR') or
                    string.imatch(commStation.name, '*Tower*'))) {
                twrStation = commStation;
            }
            elsif (ctfStation == nil and
                (commStation.name == 'RADIO' or
                    string.imatch(commStation.name, 'CTAF*') or
                    string.imatch(commStation.name, '* RADIO'))) {
                ctfStation = commStation;
            }
            elsif (uniStation == nil and
                (commStation.name == 'UNICOM') or
                 string.imatch(commStation.name, '* UNICOM')) {
                uniStation = commStation;
            }
        }
        if (twrStation != nil)
            extraInfo1 = 'twr' ~ format8_33khz(twrStation.frequency);
        elsif (uniStation != nil)
            extraInfo1 = 'uni' ~ format8_33khz(uniStation.frequency);
        elsif (ctfStation != nil)
            extraInfo1 = 'ctf' ~ format8_33khz(ctfStation.frequency);
        if (promptStr == '') {
            var longestLength = 0;
            var bestRunway = nil;
            foreach (var idx; keys(apinfo.runways)) {
                var runway = apinfo.runways[idx];
                if (runway.length > longestLength) {
                    bestRunway = runway;
                }
            }
            if (bestRunway != nil) {
                if (bestRunway.reciprocal == nil) {
                    extraInfo2 = 
                        sprintf('rnwy %-3s      %6s',
                            bestRunway.id,
                            formatRunwayLength(bestRunway.length, 'm'));
                }
                else {
                    if (bestRunway.heading > bestRunway.reciprocal.heading)
                        bestRunway = bestRunway.reciprocal;
                    extraInfo2 = 
                        sprintf('rnwy %-3s/%-3s %5s',
                            bestRunway.id,
                            bestRunway.reciprocal.id,
                            formatRunwayLength(bestRunway.length, 'm'));
                }
            }
        }
    }
    elsif (waypoint.type == 'VOR') {
        extraInfo0 = format25khz(waypoint.frequency / 100);
    }
    elsif (waypoint.type == 'NDB') {
        extraInfo0 = format1khz(waypoint.frequency / 100);
    }
    var db = getWaypointDistanceAndBearing(waypoint);
    if (indexStr == '')
        line0 =
            sprintf("%-3s %-5s %-11s",
                getWaypointType(waypoint, 1),
                substr(waypoint.id, 0, 5),
                extraInfo0);
    else
        line0 =
            sprintf("%-3s %-3s %-5s %-7s",
                indexStr,
                getWaypointType(waypoint, 1),
                substr(waypoint.id, 0, 5),
                extraInfo0);
    line1 =
        sprintf(' %4s%5s %-9s',
            formatHeading(db.bearing),
            formatDistanceShort(db.distance),
            extraInfo1);
    if (promptStr == '')
        line2 =
            sprintf(' %-20s',
                shorten(extraInfo2, 20));
    else
        line2 =
            sprintf(' %-15s %3s',
                shorten(extraInfo2, 15),
                promptStr);
    return [line0, line1, line2];
};

formatAltitude = func (alt, inUnits='ft') {
    var inFactor = 1;
    if (inUnits = 'm')
        inFactor = M2FT;
    return sprintf('%5i' ~ sc.ft, alt * inFactor);
};

formatRunwayLength = func (len, inUnits='ft') {
    var inFactor = 1;
    if (inUnits = 'm')
        inFactor = M2FT;
    return sprintf('%5i' ~ sc.ft, math.floor(len * inFactor));
};

formatHeading = func (hdg) {
    hdg = math.round(geo.normdeg(hdg));
    if (hdg < 1)
        hdg += 360;
    if (hdg >= 361)
        hdg -= 360;
    return sprintf('%03i' ~ sc.deg, hdg);
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
        return sprintf('%3i', i) ~ smallStr(sprintf('.%02i', f)) ~ sc.nm;
    }
    else {
        return sprintf('%6i', dist) ~ sc.nm;
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
        return sprintf('%2i', i) ~ smallStr(sprintf('.%02i', f)) ~ sc.nm;
    }
    elsif (dist < 1000) {
        var i = math.floor(dist);
        var f = math.floor((dist - i) * 10);
        return sprintf('%3i', i) ~ smallStr(sprintf('.%01i', f)) ~ sc.nm;
    }
    else {
        return sprintf('%5i', dist) ~ sc.nm;
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
        var f = math.floor((dist - i) * 10);
        return sprintf('%3i', i) ~ smallStr(sprintf('.%01i', f)) ~ sc.nm;
    }
    else {
        return sprintf('%4i', math.round(dist)) ~ sc.nm;
    }
};

var format25khz = func (freq) {
    var i = math.floor(freq);
    var f = math.floor((freq - i) * 100 + 0.05);
    return sprintf('%3i', i) ~ smallStr(sprintf('.%02i', f));
};

var format8_33khz = func (freq) {
    var i = math.floor(freq - 100);
    var f = math.round((freq - 100 - i) * 1000);
    if (math.mod(math.round(freq * 1000), 25) == 0)
        return ' ' ~ format25khz(freq);
    else
        return smallStr('`1') ~ sprintf('%02i', i) ~ smallStr(sprintf('.%03i', f));
};

var format1khz = func (freq) {
    var i = math.floor(freq);
    var f = math.floor((freq - i) * 10);
    return sprintf('%4i', i) ~ smallStr(sprintf('.%01i', f));
};

var shorten = func (str, maxlen) {
    if (utf8.size(str) <= maxlen)
        return str;

    var half = math.ceil((maxlen - 2) / 2);
    return utf8.substr(str, 0, half) ~
           '..' ~
           utf8.substr(str, utf8.size(str) - (maxlen - 2 - half));
};

var scrollAlphabet = [
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "_", "-" ];

var scrollChar = func (str, index, amount) {
    if (utf8.size(str) < index) return str;
    var charNum = vecindex(scrollAlphabet, string.uc(utf8.substr(str, index, 1)));
    if (charNum == nil)
        charNum = 0;
    else
        charNum = math.mod(charNum + amount, size(scrollAlphabet));
    str = utf8.substr(str, 0, index) ~ scrollAlphabet[charNum];
    return str;
};
