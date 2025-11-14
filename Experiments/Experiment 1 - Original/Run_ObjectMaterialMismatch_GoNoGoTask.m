%% Go/No-Go Task for Object–Material Mismatch
% Author: Fatma Kilic
%
% Description:
%   This script runs a Go/No-Go task in which participants respond to
%   briefly presented images of objects from different categories.
%   On "Go" trials (target category), participants press ENTER.
%   On "No-Go" trials (all other categories), participants withhold response.
%
% Requirements:
%   - MATLAB (tested with R2017b or later)
%   - Psychtoolbox
%   - Image folder structure:
%       ImFolder/
%           Animal/
%               Obj1/
%                   *.png (6 images)
%               Obj2/
%               ...
%           Vegetable/
%           Appliance/
%           Clothing/
%           Furniture/
%           Musical Instrument/
%           Tool/
%           Vehicle/
%
% Output:
%   - Saves a .mat file with a table "responses" containing:
%       Block, Trial, Category, ImageShown, Subfolder, Correct,
%       ReactionTime, ParticipantInfo (ID, Gender, Age)
%
% Notes:
%   - For real experiments, you may want to disable SkipSyncTests
%     after validating your setup.

%% Housekeeping
sca;
close all;
clearvars;

KbName('UnifyKeyNames');

% Use participant-specific RNG seed for reproducibility if desired:
% rng('shuffle'); % participant-specific randomization (kept implicit here)

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
%                     Data Saving Setup / Duplicate Check                 
% #########################################################################

% Create a "data" folder (or adjust to your repo structure)
dataDir = fullfile(pwd, 'data');
if ~exist(dataDir, 'dir')
    mkdir(dataDir);
end

% Pattern for existing files for this participant
filePatternData = fullfile(dataDir, ['*' participantID '*.mat']);
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

% Use the maximum screen index by default
screenNumber = max(Screen('Screens'));

% For debugging, skip sync tests (set to 0 for real lab use!)
Screen('Preference', 'SkipSyncTests', 1);

backgroundColor = [128 128 128]; % mid-grey

[window, windowRect] = PsychImaging('OpenWindow', screenNumber, backgroundColor);
HideCursor();

[screenResolutionWidth, screenResolutionHeight] = Screen('WindowSize', screenNumber);

% Physical screen width in cm (adjust to your setup)
screenWidthCm = 59.6736; % Lab PC width

pixelsPerCm = screenResolutionWidth / screenWidthCm;

%% ########################################################################
%                         Stimulus Size (Visual Angle)                    
% #########################################################################

visualAngleTarget = 20;   % degrees
viewingDistance   = 50;   % cm

stimulusSizeCmTarget = 2 * viewingDistance * tan((visualAngleTarget / 2) * pi / 180);
stimulusSizePixelsTarget = round(stimulusSizeCmTarget * pixelsPerCm);

[screenXpixels, screenYpixels] = Screen('WindowSize', screenNumber);
xCenter = screenXpixels / 2;
yCenter = screenYpixels / 2;

dstRectTarget = [0 0 stimulusSizePixelsTarget stimulusSizePixelsTarget];
dstRectTarget = CenterRectOnPointd(dstRectTarget, xCenter, yCenter);

disp(['Screen resolution: ' num2str(screenResolutionWidth) 'x' num2str(screenResolutionHeight) ' pixels']);
disp(['Screen width: ' num2str(screenWidthCm) ' cm']);
disp(['Pixels per cm: ' num2str(pixelsPerCm)]);
disp(['Stimulus size: ' num2str(stimulusSizePixelsTarget) ' pixels (' num2str(stimulusSizeCmTarget) ' cm)']);

frameRate = Screen('NominalFrameRate', screenNumber);
ifi       = Screen('GetFlipInterval', window);

% Timing in frames
targetDurationFrames   = 1;   % ~16.7 ms at 60 Hz
fixationDurationFrames = 3;   % frames
responseWindowFrames   = 60;  % frames for response window (~1 s at 60 Hz)

%% ########################################################################
%                         Instructions Screen                            
% #########################################################################

Screen('TextSize',  window, 40);
Screen('TextColor', window, [0 0 0]);
Screen('FillRect',  window, backgroundColor);

instrText = [ ...
    'In this experiment, you will be presented images briefly.\n\n' ...
    'In each block, you need to press ENTER as fast as possible\n' ...
    'when you see an object from the target category.\n\n' ...
    'Press Space when you are ready to start the experiment.'];

DrawFormattedText(window, instrText, 'center', 'center');
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

fixCrossDimPix  = 15;
lineWidthPix    = 4;
fixationColor   = [0 0 0];

xCoords = [-fixCrossDimPix fixCrossDimPix 0 0];
yCoords = [0 0 -fixCrossDimPix fixCrossDimPix];
allCoords = [xCoords; yCoords];

%% ########################################################################
%                         Load Images                                    
% #########################################################################

mainImageFolder = fullfile(pwd, 'ImFolder');
if ~exist(mainImageFolder, 'dir')
    sca;
    error('ImFolder not found in %s. Please create the folder and add stimuli.', pwd);
end

% Assumptions: 8 categories, each with 10 subfolders, 6 images per subfolder
numFolders      = 8;
subFolders      = 10;
imagesPerFolder = 6;

imageData = cell(numFolders * subFolders * imagesPerFolder, 1);
imageInfo = cell(numFolders * subFolders * imagesPerFolder, 1);

folders = dir(mainImageFolder);
folders = folders([folders.isdir] & ~ismember({folders.name}, {'.', '..'}));

img_idx = 0;

for f = 1:numFolders
    folderPath = fullfile(mainImageFolder, folders(f).name);
    subfolders = dir(folderPath);
    subfolders = subfolders([subfolders.isdir] & ~ismember({subfolders.name}, {'.', '..'}));
    
    for s = 1:subFolders
        subfolderPath = fullfile(folderPath, subfolders(s).name);
        images = dir(fullfile(subfolderPath, '*.png'));
        
        if numel(images) < imagesPerFolder
            warning('Subfolder %s has fewer than %d images.', subfolderPath, imagesPerFolder);
        end
        
        for img = 1:imagesPerFolder
            img_idx = img_idx + 1;
            thisFile = fullfile(subfolderPath, images(img).name);
            imageData{img_idx} = imread(thisFile);
            imageInfo{img_idx} = struct( ...
                'filename',  images(img).name, ...
                'folder',    folders(f).name, ...
                'folder_idx', f, ...
                'subfolder', subfolders(s).name);
        end
    end
end

% Use first image to compute aspect ratio for resizing
[originalHeight, originalWidth, ~] = size(imageData{1});
aspectRatio = originalWidth / originalHeight;

if aspectRatio > 1
    resizedWidth  = stimulusSizePixelsTarget;
    resizedHeight = round(stimulusSizePixelsTarget / aspectRatio);
else
    resizedHeight = stimulusSizePixelsTarget;
    resizedWidth  = round(stimulusSizePixelsTarget * aspectRatio);
end

% Resize all images
for k = 1:numel(imageData)
    imageData{k} = imresize(imageData{k}, [resizedHeight, resizedWidth]);
end

%% ########################################################################
%                         Experimental Design                            
% #########################################################################

numBaseBlocks = 8; % categories
repetitions   = 3;
numBlocks     = numBaseBlocks * repetitions;
numTrials     = 120;
numRows       = numBlocks * numTrials;

% Block order randomization
rng('shuffle'); % participant-specific randomization
blockOrder = repelem(1:numBaseBlocks, repetitions);
blockOrder = blockOrder(randperm(numBlocks));

% Category labels (must match ImFolder category names)
categories = {'Animal', 'Vegetable', 'Appliance', 'Clothing', ...
              'Furniture', 'Musical Instrument', 'Tool', 'Vehicle'};

% Preallocate table variables
Block          = zeros(numRows, 1);
Trial          = zeros(numRows, 1);
Category       = strings(numRows, 1);
ImageShown     = strings(numRows, 1);
Subfolder      = strings(numRows, 1);
Correct        = zeros(numRows, 1);
ReactionTime   = zeros(numRows, 1);
ParticipantCol = strings(numRows, 3);

responses = table(Block, Trial, Category, ImageShown, Subfolder, ...
                  Correct, ReactionTime, ParticipantCol, ...
                  'VariableNames', {'Block','Trial','Category','ImageShown', ...
                                    'Subfolder','Correct','ReactionTime','ParticipantInfo'});

responseIndex = 1;

%% ########################################################################
%                         Main Experiment Loop                           
% #########################################################################

for blockIndex = 1:numBlocks
    
    targetCategory = categories{blockOrder(blockIndex)};
    
    % Block instructions
    Screen('FillRect', window, backgroundColor);
    instructions = sprintf([ ...
        'In this block, respond to %s images as fast as possible.\n\n' ...
        'Press ENTER if you see %s.\n\nPress Space key to begin.'], ...
        targetCategory, targetCategory);
    DrawFormattedText(window, instructions, 'center', 'center');
    Screen('Flip', window);
    
    % Wait for Space to start block
    spacePressed = false;
    while ~spacePressed
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown && keyCode(KbName('space'))
            spacePressed = true;
        end
    end
    
    % Small pause before trials
    WaitSecs(1);
    
    % Initial fixation
    Screen('FillRect', window, backgroundColor);
    Screen('DrawLines', window, allCoords, lineWidthPix, fixationColor, [xCenter yCenter]);
    [~, StimulusOnsetTime] = Screen('Flip', window);
    
    while GetSecs - StimulusOnsetTime < fixationDurationFrames * ifi
        % keep displaying fixation
    end
    
    % Build image info struct for selection
    imageInfoStruct = [imageInfo{:}];
    
    targetCategoryImages    = imageInfoStruct(strcmpi({imageInfoStruct.folder}, targetCategory));
    nonTargetCategoryImages = imageInfoStruct(~strcmpi({imageInfoStruct.folder}, targetCategory));
    
    % Select 60 non-target images
    nonTargetImages = nonTargetCategoryImages(randperm(length(nonTargetCategoryImages), 60));
    
    % Combine and shuffle target + non-target
    allImages = [targetCategoryImages, nonTargetImages];
    allImages = allImages(randperm(numel(allImages)));
    
    %% Trial loop
    for trial = 1:numTrials
        
        imgInfo  = allImages(trial);
        isTarget = strcmpi(imgInfo.folder, targetCategory);
        
        % Find matching imageData entry
        imgMask = cellfun(@(x) strcmp(x.filename, imgInfo.filename) & ...
                               strcmp(x.folder,   imgInfo.folder), imageInfo);
        imgIndex = find(imgMask, 1);
        imgData  = imageData{imgIndex};
        
        % Present stimulus
        Screen('FillRect', window, backgroundColor);
        targetTexture = Screen('MakeTexture', window, imgData);
        dstRectTarget = CenterRectOnPointd([0 0 resizedWidth resizedHeight], xCenter, yCenter);
        Screen('DrawTexture', window, targetTexture, [], dstRectTarget);
        [~, StimulusOnsetTime] = Screen('Flip', window);
        
        % Keep stimulus on screen for targetDurationFrames
        while GetSecs - StimulusOnsetTime < targetDurationFrames * ifi
            % do nothing
        end
        
        % Response phase
        reactionTime = NaN;
        correct      = 0;
        startTime    = GetSecs;
        responseMade = false;
        
        while GetSecs - startTime < responseWindowFrames * ifi
            % Show fixation during response window
            Screen('FillRect', window, backgroundColor);
            Screen('DrawLines', window, allCoords, lineWidthPix, fixationColor, [xCenter yCenter]);
            Screen('Flip', window);
            
            [keyIsDown, keyPressTime, keyCode] = KbCheck;
            
            if keyIsDown && ~responseMade
                if keyCode(KbName('Return'))
                    reactionTime = keyPressTime - startTime;
                    
                    if isTarget
                        correct = 1;   % Hit
                    else
                        correct = 0;   % False alarm
                    end
                    responseMade = true;
                end
                
                if keyCode(KbName('ESCAPE'))
                    % Save partial data and exit
                    save(fullfile(dataDir, ['go_nogo_unfinished_response_data_' participantID '.mat']), 'responses');
                    disp('Experiment manually terminated by user.');
                    sca;
                    ShowCursor();
                    return;
                end
            end
        end
        
        % No response case
        if ~responseMade
            reactionTime = NaN;
            if isTarget
                correct = 0; % Miss
            else
                correct = 1; % Correct rejection
            end
        end
        
        % Store trial data
        responses.Block(responseIndex)        = blockIndex;
        responses.Trial(responseIndex)        = trial;
        responses.Category(responseIndex)     = string(targetCategory);
        responses.ImageShown(responseIndex)   = string(imgInfo.filename);
        responses.Subfolder(responseIndex)    = string(imgInfo.folder);
        responses.Correct(responseIndex)      = correct;
        responses.ReactionTime(responseIndex) = reactionTime;
        responses.ParticipantInfo(responseIndex, :) = string(participantInfo(:))';
        
        responseIndex = responseIndex + 1;
    end
end

%% ########################################################################
%                         Goodbye Screen                                 
% #########################################################################

goodbyeMessage = 'The experiment has ended. \n\nThe screen will close automatically in 5 seconds.';

Screen('FillRect', window, [0 0 0]);
Screen('TextSize', window, 40);
Screen('TextColor', window, [255 255 255]);
DrawFormattedText(window, goodbyeMessage, 'center', 'center');
Screen('Flip', window);

WaitSecs(5);

sca;
ShowCursor();
disp('Experiment finished. Screen closed.');

% Save responses
outFile = fullfile(dataDir, ['go_nogo_response_data_' participantID '.mat']);
save(outFile, 'responses');
disp(['Saved data to: ' outFile]);
