%% About function
%
% Name:		ch_vis_singletrials
% Version:	1.11
%
% Christoffer Hatlestad-Hall
%
%
% Date created:			05 Jan 2020
% Date last modified:	01 May 2021
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
%
% SUMMARY:
%
% Function for visualisation of single trials and their average and standard deviation in each specified condition.
%
%
% INPUT:
%
% EEG		|		struct		|		EEGLAB format EEG data.
% cfg		|		struct		|		Struct containing configuration details.
%
% Configuration struct (cfg):
%				.events			|		Cell matrix. Contains the events names which to plot in each sub-figure. See below for details.
%				.cond_label		|		Cell array. Contains the labels to affix each sub-figure. Must match 'events'.
%				.channel		|		Integer/string. The channel (or average of multiple) to plot.
%				.reref			|		Integer/string. Channel(s) to rereference to before plotting ( [] to disable ).
%				.montage		|		Channel montage for conversion between channel indices and labels.
%				.bl_corr		|		[ min, max ]. Baseline period (in ms, relative to event marker) for baseline correction ( [] to disable).
%				.x_limits		|		[ min, max ]. X axis range (in ms, relative to event marker).
%				.x_ticks		|		Number. X axis tick interval.
%				.y_limits		|		[ min, max ]. Y axis range (in microvolt). May be set to 'auto' for automatic formatting.
%				.y_ticks		|		Number. Y axis tick interval.
%
% OUTPUT:
%
% erp_fig	|		fig handle	|		Figure handle to the single trial plot figure.
% st_data	|		matrix		|		Matrix containing single trial data.
% erp		|		matrix		|		Matrix containing ERP data.
% erp_sd	|		matrix		|		Matrix containing ERP SD data.
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
%
% Events configuration elaboration and example:
% cfg.events specifies both which events to plot and how the output figure will be divided into subplots.
% It's a cell matrix, where the rows and columns correspond to subplot rows and columns.
% To average two or more events into one plot, the events should be placed in a cell within the matrix entry.
%
% So, to plot a...		2 x 2 figure:	{ 'Cond_1', 'Cond_2'; 'Cond_3, 'Cond_4 }
%						1 x 4 figure:	{ 'Cond_1'; 'Cond_2'; 'Cond_3; 'Cond_4 }
%						2 x 1 figure:	{ 'Cond_1', 'Cond_2' }
%
% If two or more events needs to be averaged in one plot, replace the string with a cell array ( e.g. { 'Cond_1', { 'Cond_2, 'Cond_3' } } ).
%
% Please note that the matrix must be rectangular; i.e. there cannot be any empty cells. If things don't add up (like with 5, for instance), ...
% enter something not corresponding to any event in the remaining cell. The resulting sub-plot will be empty, but the function will run.
%
% Complete configuration example:
% cfg.events		= { 'Baseline', 'Post 1'; 'Post 2', { 'Baseline', 'Post 1', 'Post 2' }; 'Post 3', { 'Post 4', 'Post 5' } };
% cfg.cond_label	= { 'Baseline', 'Post 1', 'Post 2', 'All' };
% cfg.channel		= 29;
% cfg.reref			= 'AFz';
% cfg.montage		= '64';
% cfg.bl_corr		= [ 0, -100 ];
% cfg.x_limits		= [ -100, 400 ];
% cfg.x_ticks		= 50;
% cfg.y_limits		= 'auto';
% cfg.y_ticks		= 10;
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
function [ erp_fig, st_data, erp, erp_sd ] = ch_vis_singletrials ( EEG, cfg )
%% Prepare the data for plotting

% If channels are specified as characters (in a cell array), convert to indices.
if ~isempty ( cfg.reref )
	if ischar ( cfg.reref ) || iscell ( cfg.reref )
		cfg.reref = ch_channels ( cfg.montage, cfg.reref );
	end
end

if ischar ( cfg.channel ) || iscell ( cfg.channel )
	cfg.channel = ch_channels ( cfg.montage, cfg.channel );
end

% If enabled, rereference.
if ~isempty ( cfg.reref )
	EEG = pop_reref ( EEG, cfg.reref, 'keepref', 'on' );
end

% Extract only the selected events.
events_row = reshape ( cfg.events.', [ 1, numel( cfg.events ) ] );
events_row_all = { };
for c = 1 : numel ( events_row )
	i = numel ( events_row_all );
	if iscell ( events_row{ c } )
		for k = 1 : numel ( events_row{ c } )
			events_row_all{ i + k } = events_row{ c }{ k };		%#ok<AGROW>
		end
	else
		events_row_all{ i + 1 } = events_row{ c };				%#ok<AGROW>
	end
end
events_row_all = unique ( events_row_all );
EEG = pop_selectevent ( EEG, 'type', events_row_all, 'deleteevents', 'on' );

% If enabled, perform baseline correction.
if ~isempty ( cfg.bl_corr )
	if cfg.bl_corr( 1 ) < EEG.times( 1 ), cfg.bl_corr( 1 ) = EEG.times( 1 ); end
	if cfg.bl_corr( 2 ) > EEG.times( end ), cfg.bl_corr( 2 ) = EEG.times( end ); end
	EEG = pop_rmbase ( EEG, cfg.bl_corr );
end

% Extract only the selected channels; if more than one channel, average.
chan_data = EEG.data( cfg.channel, :, : );
if length ( cfg.channel ) > 1
	chan_data = squeeze ( mean( chan_data, 1 ) );
else
	chan_data = squeeze ( chan_data );
end

% Extract single trial data, and compute the ERPs.
st_data		= zeros ( length( events_row ), length( EEG.times ), 1 );
erp			= zeros ( length( events_row ), length( EEG.times ) );
erp_sd		= zeros ( length( events_row ), length( EEG.times ) );
epochs_nb	= zeros ( length( events_row ), 1 );
all_events	= { EEG.epoch.eventtype };
for r = 1 : length ( events_row )
	
	% Identify epochs defined by current event(s).
	epochs = find ( startsWith( all_events, events_row{ r } ) );
	
	% Store the number of epochs included in the condition.
	epochs_nb( r ) = length ( epochs );
	
	% Store the single trial data (condition x datapoints x trial).
	st_data( r, :, 1 : length( epochs ) ) = chan_data( :, epochs );
	
	% Compute average amplitude at all time points.
	erp( r, : ) = mean ( chan_data( :, epochs ), 2 );
	
	% Compute amplitude standard deviation at all time points as well.
	erp_sd( r, : ) = std ( chan_data( :, epochs ), 0, 2 );
end

%% Plot the data

% Retrieve data points corresponding to X axis limits (which are given in milliseconds).
[ ~, minpnt ]	= min ( abs( EEG.times - cfg.x_limits( 1 ) ) );
[ ~, maxpnt ]	= min ( abs( EEG.times - cfg.x_limits( 2 ) ) );
x_limits_t		= [ EEG.times( minpnt ), EEG.times( maxpnt ) ];
x_axis			= cfg.x_limits( 1 ) : cfg.x_ticks : cfg.x_limits( 2 );

% Initialise the figure.
erp_fig = figure ( 'units', 'normalized', 'name', EEG.setname );
try
	fullfig ( gcf );
	if size ( cfg.events, 2 ) == 1 && size ( cfg.events, 1 ) > 1
		erp_fig.OuterPosition( 3 ) = erp_fig.OuterPosition( 3 ) / 2;
		erp_fig.OuterPosition( 1 ) = erp_fig.OuterPosition( 1 ) + erp_fig.OuterPosition( 3 );
	end
catch
end

% Loop through the conditions, creating one subplot for each.
for r = 1 : length ( events_row )
	
	% Create handle for the current subplot.
	sub_erp_fig = subplot ( size( cfg.events, 1 ), size( cfg.events, 2 ), r );
	
	% Plot X and Y axes.
	axes ( sub_erp_fig ); %#ok<LAXES>
	erp_axes = gca;
	
	% Configure axes.
	erp_axes.XLimMode		= 'manual';
	erp_axes.XLim			= [ x_limits_t( 1 ) - 10, x_limits_t( 2 ) + 10 ];
	erp_axes.XTickMode		= 'manual';
	erp_axes.XTick			= x_axis;
	erp_axes.XAxisLocation	= 'origin';
	
	erp_axes.YLimMode		= 'manual';
	if ischar ( cfg.y_limits ) && strcmpi ( cfg.y_limits, 'auto' )
		y_low = round ( min( min( erp ) ) - 5 );
		if mod ( y_low, 2 ) ~= 0, y_low = y_low - 1; end
		y_high = round ( max( max( erp ) ) + 5 );
		if mod ( y_high, 2 ) ~= 0, y_high = y_high + 1; end
	else
		y_low = cfg.y_limits( 1 );
		y_high = cfg.y_limits( 2 );
	end
	erp_axes.YLim			= [ y_low, y_high ];
	erp_axes.YTickMode		= 'manual';
	erp_axes.YTick			= y_low : cfg.y_ticks : y_high;
	erp_axes.YAxisLocation	= 'origin';
	
	erp_axes.Box		= 'on';
	erp_axes.FontSize	= 12;
	
	hold on
	
	% Plot all single trials separately.
	for t = 1 : epochs_nb( r )
		
		% Text.
		% fprintf ( '\nPlotting trial number %d', t );
		
		% Extract data to plot.
		curr_st_data = squeeze ( st_data( r, :, t ) );
		
		% Plot the time series.
		plot ( erp_axes, EEG.times, curr_st_data, 'LineWidth', 0.5, 'Color', [ 0, 0, 0, 0.25 ] );

	end
	
	% Plot the time series.
	plot ( erp_axes, EEG.times, erp( r, : ), 'LineWidth', 2, 'Color', [ 0, 0, 0, 0.5 ] );
	
	% Plot SD.
	% Text.
	% fprintf ( '\n\n\nPlotting stadard deviation for each time point.\n' );
	
	% Plot the standard deviation as a shaded area around the average.
	sd_low	= erp( r, : ) - erp_sd( r, : );
	sd_high = erp( r, : ) + erp_sd( r, : );
	
	plot ( erp_axes, EEG.times, sd_low, 'Color', [ 0, 0, 1, 0.1 ], 'LineWidth', 0.15 );
	plot ( erp_axes, EEG.times, sd_high, 'Color', [ 0, 0, 1, 0.1 ], 'LineWidth', 0.15 );
	
	x_times_2 = [ EEG.times, fliplr( EEG.times ) ];
	area_between = [ sd_low, fliplr( sd_high ) ];
	fill ( x_times_2, area_between, [ 0, 0, 1 ], 'FaceAlpha', 0.1 );
	hold off
	
	% Add condition as title.
	title ( sub_erp_fig, sprintf( '%s (%d trials)', cfg.cond_label{ r }, epochs_nb( r ) ), 'FontSize', 16, 'Color', [ 0.4, 0.4, 0.4 ] );
	
end

% Insert EEG setname as main plot title.
try
	fig_title = mtit ( erp_fig, EEG.setname, 'xoff', 0, 'yoff', 0.045 );
	set ( fig_title.th, 'FontSize', 24, 'FontName', 'Calibri', 'Interpreter', 'none' );
catch
	sgtitle ( erp_fig, EEG.setname, 'FontSize', 20, 'FontName', 'Calibri', 'Interpreter', 'none' );
	% Note: Only available in MATLAB 2018b or later.
end

end