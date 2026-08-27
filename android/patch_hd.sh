#!/bin/bash
FILE=$(find ~/.pub-cache -path "*flutter_screen_recording-2.0.25/android/src/main/java/com/foregroundservice/RecordService.java" | head -1)
if [ -f "$FILE" ]; then
  sed -i 's/setVideoEncodingBitRate.*/setVideoEncodingBitRate(12000000);/' $FILE
  sed -i 's/setVideoFrameRate.*/setVideoFrameRate(30);/' $FILE
  sed -i 's/setVideoSize.*/setVideoSize(1080, 1920);/' $FILE
  echo "Patched to 1080p HD 12Mbps"
fi