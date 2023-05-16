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
# --normalmap specifies whether the image is normalmap
#             (should be used for normal maps instead of --flip).
# --nvcompress nvcompress will be used if available.
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
normalmap=false;
use_nvcompress=false;
#[[ -n "$1" ]] && root="$1"
while [ -n "$1" ]; do
    case "$1" in
    --dir) root="$2";;
    --no-replace) replace=false;;
    --png-remove) png_remove=true;;
    --alpha-remove) alpha_remove=true;;
    --flip) flip=true;;
    --normalmap) alpha_remove=true; normalmap=true;;
    --nvcompress) use_nvcompress=true;;
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
    Remove alpha channel (--alpha-remove / forced with --normalmap):
        ${alpha_remove}
    Flip DDS up-down (--flip):
        ${flip}
    Treat as normalmap (--normalmap):
        ${normalmap}
    Use nvcompress (--nvcompress):
        ${use_nvcompress}";

# Check if NVIDIA texture tools is installed
echo "
";
command -v nvcompress >/dev/null
if [[ $? -gt 0 ]]; then
    echo "nvcompress not available";
    use_nvcompress=false;
else
    echo "nvcompress available";
fi;
if $use_nvcompress; then
    echo "Using nvcompress";
else
    echo "Using imagemagick";
fi;

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
        convert $file "${dir}/${name}.tga";

        # Removing alpha
        if $alpha_remove; then
            echo "Removing alpha channel...";
            convert -background black -alpha remove "${dir}/${name}.tga" "${dir}/${name}.tga";
        fi;

        #Flip
        if $flip; then
            echo "Flipping image..."
            convert -flip "${dir}/${name}.tga" "${dir}/${name}.tga";

            # Convert normal vectors
            if $normalmap; then
                echo "Flipping normals...";
                mogrify -channel red -negate +channel -channel green -negate +channel "${dir}/${name}.tga";
            fi;
        fi;

        # Convert to DDS
        echo "Converting to DDS (${dir}/${name}.dds)...";
        if $use_nvcompress; then
            convert -flip "${dir}/${name}.tga" "${dir}/${name}.tga"; # counteract nvcompress flip
            if $normalmap; then
                nvcompress -normal -bc1n "${dir}/${name}.tga" "${dir}/${name}.tga";
            elif $alpha_remove; then
                nvcompress -color -bc1 "${dir}/${name}.tga" "${dir}/${name}.tga";
            else 
                nvcompress -alpha -bc3 "${dir}/${name}.tga" "${dir}/${name}.tga";
            fi;
            #nvcompress -bc1a "${dir}/${name}.tga" "${dir}/${name}.tga";
        else
            if $alpha_remove; then
                convert "${dir}/${name}.tga" -define dds:compression=DXT1 dxt1:${dir}/${name}.tga;
            else
                convert "${dir}/${name}.tga" -define dds:compression=DXT5 dxt5:${dir}/${name}.tga;
            fi;
        fi;
        mv "${dir}/${name}.tga" "${dir}/${name}.dds";

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
