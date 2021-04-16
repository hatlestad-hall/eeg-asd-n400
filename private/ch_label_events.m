function [ EEG, EventsTally ] = ch_label_events ( EEG, TimeLockEvents, ResetType, Rename )
%% ABOUT
%
% FUNCTION
% Replaces original event labels in EEG.event.type with custom strings, while ...
% backing up the existing EEG.event.type structure to EEG.event.code
%
% INPUT ARGUMENTS
% - EEG:			EEG structure
% - TimeLockEvents: Nx4 cell array (see below for syntax)
% - ResetType:		For this function to work, EEG.event.type must be numbers (not strings).
%					true = field is strings  |  false = field is numbers (default)
% - Rename:			If this function has been run previously, and a renaming of events ...
%					is warranted, the EEG.event.type field must be reverted to original ...
%					using the EEG.event.code field which was established during the first run
%					true = rename  |  false = first-time run (default)
%
% OUTPUT
% - EEG:			EEG structure with new labels
% - EventsTally:	A summary of the number of events corresponding to each label
%
% SYNTAX
% Cell array for each event containing the following:
% {1, x, x, x} = Original trigger code(s). Single number or number array
% {x, 2, x, x} = Context code. Single number or number array. [] to disable
% {x, x, 3, x} = Context time frame (seconds). Positive or negative number. [] to disable
% {x, x, x, 4} = New event label (string)
%
% NOTES
% * If context code is specified, a time frame must be specified as well
%
% EXAMPLES
% Rename original trigger code 4 to 'Trigger 4':
% - TimeLockEvents{1} = {4, [], [], 'Trigger 4'};
%
% Rename original trigger code 8 and 9 to 'Correct', but only if succeeded by ...
% trigger code 3 within two seconds:
% - TimeLockEvents{1} = {[8, 9], 3, 2, 'Correct'};

%% Run event labeling function

% Disable 'ResetType' and 'Rename' if arguments aren't provided.
if nargin < 3, ResetType = false; Rename = false; end
if nargin < 4, Rename = false; end

if ResetType
	% Reset EEG.type back to numbers (from strings).
	for i = 1 : length ( EEG.event )
		EEG.event( i ).type = str2double (EEG.event( i ).type);
	end
end

if ~Rename
	% Backup original 'type' entries.
	for i = 1 : length ( EEG.event )
		EEG.event( i ).code = EEG.event( i ).type;
	end
	
else
	% Restore original 'type' entries.
	for i = 1 : length ( EEG.event )
		EEG.event( i ).type = EEG.event( i ).code;
	end
end

% Retrieve total number of new event types.
[ ~, nbNewEventTypes ] = size ( TimeLockEvents );

% Retrieve total number of events.
nbEvents = length ( EEG.event );

% Convert 'type' field to characters.
for i = 1 : nbEvents
	EEG.event( i ).type = num2str ( EEG.event( i ).type );
end

% Loop: New event types.
for n = 1 : nbNewEventTypes
	
	% Get original code, context code, context time frame, and new label for current new event.
	orgEvent = cell2mat ( TimeLockEvents{ 1, n }( 1 ) );
	conEvent = cell2mat ( TimeLockEvents{ 1, n }( 2 ) );
	timeFrame = cell2mat ( TimeLockEvents{ 1, n }( 3 ) );
	eventLabel = char ( TimeLockEvents{ 1, n }( 4 ) );
	
	% Convert current time frame to points.
	timePoints = abs ( timeFrame ) * EEG.srate;
	
	% Loop: Check each event if it matches the current new event type.
	for i = 1 : nbEvents
		
		if ~isempty ( find( orgEvent == EEG.event( i ).code, 1 ) )
			
			% Check if the current event depends on a specified context.
			conCheck = isempty ( conEvent );
			
			if ~conCheck
				
				% Determine whether context time frame is positive or negative.
				if timeFrame > 0, timePos = 1; else, timePos = 0; end
				
				% Determine how many adjacent events to check for context code.
				if timePos == 1 && i ~= nbEvents % Subsequent events.
					nbCon = 1;
					eventLat = EEG.event( i ).latency;
					nbActCon = 0;
					
					while eventLat + timePoints > EEG.event( i + nbCon ).latency
						nbCon = nbCon + 1;
						nbActCon = nbActCon + 1;
						if i + nbCon > nbEvents, break; end
					end
					
					% Check if any of the subsequent events within the time frame contains the context code.
					if nbActCon ~= 0
						
						searchAct = 1;
						for c = 1 : nbActCon
							
							if searchAct == 1 && ~isempty ( find( conEvent == EEG.event( i + c ).code, 1 ) )
								conFound = 1;
								searchAct = 0;
							elseif searchAct == 1
								conFound = 0;
							end
							
						end
						
					else
						conFound = 0;
						
					end
					
					% If context code is found within the time frame, rename the event.
					if conFound
						EEG.event( i ).type = eventLabel;
					end
					
				elseif timePos == 0 && i ~= 1 % Preceding events.
					nbCon = 1;
					eventLat = EEG.event( i ).latency;
					nbActCon = 0;
					
					while eventLat - timePoints < EEG.event( i + nbCon ).latency
						nbCon = nbCon + 1;
						nbActCon = nbActCon + 1;
						if i + nbCon > nbEvents, break; end
					end
					
					% Check if any of the subsequent events within the time frame contains the context code.
					if nbActCon ~= 0
						
						searchAct = 1;
						for c = 1 : nbActCon
							
							if searchAct == 1 && ~isempty ( find( conEvent == EEG.event( i - c ).code, 1 ) )
								conFound = 1;
								searchAct = 0;
							elseif searchAct == 1
								conFound = 0;
							end
						end
						
					else
						conFound = 0;
						
					end
					
					% If context code is found within the time frame, rename the event.
					if conFound
						EEG.event( i ).type = eventLabel;
					end
				end
				
			else % If event is not dependent on a context code.
				EEG.event( i ).type = eventLabel;
				
			end
			
		end
	end
end

% Compute event stats.
[ ~, NUM.events ] = size ( TimeLockEvents );
NUM.allevents = length ( EEG.event );
for event = 1 : NUM.events
	NUM.tally = 0;
	label = '';
	for allevent = 1 : NUM.allevents
		label = char ( TimeLockEvents{ 1, event }( 4 ) );
		if strcmp ( EEG.event( allevent ).type, label )
			NUM.tally = NUM.tally + 1;
		end
	end
	EventsTally( event ).Event = label; %#ok<*AGROW>
	EventsTally( event ).Tally = NUM.tally;
	
% 	EventsTally.stats( event ).event = label;
% 	EventsTally.stats( event ).tally = NUM.tally;
end

end