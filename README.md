# MCSyncTest
## Description of the issue

This repository represents a minimum reproducible example for the following issue: Using Multipeer Connectivity to synchronize state between two local devices has become somewhat laggy. This was not always the case although I am not able to say the exact point in time when the issue first appeared. I am using this approach in an AR app of mine to synchronize 3D model state (and a bit of UI using SwiftUI) between devices and this has always been silky smooth. The gif shows the issue. The slider is being moved in a continous and smooth motion on the peer device. The receiving device is not able to smoothly present the state change.

![](https://github.com/MrMuetze/MCSyncTest/blob/main/gif/example_of_issue.gif)

(Xcode 15.2, iOS 17.3, connection between iPhone 15 Pro and iPad Pro (2nd generation))

I have added `print` outputs to the app to better indicate which part of the code is the issue. Thus I am able to eliminate the network code as a possible source as messages are being retrieved without problem. It seems that `DispatchQueue.main.async` is having "hiccups" regularly. The workload to update the UI can't really be the issue. In my tests with the AR app the hiccups happen with SwiftUI changes as well as SceneKit node changes. During a hiccup the usual sequence of "received data -> doing stuff" turns into

```
...
received data <-- normal behavior
doing stuff
received data
doing stuff
received data
doing stuff
received data <-- hiccup starts
received data
received data
received data
doing stuff
doing stuff
doing stuff
doing stuff
received data <-- returns to normal behavior
doing stuff
received data
doing stuff
...
```

and shows as a lag spike in the app. I am aware that `DispatchQueue.main.async` does not guarantee the sequence of work to be run, but the workload itself shouldn't be the issue. I am sure that there is something else going on.

## How to reproduce locally

Reproducing the issue with two iOS devices should be the easiest.

1. Run app on both devices.
2. Tap "Advertise" on one app.
3. Tap on the appearing `MCPeerID` on the other device. (ideally have a debugger running on one device to be aware of the connection state changes)
4. When the devices are connected, move the slider on one device to observe the lag spikes on the other device. (debug output is also provided on the receiving device)

I was also only sometimes able to reproduce it with a Simulator + real device, but success does not seem to be guaranteed. The most promising steps would be:

1. Run app on simulator and on device.
2. Tap "Advertise" in the simulator.
3. Tap on the appearing `MCPeerID` on the device.
4. Change the slider value in the simulator and observe lag spikes on device.

The issue should happen in Debug as well as Release mode.

## What I have tried so far

I have already tried to set the "Quality of Service" to `.userInteractive` but that has not helped. Limiting the number of messages being sent (e.g. a maximum of 10 messages per second) does not improve the situation either. `DispatchQueue.main.sync` is also not a solution right now. It does bring the sequence back into original order but the periodic "freeze" of the queue is prevalent there as well. This then leads to a "laggy" execution of what happened on the sending peer device.
