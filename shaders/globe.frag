#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution;
uniform float iTime;
uniform float rotY;
uniform float windRot;
uniform float glow;

out vec4 fragColor;

#define PI 3.14159265359

mat2 rotate2D(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, -s, s, c);
}

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    f = f * f * (3.0 - 2.0 * f);

    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(
        mix(a, b, f.x),
        mix(c, d, f.x),
        f.y
    );
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;

    for (int i = 0; i < 5; i++) {
        value += noise2D(p) * amplitude;
        p = p * 2.02 + vec2(17.1, 9.2);
        amplitude *= 0.5;
    }

    return value;
}

float circularMask(float distanceValue, float radius) {
    return 1.0 - smoothstep(
        radius - 0.012,
        radius + 0.012,
        distanceValue
    );
}

vec3 goldColor() {
    return vec3(1.0, 0.70, 0.16);
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;

    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = uv * 2.0 - 1.0;

    p.x *= iResolution.x / iResolution.y;

    // Posisi globe di area atas-tengah.
    vec2 globeCenter = vec2(0.0, 0.30);
    vec2 d = p - globeCenter;

    float r = length(d);
    float angle = atan(d.y, d.x);

    float globeRadius = 0.515;

    // ------------------------------------------------------------
    // BLACK MARBLE BACKGROUND
    // ------------------------------------------------------------

    vec2 marbleUV = p * 2.6;

    float marble = fbm(marbleUV * 1.25);

    float veinA = sin(
        marbleUV.x * 3.0 +
        marbleUV.y * 1.4 +
        marble * 7.0
    );

    float veinB = sin(
        marbleUV.y * 2.1 -
        marbleUV.x * 1.1 +
        marble * 5.0
    );

    float veins = pow(
        abs(veinA * veinB),
        7.0
    );

    float thinVeins = pow(
        max(0.0, sin(marbleUV.x * 5.0 + marble * 10.0)),
        18.0
    );

    vec3 background = vec3(0.006, 0.006, 0.007);

    background += vec3(0.13, 0.075, 0.018) * veins;
    background += vec3(0.48, 0.30, 0.075) * thinVeins;

    // Sedikit grain pada batu.
    float grain = hash21(fragCoord * 0.45);
    background += vec3(grain) * 0.018;

    vec3 color = background;

    // ------------------------------------------------------------
    // GOLDEN WIND AND CLOUD ATMOSPHERE
    // Arah atmosfer berlawanan dengan rotasi globe.
    // ------------------------------------------------------------

    float wind = 0.0;

    for (int i = 0; i < 7; i++) {
        float fi = float(i);

        float localRadius =
            r * (0.92 + fi * 0.105);

        float localAngle =
            angle
            - windRot * (0.48 + fi * 0.07)
            + localRadius * (2.05 + fi * 0.19);

        vec2 swirlUV = vec2(
            cos(localAngle) * localRadius,
            sin(localAngle) * localRadius
        );

        swirlUV += vec2(
            windRot * 0.22,
            -windRot * 0.12
        );

        float cloud = fbm(
            swirlUV * (3.0 + fi * 0.18)
            + vec2(0.0, windRot * 0.5)
        );

        float ribbon = sin(
            localAngle * (2.1 + fi * 0.16)
            + cloud * 5.4
            + localRadius * 8.0
        );

        ribbon = smoothstep(
            0.42,
            0.90,
            ribbon * 0.5 + 0.5
        );

        float radialMask =
            smoothstep(1.62, 0.42, localRadius) *
            smoothstep(0.32, 0.72, localRadius);

        float cloudMask = smoothstep(
            0.46,
            0.78,
            cloud
        );

        float line = ribbon * radialMask * cloudMask;

        // Debu emas di sekitar atmosfer.
        float dust = hash21(vec2(
            floor(localAngle * 20.0),
            floor(localRadius * 45.0) + fi * 12.0
        ));

        dust = pow(dust, 5.0);
        dust *= radialMask * smoothstep(0.65, 0.95, cloud);

        vec3 atmosphereGold = mix(
            vec3(0.72, 0.38, 0.035),
            vec3(1.0, 0.88, 0.42),
            ribbon
        );

        color += atmosphereGold * line * glow * 0.65;
        color += vec3(1.0, 0.76, 0.22) * dust * glow * 3.0;

        wind += line;
    }

    // Soft aura di belakang globe.
    float aura = exp(-r * 3.2) * 0.20;
    color += vec3(1.0, 0.47, 0.06) * aura * glow;

    // ------------------------------------------------------------
    // GOLDEN GLOBE
    // ------------------------------------------------------------

    if (r < globeRadius + 0.035) {
        vec2 sphereUV = d / globeRadius;

        float zSquared = 1.0 - dot(sphereUV, sphereUV);

        if (zSquared > 0.0) {
            float z = sqrt(zSquared);

            // Surface normal bola.
            vec3 normal = vec3(
                sphereUV.x,
                sphereUV.y,
                z
            );

            // Rotasi permukaan globe.
            normal.xz = rotate2D(rotY) * normal.xz;

            vec3 lightDirection = normalize(
                vec3(-0.52, 0.42, 0.92)
            );

            float diffuse = max(
                0.0,
                dot(normal, lightDirection)
            );

            vec3 viewDirection = vec3(0.0, 0.0, 1.0);

            vec3 reflected = reflect(
                -lightDirection,
                normal
            );

            float specular = pow(
                max(0.0, dot(reflected, viewDirection)),
                58.0
            );

            float fresnel = pow(
                1.0 - max(0.0, dot(normal, viewDirection)),
                3.0
            );

            vec3 darkGold = vec3(
                0.25,
                0.105,
                0.012
            );

            vec3 brightGold = vec3(
                0.95,
                0.58,
                0.105
            );

            vec3 globeColor = mix(
                darkGold,
                brightGold,
                smoothstep(0.05, 0.98, diffuse)
            );

            // Arah highlight agar mirip logam mengilap.
            globeColor += vec3(
                1.0,
                0.78,
                0.30
            ) * specular * 1.4;

            globeColor = mix(
                globeColor,
                globeColor * 0.42,
                fresnel * 0.55
            );

            // Noise sangat halus pada permukaan logam.
            float surfaceNoise = fbm(
                sphereUV * 8.0 + vec2(rotY * 0.2)
            );

            globeColor += vec3(
                0.15,
                0.075,
                0.012
            ) * surfaceNoise * 0.16;

            float globeMask = circularMask(
                r,
                globeRadius
            );

            color = mix(
                color,
                globeColor,
                globeMask
            );

            // Rim light.
            float rim = smoothstep(
                0.0,
                0.075,
                abs(r - globeRadius)
            );

            rim = 1.0 - rim;

            color += vec3(
                1.0,
                0.70,
                0.18
            ) * rim * 0.42;
        }
    }

    // ------------------------------------------------------------
    // THORN CROWN
    // ------------------------------------------------------------

    float crownRadius = globeRadius + 0.050;
    float crownDistance = abs(r - crownRadius);

    if (crownDistance < 0.060) {
        float thornAngle =
            angle * 25.0
            + rotY * 1.25;

        float thornShape = sin(thornAngle);
        thornShape = smoothstep(
            0.64,
            0.98,
            thornShape * 0.5 + 0.5
        );

        float crownMask = smoothstep(
            0.065,
            0.005,
            crownDistance
        );

        crownMask *= thornShape;

        vec3 crownColor = vec3(
            0.006,
            0.004,
            0.002
        );

        crownColor += vec3(
            0.10,
            0.055,
            0.012
        ) * thornShape;

        color = mix(
            color,
            crownColor,
            crownMask * 0.96
        );
    }

    // ------------------------------------------------------------
    // VIGNETTE
    // ------------------------------------------------------------

    float vignette = 1.0 - smoothstep(
        0.45,
        1.45,
        length(p * vec2(0.72, 0.84))
    );

    color *= 0.70 + vignette * 0.42;

    // Sedikit warm color grading.
    color = pow(color, vec3(0.91));

    fragColor = vec4(color, 1.0);
}
