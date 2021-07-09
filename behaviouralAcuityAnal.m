%==========================================================================
%===========================================================response values
YESBLANK = 1; YESTARGET = 2; UNSURE = 4; BREAKINIT = -100; BREAKBLANK = -10;
BREAKTARGET = -1; BREAKEXCL = -5; UNDEFINED = 0;

% parametric standard error?
parametric = NaN;

%do we include the break exclude trials?
useExclusion = false;

%Here is our data
%load('/home/cog5/MatlabFiles/SavedData/BAMOC_07run2_2021_7_6_13_31_15.mat')
%load('/home/cog5/MatlabFiles/SavedData/BAMOC_17run5_2021_7_7_13_47_47.mat');

file = uigetfile;
if file == 0; return; end
load(file);

contrasts = task.nVar(1).values;

trials = ana.task([ana.task.showGrating]==true);
trialscorrect = trials([trials.response]==YESTARGET);
trialswrong = trials([trials.response]==BREAKTARGET);
trialswrongall = trials([trials.response]==BREAKTARGET | [trials.response]==BREAKEXCL);

fprintf('\n\nData: %s\n',file)
fprintf('Trial number: %i -- Correct: %i -- BREAK: %i -- BREAKALL: %i\n',...
	length(trials),length(trialscorrect),length(trialswrong),length(trialswrongall));

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

contrasts(contrasts==0) = 1e-6;

total = contrastTotal;
correct = contrastCorrect;

% ================= Here are our model parameters =========================
% ---- threshold
search.alpha = linspace(min(contrasts),max(contrasts),200);
% ---- slope
search.beta = logspace(0,1,200);
% ---- guess rate
search.gamma = 0;
%search.gamma = linspace(0,0.5,50);
% ---- error bias
%search.lambda = 0.02;
search.lambda = linspace(0,0.2,50);
% ---- which parameters to search
freeParameters = [1 1 0 1];
% ---- which psychometric function to use?
PF = @PAL_Gumbel;

% ============================ Here we run the model ======================
[params,b,c] = PAL_PFML_Fit(contrasts,correct,total,search,freeParameters,PF);

if params(2) == Inf
	warning('Had to change the INF slope parameter!!')
	params(2) = max(search.beta);
end
xrange = [0:0.0005:max(contrasts)];
fit = PF(params,xrange);

% ========================= And plot our result ===========================
figure
hold on
plot(contrasts,(correct./total),'ko');
plot(xrange,fit,'LineWidth', 2);
title(['PF Fitted data values: ' num2str(params,'%.4f ')]);
grid on; grid minor; box on;
drawnow;


% =======================Get errors and goodness of fit? =================
if islogical(parametric)
	B=400;
	if parametric == 1
		[SD paramsSim LLSim converged] = PAL_PFML_BootstrapParametric(...
			contrasts, total, params, freeParameters, B, PF, ...
			'searchGrid', search);
	else
		[SD paramsSim LLSim converged] = PAL_PFML_BootstrapNonParametric(...
			contrasts, correct, total, [], freeParameters, B, PF,...
			'searchGrid',search);
	end

	disp('done:');
	message = sprintf('Standard error of Threshold: %6.4f',SD(1));
	disp(message);
	message = sprintf('Standard error of Slope: %6.4f\r',SD(2));
	disp(message);
	
	%Number of simulations to perform to determine Goodness-of-Fit
	B=1000;

	disp('Determining Goodness-of-fit.....');

	[Dev pDev] = PAL_PFML_GoodnessOfFit(contrasts, correct, total, ...
		params, freeParameters, B, PF, 'searchGrid', search);

	disp('done:');

	%Put summary of results on screen
	message = sprintf('Deviance: %6.4f',Dev);
	disp(message);
	message = sprintf('p-value: %6.4f',pDev);
	disp(message);

	%Create simple plot
	ProportionCorrectObserved=NumPos./OutOfNum; 
	StimLevelsFineGrain=[min(StimLevels):max(StimLevels)./1000:max(StimLevels)];
	ProportionCorrectModel = PF(paramsValues,StimLevelsFineGrain);

	figure('name','Maximum Likelihood Psychometric Function Fitting');
	axes
	hold on
	plot(StimLevelsFineGrain,ProportionCorrectModel,'-','color',[0 .7 0],'linewidth',4);
	plot(StimLevels,ProportionCorrectObserved,'k.','markersize',40);
	set(gca, 'fontsize',16);
	set(gca, 'Xtick',StimLevels);
	axis([min(StimLevels) max(StimLevels) .4 1]);
	xlabel('Stimulus Intensity');
	ylabel('proportion correct');
end
