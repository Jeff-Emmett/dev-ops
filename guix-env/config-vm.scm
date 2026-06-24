;; config-vm.scm — desktop config for fast QEMU iteration (Phase 2).
;;
;; Differs from config.scm ONLY by using the stock linux-libre kernel instead
;; of the nonguix mainline kernel: inside QEMU all drivers are virtio (in-tree),
;; so no proprietary firmware is needed and nonguix can be skipped entirely.
;; config.scm (with nonguix) remains the bare-metal target.
;;
;;   build + launch in KVM:   guix system vm config-vm.scm   (prints a run script)
;;   validate only:           guix system build config-vm.scm

(use-modules (gnu))
(use-service-modules desktop networking ssh xorg)   ; xorg = gdm-service-type
(use-package-modules nss ssh version-control)   ; nss-certs lives in (gnu packages nss)

(operating-system
  (host-name "guixvm")
  (timezone "Etc/UTC")
  (locale "en_US.utf8")
  (keyboard-layout (keyboard-layout "us"))

  ;; stock kernel — fine in QEMU (virtio).
  (bootloader (bootloader-configuration
               (bootloader grub-bootloader)
               (targets (list "/dev/vda"))
               (keyboard-layout keyboard-layout)))

  (file-systems (cons (file-system
                        (mount-point "/")
                        (device (file-system-label "guix-root"))
                        (type "ext4"))
                      %base-file-systems))

  (users (cons* (user-account
                  (name "jeff")
                  (comment "Jeff Emmett")
                  (group "users")
                  (home-directory "/home/jeff")
                  (supplementary-groups
                   '("wheel" "netdev" "audio" "video")))
                %base-user-accounts))

  (packages (append (list git openssh nss-certs)
                    %base-packages))

  ;; GNOME + auto-login as jeff (VM convenience — no password prompt on boot).
  (services
   (cons* (service gnome-desktop-service-type)
          (service openssh-service-type)
          (modify-services %desktop-services
            (gdm-service-type config =>
                              (gdm-configuration
                               (inherit config)
                               (auto-login? #t)
                               (default-user "jeff")))))))
