FROM ubuntu:latest
RUN apt-get update && apt-get install -y curl
COPY nix-install/nix /tmp/nix
RUN sh /tmp/nix install linux \
           --extra-conf "sandbox = false" \
           --init none \
           --no-confirm && \
      rm /tmp/nix
ENV PATH="${PATH}:/nix/var/nix/profiles/default/bin"
RUN nix run nixpkgs#hello
