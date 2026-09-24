#!/usr/bin/env sh

# Terminate already running bar instances
killall volumeicon
killall -q polybar

# Wait until the processes have been shut down
# while pgrep -x polybar >/dev/null; do sleep 1; done

# Launch
polybar -r mainbar-bspwm &
polybar -r mainbar-bspwm-extra &
volumeicon &

echo "Bar launched..."
