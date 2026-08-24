#version 460 core
#include <flutter/runtime_effect.gl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uRotX;
uniform float uRotY;
uniform vec3 uGoldColor;
out vec4 fragColor;

float noise(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }

void main(){
    vec2 uv = FlutterFragCoord().xy / uResolution.xy;
    vec2 c = uv*2.0-1.0; c.x*=uResolution.x/uResolution.y;
    float dist = length(c);
    float angle = atan(c.y,c.x);
    
    // Background marmer hitam
    float marble = noise(uv*4.0 + uTime*0.03);
    vec3 bg = vec3(0.02) + vec3(0.08,0.06,0.02)*marble;
    
    // BLACKHOLE CORE
    float hole = smoothstep(0.35,0.15, dist);
    float ring = smoothstep(0.15,0.22,dist)*smoothstep(0.4,0.32,dist);
    // Pusaran atmosphere - 3 lapisan emas muter kayak topan
    float vortex1 = sin(angle*2.0 + dist*8.0 - uTime*1.5)*0.5+0.5;
    float vortex2 = sin(angle*3.0 + dist*6.0 - uTime*2.2)*0.5+0.5;
    float swirl = vortex1*0.6 + vortex2*0.4;
    
    vec3 goldSwirl = vec3(1.0,0.84,0.0)*swirl*ring*1.5;
    goldSwirl += vec3(0.8,0.6,0.1)*pow(swirl,2.0)*ring;
    
    // Atmosphere fog tertarik
    float suck = (1.0-dist)*0.3;
    bg = mix(bg, goldSwirl, ring*0.8 + suck*0.4);
    
    // Blackhole hitam pekat
    bg = mix(bg, vec3(0.0), hole*0.95);
    // Event horizon glow
    float horizon = smoothstep(0.18,0.16,dist)*smoothstep(0.12,0.16,dist);
    bg += vec3(1.0,0.9,0.5)*horizon*0.9;
    
    // Globe terjebak - di bawah blackhole, ketarik melar
    vec2 globePos = vec2(0.0, 0.45); // bawah
    vec2 toGlobe = c - globePos;
    float dGlobe = length(toGlobe);
    float globeMask = smoothstep(0.22,0.18, dGlobe);
    
    if(globeMask>0.01){
        // Real 3D globe shading + BABE.INFO emboss
        float lat = toGlobe.y*3.0 + uRotX;
        float lon = toGlobe.x*3.0 + uRotY + uTime*0.3;
        float light = dot(normalize(vec3(toGlobe,0.5)), vec3(-0.3,-0.4,1.0))*0.5+0.5;
        vec3 gold = uGoldColor*light + vec3(1.0,0.9,0.5)*pow(light,6.0)*0.6;
        
        // Duri hitam melilit
        float thorn = sin(lon*8.0 + lat*6.0)*0.5+0.5;
        thorn = smoothstep(0.65,0.75,thorn);
        gold = mix(gold, vec3(0.0), thorn*0.85);
        
        // Tertarik blackhole - melar
        float stretch = (0.45 - c.y)*1.5; // makin atas makin melar
        gold *= 1.0 + stretch*0.3;
        
        bg = mix(bg, gold, globeMask);
    }
    
    fragColor = vec4(bg,1.0);
}