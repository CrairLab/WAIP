% Beta version, combine summary data across animals, yixiang.wang@yale.edu

% Read in paths/ directories from summary_dirs.txt
DirList = readtext('summary_dirs.txt',' ');

nDir = length(DirList);

% Initiation
rp_all = [];
validId = [];
durations = [];
diameters= [];
roiCentr = [];
roiArea = [];
boundBox = [];
valid = [];
pixel = {};
angle = [];
RHO = [];
p_Interval1 = {};
m_Interval1 = {};
m_p_Duration = {};

% Run through each folder to read in dataSummary.mat
for i = 1:nDir
    disp(['Working on folder:' DirList{i}])
    cd(DirList{i})
    curSummary = dir('*dataSummary.mat');
    load(curSummary.name);
    %First merge all stats from different movies of the same animal
    rp_thisAnimal = singleAnimalMerge(rp_total);

    validId = [validId; rp_thisAnimal.validId];
    durations = [durations; rp_thisAnimal.durations];
    diameters = [diameters; rp_thisAnimal.diameters];
    roiCentr = [roiCentr; rp_thisAnimal.roiCentr];
    roiArea = [roiArea rp_thisAnimal.roiArea];
    boundBox = [boundBox rp_thisAnimal.boundBox];
    valid = [valid; rp_thisAnimal.valid];

    pixel{i} = rp_thisAnimal.pixel;
    p_Interval1{i} = rp_thisAnimal.p_Interval1;
    m_Interval1{i} = rp_thisAnimal.m_Interval1;
    m_p_Duration{i} = rp_thisAnimal.m_p_Duration;

    angle = [angle rp_thisAnimal.angle];
    RHO = [RHO rp_thisAnimal.RHO];
    
    clear rp_toal
end

rp_all.validId = validId;
rp_all.durations = durations;
rp_all.diameters = diameters;
rp_all.roiCentr = roiCentr;
rp_all.roiArea = roiArea;
rp_all.boundBox = boundBox;
rp_all.valid = valid;
rp_all.pixel = pixel;
rp_all.angle = angle;
rp_all.RHO = RHO;
rp_all.p_Interval1 = p_Interval1;
rp_all.m_Interval1 = m_Interval1;
rp_all.m_p_Duration = m_p_Duration;

%Save the all-in-on data file
filter = '*.mat';
[file, path] = uiputfile(filter);
save(fullfile(path, file), 'rp_all')
cd(path);
generatePlots(rp_all);


function rp_oneAnimal = singleAnimalMerge(rp_total)
%First merge all stats from different movies of the same animal

    nMovies = length(rp_total);
    validId = [];
    durations = [];
    diameters= [];
    roiCentr = [];
    roiArea = [];
    boundBox = [];
    valid = [];
    pixel = {};
    angle = [];
    RHO = [];
    p_Interval1 = {};
    m_Interval1 = {};
    m_p_Duration = {};
    
    
    for i = 1:nMovies
        curStruct = rp_total{1, i};
        validId = [validId; curStruct.validId{1}];
        durations = [durations; curStruct.durations{1}];
        diameters = [diameters; curStruct.diameters{1}];
        roiCentr = [roiCentr; curStruct.roiCentr{1}];
        roiArea = [roiArea curStruct.roiArea{1}];
        boundBox = [boundBox curStruct.boundBox{1}];
        valid = [valid; curStruct.valid{1}];

        pixel{i} = curStruct.pixel{1};
        p_Interval1{i} = curStruct.p_Interval1{1};
        m_Interval1{i} = curStruct.m_Interval1{1};
        m_p_Duration{i} = curStruct.m_p_Duration{1};

        angle = [angle curStruct.angle{1}];
        RHO = [RHO curStruct.RHO{1}];
        
        clear curStruct
    end
    
    rp_oneAnimal.validId = validId;
    rp_oneAnimal.durations = durations;
    rp_oneAnimal.diameters = diameters;
    rp_oneAnimal.roiCentr = roiCentr;
    rp_oneAnimal.roiArea = roiArea;
    rp_oneAnimal.boundBox = boundBox;
    rp_oneAnimal.valid = valid;
    rp_oneAnimal.pixel = pixel;
    rp_oneAnimal.angle = angle;
    rp_oneAnimal.RHO = RHO;
    rp_oneAnimal.p_Interval1 = p_Interval1;
    rp_oneAnimal.m_Interval1 = m_Interval1;
    rp_oneAnimal.m_p_Duration = m_p_Duration;
    
    
end

function generatePlots(rp_all)
    
    savefn2 = 'Summary_across_aniamls';
    
    % rose plot
    h = figure; rose(rp_all.angle);
    title('Summary rose plot');
    saveas(h, [savefn2, '_rosePlot.png'])
    
    %Plot durations and diameters of detected components
    h(1) = figure; hist(rp_all.durations, 50); xlabel('durations (frames)'); title('Summary durations')
    saveas(h(1), [savefn2, '_durations.png'])
    h(2) = figure; hist(rp_all.diameters, 50); xlabel('diameters (pixels)'); title('Summary diameters')
    saveas(h(2), [savefn2, '_diameters.png'])
    h(3) = figure; scatter(rp_all.durations, rp_all.diameters); xlabel('durations'); ylabel('diameters'); title('Durations-Diameters Plot')
    saveas(h(3), [savefn2, '_duraVSdia.png'])
    
    %Plot roiArea
    h(4) = figure; hist(rp_all.roiArea, 50); xlabel('#pixels'); title('Summary roi sizes')
    saveas(h(4), [savefn2, '_roiArea.png'])
    
end