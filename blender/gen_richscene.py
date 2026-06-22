#!/usr/bin/env python3
"""
Generate RichCinemaScene.usda — the wrapper that references the Blender-exported
RichCinema.usdc, hides the placeholder screen/frame, binds the blurry reflection
materials to the floor/ceiling, and places the video docking region.

Reflection graph is reused from the project's CinemaScene.usda, with constants
re-fitted to this environment (screen at z=-11, room half-width 9):
  ZFromScreen offset  : 11.0   (distance from screen = worldZ + 11)
  DynamicThreshold base: 11.6  (half-width = 0.6*z + 11.6 -> ~5m at the screen)
  FarMask fade distance: 11 (floor) / 7 (ceiling)
  Intensity           : 0.18
"""

import os

RKASSETS = ("/Users/ishinotento/Documents/Envideo/Packages/RealityKitContent/"
            "Sources/RealityKitContent/RealityKitContent.rkassets")
OUT = os.path.join(RKASSETS, "RichCinemaScene.usda")

ZFROM = "11.0"
DYN = "11.6"
INTENSITY = "0.18"
DOCK_Z = -11.0
DOCK_Y = 3.75
DOCK_HALF_W = 5.1
DOCK_HALF_H = 2.75

REFLECT = r'''        def Material "%MAT%"
        {
            token outputs:mtlx:surface.connect = </Root/Materials/%MAT%/UnlitSurface.outputs:out>

            def Shader "ReflectionSpecular"
            {
                uniform token info:id = "ND_realitykit_light_spill_specular"
                float2 inputs:antialiasingStrength = (32.0, 32.0)
                float3 inputs:normal.connect = </Root/Materials/%MAT%/PerturbedNormal.outputs:out>
                float3 inputs:unreflected_direction.connect = </Root/Materials/%MAT%/ViewDirection.outputs:out>
                color4f outputs:out
            }

            def Shader "Normal"
            {
                uniform token info:id = "ND_normal_vector3"
                string inputs:space = "world"
                float3 outputs:out
            }

            def Shader "Position"
            {
                uniform token info:id = "ND_position_vector3"
                string inputs:space = "world"
                float3 outputs:out
            }

            def Shader "PositionHighFreq"
            {
                uniform token info:id = "ND_multiply_vector3FA"
                float3 inputs:in1.connect = </Root/Materials/%MAT%/Position.outputs:out>
                float inputs:in2 = 50.0
                float3 outputs:out
            }

            def Shader "NoiseR"
            {
                uniform token info:id = "ND_noise3d_float"
                float inputs:amplitude = 1.0
                float inputs:pivot = 0.0
                float3 inputs:position.connect = </Root/Materials/%MAT%/PositionHighFreq.outputs:out>
                float outputs:out
            }

            def Shader "PositionShifted"
            {
                uniform token info:id = "ND_add_vector3"
                float3 inputs:in1.connect = </Root/Materials/%MAT%/PositionHighFreq.outputs:out>
                float3 inputs:in2 = (100, 200, 300)
                float3 outputs:out
            }

            def Shader "NoiseG"
            {
                uniform token info:id = "ND_noise3d_float"
                float inputs:amplitude = 1.0
                float inputs:pivot = 0.0
                float3 inputs:position.connect = </Root/Materials/%MAT%/PositionShifted.outputs:out>
                float outputs:out
            }

            def Shader "NoiseVec"
            {
                uniform token info:id = "ND_combine3_vector3"
                float inputs:in1.connect = </Root/Materials/%MAT%/NoiseR.outputs:out>
                float inputs:in2.connect = </Root/Materials/%MAT%/NoiseG.outputs:out>
                float inputs:in3 = 0.0
                float3 outputs:out
            }

            def Shader "NoiseScaled"
            {
                uniform token info:id = "ND_multiply_vector3FA"
                float3 inputs:in1.connect = </Root/Materials/%MAT%/NoiseVec.outputs:out>
                float inputs:in2 = 0.08
                float3 outputs:out
            }

            def Shader "PerturbedNormalRaw"
            {
                uniform token info:id = "ND_add_vector3"
                float3 inputs:in1.connect = </Root/Materials/%MAT%/Normal.outputs:out>
                float3 inputs:in2.connect = </Root/Materials/%MAT%/NoiseScaled.outputs:out>
                float3 outputs:out
            }

            def Shader "PerturbedNormal"
            {
                uniform token info:id = "ND_normalize_vector3"
                float3 inputs:in.connect = </Root/Materials/%MAT%/PerturbedNormalRaw.outputs:out>
                float3 outputs:out
            }

            def Shader "ViewDirection"
            {
                uniform token info:id = "ND_realitykit_viewdirection_vector3"
                string inputs:space = "world"
                float3 outputs:out
            }

            def Shader "Swizzle"
            {
                uniform token info:id = "ND_swizzle_color4_color3"
                string inputs:channels = "rgb"
                color4f inputs:in.connect = </Root/Materials/%MAT%/ReflectionSpecular.outputs:out>
                color3f outputs:out
            }

            def Shader "PositionX"
            {
                uniform token info:id = "ND_swizzle_vector3_float"
                string inputs:channels = "x"
                float3 inputs:in.connect = </Root/Materials/%MAT%/Position.outputs:out>
                float outputs:out
            }

            def Shader "PositionZ"
            {
                uniform token info:id = "ND_swizzle_vector3_float"
                string inputs:channels = "z"
                float3 inputs:in.connect = </Root/Materials/%MAT%/Position.outputs:out>
                float outputs:out
            }

            def Shader "AbsX"
            {
                uniform token info:id = "ND_absval_float"
                float inputs:in.connect = </Root/Materials/%MAT%/PositionX.outputs:out>
                float outputs:out
            }

            def Shader "ZScaled"
            {
                uniform token info:id = "ND_multiply_float"
                float inputs:in1.connect = </Root/Materials/%MAT%/PositionZ.outputs:out>
                float inputs:in2 = 0.6
                float outputs:out
            }

            def Shader "DynamicThreshold"
            {
                uniform token info:id = "ND_add_float"
                float inputs:in1.connect = </Root/Materials/%MAT%/ZScaled.outputs:out>
                float inputs:in2 = %DYN%
                float outputs:out
            }

            def Shader "DynamicHigh"
            {
                uniform token info:id = "ND_add_float"
                float inputs:in1.connect = </Root/Materials/%MAT%/DynamicThreshold.outputs:out>
                float inputs:in2 = 2.0
                float outputs:out
            }

            def Shader "OutsideMask"
            {
                uniform token info:id = "ND_smoothstep_float"
                float inputs:low.connect = </Root/Materials/%MAT%/DynamicThreshold.outputs:out>
                float inputs:high.connect = </Root/Materials/%MAT%/DynamicHigh.outputs:out>
                float inputs:in.connect = </Root/Materials/%MAT%/AbsX.outputs:out>
                float outputs:out
            }

            def Shader "InsideMask"
            {
                uniform token info:id = "ND_subtract_float"
                float inputs:in1 = 1.0
                float inputs:in2.connect = </Root/Materials/%MAT%/OutsideMask.outputs:out>
                float outputs:out
            }

            def Shader "ZFromScreen"
            {
                uniform token info:id = "ND_add_float"
                float inputs:in1.connect = </Root/Materials/%MAT%/PositionZ.outputs:out>
                float inputs:in2 = %ZFROM%
                float outputs:out
            }

            def Shader "FarMask"
            {
                uniform token info:id = "ND_smoothstep_float"
                float inputs:low = 0.0
                float inputs:high = %FAR_HIGH%
                float inputs:in.connect = </Root/Materials/%MAT%/ZFromScreen.outputs:out>
                float outputs:out
            }

            def Shader "NearMask"
            {
                uniform token info:id = "ND_subtract_float"
                float inputs:in1 = 1.0
                float inputs:in2.connect = </Root/Materials/%MAT%/FarMask.outputs:out>
                float outputs:out
            }

            def Shader "CombinedMask"
            {
                uniform token info:id = "ND_multiply_float"
                float inputs:in1.connect = </Root/Materials/%MAT%/InsideMask.outputs:out>
                float inputs:in2.connect = </Root/Materials/%MAT%/NearMask.outputs:out>
                float outputs:out
            }

            def Shader "MaskTimesIntensity"
            {
                uniform token info:id = "ND_multiply_float"
                float inputs:in1.connect = </Root/Materials/%MAT%/CombinedMask.outputs:out>
                float inputs:in2 = %INTENSITY%
                float outputs:out
            }

            def Shader "MaskedColor"
            {
                uniform token info:id = "ND_multiply_color3FA"
                color3f inputs:in1.connect = </Root/Materials/%MAT%/Swizzle.outputs:out>
                float inputs:in2.connect = </Root/Materials/%MAT%/MaskTimesIntensity.outputs:out>
                color3f outputs:out
            }

            def Shader "UnlitSurface"
            {
                uniform token info:id = "ND_realitykit_unlit_surfaceshader"
                color3f inputs:color.connect = </Root/Materials/%MAT%/MaskedColor.outputs:out>
                token outputs:out
            }
        }
'''

def mat(name, far_high):
    return (REFLECT.replace("%MAT%", name)
                   .replace("%DYN%", DYN)
                   .replace("%ZFROM%", ZFROM)
                   .replace("%INTENSITY%", INTENSITY)
                   .replace("%FAR_HIGH%", far_high))

HEADER = '''#usda 1.0
(
    defaultPrim = "Root"
    metersPerUnit = 1
    upAxis = "Y"
)

def Xform "Root"
{
    def Xform "RichCinemaScene"
    {
        def "Cinema" (
            prepend references = @RichCinema.usdc@
        )
        {
            over "VideoScreen"
            {
                token visibility = "invisible"
            }

            over "ScreenFrame"
            {
                token visibility = "invisible"
            }

            over "Floor"
            {
                over "Floor"
                {
                    rel material:binding = </Root/Materials/FloorReflectMat>
                }
            }

            over "Ceiling"
            {
                over "Ceiling"
                {
                    rel material:binding = </Root/Materials/CeilingReflectMat>
                }
            }
        }
    }

    def Xform "Video_Dock"
    {
        double3 xformOp:translate = (0, %DOCK_Y%, %DOCK_Z%)
        uniform token[] xformOpOrder = ["xformOp:translate", "xformOp:orient", "xformOp:scale"]

        def Xform "Player"
        {
            def RealityKitComponent "CustomDockingRegion"
            {
                token info:id = "RealityKit.CustomDockingRegion"

                def RealityKitStruct "m_bounds"
                {
                    float3 max = (%HW%, %HH%, 0)
                    float3 min = (-%HW%, -%HH%, 0)
                }
            }
        }
    }

    def Scope "Materials"
    {
'''

FOOTER = '''    }
}
'''

def main():
    body = (HEADER
            .replace("%DOCK_Y%", str(DOCK_Y))
            .replace("%DOCK_Z%", str(DOCK_Z))
            .replace("%HW%", str(DOCK_HALF_W))
            .replace("%HH%", str(DOCK_HALF_H)))
    body += mat("FloorReflectMat", "11.0")
    body += "\n"
    body += mat("CeilingReflectMat", "7.0")
    body += FOOTER
    with open(OUT, "w") as f:
        f.write(body)
    print("wrote", OUT, len(body), "bytes")

if __name__ == "__main__":
    main()
