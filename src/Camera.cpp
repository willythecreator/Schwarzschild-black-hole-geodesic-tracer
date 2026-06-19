#include "Camera.h"
#include <cmath>
#include <algorithm>

namespace
{
    constexpr double PI = 3.14159265358979323846;
}

Camera::Camera(Vec3 position_, Vec3 lookDir_, double fovDegrees, int imageWidth, int imageHeight) : position(position_), lookDir(lookDir_.normalized()), fov(fovDegrees), width(imageWidth), height(imageHeight) {}

double Camera::impactParameterForPixel(int px, int py) const
{
    double aspect = static_cast<double>(width) / height;
    double scale = std::tan(fov * PI / 180.0 / 2.0);

    double camX = (2.0 * (px + 0.5) / width - 1.0) * aspect * scale;
    double camY = (1.0 - 2.0 * (py + 0.5) / height) * scale;

    Vec3 worldUp(0, 1, 0);
    Vec3 forward = lookDir;
    Vec3 right = forward.cross(worldUp).normalized();
    Vec3 up = right.cross(forward);

    Vec3 rayDir = (right * camX + up * camY + forward).normalized();

    Vec3 toBH = (Vec3(0, 0, 0) - position).normalized();
    double cosTheta = std::max(-1.0, std::min(1.0, rayDir.dot(toBH)));
    double theta = std::acos(cosTheta);

    double r0 = position.length();
    return r0 * std::sin(theta);
}