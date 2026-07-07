%% ==========================================================
%  Mixed-effects analysis for REACTION TIME
%
%  Question:
%    Do diagnosticity and familiarity explain the RT cost of
%    material mismatch (Original vs Rest)?
%
%  Global model:
%    logRT ~ ImageType * zComp + ImageType * zDiag + ImageType * zFam
%            + (1|Participant) + (1|Object)
%
%  Predictors:
%    zComp = standardized material-composition rating
%    zDiag = inverted standardized variability rating
%            higher zDiag = higher material diagnosticity
%    zFam  = standardized familiarity rating
%
%  Interpretation:
%    A positive ImageType_Rest:zDiag coefficient means that higher
%    diagnosticity is associated with a larger RT cost for Rest images
%    relative to Original images.
%% ==========================================================

clc;
clear;

%% ----------------------------------------------------------
% 1) File paths and shared settings
%% ----------------------------------------------------------

baseDir = 'C:\Users\JLU-SU\Documents\MATLAB\ObjectMaterialMismatch';

responseFile = fullfile(baseDir, ...
    'OriginalExp', 'analysisFolder', 'Data Files', 'combinedData_ExpV2.mat');

diagFile = fullfile(baseDir, ...
    'ControlExp', 'participantFolder', 'combinedData_diagnosticity.mat');

famFile = fullfile(baseDir, ...
    'ControlExp', 'participantFolder', 'combinedData_familiarity.mat');

objectCorrections = {
    'WolkswagenKombi',   'VolkswagenKombi'
    'VolkswagenBettle',  'VolkswagenBeetle'
    'Zuccini',           'Zucchini'
    'BedSideCupboard',   'BedsideCupboard'
    'Cargopants',        'CargoPants'
    'CoffeeMachineRed',  'CapsuleCoffeeMachine'
};

%% ----------------------------------------------------------
% 2) Load and prepare trial-level RT data
%% ----------------------------------------------------------

responseData = loadResponseData(responseFile, objectCorrections);
rtData       = keepValidGoRTTrials(responseData);

fprintf('Valid RT trials before object-level join: %d\n', height(rtData));

%% ----------------------------------------------------------
% 3) Load object-level predictors
%% ----------------------------------------------------------

diagByObj    = loadDiagnosticityByObject(diagFile, objectCorrections);
famByObj     = loadFamiliarityByObject(famFile, objectCorrections);
predictorTbl = makeObjectPredictorTable(diagByObj, famByObj);

%% ----------------------------------------------------------
% 4) Join predictors into trial-level RT data
%% ----------------------------------------------------------

rtJoin = joinPredictorsToTrials(rtData, predictorTbl);

fprintf('Valid RT trials after object-level join: %d\n', height(rtJoin));

%% ----------------------------------------------------------
% 5) Fit global mixed-effects model
%% ----------------------------------------------------------

T = makeGlobalRTModelTable(rtJoin);

formula = ['logRT ~ ImageType * zComp + ImageType * zDiag + ImageType * zFam ' ...
           '+ (1|Participant) + (1|Object)'];

mdlMixed = fitlme(T, formula);
coefTbl  = mdlMixed.Coefficients;

fprintf('\n==================================================\n');
fprintf('GLOBAL MIXED-EFFECTS MODEL\n');
fprintf('==================================================\n');
disp(mdlMixed);

fprintf('\nFixed effects:\n');
disp(coefTbl);

%% ----------------------------------------------------------
% 6) Print key global interaction terms
%% ----------------------------------------------------------

printRTInteractionSummary(coefTbl);

%% ----------------------------------------------------------
% 7) Plot global interaction beta coefficients
%% ----------------------------------------------------------

plotGlobalInteractionBetas(mdlMixed);

%% ----------------------------------------------------------
% 8) Fit per-category mixed models
%% ----------------------------------------------------------

categoryResults = fitPerCategoryRTModels(rtJoin);

fprintf('\n===== Per-category mixed-model interaction results =====\n');
disp(categoryResults);

%% ----------------------------------------------------------
% 9) Object-level descriptive plots
%% ----------------------------------------------------------

objLevel = makeObjectLevelRTTable(rtJoin);

facetRTByPredictorObjects(objLevel, ...
    'zComp', ...
    'Material Composition (z)', ...
    'RT by Material Composition (Original vs Rest)');

facetRTByPredictorObjects(objLevel, ...
    'zDiag', ...
    'Material Diagnosticity (z, inverted variability)', ...
    'RT by Material Diagnosticity (Original vs Rest)');

facetRTByPredictorObjects(objLevel, ...
    'zFam', ...
    'Familiarity (z)', ...
    'RT by Familiarity (Original vs Rest)');

%% ==========================================================
% Local helper functions
%% ==========================================================

function responseData = loadResponseData(responseFile, objectCorrections)

    load(responseFile, 'combinedTable');
    responseData = combinedTable;

    responseData.Category   = normalizeCategoryNames(responseData.Category);
    responseData.Subfolder  = normalizeCategoryNames(responseData.Subfolder);
    responseData.ImageShown = string(responseData.ImageShown);

    isOriginal = contains(lower(responseData.ImageShown), 'original');

    imageType = repmat("Rest", height(responseData), 1);
    imageType(isOriginal) = "Original";
    responseData.ImageType = categorical(imageType, {'Original','Rest'});

    participantText = string(responseData.ParticipantInfo);
    responseData.Participant = categorical(extractBefore(participantText + " ", " "));

    objectNames = extractBefore(responseData.ImageShown, "_");
    objectNames = applyObjectNameCorrections(objectNames, objectCorrections);
    responseData.Object = categorical(objectNames);

end

function rtData = keepValidGoRTTrials(responseData)

    isGoTrial = responseData.Category == responseData.Subfolder;

    didRespond = ~isnan(responseData.ReactionTime) & ...
                 responseData.ReactionTime >= 0.1;

    rtData = responseData(isGoTrial & didRespond, :);

    rtData.ImageType   = categorical(string(rtData.ImageType), {'Original','Rest'});
    rtData.Participant = categorical(rtData.Participant);
    rtData.Object      = categorical(rtData.Object);
    rtData.Category    = categorical(rtData.Category);

    rtData.logRT = log(rtData.ReactionTime);

end

function diagByObj = loadDiagnosticityByObject(diagFile, objectCorrections)

    load(diagFile, 'combinedDiagnosticity');
    diagTbl = ensureTable(combinedDiagnosticity);

    diagTbl.imageName = string(diagTbl.imageName);
    diagTbl.category  = normalizeCategoryNames(diagTbl.category);

    objectNames = extractBefore(diagTbl.imageName, "_");
    diagTbl.Object = applyObjectNameCorrections(objectNames, objectCorrections);

    diagByObj = groupsummary(diagTbl, "Object", "mean", ...
        ["slider1_composition", "slider2_variability"]);

    diagByObj = removevars(diagByObj, "GroupCount");
    diagByObj.Properties.VariableNames = ...
        {'Object', 'meanMaterialComposition', 'meanVariability'};

    diagByObj.Object = string(diagByObj.Object);

end

function famByObj = loadFamiliarityByObject(famFile, objectCorrections)

    load(famFile, 'combinedFamiliarity');
    famTbl = ensureTable(combinedFamiliarity);

    famTbl.Filename = string(famTbl.Filename);
    famTbl.Category = normalizeCategoryNames(famTbl.Category);

    objectNames = extractBefore(famTbl.Filename, "_");
    famTbl.Object = applyObjectNameCorrections(objectNames, objectCorrections);

    % Familiarity score: 10 = most familiar, 1 = least familiar.
    famTbl.FamScore = 11 - famTbl.ClickRank;

    famByObj = groupsummary(famTbl, "Object", "mean", "FamScore");
    famByObj = removevars(famByObj, "GroupCount");
    famByObj.Properties.VariableNames = {'Object', 'meanFamiliarity'};
    famByObj.Object = string(famByObj.Object);

end

function predictorTbl = makeObjectPredictorTable(diagByObj, famByObj)

    predictorTbl = outerjoin(diagByObj, famByObj, ...
        'Keys', 'Object', ...
        'MergeKeys', true);

    predictorTbl.Object = string(predictorTbl.Object);

    predictorTbl.zComp = zscoreOmitNan(predictorTbl.meanMaterialComposition);

    % Higher raw variability = lower material diagnosticity.
    predictorTbl.zVar  = zscoreOmitNan(predictorTbl.meanVariability);
    predictorTbl.zDiag = -predictorTbl.zVar;

    predictorTbl.zFam = zscoreOmitNan(predictorTbl.meanFamiliarity);

end

function rtJoin = joinPredictorsToTrials(rtData, predictorTbl)

    rtData.ObjectStr = string(rtData.Object);

    missingMask = ~ismember(rtData.ObjectStr, predictorTbl.Object);
    missingTrials = rtData(missingMask, :);

    fprintf('RT trials missing diagnosticity/familiarity info: %d\n', ...
        height(missingTrials));

    if ~isempty(missingTrials)
        objCounts = groupsummary(missingTrials, "Object");
        objCounts.Properties.VariableNames(end) = "Ntrials";

        disp('Objects with missing diagnosticity/familiarity info:');
        disp(objCounts);
    end

    predictorTblForJoin = renamevars(predictorTbl, 'Object', 'ObjectStr');

    rtJoin = innerjoin(rtData, predictorTblForJoin, 'Keys', 'ObjectStr');

    rtJoin.Object = categorical(rtJoin.ObjectStr);
    rtJoin = removevars(rtJoin, 'ObjectStr');

    rtJoin.ImageType = categorical(string(rtJoin.ImageType), {'Original','Rest'});
    rtJoin.Category  = categorical(rtJoin.Category);

end

function T = makeGlobalRTModelTable(rtJoin)

    T = table();

    T.logRT       = double(rtJoin.logRT);
    T.ImageType   = categorical(string(rtJoin.ImageType), {'Original','Rest'});
    T.Participant = categorical(rtJoin.Participant);
    T.Object      = categorical(rtJoin.Object);

    T.zComp = double(rtJoin.zComp);
    T.zDiag = double(rtJoin.zDiag);
    T.zFam  = double(rtJoin.zFam);

    T = rmmissing(T, 'DataVariables', ...
        {'logRT','ImageType','Participant','Object','zComp','zDiag','zFam'});

end

function printRTInteractionSummary(coefTbl)

    fprintf('\n==================================================\n');
    fprintf('GLOBAL RT INTERACTION EFFECTS\n');
    fprintf('Positive beta = larger RT cost for Rest vs Original\n');
    fprintf('Negative beta = smaller RT cost for Rest vs Original\n');
    fprintf('==================================================\n');

    printOneRTInteraction(coefTbl, 'zComp', 'Composition', false);
    printOneRTInteraction(coefTbl, 'zDiag', 'Diagnosticity', true);
    printOneRTInteraction(coefTbl, 'zFam',  'Familiarity', false);

end

function printOneRTInteraction(coefTbl, predictorName, label, includeInterpretation)

    idx = findInteractionRow(coefTbl, predictorName);

    if isempty(idx)
        fprintf('\n[Warning] Could not find interaction term for ImageType x %s.\n', predictorName);
        return;
    end

    beta = coefTbl.Estimate(idx);
    se   = coefTbl.SE(idx);
    p    = coefTbl.pValue(idx);

    fprintf('\n[RT] ImageType(Rest vs Original) x %s\n', label);
    fprintf('  beta = %.4f, SE = %.4f, p = %.4f\n', beta, se, p);

    if includeInterpretation
        if beta > 0
            fprintf('  Interpretation: Higher diagnosticity is associated with a larger RT cost for Rest images relative to Original images.\n');
        elseif beta < 0
            fprintf('  Interpretation: Higher diagnosticity is associated with a smaller RT cost for Rest images relative to Original images.\n');
        else
            fprintf('  Interpretation: Diagnosticity does not modulate the Rest vs Original RT difference.\n');
        end
    end

end

function plotGlobalInteractionBetas(mdlMixed)

    coefTbl = mdlMixed.Coefficients;

    if ~istable(coefTbl)
        coefTbl = dataset2table(coefTbl);  % compatibility with older MATLAB versions
    end

    predictorNames = {'zComp', 'zDiag', 'zFam'};
    prettyLabels   = {'Composition', 'Diagnosticity', 'Familiarity'};

    nTerms = numel(predictorNames);
    beta   = nan(nTerms, 1);
    ciLow  = nan(nTerms, 1);
    ciHigh = nan(nTerms, 1);
    pVals  = nan(nTerms, 1);

    for k = 1:nTerms
        idx = findInteractionRow(coefTbl, predictorNames{k});

        if isempty(idx)
            warning('Interaction term for ImageType x %s not found.', predictorNames{k});
            continue;
        end

        beta(k) = coefTbl.Estimate(idx);

        if all(ismember({'Lower','Upper'}, coefTbl.Properties.VariableNames))
            ciLow(k)  = coefTbl.Lower(idx);
            ciHigh(k) = coefTbl.Upper(idx);
        else
            ciLow(k)  = beta(k) - 1.96 * coefTbl.SE(idx);
            ciHigh(k) = beta(k) + 1.96 * coefTbl.SE(idx);
        end

        pVals(k) = coefTbl.pValue(idx);
    end

    figure('Position', [200 200 600 400]);
    hold on;

    bar(1:nTerms, beta, ...
        'FaceColor', [0.70 0.70 0.70], ...
        'EdgeColor', 'none');

    errorbar(1:nTerms, beta, beta - ciLow, ciHigh - beta, ...
        'k', ...
        'LineStyle', 'none', ...
        'LineWidth', 1.5, ...
        'CapSize', 10);

    yline(0, 'k-');

    set(gca, ...
        'XTick', 1:nTerms, ...
        'XTickLabel', prettyLabels, ...
        'FontSize', 12, ...
        'FontName', 'Arial');

    ylabel('\beta interaction with ImageType: Rest vs Original');
    title('Global mixed model: predictors of material mismatch RT cost');
    box off;

    disp(table(prettyLabels(:), beta, pVals, ...
        'VariableNames', {'Predictor','Beta','pValue'}));

end

function results = fitPerCategoryRTModels(rtJoin)

    rtJoin.ImageType   = categorical(string(rtJoin.ImageType), {'Original','Rest'});
    rtJoin.Category    = categorical(rtJoin.Category);
    rtJoin.Participant = categorical(rtJoin.Participant);

    cats  = categories(rtJoin.Category);
    nCats = numel(cats);

    results = table( ...
        strings(nCats, 1), ...
        nan(nCats, 1), ...
        nan(nCats, 1), nan(nCats, 1), ...
        nan(nCats, 1), nan(nCats, 1), ...
        nan(nCats, 1), nan(nCats, 1), ...
        'VariableNames', { ...
            'Category','nTrials', ...
            'betaComp','pComp', ...
            'betaDiag','pDiag', ...
            'betaFam','pFam'});

    for i = 1:nCats
        thisCat = cats{i};
        Tcat = makeCategoryModelTable(rtJoin, thisCat);

        results.Category(i) = string(thisCat);
        results.nTrials(i)  = height(Tcat);

        if numel(categories(removecats(Tcat.ImageType))) < 2
            warning('Category %s has only one ImageType level; skipping.', thisCat);
            continue;
        end

        [results.betaComp(i), results.pComp(i)] = ...
            fitSingleCategoryPredictor(Tcat, 'zComp', thisCat, 'composition');

        [results.betaDiag(i), results.pDiag(i)] = ...
            fitSingleCategoryPredictor(Tcat, 'zDiag', thisCat, 'diagnosticity');

        [results.betaFam(i), results.pFam(i)] = ...
            fitSingleCategoryPredictor(Tcat, 'zFam', thisCat, 'familiarity');
    end

end

function Tcat = makeCategoryModelTable(rtJoin, categoryName)

    sub = rtJoin(rtJoin.Category == categoryName, :);

    Tcat = table();
    Tcat.logRT       = double(sub.logRT);
    Tcat.ImageType   = categorical(string(sub.ImageType), {'Original','Rest'});
    Tcat.Participant = categorical(sub.Participant);
    Tcat.zComp       = double(sub.zComp);
    Tcat.zDiag       = double(sub.zDiag);
    Tcat.zFam        = double(sub.zFam);

end

function [beta, pValue] = fitSingleCategoryPredictor(Tcat, predictorName, categoryName, label)

    beta   = NaN;
    pValue = NaN;

    valid = ~isnan(Tcat.logRT) & ~isnan(Tcat.(predictorName));
    thisData = Tcat(valid, {'logRT','ImageType','Participant', predictorName});
    thisData.ImageType = removecats(thisData.ImageType);

    if height(thisData) <= 50
        warning('Category %s: too few valid trials for %s model.', categoryName, label);
        return;
    end

    if numel(categories(thisData.ImageType)) < 2
        warning('Category %s: only one ImageType level for %s model.', categoryName, label);
        return;
    end

    if all(ismember({'Original','Rest'}, categories(thisData.ImageType)))
        thisData.ImageType = reordercats(thisData.ImageType, {'Original','Rest'});
    end

    formula = sprintf('logRT ~ ImageType * %s + (1|Participant)', predictorName);
    mdl = fitlme(thisData, formula);

    coefTbl = mdl.Coefficients;
    idx = findInteractionRow(coefTbl, predictorName);

    if ~isempty(idx)
        beta   = coefTbl.Estimate(idx);
        pValue = coefTbl.pValue(idx);
    end

end

function objLevel = makeObjectLevelRTTable(rtJoin)

    [G_rt, obj_rt, cat_rt, type_rt] = findgroups( ...
        rtJoin.Object, rtJoin.Category, rtJoin.ImageType);

    meanRT = splitapply(@mean, rtJoin.ReactionTime, G_rt);

    rtLong = table(string(obj_rt), categorical(cat_rt), categorical(type_rt), meanRT, ...
        'VariableNames', {'Object','Category','ImageType','MeanRT'});

    rtWide = unstack(rtLong, 'MeanRT', 'ImageType');

    if any(strcmp(rtWide.Properties.VariableNames, 'Original'))
        rtWide.Properties.VariableNames{'Original'} = 'RT_original';
    end

    if any(strcmp(rtWide.Properties.VariableNames, 'Rest'))
        rtWide.Properties.VariableNames{'Rest'} = 'RT_rest';
    end

    [G_pred, obj_pred, cat_pred] = findgroups(rtJoin.Object, rtJoin.Category);

    predTbl = table( ...
        string(obj_pred), ...
        categorical(cat_pred), ...
        splitapply(@mean, rtJoin.meanMaterialComposition, G_pred), ...
        splitapply(@mean, rtJoin.meanVariability, G_pred), ...
        splitapply(@mean, rtJoin.meanFamiliarity, G_pred), ...
        splitapply(@mean, rtJoin.zComp, G_pred), ...
        splitapply(@mean, rtJoin.zDiag, G_pred), ...
        splitapply(@mean, rtJoin.zFam, G_pred), ...
        'VariableNames', { ...
            'Object','Category', ...
            'meanMaterialComposition','meanVariability','meanFamiliarity', ...
            'zComp','zDiag','zFam'});

    objLevel = innerjoin(rtWide, predTbl, 'Keys', {'Object','Category'});
    objLevel.Category = categorical(objLevel.Category);

end

function facetRTByPredictorObjects(objLevel, predictorVar, predictorLabel, figTitle)

    requiredVars = {'RT_original', 'RT_rest', predictorVar};

    if ~all(ismember(requiredVars, objLevel.Properties.VariableNames))
        warning('Skipping plot "%s" because one or more required variables are missing.', figTitle);
        return;
    end

    objLevel.Category = categorical(objLevel.Category);

    cats  = categories(objLevel.Category);
    nCats = numel(cats);

    nCols = min(4, max(1, ceil(sqrt(nCats))));
    nRows = ceil(nCats / nCols);

    figure('Position', [100 100 1400 600]);

    tlo = tiledlayout(nRows, nCols, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');

    title(tlo, figTitle);

    legendHandles = gobjects(2, 1);

    for i = 1:nCats
        thisCat = cats{i};

        ax = nexttile;
        hold(ax, 'on');

        sub = objLevel(objLevel.Category == thisCat, :);

        x    = sub.(predictorVar);
        yOri = sub.RT_original;
        yRes = sub.RT_rest;

        valid = ~isnan(x) & ~isnan(yOri) & ~isnan(yRes);

        x    = x(valid);
        yOri = yOri(valid);
        yRes = yRes(valid);

        [xSorted, sortIdx] = sort(x);
        yOri = yOri(sortIdx);
        yRes = yRes(sortIdx);

        h1 = plot(ax, xSorted, yOri, 'o-', ...
            'MarkerFaceColor', [0 0.4470 0.7410], ...
            'Color', [0 0.4470 0.7410]);

        h2 = plot(ax, xSorted, yRes, 's-', ...
            'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
            'Color', [0.8500 0.3250 0.0980]);

        if i == 1
            legendHandles = [h1; h2];
        end

        xlabel(ax, predictorLabel);
        ylabel(ax, 'Reaction Time (s)');
        title(ax, char(thisCat));

        box(ax, 'off');
        grid(ax, 'off');
    end

    leg = legend(legendHandles, {'Original','Rest'}, ...
        'Location', 'southoutside', ...
        'Orientation', 'horizontal');
    leg.Box = 'off';

end

function idx = findInteractionRow(coefTbl, predictorName)

    names = string(coefTbl.Name);

    idx = find(names == "ImageType_Rest:" + predictorName | ...
               names == predictorName + ":ImageType_Rest", 1);

end

function categoryNames = normalizeCategoryNames(categoryNames)

    categoryNames = string(categoryNames);

    categoryNames = replace(categoryNames, "animal", "Animal");
    categoryNames = replace(categoryNames, "vegetable", "Vegetable");
    categoryNames = replace(categoryNames, ...
        ["Musical Instrument", "Musical Instruments"], ...
        "Instrument");

end

function objectNames = applyObjectNameCorrections(objectNames, objectCorrections)

    objectNames = string(objectNames);

    for k = 1:size(objectCorrections, 1)
        objectNames = replace(objectNames, ...
            objectCorrections{k, 1}, ...
            objectCorrections{k, 2});
    end

end

function T = ensureTable(data)

    if isstruct(data)
        T = struct2table(data);
    else
        T = data;
    end

end

function z = zscoreOmitNan(x)

    mu = mean(x, 'omitnan');
    sigma = std(x, 'omitnan');

    if sigma == 0 || isnan(sigma)
        z = nan(size(x));
    else
        z = (x - mu) ./ sigma;
    end

end
