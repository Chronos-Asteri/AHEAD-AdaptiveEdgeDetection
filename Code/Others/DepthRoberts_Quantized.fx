/*
    Depth-Aware Roberts Edge Detection with Quantization
    ----------------------------------------------------
    1. Roberts Cross function (2x2 kernel) for fine edge detection.
    2. Depth Masking to clean up distant noise.
    3. Toggleable Quantization (Posterization) for stylized output.
    4. No binary thresholding (Smooth edges).
*/

#include "ReShade.fxh"

// =============================================================================
// UI SETTINGS
// =============================================================================

uniform float EdgeStrength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 10.0;
    ui_label = "Edge Strength";
    ui_tooltip = "How dark/prominent the edges appear.";
> = 2.0;

uniform float DepthMaskPower <
    ui_type = "slider";
    ui_min = 0.1; ui_max = 10.0;
    ui_label = "Depth Mask Intensity";
    ui_tooltip = "Higher values remove edges from the background more aggressively.";
> = 2.0;

uniform bool EnableQuantization <
    ui_type = "checkbox";
    ui_label = "Enable Posterization";
    ui_tooltip = "Reduces the number of colors to create a cartoon/painting effect.";
> = true;

uniform int QuantizeLevels <
    ui_type = "slider";
    ui_min = 2; ui_max = 255;
    ui_label = "Color Levels";
    ui_tooltip = "Lower values create distinct bands of color (banding).";
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
    ui_tooltip = "Sets the threshold for the G value of the Roberts Filter";
> = 0.037;

// =============================================================================
// FUNCTIONS
// =============================================================================

// 1. THE ROBERTS CROSS FUNCTION
// Uses a 2x2 Kernel. Faster and sensitive to very fine noise/lines.
float GetRobertsEdge(float2 texcoord)
{
    float3 offset = float3(BUFFER_PIXEL_SIZE, 0.0);

    // We only need 4 samples for Roberts Cross (Current pixel + 3 neighbors)
    // TL = Top-Left (Current), TR = Top-Right, BL = Bottom-Left, BR = Bottom-Right
    
    // Convert to grayscale immediately using dot product
    float3 weights = float3(0.299, 0.587, 0.114);

    float2 dx = float2(offset.x, 0.0); // Step Right
    float2 dy = float2(0.0, offset.y); // Step Down

    float p_tl = dot(tex2D(ReShade::BackBuffer, texcoord).rgb, weights);
    float p_tr = dot(tex2D(ReShade::BackBuffer, texcoord + dx).rgb, weights);
    float p_bl = dot(tex2D(ReShade::BackBuffer, texcoord + dy).rgb, weights);
    float p_br = dot(tex2D(ReShade::BackBuffer, texcoord + dx + dy).rgb, weights);

    // Roberts Cross Calculation
    // Gx = TopLeft - BottomRight
    // Gy = TopRight - BottomLeft
    float grad_x = p_tl - p_br;
    float grad_y = p_tr - p_bl;

    // Return Magnitude
    //return sqrt(grad_x * grad_x + grad_y * grad_y);

    float gradient = sqrt(grad_x * grad_x + grad_y * grad_y);

    if (Thresholding) 
    {
        return step(ThresholdEdge, gradient);
    }
    else 
    {
        return gradient;
    }
}

// =============================================================================
// PIXEL SHADER
// =============================================================================

float3 PS_Main(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // --- Step A: Get Original Color ---
    float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;

    // --- Step B: Calculate Roberts Edge ---
    float edge = GetRobertsEdge(texcoord);

    // --- Step C: Depth-Aware Masking ---
    // Get depth (0.0 = close, 1.0 = far)
    float depth = ReShade::GetLinearizedDepth(texcoord);
    
    // Create a mask to hide distant edges
    float mask = 1.0 - saturate(pow(depth, 1.0 / DepthMaskPower));
    
    // Apply mask to the edge magnitude
    edge *= mask; 

    // --- Step D: Quantization (Posterization) ---
    if (EnableQuantization)
    {
        // Apply posterization to the background color, not the edge itself
        color = floor(color * QuantizeLevels) / QuantizeLevels;
    }

    // --- Step E: Combine ---
    // We mix the color with Black (0.0) based on the edge strength.
    // Since we removed thresholding, this creates smooth, shadowed outlines.
    return lerp(color, 0.0, saturate(edge * EdgeStrength));
}

// =============================================================================
// TECHNIQUE
// =============================================================================

technique DepthRobertsQuantized
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Main;
    }
}