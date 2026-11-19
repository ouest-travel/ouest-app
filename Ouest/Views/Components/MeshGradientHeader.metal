#include <metal_stdlib>
using namespace metal;

// Decorative mesh gradient for hero areas (profile card header).
//
// Modelled on Paper Shaders' "mesh gradient" effect: four control points
// drift slowly and every pixel is an inverse-distance blend of their colours.
// `grain` adds static per-pixel noise on top (the "grain gradient" variant).
// The noise is keyed off position only, never time, so it can't shimmer.
//
// Colours arrive as uniforms from the SwiftUI side so the design tokens
// (and their dark variants) stay the single source of truth.

static float hash21(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float weight(float2 st, float2 p) {
    float2 d = st - p;
    return 1.0 / pow(dot(d, d) + 0.05, 1.4);
}

[[ stitchable ]] half4 ouestMeshGradient(
    float2 position,
    half4 color,
    float2 size,
    float time,
    half4 c0,
    half4 c1,
    half4 c2,
    half4 c3,
    float grain
) {
    float2 st = position / size;
    st.x *= size.x / size.y;
    // ~7s per drift cycle: visible as motion, still a slow colour drift
    // (no luminance flash) for photosensitivity purposes.
    float t = time * 2.5;

    float2 p0 = float2(0.10, 0.85) + 0.35 * float2(sin(t * 0.37),       cos(t * 0.29));
    float2 p1 = float2(2.30, 0.90) + 0.40 * float2(cos(t * 0.31),       sin(t * 0.41));
    float2 p2 = float2(1.30, 0.10) + 0.45 * float2(sin(t * 0.27 + 1.3), cos(t * 0.33 + 0.4));
    float2 p3 = float2(0.70, 0.40) + 0.40 * float2(cos(t * 0.23 + 2.1), sin(t * 0.36 + 1.1));

    float w0 = weight(st, p0);
    float w1 = weight(st, p1);
    float w2 = weight(st, p2);
    float w3 = weight(st, p3);

    half3 col = (half3(w0) * c0.rgb + half3(w1) * c1.rgb + half3(w2) * c2.rgb + half3(w3) * c3.rgb)
              / half3(w0 + w1 + w2 + w3);

    col += half3((hash21(position) - 0.5) * grain);

    return half4(col, color.a);
}
