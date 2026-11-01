SUMMARY = "nRF52840 HSM Development Image"
DESCRIPTION = "Development image with debugging tools, root console access, and dual serial port exposure."

require hsm-image-base.bb

IMAGE_FEATURES += "debug-tweaks tools-debug"

IMAGE_INSTALL:append = " \
    sudo \
    strace \
"
