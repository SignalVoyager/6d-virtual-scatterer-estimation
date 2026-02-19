function [P_dBm, state] = rtSionna(txPos, rxPos, spec, path, state)
%RT_SIONNA Ray tracing via Sionna RT adapter (Python)
% P_dBm: [NrxSamp x NtxSamp]

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
