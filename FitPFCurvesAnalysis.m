function FitPFCurvesAnalysis(uiin)

%==========================================================================
%===========================================================response values
YESBLANK = 1; YESTARGET = 2; UNSURE = 4; BREAKINIT = -100; BREAKBLANK = -10;
BREAKTARGET = -1; BREAKEXCL = -5; UNDEFINED = 0;

if uiin.correctGamma
	load('~/MatlabFiles/Calibration/AorusFI27-120Hz-NEWcalibration.mat');
	gamma = c.displayGamma(1);
else
	gamma = 1;
end

% parametric standard error?
parametric = uiin.parametric;

%do we include the break exclude trials?
useExclusion = uiin.exclusion;

%resolution of search space
grain = uiin.grain;

% fixed lambda (lapse rate) - NaN or a value
fixedLambda = uiin.fixedLambda;

% ---- which psychometric function to use?
if uiin.logSlope
	PF = @PAL_Gumbel;
	logSlope = true;
else
	PF = @PAL_Weibull;
	logSlope = false;
end
pfname = functions(PF);
pfname = pfname.function;
pfname = regexprep(pfname,'_','-');

cd(uiin.path);
load(uiin.file);
if ~exist('task','var') || ~isprop(task,'nVars'); warning('Data not valid!');return;end

uiin.file = regexprep(uiin.file,'_','-');

contrasts = task.nVar(1).values;

if uiin.correctGamma
	contrastlabels = contrasts.^(gamma);
	contrasts = contrastlabels;
end

trials = ana.task([ana.task.showGrating]==true);
trialscorrect = trials([trials.response]==YESTARGET);
trialswrong = trials([trials.response]==BREAKTARGET);
trialswrongall = trials([trials.response]==BREAKTARGET | [trials.response]==BREAKEXCL);

txt = sprintf('Trial number: %i | Correct: %i | BREAK: %i | BREAKALL: %i', ...
	length(trials),length(trialscorrect),length(trialswrong),length(trialswrongall));
disp(txt);
uiin.results.Value = {txt};

if useExclusion
	trialswrong = trialswrongall;
end

contrastTotal = [];
contrastCorrect = [];

for i = 1 : length(contrasts)
	tr = trialscorrect([trialscorrect.contrast] == contrasts(i));
	contrastCorrect(i) = length(tr);
	tr = trialswrong([trialswrong.contrast] == contrasts(i));
	contrastWrong(i) = length(tr);
	contrastTotal(i) = contrastWrong(i) + contrastCorrect(i);
end

% force the first value to be 0 contrast
if uiin.logAxis
	contrasts(contrasts==0) = 1e-3;
end

total = contrastTotal;
correct = contrastCorrect;

% ================= Here are our model parameters =========================
% ---- threshold
search.alpha = linspace(uiin.maxThreshold(1), uiin.maxThreshold(2), grain);
freeParameters = 1 ;
% ---- slope
if logSlope
	if length(uiin.maxSlope) == 1
		search.beta = uiin.maxSlope;
		freeParameters = [freeParameters 0];
	else
		search.beta = logspace(log10(uiin.maxSlope(1)), log10(uiin.maxSlope(2)), grain);
		freeParameters = [freeParameters 1];
	end
else
	if length(uiin.maxSlope) == 1
		search.beta = uiin.maxSlope;
		freeParameters = [freeParameters 0];
	else
		search.beta = linspace(uiin.maxSlope(1), uiin.maxSlope(2), grain);
		freeParameters = [freeParameters 1];
	end
end

% ---- guess rate
correct0 = contrastCorrect(1) ./ contrastTotal(1); 
if isnan(uiin.fixedGamma)
	search.gamma = linspace(0,0.5,25);
	freeParameters = [freeParameters 1];
elseif isinf(uiin.fixedGamma) 
	search.gamma = correct0;
	freeParameters = [freeParameters 0];
else
	search.gamma = uiin.fixedGamma;
	freeParameters = [freeParameters 0];
end
gL = [min(search.gamma) max(search.gamma)];

% ---- error bias
if isnan(fixedLambda)
	search.lambda = linspace(0,0.2,25);
	freeParameters = [freeParameters 1];
elseif isinf(fixedLambda)
	search.lambda = 0.02;
	freeParameters = [freeParameters 0];
else
	search.lambda = fixedLambda;
	freeParameters = [freeParameters 0];
end
lL = [0 max(search.lambda)];

% ---- which psychometric function to use?
% fitting method nAPLE treals each stim seperately, jAPLE assumes largest
% stim defines lapse rate, i.e. contrast is clearly visible so lapse is
% only explanation if larger than 0.
lf = uiin.fitting;

% ---- fitting options
options = PAL_minimize('options');  %decrease tolerance (i.e., increase
options.TolX = 1e-10;              %precision). This is a good idea,
options.TolFun = 1e-10;            %especially in high-dimension
options.MaxIter = 7000;           %parameter space.
options.MaxFunEvals = 7000;
options.Display = 'on';

% ============================ Here we run the model ======================
[params,LL,c,d] = PAL_PFML_Fit(contrasts,correct,total,search,freeParameters,PF,...
	'lapseFits',lf,...
	'guessLimits',gL,...
	'lapseLimits',lL,...
	'searchOptions',options);
disp(d);
if c < 0
	warning('Fit did not converge on a global maximum!'); 
	txt = ['WARNING!!!: NO Convergence - LL:' num2str(LL)];
else
	txt = ['LL:' num2str(LL)];
end
if params(2) == Inf
	warning('Had to change the INF slope parameter!!')
	txt = [txt ' - WARNING: INF Slope'];
	params(2) = max(search.beta);
end
uiin.results.Value = [uiin.results.Value; txt; d.message];drawnow

xrange = linspace(0, max(contrasts), 500);
fit = PF(params,xrange);

% =======================Get errors and goodness of fit? =================
if islogical(parametric)
	commandwindow;
	disp('Calculating standard errors and goodness of fit, please wait...')
	B=uiin.nBootstraps;
	if parametric == true
		[SD, paramsSim, LLSim, converged] = PAL_PFML_BootstrapParametric(...
			contrasts, total, params, freeParameters, B, PF, ...
			'searchGrid', search);
	else
		[SD, paramsSim, LLSim, converged] = PAL_PFML_BootstrapNonParametric(...
			contrasts, correct, total, [], freeParameters, B, PF,...
			'searchGrid',search);
	end
	
	%Number of simulations to perform to determine Goodness-of-Fit
	B=uiin.nBootstraps;
	disp('Determining Goodness-of-fit.....');
	[Dev, pDev] = PAL_PFML_GoodnessOfFit(contrasts, correct, total, ...
		params, freeParameters, B, PF, 'searchGrid', search, 'lapseFit',lf);
	txt = sprintf('%s LL:%.3f Thr: %.3f±%.3f | Slope: %.3f±%.3f | Guess: %.3f | Lapse: %.3f | Dev: %.3f; p-val: %.3f',...
		pfname,LL,params(1),SD(1),params(2),SD(2),params(3),params(4),Dev,pDev);
	
else
	txt = sprintf('%s LL:%.3f Thr: %.3f | Slope: %.3f | Guess: %.3f | Lapse: %.3f',...
		pfname,LL,params(1),params(2),params(3),params(4));
end
uiin.results.Value = [uiin.results.Value; txt];

% ========================= And plot our result ===========================
fname = functions(PF);
fname = fname.function;
axis(uiin.axis);
%figure('NumberTitle', 'off', 'Toolbar', 'none','Name',[file],'Position',[50 100 1000 600]);
%if exist('opticka','file'); opticka.resizeFigure(0,[1000 700]); end
plot(uiin.axis,contrasts,(correct./total),'k.','Color',[0.3 0.3 0.3],'MarkerSize',30);
hold(uiin.axis,'on');
plot(uiin.axis,xrange,fit,'Color',[0.8 0.5 0],'LineWidth', 2);
if exist('SD','var') & ~isempty(SD)
	plot(uiin.axis,params(1),0.6,'bo','MarkerFaceColor','b','MarkerSize',6);
	line(uiin.axis,[params(1)-SD(1) params(1)+SD(1)], [0.6 0.6],'Color','b','LineWidth',1);
end
title(uiin.axis,txt,'FontSize',10);
SF = ana.SF;
txt = ['SF = ' num2str(SF) ', file = ' uiin.file];
subtitle(uiin.axis,txt,'Interpreter','none');
uiin.results.Value = [uiin.results.Value; txt];
xlim(uiin.axis,[-0.01 max(contrasts)+0.02]);
ylim(uiin.axis,[-0.05 1.05]);
if uiin.logAxis; uiin.axis.XScale='log'; else; uiin.axis.XScale='linear'; end
xlabel(uiin.axis,'Contrast');
ylabel(uiin.axis,'Probability Correct');
grid(uiin.axis,'on'); 
uiin.axis.XMinorGrid='on';uiin.axis.YMinorGrid='on';
box(uiin.axis,'on');
drawnow;

end