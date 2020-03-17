function runBasicTraining(ana)

global rM

if ~exist('rM','var') || isempty(rM)
	rM = arduinoManager();
end
open(rM) %open our reward manager

fprintf('\n--->>> runBasicTraining Started: ana UUID = %s!\n',ana.uuid);

%===================Initiate out metadata===================
ana.date = datestr(datetime);
ana.version = Screen('Version');
ana.computer = Screen('Computer');

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
	sM = screenManager();
	sM.screen = ana.screenID;
	if ismac || ispc; sM.disableSyncTests = true; end
	sM.pixelsPerCm = ana.pixelsPerCm;
	sM.distance = ana.distance;
	sM.blend = 1;
	sM.verbosityLevel = 3;
	sM.open; % OPEN THE SCREEN
	fprintf('\n--->>> BasicTraining Opened Screen %i : %s\n', sM.win, sM.fullName);
	
	if IsLinux
		Screen('Preference', 'TextRenderer', 1);
		Screen('Preference', 'DefaultFontName', 'Liberation Sans');
	end
	
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
		assignin('base','cal',cal); 
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
		stim = movieStimulus();
		stim.size = ana.size;
		stim.setup(sM);
	else
		stim = imageStimulus();
		stim.size = ana.size;
		stim.fileName = ana.imageDir;
		stim.setup(sM);
	end
	
	pos = ana.positions;
	
	%===========================prepare===========================
	Priority(MaxPriority(sM.win)); %bump our priority to maximum allowed
	startRecording(eT); WaitSecs('YieldSecs',1);
	trackerMessage(eT,'!!! Starting Demo...')
	breakLoop		= false;
	ana.trial		= struct();
	totalRuns		= 0;
	rewards			= 0;
	pfeedback		= 0;
	nfeedback		= 0;
	
	while ~breakLoop
		%=========================TRIAL SETUP==========================
		totalRuns = totalRuns + 1;
		
		if ana.randomPosition
			thisPos = pos(randi(length(pos)),:);
		else
			thisPos = [0, 0];
		end
		stim.xPositionOut = thisPos(1);
		stim.yPositionOut = thisPos(2);
		update(stim);
		
		eT.resetFixation();
		eT.fixation.X = thisPos(1);
		eT.fixation.Y = thisPos(2);
		
		fprintf('\n===>>> BasicTraining START Run = %i | %s | pos = %i %i\n', totalRuns, sM.fullName,thisPos(1),thisPos(2));
		ListenChar(-1);
		WaitSecs(0.1);
		
		%=====================INITIATE FIXATION
		trackerMessage(eT,['TRIALID' num2str(totalRuns)]);
		trackerMessage(eT,'INITIATEFIX');
		fixated = ''; doBreak = false;
		if ana.useTracker
			while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
				drawCross(sM,1,[],thisPos(1),thisPos(2));
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
				fprintf('===>>> BROKE INITIATE FIXATION Trial = %i\n', totalRuns);
				trackerMessage(eT,'TRIAL_RESULT -100');
				trackerMessage(eT,'MSG:BreakInitialFix');
				Screen('Flip',sM.win); %flip the buffer
				WaitSecs('YieldSecs',0.5);
				continue
			end
		else
			drawCross(sM,1,[],thisPos(1),thisPos(2));
			finishDrawing(sM);
			flip(sM);
			WaitSecs(0.5);
		end
		
		%=====================SHOW STIMULUS
		tick = 0;
		kTimer = 0; % this is the timer to stop too many key events
		thisResponse = -1; doBreak = false;
		sM.drawCross(1,[],thisPos(1),thisPos(2));
		tStart = flip(sM); vbl = tStart;
		if ana.rewardStart; rM.timedTTL(2,300); rewards=rewards+1; end
		play(sM.audio);
		while vbl < tStart + ana.playTimes
			draw(stim);
			sM.drawCross(0.4,[0.5 0.5 0.5],thisPos(1),thisPos(2));
			if ana.drawEye; drawEyePosition(eT,true); end
			finishDrawing(sM);
			vbl = flip(sM,vbl); tick = tick + 1;
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
			if ana.rewardEnd; rM.timedTTL(2,300); beep(sM.audio,'high'); end
			WaitSecs('YieldSecs',1);
			flip(sM);
		end
		ListenChar(0);
		updatePlots();
		sM.audio.loadSamples();
		ana.trial(totalRuns).result = thisResponse;
		ana.trial(totalRuns).rewards = rewards;
		ana.trial(totalRuns).positive = pfeedback;
		ana.trial(totalRuns).negative = nfeedback;
		ana.trial(totalRuns).tStart = tStart;
		ana.trial(totalRuns).tEnd = tEnd;
		ana.trial(totalRuns).tick = tick;
	end %=====================================while ~breakLoop
	
	%===============================Clean up============================
	fprintf('===>>> basicTraining Finished Trials: %i\n',totalRuns);
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
		save([ana.nameExp '.mat'],'ana');
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
				case {'1','1!','kp_end'}
					if kTimer < vbl
						kTimer = vbl + 0.2;
						rM.timedTTL(2,300);
						rewards = rewards + 1;
					end
				case {'2','2@','kp_down'}
					correct();
				case {'3','3#','kp_next'}
					incorrect();
			end
		end
	end

	function updatePlots()
		b = bar(ana.plotAxis1, rewards);
		b.Parent.XTickLabel = {''};
		b = bar(ana.plotAxis2, [1 2], [pfeedback nfeedback]);
		b.Parent.XTickLabel = {'positive','negative'};
		drawnow;
	end

	function correct()
		fprintf('===>>> Correct given!\n');
		drawGreenSpot(sM,5);
		flip(sM);
		thisResponse = 1;
		if ana.rewardEnd; rM.timedTTL(2,300); beep(sM.audio,'high'); end
		WaitSecs('YieldSecs',0.5);
		flip(sM);
		WaitSecs('YieldSecs',0.25);
		doBreak = true;
		pfeedback = pfeedback + 1;
	end

	function incorrect()
		fprintf('===>>> Incorrect given!\n');
		drawRedSpot(sM,5);
		flip(sM);
		thisResponse = 0;
		beep(sM.audio,'low');
		WaitSecs('YieldSecs',3.5);
		flip(sM);
		WaitSecs('YieldSecs',1.5);
		doBreak = true;
		nfeedback = nfeedback + 1;
	end

end
