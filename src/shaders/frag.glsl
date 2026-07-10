#version 330 core
in vec2 fragCoord;
out vec4 FragColor;

uniform vec3  camPos;
uniform vec3  camForward;
uniform vec3  camRight;
uniform vec3  camUp;
uniform float fov;
uniform float aspectRatio;
uniform float time;

const float M         = 1.0;
const float HORIZON   = 2.05;
const float ESCAPE_R  = 300.0;
const int   MAX_STEPS = 6000;
const float dPhi      = 0.015;
const float PI        = 3.14159265358979;

// Hash 
float hash(vec3 p) {
    p = fract(p * vec3(443.897, 397.297, 491.187));
    p += dot(p, p.yxz + 19.19);
    return fract((p.x + p.y) * p.z);
}

// Milky Way starfield 
vec3 starfield(vec3 dir) {
    vec3 d = normalize(dir);

    // Milky Way band
    vec3  galN  = normalize(vec3(0.0, 0.5, 0.87));
    float glat  = abs(dot(d, galN));
    float band  = exp(-glat * glat * 6.0);
    vec3  mw    = vec3(0.0) * band;

    // Bright sparse stars
    vec3 stars = vec3(0.0);
    for (int i = 1; i <= 4; i++) {
        float sc   = 130.0 * float(i);
        vec3  cell = floor(d * sc);
        vec3  g    = fract(d * sc) - 0.5;
        float h    = hash(cell);
        float s    = smoothstep(0.055, 0.0, length(g)) * step(0.86, h);
        float cs   = hash(cell + 0.5);
        vec3  col  = mix(
            mix(vec3(0.6, 0.7, 1.0), vec3(1.0, 0.95, 0.8), cs),
            vec3(1.0, 0.5, 0.2), step(0.93, cs)
        );
        stars += col * s * (0.55 + 0.45 / float(i));
    }

    // Dense faint stars in band
    for (int i = 1; i <= 2; i++) {
        float sc   = 320.0 * float(i);
        vec3  cell = floor(d * sc);
        vec3  g    = fract(d * sc) - 0.5;
        float h    = hash(cell + 7.3);
        float s    = smoothstep(0.035, 0.0, length(g)) * step(0.72, h) * band;
        stars     += vec3(0.7, 0.8, 1.0) * s * 0.4;
    }

    return stars;
}

// Disk emission 
vec3 diskEmission(float r, float doppler) {
    if (r < 3.0 || r > 18.0) return vec3(0.0);

    // Three-zone radial profile
    float z1 = exp(-pow((r - 3.8) / 1.0, 2.0)) * 3.0;   // bright inner ring
    float z2 = exp(-pow((r - 7.0) / 3.5, 2.0)) * 1.2;   // mid body
    float z3 = exp(-pow((r - 13.0) / 3.5, 2.0)) * 0.35; // faint outer
    float radial = z1 + z2 + z3;

    // Temperature: white-hot inner → orange → deep red outer
    float t   = clamp((r - 3.0) / 15.0, 0.0, 1.0);
    vec3 hot  = vec3(1.00, 0.70, 0.20);
    vec3 mid  = vec3(1.00, 0.35, 0.00);
    vec3 cool = vec3(0.60, 0.08, 0.00);
    vec3 base = t < 0.35
        ? mix(hot,  mid,  t / 0.35)
        : mix(mid,  cool, (t - 0.35) / 0.65);

    // Relativistic beaming D^3
    float beam = pow(clamp(doppler, 0.05, 5.0), 3.0);

    // Brightness falloff
    float brightness = 1.2 / (1.0 + (r - 3.0) * 0.18);

    return base * radial * beam * brightness * 3.0;
}

// Main 
void main()
{
    float scale  = tan(radians(fov) * 0.5);
    vec3  rayDir = normalize(
        camForward +
        camRight * fragCoord.x * scale * aspectRatio +
        camUp    * fragCoord.y * scale
    );

    // Impact parameter b = r0 * sin(angle to BH)
    float r0       = length(camPos);
    vec3  toBH     = normalize(-camPos);
    float cosTheta = clamp(dot(rayDir, toBH), -1.0, 1.0);
    float sinTheta = sqrt(max(0.0, 1.0 - cosTheta * cosTheta));
    float b        = r0 * sinTheta;

    // Initial u = 1/r conditions
    float u      = 1.0 / r0;
    float rad    = max(0.0, 1.0 - (1.0 - 2.0*M*u) * b*b * u*u);
    float dudPhi = sqrt(rad) / max(b, 0.001);

    // Integration
    vec3  diskAccum     = vec3(0.0);
    float crossWeight   = 1.0;
    bool  captured      = false;
    float minR          = r0;
    float phi           = 0.0;
    float prevH         = camPos.y;

    for (int i = 0; i < MAX_STEPS; i++)
    {
        // RK4
        float k1u = dudPhi;
        float k1v = 3.0*M*u*u - u;

        float u2  = u + 0.5*dPhi*k1u;
        float v2  = dudPhi + 0.5*dPhi*k1v;
        float k2u = v2;
        float k2v = 3.0*M*u2*u2 - u2;

        float u3  = u + 0.5*dPhi*k2u;
        float v3  = dudPhi + 0.5*dPhi*k2v;
        float k3u = v3;
        float k3v = 3.0*M*u3*u3 - u3;

        float u4  = u + dPhi*k3u;
        float v4  = dudPhi + dPhi*k3v;
        float k4u = v4;
        float k4v = 3.0*M*u4*u4 - u4;

        u      += (dPhi/6.0)*(k1u + 2.0*k2u + 2.0*k3u + k4u);
        dudPhi += (dPhi/6.0)*(k1v + 2.0*k2v + 2.0*k3v + k4v);
        phi    += dPhi;

        float r = 1.0 / u;
        minR = min(minR, r);

        if (r < HORIZON) { captured = true; break; }
        if (r > ESCAPE_R) break;

        // Equatorial plane crossing
        float curH = camPos.y + r * sin(phi) * rayDir.y;
        if (prevH * curH < 0.0 && r > 3.0 && r < 18.0)
        {
            float denom   = max(0.001, 1.0 - 3.0*M/r);
            float v_orb   = clamp(sqrt(M/r) / sqrt(denom), 0.0, 0.95);
            float cosA    = cos(phi) * rayDir.y;
            float doppler = sqrt((1.0 + v_orb*cosA) /
                            max(0.001, 1.0 - v_orb*cosA));
            float gFactor = sqrt(max(0.001, 1.0 - 2.0*M/r));
            diskAccum    += diskEmission(r, doppler * gFactor) * crossWeight;
            crossWeight  *= 0.45;  // tighter falloff = sharper bands
        }
        prevH = curH;
    }

    // Photon ring
    vec3 ring = vec3(0.0);
    if (!captured) {
        float graze = clamp(1.0 - (minR - 3.0*M) / (2.0*M), 0.0, 1.0);
        ring = vec3(1.0, 0.82, 0.5) * pow(graze, 10.0) * 2.0;
    }

    // Gravitational redshift on starfield
    vec3 bg = vec3(0.0);
    if (!captured) {
        bg = starfield(rayDir);
    }

    vec3 color = captured ? vec3(0.0) : bg + diskAccum + ring;

    // Tone mapping + gamma
    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0 / 2.2));

    FragColor = vec4(color, 1.0);
}