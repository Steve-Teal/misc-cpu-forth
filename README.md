# misc-cpu-forth
Fairweather 'C' implementation of MISC (Minimal Instruction Set CPU) virtual machine with a GForth kernel.

## File List
A description of the files included in this repository.  
**readme.md**           - This file  
**misc.c**              - Source code  
**kernl-misc-0-7-3.fi** - GForth binary image

## Build instructions
This program is unlikely to run or compile on a non-Windows machine. It can be built with the GCC compiler as follows:
```

gcc misc.c -o misc.exe

```
Running **misc.exe** will load and run the GForth kernel.

## Screenshot
![Screenshot](misc.png)

## TODO
* VHDL version for a FPGA platform

## Licence
MIT License - refer to the license file included with this repository.
