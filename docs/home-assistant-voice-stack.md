# Home Assistant Voice Stack

This guide sets up a practical local voice path for Home Assistant Container:

- ESPHome ESP32-S3 satellite -> microphone audio into Home Assistant
- openWakeWord -> wake word
- Whisper -> speech to text
- Home Assistant or Ollama -> conversation agent
- Piper -> text to speech
- ESP32 speaker -> spoken reply

The repo deploys the voice services as a dedicated compose bundle on
`vm210-ai-gpu`.

The examples below use the default UK site config. France builds keep the same
host ID on the servers VLAN, so the AI VM becomes `10.20.20.210`.

## Docker Compose Bundle

Compose bundle path:

- [docker-compose.yml](../ansible/files/compose/vm210-ai-gpu/home-assistant-voice/docker-compose.yml)

Environment defaults:

- [stack.env.example](../ansible/files/compose/vm210-ai-gpu/home-assistant-voice/stack.env.example)

Service endpoints on `vm210-ai-gpu` (`10.10.20.210`):

- Piper: `10.10.20.210:10200`
- Whisper: `10.10.20.210:10300`
- openWakeWord: `10.10.20.210:10400`

France defaults:

- Piper: `10.20.20.210:10200`
- Whisper: `10.20.20.210:10300`
- openWakeWord: `10.20.20.210:10400`

Persistent data locations:

- `/mnt/appdata/docker_volumes/home-assistant-voice/piper`
- `/mnt/appdata/docker_volumes/home-assistant-voice/whisper`
- `/mnt/appdata/docker_volumes/home-assistant-voice/openwakeword`

## Recommended Defaults

- Piper voice: `en_US-lessac-medium`
- Whisper model: `tiny-int8`
- Whisper language: `en`
- openWakeWord model: `ok_nabu` for initial setup
- target custom wake word: `HAL`

### Whisper model tradeoff

`tiny-int8`

- fastest
- lowest CPU load
- best first choice for responsive voice replies
- lower transcription quality in noisy rooms

`base-int8`

- noticeably better accuracy
- higher CPU use and more latency
- better choice if `tiny-int8` misses words or room noise is a problem

If you want the safer first-run option, keep `tiny-int8` and only switch to
`base-int8` after the end-to-end audio path is working.

### Wake word plan: HAL

`HAL` is not a built-in openWakeWord model in the Wyoming container. The stack
is now wired for a custom wake word model:

- host path:
  - `/mnt/appdata/docker_volumes/home-assistant-voice/openwakeword/custom`
- container path:
  - `/custom`

Recommended rollout:

1. Start with `ok_nabu` so the full voice path is easy to validate.
2. Train or obtain a custom `HAL` wake word `.tflite` model.
3. Copy it into:
   - `/mnt/appdata/docker_volumes/home-assistant-voice/openwakeword/custom`
4. Restart `wyoming-openwakeword`.
5. In Home Assistant, switch the wake word from `Okay Nabu` to `HAL`.

## Home Assistant Setup

### 1. Start the voice services

Deploy the `vm210-ai-gpu` role as usual so Ansible creates the voice service
bundle and starts the containers.

### 2. Add Wyoming Protocol integrations

In Home Assistant:

1. Go to `Settings -> Devices & services -> Add integration`.
2. Search for `Wyoming Protocol`.
3. Add `Piper`:
   - Host: `10.10.20.210`
   - Port: `10200`
4. Add `Whisper`:
   - Host: `10.10.20.210`
   - Port: `10300`
5. Add `openWakeWord`:
   - Host: `10.10.20.210`
   - Port: `10400`

If auto-discovery appears, you can accept the discovered services instead of
adding them manually. Manual add is more predictable on Docker installs.

### 3. Build the Assist pipeline

In Home Assistant:

1. Go to `Settings -> Voice assistants`.
2. Create a new pipeline called `Assist Local`.
3. Set:
   - Wake word: `openWakeWord`
   - Speech-to-text: `Whisper`
   - Conversation agent: `Home Assistant`
   - Text-to-speech: `Piper`
4. Save.

Recommended first pass:

- keep the conversation agent as `Home Assistant` first
- keep the wake word on `Okay Nabu` first
- confirm the ESP32 can hear you and play the reply
- only then switch the wake word to `HAL` and/or clone the pipeline for
  Ollama-backed conversation

### 4. Optional LLM pipeline

After the base pipeline works:

1. Create a second pipeline called `Assist Local LLM`.
2. Set:
   - Wake word: `HAL` once the custom model is installed
   - Speech-to-text: `Whisper`
   - Conversation agent: `Ollama`
   - Text-to-speech: `Piper`
3. Save.

Use the first pipeline for reliable home control and the second pipeline for
more natural replies.

## Assist Pipeline Settings

Recommended production split:

### Pipeline A: `Assist Local`

- Wake word: `openWakeWord`
- STT: `Whisper`
- Conversation: `Home Assistant`
- TTS: `Piper`

Use this for:

- device control
- timers
- lights
- climate
- reliable local commands

### Pipeline B: `Assist Local LLM`

- Wake word: `HAL`
- STT: `Whisper`
- Conversation: `Ollama`
- TTS: `Piper`

Use this for:

- richer conversational responses
- summarization
- Q&A
- optional Home Assistant control through the Ollama agent

## ESPHome Voice Satellite

Starter YAML:

- [esphome-esp32-s3-voice-satellite.yaml](esphome-esp32-s3-voice-satellite.yaml)

That YAML is written for:

- ESP32-S3 DevKitC-1 N16R8
- INMP441 I2S microphone
- MAX98357A I2S speaker amp
- Home Assistant `voice_assistant` integration

## Pins to verify

Before flashing the ESPHome YAML, verify these pins against your exact board and
wiring:

- `GPIO4` -> I2S microphone WS/LRCLK
- `GPIO5` -> I2S microphone BCLK/SCK
- `GPIO8` -> INMP441 SD/DOUT
- `GPIO6` -> I2S speaker WS/LRCLK
- `GPIO7` -> I2S speaker BCLK
- `GPIO9` -> MAX98357A DIN
- `GPIO48` -> status LED
- `GPIO0` -> button input

Common changes:

- many ESP32-S3 boards use different boot button pins
- some boards do not expose a usable LED on `GPIO48`
- some builds share one I2S bus for both microphone and speaker instead of two
  separate buses
- some INMP441 boards need `channel: right` instead of `channel: left`

## Troubleshooting

### No audio playback

- Confirm the MAX98357A `GAIN/SD` wiring and speaker power.
- Confirm the I2S speaker pins in the ESPHome YAML.
- In ESPHome logs, verify the voice assistant receives a TTS stream after your request.
- Temporarily test with a simple Home Assistant TTS action to rule out wake word/STT issues.

### TTS works in Home Assistant but no sound on the ESP32

- This usually means the Assist pipeline is fine, but the ESP32 speaker config is wrong.
- Re-check the `speaker` block and I2S `dout` pin.
- Verify the ESP32 board uses the same sample rate for speaker output as the configured media path.
- Make sure the MAX98357A amplifier is actually enabled and the speaker ground is common with the ESP32.

### Choppy audio

- Use strong Wi-Fi on the ESP32 satellite.
- Keep the ESP32 on 2.4 GHz with a good signal.
- Reduce concurrent CPU load on the VM if Whisper is busy.
- Keep Whisper on `tiny-int8` before moving to `base-int8`.
- Increase buffering only after the basic path works.

### Wrong sample rate

- Use `16000` Hz on the microphone path for voice assistant capture.
- If playback sounds too fast, too slow, or distorted, re-check the speaker sample rate in the ESPHome YAML.
- Keep microphone and speaker clock pins exactly aligned with your board wiring.

### Wake word triggers but conversation reply never plays

- Verify the Assist pipeline uses Piper for TTS.
- Verify the ESPHome satellite remains connected to Home Assistant during the reply.
- Confirm the `voice_assistant` component is configured with both microphone and speaker.
- Check the Home Assistant logs for STT or conversation-agent failures.
- If using the Ollama pipeline, switch back to the plain `Home Assistant` conversation pipeline first to isolate the problem.
- If `HAL` does not appear as a wake word, confirm the custom `.tflite` model is
  in `/mnt/appdata/docker_volumes/home-assistant-voice/openwakeword/custom` and
  restart `wyoming-openwakeword`.
