---
date: "2025-05-12"
draft: false
title: "mitmproxy, but on Android"
tags: ["mitmproxy", "android"]
---

Mitmproxy has always been extremely helpful when I needed an HTTPS proxy that would allow me to monitor network traffic with more freedom. Last week, while trying to monitor an application on Android, I discovered an interesting open-source tool that made the entire process possible directly on the device, with very little configuration: [PCAPdroid](https://github.com/emanuele-f/PCAPdroid). Monitoring and decrypting network traffic with just a few clicks was truly satisfying.

## Installation
It can be easily installed through the Play Store, F-Droid, or the APK from its GitHub page. The choice is yours.

![img](./f-droid.png#small)

## Main screen
Here we can choose which apps will be monitored and decide if we want to dump the traffic to a specific location. By default, the app will create a VPN to establish the proxy connection, but it's also possible to activate a transparent connection in the settings, which would require root access.

![img](./start.png#small)

## Activating mitmproxy
In the settings, you'll find an option to enable TLS decryption. The app provides a very educational guide about what needs to be done. You'll install an addon with mitmproxy and a CA certificate in the system.

![img](./option.png#small)

## Targeting specific apps
In the left menu, under "Decryption rules", you can select which apps will have their traffic decrypted, as well as use other criteria such as a specific host, IP, or even a country.

![img](./menu.png#small)

## Testing
Just click "Ready" and all established connections will be properly listed in the "Connections" tab. Here I'm using F-Droid as an example.

![img](./connections.png#small)

Those with a green open padlock mean they were successfully decrypted. When you click on one...

![img](./http.png#small)

Voilà! The requests are right in the palm of your hand.

## Final considerations
Despite having installed the certificate on Android, unfortunately not all applications will allow you to use it with mitmproxy due to SSL pinning. Fortunately, there's a tool called [apk-mitm](https://github.com/niklashigi/apk-mitm) that attempts to fix these blocks directly in the APK files. It's not 100% guaranteed to work, but in my tests, it has performed well. After installing the tool, the process is as simple as:

```bash
$ apk-mitm file.apk
```

Well, it's worth a try. Here's a tip.
