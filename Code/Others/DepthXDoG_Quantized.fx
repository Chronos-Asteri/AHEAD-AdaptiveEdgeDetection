#include "ReShade.fxh"

// =============================================================================
// GLOBAL SETTINGS
// =============================================================================
uniform bool EnableQuantization <
    ui_type = "checkbox";
    ui_label = "Enable Posterization";
    ui_category = "Global Settings";
> = false;

uniform int QuantizeLevels <
    ui_type = "slider";
    ui_min = 2; ui_max = 255;
    ui_label = "Color Levels";
    ui_category = "Global Settings";
> = 8;

uniform float Sigma <
    ui_type = "slider";
    ui_min = 0.1; ui_max = 2.0;
    ui_label = "Line Detail (Sigma)";
    ui_tooltip = "Adjusts the width of the blur. Smaller values find finer details.";
    ui_category = "4. Difference Of Gaussians";
> = 0.990;

uniform float K_Weight <
    ui_type = "slider";
    ui_min = 1.1; ui_max = 5.0;
    ui_label = "Line Thickness (K)";
    ui_tooltip = "The ratio between the two blurs. Higher values create thicker outlines.";
    ui_category = "4. Difference Of Gaussians";
> = 1.876;

uniform float Phi <
    ui_type = "slider";
    ui_min = 1.0; ui_max = 100.0;
    ui_label = "Phi";
    ui_tooltip = "Phi controls the steepness (Sharpness of the black line)";
    ui_category = "4. Difference Of Gaussians";
> = 10.0;

uniform float DoGDepthMaskPower <
    ui_type = "slider";
    ui_min = 0.01; ui_max = 1.0;
    ui_label = "Distance Fade (Mask)";
    ui_tooltip = "Higher values restrict edges to the immediate foreground.";
    ui_category = "4. Difference Of Gaussians";
> = 0.1;

uniform bool DoGThresholding <
    ui_type = "checkbox";
    ui_label = "Enable Thresholding";
    ui_tooltip = "Enables black and white lines for defined edges.";
    ui_category = "4. Difference Of Gaussians";
> = true;

uniform float DoGThresholdEdge <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Threshold";
    ui_tooltip = "Sets the binary cutoff for the DoG result.";
    ui_category = "4. Difference Of Gaussians";
> = 0.032;

float gaussian(float x, float sigma) {
    return (1.0 / (2.506628 * sigma)) * exp(-(x * x) / (2.0 * sigma * sigma));
}

float GetDoGEdge(float2 texcoord)
{
    float2 pix = BUFFER_PIXEL_SIZE;
    float3 weights = float3(0.299, 0.587, 0.114);

    // --- 1. Convolution Loop ---
    // We calculate two blurs simultaneously to save texture lookups.
    // Blur A (Sharp/Inner) and Blur B (Wide/Outer).
    
    float3 sum_A = 0.0;
    float3 sum_B = 0.0;
    float weight_A = 0.0;
    float weight_B = 0.0;
    
    // Sigma2 is the "Outer" blur width (K * Sigma)
    float sigma2 = Sigma * K_Weight; 

    // Calculate kernel size automatically based on the largest Sigma.
    // We limit it to 6 to prevent freezing the GPU on high settings.
    int radius = clamp(int(ceil(sigma2 * 2.0)), 1, 6);

    for (int x = -radius; x <= radius; x++)
    {
        for (int y = -radius; y <= radius; y++)
        {
            // Calculate Distance from Center
            float2 offset = float2(x, y) * pix;
            float dist = length(float2(x, y)); // Euclidean distance in pixels

            // Sample Color ONCE for both blurs
            float3 sampleColor = tex2D(ReShade::BackBuffer, texcoord + offset).rgb;
            
            // Calculate Gaussian Weights
            // (Note: We use the same sample, just weigh it differently for each blur)
            float w_a = gaussian(dist, Sigma);
            float w_b = gaussian(dist, sigma2);

            sum_A += sampleColor * w_a;
            weight_A += w_a;

            sum_B += sampleColor * w_b;
            weight_B += w_b;
        }
    }

    // Normalize results
    float val_A = dot(sum_A / weight_A, weights); // Sharp Luma
    float val_B = dot(sum_B / weight_B, weights); // Blurred Luma

    // --- 2. The Difference ---
    // Standard DoG: (Sharp - Blurred)
    float diff = val_A - val_B;

    // --- 3. "XDoG" Transformation (The Secret Sauce) ---
    // Standard DoG output is often very faint (e.g., 0.05).
    // We use a Scaled Tanh function to create a "Soft Threshold".
    // This makes weak edges bold (like ink) without hard aliasing.
    
    // Apply Soft Thresholding
    // Logic: If diff is slightly negative (dark edge), push it strongly towards 1.0
    float edge = 1.0;
    
    if (diff < 0.0) // We only care about dark edges
    {
       edge = 1.0 + tanh(Phi * diff);
    }
    
    // Invert so 1.0 = Line, 0.0 = White
    float final_response = 1.0 - edge;

    if (DoGThresholding) 
    {
        return step(DoGThresholdEdge, final_response);
    }
    else 
    {
        return final_response;
    }
}

float3 PS_Main(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
    float depth = ReShade::GetLinearizedDepth(texcoord);

    // Calculate Difference of Gaussians
    float DoGMask = 1.0 - saturate(pow(depth, 1.0 / DoGDepthMaskPower));
    float DoGEdge = GetDoGEdge(texcoord) * DoGMask;

    float finalEdge = saturate(DoGEdge);
        
    // Optional Quantization (Posterization)
    if (EnableQuantization)
    {
        color = floor(color * QuantizeLevels) / (float)QuantizeLevels;
    }

    return lerp(color, 0.0, finalEdge);
}

// =============================================================================
// TECHNIQUE
// =============================================================================

technique XDoGEdge
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Main;
    }
}