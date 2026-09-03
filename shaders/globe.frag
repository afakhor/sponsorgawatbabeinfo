#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution;
uniform float iTime;
uniform float rotY;
uniform float windRot;
uniform float glow;
uniform float beatPulse;
uniform float rotX;
uniform float axisTilt;

uniform sampler2D textTexture;

out vec4 fragColor;

const float PI = 3.14159265359;
const float TWO_PI = 6.28318530718;

const float GLOBE_RADIUS = 0.27;
const float ATMOSPHERE_GAP = 0.012;
const float ATMOSPHERE_THICKNESS = 0.105;

const float GLOBE_ALPHA = 0.95;
const float PLASMA_ALPHA = 0.70;
const float BUBBLE_ALPHA = 0.60;
const float ATMOSPHERE_ALPHA = 0.70;
const float LIGHTNING_ALPHA = 0.70;

// ==================================================
// RANDOM DAN NOISE
// ==================================================

float hash11(float p) {
    return fract(
        sin(p * 127.1) *
        43758.5453
    );
}

float hash21(vec2 p) {
    p = fract(
        p * vec2(123.34, 456.21)
    );

    p += dot(
        p,
        p + 45.32
    );

    return fract(
        p.x * p.y
    );
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    f = f * f * (
        3.0 - 2.0 * f
    );

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

// ==================================================
// ROTASI 3D
// ==================================================

vec3 rotateXPoint(
    vec3 p,
    float angle
) {
    float c = cos(angle);
    float s = sin(angle);

    return vec3(
        p.x,
        p.y * c - p.z * s,
        p.y * s + p.z * c
    );
}

vec3 rotateYPoint(
    vec3 p,
    float angle
) {
    float c = cos(angle);
    float s = sin(angle);

    return vec3(
        p.x * c - p.z * s,
        p.y,
        p.x * s + p.z * c
    );
}

vec3 rotateZPoint(
    vec3 p,
    float angle
) {
    float c = cos(angle);
    float s = sin(angle);

    return vec3(
        p.x * c - p.y * s,
        p.x * s + p.y * c,
        p.z
    );
}

// ==================================================
// MASK GLOBE
// ==================================================

float globeMask(
    float radius
) {
    return 1.0 - smoothstep(
        GLOBE_RADIUS - 0.007,
        GLOBE_RADIUS + 0.007,
        radius
    );
}

float globeInsideMask(
    float radius
) {
    return 1.0 - smoothstep(
        GLOBE_RADIUS - 0.010,
        GLOBE_RADIUS,
        radius
    );
}

// ==================================================
// BUIH
// ==================================================

vec3 bubblesEffect(
    vec2 p,
    float time,
    float pulse
) {
    vec2 grid = p * 7.5;
    vec2 cell = floor(grid);
    vec2 local = fract(grid) - 0.5;

    vec3 result = vec3(0.0);

    for (
        float layer = 0.0;
        layer < 3.0;
        layer += 1.0
    ) {
        vec2 currentCell =
            cell +
            vec2(
                layer * 17.17,
                layer * 31.41
            );

        float seed = hash21(
            currentCell
        );

        if (seed > 0.64) {
            vec2 randomPosition =
                vec2(
                    hash21(
                        currentCell +
                        vec2(4.1, 8.7)
                    ),
                    hash21(
                        currentCell +
                        vec2(9.3, 2.4)
                    )
                ) - 0.5;

            float cycle =
                3.0 + seed * 3.0;

            float phase = fract(
                time / cycle + seed
            );

            vec2 position =
                local - randomPosition;

            position.y += phase * 0.75;

            position.x += sin(
                phase * TWO_PI +
                seed * 20.0
            ) * 0.07;

            float distanceToBubble =
                length(position);

            float size = mix(
                0.010,
                0.065,
                sin(phase * PI)
            );

            size *= 1.0 + pulse * 0.18;

            float body = 1.0 - smoothstep(
                size * 0.55,
                size,
                distanceToBubble
            );

            float edge = 1.0 - smoothstep(
                size * 0.82,
                size,
                distanceToBubble
            );

            edge *= smoothstep(
                size * 0.42,
                size * 0.82,
                distanceToBubble
            );

            float shine = 1.0 - smoothstep(
                size * 0.02,
                size * 0.28,
                length(
                    position -
                    vec2(
                        -size * 0.25,
                        -size * 0.25
                    )
                )
            );

            vec3 bubbleColor = mix(
                vec3(0.20, 0.80, 0.95),
                vec3(1.00, 0.90, 0.58),
                seed
            );

            result +=
                bubbleColor *
                body *
                0.48;

            result +=
                vec3(1.0) *
                edge *
                0.38;

            result +=
                vec3(1.0) *
                shine *
                body *
                0.28;
        }
    }

    return result;
}

// ==================================================
// BINTANG
// ==================================================

vec3 starsEffect(
    vec2 p,
    float time
) {
    vec2 cell = floor(
        p * 95.0
    );

    float seed = hash21(cell);

    float star = step(
        0.988,
        seed
    );

    float twinkle =
        0.65 +
        0.35 *
        sin(
            time * 2.5 +
            seed * 60.0
        );

    return vec3(
        0.58,
        0.78,
        1.00
    ) *
    star *
    twinkle *
    0.22;
}

// ==================================================
// PLASMA PUSARAN CAKRA BERDURI
// ==================================================

vec4 plasmaEffect(
    vec2 q,
    float time,
    float pulse
) {
    float radius = length(q);
    float angle = atan(q.y, q.x);

    float spiralAngle =
        angle -
        radius * 13.0 -
        time * 1.65 -
        pulse * 0.45;

    float rayA = sin(
        spiralAngle * 17.0 +
        sin(angle * 5.0 + time) * 1.8
    );

    float rayB = sin(
        spiralAngle * 31.0 -
        radius * 18.0 -
        time * 2.4
    );

    float rayC = sin(
        angle * 53.0 +
        radius * 34.0 -
        time * 3.3
    );

    float rays =
        rayA * 0.48 +
        rayB * 0.32 +
        rayC * 0.20;

    rays = rays * 0.5 + 0.5;

    float spikes = smoothstep(
        0.56,
        0.88,
        rays
    );

    float radialMask =
        smoothstep(
            0.025,
            0.12,
            radius
        ) *
        (
            1.0 -
            smoothstep(
                0.80,
                1.0,
                radius
            )
        );

    float smoke = noise2(
        q * 8.0 +
        vec2(
            time * 0.24,
            -time * 0.16
        )
    );

    float plasmaMask =
        spikes *
        radialMask *
        (
            0.72 +
            smoke * 0.55
        );

    plasmaMask *=
        0.72 +
        pulse * 0.38;

    float core = exp(
        -radius * 8.0
    );

    vec3 purple = vec3(
        0.32,
        0.015,
        0.95
    );

    vec3 magenta = vec3(
        0.95,
        0.025,
        0.42
    );

    vec3 blue = vec3(
        0.04,
        0.22,
        1.00
    );

    vec3 color = mix(
        purple,
        magenta,
        smoothstep(
            0.42,
            0.78,
            rays
        )
    );

    color = mix(
        color,
        blue,
        smoothstep(
            0.70,
            1.0,
            smoke
        ) * 0.42
    );

    color += vec3(
        1.0,
        0.35,
        0.85
    ) *
    core *
    0.70;

    float alpha =
        plasmaMask *
        PLASMA_ALPHA;

    return vec4(
        color * 1.35,
        alpha
    );
}

// ==================================================
// ATMOSFER ASAP ANGKASA
// ==================================================

vec4 atmosphereEffect(
    vec2 delta,
    float radius,
    float time,
    float pulse
) {
    float distanceFromGlobe =
        radius -
        GLOBE_RADIUS;

    float startMask = smoothstep(
        ATMOSPHERE_GAP,
        ATMOSPHERE_GAP + 0.018,
        distanceFromGlobe
    );

    float endDistance =
        ATMOSPHERE_GAP +
        ATMOSPHERE_THICKNESS;

    float endMask = 1.0 - smoothstep(
        endDistance - 0.025,
        endDistance,
        distanceFromGlobe
    );

    float shellMask =
        startMask *
        endMask;

    vec2 smokeUV =
        delta * 18.0;

    float smokeA = noise2(
        smokeUV +
        vec2(
            time * 0.24,
            -time * 0.12
        )
    );

    float smokeB = noise2(
        smokeUV * 1.7 +
        vec2(
            -time * 0.16,
            time * 0.22
        )
    );

    float smokeC = noise2(
        smokeUV * 3.2 +
        vec2(
            time * 0.35,
            time * 0.10
        )
    );

    float smoke = smoothstep(
        0.28,
        0.78,
        smokeA * 0.50 +
        smokeB * 0.32 +
        smokeC * 0.18
    );

    float outwardFade = exp(
        -max(
            distanceFromGlobe -
            ATMOSPHERE_GAP,
            0.0
        ) * 8.0
    );

    float beatExpansion =
        1.0 + pulse * 0.12;

    float value =
        smoke *
        outwardFade *
        shellMask *
        beatExpansion;

    vec3 blue = vec3(
        0.015,
        0.24,
        0.95
    );

    vec3 violet = vec3(
        0.28,
        0.04,
        0.75
    );

    vec3 color = mix(
        blue,
        violet,
        smoke * 0.70
    );

    float alpha =
        value *
        ATMOSPHERE_ALPHA;

    return vec4(
        color,
        alpha
    );
}

// ==================================================
// PETIR HANYA PADA JALURNYA
// ==================================================

float lightningEffect(
    float angle,
    float radius,
    float time,
    float pulse
) {
    float distanceFromGlobe =
        radius -
        GLOBE_RADIUS;

    float outsideMask = smoothstep(
        -0.005,
        0.010,
        distanceFromGlobe
    );

    float atmosphereLimit = 1.0 -
        smoothstep(
            ATMOSPHERE_THICKNESS * 0.92,
            ATMOSPHERE_THICKNESS,
            distanceFromGlobe
        );

    float allowedArea =
        outsideMask *
        atmosphereLimit;

    float total = 0.0;

    for (
        float i = 0.0;
        i < 5.0;
        i += 1.0
    ) {
        float seed =
            i * 13.731;

        float speed =
            0.55 + i * 0.07;

        float strike = floor(
            time * speed + seed
        );

        float chance = hash11(
            strike + seed
        );

        if (chance > 0.42) {
            float baseAngle = hash11(
                strike + seed + 7.0
            ) * TWO_PI;

            float life = fract(
                time * speed + seed
            );

            float visibility = exp(
                -life * 10.0
            );

            float pathAngle =
                angle +
                distanceFromGlobe * 30.0 -
                time * 1.2 +
                baseAngle;

            float jagged = sin(
                radius * 150.0 +
                time * 21.0 +
                seed
            ) * 0.065;

            float path = abs(
                sin(
                    pathAngle * 0.5 +
                    jagged
                )
            );

            float core = smoothstep(
                0.025,
                0.0,
                path
            );

            float aura = smoothstep(
                0.085,
                0.0,
                path
            );

            total += (
                core * 3.4 +
                aura * 0.65
            ) *
            visibility *
            allowedArea;
        }
    }

    return total * (
        0.70 +
        pulse * 0.30
    );
}

// ==================================================
// MAIN
// ==================================================

void main() {
    vec2 fragCoord =
        FlutterFragCoord().xy;

    vec2 uv =
        fragCoord /
        iResolution.xy;

    vec2 p =
        uv * 2.0 -
        1.0;

    p.x *=
        iResolution.x /
        iResolution.y;

    vec2 center = vec2(
        0.0,
        0.12
    );

    vec2 delta =
        p - center;

    float radius =
        length(delta);

    float angle =
        atan(
            delta.y,
            delta.x
        );

    float pulse =
        clamp(
            beatPulse,
            0.0,
            1.0
        );

    vec3 color =
        vec3(0.0);

    float alpha =
        0.0;

    // ==================================================
    // BUIH
    // ==================================================

    vec3 bubbles = bubblesEffect(
        p,
        iTime,
        pulse
    );

    float bubbleValue = max(
        bubbles.r,
        max(
            bubbles.g,
            bubbles.b
        )
    );

    float bubbleAlpha =
        smoothstep(
            0.01,
            0.16,
            bubbleValue
        ) *
        BUBBLE_ALPHA;

    color += bubbles;
    alpha = max(
        alpha,
        bubbleAlpha
    );

    // ==================================================
    // BINTANG
    // ==================================================

    vec3 stars = starsEffect(
        p,
        iTime
    );

    float starValue = max(
        stars.r,
        max(
            stars.g,
            stars.b
        )
    );

    float starAlpha =
        step(
            0.01,
            starValue
        ) *
        0.30;

    color += stars;
    alpha = max(
        alpha,
        starAlpha
    );

    // ==================================================
    // ATMOSFER
    // ==================================================

    vec4 atmosphere =
        atmosphereEffect(
            delta,
            radius,
            iTime,
            pulse
        );

    color += atmosphere.rgb;

    alpha = max(
        alpha,
        atmosphere.a *
        clamp(glow, 0.0, 1.0)
    );

    // ==================================================
    // PETIR
    // ==================================================

    float bolt =
        lightningEffect(
            angle,
            radius,
            iTime,
            pulse
        );

    vec3 boltColor = vec3(
        1.0,
        0.18,
        0.015
    );

    float boltAlpha =
        smoothstep(
            0.01,
            0.40,
            bolt
        ) *
        LIGHTNING_ALPHA;

    color +=
        boltColor *
        bolt *
        1.15;

    alpha = max(
        alpha,
        boltAlpha
    );

    // ==================================================
    // GLOBE 3D
    // ==================================================

    float mask =
        globeMask(radius);

    if (
        radius <=
        GLOBE_RADIUS + 0.01
    ) {
        vec2 sphereUV =
            delta /
            GLOBE_RADIUS;

        float zSquared =
            1.0 -
            dot(
                sphereUV,
                sphereUV
            );

        if (zSquared > 0.0) {
            float z =
                sqrt(zSquared);

            vec3 point = vec3(
                sphereUV.x,
                sphereUV.y,
                z
            );

            point = rotateYPoint(
                point,
                rotY
            );

            point = rotateXPoint(
                point,
                rotX
            );

            point = rotateZPoint(
                point,
                axisTilt
            );

            vec3 normal =
                normalize(point);

            vec3 lightDirection =
                normalize(
                    vec3(
                        -0.65,
                        0.40,
                        0.90
                    )
                );

            float diffuse =
                max(
                    dot(
                        normal,
                        lightDirection
                    ),
                    0.0
                );

            float frontLight =
                smoothstep(
                    -0.20,
                    0.70,
                    normal.z
                );

            float rim = pow(
                1.0 -
                max(
                    normal.z,
                    0.0
                ),
                3.0
            );

            vec3 darkGold = vec3(
                0.045,
                0.004,
                0.001
            );

            vec3 gold = vec3(
                0.38,
                0.055,
                0.002
            );

            vec3 brightGold = vec3(
                1.0,
                0.55,
                0.025
            );

            vec3 globeColor =
                mix(
                    darkGold,
                    gold,
                    diffuse
                );

            globeColor = mix(
                globeColor,
                brightGold,
                diffuse *
                frontLight *
                0.85
            );

            // Plasma hanya di dalam permukaan globe.
            vec4 plasma =
                plasmaEffect(
                    sphereUV,
                    iTime,
                    pulse
                );

            float plasmaSurfaceAlpha =
                plasma.a *
                frontLight *
                globeInsideMask(
                    radius
                );

            globeColor = mix(
                globeColor,
                globeColor +
                plasma.rgb * 0.70,
                clamp(
                    plasmaSurfaceAlpha,
                    0.0,
                    1.0
                )
            );

            // Tekstur tulisan globe.
            float longitude =
                atan(
                    point.x,
                    point.z
                );

            float latitude =
                asin(
                    clamp(
                        point.y,
                        -1.0,
                        1.0
                    )
                );

            vec2 textUV = vec2(
                longitude /
                TWO_PI +
                0.5,

                latitude /
                PI +
                0.5
            );

            textUV.x = fract(
                textUV.x -
                windRot * 0.04
            );

            textUV.y = clamp(
                textUV.y,
                0.001,
                0.999
            );

            vec4 textPixel =
                texture(
                    textTexture,
                    textUV
                );

            float textAlpha =
                smoothstep(
                    0.015,
                    0.12,
                    textPixel.a
                );

            vec3 textColor = vec3(
                1.0,
                0.82,
                0.25
            );

            globeColor = mix(
                globeColor,
                textColor * (
                    0.80 +
                    diffuse * 0.65
                ),
                textAlpha * 0.96
            );

            // Rim globe.
            globeColor += vec3(
                1.0,
                0.18,
                0.002
            ) *
            rim *
            1.45;

            // Globe berada di atas efek luar.
            color = mix(
                color,
                globeColor,
                mask
            );

            alpha = max(
                alpha,
                mask * GLOBE_ALPHA
            );
        }
    }

    // ==================================================
    // OUTPUT ALPHA
    // ==================================================

    float vignette =
        1.0 -
        dot(
            p,
            p
        ) *
        0.08;

    color *= max(
        vignette,
        0.0
    );

    color = pow(
        max(
            color,
            0.0
        ),
        vec3(0.90)
    );

    alpha = clamp(
        alpha,
        0.0,
        0.95
    );

    // Area kosong wajib transparan.
    if (alpha <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    // Jangan gunakan color *= alpha.
    // Alpha diserahkan ke proses compositing Flutter.
    fragColor = vec4(
        color,
        alpha
    );
}
