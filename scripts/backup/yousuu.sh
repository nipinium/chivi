#! /bin/bash

INP=nipin@ssh.nipin.xyz:web/chivi/data/txt-inp/yousuu
INP=assets/.inits/books/yousuu

rsync -azui --no-p "$INP/serials" $OUT
rsync -azui --no-p "$INP/reviews" $OUT