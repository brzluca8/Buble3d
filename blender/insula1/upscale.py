"""upscale an image x4 with a Real-ESRGAN ncnn model on the CPU, in overlapping tiles (no seams)"""
import sys, time
import numpy as np
import ncnn
from PIL import Image

src, dst, model = sys.argv[1], sys.argv[2], sys.argv[3]
box = [int(v) for v in sys.argv[4].split(",")] if len(sys.argv) > 4 and sys.argv[4] else None
TILE, PAD, SC = 192, 12, 4
net = ncnn.Net()
net.opt.use_vulkan_compute = False
net.opt.num_threads = 4
net.load_param(model + ".param")
net.load_model(model + ".bin")
im = np.array(Image.open(src).convert("RGB"))
if box:
    im = im[box[1]:box[3], box[0]:box[2]]
H, W = im.shape[:2]
pad = np.pad(im, ((PAD, PAD), (PAD, PAD), (0, 0)), mode="reflect")
out = np.zeros((H * SC, W * SC, 3), np.float32)
t0 = time.time()
n = 0
for y in range(0, H, TILE):
    for x in range(0, W, TILE):
        th, tw = min(TILE, H - y), min(TILE, W - x)
        tile = np.ascontiguousarray(pad[y:y + th + 2 * PAD, x:x + tw + 2 * PAD])
        m = ncnn.Mat.from_pixels(tile, ncnn.Mat.PixelType.PIXEL_RGB, tile.shape[1], tile.shape[0])
        m.substract_mean_normalize([0, 0, 0], [1 / 255.0] * 3)
        ex = net.create_extractor()
        ex.input("data", m)
        _, r = ex.extract("output")
        r = np.array(r).transpose(1, 2, 0)
        out[y * SC:(y + th) * SC, x * SC:(x + tw) * SC] = r[PAD * SC:(PAD + th) * SC, PAD * SC:(PAD + tw) * SC]
        n += 1
    print(f"row {y // TILE + 1}/{(H + TILE - 1) // TILE}  {time.time() - t0:.0f}s", flush=True)
Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)).save(dst)
print("done", dst, out.shape, f"{time.time() - t0:.0f}s")
