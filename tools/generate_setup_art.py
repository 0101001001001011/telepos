"""Генерация трёх иллюстраций мастера настройки через ComfyUI.

Запуск:  python tools/generate_setup_art.py --out build/setup-art
Сервер задаётся через --host, по умолчанию 192.168.1.205:8188.

Иллюстрации нужны ровно на трёх шагах из одиннадцати: приветствие (страна),
режим работы и «готово». На остальных их нет намеренно — в Telegram настройки
не иллюстрируют, и картинка на каждой форме подряд удешевляет, а не украшает.

Заглушек этот скрипт не делает. Если сервер не отвечает, работа
останавливается: разъехавшийся или случайный набор выглядит дешевле, чем
отсутствие картинок вовсе.
"""

import argparse
import json
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# Общий префикс — единственное, что удерживает три картинки в одном наборе.
STYLE = (
    "soft rounded 3d illustration, matte clay render, isolated on pure white "
    "background, single accent colour #3390EC light blue, muted grey secondary, "
    "gentle soft shadow, thin clean edges, no text, no letters, no people, "
    "no faces, centred composition, generous empty margin, product illustration"
)

SUBJECTS = {
    "welcome": "a small friendly storefront next to a globe with a map pin",
    "mode": "three small objects side by side: a shop awning, a restaurant "
            "table with a plate, a toolbox",
    "done": "a compact receipt printer with a paper receipt curling out and a "
            "check mark floating above it",
}

NEGATIVE = (
    "text, watermark, signature, cluttered, photo, realistic skin, harsh shadow"
)


def workflow(subject: str, seed: int, width: int, height: int) -> dict:
    return {
        "1": {
            "class_type": "UNETLoader",
            "inputs": {
                "unet_name": "flux1-dev-fp8.safetensors",
                "weight_dtype": "fp8_e4m3fn",
            },
        },
        "2": {
            "class_type": "DualCLIPLoader",
            "inputs": {
                "clip_name1": "t5xxl_fp16.safetensors",
                "clip_name2": "clip_l.safetensors",
                "type": "flux",
            },
        },
        "3": {
            "class_type": "VAELoader",
            "inputs": {"vae_name": "flux1-dev-ae.safetensors"},
        },
        "4": {
            "class_type": "CLIPTextEncode",
            "inputs": {"clip": ["2", 0], "text": f"{subject}, {STYLE}"},
        },
        "5": {
            "class_type": "CLIPTextEncode",
            "inputs": {"clip": ["2", 0], "text": NEGATIVE},
        },
        "6": {
            "class_type": "FluxGuidance",
            "inputs": {"conditioning": ["4", 0], "guidance": 3.5},
        },
        "7": {
            "class_type": "EmptySD3LatentImage",
            "inputs": {"width": width, "height": height, "batch_size": 1},
        },
        "8": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["1", 0],
                "positive": ["6", 0],
                "negative": ["5", 0],
                "latent_image": ["7", 0],
                "seed": seed,
                "steps": 24,
                # У flux-dev управление силой идёт через FluxGuidance,
                # поэтому cfg остаётся единицей.
                "cfg": 1.0,
                "sampler_name": "euler",
                "scheduler": "simple",
                "denoise": 1.0,
            },
        },
        "9": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["8", 0], "vae": ["3", 0]},
        },
        "10": {
            "class_type": "SaveImage",
            "inputs": {"images": ["9", 0], "filename_prefix": "telepos_setup"},
        },
    }


def check_server(host: str, timeout: int = 8) -> None:
    """Останавливает работу, если сервера нет.

    Проверка стоит до первой генерации намеренно: молча получить пустой каталог
    и положить в репозиторий что попало хуже, чем не сделать ничего.
    """
    try:
        with urllib.request.urlopen(
            f"http://{host}/system_stats", timeout=timeout
        ) as resp:
            stats = json.load(resp)
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise SystemExit(
            f"ComfyUI на {host} не отвечает ({e}).\n"
            "Задача останавливается. Заглушки в репозиторий не кладутся: "
            "случайный набор выглядит дешевле, чем отсутствие картинок."
        )
    version = stats.get("system", {}).get("comfyui_version", "?")
    print(f"ComfyUI {version} на {host}")


def submit(host: str, wf: dict) -> str:
    body = json.dumps({"prompt": wf}).encode()
    req = urllib.request.Request(
        f"http://{host}/prompt",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)["prompt_id"]


def wait(host: str, prompt_id: str, timeout: int = 600) -> list:
    deadline = time.time() + timeout
    while time.time() < deadline:
        with urllib.request.urlopen(
            f"http://{host}/history/{prompt_id}", timeout=30
        ) as resp:
            history = json.load(resp)
        if prompt_id in history:
            outputs = history[prompt_id]["outputs"]
            return outputs["10"]["images"]
        time.sleep(3)
    raise TimeoutError(f"ComfyUI не ответил за {timeout} с")


def fetch(host: str, image: dict) -> bytes:
    query = urllib.parse.urlencode(
        {
            "filename": image["filename"],
            "subfolder": image.get("subfolder", ""),
            "type": image.get("type", "output"),
        }
    )
    with urllib.request.urlopen(f"http://{host}/view?{query}", timeout=60) as r:
        return r.read()


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")

    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="192.168.1.205:8188")
    parser.add_argument("--out", default="build/setup-art")
    parser.add_argument("--variants", type=int, default=4)
    parser.add_argument("--width", type=int, default=1536)
    parser.add_argument("--height", type=int, default=1024)
    args = parser.parse_args()

    check_server(args.host)

    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    for name, subject in SUBJECTS.items():
        for variant in range(args.variants):
            # Сид выводится из имени и номера, а не случаен: неудачный
            # вариант потом можно воспроизвести точно.
            seed = abs(hash((name, variant))) % (2**31)
            wf = workflow(subject, seed, args.width, args.height)
            prompt_id = submit(args.host, wf)
            print(f"{name} #{variant} seed={seed} → {prompt_id}")
            for image in wait(args.host, prompt_id):
                data = fetch(args.host, image)
                path = out / f"{name}_{variant}_{seed}.png"
                path.write_bytes(data)
                print(f"  сохранено {path}")


if __name__ == "__main__":
    main()
