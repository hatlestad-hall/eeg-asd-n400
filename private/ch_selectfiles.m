function files = ch_selectfiles ( ext, multisel, defdir )
%% About

% Name:		ch_selectfiles
% Version:	1.2

% Christoffer Hatlestad-Hall


% Date created:			29 Oct 2019
% Date last modified:	20 Dec 2019

% ------------------------------------------------------------------------------------------------------------------------------------------------ %

% SUMMARY:

% Support function: Opens up file selection GUI, and returns a 'dir' compatible structure for the selected file(s).


% INPUT:

% ext			|		string		|		File extension to filter by (default: 'set').
% multisel		|		string		|		Multi-select 'on' or 'off'.
% defdir		|		string		|		Path to the GUI default directory (default: path to current working directory).



% OUTPUT:

% files			|		struct		|		Struct containing info about the selected files.

% ------------------------------------------------------------------------------------------------------------------------------------------------ %

%% Evaluate the input arguments

% Set default values to missing argument(s).
if nargin == 0
	ext = 'set';
	multisel = 'on';
	defdir = strrep ( sprintf( '%s/', pwd ), '\', '/' );
elseif nargin == 1
	multisel = 'on';
	defdir = strrep ( sprintf( '%s/', pwd ), '\', '/' );
elseif nargin == 2
	defdir = strrep ( sprintf( '%s/', pwd ), '\', '/' );
end

% Make sure the default directory path ends in '/'.
defdir = strrep ( defdir, '\', '/' );
if ~endsWith ( defdir, '/' )
	defdir = sprintf ( '%s/', defdir );
end

%% Function body

% Open the GUI for file selection.
[ filename, filepath ] = uigetfile ( sprintf( '*.%s', ext ), sprintf( 'Select file(s) (*.%s)', ext ), ...
	defdir, 'MultiSelect', multisel );

% If user canceled the selection, throw error.
if ~iscell ( filename ) && ~ischar ( filename )
	error ( 'ch_selectfiles: Error. User canceled file selection.' );
end

% List all the files in the directory with the specified extension.
all_files = dir ( sprintf( '%s*.%s', filepath, ext ) );

% Extract only the rows containing the selected file(s).
all_filenames = { all_files.name };
file_indices_1 = find ( startsWith( all_filenames, filename ) );
file_indices_2 = find ( endsWith( all_filenames, filename ) );
file_indices = intersect ( file_indices_1, file_indices_2 );

files = all_files( file_indices );

end