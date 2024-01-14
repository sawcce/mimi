# MiMi

Toy os based of off the limine zig template, currently only aiming for x86_64 (64 bit) support.

## Current architecture
The project is currently centered around kernel "modules",
these modules provide a generic way for the kernel to
initialize and deinitialize them, as well as keeping track
of loaded modules (along with an associated name).
This makes it easy to run code at boot without actually
having to keep track of method names or other factors: 
modules only expose what they need.

## Current state
The project might not be consistently active due my current
studies, but you are free to give any suggestions by
opening a PR (pull request) or an issue.