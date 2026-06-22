classdef VirtualScatter6D < model.ScatteringModel
% VirtualScatter6D - single-hop TX->(scatterer)->RX gain model with angular discretization
%
% This model discretizes (omega_in, omega_out) into M angle bins and uses a
% nonnegative linear model to fit per-path scattering responses.
%
% Key idea:
%   y(tx,rx) ≈ w_LOS(tx,rx) * gamma_LOS(omega_in,omega_out)
%            + sum_n w_n(tx,rx) * gamma_n(omega_in,omega_out)
%
% where w are geometry weights (visibility + path-loss), and gamma are learned
% per-path angular response tables (one-hot over angle bins in this implementation).

    properties
        % -------- Model hyperparameters --------
        NumCenters   % number of angle bins per dimension (M)
        PathLossExp  % path-loss exponent alpha, g(d) = (d0 / d)^alpha
        RefDistance  % reference distance d0
        EpsDist      % distance floor epsilon
        Solver       % "LS" | "LS-Ridge" | "NNLS"
    end
    methods
        function obj = VirtualScatter6D(params, modelId,raytracingResults,varargin)
            % VirtualScatter6D(params, modelId, raytracingResults, ...)
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
            p.addParameter("NumCenters", 4); % M (default 4), must be >= 2
            p.addParameter("PathLossExp", 2.0); % alpha (default 2.0)  g(d)=1/(d^alpha)
            p.addParameter("RefDistance", 1.0); % d0 (default 1.0)
            p.addParameter("EpsDist", 1e-3); % epsilon for distance (default 1e-3)
            p.addParameter("Solver", "LS");
            p.parse(varargin{:});
            opt = p.Results;
            
            obj.NumCenters = opt.NumCenters;
            obj.PathLossExp = opt.PathLossExp;
            obj.RefDistance    = opt.RefDistance;
            obj.EpsDist  = opt.EpsDist;
            obj.Solver = opt.Solver;
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

        % [P, M, B] = evaluate(obj, opt, savePath)
        %   savePath is output file prefix. Empty means no figure output.
        [P, M, B] = evaluate(obj, opt, savePath)
    end

    methods (Access = private)
        % [Geometry, Scattering] = TypesSector(obj, pairsTR)
        %   Build geometry weights and one-hot angular features for LOS and each scatterer.
        [Geometry, Scattering] = TypesSector(obj, pairsTR)
    end
end
