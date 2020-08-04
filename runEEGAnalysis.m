function runEEGAnalysis(ana)
ts=tic;
ana.table.Data =[]; 
ana.warning.Color = [ 0.5 0.5 0.5 ];
drawnow;
ft_defaults;
ana.codeVersion = '1.04';
ana.versionLabel.Text = [ana.versionLabel.UserData ' Code: V' ana.codeVersion];
c=analysisCore.optimalColours(10);
info = load(ana.MATFile);
info.seq.getLabels();
vars = getVariables();
data_raw = []; trl=[]; triggers=[]; events=[]; timelock = []; freq = [];

%========================================================PLOT RAW DATA
if ana.plotTriggers
	info.seq.showLog(); drawnow;
	cfgRaw				= [];
	cfgRaw.dataset		= ana.EDFFile;
	cfgRaw.header		= ft_read_header(cfgRaw.dataset); 
	disp('============= HEADER INFO, please check! ====================');
	disp(cfgRaw.header); disp(cfgRaw.header.orig);
	if cfgRaw.header.nChans ~= ana.pDiode
		ana.pDiode = cfgRaw.header.nChans;
		ana.bitChannels = ana.pDiode-8:ana.pDiode-1;
		ana.dataChannels = 1:ana.bitChannels(1)-1;
		warndlg('GUI channel assignments are incorrect, will correct this time!')
	end
	cfgRaw.continuous	= 'yes';
	cfgRaw.channel		= 'all';
	cfgRaw.demean		= 'yes';
	cfgRaw.detrend		= 'yes';
	cfgRaw.polyremoval  = 'yes';
	cfgRaw.chanindx     = ana.bitChannels;
	cfgRaw.threshold	= ana.threshold;
	cfgRaw.jitter		= ana.jitter;
	cfgRaw.minTrigger	= ana.minTrigger;
	cfgRaw.preTime		= ana.preTime;
	cfgRaw.correctID	= ana.correctID;
	data_raw			= ft_preprocessing(cfgRaw);
	cfgRaw.denoise		= false;
	[trl, events, triggers] = loadCOGEEG(cfgRaw);
	if isempty(trl)
		fprintf('--->>> NO Trials loaded\n');
	else
		fprintf('--->>> %i Trials loaded, plotting...\n',size(trl,1));
	end
	plotRawChannels(); drawnow;
	if ~isempty(trl) && size(trl,2) == 4
		plotTable(info.seq.outIndex,trl(:,4));
	end
	info.data_raw		= data_raw;
	info.events			= events;
	info.triggers		= triggers;
	info.trl			= trl;
	assignin('base','info',info);
	return;
end

%================================================LOAD DATA AS TRIALS
cfg					= [];
cfg.dataset			= ana.EDFFile;
cfg.header			= ft_read_header(cfg.dataset); disp(cfg.header);
if cfg.header.nChans ~= ana.pDiode
	ana.pDiode = cfg.header.nChans;
	ana.bitChannels = ana.pDiode-8:ana.pDiode-1;
	ana.dataChannels = 1:ana.bitChannels(1)-1;
	disp('============= HEADER INFO, please check! ====================');
	disp(cfg.header)
	warndlg('GUI channel assignments are incorrect, will correct this time!')
end
cfg.continuous		= 'yes';
cfg.trialfun		= 'loadCOGEEG';
cfg.chanindx		= ana.bitChannels;
cfg.threshold		= ana.threshold;
cfg.jitter			= ana.jitter;
cfg.minTrigger		= ana.minTrigger;
cfg.correctID		= ana.correctID;
cfg.preTime			= ana.preTime;
cfg.denoise			= false;
cfg					= ft_definetrial(cfg);
cfg					= rmfield(cfg,'denoise');
cfg.demean			= ana.demean;
if strcmpi(ana.demean,'yes') 
	cfg.baselinewindow	= ana.baseline;
end
cfg.medianfilter	= ana.medianfilter;
cfg.dftfilter		= ana.dftfilter;
cfg.detrend			= ana.detrend;
cfg.polyremoval		= ana.polyremoval;
cfg.channel			= ana.dataChannels;
if ana.rereference > 0 && any(ana.dataChannels == ana.rereference)
	cfg.reref		= 'yes';
	cfg.refchannel	= cfg.header.label{ana.rereference};
	cfg.refmethod	= 'avg';
end
if ana.lowpass > 0 
	cfg.lpfilter	= 'yes';
	cfg.lpfreq		= ana.lowpass;
	cfg.lpfilttype	= ana.filtertype;
end
if ana.highpass > 0
	cfg.hpfilter	= 'yes';
	cfg.hpfreq		= ana.highpass;
	cfg.hpfilttype	= ana.filtertype;
end
data_eeg			= ft_preprocessing(cfg);
info.data_cfg		= cfg;

if ana.makeSurrogate
	makeSurrogate();
end

if ana.rejectvisual
	cfg				= [];
	cfg.box			= 'yes';
	cfg.latency		= 'all';
	cfg.method		= ana.rejecttype;
	data_eeg		= ft_rejectvisual(cfg,data_eeg);
end

%================================================RUN TIMELOCK
varmap				= unique(data_eeg.trialinfo);
timelock			= cell(length(varmap),1);
avgfn				= eval(['@nan' ana.avgmethod]);
if ana.doTimelock
	for jv = 1:length(varmap)
		cfg				= [];
		cfg.trials		= find(data_eeg.trialinfo==varmap(jv));
		cfg.covariance	= ana.tlcovariance;
		cfg.keeptrials	= ana.tlkeeptrials;
		cfg.removemean	= ana.tlremovemean;
		if ~isempty(ana.plotRange);	cfg.latency = ana.plotRange; end
		timelock{jv}		= ft_timelockanalysis(cfg,data_eeg);
	end
	
	plotTimeLock();
	plotFreqPower();
end

%================================================RUN TIMEFREQ
freq					= cell(length(varmap),1);
if ana.doTimeFreq
	for jtf = 1:length(varmap)
		cfg				= [];
		cfg.trials		= find(data_eeg.trialinfo==varmap(jtf));
		cfg.channel		= 1;
		cfg.method		= 'mtmconvol';
		cfg.taper		= ana.freqtaper;
		cfg.pad			= 'nextpow2';
		cfg.foi			= ana.freqrange;                  % analysis 2 to 30 Hz in steps of 2 Hz
		cfg.t_ftimwin	= ones(length(cfg.foi),1).*0.2;   % length of time window = 0.5 sec
		if ~isempty(ana.plotRange) && isnumeric(ana.plotRange) && length(ana.plotRange)==2
			cfg.toi		= ana.plotRange(1):0.05:ana.plotRange(2);% time window "slides" from -0.5 to 1.5 sec in steps of 0.05 sec (50 ms)
		else
			cfg.toi		= min(data_eeg.time{1}):0.05:max(data_eeg.time{1});
		end
		freq{jtf}		= ft_freqanalysis(cfg,data_eeg);
	end
	plotFrequency();
end

info.timelock			= timelock;
info.freq				= freq;
info.data_raw			= data_raw;
info.data_eeg			= data_eeg;
info.triggers			= triggers;
info.ana2				= ana;
assignin('base','info',info);

plotTable(info.seq.outIndex, info.data_eeg.trialinfo);
fprintf('===>>> Analysis took %.2f seconds\n', toc(ts));


%=============================================================================
%================================================================SUB FUNCTIONS
%=============================================================================

function vars = getVariables()
	if isprop(info.seq,'varLabels')
		vars = info.seq.varLabels;
	else
		vars = cell(1,info.seq.minBlocks);
	end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%PLOT TABLE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function plotTable(intrig,outtrig)
	col1 = intrig;if size(col1,1)<size(col1,2); col1=col1';end
	col2 = outtrig;if size(col2,1)<size(col2,2); col2=col2';end
	col3 = vars; if size(col3,1)<size(col3,2); col3=col3';end
	col4 = 1:length(col3); if size(col4,1)<size(col4,2); col4=col4';end
	
	if length(col1) ~= length(col2)
		warning('Input and output triggers are different!')
		ana.warning.Color = [ 0.8 0.3 0.3 ];
	else
		ana.warning.Color = [ 0.3 0.8 0.3 ];
	end

	maxn = max([length(col1) length(col2) length(col3) length(col4)]);
	if length(col1) < maxn; col1(end+1:maxn) = NaN; end
	if length(col2) < maxn; col2(end+1:maxn) = NaN; end
	if length(col3) < maxn
		col3 = [col3;repmat({''},maxn-length(col3),1)];
	end
	if length(col4) < maxn; col4(end+1:maxn) = NaN; end
	tdata = table(col1,col2,col3,col4,'VariableNames',{'Triggers Sent','Data Triggers','Stimulus Value','Index'});
	ana.table.Data = tdata;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%PLOT TIME LOCKED RESPONSE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function plotTimeLock()
	[p f e] = fileparts(ana.EDFFile);
	h = figure('Name',['TL Data: ' f '.' e],'Units','normalized',...
		'Position',[0 0.025 0.25 0.9]);
	if length(timelock) > 8
		tl = tiledlayout(h,'flow','TileSpacing','compact');
	else
		tl = tiledlayout(h,length(timelock),1,'TileSpacing','compact');
	end
	mn = inf; mx = -inf;
	for jj = 1:length(timelock)
		nexttile(tl,jj)
		hold on
		if isfield(timelock{jj},'avg')
			for i = 1:length(timelock{jj}.label)
				analysisCore.areabar(timelock{jj}.time,timelock{jj}.avg(i,:),...
					timelock{jj}.var(i,:),c(i,:));
			end
		else
			for i = 1:length(timelock{jj}.label)
				plot(timelock{jj}.time',squeeze(timelock{jj}.trial(:,i,:))',...
					':','Color',c(i,:),'DisplayName',timelock{jj}.label{i});
				plot(timelock{jj}.time',avgfn(squeeze(timelock{jj}.trial(:,i,:)))',...
					'-','Color',c(i,:),'LineWidth',1.5,'DisplayName',timelock{jj}.label{i});
			end
		end
		if length(ana.tlChannels)>1
			cfg = [];
			cfg.linecolor = 'kgrbywrgbkywrgbkywrgbkyw';
			cfg.interactive = 'no';
			cfg.linewidth = 1.5;
			cfg.channel = ana.tlChannels;
			hold on
			ft_singleplotER(cfg,timelock{jj});
		end
		if isnumeric(ana.plotRange);xlim([ana.plotRange(1) ana.plotRange(2)]);end
		box on;grid on; grid minor; axis tight;
		if length(ana.tlChannels)>1 && jj == 1
			legend(cat(1,timelock{1}.label,{'AVG'}));
		elseif jj == 1
			legend(timelock{1}.label);
		end
		if min(ylim)<mn;mn=min(ylim);end
		if max(ylim)>mx;mx=max(ylim);end
		l = line([0 0],ylim,'LineStyle','--','LineWidth',1.25,'Color',[.4 .4 .4]);
		l.Annotation.LegendInformation.IconDisplayStyle = 'off';
		l.ButtonDownFcn = @cloneAxes;
		t = title(['Var: ' num2str(jj) ' = ' vars{jj}]);
		t.ButtonDownFcn = @cloneAxes;
		hz = zoom;hz.ActionPostCallback = @myCallbackZoom;
		hp = pan;hp.ActionPostCallback = @myCallbackZoom;
	end
	interv = info.ana.VEP.Flicker;
	nint = round(max(timelock{1}.time) / interv);
	for j = 1:length(timelock)
		nexttile(tl,j);
		ylim([mn mx]);
		for kk = 1:2:nint
			rectangle('Position',[(kk-1)*interv mn interv mx-mn],...
			'FaceColor',[0.8 0.8 0.8 0.1],'EdgeColor','none');
		end
	end
	t = sprintf('TL: dft=%s demean=%s (%.2f %.2f) detrend=%s poly=%s lp=%.2f hp=%.2f | avg:%s',ana.dftfilter,ana.demean,ana.baseline(1),ana.baseline(2),ana.detrend,ana.polyremoval,ana.lowpass,ana.highpass,num2str(ana.tlChannels));
	tl.XLabel.String = 'Time (s)';
	tl.YLabel.String = 'Amplitude';
	tl.Title.String = [t '\newlineComments: ' info.ana.comments];
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%PLOT POWER ACROSS FREQUENCY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function plotFreqPower()
	[~, f, e] = fileparts(ana.EDFFile);
	h = figure('Name',['TL Data: ' f '.' e],'Units','normalized',...
		'Position',[0.25 0.025 0.25 0.9]);
	if length(timelock) > 8
		tl = tiledlayout(h,'flow','TileSpacing','compact');
	else
		tl = tiledlayout(h,length(timelock),1,'TileSpacing','compact');
	end
	ff = 1/info.ana.VEP.Flicker;
	mn = inf; mx = -inf;
	powf(length(timelock),1) = struct('f0',[],'f1',[],'f2',[]);
	PP = cell(length(timelock),1);
	tlNames = {data_eeg.hdr.label{ana.tlChannels}};
	for j = 1:length(timelock)
		minidx = analysisCore.findNearest(timelock{j}.time, ana.analRange(1));
		maxidx = analysisCore.findNearest(timelock{j}.time, ana.analRange(2));
		nexttile(tl,j)
		hold on
		for ch = 1:length(timelock{j}.label)
			if isfield(timelock{j},'avg')
				dt = timelock{j}.avg(ch,minidx:maxidx);
				[P,f,~,f0,f1,f2] = doFFT(dt);
				plot(f,P,'Color',c(ch,:));
				if any(contains(tlNames,timelock{j}.label{ch}))
					powf(j).f0 = [powf(j).f0 f0];
					powf(j).f1 = [powf(j).f1 f1];
					powf(j).f2 = [powf(j).f2 f2];
				end
				if min(P)<mn;mn=min(P);end
				if max(P)>mx;mx=max(P);end
			else
				dt = squeeze(timelock{j}.trial(:,ch,minidx:maxidx));
				[P,f] = doFFT(avgfn(dt));
				h=plot(f,P,'--','Color',c(ch,:));
				set(get(get(h,'Annotation'),'LegendInformation'),'IconDisplayStyle','off')
				for jj = 1:size(dt,1)
					[P,f,~,f0,f1,f2] = doFFT(dt(jj,:));
					PP{j}(jj,:) = P;
					PP0(j,jj) = f0;
					PP1(j,jj) = f1;
					PP2(j,jj) = f2;
					if any(contains(tlNames,timelock{j}.label{ch}))
						powf(j).f0 = [powf(j).f0 f0];
						powf(j).f1 = [powf(j).f1 f1];
						powf(j).f2 = [powf(j).f2 f2];
					end
				end
				[avg,err] = analysisCore.stderr(PP{j}, ana.errormethod, [], ana.pvalue, [], avgfn);
				analysisCore.areabar(f,avg,err,c(ch,:));
				if min(avg)<mn;mn=min(avg);end
				if max(avg)>mx;mx=max(avg);end
			end
		end
		l = line([[ff ff]',[ff*2 ff*2]'],[ylim' ylim'],'LineStyle','--','LineWidth',1.25,'Color',[.4 .4 .4]);
		l(1).Annotation.LegendInformation.IconDisplayStyle = 'off';
		l(2).Annotation.LegendInformation.IconDisplayStyle = 'off';
		if j==1;legend(timelock{1}.label);end
		box on;grid on; grid minor;
		t = title(['Var: ' num2str(j) ' = ' vars{j}]);
		t.ButtonDownFcn = @cloneAxes;
		hz = zoom;hz.ActionPostCallback = @myCallbackZoom;
		hp = pan;hp.ActionPostCallback = @myCallbackZoom;
	end
	for jj = 1:length(timelock);nexttile(tl,jj);ylim([0 mx]);xlim([-1 35]);end
	t = sprintf('TL: dft=%s demean=%s (%.2f %.2f) detrend=%s poly=%s ANALTIME: %.2f-%.2f',ana.dftfilter,...
		ana.demean,ana.baseline(1),ana.baseline(2),ana.detrend,ana.polyremoval, ana.analRange(1), ana.analRange(2));
	tl.XLabel.String = 'Frequency (Hz)';
	if isfield(timelock{j},'avg')
		tl.YLabel.String = 'FFT Power';
	else
		tl.YLabel.String = ['FFT Power \pm' ana.errormethod];
	end
	tl.Title.String = [t '\newlineComments: ' info.ana.comments];
	
	
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%TUNING CURVES
	[~, f, e] = fileparts(ana.EDFFile);
	h = figure('Name',['TL Data: ' f '.' e],'Units','normalized',...
		'Position',[0.2 0.2 0.6 0.6]);
	tl = tiledlayout(h,'flow','TileSpacing','compact');
	nexttile(tl)
	for i = 1:length(powf)
		if isfield(timelock{j},'avg')
			powf0(i,1) = avgfn(powf(i).f0); powf0err(i,1) = 0;
			powf1(i,1) = avgfn(powf(i).f1); powf1err(i,1) = 0;
			powf2(i,1) = avgfn(powf(i).f2); powf2err(i,1) = 0;
		else
			[powf0(i,1),powf0err(i,:)] = analysisCore.stderr(powf(i).f0, ana.errormethod, [], ana.pvalue, [], avgfn);
			[powf1(i,1),powf1err(i,:)] = analysisCore.stderr(powf(i).f1, ana.errormethod, [], ana.pvalue, [], avgfn);
			[powf2(i,1),powf2err(i,:)] = analysisCore.stderr(powf(i).f2, ana.errormethod, [], ana.pvalue, [], avgfn);
		end
	end
	xa = 1:length(powf0);
	if info.seq.addBlank
		xb = [xa(end) xa(1:end-1)];
		for jj = 1:length(xb)
			if jj == 1
				xlab{jj} = ['blank:' num2str(xb(jj))];
			else
				xlab{jj} = num2str(xb(jj));
			end
		end
		f0 = [powf0(end); powf0(1:end-1)]';
		f1 = [powf1(end); powf1(1:end-1)]';
		f2 = [powf2(end); powf2(1:end-1)]';
		f0err = [powf0err(end,:); powf0err(1:end-1,:)]';
		f1err = [powf1err(end,:); powf1err(1:end-1,:)]';
		f2err = [powf2err(end,:); powf2err(1:end-1,:)]';
	else
		xb = xa;
		f0 = powf0;	f1 = powf1;	f2 = powf2;
		f0err = powf0err; f1err = powf1err; f2err = powf2err;
		for jj = 1:length(xb)
			xlab{jj} = num2str(xb(jj));
		end
	end
	if size(f1err,1)==2
		thrsh = f1err(2,1);
	else
		if isempty(regexpi(ana.errormethod,'SE|SD'))
			thrsh = f1(1) + f1err(1);
		else
			thrsh = f1(1) + f1err(1)*2;
		end
	end
	info.fpower.f0 = f0; info.fpower.f0err = f0err;
	info.fpower.f1 = f1; info.fpower.f1err = f1err;
	info.fpower.f2 = f2; info.fpower.f2err = f2err;
	info.fpower.x = xb;
	info.fpower.xlab = xlab;
	opts = {'Marker','.','MarkerSize',12};
	if max(f0err)==0
		pl = plot(xa,[f0;f1;f2],opts{:});
		pl(1).Color = c(1,:);pl(2).Color = c(2,:);pl(3).Color = c(3,:);
		pl(1).Parent.XTick = xa;
		pl(1).Parent.XTickLabel = xlab;
		pl(1).Parent.XTickLabelRotation=45;
	else
		hold on
		pl = analysisCore.areabar(xa,f0,f0err,c(1,:),0.2,opts{:});
		pl = analysisCore.areabar(xa,f1,f1err,c(2,:),0.2,opts{:});
		pl = analysisCore.areabar(xa,f2,f2err,c(3,:),0.2,opts{:});
		pl = pl.plot;
		l = line(xlim, [thrsh thrsh],'LineStyle','--','LineWidth',2,'Color',[.9 0 0]);
		l.Annotation.LegendInformation.IconDisplayStyle = 'off';
		pl(1).Parent.XTick = xa;
		pl(1).Parent.XTickLabel = xlab;
		pl(1).Parent.XTickLabelRotation=45;
	end
	xlim([0.9 length(xa)+0.1]);
	ymax = max(ylim);
	legend({'0th','1st','2nd'});box on; grid on;
	title(['Flicker Frequency: ' num2str(ff) 'Hz'])
	xlabel('Variable #');
	
	if info.seq.nVars == 2
		lst = info.seq.varList;
		minv = [];
		for jj = 1 : info.seq.nVars
			lv = info.seq.nVar(jj).values;
			minv(jj) = length(unique(lv));
		end
		v1 = [lst{:,3}];
		v1 = unique(v1);
		v1(isnan(v1))=[];
		v2 = [lst{:,4}];
		v2 = unique(v2);
		ctrl = [];
		for jj = 1 : length(v2)
			if isnan(v2(jj))
				ctrl = find(isnan([lst{:,4}]));
				ctrl = ctrl(1);
			else
				p{jj} = find([lst{:,4}] == v2(jj));
			end
		end
		if ~isempty(ctrl)
			v1 = [0 v1];
			for jj = 1 : length(p)
				p{jj} = [ctrl p{jj}];
			end
		end
		
		if info.seq.addBlank
			for blf = 1:length(p)
				p{blf}(1) = 1;
				p{blf}(2:end) = p{blf}(2:end)+1;
			end
		end
% 		if isfield(timelock{j},'avg')
% 			ymax = max(max([f0 f1 f2])) + max(max([f0err f1err f2err]));
% 		else
% 			ymax = max(max([f0err f1err f2err]));
% 		end
% 		ymax = ymax + (ymax/20); 
		for jj = 1 : length(p)
			nexttile(tl); hold on
			if max(f0err)==0
				points=[f0(p{jj}); f1(p{jj}); f2(p{jj})]';
				pl = plot(1:length(p{jj}),points,opts{:});
				pl(1).Color = c(1,:);pl(2).Color = c(2,:);pl(3).Color = c(3,:);
			else
				pl = analysisCore.areabar(1:length(p{jj}),f0(p{jj}),f0err(:,p{jj}),c(1,:),0.1,opts{:});
				pl = analysisCore.areabar(1:length(p{jj}),f1(p{jj}),f1err(:,p{jj}),c(2,:),0.2,opts{:});
				pl = analysisCore.areabar(1:length(p{jj}),f2(p{jj}),f2err(:,p{jj}),c(3,:),0.1,opts{:});
				pl = pl.plot;
				l = line([1 length(p{jj})], [thrsh thrsh],'LineStyle','--','LineWidth',2,'Color',[.9 0 0]);
				l.Annotation.LegendInformation.IconDisplayStyle = 'off';
			end
			pl(1).Parent.XTick = 1:length(p{jj});
			pl(1).Parent.XTickLabel = v1;
			pl(1).Parent.XTickLabelRotation=45;
			xlim([0.9 length(p{jj})+0.1]);
			ylim([0 ymax]);
			title(['Power at ' info.seq.nVar(2).name ': ' num2str(v2(jj))]);
			xlabel(info.seq.nVar(1).name);
			box on;grid on; grid minor;
		end
	end
	if isfield(timelock{j},'avg')
		tl.YLabel.String = 'FFT Power';
	else
		tl.YLabel.String = ['FFT Power \pm' ana.errormethod];
	end
	tl.Title.String = ['Tuning Averages for Channels ' num2str(ana.tlChannels)];
	figure(h);drawnow
	
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%CSF
	
% 	[~, f, e] = fileparts(ana.EDFFile);
% 	h = figure('Name',['TL Data: ' f '.' e],'Units','normalized',...
% 		'Position',[0.2 0.2 0.6 0.6]);
% 	tl = tiledlayout(h,'flow','TileSpacing','compact');
% 	nexttile(tl)
	
	
	
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%PLOT TIME FREQUENCY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function plotFrequency()
	[~, f, e] = fileparts(ana.EDFFile);
	h = figure('Name',['TF Data: ' f '.' e],'Units','normalized',...
		'Position',[0.6 0.025 0.25 0.9]);
	if length(freq) > 8
		tl = tiledlayout(h,'flow','TileSpacing','compact');
	else
		tl = tiledlayout(h,length(freq),1,'TileSpacing','compact');
	end
	
	for jj = 1:length(freq)
		nexttile(tl);
		cfg = [];
		if ~contains(ana.freqbaseline,'none')
			cfg.baseline = ana.freqbaselinevalue;
			cfg.baselinetype = ana.freqbaseline;
		end
		ft_singleplotTFR(cfg,freq{jj});
		line([0 0],[min(ana.freqrange) max(ana.freqrange)],'LineWidth',2);
		xlabel('Time (s)');
		ylabel('Frequency (Hz)');
		box on;grid on; axis tight
		t =title(['Var: ' num2str(jj) ' = ' vars{jj}]);
		t.ButtonDownFcn = @cloneAxes;
	end
	tl.Title.String = 'Time Frequency Analysis';	
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%PLOT RAW DATA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function plotRawChannels()
	% plotting code to visualise the raw data triggers
	offset = 0;
	nchan = length(cfgRaw.header.label);
	h = figure('Name',['RAW Data: ' cfgRaw.dataset],'Units','normalized',...
		'Position',[0.05 0.05 0.4 0.9]);
	tl = tiledlayout(h,nchan,1,'TileSpacing','compact','Padding','none');
	tm = data_raw.time{1};
    if ~isempty(trl)
        xl = [tm(trl(1,1))-1 tm(trl(1,1))+9];
    else
        xl = [10 20];
    end
	for i = 1:nchan
		ch{i} = data_raw.trial{1}(i+offset,:);
		baseline = nanmedian(ch{i});
		ch{i} = (ch{i} - baseline);
		ch{i} = ch{i} / max(ch{i});
		nexttile(tl,i)
		p = plot(tm,ch{i},'k-');
		dtt = p.DataTipTemplate;
		dtt.DataTipRows(1).Format = '%.3f';
		line([min(tm) max(tm)], [0 0],'LineStyle',':','Color',[0.4 0.4 0.4]);
		hold on
		if ~any(ana.bitChannels == i) && (i == 1 || i == ana.pDiode)
			for ii = 1:length(events)
				if ~isempty(events(ii).times)
					y = repmat(ii/10, [1 length(events(ii).times)]);
					plot(events(ii).times,y,'.','MarkerSize',12);
				end
			end
			ylim([-inf inf]);
		elseif any(ana.bitChannels == i)
			ii = i - (ana.bitChannels(1)-1);
			if ~isempty(events(ii).times)
				p=plot(events(ii).times,0.75,'r.','MarkerSize',12);
				dtt = p.DataTipTemplate;
				dtt.DataTipRows(1).Format = '%.3f';
			end
			ylim([-0.05 1.05]);
		end
		if any([ana.dataChannels ana.pDiode] == i) && i == 1 && ~isempty(trl) && size(trl,1) > 1
			ypos = 0.2;
			for jj = 1:size(trl,1) 
				line([tm(trl(jj,1)) tm(trl(jj,2))],[ypos ypos]);
				plot([tm(trl(jj,1)) tm(trl(jj,1)-trl(jj,3)) tm(trl(jj,2)+trl(jj,3))],ypos,'ko','MarkerSize',8);
				%text(tm(trl(jj,1)-trl(jj,3)),ypos,['\leftarrow' num2str(trl(jj,4))]);
				%text(tm(trl(jj,2)+trl(jj,3)),ypos,'\leftarrow255');
				ypos = ypos+0.125;
				if ypos > 1.0; ypos = 0.3;end
			end
			trgVals = num2cell([triggers.value]);
			trgVals = cellfun(@num2str,trgVals,'UniformOutput',false);
			trgTime = [triggers.time];
			trgY = ones(1,length(trgTime));
			text(trgTime,trgY,trgVals);
		end
		title(data_raw.label{i});
		xlim(xl);
	end
	hz = zoom;
	hz.ActionPostCallback = @myCallbackScroll;
	hp = pan;
	hp.enable = 'on';
	hp.Motion = 'horizontal';
	hp.ActionPostCallback = @myCallbackScroll;
	tl.XLabel.String = 'Time (s)';
	tl.YLabel.String = 'Normalised Amplitude';
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function myCallbackScroll(~,event)
	src = event.Axes;
	xl = src.XLim;
	for i = 1:length(src.Parent.Children)
		if i < length(src.Parent.Children)-2
			src.Parent.Children(i).YLim = [-0.05 1.05];
		else
			ylim(src.Parent.Children(i),'auto');
		end
		if ~all(xl == src.Parent.Children(i).XLim)
			src.Parent.Children(i).XLim = xl;
		end
	end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function myCallbackZoom(~,event)
	src = event.Axes;
	xl = src.XLim;
	xy = src.YLim;
	for i = 1:length(src.Parent.Children)
		if isa(src.Parent.Children(i),'matlab.graphics.axis.Axes')
			if ~all(xl == src.Parent.Children(i).XLim)
				src.Parent.Children(i).XLim = xl;
			end
			if ~all(xy == src.Parent.Children(i).YLim)
				src.Parent.Children(i).YLim = xy;
			end
		end
	end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cloneAxes(src,~)
	disp('Cloning axis!')
	if ~isa(src,'matlab.graphics.axis.Axes')
		if isa(src.Parent,'matlab.graphics.axis.Axes')
			src = src.Parent;
		end
	end
	f=figure;
	nsrc = copyobj(src,f);
	nsrc.OuterPosition = [0.05 0.05 0.9 0.9];
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [P, f, A, p0, p1, p2] = doFFT(p)	
	useX = true;
	useHanning = true;
	L = length(p);
	
	fs = data_eeg.fsample;
	ff = (1/info.ana.VEP.Flicker);
	
	if useHanning
		win = hanning(L, 'periodic');
		Pi = fft(p.*win'); 
	else
		Pi = fft(p);
	end

	if useX
		P = abs(Pi/L);
		P=P(1:floor(L/2)+1);
		P(2:end-1) = 2*P(2:end-1);
		f = fs * (0:(L/2))/L;
	else
		NumUniquePts = ceil((L+1)/2);
		P = abs(Pi(1:NumUniquePts));
		f = (0:NumUniquePts-1)*fs/L;
	end

	idx = analysisCore.findNearest(f, ff);
	p1 = P(idx);
	A = angle(Pi(idx));
	idx = analysisCore.findNearest(f, 0);
	p0 = P(idx);
	idx = analysisCore.findNearest(f, ff*2);
	p2 = P(idx);

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function doCSF()
	

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makeSurrogate()
	randPhaseRange			= 2*pi; %how much to randomise phase?
	rphase					= 0; %default phase
	basef					= 1; % base frequency
	onsetf					= 4; %an onset at 0 frequency
	onsetLength				= 3; %length of onset signal
	onsetDivisor			= 2.0; %scale the onset frequency
	burstf					= 30; %small burst frequency
	burstOnset				= 1.0; %time of onset of burst freq
	burstLength				= 1.0; %length of burst
	powerDivisor			= 1; %how much to attenuate the secondary frequencies
	group2Divisor			= 1; %do we use a diff divisor for group 2?
	noiseDivisor			= 0.4; %scale noise to signal
	piMult					= basef * 2; %resultant pi multiplier
	burstMult				= burstf * 2; %resultant pi multiplier
	onsetMult				= onsetf * 2; %onset multiplier
	lowpassNoise			= true;
	options = {['t|' num2str(randPhaseRange)], 'Random phase range in radians?';...
		['t|' num2str(rphase)], 'Default phase?';...
		['t|' num2str(basef)], 'Base Frequency (Hz)';...
		['t|' num2str(onsetf)], 'Onset (time=0) Frequency (Hz)';...
		['t|' num2str(onsetDivisor)], 'Onset F Power Divisor';...
		['t|' num2str(burstf)], 'Burst Frequency (Hz)';...
		['t|' num2str(burstOnset)], 'Burst Onset Time (s)';...
		['t|' num2str(burstLength)], 'Burst Length (s)';...
		['t|' num2str(powerDivisor)], 'Burst Power Divisor';...
		['t|' num2str(group2Divisor)], 'Burst Power Divisor for Group 2';...
		['t|' num2str(noiseDivisor)], 'Noise Divisor';...
		'x|¤Lowpass?','Filter noise?';...
		};
	answer = menuN('Select Surrogate options:',options);
	drawnow;
	if iscell(answer) && ~isempty(answer)
		randPhaseRange = eval(answer{1});
		rphase = str2num(answer{2});
		basef = str2num(answer{3});
		onsetf = str2num(answer{4});
		onsetDivisor = str2num(answer{5});
		burstf = str2num(answer{6});
		burstOnset = str2num(answer{7});
		burstLength = str2num(answer{8});
		powerDivisor = str2num(answer{9});
		group2Divisor = str2num(answer{10});
		noiseDivisor = str2num(answer{11});
		lowpassNoise = logical(answer{12});
	end

	f = data_eeg.fsample; 
	time = data_eeg.time{1};
	maxtime = max(time);
	if onsetLength > maxtime; onsetLength = maxTime - 0.1; end
	if burstLength > maxtime; burstLength = maxTime - 0.1; end
	
	for k = 1:length(data_eeg.trial)
		time = data_eeg.time{k};
		tmult = (length(time)-1) / f; 
		mx = max(data_eeg.trial{k}(end,:));
		mn = min(data_eeg.trial{k}(end,:));
		rn = mx - mn;
		y = createSurrogate();
		y = y * rn; % scale to the voltage range of the original trial
		y = y + mn;
		data_eeg.trial{k}(end,:) = y;
	end
	
	function y = createSurrogate()
		rphase = rand * randPhaseRange;
		%base frequency
		y = sin((0 : (pi*piMult)/f : (pi*piMult) * tmult)+rphase)';
		y = y(1:length(time));
		%burst frequency with different power in group 2 if present
		rphase = rand * randPhaseRange;
		yy = sin((0 : (pi*burstMult)/f : (pi*burstMult) * burstLength)+rphase)';
		if 1
			yy = yy ./ group2Divisor;
		else
			yy = yy ./ powerDivisor;
		end
		%intermediate onset frequency
		rphase = rand * randPhaseRange;
		yyy = sin((0 : (pi*onsetMult)/f : (pi*onsetMult) * onsetLength)+rphase)';
		yyy = yyy ./ onsetDivisor;
		%find our times to inject yy burst frequency
		st = analysisCore.findNearest(time,burstOnset);
		en = st + length(yy)-1;
		y(st:en) = y(st:en) + yy;
		%add our fixed 0.4s intermediate onset freq
		st = analysisCore.findNearest(time,0);
		en = st + length(yyy)-1;
		y(st:en) = y(st:en) + yyy;
		%add our noise
		if lowpassNoise
			y = y + ((lowpass(rand(size(y)),300,f)-0.5)./noiseDivisor);
		else
			y = y + ((rand(size(y))-0.5)./noiseDivisor);
		end
		%normalise our surrogate to be 0-1 range
		y = y - min(y); y = y / max(y); % 0 - 1 range;
		%make sure we are a column vector
		if size(y,2) < size(y,1); y = y'; end
	end
end

end
