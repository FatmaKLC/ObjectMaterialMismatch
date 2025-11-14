%% Accuracy Analysis (Grayscale): Category × ImageType (Original vs Rest)
% Author: Fatma Kilic
%
% Description:
%   - Loads combined trial-level data from the grayscale Go/No-Go experiment
%   - Recomputes trial-level accuracy:
%         Go  trial  = Category == Subfolder
%         Correct Go = responded (RT >= 0.1 s)
%         Correct NoGo = withheld response
%   - Computes mean accuracy per Participant × Category × ImageType
%   - Runs a repeated-measures ANOVA with factors:
%         Category (8 levels) × ImageType (Original vs Rest)
%   - Performs pairwise comparisons and extracts Bonferroni-corrected
%     post-hoc tests for ImageType within Category
%   - Creates a horizontal bar plot of accuracy with error bars and
%     significance stars.
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
%       └─ analyse_Accuracy_Grayscale_RMANOVA_Category_ImageType.m
%
% NOTE: The .mat data file should remain private (or anonymised/demo version)
%       when sharing the repository publicly.

%% ------------------------------------------------------------------------
%                           Configuration                                 
% -------------------------------------------------------------------------

clearvars; close all; clc;

% Resolve project root as one directory above this script
thisFile            = mfilename('fullpath');
[thisDir, ~, ~]     = fileparts(thisFile);
projectDir          = fileparts(thisDir);

% Input data file (grayscale accuracy analysis)
dataDir             = fullfile(projectDir, 'data');
inputMatFile        = fullfile(dataDir, 'combinedData_grayscale.mat');

% Output directory
resultsDir = fullfile(projectDir, 'analysis', 'results', 'RM_ANOVA_Accuracy_Grayscale');
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
%                     Recalculate trial-level accuracy                    
% -------------------------------------------------------------------------

is_go_trial   = strcmp(response_data.Category, response_data.Subfolder);

did_respond   = ~isnan(response_data.ReactionTime) & ...
                response_data.ReactionTime >= 0.1;

response_data.RecalculatedCorrect = (is_go_trial & did_respond) | ...
                                    (~is_go_trial & ~did_respond);

%% ------------------------------------------------------------------------
%                              ImageType                                  
% -------------------------------------------------------------------------

is_original = contains(response_data.ImageShown, 'original', 'IgnoreCase', true);
ImageType   = repmat("Rest", height(response_data), 1);
ImageType(is_original) = "Original";

response_data.ImageType = categorical(ImageType);

%% ------------------------------------------------------------------------
%                Participant column from ParticipantInfo                  
% -------------------------------------------------------------------------

response_data.Participant = categorical(string(response_data.ParticipantInfo));

n = height(response_data);
participantID = strings(n, 1);

for i = 1:n
    info = strsplit(string(response_data.ParticipantInfo{i}));  % split by whitespace
    participantID(i) = info(1);                                % take ID token
end

response_data.Participant = categorical(participantID);

%% ------------------------------------------------------------------------
%       Mean accuracy per Participant × Category × ImageType              
% -------------------------------------------------------------------------

response_data.Participant = categorical(response_data.Participant(:));
response_data.Category    = categorical(response_data.Category(:));
response_data.ImageType   = categorical(response_data.ImageType(:));

grouped = groupsummary(response_data, ...
    {'Participant', 'Category', 'ImageType'}, ...
    'mean', 'RecalculatedCorrect');

grouped.Properties.VariableNames{'mean_RecalculatedCorrect'} = 'Accuracy';

% Quick preview in the command window
head_rows = grouped(1:min(10, height(grouped)), :);
disp('Preview of grouped accuracy:');
disp(head_rows);

%% ------------------------------------------------------------------------
%                     Pivot to wide: Participant × Condition              
% -------------------------------------------------------------------------

pivoted = table();

% Combined condition label, e.g. 'Animal_Original'
grouped.Condition = strcat(string(grouped.Category), "_", string(grouped.ImageType));
participants = unique(grouped.Participant);
conditions   = unique(grouped.Condition);

pivoted.Participant = participants;

for c = 1:numel(conditions)
    cond       = conditions(c);
    acc_column = nan(numel(participants), 1);

    for p = 1:numel(participants)
        match = grouped.Participant == participants(p) & grouped.Condition == cond;
        accs  = grouped.Accuracy(match);

        if ~isempty(accs)
            acc_column(p) = accs(1);  % one value per Participant × Condition
        end
    end

    pivoted.(cond) = acc_column;
end

wideTable    = pivoted;
responseCols = wideTable.Properties.VariableNames(2:end);

%% ------------------------------------------------------------------------
%                     Within-subject factor table                         
% -------------------------------------------------------------------------

category_part   = extractBefore(responseCols, "_");
image_type_part = extractAfter(responseCols, "_");

withinDesign = table( ...
    categorical(category_part(:)), ...
    categorical(image_type_part(:)), ...
    'VariableNames', {'Category', 'ImageType'});

% Remove participants with incomplete cells
wideTable_clean = rmmissing(wideTable, 'DataVariables', responseCols);

%% ------------------------------------------------------------------------
%                       Repeated-measures ANOVA                           
% -------------------------------------------------------------------------

modelFormula = sprintf('%s-%s ~ 1', responseCols{1}, responseCols{end});
rm = fitrm(wideTable_clean, modelFormula, 'WithinDesign', withinDesign);

anova_results = ranova(rm, 'WithinModel', 'Category*ImageType');
disp('Repeated-measures ANOVA on Accuracy (Grayscale; Category × ImageType):');
disp(anova_results);

%% ------------------------------------------------------------------------
%                     Save ANOVA results (optional)                       
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
anova_clean        = movevars(anova_clean, 'Source', 'Before', 1);

if SAVE_CSV
    outCSV = fullfile(resultsDir, 'RMANOVA_Grayscale_Accuracy_Category_ImageType.csv');
    writetable(anova_clean, outCSV);
    fprintf('Saved ANOVA table to: %s\n', outCSV);
end

%% ------------------------------------------------------------------------
%                    Pairwise comparisons (optional)                      
% -------------------------------------------------------------------------

% ImageType main effect
posthoc_imageType = multcompare(rm, 'ImageType');
disp('Post-hoc (ImageType main effect):');
disp(posthoc_imageType);

% Category main effect
posthoc_category = multcompare(rm, 'Category');
disp('Post-hoc (Category main effect):');
disp(posthoc_category);

%% ------------------------------------------------------------------------
%      Pairwise within interaction: ImageType within Category             
% -------------------------------------------------------------------------

posthoc_interaction = multcompare(rm, 'ImageType', 'By', 'Category', ...
    'ComparisonType', 'bonferroni');
disp('Post-hoc (ImageType within Category, Bonferroni):');
disp(posthoc_interaction);

% Add significance flags and stars
posthoc_interaction.Significant = posthoc_interaction.pValue < 0.05;
posthoc_interaction.SigStars    = strings(height(posthoc_interaction), 1);
posthoc_interaction.SigStars(posthoc_interaction.pValue < 0.001) = "***";
posthoc_interaction.SigStars(posthoc_interaction.pValue < 0.01  & posthoc_interaction.pValue >= 0.001) = "**";
posthoc_interaction.SigStars(posthoc_interaction.pValue < 0.05  & posthoc_interaction.pValue >= 0.01)  = "*";

if SAVE_CSV
    outCSVpost = fullfile(resultsDir, 'RMANOVA_Grayscale_Accuracy_PostHoc_Interaction_CategoryByImageType.csv');
    writetable(posthoc_interaction, outCSVpost);
    fprintf('Saved interaction post-hoc table (with SigStars) to: %s\n', outCSVpost);
end

%% ------------------------------------------------------------------------
%     Accuracy Bar Plot: Original vs Rest, sorted by max accuracy         
% -------------------------------------------------------------------------

% Get unique categories as strings
allCats   = unique(cellstr(grouped.Category));
n         = numel(allCats);

meanAcc   = nan(n, 2);   % 1 = Original, 2 = Rest
semAcc    = nan(n, 2);
catLabels = strings(n,1);

% Group-level stats
[G, cats, types] = findgroups(grouped.Category, grouped.ImageType);
meanAcc_vals     = splitapply(@mean, grouped.Accuracy, G);
semAcc_vals      = splitapply(@(x) std(x)/sqrt(numel(x)), grouped.Accuracy, G);

acc_stats = table(cats, types, meanAcc_vals, semAcc_vals, ...
    'VariableNames', {'Category', 'ImageType', 'MeanAcc', 'SEMAcc'});

% Fill matrices for Original / Rest
for i = 1:n
    cat = allCats{i};
    catLabels(i) = cat;

    idx_o = strcmp(cellstr(acc_stats.Category), cat) & strcmp(cellstr(acc_stats.ImageType), 'Original');
    idx_r = strcmp(cellstr(acc_stats.Category), cat) & strcmp(cellstr(acc_stats.ImageType), 'Rest');

    if any(idx_o)
        meanAcc(i,1) = acc_stats.MeanAcc(idx_o);
        semAcc(i,1)  = acc_stats.SEMAcc(idx_o);
    end
    if any(idx_r)
        meanAcc(i,2) = acc_stats.MeanAcc(idx_r);
        semAcc(i,2)  = acc_stats.SEMAcc(idx_r);
    end
end

% Sort by maximum accuracy across ImageType
[~, sortIdx] = sort(max(meanAcc, [], 2), 'descend');
meanAcc   = meanAcc(sortIdx, :);
semAcc    = semAcc(sortIdx, :);
catLabels = catLabels(sortIdx);

% Ensure strings for lookup
posthoc_interaction.Category = string(posthoc_interaction.Category);
posthoc_interaction.SigStars = string(posthoc_interaction.SigStars);

%% ------------------------------------------------------------------------
%              Horizontal bar plot with significance stars                
% -------------------------------------------------------------------------

figure('Position', [100, 100, 1000, 600]); 
hold on;

barWidth    = 0.4;
groupOffset = [-barWidth/2, barWidth/2];
colors      = [0 0.4470 0.7410; 0.8500 0.3250 0.0980];  % Original / Rest
handles     = gobjects(2,1);

for i = 1:n
    for j = 1:2  % 1 = Original, 2 = Rest
        y = i + groupOffset(j);
        handles(j) = barh(y, meanAcc(i,j) * 100, barWidth, ...
            'FaceColor', colors(j,:), 'EdgeColor', 'none');
        errorbar(meanAcc(i,j) * 100, y, semAcc(i,j) * 100, 'horizontal', ...
            'Color', 'k', 'LineStyle', 'none', ...
            'CapSize', 2, 'LineWidth', 2);
    end

    % Add SigStars (Original vs Rest only)
    thisCat = catLabels(i);
    starRow = posthoc_interaction.Category == thisCat & ...
              posthoc_interaction.ImageType_1 == "Original" & ...
              posthoc_interaction.ImageType_2 == "Rest";

    if any(starRow)
        stars = posthoc_interaction.SigStars(starRow);
        if stars ~= ""
            % Horizontal position: max of two bars + offset
            maxX = max(meanAcc(i,:) * 100) + max(semAcc(i,:) * 100) + 0.5;

            % Vertical position: midpoint between the two bars
            y_pos = i + mean(groupOffset);

            text(maxX, y_pos, stars, ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'middle', ...
                'FontSize', 26, 'FontWeight', 'bold');
        end
    end
end

% Aesthetics
yticks(1:n);
yticklabels(catLabels);
xlabel('Accuracy (%)');
xlim([50, 100]);  % leave some space for stars
legend(handles, {'Original', 'Rest'}, 'Location', 'southeast', 'Box', 'off');
set(gca, 'FontSize', 28, 'FontName', 'Arial', 'YDir', 'reverse');
box off;

if SAVE_FIG
    outFig = fullfile(resultsDir, 'Accuracy_Grayscale_CategoryByImageType_barplot.png');
    saveas(gcf, outFig);
    fprintf('Saved accuracy grayscale bar plot to: %s\n', outFig);
end
