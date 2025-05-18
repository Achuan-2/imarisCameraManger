classdef ImarisCameraManager_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        SelectPathButton     matlab.ui.control.Button
        ImarisPathEditField  matlab.ui.control.EditField
        ImarisPathLabel      matlab.ui.control.Label
        ConnectButton        matlab.ui.control.Button
        StatusLamp           matlab.ui.control.Lamp
        CopyPositionButton   matlab.ui.control.Button
        PastePositionButton  matlab.ui.control.Button
        FitButton            matlab.ui.control.Button
        ResetButton          matlab.ui.control.Button
        RotateButton         matlab.ui.control.Button
        YawEditFieldLabel    matlab.ui.control.Label
        YawEditField         matlab.ui.control.NumericEditField
        PitchEditFieldLabel  matlab.ui.control.Label
        PitchEditField       matlab.ui.control.NumericEditField
        RollEditFieldLabel   matlab.ui.control.Label
        RollEditField        matlab.ui.control.NumericEditField
    end

    % Properties for Imaris connection and data
    properties (Access = private)
        vImarisApplication      % Imaris application object
        viewer                  % Imaris Surpass camera
        quaternion              % Stored quaternion
        position                % Stored position
        dataFile  % File to store path data in app folder

    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.dataFile = fullfile(fileparts(mfilename('fullpath')), 'ImarisCameraManager.mat');
            if exist(app.dataFile, 'file')
                load(app.dataFile, 'imarisPath');
                % Ensure path ends with \XT\matlab
                if ~endsWith(imarisPath, '\XT\matlab', 'IgnoreCase', true)
                    imarisPath = fullfile(imarisPath, 'XT', 'matlab');
                    save(app.dataFile, 'imarisPath');
                end
                if isfolder(imarisPath)
                    app.ImarisPathEditField.Value = imarisPath;
                end
            end
        end

        % Button pushed function: SelectPathButton
        function SelectPathButtonPushed(app, event)
            try
                % Open folder selection dialog
                selectedPath = uigetdir('C:\Program Files\Bitplane\', 'Select Imaris Installation Folder');
                if selectedPath ~= 0 % User didn't cancel
                    % Ensure path ends with \XT\matlab
                    if ~endsWith(selectedPath, '\XT\matlab', 'IgnoreCase', true)
                        selectedPath = fullfile(selectedPath, 'XT', 'matlab');
                    end
                    app.ImarisPathEditField.Value = selectedPath;
                    % Save the selected path
                    imarisPath = selectedPath;
                    save(app.dataFile, 'imarisPath');
                end
            catch e
                uialert(app.UIFigure, sprintf('Error selecting path: %s', e.message), 'Error');
            end
        end

        % Button pushed function: ConnectButton
        function ConnectButtonPushed(app, event)
            try
                progressDlg = uiprogressdlg(app.UIFigure,'Title','Connecting','Indeterminate','on');
                % Use the path from the edit field
                imarisPath = app.ImarisPathEditField.Value;
                if ~isfolder(imarisPath)
                    error('Invalid Imaris path');
                end
                if ~contains(path, imarisPath)
                    addpath(imarisPath);
                end
                % Save the path if not already saved
                if ~exist(app.dataFile, 'file')
                    save(app.dataFile, 'imarisPath');
                end

                % Connect to Imaris
                % Check if ImarisLib.jar is already in Java class path
                javaClassPath = javaclasspath;
                jarFile = fullfile(imarisPath, 'ImarisLib.jar');
                if ~any(contains(javaClassPath, jarFile))
                    javaaddpath(jarFile);
                end
                vImarisLib = ImarisLib;
                vObjectId = 0;
                app.vImarisApplication = vImarisLib.GetApplication(vObjectId);
                app.viewer = app.vImarisApplication.GetSurpassCamera;
                
                if isempty(app.viewer)
                    error('No viewer found');
                end
                
                % Update UI on successful connection
                app.StatusLamp.Color = 'green';
                app.CopyPositionButton.Enable = 'on';
                app.PastePositionButton.Enable = 'on';
                app.FitButton.Enable = 'on';
                app.ResetButton.Enable = 'on';
                app.RotateButton.Enable = 'on';
                app.YawEditField.Enable = 'on';
                app.PitchEditField.Enable = 'on';
                app.RollEditField.Enable = 'on';
                close(progressDlg);
            catch e
                close(progressDlg);
                app.StatusLamp.Color = 'red';
                uialert(app.UIFigure, sprintf('Connection failed'), 'Error');
            end
        end

        % Button pushed function: CopyPositionButton
        function CopyPositionButtonPushed(app, event)
            try
                app.quaternion = app.viewer.GetOrientationQuaternion;
                app.position = app.viewer.GetPosition;
                uialert(app.UIFigure, 'Position and orientation copied', 'Success','Icon','success');
            catch e
                uialert(app.UIFigure, sprintf('Error: %s', e.message), 'Error');
            end
        end

        % Button pushed function: PastePositionButton
        function PastePositionButtonPushed(app, event)
            try
                if isempty(app.quaternion) || isempty(app.position)
                    error('No position/orientation data available');
                end
                app.viewer.SetOrientationQuaternion(app.quaternion);
                app.viewer.SetPosition(app.position);
            catch e
                uialert(app.UIFigure, sprintf('Error: %s', e.message), 'Error');
            end
        end

        % Button pushed function: FitButton
        function FitButtonPushed(app, event)
            try
                app.vImarisApplication.GetSurpassCamera.Fit;
            catch e
                uialert(app.UIFigure, sprintf('Error: %s', e.message), 'Error');
            end
        end

        % Button pushed function: ResetButton
        function ResetButtonPushed(app, event)
            try
                defaultQuaternion = [1, 0, 0, 0]; % Identity quaternion
                app.viewer.SetOrientationQuaternion(defaultQuaternion);
                app.vImarisApplication.GetSurpassCamera.Fit;
            catch e  uialert(app.UIFigure, sprintf('Error: %s', e.message), 'Error');
            end
        end

        % Button pushed function: RotateButton
        function RotateButtonPushed(app, event)
            try
                % Get angles from input fields (in degrees)
                yaw = deg2rad(app.YawEditField.Value);   % Z-axis
                pitch = deg2rad(app.PitchEditField.Value); % X-axis
                roll = deg2rad(app.RollEditField.Value);   % Y-axis

                % Calculate quaternion from Euler angles (ZXY convention)
                cy = cos(yaw/2);
                sy = sin(yaw/2);
                cp = cos(pitch/2);
                sp = sin(pitch/2);
                cr = cos(roll/2);
                sr = sin(roll/2);

                % ZXY rotation quaternion
                w = cr*cp*cy + sr*sp*sy;
                x = sr*cp*cy - cr*sp*sy;
                y = cr*sp*cy + sr*cp*sy;
                z = cr*cp*sy - sr*sp*cy;

                % Normalize quaternion
                quaternion = [w, x, y, z];
                quaternion = quaternion / norm(quaternion);

                % Apply rotation and fit
                app.viewer.SetOrientationQuaternion(quaternion);
                app.vImarisApplication.GetSurpassCamera.Fit;
            catch e
                uialert(app.UIFigure, sprintf('Error: %s', e.message), 'Error');
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Color = [0.96078431372549 0.96078431372549 0.96078431372549];
            app.UIFigure.Position = [93 93 412 550];
            app.UIFigure.Name = 'Imaris Camera Manager';

            % Create RollEditField
            app.RollEditField = uieditfield(app.UIFigure, 'numeric');
            app.RollEditField.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.RollEditField.Enable = 'off';
            app.RollEditField.Position = [93 329 100 22];

            % Create RollEditFieldLabel
            app.RollEditFieldLabel = uilabel(app.UIFigure);
            app.RollEditFieldLabel.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.RollEditFieldLabel.Position = [33 329 50 22];
            app.RollEditFieldLabel.Text = 'X';

            % Create PitchEditField
            app.PitchEditField = uieditfield(app.UIFigure, 'numeric');
            app.PitchEditField.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.PitchEditField.Enable = 'off';
            app.PitchEditField.Position = [93 369 100 22];

            % Create PitchEditFieldLabel
            app.PitchEditFieldLabel = uilabel(app.UIFigure);
            app.PitchEditFieldLabel.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.PitchEditFieldLabel.Position = [33 369 50 22];
            app.PitchEditFieldLabel.Text = 'Y';

            % Create YawEditField
            app.YawEditField = uieditfield(app.UIFigure, 'numeric');
            app.YawEditField.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.YawEditField.Enable = 'off';
            app.YawEditField.Position = [93 409 100 22];

            % Create YawEditFieldLabel
            app.YawEditFieldLabel = uilabel(app.UIFigure);
            app.YawEditFieldLabel.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.YawEditFieldLabel.Position = [33 409 50 22];
            app.YawEditFieldLabel.Text = 'Z';

            % Create RotateButton
            app.RotateButton = uibutton(app.UIFigure, 'push');
            app.RotateButton.ButtonPushedFcn = createCallbackFcn(app, @RotateButtonPushed, true);
            app.RotateButton.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];
            app.RotateButton.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.RotateButton.Enable = 'off';
            app.RotateButton.Position = [34 276 100 30];
            app.RotateButton.Text = 'Rotate';

            % Create ResetButton
            app.ResetButton = uibutton(app.UIFigure, 'push');
            app.ResetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetButtonPushed, true);
            app.ResetButton.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];
            app.ResetButton.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.ResetButton.Enable = 'off';
            app.ResetButton.Position = [211 159 120 30];
            app.ResetButton.Text = 'Reset';

            % Create FitButton
            app.FitButton = uibutton(app.UIFigure, 'push');
            app.FitButton.ButtonPushedFcn = createCallbackFcn(app, @FitButtonPushed, true);
            app.FitButton.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];
            app.FitButton.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.FitButton.Enable = 'off';
            app.FitButton.Position = [31 159 120 30];
            app.FitButton.Text = 'Fit';

            % Create PastePositionButton
            app.PastePositionButton = uibutton(app.UIFigure, 'push');
            app.PastePositionButton.ButtonPushedFcn = createCallbackFcn(app, @PastePositionButtonPushed, true);
            app.PastePositionButton.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];
            app.PastePositionButton.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.PastePositionButton.Enable = 'off';
            app.PastePositionButton.Position = [211 219 120 30];
            app.PastePositionButton.Text = 'Paste Position';

            % Create CopyPositionButton
            app.CopyPositionButton = uibutton(app.UIFigure, 'push');
            app.CopyPositionButton.ButtonPushedFcn = createCallbackFcn(app, @CopyPositionButtonPushed, true);
            app.CopyPositionButton.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];
            app.CopyPositionButton.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.CopyPositionButton.Enable = 'off';
            app.CopyPositionButton.Position = [31 219 120 30];
            app.CopyPositionButton.Text = 'Copy Position';

            % Create StatusLamp
            app.StatusLamp = uilamp(app.UIFigure);
            app.StatusLamp.Position = [141 470 20 20];
            app.StatusLamp.Color = [1 0 0];

            % Create ConnectButton
            app.ConnectButton = uibutton(app.UIFigure, 'push');
            app.ConnectButton.ButtonPushedFcn = createCallbackFcn(app, @ConnectButtonPushed, true);
            app.ConnectButton.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];
            app.ConnectButton.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.ConnectButton.Position = [32 465 100 30];
            app.ConnectButton.Text = 'Connect';

            % Create ImarisPathLabel
            app.ImarisPathLabel = uilabel(app.UIFigure);
            app.ImarisPathLabel.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.ImarisPathLabel.Position = [30 510 100 22];
            app.ImarisPathLabel.Text = 'Imaris Path:';

            % Create ImarisPathEditField
            app.ImarisPathEditField = uieditfield(app.UIFigure, 'text');
            app.ImarisPathEditField.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.ImarisPathEditField.Enable = 'off';
            app.ImarisPathEditField.Position = [130 510 200 22];

            % Create SelectPathButton
            app.SelectPathButton = uibutton(app.UIFigure, 'push');
            app.SelectPathButton.ButtonPushedFcn = createCallbackFcn(app, @SelectPathButtonPushed, true);
            app.SelectPathButton.BackgroundColor = [0.96078431372549 0.96078431372549 0.96078431372549];
            app.SelectPathButton.FontColor = [0.129411764705882 0.129411764705882 0.129411764705882];
            app.SelectPathButton.Position = [340 510 50 22];
            app.SelectPathButton.Text = 'Browse';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ImarisCameraManager_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

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