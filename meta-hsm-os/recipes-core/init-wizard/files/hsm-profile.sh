# /etc/profile.d/hsm-login.sh
if [ -n "$PS1" ] && [ "$(id -u)" != "0" ]; then
    if [ -x /usr/local/bin/first-login-wizard.sh ]; then
        /usr/local/bin/first-login-wizard.sh
    fi
    if [ -x /usr/local/bin/clock-setup.sh ]; then
        /usr/local/bin/clock-setup.sh
    fi
fi
