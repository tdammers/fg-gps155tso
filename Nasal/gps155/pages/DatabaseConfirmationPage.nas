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
            loadPage(SatPage.new());
            return 1;
        }
        else {
            return 1;
        }
    },
};

