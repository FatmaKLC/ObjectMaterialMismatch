# Material Appearance Affects Object Categorization  
[![DOI](https://img.shields.io/badge/DOI-10.5281%2Fzenodo.17670327-blue)](https://doi.org/10.5281/zenodo.17670327)

## Stimuli Availability

All stimuli used in the experiments (Original, Grayscale, Exploratory, and Line-Drawing sets)  
are publicly available via Zenodo and can be downloaded here:

🔗 **https://doi.org/10.5281/zenodo.17670327**

Because the stimulus folders exceed GitHub’s file size limits, they are hosted on Zenodo instead  
and linked to this repository.

---

## 📁 Experiment Code & Analysis Repository

This repository contains all MATLAB experiment scripts and statistical analysis code  
for the project **“Material Appearance Affects Object Categorization”** (working title).

The experiments investigate how changing material appearance (original vs. mismatched)  
affects visual object categorization behaviour.

---

## 📁 Repository Structure

```text
ObjectMaterialMismatch/
├── Experiments/
│   ├── Experiment 1 - Original/
│   │   └── Run_ObjectMaterialMismatch_GoNoGoTask.m
│   │
│   ├── Experiment 2 - Grayscale/
│   │   └── Run_ObjectMaterialMismatch_Grayscale_GoNoGoTask.m
│   │
│   └── Experiment 3 - Exploratory/
│       └── Run_DiagFam_Control_Exp.m
│
└── Analyses/
    ├── Experiment 1 - Original/
    │   ├── analyse_RT_RMANOVA_Category_ImageType.m
    │   └── analyse_Accuracy_RMANOVA_Category_ImageType.m
    │
    ├── Experiment 2 - Grayscale/
    │   ├── analyse_RT_Grayscale_RMANOVA_Category_ImageType.m
    │   └── analyse_Accuracy_Grayscale_RMANOVA_Category_ImageType.m
    │
    └── Experiment 3 - Exploratory/
        └── (analysis scripts to be added)
```
---

## 🧪 Experiment Overview

### **Experiment 1 – Original (Colour) Go/No-Go**
Participants press **ENTER** when an object from the target category appears.  
Stimulus types:
- **Original** material  
- **Material-mismatched** (“Rest”)

Script:  
`Experiments/Experiment 1 - Original/Run_ObjectMaterialMismatch_GoNoGoTask.m`

---

### **Experiment 2 – Grayscale Go/No-Go (Control)**
Identical to Experiment 1, but **all images are grayscale** to remove colour cues.

Script:  
`Experiments/Experiment 2 - Grayscale/Run_ObjectMaterialMismatch_Grayscale_GoNoGoTask.m`

---

### **Experiment 3 – Exploratory (Diagnosticity & Familiarity)**

Two blocks:

#### 1. Diagnosticity ratings (line drawings)
Participants rate:
- **How variable** the object's real-world material is  
- **How many materials** the object typically contains  

(0–1 sliders, two questions per image)

#### 2. Familiarity ranking
Participants rank 10 images (1 per category) from **most familiar → least familiar**.

Script:  
`Experiments/Experiment 3 - Exploratory/Run_DiagFam_Control_Exp.m`

---

## 📊 Analysis Scripts

MATLAB R2017b–R2023b compatible.

### **Experiment 1 Analysis (Colour)**
`Analyses/Experiment 1 - Original/`

Scripts:
- `Accuracy_LeaveOneOut_Model_SimpleEffectsIncluded.m`
- `RT_LeaveOneOut_Model_SimpleEffectsIncluded.m`
- `Plotting_RT_Accuracy_Manuscript.m`
- `Comparison_Colored_vs_Grayscale_Exps.m`  
  → compares mismatch effects between **Colour vs. Grayscale** using RM-ANOVA, mixed LME, Welch tests, bootstrapped CIs.

---

### **Experiment 2 Analysis (Grayscale)**
`Analyses/Experiment 2 - Grayscale/`

Scripts:
- `Accuracy_Grayscale_LeaveOneOut_Model_SimpleEffectsIncluded.m`
- `RT_Grayscale_LeaveOneOut_Model_SimpleEffectsIncluded.m`

---

### **Experiment 3 Analysis**
`Analyses/Experiment 3 - Exploratory/`

Scripts:
- `analyse_RT_Exploratory_mixedModel.m`
- `analyse_Accuracy_Exploratory_mixedModel.m`
- `summary_tables_Exploratory.m`
- `analyse_Exploratory_Reliability.m`

---

## 📦 Stimuli (Download via Zenodo)

Since GitHub rejects large folders, all stimuli are hosted on Zenodo.

### **Download Stimuli (Zenodo DOI)**  
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.17670327.svg)](https://doi.org/10.5281/zenodo.17670327)

Direct link:  
🔗 https://doi.org/10.5281/zenodo.17670327

### Zenodo Contents:
- `ImFolder - Original.zip`
- `ImFolder - Grayscale.zip`
- `ImFolder - Exploratory.zip`
- `ImFolderLineDrawing - Exploratory.zip`

Each ZIP follows the folder naming expected by the MATLAB scripts.

---

## ▶️ Running the Experiments

### Requirements:
- MATLAB (R2017b or later)
- Psychtoolbox 3
- Display resolution & viewing distance should match experiment constants

### To run an experiment:

```bash
cd Experiments/Experiment 1 - Original
Run_ObjectMaterialMismatch_GoNoGoTask
```
### Required stimulus folder names:

- ImFolder
- ImFolderGrayScale
- ImFolderLineDrawing


---


## 📈 Output Files

Each experiment saves:

- Trial-level responses table ("responses")
- Participant metadata (ID, gender, age)
- Reaction times (RT)
- Accuracy (raw [0 or 1])
- Category labels
- Block information (if applicable)

## 📈 Analysis Outputs

Analysis scripts in the Analyses/ directory generate:

- RM-ANOVA tables (with GG/HF corrected p-values)
- Bonferroni post-hoc comparisons
- Partial eta-squared effect sizes
- Mixed-effects models (overall + per-category)
- ΔRT mismatch indices (Other − Original)
- Welch tests & bootstrap confidence intervals
- Figures:
    – Reaction-time bar plots
    – Accuracy bar plots
    – Per-category comparison plots
    – Forest plots for ΔΔRT (Gray − Color)


---


## 🖊️ Citation / Author Information
### Material Appearance Affects Object Categorization

(working title)

#### Authors:

Fatma Kilic¹², Celine Aubuchon¹, Emily J. A-Izzeddin¹², Zoe R. Goll¹², Roland W. Fleming¹², Filipp Schmidt¹²

#### Affiliations:
¹ Department of Experimental Psychology, Justus Liebig University Giessen, 35394 Giessen, Germany
² Center for Mind, Brain and Behavior (CMBB), 35032 Marburg, Germany

#### Author Emails:
fatma.kilic@psychol.uni-giessen.de

celine.aubuchon@psychol.uni-giessen.de

emily.a-izzeddin@psychol.uni-giessen.de

zoe.r.goll@psychol.uni-giessen.de

roland.w.fleming@psychol.uni-giessen.de

filipp.schmidt@psychol.uni-giessen.de

A formal citation will be added upon publication.


---


## 🔒 License

To be added later (recommendation: MIT or CC-BY 4.0 for reproducible science).


---


## 📝 Notes

All analysis scripts are publication-ready and reproducible.

Stimuli are hosted externally due to size limits.
