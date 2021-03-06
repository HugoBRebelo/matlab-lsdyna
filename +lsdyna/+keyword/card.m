classdef card < lsdyna.keyword.card_base
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    %% CONSTRUCTOR
    methods
        function this = card(Keyword,String,varargin)
            % Allow empty constructor
            if ~nargin
                return;
            end
            
            % Ensure strings for proper iteration
            Keyword = string(Keyword);
            
            % Allow multiple cards at once
            if ~isscalar(Keyword)
                nCards = numel(Keyword);
                this(nCards) = lsdyna.keyword.card();
                for i = 1:nCards
                    this(i) = lsdyna.keyword.card(Keyword(i),String{i});
                end
                return;
            end
            
            % Instantiate single object
            this.Keyword = Keyword;
            this.String = String;
            %this.String = split(String,newline);
        end
    end
    
    methods
        function strs = sca_dataToString(C)
            % By default return the card's String (no data referenced)
            strs = C.String;
        end
    end
    
    %% CONSTRUCTOR UTILITY methods
    
    methods (Hidden)
        function subclassObj = assignPropsToSubclass(this, subclassObj)
            % A utility method to assign all properties of this parent
            % class to a given (newly instantiated, likely empty, subclass)
            parentMC = metaclass(this);
            parentProps = parentMC.PropertyList;
            for i = find(~[parentProps.Dependent])
                propName = parentProps(i).Name;
                subclassObj.(propName) = this.(propName);
            end
        end
    end
    
    %% PARSER UTILITY methods
    methods (Static)
        function strs = convertCommaSepStrsToSpacedStrs(strs,charSpaces)
            % Utility function that takes an array of strings and replaces
            % those elements with comma-separated values (one style of
            % lsdyna deck input) with the more standard fixed-position
            % input with the number of characters per data field provided.
            
            % First find the strings that actually need adjusting
            hasCommaInds = find(contains(strs,","))';
            if isempty(hasCommaInds)
                return;
            end
            charSpaces = charSpaces(:)';
            % Next, make a char array (this will auto-pad on the right)
            strsChar = char(strs(hasCommaInds));
            % Particularly for massive chunks of text it is very slow to
            % call strsplit on commas for each line. Instead, break the big
            % chunk of text into chunks that have the commas in the exact
            % same left-t-right index along the char array.
            [unqCommasMask,~,grps] = unique(strsChar==',','rows');
            for grpNo = 1:size(unqCommasMask,1)
                % All lines now have commas in the same place. Do a manual
                % split by picking out the text before/after each comma
                commaInds = find(unqCommasMask(grpNo,:));
                fromInds = [1 commaInds+1];
                toInds = [commaInds-1 size(unqCommasMask,2)];
                unqStrChars = strsChar(grps==grpNo,:);
                % Pick out the pieces of each delimited set of chars
                nPieces = length(fromInds);
                pieces = strtrim(arrayfun(@(from,to)...
                    unqStrChars(:,from:to),fromInds,toInds,'Un',0));
                if any(cellfun(@(x)size(x,2),pieces) > charSpaces(1:nPieces))
                    error("lsdyna:badFormText",strjoin([
                        "Text delimited by commas had more characters"
                        "than the defined size of the card."]))
                end
                for pieceNo = 1:nPieces
                    pieces{pieceNo}(:,end+1:charSpaces(pieceNo)) = ' ';
                end
                strs(hasCommaInds(grps==grpNo)) = string([pieces{:}]);
            end
        end
        
        function DATAMAT = convertSpacedStrsToMatrix(strs,FLDS)
            % Convert an array of strings into a matrix of data

            nFlds = height(FLDS);
            % Convert strings to char matrix for use in sscanf which is the
            % fastest way to bulk-read fixed width data.
            charMat = char(strs);
            % And ensure that the charMat is at least as wide as expected
            charMat(:,FLDS.endChar(end)+1) = ' ';
            % MATLAB, however, is terrible at true fixed-width reading
            % because it doesn't acknowledge spaces as taking up width (see
            % https://www.mathworks.com/matlabcentral/answers/110381). So
            % we need to artificially add a default (0) value for fields
            % that are total whitespace:
            charMat(charMat==char(0)) = ' ';
            for i = 1:nFlds
                emptyMask = all(charMat(:,FLDS.charInds{i}) == ' ',2);
                charMat(emptyMask,FLDS.endChar(i)) = '0';
            end
            % and we need to add an extra separator character between
            % fields in case the full field width is taken up by data such
            % as '1111    23333' which becomes [1111 2333 3] instead of
            % [1111 2 3333] if we don't add a separator. We therefore have
            % source colNos (into charMat) and shifted targetColNos.
            srcCols = [FLDS.charInds{:}];
            % Columns will shift right with one extra char per field
            colPads = num2cell(cumsum(0:nFlds-1)');
            tarColInds = cellfun(@(o,e)o+e,FLDS.charInds,colPads,'Un',0);
            tarCols = [tarColInds{:}];
            % Initialize the separated char mat with spaces and then fill
            charMatAndSep = repmat(' ',size(charMat,1), tarCols(end)+1);
            charMatAndSep(:,tarCols) = charMat(:,srcCols);
            % Now we can finally use sscanf to read the data
            fmtStr = strjoin("%" + FLDS.size + FLDS.fmt," ") + " ";
            DATAMAT = reshape(sscanf(charMatAndSep',fmtStr), nFlds,[])';
        end
    end
end

