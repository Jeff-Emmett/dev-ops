;; manifest.scm — the dev toolchain, as a reproducible set.
;;
;;   ephemeral shell with these tools:   guix shell -m manifest.scm
;;   install into a named profile:        guix package -m manifest.scm
;;
;; Pair with channels.scm + `guix time-machine` for a bit-identical toolchain
;; on any machine.

(specifications->manifest
 '("git" "git:send-email"
   "ripgrep" "fd" "fzf" "jq" "curl"
   "node" "python" "gcc-toolchain" "make"
   "docker-cli" "qemu"))
