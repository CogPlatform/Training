function contrasttest()

bgColour = [0.5 0.5 0.5];
screen = max(Screen('Screens'));
screenSize = [ ];

s = screenManager;
s.screen = screen;
s.pixelsPerCm = 27;
s.windowed = screenSize;
s.backgroundColour = bgColour;
s.bitDepth = 'EnableBits++Mono++Output';
s.blend = true;

s.open();

g1 = gratingStimulus();
g1.sf = 2;
g1.tf = 0;
g1.size = 10;
g1.contrast = 0.01;
g1.xPosition = -15;

g2 = gratingStimulus();
g2.sf = 2;
g2.tf = 0;
g2.size = 10;
g2.contrast = 0.0075;
g2.xPosition = 0;

g3 = gratingStimulus();
g3.sf = 2;
g3.tf = 0;
g3.size = 10;
g3.contrast = 0.005;
g3.xPosition = 15;

stims = metaStimulus();
stims{1} = g1;
stims{2} = g2;
stims{3} = g3;

stims.setup(s);

vbl(1)=flip(s);
while vbl(end) < vbl(1) + 25
	s.drawGrid();
	draw(stims);
	animate(stims);
	vbl(end+1) = flip(s);
end

flip(s);

%figure;plot(diff(vbl)*1e3);title(sprintf('VBL Times, should be ~%.2f ms',ptb.ifi*1e3));ylabel('Time (ms)')

end

%----------------------
function ptb = mySetup(screen, bgColour, ws)

ptb.cleanup = onCleanup(@myCleanup);
PsychDefaultSetup(2);
Screen('Preference', 'SkipSyncTests', 2);
if isempty(screen); screen = max(Screen('Screens')); end
ptb.ScreenID = screen;
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'EnableBits++Mono++Output');
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
sca

end