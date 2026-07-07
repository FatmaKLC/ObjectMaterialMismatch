%% ==========================================================
%  Mixed-effects analysis for ACCURACY
%
%  Question:
%  Does material diagnosticity and/or familiarity explain the accuracy cost
%  for material-mismatched images compared with original images?
%
%  Logistic mixed-effects model:
%  Accuracy ~ ImageType*zComp + ImageType*zDiag + ImageType*zFam
%             + (1|Participant) + (1|Object)
%
%  ImageType reference level:
%  Original
%
%  Notes:
%  - zComp = standardized material composition rating
%  - zDiag = standardized diagnosticity score
%            computed by reversing material variability, so higher values
%            consistently mean higher material diagnosticity
%  - zFam  = standardized familiarity score
%% ==========================================================

clc;
clear;

%% ----------------------------------------------------------
% 1) File paths
%% ----------------------------------------------------------

projectRoot = 'C:\Users\JLU-SU\Documents\MATLAB\ObjectMaterialMismatch';

dataFile = fullfile(projectRoot, ...
    'OriginalExp', 'analysisFolder', 'Data Files', 'combinedData_ExpV2.mat');

diagFile = fullfile(projectRoot, ...
    'ControlExp', 'participantFolder', 'combinedData_diagnosticity.mat');

famFile = fullfile(projectRoot, ...
    'ControlExp', 'participantFolder', 'combinedData_familiarity.mat');

%% ----------------------------------------------------------
% 2) Load and prepare original experiment data
%% ----------------------------------------------------------

load(dataFile, 'combinedTable');
responseData = combinedTable;

responseData.Category   = normalizeCategoryNames(string(responseData.Category));
responseData.Subfolder  = normalizeCategoryNames(string(responseData.Subfolder));
responseData.ImageShown = string(responseData.ImageShown);

% Image type: Original vs Rest
isOriginal = contains(responseData.ImageShown, 'original', 'IgnoreCase', true);
imageType = repmat("Rest", height(responseData), 1);
imageType(isOriginal) = "Original";
responseData.ImageType = categorical(imageType);

% Participant ID: first token in ParticipantInfo, e.g., "Sub-01 ..." -> "Sub-01"
responseData.Participant = categorical(extractParticipantID(responseData.ParticipantInfo));

% Object name: first part of image filename, e.g., "Cow_original_..." -> "Cow"
responseData.Object = categorical(fixObjectNames(extractBefore(responseData.ImageShown, "_")));

%% ----------------------------------------------------------
% 3) Recalculate trial-level accuracy
%% ----------------------------------------------------------

% Go trials: correct category matches the shown object's subfolder
isGoTrial = responseData.Category == responseData.Subfolder;

% A valid response is any response with RT >= 0.1 s
% NoGo trials are correct when no valid response is made.
didRespond = ~isnan(responseData.ReactionTime) & responseData.ReactionTime >= 0.1;

responseData.Accuracy = (isGoTrial & didRespond) | (~isGoTrial & ~didRespond);

%% ----------------------------------------------------------
% 4) Load and summarize diagnosticity data
%% ----------------------------------------------------------

load(diagFile, 'combinedDiagnosticity');
diagTbl = ensureTable(combinedDiagnosticity);

diagTbl.imageName = string(diagTbl.imageName);
diagTbl.category  = normalizeCategoryNames(string(diagTbl.category));
diagTbl.Object    = fixObjectNames(extractBefore(diagTbl.imageName, "_"));

diagByObj = groupsummary(diagTbl, "Object", "mean", ...
    ["slider1_composition", "slider2_variability"]);

diagByObj = removevars(diagByObj, "GroupCount");
diagByObj = renamevars(diagByObj, ...
    ["mean_slider1_composition", "mean_slider2_variability"], ...
    ["meanMaterialComposition", "meanVariability"]);

diagByObj.Object = string(diagByObj.Object);

%% ----------------------------------------------------------
% 5) Load and summarize familiarity data
%% ----------------------------------------------------------

load(famFile, 'combinedFamiliarity');
famTbl = ensureTable(combinedFamiliarity);

famTbl.Filename = string(famTbl.Filename);
famTbl.Category = normalizeCategoryNames(string(famTbl.Category));
famTbl.Object   = fixObjectNames(extractBefore(famTbl.Filename, "_"));

% Familiarity score: 10 = most familiar, 1 = least familiar
famTbl.FamScore = 11 - famTbl.ClickRank;

famByObj = groupsummary(famTbl, "Object", "mean", "FamScore");
famByObj = removevars(famByObj, "GroupCount");
famByObj = renamevars(famByObj, "mean_FamScore", "meanFamiliarity");
famByObj.Object = string(famByObj.Object);

%% ----------------------------------------------------------
% 6) Merge object-level predictors and standardize them
%% ----------------------------------------------------------

diagFamByObj = outerjoin(diagByObj, famByObj, ...
    "Keys", "Object", ...
    "MergeKeys", true);

diagFamByObj.Object = string(diagFamByObj.Object);

diagFamByObj.zComp = standardizeOmitNaN(diagFamByObj.meanMaterialComposition);

% Higher raw variability means lower material diagnosticity.
% Therefore, reverse the standardized variability score.
diagFamByObj.zDiag = -standardizeOmitNaN(diagFamByObj.meanVariability);

diagFamByObj.zFam = standardizeOmitNaN(diagFamByObj.meanFamiliarity);

%% ----------------------------------------------------------
% 7) Join object-level predictors to trial-level data
%% ----------------------------------------------------------

accData = responseData;
accData.ObjectKey = string(accData.Object);
diagFamByObj.ObjectKey = string(diagFamByObj.Object);

accJoin = innerjoin(accData, diagFamByObj, ...
    "Keys", "ObjectKey", ...
    "RightVariables", {"meanMaterialComposition", "meanVariability", ...
                       "meanFamiliarity", "zComp", "zDiag", "zFam"});

accJoin.Object = categorical(accJoin.ObjectKey);

fprintf('ACCURACY: trials before join = %d, after join = %d\n', ...
    height(accData), height(accJoin));

%% ----------------------------------------------------------
% 8) Build model table
%% ----------------------------------------------------------

Tacc = table();
Tacc.Accuracy    = double(accJoin.Accuracy(:));
Tacc.ImageType   = categorical(accJoin.ImageType(:));
Tacc.Participant = categorical(accJoin.Participant(:));
Tacc.Object      = categorical(accJoin.Object(:));
Tacc.zComp       = double(accJoin.zComp(:));
Tacc.zDiag       = double(accJoin.zDiag(:));
Tacc.zFam        = double(accJoin.zFam(:));

Tacc = rmmissing(Tacc, 'DataVariables', ...
    {'Accuracy', 'ImageType', 'Participant', 'Object', 'zComp', 'zDiag', 'zFam'});

% Set Original as the reference level for ImageType.
if all(ismember({'Original', 'Rest'}, categories(Tacc.ImageType)))
    Tacc.ImageType = reordercats(Tacc.ImageType, {'Original', 'Rest'});
end

fprintf('Accuracy rows in model: %d\n', height(Tacc));
fprintf('Mean accuracy: %.3f\n', mean(Tacc.Accuracy));

%% ----------------------------------------------------------
% 9) Fit logistic mixed-effects model
%% ----------------------------------------------------------

formulaAcc = ['Accuracy ~ ImageType*zComp + ImageType*zDiag + ImageType*zFam ' ...
              '+ (1|Participant) + (1|Object)'];

mdlAcc = fitglme(Tacc, formulaAcc, ...
    'Distribution', 'Binomial', ...
    'Link', 'logit');

disp('Mixed-effects model for ACCURACY:');
disp(mdlAcc);

coefAcc = mdlAcc.Coefficients;

disp('Fixed effects:');
disp(coefAcc);

disp('ANOVA:');
disp(anova(mdlAcc));

%% ----------------------------------------------------------
% 10) Print key effects
%% ----------------------------------------------------------

namesAcc = string(coefAcc.Name);

idxImage = namesAcc == "ImageType_Rest";
idxComp  = namesAcc == "ImageType_Rest:zComp"  | namesAcc == "zComp:ImageType_Rest";
idxDiag  = namesAcc == "ImageType_Rest:zDiag"  | namesAcc == "zDiag:ImageType_Rest";
idxFam   = namesAcc == "ImageType_Rest:zFam"   | namesAcc == "zFam:ImageType_Rest";

fprintf('\n==================================================\n');
fprintf('KEY ACCURACY EFFECTS\n');
fprintf('Positive beta = higher accuracy / higher log-odds correct\n');
fprintf('Negative beta = lower accuracy / lower log-odds correct\n');
fprintf('==================================================\n');

[bImage, ~, ~, ~] = printEffect(coefAcc, idxImage, ...
    '[ACC] Main effect of ImageType: Rest vs Original');

if ~isnan(bImage)
    if bImage < 0
        fprintf('  Interpretation: Rest images are less accurate than Original images.\n');
    elseif bImage > 0
        fprintf('  Interpretation: Rest images are more accurate than Original images.\n');
    else
        fprintf('  Interpretation: No Rest vs Original accuracy difference.\n');
    end
end

printEffect(coefAcc, idxComp, ...
    '[ACC] ImageType(Rest vs Original) x Composition');

[bDiag, ~, ~, ~] = printEffect(coefAcc, idxDiag, ...
    '[ACC] ImageType(Rest vs Original) x Diagnosticity');

if ~isnan(bDiag)
    if bDiag < 0
        fprintf('  Interpretation: Higher diagnosticity is associated with a larger accuracy cost for Rest images relative to Original images.\n');
    elseif bDiag > 0
        fprintf('  Interpretation: Higher diagnosticity is associated with a smaller accuracy cost for Rest images relative to Original images.\n');
    else
        fprintf('  Interpretation: Diagnosticity does not modulate the Rest vs Original accuracy difference.\n');
    end
end

printEffect(coefAcc, idxFam, ...
    '[ACC] ImageType(Rest vs Original) x Familiarity');

%% ==========================================================
%  Local helper functions
%% ==========================================================

function T = ensureTable(x)
    if isstruct(x)
        T = struct2table(x);
    else
        T = x;
    end
end

function category = normalizeCategoryNames(category)
    category = replace(category, "animal", "Animal");
    category = replace(category, "vegetable", "Vegetable");
    category = replace(category, ...
        ["Musical Instrument", "Musical Instruments"], "Instrument");
end

function objectName = fixObjectNames(objectName)
    objectName = string(objectName);

    oldNames = [
        "WolkswagenKombi"
        "VolkswagenBettle"
        "Zuccini"
        "BedSideCupboard"
        "Cargopants"
        "CoffeeMachineRed"
    ];

    newNames = [
        "VolkswagenKombi"
        "VolkswagenBeetle"
        "Zucchini"
        "BedsideCupboard"
        "CargoPants"
        "CapsuleCoffeeMachine"
    ];

    for i = 1:numel(oldNames)
        objectName = replace(objectName, oldNames(i), newNames(i));
    end
end

function participantID = extractParticipantID(participantInfo)
    participantInfo = string(participantInfo);
    participantID = strings(numel(participantInfo), 1);

    for i = 1:numel(participantInfo)
        tokens = split(strtrim(participantInfo(i)));
        participantID(i) = tokens(1);
    end
end

function z = standardizeOmitNaN(x)
    x = double(x);
    z = (x - mean(x, 'omitnan')) ./ std(x, 'omitnan');
end

function [b, se, p, OR] = printEffect(coefTbl, idx, label)
    b = NaN;
    se = NaN;
    p = NaN;
    OR = NaN;

    if ~any(idx)
        fprintf('\n%s\n', label);
        fprintf('  Term not found in model coefficients.\n');
        return;
    end

    row = find(idx, 1);
    b = coefTbl.Estimate(row);
    se = coefTbl.SE(row);
    p = coefTbl.pValue(row);
    OR = exp(b);

    fprintf('\n%s\n', label);
    fprintf('  beta = %.4f, SE = %.4f, OR = %.3f, p = %.4f\n', b, se, OR, p);
end