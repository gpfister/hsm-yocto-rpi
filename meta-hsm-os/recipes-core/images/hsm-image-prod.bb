SUMMARY = "nRF52840 HSM Production Air-Gapped Image"
DESCRIPTION = "Fully hardened, immutable, production air-gapped embedded Linux image with strict port exposure."

require hsm-image-base.bb

inherit extrausers
# Lock root account to prevent root login
EXTRA_USERS_PARAMS = "usermod -L root;"

# Ensure no debugging tweaks or debug packages are pulled in
EXTRA_IMAGE_FEATURES = ""
