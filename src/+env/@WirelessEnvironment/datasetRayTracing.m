function Results = datasetRayTracing(obj, Blocks, Nt_side, Nr_side, mode)
if isempty(Blocks)
    Results = zeros(0,3);
    return;
end

% ---- unify spec/path ----
spec = struct();
spec.fc = obj.RadioSpec.fc;
spec.Pt_dBm = obj.RadioSpec.Pt_dBm;
spec.maxRef = 5;
spec.maxDif = 2;
spec.material = "concrete";
spec.cudaVisibleDevices = "0";  % 可选：只给 sionna
path = struct();
path.stlFile = obj.SceneSpec.stlFile;
path.xmlFile  = obj.SceneSpec.xmlFile;
path.condaEnv = obj.BackendSpec.condaEnv;
path.sionnaModule = obj.BackendSpec.sionnaModule;

% ---- choose backend ----
mode = lower(string(mode));
state = struct();
switch mode
    case "matlab"
        rtCall = @(txPos, rxPos, spec, path, state) rtMatlab(txPos, rxPos, spec, path, state);
    case "sionna"
        rtCall = @(txPos, rxPos, spec, path, state) rtSionna(txPos, rxPos, spec, path, state);
    otherwise
        error('Unknown mode "%s".', mode);
end

Results = zeros(0,3);

for b = 1:numel(Blocks)
    txSel = Blocks(b).txSel(:);
    rxSel = Blocks(b).rxSel(:);
    if isempty(txSel) || isempty(rxSel), continue; end

    [txPos, rxPos, meta] = expandGridSamples( ...
        obj.GridSpec.areaSize,obj.GridSpec.gridSize, ...
        obj.GridSpec.tx_pos_z,obj.GridSpec.rx_pos_z, ...
        txSel, rxSel, Nt_side, Nr_side);
    fprintf('[datasetRayTracing] Block %d/%d: TX=%d grids, RX=%d grids, TXsamp=%d, RXsamp=%d\n', b, numel(Blocks), meta.Ntx, meta.Nrx, meta.Ns_tx, meta.Ns_rx);

    % ---- backend call, normalized: P_dBm is [NrxSamp x NtxSamp] ----
    [P_dBm, state] = rtCall(txPos, rxPos, spec, path, state);

    P_mW = 10.^(P_dBm/10).';

    % --- grid-averaged power: avgGrid(rx, tx) ---
    P4 = reshape(P_mW, meta.Ns_rx, meta.Nrx, meta.Ns_tx, meta.Ntx);  % [Ns_rx x Nrx x Ns_tx x Ntx]
    avgGrid = reshape(mean(mean(P4, 1), 3), meta.Nrx, meta.Ntx);
    % Indices of all pairs in "rx-major" order or "tx-major" order
    [Itx, Irx] = ndgrid(1:meta.Ntx, 1:meta.Nrx);          % Itx/Irx: [Ntx x Nrx]
    
    txList = txSel(Itx(:));                    % [Ntx*Nrx x 1]
    rxList = rxSel(Irx(:));                    % [Ntx*Nrx x 1]
    % avgGrid(j,i) is power for rx_j with tx_i, so index is (Irx, Itx) into [Nrx x Ntx]
    powList = avgGrid(sub2ind([meta.Nrx, meta.Ntx], Irx(:), Itx(:)));   % [Ntx*Nrx x 1]
    
    Results = [Results; [txList, rxList, powList]]; %#ok<AGROW>
end

pairOpt = struct('directed',true,'allowSelf',false,'dedup',true);
Results = aggregateGridSamples(Results, pairOpt);
end
    

