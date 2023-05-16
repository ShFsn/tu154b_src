#!/bin/bash
#
# Looks up all .png's and creates dds with imagemagick or nvcompress (if available) 
#             from them, if not already done.
#
# All parameters are optional:
# --dir [path] specifies the root directory to scan recursively.
#             Default is "local dir" (".").
# --no-replace specifies whether already existing DDSes will be geneterated again
#             or left as is.
# --png-remove specifies whether orignal PNGs will be removed of not.
# --alpha-remove specifies whether alpha channel will be removed or not
#             (redusing resulting DDS size).
# --flip specifies whether image will be flipped from up to down.
# --flip-normals specifies whether normal vector will be flipped as well
#             (should be used for normal maps instead of --flip).
#
# All-options example: 
# `./fg_dds_converter.sh --dir ../Models/Fuselage/ --no-replace --png-remove --alpha-remove --no-flip`
#


# Read parameters
root=".";
replace=true;
png_remove=false;
alpha_remove=false;
flip=false;
flip_normals=false;
#[[ -n "$1" ]] && root="$1"
while [ -n "$1" ]; do
    case "$1" in
    --dir) root="$2";;
    --no-replace) replace=false;;
    --png-remove) png_remove=true;;
    --alpha-remove) alpha_remove=true;;
    --flip) flip=true;;
    --flip-normals) flip=true; flip_normals=true;;
    *);;
    esac;
    shift;
done;
echo "
Parameters:
    Directory for recursive PNG search (--dir [path]):
        ${root}
    Replace old DDS (--no-replace):
        ${replace}
    Remove PNG (--png-remove):
        ${png_remove}
    Remove alpha channel (--alpha-remove):
        ${alpha_remove}
    Flip DDS up-down (--flip / forced with --flip-normals):
        ${flip}
    Flip normalmap (--flip-normals):
        ${flip_normals}";

# Check if NVIDIA texture tools is installed
command -v nvcompress >/dev/null
if [[ $? -gt 0 ]]; then
    echo "
nvcompress not available, using imagemagick";
    nvcompress_available=false;
else
    echo "
nvcompress available, using nvcompress";
    nvcompress_available=true;
fi

# Search PNGs
find $root -name '*.png' | while IFS= read file; do
    dir=$(dirname $file);
    name=$(basename $file .png);
    echo "
Found PNG $file: ";

    # Determine if replacing is needed
    no_skip=true;
    if [ -f ${dir}/${name}.dds ]; then
        if $replace; then
            echo "DDS already exist, replacing.";
        else
            echo "DDS already exist, skipping.";
            no_skip=false;
        fi;
    else
        echo "DDS does not exist, starting convertion.";
    fi;

    if $no_skip; then
        # Create temporary file
        convert $file "${dir}/${name}.tmp";

        # Removing alpha
        if $alpha_remove; then
            echo "Removing alpha channel...";
            convert -background black -alpha remove "${dir}/${name}.tmp" "${dir}/${name}.tmp";
            #convert -background black -alpha remove "${dir}/${name}.tmp" "${dir}/${name}1.png";
        fi;

        #Flip
        if $flip; then
            echo "Flipping image..."
            convert -flip "${dir}/${name}.tmp" "${dir}/${name}.tmp";

            # Convert normal vectors
            if $flip_normals; then
                echo "Flipping normals...";
                mogrify -channel red -negate +channel -channel green -negate +channel "${dir}/${name}.tmp";
            fi;
        fi;

        # Convert to DDS
        echo "Converting to DDS (${dir}/${name}.dds)...";
        if $nvcompress_available; then
            if $normalmap; then
                nvcompress -normal -bc5 "${dir}/${name}.tmp" "${dir}/${name}.tmp";
            elif $alpha_remove; then
                nvcompress -color -bc1 "${dir}/${name}.tmp" "${dir}/${name}.tmp";
            else 
                nvcompress -alpha -bc3 "${dir}/${name}.tmp" "${dir}/${name}.tmp";
            fi;
            #nvcompress -bc1a "${dir}/${name}.tmp" "${dir}/${name}.tmp";
        else
            if $alpha_remove; then
                convert "${dir}/${name}.tmp" -define dds:compression=DXT1 dxt1:${dir}/${name}.tmp;
            else
                convert "${dir}/${name}.tmp" -define dds:compression=DXT5 dxt5:${dir}/${name}.tmp;
            fi;
        fi;
        mv "${dir}/${name}.tmp" "${dir}/${name}.dds";

        # Remove PNG
        if $png_remove; then
            echo "Removing PNG $file...";
            rm -f $file;
        fi;
    fi;

done; 

echo "
Done.
";
