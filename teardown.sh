#!/bin/bash

kind delete cluster

docker rm -f registry
