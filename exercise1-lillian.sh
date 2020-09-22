#!/bin/bash
#This script takes as input one argument, a directory, and outputs the number of different permission types in this directory.

ls -l $1 | tail -n +2 | cut -d ' ' -f 1 | sort | uniq | wc -l


