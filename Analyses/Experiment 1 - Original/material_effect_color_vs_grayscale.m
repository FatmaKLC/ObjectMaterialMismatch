%% Material Effect: Color vs Grayscale (Effect Size Comparison)
% Author: Fatma Kilic
%
% Description:
%   - Compares the material mismatch effect (Other − Original) between:
%       1) Color experiment
%       2) Grayscale control experiment
%
%   Steps:
%     A) Compute subject means per Participant × Category × Material (Original vs Other)
%     B) Run separate 2×8 RM-ANOVAs within each experiment (Color, Grayscale)
%     C) Mixed-effects LME:
%           Overall: RT ~ Material*Experiment + Category + (1 + Material | Participant)
%           Per-category: RT ~ Material*Experiment + (1 + Material | Participant)
%     D) ΔRT corroboration:
%           ΔRT = RT_other − RT_original
%           Compare Color vs Grayscale (overall + per category)
%           Welch t-tests, FDR correction, bootstrap CIs, Cohen’s d
%     E) Plots:
%           - Overall ΔRT (Color vs Grayscale)
%           - Per-category ΔRT by experiment
%           - Forest plot of ΔΔRT (Gray − Color) with 95% CI
%
% Requirements:
%   - MATLAB (tested with R2017b+)
%   - Statistics and Machine Learning Toolbox
%
% Expected input files:
%   project_root/
%   ├─ data/
%   │   ├─ combinedData_ExpV2.mat        (color; contains combinedTable)
%   │   └─ combinedData_grayscale.mat    (grayscale; contains combinedTable)
%   └─ analysis/
%       └─ material_effect_color_vs_grayscale.m
%
% Output:
%   - Command window summaries (RM-ANOVAs, LME, Welch tests)
%   - Figures (overall ΔRT, per-category ΔRT, forest plot)
%   - Optional: you can add writetable(...) calls to save tables if desired.

%% ------------------------------------------------------------------------
%                          Configuration                                  
% -------------------------------------------------------------------------

clear; clc;

% Resolve project root as one directory above this script
thisFile   = mfilename('fullpath');
[thisDir, ~, ~] = fileparts(thisFile);
projectDir = fileparts(thisDir);

dataDir = fullfile(projectDir, 'data');

% Input data files (adjust names if needed)
color_file = fullfile(dataDir, 'combinedData_ExpV2.mat');       % color experiment
gray_file  = fullfile(dataDir, 'combinedData_grayscale.mat');   % grayscale experiment

% Number of bootstrap samples for ΔΔRT CIs
B = 10000;

%% ------------------------------------------------------------------------
%                             Load data                                   
% -------------------------------------------------------------------------

Scolor = load(color_file);
assert(isfield(Scolor, 'combinedTable'), ...
    'Color file does not contain variable "combinedTable".');

Sgray = load(gray_file);
assert(isfield(Sgray, 'combinedTable'), ...
    'Grayscale file does not contain variable "combinedTable".');

Tcolor = Scolor.combinedTable;
Tgray  = Sgray.combinedTable;

%% ------------------------------------------------------------------------
%      Participant extraction, filters, labels (Color vs Grayscale)       
% -------------------------------------------------------------------------

Tcolor = prep_table_userstyle(Tcolor, 'Color');
Tgray  = prep_table_userstyle(Tgray,  'Grayscale');

% Ensure overlapping categories only
catsC = categories(Tcolor.Category);  % cellstr
catsG = categories(Tgray.Category);   % cellstr
cats  = intersect(catsC, catsG, 'stable');   % overlapping categories

Tcolor = Tcolor(ismember(cellstr(Tcolor.Category), cats), :);
Tgray  = Tgray(ismember(cellstr(Tgray.Category),  cats), :);
cats_c = categorical(cats);  % for RM design

%% ------------------------------------------------------------------------
% A) Subject means per Participant × Category × Material                  
% -------------------------------------------------------------------------

AggC = aggregate_means(Tcolor);
AggG = aggregate_means(Tgray);

AggC = AggC(ismember(cellstr(AggC.Category), cats), :);
AggG = AggG(ismember(cellstr(AggG.Category),  cats), :);

%% ------------------------------------------------------------------------
% B) Separate 2×8 RM-ANOVAs (within each experiment)                      
% -------------------------------------------------------------------------

fprintf('\n=== Repeated-measures ANOVA: COLOR (Category × Material) ===\n');
[rmC, ranovaC, effC] = run_rm_anova(AggC, cats_c);
disp(ranovaC);
disp_effectsizes('COLOR', effC);

fprintf('\n=== Repeated-measures ANOVA: GRAYSCALE (Category × Material) ===\n');
[rmG, ranovaG, effG] = run_rm_anova(AggG, cats_c);
disp(ranovaG);
disp_effectsizes('GRAYSCALE', effG);

%% ------------------------------------------------------------------------
% C) Mixed LME: Color vs Grayscale                                        
%     Overall: RT ~ Material*Experiment + Category + (1 + Material | Participant)
%     Per-category: RT ~ Material*Experiment + (1 + Material | Participant)
% -------------------------------------------------------------------------

% Combine for LME
T = [Tcolor; Tgray];
T = table(T.ReactionTime, T.Material, T.Experiment, T.Category, T.Participant, ...
          'VariableNames', {'RT','Material','Experiment','Category','Participant'});

T.Material    = removecats(categorical(T.Material));
T.Experiment  = removecats(categorical(T.Experiment));
T.Category    = removecats(categorical(T.Category));
T.Participant = removecats(categorical(T.Participant));

% Overall LME
lme_overall = fitlme(T, ...
    'RT ~ Material*Experiment + Category + (1 + Material | Participant)');
res_overall = anova(lme_overall);

disp('=== Mixed LME (overall): RT ~ Material*Experiment + Category + (1+Material|Participant) ===');
disp(res_overall);

row_ME = effect_row_mask(res_overall, 'Material:Experiment');
show_row('Material × Experiment (overall)', subset_rows(res_overall, row_ME));

% Per-category LMEs (Material × Experiment per category)
catsL = categories(T.Category); % cellstr
K     = numel(catsL);

cat_F  = nan(K,1);
cat_p  = nan(K,1);
cat_df = nan(K,1);

for k = 1:K
    label = catsL{k};                   % char
    Tk    = T(T.Category == label, :);  % compare categorical to char
    lme_k = fitlme(Tk, 'RT ~ Material*Experiment + (1 + Material | Participant)');
    ak    = anova(lme_k);
    row   = effect_row_mask(ak, 'Material:Experiment');
    ak_row = subset_rows(ak, row);
    if ~isempty_row(ak_row)
        [Fval, DFval, pval] = read_F_dp(ak_row);
        cat_F(k)  = Fval;
        cat_df(k) = DFval;
        cat_p(k)  = pval;
    end
end

[q_catME, ~] = fdr_bh(cat_p);
perCat_LME = table(catsL(:), cat_F, cat_df, cat_p, q_catME, ...
    'VariableNames', {'Category','F','DF','p','q_FDR'});

disp('=== Per-category Material × Experiment from LME (one model per category) ===');
disp(perCat_LME);

%% ------------------------------------------------------------------------
% D) ΔRT corroboration: ΔRT = Other − Original                            
%     Compare Color vs Grayscale (overall + per category)                 
% -------------------------------------------------------------------------

DeltaC = pivot_delta(AggC); % Participant, Category, DeltaRT
DeltaG = pivot_delta(AggG);

% Overall ΔRT per subject (mean across categories)
[gC2,~] = findgroups(DeltaC.Participant);
dC      = splitapply(@(x) mean(x,'omitnan'), DeltaC.DeltaRT, gC2);

[gG2,~] = findgroups(DeltaG.Participant);
dG      = splitapply(@(x) mean(x,'omitnan'), DeltaG.DeltaRT, gG2);

[~, pWelch_over, ~, stWelch_over] = ttest2(dG, dC, 'Vartype','unequal');
d_overall = cohen_d_ind(dG, dC);

% Bootstrap CI for mean difference (Gray − Color)
diffs = nan(B,1);
for b = 1:B
    diffs(b) = mean(dG(randi(numel(dG), numel(dG), 1))) - ...
               mean(dC(randi(numel(dC), numel(dC), 1)));
end
ci_over = quantile(diffs, [0.025 0.975]);

fprintf('\n=== Welch on overall ΔRT (Gray − Color) ===\n');
fprintf('t(%.1f)=%.2f, p=%.3g, d=%.2f, 95%% CI of mean diff [%.4f, %.4f] s\n', ...
    stWelch_over.df, stWelch_over.tstat, pWelch_over, d_overall, ci_over(1), ci_over(2));

% Per-category Welch + bootstrap CI + FDR + ΔΔRT estimate
p_welch = nan(K,1);
d_cohen = nan(K,1);
ci_low  = nan(K,1);
ci_high = nan(K,1);
est_dd  = nan(K,1);

for k = 1:K
    label = catsL{k};  % char

    Dc = DeltaC.DeltaRT(DeltaC.Category == label); Dc = Dc(~isnan(Dc));
    Dg = DeltaG.DeltaRT(DeltaG.Category == label); Dg = Dg(~isnan(Dg));

    if numel(Dc) > 1 && numel(Dg) > 1
        est_dd(k) = mean(Dg) - mean(Dc);  % ΔΔRT (Gray − Color)
        [~, p_welch(k)] = ttest2(Dg, Dc, 'Vartype','unequal');
        d_cohen(k) = cohen_d_ind(Dg, Dc);

        diffs = nan(B,1);
        for b = 1:B
            diffs(b) = mean(Dg(randi(numel(Dg), numel(Dg), 1))) - ...
                       mean(Dc(randi(numel(Dc), numel(Dc), 1)));
        end
        tmp = quantile(diffs, [0.025 0.975]);
        ci_low(k)  = tmp(1);
        ci_high(k) = tmp(2);
    end
end

[q_welch, ~] = fdr_bh(p_welch);
perCat_Welch = table(catsL(:), est_dd, p_welch, q_welch, d_cohen, ci_low, ci_high, ...
    'VariableNames', {'Category','DeltaDeltaRT','p_Welch','q_FDR','Cohens_d','CI_low','CI_high'});

disp('=== Per-category ΔRT (Gray − Color) Welch tests with bootstrap CIs ===');
disp(perCat_Welch);

%% ------------------------------------------------------------------------
% E) Plots: overall bars, per-category bars, forest plot                  
% -------------------------------------------------------------------------

% ---------- Panel A: Overall ΔRT (Color vs Grayscale) ----------
figure('Color','w','Position',[100, 100, 1000, 400]);

subplot(1,2,1);
mA  = [mean(dC,'omitnan'), mean(dG,'omitnan')];
seA = [std(dC,'omitnan')/sqrt(numel(dC)), ...
       std(dG,'omitnan')/sqrt(numel(dG))];

bh = bar(mA); hold on;
if numel(bh) == 1
    bh.FaceColor = 'flat';
    bh.EdgeColor = 'none';
    bh.CData = [0 0.5 0.5;    % Color (teal)
                0.6 0.6 0.6]; % Grayscale (gray)
else
    bh(1).FaceColor = [0 0.5 0.5];   bh(1).EdgeColor = 'none';
    bh(2).FaceColor = [0.6 0.6 0.6]; bh(2).EdgeColor = 'none';
end

errorbar(1:2, mA, seA, 'k','linestyle','none','linewidth',1.5,'CapSize',8);
set(gca,'XTick',1:2,'XTickLabel',{'Color','Grayscale'});
ylabel('\DeltaRT = RT_{Other} - RT_{Original} (s)');
title('Mismatch effect (overall)'); box off;

yl = ylim;
txt = sprintf('Welch t: t(%.1f)=%.2f, p=%.3g, d=%.2f', ...
    stWelch_over.df, stWelch_over.tstat, pWelch_over, d_overall);
text(0.55, yl(2)-0.08*range(yl), txt, 'FontSize',10);

% ---------- Panel B: Per-category ΔRT (Color vs Grayscale) ----------
subplot(1,2,2);
mB  = nan(K,2);  % [Color, Gray]
seB = nan(K,2);

for k = 1:K
    label = catsL{k};
    Dc = DeltaC.DeltaRT(DeltaC.Category == label); Dc = Dc(~isnan(Dc));
    Dg = DeltaG.DeltaRT(DeltaG.Category == label); Dg = Dg(~isnan(Dg));
    mB(k,1)  = mean(Dc,'omitnan');
    seB(k,1) = std(Dc,'omitnan') / max(1, sqrt(numel(Dc)));
    mB(k,2)  = mean(Dg,'omitnan');
    seB(k,2) = std(Dg,'omitnan') / max(1, sqrt(numel(Dg)));
end

hb2 = bar(mB); hold on;
hb2(1).FaceColor = [0 0.5 0.5];   hb2(1).EdgeColor = 'none';
hb2(2).FaceColor = [0.6 0.6 0.6]; hb2(2).EdgeColor = 'none';

ng = size(mB,1);
nb = 2;
xends = nan(nb, ng);
for b = 1:nb
    xends(b,:) = hb2(b).XEndPoints;
end

errorbar(xends', mB, seB, 'k','linestyle','none','linewidth',1.0,'CapSize',6);
set(gca,'XTick',1:K,'XTickLabel',catsL,'XTickLabelRotation',30);
ylabel('\DeltaRT (s)');
title('Mismatch effect by category');
legend({'Color','Grayscale'},'Location','northwest');
box off;

% ---------- Forest plot: ΔΔRT (Gray − Color) ----------
figure('Color','w','Position',[120,120,760,560]); hold on;

[~, order] = sort(est_dd, 'descend');
E    = est_dd(order);
L    = ci_low(order);
H    = ci_high(order);
labs = catsL(order);

for i = 1:K
    y = i;
    plot([L(i), H(i)], [y, y], '-', 'LineWidth', 2);
    plot(E(i), y, 'o', 'MarkerSize', 6, ...
        'MarkerFaceColor', [0.25 0.25 0.25], ...
        'MarkerEdgeColor', 'none');
end

plot([0 0], [0.5 K+0.5], '--', 'Color', [0.7 0.7 0.7]);
set(gca,'YTick',1:K,'YTickLabel',labs,'YDir','reverse','FontName','Arial');
xlabel('\Delta\DeltaRT (s) = mean(\DeltaRT_{Gray}) − mean(\DeltaRT_{Color})');
ylabel('Category');
title('Per-category difference in material effect (Gray vs Color)');
box off;

disp('All analyses complete.');

%% ========================= Helper functions ============================

function T = prep_table_userstyle(Tin, whichExp)
% Prepares table:
%   - Extract Participant from ParticipantInfo
%   - Filter to Go trials (Category == Subfolder) and RT in [0.1, 1.0] s
%   - Derive Material from filename ('original' vs 'Other')
%   - Add Experiment label ('Color'/'Grayscale')

    T = Tin;

    if ~ismember('Participant', T.Properties.VariableNames)
        T.Participant = categorical(string(T.ParticipantInfo));
    end

    n = height(T);
    participantID = strings(n,1);
    for i = 1:n
        info = strsplit(string(T.ParticipantInfo(i)));
        participantID(i) = info(1);
    end
    T.Participant = categorical(participantID);

    % Go trials + RT window (0.1–1.0 s)
    is_go = strcmp(string(T.Category), string(T.Subfolder));
    rt_ok = ~isnan(T.ReactionTime) & T.ReactionTime >= 0.1 & T.ReactionTime <= 1.0;
    T = T(is_go & rt_ok, :);

    % Material from filename
    nameLower = lower(string(T.ImageShown));
    material  = repmat("Other", height(T), 1);
    material(contains(nameLower, 'original')) = "Original";
    T.Material = categorical(material);

    % Category / Participant cleanup
    T.Participant = removecats(categorical(T.Participant));
    T.Category    = removecats(categorical(T.Category));
    T.Material    = removecats(T.Material);

    % Experiment tag
    T.Experiment = categorical(repmat(string(whichExp), height(T), 1));
end

function Agg = aggregate_means(T)
% Mean RT per Participant × Category × Material
    [G,p,c,m] = findgroups(T.Participant, T.Category, T.Material);
    RTm = splitapply(@mean, T.ReactionTime, G);
    Agg = table(categorical(p), categorical(c), categorical(m), RTm, ...
        'VariableNames', {'Participant','Category','Material','RT'});
end

function [rm, ran, eff] = run_rm_anova(Agg, cats_c)
% Build wide table and run RM-ANOVA for Category × Material
    mats = categorical({'Original','Other'});
    [wide, condNames] = to_wide(Agg, cats_c, mats);
    wide_clean = rmmissing(wide, 'DataVariables', condNames);

    [catPart, matPart] = ndgrid(cats_c, mats);
    WithinDesign = table(categorical(catPart(:)), categorical(matPart(:)), ...
        'VariableNames', {'Category','Material'});

    respCols = wide_clean.Properties.VariableNames(2:end);
    rm = fitrm(wide_clean, sprintf('%s-%s ~ 1', respCols{1}, respCols{end}), ...
        'WithinDesign', WithinDesign);
    ran = ranova(rm, 'WithinModel', 'Category*Material');

    eff = struct();
    eff.Material = partial_eta(ran, 'Material');
    eff.Category = partial_eta(ran, 'Category');
    eff.Int      = partial_eta(ran, 'Category:Material');
end

function [wide, condNames] = to_wide(Agg, cats_c, mats)
% Wide table: rows=participants, columns=Category×Material means
    P = categories(Agg.Participant);
    wide = table(); 
    wide.Participant = categorical(P);

    condNames = strings(0,1);
    for ci = 1:numel(cats_c)
        for mi = 1:numel(mats)
            vname = matlab.lang.makeValidName(sprintf('%s_%s', ...
                string(cats_c(ci)), string(mats(mi))));
            condNames(end+1,1) = vname;

            col = nan(numel(P),1);
            for pi = 1:numel(P)
                idx = (Agg.Participant == P{pi}) & ...
                      (Agg.Category    == cats_c(ci)) & ...
                      (Agg.Material    == mats(mi));
                vals = Agg.RT(idx);
                if ~isempty(vals)
                    col(pi) = mean(vals,'omitnan');
                end
            end
            wide.(vname) = col;
        end
    end
end

function eta = partial_eta(ranovaTbl, effectKey)
% Partial eta^2 from ranova table
    rn = row_labels(ranovaTbl);
    if isempty(rn), eta = NaN; return; end

    effRow = contains(rn, effectKey) & ~contains(rn, "Error");
    if ~any(effRow), eta = NaN; return; end

    SumSq = get_col(ranovaTbl,'SumSq');
    if isempty(SumSq), eta = NaN; return; end

    SS_eff = SumSq(effRow);
    SS_eff = SS_eff(~isnan(SS_eff));
    SS_eff = sum(double(SS_eff));

    errKey = "Error(" + effectKey + ")";
    errRow = contains(rn, errKey);
    if ~any(errRow)
        DF = get_col(ranovaTbl,'DF');
        if ~isempty(DF)
            errRow = contains(rn,'Error') & ...
                     (double(DF) == double(DF(effRow)));
        end
    end

    if any(errRow)
        SS_err = SumSq(errRow);
        SS_err = SS_err(~isnan(SS_err));
        SS_err = sum(double(SS_err));
        eta = SS_eff / (SS_eff + SS_err);
    else
        eta = NaN;
    end
end

function disp_effectsizes(tag, eff)
    fprintf('%s partial eta-squared:\n', tag);
    fprintf('  Material: %s\n', fmt_eta(eff.Material));
    fprintf('  Category: %s\n', fmt_eta(eff.Category));
    fprintf('  Category×Material: %s\n', fmt_eta(eff.Int));
end

function s = fmt_eta(x)
    if ~isempty(x) && ~isnan(x)
        s = sprintf('%.3f', x);
    else
        s = '(NA)';
    end
end

function D = pivot_delta(Agg)
% Per-subject ΔRT = Other - Original per category
    subs = categories(Agg.Participant);
    cats = categories(Agg.Category);

    P = {};
    C = {};
    Delta = [];

    for si = 1:numel(subs)
        sLab = subs{si};
        for ci = 1:numel(cats)
            cLab = cats{ci};

            idxO = (Agg.Participant == sLab) & ...
                   (Agg.Category    == cLab) & ...
                   (Agg.Material    == 'Original');
            idxX = (Agg.Participant == sLab) & ...
                   (Agg.Category    == cLab) & ...
                   (Agg.Material    == 'Other');

            if any(idxO) || any(idxX)
                rtO = mean(Agg.RT(idxO), 'omitnan');
                rtX = mean(Agg.RT(idxX), 'omitnan');

                P{end+1,1}   = sLab; %#ok<AGROW>
                C{end+1,1}   = cLab; %#ok<AGROW>
                Delta(end+1,1) = rtX - rtO; %#ok<AGROW>
            end
        end
    end

    D = table(categorical(P), categorical(C), Delta, ...
        'VariableNames', {'Participant','Category','DeltaRT'});
end

function d = cohen_d_ind(x, y)
% Independent-samples Cohen's d (pooled SD)
    x = x(~isnan(x));
    y = y(~isnan(y));
    nx = numel(x);
    ny = numel(y);
    sx = var(x,1);
    sy = var(y,1);
    sp = sqrt(((nx-1)*sx + (ny-1)*sy) / (nx+ny-2));
    d  = (mean(x) - mean(y)) / sp;
end

function [q, crit_p] = fdr_bh(pvals, q_level)
% Benjamini-Hochberg FDR (vector pvals). NaNs preserved.
    if nargin < 2 || isempty(q_level), q_level = 0.05; end
    p = pvals(:);
    m = sum(~isnan(p));
    [sp, sort_idx] = sort(p);
    ranks = (1:numel(sp))';
    adj   = nan(size(sp));
    last  = Inf;

    for i = numel(sp):-1:1
        if isnan(sp(i)), adj(i) = NaN; continue; end
        last   = min(last, sp(i) * m / ranks(i));
        adj(i) = last;
    end

    q = nan(size(p));
    q(sort_idx) = adj;

    crit_p = NaN;
    if m > 0
        thresh = (ranks / m) * q_level;
        idx = find(~isnan(sp) & sp <= thresh, 1, 'last');
        if ~isempty(idx), crit_p = sp(idx); end
    end

    q = reshape(q, size(pvals));
end

function tf = isempty_row(tbl)
    if isa(tbl,'dataset')
        tf = (size(tbl,1) == 0);
    else
        tf = isempty(tbl) || height(tbl) == 0;
    end
end

function rn = row_labels(tbl)
% Row labels from table or dataset
    if isa(tbl,'dataset')
        try
            obs = get(tbl,'ObsNames');
            rn  = string(obs);
        catch
            rn = strings(0,1);
        end
    else
        rn = string(tbl.Properties.RowNames);
    end
end

function col = get_col(tbl, name)
% Safely get a column by name; [] if missing
    col = [];
    if isa(tbl,'dataset')
        vn = get(tbl,'VarNames');
        if any(strcmp(vn, name)), col = tbl.(name); end
    else
        if any(strcmp(tbl.Properties.VariableNames, name))
            col = tbl.(name);
        end
    end
end

function mask = effect_row_mask(tbl, effectStr)
% Logical mask for rows whose labels mention effectStr
    rn = row_labels(tbl);
    mask = ~isempty(rn) & contains(rn, effectStr);
    if ~any(mask)
        terms = get_col(tbl, 'Term');
        if ~isempty(terms)
            try
                mask = contains(string(terms), effectStr);
            catch
                mask = contains(cellstr(terms), effectStr);
            end
        end
    end
end

function sub = subset_rows(tbl, mask)
% Return subset rows for table or dataset
    sub = tbl(mask, :);
end

function [Fval, DFval, pval] = read_F_dp(tblRow)
% Read F, DF, p from a 1-row table/dataset
    Fval = NaN; DFval = NaN; pval = NaN;

    pv = get_col(tblRow,'pValue');
    if isempty(pv), pv = get_col(tblRow,'pvalue'); end
    if ~isempty(pv), pval = double(pv(1)); end

    Fcol = get_col(tblRow,'F');
    if isempty(Fcol), Fcol = get_col(tblRow,'FStat'); end
    if ~isempty(Fcol), Fval = double(Fcol(1)); end

    DFcol = get_col(tblRow,'DF');
    if ~isempty(DFcol), DFval = double(DFcol(1)); end

    if isnan(DFval)
        DF1 = get_col(tblRow,'DF1');
        DF2 = get_col(tblRow,'DF2');
        if ~isempty(DF1) && ~isempty(DF2)
            DFval = double(DF1(1) + DF2(1));
        end
    end
end

function show_row(label, rowTbl)
% Pretty-print a single ANOVA/LME effect row
    fprintf('\n-- %s --\n', label);

    if isa(rowTbl,'dataset')
        if size(rowTbl,1) == 0
            fprintf('  (row not found in your output)\n');
            return;
        end
        varNames = get(rowTbl,'VarNames');
        have = @(n) any(strcmp(varNames,n));
        if have('SumSq') && have('DF') && have('MeanSq') && have('F') && have('pValue')
            disp(rowTbl(:, {'SumSq','DF','MeanSq','F','pValue'}));
        else
            disp(rowTbl);
        end
    else
        if isempty(rowTbl) || height(rowTbl) == 0
            fprintf('  (row not found in your output)\n');
            return;
        end
        want = intersect({'SumSq','DF','MeanSq','F','pValue'}, ...
                         rowTbl.Properties.VariableNames, 'stable');
        if ~isempty(want)
            disp(rowTbl(:, want));
        else
            disp(rowTbl);
        end
    end
end
