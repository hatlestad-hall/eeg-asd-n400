% asd_extractN400( )

% ASD_EXTRACTN400 extracts the N400 amplitude from epoched EEG files
%
%
%
%
%
% Copyright (C) 2021, Christoffer Hatlestad-Hall
%


% PARAMETERS
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
cfg.time_window = [ 300, 500 ];

cfg.chan_clusters = { ...
	{ 'F1', 'F3', 'F5', 'FC5', 'FC3', 'FC1' }, ...
	{ 'Fz', 'FCz' } ...
	{ 'F2', 'F4', 'F6', 'FC6', 'FC4', 'FC2' }, ...
	{ 'C1', 'C3', 'C5', 'CP5', 'CP3', 'CP1' }, ...
	{ 'CPz', 'Cz' }, ...
	{ 'C2', 'C4', 'C6', 'CP6', 'CP4', 'CP2' }, ...
	{ 'P1', 'P3', 'P5', 'PO3' }, ...
	{ 'POz', 'Pz' }, ...
	{ 'P2', 'P4', 'P6', 'PO4' } };

cfg.cluster_labels = { 'C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'C9' };

% cfg.timelocks = { 'related', 'unrelated' };
cfg.timelocks = { 'symmetry', 'equivalence', 'unrelated' };

% cfg.cond_labels = { 'IM_REL', 'IM_UNR' };
cfg.cond_labels = { 'IM_SYM', 'IM_EQV', 'IM_UNR' };

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% select files
files = ch_selectfiles( 'set', 'on' );

% generate a list of subject identifiers to use as row names
sub_list = cell( numel( files ), 1 );
for s = 1 : numel( files )
	[ ~, sub_list{ s } ] = fileparts( sprintf( '%s\\%s', files( s ).folder, files( s ).name ) );
end

% set up the summary table
out = array2table( zeros( numel( files ), numel( cfg.cluster_labels ) * numel( cfg.timelocks ) ), 'RowNames', sub_list );

% add the subject identifiers as the first table variable (easier when exporting to *.xlsx)
out = addvars( out, sub_list, 'Before', 1, 'NewVariableNames', 'Sub_ID' );

% collect group tags
group_list = cell( numel( files ), 1 );

% loop subjects
for f = 1 : numel( files )
	
	% load the file
	EEG = pop_loadset( sprintf( '%s\\%s', files( f ).folder, files( f ).name ) );
	group_list{ f } = EEG.group;
	
	% get the time samples corresponding to the time window limits
	time_low = ch_find_nearest( EEG.times, cfg.time_window( 1 ) );
	time_upp = ch_find_nearest( EEG.times, cfg.time_window( 2 ) );
	
	% set the column tracker
	col = 1;
	
	% loop the timelock events
	for t = 1 : numel( cfg.timelocks )
		
		% identify the epochs from which the average amplitude should be extracted
		all_events	= { EEG.event.type };
		epochs		= [ EEG.event( ismember( all_events, cfg.timelocks{ t } ) ).epoch ];
		
		% loop the channel clusters
		for c = 1 : numel( cfg.cluster_labels )
			measures		= zeros( length( epochs ), 1 );
			chan_indices	= ch_channels( '64', cfg.chan_clusters{ c } );
			
			% loop the epochs
			for e = 1 : length( epochs )
				measures( e ) = mean( EEG.data( chan_indices, time_low : time_upp, epochs( e ) ), 'all' );
			end
			
			% add the cluster average to the output table
			col = col + 1;
			out{ f, col } = mean( measures );
			out.Properties.VariableNames{ col } = sprintf( '%s_%s', cfg.cond_labels{ t }, cfg.cluster_labels{ c } );
		end
	end
end

% add group identifier as the second table variable
out = addvars( out, group_list, 'After', 1, 'NewVariableNames', 'Group' );

% write the output table to an Excel spreadsheet
writetable( out, sprintf( '%s\\n400.xlsx', files( 1 ).folder ) );

