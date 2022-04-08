%DirList = readtext('E:\Yixiaddang\results2021\p10-11_waveproperties\G6\summary_dirs.txt', ' ');
DirList = readtext('ttest_dirs.txt', ' ');
folderList = DirList(:, 1);
nDir = size(DirList, 1);
curdir = pwd; 

% Folder 1
cd(folderList{1}); fileList = dir('*.mat');
load(fileList.name)
disp(pwd)
disp('Loading exsiting data!')
angle1 = rp_all.angle; angle1 = angle1';
[Y1,E1] = discretize(angle1,36);
dominant_ind1 = mode(Y1);
edge_low = E1(dominant_ind1 - 2);
edge_high = E1(dominant_ind1 + 2);
dominant_dir1 = mean(angle1((angle1 > edge_low) & (angle1 < edge_high)));
dominant_dir1 = -pi/2;
angle1_rc = angle1 - dominant_dir1;
angle1_rc(abs(angle1_rc) > pi) = 2*pi - angle1_rc(abs(angle1_rc) > pi);
figure; histogram(angle1_rc, 36, 'Normalization','probability'); title('distribution 1');

% Folder 2
cd(folderList{2}); fileList = dir('*.mat');
load(fileList.name)
disp(pwd)
disp('Loading exsiting data!')
angle2 = rp_all.angle; angle2 = angle2';
[Y2,E2] = discretize(angle2,36);
dominant_ind2 = mode(Y2);
edge_low = E2(dominant_ind2 - 2);
edge_high = E2(dominant_ind2 + 2);
dominant_dir2 = mean(angle2((angle2 > edge_low) & (angle2 < edge_high)));
angle2_rc = angle2 - dominant_dir2;
angle2_rc(abs(angle2_rc) > pi) = 2*pi - angle2_rc(abs(angle2_rc) > pi);

% Remap distribution 2 relative to distribution 1
mean_diff = abs(dominant_dir2 - dominant_dir1);
if mean_diff > pi
    mean_diff = 2*pi - mean_diff; % This is critical, be aware of the fact that we are on a circle!
end

figure; histogram(angle2_rc, 36, 'Normalization','probability'); title('distribution 2');
angle2_rc = angle2_rc + mean_diff; % 
hold on; histogram(angle2_rc, 36, 'Normalization','probability'); legend('Before shifted', 'After shifted')

% Do two sample t test with welch's correction
[h, p, ci, stats] = ttest2(angle1_rc, angle2_rc, 'Vartype','unequal');

cd(curdir);
[file, path] = uiputfile('ttest_welch.mat');
cd(path);
save(fullfile(path, file), 'angle1', 'angle1_rc', 'dominant_dir1', ...
    'angle2', 'angle2_rc', 'dominant_dir2', 'h', 'p', 'ci', 'stats')