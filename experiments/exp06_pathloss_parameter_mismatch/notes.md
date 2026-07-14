# Experiment Notes — Path-Loss Parameter Mismatch

## Purpose

This experiment responds to the reviewer concern that a single path-loss
exponent and reference gain may not represent a heterogeneous urban region.
It measures deployment-time train–test parameter mismatch, not uncertainty
from repeated ray tracing.

## Protocol

- Reuse the `2R/0D` dense-scene caches generated for exp05. No RT is run.
- For every assumed parameter pair, rebuild the Eq. (7) design matrix,
  re-estimate the virtual-scatterer responses, and reconstruct the test CGM
  using the same assumed pair.
- Alpha sweep: solve and reconstruct with
  `alpha={1.6,1.8,1.9,2.0,2.1,2.2,2.4}` while fixing `beta0=-30 dB`.
- Beta0 sweep: solve and reconstruct with
  `beta0={-36,-33,-31.5,-30,-28.5,-27,-24} dB` while fixing `alpha=2`.
- Evaluate all settings on the same fixed 1500-pair test set with the standard
  `q=0.017` evaluation noise floor.

`dataCleaning.enabled` must remain `false`. In particular, zero powers must not
be replaced by `1e-12 mW` before `evaluate()` applies its noise floor.

## Interpretation

The assumed parameters are deliberately used inside the reconstruction
algorithm even though the fixed RT data correspond to the nominal calibration.
Because beta0 is a global multiplicative scale and the response coefficients
are freely re-estimated, its scale is theoretically absorbed by those
coefficients. Identical beta0-sweep MAEs therefore indicate scale
non-identifiability, not a failed sweep. Alpha changes relative path weights and
cannot generally be absorbed in this way.

The ray-tracing data itself is unchanged. Therefore, the experiment quantifies
the reconstruction sensitivity to assumed propagation parameters efficiently,
rather than claiming that the RT generator used different material exponents.

## Outputs

- `outputs/original/pathloss_mismatch_raw_seed*.csv`
- `outputs/final/pathloss_mismatch_summary.csv`
- `outputs/final/pathloss_parameter_mismatch_mae.{png,pdf,fig}`
