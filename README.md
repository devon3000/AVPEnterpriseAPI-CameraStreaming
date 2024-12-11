# Vision Pro Enterprise API Main Camera Streaming #
<img width="600" alt="Screenshot 2024-12-09 at 7 20 49 PM" src="https://github.com/user-attachments/assets/7f968cb4-f3cd-4c28-a48c-0cda82b17e0b">

This example project demonstrates how to access the Vision Pro main front-mounted camera using the new [Enterprise API entitlements](https://developer.apple.com/documentation/visionOS/building-spatial-experiences-for-business-apps-with-enterprise-apis) available for private apps. 

In order to demo something useful with the camera, it also livestreams the microphone and main camera to YouTube using RTMP. This functionality makes use of the excellent [HaishinKit package](https://github.com/shogo4405/HaishinKit.swift) for video streaming along with the VideoToolbox package for h264 encoding of the raw camera frames.

This project is a testbed, used to explore different applications of the Enterprise API, and I expect to continue to develop it to support WebRTC and perhaps other forms of connectivity, as well as the ARKit functionality and perhaps other API functions.

## Setup ##
This project was built on XCode 16.1 for visionOS 2.x, using the HaishinKit version 2.0.1. *It requires a license entitlement from Apple that is locked to the bundle ID.* I've checked my license into the repo, but I can't guarantee that it will continue to be valid, as I don't entirely know how it works. Most likely you need to [obtain your own license from Apple](https://developer.apple.com/go/?id=69613ca716fe11ef8ec848df370857f4) and update the project file to reference your own bundleID. Also you need a physical Vision Pro to run this app - it won't run on the simulator since there's no main camera available there.

## Building ##
- Check out the code
- Open avpenterprisetest.xcodeproj in Xcode
- Update streamKey in YouTubeStreamManager to your own YouTube stream key
- Connect your Vision Pro to your Mac
- Build and Run

## Operation ##
As of this writing:
- Click "Show Immersive Space" to activate ARKit
- Click "Test Camera" to start the main camera feed (you should see it appear in the UX window)
- Click "Start Streaming" to begin streaming live to YouTube. It'll take about 10 seconds for the stream to appear on the YouTube console.

## License ##
This code is licensed under the MIT open source license and is free and unencumbered for all uses personal and commercial. Please note the terms of the dependencies (especially HaishinKit).

