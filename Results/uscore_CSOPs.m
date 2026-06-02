function [SR, score, scoreTbl, rankTbl, srTotAll, Data, sr1, ac1] = ...
    uscore_nAlgorithms_CSOP_pairwise(pro, trial, num, algs, epsCV, epsEV)
%USCORE_NALGORITHMS_CSOP_PAIRWISE
% Official-style CEC 2026 CSOP score for n algorithms using pairwise
% accuracy and speed comparisons.
%
% This function is intended for constrained single-objective problems (CSOPs).
% It follows the CEC 2026 technical-report idea:
%   - Each trial stores Min_EV and LCV along the run.
%   - Accuracy score A is computed by pairwise comparison of final trials.
%   - Speed score S is computed by pairwise comparison of the first cut-point
%     where each trial reaches the pairwise reference value.
%   - Final problem score = A + S.
%
% IMPORTANT:
%   There is NO global TGT in the official CSOP rule.
%   The previous target-based U-score is not used here.
%
% INPUTS
%   pro   : number of functions/problems, e.g., 28
%   trial : number of independent runs per algorithm, e.g., 25
%   num   : number of saved sampling points, e.g., 2001 for CEC2026 CSOP
%           if initial population + every 10D evaluations are saved.
%   algs  : struct array with fields:
%           algs(a).name : algorithm name
%           algs(a).getT : function handle, X = algs(a).getT(f)
%
%   epsCV : feasibility tolerance for LCV. Default = 1e-8.
%   epsEV : precision/tie tolerance for Min_EV. Default = 1e-8.
%
% ACCEPTED OUTPUT FORMAT FROM algs(a).getT(f)
%
%   Option 1: struct output
%       X.Min_EV or X.MinEV or X.EV or X.Obj : num x trial Min_EV matrix
%       X.LCV    or X.CV                     : num x trial LCV matrix
%       X.FEs or X.FE                         : optional num x 1 FE vector
%
%   Option 2: numeric official/interleaved matrix without FE column
%       X(:,1) = Min_EV run 1
%       X(:,2) = LCV    run 1
%       X(:,3) = Min_EV run 2
%       X(:,4) = LCV    run 2
%       ...
%
%   Option 3: numeric official/interleaved matrix with FE column
%       X(:,1) = FEs
%       X(:,2) = Min_EV run 1
%       X(:,3) = LCV    run 1
%       X(:,4) = Min_EV run 2
%       X(:,5) = LCV    run 2
%       ...
%
% OUTPUTS
%   SR        : pro x nAlg rank matrix. Rank 1 is best. Larger score is better.
%   score     : pro x nAlg official CSOP score = accuracy + speed.
%   scoreTbl  : table of official scores with sum row.
%   rankTbl   : table of ranks with sum row.
%   srTotAll  : same as score, kept for compatibility with previous code.
%   Data      : diagnostic struct.
%   sr1       : pro x nAlg speed score S.
%   ac1       : pro x nAlg accuracy score A.
%
% NOTE ABOUT Min_EV AND LCV
%   Min_EV should be NaN at a sampling point if no feasible solution exists.
%   LCV should be the population's lowest overall constraint violation.
%   Min_EV values smaller than epsEV are set to zero.
%   LCV values smaller than epsCV are set to zero.
%
% Author note:
%   This version is pairwise and feasibility-aware. It avoids mixing objective
%   values and constraint-violation values in a single global target.

    if nargin < 5 || isempty(epsCV)
        epsCV = 1e-8;
    end
    if nargin < 6 || isempty(epsEV)
        epsEV = 1e-8;
    end

    if ~isstruct(algs) || ~isfield(algs, 'name') || ~isfield(algs, 'getT')
        error('algs must be a struct array with fields name and getT.');
    end

    nAlg = numel(algs);
    nTotalTrials = nAlg * trial;
    nPairs = nTotalTrials * (nTotalTrials - 1) / 2;

    % Output arrays
    ac1      = zeros(pro, nAlg);    % accuracy score A
    sr1      = zeros(pro, nAlg);    % speed score S
    score    = zeros(pro, nAlg);    % official score A + S
    srTotAll = zeros(pro, nAlg);    % compatibility name for score
    SR       = zeros(pro, nAlg);    % rank per function

    % Diagnostics
    Data = struct();
    Data.epsCV = epsCV;
    Data.epsEV = epsEV;
    Data.nAlgorithms = nAlg;
    Data.nTrialsPerAlgorithm = trial;
    Data.nTotalTrials = nTotalTrials;
    Data.nPairsPerFunction = nPairs;
    Data.NumFinalFeasible = zeros(pro, nAlg);
    Data.NumFinalInfeasible = zeros(pro, nAlg);
    Data.MeanFinalMinEV_Feasible = nan(pro, nAlg);
    Data.MeanFinalLCV = nan(pro, nAlg);
    Data.BestFinalLCV = nan(pro, nAlg);
    Data.PairwiseAccuracyTrialScore = cell(pro,1);
    Data.PairwiseSpeedTrialScore = cell(pro,1);

    % Algorithm labels for output tables
    algLabels = matlab.lang.makeValidName(string({algs.name}));
    algLabels = matlab.lang.makeUniqueStrings(cellstr(algLabels));
    tableVarNames = [{'Function'}, algLabels];

    for f = 1:pro

        % ==============================================================
        % 1) Load Min_EV and LCV for all algorithms and concatenate trials
        % ==============================================================
        MinEV_all = nan(num, nTotalTrials);
        LCV_all   = inf(num, nTotalTrials);
        algID     = zeros(1, nTotalTrials);

        colStart = 1;
        for a = 1:nAlg
            X = algs(a).getT(f);
            [MinEV, LCV] = parseCSOPData(X, trial, num, algs(a).name, f, epsCV, epsEV);

            cols = colStart:(colStart + trial - 1);
            MinEV_all(:, cols) = MinEV;
            LCV_all(:, cols)   = LCV;
            algID(cols)        = a;

            colStart = colStart + trial;
        end

        % Final values at MaxFEs
        finalEV  = MinEV_all(end, :);
        finalLCV = LCV_all(end, :);

        % A final trial is feasible if LCV is zero/tiny and Min_EV exists.
        finalFeas = (finalLCV <= epsCV) & isfinite(finalEV) & ~isnan(finalEV);

        % Diagnostics per algorithm
        for a = 1:nAlg
            idxA = (algID == a);
            Data.NumFinalFeasible(f,a)   = sum(finalFeas(idxA));
            Data.NumFinalInfeasible(f,a) = sum(~finalFeas(idxA));
            Data.MeanFinalLCV(f,a)       = mean(finalLCV(idxA), 'omitnan');
            Data.BestFinalLCV(f,a)       = min(finalLCV(idxA));

            feasA = idxA & finalFeas;
            if any(feasA)
                Data.MeanFinalMinEV_Feasible(f,a) = mean(finalEV(feasA), 'omitnan');
            end
        end

        % ==============================================================
        % 2) Pairwise comparisons among all trials
        % ==============================================================
        accTrial   = zeros(1, nTotalTrials);  % accuracy points per trial
        speedTrial = zeros(1, nTotalTrials);  % speed points per trial

        for p = 1:(nTotalTrials - 1)
            for q = (p + 1):nTotalTrials

                % ------------------------------------------------------
                % 2a) Accuracy score A
                % ------------------------------------------------------
                % Rule 1: both feasible -> compare final Min_EV
                % Rule 2: both infeasible -> compare final LCV
                % Rule 3: one feasible -> feasible trial wins
                if finalFeas(p) && finalFeas(q)
                    cmp = compareSmallerIsBetter(finalEV(p), finalEV(q), epsEV);
                    [accTrial(p), accTrial(q)] = addPairPoint(accTrial(p), accTrial(q), cmp);

                elseif ~finalFeas(p) && ~finalFeas(q)
                    cmp = compareSmallerIsBetter(finalLCV(p), finalLCV(q), epsCV);
                    [accTrial(p), accTrial(q)] = addPairPoint(accTrial(p), accTrial(q), cmp);

                elseif finalFeas(p) && ~finalFeas(q)
                    accTrial(p) = accTrial(p) + 1;

                else
                    accTrial(q) = accTrial(q) + 1;
                end

                % ------------------------------------------------------
                % 2b) Speed score S
                % ------------------------------------------------------
                % If both trials are feasible at MaxFEs, compare the first
                % cut-point at which each reaches the worse of the two final
                % Min_EV values.
                %
                % If one or both trials are infeasible at MaxFEs, compare the
                % first cut-point at which each reaches the worse of the two
                % final LCV values.
                if finalFeas(p) && finalFeas(q)
                    theta = max(finalEV(p), finalEV(q));
                    tauP = firstReach(MinEV_all(:,p), theta, epsEV);
                    tauQ = firstReach(MinEV_all(:,q), theta, epsEV);
                else
                    theta = max(finalLCV(p), finalLCV(q));
                    tauP = firstReach(LCV_all(:,p), theta, epsCV);
                    tauQ = firstReach(LCV_all(:,q), theta, epsCV);
                end

                if tauP < tauQ
                    speedTrial(p) = speedTrial(p) + 1;
                elseif tauQ < tauP
                    speedTrial(q) = speedTrial(q) + 1;
                else
                    speedTrial(p) = speedTrial(p) + 0.5;
                    speedTrial(q) = speedTrial(q) + 0.5;
                end
            end
        end

        Data.PairwiseAccuracyTrialScore{f} = accTrial;
        Data.PairwiseSpeedTrialScore{f}    = speedTrial;

        % ==============================================================
        % 3) Aggregate trial points to algorithm-level scores
        % ==============================================================
        for a = 1:nAlg
            idxA = (algID == a);
            ac1(f,a) = sum(accTrial(idxA));
            sr1(f,a) = sum(speedTrial(idxA));
        end

        srTot = ac1(f,:) + sr1(f,:);
        score(f,:)    = srTot;
        srTotAll(f,:) = srTot;

        % Larger score is better; rank 1 is best.
        SR(f,:) = tieSafeRanksDesc(srTot, epsEV);
    end

    % ==============================================================
    % 4) Build output tables with sum row
    % ==============================================================
    scoreTbl = array2table([(1:pro)' score], 'VariableNames', tableVarNames);
    rankTbl  = array2table([(1:pro)' SR],    'VariableNames', tableVarNames);

    scoreTbl = addSumRow(scoreTbl);
    rankTbl  = addSumRow(rankTbl);

    % Store summary tables in Data as well
    Data.Accuracy = ac1;
    Data.Speed = sr1;
    Data.TotalScore = score;
    Data.ScoreTable = scoreTbl;
    Data.RankTable = rankTbl;
end

% =====================================================================
% Helper: parse CSOP data from struct or numeric matrix
% =====================================================================
function [MinEV, LCV] = parseCSOPData(X, trial, num, algName, f, epsCV, epsEV)

    if isstruct(X)
        evField = findFirstField(X, {'Min_EV','MinEV','EV','Obj','obj','Fitness','fitness'});
        cvField = findFirstField(X, {'LCV','CV','cv','Cons','cons','Violation','violation'});

        if isempty(evField)
            error('Algorithm %s, F%d: struct output must contain Min_EV/MinEV/EV/Obj.', algName, f);
        end
        if isempty(cvField)
            error('Algorithm %s, F%d: struct output must contain LCV/CV.', algName, f);
        end

        MinEV = X.(evField);
        LCV   = X.(cvField);

    else
        if ~isnumeric(X)
            error('Algorithm %s, F%d: loader output must be a struct or numeric matrix.', algName, f);
        end

        % Some official files include the FE column first.
        % With FE column:    [FEs, EV1, LCV1, EV2, LCV2, ...]
        % Without FE column: [EV1, LCV1, EV2, LCV2, ...]
        if size(X,2) >= 2*trial + 1 && looksLikeFEColumn(X(:,1))
            Y = X(:,2:end);  % remove FE column
        else
            Y = X;
        end

        if size(Y,2) < 2*trial
            error(['Algorithm %s, F%d: numeric CSOP data must contain interleaved ', ...
                   'Min_EV and LCV columns for all runs. Required at least %d columns, got %d.'], ...
                   algName, f, 2*trial, size(Y,2));
        end

        MinEV = Y(:, 1:2:(2*trial-1));
        LCV   = Y(:, 2:2:(2*trial));
    end

    if size(MinEV,1) < num || size(LCV,1) < num
        error('Algorithm %s, F%d: Min_EV/LCV has fewer than num=%d rows.', algName, f, num);
    end
    if size(MinEV,2) < trial || size(LCV,2) < trial
        error('Algorithm %s, F%d: Min_EV/LCV has fewer than trial=%d columns.', algName, f, trial);
    end

    MinEV = MinEV(1:num, 1:trial);
    LCV   = LCV(1:num, 1:trial);

    % Clean numerical values.
    % Min_EV can be NaN when no feasible solution exists at a sampling point.
    MinEV(abs(MinEV) < epsEV) = 0;

    % LCV should be nonnegative. Small numerical values are treated as zero.
    LCV(abs(LCV) < epsCV) = 0;
    LCV(LCV < 0 & isfinite(LCV)) = 0;
    LCV(isnan(LCV)) = Inf;
end

% =====================================================================
% Helper: detect whether the first numeric column is an FE column
% =====================================================================
function tf = looksLikeFEColumn(x)
    x = x(:);
    x = x(isfinite(x));
    if numel(x) < 3
        tf = false;
        return;
    end
    dx = diff(x);
    tf = all(dx >= 0) && x(end) > x(1);
end

% =====================================================================
% Helper: find first available field name
% =====================================================================
function fieldName = findFirstField(S, candidates)
    fieldName = '';
    for i = 1:numel(candidates)
        if isfield(S, candidates{i})
            fieldName = candidates{i};
            return;
        end
    end
end

% =====================================================================
% Helper: compare smaller-is-better values
% cmp = -1 means x is better
% cmp =  1 means y is better
% cmp =  0 means tie
% =====================================================================
function cmp = compareSmallerIsBetter(x, y, tol)
    if nargin < 3 || isempty(tol)
        tol = 1e-12 * max(1, max(abs(x), abs(y)));
    end

    if isnan(x), x = Inf; end
    if isnan(y), y = Inf; end

    localTol = max(tol, 1e-12 * max(1, max(abs(x), abs(y))));

    if abs(x - y) <= localTol
        cmp = 0;
    elseif x < y
        cmp = -1;
    else
        cmp = 1;
    end
end

% =====================================================================
% Helper: add pairwise point based on comparison result
% =====================================================================
function [sp, sq] = addPairPoint(sp, sq, cmp)
    if cmp < 0
        sp = sp + 1;
    elseif cmp > 0
        sq = sq + 1;
    else
        sp = sp + 0.5;
        sq = sq + 0.5;
    end
end

% =====================================================================
% Helper: first sampling point where a curve reaches a reference threshold
% Smaller value is better.
% =====================================================================
function tau = firstReach(curve, theta, tol)
    if isnan(theta) || ~isfinite(theta)
        tau = Inf;
        return;
    end

    idx = find(isfinite(curve) & (curve <= theta + tol), 1, 'first');
    if isempty(idx)
        tau = Inf;
    else
        tau = idx;
    end
end

% =====================================================================
% Helper: tie-safe ranks for descending scores
% Larger score is better; rank 1 is best.
% =====================================================================
function ranks = tieSafeRanksDesc(vals, tol)
    vals = vals(:)';
    n = numel(vals);
    ranks = zeros(1,n);

    [sVals, ord] = sort(vals, 'descend');

    i = 1;
    while i <= n
        j = i;
        while j < n && isEqualTol(sVals(j), sVals(j+1), tol)
            j = j + 1;
        end
        ranks(ord(i:j)) = mean(i:j);
        i = j + 1;
    end
end

% =====================================================================
% Helper: tolerance equality
% =====================================================================
function tf = isEqualTol(x, y, tol)
    if nargin < 3 || isempty(tol)
        tol = 1e-12 * max(1, max(abs(x), abs(y)));
    end
    localTol = max(tol, 1e-12 * max(1, max(abs(x), abs(y))));
    tf = abs(x - y) <= localTol;
end

% =====================================================================
% Helper: add sum row to a numeric table with first column Function
% =====================================================================
function T = addSumRow(T)
    last = T(1,:);
    for c = 1:width(T)
        if isnumeric(T{1,c})
            last{1,c} = NaN;
        end
    end
    last.Function = NaN;
    last{1,2:end} = sum(T{:,2:end}, 1, 'omitnan');
    T = [T; last];
end
