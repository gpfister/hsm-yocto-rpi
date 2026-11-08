# Raspberry Pi firmware config.txt air-gap lockdown and hardware adaptation
# - Air-Gap Hardware Lockdown (disable Bluetooth and WiFi, silent boot)
# - Waveshare USB HAT (B) Host Mode Support (Synopsys DWC2 host mode)
# - Video Console on HDMI (tty1)
# - HW-084 (DS3231) Real-Time Clock over I2C-1

ENABLE_I2C = "1"

RPI_EXTRA_CONFIG:append = "\n\
dtoverlay=disable-bt\n\
dtoverlay=disable-wifi\n\
boot_delay=0\n\
disable_splash=1\n\
dtoverlay=dwc2,dr_mode=host\n\
dtoverlay=i2c-rtc,ds3231\n\
hdmi_force_hotplug=1\n\
hdmi_drive=2\n\
"
