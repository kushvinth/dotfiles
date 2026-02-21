#!/bin/bash

click() {
  open "http://localhost:5600/#/activity/kushvinth/view/"
}

case "$SENDER" in
  "mouse.clicked") click ;;
esac
