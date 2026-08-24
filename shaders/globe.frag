#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution;
uniform float iTime;
uniform float rotX;
uniform float rotY;
uniform float glow;

out vec4 fragColor;

#define PI 3.14159265359

mat2 rot2D(float a){ float c=cos(a), s=sin(a); return mat2(c,-s,s,c); }

void main(){
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;

    vec2 center = vec2(0.0, -0.05);
    vec2 d = p - center;
    float r = length(d);
    float ang = atan(d.y, d.x);

    vec3 col = vec3(0.0);

    // === BLACKHOLE ACCRETION DISK ===
    float diskR = r;
    float diskAng = ang + iTime * 0.25 + diskR * 0.8;
    float spiral = sin(diskAng * 3.0 + diskR * 6.0 - iTime * 1.2) * 0.5 + 0.5;
    
    float horizonOuter = smoothstep(1.4, 0.9, diskR);
    float horizonInner = smoothstep(0.35, 0.55, diskR);
    float horizon = horizonOuter * horizonInner;

    vec3 gold1 = vec3(1.0, 0.97, 0.65);
    vec3 gold2 = vec3(1.0, 0.84, 0.0);
    vec3 gold3 = vec3(0.8, 0.55, 0.05);

    vec3 diskCol = mix(gold3, gold2, spiral);
    diskCol = mix(diskCol, gold1, pow(spiral, 2.0));
    diskCol *= horizon * (1.8 + glow);

    // Anamorphic stretch buat disk
    float diskFlatten = 0.22;
    vec2 diskUV = d; diskUV.y /= diskFlatten;
    float diskR2 = length(diskUV);
    float diskMask = smoothstep(1.5, 1.2, diskR2) * smoothstep(0.5, 0.7, diskR2);
    diskCol *= diskMask;

    col += diskCol;

    // Event horizon glow
    float eh = smoothstep(0.58, 0.52, r) * smoothstep(0.38, 0.45, r);
    col += gold1 * eh * 1.8;

    // === GLOBE EMAS 3D ===
    float globeRadius = 0.62;
    float globeDist = r;

    if(globeDist < globeRadius){
        // Sphere mapping
        vec2 sphereUV = d / globeRadius;
        float z = sqrt(max(0.0, 1.0 - dot(sphereUV, sphereUV)));
        vec3 normal = vec3(sphereUV, z);

        // Rotate globe
        float ry = rotY + iTime * 0.35;
        float rx = rotX * 0.5;
        normal.xz = rot2D(ry) * normal.xz;
        normal.yz = rot2D(rx) * normal.yz;

        float lon = atan(normal.z, normal.x);
        float lat = asin(normal.y);

        // Gold base
        vec3 base = mix(gold3, gold2, 0.5 + 0.5 * sin(lat * 3.0));
        base = mix(base, gold1, pow(max(0.0, dot(normal, vec3(-0.4,-0.4,0.8))), 2.0));

        // Longitude lines rotating
        float lines = 0.0;
        for(float i=0.0; i<12.0; i++){
            float l = lon + i * PI / 6.0;
            lines += smoothstep(0.02, 0.0, abs(sin(l * 1.0)));
        }
        lines *= 0.18;
        
        float latLines = 0.0;
        for(float i=-2.0; i<=2.0; i++){
            latLines += smoothstep(0.03, 0.0, abs(lat - i * 0.52));
        }
        latLines *= 0.15;

        base -= (lines + latLines) * 0.6;

        // Shading
        float diff = max(0.0, dot(normal, normalize(vec3(-0.6,-0.5,0.8))));
        float spec = pow(max(0.0, dot(reflect(vec3(0.0,0.0,-1.0), normal), normalize(vec3(-0.5,-0.5,0.8)))), 32.0);

        vec3 globeCol = base * (0.6 + diff * 0.8) + spec * 0.6;

        // Lensing di pinggir globe
        float fresnel = pow(1.0 - max(0.0, dot(normal, vec3(0.0,0.0,1.0))), 3.0);
        globeCol += gold2 * fresnel * 0.6;

        // Shadow blackhole di globe
        float shadow = 1.0 - smoothstep(0.3, 0.9, globeDist / globeRadius);
        globeCol *= 0.85 + shadow * 0.15;

        col = mix(col, globeCol, smoothstep(globeRadius+0.02, globeRadius-0.01, globeDist));
        
        // Outer glow globe
        float glowRing = smoothstep(0.05, 0.0, abs(globeDist - globeRadius));
        col += gold2 * glowRing * 0.35;
    }

    // Stars
    vec2 starUV = uv * 80.0;
    float stars = step(0.998, sin(starUV.x + iTime*0.1) * sin(starUV.y));
    col += stars * (1.0 - horizon) * 0.5;

    // Vignette luxury
    float vign = 1.0 - dot(p, p) * 0.22;
    col *= vign;

    fragColor = vec4(col, 1.0);
}