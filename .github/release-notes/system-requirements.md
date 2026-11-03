## System requirements

| Platform | Minimum |
| --- | --- |
| Windows | Windows 10 version 1809 (LTSC 2019) or later |
| Linux | glibc 2.38 or later (Debian 13, Ubuntu 24.04 or later) |

**Windows:** entries are rendered with Microsoft Edge WebView2. Windows 11 and
most Windows 10 installations already have the Evergreen Runtime through Edge
updates; Windows 10 LTSC and images without Edge do not, and need it installed
from <https://go.microsoft.com/fwlink/p/?LinkId=2124703> before the first
launch. Ciyue checks for it at startup and shows a prompt when it is missing.

**Linux:** the bundle ships its own WebKit, which requires glibc 2.38. Debian 12
(glibc 2.36) and Ubuntu 22.04 (glibc 2.35) cannot load it.
