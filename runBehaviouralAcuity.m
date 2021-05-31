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
%=================================response values, linked to left, up, down
NOSEE = 1; 	YESSEE = 2; UNSURE = 4; BREAKFIX = -1;
%saveMetaData();

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
eT.resetFixation();
eT.updateFixationValues(ana.XFix,ana.YFix,ana.initTime,ana.fixTime,ana.radius,ana.strict);

%---------------------------Set up task variables----------------------

if ana.useStaircase == false
	task = stimulusSequence();
	task.name = ana.nameExp;
	task.nBlocks = nBlocks;
	task.nVar(1).name = 'contrast';
	task.nVar(1).stimulus = 2;
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
	startRecording(eT); WaitSecs('YieldSecs',0.5);
	trackerMessage(eT,'!!! Starting Session...');
	breakLoop		= false;
	ana.trial		= struct();
	thisRun			= 0;
	rewards			= 0;
	breakLoop		= false;
	fixated			= 'no';
	response		= NaN;
	responseRedo	= 0; %number of trials the subject was unsure and redid (left arrow)
	startAlpha		= stimuli{4}.alphaOut;
	startAlpha2		= stimuli{4}.alpha2Out;
	
	%============================================================
	while ~breakLoop && task.thisRun <= task.nRuns
		%-----setup our values and print some info for the trial
		response = NaN; fixated = '';
		startRecording(eT); WaitSecs('YieldSecs',0.5);
		if ana.useStaircase 
			contrastOut = staircase.xCurrent;
		else
			contrastOut = task.outValues{task.thisRun,1};
		end
		
		transitionTime = randi([ana.minTime*1e3, ana.maxTime*1e3]) / 1e3;
		ana.task(task.thisRun).contrast = contrastOut;
		ana.task(task.thisRun).transitionTime = transitionTime;
		
		stimuli{2}.xPositionOut = ana.targetPosition;
		stimuli{3}.contrastOut = contrastOut;
		stimuli{4}.alphaOut		= startAlpha;
		stimuli{4}.alpha2Out	= startAlpha2;
		stimuli{4}.xPositionOut = ana.XFix;
		hide(stimuli);
		show(stimuli{4}); % fixation is visible
		update(stimuli);
		
		eT.updateFixationValues(ana.XFix,ana.YFix,ana.initTime,ana.fixTime,ana.radius,ana.strict);
		resetFixation(eT);
		
		fprintf('\n\n===>>>START %i: CONTRAST = %.2f TRANSITION TIME = %.2f\n',task.thisRun,contrastOut,transitionTime);
		trackerMessage(eT,['TRIALID ' num2str(thisRun)]);
		
		% ======================================================INITIATE TRIAL
		vbl = flip(sM); tStart = vbl;
		tick = 1; 
		while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
			draw(stimuli);
			if drawEye==1 
				drawEyePosition(eT,true);
			elseif drawEye==2 && mod(tick,refRate)==0
				drawGrid(s);trackerDrawFixation(eT);trackerDrawEyePosition(eT);
			end
			finishDrawing(sM);
			getSample(eT);
			fixated=testSearchHoldFixation(eT,'fix','breakfix');
			doBreak = checkKeys();
			if doBreak; break; end
			vbl = flip(sM);
			if tick == 1; trackerMessage(eT,'INITIATE_FIX',vbl); end
			if drawEye==2 && mod(tick,refRate)==0; flip(s,[],[],2);end
			tick = tick + 1;
		end
		if ~strcmpi(fixated,'fix')
			if drawEye==2
				drawGrid(s);
				trackerDrawFixation(eT);
				trackerDrawEyePosition(eT);
				trackerDrawText(eT,'Break Initial Fixation...')
				flip(s,[],[],2);
			end
			fprintf('===>>> BROKE INITIATE FIXATION Trial = %i\n', thisRun);
			trackerMessage(eT,'TRIAL_RESULT -100');
			trackerMessage(eT,'MSG:BreakInitialFix');
			Screen('Flip',sM.win); %flip the buffer
			response = BREAKFIX;
			WaitSecs('YieldSecs',0.5);
			continue
		else
			trackerMessage(eT,'END_FIX',vbl)
		end
			
		% ======================================================TASKTYPE>0 (Blank)
		if taskType > 0
			tick = 1;
			triggerTarget = true;
			triggerFixOFF = true;
			show(stimuli{1});
			tBlank = vbl + sM.screenVals.ifi; 
			while vbl < (tBlank + transitionTime) && response ~= BREAKFIX
				thisT = vbl - tBlank;
				draw(stimuli); %draw stimulus
				if drawEye==1 
					drawEyePosition(eT,true);
				elseif drawEye==2 && mod(tick,refRate)==0
					drawGrid(s);trackerDrawFixation(eT);trackerDrawEyePosition(eT);
				end
				finishDrawing(sM);
				if triggerTarget && thisT > ana.targetON
					triggerTarget = false; show(stimuli{2}); 
				end
				if taskType > 1 && triggerFixOFF && thisT > ana.fixOFF
					if stimuli{4}.alphaOut > 0;stimuli{4}.alphaOut = stimuli{4}.alphaOut - 0.05;end
					if stimuli{4}.alpha2Out > 0;stimuli{4}.alpha2Out = stimuli{4}.alpha2Out - 0.05;end
					if stimuli{4}.alphaOut == 0 && stimuli{4}.alpha2Out == 0
						triggerFixOFF = false;
					end
				end
				getSample(eT);
				isfix = isFixated(eT);
				if ~isfix
					if drawEye==2
						drawGrid(s);trackerDrawFixation(eT);trackerDrawEyePosition(eT);
						flip(s,[],[],2);
					end
					fixated = 'breakfix';
					response = BREAKFIX;
					fprintf('BREAK in BLANK!\n');
					statusMessage(eT,'Subject Broke Fixation!');
					trackerMessage(eT,'MSG:BreakFix')
					break;
				end
				vbl = Screen('Flip',sM.win, vbl + screenVals.halfisi); %flip the buffer
				if drawEye==2 && mod(tick,refRate)==0; flip(s,[],[],2);end
				tick = tick + 1;
			end
		end
		
		%====================================================TASKTYPE > 2 GRATING
		if taskType > 2
			triggerFixOFF = true;
			stimuli{1}.hide(); stimuli{3}.show();
			stimuli{4}.xPositionOut = ana.targetPosition;
			stimuli{4}.alphaOut		= startAlpha;
			simuli{4}.alpha2Out		= startAlpha2;
			update(stimuli);
			eT.updateFixationValues(ana.targetPosition,ana.YFix,ana.initTarget,ana.fixTarget,ana.radius,ana.strict);
			resetFixation(eT); fixated = '';
			tGrat = vbl + sM.screenVals.ifi;
			while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix') && response ~= BREAKFIX
				
				thisT = vbl - tGrat;
				
				draw(stimuli); %draw stimulus
				if drawEye==1 
					drawEyePosition(eT,true);
				elseif drawEye==2 && mod(tick,refRate)==0
					drawGrid(s);trackerDrawFixation(eT);trackerDrawEyePosition(eT);
				end
				finishDrawing(sM);
				
				if triggerFixOFF && thisT > ana.fixOFF
					if stimuli{4}.alphaOut > 0;stimuli{4}.alphaOut = stimuli{4}.alphaOut - 0.05;end
					if stimuli{4}.alpha2Out > 0;stimuli{4}.alpha2Out = stimuli{4}.alpha2Out - 0.05;end
					if stimuli{4}.alphaOut == 0 && stimuli{4}.alpha2Out == 0
						triggerFixOFF = false;
					end
				end
				
				getSample(eT);
				fixated=testSearchHoldFixation(eT,'fix','breakfix');
				doBreak = checkKeys();
				if doBreak || strcmpi(fixated,'breakfix'); break; end
				vbl = Screen('Flip',sM.win, vbl + screenVals.halfisi); %flip the buffer
				if drawEye==2 && mod(tick,refRate)==0; flip(s,[],[],2);end
				tick = tick + 1;
			end
		end
		if drawEye==2 
			drawGrid(s);trackerDrawFixation(eT);trackerDrawEyePosition(eT);
			trackerDrawText(eT,'Final Eye Position...');
			flip(s,[],[],2);
		end
		timeOut = 3;
		if strcmpi(fixated,'fix')
			sM.audio.beep(1000,0.1,0.1);
			response = YESSEE;
			ana.trial(task.thisRun).response = response;
			rM.timedTTL();
			task.updateTask(response);
			timeOut = 1;
		else
			sM.audio.beep(100,0.5,0.75);
			response = NOSEE;
			ana.trial(task.thisRun).response = response;
			timeOut = 2;
		end
		
		tEnd = GetSecs;
		resetFixation(eT); fixated = ''; response = NaN;
		trackerMessage(eT,['TRIAL_RESULT ' num2str(response)]);
		stopRecording(eT);
		drawBackground(sM);
		vbl = Screen('Flip',sM.win); %flip the buffer
		t = vbl;
		while vbl < t + timeOut
			doBreak = checkKeys();
			if doBreak || strcmpi(fixated,'breakfix'); break; end
			vbl = flip(sM);
		end
	end
	
	%-----Cleanup
	Screen('Flip',sM.win);
	reset(stimuli); %reset our stimulus ready for use again
	Priority(0); ListenChar(0); ShowCursor;
	close(eT);
	close(sM); %close screen
	if isa(s,'screenManager'); close(s); end
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
catch ME
	getReport(ME)
	close(sM); %close screen
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
					breakLoop = true;
					doBreak = true;
				case {'p'}
					fprintf('===>>> PAUSED!\n');
					Screen('DrawText', sM.win, '===>>> PAUSED, press key to resume!!!',10,10);
					flip(sM);
					WaitSecs('Yieldsecs',0.1);
					KbWait(-1);
					fixated = 'breakfix';
					doBreak = true;
				case {'c'}
					WaitSecs('YieldSecs',0.1);
					fprintf('\n\n--->>> Entering calibration mode...\n');
					if isempty(regexpi(ana.VEP.Type,'Sin|Square'))
						trackerSetup(eT);
					else
						trackerSetup(eT,eT.calibration);
					end
					fixated = 'breakfix';
					doBreak = true;
				case {'1','1!','kp_end'}
					if kTimer < vbl
						kTimer = vbl + 0.2;
						rM.timedTTL(2,rewardtime);
						rewards = rewards + 1;
					end
				case {'2','2@','kp_down'}
					correct();
					doBreak = true;
				case {'3','3#','kp_next'}
					incorrect();
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
		ana.values.nBlocksOverall = nBlocksOverall;
		ana.values.pedestalBlackLinear = pedestalBlackLinear;
		ana.values.pedestalWhiteLinear = pedestalWhiteLinear;
		ana.values.pedestalBlack = pedestalBlack;
		ana.values.pedestalWhite = pedestalWhite;
		ana.values.NOSEE = NOSEE;
	    ana.values.YESSEE = YESSEE;
		ana.values.UNSURE = UNSURE;
		ana.values.BREAKFIX = BREAKFIX;
		ana.values.XPos = XPos;
		ana.values.yPos = YPos;
	end


end


