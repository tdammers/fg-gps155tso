var BasePage = {
    start: func {
        me.selectableFields = [];
        me.selectedField = -1;
    },
    stop: func {
        unsetCursor();
    },
    update: func (dt) {},

    handleInput: func (what, amount=0) {
        if (what == 'CRSR') {
            if (me.selectedField >= 0) {
                me.selectedField = -1;
                unsetCursor();
                return 1;
            }
            elsif (size(me.selectableFields) > 0) {
                me.selectedField = 0;
                var field = me.selectableFields[me.selectedField];
                setCursor(field.row, field.col);
                return 1;
            }
        }
        elsif (what == 'data-inner') {
            if (me.selectedField >= 0) {
                var field = me.selectableFields[me.selectedField];
                field.changeValue(amount);
                return 1;
            }
        }
        elsif (what == 'data-outer') {
            if (me.selectedField >= 0 and size(me.selectableFields) > 0) {
                me.selectedField += amount;
                while (me.selectedField < 0) {
                    me.selectedField += size(me.selectableFields);
                }
                while (me.selectedField >= size(me.selectableFields)) {
                    me.selectedField -= size(me.selectableFields);
                }
                var field = me.selectableFields[me.selectedField];
                setCursor(field.row, field.col);
                return 1;
            }
        }
        else {
            return 0;
        }
    },
};
