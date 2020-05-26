function runBasicTraining(ana)

global lM
if ~exist('lM','var') || isempty(lM) || ~isa(lM,'labJackT')
	 lM = labJackT('openNow',false);
end
if ~ana.sendTrigger; lM.silentMode = true; end
lM.strobeTime = 10; %make strobe time a bit longer for EEG 
if ~lM.isOpen; open(lM); end %open our strobed word manager

global rM
if ~exist('rM','var') || isempty(rM)
	rM = arduinoManager();
end
open(rM) %open our reward manager

fprintf('\n--->>> runBasicTraining Started: ana UUID = %s!\n',ana.uuid);

%===================Initiate our metadata===================
ana.date = datestr(datetime);
ana.version = Screen('Version');
ana.computer = Screen('Computer');
ana.gpu = opengl('data');

%===================experiment parameters===================
ana.screenID = max(Screen('Screens'));%-1;

%===================Make a name for this run===================
if ~isempty(ana.subject)
	nameExp = ['basicTrain_' ana.stimulus '_' ana.subject];
	ana.timeExp = fix(clock());
	c = sprintf(' %i',ana.timeExp);
	nameExp = [nameExp c];
	ana.nameExp = regexprep(nameExp,' ','_');
else
	ana.nameExp = 'debug';
end

cla(ana.plotAxis1);
cla(ana.plotAxis2);

%==========================TRY==========================
try
	PsychDefaultSetup(2);
	%===================open our screen====================
	sM							= screenManager();
	sM.screen				= ana.screenID;
	if ana.debug || ismac || ispc || ~isempty(regexpi(ana.gpu.Vendor,'NVIDIA','ONCE'))
		sM.disableSyncTests = true; 
	end
	if ana.debug
		sM.windowed			= [0 0 1400 1000]; sM.debug = true;
		sM.verbosityLevel	= 5;
	else
		sM.debug				= false;
		sM.verbosityLevel	= 3;
	end
	sM.backgroundColour	= ana.backgroundColour;
	sM.pixelsPerCm			= ana.pixelsPerCm;
	sM.distance				= ana.distance;
	sM.blend					= true;
	if isfield(ana,'screenCal') && exist(ana.screenCal, 'file')
		load(ana.screenCal);
		if exist('c','var') && isa(c,'calibrateLuminance')
			sM.gammaTable = c;
		end
		clear c;
	end
	sM.open; % OPEN THE SCREEN
	ana.gpuInfo				= Screen('GetWindowInfo',sM.win);
	fprintf('\n--->>> BasicTraining Opened Screen %i : %s\n', sM.win, sM.fullName);
	
	PsychPortAudio('Close');
	sM.audio = audioManager(); sM.audio.close();
	if IsLinux
		sM.audio.device = [];
	elseif IsWin
		sM.audio.device = [];
	end
	sM.audio.setup();
	
	%===========================tobii manager=====================
	eT							= tobiiManager();
	eT.name					= ana.nameExp;
	eT.model             = ana.tracker;
	eT.trackingMode		= ana.trackingMode;
	eT.eyeUsed				= ana.eyeUsed;
	eT.sampleRate			= ana.sampleRate;
	eT.calibrationStimulus= ana.calStim;
	eT.manualCalibration = ana.calManual;
	eT.calPositions		= ana.calPos;
	eT.valPositions		= ana.valPos;
	eT.autoPace				= ana.autoPace;
	eT.smoothing.nSamples= ana.nSamples;
	eT.smoothing.method	= ana.smoothMethod;
	eT.smoothing.window	= ana.w;
	eT.smoothing.eyes		= ana.smoothEye;
	if ~ana.isDummy; eT.verbose	= true; end
	if ~ana.useTracker || ana.isDummy
		eT.isDummy			= true;
	end
	if length(Screen('Screens')) > 1 && ~eT.isDummy % ---- second screen for calibration
		s						= screenManager;
		s.screen				= sM.screen - 1;
		s.backgroundColour= sM.backgroundColour;
		s.pixelsPerCm		= sM.pixelsPerCm;
		s.distance			= sM.distance;
		[w,h]=Screen('WindowSize',s.screen);
		s.windowed			= [0 0 round(w/1.2) round(h/1.2)];
		s.bitDepth			= '8bit';
		s.blend				= sM.blend;
		s.disableSyncTests= true;
	end
	if exist('s','var')
		initialise(eT,sM,s);
	else
		initialise(eT,sM);
	end
	eT.settings.cal.paceDuration = ana.paceDuration;
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
	
	% ---- fixation values.
	eT.resetFixation();
	eT.fixation.X			= 0;
	eT.fixation.Y			= 0;
	eT.fixation.initTime	= ana.initTime;
	eT.fixation.fixTime		= ana.fixTime;
	eT.fixation.radius		= ana.radius;
	eT.fixation.strict		= ana.strict;
	
	%===========================set up stimuli====================
	if strcmpi(ana.stimulus,'Dancing Monkey')
		stim				= movieStimulus();
		stim.size			= ana.size;
		stim.setup(sM);
		ana.fixOnly			= false;
		ana.moveStim		= true;
		ana.isVEP			= false;
		seq.taskFinished	= false;
	elseif strcmpi(ana.stimulus,'Pictures')
		stim				= imageStimulus();
		stim.size			= ana.size;
		stim.fileName		= ana.imageDir;
		stim.setup(sM);
		ana.fixOnly			= false;
		ana.moveStim		= true;
		ana.isVEP			= false;
		seq.taskFinished	= false;
	elseif strcmpi(ana.stimulus,'VEP')
		stim									= metaStimulus();
		switch ana.VEP.Type
			case 'Checkerboard'
				stim.stimuli{1}					= barStimulus();
				if ana.size == 0 || ana.size == inf
					stim.stimuli{1}.barWidth	= ceil(sM.screenVals.width / sM.ppd);
					stim.stimuli{1}.barHeight	= ceil(sM.screenVals.height / sM.ppd);
				else
					stim.stimuli{1}.size			= ana.size;
				end
				stim.stimuli{1}.type				= 'checkerboard';
			case {'Square','Sin'}
				stim.stimuli{1}					= gratingStimulus();
				if ana.size == 0 || ana.size == inf
					stim.stimuli{1}.size	= ceil(sM.screenVals.width / sM.ppd);
				else
					stim.stimuli{1}.size			= ana.size;
				end
				if strcmpi(ana.VEP.Type,'Square')
					sM.srcMode				= 'GL_ONE';
					sM.dstMode				= 'GL_ZERO';
					stim.stimuli{1}.type = 'square';
				end
				stim.stimuli{1}.tf				= 0;
				stim.stimuli{1}.mask				= ana.VEP.mask;
			case 'LogGabor'
				stim.stimuli{1}					= logGaborStimulus();
				if ana.size == 0 || ana.size == inf
					stim.stimuli{1}.size	= ceil(sM.screenVals.width / sM.ppd);
				else
					stim.stimuli{1}.size			= ana.size;
				end
				stim.stimuli{1}.sf				= ana.VEP.sfPeak;
				stim.stimuli{1}.sfSigma			= ana.VEP.sfSigma;
				stim.stimuli{1}.angle			= ana.VEP.anglePeak;
				stim.stimuli{1}.angleSigma		= ana.VEP.angleSigma;
				stim.stimuli{1}.mask				= ana.VEP.mask;
		end
		stim.stimuli{1}.speed					= 0;
		stim.stimuli{1}.phaseReverseTime		= ana.VEP.Flicker;
		
		stim.stimuli{2}							= discStimulus();
		stim.stimuli{2}.size						= 1;
		stim.stimuli{2}.colour					= ana.backgroundColour;
		stim.setup(sM);
		if ana.spotSize == 0; stim.stimuli{2}.hide(); end
		ana.fixOnly			= false;
		ana.moveStim		= false;
		ana.isVEP			= true;
		
		
		seq					= stimulusSequence();
		seq.nBlocks			= ana.nBlocks;
		seq.addBlank		= true;
		seq.nVar(1).name	= 'sf';
		if size(ana.VEP.SF,1) > size(ana.VEP.SF,2)
			if ana.VEP.LogSF
				seq.nVar(1).values	= logspace(log10(ana.VEP.SF(1)),log10(ana.VEP.SF(2)),ana.VEP.SF(3));
			else
				seq.nVar(1).values	= linspace(ana.VEP.SF(1),ana.VEP.SF(2),ana.VEP.SF(3));
			end
		else
			seq.nVar(1).values = [ana.VEP.SF];
		end
		seq.nVar(1).values = unique(seq.nVar(1).values);
		seq.nVar(1).stimulus = 1;
		
		seq.nVar(2).name	= 'contrast';
		if size(ana.VEP.Contrast,1) > size(ana.VEP.Contrast,2)
			if ana.VEP.LogContrast
				seq.nVar(2).values	= [logspace(log10(ana.VEP.Contrast(1)),log10(ana.VEP.Contrast(2)),ana.VEP.Contrast(3))];
			else
				seq.nVar(2).values	= [linspace(ana.VEP.Contrast(1),ana.VEP.Contrast(2),ana.VEP.Contrast(3))];
			end
		else
			seq.nVar(2).values = [ana.VEP.Contrast];
		end
		seq.nVar(2).values = unique(seq.nVar(2).values);
		seq.nVar(2).stimulus = 1;
		
		initialise(seq);
		ana.nTrials = seq.nRuns;
	else
		ana.fixOnly			= true;
		ana.moveStim		= true;
		ana.isVEP			= false;
		seq.taskFinished	= false;
		if ana.size == 0; ana.size = 0.6; end
	end
	
	pos = ana.positions;
	
	%===========================prepare===========================
	Priority(MaxPriority(sM.win)); %bump our priority to maximum allowed
	if ana.sendTrigger
		sd = ana.timeExp;
		sd(1)=20;
		for i = 1:3;lM.strobeServer(255);WaitSecs(0.02); end
		for i = 1:length(sd);lM.strobeServer(sd(i));WaitSecs(0.02);end
	end
	startRecording(eT); WaitSecs('YieldSecs',1);
	trackerMessage(eT,'!!! Starting Demo...');
	breakLoop		= false;
	ana.trial		= struct();
	thisRun			= 0;
	rewards			= 0;
	pfeedback		= 0;
	nfeedback		= 0;
	
	while ~breakLoop
		%=========================TRIAL SETUP==========================
		thisRun = thisRun + 1;
		if ~ana.moveStim && ~ana.isVEP
			thisPos = pos(randi(length(pos)),:);
			eT.fixation.X = thisPos(1);
			eT.fixation.Y = thisPos(2);
			if ~ana.fixOnly
				stim.xPositionOut = thisPos(1);
				stim.yPositionOut = thisPos(2);
			end
			fprintf('\n===>>> BasicTraining START Run = %i | %s | pos = %i %i\n', thisRun, sM.fullName,thisPos(1),thisPos(2));
		else
			thisPos = [0, 0];
			eT.fixation.X = thisPos(1);
			eT.fixation.Y = thisPos(2);
		end
		if ana.isVEP
			thisRun = seq.outIndex(seq.totalRuns);
			if isnan(seq.outValues{seq.totalRuns,1});
				hide(stim);
				fprintf('BLANK STIMULUS CONDITION\n');
			else
				show(stim);
				stim.stimuli{1}.sfOut = seq.outValues{seq.totalRuns,1};
				stim.stimuli{1}.contrastOut = seq.outValues{seq.totalRuns,2};
			end
			fprintf('\n===>>> BasicTraining START Run = %i (%i:%i) | %s | SF = %.2f | Contrast = %.2f\n', thisRun, seq.totalRuns, seq.nRuns, sM.fullName,stim.stimuli{1}.sfOut,stim.stimuli{1}.contrastOut);
		end
		
		if ~ana.fixOnly
			update(stim); 
		end
		
		eT.resetFixation();
		
		if ~ana.debug;ListenChar(-1);end
		
		%=====================INITIATE FIXATION
		trackerMessage(eT,['TRIALID ' num2str(thisRun)]);
		trackerMessage(eT,'INITIATEFIX');
		fixated = ''; doBreak = false;
		if ana.useTracker
			while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
				if ana.spotSize > 0;sM.drawCross(ana.spotSize,[],thisPos(1),thisPos(2));end
				if ana.photoDiode; drawPhotoDiodeSquare(sM,[0 0 0]); end
				if ana.drawEye; drawEyePosition(eT,true); end
				finishDrawing(sM);
				flip(sM);
				getSample(eT);
				fixated=testSearchHoldFixation(eT,'fix','breakfix');
				doBreak = checkKeys();
				if doBreak; break; end
			end
			ListenChar(0);
			if strcmpi(fixated,'breakfix')
				fprintf('===>>> BROKE INITIATE FIXATION Trial = %i\n', thisRun);
				trackerMessage(eT,'TRIAL_RESULT -100');
				trackerMessage(eT,'MSG:BreakInitialFix');
				if ana.photoDiode; drawPhotoDiodeSquare(sM,[0 0 0]); end
				Screen('Flip',sM.win); %flip the buffer
				WaitSecs('YieldSecs',0.5);
				continue
			end
		else
			if ana.spotSize > 0;sM.drawCross(ana.spotSize,[],thisPos(1),thisPos(2));end
			if ana.photoDiode; drawPhotoDiodeSquare(sM,[0 0 0]); end
			finishDrawing(sM);
			flip(sM);
			WaitSecs(0.5);
		end
		
		%=====================SHOW STIMULUS
		tick = 0;
		kTimer = 0; % this is the timer to stop too many key events
		thisResponse = -1; doBreak = false;
		if ana.spotSize > 0;sM.drawCross(ana.spotSize,[],thisPos(1),thisPos(2));end
		if ana.photoDiode; drawPhotoDiodeSquare(sM,[0 0 0]); end
		if ana.rewardStart; rM.timedTTL(2,300); rewards=rewards+1; end
		if ~ana.isVEP; play(sM.audio); end
		tStart = flip(sM); vbl = tStart;
		while vbl < tStart + ana.playTimes
			if ana.fixOnly
				drawCross(sM,ana.size,[],thisPos(1),thisPos(2));
			else
				draw(stim);
				if ana.isVEP
					if ana.spotSize > 0;sM.drawCross(ana.spotSize,[],thisPos(1),thisPos(2));end
				else
					sM.drawCross(0.4,[0.5 0.5 0.5],thisPos(1),thisPos(2));
				end
			end
			if ana.photoDiode; drawPhotoDiodeSquare(sM,[1 1 1]); end
			if ana.drawEye; drawEyePosition(eT,true); end
			finishDrawing(sM);
			
			if ~ana.fixOnly; animate(stim); end
			getSample(eT);
			if ana.useTracker && ~isFixated(eT);fixated = 'breakfix'; break; end
			doBreak = checkKeys(); if doBreak; break; end
			
			vbl = flip(sM,vbl); tick = tick + 1;
			if tick==1 && ana.sendTrigger; lM.strobeServer(thisRun); end
			
			if ana.rewardDuring && tick == 60;rM.timedTTL(2,300);rewards=rewards+1;end
		end
		
		if ana.photoDiode; drawPhotoDiodeSquare(sM,[0 0 0]); end
		vbl=flip(sM);
		if ana.sendTrigger;lM.strobeServer(255); end
		tEnd = vbl;
		
		if strcmpi(fixated,'breakfix') || thisResponse == 0
			trackerMessage(eT,'ENDVBL',vbl);
			trackerMessage(eT,'TRIAL_RESULT -1');
			trackerMessage(eT,'MSG:BreakFix');
			if ~doBreak; incorrect(); end
		elseif strcmpi(fixated,'fix') || thisResponse == 1
			trackerMessage(eT,'ENDVBL',vbl);
			trackerMessage(eT,'TRIAL_RESULT 1');
			if ~doBreak; correct(); end
		elseif ~doBreak
			if ana.rewardEnd; rM.timedTTL(2,300); rewards=rewards+1;beep(sM.audio,'high'); end
			if ana.isVEP
				updateTask(seq,true,tEnd-tStart); %updates our current run number
				if seq.taskFinished;breakLoop = true;end
			end
			if ana.sendTrigger;lM.strobeServer(250); end
			WaitSecs('YieldSecs',ana.ITI);
			if ana.photoDiode; drawPhotoDiodeSquare(sM,[0 0 0]); end
			flip(sM);
		end
		sM.audio.loadSamples();
		updatePlots();
		%save this run info to structure
		if ana.isVEP
			ana.trial(seq.totalRuns).n = seq.totalRuns;
			ana.trial(seq.totalRuns).variable = seq.outIndex(seq.totalRuns);
			ana.trial(seq.totalRuns).result = thisResponse;
			ana.trial(seq.totalRuns).rewards = rewards;
			ana.trial(seq.totalRuns).positive = pfeedback;
			ana.trial(seq.totalRuns).negative = nfeedback;
			ana.trial(seq.totalRuns).tStart = tStart;
			ana.trial(seq.totalRuns).tEnd = tEnd;
			ana.trial(seq.totalRuns).tick = tick;
		else
			ana.trial(thisRun).result = thisResponse;
			ana.trial(thisRun).rewards = rewards;
			ana.trial(thisRun).positive = pfeedback;
			ana.trial(thisRun).negative = nfeedback;
			ana.trial(thisRun).tStart = tStart;
			ana.trial(thisRun).tEnd = tEnd;
			ana.trial(thisRun).tick = tick;
		end
	end %=====================================while ~breakLoop
	
	%===============================Clean up============================
	fprintf('===>>> basicTraining Finished Trials: %i\n',thisRun);
	Screen('DrawText', sM.win, '===>>> FINISHED!!!');
	Screen('Flip',sM.win);
	if ana.sendTrigger
		sd = ana.timeExp;
		sd(1)=20;
		for i = 1:3;lM.strobeServer(255);WaitSecs(0.02); end
		for i = 1:length(sd);lM.strobeServer(sd(i));WaitSecs(0.02);end
	end
	WaitSecs('YieldSecs', 0.25);
	stopRecording(eT);
	saveData(eT,false);
	close(sM);
	
	if exist(ana.ResultDir,'dir') > 0
		cd(ana.ResultDir);
	end
	
	if ~isempty(ana.nameExp) || ~strcmpi(ana.nameExp,'debug')
		ana.plotAxis1 = [];
		ana.plotAxis2 = [];
		fprintf('==>> SAVE %s, to: %s\n', ana.nameExp, pwd);
		save([ana.nameExp '.mat'],'ana','eT','sM','seq');
		assignin('base','ana',ana)
		assignin('base','seq',seq)
	end
	
	ListenChar(0);ShowCursor;Priority(0);
	clear ana seq eT sM tL cM
	
catch ME
	getReport(ME)
	assignin('base','ana',ana)
	if exist('sM','var'); close(sM); end
	ListenChar(0);ShowCursor;Priority(0);Screen('CloseAll');
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
					breakLoop = true;
					doBreak = true;
				case {'p'}
					fprintf('===>>> PAUSED!\n');
					Screen('DrawText', sM.win, '===>>> PAUSED, press key to resume!!!',10,10);
					flip(sM);
					WaitSecs('Yieldsecs',0.1);
					KbWait(-1);
					doBreak = true;
				case {'c'}
					WaitSecs('YieldSecs',0.1);
					fprintf('--->>> Entering calibration mode...\n');
					trackerSetup(eT,eT.calibration);
					doBreak = true;
				case {'1','1!','kp_end'}
					if kTimer < vbl
						kTimer = vbl + 0.2;
						rM.timedTTL(2,300);
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

	function updatePlots()
		b = bar(ana.plotAxis1, rewards);
		b.Parent.XTickLabel = {''};
		b = bar(ana.plotAxis2, [1 2], [pfeedback nfeedback]);
		title(ana.plotAxis2,sprintf('Responses [correct rate = %.2f]',...
			(1/((pfeedback+nfeedback)/pfeedback))*100));
		b.Parent.XTickLabel = {'positive','negative'};
		drawnow;
	end

	function correct()
		if ana.rewardEnd; rM.timedTTL(2,300); rewards=rewards+1; end
		fprintf('===>>> Correct given, ITI=%.2f!\n',ana.ITI);
		beep(sM.audio,'high');
		WaitSecs(0.02);if ana.sendTrigger;lM.strobeServer(250); end
		drawGreenSpot(sM,5);
		if ana.photoDiode; drawPhotoDiodeSquare(sM,[0 0 0]); end
		vbl=flip(sM); ct = vbl;
		cloop=1;
		while vbl <= ct + ana.ITI
			if cloop<60; drawGreenSpot(sM,5); end
			if ana.photoDiode; drawPhotoDiodeSquare(sM,[0 0 0]); end
			vbl=flip(sM); cloop=cloop+1;
			doBreak = checkKeys();
			if doBreak; break; end
		end
		if ana.photoDiode; drawPhotoDiodeSquare(sM,[0 0 0]); end
		vbl=flip(sM);
		thisResponse = 1;
		pfeedback = pfeedback + 1;
		if ana.isVEP
			updateTask(seq,true,tEnd-tStart); %updates our current run number
			if seq.taskFinished; breakLoop = true; end
		end
	end

	function incorrect()
		fprintf('===>>> Incorrect given, timeout=%.2f!\n',ana.timeOut);
		beep(sM.audio,'low');
		WaitSecs(0.02);if ana.sendTrigger;lM.strobeServer(251); end
		drawRedSpot(sM,5);
		if ana.photoDiode; drawPhotoDiodeSquare(sM,[0 0 0]); end
		vbl=flip(sM); ct = vbl;
		cloop=1;
		while vbl <= ct + ana.timeOut
			if cloop<60; drawRedSpot(sM,5); end
			if ana.photoDiode; drawPhotoDiodeSquare(sM,[0 0 0]); end
			vbl=flip(sM);cloop=cloop+1;
			doBreak = checkKeys();
			if doBreak; break; end
		end
		if ana.photoDiode; drawPhotoDiodeSquare(sM,[0 0 0]); end
		vbl=flip(sM);
		thisResponse = 0;
		nfeedback = nfeedback + 1;
	end

end
