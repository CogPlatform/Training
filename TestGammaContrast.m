clear all
s = screenManager();
s.bitDepth = 'Native10bit';
load('~/MatlabFiles/Calibrations/AorusFI27-120Hz-NEWcalibration.mat');
if ~exist('c','var'); error('Cannot load gamma table');end
s.gammaTable = c;

g=gratingStimulus();
g.size = 30;
g.mask = false;
g.sf = 0.1;
g.contrast = 0.01;
tic
sv = s.open;

g.setup(s);g.draw;s.flip;

c.openSpectroCAL;


f = figure('Units','Normalized','Position',[0 0 0.3 1]);
tiledlayout(f,'flow')

nexttile
plot(sv.gammaTable); 
hold on; 
plot(sv.linearGamma); 
title(['Gamma tables for contrast = ' num2str(g.contrast)]);
legend({'corrected','linear'});

phase = 0:10:360;

Screen('LoadNormalizedGammaTable',s.win,s.screenVals.gammaTable);
g.draw;s.flip;
WaitSecs(0.5);

l1 = zeros(size(phase));

for i = 1:length(phase)
	
	g.phaseOut = phase(i);disp(['Corrected Phase: ' num2str(phase(i))]);
	g.update;
	g.draw;
	s.flip;
	WaitSecs(0.3);
	[~,~,l1(i)] = c.getSpectroCALValues();
	
end

g.phaseOut=0;g.update;
Screen('LoadNormalizedGammaTable',s.win,s.screenVals.linearGamma);
g.draw;s.flip;
WaitSecs(0.5);

l2 = zeros(size(phase));

for i = 1:length(phase)
	
	g.phaseOut = phase(i);disp(['Linear Phase: ' num2str(phase(i))]);
	g.update;
	g.draw;
	s.flip;
	WaitSecs(0.3);
	[~,~,l2(i)] = c.getSpectroCALValues();
	
end

nexttile
plot(phase,l1);
hold on
plot(phase,l2);
legend('corrected','linear');
title(sprintf('Raw; Range = %.3f vs. %.3f',max(l1)-min(l1),max(l2)-min(l2)));
xlabel('Phase (deg)');
ylabel('Luminance (cd/m2)');
ll1 = l1 - mean(l1);
ll2 = l2 - mean(l2);

nexttile

plot(phase,ll1);
hold on
plot(phase,ll2);
legend('corrected','linear');
title('Normalised (subtract mean)');
xlabel('Phase (deg)');
ylabel('Luminance (cd/m2)');

c.closeSpectroCAL;
s.close;
g.reset;

toc;

