We recommend a machine with 4GB or more of RAM.  
If you are careful and use a limited number of connections you can go lower than this, but doing so can cause instability.

You must use an x64 (Intel or AMD), or an ARM64 CPU and matching Linux distribution.  
If using a Raspberry Pi or similar and installing yourself, make sure to use the ARM64 image instead of the default ARM image.

We chose not to support the non 64bit ARM images, as they don't work as well for systems with over 4GB of memory, and many of our dependencies need extra work to compile for the ARM platform. It would take much more effort from us, and would result in there being two ARM versions (we would need to keep the ARM64 support) further increasing the work and confusion for users.
