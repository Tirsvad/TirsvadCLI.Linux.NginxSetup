# Nginx Setup script

## Add it as submodule to your git project
mkdir <submodule folder>
cd <submodule folder>
git submodule add git@github.com:TirsvadCLI/Linux.NginxSetup.git <optional dir place>
git submodule init
git submodule update

## Update a submodule
git submodule update --remote
git add .
git commit -m "git submodule updated"
git push origin
