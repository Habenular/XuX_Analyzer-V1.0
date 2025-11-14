classdef XuX_Analyzer < handle
    % Animal Behavior Test Video Analyzer with GUI
    % -------------------------------------------------------
    % [Version 1.0]
    % 20251031 Written by X-Xin.
    % xuxing1819@live.com
     
    % [Guidance]
    % 1. Video format must be "mp4"; 
    % 1. 视频格式需要为"mp4"；
    % 2. Area name needs to be in English. 
    % 2. 区域名称需要使用英文，其他语言会导致导出数据混乱。
    
    properties
        % --- UI ---
        fig
        axProcessed
        btnLoadVideo
        btnPickBG
        btnLoadBG         
        btnSaveBG
        btnAddArea
        btnEditArea            
        btnClearAreas    
        lstAreas
        edtAreaName
        btnRenameArea
        btnDelArea       
        sldFrame
        txtFrameInfo
        btnSetRange
        btnAnalyze      
        btnSaveSettings   
        btnLoadSettings   
        btnBatch        
        % 参数控件
        spnThreshold
        spnMinArea
        spnMorph          
        spnScale
        spnMinDwellTime_s
        spnStartT
        spnEndT
        chkUseCrop
        btnSetCrop
        chkLivePreview % (新增)
        txtStatus
        spnStationaryThr       
        spnStationaryMinSec     
        btnCalibrateScale       
        spnAnalyzeEveryN        
        
        % --- 站点管理 UI ---
        stationPanel
        lstStations
        btnAddStation
        btnDelStation
        edtStationName
        btnRenameStation

        % --- UI 控件句柄 (新增) ---
        lblAreaTitle
        lblLocalParamsTitle

        % --- Data ---
        vidPath = ''
        vReader
        nFrames = 0
        fps = 0
        vidDuration = 0
        frameSize = [0 0]
        frameIdx = 1          
        bgFrame = []          
        areaColors            
        
        % (新增) 恢复为全局属性
        rangeStartF = 1
        rangeEndF   = 2

        % --- 重构的数据结构 ---
        GlobalParams          
        Stations = struct(... 
            'Name', {}, ...        
            'CropRect', {}, ...   
            'Areas', {}, ...      
            'LocalParams', {} ... 
        );
        ActiveStationIdx = 0; 
        
        % --- Batch GUI Handle ---
        batchFig

        % --- Batch UI (新增) ---
        fBatch              % 批量分析窗口句柄
        batchData           % {Video Path, Video Name, Setting Path, Background Path, Status}
        tblVideos           % 视频和配置表格
        btnSelectAllBatch   % 全选按钮句柄
        txtBatchETR      % [新增] 预计剩余时间文本标签
        txtBatchStatus      % 底部状态栏文本
        gaugeBatchProgress  % 进度条 (解决问题 4)
        edtSaveDir          % 保存目录文本框
        edtFileName         % 文件名文本框
        chkBatchLivePreview % (新增) 批量分析-实时预览复选框
    end
    
    methods
        % (替换) 构造函数：初始化时避开蓝色
        function self = XuX_Analyzer
            
            % --- 1. 初始化 全局参数 (使用静态方法) ---
            self.GlobalParams = XuX_Analyzer.getDefaultGlobalParams();
            
            % --- 2. 定义 默认局部参数 (使用静态方法) ---
            defaultLocalParams = XuX_Analyzer.getDefaultLocalParams();

            % --- 3. 创建默认的 "Station 1" ---
            self.Stations(1).Name = 'Station 1';
            self.Stations(1).CropRect = []; 
            self.Stations(1).Areas = struct('name',{},'mask',{},'color',{},'vertices',{}); 
            self.Stations(1).LocalParams = defaultLocalParams; 
            
            self.ActiveStationIdx = 1; 
            
            % [优化] 区域颜色避开蓝色
            % MATLAB默认lines色图第1个为深蓝，第6个为青色(接近蓝)。
            % 策略：生成更多颜色，然后手动剔除第1行(蓝)
            rawColors = lines(20); 
            % 剔除第1行(标准蓝)，保留橙、黄、紫、绿等后续颜色
            self.areaColors = rawColors(2:end, :); 
            
            buildUI(self);
        end
        
        % (替换) buildUI
        function buildUI(self)
            % 窗口大小和网格布局保持不变
            self.fig = uifigure('Name','XuX Analyzer V1.0','Position',[80 80 1400 1100]);
            
            % --- 主网格布局 ---
            g = uigridlayout(self.fig,[6,8]);
            g.RowHeight = {32,32,'1.5x','1x',38,40}; 
            g.ColumnWidth = {120,120,120,120,'1x','1x','1x','1x'}; 
            
            % --- Row 1 & 2, Col 1-4: 核心功能按钮 (不变) ---
            self.btnLoadVideo = uibutton(g,'Text','加载视频','ButtonPushedFcn',@(s,e)onLoadVideo(self));
            self.btnLoadVideo.Layout.Row = 1; self.btnLoadVideo.Layout.Column = 1;
            
            self.btnPickBG = uibutton(g,'Text','当前帧设为背景','ButtonPushedFcn',@(s,e)onPickBG(self));
            self.btnPickBG.Layout.Row = 1; self.btnPickBG.Layout.Column = 2;
            
            self.btnLoadBG = uibutton(g,'Text','加载背景','ButtonPushedFcn',@(s,e)onLoadBG(self));
            self.btnLoadBG.Layout.Row = 1; self.btnLoadBG.Layout.Column = 3;
            
            self.btnSaveBG = uibutton(g,'Text','保存背景','ButtonPushedFcn',@(s,e)onSaveBG(self));
            self.btnSaveBG.Layout.Row = 1; self.btnSaveBG.Layout.Column = 4;
            
            self.btnLoadSettings = uibutton(g,'Text','加载设置','ButtonPushedFcn',@(s,e)onLoadSettings(self));
            self.btnLoadSettings.Layout.Row = 2; self.btnLoadSettings.Layout.Column = 1;

            self.btnSaveSettings = uibutton(g,'Text','保存设置','ButtonPushedFcn',@(s,e)onSaveSettings(self));
            self.btnSaveSettings.Layout.Row = 2; self.btnSaveSettings.Layout.Column = 2;
            
            % 实时预览开关
            self.chkLivePreview = uicheckbox(g,'Text','实时分析预览', 'Value', true);
            self.chkLivePreview.Layout.Row = 2; self.chkLivePreview.Layout.Column = 3;

            % --- Row 1 & 2, Col 5-8: 分析/批量按钮 (已修正对齐) ---
            
            % 外层 Wrapper (gAnalyzeWrapper) 占据 Row 1-2，并移除所有内边距，确保紧贴边界
            gAnalyzeWrapper = uigridlayout(g, [1, 1]); % 1x1 布局
            gAnalyzeWrapper.Layout.Row = [1 2]; 
            gAnalyzeWrapper.Layout.Column = [5 8]; 
            gAnalyzeWrapper.RowHeight = {'1x'}; 
            gAnalyzeWrapper.ColumnWidth = {'1x'};
            gAnalyzeWrapper.Padding = [0 0 0 0]; % 移除外层内边距
            
            % 内层网格布局 gAnalyze 用于并排放置两个按钮
            gAnalyze = uigridlayout(gAnalyzeWrapper, [1, 2]); 
            gAnalyze.Layout.Row = 1; 
            gAnalyze.Layout.Column = 1;
            gAnalyze.RowHeight = {'1x'};
            gAnalyze.ColumnWidth = {'1x', '1x'};
            
            % [修正对齐] 增加垂直内边距 (Bottom/Top) 来对齐左侧按钮的边界，并增加水平间距
            % Padding: [Left Bottom Right Top]
            gAnalyze.Padding = [5 5 5 5]; 
            gAnalyze.ColumnSpacing = 8; 

            % 开始分析按钮
            self.btnAnalyze = uibutton(gAnalyze,'Text','开始分析','ButtonPushedFcn',@(s,e)onAnalyze(self));
            self.btnAnalyze.Layout.Row = 1; self.btnAnalyze.Layout.Column = 1;
            self.btnAnalyze.FontWeight = 'bold';
            self.btnAnalyze.FontSize = 18; 
            self.btnAnalyze.BackgroundColor = [244 168 27]/255; 
            self.btnAnalyze.FontColor = 'w';
            
            % 批量分析按钮
            self.btnBatch = uibutton(gAnalyze,'Text','批量分析','ButtonPushedFcn',@(s,e)onBatchGUI(self));
            self.btnBatch.Layout.Row = 1; self.btnBatch.Layout.Column = 2;
            self.btnBatch.FontWeight = 'bold';
            self.btnBatch.FontSize = 18;
            self.btnBatch.BackgroundColor = [232 68 24]/255; 
            self.btnBatch.FontColor = 'w';

            % --- Row 3-4: TabGroup (Col 1-4) & Axes (Col 5-8) ---
            tabg = uitabgroup(g);
            tabg.Layout.Row = [3 4]; tabg.Layout.Column = [1 4];
            
            tabParams = uitab(tabg, 'Title', '分析参数 & 区域设置');
            
            % 18 行布局
            gParams = uigridlayout(tabParams, [18, 4]); 
            gParams.ColumnWidth = {'1x', '1x', '1x', '1x'};
            
            % 18 行高度定义
            gParams.RowHeight = {32, 32, 32, 32, 32, ... % R1-R5: 全局
                                 32, 32, 32, '1x', ...   % R6-R9: 站点管理
                                 32, 32, '1x', 32, ...   % R10-R13: 区域设置
                                 32, 32, 32, 32, 32};    % R14-R18: 独立识别参数
            
            % --- R1-R5: 全局参数 ---
            lbl = uilabel(gParams,'Text','全局设置','FontWeight','bold','FontSize',14); 
            lbl.Layout.Row = 1; lbl.Layout.Column = [1 4];
            
            self.btnCalibrateScale = uibutton(gParams,'Text','标尺校准','ButtonPushedFcn',@(s,e)onCalibrateScale(self));
            self.btnCalibrateScale.Layout.Row = 2; self.btnCalibrateScale.Layout.Column = [1 2];
            
            lbl = uilabel(gParams,'Text','px->cm','FontWeight','bold'); 
            lbl.Layout.Row = 2; lbl.Layout.Column = 3;
            self.spnScale = uieditfield(gParams,'numeric','ValueChangedFcn',@(s,e)onGlobalParamChange(self, 'scalePx2Cm', s.Value));
            self.spnScale.Layout.Row = 2; self.spnScale.Layout.Column = 4;

            lbl = uilabel(gParams,'Text','进入最少(s)'); 
            lbl.Layout.Row = 3; lbl.Layout.Column = 1;
            self.spnMinDwellTime_s = uispinner(gParams,'Limits',[0.01 10], 'Step', 0.1, 'ValueChangedFcn',@(s,e)onGlobalParamChange(self, 'minDwellTime_s', s.Value));
            self.spnMinDwellTime_s.Layout.Row = 3; self.spnMinDwellTime_s.Layout.Column = 2;

            lbl = uilabel(gParams,'Text','每 (N) 帧分析1次','FontWeight','bold'); 
            lbl.Layout.Row = 3; lbl.Layout.Column = 3;
            self.spnAnalyzeEveryN = uispinner(gParams,'Limits',[1 100],'Step',1,'ValueChangedFcn',@(s,e)onGlobalParamChange(self, 'analyzeEveryN', s.Value));
            self.spnAnalyzeEveryN.Layout.Row = 3; self.spnAnalyzeEveryN.Layout.Column = 4;
            
            % R4: 全局时间范围按钮
            self.btnSetRange = uibutton(gParams,'Text','设置分析时间','ButtonPushedFcn',@(s,e)onSetTimeRange(self));
            self.btnSetRange.Layout.Row = 4; self.btnSetRange.Layout.Column = [1 4];
            
            % R5: 全局时间范围输入
            lbl = uilabel(gParams,'Text','起始(s)','FontWeight','bold'); 
            lbl.Layout.Row = 5; lbl.Layout.Column = 1;
            self.spnStartT = uieditfield(gParams,'numeric','ValueChangedFcn',@(s,e)onGlobalParamChange(self, 'startTime', s.Value));
            self.spnStartT.Layout.Row = 5; self.spnStartT.Layout.Column = 2;
            
            lbl = uilabel(gParams,'Text','结束(s, 0=末尾)','FontWeight','bold'); 
            lbl.Layout.Row = 5; lbl.Layout.Column = 3;
            self.spnEndT = uieditfield(gParams,'numeric','ValueChangedFcn',@(s,e)onGlobalParamChange(self, 'endTime', s.Value));
            self.spnEndT.Layout.Row = 5; self.spnEndT.Layout.Column = 4;
            
            % --- R6-R9: 站点管理 ---
            lbl = uilabel(gParams,'Text','站点管理','FontWeight','bold','FontSize',14); 
            lbl.Layout.Row = 6; lbl.Layout.Column = [1 4];
            
            self.btnAddStation = uibutton(gParams,'Text','添加新站点','ButtonPushedFcn',@(s,e)onAddStation(self));
            self.btnAddStation.Layout.Row = 7; self.btnAddStation.Layout.Column = [1 2];
            
            self.btnDelStation = uibutton(gParams,'Text','删除选中站点','ButtonPushedFcn',@(s,e)onDeleteStation(self));
            self.btnDelStation.Layout.Row = 7; self.btnDelStation.Layout.Column = [3 4];
            
            self.edtStationName = uieditfield(gParams,'text','Value','');
            self.edtStationName.Layout.Row = 8; self.edtStationName.Layout.Column = [1 2];
            self.btnRenameStation = uibutton(gParams,'Text','重命名选中站点','ButtonPushedFcn',@(s,e)onRenameStation(self));
            self.btnRenameStation.Layout.Row = 8; self.btnRenameStation.Layout.Column = [3 4];

            self.lstStations = uilistbox(gParams, 'Items',{}, 'ItemsData',{}, 'ValueChangedFcn', @(s,e)onSelectStation(self));
            self.lstStations.Layout.Row = 9; self.lstStations.Layout.Column = [1 4];

            % --- R10-R13: 区域设置 ---
            self.lblAreaTitle = uilabel(gParams,'Text','区域设置 (当前站点)','FontWeight','bold','FontSize',14);  
            self.lblAreaTitle.Layout.Row = 10; self.lblAreaTitle.Layout.Column = [1 4];
            
            self.btnAddArea = uibutton(gParams,'Text','添加区域','ButtonPushedFcn',@(s,e)onAddArea(self));
            self.btnAddArea.Layout.Row = 11; self.btnAddArea.Layout.Column = 1;
            
            self.btnEditArea = uibutton(gParams,'Text','编辑选中','ButtonPushedFcn',@(s,e)onEditArea(self));
            self.btnEditArea.Layout.Row = 11; self.btnEditArea.Layout.Column = 2;
            
            self.btnDelArea = uibutton(gParams,'Text','删除所选','ButtonPushedFcn',@(s,e)onDeleteArea(self)); 
            self.btnDelArea.Layout.Row = 11; self.btnDelArea.Layout.Column = 3;

            self.btnClearAreas = uibutton(gParams,'Text','清空所有','ButtonPushedFcn',@(s,e)onClearAreas(self)); 
            self.btnClearAreas.Layout.Row = 11; self.btnClearAreas.Layout.Column = 4;
            
            self.lstAreas = uilistbox(gParams, 'Items',{}, 'ItemsData',{}, 'Multiselect','off');
            self.lstAreas.Layout.Row = 12; self.lstAreas.Layout.Column = [1 4];
            
            self.edtAreaName = uieditfield(gParams,'text','Value','区域名（使用英文）');
            self.edtAreaName.Layout.Row = 13; self.edtAreaName.Layout.Column = [1 2];
            
            self.btnRenameArea = uibutton(gParams,'Text','应用新名称','ButtonPushedFcn',@(s,e)onRenameArea(self));
            self.btnRenameArea.Layout.Row = 13; self.btnRenameArea.Layout.Column = [3 4];

            % --- R14-R18: 独立识别参数 ---
            self.lblLocalParamsTitle = uilabel(gParams,'Text','识别参数 (当前站点)','FontWeight','bold','FontSize',14); 
            self.lblLocalParamsTitle.Layout.Row = 14; self.lblLocalParamsTitle.Layout.Column = [1 4];

            % R15: 识别范围
            self.btnSetCrop = uibutton(gParams,'Text','设置识别范围','ButtonPushedFcn',@(s,e)onSetCrop(self));
            self.btnSetCrop.Layout.Row = 15; self.btnSetCrop.Layout.Column = [1 2];
            
            self.chkUseCrop = uicheckbox(gParams,'Text','启用裁剪', 'Value', false, 'ValueChangedFcn',@(s,e)refreshPreview(self));
            self.chkUseCrop.Layout.Row = 15; self.chkUseCrop.Layout.Column = [3 4];

            % R16: 识别参数
            lbl = uilabel(gParams,'Text','阈值'); 
            lbl.Layout.Row = 16; lbl.Layout.Column = 1;
            self.spnThreshold = uispinner(gParams,'Limits',[0 255],'ValueChangedFcn',@(s,e)onLocalParamChange(self, 'threshold', s.Value));
            self.spnThreshold.Layout.Row = 16; self.spnThreshold.Layout.Column = 2;
            
            lbl = uilabel(gParams,'Text','最小面积'); 
            lbl.Layout.Row = 16; lbl.Layout.Column = 3;
            self.spnMinArea   = uispinner(gParams,'Limits',[1 1e6],'Step',10,'ValueChangedFcn',@(s,e)onLocalParamChange(self, 'minBlobArea', s.Value));
            self.spnMinArea.Layout.Row = 16; self.spnMinArea.Layout.Column = 4;

            % R17: 识别参数 / 形态核
            lbl = uilabel(gParams,'Text','形态核'); 
            lbl.Layout.Row = 17; lbl.Layout.Column = 1;
            self.spnMorph     = uispinner(gParams,'Limits',[0 10],'ValueChangedFcn',@(s,e)onLocalParamChange(self, 'morphRadius', s.Value));
            self.spnMorph.Layout.Row = 17; self.spnMorph.Layout.Column = 2;
            
            % R18: 静止参数
            lbl = uilabel(gParams,'Text','静止阈值(cm/s)'); 
            lbl.Layout.Row = 18; lbl.Layout.Column = 1;
            self.spnStationaryThr = uieditfield(gParams,'numeric','ValueChangedFcn',@(s,e)onLocalParamChange(self, 'stationarySpeedThreshold_cm_s', s.Value));
            self.spnStationaryThr.Layout.Row = 18; self.spnStationaryThr.Layout.Column = 2;

            lbl = uilabel(gParams,'Text','静止最短(s)'); 
            lbl.Layout.Row = 18; lbl.Layout.Column = 3;
            self.spnStationaryMinSec = uieditfield(gParams,'numeric','ValueChangedFcn',@(s,e)onLocalParamChange(self, 'stationaryMinDuration_s', s.Value));
            self.spnStationaryMinSec.Layout.Row = 18; self.spnStationaryMinSec.Layout.Column = 4;
            
            % =============================================================
            % 预览轴 (Row 3-4, Col 5-8)
            % =============================================================
            % 1. 包裹在一个 Panel 中以创建边框效果
            axPanel = uipanel(g, 'Title', '','BorderType', 'line', 'BackgroundColor', [1 1 1], 'FontSize', 14); 
            axPanel.Layout.Row = [3 4]; 
            axPanel.Layout.Column = [5 8];

            % 2. 使用内层网格布局以确保轴的响应性
            axG = uigridlayout(axPanel, [1, 1]);
            axG.Padding = 0;
            axG.RowHeight = {'1x'};
            axG.ColumnWidth = {'1x'};
            
            self.axProcessed = uiaxes(axG,'Box','on'); 
            self.axProcessed.Layout.Row = 1; 
            self.axProcessed.Layout.Column = 1; 
            title(self.axProcessed,'识别预览');
            
            % --- Row 5: 时间滑条 ---
            self.sldFrame = uislider(g,'Limits',[1 2],'Value',1,'ValueChangedFcn',@(s,e)onSlider(self));
            self.sldFrame.Layout.Row = 5; self.sldFrame.Layout.Column = [1 7];
            
            self.txtFrameInfo = uilabel(g,'Text','帧: - / 时间: - s'); 
            self.txtFrameInfo.Layout.Row = 5; self.txtFrameInfo.Layout.Column = 8;
            self.txtFrameInfo.HorizontalAlignment = 'left';
            
            % --- Row 6: 状态栏 ---
            self.txtStatus = uilabel(g,'Text','准备就绪','FontWeight','bold');
            self.txtStatus.Layout.Row = 6; self.txtStatus.Layout.Column = [1 8];
            
            % --- UI 构建完成后，立即填充控件的默认值 ---
            updateUIfromState(self); 
        end
        
        %% ------------------------- (新) 站点管理与UI绑定 -------------------------
        
        % (新) 核心函数：当选中站点时，从 self.Stations 更新UI
        function onSelectStation(self, ~, ~)
            if isempty(self.lstStations.Value)
                if ~isempty(self.Stations)
                    self.lstStations.Value = 1; % 强制选回第一个
                else
                    return; % 列表为空
                end
            end
            
            idx = self.lstStations.Value;
            if idx > 0 && idx <= numel(self.Stations)
                self.ActiveStationIdx = idx;
                updateUIfromState(self); % 使用激活的站点数据刷新UI
            end
        end

        % (替换) updateUIfromState (已修正鲁棒性)
        function updateUIfromState(self)
            if self.ActiveStationIdx <= 0 || self.ActiveStationIdx > numel(self.Stations)
                if isempty(self.Stations)
                    onAddStation(self); 
                else
                    self.ActiveStationIdx = 1; 
                end
            end
            
            idx = self.ActiveStationIdx;
            if idx > numel(self.Stations), return; end 
            
            % --- 鲁棒性修正 ---
            self.GlobalParams = XuX_Analyzer.mergeParams(self.GlobalParams, XuX_Analyzer.getDefaultGlobalParams());
            self.Stations(idx).LocalParams = XuX_Analyzer.mergeParams(self.Stations(idx).LocalParams, XuX_Analyzer.getDefaultLocalParams());
            % ------------------------------------------------
            
            stationName = self.Stations(idx).Name; % 获取当前站点名称

            % 1. 填充站点列表
            names = arrayfun(@(s)s.Name, self.Stations, 'UniformOutput', false);
            self.lstStations.Items = names;
            self.lstStations.ItemsData = 1:numel(names);
            self.lstStations.Value = idx;
            
            % 2. 填充站点名称
            self.edtStationName.Value = stationName;

            % 3. 实时更新区域和参数标题 (要求 3)
            if isprop(self, 'lblAreaTitle') && isvalid(self.lblAreaTitle)
                self.lblAreaTitle.Text = sprintf('区域设置 (%s)', stationName);
            end
            if isprop(self, 'lblLocalParamsTitle') && isvalid(self.lblLocalParamsTitle)
                self.lblLocalParamsTitle.Text = sprintf('识别参数 (%s)', stationName);
            end

            % 4. 填充站点独立 (Local) 参数
            L = self.Stations(idx).LocalParams; 
            self.spnThreshold.Value = L.threshold;
            self.spnMinArea.Value   = L.minBlobArea;
            self.spnMorph.Value     = L.morphRadius;
            self.spnStationaryThr.Value = L.stationarySpeedThreshold_cm_s;
            self.spnStationaryMinSec.Value = L.stationaryMinDuration_s;

            % 5. 填充全局 (Global) 参数
            G = self.GlobalParams;
            self.spnScale.Value = G.scalePx2Cm;
            self.spnMinDwellTime_s.Value = G.minDwellTime_s;
            self.spnAnalyzeEveryN.Value = G.analyzeEveryN;
            self.spnStartT.Value = G.startTime;
            if isnan(G.endTime), self.spnEndT.Value = 0; else, self.spnEndT.Value = G.endTime; end

            % --- [BUG 修复] ---
            % 强制更新内部帧范围和滑块，确保加载设置后时间范围能正确应用
            if ~isempty(self.vReader)
                % (此逻辑从 onGlobalParamChange 复制而来)
                [self.GlobalParams.startF, self.GlobalParams.endF] = ...
                    self.calculateFrameRange(self.GlobalParams.startTime, self.GlobalParams.endTime);
                
                % (恢复) 确保全局范围也同步
                self.rangeStartF = self.GlobalParams.startF;
                self.rangeEndF = self.GlobalParams.endF;
                
                self.sldFrame.Limits = [self.GlobalParams.startF, self.GlobalParams.endF];
                
                % 确保当前帧索引在更新后的范围内
                if self.frameIdx < self.GlobalParams.startF || self.frameIdx > self.GlobalParams.endF
                    self.frameIdx = self.GlobalParams.startF;
                end
                self.sldFrame.Value = self.frameIdx;
            else
                % 视频未加载时，使用默认值
                self.GlobalParams.startF = 1;
                self.GlobalParams.endF = 2;
                self.rangeStartF = 1;
                self.rangeEndF = 2;
            end
            % --- [修复结束] ---

            % 6. 填充独立 (Areas) 列表
            refreshAreaList(self); 
            
            % 7. 刷新预览
            refreshPreview(self);
        end

        % (新) 添加站点
        function onAddStation(self)
            % 复制当前站点的设置，或 (如果为空) 创建默认值
            if isempty(self.Stations)
                % (这在构造函数中已处理，但作为安全防护)
                defaultLocalParams.threshold = 50;
                defaultLocalParams.minBlobArea = 50;
                defaultLocalParams.morphRadius = 3;
                newStation.LocalParams = defaultLocalParams;
                newStation.CropRect = [];
                newStation.Areas = struct('name',{},'mask',{},'color',{},'vertices',{});
            else
                % 复制当前激活的站点
                newStation = self.Stations(self.ActiveStationIdx);
            end
            
            newStation.Name = sprintf('Station %d', numel(self.Stations) + 1);
            
            self.Stations(end+1) = newStation;
            self.ActiveStationIdx = numel(self.Stations); % 自动激活新站点
            
            updateUIfromState(self); % 刷新整个UI
        end

        % (新) 删除站点
        function onDeleteStation(self)
            if numel(self.Stations) <= 1
                uialert(self.fig, '必须保留至少一个站点。', '删除失败');
                return;
            end
            
            idx = self.ActiveStationIdx;
            self.Stations(idx) = [];
            
            % 激活上一个 (或第一个)
            self.ActiveStationIdx = max(1, idx - 1);
            
            updateUIfromState(self); % 刷新整个UI
        end
        
        % (新) 重命名站点
        function onRenameStation(self)
            idx = self.ActiveStationIdx;
            newName = strtrim(self.edtStationName.Value);
            if isempty(newName)
                uialert(self.fig, '站点名称不能为空。', '重命名失败');
                return;
            end
            
            self.Stations(idx).Name = newName;
            
            % 刷新站点列表框中的名字
            updateUIfromState(self);
        end

        % (新) 响应 [独立] 参数控件变化
        % (替换)
        function onLocalParamChange(self, fieldName, value)
            if self.ActiveStationIdx == 0, return; end
            
            % (移除了 endTime 检查)
            
            self.Stations(self.ActiveStationIdx).LocalParams.(fieldName) = value;
            
            % (移除了时间范围更新)
            
            % 实时刷新预览
            if any(strcmp(fieldName, {'threshold', 'minBlobArea', 'morphRadius'}))
                refreshPreview(self);
            end
        end
        
        % (替换)
        function onGlobalParamChange(self, fieldName, value)
            % (新增) 处理 endTime 的特殊情况 (0 = NaN)
            if strcmp(fieldName, 'endTime') && value <= 0
                value = NaN; % 内部用 NaN 表示末尾
            end
            
            self.GlobalParams.(fieldName) = value;
            
            % (新增) 如果更改了时间，需更新帧范围
            if any(strcmp(fieldName, {'startTime', 'endTime'}))
                % 立即更新全局帧范围
                P = self.GlobalParams;
                [P.startF, P.endF] = self.calculateFrameRange(P.startTime, P.endTime);
                self.GlobalParams = P;
                
                % (新增) 更新滑块
                if ~isempty(self.vReader)
                    self.sldFrame.Limits = [P.startF, P.endF];
                    self.frameIdx = P.startF;
                    self.sldFrame.Value = self.frameIdx;
                    refreshPreview(self); % 刷新预览以更新帧
                end
            end
        end
        
        % (新) 辅助：确保加载的结构体S拥有默认结构D中的所有字段
        function S = ensureFields(self, S, D)
            % 确保 S 拥有 D 中的所有字段
            fields = fieldnames(D);
            for i = 1:numel(fields)
                if ~isfield(S, fields{i})
                    S.(fields{i}) = D.(fields{i});
                end
            end
        end

        % (替换)
        function onLoadVideo(self)
            [f,p] = uigetfile({'*.mp4;*.mpg;*.avi;*.mov','Video Files'},'选择视频');
            if isequal(f,0), return; end
            figure(self.fig);
            self.vidPath = fullfile(p,f);
            self.vReader = VideoReader(self.vidPath);
            self.fps = max(1e-6, self.vReader.FrameRate);
            self.nFrames = max(1, floor(self.vReader.Duration * self.fps));
            self.vidDuration = self.vReader.Duration;
            self.frameSize = [self.vReader.Height, self.vReader.Width];
            
            % (恢复) 设置全局帧范围
            self.rangeStartF = 1;
            self.rangeEndF   = max(2, self.nFrames);
            self.frameIdx = 1; 
            
            self.fig.Name = ['XuX Analyzer - ' f]; 
            
            % (删除) axOriginal 的设置
            
            % --- 重置站点配置 ---
            self.GlobalParams = XuX_Analyzer.getDefaultGlobalParams();
            % (恢复) 为 GlobalParams 设置正确的帧范围
            self.GlobalParams.startF = self.rangeStartF;
            self.GlobalParams.endF = self.rangeEndF;
            
            defaultLocalParams = XuX_Analyzer.getDefaultLocalParams();
            
            self.Stations(1).Name = 'Station 1';
            self.Stations(1).CropRect = [];
            self.Stations(1).Areas = struct('name',{},'mask',{},'color',{},'vertices',{});
            self.Stations(1).LocalParams = defaultLocalParams;
            
            if numel(self.Stations) > 1
                self.Stations(2:end) = [];
            end
            
            self.ActiveStationIdx = 1; 
            
            % (恢复) 更新滑块范围
            self.sldFrame.Limits = [self.rangeStartF, self.rangeEndF];
            self.sldFrame.Value  = self.frameIdx;

            updateUIfromState(self); 

            setStatus(self, sprintf('已加载: %s (%.2f s, %.1f fps, %dx%d)', ...
                f, self.vidDuration, self.fps, self.frameSize(2), self.frameSize(1)));
        end
        
        % (替换)
        function onSetTimeRange(self)
            if isempty(self.vReader), uialert(self.fig,'请先加载视频','提示'); return; end
            
            s = self.spnStartT.Value;
            e_raw = self.spnEndT.Value;
            
            [startF, endF, s_out, e_out_nan] = self.calculateFrameRange(s, e_raw);
            
            % (恢复) 保存到 GlobalParams
            self.GlobalParams.startTime = s_out;
            self.GlobalParams.endTime = e_out_nan;
            self.GlobalParams.startF = startF;
            self.GlobalParams.endF = endF;
            
            % (恢复) 更新全局范围
            self.rangeStartF = startF;
            self.rangeEndF = endF;
            
            % 更新滑块和帧索引
            self.sldFrame.Limits = [startF, endF];
            self.frameIdx = startF;
            self.sldFrame.Value = self.frameIdx;
            
            % (修正) 更新UI上的显示
            if isnan(e_out_nan), self.spnEndT.Value = 0; else, self.spnEndT.Value = e_out_nan; end
            self.spnStartT.Value = s_out;
            
            setStatus(self, sprintf('[全局] 分析时间: (帧 %d-%d)', startF, endF));
            refreshPreview(self);
        end

        % (替换)
        function [startF, endF, s_out, e_out_nan] = calculateFrameRange(self, s_in, e_in)
            if isempty(self.vReader) 
                startF = 1; endF = 2; s_out = 0; e_out_nan = NaN;
                return;
            end
            
            analyzeEveryN = self.GlobalParams.analyzeEveryN; % (恢复) 帧步长是全局的

            s_out = max(0, s_in);
            
            if e_in <= 0 || isnan(e_in)
                e_out_nan = NaN;
                e_sec = self.vidDuration;
            else
                e_out_nan = min(e_in, self.vidDuration);
                e_sec = e_out_nan;
            end
            
            if s_out >= e_sec
                s_out = max(0, e_sec - 1); 
            end
            
            startF = max(1, floor(s_out * self.fps / analyzeEveryN) * analyzeEveryN + 1);
            endF = max(startF + 1, min(self.nFrames, floor(e_sec * self.fps / analyzeEveryN) * analyzeEveryN + 1));
        end
        
        % (替换)
        function onSetCrop(self)
            if isempty(self.vReader), uialert(self.fig,'请先加载视频','提示'); return; end
            
            idx = self.ActiveStationIdx;
            if idx == 0, return; end

            fr = readFrameAt(self, self.frameIdx);
            fig2 = figure('Name',sprintf('绘制识别范围 (站点: %s)，双击结束', self.Stations(idx).Name)); 
            imshow(fr); 
            
            % (新) 如果当前站点已有裁剪，显示它
            currentCropRect = self.Stations(idx).CropRect;
            if ~isempty(currentCropRect)
                h = drawrectangle('Position', currentCropRect);
            else
                h = drawrectangle;
            end
            
            wait(h); 
            rectRaw = round(h.Position); 
            close(fig2);
            rect = XuX_Analyzer.clampRectStatic(rectRaw, [size(fr,1) size(fr,2)]);
            
            if isempty(rect)
                self.Stations(idx).CropRect = []; % (新)
                setStatus(self, '裁剪框无效，已忽略（可能越界或太小）。');
            else
                self.Stations(idx).CropRect = rect; % (新)
                setStatus(self, sprintf('已设置 [站点 %s] 的裁剪区域: [x=%d,y=%d,w=%d,h=%d]',...
                    self.Stations(idx).Name, rect));
            end
            refreshPreview(self);
        end
        
        % (替换) 添加区域：移除弹窗，自动命名
        function onAddArea(self)
            if isempty(self.vReader), uialert(self.fig,'请先加载视频','提示'); return; end
            
            idx = self.ActiveStationIdx;
            if idx == 0, return; end
            
            activeStation = self.Stations(idx);
            currentCropRect = activeStation.CropRect;
            currentAreas = activeStation.Areas;

            fr = readFrameAt(self, self.frameIdx);
            
            % --- 坐标偏移处理 ---
            x_offset = 0;
            y_offset = 0;
            if ~isempty(currentCropRect) && self.chkUseCrop.Value
                fr_display = XuX_Analyzer.safeCropStatic(fr, currentCropRect);
                x_offset = currentCropRect(1) - 1; % -1 是因为 imcrop/drawpolygon 从 1 开始
                y_offset = currentCropRect(2) - 1;
            else
                fr_display = fr; % 在全图上绘制
            end

            figTitle = sprintf('绘制新区域 (站点: %s) (双击结束)', activeStation.Name);
            fig2 = figure('Name', figTitle, 'NumberTitle', 'off'); 
            imshow(fr_display);
            hold on;
            
            % 绘制现有区域作为参考
            if ~isempty(currentAreas)
                for i=1:numel(currentAreas)
                    % 从全局坐标转换回显示坐标
                    vertices_global = currentAreas(i).vertices;
                    vertices_display = [vertices_global(:,1) - x_offset, ...
                                        vertices_global(:,2) - y_offset];
                                    
                    plot(vertices_display(:,1), vertices_display(:,2),'Color',currentAreas(i).color,'LineWidth',1);
                end
            end
            
            setStatus(self, '绘制新区域... (双击结束)');
            hp = drawpolygon('LineWidth',1.5);
            
            if isempty(hp) || ~isvalid(hp)
                if ishandle(fig2), close(fig2); end
                setStatus(self, '操作取消');
                return; 
            end
            
            try
                wait(hp);
            catch ME
                if ishandle(fig2), close(fig2); end
                setStatus(self, '操作取消');
                return;
            end

            polyMask = createMask(hp); % Mask 总是局部的
            polyVertices_local = hp.Position; % 顶点也是局部的

            if ishandle(fig2), close(fig2); end

            % [优化] 移除重命名弹窗，直接自动生成名称 (Area + 序号)
            % 始终使用英文前缀以保证兼容性
            newAreaIdx = numel(currentAreas) + 1;
            nm = sprintf('Area%d', newAreaIdx);
            
            % --- 转换为全局坐标后再保存 ---
            polyVertices_global = [polyVertices_local(:,1) + x_offset, ...
                                   polyVertices_local(:,2) + y_offset];
            
            self.Stations(idx).Areas(newAreaIdx).name = nm;
            self.Stations(idx).Areas(newAreaIdx).mask = logical(polyMask); % Mask 保持局部
            self.Stations(idx).Areas(newAreaIdx).color = self.areaColors(mod(newAreaIdx-1,size(self.areaColors,1))+1,:);
            self.Stations(idx).Areas(newAreaIdx).vertices = polyVertices_global; % 保存全局顶点
            
            refreshAreaList(self);
            setStatus(self, sprintf('已添加区域: %s (站点: %s)', nm, activeStation.Name));
            refreshPreview(self);
            
            % [优化] 操作完成后焦点返回主界面
            figure(self.fig);
        end

        % (替换)
        function onEditArea(self)
            if isempty(self.vReader), uialert(self.fig,'请先加载视频','提示'); return; end

            stationIdx = self.ActiveStationIdx;
            areaIdx_val = self.lstAreas.Value; 
            
            if iscell(areaIdx_val) && ~isempty(areaIdx_val)
                areaIdx = areaIdx_val{1};
            else
                areaIdx = areaIdx_val;
            end
            
            if isempty(areaIdx) || ~isnumeric(areaIdx) || areaIdx < 1 || areaIdx > numel(self.Stations(stationIdx).Areas)
                uialert(self.fig, '请先在右侧列表中选择一个要编辑的区域。', '未选择区域');
                return;
            end
            
            activeStation = self.Stations(stationIdx);
            currentCropRect = activeStation.CropRect;
            currentAreas = activeStation.Areas;

            fr = readFrameAt(self, self.frameIdx);
            
            % --- (要求 2 修正) ---
            x_offset = 0;
            y_offset = 0;
            if ~isempty(currentCropRect) && self.chkUseCrop.Value
                fr_display = XuX_Analyzer.safeCropStatic(fr, currentCropRect);
                x_offset = currentCropRect(1) - 1; 
                y_offset = currentCropRect(2) - 1;
            else
                fr_display = fr; 
            end
            % --- (修正结束) ---

            figTitle = sprintf('编辑区域: %s (站点: %s) (双击结束)', currentAreas(areaIdx).name, activeStation.Name);
            fig2 = figure('Name', figTitle, 'NumberTitle', 'off'); 
            imshow(fr_display);
            hold on;
            
            % (修正) 绘制其他区域
            if ~isempty(currentAreas)
                for i=1:numel(currentAreas)
                    if i == areaIdx, continue; end
                    vertices_global = currentAreas(i).vertices;
                    vertices_display = [vertices_global(:,1) - x_offset, ...
                                        vertices_global(:,2) - y_offset];
                    plot(vertices_display(:,1), vertices_display(:,2),'Color',currentAreas(i).color,'LineWidth',1);
                end
            end
            
            setStatus(self, sprintf('正在编辑: %s...', currentAreas(areaIdx).name));
            hp = [];
            
            % (修正) 将全局坐标转换回局部坐标以供编辑
            pos_global = currentAreas(areaIdx).vertices;
            pos_local = [pos_global(:,1) - x_offset, ...
                         pos_global(:,2) - y_offset];
                         
            hp = drawpolygon('Position', pos_local, 'LineWidth', 1.5, 'Color', currentAreas(areaIdx).color);
                        
            if isempty(hp) || ~isvalid(hp)
                if ishandle(fig2), close(fig2); end
                setStatus(self, '操作取消');
                return; 
            end
            
            try
                wait(hp);
            catch ME
                if ishandle(fig2), close(fig2); end
                setStatus(self, '操作取消');
                return;
            end

            polyMask = createMask(hp);
            polyVertices = hp.Position;
            
            if ishandle(fig2), close(fig2); end

            % (新) 保存回当前站点
            self.Stations(stationIdx).Areas(areaIdx).mask = logical(polyMask);
            self.Stations(stationIdx).Areas(areaIdx).vertices = polyVertices;
            setStatus(self, sprintf('已更新区域: %s (站点: %s)', currentAreas(areaIdx).name, activeStation.Name));
            
            refreshPreview(self);
        end
        
        % (替换)
        function onClearAreas(self)
            stationIdx = self.ActiveStationIdx;
            if stationIdx == 0, return; end
            
            self.Stations(stationIdx).Areas = struct('name',{},'mask',{},'color',{},'vertices',{});
            refreshAreaList(self);
            setStatus(self,sprintf('已清空 [站点 %s] 的所有区域', self.Stations(stationIdx).Name));
            refreshPreview(self);
        end
        
        % (替换)
        % (替换)
        function onRenameArea(self)
            stationIdx = self.ActiveStationIdx;
            areaIdx = self.lstAreas.Value; 

            % (FIXED: 安全获取数值索引)
            if iscell(areaIdx) && ~isempty(areaIdx)
                areaIdx = areaIdx{1};
            end
            
            if isempty(areaIdx) || ~isnumeric(areaIdx) || areaIdx < 1 || areaIdx > numel(self.Stations(stationIdx).Areas)
                return; 
            end
            % areaIdx 现在是一个有效的数值索引
            
            nm = strtrim(self.edtAreaName.Value);
            if isempty(nm), return; end
            
            self.Stations(stationIdx).Areas(areaIdx).name = nm;
            refreshAreaList(self);
        end
        
        % (替换)
        function onDeleteArea(self)
            stationIdx = self.ActiveStationIdx;
            areaIdx = self.lstAreas.Value; 

            % (FIXED: 安全获取数值索引)
            if iscell(areaIdx) && ~isempty(areaIdx)
                areaIdx = areaIdx{1};
            end
            
            if isempty(areaIdx) || ~isnumeric(areaIdx) || areaIdx < 1 || areaIdx > numel(self.Stations(stationIdx).Areas)
                return; 
            end
            % areaIdx 现在是一个有效的数值索引

            self.Stations(stationIdx).Areas(areaIdx) = [];
            refreshAreaList(self);
            refreshPreview(self);
        end
        
        % (替换)
        function onPickBG(self)
            if isempty(self.vReader), uialert(self.fig,'请先加载视频','提示'); return; end
            
            % (新) getCurrentFrameProcessed(self, false) 
            % 现在会返回 *当前站点裁剪后* (如果启用) 的 *灰度* 帧
            frame = getCurrentFrameProcessed(self,false); 
            
            % (新) 背景帧应该是全尺寸的还是裁剪后的？
            % 您的要求是 "共用背景帧"。
            % 方案：onPickBG 总是从 *全尺寸* 原始帧中提取背景。
            % (在分析时，我们再动态裁剪这个全局背景)
            
            fr_raw = readFrameAt(self, self.frameIdx);
            self.bgFrame = im2gray(fr_raw);
            
            setStatus(self,'已设置当前帧 (全尺寸) 为全局背景参照');
            
            % (新) 刷新预览，因为 makeMask 会使用新的 bgFrame
            refreshPreview(self);
        end
        
        % <--- [MODIFIED V11] 新增加载背景帧功能 --->
        function onLoadBG(self)
            [f,p] = uigetfile({'*.png;*.jpg;*.tif','Image Files'},'选择背景帧文件');
            if isequal(f,0), return; end
            figure(self.fig);
            
            try
                img = imread(fullfile(p,f));
                if size(img,3) == 3, img = rgb2gray(img); end
                self.bgFrame = img;
                setStatus(self, ['已加载背景帧: ' fullfile(p,f)]);
                refreshPreview(self);
            catch ME
                uialert(self.fig, ['背景帧加载失败: ' ME.message], '错误');
            end
        end
        % <--- [MODIFIED V11] 结束 --->
        
        function onSaveBG(self)
            if isempty(self.bgFrame), uialert(self.fig,'尚未设置背景','提示'); return; end
            [f,p] = uiputfile({'*.png;*.jpg','Image'},'保存背景帧为...');
            if isequal(f,0), return; end
            imwrite(self.bgFrame, fullfile(p,f));
            setStatus(self, ['背景已保存: ' fullfile(p,f)]);
        end

        function onSaveSettings(self)
            % (新) 保存新的数据结构
            S.GlobalParams = self.GlobalParams;
            S.Stations = self.Stations; 
            
            % 1. 确保将 chkUseCrop 的当前值写入 GlobalParams 结构体
            S.GlobalParams.useCrop = self.chkUseCrop.Value; 
            
            % 2. 确保保存当前激活的站点索引
            S.ActiveStationIdx = self.ActiveStationIdx;
            
            [f,p] = uiputfile('*.mat','保存多站点分析设置为...');
            if isequal(f,0), return; end
            
            % 使用 -struct 方式保存
            save(fullfile(p,f),'-struct','S');
            setStatus(self,['设置已保存: ' fullfile(p,f)]);
            
            % [优化] 保存后焦点返回到程序主界面
            figure(self.fig);
        end
        
        % (替换) onLoadSettings (已修复：强制加载启用裁剪开关)
        function onLoadSettings(self)
            [f,p] = uigetfile('*.mat','选择配置文件');
            if isequal(f,0), return; end
            path = fullfile(p,f);
            figure(self.fig);            
            
            setStatus(self, '正在加载设置...');
            
            try
                S_loaded = load(path);
            catch ME
                uialert(self.fig, ['无法加载配置文件: ' ME.message], '错误');
                return;
            end
            
            % --- 鲁棒性修正：加载时合并，确保所有字段存在 ---
            S_loaded.GlobalParams = XuX_Analyzer.mergeParams(S_loaded.GlobalParams, XuX_Analyzer.getDefaultGlobalParams());
            
            if isfield(S_loaded, 'Stations') && ~isempty(S_loaded.Stations)
                for i = 1:numel(S_loaded.Stations)
                    if isfield(S_loaded.Stations(i), 'LocalParams')
                        S_loaded.Stations(i).LocalParams = XuX_Analyzer.mergeParams(S_loaded.Stations(i).LocalParams, XuX_Analyzer.getDefaultLocalParams());
                    else
                         S_loaded.Stations(i).LocalParams = XuX_Analyzer.getDefaultLocalParams();
                    end
                end
            end
            % ------------------------------------------------
            
            % 1. 应用全局参数
            self.GlobalParams = S_loaded.GlobalParams;
            
            % 2. 【核心修复：显式加载启用裁剪开关状态】
            if isfield(self.GlobalParams, 'useCrop')
                % 确保该字段存在，然后直接赋值给 UI 控件
                self.chkUseCrop.Value = self.GlobalParams.useCrop;
            end
            
            % 3. 应用站点和局部参数 (保留区域刷新修复逻辑)
            if isfield(S_loaded, 'Stations')
                self.Stations = S_loaded.Stations;
            end
            
            % --- 修正后的代码块 (替换原 onLoadSettings 中的对应部分) ---
            if isprop(self, 'lstStations') && isvalid(self.lstStations) % 修正：操作 lstStations
                if ~isempty(self.Stations)
                    self.lstStations.Value = {}; 
                    stationNames = arrayfun(@(s) s.Name, self.Stations, 'UniformOutput', false);
                    self.lstStations.Items = stationNames;
                    self.lstStations.ItemsData = 1:numel(stationNames); % 修正：设置 ItemsData
                    
                    if isfield(S_loaded, 'ActiveStationIdx')
                        idx = S_loaded.ActiveStationIdx;
                        if idx <= 0 || idx > numel(stationNames)
                             idx = 1; 
                        end
                    else
                         idx = 1;
                    end
                    self.ActiveStationIdx = idx;
                    self.lstStations.Value = idx; % 修正：设置 Value 为 ItemsData 中的数值索引
                else
                    self.lstStations.Items = {};
                    self.lstStations.Value = {};
                    self.ActiveStationIdx = 0;
                end
            end
            
            % 4. 应用背景帧 (如果存在)
            if isfield(S_loaded, 'bgFrame')
                self.bgFrame = S_loaded.bgFrame;
            end
            
            % 5. 更新UI (这会处理所有其它 UI 控件的刷新)
            updateUIfromState(self);
            
            setStatus(self, ['设置已加载: ' f]);
        end
        
        function onAnalyze(self)
            if isempty(self.vReader), uialert(self.fig,'请先加载视频','提示'); return; end
            if isempty(self.bgFrame), uialert(self.fig,'请先选取背景','提示'); return; end

            setStatus(self, '正在检查配置...');
            
            if isempty(self.Stations)
                uialert(self.fig, '没有可分析的站点，请添加至少一个站点。', '分析中止');
                return;
            end
            
            % (恢复) 使用全局时间范围
            minStartF = self.GlobalParams.startF;
            maxEndF = self.GlobalParams.endF;
            
            if maxEndF <= minStartF
                uialert(self.fig, '设定的分析时间范围无效或太短，请检查。', '分析中止');
                return;
            end

            % 2. 选择输出路径
            defaultName = [self.vReader.Name(1:end-4) '_Analysis'];
            [f,p] = uiputfile('*.csv', '选择分析结果文件基名称 (将为每个站点添加后缀)', defaultName);
            if isequal(f,0), return; end
            [~, baseName, ~] = fileparts(f);

            setStatus(self, '开始多目标同步分析...');
            
            % 3. 运行核心分析
            try
                dt_step = self.GlobalParams.analyzeEveryN / self.fps;
                
                % --- [BUG 4 修复] 
                % 传递 self.fig 作为 waitbar 的父窗口
                % 传递一个空的 progressCallback (因为主分析没有外部进度条)
                progressCallback = []; 
                
                % --- (要求 5) 实时预览分支 ---
                if self.chkLivePreview.Value
                    % 调用非静态的 runAnalysisLive
                    [Results, Trajs] = self.runAnalysisLive(self.vReader, self.bgFrame, ...
                                        self.GlobalParams, self.Stations, ...
                                        minStartF, maxEndF, ...
                                        dt_step, self.nFrames, self.fps, ...
                                        self.fig, progressCallback); % (新增 progressCallback)
                else
                    % 调用静态的 runAnalysisCore (无预览)
                    [Results, Trajs] = XuX_Analyzer.runAnalysisCore(self.vReader, self.bgFrame, ...
                                        self.GlobalParams, self.Stations, ...
                                        minStartF, maxEndF, ...
                                        dt_step, self.nFrames, self.fps, ...
                                        self.fig, progressCallback); % (新增 progressCallback)
                end
                % --- (修正结束) ---
                                    
            catch ME
                setStatus(self, sprintf('分析核心出错: %s', ME.message));
                rethrow(ME);
            end
            
            % 4. 循环保存每个站点的结果 (原逻辑)
            numStations = numel(self.Stations);
            for i = 1:numStations
                stationName = self.Stations(i).Name;
                stationNameClean = matlab.lang.makeValidName(stationName);

                resTbl = Results{i}.perFrameTbl;
                perAreaTbl = Results{i}.perAreaTbl;
                summaryTbl = Results{i}.summaryTbl;

                % 5a. 保存逐帧数据
                perFrameFile = fullfile(p, sprintf('%s_%s_perFrame.csv', baseName, stationNameClean));
                writetable(resTbl, perFrameFile);

                % 5b. 保存区域数据
                perAreaFile = fullfile(p, sprintf('%s_%s_perArea.csv', baseName, stationNameClean));
                writetable(perAreaTbl, perAreaFile);
                
                % 5c. 保存摘要数据
                summaryFile = fullfile(p, sprintf('%s_%s_summary.csv', baseName, stationNameClean));
                writetable(summaryTbl, summaryFile);
                
                % 5d. 保存轨迹图
                if ~isempty(Trajs{i})
                    trajFile = fullfile(p, sprintf('%s_%s_trajectory.png', baseName, stationNameClean));
                    fTraj = figure('Visible','off');
                    imshow(self.bgFrame,'InitialMagnification','fit');
                    hold on;
                    % 轨迹图需使用全局坐标 (在 runAnalysisCore 中已转换)
                    plot(Trajs{i}(:,1), Trajs{i}(:,2), 'k-'); 
                    title(sprintf('%s - %s 轨迹图', baseName, stationName));
                    xlabel('X (px)'); ylabel('Y (px)');
                    saveas(fTraj, trajFile);
                    close(fTraj);
                end
            end
            
            % --- [功能 1 新增：导出汇总 Excel] ---
            setStatus(self, '正在生成汇总报告...');
            try
                % --- 1. 初始化汇总表结构 (同批量分析) ---
                exportHeader1 = {'Analyze Information', 'Analyze Information', 'Analyze Information', 'Analyze Information', 'Analyze Information', 'Analyze Information', 'Analyze Information', 'Analyze Information'};
                exportHeader2 = {'VideoName', 'VideoDuration_s', 'BG_Frame', 'Start_s', 'End_s', 'AnalyzeEveryN', 'SettingFilePath', 'BackgroundFilePath'};
                internalColNames = {'VideoName', 'VideoDuration_s', 'BG_Frame', 'Start_s', 'End_s', 'AnalyzeEveryN', 'SettingFilePath', 'BackgroundFilePath'}; 
                colNamesFixedCount = numel(internalColNames); 
                combinedTbl = []; 
                P_Global = self.GlobalParams;
                Stations = self.Stations;

                % --- 2. 填充固定数据 ---
                [~, vidNameOnly, ~] = fileparts(self.vidPath);
                combinedRowDataFixed = {vidNameOnly, self.vidDuration, ...
                                   sprintf('%dx%d', size(self.bgFrame,2), size(self.bgFrame,1)), ...
                                   P_Global.startTime, P_Global.endTime, ...
                                   P_Global.analyzeEveryN, ...
                                   'N/A (From Main UI)', 'N/A (From Main UI)'};
                
                % --- 3. 收集动态数据 (解析 Results) ---
                videoDynamicInternalNames = cell(0);
                videoDynamicExportNames = cell(0);
                videoDynamicHeader1 = cell(0);
                videoDynamicColData = cell(0);
                
                for s_idx = 1:numel(Stations)
                    stationNameClean = matlab.lang.makeValidName(Stations(s_idx).Name);
                    stationNameDisplay = Stations(s_idx).Name; 
                    summaryTbl = Results{s_idx}.summaryTbl;
                    perAreaTbl = Results{s_idx}.perAreaTbl;
                    
                    % a. Summary data
                    baseSummaryNames = summaryTbl.Properties.VariableNames;
                    for j = 1:numel(baseSummaryNames)
                        internalColName = [stationNameClean '_' baseSummaryNames{j}];
                        videoDynamicInternalNames{end+1} = internalColName; 
                        videoDynamicExportNames{end+1} = baseSummaryNames{j};
                        videoDynamicHeader1{end+1} = stationNameDisplay; 
                        videoDynamicColData{end+1} = summaryTbl.(baseSummaryNames{j})(1);
                    end
                    
                    % b. Area data
                    areaNamesInResult = perAreaTbl.AreaName;
                    stationAreaNames = arrayfun(@(a)a.name, Stations(s_idx).Areas, 'UniformOutput', false); 
                    for j = 1:numel(stationAreaNames) 
                        areaName = stationAreaNames{j};
                        internalColTime = [stationNameClean '_' areaName '_Time_s'];
                        internalColEntries = [stationNameClean '_' areaName '_Entries'];
                        internalColDistance = [stationNameClean '_' areaName '_Distance_m'];
                        exportColTime = [areaName '_Time_s'];
                        exportColEntries = [areaName '_Entries'];
                        exportColDistance = [areaName '_Distance_m'];
                        
                        videoDynamicInternalNames = [videoDynamicInternalNames, {internalColTime, internalColEntries, internalColDistance}];
                        videoDynamicExportNames = [videoDynamicExportNames, {exportColTime, exportColEntries, exportColDistance}];
                        videoDynamicHeader1 = [videoDynamicHeader1, {stationNameDisplay, stationNameDisplay, stationNameDisplay}];
                        idxArea = find(strcmp(areaNamesInResult, areaName), 1);
                        if isempty(idxArea)
                            videoDynamicColData = [videoDynamicColData, {0, 0, 0}]; 
                        else
                            videoDynamicColData{end+1} = perAreaTbl.Time_s(idxArea);
                            videoDynamicColData{end+1} = perAreaTbl.Entries(idxArea);
                            videoDynamicColData{end+1} = perAreaTbl.Distance_m(idxArea);
                        end
                    end
                end
                
                % --- 4. 更新全局列名 ---
                newColsMask = ~ismember(videoDynamicInternalNames, internalColNames);
                newInternalCols = videoDynamicInternalNames(newColsMask);
                
                if ~isempty(newInternalCols)
                    internalColNames = [internalColNames, newInternalCols];
                    exportHeader2 = [exportHeader2, videoDynamicExportNames(newColsMask)];
                    exportHeader1 = [exportHeader1, videoDynamicHeader1(newColsMask)];
                end
                
                % --- 5. 构建最终的行数据 ---
                finalRowData = cell(1, numel(internalColNames));
                finalRowData(1:colNamesFixedCount) = combinedRowDataFixed;
                [~, globalIdx, videoIdx] = intersect(internalColNames, videoDynamicInternalNames, 'stable');
                finalRowData(globalIdx) = videoDynamicColData(videoIdx);
                
                for j = colNamesFixedCount+1:numel(finalRowData)
                    if isempty(finalRowData{j})
                         finalRowData{j} = 0; 
                    end
                end
                
                combinedTbl = cell2table(finalRowData, 'VariableNames', internalColNames);

                % --- 6. 保存到 .xlsx ---
                finalFile = fullfile(p, [baseName '_Combined.xlsx']);
                
                % 准备表头
                headerRow1Data = cell(1, numel(exportHeader1));
                [uniqueGroups, ~, groupIndex] = unique(exportHeader1, 'stable');
                for g = 1:numel(uniqueGroups)
                    groupName = uniqueGroups{g};
                    groupStartCol = find(groupIndex == g, 1, 'first');
                    headerRow1Data{groupStartCol} = groupName;
                end
                headerMatrix = [headerRow1Data; exportHeader2];
                dataCell = table2cell(combinedTbl); 
                dataNumericMask = cellfun(@isnumeric, dataCell); 
                dataCell(dataNumericMask) = cellfun(@(x) num2str(x), dataCell(dataNumericMask), 'UniformOutput', false);
                exportData = [headerMatrix; dataCell];
                
                try
                    xlswrite(finalFile, exportData, 'Sheet1', 'A1');
                    setStatus(self, sprintf('分析完成。汇总报告已保存到: %s', finalFile));
                catch ME_xls
                    % Fallback to CSV if xlswrite fails
                    warning('XLSX 写入失败: %s. 正在尝试保存为 CSV.', ME_xls.message);
                    fallbackFile = fullfile(p, [baseName '_Combined_FALLBACK.csv']);
                    emptyCells = cellfun(@isempty, headerRow1Data);
                    headerRow1Data(emptyCells) = {''}; 
                    headerRow1 = strjoin(headerRow1Data, ','); 
                    headerRow2 = strjoin(exportHeader2, ','); 
                    fid = fopen(fallbackFile, 'w');
                    fprintf(fid, '%s\n', headerRow1);
                    fprintf(fid, '%s\n', headerRow2);
                    for r = 1:size(dataCell, 1)
                        rowStr = strjoin(dataCell(r, :), ',');
                        fprintf(fid, '%s\n', rowStr);
                    end
                    fclose(fid);
                    setStatus(self, sprintf('分析完成。XLSX 写入失败，汇总报告已保存为: %s', fallbackFile));
                end

            catch ME_combine
                setStatus(self, sprintf('分析完成，但保存汇总表时出错: %s', ME_combine.message));
            end
            % --- [功能 1 结束] ---
            
            % (原状态信息被上面的 try/catch 覆盖了，这里保留原意)
            % setStatus(self, sprintf('分析完成。共保存了 %d 个站点的结果文件到: %s', numStations, p));
        end

        % (新增) 实时分析预览
        function [Results, Trajectories] = runAnalysisLive(self, vReader, bgFrame, GlobalParams, Stations, startF, endF, dt_step, nFramesTotal, fps, hFig, progressCallback)
            
            P_Global = GlobalParams; 
            numStations = numel(Stations);
            
            % 1. 预分配
            Trajectories = cell(numStations, 1); 
            TempData = struct(); 
            for i = 1:numStations
                MaxFrames = floor((endF - startF) / P_Global.analyzeEveryN) + 1; 
                TempData(i).pos = NaN(MaxFrames, 2); 
                TempData(i).inside = false(MaxFrames, numel(Stations(i).Areas)); 
                TempData(i).idx = 0; 
            end
            
            % 2. 逐帧处理循环
            vr = vReader;
            currentFrameIdx = startF;
            
            waitbarHandle = []; 
            if ~isempty(hFig) && ishandle(hFig)
                % (要求 1 修正) 将 WindowStyle 从 'modal' 改为 'normal' 
                waitbarHandle = waitbar(0, '正在初始化...', 'Name', '多目标分析进度', 'WindowStyle', 'normal'); 
                if isprop(waitbarHandle, 'UserData')
                   setappdata(waitbarHandle, 'canceling', false);
                   uicontrol('Parent', waitbarHandle, 'String', '取消', ...
                       'Position', [waitbarHandle.Position(3)/2-30, 5, 60, 20], ...
                       'Callback', @(s,e) setappdata(waitbarHandle, 'canceling', true));
                end
            end

            while currentFrameIdx <= endF
                
                if ~isempty(waitbarHandle) && isvalid(waitbarHandle) && getappdata(waitbarHandle,'canceling')
                    break;
                end
                
                % 2a. 读取原始帧
                try
                    vr.CurrentTime = (currentFrameIdx - 1) / fps; 
                    fr_raw = readFrame(vr);
                catch
                    disp(['Warning: 无法读取帧 ' num2str(currentFrameIdx) '. 跳过。']);
                    currentFrameIdx = currentFrameIdx + P_Global.analyzeEveryN;
                    continue;
                end
                
                % --- (优化) 实时预览逻辑 ---
                % 1. 显示原始帧
                imshow(fr_raw, 'Parent', self.axProcessed);
                hold(self.axProcessed, 'on');

                % 2. (新增) 循环绘制所有站点的静态叠加 (区域和裁剪框)
                for s_idx = 1:numStations
                    S_preview = Stations(s_idx);
                    % 在实时分析时，所有站点都在工作，很难定义谁是 "Active"。
                    % 策略：全部画成实线，或者全部画成一种统一样式。
                    % 为了视觉清晰，我们把所有正在分析的站点都视为 "Active" (实线, 0.3 alpha)
                    isActive_live = true; 
                    
                    % 调用修改后的 drawOverlays
                    self.drawOverlays(self.axProcessed, S_preview, isActive_live);
                end
                % --- (静态叠加绘制结束) ---
                
                % 2b. 站点内循环 (分析 + 绘制动态结果)
                for i = 1:numStations
                    S = Stations(i);
                    L = S.LocalParams;
                    
                    % i. 裁剪
                    if isempty(S.CropRect)
                        fr_cropped = fr_raw;
                        bg_cropped = bgFrame;
                        x_offset = 0;
                        y_offset = 0;
                    else
                        rect = S.CropRect;
                        fr_cropped = XuX_Analyzer.safeCropStatic(fr_raw, rect);
                        bg_cropped = XuX_Analyzer.safeCropStatic(bgFrame, rect);
                        x_offset = rect(1) - 1; 
                        y_offset = rect(2) - 1; 
                    end
                    
                    % ii. 分析
                    gray_cropped = im2gray(fr_cropped);
                    mask_local = XuX_Analyzer.makeMask(gray_cropped, bg_cropped, L); 

                    cc = bwconncomp(mask_local);
                    centroid_global = [NaN, NaN]; 
                    
                    if cc.NumObjects > 0
                        Sprops = regionprops(cc, 'Area', 'Centroid');
                        [~, ii] = max([Sprops.Area]);
                        centroid_local = Sprops(ii).Centroid;
                        
                        centroid_global = [centroid_local(1) + x_offset, ...
                                           centroid_local(2) + y_offset];
                    end
                    
                    % --- (优化) 实时预览：绘制所有站点的分析结果 ---
                    % (移除了 if i == self.ActiveStationIdx)
                    
                    % 绘制轮廓 (全局坐标)
                    B = bwboundaries(mask_local);
                    for k = 1:length(B)
                        plot(self.axProcessed, B{k}(:,2) + x_offset, B{k}(:,1) + y_offset, 'w', 'LineWidth', 0.5);
                    end
                    
                    % 绘制中心点 (全局坐标)
                    if ~any(isnan(centroid_global))
                        % (新增) 为不同站点使用不同颜色
                        color = self.areaColors(mod(i-1,size(self.areaColors,1))+1,:);
                        plot(self.axProcessed, centroid_global(1), centroid_global(2), '+', 'Color', color, 'MarkerSize', 10, 'LineWidth', 1);
                    end
                    % --- (预览逻辑结束) ---
                    
                    % iii. 区域判定 (使用全局坐标)
                    inside_mask = false(1, numel(S.Areas));
                    if ~isnan(centroid_global(1))
                        for k = 1:numel(S.Areas)
                            if isfield(S.Areas(k), 'vertices') && ~isempty(S.Areas(k).vertices)
                                inside_mask(k) = inpolygon(centroid_global(1), centroid_global(2), ...
                                    S.Areas(k).vertices(:,1), S.Areas(k).vertices(:,2));
                            end
                        end
                    end
                    
                    % iv. 存储结果
                    TempData(i).idx = TempData(i).idx + 1;
                    frame_idx = TempData(i).idx;
                    
                    TempData(i).pos(frame_idx, :) = centroid_global;
                    TempData(i).inside(frame_idx, :) = inside_mask;
                end % 站点循环结束
                
                % 2c. 更新预览
                hold(self.axProcessed, 'off');
                % (优化) 更新标题以反映所有站点
                title(self.axProcessed, sprintf('实时分析 (预览所有 %d 个站点)', numStations));
                
                t = (currentFrameIdx-1)/fps;
                self.txtFrameInfo.Text = sprintf('帧: %d / %d    时间: %.2f s', currentFrameIdx, self.nFrames, t);
                
                % --- [功能 4 修复：进度回调] ---
                progress = 0; msg = '...';
                if (endF - startF) > 0
                    progress = (currentFrameIdx - startF) / (endF - startF);
                end
                
                if ~isempty(waitbarHandle) && isvalid(waitbarHandle)
                    msg = sprintf('帧 %d/%d (%.1f%%) - 站点分析中...', ...
                        currentFrameIdx, endF, progress * 100);
                    waitbar(progress, waitbarHandle, msg);
                else
                    msg = sprintf('帧 %d/%d (%.1f%%)', currentFrameIdx, endF, progress * 100);
                end
                
                % [FIX] Call external progress callback if provided
                if nargin > 11 && ~isempty(progressCallback)
                    progressCallback(progress, msg);
                end
                % --- [修复结束] ---
                
                drawnow('limitrate'); % 强制刷新 UI
                
                currentFrameIdx = currentFrameIdx + P_Global.analyzeEveryN;
            end % 逐帧循环结束
            
            if ~isempty(waitbarHandle) && isvalid(waitbarHandle), close(waitbarHandle); end
            
            % 3. 结果后处理
            % (此部分与 runAnalysisCore 完全相同)
            Results = cell(numStations, 1);
            
            for i = 1:numStations
                S = Stations(i);
                P = P_Global; 
                L = S.LocalParams; 
                
                pos = TempData(i).pos(1:TempData(i).idx, :);
                inside = TempData(i).inside(1:TempData(i).idx, :);
                
                is_valid = ~any(isnan(pos), 2);
                
                % [CRITICAL FIX V2] 确保 'dist' 数组尺寸匹配 'pos' 行数，以避免索引错误
                num_rows = size(pos, 1);
                
                if num_rows == 0
                    dist = zeros(0, 1); % 0x1 数组 (空)
                elseif num_rows == 1
                    dist = 0; % 1x1 数组 (单帧时距离为 0)
                else
                    % 对于 2 行或更多，计算距离
                    dist = [0; sqrt(sum(diff(pos, 1, 1).^2, 2))];
                end
                
                % 确保 'dist' 是列向量，以匹配其他表格列
                dist = dist(:); 
                
                % 应用 NaN 掩码
                dist(~is_valid) = NaN;
                dist_m = dist * P.scalePx2Cm / 100; 
                
                f_idx = (startF:P.analyzeEveryN:endF)';
                f_idx = f_idx(1:TempData(i).idx); 
                tvec = (f_idx - 1) / fps;
                
                speeds_m_s = dist_m / dt_step;
                
                isSlow = speeds_m_s < L.stationarySpeedThreshold_cm_s / 100; 
                
                resTbl = table(f_idx, tvec, pos(:,1), pos(:,2), dist, dist_m, speeds_m_s, isSlow, ...
                    'VariableNames',{'Frame','Time_s','X','Y','Distance_px','Distance_m','Speed_m_s','IsStationary'});
                
                Trajectories{i} = pos(is_valid,:); 
                
                areaNames = arrayfun(@(a)a.name, S.Areas, 'UniformOutput', false);
                Time_s = zeros(numel(S.Areas),1);
                Entries = zeros(numel(S.Areas),1);
                Distance_m = zeros(numel(S.Areas),1);
                
                minDwellSteps = max(1, ceil(P.minDwellTime_s / dt_step)); 
                
                for k=1:numel(S.Areas)
                    in = inside(:,k);
                    Time_s(k) = XuX_Analyzer.nanSum(in) * dt_step; 
                    
                    trans = find(diff([false; in])==1); 
                    cnt = 0;
                    for ti = trans'
                        idxStay = ti:min(ti+minDwellSteps-1, numel(in));
                        if all(in(idxStay)), cnt = cnt + 1; end
                    end
                    Entries(k) = cnt;
                    Distance_m(k) = XuX_Analyzer.nanSum(dist_m(in));
                end
                
                perAreaTbl = table(string(areaNames'), Time_s, Entries, Distance_m, ...
                    'VariableNames', {'AreaName','Time_s','Entries','Distance_m'});
                
                valid_mask = (f_idx >= P.startF & f_idx <= P.endF);
                
                totalTime = sum(valid_mask) * dt_step;
                totalDist_m = XuX_Analyzer.nanSum(dist_m(valid_mask));
                averageSpeed_m_s = totalDist_m / totalTime;
                
                minStatSteps = max(1, ceil(L.stationaryMinDuration_s / dt_step));
                isStationaryDuration = false(size(isSlow));
                
                isSlow_valid = isSlow(valid_mask);
                
                current_run_length = 0;
                start_idx_run = 0;
                
                for j = 1:numel(isSlow_valid)
                    if isSlow_valid(j)
                        if current_run_length == 0
                            start_idx_run = j; 
                        end
                        current_run_length = current_run_length + 1;
                    else
                        if current_run_length >= minStatSteps
                            isStationaryDuration(start_idx_run:j-1) = true;
                        end
                        current_run_length = 0;
                    end
                end
                if current_run_length >= minStatSteps
                    isStationaryDuration(start_idx_run:end) = true;
                end
                
                stationaryTime_s = XuX_Analyzer.nanSum(isStationaryDuration) * dt_step;

                summaryTbl = table(totalTime, totalDist_m, averageSpeed_m_s, stationaryTime_s, ...
                    'VariableNames', {'TotalTime_s','TotalDistance_m','AverageSpeed_m_s','StationaryTime_s'});
                
                Results{i}.perFrameTbl = resTbl;
                Results{i}.perAreaTbl = perAreaTbl;
                Results{i}.summaryTbl = summaryTbl;

            end % 结果后处理循环结束
        end
        
        function onSlider(self)
            % (恢复) 恢复为使用全局范围
            self.frameIdx = round(min(max(self.sldFrame.Value, self.rangeStartF), self.rangeEndF));
            refreshPreview(self);
        end
        
        function setScale(self)
            self.params.scalePx2Cm = self.spnScale.Value;
        end
        
        % (替换)
        function onCalibrateScale(self)
            if isempty(self.vReader), uialert(self.fig,'请先加载视频','提示'); return; end
            
            idx = self.ActiveStationIdx;
            if idx == 0, return; end
            
            % --- 获取当前站点的裁剪设置 ---
            currentCropRect = self.Stations(idx).CropRect;
            
            fr = readFrameAt(self, self.frameIdx);
            
            % (修正) 检查当前站点是否有裁剪框，并判断是否启用
            if ~isempty(currentCropRect) && self.chkUseCrop.Value 
                fr = XuX_Analyzer.safeCropStatic(fr, currentCropRect);
            end

            fig2 = figure('Name', '标尺校准，双击结束'); 
            imshow(fr); 
            
            setStatus(self,'请绘制标尺线段，双击结束...');
            
            h = drawline; 
            wait(h); 
            
            p1 = round(h.Position(1,:)); 
            p2 = round(h.Position(2,:)); 
            
            pixelDist = sqrt(sum((p1 - p2).^2));
            close(fig2);
            
            if pixelDist < 10
                uialert(self.fig,'绘制线段过短或无效，校准已取消。','提示');
                setStatus(self,'标尺校准取消');
                return;
            end
            
            answer = inputdlg('请输入该线段的实际长度 (cm):', '输入实际长度', [1 50]);
            
            if isempty(answer) || isempty(str2double(answer{1}))
                setStatus(self,'标尺校准取消');
                return;
            end
            
            realDistCm = str2double(answer{1});
            scale = realDistCm / pixelDist;
            
            % (修正) 标尺是全局属性，保存到 GlobalParams
            self.GlobalParams.scalePx2Cm = scale; 
            
            % (修正) 更新 UI
            self.spnScale.Value = scale;
            
            setStatus(self,sprintf('标尺已校准: 1 像素 = %.4f cm (全局参数)', scale));
        end

        % (替换) 辅助函数：绘制站点的覆盖层 (站点框红色 + 区域)
        function drawOverlays(self, ax, S, isActive)
            % S: Station 结构体
            % isActive: Boolean, 是否为当前选中的站点
            
            if ~isvalid(ax) || isempty(S)
                return;
            end
            
            % --- 1. 绘制站点范围框 (CropRect) ---
            % 需求：站点边缘线条颜色改成红色 (Red)
            % 样式区分：选中=实线，未选中=虚线
            if ~isempty(S.CropRect)
                if isActive
                    lineStyle = '-';  % 实线
                    lineWidth = 2.0;
                else
                    lineStyle = '--'; % 虚线
                    lineWidth = 1.0;
                end
                
                rectangle(ax, 'Position', S.CropRect, ...
                    'EdgeColor', 'r', ... % [修改] 改为红色
                    'LineWidth', lineWidth, ...
                    'LineStyle', lineStyle);
                
                % [修改] 文本颜色也改为红色，保持一致
                text(ax, S.CropRect(1), S.CropRect(2)-5, S.Name, ...
                    'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold', 'Interpreter', 'none');
            end
            
            % --- 2. 绘制区域 (Areas) ---
            currentAreas = S.Areas;
            for i = 1:numel(currentAreas)
                area = currentAreas(i);
                if isfield(area, 'vertices') && ~isempty(area.vertices)
                    verts = area.vertices;
                    
                    % 样式定义
                    if isActive
                        edgeStyle = '-';
                        faceAlpha = 0.3; % 选中：较清晰
                        lineWidth = 1.5;
                    else
                        edgeStyle = '--';
                        faceAlpha = 0.2; % 未选中：较隐蔽
                        lineWidth = 1.0;
                    end
                    
                    patch(ax, ...
                        'XData', verts(:,1), ...
                        'YData', verts(:,2), ...
                        'FaceColor', area.color, ...
                        'FaceAlpha', faceAlpha, ...
                        'EdgeColor', area.color, ... 
                        'LineStyle', edgeStyle, ...
                        'LineWidth', lineWidth);
                end
            end
        end

        % (新增) 辅助函数：在指定坐标轴上绘制调光蒙版
        function drawDimmingPatches(self, ax, rect, frameSize)
            if ~isvalid(ax) || isempty(rect)
                return;
            end

            H = frameSize(1);
            W = frameSize(2);
            
            % 矩形内部坐标
            x1 = rect(1);
            y1 = rect(2);
            w = rect(3);
            h = rect(4);
            x2 = x1 + w;
            y2 = y1 + h;

            % 绘制4个矩形 patch (上, 下, 左, 右) 覆盖非活动区域
            
            % 上
            patch(ax, 'Vertices', [0.5 0.5; W+0.5 0.5; W+0.5 y1; 0.5 y1], 'Faces', 1:4, 'FaceColor', 'k', 'FaceAlpha', 0.6, 'EdgeColor', 'none');
            % 下
            patch(ax, 'Vertices', [0.5 y2; W+0.5 y2; W+0.5 H+0.5; 0.5 H+0.5], 'Faces', 1:4, 'FaceColor', 'k', 'FaceAlpha', 0.6, 'EdgeColor', 'none');
            % 左
            patch(ax, 'Vertices', [0.5 y1; x1 y1; x1 y2; 0.5 y2], 'Faces', 1:4, 'FaceColor', 'k', 'FaceAlpha', 0.6, 'EdgeColor', 'none');
            % 右
            patch(ax, 'Vertices', [x2 y1; W+0.5 y1; W+0.5 y2; x2 y2], 'Faces', 1:4, 'FaceColor', 'k', 'FaceAlpha', 0.6, 'EdgeColor', 'none');
        end

% (替换) 刷新预览：全图显示 + 差异化样式 + 遮罩模拟裁剪
        function refreshPreview(self)
            if isempty(self.axProcessed) || ~isgraphics(self.axProcessed)
                return;
            end
            
            if isempty(self.vReader)
                cla(self.axProcessed); 
                title(self.axProcessed,'识别预览');
                self.txtFrameInfo.Text = '帧: - / 时间: - s';
                return;
            end
            
            % --- 1. 准备基础数据 ---
            activeIdx = self.ActiveStationIdx;
            if activeIdx == 0 || activeIdx > numel(self.Stations)
                cla(self.axProcessed); title(self.axProcessed,'站点无效');
                return;
            end
            
            activeStation = self.Stations(activeIdx);
            activeL = activeStation.LocalParams;
            
            % 确保帧索引在全局范围内
            self.frameIdx = round(min(max(self.frameIdx, self.rangeStartF), self.rangeEndF));
            frRGB = readFrameAt(self, self.frameIdx); % 始终读取全尺寸帧
            
            % 获取全局设置
            useCropGlobal = self.chkUseCrop.Value;
            
            % --- 2. 绘制背景帧 (始终全图) ---
            imshow(frRGB, 'Parent', self.axProcessed); 
            hold(self.axProcessed, 'on');
            
            % --- 3. 绘制视觉遮罩 (Dimming) 模拟裁剪效果 ---
            % 仅当启用裁剪且当前站点有定义的裁剪框时，调暗非关注区域
            if useCropGlobal && ~isempty(activeStation.CropRect)
                self.drawDimmingPatches(self.axProcessed, activeStation.CropRect, self.frameSize);
            end

            % --- 4. 循环绘制所有站点 (Overlay) ---
            % 要求：始终显示所有站点、所有区域
            numStations = numel(self.Stations);
            for i = 1:numStations
                S = self.Stations(i);
                isActive = (i == activeIdx); % 标记是否为当前选中的站点
                
                % 调用新版的绘制函数
                self.drawOverlays(self.axProcessed, S, isActive);
            end
            
            % --- 5. 绘制当前站点的识别结果预览 (实时计算结果) ---
            % 为了演示效果，我们只计算并绘制"当前激活站点"的识别结果
            % (如果需要显示所有站点的识别结果，需要遍历计算，但这可能会卡顿)
            
            % 5a. 准备局部计算数据
            currentCropRect = activeStation.CropRect;
            if useCropGlobal && ~isempty(currentCropRect)
                fr_calc = XuX_Analyzer.safeCropStatic(frRGB, currentCropRect);
                bg_calc = XuX_Analyzer.safeCropStatic(self.bgFrame, currentCropRect);
                x_offset = currentCropRect(1) - 1;
                y_offset = currentCropRect(2) - 1;
            else
                fr_calc = frRGB;
                bg_calc = self.bgFrame;
                x_offset = 0;
                y_offset = 0;
            end
            
            gray_calc = im2gray(fr_calc);
            if size(bg_calc, 3) == 3, bg_calc = im2gray(bg_calc); end
            
            % 5b. 计算 Mask
            mask_local = XuX_Analyzer.makeMask(gray_calc, bg_calc, activeL);
            
            % 5c. 寻找质心
            centroid_global = [NaN, NaN];
            cc = bwconncomp(mask_local);
            if cc.NumObjects > 0
                Sprops = regionprops(cc, 'Area', 'Centroid');
                [~, ii] = max([Sprops.Area]);
                centroid_local = Sprops(ii).Centroid;
                centroid_global = centroid_local + [x_offset, y_offset];
            end
            
            % 5d. 绘制识别结果 (白色轮廓 + 红色十字)
            B = bwboundaries(mask_local);
            for k = 1:length(B)
                % 转换回全局坐标绘制
                plot(self.axProcessed, B{k}(:,2) + x_offset, B{k}(:,1) + y_offset, 'w', 'LineWidth', 0.5);
            end
            
            if ~any(isnan(centroid_global))
                plot(self.axProcessed, centroid_global(1), centroid_global(2), 'r+', 'MarkerSize', 10, 'LineWidth', 1.5);
            end
            
            hold(self.axProcessed, 'off');
            
            % 设置标题
            activeName = activeStation.Name;
            if isempty(activeName), activeName = sprintf('Station %d', activeIdx); end
            title(self.axProcessed, sprintf('预览: %s (全局视图)', activeName));
            
            % 锁定视图范围 (防止意外缩放)
            xlim(self.axProcessed, [0.5, self.frameSize(2)+0.5]);
            ylim(self.axProcessed, [0.5, self.frameSize(1)+0.5]);
            
            % --- 6. 更新文字信息 ---
            t = (self.frameIdx-1)/self.fps;
            self.txtFrameInfo.Text = sprintf('帧: %d / %d    时间: %.2f s', self.frameIdx, self.nFrames, t);
        end
        
        %% ------------------------- 工具函数 -------------------------
        
        % (替换)
        function refreshAreaList(self)
            if self.ActiveStationIdx == 0 || isempty(self.Stations)
                self.lstAreas.Items     = {};
                self.lstAreas.ItemsData = {};
                self.lstAreas.Value     = {};
                return;
            end
            
            % 从当前激活的站点读取
            currentAreas = self.Stations(self.ActiveStationIdx).Areas;
            
            if isempty(currentAreas)
                self.lstAreas.Items     = {};
                self.lstAreas.ItemsData = {};
                self.lstAreas.Value     = {};
                return;
            end
            
            names = arrayfun(@(a)a.name, currentAreas, 'UniformOutput', false);
            self.lstAreas.Items     = names;
            self.lstAreas.ItemsData = num2cell(1:numel(currentAreas));

            % 确保选择不越界 (FIXED: 使用 isnumeric/iscell 进行安全检查)
            val = self.lstAreas.Value;
            idx_to_check = NaN;
            if isnumeric(val)
                idx_to_check = val;
            elseif iscell(val) && ~isempty(val)
                idx_to_check = val{1}; % 确保如果返回 cell，取第一个元素
            end
            
            if ~isnan(idx_to_check) && idx_to_check > numel(currentAreas)
                self.lstAreas.Value = {};
            end

            % 默认选中最后一个
            if isempty(self.lstAreas.Value) && ~isempty(self.lstAreas.ItemsData)
                 self.lstAreas.Value = self.lstAreas.ItemsData{end};
            end
        end
        
        function setStatus(self,msg)
            self.txtStatus.Text = msg;
            drawnow;
        end
        
        function fr = getFrameAt(self, idx)
            idx = round(min(max(idx,1), self.nFrames));
            safeTime = max(0, (idx-1)/self.fps);
            safeTime = min(safeTime, max(0, self.vReader.Duration - 0.75/self.fps));
            self.vReader.CurrentTime = safeTime;
            try
                fr = readFrame(self.vReader);
            catch
                self.vReader.CurrentTime = max(0, safeTime - 1/self.fps);
                fr = readFrame(self.vReader);
            end
            if size(fr,3)==1, fr = repmat(fr,[1 1 3]); end
        end
        
        function fr = readFrameAt(self, idx)
            fr = getFrameAt(self, idx);
        end           
                
        % (替换)
        function frame = getCurrentFrameProcessed(self, asMask)
            % (新) 获取当前站点的设置
            idx = self.ActiveStationIdx;
            if idx == 0 || isempty(self.Stations)
                % 安全防护：如果站点无效，不裁剪
                currentCropRect = [];
                P_preview.threshold = 50;
                P_preview.minBlobArea = 50;
                P_preview.morphRadius = 3;
            else
                S = self.Stations(idx);
                currentCropRect = S.CropRect;
                P_preview = S.LocalParams; % 预览只需要局部参数
            end
            
            frameRGB = readFrameAt(self, self.frameIdx);
            
            if ~isempty(currentCropRect) && self.chkUseCrop.Value
                frameRGB = XuX_Analyzer.safeCropStatic(frameRGB, currentCropRect);
            end
            
            gray = im2gray(frameRGB);
            
            if asMask
                % (新) 使用站点的局部参数
                frame = self.makeMask(gray, self.bgFrame, P_preview);
            else
                frame = gray;
            end
        end
        
        function [resTbl, perAreaTbl, trajImg, heatImg, wasCanceled] = runAnalysis(self, P, vr, bgFrame, varargin)
            if self.chkLivePreview.Value
                if self.chkUseCrop.Value
                    P.cropRect = self.cropRect;
                else
                    P.cropRect = [];
                end
                [resTbl, perAreaTbl, trajImg, heatImg, wasCanceled] = runAnalysisLive(self, P, vr, bgFrame, varargin{:});
            else
                if self.chkUseCrop.Value
                    P.cropRect = self.cropRect;
                else
                    P.cropRect = [];
                end
                [resTbl, perAreaTbl, trajImg, heatImg] = XuX_Analyzer.runAnalysisCore(vr, P, self.areas, ...
                    P.cropRect, bgFrame);
                wasCanceled = false;
            end
        end

        function autoSaveResults(self, res, perArea, trajImg, heatImg, vidPath)
            try
                [vp, vbase, ~] = fileparts(vidPath);
                outDir = fullfile(vp, 'EPM_Results');
                if ~exist(outDir,'dir'), mkdir(outDir); end
                ts = datestr(now,'yyyymmdd_HHMMSS');
                base = sprintf('%s_%s', vbase, ts);
                csv1 = fullfile(outDir,[base '_perFrame.csv']);
                csv2 = fullfile(outDir,[base '_perArea.csv']);
                p1   = fullfile(outDir,[base '_trajectory.png']);
                p2   = fullfile(outDir,[base '_heatmap.png']);
                writetable(res, csv1);
                writetable(perArea, csv2);
                imwrite(trajImg, p1);
                imwrite(heatImg, p2);

                % --- [新代码] 自动保存矢量图 ---
                try
                    posData = [res.X, res.Y];
                    % 使用 trajImg 的尺寸作为基准 frameSize (已考虑裁剪)
                    frameSz = [size(trajImg, 1), size(trajImg, 2)];
                    svgPath = fullfile(outDir,[base '_trajectory.svg']);
                    figPath = fullfile(outDir,[base '_heatmap.fig']);
                    
                    XuX_Analyzer.saveTrajectoryVector(posData, frameSz, svgPath);
                    XuX_Analyzer.saveHeatmapVector(posData, frameSz, figPath);
                catch ME_vec_auto
                    fprintf('自动保存矢量图失败: %s\n', ME_vec_auto.message);
                end
                % --- [新代码结束] ---
                
                totalDistance = XuX_Analyzer.nanSum(res.Distance_m);
                if ismember('IsStationary', res.Properties.VariableNames)
                    if height(res) > 1
                        avg_dt = mean(diff(res.Time_s));
                        v_fps_equiv = 1 / avg_dt; 
                    else
                        v_fps_equiv = 1; 
                    end
                    totalStationary = sum(res.IsStationary) / v_fps_equiv;
                    stCount = XuX_Analyzer.countStationaryEvents(res.IsStationary, v_fps_equiv, self.spnStationaryMinSec.Value);
                else
                    totalStationary = NaN; stCount = NaN;
                end
                summ = table({vbase}, totalDistance, totalStationary, stCount, ...
                    'VariableNames',{'Video','TotalDistance_m','TotalStationaryTime_s','StationaryCount'});
                writetable(summ, fullfile(outDir,[base '_summary.csv']));
                
                setStatus(self, ['结果已自动保存到: ' outDir]);
            catch ME
                uialert(self.fig, ['自动保存失败：' ME.message], '保存错误');
            end
        end
    end

%% =================================================================
    %                   批量分析 (BATCH ANALYSIS)
    %  =================================================================
    methods
        % (替换) onBatchGUI - [功能 4 ETR UI 调整]
        function onBatchGUI(self)
            
            % 检查窗口是否已存在且有效
            if isscalar(self.fBatch) && isvalid(self.fBatch) && ishghandle(self.fBatch)
                figure(self.fBatch);
                return;
            end
            
            % --- 1. 创建独立的批量分析配置界面 ---
            fBatch = uifigure('Name', '批量分析配置', 'Position', [100 100 1000 600]);
            self.fBatch = fBatch; % 将句柄存为属性
            
            % --- 主网格布局 ---
            g = uigridlayout(fBatch, [5, 10]); 
            g.RowHeight = {30, '1x', 30, 30, 30}; 
            g.ColumnWidth = {100, 100, 100, 120, 10, 120, '1x', 120, 120, 120}; 
            g.Padding = [10 10 10 10];
            
            % --- Row 1: 按钮区 (保持不变) ---
            
            % 导入视频
            btnImport = uibutton(g, 'Text', '导入视频...', 'ButtonPushedFcn', @(~,~) onImportVideos());
            btnImport.Layout.Column = 1;
            btnImport.Layout.Row = 1;
            
            % 设置配置
            btnSettings = uibutton(g, 'Text', '设置配置', 'ButtonPushedFcn', @(~,~) onSetSettings());
            btnSettings.Layout.Column = 2;
            btnSettings.Layout.Row = 1;
            
            % 设置背景
            btnBackground = uibutton(g, 'Text', '设置背景', 'ButtonPushedFcn', @(~,~) onSetBackground());
            btnBackground.Layout.Column = 3;
            btnBackground.Layout.Row = 1;
            
            % 删除选中项
            btnDelete = uibutton(g, 'Text', '删除选中项', 'ButtonPushedFcn', @(~,~) onDeleteSelected());
            btnDelete.Layout.Column = 4;
            btnDelete.Layout.Row = 1;
            
            % 全选/反选
            self.btnSelectAllBatch = uibutton(g, 'Text', '全选/反选', 'ButtonPushedFcn', @(~,~) onSelectAllVideosBatch());
            self.btnSelectAllBatch.Layout.Row = 1;
            self.btnSelectAllBatch.Layout.Column = 6; 
            
            % 实时预览复选框
            self.chkBatchLivePreview = uicheckbox(g, 'Text', '显示实时预览', 'Value', false);
            self.chkBatchLivePreview.Layout.Row = 1;
            self.chkBatchLivePreview.Layout.Column = 8;
            
            % 开始批量分析
            btnStart = uibutton(g, 'Text', '开始批量分析', 'ButtonPushedFcn', @(~,~) onStartAnalysis());
            btnStart.Layout.Column = [9 10];
            btnStart.Layout.Row = 1;
            
            % --- Row 2: 视频配置表格 (保持不变) ---
            self.tblVideos = uitable(g, ...
                'ColumnName', {'视频名称', '设置文件 (.mat)', '背景文件 (图像)', '状态', '视频路径'}, ...
                'ColumnFormat', {'char', 'char', 'char', 'char', 'char'}, ...
                'ColumnEditable', [false, false, false, false, false], ...
                'RowName', 'numbered', ...
                'ColumnWidth', {'1x', '1x', '1x', 100, 0.01}, ... 
                'Tooltip', '点击左侧行号选中整行，按住Ctrl/Shift可多选。');
            self.tblVideos.Layout.Row = 2;
            self.tblVideos.Layout.Column = [1 10];
            
            % --- Row 3: 进度条/状态行 (主要修改区域) ---
            
            % 1. 左侧标签
            lblProgress = uilabel(g, 'Text', '总进度:');
            lblProgress.Layout.Row = 3;
            lblProgress.Layout.Column = 1;
            
            % 2. [新增] 替换进度条，用于显示 ETR (中间突出位置)
            self.txtBatchETR = uilabel(g, ...
                'Text', '预计剩余时间...', ...
                'FontWeight', 'bold', ...
                'FontSize', 14, ... 
                'HorizontalAlignment', 'center');
            self.txtBatchETR.Layout.Row = 3;
            self.txtBatchETR.Layout.Column = [2 8];
            
            % 3. [重用] 原进度状态文本框，显示详细的视频进度/百分比 (右侧)
            % 注意：原 self.gaugeBatchProgress 被移除
            self.txtBatchStatus = uilabel(g, 'Text', '就绪。', 'FontWeight', 'normal');
            self.txtBatchStatus.Layout.Row = 3;
            self.txtBatchStatus.Layout.Column = [9 10];
            
            % --- Row 4 & 5: 保存路径 (保持不变) ---
            
            % Row 4: 结果保存路径
            lblSaveDir = uilabel(g, 'Text', '结果保存路径:');
            lblSaveDir.Layout.Row = 4;
            lblSaveDir.Layout.Column = 1;
            
            self.edtSaveDir = uieditfield(g, 'Editable', 'off', 'Value', pwd());
            self.edtSaveDir.Layout.Row = 4;
            self.edtSaveDir.Layout.Column = [2 8];
            
            btnSelectDir = uibutton(g, 'Text', '选择目录', 'ButtonPushedFcn', @(~,~) onSelectSaveDir());
            btnSelectDir.Layout.Row = 4;
            btnSelectDir.Layout.Column = [9 10];
            
            % Row 5: 文件名
            lblFileName = uilabel(g, 'Text', '文件名:');
            lblFileName.Layout.Row = 5;
            lblFileName.Layout.Column = 1;
            
            self.edtFileName = uieditfield(g, 'Value', 'Batch_Combined_MultiStation_Results.xlsx');
            self.edtFileName.Layout.Row = 5;
            self.edtFileName.Layout.Column = [2 10];
            
            % --- 数据初始化 ---
            if ~isprop(self, 'batchData') || isempty(self.batchData)
                 self.batchData = cell(0, 5); % 初始化为 class 属性
            end
            updateTableDisplay(); % 首次加载时显示任何旧数据
            
            % --- Nested UI Callback Functions (保留之前的辅助函数) ---
            
            function onSelectSaveDir()
                newDir = uigetdir(self.edtSaveDir.Value,'选择批量结果保存文件夹');
                if ischar(newDir)
                    self.edtSaveDir.Value = newDir;
                end
                figure(self.fBatch); % 恢复焦点
            end
            
            function onSelectAllVideosBatch()
                data = self.tblVideos.Data;
                if isempty(data)
                    return;
                end
                
                if isempty(self.tblVideos.Selection) || size(self.tblVideos.Selection, 1) < size(data, 1)
                    rows = (1:size(data, 1))';
                    cols = ones(size(rows)); 
                    self.tblVideos.Selection = [rows, cols];
                else
                    self.tblVideos.Selection = [];
                end
            end

            function selectedRows = getSelectedRows()
                selectionMatrix = self.tblVideos.Selection;
                if isempty(selectionMatrix)
                    selectedRows = [];
                else
                    selectedRows = unique(selectionMatrix(:, 1));
                end
            end

            function updateTableDisplay()
                batchDataLocal = self.batchData;

                if isempty(batchDataLocal)
                    self.tblVideos.Data = {};
                    self.tblVideos.BackgroundColor = [1 1 1]; 
                    return;
                end
                
                dataToDisplay = batchDataLocal(:, [2 3 4 5]); 

                if size(dataToDisplay, 2) ~= numel(self.tblVideos.ColumnName) - 1 
                    warning('批量分析数据结构异常，无法更新表格显示。');
                    self.tblVideos.Data = {};
                    return;
                end

                self.tblVideos.Data = dataToDisplay;
                
                numRows = size(batchDataLocal, 1);
                bgColorsNumeric = zeros(numRows, 3); 
                
                for r = 1:numRows
                    status = batchDataLocal{r, 5};
                    color = [1 1 1]; 
                    
                    if strcmp(status, '分析失败')
                        color = [1.0 0.8 0.8]; 
                    elseif strcmp(status, '已完成')
                        color = [0.8 1.0 0.8]; 
                    elseif strcmp(status, '未设置') || strcmp(status, '待配置')
                        color = [1.0 1.0 0.8]; 
                    elseif strcmp(status, '进行中')
                        color = [0.8 0.8 1.0]; 
                    elseif strcmp(status, '待分析')
                         color = [0.9 0.9 0.9]; 
                    end
                    
                    bgColorsNumeric(r, :) = color; 
                end
                
                self.tblVideos.BackgroundColor = bgColorsNumeric;
            end
            
            function onImportVideos()
                filter = {'*.mp4;*.avi;*.mov;*.wmv;*.mpg', '视频文件 (*.mp4, *.avi, *.mov, *.wmv, *.mpg)'; '*.*', '所有文件'};
                [filenames, pathname] = uigetfile(filter, '选择要分析的视频文件', 'MultiSelect', 'on');
                
                if isequal(filenames, 0)
                    figure(self.fBatch); 
                    return;
                end
                
                if ischar(filenames)
                    filenames = {filenames};
                end
                
                numNewFiles = numel(filenames);
                newRows = cell(numNewFiles, 5);
                
                for k = 1:numNewFiles
                    fullPath = fullfile(pathname, filenames{k});
                    newRows{k, 1} = fullPath; % Video Path
                    newRows{k, 2} = filenames{k}; % Video Name
                    newRows{k, 3} = '未设置'; % Setting Path
                    newRows{k, 4} = '未设置'; % Background Path
                    newRows{k, 5} = '待配置'; % Status
                end
                
                self.batchData = [self.batchData; newRows];
                updateTableDisplay();
                figure(self.fBatch); 
            end
            
            function onSetSettings()
                selectedRows = getSelectedRows(); 
                
                if isempty(selectedRows) 
                    uialert(self.fBatch, '请先在表格中选中要配置的视频行。', '未选择视频');
                    return;
                end
                
                [setF, setP] = uigetfile('*.mat', '选择设置文件 (.mat)');
                if isequal(setF, 0)
                    figure(self.fBatch); 
                    return;
                end
                
                setPath = fullfile(setP, setF);
                
                for rowIdx = selectedRows'
                    self.batchData{rowIdx, 3} = setPath;
                    if ~strcmp(self.batchData{rowIdx, 4}, '未设置')
                        self.batchData{rowIdx, 5} = '待分析';
                    else
                        self.batchData{rowIdx, 5} = '待配置';
                    end
                end
                updateTableDisplay();
                figure(self.fBatch); 
            end
            
            function onSetBackground()
                selectedRows = getSelectedRows(); 
                
                if isempty(selectedRows)
                    uialert(self.fBatch, '请先在表格中选中要配置的视频行。', '未选择视频');
                    return;
                end
                
                filter = {'*.png;*.jpg;*.tif','图像文件 (*.png, *.jpg, *.tif)'; '*.*', '所有文件'};
                [bgF, bgP] = uigetfile(filter, '选择背景图像文件');
                if isequal(bgF, 0)
                    figure(self.fBatch); 
                    return;
                end
                
                bgPath = fullfile(bgP, bgF);
                
                for rowIdx = selectedRows'
                    self.batchData{rowIdx, 4} = bgPath;
                    if ~strcmp(self.batchData{rowIdx, 3}, '未设置')
                        self.batchData{rowIdx, 5} = '待分析';
                    else
                        self.batchData{rowIdx, 5} = '待配置';
                    end
                end
                updateTableDisplay();
                figure(self.fBatch); 
            end
            
            function onDeleteSelected()
                selectedRows = getSelectedRows(); 
                
                if isempty(selectedRows)
                    uialert(self.fBatch, '请先选中要删除的视频行。', '未选择视频');
                    return;
                end
                
                selectedRows = sort(selectedRows, 'descend'); 
                
                for rowIdx = selectedRows'
                    self.batchData(rowIdx, :) = [];
                end
                updateTableDisplay();
            end
            
            % ETR 格式化辅助函数 (保持不变)
            function str = formatTimeS(seconds)
                seconds = round(seconds);
                if seconds < 60
                    str = sprintf('%d 秒', seconds);
                elseif seconds < 3600
                    mins = floor(seconds / 60);
                    secs = mod(seconds, 60);
                    str = sprintf('%d 分 %d 秒', mins, secs);
                else
                    hours = floor(seconds / 3600);
                    mins = floor(mod(seconds, 3600) / 60);
                    str = sprintf('%d 小时 %d 分', hours, mins);
                end
            end

            
            % Callback 4: Start Analysis (核心逻辑)
            function onStartAnalysis()
                
                rowsToAnalyze = find(strcmp(self.batchData(:, 5), '待分析'));
                
                if isempty(rowsToAnalyze)
                    uialert(self.fBatch, '没有配置完整且状态为"待分析"的视频。', '分析中止');
                    return;
                end
                
                saveDir = self.edtSaveDir.Value;
                finalFileName = self.edtFileName.Value;
                
                if isempty(saveDir)
                    uialert(self.fBatch, '请选择结果保存路径。', '缺少配置');
                    return;
                end
                
                if ~endsWith(finalFileName, '.xlsx', 'IgnoreCase', true)
                    finalFileName = [strrep(finalFileName, '.csv', ''), '.xlsx'];
                end
                
                % --- 初始化全局列名和分组 (保持不变) ---
                exportHeader1 = {'Analyze Information', 'Analyze Information', 'Analyze Information', 'Analyze Information', 'Analyze Information', 'Analyze Information', 'Analyze Information', 'Analyze Information'};
                exportHeader2 = {'VideoName', 'VideoDuration_s', 'BG_Frame', 'Start_s', 'End_s', 'AnalyzeEveryN', 'SettingFilePath', 'BackgroundFilePath'};
                internalColNames = {'VideoName', 'VideoDuration_s', 'BG_Frame', 'Start_s', 'End_s', 'AnalyzeEveryN', 'SettingFilePath', 'BackgroundFilePath'}; 
                colNamesFixedCount = numel(internalColNames); 
                
                combinedTbl = []; 
                
                % [解决问题 4: 进度集成]
                totalVideos = numel(rowsToAnalyze);
                currentVideoCount = 0;
                
                % [修改] 初始化 ETR 文本
                self.txtBatchETR.Text = '正在开始...';
                self.txtBatchStatus.Text = sprintf('正在开始批量分析 %d 个视频...', totalVideos);
                
                % --- ETR 计时器 ---
                batchStartTime = tic;
                
                % --- Analysis Loop ---
                for k = 1:totalVideos 
                    i = rowsToAnalyze(k); 
                    currentVideoCount = currentVideoCount + 1;
                    
                    vidFile = self.batchData{i, 1};
                    [~, baseName, ~] = fileparts(self.batchData{i, 2});
                    setPath = self.batchData{i, 3};
                    bgPath = self.batchData{i, 4};
                    vReader = []; 
                    self.batchData{i, 5} = '进行中';
                    updateTableDisplay(); 
                    
                    combinedRowDataFixed = {baseName, 0, sprintf('%dx%d', 0, 0), 'N/A', 'N/A', 0, setPath, bgPath};
                    P_Global = []; 
                    
                    try
                        % 更新状态
                        self.txtBatchStatus.Text = sprintf('(%d/%d) 正在加载: %s...', currentVideoCount, totalVideos, self.batchData{i, 2});
                        drawnow limitrate;

                        S_in = load(setPath);
                        P_Global = S_in.GlobalParams;
                        Stations = S_in.Stations;
                        
                        if isempty(Stations)
                             error('设置文件中没有可分析的站点。');
                        end
                        
                        bgFrame = imread(bgPath);
                        if size(bgFrame, 3) == 3
                            bgFrame = im2gray(bgFrame);
                        end
                        
                        vReader = VideoReader(vidFile);
                        fps_v = max(1e-6, vReader.FrameRate);
                        nFrames = floor(vReader.Duration * fps_v);
                        
                        % --- 计算帧范围 ---
                        [startF, endF, s_out, e_out_nan] = self.calculateFrameRangeStatic(P_Global.startTime, P_Global.endTime, fps_v, nFrames, P_Global.analyzeEveryN, vReader.Duration);
                        P_Global.startF = startF;
                        P_Global.endF = endF;
                        P_Global.startTime = s_out;
                        P_Global.endTime = e_out_nan;
                        dt = 1/fps_v * P_Global.analyzeEveryN;
                        
                        % --- 进度回调定义 ---
                        progressCallback = @(p, msg) updateProgress(p, msg);
                        
                        if self.chkBatchLivePreview.Value
                            [Results, ~] = self.runAnalysisLive(vReader, bgFrame, ...
                                                P_Global, Stations, ...
                                                startF, endF, ...
                                                dt, nFrames, fps_v, ...
                                                self.fig, ...
                                                progressCallback);
                        else
                            [Results, ~] = XuX_Analyzer.runAnalysisCore(vReader, bgFrame, ...
                                                P_Global, Stations, ...
                                                startF, endF, ...
                                                dt, nFrames, fps_v, ...
                                                self.fig, ...
                                                progressCallback); 
                        end
                        
                        % --- 结果解析及汇总 (保持不变) ---
                        combinedRowDataFixed = {baseName, vReader.Duration, ...
                                           sprintf('%dx%d', size(bgFrame,2), size(bgFrame,1)), ...
                                           P_Global.startTime, P_Global.endTime, ...
                                           P_Global.analyzeEveryN, ...
                                           setPath, bgPath};
                        
                        videoDynamicInternalNames = cell(0);
                        videoDynamicExportNames = cell(0);
                        videoDynamicHeader1 = cell(0);
                        videoDynamicColData = cell(0);
                        
                        for s_idx = 1:numel(Stations)
                            stationNameClean = matlab.lang.makeValidName(Stations(s_idx).Name);
                            stationNameDisplay = Stations(s_idx).Name; 
                            summaryTbl = Results{s_idx}.summaryTbl;
                            perAreaTbl = Results{s_idx}.perAreaTbl;
                            
                            % Summary data
                            baseSummaryNames = summaryTbl.Properties.VariableNames;
                            for j = 1:numel(baseSummaryNames)
                                internalColName = [stationNameClean '_' baseSummaryNames{j}];
                                videoDynamicInternalNames{end+1} = internalColName; 
                                videoDynamicExportNames{end+1} = baseSummaryNames{j};
                                videoDynamicHeader1{end+1} = stationNameDisplay; 
                                videoDynamicColData{end+1} = summaryTbl.(baseSummaryNames{j})(1);
                            end
                            
                            % Area data
                            areaNamesInResult = perAreaTbl.AreaName;
                            stationAreaNames = arrayfun(@(a)a.name, Stations(s_idx).Areas, 'UniformOutput', false); 
                            for j = 1:numel(stationAreaNames) 
                                areaName = stationAreaNames{j};
                                
                                internalColTime = [stationNameClean '_' areaName '_Time_s'];
                                internalColEntries = [stationNameClean '_' areaName '_Entries'];
                                internalColDistance = [stationNameClean '_' areaName '_Distance_m'];
                                
                                exportColTime = [areaName '_Time_s'];
                                exportColEntries = [areaName '_Entries'];
                                exportColDistance = [areaName '_Distance_m'];
                                
                                videoDynamicInternalNames = [videoDynamicInternalNames, {internalColTime, internalColEntries, internalColDistance}];
                                videoDynamicExportNames = [videoDynamicExportNames, {exportColTime, exportColEntries, exportColDistance}];
                                videoDynamicHeader1 = [videoDynamicHeader1, {stationNameDisplay, stationNameDisplay, stationNameDisplay}];
                                idxArea = find(strcmp(areaNamesInResult, areaName), 1);
                                if isempty(idxArea)
                                    videoDynamicColData = [videoDynamicColData, {0, 0, 0}]; 
                                else
                                    videoDynamicColData{end+1} = perAreaTbl.Time_s(idxArea);
                                    videoDynamicColData{end+1} = perAreaTbl.Entries(idxArea);
                                    videoDynamicColData{end+1} = perAreaTbl.Distance_m(idxArea);
                                end
                            end
                        end
                        
                        % 更新全局列名
                        newColsMask = ~ismember(videoDynamicInternalNames, internalColNames);
                        newInternalCols = videoDynamicInternalNames(newColsMask);
                        
                        if ~isempty(newInternalCols)
                            internalColNames = [internalColNames, newInternalCols];
                            exportHeader2 = [exportHeader2, videoDynamicExportNames(newColsMask)];
                            exportHeader1 = [exportHeader1, videoDynamicHeader1(newColsMask)];
                        end
                        
                        % 构建最终的行数据
                        finalRowData = cell(1, numel(internalColNames));
                        finalRowData(1:colNamesFixedCount) = combinedRowDataFixed;
                        [~, globalIdx, videoIdx] = intersect(internalColNames, videoDynamicInternalNames, 'stable');
                        finalRowData(globalIdx) = videoDynamicColData(videoIdx);
                        
                        for j = colNamesFixedCount+1:numel(finalRowData)
                            if isempty(finalRowData{j})
                                 finalRowData{j} = 0; 
                            end
                        end
                        
                        % Add to combined table
                        currentRowTbl = cell2table(finalRowData, 'VariableNames', internalColNames);
                        if isempty(combinedTbl)
                            combinedTbl = currentRowTbl;
                        else
                            combinedTbl = [combinedTbl; currentRowTbl];
                        end
                        
                        self.batchData{i, 5} = '已完成';
                        
                    catch ME
                        self.batchData{i, 5} = '分析失败';
                        disp(['Error processing ' vidFile ': ' ME.message]);
                        
                        % 错误报告逻辑 (保持不变)
                        errorRowData = cell(1, numel(internalColNames));
                        errorRowData(1:colNamesFixedCount) = combinedRowDataFixed; 
                        
                        try 
                             if ~isempty(P_Global)
                                 if ~isempty(Stations) && numel(Stations) >= 1 && ~isempty(Stations(1).Name)
                                     colNamesSummary = [matlab.lang.makeValidName(Stations(1).Name) '_TotalTime_s'];
                                     errorIdx = find(strcmp(internalColNames, colNamesSummary), 1);
                                 else
                                     errorIdx = [];
                                 end
                                 
                                 if isempty(errorIdx)
                                    errorRowData{1} = [baseName ' (ERROR: ' ME.message ')'];
                                 else
                                    errorRowData{errorIdx} = ME.message;
                                 end
                             else
                                 errorRowData{1} = [baseName ' (ERROR: ' ME.message ')'];
                             end
                        catch
                             errorRowData{1} = [baseName ' (ERROR: ' ME.message ')'];
                        end
                        
                        if numel(errorRowData) < numel(internalColNames)
                             errorRowData{numel(internalColNames)} = []; 
                        end
                        
                        errorRowTbl = cell2table(errorRowData, 'VariableNames', internalColNames);
                        if isempty(combinedTbl)
                           combinedTbl = errorRowTbl;
                        else
                           combinedTbl = [combinedTbl; errorRowTbl];
                        end
                    end
                    
                    if isvalid(vReader), delete(vReader); end
                    updateTableDisplay(); 
                    drawnow;
                    
                end % 视频循环结束
                
                % Final Update
                % [修改] 移除 gaugeBatchProgress
                % self.gaugeBatchProgress.Value = 100;
                self.txtBatchETR.Text = '批量分析完成';
                self.txtBatchStatus.Text = '正在保存结果...';
                drawnow;

                
                % --- ETR 逻辑 (更新回调) ---
                function updateProgress(p, msg)
                    
                    % 1. 计算总进度 (0-1)
                    CurrentVideoProgress = p;
                    VideosProcessed = (currentVideoCount - 1) + CurrentVideoProgress;
                    totalProgress = VideosProcessed / totalVideos;
                    
                    % 2. 计算 ETR
                    TimeElapsed = toc(batchStartTime);
                    displayETR = '计算中...';
                    
                    % 仅在处理了少量工作后才开始计算 (避免早期波动)
                    if VideosProcessed > 0.001
                        AvgTimePerVideo = TimeElapsed / VideosProcessed;
                        VideosRemaining = totalVideos - VideosProcessed;
                        ETR_seconds = VideosRemaining * AvgTimePerVideo;
                        
                        if ~isnan(ETR_seconds) && ~isinf(ETR_seconds) && ETR_seconds > 0
                             displayETR = formatTimeS(ETR_seconds);
                        else
                             displayETR = '很快完成...';
                        end
                    end
                    
                    % 3. [修改] 更新 ETR 文本 (中间)
                    self.txtBatchETR.Text = ['预计剩余: ' displayETR];
                    
                    % 4. [修改] 更新详细状态文本 (右侧)
                    self.txtBatchStatus.Text = sprintf('(%d/%d) %.1f%% (%s)', ...
                        currentVideoCount, totalVideos, ...
                        totalProgress*100, msg);
                    
                    drawnow limitrate;
                end
                
                % 8. 最终保存和清理 (保持不变)
                if ~isvalid(self.fBatch), return; end
                
                if ~isempty(combinedTbl)
                    
                    saveDir = self.edtSaveDir.Value; 
                    finalFileName = self.edtFileName.Value; 
                    finalFile = fullfile(saveDir, finalFileName);
                    [finalDir, ~, ~] = fileparts(finalFile);
                    if ~exist(finalDir, 'dir'), mkdir(finalDir); end
                    
                    % 1. 准备表头
                    headerRow1Data = cell(1, numel(exportHeader1));
                    [uniqueGroups, ~, groupIndex] = unique(exportHeader1, 'stable');
                    for g = 1:numel(uniqueGroups)
                        groupName = uniqueGroups{g};
                        groupStartCol = find(groupIndex == g, 1, 'first');
                        headerRow1Data{groupStartCol} = groupName;
                    end
                    headerMatrix = [headerRow1Data; exportHeader2];
                    
                    % 3. 数据转换
                    dataCell = table2cell(combinedTbl); 
                    
                    % 4. 数值转字符串
                    dataNumericMask = cellfun(@isnumeric, dataCell); 
                    dataCell(dataNumericMask) = cellfun(@(x) num2str(x), dataCell(dataNumericMask), 'UniformOutput', false);
                    exportData = [headerMatrix; dataCell];
                    
                    try
                        % 尝试使用 xlswrite 写入 XLSX 
                        xlswrite(finalFile, exportData, 'Sheet1', 'A1');
                        if isvalid(self.txtStatus)
                            self.txtStatus.Text = ['批量分析完成。合并结果保存于: ' finalFile];
                        end
                        
                    catch ME
                        % --- 鲁棒性 fallback 逻辑：写入 CSV ---
                        fallbackFile = strrep(finalFile, '.xlsx', '_FALLBACK.csv');
                        emptyCells = cellfun(@isempty, headerRow1Data);
                        headerRow1Data(emptyCells) = {''}; 
                        headerRow1 = strjoin(headerRow1Data, ','); 
                        headerRow2 = strjoin(exportHeader2, ','); 
                        
                        fid = fopen(fallbackFile, 'w');
                        if fid == -1
                            if isvalid(self.fig), uialert(self.fig, sprintf('无法写入文件: %s。请检查目录权限。', fallbackFile), '写入错误'); end
                            if isvalid(self.txtStatus), self.txtStatus.Text = '批量分析完成，但结果写入失败。'; end
                            return;
                        end
                        fprintf(fid, '%s\n', headerRow1);
                        fprintf(fid, '%s\n', headerRow2);
                        for r = 1:size(dataCell, 1)
                            rowStr = strjoin(dataCell(r, :), ',');
                            fprintf(fid, '%s\n', rowStr);
                        end
                        fclose(fid);
                        
                        if isvalid(self.fig)
                            uialert(self.fig, sprintf('警告：无法写入 XLSX 文件。结果已导出为 CSV 文件，位于：\n%s', fallbackFile), '导出警告：Excel 格式失败');
                        end
                        if isvalid(self.txtStatus)
                            self.txtStatus.Text = ['批量分析完成。结果已作为 CSV 导出: ' fallbackFile];
                        end
                        
                    end
                    
                else
                    if isvalid(self.txtStatus), self.txtStatus.Text = '批量分析完成，但没有生成有效的结果表格。'; end
                end
                
                % 弹出完成提示
                if isvalid(self.fBatch)
                    uialert(self.fBatch, '批量分析已尝试完成。', '完成');
                end
            end % onStartAnalysis 结束
        end % onBatchGUI 结束
    end
    
    methods (Static)
            
            % (替换)
            function params = getDefaultLocalParams()
                params.threshold = 50;
                params.minBlobArea = 50;
                params.morphRadius = 3;
                params.stationarySpeedThreshold_cm_s = 0.5;
                params.stationaryMinDuration_s = 0.5;
            end
            
            % (替换)
            function params = getDefaultGlobalParams()
                params.scalePx2Cm = 0;
                params.minDwellTime_s = 0.5;
                params.analyzeEveryN = 1;
                params.startTime = 0;
                params.endTime = NaN; % 内部用 NaN 表示末尾
                params.startF = 1;
                params.endF = 2;
            end
            
            % 鲁棒性辅助函数：合并当前参数和默认参数，填补缺失字段
            function current = mergeParams(current, defaultParams)
                if isempty(current)
                    current = defaultParams;
                    return;
                end
                
                defaultFields = fieldnames(defaultParams);
                for i = 1:numel(defaultFields)
                    field = defaultFields{i};
                    if ~isfield(current, field)
                        current.(field) = defaultParams.(field);
                    end
                end
            end

        function mask = makeMask(gray, bg_cropped, L) 
            % L 是局部参数结构体 (LocalParams)
            
            % 确保 gray 和 bg_cropped 尺寸匹配
            if isempty(bg_cropped) || any(size(gray) ~= size(bg_cropped))
                mask = false(size(gray));
                return;
            end

            diff_frame = abs(int16(gray) - int16(bg_cropped));
            
            % 1. 阈值分割
            mask = diff_frame > L.threshold;
            
            % 2. 形态学操作
            if L.morphRadius > 0
                se = strel('disk', L.morphRadius);
                mask = imopen(mask, se);
            end
            
            % 3. 面积过滤
            if L.minBlobArea > 0
                mask = bwareaopen(mask, L.minBlobArea);
            end
        end     
             
                
        function fr = readFrameAt_v(vr, idx)
            fps = max(1e-6, vr.FrameRate);
            nF = max(1, floor(vr.Duration*fps));
            idx = round(min(max(idx,1), nF));
            safeTime = min((idx-1)/fps, max(0, vr.Duration - 0.75/fps));
            vr.CurrentTime = safeTime;
            try
                fr = readFrame(vr);
            catch
                vr.CurrentTime = max(0, safeTime - 1/fps);
                fr = readFrame(vr);
            end
            if size(fr,3)==1, fr = repmat(fr,[1 1 3]); end
        end
        
        % (替换)
        function [Results, Trajectories] = runAnalysisCore(vReader, bgFrame, GlobalParams, Stations, startF, endF, dt_step, nFramesTotal, fps, hFig, progressCallback)
            
            P_Global = GlobalParams; 
            numStations = numel(Stations);
            
            % 1. 预分配结果存储
            Trajectories = cell(numStations, 1); 
            
            TempData = struct(); 
            for i = 1:numStations
                MaxFrames = floor((endF - startF) / P_Global.analyzeEveryN) + 1; 
                TempData(i).pos = NaN(MaxFrames, 2); 
                TempData(i).inside = false(MaxFrames, numel(Stations(i).Areas)); 
                TempData(i).idx = 0; 
            end
            
            % 2. 逐帧处理循环
            vr = vReader;
            currentFrameIdx = startF;
            
            waitbarHandle = []; 
            if ~isempty(hFig) && ishandle(hFig)
                % (要求 1 修正) 将 WindowStyle 从 'modal' 改为 'normal' 
                % 这样可以允许用户最小化主 MATLAB 界面并移动进度条窗口
                waitbarHandle = waitbar(0, '正在初始化...', 'Name', '多目标分析进度', 'WindowStyle', 'normal'); 
                if isprop(waitbarHandle, 'UserData')
                   setappdata(waitbarHandle, 'canceling', false);
                   uicontrol('Parent', waitbarHandle, 'String', '取消', ...
                       'Position', [waitbarHandle.Position(3)/2-30, 5, 60, 20], ...
                       'Callback', @(s,e) setappdata(waitbarHandle, 'canceling', true));
                end
            end

            while currentFrameIdx <= endF
                
                if ~isempty(waitbarHandle) && isvalid(waitbarHandle) && getappdata(waitbarHandle,'canceling')
                    break;
                end
                
                % 2a. 读取原始帧
                try
                    vr.CurrentTime = (currentFrameIdx - 1) / fps; 
                    fr_raw = readFrame(vr);
                catch
                    disp(['Warning: 无法读取帧 ' num2str(currentFrameIdx) '. 跳过。']);
                    currentFrameIdx = currentFrameIdx + P_Global.analyzeEveryN;
                    continue;
                end
                
                % 2b. 站点内循环
                for i = 1:numStations
                    S = Stations(i);
                    L = S.LocalParams;
                    
                    % (恢复) 移除了站点独立时间检查
                    
                    % i. 裁剪
                    if isempty(S.CropRect)
                        fr_cropped = fr_raw;
                        bg_cropped = bgFrame;
                        x_offset = 0;
                        y_offset = 0;
                    else
                        rect = S.CropRect;
                        fr_cropped = XuX_Analyzer.safeCropStatic(fr_raw, rect);
                        bg_cropped = XuX_Analyzer.safeCropStatic(bgFrame, rect);
                        x_offset = rect(1) - 1; 
                        y_offset = rect(2) - 1; 
                    end
                    
                    % ii. 分析
                    gray_cropped = im2gray(fr_cropped);
                    mask = XuX_Analyzer.makeMask(gray_cropped, bg_cropped, L); 

                    cc = bwconncomp(mask);
                    centroid_global = [NaN, NaN]; 
                    
                    if cc.NumObjects > 0
                        Sprops = regionprops(cc, 'Area', 'Centroid');
                        [~, ii] = max([Sprops.Area]);
                        centroid_local = Sprops(ii).Centroid;
                        
                        centroid_global = [centroid_local(1) + x_offset, ...
                                           centroid_local(2) + y_offset];
                    end
                    
                    % --- (要求 2 修复) 区域判定 (使用全局坐标) ---
                    inside_mask = false(1, numel(S.Areas));
                    if ~isnan(centroid_global(1))
                        for k = 1:numel(S.Areas)
                            if isfield(S.Areas(k), 'vertices') && ~isempty(S.Areas(k).vertices)
                                % 使用 inpolygon 判断全局坐标是否在全局顶点内
                                inside_mask(k) = inpolygon(centroid_global(1), centroid_global(2), ...
                                    S.Areas(k).vertices(:,1), S.Areas(k).vertices(:,2));
                            end
                        end
                    end
                    % --- (修复结束) ---
                    
                    % v. 存储结果
                    TempData(i).idx = TempData(i).idx + 1;
                    frame_idx = TempData(i).idx;
                    
                    TempData(i).pos(frame_idx, :) = centroid_global;
                    TempData(i).inside(frame_idx, :) = inside_mask;
                end % 站点循环结束
                
                % --- [功能 4 修复：进度回调] ---
                progress = 0; msg = '...';
                if (endF - startF) > 0
                    progress = (currentFrameIdx - startF) / (endF - startF);
                end

                if ~isempty(waitbarHandle) && isvalid(waitbarHandle)
                    msg = sprintf('帧 %d/%d (%.1f%%) - 站点分析中...', ...
                        currentFrameIdx, endF, progress * 100);
                    waitbar(progress, waitbarHandle, msg);
                else
                    msg = sprintf('帧 %d/%d (%.1f%%)', currentFrameIdx, endF, progress * 100);
                end
                
                % [FIX] Call external progress callback if provided
                if nargin > 10 && ~isempty(progressCallback)
                    progressCallback(progress, msg);
                end
                % --- [修复结束] ---
                
                currentFrameIdx = currentFrameIdx + P_Global.analyzeEveryN;
            end % 逐帧循环结束
            
            if ~isempty(waitbarHandle) && isvalid(waitbarHandle), close(waitbarHandle); end
            
            % 3. 结果后处理 (循环 Stations)
            Results = cell(numStations, 1);
            
            for i = 1:numStations
                S = Stations(i);
                P = P_Global; 
                L = S.LocalParams; % (恢复) 局部参数 L
                
                pos = TempData(i).pos(1:TempData(i).idx, :);
                inside = TempData(i).inside(1:TempData(i).idx, :);
                
                % 3a. 计算距离、速度等
                is_valid = ~any(isnan(pos), 2);
                
                % [CRITICAL FIX V2] 确保 'dist' 数组尺寸匹配 'pos' 行数，以避免索引错误
                num_rows = size(pos, 1);
                
                if num_rows == 0
                    dist = zeros(0, 1); % 0x1 数组 (空)
                elseif num_rows == 1
                    dist = 0; % 1x1 数组 (单帧时距离为 0)
                else
                    % 对于 2 行或更多，计算距离
                    dist = [0; sqrt(sum(diff(pos, 1, 1).^2, 2))];
                end
                
                % 确保 'dist' 是列向量，以匹配其他表格列
                dist = dist(:); 
                
                % 应用 NaN 掩码
                dist(~is_valid) = NaN;
                dist_m = dist * P.scalePx2Cm / 100; 
                
                f_idx = (startF:P.analyzeEveryN:endF)';
                f_idx = f_idx(1:TempData(i).idx); 
                tvec = (f_idx - 1) / fps;
                
                speeds_m_s = dist_m / dt_step;
                
                % (恢复) 静止判定 (使用局部参数 L)
                isSlow = speeds_m_s < L.stationarySpeedThreshold_cm_s / 100; 
                
                % 3b. 转换为逐帧表格
                resTbl = table(f_idx, tvec, pos(:,1), pos(:,2), dist, dist_m, speeds_m_s, isSlow, ...
                    'VariableNames',{'Frame','Time_s','X','Y','Distance_px','Distance_m','Speed_m_s','IsStationary'});
                
                Trajectories{i} = pos(is_valid,:); 
                
                % 3c. 计算区域统计 (perArea)
                areaNames = arrayfun(@(a)a.name, S.Areas, 'UniformOutput', false);
                Time_s = zeros(numel(S.Areas),1);
                Entries = zeros(numel(S.Areas),1);
                Distance_m = zeros(numel(S.Areas),1);
                
                minDwellSteps = max(1, ceil(P.minDwellTime_s / dt_step)); 
                
                for k=1:numel(S.Areas)
                    in = inside(:,k);
                    Time_s(k) = XuX_Analyzer.nanSum(in) * dt_step; 
                    
                    trans = find(diff([false; in])==1); 
                    cnt = 0;
                    for ti = trans'
                        idxStay = ti:min(ti+minDwellSteps-1, numel(in));
                        if all(in(idxStay)), cnt = cnt + 1; end
                    end
                    Entries(k) = cnt;
                    Distance_m(k) = XuX_Analyzer.nanSum(dist_m(in));
                end
                
                perAreaTbl = table(string(areaNames'), Time_s, Entries, Distance_m, ...
                    'VariableNames', {'AreaName','Time_s','Entries','Distance_m'});
                
                % 3d. 计算摘要统计 (summary)
                
                % (恢复) 摘要统计使用全局时间
                valid_mask = (f_idx >= P.startF & f_idx <= P.endF);
                
                totalTime = sum(valid_mask) * dt_step;
                totalDist_m = XuX_Analyzer.nanSum(dist_m(valid_mask));
                averageSpeed_m_s = totalDist_m / totalTime;
                
                % (恢复) 静止判定 (使用局部参数 L)
                minStatSteps = max(1, ceil(L.stationaryMinDuration_s / dt_step));
                isStationaryDuration = false(size(isSlow));
                
                isSlow_valid = isSlow(valid_mask);
                
                current_run_length = 0;
                start_idx_run = 0;
                
                for j = 1:numel(isSlow_valid)
                    if isSlow_valid(j)
                        if current_run_length == 0
                            start_idx_run = j; 
                        end
                        current_run_length = current_run_length + 1;
                    else
                        if current_run_length >= minStatSteps
                            isStationaryDuration(start_idx_run:j-1) = true;
                        end
                        current_run_length = 0;
                    end
                end
                if current_run_length >= minStatSteps
                    isStationaryDuration(start_idx_run:end) = true;
                end
                
                stationaryTime_s = XuX_Analyzer.nanSum(isStationaryDuration) * dt_step;

                summaryTbl = table(totalTime, totalDist_m, averageSpeed_m_s, stationaryTime_s, ...
                    'VariableNames', {'TotalTime_s','TotalDistance_m','AverageSpeed_m_s','StationaryTime_s'});
                
                % 3e. 存储最终结果
                Results{i}.perFrameTbl = resTbl;
                Results{i}.perAreaTbl = perAreaTbl;
                Results{i}.summaryTbl = summaryTbl;

            end % 结果后处理循环结束
        end
        
        % (新增) 静态版本的 calculateFrameRange (用于批量分析)
        function [startF, endF, s_out, e_out_nan] = calculateFrameRangeStatic(s_in, e_in, fps, nFrames, analyzeEveryN, vidDuration)
            
            s_out = max(0, s_in);
            
            if e_in <= 0 || isnan(e_in)
                e_out_nan = NaN;
                e_sec = vidDuration;
            else
                e_out_nan = min(e_in, vidDuration);
                e_sec = e_out_nan;
            end
            
            if s_out >= e_sec
                s_out = max(0, e_sec - 1); 
            end
            
            startF = max(1, floor(s_out * fps / analyzeEveryN) * analyzeEveryN + 1);
            endF = max(startF + 1, min(nFrames, floor(e_sec * fps / analyzeEveryN) * analyzeEveryN + 1));
        end

        function img = renderTrajectory(bgRGB, pos, areas)
            if size(bgRGB,3)==1, bgRGB = repmat(bgRGB,[1 1 3]); end
            bgRGB = im2uint8(mat2gray(bgRGB));

            fh = figure('Visible','off','Color','w');
            try
                ax = axes('Parent',fh);
                imshow(bgRGB,'Parent',ax); hold(ax,'on');

                P = pos(~any(isnan(pos),2),:);
                if size(P,1)>=2
                    plot(ax, P(:,1), P(:,2), '-', 'LineWidth', 2);
                    plot(ax, P(1,1),  P(1,2),  'go', 'MarkerFaceColor','g','MarkerSize',5);
                    plot(ax, P(end,1),P(end,2),'ro', 'MarkerFaceColor','r','MarkerSize',5);
                end

                for k=1:numel(areas)
                    B = bwboundaries(areas(k).mask);
                    if ~isempty(B)
                        plot(ax, B{1}(:,2), B{1}(:,1), 'Color', areas(k).color, 'LineWidth', 2);
                    end
                end

                ax.Visible = 'off';
                drawnow;
                fr = getframe(ax);
                img = im2uint8(frame2im(fr));
            catch
                img = bgRGB;
            end
            if ishghandle(fh), close(fh); end
        end
        
        
        function img = renderHeatmap(pos, sz, edgesX, edgesY)
            % 输入：
            %   pos: N×2 的坐标（X,Y），可含 NaN
            %   sz: [height, width]
            % 可选 edgesX, edgesY：bin 边界（向量）。若缺失将自动生成合理默认值。
        
            % 1) 参数保护与默认生成
            if nargin < 2 || isempty(sz) || numel(sz) < 2
                error('renderHeatmap:InvalidSize', '第二个参数 sz 必须为 [height, width]。');
            end
            h = max(1, round(sz(1)));
            w = max(1, round(sz(2)));
        
            if nargin < 3 || isempty(edgesX)
                edgesX = linspace(1, w, max(2, min(200, w)));
            end
            if nargin < 4 || isempty(edgesY)
                edgesY = linspace(1, h, max(2, min(200, h)));
            end
        
            % 确保边界长度 >= 2
            if numel(edgesX) < 2
                edgesX = [1, max(2,w)];
            end
            if numel(edgesY) < 2
                edgesY = [1, max(2,h)];
            end
        
            % 2) 数据检查
            if isempty(pos) || all(isnan(pos(:)))
                img = uint8(zeros(h, w, 3));
                return;
            end
            pos = pos(~any(isnan(pos),2), :);
            if isempty(pos)
                img = uint8(zeros(h, w, 3));
                return;
            end
        
            % Clip positions to image bounds (避免 histcounts2 出错)
            pos(:,1) = min(max(pos(:,1), 1), w);
            pos(:,2) = min(max(pos(:,2), 1), h);
        
            % 3) 计算热图（安全包装 histcounts2）
            try
                % histcounts2 的输入格式： (Y, X, yedges, xedges)
                H = histcounts2(pos(:,2), pos(:,1), edgesY, edgesX, 'Normalization', 'probability');
            catch ME
                % 如果失败，降级为使用 griddata / accumulation（更慢但稳健）
                try
                    % 使用简单的像素计数累加作为后备
                    Htmp = zeros(numel(edgesY)-1, numel(edgesX)-1);
                    % 将点映射到 bin 索引
                    [~, binX] = histc(pos(:,1), edgesX);
                    [~, binY] = histc(pos(:,2), edgesY);
                    valid = binX >= 1 & binX <= size(Htmp,2) & binY >=1 & binY <= size(Htmp,1);
                    idx = sub2ind(size(Htmp), binY(valid), binX(valid));
                    cnts = accumarray(idx, 1, [numel(Htmp) 1]);
                    Htmp(:) = cnts;
                    H = Htmp / max(sum(Htmp(:)),1);
                catch ME2
                    warning('renderHeatmap:FallbackFailed', 'histcounts2 failed and fallback also failed: %s; returning blank heatmap.', ME2.message);
                    img = uint8(zeros(h, w, 3));
                    return;
                end
            end
        
            % 4) 平滑与归一化
            if ~isempty(H) && any(H(:) > 0)
                Hs = imgaussfilt(H, 2);
                Hs = Hs / max(Hs(:));
            else
                Hs = zeros(size(H));
            end
        
            % 5) 缩放到图像尺寸并映射颜色
            try
                H_resized = imresize(Hs, [h, w], 'bilinear');
            catch
                H_resized = repmat(Hs(1,:), [h,1]); % 极端降级
            end
        
            cmap = hot(256);
            % 防护：避免 gray2ind 出错（需要 [0,1] 范围）
            H_resized = min(max(H_resized, 0), 1);
            idxMap = gray2ind(H_resized, 255);
            imgRGB = ind2rgb(idxMap, cmap);
            img = im2uint8(imgRGB);
        end

        function imgOut = safeCropStatic(imgIn, rect)
            if isempty(rect) || numel(rect)~=4
                imgOut = imgIn; return;
            end
            H = size(imgIn,1); W = size(imgIn,2);
            x = max(1, round(rect(1))); 
            y = max(1, round(rect(2)));
            w = round(rect(3)); 
            h = round(rect(4));
            if w<=0 || h<=0
                imgOut = imgIn; return;
            end
            w = min(w, W - x + 1);
            h = min(h, H - y + 1);
            if w<=1 || h<=1
                imgOut = imgIn; return;
            end
            imgOut = imcrop(imgIn, [x y w h]);
            if isempty(imgOut) || any(size(imgOut,1:2)<=1)
                imgOut = imgIn;
            end
        end

        function rectOut = clampRectStatic(rect, imgSize)
            if isempty(rect) || numel(rect)~=4
                rectOut = []; return;
            end
            H = imgSize(1); W = imgSize(2);
            x = max(1, round(rect(1))); 
            y = max(1, round(rect(2)));
            w = round(rect(3)); 
            h = round(rect(4));
            if w<=0 || h<=0
                rectOut = []; return;
            end
            w = min(w, W - x + 1);
            h = min(h, H - y + 1);
            if w<=1 || h<=1
                rectOut = []; return;
            end
            rectOut = [x y w h];
        end

        function s = nanSum(x)
            if isempty(x), s = 0; return; end
            x = x(~isnan(x));
            if isempty(x), s = 0; else, s = sum(x(:)); end
        end
        
        function stCount = countStationaryEvents(isStationaryBool, fps, minDurationSec)
            if isempty(isStationaryBool)
                stCount = 0; return;
            end
            bs = isStationaryBool;
            d = [0; diff(bs)];
            starts = find(d==1);
            ends = find(d==-1)-1;
            if ~isempty(bs) && bs(1), starts = [1; starts]; end
            if ~isempty(bs) && bs(end), ends = [ends; length(bs)]; end
            stCount = 0;
            minDurFrames = max(1, round(minDurationSec * fps));
            for jj = 1:length(starts)
                len = ends(jj) - starts(jj) + 1;
                if len >= minDurFrames
                    stCount = stCount + 1;
                end
            end
        end

        function out = calibrateScaleInteractive(frameRGB)
            out = [];
            fh = figure('Name','标尺校准：点击两点（双击结束），Esc 取消','NumberTitle','off');
            imshow(frameRGB); hold on;
            title('请点击两点以标定（双击第二点结束），按 Esc 取消');
            try
                [x,y] = ginput(2);
            catch
                close(fh); return;
            end
            if numel(x) < 2
                close(fh); return;
            end
            plot(x,y,'r-o','LineWidth',2);
            pixelDist = hypot(diff(x), diff(y));
            prompt = {'两点之间的实际距离（单位 cm）:'};
            dlgtitle = '输入实际距离 (cm)';
            dims = [1 35];
            definput = {'10'};
            answer = inputdlg(prompt,dlgtitle,dims,definput);
            if isempty(answer)
                close(fh); return;
            end
            realDist = str2double(answer{1});
            if isnan(realDist) || realDist<=0
                close(fh); return;
            end
            pxPerUnit = pixelDist / realDist; 
            out.pxPerUnit = pxPerUnit;
            out.unit = 'cm';
            out.realDist = realDist;
            out.pts = [x(:) y(:)];
            close(fh);
        end
        %% =================================================================
        %                   优化：矢量图导出 (Vector Export)
        %  =================================================================
        
        function saveTrajectoryVector(pos, frameSize, filePath)
            % 满足用户需求：
            % 1. 仅导出轨迹
            % 2. 导出为 .svg 矢量图
            % 3. 无背景、无区域框
            
            % 创建一个不可见的、背景透明的图形
            fh = figure('Visible', 'off', 'Color', 'none');
            ax = axes('Parent', fh);
            try
                % 筛选有效的坐标点
                P = pos(~any(isnan(pos),2),:);
                if size(P,1) >= 2
                    % 绘制轨迹线 (k- = 黑色实线)
                    plot(ax, P(:,1), P(:,2), 'k-', 'LineWidth', 0.5); 
                end
                
                % 保持与视频/图像相同的坐标系 (Y轴反转)
                set(ax, 'YDir', 'reverse');
                % 设置坐标轴范围严格匹配图像尺寸
                xlim(ax, [0.5, frameSize(2)+0.5]);
                ylim(ax, [0.5, frameSize(1)+0.5]);

                % 核心：移除所有坐标轴装饰（背景、边框、刻度）
                axis(ax, 'off');
                box(ax, 'off');
                set(ax, 'Color', 'none'); % 坐标轴背景透明

                % 设置图形和坐标轴单位为像素，确保 1:1 映射
                set(fh, 'Units', 'pixels', 'Position', [0 0 frameSize(2) frameSize(1)]);
                set(ax, 'Units', 'pixels', 'Position', [0 0 frameSize(2) frameSize(1)]);
                
                % 导出为 SVG
                % SVG (Scalable Vector Graphics) 是标准的矢量格式
                saveas(fh, filePath, 'svg');
                
            catch ME
                fprintf('保存轨迹矢量图 (SVG) 失败: %s\n', ME.message);
            end
            if ishghandle(fh), close(fh); end
        end

        function saveHeatmapVector(pos, frameSize, filePath)
            % 满足用户需求：
            % 1. 导出热图
            % 2. 导出为 .fig 矢量图，以便在 MATLAB 中编辑
            
            % 创建一个不可见的图形
            fh = figure('Visible', 'off');
            ax = axes('Parent', fh);
            try
                pos = pos(~any(isnan(pos),2),:);
                if isempty(pos)
                    if ishghandle(fh), close(fh); end
                    return; 
                end
                
                % --- 使用与 renderHeatmap 相同的热图计算逻辑 ---
                edgesX = 1:8:frameSize(2);
                edgesY = 1:8:frameSize(1);
                
                H = histcounts2(pos(:,2), pos(:,1), edgesY, edgesX, 'Normalization', 'probability'); 
                H = imgaussfilt(H, 1);
                H = H / max(H(:)+eps);
                
                % 调整大小以匹配 .png 输出 (使其平滑)
                H_resized = imresize(H, [frameSize(1) frameSize(2)], 'nearest');
                % --- 逻辑结束 ---
                
                % 使用 imagesc 绘制热图数据
                % (这是 .fig 可编辑的关键)
                imagesc(ax, H_resized);
                
                colormap(ax, 'jet'); % 设置默认 colormap
                colorbar(ax);        % 添加色阶条
                title(ax, 'Heatmap (Probability)');
                
                % 保持与视频/图像相同的坐标系
                set(ax, 'YDir', 'reverse');
                axis(ax, 'equal');
                axis(ax, 'tight');
                xlim(ax, [0.5, frameSize(2)+0.5]);
                ylim(ax, [0.5, frameSize(1)+0.5]);
                
                % 导出为 .fig 文件
                % 用户后续可以 loadfig() 或直接双击打开
                savefig(fh, filePath);
                
            catch ME
                fprintf('保存热图 .fig 失败: %s\n', ME.message);
            end
            if ishghandle(fh), close(fh); end
        end
    end
end