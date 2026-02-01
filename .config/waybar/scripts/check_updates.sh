#!/bin/bash
dnf check-update -q | grep -v '^$' | wc -l