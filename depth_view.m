classdef depth_view < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                  matlab.ui.Figure
        YposAX                    matlab.ui.control.UIAxes
        THposAX                   matlab.ui.control.UIAxes
        ColorAX                   matlab.ui.control.UIAxes
        PointCloudAX              matlab.ui.control.UIAxes
        StartButton               matlab.ui.control.Button
        StopButton                matlab.ui.control.Button
        Up1                       matlab.ui.control.Button
        Down1                     matlab.ui.control.Button
        Up2                       matlab.ui.control.Button
        Down2                     matlab.ui.control.Button
        Left1                     matlab.ui.control.Button
        Right1                    matlab.ui.control.Button
        Left2                     matlab.ui.control.Button
        Right2                    matlab.ui.control.Button
    end

    properties (Access = private) %, Hidden = true)
        MeTimer            % Timer object
        DrawFlag           % Boolean 
        Cfg                % Realsense.config
        Pipe               % Realsense.pipeline
        Colorizer          % Realsense.colorizer
        PointCloud         % Realsense.pointcloud
        Profile            % Realsense.profile
        Frameset           % Realsense.frameset
        hhDepth            % Image
        hhColor            % Image
        hhCloud
        cy1
        cy2
        cx1
        cx2
        y1line
        y2line
        x1line
        x2line
        tform      
        player
        li_y
        li_th
    end

    % Callbacks that handle component events
    methods (Access = private)
        
        function MeTimerFcn(app,varargin)

        if ( app.DrawFlag == 1 )
                      
            % lock drawing process
            app.DrawFlag = 0;

            % Get frameset
            app.Frameset = app.Pipe.wait_for_frames();

            % Color           
            color_frame = app.Frameset.get_color_frame();
            color_data = color_frame.get_data();
            color_img = permute(reshape(color_data',[3,color_frame.get_width(),color_frame.get_height()]),[3 2 1]);
            [ki,kj] = size(app.hhColor);

            if ki*kj < 1

                app.hhColor = imshow(color_img,'Parent',app.ColorAX,'XData', [1 app.ColorAX.Position(3)], ...
                                         'YData', [1 app.ColorAX.Position(4)]);
                app.y1line = yline(app.cy1,'Color','green','LineWidth',2,'Parent',app.ColorAX);
                app.y2line = yline(app.cy2,'Color','red','LineWidth',2,'Parent',app.ColorAX);
                app.x1line = xline(app.cx1,'Color','cyan','LineWidth',2,'Parent',app.ColorAX);
                app.x2line = xline(app.cx2,'Color','magenta','LineWidth',2,'Parent',app.ColorAX);

            else

                app.hhColor.CData = color_img;
                app.y1line.Value = app.cy1;
                app.y2line.Value = app.cy2;
                app.x1line.Value = app.cx1;
                app.x2line.Value = app.cx2;

            end

            % PointCloud Graph 

            depth_frame = app.Frameset.get_depth_frame();

            if depth_frame.logical()

                points = app.PointCloud.calculate(depth_frame);           
                vertices = points.get_vertices();
                ptcl = pointCloud(vertices(rem(1:height(vertices),30)==0,:));

                ptcl_out = pctransform(ptcl,app.tform);
                indices = findPointsInROI(ptcl_out,[-(320-app.cx1)/1000 (app.cx2-320)/1000 0.1 0.8 -(app.cy2-180)/1000 (180-app.cy1)/1000]);
                ptcl_zone = select(ptcl_out,indices);
                ptcl_zone.Color = lab2uint8(repmat([128 128 128],ptcl_zone.Count,1));
                mean_zone = mean(ptcl_zone.Location);

                indices_left = findPointsInROI(ptcl_zone,[-(320-app.cx1)/1000 -((320-app.cx1)/1000)+0.05  0.1 0.8 -(app.cy2-180)/1000 (180-app.cy1)/1000]);
                ptcl_left = select(ptcl_zone,indices_left);
                ptcl_left.Color = lab2uint8(repmat([255 0 0],ptcl_left.Count,1));
                mean_left = mean(ptcl_left.Location);

                indices_right = findPointsInROI(ptcl_zone,[((app.cx2-320)/1000)-0.05 (app.cx2-320)/1000 0.1 0.8 -(app.cy2-180)/1000 (180-app.cy1)/1000]);
                ptcl_right = select(ptcl_zone,indices_right);
                ptcl_right.Color = lab2uint8(repmat([200 0 200],ptcl_right.Count,1));
                mean_right = mean(ptcl_right.Location);

                if ki*kj < 1
                    
%                     color_stream = app.Profile.get_stream(realsense.stream.color);
%                     color_video_stream = color_stream.as('video_stream_profile');
%                     intr = color_video_stream.get_intrinsics();
% 
%                     imagePoints = worldToImage(cameraIntrinsics([intr.fx intr.fy],[intr.ppx intr.ppy],[360 640]),[1 0 0; 0 0 -1; 0 1 0],[0 0 0],ptcl_zone.Location);
                    
                    app.player = pcplayer([-0.320 0.320], [0.1 0.8], [-0.18 0.18],'Parent',app.PointCloudAX);
                    view(app.player,pccat([ptcl_zone ptcl_right ptcl_left]));

                    % Ypos Graph

                    app.li_y = animatedline(app.YposAX,'Color','g');
                    addpoints(app.li_y,toc,mean_zone(2));
                    drawnow limitrate
                    app.YposAX.XLim = [toc-10 toc+10];
                    

                    % THpos Graph

                    app.li_th = animatedline(app.THposAX,'Color','g');
                    addpoints(app.li_th,toc,0);
                    drawnow limitrate
                    app.THposAX.XLim = [toc-10 toc+10];
                    

                elseif length(mean_left) == 3 && length(mean_right) == 3
                    
                    u = (mean_left-mean_right)/norm(mean_left-mean_right);
                    line = mean_right + (0:0.0005:norm(mean_left-mean_right))'*u; 
                    
                    ptcl_line = pointCloud(line); 
                    ptcl_line.Color = lab2uint8(repmat([255 255 0],ptcl_line.Count,1)); 

                    view(app.player,pccat([ptcl_zone ptcl_line ptcl_right ptcl_left]));

                    % Ypos Graph

                    addpoints(app.li_y,toc,mean_zone(2));
                    drawnow limitrate
                    app.YposAX.XLim = [toc-10 toc+10]; 
                    app.YposAX.Title.String = ['Y Position = ' num2str(mean_zone(2))];
%                     app.YposAX.Legend.Title.String = num2str(mean_zone(2));

                    % THpos Graph

                    angle = real(asind((mean_left(2)-mean_right(2))/(mean_left(1)-mean_right(1))));
                    addpoints(app.li_th,toc, angle);
                    drawnow limitrate
                    app.THposAX.XLim = [toc-10 toc+10];
                    app.THposAX.Title.String = ['Angle Position = ' num2str(angle)];
%                     app.THposAX.Legend.Title.String = num2str(angle);

                end
            end

           % unlock drawing process
           app.DrawFlag = 1;
           pause(0.001);   
           
       end       
        end

        % Executes after component creation
        function StartUpFunc(app)
               % Create Realsense items

               app.Cfg = realsense.config();
               app.Cfg.enable_stream(realsense.stream.depth,424,240,...
                    realsense.format.z16,30);
               app.Cfg.enable_stream(realsense.stream.color,424,240,...
                    realsense.format.rgb8,30)
               app.Pipe = realsense.pipeline();
               app.Colorizer = realsense.colorizer();
               app.PointCloud = realsense.pointcloud();
               app.Profile = app.Pipe.start(app.Cfg);

               % Create timer object

               kFramePerSecond = 30.0;                                  % Number of frames per second
               Period = double(int64(1000.0 / kFramePerSecond))/1000.0+0.001; % Frame Rate
               
               
               tic
               app.MeTimer = timer(...
                 'ExecutionMode', 'fixedSpacing', ...  % 'fixedRate', ...     % Run timer repeatedly
                 'Period', Period, ...                 % Period (second)
                 'BusyMode', 'drop', ... %'queue',...  % Queue timer callbacks when busy
                 'TimerFcn', @app.MeTimerFcn);

               app.DrawFlag = 0;
               app.hhDepth = [];
               app.hhColor = [];             
               app.tform = rigid3d([1 0 0; 0 0 -1; 0 1 0],[0 0 0]); % 0.15
               
        end

        % Button pushed function: start timer
        function onStartButton(app, event)
            % If timer is not running, start it
            if strcmp(app.MeTimer.Running, 'off')
               app.DrawFlag = 1;
               start(app.MeTimer);
            end
        end
        
        function onUp1(app, event)            
            
            app.cy1 = app.cy1 - 2;
                               
        end
        
        function onUp2(app, event)
            
            app.cy2 = app.cy2 - 2;
                      
        end
        
        function onDown1(app, event)
            
            app.cy1 = app.cy1 + 2;
            
        end
        
        function onDown2(app, event)
            
            app.cy2 = app.cy2 + 2;
            
        end
        
        function onRight1(app, event)
            
            app.cx1 = app.cx1 + 2;
            
        end
        
        function onRight2(app, event)
            
            app.cx2 = app.cx2 + 2;
            
        end
        
        function onLeft1(app, event)
            
            app.cx1 = app.cx1 - 2;
            
        end
        
        function onLeft2(app, event)
            
            app.cx2 = app.cx2 - 2;
            
        end

        % Button pushed function: stop timer
        function onStopButton(app, event)
            app.DrawFlag = 0;
            stop(app.MeTimer);
        end

        %Close request UIFigure function
        function UIFigureCloseRequest(app,event)
            app.DrawFlag = 0;
            stop(app.MeTimer);
            delete(app.MeTimer);
            app.Pipe.stop();
            delete(app.Profile);
            delete(app.Colorizer);
            delete(app.Pipe);
            delete(app.Cfg);
            delete(app);
        end

    end

    % Component initialization
    methods (Access = private)
        
        % Create UIFigure and components
        function createComponents(app)
            
            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('WindowState','maximized','Visible','on');
            app.UIFigure.Name = 'Gait Analysis';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app,@UIFigureCloseRequest);
            setAutoResize(app,app.UIFigure,false);

            % Create ColorAX
            app.ColorAX = uiaxes(app.UIFigure);
            app.ColorAX.Position = [10 420 640 360];
            
            % Create YposAX
            app.YposAX = uiaxes(app.UIFigure);
            app.YposAX.Position = [10 230 640 170];
            app.YposAX.Color = 'k';
            app.YposAX.YColor = 'w';
            app.YposAX.XColor = 'w';
            app.YposAX.XGrid = 'on';
            app.YposAX.YGrid = 'on';
            app.YposAX.GridColor = 'w';
            app.YposAX.Title.String = 'Y Position';
            app.YposAX.Title.Color = [1 1 1];
            app.YposAX.YLabel.String = 'y [m]';
            app.YposAX.YLabel.Color = [1 1 1];
            app.YposAX.YLim = [0.1 0.8];
%             legend(app.YposAX);
%             app.YposAX.Legend.Title.Color = [1 1 1];
            
            
            
            
            % Create THposAX
            app.THposAX = uiaxes(app.UIFigure);
            app.THposAX.Position = [10 40 640 170];
            app.THposAX.Color = 'k';
            app.THposAX.YColor = 'w';
            app.THposAX.XColor = 'w';
            app.THposAX.XGrid = 'on';
            app.THposAX.YGrid = 'on';
            app.THposAX.GridColor = 'w';
            app.THposAX.Title.String = 'Angle Position';
            app.THposAX.Title.Color = [1 1 1];
            app.THposAX.XLabel.String = 't [s]';
            app.THposAX.XLabel.Color = [1 1 1];
            app.THposAX.YLabel.String = '\theta [°]';
            app.THposAX.YLabel.Color = [1 1 1];
            app.THposAX.YLim = [-45 45];
%             legend(app.THposAX);
%             app.THposAX.Legend.Title.Color = [1 1 1];
            
            
            % Create PointCloudAX
            app.PointCloudAX = uiaxes(app.UIFigure);
            app.PointCloudAX.Position = [900 125 600 600];
            app.PointCloudAX.XLim = [-0.5 0.5];
            app.PointCloudAX.YLim = [0.1 0.8];
            app.PointCloudAX.ZLim = [-0.5 1.2];
            app.PointCloudAX.Title.String = 'Point Cloud';
            app.PointCloudAX.Title.Color = [1 1 1];
            

            % Create StartButton
            app.StartButton = uibutton(app.UIFigure, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @onStartButton, true);
            app.StartButton.IconAlignment = 'center';
            app.StartButton.Position = [10 10 100 20];
            app.StartButton.Text = 'Start';
            
            % Create Up1
            app.Up1 = uibutton(app.UIFigure, 'push');
            app.Up1.ButtonPushedFcn = createCallbackFcn(app, @onUp1, true);
            app.Up1.IconAlignment = 'center';
            app.Up1.Position = [670 750 50 20];
            app.Up1.Text = 'Up';
            app.Up1.FontColor = 'green';
            app.cy1 = 90; 
            
            % Create Up2
            app.Up2 = uibutton(app.UIFigure, 'push');
            app.Up2.ButtonPushedFcn = createCallbackFcn(app, @onUp2, true);
            app.Up2.IconAlignment = 'center';
            app.Up2.Position = [730 750 50 20];
            app.Up2.Text = 'Up';
            app.Up2.FontColor = 'red';
            app.cy2 = 270;
            
            % Create Down1
            app.Down1 = uibutton(app.UIFigure, 'push');
            app.Down1.ButtonPushedFcn = createCallbackFcn(app, @onDown1, true);
            app.Down1.IconAlignment = 'center';
            app.Down1.Position = [670 720 50 20];
            app.Down1.Text = 'Down';
            app.Down1.FontColor = 'green';
            
            % Create Down2
            app.Down2 = uibutton(app.UIFigure, 'push');
            app.Down2.ButtonPushedFcn = createCallbackFcn(app, @onDown2, true);
            app.Down2.IconAlignment = 'center';
            app.Down2.Position = [730 720 50 20];
            app.Down2.Text = 'Down';
            app.Down2.FontColor = 'red';
            
            % Create Right1
            app.Right1 = uibutton(app.UIFigure, 'push');
            app.Right1.ButtonPushedFcn = createCallbackFcn(app, @onRight1, true);
            app.Right1.IconAlignment = 'center';
            app.Right1.Position = [730 670 50 20];
            app.Right1.Text = 'Right';
            app.Right1.FontColor = 'cyan';
            app.cx1 = 160;
            
            % Create Right2
            app.Right2 = uibutton(app.UIFigure, 'push');
            app.Right2.ButtonPushedFcn = createCallbackFcn(app, @onRight2, true);
            app.Right2.IconAlignment = 'center';
            app.Right2.Position = [730 640 50 20];
            app.Right2.Text = 'Right';
            app.Right2.FontColor = 'magenta';
            app.cx2 = 480;
            
            % Create Left1
            app.Left1 = uibutton(app.UIFigure, 'push');
            app.Left1.ButtonPushedFcn = createCallbackFcn(app, @onLeft1, true);
            app.Left1.IconAlignment = 'center';
            app.Left1.Position = [670 670 50 20];
            app.Left1.Text = 'Left';
            app.Left1.FontColor = 'cyan';
            
            % Create Left2
            app.Left2 = uibutton(app.UIFigure, 'push');
            app.Left2.ButtonPushedFcn = createCallbackFcn(app, @onLeft2, true);
            app.Left2.IconAlignment = 'center';
            app.Left2.Position = [670 640 50 20];
            app.Left2.Text = 'Left';
            app.Left2.FontColor = 'magenta';

            % Create StopButton
            app.StopButton = uibutton(app.UIFigure, 'push');
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @onStopButton, true);
            app.StopButton.IconAlignment = 'center';
            app.StopButton.Position = [120 10 100 20];
            app.StopButton.Text = 'Stop';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)
        
        % Construct app
        function app = depth_view
            
            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Set Startup function - after component creation
            runStartupFcn(app,@StartUpFunc);
            
            if nargout == 0
                clear app
            end            
        end

        % Code that executes before app deletion
        function delete(app)
            
            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end

