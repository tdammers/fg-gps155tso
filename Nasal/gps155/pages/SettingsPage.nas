var SettingsPage = {
    new: func {
        var m = MultiPage.new(deviceProps.currentPage.set, 'SET');
        m.parents = [SettingsPage] ~ m.parents;
        return m;
    },

    SUBPAGE_SAT_STATUS: 0,
    SUBPAGE_NAV_UNITS: 1,
    SUBPAGE_NUM: 2,

    getNumPages: func { return 2; },

    start: func {
        call(MultiPage.start, [], me);
        modeLightProp.setValue('SET');
    },

    stop: func {
        call(MultiPage.stop, [], me);
        modeLightProp.setValue('');
    },

    setSelectableFields: func {
        var self = me;
        if (me.getCurrentPage() == SettingsPage.SUBPAGE_NAV_UNITS) {
            me.selectableFields = [
                { row: 0, col: 5,
                  changeValue: func(amount) {
                    cycleProp(deviceProps.settings.units.position,
                        ['dm', 'dms'],
                        amount);
                    self.redraw();
                  }
                },
                { row: 0, col: 13,
                  changeValue: func(amount) {
                    cycleProp(deviceProps.settings.units.altitude,
                        ['ft', 'm'],
                        amount);
                    self.redraw();
                  }
                },
                { row: 0, col: 15,
                  changeValue: func(amount) {
                    cycleProp(deviceProps.settings.units.vspeed,
                        ['fpm', 'mpm', 'mps'],
                        amount);
                    self.redraw();
                  }
                },
                { row: 1, col: 5,
                  changeValue: func(amount) {
                    cycleProp(deviceProps.settings.units.distance,
                        ['nm', 'km', 'mi'],
                        amount);
                    self.redraw();
                  }
                },
                { row: 1, col: 7,
                  changeValue: func(amount) {
                    cycleProp(deviceProps.settings.units.speed,
                        ['kt', 'kmh', 'mph'],
                        amount);
                    self.redraw();
                  }
                },
                { row: 1, col: 14,
                  changeValue: func(amount) {
                    cycleProp(deviceProps.settings.units.fuel,
                        ['gal', 'lt', 'lbs', 'kg', 'igal'],
                        amount);
                    self.redraw();
                  }
                },
                { row: 2, col: 5,
                  changeValue: func(amount) {
                    cycleProp(deviceProps.settings.units.pressure,
                        ['inhg', 'mbar'],
                        amount);
                    self.redraw();
                  }
                },
                { row: 2, col: 14,
                  changeValue: func(amount) {
                    cycleProp(deviceProps.settings.units.temperature,
                        ['degC', 'degF'],
                        amount);
                    self.redraw();
                  }
                },
            ];
        }
        else {
            me.selectableFields = [];
        }
    },

    redraw: func {
        if (me.getCurrentPage() == SettingsPage.SUBPAGE_NAV_UNITS) {
            me.redrawNavUnits();
        }
        elsif (me.getCurrentPage() == SettingsPage.SUBPAGE_SAT_STATUS) {
            me.redrawSatStatus();
        }
        else {
            clearScreen();
        }
    },

    redrawSatStatus: func {
        var status = deviceProps.receiver.status.getValue() or 0;
        putScreen(formatSatStatus(status, satellites));
    },

    redrawNavUnits: func {
        putLine(0,
            sprintf('posn %-3s alt %1s %3s',
                unitSymbol(deviceProps.settings.units.position.getValue()),
                unitSymbol(deviceProps.settings.units.altitude.getValue()),
                unitSymbol(deviceProps.settings.units.vspeed.getValue())));
        putLine(1,
            sprintf('nav  %1s %1s fuel %1s',
                unitSymbol(deviceProps.settings.units.distance.getValue()),
                unitSymbol(deviceProps.settings.units.speed.getValue()),
                unitSymbol(deviceProps.settings.units.fuel.getValue())));
        putLine(2,
            sprintf('pres %1s   temp %1s',
                unitSymbol(deviceProps.settings.units.pressure.getValue()),
                unitSymbol(deviceProps.settings.units.temperature.getValue())));
    },

    handleInput: func (what, amount) {
        if (call(MultiPage.handleInput, [what, amount], me)) {
            return 1;
        }
        else {
            return 0;
        }
    },
};

