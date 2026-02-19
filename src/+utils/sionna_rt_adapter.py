# # pycode/sionna_rt_adapter.py
# import numpy as np
# 
# from sionna.rt import load_scene, Transmitter, Receiver, PlanarArray, RadioMapSolver
# 
# _SCENE_CACHE = {}
# 
# # ---------------------------
# # Hyper-parameters (tune here)
# # ---------------------------
# RM_CELL_SIZE_M = 0.25       # 覆盖图网格分辨率（越小越慢、越细）
# RM_MARGIN_M   = 1.0         # 覆盖图在(rx bbox)基础上的外扩边界
# RM_SAMPLES_PER_TX = 2_000_000  # 每个TX的蒙特卡洛采样数（越大越稳但越慢）先 5e5-2e6
# RM_SEED = 2
# 
# # 你可以固定传播机制（更接近"确定性"）
# RM_LOS = True
# RM_SPECULAR = True
# RM_REFRACTION = False
# RM_DIFFUSE = False
# RM_EDGE_DIFFRACTION = False
# RM_DIFFRACTION_LIT_REGION = True
# 
# def _scene_key(scene_path, freq_hz):
#     return (str(scene_path), float(freq_hz))
# 
# def _to_N3(x):
#     """Accept (N,3) or (3,N)"""
#     a = np.asarray(x, dtype=np.float32)
#     if a.ndim != 2:
#         raise ValueError(f"pos array must be 2D, got shape {a.shape}")
#     if a.shape[1] == 3:
#         return a
#     if a.shape[0] == 3:
#         return a.T
#     raise ValueError(f"pos array must be (N,3) or (3,N), got shape {a.shape}")
# 
# def get_scene(scene_path, freq_hz):
#     key = _scene_key(scene_path, freq_hz)
#     if key in _SCENE_CACHE:
#         return _SCENE_CACHE[key]
# 
#     scene = load_scene(scene_path)
#     scene.frequency = float(freq_hz)  # Scene.frequency exists in Sionna RT
#     _SCENE_CACHE[key] = scene
#     return scene
# 
# def _apply_radio_material(scene, material_tag):
#     # 你之前提到自定义材质/版本坑，这里只做"radio_material 绑定"的最小实现：
#     # 若 material_tag 不存在则忽略
#     try:
#         rm = scene.radio_materials[material_tag]
#     except Exception:
#         return
#     # 给所有 scene objects 绑同一 radio material（可按需更精细）
#     for _, obj in scene.objects.items():
#         try:
#             obj.radio_material = rm
#         except Exception:
#             pass
# 
# def sigstrength(scene_path,
#                 tx_pos_xyz,
#                 rx_pos_xyz,
#                 freq_hz,
#                 tx_power_dbm,
#                 max_depth=5,
#                 max_diff=2,
#                 material_tag="concrete"):
#     """
#     Return P_dBm with shape [Nrx, Ntx]
#     """
#     tx_pos = _to_N3(tx_pos_xyz)
#     rx_pos = _to_N3(rx_pos_xyz)
# 
#     scene = get_scene(scene_path, freq_hz)
# 
#     # 清空旧的 Tx/Rx
#     for name in list(scene.transmitters.keys()):
#         scene.remove(name)
#     for name in list(scene.receivers.keys()):
#         scene.remove(name)
# 
#     # 天线阵列：保持最简单的单天线各向同性（否则 all_set(radio_map=True) 会要求阵列）
#     scene.tx_array = PlanarArray(num_rows=1, num_cols=1,
#                                  vertical_spacing=0.5, horizontal_spacing=0.5,
#                                  pattern="iso", polarization="V")
#     scene.rx_array = PlanarArray(num_rows=1, num_cols=1,
#                                  vertical_spacing=0.5, horizontal_spacing=0.5,
#                                  pattern="iso", polarization="V")
# 
#     _apply_radio_material(scene, str(material_tag))
# 
#     # 添加 Tx
#     for i, p in enumerate(tx_pos):
#         tx = Transmitter(name=f"tx{i}", position=p, orientation=[0,0,0])
#         tx.power_dbm = float(tx_power_dbm)
#         scene.add(tx)
# 
#     # 添加 Rx（用来获取 rm.rx_cell_indices 对应每个rx落在哪个cell）
#     for j, p in enumerate(rx_pos):
#         rx = Receiver(name=f"rx{j}", position=p, orientation=[0,0,0])
#         scene.add(rx)
# 
#     # ------- Radio map plane (只覆盖 rx 的 bbox，避免整场景大地图) -------
#     x_min, y_min = float(np.min(rx_pos[:,0])), float(np.min(rx_pos[:,1]))
#     x_max, y_max = float(np.max(rx_pos[:,0])), float(np.max(rx_pos[:,1]))
#     cx = 0.5*(x_min + x_max)
#     cy = 0.5*(y_min + y_max)
#     cz = float(np.mean(rx_pos[:,2]))  # 覆盖图平面高度（默认按rx高度）
#     sx = (x_max - x_min) + 2.0*RM_MARGIN_M
#     sy = (y_max - y_min) + 2.0*RM_MARGIN_M
#     sx = max(sx, RM_CELL_SIZE_M)
#     sy = max(sy, RM_CELL_SIZE_M)
# 
#     solver = RadioMapSolver()
#     rm = solver(
#         scene,
#         center=[cx, cy, cz],
#         orientation=[0.0, 0.0, 0.0],
#         size=[sx, sy],
#         cell_size=[RM_CELL_SIZE_M, RM_CELL_SIZE_M],
#         samples_per_tx=int(RM_SAMPLES_PER_TX),
#         max_depth=int(max_depth),
#         los=bool(RM_LOS),
#         specular_reflection=bool(RM_SPECULAR),
#         diffuse_reflection=bool(RM_DIFFUSE),
#         refraction=bool(RM_REFRACTION),
#         diffraction=bool(int(max_diff) > 0),
#         edge_diffraction=bool(RM_EDGE_DIFFRACTION),
#         diffraction_lit_region=bool(RM_DIFFRACTION_LIT_REGION),
#         seed=int(RM_SEED),
#     )
#     # RadioMap.rss 是 W；rss = path_gain * tx_power(W) :contentReference[oaicite:1]{index=1}
# 
#     # 取每个 rx 所在 cell 的 rss 值（对每个 tx）
#     # --- NumPy view once ---
#     rss_np = np.array(rm.rss.numpy(), dtype=np.float64)   # [Ntx, Ny, Nx]
# 
#     idx = rm.rx_cell_indices                              # (col,row)
#     col = np.array(idx.x, dtype=np.int64)
#     row = np.array(idx.y, dtype=np.int64)
# 
#     # (optional) clip for safety during debug
#     Ny, Nx = int(rss_np.shape[1]), int(rss_np.shape[2])
#     col_c = np.clip(col, 0, Nx-1)
#     row_c = np.clip(row, 0, Ny-1)
# 
#     # Correct sampling: rss[:, row, col] -> [Ntx, Nrx]
#     rss_k = rss_np[:, row_c, col_c]
# 
#     p_dbm = 10.0*np.log10(np.maximum(rss_k, 1e-30)) + 30.0
#     return p_dbm.T.astype(np.float64)    # -> [Nrx, Ntx]

# sionna_rt_adapter.py
import os

# （可选）打印/确认：MATLAB 侧设置的 CUDA_VISIBLE_DEVICES 是否生效
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