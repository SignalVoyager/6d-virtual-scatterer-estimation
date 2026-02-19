import os
"""
Sionna Ray Tracing Adapter Module
This module provides a high-level interface to Sionna's ray tracing engine for computing
signal strength in wireless propagation scenarios. It wraps Sionna's PathSolver with
scene caching and simplified APIs similar to MATLAB's sigstrength function.
Configuration:
    ENABLE_SCATTERING (bool): Enable diffuse scattering in ray tracing. When False,
        only mirror-like reflections are computed.
    ENABLE_REFRACTION (bool): Enable refraction effects in ray tracing.
    ENABLE_EDGE_DIFFRACTION (bool): Enable edge diffraction effects.
    SYNTHETIC_ARRAY (bool): Use synthetic array processing for beamforming.
    SEED (int): Random seed for reproducibility in stochastic computations.
Functions:
    get_scene(scene_path, freq_hz, max_depth, max_diff, material_tag):
        Load or retrieve cached scene with configured transmitter/receiver arrays.
    sigstrength(scene_path, tx_pos_xyz, rx_pos_xyz, freq_hz, tx_power_dbm, 
                max_depth, max_diff, material_tag):
        Compute received signal strength (dBm) between transmitters and receivers
        using ray tracing with configurable propagation mechanisms.
    gpu_report():
        Query and return NVIDIA GPU information via nvidia-smi.
Dependencies:
    - mitsuba: Ray tracing engine (CUDA variant)
    - sionna: Wireless ray tracing library
    - numpy: Numerical computations
"""

print("CUDA_VISIBLE_DEVICES =", os.environ.get("CUDA_VISIBLE_DEVICES", ""))

import mitsuba as mi
mi.set_variant("cuda_ad_mono_polarized")   # 用 RTX 跑

import numpy as np
from sionna.rt import load_scene, Transmitter, Receiver, PathSolver, PlanarArray

ENABLE_SCATTERING = True     # True: enable diffuse scattering; False: mirror-like only
SEED = 1

ENABLE_REFRACTION = False      # 你当前是 True；如需更像 MATLAB，可设 False
ENABLE_EDGE_DIFFRACTION = True
SYNTHETIC_ARRAY = False        # 你之前用 True；若只用 1x1 阵列也可以关掉（性能相关）

_SCENE_CACHE = {}
_PATH_SOLVER = PathSolver()  # 全局复用

def get_scene(scene_path, freq_hz, max_depth=5, max_diff=2, material_tag="concrete"):
    key = (str(scene_path), float(freq_hz), int(max_depth), int(max_diff), str(material_tag))
    if key in _SCENE_CACHE:
        return _SCENE_CACHE[key]

    scene = load_scene(scene_path)
    scene.frequency = float(freq_hz)

    # 统一设置：单天线各向同性阵列（最贴近你 MATLAB sigstrength 的"点天线"用法）
    scene.tx_array = PlanarArray(num_rows=1, num_cols=1,
                                 vertical_spacing=0.5, horizontal_spacing=0.5,
                                 pattern="iso", polarization="V")
    scene.rx_array = scene.tx_array  # 复用同一配置

    _SCENE_CACHE[key] = scene
    return scene

def sigstrength(scene_path,
                      tx_pos_xyz,
                      rx_pos_xyz,
                      freq_hz,
                      tx_power_dbm,
                      max_depth=5,
                      max_diff=2,
                      material_tag="concrete"):
    scene = get_scene(scene_path, freq_hz, max_depth, max_diff, material_tag)

    # 清空旧 Tx/Rx
    for name in list(scene.transmitters.keys()):
        scene.remove(name)
    for name in list(scene.receivers.keys()):
        scene.remove(name)

    tx_pos_xyz = np.asarray(tx_pos_xyz, dtype=np.float32)
    rx_pos_xyz = np.asarray(rx_pos_xyz, dtype=np.float32)

    # 兼容：tx_power_dbm 支持标量或长度 Ntx 的向量
    tx_power_dbm_arr = np.asarray(tx_power_dbm, dtype=np.float64).reshape(-1)
    if tx_power_dbm_arr.size == 1:
        tx_power_dbm_arr = np.repeat(tx_power_dbm_arr, tx_pos_xyz.shape[0])

    # 添加 Tx
    for i, p in enumerate(tx_pos_xyz):
        tx = Transmitter(name=f"tx{i}", position=p)
        tx.power_dbm = float(tx_power_dbm_arr[i])
        scene.add(tx)

    # 添加 Rx
    for j, p in enumerate(rx_pos_xyz):
        rx = Receiver(name=f"rx{j}", position=p)
        scene.add(rx)

    # ---- PathSolver: switch scattering by global flag ----
    solver_kwargs = dict(
        scene=scene,
        max_depth=int(max_depth),
        los=True,
        specular_reflection=True,
        diffuse_reflection=bool(ENABLE_SCATTERING),    # <= 核心开关
        refraction=bool(ENABLE_REFRACTION),
        diffraction=(int(max_diff) > 0),
        edge_diffraction=bool(ENABLE_EDGE_DIFFRACTION),
        synthetic_array=bool(SYNTHETIC_ARRAY),
        seed=int(SEED),
    )

    paths = _PATH_SOLVER(**solver_kwargs)

    # 从 Paths 得到 CIR：a 的能量和就是链路"线性增益"（再乘 Tx 功率）
    a, _ = paths.cir(out_type="numpy")  # shape: [Nrx, Nrx_ant, Ntx, Ntx_ant, Npaths, Ntime] :contentReference[oaicite:1]{index=1}
    gain_lin = np.sum(np.abs(a)**2, axis=(1, 3, 4, 5))  # -> [Nrx, Ntx]

    p_tx_w = 10.0**((tx_power_dbm_arr - 30.0)/10.0)     # [Ntx]
    p_rx_w = gain_lin * p_tx_w.reshape(1, -1)           # [Nrx, Ntx]

    p_dbm = 10.0*np.log10(np.maximum(p_rx_w, 1e-30)) + 30.0
    return p_dbm.astype(np.float64)

def gpu_report():
    import subprocess
    try:
        txt = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=index,name,memory.total,pci.bus_id", "--format=csv,noheader"],
            universal_newlines=True
        )
        return txt
    except Exception as e:
        return repr(e)