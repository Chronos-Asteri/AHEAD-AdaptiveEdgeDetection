# AHEAD: Adaptive Hierarchical Edge Detection

[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](LICENSE)

**AHEAD** (Adaptive Hierarchical Edge Detection) is a real-time artistic stylization shader for video games. It uses a novel three-layer hierarchy (Silhouette, Structure, Texture) and adaptive sensitivity to generate clean, stable, ink-style outlines that react dynamically to scene lighting and depth.

> **Paper Title:** AHEAD: Adaptive Hierarchical Edge Detection for Real-Time Artistic Stylization

---

## 📥 1. How to Install ReShade

To use this shader, you first need the ReShade injector.

1.  Download the latest version of ReShade from [https://reshade.me](https://reshade.me).
2.  Run the installer (`ReShade_Setup.exe`).
3.  **Select a Game:** Click "Browse" and find the executable (`.exe`) of the game you want to stylize (e.g., `TheWitcher3.exe`).
4.  **Select API:** Choose the rendering API the game uses (usually **DirectX 10/11/12** for modern games, or **Vulkan**).
5.  **Select Effects:** You can skip the standard effect packages if you only want to use AHEAD, or install "Standard Effects" to mix it with other filters.
6.  Finish the installation.

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

Below are results demonstrating the AHEAD shader in various game engines. (Click the image to view the full-res version)

| | |
|:-------------------------:|:-------------------------:|
| <img src="./Figures/Figure 2/Depth_Map.jpg" width="100%"/><br><b>Figure 1:</b> Comparison of Silhouette vs Texture layers.| <img src="./Figures/Figure 2/Normal_Map.jpg" width="100%"/><br><b>Figure 2:</b> Adaptive sensitivity in low-light scenes.|
| <img src="./Figures/Figure 5/Combined Pass.jpg" width="100%"/><br><b>Figure 3:</b> Result in <i>The Witcher 3</i> (Forest).| <img src="./Figures/Figure 5/Original.jpg" width="100%"/><br><b>Figure 4:</b> Result in <i>Cyberpunk 2077</i> (City).|
| <img src="./Figures/Figure 5/SilhouettePass_W1_4_849.jpg" width="100%"/><br><b>Figure 5:</b> Result in <i>The Walking Dead</i>.| <img src="./Figures/Figure 5/StructurePass_W2_1_000.jpg" width="100%"/><br><b>Figure 6:</b> Close-up on facial feature detection.|

---

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