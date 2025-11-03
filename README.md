# thin-edge-update

The following commands serve to trigger the workflow restart_background and listen to the updates


```
tedge mqtt pub -q 1 -r te/device/main///cmd/restart_background/re-123 "{\"status\": \"init\"}"
mosquitto_sub -h localhost -p 1883 -t 'te/device/main///cmd/restart_background/#' -v -R
mosquitto_pub -h localhost -p 1883 -t 'te/device/main///cmd/restart_background/re-123' -r -m "{\"status\": \"init\"}"
```