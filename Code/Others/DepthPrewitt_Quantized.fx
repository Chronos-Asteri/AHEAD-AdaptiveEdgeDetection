/*
    Depth-Aware Prewitt Edge Detection with Quantization
    ---------------------------------------------------
    1. Prewitt Operator: 3x3 kernel using uniform weights for gradient detection.
    2. Depth Masking: Fades edges based on distance to maintain visual clarity.
    3. Toggleable Quantization: Stylized posterization for the background.
*/

#include "ReShade.fxh"

// =============================================================================
// UI SETTINGS
// =============================================================================

uniform float EdgeStrength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 10.0;
    ui_label = "Edge Strength";
    ui_tooltip = "Controls the darkness/visibility of the detected lines.";
> = 2.0;

uniform float DepthMaskPower <
    ui_type = "slider";
    ui_min = 0.1; ui_max = 10.0;
    ui_label = "Distance Fade (Mask)";
    ui_tooltip = "Higher values restrict edges to the immediate foreground.";
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
    ui_tooltip = "Sets the threshold for the G value of the Prewitt Filter";
> = 0.5;

// =============================================================================
// FUNCTIONS
// =============================================================================

// 1. THE PREWITT FUNCTION
// Horizontal Kernel: [[-1, 0, 1], [-1, 0, 1], [-1, 0, 1]]
// Vertical Kernel:   [[-1, -1, -1], [0, 0, 0], [1, 1, 1]]
float GetPrewittEdge(float2 texcoord)
{
    float3 offset = float3(BUFFER_PIXEL_SIZE, 0.0);
    float3 weights = float3(0.299, 0.587, 0.114); // Luma conversion

    // Sample the 3x3 neighborhood
    float t_l = dot(tex2D(ReShade::BackBuffer, texcoord - offset.xy - offset.yz).rgb, weights);
    float t_c = dot(tex2D(ReShade::BackBuffer, texcoord - offset.yz).rgb, weights);
    float t_r = dot(tex2D(ReShade::BackBuffer, texcoord + offset.xy - offset.yz).rgb, weights);

    float m_l = dot(tex2D(ReShade::BackBuffer, texcoord - offset.xy).rgb, weights);
    float m_r = dot(tex2D(ReShade::BackBuffer, texcoord + offset.xy).rgb, weights);

    float b_l = dot(tex2D(ReShade::BackBuffer, texcoord - offset.xy + offset.yz).rgb, weights);
    float b_c = dot(tex2D(ReShade::BackBuffer, texcoord + offset.yz).rgb, weights);
    float b_r = dot(tex2D(ReShade::BackBuffer, texcoord + offset.xy + offset.yz).rgb, weights);

    // Apply Prewitt Kernels (Uniform weights of 1.0)
    // Horizontal (X)
    float grad_x = (t_r + m_r + b_r) - (t_l + m_l + b_l);
    
    // Vertical (Y)
    float grad_y = (b_l + b_c + b_r) - (t_l + t_c + t_r);

    // Calculate Magnitude

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
    // Step A: Sample Original Image
    float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;

    // Step B: Calculate Prewitt Edge
    float edge = GetPrewittEdge(texcoord);

    // Step C: Depth-Aware Masking
    // Get depth (0.0 = Near, 1.0 = Far)
    float depth = ReShade::GetLinearizedDepth(texcoord);
    
    // Create mask (1.0 at camera, fading to 0.0 at distance)
    float mask = 1.0 - saturate(pow(depth, 1.0 / DepthMaskPower));
    
    // Apply Mask as Global Strength Multiplier
    edge *= mask;

    // Step D: Optional Quantization (Posterization)
    if (EnableQuantization)
    {
        color = floor(color * QuantizeLevels) / QuantizeLevels;
    }

    // Step E: Combine
    // Lerp the posterized color toward black (0.0) using the edge intensity.
    float edge_final = saturate(edge * EdgeStrength);
    
    return lerp(color, 0.0, edge_final);
}

// =============================================================================
// TECHNIQUE
// =============================================================================

technique DepthPrewittQuantized
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Main;
    }
}