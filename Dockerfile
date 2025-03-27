FROM ubuntu:latest
RUN apt-get update && apt-get install -y curl
COPY nix-install/nix /tmp/nix
RUN sh /tmp/nix install linux \
           --extra-conf "sandbox = false" \
           --init none \
           --no-confirm && \
      rm /tmp/nix && \
      apt-get remove -y curl
ENV PATH="${PATH}:/nix/var/nix/profiles/default/bin"
COPY . /code
WORKDIR /code
