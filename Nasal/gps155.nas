var version = '0.1beta';

var acdir = getprop('/sim/aircraft-dir');
var include = func (basename) {
    var path = acdir ~ '/Nasal/gps155/' ~ basename;
    printf("--- loading " ~ path ~ " ---");
    io.load_nasal(path, 'gps155');
}

var initialized = 0;

var initialize = func {
    if (initialized) return;
    initialized = 1;

    include('text.nas');
    include('screen.nas');
    include('input.nas');
    include('device.nas');
    include('pages/BasePage.nas');
    include('pages/DatabaseConfirmationPage.nas');
    include('pages/InitializationPage.nas');
    include('pages/NavPage.nas');
    include('pages/SatPage.nas');
    include('pages/WaypointConfirmPage.nas');
    include('pages/WaypointSelectPage.nas');

    initScreen();
    initInput();
    initDevice();
};

setlistener("sim/signals/fdm-initialized", initialize);
