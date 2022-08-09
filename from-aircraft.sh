#!/bin/bash

AIRCRAFTDIR=$1
LOCALDIR=$(dirname $0)

mkdir -p "$LOCALDIR/Models/Instruments"
mkdir -p "$LOCALDIR/Models/Effects"
mkdir -p "$LOCALDIR/Nasal"
mkdir -p "$LOCALDIR/Nasal/gps155"
mkdir -p "$LOCALDIR/Fonts"

cp "$AIRCRAFTDIR/Models/Instruments/gps155.xml" "$LOCALDIR/Models/Instruments/"
cp "$AIRCRAFTDIR/Models/Effects/gps155.eff" "$LOCALDIR/Models/Effects/"
cp "$AIRCRAFTDIR/Models/Instruments/gps155.ac" "$LOCALDIR/Models/Instruments/"
cp "$AIRCRAFTDIR/Models/Instruments/gps155-screen.png" "$LOCALDIR/Models/Instruments/"
cp "$AIRCRAFTDIR/Models/Instruments/GPS155.png" "$LOCALDIR/Models/Instruments/"
cp "$AIRCRAFTDIR/Models/Instruments/GPS155-lightmap.png" "$LOCALDIR/Models/Instruments/"
cp "$AIRCRAFTDIR/Nasal/gps155.nas" "$LOCALDIR/Nasal/"
cp "$AIRCRAFTDIR/Fonts/gps155.txf" "$LOCALDIR/Fonts/"
