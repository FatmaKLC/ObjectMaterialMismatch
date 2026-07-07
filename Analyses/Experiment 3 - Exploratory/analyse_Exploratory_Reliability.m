clear; clc;

%% LOAD DATA
load('combinedData_diagnosticity.mat');
T_diag = combinedDiagnosticity;

load('combinedData_familiarity.mat');
T_fam = combinedFamiliarity;

%% ----------------------------
% For Diagnosticity Reliability
%% ----------------------------

% Clean participant IDs
T_diag.participantID = string(T_diag.participantID);
T_diag.imageName = string(T_diag.imageName);

% Average repeated trials within participant × image
T_comp = groupsummary(T_diag, {'participantID','imageName'}, 'mean', 'slider1_composition');
T_var  = groupsummary(T_diag, {'participantID','imageName'}, 'mean', 'slider2_variability');

% Rename mean columns to a common name so the function is simpler
T_comp.Properties.VariableNames{'mean_slider1_composition'} = 'rating';
T_var.Properties.VariableNames{'mean_slider2_variability'}  = 'rating';

%% ----------------------------
% For Familiarity Reliability
%% ----------------------------

T_fam.ParticipantID = string(T_fam.ParticipantID);
T_fam.Filename = string(T_fam.Filename);

% Convert rank so higher = more familiar
T_fam.FamiliarityScore = 11 - T_fam.ClickRank;

% Average per participant × image
T_fam_mean = groupsummary(T_fam, {'ParticipantID','Filename'}, 'mean', 'FamiliarityScore');

% Rename columns to match function
T_fam_mean.Properties.VariableNames{'ParticipantID'} = 'participantID';
T_fam_mean.Properties.VariableNames{'Filename'} = 'imageName';
T_fam_mean.Properties.VariableNames{'mean_FamiliarityScore'} = 'rating';

%% ----------------------------
% Compute reliability
%% ----------------------------

[r_comp, r_comp_sb, ci_comp_sb] = compute_split_half(T_comp);
[r_var,  r_var_sb,  ci_var_sb]  = compute_split_half(T_var);
[r_fam,  r_fam_sb,  ci_fam_sb]  = compute_split_half(T_fam_mean);

fprintf('Composition raw split-half r: %.3f, SB corrected: %.3f, 95%% CI [%.3f, %.3f]\n', ...
    r_comp, r_comp_sb, ci_comp_sb(1), ci_comp_sb(2));

fprintf('Variability raw split-half r: %.3f, SB corrected: %.3f, 95%% CI [%.3f, %.3f]\n', ...
    r_var, r_var_sb, ci_var_sb(1), ci_var_sb(2));

fprintf('Familiarity raw split-half r: %.3f, SB corrected: %.3f, 95%% CI [%.3f, %.3f]\n', ...
    r_fam, r_fam_sb, ci_fam_sb(1), ci_fam_sb(2));

%% ----------------------------
% Function
%% ----------------------------
function [mean_r, mean_r_sb, ci_r_sb] = compute_split_half(T)

participants = unique(T.participantID);
n = numel(participants);

nIter = 1000;
r_all = nan(nIter,1);
r_sb_all = nan(nIter,1);

for i = 1:nIter
    perm = participants(randperm(n));

    g1 = perm(1:floor(n/2));
    g2 = perm(floor(n/2)+1:end);

    T1 = T(ismember(T.participantID, g1), :);
    T2 = T(ismember(T.participantID, g2), :);

    % Mean across participants within each half, for each image
    M1 = groupsummary(T1, 'imageName', 'mean', 'rating');
    M2 = groupsummary(T2, 'imageName', 'mean', 'rating');

    [~, ia, ib] = intersect(M1.imageName, M2.imageName);

    v1 = M1.mean_rating(ia);
    v2 = M2.mean_rating(ib);

    if numel(v1) > 1 && numel(v2) > 1
        r = corr(v1, v2, 'Rows', 'complete');
        r_all(i) = r;

        % Spearman-Brown correction
        r_sb_all(i) = (2*r) / (1+r);
    end
end

mean_r = mean(r_all, 'omitnan');
mean_r_sb = mean(r_sb_all, 'omitnan');

ci_r_sb = prctile(r_sb_all, [2.5 97.5]);

end