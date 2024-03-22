### To make changes and patch files:

1. Make changes to gcc
2. git diff <filename> > /path/to/patches/<filename>.patch

### To apply patches:
1. patch -u <filename> -i <filename>.patch

### Caveats
1. You cannot create patches for multiple files at a time without some annoying parsing
