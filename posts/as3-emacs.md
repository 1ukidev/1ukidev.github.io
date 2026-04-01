---
date: "2025-07-29"
draft: false
title: "Depurando ActionScript no Emacs"
tags: ["emacs", "actionscript"]
---

Graças ao projeto [vscode-swf-debug](https://github.com/BowlerHatLLC/vscode-swf-debug) e a extensão [dap-mode](https://github.com/emacs-lsp/dap-mode), descobri que é possível depurar `.swf` no Emacs.

A comunicação com o `dap-mode` é simples - o módulo Java `swf-debug-adapter` do `vscode-swf-debug` cuidará do servidor DAP, a partir daí basta integrar com a extensão.

```elisp
;;; dap-as3.el --- DAP mode for ActionScript -*- lexical-binding: t; -*-

(require 'dap-mode)

(defcustom dap-swf-adapter-jar
  ""
  "Caminho do arquivo jar do swf-debug-adapter.
Exemplo:
  /home/user/vscode-swf-debug/swf-debug-adapter/target/swf-debug-adapter.jar"
  :type 'string
  :group 'dap-mode)

(defcustom dap-swf-runtime-executable
  ""
  "Caminho do executável do runtime do SWF (adl).
Exemplo:
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

Agora só definir as variáveis `dap-swf-adapter-jar` e `dap-swf-runtime-executable`, e estamos pronto para criar uma configuração de depuração:

```elisp
(dap-register-debug-template
 "Debug example"
 (list :type "as3"
       :name "example"
       :program "/home/user/as3-example/bin-debug/example-app.xml"))
```
