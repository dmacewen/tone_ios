# Tone iOS App

## Tone Overview
Tone is a project that aims to address the challenge of getting an accurate foundation makeup match. The current best method for getting accurately matching foundation makeup is to go to a brick and mortar store and try on different shades. Making matters worse, skin tone and skin needs change throughout the year for many people which means the user will often need to go back to the store if their skin changes. 

Tone works to address the core issues by measuring the users skin tone with a mobile app and match them to the best foundation makeup for their needs.

## Tone Projects
|Repo | |
|---|---|
| [Tone Color Match](https://github.com/dmacewen/tone_colorMatch) | Primary image processing pipeline. Takes a set of images of the users face (taken by the iOS app) and records the processed colors to the database |
| [Tone iOS App (This Repo)](https://github.com/dmacewen/tone_ios) | Guides the user through capturing the images, preprocesses them, and sends them to the server |
| [Tone Server](https://github.com/dmacewen/tone_server) | RESTful API handling user data, authentication, and beta testing information. Receives images from the iOS app and starts color measuring jobs |
| [Tone Spectrum](https://github.com/dmacewen/tone_spectrum) | A deep dive into [metamerism](https://en.wikipedia.org/wiki/Metamerism_(color)) as a potential source of error for Tone in its current form |
| [Tone Database](https://github.com/dmacewen/tone_database) | SQL |
| [Tone SQS](https://github.com/dmacewen/tone_sqs) | Command line utility for sending SQS messages to the Color Match worker. Good for running updated Color Match versions on old captures |

## Tone iOS Overview

The primary goal of the iOS app is to capture a set of photos under specific conditions and upload them to the server. An additional goal is to make beta testing easy for the volunteers and to test different UX and UI.

The image capture portion of the app happens in a number of steps:
1. The user sees a live video of themselves. This helps them line up the image
2. A series of prompts are shown to indicate to the user what changes they need to make in order to capture the images. If everything looks good, they are prompted to start the capture.
    * Users are prompted for: very uneven lighting on the face, face is obstructed, face is cropped out, user is holding device too close, etc
    * These checks are done in real time by calculating facial landmarks and sampling different portions of the video frame
3. Once the user initiates image capture the device:
    1. Maxes phone screen brightness
    2. Fills the screen to be 100% white (100% screen flash)
    3. Meters the camera to a bright point on the face
    4. Locks exposure and WB settings
    5. Captures an image
    6. Changes screen flash to 90%
    7. Repeat 5, 6 until 50% screen flash
    8. Calculate facial landmarks on each face
    9. Crop, resize, and convert each image to a lossless PNG
        1. Use facial landmarks to extract a crop of each eye in full resolution
        2. Use facial landmarks to crop to the face
        3. Resize face crop so longest edge is 1080 pixels
        4. Convert each image to a lossless PNG
    10. transfer images, facial landmarks, and metadata to server to calculate face color


The app supports other functionality, such as user logins, user settings, real time facial landmark overlays, and the ability to record your skin tone - established by comparing your skin to a ground truth color swatch (for beta testing and technological validation).

## Tone iOS Implementation Details

The app is structured in a MVVM format leveraging RxSwift to wrap State, UI, Delegates, and generally structure the image processing pipelines in a declarative way.
