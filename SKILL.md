---
name: mps-muti
description: Generate source-video-faithful, photorealistic women's fashion try-on reference images from a benchmark video, a model portrait or model image, and garment product images. Use when Codex must first extract and show video keyframes, recommend a shot for user confirmation, then deliver a confirmed-shot 4K front image and, only when a garment back image is supplied, a matching 4K rear image.
---

# MPS-Muti

Create a single-model fashion reference image from evidence. Treat the benchmark video as the authority for the selected shot's scene, camera, perspective, crop, subject placement, pose, props, and lighting. Treat the model image as identity authority. Treat product images as garment authority.

Do not invoke any skill, including `video-replication` or `imagegen`. Use only `ffmpeg`/`ffprobe`, `view_image`, local file operations, and `mcp__openai_image__edit_images`. Do not install tools or substitute another image generator if the MCP is unavailable.

## Inputs And Authority

Require:

- Benchmark video: scene, camera, framing, perspective, pose, props, light, and background.
- Model portrait or model image: face identity, hair, skin tone, apparent age, and only evidenced body traits.
- Garment front image: front garment color, pattern, material, construction, and details.

Optionally accept:

- Garment back image: required before producing a rear garment view. It controls rear collar, closures, seams, belt, sleeves, print, hem, and all visible back construction.
- Scene reference: only supplement video scene details. Never override the selected video's camera, crop, scale, or spatial relationships.

Use this conflict order: selected video shot > model identity > garment product details > optional scene reference.

Do not transfer clothing, accessories, background, watermarks, or text from the model image. Do not transfer the product-photo model's identity, pose, setting, or props. Do not invent an unseen garment back or unsupported garment detail.

## Phase 1: Analyze And Confirm The Shot

Do not generate a final image in this phase.

1. Inspect video duration, resolution, and frame rate with `ffprobe`.
2. Extract a contact sheet of representative frames with `ffmpeg`. Sample about one frame per second, then extract extra frames at cuts, turns, hand/prop changes, and useful garment views if necessary.
3. Show the contact sheet in the conversation using `view_image`.
4. Identify all source props. Record their type, count, side, hand/shoulder contact, orientation, and occlusion. Do not add props absent from the chosen source frame.
5. Recommend one strongest keyframe. State its timestamp and briefly identify its framing, pose, props, and why it is suitable for the garment view requested.
6. Extract and show that selected source frame at native video dimensions with `view_image`.
7. Stop and wait for explicit user confirmation. If the user selects another frame or asks for a new pose, extract and show the revised candidate before continuing.

For a requested front view, prefer a clear full-body or product-revealing frontal source frame. Preserve its pose unless the user explicitly requests a limited change such as hands naturally down or a larger subject scale.

## Phase 2: Generate The Front Image

Start only after the user confirms a selected frame.

1. Use `mcp__openai_image__edit_images` once with exactly these roles, in this order:
   - selected video frame: composition master;
   - model image: identity only;
   - garment front product image: garment front only.
2. Request `2160x3840` and high quality.
3. Write an explicit prompt that locks:
   - source scene, camera, perspective, crop, subject position, pose, gaze, expression, source props, and lighting;
   - model face, hair, skin tone, and apparent age;
   - garment color, silhouette, material, texture, print, seams, collar, sleeves, buttons, closures, pockets, belt, and hem from the front product image;
   - natural anatomy, five fingers per visible hand, fabric folds, contact shadows, prop contact, and no text/watermarks/UI.
4. If user asked for a pose or framing adjustment, make only that adjustment while retaining the selected shot's camera, environment, prop placement, and spatial relationships.
5. Inspect the generated output with `view_image`. Check identity, selected composition, garment structure, prop count/contact, hands, feet, lighting, and absence of text or watermarks.

Do not issue another image-generation request merely to reach 4K. If the MCP output is below `2160x3840`, perform exactly one non-generative local upscale using high-quality Lanczos resampling and light sharpening. Verify the final file dimensions are exactly `2160x3840`.

## Phase 3: Optional Rear Image

Generate a rear image only when the user provided a garment back image.

If the source video contains a suitable rear-view frame, present it for confirmation before generating. If no suitable rear frame exists, use the confirmed source scene, camera height, lighting, prop, and full-body scale to create a neutral straight-on rear standing view. State that this rear pose is derived because the video lacks rear pose evidence.

Use one MCP call for the rear image with:

- rear source frame or the confirmed front frame as scene/camera master;
- model image for hair, skin, body identity, and apparent age only;
- garment back image as the sole authority for all visible rear garment construction.

Do not put front buttons, front lapels, front closures, or unverified features into the rear image. Apply the same one-pass, non-generative 4K-upscale rule as the front image.

## Delivery

Save final files under a task-local `output/` directory with clear names:

- `fashion-reference-front-4K.png`
- `fashion-reference-back-4K.png` when applicable

Present the 4K front image inline. When available, present the 4K rear image inline immediately after it. Do not show intermediate generated images as delivery artifacts and do not generate a redundant variant.
