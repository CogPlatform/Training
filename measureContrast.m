s=screenManager;
g=gratingStimulus;
load('/home/cog5/MatlabFiles/Calibrations/TobiiTX300_SET2_MonitorCalibration.mat');
%c.plot;

%g.type='square';
g.mask = false;
g.size = 30;
g.tf=0;
g.sf = 0.1;
g.contrast = 0.5;

s.gammaTable = c;
sv = s.open();
c.screenVals = sv;
g.setup(s);
g.draw();
s.flip();

c.openSpectroCAL();
c.spectroCalLaser(true);
%input('Align Laser then press enter to start...')
c.spectroCalLaser(false);
WaitSecs(0.5);

ctest = [];

for loop = 1:length(ctest)
	
	g.driftPhase = 0;
	g.contrastOut = ctest(loop);
	
	for i = 1:20
		g.draw();
		s.flip();
		WaitSecs(0.1);
		[~,~,Y(i)] = c.getSpectroCALValues();
		g.driftPhase = g.driftPhase + 180;
	end

	A = Y(1:2:19);
	B = Y(2:2:20);

	h=figure;
	tl = tiledlayout(h,'flow');

	nexttile;
	plot(A,'ko');
	hold on;
	plot(B,'ro');
	ylabel('Luminance');

	nexttile;
	boxplot([A,B],[ones(1,10),ones(1,10)*2],'Notch','on','Labels',{'phase0','phase180'});
	ylabel('Luminance');

	tl.YLabel.String = 'Luminance (cd/m^2)';
	tl.Title.String = ['Contrast: ' num2str(g.contrastOut)];
	
end

phs = [0:22.5:360];
YY=[];
g.contrastOut = 0.01;
g.driftPhase = phs(1);
g.draw();
s.flip();
WaitSecs

for loop = 1:length(phs)
	g.driftPhase = phs(loop);
	fprintf('Phase is: %.2f\n',phs(loop));
	g.draw();
	s.flip();
	WaitSecs(0.1);
	[~,~,YY(loop)] = c.getSpectroCALValues();
end

figure
plot(phs,YY,'r-o');
title(['Contrast: ' num2str(g.contrastOut)]);

g.reset;
s.close;
c.close;
