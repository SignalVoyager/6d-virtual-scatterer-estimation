%% RT_SIONNA Ray tracing via Sionna RT adapter (Python)
%
% SYNTAX
%   [P_dBm, state] = rtSionna(txPos, rxPos, spec, path)
%   [P_dBm, state] = rtSionna(txPos, rxPos, spec, path, state)
%
% DESCRIPTION
%   Performs ray tracing simulation using Sionna RT (a Python-based ray tracing
%   engine with Mitsuba backend). This function acts as a MATLAB-Python adapter,
%   handling environment setup, module loading, and coordinate transformation.
%
% INPUT ARGUMENTS
%   txPos           [3 x NtxSamp] double
%                   Transmitter position(s) in Cartesian coordinates [x; y; z]
%
%   rxPos           [3 x NrxSamp] double
%                   Receiver position(s) in Cartesian coordinates [x; y; z]
%
%   spec            struct
%                   Simulation specification containing:
%                   - fc              Center frequency (Hz)
%                   - Pt_dBm          Transmit power (dBm)
%                   - maxRef          Maximum number of reflections (int)
%                   - maxDif          Maximum number of diffractions (int)
%                   - material        Material database name (string)
%                   - cudaVisibleDevices  (optional) GPU device indices
%
%   path            struct
%                   File paths and environment settings:
%                   - sionnaModule    Path to Sionna adapter Python module
%                   - xmlFile         Path to ray tracing scene XML file
%                   - condaEnv        (optional) Conda environment directory
%
%   state           struct (default: empty)
%                   Cached Python module handles:
%                   - py_sionna       Loaded Sionna adapter module
%                   - py_np           NumPy module reference
%
% OUTPUT ARGUMENTS
%   P_dBm           [NrxSamp x NtxSamp] double
%                   Received power matrix in dBm. Element (i,j) contains the
%                   power received at receiver i from transmitter j.
%
%   state           struct
%                   Updated state structure with cached Python objects for
%                   efficient reuse across multiple function calls.
%
% NOTES
%   - Coordinate transformation: MATLAB [3 x N] transposed to Python [N x 3]
%   - Output shape normalized to [NrxSamp x NtxSamp] (transposed if needed)
%   - CUDA device and Conda environment initialized on first call only
%   - Python module cache persists for performance optimization
%
% EXAMPLE
%   spec.fc = 3.5e9; spec.Pt_dBm = 20; spec.maxRef = 3; spec.maxDif = 2;
%   [P_dBm, state] = rtSionna([0;0;5], [10;0;1.5], spec, path);
%
% SEE ALSO
%   py.importlib, setenv
function [P_dBm, state] = rtSionna(txPos, rxPos, spec, path, state)
arguments
    txPos (3,:) double
    rxPos (3,:) double
    spec struct
    path struct
    state struct = struct()
end

% ---- init python module cache once ----
if ~isfield(state, "py_sionna") || isempty(state.py_sionna)
    % GPU visibility (按你的习惯封装在这里)
    if isfield(spec, "cudaVisibleDevices")
        setenv("CUDA_DEVICE_ORDER", "PCI_BUS_ID");
        setenv("CUDA_VISIBLE_DEVICES", string(spec.cudaVisibleDevices));
    end

    % conda path 注入
    if isfield(path, "condaEnv") && strlength(string(path.condaEnv))>0
        condaEnv = string(path.condaEnv);
        setenv("PATH", condaEnv + "\Library\bin;" + condaEnv + "\DLLs;" + ...
                     condaEnv + "\Scripts;" + getenv("PATH"));
    end

    py_util = py.importlib.import_module("importlib.util");
    specpy  = py_util.spec_from_file_location("sionna_rt_adapter", path.sionnaModule);
    mod     = py_util.module_from_spec(specpy);
    specpy.loader.exec_module(mod);

    state.py_sionna = mod;
    state.py_np     = py.importlib.import_module("numpy");

    if py.hasattr(state.py_sionna, "which_variant")
        fprintf("[Sionna] Mitsuba variant = %s\n", string(state.py_sionna.which_variant()));
    end
end

% ---- call adapter ----
py_sigstrength = py.getattr(state.py_sionna, "sigstrength");

% MATLAB: [3 x N] -> Python expects [N x 3]
tx_py = state.py_np.array(txPos.');
rx_py = state.py_np.array(rxPos.');

P_py = py_sigstrength( ...
    path.xmlFile, ...
    tx_py, ...
    rx_py, ...
    double(spec.fc), ...
    double(spec.Pt_dBm), ...
    int32(spec.maxRef), ...
    int32(spec.maxDif), ...
    string(spec.material));

% ---- normalize shape to [NrxSamp x NtxSamp] double ----
P_dBm = double(P_py);

% 关键：你要在这里把形�?归一�?，不要把转置散落在主流程�?
% 如果你的 python 端返回的�?[NtxSamp x NrxSamp]，就在这里转置：
if size(P_dBm,1) == size(txPos,2) && size(P_dBm,2) == size(rxPos,2)
    P_dBm = P_dBm.';  % -> [NrxSamp x NtxSamp]
end
end
