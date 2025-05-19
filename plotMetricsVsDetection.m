%% 5｜指標 vs. Detection Scatter
T = readtable('intussusception_sweep_results.xlsx');

figure('Name','Metrics vs. Detection','NumberTitle','off');

% 转换 grouping 变量
G = categorical(T.Detected);

subplot(2,2,1);
boxchart(G, T.VG_min);
xlabel('Detected');
ylabel('VG\_min');
title('VG\_min vs Detection');

subplot(2,2,2);
boxchart(G, T.DR);
xlabel('Detected');
ylabel('DR');
title('Drop Ratio vs Detection');

subplot(2,2,3);
boxchart(G, T.DL);
xlabel('Detected');
ylabel('DL (cm)');
title('Drop Length vs Detection');

subplot(2,2,4);
boxchart(G, T.CP_pos);
xlabel('Detected');
ylabel('CP\_pos (cm)');
title('Change-Point Position vs Detection');

sgtitle('各指標在有無套疊時的分布比較');
