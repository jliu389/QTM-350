#!/bin/bash
dir=$1
ls -l "$dir" | tail -n +2 | cut -d ' ' -f 1| sort | uniq | wc -l


