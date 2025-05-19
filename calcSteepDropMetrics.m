function metrics = calcSteepDropMetrics(V,E,x)
% calcSteepDropMetrics Quantifies "steep-drop" characteristics of a
% peristaltic speed profile and its accompanying elasticity curve.
% 
% INPUTS
%   V : 1×N numeric vector of speed (cm/s)
%   E : 1×N numeric vector of elasticity (arbitrary units)
%   x : 1×N numeric vector of positions (cm)
%
% OUTPUT
%   metrics : structure with fields VG_min, Jerk_min, DR, DL, CP_pos, HF_energy

% Basic input validation
assert(isnumeric(V) && isvector(V), 'V must be a numeric vector');
assert(isnumeric(E) && isvector(E), 'E must be a numeric vector');
assert(isnumeric(x) && isvector(x) && numel(x)==numel(V), 'x must be numeric vector same length as V');

N = numel(V);
% Compute spacing
if N>1
    dx = mean(diff(x));
else
    dx = 1;
end

% First derivative (gradient)
VG = diff(V)./dx;
VG_min = min(VG);

% Second derivative (jerk)
Jerk = diff(VG)./dx;
Jerk_min = min(Jerk);

% Change-point detection
try
    [cp_idx,~] = findchangepts(V,'Statistic','linear','MaxNumChanges',1);
catch
    [~,cp_idx] = min([0, abs(Jerk), 0]);
end
CP_pos = x(cp_idx);

% Drop ratio
win = max(3, round(10/dx));
before_idx = max(cp_idx-win,1):max(cp_idx-1,1);
after_idx = min(cp_idx+1,N):min(cp_idx+win,N);
V_before = mean(V(before_idx));
V_after  = mean(V(after_idx));
DR = (V_before - V_after) / max(V_before, eps);

% Drop length
threshold = V_before * 0.98;
left_idx  = cp_idx;
while left_idx>1 && V(left_idx-1)>threshold
    left_idx = left_idx - 1;
end
right_idx = cp_idx;
while right_idx<N && V(right_idx+1)<V(right_idx)
    right_idx = right_idx + 1;
end
DL = x(right_idx) - x(left_idx);

% High-frequency energy (manual integration of PSD)
% Compute PSD via periodogram
Fs = 1/dx;
[pxx,f] = periodogram(V,[],[],Fs);
% Integrate PSD over [0.02, Fs/2]
hf_idx = f >= 0.02 & f <= Fs/2;
HF_energy = trapz(f(hf_idx), pxx(hf_idx));

% Return metrics
metrics = struct('VG_min',    VG_min, ...
                 'Jerk_min',  Jerk_min, ...
                 'DR',        DR, ...
                 'DL',        DL, ...
                 'CP_pos',    CP_pos, ...
                 'HF_energy', HF_energy);
end
