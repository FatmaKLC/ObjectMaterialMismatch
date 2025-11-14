%% Familiarity & Diagnosticity Experiment
% Author: Fatma Kilic
%
% Description:
%   This script runs two tasks:
%     1) Diagnosticity (line drawings + sliders)
%     2) Familiarity (ranking original images)
%
% Output:
%   - data/diagnosticity_slider_<ParticipantID>.mat
%   - data/familiarity_ranking_<ParticipantID>.mat
%
% Requirements:
%   - MATLAB (tested with R2017b or later)
%   - Psychtoolbox
%   - Folders:
%       ImFolderLineDrawing/   (8 categories, 10 .jpg line drawings each)
%       ImFolder/              (original images, *_original_*.png)

%% Housekeeping
sca;
close all;
clearvars;

KbName('UnifyKeyNames');

%% ########################################################################
%                         Participant Info                                
% #########################################################################

prompt   = {'Enter Participant ID:', 'Gender:', 'Age:'};
dlgtitle = 'Participant Info Input';
dims     = [1 50];
definput = {'Participant01', 'Enter the Gender', 'Enter the Age'};

participantInfo = inputdlg(prompt, dlgtitle, dims, definput);

if isempty(participantInfo)
    error('Participant info input cancelled.');
end

participantID = strtrim(participantInfo{1});
gender        = strtrim(participantInfo{2});
age           = str2double(participantInfo{3});

participantInfo = reshape(participantInfo, 1, []);  % 1x3 cell

%% ########################################################################
%                     Data Folder / Duplicate Check                       
% #########################################################################

dataDir = fullfile(pwd, 'data');
if ~exist(dataDir, 'dir')
    mkdir(dataDir);
end

filePatternData   = fullfile(dataDir, ['*' participantID '*.mat']);
existingFilesData = dir(filePatternData);

if ~isempty(existingFilesData)
    choice = questdlg( ...
        sprintf('A data file for participant "%s" already exists in /data. Overwrite?', participantID), ...
        'Duplicate Participant ID Detected', ...
        'Yes', 'No', 'No');
    if strcmp(choice, 'No')
        error('Save cancelled to avoid overwriting data for this participant ID.');
    end
end

%% ########################################################################
%                         Initialize Psychtoolbox                         
% #########################################################################

experimentStartTime = datetime('now'); 

screenNumber = max(Screen('Screens'));

% Set to 0 for real experiments after timing tests
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'TextRenderer', 1);

backgroundColor = [128 128 128];

[window, windowRect] = PsychImaging('OpenWindow', screenNumber, backgroundColor);
HideCursor();

[screenResolutionWidth, screenResolutionHeight] = Screen('WindowSize', screenNumber);

% Physical screen width in cm (adjust to your setup)
screenWidthCm = 59.6736;
pixelsPerCm   = screenResolutionWidth / screenWidthCm;

% Visual angle & stimulus size (smaller than Go/No-Go)
visualAngleTarget = 10;   % degrees
viewingDistance   = 50;   % cm

stimulusSizeCmTarget     = 2 * viewingDistance * tan((visualAngleTarget / 2) * pi / 180);
stimulusSizePixelsTarget = round(stimulusSizeCmTarget * pixelsPerCm);

[screenXpixels, screenYpixels] = Screen('WindowSize', screenNumber);
xCenter = screenXpixels / 2;
yCenter = screenYpixels / 2;

dstRectTarget = [0 0 stimulusSizePixelsTarget stimulusSizePixelsTarget];
dstRectTarget = CenterRectOnPointd(dstRectTarget, xCenter, yCenter);

%% ########################################################################
%                     Initial Instructions Screen                        
% #########################################################################

Screen('TextSize', window, 40);
Screen('TextColor', window, [0 0 0]);
Screen('TextFont', window, 'Arial');
Screen('FillRect', window, backgroundColor);

introText = [ ...
    'In this experiment, you will complete two short tasks, both involving images of everyday objects.\n\n' ...
    'Each task focuses on a different type of judgment.\n\n' ...
    'In the first part, you will be presented line drawings and asked to rate them based on material composition and variability.\n\n' ...
    'In the second part, you will see sets of original images and rank-order them based on familiarity.\n\n' ...
    'Press SPACE when you are ready to start the experiment.' ];

DrawFormattedText(window, introText, 'center', 'center');
Screen('Flip', window);

spacePressed = false;
while ~spacePressed
    [keyIsDown, ~, keyCode] = KbCheck;
    if keyIsDown && keyCode(KbName('space'))
        spacePressed = true;
    end
end

%% ########################################################################
%                         Fixation Cross Setup                           
% #########################################################################

fixCrossDimPix = 15;
lineWidthPix   = 4;
fixationColor  = [0 0 0];

xCoords   = [-fixCrossDimPix fixCrossDimPix 0 0];
yCoords   = [0 0 -fixCrossDimPix fixCrossDimPix];
allCoords = [xCoords; yCoords];

%% ###############################################################
%         Instructions for Diagnosticity Block                   
% ###############################################################

Screen('FillRect', window, backgroundColor);
Screen('TextSize', window, 40);
Screen('TextColor', window, [0 0 0]);
Screen('TextFont', window, 'Arial');

diagText = [ ...
    'In the first part, you will see line drawings of objects with their names.\n\n' ...
    'For each object, you will answer TWO questions in a row:\n\n' ...
    '1) How many distinct materials is this typically composed of?\n' ...
    '2) How variable are the materials this could be made of?\n\n' ...
    'Use the mouse to move the slider and click the LEFT BUTTON to confirm your rating.\n\n' ...
    'Press SPACE when you are ready to start.' ];

DrawFormattedText(window, diagText, 'center', 'center');
Screen('Flip', window);

spacePressed = false;
while ~spacePressed
    [keyIsDown, ~, keyCode] = KbCheck;
    if keyIsDown && keyCode(KbName('space'))
        spacePressed = true;
    end
end

%% ######################## DIAGNOSTICITY BLOCK ###########################

% Folder structure: ImFolderLineDrawing/CategoryName/*.jpg
ldMainFolder = fullfile(pwd, 'ImFolderLineDrawing');
if ~exist(ldMainFolder, 'dir')
    sca;
    error('ImFolderLineDrawing not found in %s.', pwd);
end

ldCategories = dir(ldMainFolder);
ldCategories = ldCategories([ldCategories.isdir] & ~ismember({ldCategories.name}, {'.', '..'}));

assert(numel(ldCategories) == 8, 'Expected 8 category folders in ImFolderLineDrawing');

% Gather all 80 image paths and metadata
imagePaths    = {};
imageNames    = {};
categoryNames = {};

for i = 1:numel(ldCategories)
    category = ldCategories(i).name;
    catPath  = fullfile(ldMainFolder, category);
    imgs     = dir(fullfile(catPath, '*.jpg'));
    assert(numel(imgs) == 10, 'Expected 10 images in category: %s', category);
    
    for j = 1:10
        imagePaths{end+1,1}    = fullfile(catPath, imgs(j).name);
        imageNames{end+1,1}    = imgs(j).name;
        categoryNames{end+1,1} = category;
    end
end

% Resize all line-drawing images
sampleImg = imread(imagePaths{1});
[originalHeight, originalWidth, ~] = size(sampleImg);
aspectRatio = originalWidth / originalHeight;

if aspectRatio > 1
    resizedWidth  = stimulusSizePixelsTarget;
    resizedHeight = round(stimulusSizePixelsTarget / aspectRatio);
else
    resizedHeight = stimulusSizePixelsTarget;
    resizedWidth  = round(stimulusSizePixelsTarget * aspectRatio);
end

resizedLineDrawingImages = cell(numel(imagePaths), 1);
for i = 1:numel(imagePaths)
    img = imread(imagePaths{i});
    resizedLineDrawingImages{i} = imresize(img, [resizedHeight, resizedWidth]);
end

% Repeat each image numReps times and shuffle
numReps    = 3;
allIndices = repmat(1:80, 1, numReps);
allIndices = allIndices(randperm(length(allIndices)));

diagnosticityResponses = struct([]);

sliderBarWidth  = 900;
sliderBarHeight = 12;

for trial = 1:length(allIndices)
    idx = allIndices(trial);
    img = resizedLineDrawingImages{idx};
    tex = Screen('MakeTexture', window, img);

    % Slider geometry
    sliderY      = yCenter + resizedHeight/2 + 200;
    sliderX      = xCenter;
    sliderLeft   = sliderX - sliderBarWidth/2;
    sliderRight  = sliderX + sliderBarWidth/2;
    
    SetMouse(sliderX, sliderY, window);

    % Questions and labels
    sliderQuestions = {
        'How many distinct materials is this typically composed of?', ...
        'How variable are the materials this could be made of?'
    };

    sliderLabels = {
        {'Usually one material', 'Made of many materials'}, ...
        {'Always one material', 'Could be many materials'}
    };

    sliderResponses = [NaN, NaN];

    for q = 1:2
        sliderValue = 0.5;
        isRated     = false;
        SetMouse(xCenter, sliderY, window);  % reset mouse to slider center

        while ~isRated
            [x, ~, buttons] = GetMouse(window);
            x = max(min(x, sliderRight), sliderLeft);
            sliderValue = (x - sliderLeft) / sliderBarWidth;

            % Draw background
            Screen('FillRect', window, backgroundColor);

            % Question text
            Screen('TextFont', window, 'Arial');
            Screen('TextSize', window, 30);
            DrawFormattedText(window, sliderQuestions{q}, ...
                'center', screenYpixels * 0.18, [0 0 0]);

            % Image
            dstRect = CenterRectOnPointd([0 0 resizedWidth resizedHeight], xCenter, yCenter);
            Screen('DrawTexture', window, tex, [], dstRect);

            % Image name (cleaned)
            cleanName  = regexprep(strtok(imageNames{idx}, '_'), '([a-z])([A-Z])', '$1 $2');
            bounds     = Screen('TextBounds', window, cleanName);
            textWidth  = bounds(3) - bounds(1);
            textX      = xCenter - textWidth / 2;
            textY      = dstRect(2) - resizedHeight / 2 + 50;
            Screen('DrawText', window, cleanName, textX, textY, [0 0 0]);

            % Slider bar
            baseRect = [sliderLeft, sliderY - sliderBarHeight/2, ...
                        sliderRight, sliderY + sliderBarHeight/2];
            Screen('FillRect', window, [200 200 200], baseRect);

            % Dot
            dotX = sliderLeft + sliderValue * sliderBarWidth;
            Screen('FillOval', window, [255 0 0], ...
                [dotX - 7, sliderY - 7, dotX + 7, sliderY + 7]);

            % Labels
            labelY    = round(sliderY + 40);
            labelBoxW = 400;
            labelBoxH = 60;

            DrawFormattedText(window, sliderLabels{q}{1}, ...
                'center', labelY, [0 0 0], [], [], [], [], [], ...
                round([sliderLeft - labelBoxW/2, labelY, ...
                       sliderLeft + labelBoxW/2, labelY + labelBoxH]));

            DrawFormattedText(window, sliderLabels{q}{2}, ...
                'center', labelY, [0 0 0], [], [], [], [], [], ...
                round([sliderRight - labelBoxW/2, labelY, ...
                       sliderRight + labelBoxW/2, labelY + labelBoxH]));

            Screen('Flip', window);

            % Confirm with left mouse button
            if buttons(1)
                isRated = true;
                while any(buttons)
                    [~, ~, buttons] = GetMouse(window);
                end
            end

            % ESC to abort
            [keyIsDown, ~, keyCode] = KbCheck;
            if keyIsDown && keyCode(KbName('ESCAPE'))
                save(fullfile(dataDir, ['diagnosticity_slider_' participantID '_incomplete.mat']), ...
                     'diagnosticityResponses');
                sca; ShowCursor(); error('Experiment manually terminated.');
            end
        end

        sliderResponses(q) = sliderValue;

        % Fixation between Q1 and Q2
        if q == 1
            Screen('FillRect', window, backgroundColor);
            Screen('DrawLines', window, allCoords, lineWidthPix, fixationColor, [xCenter yCenter]);
            Screen('Flip', window);
            WaitSecs(0.75);
        end
    end

    % Save this trial's data
    diagnosticityResponses(trial).trial              = trial;
    diagnosticityResponses(trial).imageIndex         = idx;
    diagnosticityResponses(trial).imageName          = imageNames{idx};
    diagnosticityResponses(trial).category           = categoryNames{idx};
    diagnosticityResponses(trial).slider1_composition = sliderResponses(1);
    diagnosticityResponses(trial).slider2_variability = sliderResponses(2);
    diagnosticityResponses(trial).participantID      = participantID;
    diagnosticityResponses(trial).gender             = gender;
    diagnosticityResponses(trial).age                = age;

    % Inter-trial fixation (1 s)
    Screen('FillRect', window, backgroundColor);
    Screen('DrawLines', window, allCoords, lineWidthPix, fixationColor, [xCenter yCenter]);
    Screen('Flip', window);
    WaitSecs(1);
end

% Save final diagnosticity data
save(fullfile(dataDir, ['diagnosticity_slider_' participantID '.mat']), ...
     'diagnosticityResponses');

%% ###############################################################
%            Transition Screen Between Parts                      
% ###############################################################

Screen('FillRect', window, backgroundColor);
Screen('TextSize', window, 40);
Screen('TextColor', window, [0 0 0]);
Screen('TextFont', window, 'Arial');

famIntro = [ ...
    'You have completed the first part.\n\n' ...
    'In the next part, you will see 10 images at once from the SAME category.\n\n' ...
    'Click them one by one from MOST familiar to LEAST familiar.\n\n' ...
    'You can click again on an image to undo its rank.\n\n' ...
    'Press SPACE when you are ready to continue.' ];

DrawFormattedText(window, famIntro, 'center', 'center');
Screen('Flip', window);

spacePressed = false;
while ~spacePressed
    [keyIsDown, ~, keyCode] = KbCheck;
    if keyIsDown && keyCode(KbName('SPACE'))
        spacePressed = true;
    end
end

%% ######################## FAMILIARITY BLOCK #############################

mainImageFolder = fullfile(pwd, 'ImFolder');
if ~exist(mainImageFolder, 'dir')
    sca;
    error('ImFolder not found in %s.', pwd);
end

% Collect original images (*_original_*.png)
originalImageList      = {};
originalImageCategories = {};

folders = dir(mainImageFolder);
folders = folders([folders.isdir] & ~ismember({folders.name}, {'.', '..'}));

for f = 1:numel(folders)
    folderName = folders(f).name;
    folderPath = fullfile(mainImageFolder, folderName);
    subfolders = dir(folderPath);
    subfolders = subfolders([subfolders.isdir] & ~ismember({subfolders.name}, {'.', '..'}));

    for s = 1:numel(subfolders)
        subfolderPath = fullfile(folderPath, subfolders(s).name);
        files = dir(fullfile(subfolderPath, '*_original_*.png'));

        for k = 1:numel(files)
            originalImageList{end+1,1}      = fullfile(subfolderPath, files(k).name);
            originalImageCategories{end+1,1} = folderName;
        end
    end
end

assert(numel(originalImageList) >= 80, 'Expected at least 80 original images.');

% Recalculate image size for familiarity block
sampleImg = imread(originalImageList{1});
[originalHeight, originalWidth, ~] = size(sampleImg);
aspectRatio = originalWidth / originalHeight;

if aspectRatio > 1
    resizedWidth  = stimulusSizePixelsTarget;
    resizedHeight = round(stimulusSizePixelsTarget / aspectRatio);
else
    resizedHeight = stimulusSizePixelsTarget;
    resizedWidth  = round(stimulusSizePixelsTarget * aspectRatio);
end

categoriesFam = unique(originalImageCategories);
numCategories = numel(categoriesFam);

ShowCursor('Arrow', window);

gridRows = 2;
gridCols = 5;
spacing  = 100;

familiarityResponses = struct('category', {}, 'clickOrder', {}, 'imageInfo', {});

for catIdx = 1:numCategories
    catName = categoriesFam{catIdx};
    idxs    = find(strcmp(originalImageCategories, catName));
    assert(numel(idxs) >= 10, 'Not enough original images in category: %s', catName);

    selectedIdxs = idxs(1:10);  % could be randomized if needed
    imagesThisTrial = {};

    for k = 1:10
        imgPath = originalImageList{selectedIdxs(k)};
        imagesThisTrial{end+1} = struct( ...
            'imagePath', imgPath, ...
            'filename',  getfield(dir(imgPath), 'name'), ... 
            'category',  catName);
    end

    % Prepare textures & positions
    textures  = zeros(1, 10);
    positions = cell(1, 10);

    totalW = gridCols * resizedWidth + (gridCols - 1) * spacing;
    totalH = gridRows * resizedHeight + (gridRows - 1) * spacing;
    startX = (screenXpixels - totalW)/2 + resizedWidth/2;
    startY = (screenYpixels - totalH)/2 + resizedHeight/2;

    k = 1;
    for row = 1:gridRows
        for col = 1:gridCols
            img = imread(imagesThisTrial{k}.imagePath);
            img = imresize(img, [resizedHeight resizedWidth]);
            textures(k) = Screen('MakeTexture', window, img);
            posX        = startX + (col-1)*(resizedWidth + spacing);
            posY        = startY + (row-1)*(resizedHeight + spacing);
            positions{k} = CenterRectOnPointd([0 0 resizedWidth resizedHeight], posX, posY);
            k = k + 1;
        end
    end

    rankedImages = nan(1, 10); % rankedImages(rank) = imageIndex
    imageRanks   = nan(1, 10); % imageRanks(imageIndex) = rank

    while true
        Screen('FillRect', window, backgroundColor);
        DrawFormattedText(window, sprintf('Rank images in category: %s', catName), ...
            'center', screenYpixels * 0.08, [0 0 0]);

        % Draw all images
        for i = 1:10
            Screen('DrawTexture', window, textures(i), [], positions{i});
        end

        % Draw ranks
        for r = 1:10
            imgIdx = rankedImages(r);
            if ~isnan(imgIdx)
                dstRect = positions{imgIdx};
                Screen('FrameRect', window, [0 200 0], dstRect, 6);
                Screen('TextSize', window, 28);
                rankText = sprintf('%d', r);
                textX    = dstRect(1) + 10;
                textY    = dstRect(2) + 10;
                Screen('DrawText', window, rankText, textX, textY, [0 200 0]);
            end
        end

        % Instructions
        Screen('TextSize', window, 32);
        if all(~isnan(rankedImages))
            DrawFormattedText(window, 'Press SPACE to continue. Click again to change ranks.', ...
                'center', screenYpixels * 0.92, [0 0 0]);
        else
            DrawFormattedText(window, 'Click to assign rank (1 = most familiar). Click again to undo.', ...
                'center', screenYpixels * 0.92, [0 0 0]);
        end

        Screen('Flip', window);

        % Mouse clicks
        [x, y, buttons] = GetMouse(window);
        if any(buttons)
            for i = 1:10
                if IsInRect(x, y, positions{i})
                    if ~isnan(imageRanks(i))
                        % Image already ranked -> remove
                        oldRank = imageRanks(i);
                        rankedImages(oldRank) = NaN;
                        imageRanks(i)         = NaN;
                    else
                        % Assign next available rank
                        nextRank = find(isnan(rankedImages), 1);
                        if ~isempty(nextRank)
                            rankedImages(nextRank) = i;
                            imageRanks(i)          = nextRank;
                        end
                    end
                    break;
                end
            end
            while any(buttons)
                [~, ~, buttons] = GetMouse(window);
            end
        end

        % Keyboard
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown && keyCode(KbName('ESCAPE'))
            save(fullfile(dataDir, ['familiarity_ranking_' participantID '_incomplete.mat']), ...
                 'familiarityResponses');
            sca; ShowCursor(); error('Manually exited.');
        elseif keyIsDown && keyCode(KbName('SPACE')) && all(~isnan(rankedImages))
            break;
        end
    end

    % Build imageInfo for this category
    imageInfo = cell(1, 10);
    for r = 1:10
        imgIdx = rankedImages(r);
        imageInfo{r} = imagesThisTrial{imgIdx};
    end

    familiarityResponses(catIdx).category   = catName;
    familiarityResponses(catIdx).clickOrder = rankedImages;
    familiarityResponses(catIdx).imageInfo  = imageInfo;

    % Inter-category fixation
    Screen('FillRect', window, backgroundColor);
    Screen('DrawLines', window, allCoords, lineWidthPix, fixationColor, [xCenter yCenter]);
    Screen('Flip', window);
    WaitSecs(1);
end

% Flatten to table
flatFamiliarityData = table();
rowIdx = 1;

for c = 1:length(familiarityResponses)
    for rank = 1:10
        info = familiarityResponses(c).imageInfo{rank};
        flatFamiliarityData(rowIdx, :) = table( ...
            c, ...
            rank, ...
            string(info.filename), ...
            string(info.category), ...
            string(participantID), ...
            string(gender), ...
            age, ...
            'VariableNames', {'CategoryIndex', 'ClickRank', 'Filename', 'Category', 'ParticipantID', 'Gender', 'Age'} ...
        );
        rowIdx = rowIdx + 1;
    end
end

save(fullfile(dataDir, ['familiarity_ranking_' participantID '.mat']), ...
     'familiarityResponses', 'flatFamiliarityData');

%% ########################################################################
%                         Goodbye Screen                                 
% #########################################################################

goodbyeMessage = 'The experiment has ended. \n\nThe screen will close automatically in 5 seconds.';

Screen('TextSize', window, 40);
Screen('TextColor', window, [0 0 0]);
Screen('FillRect', window, backgroundColor);
DrawFormattedText(window, goodbyeMessage, 'center', 'center');
Screen('Flip', window);

WaitSecs(5);

sca;
ShowCursor();
disp('Experiment finished. Screen closed.');
S