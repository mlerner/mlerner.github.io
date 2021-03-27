#!/bin/sh

#
# Configuration
#

# sass source
SASS_SOURCE_PATH="resources/"
SASS_SOURCE_FILE="main.sass"

# sass options
SASS_OPTIONS="-t compressed -l -m"

# css target
CSS_TARGET_PATH="css/"
CSS_TARGET_FILE="main.css"


#
# Check prerequisites
#

sasscfile=$(command -v sassc) || { echo "sassc is required but not installed"; exit 1; }
fswatchfile=$(command -v fswatch) || { echo "fswatch is required but not installed"; exit 1; }

#
# Watch folder for changes
#

$fswatchfile --recursive --one-per-batch "$SASS_SOURCE_PATH" | xargs -n1 -I{}  $sasscfile $SASS_OPTIONS "$SASS_SOURCE_PATH/$SASS_SOURCE_FILE" "$CSS_TARGET_PATH/$CSS_TARGET_FILE"

