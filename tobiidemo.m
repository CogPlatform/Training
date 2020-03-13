function tobiidemo()

global rM
if ~exist('rM','var') || isempty(rM)
	rM = arduinoManager;
end
open(rM) %open our reward manager

bgColour				= [0.25 0.25 0.25 1];
screen				= max(Screen('Screens'));
windowed				= [0 0 1000 1000];
pin					= 2;
ttlTime				= 300;
trialTime			= 2;

% ---- screenManager
sM = screenManager('backgroundColour',bgColour,'screen',screen,'windowed',windowed);
sM.bitDepth				= '8bit';
sM.blend					= true;
sM.disableSyncTests	=true;
sv							= sM.open();
sM.audio					= audioManager('device',[]); ad	= sM.audio; ad.setup();
%if IsWin; ad.device = 6; end
if length(Screen('Screens')) > 1 % ---- second screen for calibration
	s					= screenManager;
	s.screen			= sM.screen - 1;
	s.backgroundColour = bgColour;
	s.windowed		= [0 0 1500 1050];
	s.bitDepth		= '8bit';
	s.blend			= sM.blend;
	s.disableSyncTests = true;
end

% ---- tobii manager
eT						= tobiiManager();
eT.name				= 'Tobii Demo';
eT.isDummy			= true;
eT.model           = 'Tobii TX300'; %'Tobii Pro Spectrum'
if ~isempty(regexpi(eT.trackingMode,'Spectrum','ONCE'))
	eT.trackingMode	= 'human';
else
	eT.trackingMode	= 'Default';
end
eT.eyeUsed			= 'both';
eT.sampleRate		= 300;
eT.calibrationStimulus	= 'animated';
eT.calPositions		= [0.2 0.5; 0.5 0.5; 0.8 0.5];
eT.valPositions		= [0.5 0.5];
eT.autoPace			= 0;
if exist('s','var')
	initialise(eT,sM,s);
else
	initialise(eT,sM);
end
eT.settings.cal.paceDuration = 0.5;
eT.settings.cal.doRandomPointOrder  = false;
trackerSetup(eT); ShowCursor();
drawnow;

% ---- fixation values.
eT.resetFixation();
eT.fixation.X            = 0;
eT.fixation.Y            = 0;
eT.fixation.initTime		= 1;
eT.fixation.fixTime		= 1;
eT.fixation.radius       = 10;

% ---- setup our image deck.
i=imageStimulus;
i.fileName		= [sM.paths.parent pathsep 'Pictures/'];
i.size			= 10;

% ---- setup movie we can use for fixation spot.
f					= movieStimulus;
f.size			= 2;

% ---- our metastimulus combines both together
stim				= metaStimulus;
stim.stimuli{1}	= i;
stim.stimuli{2}	= f;
setup(stim,sM);
show(stim);
stim.stimuli{2}.hide();

pos = [-10 -10; -10 0; 0 -10; 0 0; 10 0; 0 10; 10 10];

% ---- prepare tracker
WaitSecs('YieldSecs',0.5);
Priority(MaxPriority(sM.win)); %bump our priority to maximum allowed
startRecording(eT); WaitSecs('YieldSecs',0.5);
trackerMessage(eT,'!!! Starting Demo...')

% ---- prepare variables
breakLoop	= false;
totalRuns	= 0;

while ~breakLoop
	totalRuns = totalRuns + 1;
	
	thisPos = pos(randi(length(pos)),:);
	i.xPositionOut = thisPos(1);
	i.yPositionOut = thisPos(2);
	update(stim);
	
	eT.resetFixation();
	eT.fixation.X = thisPos(1);
	eT.fixation.Y = thisPos(2);
	
	fprintf('===>>> tobiidemo START Run = %i | %s | pos = %i %i\n', totalRuns, sM.fullName,thisPos(1),thisPos(2));
	
	kTimer = 0; % this is the timer to stop too many key events
	
	%=====================INITIATE FIXATION
	%ListenChar(-1);
	trackerMessage(eT,['TRIALID' num2str(totalRuns)]);
	trackerMessage(eT,'INITIATEFIX');
	fixated = '';
	while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
		drawCross(sM,[],[],thisPos(1),thisPos(2));
		finishDrawing(sM);
		flip(sM);
		getSample(eT);
		fixated=testSearchHoldFixation(eL,'fix','breakfix');
		doBreak = checkKeys();
		if doBreak; break; end
	end
	if strcmpi(fixated,'breakfix')
		fprintf('===>>> BROKE INITIATE FIXATION Trial = %i\n', totalRuns);
		trackerMessage(eT,'TRIAL_RESULT -100');
		trackerMessage(eT,'MSG:BreakInitialFix');
		resetFixation(eT);
		Screen('Flip',sM.win); %flip the buffer
		WaitSecs('YieldSecs',0.2);
		continue
	end
	
	%=====================SHOW STIMULUS
	
	if rewardAtStart; rM.timedTTL(pin,ttlTime); end
	ad.play();
	vbl = flip(sM); startT = vbl + sv.ifi; tick = 1;
	while vbl < startT + trialTime
		draw(stim);
		getSample(eT);
		drawEyePosition(eT);
		finishDrawing(sM);
		animate(stim);
		vbl = sM.flip(vbl); tick = tick + 1;
		if tick == 1; trackerMessage(eT,'STARTVBL',vbl); end
		getSample(eT);
		if ~isFixated(eT)
			fixated = 'breakfix';
			break %break the while loop
		end
		doBreak = checkKeys();
		if doBreak; break; end
	end
	
	if strcmpi(fixated,'breakfix')
		drawRedSpot(sM,5);
		vbl=flip(sM); endT = vbl;
		trackerMessage(eT,'ENDVBL',vbl);
		trackerMessage(eL,'TRIAL_RESULT -1');
		trackerMessage(eL,'MSG:BreakFix');
		beep(ad,'low');
		while vbl < endT + 5
			drawGreenSpot(sM,5);
			vbl=flip(sM);
			doBreak = checkKeys();
			if doBreak; break; end
		end
	else
		drawGreenSpot(sM,5);
		vbl=flip(sM); endT = vbl;
		if rewardAtEnd; rM.timedTTL(pin,ttlTime); end
		beep(ad,'high');
		trackerMessage(eT,'ENDVBL',vbl);
		trackerMessage(eT,'TRIAL_RESULT 1');
		while vbl < endT + 1
			drawGreenSpot(sM,5);
			vbl=flip(sM);
			doBreak = checkKeys();
			if doBreak; break; end
		end
	end
	
	ad.loadSamples();
	
end

sM.flip();
stopRecording(eT);
WaitSecs('Yieldsecs',0.5)
ListenChar(0); Priority(0); ShowCursor;
reset(stim);
saveData(eT);
close(eT); close(sM);

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
					fprintf('--->>> Entering paused mode...\n');
					Screen('DrawText','--->>> PAUSED, key to exit...', 20,20,[1 1 1]);
					flip(sM);
					KbWait(-1);
					doBreak = true;
				case {'c'}
					WaitSecs('YieldSecs',0.1);
					fprintf('--->>> Entering calibration mode...\n');
					trackerSetup(eT);
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

