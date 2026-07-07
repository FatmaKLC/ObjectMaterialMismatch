%% =========================================================
% COMBINED COLOR + GRAYSCALE ANALYSIS
% Test whether the material-manipulation effect differs
% between experiments using ONE unified mixed model
%
% Assumptions:
% - .mat files contain a table variable
% - valid RT trials are Go trials with a button press
% - original images contain "original" in ImageShown
%   (adjust this rule if your filenames differ)
%
% Compatible with MATLAB R2017b
%% =========================================================

clear; clc;

%% -------------------------
% LOAD TABLES ROBUSTLY
%% -------------------------
T_color = loadTableFromMat('combinedData_ExpV2.mat');
T_gray  = loadTableFromMat('combinedData_grayscale.mat');

%% -------------------------
% ADD EXPERIMENT LABEL
%% -------------------------
T_color.Experiment = repmat({'Color'},     height(T_color), 1);
T_gray.Experiment  = repmat({'Grayscale'}, height(T_gray), 1);

%% =========================================================
% EXTRACT OBJECT KEY + IMAGE KEY FROM BEHAVIORAL TABLES
%% =========================================================

% ---- Color table ----
T_color.ObjectKey = cell(height(T_color),1);

for i = 1:height(T_color)
    fname = T_color.ImageShown{i};
    fname = lower(strtrim(fname));

    [~, base, ~] = fileparts(fname);

    parts = strsplit(base, '_');
    T_color.ObjectKey{i} = parts{1};
end

% ---- Grayscale table ----
T_gray.ObjectKey = cell(height(T_gray),1);

for i = 1:height(T_gray)
    fname = T_gray.ImageShown{i};
    fname = lower(strtrim(fname));

    [~, base, ~] = fileparts(fname);

    parts = strsplit(base, '_');
    T_gray.ObjectKey{i} = parts{1};
end


%% =========================================================
% MANUAL NAME FIXES
%% =========================================================

% ---- Color table fixes ----
for i = 1:height(T_color)

    if strcmp(T_color.ObjectKey{i}, 'coffeemachinered')
        T_color.ObjectKey{i} = 'capsulecoffeemachine';
    end

    if strcmp(T_color.ObjectKey{i}, 'wolkswagenkombi')
        T_color.ObjectKey{i} = 'volkswagenkombi';
    end
end

% ---- Grayscale table fixes ----
for i = 1:height(T_gray)

    if strcmp(T_gray.ObjectKey{i}, 'coffeemachinered')
        T_gray.ObjectKey{i} = 'capsulecoffeemachine';
    end

    if strcmp(T_gray.ObjectKey{i}, 'wolkswagenkombi')
        T_gray.ObjectKey{i} = 'volkswagenkombi';
    end
end

%% -------------------------
% COMBINE
%% -------------------------
T_all = [T_color; T_gray];

%% -------------------------
% BASIC SANITY CHECK
%% -------------------------
requiredVars = {'Category','Subfolder','ImageShown','ReactionTime'};
for i = 1:numel(requiredVars)
    if ~ismember(requiredVars{i}, T_all.Properties.VariableNames)
        error('Missing required variable: %s', requiredVars{i});
    end
end

%% -------------------------
% BUILD CLEAN PARTICIPANT ID
% Works for IDs like:
%   "001"
%   "007"
%   "Participant001"
%   "Participant007"
%
% Then prefixes by experiment so the same number across experiments
% is never treated as the same person.
%% -------------------------
rawID = strings(height(T_all),1);

% ---- OPTION A: participant info stored in ParticipantInfo
if ismember('ParticipantInfo', T_all.Properties.VariableNames)

    for i = 1:height(T_all)
        val = T_all.ParticipantInfo{i};

        % if ParticipantInfo has multiple pieces, take first one
        if isstring(val) || ischar(val)
            parts = strsplit(char(val));
            rawID(i) = string(parts{1});
        else
            rawID(i) = string(val);
        end
    end

% ---- OPTION B: participant ID is in column named "1"
elseif ismember('1', T_all.Properties.VariableNames)

    for i = 1:height(T_all)
        rawID(i) = string(T_all.('1'){i});
    end

% ---- OPTION C: imported as Var8 or similar
elseif ismember('Var8', T_all.Properties.VariableNames)

    for i = 1:height(T_all)
        rawID(i) = string(T_all.Var8{i});
    end

else
    error('Could not find participant ID column.');
end

% normalize IDs: strip "Participant" and keep numeric part only
cleanNumID = strings(height(T_all),1);

for i = 1:height(T_all)
    thisID = char(rawID(i));

    % extract digits only
    digitsOnly = regexp(thisID, '\d+', 'match');

    if isempty(digitsOnly)
        error('Could not extract numeric participant ID from: %s', thisID);
    end

    % use the first digit group, zero-pad to 3 digits
    cleanNumID(i) = string(sprintf('%03d', str2double(digitsOnly{1})));
end

% prefix by experiment
finalID = strings(height(T_all),1);
for i = 1:height(T_all)
    if strcmp(T_all.Experiment{i}, 'Color')
        finalID(i) = "Color_" + cleanNumID(i);
    elseif strcmp(T_all.Experiment{i}, 'Grayscale')
        finalID(i) = "Gray_" + cleanNumID(i);
    else
        error('Unknown experiment label in row %d.', i);
    end
end

T_all.Participant = categorical(finalID);

disp('Unique participant IDs after cleaning:');
disp(categories(T_all.Participant));

disp('N unique color participants:');
disp(numel(unique(T_all.Participant(strcmp(T_all.Experiment,'Color')))));

disp('N unique grayscale participants:');
disp(numel(unique(T_all.Participant(strcmp(T_all.Experiment,'Grayscale')))));

%% -------------------------
% DEFINE VALID GO TRIALS
% This follows YOUR exact logic
%% -------------------------
is_go_trial = strcmp(T_all.Category, T_all.Subfolder);
pressed_condition = ~isnan(T_all.ReactionTime) & T_all.ReactionTime >= 0.1;
valid_go_trials = is_go_trial & pressed_condition;

rt_data = T_all(valid_go_trials, :);

%% -------------------------
% LOG RT
%% -------------------------
rt_data.logRT = log(rt_data.ReactionTime);

%% -------------------------
% CLEAN VARIABLES FOR fitlme
%% -------------------------
rt_data.logRT        = double(rt_data.logRT);
rt_data.Experiment   = categorical(string(rt_data.Experiment));
rt_data.Category     = categorical(string(rt_data.Category));
rt_data.Subfolder    = categorical(string(rt_data.Subfolder));
rt_data.Participant  = categorical(string(rt_data.Participant));
rt_data.ImageShown   = string(rt_data.ImageShown);
rt_data.ObjectKey = categorical(string(rt_data.ObjectKey));

% remove unused categories
rt_data.Experiment   = removecats(rt_data.Experiment);
rt_data.Category     = removecats(rt_data.Category);
rt_data.Subfolder    = removecats(rt_data.Subfolder);
rt_data.Participant  = removecats(rt_data.Participant);
rt_data.ObjectKey = removecats(rt_data.ObjectKey);

%% -------------------------
% DEFINE IMAGE TYPE / MATERIAL CONDITION
%
% Rule used here:
% Original images contain "original" in filename
% Everything else = manipulated
%
% IMPORTANT:
% If your filenames use a different convention, edit this part.
%% -------------------------
img = lower(string(rt_data.ImageShown));
is_original = contains(img, 'original');

rt_data.ImageType = strings(height(rt_data),1);
rt_data.ImageType(is_original)  = "Original";
rt_data.ImageType(~is_original) = "Manipulated";
rt_data.ImageType = categorical(rt_data.ImageType);
rt_data.ImageType = removecats(rt_data.ImageType);

%% -------------------------
% OPTIONAL: QUICK CHECK OF COUNTS
%% -------------------------
disp('Counts by Experiment x ImageType:');
disp(crosstab(rt_data.Experiment, rt_data.ImageType));

disp('Mean RT by Experiment x ImageType:');
summaryTbl = grpstats(rt_data, {'Experiment','ImageType'}, {'mean'}, 'DataVars', 'ReactionTime');
disp(summaryTbl(:, {'Experiment','ImageType','mean_ReactionTime'}));

disp('Classes of model variables:');
disp(class(rt_data.logRT));
disp(class(rt_data.ImageType));
disp(class(rt_data.Experiment));
disp(class(rt_data.Category));
disp(class(rt_data.Participant));
%% -------------------------
% UNIFIED MIXED MODEL
%
% Critical term:
%   ImageType * Experiment
%
% Interpretation:
% - main effect of ImageType:
%   overall original vs manipulated difference
% - main effect of Experiment:
%   overall color vs grayscale difference
% - interaction:
%   does the material-manipulation effect differ between experiments?
%
% Category is added as a fixed effect to absorb category differences.
%% -------------------------
rt_plot = rt_data;
rt_data = rt_data(:, {'logRT','ImageType','Experiment','Category','Participant', 'ObjectKey'});

lme = fitlme(rt_data, ...
    'logRT ~ ImageType * Experiment * Category + (1|Participant) + (1|ObjectKey)');

%% -------------------------
% RESULTS
%% -------------------------
disp(' ');
disp('================ COEFFICIENTS ================');
disp(lme);

disp(' ');
disp('================ ANOVA TABLE =================');
anovaTbl = anova(lme);
disp(anovaTbl);

%% -------------------------
% EXTRACT THE KEY INTERACTION ROW
%% -------------------------
termNames = anovaTbl.Term;
interactionRow = strcmp(termNames, 'ImageType:Experiment');

if any(interactionRow)
    p_interaction = anovaTbl.pValue(interactionRow);
    F_interaction = anovaTbl.FStat(interactionRow);

    fprintf('\nCritical interaction: ImageType x Experiment\n');
    fprintf('F = %.4f, p = %.6f\n', F_interaction, p_interaction);

    if p_interaction < 0.05
        fprintf(['Interpretation: The material-manipulation effect differs ' ...
                 'between Color and Grayscale.\n']);
    else
        fprintf(['Interpretation: The material-manipulation effect does NOT ' ...
                 'significantly differ between Color and Grayscale.\n']);
    end
else
    warning('Could not find ImageType:Experiment term in ANOVA table.');
end

%% -------------------------
% EXTRACT THE KEY INTERACTION ROW
%% -------------------------
termNames = anovaTbl.Term;
interactionRow = strcmp(termNames, 'Experiment:Category');

if any(interactionRow)
    p_interaction = anovaTbl.pValue(interactionRow);
    F_interaction = anovaTbl.FStat(interactionRow);

    fprintf('\nCritical interaction: Category x Experiment\n');
    fprintf('F = %.4f, p = %.6f\n', F_interaction, p_interaction);

    if p_interaction < 0.05
        fprintf(['Interpretation: The material-manipulation effect differs across categories ' ...
                 'between Color and Grayscale.\n']);
    else
        fprintf(['Interpretation: The material-manipulation effect does NOT ' ...
                 'significantly differ across categories between Color and Grayscale.\n']);
    end
else
    warning('Could not find Category:Experiment term in ANOVA table.');
end

%% -------------------------
% EXTRACT THE KEY INTERACTION ROW
%% -------------------------
threeWayRow = strcmp(termNames, 'ImageType:Experiment:Category');

if any(threeWayRow)
    p_threeway = anovaTbl.pValue(threeWayRow);
    F_threeway = anovaTbl.FStat(threeWayRow);

    fprintf('\nCategory-dependent interaction: ImageType x Experiment x Category\n');
    fprintf('F = %.4f, p = %.6f\n', F_threeway, p_threeway);

    if p_threeway < 0.05
        fprintf(['Interpretation: The color-vs-grayscale difference in the material effect depends on category.\n']);
    else
        fprintf(['Interpretation: The color-vs-grayscale difference in the material effect does NOT significantly depend on category.\n']);
    end
end

%% -------------------------
% OPTIONAL PLOT
%% -------------------------
plotTbl = grpstats(rt_plot, {'Experiment','ImageType'}, {'mean','sem'}, ...
                   'DataVars', 'ReactionTime');

figure('Color','w','Position',[100 100 700 500]); hold on;

x = [1 2]; % Original, Manipulated
expCats = categories(plotTbl.Experiment);

for e = 1:numel(expCats)
    idx = plotTbl.Experiment == expCats{e};

    thisTypes = cellstr(plotTbl.ImageType(idx));
    [~, order] = ismember(thisTypes, {'Original','Manipulated'});

    y = plotTbl.mean_ReactionTime(idx);
    err = plotTbl.sem_ReactionTime(idx);

    y = y(order);
    err = err(order);

    errorbar(x, y, err, '-o', 'LineWidth', 1.8, 'MarkerSize', 7);
end

xlim([0.7 2.3]);
xticks([1 2]);
xticklabels({'Original','Manipulated'});
ylabel('Reaction Time');
legend(expCats, 'Location', 'best');
title('RT by Experiment and Image Type');
box off;

%% =========================================================
% LOCAL FUNCTION
%% =========================================================
function T = loadTableFromMat(filename)

S = load(filename);
vars = fieldnames(S);

tableFound = false;
for i = 1:numel(vars)
    if istable(S.(vars{i}))
        T = S.(vars{i});
        tableFound = true;
        fprintf('Loaded table "%s" from %s\n', vars{i}, filename);
        break;
    end
end

if ~tableFound
    error('No table variable found inside %s', filename);
end

end