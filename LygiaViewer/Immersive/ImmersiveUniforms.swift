#if os(visionOS)
import simd

// Swift mirrors of Shaders/Immersive/ImmersiveTypes.h. Field order, types and
// padding must match the Metal structs byte for byte.

nonisolated struct ImmersiveViewUniforms {
    var viewProjection = matrix_identity_float4x4
    var inverseProjection = matrix_identity_float4x4
    var cameraToWorld = matrix_identity_float4x4
}

nonisolated struct ImmersiveFrameUniforms {
    var views = (ImmersiveViewUniforms(), ImmersiveViewUniforms())
    var time: Float = 0
    var viewCount: UInt32 = 0
    var padding = SIMD2<Float>()

    subscript(view index: Int) -> ImmersiveViewUniforms {
        get { index == 0 ? views.0 : views.1 }
        set { if index == 0 { views.0 = newValue } else { views.1 = newValue } }
    }
}

nonisolated struct ImmersivePassViews {
    var viewIndex: (UInt32, UInt32) = (0, 0)
}
#endif
