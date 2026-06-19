#pragma once
#include "Vec3.h"

// Converts a pixel coordinate into the impact parameter b that a
// GeodesicIntegrator needs, based on a pinhole camera looking at the hole
class Camera
{
public:
    Camera(Vec3 position, Vec3 lookDir, double fovDegrees, int imageWidth, int imageHeight);

    // TODO: 1) map (px, py) to a ray direction in camera space using fov, width, height. 2) rotate into world space using lookDir. 3) compute b from the angle between that direction and the line from the camera to the black hole center (b = L/E = r0 * sin(angle) far away).
    double impactParameterForPixel(int px, int py) const;

private:
    Vec3 position;
    Vec3 lookDir;
    double fov;
    int width, height;
};