Sensible Deconstruction

A Factorio Mod that deconstructs buildings in a sensible way.

The following five steps are executed while there are still buildings to be deconstructed:
1. Deconstruct all buildings except Roboports and Electric poles.
2. Deconstruct Roboports and Electric poles beginning from the edgesof the power supply area.
3. Remove cycles within all energy pole connections.
4. Again deconstruct Roboports and Electric poles beginning from the edges of the power supply area
5. Deconstruct additional Roboports, that are not at the edges of the power supply area

If there are still buildings left after the last step, the sensible deconstruction planner gives up,
since it encountered an unhandleable situation.

This method allows all (within reason) selected buildings to be deconstructed by construction bots.

Use Ctrl-Shift-D to enable the newly introduced sensible deconstruction planner.

ALPHA-version - Additional testing and feedback appreciated.

Missing features:
- Quality of life additions
- Visual feedback

License: MIT

Graphics attribution: The icon uses the deconstruction planner graphic of the Factorio base game

Factorio 1.1 is compatible up to V0.1.1.
Factorio 2.0 is compatible to V0.2.0 and later.
