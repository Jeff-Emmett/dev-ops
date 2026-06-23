;; jmjmj/packages/forge.scm
;;
;; The JMJMJ Pantheon engine toolchain, expressed as Guix.
;;
;; WHY THIS EXISTS: the forge pantheon dispatches morph-paths across system
;; engines (graphviz, inkscape, ghostscript, plantuml, d2, vega, scribus, ...).
;; Packaging them here makes each engine a /gnu/store derivation addressed by a
;; cryptographic hash — the OS-level mirror of your KOI content-addressed
;; bundles. Two payoffs:
;;
;;   1. `guix challenge jmjmj-forge-toolchain` — independent build farms rebuild
;;      and prove the binaries match bit-for-bit. Tamper-evident engine supply
;;      chain (relevant to payment-forge value-routing provenance).
;;   2. No more "which version of inkscape/ghostscript built this artifact" or
;;      env-ordering bugs (cf. the libheif/pyvips first-import-wins class) — the
;;      toolchain is one pinned, reproducible closure.
;;
;; This metapackage is the SKELETON: start with the three engines below, then
;; grow it to cover the full pantheon registration contract (form.ts builtinForms
;; + forge-engine.ts formExt-map).

(define-module (jmjmj packages forge)
  #:use-module (guix packages)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages graphviz)
  #:use-module (gnu packages inkscape)
  #:use-module (gnu packages ghostscript)
  #:export (jmjmj-forge-toolchain))

(define-public jmjmj-forge-toolchain
  (package
    (name "jmjmj-forge-toolchain")
    (version "0.1.0")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list #:builder #~(begin (mkdir #$output) #t)))
    ;; Propagated so installing the metapackage pulls the whole pantheon closure.
    ;; Add engines here as you migrate them: plantuml, d2, scribus, vega tools...
    (propagated-inputs
     (list graphviz
           inkscape
           ghostscript))
    (synopsis "JMJMJ Pantheon forge engine toolchain (reproducible)")
    (description
     "Content-addressed, channel-pinned bundle of the system engines the JMJMJ
forge pantheon dispatches to.  Each engine is a @file{/gnu/store} derivation
verifiable via @command{guix challenge}, giving the morph-path fleet a
tamper-evident, drift-free toolchain.")
    (home-page "https://rspace.online")
    (license license:agpl3+)))
