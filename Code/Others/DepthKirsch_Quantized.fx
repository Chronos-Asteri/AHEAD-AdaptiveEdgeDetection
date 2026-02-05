/*
    Depth-Aware Kirsch Compass Edge Detection with Quantization
    ---------------------------------------------------
    1. Kirsch Operator: 8-directional compass kernels with max-pooling.
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
> = 0.480;

uniform float DepthMaskPower <
    ui_type = "slider";
    ui_min = 0.1; ui_max = 10.0;
    ui_label = "Distance Fade (Mask)";
    ui_tooltip = "Higher values restrict edges to the immediate foreground.";
> = 0.528;

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
    ui_min = 0.0; ui_max = 2;
    ui_label = "Threshold";
    ui_tooltip = "Sets the threshold for the Maximum Gradient value of the Kirsch Filter.";
> = 0.052;

// =============================================================================
// FUNCTIONS
// =============================================================================

// 1. THE KIRSCH FUNCTION
// Uses 8 directional kernels (Compass) and returns the Maximum response.
float GetKirschEdge(float2 texcoord)
{
    float3 offset = float3(BUFFER_PIXEL_SIZE, 0.0);
    float3 grey_weights = float3(0.299, 0.587, 0.114); // Luma conversion

    // Sample the 3x3 neighborhood
    // Define isolated axis vectors for cleaner code
    float2 dx = float2(offset.x, 0.0); // Step Right
    float2 dy = float2(0.0, offset.y); // Step Down

    // Row 1: Top (Subtract Y)
    float tl = dot(tex2D(ReShade::BackBuffer, texcoord - dx - dy).rgb, grey_weights);
    float tc = dot(tex2D(ReShade::BackBuffer, texcoord - dy).rgb,      grey_weights);
    float tr = dot(tex2D(ReShade::BackBuffer, texcoord + dx - dy).rgb, grey_weights);

    // Row 2: Middle (No Y change)
    float ml = dot(tex2D(ReShade::BackBuffer, texcoord - dx).rgb, grey_weights);
    float mc = dot(tex2D(ReShade::BackBuffer, texcoord).rgb,      grey_weights);
    float mr = dot(tex2D(ReShade::BackBuffer, texcoord + dx).rgb, grey_weights);

    // Row 3: Bottom (Add Y)
    float bl = dot(tex2D(ReShade::BackBuffer, texcoord - dx + dy).rgb, grey_weights);
    float bc = dot(tex2D(ReShade::BackBuffer, texcoord + dy).rgb,      grey_weights);
    float br = dot(tex2D(ReShade::BackBuffer, texcoord + dx + dy).rgb, grey_weights);

    // Kirsch Compass Kernels
    // Each kernel emphasizes 3 neighbors (weight 5) against 5 others (weight -3)
    float g1 = abs(5.0 * (tl + tc + tr) - 3.0 * (ml + mr + bl + bc + br)); // North
    float g2 = abs(5.0 * (tc + tr + mr) - 3.0 * (tl + ml + bl + bc + br)); // North-East
    float g3 = abs(5.0 * (tr + mr + br) - 3.0 * (tl + tc + ml + bl + bc)); // East
    float g4 = abs(5.0 * (mr + br + bc) - 3.0 * (tl + tc + tr + ml + bl)); // South-East
    float g5 = abs(5.0 * (br + bc + bl) - 3.0 * (tl + tc + tr + ml + mr)); // South
    float g6 = abs(5.0 * (bc + bl + ml) - 3.0 * (tc + tr + mr + br + tl)); // South-West
    float g7 = abs(5.0 * (bl + ml + tl) - 3.0 * (bc + br + mr + tr + tc)); // West
    float g8 = abs(5.0 * (ml + tl + tc) - 3.0 * (bl + bc + br + mr + tr)); // North-West

    // MAX-POOLING: Take the strongest directional response
    float gradient = max(g1, max(g2, max(g3, max(g4, max(g5, max(g6, max(g7, g8)))))));

    // Normalize (Kirsch sums can be large, dividing by 15.0 scales it roughly to 0-1)
    gradient /= 15.0;

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

    // Step B: Calculate Kirsch Edge
    float edge = GetKirschEdge(texcoord);

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
    // Lerp the color toward black (0.0) based on edge intensity.
    float edge_final = saturate(edge * EdgeStrength);
    
    return lerp(color, 0.0, edge_final);
}

// =============================================================================
// TECHNIQUE
// =============================================================================

technique DepthKirschQuantized
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Main;
    }
}