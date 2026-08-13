#!/bin/bash
# Wrapper: OpenLane expects 'sta' binary, but OpenROAD integrates STA
exec /home/openroad/OpenROAD/build/bin/openroad -no_splash "$@"
