
# Blueprint on Unraid
### some things which are maybe important
The first thing i have to say this is not the things we should do if we want to have blueprint installed inside a Docker container on Unraid and im trying to make an Unraid template with the Docker container which includes Blueprint already but i dont have a lot of time to get me trough this so use this with care (also there are some more things which we need to solve which i kinda solved myself but its not how it should be) pterodactyl has a queue worker and this one is not really working in the IBRACORP container so i first tried it with just making a service file for this one but the container is running without systemd so i just did a cronjob on this (again not how it should be but works for now)
### plugins which work
-   Nebula from [Emma/prplwtf](https://github.com/prplwtf)
-   Slate from [Emma/prplwtf](https://github.com/prplwtf)
-   Modpackinstaller for Blueprint (with the need of running the queue worker)

###
Kinda explanation on how to setup [Blueprint](https://blueprint.zip/docs/?page=getting-started/Installation) on Unraid using the IBRACORP container

### installing 
got in the container and execute 
-  `microdnf install -y wget`
-  `wget https://raw.githubusercontent.com/gameguys919/unraidark/refs/heads/main/bpinstall.sh`
-  `chmod +x bpinstall.sh`
-  `./bpinstall.sh`
if its asking to put the panel into maintainance just enter `Y` and its done basically 
