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
const float ATMOSPHERE_GAP = 0.025;
const float ATMOSPHERE_THICKNESS = 0.16;

// --------------------------------------------------
// RANDOM
// --------------------------------------------------

float hash1(float p) {
    return fract(
        sin(p * 127.1) * 43758.5453
    );
}

float hash2(vec2 p) {
    return fract(
        sin(dot(p, vec2(127.1, 311.7))) *
        43758.5453
    );
}

// --------------------------------------------------
// ROTASI TITIK 3D
// --------------------------------------------------

vec3 rotateXPoint(vec3 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);

    return vec3(
        p.x,
        p.y * c - p.z * s,
        p.y * s + p.z * c
    );
}

vec3 rotateYPoint(vec3 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);

    return vec3(
        p.x * c - p.z * s,
        p.y,
        p.x * s + p.z * c
    );
}

vec3 rotateZPoint(vec3 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);

    return vec3(
        p.x * c - p.y * s,
        p.x * s + p.y * c,
        p.z
    );
}

// --------------------------------------------------
// BUIH / NEBULA
// --------------------------------------------------

vec3 spaceBubbles(
    vec2 p,
    float time,
    float pulse
) {
    vec2 grid = p * 9.5;
    vec2 baseCell = floor(grid);

    vec3 result = vec3(0.0);

    for (
        float layer = 0.0;
        layer < 3.0;
        layer += 1.0
    ) {
        vec2 cell =
            baseCell +
            vec2(
                layer * 19.17,
                layer * 37.41
            );

        float seed = hash2(cell);

        float exists =
            step(0.72, seed);

        vec2 randomPosition =
            vec2(
                hash2(cell + vec2(13.1, 4.7)),
                hash2(cell + vec2(7.3, 21.8))
            ) - 0.5;

        vec2 localPosition =
            fract(grid) - 0.5;

        float cycleLength =
            3.5 +
            hash2(
                cell + vec2(44.2, 16.8)
            ) * 3.0;

        float phase =
            fract(
                time / cycleLength + seed
            );

        vec2 bubblePosition =
            localPosition -
            randomPosition;

        bubblePosition.y += phase * 0.55;

        bubblePosition.x +=
            sin(
                phase * TWO_PI +
                seed * 18.0
            ) * 0.045;

        float distanceToBubble =
            length(bubblePosition);

        float grow =
            sin(phase * PI);

        float bubbleSize =
            mix(
                0.018,
                0.105,
                grow
            );

        bubbleSize *=
            1.0 +
            pulse * 0.28;

        float bubble =
            1.0 -
            smoothstep(
                bubbleSize * 0.25,
                bubbleSize,
                distanceToBubble
            );

        float bubbleRing =
            1.0 -
            smoothstep(
                bubbleSize * 0.72,
                bubbleSize * 1.05,
                distanceToBubble
            );

        bubbleRing *=
            smoothstep(
                bubbleSize * 0.35,
                bubbleSize * 0.72,
                distanceToBubble
            );

        float brightness =
            smoothstep(
                0.04,
                0.22,
                grow
            ) *
            (
                0.20 +
                grow * 0.80
            );

        vec3 redColor =
            vec3(0.95, 0.015, 0.003);

        vec3 orangeColor =
            vec3(1.0, 0.16, 0.015);

        vec3 goldColor =
            vec3(1.0, 0.62, 0.045);

        vec3 cyanColor =
            vec3(0.03, 0.80, 0.72);

        vec3 whiteColor =
            vec3(1.0, 0.98, 0.90);

        vec3 colorPhase;

        if (grow < 0.25) {
            colorPhase =
                mix(
                    redColor,
                    orangeColor,
                    grow / 0.25
                );
        } else if (grow < 0.50) {
            colorPhase =
                mix(
                    orangeColor,
                    goldColor,
                    (grow - 0.25) / 0.25
                );
        } else if (grow < 0.78) {
            colorPhase =
                mix(
                    goldColor,
                    cyanColor,
                    (grow - 0.50) / 0.28
                );
        } else {
            colorPhase =
                mix(
                    cyanColor,
                    whiteColor,
                    (grow - 0.78) / 0.22
                );
        }

        float pulseBoost =
            1.0 +
            pulse * 0.80;

        result +=
            colorPhase *
            bubble *
            brightness *
            exists *
            (
                0.45 +
                layer * 0.18
            ) *
            pulseBoost;

        result +=
            whiteColor *
            bubbleRing *
            brightness *
            exists *
            0.85 *
            pulseBoost;

        float whiteCenter =
            1.0 -
            smoothstep(
                bubbleSize * 0.02,
                bubbleSize * 0.34,
                distanceToBubble
            );

        whiteCenter *=
            smoothstep(
                0.48,
                0.82,
                grow
            );

        result +=
            whiteColor *
            whiteCenter *
            brightness *
            exists *
            1.35 *
            pulseBoost;
    }

    return result;
}

// --------------------------------------------------
// BINTANG
// --------------------------------------------------

vec3 starLayer(
    vec2 p,
    float time
) {
    vec2 cell = floor(p * 110.0);

    float value =
        hash2(cell);

    float star =
        step(0.993, value);

    float twinkle =
        0.65 +
        0.35 *
        sin(
            time * 3.0 +
            value * 60.0
        );

    return vec3(
        0.55,
        0.75,
        1.0
    ) *
    star *
    twinkle *
    0.40;
}

// --------------------------------------------------
// ATMOSFER
// --------------------------------------------------

float globeAtmosphere(
    float radius,
    float time,
    float pulse
) {
    float distanceFromGlobe =
        radius -
        GLOBE_RADIUS;

    float startMask =
        smoothstep(
            ATMOSPHERE_GAP,
            ATMOSPHERE_GAP + 0.018,
            distanceFromGlobe
        );

    float atmosphereEnd =
        ATMOSPHERE_GAP +
        ATMOSPHERE_THICKNESS;

    float endMask =
        1.0 -
        smoothstep(
            atmosphereEnd - 0.035,
            atmosphereEnd,
            distanceFromGlobe
        );

    float shellMask =
        startMask *
        endMask;

    float distanceFromAtmosphere =
        max(
            distanceFromGlobe -
            ATMOSPHERE_GAP,
            0.0
        );

    float wideSmoke =
        exp(
            -distanceFromAtmosphere * 4.8
        );

    float denseSmoke =
        exp(
            -distanceFromAtmosphere * 16.0
        );

    float cloud1 =
        sin(
            time * 1.8 +
            radius * 17.0
        ) * 0.5 + 0.5;

    float cloud2 =
        sin(
            time * 2.7 -
            radius * 31.0
        ) * 0.5 + 0.5;

    float cloud3 =
        sin(
            time * 4.4 +
            radius * 54.0
        ) * 0.5 + 0.5;

    float noise =
        smoothstep(
            0.25,
            0.72,
            cloud1 * 0.45 +
            cloud2 * 0.32 +
            cloud3 * 0.23
        );

    float ring =
        exp(
            -abs(
                distanceFromGlobe -
                (
                    ATMOSPHERE_GAP +
                    ATMOSPHERE_THICKNESS * 0.46
                )
            ) * 55.0
        );

    float pulseBoost =
        1.0 +
        pulse * 0.55;

    float value =
        wideSmoke *
        noise *
        1.60;

    value +=
        denseSmoke *
        noise *
        1.00;

    value +=
        ring *
        0.90;

    return value *
        shellMask *
        pulseBoost;
}

// --------------------------------------------------
// PLASMA
// --------------------------------------------------

vec3 plasmaEffect(
    vec2 localUV,
    float time,
    float pulse
) {
    float radius =
        length(localUV);

    float angle =
        atan(
            localUV.y,
            localUV.x
        );

    float distortion =
        sin(
            angle * 5.0 +
            time * 2.0
        ) * 0.10;

    distortion +=
        sin(
            angle * 11.0 -
            time * 3.0
        ) * 0.055;

    float ray1 =
        sin(
            angle * 24.0 +
            distortion * 18.0 +
            time * 2.5 +
            radius * 13.0
        );

    float ray2 =
        sin(
            angle * 39.0 -
            distortion * 22.0 -
            time * 3.2 +
            radius * 27.0
        );

    float ray3 =
        sin(
            angle * 67.0 +
            time * 4.5 -
            radius * 42.0
        );

    float rays =
        ray1 * 0.48 +
        ray2 * 0.32 +
        ray3 * 0.20;

    rays =
        rays * 0.5 + 0.5;

    float sharpRays =
        smoothstep(
            0.54,
            0.88,
            rays
        );

    float branches =
        sin(
            angle * 91.0 +
            radius * 150.0 -
            time * 11.0
        ) * 0.5 + 0.5;

    branches =
        smoothstep(
            0.42,
            0.76,
            branches
        );

    float radialMask =
        smoothstep(
            0.035,
            0.18,
            radius
        ) *
        (
            1.0 -
            smoothstep(
                0.84,
                1.02,
                radius
            )
        );

    float plasmaMask =
        sharpRays *
        (
            0.45 +
            branches * 0.85
        ) *
        radialMask;

    float aura =
        smoothstep(
            0.32,
            0.70,
            rays
        ) *
        radialMask *
        0.72;

    float centerCore =
        exp(
            -radius * 7.5
        );

    float centerRing =
        exp(
            -abs(
                radius - 0.16
            ) * 55.0
        );

    float pulseBoost =
        1.0 +
        pulse * 0.60;

    vec3 purple =
        vec3(
            0.40,
            0.015,
            1.0
        );

    vec3 magenta =
        vec3(
            1.0,
            0.025,
            0.55
        );

    vec3 blue =
        vec3(
            0.08,
            0.28,
            1.0
        );

    vec3 cyan =
        vec3(
            0.10,
            0.75,
            1.0
        );

    vec3 white =
        vec3(
            1.0,
            0.92,
            1.0
        );

    vec3 result =
        vec3(0.0);

    result +=
        purple *
        plasmaMask *
        1.75;

    result +=
        magenta *
        aura *
        2.10;

    result +=
        blue *
        plasmaMask *
        1.35;

    result +=
        purple *
        centerCore *
        2.20;

    result +=
        magenta *
        centerRing *
        2.00;

    result +=
        white *
        exp(-radius * 20.0) *
        4.20;

    return result *
        pulseBoost;
}

// --------------------------------------------------
// PETIR
// --------------------------------------------------

float wrappingLightning(
    float angle,
    float radius,
    float time,
    float pulse
) {
    float distanceFromGlobe =
        radius -
        GLOBE_RADIUS;

    float vortexArea =
        smoothstep(
            -0.025,
            0.015,
            distanceFromGlobe
        ) *
        (
            1.0 -
            smoothstep(
                0.24,
                0.52,
                distanceFromGlobe
            )
        );

    float total =
        0.0;

    for (
        float i = 0.0;
        i < 8.0;
        i += 1.0
    ) {
        float seed =
            i * 19.731;

        float speed =
            0.45 +
            i * 0.085;

        float strikeId =
            floor(
                time * speed +
                seed
            );

        float chance =
            hash1(
                strikeId +
                seed
            );

        if (chance > 0.28) {
            float baseAngle =
                hash1(
                    strikeId +
                    seed +
                    4.0
                ) *
                TWO_PI;

            float phase =
                fract(
                    time * speed +
                    seed
                );

            float pulseShape =
                exp(
                    -phase * 8.5
                );

            float spiralAngle =
                angle +
                distanceFromGlobe * 28.0 -
                time * 2.2 +
                baseAngle;

            float distortion =
                sin(
                    radius * 125.0 +
                    time * 18.0 +
                    seed
                ) * 0.05;

            float path =
                abs(
                    sin(
                        (
                            spiralAngle +
                            distortion
                        ) * 0.5
                    )
                );

            float core =
                smoothstep(
                    0.022,
                    0.0,
                    path
                );

            float aura =
                smoothstep(
                    0.075,
                    0.0,
                    path
                );

            total +=
                (
                    core * 4.5 +
                    aura * 1.2
                ) *
                vortexArea *
                pulseShape;
        }
    }

    return total *
        (
            1.0 +
            pulse * 0.35
        );
}

// --------------------------------------------------
// MAIN
// --------------------------------------------------

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

    vec2 center =
        vec2(
            0.0,
            0.12
        );

    vec2 delta =
        p -
        center;

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

    // Warna awal.
    vec3 color =
        vec3(0.0);

    float alpha =
        0.0;

    // --------------------------------------------------
    // BUIH
    // --------------------------------------------------

    vec3 bubbles =
        spaceBubbles(
            p,
            iTime,
            pulse
        ) *
        1.8;

    float bubbleIntensity =
        max(
            bubbles.r,
            max(
                bubbles.g,
                bubbles.b
            )
        );

    float bubbleAlpha =
        smoothstep(
            0.015,
            0.20,
            bubbleIntensity
        ) *
        0.65;

    color +=
        bubbles;

    alpha =
        max(
            alpha,
            bubbleAlpha
        );

    // --------------------------------------------------
    // BINTANG
    // --------------------------------------------------

    vec3 stars =
        starLayer(
            p,
            iTime
        );

    float starIntensity =
        max(
            stars.r,
            max(
                stars.g,
                stars.b
            )
        );

    color +=
        stars;

    alpha =
        max(
            alpha,
            step(
                0.01,
                starIntensity
            ) *
            0.75
        );

    // --------------------------------------------------
    // ATMOSFER
    // --------------------------------------------------

    float atmosphere =
        globeAtmosphere(
            radius,
            iTime,
            pulse
        );

    float lowerBowl =
        1.0 -
        smoothstep(
            -0.18,
            0.35,
            delta.y
        );

    vec3 blueAtmosphere =
        vec3(
            0.015,
            0.32,
            1.0
        );

    vec3 orangeAtmosphere =
        vec3(
            1.0,
            0.16,
            0.008
        );

    vec3 atmosphereColor =
        mix(
            blueAtmosphere,
            orangeAtmosphere,
            lowerBowl
        );

    color +=
        atmosphereColor *
        atmosphere *
        glow *
        1.45;

    float atmosphereAlpha =
        smoothstep(
            0.01,
            0.18,
            atmosphere
        ) *
        0.82;

    alpha =
        max(
            alpha,
            atmosphereAlpha
        );

    // --------------------------------------------------
    // PETIR
    // --------------------------------------------------

    float bolt =
        wrappingLightning(
            angle,
            radius,
            iTime,
            pulse
        );

    vec3 boltColor =
        vec3(
            1.0,
            0.20,
            0.01
        ) *
        bolt *
        2.5;

    color +=
        boltColor;

    alpha =
        max(
            alpha,
            smoothstep(
                0.01,
                0.25,
                bolt
            ) *
            0.85
        );

    // --------------------------------------------------
    // GLOBE 3D
    // --------------------------------------------------

    float globeMask =
        1.0 -
        smoothstep(
            GLOBE_RADIUS - 0.008,
            GLOBE_RADIUS + 0.008,
            radius
        );

    if (radius < GLOBE_RADIUS) {
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

            vec3 point =
                vec3(
                    sphereUV.x,
                    sphereUV.y,
                    z
                );

            // Rotasi gesture.
            point =
                rotateYPoint(
                    point,
                    rotY
                );

            point =
                rotateXPoint(
                    point,
                    rotX
                );

            point =
                rotateZPoint(
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
                    0.0,
                    dot(
                        normal,
                        lightDirection
                    )
                );

            float frontLight =
                smoothstep(
                    -0.20,
                    0.70,
                    normal.z
                );

            float rim =
                pow(
                    1.0 -
                    max(
                        0.0,
                        normal.z
                    ),
                    3.0
                );

            vec3 darkGold =
                vec3(
                    0.055,
                    0.006,
                    0.001
                );

            vec3 gold =
                vec3(
                    0.40,
                    0.075,
                    0.003
                );

            vec3 brightGold =
                vec3(
                    1.0,
                    0.58,
                    0.045
                );

            vec3 globeColor =
                mix(
                    darkGold,
                    gold,
                    diffuse
                );

            globeColor =
                mix(
                    globeColor,
                    brightGold,
                    diffuse *
                    frontLight *
                    0.82
                );

            // Plasma mengikuti area permukaan globe.
            vec3 plasma =
                plasmaEffect(
                    sphereUV,
                    iTime,
                    pulse
                );

            globeColor +=
                plasma *
                frontLight *
                0.75;

            // Tekstur BABE.INFO.
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

            vec2 textUV =
                vec2(
                    longitude /
                    TWO_PI +
                    0.5,

                    latitude /
                    PI +
                    0.5
                );

            textUV.x =
                fract(
                    textUV.x -
                    windRot * 0.04
                );

            textUV.y =
                clamp(
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

            vec3 textColor =
                vec3(
                    1.0,
                    0.82,
                    0.25
                );

            globeColor =
                mix(
                    globeColor,
                    textColor *
                    (
                        0.80 +
                        diffuse * 0.65
                    ),
                    textAlpha *
                    0.96
                );

            // Rim globe.
            globeColor +=
                vec3(
                    1.0,
                    0.18,
                    0.002
                ) *
                rim *
                1.55;

            // Globe berada di atas efek luar.
            color =
                mix(
                    color,
                    globeColor,
                    globeMask
                );

            alpha =
                max(
                    alpha,
                    globeMask *
                    0.92
                );
        }
    }

    // --------------------------------------------------
    // VIGNETTE
    // --------------------------------------------------

    float vignette =
        1.0 -
        dot(
            p,
            p
        ) *
        0.16;

    color *=
        max(
            vignette,
            0.0
        );

    color =
        pow(
            max(
                color,
                0.0
            ),
            vec3(
                0.86
            )
        );

    alpha =
        clamp(
            alpha,
            0.0,
            1.0
        );

    // Sangat penting:
    // RGB dikalikan alpha agar area transparan
    // benar-benar tidak menutupi bg.png.
    color *=
        alpha;

    fragColor =
        vec4(
            color,
            alpha
        );
}
