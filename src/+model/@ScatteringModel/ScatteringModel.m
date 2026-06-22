classdef (Abstract) ScatteringModel < handle
% ScatteringModel - scattering-based channel modeling and estimation
%
% This abstract base class provides a clean separation between:
%   (i)  immutable experiment/environment specs (GridSpec/SceneSpec/ModelSpec),
%   (ii) ray-traced datasets (train/test),
%   (iii) model-specific learning/inference (train/predict/evaluate),
%   (iv) reusable evaluation and visualization "blocks" (protected methods).
%
% Typical usage:
%   % 1) Prepare datasets (from WirelessEnvironment or any other generator)
%   Results = struct();
%   Results.trainSet = trainSet;   % [N x 3] = [tx_idx, rx_idx, power_mW]
%   Results.testSet  = testSet;    % same schema
%
%   % 2) Construct a concrete model and train
%   model = MyConcreteModel(params, "MyModel", Results);
%   model.train();
%
%   % 3) Run model-specific evaluation (pipeline is decided by the subclass)
%   opt = struct("whichSet","test", "txGridList",[30 30], "doPdf",true);
%   model.evaluate(opt, fullfile("outputs","MyModel_seed421"));
%
% Data convention (important):
%   - tx_idx/rx_idx are linear indices over the 2D grid [Ky,Kx] (MATLAB sub2ind).
%   - power is in linear scale mW (NOT dBm).
%   - predict() must return linear mW as well.
    
    properties (SetAccess = private)
        % -------- Specs (inputs, bound at construction) --------
        GridSpec    % struct: areaSize, gridSize, tx_pos_z, rx_pos_z
        SceneSpec   % struct: scatterTable
        ModelSpec   % struct: modelId, responseFile

        % -------- Datasets (inputs) --------
        % raytracingResults.trainSet / .testSet:
        %   [N x 3] double = [tx_idx, rx_idx, power_mW]
        raytracingResults
    end

    properties
        % -------- Model state (mutable) --------
        % scatterInfo: model parameter container populated by subclasses in train().
        % In this project, it is typically a struct with fields such as
        %   .scatterers and .beta_all.
        scatterInfo = struct([])
    end

    % ============================================================
    % Constructor + shared geometry utility
    % ============================================================
    methods
        function obj = ScatteringModel(params, modelId, raytracingResults)
            % params: struct with fields:
            %   responseFile
            %   scatterTable
            %   gridSize, areaSize, tx_pos_z, rx_pos_z
            %
            % raytracingResults: struct with fields:
            %   .trainSet, .testSet (each [N x 3] = [tx_idx, rx_idx, power_mW])
            %
            % Minimal validation is done here; detailed checks can be added
            % inside your data-loading or evaluation methods.
            
            obj.raytracingResults = raytracingResults;

            % ---- ModelSpec ----
            obj.ModelSpec = struct();
            obj.ModelSpec.responseFile = params.responseFile;
            obj.ModelSpec.modelId = modelId;

            % ---- SceneSpec ----
            obj.SceneSpec = struct();
            obj.SceneSpec.scatterTable = params.scatterTable;

            % ---- GridSpec ----
            obj.GridSpec = struct();
            obj.GridSpec.gridSize = params.gridSize;
            obj.GridSpec.areaSize = params.areaSize;
            obj.GridSpec.tx_pos_z = params.tx_pos_z;
            obj.GridSpec.rx_pos_z = params.rx_pos_z;
        end
        
        % computeGeometry(obj, tx_idx, rx_idx)
        %   Derive geometric features for a given TX/RX grid pair.
        %
        % Inputs:
        %   tx_idx : scalar linear index of TX grid (over [Ky,Kx])
        %   rx_idx : scalar linear index of RX grid
        %
        % Outputs:
        %   geomInfo : 1-by-Ns struct array aligned with SceneSpec.scatterTable
        %       .position      : scatterer center position [x,y,z] (m)
        %       .dist_tx       : TX-to-scatterer distance (m)
        %       .dist_rx       : scatterer-to-RX distance (m)
        %       .visibility_tx : LOS/NLOS flag TX->scatterer (logical)
        %       .visibility_rx : LOS/NLOS flag scatterer->RX (logical)
        %       .omega_in      : angle TX->scatterer in xy-plane (rad, [0,2pi))
        %       .omega_out     : angle scatterer->RX in xy-plane (rad, [0,2pi))
        %
        %   losInfo : struct for the direct TX->RX path
        %       .position_tx : [1 x 3]
        %       .position_rx : [1 x 3]
        %       .dist        : distance (m)
        %       .visibility  : LOS flag (logical)
        %       .omega       : angle TX->RX (rad, [0,2pi))
        %
        % Notes:
        %   - This method should be deterministic and side-effect free.
        %   - Visibility computation is scene-dependent; keep it consistent
        %     with how the dataset was generated.
        [geomInfo, losInfo] = computeGeometry(obj, tx_idx, rx_idx)
    end

    % ============================================================
    % Abstract interfaces (must be implemented by subclasses)
    % ============================================================
    methods (Abstract)
        % train(obj)
        %   Fit/estimate model parameters from obj.raytracingResults.trainSet
        %   and update obj.scatterInfo (and any subclass-specific state).
        train(obj)

        % [P, M, B] = evaluate(obj, opt, savePath)
        %   Model-specific evaluation pipeline. Subclasses decide:
        %     - which metrics to report
        %     - which plots to generate
        %     - which TXs to diagnose, etc.
        %
        % Returns:
        %   P: standardized prediction pack from evalPrepare()
        %   M: core metrics from evalMetricsCore()
        %   B: bucket metrics from evalMetricsBuckets()
        %
        % savePath:
        %   output file prefix (without extension). Empty means no figure output.
        %
        % opt fields (optional):
        %   whichSet   : "test"|"train"|"all"  (default "test")
        %   txGridList : [N x 2] [col,row] list for CGM/residual plots (default [30 30])
        %   doPdf      : true/false (default true)  - plot PDF comparison
        %   doCgm      : true/false (default true)  - plot CGM heatmap(s)
        %   doResidual : true/false (default true)  - plot residual scatter(s)
        %
        % Recommended behavior:
        %   - Call evalPrepare() first to standardize prediction + noise-floor handling.
        %   - Use evalMetricsCore()/evalMetricsBuckets()/evalReport() as reusable blocks.
        [P, M, B] = evaluate(obj, opt, savePath)
                      
        % [gain_sum, gain_path, gamma_path] = predict(obj, pairsTR)
        %   Predict channel gain for a batch of TX/RX grid pairs.
        %
        % Input:
        %   pairsTR : [N x 2] double/int = [tx_idx, rx_idx]
        %
        % Output:
        %   gain_sum  : [N x 1] double, predicted total gain/power in mW (linear)
        %   gain_path : (optional) per-path gain decomposition (model-defined)
        %   gamma_path: (optional) per-path parameters (model-defined)
        %
        % Contract:
        %   - gain_sum must be nonnegative (or NaN for invalid pairs).
        %   - Units are linear mW (NOT dB).
        [gain_sum, gain_path, gamma_path] = predict(obj, pairsTR)
    end

    % ============================================================
    % Sealed persistence APIs (format-stable across subclasses)
    % ============================================================
    methods (Sealed)
        % saveModel(obj)
        %   Save obj.scatterInfo to ModelSpec.responseFile as variable 'scatterer'.
        saveModel(obj)

        % loadModel(obj)
        %   Load model state from ModelSpec.responseFile and restore scatterInfo.
        %   This should not override GridSpec/SceneSpec/ModelSpec unless you
        %   explicitly version them.
        loadModel(obj)
    end

    % ============================================================
    % Protected evaluation/plot blocks (reusable building blocks)
    % Implement these in separate files under @ScatteringModel/
    % ============================================================
    methods (Access = protected)
        % P = evalPrepare(obj, whichSet, opt)
        %   Standardized data preparation for evaluation:
        %     - selects dataset(s) by whichSet
        %     - runs predict() on the selected pairs
        %     - applies noise-floor projection to y/yhat in linear domain
        %     - packs common intermediate variables into a struct P
        %
        % Inputs:
        %   whichSet: "test"|"train"|"all"
        %   opt (optional fields):
        %     q       : noise-floor quantile (default 0.02)
        %     eps_min : minimum floor in mW (default 1e-12)
        %     eps_mW  : floor used for log10 conversion (default eps_min)
        %
        % Output P (recommended fields):
        %   P.data     : [N x 3] [tx, rx, y_mW]
        %   P.y_mW     : [N x 1] ground truth (after floor)
        %   P.yhat_mW  : [N x 1] prediction (after floor)
        %   P.res_mW   : [N x 1] residual (y - yhat) in mW
        %   P.valid    : [N x 1] logical mask for positive finite entries
        %   P.y_dBm    : [N x 1] 10log10(max(y,eps_mW))
        %   P.yhat_dBm : [N x 1] 10log10(max(yhat,eps_mW))
        %   P.err_dB   : [N x 1] (y_dBm - yhat_dBm)
        P = evalPrepare(obj, whichSet, opt)

        % M = evalMetricsCore(obj, P)
        %   Compute core regression metrics from P.y_mW and P.yhat_mW:
        %     - MSE, NMSE
        %     - dB-domain global MSE (Sun-aligned)
        %     - correlation coefficients
        %     - relative RMSE
        %     - linear calibration fit y ≈ a*yhat + b
        %
        % Output M (recommended fields):
        %   mse, nmse, glo_mse_dB, rho_y_yhat, rho_y_res, relRMSE, ab
        M = evalMetricsCore(obj, P)

        % B = evalMetricsBuckets(obj, P, qList)
        %   Bucketed metrics using quantiles of y (linear mW).
        %
        % Inputs:
        %   qList: [1 x 2] (default [0.50 0.90])
        %
        % Output B (recommended fields):
        %   q50, q90
        %   LOW/MID/HIGH: struct with fields {mse, nmse, count}
        B = evalMetricsBuckets(obj, P, qList)

        % evalReport(obj, M, B)
        %   Print a human-readable evaluation report to console.
        %   This should be stable and consistent across models, unless
        %   subclasses intentionally override evaluate() behavior.
        evalReport(obj, M, B)

        % plotPdfCompare(obj, P, opt)
        %   Plot the PDF of power in dBm for ground truth vs prediction.
        %
        % opt (optional fields):
        %   binWidth_dB : histogram bin width (default 1.0)
        %   smoothWin   : moving-average window (default 3; 1 disables smoothing)
        plotPdfCompare(obj, P, opt)

        % plotCgmSlice(obj, mode, gridPos)
        %   Visualizes a 2D slice of the 6D CKM by fixing either
        %   Tx or Rx position and sweeping the other across the grid.
        %
        % Input Arguments:
        %   obj      - 6D CKM model object
        %   mode     - 'fixTx' or 'fixRx'
        %   gridPos  - [col, row] grid index to fix
        %
        % Notes:
        %   - Invalid grids excluded
        %   - Power displayed in dBm
        %   - Scatterers overlaid
        %   - Color scale clipped to [1%, 99%]
        plotCgmSlice(obj, mode, gridPos)

        % plotResidualMap(obj, txGrid, opt)
        %   Visualize residuals (in dB) for all measured RX locations under a
        %   fixed TX, using both train and test samples for diagnostics.
        %
        % Inputs:
        %   txGrid: [1 x 2] [col,row]
        %
        % opt (optional fields):
        %   topPercentile : highlight top-|res| percentile (default 95)
        %   q             : noise-floor quantile (default 0.02)
        %   eps_min       : minimum floor for log10 conversion (default 1e-12)
        plotResidualMap(obj, txGrid, opt)

        % C = getPlotContext(obj)
        %   Compute common grid/scene context for plotting:
        %     - Kx, Ky, K
        %     - xCenters, yCenters
        %     - invalidMask (grids inside scatterer rectangles, with margin)
        %     - scatterTable
        %
        % Output C fields (recommended):
        %   scatterTable, gridSize, areaSize, Kx, Ky, K, xCenters, yCenters, invalidMask
        C = getPlotContext(obj)
    end
end
