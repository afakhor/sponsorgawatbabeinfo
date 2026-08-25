#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution;
uniform float iTime;
uniform float rotY;
uniform float windRot;
uniform float glow;

uniform sampler2D textTexture;

out vec4 fragColor;

const float PI = 3.14159265359;
const float TWO_PI = 6.28318530718;

// --------------------------------------------------
// RANDOM
// --------------------------------------------------

float hash1(float p) {
    return fract(
        sin(p * 127.1) *
        43758.5453
    );
}

float hash2(vec2 p) {
    return fract(
        sin(dot(p, vec2(127.1, 311.7))) *
        43758.5453
    );
}

float angularDistance(float a, float b) {
    float d = abs(a - b);
    return min(d, TWO_PI - d);
}

// --------------------------------------------------
// PETIR YANG MENYELIMUTI GLOBE
// --------------------------------------------------

float wrappingLightning(
    float angle,
    float radius,
    float time
) {
    const float globeRadius =
        0.32;

    float total =
        0.0;

    float distanceFromGlobe =
        radius -
        globeRadius;

    // Area pusaran dari permukaan sampai ke luar globe
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

    // Arah gerakan pusaran
    float vortexTime =
        -time * 2.2;

    // Radius memengaruhi posisi sudut.
    // Ini yang membuat garis menjadi spiral.
    float spiralAngle =
        angle
        + distanceFromGlobe * 28.0
        - vortexTime;

    for (float i = 0.0; i < 9.0; i += 1.0) {
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

            float pulsePhase =
                fract(
                    time * speed +
                    seed
                );

            // Kilatan dimulai dari luar,
            // lalu terasa tersedot ke arah globe
            float suction =
                1.0 -
                smoothstep(
                    0.0,
                    1.0,
                    pulsePhase
                );

            float pulse =
                exp(
                    -pulsePhase *
                    8.5
                );

            // Gangguan zig-zag pada jalur spiral
            float distortion =
                sin(
                    radius * 125.0 +
                    time * 18.0 +
                    seed
                ) *
                0.050
              + sin(
                    radius * 240.0 -
                    time * 27.0 +
                    seed * 1.7
                ) *
                0.028
              + sin(
                    radius * 410.0 +
                    time * 41.0 +
                    seed * 2.4
                ) *
                0.014;

            // Setiap petir memiliki spiral yang sedikit berbeda
            float localSpiralAngle =
                spiralAngle
                + baseAngle
                + distortion
                + suction *
                0.35;

            // Jarak sudut dari jalur spiral
            float pathDistance =
                abs(
                    sin(
                        (
                            localSpiralAngle
                        ) *
                        0.5
                    )
                );

            // Jalur utama spiral
            float mainPath =
                smoothstep(
                    0.075,
                    0.0,
                    pathDistance
                );

            // Garis inti yang sangat tipis
            float core =
                smoothstep(
                    0.022,
                    0.0,
                    pathDistance
                );

            // Cabang-cabang listrik
            float branchWave1 =
                sin(
                    angle * 42.0 +
                    radius * 170.0 +
                    seed -
                    time * 5.0
                ) *
                0.5 +
                0.5;

            float branchWave2 =
                sin(
                    angle * 71.0 -
                    radius * 280.0 +
                    seed * 2.0 +
                    time * 7.0
                ) *
                0.5 +
                0.5;

            float branches =
                pow(
                    branchWave1,
                    18.0
                ) *
                mainPath *
                1.4;

            branches +=
                pow(
                    branchWave2,
                    24.0
                ) *
                mainPath *
                1.0;

            // Efek penarikan menuju permukaan globe
            float suctionMask =
                exp(
                    -abs(
                        distanceFromGlobe
                    ) *
                    18.0
                );

            // Jalur listrik luar
            float outerPath =
                mainPath *
                vortexArea *
                (
                    0.45 +
                    suctionMask *
                    1.8
                );

            // Inti listrik
            float electricCore =
                core *
                vortexArea *
                suction *
                4.5;

            // Aura besar di sekeliling jalur
            float electricAura =
                mainPath *
                vortexArea *
                1.2;

            total +=
                (
                    electricCore +
                    electricAura +
                    branches *
                    0.8 +
                    outerPath
                ) *
                pulse;
        }
    }

    // Pita spiral tambahan agar pusaran lebih penuh
    float broadSpiral =
        sin(
            angle * 11.0 +
            distanceFromGlobe * 38.0 -
            time * 4.0
        ) *
        0.5 +
        0.5;

    broadSpiral =
        smoothstep(
            0.62,
            0.90,
            broadSpiral
        );

    broadSpiral *=
        vortexArea *
        exp(
            -max(
                distanceFromGlobe,
                0.0
            ) *
            5.5
        );

    total +=
        broadSpiral *
        1.35;

    // Cincin kuat di bibir globe,
    // seperti pusaran sedang menelan permukaan
    float globeRim =
        exp(
            -abs(
                distanceFromGlobe
            ) *
            145.0
        );

    total +=
        globeRim *
        1.4;

    return total;
}


// --------------------------------------------------
// ATMOSFER BERLAWANAN ARAH DENGAN GLOBE
// --------------------------------------------------

float globeAtmosphere(
    float radius,
    float angle,
    float time
) {
    float globeRadius =
        0.32;

    float distanceFromGlobe =
        radius -
        globeRadius;

    // Atmosfer melebar ke segala arah
    float wideSmoke =
        exp(
            -max(
                distanceFromGlobe,
                0.0
            ) *
            9.5
        );

    // Asap padat dekat permukaan
    float denseSmoke =
        exp(
            -abs(
                distanceFromGlobe
            ) *
            23.0
        );

    // Gumpalan asap besar
    float cloud1 =
        sin(
            angle * 3.0 +
            time * 1.8 +
            radius * 17.0
        ) *
        0.5 +
        0.5;

    float cloud2 =
        sin(
            angle * 6.0 -
            time * 2.7 +
            radius * 31.0
        ) *
        0.5 +
        0.5;

    float cloud3 =
        sin(
            angle * 11.0 +
            time * 4.4 -
            radius * 54.0
        ) *
        0.5 +
        0.5;

    float cloud4 =
        sin(
            angle * 19.0 -
            time * 6.2 +
            radius * 83.0
        ) *
        0.5 +
        0.5;

    // Noise asap bertingkat
    float smokeNoise =
        cloud1 * 0.40 +
        cloud2 * 0.28 +
        cloud3 * 0.20 +
        cloud4 * 0.12;

    smokeNoise =
        smoothstep(
            0.28,
            0.76,
            smokeNoise
        );

    // Asap lebih padat dan menyatu
    float packedSmoke =
        wideSmoke *
        smokeNoise;

    // Lapisan asap kedua agar atmosfer tidak kosong
    float secondarySmoke =
        denseSmoke *
        smoothstep(
            0.22,
            0.72,
            cloud1 * 0.65 +
            cloud2 * 0.35
        );

    // Ring atmosfer lembut
    float softRing =
        exp(
            -abs(
                radius -
                0.335
            ) *
            90.0
        );

    // Batas penyebaran atmosfer
    float spreadMask =
        1.0 -
        smoothstep(
            0.40,
            0.62,
            radius
        );

    return (
        packedSmoke *
        1.70
        +
        secondarySmoke *
        1.10
        +
        softRing *
        0.85
    ) *
    spreadMask;
}


// --------------------------------------------------
// FLASH GLOBAL
// --------------------------------------------------

float lightningFlash(float time) {
    float flash = 0.0;

    for (float i = 0.0; i < 8.0; i += 1.0) {
        float speed =
            0.55 +
            i * 0.19;

        float id =
            floor(
                time * speed +
                i * 13.17
            );

        float randomValue =
            hash1(
                id +
                i * 3.71
            );

        if (randomValue > 0.63) {
            float phase =
                fract(
                    time * speed +
                    i * 13.17
                );

            flash +=
                exp(
                    -phase * 28.0
                ) *
                (
                    randomValue -
                    0.63
                ) *
                7.0;
        }
    }

    return flash;
}

// --------------------------------------------------
// PLASMA RADIAL GLOBE
// --------------------------------------------------

float plasmaNoise(
    float value
) {
    return sin(value) * 0.5 + 0.5;
}

vec3 plasmaEffect(
    vec2 localUV,
    float radius,
    float time
) {
    // localUV berada pada area -1.0 sampai 1.0
    float localRadius =
        length(localUV);

    float localAngle =
        atan(
            localUV.y,
            localUV.x
        );

    // Banyak jalur plasma radial
    float ray1 =
        sin(
            localAngle * 24.0
            + sin(localAngle * 5.0 + time * 2.0) * 1.4
            + time * 2.5
            + localRadius * 13.0
        );

    float ray2 =
        sin(
            localAngle * 39.0
            - sin(localAngle * 8.0 - time * 2.8) * 1.0
            - time * 3.2
            + localRadius * 27.0
        );

    float ray3 =
        sin(
            localAngle * 67.0
            + time * 4.5
            - localRadius * 42.0
        );

    // Gabungan cabang plasma
    float plasmaRays =
        ray1 * 0.48
        +
        ray2 * 0.32
        +
        ray3 * 0.20;

    plasmaRays =
        plasmaRays *
        0.5 +
        0.5;

    // Menjadikan sinyal seperti garis tipis
    float sharpRays =
        smoothstep(
            0.60,
            0.93,
            plasmaRays
        );

    // Gangguan zig-zag sepanjang cabang
    float branchNoise =
        sin(
            localAngle * 91.0
            + localRadius * 150.0
            - time * 11.0
        ) *
        0.5 +
        0.5;

    branchNoise =
        smoothstep(
            0.48,
            0.78,
            branchNoise
        );

    // Plasma lebih tipis di pusat dan lebih jelas
    // ketika menjalar keluar
    float radialMask =
        smoothstep(
            0.10,
            0.28,
            localRadius
        ) *
        (
            1.0 -
            smoothstep(
                0.88,
                1.02,
                localRadius
            )
        );

    // Cahaya cabang utama
    float branches =
        sharpRays *
        (
            0.35 +
            branchNoise * 0.85
        ) *
        radialMask;

    // Aura plasma yang lebih lebar
    float plasmaAura =
        smoothstep(
            0.38,
            0.68,
            plasmaRays
        ) *
        radialMask *
        0.55;

    // Cahaya radial tipis seperti jalur listrik
    float radialWave =
        sin(
            localRadius * 26.0
            - time * 5.0
        ) *
        0.5 +
        0.5;

    radialWave =
        smoothstep(
            0.62,
            0.92,
            radialWave
        );

    // Inti plasma di tengah
    float centerCore =
        exp(
            -localRadius *
            7.5
        );

    float centerHotspot =
        exp(
            -localRadius *
            20.0
        );

    vec3 purpleColor =
        vec3(
            0.40,
            0.015,
            1.0
        );

    vec3 magentaColor =
        vec3(
            1.0,
            0.025,
            0.55
        );

    vec3 blueColor =
        vec3(
            0.10,
            0.30,
            1.0
        );

    vec3 whiteColor =
        vec3(
            1.0,
            0.92,
            1.0
        );

    vec3 plasmaColor =
        purpleColor *
        branches *
        1.6;

    plasmaColor +=
        magentaColor *
        plasmaAura *
        1.8;

    plasmaColor +=
        blueColor *
        branches *
        radialWave *
        2.2;

    plasmaColor +=
        purpleColor *
        centerCore *
        2.0;

    plasmaColor +=
        whiteColor *
        centerHotspot *
        3.2;

    return plasmaColor;
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

    // Koreksi aspect ratio
    p.x *=
        iResolution.x /
        iResolution.y;

    // Posisi globe
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

    float globeR =
        0.32;

    // --------------------------------------------------
    // BACKGROUND
    // --------------------------------------------------

    vec3 color =
        vec3(
            0.001,
            0.0015,
            0.003
        );

    // Partikel kecil di background
    float stars =
        hash2(
            floor(
                p * 110.0
            )
        );

    float starMask =
        step(
            0.985,
            stars
        );

    color +=
        vec3(
            1.0,
            0.40,
            0.05
        ) *
        starMask *
        0.45;

    // --------------------------------------------------
    // ATMOSFER LUAR
    // --------------------------------------------------

    float atmosphere =
        globeAtmosphere(
            radius,
            angle,
            iTime
        );

    vec3 atmosphereColor =
    vec3(
        1.0,
        0.24,
        0.008
    );

color +=
    atmosphereColor *
    atmosphere *
    glow *
    1.45;


    // --------------------------------------------------
    // PETIR DI LUAR GLOBE
    // --------------------------------------------------

    float bolt =
        wrappingLightning(
            angle,
            radius,
            iTime
        );

    vec3 boltAura =
    vec3(
        1.0,
        0.10,
        0.001
    ) *
    bolt *
    2.2;

vec3 boltCore =
    vec3(
        1.0,
        0.88,
        0.40
    ) *
    pow(
        max(
            bolt,
            0.0
        ),
        1.25
    ) *
    5.5;

color +=
    boltAura;

color +=
    boltCore;

float vortexCenter =
    exp(
        -radius *
        7.0
    ) *
    smoothstep(
        0.32,
        0.0,
        radius
    );

color +=
    vec3(
        1.0,
        0.16,
        0.002
    ) *
    vortexCenter *
    0.22;


    // Kilatan global
    float flash =
        lightningFlash(
            iTime
        );

    color +=
        vec3(
            1.0,
            0.38,
            0.025
        ) *
        flash *
        0.22;

    // --------------------------------------------------
    // PERMUKAAN GLOBE 3D
    // --------------------------------------------------

   if (radius < globeR) {
    vec2 sphereUV =
        delta /
        globeR;

    float zSquared =
        1.0 -
        dot(
            sphereUV,
            sphereUV
        );

    if (zSquared > 0.0) {
        float z =
            sqrt(
                zSquared
            );

        float c =
            cos(
                rotY
            );

        float s =
            sin(
                rotY
            );

        vec2 rotatedXZ =
            vec2(
                sphereUV.x * c -
                z * s,

                sphereUV.x * s +
                z * c
            );

        vec3 normal =
            normalize(
                vec3(
                    rotatedXZ.x,
                    sphereUV.y,
                    rotatedXZ.y
                )
            );

        // ------------------------------------------
        // LIGHTING
        // ------------------------------------------

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

        // ------------------------------------------
        // WARNA DASAR GLOBE
        // ------------------------------------------

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

        // ------------------------------------------
        // PLASMA GLOBE
        // ------------------------------------------

        vec3 plasma =
            plasmaEffect(
                sphereUV,
                radius,
                iTime
            );

        float plasmaVisibility =
            smoothstep(
                -0.20,
                0.60,
                normal.z
            );

        globeColor +=
            plasma *
            plasmaVisibility *
            0.75;

        // ------------------------------------------
        // INTI PLASMA DI TENGAH
        // ------------------------------------------

        float centerDistance =
            length(
                sphereUV
            );

        float centerOrb =
            exp(
                -centerDistance *
                15.0
            );

        float centerOrbRing =
            exp(
                -abs(
                    centerDistance -
                    0.13
                ) *
                70.0
            );

        vec3 centerOrbColor =
            vec3(
                1.0,
                0.04,
                0.60
            ) *
            centerOrb *
            2.4;

        centerOrbColor +=
            vec3(
                0.20,
                0.50,
                1.0
            ) *
            centerOrbRing *
            1.7;

        globeColor +=
            centerOrbColor *
            plasmaVisibility;

        // ------------------------------------------
        // TEXTURE BABE.INFO
        // ------------------------------------------

        float longitude =
            atan(
                rotatedXZ.x,
                rotatedXZ.y
            );

        float latitude =
            asin(
                clamp(
                    normal.y,
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
                windRot *
                0.04
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

        float textLight =
            0.80 +
            diffuse *
            0.65;

        globeColor =
            mix(
                globeColor,
                textColor *
                textLight,
                textAlpha *
                0.96
            );

        // ------------------------------------------
        // PETIR PADA PERMUKAAN
        // ------------------------------------------

        globeColor +=
            vec3(
                1.0,
                0.20,
                0.005
            ) *
            bolt *
            0.30;

        globeColor +=
            vec3(
                1.0,
                0.72,
                0.16
            ) *
            flash *
            0.48;

        // Rim globe
        globeColor +=
            vec3(
                1.0,
                0.18,
                0.002
            ) *
            rim *
            1.55;

        color =
            globeColor;
    }
}


    // --------------------------------------------------
    // VIGNETTE DAN COLOR GRADING
    // --------------------------------------------------

    float vignette =
        1.0 -
        dot(
            p,
            p
        ) *
        0.20;

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

    fragColor =
        vec4(
            color,
            1.0
        );
}
