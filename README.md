# VMD Trajectory Movie Renderer

Render a molecular-dynamics trajectory as high-quality PPM frames in
[VMD](https://www.ks.uiuc.edu/Research/vmd/) and convert the sequence into an
H.264 MP4 movie with [FFmpeg](https://ffmpeg.org/).

The Tcl script uses VMD's internal Tachyon ray tracer, supports a selectable
frame range and stride, and can add a customizable text label without deleting
other graphics objects already present in the scene.

## Repository contents

| File | Purpose |
| --- | --- |
| `Render_Frames.tcl` | Renders selected trajectory frames as a numbered PPM sequence. |
| `README.md` | Setup, usage, encoding commands, and troubleshooting. |

## Requirements

- VMD with the `TachyonInternal` renderer available.
- FFmpeg built with the `libx264` encoder.
- Enough free disk space for uncompressed PPM images.

In the VMD Tk Console, check that the renderer is available with:

```tcl
render list
```

At a terminal, check FFmpeg and H.264 support with:

```bash
ffmpeg -version
ffmpeg -hide_banner -encoders | grep libx264
```

On Windows, use `findstr libx264` instead of `grep`.

## Quick start

1. Open VMD and load the structure and trajectory. The trajectory to be
   rendered must belong to the top molecule.
2. Configure the molecular representation, colors, background, projection,
   orientation, zoom, and any periodic-image display exactly as desired.
3. Open `Render_Frames.tcl` and adjust the settings near the top of the file.
4. Open **Extensions > Tk Console** in VMD and source the script:

   ```tcl
   source /absolute/path/to/Render_Frames.tcl
   ```

   Windows paths can be written with forward slashes, for example:

   ```tcl
   source C:/Users/username/path/to/Render_Frames.tcl
   ```

5. By default, the images are saved as:

   ```text
   frames/untitled.0000.ppm
   frames/untitled.0001.ppm
   frames/untitled.0002.ppm
   ...
   ```

The script numbers output images consecutively from zero, even when only part
of the trajectory or every nth frame is rendered. This keeps the FFmpeg input
sequence continuous.

## Configuration

Edit only the **User settings** section unless the rendering logic itself needs
to change.

| Setting | Default | Meaning |
| --- | ---: | --- |
| `output_dir` | `frames` | Directory in which PPM files are written. Relative paths use VMD's current working directory. |
| `prefix` | `untitled` | Prefix used for every rendered image. |
| `width`, `height` | `1920`, `1080` | Native Tachyon render resolution in pixels. |
| `first_frame` | `0` | First trajectory frame to render. |
| `last_frame` | `-1` | Last frame to render; `-1` means the final loaded frame. |
| `frame_step` | `1` | Trajectory stride; `1` renders all frames, `2` every other frame, and so on. |
| `overwrite_existing` | `0` | Refuses to start when matching frames exist; set to `1` only for intentional overwriting. |
| `show_label` | `1` | Set to `0` to disable the text label. |
| `label_text` | `Movie prepared by Vahid` | Text drawn into each rendered image. |
| `label_position` | `{-2.0 2.0 0.0}` | Label position in 3D scene coordinates. |
| `label_color` | `black` | Any color name recognized by VMD. |
| `label_size` | `1.0` | VMD text size. |
| `label_thickness` | `2.0` | VMD text stroke thickness. |

The label position is not a screen-fixed pixel coordinate. Set the final view
first, run a short test, and then adjust `label_position` if necessary.

## Create a Full HD movie

Render the frames natively at Full HD in `Render_Frames.tcl`:

```tcl
set width 1920
set height 1080
```

Then run this command from the directory containing the `frames` folder:

```bash
ffmpeg -framerate 25 -start_number 0 \
  -i "frames/untitled.%04d.ppm" \
  -c:v libx264 -crf 18 -preset slow \
  -pix_fmt yuv420p -movflags +faststart \
  movie_hd1080.mp4
```

## Create a 4K UHD movie

For genuine 4K detail, render the source frames at 4K UHD rather than enlarging
the 1080p images during encoding:

```tcl
set width 3840
set height 2160
```

Render into an empty output directory, then encode:

```bash
ffmpeg -framerate 25 -start_number 0 \
  -i "frames/untitled.%04d.ppm" \
  -c:v libx264 -crf 18 -preset slow \
  -pix_fmt yuv420p -movflags +faststart \
  movie_4k_uhd.mp4
```

FFmpeg's `4k` size abbreviation means **4096 x 2160** (DCI 4K), whereas the
usual 16:9 monitor/TV format is **3840 x 2160** (`uhd2160`). Applying `-s 4k`
to 1920 x 1080 input therefore both upscales the image and changes its aspect
ratio. If DCI 4K is specifically required, render at 4096 x 2160 in VMD and
reframe the scene there.

## Encoding options

- `-framerate 25` makes a 25-frame-per-second movie. Change it to alter playback
  speed; movie duration is the number of rendered images divided by this value.
- `-crf 18` gives high H.264 quality. Lower values increase quality and file
  size; higher values reduce both.
- `-preset slow` spends more encoding time to improve compression efficiency.
- `-pix_fmt yuv420p` improves compatibility with common players and browsers.
- `-movflags +faststart` places MP4 metadata near the beginning of the file for
  faster web playback startup.

The numbered input pattern is preferable to a glob because it is deterministic
and does not depend on FFmpeg being compiled with glob support. If the filenames
or directory differ from the defaults, update the `-i` pattern accordingly.

## Storage considerations

PPM files are uncompressed. Approximate RGB storage per frame is:

| Resolution | Approximate size per frame |
| --- | ---: |
| 1920 x 1080 | 5.9 MiB |
| 3840 x 2160 | 23.7 MiB |

After checking the final MP4 carefully, the PPM sequence can be archived or
removed manually.

## Troubleshooting

### `No molecule is loaded`

Load both the structure and trajectory before sourcing the Tcl script. Make
sure the intended trajectory is the top molecule in VMD.

### `Renderer 'TachyonInternal' is not available`

Run `render list` in the VMD Tk Console. Use a VMD installation that includes
the internal Tachyon renderer.

### The image size cannot be set

The script requires a VMD build that supports renderer-specific image sizing.
Update VMD if `render imagesize` is unavailable.

### The label is misplaced or not visible

Adjust `label_position` after fixing the final view. Select a contrasting
`label_color` (for example, white on a dark background), or disable the label
with `set show_label 0`.

### Existing frames are reported

Use a new `output_dir` or `prefix`, or remove the old sequence after confirming
it is no longer needed. Avoid mixing images from different runs because FFmpeg
will treat them as one continuous movie.

### Rendering takes too long

Test a small range first by setting `last_frame` to a low number. For the final
run, reduce the resolution or increase `frame_step` if scientifically and
visually appropriate.

## Documentation

- [VMD `render` command](https://www.ks.uiuc.edu/Research/vmd/current/ug/node147.html)
- [VMD `graphics` command](https://www.ks.uiuc.edu/Research/vmd/current/ug/node129.html)
- [FFmpeg image-sequence input](https://ffmpeg.org/ffmpeg-formats.html#image2-1)
- [FFmpeg video-size abbreviations](https://ffmpeg.org/ffmpeg-utils.html#Video-size)


## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
