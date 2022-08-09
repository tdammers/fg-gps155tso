#!/bin/bash

AIRCRAFTDIR=$1
LOCALDIR=$(dirname $0)

mkdir -p "$AIRCRAFTDIR/Models/Instruments"
mkdir -p "$AIRCRAFTDIR/Models/Effects"
mkdir -p "$AIRCRAFTDIR/Nasal"
mkdir -p "$AIRCRAFTDIR/Nasal/gps155"
mkdir -p "$AIRCRAFTDIR/Fonts"

cp "$LOCALDIR/Models/Instruments/gps155.xml" "$AIRCRAFTDIR/Models/Instruments/"
cp "$LOCALDIR/Models/Effects/gps155.eff" "$AIRCRAFTDIR/Models/Effects/"
cp "$LOCALDIR/Models/Instruments/gps155.ac" "$AIRCRAFTDIR/Models/Instruments/"
cp "$LOCALDIR/Models/Instruments/gps155-screen.png" "$AIRCRAFTDIR/Models/Instruments/"
cp "$LOCALDIR/Models/Instruments/GPS155.png" "$AIRCRAFTDIR/Models/Instruments/"
cp "$LOCALDIR/Models/Instruments/GPS155-lightmap.png" "$AIRCRAFTDIR/Models/Instruments/"
cp "$LOCALDIR/Nasal/gps155.nas" "$AIRCRAFTDIR/Nasal/"
cp "$LOCALDIR/Fonts/gps155.txf" "$AIRCRAFTDIR/Fonts/"
