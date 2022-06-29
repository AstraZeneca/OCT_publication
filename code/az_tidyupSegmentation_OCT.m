function [segmentedImage,overlayed] = az_tidyupSegmentation_OCT(rawImage, f, thickness)
    
    maxSizeToIgnore = 1000;
    [m, n] = size(rawImage);

    
    if nargin <= 2 || isempty(thickness)
        thickness = 220; %-- 220 pixels == 1 mm in depth
    end
    
    if nargin <= 1
        f = zeros(m, n);
    end

    %%__________________________________________
    %
    % Reassign the labels for median filter
    %__________________________________________
    %%
    aLabelImage = zeros(size(rawImage));
    aLabelImage(rawImage == 2) = 0;             %-- Background
    aLabelImage(rawImage == 5) = 0;             %-- Blood to be treated as background
    aLabelImage(rawImage == 7) = 1;             %-- dry Clot
    
    aLabelImage(rawImage == 1) = 2;             %-- Normal tissue
    
    aLabelImage(rawImage == 6) = 3;             %-- NewEpidermis
    aLabelImage(rawImage == 3) = 4;             %-- sponge
    aLabelImage(rawImage == 4) = 5;             %-- Collagen
    aLabelImage = medfilt2(aLabelImage,[11,11]);

    %%__________________________________________
    %
    % 1. This is the chunck of the tissue and the tissueBand
    %__________________________________________
    %%
    bwNormal = aLabelImage ~= 0;
    
    bwDark = bwNormal;
    bwDark(1:uint16(m*2/3), 1:end) = true;
    
    bwNormal(bwDark==false) = true;
    bwNormal = imfill(bwNormal, 'holes');
    bwNormal = bwareafilt(bwNormal, 1);

    se = strel('disk', 5);
    bwNormal = imopen(bwNormal, se);
    bwNormal = imclose(bwNormal, se);

    
    bwNormal = padarray(bwNormal, [20 20], 'replicate', 'both'); 

    bwNormal = az_fourierDesp(bwNormal, 0.05);            
    bwNormal = bwareafilt(bwNormal, 1);
  
    bwTissue = bwNormal(21:end-20, 21:end-20);

    bwTissue2 = imtranslate(bwTissue, [0, thickness]);
    bwTissueBand = bwTissue == true & bwTissue2 == false;

    %%__________________________________________
    %
    % 4. This is the total non-intact tissue
    %__________________________________________
    %%
    bwNonIntact = aLabelImage == 1 |...
                  aLabelImage == 3 |...
                  aLabelImage == 4 |...
                  aLabelImage == 5;

    se = strel('disk', 5);
    bwNonIntact = imclose(bwNonIntact, se);
    bwNonIntact = imopen(bwNonIntact, se);

    bwNonIntact = imfill(bwNonIntact, 'holes');

    bwNonIntact = bwNonIntact & bwTissue;
    
    residure = bwTissue == true & bwNonIntact == false;
    bwToAdd = bwareafilt(residure, [1, maxSizeToIgnore]);
    bwNonIntact = bwNonIntact | bwToAdd;
    
    bwNonIntact = bwareafilt(bwNonIntact, [10000, m*n]);

    %%__________________________________________
    %
    % 5 Asign labels to small, isolated pixels.
    %__________________________________________
    %%
    
    %-- bwNotAssigned is the pixels not belong to any non-intact class
    segmentedImage = aLabelImage;
    segmentedImage(bwNonIntact == false) = 0;
    bwNotAssigned = aLabelImage ~= 1 & ...
                    aLabelImage ~= 3 & ...
                    aLabelImage ~= 4 & ...
                    aLabelImage ~= 5 & ...
                    bwNonIntact == 1;

                
    %-- aSmallAreaMask is small regions of non-intact class
    aLabelMat = aLabelImage;
    aLabelMat(bwNonIntact==0)=0;
    
    aSmallAreaMask = zeros(size(aLabelImage));
    INDEX = [1 3 4 5];
    for i = 1:length(INDEX)
        aMask = aLabelMat == INDEX(i);
        aMask = bwareafilt(aMask, [0 maxSizeToIgnore-1]);
        aSmallAreaMask = aSmallAreaMask | aMask;
    end
    
    %-- this the mask of all the pixels need to be reassigned
    jointMask = bwNotAssigned == 1 | aSmallAreaMask == 1;
    [x, y] = find(jointMask == 1);

    %==============
    bwAssigned = bwNonIntact == 1 & jointMask == 0;
    [X, Y] = find(bwAssigned == 1);
    
    
    Mdl = KDTreeSearcher([X, Y]);
    
    
    theLabel = zeros(1, length(x));
    for j = 1:length(x)
    
        aNewPoint = [x(j), y(j)];
        [n,~] = knnsearch(Mdl,aNewPoint, 'k', 10);

        label10 = zeros(1, 10);
        for i = 1:10
            label10(i) = aLabelImage(X(n(i)), Y(n(i)));
        end
        tbl = tabulate(label10);

        [~, index] = max(tbl(:, end));
        theLabel(j) = tbl(index, 1);
    end
        
    for i = 1:length(x)
        segmentedImage(x(i), y(i)) = theLabel(i);
    end    

    segmentedImage((segmentedImage ~= 1 & ...
                    segmentedImage ~= 3 & ...
                    segmentedImage ~= 4 & ...
                    segmentedImage ~= 5) & ...
                   bwTissue == 1) = 6;
    
    segmentedImage(bwTissueBand == false) = 0;
               
    segmentedImage = uint8(segmentedImage);

    map = [1, 0, 1;...
           0.5, 0.7, 0.3;...
           1, 0, 0;...
           0, 1, 0;...
           1, 1, 0;...
           0, 0, 1];

    overlayed = labeloverlay(f,segmentedImage,'Transparency',0.8, 'Colormap', map);
    overlayed = imoverlay(overlayed, bwperim(bwTissueBand), [255, 255, 255], 2);
    overlayed = imoverlay(overlayed, bwperim(segmentedImage == 1), [255, 0, 255], 2);
    overlayed = imoverlay(overlayed, bwperim(segmentedImage == 3), [255, 0, 0], 2);
    overlayed = imoverlay(overlayed, bwperim(segmentedImage == 4), [0 255 0], 2);
    overlayed = imoverlay(overlayed, bwperim(segmentedImage == 5), [255, 255, 0], 2);
end