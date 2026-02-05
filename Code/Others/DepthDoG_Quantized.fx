/*
    Depth-Aware Difference of Gaussians (DoG) Edge Detection
    -------------------------------------------------------
    1. DoG Operator: Subtraction of two Gaussian blurs to extract frequency edges.
    2. Depth Masking: Fades edges based on distance to maintain visual clarity.
    3. Toggleable Quantization: Stylized posterization for the background.
*/

#include "ReShade.fxh"

// =============================================================================
// UI SETTINGS
// =============================================================================

uniform float EdgeStrength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 20.0;
    ui_label = "Edge Strength";
    ui_tooltip = "Controls the darkness/visibility of the detected lines.";
> = 5.0;

uniform float Sigma <
    ui_type = "slider";
    ui_min = 0.1; ui_max = 2.0;
    ui_label = "Line Detail (Sigma)";
    ui_tooltip = "Adjusts the width of the blur. Smaller values find finer details.";
> = 0.5;

uniform float K_Weight <
    ui_type = "slider";
    ui_min = 1.1; ui_max = 5.0;
    ui_label = "Line Thickness (K)";
    ui_tooltip = "The ratio between the two blurs. Higher values create thicker outlines.";
> = 1.6;

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
    ui_tooltip = "Enables black and white lines for defined edges.";
> = false;

uniform float ThresholdEdge <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Threshold";
    ui_tooltip = "Sets the binary cutoff for the DoG result.";
> = 0.01;

uniform float Phi <
    ui_type = "slider";
    ui_min = 0.1; ui_max = 100.0;
    ui_label = "Softness (Phi)";
    ui_tooltip = "Controls the steepness of the edge transition (Tanh curve). Lower = Softer/Grayer, Higher = Harder/Blacker.";
> = 10.0;

uniform float Epsilon <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Threshold (Epsilon)";
    ui_tooltip = "Removes noise. Any edge weaker than this value will be ignored.";
> = 0.05;

float tanh_approx(float x)
{
    float e2x = exp(2.0 * x);
    return (e2x - 1.0) / (e2x + 1.0);
}

// =============================================================================
// FUNCTIONS
// =============================================================================

// 1. THE DoG FUNCTION
// Approximates the Difference of Gaussians using a 5-tap cross-sampling
float GetDoGEdge(float2 texcoord)
{
    float2 pix = BUFFER_PIXEL_SIZE;
    float3 weights = float3(0.299, 0.587, 0.114);

    // Sample Center
    float center = dot(tex2D(ReShade::BackBuffer, texcoord).rgb, weights);

    // Sample Neighbors for Blur 1 (Narrow)
    float blur1 = center;
    blur1 += dot(tex2D(ReShade::BackBuffer, texcoord + float2(pix.x, 0) * Sigma).rgb, weights);
    blur1 += dot(tex2D(ReShade::BackBuffer, texcoord - float2(pix.x, 0) * Sigma).rgb, weights);
    blur1 += dot(tex2D(ReShade::BackBuffer, texcoord + float2(0, pix.y) * Sigma).rgb, weights);
    blur1 += dot(tex2D(ReShade::BackBuffer, texcoord - float2(0, pix.y) * Sigma).rgb, weights);
    blur1 /= 5.0;

    // Sample Neighbors for Blur 2 (Wide - scaled by K)
    float blur2 = center;
    float Sigma2 = Sigma * K_Weight;
    blur2 += dot(tex2D(ReShade::BackBuffer, texcoord + float2(pix.x, 0) * Sigma2).rgb, weights);
    blur2 += dot(tex2D(ReShade::BackBuffer, texcoord - float2(pix.x, 0) * Sigma2).rgb, weights);
    blur2 += dot(tex2D(ReShade::BackBuffer, texcoord + float2(0, pix.y) * Sigma2).rgb, weights);
    blur2 += dot(tex2D(ReShade::BackBuffer, texcoord - float2(0, pix.y) * Sigma2).rgb, weights);
    blur2 /= 5.0;

    // The Difference
    float gradient = blur1 - blur2;
    float edge = tanh_approx(Phi * (gradient - Epsilon));

    if (Thresholding) 
    {
        return step(ThresholdEdge, gradient);
    }
    else 
    {
        // Clamp to positive to only get "dark" edges on light backgrounds
        return max(gradient, 0);
    }
}

// =============================================================================
// PIXEL SHADER
// =============================================================================

float3 PS_Main(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // Step A: Sample Original Image
    float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;

    // Step B: Calculate DoG Edge
    float edge = GetDoGEdge(texcoord);

    // Step C: Depth-Aware Masking
    float depth = ReShade::GetLinearizedDepth(texcoord);
    
    // Create mask (1.0 at camera, fading to 0.0 at distance)
    float mask = 1.0 - saturate(pow(depth, 1.0 / DepthMaskPower));
    
    // Apply Mask as Global Strength Multiplier
    edge *= mask;

    // Step D: Optional Quantization (Posterization)
    if (EnableQuantization)
    {
        color = floor(color * QuantizeLevels) / (float)QuantizeLevels;
    }

    // Step E: Combine
    // We use a subtractive blend for DoG to get that clean ink look
    float edge_final = saturate(edge * EdgeStrength);
    
    return lerp(color, 0.0, edge_final);
}

// =============================================================================
// TECHNIQUE
// =============================================================================

technique DepthDoGQuantized
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Main;
    }
}