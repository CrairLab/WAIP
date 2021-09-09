%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Wave Analysis Integrated Pipeline (WAIP) - Beta Version 0.0.3 (09/07/21)%    
% Author: Yixiang Wang. Email: yixiang.wang@yale.edu                      %
% Integrating wave analysis code from Xinxin Ge. For running on the HPC   %
% Adapted from github.com/GXinxin/SC-Cortical-activity-detection          %
% With substantial modifications to interface with Yixang_OOP_pipeline    %
% Estimate optical flow using Lucas-Kanade  method (opticalFlowLK)        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Generate binary movies based on different thresholds %%%%%%%%%%%%%%%%%%%
% Be aware that this pipeline is only compatible with pre-processed movies
% generated by Yixiang_OOP_pipeline
% Ref: https://github.com/CrairLab/Yixiang_OOP_pipeline
% This section is mostly adapted from testThreshold_010617.m (Xinxin Ge) 
% See original code at github.com/GXinxin/SC-Cortical-activity-detection
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Get the number of movies, subject to change when run on HPC
if isempty(dir(('files.txt')))
    Integration.fileDetector()
end
filelist = readtext('files.txt',' ');
nmov = size(filelist,1); %# of movies
root_dir = cd; %record the root directory
    
parfor n = 1:nmov
  
    %Read in the current movie
    movTag = 'filtered';
    [curLoad, outputFolder, filename]  = Integration.readInSingleMatrix(movTag, n);
    imgall = curLoad.A_dFoF;
    sz = size(imgall);
    cd(outputFolder); %relocate to subfolders

    %Get disconnected rois from the loaded movie
    roi = getRoiFromMovie(curLoad.A_dFoF);
    %clear curLoad

    %Define threshold levels 
    th = [1 1.5 2 3 5];

    %Iterate over various threshold levels
    for t = 1:length(th)

        %Get the current threshold
        thresh = th(t);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Segmentation
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        dura_th = 8; % duration threshold (in frames)
        dia_th = 8; % diameter threshold (in pixels)
        wave_flag = 0; % do wave property analysis or not
        
        %Binarize and filter the movie, wave analysis optional
        [total_ActiveMovie, ~] = ...
            binarize_filter(imgall, thresh, roi, filename, wave_flag, ...
            dura_th, dia_th);
      
        %Binarize filter movies 
        total_ActiveMovie = total_ActiveMovie > 0;
        
        %Construct frames for the output binary movie
        [I2, map2] = gray2ind(total_ActiveMovie(:,:,1), 8);
        F = im2frame(I2, map2);
        for fr = 1:sz(3)
            [I2, map2] = gray2ind(total_ActiveMovie(:,:,fr), 8); 
            F(fr) = im2frame(I2,map2);  %setup the binary segmented mask movie
        end
        binaryName = [filename(1:end-4), '_mask_th', num2str(thresh), '.avi'];
        
        %Write the movie
        writeMovie_xx(F, binaryName, 0);

    end
    %Back to the root directory
    cd(root_dir)
end

% Select the optimal threshold level, make a threshold list, and write the
% list to a .txt file with corresponding filenames

% Whether the script is running on the HPC

if contains(root_dir, 'gpfs')
    th_set = 2; % Change in the future, to allow customized input
else
    th_set = input('Please input the threshold level you pick for this animal:');
end

% Apply same thresholds to all movies unless specified otherwise
th_list = ones(nmov, 1).*th_set;
fileID = fopen('files_wave.txt','wt');
for n = 1:nmov
    formatSpec = [filelist{n, 1} ' %3.1f \n'];
    fprintf(fileID, formatSpec, th_list(n));
end

% End of section



%% Wave property analysis (the meat). 
% Adapted from waveProperty_SC_regressed_selectSVD_020617.m (Xinxin Ge)
% See original code at https://github.com/GXinxin/SC-Cortical-activity-detection


if isempty(dir(('files.txt')))
    Integration.fileDetector()
end
filelist = readtext('files.txt',' ');
nmov = size(filelist,1); %# of movies
root_dir = cd; %record the root directory


th_set = 1.5;

% Apply same thresholds to all movies unless specified otherwise
th_list = ones(nmov, 1).*th_set;
fileID = fopen('files_wave.txt','wt');
for n = 1:nmov
    formatSpec = [filelist{n, 1} ' %3.1f \n'];
    fprintf(fileID, formatSpec, th_list(n));
end

% Read filenames and thresholds 
filelist = readtext('files_wave.txt', ' ');
fnms = filelist(:, 1);
thresh = filelist(:, 2);
nmov = size(filelist,1);
root_dir = cd; % record the root directory
rp_total = {}; % a holder to store all regionprop structs from different movies
    
parfor n = 1:nmov
    %Read in the current movie
    movTag = 'filtered';
    [curLoad, outputFolder, filename]  = Integration.readInSingleMatrix(movTag, n);
    disp(['Working on folder #' num2str(n)])
    fnm = filename;
    cd(outputFolder);
    
    %curLoad.A_dFoF = reshape(curLoad.dA, [256, 250, 1200]);
    
    %Get disconnected rois from the loaded movie
    roi = getRoiFromMovie(curLoad.A_dFoF);
    
    %Z-score the current movie
    A_z = z_reshape(curLoad.A_dFoF);
    sz = size(A_z);
    %clear curLoad
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % compute flow field
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
    smallSize = 0.5; % downSample the flowfield size
    imgall = reshape(A_z, sz(1), sz(2), sz(3));    
    
    %Computes optic flow field (with normalized vectors) for imgall
    %[normVx, normVy] = computeFlowField_normalized_xx(imgall, sz, smallSize);
    [normVx, normVy] = computeFlowField_normalized(imgall, sz, smallSize);
    totalMask = ~isnan(A_z(:,:,1));
    smallMask = imresize(totalMask, smallSize, 'bilinear');
    %clear A_z;
    
    %Plot the optic flow field 
    h = figure; imagesc(smallMask); hold on
    quiver(mean(normVx, 3).*smallMask, mean(normVy, 3).*smallMask); axis image;
    title(fnm(1:end-4))
    set(h, 'Position', [0, 0, 1200, 900]);
    h.PaperPositionMode = 'auto';
    print([fnm(1:end-4), '_quiver'], '-dpng', '-r0')
    
    %Plot the optic flow field (further downsampled)
    h = figure; imagesc(imresize(smallMask, .5, 'bilinear')); hold on
    quiver(imresize(mean(normVx, 3), .5, 'bilinear') .* imresize(smallMask, .5, 'bilinear'), ...
        imresize(mean(normVy, 3), .5, 'bilinear') .* imresize(smallMask, .5, 'bilinear'));
    axis image;
    title(fnm(1:end-4))
    set(h, 'Position', [0, 0, 1200, 900]);
    h.PaperPositionMode = 'auto';
    print([fnm(1:end-4), '_quiver_s'], '-dpng', '-r0')
    
    %Binarize, filter, and do wave analysis on the input movie
    wave_flag = 1; % turn on wave analysis
    dura_th = 8;
    dia_th = 8;
    [total_ActiveMovie, rp] = ...
    binarize_filter(imgall, thresh{n}, roi, filename, wave_flag, ...
    dura_th, dia_th);

    %Create segmented movie     
    total_ActiveMovie = total_ActiveMovie > 0;
    [I2, map2] = gray2ind(total_ActiveMovie(:,:,1), 8);
    F = im2frame(I2, map2);
    for fr = 1:sz(3)
        [I2, map2] = gray2ind(total_ActiveMovie(:,:,fr), 8); %figure; imshow(I2,map)
        F(fr) = im2frame(I2,map2);  %setup the binary segmented mask movie
    end
    fnm3 = [fnm(1:end-4), '_mask_th', num2str(thresh{n}), '.avi'];
    writeMovie_xx(F, fnm3, 0); %output the constructed movie
    
    %Downsample
    total_ActiveMovie = imresize(total_ActiveMovie, .5, 'bilinear');
    
    %Get wave properties (angle, rho, vector matrices)
    angle = rp.angle;
    RHO = rp.RHO;
    %total_AVx = rp.total_AVx;
    %total_AVy = rp.total_AVy;
    
    %Save opticflow properties for this movie
    %save([fnm(1:end-4), '_opticFlow.mat'], 'fnms', 'angle', 'normVx', 'normVy', 'RHO', ...
    %    'total_ActiveMovie', '-v7.3');
    
    %clear normVx normVy total_ActiveMovie
    
    %Get more opticflow properties
    validId = rp.validId;
    durations = rp.durations ;
    diameters = rp.diameters ;
    roiCentr = rp.roiCentr ;
    roiArea = rp.roiArea;
    boundBox = rp.boundBox;
    valid = rp.valid;
    pixel = rp.pixel;
 
    p_Interval1 = rp.p_Interval1;
    m_Interval1 = rp.m_Interval1;
    m_p_Duration = rp.m_p_Duration;
    
    %Save all opticflow properties as a data summary file
    %save([fnm(1:end-4), '_dataSummary.mat'], 'fnms', 'p_Interval1', 'm_Interval1', ...
    %'validId', 'durations', 'diameters', 'roiCentr', 'roiArea', 'angle', 'RHO', 'm_p_Duration', 'boundBox', 'pixel', '-v7.3');
    
    %Store the regionprop struct (opticflow properties) 
    rp_total{n} = rp;
    
    %Go back to root directory
    cd(root_dir)
end

%Save the summary data for this animal
tmp = fullfile('a','b');
tmp = tmp(2); %a trick to detect whether '\' or '/' is used in paths
foldername = root_dir(max(find(root_dir == tmp))+1:end); %Get the animal information/ foler name
disp(['Processing at ' foldername ' is done!'])
save([foldername, '_dataSummary.mat'], 'fnms', 'rp_total', '-v7.3');






%% Reused functions

function A_z = z_reshape(A)
% Z-score input movie A (3D)
% Input:
%    A   3D dFoF movie
% Output:
%    A_z z-scored 3D movie

    sz = size(A);
    A_z = reshape(A, sz(1) * sz(2), sz(3));
    A_z = zscore(A_z')';
    A_z = reshape(A_z, sz);

end

function roi = getRoiFromMovie(A)
% Get disconnected rois from the input movie output individual rois
% Input:
%    A    3D dFoF movie
%    roi  non-overlapping roi fields 

    %Binarize the first frame of the input movie
    A1 = A(:, :, 1);
    sz = size(A1);
    if any(isnan(A1(:)))
        B1 = ~isnan(A1);
    else
        B1 = ~(A1 == 0);
    end
    
    %Get connected componets from frame1
    C1 = bwconncomp(B1);
    
    %Construct the cell array of differnt rois
    n_roi = size(C1.PixelIdxList, 2);
    for i = 1 : n_roi
        cur_roi = zeros(sz);
        cur_roi(C1.PixelIdxList{i}) = 1;
        roi{i} = cur_roi;   
    end
    
end


function [total_ActiveMovie, rp] = ...
    binarize_filter(imgall, thresh, roi, fnm, wave_flag, dura_th, dia_th)
% Binarize the input movie per the threshold, filter the binary movie
% based on connected component analysis, output the reconstructed movie
% Input: 
%   imgall        Preprocessed movie
%   thresh        threshold
%   roi           a cell array of disconnected rois
%   fnm           filename
%   wave_flag     whether analyze wave properties
%   dura_th       duration threshold for filtering
%   dia_th        diameter threshold for filtering
%
% Output:
%   total_ActiveMovie   reconstructed/ filtered binary movie
%   rp                  regionprop struct containing opticflow properties

    
    if nargin < 5
        dura_th = 8;
        dia_th = 8;
    end
    
    %Initialization (placeholders)
    total_ActiveMovie = [];
    %total_AVx = [];
    %total_AVy = [];
    angle = [];
    RHO = [];
    p_Interval1 = [];
    m_Interval1 = [];
    m_p_Duration = [];
        
    n =1; %Only analyze the current movie, keep format consistent
    frameRate = 10; %Note that this could be an issue if frame rate differs
    
    sz = size(imgall);
    
    % Get the total mask combining all rois
    totalMask = zeros(size(roi{1}));
    for r = 1:length(roi)
        totalMask = totalMask + roi{r};
    end
        
    for r = 1:length(roi)
        
        savefn = [fnm(1:end-4), '_', num2str(r)];
        
        if r == length(roi) + 1
            maskMatrix = totalMask;
        else
            maskMatrix = roi{r};
        end

        maskId = find(maskMatrix > 0);
        maskMatrix = reshape(maskMatrix, sz(1)*sz(2), 1);
        maskMatrix = repmat(maskMatrix, 1, sz(3));
        maskMatrix = reshape(maskMatrix, sz(1), sz(2), sz(3)); 
        
        %Apply the total mask
        imgall = reshape(imgall, sz(1), sz(2), sz(3));
        subMov = imgall .* maskMatrix;

        %Zscore
        subMov = reshape(subMov, sz(1) * sz(2), sz(3));
        temp_subMov = subMov(maskId, :);
        temp_subMov = zscore(temp_subMov');
        temp_subMov = temp_subMov';
        subMov = zeros(size(subMov));
        subMov(maskId, :) = temp_subMov;

        %Binarization
        activeMov = subMov > thresh;
        subMov = reshape(subMov, sz(1), sz(2), sz(3));
        activeMov = reshape(activeMov,sz(1), sz(2), sz(3));

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % detect connected components
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %Get connected components  
        CC = bwconncomp(activeMov);
        
        %Get regional properties
        STATS = regionprops(CC, activeMov, 'Area', 'BoundingBox', 'Centroid', 'PixelList');      

        %Compute duration, diameter, area and centroid
        roiBoundingBox = zeros(length(STATS),6);

        for i = 1:length(STATS)
            roiBoundingBox(i, :) = STATS(i).BoundingBox;
        end

        dura = roiBoundingBox(:,6); 
        dia = mean([roiBoundingBox(:,4) roiBoundingBox(:,5)], 2);
        area = vertcat(STATS.Area);
        
        %Save all properties
        validId{r, n} = (dura > dura_th & dia > dia_th); 
        durations{r, n} = dura(validId{r, n});
        diameters{r, n} = dia(validId{r, n});
        roiCentr{r, n} = vertcat(STATS(validId{r, n}).Centroid);
        roiArea{r, n} = [STATS(validId{r, n}).Area];  
        boundBox{r, n} = [STATS(validId{r, n}).BoundingBox];
        valid_tmp = find(validId{r, n} > 0);
        
        for v = 1:length(valid_tmp)
            pixel{r, n}{v} = STATS(valid_tmp(v)).PixelList;
        end
        
        valid{r, n} = valid_tmp;
        
        
        %Reconstruct binary mov based on valid connected components
        valid_mov = subMov;
        valid_activeMov{r} = activeMov;
        badId = find(validId{r, n} == 0);
        for id = 1:length(badId)
            removePixel = CC.PixelIdxList{badId(id)};
            valid_mov(removePixel) = 0;
            valid_activeMov{r}(removePixel) = 0;
        end

        %valid_activeMov_down = imresize(valid_activeMov{r}, 0.25, 'bilinear');
        %tmpsz = size(valid_activeMov_down);
        %valid_activeMov_down = reshape(valid_activeMov_down, tmpsz(1)*tmpsz(2), tmpsz(3));

        if r == 1
            total_ActiveMovie = valid_activeMov{r};
        else
            total_ActiveMovie = total_ActiveMovie + valid_activeMov{r};
        end
        
        %Do wave property analysis
        if wave_flag
            
            %Compute flow field (without normalization)
            %[AVx, AVy] = computeFlowField_xx(imgall, sz);
            [AVx, AVy] = computeFlowField(imgall, sz);
            nDomains = sum(validId{r, n});
            validDomains = CC.PixelIdxList(validId{r, n});
            theta = []; rho = [];
            %Go through each domain and transform Cartesian coordinates to polar or cylindrical
            for k = 1:nDomains
                p_id = intersect(1 : sz(1)*sz(2)*size(AVx, 3), validDomains{k});
                [theta(k), rho(k)]= cart2pol(sum(AVx(p_id)), sum(AVy(p_id))); %transformation
            end

            %AVx = imresize(AVx, .5, 'bilinear');
            %AVy = imresize(AVy, .5, 'bilinear');
 
            %Record all vectors
            %if isempty(total_AVx)
            %    total_AVx = AVx;
            %    total_AVy = AVy;
            %else
            %    total_AVx = total_AVx + AVx;
            %    total_AVy = total_AVy + AVy;
            %end
            clear AVx AVy
            
            angle{r, n} = theta;
            RHO{r, n} = rho;
        
            h = figure; rose(angle{r, n});
            set(gca,'YDir','reverse'); % 90 degree is moving downwards
            title(savefn);
            saveas(h, [savefn, '_rosePlot.png'])
            
            %Plot durations and diameters of detected components
            savefn2 = [savefn, num2str(thresh)];            
            h(1) = figure; hist(durations{r, n}, 50); xlabel('durations (frames)'); title(['thresh=', num2str(thresh)])
            saveas(h(1), [savefn2, '_durations.png'])
            h(2) = figure; hist(diameters{r, n}, 50); xlabel('diameters (pixels)'); title(['thresh=', num2str(thresh)])
            saveas(h(2), [savefn2, '_diameters.png'])
            h(3) = figure; scatter(durations{r, n}, diameters{r, n}); xlabel('durations'); ylabel('diameters'); title(['thresh=', num2str(thresh)])
            saveas(h(3), [savefn2, '_duraVSdia.png'])
            
            %Reconstruct binary mov based on valid connected components
            valid_mov = subMov;
            valid_activeMov{r} = activeMov;
            clear activeMov subMov
            
            %Find noise
            badId = find(validId{r, n} == 0);
            for id = 1:length(badId)
                removePixel = CC.PixelIdxList{badId(id)};
                valid_mov(removePixel) = 0;
                valid_activeMov{r}(removePixel) = 0;
            end

            valid_activeMov_down{r} = imresize(valid_activeMov{r}, 0.5, 'bilinear');
            tmpsz = size(valid_activeMov_down{r});
            valid_activeMov_down{r} = reshape(valid_activeMov_down{r}, tmpsz(1)*tmpsz(2), tmpsz(3));
            
            %Combine differ rois
            if isempty(total_ActiveMovie)
                total_ActiveMovie = valid_activeMov{r};
            else
                total_ActiveMovie = total_ActiveMovie + valid_activeMov{r};
            end


            % compute active duration and event interval   
            for p = 1:tmpsz(1)*tmpsz(2)
                activeOn{p} = find(valid_activeMov_down{r}(p, 2:end) - valid_activeMov_down{r}(p, 1:end-1) > 0) + 1;
                activeOff{p} = find(valid_activeMov_down{r}(p, 2:end) - valid_activeMov_down{r}(p, 1:end-1) < 0);

                if (isempty(activeOn{p}) + isempty(activeOff{p})) == 1

                    activeOn{p} = [];
                    activeOff{p} = [];

                elseif (isempty(activeOn{p}) + isempty(activeOff{p})) == 0

                    if activeOn{p}(1) > activeOff{p}(1)
                        activeOff{p} = activeOff{p}(2:end);
                    end

                    if activeOn{p}(end) > activeOff{p}(end)
                        activeOn{p} = activeOn{p}(1:end-1);
                    end
                end

                pixelDuration{p} = activeOff{p} - activeOn{p};
 
                goodId = pixelDuration{p} > 2;
                activeOn{p} = activeOn{p}(goodId);
                activeOff{p} = activeOff{p}(goodId);
                pixelDuration{p} = pixelDuration{p}(goodId);
                meanDuration(p) = sum(pixelDuration{p}) / sz(3);

                %Interval: from end of one event to the beginning of the following event
                pixelInterval1{p} = activeOn{p}(2:end) - activeOff{p}(1:end-1);
                meanInterval1(p) = mean(pixelInterval1{p});

                %Interval: between the center of each event
                eventCenterTime{p} = activeOff{p} - activeOn{p};
                pixelInterval2{p} = eventCenterTime{p}(2 : end) - eventCenterTime{p}(1 : end-1);
                meanInterval2(p) = mean(pixelInterval2{p});
            end
            
            %Plot event intervals
            p_Interval1{r, n} = pixelInterval1;       
            meanInterval1(isnan(meanInterval1)) = 2000/frameRate;
            meanInterval1 = reshape(meanInterval1, tmpsz(1), tmpsz(2))/frameRate;
            h = figure; imagesc(meanInterval1); colorbar; colormap jet
            caxis([0, 50]); axis image
            title(savefn2);
            saveas(h, [savefn2, '_interval.png']);       

            %Plot mean durations
            meanDuration = reshape(meanDuration, tmpsz(1), tmpsz(2));
            h = figure; imagesc(meanDuration); colorbar; colormap jet
            caxis([0, 0.3]); axis image
            title(savefn2);
            saveas(h, [savefn2, '_duration.png']);

            m_Interval1{r, n} = meanInterval1;
            m_p_Duration{r, n} = meanDuration;

        end
        
    end
    
    clear valid_activeMov imgall
    
    %Record all properteis as a struct
    rp.validId = validId;
    rp.durations = durations;
    rp.diameters = diameters;
    rp.roiCentr = roiCentr;
    rp.roiArea = roiArea;
    rp.boundBox = boundBox;
    rp.valid = valid;
    rp.pixel = pixel;
    rp.angle = angle;
    rp.RHO = RHO;
    %rp.total_AVx = total_AVx;
    %rp.total_AVy = total_AVy;
    rp.p_Interval1 = p_Interval1;
    rp.m_Interval1 = m_Interval1;
    rp.m_p_Duration = m_p_Duration;
       
end





function [AVx, AVy] = computeFlowField(imgall, sz)
% compute flow field 
% Input:
%    imagall   dFoF movie
%    sz        size of the movie
% Output:
%    AVx       matrix of x vectors
%    AVy       matrix of y vectors

opticFlow = opticalFlowLK;
     
    for f = 1:sz(3)-1 %option:parfor
        flow = estimateFlow(opticFlow,imgall(:, :, f));
        AVx(:, :, f) = flow.Vx;
        AVy(:, :, f) = flow.Vy;
    end

    AVx(:, :, sz(3)) = AVx(:, :, end);
    AVy(:, :, sz(3)) = AVy(:, :, end);

end


function [normVx, normVy] = computeFlowField_normalized(imgall, sz, resizeRatio)
% computes optic flow field for imgall, vectors normalized before summing
% up, better for computing the overall directional bias
% Input:
%    imagall   dFoF movie
%    sz        size of the movie
%    resizeRatio    ratio to resize the image
% Output:
%    normVx    normalized x vectors
%    normVy    normalized y vectors

    normVx = [];
    normVy = [];
    opticFlow = opticalFlowLK;
    
    for f = 1:sz(3)
        
        flow = estimateFlow(opticFlow,imgall(:, :, f));
        Vx = flow.Vx;
        Vy = flow.Vy;
        Vx = imresize(Vx, resizeRatio, 'bilinear');
        Vy = imresize(Vy, resizeRatio, 'bilinear');

        % Normalize the lengths of the arrows
        mag = sqrt(Vx.^2 + Vy.^2);
        normVx(:, :, f) = Vx ./ mag;
        normVy(:, :, f) = Vy ./ mag;

        id = mag > 0;
        normVx(:, :, f) = normVx(:, :, f) .* id;
        normVy(:, :, f) = normVy(:, :, f) .* id;
    end

end




function writeMovie_xx(M, filename, useFFmpeg)
%writeMovie - Make avi movie
%PURPOSE -- Make movie video from a colormapped matlab movie structure. Called by Iarr2avi.m and others and used in conjunction with output from timeColorMapProj.m
%USAGE -- 	writeMovie(M, 'filename.avi');
% M - A matlab specific 'movie' data structure
% filename - string, the 'filename.avi' that the data come from and the string from which the output filename will be formatted
%
% See also timeColorMapProj.m, Iarr2montage.m, myMovie2avi.m, Iarr2avi.m
%
%James B. Ackman 2014-12-31 10:46:39
% Xinxin Ge 06/22/16

if nargin < 3 || isempty(useFFmpeg), useFFmpeg = 1; end
if nargin < 2 || isempty(filename), filename = ['movie' datestr(now,'yyyymmdd-HHMMSS') '.avi']; end

disp(['Making ' filename '-----------'])


    if useFFmpeg
            rng('shuffle')
            tmpPath = ['wbDXtmp' num2str(round(rand(1)*1e09))];
            mkdir(tmpPath)

        szZ = numel(M);
        for fr = 1:szZ %option:parfor
            tmpFilename = fullfile(tmpPath, sprintf('img%05d.jpg',fr));
            if isempty(M(fr).colormap)
                imwrite(M(fr).cdata,tmpFilename)
            else
                imwrite(M(fr).cdata,M(fr).colormap,tmpFilename)
            end
        end

        
        filePath = [pwd, '\', tmpPath];
        tic
        disp('ffmpeg running...')
        try
            %System cmd to ffmpeg:
            system(['ffmpeg -f image2 -i ' filePath filesep 'img%05d.jpg -vcodec mjpeg ' filename])
            %The call to ffmpeg can be modified to write something other than a motion jpeg avi video:
            %system('ffmpeg -f image2 -i img%05d.png a.mpg')
            rmdir(tmpPath,'s');
        catch
            rmdir(tmpPath,'s');
            error(errstr);
        end
        toc

    else
        tic
        disp('using video obj...')
        vidObj = VideoWriter(filename);
        open(vidObj);
        for i =1:numel(M)
            writeVideo(vidObj,M(i));
        end
        close(vidObj);
        toc
    end

end