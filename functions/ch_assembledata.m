function [ segments, segs_plot ] = ch_assembledata ( EEG, cfg )
%% About function
%
% Name:		ch_assembledata
% Version:	1.12
%
% Christoffer Hatlestad-Hall
%
%
% Date created:			28 Jan 2020
% Date last modified:	01 Apr 2020
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
%
% SUMMARY:
%
% -
%
%
% INPUT:
%
% EEG		|		struct		|		EEGLAB format data. Note that the EEG.event.type field must contain strings.
% cfg		|		struct		|		Configuration struct. See below for details.
%
% Configuration struct (cfg):
%				.event_limits	|		Cell matrix defining the events to used as limits for each segment. Each row defines a separate segment.
%										The first column is the start event, and the second column the end event.
%										Events must be strings, and can contain a wildcard (*).
%				.min_max		|		A matrix denoting the selection of events in the case of multiple instances.
%										Note that MinMax must be equal to EventLimits in size.
%										Enter 0 to use the first instance of the event, or 1 to use the last.
%				.shift			|		Number of seconds to move the limit relative to the corresponding event in 'event_limits'.
%										Note that Shift must be equal to EventLimits in size.
%										Positive values increases limit latency, whereas negative values decreases.
%				.labels			|		Cell containing strings denoting the label to assign each segment.
%										The label will be appended to the saved data filename.
%										Note that the number of labels must match the number of segments to extract.
%				.plot_segs		|		Boolean. Plot segments overview.
%
%
% OUTPUT:
%
% segments		|		array		|		Time ranges for the output segments (in seconds relative to file start).
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
%
% Example cfg structure:
%
% cfg.event_limits	= { 'RSEC start', 'RSEC end'; 'RSEO start', 'RSEO end'; 'VNO buffer', 'VNO*' };
% cfg.min_max		= [ 0, 0; 0, 0; 0, 1 ];
% cfg.shift			= [ -1, 1; -1, 1; -2, 2 ];
% cfg.labels		= { 'RSEC', 'RSEO', 'VNO' };
% cfg.plot_segs		= true;
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %

%% Validate the input arguments

% Make sure the EEG.event.type field contains strings.
if ~ischar ( EEG.event( 1 ).type )
	error ( 'ch_segment: Error. EEG.event.type field must contain strings.' );
end

% Make sure the 'event_limits', 'min_max', and 'shift' matrices have equal sizes.
if ~isequal ( size( cfg.event_limits ), size( cfg.shift ), size( cfg.min_max ) )
	error ( 'ch_segment: Error. The sizes of ''event_limits'', ''min_max'', and ''shift'' must be equal.' );
end

% Make sure the number of segments to be extracted matches the number of labels.
if ~isequal ( size( cfg.event_limits, 1 ), numel( cfg.labels ) )
	error ( 'ch_segment: Error. The number of segments to be extracted must match the number of labels.' );
end

%% Prepare for processing

% Get the original set name.
setname = EEG.setname;

% Determine the number of segments which will be extracted.
nb_segments = size ( cfg.event_limits, 1 );

% Set up the output log structures.
segments = struct ( 'label', cell( 1, nb_segments ), 'start_time', cell( 1, nb_segments ), 'end_time', cell( 1, nb_segments ) );

%% Loop through n times, extracting one segment each iteration.

fprintf ( '\n\n   ch_assembledata: Extracting segments from %s...\n\n', setname );

for s = 1 : nb_segments
	
	% Determine if either of the current iteration's events contain wildcards.
	if contains ( cfg.event_limits{ s, 1 }, '*' )
		if strfind ( cfg.event_limits{ s, 1 }, '*' ) == 1
			wildc_start = 'ends';
		elseif strfind ( cfg.event_limits{ s, 1 }, '*' ) == length ( cfg.event_limits{ s, 1 } )
			wildc_start = 'starts';
		else
			wildc_start = 'off';
		end
	else
		wildc_start = 'off';
	end
	
	if contains ( cfg.event_limits{ s, 2 }, '*' )
		if strfind ( cfg.event_limits{ s, 2 }, '*' ) == 1
			wildc_end = 'ends';
		elseif strfind ( cfg.event_limits{ s, 2 }, '*' ) == length ( cfg.event_limits{ s, 2 } )
			wildc_end = 'starts';
		else
			wildc_end = 'off';
		end
	else
		wildc_end = 'off';
	end
	
	% Set up the min/max functions for both of the current iteration's limits.
	% For the start limit:
	if cfg.min_max( s, 1 ) == 0
		min_max_fnc_start = @min;
		
	elseif cfg.min_max( s, 1 ) == 1
		min_max_fnc_start = @max;
		
	else
		error ( 'ch_assembledata: Error. ''min_max'' matrix cannot contain numbers other than 1 or 0.' );
	end
	
	% For the end limit:
	if cfg.min_max( s, 2 ) == 0
		min_max_fnc_end = @min;
		
	elseif cfg.min_max( s, 2 ) == 1
		min_max_fnc_end = @max;
		
	else
		error ( 'ch_assembledata: Error. ''min_max'' matrix cannot contain numbers other than 1 or 0.' );
	end
	
	% Get the start limit in seconds. If the function returns more than one instance of the event, select the specified.
	[ ~, start_sec ] = ch_eventlatencies ( EEG, cfg.event_limits{ s, 1 }, wildc_start );
	if numel ( start_sec ) > 1
		start_sec = min_max_fnc_start ( start_sec );
		
	elseif numel ( start_sec ) == 0 % If no event exists, and function gives an empty array, skip to next iteration.
		fprintf ( '\n\nch_assembledata: Warning. Start event for %s not found.\n\n', cfg.labels{ s } );
		segments( s ).label			= cfg.labels{ s };
		segments( s ).start_time	= NaN;
		segments( s ).end_time		= NaN;
		continue
	end
	
	% Adjust the latency with the corresponding buffer value.
	start_sec = start_sec + cfg.shift( s, 1 );
	
	% Get the end limit in seconds. If the function returns more than one instance of the event, select the specified.
	[ ~, end_sec ] = ch_eventlatencies ( EEG, cfg.event_limits{ s, 2 }, wildc_end );
	if numel ( end_sec ) > 1
		end_sec = min_max_fnc_end ( end_sec );
		
	elseif numel ( end_sec ) == 0 % If no event exists, and function gives an empty array, skip to next iteration.
		fprintf ( '\n\nch_assembledata: Warning. End event for %s not found.\n\n', cfg.labels{ s } );
		segments( s ).label			= cfg.labels{ s };
		segments( s ).start_time	= NaN;
		segments( s ).end_time		= NaN;
		continue
	end
	
	% Adjust the latency with the corresponding buffer value.
	end_sec = end_sec + cfg.shift( s, 2 );
	
	% Update the output log structure with info about the start and end times.
	segments( s ).label			= cfg.labels{ s };
	segments( s ).start_time	= start_sec;
	segments( s ).end_time		= end_sec;
end

% Sort the segments after latency.
segments = nestedSortStruct ( segments, 'start_time' );

if cfg.plot_segs == true
	
	% Compute binary arrays for each segment.
	segs_bin = zeros ( nb_segments, size( EEG.times, 2 ) );
	for s = 1 : nb_segments
		if ~isnan ( segments( s ).start_time )
			segs_bin( s, ceil( segments( s ).start_time * EEG.srate ) : floor( ( segments( s ).end_time * EEG.srate ) ) ) = 1;
		end
	end
	
	% Create the figure.
	segs_plot = figure ( 'units', 'normalized', 'outerposition', [ 0.10, 0.4, 0.80, 0.5 ], 'Name', EEG.setname );
	
	% Plot X and Y axes.
	axes ( segs_plot );
	segs_axes = gca;
	
	% Plot overview of bad segments.
	hold on
	area_col = { 'red', 'green', 'cyan', 'magenta', 'yellow', 'blue' };
	for s = 1 : nb_segments
		area ( segs_bin( s, : ), 'FaceColor', area_col{ s }, 'EdgeColor', 'black', 'FaceAlpha', 0.60 );
	end
	hold off
	
	% Add title and legend to the plot.
	title ( sprintf( '%s   |   Extracted segments (seconds)', EEG.setname ), 'Interpreter', 'none' );
	legend ( { segments.label }, 'Orientation', 'horizontal', 'Location', 'southoutside', 'FontSize', 20, 'Interpreter', 'none' );
	
	% Compute adjusted X axis ticks.
	x_tick = EEG.times( end ) / 1000 / 30;
	if x_tick >= 80
		x_tick = roundn ( x_tick, 2 ) * 2;
	elseif x_tick >= 50
		x_tick = roundn ( x_tick, 2 );
	else
		x_tick = roundn ( x_tick, 1 );
	end
	
	% Adjust the axes.
	segs_axes.XLim						= [ 0, length( EEG.times ) ];
	segs_axes.YLim						= [ 0.5, 1 ];
	segs_axes.XTick						= 0 : x_tick * EEG.srate : length( EEG.times );
	segs_axes.XTickLabel				= 0 : x_tick : length( EEG.times ) / EEG.srate;
	segs_axes.YTick						= [ ];
	segs_axes.FontSize					= 12;
	segs_axes.FontName					= 'Calibri';
	segs_axes.TitleFontSizeMultiplier	= 1.25;
	segs_axes.Box						= 'on';
end

%% Wrap up the function

% Display completion statement.
fprintf ( '\n\n' )
fprintf ( '   ch_assembledata:	   %s done.\n\n', setname );
fprintf ( '                      The following segments have been extracted:\n\n' );
for p = 1 : nb_segments
	fprintf ( '                         %s:   %.2f   to   %.2f (seconds).\n', ...
		segments( p ).label, segments( p ).start_time, segments( p ).end_time );
end

end