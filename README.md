# Material Appearance Affects Object Categorization
Experiment Code & Analysis Repository

This repository contains all MATLAB code, stimulus folders, and statistical analysis scripts for the three experiments reported in "Material Appearance Affects Object Categorization" (working title).

The experiments investigate how material appearance (original vs mismatched surface materials) affects visual object categorization behaviour using Go/No-Go and rating tasks.

📂 Repository Structure
ObjectMaterialMismatch/
│
├── Experiments/
│   ├── Experiment 1 - Original/
│   │    └── Run_ObjectMaterialMismatch_GoNoGoTask.m
│   │
│   ├── Experiment 2 - Grayscale/
│   │    └── Run_ObjectMaterialMismatch_Grayscale_GoNoGoTask.m
│   │
│   └── Experiment 3 - Exploratory/
│        └── Run_DiagFam_Control_Exp.m
│
├── Stimuli/
│   ├── ImFolder - Original
│   ├── ImFolder - Grayscale
│   ├── ImFolder - Exploratory
│   └── ImFolderLineDrawing - Exploratory
│
└── Analyses/
    ├── Experiment 1 - Original/
    │     ├── analyse_RT_RMANOVA_Category_ImageType.m
    │     └── analyse_Accuracy_RMANOVA_Category_ImageType.m
    │
    ├── Experiment 2 - Grayscale/
    │     ├── analyse_RT_Grayscale_RMANOVA_Category_ImageType.m
    │     └── analyse_Accuracy_Grayscale_RMANOVA_Category_ImageType.m
    │
    └── Experiment 3 - Exploratory/
          └── (analysis scripts to be added)

🧪 Overview of Experiments
Experiment 1 – Original (Colour) Go/No-Go Task

Participants respond as fast as possible whenever an object from the target category appears.
Image types:

Original material

Material-mismatched (“Rest”)

Script:
Experiments/Experiment 1 - Original/Run_ObjectMaterialMismatch_GoNoGoTask.m

Experiment 2 – Grayscale Control Go/No-Go

Identical to Experiment 1, but all images are rendered in grayscale to remove colour cues.

Script:
Experiments/Experiment 2 - Grayscale/Run_ObjectMaterialMismatch_Grayscale_GoNoGoTask.m

Experiment 3 – Exploratory Diagnosticity & Familiarity Ratings

Two blocks:

Diagnosticity block (line drawings)
Participants rate:

How many materials the object is typically made of

How variable its material composition could be
(two sliders per image)

Familiarity ranking block
Participants rank 10 images (1 per category) from most to least familiar.

Script:
Experiments/Experiment 3 - Exploratory/Run_DiagFam_Control_Exp.m

📊 Analysis Scripts

All analysis scripts use MATLAB R2017b–R2023b compatible functions.

Experiment 1 Analysis (Colour)

Located in:

Analyses/Experiment 1 - Original/


Scripts:

analyse_RT_RMANOVA_Category_ImageType.m

analyse_Accuracy_RMANOVA_Category_ImageType.m

material_effect_color_vs_grayscale.m
→ compares mismatch effect between Colour vs Grayscale experiments (RM-ANOVA, LME, Welch tests).

Experiment 2 Analysis (Grayscale)

Located in:

Analyses/Experiment 2 - Grayscale/


Scripts:

analyse_RT_Grayscale_RMANOVA_Category_ImageType.m

analyse_Accuracy_Grayscale_RMANOVA_Category_ImageType.m

Experiment 3 Analysis

Will be added later; placeholder folder is ready.

📁 Stimuli Structure
Stimuli/
│
├── ImFolder - Original/
│     ├── Animal/
│     │     └── 10 subfolders (each 6 images)
│     ├── Appliance/
│     ├── ...
│
├── ImFolder - Grayscale/   (identical structure, grayscale)
│
├── ImFolder - Exploratory/  (material-swapped versions)
│
└── ImFolderLineDrawing - Exploratory/
      └── 8 categories × 10 line drawings


Participants see:

Original vs mismatched material versions (Exp 1 & 2)

Line drawings and original images (Exp 3)

▶️ Running the Experiments
Requirements

MATLAB (R2017b or later)

Psychtoolbox 3

Display resolution & viewing distance should match the values set in the scripts

To run:
cd Experiments/Experiment 1 - Original
Run_ObjectMaterialMismatch_GoNoGoTask


Stimuli folders must remain exactly named as:

ImFolder
ImFolderGrayScale
ImFolderLineDrawing


(or as the script currently references them).

📈 Outputs

Each experiment saves:

A "responses" table with trial-level data

Participant metadata (ID, gender, age)

Reaction times

Accuracy (calculated or recalculated)

Block/category information

Analysis scripts generate:

RM-ANOVA tables

Post-hoc tests (Bonferroni)

Partial eta-squared

LME models (overall & per category)

ΔRT mismatch indices

Figures (bar plots, forest plots)

🖊️ Citation / Author Information

Material Appearance Affects Object Categorization
(working title)

Authors:

Fatma Kilic¹²

Celine Aubuchon¹

Emily J. A-Izzeddin¹²

Zoe R. Goll¹²

Roland W. Fleming¹²

Filipp Schmidt¹²

Affiliations:
¹ Department of Experimental Psychology, Justus Liebig University Giessen, 35394 Giessen, Germany
² Center for Mind, Brain and Behavior (CMBB), 35032 Marburg, Germany

Author Emails:

fatma.kilic@psychol.uni-giessen.de

celine.aubuchon@psychol.uni-giessen.de

emily.a-izzeddin@psychol.uni-giessen.de

zoe.r.goll@psychol.uni-giessen.de

roland.w.fleming@psychol.uni-giessen.de

filipp.schmidt@psychol.uni-giessen.de

A formal citation entry will be added when the manuscript is published.

🔒 License

To be added depending on journal requirements (GPL-3, MIT, or CC-BY recommended for reproducible science).

📝 Notes

All analysis scripts are publication-ready and use reproducible statistics.

Stimuli cannot be redistributed unless permitted by copyright (remove them if needed before public release).

Code will remain private until manuscript submission; then it can be switched to public.
