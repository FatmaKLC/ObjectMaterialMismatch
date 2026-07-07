%% =========================================================
% ACCURACY AREA/LUMINANCE MODEL
% + LEAVE-ONE-OUT ROBUSTNESS
% + WITHIN-CATEGORY SIMPLE EFFECTS FROM SAME OMNIBUS MODEL
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
% RECALCULATE TRIAL-LEVEL ACCURACY
%% -------------------------------------------------
is_go_trial = strcmp(response_data.Category, response_data.Subfolder);
did_respond = ~isnan(response_data.ReactionTime) & response_data.ReactionTime >= 0.1;

response_data.RecalculatedCorrect = ...
    (is_go_trial & did_respond) | (~is_go_trial & ~did_respond);

%% -------------------------------------------------
% DEFINE ImageType
%% -------------------------------------------------
response_data.ImageType = repmat("Rest", height(response_data), 1);
response_data.ImageType(contains(lower(string(response_data.ImageShown)), 'original')) = "Original";
response_data.ImageType = categorical(response_data.ImageType);

%% -------------------------------------------------
% REMOVE MISSING PREDICTORS
%% -------------------------------------------------
valid_predictors = ...
    ~isnan(response_data.AreaProp_z) & ...
    ~isnan(response_data.MeanL_z);

acc_data = response_data(valid_predictors, :);

%% -------------------------------------------------
% BUILD CLEAN MODEL TABLE
%% -------------------------------------------------
M = table();

M.Accuracy   = double(acc_data.RecalculatedCorrect(:));
M.AreaProp_z = double(acc_data.AreaProp_z(:));
M.MeanL_z    = double(acc_data.MeanL_z(:));

M.Participant = categorical(string(acc_data.Participant(:)));
M.Category    = categorical(string(acc_data.Category(:)));
M.ImageType   = categorical(string(acc_data.ImageType(:)));
M.ObjectKey   = categorical(string(acc_data.ObjectKey(:)));

% make sure Original is reference
if any(strcmp(categories(M.ImageType), 'Original')) && any(strcmp(categories(M.ImageType), 'Rest'))
    M.ImageType = reordercats(M.ImageType, {'Original','Rest'});
end

fprintf('Accuracy rows in model: %d\n', height(M));
fprintf('Mean accuracy: %.3f\n', mean(M.Accuracy));

%% -------------------------------------------------
% LEAVE-ONE-OUT ROBUSTNESS ANALYSIS
%% -------------------------------------------------
modelNames = { ...
    'Full'; ...
    'NoArea'; ...
    'NoMeanL'; ...
    'Baseline'};

formulas = { ...
    ['Accuracy ~ Category * ImageType + MeanL_z + AreaProp_z + ' ...
     '(1|Participant) + (1|ObjectKey)']; ...
    ['Accuracy ~ Category * ImageType + MeanL_z + ' ...
     '(1|Participant) + (1|ObjectKey)']; ...
    ['Accuracy ~ Category * ImageType + AreaProp_z + ' ...
     '(1|Participant) + (1|ObjectKey)']; ...
    ['Accuracy ~ Category * ImageType + ' ...
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
simple_effects_summary = table();

cat_levels = categories(M.Category);

for i = 1:nModels

    thisName = modelNames{i};
    thisFormula = formulas{i};

    fprintf('\n==================================================\n');
    fprintf('RUNNING ACCURACY MODEL: %s\n', thisName);
    fprintf('%s\n', thisFormula);
    fprintf('==================================================\n');

    %% -----------------------------
    % Fit omnibus GLME model
    %% -----------------------------
    glme_tmp = fitglme(M, thisFormula, ...
        'Distribution', 'Binomial', ...
        'Link', 'logit');

    a = anova(glme_tmp);

    disp(glme_tmp)
    disp(a)

    %% -----------------------------
    % Summary row: Category:ImageType
    %% -----------------------------
    idx_key = strcmp(a.Term, 'Category:ImageType');

    loo_summary.Model(i) = string(thisName);
    loo_summary.AIC(i) = glme_tmp.ModelCriterion.AIC;
    loo_summary.BIC(i) = glme_tmp.ModelCriterion.BIC;
    loo_summary.LogLikelihood(i) = glme_tmp.LogLikelihood;

    if any(idx_key)
        loo_summary.F_CategoryImageType(i) = a.FStat(idx_key);
        loo_summary.DF1_CategoryImageType(i) = a.DF1(idx_key);
        loo_summary.DF2_CategoryImageType(i) = a.DF2(idx_key);
        loo_summary.p_CategoryImageType(i) = a.pValue(idx_key);
    end

    %% -----------------------------
    % Save omnibus coefficients
    %% -----------------------------
    coef_tbl_tmp = glme_tmp.Coefficients;

    coef_clean_tmp = table();
    coef_clean_tmp.Model    = repmat(string(thisName), height(coef_tbl_tmp), 1);
    coef_clean_tmp.Name     = coef_tbl_tmp.Name;
    coef_clean_tmp.Estimate = coef_tbl_tmp.Estimate;
    coef_clean_tmp.SE       = coef_tbl_tmp.SE;
    coef_clean_tmp.tStat    = coef_tbl_tmp.tStat;
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
    % WITHIN-CATEGORY SIMPLE EFFECTS
    % Effect(Rest vs Original | Category = c)
    % For accuracy, beta is log-odds difference.
    %% =================================================
    coef_names = string(coef_tbl_tmp.Name);
    beta_hat   = coef_tbl_tmp.Estimate;
    CovB       = glme_tmp.CoefficientCovariance;

    idx_main = find(coef_names == "ImageType_Rest");

    if isempty(idx_main)
        error('Could not find coefficient "ImageType_Rest". Check ImageType reference coding.');
    end

    for c = 1:numel(cat_levels)

        thisCat = string(cat_levels{c});

        Ncat = sum(M.Category == thisCat);
        acc_mean = mean(M.Accuracy(M.Category == thisCat));

        L = zeros(numel(beta_hat), 1);
        L(idx_main) = 1;

        pattern1 = "Category_" + thisCat + ":ImageType_Rest";
        pattern2 = "ImageType_Rest:Category_" + thisCat;

        idx_inter = find(coef_names == pattern1 | coef_names == pattern2);

        if ~isempty(idx_inter)
            L(idx_inter) = 1;
        end

        beta_val = L' * beta_hat;
        se_val   = sqrt(L' * CovB * L);

        z_val = beta_val / se_val;

        % GLME: use normal approximation
        p_val = 2 * (1 - normcdf(abs(z_val)));

        low_val = beta_val - 1.96 * se_val;
        up_val  = beta_val + 1.96 * se_val;

        odds_ratio = exp(beta_val);
        OR_low = exp(low_val);
        OR_up  = exp(up_val);

        if beta_val > 0
            dir_txt = "Rest more accurate";
        elseif beta_val < 0
            dir_txt = "Rest less accurate";
        else
            dir_txt = "No difference";
        end

        tmpRow = table();
        tmpRow.Model = string(thisName);
        tmpRow.Category = thisCat;
        tmpRow.N = Ncat;
        tmpRow.MeanAccuracy = acc_mean;
        tmpRow.Beta_RestVsOriginal = beta_val;
        tmpRow.SE = se_val;
        tmpRow.zStat = z_val;
        tmpRow.pValue_coef = p_val;
        tmpRow.Lower = low_val;
        tmpRow.Upper = up_val;
        tmpRow.OddsRatio = odds_ratio;
        tmpRow.OR_Lower = OR_low;
        tmpRow.OR_Upper = OR_up;
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
writetable(loo_summary, 'Accuracy_leave_one_out_summary_grayscale.csv');
writetable(all_loo_coefs, 'Accuracy_leave_one_out_coefficients_grayscale.csv');
writetable(all_loo_anova, 'Accuracy_leave_one_out_ANOVA_grayscale.csv');

writetable(simple_effects_summary, ...
    'Accuracy_simple_effects_within_category_from_omnibus_by_LOO_grayscale.csv');

fprintf('\nSaved accuracy leave-one-out outputs.\n');

disp(loo_summary);
disp(simple_effects_summary);

%% =========================================================
% ONE-PLOT SUMMARY OF SIMPLE EFFECTS ACROSS ALL MODELS
%% =========================================================

% model_order = {'Full','NoArea','NoMeanL','Baseline'};
% cat_order = categories(categorical(string(simple_effects_summary.Category)));
% 
% S = simple_effects_summary;
% S.Model = categorical(string(S.Model), model_order, 'Ordinal', true);
% S.Category = categorical(string(S.Category), cat_order, 'Ordinal', true);
% 
% S = sortrows(S, {'Category','Model'});
% 
% colors = [
%     0.0000 0.4470 0.7410;
%     0.8500 0.3250 0.0980;
%     0.9290 0.6940 0.1250;
%     0.3010 0.7450 0.9330
% ];
% 
% base_y = 1:numel(cat_order);
% offsets = linspace(-0.28, 0.28, numel(model_order));
% 
% figure('Color','w','Position',[100 100 1200 700]); hold on;
% 
% xline(0, '--k', 'LineWidth', 1.2);
% 
% legend_handles = gobjects(numel(model_order),1);
% 
% for m = 1:numel(model_order)
%     thisModel = model_order{m};
%     idx_model = S.Model == thisModel;
% 
%     Sm = S(idx_model, :);
% 
%     legend_handles(m) = plot(nan, nan, 'o-', ...
%         'Color', colors(m,:), ...
%         'MarkerFaceColor', colors(m,:), ...
%         'MarkerEdgeColor', colors(m,:), ...
%         'LineWidth', 1.5, ...
%         'MarkerSize', 7);
% 
%     for c = 1:numel(cat_order)
%         thisCat = cat_order{c};
%         idx = Sm.Category == thisCat;
% 
%         if ~any(idx)
%             continue;
%         end
% 
%         beta  = Sm.Beta_RestVsOriginal(idx);
%         lower = Sm.Lower(idx);
%         upper = Sm.Upper(idx);
% 
%         y = base_y(c) + offsets(m);
% 
%         plot([lower upper], [y y], '-', ...
%             'Color', colors(m,:), 'LineWidth', 1.5);
% 
%         pfdr = Sm.pFDR(idx);
%         isSig = ~isnan(pfdr) && pfdr < 0.05;
% 
%         if isSig
%             plot(beta, y, 'o', ...
%                 'MarkerSize', 7, ...
%                 'MarkerFaceColor', colors(m,:), ...
%                 'MarkerEdgeColor', colors(m,:), ...
%                 'LineWidth', 1.2);
%         else
%             plot(beta, y, 'o', ...
%                 'MarkerSize', 7, ...
%                 'MarkerFaceColor', 'w', ...
%                 'MarkerEdgeColor', colors(m,:), ...
%                 'LineWidth', 1.2);
%         end
%     end
% end
% 
% set(gca, 'YTick', base_y, 'YTickLabel', cat_order, ...
%     'FontSize', 12, 'LineWidth', 1.2, 'Box', 'off', ...
%     'YDir', 'reverse');
% 
% xlabel('\beta for Rest vs Original accuracy (log-odds)', 'FontSize', 13);
% ylabel('Category', 'FontSize', 13);
% title('Rest vs Original accuracy effect across categories and leave-one-out models', ...
%     'FontSize', 15, 'FontWeight', 'bold');
% 
% h1 = plot(nan,nan,'o','MarkerFaceColor','k','MarkerEdgeColor','k');
% h2 = plot(nan,nan,'o','MarkerFaceColor','w','MarkerEdgeColor','k');
% 
% legend([legend_handles; h1; h2], ...
%     [model_order, {'FDR p<0.05','n.s.'}], ...
%     'Location','bestoutside');
% 
% xmin = min(S.Lower);
% xmax = max(S.Upper);
% pad = 0.05 * (xmax - xmin + eps) + 0.01;
% xlim([xmin-pad xmax+pad]);
% 
% grid off;
% set(gca, 'GridAlpha', 0.15);
% 
