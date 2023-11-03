function binocularStimulation(in)
% Version 1.0.9

if ~exist('in','var')
	in.stereoMode = 8;
	in.distance = 57.3;
	in.ppcm = 36;
	in.bg = [0 0 0];
	in.left = [0.8 0 0];
	in.right = [0 0.3 1];
	in.type = 'checkerboard';
	in.sf = 0.1;
	in.tf = 0;
	in.flash = 0;
	in.anglemod = 0.2;
	in.sfmod = 0;
	in.repeats =  10;
	in.times = [14 14];
	in.focusSize = 0.4;
	in.debug = true;
end

mridata.in = in;
mridata.date = datetime;

%===========================task
t = taskSequence;
t.randomise = false;
t.nVar.name = 'eye';
t.nVar.values = [1 2 3 4];
t.nBlocks = in.repeats;
t.trialTime = in.times(1);
t.isTime = in.times(2);
t.ibTime = t.isTime;
t.randomiseTask;

fname = t.initialiseSaveFile;
fname = ['BinocularMRI-' in.name '-' fname '.mat'];
mridata.name = fname;
cd(t.paths.savedData);

fprintf('BINOCULAR MRI: Data: %s\n',[pwd filesep fname]);

%===========================setup
s = screenManager('backgroundColour', in.bg, ...
	'distance', in.distance, 'pixelsPerCm', in.ppcm);
s.stereoMode = in.stereoMode;
s.anaglyphLeft = in.left;
s.anaglyphRight = in.right;

if IsOSX || IsWin || in.debug
	s.disableSyncTests = true;
end

if in.debug
	s.screen = 0;
	s.windowed = [0 0 1200 800];
	s.specialFlags = kPsychGUIWindow;
end

switch lower(in.type)
	case 'checkerboard'
		stim = checkerboardStimulus('sf',in.sf,'colour',[1 1 1],'colour2',[0 0 0]);
		stim.contrast = 1;
		stim.tf = in.tf;
		stim.mask = false;
		stim.size = 80;
	case 'spiral'
		stim = polarGratingStimulus('sf',in.sf,'colour',[1 1 1],'colour2',[0 0 0]);
		stim.tf = in.tf;
		stim.type = 'spiral';
		stim.centerMask = 0.5;
		stim.sf = stim.sf * 1;
		stim.spiralFactor = 3;
		stim.sigma = 0.1;
		stim.mask = true;
		stim.size = 70;
		in.anglemod = 0;
	case 'radial'
		stim = polarGratingStimulus('sf',in.sf,'colour',[1 1 1],'colour2',[0 0 0]);
		stim.tf = in.tf;
		stim.type = 'radial';
		stim.centerMask = 1;
		stim.sf = stim.sf * 1;
		stim.spiralFactor = 3;
		stim.sigma = 0.1;
		stim.mask = true;
		stim.size = 70;
		in.anglemod = 0;
	case 'circular'
		stim = polarGratingStimulus('sf',in.sf,'colour',[1 1 1],'colour2',[0 0 0]);
		stim.tf = in.tf;
		stim.type = 'circular';
		stim.centerMask = 0;
		stim.sf = stim.sf * 2;
		stim.spiralFactor = 3;
		stim.sigma = 0.1;
		stim.mask = true;
		stim.size = 70;
		in.anglemod = 0;
end

dis0 = discStimulus('colour', [0 0 0], 'size', in.focusSize+0.2,'sigma',27);
dis1 = imageStimulus('size', in.focusSize, 'colour', [1 1 1],...
	'fileName',[s.paths.root '/stimuli/star.png']);
dis2 = imageStimulus('size', in.focusSize, 'colour', [1 1 1],...
	'fileName',[s.paths.root '/stimuli/triangle.png']);
dis = metaStimulus;
dis{1} = dis0;
dis{2} = dis1;
dis{3} = dis2;

mridata.t = t;
mridata.s = s;
mridata.stim = stim;
mridata.eye = t.outValues;

if in.flash > 0
	stim.phaseReverseTime = in.flash;
end

sv = open(s);
mridata.sv = sv;
halfisi = sv.halfisi;
setup(stim, s);
setup(dis, s);

sfinc = in.sfmodtime;

sfs = [];
if in.sfmod > 0 && strcmpi(in.type,'checkerboard')
	sfs = ( (cos(pi:sfinc:15*pi) + 1 ) / 2 ) * in.sfmod + in.sf;
end

%============================keys
KbName('UnifyKeyNames')
stopKey				= KbName('q');
triggerKey			= KbName('s');
upKey				= KbName('uparrow');
downKey				= KbName('downarrow');
leftKey				= KbName('leftarrow');
rightKey			= KbName('rightarrow');
oldr=RestrictKeysForKbCheck([stopKey triggerKey upKey downKey leftKey rightKey]);

if in.test
	vbl = flip(s); startT = vbl;
	a = 1;
	tick = 1;
	while vbl <= startT + in.times(1)
		switchChannel(s,0);
		draw(stim);
		switchChannel(s,1);
		draw(stim);
		animate(stim);
		vbl = flip(s);
		if ~isempty(sfs)
			stim.sfOut = sfs(a); a = a + 1;
		end
		if in.anglemod
			stim.angleOut = stim.angleOut + in.anglemod;
		end

		tick = tick + 1;
	end
	RestrictKeysForKbCheck(oldr);ListenChar(0);Priority(0);ShowCursor;
	try close(s); end
	try reset(stim); end
	return; 
end

Priority(MaxPriority(s.win));

if ~in.debug; ListenChar(-1); HideCursor; end

WaitSecs(1);

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

endExperiment = false;

times.next = [];

vbl = flip(s); startT = vbl; nextT = startT; 
times.start = startT;
times.next = [times.next nextT-startT];

for i = 1:t.nRuns

	fprintf('\n===>>> Time: %.2f -- RUN: %i -- EYE: %i -- BLANK ON\n', vbl - startT, i, t.outValues{i});
	
	stim.angleOut = 0;
	stim.sfOut = in.sf;

	nextT = nextT + in.times(2);
	times.next = [times.next nextT-startT];
	while vbl <= nextT
		vbl = flip(s, vbl+sv.halfisi);
		[keyDown, ~, keyCode] = optickaCore.getKeys();
		if keyDown
			if keyCode(stopKey); endExperiment = true; break; end
		end
	end

	if endExperiment; break; end

	fprintf('   >>> Time: %.2f -- RUN: %i -- EYE: %i -- STIM ON\n', vbl - startT, i, t.outValues{i});
	
	a = 1;
	disTime = 0;
	sw = 1;
	hide(dis,3);
	show(dis,[1 2]);
	nextT = nextT + in.times(1);
	times.next = [times.next nextT-startT];
	focusT = vbl;

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
				draw(dis);
			case 2
				switchChannel(s,1);
				draw(stim);
				draw(dis);
			case 3
				switchChannel(s,0);
				draw(stim); 
				draw(dis);
				switchChannel(s,1);
				draw(stim);
				draw(dis);
			case 4
				switchChannel(s,0);
				if matches(in.fellowEye,'Left')
					stim.contrastOut = in.fellowContrast;
				end
				draw(stim); 
				draw(dis);
				stim.contrastOut = 1.0;
				switchChannel(s,1);
				if matches(in.fellowEye,'Right')
					stim.contrastOut = in.fellowContrast;
				end
				draw(stim);
				draw(dis);
				stim.contrastOut = 1.0;
		end
		animate(stim);
		vbl = flip(s, vbl+sv.halfisi);
		disTime = vbl - focusT;
		if disTime > in.focusTime(2) || (disTime > in.focusTime(1) && rand > 0.975)
			sw = sw + 1; 
			focusT = vbl; 
			if sw > 2; sw = 1; end
			if sw == 1; hide(dis,3); show(dis,2);else;hide(dis,2); show(dis,3);end
		end
	end

end

times.end = vbl;
disp('Recorded Times of Transitions:');
disp(times.next);

mridata.times = times;

fprintf('\n===>>> SAVE DATA: %s\n',fname);
save(fname,'mridata');

RestrictKeysForKbCheck(oldr);ListenChar(0);Priority(0);ShowCursor;
reset(stim);
close(s);

end