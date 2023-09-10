#!/bin/bash

# Setup taken from https://github.com/tianon/dockerfiles/blob/master/makemkv/Dockerfile
# The Expat/MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

# Auto-grab latest version
echo -e "${RED}Finding current MakeMKV version${NC}"
MAKEMKV_VERSION=$(curl -s https://www.makemkv.com/download/ | grep -o "[0-9.]*.txt" | sed 's/.txt//')
echo -e "${RED}Downloading MakeMKV $MAKEMKV_VERSION sha, bin, and oss${NC}"

# This disc requires Java runtime (JRE), but none was found. Certain functions will fail, please install Java. See http://www.makemkv.com/bdjava/ for details.
set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		openjdk-11-jre-headless \
	; \
	rm -rf /var/lib/apt/lists/*


# beta code: http://www.makemkv.com/forum2/viewtopic.php?f=5&t=1053
set -ex; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		g++ \
		gcc \
		gnupg \
		libavcodec-dev \
		libexpat-dev \
		libssl-dev \
		make \
		pkg-config \
		qtbase5-dev \
		wget \
		zlib1g-dev \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
	wget -O 'sha256sums.txt.sig' "https://www.makemkv.com/download/makemkv-sha-${MAKEMKV_VERSION}.txt"; \
# TODO pre-download (in versions.sh)/verify sha256sums
# pub   dsa2048 2017-05-26 [SC]
#       2ECF 2330 5F1F C0B3 2001  6733 94E3 083A 1804 2697
# uid           [ unknown] MakeMKV (signature) <support@makemkv.com>
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 2ECF23305F1FC0B32001673394E3083A18042697; \
	gpg --batch --decrypt --output sha256sums.txt sha256sums.txt.sig; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" sha256sums.txt.sig; \
	\
	export PREFIX='/usr/local'; \
	for ball in makemkv-oss makemkv-bin; do \
		wget -O "$ball.tgz" "https://www.makemkv.com/download/${ball}-${MAKEMKV_VERSION}.tar.gz"; \
		sha256="$(grep "  $ball-${MAKEMKV_VERSION}[.]tar[.]gz\$" sha256sums.txt)"; \
		sha256="${sha256%% *}"; \
		[ -n "$sha256" ]; \
		echo "$sha256 *$ball.tgz" | sha256sum -c -; \
		\
		mkdir -p "$ball"; \
		tar -xvf "$ball.tgz" -C "$ball" --strip-components=1; \
		rm "$ball.tgz"; \
		\
		cd "$ball"; \
		if [ -f configure ]; then \
			./configure --prefix="$PREFIX"; \
		else \
			mkdir -p tmp; \
			touch tmp/eula_accepted; \
		fi; \
		make -j "$(nproc)" PREFIX="$PREFIX"; \
		make install PREFIX="$PREFIX"; \
		\
		cd ..; \
		rm -r "$ball"; \
	done; \
	\
	rm sha256sums.txt; \
	\
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

#set -ex
#savedAptMark="$(apt-mark showmanual)"
#
#wget -O 'sha256sums.txt.sig' "https://www.makemkv.com/download/makemkv-sha-${MAKEMKV_VERSION}.txt"
#GNUPGHOME="$(mktemp -d)" && export GNUPGHOME
#gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 2ECF23305F1FC0B32001673394E3083A18042697
#gpg --batch --decrypt --output sha256sums.txt sha256sums.txt.sig
#gpgconf --kill all
#rm -rf "$GNUPGHOME" sha256sums.txt.sig
#
#export PREFIX='/usr/local'
#for ball in makemkv-oss makemkv-bin; do
#	wget -O "$ball.tgz" "https://www.makemkv.com/download/${ball}-${MAKEMKV_VERSION}.tar.gz"
#	sha256="$(grep "  $ball-${MAKEMKV_VERSION}[.]tar[.]gz\$" sha256sums.txt)"
#	sha256="${sha256%% *}"
#	[ -n "$sha256" ]
#	echo "$sha256 *$ball.tgz" | sha256sum -c -
#	mkdir -p "$ball"
#	tar -xvf "$ball.tgz" -C "$ball" --strip-components=1
#	rm "$ball.tgz"
#	cd "$ball"
#	if [ -f configure ]; then
#		./configure --prefix="$PREFIX"
#	else
#		mkdir -p tmp
#		touch tmp/eula_accepted
#	fi
#	make -j "$(nproc)" PREFIX="$PREFIX"
#	make install PREFIX="$PREFIX"
#	cd ..
#	rm -r "$ball"
#done
#
#rm sha256sums.txt
#apt-mark auto '.*' > /dev/null
## shellcheck disable=SC2086
#[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark # double quoting this var breaks the build
#find /usr/local -type f -executable -exec ldd '{}' ';' \
#	| awk '/=>/ { print $(NF-1) }' \
#	| sort -u \
#	| xargs -r dpkg-query --search \
#	| cut -d: -f1 \
#	| sort -u \
#	| xargs -r apt-mark manual
