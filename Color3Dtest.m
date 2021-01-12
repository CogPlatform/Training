function color3Dtest()

bgColour = [0.5 0.5 0.5];
screen = max(Screen('Screens'));
screenSize = [];

ptb = mySetup(screen,bgColour,screenSize);

resolution = [400 400];
phase = 0;
angle = 0;
sf = 0.5 / ptb.ppd; %1c/d
contrast = 0.75; 
sigma = -1; % >=0 become a square wave smoothed with sigma. <0 = sinewave grating.
radius = inf; %if radius > 0 then we create a circular aperture radius pixels wide

%keyboard
incR = KbName('r');
decR = KbName('t');
incG = KbName('g');
decG = KbName('h');
incB = KbName('b');
decB = KbName('n');
quit = KbName('escape');
RestrictKeysForKbCheck([incR decR incG decG incB decB quit]);

colorA = [1 0 0 1];
colorB = [0 0 0 1];
r = colorA(1); g = colorA(2); b = colorA(3);

% this is a two color grating, passing in colorA and colorB.
[cgrat, crect, shader] = CreateProceduralColorGrating(ptb.win, ...
	resolution(1), resolution(2),...
	colorA, colorB, radius);

colorA = [0 1 0 1];
colorB = [0 0 0 1];

% this is a two color grating, passing in colorA and colorB.
[cgrat2, ~] = CreateProceduralColorGrating(ptb.win, ...
	resolution(1), resolution(2),...
	colorA, colorB, radius);

colorA = [0 0 1 1];
colorB = [0 0 0 1];

% this is a two color grating, passing in colorA and colorB.
[cgrat3, ~] = CreateProceduralColorGrating(ptb.win, ...
	resolution(1), resolution(2),...
	colorA, colorB, radius);

Priority(MaxPriority(ptb.win)); %bump our priority to maximum allowed

cRect = CenterRect(crect,ptb.winRect);
lRect = OffsetRect(cRect,-resolution(1),0);
rRect = OffsetRect(cRect,resolution(1),0);

thisp = 0;
closeWin = false; ListenChar(-1);
vbl(1)=Screen('Flip', ptb.win);

while ~closeWin
	Screen('DrawTexture', ptb.win, cgrat, [], lRect,...
		angle, [], [], [bgColour 1], [], [],...
		[phase, sf, contrast, sigma]);
	Screen('DrawTexture', ptb.win, cgrat2, [], cRect,...
		angle, [], [], [bgColour 1], [], [],...
		[phase, sf, contrast, sigma]); 
	Screen('DrawTexture', ptb.win, cgrat3, [], rRect,...
		angle, [], [], [bgColour 1], [], [],...
		[phase, sf, contrast, sigma]); 
	phase = phase - 5; 
	vbl(end+1) = Screen('Flip', ptb.win, vbl(end) + ptb.ifi/2);
	%---- handle keyboard
	[~,~,keyCode] = KbCheck(-1);
	name = find(keyCode==1);
	if ~isempty(name)  
		switch name
			case incR
				r = r + 0.005;
				if r > 1
					r = 1;
				end
				changeColor([r, g, b, 1],shader);
				fprintf('r = %.2f\n',r)
			case decR
				r = r - 0.005;
				if r < 0
					r = 0;
				end
				changeColor([r, g, b, 1],shader);
				fprintf('r = %.2f\n',r)
			case incG
				g = g + 0.005;
				if g > 1
					g = 1;
				end
				changeColor([r, g, b, 1],shader);
				fprintf('g = %.2f\n',g)
			case decG
				g = g - 0.005;
				if g < 0
					g = 0;
				end
				changeColor([r, g, b, 1],shader);
				fprintf('g = %.2f\n',g)
			case incB
				b = b + 0.005;
				if b > 1
					b = 1;
				end
				changeColor([r, g, b, 1],shader);
				fprintf('b = %.2f\n',b)
			case decB
				b = b - 0.005;
				if b < 0
					b = 0;
				end
				changeColor([r, g, b, 1],shader);
				fprintf('b = %.2f\n',b)
			case quit
				closeWin = true;
			otherwise
				fprintf('Can''t match key!\n')
		end
	end
end

Screen('Flip', ptb.win);

%figure;plot(diff(vbl)*1e3);title(sprintf('VBL Times, should be ~%.2f ms',ptb.ifi*1e3));ylabel('Time (ms)')

end

function changeColor(newColor,shader)
glUseProgram(shader);
glUniform4f(glGetUniformLocation(shader, 'color1'),...
	newColor(1),newColor(2),newColor(3),newColor(4));
glUseProgram(0);
end

%----------------------
function ptb = mySetup(screen, bgColour, ws)

ptb.cleanup = onCleanup(@myCleanup);
PsychDefaultSetup(2);
Screen('Preference', 'SkipSyncTests', 2);
if isempty(screen); screen = max(Screen('Screens')); end
ptb.ScreenID = screen;
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
[ptb.win, ptb.winRect] = PsychImaging('OpenWindow', ptb.ScreenID, bgColour, ws, [], [], [], 1);

[ptb.w, ptb.h] = RectSize(ptb.winRect);
screenWidth = 530; % mm
viewDistance = 573; % mm
ptb.ppd = ptb.w/2/atand(screenWidth/2/viewDistance);
ptb.ifi = Screen('GetFlipInterval', ptb.win);
ptb.fps = 1 / ptb.ifi;
Screen('BlendFunction', ptb.win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

end

%----------------------
function myCleanup()

disp('Clearing up...')
ListenChar(0); Priority(0);
sca

end