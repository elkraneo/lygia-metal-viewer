#if os(macOS)
import Foundation

/// A snippet that shows one Metal fix: rendered with upstream LYGIA and with
/// this fork, side by side. Each mirrors a claim in the fork's
/// test/msl/proof/claims, whose GPU check gives the numbers; these give the picture.
struct CompareCase: Identifiable {
    let id: String
    let title: String
    /// What differs, and the upstream commit or claim that pins it down.
    let note: String
    let source: String
}

enum CompareCases {
    static let all: [CompareCase] = [
        CompareCase(id: "rotate2d", title: "Rotation direction",
                    note: "GLSL and HLSL flipped rotate2d/3d/4d in 9a3a036c (2024-08-02); Metal kept the old matrices, so it rotates the other way. Claim: rotate2d.",
                    source: """
        #include "lygia/space/ratio.msl"
        #include "lygia/space/rotate.msl"
        #include "lygia/sdf/triSDF.msl"
        #include "lygia/draw/fill.msl"

        // A triangle turned by +30 degrees. GLSL turns it counterclockwise.
        float4 mainImage(float2 fragCoord, float2 resolution, float time) {
            float2 st = ratio(fragCoord / resolution, resolution);
            float2 p = rotate(st, 0.5236);
            float3 color = float3(0.06, 0.07, 0.1);
            color = mix(color, float3(0.95, 0.55, 0.2), fill(triSDF(p), 0.7));
            color = mix(color, float3(1.0), fill(triSDF(st), 0.7) * 0.15);   // unrotated ghost
            return float4(color, 1.0);
        }
        """),
        CompareCase(id: "bayer", title: "Bayer dither pattern",
                    note: "Metal read the 8x8 Bayer table transposed (x and y swapped), so the dither pattern was mirrored across the diagonal. Claim: bayer.",
                    source: """
        #include "lygia/space/ratio.msl"
        #include "lygia/color/dither/bayer.msl"

        // A horizontal ramp dithered with 8x8 Bayer, magnified 6x.
        float4 mainImage(float2 fragCoord, float2 resolution, float time) {
            float2 cell = floor(fragCoord / 6.0);
            float ramp = cell.x / floor(resolution.x / 6.0);
            float v = step(ditherBayer(cell), ramp);
            return float4(float3(v), 1.0);
        }
        """),
        CompareCase(id: "worley2", title: "worley2 (F1, F2)",
                    note: "worley2 didn't exist in the Metal port, so this doesn't compile against upstream. F2 - F1 draws cell borders. Claim: worley2.",
                    source: """
        #include "lygia/space/ratio.msl"
        #include "lygia/generative/worley.msl"

        float4 mainImage(float2 fragCoord, float2 resolution, float time) {
            float2 st = ratio(fragCoord / resolution, resolution);
            float2 f = worley2(st * 6.0);
            float border = smoothstep(0.0, 0.08, f.y - f.x);
            return float4(float3(border) * float3(0.4, 0.8, 1.0), 1.0);
        }
        """),
        CompareCase(id: "round", title: "round() with math/round",
                    note: "math/round.msl redefined round, which made every call ambiguous with Metal's own round, so including it broke compilation. Claim: round.",
                    source: """
        #include "lygia/space/ratio.msl"
        #include "lygia/math/round.msl"

        // 8 steps across, using round().
        float4 mainImage(float2 fragCoord, float2 resolution, float time) {
            float2 st = fragCoord / resolution;
            float v = round(st.x * 8.0) / 8.0;
            return float4(float3(v), 1.0);
        }
        """),
        CompareCase(id: "control", title: "Control: fill + circleSDF",
                    note: "A control: these functions are the same in both, so the difference should be zero.",
                    source: """
        #include "lygia/space/ratio.msl"
        #include "lygia/sdf/circleSDF.msl"
        #include "lygia/draw/fill.msl"

        float4 mainImage(float2 fragCoord, float2 resolution, float time) {
            float2 st = ratio(fragCoord / resolution, resolution);
            float v = fill(circleSDF(st), 0.6);
            return float4(float3(v) * float3(0.3, 0.7, 1.0), 1.0);
        }
        """),
        CompareCase(id: "kaleidoscope", title: "kaleidoscope compiles",
                    note: "Upstream's kaleidoscope.msl calls atan(y, x), which Metal doesn't have (it's atan2), so it never compiled: one of the 54 files fixed in #318. The fixed output matches LYGIA's own WESL test image within 1/255.",
                    source: """
        #include "lygia/space/ratio.msl"
        #include "lygia/space/kaleidoscope.msl"
        #include "lygia/sdf/starSDF.msl"
        #include "lygia/draw/fill.msl"

        float4 mainImage(float2 fragCoord, float2 resolution, float time) {
            float2 st = ratio(fragCoord / resolution, resolution);
            float2 k = kaleidoscope(st, 6.0);
            float v = fill(starSDF(k - float2(0.25, 0.0), 5, 0.1), 0.3);
            return float4(float3(v) * float3(1.0, 0.8, 0.3), 1.0);
        }
        """),
        CompareCase(id: "pbr", title: "Lighting (fork only)",
                    note: "The lighting module (99 files) was never ported to Metal; it only exists on the fork, so upstream fails to compile. Shown here with a point light on a sphere.",
                    source: """
        #include "lygia/space/ratio.msl"
        #include "lygia/lighting/diffuse/lambert.msl"
        #include "lygia/lighting/specular/blinnPhong.msl"

        float4 mainImage(float2 fragCoord, float2 resolution, float time) {
            float2 st = ratio(fragCoord / resolution, resolution) - 0.5;
            float r2 = dot(st, st);
            if (r2 > 0.16) return float4(0.05, 0.05, 0.07, 1.0);
            float3 n = normalize(float3(st, sqrt(0.16 - r2)));
            float3 l = normalize(float3(0.6, 0.8, 1.0));
            float3 v = float3(0.0, 0.0, 1.0);
            float3 h = normalize(l + v);
            float3 color = float3(0.9, 0.4, 0.3) * diffuseLambert(l, n)
                         + specularBlinnPhong(max(0.0, dot(n, h)), 32.0);
            return float4(color + 0.03, 1.0);
        }
        """),
    ]
}
#endif
