
# Blueprint on Unraid
### some things which are maybe important
The first thing i have to say this is not the things we should do if we want to have blueprint installed inside a Docker container on Unraid and im trying to make an Unraid template with the Docker container which includes Blueprint already but i dont have a lot of time to get me trough this so use this with care (also there are some more things which we need to solve which i kinda solved myself but its not how it should be) pterodactyl has a queue worker and this one is not really working in the IBRACORP container so i first tried it with just making a service file for this one but the container is running without systemd so i just did a cronjob on this (again not how it should be but works for now)
### plugins which work
-   Nebula from [Emma/prplwtf](https://github.com/prplwtf)
-   Slate from [Emma/prplwtf](https://github.com/prplwtf)
-   Modpackinstaller for Blueprint (with the need of running the queue worker)

###
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
-   findutils
-   [Node version manager](https://www.freecodecamp.org/news/node-version-manager-nvm-install-guide/) (i tried it with manually installing nodejs but continuing with the install of blueprint i had some errors i couldnt fix)

for the dependencies just use the command `microdnf install <your dependencies -y>` so you can basically just do `microdnf install ca-certificates curl gnupg nano wget git zip unzip findutils -y`

for node version manager we can tun the installer: `wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash`

if you have some trouble installing node version manager just reach out to me in Discord

it could be that you have to reboot the container after you installed nvm

after you sucessfully installed NVM you have to install nodejs version 20 with `nvm install 20`
### Blueprint install 

we have to instal yarn with `npm i -g yarn`
after this we just have to run yarn in your dircetory so just execute `yarn` and `yarn install` in command line

download latest Blueprint release with `wget "$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4)" -O release.zip` 

when its done downloading just unzip it with `unzip release.zip`

to do the last step to proceed to the install of blueprint we have to create a 
.blueprintrc file for skipping some things in the blueprint install script just execute `echo -e "DOCKER='n'\nFOLDER='/var/www/html'" > .blueprintrc` to create the file, you can check if the file is there with just executing `nano .blueprintrc` if you created this sucessfully

we only need to give blueprint permissions to execute
`chmod +x blueprint.sh`
after this you can just execute the blueprint script with `./blueprint.sh` or `bash blueprint.sh`

## some more stuff

some plugins need the user www-data to install sucessfully so we might have to create this one and give the user the rights for the pterodactyl files 
`adduser --user-group www-data`
and make the files writeable for the user
`chmod -R 777 /var/www/html`

