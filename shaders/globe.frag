#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution;
uniform float iTime;
uniform float rotX;
uniform float rotY;
uniform float zoom;
uniform float glow;
uniform float base;

out vec4 fragColor;

#define PI 3.14159265359

// Blackhole Atmosphere + Golden Globe Gawat
vec3 blackhole(vec2 uv, float t){
    vec2 c = uv - 0.5;
    float r = length(c) * 2.0;
    float ang = atan(c.y, c.x) + t*0.15 + r*0.6;
    
    // Pusaran blackhole
    float spiral = sin(ang*3.0 + r*6.0 - t*1.5) * 0.5 + 0.5;
    float hole = smoothstep(0.5, 0.15, r) * smoothstep(0.0, 0.3, r);
    
    // Gold atmosphere
    vec3 gold1 = vec3(1.0, 0.95, 0.6);
    vec3 gold2 = vec3(0.83, 0.68, 0.21);
    vec3 gold3 = vec3(0.72, 0.53, 0.04);
    
    vec3 col = mix(gold3, gold2, spiral);
    col = mix(col, gold1, sin(r*10.0 - t*2.0)*0.5+0.5);
    col *= hole;
    col += vec3(1.0,0.84,0.0) * pow(hole, 2.0) * 1.5 * glow;
    
    // Event horizon glow
    float horizon = smoothstep(0.35, 0.3, r) * smoothstep(0.15, 0.25, r);
    col += gold1 * horizon * 2.0;
    
    // Stars background
    float stars = step(0.995, sin(uv.x*200.0)*sin(uv.y*200.0 + t));
    col += stars * (1.0 - hole) * 0.8;
    
    return col;
}

void main(){
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / iResolution.xy;
    
    // Fix aspect
    float aspect = iResolution.x / iResolution.y;
    uv.x *= aspect;
    uv.x -= (aspect - 1.0) * 0.5;
    
    // Rotate
    uv -= 0.5;
    float rx = rotX * 0.5;
    float ry = rotY * 0.5;
    mat2 rotXMat = mat2(cos(rx), -sin(rx), sin(rx), cos(rx));
    mat2 rotYMat = mat2(cos(ry), -sin(ry), sin(ry), cos(ry));
    uv = rotXMat * uv;
    uv = rotYMat * uv;
    uv += 0.5;
    
    vec3 col = blackhole(uv, iTime);
    
    // Vignette luxury
    float vign = 1.0 - length((fragCoord / iResolution.xy - 0.5) * 0.6);
    vign = pow(vign, 1.2);
    col *= vign;
    
    // Gold tint
    col = mix(col, col * vec3(1.1, 0.95, 0.5), 0.2);
    
    fragColor = vec4(col, 1.0);
}