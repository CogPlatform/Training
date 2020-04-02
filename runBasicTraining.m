function runBasicTraining(ana)

global lM
if ~exist('lM','var') || isempty(lM) || ~isa(lM,'labJackT')
	 lM = labJackT('openNow',false);
end
if ~ana.sendTrigger; lM.silentMode = true; end
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
pf='basicTrain_';
if ~isempty(ana.subject)
	nameExp = [pf ana.subject];
	c = sprintf(' %i',fix(clock()));
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
	Screen('Preference', 'SkipSyncTests', 1);
	%===================open our screen====================
	sM						= screenManager();
	sM.screen				= ana.screenID;
	if ana.debug || ismac || ispc || ~isempty(regexpi(ana.gpu.Vendor,'NVIDIA','ONCE'))
		sM.disableSyncTests = true; 
	end
	if ana.debug
		sM.windowed			= [0 0 1400 1000]; sM.debug = true; sM.visualDebug = true;
	end
	sM.backgroundColour		= ana.backgroundColour;
	sM.pixelsPerCm			= ana.pixelsPerCm;
	sM.distance				= ana.distance;
	sM.blend				= 1;
	sM.verbosityLevel		= 3;
	sM.open; % OPEN THE SCREEN
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
	eT						= tobiiManager();
	eT.name					= 'Tobii Demo';
	eT.model                = ana.tracker;
	eT.trackingMode			= ana.trackingMode;
	eT.eyeUsed				= 'both';
	eT.sampleRate			= ana.sampleRate;
	eT.calibrationStimulus	= ana.calStim;
	eT.calPositions			= ana.calPos;
	eT.valPositions			= ana.valPos;
	eT.autoPace				= ana.autoPace;
	if ~ana.isDummy; eT.verbose	= true; end
	if ~ana.useTracker || ana.isDummy
		eT.isDummy = true;
	end
	if length(Screen('Screens')) > 1 && ~eT.isDummy % ---- second screen for calibration
		s					= screenManager;
		s.screen			= sM.screen - 1;
		s.backgroundColour	= sM.backgroundColour;
		s.windowed			= [];
		s.bitDepth			= '8bit';
		s.blend				= sM.blend;
		s.disableSyncTests	= true;
	end
	if exist('s','var')
		initialise(eT,sM,s);
	else
		initialise(eT,sM);
	end
	eT.settings.cal.paceDuration = ana.paceDuration;
	eT.settings.cal.doRandomPointOrder  = false;
	ana.cal=[];
	cal = trackerSetup(eT, ana.cal); ShowCursor();
	if ~isempty('cal')
		cal.comment='tobii demo calibration';
		assignin('base','cal',cal); %put our calibration ready to save manually
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
		stim								= metaStimulus();
		stim.stimuli{1}						= barStimulus();
		stim.stimuli{1}.barWidth			= ceil(sM.screenVals.width / sM.pixelsPerCm);
		stim.stimuli{1}.barHeight			= ceil(sM.screenVals.height / sM.pixelsPerCm);
		stim.stimuli{1}.type				= 'checkerboard';
		stim.stimuli{1}.contrast			= ana.VEPContrast(end);
		stim.stimuli{1}.phaseReverseTime	= 0.3;
		stim.stimuli{1}.checkSize			= ana.VEPSF(2);
		stim.stimuli{2}						= discStimulus();
		stim.stimuli{2}.size				= 2.5;
		stim.stimuli{2}.colour				= ana.backgroundColour;
		stim.setup(sM);
		ana.fixOnly			= false;
		ana.moveStim		= false;
		ana.isVEP			= true;
		seq					= stimulusSequence();
		seq.nBlocks			= ana.nBlocks;
		seq.nVar(1).name	= 'sf';
		seq.nVar(1).values	= linspace(ana.VEPSF(1),ana.VEPSF(2),ana.VEPSF(3));
		seq.nVar(1).stimulus = 1;
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
	startRecording(eT); WaitSecs('YieldSecs',1);
	trackerMessage(eT,'!!! Starting Demo...')
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
			stim.stimuli{1}.checkSizeOut = seq.outValues{seq.totalRuns};
			fprintf('\n===>>> BasicTraining START Run = %i:%i | %s | checkSize = %.2f\n', thisRun, seq.totalRuns, sM.fullName,stim.stimuli{1}.checkSizeOut);
		end
		
		if ~ana.fixOnly
			update(stim); 
		end
		
		eT.resetFixation();
		
		if ~ana.debug;ListenChar(-1);end
		
		%=====================INITIATE FIXATION
		if ana.isVEP
			thisRun = seq.outIndex(seq.totalRuns);
			trackerMessage(eT,['TRIALID ' num2str(thisRun)]);
		else
			trackerMessage(eT,['TRIALID' num2str(thisRun)]);
		end
		trackerMessage(eT,'INITIATEFIX');
		fixated = ''; doBreak = false;
		if ana.useTracker
			while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
				drawCross(sM,ana.spotSize,[],thisPos(1),thisPos(2));
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
				Screen('Flip',sM.win); %flip the buffer
				WaitSecs('YieldSecs',0.5);
				continue
			end
		else
			drawCross(sM,ana.spotSize,[],thisPos(1),thisPos(2));
			finishDrawing(sM);
			flip(sM);
			WaitSecs(0.5);
		end
		
		%=====================SHOW STIMULUS
		tick = 0;
		kTimer = 0; % this is the timer to stop too many key events
		thisResponse = -1; doBreak = false;
		drawCross(sM,ana.spotSize,[],thisPos(1),thisPos(2));
		tStart = flip(sM); vbl = tStart;
		if ana.sendTrigger;lM.strobeServer(1); end
		if ana.rewardStart; rM.timedTTL(2,300); rewards=rewards+1; end
		play(sM.audio);
		while vbl < tStart + ana.playTimes
			if ana.fixOnly
				drawCross(sM,ana.size,[],thisPos(1),thisPos(2));
			else
				draw(stim);
				if ana.isVEP
					sM.drawCross(ana.spotSize,[],thisPos(1),thisPos(2));
				else
					sM.drawCross(0.4,[0.5 0.5 0.5],thisPos(1),thisPos(2));
				end
			end
			if ana.drawEye; drawEyePosition(eT,true); end
			finishDrawing(sM);
			vbl = flip(sM,vbl); tick = tick + 1;
			animate(stim);
			getSample(eT);
			if ana.useTracker && ~isFixated(eT)
				fixated = 'breakfix';
				break %break the while loop	
			end
			doBreak = checkKeys();
			if doBreak; break; end
			if ana.rewardDuring && tick == 60;rM.timedTTL(2,300);rewards=rewards+1;end
		end
		
		vbl=flip(sM); tEnd = vbl;
		if ana.sendTrigger;lM.strobeServer(255); end
		
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
			WaitSecs('YieldSecs',ana.ITI);
			flip(sM);
		end
		ListenChar(0);
		updatePlots();
		sM.audio.loadSamples();
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
	WaitSecs('YieldSecs', 1);
	close(sM);
	
	if exist(ana.ResultDir,'dir') > 0
		cd(ana.ResultDir);
	end
	
	if ~isempty(ana.nameExp) || ~strcmpi(ana.nameExp,'debug')
		ana.plotAxis1 = [];
		ana.plotAxis2 = [];
		fprintf('==>> SAVE %s, to: %s\n', ana.nameExp, pwd);
		save([ana.nameExp '.mat'],'ana','seq');
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
		if ana.sendTrigger;lM.strobeServer(250); end
		if ana.rewardEnd; rM.timedTTL(2,300); rewards=rewards+1;beep(sM.audio,'high'); end
		fprintf('===>>> Correct given, ITI=%.2f!\n',ana.ITI);
		drawGreenSpot(sM,5);
		vbl=flip(sM); ct = vbl;
		cloop=1;
		while vbl <= ct + ana.ITI
			if cloop<60; drawGreenSpot(sM,5); end
			vbl=flip(sM); cloop=cloop+1;
			doBreak = checkKeys();
			if doBreak; break; end
		end
		vbl=flip(sM);
		thisResponse = 1;
		pfeedback = pfeedback + 1;
		if ana.isVEP
			updateTask(seq,true,tEnd-tStart); %updates our current run number
			if seq.taskFinished; breakLoop = true; end
		end
	end

	function incorrect()
		if ana.sendTrigger;lM.strobeServer(251); end
		fprintf('===>>> Incorrect given, timeout=%.2f!\n',ana.timeOut);
		beep(sM.audio,'low');
		drawRedSpot(sM,5);
		vbl=flip(sM); ct = vbl;
		cloop=1;
		while vbl <= ct + ana.timeOut
			if cloop<60; drawRedSpot(sM,5); end
			vbl=flip(sM);cloop=cloop+1;
			doBreak = checkKeys();
			if doBreak; break; end
		end
		vbl=flip(sM);
		thisResponse = 0;
		nfeedback = nfeedback + 1;
	end

end
