DirList = readtext('summary_dirs.txt', ' ');
folderList = DirList(:, 1);
curdir = pwd; 

nDir = size(DirList, 1);
freq_total = [];

for n = 1:nDir
    disp(['Working on folder:' folderList{n}])
    cd(folderList{n})
    
    filename = dir('*dataSummary.mat');
    load(filename.name)
    nmov = size(rp_total, 2);
    nframes = 0;
    nwaves =  0;
    for i = 1:nmov
        cur_rp = rp_total{i};
        if ~isempty(cur_rp)
            
            if i ~= nmov
                nframes = nframes + 3097;
            else
                last_mov_pixel = cur_rp.pixel{1}{end};
                last_frame = last_mov_pixel(end);
                nframes = nframes + last_frame;
            end
            
            nwaves = nwaves + size(cur_rp.durations{1}, 1);
            
        end
    end
    
    freq = nwaves/nframes * 600;
    try
        save(filename.name, 'freq', '-append');
    catch
        save('freq.mat', 'freq')
    end
    freq_total(n) = freq;    
end

freq_total = freq_total';
cd(curdir);
save('freq_total.mat', 'freq_total');
