#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_workflows.py - Anima OC 워크플로 생성기 (ComfyUI UI 포맷 + API 포맷)

Pure Python 3.8+ standard library only. Every workflow graph is defined exactly once in this
file (nodes, links, groups, Korean MarkdownNote guides) and emitted in two formats:

  workflows/<name>.json       ComfyUI UI workflow (drag & drop onto the ComfyUI canvas; schema 0.4)
  workflows/api/<name>.json   API prompt format (POST {"prompt": <file>} to /prompt).
                              Bypassed (Ctrl+B, mode 4) nodes are removed and their links are
                              rerouted exactly like the ComfyUI frontend does; MarkdownNote nodes
                              are UI-only and are not part of the API format.

Usage
  python tools/build_workflows.py                      # (re)write ../workflows and ../workflows/api
  python tools/build_workflows.py --out DIR            # write <DIR>/*.json and <DIR>/api/*.json
  python tools/build_workflows.py --check-object-info http://127.0.0.1:8188/object_info
      # verify the embedded node schema and every chosen widget value (incl. model file names)
      # against a running ComfyUI (or a saved object_info.json). Exit code 1 on any mismatch.

The embedded SCHEMA (input order, socket-vs-widget, enum options, output types) was generated
from GET /object_info of ComfyUI master e9027f2 (v0.38.0-32-ge9027f2, 2026-10-03) with
ComfyUI-Impact-Pack 8.28.3 (429d015) and ComfyUI-Impact-Subpack 1.3.5 (50c7b71).
UI widgets_values follow the frontend rule: one value per widget in input order, plus the extra
"control_after_generate" value right after every `seed` widget and the extra "image" value
after LoadImage's upload widget.
"""
import argparse
import copy
import json
import os
import re
import sys
import urllib.request
import uuid

CORE_VER = "0.38.0"
CUSTOM_NODE_PACKS = {
    # node type -> (cnr_id, version) for nodes that are not part of ComfyUI core
    "FaceDetailer": ("comfyui-impact-pack", "8.28.3"),
    "UltralyticsDetectorProvider": ("comfyui-impact-subpack", "1.3.5"),
}
FRONTEND_ONLY = {"MarkdownNote", "Note"}
NOTE_COLOR = {"color": "#222", "bgcolor": "#000"}
TITLE_H = 30        # LiteGraph node title height (node.pos is the top-left of the body)
GROUP_TITLE_H = 34  # group title bar height (font_size 24)
# Minimum free space between two nodes. Node sizes below are the heights the Vue node renderer
# ("Modern Node Design / Nodes 2.0", frontend 1.53) actually draws, so the same layout is clean in
# both the classic canvas and the Vue renderer.
NODE_GAP = 30
# Initial view: scale must stay >= 0.58 or the frontend draws nodes in low-detail mode (no text) at
# devicePixelRatio 1 (threshold = MinFontSizeForLOD 8 / NODE_TEXT_SIZE 14). x offset 680 keeps the
# guide note (x = -560) clear of the 56px left icon bar.
DS_SCALE = 0.6
DS_OFFSET = (680, 80)

HF = "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files"
HF_LORA = "https://huggingface.co/circlestone-labs/Anima-Official-LoRAs/resolve/main"
MODELS = {
    "aesthetic": ("anima-aesthetic-v1.1.safetensors", HF + "/diffusion_models/anima-aesthetic-v1.1.safetensors", "diffusion_models"),
    "turbo": ("anima-turbo-v1.1.safetensors", HF + "/diffusion_models/anima-turbo-v1.1.safetensors", "diffusion_models"),
    "te": ("qwen_3_06b_base.safetensors", HF + "/text_encoders/qwen_3_06b_base.safetensors", "text_encoders"),
    "vae": ("qwen_image_vae.safetensors", HF + "/vae/qwen_image_vae.safetensors", "vae"),
    "rl": ("anima-rl-v0.1.safetensors", HF_LORA + "/anima-rl-v0.1.safetensors", "loras"),
    "highres": ("anima-highres-aesthetic-boost.safetensors", HF_LORA + "/anima-highres-aesthetic-boost.safetensors", "loras"),
    "turbo_lora": ("anima-turbo-lora-v0.2.safetensors", HF_LORA + "/anima-turbo-lora-v0.2.safetensors", "loras"),
    "esrgan": ("RealESRGAN_x4plus_anime_6B.pth", "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth", "upscale_models"),
    "lllite": ("anima-lllite-any-test-like-v2.safetensors", "https://huggingface.co/Comfy-Org/Anima-LLLite/resolve/main/model_patches/anima-lllite-any-test-like-v2.safetensors", "model_patches"),
}
# Civitai LoRAs need an API token, so they get no "models" metadata (the frontend could not download them).
CIVITAI_LORAS = {
    "masterpiece": "anima-base-1-masterpiece-v51.safetensors",
    "sheet": "Character Sheet for Anima.safetensors",
    "bluearchive": "BlueArchiveStyleB1.safetensors",
}


def model(key):
    name, url, directory = MODELS[key]
    return {"name": name, "url": url, "directory": directory}


# =============================================================================================
# Node schema (generated from ComfyUI GET /object_info; see --check-object-info)
# =============================================================================================
SCHEMA = {
    'UNETLoader': {
        'display': 'Load Diffusion Model', 'module': 'nodes',
        'inputs': [
            {"name": "unet_name", "type": "COMBO", "kind": "widget"},
            {"name": "weight_dtype", "type": "COMBO", "kind": "widget", "options": ["default", "fp8_e4m3fn", "fp8_e4m3fn_fast", "fp8_e5m2"]},
        ],
        'outputs': [["MODEL", "MODEL", False]],
    },
    'CLIPLoader': {
        'display': 'Load CLIP', 'module': 'nodes',
        'inputs': [
            {"name": "clip_name", "type": "COMBO", "kind": "widget"},
            {"name": "type", "type": "COMBO", "kind": "widget", "options": ["stable_diffusion", "stable_cascade", "sd3", "stable_audio", "mochi", "ltxv", "pixart", "cosmos", "lumina2", "wan", "hidream", "chroma", "ace", "omnigen2", "qwen_image", "hunyuan_image", "flux2", "ovis", "longcat_image", "cogvideox", "lens", "pixeldit", "ideogram4", "boogu", "krea2", "joyimage", "mage", "minimax", "yue2"]},
            {"name": "device", "type": "COMBO", "kind": "widget", "optional": True, "options": ["default", "cpu"]},
        ],
        'outputs': [["CLIP", "CLIP", False]],
    },
    'VAELoader': {
        'display': 'Load VAE', 'module': 'nodes',
        'inputs': [
            {"name": "vae_name", "type": "COMBO", "kind": "widget"},
        ],
        'outputs': [["VAE", "VAE", False]],
    },
    'LoraLoaderModelOnly': {
        'display': 'Load LoRA', 'module': 'nodes',
        'inputs': [
            {"name": "model", "type": "MODEL", "kind": "socket"},
            {"name": "lora_name", "type": "COMBO", "kind": "widget"},
            {"name": "strength_model", "type": "FLOAT", "kind": "widget", "default": 1.0},
        ],
        'outputs': [["MODEL", "MODEL", False]],
    },
    'LoraLoader': {
        'display': 'Load LoRA (Model and CLIP)', 'module': 'nodes',
        'inputs': [
            {"name": "model", "type": "MODEL", "kind": "socket"},
            {"name": "clip", "type": "CLIP", "kind": "socket"},
            {"name": "lora_name", "type": "COMBO", "kind": "widget"},
            {"name": "strength_model", "type": "FLOAT", "kind": "widget", "default": 1.0},
            {"name": "strength_clip", "type": "FLOAT", "kind": "widget", "default": 1.0},
        ],
        'outputs': [["MODEL", "MODEL", False], ["CLIP", "CLIP", False]],
    },
    'CLIPTextEncode': {
        'display': 'CLIP Text Encode (Prompt)', 'module': 'nodes',
        'inputs': [
            {"name": "text", "type": "STRING", "kind": "widget"},
            {"name": "clip", "type": "CLIP", "kind": "socket"},
        ],
        'outputs': [["CONDITIONING", "CONDITIONING", False]],
    },
    'EmptyLatentImage': {
        'display': 'Empty Latent Image', 'module': 'nodes',
        'inputs': [
            {"name": "width", "type": "INT", "kind": "widget", "default": 1024},
            {"name": "height", "type": "INT", "kind": "widget", "default": 1024},
            {"name": "batch_size", "type": "INT", "kind": "widget", "default": 1},
        ],
        'outputs': [["LATENT", "LATENT", False]],
    },
    'KSampler': {
        'display': 'KSampler', 'module': 'nodes',
        'inputs': [
            {"name": "model", "type": "MODEL", "kind": "socket"},
            {"name": "seed", "type": "INT", "kind": "widget", "default": 0, "seed": True},
            {"name": "steps", "type": "INT", "kind": "widget", "default": 20},
            {"name": "cfg", "type": "FLOAT", "kind": "widget", "default": 8.0},
            {"name": "sampler_name", "type": "COMBO", "kind": "widget", "options": ["euler", "euler_cfg_pp", "euler_ancestral", "euler_ancestral_cfg_pp", "heun", "heunpp2", "exp_heun_2_x0", "exp_heun_2_x0_sde", "dpm_2", "dpm_2_ancestral", "lms", "dpm_fast", "dpm_adaptive", "dpmpp_2s_ancestral", "dpmpp_2s_ancestral_cfg_pp", "dpmpp_sde", "dpmpp_sde_gpu", "dpmpp_2m", "dpmpp_2m_cfg_pp", "dpmpp_2m_sde", "dpmpp_2m_sde_gpu", "dpmpp_2m_sde_heun", "dpmpp_2m_sde_heun_gpu", "dpmpp_3m_sde", "dpmpp_3m_sde_gpu", "ddpm", "lcm", "ipndm", "ipndm_v", "deis", "cfgpp_ud10_ab", "res_multistep", "res_multistep_cfg_pp", "res_multistep_ancestral", "res_multistep_ancestral_cfg_pp", "gradient_estimation", "gradient_estimation_cfg_pp", "er_sde", "seeds_2", "seeds_3", "sa_solver", "sa_solver_pece", "ddim", "uni_pc", "uni_pc_bh2"]},
            {"name": "scheduler", "type": "COMBO", "kind": "widget", "options": ["simple", "sgm_uniform", "karras", "exponential", "ddim_uniform", "beta", "normal", "linear_quadratic", "kl_optimal"]},
            {"name": "positive", "type": "CONDITIONING", "kind": "socket"},
            {"name": "negative", "type": "CONDITIONING", "kind": "socket"},
            {"name": "latent_image", "type": "LATENT", "kind": "socket"},
            {"name": "denoise", "type": "FLOAT", "kind": "widget", "default": 1.0},
        ],
        'outputs': [["LATENT", "LATENT", False]],
    },
    'VAEDecode': {
        'display': 'VAE Decode', 'module': 'nodes',
        'inputs': [
            {"name": "samples", "type": "LATENT", "kind": "socket"},
            {"name": "vae", "type": "VAE", "kind": "socket"},
        ],
        'outputs': [["IMAGE", "IMAGE", False]],
    },
    'SaveImage': {
        'display': 'Save Image', 'module': 'nodes',
        'inputs': [
            {"name": "images", "type": "IMAGE", "kind": "socket"},
            {"name": "filename_prefix", "type": "STRING", "kind": "widget", "default": "ComfyUI"},
        ],
        'outputs': [["images", "IMAGE", False]],
    },
    'UpscaleModelLoader': {
        'display': 'Load Upscale Model', 'module': 'comfy_extras.nodes_upscale_model',
        'inputs': [
            {"name": "model_name", "type": "COMBO", "kind": "widget"},
        ],
        'outputs': [["UPSCALE_MODEL", "UPSCALE_MODEL", False]],
    },
    'ImageUpscaleWithModel': {
        'display': 'Upscale Image (using Model)', 'module': 'comfy_extras.nodes_upscale_model',
        'inputs': [
            {"name": "upscale_model", "type": "UPSCALE_MODEL", "kind": "socket"},
            {"name": "image", "type": "IMAGE", "kind": "socket"},
        ],
        'outputs': [["IMAGE", "IMAGE", False]],
    },
    'ImageScaleToTotalPixels': {
        'display': 'Scale Image to Total Pixels', 'module': 'comfy_extras.nodes_post_processing',
        'inputs': [
            {"name": "image", "type": "IMAGE", "kind": "socket"},
            {"name": "upscale_method", "type": "COMBO", "kind": "widget", "options": ["nearest-exact", "bilinear", "area", "bicubic", "lanczos"]},
            {"name": "megapixels", "type": "FLOAT", "kind": "widget", "default": 1.0},
            {"name": "resolution_steps", "type": "INT", "kind": "widget", "default": 1},
        ],
        'outputs': [["IMAGE", "IMAGE", False]],
    },
    'RebatchImages': {
        'display': 'Rebatch Images', 'module': 'comfy_extras.nodes_rebatch',
        'inputs': [
            {"name": "images", "type": "IMAGE", "kind": "socket"},
            {"name": "batch_size", "type": "INT", "kind": "widget", "default": 1},
        ],
        'outputs': [["IMAGE", "IMAGE", True]],
    },
    'VAEEncode': {
        'display': 'VAE Encode', 'module': 'nodes',
        'inputs': [
            {"name": "pixels", "type": "IMAGE", "kind": "socket"},
            {"name": "vae", "type": "VAE", "kind": "socket"},
        ],
        'outputs': [["LATENT", "LATENT", False]],
    },
    'LoadImage': {
        'display': 'Load Image', 'module': 'nodes',
        'inputs': [
            {"name": "image", "type": "COMBO", "kind": "widget", "upload": True},
        ],
        'outputs': [["IMAGE", "IMAGE", False], ["MASK", "MASK", False]],
    },
    'UltralyticsDetectorProvider': {
        'display': 'UltralyticsDetectorProvider', 'module': 'custom_nodes.ComfyUI-Impact-Subpack',
        'inputs': [
            {"name": "model_name", "type": "COMBO", "kind": "widget"},
        ],
        'outputs': [["BBOX_DETECTOR", "BBOX_DETECTOR", False], ["SEGM_DETECTOR", "SEGM_DETECTOR", False]],
    },
    'FaceDetailer': {
        'display': 'FaceDetailer', 'module': 'custom_nodes.ComfyUI-Impact-Pack',
        'inputs': [
            {"name": "image", "type": "IMAGE", "kind": "socket"},
            {"name": "model", "type": "MODEL", "kind": "socket"},
            {"name": "clip", "type": "CLIP", "kind": "socket"},
            {"name": "vae", "type": "VAE", "kind": "socket"},
            {"name": "guide_size", "type": "FLOAT", "kind": "widget", "default": 512},
            {"name": "guide_size_for", "type": "BOOLEAN", "kind": "widget", "default": True},
            {"name": "max_size", "type": "FLOAT", "kind": "widget", "default": 1024},
            {"name": "seed", "type": "INT", "kind": "widget", "default": 0, "seed": True},
            {"name": "steps", "type": "INT", "kind": "widget", "default": 20},
            {"name": "cfg", "type": "FLOAT", "kind": "widget", "default": 8.0},
            {"name": "sampler_name", "type": "COMBO", "kind": "widget", "options": ["euler", "euler_cfg_pp", "euler_ancestral", "euler_ancestral_cfg_pp", "heun", "heunpp2", "exp_heun_2_x0", "exp_heun_2_x0_sde", "dpm_2", "dpm_2_ancestral", "lms", "dpm_fast", "dpm_adaptive", "dpmpp_2s_ancestral", "dpmpp_2s_ancestral_cfg_pp", "dpmpp_sde", "dpmpp_sde_gpu", "dpmpp_2m", "dpmpp_2m_cfg_pp", "dpmpp_2m_sde", "dpmpp_2m_sde_gpu", "dpmpp_2m_sde_heun", "dpmpp_2m_sde_heun_gpu", "dpmpp_3m_sde", "dpmpp_3m_sde_gpu", "ddpm", "lcm", "ipndm", "ipndm_v", "deis", "cfgpp_ud10_ab", "res_multistep", "res_multistep_cfg_pp", "res_multistep_ancestral", "res_multistep_ancestral_cfg_pp", "gradient_estimation", "gradient_estimation_cfg_pp", "er_sde", "seeds_2", "seeds_3", "sa_solver", "sa_solver_pece", "ddim", "uni_pc", "uni_pc_bh2"]},
            {"name": "scheduler", "type": "COMBO", "kind": "widget", "options": ["simple", "sgm_uniform", "karras", "exponential", "ddim_uniform", "beta", "normal", "linear_quadratic", "kl_optimal", "AYS SDXL", "AYS SD1", "AYS SVD", "GITS[coeff=1.2]", "LTXV[default]", "OSS FLUX", "OSS Wan", "OSS Chroma"]},
            {"name": "positive", "type": "CONDITIONING", "kind": "socket"},
            {"name": "negative", "type": "CONDITIONING", "kind": "socket"},
            {"name": "denoise", "type": "FLOAT", "kind": "widget", "default": 0.5},
            {"name": "feather", "type": "INT", "kind": "widget", "default": 5},
            {"name": "noise_mask", "type": "BOOLEAN", "kind": "widget", "default": True},
            {"name": "force_inpaint", "type": "BOOLEAN", "kind": "widget", "default": True},
            {"name": "bbox_threshold", "type": "FLOAT", "kind": "widget", "default": 0.5},
            {"name": "bbox_dilation", "type": "INT", "kind": "widget", "default": 10},
            {"name": "bbox_crop_factor", "type": "FLOAT", "kind": "widget", "default": 3.0},
            {"name": "sam_detection_hint", "type": "COMBO", "kind": "widget", "options": ["center-1", "horizontal-2", "vertical-2", "rect-4", "diamond-4", "mask-area", "mask-points", "mask-point-bbox", "none"]},
            {"name": "sam_dilation", "type": "INT", "kind": "widget", "default": 0},
            {"name": "sam_threshold", "type": "FLOAT", "kind": "widget", "default": 0.93},
            {"name": "sam_bbox_expansion", "type": "INT", "kind": "widget", "default": 0},
            {"name": "sam_mask_hint_threshold", "type": "FLOAT", "kind": "widget", "default": 0.7},
            {"name": "sam_mask_hint_use_negative", "type": "COMBO", "kind": "widget", "options": ["False", "Small", "Outter"]},
            {"name": "drop_size", "type": "INT", "kind": "widget", "default": 10},
            {"name": "bbox_detector", "type": "BBOX_DETECTOR", "kind": "socket"},
            {"name": "wildcard", "type": "STRING", "kind": "widget"},
            {"name": "cycle", "type": "INT", "kind": "widget", "default": 1},
            {"name": "sam_model_opt", "type": "SAM_MODEL", "kind": "socket", "optional": True},
            {"name": "segm_detector_opt", "type": "SEGM_DETECTOR", "kind": "socket", "optional": True},
            {"name": "detailer_hook", "type": "DETAILER_HOOK", "kind": "socket", "optional": True},
            {"name": "inpaint_model", "type": "BOOLEAN", "kind": "widget", "optional": True, "default": False},
            {"name": "noise_mask_feather", "type": "INT", "kind": "widget", "optional": True, "default": 20},
            {"name": "scheduler_func_opt", "type": "SCHEDULER_FUNC", "kind": "socket", "optional": True},
            {"name": "tiled_encode", "type": "BOOLEAN", "kind": "widget", "optional": True, "default": False},
            {"name": "tiled_decode", "type": "BOOLEAN", "kind": "widget", "optional": True, "default": False},
        ],
        'outputs': [["image", "IMAGE", False], ["cropped_refined", "IMAGE", True], ["cropped_enhanced_alpha", "IMAGE", True], ["mask", "MASK", False], ["detailer_pipe", "DETAILER_PIPE", False], ["cnet_images", "IMAGE", True]],
    },
    'ImageScaleBy': {
        'display': 'Upscale Image By', 'module': 'nodes',
        'inputs': [
            {"name": "image", "type": "IMAGE", "kind": "socket"},
            {"name": "upscale_method", "type": "COMBO", "kind": "widget", "options": ["nearest-exact", "bilinear", "area", "bicubic", "lanczos"]},
            {"name": "scale_by", "type": "FLOAT", "kind": "widget", "default": 1.0},
        ],
        'outputs': [["IMAGE", "IMAGE", False]],
    },
    'PreviewImage': {
        'display': 'Preview Image', 'module': 'nodes',
        'inputs': [
            {"name": "images", "type": "IMAGE", "kind": "socket"},
        ],
        'outputs': [["images", "IMAGE", False]],
    },
    'ModelPatchLoader': {
        'display': 'Load Model Patch', 'module': 'comfy_extras.nodes_model_patch',
        'inputs': [
            {"name": "name", "type": "COMBO", "kind": "widget"},
        ],
        'outputs': [["MODEL_PATCH", "MODEL_PATCH", False]],
    },
    'Canny': {
        'display': 'Detect Edges (Canny)', 'module': 'comfy_extras.nodes_canny',
        'inputs': [
            {"name": "image", "type": "IMAGE", "kind": "socket"},
            {"name": "low_threshold", "type": "FLOAT", "kind": "widget", "default": 0.4},
            {"name": "high_threshold", "type": "FLOAT", "kind": "widget", "default": 0.8},
        ],
        'outputs': [["IMAGE", "IMAGE", False]],
    },
    'ImageInvert': {
        'display': 'Invert Image Colors', 'module': 'nodes',
        'inputs': [
            {"name": "image", "type": "IMAGE", "kind": "socket"},
        ],
        'outputs': [["IMAGE", "IMAGE", False]],
    },
    'AnimaLLLiteApply': {
        'display': 'Apply Anima LLLite', 'module': 'comfy_extras.nodes_model_patch',
        'inputs': [
            {"name": "model", "type": "MODEL", "kind": "socket"},
            {"name": "model_patch", "type": "MODEL_PATCH", "kind": "socket"},
            {"name": "image", "type": "IMAGE", "kind": "socket"},
            {"name": "strength", "type": "FLOAT", "kind": "widget", "default": 1.0},
            {"name": "start_percent", "type": "FLOAT", "kind": "widget", "default": 0.0},
            {"name": "end_percent", "type": "FLOAT", "kind": "widget", "default": 1.0},
            {"name": "mask", "type": "MASK", "kind": "socket", "optional": True},
        ],
        'outputs': [["MODEL", "MODEL", False]],
    },
    'GetImageSize': {
        'display': 'Get Image Size', 'module': 'comfy_extras.nodes_images',
        'inputs': [
            {"name": "image", "type": "IMAGE", "kind": "socket"},
        ],
        'outputs': [["width", "INT", False], ["height", "INT", False], ["batch_size", "INT", False]],
    },
}


# =============================================================================================
# Graph model
# =============================================================================================
class Node:
    def __init__(self, nid, ntype, pos, size, title=None, mode=0, widgets=None, models=None,
                 color=None, bgcolor=None, widget_inputs=()):
        self.id = nid
        self.type = ntype
        self.pos = list(pos)
        self.size = list(size)
        self.title = title
        self.mode = mode                      # 0 = always, 2 = never (mute), 4 = bypass
        self.widgets = dict(widgets or {})
        self.models = models
        self.color = color
        self.bgcolor = bgcolor
        self.widget_inputs = tuple(widget_inputs)   # widgets converted to (linked) input sockets

    # -- schema helpers -------------------------------------------------------------------
    @property
    def schema(self):
        return SCHEMA[self.type]

    def ui_inputs(self):
        """Input slots exactly as the UI workflow lists them: real sockets + linked widgets."""
        if self.type in FRONTEND_ONLY:
            return []
        out = []
        for inp in self.schema["inputs"]:
            if inp["kind"] == "socket" or inp["name"] in self.widget_inputs:
                out.append(inp)
        return out

    def outputs(self):
        if self.type in FRONTEND_ONLY:
            return []
        return self.schema["outputs"]

    def widget_values(self):
        """UI widgets_values (frontend order, incl. control_after_generate / upload values)."""
        if self.type in FRONTEND_ONLY:
            return [self.widgets["text"]]
        w = dict(self.widgets)
        vals = []
        for inp in self.schema["inputs"]:
            if inp["kind"] != "widget":
                continue
            name = inp["name"]
            if name in w:
                v = w.pop(name)
            elif "default" in inp:
                v = inp["default"]
            else:
                raise ValueError("node %s (%s): widget %r has no value and no default" % (self.id, self.type, name))
            vals.append(v)
            if inp.get("seed"):
                vals.append(w.pop("control_after_generate", "randomize"))
            if inp.get("upload"):
                vals.append("image")
        if w:
            raise ValueError("node %s (%s): unknown widgets %s" % (self.id, self.type, sorted(w)))
        return vals

    def api_widget(self, name):
        if name in self.widgets:
            return self.widgets[name]
        for inp in self.schema["inputs"]:
            if inp["name"] == name and "default" in inp:
                return inp["default"]
        raise KeyError(name)

    def rect(self):
        """Bounding box including the title bar: [x, y, w, h]."""
        return [self.pos[0], self.pos[1] - TITLE_H, self.size[0], self.size[1] + TITLE_H]


class Graph:
    def __init__(self, filename, title, ds_scale=DS_SCALE, ds_offset=DS_OFFSET):
        self.filename = filename
        self.title = title
        self.ds = {"scale": ds_scale, "offset": list(ds_offset)}
        self.nodes = {}
        self.links = {}      # link_id -> (src_id, src_slot, dst_id, dst_input_name)
        self.groups = []     # (title, bounding, color, member_ids)

    # -- construction ---------------------------------------------------------------------
    def add(self, nid, ntype, pos, size, **kw):
        if nid in self.nodes:
            raise ValueError("duplicate node id %s" % nid)
        if ntype not in SCHEMA and ntype not in FRONTEND_ONLY:
            raise ValueError("unknown node type %s" % ntype)
        n = Node(nid, ntype, pos, size, **kw)
        self.nodes[nid] = n
        return n

    def note(self, nid, title, pos, size, text):
        # LiteGraph "black" palette: inline `code` in markdown stays readable in both the classic
        # canvas and the Vue node renderer (on the default yellow note it is blue-on-blue in Vue mode).
        return self.add(nid, "MarkdownNote", pos, size, title=title, widgets={"text": text.strip("\n")},
                        color=NOTE_COLOR["color"], bgcolor=NOTE_COLOR["bgcolor"])

    def link(self, lid, src, src_slot, dst, dst_input):
        if lid in self.links:
            raise ValueError("duplicate link id %s" % lid)
        self.links[lid] = (src, src_slot, dst, dst_input)

    def group(self, title, bounding, color, members):
        self.groups.append((title, list(bounding), color, list(members)))

    # -- link helpers ---------------------------------------------------------------------
    def input_slot(self, nid, name):
        for i, inp in enumerate(self.nodes[nid].ui_inputs()):
            if inp["name"] == name:
                return i
        raise ValueError("node %s (%s) has no input socket %r" % (nid, self.nodes[nid].type, name))

    def link_type(self, lid):
        src, slot, _, _ = self.links[lid]
        return self.nodes[src].outputs()[slot][1]

    def incoming(self, nid, name):
        for lid, (s, ss, d, dn) in self.links.items():
            if d == nid and dn == name:
                return lid
        return None

    def outgoing(self, nid, slot):
        return sorted(lid for lid, (s, ss, d, dn) in self.links.items() if s == nid and ss == slot)

    # -- checks ---------------------------------------------------------------------------
    def check(self):
        errors = []
        seen_inputs = set()
        for lid, (s, ss, d, dn) in sorted(self.links.items()):
            if s not in self.nodes or d not in self.nodes:
                errors.append("link %s references a missing node" % lid)
                continue
            outs = self.nodes[s].outputs()
            if ss >= len(outs):
                errors.append("link %s: node %s has no output slot %s" % (lid, s, ss))
                continue
            try:
                slot = self.input_slot(d, dn)
            except ValueError as e:
                errors.append("link %s: %s" % (lid, e))
                continue
            itype = self.nodes[d].ui_inputs()[slot]["type"]
            if itype != outs[ss][1]:
                errors.append("link %s: type %s -> %s(%s) mismatch" % (lid, outs[ss][1], dn, itype))
            if (d, dn) in seen_inputs:
                errors.append("input %s.%s linked twice" % (d, dn))
            seen_inputs.add((d, dn))
        for n in self.nodes.values():
            if n.type in FRONTEND_ONLY:
                continue
            for inp in n.ui_inputs():
                if not inp.get("optional") and self.incoming(n.id, inp["name"]) is None:
                    errors.append("node %s (%s): required input %r is not linked" % (n.id, n.type, inp["name"]))
            try:
                n.widget_values()
            except ValueError as e:
                errors.append(str(e))
            for inp in n.schema["inputs"]:
                if "options" in inp and inp["kind"] == "widget" and inp["name"] in n.widgets:
                    if n.widgets[inp["name"]] not in inp["options"]:
                        errors.append("node %s: %r not a valid %s" % (n.id, n.widgets[inp["name"]], inp["name"]))
        # layout: every node rect (incl. title) inside its declared group, below the group title,
        # no node overlaps another node, no group overlaps another group.
        def inside(r, b):
            return r[0] >= b[0] and r[1] >= b[1] + GROUP_TITLE_H and r[0] + r[2] <= b[0] + b[2] and r[1] + r[3] <= b[1] + b[3]

        def overlap(a, b):
            return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]

        def grow(r, d):
            return [r[0] - d, r[1] - d, r[2] + 2 * d, r[3] + 2 * d]

        declared = {}
        for title, b, _, members in self.groups:
            for m in members:
                declared[m] = title
                if not inside(self.nodes[m].rect(), b):
                    errors.append("layout: node %s is not fully inside group %r" % (m, title))
        for n in self.nodes.values():
            for title, b, _, members in self.groups:
                if n.id not in members and overlap(n.rect(), b):
                    errors.append("layout: node %s overlaps group %r it does not belong to" % (n.id, title))
        ids = sorted(self.nodes)
        for i, a in enumerate(ids):
            for b_ in ids[i + 1:]:
                if overlap(grow(self.nodes[a].rect(), NODE_GAP / 2.0), grow(self.nodes[b_].rect(), NODE_GAP / 2.0 - 0.01)):
                    errors.append("layout: nodes %s and %s overlap or are closer than %dpx" % (a, b_, NODE_GAP))
        for i, g1 in enumerate(self.groups):
            for g2 in self.groups[i + 1:]:
                if overlap(g1[1], g2[1]):
                    errors.append("layout: groups %r and %r overlap" % (g1[0], g2[0]))
        if errors:
            raise SystemExit("[%s] graph check failed:\n  " % self.filename + "\n  ".join(errors))

    # -- ordering -------------------------------------------------------------------------
    def exec_order(self):
        """Topological order (frontend 'order' field). Notes first, ties broken by node id."""
        notes = sorted(n for n in self.nodes if self.nodes[n].type in FRONTEND_ONLY)
        rest = [n for n in sorted(self.nodes) if n not in notes]
        deps = {n: set() for n in rest}
        for s, ss, d, dn in self.links.values():
            deps[d].add(s)
        order = list(notes)
        done = set(notes)
        while len(order) < len(self.nodes):
            ready = [n for n in rest if n not in done and deps[n] <= done]
            if not ready:
                raise SystemExit("[%s] cycle in graph" % self.filename)
            order.append(ready[0])
            done.add(ready[0])
        return {nid: i for i, nid in enumerate(order)}

    # -- UI format ------------------------------------------------------------------------
    def to_ui(self):
        self.check()
        order = self.exec_order()
        nodes = []
        for nid in sorted(self.nodes, key=lambda x: order[x]):
            n = self.nodes[nid]
            d = {"id": n.id, "type": n.type, "pos": n.pos, "size": n.size, "flags": {}, "order": order[nid], "mode": n.mode}
            inputs = []
            for inp in n.ui_inputs():
                e = {"name": inp["name"], "type": inp["type"]}
                if inp["kind"] == "widget":
                    e["widget"] = {"name": inp["name"]}
                if inp.get("optional"):
                    e["shape"] = 7
                e["link"] = self.incoming(nid, inp["name"])
                inputs.append(e)
            d["inputs"] = inputs
            outputs = []
            for slot, (oname, otype, is_list) in enumerate(n.outputs()):
                e = {"name": oname, "type": otype}
                links = self.outgoing(nid, slot)
                e["links"] = links if links else None
                if is_list:
                    e["shape"] = 6
                outputs.append(e)
            d["outputs"] = outputs
            if n.title:
                d["title"] = n.title
            if n.type in FRONTEND_ONLY:
                d["properties"] = {}
            else:
                props = {"Node name for S&R": n.type}
                cnr, ver = CUSTOM_NODE_PACKS.get(n.type, ("comfy-core", CORE_VER))
                props["cnr_id"] = cnr
                props["ver"] = ver
                if n.models:
                    props["models"] = n.models
                d["properties"] = props
            d["widgets_values"] = n.widget_values()
            if n.color:
                d["color"] = n.color
            if n.bgcolor:
                d["bgcolor"] = n.bgcolor
            nodes.append(d)
        links = []
        for lid in sorted(self.links):
            s, ss, dst, dn = self.links[lid]
            links.append([lid, s, ss, dst, self.input_slot(dst, dn), self.link_type(lid)])
        groups = []
        for i, (title, b, color, _) in enumerate(self.groups, 1):
            groups.append({"id": i, "title": title, "bounding": b, "color": color, "font_size": 24, "flags": {}})
        return {
            "id": str(uuid.uuid5(uuid.NAMESPACE_URL, "comfyui-anime-oc/" + self.filename)),
            "revision": 0,
            "last_node_id": max(self.nodes),
            "last_link_id": max(self.links) if self.links else 0,
            "nodes": nodes,
            "links": links,
            "groups": groups,
            "config": {},
            "extra": {"ds": self.ds, "workflow_title_ko": self.title},
            "version": 0.4,
        }

    # -- API format -----------------------------------------------------------------------
    def resolve(self, nid, slot):
        """Follow bypassed / muted nodes the same way the ComfyUI frontend does."""
        n = self.nodes[nid]
        if n.mode == 0:
            return [str(nid), slot]
        if n.mode == 2:
            return None
        otype = n.outputs()[slot][1]
        ins = n.ui_inputs()
        if slot < len(ins) and ins[slot]["type"] == otype:
            idx = slot
        else:
            idx = next((i for i, x in enumerate(ins) if x["type"] == otype), None)
        if idx is None:
            return None
        lid = self.incoming(nid, ins[idx]["name"])
        if lid is None:
            return None
        s, ss, _, _ = self.links[lid]
        return self.resolve(s, ss)

    def to_api(self, resolve_dynamic_prompts=True):
        self.check()
        order = self.exec_order()
        prompt = {}
        for nid in sorted(self.nodes, key=lambda x: order[x]):
            n = self.nodes[nid]
            if n.type in FRONTEND_ONLY or n.mode != 0:
                continue
            inputs = {}
            for inp in n.schema["inputs"]:
                name = inp["name"]
                lid = self.incoming(nid, name)
                if lid is not None:
                    s, ss, _, _ = self.links[lid]
                    src = self.resolve(s, ss)
                    if src is not None:
                        inputs[name] = src
                elif inp["kind"] == "widget":
                    v = n.api_widget(name)
                    if resolve_dynamic_prompts and n.type == "CLIPTextEncode" and name == "text":
                        v = first_choice(v)
                    inputs[name] = v
            prompt[str(nid)] = {"inputs": inputs, "class_type": n.type,
                                "_meta": {"title": n.title or n.schema["display"]}}
        return prompt


def first_choice(text):
    """The UI resolves {a|b|c} randomly at queue time; the API file pins the first option."""
    pat = re.compile(r"\{([^{}]*)\}")
    while pat.search(text):
        text = pat.sub(lambda m: m.group(1).split("|")[0], text)
    return text



# =============================================================================================
# Shared building blocks
# =============================================================================================
POS_COLOR = {"color": "#232", "bgcolor": "#353"}
NEG_COLOR = {"color": "#322", "bgcolor": "#533"}
SEED = 20261003

G_BLUE, G_PURPLE, G_GREEN, G_ORANGE, G_BROWN = "#3f789e", "#a1309b", "#3f8f3f", "#b06634", "#8a6d2f"

NEG_DEFAULT = ("worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, "
               "multiple views, watermark, signature, english text, feet out of frame")


def add_loaders(g, unet_key, unet_title, x=20, y=80):
    """Load Diffusion Model / CLIP / VAE (ids 1, 2, 3) in the left column."""
    g.add(1, "UNETLoader", [x, y], [340, 86], title=unet_title,
          widgets={"unet_name": MODELS[unet_key][0], "weight_dtype": "default"}, models=[model(unet_key)])
    g.add(2, "CLIPLoader", [x, y + 146], [340, 114], title="Load CLIP (Qwen3 0.6B)",
          widgets={"clip_name": MODELS["te"][0], "type": "stable_diffusion", "device": "default"}, models=[model("te")])
    g.add(3, "VAELoader", [x, y + 320], [340, 62], title="Load VAE (Qwen-Image)",
          widgets={"vae_name": MODELS["vae"][0]}, models=[model("vae")])


def ksampler(seed_mode, steps, cfg, sampler, scheduler, denoise):
    return {"seed": SEED, "control_after_generate": seed_mode, "steps": steps, "cfg": cfg,
            "sampler_name": sampler, "scheduler": scheduler, "denoise": denoise}


# =============================================================================================
# 01. OC 외형 디자인 - Aesthetic v1.1 + 하이레즈 2패스
# =============================================================================================
WF01_POS = ("masterpiece, best quality, highres, safe, newest, 1girl, solo, full body, standing, straight-on, "
            "looking at viewer, arms at sides, light smile, closed mouth, long hair, white hair, colored inner hair, "
            "blue hair, half updo, black ribbon, hair between eyes, sidelocks, blue eyes, tsurime, pale skin, "
            "petite, mole under eye, white shirt, collared shirt, blue necktie, black jacket, cropped jacket, long sleeves, "
            "black skirt, pleated skirt, black thighhighs, zettai ryouiki, brown shoes, loafers, black choker, "
            "x hair ornament, white background, simple background, anime coloring. Full-body character design of an "
            "original anime girl standing upright and facing the viewer on a plain white background, her whole figure "
            "visible from the top of her head to her shoes. Her long white hair has light blue inner coloring and is "
            "tied in a half updo with a small black ribbon.")
WF01_NEG = NEG_DEFAULT

WF01_NOTE_GUIDE = """
## 01. OC 외형 디자인 (Anima Aesthetic v1.1 + 하이레즈 2패스)
코어 노드만 사용합니다. 커스텀 노드 설치가 필요 없습니다.

### 필요한 파일 (ComfyUI/models/ 아래)
- diffusion_models/**anima-aesthetic-v1.1.safetensors** (4.18GB)
- text_encoders/**qwen_3_06b_base.safetensors**
- vae/**qwen_image_vae.safetensors**
- loras/**anima-rl-v0.1.safetensors** (기본 ON)
- upscale_models/**RealESRGAN_x4plus_anime_6B.pth**

다운로드: https://huggingface.co/circlestone-labs/Anima (모델, TE, VAE) / https://huggingface.co/circlestone-labs/Anima-Official-LoRAs (LoRA) / https://github.com/xinntao/Real-ESRGAN/releases/tag/v0.2.2.4 (업스케일러)
- 워크플로를 열 때 뜨는 오류 알림("자세히 보기" → 누락된 모델)에서 다른 파일은 Download 버튼으로 받을 수 있지만, **업스케일러 RealESRGAN_x4plus_anime_6B.pth는 GitHub 배포라 버튼이 없고 "Download all"로도 받아지지 않습니다.** 위 링크나 download_models 스크립트로 받아 upscale_models 폴더에 넣으세요.

### 여기만 고치세요
1. **[3] Positive(초록)**: 캐릭터 외형 태그만 교체. 순서 = 머리 길이 → 머리색 → 헤어스타일/장식 → 앞머리 → 눈 → 피부/얼굴 → 상의 → 하의 → 다리 → 신발 → 액세서리. 옷마다 색을 붙이면(예: black jacket) 디자인이 안정됩니다. 끝의 영어 문장 1~2개는 태그로 표현하기 어려운 부분(이너컬러 위치 등)을 설명합니다.
2. **그림체**: `1girl, solo,` 뒤에 `@작가명` 하나만 추가 (예: `@fkey`). 2명 이상 섞으면 화풍이 흐려집니다. 너무 세면 `(@작가명:0.6)`.
3. **[4] 해상도**: 전신 832x1216 / 반신 896x1152 / 바스트업 1024x1024. 32의 배수를 권장합니다.
4. **seed 고정**: 화면의 seed 값은 실행하자마자 **다음 실행용 값으로 이미 바뀌어** 있습니다. 마음에 드는 그림이 나오면 그 PNG(output/AnimaOC/01_base 또는 01_hires)를 ComfyUI 빈 화면에 끌어다 놓아 당시 seed가 든 워크플로를 복원한 뒤, control_after_generate(한국어 화면: 생성 후 제어)를 `fixed`(고정)로 바꾸세요. 그다음 프롬프트를 한 번에 한 가지씩만 고칩니다.

### 프롬프트 규칙 (Anima 전용)
- 영어만 사용. 태그는 소문자 + 띄어쓰기 (밑줄 금지). score_7 같은 score 태그만 밑줄 유지.
- **Aesthetic 모델에는 score 태그를 쓰지 마세요** (Positive/Negative 모두).
- 가중치는 SDXL보다 세게 (공식 예시 `(chibi:2)`): `(twintails:1.5)` ~ `(chibi:2)`. 1.1~1.2는 효과가 약하다는 경험담이 많습니다(공식 기준은 아님).
- `{a|b}`는 ComfyUI에서 **랜덤 선택** 문법입니다 (NovelAI 강조 아님). BREAK도 동작하지 않습니다.

### 단축키
- LoRA 켜기/끄기: 노드 클릭 → **Ctrl+B** (우회/Bypass, 보라색 = 꺼짐).
- 하이레즈 끄기: [5] 그룹 안 노드를 Ctrl+드래그로 모두 선택 → **Ctrl+M** (음소거/Mute, 다시 누르면 복구). 1차 결과는 `AnimaOC/01_base`로 저장됩니다.
- 실행: Run(실행) 버튼 또는 Ctrl+Enter.
"""

WF01_NOTE_LORA = """
### [2] LoRA 체인 (위에서 아래로 적용)
| 슬롯 | 파일 | 기본 | 권장 가중치 |
|---|---|---|---|
| 1 | anima-rl-v0.1 (공식) | **ON** | 0.5 (0.3~1.0) 디테일·미감 |
| 2 | anima-highres-aesthetic-boost (공식) | OFF | 0.5~1.0, 1536px 이상일 때 |
| 3 | anima-base-1-masterpiece-v51 (Civitai, 토큰 필요) | OFF | 0.6, 켜면 Positive 맨 앞에 `masterpiece, very aesthetic` |

- 슬롯 3은 LoraLoader(모델+CLIP)라서 나중에 직접 학습한 **내 OC LoRA**나 스타일 LoRA를 넣기 좋습니다 (lora_name 드롭다운에서 교체).
- 같이 켜는 LoRA는 3개 이하 권장. 많이 쌓으면 손·팔이 깨지기 쉽습니다.
- Illustrious/SDXL/Pony용 LoRA는 동작하지 않습니다. Civitai에서 Base Model이 **Anima**인 것만 쓰세요.
- 효과 비교: 같은 seed(fixed)로 슬롯 1을 Ctrl+B로 껐다 켜며 확인하세요.
"""

WF01_NOTE_HIRES = """
### [5] 2차 패스 (하이레즈)
1차 이미지를 RealESRGAN(4배)로 키운 뒤 약 **2.25MP**(1536x1536 면적, 16의 배수)로 줄이고 denoise 0.40으로 다시 그립니다. 832x1216 → 1264x1856.
- denoise: 0.35(원본 유지) ~ 0.45(디테일 추가). 0.5 이상이면 얼굴·옷 디자인이 바뀔 수 있습니다.
- 한 번에 약 1.5배 넘게 키우지 않는 것을 권장합니다 (커뮤니티 경험칙: 2배 이상을 한 번에 다시 그리면 불안정해지기 쉬움).
- **Rebatch Images 노드는 지우지 마세요.** Anima(Qwen-Image) VAE는 여러 장을 한 번에 인코딩하면 1장으로 합쳐 버립니다. 이 노드가 batch_size가 2 이상일 때도 1장씩 나눠 줍니다.
- 8GB 이하에서 디코딩 OOM이 나면 마지막 VAE Decode를 VAE Decode (Tiled)로 교체하세요.
"""


def add_hires_pass(g, model_link_src, pos_src, neg_src, vae_src, decode_src, denoise, save_prefix,
                   save_size, ids, link_ids):
    """Shared [5] hires block (01/03): upscale x4 -> ~2.25MP -> rebatch -> encode -> KSampler -> save."""
    n13, n14, n15, n16, n17, n18, n19, n20 = ids
    x1, x2 = 1780, 2150
    g.add(n13, "UpscaleModelLoader", [x1, 80], [340, 62], title="Load Upscale Model",
          widgets={"model_name": MODELS["esrgan"][0]}, models=[model("esrgan")])
    g.add(n14, "ImageUpscaleWithModel", [x1, 202], [260, 54], title="Upscale x4 (model)")
    g.add(n15, "ImageScaleToTotalPixels", [x1, 316], [340, 114], title="Scale to ~2.25MP (16의 배수)",
          widgets={"upscale_method": "lanczos", "megapixels": 2.25, "resolution_steps": 16})
    g.add(n16, "RebatchImages", [x1, 490], [260, 62], title="Rebatch Images (지우지 마세요)",
          widgets={"batch_size": 1})
    g.add(n17, "VAEEncode", [x1, 612], [225, 54], title="VAE Encode")
    g.add(n18, "KSampler", [x2, 80], [360, 262], title="KSampler 2차 (denoise %.2f)" % denoise,
          widgets=ksampler("fixed", 20, 3.5, "er_sde", "simple", denoise))
    g.add(n19, "VAEDecode", [x2, 402], [225, 54], title="VAE Decode 2차")
    g.add(n20, "SaveImage", [x2, 516], save_size, title="Save 하이레즈 (%s)" % save_prefix,
          widgets={"filename_prefix": save_prefix})
    l_up, l_img, l_scaled, l_rebatched, l_vae_enc, l_model, l_pos, l_neg, l_latent, l_samples, l_vae_dec, l_out = link_ids
    g.link(l_up, n13, 0, n14, "upscale_model")
    g.link(l_img, decode_src, 0, n14, "image")
    g.link(l_scaled, n14, 0, n15, "image")
    g.link(l_rebatched, n15, 0, n16, "images")
    g.link(l_vae_enc[0], n16, 0, n17, "pixels")
    g.link(l_vae_enc[1], vae_src, 0, n17, "vae")
    g.link(l_model, model_link_src[0], model_link_src[1], n18, "model")
    g.link(l_pos, pos_src, 0, n18, "positive")
    g.link(l_neg, neg_src, 0, n18, "negative")
    g.link(l_latent, n17, 0, n18, "latent_image")
    g.link(l_samples, n18, 0, n19, "samples")
    g.link(l_vae_dec, vae_src, 0, n19, "vae")
    g.link(l_out, n19, 0, n20, "images")


def wf01():
    g = Graph("01_oc_design_anima_aesthetic", "01. OC 외형 디자인 - Aesthetic v1.1 + 하이레즈 2패스")
    add_loaders(g, "aesthetic", "Load Diffusion Model (Aesthetic v1.1)")
    g.add(4, "LoraLoaderModelOnly", [420, 80], [340, 90], title="LoRA 1: anima-rl (공식, ON)",
          widgets={"lora_name": MODELS["rl"][0], "strength_model": 0.5}, models=[model("rl")])
    g.add(5, "LoraLoaderModelOnly", [420, 230], [340, 90], title="LoRA 2: highres boost (1536px 이상일 때만)", mode=4,
          widgets={"lora_name": MODELS["highres"][0], "strength_model": 0.5}, models=[model("highres")])
    g.add(6, "LoraLoader", [420, 380], [340, 138], title="LoRA 3: 품질/스타일/내 OC LoRA (Civitai)", mode=4,
          widgets={"lora_name": CIVITAI_LORAS["masterpiece"], "strength_model": 0.6, "strength_clip": 0.6})
    g.add(7, "CLIPTextEncode", [820, 80], [480, 420], title="Positive (외형 프롬프트)", widgets={"text": WF01_POS}, **POS_COLOR)
    g.add(8, "CLIPTextEncode", [820, 560], [480, 220], title="Negative", widgets={"text": WF01_NEG}, **NEG_COLOR)
    g.add(9, "EmptyLatentImage", [1360, 80], [360, 118], title="Empty Latent (832x1216 전신)",
          widgets={"width": 832, "height": 1216, "batch_size": 1})
    g.add(10, "KSampler", [1360, 260], [360, 262], title="KSampler 1차 (30 steps, CFG 3.5)",
          widgets=ksampler("randomize", 30, 3.5, "er_sde", "simple", 1.0))
    g.add(11, "VAEDecode", [1360, 582], [225, 54], title="VAE Decode 1차")
    g.add(12, "SaveImage", [1360, 700], [360, 420], title="Save 1차 (AnimaOC/01_base)",
          widgets={"filename_prefix": "AnimaOC/01_base"})
    g.note(21, "사용 안내", [-560, 50], [520, 970], WF01_NOTE_GUIDE)
    g.note(22, "LoRA 안내", [400, 590], [380, 480], WF01_NOTE_LORA)
    g.note(23, "하이레즈 안내", [1780, 726], [340, 420], WF01_NOTE_HIRES)

    g.link(1, 1, 0, 4, "model")
    g.link(2, 4, 0, 5, "model")
    g.link(3, 5, 0, 6, "model")
    g.link(4, 2, 0, 6, "clip")
    g.link(5, 6, 0, 10, "model")
    g.link(7, 6, 1, 7, "clip")
    g.link(8, 6, 1, 8, "clip")
    g.link(9, 7, 0, 10, "positive")
    g.link(10, 8, 0, 10, "negative")
    g.link(11, 9, 0, 10, "latent_image")
    g.link(12, 10, 0, 11, "samples")
    g.link(13, 3, 0, 11, "vae")
    g.link(14, 11, 0, 12, "images")
    add_hires_pass(g, model_link_src=(6, 0), pos_src=7, neg_src=8, vae_src=3, decode_src=11, denoise=0.40,
                   save_prefix="AnimaOC/01_hires", save_size=[400, 560],
                   ids=(13, 14, 15, 16, 17, 18, 19, 20),
                   link_ids=(15, 16, 17, 18, (19, 20), 6, 21, 22, 23, 24, 25, 26))

    g.group("1. 모델 로드", [0, 0, 380, 540], G_BLUE, [1, 2, 3])
    g.group("2. LoRA 체인 (Ctrl+B = 켜기/끄기)", [400, 0, 380, 540], G_PURPLE, [4, 5, 6])
    g.group("3. 프롬프트 (여기를 수정)", [800, 0, 520, 800], G_GREEN, [7, 8])
    g.group("4. 1차 생성 (832x1216)", [1340, 0, 400, 1160], G_ORANGE, [9, 10, 11, 12])
    g.group("5. 하이레즈 2차 패스 (끄려면 그룹 노드 전체 선택 후 Ctrl+M)", [1760, 0, 810, 1160], G_BROWN,
            [13, 14, 15, 16, 17, 18, 19, 20, 23])
    return g


# =============================================================================================
# 02. 빠른 시안 - Anima Turbo v1.1 (8스텝)
# =============================================================================================
WF02_POS = ("masterpiece, best quality, safe, 1girl, solo, full body, standing, straight-on, looking at viewer, "
            "{long hair|medium hair|short hair}, {white hair|pink hair|black hair|blonde hair|blue hair}, "
            "{half updo|twintails|ponytail|hime cut}, {blue eyes|red eyes|purple eyes|yellow eyes}, "
            "{school uniform|hoodie|dress|serafuku}, white background, simple background, anime coloring. "
            "Full-body character design of an original anime girl standing on a plain white background.")
WF02_NEG = NEG_DEFAULT

WF02_NOTE_GUIDE = """
## 02. 빠른 시안 (Anima Turbo v1.1, 8스텝)
코어 노드만 사용합니다. 필요한 파일: diffusion_models/**anima-turbo-v1.1.safetensors** + 01과 같은 TE/VAE.

### 사용법
- Positive의 `{long hair|medium hair|short hair}`처럼 중괄호로 묶은 부분은 **실행할 때마다 하나씩 랜덤으로 선택**됩니다. Run(실행)을 여러 번 눌러 외형 조합을 탐색하세요. 고정하려면 중괄호를 지우고 하나만 남기세요.
- 어떤 조합이 뽑혔는지는 **결과 그림을 보고 판단하는 것이 가장 쉽습니다.** 정확한 문구가 필요하면 PNG를 메모장으로 열어 "prompt" 부분에서 CLIPTextEncode의 "text" 값을 찾으세요. (PNG를 화면에 다시 끌어다 놓으면 뽑힌 문구가 아니라 중괄호 템플릿이 그대로 복원됩니다.)
- 마음에 드는 조합은 01 워크플로(Aesthetic)의 Positive로 옮겨 최종본을 만드세요. 모델이 달라서 같은 seed여도 그림은 달라집니다.

### 설정 (가급적 그대로 두세요)
- steps 8 (8~12), **CFG 1**, sampler euler, scheduler simple. er_sde는 지저분해질 수 있습니다. CFG를 올리면 그림이 타기 쉽습니다 (올려도 1.5~2까지).
- **CFG 1에서는 Negative가 무시됩니다** (ComfyUI가 계산을 건너뜀). 빼고 싶은 요소는 Positive에서 지우거나 다르게 표현하세요.
- 결과가 뭉개지거나 AI 느낌이 강하면 `masterpiece, best quality`를 빼고 `anime coloring`은 유지하세요.
- Turbo 체크포인트에는 Turbo LoRA를 **추가로 걸지 마세요** (이미 증류된 모델).
- batch_size 2 (VRAM 12GB 이상이면 4).
- 스타일 LoRA 슬롯(BlueArchiveStyleB1, Civitai 토큰 필요)은 기본 OFF입니다. Ctrl+B(우회 해제)로 켜세요.
"""


def wf02():
    g = Graph("02_fast_draft_anima_turbo", "02. 빠른 시안 - Anima Turbo v1.1 (8스텝)")
    add_loaders(g, "turbo", "Load Diffusion Model (Turbo v1.1)")
    g.add(4, "LoraLoader", [420, 80], [340, 138], title="스타일/OC LoRA (기본 OFF, Civitai)", mode=4,
          widgets={"lora_name": CIVITAI_LORAS["bluearchive"], "strength_model": 0.8, "strength_clip": 0.8})
    g.add(5, "CLIPTextEncode", [820, 80], [480, 420], title="Positive ({a|b} = 랜덤 선택)", widgets={"text": WF02_POS}, **POS_COLOR)
    g.add(6, "CLIPTextEncode", [820, 560], [480, 220], title="Negative (CFG 1에서는 무시됨)", widgets={"text": WF02_NEG}, **NEG_COLOR)
    g.add(7, "EmptyLatentImage", [1360, 80], [360, 118], title="Empty Latent (832x1216, batch 2)",
          widgets={"width": 832, "height": 1216, "batch_size": 2})
    g.add(8, "KSampler", [1360, 260], [360, 262], title="KSampler Turbo (8 steps, CFG 1, euler)",
          widgets=ksampler("randomize", 8, 1.0, "euler", "simple", 1.0))
    g.add(9, "VAEDecode", [1360, 582], [225, 54])
    g.add(10, "SaveImage", [1760, 80], [420, 640], title="Save (AnimaOC/02_draft)",
          widgets={"filename_prefix": "AnimaOC/02_draft"})
    g.note(11, "사용 안내", [-560, 50], [520, 800], WF02_NOTE_GUIDE)

    g.link(1, 1, 0, 4, "model")
    g.link(2, 2, 0, 4, "clip")
    g.link(3, 4, 0, 8, "model")
    g.link(4, 4, 1, 5, "clip")
    g.link(5, 4, 1, 6, "clip")
    g.link(6, 5, 0, 8, "positive")
    g.link(7, 6, 0, 8, "negative")
    g.link(8, 7, 0, 8, "latent_image")
    g.link(9, 8, 0, 9, "samples")
    g.link(10, 3, 0, 9, "vae")
    g.link(11, 9, 0, 10, "images")

    g.group("1. 모델 로드 (Turbo)", [0, 0, 380, 540], G_BLUE, [1, 2, 3])
    g.group("2. 스타일 LoRA (Ctrl+B)", [400, 0, 380, 240], G_PURPLE, [4])
    g.group("3. 프롬프트 (여기를 수정)", [800, 0, 520, 800], G_GREEN, [5, 6])
    g.group("4. 생성 + 저장", [1340, 0, 860, 760], G_ORANGE, [7, 8, 9, 10])
    return g


# =============================================================================================
# 03. 캐릭터 레퍼런스 시트 - 정면/옆/뒤 3면도
# =============================================================================================
WF03_POS = ("masterpiece, best quality, highres, safe, newest, 1girl, reference sheet, character sheet, turnaround, "
            "multiple views, full body, standing, straight-on, from side, from behind, arms at sides, long hair, "
            "white hair, colored inner hair, blue hair, half updo, black ribbon, hair between eyes, sidelocks, "
            "blue eyes, tsurime, pale skin, petite, mole under eye, white shirt, collared shirt, blue necktie, "
            "black jacket, cropped jacket, long sleeves, black skirt, pleated skirt, black thighhighs, zettai ryouiki, "
            "brown shoes, loafers, black choker, x hair ornament, white background, simple background. "
            "A character turnaround sheet of one original anime girl drawn three times side by side on a plain white "
            "background: front view on the left, side view in the middle, back view on the right. She keeps the same "
            "neutral standing pose, the same hairstyle and exactly the same outfit in every view. Her long white hair "
            "has light blue inner coloring and is tied in a half updo with a small black ribbon.")
WF03_NEG = ("worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, watermark, "
            "signature, english text, 2girls, multiple girls")

WF03_NOTE_GUIDE = """
## 03. 캐릭터 레퍼런스 시트 (정면 / 옆 / 뒤 3면도)
코어 노드만 사용합니다. 모델, LoRA, 업스케일러는 01과 같습니다 (업스케일러는 '누락된 모델' 창에서 받을 수 없으니 01 안내처럼 직접 받으세요).

### 사용법
1. 01에서 확정한 **외형 태그 블록과 색 설명 문장**을 Positive의 같은 위치에 그대로 붙여넣으세요 (시트 관련 태그와 앞쪽 설명 문장은 유지).
2. 1536x1024 가로 캔버스에 같은 캐릭터를 3번 그립니다. 3면도는 seed 운이 크므로 먼저 [5] 그룹을 Ctrl+M으로 끄고 여러 장 뽑으세요.
3. 마음에 드는 1차 결과 PNG(output/AnimaOC/03_sheet_base)를 **빈 화면에 끌어다 놓아** 그때의 seed가 든 워크플로를 복원하고, control_after_generate(생성 후 제어)를 `fixed`(고정)로 바꾼 뒤 [5] 그룹을 Ctrl+M으로 다시 켜고 실행하세요. 화면에 보이는 seed는 실행 직후 이미 다음 값으로 바뀌어 있으므로, 복원하지 않고 그대로 fixed로 바꾸면 다른 그림이 나옵니다.
4. 레이아웃이 자주 무너지면 **LoRA 2: Character Sheet for Anima**(Civitai, 토큰 필요)를 Ctrl+B로 켜고 0.6~0.8로 쓰세요.

### 01과 다른 점 (중요)
- 시트에는 **`solo`를 쓰지 않습니다** (Danbooru 규칙상 여러 시점 그림은 solo가 아님).
- Negative에 **`multiple views`를 넣지 마세요** (01에서는 넣음). 대신 `2girls, multiple girls`로 다른 인물이 섞이는 것을 막습니다.
- 2차 패스 denoise를 0.35로 낮춰 세 시점의 디자인이 서로 달라지지 않게 했습니다.

### 표정 시트로 바꾸려면
Positive를 프롬프트 템플릿의 표정 시트로 교체하고 해상도를 1216x832(3x2) 또는 1024x1024로 바꾸세요.
- 시트의 각 시점을 잘라 모아 두면 나중에 OC LoRA 학습 데이터(20~40장)로 쓸 수 있습니다.
"""


def wf03():
    g = Graph("03_character_sheet_anima", "03. 캐릭터 레퍼런스 시트 - 정면/옆/뒤 3면도")
    add_loaders(g, "aesthetic", "Load Diffusion Model (Aesthetic v1.1)")
    g.add(4, "LoraLoaderModelOnly", [420, 80], [356, 90], title="LoRA 1: anima-rl (공식, ON)",
          widgets={"lora_name": MODELS["rl"][0], "strength_model": 0.5}, models=[model("rl")])
    g.add(5, "LoraLoaderModelOnly", [420, 230], [356, 90], title="LoRA 2: Character Sheet (Civitai, 레이아웃 보조)", mode=4,
          widgets={"lora_name": CIVITAI_LORAS["sheet"], "strength_model": 0.7})
    g.add(7, "CLIPTextEncode", [820, 80], [480, 420], title="Positive (시트 프롬프트)", widgets={"text": WF03_POS}, **POS_COLOR)
    g.add(8, "CLIPTextEncode", [820, 560], [480, 220], title="Negative (multiple views 넣지 말 것)", widgets={"text": WF03_NEG}, **NEG_COLOR)
    g.add(9, "EmptyLatentImage", [1360, 80], [360, 118], title="Empty Latent (1536x1024 시트)",
          widgets={"width": 1536, "height": 1024, "batch_size": 1})
    g.add(10, "KSampler", [1360, 260], [360, 262], title="KSampler 1차 (30 steps, CFG 3.5)",
          widgets=ksampler("randomize", 30, 3.5, "er_sde", "simple", 1.0))
    g.add(11, "VAEDecode", [1360, 582], [225, 54], title="VAE Decode 1차")
    g.add(12, "SaveImage", [1360, 700], [360, 420], title="Save 1차 (AnimaOC/03_sheet_base)",
          widgets={"filename_prefix": "AnimaOC/03_sheet_base"})
    g.note(21, "사용 안내", [-560, 50], [520, 970], WF03_NOTE_GUIDE)

    g.link(1, 1, 0, 4, "model")
    g.link(2, 4, 0, 5, "model")
    g.link(3, 5, 0, 10, "model")
    g.link(5, 2, 0, 7, "clip")
    g.link(6, 2, 0, 8, "clip")
    g.link(7, 7, 0, 10, "positive")
    g.link(8, 8, 0, 10, "negative")
    g.link(9, 9, 0, 10, "latent_image")
    g.link(10, 10, 0, 11, "samples")
    g.link(11, 3, 0, 11, "vae")
    g.link(12, 11, 0, 12, "images")
    add_hires_pass(g, model_link_src=(5, 0), pos_src=7, neg_src=8, vae_src=3, decode_src=11, denoise=0.35,
                   save_prefix="AnimaOC/03_sheet_hires", save_size=[560, 400],
                   ids=(13, 14, 15, 16, 17, 18, 19, 20),
                   link_ids=(13, 14, 15, 16, (17, 18), 4, 19, 20, 21, 22, 23, 24))

    g.group("1. 모델 로드", [0, 0, 380, 540], G_BLUE, [1, 2, 3])
    g.group("2. LoRA (Ctrl+B = 켜기/끄기)", [400, 0, 380, 360], G_PURPLE, [4, 5])
    g.group("3. 시트 프롬프트 (외형 블록을 01에서 복사)", [800, 0, 520, 800], G_GREEN, [7, 8])
    g.group("4. 1차 생성 (1536x1024)", [1340, 0, 400, 1160], G_ORANGE, [9, 10, 11, 12])
    g.group("5. 하이레즈 2차 패스 (끄려면 그룹 노드 전체 선택 후 Ctrl+M)", [1760, 0, 970, 960], G_BROWN,
            [13, 14, 15, 16, 17, 18, 19, 20])
    return g


# =============================================================================================
# 04. 얼굴·손 디테일 + 최종 2배 업스케일 (Impact Pack)
# =============================================================================================
WF04_POS = ("masterpiece, best quality, highres, safe, 1girl, solo, portrait, looking at viewer, light smile, "
            "closed mouth, white hair, colored inner hair, blue hair, hair between eyes, sidelocks, blue eyes, "
            "tsurime, pale skin, mole under eye, black choker, x hair ornament, anime coloring")
WF04_NEG = "worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, watermark, signature"
WF04_HAND_POS = "masterpiece, best quality, safe, A clean, well-drawn anime hand with five fingers and natural joints."

WF04_NOTE_GUIDE = """
## 04. 얼굴·손 디테일 + 최종 업스케일 (커스텀 노드 필요)
### 설치
1. ComfyUI-Manager에서 **ComfyUI Impact Pack**과 **ComfyUI Impact Subpack**을 설치하고 재시작하세요. Manager로 설치하면 models/ultralytics/bbox/에 face_yolov8m.pt, hand_yolov8s.pt가 자동으로 받아집니다.
2. **Windows 포터블은 Manager가 기본으로 꺼져 있습니다** (Manager 버튼이 안 보임). ComfyUI_windows_portable 폴더에서 PowerShell로 `.\python_embeded\python.exe -m pip install -r ComfyUI\manager_requirements.txt`를 실행하고, run_nvidia_gpu.bat의 main.py 줄 끝에 `--enable-manager`를 붙인 뒤 다시 실행하세요. Desktop에는 Manager가 기본으로 들어 있습니다.
3. Manager 없이 git clone으로 설치했다면 검출기가 자동으로 받아지지 않습니다. download_models 스크립트에 `-Only face_yolov8m,hand_yolov8s`(bash는 `--only`)를 붙여 받으세요.
- 업스케일러 RealESRGAN_x4plus_anime_6B.pth는 '누락된 모델' 창에 Download 버튼이 없으니 01 안내처럼 직접 받으세요.

### 사용법
1. **Load Image** 노드의 "choose file to upload"(한국어 화면: 업로드할 파일 선택) 버튼으로 01/03의 하이레즈 결과 PNG를 1장 고르세요. 끌어다 놓을 때는 Load Image 노드 위에 정확히 놓으세요. **빈 화면에 놓으면 그 PNG의 워크플로(01)가 열려 04가 사라집니다.**
2. 얼굴용 Positive 노드에는 **캐릭터 얼굴 태그**(머리색, 눈색, 표정, 액세서리)를 01과 똑같이 넣으세요. 다르면 얼굴이 다른 사람처럼 바뀝니다.
3. FaceDetailer denoise는 0.35~0.45 (기본 0.40). guide_size는 768을 권장합니다 (경험칙: 512px보다 작게 다시 그리면 얼굴이 뭉개지기 쉬움).
4. 손 디테일러(FaceDetailer - Hands)는 기본 OFF입니다. 손이 깨졌을 때만 Ctrl+B로 켜세요. 그래도 안 되면 seed를 바꿔 다시 생성하는 편이 빠릅니다.
5. 마지막 업스케일은 RealESRGAN 4배 → 0.5배 = **최종 2배** 순수 확대입니다 (다시 그리지 않음).

- 애니 얼굴을 잘 못 찾으면 Anzhc Face seg 모델을 models/ultralytics/segm/에 넣고 Face Detector를 segm/ 항목으로 바꾸세요.
- 오른쪽 Preview는 FaceDetailer가 다시 그린 얼굴 크롭입니다.
"""


def face_detailer(guide, denoise):
    return {"guide_size": guide, "guide_size_for": True, "max_size": 1024, "seed": SEED, "control_after_generate": "fixed",
            "steps": 20, "cfg": 3.5, "sampler_name": "er_sde", "scheduler": "simple", "denoise": denoise,
            "feather": 5, "noise_mask": True, "force_inpaint": True, "bbox_threshold": 0.5, "bbox_dilation": 10,
            "bbox_crop_factor": 3.0, "sam_detection_hint": "center-1", "sam_dilation": 0, "sam_threshold": 0.93,
            "sam_bbox_expansion": 0, "sam_mask_hint_threshold": 0.7, "sam_mask_hint_use_negative": "False",
            "drop_size": 10, "wildcard": "", "cycle": 1, "inpaint_model": False, "noise_mask_feather": 20,
            "tiled_encode": False, "tiled_decode": False}


def wf04():
    g = Graph("04_face_detail_upscale_impact", "04. 얼굴·손 디테일 + 최종 2배 업스케일 (Impact Pack)")
    add_loaders(g, "aesthetic", "Load Diffusion Model (Aesthetic v1.1)")
    g.add(4, "LoadImage", [20, 522], [340, 380], title="Load Image (01/03 결과 PNG)", widgets={"image": "example.png"})
    g.add(5, "CLIPTextEncode", [420, 80], [480, 300], title="Positive (얼굴용: 캐릭터 얼굴 태그 유지)", widgets={"text": WF04_POS}, **POS_COLOR)
    g.add(6, "CLIPTextEncode", [420, 440], [480, 160], title="Negative", widgets={"text": WF04_NEG}, **NEG_COLOR)
    g.add(10, "CLIPTextEncode", [420, 660], [480, 200], title="Positive (손용)", widgets={"text": WF04_HAND_POS}, **POS_COLOR)
    g.add(7, "UltralyticsDetectorProvider", [960, 80], [380, 106], title="Face Detector",
          widgets={"model_name": "bbox/face_yolov8m.pt"})
    g.add(8, "FaceDetailer", [960, 250], [380, 1140], title="FaceDetailer - Face (denoise 0.40)",
          widgets=face_detailer(768, 0.4))
    g.add(9, "UltralyticsDetectorProvider", [1400, 80], [380, 106], title="Hand Detector",
          widgets={"model_name": "bbox/hand_yolov8s.pt"})
    g.add(11, "FaceDetailer", [1400, 250], [380, 1140], title="FaceDetailer - Hands (기본 OFF)", mode=4,
          widgets=face_detailer(512, 0.35))
    g.add(12, "UpscaleModelLoader", [1840, 80], [400, 62], title="Load Upscale Model",
          widgets={"model_name": MODELS["esrgan"][0]}, models=[model("esrgan")])
    g.add(13, "ImageUpscaleWithModel", [1840, 202], [260, 54], title="Upscale x4 (model)")
    g.add(14, "ImageScaleBy", [1840, 316], [320, 90], title="x0.5 (최종 2배)",
          widgets={"upscale_method": "lanczos", "scale_by": 0.5})
    g.add(15, "SaveImage", [1840, 466], [420, 640], title="Save (AnimaOC/04_detail_upscale)",
          widgets={"filename_prefix": "AnimaOC/04_detail_upscale"})
    g.add(16, "PreviewImage", [2320, 80], [400, 420], title="다시 그린 얼굴 크롭 확인")
    g.note(17, "사용 안내", [-560, 50], [520, 900], WF04_NOTE_GUIDE)

    g.link(1, 2, 0, 5, "clip")
    g.link(2, 2, 0, 6, "clip")
    g.link(3, 2, 0, 10, "clip")
    g.link(4, 4, 0, 8, "image")
    g.link(5, 1, 0, 8, "model")
    g.link(6, 2, 0, 8, "clip")
    g.link(7, 3, 0, 8, "vae")
    g.link(8, 5, 0, 8, "positive")
    g.link(9, 6, 0, 8, "negative")
    g.link(10, 7, 0, 8, "bbox_detector")
    g.link(11, 8, 0, 11, "image")
    g.link(12, 1, 0, 11, "model")
    g.link(13, 2, 0, 11, "clip")
    g.link(14, 3, 0, 11, "vae")
    g.link(15, 10, 0, 11, "positive")
    g.link(16, 6, 0, 11, "negative")
    g.link(17, 9, 0, 11, "bbox_detector")
    g.link(18, 12, 0, 13, "upscale_model")
    g.link(19, 11, 0, 13, "image")
    g.link(20, 13, 0, 14, "image")
    g.link(21, 14, 0, 15, "images")
    g.link(22, 8, 1, 16, "images")

    g.group("1. 모델 + 입력 이미지", [0, 0, 380, 920], G_BLUE, [1, 2, 3, 4])
    g.group("2. 프롬프트 (얼굴 / 손)", [400, 0, 520, 920], G_GREEN, [5, 6, 10])
    g.group("3. 얼굴 디테일러", [940, 0, 420, 1420], G_ORANGE, [7, 8])
    g.group("4. 손 디테일러 (기본 OFF, Ctrl+B)", [1380, 0, 420, 1420], G_PURPLE, [9, 11])
    g.group("5. 최종 2배 업스케일 + 저장 / 얼굴 크롭 확인", [1820, 0, 920, 1140], G_BROWN, [12, 13, 14, 15, 16])
    return g


# =============================================================================================
# 05. 스케치/선화 → OC 완성 일러스트 (Anima LLLite)
# =============================================================================================
WF05_POS = ("masterpiece, best quality, highres, safe, newest, 1girl, solo, full body, standing, looking at viewer, "
            "long hair, white hair, colored inner hair, blue hair, half updo, black ribbon, hair between eyes, "
            "sidelocks, blue eyes, tsurime, pale skin, petite, mole under eye, white shirt, collared shirt, blue necktie, "
            "black jacket, cropped jacket, long sleeves, black skirt, pleated skirt, black thighhighs, zettai ryouiki, "
            "brown shoes, loafers, black choker, x hair ornament, white background, simple background, anime coloring. "
            "A finished full-color anime illustration of an original girl that follows the pose and outline of the "
            "sketch. Her long white hair has light blue inner coloring and is tied in a half updo with a small black ribbon.")
WF05_NEG = ("worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, watermark, "
            "signature, english text, monochrome, greyscale, sketch")

WF05_NOTE_GUIDE = """
## 05. 스케치/선화 → OC 완성 일러스트 (Anima LLLite, 코어 노드)
필요한 파일: model_patches/**anima-lllite-any-test-like-v2.safetensors** (https://huggingface.co/Comfy-Org/Anima-LLLite). 스크립트로 받으려면 `-Only lllite_any_test_v2` (bash는 `--only`)를 붙이세요.

### 사용법
1. **Load Image** 노드의 "choose file to upload"(업로드할 파일 선택) 버튼으로 러프 스케치, 포즈 낙서, 선화를 고르세요. 끌어다 놓을 때는 Load Image 노드 위에 정확히 놓으세요 (ComfyUI가 만든 PNG를 빈 화면에 놓으면 그 PNG의 워크플로가 열립니다). 입력 비율에 맞춰 약 1MP(16의 배수) 해상도가 자동으로 정해집니다.
2. Canny(0.17/0.45) → Invert = 흰 바탕에 검은 선 컨트롤 이미지입니다 (공식 템플릿과 같음). **이미 깔끔한 흑백 선화(흰 바탕/검은 선)라면 Canny와 Invert Image를 Ctrl+B로 끄세요.**
3. Positive에는 01의 외형 블록을 넣으세요. 형태는 스케치가, 색과 디테일은 프롬프트가 결정합니다.
4. strength 1.0이 기본입니다. 선을 너무 그대로 따라가면 0.6~0.8로 낮추거나 end_percent를 0.5~0.7로 바꾸세요.

### 참고
- LLLite는 공식적으로 **Anima Base v1.0**으로 학습되었습니다. 여기서는 Aesthetic v1.1에 적용했으며, 결과가 이상하면 Load Diffusion Model을 anima-base-v1.0으로 바꾸세요 (그때는 Positive에 `score_7`, Negative에 `score_1, score_2, score_3` 추가, CFG 4~5).
- 빠르게 확인하려면 Turbo LoRA를 Ctrl+B로 켜고 KSampler를 steps 8, cfg 1로 바꾸세요.
- 포즈 전용 pose-1 모델은 공식 문서에서도 약하다고 명시되어 있어 넣지 않았습니다. 간단한 사람 실루엣이나 선화를 이 any-test 모델에 넣는 방식을 권장합니다.
"""


def wf05():
    g = Graph("05_sketch_to_oc_lllite", "05. 스케치/선화 → OC 완성 일러스트 (Anima LLLite, 선택)")
    add_loaders(g, "aesthetic", "Load Diffusion Model (Aesthetic v1.1)")
    g.add(4, "ModelPatchLoader", [20, 522], [340, 86], title="Load LLLite (any-test-like v2)",
          widgets={"name": MODELS["lllite"][0]}, models=[model("lllite")])
    g.add(5, "LoadImage", [420, 80], [340, 380], title="Load Image (스케치/선화/포즈 낙서)", widgets={"image": "example.png"})
    g.add(6, "ImageScaleToTotalPixels", [420, 520], [340, 114], title="Scale to ~1MP (16의 배수)",
          widgets={"upscale_method": "lanczos", "megapixels": 1.0, "resolution_steps": 16})
    g.add(7, "Canny", [790, 80], [340, 90], title="Canny (깔끔한 선화면 Ctrl+B로 끄기)",
          widgets={"low_threshold": 0.17, "high_threshold": 0.45})
    g.add(8, "ImageInvert", [790, 230], [240, 46], title="Invert Image (흰 바탕/검은 선)")
    g.add(9, "PreviewImage", [790, 336], [360, 470], title="컨트롤 이미지 확인")
    g.add(10, "AnimaLLLiteApply", [1200, 80], [340, 202], title="Apply Anima LLLite (strength 1.0)",
          widgets={"strength": 1.0, "start_percent": 0.0, "end_percent": 1.0})
    g.add(11, "LoraLoaderModelOnly", [1200, 342], [340, 90], title="Turbo LoRA (기본 OFF: 켜면 8 steps / CFG 1)", mode=4,
          widgets={"lora_name": MODELS["turbo_lora"][0], "strength_model": 1.0}, models=[model("turbo_lora")])
    g.add(12, "GetImageSize", [2140, 80], [225, 86])
    g.add(13, "EmptyLatentImage", [2140, 226], [300, 118], title="Empty Latent (컨트롤 이미지 크기)",
          widgets={"width": 1024, "height": 1024, "batch_size": 1}, widget_inputs=("width", "height"))
    g.add(14, "CLIPTextEncode", [1600, 80], [480, 420], title="Positive (01의 외형 블록)", widgets={"text": WF05_POS}, **POS_COLOR)
    g.add(15, "CLIPTextEncode", [1600, 560], [480, 220], title="Negative", widgets={"text": WF05_NEG}, **NEG_COLOR)
    g.add(16, "KSampler", [2140, 404], [360, 262], title="KSampler (30 steps, CFG 4, euler)",
          widgets=ksampler("randomize", 30, 4.0, "euler", "simple", 1.0))
    g.add(17, "VAEDecode", [2140, 726], [225, 54])
    g.add(18, "SaveImage", [2540, 80], [380, 620], title="Save (AnimaOC/05_lllite)",
          widgets={"filename_prefix": "AnimaOC/05_lllite"})
    g.note(19, "사용 안내", [-560, 50], [520, 900], WF05_NOTE_GUIDE)

    g.link(1, 5, 0, 6, "image")
    g.link(2, 6, 0, 7, "image")
    g.link(3, 7, 0, 8, "image")
    g.link(4, 8, 0, 9, "images")
    g.link(5, 1, 0, 10, "model")
    g.link(6, 4, 0, 10, "model_patch")
    g.link(7, 8, 0, 10, "image")
    g.link(8, 10, 0, 11, "model")
    g.link(9, 11, 0, 16, "model")
    g.link(10, 6, 0, 12, "image")
    g.link(11, 12, 0, 13, "width")
    g.link(12, 12, 1, 13, "height")
    g.link(13, 2, 0, 14, "clip")
    g.link(14, 2, 0, 15, "clip")
    g.link(15, 14, 0, 16, "positive")
    g.link(16, 15, 0, 16, "negative")
    g.link(17, 13, 0, 16, "latent_image")
    g.link(18, 16, 0, 17, "samples")
    g.link(19, 3, 0, 17, "vae")
    g.link(20, 17, 0, 18, "images")

    g.group("1. 모델 로드", [0, 0, 380, 640], G_BLUE, [1, 2, 3, 4])
    g.group("2. 컨트롤 이미지 (스케치/선화)", [400, 0, 760, 840], G_ORANGE, [5, 6, 7, 8, 9])
    g.group("3. LLLite 적용 + (선택) Turbo", [1180, 0, 380, 460], G_PURPLE, [10, 11])
    g.group("4. 프롬프트", [1580, 0, 520, 840], G_GREEN, [14, 15])
    g.group("5. 생성 + 저장", [2120, 0, 810, 820], G_BROWN, [12, 13, 16, 17, 18])
    return g


WORKFLOWS = [wf01, wf02, wf03, wf04, wf05]


def build_graphs():
    return [f() for f in WORKFLOWS]


# =============================================================================================
# Variants (used by the validation helper; not written by default)
# =============================================================================================
def variant(g, modes=None, widgets=None, suffix="variant"):
    """Copy of graph `g` with some node modes / widget values changed (e.g. all LoRAs enabled)."""
    v = copy.deepcopy(g)
    v.filename = "%s__%s" % (g.filename, suffix)
    for nid, mode in (modes or {}).items():
        v.nodes[nid].mode = mode
    for nid, w in (widgets or {}).items():
        v.nodes[nid].widgets.update(w)
    return v


def validation_variants():
    """Non-default states that should also validate (and run) on a real ComfyUI server."""
    g1, g2, g3, g4, g5 = build_graphs()
    return [
        variant(g1, modes={5: 0, 6: 0}, widgets={9: {"batch_size": 2}}, suffix="all_loras_batch2"),
        variant(g2, modes={4: 0}, suffix="style_lora_on"),
        variant(g3, modes={5: 0}, suffix="sheet_lora_on"),
        variant(g4, modes={11: 0}, suffix="hand_detailer_on"),
        variant(g5, modes={11: 0, 7: 4, 8: 4}, widgets={16: {"steps": 8, "cfg": 1.0}}, suffix="turbo_on_no_canny"),
    ]


# =============================================================================================
# object_info cross-check
# =============================================================================================
def load_object_info(src):
    if re.match(r"https?://", src):
        with urllib.request.urlopen(src, timeout=60) as r:
            return json.load(r)
    with open(src, encoding="utf-8") as f:
        return json.load(f)


def check_against_object_info(graphs, oi):
    problems = []
    for t, sch in SCHEMA.items():
        if t not in oi:
            problems.append("node type %s is not installed on the server" % t)
            continue
        d = oi[t]
        order = d.get("input_order") or {s: list(d["input"].get(s, {})) for s in ("required", "optional")}
        live = [(k, sec) for sec in ("required", "optional") for k in order.get(sec, [])]
        mine = [(i["name"], "optional" if i.get("optional") else "required") for i in sch["inputs"]]
        if live != mine:
            problems.append("%s: input order differs\n    live: %s\n    mine: %s" % (t, live, mine))
        if list(d["output"]) != [o[1] for o in sch["outputs"]]:
            problems.append("%s: outputs differ live=%s mine=%s" % (t, d["output"], [o[1] for o in sch["outputs"]]))
    for g in graphs:
        for n in g.nodes.values():
            if n.type in FRONTEND_ONLY or n.type not in oi:
                continue
            spec = {}
            for sec in ("required", "optional"):
                spec.update(oi[n.type]["input"].get(sec, {}))
            for name, value in n.widgets.items():
                if name == "control_after_generate":
                    continue
                s = spec.get(name)
                if s is None:
                    problems.append("%s node %s: widget %s unknown to server" % (g.filename, n.id, name))
                    continue
                opts = s[0] if isinstance(s[0], list) else (s[1].get("options") if s[0] == "COMBO" and len(s) > 1 else None)
                if opts is not None and value not in opts:
                    problems.append("%s node %s (%s): %s=%r not offered by server" % (g.filename, n.id, n.type, name, value))
    return problems


# =============================================================================================
# main
# =============================================================================================
def dump(obj, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write("\n")


def main(argv=None):
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--out", default=os.path.join(here, "..", "workflows"),
                    help="output directory for UI workflows (API files go to <out>/api)")
    ap.add_argument("--check-object-info", metavar="URL_OR_FILE",
                    help="verify schema + widget values against a ComfyUI /object_info (URL or saved JSON)")
    args = ap.parse_args(argv)

    graphs = build_graphs()
    if args.check_object_info:
        problems = check_against_object_info(graphs + validation_variants(), load_object_info(args.check_object_info))
        if problems:
            print("object_info check FAILED:\n  " + "\n  ".join(problems))
            return 1
        print("object_info check OK (%d node types, %d workflows)" % (len(SCHEMA), len(graphs)))
        return 0

    out = os.path.normpath(args.out)
    for g in graphs:
        ui = g.to_ui()
        api = g.to_api()
        dump(ui, os.path.join(out, g.filename + ".json"))
        dump(api, os.path.join(out, "api", g.filename + ".json"))
        print("%-34s UI: %2d nodes, %2d links, %d groups | API: %2d nodes" % (
            g.filename, len(ui["nodes"]), len(ui["links"]), len(ui["groups"]), len(api)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
