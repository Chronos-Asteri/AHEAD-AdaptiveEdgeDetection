/*
    Depth-Aware Sobel Edge Detection with Quantization
    --------------------------------------------------
    1. Single Sobel Function for edge detection.
    2. Depth Masking to clean up distant noise.
    3. Toggleable Quantization for stylized output.
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
> = 1.5;

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
    ui_tooltip = "Sets the threshold for the G value of the Sobel Filter";
> = 0.12017;



// =============================================================================
// FUNCTIONS
// =============================================================================

// 1. THE SOBEL FUNCTION
// Calculates the gradient magnitude based on luminance.
float GetSobelEdge(float2 texcoord)
{
    float3 offset = float3(BUFFER_PIXEL_SIZE, 0.0);
    float3 weights = float3(0.299, 0.587, 0.114); // Luma conversion

    // // Sample neighbor pixels
    // // Top Row
    // float t_l = dot(tex2D(ReShade::BackBuffer, texcoord - offset.xy - offset.yz).rgb, weights); // Top Left
    // float t_c = dot(tex2D(ReShade::BackBuffer, texcoord - offset.yz).rgb, weights);             // Top Center
    // float t_r = dot(tex2D(ReShade::BackBuffer, texcoord + offset.xy - offset.yz).rgb, weights); // Top Right

    // // Middle Row
    // float m_l = dot(tex2D(ReShade::BackBuffer, texcoord - offset.xy).rgb, weights);             // Mid Left
    // float m_r = dot(tex2D(ReShade::BackBuffer, texcoord + offset.xy).rgb, weights);             // Mid Right

    // // Bottom Row
    // float b_l = dot(tex2D(ReShade::BackBuffer, texcoord - offset.xy + offset.yz).rgb, weights); // Bot Left
    // float b_c = dot(tex2D(ReShade::BackBuffer, texcoord + offset.yz).rgb, weights);             // Bot Center
    // float b_r = dot(tex2D(ReShade::BackBuffer, texcoord + offset.xy + offset.yz).rgb, weights); // Bot Right

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

    // Apply Sobel Kernels
    // Horizontal (X)
    float grad_x = (t_r + 2.0 * m_r + b_r) - (t_l + 2.0 * m_l + b_l);
    
    // Vertical (Y)
    float grad_y = (b_l + 2.0 * b_c + b_r) - (t_l + 2.0 * t_c + t_r);

    // Return Magnitude (pythagorean distance)
    // return sqrt(grad_x * grad_x + grad_y * grad_y);

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

    // --- Step B: Calculate Edge ---
    float edge = GetSobelEdge(texcoord);

    // --- Step C: Depth-Aware Masking ---
    // Get depth (0.0 = close, 1.0 = far)
    float depth = ReShade::GetLinearizedDepth(texcoord);
    
    // Create a mask: High value (1.0) at close range, Low value (0.0) at far range.
    // The 'DepthMaskPower' controls how quickly it fades out.
    float mask = 1.0 - saturate(pow(depth, 1.0 / DepthMaskPower)); // Invert depth logic so foreground is white
    
    // Apply mask to the edge
    // This ensures edges are strong on characters/nearby walls, but invisible on the skybox/mountains.
    edge *= mask;
    //edge *= 1; 

    // --- Step D: Quantization (Posterization) ---
    if (EnableQuantization)
    {
        // Simple floor quantization: floor(x * levels) / levels
        color = floor(color * QuantizeLevels) / QuantizeLevels;
    }

    // --- Step E: Combine ---
    // Overlay the black edges onto the color.
    // 'EdgeStrength' multiplies the edge magnitude.
    return lerp(color, 0.0, saturate(edge * EdgeStrength));
}

// =============================================================================
// TECHNIQUE
// =============================================================================

technique DepthSobelQuantized
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Main;
    }
}