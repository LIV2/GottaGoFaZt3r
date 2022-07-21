# GottaGoFaZt3r Fast RAM

256MB Autoconfig Fast RAM for the Amiga 3000/4000 

![PCB](Docs/PCB.png?raw=True)

## Table of contents
1. [Status](#status)
2. [Features](#features)
3. [Ordering PCBs](#ordering-pcbs)
4. [Bill of materials](#bill-of-materials)
5. [Troubleshooting](#troubleshooting)
6. [Special Thanks and Shoutouts](#special-thanks-and-shoutouts)
7. [License](#license)

## Status
Tested and working in the following configurations:
* Amiga 3000
* Amiga 4000 with A3640

## Features
128MB or 256MB Z3 Fast RAM  
Brand new 32Mx16 SDRAM chips are quite expensive so the board can also be fitted with 16Mx16 chips for a much lower build cost  

## Ordering PCBs
I recommend ordering from JLCPCB as this board was designed within their 4-layer specifications  
Recommended options when ordering:
* Thickness: 1.6mm
* Surface Finish: ENIG-RoHS
* Gold Fingers: Yes
* 45°finger chamfered: Yes

Layer sequence:
|Layer|File|
|-|-|
|L1|GottaGoFaSDZ3-F_Cu.gbr|
|L2|GottaGoFaSDZ3-In1_Cu.gbr|
|L3|GottaGoFaSDZ3-In2_Cu.gbr|
|L4|GottaGoFaSDZ3-B_Cu.gbr|


## Bill of materials

|Component|Location|QTY|Link|Notes|
|---------|--------|---|----|-----|
|0.1uF Ceramic Capacitor, 0603|C4-15,C17-44|40|[Mouser](https://www.mouser.com/ProductDetail/80-C603C104K5RAC3121)<br />[DigiKey](https://www.digikey.com/short/f7trtfwt)||
|10uF Ceramic Capacitor, 1206|C2-3,C16|3|[Mouser](https://www.mouser.com/ProductDetail/187-CL31A106MAHNNNE)<br />[DigiKey](https://www.digikey.com/short/rqt1br0q)||
|33 Ohm Resistor, 0603|R1|1|[Mouser](https://www.mouser.com/ProductDetail/603-RT0603DRE0733RL)<br />[DigiKey](https://www.digikey.com/short/40rdd4m1)||
|33 Ohm Resistor network, Convex 1206 (3.2x1.6mm)|RN1-8|8|[Mouser](https://www.mouser.com/ProductDetail/667-EXB-38V330JV)<br />[DigiKey](https://www.digikey.com/short/t08zh4pn)||
|10K Resistor, 0603|R2|1|[Mouser](https://www.mouser.com/ProductDetail/603-RT0603FRD0710KL)<br />[DigiKey](https://www.digikey.com/short/nvvrt5dw)||
|LM1117-3.3 SOT-223|U1|1|[Mouser](https://www.mouser.com/ProductDetail/926-LM1117IMP3.3NOPB)<br />[Digikey](https://www.digikey.se/short/jprv7r4q)||
|74LVC245N TSSOP|U2-5|4|[Mouser](https://www.mouser.com/ProductDetail/595-SN74LVC245APWT)<br />[DigiKey](https://www.digikey.se/short/vbmphn44)|Can be substituted with SN74LVTH245 or SN74LVCR2245|
|AS4C32M16SC 32Mx16 SDRAM, TSSOP-54|U7-10|4|[Mouser](https://www.mouser.com/ProductDetail/913-AS4C32M16SC-7TIN)<br />[DigiKey](https://www.digikey.com/short/wfwn8nmw)|Cheaper option is to use [A3V56S40GTP](https://www.mouser.com/ProductDetail/155-A3V56S40GTP-60) 16Mx16 for a 128MB configuration at a drastically lower price, or scavenge some 32Mx16 SDRAM from old SODIMMs*|
|Xilinx XC95144XL-10TQG100C 10ns 144 Macrocell CPLD|U6|1|[Mouser](https://www.mouser.com/ProductDetail/217-95144XL-10TQ100C)<br />[Digkey](https://www.digikey.com/short/w0r0j288)||
|Clock Oscillator, HCMOS, 7x5mm, 3.3V, ~66MHz|X1|1|[Mouser](https://www.mouser.com/ProductDetail/959-SM7745HEV-66.667)<br />[DigiKey](https://www.digikey.com/short/q8bzfwj4)|Anything close to 66MHz should work<br />Tested at 66.6666MHz|

__*__ I cannot provide technical support for RAM chips other than those explicitly listed in the BOM, others may work but you're on your own

## Troubleshooting
__Problem:__ The board is detected but there is less memory detected than there should be. or you see a message stating that the board is "Defective"  
__Resolution:__
1. Check all soldering looking for bad connections and shorts around the RAM and CPLD
2. Test the RAM using [ATK](https://github.com/keirf/amiga-stuff/releases)  
Look for the relevant region under "List and test regions" and test it  
Consult the memory layout to determine which IC is responsible for any stuck bits you might see

### Memory Layout
The memory is laid out in a way that causes it to wrap around above 128MB when only 128MB of ram is fitted to the card allowing either 128/256MB configuration with the same CPLD firmware.  
Kickstart will notice this wrap and add only 128MB to the free pool in this instance.

|Address|D0-15|D16-31|
|-------|-----|------|
|40000000-43FFFFFF|U7|U9|
|44000000-47FFFFFF|U8|U10|
|48000000-4BFFFFFF|U7|U9|
|4C000000-4FFFFFFF|U8|U10|

## Special Thanks and Shoutouts
* [Niklas Ekström](https://github.com/niklasekstrom) for helping to clean up my messy code
* [GadgetUK164](https://www.youtube.com/gadgetuk164) for ~~being a guinea pig~~ beta testing many of my boards
* SparxUK also for being a helpful beta tester of many of my boards
* [CDH](https://github.com/cdhooper) and [Stefan Reinauer](https://github.com/reinauer) for helping me to get my A3000 going 
* [Rob "peepo" Taylor](https://tindie.com/stores/bobsbits/) whose A500++ got me started on my journey of tinkering with Amigas
* [jbilander](https://github.com/jbilander) who came up with the cool name :)
* RetroFletch
* [SukkoPera](https://github.com/SukkoPera)

## License

[![CC BY-SA 4.0][cc-by-sa-shield]][cc-by-sa]

This work is licensed under a
[Creative Commons Attribution-ShareAlike 4.0 International License][cc-by-sa].

[![CC BY-SA 4.0][cc-by-sa-image]][cc-by-sa]

[cc-by-sa]: http://creativecommons.org/licenses/by-sa/4.0/
[cc-by-sa-image]: https://licensebuttons.net/l/by-sa/4.0/88x31.png
[cc-by-sa-shield]: https://img.shields.io/badge/License-CC%20BY--SA%204.0-lightgrey.svg
