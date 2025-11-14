%% RT Analysis: Category × ImageType (Original vs Rest)
% Author: Fatma Kilic
%
% Description:
%   - Loads combined behavioral data from the Go/No-Go experiment
%   - Selects valid Go trials (Category == Subfolder, RT >= 0.1 s)
%   - Computes mean RT per Participant × Category × ImageType
%   - Runs a repeated-measures ANOVA with factors:
%       Category (8 levels) × ImageType (Original vs Rest)
%   - Performs Bonferroni-corrected pairwise comparisons
%   - Computes Mean and SEM per Category × ImageType
%   - Produces a horizontal bar plot with error bars + significance stars
%
% Requirements:
%   - MATLAB (tested with R2017b+)
%   - Statistics and Machine Learning Toolbox
%
% Expected input:
%   - A .mat file containing a table `combinedTable` with at least:
%       ParticipantInfo  (string or char)
%       Category         (string/char)
%       Subfolder        (string/char)
%       ImageShown       (string/char)
%       ReactionTime     (double, seconds)
%
% Folder assumptions:
%   project_root/
%   ├─ experiment/
%   ├─ analysis/
%   │   └─ analyse_RT_RMANOVA_Category_ImageType.m
%   └─ data/
%       └─ combinedData_ExpV2.mat   (contains `combinedTable`)
%
% Output:
%   - anova_results (in workspace)
%   - posthoc_interaction (in workspace)
%   - group_stats, meanRT, semRT, catLabels (for plotting)
%   - Optional CSVs + figure saved under analysis/results/

%% ------------------------------------------------------------------------
%                            Configuration                                
% -------------------------------------------------------------------------

% Resolve project root as one directory above this script
thisFile   = mfilename('fullpath');
[thisDir, ~, ~] = fileparts(thisFile);
projectDir = fileparts(thisDir);

% Input data file (relative)
dataDir      = fullfile(projectDir, 'data');
inputMatFile = fullfile(dataDir, 'combinedData_ExpV2.mat');

% Output directory for stats & plots
resultsDir = fullfile(projectDir, 'analysis', 'results', 'RM_ANOVA');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

% Toggles for saving
SAVE_CSV   = true;
SAVE_FIG   = true;

%% ------------------------------------------------------------------------
%                               Load Data                                 
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
%                     Participant ID (from ParticipantInfo)               
% -------------------------------------------------------------------------

% Ensure ParticipantInfo is string
response_data.ParticipantInfo = string(response_data.ParticipantInfo);

n = height(response_data);
participantID = strings(n, 1);

for i = 1:n
    % Split by whitespace and take first token (e.g., "Sub-01")
    info = strsplit(response_data.ParticipantInfo(i));
    participantID(i) = info(1);
end

response_data.Participant = categorical(participantID);

%% ------------------------------------------------------------------------
%                Define valid GO + pressed trials                         
% -------------------------------------------------------------------------

% Go trials: Category == Subfolder
is_go_trial = strcmp(string(response_data.Category), string(response_data.Subfolder));

% Pressed condition: RT not NaN and >= 0.1 s
pressed_condition = ~isnan(response_data.ReactionTime) & response_data.ReactionTime >= 0.1;

valid_go_trials = is_go_trial & pressed_condition;

% Filter data
rt_data = response_data(valid_go_trials, :);

% ImageType: Original vs Rest (everything else)
rt_data.ImageType = repmat("Rest", height(rt_data), 1);
rt_data.ImageType(contains(string(rt_data.ImageShown), 'original', 'IgnoreCase', true)) = "Original";
rt_data.ImageType = categorical(rt_data.ImageType);

rt_data.Category = categorical(rt_data.Category);

%% ------------------------------------------------------------------------
%           Mean RT per Participant × Category × ImageType                
% -------------------------------------------------------------------------

grouped = groupsummary(rt_data, {'Participant', 'Category', 'ImageType'}, ...
                       'mean', 'ReactionTime');
grouped.Properties.VariableNames{'mean_ReactionTime'} = 'RT';

% Combined condition label, e.g. "Animal_Original"
grouped.Condition = strcat(string(grouped.Category), "_", string(grouped.ImageType));

participants = unique(grouped.Participant);
conditions   = unique(grouped.Condition);

% Preallocate wide table
pivoted = table();
pivoted.Participant = participants;

for c = 1:numel(conditions)
    cond      = conditions(c);
    rt_column = nan(numel(participants), 1);
    
    for p = 1:numel(participants)
        match = grouped.Participant == participants(p) & grouped.Condition == cond;
        rts   = grouped.RT(match);
        if ~isempty(rts)
            rt_column(p) = rts(1); % there should be a single value per Participant×Condition
        end
    end
    
    % Use condition label as column name (converts to valid MATLAB name automatically)
    pivoted.(cond) = rt_column;
end

wideTable   = pivoted;
responseCols = wideTable.Properties.VariableNames(2:end);  % skip Participant

%% ------------------------------------------------------------------------
%                    Within-subject design table                          
% -------------------------------------------------------------------------

category_part   = extractBefore(responseCols, "_");
image_type_part = extractAfter(responseCols, "_");

withinDesign = table( ...
    categorical(category_part(:)), ...
    categorical(image_type_part(:)), ...
    'VariableNames', {'Category', 'ImageType'});

%% Remove participants with any missing data across conditions
wideTable_clean = rmmissing(wideTable, 'DataVariables', responseCols);

%% ------------------------------------------------------------------------
%                    Repeated-measures ANOVA                              
% -------------------------------------------------------------------------

% Formula: Var1-VarN ~ 1  (all condition columns as repeated measures)
modelFormula = sprintf('%s-%s ~ 1', responseCols{1}, responseCols{end});
rm = fitrm(wideTable_clean, modelFormula, 'WithinDesign', withinDesign);

anova_results = ranova(rm, 'WithinModel', 'Category*ImageType');
disp('Repeated-measures ANOVA (Category × ImageType):');
disp(anova_results);

%% ------------------------------------------------------------------------
%                     Save ANOVA table as CSV                             
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
    outCSV = fullfile(resultsDir, 'RMANOVA_Results_for_RT_Category_ImageType.csv');
    writetable(anova_clean, outCSV);
    fprintf('Saved ANOVA results to: %s\n', outCSV);
end

%% ------------------------------------------------------------------------
%             Pairwise comparisons within Category × ImageType            
% -------------------------------------------------------------------------

posthoc_interaction = multcompare(rm, 'ImageType', 'By', 'Category', ...
    'ComparisonType', 'bonferroni');
disp('Post-hoc comparisons (ImageType within Category, Bonferroni-corrected):');
disp(posthoc_interaction);

% Significance coding
posthoc_interaction.Significant = posthoc_interaction.pValue < 0.05;
posthoc_interaction.SigStars    = strings(height(posthoc_interaction), 1);
posthoc_interaction.SigStars(posthoc_interaction.pValue < 0.001) = "***";
posthoc_interaction.SigStars(posthoc_interaction.pValue < 0.01  & posthoc_interaction.pValue >= 0.001) = "**";
posthoc_interaction.SigStars(posthoc_interaction.pValue < 0.05  & posthoc_interaction.pValue >= 0.01)  = "*";

if SAVE_CSV
    outCSV_posthoc = fullfile(resultsDir, 'RMANOVA_PostHoc_Interaction_for_RT_CategoryByImageType.csv');
    writetable(posthoc_interaction, outCSV_posthoc);
    fprintf('Saved post-hoc results to: %s\n', outCSV_posthoc);
end

%% ------------------------------------------------------------------------
%        Mean and SEM per Category × ImageType for plotting               
% -------------------------------------------------------------------------

[G, cats, imgTypes] = findgroups(rt_data.Category, rt_data.ImageType);
meanRT_vals = splitapply(@mean, rt_data.ReactionTime, G);
semRT_vals  = splitapply(@(x) std(x)/sqrt(numel(x)), rt_data.ReactionTime, G);

group_stats = table(cats, imgTypes, meanRT_vals, semRT_vals, ...
    'VariableNames', {'Category', 'ImageType', 'Mean_RT', 'SEM_RT'});

% Pivot to wide (Category × [Original, Rest])
uniqueCats = unique(group_stats.Category);
nCats      = numel(uniqueCats);

meanRT   = nan(nCats, 2);  % 1 = Original, 2 = Rest
semRT    = nan(nCats, 2);
catLabels = string(uniqueCats);

for i = 1:nCats
    thisCat = uniqueCats(i);

    idx_o = group_stats.Category == thisCat & group_stats.ImageType == "Original";
    if any(idx_o)
        meanRT(i, 1) = group_stats.Mean_RT(idx_o);
        semRT(i, 1)  = group_stats.SEM_RT(idx_o);
    end

    idx_r = group_stats.Category == thisCat & group_stats.ImageType == "Rest";
    if any(idx_r)
        meanRT(i, 2) = group_stats.Mean_RT(idx_r);
        semRT(i, 2)  = group_stats.SEM_RT(idx_r);
    end
end

% Sort categories by max RT (descending)
[~, sortIdx] = sort(max(meanRT, [], 2), 'descend');
meanRT    = meanRT(sortIdx, :);
semRT     = semRT(sortIdx, :);
catLabels = catLabels(sortIdx);
nCats     = numel(catLabels);

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

for i = 1:nCats
    for j = 1:2  % 1 = Original, 2 = Rest
        y = i + groupOffset(j);
        handles(j) = barh(y, meanRT(i,j), barWidth, ...
            'FaceColor', colors(j,:), 'EdgeColor', 'none');
        errorbar(meanRT(i,j), y, semRT(i,j), 'horizontal', ...
            'Color', 'k', 'LineStyle', 'none', ...
            'CapSize', lineWidth, 'LineWidth', lineWidth);
    end
end

% Use only Original vs Rest rows for SigStars, and only significant ones
it1 = string(posthoc_interaction.ImageType_1);
it2 = string(posthoc_interaction.ImageType_2);

sig_rows = posthoc_interaction( ...
    it1 == "Original" & it2 == "Rest" & posthoc_interaction.Significant, :);

sortedCategories = catLabels;

for s = 1:height(sig_rows)
    thisCat = sig_rows.Category(s);
    catIdx  = find(ismember(string(sortedCategories), string(thisCat)));

    if isempty(catIdx)
        continue;
    end

    % Center y between the two bars
    y = catIdx;

    % Offset x to the right of the larger bar
    rt_max = max(meanRT(catIdx, :));
    offset = 0.04 * range(meanRT(:));  % adaptive offset
    x = rt_max + offset;

    text(x, y, sig_rows.SigStars(s), ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', 30, ...
        'FontWeight', 'bold', ...
        'Color', 'k');
end

yticks(1:nCats);
yticklabels(catLabels);
xlabel('Reaction Time (s)');
xlim([0.3 - 0.01, max(meanRT(:)) + 0.03]);
legend(handles, {'Original', 'Rest'}, 'Location', 'southeast', 'Box', 'off');
set(gca, 'FontSize', 28, 'FontName', 'Arial', 'YDir', 'reverse');
box off;
grid off;

if SAVE_FIG
    outFig = fullfile(resultsDir, 'RT_CategoryByImageType_barplot.png');
    saveas(gcf, outFig);
    fprintf('Saved RT bar plot to: %s\n', outFig);
end
