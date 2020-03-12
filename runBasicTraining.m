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
    if ismac; sM.disableSyncTests = true; end
	sM.pixelsPerCm = ana.pixelsPerCm;
	sM.distance = ana.distance;
	sM.blend = 1;
	sM.verbosityLevel = 3;
	sM.open; % OPEN THE SCREEN
	fprintf('\n--->>> BasicTraining Opened Screen %i : %s\n', sM.win, sM.fullName);
	
	if IsLinux
		Screen('Preference', 'TextRenderer', 1);
		Screen('Preference', 'DefaultFontName', 'DejaVu Sans');
	end
	
	ad = audioManager(); ad.close();
	if IsLinux
		ad.device = [];
	elseif IsWin 
		ad.device = [];
	end
	ad.setup();
	
	%===========================tobii manager=====================
	t						= tobiiManager();
	t.name					= 'Tobii Demo';
    t.model                 = ana.tracker;
	t.trackingMode			= ana.trackingMode;
	t.eyeUsed				= 'both';
	t.sampleRate			= ana.sampleRate;
	t.calibrationStimulus	= ana.calStim;
	t.calPositions			= ana.calPos;
	t.valPositions			= ana.valPos;
	t.autoPace				= 0;
	if ~ana.useTracker
		t.isDummy = true;
	end
	
	if length(Screen('Screens')) > 1 && ~t.isDummy % ---- second screen for calibration
		s			= screenManager;
		s.screen	= sM.screen - 1;
		s.backgroundColour = bgColour;
		s.windowed	= [0 0 1500 1050];
		s.bitDepth	= '8bit';
		s.blend		= sM.blend;
		s.disableSyncTests = true;
	end
	
	if exist('s','var')
		initialise(t,sM,s);
	else
		initialise(t,sM);
	end
	t.settings.cal.paceDuration = 0.5;
	t.settings.cal.doRandomPointOrder  = false;
	trackerSetup(t); ShowCursor();
	drawnow;
    
	% ---- fixation values.
	t.resetFixation();
    t.fixation.X            = 0;
    t.fixation.Y            = 0;
	t.fixation.initTime		= ana.initTime;
	t.fixation.fixTime		= ana.fixTime;
	t.fixation.radius       = ana.radius;
	t.fixation.strict		= ana.strict;
	
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
	breakLoop		= false;
	ana.trial		= struct();
	totalRuns		= 0;
	rewards			= 0;
	pfeedback		= 0;
	nfeedback		= 0;
    
    halfisi			= sM.screenVals.halfisi;
	Priority(MaxPriority(sM.win));
	
	while ~breakLoop
		%=========================MAINTAIN INITIAL FIXATION==========================
		totalRuns = totalRuns + 1;
		
		if ana.randomPosition
			thisPos = pos(randi(length(pos)),:);
		else
			thisPos = [0, 0];
		end
		stim.xPositionOut = thisPos(1);
		stim.yPositionOut = thisPos(2);
		update(stim);
		
		t.resetFixation();
		t.fixation.X = thisPos(1);
		t.fixation.Y = thisPos(2);
		
		fprintf('===>>> BasicTraining START Run = %i | %s | pos = %i %i\n', totalRuns, sM.fullName,thisPos(1),thisPos(2));
		
		sM.drawCross([],[],thisPos(1),thisPos(2));
		flip(sM);
		WaitSecs(0.5);
		
		tick = 0;
		kTimer = 0; % this is the timer to stop too many key events
		thisResponse = -1;
		ListenChar(-1);
		sM.drawCross([],[],thisPos(1),thisPos(2));
		tStart = flip(sM); vbl = tStart;
		if ana.rewardStart; rM.timedTTL(2,300); rewards=rewards+1; end
		play(ad);
		
		while vbl < tStart + ana.playTimes
			draw(stim);
			sM.drawCross(0.4,[0.5 0.5 0.5],thisPos(1),thisPos(2))
			drawEyePosition(t);
			finishDrawing(sM);
            vbl = flip(sM,vbl); tick = tick + 1;
			getSample(t);
			doBreak = checkKeys();
			if doBreak; break; end
			if ana.rewardDuring && tick == 60;rM.timedTTL(2,300);rewards=rewards+1;end
			
		end
		
		tEnd = vbl;
		if ana.rewardEnd; rM.timedTTL(2,300); rewards=rewards+1; end
		vbl=flip(sM); tTemp = vbl;
		
		%inter trial interval
		while vbl < tTemp + 1
			
			vbl=flip(sM);
			doBreak = checkKeys();
			if doBreak; break; end
			
		end
		
		ListenChar(0);
		updatePlots();
		ad.loadSamples();
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
	clear ana seq eL sM tL cM

catch ME
    flip(sM);
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
					fprintf('===>>> Correct given!\n');
					drawGreenSpot(sM,5);
					flip(sM);
					thisResponse = 1;
					rM.timedTTL(2,300); beep(ad,'high');
					WaitSecs('YieldSecs',0.5);
					doBreak = true;
					pfeedback = pfeedback + 1;
				case {'3','3#','kp_next'}
					fprintf('===>>> Incorrect given!\n');
					drawRedSpot(sM,5);
					flip(sM);
					thisResponse = 0;
					beep(ad,'low');
					WaitSecs('YieldSecs',5);
					doBreak = true;
					nfeedback = nfeedback + 1;
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
		
end
