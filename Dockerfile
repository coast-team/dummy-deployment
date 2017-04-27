FROM quentinlc/ubuntu-xenial-lxc

MAINTAINER Quentin Laporte-Chabasse

# Dependencies
RUN apt-get -y update && apt-get install -y \
    unzip \
    curl \
    default-jre \
    xvfb \
    fonts-ipafont-gothic \
    xfonts-100dpi \
    xfonts-75dpi \
    xfonts-scalable \
    xfonts-cyrillic \
    python3-pip \
    ntp \
    git

RUN pip3 install --upgrade pip

# Dummy's sources
RUN git clone https://github.com/coast-team/dummy /home/dummy

# Python dependencies
RUN pip3 install -r /home/dummy/requirements.txt

# Install Chrome
RUN curl https://dl-ssl.google.com/linux/linux_signing_key.pub -o /tmp/google.pub
RUN cat /tmp/google.pub | apt-key add -; rm /tmp/google.pub
RUN echo 'deb http://dl.google.com/linux/chrome/deb/ stable main' > /etc/apt/sources.list.d/google.list
RUN mkdir -p /usr/share/desktop-directories
RUN apt-get -y update && apt-get install -y google-chrome-stable

# Install Chrome Driver
RUN curl https://chromedriver.storage.googleapis.com/2.29/chromedriver_linux64.zip -o /home/dummy/chromedriver_linux64.zip
RUN unzip /home/dummy/chromedriver_linux64.zip -d /home/dummy/
RUN rm -rf /home/dummy/chromedriver_linux64.zip

# Copy Launch script
COPY scripts/entrypoint /home/entrypoint
RUN chmod 0755 /home/dummy/main.py

# Copy Sync Clock script
COPY scripts/sync_clock.sh /home/sync_clock.sh
RUN chmod 0755 /home/sync_clock.sh


#################################################################################
# Grid5000 configuration
# (comment this section if the application is not supposed to be executed on g5k)
#################################################################################

# Add custom rc.local file in order to launch ntp deamon
COPY scripts/rc.local /etc/
RUN chmod 755 /etc/rc.local

# Importation of DNS configuration in home folder
COPY scripts/resolv.conf /home/

# Importation of useful files in order to daemonize application
COPY scripts/dummy /etc/init.d/
RUN chmod 0755 /etc/init.d/dummy

# Daemons must work in background
RUN rm /lib/init/init-d-script
COPY scripts/init-d-script /lib/init/

EXPOSE 8000
CMD ["sh", "/home/entrypoint"]
