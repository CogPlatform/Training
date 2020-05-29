function runEEGAnalysis(ana)

ana.table.Data =[]; drawnow;
ft_defaults;
info = load(ana.MATFile);
info.seq.showLog();drawnow;
vars = getVariables;

data_raw = []; trl=[];triggers=[];events=[];
if ana.plotTriggers
	cfgRaw				= [];
	cfgRaw.dataset		= ana.EDFFile;
	cfgRaw.header		= ft_read_header(cfgRaw.dataset);
	cfgRaw.continuous	= 'yes';
	cfgRaw.channel		= 'all';
	cfgRaw.demean		= 'yes';
	cfgRaw.detrend		= 'yes';
	cfgRaw.polyremoval = 'yes';
	cfgRaw.chanindx	= ana.bitChannels;
	cfgRaw.threshold	= ana.threshold;
	cfgRaw.jitter		= ana.jitter;
	cfgRaw.minTrigger	= ana.minTrigger;
	cfgRaw.preTime		= ana.preTime;
	data_raw				= ft_preprocessing(cfgRaw);
	[trl, events, triggers] = loadCOGEEG(cfgRaw);
	plotRawChannels(); drawnow;
end

cfg					= [];
cfg.dataset			= ana.EDFFile;
cfg.continuous		= 'yes';
cfg.trialfun		= 'loadCOGEEG';
cfg.chanindx		= ana.bitChannels;
cfg.threshold		= ana.threshold;
cfg.jitter			= ana.jitter;
cfg.minTrigger		= ana.minTrigger;
cfg.preTime			= ana.preTime;
cfg					= ft_definetrial(cfg);
cfg.dftfilter		= ana.dftfilter;
cfg.demean			= ana.demean;
cfg.detrend			= ana.detrend;
cfg.polyremoval	= ana.polyremoval;
cfg.baselinewindow= ana.baseline;
cfg.channel			= ana.dataChannels;
data_eeg			= ft_preprocessing(cfg);
info.data_cfg		= cfg;

varmap				= unique(data_eeg.trialinfo);
timelock				= cell(length(varmap),1);
freq					= cell(length(varmap),1);
for j = 1:length(varmap)
	cfg				= [];
	cfg.trials		= find(data_eeg.trialinfo==varmap(j));
	cfg.keeptrials	= ana.keeptrials;
	cfg.latency		= ana.latency;
	timelock{j}		= ft_timelockanalysis(cfg,data_eeg);
	cfg				= [];
	cfg.trials		= find(data_eeg.trialinfo==varmap(j));
	cfg.channel		= 1;
	cfg.method		= 'mtmconvol';
	cfg.taper		= ana.freqtaper;
	cfg.pad			= 'nextpow2';
	cfg.foi			= ana.freqrange;                         % analysis 2 to 30 Hz in steps of 2 Hz
	cfg.t_ftimwin	= ones(length(cfg.foi),1).*0.2;   % length of time window = 0.5 sec
	cfg.toi			= -0.5:0.05:1;                  % time window "slides" from -0.5 to 1.5 sec in steps of 0.05 sec (50 ms)
	freq{j}			= ft_freqanalysis(cfg,data_eeg);
end

plotTimeLock();
plotFrequency();

info.timelock		= timelock;
info.freq			= freq;
info.data_raw		= data_raw;
info.data_eeg		= data_eeg;
info.triggers		= triggers;
assignin('base','info',info);

col1 = info.seq.outIndex;if size(col1,1)<size(col1,2); col1=col1';end
col2 = info.data_eeg.trialinfo;if size(col2,1)<size(col2,2); col2=col2';end
col3 = vars; if size(col3,1)<size(col3,2); col3=col3';end
col4 = 1:length(col3); if size(col4,1)<size(col4,2); col4=col4';end

maxn = max([length(col1) length(col2) length(col3) length(col4)]);
if length(col1) < maxn; col1(end+1:maxn) = NaN; end
if length(col2) < maxn; col2(end+1:maxn) = NaN; end
if length(col3) < maxn; col3(end+1:maxn) = ' '; end
if length(col4) < maxn; col4(end+1:maxn) = NaN; end
tdata = table(col1,col2,col3,col4,'VariableNames',{'Triggers Sent','Data Triggers','Stimulus Value','Index'});
ana.table.Data = tdata;
drawnow;


%==========================================SUB FUNCTIONS

function vars = getVariables()
	if isprop(info.seq,'varLabels')
		vars = info.seq.varLabels;
	else
		vars = cell(1,info.seq.minBlocks);
	end
end

function plotTimeLock()
	h = figure('Name',['TL Data: ' ana.EDFFile],'Units','normalized',...
		'Position',[0 0.1 0.3 0.9]);
	tl = tiledlayout(h,length(timelock),1,'TileSpacing','compact');
	for jj = 1:length(timelock)
		nexttile(tl,jj)
		ft_singleplotER(struct('channel',[1 2]),timelock{jj});
		if isfield(timelock{jj},'avg')
			hold on
			areabar(timelock{jj}.time,timelock{jj}.avg(1,:),timelock{jj}.var(1,:),[0.6 0.6 0.6]);
			areabar(timelock{jj}.time,timelock{jj}.avg(2,:),timelock{jj}.var(2,:),[0.9 0.6 0.6]);
		end
		box on;grid on; axis tight;
		xlim([ana.plotRange(1) ana.plotRange(2)]);
		line([0 0],ylim,'LineWidth',1,'Color','k');
		title(['Var: ' num2str(jj) ' = ' vars{jj}]);
	end
	
	t = sprintf('TL: dft=%s demean=%s (%.2f %.2f) detrend=%s poly=%s',ana.dftfilter,ana.demean,ana.baseline(1),ana.baseline(2),ana.detrend,ana.polyremoval);
	tl.XLabel.String = 'Time (s)';
	tl.YLabel.String = 'Amplitude';
	tl.Title.String = t;
end

function plotFrequency()
	h = figure('Name',['TF Data: ' ana.EDFFile],'Units','normalized',...
		'Position',[0.3 0.1 0.3 0.9]);
	tl = tiledlayout(h,'flow');
	for jj = 1:length(freq)
		nexttile(tl)
		cfg = [];
		cfg.baseline = ana.freqbaselinevalue;
		cfg.baselinetype = ana.freqbaseline;
		%cfg.xlim = [-0.3 1];
		ft_singleplotTFR(cfg,freq{jj});
		line([0 0],[min(ana.freqrange) max(ana.freqrange)],'LineWidth',2);
		xlabel('Time (s)');
		ylabel('Frequency (Hz)');
		box on;grid on; axis tight
		title(['Var: ' num2str(jj) ' = ' vars{jj}]);
	end
	tl.Title.String = 'Time Frequency Analysis';	
end

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
		baseline = median(ch{i}(1:100));
		ch{i} = (ch{i} - baseline);
		ch{i} = ch{i} / max(ch{i});
		nexttile(tl,i)
		p = plot(tm,ch{i},'k-'); 
		dtt = p.DataTipTemplate;
		dtt.DataTipRows(1).Format = '%.3f';
		hold on
		if any([ana.dataChannels ana.pDiode] == i)
			for ii = 1:length(events)
				y = repmat(ii/10, [1 length(events(ii).times)]);
				p = plot(events(ii).times,y,'.','MarkerSize',12);
				dtt = p.DataTipTemplate;
				dtt.DataTipRows(1).Format = '%.3f';
			end
			ylim([-inf inf]);
		else
			ii = i - (ana.bitChannels(1)-1);
			if ~isempty(events(ii).times);plot(events(ii).times,0.75,'r.','MarkerSize',12);end
			ylim([-0.05 1.05]);
		end
		if any([ana.dataChannels ana.pDiode] == i) && i == 1 && ~isempty(trl)
			ypos = 0.2;
			for jj = 1:size(trl,1) 
				line([tm(trl(jj,1)) tm(trl(jj,2))],[ypos ypos]);
				plot([tm(trl(jj,1)) tm(trl(jj,1)-trl(jj,3)) tm(trl(jj,2)+trl(jj,3))],ypos,'ko','MarkerSize',8);
				text(tm(trl(jj,1)-trl(jj,3)),ypos,['\leftarrow' num2str(trl(jj,4))]);
				text(tm(trl(jj,2)+trl(jj,3)),ypos,'\leftarrow255');
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

function [idx,val,delta]=findNearest(in,value)
	%find nearest value in a vector, if more than 1 index return the first	
	[~,idx] = min(abs(in - value));
	val = in(idx);
	delta = abs(value - val);
end

end
