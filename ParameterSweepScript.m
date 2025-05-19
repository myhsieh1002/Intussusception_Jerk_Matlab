function ParameterSweepScript
% ParameterSweepScript  Batch runs Drop parameter sweep using IntussusceptionSimulatorApp
%   - Uses 10 parallel workers
%   - Fixed Prox Speed=3, Dist Speed=1, Prox Elastic=1, Dist Elastic=0.8
%   - Sweeps over SpeedDropWidth, SpeedDropDepth, ElasticDropWidth, ElasticDropDepth
%   - Exports results to Excel with live progress in Command Window

% Fixed parameters
proxSpeed   = 3;
distSpeed   = 1;
proxElastic = 1;
distElastic = 0.8;

% Sweep ranges
spdW = [5,10,15,20,25,30,35,40];      % Speed Drop Width
spdD = [0.5,1,1.5,2,2.5,3,3.5];      % Speed Drop Depth
elpW = [5,10,15,20,25,30,35,40];      % Elastic Drop Width
elpD = [0.1,0.2,0.3,0.4,0.5,0.6,0.7]; % Elastic Drop Depth

% Create grid of combinations
d1 = 1:numel(spdW); d2 = 1:numel(spdD); d3 = 1:numel(elpW); d4 = 1:numel(elpD);
[N1,N2,N3,N4] = ndgrid(d1,d2,d3,d4);
comboCount = numel(N1);

% Preallocate arrays for results
IDs               = zeros(comboCount,1);
SpeedWidthArr     = zeros(comboCount,1);
SpeedDepthArr     = zeros(comboCount,1);
ElasticWidthArr   = zeros(comboCount,1);
ElasticDepthArr   = zeros(comboCount,1);
VG_minArr         = zeros(comboCount,1);
Jerk_minArr       = zeros(comboCount,1);
DRArr             = zeros(comboCount,1);
DLArr             = zeros(comboCount,1);
CP_posArr         = zeros(comboCount,1);
DetectedArr       = false(comboCount,1);

% Setup DataQueue for progress
dq = parallel.pool.DataQueue;
count = 0;
afterEach(dq, @updateProgress);
numTasks = comboCount;

% Launch parallel pool if needed
if isempty(gcp('nocreate'))
    parpool(10);
end

% Parallel sweep
parfor idx = 1:comboCount
    % Determine indices
    i1 = N1(idx); i2 = N2(idx); i3 = N3(idx); i4 = N4(idx);
    % parameters for this run
    sw = spdW(i1); sd = spdD(i2);
    ew = elpW(i3); ed = elpD(i4);
    % simulate one
    metrics = runOne(proxSpeed, distSpeed, proxElastic, distElastic, sw, sd, ew, ed);
    % store into slices
    IDs(idx)             = idx;
    SpeedWidthArr(idx)   = sw;
    SpeedDepthArr(idx)   = sd;
    ElasticWidthArr(idx) = ew;
    ElasticDepthArr(idx) = ed;
    VG_minArr(idx)       = metrics.VG_min;
    Jerk_minArr(idx)     = metrics.Jerk_min;
    DRArr(idx)           = metrics.DR;
    DLArr(idx)           = metrics.DL;
    CP_posArr(idx)       = metrics.CP_pos;
    DetectedArr(idx)     = metrics.Detected;
    % signal progress
    send(dq, idx);
end

% Assemble table and write to Excel
T = table(IDs, SpeedWidthArr, SpeedDepthArr, ElasticWidthArr, ElasticDepthArr, ...
          VG_minArr, Jerk_minArr, DRArr, DLArr, CP_posArr, DetectedArr, ...
          'VariableNames', {'ID','SpeedWidth','SpeedDepth','ElasticWidth','ElasticDepth', ...
                            'VG_min','Jerk_min','DR','DL','CP_pos','Detected'});

writetable(T,'intussusception_sweep_results.xlsx');
fprintf('Sweep completed: %d runs. Results saved to intussusception_sweep_results.xlsx\n',comboCount);

%% Nested function for progress update
    function updateProgress(~)
        count = count + 1;
        fprintf('Progress: %d/%d (%.1f%%)\n', count, numTasks, count/numTasks*100);
    end
end

%% Helper: run one simulation and return metrics
function metrics = runOne(pV,dV,pE,dE, sw, sd, ew, ed)
    app = IntussusceptionSimulatorApp;
    app.UIFigure.Visible = 'off';
    % set fixed inputs
    app.ProxSpeedField.Value      = pV;
    app.DistSpeedField.Value      = dV;
    app.ProxElasticField.Value    = pE;
    app.DistElasticField.Value    = dE;
    % set drop inputs
    app.SpeedDropWidthField.Value   = sw;
    app.SpeedDropDepthField.Value   = sd;
    app.ElasticDropWidthField.Value = ew;
    app.ElasticDropDepthField.Value = ed;
    % run simulation
    app.RunButton.ButtonPushedFcn(app.RunButton, []);
    % extract metrics from UI table
    T = app.ResultsTable.Data;
    if istable(T)
        metrics = table2struct(T,'ToScalar',true);
    else
        % Data as cell array
        C = T;
        colnames = app.ResultsTable.ColumnName;
        for i=1:length(colnames)
            metrics.(colnames{i}) = C{1,i};
        end
    end
    delete(app);
end
