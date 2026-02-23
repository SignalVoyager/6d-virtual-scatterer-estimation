classdef VirtualScatter3D < model.ScatteringModel
% VirtualScatter3D - per-TX degraded virtual-scatterer model (3D CGM baseline)
%
% This model is a degenerate version of VirtualScatter6D:
%   - It fits an angular response table using ONLY the outgoing angle omega_out.
%   - It trains an independent parameter set for each TX grid index.
%
% For each fixed TX (tx_idx), we assume:
%   y(tx_idx, rx) ≈ w_LOS(tx_idx,rx) * gamma_LOS(omega_los_out)
%                + sum_n w_n(tx_idx,rx) * gamma_n(omega_out_n)
%
% where:
%   - w are geometry weights (visibility + path-loss)
%   - gamma_* are learned nonnegative 1D angular response tables (one-hot bins)
%
% Typical usage:
%   mdl = model.VirtualScatter3D(params, "VirtualScatter3D", raytracingResults, ...
%           "NumCenters", 8, "Solver","NNLS");
%   mdl.train("mode","save");
%   mdl.evaluate(struct("txGridList",[30 30; 10 10]), ...
%                fullfile("outputs","VirtualScatter3D_seed421"));

    properties
        % -------- Model hyperparameters --------
        NumCenters   % number of angle bins (M)
        PathLossExp  % path-loss exponent alpha, g(d) = (d0 / d)^alpha
        RefDistance  % reference distance d0
        EpsDist      % distance floor epsilon
        Solver       % "LS" | "LS-Ridge" | "NNLS"
    end

    methods
        function obj = VirtualScatter3D(params, modelId, raytracingResults, varargin)
            % VirtualScatter3D(params, modelId, raytracingResults, ...)
            %
            % Inputs:
            %   params: struct passed to ScatteringModel, must include:
            %     responseFile, scatterTable, gridSize, areaSize, tx_pos_z, rx_pos_z
            %   raytracingResults: struct with fields trainSet/testSet
            %
            % Name-value options:
            %   "NumCenters"  : integer, default 4
            %   "PathLossExp" : double,  default 2.0
            %   "RefDistance" : double,  default 1.0
            %   "EpsDist"     : double,  default 1e-3
            %   "Solver"      : "LS" | "LS-Ridge" | "NNLS", default "LS"

            obj = obj@model.ScatteringModel(params, modelId, raytracingResults);

            p = inputParser;
            p.addParameter("NumCenters", 4);
            p.addParameter("PathLossExp", 2.0);
            p.addParameter("RefDistance", 1.0);
            p.addParameter("EpsDist", 1e-3);
            p.addParameter("Solver", "LS");
            p.parse(varargin{:});
            opt = p.Results;

            obj.NumCenters  = opt.NumCenters;
            obj.PathLossExp = opt.PathLossExp;
            obj.RefDistance = opt.RefDistance;
            obj.EpsDist     = opt.EpsDist;
            obj.Solver      = opt.Solver;
        end

        % train(obj, varargin)
        %   Optional mode control via varargin:
        %     train(obj, "mode","load")  -> loadModel()
        %     train(obj, "mode","save")  -> train then saveModel()
        %     train(obj) or train(obj,"mode","fit") -> just train
        train(obj, varargin)

        % [gain_sum, gain_path, gamma_path] = predict(obj, pairsTR)
        %   Linear power prediction in mW.
        [gain_sum, gain_path, gamma_path] = predict(obj, pairsTR)


        % evaluate(obj, opt, savePath)
        %   savePath is output file prefix. Empty means no figure output.
        evaluate(obj, opt, savePath)
    end

    methods (Access = private)
        % Build geometry weights + one-hot angular features (omega_out only),
        % for a batch of pairsTR. This is shared by train and predict.
        [Geometry, Scattering] = TypesSectorTx(obj, pairsTR)
    end
end
