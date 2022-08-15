# xkmixer - an audio mixer / USB sound card for the XCORE-200 Multichannel Audio Platform

xkmixer is a firmware for the XCORE-200 Multichannel Audio Platform board
(XK-AUDIO-216-MC-AB). I use it as my main audio box for my gaming desk:

- USB sound card for my gaming PC.
  - Supports several outputs as well as configurable return channels, to
    provide JACK-like per-application routing and recording on a Windows
    gaming machine.
- Audio mixer for other miscellaneous devices.
  - Mixes together sound from the PC, multiple analog sources, and a digital
    TOSLINK source. Sends that mixed audio to multiple analog outputs
    (speakers, headset).

Long term, I would like to also add features such as microphone noise
cancellation directly in the box. This would allow for such features to work
systemwide instead of being specific to individual applications (e.g. Discord,
Mumble, etc. all have their own noise cancellation currently).

This is not really meant to be a widely used/distributed project, it's very
much tailored to my personal needs. I am distributing the source for it under
an open license for educational purposes, but feel free to do whatever else
you want with it!

## How

While XMOS provides a sample firmware which covers many of my needs, the
licensing of the source code for this sample is problematic. Some components
are openly licensed, but not all of it. In order to better understand what's
going on and how the hardware operates, I decided to rewrite everything from
scratch, because why not!