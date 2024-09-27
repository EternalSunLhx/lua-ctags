# Makefile for (cross)compiling lua-ctags binaries.
# Do not use directly, run scripts/build-binaries.sh instead.

LUA_VERSION= 5.4.4
LFS_VERSION= 1.8.0-1
ARGPARSE_VERSION= 0.7.1-1

LUA_DIR= lua-$(LUA_VERSION)
LFS_DIR= luafilesystem-$(LFS_VERSION)/luafilesystem
ARGPARSE_DIR= argparse-$(ARGPARSE_VERSION)/argparse-$(ARGPARSE_VERSION:-1=)

BASE_CC= gcc
BASE_AR= ar rc
BASE_RANLIB= ranlib
BASE_STRIP= strip
BASE_NM= nm

CROSS=
CC= $(CROSS)$(BASE_CC)
CFLAGS= -O2 -Wall -Wextra
AR= $(CROSS)$(BASE_AR)
NM= $(CROSS)$(BASE_NM)
RANLIB= $(CROSS)$(BASE_RANLIB)
STRIP= $(CROSS)$(BASE_STRIP)

SUFFIX=
TARGET= bin/lua-ctags$(SUFFIX)

LUA_O= $(patsubst %.c,%.o,$(filter-out $(addprefix $(LUA_DIR)/src/,lua.c luac.c print.c),$(wildcard $(LUA_DIR)/src/*.c)))
LUA_A= $(LUA_DIR)/src/liblua.a
LFS_O= $(patsubst %.c,%.o,$(wildcard $(LFS_DIR)/src/*.c))
LFS_A= $(LFS_DIR)/src/lfs.a

default:	$(TARGET)

$(LUA_DIR):
	@echo
	@echo "=== Downloading Lua $(LUA_VERSION) ==="
	@echo
	curl "https://www.lua.org/ftp/$(LUA_DIR).tar.gz" | tar xz

$(LFS_DIR):
	@echo
	@echo "=== Downloading LuaFileSystem $(LFS_VERSION) ==="
	@echo
	luarocks unpack luafilesystem $(LFS_VERSION)

$(ARGPARSE_DIR):
	@echo
	@echo "=== Downloading argparse $(ARGPARSE_VERSION) ==="
	@echo
	luarocks unpack argparse $(ARGPARSE_VERSION)

fetch:	$(LUA_DIR) $(LFS_DIR) $(ARGPARSE_DIR)

$(LUA_O):	CFLAGS+= $(if $(LINUX),-DLUA_USE_POSIX)
$(LUA_A):	$(LUA_O)
$(LFS_O):	CFLAGS+= -I$(LUA_DIR)/src
$(LFS_A):	$(LFS_O)

%.a:
	$(AR) $@ $^
	$(RANLIB) $@

$(TARGET): $(LUA_A) $(LFS_A)
	cp $(LUA_A) .
	cp $(LFS_A) .
	cp $(ARGPARSE_DIR)/src/argparse.lua .
	cp -r ../src/lua-ctags .
	cp -f bin/lua-ctags.lua bin/lua-ctags_bin.lua
	CC=$(CC) NM=$(NM) RANLIB=$(RANLIB) luastatic bin/lua-ctags_bin.lua lua-ctags/*.lua lua-ctags/*/*.lua lua-ctags/*/*/*.lua argparse.lua $(LUA_A) $(LFS_A) -lm $(if $(LINUX),-lpthread) -I$(LUA_DIR)/src
	rm lua-ctags_bin.luastatic.c
	$(STRIP) lua-ctags_bin*
	mv lua-ctags_bin* $(TARGET)

clean:
	rm -f $(TARGET) lua-ctags.luastatic.c
	rm -f $(LUA_O) $(LUA_A) $(LFS_O) $(LFS_A)
	rm -f argparse.lua lfs.a liblua.a
	rm -rf lua-ctags
	rm -f lua-ctags_bin*

.PHONY: default fetch clean
