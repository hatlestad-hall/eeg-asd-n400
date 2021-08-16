%% Configuration

% Debug mode.
debug_mode	= false;

% Group.
cfg.group	= 'control';

% Events.
cfg.events.symmetry		= { 'Im B1 Sym',  'Im B2 Sym' };
cfg.events.equivalence	= { 'Im B1 Eqv', 'Im B2 Eqv' };
cfg.events.unrelated	= { 'Im B1 UR1', 'Im B1 UR2', 'Im B2 UR1', 'Im B2 UR2' };

% Re-reference.
cfg.reref		= { 'P9', 'P10' };
% cfg.reref		= [];
cfg.montage		= '64';

% Epoch segmentation.
cfg.epoch.events	= { 'symmetry', 'equivalence', 'unrelated' };
cfg.epoch.limits	= [ -600, 1000 ];
cfg.epoch.baseline	= [ -200, 0 ];

% Epoch rejection.
cfg.ep_rej.channels			= { ...
	'F1', 'F3', 'F5', 'FC5', 'FC3', 'FC1', ...
	'Fz', 'FCz', ...
	'F2', 'F4', 'F6', 'FC6', 'FC4', 'FC2', ...
	'C1', 'C3', 'C5', 'CP5', 'CP3', 'CP1', ...
	'CPz', 'Cz', ...
	'C2', 'C4', 'C6', 'CP6', 'CP4', 'CP2', ...
	'P1', 'P3', 'P5', 'PO3', ...
	'POz', 'Pz', ...
	'P2', 'P4', 'P6', 'PO4' };
cfg.ep_rej.abs_threshold	= [ -75, 75 ];
cfg.ep_rej.abs_timewindow	= [ 0, 500 ];
cfg.ep_rej.prob_thresh_loc	= 5;
cfg.ep_rej.prob_thresh_glob	= 20;

% Single trial plotting (see ch_vis_st_erp for configuration details).
cfg.st_plot.events		= { 'symmetry', 'equivalence'; 'unrelated', { 'symmetry', 'equivalence', 'unrelated' } };
cfg.st_plot.cond_label	= { 'Symmetry', 'Equivalence', 'Unrelated', 'All' };
cfg.st_plot.channel		= { 'Cz', 'FCz', 'CPz' };
cfg.st_plot.reref		= [ ];
cfg.st_plot.montage		= '64';
cfg.st_plot.bl_corr		= [ ];
cfg.st_plot.x_limits	= [ -200, 700 ];
cfg.st_plot.x_ticks		= 50;
cfg.st_plot.y_limits	= 'auto';
cfg.st_plot.y_ticks		= 4;

% Conditions comparison plot.
cfg.comp_plot.events		= { 'symmetry'; 'equivalence'; 'unrelated' };
cfg.comp_plot.cond_label	= { 'Symmetry', 'Equivalence', 'Unrelated' };
cfg.comp_plot.variance		= 'none';
cfg.comp_plot.channel		= { 'Cz', 'FCz', 'CPz' };
cfg.comp_plot.reref			= [ ];
cfg.comp_plot.montage		= '64';
cfg.comp_plot.bl_corr		= [ ];
cfg.comp_plot.colour		= { [ 0, 0, 0, 0.75 ], [ 1, 0, 0, 0.75 ], [ 0, 1, 0, 0.75 ] };
cfg.comp_plot.x_limits		= [ -200, 700 ];
cfg.comp_plot.x_ticks		= 50;
cfg.comp_plot.y_limits		= 'auto';
cfg.comp_plot.y_ticks		= 4;
cfg.comp_plot.visible		= 'off';

%% Preparation

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Make sure EEGLAB and the required plugins, and support
% functions are available on the MATLAB path.
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Select files.
ch_verbose ( 'Select input file(s)...', 2, 2 );
files = ch_selectfiles ( 'set', 'on' );

% Select the output directory.
ch_verbose ( 'Select output directory...', 2, 2 );
output_dir	= [ uigetdir( sprintf( '%s/../', files( 1 ).folder ), 'Select output directory' ) '/' ];
if numel ( output_dir ) < 3, return; end

% If it doesn't exist, create output directory for command window output text file(s).
if ~exist ( sprintf( '%s%s', output_dir, 'CW output files' ), 'dir' )
	mkdir ( sprintf( '%s%s', output_dir, 'CW output files' ) );
end

% Run EEGLAB, and close the GUI.
eeglab;
close;

% Make sure EEGLAB uses double precision, not single.
pop_editoptions ( 'option_single', false );

% If debug mode is enabled, configure to pause on error.
if debug_mode
	dbstop if error
else
	dbclear all
end

% Start timer.
start_time = tic;

%% Processing loop

for file = 1 : numel ( files )
	try
		
		% Clear the log struct in preparation for the upcoming file.
		log = [ ];
		
		% Modify setname.
		[ ~, setname ] = fileparts ( sprintf( '%s/%s', files( file ).folder, files( file ).name ) );
		log.setname = setname;
		
		% Define the text file to which command window output will be written; initiate logging of command window output.
		cw_file = sprintf( '%s%s/CW_%s.txt', output_dir, 'CW output files', setname );
		diary ( cw_file );
		
		% Print loop iteration number.
		ch_output_separator;
		ch_verbose ( sprintf( 'Starting preprocessing of file %d of %d:', file, numel( files ) ), 2, 2 );
		
		% Load file.
		ch_output_separator;
		ch_verbose ( sprintf( 'Loading file: %s...', files( file ).name ), 2, 2 );
		EEG = pop_loadset ( 'filepath', sprintf( '%s/%s', files( file ).folder, files( file ).name ) );
		
		% Add group tag.
		EEG = pop_editset( EEG, 'group', cfg.group );
		
		% Rename relevant events.
		events = { EEG.event.type };
		for r = 1 : numel( cfg.events.symmetry )
			events = strrep( events, cfg.events.symmetry{ r }, 'symmetry' );
		end
		for r = 1 : numel( cfg.events.equivalence )
			events = strrep( events, cfg.events.equivalence{ r }, 'equivalence' );
		end
		for r = 1 : numel( cfg.events.unrelated )
			events = strrep( events, cfg.events.unrelated{ r }, 'unrelated' );
		end
		if size( events, 2 ) > 1, events = events'; end
		for r = 1 : numel( events )
			EEG.event( r ).type = events{ r };
		end
		
		% Re-reference.
		% If necessary, convert channel labels to indices.
		if ~isempty ( cfg.reref )
			ch_output_separator;
			ch_verbose ( 'Re-referencing...', 2, 2 );
			if ischar ( cfg.reref ) || iscell ( cfg.reref )
				reref_chan = ch_channels ( cfg.montage, cfg.reref );
			end
			EEG = pop_reref ( EEG, reref_chan, 'keepref', 'on' );
		end
		
		% Extract epochs (with baseline correction).
		ch_output_separator;
		ch_verbose ( 'Extracting epochs...', 2, 2 );
		EEG = pop_epoch ( EEG, cfg.epoch.events,  cfg.epoch.limits / 1000 );
		EEG = pop_rmbase ( EEG, [ ], ...
			[ ch_find_nearest( EEG.times, cfg.epoch.baseline( 1 ) ), ch_find_nearest( EEG.times, cfg.epoch.baseline( 2 ) ) ] );
		
		% Remove all obsolete, irrelevant events.
		ch_output_separator;
		ch_verbose ( 'Removing all obsolete event markers...', 2, 2 );
		EEG = pop_selectevent ( EEG, 'type', cfg.epoch.events, 'deleteevents', 'on' );
		
		% Register the original number of trials in each condition.
		ch_output_separator;
		ch_verbose ( 'Counting epochs in each condition...', 2, 2 );
		all_events	= { EEG.epoch.eventtype };
		log.orig_epochs_nb = zeros ( 1, length( cfg.epoch.events ) );
		for r = 1 : length ( cfg.epoch.events )
			
			% Identify epochs defined by current event.
			epochs = find ( startsWith( all_events, cfg.epoch.events{ r } ) );
			
			% Store the number of epochs included in the condition.
			log.orig_epochs_nb( r ) = length ( epochs );
			
			% State number of epochs to command window.
			fprintf ( '   %s: %d\n\n', cfg.epoch.events{ r }, length ( epochs ) );
		end
		
		% Inspect epochs for above-threshold amplitudes and low probability of occurance.
		ch_output_separator;
		ch_verbose ( 'Evaluating epochs and rejecting the bad...', 2, 2 );
		
		% Create a temporary EEG structure for evaluation.
		EEG_eprej = EEG;
		
		% If necessary, convert channel labels to indices.
		if ischar ( cfg.ep_rej.channels ) || iscell ( cfg.ep_rej.channels )
			channels = ch_channels ( '64', cfg.ep_rej.channels, false );
		else
			channels = cfg.ep_rej.channels;
		end
		
		% Absolute threshold:
		EEG_eprej = pop_eegthresh ( EEG_eprej, 1, channels, cfg.ep_rej.abs_threshold( 1 ), cfg.ep_rej.abs_threshold( 2 ), ...
			( cfg.ep_rej.abs_timewindow( 1 ) / 1000 ), ( cfg.ep_rej.abs_timewindow( 2 ) / 1000 ), 1, 0 );
		
		% Joint probability criteria:
		EEG_eprej = pop_jointprob ( EEG_eprej, 1, channels, cfg.ep_rej.prob_thresh_loc, cfg.ep_rej.prob_thresh_glob, 0, 0, 0, [ ], 0 );
		
		% Transfer the rejection array from the temporary set to the original set.
		bad_epochs = EEG_eprej.reject.rejthresh;
		bad_epochs( EEG_eprej.reject.rejjp ) = 1;
		
		% Store the number of identified epochs for each method; then, reject the bad epochs.
		log.epochs_rej_abs	= sum ( EEG_eprej.reject.rejthresh );
		log.epochs_rej_prob = sum ( EEG_eprej.reject.rejjp );
		log.epochs_rej_percent = ( sum( [ log.epochs_rej_abs, log.epochs_rej_prob ] ) / sum( log.orig_epochs_nb ) ) * 100;
		EEG = pop_rejepoch ( EEG, bad_epochs, 0 );
		EEG.setname = setname;
		EEG_eprej = [ ];
		
		% Register the remaining number of trials in each condition.
		ch_output_separator;
		ch_verbose ( 'Counting epochs in each condition after epoch rejection...', 2, 2 );
		all_events	= { EEG.epoch.eventtype };
		log.epochs_nb = zeros ( 1, length( cfg.epoch.events ) );
		for r = 1 : length ( cfg.epoch.events )
			
			% Identify epochs defined by current event.
			epochs = find ( startsWith( all_events, cfg.epoch.events{ r } ) );
			
			% Store the number of epochs included in the condition.
			log.epochs_nb( r ) = length ( epochs );
			
			% State number of epochs after epoch rejection to command window.
			ch_verbose ( sprintf( '   %s: %d', cfg.epoch.events{ r }, length ( epochs ) ), 2, 2);
		end
		
		% Generate single-trial plots.
		ch_output_separator;
		ch_verbose ( 'Plotting ERPs - single trial and average with SD...', 2, 2 );
		st_fig = ch_vis_singletrials ( EEG, cfg.st_plot );
		
		% Save and close the figure from ch_vis_singletrials.
		% If the save directory doesn't exist, create it; then save.
		if ~exist ( sprintf( '%s%s', output_dir, 'Single trials plots' ), 'dir' )
			mkdir ( sprintf( '%s%s', output_dir, 'Single trials plots' ) );
		end
		saveas ( st_fig, sprintf( '%s/%s.png', sprintf( '%s%s', output_dir, 'Single trials plots' ), EEG.setname ) );
		close ( st_fig );
		
		% Generate condition comparison plots.
		ch_output_separator;
		ch_verbose ( 'Plotting ERPs - condition averages...', 2, 2 );
		comp_fig = ch_vis_erpcompare ( EEG, cfg.comp_plot );
		
		% Save and close the figure from ch_vis_singletrials.
		% If the save directory doesn't exist, create it; then save.
		if ~exist ( sprintf( '%s%s', output_dir, 'ERP comparison plots' ), 'dir' )
			mkdir ( sprintf( '%s%s', output_dir, 'ERP comparison plots' ) );
		end
		saveas ( comp_fig, sprintf( '%s/%s.png', sprintf( '%s%s', output_dir, 'ERP comparison plots' ), EEG.setname ) );
		close ( comp_fig );
		
		% Save the processed EEG file.
		ch_output_separator;
		ch_verbose ( 'Saving the processed EEG and log files...', 2, 2 );
		pop_saveset ( EEG, 'filename', EEG.setname, 'filepath', output_dir, 'savemode', 'onefile' );
		
		% Save the log file (if the save directory for log files doesn't exist, create it).
		log.configuration = cfg;
		if ~exist ( sprintf( '%s%s', output_dir, 'Log files' ), 'dir' )
			mkdir ( sprintf( '%s%s', output_dir, 'Log files' ) );
		end
		save ( sprintf( '%s/%s_log.mat', sprintf( '%s%s', output_dir, 'Log files' ), EEG.setname ), 'log' );
		
		% Display completion statement and (if not the final file) print the estimated remaining time for the batch.
		ch_output_separator;
		ch_verbose ( sprintf( 'EEG file done: %s.', EEG.setname ), 2, 2 );
		if file ~= numel ( files )
			ch_timeremaining ( start_time, file, numel( files ) );
		end
		
		% Stop recording the command window output.
		diary off
		
	catch error_info
		
		% Display error message.
		ch_verbose ( 'ERROR ENCOUNTERED. Saving information relevant for error analysis. Continuing with next file.', 4, 4 );
		
		% If present, save the error info, EEG file, log and configuration struct for error analysis.
		error_dir = sprintf ( '%s%s_%s/', output_dir, 'Error', EEG.setname );
		mkdir ( error_dir );
		save ( sprintf( '%s%s', error_dir, 'cfg.mat' ), 'cfg' );
		try
			save ( sprintf( '%s%s', error_dir, 'log.mat' ), 'log' );
		catch
		end
		save ( sprintf( '%s%s', error_dir, 'error_info.mat' ), 'error_info' );
		try
			pop_saveset ( EEG, 'filename', EEG.setname, 'filepath', error_dir, 'savemode', 'onefile' );
		catch
			try
				save ( sprintf( '%s%s', error_dir, 'eeg.mat' ), 'EEG' );
			catch
			end
		end
		
		% Print total time elapsed and remaining time estimate.
		ch_timeremaining ( start_time, file, numel( files ) );
		
		% End the command window output recording.
		diary off
		
		% If debug mode is enabled, rethrow error; else, continue to the next file.
		if debug_mode
			ch_verbose ( 'Debug mode enabled. Terminating execution with error.', 2, 2 );
			rethrow ( error_info )
		else
			ch_verbose ( 'Debug mode disabled. Proceeding to the next file.', 2, 2 ); %#ok<*UNRCH>
			continue
		end
	end
end

%% Wrap up

% Print completion statement and total elapsed time.
ch_verbose ( 'Batch completed!', 5, 1 );
