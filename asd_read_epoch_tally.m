% Log directory (choose one)
%logdir = '/Volumes/T7 Shield/Datasets/Unsorted/ASD-N400/ASD-N400/October 2020-May 2021/Preprocessed epoch/Images related-unrelated/Mastoid reference/Log files';
%logdir = '/Volumes/T7 Shield/Datasets/Unsorted/ASD-N400/ASD-N400/October 2020-May 2021/Preprocessed epoch/Images symmetry-equivalence-unrelated/Mastoid reference/Log files';
logdir = '/Volumes/T7 Shield/Datasets/Unsorted/ASD-N400/ASD-N400/October 2020-May 2021/Preprocessed epoch/Words related-unrelated/Mastoid reference/Log files';

% List the files in the log directory
files = dir( sprintf( '%s/*.mat', logdir ) );

% Loop the log files
for f = 1 : numel( files )
    logfile = load( sprintf( '%s/%s', files( f ).folder, files( f ).name ) );
    tally( f ).group = logfile.log.configuration.group;
    for i = 1 : length( logfile.log.epochs_nb )
        tally( f ).( logfile.log.configuration.epoch.events{ i } ) = logfile.log.epochs_nb( i );
    end
end
