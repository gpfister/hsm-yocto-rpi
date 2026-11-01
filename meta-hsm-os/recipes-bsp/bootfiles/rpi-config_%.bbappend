# Raspberry Pi firmware config.txt air-gap lockdown and hardware adaptation
RPI_EXTRA_CONFIG:append = " \n\
# Air-Gap Hardware Lockdown\n\
dtoverlay=disable-bt\n\
dtoverlay=disable-wifi\n\
boot_delay=0\n\
disable_splash=1\n\
# Waveshare USB HAT (B) Host Mode Support\n\
dtoverlay=dwc2,dr_mode=host\n\
# Video Console on HDMI (tty1)\n\
hdmi_force_hotplug=1\n\
hdmi_drive=2\n\
"
