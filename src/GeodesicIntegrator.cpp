#include "GeodesicIntegrator.h"
#include <cmath>
#include <utility>
#include <algorithm>

GeodesicIntegrator::GeodesicIntegrator(double b, double r0, double phi0)
    : impactParam(b), u(1.0 / r0), currentPhi(phi0)
{
    double radicand = 1.0 - (1.0 - 2.0 * M * u) * impactParam * impactParam * u * u;
    radicand = std::max(0.0, radicand); // guards rays that never head inward at this r0
    dudPhi = std::sqrt(radicand) / impactParam;
}

void GeodesicIntegrator::step(double dPhi)
{
    auto derivative = [](double uVal, double vVal) -> std::pair<double, double>
    {
        double dudphi = vVal;
        double dvdphi = 3.0 * M * uVal * uVal - uVal;
        return {dudphi, dvdphi};
    };

    auto [k1u, k1v] = derivative(u, dudPhi);
    auto [k2u, k2v] = derivative(u + 0.5 * dPhi * k1u, dudPhi + 0.5 * dPhi * k1v);
    auto [k3u, k3v] = derivative(u + 0.5 * dPhi * k2u, dudPhi + 0.5 * dPhi * k2v);
    auto [k4u, k4v] = derivative(u + dPhi * k3u, dudPhi + dPhi * k3v);

    u += (dPhi / 6.0) * (k1u + 2.0 * k2u + 2.0 * k3u + k4u);
    dudPhi += (dPhi / 6.0) * (k1v + 2.0 * k2v + 2.0 * k3v + k4v);
    currentPhi += dPhi;
}

GeodesicIntegrator::Outcome GeodesicIntegrator::outcome() const
{
    double currentR = r();
    if (currentR < 2.02 * M)
        return Outcome::Captured;
    if (currentR > 1000.0 * M)
        return Outcome::Escaped;
    return Outcome::StillTracing;
}

double GeodesicIntegrator::r() const
{
    return 1.0 / u;
}