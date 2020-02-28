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
	
	ad = audioManager();ad.close();
	if IsLinux
		ad.device = [];
	elseif IsWin 
		ad.device = 6;
	end
	ad.setup();
	
	pos = [-16 -16; -16 0; 0 -16; 0 0; 16 0; 0 16; 16 16];
	
	%===========================set up stimuli====================
	mv = movieStimulus();
    mv.setup(sM);
	
	
	%===========================prepare===========================
	tL				= timeLogger();
	tL.screenLog.beforeDisplay = GetSecs();
	tL.screenLog.stimTime(1) = 1;
	breakLoop		= false;
	ana.trial		= struct();
	halfisi			= sM.screenVals.halfisi;
	Priority(MaxPriority(sM.win));
	totalRuns = 0;
	
	while ~breakLoop
		%=========================MAINTAIN INITIAL FIXATION==========================
		totalRuns = totalRuns + 1;
		fprintf('===>>> BasicTraining START Run = %i | %s\n', totalRuns, sM.fullName);
		
		thisPos = pos(randi(7),:);
		mv.xPositionOut = thisPos(1);
		mv.xPositionOut = thisPos(2);
		update(mv);
        
		tEnd=Screen('Flip',sM.win);
        ListenChar(-1);
		tick = 0;
		thisResponse = -1;
		tStart = flip(sM); vbl = tStart;
		if ana.rewardStart; rM.timedTTL(300,2); end
		play(ad);
		while vbl < tStart + ana.playTimes
			draw(mv); animate(mv);
			sM.drawCross([],[],0,0);
			finishDrawing(sM);
            vbl = flip(sM,vbl); tick = tick + 1;
			
			if ana.rewardDuring && tick == 60;rM.timedTTL(300,2);end
			
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode);
				switch lower(rchar)
					case {'q'}
						breakLoop = true;
						break;
					case {'1','1!','kp_end'}
						fprintf('===>>> reward given!\n');
						rM.timedTTL(300,2);
					case {'2','2@','kp_down'}
						fprintf('===>>> Correct given!\n');
						drawGreenSpot(sM,5);
						flip(sM);
						thisResponse = 1;
						rM.timedTTL(300,2); beep(ad,'high');
						break;
					case {'3','3#','kp_next'}
						fprintf('===>>> Incorrect given!\n');
						drawRedSpot(sM,5);
						flip(sM);
						thisResponse = 0;
						beep(ad,'low');
						WaitSecs('YieldSecs',5);
						break;
				end
			end
		end
		tEnd = vbl;
		if ana.rewardEnd; rM.timedTTL(300,2); end
		ana.trial(totalRuns).result = thisResponse;
		ana.trial(totalRuns).tStart = tStart;
		ana.trial(totalRuns).tEnd = tEnd;
		ana.trial(totalRuns).tick = tick;
		WaitSecs('YieldSecs',1);
		
		
	end % while ~breakLoop
	
	%===============================Clean up============================
	fprintf('===>>> basicTraining Finished Trials: %i\n',totalRuns);
	Screen('DrawText', sM.win, '===>>> FINISHED!!!');
	Screen('Flip',sM.win);
	WaitSecs('YieldSecs', 2);
	close(sM);
	ListenChar(0);ShowCursor;Priority(0);
	clear ana seq eL sM tL cM

catch ME
	assignin('base','ana',ana)
	if exist('eL','var'); close(eL); end
	if exist('sM','var'); close(sM); end
	ListenChar(0);ShowCursor;Priority(0);Screen('CloseAll');
	getReport(ME)
end
		
end
