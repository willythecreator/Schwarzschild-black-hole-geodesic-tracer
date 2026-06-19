#pragma once

// Integrates a single photon's path around a Schwarzschild black hole confined to its own orbital plane, using u = 1/r as the radial variable.

// Governing equation (from the null geodesic plus conserved E, L):
//     d^2u/dphi^2 + u = 3*M*u^2

// M = 1.0 (geometric units, G = c = 1) so all lengths are in units of black hole mass. Event horizon at r = 2M, photon sphere at r = 3M.

class GeodesicIntegrator
{
public:
    enum class Outcome
    {
        StillTracing,
        Escaped,
        Captured
    };

    // b = impact parameter (L/E), r0, phi0 = starting radius/angle in the photon's plane
    GeodesicIntegrator(double b, double r0, double phi0);

    // TODO: RK4 step on stats (u, dudPhi) using:
    //  du/dphi = dudPhi
    //  d(dudPhi)/dphi = 3*M*u*u - u
    // Advance currentPhi by dPhi too
    void step(double dPhi);

    // TODO Escaped once r() exceeds some large cutoff (e.g. 1000*M),
    // Captured once r() drops below the horizon (e.g. 2.0*M plus a small epsilon), otherwise StillTracing.
    Outcome outcome() const;

    double r() const;
    double phi() const { return currentPhi; }

private:
    static constexpr double M = 1.0;

    double impactParam; // stored for use when you derive initial dudPhi
    double u;
    double dudPhi;
    double currentPhi;
};