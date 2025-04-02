---
date: "2025-01-20"
draft: false
title: '"Inspect element" saving lives'
tags: ["browser", "javascript"]
---

Today, while trying to request an online service from my city, I accidentally entered one of the required data incorrectly. The problem was that the website wouldn't allow me to manually correct it, because the HTML `input` field was disabled. This made it impossible to continue the entire process, as the validation would always fail.

In this case, a normal person would probably be forced to file a complaint to try to resolve the issue, but I couldn't stop there.

Not satisfied, I opened the browser's developer tools and checked what the site was doing while I was trying to request the service. I noticed that all communications with the API were made with a simple XHR request, where the data I filled in was copied to the request body.

So, I figured I could simply remove the `disabled` attribute from the `input` tag, correct the information, and try again.

To my surprise, it worked perfectly.
