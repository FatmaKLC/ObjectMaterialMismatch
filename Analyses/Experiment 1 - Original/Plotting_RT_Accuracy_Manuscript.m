%% =========================================================
% DESCRIPTIVE FIGURE: MEAN RT + ACCURACY
% Original vs Rest/Incongruent per category
% Error bars = SEM across participants
%
% RT:
%   only valid Go + pressed trials
%
% Accuracy:
%   all trials using recalculated correctness
%% =========================================================

clear; clc;

%% -------------------------------------------------
% LOAD DATA
%% -------------------------------------------------
load('data_with_mask_and_luminance_grayscale.mat');   % to plot coloured data replace this part with "data_with_mask_and_luminance_coloured.mat"
response_data = T;

%% -------------------------------------------------
% CREATE CLEAN PARTICIPANT COLUMN
%% -------------------------------------------------
n = height(response_data);
participantID = strings(n, 1);

for i = 1:n
    info = strsplit(response_data.ParticipantInfo{i});
    participantID(i) = string(info{1});
end

response_data.Participant = categorical(participantID);

%% -------------------------------------------------
% CLEAN CATEGORY NAMES
%% -------------------------------------------------
response_data.Category = string(response_data.Category);
response_data.Subfolder = string(response_data.Subfolder);

response_data.Category = strrep(response_data.Category, ...
    'Musical Instruments', 'Instrument');
response_data.Category = strrep(response_data.Category, ...
    'Musical Instrument', 'Instrument');

response_data.Subfolder = strrep(response_data.Subfolder, ...
    'Musical Instruments', 'Instrument');
response_data.Subfolder = strrep(response_data.Subfolder, ...
    'Musical Instrument', 'Instrument');

%% -------------------------------------------------
% DEFINE ImageType
%% -------------------------------------------------
response_data.ImageType = repmat("Rest", height(response_data), 1);
response_data.ImageType(contains(lower(string(response_data.ImageShown)), 'original')) = "Original";
response_data.ImageType = categorical(response_data.ImageType);

response_data.ImageType = reordercats(response_data.ImageType, {'Original','Rest'});

%% =========================================================
% PART 1: RT DATA
% Use only Go trials with valid button press
%% =========================================================

is_go_trial = response_data.Category == response_data.Subfolder;
pressed_condition = ~isnan(response_data.ReactionTime) & response_data.ReactionTime >= 0.1;
valid_go_trials = is_go_trial & pressed_condition;

rt_data = response_data(valid_go_trials, :);

fprintf('RT trials included: %d\n', height(rt_data));

%% participant-level RT means
G_rt = groupsummary(rt_data, ...
    {'Participant','Category','ImageType'}, ...
    'mean', 'ReactionTime');

G_rt.Properties.VariableNames{'mean_ReactionTime'} = 'MeanRT';

%% category-level RT mean and SEM
S_rt = groupsummary(G_rt, ...
    {'Category','ImageType'}, ...
    {'mean','std'}, 'MeanRT');

S_rt.Properties.VariableNames{'mean_MeanRT'} = 'MeanRT';
S_rt.Properties.VariableNames{'std_MeanRT'}  = 'StdRT';

S_rt.N = S_rt.GroupCount;
S_rt.SEM = S_rt.StdRT ./ sqrt(S_rt.N);

%% =========================================================
% PART 2: ACCURACY DATA
% Use all trials using recalculated correctness
%% =========================================================

acc_data = response_data;

is_go_trial_all = acc_data.Category == acc_data.Subfolder;
did_respond = ~isnan(acc_data.ReactionTime) & acc_data.ReactionTime >= 0.1;

acc_data.RecalculatedCorrect = ...
    (is_go_trial_all & did_respond) | (~is_go_trial_all & ~did_respond);

fprintf('Accuracy trials included: %d\n', height(acc_data));

%% participant-level accuracy
G_acc = groupsummary(acc_data, ...
    {'Participant','Category','ImageType'}, ...
    'mean', 'RecalculatedCorrect');

G_acc.Properties.VariableNames{'mean_RecalculatedCorrect'} = 'Accuracy';

%% category-level accuracy mean and SEM
S_acc = groupsummary(G_acc, ...
    {'Category','ImageType'}, ...
    {'mean','std'}, 'Accuracy');

S_acc.Properties.VariableNames{'mean_Accuracy'} = 'MeanAccuracy';
S_acc.Properties.VariableNames{'std_Accuracy'}  = 'StdAccuracy';

S_acc.N = S_acc.GroupCount;
S_acc.SEM = S_acc.StdAccuracy ./ sqrt(S_acc.N);

%% convert accuracy to percent
S_acc.MeanAccuracy = S_acc.MeanAccuracy * 100;
S_acc.SEM = S_acc.SEM * 100;

%% =========================================================
% ADD SIGNIFICANCE TABLES
%% =========================================================
%For coloured version, use the commented .csv files
% RTsig  = readtable('RT_simple_effects_within_category_by_LOO.csv'); 
% ACCsig = readtable('Accuracy_simple_effects_within_category_from_omnibus_by_LOO.csv');
RTsig  = readtable('RT_simple_effects_within_category_from_omnibus_by_LOO_grayscale.csv');
ACCsig = readtable('Accuracy_simple_effects_within_category_from_omnibus_by_LOO_grayscale.csv');

RTsig.Category = string(RTsig.Category);
ACCsig.Category = string(ACCsig.Category);

RTsig.Category = strrep(RTsig.Category, 'Musical Instruments', 'Instrument');
RTsig.Category = strrep(RTsig.Category, 'Musical Instrument', 'Instrument');

ACCsig.Category = strrep(ACCsig.Category, 'Musical Instruments', 'Instrument');
ACCsig.Category = strrep(ACCsig.Category, 'Musical Instrument', 'Instrument');

RTsig  = RTsig(strcmp(string(RTsig.Model), 'Baseline'), :);
ACCsig = ACCsig(strcmp(string(ACCsig.Model), 'Baseline'), :);

%% =========================================================
% PLOT SETTINGS
%% =========================================================

cat_order = {'Appliance','Instrument','Vegetable','Furniture', ...
             'Tool','Vehicle','Animal','Clothing'};

colors = [
    0.0000 0.4470 0.7410;   % Original
    0.8500 0.3250 0.0980    % Incongruent / Rest
];

bar_width = 0.34;

figure('Color','w','Position',[100 100 1150 650]);

%% =========================================================
% LEFT PANEL: RT
%% =========================================================

ax1 = subplot(1,2,1); hold on;

for c = 1:numel(cat_order)

    thisCat = cat_order{c};
    y = numel(cat_order) - c + 1;

    idx_orig = strcmp(string(S_rt.Category), thisCat) & strcmp(string(S_rt.ImageType), 'Original');
    idx_rest = strcmp(string(S_rt.Category), thisCat) & strcmp(string(S_rt.ImageType), 'Rest');

    if ~any(idx_orig) || ~any(idx_rest)
        warning('Missing RT data for category: %s', thisCat);
        continue;
    end

    barh(y + bar_width/2, S_rt.MeanRT(idx_orig), bar_width, ...
        'FaceColor', colors(1,:), 'EdgeColor','none');

    errorbar(S_rt.MeanRT(idx_orig), y + bar_width/2, S_rt.SEM(idx_orig), ...
        'k', 'horizontal', 'LineWidth', 1, 'LineStyle','none', 'CapSize', 0);

    barh(y - bar_width/2, S_rt.MeanRT(idx_rest), bar_width, ...
        'FaceColor', colors(2,:), 'EdgeColor','none');

    errorbar(S_rt.MeanRT(idx_rest), y - bar_width/2, S_rt.SEM(idx_rest), ...
        'k', 'horizontal', 'LineWidth', 1, 'LineStyle','none', 'CapSize', 0);

    %% RT significance stars + mean difference
    idx_sig = strcmp(string(RTsig.Category), thisCat);
    
    if any(idx_sig)
    
        p = RTsig.pFDR(idx_sig);
        p = p(1);
    
        stars = getStars(p);
    
        % Difference: Rest - Original
        rt_diff_sec = S_rt.MeanRT(idx_rest) - S_rt.MeanRT(idx_orig);
        rt_diff_ms  = rt_diff_sec * 1000;
    
        if ~isempty(stars)
    
            x_star = max([ ...
                S_rt.MeanRT(idx_orig) + S_rt.SEM(idx_orig), ...
                S_rt.MeanRT(idx_rest) + S_rt.SEM(idx_rest)]) + 0.006;
    
            label_text = sprintf('%s  %0.0f ms', stars, rt_diff_ms);
    
            text(x_star, y, label_text, ...
                'FontSize', 16, ...
                'VerticalAlignment', 'middle');
        end
    end
end

set(gca, ...
    'YTick', 1:numel(cat_order), ...
    'YTickLabel', fliplr(cat_order), ...
    'YLim', [0.5 numel(cat_order)+0.5], ...
    'FontSize', 25, ...
    'LineWidth', 1.1, ...
    'Box', 'off');

xlabel('Mean Reaction Time (s)', 'FontSize', 25);
xlim([0.00 0.55]);

%% =========================================================
% RIGHT PANEL: ACCURACY
%% =========================================================

ax2 = subplot(1,2,2); hold on;

for c = 1:numel(cat_order)

    thisCat = cat_order{c};
    y = numel(cat_order) - c + 1;

    idx_orig = strcmp(string(S_acc.Category), thisCat) & strcmp(string(S_acc.ImageType), 'Original');
    idx_rest = strcmp(string(S_acc.Category), thisCat) & strcmp(string(S_acc.ImageType), 'Rest');

    if ~any(idx_orig) || ~any(idx_rest)
        warning('Missing accuracy data for category: %s', thisCat);
        continue;
    end

    barh(y + bar_width/2, S_acc.MeanAccuracy(idx_orig), bar_width, ...
        'FaceColor', colors(1,:), 'EdgeColor','none');

    errorbar(S_acc.MeanAccuracy(idx_orig), y + bar_width/2, S_acc.SEM(idx_orig), ...
        'k', 'horizontal', 'LineWidth', 1, 'LineStyle','none', 'CapSize', 0);

    barh(y - bar_width/2, S_acc.MeanAccuracy(idx_rest), bar_width, ...
        'FaceColor', colors(2,:), 'EdgeColor','none');

    errorbar(S_acc.MeanAccuracy(idx_rest), y - bar_width/2, S_acc.SEM(idx_rest), ...
        'k', 'horizontal', 'LineWidth', 1, 'LineStyle','none', 'CapSize', 0);

    %% Accuracy significance stars + mean difference
    idx_sig = strcmp(string(ACCsig.Category), thisCat);
    
    if any(idx_sig)
    
        p = ACCsig.pFDR(idx_sig);
        p = p(1);
    
        stars = getStars(p);
    
        % Difference: Rest - Original
        acc_diff = S_acc.MeanAccuracy(idx_rest) - S_acc.MeanAccuracy(idx_orig);
    
        if ~isempty(stars)
    
            x_star = max([ ...
                S_acc.MeanAccuracy(idx_orig) + S_acc.SEM(idx_orig), ...
                S_acc.MeanAccuracy(idx_rest) + S_acc.SEM(idx_rest)]) + 0.7;
    
            label_text = sprintf('%s  %0.1f%%', stars, acc_diff);
    
            text(x_star, y, label_text, ...
                'FontSize', 16, ...
                'VerticalAlignment', 'middle');
        end
    end
end

set(gca, ...
    'YTick', 1:numel(cat_order), ...
    'YTickLabel', {}, ...
    'YLim', [0.5 numel(cat_order)+0.5], ...
    'FontSize', 25, ...
    'LineWidth', 1.1, ...
    'Box', 'off');

xlabel('Accuracy (%)', 'FontSize', 25);
xlim([0 100]);

%% =========================================================
% LEGEND
%% =========================================================

hOrig = barh(nan, nan, 'FaceColor', colors(1,:), 'EdgeColor','none');
hRest = barh(nan, nan, 'FaceColor', colors(2,:), 'EdgeColor','none');

legend([hOrig hRest], ...
    {'Original Material','Incongruent Materials'}, ...
    'Location','best', ...
    'Box','off', ...
    'FontSize',20);

%% =========================================================
% AXES
%% =========================================================
ylim(ax1, [0.5 numel(cat_order)+0.5]);
ylim(ax2, [0.5 numel(cat_order)+0.5]);

set(ax1, 'YDir', 'normal');
set(ax2, 'YDir', 'normal');

%% -------------------------------------------------
% SAVE FIGURE
%% -------------------------------------------------

% set(gcf, 'PaperPositionMode', 'auto');
% print(gcf, 'RT_Accuracy_Original_vs_Incongruent_Grayscale.png', '-dpng', '-r300');
% 
% fprintf('\nSaved figure: RT_Accuracy_Original_vs_Incongruent_Grayscale.png\n');
% 
%% =========================================================
% LOCAL FUNCTION
%% =========================================================

function stars = getStars(p)

    if p < 0.001
        stars = '***';
    elseif p < 0.01
        stars = '**';
    elseif p < 0.05
        stars = '*';
    else
        stars = '';
    end

end