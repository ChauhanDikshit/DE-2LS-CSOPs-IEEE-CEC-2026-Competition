%% ========================================================================
%  U-score Calculation for CEC 2026 CSOPs
%  ------------------------------------------------------------------------
%  Author      : Dikshit Chauhan
%  Affiliation : Department of Electrical and Computer Engineering,
%                National University of Singapore
%  Contact     : dikshitchauhan608@gmail.com 
%  Purpose     : This script computes the pairwise U-score for constrained
%                single-objective optimization problems (CSOPs) using the
%                official CEC 2026-style accuracy and speed scoring procedure.
%
%  Description :
%     - Loads progress-curve files for all selected algorithms.
%     - Uses Min_EV and LCV trajectories for feasibility-aware comparison.
%     - Computes accuracy score, speed score, total U-score, and ranks.
%     - Exports the final results into Excel format.
%
%  Notes:
%     - Min_EV represents the best feasible objective-error trajectory.
%     - LCV represents the lowest constraint violation trajectory.
%     - Larger U-score indicates better overall performance.
%
%  Created/Updated: 02-Jun-2026
% ========================================================================

%% ===================== USER SETTINGS =====================
clear all;
clc;

%% ===================== SETTINGS =====================
pro   = 28;      % number of CSOP functions
trial = 25;      % number of independent runs
num   = 2000;    % number of saved progress points
D     = 30;      % dimension, used only in filenames

saveResults = true;

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(scriptDir);

% if exist('uscore_nAlgorithms_CSOP_pairwise', 'file') ~= 2
%     error(['uscore_nAlgorithms_CSOP_pairwise.m was not found. ', ...
%            'Place it in the same folder as this script or add it to the MATLAB path.']);
% end

% algNames = {'AEBDE','AGEA','CL-SRDE','DE_2LS','RDE26','RDEx','UDE_III','UDE_IV', 'RDEx_CASK'};   % algorithm folder names (must match folder name in merged dir)
% algFns = {@load_AEBDE,@load_AGEA,@load_CL_SRDE,@load_DE_2LS,@load_RDE26,@load_RDEx,@load_UDE_III,@load_UDE_IV,@load_RDEx_CASK};

algNames = {'AEBDE','CL-SRDE','DE_2LS','RDE26','RDEx','UDE_III','UDE_IV', 'RDEx_CASK'};   % algorithm folder names (must match folder name in merged dir)
algFns = {@load_AEBDE,@load_CL_SRDE,@load_DE_2LS,@load_RDE26,@load_RDEx,@load_UDE_III,@load_UDE_IV,@load_RDEx_CASK};


%% ===================== BUILD ALGORITHM STRUCT =====================
algs = struct('name', {}, 'getT', {});
% Decide per algorithm which folder to use
for a = 1:numel(algNames)
    algs(a).name = algNames{a};

    switch algNames{a}
        % --- these live in folderr ---
        case {'AEBDE','AGEA','CL-SRDE','DE_2LS','RDE26','RDEx','UDE_III','UDE_IV','RDEx_CASK'}
            algs(a).getT = @(f) algFns{a}(scriptDir, f, num, trial);
        otherwise
            error('Unknown algorithm name: %s', algNames{a});
    end
end


%% pairwise---As mentioned in the technical report
[SR, score, scoreTbl, rankTbl, srTotAll, Data, speedPart, accuracyPart] = uscore_CSOPs(pro, trial, num, algs);
nAlg = numel(algs);
% ---------------- Overall U-score ----------------
u_score = sum(score, 1);

fprintf('\nU-score of all algorithms using pairwise CSOP code:\n');
disp(array2table(u_score, 'VariableNames', local_valid_names(algNames, 'Uscore_')));

fprintf('Best U-score: %.6g\n', max(u_score));

%% ===================== DETAILED OUTPUT TABLE =====================
algLabels = string({algs.name});
algLabels = string(local_valid_names(algNames, ''));

accuracyPart = accuracyPart(:, 1:nAlg);
speedPart    = speedPart(:, 1:nAlg);
rawTotal     = accuracyPart + speedPart;
adjustedU    = score(:, 1:nAlg);
rankPart     = SR(:, 1:nAlg);

allData = [accuracyPart, speedPart, rawTotal, adjustedU, rankPart];


% Create variable names automatically
varNames = [ ...
    strcat("Accuracy ", algLabels), ...
    strcat("Speed ", algLabels), ...
    strcat("RawTotal ", algLabels), ...
    strcat("Uscore ", algLabels), ...
    strcat("Rank ", algLabels) ...
];

% Convert to table
dataTbl = array2table(allData, 'VariableNames', cellstr(varNames));
% Add function number
dataTbl = addvars(dataTbl, (1:pro)', 'Before', 1, 'NewVariableNames', 'Function');

% ---------------- Add summary row ----------------
summaryRow = dataTbl(1, :);
for j = 1:width(summaryRow)
    if isnumeric(summaryRow{1,j})
        summaryRow{1,j} = NaN;
    end
end
summaryRow.Function = NaN;
% Sum accuracy, speed, raw total, adjusted U-score, and ranks
summaryRow{1, 2:end} = sum(dataTbl{:, 2:end}, 1);
dataTbl = [dataTbl; summaryRow];

% Overall table.
overallTbl = table(string(algNames(:)), accuracyPart(end,:)'*0, ...
    'VariableNames', {'Algorithm','Dummy'});
overallTbl.Dummy = [];
overallTbl.TotalAccuracy = sum(accuracyPart, 1)';
overallTbl.TotalSpeed    = sum(speedPart, 1)';
overallTbl.TotalUscore   = u_score(:);
overallTbl.RankSum       = sum(SR, 1)';

[~, bestIdx] = max(overallTbl.TotalUscore);
overallTbl.IsBest = false(height(overallTbl),1);
overallTbl.IsBest(bestIdx) = true;

disp('Overall summary:');
disp(overallTbl);

%% ===================== SAVE RESULTS =====================
if saveResults
outputDir = fullfile(pwd, 'USCORE_Output');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    xlsxFile = fullfile(outputDir, sprintf('USCORE_CSOP_pairwise_%dAlg_%dF_%dRuns.xlsx', nAlg, pro, trial));

writetable(overallTbl, xlsxFile, 'Sheet', 'Overall_Uscore');
writetable(dataTbl,    xlsxFile, 'Sheet', 'Accuracy_Speed_Uscore');
writetable(scoreTbl,   xlsxFile, 'Sheet', 'Score_Table');
writetable(rankTbl,    xlsxFile, 'Sheet', 'Rank_Table');

 % Optional diagnostic fields from Data, if available.
    if isstruct(Data)
        try
            diagTbl = struct2table(Data);
            writetable(diagTbl, xlsxFile, 'Sheet', 'Diagnostics');
        catch
            % Some Data structures may contain non-table-compatible fields.
            save(fullfile(outputDir, 'USCORE_Diagnostics_Data.mat'), 'Data');
        end
    end

    save(fullfile(outputDir, 'USCORE_CSOP_workspace.mat'), ...
        'SR', 'score', 'scoreTbl', 'rankTbl', 'srTotAll', 'Data', ...
        'speedPart', 'accuracyPart', 'u_score', 'overallTbl', 'dataTbl', ...
        'algNames', 'pro', 'trial', 'num', 'D');

    fprintf('\nU-score Excel file saved:\n%s\n', xlsxFile);
    fprintf('Workspace MAT file saved in:\n%s\n', outputDir);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function T = load_AEBDE(folderr, f, num, run)
    file = fullfile(folderr,'AEBDE', sprintf('PaperID_CEC26_CSOP_F%d.txt', f));
%     T = load(file,'-ascii');  
    T = load(file);
    T = T(1:num,2:end);
end

function T = load_AGEA(folderr, f, num, run)
    file = fullfile(folderr,'AGEA_C06', sprintf('AGEA_F%d_Min_LCV.mat', f));
%     T = load(file,'-ascii');  
    T = load(file);
    T = T.data_mat(1:num,:);
end

function T = load_CL_SRDE(folderr, f, num, run)
    file = fullfile(folderr,'CL_SRDE_2025', sprintf('CL_SRDE_2025_F%d_Min_EV.mat', f));
    T = load(file);       
    T = T.Min_EV(1:num,:);
end

function T = load_DE_2LS(folderr, f, num, run)
    file = fullfile(folderr, 'DE-2LS',sprintf('DE-2LS_F%d_D30.txt', f));
    T = load(file); %T=T';      
    % T = T.CECResults(1:num,:);
    T = T(1:num,:);
end

function T = load_RDEx_CASK(folderr, f, num, run)
    file = fullfile(folderr, 'RDEx_CASK',sprintf('RDEx_CASK_F%d_D30.txt', f));
    T = load(file); %T=T';      
    % T = T.CECResults(1:num,:);
    T = T(1:num,:);
end

function T = load_RDE26(folderr, f, num, run)
    file = fullfile(folderr,'rde26_csop', sprintf('rde26_csop_F%d_Min_EV.mat', f));
    T = load(file);       
    T = T.Min_EV(1:num,:);
end

function T = load_RDEx(folderr, f, num, run)
    file = fullfile(folderr, 'rdex-csop',sprintf('CORDEx_2025_F%d_Min_EV.mat', f));
    T = load(file); T=T';      
    % T = T.CECResults(1:num,:);
    T = T.Min_EV(1:num,:);
end

function T = load_UDE_III(folderr, f, num, run)
    file = fullfile(folderr,'UDEIII', sprintf('UDEIII_2024_2025_F%d_Min_EV.mat', f));
    T = load(file);       
    T = T.Min_EV(1:num,:);
end

function T = load_UDE_IV(folderr, f, num, run)
    file = fullfile(folderr,'UDE_IV', sprintf('UDEIV_%d_30.mat', f));
    T = load(file,'-ascii');
    T = T(1:num,:);
end


function names = local_valid_names(rawNames, prefix)
    rawNames = string(rawNames);
    names = matlab.lang.makeValidName(strcat(prefix, rawNames));
    names = matlab.lang.makeUniqueStrings(cellstr(names));
end

