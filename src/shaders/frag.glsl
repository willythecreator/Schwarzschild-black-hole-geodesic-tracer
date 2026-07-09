#version 330 core
in vec2 fragCoord;
out vec4 FragColor;

uniform vec3 camPos;
uniform vec3 camForward;
uniform vec3 camRight;
uniform vec3 camUp;
uniform float fov;
uniform float aspectRatio;
uniform float time;
uniform float camHeight;

const float M         = 1.0;
const float HORIZON   = 2.02;
const float ESCAPE_R  = 200.0;
const int   MAX_STEPS = 8000;
const float dPhi      = 0.012;

float hash(vec3 p)
{
    p = fract(p * vec3(443.897, 397.297, 491.187));
    p += dot(p, p.yxz + 19.19);
    return fract((p.x + p.y) * p.z);
}

vec3 starfield(vec3 dir)
{
    vec3 d = normalize(dir);
    vec3 color = vec3(0.0);
    for (int i = 1; i <= 4; i++)
    {
        float scale = 120.0 * float(i);
        vec3 cell = floor(d * scale);
        vec3 g = fract(d * scale) - 0.5;
        float h = hash(cell);
        float s = smoothstep(0.06, 0.0, length(g)) * step(0.88, h);
        float cSeed = hash(cell + 0.5);
        vec3 sc = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.9, 0.7), cSeed);
        color += sc * s * (0.6 + 0.4 / float(i));
    }
    return color;
}

// Disk emission at radius r 
vec3 diskEmission(float r, float doppler)
{
    if (r < 3.0 || r > 20.0) return vec3(0.0);

    // Sharp radial profile — peaks near ISCO (r=6M), falls off both ways
    float inner = exp(-pow((r - 3.5) / 1.2, 2.0)) * 2.5;
    float body  = exp(-pow((r - 7.0) / 5.0,  2.0)) * 1.0;
    float outer = exp(-pow((r - 14.0)/ 4.0,  2.0)) * 0.3;
    float radial = inner + body + outer;

    // Temperature gradient
    float t    = clamp((r - 3.0) / 17.0, 0.0, 1.0);
    vec3 hot   = vec3(1.00, 0.75, 0.35);
    vec3 mid   = vec3(0.90, 0.25, 0.02);
    vec3 cool  = vec3(0.40, 0.02, 0.00);
    vec3 base  = t < 0.35
        ? mix(hot,  mid,  t / 0.35)
        : mix(mid,  cool, (t - 0.35) / 0.65);

    // Relativistic beaming ∝ D³
    float beam = pow(clamp(doppler, 0.1, 4.0), 3.0);

    return base * radial * beam * 3.5;
}

void main()
{
    float scale  = tan(radians(fov) * 0.5);
    vec3  rayDir = normalize(
        camForward +
        camRight * fragCoord.x * scale * aspectRatio +
        camUp    * fragCoord.y * scale
    );

    // Impact parameter
    vec3  toBH     = normalize(-camPos);
    float cosTheta = clamp(dot(rayDir, toBH), -1.0, 1.0);
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    float r0       = length(camPos);
    float b        = r0 * sinTheta;

    // World space equatorial plane crossing detection
    // We track the ray's y coordinate directly using the camera height and the ray direction's y component accumulated over phi steps
    float rayDirY = rayDir.y;

    // Initial conditions
    float u       = 1.0 / r0;
    float radicand = max(0.0, 1.0 - (1.0 - 2.0 * M * u) * b * b * u * u);
    float dudPhi_  = sqrt(radicand) / max(b, 0.001);

    vec3  diskAccum  = vec3(0.0);
    float minR       = r0;
    bool  captured   = false;
    float phi        = 0.0;

    // Height sign: track sign changes to detect equatorial plane crossings
    // Height above equatorial plane ≈ r * sin(phi) * tiltSin
    float prevH = camHeight;

    // Each successive crossing is dimmer (higher-order images)
    float crossingWeight = 1.0;

    for (int i = 0; i < MAX_STEPS; i++)
    {
        // RK4
        float k1u = dudPhi_;
        float k1v = 3.0 * M * u * u - u;

        float u2  = u + 0.5 * dPhi * k1u;
        float v2  = dudPhi_ + 0.5 * dPhi * k1v;
        float k2u = v2;
        float k2v = 3.0 * M * u2 * u2 - u2;

        float u3  = u + 0.5 * dPhi * k2u;
        float v3  = dudPhi_ + 0.5 * dPhi * k2v;
        float k3u = v3;
        float k3v = 3.0 * M * u3 * u3 - u3;

        float u4  = u + dPhi * k3u;
        float v4  = dudPhi_ + dPhi * k3v;
        float k4u = v4;
        float k4v = 3.0 * M * u4 * u4 - u4;

        u       += (dPhi / 6.0) * (k1u + 2.0*k2u + 2.0*k3u + k4u);
        dudPhi_ += (dPhi / 6.0) * (k1v + 2.0*k2v + 2.0*k3v + k4v);
        phi     += dPhi;

        float r = 1.0 / u;
        minR = min(minR, r);

        if (r < HORIZON) { captured = true; break; }
        if (r > ESCAPE_R) break;

        // Approximate world space height: camera height + ray travels in rayDir.y direction modified by how much the goedesic has curved
        float curH = camHeight + r * sin(phi) * rayDirY;

        // Equatorial plane crossing: sign change in height
        if (prevH * curH < 0.0 && r > 3.0 && r < 20.0)
        {
            // Doppler factor from orbital velocity
            float denom   = max(0.001, 1.0 - 3.0 * M / r);
            float v_orb   = clamp(sqrt(M / r) / sqrt(denom), 0.0, 0.95);
            // Approaching side: cos(phi) determines which side
            float cosA    = cos(phi) * rayDirY;
            float doppler = sqrt((1.0 + v_orb * cosA) /
                            max(0.001, 1.0 - v_orb * cosA));

            // Gravitational redshift
            float gFactor = sqrt(max(0.001, 1.0 - 2.0 * M / r));

            diskAccum    += diskEmission(r, doppler * gFactor) * crossingWeight;
            crossingWeight *= 0.55; // each successive image is dimmer
        }

        prevH = curH;
    }

    // Photon ring on shadow edge
    vec3 ring = vec3(0.0);
    if (!captured) {
        float graze = clamp(1.0 - (minR - 3.0 * M) / (2.5 * M), 0.0, 1.0);
        ring = vec3(1.0, 0.7, 0.3) * pow(graze, 8.0) * 1.5;
    }

    vec3 bg = captured ? vec3(0.0) : starfield(rayDir);
    vec3 color = captured ? vec3(0.0) : bg + diskAccum + ring;

    // Tone mapping + gamma
    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0 / 2.2));

    FragColor = vec4(color, 1.0);
}