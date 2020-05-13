# Custom Sphere-cast based vehicle implementation for Godot 3.x

![icon](https://github.com/Tobalation/RaycastVehicleTest/blob/master/icon.png)

A custom vehicle implementation emphasizing simplicity and adaptability.

## Difference of this branch and master
This branch uses sphere casting instead of raycasting, which from my testing doesn't seem to have a performance impact.
The code has also been refactored somewhat as well.

The drive elements serve as a basis for any type of land vehicle that needs to be suspended by "springs" and propelled
using driving force applied against the ground.

This system primarily allows for the simulation of wheeled, tracked and hover vehicles with as many propulsion elements as needed.

## In this project:

Currently, two different sample vehicles are provided:

1. A tank type vehicle with 10 drive elements total (5 per side) with tracked vehicle steering that has neutral turn capability.

2. A 4 wheel drive vehicle with 4 drive elements (1 per wheel) with traditional car steering.

The default scene is the tracked vehicle. You can switch to the other vehicle by pressing escape to unlock the mouse
and clicking on the 'Change to 4WD vehicle' button.

## What about the 3rd person orbit camera?
The orbit camera used in this project is another example of mine, it can be found [here.](https://github.com/Tobalation/Godot-orbit-camera)
