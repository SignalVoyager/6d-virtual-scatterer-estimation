classdef KrigingModel < model.ScatteringModel
% KrigingModel - Per-TX ordinary Kriging baseline in 2D RX space.
%
% For each transmitter index (tx_idx), this model fits a separate ordinary
% Kriging interpolator over receiver coordinates (x,y). By default it fits
% in dBm domain, but PowerDomain="linear" fits directly in mW.
%
% Key design choices:
%   - Ordinary kriging (constant unknown mean)
%   - Stable variogram with fixed alpha (StableAlpha)
%   - Variogram parameters fitted by bounded search with fallback solver
%   - Configurable fit domain; predictions always return mW
%
% Notes:
%   - This is a baseline interpolation method, not a physical scatterer model.
%   - gain_path and gamma_path are not modeled and returned as [].
%   - Uses all observations per TX (no sample truncation).
%   - If any TX model fit fails, training throws an error (no fallback model).

    properties (SetAccess = private)
        MaxDistance
        NumBins
        StableAlpha
        UseWeightedFit
        KNeighbors
        PowerDomain
    end

    methods
        function obj = KrigingModel(params, modelId, raytracingResults, varargin)
            % KrigingModel(params, modelId, raytracingResults, ...)
            %
            % Required:
            %   params: struct (must match ScatteringModel)
            %   modelId: string model identifier
            %   raytracingResults: struct with trainSet/testSet
            %
            % Optional name-value:
            %   "MaxDistance"     : lag-distance cutoff for experimental variogram
            %                       ([] -> use max pairwise distance / 2)
            %   "NumBins"         : number of lag bins in experimental variogram
            %   "StableAlpha"     : fixed alpha for stable variogram (default 0.1)
            %   "UseWeightedFit"  : use bin-count weighted LS in variogram fit
            %                       (default false)
            %   "KNeighbors"      : number of nearest RX samples used per query
            %                       in local Kriging prediction (default inf)
            %   "PowerDomain"     : "dbm" (default) or "linear"; controls the
            %                       response domain used for Kriging fitting

            obj@model.ScatteringModel(params, modelId, raytracingResults);

            p = inputParser;
            p.addParameter("MaxDistance",     []);
            p.addParameter("NumBins",         20);
            p.addParameter("StableAlpha",     0.1);
            p.addParameter("UseWeightedFit",  false);
            p.addParameter("KNeighbors",      inf);
            p.addParameter("PowerDomain",     "dbm");
            p.parse(varargin{:});
            opt = p.Results;

            obj.MaxDistance = opt.MaxDistance;
            obj.NumBins = opt.NumBins;
            obj.StableAlpha = opt.StableAlpha;
            obj.UseWeightedFit = logical(opt.UseWeightedFit);
            obj.KNeighbors = opt.KNeighbors;
            obj.PowerDomain = lower(string(opt.PowerDomain));
            if ~ismember(obj.PowerDomain, ["dbm", "linear"])
                error('[KrigingModel] PowerDomain must be "dbm" or "linear".');
            end
        end

        % train - Fit per-TX Kriging models using trainSet.
        %
        % Optional name-value:
        %   "mode" : "fit"|"load"|"save" (default "fit")
        %
        % Persistence uses ScatteringModel.saveModel/loadModel and
        % stores obj.scatterInfo with:
        %   .txModels (containers.Map keyed by tx_idx)
        %   .meta.MaxDistance / .meta.NumBins / .meta.StableAlpha /
        %   .meta.UseWeightedFit / .meta.KNeighbors
        train(obj, varargin)

        % predict - Predict power in mW for pairsTR=[tx_idx, rx_idx].
        %
        % Returns:
        %   gain_sum  : [N x 1] predicted power in mW
        %   gain_path : []
        %   gamma_path: []
        [gain_sum, gain_path, gamma_path] = predict(obj, pairsTR)

        % evaluate - Run model evaluation and optional plotting.
        % Uses ScatteringModel protected helpers.
        [P, M, B] = evaluate(obj, opt, savePath)
    end

    % ============================================================
    % Internal helpers (kept inside class; no utils dependency)
    % ============================================================
    methods (Access = private)
        % fitOneTxModel - Fit one TX-specific Kriging payload from raw samples.
        %
        % Inputs:
        %   pairsTR : [N x 2] array of [tx_idx, rx_idx] for one TX group
        %   powMw   : [N x 1] received power observations in mW
        %
        % Output:
        %   txModel : struct with fields:
        %             .type="kriging", .tx_idx, .vstruct,
        %             .xTrain, .yTrain, .zTrain, .powerDomain, .meta
        %
        % Notes:
        %   - Maps RX linear indices to XY grid centers
        %   - Converts mW according to obj.PowerDomain before variogram fitting
        %   - Fits stable variogram using ok_experimentalVariogram +
        %     ok_fitStableVariogram
        txModel = fitOneTxModel(obj, pairsTR, powMw)

        % predictOneTx - Predict power values for one TX model and query pairs.
        %
        % Inputs:
        %   txModel : TX model struct from scatterInfo.txModels
        %   pairsTR : [N x 2] query pairs [tx_idx, rx_idx]
        %
        % Output:
        %   powerHat : [N x 1] predicted power in txModel.powerDomain
        %
        % Notes:
        %   - Uses rx_idx only for XY mapping; TX grouping is handled in predict()
        %   - Dispatches to ok_ordinaryKriging for txModel.type="kriging"
        powerHat = predictOneTx(obj, txModel, pairsTR)

        % ok_experimentalVariogram - Compute binned experimental semivariogram.
        %
        % Inputs:
        %   XY: [N x 2]
        %   z : [N x 1] (dB)
        %
        % Name-value:
        %   "MaxDistance" : maximum lag distance
        %   "NumBins"     : number of bins
        %
        % Output:
        %   vg.distance : [B x 1] bin centers
        %   vg.gamma    : [B x 1] semivariance
        %   vg.count    : [B x 1] pair counts
        vg = ok_experimentalVariogram(XY, z, varargin)

        % ok_fitStableVariogram - Fit stable variogram with fixed alpha.
        %
        % Model (semivariogram):
        %   gamma(h) = nugget + sill * ( 1 - exp( - (h / range)^alpha ) )
        %
        % Inputs:
        %   h     : [M x 1] distances
        %   gamma : [M x 1] experimental semivariance
        %
        % Name-value:
        %   "StableAlpha" : alpha in (0,2], fixed
        %   "BinCount"    : pair counts per lag bin (optional)
        %   "UseWeightedLS": whether to use weighted least squares
        %
        % Output vstruct fields:
        %   .model  = "stable"
        %   .range, .sill, .nugget, .alpha
        vstruct = ok_fitStableVariogram(h, gamma, varargin)

        % ok_ordinaryKriging - ordinary kriging in 2D
        %
        % Inputs:
        %   vstruct: stable variogram params
        %   x,y,z : training samples (z in dB)
        %   xq,yq : query points
        %
        % Output:
        %   zhat  : predicted z in dB
        zhat = ok_ordinaryKriging(vstruct, x, y, z, xq, yq)

        % ok_fminsearchbnd - bounded fminsearch via variable transform
        %
        % This is a lightweight special-case optimizer wrapper to avoid dependencies.
        % It transforms bounded variables into unconstrained space and calls fminsearch.
        x = ok_fminsearchbnd(fun, x0, lb, ub)

    end
end

