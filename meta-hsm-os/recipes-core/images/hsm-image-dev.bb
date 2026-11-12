SUMMARY = "nRF52840 HSM Development Image"
DESCRIPTION = "Development image with debugging tools, root console access, and dual serial port exposure."

require hsm-image-base.bb

inherit extrausers
# Root password 'root' (SHA-512 crypt hash)
EXTRA_USERS_PARAMS = "usermod -p '\$6\$saltsalt\$bAY90rAsHhyx.bxmKP9FE5UF4jP1iWgjV0ltM6ZJxfYkiIaCExjBZIbfmqmZEWoR65aM.1nFvG7fF3gYOjHpM.' root;"

IMAGE_FEATURES += "allow-root-login post-install-logging tools-debug"

IMAGE_INSTALL:append = " \
    sudo \
    strace \
"

# Set development hostname to piKMS-dev
hostname:pn-base-files = "piKMS-dev"
