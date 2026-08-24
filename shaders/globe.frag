#version 460 core
#include <flutter/runtime_effect.gl>

uniform vec2 uResolution; // ukuran layar
uniform float uTime;      // waktu untuk animasi topan
uniform float uRotX;      // geser atas bawah
uniform float uRotY;      // geser kiri kanan
uniform vec3 uGoldColor;  // warna emas

out vec4 fragColor;

// Noise untuk urat marmer
float noise(vec2 p){
    return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453);
}

// Sphere mapping real 3D
vec3 sphereMap(vec2 uv, float rotX, float rotY){
    vec2 p = uv * 2.0 - 1.0;
    float r = length(p);
    if(r > 1.0) return vec3(0.0);
    
    // Real 3D sphere math
    float z = sqrt(1.0 - r*r);
    vec3 pos = vec3(p.x, p.y, z);
    
    // Rotasi 3D real pakai matrix
    float cosY = cos(rotY), sinY = sin(rotY);
    float cosX = cos(rotX), sinX = sin(rotX);
    
    // Yaw
    float x1 = pos.x * cosY - pos.z * sinY;
    float z1 = pos.x * sinY + pos.z * cosY;
    // Pitch
    float y1 = pos.y * cosX - z1 * sinX;
    float z2 = pos.y * sinX + z1 * cosX;
    
    return vec3(x1, y1, z2);
}

void main(){
    vec2 uv = FlutterFragCoord().xy / uResolution.xy;
    vec2 centered = uv * 2.0 - 1.0;
    centered.x *= uResolution.x / uResolution.y;
    
    vec3 sphere = sphereMap(uv, uRotX, uRotY);
    float dist = length(centered);
    
    vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
    
    // Background marmer hitam emas + topan bergerak
    float marble = noise(uv * 5.0 + uTime * 0.05);
    float goldVein = smoothstep(0.4, 0.6, sin(uv.x * 10.0 + uv.y * 8.0 + uTime * 0.3) * 0.5 + 0.5);
    vec3 bg = mix(vec3(0.02), vec3(0.1, 0.08, 0.02), marble);
    bg += vec3(0.8, 0.6, 0.1) * goldVein * 0.3;
    
    // Angin topan emas mengelilingi
    float angle = atan(centered.y, centered.x);
    float radius = length(centered);
    float vortex = sin(angle * 3.0 + radius * 5.0 - uTime * 2.0) * 0.5 + 0.5;
    float vortexRing = smoothstep(0.4, 0.5, radius) * smoothstep(0.8, 0.7, radius);
    bg += vec3(1.0, 0.8, 0.2) * vortex * vortexRing * 0.6;
    
    color.rgb = bg;
    
    // Globe emas 3D real
    if(sphere != vec3(0.0)){
        // Shading 3D real
        float light = dot(sphere, normalize(vec3(-0.3, -0.4, 1.0))) * 0.5 + 0.5;
        vec3 gold = uGoldColor * light;
        gold += vec3(1.0, 0.9, 0.5) * pow(light, 8.0) * 0.8; // glossy
        
        // BABE.INFO texture di globe - pakai math bukan image!
        float lat = asin(sphere.y);
        float lon = atan(sphere.x, sphere.z);
        float textPattern = sin(lon * 8.0 + uTime * 0.2) * cos(lat * 6.0);
        float babeText = smoothstep(0.3, 0.4, textPattern) * 0.15;
        gold += vec3(0.1) * babeText;
        
        // Akar berduri hitam
        float thorn = sin(lon * 12.0 + lat * 8.0 + uTime * 0.1) * 0.5 + 0.5;
        thorn = smoothstep(0.7, 0.8, thorn);
        gold = mix(gold, vec3(0.0), thorn * 0.9);
        
        // Depth + glow
        float edge = 1.0 - sphere.z;
        gold += vec3(1.0, 0.8, 0.2) * pow(edge, 3.0) * 0.5;
        
        color.rgb = gold;
        color.a = 1.0;
    }
    
    // BABE.INFO text bawah (biar gak ketutupan!)
    float textY = 0.75; // posisi text di bawah
    float textDist = abs(uv.y - textY);
    if(textDist < 0.08 && abs(uv.x - 0.5) < 0.35){
        // Gold text effect
        float shine = sin((uv.x - 0.5) * 20.0 - uTime * 3.0) * 0.5 + 0.5;
        vec3 textGold = vec3(1.0, 0.84, 0.0) + vec3(0.3) * shine;
        float textAlpha = smoothstep(0.08, 0.02, textDist);
        color.rgb = mix(color.rgb, textGold, textAlpha);
    }
    
    // Border emas
    float border = smoothstep(0.9, 0.91, dist) * smoothstep(1.1, 1.0, dist);
    color.rgb += vec3(1.0, 0.84, 0.0) * border * 0.8;
    
    fragColor = color;
}