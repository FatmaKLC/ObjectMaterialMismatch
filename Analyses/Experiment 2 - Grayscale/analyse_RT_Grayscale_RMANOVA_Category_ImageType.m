%% RT Analysis (Grayscale): Category × ImageType (Original vs Rest)
% Author: Fatma Kilic
%
% Description:
%   - Loads combined trial-level data from the grayscale Go/No-Go experiment
%   - Selects Go trials with valid responses (RT >= 0.1 s)
%   - Computes mean RT per Participant × Category × ImageType
%   - Runs a repeated-measures ANOVA with factors:
%         Category (8 levels) × ImageType (Original vs Rest)
%   - Performs Bonferroni-corrected pairwise comparisons within Category
%   - Creates a horizontal bar plot (RT) with error bars and significance stars
%
% Requirements:
%   - MATLAB (tested with R2017b+)
%   - Statistics and Machine Learning Toolbox
%
% Expected project structure:
%   project_root/
%   ├─ data/
%   │   └─ combinedData_grayscale.mat   (contains combinedTable)
%   └─ analysis/
%       └─ analyse_RT_Grayscale_RMANOVA_Category_ImageType.m
%
% NOTE: The .mat data file should remain private (or anonymised/demo version)
%       when sharing the repository publicly.

%% ------------------------------------------------------------------------
%                          Configuration                                  
% -------------------------------------------------------------------------

clearvars; close all; clc;

% Resolve project root as one directory above this script
thisFile   = mfilename('fullpath');
[thisDir, ~, ~] = fileparts(thisFile);
projectDir = fileparts(thisDir);

% Input data (grayscale)
dataDir      = fullfile(projectDir, 'data');
inputMatFile = fullfile(dataDir, 'combinedData_grayscale.mat');

% Output directory
resultsDir = fullfile(projectDir, 'analysis', 'results', 'RM_ANOVA_RT_Grayscale');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

% Toggles
SAVE_CSV = true;
SAVE_FIG = true;

%% ------------------------------------------------------------------------
%                               Load data                                 
% -------------------------------------------------------------------------

if ~exist(inputMatFile, 'file')
    error('Input data file not found: %s', inputMatFile);
end

S = load(inputMatFile);
if ~isfield(S, 'combinedTable')
    error('The file %s does not contain a variable named "combinedTable".', inputMatFile);
end

response_data = S.combinedTable;

%% ------------------------------------------------------------------------
%                  Participant column from ParticipantInfo                
% -------------------------------------------------------------------------

response_data.Participant = categorical(string(response_data.ParticipantInfo));

n = height(response_data);
participantID = strings(n, 1);

for i = 1:n
    info = strsplit(string(response_data.ParticipantInfo{i}));  % split by whitespace
    participantID(i) = info(1);                                % take the ID token
end

response_data.Participant = categorical(participantID);

%% ------------------------------------------------------------------------
%            Define GO + pressed trials (valid Go RT trials)              
% -------------------------------------------------------------------------

is_go_trial       = strcmp(response_data.Category, response_data.Subfolder);
pressed_condition = ~isnan(response_data.ReactionTime) & response_data.ReactionTime >= 0.1;

valid_go_trials = is_go_trial & pressed_condition;

% Filter data to valid Go trials
rt_data = response_data(valid_go_trials, :);

%% ------------------------------------------------------------------------
%                      ImageType and Category factors                     
% -------------------------------------------------------------------------

rt_data.ImageType = repmat("Rest", height(rt_data), 1);
rt_data.ImageType(contains(rt_data.ImageShown, 'original', 'IgnoreCase', true)) = "Original";

rt_data.ImageType = categorical(rt_data.ImageType);
rt_data.Category  = categorical(rt_data.Category);

%% ------------------------------------------------------------------------
%    Mean RT per Participant × Category × ImageType (long → group table)  
% -------------------------------------------------------------------------

grouped = groupsummary(rt_data, ...
    {'Participant', 'Category', 'ImageType'}, ...
    'mean', 'ReactionTime');

grouped.Properties.VariableNames{'mean_ReactionTime'} = 'RT';

% Combined condition label like 'Animal_Original'
grouped.Condition = strcat(string(grouped.Category), "_", string(grouped.ImageType));
participants = unique(grouped.Participant);
conditions   = unique(grouped.Condition);

%% ------------------------------------------------------------------------
%                       Pivot to wide table                               
% -------------------------------------------------------------------------

pivoted = table();
pivoted.Participant = participants;

for c = 1:numel(conditions)
    cond      = conditions(c);
    rt_column = nan(numel(participants), 1);

    for p = 1:numel(participants)
        match = grouped.Participant == participants(p) & grouped.Condition == cond;
        rts   = grouped.RT(match);

        if ~isempty(rts)
            rt_column(p) = rts(1);  % one value per Participant × Condition
        end
    end

    pivoted.(cond) = rt_column;
end

wideTable    = pivoted;
responseCols = wideTable.Properties.VariableNames(2:end);  % skip Participant

%% ------------------------------------------------------------------------
%                     Within-subject design table                         
% -------------------------------------------------------------------------

category_part   = extractBefore(responseCols, "_");
image_type_part = extractAfter(responseCols, "_");

withinDesign = table( ...
    categorical(category_part(:)), ...
    categorical(image_type_part(:)), ...
    'VariableNames', {'Category', 'ImageType'});

% Remove participants with any missing cells
wideTable_clean = rmmissing(wideTable, 'DataVariables', responseCols);

%% ------------------------------------------------------------------------
%                     Repeated-measures ANOVA                             
% -------------------------------------------------------------------------

modelFormula = sprintf('%s-%s ~ 1', responseCols{1}, responseCols{end});
rm = fitrm(wideTable_clean, modelFormula, 'WithinDesign', withinDesign);

anova_results = ranova(rm, 'WithinModel', 'Category*ImageType');
disp('Repeated-measures ANOVA on RT (Grayscale; Category × ImageType):');
disp(anova_results);

%% ------------------------------------------------------------------------
%                       Save ANOVA results (CSV)                          
% -------------------------------------------------------------------------

anova_clean = table();
anova_clean.SumSq    = anova_results.SumSq;
anova_clean.DF       = anova_results.DF;
anova_clean.MeanSq   = anova_results.MeanSq;
anova_clean.F        = double(anova_results.F);
anova_clean.pValue   = double(anova_results.pValue);
anova_clean.pValueGG = double(anova_results.pValueGG);
anova_clean.pValueHF = double(anova_results.pValueHF);
anova_clean.pValueLB = double(anova_results.pValueLB);

anova_clean.Source = anova_results.Properties.RowNames;
anova_clean = movevars(anova_clean, 'Source', 'Before', 1);

if SAVE_CSV
    outCSV = fullfile(resultsDir, 'RMANOVA_Grayscale_RT_Category_ImageType.csv');
    writetable(anova_clean, outCSV);
    fprintf('Saved ANOVA table to: %s\n', outCSV);
end

%% ------------------------------------------------------------------------
%              Pairwise within the interaction (ImageType × Category)     
% -------------------------------------------------------------------------

posthoc_interaction = multcompare(rm, 'ImageType', 'By', 'Category', ...
    'ComparisonType', 'bonferroni');
disp('Post-hoc (ImageType within Category; Bonferroni, Grayscale):');
disp(posthoc_interaction);

% Add significance flags + stars
sig_rows = posthoc_interaction;
sig_rows.Significant = sig_rows.pValue < 0.05;
sig_rows.SigStars    = strings(height(sig_rows), 1);
sig_rows.SigStars(sig_rows.pValue < 0.001) = "***";
sig_rows.SigStars(sig_rows.pValue < 0.01  & sig_rows.pValue >= 0.001) = "**";
sig_rows.SigStars(sig_rows.pValue < 0.05  & sig_rows.pValue >= 0.01)  = "*";

if SAVE_CSV
    outCSVpost = fullfile(resultsDir, 'RMANOVA_Grayscale_RT_PostHoc_Interaction_CategoryByImageType.csv');
    writetable(sig_rows, outCSVpost);
    fprintf('Saved post-hoc interaction table (with SigStars) to: %s\n', outCSVpost);
end

%% ------------------------------------------------------------------------
%       Mean & SEM per Category × ImageType for plotting                  
% -------------------------------------------------------------------------

[G, cats, imgTypes] = findgroups(rt_data.Category, rt_data.ImageType);
meanRT_vals = splitapply(@mean, rt_data.ReactionTime, G);
semRT_vals  = splitapply(@(x) std(x)/sqrt(numel(x)), rt_data.ReactionTime, G);

group_stats = table(cats, imgTypes, meanRT_vals, semRT_vals, ...
    'VariableNames', {'Category', 'ImageType', 'Mean_RT', 'SEM_RT'});

% Pivot to wide (Original vs Rest)
uniqueCats = unique(group_stats.Category);
n          = numel(uniqueCats);

meanRT   = nan(n, 2);  % 1 = Original, 2 = Rest
semRT    = nan(n, 2);
catLabels = string(uniqueCats);

for i = 1:n
    thisCat = uniqueCats(i);

    % Original
    idx_o = group_stats.Category == thisCat & group_stats.ImageType == "Original";
    if any(idx_o)
        meanRT(i, 1) = group_stats.Mean_RT(idx_o);
        semRT(i, 1)  = group_stats.SEM_RT(idx_o);
    end

    % Rest
    idx_r = group_stats.Category == thisCat & group_stats.ImageType == "Rest";
    if any(idx_r)
        meanRT(i, 2) = group_stats.Mean_RT(idx_r);
        semRT(i, 2)  = group_stats.SEM_RT(idx_r);
    end
end

% Sort categories by max RT
[~, sortIdx] = sort(max(meanRT, [], 2), 'descend');
meanRT   = meanRT(sortIdx, :);
semRT    = semRT(sortIdx, :);
catLabels = catLabels(sortIdx);
n        = numel(catLabels);

%% ------------------------------------------------------------------------
%                         Plot with SigStars                              
% -------------------------------------------------------------------------

figure('Position', [100, 100, 1000, 600]); 
hold on;

barWidth    = 0.4;
groupOffset = [-barWidth/2, barWidth/2];
colors      = [0 0.4470 0.7410; 0.8500 0.3250 0.0980];  % Original / Rest
handles     = gobjects(2,1);
lineWidth   = 2;

% Draw bars + error bars
for i = 1:n
    for j = 1:2  % 1 = Original, 2 = Rest
        y = i + groupOffset(j);
        handles(j) = barh(y, meanRT(i,j), barWidth, ...
            'FaceColor', colors(j,:), 'EdgeColor', 'none');
        errorbar(meanRT(i,j), y, semRT(i,j), 'horizontal', ...
            'Color', 'k', 'LineStyle', 'none', ...
            'CapSize', lineWidth, 'LineWidth', lineWidth);
    end
end

% Filter sig_rows to only Original vs Rest comparisons
sig_rows = sig_rows( ...
    sig_rows.ImageType_1 == "Original" & ...
    sig_rows.ImageType_2 == "Rest", :);

sortedCategories = catLabels;

for s = 1:height(sig_rows)
    thisCat = sig_rows.Category(s);
    catIdx  = find(ismember(string(sortedCategories), string(thisCat)));

    if isempty(catIdx)
        continue;
    end

    % Center y between Original and Rest bars (their midpoint)
    y = catIdx;

    % x position: right of the longer bar
    rt_max = max(meanRT(catIdx, :));
    offset = 0.04 * range(meanRT(:));  % adaptive offset
    x      = rt_max + offset;

    text(x, y, sig_rows.SigStars(s), ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', 30, ...
        'FontWeight', 'bold', ...
        'Color', 'k');
end

% Labels & aesthetics
yticks(1:n);
yticklabels(catLabels);
xlabel('Reaction Time (s)');
xlim([max(0.0, min(meanRT(:)) - 0.02), max(meanRT(:)) + 0.05]);
legend(handles, {'Original', 'Rest'}, 'Location', 'southeast', 'Box', 'off');
set(gca, 'FontSize', 28, 'FontName', 'Arial', 'YDir', 'reverse');
box off;
grid off;

if SAVE_FIG
    outFig = fullfile(resultsDir, 'RT_Grayscale_CategoryByImageType_barplot.png');
    saveas(gcf, outFig);
    fprintf('Saved RT grayscale bar plot to: %s\n', outFig);
end
