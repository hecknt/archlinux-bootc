# Arch Linux Bootc

Reference [Arch Linux](https://archlinux.org/) container image preconfigured for [bootc](https://github.com/bootc-dev/bootc) usage, based off the work done by [bootcrew](https://github.com/bootcrew). It differentiates itself by using the Arch Linux bootstrap tarball instead of the docker image as its base.

## Why not use the Arch Linux docker image as a base?

This image exists because I have a few issues with the [Arch Linux Docker Image](https://hub.docker.com/r/archlinux/archlinux) for use as a bootable OS. Here's a small list of things that are rather counter intuitive for a non-docker installation:

- Disables extracts of a [lot of directories](https://gitlab.archlinux.org/archlinux/archlinux-docker/-/blob/master/pacman-conf.d-noextract.conf?ref_type=heads)
- Disables the sandbox of pacman for docker purposes
- Sets a user for downloads (why? I genuinely have no idea why they do this)
- Enables the `NoProgressBar` option in pacman.conf, which as described, disables the progress bar

For the reasons listed above, I have decided to build this image off of the Arch Linux bootstrap tarball. This is also listed as a [valid installation method](https://wiki.archlinux.org/title/Install_Arch_Linux_from_existing_Linux#Creating_a_chroot) on the [Arch Linux wiki](https://wiki.archlinux.org). The tarball is nothing more than a base Arch Linux system, which is perfect for our needs.

## Building

In order to get a running arch-bootc system you can run the following steps:
```shell
just build-containerfile # This will build the containerfile and all the dependencies you need
just generate-bootable-image # Generates a bootable image for you using bootc!
```

Then you can run the `bootable.img` as your boot disk in your preferred hypervisor.
