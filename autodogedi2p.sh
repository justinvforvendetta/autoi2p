#!/bin/bash
#todo_setup_much_configs
if [[ $EUID -eq 0 ]]
then
    #apt-get install libssl-dev libdb-dev libdb++-dev libqrencode-dev qt4-qmake libqtgui4 libqt4-dev libminiupnpc-dev libminiupnpc8 libboost-all-dev libboost1.53-all-dev build-essential git
    apt-get install -f --force-yes --yes build-essential pkg-config libtool autotools-dev autoconf automake libssl-dev libboost-all-dev libdb5.3-dev  libdb5.3++-dev libminiupnpc-dev libdb++-dev qt4-qmake libqt4-dev libboost-dev libboost-system-dev libboost-filesystem-dev libboost-program-options-dev libboost-thread-dev libssl-dev libminiupnpc8 git 
    $(which git) clone https://github.com/doged/dogedsource && cd dogedsource/src
    make -f makefile.unix && make install
    if [[ -f src/dogecoindarkd ]] && cp src/dogecoindarkd /usr/bin/dogecoindarkd
    qmake "USE_UPNP=- USE_QRCODE=0 USE_IPV6=0" dogecoindark-qt.pro
    make
    if [[ -f dogecoindark-qt ]] && cp dogecoindark-qt /usr/bin/dogecoindark-qt
    mkdir -p $HOME/.DogeCoinDark
    if [[ -f $HOME/.DogeCoinDark/DogeCoinDark.conf ]] && mv $HOME/.DogeCoinDark/DogeCoinDark.conf $HOME/.DogeCoinDark/DogeCoinDark.conf.bak
    curl -ksL https://raw.githubusercontent.com/doged/i2pautoinstall/master/DogeCoinDark.conf >> $HOME/.DogeCoinDark/DogeCoinDark.conf
    # preseed debconf to set I2P to start at boot
    echo "i2p i2p/daemon boolean true" | debconf-set-selections
    # The 'i2psvc' user is created by the 'i2p' package and is set
    # to start I2P by default. You can set another user here but you
    # must ensure that it exists, e.g.
    #if ! getent passwd i2p; then
    # adduser --system --quiet --group --home /home/i2p i2p > /dev/null 2>&1
    #fi
    echo "i2p i2p/user string i2psvc" | debconf-set-selections
    $(which add-apt-repository) ppa:i2p-maintainers/i2p
    apt-get update
    apt-get install sun-java6-jre i2p i2p-keyring 
    mkdir -p $HOME/.i2p
    if [[ -f $HOME/.i2p/i2ptunnel.config ]] && mv $HOME/.i2p/i2ptunnel.config $HOME/.i2p/i2ptunnel.config.bak
    curl -ksL https://raw.githubusercontent.com/doged/i2pautoinstall/master/i2ptunnel.config > $HOME/.i2p/i2ptunnel.config
    # If we end up here, I2P should be installed, running, and configured to start at boot.
    # ..but let's make sure.
    if service i2p status > /dev/null 2>&1; then :; else
        # Since we're here, I2P was not running. We'll make sure the initscript is enabled,
        # then start I2P
        sed -i.bak -e 's/^.*\(RUN_DAEMON\).*/\1="true"/' /etc/default/i2p
        service i2p start
    fi
    # Get the configured user from the debconf db
    I2PUSER=$(debconf-show i2p |sed -e '/i2p\/user/!d' -e 's/.*:\s\+//')
    if [ $I2PUSER != 'i2psvc' ]; then
        I2PHOME=$(getent passwd $I2PUSER | awk -F: '{print $6}')
    else
        I2PHOME="/var/lib/i2p/i2p-config"
    fi
    #Check to ensure config file has generated before setting firewall rules
    # Wait up to 10 seconds for router.config to be created.
    wait_until 10 "test -e /var/lib/i2p/i2p-config/router.config"
    i2pport=$(awk -F= '/i2np\.udp\.port/{print $2}' $I2PHOME/router.config)
    if [ x$i2pport = 'x' ]; then
        echo "Error determining I2P's UDP port" >&2
        exit 1
    else
        echo "The I2P port is $i2pport"
    fi
    #Set firewall rules to allow I2P
    ufw default deny
    ufw allow $i2pport
else
    echo -n "much codez need run with root"    
fi
 
wait_until() {
    local timeout check_expr delay timeout_at
    timeout="${1}"
    check_expr="${2}"
    delay="${3:-1}"
    timeout_at=$(expr $(date +%s) + ${timeout})
    until eval "${check_expr}"; do
        if [ "$(date +%s)" -ge "${timeout_at}" ]; then
            return 1
        fi
    sleep ${delay}
    done
    return 0
}