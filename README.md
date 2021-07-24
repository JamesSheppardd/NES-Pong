![Logo](/Pong/assets/LogoNoBg.png)
# NES-Pong

### About
This is my first time using assembly and it uses the 6502 architecture, and is my first attempt at an NES homebrew game. It is a pretty bare-bones clone of Pong, and as of now there are no sound effects or music, and collision detection can be a bit hit or miss.

### Installation / Playing
If you wish to play the game you can download it from my [itch.io](https://jamessheppard.itch.io/nes-pong) page, or you can compile it yourself (only works if you have installed [cc65](https://cc65.github.io/#Links)):
1. Clone this repository
2. Move into the folder you cloned into
3. Run "Makefile.bat" from the src folder
4. A couple of files will be created
    * pong.nes  - the playable ROM to be opened with an NES emulator like [Mesen](https://mesen.ca/)
    * pong.dbg  - a debug file
    * pong.o

### Useful resources 
* [Nerdy Nights tutorials](https://nerdy-nights.nes.science/#main_tutorial)
* [NESdev Wiki](https://wiki.nesdev.com/w/index.php/Nesdev_Wiki)
* [NES Memory Map](https://docs.google.com/spreadsheets/d/13Y_h6-3DQwdK-3Dvleg-Glk0jn43_As8jPKa08O__bU/edit?usp=sharing) created by [@vblank182](https://github.com/vblank182)
* [6502 Reference](www.obelisk.me.uk/6502/reference.html)