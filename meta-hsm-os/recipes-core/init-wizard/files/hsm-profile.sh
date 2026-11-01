# /etc/profile.d/hsm-login.sh
# Execute initial setup wizard and clock prompt on interactive console logins
if [ -t 0 ] && [ "$(id -u)" != "0" ]; then
    if [ -x /usr/local/bin/first-login-wizard.sh ]; then
        /usr/local/bin/first-login-wizard.sh
    fi
    if [ -x /usr/local/bin/clock-setup.sh ]; then
        /usr/local/bin/clock-setup.sh
    fi
fi
