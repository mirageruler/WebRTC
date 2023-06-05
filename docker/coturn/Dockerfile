FROM coturn/coturn:latest

# Switch to root user to install dependencies
USER root

# Install any additional dependencies or packages here, if needed
RUN apt-get update && apt-get install -y sudo && \
    adduser --disabled-password --gecos '' myuser && \
    adduser myuser sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Switch to the non-root user
USER myuser

# Install vim
RUN sudo apt-get update && sudo apt-get install -y curl vim

# Copy any configuration files or scripts that you want to add to the image
COPY turnserver.conf /etc/

# Expose the default TURN server ports
EXPOSE 3478/tcp 3478/udp 5349/tcp 5349/udp

# # Start the TURN server when the container starts
# CMD ["turnserver"]
