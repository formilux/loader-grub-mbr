#make -j 3 bzImage CC=gcc-3.3.1
cd linux* && make -j 3 bzImage ; cd -

# tools
cd kexec-tools*

# NE SURTOUT PAS COMPILER EN DIET !!! les options sont ignorées
# et on obtient un segfault
#make CC="diet gcc" CFLAGS="-Os \$(CPPFLAGS)"
strip -R .comment -R .note objdir/build/sbin/kexec 
