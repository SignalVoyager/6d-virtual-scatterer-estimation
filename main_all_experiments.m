function main_all_experiments()
% main_all_experiments - entry point to run one or multiple experiments
%
% Convention:
%   Each experiment lives in: project/experiments/<exp_name>/
%     - config.json
%     - run_experiment.m
%     - data/        (intermediate artifacts)
%     - outputs/     (figures, logs, metrics)
%
% This main script:
%   - sets project root
%   - adds src to path
%   - iterates experiments
%   - runs the experiment-local script with expRoot injected

    clc; close all;

    % ---------- project root (this file's folder) ----------
    projectRoot = fileparts(mfilename('fullpath'));

    % ---------- add source paths ----------
    addpath(fullfile(projectRoot, "src"));
    addpath(genpath(fullfile(projectRoot, "src")));

    % ---------- choose experiments ----------
    expNames = ["exp01_virtualscatter6d_showcase"];

    % ---------- choose RNG seeds ----------
    rngValues = [421,32];  % can be vector

    for e = 1:numel(expNames)
        expName = expNames(e);
        expRoot = fullfile(projectRoot, "experiments", expName);

        % minimal sanity
        assert(isfolder(expRoot), "Experiment folder not found: %s", expRoot);
        assert(isfile(fullfile(expRoot, "config.json")), "Missing config.json in %s", expRoot);
        assert(isfile(fullfile(expRoot, "run_experiment.m")), "Missing run_experiment.m in %s", expRoot);

        for s = 1:numel(rngValues)
            seed = rngValues(s);

            fprintf("\n================ EXP: %s | SEED: %d ================\n", expName, seed);

            % ---------- reset runtime state ----------
            clc;
            close all;
            rng(seed, "twister");

            % (optional) clear python adapter persistent state if needed
            clear functions; %#ok<CLFUNC>
            % If your sionna adapter uses persistent variables inside methods,
            % you may also want:
            % clear classes;

            % ---------- run experiment-local script ----------
            % Inject expRoot + seed so the local script stays self-contained.
            run(fullfile(expRoot, "run_experiment.m"));
        end
    end
end
