# Tone iOS App

### NOTE: THIS IS NOT CLEANED UP YET. 

Target deadline for cleaning and detailed writeup 1/14/2020

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
