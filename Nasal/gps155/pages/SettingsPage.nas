var SettingsPage = {
    new: func () {
        return {
            parents: [SettingsPage, BasePage],
        };
    },

    currentSubpage: 0,

    SUBPAGE_SAT_STATUS: 0,
    SUBPAGE_NAV_UNITS: 1,
    SUBPAGE_NUM: 2,

    start: func {
        call(BasePage.start, [], me);
        modeLightProp.setValue('SET');
        me.setSelectableFields();
        me.redraw();
    },

    setSelectableFields: func {
        var self = me;
        if (SettingsPage.currentSubpage == SettingsPage.SUBPAGE_NAV_UNITS) {
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
        if (SettingsPage.currentSubpage == SettingsPage.SUBPAGE_NAV_UNITS) {
            me.redrawNavUnits();
        }
        elsif (SettingsPage.currentSubpage == SettingsPage.SUBPAGE_SAT_STATUS) {
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
        if (call(BasePage.handleInput, [what, amount], me)) {
            return 1;
        }
        elsif (what == 'SET') {
            SettingsPage.currentSubpage =
                math.mod(SettingsPage.currentSubpage + 1, SettingsPage.SUBPAGE_NUM);
            me.selectedField = -1;
            unsetCursor();
            me.redraw();
            return 1;
        }
        elsif (what == 'data-outer') {
            SettingsPage.currentSubpage =
                math.mod(SettingsPage.currentSubpage + amount, SettingsPage.SUBPAGE_NUM);
            me.selectedField = -1;
            unsetCursor();
            me.redraw();
            return 1;
        }
        else {
            return 0;
        }
    },
};

