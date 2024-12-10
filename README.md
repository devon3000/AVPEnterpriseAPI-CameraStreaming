# Vision Pro Enterprise API Main Camera Streaming #

This example project demonstrates how to access the Vision Pro main front-mounted camera using the new [Enterprise API entitlements](https://developer.apple.com/documentation/visionOS/building-spatial-experiences-for-business-apps-with-enterprise-apis) available for private apps. 

In order to demo something useful with the camera, it also livestreams the microphone and main camera to YouTube using RTMP. This functionality makes use of the excellent [HaishinKit package](https://github.com/shogo4405/HaishinKit.swift) for video streaming along with the VideoToolbox package.

This project is a testbed, used to explore different applications of the Enterprise API, and I expect to continue to develop it to support WebRTC and perhaps other forms of connectivity, as well as the ARKit functionality and perhaps other API functions.

## Building and dependencies ##
This project was built on XCode 16.1 for visionOS 2.x, using the HaishinKit version 2.0.1. *It requires a license entitlement from Apple that is locked to the bundle ID.* I've checked my license into the repo, but I can't guarantee that it will continue to be valid, as I don't entirely know how it works. Most likely you need to [obtain your own license from Apple] (https://developer.apple.com/go/?id=69613ca716fe11ef8ec848df370857f4)and update the project file to reference your own bundleID.  
