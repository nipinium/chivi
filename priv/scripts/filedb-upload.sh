#!/usr/bin/env bash

if [[ $1 == "prod" ]]
then
  echo "Upload to chivi.xyz!"
  ssh=nipin@ssh.chivi.xyz:srv/chivi.xyz
else
  echo "Upload to dev.chivi.xyz!"
  ssh=nipin@dev.chivi.xyz:srv/chivi.xyz
fi

echo $ssh

## upload dicts
# rsync -azi --no-p "_db/vp_dicts/_inits/" "$ssh/_db/vp_dicts/_inits/"
rsync -azi --no-p "_db/vp_dicts/active/" "$ssh/_db/vp_dicts/backup/"
# rsync -azi --no-p "_db/vp_dicts/active/" "$ssh/_db/vp_dicts/active/"

## upload user data
rsync -azi --no-p "_db/vi_users/" "$ssh/_db/vi_users/"

## upload parsed seed data
rsync -azi --no-p "_db/_seeds/" "$ssh/_db/_seeds/"

## upload book data
rsync -azi --no-p "_db/nv_infos/" "$ssh/_db/nv_infos/"

#rsync -azi --no-p --delete "_db/nv_infos/covers" "$ssh/_db/nv_infos/"