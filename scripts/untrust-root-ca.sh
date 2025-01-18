#!/bin/sh

sudo security delete-certificate -c "Local Dev Root" /Library/Keychains/System.keychain
