NOTE: i have quit working on this as i lost interest in trying to fully fix the new episode fetching logic and metadata grabbing. if anyone happens to find this later do not download 2.0 it was a failed apk.



# Lumina - Media Streamer & Library Manager 🎬

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue.svg)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20|%20iOS%20|%20Web-brightgreen.svg)](https://flutter.dev/multi-platform/)

A Flutter-based media streaming application that fetches streams from Premiumize using Orionoid or Torrentio and plays them. The UI is modeled after Kodi skins' list views, with potential for additional view options like poster view.


## ✨ What Makes Lumina Different?

Unlike other streaming apps such as Stremio or Syncler, Lumina is designed with a focus on simplicity, and full local control over your media library. Here's how Lumina stands out:

✅ Fully Local Metadata Storage: Unlike apps that rely on cloud services for metadata, Lumina stores all movie and show metadata locally in a folder on your device (Player_Files), making it easy to back up and restore without needing external servers.

🔄 Simkl and Trakt Integration for Watchlist Management: Unlike Stremio, Lumina uses Simkl and Trakt for managing your library, with a straightforward syncing process that pulls your movies and shows into the app automatically. This makes it so your library is customized to you. No more having a homescreen with 90% of stuff that isnt interesting to you.

🎥 Custom JustPlayer Integration: Lumina integrates with a modified version of JustPlayer, allowing for seamless tracking of playback progress, this modified version of justplayer is made to be the absolute simplest it could possibly be, good for those that are not tech savy.

🎮 Built with flutter/dart: Being wrote in flutter/dart allows this app to be modular in terms of what devices it will run on. other apps are generally only specific for 1 platform such as pc or android, Lumina will run on windows,android,ios,and even as a website/html. 
*some modifications will need to be made for these other platforms due to me hardcoding some android paths and Android intents. This change would be very simple if someone was to do it.*


## ✨ Current Features
### 📺 Media Library Management

    Fetches a Simkl watchlist or Trakt list and retrieves metadata from TMDB/TVDB.
    Stores metadata in a folder named Player_Files on the device's internal storage for easy backup.
    Note: Requires storage permissions for metadata management.

### 🔗 Stream Fetching & Playback

    Authenticates using Orionoid's API or Torrentio to fetch streaming links.
    Sends links to JustPlayer for playback on your device.

### 🎥  User Interface

    Movies Screen and TV Shows Screen displayed in a list view with posters, titles, and information.
    Mark episodes or movies as "watched" to track progress. Movies will also auto mark themselves after watching.
    Quick Navigation Bar for jumping to specific letters in your library.

### 🔍 Search Functionality

    Search your library for movies or TV shows with keyboard input or voice input.

### ⚙️ Settings

    Customize Orionoid or Torrentio search results for better more tailored files for specific qualities or languages.

### 📱 Supported Platforms

Currently tested on a ONN. Google TV 4K Pro, but should work on most Android TV devices.

Built with Flutter, Lumina theoretically supports:

    Android
    iOS
    Web
    Windows

Note: The app currently has hardcoded paths for Android. Modifications are needed for other platforms if you wanted to build for another one.

### 🛠️ Building the Project

    Set up Android Studio and Flutter.
    Run the build.ps1 file and choose either the release build or debug build.
	Note: building a release build requires creating java signing keys.

### 🚀 Setup Instructions

    Grant the app storage permissions.

    Install JustPlayer on your device.
	NOTE: this app expects specific intents that were added to my custom justplayer. these intents are for tracking play progress thus is needed: https://github.com/Spark-NV/Player

    Add your API keys to the Debrid_Player/api_keys.txt file:


    These 3 keys are required.
	    tvdb_api_key = your_key_here
        tmdb_api_key = your_key_here
	    premiumize_api_key = your_key_here
	
	Add either of these keys to the services you plan to use.
        simkl_api_key = your_key_here
	    trakt_client_id = your_key_here
	
	add this key if you plan to use orionoid.
        orion_app_key = your_key_here

	add this entry if you plan to use AIOStreams.
        AIOConfig = your_config/passwordhash_here
	
	
    Build your Simkl/Trakt library:

        Add movies/shows to your "Plan to Watch" list or "Completed" List, or if using trakt to a custom list.


    Open the app and authorize Simkl and Orionoid to get the tokens so the app can interact with the 2 services if you want to use them.
	
	Set your trakt list id and username if you are using trakt.

    Use the "Sync" button to fetch new content from your selected list.

    So the process for adding movies or shows will be you use simkl/trakt and find any movies or shows you want and add them to your list. then in Lumina you use the sync button to have it find any new movies or tvshows you added. In the settings you can set it to auto sync every day at a certain time so new episodes or new movies get added automatically.

    Note: You must link your premiumize account and orionoid account in the user panel on orionoids website.

### 🤝 Contributing

Contributions are welcome! If you'd like to improve Lumina, here are some ideas:


    Add actor searching within the preplay screen(selecting an actor would bring up all other movies/shows they are in.)

    Introduce more view options like poster view.

    Support additional debrid services.

    Add other video player options. Other options would need ways of tracking play progress.


### 📜 License

Distributed under the MIT License. See LICENSE for more information.
🙏 Acknowledgments

    Flutter Team for the amazing framework.
    Orionoid for their comprehensive media API.
    Torrentio for their Amazing Scraper API.
    Simkl and Trakt for list management.
    TMDB and TVDB for metadata.
    moneytoo for his JustPlayer

### 📌 Suggestions for improvement are welcome


# Screenshots


### Main / Home Screen
![Alt text](Screenshots/Main_Screen.png)

### Movies List
![Alt text](Screenshots/Movies_list.png)

### Selected movie Pre-Play screen
![Alt text](Screenshots/PrePlay_Screen.png)

### Search Screen
![Alt text](Screenshots/Search_Screen.png)

### Genre Search Selections
![Alt text](Screenshots/Genre_Search.png)
