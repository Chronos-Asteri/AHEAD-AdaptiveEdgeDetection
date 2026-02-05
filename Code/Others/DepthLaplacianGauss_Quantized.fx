/*
    Depth-Aware Laplacian of Gaussian (LoG) with Quantization
    --------------------------------------------------------
    1. LoG Function: Uses a 5x5 approximation to detect second-order derivatives.
    2. Depth Masking: Fades edges based on distance to prevent background noise.
    3. Toggleable Quantization: For that "illustrated" look.
*/

#include "ReShade.fxh"

// =============================================================================
// UI SETTINGS
// =============================================================================

uniform float BlurStrength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Pre-Blur Strength";
    ui_tooltip = "Blends the center pixel with its neighbors to reduce noise before detecting edges.";
> = 0.5;

uniform float EdgeStrength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 20.0;
    ui_label = "Edge Strength";
> = 5.0;

uniform float DepthMaskPower <
    ui_type = "slider";
    ui_min = 0.1; ui_max = 10.0;
    ui_label = "Distance Fade (Mask)";
> = 2.0;

uniform bool EnableQuantization <
    ui_type = "checkbox";
    ui_label = "Enable Posterization";
> = true;

uniform int QuantizeLevels <
    ui_type = "slider";
    ui_min = 2; ui_max = 255;
    ui_label = "Color Levels";
> = 8;

uniform bool Thresholding <
    ui_type = "checkbox";
    ui_label = "Enable Thresholding";
    ui_tooltip = "Enalbes black and white lines for defined edges";
> = false;

uniform float ThresholdEdge <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
    ui_label = "Threshold";
    ui_tooltip = "Sets the threshold for the G value of the LoG Filter";
> = 0.0171;


// =============================================================================
// FUNCTIONS
// =============================================================================

// 1. THE LAPLACIAN OF GAUSSIAN FUNCTION
// Implements the 3x3 kernel:
// [ -1, -1, -1 ]
// [ -1, +8, -1 ]
// [ -1, -1, -1 ]
// It effectively blurs (Gaussian) and then finds the edge (Laplacian).
float GetLoGEdge(float2 texcoord)
{
    float2 p = BUFFER_PIXEL_SIZE;
    float3 w = float3(0.299, 0.587, 0.114);

    // Sample the 8 neighbors
    float s01 = dot(tex2D(ReShade::BackBuffer, texcoord + float2(-p.x, -p.y)).rgb, w); // TL
    float s02 = dot(tex2D(ReShade::BackBuffer, texcoord + float2( 0,   -p.y)).rgb, w); // TC
    float s03 = dot(tex2D(ReShade::BackBuffer, texcoord + float2( p.x, -p.y)).rgb, w); // TR
    float s04 = dot(tex2D(ReShade::BackBuffer, texcoord + float2(-p.x,  0)).rgb,   w); // ML
    float s05 = dot(tex2D(ReShade::BackBuffer, texcoord + float2( p.x,  0)).rgb,   w); // MR
    float s06 = dot(tex2D(ReShade::BackBuffer, texcoord + float2(-p.x,  p.y)).rgb, w); // BL
    float s07 = dot(tex2D(ReShade::BackBuffer, texcoord + float2( 0,    p.y)).rgb, w); // BC
    float s08 = dot(tex2D(ReShade::BackBuffer, texcoord + float2( p.x,  p.y)).rgb, w); // BR
    
    // Original center pixel
    float centerRaw = dot(tex2D(ReShade::BackBuffer, texcoord).rgb, w);

    // --- PRE-BLUR STEP ---
    // Create a 3x3 average (Box Blur) of the neighbors
    float neighborhoodAvg = (s01 + s02 + s03 + s04 + s05 + s06 + s07 + s08) / 8.0;
    
    // Mix the original center with the neighborhood average based on BlurStrength
    float blurredCenter = lerp(centerRaw, neighborhoodAvg, BlurStrength);

    // --- LAPLACIAN STEP ---
    // We use the blurred center against the neighbors
    float acc = (blurredCenter * 8.0) - (s01 + s02 + s03 + s04 + s05 + s06 + s07 + s08);

    // Return absolute value to get edge magnitude
    //return abs(acc);

    if (Thresholding) 
    {
        return step(ThresholdEdge, abs(acc));
    }
    else 
    {
        return abs(acc);
    }
}

// =============================================================================
// PIXEL SHADER
// =============================================================================

float3 PS_Main(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;

    // A. Detect Edges using LoG
    float edge = GetLoGEdge(texcoord);

    // B. Depth Masking logic
    float depth = ReShade::GetLinearizedDepth(texcoord);
    float mask = 1.0 - saturate(pow(depth, 1.0 / DepthMaskPower));
    
    // Apply masking to the edge detection
    edge *= mask;

    // C. Optional Quantization
    if (EnableQuantization)
    {
        color = floor(color * QuantizeLevels) / QuantizeLevels;
    }

    // D. Final Composition
    // We subtract the edge from the color to create dark outlines.
    float edge_final = saturate(edge * EdgeStrength);
    
    return lerp(color, 0.0, edge_final);
}

// =============================================================================
// TECHNIQUE
// =============================================================================

technique DepthLoGQuantized
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Main;
    }
}