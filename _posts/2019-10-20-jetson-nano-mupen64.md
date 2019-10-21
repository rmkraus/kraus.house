---
layout: post
title:  "Installing Mupen64 on the Jetson Nano"
date:   2019-10-20 16:00:00 +0500
categories: [linux, gaming]
---

The Jetson Nano is a pretty powerful device for an ARM based SOC. That being said, support in the way of pre-compiled packages can be pretty minimal outside of machine learning libraries. This post covers how to get Mupen64 working on a Jetson Nano.

I'll be working from one of NVIDIA's Ubuntu builds.

SDL Libraries
-------------

First and foremost, the SDL libraries that come compiled from the repos are terrible. You'll need to rip them out and compile your own using the source for a newer Ubuntu release. We'll use the Disco Dingo packages instead of the Bionic packages.

  1. Remove the SDL libraries from the repos.
  ``` bash
  sudo apt-get remove 'libsdl*'
  ```
  2. Install the SDL library dependencies
  ```bash
  sudo apt-get install \
    devscripts build-essential fakeroot \
    fcitx-libs-dev libvulkan-dev \
    libsamplerate0-dev wayland-protocols doxygen
  ```
  3. Download the latest source packages from launchpad. I used [libsdl 2.0.9](https://launchpad.net/ubuntu/+source/libsdl2/2.0.9+dfsg1-1ubuntu1). Download both tarballs and the dsc file into a working directory.
  4. Move into that directory and create the development directories.
  ```bash
  dpkg-source -x libsdl2_2.0.9+dfsg1-1ubuntu1.dsc
  ```
  5. Move into the new dev directory, compile the libraries, and build the deb files without signing them. Note that we are telling lintian to ignore the bad distribution errors since this SDL2 library is for another release.
  ```bash
  cd libsdl2-2.0.9+dfsg1
  debuild -b -uc -us --lintian-opts --suppress-tags bad-distribution-in-changes-file
  ```
  6. Install the deb packages.
  ```bash
  cd ..
  sudo dpkg -i \
    libsdl2-2.0-0_2.0.9+dfsg1-1ubuntu1_arm64.deb \
    libsdl2-dev_2.0.9+dfsg1-1ubuntu1_arm64.deb
  ```

PySDL2
------
This Python module is required for the Mupen64Plus Python UI. For this, we can use the packages from the Ubuntu repos.
```bash
sudo apt-get install python-sdl2
```

Mupen64Plus Core
----------------
  1. Download and extract the [latest released source from GitHub](https://github.com/mupen64plus/mupen64plus-core/releases). I'm using 2.5.9.
  2. Install dependencies. Note: SDL2 is already installed.
  ```bash
  sudo apt-get install libpng-dev libfreetype6-dev
  ```
  3. Go to the Unix project. Compile and install.
  ```bash
  cd projects/unix
  make all -j 4
  sudo make install
  ```

Mupen64Plus UI Console
----------------------
This is a simple console for the Mupen emulator. Interaction is CLI based.
  1. Download and extract the [latest released source from GitHub](https://github.com/mupen64plus/mupen64plus-ui-console/releases)
  2. Go to the Unix project. Compile and install.
  ```bash
  cd projects/unix
  make all -j 4
  sudo make install
  ```

Mupen64 Video Plugin
--------------------
The video plugin is used by Mupen to render on-screen video. I'll be using glide64mk2.
1. Download and extract the [latest released source from GitHub](https://github.com/mupen64plus/mupen64plus-video-glide64mk2/releases)
2. Install dependencies.
```bash
sudo apt-get install \
libboost-dev libboost-filesystem-dev \
libboost-system-dev
```
3. Go to the Unix project. Compile and install.
```bash
cd projects/unix
make all -j 4
sudo make install
```

Mupen64Plus RSP Plugin
----------------------
I don't know what this is. I'm too lazy to look it up, but it's important. I'll be using hle.
1. Download and extract the [latest released source from GitHub](https://github.com/mupen64plus/mupen64plus-rsp-hle/releases)
2. Go to the Unix project. Compile and install.
```bash
cd projects/unix
make all -j 4
sudo make install
```

Mupen64Plus Audio Plugin
----------------------
Makes noise. People like noise. I'll be using sdl.
1. Download and extract the [latest released source from GitHub](https://github.com/mupen64plus/mupen64plus-audio-sdl/releases)
2. Go to the Unix project. Compile and install.
```bash
cd projects/unix
make all -j 4
sudo make install
```

Mupen64Plus Input Plugin
----------------------
This plugin allows user inputs to control the game. I'll be using sdl.
1. Download and extract the [latest released source from GitHub](https://github.com/mupen64plus/mupen64plus-input-sdl/releases)
2. Go to the Unix project. Compile and install.
```bash
cd projects/unix
make all -j 4
sudo make install
```

Mupen64Plus Python UI
---------------------
This is a more full featured GUI for Mupen. I'm not really using it, but the install procedure is like so.
  1. Download and extract the [latest released source from GitHub](https://github.com/mupen64plus/mupen64plus-ui-python/releases). I'm using 0.2.4.
  2. Install dependencies.
  ```bash
  sudo apt-get install \
  python-pip python-pyqt5 pyqt5-dev-tools \
  python-pyqt5.qtopengl
  ```
  3. Build and install the Python module.
  ```bash
  python setup.py build
  python setup.py install --user
  ```
  4. Add the user's local bin and lib to your search paths by adding the following lines to your `~/.bashrc` file.
  ```bash
  export PATH=~/.local/bin:$PATH
  export LD_LIBRARY_PATH=~/.loca/lib:$LD_LIBRARY_PATH
  ```

That's It
---------
You should now have a working Mupen64Plus install.
