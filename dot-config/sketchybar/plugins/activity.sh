#!/bin/bash

click() {
  open "https://wakapi.kushvinth.com/"
}

case "$SENDER" in
  "mouse.clicked") click ;;
esac
