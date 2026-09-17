
/* Start containers */

podman-compose up -d --build

/* Replace the '#' with the week number */
podman exec -it week#_student /bin/bash

/* Shutdown all of the containers */
podman-compose down
