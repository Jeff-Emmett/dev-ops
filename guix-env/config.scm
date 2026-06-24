;; config.scm — Guix System: portable desktop daily-driver.
;;
;;   iterate in QEMU (shares host store, fast loop):
;;       guix system vm config.scm
;;   build a standalone portable VM image:
;;       guix system image -t qcow2 config.scm
;;   go bare-metal once it's the desktop you want:
;;       sudo guix system reconfigure config.scm
;;   dry-run / validate without applying:
;;       guix system build config.scm
;;
;; SET BEFORE BARE-METAL (marked CHANGE): host-name, timezone, user,
;; and the real root file-system UUID. The file-system-label defaults
;; below are correct for `guix system image`.

(use-modules (gnu)
             (nongnu packages linux)         ; mainline kernel + firmware
             (nongnu system linux-initrd))

(use-service-modules desktop networking ssh xorg)
(use-package-modules nss ssh version-control)   ; nss-certs lives in (gnu packages nss)

(operating-system
  (host-name "guixtop")                       ; CHANGE
  (timezone "Etc/UTC")                         ; CHANGE e.g. "America/Toronto"
  (locale "en_US.utf8")
  (keyboard-layout (keyboard-layout "us"))

  ;; nonguix mainline kernel + firmware = working Wi-Fi / GPU / hardware.
  (kernel linux)
  (initrd microcode-initrd)
  (firmware (list linux-firmware))

  (bootloader (bootloader-configuration
               (bootloader grub-efi-bootloader)
               (targets (list "/boot/efi"))
               (keyboard-layout keyboard-layout)))

  ;; VM/default layout. For bare-metal replace the root device with:
  ;;   (device (uuid "xxxxxxxx-...." 'ext4))
  (file-systems (cons* (file-system
                         (mount-point "/")
                         (device (file-system-label "guix-root"))
                         (type "ext4"))
                       (file-system
                         (mount-point "/boot/efi")
                         (device (file-system-label "GNU-ESP"))
                         (type "vfat"))
                       %base-file-systems))

  (users (cons* (user-account
                  (name "jeff")              ; CHANGE
                  (comment "Jeff Emmett")
                  (group "users")
                  (home-directory "/home/jeff")
                  (supplementary-groups
                   '("wheel" "netdev" "audio" "video")))
                %base-user-accounts))

  (packages (append (list git openssh nss-certs)
                    %base-packages))

  ;; GNOME for first-boot reliability. Lean alternative: drop the gnome
  ;; service and add `sway` to packages for a tiling Wayland session.
  (services (append
             (list (service gnome-desktop-service-type)
                   (service openssh-service-type)
                   (set-xorg-configuration
                    (xorg-configuration
                     (keyboard-layout keyboard-layout))))
             %desktop-services)))
