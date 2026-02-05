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

uniform bool EnableAdaptive <
    ui_type = "checkbox";
    ui_label = "Enable Adaptive";
    ui_category = "Global Settings";
> = true;

uniform float UserGlobalStrength <
    ui_type = "slider";
    ui_min = 0; ui_max = 10;
    ui_label = "Global Strength";
    ui_category = "Global Settings";
> = 1.165;

uniform float WeightSilhouette <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 15.0;
    ui_label = "W1 - Silhouette";
    ui_category = "Global Settings";
> = 4.849;

uniform float WeightStructure <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 15.0;
    ui_label = "W2 - Structure";
    ui_tooltip = "This also works when Adaptive feature is turned on";
    ui_category = "Global Settings";
> = 1.0;

uniform float WeightTexture <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 15.0;
    ui_label = "W3 - Texture";
    ui_category = "Global Settings";
> = 0.288;

// =============================================================================
// 1. KIRSCH ALGORITHM SETTINGS
// =============================================================================

uniform float KirschEdgeStrength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 10.0;
    ui_label = "Edge Strength";
    ui_tooltip = "Controls the darkness/visibility of the detected lines.";
    ui_category = "1. Kirsch Edge";
> = 0.480;

uniform float KirschDepthMaskPower <
    ui_type = "slider";
    ui_min = 0.1; ui_max = 10.0;
    ui_label = "Distance Fade (Mask)";
    ui_tooltip = "Higher values restrict edges to the immediate foreground.";
    ui_category = "1. Kirsch Edge";
> = 0.191;

uniform bool KirschThresholding <
    ui_type = "checkbox";
    ui_label = "Enable Thresholding";
    ui_tooltip = "Enables only stronger lines for defined edges.";
    ui_category = "1. Kirsch Edge";
> = true;

uniform float KirschThresholdEdge <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2;
    ui_label = "Threshold";
    ui_tooltip = "Sets the threshold for the Maximum Normalized Gradient value of the Kirsch Filter.";
    ui_category = "1. Kirsch Edge";
> = 0.052;

// =============================================================================
// 2. DEPTH DIFFERENCE ALGORITHM SETTINGS
// =============================================================================

uniform float DepthDiffDepthMaskPower <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 10.0;
    ui_label = "Distance Fade (Mask)";
    ui_tooltip = "Prevents messy lines on distant horizons/mountains.";
    ui_category = "2. Depth Difference Edge";
> = 0.0;

// =============================================================================
// 3. SCHARR ALGORITHM SETTINGS
// =============================================================================

uniform float ScharrEdgeStrength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 5.0;
    ui_label = "Edge Strength";
    ui_tooltip = "How dark/prominent the edges appear.";
    ui_category = "3. Scharr Edge";
> = 1.0;

uniform float ScharrDepthMaskPower <
    ui_type = "slider";
    ui_min = 0.1; ui_max = 10.0;
    ui_label = "Distance Fade (Mask)";
    ui_tooltip = "Hides edges on distant objects (1.0 = Linear, >1.0 = Aggressive).";
    ui_category = "3. Scharr Edge";
> = 2.0;

uniform bool ScharrThresholding <
    ui_type = "checkbox";
    ui_label = "Enable Thresholding";
    ui_tooltip = "Enables only stronger lines for defined edges";
    ui_category = "3. Scharr Edge";
> = true;

uniform float ScharrThresholdEdge <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 5.0;
    ui_label = "Threshold";
    ui_tooltip = "Sets the threshold for the G value of the Scharr Filter";
    ui_category = "3. Scharr Edge";
> = 0.5;

// =============================================================================
// 4. DIFFERENCE OF GAUSSIANS ALGORITHM SETTINGS
// =============================================================================

uniform float Sigma <
    ui_type = "slider";
    ui_min = 0.1; ui_max = 2.0;
    ui_label = "Line Detail (Sigma)";
    ui_tooltip = "Adjusts the width of the blur. Smaller values find finer details.";
    ui_category = "4. Difference Of Gaussians";
> = 0.784;

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



// =============================================================================
// FUNCTIONS
// =============================================================================

// 1. THE KIRSCH FUNCTION
// Uses 8 directional kernels (Compass) and returns the Maximum response.
float GetKirschEdge(float2 texcoord)
{
    float3 offset = float3(BUFFER_PIXEL_SIZE, 0.0);
    float3 weights = float3(0.299, 0.587, 0.114); // Luma conversion

    float2 dx = float2(offset.x, 0.0); // Step Right
    float2 dy = float2(0.0, offset.y); // Step Down

    // 3x3 Kernel t->top, m->middle, b->bottom, l->left, c->center, r->right
    // Row 1: Top
    float tl = dot(tex2D(ReShade::BackBuffer, texcoord - dx - dy).rgb, weights);
    float tc = dot(tex2D(ReShade::BackBuffer, texcoord - dy).rgb, weights);
    float tr = dot(tex2D(ReShade::BackBuffer, texcoord + dx - dy).rgb, weights);

    // Row 2: Middle
    float ml = dot(tex2D(ReShade::BackBuffer, texcoord - dx).rgb, weights);
    float mc = dot(tex2D(ReShade::BackBuffer, texcoord).rgb, weights);
    float mr = dot(tex2D(ReShade::BackBuffer, texcoord + dx).rgb, weights);

    // Row 3: Bottom
    float bl = dot(tex2D(ReShade::BackBuffer, texcoord - dx + dy).rgb, weights);
    float bc = dot(tex2D(ReShade::BackBuffer, texcoord + dy).rgb, weights);
    float br = dot(tex2D(ReShade::BackBuffer, texcoord + dx + dy).rgb, weights);


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

    if (KirschThresholding) 
    {
        return step(KirschThresholdEdge, gradient);
    }
    else 
    {
        return gradient;
    }
}

// 2. THE DEPTH DIFFERENCE FUNCTION
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
    // This value will be very small (e.g., 0.001)
    return sqrt(diff_x * diff_x + diff_y * diff_y);
}

// 3. SCHARR FUNCTION
float GetScharrEdge(float2 texcoord)
{
    float3 offset = float3(BUFFER_PIXEL_SIZE, 0.0);
    float3 weights = float3(0.299, 0.587, 0.114); // Luma weights

    float2 dx = float2(offset.x, 0.0); // Step Right
    float2 dy = float2(0.0, offset.y); // Step Down

    // 3x3 Kernel t->top, m->middle, b->bottom, l->left, c->center, r->right
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

    // Normalization
    //gradient /= 22.627;

    if (ScharrThresholding) 
    {
        return step(ScharrThresholdEdge, gradient);
    }
    else 
    {
        return gradient;
    }
    
}

// 4. Extended DIFFERENCE OF GAUSSIANS FUNCTION
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

// =============================================================================
// PIXEL SHADER
// =============================================================================

float3 PS_Main(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
    float depth = ReShade::GetLinearizedDepth(texcoord);

    // Calculate Kirsch Edge
    float KirschMask = 1.0 - saturate(pow(depth, 1.0 / KirschDepthMaskPower));
    float KirschEdge = GetKirschEdge(texcoord) * KirschEdgeStrength * KirschMask;

    // Calculate Scharr's Edge
    float ScharrMask = 1.0 - saturate(pow(depth, 1.0 / ScharrDepthMaskPower));
    float ScharrEdge = GetScharrEdge(texcoord) * ScharrEdgeStrength * ScharrMask;

    // Calculate Difference of Gaussians
    float DoGMask = 1.0 - saturate(pow(depth, 1.0 / DoGDepthMaskPower));
    float DoGEdge = GetDoGEdge(texcoord) * DoGMask; // W3 WeightTexture exclusively is applied to DoGEdge

    // Calculate Depth Difference Edge (Outline)
    float DepthDiffMask = 1.0 - saturate(pow(depth, 1.0 / DepthDiffDepthMaskPower));
    float DepthDiffEdge = GetDepthDiffEdge(texcoord) * DepthDiffMask; // W1 WeightSilhouette exclusively is applied to DepthDiffEdge

    // Final Edge 
    
    float finalEdge = max(ScharrEdge, KirschEdge);
    
    if (EnableAdaptive)
    { 
        // Adaptive Feature
        // The modified (x3) "Weber-Fechner" Adaptive Weight
        // auto_weight increases when the image is low-contrast/dark
        float contrast_color = tex2D(ReShade::BackBuffer, texcoord).rgb; // or local average
        float local_contrast = dot(contrast_color, float3(0.299, 0.587, 0.114));
        float adaptive_scalar = 1.0 / (local_contrast * 3 + 0.1);
        adaptive_scalar = min(adaptive_scalar, 4.0); 

        finalEdge = max(WeightStructure * adaptive_scalar * finalEdge, WeightTexture * DoGEdge);
    }
    else 
    {
        finalEdge = max(WeightStructure * finalEdge, WeightTexture * DoGEdge);
    }

    finalEdge = max(finalEdge, WeightSilhouette * DepthDiffEdge);
    finalEdge = saturate(finalEdge * UserGlobalStrength);

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

technique CombinedHybridEdge
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Main;
    }
}