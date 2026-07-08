# GSP: Garrysmod Sound Player

![Garry's Mod](https://img.shields.io/badge/Garry's%20Mod-GLua-blue)
![React](https://img.shields.io/badge/UI-React.js-61DAFB?logo=react&logoColor=black)
![Tailwind](https://img.shields.io/badge/Style-Tailwind%20CSS-38B2AC?logo=tailwind-css&logoColor=white)

**A modern, React-based audio streaming system that completely redefines the listening experience on Garry's Mod servers.**

> **Available on Steam Workshop!**
> This repository contains the source code for the project. If you are a server owner or player looking to install this on your server, please subscribe directly via the Steam Workshop:
> **[Download GSP on Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3751627187)**

---

## About The Project

GSP is an advanced audio manager built to bridge the gap between traditional GLua server mechanics and modern web interfaces. As a server owner or admin, you can broadcast music globally. However, if a player prefers a different vibe, they can instantly mute the global stream and play their own local music instead—vastly improving player retention and comfort.

**NO CHROMIUM REQUIRED!** Unlike many media players on the Workshop, GSP is fully compatible with the standard, stable version of Garry's Mod.

## The "Killer Feature": Absolute Local Audio Control

Tired of server DJs blasting music you don't like? Are your players leaving because of mic-spamming or audio trolling?

If a server admin or DJ starts a global track, any player can instantly mute that global stream through their `!GSP` menu and replace it with their own local audio track or URL. Maintain immersion, eliminate complaints, and enjoy the gameplay without lowering the master game volume.

## Core Features

* **Modern React & Tailwind UI:** Completely asynchronous web-rendered interface. ZERO FPS drops or client-side stuttering when opening or interacting with the menu.
* **Dual Audio Engine:** Supports both local file playback (`sound/GSP/*.mp3`) and remote URLs using GMod's native audio and a custom hidden DHTML player. *(Note: YouTube URLs are not natively supported out of the box).*
* **Advanced Permissions (`!GSP_admin`):** A dedicated standalone rank management window. Easily assign "DJ" roles or designate Manager (MGR) ranks who can assign/revoke permissions for other groups in real-time.
* **Network Optimized (No FastDL Clutter):** Streams directly via URL or leverages clean, workshop-mounted music packs. Drastically reduces joining times by eliminating huge, mandatory `.mp3` downloads.
* **Garbage Collection Safe:** Engineered to maintain persistent variable references for BASS audio handles, entirely preventing random song cut-offs mid-track.
* **Multilingual Support:** Full, on-the-fly interface translation supporting English, Polish, French, Russian, Spanish, and German.

---

## Commands

| Command | Description | Access |
| :--- | :--- | :--- |
| `!GSP` | Opens the main player interface. | All Players |
| `!GSP_admin` | Opens the permission and rank management system. | SuperAdmins & MGRs |

---

## Creating Custom Music Packs

You can easily package and upload your own custom music packs to the Steam Workshop for your server. To help developers get started, refer to our official resources:

* **[GSP: Official Music Template (Content Pack Base)](https://steamcommunity.com/sharedfiles/filedetails/?id=3751630070)** - *Official, pre-structured template pack.*
* **[Beginner Friendly Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3749282153)** - *Explains folder setups, GMod naming rules, and how to use batch renaming scripts.*
* **[Advanced Tech Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3749273478)** - *Technical reference sheet for experienced server technicians.*

*(Note: Please replace the `#` links above with your actual guide URLs if hosted externally).*

---

## Support & Feedback

If you encounter a bug, have feature requests, or need help integrating GSP into your server, please leave a comment on the **[Steam Workshop Page](https://steamcommunity.com/sharedfiles/filedetails/?id=3751627187)**. 

**If you enjoy this project, please consider leaving a Rating and Favorite on the Steam Workshop to help others find it!**
