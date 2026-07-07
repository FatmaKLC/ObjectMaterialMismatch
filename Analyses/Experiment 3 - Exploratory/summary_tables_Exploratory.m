%% ==========================================================
%  Summary tables and plots for Experiment 3 exploratory predictors
%
%  Computes object-level summaries for:
%    - Material composition / heterogeneity
%    - Material diagnosticity, defined as inverted material variability
%    - Familiarity
%
%  Also produces:
%    - Grouped bar plots by category
%    - Correlations between familiarity and diagnosticity
%
%  Input files:
%    - combinedData_diagnosticity.mat  (variable: combinedDiagnosticity)
%    - combinedData_familiarity.mat    (variable: combinedFamiliarity)
%% ==========================================================

clc; clear;

%% ----------------------------------------------------------
% 1) Settings and paths
%% ----------------------------------------------------------

baseDir = 'C:\Users\JLU-SU\Documents\MATLAB\ObjectMaterialMismatch\ControlExp\participantFolder';

diagFile = fullfile(baseDir, 'combinedData_diagnosticity.mat');
famFile  = fullfile(baseDir, 'combinedData_familiarity.mat');

% Diagnosticity is calculated as an inverted variability score.
% The current control-task slider is assumed to range from 0 to 1.
variabilityScaleMin = 0;
variabilityScaleMax = 1;

% Known object-name corrections used across the analysis scripts
objectCorrections = {
    'WolkswagenKombi',   'VolkswagenKombi'
    'VolkswagenBettle',  'VolkswagenBeetle'
    'Zuccini',           'Zucchini'
    'BedSideCupboard',   'BedsideCupboard'
    'Cargopants',        'CargoPants'
    'CoffeeMachineRed',  'CapsuleCoffeeMachine'
};

% Plot colors
plotColors.composition   = [0.55 0.35 0.75];   % purple
plotColors.diagnosticity = [0.20 0.60 0.55];   % teal
plotColors.familiarity   = [0.45 0.45 0.45];   % gray
plotColors.meanLine      = [0.00 0.00 0.00];   % black

%% ----------------------------------------------------------
% 2) Load and summarize diagnosticity data
%% ----------------------------------------------------------

load(diagFile, 'combinedDiagnosticity');

diagTbl = ensure_table(combinedDiagnosticity);
diagTbl.imageName = string(diagTbl.imageName);
diagTbl.category  = clean_category_names(string(diagTbl.category));

diagTbl.Object = extract_object_name(diagTbl.imageName);
diagTbl.Object = apply_object_corrections(diagTbl.Object, objectCorrections);

diagByObj = groupsummary(diagTbl, "Object", "mean", ...
    ["slider1_composition", "slider2_variability"]);

diagByObj = removevars(diagByObj, "GroupCount");
diagByObj.Properties.VariableNames = ...
    ["Object", "meanMaterialComposition", "meanVariability"];

diagByObj.Object = string(diagByObj.Object);

% Higher variability means lower material diagnosticity.
% Therefore, invert the variability scale.
diagByObj.meanDiagnosticity = invert_scale( ...
    diagByObj.meanVariability, variabilityScaleMin, variabilityScaleMax);

% Add one category label per object.
diagObjCat = object_category_table(diagTbl.Object, diagTbl.category);
diagByObj  = join(diagByObj, diagObjCat, "Keys", "Object");

disp('Diagnosticity summary:');
disp(summary(diagByObj));

print_stats('Composition', diagByObj.meanMaterialComposition);
print_stats('Diagnosticity', diagByObj.meanDiagnosticity);
print_stats('Raw material-range rating before inversion', diagByObj.meanVariability);

%% ----------------------------------------------------------
% 3) Build grouped and sorted diagnosticity table
%% ----------------------------------------------------------

% Objects are grouped by category and sorted within each category by
% material composition / heterogeneity.
categoryOrder = unique(string(diagByObj.Category), 'stable');

groupedSorted = sort_objects_within_categories( ...
    diagByObj, categoryOrder, "meanMaterialComposition", "descend");

%% ----------------------------------------------------------
% 4) Load and summarize familiarity data
%% ----------------------------------------------------------

load(famFile, 'combinedFamiliarity');

famTbl = ensure_table(combinedFamiliarity);
famTbl.Filename = string(famTbl.Filename);
famTbl.Category = clean_category_names(string(famTbl.Category));

famTbl.Object = extract_object_name(famTbl.Filename);
famTbl.Object = apply_object_corrections(famTbl.Object, objectCorrections);

% Original ranking: 1 = most familiar, 10 = least familiar.
famTbl.Rank = famTbl.ClickRank;

% More intuitive familiarity score:
% 10 = most familiar, 1 = least familiar.
famTbl.FamScore = 11 - famTbl.Rank;

famByObj = groupsummary(famTbl, "Object", "mean", ["Rank", "FamScore"]);
famByObj = removevars(famByObj, "GroupCount");
famByObj.Properties.VariableNames = ["Object", "meanRank", "meanFamiliarity"];
famByObj.Object = string(famByObj.Object);

% Add one category label per object.
famObjCat = object_category_table(famTbl.Object, famTbl.Category);
famByObj  = join(famByObj, famObjCat, "Keys", "Object");

disp('Familiarity summary:');
disp(summary(famByObj));

print_stats('Familiarity score', famByObj.meanFamiliarity);

%% ----------------------------------------------------------
% 5) Plot composition, diagnosticity, and familiarity
%% ----------------------------------------------------------

% Align familiarity to the diagnosticity/order table.
[famAligned, groupedSortedFam] = align_familiarity_to_diagnosticity_order( ...
    famByObj, groupedSorted);

figure('Position', [100 100 1400 900]);

% 5.1 Material composition / heterogeneity
subplot(3, 1, 1);
plot_grouped_bars( ...
    groupedSorted.meanMaterialComposition, ...
    groupedSorted.Category, ...
    categoryOrder, ...
    plotColors.composition, ...
    plotColors.meanLine, ...
    'Mean Material Heterogeneity', ...
    '', ...
    '', ...
    [0 1], ...
    false);

% 5.2 Material diagnosticity
subplot(3, 1, 2);
plot_grouped_bars( ...
    groupedSorted.meanDiagnosticity, ...
    groupedSorted.Category, ...
    categoryOrder, ...
    plotColors.diagnosticity, ...
    plotColors.meanLine, ...
    'Mean Material Diagnosticity', ...
    '', ...
    '', ...
    [0 1], ...
    false);

% 5.3 Familiarity
subplot(3, 1, 3);
plot_grouped_bars( ...
    famAligned.meanFamiliarity, ...
    groupedSortedFam.Category, ...
    categoryOrder, ...
    plotColors.familiarity, ...
    plotColors.meanLine, ...
    'Mean Familiarity (10 = most familiar)', ...
    'Objects grouped by category and sorted within category by material heterogeneity', ...
    famAligned.Object, ...
    [0 10], ...
    true);

%% ----------------------------------------------------------
% 6) Correlations between familiarity and diagnosticity
%% ----------------------------------------------------------

FD = outerjoin(famByObj, diagByObj, ...
               "Keys", "Object", ...
               "MergeKeys", true);

[rFamDiag, pFamDiag] = corr( ...
    FD.meanFamiliarity, ...
    FD.meanDiagnosticity, ...
    'Rows', 'complete');

fprintf('\nCorrelation Familiarity ~ Diagnosticity: r = %.3f, p = %.4f\n', ...
    rFamDiag, pFamDiag);

% Diagnostic check only:
% Higher raw variability means lower diagnosticity.
[rFamRawRange, pFamRawRange] = corr( ...
    FD.meanFamiliarity, ...
    FD.meanVariability, ...
    'Rows', 'complete');

fprintf('Correlation Familiarity ~ Raw material-range rating: r = %.3f, p = %.4f\n', ...
    rFamRawRange, pFamRawRange);

%% ==========================================================
% Helper functions
%% ==========================================================

function T = ensure_table(x)
% Return input as a table, whether it was saved as a struct or table.

if isstruct(x)
    T = struct2table(x);
else
    T = x;
end

end

function category = clean_category_names(category)
% Harmonize category labels across files.

category = string(category);

category = replace(category, "animal", "Animal");
category = replace(category, "vegetable", "Vegetable");
category = replace(category, ["Musical Instrument", "Musical Instruments"], "Instrument");

end

function object = extract_object_name(fileNames)
% Extract object name before the first underscore.

fileNames = string(fileNames);
object = extractBefore(fileNames, "_");
object = string(object);

end

function object = apply_object_corrections(object, corrections)
% Apply known spelling/name corrections.

object = string(object);

for k = 1:size(corrections, 1)
    object = replace(object, corrections{k, 1}, corrections{k, 2});
end

end

function y = invert_scale(x, scaleMin, scaleMax)
% Invert a score on a bounded scale.
% Example for a 0-1 scale: y = 1 - x.
% Example for a 1-10 scale: y = 11 - x.

if any(x < scaleMin | x > scaleMax, 'all', 'omitnan')
    warning(['Some variability values fall outside the configured scale ' ...
             '[%.2f, %.2f]. Check variabilityScaleMin/Max.'], ...
             scaleMin, scaleMax);
end

y = scaleMax + scaleMin - x;

end

function objCat = object_category_table(object, category)
% Return one stable category label per object.

object   = string(object);
category = string(category);

[uniqueObjects, idx] = unique(object, 'stable');

objCat = table(uniqueObjects, category(idx), ...
    'VariableNames', {'Object', 'Category'});

objCat.Object   = string(objCat.Object);
objCat.Category = string(objCat.Category);

end

function print_stats(label, values)
% Print mean, SD, min, and max for a numeric vector.

fprintf('%s stats: mean=%.2f, std=%.2f, min=%.2f, max=%.2f\n', ...
    label, ...
    mean(values, 'omitnan'), ...
    std(values, 'omitnan'), ...
    min(values), ...
    max(values));

end

function sortedTable = sort_objects_within_categories(T, categoryOrder, sortVar, direction)
% Group by category and sort objects within each category.

sortedTable = table();

for i = 1:numel(categoryOrder)
    thisCat = categoryOrder(i);

    temp = T(string(T.Category) == thisCat, :);
    temp = sortrows(temp, sortVar, direction);

    sortedTable = [sortedTable; temp]; %#ok<AGROW>
end

end

function [famAligned, groupedSortedFam] = align_familiarity_to_diagnosticity_order(famByObj, groupedSorted)
% Reorder familiarity rows to match the diagnosticity object order.

fixedOrder = groupedSorted.Object;

[isFound, famIdx] = ismember(fixedOrder, famByObj.Object);

missingObjects = fixedOrder(~isFound);

if ~isempty(missingObjects)
    disp('Objects in diagnosticity table but missing in familiarity table:');
    disp(missingObjects);
    warning('Some objects are missing from famByObj and will be removed from the familiarity plot.');
end

validRows = famIdx > 0;

famAligned      = famByObj(famIdx(validRows), :);
groupedSortedFam = groupedSorted(validRows, :);

end

function plot_grouped_bars(values, categoriesForRows, categoryOrder, barColor, meanLineColor, ...
                           yLabelText, xLabelText, xTickLabels, yLimits, showXLabels)
% Plot grouped bars with category separator lines, category labels, and
% category-level mean lines.

bar(values, ...
    'FaceColor', barColor, ...
    'EdgeColor', 'none');

ylabel(yLabelText);
xlabel(xLabelText);

if showXLabels
    xticks(1:numel(xTickLabels));
    xticklabels(xTickLabels);
    xtickangle(45);
else
    xticks([]);
    xticklabels([]);
end

ylim(yLimits);
set(gca, 'FontSize', 10);
box off;
grid off;

hold on;

pos = 0;
labelY = yLimits(2) * 1.03;

for i = 1:numel(categoryOrder)
    thisCat = categoryOrder(i);
    nRows = sum(string(categoriesForRows) == thisCat);

    if nRows == 0
        continue;
    end

    startX = pos + 1;
    endX   = pos + nRows;
    pos    = pos + nRows;

    % Category separator line
    line([pos + 0.5 pos + 0.5], yLimits, ...
        'LineStyle', '--', ...
        'Color', 'k', ...
        'LineWidth', 1);

    % Category label
    text((startX + endX) / 2, labelY, char(thisCat), ...
        'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', ...
        'FontSize', 12);

    % Category mean line
    catMean = mean(values(startX:endX), 'omitnan');

    line([startX - 0.4 endX + 0.4], [catMean catMean], ...
        'Color', meanLineColor, ...
        'LineWidth', 2);
end

hold off;

end
