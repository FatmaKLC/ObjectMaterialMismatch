%% Go/No-Go Task for Object–Material Mismatch (Grayscale)
% Author: Fatma Kilic
%
% Description:
%   This script runs a Go/No-Go task using **grayscale** versions of the
%   object–material mismatch stimuli. The design is identical to the
%   color version, but images are loaded from "ImFolderGrayScale".
%
% Requirements:
%   - MATLAB (tested with R2017b or later)
%   - Psychtoolbox
%   - Image folder structure:
%       ImFolderGrayScale/
%           Animal/
%               Obj1/
%                   *.jpg (6 images)
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
%   - Saves a .mat file with a table "responses" in /data:
%       data/go_nogo_response_data_grayscale_<ParticipantID>.mat

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
gender        = strtrim(participantInfo{2}); %#ok<NASGU>
age           = str2double(participantInfo{3}); %#ok<NASGU>

participantInfo = reshape(participantInfo, 1, []);  % 1x3 cell

%% ########################################################################
%                     Data Saving Setup / Duplicate Check                 
% #########################################################################

dataDir = fullfile(pwd, 'data');
if ~exist(dataDir, 'dir')
    mkdir(dataDir);
end

filePatternData    = fullfile(dataDir, ['*' participantID '*.mat']);
existingFilesData  = dir(filePatternData);

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

experimentStartTime = datetime('now'); %#ok<NASGU>

screenNumber = max(Screen('Screens'));

Screen('Preference', 'SkipSyncTests', 1); % set to 0 for real experiments
backgroundColor = [128 128 128];

[window, windowRect] = PsychImaging('OpenWindow', screenNumber, backgroundColor);
HideCursor();

[screenResolutionWidth, screenResolutionHeight] = Screen('WindowSize', screenNumber);

% Physical screen width in cm (adjust to your setup)
screenWidthCm = 59.6736;

pixelsPerCm = screenResolutionWidth / screenWidthCm;

%% ########################################################################
%                         Stimulus Size (Visual Angle)                    
% #########################################################################

visualAngleTarget = 20;   % degrees
viewingDistance   = 50;   % cm

stimulusSizeCmTarget      = 2 * viewingDistance * tan((visualAngleTarget / 2) * pi / 180);
stimulusSizePixelsTarget  = round(stimulusSizeCmTarget * pixelsPerCm);

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

targetDurationFrames   = 1;   % ~16.7 ms at 60 Hz
fixationDurationFrames = 3;
responseWindowFrames   = 60;  % ~1 s at 60 Hz

%% ########################################################################
%                         Instructions Screen                            
% #########################################################################

Screen('TextSize',  window, 40);
Screen('TextColor', window, [0 0 0]);
Screen('FillRect',  window, backgroundColor);

instrText = [ ...
    'In this experiment, you will be presented images briefly.\n\n' ...
    'In each block, you need to press ENTER as fast as possible\n\n' ...
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

fixCrossDimPix = 15;
lineWidthPix   = 4;
fixationColor  = [0 0 0];

xCoords   = [-fixCrossDimPix fixCrossDimPix 0 0];
yCoords   = [0 0 -fixCrossDimPix fixCrossDimPix];
allCoords = [xCoords; yCoords];

%% ########################################################################
%                         Load Grayscale Images                          
% #########################################################################

mainImageFolder = fullfile(pwd, 'ImFolderGrayScale');
if ~exist(mainImageFolder, 'dir')
    sca;
    error('ImFolderGrayScale not found in %s. Please create the folder and add grayscale stimuli.', pwd);
end

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
        images = dir(fullfile(subfolderPath, '*.jpg')); % grayscale images as .jpg
        
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

[originalHeight, originalWidth, ~] = size(imageData{1});
aspectRatio = originalWidth / originalHeight;

if aspectRatio > 1
    resizedWidth  = stimulusSizePixelsTarget;
    resizedHeight = round(stimulusSizePixelsTarget / aspectRatio);
else
    resizedHeight = stimulusSizePixelsTarget;
    resizedWidth  = round(stimulusSizePixelsTarget * aspectRatio);
end

for k = 1:numel(imageData)
    imageData{k} = imresize(imageData{k}, [resizedHeight, resizedWidth]);
end

%% ########################################################################
%                         Experimental Design                            
% #########################################################################

numBaseBlocks = 8;
repetitions   = 3;
numBlocks     = numBaseBlocks * repetitions;
numTrials     = 120;
numRows       = numBlocks * numTrials;

rng('shuffle');
blockOrder = repelem(1:numBaseBlocks, repetitions);
blockOrder = blockOrder(randperm(numBlocks));

categories = {'Animal', 'Vegetable', 'Appliance', 'Clothing', ...
              'Furniture', 'Musical Instrument', 'Tool', 'Vehicle'};

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
    
    Screen('FillRect', window, backgroundColor);
    instructions = sprintf([ ...
        'In this block, respond to %s images as fast as possible.\n\n' ...
        'Press ENTER if you see %s.\n\nPress Space key to begin.'], ...
        targetCategory, targetCategory);
    DrawFormattedText(window, instructions, 'center', 'center');
    Screen('Flip', window);
    
    spacePressed = false;
    while ~spacePressed
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown && keyCode(KbName('space'))
            spacePressed = true;
        end
    end
    
    WaitSecs(1);
    
    % Initial fixation
    Screen('FillRect', window, backgroundColor);
    Screen('DrawLines', window, allCoords, lineWidthPix, fixationColor, [xCenter yCenter]);
    [~, StimulusOnsetTime] = Screen('Flip', window);
    
    while GetSecs - StimulusOnsetTime < fixationDurationFrames * ifi
        % keep fixation
    end
    
    imageInfoStruct = [imageInfo{:}];
    
    targetCategoryImages    = imageInfoStruct(strcmpi({imageInfoStruct.folder}, targetCategory));
    nonTargetCategoryImages = imageInfoStruct(~strcmpi({imageInfoStruct.folder}, targetCategory));
    
    nonTargetImages = nonTargetCategoryImages(randperm(length(nonTargetCategoryImages), 60));
    
    allImages = [targetCategoryImages, nonTargetImages];
    allImages = allImages(randperm(numel(allImages)));
    
    %% Trial loop
    for trial = 1:numTrials
        
        imgInfo  = allImages(trial);
        isTarget = strcmpi(imgInfo.folder, targetCategory);
        
        % Safer lookup: match filename and folder
        imgMask  = cellfun(@(x) strcmp(x.filename, imgInfo.filename) & ...
                                strcmp(x.folder,   imgInfo.folder), imageInfo);
        imgIndex = find(imgMask, 1);
        imgData  = imageData{imgIndex};
        
        Screen('FillRect', window, backgroundColor);
        targetTexture = Screen('MakeTexture', window, imgData);
        dstRectTarget = CenterRectOnPointd([0 0 resizedWidth resizedHeight], xCenter, yCenter);
        Screen('DrawTexture', window, targetTexture, [], dstRectTarget);
        [~, StimulusOnsetTime] = Screen('Flip', window);
        
        while GetSecs - StimulusOnsetTime < targetDurationFrames * ifi
            % show stimulus
        end
        
        reactionTime = NaN;
        correct      = 0;
        startTime    = GetSecs;
        responseMade = false;
        
        while GetSecs - startTime < responseWindowFrames * ifi
            Screen('FillRect', window, backgroundColor);
            Screen('DrawLines', window, allCoords, lineWidthPix, fixationColor, [xCenter yCenter]);
            Screen('Flip', window);
            
            [keyIsDown, keyPressTime, keyCode] = KbCheck;
            
            if keyIsDown && ~responseMade
                if keyCode(KbName('Return'))
                    reactionTime = keyPressTime - startTime;
                    
                    if isTarget
                        correct = 1;   % hit
                    else
                        correct = 0;   % false alarm
                    end
                    responseMade = true;
                end
                
                if keyCode(KbName('ESCAPE'))
                    save(fullfile(dataDir, ['go_nogo_unfinished_response_data_grayscale_' participantID '.mat']), 'responses');
                    disp('Experiment manually terminated by user.');
                    sca;
                    ShowCursor();
                    return;
                end
            end
        end
        
        if ~responseMade
            reactionTime = NaN;
            if isTarget
                correct = 0; % miss
            else
                correct = 1; % correct rejection
            end
        end
        
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
Screen('TextSize',  window, 40);
Screen('TextColor', window, [255 255 255]);
DrawFormattedText(window, goodbyeMessage, 'center', 'center');
Screen('Flip', window);

WaitSecs(5);

sca;
ShowCursor();
disp('Experiment finished. Screen closed.');

outFile = fullfile(dataDir, ['go_nogo_response_data_grayscale_' participantID '.mat']);
save(outFile, 'responses');
disp(['Saved data to: ' outFile]);
