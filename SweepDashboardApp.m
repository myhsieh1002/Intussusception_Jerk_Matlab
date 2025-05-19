classdef IntussusceptionSimulatorApp < matlab.apps.AppBase
    % IntussusceptionSimulatorApp  Streamlined simulator with separate speed & elasticity drops
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        % Parameter fields
        ProxSpeedField       matlab.ui.control.NumericEditField
        DistSpeedField       matlab.ui.control.NumericEditField
        ProxElasticField     matlab.ui.control.NumericEditField
        DistElasticField     matlab.ui.control.NumericEditField
        % Speed drop controls
        SpeedDropPosField    matlab.ui.control.NumericEditField
        SpeedDropWidthField  matlab.ui.control.NumericEditField
        SpeedDropDepthField  matlab.ui.control.NumericEditField
        % Elastic drop controls
        ElasticDropPosField   matlab.ui.control.NumericEditField
        ElasticDropWidthField matlab.ui.control.NumericEditField
        ElasticDropDepthField matlab.ui.control.NumericEditField
        RunButton            matlab.ui.control.Button
        ResultsTable         matlab.ui.control.Table
        SpeedAxes            matlab.ui.control.UIAxes
        ElasticAxes          matlab.ui.control.UIAxes
    end
    properties (Access = private)
        params   % simulation parameters
        results  % time-series profiles
        metrics  % steep-drop metrics
    end

    methods (Access = private)
        function RunButtonPushed(app, ~)
            % Collect inputs
            p  = app.ProxSpeedField.Value;
            d  = app.DistSpeedField.Value;
            pe = app.ProxElasticField.Value;
            de = app.DistElasticField.Value;
            % Speed-specific drop
            spPos   = app.SpeedDropPosField.Value;
            spWidth = app.SpeedDropWidthField.Value;
            spDepth = app.SpeedDropDepthField.Value;
            % Elastic-specific drop
            ePos   = app.ElasticDropPosField.Value;
            eWidth = app.ElasticDropWidthField.Value;
            eDepth = app.ElasticDropDepthField.Value;

            % Build params
            params = struct(...
                'prox_speed', p, 'dist_speed', d, ...
                'prox_elastic', pe, 'dist_elastic', de, ...
                'speed_drop_pos', spPos, 'speed_drop_width', spWidth, 'speed_drop_depth', spDepth, ...
                'elastic_drop_pos', ePos, 'elastic_drop_width', eWidth, 'elastic_drop_depth', eDepth, ...
                'num_steps',1000,'dt',0.02,'simulation_time',20,'num_segments',300,'gastroenteritis_onset',5);
            app.params = params;

            % Positions
            x = linspace(0,params.simulation_time*0 + 300, params.num_segments);
                        % Speed profile with centered drop
            V = linspace(p, d, params.num_segments);
            spHalf = params.speed_drop_width/2;
            spStart = params.speed_drop_pos - spHalf;
            spEnd   = params.speed_drop_pos + spHalf;
            idxS    = find(x>=spStart,1);
            idxSE   = find(x>=spEnd,1);
            if isempty(idxS), idxS = 1; end
            if isempty(idxSE), idxSE = params.num_segments; end
            for k = idxS:idxSE
                frac = (x(k)-spStart)/max(spHalf,eps);
                V(k) = V(k) - params.speed_drop_depth * min(frac,1);
            end
            % beyond drop end, maintain full depth
            if idxSE < params.num_segments
                V(idxSE+1:end) = V(idxSE+1:end) - params.speed_drop_depth;
            end
            % Elasticity profile with centered drop
            E = linspace(pe, de, params.num_segments);
            eHalf = params.elastic_drop_width/2;
            eStart = params.elastic_drop_pos - eHalf;
            eEnd   = params.elastic_drop_pos + eHalf;
            idxE   = find(x>=eStart,1);
            idxEE  = find(x>=eEnd,1);
            if isempty(idxE), idxE = 1; end
            if isempty(idxEE), idxEE = params.num_segments; end
            for k = idxE:idxEE
                frac = (x(k)-eStart)/max(eHalf,eps);
                E(k) = E(k) - params.elastic_drop_depth * min(frac,1);
            end
            if idxEE < params.num_segments
                E(idxEE+1:end) = E(idxEE+1:end) - params.elastic_drop_depth;
            end

            intestine = struct('x',x,'local_speed',V,'local_elasticity',E,...
                'radius',ones(1,params.num_segments),'content',zeros(1,params.num_segments),...
                'wall_position',zeros(2,params.num_segments),'local_amplitude',ones(1,params.num_segments)*0.5,...
                'is_gastroenteritis',false);

            % Simple evolution
            N = params.num_steps; S = params.num_segments;
            res.time = linspace(0,params.simulation_time,N);
            res.speed_profile = zeros(N,S);
            res.elasticity_profile = zeros(N,S);
            res.speed_profile(1,:) = V;
            res.elasticity_profile(1,:) = E;
            for step=2:N
                t=(step-1)*params.dt;
                if t>=params.gastroenteritis_onset && ~intestine.is_gastroenteritis
                    intestine.is_gastroenteritis = true;
                    E = E * 0.7;
                end
                intestine.local_speed = intestine.local_speed + (d-p)/S * 0.005;
                res.speed_profile(step,:)     = intestine.local_speed;
                res.elasticity_profile(step,:) = intestine.local_elasticity;
            end
            app.results = res;

            % Compute metrics
            app.metrics = calcSteepDropMetrics(res.speed_profile(end,:), res.elasticity_profile(end,:), x);
            m = app.metrics; m.Detected = m.DR>0.5;
            app.metrics = m;

            % Display results
            app.ResultsTable.ColumnName = {'VG_min','Jerk_min','DR','DL','CP_pos','HF_energy','Detected'};
            app.ResultsTable.Data = struct2table(app.metrics);

            % Plot
            cla(app.SpeedAxes); plot(app.SpeedAxes,x,res.speed_profile(end,:)); hold(app.SpeedAxes,'on');
            xline(app.SpeedAxes,m.CP_pos,'--k','CP'); hold(app.SpeedAxes,'off');
            title(app.SpeedAxes,'Speed Profile'); xlabel(app.SpeedAxes,'x (cm)');
            cla(app.ElasticAxes); plot(app.ElasticAxes,x,res.elasticity_profile(end,:)); hold(app.ElasticAxes,'on');
            xline(app.ElasticAxes,m.CP_pos,'--k','CP'); hold(app.ElasticAxes,'off');
            title(app.ElasticAxes,'Elasticity Profile'); xlabel(app.ElasticAxes,'x (cm)');
        end
    end
    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Name','Intussusception Simulator','Position',[100 100 900 550]);
            y0=500;
            % Speed inputs
            app.ProxSpeedField    = uieditfield(app.UIFigure,'numeric','Position',[120 y0 80 22],'Value',3);
            uilabel(app.UIFigure,'Text','Prox Speed','Position',[20 y0 80 22]);
            app.DistSpeedField    = uieditfield(app.UIFigure,'numeric','Position',[120 y0-30 80 22],'Value',1);
            uilabel(app.UIFigure,'Text','Dist Speed','Position',[20 y0-30 80 22]);
            % Elastic inputs
            app.ProxElasticField  = uieditfield(app.UIFigure,'numeric','Position',[320 y0 80 22],'Value',0.4);
            uilabel(app.UIFigure,'Text','Prox Elastic','Position',[220 y0 80 22]);
            app.DistElasticField  = uieditfield(app.UIFigure,'numeric','Position',[320 y0-30 80 22],'Value',0.2);
            uilabel(app.UIFigure,'Text','Dist Elastic','Position',[220 y0-30 80 22]);
            % Speed drop controls (left)
            app.SpeedDropPosField    = uieditfield(app.UIFigure,'numeric','Position',[120 y0-80 80 22],'Value',270);
            uilabel(app.UIFigure,'Text','Speed Drop Pos','Position',[20 y0-80 100 22]);
            app.SpeedDropWidthField  = uieditfield(app.UIFigure,'numeric','Position',[120 y0-110 80 22],'Value',10);
            uilabel(app.UIFigure,'Text','Speed Drop Width','Position',[20 y0-110 100 22]);
            app.SpeedDropDepthField  = uieditfield(app.UIFigure,'numeric','Position',[120 y0-140 80 22],'Value',2);
            uilabel(app.UIFigure,'Text','Speed Drop Depth','Position',[20 y0-140 100 22]);
            % Elastic drop controls (right)
            app.ElasticDropPosField    = uieditfield(app.UIFigure,'numeric','Position',[320 y0-80 80 22],'Value',270);
            uilabel(app.UIFigure,'Text','Elastic Drop Pos','Position',[220 y0-80 100 22]);
            app.ElasticDropWidthField  = uieditfield(app.UIFigure,'numeric','Position',[320 y0-110 80 22],'Value',10);
            uilabel(app.UIFigure,'Text','Elastic Drop Width','Position',[220 y0-110 100 22]);
            app.ElasticDropDepthField  = uieditfield(app.UIFigure,'numeric','Position',[320 y0-140 80 22],'Value',2);
            uilabel(app.UIFigure,'Text','Elastic Drop Depth','Position',[220 y0-140 100 22]);
            % Run button
                        % Run button moved below inputs
            app.RunButton = uibutton(app.UIFigure,'push','Text','Run', ...
                'Position',[160 240 80 30], ...
                'ButtonPushedFcn',@(btn,event)app.RunButtonPushed(event));
            % Table and axes
            app.ResultsTable = uitable(app.UIFigure,'Position',[20 20 400 200]);
            app.SpeedAxes   = uiaxes(app.UIFigure,'Position',[460 300 400 220]);
            app.ElasticAxes = uiaxes(app.UIFigure,'Position',[460 40 400 220]);
        end
    end
    methods (Access = public)
        function app = IntussusceptionSimulatorApp
            createComponents(app);
        end
    end
end
