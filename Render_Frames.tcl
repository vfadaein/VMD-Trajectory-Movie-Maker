# Render_Frames.tcl
#
# Render selected frames from the trajectory currently loaded as VMD's top
# molecule. Frames are written as a consecutively numbered PPM sequence that
# can be converted to an MP4 movie with FFmpeg.
#
# Usage:
#   1. Load a structure and trajectory in VMD.
#   2. Set the desired representation, colors, orientation, and display style.
#   3. Adjust the user settings below.
#   4. In Extensions > Tk Console, run:
#        source /path/to/Render_Frames.tcl

# =============================================================================
# User settings
# =============================================================================

# Output directory and filename prefix. A relative directory is resolved from
# VMD's current working directory (shown by running "pwd" in the Tk Console).
set output_dir "frames"
set prefix "untitled"

# Rendered image size in pixels.
# Full HD: 1920 x 1080
# 4K UHD: 3840 x 2160
set width 1920
set height 1080

# Frame selection. Set last_frame to -1 to render through the final trajectory
# frame. frame_step = 1 renders every frame; 2 renders every other frame, etc.
set first_frame 0
set last_frame -1
set frame_step 1

# Refuse to start if matching PPM files already exist. This helps prevent old
# and new frames from being mixed accidentally. Set to 1 only if overwriting is
# intentional; stale frames beyond the new sequence must still be removed by
# the user before encoding.
set overwrite_existing 0

# Optional text label. The position is a 3D scene coordinate, not a fixed pixel
# coordinate, so adjust it after choosing the final molecular view.
set show_label 1
set label_text "Movie prepared by Vahid"
set label_position {-2.0 2.0 0.0}
set label_color "black"
set label_size 1.0
set label_thickness 2.0

# VMD renderer used for every frame.
set renderer "TachyonInternal"

# =============================================================================
# Validation and renderer setup
# =============================================================================

set molid [molinfo top]
if {$molid < 0} {
    error "No molecule is loaded. Load a structure and trajectory before running this script."
}

set total_frames [molinfo $molid get numframes]
if {$total_frames < 1} {
    error "The top molecule does not contain any trajectory frames."
}

if {$last_frame == -1} {
    set last_frame [expr {$total_frames - 1}]
}

if {$first_frame < 0 || $first_frame >= $total_frames} {
    error "first_frame must be between 0 and [expr {$total_frames - 1}]."
}
if {$last_frame < $first_frame || $last_frame >= $total_frames} {
    error "last_frame must be between first_frame and [expr {$total_frames - 1}]."
}
if {$frame_step < 1} {
    error "frame_step must be a positive integer."
}
if {$width < 1 || $height < 1} {
    error "width and height must be positive integers."
}

if {[lsearch -exact [render list] $renderer] < 0} {
    error "Renderer '$renderer' is not available in this VMD installation. Available renderers: [render list]"
}

# Set the renderer output format and resolution explicitly. Supplying "-res"
# after the render filename is incorrect because VMD interprets extra arguments
# there as a shell command to execute after rendering.
if {[catch {render format $renderer PPM} setup_error]} {
    error "Could not set $renderer output format to PPM: $setup_error"
}
if {[catch {render imagesize $renderer [list $width $height]} setup_error]} {
    error "Could not set $renderer image size to ${width}x${height}: $setup_error"
}

file mkdir $output_dir
set output_dir_abs [file normalize $output_dir]

# Do not silently combine this run with an older sequence using the same prefix.
set existing_frames [glob -nocomplain [file join $output_dir "${prefix}.*.ppm"]]
if {[llength $existing_frames] > 0} {
    if {!$overwrite_existing} {
        error "Matching frames already exist in '$output_dir_abs'. Choose another output_dir/prefix, remove the old frames, or set overwrite_existing to 1."
    }
    puts "WARNING: Existing '${prefix}.*.ppm' files may be overwritten. Remove any stale extra frames before running FFmpeg."
}

set selected_frame_count [expr {(($last_frame - $first_frame) / $frame_step) + 1}]
puts "Rendering $selected_frame_count frame(s) at ${width}x${height} with $renderer."
puts "Output directory: $output_dir_abs"

# =============================================================================
# Label and frame rendering
# =============================================================================

# Add one persistent graphics object for the entire sequence. Unlike
# "draw delete all", this preserves any other graphics objects in the scene.
set label_id -1
if {$show_label && $label_text ne ""} {
    graphics $molid color $label_color
    graphics $molid materials off
    set label_id [graphics $molid text $label_position $label_text \
        size $label_size thickness $label_thickness]
}

set output_index 0
set render_failed [catch {
    for {set frame $first_frame} {$frame <= $last_frame} {incr frame $frame_step} {
        # animate goto also pauses trajectory playback at the requested frame.
        animate goto $frame

        # Number output images consecutively from zero even when frame_step > 1.
        # This makes FFmpeg's "%04d" sequence input work without filename gaps.
        set frame_name [format "%s.%04d.ppm" $prefix $output_index]
        set filename [file join $output_dir $frame_name]

        # The empty third argument explicitly disables any post-render shell
        # command (for example, automatically opening an image viewer).
        render $renderer $filename ""
        puts "Rendered trajectory frame $frame -> $filename"
        incr output_index
    }
} render_error]

# Remove only the graphics object created above and leave the user's other
# labels, drawings, and molecular representations unchanged.
if {$label_id >= 0} {
    catch {graphics $molid delete $label_id}
}

if {$render_failed} {
    error "Rendering stopped: $render_error"
}

puts "Finished rendering $output_index frame(s) to '$output_dir_abs'."
puts "Use the FFmpeg commands in README.md to create the movie."
