function tobiidemo()

	global rM
	if ~exist('rM','var') || isempty(rM)
		 rM = arduinoManager;
	end
	open(rM) %open our reward manager

	bgColour = [0.25 0.25 0.25 1];
	screen = max(Screen('Screens'));
	windowed=[];
	
	rewardAtStart		= true;
	rewardAtEnd			= true;
	pin					= 2;
	ttlTime				= 300;

	% ---- screenManager
	sM = screenManager('backgroundColour',bgColour,'screen',screen,'windowed',windowed);
	sM.bitDepth		= '8bit';
	sM.blend		= true;
	sv				= sM.open();
	sM.audio		= audioManager();
	ad				= sM.audio;
	if IsWin; ad.device = 6; end
	ad.setup();
	% ---- second screen for calibration
	if length(Screen('Screens')) > 1
		s			= screenManager;
		s.screen	= sM.screen - 1;
		s.backgroundColour = bgColour;
		s.windowed	= [0 0 1500 1050];
		s.bitDepth	= '8bit';
		s.blend		= true;
		s.disableSyncTests = true;
	end
	
	% ---- setup our image deck.
	i=imageStimulus;
	i.fileName		= '/home/cog5/Documents/Monkey-Pictures/';
	
	% ---- setup movie we can use for fixation spot.
	f				= movieStimulus;
	f.size			= 2;
	
	% ---- our metastimulus combines both together
	m				= metaStimulus;
	m.stimuli{1}	= i;
	m.stimuli{2}	= f;
	setup(m,sM);
	show(m);
	m.stimuli{2}.hide();

	% ---- tobii manager
	t						= tobiiManager();
	t.name					= 'Tobii Demo';
	t.trackingMode			= 'macaque';
	t.eyeUsed				= 'both';
	t.sampleRate			= 60;
	t.calibrationStimulus	= 'movie';
	t.calPositions			= [0.2 0.5; 0.5 0.5; 0.8 0.5];
	t.valPositions			= [0.5 0.5];
	t.autoPace				= 0;
	if exist('s','var')
		initialise(t,sM,s);
	else
		initialise(t,sM);
	end
	t.settings.cal.paceDuration = 0.8;
	t.settings.cal.doRandomPointOrder  = false;
	trackerSetup(t); ShowCursor();
	if s.isOpen; close(s); end
	
	% ---- prepare tracker
	WaitSecs('YieldSecs',0.5);
	Priority(MaxPriority(sM.win)); %bump our priority to maximum allowed
	startRecording(t); WaitSecs('YieldSecs',0.5);
	trackerMessage(t,'!!! Starting Demo...')
	
	% ---- prepare variables
	breakLoop	= false;
	totalRuns	= 0;
	
	while ~breakLoop
		totalRuns = totalRuns + 1;
		fprintf('===>>> BasicTraining START Run = %i | %s\n', totalRuns, sM.fullName);
		tick = 0;
		kTimer = 0; % this is the timer to stop too many key events
		%ListenChar(-1);
		ad.play();
		if rewardAtStart; rM.timedTTL(pin,ttlTime); end
		vbl = flip(sM); startT = vbl;
		while vbl < startT + 4
			draw(m);
			getSample(t);
			drawEyePosition(t);
			finishDrawing(sM);
			animate(m);
			vbl = sM.flip(vbl); tick = tick + 1;
			if tick == 1; trackerMessage(t,'STARTVBL',vbl); end
			doBreak = checkKeys();
			if doBreak; break; end
		end 
		if rewardAtEnd; rM.timedTTL(pin,ttlTime); end
		
		vbl=flip(sM); startT = vbl;
		trackerMessage(t,'ENDVBL',vbl);
		while vbl < startT + 1
			vbl=flip(sM);
			doBreak = checkKeys();
			if doBreak; break; end
		end
		
		ad.loadSamples();
		update(m);
		
	end

	sM.flip();
	stopRecording(t);
	WaitSecs('Yieldsecs',0.5)
	ListenChar(0); Priority(0); ShowCursor;
	reset(m);
	saveData(t);
	close(t); close(sM);
	
	function doBreak = checkKeys()
		doBreak = false;
		[keyIsDown, ~, keyCode] = KbCheck(-1);
		if keyIsDown == 1
			rchar = KbName(keyCode);
			switch lower(rchar)
				case {'q','0'}
					breakLoop = true;
					doBreak = true;
				case {'p'}
					WaitSecs('YieldSecs',0.1);
					KbWait(-1);
					doBreak = true;
				case {'1','1!','kp_end'}
					if kTimer < vbl
						kTimer = vbl + 0.2;
						rM.timedTTL(2,300);
					end
			end
		end
	end
end

