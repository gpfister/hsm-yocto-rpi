# Disable onboard Bluetooth and WiFi via standard device tree overlays
RPI_EXTRA_CONFIG:append = " \n\
# Air-Gap Hardware Lockdown\n\
dtoverlay=disable-bt\n\
dtoverlay=disable-wifi\n\
boot_delay=0\n\
disable_splash=1\n\
"
