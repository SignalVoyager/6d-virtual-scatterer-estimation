# Experiment 05: Sector-number sensitivity

Reviewer concern: the bidirectional virtual-scatterer response is discretized into \(M\) non-overlapping sectors, but the manuscript did not quantify sensitivity to \(M\).

This experiment evaluates \(M=\{2,3,4,5,6\}\). The model still uses \(M\) bidirectional sectors, but the geometry-guided training set is slightly oversampled with \(K=M+1\) TX samples and \(K=M+1\) RX samples per virtual scatterer. The nominal training-set size is

\[
N_{\mathrm{sc}} K^2,\quad K=M+1.
\]

With the dense scene used here, \(N_{\mathrm{sc}}=17\), giving:

- \(M=2, K=3\): 153 training samples
- \(M=3, K=4\): 272 training samples
- \(M=4, K=5\): 425 training samples
- \(M=5, K=6\): 612 training samples
- \(M=6, K=7\): 833 training samples

Repeated runs are controlled by `rngValues` in `main_all_experiments.m`. The geometry-guided sampler uses random selection inside each angular bin, so different seeds produce independent sector-coverage samples.

The fixed-TX test set is kept unchanged across all \(M\). By default, the script reuses the existing 2-reflection/no-diffraction cache from `experiments/exp04_propagation_order_ablation/data/test_second_order_2r0d_seed521.mat` to avoid rerunning the test-set ray tracing.

Power values are cleaned consistently with exp04 before training/evaluation:
non-finite or non-positive powers, and powers below the configured floor, are
clipped to \(-120\) dBm. The evaluation options also explicitly set
`q=0.017`, `eps_min=1e-12`, and `eps_mW=1e-12`.

Main outputs:

- `outputs/original/sector_number_raw_seed*.csv`
- `outputs/final/sector_number_summary.csv`
- `outputs/final/sector_number_sensitivity_mae.png`
- `outputs/final/sector_number_sensitivity_mae.pdf`
- `outputs/final/sector_number_sensitivity_mae.fig`
