
    rootFolder = 'C:\tests';

    %-- load class labels
    A = load(fullfile(rootFolder, 'gTruth.mat'));
    obj = cOctUnet.setupTrainingData(A.gTruth);
    
    %-- load the trained u-net network
    T = load(fullfile(rootFolder, 'Unet model.mat'));
    obj.loadNet(T.net);

    %-- to test a single image, please run e.g. 
    aFileName = sprintf('%s/testImages/1.tif', rootFolder);
    obj.testAnImage(aFileName);

    %-- to run batch processing, please run:
    %you need to setup the property of PredictDataDir, PredictResultDir
    %within the cOctUnet class to be the path on your computer
    obj.segment();
    obj.runAnalysis();
