distrobox assemble create --file main.ini
curl -L 'https://code.visualstudio.com/sha/download?build=insider&os=linux-deb-x64' -o ~/Downloads/code-insiders.deb
distrobox enter main -- sudo apt-get update
distrobox enter main -- sudo apt-get dist-upgrade -y
distrobox enter main -- sudo apt-get -y install libasound2t64 libxkbfile1 xdg-utils
distrobox enter main -- sudo dpkg --install ~/Downloads/code-insiders.deb
distrobox enter main -- sudo apt-get -y -f install
distrobox enter main -- sudo dpkg --install ~/Downloads/code-insiders.deb
distrobox enter main -- distrobox-export --app keybase
distrobox enter main -- distrobox-export --app code-insiders
