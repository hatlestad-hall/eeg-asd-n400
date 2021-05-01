function ch_timeremaining ( start_time, iteration, total )
%% About function

% Name:		ch_timeremaining
% Version:	1.0

% Christoffer Hatlestad-Hall


% Date created:			15 Jan 2020
% Date last modified:	15 Jan 2020

% ------------------------------------------------------------------------------------------------------------------------------------------------ %

% SUMMARY:

% Function for printing total time elapsed since a tic-defined timepoint up to now and estimate of remaining time.


% INPUT:

% start_time	|	tic object
% iteration		|	current iteration
% total			|	total number of iterations


% OUTPUT:

% Print to command window: 1) total time elapsed, 2) estimate of remaining time.

% ------------------------------------------------------------------------------------------------------------------------------------------------ %

% Calculate and display total elapsed time.
time_hms = datevec ( toc( start_time )./ ( 60 * 60 * 24 ) );
fprintf ( '\n\nTotal elapsed time: %s : %s : %s.\n\n', ...
	num2str ( time_hms( 4 ) ), num2str ( time_hms( 5 ) ), num2str ( round( time_hms( 6 ) ) ) );

% Calculate and display an estimate of the remaining processing time (if not last iteration).
if iteration < total
	est_rem_time = ( toc( start_time ) / iteration ) * ( total - iteration );
	time_hms = datevec ( est_rem_time./ ( 60 * 60 * 24 ) );
	fprintf ( '\n\nEstimated remaining time: %s : %s : %s.\n\n', ...
		num2str( time_hms( 4 ) ), num2str( time_hms( 5 ) ), num2str( round( time_hms( 6 ) ) ) );
end

end