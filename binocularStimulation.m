function binocularStimulation(in)
% Version 1.0.0

debug = false;

if ~exist('in','var')
	in.stereoMode = 8;
	in.bg = [0 0 0];
	in.left = [0.8 0 0];
	in.right = [0 0.3 1];
	in.type = 'checkerboard';
	in.sf = 0.1;
	in.flash = 0;
	in.anglemod = 0.2;
	in.sfmod = 0;
	in.repeats =  10;
	in.times = [14 14];
end

sf = in.sf;
tf = 0;
size = 50;
mask = false;

%============================keys
KbName('UnifyKeyNames')
stopKey				= KbName('q');
triggerKey			= KbName('s');
upKey				= KbName('uparrow');
downKey				= KbName('downarrow');
leftKey				= KbName('leftarrow');
rightKey			= KbName('rightarrow');
oldr=RestrictKeysForKbCheck([stopKey triggerKey upKey downKey leftKey rightKey]);

%===========================task
t = taskSequence;
t.nVar.name = 'eye';
t.nVar.values = [1 2 3];
t.nBlocks = in.repeats;
t.trialTime = in.times(1);
t.isTime = in.times(2);
t.ibTime = t.isTime;
t.randomiseTask;

%===========================setup
s = screenManager('backgroundColour', in.bg);
s.stereoMode = in.stereoMode;
s.anaglyphLeft = in.left;
s.anaglyphRight = in.right;
%s.disableSyncTests = true;

switch lower(in.type)
	case 'checkerboard'
		stim = checkerboardStimulus('sf',in.sf,'colour',[1 1 1],'colour2',[0 0 0]);
		stim.mask = false;
	case 'spiral'
		stim = polarGratingStimulus('sf',in.sf,'colour',[1 1 1],'colour2',[0 0 0]);
		stim.type = 'spiral';
		stim.centerMask = 0.5;
		stim.sf = stim.sf * 1;
		stim.spiralFactor = 3;
		stim.sigma = 0.1;
	case 'radial'
		stim = polarGratingStimulus('sf',in.sf,'colour',[1 1 1],'colour2',[0 0 0]);
		stim.type = 'polar';
		stim.centerMask = 1;
		stim.sf = stim.sf * 1;
		stim.spiralFactor = 3;
		stim.sigma = 0.1;
	case 'circular'
		stim = polarGratingStimulus('sf',in.sf,'colour',[1 1 1],'colour2',[0 0 0]);
		stim.type = 'circular';
		stim.centerMask = 0;
		stim.sf = stim.sf * 2;
		stim.spiralFactor = 3;
		stim.sigma = 0.1;
end

stim.size = 80;

if in.flash > 0
	stim.phaseReverseTime = in.flash;
end

sv = open(s);
halfisi = sv.halfisi;
setup(stim, s);

sfinc = 0.02;

sfs = [];
if in.sfmod > 0 && strcmp(in.type,'checkerboard')
	sfs = ( (cos(pi:sfinc:10*pi) + 1 ) / 2 ) * in.sfmod + in.sf;
end

Priority(MaxPriority(s.win));

if ~debug
	ListenChar(-1); HideCursor;
end

WaitSecs(1);

ts = Screen('TextSize', s.win);
endExperiment = false;
noStart = true;

while noStart || ~endExperiment
	drawText(s,'Waiting for Trigger from MRI Scanner... [q] to QUIT'); 
	vbl = flip(s);
	[keyDown, ~, keyCode] = optickaCore.getKeys();
	if keyDown
		if keyCode(stopKey); endExperiment = true; break;
		elseif keyCode(triggerKey); noStart = false; break;
		end
	end
end

if endExperiment
	RestrictKeysForKbCheck(oldr);ListenChar(0);Priority(0);ShowCursor;
	try close(s); end
	try reset(stim); end
	return; 
end

vbl = flip(s); startT = vbl; nextT = startT;

for i = 1:t.nRuns

	fprintf('\n===>>> Time: %.2f -- RUN: %i -- EYE: %i\n', vbl - startT, i, t.outValues{i});
	
	stim.angleOut = 0;
	stim.sfOut = in.sf;

	nextT = nextT + in.times(2);
	
	while vbl <= nextT
		vbl = flip(s, vbl+sv.halfisi);
	end

	nextT = nextT + in.times(1);

	a = 1;
	
	while vbl <= nextT
		if ~isempty(sfs)
			stim.sfOut = sfs(a); a = a + 1;
		end
		if in.anglemod
			stim.angleOut = stim.angleOut + in.anglemod;
		end
		switch t.outValues{i}
			case 1
				switchChannel(s,0);
				draw(stim);
			case 2
				switchChannel(s,1);
				draw(stim);
			case 3
				switchChannel(s,0);
				draw(stim);
				switchChannel(s,1);
				draw(stim);
		end
		animate(stim);
		vbl = flip(s, vbl+sv.halfisi);
	end

end

RestrictKeysForKbCheck(oldr);ListenChar(0);Priority(0);ShowCursor;
reset(stim);
close(s);

end