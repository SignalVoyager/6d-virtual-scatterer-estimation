classdef WirelessEnvironment < handle
% WirelessEnvironment - build, run, and visualize ray-traced radio scenes
%
% Typical usage:
%   env = WirelessEnvironment(params);
%   env.datasetScene("save");
%   Blocks  = env.datasetSampling("geom-geom", ...);
%   Results = env.datasetRayTracing(Blocks, Nt_side, Nr_side, "sionna");
%   env.saveDataset(outFile, Results);  % optional

    properties (SetAccess = private)
        % -------- Specs (inputs) --------
        GridSpec    % struct: areaSize, gridSize, tx_pos_z, rx_pos_z
        RadioSpec   % struct: fc, Pt_dBm
        SceneSpec   % struct: scatterTable, stlFile, plyFile, xmlFile
        BackendSpec % struct: condaEnv, sionnaModule, (optional) gpuIndex, etc.
    end

    properties
        % -------- Runtime state (mutable) --------
        raytracingResults % optional cache, e.g., struct("trainSet",...,"testSet",...)
    end

    % ============================================================
    % Public method interfaces (implemented in separate files)
    % ============================================================
    methods
        function obj = WirelessEnvironment(params)
            % params: struct with fields:
            %   areaSize, gridSize, tx_pos_z, rx_pos_z
            %   fc, Pt_dBm
            %   scatterTable, stlFile, plyFile, xmlFile
            %   condaEnv, sionnaModule
            %
            % Minimal validation is done here; detailed checks can be inside methods.

            % ---- GridSpec ----
            obj.GridSpec = struct();
            obj.GridSpec.areaSize = params.areaSize;   % [Lx, Ly]
            obj.GridSpec.gridSize  = params.gridSize;    % scalar
            obj.GridSpec.tx_pos_z  = params.tx_pos_z;    % scalar
            obj.GridSpec.rx_pos_z  = params.rx_pos_z;    % scalar

            % ---- RadioSpec ----
            obj.RadioSpec = struct();
            obj.RadioSpec.fc     = params.fc;            % Hz
            obj.RadioSpec.Pt_dBm = params.Pt_dBm;        % dBm

            % ---- SceneSpec ----
            obj.SceneSpec = struct();
            obj.SceneSpec.scatterTable = params.scatterTable; % [x y z w d h] per row
            obj.SceneSpec.stlFile = params.stlFile;
            obj.SceneSpec.plyFile = params.plyFile;
            obj.SceneSpec.xmlFile = params.xmlFile;

            % ---- BackendSpec ----
            obj.BackendSpec = struct();
            obj.BackendSpec.condaEnv     = params.condaEnv;
            obj.BackendSpec.sionnaModule = params.sionnaModule;

            % Optional backend knobs (safe defaults)
            if isfield(params, "gpuIndex"); obj.BackendSpec.gpuIndex = params.gpuIndex; end
            if isfield(params, "material"); obj.BackendSpec.material = params.material; end

            obj.raytracingResults = struct();
        end

        % datasetScene(obj, mode)
        %   mode: "save" | "load"
        %   - save: build mesh from scatterTable then export STL/PLY/XML.
        %   - load: read existing STL then export PLY/XML.
        datasetScene(obj, mode)

        % Blocks = datasetSampling(obj, mode, varargin)
        %   mode: "rand-rand" | "geom-geom" | "list-rand" | "randblock-randblock" | "list-geom"
        % Output Blocks (recommended fields):
        %   Blocks(b).txSel : [Ntx x 1] grid indices (linear index over [Ky,Kx])
        %   Blocks(b).rxSel : [Nrx x 1] grid indices
        %   Blocks(b).tag   : string (mode tag)
        %   Blocks(b).sid   : numeric scatterer id or block id (optional)
        %
        % Notes:
        %   - It should guarantee txSel/rxSel belong to free-grid set (not inside scatterers).
        Blocks = datasetSampling(obj, mode, varargin)

        % Results = datasetRayTracing(obj, Blocks, Nt_side, Nr_side, backend)
        %   backend: "sionna" | "matlab"
        %   Nt_side/Nr_side: per-grid sampling resolution; each grid is sub-sampled into
        %   Nt_side^2 (TX) and Nr_side^2 (RX) points, then averaged back to grid-level.
        %
        % Output Results: numeric matrix [Npairs x 3]
        %   col1: txGridIdx (linear index)
        %   col2: rxGridIdx (linear index)
        %   col3: avg power in mW (grid-averaged)
        %
        % Notes:
        %   - Pair ordering is implementation-defined but should be stable.
        %   - You may internally deduplicate pairs.
        Results = datasetRayTracing(obj, Blocks, Nt_side, Nr_side, backend)

        % data = loadDataset(obj, file)
        %   Load variable 'Results' from MAT-file and return it.
        %   Does not modify raytracingResults unless you choose to assign it.
        data = loadDataset(obj, file)

        % saveDataset(obj, file, data)
        %   Save variable 'Results' to MAT-file (-v7.3 recommended).
        saveDataset(obj, file, data)

        % Results = generateDataset(obj, Nt_side, Nr_side, dataMode, sceneMode, filePath, varargin)
        %   dataMode:  "load" | "save" (dataset MAT workflow)
        %   sceneMode: "load" | "save" (scene STL workflow; used when dataMode="save")
        %   Optional: "samplingMode" and "samplingArgs"
        %   Returns one dataset matrix [N x 3] and does not split train/test internally.
        Results = generateDataset(obj, Nt_side, Nr_side, dataMode, sceneMode, filePath, varargin)

        % evaluate(obj, whichSet, viewMode, varargin)
        %   whichSet: "train" | "test"
        %   viewMode: "txHeatmap" | "rxCount" | "txCount"
        %   varargin: for "txHeatmap", provide orderTx (index into unique tx list)
        evaluate(obj, whichSet, viewMode, varargin)
    end
end

