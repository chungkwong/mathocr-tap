%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% pprintCROHME.Txl
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Revision History
% v 1.0.0 Original Version: Richard Zanibbi, Feb 13 2013 22:10:43
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

include "Grammars/CROHME_InkML.Grammar"

define program
		[crohme_inkml_file]
end define

function main
	replace [program]
		M[program]

	by
		M
end function
