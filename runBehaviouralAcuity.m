function runBehaviouralAcuity(ana)

global rM
if ~exist('rM','var') || isempty(rM)
	rM = arduinoManager();
end
if ~rM.isOpen; open(rM); end %open our reward manager


%===============compatibility for windows===================
%if ispc; PsychJavaTrouble(); end
KbName('UnifyKeyNames');

%===================Initiate out metadata===================
ana.date		= datestr(datetime);
ana.version		= Screen('Version');
ana.computer	= Screen('Computer');
ana.gpu			= opengl('data');
thisVerbose		= false;

%===================experiment parameters===================
ana.screenID	= max(Screen('Screens'));%-1;

%==========================================================================
%==================================================Make a name for this run
cd(ana.ResultDir)
ana.timeExp		= fix(clock());
if ~isempty(ana.subject)
	if ana.useStaircase; type = 'BASTAIR'; else type = 'BAMOC'; end %#ok<*UNRCH>
	nameExp = [type '_' ana.subject];
	c = sprintf(' %i',ana.timeExp);
	nameExp = [nameExp c];
	ana.nameExp = regexprep(nameExp,' ','_');
else
	ana.nameExp = 'debug';
end
cla(ana.plotAxis1);
cla(ana.plotAxis2);
cla(ana.plotAxis3);
cla(ana.plotAxis4);

nBlocks = ana.nBlocks;
nBlocksOverall = nBlocks * length(ana.contrastRange);

%==========================================================================
%===========================================================response values
NOSEE = 1; 	YESSEE = 2; UNSURE = 4; BREAKINIT = -100; BREAKBLANK = -10; BREAKFIX = -1;
UNDEFINED = 0;
saveMetaData();

%==========================================================================
%======================================================stimulus objects
% ---- blank disc.
blank = discStimulus();
blank.name = ['DISC' ana.nameExp];
blank.colour = [0.5 0.5 0.5];
blank.size = ana.discSize;
blank.sigma = ana.sigma;
% ---- target stimulus
target = discStimulus();
target.name = ['DISC' ana.nameExp];
target.colour = [0.5 0.5 0.5];
target.size = 1.5;
target.sigma = 5;
% ---- grat stimulus
grat = gratingStimulus();
grat.mask = true;
grat.useAlpha = true;
grat.name = ['GRAT' ana.nameExp];
grat.size = blank.size;
grat.sigma = ana.sigma;
% ---- fixation cross
fixX = fixationCrossStimulus();
fixX.colour = [1 1 1];
fixX.colour2 = [0 0 0];
fixX.size = ana.spotSize;
fixX.alpha = ana.spotAlpha;
fixX.alpha2 = ana.spotAlpha;
fixX.lineWidth = ana.spotLine;
%----------combine them into a single meta stimulus
stimuli = metaStimulus();
stimuli.name = ana.nameExp;
stimuli{1} = blank;
stimuli{2} = target;
stimuli{3} = grat;
stimuli{4} = fixX;

%==========================================================================
%======================================================open the PTB screens
PsychDefaultSetup(2);
Screen('Preference', 'VisualDebugLevel', 3);
Screen('Preference', 'SkipSyncTests', 0);
Screen('Preference', 'DefaultFontSize',30);
sM						= screenManager();
sM.screen				= ana.screenID;
sM.windowed				= ana.windowed;
sM.pixelsPerCm			= ana.pixelsPerCm;
sM.distance				= ana.distance;
sM.debug				= ana.debug;
sM.blend				= true;
sM.bitDepth				= 'FloatingPoint32Bit';
if exist(ana.gammaTable, 'file')
	load(ana.gammaTable);
	if isa(c,'calibrateLuminance')
		sM.gammaTable = c;
	end
	clear c;
	if ana.debug
		sM.gammaTable.plot
	end
end
sM.backgroundColour		= ana.backgroundColor;
screenVals				= sM.open; % OPEN THE SCREEN
fprintf('\n--->>> Behavioural Acuity Opened Screen %i : %s\n', sM.win, sM.fullName);
setup(stimuli,sM); %setup our stimulus object

PsychPortAudio('Close');
sM.audio = audioManager(); sM.audio.close();
if IsLinux
	sM.audio.device		= [];
elseif IsWin
	sM.audio.device		= [];
end
sM.audio.setup();
	
%===========================tobii manager=====================
eT						= tobiiManager();
eT.name					= ana.nameExp;
eT.model				= ana.tracker;
eT.trackingMode			= ana.trackingMode;
eT.eyeUsed				= ana.eyeUsed;
eT.sampleRate			= ana.sampleRate;
eT.calibrationStimulus	= ana.calStim;
eT.manualCalibration	= ana.calManual;
eT.calPositions			= ana.calPos;
eT.valPositions			= ana.valPos;
eT.autoPace				= ana.autoPace;
eT.paceDuration			= ana.paceDuration;
eT.smoothing.nSamples	= ana.nSamples;
eT.smoothing.method		= ana.smoothMethod;
eT.smoothing.window		= ana.w;
eT.smoothing.eyes		= ana.smoothEye;
if ~ana.isDummy; eT.verbose	= true; end
if ~ana.useTracker || ana.isDummy
	eT.isDummy			= true;
end
if length(Screen('Screens')) > 1 && sM.screen - 1 >= 0 && ana.useTracker% ---- second screen for calibration
	s					= screenManager;
	s.verbose			= thisVerbose;
	s.screen			= sM.screen - 1;
	s.backgroundColour	= sM.backgroundColour;
	s.distance			= sM.distance;
	[w,h]				= Screen('WindowSize',s.screen);
	s.windowed			= [0 0 round(w/1.5) round(h/1.5)];
	s.bitDepth			= '';
	s.blend				= sM.blend;
	s.bitDepth			= '8bit';
	s.blend				= true;
	s.pixelsPerCm		= 30;
end
if exist('s','var')
	initialise(eT,sM,s);
else
	initialise(eT,sM);
end

eT.settings.cal.doRandomPointOrder  = false;
ana.cal=[];
if isempty(ana.calFile) || ~exist(ana.calFile,'file')
	name = regexprep(ana.subject,' ','_');
	ana.calFile = [eT.paths.savedData filesep 'TobiiCal-' name '.mat'];
end
if ana.reloadPreviousCal && exist(ana.calFile,'file')
	load(ana.calFile);
	if isfield(cal,'attempt') && ~isempty(cal.attempt); ana.cal = cal; end
end
cal = trackerSetup(eT, ana.cal); ShowCursor();
if ~isempty(cal) && isfield(cal,'attempt')
	cal.comment=sprintf('Subject:%s | Comments: %s | tobii calibration',ana.subject,ana.comments);
	cal.computer = ana.computer;
	cal.date = ana.date;
	assignin('base','cal',cal); %put our calibration ready to save manually
	save(ana.calFile,'cal');
	ana.outcal = cal;
end

% ---- initial fixation values.
eT.updateFixationValues(ana.XFix,ana.YFix,ana.initTime,ana.fixTime,ana.radius,ana.strict);
resetFixation(eT);

%---------------------------Set up task variables----------------------

if ana.useStaircase == false
	task = stimulusSequence();
	task.name = ana.nameExp;
	task.nBlocks = nBlocks;
	task.nVar(1).name = 'contrast';
	task.nVar(1).stimulus = 3;
	task.nVar(1).values = ana.contrastRange;
	randomiseStimuli(task);
	initialiseTask(task);
else
	task.thisRun = 0;
	stopRule = 40;
	usePriors = ana.usePriors;
	grain = 100;
	setupStairCase();
end

%=========================================TASK TYPE
switch ana.myFunc
	case 'Blank Stage 1'
		taskType = 1;
	case 'Blank Stage 2'
		taskType = 2;
	case 'Grating Alone'
		taskType = 3;
	case 'Blank + Grating'
		taskType = 4;
	otherwise
		taskType = 5;
end
ana.taskType = taskType;

%=================set up eye position drawing================
switch lower(ana.drawEye)
	case 'same screen'
		drawEye = 1;
	case 'new screen'
		if exist('s','var') && isa(s,'screenManager')
			if isempty(eT.operatorScreen); eT.operatorScreen = s; eT.secondScreen=true; end
			if ~s.isOpen; s.open; end
			drawEye = 2;
			refRate = 3; %refresh window every N frames
		else
			drawEye = 1;
		end
	otherwise
		drawEye = 0;
end

%=====================================================================
try %our main experimental try catch loop
%=====================================================================
	%===========================prepare===========================
	Priority(MaxPriority(sM.win)); %bump our priority to maximum allowed
	if ~ana.debug; ListenChar(-1); end
	commandwindow;
	startRecording(eT); WaitSecs('YieldSecs',0.5);
	trackerMessage(eT,'!!! Starting Session...');
	breakLoop		= false;
	ana.task		= struct();
	thisRun			= 0;
	breakLoop		= false;
	responseRedo	= 0; %number of trials the subject was unsure and redid (left arrow)
	startAlpha		= stimuli{4}.alphaOut;
	startAlpha2		= stimuli{4}.alpha2Out;
	fadeAmount		= ana.fadeAmount/100;
	fadeFinal		= ana.fadeFinal/100;
	
	%============================================================
	while ~breakLoop && task.thisRun <= task.nRuns
		thisRun = thisRun + 1;
		%-----setup our values and print some info for the trial
		startRecording(eT);
		if ana.useStaircase 
			contrastOut = staircase.xCurrent;
		else
			contrastOut = task.outValues{task.thisRun,1};
		end
		
		transitionTime = randi([ana.switchTime(1)*1e3, ana.switchTime(2)*1e3]) / 1e3;
		targetTime = randi([ana.targetON(1)*1e3, ana.targetON(2)*1e3]) / 1e3;
		if taskType == 3
			ana.gProbability = 100;
		end
		ana.task(thisRun).probability = rand;
		if ana.task(thisRun).probability <= (ana.gProbability/100)
			showGrating = true;
		else
			showGrating = false;
		end
		
		ana.task(thisRun).showGrating = showGrating;
		ana.task(thisRun).taskRun = task.thisRun;
		ana.task(thisRun).contrast = contrastOut;
		ana.task(thisRun).transitionTime = transitionTime;
		ana.task(thisRun).targetTime = targetTime;
		
		stimuli{2}.xPositionOut = ana.targetPosition;
		stimuli{3}.contrastOut = contrastOut;
		stimuli{4}.alphaOut		= startAlpha;
		stimuli{4}.alpha2Out	= startAlpha2;
		stimuli{4}.xPositionOut = ana.XFix;
		hide(stimuli);
		show(stimuli{4}); % fixation is visible
		update(stimuli);
		
		tStart = 0; tBlank = 0; tGrat = 0; tEnd = 0;
		
		eT.fixInit.X = [];
		eT.fixInit.Y = [];
		eT.updateFixationValues(ana.XFix,ana.YFix,ana.initTime,ana.fixTime,ana.radius,ana.strict);
		resetFixationHistory(eT);
		
		fprintf('\n\n===>>>START %i / %i: CONTRAST = %.2f TRANSITION TIME = %.2f TARGET ON = %.2f\n',...
			thisRun,task.thisRun,contrastOut,transitionTime,targetTime);
		trackerMessage(eT,['TRIALID ' num2str(thisRun)]);
		if taskType > 2 && showGrating; fprintf('===>>> GRATING trial!\n'); end
		if taskType > 2 && ~showGrating; fprintf('===>>> BLANK trial!\n'); end
		% ======================================================INITIATE TRIAL
		response = UNDEFINED; 
		fixated = '';
		tick = 1; 
		vbl = flip(sM); tStart = vbl;
		while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
			draw(stimuli);
			if drawEye==1 
				drawEyePosition(eT,true);
			elseif drawEye==2 && mod(tick,refRate)==0
				drawGrid(s);
				trackerDrawFixation(eT);
				trackerDrawEyePosition(eT);
			end
			finishDrawing(sM);
		
			vbl = flip(sM);
			if tick == 1; trackerMessage(eT,'INITIATE_FIX',vbl); end
			if drawEye==2 && mod(tick,refRate)==0; flip(s,[],[],2);end
			tick = tick + 1;
			
			getSample(eT);
			fixated=testSearchHoldFixation(eT,'fix','breakfix');
			doBreak = checkKeys();
			if doBreak; break; end
		end
		if ~strcmpi(fixated,'fix')
			Screen('Flip',sM.win); %flip the buffer
			response = BREAKINIT;
		else
			trackerMessage(eT,'END_FIX',vbl)
		end
		fprintf('--->>> Time delta Init = %.3f\n',vbl - tStart);
			
		% ======================================================TASKTYPE>0 (Blank)
		if taskType > 0 && response > -1
			tick = 1;
			triggerTarget = true;
			triggerFixOFF = true;
			show(stimuli{1});
			tBlank = vbl + sM.screenVals.ifi; 
			while vbl < (tBlank + transitionTime) && response ~= BREAKBLANK
				
				thisT = vbl - tBlank;
				
				draw(stimuli); %draw stimulus
				if drawEye==1 
					drawEyePosition(eT,true);
				elseif drawEye==2 && mod(tick,refRate)==0
					drawGrid(s);trackerDrawFixation(eT);trackerDrawEyePosition(eT);
					trackerDrawText(eT,'Blank Period...');
				end
				finishDrawing(sM);
				
				if triggerTarget && thisT > targetTime
					triggerTarget = false; show(stimuli{2}); 
				end
				
				if triggerFixOFF && taskType > 1 && thisT > ana.fixOFF
					stimuli{4}.alphaOut = stimuli{4}.alphaOut - fadeAmount;
					stimuli{4}.alpha2Out = stimuli{4}.alpha2Out - fadeAmount;
					if stimuli{4}.alphaOut <= fadeFinal+fadeAmount
						if fadeFinal <= 0
							hide(stimuli{4});
						end
						triggerFixOFF = false;
						
					end
				end

				vbl = Screen('Flip',sM.win, vbl + screenVals.halfisi); %flip the buffer
				if drawEye==2 && mod(tick,refRate)==0; flip(s,[],[],2);end
				tick = tick + 1;
				
				getSample(eT);
				isfix = isFixated(eT);
				if ~isfix
					fixated = 'breakfix';
					response = BREAKBLANK;
					statusMessage(eT,'Subject Broke Fixation!');
					trackerMessage(eT,'MSG:BreakFix')
					break;
				end
			end
		end
		if tBlank > 0;fprintf('--->>> Time delta blank = %.3f\n',vbl - tBlank);end
		
		%====================================================TASKTYPE > 2 GRATING/BLANK
		if taskType > 2 && response > -1
			if showGrating
				stimuli{1}.hide(); stimuli{3}.show(); stimuli{4}.show();
				stimuli{4}.xPositionOut = ana.targetPosition;
				stimuli{4}.alphaOut		= startAlpha;
				stimuli{4}.alpha2Out	= startAlpha2;
				eT.fixInit.X = ana.XFix;
				eT.fixInit.Y = ana.YFix;
				eT.updateFixationValues(ana.targetPosition,ana.YFix,ana.initTarget,ana.fixTarget,ana.radius,ana.strict);
				fixated = 'searching';
				fixOFF = ana.fixOFF2;
				triggerFixOFF = true;
				update(stimuli);
			else
				fixOFF = ana.fixOFF;
				eT.fixation.time = ana.keepBlank;
				resetFixationTime(eT); fixated = 'fixing';
			end
			
			tGrat = GetSecs;
			fprintf('--->>> Time delta to switch = %.3f\n',tGrat - vbl);
			while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix') && ~strcmpi(fixated,'EXCLUDED!')
				
				if showGrating
					thisT = vbl - tGrat;
				else
					thisT = vbl - tBlank;
				end
				
				draw(stimuli); %draw stimulus
				
				if drawEye==1 
					drawEyePosition(eT,true);
				elseif drawEye==2 && mod(tick,refRate)==0
					drawGrid(s);
					trackerDrawFixation(eT);
					trackerDrawEyePosition(eT);
					trackerDrawText(eT,'Target Period...');
				end
				
				finishDrawing(sM);
				
				if triggerFixOFF && thisT > fixOFF
					stimuli{4}.alphaOut = stimuli{4}.alphaOut - fadeAmount;
					stimuli{4}.alpha2Out = stimuli{4}.alpha2Out - fadeAmount;
					if stimuli{4}.alphaOut <= fadeFinal+fadeAmount 
						if fadeFinal <= 0
							hide(stimuli{4});
						end
						triggerFixOFF = false;
					end
				end
				
				doBreak = checkKeys();
				if doBreak; break; end
				
				vbl = Screen('Flip',sM.win, vbl + screenVals.halfisi); %flip the buffer
				if drawEye==2 && mod(tick,refRate)==0; flip(s,[],[],2);end
				tick = tick + 1;
				
				getSample(eT);
				if showGrating
					fixated=testSearchHoldFixation(eT,'fix','breakfix');
				else
					fixated = testHoldFixation(eT,'fix','breakfix');
				end				
				if strcmpi(fixated,'fix')
					response = YESSEE;
				elseif strcmpi(fixated,'breakfix')
					response = BREAKFIX;
				elseif strcmpi(fixated,'EXCLUDED!')
					response = BREAKFIX;
					fprintf('--->>> Fix INIT Exclusion triggered!\n');
				end
			end
		end
		tEnd = flip(sM);
		if tGrat > 0;fprintf('--->>> Time delta grat = %.3f\n',tEnd - tGrat);end
		ana.task(thisRun).tStart = tStart;
		ana.task(thisRun).tBlank = tBlank;
		ana.task(thisRun).tGrat = tGrat;
		ana.task(thisRun).tEnd = tEnd;
		
		%====================================================== FINALISE TRIAL
		if response > 0
			sM.audio.beep(1000,0.1,0.1);
			rM.timedTTL();
			ana.task(thisRun).response = response;
			task.updateTask(response);
			timeOut = ana.IFI;
			if drawEye==2 
				drawGrid(s);
				trackerDrawFixation(eT);
				trackerDrawEyePositions(eT);
				trackerDrawEyePosition(eT);
				trackerDrawText(eT,'Correct!!!...');
				flip(s,[],[],2);
			end
		elseif response == 0 && taskType < 3
			sM.audio.beep(1000,0.1,0.1);
			rM.timedTTL();
			ana.task(thisRun).response = response;
			%task.updateTask(response);
			timeOut = ana.IFI;
			if drawEye==2 
				drawGrid(s);
				trackerDrawFixation(eT);
				trackerDrawEyePositions(eT);
				trackerDrawEyePosition(eT);
				trackerDrawText(eT,'Correct blank!!!...');
				flip(s,[],[],2);
			end
		else
			sM.audio.beep(100,0.75,0.75);
			ana.task(thisRun).response = response;
			timeOut = ana.punishIFI;
			if drawEye==2 
				drawGrid(s);
				trackerDrawFixation(eT);
				trackerDrawEyePositions(eT);
				trackerDrawEyePosition(eT);
				if response == BREAKINIT
					trackerDrawText(eT,'Break in INIT!!!');
					timeOut = 0.75;
				elseif response == BREAKBLANK
					trackerDrawText(eT,'Break in BLANK!!!');
				elseif response == BREAKFIX
					trackerDrawText(eT,'Break in TARGET!!!');
				end
				flip(s,[],[],2);
			end
		end
		
		trackerMessage(eT,['TRIAL_RESULT ' num2str(response)]);
		stopRecording(eT);
		drawBackground(sM);
		vbl = flip(sM); %flip the buffer
		t = vbl;
		while vbl < t + timeOut
			doBreak = checkKeys();
			if doBreak; break; end
			vbl = flip(sM);
		end
	end %=====================================================END MAIN WHILE
	
	%=========================================================CLEANUP
	flip(sM);
	Priority(0); ListenChar(0); ShowCursor;
	reset(stimuli); %reset our stimuli
	try if isa(sM,'screenManager'); close(sM); end; end %#ok<*TRYNC>
	try if isa(s,'screenManager'); close(s); end; end
	try if isa(eT,'tobiiManager'); close(eT); end; end
	try if isa(rM,'arduinoManager'); close(rM); end; end
	p=uigetdir(pwd,'Select Directory to Save Data, CANCEL to not save.');
	if ischar(p)
		cd(p);
		response = task.response;
		responseInfo = task.responseInfo;
		save([ana.nameExp '.mat'], 'ana', 'response', 'responseInfo', 'task','sM','stimuli', 'eT');
		disp(['=====SAVE, saved current data to: ' pwd]);
	else
		eT.saveFile = ''; %blank save file so it doesn't save
	end	
	assignin('base','ana',ana);
catch ME
	getReport(ME)
	try if isa(sM,'screenManager'); close(sM); end; end %#ok<*TRYNC>
	try if isa(s,'screenManager'); close(s); end; end
	try if isa(eT,'tobiiManager'); close(eT); end; end
	try if isa(rM,'arduinoManager'); close(rM); end; end
	Priority(0); ListenChar(0); ShowCursor;
	disp(['!!!!!!!!=====CRASH, save current data to: ' pwd]);
	save([ana.nameExp 'CRASH.mat'], 'task', 'ana', 'sM', 'stimuli', 'eT', 'ME')
	reset(stimuli);
	clear stimuli sM task taskB taskW md eT s
	rethrow(ME);
end
	
	function doBreak = checkKeys()
		doBreak = false;
		[keyIsDown, ~, keyCode] = KbCheck(-1);
		if keyIsDown == 1
			rchar = KbName(keyCode);if iscell(rchar); rchar=rchar{1}; end
			switch lower(rchar)
				case {'q','0','escape'}
					Screen('DrawText', sM.win, '===>>> EXIT!!!',10,10);
					flip(sM);
					fprintf('===>>> EXIT!\n');
					fixated = 'breakfix';
					response = BREAKINIT;
					breakLoop = true;
					doBreak = true;
				case {'p'}
					fprintf('===>>> PAUSED!\n');
					Screen('DrawText', sM.win, '===>>> PAUSED, press key to resume!!!',10,10);
					flip(sM);
					KbWait(-1);
					fixated = 'breakfix';
					response = BREAKINIT;
					doBreak = true;
				case {'c'}
					WaitSecs('YieldSecs',0.1);
					fprintf('\n\n--->>> Entering calibration mode...\n');
					trackerSetup(eT,eT.calibration);
					fixated = 'breakfix';
					response = BREAKINIT;
					doBreak = true;
			end
		end
	end

	function updateResponse()
		tEnd = GetSecs;
		ListenChar(0);
		if response == NOSEE || response == YESSEE  %subject responded
			responseInfo.response = response;
			responseInfo.N = task.thisRun;
			responseInfo.times = [tFix tStim tPedestal tMask tMaskOff tEnd];
			responseInfo.contrastOut = colourOut;
			responseInfo.pedestal = pedestal;
			responseInfo.pedestalGamma = pedestal;
			responseInfo.blackN = taskB.thisRun;
			responseInfo.whiteN = taskW.thisRun;
			responseInfo.redo = responseRedo;
			updateTask(task,response,tEnd,responseInfo)
			if ana.useStaircase == true
				if colourOut == 0
					if response == NOSEE 
						yesnoresponse = 0;
					else
						yesnoresponse = 1;
					end
					staircaseB = PAL_AMPM_updatePM(staircaseB, yesnoresponse);
				elseif colourOut == 1
					if response == NOSEE 
						yesnoresponse = 0;
					else
						yesnoresponse = 1;
					end
					staircaseW = PAL_AMPM_updatePM(staircaseW, yesnoresponse);
				end
				fprintf('subject response: %i | ', yesnoresponse)
			else
				if colourOut == 0
					taskB.thisRun = taskB.thisRun + 1;
				else
					taskW.thisRun = taskW.thisRun + 1;
				end
			end
		elseif response == -10
			if task.totalRuns > 1
				if ana.useStaircase == true
					warning('Not Implemented yet!!!')
				else
					if task.responseInfo(end) == 0
						taskB.rewindRun;
					else
						taskW.rewindRun;
					end
					task.rewindRun
					fprintf('new trial  = %i\n', task.thisRun);
				end
			end
		elseif response == UNSURE
			responseRedo = responseRedo + 1;
			fprintf('Subject is trying stimulus again, overall = %.2g %\n',responseRedo);
		end
	end

	function doPlot()
		ListenChar(0);
				
		x = 1:length(task.response);
		info = cell2mat(task.responseInfo);
		ped = [info.pedestal];
		
		idxW = [info.contrastOut] == 1;
		idxB = [info.contrastOut] == 0;
		
		idxNO = task.response == NOSEE;
		idxYESSEE = task.response == YESSEE;

		cla(ana.plotAxis1); line(ana.plotAxis1,[0 max(x)+1],[0.5 0.5],'LineStyle','--','LineWidth',2); hold(ana.plotAxis1,'on')
		plot(ana.plotAxis1,x(idxNO & idxB), ped(idxNO & idxB),'ro','MarkerFaceColor','r','MarkerSize',8);
		plot(ana.plotAxis1,x(idxNO & idxW), ped(idxNO & idxW),'bo','MarkerFaceColor','b','MarkerSize',8);
		plot(ana.plotAxis1,x(idxYESSEE & idxB), ped(idxYESSEE & idxB),'rv','MarkerFaceColor','w','MarkerSize',8);
		plot(ana.plotAxis1,x(idxYESSEE & idxW), ped(idxYESSEE & idxW),'bv','MarkerFaceColor','w','MarkerSize',8);

		
		if length(task.response) > 4
			try %#ok<TRYNC>
				idx = idxNO & idxB;
				blackPedestal = ped(idx);
				[bAvg, bErr] = stderr(blackPedestal);
				idx = idxNO & idxW;
				whitePedestal = ped(idx);
				[wAvg, wErr] = stderr(whitePedestal);
				if length(blackPedestal) > 4 && length(whitePedestal)> 4
					p = ranksum(abs(blackPedestal-0.5),abs(whitePedestal-0.5));
				else
					p = 1;
				end
				t = sprintf('TRIAL:%i BLACK=%.2g +- %.2g (%i)| WHITE=%.2g +- %.2g (%i) | P=%.2g [B=%.2g W=%.2g]', task.thisRun, bAvg, bErr, length(blackPedestal), wAvg, wErr, length(whitePedestal), p, mean(abs(blackPedestal-0.5)), mean(abs(whitePedestal-0.5)));
				title(ana.plotAxis1, t);
			end
		else
			t = sprintf('TRIAL:%i', task.thisRun);
			title(ana.plotAxis1, t);
		end
		box(ana.plotAxis1,'on'); grid(ana.plotAxis1,'on');
		ylim(ana.plotAxis1,[0.1 0.9]);
		xlim(ana.plotAxis1,[0 max(x)+1]);
		xlabel(ana.plotAxis1,'Trials (red=BLACK blue=WHITE)')
		ylabel(ana.plotAxis1,'Stimulus Luminance')
		hold(ana.plotAxis1,'off')
		
		if ana.useStaircase == true
			cla(ana.plotAxis2); hold(ana.plotAxis2,'on');
			if ~isempty(staircaseB.threshold)
				rB = [min(staircaseB.stimRange):.003:max(staircaseW.stimRange)];
				outB = ana.PF([staircaseB.threshold(end) ...
					staircaseB.slope(end) staircaseB.guess(end) ...
					staircaseB.lapse(end)], rB);
				plot(ana.plotAxis2,rB,outB,'r-','LineWidth',2);
				
				r = staircaseB.response;
				t = staircaseB.x(1:length(r));
				yes = r == 1;
				no = r == 0; 
				plot(ana.plotAxis2,t(yes), ones(1,sum(yes)),'ko','MarkerFaceColor','r','MarkerSize',10);
				plot(ana.plotAxis2,t(no), zeros(1,sum(no))+ana.gamma,'ro','MarkerFaceColor','w','MarkerSize',10);
			end
			if ~isempty(staircaseW.threshold)
				rW = [min(staircaseB.stimRange):.003:max(staircaseW.stimRange)];
				outW = ana.PF([staircaseW.threshold(end) ...
					staircaseW.slope(end) staircaseW.guess(end) ...
					staircaseW.lapse(end)], rW);
				plot(ana.plotAxis2,rW,outW,'b--','LineWidth',2);
				
				r = staircaseW.response;
				t = staircaseW.x(1:length(r));
				yes = r == 1;
				no = r == 0;
				plot(ana.plotAxis2,t(yes), ones(1,sum(yes)),'kd','MarkerFaceColor','b','MarkerSize',8);
				plot(ana.plotAxis2,t(no), zeros(1,sum(no))+ana.gamma,'bd','MarkerFaceColor','w','MarkerSize',8);
				end

				box(ana.plotAxis2, 'on'); grid(ana.plotAxis2, 'on');
				ylim(ana.plotAxis2, [ana.gamma 1]);
				xlim(ana.plotAxis2, [0 0.4]);
				xlabel(ana.plotAxis2, 'Contrast (red=BLACK blue=WHITE)');
				ylabel(ana.plotAxis2, 'Responses');
				hold(ana.plotAxis2, 'off');		
		end
		drawnow;
	end

	function setupStairCase()
		priorAlphaB = linspace(min(pedestalBlack), max(pedestalBlack),grain);
		priorAlphaW = linspace(min(pedestalWhite), max(pedestalWhite),grain);
		priorBetaB = linspace(0, ana.betaMax, 40); %our slope
		priorBetaW = linspace(0, ana.betaMax, 40); %our slope
		priorGammaRange = ana.gamma;  %fixed value (using vector here would make it a free parameter)
		priorLambdaRange = ana.lambda; %ditto
		
		staircaseB = PAL_AMPM_setupPM('stimRange',pedestalBlack,'PF',ana.PF,...
			'priorAlphaRange', priorAlphaB, 'priorBetaRange', priorBetaB,...
			'priorGammaRange',priorGammaRange, 'priorLambdaRange',priorLambdaRange,...
			'numTrials', stopRule,'marginalize',ana.marginalize);
		
		staircaseW = PAL_AMPM_setupPM('stimRange',pedestalWhite,'PF',ana.PF,...
			'priorAlphaRange', priorAlphaW, 'priorBetaRange', priorBetaW,...
			'priorGammaRange',priorGammaRange, 'priorLambdaRange',priorLambdaRange,...
			'numTrials', stopRule,'marginalize',ana.marginalize);
		
		if usePriors
			priorB = PAL_pdfNormal(staircaseB.priorAlphas,ana.alphaPrior,ana.alphaSD).*PAL_pdfNormal(staircaseB.priorBetas,ana.betaPrior,ana.betaSD);
			priorW = PAL_pdfNormal(staircaseW.priorAlphas,ana.alphaPrior,ana.alphaSD).*PAL_pdfNormal(staircaseW.priorBetas,ana.betaPrior,ana.betaSD);
			figure;
			subplot(1,2,1);imagesc(staircaseB.priorBetaRange,staircaseB.priorAlphaRange,priorB);axis square
			ylabel('Threshold');xlabel('Slope');title('Initial Bayesian Priors BLACK')
			subplot(1,2,2);imagesc(staircaseW.priorBetaRange,staircaseW.priorAlphaRange,priorW); axis square
			ylabel('Threshold');xlabel('Slope');title('Initial Bayesian Priors WHITE')
			staircaseB = PAL_AMPM_setupPM(staircaseB,'prior',priorB);
			staircaseW = PAL_AMPM_setupPM(staircaseW,'prior',priorW);
		end
	end

	function saveMetaData()
		ana.values.nBlocks = nBlocks;
		ana.values.nBlocksOverall = nBlocksOverall;
		ana.values.NOSEE = NOSEE;
	    ana.values.YESSEE = YESSEE;
		ana.values.UNSURE = UNSURE;
		ana.values.BREAKFIX = BREAKFIX;
		ana.values.UNDEFINED = UNDEFINED;
		ana.values.BREAKINIT = BREAKINIT;
		ana.values.BREAKBLANK = BREAKBLANK;
	end


end


