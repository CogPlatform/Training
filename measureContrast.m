s = screenManager;
g = gratingStimulus;
d = discStimulus;

%g.type='square';
g.mask = false;
g.size = 30;
g.tf=0;
g.sf = 0.1;
g.contrast = 0.5;

d.colour = [0.2 0.2 0.2];
d.size = 30;

%load('~/MatlabFiles/Calibrations/TobiiTX300_SET2_MonitorCalibration.mat');
%load('~/Code/Training/AorusFI27QP_2560x1440x120Hz.mat');
%load('~/MatlabFiles/Calibration/Display++Color++Mode-Ubuntu-RadeonPsychlab.mat')
c = calibrateLuminance;
%c.choice = 2;
%c.plot;
%s.gammaTable = c;
s.bitDepth = 'Native10bit';
resolution = 2^10;
sv = s.open();
c.screenVals = sv;
g.setup(s);
d.setup(s);
g.draw();
s.flip();

c.openSpectroCAL();
c.spectroCalLaser(true);
input('Align Laser then press enter to start...')
c.spectroCalLaser(false);
Priority(MaxPriority(s.win));
WaitSecs(0.5);

ctest = [];
clear Y YY YYY A B;
for loop = 1:length(ctest)
	
	g.driftPhase = 0;
	g.contrastOut = ctest(loop);
	
	for i = 1:10
		g.draw();
		s.flip();
		WaitSecs(0.1);
		[~,~,Y(i)] = c.getSpectroCALValues();
		g.driftPhase = g.driftPhase + 180;
	end

	A = Y(1:2:9);
	B = Y(2:2:10);

	h=figure;
	tl = tiledlayout(h,'flow');

	nexttile;
	plot(A,'ko');
	hold on;
	plot(B,'ro');
	box on;grid on
	nexttile;
	boxplot([A,B],[ones(1,5),ones(1,5)*2],'Notch','on','Labels',{'phase0','phase180'});
	box on;grid on
	tl.YLabel.String = 'Luminance (cd/m^2)';
	tl.Title.String = ['Contrast: ' num2str(g.contrastOut)];
	drawnow;
end

phs = [0:22.5:360];
YY=[];
g.contrastOut = 0.01;
g.driftPhase = phs(1);
g.draw();
s.flip();
WaitSecs(0.5);

for loop = 1:length(phs)
	g.driftPhase = phs(loop);
	g.draw();
	s.flip();
	WaitSecs(0.1);
	[~,~,YY(loop)] = c.getSpectroCALValues();
	fprintf('Phase is: %.2f, Luminance is %.4f\n',phs(loop),YY(loop));
end

h=figure;
tl = tiledlayout(h,'flow');
nexttile
plot(phs,YY,'r-o');box on;grid on
title(['Contrast: ' num2str(g.contrastOut)]);
xlabel('Phase (deg)')
ylabel('Output Luminance (cd/m^2)');
drawnow;

s.flip();
range = 0:1/resolution:1;
steps = floor(length(range)/2):floor(length(range)/2)+25;
for loop = steps
	d.colourOut = [range(loop) range(loop) range(loop) 1];
	d.update();
	d.draw();
	s.flip();
	WaitSecs(0.1);
	[~,~,YYY(loop)] = c.getSpectroCALValues();
	fprintf('Loop %i - In/out Luminance %.4f = %.4f\n',loop,range(loop),YYY(loop));
end
YYY=YYY(steps);
nexttile
plot(range(steps),YYY,'r-o');
title([s.bitDepth ' Luminance: ' num2str(resolution)]);
xlabel('Grayscale Step 0-1')
ylabel('Output Luminance (cd/m^2)');
box on;grid on
drawnow;

ListenChar(0);ShowCursor;Priority(0);
g.reset;
d.reset;
s.close;
c.closeSpectroCAL
c.close;
