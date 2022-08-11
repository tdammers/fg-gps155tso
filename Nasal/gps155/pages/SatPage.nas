var SatPage = {
    new: func {
        return {
            parents: [SatPage, BasePage],
            satellites: [],
            timeLeft: 0,
        };
    },

    start: func {
        call(BasePage.start, [], me);
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

        putLine(0, 'Acquiring   epe____' ~ sc.ft);
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
