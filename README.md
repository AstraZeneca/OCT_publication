![Maturity level-1](https://img.shields.io/badge/Maturity%20Level-ML--1-yellow)

# U-net model for analysing OCT image.

This repository contains the source code for the image analysis of optical coherence tomography images, as stated in the publication of **Volumetric wound healing by machine learning and optical coherence tomography in type 2 diabetes**. 


**AUTHORS**

Yinhai Wang	<sup>1</sup>, Adrian Freeman<sup>2</sup>, Ramzi Ajjan<sup>3</sup>, Francesco Del Galdo<sup>*4,5</sup>, and Ana Tiganescu<sup>*3</sup>

**AFFILIATIONS**

<sup>1</sup>Data Sciences & Quantitative Biology, Discovery Sciences, BioPharmaceuticals R&D, AstraZeneca, Cambridge, UK; 

<sup>2</sup>Emerging Innovations Unit, Discovery Sciences, BioPharmaceuticals R&D, AstraZeneca, Cambridge, UK; 

<sup>3</sup>Leeds Institute of Cardiovascular and Metabolic Medicine, University of Leeds, Leeds, UK; 

<sup>4</sup>NIHR Biomedical Research Centre, Leeds Teaching Hospitals NHS Trust, Leeds, UK; 

<sup>5</sup>Leeds Institute of Rheumatic and Musculoskeletal Medicine, University of Leeds, Leeds, UK.


a copy of the paper (*pending peer review) can be found here: https://www.medrxiv.org/content/10.1101/2021.03.23.21254200v1.full

--------------------------------------------------------------------------------
**What it contains**


1. All source code are in the \code folder.
2. Some test images (2D gray scale images) are in the \testImages folder.
3. A pretained u-net model is in the root folder, named "Unet model.mat".

--------------------------------------------------------------------------------
**Software requirements**


this package was developed using Matlab 2019b. this code repository should contain all the dependecies it required, no additional packages are required. 

Four functions are from "Oliver Woodford (2022). real2rgb & colormaps (https://www.mathworks.com/matlabcentral/fileexchange/23342-real2rgb-colormaps)" package. These files are included in the repository, which are: colormap_helper, summer, rescale and real2rgb.  They are used but not checked nor modified. 

All code are fully checked and passed the checkcode(), the Matlab equivlant of lint. The exception is that there are two occurances of the warning messages that variables "change size on every loop iteration. Consider preallocating for speed.". They are not bugs and the loop counter is small, therefore the speed of the code was not impacted in a noticable way. These were not further fixed.

--------------------------------------------------------------------------------
**How to run**

To test the image analysis of an OCT image, please follow the steps in **code\toPredict.m** 
    
    %-- define a folder on your local computer where you git cloned the repository
    rootFolder = 'C:\Matlab_Works\testOct';

    %-- load class labels, which is stored in the 'gTruth.mat' file
    A = load(fullfile(rootFolder, 'gTruth.mat'));
    obj = cOctUnet.setupTrainingData(A.gTruth);
    
    %-- load the trained u-net network which is stored in the 'Unet model.mat' file
    T = load(fullfile(rootFolder, 'Unet model.mat'));
    obj.loadNet(T.net);

    %-- to test a single image, please run e.g. 
    aFileName = sprintf('%s/testImages/1.tif', rootFolder);
    obj.testAnImage(aFileName);
