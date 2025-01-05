#!/bin/zsh

cd ~/Downloads/mp3

# ls | grep mp3 | sed 's/\.mp3//' | xargs -I{} echo {}
# ls | grep mp3 | sed 's/\.mp3//' | xargs -I{} ffmpeg -loop 1 -i input.jpg -i "{}.mp3" -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black,setsar=1,format=yuv420p" -shortest -fflags +shortest "{}.mp4"
find . -type f -name '*.mp3' -mmin -120 | sed 's/\.mp3//' | xargs -I{} ffmpeg -loop 1 -i input.jpg -i "{}.mp3" -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black,setsar=1,format=yuv420p" -shortest -fflags +shortest "{}.mp4"

# ffmpeg -loop 1 -i input.jpg -i "野地的花.mp3" -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black,setsar=1,format=yuv420p" -shortest -fflags +shortest "野地的花.mp4"