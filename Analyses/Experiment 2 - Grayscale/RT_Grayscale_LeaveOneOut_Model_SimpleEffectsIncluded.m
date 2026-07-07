%% =========================================================
% RT AREA MODEL
% + LEAVE-ONE-OUT ROBUSTNESS
% + WITHIN-CATEGORY SIMPLE EFFECTS FROM THE SAME OMNIBUS MODEL
%% =========================================================

clear; clc;

%% LOAD DATA
load('data_with_mask_and_luminance.mat');   % loads T
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
% DEFINE GO + PRESSED TRIALS
%% -------------------------------------------------
is_go_trial = strcmp(response_data.Category, response_data.Subfolder);
pressed_condition = ~isnan(response_data.ReactionTime) & response_data.ReactionTime >= 0.1;
valid_go_trials = is_go_trial & pressed_condition;

rt_data = response_data(valid_go_trials, :);

%% -------------------------------------------------
% DEFINE ImageType
%% -------------------------------------------------
rt_data.ImageType = repmat("Rest", height(rt_data), 1);
rt_data.ImageType(contains(lower(string(rt_data.ImageShown)), 'original')) = "Original";
rt_data.ImageType = categorical(rt_data.ImageType);

%% -------------------------------------------------
% REMOVE MISSING VALUES
%% -------------------------------------------------
valid_predictors = ...
    ~isnan(rt_data.AreaProp_z) & ...
    ~isnan(rt_data.MeanL_z);

rt_data = rt_data(valid_predictors, :);

%% -------------------------------------------------
% BUILD CLEAN MODEL TABLE
%% -------------------------------------------------
M = table();

M.logRT      = double(log(rt_data.ReactionTime(:)));
M.AreaProp_z = double(rt_data.AreaProp_z(:));
M.MeanL_z    = double(rt_data.MeanL_z(:));

M.Participant = categorical(string(rt_data.Participant(:)));
M.Category    = categorical(string(rt_data.Category(:)));
M.ImageType   = categorical(string(rt_data.ImageType(:)));
M.ObjectKey   = categorical(string(rt_data.ObjectKey(:)));

% make sure Original is reference
if any(strcmp(categories(M.ImageType), 'Original')) && any(strcmp(categories(M.ImageType), 'Rest'))
    M.ImageType = reordercats(M.ImageType, {'Original','Rest'});
end

fprintf('RT rows in model: %d\n', height(M));

%% -------------------------------------------------
% LEAVE-ONE-OUT ROBUSTNESS ANALYSIS
%% -------------------------------------------------
modelNames = { ...
    'Full'; ...
    'NoArea'; ...
    'NoMeanL'; ...
    'Baseline'};

formulas = { ...
    ['logRT ~ Category * ImageType + MeanL_z + AreaProp_z + ' ...
     '(1|Participant) + (1|ObjectKey)']; ...
    ['logRT ~ Category * ImageType + MeanL_z + ' ...
     '(1|Participant) + (1|ObjectKey)']; ...
    ['logRT ~ Category * ImageType + AreaProp_z + ' ...
     '(1|Participant) + (1|ObjectKey)']; ...
    ['logRT ~ Category * ImageType + ' ...
     '(1|Participant) + (1|ObjectKey)']};

nModels = numel(modelNames);

loo_summary = table( ...
    strings(nModels,1), ...
    nan(nModels,1), nan(nModels,1), nan(nModels,1), ...
    nan(nModels,1), nan(nModels,1), nan(nModels,1), nan(nModels,1), ...
    'VariableNames', {'Model','AIC','BIC','LogLikelihood', ...
    'F_CategoryImageType','DF1_CategoryImageType','DF2_CategoryImageType','p_CategoryImageType'});

all_loo_coefs = table();
all_loo_anova = table();

% per-category simple effects tables
simple_effects_summary = table();

cat_levels = categories(M.Category);

for i = 1:nModels

    thisName = modelNames{i};
    thisFormula = formulas{i};

    fprintf('\n==================================================\n');
    fprintf('RUNNING LOO MODEL: %s\n', thisName);
    fprintf('%s\n', thisFormula);
    fprintf('==================================================\n');

    %% -----------------------------
    % Fit omnibus LOO model
    %% -----------------------------
    lme_tmp = fitlme(M, thisFormula);
    a = anova(lme_tmp);

    disp(lme_tmp)
    disp(a)

    %% -----------------------------
    % Summary row: Category:ImageType
    %% -----------------------------
    idx_key = strcmp(a.Term, 'Category:ImageType');

    loo_summary.Model(i) = string(thisName);
    loo_summary.AIC(i) = lme_tmp.ModelCriterion.AIC;
    loo_summary.BIC(i) = lme_tmp.ModelCriterion.BIC;
    loo_summary.LogLikelihood(i) = lme_tmp.LogLikelihood;

    if any(idx_key)
        loo_summary.F_CategoryImageType(i) = a.FStat(idx_key);
        loo_summary.DF1_CategoryImageType(i) = a.DF1(idx_key);
        loo_summary.DF2_CategoryImageType(i) = a.DF2(idx_key);
        loo_summary.p_CategoryImageType(i) = a.pValue(idx_key);
    end

    %% -----------------------------
    % Save omnibus coefficients
    %% -----------------------------
    coef_tbl_tmp = lme_tmp.Coefficients;

    coef_clean_tmp = table();
    coef_clean_tmp.Model    = repmat(string(thisName), height(coef_tbl_tmp), 1);
    coef_clean_tmp.Name     = coef_tbl_tmp.Name;
    coef_clean_tmp.Estimate = coef_tbl_tmp.Estimate;
    coef_clean_tmp.SE       = coef_tbl_tmp.SE;
    coef_clean_tmp.tStat    = coef_tbl_tmp.tStat;
    coef_clean_tmp.DF       = coef_tbl_tmp.DF;
    coef_clean_tmp.pValue   = coef_tbl_tmp.pValue;
    coef_clean_tmp.Lower    = coef_tbl_tmp.Lower;
    coef_clean_tmp.Upper    = coef_tbl_tmp.Upper;

    all_loo_coefs = [all_loo_coefs; coef_clean_tmp];

    %% -----------------------------
    % Save omnibus ANOVA
    %% -----------------------------
    anova_clean_tmp = table();
    anova_clean_tmp.Model  = repmat(string(thisName), height(a), 1);
    anova_clean_tmp.Term   = a.Term;
    anova_clean_tmp.DF1    = a.DF1;
    anova_clean_tmp.DF2    = a.DF2;
    anova_clean_tmp.FStat  = a.FStat;
    anova_clean_tmp.pValue = a.pValue;

    all_loo_anova = [all_loo_anova; anova_clean_tmp];

    %% =================================================
    % WITHIN-CATEGORY SIMPLE EFFECTS FROM SAME OMNIBUS MODEL
    % Effect(Rest vs Original | Category = c)
    %% =================================================
    coef_names = string(coef_tbl_tmp.Name);
    beta_hat   = coef_tbl_tmp.Estimate;
    CovB       = lme_tmp.CoefficientCovariance;
    df_resid   = lme_tmp.DFE;

    % main effect of Rest (for reference category)
    idx_main = find(coef_names == "ImageType_Rest");

    if isempty(idx_main)
        error('Could not find coefficient "ImageType_Rest". Check ImageType reference coding.');
    end

    for c = 1:numel(cat_levels)

        thisCat = string(cat_levels{c});

        % sample size for this category
        Ncat = sum(M.Category == thisCat);

        % contrast vector
        L = zeros(numel(beta_hat), 1);
        L(idx_main) = 1;

        % look for interaction term in either naming order
        pattern1 = "Category_" + thisCat + ":ImageType_Rest";
        pattern2 = "ImageType_Rest:Category_" + thisCat;

        idx_inter = find(coef_names == pattern1 | coef_names == pattern2);

        % reference category will not have an interaction term
        if ~isempty(idx_inter)
            L(idx_inter) = 1;
        end

        % estimate
        beta_val = L' * beta_hat;

        % SE
        se_val = sqrt(L' * CovB * L);

        % t
        t_val = beta_val / se_val;

        % p-value
        p_val = 2 * (1 - tcdf(abs(t_val), df_resid));

        % 95% CI
        tcrit = tinv(0.975, df_resid);
        low_val = beta_val - tcrit * se_val;
        up_val  = beta_val + tcrit * se_val;

        % direction
        if beta_val > 0
            dir_txt = "Rest slower";
        elseif beta_val < 0
            dir_txt = "Rest faster";
        else
            dir_txt = "No difference";
        end

        % summary row
        tmpRow = table();
        tmpRow.Model = string(thisName);
        tmpRow.Category = thisCat;
        tmpRow.N = Ncat;
        tmpRow.Beta_RestVsOriginal = beta_val;
        tmpRow.SE = se_val;
        tmpRow.tStat = t_val;
        tmpRow.DF = df_resid;
        tmpRow.pValue_coef = p_val;
        tmpRow.Lower = low_val;
        tmpRow.Upper = up_val;
        tmpRow.Direction = dir_txt;

        simple_effects_summary = [simple_effects_summary; tmpRow];
    end
end

%% -------------------------------------------------
% FDR correction WITHIN EACH MODEL
%% -------------------------------------------------
simple_effects_summary.pFDR = nan(height(simple_effects_summary),1);

model_levels = unique(simple_effects_summary.Model);

for m = 1:numel(model_levels)

    thisModel = model_levels(m);
    idx_model = simple_effects_summary.Model == thisModel;

    p = simple_effects_summary.pValue_coef(idx_model);
    valid_p = ~isnan(p);

    pFDR_model = nan(size(p));

    if any(valid_p)
        p_valid = p(valid_p);
        [sorted_p, sort_idx] = sort(p_valid);

        nTests = numel(p_valid);
        q = zeros(size(p_valid));

        for k = 1:nTests
            q(k) = sorted_p(k) * nTests / k;
        end

        q = flipud(cummin(flipud(q)));
        q(q > 1) = 1;

        tmp = nan(size(p_valid));
        tmp(sort_idx) = q;

        pFDR_model(valid_p) = tmp;
    end

    simple_effects_summary.pFDR(idx_model) = pFDR_model;
end

%% -------------------------------------------------
% SIGNIFICANCE LABEL
%% -------------------------------------------------
simple_effects_summary.Significant = repmat("n.s.", height(simple_effects_summary), 1);
simple_effects_summary.Significant(simple_effects_summary.pFDR < 0.05) = "FDR<.05";

%% -------------------------------------------------
% SAVE OUTPUTS
%% -------------------------------------------------
writetable(loo_summary, 'RT_leave_one_out_summary_grayscale.csv');
writetable(all_loo_coefs, 'RT_leave_one_out_coefficients_grayscale.csv');
writetable(all_loo_anova, 'RT_leave_one_out_ANOVA_grayscale.csv');

writetable(simple_effects_summary, 'RT_simple_effects_within_category_from_omnibus_by_LOO_grayscale.csv');

fprintf('\nSaved leave-one-out outputs.\n');

%% -------------------------------------------------
% DISPLAY SUMMARY TABLES
%% -------------------------------------------------
fprintf('\n==================================================\n');
fprintf('LEAVE-ONE-OUT SUMMARY\n');
fprintf('==================================================\n');
disp(loo_summary);

fprintf('\n==================================================\n');
fprintf('WITHIN-CATEGORY SIMPLE EFFECTS SUMMARY\n');
fprintf('==================================================\n');
disp(simple_effects_summary);

%% =========================================================
% ONE-PLOT SUMMARY OF SIMPLE EFFECTS ACROSS ALL MODELS
% x-axis: Beta_RestVsOriginal
% y-axis: Category
% color: Model
% horizontal error bars: 95% CI
% filled marker = survives FDR
%% =========================================================

% ---------- choose model order ----------
model_order = {'Full','NoArea','NoMeanL','Baseline'};

% use actual category order from data, no hardcoding
cat_order = categories(categorical(string(simple_effects_summary.Category)));

% make copies as categoricals for stable ordering
S = simple_effects_summary;
S.Model = categorical(string(S.Model), model_order, 'Ordinal', true);
S.Category = categorical(string(S.Category), cat_order, 'Ordinal', true);

% sort rows
S = sortrows(S, {'Category','Model'});

% colors for models
colors = [
    0.0000 0.4470 0.7410;   % Full
    0.8500 0.3250 0.0980;   % NoArea
    0.9290 0.6940 0.1250;   % NoMeanL
    0.3010 0.7450 0.9330    % Baseline
];

% y positions with small offsets so models do not overlap
base_y = 1:numel(cat_order);
offsets = linspace(-0.28, 0.28, numel(model_order));

figure('Color','w','Position',[100 100 1200 700]); hold on;

% vertical reference at zero
xline(0, '--k', 'LineWidth', 1.2);

% dummy handles for correct legend
legend_handles = gobjects(numel(model_order),1);

for m = 1:numel(model_order)
    thisModel = model_order{m};
    idx_model = S.Model == thisModel;

    Sm = S(idx_model, :);

    % create dummy handle for legend
    legend_handles(m) = plot(nan, nan, 'o-', ...
        'Color', colors(m,:), ...
        'MarkerFaceColor', colors(m,:), ...
        'MarkerEdgeColor', colors(m,:), ...
        'LineWidth', 1.5, ...
        'MarkerSize', 7);

    for c = 1:numel(cat_order)
        thisCat = cat_order{c};
        idx = Sm.Category == thisCat;

        if ~any(idx)
            continue;
        end

        beta  = Sm.Beta_RestVsOriginal(idx);
        lower = Sm.Lower(idx);
        upper = Sm.Upper(idx);

        y = base_y(c) + offsets(m);

        % CI line
        plot([lower upper], [y y], '-', ...
            'Color', colors(m,:), 'LineWidth', 1.5);

        % significance by FDR
        pfdr = Sm.pFDR(idx);
        isSig = ~isnan(pfdr) && pfdr < 0.05;

        % point
        if isSig
            plot(beta, y, 'o', ...
                'MarkerSize', 7, ...
                'MarkerFaceColor', colors(m,:), ...
                'MarkerEdgeColor', colors(m,:), ...
                'LineWidth', 1.2);
        else
            plot(beta, y, 'o', ...
                'MarkerSize', 7, ...
                'MarkerFaceColor', 'w', ...
                'MarkerEdgeColor', colors(m,:), ...
                'LineWidth', 1.2);
        end
    end
end

% y-axis labels
set(gca, 'YTick', base_y, 'YTickLabel', cat_order, ...
    'FontSize', 12, 'LineWidth', 1.2, 'Box', 'off', ...
    'YDir', 'reverse');

xlabel('\beta for Rest vs Original (logRT)', 'FontSize', 13);
ylabel('Category', 'FontSize', 13);
title('Rest vs Original effect across categories and leave-one-out models', ...
    'FontSize', 15, 'FontWeight', 'bold');

% significance legend
h1 = plot(nan,nan,'o','MarkerFaceColor','k','MarkerEdgeColor','k');
h2 = plot(nan,nan,'o','MarkerFaceColor','w','MarkerEdgeColor','k');

legend([legend_handles; h1; h2], ...
    [model_order, {'FDR p<0.05','n.s.'}], ...
    'Location','bestoutside');

% x-limits from CI range
xmin = min(S.Lower);
xmax = max(S.Upper);
pad = 0.01 * (xmax - xmin + eps) + 0.005;
xlim([xmin-pad xmax+pad]);

grid off;
set(gca, 'GridAlpha', 0.15);