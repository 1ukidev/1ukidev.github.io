---
date: "2025-07-29"
draft: false
title: "Debugging ActionScript in Emacs"
tags: ["emacs", "actionscript"]
---

Thanks to the [vscode-swf-debug](https://github.com/BowlerHatLLC/vscode-swf-debug) project and the [dap-mode](https://github.com/emacs-lsp/dap-mode) extension, I discovered that it's possible to debug `.swf` files in Emacs.

The communication with `dap-mode` is straightforward - the Java module `swf-debug-adapter` from `vscode-swf-debug` handles the DAP server, and from there you just need to integrate it with the extension.

```elisp
;;; dap-as3.el --- DAP mode for ActionScript -*- lexical-binding: t; -*-

(require 'dap-mode)

(defcustom dap-swf-adapter-jar
  ""
  "Path to the swf-debug-adapter jar file.
Example:
  /home/user/vscode-swf-debug/swf-debug-adapter/target/swf-debug-adapter.jar"
  :type 'string
  :group 'dap-mode)

(defcustom dap-swf-runtime-executable
  ""
  "Path to the SWF runtime executable (adl).
Example:
  /home/user/airsdk/bin/adl"
  :type 'string
  :group 'dap-mode)

(defun dap-swf-start-adapter-command (port)
  (format "java -jar %s --server=%d" dap-swf-adapter-jar port))

(defun dap-as3--populate-start-args (conf)
  (let ((port (dap--find-available-port)))
    (-> conf
        (dap--put-if-absent :program-to-start (dap-swf-start-adapter-command port))
        (dap--put-if-absent :type "swf")
        (dap--put-if-absent :debugServer port)
        (dap--put-if-absent :profile "desktop")
        (dap--put-if-absent :request "launch")
        (dap--put-if-absent :runtimeExecutable dap-swf-runtime-executable)
        (dap--put-if-absent :name "SWF Debug"))))

(dap-register-debug-provider "as3" #'dap-as3--populate-start-args)

(provide 'dap-as3)
```

Now just define the `dap-swf-adapter-jar` and `dap-swf-runtime-executable` variables, and we're ready to create a debug configuration:

```elisp
(dap-register-debug-template
 "Debug example"
 (list :type "as3"
       :name "example"
       :program "/home/user/as3-example/bin-debug/example-app.xml"))
```
