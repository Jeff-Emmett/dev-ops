;; home.scm — Guix Home: the portable USER environment.
;;
;; The big win: this works on Guix System AND on any foreign distro,
;; INCLUDING WSL2. So you can carry your shell/editor/tools to the
;; current box today, before committing to full Guix System:
;;
;;   guix home reconfigure home.scm
;;
;; It manages dotfiles declaratively and rolls back like the system does.

(use-modules (gnu home)
             (gnu home services shells)
             (gnu services)
             (gnu packages)
             (guix gexp))            ; plain-file, local-file, etc.

(home-environment
 (packages
  ;; NOTE: pkg:output syntax (e.g. "git:send-email") is NOT valid here —
  ;; specification->package can't return a package output. Use manifest.scm
  ;; (specifications->manifest) when you need outputs.
  (map specification->package
       '("git"
         "ripgrep" "fd" "fzf" "tmux" "neovim"
         "curl" "jq" "htop" "tree" "openssh")))
 (services
  (list
   (service home-bash-service-type
            (home-bash-configuration
             (aliases
              '(("ll" . "ls -alF")
                ("gs" . "git status")
                ("gd" . "git diff")))
             (bashrc
              (list (plain-file "bashrc-extra"
                                "export EDITOR=nvim\n"))))))))
