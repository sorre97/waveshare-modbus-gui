# A (very) simple modbus python client for Waveshare
## TL;DR
This folder derives from [the Waveshare RaspberryPI demo](https://www.waveshare.com/wiki/Modbus_POE_ETH_Relay#Demos). 

After that, understanding that basically the device only works correctly via RTU-modbus (and not TCP-modbus), a lot of changes have been made to the original RTU demo, and saved into the usable script `modbus-cmd.py`. 

So first usage:

```bash
python3 modbus-cmd.py -h #so that you can see which arguments to give
```

## Other stuff
`relay2_ON.py` and `relay2_OFF.py` are simply tests/templates for even simpler usages. 

`pycrc.py` is a standalone version of the pycrc package from the maker of the device (please, don't ask). It must be available/next to the scripts.