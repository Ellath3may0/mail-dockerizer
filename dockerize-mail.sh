#!/bin/bash

# Install Docker
sh $(curl -fsSL https://get.docker.com)

# Create working directory
mkdir docker && cd docker

# Stop services
systemctl stop postfix dovecot

# Collect existing information and configurations
cp -r /etc/postfix        postetc
cp -r /etc/dovecot        doveetc
cp -r /var/spool/postfix  postspool
cp -r /var/mail           mail
cp -r /var/lib/dovecot    dovelib
cp    /etc/passwd         passwd
cp    /etc/group          group
cp    /etc/shadow         shadow
cp    /etc/gshadow        gshadow

# Find and copy mailboxes
mkdir home
for u in /home/*/
do
  #TODO: get mail directory from config files
  if [ -d /home/"$u"/Maildir ]; then
    echo "Copying home directory: $u"
    cp -r /home/"$u" home/"$u"
  fi
done

echo "Generating Dockerfile..."
touch Dockerfile
echo "FROM fedora:42"                               > Dockerfile
echo "WORKDIR ."                                    >> Dockerfile
echo ""                                             >> Dockerfile
echo "COPY postetc          /etc/postfix"           >> Dockerfile
echo "COPY doveetc          /etc/dovecot"           >> Dockerfile
echo "COPY postspool        /var/spool/postfix"     >> Dockerfile
echo "COPY mail             /var/mail"              >> Dockerfile
echo "COPY dovelib          /var/lib/dovecot"       >> Dockerfile
echo "COPY passwd           /etc/passwd"            >> Dockerfile
echo "COPY group            /etc/group"             >> Dockerfile
echo "COPY shadow           /etc/shadow"            >> Dockerfile
echo "COPY gshadow          /etc/gshadow"           >> Dockerfile
echo "COPY supervisord.conf /etc/supervisord.conf"  >> Dockerfile
echo ""                                             >> Dockerfile

# Copy home directories
for u in home/*/
do
  echo "COPY home/$u /home/$u" >> Dockerfile
  echo "RUN chown -R $(sed -n 's|[^:]*:[^:]*:\([0-9]*\):[^:]*:[^:]*:/home/$u:.*|\1|p' /etc/passwd):$(sed -n 's|[^:]*:[^:]*:[^:]*:\([0-9]*\):[^:]*:/home/$u:.*|\1|p' /etc/passwd) /home/$u" >> Dockerfile
  echo "RUN chmod -R 755 /home/$u" >> Dockerfile
done

# Installing packages
echo "" >> Dockerfile
echo "RUN dnf install -y postfix dovecot supervisor" >> Dockerfile
echo "RUN dnf clean all"                  >> Dockerfile
echo ""                                   >> Dockerfile

# Command line
echo "CMD [\"/usr/bin/supervisord\", \"-n\", \"-c\", \"/etc/supervisord.conf\"]" >> Dockerfile
echo "Dockerfile generated"

# build image
echo "Building image..."
docker build -t mail .

# Generate docker compose file
echo "Generating Docker Compose file..."
touch docker-compose.yaml
echo "services:"                > docker-compose.yaml
echo "  mail:"                  >> docker-compose.yaml
echo "    image: mail:latest"   >> docker-compose.yaml
echo "    pull_policy: never"   >> docker-compose.yaml
echo "     network_mode: host"  >> docker-compose.yaml
#echo "    ports:"               >> docker-compose.yaml
#echo "      - \"143:143\""      >> docker-compose.yaml
#echo "      - \"587:587\""      >> docker-compose.yaml
#echo "      - \"25:25\""        >> docker-compose.yaml
#echo "      - \"110:110\""      >> docker-compose.yaml
echo "Docker Compose file generated"

docker compose up