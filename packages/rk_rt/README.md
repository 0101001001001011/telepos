# rk_rt

Motion control commands and telemetry.

**Version 0.0.1 claims the name and does nothing else.** The implementation
arrives in later versions.

Deliberately dormant. A control loop cannot run in a garbage-collected runtime, so this package carries intent and observation, never the loop. With servo drives the loop is closed inside the drive, which is why this package may never need more than a protocol.

## License

MIT, Rob Kim. See `LICENSE`.
