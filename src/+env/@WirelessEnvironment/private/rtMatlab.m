function [P_dBm, state] = rtMatlab(txPos, rxPos, spec, path, state)
%RT_MATLAB Ray tracing via MATLAB RF Propagation toolbox
% P_dBm: [NrxSamp x NtxSamp]

arguments
    txPos (3,:) double
    rxPos (3,:) double
    spec struct
    path struct
    state struct = struct()
end

% ---- init cache (viewer + propagation model) ----
if ~isfield(state, "viewer") || ~isvalid(state.viewer)
    state.viewer = siteviewer("SceneModel", path.stlFile, "Visible", "off");
end
if ~isfield(state, "pm") || isempty(state.pm)
    state.pm = propagationModel("raytracing", ...
        "Method", "sbr", ...
        "CoordinateSystem", "cartesian", ...
        "MaxNumReflections", spec.maxRef, ...
        "MaxNumDiffractions", spec.maxDif, ...
        "SurfaceMaterial", spec.material);
end

% ---- build sites ----
txSites = txsite("cartesian", ...
    "AntennaPosition", txPos, ...
    "TransmitterFrequency", spec.fc, ...
    "TransmitterPower", 10.^((spec.Pt_dBm - 30)/10));  % W

rxSites = rxsite("cartesian", "AntennaPosition", rxPos);

% ---- call ----
% Expect: [NrxSamp x NtxSamp]
P_dBm = sigstrength(rxSites, txSites, state.pm, ...
    "PropagationModel", "raytracing", "Map", state.viewer);

% 清理临时对象（viewer/pm 保留在 state 里）
clear txSites rxSites
end
