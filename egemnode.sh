#!/bin/bash

create_swap(){
    swap_file="/swapfile"
    
    if [ -n "$(grep swap /etc/fstab)" ]; then
        echo
        echo "Looks like you already have a swap file/partition."
        echo "Skipping swap creation."
        echo
        sleep 3
    else
        fallocate -l 2G ${swap_file} || error "Create Swap - fallocate"
        chmod 600 ${swap_file}
        mkswap ${swap_file} || error "Create Swap - mkswap"
        swapon ${swap_file} || error "Create Swap - swapon"
        
        echo "${swap_file} none swap sw 0 0" | tee -a /etc/fstab
    fi
}

install_egem_node(){
    cd ${HOME}
    
    echo
    echo "What woud you like to name your instance? (example -> TeamEGEM Node East Coast USA):"
    read nodename
    
    echo
    echo "What is your node's contact details? (example -> twitter: @TeamEGEM):"
    read contactdetails
    
    add_repos
    update_system
    essentials
    fw_conf
    livenet_data
    install_go_egem
    install_net_intel
    create_service
    start_go_egem
    start_net_intel
    
    echo
    echo "-------------------------------------------------------------------"
    echo "Setup comlete."
    echo
    echo "Your node should be listed on https://network.egem.io"
    echo
    echo "If it is not listed, try rebooting your VPS and check again."
    echo
    echo "Don't forget to thank our hard working EGEM Devs"
    echo "for this so easy node experience."
    echo "-------------------------------------------------------------------"
    echo
}

update_egem_node(){
    echo
    pkill egem
    cd ${dir_go_egem}
    make clean || error "Update Node - make clean"
    git pull || error "Update Node - git pull"
    make all || error "Update Node - make all"
    
    run_now "go-egem"
}

add_repos(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Adding necessary repositories"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    add-apt-repository main
    add-apt-repository universe
    add-apt-repository restricted
    add-apt-repository multiverse
}

update_system(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Updating current system packages"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    echo "If you see a prompt about 'Grub Configuration',"
    echo "prefer keeping the currently installed version."
    echo
    echo
    sleep 5
    
    up_sys || error "Install Node - system update"
}

up_sys(){
    apt-get update && apt-get upgrade -y && apt-get -f install
}

essentials(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Installing necessary packages"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    up_ess
    
    echo
    npm install -g pm2 || error "Install Node - pm2"
    echo
}

up_ess() {
    if [ -z "$(which curl)" ]; then
        apt-get install -y curl
    fi
    
    curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
    
    apt-get install -y build-essential screen git fail2ban ufw golang nodejs || error "Install Node - necessary packages"
    
    if [ -n "$(lsb_release -r | grep 18)" ]; then
        apt-get install -y golang || error "Install Node - golang package"
    else
        if [ -n "$(which go)" ]; then
            apt-get -y remove golang
            apt-get -y autoremove
        fi
        
        apt-get install -y golang-1.10 || error "Install Node - golang-1.10 package"
        ln -f /usr/lib/go-1.10/bin/go /usr/bin/go
    fi
}

fw_conf(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Configuring Firewall"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    ufw default allow outgoing
    ufw default deny incoming
    ufw allow ssh/tcp
    ufw limit ssh/tcp
    ufw allow 8545/tcp
    ufw allow 30666/tcp
    ufw allow 30661/tcp
    ufw logging on
    ufw --force enable
}

livenet_data(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Downloading live network data"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    cd ${HOME}
    rm -rf ${dir_live_net}
    mkdir -p ${dir_live_net}

    cd ${dir_live_net}
    wget --no-check-certificate https://raw.githubusercontent.com/TeamEGEM/EGEM-Bootnodes/master/static-nodes.json || error "Install Node - live network data download"
}

install_go_egem(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Installing Go-Egem"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    cd ${HOME}
    rm -rf ${dir_go_egem}
    git clone https://github.com/TeamEGEM/go-egem.git || error "Install Node - Go-EGEM download"
    cd ${dir_go_egem} && make egem || error "Install Node - Go-EGEM make"
    cd ${HOME}
}

start_go_egem(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Starting Go-Egem"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    run_now "go-egem"
    
    #if [ -f /etc/systemd/system/${servicefile} ]; then
    #    systemctl start ${servicefile} || error "Go-EGEM start"
    #else
    #    screen -dmUS go-egem ${dir_go_egem}/build/bin/egem --datadir ${dir_live_net}/ --maxpeers 100 --rpc || error "Go-EGEM start"
    #fi
    
    echo
    echo "Your node is syncronizing with network now. This may take some time."
    echo
    sleep 3
}

install_net_intel(){
    echo
    echo "Installing EGEM Net-Intelligence"
    echo "(necessary for sending statistics to network.egem.io)"
    echo
    sleep 3
    
    rm -rf ${dir_net_intel}
    git clone https://github.com/TeamEGEM/egem-net-intelligence-api.git || error "Install Node - net-intel download"
    
    cd ${dir_net_intel}
    
    sed -i '17s/.*/      "INSTANCE_NAME"   : '"'$nodename'"',/' app.json
    sed -i '18s/.*/      "CONTACT_DETAILS" : '"'$contactdetails'"',/' app.json
    sed "s/'/\"/g" app.json
    
    npm install || error "Install Node - net-intel install"
}

start_net_intel(){
    echo
    echo "-------------------------------------------------------------------"
    echo "Starting EGEM Net-Intelligence"
    echo "-------------------------------------------------------------------"
    echo
    sleep 3
    
    run_now "node-app"
    
    #if [ -f /etc/systemd/system/${service2} ]; then
    #    systemctl start ${service2} || error "net-intel start"
    #else
    #    cd ${dir_net_intel} && pm2 start app.json || error "net-intel start"
    #fi
}

run_now(){
    case $1 in
    "go-egem")
        systemctl start ${servicefile} || warn "Go-EGEM start"
    ;;
    "node-app")
        env PATH=$PATH:/usr/local/bin pm2 startup -u root
        cd ${dir_net_intel}
        pm2 start app.json || warn "net-intel start"
    ;;
    esac
}

create_service(){
    if [ ! -f /etc/systemd/system/${servicefile} ]; then
        cd /etc/systemd/system/ && touch ${servicefile}
        
        echo "[Unit]" >> ${servicefile}
        echo "Description=Go-EGEM Service" >> ${servicefile}
        echo "After=network-online.target" >> ${servicefile}
        echo "" >> ${servicefile}
        echo "[Service]" >> ${servicefile}
        echo "User=root" >> ${servicefile}
        echo "Type=simple" >> ${servicefile}
        echo "#TimeoutStartSec=15" >> ${servicefile}
        echo "Restart=always" >> ${servicefile}
        echo "#RestartSec=5" >> ${servicefile}
        echo "ExecStart=${dir_go_egem}/build/bin/egem --datadir ${dir_live_net}/ --maxpeers 100 --rpc" >> ${servicefile}
        echo "#ExecStop=/usr/bin/pkill egem" >> ${servicefile}  
        echo "" >> ${servicefile}
        echo "[Install]" >> ${servicefile}
        echo "WantedBy=multi-user.target" >> ${servicefile}
        echo "" >> ${servicefile}
    fi
    
    systemctl daemon-reload
    systemctl disable ${servicefile}
    systemctl enable ${servicefile}
}

error(){
    echo
    echo "Error. Install failed at this step ->  ${1}"
    echo
    exit 1
}

warn(){
    echo
    echo "This step has failed ->  ${1}"
    echo
    sleep 3
}

dir_net_intel="${HOME}/egem-net-intelligence-api"
dir_live_net="${HOME}/live-net"
dir_go_egem="${HOME}/go-egem"

servicefile="egem.service"

cd ${HOME}

while true
do
    clear
    echo
    echo "======================================================"
    echo " Egem Node Installer v2 (based on BuzzkillB's script) "
    echo "======================================================"
    echo
    echo " 1 - Install Egem Node with Swap File (2G size)"
    echo " 2 - Install Egem Node without Swap File"
    echo
    echo " 3 - Update Egem Node (go-egem)"
    echo
    echo " 4 - Start Egem Node (go-egem) (if installed but stopped)"
    echo " 5 - Stop Egem Node (go-egem)"
    echo
    echo " 6 - Start Network-Intelligence (node-app)"
    echo " 7 - Stop Network-Intelligence (node-app)"
    echo
    echo " 8 - How do I check if my node is running?"
    echo " 9 - What is next? What do I need to do?"
    echo "10 - ROI of nodes?"
    echo
    echo " q - exit this script"
    echo
    echo -n " Enter your selection: "
    read answer
    
    clear; echo; echo
    
    case ${answer} in
    1)
        create_swap && install_egem_node
    ;;
    2)
        install_egem_node
    ;;
    3)
        update_egem_node
    ;;
    4)
        start_go_egem
    ;;
    5)
        pkill egem
    ;;
    6)
        start_net_intel
    ;;
    7)
        pkill pm2
    ;;
    8)
        echo
        echo "-------------------------------------------------------------------"
        echo
        echo "Your node has 2 working parts: go-egem and network-intelligence app"
        echo "go-egem is the actual node, network-intelligence part just sends stats to network.egem.io"
        echo
        echo "To check go-egem:"
        echo "screen -r go-egem"
        echo
        echo "If go-egem is running, you should see a lot of info flowing on the screen."
        echo
        echo "To quit that screen:"
        echo "press  Ctrl + A  and  d"
        echo
        echo "To check network-intelligence:"
        echo "pm2 status"
        echo
        echo "If app is running, you should see a table where 'node-app' is listed and says 'online'"
        echo
        echo "-------------------------------------------------------------------"
        echo
    ;;
    9)
        echo
        echo "-------------------------------------------------------------------"
        echo
        echo "If setup has completed without errors, your node must be up and running."
        echo "Now go to EGEM Discord, #node-owners channel."
        echo
        echo "Run these commands:"
        echo "/botreg YourWalletAddress"
        echo "/changeip YourVpsIP"
        echo
        echo "Last step is asking Riddlez to complete your registration."
        echo
        echo "PS: Make sure you have the necessary balance in your wallet."
        echo
        echo "Happy earnings Node Owner! ^^"
        echo
        echo "-------------------------------------------------------------------"
        echo
    ;;
    10)
        echo
        echo "-------------------------------------------------------------------"
        echo "For detailed info about nodes go check this page:"
        echo
        echo "http://triforce.egem.io/egem.php"
        echo
        echo "Don't forget to thank BuzzkillB for that page."
        echo "-------------------------------------------------------------------"
        echo
    ;;
    q)
        exit
    ;;
    esac
    
    echo
    echo "-------------------------------------------------------------------"
    echo "Press Enter to continue"
    echo "-------------------------------------------------------------------"
    echo
    read input
done
