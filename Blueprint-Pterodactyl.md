
# Blueprint on Unraid

Kinda explanation on how to setup [Blueprint](https://blueprint.zip/docs/?page=getting-started/Installation) on Unraid using the IBRACORP container

### installing dependencies
we have to install some stuff:

-   ca-certificates
-   curl 
-   gnupg
-   nano (if you want to edit some stuff directly from the commandline)
-   wget
-   git 
-   zip
-   unzip
-   [Node version manager](https://www.freecodecamp.org/news/node-version-manager-nvm-install-guide/) (i tried it with manually installing nodejs but continuing with the install of blueprint i had some errors i couldnt fix)

for the dependencies just use the command `microdnf install <your dependencies -y>` so you can basically just do `microdnf install ca-certificates curl gnupg nano wget git zip unzip -y`

for node version manager we can tun the installer: `wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash``

if you have some trouble installing node version manager just reach out to me in Discord

after you sucessfully installed NVM you have to install nodejs version 20 with `nvm install 20`
### Blueprint install 

we have to instal yarn with `npm i -g yarn`
after this we just have to run yarn in your dircetory so just execute `yarn` and `yarn install` in command line


