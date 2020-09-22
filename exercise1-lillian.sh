#!/bin/bash
dir=$1
ls -l "$dir" | tail -n +2 | cut -c 1-11| sort | uniq | wc -l


