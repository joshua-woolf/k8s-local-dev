#!/bin/sh

kind delete cluster

docker rm -f registry
