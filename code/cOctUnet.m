classdef cOctUnet < handle

    properties
        TrainDataDir = [];
        TrainLabelDir = [];

        ClassNames = {};
%                      {  'Normal',...
%                         'Background',...
%                         'Honeycone' ,...
%                         'Collagen'  ,...
%                         'Blood'     ,...
%                         'NewEpi'    ,...
%                         'Clot'}
        
        PredictDataDir = '/projects/img/qubi/OCT/Tif Separated';
        PredictResultDir = '/projects/img/qubi/OCT/Tif Separated Results';
        
        DsTrain = [];
        
        Net = [];
        
        %-- Properties for the current Image
        ImageName = '';
        
        ImOverlay = [];
        ImRaw = [];
        ImSeg = [];
        
        M = 0;
        N = 0;
        P = 0;  %-- how many slices

        
        %-- Properties for ALL Images
        ImageNames = {};
        ImageNameParts = [];
        
        ImageStats = [];
        
        PixelSize = 4.54; %--4.54μm/pixel#
        ZStep = 50 %-- 50 um per z slice
    end
   
    methods
        function this = cOctUnet(trainDataDir, trainLabelDir, classNames)
            
            if nargin <= 2
                return;
            end
                
            this.TrainDataDir = trainDataDir;
            this.TrainLabelDir = trainLabelDir;
            
            this.ClassNames = classNames;
            
            if ispc
                this.PredictDataDir = '\img\qubi\OCT\Tif Separated';
                this.PredictResultDir = '\img\qubi\OCT\Tif Separated Results';
            else
                this.PredictDataDir = '/projects/img/qubi/OCT/Tif Separated';
                this.PredictResultDir = '/projects/img/qubi/OCT/Tif Separated Results';
            end
        end
        
        %-- wrapper to run all analysis of all images
        function runAnalysis(this)
            
            this.parseImageNames();
        
            this.getAllImageStats();
            
            this.overlay2Video_ALL();
            
            try
                  this.plotStats();
            catch
            end

            %-----
            for i = 1:length(this.ImageNames)
                disp(this.ImageNames{i});
                
                this.setCurrentImage(this.ImageNames{i},[false true false]);
                this.try3D(3);
                this.try3D(4);
                this.try3D(5);
                close all;
            end
        end   
        
        function testAnImage(this, anImageFile)
% e.g. 
%             f = imread('/projects/img/qubi/OCT/Tif Separated/001 1/001 1_s11.tif');
            f = imread(anImageFile);
            
            predictPatchSize = [512 512];
            segmentedImage = az_segmentImage_OCT(f, this.Net, predictPatchSize);
            [~, overlayed] = az_tidyupSegmentation_OCT(segmentedImage, f);
            

            montage({f, overlayed});
        end        
        
        
        function getTrainingData(this)
        
            imds = imageDatastore(this.TrainDataDir,'FileExtensions','.tif');
            
            pixelLabelIds = 1:numel(this.ClassNames);
            pxds = pixelLabelDatastore(this.TrainLabelDir,this.ClassNames,pixelLabelIds);
            
            %-- original image size [1378 460]
            blockSize = 256;
            this.DsTrain = randomPatchExtractionDatastore(imds,pxds,[blockSize,blockSize],'PatchesPerImage',256);         
            
            inputBatch = this.DsTrain.preview();
            disp(inputBatch)            
           
            for i = 1:height(inputBatch)
                anImage = inputBatch.InputImage{i};
                aLabel = grp2idx(reshape(inputBatch.ResponsePixelLabelImage{i}, 1, []));
                aLabel = uint8(reshape(aLabel, blockSize, []));

                disp(unique(inputBatch.ResponsePixelLabelImage{i}));
                max(aLabel(:))
                min(aLabel(:))
                
                figure, imshowpair(anImage, aLabel, 'montage');
                title(unique(inputBatch.ResponsePixelLabelImage{i}));
            end
        end
        
        function info = trainUnet(this)
            
            inputTileSize = [256,256 1];
            lgraph = az_createUnet(inputTileSize, numel(this.ClassNames));
            disp(lgraph.Layers);
            
            initialLearningRate = 0.05;
            maxEpochs = 100;
            minibatchSize = 16;
            l2reg = 0.0001;

            options = trainingOptions('sgdm',...
                                        'InitialLearnRate',initialLearningRate, ...
                                        'Momentum',0.9,...
                                        'L2Regularization',l2reg,...
                                        'MaxEpochs',maxEpochs,...
                                        'MiniBatchSize',minibatchSize,...
                                        'LearnRateSchedule','piecewise',...    
                                        'Shuffle','every-epoch',...
                                        'GradientThresholdMethod','l2norm',...
                                        'GradientThreshold',0.05, ...
                                        'Plots','training-progress', ...
                                        'VerboseFrequency',20,...
                                        'ExecutionEnvironment', 'multi-gpu');            
                                        
                                    
            modelDateTime = datestr(now,'dd-mmm-yyyy-HH-MM-SS');
            [net,info] = trainNetwork(this.DsTrain,lgraph,options);
            save(['Unet-' modelDateTime '-Epoch-' num2str(maxEpochs) '.mat'],'net','options');                                    
            this.Net = net;
        end
        
        
        function segment(this)
            aStruct = dir2(this.PredictDataDir);
            folders = {aStruct.name};

            for i = 1:length(folders)

                resultDir = sprintf('%s/%s', this.PredictResultDir, folders{i});
                flag = exist(resultDir, 'dir');
                if flag ~= 7
                    mkdir(resultDir);
                else
                    continue;
                end
                
                imds = imageDatastore(sprintf('%s/%s', this.PredictDataDir, folders{i}), 'FileExtensions','.tif');
                
                noImages = length(imds.Files);
                
                for j = 1:noImages
                    
                    f = imds.readimage(j);
                    
                    predictPatchSize = [512 512];
                    segmentedImage = az_segmentImage_OCT(f, this.Net, predictPatchSize);
                    [segmentedImage2, overlayed] = az_tidyupSegmentation_OCT(segmentedImage, f);

                    
                    if ispc
                        C = strsplit(imds.Files{j}, '\');
                    else
                        C = strsplit(imds.Files{j}, '/');
                    end
                    
                    aString = sprintf('%s/raw_%s', resultDir, C{end});
                    imwrite(segmentedImage, aString);
                    
                    aString = sprintf('%s/seg_%s', resultDir, C{end});
                    imwrite(segmentedImage2, aString);
                    
                    aString = sprintf('%s/overlayed_%s', resultDir, C{end});
                    imwrite(overlayed, aString);
                end                
            end
        end
        
        function resetCurrentImage(this)
            this.P = 0;
            this.M = 0;
            this.N = 0;
                
            this.ImRaw = [];
            this.ImSeg = [];
            this.ImOverlay = [];
            
            this.ImageName = '';

        end
        
        %-- flags are the boolean flag for loading [raw result, processed
        %result, overlayed] from harddrive.
        function setCurrentImage(this, anImageName, flags)
            
            this.resetCurrentImage();
            
            if nargin <= 2
                flags = [true true true];
            end
            
            if nargin <= 1 || isempty(anImageName)
                aDir = uigetdir(this.PredictDataDir);
                
                C = strsplit(aDir, '\');
                this.ImageName = C{end};
            else
                this.ImageName = anImageName;
                aDir = sprintf('%s/%s', this.PredictDataDir, this.ImageName);
            end
            
            aString = sprintf('%s/*.tif', aDir);
            C = dir2(aString);
            
            this.P = length(C);

            for i = 1:length(C)
                aFileName = fullfile(C(i).folder, C(i).name);
            
                if exist(aFileName, 'File') == 2
                    info = imfinfo(aFileName);
                    break;
                end
            end
                
            this.M = info.Height;
            this.N = info.Width;
                
            if flags(1) == true
                this.ImRaw = zeros(this.M, this.N, this.P);
            end
            
            if flags(2) == true
                this.ImSeg = zeros(this.M, this.N, this.P);
            end
            
            if flags(3) == true
                this.ImOverlay = zeros(this.M, this.N, 3, this.P);
            end
            
            
            for i = 1:this.P
%                 disp(i);
                
                if flags(1) == true
                    aString = sprintf('%s/%s/raw_%s_s%d.tif', this.PredictResultDir, this.ImageName, this.ImageName, i);

                    f = imread(aString);
                    this.ImRaw(:, :, i) = f;
                end
                
                if flags(2) == true
                    aString = sprintf('%s/%s/seg_%s_s%d.tif', this.PredictResultDir, this.ImageName, this.ImageName, i);

                    %-- if I have deleted the file according to Ana!
                    if exist(aString, 'File') == 2
                        f = imread(aString);
                    else
                        f = uint8(zeros(this.M, this.N));
                    end
                        
                    this.ImSeg(:, :, i) = f;
                end                
                
                if flags(3) == true
                    aString = sprintf('%s/%s/overlayed_%s_s%d.tif', this.PredictResultDir, this.ImageName, this.ImageName, i);

                    f = imread(aString);
                    this.ImOverlay(:, :, :, i) = f;
                end                
            end
        end
        
        function o_statsTable = getCurrentImageStats(this, flagSilentMode)
            
            if nargin<= 1
                flagSilentMode = false;
            end
            
            %-- only for label == 3 / NewEpidermis
            area1 = zeros(1, this.P);
            areaRatio1 = zeros(1, this.P);

            %-- only for label == 4 / honeycomb
            area2 = zeros(1, this.P);
            areaRatio2 = zeros(1, this.P);

            %-- only for label == 5 / collagen
            area3 = zeros(1, this.P);
            areaRatio3 = zeros(1, this.P);

            %-- only for label == 1 / dried clot
            area4 = zeros(1, this.P);
            areaRatio4 = zeros(1, this.P);
            
            %-- 1 + 3 + 4 + 5, total non-intact
%             area5 = zeros(1, this.P);
            areaRatio5 = zeros(1, this.P);
            
%             area6 = zeros(1, this.P);
            areaRatio6 = zeros(1, this.P);
            
            width = zeros(1, this.P);
            widthGranulation = zeros(1, this.P);
            heightClots = zeros(1, this.P);
            
            for i = 1:this.P
                anImage = this.ImSeg(:, :, i);
                
                area1(i) = sum(sum(anImage == 3)) * this.PixelSize * this.PixelSize / 1000000; 
                area2(i) = sum(sum(anImage == 4)) * this.PixelSize * this.PixelSize / 1000000; 
                area3(i) = sum(sum(anImage == 5)) * this.PixelSize * this.PixelSize / 1000000; 
                area4(i) = sum(sum(anImage == 1)) * this.PixelSize * this.PixelSize / 1000000; 
            end
            
            area1 = smoothResults_OCT(area1);
            area2 = smoothResults_OCT(area2);
            area3 = smoothResults_OCT(area3);
            area4 = smoothResults_OCT(area4);
            area5 = area1 + area2 + area3 + area4;
            area6 = area1 + area4;
            
            for i = 1:this.P
                anImage = this.ImSeg(:, :, i);
                
                totalTissueArea = (sum(sum(anImage == 6)) + area5(i)) * this.PixelSize * this.PixelSize / 1000000;
                
                if sum(anImage(:)) ~= 0
                    areaRatio1(i) = area1(i) ./ (totalTissueArea + eps);
                    areaRatio2(i) = area2(i) ./ (totalTissueArea + eps);
                    areaRatio3(i) = area3(i) ./ (totalTissueArea + eps);
                    areaRatio4(i) = area4(i) ./ (totalTissueArea + eps);
                    areaRatio5(i) = area5(i) ./ (totalTissueArea + eps);
                    areaRatio6(i) = area6(i) ./ (totalTissueArea + eps);
                else
                    areaRatio1(i) = nan;
                    areaRatio2(i) = nan;
                    areaRatio3(i) = nan;
                    areaRatio4(i) = nan;
                    areaRatio5(i) = nan;
                    areaRatio6(i) = nan;
                end                    
                
                anImageMax = anImage==3 | anImage==4 | anImage==5 | anImage==1;
%                 anImageMax = anImage==4;
                STATS = regionprops(anImageMax, 'BoundingBox');
                if ~isempty(STATS)
                    
                    aWidth = zeros(1, length(STATS));
                    for j = 1:length(STATS)
                        aWidth(j) = STATS(j).BoundingBox(3);
                    end
                    
                    width(i) = max(aWidth)* this.PixelSize /1000;
                end

                %-- width of the granulation tissue only
                anImageMax = anImage==4;
                STATS = regionprops(anImageMax, 'BoundingBox');
                if ~isempty(STATS)
                    
                    aWidth = zeros(1, length(STATS));
                    for j = 1:length(STATS)
                        aWidth(j) = STATS(j).BoundingBox(3);
                    end
                    
                    widthGranulation(i) = max(aWidth)* this.PixelSize /1000;
                end
                

                %-- hights of the clots
                anImageMax = anImage==1;
                STATS = regionprops(anImageMax, 'BoundingBox');
                if ~isempty(STATS)
                    
                    aHeight = zeros(1, length(STATS));
                    for j = 1:length(STATS)
                        aHeight(j) = STATS(j).BoundingBox(4);
                    end
                    heightClots(i) = max(aHeight)* this.PixelSize /1000;
                end
                
                
                
            end
                
            volume1 = sum(area1) * this.ZStep /1000;
            volume2 = sum(area2) * this.ZStep /1000;
            volume3 = sum(area3) * this.ZStep /1000;
            volume4 = sum(area4) * this.ZStep /1000;
            volume5 = sum(area5) * this.ZStep /1000;
            volume6 = sum(area6) * this.ZStep /1000;

            vRatio1 = mean(areaRatio1, 'omitnan');
            vRatio2 = mean(areaRatio2, 'omitnan');
            vRatio3 = mean(areaRatio3, 'omitnan');
            vRatio4 = mean(areaRatio4, 'omitnan');
            vRatio5 = mean(areaRatio5, 'omitnan');
            vRatio6 = mean(areaRatio6, 'omitnan');
            
            widthMax = max(width);
            widthMaxGranulation = max(widthGranulation);
            heightMaxClots = max(heightClots);
            
            T1 = array2table(volume1, 'VariableNames', {'Volume1'});
            T2 = array2table(volume2, 'VariableNames', {'Volume2'});
            T3 = array2table(volume3, 'VariableNames', {'Volume3'});
            T4 = array2table(volume4, 'VariableNames', {'Volume4'});
            T4_1 = array2table(volume5, 'VariableNames', {'Volume5'});
            T4_2 = array2table(volume6, 'VariableNames', {'Volume6'});
            T5 = array2table(vRatio1, 'VariableNames', {'vRatio1'});
            T6 = array2table(vRatio2, 'VariableNames', {'vRatio2'});
            T7 = array2table(vRatio3, 'VariableNames', {'vRatio3'});
            T8 = array2table(vRatio4, 'VariableNames', {'vRatio4'});
            T8_1 = array2table(vRatio5, 'VariableNames', {'vRatio5'});
            T8_2 = array2table(vRatio6, 'VariableNames', {'vRatio6'});
            T9 = array2table(widthMax, 'VariableNames', {'widthMax'});
            T10 = array2table(widthMaxGranulation, 'VariableNames', {'widthGranulation'});
            T11 = array2table(heightMaxClots, 'VariableNames', {'heightClots'});
           
            o_statsTable = [T1 T2 T3 T4 T4_1 T4_2 T5 T6 T7 T8 T8_1 T8_2 T9 T10 T11];
            
            if flagSilentMode == false
            
                aFigure = figure('units','normalized','outerposition',[0 0 1 1]);

                areaAll = cat(2, area3, area2, area1, area4);
                areaRatio = cat(2, areaRatio3', areaRatio2', areaRatio1', areaRatio4');

                ax = subplot(4, 3, 1); plotAStat_OCT(ax, area1, [], [], 'Slices', 'Area NeoEpidermis (mm^{2})', [], 8, [0.9290    0.6940    0.1250]);
                ax = subplot(4, 3, 2); plotAStat_OCT(ax, areaRatio1, [], [], 'Slices', 'areaRatio NeoEpidermis', [], 8,[0.9290    0.6940    0.1250]);

                ax = subplot(4, 3, 4); plotAStat_OCT(ax, area2, [], [], 'Slices', 'Area Sponginess (mm^{2})', [], 8, [0.8500    0.3250    0.0980]);
                ax = subplot(4, 3, 5); plotAStat_OCT(ax, areaRatio2, [], [], 'Slices',  'areaRatio Sponginess', [], 8, [0.8500    0.3250    0.0980]);

                ax = subplot(4, 3, 7); plotAStat_OCT(ax, area3, [], [], 'Slices', 'Area Collagen (mm^{2})', [], 8, [     0    0.4470    0.7410]);
                ax = subplot(4, 3, 8); plotAStat_OCT(ax, areaRatio3, [], [],'Slices', 'areaRatio Collagen', [], 8, [     0    0.4470    0.7410]);

                ax = subplot(4, 3, 10); plotAStat_OCT(ax, area4, [], [], 'Slices', 'Area Clot (mm^{2})', [], 8, [0.4940    0.1840    0.5560]);
                ax = subplot(4, 3, 11); plotAStat_OCT(ax, areaRatio4, [], [], 'Slices', 'areaRatio Clot', [], 8, [0.4940    0.1840    0.5560]);

                ax = subplot(4, 3, 12); plotAStat_OCT(ax, width, [], [],'Slices', 'width (mm)', [], 8, [0 0 0]);

                ax = subplot(4, 3, 3); plotAStat_OCT(ax, areaAll, [], [],'Slices', 'Total Area (mm^{2})', [], 8);
                ax = subplot(4, 3, 6); plotAStat_OCT(ax, areaRatio, [], [],'Slices', 'Area Ratio', [], 8);

                aString = sprintf('%s\\plotDetails_%s.png', pwd, this.ImageName);
                saveas(aFigure, aString);
            end
        end
        
        function getAllImageStats(this, flag)
            
            if nargin<=1 
                flag = false;
            end
            
            this.ImageStats = [];
            
            for i = 1:length(this.ImageNames)
                disp(i);
                disp(this.ImageNames{i});
                
                this.setCurrentImage(this.ImageNames{i},[false true false]);
                this.ImageStats = [this.ImageStats; this.getCurrentImageStats(flag)];
                
                close all;
            end 
            
            this.ImageStats = [this.ImageStats, this.ImageNameParts, array2table(this.ImageNames')];            
            
            aString = sprintf('%s/stats.csv', pwd);
            writetable(this.ImageStats, aString);  
            
            aString = sprintf('%s/stats.mat', pwd);
            stats = this.ImageStats;
            save(aString, 'stats');              
        end

        function parseImageNames(this)
            
            aStruct = dir2(this.PredictDataDir);
            this.ImageNames = {aStruct.name};
            
            %-- this is the list of images need to be analysed from Ana
            %master file.
            F = load('/home/klhw327/Matlab_Works/2020-05 OCT/patientUID.mat');
            
            [a, ~] = ismember(this.ImageNames, F.patientUID);
            this.ImageNames(a == 0) = [];
            
            userID = cell(length(this.ImageNames), 1);
            days = zeros(length(this.ImageNames), 1);
            caseID = zeros(length(this.ImageNames), 1);
            
            for i = 1:length(this.ImageNames)
                
                C = strsplit(this.ImageNames{i}, ' ');
                C2 = strsplit(C{2}, '.');
                
                userID{i} = C{1};
                days(i) = str2double(C2{1});
                
                if length(C2) <= 1
                    caseID(i) = 0;
                else
                    caseID(i) = str2double(C2{2});
                end
            end
            
            T1 = array2table(userID, 'VariableNames', {'UserID'});
            T2 = array2table(days, 'VariableNames', {'Days'});
            T3 = array2table(caseID, 'VariableNames', {'CaseID'});
            
            this.ImageNameParts = [T1 T2 T3];
        end
        
        function plotStats(this)

            v = this.ImageStats(:, 1:11);
            
            for k = 1:6:13
%                 % Create figure
%                 aFigure = figure('units','normalized','outerposition',[0 0 1 1]);

                userIDUnique = unique(this.ImageNameParts.UserID);

                for i = 1:length(userIDUnique)


                    [userFlag, ~] = ismember(this.ImageNameParts.UserID, userIDUnique{i});

                    days = this.ImageNameParts.Days(userFlag);
                    caseID = this.ImageNameParts.CaseID(userFlag);

                    [~, index] = sort(days);

                    aStat = table2array(v(:, k:k+3));
                    yMax = max(aStat);
                    aStat = aStat(userFlag, :);
                    aStat = aStat(index, :);

                    aString = cell(1, length(index));
                    for j = 1:length(index)
                        aString{j} = sprintf('%i\\_%i', days(index(j)), caseID(index(j)));
                    end

%                     ax = subplot(ceil(length(userIDUnique)*0.25), 4, i);
%                     plotAStat2_OCT(ax, aStat, yMax, aString, 'Days', this.ImageStats.Properties.VariableNames(k), userIDUnique{i}, 10);

                    aFigure = figure('units','normalized','outerposition',[0 0 1 1]);
                    h = axes('parent',aFigure);
                    plotAStat2_OCT(h, aStat, yMax, aString, 'Days', this.ImageStats.Properties.VariableNames(k), userIDUnique{i}, 10);

                    aString = sprintf('%s/plot_%s_%s.png', pwd, userIDUnique{i}, this.ImageStats.Properties.VariableNames{k});
                    saveas(aFigure, aString);
                    close all;
                end

%                 aString = sprintf('%s/plot_%s.png', pwd, this.ImageStats.Properties.VariableNames{k});
%                 saveas(aFigure, aString);

%                 aString = sprintf('%s/plotStatslot_%s.fig', pwd, this.ImageStats.Properties.VariableNames{k});
%                 saveas(aFigure, aString);
            end
        end
        
        function overlay2Video(this)
            %___________________________________________________
            %
            aString = sprintf('%s\\overlay_%s', pwd, this.ImageName);
            aWriter = VideoWriter(aString);            
            aWriter.FrameRate = 10;
            
            aWriter.open();
            
            for i = 1:size(this.ImOverlay, 4)
                temp = im2double(uint8(squeeze(this.ImOverlay(:, :, :, i))));
                aWriter.writeVideo(temp);
            end            
            
            aWriter.close();
        end
            
        function overlay2Video_ALL(this)

            for i = 1:length(this.ImageNames)
                this.setCurrentImage(this.ImageNames{i},[false false true]);
                this.overlay2Video();
            end
        end
        
        function try3D(this, whichLabel)

            if nargin <= 1
                whichLabel = 3;
            end
            
            %---------
            aMask = uint8(this.ImSeg == whichLabel);
            
            aMask = imresize(aMask, 0.25);
            aMask = medfilt3(aMask, [7 7 7]);
            
            
            %___________________________________________________
            %
            aFigure = figure();
            [axes1, aPatch] = az_showLabelMat3D_OCT(aMask, aFigure, 'Full');
        
            if isempty(aPatch)
                close all;
                return;
            end
            
            
            aString = sprintf('%s/rotation_%s_Label_%d', pwd, this.ImageName, whichLabel);
            aWriter = VideoWriter(aString);            
            aWriter.FrameRate = 5;
            
            aWriter.open();
            
            for i = 1:72
                camorbit(axes1, 10,0,'data',[0 1 0])
                drawnow
                
                F = getframe(gcf);
                [X, ~] = frame2im(F);
                
                if i == 1 || i == 10 || i == 20
                    tempString = sprintf('%s/rotation_%s_Label_%d_ROT_%d.tif', pwd, this.ImageName, whichLabel, i);
                    imwrite(X, tempString);
                end
                aWriter.writeVideo(X);
            end            
            
            aWriter.close();

            aString = sprintf('%s/rotation_%s_Label_%d.fig', pwd, this.ImageName, whichLabel);
            saveas(aFigure, aString);
        end
        
        function loadNet(this, aNet)
            this.Net = aNet;
        end
        
    end
    
    
    
    methods (Access = private)    
       
    end
    
    methods (Static)
        %_________________________________________________________________
        %
        %   Copy from Windows to Linux
        %_________________________________________________________________
        %
        function obj = setupTrainingData(gTruth, flagSlientMode)
            
            if nargin <= 1
                flagSlientMode = true;
            end
                        
            if nargin < 1 || isempty(gTruth)
                [fileName, pathName] = uigetfile('*.mat','load a ground truth gTruth.mat file.');            
                F = load(fullfile(pathName, fileName));
                gTruth = F.gTruth;
                
                
                if ispc && flagSlientMode == false
                    destPath = '\Matlab_Works\2020-05 OCT';
                    copyfile(fullfile(pathName, fileName), fullfile(destPath, fileName));
                end
            end
            
            if ~ispc
                aFile = gTruth.DataSource.Source{1};
                [path, ~, ~] = fileparts(aFile);

                C = strsplit(path, '/');

                destPath = '/home/klhw327/Matlab_Works/2020-05 OCT';
                trainDataDir = sprintf('%s/%s', destPath, C{end});
            
                trainLabelDir = sprintf('%s Labels', trainDataDir);

                obj = cOctUnet(trainDataDir, trainLabelDir, gTruth.LabelDefinitions.Name);
                return;
            end
            
            
            len = length(gTruth.DataSource.Source);

            %-- 1. Make a dir, and a dir for Labels
            aFile = gTruth.DataSource.Source{1};
            [path, ~, ~] = fileparts(aFile);
            
            C = strsplit(path, '\');
            
            destPath = '\Matlab_Works\2020-05 OCT';
            destPath = sprintf('%s\\%s', destPath, C{end});
            
            flag = exist(destPath, 'dir');
            if flag ~= 7
                mkdir(destPath);
            end
            
            %-- 2 copy source images
            if flagSlientMode == false
                destTiffNames = cell(1, len);
                for i = 1:len
                    aFile = gTruth.DataSource.Source{i};
                    [~, fileName, ext] = fileparts(aFile);

                    destTiffNames{i} = fullfile(destPath, sprintf('%s%s', fileName, ext));
                    copyfile( aFile, destTiffNames{i});
                end
            end
            
            %-- 3. Make a dir for labels
            destPath = sprintf('%s Labels', destPath);
            
            flag = exist(destPath, 'dir');
            if flag ~= 7
                mkdir(destPath);
            end
            
            %-- 4 copy label files (and MAYBE NOT!!! add 1 on top of it)
            if flagSlientMode == false
                for i = 1:len
                    aFile = gTruth.LabelData.PixelLabelData{i};
                    [~, fileName, ~] = fileparts(destTiffNames{i});

                    newFileName  = strrep(fileName, '_s', '_Label_');

                    bFile = fullfile(destPath, sprintf('%s.png', newFileName));
                    copyfile(aFile, bFile);

    %                 f = imread(aFile);
    %                 f = f + 1;
    %                 imwrite(f, bFile);

                end
            end
            
            aFile = gTruth.DataSource.Source{1};
            [trainDataDir, ~, ~] = fileparts(aFile);                

            aFile = gTruth.LabelData.PixelLabelData{1};
            [trainLabelDir, ~, ~] = fileparts(aFile);                
            
            obj = cOctUnet(trainDataDir, trainLabelDir, gTruth.LabelDefinitions.Name);
        end
        
    end
end





    
