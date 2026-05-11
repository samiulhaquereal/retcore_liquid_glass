#include <flutter/runtime_effect.glsl>

// ── Uniforms (must match Dart binding order exactly) ─────────────────────────
uniform vec2      uSize;          // lens pixel dimensions (logical)
uniform sampler2D uTexture;       // captured background
uniform float     uRefraction;    // IOR blend: 0=no bend, 1=full IOR 1.5
uniform float     uMagnification; // zoom factor inside glass  (~1.0-2.0)
uniform float     uChromatic;     // chromatic aberration      (~0.002-0.01)
uniform vec4      uTint;          // rgba tint overlay
uniform vec2      uLensSizeNorm;  // lens size / background size (normalized)
uniform vec2      uLensPosNorm;   // lens pos / background size (normalized)
uniform float     uMode;          // 0.0 = Shape, 1.0 = Radial

out vec4 fragColor;

// ── Constants ────────────────────────────────────────────────────────────────
const float IOR_AIR   = 1.000;
const float IOR_GLASS = 1.500;     // borosilicate / Gorilla Glass
const float TWO_PI    = 6.283185;
const vec3  UP_LIGHT  = normalize(vec3(-0.45, -0.80, 1.50));   // upper-left
const vec3  VIEW_DIR  = vec3(0.0, 0.0, 1.0);                   // camera

// ── Schlick Fresnel approximation ────────────────────────────────────────────
float schlick(float cosTheta, float ior) {
    float r0 = (1.0 - ior) / (1.0 + ior);
    r0 = r0 * r0;
    return r0 + (1.0 - r0) * pow(1.0 - cosTheta, 5.0);
}

// ── Rounded Box SDF ──────────────────────────────────────────────────────────
float lensSDF(vec2 p, float aspect) {
    // We treat the lens as a box with rounded corners.
    float radius = 0.35; 
    vec2 b = vec2(aspect, 1.0) - radius;
    vec2 q = abs(p * vec2(aspect, 1.0)) - b;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// ── SDF Gradient (Normal) ────────────────────────────────────────────────────
// Calculates the 2D normal vector pointing outward from the shape.
vec2 getSDFNormal(vec2 p, float aspect) {
    vec2 e = vec2(0.005, 0.0);
    return normalize(vec2(
        lensSDF(p + e.xy, aspect) - lensSDF(p - e.xy, aspect),
        lensSDF(p + e.yx, aspect) - lensSDF(p - e.yx, aspect)
    ));
}

void main() {
    // ── 1. Coordinate setup ──────────────────────────────────────────────────
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv        = fragCoord / uSize;          
    vec2 c         = uv * 2.0 - 1.0;            
    float aspect   = uSize.x / uSize.y;

    // ── 2. SDF alpha mask (Clean edge) ───────────────────────────────────────
    float sdf   = lensSDF(c, aspect);
    // Very sharp, clean anti-aliased edge
    float alpha = 1.0 - smoothstep(-0.015, 0.015, sdf);
    if (alpha < 0.001) { fragColor = vec4(0.0); return; }

    // Distance from the edge (0.0 at edge, positive inside)
    float distToEdge = -sdf;

    // ── 3. Normal & Refraction Logic (Flat Center, Beveled Edge) ─────────────
    vec2 refOffset;
    vec2 sdfNorm = getSDFNormal(c, aspect);

    if (uMode > 0.5) {
        // --- RADIAL REFRACTION ---
        // Pushes pixels cleanly away from the edge, matching the shape.
        float radialCurve = smoothstep(0.4, 0.0, distToEdge);
        float radialStrength = pow(radialCurve, 2.0);
        refOffset = sdfNorm * radialStrength * 0.8;
    } else {
        // --- SHAPE REFRACTION (Snell's Law with Flat Center) ---
        // Center is flat (normal points straight up). Edges curve sharply.
        // The curve perfectly follows the rounded box border.
        float edgeCurve = smoothstep(0.35, 0.0, distToEdge); 
        
        vec2 n_xy = sdfNorm * edgeCurve;
        float n_z = sqrt(max(0.0, 1.0 - dot(n_xy, n_xy)));
        vec3 normal = vec3(n_xy.x, n_xy.y, n_z);

        vec3  I         = vec3(0.0, 0.0, -1.0);
        float eta       = mix(1.0, IOR_AIR / IOR_GLASS, uRefraction);
        vec3  refracted = refract(I, normal, eta);
        
        refOffset = refracted.xy * (1.0 - refracted.z);
    }

    refOffset /= max(aspect, 1.0); 

    // ── 4. Background UV & Magnification ─────────────────────────────────────
    vec2 bgUvRaw  = uLensPosNorm + (uv * uLensSizeNorm);
    vec2 centerBg = uLensPosNorm + (uLensSizeNorm * 0.5);
    vec2 bgUv     = centerBg + (bgUvRaw - centerBg) / uMagnification;

    // ── 5. Apply refraction offset ────────────────────────────────────────────
    vec2 baseUv = bgUv + refOffset * uRefraction;

    // ── 6. Chromatic aberration (clean edge dispersion) ──────────────────────
    vec2 dispDir = refOffset * uRefraction;
    vec2 uvR = clamp(baseUv + dispDir * (uChromatic * 0.5),  0.001, 0.999);
    vec2 uvG = clamp(baseUv,                                  0.001, 0.999);
    vec2 uvB = clamp(baseUv - dispDir * (uChromatic * 1.0),  0.001, 0.999);

    float r   = texture(uTexture, uvR).r;
    float g   = texture(uTexture, uvG).g;
    float b   = texture(uTexture, uvB).b;
    vec4  bg  = vec4(r, g, b, 1.0);

    // ── 7. Tint overlay ───────────────────────────────────────────────────────
    bg.rgb = mix(bg.rgb, uTint.rgb, uTint.a);

    // ── 8. Subtle inner shadow for 3D depth (No artificial white highlights) ──
    // Just a very faint darkening at the extreme edges to define the geometry
    float edgeShadow = smoothstep(0.08, 0.0, distToEdge) * 0.35;
    
    vec3 col = bg.rgb;
    col *= (1.0 - edgeShadow);

    fragColor = vec4(col, alpha);
}
