classdef KrigingModel < ScatteringModel
% KrigingModel - per-TX ordinary kriging baseline for 6D CGM
%
% This model constructs a conditional 2D channel gain map for each TX grid:
%   z_tx(x,y) = 10*log10(power_mW)
% by ordinary kriging in the spatial domain (x,y).
%
% Key design choices (special-case baseline):
%   - Ordinary kriging (constant unknown mean)
%   - Stable variogram with fixed alpha (stablealpha = 0.1) to reduce DoF
%   - Fitting via bounded Nelder-Mead (fminsearchbnd-style)
%   - Work in dB domain; convert back to mW for evaluation consistency
%
% Notes:
%   - This is a baseline interpolation method, not a physical scatterer model.
%   - gain_path/gamma_path are not meaningful here and will be returned as [].

    properties (SetAccess = private)
        KrigingSpec   % struct: method/options for this baseline
        TxModels      % containers.Map: key=tx_idx (char), value=struct(model)
        GlobalFallback % struct: global fallback stats (mean in dB etc.)
    end

    methods
        function obj = KrigingModel(params, modelId, raytracingResults, varargin)
            % KrigingModel(params, modelId, raytracingResults, ...)
            %
            % Required:
            %   params: struct (must match ScatteringModel)
            %   modelId: string
            %   raytracingResults: struct with trainSet/testSet
            %
            % Optional name-value:
            %   "MinSamplesPerTx" : minimum samples to fit kriging for a TX
            %   "MaxPairsForFit"  : cap samples per TX (subsample) for speed
            %   "MaxDistance"     : max distance used in experimental variogram
            %   "NumBins"         : number of bins for experimental variogram
            %   "StableAlpha"     : fixed alpha for stable variogram (default 0.1)
            %   "Fallback"        : "idw"|"nearest"|"globalmean" (default "idw")
            %   "IdwPower"        : power parameter for IDW (default 2)
            %   "Verbose"         : true/false

            obj@ScatteringModel(params, modelId, raytracingResults);

            p = inputParser;
            p.addParameter("MinSamplesPerTx", 20);
            p.addParameter("MaxPairsForFit",  2000);
            p.addParameter("MaxDistance",     []);
            p.addParameter("NumBins",         20);
            p.addParameter("StableAlpha",     0.1);
            p.addParameter("Fallback",        "idw");
            p.addParameter("IdwPower",        2);
            p.addParameter("Verbose",         true);
            p.parse(varargin{:});
            opt = p.Results;

            spec = struct();
            spec.minSamplesPerTx = opt.MinSamplesPerTx;
            spec.maxPairsForFit  = opt.MaxPairsForFit;
            spec.maxDistance     = opt.MaxDistance;
            spec.numBins         = opt.NumBins;
            spec.stableAlpha     = opt.StableAlpha;
            spec.fallback        = string(opt.Fallback);
            spec.idwPower        = opt.IdwPower;
            spec.verbose         = logical(opt.Verbose);

            obj.KrigingSpec = spec;
            obj.TxModels = containers.Map('KeyType','char','ValueType','any');
            obj.GlobalFallback = struct();
        end

        % train - fit per-TX kriging models using training set.
        %
        % Optional name-value:
        %   "mode" : "fit"|"load"|"save" (default "fit")
        %
        % Persistence uses ScatteringModel.saveModel/loadModel and
        % stores obj.scatterInfo as a container for TxModels and meta.
        train(obj, varargin)

        % predict - predict power in mW for [N x 2] pairsTR = [tx_idx, rx_idx]
        %
        % Returns:
        %   gain_sum  : [N x 1] predicted power in mW
        %   gain_path : []
        %   gamma_path: []
        [gain_sum, gain_path, gamma_path] = predict(obj, pairsTR, varargin)

        % evaluate - model-specific evaluation pipeline
        % Uses ScatteringModel's protected helper methods.
        evaluate(obj, opt)
    end

    % ============================================================
    % Internal helpers (kept inside class; no utils dependency)
    % ============================================================
    methods (Access = private)
        key = txKey(~, txIdx)

        [x, y] = rxIdxToXY(obj, rxIdx)

        txModel = fitOneTxModel(obj, txIdx, x, y, zDb)

        txModel = makeFallbackModel(obj, txIdx, x, y, zDb, reason)

        zHatDb = predictOneTx(obj, txModel, xq, yq)

        printKrigingTrainingSummary(obj)

        % ok_experimentalVariogram - binned experimental semivariogram
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

        % ok_fitStableVariogram - fit a stable variogram with fixed alpha
        %
        % Model (semivariogram):
        %   gamma(h) = nugget + sill * ( 1 - exp( - (h / range)^alpha ) )
        %
        % Inputs:
        %   h     : [M x 1] distances
        %   gamma : [M x 1] experimental semivariance
        %
        % Name-value:
        %   "StableAlpha" : alpha in (0,2], fixed (default 0.1)
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

        % ok_idwPredict - inverse distance weighting predictor in 2D
        zhat = ok_idwPredict(x, y, z, xq, yq, p)
    end
end
