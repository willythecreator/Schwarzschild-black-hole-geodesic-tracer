#pragma once
#include <cmath>

struct Vec3
{
    double x = 0, y = 0, z = 0;

    Vec3() = default;
    Vec3(double x_, double y_, double z_) : x(x_), y(y_), z(z_) {}

    Vec3 operator+(const Vec3 &o) const { return {x + o.x, y + o.y, z + o.z}; }
    Vec3 operator-(const Vec3 &o) const { return {x - o.x, y - o.y, z - o.z}; }
    Vec3 operator*(double s) const { return {x * s, y * s, z * s}; }

    double dot(const Vec3 &o) const { return x * o.x + y * o.y + z * o.z; }
    Vec3 cross(const Vec3 &o) const
    {
        return {y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x};
    }
    double length() const { return std::sqrt(dot(*this)); }
    Vec3 normalized() const
    {
        double l = length();
        return {x / l, y / l, z / l};
    }
};