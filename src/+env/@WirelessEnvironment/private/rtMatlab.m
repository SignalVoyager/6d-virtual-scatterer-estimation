%RT_MATLAB Ray tracing simulation using MATLAB RF Propagation Toolbox
%   [P_dBm, state] = RT_MATLAB(txPos, rxPos, spec, path, state) performs
%   ray tracing propagation analysis to compute received signal strength
%   at receiver locations given transmitter positions and environment.
%
%   INPUTS:
%       txPos       [3 x NtxSamp] double
%                   Transmitter Cartesian coordinates (x, y, z) in meters
%
%       rxPos       [3 x NrxSamp] double
%                   Receiver Cartesian coordinates (x, y, z) in meters
%
%       spec        struct
%                   Propagation specification with fields:
%                   - fc:           Center frequency (Hz)
%                   - Pt_dBm:       Transmitter power (dBm)
%                   - maxRef:       Maximum number of reflections
%                   - maxDif:       Maximum number of diffractions
%                   - material:     Surface material specification
%
%       path        struct
%                   Environment path with fields:
%                   - stlFile:      Path to STL scene model file
%
%       state       struct (optional)
%                   Cached propagation state with fields:
%                   - viewer:       Initialized siteviewer object
%                   - pm:           Propagation model object
%
%   OUTPUTS:
%       P_dBm       [NrxSamp x NtxSamp] double
%                   Received signal strength (dBm) at each receiver
%                   location for each transmitter
%
%       state       struct
%                   Updated state containing viewer and propagation model
%                   for reuse in subsequent calls
%
%   NOTES:
%       - Uses Shooting and Bouncing Ray (SBR) method
%       - Caches viewer and propagation model in state for efficiency
%       - Coordinates must be in Cartesian system
function [P_dBm, state] = rtMatlab(txPos, rxPos, spec, path, state)

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
% Pass the configured model exactly once. A second PropagationModel
% name-value would override state.pm and restore MATLAB's ray-tracing
% defaults (currently 2 reflections and 0 diffractions).
% Expect: [NrxSamp x NtxSamp]
P_dBm = sigstrength(rxSites, txSites, state.pm, "Map", state.viewer);

% 清理临时对象（viewer/pm 保留在 state 里）
clear txSites rxSites
end
