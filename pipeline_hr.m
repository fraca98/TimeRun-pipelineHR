%% PIPELINE_HR to manipulate data and get results
clear
close all
clc

addpath(genpath("src"));
%%
% devices names
devices = {'Apple','Fitbit','Garmin','Withings'};

% color to plot devices
colors = {'black','blue','magenta','green'};

%% Set the timestep to retime heart rate data
timestep = 5;

%% Plot sessions
filePath = matlab.desktop.editor.getActiveFilename; % Get the filepath of the script
projectPath = fileparts(filePath); % Take directory of folder containing filePath
dataPath = fullfile(projectPath,'data'); %path of folder data
data_fd = dir(dataPath);
data_Flags = [data_fd.isdir];
% extract only those that are directories.
users_Dirs = data_fd(data_Flags);

% get only the folder names into a cell array.
users_Dirs = users_Dirs(3:end);

% remove not necessary folders
users_Dirs(startsWith({users_Dirs.name},'Test')) = [];
users_Dirs(startsWith({users_Dirs.name},'AirQuality')) = [];
users_Dirs(startsWith({users_Dirs.name},'Garmin')) = [];
users_Dirs(startsWith({users_Dirs.name},'AppleWatch')) = [];

% sort users alphabetically
[~,ind] = sort(cellfun(@(x) str2num(char(regexp(x,'\d*','match'))),{users_Dirs.name}));
users_Dirs = users_Dirs(ind);
users_DirsNames = {users_Dirs.name};

users_DirsNames = string(users_DirsNames);

% loop in data folder for each user folder (iterate for user)
for idx_user = 1:size(users_DirsNames,2)
    userPath = fullfile(dataPath,users_DirsNames(idx_user));
    user_fd = dir(userPath);
    user_Flags = [user_fd.isdir];
    sessions_Dirs = user_fd(user_Flags);
    sessions_Dirs = sessions_Dirs(3:end); % keep only valid folders

    % sort sessions alphabetically
    [~,ind] = sort(cellfun(@(x) str2num(char(regexp(x,'\d*','match'))),{sessions_Dirs.name}));
    sessions_Dirs = sessions_Dirs(ind);
    sessions_DirsNames = {sessions_Dirs.name};

    sessions_DirsNames = string(sessions_DirsNames);
    sessions_DirsNames(startsWith(sessions_DirsNames,'Questionnaires')) = []; %remove the Questionnaires folder when i iterate sessions

    csvs = dir(fullfile(userPath));
    % get only the folder names into a cell array.
    csv_names = {csvs(3:end).name};
    csv_names = string(csv_names);
    tf_user = startsWith(csv_names,'user');
    user = readtable(fullfile(userPath, csv_names(tf_user)),"VariableNamingRule",'preserve');

    figure()
    sgtitle('idUser '+ users_DirsNames(idx_user))

    % loop for sessions for each user (iterate for session)
    for idx_session = 1: size(sessions_DirsNames,2)
        csvs = dir(fullfile(userPath,sessions_DirsNames(idx_session)));
        % get only the folder names into a cell array.
        csv_names = {csvs(3:end).name};
        csv_names = string(csv_names);

        subplot(2,1,idx_session),hold on

        tf_intervals = startsWith(csv_names, 'intervals');
        intervals = readtable(fullfile(userPath,sessions_DirsNames(idx_session), csv_names(tf_intervals)),"VariableNamingRule",'preserve');
        time = sort([intervals.start;intervals.end]); %put time of intervals in an array
        retInt = retimeINT(time,5); %Retime intervals to the new intervals considering new grid with timestep
        shiftstart = retInt(1:2:end-1);
        shiftend = retInt(2:2:end);


        % plot vertical line for start/end session (start first interval / end last interval)
        xline(shiftstart(1)-shiftstart(1),'HandleVisibility','off');
        xline(shiftend(end)-shiftstart(1),'HandleVisibility','off');

        % plot Y-lines to identify heart rate zones
        for z = 1:length(shiftstart)
            if z~=length(shiftstart)
                line([shiftstart(z)-shiftstart(1) shiftend(z)-shiftstart(1)],[(0.5 + 0.1*(z-1))*(220-(shiftstart(1).Year-user.birthYear)) (0.5 + 0.1*(z-1))*(220-(shiftstart(1).Year-user.birthYear))],'HandleVisibility','off','LineStyle','--')
            end
            if z~=1
                line([shiftstart(z)-shiftstart(1) shiftend(z)-shiftstart(1)],[(0.5 + 0.1*(z-2))*(220-(shiftstart(1).Year-user.birthYear)) (0.5 + 0.1*(z-2))*(220-(shiftstart(1).Year-user.birthYear))],'HandleVisibility','off','LineStyle','--')
            end
        end

        % color each interval
        for k=1:size(intervals,2)-1
            x_fill=[shiftend(k)-shiftstart(1),shiftend(k)-shiftstart(1),shiftstart(k+1)-shiftstart(1),shiftstart(k+1)-shiftstart(1)];
            y_fill=[0,250,250,0];
            a = fill(x_fill,y_fill,'yellow','HandleVisibility','off');
            a.FaceAlpha = 0.5;
        end

        tf_polar = startsWith(csv_names,'polar'); %% take polar file name
        polar = readtimetable(fullfile(userPath,sessions_DirsNames(idx_session), csv_names(tf_polar)),"VariableNamingRule",'preserve');
        polar = retimeHR(polar,timestep,shiftstart(1),shiftend(end)); %retime Polar considering the new grid
        plot(polar.time(~isnan(polar.rate))-shiftstart(1), polar.rate(~isnan(polar.rate)),'--.',Color='red', DisplayName='Polar')

        for i = 1:length(devices)
            tf = startsWith(csv_names,devices{i},'IgnoreCase',true); %% take file name containing devices data ignoring case sensitive
            if(ismember(1,tf) == 1)
                data = readtimetable(fullfile(userPath,sessions_DirsNames(idx_session), csv_names(tf)),'VariableNamingRule','preserve');
                data = retimeHR(data,timestep,shiftstart(1),shiftend(end)); %retime smartwatch considering the new grid
                plot(data.time(~isnan(data.rate))-shiftstart(1), data.rate(~isnan(data.rate)),'--.', Color=colors{i}, DisplayName=devices{i})
            end
            xlim([shiftstart(1)-shiftstart(1) shiftend(end)-shiftstart(1)])
            ylim([35 220]);
            set(gca,'FontSize',13)
            legend('Location','eastoutside')
        end
    end
end

%% A) Computing Error metrics
% - RMSE
% - COD
% - MARD
% - MAE
% - DELAY
% - XCORR

strDevices = string(['IDUser',devices]);

% creation of tables inside strcutures of errorMetrics
RMSE.all = table('Size',[length(users_DirsNames),5],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
COD.all = table('Size',[length(users_DirsNames),5],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
MARD.all = table('Size',[length(users_DirsNames),5],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
MAE.all = table('Size',[length(users_DirsNames),5],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
DELAY.all = table('Size',[length(users_DirsNames),5],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
XCORR.all = table('Size',[length(users_DirsNames),5],'VariableTypes',{'double','cell','cell','cell','cell'},'VariableNames',strDevices);

RMSE.all = standardizeMissing(RMSE.all,0); %to set table to NaN
COD.all = standardizeMissing(COD.all,0);
MARD.all = standardizeMissing(MARD.all,0);
MAE.all = standardizeMissing(MAE.all,0);
DELAY.all = standardizeMissing(DELAY.all,0);
XCORR.all = standardizeMissing(XCORR.all,0);


for tr = 1 : length(intervals.start)-1
    RMSE.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
    COD.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
    MARD.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
    MAE.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
    DELAY.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
    XCORR.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','cell','cell','cell','cell'},'VariableNames',strDevices);

    RMSE.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(RMSE.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    COD.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(COD.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    MARD.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(MARD.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    MAE.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(MAE.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    DELAY.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(DELAY.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    XCORR.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(XCORR.transition.(sprintf('tr%d%d',tr-1,tr)),0);
end

for hrzone = 1 : length(intervals.start)
    RMSE.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
    COD.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
    MARD.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
    MAE.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
    DELAY.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
    XCORR.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','cell','cell','cell','cell'},'VariableNames',strDevices);

    RMSE.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(RMSE.zone.(sprintf('z%d',hrzone-1)),0);
    COD.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(COD.zone.(sprintf('z%d',hrzone-1)),0);
    MARD.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(MARD.zone.(sprintf('z%d',hrzone-1)),0);
    MAE.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(MAE.zone.(sprintf('z%d',hrzone-1)),0);
    DELAY.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(DELAY.zone.(sprintf('z%d',hrzone-1)),0);
    XCORR.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(XCORR.zone.(sprintf('z%d',hrzone-1)),0);
end

RMSE.allzone = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
COD.allzone = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
MARD.allzone = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
MAE.allzone = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
DELAY.allzone = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
XCORR.allzone = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','cell','cell','cell','cell'},'VariableNames',strDevices);

RMSE.allzone = standardizeMissing(RMSE.allzone,0);
COD.allzone = standardizeMissing(COD.allzone,0);
MARD.allzone = standardizeMissing(MARD.allzone,0);
MAE.allzone = standardizeMissing(MAE.allzone,0);
DELAY.allzone = standardizeMissing(DELAY.allzone,0);
XCORR.allzone = standardizeMissing(XCORR.allzone,0);

RMSE.alltr = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
COD.alltr = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
MARD.alltr = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
MAE.alltr = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
DELAY.alltr = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','double','double','double','double'},'VariableNames',strDevices);
XCORR.alltr = table('Size',[length(users_DirsNames),length(strDevices)],'VariableTypes',{'double','cell','cell','cell','cell'},'VariableNames',strDevices);

RMSE.alltr = standardizeMissing(RMSE.alltr,0);
COD.alltr = standardizeMissing(COD.alltr,0);
MARD.alltr = standardizeMissing(MARD.alltr,0);
MAE.alltr = standardizeMissing(MAE.alltr,0);
DELAY.alltr = standardizeMissing(DELAY.alltr,0);
XCORR.alltr = standardizeMissing(XCORR.alltr,0);

for idx_user = 1:size(users_DirsNames,2)

    % assign the idUser in tables of structures of errorMetrics
    RMSE.all {idx_user,1} = users_DirsNames(idx_user);
    COD.all {idx_user,1} = users_DirsNames(idx_user);
    MARD.all {idx_user,1} = users_DirsNames(idx_user);
    MAE.all {idx_user,1} = users_DirsNames(idx_user);
    DELAY.all {idx_user,1} = users_DirsNames(idx_user);
    XCORR.all {idx_user,1} = users_DirsNames(idx_user);

    for tr = 1 : length(intervals.start)-1
        RMSE.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        COD.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        MARD.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        MAE.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        DELAY.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        XCORR.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
    end

    for hrzone = 1 : length(intervals.start)
        RMSE.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        COD.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        MARD.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        MAE.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        DELAY.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        XCORR.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
    end

    RMSE.allzone {idx_user,1} = users_DirsNames(idx_user);
    COD.allzone {idx_user,1} = users_DirsNames(idx_user);
    MARD.allzone {idx_user,1} = users_DirsNames(idx_user);
    MAE.allzone {idx_user,1} = users_DirsNames(idx_user);
    DELAY.allzone {idx_user,1} = users_DirsNames(idx_user);
    XCORR.allzone {idx_user,1} = users_DirsNames(idx_user);

    RMSE.alltr {idx_user,1} = users_DirsNames(idx_user);
    COD.alltr {idx_user,1} = users_DirsNames(idx_user);
    MARD.alltr {idx_user,1} = users_DirsNames(idx_user);
    MAE.alltr {idx_user,1} = users_DirsNames(idx_user);
    DELAY.alltr {idx_user,1} = users_DirsNames(idx_user);
    XCORR.alltr {idx_user,1} = users_DirsNames(idx_user);

    % access the sessions of each user
    userPath = fullfile(dataPath,users_DirsNames(idx_user));
    user_fd = dir(userPath);
    user_Flags = [user_fd.isdir];
    sessions_Dirs = user_fd(user_Flags);
    sessions_Dirs = sessions_Dirs(3:end); % keep only valid folders

    % sort sessions alphabetically
    [~,ind] = sort(cellfun(@(x) str2num(char(regexp(x,'\d*','match'))),{sessions_Dirs.name}));
    sessions_Dirs = sessions_Dirs(ind);
    sessions_DirsNames = {sessions_Dirs.name};

    sessions_DirsNames = string(sessions_DirsNames);
    sessions_DirsNames(startsWith(sessions_DirsNames,'Questionnaires')) = []; %remove the Questionnaires folder when i iterate sessions

    % loop for sessions for each user (iterate for session)
    for idx_session = 1: size(sessions_DirsNames,2)
        csvs = dir(fullfile(userPath,sessions_DirsNames(idx_session)));
        % get only the folder names into a cell array
        csv_names = {csvs(3:end).name};
        csv_names = string(csv_names);

        tf_intervals = startsWith(csv_names, 'intervals');
        intervals = readtable(fullfile(userPath,sessions_DirsNames(idx_session), csv_names(tf_intervals)),"VariableNamingRule",'preserve');
        time = sort([intervals.start;intervals.end]); %put time of intervals in an array
        retInt = retimeINT(time,5); %Retime intervals to the new intervals considering new grid with timestep
        shiftstart = retInt(1:2:end-1);
        shiftend = retInt(2:2:end);

        tf_polar = startsWith(csv_names,'polar'); %% take polar file name
        polar = readtimetable(fullfile(userPath,sessions_DirsNames(idx_session), csv_names(tf_polar)),"VariableNamingRule",'preserve');
        polar = retimeHR(polar,timestep,shiftstart(1),shiftend(end)); %retime Polar considering the new grid

        for i = 1:length(devices)
            tf = startsWith(csv_names,devices{i},'IgnoreCase',true); %% take file name containing devices data ignoring case sensitive
            if(ismember(1,tf) == 1)
                data = readtimetable(fullfile(userPath,sessions_DirsNames(idx_session), csv_names(tf)),"VariableNamingRule",'preserve');
                data = retimeHR(data,timestep,shiftstart(1),shiftend(end)); %retime smartwatch considering the new grid

                % Removing here zone/transitions after seeing in plots
                switch idx_user
                    case 6
                        % Apple: only HR0,HR1,TR01,TR12
                        if (i==1) %Apple
                            data.rate(~isbetween(data.time,shiftstart(1),shiftstart(3),'openright'))=NaN;
                        end
                    case 7
                        % Fitbit/Garmin/Apple/Withings: NO HR0,TR01 (TR01 NOT EXIST! --> remove calculation HR0, cause first point HR1 is also end HR0)
                        data.rate(~isbetween(data.time,shiftstart(2),shiftend(end)))=NaN;
                        % Remove Fitbit (outlier)
                        if (i==2) data.rate(:)=NaN; end
                    case 8
                        if(i==1 || i==4) %Apple/Withings: NO HR0,TR01
                            data.rate(~isbetween(data.time,shiftstart(2),shiftend(end)))=NaN;
                        end
                        if(i==2 || i==3) %Fitbit/Garmin: NO HR0
                            data.rate(~isbetween(data.time,shiftend(1),shiftend(end),'openleft'))=NaN;
                        end

                end

                % Now calculating the errorMetrics

                % 1) Entire signal (from the start of the first interval to
                % the end of the session or last interval. Transitions are
                % included)

                RMSE.all {idx_user,i+1} = rmse(polar,data);
                COD.all {idx_user,i+1} = cod(polar,data);
                MARD.all {idx_user,i+1} = mard(polar,data);
                MAE.all {idx_user,i+1} = mae(polar,data);
                DELAY.all {idx_user,i+1} = timeDelay(polar,data);
                XCORR.all {idx_user,i+1} = {xcorrN(polar,data)};

                % 2) Each transition
                for tr = 1 : length(intervals.start)-1
                    trpolar = polar(isbetween(polar.time,shiftend(tr),shiftstart(tr+1),'open'),:);
                    trdata = data(isbetween(data.time,shiftend(tr),shiftstart(tr+1),'open'),:);

                    RMSE.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,i+1} = rmse(trpolar,trdata);
                    COD.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,i+1} = cod(trpolar,trdata);
                    MARD.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,i+1} = mard(trpolar,trdata);
                    MAE.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,i+1} = mae(trpolar,trdata);
                    DELAY.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,i+1} = timeDelay(trpolar,trdata);
                    XCORR.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,i+1} = {xcorrN(trpolar,trdata)};

                end

                % 3) Each heart rate zone (interval)
                for hrzone = 1 : length(intervals.start)
                    hrzonepolar = polar(isbetween(polar.time,shiftstart(hrzone),shiftend(hrzone)),:);
                    hrzonedata = data(isbetween(data.time,shiftstart(hrzone),shiftend(hrzone)),:);

                    if(idx_user==7 && hrzone ==1) %HR0 7 is NaN
                        hrzonedata.rate = NaN(size(hrzonedata,1),1);
                    end
                    RMSE.zone.(sprintf('z%d',hrzone-1)) {idx_user,i+1} = rmse(hrzonepolar,hrzonedata);
                    COD.zone.(sprintf('z%d',hrzone-1)) {idx_user,i+1} = cod(hrzonepolar,hrzonedata);
                    MARD.zone.(sprintf('z%d',hrzone-1)) {idx_user,i+1} = mard(hrzonepolar,hrzonedata);
                    MAE.zone.(sprintf('z%d',hrzone-1)) {idx_user,i+1} = mae(hrzonepolar,hrzonedata);
                    DELAY.zone.(sprintf('z%d',hrzone-1)) {idx_user,i+1} = timeDelay(hrzonepolar,hrzonedata);
                    XCORR.zone.(sprintf('z%d',hrzone-1)) {idx_user,i+1} = {xcorrN(hrzonepolar,hrzonedata)};

                end

                % 4) All the zones together
                allzonepolar = [];
                allzonedata = [];
                for hrzone = 1 : length(intervals.start)
                    allzonepolar = [allzonepolar;polar(isbetween(polar.time,shiftstart(hrzone),shiftend(hrzone)),:)];
                    allzonedata = [allzonedata;data(isbetween(data.time,shiftstart(hrzone),shiftend(hrzone)),:)];
                end
                RMSE.allzone {idx_user,i+1} = rmse(allzonepolar,allzonedata);
                COD.allzone {idx_user,i+1} = cod(allzonepolar,allzonedata);
                MARD.allzone {idx_user,i+1} = mard(allzonepolar,allzonedata);
                MAE.allzone {idx_user,i+1} = mae(allzonepolar,allzonedata);
                DELAY.allzone {idx_user,i+1} = timeDelay(allzonepolar,allzonedata);
                XCORR.allzone {idx_user,i+1} = {xcorrN(allzonepolar,allzonedata)};

                % 5) All the transitions together
                alltrpolar = [];
                alltrdata = [];
                for tr = 1 : length(intervals.start)-1
                    alltrpolar = [alltrpolar;polar(isbetween(polar.time,shiftend(tr),shiftstart(tr+1),'open'),:)];
                    alltrdata = [alltrdata;data(isbetween(data.time,shiftend(tr),shiftstart(tr+1),'open'),:)];
                end
                RMSE.alltr {idx_user,i+1} = rmse(alltrpolar,alltrdata);
                COD.alltr {idx_user,i+1} = cod(alltrpolar,alltrdata);
                MARD.alltr {idx_user,i+1} = mard(alltrpolar,alltrdata);
                MAE.alltr {idx_user,i+1} = mae(alltrpolar,alltrdata);
                DELAY.alltr {idx_user,i+1} = timeDelay(alltrpolar,alltrdata);
                XCORR.alltr {idx_user,i+1} = {xcorrN(alltrpolar,alltrdata)};
            end
        end
    end
end

%% B) Computing Statistics
% - Mean
% - SD
% - Median
% - 25/75 boxplot

% Session 1

Sess1.MEAN.all = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double'},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.MEDIAN.all = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double'},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.SD.all = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double'},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.p25.all = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double'},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.p75.all = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.MIN.all = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.MAX.all = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);

Sess1.MEAN.all = standardizeMissing(Sess1.MEAN.all,0);
Sess1.MEDIAN.all = standardizeMissing(Sess1.MEDIAN.all,0);
Sess1.SD.all = standardizeMissing(Sess1.SD.all,0);
Sess1.p25.all = standardizeMissing(Sess1.p25.all,0);
Sess1.p75.all = standardizeMissing(Sess1.p75.all,0);
Sess1.MIN.all = standardizeMissing(Sess1.MIN.all,0);
Sess1.MAX.all = standardizeMissing(Sess1.MAX.all,0);

for tr = 1 : length(intervals.start)-1
    Sess1.MEAN.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
    Sess1.MEDIAN.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
    Sess1.SD.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
    Sess1.p25.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
    Sess1.p75.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
    Sess1.MIN.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
    Sess1.MAX.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);


    Sess1.MEAN.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(Sess1.MEAN.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    Sess1.MEDIAN.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(Sess1.MEDIAN.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    Sess1.SD.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(Sess1.SD.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    Sess1.p25.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(Sess1.p25.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    Sess1.p75.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(Sess1.p75.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    Sess1.MIN.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(Sess1.MIN.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    Sess1.MAX.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(Sess1.MAX.transition.(sprintf('tr%d%d',tr-1,tr)),0);
end

for hrzone = 1 : length(intervals.start)
    Sess1.MEAN.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
    Sess1.MEDIAN.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
    Sess1.SD.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
    Sess1.p25.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
    Sess1.p75.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
    Sess1.MIN.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
    Sess1.MAX.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);

    Sess1.MEAN.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(Sess1.MEAN.zone.(sprintf('z%d',hrzone-1)),0);
    Sess1.MEDIAN.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(Sess1.MEDIAN.zone.(sprintf('z%d',hrzone-1)),0);
    Sess1.SD.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(Sess1.SD.zone.(sprintf('z%d',hrzone-1)),0);
    Sess1.p25.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(Sess1.p25.zone.(sprintf('z%d',hrzone-1)),0);
    Sess1.p75.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(Sess1.p75.zone.(sprintf('z%d',hrzone-1)),0);
    Sess1.MIN.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(Sess1.MIN.zone.(sprintf('z%d',hrzone-1)),0);
    Sess1.MAX.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(Sess1.MAX.zone.(sprintf('z%d',hrzone-1)),0);
end

Sess1.MEAN.allzone = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.MEDIAN.allzone = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.SD.allzone = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.p25.allzone = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.p75.allzone = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.MIN.allzone = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.MAX.allzone = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);

Sess1.MEAN.allzone = standardizeMissing(Sess1.MEAN.allzone,0);
Sess1.MEDIAN.allzone = standardizeMissing(Sess1.MEDIAN.allzone,0);
Sess1.SD.allzone = standardizeMissing(Sess1.SD.allzone,0);
Sess1.p25.allzone = standardizeMissing(Sess1.p25.allzone,0);
Sess1.p25.allzone = standardizeMissing(Sess1.p75.allzone,0);
Sess1.MIN.allzone = standardizeMissing(Sess1.MIN.allzone,0);
Sess1.MAX.allzone = standardizeMissing(Sess1.MAX.allzone,0);

Sess1.MEAN.alltr = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.MEDIAN.alltr = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.SD.alltr = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.p25.alltr = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.p75.alltr = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.MIN.alltr = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);
Sess1.MAX.alltr = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Fitbit","Garmin"]);

Sess1.MEAN.alltr = standardizeMissing(Sess1.MEAN.alltr,0);
Sess1.MEDIAN.alltr = standardizeMissing(Sess1.MEDIAN.alltr,0);
Sess1.SD.alltr = standardizeMissing(Sess1.SD.alltr,0);
Sess1.p25.alltr = standardizeMissing(Sess1.p25.alltr,0);
Sess1.p25.alltr = standardizeMissing(Sess1.p75.alltr,0);
Sess1.MIN.alltr = standardizeMissing(Sess1.MIN.alltr,0);
Sess1.MAX.alltr = standardizeMissing(Sess1.MAX.alltr,0);


for idx_user = 1:size(users_DirsNames,2)

    % assign the idUser in tables of structures of errorMetrics
    Sess1.MEAN.all {idx_user,1} = users_DirsNames(idx_user);
    Sess1.MEDIAN.all {idx_user,1} = users_DirsNames(idx_user);
    Sess1.SD.all {idx_user,1} = users_DirsNames(idx_user);
    Sess1.p25.all {idx_user,1} = users_DirsNames(idx_user);
    Sess1.p75.all {idx_user,1} = users_DirsNames(idx_user);
    Sess1.MIN.all {idx_user,1} = users_DirsNames(idx_user);
    Sess1.MAX.all {idx_user,1} = users_DirsNames(idx_user);

    for tr = 1 : length(intervals.start)-1
        Sess1.MEAN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        Sess1.MEDIAN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        Sess1.SD.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        Sess1.p25.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        Sess1.p75.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        Sess1.MIN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        Sess1.MAX.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
    end

    for hrzone = 1 : length(intervals.start)
        Sess1.MEAN.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        Sess1.MEDIAN.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        Sess1.SD.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        Sess1.p25.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        Sess1.p75.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        Sess1.MIN.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        Sess1.MAX.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
    end

    Sess1.MEAN.allzone {idx_user,1} = users_DirsNames(idx_user);
    Sess1.MEDIAN.allzone {idx_user,1} = users_DirsNames(idx_user);
    Sess1.SD.allzone {idx_user,1} = users_DirsNames(idx_user);
    Sess1.p25.allzone {idx_user,1} = users_DirsNames(idx_user);
    Sess1.p75.allzone {idx_user,1} = users_DirsNames(idx_user);
    Sess1.MIN.allzone {idx_user,1} = users_DirsNames(idx_user);
    Sess1.MAX.allzone {idx_user,1} = users_DirsNames(idx_user);

    Sess1.MEAN.alltr {idx_user,1} = users_DirsNames(idx_user);
    Sess1.MEDIAN.alltr {idx_user,1} = users_DirsNames(idx_user);
    Sess1.SD.alltr {idx_user,1} = users_DirsNames(idx_user);
    Sess1.p25.alltr {idx_user,1} = users_DirsNames(idx_user);
    Sess1.p75.alltr {idx_user,1} = users_DirsNames(idx_user);
    Sess1.MIN.alltr {idx_user,1} = users_DirsNames(idx_user);
    Sess1.MAX.alltr {idx_user,1} = users_DirsNames(idx_user);

    % access the sessions of each user
    userPath = fullfile(dataPath,users_DirsNames(idx_user));
    user_fd = dir(userPath);
    user_Flags = [user_fd.isdir];
    sessions_Dirs = user_fd(user_Flags);
    sessions_Dirs = sessions_Dirs(3:end); % keep only valid folders

    % sort sessions alphabetically
    [~,ind] = sort(cellfun(@(x) str2num(char(regexp(x,'\d*','match'))),{sessions_Dirs.name}));
    sessions_Dirs = sessions_Dirs(ind);
    sessions_DirsNames = {sessions_Dirs.name};

    sessions_DirsNames = string(sessions_DirsNames);
    sessions_DirsNames(startsWith(sessions_DirsNames,'Questionnaires')) = []; %remove the Questionnaires folder when i iterate sessions

    % first session of the user
    idx_session = 1;
    csvs = dir(fullfile(userPath,sessions_DirsNames(idx_session)));
    % get only the folder names into a cell array
    csv_names = {csvs(3:end).name};
    csv_names = string(csv_names);

    tf_intervals = startsWith(csv_names, 'intervals');
    intervals = readtable(fullfile(userPath,sessions_DirsNames(idx_session), csv_names(tf_intervals)),"VariableNamingRule",'preserve');
    time = sort([intervals.start;intervals.end]); %put time of intervals in an array
    retInt = retimeINT(time,5); %Retime intervals to the new intervals considering new grid with timestep
    shiftstart = retInt(1:2:end-1);
    shiftend = retInt(2:2:end);

    tf_polar = startsWith(csv_names,'polar'); %% take polar file name
    polar = readtimetable(fullfile(userPath,sessions_DirsNames(idx_session), csv_names(tf_polar)),"VariableNamingRule",'preserve');
    polar = retimeHR(polar,timestep,shiftstart(1),shiftend(end)); %retime Polar considering the new grid

    k=3; %counter for columns to save data of devices

    for i = 1:length(devices)
        tf = startsWith(csv_names,devices{i},'IgnoreCase',true); %% take file name containing devices data ignoring case sensitive
        if(ismember(1,tf) == 1)
            data = readtimetable(fullfile(userPath,sessions_DirsNames(idx_session), csv_names(tf)),"VariableNamingRule",'preserve');
            data = retimeHR(data,timestep,shiftstart(1),shiftend(end)); %retime smartwatch considering the new grid

            % Removing here zone/transitions after seeing in plots
            switch idx_user
                case 6
                    % Apple: only HR0,HR1,TR01,TR12
                    if (i==1) %Apple
                        data.rate(~isbetween(data.time,shiftstart(1),shiftstart(3),'openright'))=NaN;
                    end
                case 7
                    % Fitbit/Garmin/Apple/Withings: NO HR0,TR01
                    data.rate(~isbetween(data.time,shiftstart(2),shiftend(end)))=NaN;
                    % Remove Fitbit (outlier)
                    if (i==2) data.rate(:)=NaN; end
                case 8
                    if(i==1 || i==4) %Apple/Withings: NO HR0,TR01
                        data.rate(~isbetween(data.time,shiftstart(2),shiftend(end)))=NaN;
                    end
                    if(i==2 || i==3) %Fitbit/Garmin: NO HR0
                        data.rate(~isbetween(data.time,shiftend(1),shiftend(end),'openleft'))=NaN;
                    end

            end
            % Now calculating the Statistics

            % 1) Entire signal (from the start of the first interval to
            % the end of the session or last interval. Transitions are
            % included)

            Sess1.MEAN.all {idx_user,2} = nanmean(polar.rate);
            Sess1.MEDIAN.all {idx_user,2} = nanmedian(polar.rate);
            Sess1.SD.all {idx_user,2} = nanstd(polar.rate);
            Sess1.p25.all {idx_user,2} = prctile(polar.rate,25);
            Sess1.p75.all {idx_user,2} = prctile(polar.rate,75);
            if(~isempty(polar.rate(~isnan(polar.rate)))) %if not empty (excluding NaN)
                Sess1.MIN.all {idx_user,2} = min(polar.rate,[],'omitnan');
                Sess1.MAX.all {idx_user,2} = max(polar.rate,[],'omitnan');
            end


            Sess1.MEAN.all {idx_user,k} = nanmean(data.rate);
            Sess1.MEDIAN.all {idx_user,k} = nanmedian(data.rate);
            Sess1.SD.all {idx_user,k} = nanstd(data.rate);
            Sess1.p25.all {idx_user,k} = prctile(data.rate,25);
            Sess1.p75.all {idx_user,k} = prctile(data.rate,75);
            if(~isempty(data.rate(~isnan(data.rate)))) %if not empty (excluding NaN)
                Sess1.MIN.all {idx_user,k} = min(data.rate,[],'omitnan');
                Sess1.MAX.all {idx_user,k} = max(data.rate,[],'omitnan');
            end



            % 2) Each transition
            for tr = 1 : length(intervals.start)-1
                trpolar = polar(isbetween(polar.time,shiftend(tr),shiftstart(tr+1),'open'),:);
                trdata = data(isbetween(data.time,shiftend(tr),shiftstart(tr+1),'open'),:);


                Sess1.MEAN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,2} = nanmean(trpolar.rate);
                Sess1.MEDIAN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,2} = nanmedian(trpolar.rate);
                Sess1.SD.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,2} = nanstd(trpolar.rate);
                Sess1.p25.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,2} = prctile(trpolar.rate,25);
                Sess1.p75.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,2} = prctile(trpolar.rate,75);
                if(~isempty(trpolar.rate(~isnan(trpolar.rate)))) %if not empty (excluding NaN)
                    Sess1.MIN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,2} = min(trpolar.rate,[],'omitnan');
                    Sess1.MAX.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,2} = max(trpolar.rate,[],'omitnan');
                end

                Sess1.MEAN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,k} = nanmean(trdata.rate);
                Sess1.MEDIAN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,k} = nanmedian(trdata.rate);
                Sess1.SD.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,k} = nanstd(trdata.rate);
                Sess1.p25.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,k} = prctile(trdata.rate,25);
                Sess1.p75.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,k} = prctile(trdata.rate,75);
                if(~isempty(trdata.rate(~isnan(trdata.rate)))) %if not empty (excluding NaN)
                    Sess1.MIN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,k} = min(trdata.rate,[],'omitnan');
                    Sess1.MAX.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,k} = max(trdata.rate,[],'omitnan');
                end
            end

            % 3) Each heart rate zone (interval)
            for hrzone = 1 : length(intervals.start)
                hrzonepolar = polar(isbetween(polar.time,shiftstart(hrzone),shiftend(hrzone)),:);
                hrzonedata = data(isbetween(data.time,shiftstart(hrzone),shiftend(hrzone)),:);

                if(idx_user==7 && hrzone ==1) %HR0 7 is NaN
                    hrzonedata.rate = NaN(size(hrzonedata,1),1);
                end

                Sess1.MEAN.zone.(sprintf('z%d',hrzone-1)) {idx_user,2} = nanmean(hrzonepolar.rate);
                Sess1.MEDIAN.zone.(sprintf('z%d',hrzone-1)) {idx_user,2} = nanmedian(hrzonepolar.rate);
                Sess1.SD.zone.(sprintf('z%d',hrzone-1)) {idx_user,2} = nanstd(hrzonepolar.rate);
                Sess1.p25.zone.(sprintf('z%d',hrzone-1)) {idx_user,2} = prctile(hrzonepolar.rate,25);
                Sess1.p75.zone.(sprintf('z%d',hrzone-1)) {idx_user,2} = prctile(hrzonepolar.rate,75);
                if(~isempty(hrzonepolar.rate(~isnan(hrzonepolar.rate)))) %if not empty (excluding NaN)
                    Sess1.MIN.zone.(sprintf('z%d',hrzone-1)) {idx_user,2} = min(hrzonepolar.rate,[],'omitnan');
                    Sess1.MAX.zone.(sprintf('z%d',hrzone-1)) {idx_user,2} = max(hrzonepolar.rate,[],'omitnan');
                end

                Sess1.MEAN.zone.(sprintf('z%d',hrzone-1)) {idx_user,k} = nanmean(hrzonedata.rate);
                Sess1.MEDIAN.zone.(sprintf('z%d',hrzone-1)) {idx_user,k} = nanmedian(hrzonedata.rate);
                Sess1.SD.zone.(sprintf('z%d',hrzone-1)) {idx_user,k} = nanstd(hrzonedata.rate);
                Sess1.p25.zone.(sprintf('z%d',hrzone-1)) {idx_user,k} = prctile(hrzonedata.rate,25);
                Sess1.p75.zone.(sprintf('z%d',hrzone-1)) {idx_user,k} = prctile(hrzonedata.rate,75);
                if(~isempty(hrzonedata.rate(~isnan(hrzonedata.rate)))) %if not empty (excluding NaN)
                    Sess1.MIN.zone.(sprintf('z%d',hrzone-1)) {idx_user,k} = min(hrzonedata.rate,[],'omitnan');
                    Sess1.MAX.zone.(sprintf('z%d',hrzone-1)) {idx_user,k} = max(hrzonedata.rate,[],'omitnan');
                end

            end

            % 4) All zone together
            allzonepolar = [];
            allzonedata = [];
            for hrzone = 1 : length(intervals.start)
                allzonepolar = [allzonepolar;polar(isbetween(polar.time,shiftstart(hrzone),shiftend(hrzone)),:)];
                allzonedata = [allzonedata;data(isbetween(data.time,shiftstart(hrzone),shiftend(hrzone)),:)];
            end
            Sess1.MEAN.allzone {idx_user,2} = nanmean(allzonepolar.rate);
            Sess1.MEDIAN.allzone {idx_user,2} = nanmedian(allzonepolar.rate);
            Sess1.SD.allzone {idx_user,2} = nanstd(allzonepolar.rate);
            Sess1.p25.allzone {idx_user,2} = prctile(allzonepolar.rate,25);
            Sess1.p75.allzone {idx_user,2} = prctile(allzonepolar.rate,75);
            if(~isempty(allzonepolar.rate(~isnan(allzonepolar.rate)))) %if not empty (excluding NaN)
                Sess1.MIN.allzone {idx_user,2} = min(allzonepolar.rate,[],'omitnan');
                Sess1.MAX.allzone {idx_user,2} = max(allzonepolar.rate,[],'omitnan');
            end

            Sess1.MEAN.allzone {idx_user,k}= nanmean(allzonedata.rate);
            Sess1.MEDIAN.allzone {idx_user,k} = nanmedian(allzonedata.rate);
            Sess1.SD.allzone {idx_user,k}= nanstd(allzonedata.rate);
            Sess1.p25.allzone {idx_user,k} = prctile(allzonedata.rate,25);
            Sess1.p75.allzone {idx_user,k} = prctile(allzonedata.rate,75);
            if(~isempty(allzonedata.rate(~isnan(allzonedata.rate)))) %if not empty (excluding NaN)
                Sess1.MIN.allzone {idx_user,k} = min(allzonedata.rate,[],'omitnan');
                Sess1.MAX.allzone {idx_user,k} = max(allzonedata.rate,[],'omitnan');
            end



            % 5) All the transitions together
            alltrpolar = [];
            alltrdata = [];
            for tr = 1 : length(intervals.start)-1
                alltrpolar = [alltrpolar;polar(isbetween(polar.time,shiftend(tr),shiftstart(tr+1),'open'),:)];
                alltrdata = [alltrdata;data(isbetween(data.time,shiftend(tr),shiftstart(tr+1),'open'),:)];
            end
            Sess1.MEAN.alltr {idx_user,2} = nanmean(alltrpolar.rate);
            Sess1.MEDIAN.alltr {idx_user,2} = nanmedian(alltrpolar.rate);
            Sess1.SD.alltr {idx_user,2} = nanstd(alltrpolar.rate);
            Sess1.p25.alltr {idx_user,2} = prctile(alltrpolar.rate,25);
            Sess1.p75.alltr {idx_user,2} = prctile(alltrpolar.rate,75);
            if(~isempty(alltrpolar.rate(~isnan(alltrpolar.rate)))) %if not empty (excluding NaN)
                Sess1.MIN.alltr {idx_user,2} = min(alltrpolar.rate,[],'omitnan');
                Sess1.MAX.alltr {idx_user,2} = max(alltrpolar.rate,[],'omitnan');
            end

            Sess1.MEAN.alltr {idx_user,k}= nanmean(alltrdata.rate);
            Sess1.MEDIAN.alltr {idx_user,k} = nanmedian(alltrdata.rate);
            Sess1.SD.alltr {idx_user,k}= nanstd(alltrdata.rate);
            Sess1.p25.alltr {idx_user,k} = prctile(alltrdata.rate,25);
            Sess1.p75.alltr {idx_user,k} = prctile(alltrdata.rate,75);
            if(~isempty(alltrdata.rate(~isnan(alltrdata.rate)))) %if not empty (excluding NaN)
                Sess1.MIN.alltr {idx_user,k} = min(alltrdata.rate,[],'omitnan');
                Sess1.MAX.alltr {idx_user,k} = max(alltrdata.rate,[],'omitnan');
            end

            k=k+1;
        end
    end
end

% Session 2
Sess2.MEAN.all = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double'},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.MEDIAN.all = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double'},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.SD.all = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double'},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.p25.all = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double'},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.p75.all = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.MIN.all = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.MAX.all = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);

Sess2.MEAN.all = standardizeMissing(Sess2.MEAN.all,0);
Sess2.MEDIAN.all = standardizeMissing(Sess2.MEDIAN.all,0);
Sess2.SD.all = standardizeMissing(Sess2.SD.all,0);
Sess2.p25.all = standardizeMissing(Sess2.p25.all,0);
Sess2.p75.all = standardizeMissing(Sess2.p75.all,0);
Sess2.MIN.all = standardizeMissing(Sess2.MIN.all,0);
Sess2.MAX.all = standardizeMissing(Sess2.MAX.all,0);

for tr = 1 : length(intervals.start)-1
    Sess2.MEAN.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
    Sess2.MEDIAN.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
    Sess2.SD.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
    Sess2.p25.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
    Sess2.p75.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
    Sess2.MIN.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
    Sess2.MAX.transition.(sprintf('tr%d%d',tr-1,tr)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);


    Sess2.MEAN.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(Sess2.MEAN.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    Sess2.MEDIAN.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(Sess2.MEDIAN.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    Sess2.SD.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(Sess2.SD.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    Sess2.p25.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(Sess2.p25.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    Sess2.p75.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(Sess2.p75.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    Sess2.MIN.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(Sess2.MIN.transition.(sprintf('tr%d%d',tr-1,tr)),0);
    Sess2.MAX.transition.(sprintf('tr%d%d',tr-1,tr)) = standardizeMissing(Sess2.MAX.transition.(sprintf('tr%d%d',tr-1,tr)),0);
end

for hrzone = 1 : length(intervals.start)
    Sess2.MEAN.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
    Sess2.MEDIAN.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
    Sess2.SD.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
    Sess2.p25.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
    Sess2.p75.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
    Sess2.MIN.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
    Sess2.MAX.zone.(sprintf('z%d',hrzone-1)) = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);

    Sess2.MEAN.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(Sess2.MEAN.zone.(sprintf('z%d',hrzone-1)),0);
    Sess2.MEDIAN.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(Sess2.MEDIAN.zone.(sprintf('z%d',hrzone-1)),0);
    Sess2.SD.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(Sess2.SD.zone.(sprintf('z%d',hrzone-1)),0);
    Sess2.p25.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(Sess2.p25.zone.(sprintf('z%d',hrzone-1)),0);
    Sess2.p75.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(Sess2.p75.zone.(sprintf('z%d',hrzone-1)),0);
    Sess2.MIN.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(Sess2.MIN.zone.(sprintf('z%d',hrzone-1)),0);
    Sess2.MAX.zone.(sprintf('z%d',hrzone-1)) = standardizeMissing(Sess2.MAX.zone.(sprintf('z%d',hrzone-1)),0);
end

Sess2.MEAN.allzone = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.MEDIAN.allzone = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.SD.allzone = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.p25.allzone = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.p75.allzone = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.MIN.allzone = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.MAX.allzone = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);

Sess2.MEAN.allzone = standardizeMissing(Sess2.MEAN.allzone,0);
Sess2.MEDIAN.allzone = standardizeMissing(Sess2.MEDIAN.allzone,0);
Sess2.SD.allzone = standardizeMissing(Sess2.SD.allzone,0);
Sess2.p25.allzone = standardizeMissing(Sess2.p25.allzone,0);
Sess2.p25.allzone = standardizeMissing(Sess2.p75.allzone,0);
Sess2.MIN.allzone = standardizeMissing(Sess2.MIN.allzone,0);
Sess2.MAX.allzone = standardizeMissing(Sess2.MAX.allzone,0);

Sess2.MEAN.alltr = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.MEDIAN.alltr = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.SD.alltr = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.p25.alltr = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.p75.alltr = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.MIN.alltr = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);
Sess2.MAX.alltr = table('Size',[length(users_DirsNames),4],'VariableTypes',{'double','double','double','double',},'VariableNames',["IDUser","Polar","Apple","Withings"]);

Sess2.MEAN.alltr = standardizeMissing(Sess2.MEAN.alltr,0);
Sess2.MEDIAN.alltr = standardizeMissing(Sess2.MEDIAN.alltr,0);
Sess2.SD.alltr = standardizeMissing(Sess2.SD.alltr,0);
Sess2.p25.alltr = standardizeMissing(Sess2.p25.alltr,0);
Sess2.p25.alltr = standardizeMissing(Sess2.p75.alltr,0);
Sess2.MIN.alltr = standardizeMissing(Sess2.MIN.alltr,0);
Sess2.MAX.alltr = standardizeMissing(Sess2.MAX.alltr,0);


for idx_user = 1:size(users_DirsNames,2)

    % assign the idUser in tables of structures of errorMetrics
    Sess2.MEAN.all {idx_user,1} = users_DirsNames(idx_user);
    Sess2.MEDIAN.all {idx_user,1} = users_DirsNames(idx_user);
    Sess2.SD.all {idx_user,1} = users_DirsNames(idx_user);
    Sess2.p25.all {idx_user,1} = users_DirsNames(idx_user);
    Sess2.p75.all {idx_user,1} = users_DirsNames(idx_user);
    Sess2.MIN.all {idx_user,1} = users_DirsNames(idx_user);
    Sess2.MAX.all {idx_user,1} = users_DirsNames(idx_user);

    for tr = 1 : length(intervals.start)-1
        Sess2.MEAN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        Sess2.MEDIAN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        Sess2.SD.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        Sess2.p25.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        Sess2.p75.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        Sess2.MIN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
        Sess2.MAX.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,1} = users_DirsNames(idx_user);
    end

    for hrzone = 1 : length(intervals.start)
        Sess2.MEAN.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        Sess2.MEDIAN.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        Sess2.SD.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        Sess2.p25.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        Sess2.p75.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        Sess2.MIN.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
        Sess2.MAX.zone.(sprintf('z%d',hrzone-1)) {idx_user,1} = users_DirsNames(idx_user);
    end

    Sess2.MEAN.allzone {idx_user,1} = users_DirsNames(idx_user);
    Sess2.MEDIAN.allzone {idx_user,1} = users_DirsNames(idx_user);
    Sess2.SD.allzone {idx_user,1} = users_DirsNames(idx_user);
    Sess2.p25.allzone {idx_user,1} = users_DirsNames(idx_user);
    Sess2.p75.allzone {idx_user,1} = users_DirsNames(idx_user);
    Sess2.MIN.allzone {idx_user,1} = users_DirsNames(idx_user);
    Sess2.MAX.allzone {idx_user,1} = users_DirsNames(idx_user);

    Sess2.MEAN.alltr {idx_user,1} = users_DirsNames(idx_user);
    Sess2.MEDIAN.alltr {idx_user,1} = users_DirsNames(idx_user);
    Sess2.SD.alltr {idx_user,1} = users_DirsNames(idx_user);
    Sess2.p25.alltr {idx_user,1} = users_DirsNames(idx_user);
    Sess2.p75.alltr {idx_user,1} = users_DirsNames(idx_user);
    Sess2.MIN.alltr {idx_user,1} = users_DirsNames(idx_user);
    Sess2.MAX.alltr {idx_user,1} = users_DirsNames(idx_user);

    % access the sessions of each user
    userPath = fullfile(dataPath,users_DirsNames(idx_user));
    user_fd = dir(userPath);
    user_Flags = [user_fd.isdir];
    sessions_Dirs = user_fd(user_Flags);
    sessions_Dirs = sessions_Dirs(3:end); % keep only valid folders

    % sort sessions alphabetically
    [~,ind] = sort(cellfun(@(x) str2num(char(regexp(x,'\d*','match'))),{sessions_Dirs.name}));
    sessions_Dirs = sessions_Dirs(ind);
    sessions_DirsNames = {sessions_Dirs.name};

    sessions_DirsNames = string(sessions_DirsNames);
    sessions_DirsNames(startsWith(sessions_DirsNames,'Questionnaires')) = []; %remove the Questionnaires folder when i iterate sessions

    % second session of the user
    idx_session = 2;
    csvs = dir(fullfile(userPath,sessions_DirsNames(idx_session)));
    % get only the folder names into a cell array
    csv_names = {csvs(3:end).name};
    csv_names = string(csv_names);

    tf_intervals = startsWith(csv_names, 'intervals');
    intervals = readtable(fullfile(userPath,sessions_DirsNames(idx_session), csv_names(tf_intervals)),"VariableNamingRule",'preserve');
    time = sort([intervals.start;intervals.end]); %put time of intervals in an array
    retInt = retimeINT(time,5); %Retime intervals to the new intervals considering new grid with timestep
    shiftstart = retInt(1:2:end-1);
    shiftend = retInt(2:2:end);

    tf_polar = startsWith(csv_names,'polar'); %% take polar file name
    polar = readtimetable(fullfile(userPath,sessions_DirsNames(idx_session), csv_names(tf_polar)),"VariableNamingRule",'preserve');
    polar = retimeHR(polar,timestep,shiftstart(1),shiftend(end)); %retime Polar considering the new grid

    k=3; %counter for columns to save data of devices

    for i = 1:length(devices)
        tf = startsWith(csv_names,devices{i},'IgnoreCase',true); %% take file name containing devices data ignoring case sensitive
        if(ismember(1,tf) == 1)
            data = readtimetable(fullfile(userPath,sessions_DirsNames(idx_session), csv_names(tf)),"VariableNamingRule",'preserve');
            data = retimeHR(data,timestep,shiftstart(1),shiftend(end)); %retime smartwatch considering the new grid

            % Removing here zone/transitions after seeing in plots
            switch idx_user
                case 6
                    % Apple: only HR0,HR1,TR01,TR12
                    if (i==1) %Apple
                        data.rate(~isbetween(data.time,shiftstart(1),shiftstart(3),'openright'))=NaN;
                    end
                case 7
                    % Apple/Withings/Apple/Withings: NO HR0,TR01
                    data.rate(~isbetween(data.time,shiftstart(2),shiftend(end)))=NaN;
                    % Remove Fitbit (outlier)
                    if (i==2) data.rate(:)=NaN; end
                case 8
                    if(i==1 || i==4) %Apple/Withings: NO HR0,TR01
                        data.rate(~isbetween(data.time,shiftstart(2),shiftend(end)))=NaN;
                    end
                    if(i==2 || i==3) %Apple/Withings: NO HR0
                        data.rate(~isbetween(data.time,shiftend(1),shiftend(end),'openleft'))=NaN;
                    end

            end
            % Now calculating the Statistics

            % 1) Entire signal (from the start of the first interval to
            % the end of the session or last interval. Transitions are
            % included)

            Sess2.MEAN.all {idx_user,2} = nanmean(polar.rate);
            Sess2.MEDIAN.all {idx_user,2} = nanmedian(polar.rate);
            Sess2.SD.all {idx_user,2} = nanstd(polar.rate);
            Sess2.p25.all {idx_user,2} = prctile(polar.rate,25);
            Sess2.p75.all {idx_user,2} = prctile(polar.rate,75);
            if(~isempty(polar.rate(~isnan(polar.rate)))) %if not empty (excluding NaN)
                Sess2.MIN.all {idx_user,2} = min(polar.rate,[],'omitnan');
                Sess2.MAX.all {idx_user,2} = max(polar.rate,[],'omitnan');
            end


            Sess2.MEAN.all {idx_user,k} = nanmean(data.rate);
            Sess2.MEDIAN.all {idx_user,k} = nanmedian(data.rate);
            Sess2.SD.all {idx_user,k} = nanstd(data.rate);
            Sess2.p25.all {idx_user,k} = prctile(data.rate,25);
            Sess2.p75.all {idx_user,k} = prctile(data.rate,75);
            if(~isempty(data.rate(~isnan(data.rate)))) %if not empty (excluding NaN)
                Sess2.MIN.all {idx_user,k} = min(data.rate,[],'omitnan');
                Sess2.MAX.all {idx_user,k} = max(data.rate,[],'omitnan');
            end



            % 2) Each transition
            for tr = 1 : length(intervals.start)-1
                trpolar = polar(isbetween(polar.time,shiftend(tr),shiftstart(tr+1),'open'),:);
                trdata = data(isbetween(data.time,shiftend(tr),shiftstart(tr+1),'open'),:);


                Sess2.MEAN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,2} = nanmean(trpolar.rate);
                Sess2.MEDIAN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,2} = nanmedian(trpolar.rate);
                Sess2.SD.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,2} = nanstd(trpolar.rate);
                Sess2.p25.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,2} = prctile(trpolar.rate,25);
                Sess2.p75.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,2} = prctile(trpolar.rate,75);
                if(~isempty(trpolar.rate(~isnan(trpolar.rate)))) %if not empty (excluding NaN)
                    Sess2.MIN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,2} = min(trpolar.rate,[],'omitnan');
                    Sess2.MAX.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,2} = max(trpolar.rate,[],'omitnan');
                end

                Sess2.MEAN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,k} = nanmean(trdata.rate);
                Sess2.MEDIAN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,k} = nanmedian(trdata.rate);
                Sess2.SD.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,k} = nanstd(trdata.rate);
                Sess2.p25.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,k} = prctile(trdata.rate,25);
                Sess2.p75.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,k} = prctile(trdata.rate,75);
                if(~isempty(trdata.rate(~isnan(trdata.rate)))) %if not empty (excluding NaN)
                    Sess2.MIN.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,k} = min(trdata.rate,[],'omitnan');
                    Sess2.MAX.transition.(sprintf('tr%d%d',tr-1,tr)) {idx_user,k} = max(trdata.rate,[],'omitnan');
                end
            end

            % 3) Each heart rate zone (interval)
            for hrzone = 1 : length(intervals.start)
                hrzonepolar = polar(isbetween(polar.time,shiftstart(hrzone),shiftend(hrzone)),:);
                hrzonedata = data(isbetween(data.time,shiftstart(hrzone),shiftend(hrzone)),:);

                if(idx_user==7 && hrzone ==1) %HR0 7 is NaN
                    hrzonedata.rate = NaN(size(hrzonedata,1),1);
                end

                Sess2.MEAN.zone.(sprintf('z%d',hrzone-1)) {idx_user,2} = nanmean(hrzonepolar.rate);
                Sess2.MEDIAN.zone.(sprintf('z%d',hrzone-1)) {idx_user,2} = nanmedian(hrzonepolar.rate);
                Sess2.SD.zone.(sprintf('z%d',hrzone-1)) {idx_user,2} = nanstd(hrzonepolar.rate);
                Sess2.p25.zone.(sprintf('z%d',hrzone-1)) {idx_user,2} = prctile(hrzonepolar.rate,25);
                Sess2.p75.zone.(sprintf('z%d',hrzone-1)) {idx_user,2} = prctile(hrzonepolar.rate,75);
                if(~isempty(hrzonepolar.rate(~isnan(hrzonepolar.rate)))) %if not empty (excluding NaN)
                    Sess2.MIN.zone.(sprintf('z%d',hrzone-1)) {idx_user,2} = min(hrzonepolar.rate,[],'omitnan');
                    Sess2.MAX.zone.(sprintf('z%d',hrzone-1)) {idx_user,2} = max(hrzonepolar.rate,[],'omitnan');
                end

                Sess2.MEAN.zone.(sprintf('z%d',hrzone-1)) {idx_user,k} = nanmean(hrzonedata.rate);
                Sess2.MEDIAN.zone.(sprintf('z%d',hrzone-1)) {idx_user,k} = nanmedian(hrzonedata.rate);
                Sess2.SD.zone.(sprintf('z%d',hrzone-1)) {idx_user,k} = nanstd(hrzonedata.rate);
                Sess2.p25.zone.(sprintf('z%d',hrzone-1)) {idx_user,k} = prctile(hrzonedata.rate,25);
                Sess2.p75.zone.(sprintf('z%d',hrzone-1)) {idx_user,k} = prctile(hrzonedata.rate,75);
                if(~isempty(hrzonedata.rate(~isnan(hrzonedata.rate)))) %if not empty (excluding NaN)
                    Sess2.MIN.zone.(sprintf('z%d',hrzone-1)) {idx_user,k} = min(hrzonedata.rate,[],'omitnan');
                    Sess2.MAX.zone.(sprintf('z%d',hrzone-1)) {idx_user,k} = max(hrzonedata.rate,[],'omitnan');
                end

            end

            % 4) All zone together
            allzonepolar = [];
            allzonedata = [];
            for hrzone = 1 : length(intervals.start)
                allzonepolar = [allzonepolar;polar(isbetween(polar.time,shiftstart(hrzone),shiftend(hrzone)),:)];
                allzonedata = [allzonedata;data(isbetween(data.time,shiftstart(hrzone),shiftend(hrzone)),:)];
            end
            Sess2.MEAN.allzone {idx_user,2} = nanmean(allzonepolar.rate);
            Sess2.MEDIAN.allzone {idx_user,2} = nanmedian(allzonepolar.rate);
            Sess2.SD.allzone {idx_user,2} = nanstd(allzonepolar.rate);
            Sess2.p25.allzone {idx_user,2} = prctile(allzonepolar.rate,25);
            Sess2.p75.allzone {idx_user,2} = prctile(allzonepolar.rate,75);
            if(~isempty(allzonepolar.rate(~isnan(allzonepolar.rate)))) %if not empty (excluding NaN)
                Sess2.MIN.allzone {idx_user,2} = min(allzonepolar.rate,[],'omitnan');
                Sess2.MAX.allzone {idx_user,2} = max(allzonepolar.rate,[],'omitnan');
            end

            Sess2.MEAN.allzone {idx_user,k}= nanmean(allzonedata.rate);
            Sess2.MEDIAN.allzone {idx_user,k} = nanmedian(allzonedata.rate);
            Sess2.SD.allzone {idx_user,k}= nanstd(allzonedata.rate);
            Sess2.p25.allzone {idx_user,k} = prctile(allzonedata.rate,25);
            Sess2.p75.allzone {idx_user,k} = prctile(allzonedata.rate,75);
            if(~isempty(allzonedata.rate(~isnan(allzonedata.rate)))) %if not empty (excluding NaN)
                Sess2.MIN.allzone {idx_user,k} = min(allzonedata.rate,[],'omitnan');
                Sess2.MAX.allzone {idx_user,k} = max(allzonedata.rate,[],'omitnan');
            end



            % 5) All the transitions together
            alltrpolar = [];
            alltrdata = [];
            for tr = 1 : length(intervals.start)-1
                alltrpolar = [alltrpolar;polar(isbetween(polar.time,shiftend(tr),shiftstart(tr+1),'open'),:)];
                alltrdata = [alltrdata;data(isbetween(data.time,shiftend(tr),shiftstart(tr+1),'open'),:)];
            end
            Sess2.MEAN.alltr {idx_user,2} = nanmean(alltrpolar.rate);
            Sess2.MEDIAN.alltr {idx_user,2} = nanmedian(alltrpolar.rate);
            Sess2.SD.alltr {idx_user,2} = nanstd(alltrpolar.rate);
            Sess2.p25.alltr {idx_user,2} = prctile(alltrpolar.rate,25);
            Sess2.p75.alltr {idx_user,2} = prctile(alltrpolar.rate,75);
            if(~isempty(alltrpolar.rate(~isnan(alltrpolar.rate)))) %if not empty (excluding NaN)
                Sess2.MIN.alltr {idx_user,2} = min(alltrpolar.rate,[],'omitnan');
                Sess2.MAX.alltr {idx_user,2} = max(alltrpolar.rate,[],'omitnan');
            end

            Sess2.MEAN.alltr {idx_user,k}= nanmean(alltrdata.rate);
            Sess2.MEDIAN.alltr {idx_user,k} = nanmedian(alltrdata.rate);
            Sess2.SD.alltr {idx_user,k}= nanstd(alltrdata.rate);
            Sess2.p25.alltr {idx_user,k} = prctile(alltrdata.rate,25);
            Sess2.p75.alltr {idx_user,k} = prctile(alltrdata.rate,75);
            if(~isempty(alltrdata.rate(~isnan(alltrdata.rate)))) %if not empty (excluding NaN)
                Sess2.MIN.alltr {idx_user,k} = min(alltrdata.rate,[],'omitnan');
                Sess2.MAX.alltr {idx_user,k} = max(alltrdata.rate,[],'omitnan');
            end

            k=k+1;
        end
    end
end

%% Correct Error Metrics (Inf --> NaN)
COD.transition.tr01.Apple(isinf(COD.transition.tr01.Apple))=NaN;
COD.transition.tr01.Fitbit(isinf(COD.transition.tr01.Fitbit))=NaN;
COD.transition.tr01.Garmin(isinf(COD.transition.tr01.Garmin))=NaN;
COD.transition.tr01.Withings(isinf(COD.transition.tr01.Withings))=NaN;

COD.transition.tr12.Apple(isinf(COD.transition.tr12.Apple))=NaN;
COD.transition.tr12.Fitbit(isinf(COD.transition.tr12.Fitbit))=NaN;
COD.transition.tr12.Garmin(isinf(COD.transition.tr12.Garmin))=NaN;
COD.transition.tr12.Withings(isinf(COD.transition.tr12.Withings))=NaN;

COD.transition.tr23.Apple(isinf(COD.transition.tr23.Apple))=NaN;
COD.transition.tr23.Fitbit(isinf(COD.transition.tr23.Fitbit))=NaN;
COD.transition.tr23.Garmin(isinf(COD.transition.tr23.Garmin))=NaN;
COD.transition.tr23.Withings(isinf(COD.transition.tr23.Withings))=NaN;

COD.transition.tr34.Apple(isinf(COD.transition.tr34.Apple))=NaN;
COD.transition.tr34.Fitbit(isinf(COD.transition.tr34.Fitbit))=NaN;
COD.transition.tr34.Garmin(isinf(COD.transition.tr34.Garmin))=NaN;
COD.transition.tr34.Withings(isinf(COD.transition.tr34.Withings))=NaN;

COD.transition.tr45.Apple(isinf(COD.transition.tr45.Apple))=NaN;
COD.transition.tr45.Fitbit(isinf(COD.transition.tr45.Fitbit))=NaN;
COD.transition.tr45.Garmin(isinf(COD.transition.tr45.Garmin))=NaN;
COD.transition.tr45.Withings(isinf(COD.transition.tr45.Withings))=NaN;

%% Boxplot

figure,
tlo = tiledlayout(2,2);
tlo.TileSpacing = 'compact';
tlo.Padding = 'compact';
ax = nexttile(tlo); 
boxplot(ax, COD.all{:,2:end},'Labels',{'Apple','Fitbit','Garmin','Withings'}), grid on
title('COD (%)') 
ax2 = nexttile(tlo); 
boxplot(ax2, MAE.all{:,2:end},'Labels',{'Apple','Fitbit','Garmin','Withings'}), grid on
title('MAE') 
ax3 = nexttile(tlo);
boxplot(ax3, MARD.all{:,2:end},'Labels',{'Apple','Fitbit','Garmin','Withings'}), grid on
title('MARD') 
ax4 = nexttile(tlo);
boxplot(ax4, RMSE.all{:,2:end},'Labels',{'Apple','Fitbit','Garmin','Withings'}), grid on
title('RMSE') 
title(tlo,'Error metrics: Overall')

%
figure,
tlo = tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

ax = nexttile(tlo); 
boxplot(ax, COD.allzone{:,2:end},'Labels',{'Apple','Fitbit','Garmin','Withings'}), grid on
title('COD (%)') 
ax2 = nexttile(tlo); 
boxplot(ax2, MAE.allzone{:,2:end},'Labels',{'Apple','Fitbit','Garmin','Withings'}), grid on
title('MAE') 
ax3 = nexttile(tlo);
boxplot(ax3, MARD.allzone{:,2:end},'Labels',{'Apple','Fitbit','Garmin','Withings'}), grid on
title('MARD') 
ax4 = nexttile(tlo);
boxplot(ax4, RMSE.allzone{:,2:end},'Labels',{'Apple','Fitbit','Garmin','Withings'}), grid on
title('RMSE') 
title(tlo,'Error metrics: All Zones')


%
figure,
tlo = tiledlayout(2,2);
tlo.TileSpacing = 'compact';
tlo.Padding = 'compact';
ax = nexttile(tlo); 
boxplot(ax, COD.alltr{:,2:end},'Labels',{'Apple','Fitbit','Garmin','Withings'}), grid on
title('COD (%)') 
ax2 = nexttile(tlo); 
boxplot(ax2, MAE.alltr{:,2:end},'Labels',{'Apple','Fitbit','Garmin','Withings'}), grid on
title('MAE') 
ax3 = nexttile(tlo);
boxplot(ax3, MARD.alltr{:,2:end},'Labels',{'Apple','Fitbit','Garmin','Withings'}), grid on
title('MARD') 
ax4 = nexttile(tlo);
boxplot(ax4, RMSE.alltr{:,2:end},'Labels',{'Apple','Fitbit','Garmin','Withings'}), grid on
title('RMSE') 
title(tlo,'Error metrics: All Transitions')

%% Boxplot Zones
figure,
tlo = tiledlayout(2,2);
tlo.TileSpacing = 'compact';
tlo.Padding = 'compact';
ax = nexttile(tlo); 
boxplotGroup(ax,{COD.zone.z0{:,2:end},COD.zone.z1{:,2:end},COD.zone.z2{:,2:end},COD.zone.z3{:,2:end},COD.zone.z4{:,2:end},COD.zone.z5{:,2:end}},'groupLines', true,'primaryLabels',{'z0','z1','z2','z3','z4','z5'},'secondaryLabels', {'Apple','Fitbit','Garmin','Withings'}), grid on
title('COD (%)') 
ax2 = nexttile(tlo); 
boxplotGroup(ax2,{MAE.zone.z0{:,2:end},MAE.zone.z1{:,2:end},MAE.zone.z2{:,2:end},MAE.zone.z3{:,2:end},MAE.zone.z4{:,2:end},MAE.zone.z5{:,2:end}},'groupLines', true,'primaryLabels',{'z0','z1','z2','z3','z4','z5'},'secondaryLabels', {'Apple','Fitbit','Garmin','Withings'}), grid on
title('MAE') 
ax3 = nexttile(tlo);
boxplotGroup(ax3,{MARD.zone.z0{:,2:end},MARD.zone.z1{:,2:end},MARD.zone.z2{:,2:end},MARD.zone.z3{:,2:end},MARD.zone.z4{:,2:end},MARD.zone.z5{:,2:end}},'groupLines', true,'primaryLabels',{'z0','z1','z2','z3','z4','z5'},'secondaryLabels', {'Apple','Fitbit','Garmin','Withings'}), grid on
title('MARD') 
ax4 = nexttile(tlo);
boxplotGroup(ax4,{RMSE.zone.z0{:,2:end},RMSE.zone.z1{:,2:end},RMSE.zone.z2{:,2:end},RMSE.zone.z3{:,2:end},RMSE.zone.z4{:,2:end},RMSE.zone.z5{:,2:end}},'groupLines', true,'primaryLabels',{'z0','z1','z2','z3','z4','z5'},'secondaryLabels', {'Apple','Fitbit','Garmin','Withings'}), grid on
title('RMSE')
title(tlo,'Error metrics: Zones')
%% Boxplot Transitions
figure,
tlo = tiledlayout(2,2);
tlo.TileSpacing = 'compact';
tlo.Padding = 'compact';
ax = nexttile(tlo); 
boxplotGroup(ax,{COD.transition.tr01{:,2:end},COD.transition.tr12{:,2:end},COD.transition.tr23{:,2:end},COD.transition.tr34{:,2:end},COD.transition.tr45{:,2:end}},'groupLines', true,'primaryLabels',{'01','12','23','34','45'},'secondaryLabels', {'Apple','Fitbit','Garmin','Withings'}), grid on
title('COD (%)') 
ax2 = nexttile(tlo); 
boxplotGroup(ax2,{MAE.transition.tr01{:,2:end},MAE.transition.tr12{:,2:end},MAE.transition.tr23{:,2:end},MAE.transition.tr34{:,2:end},MAE.transition.tr45{:,2:end}},'groupLines', true,'primaryLabels',{'01','12','23','34','45'},'secondaryLabels', {'Apple','Fitbit','Garmin','Withings'}), grid on
title('MAE') 
ax3 = nexttile(tlo);
boxplotGroup(ax3,{MARD.transition.tr01{:,2:end},MARD.transition.tr12{:,2:end},MARD.transition.tr23{:,2:end},MARD.transition.tr34{:,2:end},MARD.transition.tr45{:,2:end}},'groupLines', true,'primaryLabels',{'01','12','23','34','45'},'secondaryLabels', {'Apple','Fitbit','Garmin','Withings'}), grid on
title('MARD') 
ax4 = nexttile(tlo);
boxplotGroup(ax4,{RMSE.transition.tr01{:,2:end},RMSE.transition.tr12{:,2:end},RMSE.transition.tr23{:,2:end},RMSE.transition.tr34{:,2:end},RMSE.transition.tr45{:,2:end}},'groupLines', true,'primaryLabels',{'01','12','23','34','45'},'secondaryLabels', {'Apple','Fitbit','Garmin','Withings'}), grid on
title('RMSE')
title(tlo,'Error metrics: Transitions')
