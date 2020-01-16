%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% pprintMathML.Txl
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Revision History
% v 1.0.0 Original Version: Richard Zanibbi, Feb 13 2013 22:10:51
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

include "Grammars/CROHME_InkML.Grammar"

define program
		[mexpression]
end define

function main
	replace [program]
		M[mexpression]

	by
		M
end function
