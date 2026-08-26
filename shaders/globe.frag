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
// BUIH NEBULA LOOPING
// --------------------------------------------------

vec3 spaceBubbles(
    vec2 p,
    float time
) {
    // p adalah koordinat yang sudah dipusatkan.
    // Ukuran grid dibuat berdasarkan tinggi layar.
    vec2 grid =
        p *
        7.5;

    vec2 baseCell =
        floor(
            grid
        );

    vec3 bubbleColor =
        vec3(
            0.0
        );

    // Beberapa lapisan agar terlihat seperti nebula
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

        float seed =
            hash2(
                cell
            );

        // Tidak semua cell memiliki buih
        float exists =
            step(
                0.72,
                seed
            );

        // Posisi acak buih di dalam cell
        vec2 randomPosition =
            vec2(
                hash2(
                    cell +
                    vec2(
                        13.1,
                        4.7
                    )
                ),
                hash2(
                    cell +
                    vec2(
                        7.3,
                        21.8
                    )
                )
            ) -
            0.5;

        // Posisi lokal cell
        vec2 localPosition =
            fract(
                grid
            ) -
            0.5;

        // Satu siklus penuh:
        // kecil -> besar -> putih -> kecil -> hilang
        float cycleLength =
            3.5 +
            hash2(
                cell +
                vec2(
                    44.2,
                    16.8
                )
            ) *
            3.0;

        float phase =
            fract(
                time /
                cycleLength +
                seed
            );

        // Gerakan perlahan ke atas
        vec2 bubblePosition =
            localPosition -
            randomPosition;

        bubblePosition.y +=
            phase *
            0.55;

        // Goyangan horizontal halus
        bubblePosition.x +=
            sin(
                phase *
                TWO_PI +
                seed *
                18.0
            ) *
            0.045;

        float distanceToBubble =
            length(
                bubblePosition
            );

        // 0 -> kecil, 1 -> besar, 0 -> mengecil
        float grow =
            sin(
                phase *
                PI
            );

        // Ukuran buih berubah selama siklus
        float bubbleSize =
            mix(
                0.018,
                0.105,
                grow
            );

        // Bentuk kabut lembut
        float bubble =
            1.0 -
            smoothstep(
                bubbleSize * 0.25,
                bubbleSize,
                distanceToBubble
            );

        // Cincin luar agar tampak seperti buih
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

        // Cahaya naik saat membesar,
        // paling terang saat fase tengah
        float brightness =
            smoothstep(
                0.04,
                0.22,
                grow
            ) *
            (
                0.20 +
                grow *
                0.80
            );

        // Membuat warna berubah selama siklus:
        // merah -> jingga -> emas -> biru kehijauan -> putih
        vec3 redColor =
            vec3(
                0.95,
                0.015,
                0.003
            );

        vec3 orangeColor =
            vec3(
                1.0,
                0.16,
                0.015
            );

        vec3 goldColor =
            vec3(
                1.0,
                0.62,
                0.045
            );

        vec3 cyanColor =
            vec3(
                0.03,
                0.80,
                0.72
            );

        vec3 whiteColor =
            vec3(
                1.0,
                0.98,
                0.90
            );

        vec3 colorPhase;

        if (
            grow < 0.25
        ) {
            colorPhase =
                mix(
                    redColor,
                    orangeColor,
                    grow /
                    0.25
                );
        } else if (
            grow < 0.50
        ) {
            colorPhase =
                mix(
                    orangeColor,
                    goldColor,
                    (
                        grow -
                        0.25
                    ) /
                    0.25
                );
        } else if (
            grow < 0.78
        ) {
            colorPhase =
                mix(
                    goldColor,
                    cyanColor,
                    (
                        grow -
                        0.50
                    ) /
                    0.28
                );
        } else {
            colorPhase =
                mix(
                    cyanColor,
                    whiteColor,
                    (
                        grow -
                        0.78
                    ) /
                    0.22
                );
        }

        // Buih utama
        bubbleColor +=
            colorPhase *
            bubble *
            brightness *
            exists *
            (
                0.45 +
                layer *
                0.18
            );

        // Lingkaran pinggir berwarna lebih terang
        bubbleColor +=
            whiteColor *
            bubbleRing *
            brightness *
            exists *
            0.85;

        // Titik pusat putih
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

        bubbleColor +=
            whiteColor *
            whiteCenter *
            brightness *
            exists *
            1.35;
    }

    return bubbleColor;
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
// PLASMA AKTIF DI DALAM GLOBE
// --------------------------------------------------

vec3 plasmaEffect(
    vec2 localUV,
    float radius,
    float time
) {
    // Posisi dari pusat globe
    float localRadius =
        length(
            localUV
        );

    float localAngle =
        atan(
            localUV.y,
            localUV.x
        );

    // Membuat bentuk plasma tidak simetris
    float distortion =
        sin(
            localAngle * 5.0 +
            time * 2.0
        ) *
        0.10;

    distortion +=
        sin(
            localAngle * 11.0 -
            time * 3.0
        ) *
        0.055;

    // Jalur plasma utama
    float ray1 =
        sin(
            localAngle * 24.0
            + distortion * 18.0
            + time * 2.5
            + localRadius * 13.0
        );

    // Jalur plasma kedua
    float ray2 =
        sin(
            localAngle * 39.0
            - distortion * 22.0
            - time * 3.2
            + localRadius * 27.0
        );

    // Jalur plasma kecil dan tajam
    float ray3 =
        sin(
            localAngle * 67.0
            + time * 4.5
            - localRadius * 42.0
        );

    // Gabungkan semua jalur
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

    // Membuat jalur menjadi lebih padat
    float sharpRays =
        smoothstep(
            0.54,
            0.88,
            plasmaRays
        );

    // Noise cabang plasma
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
            0.42,
            0.76,
            branchNoise
        );

    // Noise cabang kedua
    float branchNoise2 =
        sin(
            localAngle * 137.0
            - localRadius * 230.0
            + time * 8.0
        ) *
        0.5 +
        0.5;

    branchNoise2 =
        smoothstep(
            0.48,
            0.82,
            branchNoise2
        );

    // Plasma dibuat lebih kuat dari bagian tengah
    // menuju pinggiran globe
    float radialMask =
        smoothstep(
            0.035,
            0.18,
            localRadius
        ) *
        (
            1.0 -
            smoothstep(
                0.84,
                1.02,
                localRadius
            )
        );

    // Cabang utama
    float branches =
        sharpRays *
        (
            0.40 +
            branchNoise *
            0.75 +
            branchNoise2 *
            0.35
        ) *
        radialMask;

    // Aura plasma yang lebih lebar
    float plasmaAura =
        smoothstep(
            0.32,
            0.70,
            plasmaRays
        ) *
        radialMask *
        0.72;

    // Gelombang radial yang berdenyut
    float radialWave =
        sin(
            localRadius * 30.0
            - time * 5.5
        ) *
        0.5 +
        0.5;

    radialWave =
        smoothstep(
            0.52,
            0.88,
            radialWave
        );

    // Gelombang kedua agar plasma lebih hidup
    float radialWave2 =
        sin(
            localRadius * 58.0
            + time * 7.0
        ) *
        0.5 +
        0.5;

    radialWave2 =
        smoothstep(
            0.60,
            0.92,
            radialWave2
        );

    // Plasma membentuk spiral ringan
    float spiral =
        sin(
            localAngle * 8.0
            + localRadius * 20.0
            - time * 3.0
        ) *
        0.5 +
        0.5;

    spiral =
        smoothstep(
            0.50,
            0.86,
            spiral
        );

    // Inti plasma
    float centerCore =
        exp(
            -localRadius *
            7.5
        );

    // Titik panas di pusat
    float centerHotspot =
        exp(
            -localRadius *
            20.0
        );

    // Cincin energi di sekitar pusat
    float centerRing =
        exp(
            -abs(
                localRadius -
                0.16
            ) *
            55.0
        );

    // Warna plasma
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
            0.08,
            0.28,
            1.0
        );

    vec3 cyanColor =
        vec3(
            0.10,
            0.75,
            1.0
        );

    vec3 whiteColor =
        vec3(
            1.0,
            0.92,
            1.0
        );

    vec3 plasmaColor =
        vec3(
            0.0
        );

    // Cahaya ungu pada cabang utama
    plasmaColor +=
        purpleColor *
        branches *
        1.75;

    // Aura magenta
    plasmaColor +=
        magentaColor *
        plasmaAura *
        2.10;

    // Biru pada jalur yang berdenyut
    plasmaColor +=
        blueColor *
        branches *
        radialWave *
        2.25;

    // Cyan pada sebagian jalur
    plasmaColor +=
        cyanColor *
        branches *
        radialWave2 *
        spiral *
        1.45;

    // Cahaya ungu dari inti
    plasmaColor +=
        purpleColor *
        centerCore *
        2.2;

    // Cincin energi di sekitar inti
    plasmaColor +=
        magentaColor *
        centerRing *
        2.0;

    // Titik putih panas di pusat
    plasmaColor +=
        whiteColor *
        centerHotspot *
        4.2;

    return plasmaColor;
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

// Buih nebula berada paling belakang
color +=
    spaceBubbles(
        p,
        iTime
    ) *
    1.25;

// Bintang kecil tambahan
float stars =
    hash2(
        floor(
            p *
            110.0
        )
    );

float starMask =
    step(
        0.992,
        stars
    );

color +=
    vec3(
        0.70,
        0.85,
        1.0
    ) *
    starMask *
    0.30;


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


vec3 plasma =
    plasmaEffect(
        sphereUV,
        radius,
        iTime
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
