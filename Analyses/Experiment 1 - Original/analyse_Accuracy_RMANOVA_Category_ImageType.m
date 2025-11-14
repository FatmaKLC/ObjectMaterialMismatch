%% Accuracy Analysis: Category × ImageType (Original vs Rest)
% Author: Fatma Kilic
%
% Description:
%   - Loads combined behavioral data from the Go/No-Go experiment
%   - Recomputes trial-level accuracy from RT + Go/No-Go logic
%   - Computes mean accuracy per Participant × Category × ImageType
%   - Runs a repeated-measures ANOVA with factors:
%       Category (8 levels) × ImageType (Original vs Rest)
%   - Performs Bonferroni-corrected pairwise comparisons
%   - Produces a horizontal bar plot (accuracy %) with significance stars
%
% Requirements:
%   - MATLAB (tested with R2017b+)
%   - Statistics and Machine Learning Toolbox
%
% Expected input:
%   - A .mat file containing a table `combinedTable` with at least:
%       ParticipantInfo
%       Category
%       Subfolder
%       ImageShown
%       ReactionTime
%
% Folder assumptions:
%   project_root/
%   ├─ experiment/
%   ├─ analysis/
%   │   └─ analyse_Accuracy_RMANOVA_Category_ImageType.m
%   └─ data/
%       └─ combinedData_ExpV2.mat   (contains `combinedTable`)
%
% Output:
%   - anova_results (workspace)
%   - posthoc_imageType, posthoc_category, posthoc_interaction (workspace)
%   - acc_stats, meanAcc, semAcc, catLabels (workspace)
%   - Optional CSVs + figure under analysis/results/RM_ANOVA_Accuracy/

%% ------------------------------------------------------------------------
%                            Configuration                                
% -------------------------------------------------------------------------

clearvars;

% Resolve project root as one directory above this script
thisFile   = mfilename('fullpath');
[thisDir, ~, ~] = fileparts(thisFile);
projectDir = fileparts(thisDir);

% Input data file (relative)
dataDir      = fullfile(projectDir, 'data');
inputMatFile = fullfile(dataDir, 'combinedData_ExpV2.mat');

% Output directory for stats & plots
resultsDir = fullfile(projectDir, 'analysis', 'results', 'RM_ANOVA_Accuracy');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

% Toggles for saving
SAVE_CSV = true;
SAVE_FIG = true;

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
%                      Recalculate trial-level accuracy                   
% -------------------------------------------------------------------------

% Ensure string type
response_data.Category     = string(response_data.Category);
response_data.Subfolder    = string(response_data.Subfolder);
response_data.ImageShown   = string(response_data.ImageShown);
response_data.ParticipantInfo = string(response_data.ParticipantInfo);

% Go trial if Category == Subfolder
is_go_trial = response_data.Category == response_data.Subfolder;

% Consider a response only if RT is not NaN and >= 0.1 s
did_respond = ~isnan(response_data.ReactionTime) & response_data.ReactionTime >= 0.1;

% Accuracy logic:
%   - Go trial: correct if responded
%   - No-Go trial: correct if did NOT respond
response_data.RecalculatedCorrect = (is_go_trial & did_respond) | ...
                                    (~is_go_trial & ~did_respond);

%% ------------------------------------------------------------------------
%                           Define ImageType                              
% -------------------------------------------------------------------------

is_original = contains(response_data.ImageShown, 'original', 'IgnoreCase', true);
ImageType   = repmat("Rest", height(response_data), 1);
ImageType(is_original) = "Original";
response_data.ImageType = categorical(ImageType);

%% ------------------------------------------------------------------------
%                     Participant ID from ParticipantInfo                 
% -------------------------------------------------------------------------

n = height(response_data);
participantID = strings(n, 1);

for i = 1:n
    info = strsplit(response_data.ParticipantInfo(i));  % split by whitespace
    participantID(i) = info(1);                        % take first token (e.g., "Sub-01")
end

response_data.Participant = categorical(participantID);
response_data.Category    = categorical(response_data.Category);
response_data.ImageType   = categorical(response_data.ImageType);

%% ------------------------------------------------------------------------
%         Mean accuracy per Participant × Category × ImageType            
% -------------------------------------------------------------------------

grouped = groupsummary(response_data, ...
    {'Participant', 'Category', 'ImageType'}, ...
    'mean', 'RecalculatedCorrect');

grouped.Properties.VariableNames{'mean_RecalculatedCorrect'} = 'Accuracy';

% Combined condition label like 'Animal_Original'
grouped.Condition = strcat(string(grouped.Category), "_", string(grouped.ImageType));
participants = unique(grouped.Participant);
conditions   = unique(grouped.Condition);

% Pivot to wide format
pivoted = table();
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

% Remove participants with missing cells
wideTable_clean = rmmissing(wideTable, 'DataVariables', responseCols);

%% ------------------------------------------------------------------------
%                      Repeated-measures ANOVA                            
% -------------------------------------------------------------------------

modelFormula = sprintf('%s-%s ~ 1', responseCols{1}, responseCols{end});
rm = fitrm(wideTable_clean, modelFormula, 'WithinDesign', withinDesign);

anova_results = ranova(rm, 'WithinModel', 'Category*ImageType');
disp('Repeated-measures ANOVA on Accuracy (Category × ImageType):');
disp(anova_results);

%% ------------------------------------------------------------------------
%                        Save ANOVA results as CSV                        
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
    outCSV = fullfile(resultsDir, 'RMANOVA_Accuracy_Results_Category_ImageType.csv');
    writetable(anova_clean, outCSV);
    fprintf('Saved ANOVA results to: %s\n', outCSV);
end

%% ------------------------------------------------------------------------
%                Pairwise comparisons for ImageType & Category            
% -------------------------------------------------------------------------

% Main effect of ImageType
posthoc_imageType = multcompare(rm, 'ImageType');
disp('Post-hoc (ImageType main effect):');
disp(posthoc_imageType);

% Main effect of Category
posthoc_category = multcompare(rm, 'Category');
disp('Post-hoc (Category main effect):');
disp(posthoc_category);

if SAVE_CSV
    outCSV_imgT = fullfile(resultsDir, 'RMANOVA_Accuracy_PostHoc_ImageType.csv');
    writetable(posthoc_imageType, outCSV_imgT);
    
    outCSV_cat = fullfile(resultsDir, 'RMANOVA_Accuracy_PostHoc_Category.csv');
    writetable(posthoc_category, outCSV_cat);
    
    fprintf('Saved post-hoc ImageType and Category results.\n');
end

%% ------------------------------------------------------------------------
%       Pairwise within the interaction: ImageType by Category            
% -------------------------------------------------------------------------

posthoc_interaction = multcompare(rm, 'ImageType', 'By', 'Category', ...
    'ComparisonType', 'bonferroni');
disp('Post-hoc (ImageType within Category, Bonferroni):');
disp(posthoc_interaction);

posthoc_interaction.Significant = posthoc_interaction.pValue < 0.05;
posthoc_interaction.SigStars    = strings(height(posthoc_interaction), 1);
posthoc_interaction.SigStars(posthoc_interaction.pValue < 0.001) = "***";
posthoc_interaction.SigStars(posthoc_interaction.pValue < 0.01  & posthoc_interaction.pValue >= 0.001) = "**";
posthoc_interaction.SigStars(posthoc_interaction.pValue < 0.05  & posthoc_interaction.pValue >= 0.01)  = "*";

if SAVE_CSV
    outCSV_int = fullfile(resultsDir, 'RMANOVA_Accuracy_PostHoc_Interaction_CategoryByImageType.csv');
    writetable(posthoc_interaction, outCSV_int);
    fprintf('Saved interaction post-hoc results to: %s\n', outCSV_int);
end

%% ------------------------------------------------------------------------
%     Accuracy Bar Plot: Original vs Rest, sorted by max accuracy         
% -------------------------------------------------------------------------

% Group-level stats from participant-level accuracies
[G, cats, types] = findgroups(grouped.Category, grouped.ImageType);
meanAcc_vals = splitapply(@mean, grouped.Accuracy, G);
semAcc_vals  = splitapply(@(x) std(x)/sqrt(numel(x)), grouped.Accuracy, G);

acc_stats = table(cats, types, meanAcc_vals, semAcc_vals, ...
    'VariableNames', {'Category', 'ImageType', 'MeanAcc', 'SEMAcc'});

allCats   = categories(acc_stats.Category);
nCats     = numel(allCats);

meanAcc   = nan(nCats, 2);  % 1 = Original, 2 = Rest
semAcc    = nan(nCats, 2);
catLabels = strings(nCats, 1);

for i = 1:nCats
    cat = allCats{i};
    catLabels(i) = cat;

    idx_o = acc_stats.Category == cat & acc_stats.ImageType == "Original";
    idx_r = acc_stats.Category == cat & acc_stats.ImageType == "Rest";

    if any(idx_o)
        meanAcc(i,1) = acc_stats.MeanAcc(idx_o);
        semAcc(i,1)  = acc_stats.SEMAcc(idx_o);
    end
    if any(idx_r)
        meanAcc(i,2) = acc_stats.MeanAcc(idx_r);
        semAcc(i,2)  = acc_stats.SEMAcc(idx_r);
    end
end

% Sort by max accuracy (descending)
[~, sortIdx] = sort(max(meanAcc, [], 2), 'descend');
meanAcc   = meanAcc(sortIdx, :);
semAcc    = semAcc(sortIdx, :);
catLabels = catLabels(sortIdx);
nCats     = numel(catLabels);

% Filter sig rows: only Original vs Rest and significant
posthoc_interaction.Category = string(posthoc_interaction.Category);
sig_rows = posthoc_interaction( ...
    string(posthoc_interaction.ImageType_1) == "Original" & ...
    string(posthoc_interaction.ImageType_2) == "Rest" & ...
    posthoc_interaction.Significant, :);

%% Plot

figure('Position', [100, 100, 1000, 600]); 
hold on;

barWidth    = 0.4;
groupOffset = [-barWidth/2, barWidth/2];
colors      = [0 0.4470 0.7410; 0.8500 0.3250 0.0980];  % Original / Rest
handles     = gobjects(2,1);

for i = 1:nCats
    for j = 1:2  % 1 = Original, 2 = Rest
        y = i + groupOffset(j);
        handles(j) = barh(y, meanAcc(i,j) * 100, barWidth, ...
            'FaceColor', colors(j,:), 'EdgeColor', 'none');
        errorbar(meanAcc(i,j) * 100, y, semAcc(i,j) * 100, 'horizontal', ...
            'Color', 'k', 'LineStyle', 'none', ...
            'CapSize', 2, 'LineWidth', 2);
    end
    
    % Add SigStars (Original vs Rest only, if significant)
    thisCat = catLabels(i);
    rowIdx  = sig_rows.Category == thisCat;
    if any(rowIdx)
        stars = sig_rows.SigStars(rowIdx);
        if stars ~= ""
            maxX  = max(meanAcc(i,:) * 100) + max(semAcc(i,:) * 100) + 1; % a bit to the right
            y_pos = i + mean(groupOffset);
            text(maxX, y_pos, stars, ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'middle', ...
                'FontSize', 26, 'FontWeight', 'bold');
        end
    end
end

yticks(1:nCats);
yticklabels(catLabels);
xlabel('Accuracy (%)');
xlim([50, 100]);  % adjust if needed
legend(handles, {'Original', 'Rest'}, 'Location', 'southeast', 'Box', 'off');
set(gca, 'FontSize', 28, 'FontName', 'Arial', 'YDir', 'reverse');
box off;
grid off;

if SAVE_FIG
    outFig = fullfile(resultsDir, 'Accuracy_CategoryByImageType_barplot.png');
    saveas(gcf, outFig);
    fprintf('Saved Accuracy bar plot to: %s\n', outFig);
end
