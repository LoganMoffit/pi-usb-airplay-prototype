# Pi USB AirPlay -> Fake Thumb Drive Prototype

This is a **hacky prototype** for Raspberry Pi Zero/Zero 2 W:

- Pi receives AirPlay audio via `shairport-sync` (pipe backend)
- A script encodes that stream into rolling MP3 files
- Pi also presents a USB Mass Storage gadget to your amp (looks like a thumb drive)

It is meant to test whether your amp firmware can handle changing files while playing.

## Quick install (after repo is on GitHub)

SSH into Pi and run:

```bash
git clone <REPO_URL> ~/pi-usb-airplay-prototype
bash ~/pi-usb-airplay-prototype/install.sh
sudo reboot
```

After reboot:

```bash
sudo ~/pi-usb-airplay-prototype/scripts/setup_usb_gadget.sh start
~/pi-usb-airplay-prototype/scripts/airplay_to_usb.sh
```

Or use bootstrap helper:

```bash
bash -c "$(curl -fsSL <RAW_BOOTSTRAP_URL>)" -- <REPO_URL>
```

## Important limits

- This is not true USB Audio Class streaming.
- Many USB-player chipsets cache directory entries and do not track updates reliably.
- Expect latency, occasional stutter, and possible rescan issues.
- This can corrupt the image if power is cut during writes. Keep backups.

## Hardware assumptions

- Raspberry Pi Zero/Zero 2 W (USB **device/gadget** capable)
- Use the Pi data-capable micro-USB OTG port to the amp USB slot

## Manual setup

### 1) Install packages

```bash
sudo apt update
sudo apt install -y ffmpeg dosfstools util-linux
```

(`shairport-sync` is assumed installed separately.)

### 2) Enable gadget support (if not already)

Add to `/boot/firmware/config.txt` (or `/boot/config.txt` on older images):

```ini
dtoverlay=dwc2
```

Add to `/boot/firmware/cmdline.txt` (single line) after `rootwait`:

```txt
modules-load=dwc2
```

Reboot.

### 3) Create a FAT image and mount it

```bash
cd ~/pi-usb-airplay-prototype
./scripts/create_usb_image.sh
```

This creates:

- image: `/home/pi/usb-amp/amp-drive.img`
- mountpoint: `/mnt/amp-drive`

### 4) Start USB gadget mode

```bash
sudo ~/pi-usb-airplay-prototype/scripts/setup_usb_gadget.sh start
```

Stop with:

```bash
sudo ~/pi-usb-airplay-prototype/scripts/setup_usb_gadget.sh stop
```

### 5) Configure shairport-sync pipe backend

Copy snippet:

```bash
sudo cp ~/pi-usb-airplay-prototype/config/shairport-sync-pipe.conf /etc/shairport-sync/conf.d/pipe.conf
sudo systemctl restart shairport-sync
```

If your distro doesn't use `conf.d`, merge the snippet into `/etc/shairport-sync.conf`.

### 6) Start MP3 segment writer

```bash
~/pi-usb-airplay-prototype/scripts/airplay_to_usb.sh
```

It writes rolling files such as:

- `/mnt/amp-drive/AIRPLAY/seg-0001.mp3`
- updates `NOWPLAY.TXT` with latest segment info

### 7) Test behavior on amp

1. Plug Pi OTG USB into amp USB port.
2. Select USB source on amp.
3. Start AirPlay playback from phone/computer.
4. Watch if amp discovers/plays rolling `seg-XXXX.mp3` files.

## Quick diagnostics

Check files changing:

```bash
ls -l /mnt/amp-drive/AIRPLAY | tail
cat /mnt/amp-drive/NOWPLAY.TXT
```

If amp never notices updates, try unplug/replug or stop/start gadget to force rescan:

```bash
sudo ~/pi-usb-airplay-prototype/scripts/setup_usb_gadget.sh stop
sudo ~/pi-usb-airplay-prototype/scripts/setup_usb_gadget.sh start
```

## Rollback / cleanup

```bash
sudo ~/pi-usb-airplay-prototype/scripts/setup_usb_gadget.sh stop || true
sudo umount /mnt/amp-drive || true
```

Remove the project directory when done.
