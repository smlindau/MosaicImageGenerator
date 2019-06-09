function generateMosaicImage()

%% Main Image Choice
disp('Choose main mosaic image...');
[mainImageName,mainImagePath] = uigetfile({'*.png;*.jpg'});
% Normalize the image from 0 to 1 and change type to double
mainImage = getNormalized(double(imread(fullfile(mainImagePath,...
    mainImageName))));
[mainRows,mainCols,mainColors] = size(mainImage);
pixelArea = mainRows*mainCols;

%% Mosaic Image Directory Choice
disp('Choose directory of mosaic images...');
mosaicImagesPath = uigetdir;
imageJpgDir = dir(fullfile(mosaicImagesPath,'*.jpg'));
imagePngDir = dir(fullfile(mosaicImagesPath,'*.png'));
% Determine the number of images in the directory
numMosaicImages = size(imageJpgDir,1)+size(imagePngDir,1);
% Set the size of each small image based on the number of images and the size of the original image
mosaicSquareSize = floor(sqrt(pixelArea/numMosaicImages));
% Initialize the image stack in RGB
imageStack = zeros(mosaicSquareSize,mosaicSquareSize,3*numMosaicImages);
imageStackRGB = zeros(3,numMosaicImages);

%% Create Mosaic Grid
% Grid the initial image to fit all of the smaller images
wholeBlockRows = floor(mainRows / mosaicSquareSize);
blockVectorR = mosaicSquareSize * ones(1, wholeBlockRows);
wholeBlockCols = floor(mainCols / mosaicSquareSize);
blockVectorC = mosaicSquareSize * ones(1, wholeBlockCols);
% Crop main image to remove any excess space not covered by smaller images
cropMainImage = mainImage(1:end-mod(mainRows,mosaicSquareSize),...
    1:end-mod(mainCols,mosaicSquareSize),:);
cellArray = mat2cell(cropMainImage,blockVectorR,blockVectorC,mainColors);
cellArrayRGB = cellfun(@meanRGB,cellArray,'UniformOutPut',0);

%% Resize Mosaic Images
% Each mosaic image needs to be the same size, so this loops through all images to resize them
for i = 1:numMosaicImages
    if i <= size(imageJpgDir,1)
        oversizedImage = getNormalized(double(imread(fullfile(...
            mosaicImagesPath,imageJpgDir(i).name))));
        [shortSide,indShortSide] = min([size(oversizedImage,1);...
            size(oversizedImage,2)]);
        [longSide,~] = max([size(oversizedImage,1);...
            size(oversizedImage,2)]);
        cropStart = longSide - shortSide; 
        oversizedCrop = round(cropStart/2):longSide-round(cropStart/2);
        if length(oversizedCrop) == shortSide - 1
            oversizedCrop = round(cropStart/2):...
                longSide-round(cropStart/2) + 1;
        elseif length(oversizedCrop) == shortSide - 2
            oversizedCrop = round(cropStart/2) - 1:...
                longSide-round(cropStart/2) + 1;
        elseif length(oversizedCrop) == shortSide + 1
            oversizedCrop = round(cropStart/2):...
                longSide-round(cropStart/2) - 1;
        elseif length(oversizedCrop) == shortSide + 2
            oversizedCrop = round(cropStart/2) + 1:...
                longSide-round(cropStart/2) - 1;
        end
        if shortSide == longSide
            cropImage = oversizedImage;
        elseif indShortSide == 1
            cropImage = oversizedImage(:,oversizedCrop,:);
        else
            cropImage = oversizedImage(oversizedCrop,:,:);            
        end
        resizedImage = imresize(cropImage,...
            [mosaicSquareSize,mosaicSquareSize]);
        imageStackRGB(:,i) = meanRGB(resizedImage);        
        imageStack(:,:,3*i-2:3*i) = resizedImage;
    else
        oversizedImage = getNormalized(double(imread(fullfile(...
            mosaicImagesPath,imagePngDir(i-size(imageJpgDir,1)).name))));
        [shortSide,indShortSide] = min([size(oversizedImage,1);...
            size(oversizedImage,2)]);
        [longSide,~] = max([size(oversizedImage,1);...
            size(oversizedImage,2)]);
        cropStart = longSide - shortSide; 
        oversizedCrop = round(cropStart/2):longSide-round(cropStart/2);
        if length(oversizedCrop) == shortSide - 1
            oversizedCrop = round(cropStart/2):...
                longSide-round(cropStart/2) + 1;
        elseif length(oversizedCrop) == shortSide - 2
            oversizedCrop = round(cropStart/2) - 1:...
                longSide-round(cropStart/2) + 1;
        elseif length(oversizedCrop) == shortSide + 1
            oversizedCrop = round(cropStart/2):...
                longSide-round(cropStart/2) - 1;
        elseif length(oversizedCrop) == shortSide + 2
            oversizedCrop = round(cropStart/2) + 1:...
                longSide-round(cropStart/2) - 1;
        end
        if indShortSide == 1
            cropImage = oversizedImage(:,oversizedCrop,:);
        else
            cropImage = oversizedImage(oversizedCrop,:,:);            
        end
        resizedImage = imresize(cropImage,...
            [mosaicSquareSize,mosaicSquareSize]);
        imageStackRGB(:,i) = meanRGB(resizedImage);
        imageStack(:,:,3*i-2:3*i) = resizedImage;        
    end
    disp(strcat(num2str(i),'/',num2str(numMosaicImages)))
end

%% Find Closest RGB Cell
% For each mosaic image, compare their RGB values and assign a location
[cellRow,cellCol] = size(cellArrayRGB);
mosaicImageUse(numMosaicImages) = struct('Index',[],'InUse',[],'Cell',[]);
for i = 1:numMosaicImages
    mosaicImageUse(i).Index = i;
    mosaicImageUse(i).InUse = 0;
end
for i = 1:cellRow
    for j = 1:cellCol
        distArray = computeDist(imageStackRGB,cellArrayRGB{i,j});
        [~,distInd] = sort(distArray,'Ascend');
        holdStruct = mosaicImageUse(distInd);
        imageInd = find([holdStruct.InUse]==0,1,'First');
        mosaicImageUse(distInd(imageInd)).InUse = 1;
        mosaicImageUse(distInd(imageInd)).Cell = [i,j];
    end
end

%% Assign Transparent Imaging
mosaicCell = cell(size(cellArray));
overlay = .4;
underlay = .6;
for i = 1:numMosaicImages
    if mosaicImageUse(i).InUse
        p = mosaicImageUse(i).Cell(1);
        q = mosaicImageUse(i).Cell(2);
        underImage = cellArray{p,q};
        overImage = imageStack(:,:,3*i-2:3*i);
        mosaicCell{p,q} = overlay*overImage + underlay*underImage; 
    end
end
imshow(cell2mat(mosaicCell))

%% Anonymous Functions
    function B = meanRGB(A)
        B(:,1) = mean(mean(A(:,:,1)));
        B(:,2) = mean(mean(A(:,:,2)));
        B(:,3) = mean(mean(A(:,:,3)));
    end
    function C = computeDist(A,B)
        C = sqrt((A(1,:)-B(:,1)).^2+(A(2,:)-B(:,2)).^2+...
            (A(3,:)-B(:,3)).^2);
    end
end
