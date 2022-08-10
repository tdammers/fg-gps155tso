# Garmin GPS155 TSO for FlightGear

The Garmin GPS155 TSO was one of the first GPS units to be certified for RNAV
IFR operations in GA aircraft. Unlike most newer devices, it does not feature
a map display; it has a text-only 20x3 character cell display, and it can drive
a HSI or similar instrument to provide visual guidance to the pilot.

## Installation

This simulation is intended for aircraft model authors to add to existing or
new FlightGear aircraft; it cannot be installed as an add-on, and it is not
intended to be user-installable.

With that said, the installation method goes something like this:

1. Copy all the relevant files into your aircraft model's directory tree. You
   need the following directories and everything below them:
    - `Fonts`
    - `Models`
    - `Nasal`
   The easiest way to achieve this is by using the included `to-aircraft.sh`
   script (requires Bash, which is available or emulated on all Linux and OS X
   systems, and on Windows via various Unix layers such as git-bash, MSYS,
   Cygwin, etc.).
2. Register the Nasal scripts with your aircraft. In your `aircraft-set.xml`,
   add the following to the `<nasal>` section:
   ```xml
   <gps155>
    <file>Nasal/gps155.nas</file>
   </gps155>
   ```
   This will load the GPS155's main entry point; all the other scripts are
   loaded automatically from there.
3. Add the 3D model to your cockpit. This can be achieved by adding something
   like the following to your cockpit model XML:
   ```xml
    <model>
      <name>gps155</name>
      <path>Aircraft/Lockheed1049h/Models/Instruments/gps155.xml</path>
      <offsets>
        <x-m>-15.649</x-m>
        <y-m>-0.480</y-m>
        <z-m>0.760</z-m>
        <pitch-deg>0</pitch-deg>
      </offsets>
    </model>
   ```
   **FIXME:** the GPS155 backlight is currently hard-coded to feed off of the
   `/controls/lighting/panel-norm` property; this should of course become a
   property alias, and aircraft authors can select whichever property suits
   them to drive the backlight.
4. Adapt your aircraft so that the GPS can drive the autopilot and HSI. The
   easiest way to do that is to use the "slaving" feature of the built-in GPS,
   which effectively sends quasi-VOR signals to the HSI and autopilot,
   synthesized from the GPS. However, you can also use a 3-way switch (NAV1,
   NAV2, GPS) and feed the autopilot and instruments directly from the GPS.

## Some Technical Details

The GPS155TSO is designed to use the built-in GPS device as much as possible;
it mostly acts as a frontend for that, so almost all the functionality is also
accessible through the Equipment → GPS dialog. However, a couple additional
things are necessary, and most of these are reflected in the property tree
under `/instrumentation/gps155`. What it inherits from the built-in GPS remains
in `/instrumentation/gps`, so in order to interact with the unit via
properties, you will need to use both of these subtrees.

Satellite data is currently not a proper simulation, but uses random data
according to a relatively simple algorithm; when the unit says "acquiring", it
just shows a selection of random satellite IDs, with signal strengths
fluctuating randomly, until a timer runs out and the unit becomes functional.

Likewise, just like the built-in GPS itself, the GPS155TSO does not simulate
GPS inaccuracy; it always produces perfect lateral positioning data, and the
altitude is read off of the first altimeter.