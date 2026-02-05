# AHEAD: Adaptive Hierarchical Edge Detection

[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](LICENSE)

**AHEAD** (Adaptive Hierarchical Edge Detection) is a real-time artistic stylization shader for video games. It uses a novel three-layer hierarchy (Silhouette, Structure, Texture) and adaptive sensitivity to generate clean, stable, ink-style outlines that react dynamically to scene lighting and depth.

> **Paper Title:** AHEAD: Adaptive Hierarchical Edge Detection for Real-Time Artistic Stylization

---

## 📥 1. How to Install ReShade

> [!IMPORTANT]
> **Version Compatibility:** This project was developed and validated using **ReShade 6.6.2**.
> While the code is likely compatible with other versions, performance metrics and shader behavior may vary.

To use this shader, you must first install the ReShade injector for your specific game.

Please refer to **Marty's Mods Guide** for a detailed, step-by-step installation tutorial:
👉 **[How to Install ReShade (Setup Tool)](https://guides.martysmods.com/reshade/installing/setuptool)**

---


## 🛠️ 2. Installing AHEAD

Once ReShade is installed for your game:

1.  Clone or download this repository.
2.  Navigate to the folder:  
    `./Code/Our_Method`
3.  Copy the file `CombinedHybrid_Edge.fx`.
4.  Paste them into the game's shader directory. This is typically located at:
    * **Folder:** `[Game Directory]\reshade-shaders\Shaders\`
5.  **Launch the Game.**
6.  Press **Home** (or Pos1) to open the ReShade menu.
7.  Search for `CombinedHybridEdge` in the list and check the box to enable it.

---

## 🖼️ Gallery

Below are results demonstrating the AHEAD shader in various game engines.(Click the image to get the full-res image)

### The Elder Scrolls V: Skyrim – Special Edition
| | |
|:-------------------------:|:-------------------------:|
| <img src="./Figures/Figure 9/Skyrim1.jpg" width="100%"/> | <img src="./Figures/Figure 9/Skyrim2.jpg" width="100%"/> |
| <img src="./Figures/Figure 9/Skyrim_Extra_1.jpg" width="100%"/> | <img src="./Figures/Figure 9/Skyrim_Extra_2.jpg" width="100%"/> |
| <img src="./Figures/Figure 9/Skyrim_Extra_3.jpg" width="100%"/> | |


### Cyberpunk 2077
| | |
|:-------------------------:|:-------------------------:|
| <img src="./Figures/Figure 9/Cyberpunk2077_1.jpg" width="100%"/> | <img src="./Figures/Figure 9/Cyberpunk2077_2.jpg" width="100%"/> |

### The Witcher 3: Wild Hunt
| | |
|:-------------------------:|:-------------------------:|
| <img src="./Figures/Figure 9/Witcher3_1.jpg" width="100%"/> | <img src="./Figures/Figure 9/Witcher3_2.jpg" width="100%"/> |
| <img src="./Figures/Figure 9/Witcher3_3.jpg" width="100%"/> | |


## 📄 Citation

If you use this code or method in your research, please cite our paper:

```bibtex
@misc{ahead2026,
  title  = {AHEAD: Adaptive Hierarchical Edge Detection for Real-Time Artistic Stylization},
  author = {M K Lino Roshaan},
  year   = {2026},
  note   = {GitHub repository},
  url    = {[https://github.com/Chronos-Asteri/AHEAD-AdaptiveEdgeDetection](https://github.com/Chronos-Asteri/AHEAD-AdaptiveEdgeDetection)}
}