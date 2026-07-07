%% =========================================================
% ACCURACY AREA MODEL
% Matches old accuracy structure:
% - Recalculate trial-level correctness
% - ImageType = Original vs Rest
% - Adds AreaProp_z as continuous predictor
%% =========================================================

clear; clc;

%% LOAD DATA
load('data_with_mask_and_hsv.mat');  % loads T

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
% RECALCULATE TRIAL-LEVEL ACCURACY (same as old analysis)
%% -------------------------------------------------
is_go_trial = strcmp(response_data.Category, response_data.Subfolder);
did_respond = ~isnan(response_data.ReactionTime) & response_data.ReactionTime >= 0.1;

response_data.RecalculatedCorrect = ...
    (is_go_trial & did_respond) | (~is_go_trial & ~did_respond);

%% -------------------------------------------------
% DEFINE ImageType
%% -------------------------------------------------
is_original = contains(lower(string(response_data.ImageShown)), 'original');
ImageType = repmat("Rest", height(response_data), 1);
ImageType(is_original) = "Original";
response_data.ImageType = categorical(ImageType);

%% -------------------------------------------------
% REMOVE MISSING AREA / ACCURACY
%% -------------------------------------------------
valid_predictors = ...
    ~isnan(response_data.AreaProp_z) & ...
    ~isnan(response_data.MeanS_z) & ...
    ~isnan(response_data.MeanV_z) & ...
    ~isnan(response_data.HueX_z) & ...
    ~isnan(response_data.HueY_z);

acc_data = response_data(valid_predictors, :);
%acc_data = response_data(~isnan(response_data.AreaProp_z), :);
acc_data = acc_data(~isnan(acc_data.RecalculatedCorrect), :);

%% -------------------------------------------------
% BUILD CLEAN MODEL TABLE
%% -------------------------------------------------
M = table();

M.Accuracy = double(acc_data.RecalculatedCorrect(:));
M.AreaProp_z = double(acc_data.AreaProp_z(:));
M.AreaProp_z = double(acc_data.AreaProp_z(:));
M.MeanS_z    = double(acc_data.MeanS_z(:));
M.MeanV_z    = double(acc_data.MeanV_z(:));
M.HueX_z     = double(acc_data.HueX_z(:));
M.HueY_z     = double(acc_data.HueY_z(:));

M.Participant = categorical(string(acc_data.Participant(:)));
M.Category    = categorical(string(acc_data.Category(:)));
M.ImageType   = categorical(string(acc_data.ImageType(:)));
M.ObjectKey   = categorical(string(acc_data.ObjectKey(:)));

fprintf('Accuracy rows in model: %d\n', height(M));

%% -------------------------------------------------
% FIT MODEL
%% -------------------------------------------------
formula = 'Accuracy ~ Category * ImageType * AreaProp_z + (1|Participant) + (1|ObjectKey)';

glme = fitglme(M, formula, ...
    'Distribution', 'Binomial', ...
    'Link', 'logit');

disp(glme)
anova_results = anova(glme);
disp(anova_results)

%% -------------------------------------------------
% SAVE COEFFICIENTS
%% -------------------------------------------------
coef_tbl = glme.Coefficients;

coef_clean = table();
coef_clean.Name     = coef_tbl.Name;
coef_clean.Estimate = coef_tbl.Estimate;
coef_clean.SE       = coef_tbl.SE;
coef_clean.tStat    = coef_tbl.tStat;
coef_clean.DF       = coef_tbl.DF;
coef_clean.pValue   = coef_tbl.pValue;
coef_clean.Lower    = coef_tbl.Lower;
coef_clean.Upper    = coef_tbl.Upper;

writetable(coef_clean, 'Accuracy_AreaModel_Coefficients.csv');

%% -------------------------------------------------
% SAVE ANOVA TABLE
%% -------------------------------------------------
anova_clean = table();
anova_clean.Term   = anova_results.Term;
anova_clean.DF1    = anova_results.DF1;
anova_clean.DF2    = anova_results.DF2;
anova_clean.FStat  = anova_results.FStat;
anova_clean.pValue = anova_results.pValue;

writetable(anova_clean, 'Accuracy_AreaModel_ANOVA.csv');

fprintf('Saved accuracy model outputs.\n');

%% =========================================================
% PLOT MODEL-PREDICTED ACCURACY BY AREA
%% =========================================================
cat_levels = categories(M.Category);
img_levels = categories(M.ImageType);

xgrid = linspace(min(M.AreaProp_z), max(M.AreaProp_z), 100)';
nCat = numel(cat_levels);

colors = [0 0.4470 0.7410;   % Original
          0.8500 0.3250 0.0980]; % Rest

% -------------------------------------------------
% FIRST PASS: collect all predictions for common y-limits
% -------------------------------------------------
all_preds = [];

for c = 1:nCat
    thisCat = cat_levels{c};

    for it = 1:numel(img_levels)
        thisImg = img_levels{it};

        predTbl = table();
        predTbl.AreaProp_z = xgrid;
        predTbl.Category   = categorical(repmat({thisCat}, numel(xgrid), 1), cat_levels);
        predTbl.ImageType  = categorical(repmat({thisImg}, numel(xgrid), 1), img_levels);

        % dummy valid grouping values
        predTbl.Participant = repmat(M.Participant(1), numel(xgrid), 1);
        predTbl.ObjectKey   = repmat(M.ObjectKey(1), numel(xgrid), 1);

        % fixed-effects only prediction
        yhat = predict(glme, predTbl, 'Conditional', false);

        % if MATLAB returns logits instead of probabilities, convert:
        if any(yhat < 0) || any(yhat > 1)
            yhat = 1 ./ (1 + exp(-yhat));
        end

        all_preds = [all_preds; yhat(:)];
    end
end

global_ylim = [min(all_preds) max(all_preds)] * 100;

% -------------------------------------------------
% PLOT
% -------------------------------------------------
figure('Color', 'w', 'Position', [100 100 1500 800]);

for c = 1:nCat
    subplot(2,4,c); hold on;

    thisCat = cat_levels{c};

    for it = 1:numel(img_levels)
        thisImg = img_levels{it};

        predTbl = table();
        predTbl.AreaProp_z = xgrid;
        predTbl.Category   = categorical(repmat({thisCat}, numel(xgrid), 1), cat_levels);
        predTbl.ImageType  = categorical(repmat({thisImg}, numel(xgrid), 1), img_levels);

        predTbl.Participant = repmat(M.Participant(1), numel(xgrid), 1);
        predTbl.ObjectKey   = repmat(M.ObjectKey(1), numel(xgrid), 1);

        yhat = predict(glme, predTbl, 'Conditional', false);

        % safety conversion if needed
        if any(yhat < 0) || any(yhat > 1)
            yhat = 1 ./ (1 + exp(-yhat));
        end

        yhat_pct = yhat * 100;

        if strcmp(thisImg, 'Original')
            plot(xgrid, yhat_pct, '-', 'Color', colors(1,:), 'LineWidth', 2);
        else
            plot(xgrid, yhat_pct, '--', 'Color', colors(2,:), 'LineWidth', 2);
        end
    end

    title(thisCat, 'FontWeight', 'bold', 'Color', 'k');
    xlabel('AreaProp_z', 'Color', 'k');
    ylabel('Predicted Accuracy (%)', 'Color', 'k');

    ylim(global_ylim)
    box off
    set(gca, ...
        'FontSize', 11, ...
        'LineWidth', 1.1, ...
        'Color', 'w', ...
        'XColor', 'k', ...
        'YColor', 'k');
end

% legend from dummy handles
h1 = plot(nan, nan, '-',  'Color', colors(1,:), 'LineWidth', 2);
h2 = plot(nan, nan, '--', 'Color', colors(2,:), 'LineWidth', 2);
lgd = legend([h1 h2], {'Original', 'Rest'}, ...
    'Location', 'southoutside', ...
    'Orientation', 'horizontal');
set(lgd, 'TextColor', 'k', 'Color', 'w');

sgtitle('Model-predicted Accuracy as a Function of Area', ...
    'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');