;; channels.scm — the pinned package universe for the whole env.
;;
;; nonguix  = mainline Linux kernel + firmware + (eventually) NVIDIA. Required
;;            for real hardware; Guix's default Linux-libre has no proprietary
;;            drivers.
;; jmjmj    = your forge pantheon channel (see ./jmjmj-channel). Add it here once
;;            it lives in its own Gitea repo; until then use `guix ... -L`.
;;
;; PIN FOR REPRODUCIBILITY after the first `guix pull`:
;;   guix describe -f channels > channels.scm
;; That stamps exact commit hashes → `guix time-machine -C channels.scm` then
;; replays a bit-identical world on any machine.

(list
 (channel
  (name 'guix)
  (url "https://git.savannah.gnu.org/git/guix.git")
  (branch "master")
  ;; (commit "PIN-ME")          ; fill via `guix describe -f channels`
  (introduction
   (make-channel-introduction
    "9edb3f66fd807b096b48283debdcddccfea34bad"
    (openpgp-fingerprint
     "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))
 (channel
  (name 'nonguix)
  (url "https://gitlab.com/nonguix/nonguix")
  (branch "master")
  ;; (commit "PIN-ME")
  (introduction
   (make-channel-introduction
    "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
    (openpgp-fingerprint
     "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5")))))
