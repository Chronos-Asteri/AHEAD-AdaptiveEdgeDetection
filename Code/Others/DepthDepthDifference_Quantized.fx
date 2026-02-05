/*
    Depth-Difference Edge Detection with Quantization
    -------------------------------------------------
    1. Depth Difference function: Detects edges based on 3D geometry distance.
       (Ignores textures, shadows, and lighting).
    2. Depth Masking: Fades edges on distant objects to prevent "cobwebs".
    3. Toggleable Quantization: Stylized "posterized" colors.
    4. No binary thresholding: Smooth, variable-strength lines.
*/

#include "ReShade.fxh"

// =============================================================================
// UI SETTINGS
// =============================================================================

uniform float EdgeStrength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 500.0; // Depth differences are tiny, so we need a high max
    ui_label = "Edge Strength";
    ui_tooltip = "Sensitivity to depth changes. Higher values detect smaller height differences.";
> = 100.0;

uniform float DepthMaskPower <
    ui_type = "slider";
    ui_min = 0.1; ui_max = 10.0;
    ui_label = "Distance Fade (Mask)";
    ui_tooltip = "Prevents messy lines on distant horizons/mountains.";
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

// =============================================================================
// FUNCTIONS
// =============================================================================

// 1. DEPTH DIFFERENCE FUNCTION
// Instead of looking at color, we look at how far away pixels are.
// If a pixel is 1 meter away, and its neighbor is 10 meters away, that's an edge.
float GetDepthDiffEdge(float2 texcoord)
{
    float3 offset = float3(BUFFER_PIXEL_SIZE, 0.0);

    // Sample Linearized Depth (0.0 = Camera, 1.0 = Horizon)
    // We use a "Central Difference" method (Right - Left, Bottom - Top)
    // This requires 4 samples around the center pixel.

    float2 dx = float2(offset.x, 0.0); // Step Right
    float2 dy = float2(0.0, offset.y); // Step Down

    float d_left   = ReShade::GetLinearizedDepth(texcoord - dx);
    float d_right  = ReShade::GetLinearizedDepth(texcoord + dx);
    float d_top    = ReShade::GetLinearizedDepth(texcoord - dy);
    float d_bottom = ReShade::GetLinearizedDepth(texcoord + dy);

    // Calculate the difference (Slope/Gradient)
    // We use abs() because we don't care if the object is closer or further, 
    // just that there is a difference.
    float diff_x = abs(d_right - d_left);
    float diff_y = abs(d_bottom - d_top);

    // Combine them (Pythagorean magnitude)
    // This value will be very small (e.g., 0.001), so it needs high boosting later.
    return sqrt(diff_x * diff_x + diff_y * diff_y);
}

// =============================================================================
// PIXEL SHADER
// =============================================================================

float3 PS_Main(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // --- Step A: Get Original Color ---
    float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;

    // --- Step B: Calculate Depth Edge ---
    float edge = GetDepthDiffEdge(texcoord);

    // --- Step C: Depth-Aware Masking ---
    // Get raw depth for masking purposes
    float depth = ReShade::GetLinearizedDepth(texcoord);
    
    // Create the mask: 1.0 near camera, 0.0 far away.
    // This prevents the horizon (where depth changes rapidly pixel-to-pixel) from turning black.
    float mask = 1.0 - saturate(pow(depth, 1.0 / DepthMaskPower));
    
    // Apply mask to the edge
    edge *= mask; 

    // --- Step D: Quantization (Posterization) ---
    if (EnableQuantization)
    {
        // Standard quantization logic
        color = floor(color * QuantizeLevels) / QuantizeLevels;
    }

    // --- Step E: Combine ---
    // Apply the edge outline.
    // Note: We multiply edge by EdgeStrength here because depth differences are tiny numbers.
    float outline_opacity = saturate(edge * EdgeStrength);
    
    return lerp(color, 0.0, outline_opacity);
}

// =============================================================================
// TECHNIQUE
// =============================================================================

technique DepthDifferenceQuantized
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Main;
    }
}