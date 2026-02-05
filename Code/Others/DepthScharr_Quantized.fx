/*
    Depth-Aware Scharr Edge Detection with Quantization
    ---------------------------------------------------
    1. Scharr Operator: Optimized 3x3 kernel for superior rotational invariance.
    2. Depth Masking: Prevents background "cobweb" noise.
    3. Toggleable Quantization: For a stylized, posterized look.
*/

#include "ReShade.fxh"

// =============================================================================
// UI SETTINGS
// =============================================================================

uniform float EdgeStrength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 5.0;
    ui_label = "Edge Strength";
    ui_tooltip = "How dark/prominent the edges appear.";
> = 1.0;

uniform float DepthMaskPower <
    ui_type = "slider";
    ui_min = 0.1; ui_max = 10.0;
    ui_label = "Distance Fade (Mask)";
    ui_tooltip = "Hides edges on distant objects (1.0 = Linear, >1.0 = Aggressive).";
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
    ui_min = 0.0; ui_max = 5.0;
    ui_label = "Threshold";
    ui_tooltip = "Sets the threshold for the G value of the Scharr Filter";
> = 0.5;

// =============================================================================
// FUNCTIONS
// =============================================================================

// 1. THE SCHARR FUNCTION
// Horizontal Kernel: [[-3, 0, +3], [-10, 0, +10], [-3, 0, +3]]
// Vertical Kernel:   [[-3, -10, -3], [0, 0, 0], [+3, +10, +3]]
float GetScharrEdge(float2 texcoord)
{
    float3 offset = float3(BUFFER_PIXEL_SIZE, 0.0);
    float3 weights = float3(0.299, 0.587, 0.114); // Luma weights

    float2 dx = float2(offset.x, 0.0); // Step Right
    float2 dy = float2(0.0, offset.y); // Step Down

    // Row 1: Top (Subtract Y)
    float t_l = dot(tex2D(ReShade::BackBuffer, texcoord - dx - dy).rgb, weights);
    float t_c = dot(tex2D(ReShade::BackBuffer, texcoord - dy).rgb, weights);
    float t_r = dot(tex2D(ReShade::BackBuffer, texcoord + dx - dy).rgb, weights);

    // Row 2: Middle (No Y change)
    float m_l = dot(tex2D(ReShade::BackBuffer, texcoord - dx).rgb, weights);
    float m_c = dot(tex2D(ReShade::BackBuffer, texcoord).rgb, weights);
    float m_r = dot(tex2D(ReShade::BackBuffer, texcoord + dx).rgb, weights);

    // Row 3: Bottom (Add Y)
    float b_l = dot(tex2D(ReShade::BackBuffer, texcoord - dx + dy).rgb, weights);
    float b_c = dot(tex2D(ReShade::BackBuffer, texcoord + dy).rgb, weights);
    float b_r = dot(tex2D(ReShade::BackBuffer, texcoord + dx + dy).rgb, weights);

    // Apply Scharr Kernels
    // Horizontal Gradient (X)
    float grad_x = (3.0 * t_r + 10.0 * m_r + 3.0 * b_r) - (3.0 * t_l + 10.0 * m_l + 3.0 * b_l);
    
    // Vertical Gradient (Y)
    float grad_y = (3.0 * b_l + 10.0 * b_c + 3.0 * b_r) - (3.0 * t_l + 10.0 * t_c + 3.0 * t_r);

    // Magnitude calculation
    float gradient =  sqrt(grad_x * grad_x + grad_y * grad_y);

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
    // A. Get Original Color
    float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;

    // B. Detect Edges using Scharr
    float edge = GetScharrEdge(texcoord);

    // C. Depth-Aware Masking
    float depth = ReShade::GetLinearizedDepth(texcoord);
    // 1.0 at camera, fades toward 0.0 at distance
    float mask = 1.0 - saturate(pow(depth, 1.0 / DepthMaskPower));
    
    // Apply Mask as a Global Strength multiplier
    edge *= mask; 

    // D. Quantization (Posterization)
    if (EnableQuantization)
    {
        color = floor(color * QuantizeLevels) / QuantizeLevels;
    }

    // E. Composition
    // We blend the color with black (0.0) based on the edge magnitude
    float edge_final = saturate(edge * EdgeStrength);
    
    return lerp(color, 0.0, edge_final);
}

// =============================================================================
// TECHNIQUE
// =============================================================================

technique DepthScharrQuantized
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Main;
    }
}