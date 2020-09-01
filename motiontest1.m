function motiontest1()

	screen = 1;
	screenSize = [];
	cycleTime = 2; % time for one sweep, determines max speed
	bgColour = 0.55;
	dotColour = [0 0 0]';
	dotSize = 0.5;
	nDots = 35;
	backlight = false;

	ptb = mySetup(screen,bgColour,screenSize);

	% ---- setup dot motion path
	nSteps = floor(cycleTime * ptb.fps);
	xMod = sin(linspace(0,2*pi,nSteps));
	xShift = (xMod * (ptb.w/2));
	maxdelta = max(abs(diff(xShift)));
	mindelta = min(abs(diff(xShift)));
	fprintf('\nMAX SPEED = %.2f deg/sec @ %.2f FPS\n',(maxdelta/ptb.ppd) * ptb.fps, ptb.fps)
	yPos = linspace(0, ptb.h, nDots)-(ptb.h/2);
	xPos = repmat(xShift(1),1,length(yPos));
	xy = [xPos;yPos];

	% ---- prepare variables
	CloseWin = false;
	incB = KbName('rightarrow');
	decB = KbName('leftarrow');
	incD = KbName('uparrow');
	decD = KbName('downarrow');
	quit = KbName('escape');
	RestrictKeysForKbCheck([incB decB incD decD quit]);
	looper = 1;
	Priority(MaxPriority(ptb.win)); %bump our priority to maximum allowed
	vbl(1) = Screen('Flip', ptb.win);
	
	
	while ~CloseWin
		if backlight && mod(looper+1,2)
			Screen('FillRect',ptb.win,bgColour);
		else
			Screen('FillRect',ptb.win,bgColour);
			%Screen('DrawDots', winPtr, xy [,size] [,color] [,center] [,dot_type][, lenient]);
			Screen('DrawDots', ptb.win, xy, dotSize * ptb.ppd, dotColour, [ptb.w/2 ptb.h/2], 3, 1);
		end
		vbl(end+1) = Screen('Flip', ptb.win, vbl(end) + ptb.ifi/2);

		looper = looper + 1;
		if looper >= length(xShift); looper = 1; end
		xy(1,:) = repmat(xShift(looper),1,length(xPos));

		% ---- handle keyboard
		[~,~,keyCode] = KbCheck(-1);
		name = find(keyCode==1);
		if ~isempty(name)  
			switch name
				case incB
					bgColour = bgColour + 0.005;
					if bgColour(1) > 1
						bgColour = 0;
					end
					fprintf('bg = %.2g\n',bgColour)
				case decB
					bgColour = bgColour - 0.005;
					if bgColour(1) < 0
						bgColour = 1;
					end
					fprintf('bg = %.2g\n',bgColour)
				case incD
					dotColour = dotColour + 0.005;
					if dotColour(1) > 1
						dotColour = [0 0 0]';
					end
					fprintf('dc = %.2g\n',dotColour)
				case decD
					dotColour = dotColour - 0.005;
					if dotColour(1) < 0
						dotColour = [1 1 1]';
					end
					fprintf('dc = %.2g\n',dotColour)
				case quit
					CloseWin = true;
				otherwise
					disp('Cant match key!')
			end
		end
	end
	Screen('Flip',ptb.win);
	figure;plot(diff(vbl(3:end))*1e3);title(sprintf('VBL Times, should be ~%.2f ms',ptb.ifi*1e3));ylabel('Time (ms)');
end

function ptb = mySetup(screen, bgColour, ws)
	ptb.cleanup = onCleanup(@myCleanup);
	PsychDefaultSetup(2);
	KbName('UnifyKeyNames');
	Screen('Preference', 'SkipSyncTests', 0);
	Screen('Preference', 'Verbosity', 3);
	Screen('Preference','SyncTestSettings', 0.0008);
	if isempty(screen); screen = max(Screen('Screens')); end
	ptb.ScreenID = screen;
	PsychImaging('PrepareConfiguration');
	PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
	[ptb.win, ptb.winRect] = PsychImaging('OpenWindow', ptb.ScreenID, bgColour, ws, [], [], [], 1); 

	[ptb.w, ptb.h] = RectSize(ptb.winRect);
	screenWidth = 698; % mm
	viewDistance = 573; % mm
	ptb.ppd = ptb.w/2/atand(screenWidth/2/viewDistance);
	ptb.ifi = Screen('GetFlipInterval', ptb.win);
	ptb.fps = 1 / ptb.ifi;
	Screen('BlendFunction', ptb.win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	disp('Screen Settings: ');
	disp(ptb);
end

function myCleanup()
	disp('Clearing up...')
	Priority(0)
	sca
end