# Design ideas
My OS goals come to cover mainly the Jonathan Blow's and part of Casey Muratori's ideas.

- Reduce processes/libraries/cruft to a minimum
- Prefer static libraries over dynamic libraries, reducing these to a minimum
- Static libraries and shared libraries are the same, because both must be position independent and it's up to the user to link them dynamically or statically. Also prefer build from source? In the executable file there should be information about library provenance to allow (security) patches.
- Remove duality between libraries and command line programs. UI features needed (section to add UI functions?). Maybe avoid libraries altogether and just go with executables? Is it worth it time-wise (because of compilation times)?
- 0 dependencies
- user-space "driver". Drivers are just a bare minimum of code to communicate to the hardware and they are given a token or something by the kernel to avoid system calls and therefore context switches and state mutexes
- Heavy sandbox by default
- Nice and fast desktop UI
- Filesystem access avoided by default to programs
- Process communication is done through shared memory mapping
- Figure out package managers/installs (not yet sure what to do there) (more software = more problems usually)
- not support GPUs for the moment or figure out how to create a really thin driver around one single GPU - run compute shader that writes to GPU memory. Maybe provide a better API or have direct access to the GPU ISA?
PATH - configuration based on strings are terrible. Path? John proposes a folder in user "home" with links to all the places where the executables are to be found. Problem with substitute path?
