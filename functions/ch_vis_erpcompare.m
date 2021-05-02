%% About function
%
% Name:		ch_vis_comp_erp
% Version:	1.1
%
% Christoffer Hatlestad-Hall
%
%
% Date created:			10 Jan 2020
% Date last modified:	02 Apr 2020
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
%
% SUMMARY:
%
% This function generates a figure in which selected ERPs are compared.
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
%				.variance		|		String. Variance measure to compute; 'sd', 'sem' or 'none'.
%				.channel		|		Integer/string. The channel (or average of multiple) to plot.
%				.reref			|		Integer/string. Channel(s) to rereference to before plotting ( [] to disable ).
%				.montage		|		Channel montage for conversion between channel indices and labels.
%				.bl_corr		|		[ min, max ]. Baseline period (in ms, relative to event marker) for baseline correction ( [] to disable).
%				.colour			|		Cell array. Line colours ( [ r, g, b, alpha ] ); corresponds to 'cfg.events' rows.
%				.x_limits		|		[ min, max ]. X axis range (in ms, relative to event marker).
%				.x_ticks		|		Number. X axis tick interval.
%				.y_limits		|		[ min, max ]. Y axis range (in microvolt). May be set to 'auto' for automatic formatting.
%				.y_ticks		|		Number. Y axis tick interval.
%				.visible		|		String. Toggle figure visibility, 'on' or 'off'.
%
%
% OUTPUT:
%
% erp_fig	|		fig handle	|		Figure handle to the comparison plot figure.
% erp		|		matrix		|		Matrix containing ERP data.
% erp_sd	|		matrix		|		Matrix containing ERP SD data.
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
function [ erp_fig, erp, erp_sd ] = ch_vis_erpcompare ( EEG, cfg )
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

% Compute the ERPs.
erp			= zeros ( length( events_row ), length( EEG.times ) );
erp_sd		= zeros ( length( events_row ), length( EEG.times ) );
epochs_nb	= zeros ( length( events_row ), 1 );
all_events	= { EEG.epoch.eventtype };
for r = 1 : length ( events_row )
	
	% Identify epochs defined by current event(s).
	epochs = find ( contains( all_events, events_row{ r } ) );
	
	% Store the number of epochs included in the condition.
	epochs_nb( r ) = length ( epochs );
	
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
erp_fig = figure ( 'units', 'normalized', 'name', EEG.setname, 'visible', cfg.visible );
try
	fullfig ( gcf );
catch
end

% Plot X and Y axes.
axes ( erp_fig );
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
erp_axes.YGrid		= 'on';
erp_axes.GridAlpha	= 0.25;

erp_axes.Box		= 'on';
erp_axes.FontSize	= 12;

hold on

% Plot all conditions separately.
erp_series = zeros ( 1, size ( erp, 1 ) );
for r = 1 : size ( erp, 1 )
	
	% Plot the time series.
	erp_series( r ) = plot ( erp_axes, EEG.times, erp( r, : ), 'LineWidth', 2, 'Color', cfg.colour{ r } );
	
	switch lower ( cfg.variance )
		case 'sd'
			
			% Plot the standard deviation as a shaded area around the average.
			sd_low	= erp( r, : ) - erp_sd( r, : );
			sd_high = erp( r, : ) + erp_sd( r, : );
			
		case 'sem'
			
			% Plot the standard error as a shaded area around the average.
			sd_low	= erp( r, : ) - ( erp_sd( r, : ) ./ sqrt ( epochs_nb( r ) ) );
			sd_high = erp( r, : ) + ( erp_sd( r, : ) ./ sqrt ( epochs_nb( r ) ) );
	end
	
	if ~strcmpi ( cfg.variance, 'none' )
		plot ( erp_axes, EEG.times, sd_low, 'Color', [ cfg.colour{ r }( 1 ), cfg.colour{ r }( 2 ), cfg.colour{ r }( 3 ), 0.1 ], 'LineWidth', 0.15 );
		plot ( erp_axes, EEG.times, sd_high, 'Color', [ cfg.colour{ r }( 1 ), cfg.colour{ r }( 2 ), cfg.colour{ r }( 3 ), 0.1 ], 'LineWidth', 0.15 );
		
		x_times_2 = [ EEG.times, fliplr( EEG.times ) ];
		area_between = [ sd_low, fliplr( sd_high ) ];
		fill ( x_times_2, area_between, [ cfg.colour{ r }( 1 ), cfg.colour{ r }( 2 ), cfg.colour{ r }( 3 ) ], 'FaceAlpha', 0.075 );
	end
end

% Generate time series names.
series_names = cell ( 1, size( cfg.events, 1 ) );
for n = 1 : length ( series_names )
	series_names{ n } = sprintf ( '%s (%d trials)', cfg.cond_label{ n }, epochs_nb( n ) );
end

% Insert legend.
legend ( erp_series, series_names, 'Location', 'northeast', 'FontSize', 18, 'Interpreter', 'none');

% Insert setname as title.
if strcmpi ( cfg.variance, 'sem' ), var_str = 'SEM'; elseif strcmpi ( cfg.variance, 'sd' ), var_str = 'SD'; else, var_str = 'Average'; end
title ( sprintf( '%s  |  %s', EEG.setname, var_str ), 'FontSize', 24, 'Color', [ 0, 0, 0 ], 'Interpreter', 'none' );

end